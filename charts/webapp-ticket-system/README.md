# Webapp Ticket System Helm Chart

This chart deploys the Django web process and its single background worker. PostgreSQL is external to this chart. The chart runs database migrations as a Helm pre-install and pre-upgrade hook before managing the web and worker workloads.

The app currently uses Django's development server. This chart is suitable for the assignment/demo environment, not a production deployment.

## Build the image

From the repository root, build an image with the chart's default reference:

```sh
docker build -t webapp-ticket-system:local ./webapp-ticket-system
```

For a local `kind` cluster, load it with:

```sh
kind load docker-image webapp-ticket-system:local
```

For a remote cluster, push the image to a registry and set `image.repository`, `image.tag`, and optionally `image.pullSecrets` in a values file.

## Install

Create the namespace, then install the existing PostgreSQL chart as a demo dependency. Its default credentials are for local testing only; use a managed database or override credentials for other environments.

```sh
kubectl create namespace tickets
helm upgrade --install tickets-db charts/postgres-pgadmin \
  --namespace tickets --wait --timeout 5m
```

Create the Django secret. The database chart creates `tickets-db-database-credentials` with key `postgres-password`:

```sh
kubectl create secret generic tickets-webapp-django \
  --namespace tickets \
  --from-literal=django-secret-key='replace-with-a-random-secret'
```

The default PostgreSQL connection targets the existing chart's default resources when that chart is installed as release `tickets-db` in namespace `tickets`: Service `tickets-db-postgres`, Secret `tickets-db-database-credentials`, key `postgres-password`. For other databases, set `database.host`, `database.name`, `database.user`, `database.port`, `database.sslmode`, and `database.passwordSecret.name`/`key`.

Install the app chart:

```sh
helm upgrade --install tickets-webapp charts/webapp-ticket-system \
  --namespace tickets \
  --set django.allowedHosts[0]=localhost \
  --set django.allowedHosts[1]=127.0.0.1
```

The chart defaults Django debug off. Add every hostname used to access the app to `django.allowedHosts`; enabled Ingress hosts are included automatically. Set `ingress.enabled=true` and configure `ingress.className`, `ingress.hosts`, and `ingress.tls` to expose it through an installed ingress controller. Ingress is disabled by default.

For local access without Ingress:

```sh
kubectl port-forward --namespace tickets service/tickets-webapp-web 8000:8000
```

Then open http://127.0.0.1:8000/. Create the application superuser separately with `python manage.py createsuperuser` in a one-off pod or other approved execution path.

## Operations

- The migration Job runs before install and upgrade. Helm waits for it; a failed migration fails the release operation. Successful hook Jobs are deleted after completion, while failed Jobs are retained for inspection and later cleaned up by Kubernetes TTL.
- The worker is deliberately fixed at one replica. Its startup recovery assumes it is the only worker.
- Web startup, readiness, and liveness probes use TCP port 8000. They only establish that the development server accepts connections, not that PostgreSQL is ready or usable.
- Database and Django secret values are not stored in Helm values. Create their Kubernetes Secrets before installing or upgrading the chart.
