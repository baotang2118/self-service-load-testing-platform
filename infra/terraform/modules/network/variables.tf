variable "name" {
  description = "Name prefix used for network resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used for subnet discovery tags."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range for the VPC."
  type        = string
}

variable "availability_zone_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 2
  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "Use two or three availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per availability zone."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == var.availability_zone_count
    error_message = "Provide exactly one public subnet CIDR per availability zone."
  }
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per availability zone."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) == var.availability_zone_count
    error_message = "Provide exactly one private subnet CIDR per availability zone."
  }
}

variable "tags" {
  description = "Tags applied to network resources."
  type        = map(string)
  default     = {}
}