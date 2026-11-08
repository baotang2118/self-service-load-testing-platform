variable "role_name" {
  description = "IAM role assumed by the GitHub Actions Terraform workflow."
  type        = string
}

variable "repository" {
  description = "Allowed GitHub repository in owner/name format."
  type        = string
}

variable "environments" {
  description = "GitHub Actions environments allowed to assume the OIDC role."
  type        = list(string)
}

variable "permissions_policy_arn" {
  description = "ARN of a separately reviewed IAM policy for Terraform operations."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}