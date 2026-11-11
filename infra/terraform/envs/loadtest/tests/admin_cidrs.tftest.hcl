mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name                            = "demo"
  kubernetes_version              = "1.34"
  private_subnet_ids              = ["subnet-12345678", "subnet-87654321"]
  public_subnet_ids               = ["subnet-abcdef12", "subnet-abcdef34"]
  operator_role_arn               = "arn:aws:iam::123456789012:role/operator"
  additional_admin_principal_arns = []
  tags                            = {}
}

run "multiple_allowed_cidrs" {
  command = plan
  module {
    source = "../../modules/cluster"
  }

  variables {
    cluster_admin_cidr = ["203.0.113.10/32", "198.51.100.0/24"]
  }

  assert {
    condition     = toset(aws_eks_cluster.this.vpc_config[0].public_access_cidrs) == toset(var.cluster_admin_cidr)
    error_message = "The EKS endpoint must receive every configured CIDR."
  }
}

run "reject_empty_list" {
  command = plan
  module {
    source = "../../modules/cluster"
  }

  variables {
    cluster_admin_cidr = []
  }

  expect_failures = [var.cluster_admin_cidr]
}

run "reject_public_internet" {
  command = plan
  module {
    source = "../../modules/cluster"
  }

  variables {
    cluster_admin_cidr = ["203.0.113.10/32", "0.0.0.0/0"]
  }

  expect_failures = [var.cluster_admin_cidr]
}

run "reject_invalid" {
  command = plan
  module {
    source = "../../modules/cluster"
  }

  variables {
    cluster_admin_cidr = ["not-a-cidr"]
  }

  expect_failures = [var.cluster_admin_cidr]
}

run "reject_ipv6" {
  command = plan
  module {
    source = "../../modules/cluster"
  }

  variables {
    cluster_admin_cidr = ["2001:db8::/32"]
  }

  expect_failures = [var.cluster_admin_cidr]
}

run "reject_noncanonical_public_internet" {
  command = plan
  module {
    source = "../../modules/cluster"
  }

  variables {
    cluster_admin_cidr = ["192.0.2.1/0"]
  }

  expect_failures = [var.cluster_admin_cidr]
}
