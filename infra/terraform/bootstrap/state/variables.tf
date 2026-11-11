variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for the Terraform state."
  type        = string
}

variable "state_key" {
  description = "State object key (and lock-file prefix) the Terraform role may read and write."
  type        = string
  default     = "loadtest/terraform.tfstate"
}

variable "project_name" {
  description = "Resource name prefix of the load-test environment the Terraform role manages."
  type        = string
  default     = "geocomply-loadtest"
}