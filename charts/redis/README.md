# Redis

This standalone Helm chart deploys one ephemeral Redis instance for prototype use. It is not connected to the Django application.

Requires Helm 3 and a Kubernetes cluster. From the repository root:

```sh
helm install redis ./charts/redis
kubectl rollout status deployment/redis-redis
```

Other workloads in the cluster can connect to `redis-redis:6379`. Redis persistence is disabled, so data is lost when the pod is replaced. The chart does not configure authentication or a network policy; a ClusterIP service is not a security boundary.

To remove Redis, run:

```sh
helm uninstall redis
```