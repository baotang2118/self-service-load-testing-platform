# PostgreSQL and pgAdmin

This standalone Helm chart deploys PostgreSQL and pgAdmin as independent services. It is not part of the Django application deployment.

Requires Helm 3, kubectl, a Kubernetes cluster, and a default storage class. From the repository root:

```sh
helm install tickets-db ./charts/postgres-pgadmin
kubectl rollout status deployment/tickets-db-postgres
kubectl rollout status deployment/tickets-db-pgadmin
kubectl port-forward service/tickets-db-pgadmin 5050:80
```

Open http://127.0.0.1:5050/ and sign in with `admin@example.com` and `admin-local-only`. Register a server in pgAdmin using host `tickets-db-postgres`, port `5432`, maintenance database `tickets`, username `tickets`, and password `tickets-local-only`.

The services are available to other workloads in the same cluster through the `tickets-db-postgres` Service. A Django process can use `POSTGRES_HOST=tickets-db-postgres`, `POSTGRES_PORT=5432`, `POSTGRES_DB=tickets`, `POSTGRES_USER=tickets`, and `POSTGRES_PASSWORD=tickets-local-only`. For a local process, port-forward PostgreSQL in a separate terminal with `kubectl port-forward service/tickets-db-postgres 5432:5432` and use `POSTGRES_HOST=localhost`.

Change defaults through `values.yaml` or a separate values file:

```sh
helm install tickets-db ./charts/postgres-pgadmin -f my-values.yaml
helm upgrade tickets-db ./charts/postgres-pgadmin -f my-values.yaml
```

These are prototype credentials. Kubernetes Secrets, Helm values, and Helm release history are not a production secrets solution. PostgreSQL applies its configured database, user, and password only when initializing an empty volume; changing them later does not update the existing database. Secret changes do not automatically restart the pods. pgAdmin settings and registered servers are not persisted across pod replacement.

To remove the services, run `helm uninstall tickets-db`. This also deletes the PostgreSQL PVC and may permanently delete its data, depending on the storage provider's reclaim policy.