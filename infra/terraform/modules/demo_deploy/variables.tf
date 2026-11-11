variable "role_name" {
  description = "IAM role assumed by the demo deployment workflow."
  type        = string
}

variable "oidc_provider_arn" {
  description = "GitHub OIDC identity provider ARN."
  type        = string
}

variable "repository_subject" {
  description = "Repository as it appears in the OIDC sub claim."
  type        = string
}

variable "environment" {
  description = "GitHub environment allowed to assume the role."
  type        = string
  default     = "demo-deploy"
}

variable "cluster_name" {
  description = "EKS cluster the role deploys to."
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace the role may edit."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository the role may push to."
  type        = string
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
