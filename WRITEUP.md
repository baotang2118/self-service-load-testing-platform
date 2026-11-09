# Self-Service Ephemeral Load Testing Engine — Architecture & Design Writeup

Written writeup (WRITEUP.md, 2-3 pages maximum). 
○ Context you assumed and why. 
○ Alternatives you considered for the major decisions (env provisioning, load 
generator, IaC layout, developer interface). What you picked and why. 
○ Trade-offs you accepted (cost, complexity, blast radius, developer experience, 
security).

## 1. Assumed Context & Problem Statement

### Organizational & Technical Context
We assume a mid-sized product engineering organization operating ~50 containerized microservices on AWS (with multi-cloud portability in mind)[cite: 2, 6]. Product squads own their services end-to-end—implemented primarily in **Python (Django)** and **Golang** backed by **PostgreSQL**[cite: 1]—and deploy to Kubernetes via **Helm** and **GitHub Actions**[cite: 1, 2, 6].

Historically, performance validation required filing a ticket with DevOps to manually provision infrastructure, deploy target services, stand up load generators, and tear down resources afterward[cite: 2]. This ticket-driven model created a delivery bottleneck, consumed senior platform capacity on repetitive toil, and caused teams to skip load testing under tight deadlines[cite: 2].

### Core Design Objective
This platform shifts DevOps from a **"Serve" (ticket-driven)** model to an **"Enable" (self-service)** model[cite: 2, 6]. Product engineers can trigger isolated, reproducible load tests on demand via GitHub Actions without DevOps intervention, while the platform automatically enforces security isolation, resource quotas, FinOps cost visibility, and guaranteed teardown.

---

## 2. Architecture Overview & Separation of Concerns

To balance fast test startup times with clean blast-radius isolation, the architecture separates **Base Cloud Foundation (Day-0/Day-1 IaC)** from **Ephemeral Test Execution (Day-2 Self-Service Runtime)**[cite: 2]:

1. **Cloud Foundation Layer (`infra/terraform`):** Provisioned via modular Terraform (`>= 1.10.0`, executed on `1.10.5`) and governed by a manually triggered GitHub Actions workflow (`terraform.yml`)[cite: 2]. It stands up a shared Amazon EKS cluster (`geocomply-loadtest`, Kubernetes `1.33`), a two-AZ VPC, a hardened private ECR registry, passwordless GitHub OIDC authentication, and automated AWS Budget alerts.
2. **Ephemeral Workload & Guardrail Layer (`charts/` & Self-Service CI/CD):** When a developer triggers a load test, the pipeline dynamically creates an isolated Kubernetes namespace (`loadtest-<run-id>`) on the shared EKS cluster[cite: 1, 2]. Inside that namespace, Helm deploys the target microservice (Django or Golang), an ephemeral seeded PostgreSQL instance, namespace-scoped `ResourceQuota`/`LimitRange` policies, a default-deny `NetworkPolicy`, and the load generator job[cite: 1, 2].

---

## 3. Developer Experience (DX): Low-Friction Self-Service Flow

A self-service platform succeeds only if it is easier to use than filing a ticket[cite: 2]. The developer workflow follows a streamlined 4-step lifecycle[cite: 2]:

1. **Author & Version Control:** Developers define or adjust their load test scenario alongside their service code and open a Pull Request (or navigate to the GitHub Actions **Run workflow** dispatch UI)[cite: 1, 2].
2. **One-Click Trigger:** The developer triggers the self-service workflow by applying a PR label (e.g., `run-load-test`) or invoking `workflow_dispatch` with bounded parameters: target service (`django` or `golang`), target virtual users/RPS, and test duration (capped at platform limits)[cite: 1, 2].
3. **Automated Ephemeral Lifecycle:**
   - Builds and scans the candidate container image, pushing it with an immutable tag to the private Amazon ECR repository[cite: 1].
   - Creates a dedicated Kubernetes namespace labeled with `ttl-hours=2` and cost-allocation metadata[cite: 1].
   - Deploys the ephemeral PostgreSQL chart seeded with deterministic test fixtures, followed by the microservice Helm chart and namespace security/quota guardrails[cite: 1].
   - Verifies `/health` readiness probes, executes the load generator against `/workload` endpoints, and captures latency (p50/p95/p99), RPS, and error-rate telemetry[cite: 1, 2].
4. **Actionable Feedback & Zero-Touch Teardown:** The pipeline posts a formatted Markdown summary table (latency percentiles, throughput, threshold pass/fail verdict) directly onto the Pull Request (and uploads raw JSON/HTML artifacts to GitHub Actions), then immediately tears down the test namespace in an `if: always()` step[cite: 1, 2].

---

## 4. Platform Guardrails, FinOps & Security Controls

Running load tests in shared cloud infrastructure introduces risks of runaway cloud spend, noisy-neighbor starvation, and accidental cross-environment traffic[cite: 2]. We enforce guardrails across four layers[cite: 1, 2]:

