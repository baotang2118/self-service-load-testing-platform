variable "name" {
  description = "Name of the monthly AWS Budget."
  type        = string
}

variable "project_tag" {
  description = "Project tag value used to filter costs."
  type        = string
}

variable "limit_amount" {
  description = "Monthly budget alert threshold in USD."
  type        = number
}

variable "alert_email" {
  description = "Email address receiving budget alerts."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to the budget."
  type        = map(string)
  default     = {}
}