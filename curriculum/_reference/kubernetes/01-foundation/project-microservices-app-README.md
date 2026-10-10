# Phase 1 Project: Microservices E-Commerce Application

Deploy a complete e-commerce platform demonstrating all Phase 1 concepts.

## Architecture Overview

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture Overview — diagram](../../../../_figures/curriculum-_reference-kubernetes-01-foundation-project-microservices-app-README-0-a0cdb88e.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  ING["Ingress controller"]
  FE["Frontend<br/><i>3 pods</i>"]
  GW["API gateway<br/><i>3 pods</i>"]
  RD[("Redis cache<br/><i>StatefulSet</i>")]
  PS["Product service<br/><i>3 pods</i>"]
  OS["Order service<br/><i>3 pods</i>"]
  US["User service<br/><i>3 pods</i>"]
  PG[("PostgreSQL primary<br/><i>StatefulSet</i>")]
  MQ[("RabbitMQ<br/><i>StatefulSet</i>")]
  WK["Worker<br/><i>3 pods</i>"]
  CJ["CronJob<br/><i>database backup, daily at 02:00</i>"]
  ING ==> FE ==> GW
  GW --> RD
  GW ==> PS
  GW ==> OS
  GW ==> US
  PS ==> PG
  OS ==> PG
  US ==> PG
  OS --> MQ ==> WK
  CJ -.-> PG
  class ING crit
  class FE,GW n
  class RD data
  class PS,OS,US n
  class PG crit
  class MQ data
  class WK n
  class CJ mut
  linkStyle 0,1,3,4,5,6,7,8,10 stroke:#2f6fb8,stroke-width:2px

%% Four StatefulSets and six Deployments, and the split is the lesson: anything
%% holding data is a StatefulSet with its own volume, anything that can be
%% replaced by an identical copy is a Deployment. The worker is a Deployment
%% even though it processes a queue -- the queue holds the state, not the pod.
```

</details>

## Project Structure

**`project-microservices-app/`**

- `README.md`
- `namespace.yaml`
- `configmaps/`
  - `frontend-config.yaml`
  - `api-gateway-config.yaml`
  - `services-config.yaml`
- `secrets/`
  - `database-secret.yaml`
  - `rabbitmq-secret.yaml`
- `storage/`
  - `storage-class.yaml`
  - `pvcs.yaml`
- `databases/`
  - `postgresql/`
    - `statefulset.yaml`
    - `service.yaml`
    - `configmap.yaml`
  - `redis/`
    - `statefulset.yaml`
    - `service.yaml`
- `messaging/`
  - `rabbitmq/`
    - `statefulset.yaml`
    - `service.yaml`
    - `configmap.yaml`
- `services/`
  - `frontend/`
    - `deployment.yaml`
    - `service.yaml`
  - `api-gateway/`
    - `deployment.yaml`
    - `service.yaml`
  - `product-service/`
    - `deployment.yaml`
    - `service.yaml`
  - `order-service/`
    - `deployment.yaml`
    - `service.yaml`
  - `user-service/`
    - `deployment.yaml`
    - `service.yaml`
  - `worker/`
    - `deployment.yaml`
- `jobs/`
  - `db-migration.yaml`
  - `db-backup-cronjob.yaml`
- `kustomization.yaml`


## Deployment Instructions

### Prerequisites

```bash
# Ensure you have a running cluster
kubectl cluster-info

# Create project namespace
kubectl apply -f namespace.yaml
```

### Step 1: Create Namespace and Base Resources

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce
  labels:
    app.kubernetes.io/name: ecommerce
    app.kubernetes.io/part-of: phase1-project
```

### Step 2: Deploy Secrets

```yaml
# secrets/database-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: ecommerce
type: Opaque
stringData:
  POSTGRES_USER: ecommerce
  POSTGRES_PASSWORD: "change-me-in-production"
  POSTGRES_DB: ecommerce
  DATABASE_URL: "postgresql://ecommerce:change-me-in-production@postgres:5432/ecommerce"
---
# secrets/rabbitmq-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-secret
  namespace: ecommerce
type: Opaque
stringData:
  RABBITMQ_DEFAULT_USER: ecommerce
  RABBITMQ_DEFAULT_PASS: "change-me-in-production"
  RABBITMQ_URL: "amqp://ecommerce:change-me-in-production@rabbitmq:5672"
```

### Step 3: Deploy PostgreSQL StatefulSet

```yaml
# databases/postgresql/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: ecommerce
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - secretRef:
            name: postgres-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command: ["pg_isready", "-U", "ecommerce"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["pg_isready", "-U", "ecommerce"]
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
# databases/postgresql/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ecommerce
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None
  selector:
    app: postgres
```

### Step 4: Deploy Redis StatefulSet

```yaml
# databases/redis/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: ecommerce
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        command:
        - redis-server
        - --appendonly
        - "yes"
        - --maxmemory
        - "256mb"
        - --maxmemory-policy
        - "allkeys-lru"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: data
          mountPath: /data
        livenessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["redis-cli", "ping"]
          initialDelaySeconds: 5
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
# databases/redis/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ecommerce
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None
  selector:
    app: redis
```

### Step 5: Deploy RabbitMQ StatefulSet

```yaml
# messaging/rabbitmq/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rabbitmq
  namespace: ecommerce
spec:
  serviceName: rabbitmq
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3.12-management-alpine
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        envFrom:
        - secretRef:
            name: rabbitmq-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: data
          mountPath: /var/lib/rabbitmq
        livenessProbe:
          exec:
            command: ["rabbitmq-diagnostics", "check_port_connectivity"]
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          exec:
            command: ["rabbitmq-diagnostics", "check_running"]
          initialDelaySeconds: 20
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
---
# messaging/rabbitmq/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: ecommerce
spec:
  ports:
  - port: 5672
    name: amqp
  - port: 15672
    name: management
  clusterIP: None
  selector:
    app: rabbitmq
```

### Step 6: Deploy Backend Services

```yaml
# services/product-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: nginx:alpine  # Replace with actual service image
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: DATABASE_URL
        - name: REDIS_URL
          value: "redis://redis:6379"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: ecommerce
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: product-service
```

```yaml
# services/order-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: nginx:alpine  # Replace with actual service image
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: DATABASE_URL
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: RABBITMQ_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: ecommerce
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: order-service
```

```yaml
# services/user-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: nginx:alpine  # Replace with actual service image
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: DATABASE_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: ecommerce
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: user-service
```

### Step 7: Deploy Worker

```yaml
# services/worker/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - name: worker
        image: nginx:alpine  # Replace with actual worker image
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: DATABASE_URL
        - name: RABBITMQ_URL
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: RABBITMQ_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        # No probes needed for workers - they don't serve HTTP traffic
```

### Step 8: Deploy API Gateway

```yaml
# services/api-gateway/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: nginx:alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: api-gateway-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: ecommerce
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: api-gateway
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-gateway-config
  namespace: ecommerce
data:
  default.conf: |
    upstream product_service {
        server product-service:8080;
    }
    upstream order_service {
        server order-service:8080;
    }
    upstream user_service {
        server user-service:8080;
    }

    server {
        listen 8080;

        location /health {
            return 200 'OK';
            add_header Content-Type text/plain;
        }

        location /api/products {
            proxy_pass http://product_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/orders {
            proxy_pass http://order_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        location /api/users {
            proxy_pass http://user_service;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
```

### Step 9: Deploy Frontend

```yaml
# services/frontend/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: ecommerce
spec:
  type: LoadBalancer  # or NodePort for local clusters
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: frontend
```

### Step 10: Deploy Database Backup CronJob

```yaml
# jobs/db-backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: ecommerce
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              echo "Starting backup at $TIMESTAMP"
              pg_dump -h postgres -U $POSTGRES_USER $POSTGRES_DB > /backup/backup-$TIMESTAMP.sql
              echo "Backup completed"
              ls -la /backup/
            env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_USER
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_DB
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            emptyDir: {}  # Replace with PVC in production
```

## Kustomization

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ecommerce

resources:
- namespace.yaml
- secrets/database-secret.yaml
- secrets/rabbitmq-secret.yaml
- databases/postgresql/statefulset.yaml
- databases/postgresql/service.yaml
- databases/redis/statefulset.yaml
- databases/redis/service.yaml
- messaging/rabbitmq/statefulset.yaml
- messaging/rabbitmq/service.yaml
- services/product-service/deployment.yaml
- services/order-service/deployment.yaml
- services/user-service/deployment.yaml
- services/worker/deployment.yaml
- services/api-gateway/deployment.yaml
- services/frontend/deployment.yaml
- jobs/db-backup-cronjob.yaml

commonLabels:
  project: ecommerce
  phase: "1"
```

## Deployment Commands

```bash
# Deploy everything
kubectl apply -k .

# Or deploy step by step
kubectl apply -f namespace.yaml
kubectl apply -f secrets/
kubectl apply -f databases/postgresql/
kubectl apply -f databases/redis/
kubectl apply -f messaging/rabbitmq/
kubectl apply -f services/

# Watch deployment progress
kubectl get pods -n ecommerce -w

# Check all resources
kubectl get all -n ecommerce
```

## Validation Checklist

- [ ] All pods are Running
- [ ] PostgreSQL accepts connections
- [ ] Redis accepts connections
- [ ] RabbitMQ management UI accessible
- [ ] API Gateway routes traffic correctly
- [ ] Frontend serves content
- [ ] Workers are consuming messages
- [ ] CronJob runs successfully

## Verification Commands

```bash
# Check pod status
kubectl get pods -n ecommerce

# Check StatefulSets
kubectl get statefulsets -n ecommerce

# Check services
kubectl get svc -n ecommerce

# Test PostgreSQL
kubectl exec -it postgres-0 -n ecommerce -- psql -U ecommerce -c "\l"

# Test Redis
kubectl exec -it redis-0 -n ecommerce -- redis-cli ping

# Test RabbitMQ
kubectl port-forward svc/rabbitmq 15672:15672 -n ecommerce
# Open http://localhost:15672

# View logs
kubectl logs -f deployment/api-gateway -n ecommerce
kubectl logs -f deployment/worker -n ecommerce

# Manual backup test
kubectl create job --from=cronjob/postgres-backup manual-backup -n ecommerce
kubectl logs job/manual-backup -n ecommerce
```

## Troubleshooting Guide

### Pod stuck in Pending
```bash
kubectl describe pod <pod-name> -n ecommerce
# Check Events section for scheduling issues
```

### Pod in CrashLoopBackOff
```bash
kubectl logs <pod-name> -n ecommerce --previous
kubectl describe pod <pod-name> -n ecommerce
```

### Service not accessible
```bash
kubectl get endpoints <service-name> -n ecommerce
# If empty, check selector labels match
```

### StatefulSet not creating pods
```bash
kubectl describe statefulset <name> -n ecommerce
kubectl get pvc -n ecommerce
# Check for storage provisioning issues
```

## Cleanup

```bash
# Delete all resources
kubectl delete -k .

# Or delete namespace (removes everything)
kubectl delete namespace ecommerce
```

## Success Criteria

You've completed Phase 1 when:

1. ✅ All 14+ pods running without restarts
2. ✅ StatefulSets maintain stable identities
3. ✅ Services route traffic correctly
4. ✅ Data persists across pod restarts
5. ✅ CronJob executes on schedule
6. ✅ You can explain the purpose of each manifest

## Next Steps

Proceed to [Phase 2: Core Operations](../../phase-2-core-operations/) to learn about networking, storage, and configuration management.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Project Structure
- Deployment Instructions
- Kustomization
- Deployment Commands

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
