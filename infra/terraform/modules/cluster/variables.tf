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
  description = "Restricted IPv4 CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
  validation {
    condition     = length(var.cluster_admin_cidr) > 0 && alltrue([for cidr in var.cluster_admin_cidr : try(cidrnetmask(cidr) != "0.0.0.0", false)])
    error_message = "Provide at least one valid, restricted IPv4 CIDR; 0.0.0.0/0 is not allowed."
  }
}

variable "operator_role_arn" {
  description = "IAM role granted EKS cluster administrator access."
  type        = string
}

variable "additional_admin_principal_arns" {
  description = "Additional IAM principals granted EKS cluster administrator access."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to cluster resources."
  type        = map(string)
  default     = {}
}