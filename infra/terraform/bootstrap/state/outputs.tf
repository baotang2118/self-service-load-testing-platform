output "state_bucket_name" {
  description = "S3 bucket name to configure as the load-test environment backend."
  value       = aws_s3_bucket.terraform_state.id
}