output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by availability zone."
  value       = [for az in local.availability_zones : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered by availability zone."
  value       = [for az in local.availability_zones : aws_subnet.private[az].id]
}

output "availability_zones" {
  description = "Availability zones used by the VPC."
  value       = local.availability_zones
}