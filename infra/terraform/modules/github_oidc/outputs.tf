output "role_arn" {
  description = "IAM role ARN assumed by the GitHub Actions workflow."
  value       = aws_iam_role.terraform.arn
}