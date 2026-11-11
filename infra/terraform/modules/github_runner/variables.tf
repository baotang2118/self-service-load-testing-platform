variable "name" {
  description = "Prefix for the runner resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC that hosts the runner."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet for the runner; it needs NAT egress to GitHub, ECR, and SSM."
  type        = string
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group; the runner is allowed to reach its API on 443."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository (owner/name) the runner registers to."
  type        = string
}

variable "runner_labels" {
  description = "Custom runner labels; self-hosted, linux, and x64 are added automatically."
  type        = list(string)
  default     = ["demo-deploy"]
}

variable "pat_parameter_name" {
  description = "Name of an existing SSM SecureString parameter holding a GitHub token that can create repository runner registration tokens."
  type        = string
  validation {
    condition     = startswith(var.pat_parameter_name, "/")
    error_message = "The parameter name must start with '/'."
  }
}

variable "instance_type" {
  description = "EC2 instance type; image builds need more than 2 GiB of memory."
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size_gb" {
  description = "Root volume size for Docker images and build caches."
  type        = number
  default     = 40
}

variable "runner_version" {
  description = "actions/runner release without the leading v."
  type        = string
  default     = "2.338.2"
}

variable "runner_sha256" {
  description = "SHA-256 of actions-runner-linux-x64-<runner_version>.tar.gz."
  type        = string
  default     = "baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40"
}

variable "kubectl_version" {
  description = "kubectl release without the leading v; keep within one minor version of the cluster."
  type        = string
  default     = "1.37.2"
}

variable "kubectl_sha256" {
  description = "SHA-256 of the linux/amd64 kubectl binary."
  type        = string
  default     = "c04487523e7aa7d1493f7808174c899db93d7a9cf57531420cd76b9bd415f8f4"
}

variable "helm_version" {
  description = "Helm 3 release without the leading v."
  type        = string
  default     = "3.22.1"
}

variable "helm_sha256" {
  description = "SHA-256 of helm-v<helm_version>-linux-amd64.tar.gz."
  type        = string
  default     = "896cf63684a42a723d61c980369d6e588330927deb13676ca0d85006dd6da0ea"
}

variable "tags" {
  description = "Tags applied to runner resources."
  type        = map(string)
  default     = {}
}
