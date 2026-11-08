locals {
  tags = {
    Project     = var.project_name
    Environment = "demo"
    ManagedBy   = "Terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name                    = var.project_name
  cluster_name            = var.project_name
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = 2
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  tags                    = local.tags
}

module "cluster" {
  source = "../../modules/cluster"

  name                            = var.project_name
  kubernetes_version              = var.cluster_version
  private_subnet_ids              = module.network.private_subnet_ids
  public_subnet_ids               = module.network.public_subnet_ids
  cluster_admin_cidr              = var.cluster_admin_cidr
  operator_role_arn               = var.operator_role_arn
  additional_admin_principal_arns = var.additional_admin_principal_arns
  tags                            = local.tags
}

module "ecr" {
  source = "../../modules/ecr"

  name         = "${var.project_name}-sample-service"
  force_delete = var.ecr_force_delete
  tags         = local.tags
}

module "github_oidc" {
  source = "../../modules/github_oidc"

  role_name              = "${var.project_name}-terraform"
  repository             = var.github_repository
  environments           = var.github_environments
  permissions_policy_arn = var.terraform_role_policy_arn
  tags                   = local.tags
}

module "budget" {
  source = "../../modules/budget"

  name         = "${var.project_name}-monthly"
  project_tag  = var.project_name
  limit_amount = var.monthly_budget_usd
  alert_email  = var.budget_alert_email
  tags         = local.tags
}