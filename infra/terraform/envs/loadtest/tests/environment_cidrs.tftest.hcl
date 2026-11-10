mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{ sha1_fingerprint = "0000000000000000000000000000000000000000" }]
    }
  }
}

variables {
  operator_role_arn         = "arn:aws:iam::123456789012:role/operator"
  budget_alert_email        = "alerts@example.com"
  terraform_role_policy_arn = "arn:aws:iam::123456789012:policy/terraform"
}

run "environment_accepts_multiple_cidrs" {
  command = plan

  variables {
    cluster_admin_cidr = ["203.0.113.10/32", "198.51.100.0/24"]
  }
}

run "environment_rejects_open_cidr" {
  command = plan

  variables {
    cluster_admin_cidr = ["203.0.113.10/32", "0.0.0.0/0"]
  }

  expect_failures = [var.cluster_admin_cidr]
}
