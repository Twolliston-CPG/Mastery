# Week 14 — the Compose stack, ported to Kubernetes

```bash
bash ../../../_setup/02-kind-cluster.sh mastery

# build and load your week-4 image (or edit 30-app.yaml to point at a registry)
docker build -t week04-app:dev ../../../week-04/solutions/compose-stack
kind load docker-image week04-app:dev --name mastery
sed -i.bak 's|ghcr.io/REPLACE_ME/week04-app:latest|week04-app:dev|' 30-app.yaml

kubectl apply -k .
kubectl -n shop get pods -w
curl -H 'Host: shop.local' http://localhost/
```

## Verify the acceptance criteria

```bash
# non-root, read-only root filesystem
kubectl -n shop exec deploy/app -- id
kubectl -n shop exec deploy/app -- sh -c 'touch /nope' || echo "read-only: OK"

# data survives pod deletion
kubectl -n shop exec db-0 -- psql -U app -d appdb -c \
  "CREATE TABLE IF NOT EXISTS t(i int); INSERT INTO t VALUES (1);"
kubectl -n shop delete pod db-0
kubectl -n shop wait --for=condition=ready pod/db-0 --timeout=120s
kubectl -n shop exec db-0 -- psql -U app -d appdb -c "SELECT count(*) FROM t;"

# the Service actually has endpoints
kubectl -n shop get endpoints app

# rollout and rollback
kubectl -n shop set image deploy/app app=week04-app:broken
kubectl -n shop rollout status deploy/app --timeout=60s || kubectl -n shop rollout undo deploy/app
```

## What to study here

| File | The lesson |
|---|---|
| `00-namespace.yaml` | Pod Security Standards, ResourceQuota, and why LimitRange is required alongside a quota |
| `20-database.yaml` | StatefulSet vs Deployment; headless Service; `volumeClaimTemplates`; `fsGroup` |
| `30-app.yaml` | The **three probes** and why liveness must not check the database; `preStop` sleep; `topologySpreadConstraints`; PDB |
| `40-ingress.yaml` | `ingressClassName`, and Ingress backends being namespace-local |

Full explanation in [`../SOLUTIONS.md`](../SOLUTIONS.md).
