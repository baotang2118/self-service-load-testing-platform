# Self-Service Ephemeral Load Testing Engine

## 1. Context and assumptions

**Built** means present in the repository; **Designed** means specified here but not implemented.

| Assumption | Why it matters |
| :--- | :--- |
| About 50 services, mostly Django and Go on PostgreSQL, packaged with Helm for Kubernetes; CI is GitHub Actions. | The platform reuses what teams already ship, so adoption needs no re-packaging. |
| One AWS account; tests use synthetic, non-production data and never reach production. | Removes data-leak risk and justifies fixture-based dependencies. |
| A typical test targets one service, runs up to a few hundred virtual users for 5-15 minutes, and a handful run concurrently company-wide. | Small, short tests justify a shared cluster and a small node pool. Larger or more frequent tests would require revisiting isolation (section 3). |
| Teams own Dockerfiles, Helm values and test scenarios; the platform owns limits and teardown. | Guardrails replace the human gatekeeper that the ticket process provides today. |

The prototype is deliberately narrower than this target. It provides Django and Go CRUD sample services, the AWS foundation, and a read-only k6 test (5 iterations/s for 1 minute, at most 5 virtual users) against two already deployed APIs.

## 2. Alternatives and decisions

| Decision | Picked | Alternatives considered | Why | Status |
| :--- | :--- | :--- | :--- | :--- |
| Cloud | AWS (EKS) | GCP | Assumed existing footprint. OIDC federation and EKS access entries avoid static credentials. | Built |
| Environment | Namespace per test in a load-test EKS cluster shared by teams | Cluster per test; reuse an existing non-production cluster; ECS/Fargate; VMs | A namespace starts in seconds, whereas a cluster takes minutes to provision and costs a control plane per run. A dedicated cluster keeps tests away from other teams' workloads, which reuse would not. ECS/Fargate and VMs diverge from the Helm deployment model teams already use. | Cluster Built; per-test namespaces Designed |
| Load generator | k6 | Locust, Gatling, JMeter, SaaS | JavaScript scenarios, native thresholds that fail the job, JSON summary, small footprint. Locust fits a Python team but needs custom hooks for pass/fail; JMeter is heavier to author and review; SaaS needs public ingress to targets and per-user cost. | Built (runs on the runner, not in-cluster) |
| IaC layout | Terraform: `bootstrap/state`, `envs/loadtest`, reusable `modules/` (network, cluster, ecr, github_oidc, demo_deploy, github_runner, budget); S3 native locking | Single root module; CDK; Pulumi | The state bucket survives destruction of the environment; modules can be reused for more environments; `use_lockfile` avoids a DynamoDB table. | Built |
| CI/CD and interface | GitHub Actions with OIDC; manual dispatch today, PR label plus per-service config planned | Web portal or Backstage; CLI; GitLab CI; Jenkins | Teams already live in GitHub, so config is versioned with code and review and authentication are reused. There is no new system to operate. | Dispatch Built; config and PR label Designed |
| Dependencies | Per-run Postgres in the test namespace with fixtures; stubs for downstream services | Shared staging RDS; RDS per run; real downstream services | No data contention or leakage, starts in seconds, and is removed with the namespace. The demo itself uses one persistent in-cluster Postgres. | Designed |

### Developer experience

The target flow keeps a developer inside GitHub with no ticket:

1. Keep a small config next to the service (target, virtual users, duration, thresholds).
2. Trigger it with a PR label or `workflow_dispatch`; configs above platform caps are rejected before anything is provisioned.
3. The pipeline builds the image, creates a quota-limited namespace, deploys the service and its Postgres, and runs k6.
4. Results are posted to the PR (p50/p95/p99, RPS, error rate, threshold verdict) with the raw JSON as an artifact; a threshold breach fails the job.
5. The namespace is deleted in an `if: always()` step; a reaper removes anything that leaks.

