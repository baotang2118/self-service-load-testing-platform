# Self-Service Load Testing Platform

Assignment prototype for exploring a self-service load-testing platform. The
repository currently contains a ticket approval demo, two independent CRUD
services for local and Kubernetes demos, and a short-lived AWS infrastructure
foundation. It does not yet implement the end-to-end load-test workflow (test
configuration, load generation, result reporting, or per-test isolation).

## Repository components

- `webapp-ticket-system/`: Django ticket submission and DevOps approval demo;
	its worker runs a fixed placeholder task, not infrastructure operations.
- `demo-django/` and `demo-go/`: independent JSON CRUD APIs backed by shared
	PostgreSQL, intended as representative service/load-test targets.
- `charts/`: Helm charts for the ticket app, CRUD services, and their
	PostgreSQL dependency.
- `infra/terraform/`: reusable AWS modules and a short-lived VPC, EKS, ECR,
	GitHub OIDC, and budget foundation. It does not deploy the demo applications.
- `docs/plan.md`: intended platform design; `docs/assignment.md`: assignment
	brief. `WRITEUP.md` is currently an unfilled writeup scaffold.
- `AI-USAGE.md`: AI tools, representative prompts, and validation notes.

## AWS Terraform infrastructure

The short-lived AWS infrastructure foundation, its modules, setup requirements,
and teardown instructions are documented in
[infra/terraform/README.md](infra/terraform/README.md). AWS resources are not
created automatically. Review the IAM policy, Terraform plan, and cost estimate
before applying. The scheduled workflow can destroy the stack after its
configured expiry; see the infrastructure guide for required GitHub environment
protection and setup.

## Opsdesk ticket demo

The separate ticket app has its own local Docker Compose and Helm instructions
in [webapp-ticket-system/README.md](webapp-ticket-system/README.md). It is not
connected to the standalone CRUD services or the AWS Terraform stack.

## Demo CRUD services

The standalone Django and Go services expose the same JSON API as independent
load-test targets. They share PostgreSQL, but each owns its own table. The
existing ticket application is unaffected.

### Run locally

With Docker and Docker Compose installed, from the repository root:

```sh
docker compose -f compose.demo.yaml up --build -d
```

Django is available at `http://localhost:8001`, Go at
`http://localhost:8002`. PostgreSQL stores data in a named Compose volume. Each
service creates its own schema on startup. No seed data is required.

Use either base URL with these examples (the returned `id` may differ):

```sh
curl -X POST http://localhost:8001/api/items -H 'Content-Type: application/json' -d '{"name":"Example","description":"Demo item"}'
curl http://localhost:8001/api/items
curl http://localhost:8001/api/items/1
curl -X PUT http://localhost:8001/api/items/1 -H 'Content-Type: application/json' -d '{"name":"Updated","description":"Changed"}'
curl -X DELETE http://localhost:8001/api/items/1
curl http://localhost:8001/health/ready
```

The `name` must be a nonempty string of at most 255 characters;
`description` is an optional string. Successful create, read/update, and
delete requests return 201, 200, and 204 respectively. Invalid input returns
400, a missing item returns 404, and unsupported methods return 405.
``/health/live` checks the process; `/health/ready` checks PostgreSQL.

To stop the stack without deleting the database, run
`docker compose -f compose.demo.yaml down`. Add `-v` to also delete the demo
database volume and its data.

### Deploy with Helm

Requires Helm, kubectl, a Kubernetes cluster with a default storage class, and
images accessible to the cluster. For example, with a local kind cluster:

```sh
docker build -t demo-django:local ./demo-django
docker build -t demo-go:local ./demo-go
kind load docker-image demo-django:local demo-go:local

helm install tickets-db ./charts/postgres-pgadmin
kubectl rollout status deployment/tickets-db-postgres
helm install demo-django ./charts/demo-django
helm install demo-go ./charts/demo-go
kubectl rollout status deployment/demo-django
kubectl rollout status deployment/demo-go
```

For other clusters, push both images to a registry and configure
`image.repository`, `image.tag`, and `image.pullPolicy` in each chart. The
default charts expect the releases shown above in the same namespace. If
dependency release names or credentials differ, set `postgres.host`,
`postgres.port`, `postgres.database`, `postgres.username`,
`postgres.existingSecret` and `postgres.passwordKey` in both application charts.
The PostgreSQL Secret must already exist in that namespace.

Forward each service in a separate terminal, then use the API examples above:

```sh
kubectl port-forward service/demo-django 8001:8000
kubectl port-forward service/demo-go 8002:8080
```

Django migrations run in an init container; Go creates its own table on
startup. Both deployments default to one replica. Coordinating Django
migrations or Go's initial table creation across simultaneous replicas is not
handled by this prototype. Remove the applications with `helm uninstall
demo-django demo-go`; uninstall the PostgreSQL release separately. Uninstalling
the PostgreSQL chart deletes its PVC and may permanently delete data.

### Test

```sh
uv run --directory demo-django pytest -q
uv run --directory demo-django ruff check .
go -C demo-go test ./...
helm lint charts/demo-django
helm lint charts/demo-go
```

To run the HTTP integration tests against the running Compose stack or the two
port forwards, set both URLs (POSIX shell syntax):

```sh
DEMO_DJANGO_URL=http://localhost:8001 DEMO_GO_URL=http://localhost:8002 uv run --directory demo-django pytest -q tests/test_integration.py
```

### Prototype limitations

These APIs have no authentication or authorization and must not be exposed to
untrusted networks. The credentials, permissive Django hosts, and chart defaults
are for local demos only; Kubernetes Secrets and Helm values are not a
production secret-management solution. PostgreSQL is the source of truth.