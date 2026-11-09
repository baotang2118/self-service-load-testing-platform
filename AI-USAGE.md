# AI USAGE

AI tools: you can use any AI coding assistant or agent Copilot, Claude, Cursor, ChatGPT, etc.). 
Include an AI-USAGE.md, documenting: which tools you used, representative prompts and any 
agentic workflow or configuration you set up for this assignment, and how you validated what the 
AI produced before using it.

## Demo CRUD services

- Tool: GitHub Copilot in VS Code, with repository exploration and a reviewed
	implementation plan before editing.
- Representative request: "add 2 demo CRUD microservices + its helm charts:
	service 1: python django; service 2: golang; both services can connect to
	postgresql and provide CRUD. keep it simple as this is a prototype."
- The user selected independent records for the two services. Copilot used
	repository exploration agents during planning and implemented the services,
	charts, Compose stack, tests, and documentation.
- Validation: Django pytest, Ruff, migration consistency, and Django system
	checks; Go tests and `go vet`; Helm lint and template rendering with
	dependency overrides; and a YAML parse of the Compose file. The two HTTP
	integration tests were skipped because Docker, Kubernetes, and PostgreSQL
	executables were unavailable. The live stack and container images
	therefore still require verification in an environment with Docker or a
	Kubernetes cluster.

## AWS Terraform foundation

- Tool: GitHub Copilot in VS Code, with read-only repository exploration and a
	reviewed implementation plan before editing.
- Representative request: "Start implementation" after selecting AWS, a
	dedicated short-lived EKS demo, ECR, a dedicated VPC, GitHub OIDC, budget
	alerts, and protected teardown.
- Copilot added reusable network, EKS, ECR, GitHub OIDC, and budget modules, an
	S3 state bootstrap, an AWS-only Terraform workflow, and setup documentation.
	The AWS resources were not applied.
- Validation: VS Code reported no diagnostics for the edited Terraform and
	workflow files, and `git diff --check` passed. Terraform, OpenTofu, an HCL
	parser, and an action linter were unavailable, so Terraform formatting,
	initialization, validation, plans, and GitHub workflow execution remain
	unverified. Review the generated IAM permissions policy and AWS cost estimate
	before using the workflow in an account.

## AI-Assisted Engineering Report: Ephemeral Load Testing Engine on AWS

This report documents the systematic integration of generative AI into the architecture, implementation, and verification of the self-service ephemeral load testing engine on Amazon Web Services (AWS). Rather than relying on unstructured autocompletion, development followed a persona-driven, multi-stage agentic workflow with explicit linting, security scanning, and cloud policy validation guardrails.
