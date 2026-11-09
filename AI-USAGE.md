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

## 1. Tooling Ecosystem & Domain Personas

Development was orchestrated via GitHub Copilot, customized through domain-specific prompts, instructions, and workspace toolchains:

### Python Developer Persona (uv + ruff)

- **Instructions & Skills:** Enforces modern Python 3.12+ patterns using `uv` for dependency resolution and lockfile synchronization (`uv.lock`), alongside `ruff` for static analysis, formatting, and import sorting.
- **Focus:** Scaffolding lightweight, high-performance mock microservices (FastAPI), simulating realistic CPU spikes, database queries, and structured JSON health endpoints.

### Golang Developer Persona

- **Instructions & Skills:** Configured for idiomatic Go 1.22+ patterns, zero-allocation serialization, non-blocking HTTP handlers, standard context propagation, and explicit error handling.
- **Focus:** Scaffolding low-overhead target APIs, minimal container images (distroless/scratch), and Prometheus instrumentation endpoints.

### DevOps Engineer Persona (Helm, Kubernetes, CI/CD)

- **Instructions & Skills:** Constrained to production Kubernetes standards, parameterized Helm v3 best practices, secure defaults (read-only root filesystems, non-root users), and ephemeral namespace isolation.
- **Focus:** Authoring reusable Helm charts, defining LimitRanges, ResourceQuotas, default-deny NetworkPolicies, and CI/CD pipelines.

### AWS Cloud Engineering Persona

- **Instructions & Skills:** Enforces AWS Well-Architected Framework standards, modular Terraform 1.5+ design principles, least-privilege IAM policies, AWS VPC subnet topologies, ECR lifecycle policies, and EKS Spot/On-Demand managed node isolation.
- **Focus:** Architecting reusable Terraform modules for VPC, ECR, and EKS while proactively identifying requirement ambiguities before emitting code.

### Platform Code Reviewer Persona

- **Instructions & Skills:** Acts as an automated Staff Platform Reviewer evaluating output strictly on security compliance, performance bottlenecks, dead code, FinOps implications, and maintainability.
- **Focus:** Detecting unpinned versions, missing container resource limits, broad IAM wildcard statements, and Terraform state anti-patterns.
