# Plan: Self-Service Ephemeral Load Testing Engine (AWS)

A developer adds a `loadtest.yaml` to their service repo and triggers a GitHub Actions workflow. The workflow creates a quota-limited namespace on a shared EKS cluster, deploys the service with stubbed dependencies, runs k6, posts results to the PR, and always tears the namespace down. A scheduled janitor removes anything that leaks. A kind-based local path makes the demo reproducible.

## Decision matrix

| Decision | Picked | Alternatives considered | Why |
|---|---|---|---|
| Cloud | AWS | GCP | Familiar, mature OIDC and EKS tooling. |
| Environment | Namespace-per-test on a shared, dedicated load-test EKS cluster | Cluster per test, ECS Fargate task, VMs | Starts in seconds and is cheap. Quota, NetworkPolicy and a tainted node group limit blast radius. A cluster per test is too slow and costly. |
| Load generator | k6 | Locust, Gatling, JMeter | JS scripts, built-in thresholds, JSON summary, small footprint. |
| IaC | Terraform with modules and `envs/` | Pulumi, CDK | Widely known and reusable. Modules are separate from environment compositions. |
| CI/CD | GitHub Actions reusable workflow with OIDC | GitLab CI, Jenkins | About 10 lines to adopt for each of 50 services. No static keys. |
| Dependencies | WireMock stubs and a seeded Postgres container | Real dependencies, shared staging DB | Isolated and deterministic, no data-leak risk. Lower fidelity, documented as a trade-off. |
| Dev interface | Per-service `loadtest.yaml` plus PR label or `workflow_dispatch` | Web portal, CLI, Backstage | Lowest friction, versioned with the code. |
| Results | PR comment, JSON artifact, optional Grafana | Dashboard only | Developers stay in their workflow. Thresholds gate the pipeline. |

## Steps

### Phase 1 - Design
1. Write assumptions, guardrail list and repo layout: `modules/`, `envs/`, `sample-service/`, `.github/workflows/`, `schema/`, `docs/`.

### Phase 2 - Sample service and local loop
2. Trivial HTTP service with a DB call, a downstream call and a health endpoint, plus a Dockerfile.
3. k6 script with smoke and ramp profiles. Make targets to run everything on kind.

### Phase 3 - IaC (depends on 1, parallel with 2)
4. `modules/cluster`: VPC, EKS, tainted load-test node group.
5. `modules/test-env`: namespace, ResourceQuota, LimitRange, deny-by-default NetworkPolicy, TTL/owner/cost-tag labels.
6. `modules/guardrails`: AWS Budget alarm, janitor CronJob with minimal RBAC, tag enforcement.
7. `modules/ci-oidc`: GitHub OIDC role scoped to repo and branch.

### Phase 4 - Config and pipeline (depends on 2 and 4-7)
8. JSON schema and validator for `loadtest.yaml`. Hard caps on VUs, duration, replicas and concurrency, defined in one limits file.
9. Reusable workflow: validate, create namespace, deploy service and stubs, seed data, smoke, ramp, collect, report, `if: always()` teardown. Concurrency group per service.
10. Scheduled janitor workflow and CronJob that delete namespaces past their TTL.

### Phase 5 - Results (depends on 9)
11. Parse k6 summary, post or update the PR comment, upload the artifact, fail the job on threshold breach.

### Phase 6 - Docs and demo (depends on all)
12. README (local and cloud paths), WRITEUP.md, AI-USAGE.md. Keep prompt logs from the start.
13. Demo video: happy path, rejected over-cap config, failure case, janitor cleaning an orphan.
14. `terraform destroy` the cluster after the demo and confirm costs.

## Files to create

- `docs/assignment.md` (source, unchanged)
- `modules/{cluster,test-env,guardrails,ci-oidc}/`
- `envs/loadtest/`
- `sample-service/` (service, Dockerfile, `loadtest.yaml`, k6 script)
- `schema/loadtest.schema.json`, `tools/validate`
- `.github/workflows/loadtest.yml` (reusable), `janitor.yml`, `ci.yml`
- `README.md`, `WRITEUP.md`, `AI-USAGE.md`

## Verification

1. `terraform fmt`, `validate` and `tflint` on all modules; `terraform plan` on `envs/loadtest`.
2. Validator unit tests: over-cap VUs, missing TTL and bad thresholds are rejected.
3. Full end-to-end run on kind.
4. Full end-to-end run on real AWS, PR comment appears.
5. Cancel a run mid-test; janitor deletes the namespace after the TTL.
6. A pod in the test namespace cannot reach the internet or other namespaces.
7. Budget alarm and cost tags are visible.

## Writeup outline (2-3 pages)

1. Context and assumptions (~0.4 page): 50 services on Kubernetes, one AWS account, no production data in tests, teams own Dockerfiles and tests.
2. Developer flow (~0.5 page): config, PR, label, results, automatic teardown. Include a flow diagram.
3. Architecture and decisions (~0.8 page): the matrix in prose, with alternatives and reasons.
4. Guardrails (~0.5 page): cost, isolation, safe defaults, enforced teardown, security. State how each is enforced.
5. Trade-offs (~0.3 page): shared-cluster blast radius and noisy neighbours, mock fidelity, idle cluster cost, GitHub as single control plane, no distributed load generation.
6. Next week (~0.3 page): Backstage or CLI front end, distributed k6, baselines and regression detection, Kyverno/OPA admission policies, per-team budgets, dedicated AWS account, Karpenter spot nodes.

## Scope

- In: one sample service, one cluster, k6, Terraform, kind local path.
- Out: multi-region, UI, distributed load generation, real dependencies.
- The cluster is created only for the demo and destroyed afterwards.

## Open considerations

1. Sample service language: whichever is faster to write.
2. Empty `ticket-system/` folder: delete it or rename it to `sample-service/`.
3. Grafana is optional; skip unless time remains.
