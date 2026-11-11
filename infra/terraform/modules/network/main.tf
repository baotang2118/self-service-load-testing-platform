data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    var.availability_zone_count,
  )
  public_subnet_cidrs  = zipmap(local.availability_zones, var.public_subnet_cidrs)
  private_subnet_cidrs = zipmap(local.availability_zones, var.private_subnet_cidrs)
  common_tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-internet"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                     = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnet_cidrs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                              = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.availability_zones[0]].id

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.common_tags, {
    Name = "${var.name}-nat"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-private"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}