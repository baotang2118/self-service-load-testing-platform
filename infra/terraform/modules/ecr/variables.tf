variable "name" {
  description = "ECR repository name."
  type        = string
}

variable "force_delete" {
  description = "Delete stored images when Terraform destroys this repository."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to ECR resources."
  type        = map(string)
  default     = {}
}