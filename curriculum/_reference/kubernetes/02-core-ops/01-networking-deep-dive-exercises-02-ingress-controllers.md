# Exercise 2: Ingress Controllers and Routing

## Objective

Deploy and configure an Ingress controller to expose multiple services with path-based and host-based routing, TLS termination, and advanced traffic management.

## Prerequisites

- Running Kubernetes cluster
- Helm installed
- Basic understanding of HTTP/HTTPS

## Tasks

### Task 1: Install NGINX Ingress Controller

```bash
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.metrics.enabled=true

# Wait for the controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get the external IP (for cloud) or NodePort (for local)
kubectl get svc -n ingress-nginx
```

### Task 2: Deploy Sample Applications

```yaml
# apps.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-lab
---
# App 1: Web frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: ingress-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: web-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: ingress-lab
data:
  index.html: |
    <html><body><h1>Web Application</h1><p>Version 1.0</p></body></html>
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: ingress-lab
spec:
  selector:
    app: web
  ports:
  - port: 80
---
# App 2: API service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-app
  namespace: ingress-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: api-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: ingress-lab
data:
  default.conf: |
    server {
      listen 80;
      location / {
        return 200 '{"service":"api","version":"1.0","status":"healthy"}';
        add_header Content-Type application/json;
      }
      location /users {
        return 200 '[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]';
        add_header Content-Type application/json;
      }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: api-app
  namespace: ingress-lab
spec:
  selector:
    app: api
  ports:
  - port: 80
---
# App 3: Admin dashboard
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-app
  namespace: ingress-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin
  template:
    metadata:
      labels:
        app: admin
    spec:
      containers:
      - name: admin
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: admin-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-content
  namespace: ingress-lab
data:
  index.html: |
    <html><body><h1>Admin Dashboard</h1><p>Restricted Access</p></body></html>
---
apiVersion: v1
kind: Service
metadata:
  name: admin-app
  namespace: ingress-lab
spec:
  selector:
    app: admin
  ports:
  - port: 80
```

### Task 3: Path-Based Routing

```yaml
# path-based-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-based-routing
  namespace: ingress-lab
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-app
            port:
              number: 80
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin-app
            port:
              number: 80
```

**Test:**
```bash
# Add to /etc/hosts (replace with your ingress IP)
INGRESS_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$INGRESS_IP myapp.local" | sudo tee -a /etc/hosts

curl http://myapp.local/
curl http://myapp.local/api
curl http://myapp.local/admin
```

### Task 4: Host-Based Routing

```yaml
# host-based-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-based-routing
  namespace: ingress-lab
spec:
  ingressClassName: nginx
  rules:
  - host: web.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
  - host: api.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-app
            port:
              number: 80
  - host: admin.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-app
            port:
              number: 80
```

### Task 5: TLS Termination

Create a self-signed certificate:
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.example.local"

# Create Kubernetes secret
kubectl create secret tls secure-tls \
  --key tls.key \
  --cert tls.crt \
  -n ingress-lab
```

```yaml
# tls-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: ingress-lab
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.local
    secretName: secure-tls
  rules:
  - host: secure.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
```

### Task 6: Rate Limiting

```yaml
# rate-limited-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limited
  namespace: ingress-lab
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    nginx.ingress.kubernetes.io/limit-rpm: "100"
spec:
  ingressClassName: nginx
  rules:
  - host: limited.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-app
            port:
              number: 80
```

**Test rate limiting:**
```bash
# Install hey for load testing
# brew install hey

for i in {1..20}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://limited.example.local/
done
```

### Task 7: Basic Authentication

```bash
# Create auth file
htpasswd -c auth admin
# Enter password when prompted

# Create secret
kubectl create secret generic basic-auth \
  --from-file=auth \
  -n ingress-lab
```

```yaml
# auth-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auth-protected
  namespace: ingress-lab
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
spec:
  ingressClassName: nginx
  rules:
  - host: protected.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-app
            port:
              number: 80
```

### Task 8: Canary Deployments

Deploy a new version:
```yaml
# canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-v2
  namespace: ingress-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
      version: v2
  template:
    metadata:
      labels:
        app: web
        version: v2
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: web-content-v2
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content-v2
  namespace: ingress-lab
data:
  index.html: |
    <html><body><h1>Web Application</h1><p>Version 2.0 - NEW!</p></body></html>
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-v2
  namespace: ingress-lab
spec:
  selector:
    app: web
    version: v2
  ports:
  - port: 80
```

```yaml
# canary-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-canary
  namespace: ingress-lab
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-v2
            port:
              number: 80
```

**Test canary:**
```bash
for i in {1..100}; do
  curl -s http://myapp.local/ | grep -o "Version [0-9.]*"
done | sort | uniq -c
```

## Success Criteria

- [ ] NGINX Ingress controller deployed and running
- [ ] Path-based routing works correctly
- [ ] Host-based routing works correctly
- [ ] TLS termination configured
- [ ] Rate limiting prevents excessive requests
- [ ] Basic authentication protects endpoints
- [ ] Canary deployment sends ~20% traffic to v2

## Cleanup

```bash
kubectl delete namespace ingress-lab
helm uninstall nginx-ingress -n ingress-nginx
kubectl delete namespace ingress-nginx
```

## Next Exercise

Continue to [Exercise 3: Service Mesh Basics](./03-service-mesh-basics.md) to learn about advanced traffic management.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Install NGINX Ingress Controller
- Deploy Sample Applications
- Path-Based Routing
- Host-Based Routing

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
