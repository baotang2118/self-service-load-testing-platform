data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "runner" {
  statement {
    sid       = "ReadRegistrationToken"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.pat_parameter_name}"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-github-runner"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "runner" {
  name   = "runner"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.runner.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-github-runner"
  role = aws_iam_role.this.name
  tags = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-github-runner"
  description = "GitHub Actions runner: no inbound, HTTPS outbound."
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-github-runner" })
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS to GitHub, ECR, SSM, package mirrors, and the EKS API"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_api" {
  security_group_id            = var.cluster_security_group_id
  description                  = "EKS API from the GitHub runner"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.this.id
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.ami.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = false
  monitoring                  = true
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    name               = var.name
    region             = data.aws_region.current.name
    github_repository  = var.github_repository
    labels             = join(",", var.runner_labels)
    pat_parameter_name = var.pat_parameter_name
    runner_version     = var.runner_version
    runner_sha256      = var.runner_sha256
    kubectl_version    = var.kubectl_version
    kubectl_sha256     = var.kubectl_sha256
    helm_version       = var.helm_version
    helm_sha256        = var.helm_sha256
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size_gb
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.name}-github-runner" })

  lifecycle {
    # A newer AL2023 image must not silently replace the runner.
    ignore_changes = [ami]
  }

  depends_on = [aws_iam_role_policy_attachment.ssm]
}