### Cost & FinOps Guardrails
* **Automated AWS Budgets (`modules/budget`):** Provisions a monthly AWS Budget defaulting to **$100/month**, filtered by the `Project` cost-allocation tag, with automated email notifications at **80% actual** and **100% forecasted** spend.
* **Right-Sized Compute & NAT Topology (`modules/network`, `modules/cluster`):** Uses a single NAT Gateway across two Availability Zones and a bounded EKS managed node group (`t3.medium`, `min=1`, `desired=1`, `max=2`, 30 GB disk) to keep baseline prototype costs minimal while allowing controlled horizontal burst.
* **ECR Storage Lifecycle (`modules/ecr`):** Enforces a 30-image retention lifecycle policy so ephemeral test builds never accumulate unbounded storage costs.
* **Controlled Infrastructure Lifecycle (`terraform.yml`):** Because EKS control planes and NAT gateways incur hourly charges while idle, the foundation workflow supports an explicit, reviewer-gated `terraform-destroy` environment so the entire cloud stack can be torn down cleanly between test campaigns (`force_delete = true` on ECR).

### Enforced Teardown (Dual-Layer Defense)
* **Pipeline-Level Teardown:** The self-service CI/CD workflow executes `helm uninstall` and `kubectl delete namespace` inside an `always()` block so failed or canceled tests still clean up immediately[cite: 1].
* **Cluster-Level TTL Reaper:** An in-cluster Kubernetes CronJob (`ttl-reaper`) sweeps namespaces labeled `ephemeral-loadtest=true` and forcibly deletes any namespace exceeding its `expires-at` timestamp, preventing orphaned resources if a CI runner crashes mid-flight[cite: 1].

### Security & Blast-Radius Isolation
* **Passwordless OIDC & Environment Gates (`modules/github_oidc`):** Eliminates static AWS access keys. GitHub Actions authenticates via IAM OIDC federated trust strictly scoped to `baotang2118/self-service-load-testing-platform` and the `terraform-plan`, `terraform-apply`, and `terraform-destroy` GitHub Environments (restricted to `main` with mandatory human reviewers for `apply`/`destroy`).
* **Hardened Cluster Access (`modules/cluster`):** Configures EKS Access Entries and cluster-admin policy associations restricted to explicit operator IAM roles (`OPERATOR_ROLE_ARN`). Public control-plane endpoint access is locked down via CIDR allowlisting (`cluster_admin_cidr`), while worker nodes run strictly in private subnets.
* **Container Registry Security (`modules/ecr`):** Enforces AES-256 encryption at rest, immutable image tags, and automated vulnerability scanning on push (`scan_on_push = true`)[cite: 1].
* **In-Cluster Quotas & Network Isolation:** Every test namespace receives a `ResourceQuota` and `LimitRange` capping aggregate CPU, memory, and pod counts, paired with a default-deny `NetworkPolicy` that restricts traffic solely to the load generator, the microservice under test, and its namespace-local PostgreSQL instance[cite: 1, 2].

---

## 5. Major Architectural Decisions & Alternatives Considered

### Decision 1: Ephemeral Environment Provisioning
* **Chosen:** **Namespace-per-test on a shared Amazon EKS cluster** (with full-stack Terraform teardown capability when the platform is idle)[cite: 1, 2].
* **Alternatives Considered:**
  * *Dedicated EKS Cluster per test:* Provides hard control-plane isolation but takes 15–20 minutes to provision via Terraform and incurs $0.10/hour per cluster control plane, destroying developer feedback loops[cite: 2].
  * *Serverless Containers (ECS Fargate / Cloud Run):* Fast startup, but diverges from our production Kubernetes/Helm deployment topology and networking behaviors[cite: 2].
* **Why Chosen:** Provisioning a Kubernetes namespace and Helm release takes <30 seconds, preserves 1:1 parity with production Helm manifests, and amortizes baseline EKS and NAT Gateway costs across all product teams[cite: 1, 2].

### Decision 2: Infrastructure as Code (IaC) Layout & State Management
* **Chosen:** **Layered Modular Terraform (`bootstrap/state`, `envs/loadtest`, and reusable `modules/`) with native S3 state locking (`use_lockfile = true`).**
* **Alternatives Considered:**
  * *Monolithic Terraform Root Module:* Faster to write initially, but couples state bootstrapping with runtime resources and prevents module reuse across staging/production[cite: 2].
  * *Legacy DynamoDB State Locking:* Historically required an extra DynamoDB table resource; Terraform 1.10+ supports native S3 lockfiles (`use_lockfile = true`), reducing infrastructure sprawl.
* **Why Chosen:** Separating `bootstrap/state` (encrypted, versioned, TLS-enforced S3 bucket with `prevent_destroy`) ensures state durability across full environment teardowns. Decomposing `network`, `cluster`, `ecr`, `github_oidc`, and `budget` into `modules/` makes each component independently reusable and testable[cite: 2].

