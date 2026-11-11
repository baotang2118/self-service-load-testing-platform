variable "project_name" {
  description = "Prefix for resources created by this environment."
  type        = string
  default     = "geocomply-loadtest"
}

variable "aws_region" {
  description = "AWS region for the demo environment."
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "Kubernetes version supported by EKS in the selected region."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range for the dedicated VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet ranges, one per selected availability zone."
  type        = list(string)
  default     = ["10.40.0.0/20", "10.40.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet ranges, one per selected availability zone."
  type        = list(string)
  default     = ["10.40.32.0/20", "10.40.48.0/20"]
}

variable "cluster_admin_cidr" {
  description = "Restricted IPv4 CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
  validation {
    condition     = length(var.cluster_admin_cidr) > 0 && alltrue([for cidr in var.cluster_admin_cidr : try(cidrnetmask(cidr) != "0.0.0.0", false)])
    error_message = "Provide at least one valid, restricted IPv4 CIDR; 0.0.0.0/0 is not allowed."
  }
}

variable "operator_role_arn" {
  description = "IAM role ARN that you use with AWS CLI and that should administer this EKS cluster."
  type        = string
  validation {
    condition     = startswith(var.operator_role_arn, "arn:aws:iam::") && can(regex(":role/", var.operator_role_arn))
    error_message = "Provide an IAM role ARN for your operator role."
  }
}

variable "additional_admin_principal_arns" {
  description = "Additional IAM principals granted EKS cluster administrator access."
  type        = set(string)
  default = [
    "arn:aws:iam::260201160134:user/baotd",
  ]
}

variable "budget_alert_email" {
  description = "Email address for AWS Budget notifications."
  type        = string
  sensitive   = true
}

variable "monthly_budget_usd" {
  description = "Monthly cost alert threshold for resources tagged to this project."
  type        = number
  default     = 100
  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "The monthly budget must be greater than zero."
  }
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the Terraform role."
  type        = string
  default     = "baotang2118/self-service-load-testing-platform"
}

variable "github_repository_subject" {
  description = "Repository as it appears in the GitHub OIDC sub claim (immutable owner/repo IDs)."
  type        = string
  default     = "baotang2118@42202403/self-service-load-testing-platform@1450214603"
}

variable "github_environments" {
  description = "GitHub environments allowed to assume the Terraform role."
  type        = list(string)
  default     = ["terraform-plan", "terraform-apply", "terraform-destroy"]
}

variable "terraform_role_policy_arn" {
  description = "ARN of a reviewed IAM policy granting only the Terraform actions needed for this environment."
  type        = string
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete the ECR repository and its images during teardown."
  type        = bool
  default     = true
}