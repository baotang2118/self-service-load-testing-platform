# Self-Service Ephemeral Load Testing Engine: Writeup

Each item below is marked **Built** (in the repo today) or **Designed** (specified, not yet implemented). The README lists the same gaps.

## 1. Assumed context

- About 50 containerized services on AWS, mostly Django and Go with PostgreSQL, deployed to Kubernetes with Helm. CI is GitHub Actions.
- One AWS account, no production data in tests, and teams own their Dockerfiles, Helm values and test scenarios.
- Assume an existing non-production EKS cluster has enough spare capacity for bounded tests and can support the required isolation controls. Do not run these tests on a production cluster.
- Typical test: one service, up to a few hundred virtual users, 5-15 minutes, a handful of concurrent tests across the company. Small-scale assumptions like these justify a shared cluster and a small node pool. If tests were much bigger or more frequent, I would revisit them (see section 6).
- Goal: move DevOps from running tests for teams to providing a platform they use without tickets. Platform guardrails replace the human gatekeeper.

## 2. Developer flow

1. The developer keeps a small `loadtest` config next to the service (target, virtual users, duration, thresholds).
2. They trigger it with a PR label or `workflow_dispatch`. Values above fixed platform caps (virtual users, duration) are rejected.
3. The pipeline builds the image, creates a quota-limited namespace, deploys the service and its Postgres, runs the load generator, and collects results.
4. A summary (p50/p95/p99, RPS, error rate, threshold verdict) is posted on the PR and the raw JSON is kept as an artifact. The job fails on a threshold breach.
5. The namespace is deleted in an `if: always()` step. A scheduled reaper removes anything that leaks.

| Step | Status |
| :--- | :--- |
| Sample targets: Django and Go CRUD APIs with `/health/live`, `/health/ready`, Dockerfiles, Helm charts, Compose file, tests | **Built** |
| Terraform foundation and its manual plan/apply/destroy workflow | **Built** |
| Load-test workflow, config schema, k6 runs, PR comment | **Designed** |
| Per-test namespace, quota, network policy, reaper | **Designed** |

## 3. Developer experience

The intended experience lets a service developer trigger a load-test pipeline directly from the service repo—using a PR label or manual dispatch—without filing a DevOps ticket or waiting for the platform team. It reuses the team's existing GitHub workflow instead of requiring a new portal or AWS credentials. The key is to make adoption familiar, configuration safe, and results useful for the next engineering decision.

| Developer need | Experience | Status |
| :--- | :--- | :--- |
| Start a test | Keep a small, version-controlled config with the service and run the pipeline from a PR label or manual dispatch, without a DevOps ticket. | **Designed** |
| Validate changes locally | Use the Django and Go sample services with the existing Compose or Helm setup; the end-to-end load-test flow is not yet available locally. | **Built** (samples); **Designed** (load-test flow) |
| Understand the result | See p50/p95/p99, RPS, error rate, and threshold verdict in the PR; inspect the raw JSON artifact for detail. | **Designed** |
| Catch mistakes before provisioning | Validate the config and enforce fixed caps before creating test resources, with an actionable error for invalid values. | **Designed** |

This keeps the feedback loop close to code review while avoiding unnecessary infrastructure setup for routine iterations. The current repository provides representative services and deployment examples, but the self-service testing experience itself is still a design, not a working feature.

## 4. Decisions and alternatives

| Decision | Picked | Alternatives | Why |
| :--- | :--- | :--- | :--- |
| Environment | Namespace per test on an existing non-production EKS cluster | Dedicated load-test EKS cluster; cluster per test; ECS Fargate; VMs | Reuses the existing control plane and Helm deployments, avoiding another always-on cluster and per-test cluster provisioning. Isolation and capacity are prerequisites, not guarantees of namespaces alone. |
| Load generator | k6, running in-cluster | Locust, Gatling, JMeter, SaaS | JS scenarios, built-in thresholds, JSON summary, small footprint. Locust is Python, which fits our stack, but k6 has native pass/fail thresholds. SaaS needs public ingress and per-user licensing. |
| IaC | Terraform, split into `bootstrap/state`, `envs/loadtest` and reusable `modules/` (network, cluster, ecr, github_oidc, budget), S3 native state locking | One root module; CDK; Pulumi | Modules are reusable and state survives teardown of the environment. S3 `use_lockfile` avoids a DynamoDB table. |
| CI/CD | GitHub Actions with OIDC, no static keys | GitLab CI, Jenkins | Teams already live in GitHub, and a reusable workflow means a small adoption cost per service. |
| Dependencies | Postgres container inside each test namespace, seeded with fixtures | Shared staging RDS; RDS per test; real downstream services | No data contention or leakage between tests, it starts in seconds, and it disappears with the namespace. The Postgres chart exists, but fixture seeding is **Designed**. |
| Interface | Config in the repo plus a PR label or dispatch | Portal, Backstage, CLI | Lowest friction, versioned with the code, and it reuses GitHub authentication and review. Nothing new to maintain. |

### Choosing an operating platform

These are heuristics, not service-count limits: traffic patterns, availability requirements, team skills and actual costs matter more than the count alone.

