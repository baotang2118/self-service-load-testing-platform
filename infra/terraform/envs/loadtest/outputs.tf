output "cluster_name" {
  description = "EKS cluster name."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Restricted public EKS API endpoint."
  value       = module.cluster.cluster_endpoint
}

output "ecr_repository_url" {
  description = "Private ECR repository URL for the sample service image."
  value       = module.ecr.repository_url
}

output "terraform_role_arn" {
  description = "GitHub Actions role ARN for Terraform operations."
  value       = module.github_oidc.role_arn
}

output "demo_deploy_role_arn" {
  description = "IAM role ARN for the Deploy demo services workflow."
  value       = module.demo_deploy.role_arn
}

output "github_runner_instance_id" {
  description = "EC2 instance ID of the self-hosted GitHub runner (SSM Session Manager target)."
  value       = module.github_runner.instance_id
}

output "vpc_id" {
  description = "Dedicated VPC ID."
  value       = module.network.vpc_id
}