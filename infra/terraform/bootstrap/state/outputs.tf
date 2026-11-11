output "state_bucket_name" {
  description = "S3 bucket name to configure as the load-test environment backend."
  value       = aws_s3_bucket.terraform_state.id
}
output "terraform_role_policy_arn" {
  description = "Managed policy ARN to use as terraform_role_policy_arn / TERRAFORM_ROLE_POLICY_ARN."
  value       = aws_iam_policy.terraform_role.arn
}