Built today: manual dispatch of the deploy and load-test workflows, k6 thresholds that fail the job (error rate under 1%, p95 under 500 ms, no dropped iterations), and a 14-day JSON artifact. Config validation, PR comments and steps 3 and 5 are **Designed**.

### Guardrails and how each is enforced

| Guardrail | Mechanism | Status |
| :--- | :--- | :--- |
| Cost | $100 monthly AWS Budget filtered by the `Project` tag (alerts at 80% actual, 100% forecast); node group of `t3.medium`, 1-3 nodes; ECR keeps 30 images; reviewer-gated Terraform destroy | Built |
| Credentials | GitHub OIDC role trusted only for this repository and named environments; deploy role limited to one ECR repository and EKS edit access in one namespace | Built |
| Network and cluster access | EKS API restricted to allowlisted CIDRs (`0.0.0.0/0` rejected by validation); nodes in private subnets; runner has no public IP or SSH | Built |
| Supply chain | Private ECR, immutable tags, scan on push | Built |
| Load limits | Fixed arrival rate (5/s), at most 5 virtual users, 10-minute job timeout, one run at a time via a concurrency group | Built (hard-coded for the demo) |
| Isolation | Per-namespace `ResourceQuota`, `LimitRange`, default-deny `NetworkPolicy` | Designed |
| Teardown | `always()` cleanup plus a CronJob reaper deleting namespaces past an `expires-at` label | Designed |
| Config caps | Platform limits validated before provisioning | Designed |

## 3. Trade-offs accepted

- **Cost:** The EKS control plane ($0.10/hr) and NAT gateway ($0.045/hr) bill while idle. Destroying the stack between campaigns avoids that but adds provisioning time before the next run. One NAT gateway for both AZs saves roughly $32/month at the price of AZ resilience. The budget alerts but does not stop spend; a hard stop could kill a run mid-test.
- **Complexity:** Terraform layers, Helm charts, a self-hosted runner and several workflows are more than a script. I accept this because each piece replaces a manual ticket step, but the runner is extra infrastructure to maintain.
- **Blast radius:** Namespaces share the control plane, nodes and kernel. Quotas and network policies reduce but cannot eliminate noisy-neighbour or kernel-level risk. Because those controls are not yet built, the platform should not be opened to multiple teams until they are. A separate account or cluster would reduce the radius further at higher cost.
- **Developer experience:** Today a run is dispatched manually from a reviewer-gated GitHub environment, so it is not yet ticket-free. I keep the gate until per-test isolation and teardown make removing it safe. k6 reaches services through `kubectl port-forward`, which adds a tunnel and caps throughput; this is adequate for about 10 requests/s but not for stress testing.
- **Security:** The runner can read a GitHub token stored in SSM, so only trusted code may run on it (environment restricted to `main`, reviewers required); a GitHub App would be safer. The demo APIs have no authentication, and Compose and Helm credentials are for local use only. A real deployment needs a secrets manager.
- **Fidelity:** A containerized Postgres is faster and more deterministic than RDS but does not model managed-database IOPS, failover or network behaviour. It still measures service CPU, memory, connection handling and query patterns.

## 4. What I would build next

Ordered so that isolation and cleanup come before scale:

1. **End-to-end reusable workflow:** config schema and cap validation, per-run namespace with quota, `LimitRange` and `NetworkPolicy`, k6 as an in-cluster Job (removes the port-forward), seeded Postgres, PR comment, and `always()` teardown.
2. **TTL reaper and proof it works:** cancel a run mid-test and confirm cleanup; confirm a pod cannot reach other namespaces or the internet.
3. **Load-generator isolation:** a tainted node group for k6 so it never competes with the target, and distributed k6 if tests outgrow one generator.
4. **Regression gating:** store baselines and fail a PR when p95 regresses against `main`.
5. **Hardening:** Kyverno or OPA admission policies so guardrails cannot be bypassed by editing a chart, per-team budgets, and a GitHub App in place of the runner token.
