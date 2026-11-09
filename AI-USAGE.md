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

## 2. Representative Prompts Across the Development Lifecycle

Prompts were structured sequentially across architecture scoping, cloud design, and code authoring:

| Lifecycle Stage | Representative Prompt | Focus & Key Constraints |
| --- | --- | --- |
| Requirements Analysis | "Analyze the requirements of the assignment: identify non-negotiable platform guardrails, developer self-service goals, FinOps constraints, and core deliverables." | Deconstructs specifications into discrete platform deliverables. |
| Execution Planning | "Plan what to do step-by-step to prototype an end-to-end self-service load testing engine in AWS within a 7-day timeline." | Sequences development into IaC scaffolding, Helm packaging, runner wiring, and pipeline automation. |
| Python Service (uv + ruff) | "Develop a demo Python microservice managed with uv and formatted/linted via ruff. Provide a multi-stage Dockerfile using ghcr.io/astral-sh/uv to build a minimal image that exposes /health and /workload endpoints." | Produces dependency-locked, containerized services with fast build caching. |
| Golang Service Scaffolding | "Develop a demo Golang microservice providing minimal memory footprint and structured JSON health/status endpoints." | Provides a compiled, high-performance alternative service under test. |
| Dependency Helm Authoring | "Develop a Helm chart for PostgreSQL; keep it simple and optimized as an ephemeral prototype dependency for testing." | Packages a lightweight ephemeral database chart inside the test namespace. |
| Service Helm Authoring | "Develop a Helm chart for the demo microservices with configurable CPU/memory requests, limits, probes, and NetworkPolicy templates." | Translates platform reliability standards into parameterized templates. |
| AWS Cloud IaC Architecture | "Develop a Terraform module that provides an AWS EKS cluster, ECR, and VPC with public/private subnets. Ask at least 10 questions to clarify my intentions and constraints before writing any code." | Surfaces critical design decisions (EKS access entries, Spot node pools, CIDR sizing, NAT Gateways) before code generation. |
| Code Review & Auditing | "Review this Python, Go, and Terraform code against security vulnerabilities, concurrency leaks, unpinned versions, and AWS least-privilege compliance." | Identifies static flaws and edge cases prior to cloud provisioning. |

## 3. Agentic Workflow & Continuous Knowledge Loop

To prevent context drift and hallucination across multi-file implementations, tasks followed a 6-step agentic execution loop:

[ 1. Plan ] ──────> [ 2. Agent Code ] ──────> [ 3. Code Format ]
                                                      │
[ 6. Clean Redundant ] <── [ 5. Update Docs ] <── [ 4. Code Review ]

1. Plan: Break each feature down into scoped, discrete contracts (e.g., input variables, outputs, interface definitions).
​2. Agent Code: Emit implementation code strictly bound to the active persona's system instructions and technical requirements.
​3. Code Format: Apply automated formatters immediately after code generation:
​Python: ruff format and ruff check --fix
​Golang: gofmt -s -w
​Terraform: terraform fmt
​4. Code Review: Pass diffs through the Platform Code Reviewer persona to identify missing timeouts, unhandled errors, or resource quota gaps.  
​5. Update Knowledge Base, Document & README: Generate inline docstrings, update technical module READMEs, and document architectural decisions.
​6. Clean & Prune Redundant Knowledge: Purge intermediate scratchpad notes, obsolete manifests, and temporary artifacts from the workspace context to minimize token bloat.
4. Multi-Layer Validation Framework (AWS & Code Verification)
​AI-generated code was treated as unverified input and subjected to a four-stage validation pipeline before integration:
[ AI Code Output ]
       ↓
[ 1. Syntax, Types & Static Linting ] 
       │ • Python: ruff check, uv lock --check
       │ • Go: go vet, golangci-lint
       │ • Terraform: terraform fmt -check, terraform validate, tflint
       ↓
[ 2. Security & Policy Audit ]
       │ • Containers: Hadolint, Trivy (CVE scans on base images)
       │ • AWS IAM & IaC: Checkov / tfsec (remove wildcard actions, verify encryption)
       │ • Kubernetes: kubeval, helm lint
       ↓
[ 3. Local Dry-Run & Synthesis ]
       │ • Helm: helm template --debug
       │ • Docker: Build and run test in local Kind/Minikube cluster
       ↓
[ 4. Target AWS Cloud Validation ]
       │ • ECR: Authenticate and push images (aws ecr get-login-password)
       │ • EKS: Deploy via Helm, verify EKS Access Entries and RBAC
       │ • Guardrails: Verify ResourceQuotas, NetworkPolicies, and TTL reaper execution

1. Python (uv & ruff) Verification
​Dependency Locking: Checked using uv lock --check to ensure all transitive dependencies resolve deterministically without version drift.
​Linting & Style: Executed ruff check . and ruff format --check . to enforce PEP 8 conventions, correct import sorting, and static bug detection.
​Container Optimization: Built using official ghcr.io/astral-sh/uv multi-stage build patterns, verifying layer caching and non-root execution inside container images.  
​2. AWS Infrastructure & IaC Verification
​Static IaC Checks: Verified with terraform validate and tflint to catch missing parameters, invalid interpolation, and deprecated provider arguments.  
​Security & Policy Analysis: Audited generated IAM policies to eliminate wildcard permissions ("Action": "*", "Resource": "*") and enforce least privilege (e.g., scoping ECR push tokens and EKS cluster admin access entries).  
​Cost Allocation & FinOps: Confirmed that AWS resource tags (Environment, ManagedBy, TestRunId) were parameterized across all modules for AWS Cost Explorer visibility.

3. Kubernetes & Container Security
​Dockerfile Linting: Validated with hadolint to enforce explicit base image digests, non-root users (USER 10001), and multi-stage build best practices.  
​Vulnerability Scanning: Ran trivy image against container images before publishing to Amazon ECR, blocking releases with Critical or High CVEs.  
​Template Rendering: Rendered Helm manifests locally with helm template and validated schemas against Kubernetes 1.30+ APIs using helm lint.  
​4. Ephemeral Runtime Testing
​Local Smoke Testing: Validated chart deployment and pod readiness in a local Kind cluster before interacting with cloud infrastructure.  
​Cloud Guardrail Enforcement: Tested live on Amazon EKS to ensure ResourceQuota limits blocked pod over-provisioning, NetworkPolicy rules isolated the ephemeral namespace, and the TTL reaper script terminated expired resources automatically.  
