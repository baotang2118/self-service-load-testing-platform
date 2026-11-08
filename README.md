# GEOCOMPLY ASSIGNMENT

Working prototype. 
○ Runnable end-to-end for at least one representative microservice. A trivial sample 
service you provide is fine. 
○ IaC modules for cloud resources, structured the way you would ship them for real 
reuse. 
○ A CI/CD pipeline. 
○ A demo video showing the working product. 
○ A README explaining how to run it locally or in the cloud.

## Demo CRUD services

The standalone Django and Go services expose the same JSON API as independent
load-test targets. They share PostgreSQL and Redis, but each owns its own table
and cache keys. The existing ticket application is unaffected.

### Run locally

With Docker and Docker Compose installed, from the repository root:

```sh
docker compose -f compose.demo.yaml up --build -d
```

Django is available at `http://localhost:8001`, Go at
`http://localhost:8002`. PostgreSQL stores data in a named Compose volume;
Redis is ephemeral. Each service creates its own schema on startup. No seed
data is required.

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
`/health/live` checks the process; `/health/ready` checks PostgreSQL and Redis.

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
helm install demo-cache ./charts/redis
kubectl rollout status deployment/tickets-db-postgres
kubectl rollout status deployment/demo-cache-redis
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
`postgres.existingSecret`, `postgres.passwordKey`, and `redis.url` in both
application charts. The PostgreSQL Secret must already exist in that namespace.

Forward each service in a separate terminal, then use the API examples above:

```sh
kubectl port-forward service/demo-django 8001:8000
kubectl port-forward service/demo-go 8002:8080
```

Django migrations run in an init container; Go creates its own table on
startup. Both deployments default to one replica. Coordinating Django
migrations or Go's initial table creation across simultaneous replicas is not
handled by this prototype. Remove the applications with `helm uninstall
demo-django demo-go`; uninstall the dependency releases separately. Uninstalling
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
Redis caches individual reads for 60 seconds and is invalidated on writes;
concurrent reads or a failed invalidation can briefly serve stale values until
the TTL expires. Cache errors fall back to PostgreSQL, but readiness fails while
Redis is unreachable, so Kubernetes will stop routing new traffic to the pod.