### Decision 3: Service Dependencies (Database & Downstream State)
* **Chosen:** **Ephemeral in-namespace PostgreSQL container seeded with deterministic fixtures[cite: 1, 2].**
* **Alternatives Considered:**
  * *Shared Staging AWS RDS Instance:* Causes lock contention and noisy-neighbor interference when multiple teams run concurrent load tests, and risks polluting shared staging data[cite: 2].
  * *Ephemeral RDS per Test:* Takes 10+ minutes to spin up and adds unnecessary hourly database costs[cite: 2].
* **Why Chosen:** Deploying a lightweight PostgreSQL Helm release inside the test namespace spins up in seconds, guarantees zero cross-test data contention, and vanishes automatically when the namespace is deleted[cite: 1, 2].

### Decision 4: Load Generator & Developer Interface
* **Chosen:** **Kubernetes-native Load Runner (k6 / Locust) orchestrated via GitHub Actions (PR Label / `workflow_dispatch`)[cite: 2].**
* **Alternatives Considered:**
  * *Standalone Web UI Portal (e.g., Backstage or custom React app):* High maintenance overhead and duplicates authentication/RBAC that already exists in GitHub[cite: 2].
  * *External SaaS Load Generators:* Introduces public ingress exposure requirements and per-virtual-user licensing costs[cite: 2].
* **Why Chosen:** Running the load generator inside the cluster avoids external ingress bottlenecks, while GitHub Actions meets developers where they already review code and inspect CI checks[cite: 2].

---

## 6. Trade-offs Accepted

| Dimension | Trade-off Accepted | Rationale & Mitigation |
| :--- | :--- | :--- |
| **Cost vs. High Availability** | Provisioned a **single NAT Gateway** serving private subnets across both AZs and a single `t3.medium` node group (`max=2`). | Saves ~$32/month in redundant NAT hourly charges for a non-production testing environment. Multi-AZ NAT can be enabled via a single module variable for production. |
| **Isolation vs. Provisioning Speed** | Shared EKS control plane and worker kernel across concurrent test namespaces rather than VM-level isolation per test[cite: 2]. | Trades hardware-level isolation for sub-minute test startup times. Mitigated via strict `ResourceQuota`, `LimitRange`, and default-deny `NetworkPolicy` per namespace[cite: 1, 2]. |
| **Idle Cloud Cost vs. Instant Readiness** | EKS control plane ($0.10/hr) and NAT Gateway ($0.045/hr) incur baseline costs while running. | Accepted during active testing windows so namespace creation is instantaneous; mitigated via AWS Budget alerts and one-click `terraform-destroy` GitHub Actions workflow when idle. |
| **Dependency Fidelity vs. Speed** | Containerized ephemeral PostgreSQL instead of managed AWS RDS[cite: 1, 2]. | Does not benchmark RDS-specific storage IOPS limits, but accurately benchmarks microservice CPU, memory, connection pooling, and query serialization without 15-minute wait times[cite: 1, 2]. |
| **Financial Alerting vs. Hard Stop** | AWS Budgets alerts at 80% actual / 100% forecast rather than hard account suspension. | Prevents abrupt mid-test state corruption during Terraform operations while giving platform operators early visibility. |

---

## 7. What I Would Build Next (Week 2 Roadmap)

If given an additional week to evolve this prototype into a multi-team production platform, I would prioritize five enhancements[cite: 2]:

1. **Dedicated Spot Node Pool for Load Generators:** Add a second EKS Managed Node Group in `modules/cluster` backed by **EC2 Spot instances** with dedicated taints (`workload=loadgen:NoSchedule`)[cite: 1]. This guarantees load-generator pods never compete for CPU/memory with the microservice under test while cutting compute cost by up to 70%[cite: 1, 7].
2. **Real-Time Observability with LGTM Stack (Grafana, Prometheus/Mimir, Loki):** Deploy Prometheus and Loki in-cluster so the PR comment includes a direct deep-link to a pre-filtered Grafana dashboard (`?var-namespace=loadtest-<id>&from=...&to=...`) for real-time flamegraphs and log correlation[cite: 2, 6].
3. **Automated SLO Baseline Gating & Regression Detection:** Store historical test metrics in S3/PostgreSQL and automatically fail the PR check if p99 latency degrades by >15% compared to the `main` branch baseline[cite: 2, 6].
4. **Multi-Cloud Portability (GCP / GKE Parity):** Add a parallel `envs/loadtest-gcp/` root and `modules/gke/` implementation so microservices migrating from AWS to GCP can run identical load test suites across both clouds[cite: 2, 6].
5. **Service Mesh Traffic Shadowing / Chaos Injection:** Integrate Istio/Linkerd fault injection or WireMock latency profiles to test how microservices degrade when downstream third-party APIs throttle or time out under peak load[cite: 2, 6].