- **4-5 services, predictable traffic:** Docker Compose on a couple of EC2 instances behind a load balancer can be sufficient and simple. The team must still handle deployments, host failures, scaling and maintenance; Compose is not a multi-host orchestrator.
- **Up to about 15 services, occasional traffic peaks:** ECS can be budget-friendly, especially when its managed orchestration reduces operational work. Cost depends on capacity, utilization and pricing; Fargate can be convenient but is not always cheaper than EC2-backed capacity.
- **50 or more services:** EKS becomes attractive when the company already uses Kubernetes and Helm, benefits from the broader open-source ecosystem, and wants portability beyond AWS. Kubernetes reduces reliance on a single orchestrator but does not eliminate AWS-specific integrations or migration work. EKS adds control-plane and operational costs and needs a capable DevOps/platform team.

### Dedicated load-test cluster vs. an existing cluster

| Option | Benefits | Costs and risks |
| :--- | :--- | :--- |
| Dedicated EKS cluster for load testing | Separate control plane and nodes reduce interference with other workloads; capacity and policies can be tuned for tests. | Another cluster and node capacity cost money and require upgrades and operations; provisioning it on demand adds startup time. A cluster in the same AWS account still shares account-level resources and limits. |
| New namespace per test in an existing non-production EKS cluster | Reuses the control plane, nodes and familiar Helm tooling; namespaces start quickly and are removed after each test. | Namespaces share the control plane, nodes and kernels. Noisy neighbors, capacity exhaustion, cluster-wide permissions or misconfigured network policies can affect other workloads; results can also be skewed by contention. |

We choose the **existing non-production cluster** for the assumed small, infrequent tests: it avoids a second cluster's fixed cost and lets developers start tests quickly without a DevOps ticket. This is safe only when spare capacity and effective namespace quotas, network policies, least-privilege RBAC and teardown are in place; those per-test controls remain **Designed**. If isolation or capacity is inadequate, use a dedicated load-test cluster instead. The **Built** Terraform foundation provisions a separate demo cluster and can be destroyed between campaigns; reusing an existing cluster is the target design, not an implemented integration.

## 5. Guardrails and how each is enforced

| Guardrail | Mechanism | Status |
| :--- | :--- | :--- |
| Cost | AWS Budget ($100/month default, filtered by the `Project` tag, alerts at 80% actual and 100% forecast); bounded node group (`t3.medium`, 1 to 2 nodes); ECR keeps 30 images; the demo cluster can be destroyed between campaigns via a reviewer-gated destroy | **Built** (demo foundation) |
| Credentials | GitHub OIDC role scoped to one repository and to the plan/apply/destroy environments; no static AWS keys | **Built** |
| Cluster access | EKS access entries for named operator roles only; public endpoint limited to an admin CIDR; nodes in private subnets | **Built** |
| Image supply chain | Private ECR, immutable tags, scan on push | **Built** |
| Teardown | Pipeline `always()` cleanup plus a CronJob reaper that deletes namespaces past their `expires-at` label | **Designed** |
| Isolation | Per-namespace `ResourceQuota`, `LimitRange` and default-deny `NetworkPolicy` | **Designed** |
| Input caps | Config rejected if it exceeds platform limits | **Designed** |

## 6. Trade-offs accepted

- **Blast radius vs. speed:** tests share a non-production cluster and node kernel. Once implemented, quotas and network policies limit some risks, but a noisy neighbor or kernel-level fault can still affect other workloads. A dedicated AWS account is a possible further isolation step, not part of the one-account assumption.
- **Result fidelity:** the load generator and the target share a small node pool, so the generator can skew results at higher load. The design fix is a tainted node group for load generators, which I consider the first thing to do after the foundation is complete.
- **Dependency fidelity:** a containerized Postgres does not reproduce RDS IOPS limits, network latency or failover. It does measure service CPU, memory, connection handling and query patterns.
- **Idle cost vs. readiness:** the demo EKS control plane ($0.10/hr) and NAT gateway ($0.045/hr) cost money while idle. Destroying the demo stack between campaigns avoids idle charges but adds provisioning time; an existing shared cluster must not be destroyed as part of test cleanup.
- **Cost vs. availability:** one NAT gateway serves both AZs, which saves about $32/month. The module hard-codes a single NAT, so a multi-AZ option would be a code change.
- **Alert vs. hard stop:** budgets alert but do not stop spend. A hard stop could corrupt state mid-run.
- **Complexity:** the platform has several moving parts (Terraform layers, Helm charts, CI, a reaper). That is more than a script, but each is small and replaces a manual ticket step.
- **GitHub as the single control plane:** it is convenient, but a GitHub outage or a misconfigured workflow blocks all testing. The cluster-side reaper is meant to limit orphaned resources when that happens.
- **Security gaps today:** demo credentials (in Helm values and the Compose file) are for local use only. A real deployment needs a secrets manager, and test-run RBAC should be namespace-scoped rather than cluster-admin.

## 7. If I had another week

1. Finish the Designed items: load-test workflow, k6 scenario and PR comment, per-namespace quota and network policy, reaper, and fixture seeding.
2. Dedicated node pool with a taint for load generators (Spot where a restart is acceptable).
3. Baseline storage and regression gating, for example failing a PR when p99 regresses against `main`.
4. Admission policies (Kyverno or OPA) so guardrails cannot be bypassed by editing a chart, plus per-team budgets.
