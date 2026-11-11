output "role_arn" {
  description = "IAM role ARN for the demo deployment workflow."
  value       = aws_iam_role.this.arn
}
