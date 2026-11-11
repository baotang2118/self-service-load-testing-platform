output "role_arn" {
  description = "IAM role ARN assumed by the GitHub Actions workflow."
  value       = aws_iam_role.terraform.arn
}

output "provider_arn" {
  description = "GitHub OIDC identity provider ARN."
  value       = aws_iam_openid_connect_provider.github.arn
}