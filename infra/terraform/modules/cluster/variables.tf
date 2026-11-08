variable "name" {
  description = "EKS cluster and IAM role name prefix."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version supported by EKS in the selected region."
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets used by the EKS control plane and managed nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets tagged for internet-facing Kubernetes load balancers."
  type        = list(string)
}

variable "cluster_admin_cidr" {
  description = "Restricted CIDR allowed to reach the public EKS API endpoint."
  type        = string
  validation {
    condition     = can(cidrhost(var.cluster_admin_cidr, 0)) && var.cluster_admin_cidr != "0.0.0.0/0"
    error_message = "The EKS API CIDR must be valid and must not be 0.0.0.0/0."
  }
}

variable "operator_role_arn" {
  description = "IAM role granted EKS cluster administrator access."
  type        = string
}

variable "tags" {
  description = "Tags applied to cluster resources."
  type        = map(string)
  default     = {}
}