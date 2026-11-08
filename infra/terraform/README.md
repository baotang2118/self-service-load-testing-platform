# AWS Terraform environment

This configuration creates a short-lived demo VPC, an EKS cluster with one small managed node group, an ECR repository, GitHub Actions OIDC trust, and a project-tagged AWS Budget. It does not deploy the Django application, Postgres, Redis, or container images.

## Layout

- `bootstrap/state/`: one-time S3 state bucket setup, kept separate from the demo stack.
- `envs/loadtest/`: AWS region-specific demo environment composition.
- `modules/network/`: two-AZ VPC, public/private subnets, routing, and one NAT gateway.
- `modules/cluster/`: EKS control plane, private managed node group, operator access, and short-retention control-plane logs.
- `modules/ecr/`: encrypted private image repository, scan-on-push, immutable tags, and image lifecycle.
- `modules/github_oidc/`: repository/environment-specific GitHub OIDC role trust.
- `modules/budget/`: monthly AWS Budget alert filtered by the `Project` resource tag.
- `.github/workflows/terraform.yml`: manual plan/apply/destroy and configured expiry cleanup.

## Before provisioning

You need Terraform 1.10.5, AWS CLI credentials for a sandbox account, `kubectl`, and an IAM role ARN that you use as the cluster operator. Your AWS principal must be allowed to create the network, EKS, ECR, budget, state bucket, and IAM resources. Do not apply this stack to an account you do not own or administer.

Set these inputs before running Terraform:

- `cluster_admin_cidr`: your current public IP as a CIDR, usually `a.b.c.d/32`. The EKS API is public but restricted to this CIDR; `0.0.0.0/0` is rejected.
- `operator_role_arn`: your AWS IAM role ARN. It receives EKS cluster-admin permissions, so use a role you control.
- `budget_alert_email`: email address for AWS Budget notifications.
- `terraform_role_policy_arn`: ARN of a reviewed IAM policy for the GitHub Terraform role. Keep this policy limited to the required Terraform resources and state bucket; do not attach `AdministratorAccess`.

AWS Budgets filters by the `Project` tag. Activate the `Project` user-defined cost allocation tag in the AWS Billing console before relying on the filtered budget. Budget notifications are delayed alerts, not a hard spending cap.

## State bucket bootstrap

Use a unique S3 bucket name. The bucket is encrypted, versioned, blocked from public access, requires TLS, and has Terraform `prevent_destroy` enabled.

```powershell
terraform -chdir=infra/terraform/bootstrap/state init
terraform -chdir=infra/terraform/bootstrap/state apply -var="state_bucket_name=YOUR-UNIQUE-STATE-BUCKET"
```

Keep the bootstrap state file secure. Do not destroy the state bucket as part of demo cleanup; it contains the main stack's Terraform state and lock file.

## Local setup

Authenticate to the sandbox account first (for example, with `aws configure sso`) and check the active identity with `aws sts get-caller-identity`. In PowerShell, set the required variables:

```powershell
$env:TF_VAR_cluster_admin_cidr = "YOUR_PUBLIC_IP/32"
$env:TF_VAR_operator_role_arn = "arn:aws:iam::ACCOUNT_ID:role/YOUR_OPERATOR_ROLE"
$env:TF_VAR_budget_alert_email = "you@example.com"
$env:TF_VAR_terraform_role_policy_arn = "arn:aws:iam::ACCOUNT_ID:policy/YOUR_REVIEWED_TERRAFORM_POLICY"
```

Initialize the environment with the S3 bucket created above. Replace the bucket name in the command:

```powershell
terraform -chdir=infra/terraform/envs/loadtest init `
  -backend-config="bucket=YOUR-UNIQUE-STATE-BUCKET" `
  -backend-config="key=loadtest/terraform.tfstate" `
  -backend-config="region=us-east-1"
terraform -chdir=infra/terraform/envs/loadtest fmt -recursive
terraform -chdir=infra/terraform/envs/loadtest validate
terraform -chdir=infra/terraform/envs/loadtest plan
```

Review the plan and an AWS Pricing Calculator estimate before applying. Include the EKS control plane, EC2 worker, NAT gateway, public IPv4 addresses, CloudWatch logs, and expected data transfer. EKS and NAT gateway charges continue while the environment is idle. One NAT gateway is used to lower demo cost; it is a network availability and cross-AZ traffic tradeoff.

Only after reviewing the plan and cost estimate, apply:

```powershell
terraform -chdir=infra/terraform/envs/loadtest apply
aws eks update-kubeconfig --region us-east-1 --name geocomly-loadtest
kubectl get nodes
```

The EKS public endpoint is restricted to your configured IP. Update `TF_VAR_cluster_admin_cidr` if your IP changes. GitHub-hosted runners do not receive Kubernetes access and cannot deploy workloads.

## GitHub Actions setup

The workflow trusts only `baotang2118/self-service-load-testing-platform` through four exact GitHub environments: `terraform-plan`, `terraform-apply`, `terraform-destroy`, and `terraform-expiry`. Restrict all four environments to the `main` branch. Require reviewers for apply and manual destroy; leave expiry without a reviewer so scheduled cleanup can run automatically. Set these repository variables and secret:

- Variables: `TERRAFORM_AWS_ROLE_ARN`, `TERRAFORM_ROLE_POLICY_ARN`, `TF_STATE_BUCKET`, `CLUSTER_ADMIN_CIDR`, `OPERATOR_ROLE_ARN`.
- Secret: `BUDGET_ALERT_EMAIL`.
- Optional variable: `DEMO_EXPIRES_AT` as a UTC date/time such as `2026-11-15T08:00:00Z`.

The workflow supports manual `plan`, `apply`, and `destroy`. Its daily scheduled run destroys the stack after `DEMO_EXPIRES_AT`; an empty expiry leaves the stack untouched. The Terraform role policy must also permit read/write access to the configured state key and its `.tflock` object. The first state bootstrap and initial role setup are performed locally.

## Cleanup

For immediate cleanup, use the protected GitHub Actions `destroy` operation or run:

```powershell
terraform -chdir=infra/terraform/envs/loadtest destroy
```

The demo ECR repository is configured to delete its stored images during stack destruction. Confirm the EKS cluster, node group, NAT gateway, and VPC are gone. Keep the S3 state bucket until that confirmation is complete. Remove it only as a separate, deliberate cleanup after archiving or discarding both bootstrap and environment state.

## Current boundary

This infrastructure slice creates the cloud foundation and cluster. Kubernetes namespace quotas, per-test NetworkPolicies, the TTL janitor, and the load-test workflow are follow-on platform modules; this stack does not yet provide the complete self-service load-test application flow.