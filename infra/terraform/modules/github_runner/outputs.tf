output "instance_id" {
  description = "Runner EC2 instance ID; connect with SSM Session Manager."
  value       = aws_instance.this.id
}

output "security_group_id" {
  description = "Runner security group ID."
  value       = aws_security_group.this.id
}

output "role_arn" {
  description = "Runner instance role ARN."
  value       = aws_iam_role.this.arn
}
