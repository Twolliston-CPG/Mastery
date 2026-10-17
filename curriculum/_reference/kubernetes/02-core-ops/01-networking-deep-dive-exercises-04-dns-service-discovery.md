# Exercise 4: DNS and Service Discovery

## Objectives

- Understand CoreDNS architecture
- Configure custom DNS settings
- Debug DNS issues
- Implement advanced DNS patterns

## Prerequisites

- Completed Exercises 1-3
- Understanding of DNS concepts
- kubectl proficiency

---

## Part 1: CoreDNS Fundamentals

### 1.1 CoreDNS Components

```bash
# View CoreDNS deployment
kubectl get deployment coredns -n kube-system

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# View CoreDNS service
kubectl get svc kube-dns -n kube-system

# Check ConfigMap
kubectl get configmap coredns -n kube-system -o yaml
```

### 1.2 Default CoreDNS Configuration

```yaml
# CoreDNS Corefile
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

### 1.3 DNS Query Flow

```
Pod DNS Query → CoreDNS →
  → If cluster.local: resolve from Kubernetes API
  → If external: forward to upstream DNS
```

---

## Part 2: DNS Resolution Patterns

### 2.1 Service DNS

```bash
# Create test service
kubectl create deployment nginx --image=nginx:1.25
kubectl expose deployment nginx --port=80

# Test DNS resolution
kubectl run dns-test --rm -it --image=busybox:1.36 -- sh

# Inside pod:
nslookup nginx
nslookup nginx.default
nslookup nginx.default.svc
nslookup nginx.default.svc.cluster.local

# Check /etc/resolv.conf
cat /etc/resolv.conf

exit
```

### 2.2 Pod DNS

```yaml
# pod-dns-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-pod
spec:
  hostname: mypod
  subdomain: mysubdomain
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Service
metadata:
  name: mysubdomain
spec:
  clusterIP: None
  selector:
    app: nonexistent  # Doesn't matter for subdomain
```

```bash
kubectl apply -f pod-dns-test.yaml

# Pod gets DNS: <hostname>.<subdomain>.<namespace>.svc.cluster.local
kubectl run test --rm -it --image=busybox -- nslookup mypod.mysubdomain.default.svc.cluster.local
```

### 2.3 SRV Records

```bash
# SRV records for named ports
kubectl run test --rm -it --image=busybox -- sh

# SRV record format: _<port-name>._<protocol>.<service>.<namespace>.svc.cluster.local
nslookup -type=SRV _http._tcp.nginx.default.svc.cluster.local

exit
```

---

## Part 3: Custom DNS Configuration

### 3.1 Pod DNS Policy

```yaml
# dns-policy-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns-pod
spec:
  dnsPolicy: "None"          # Don't use cluster DNS
  dnsConfig:
    nameservers:
      - 8.8.8.8
      - 8.8.4.4
    searches:
      - my.custom.domain
      - another.domain
    options:
      - name: ndots
        value: "2"
      - name: timeout
        value: "3"
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
```

DNS Policies:
- **Default**: Inherit from node
- **ClusterFirst**: Use CoreDNS, fall back to node DNS
- **ClusterFirstWithHostNet**: For hostNetwork pods
- **None**: Use only dnsConfig

### 3.2 DNS Config Options

```yaml
# Common DNS options
dnsConfig:
  options:
    - name: ndots
      value: "5"        # Number of dots before absolute lookup
    - name: timeout
      value: "3"        # Timeout for queries
    - name: attempts
      value: "3"        # Retry attempts
    - name: single-request-reopen
                        # Use new socket per request (helps with conntrack)
```

### 3.3 Customizing CoreDNS

```yaml
# custom-coredns.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready

        # Kubernetes zone
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }

        # Custom domain rewrite
        rewrite name suffix .mycompany.local .default.svc.cluster.local

        # Custom stub domain
        forward example.com 10.0.0.53

        # External DNS
        forward . 8.8.8.8 8.8.4.4 {
           max_concurrent 1000
        }

        cache 30
        loop
        reload
        loadbalance
        prometheus :9153
    }
```

```bash
# Apply and restart CoreDNS
kubectl apply -f custom-coredns.yaml
kubectl rollout restart deployment coredns -n kube-system
```

---

## Part 4: Stub Domains and Upstream DNS

### 4.1 Stub Domains

```yaml
# stub-domain-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }

    # Stub domain for internal corporate DNS
    corp.example.com:53 {
        errors
        cache 30
        forward . 10.0.0.53 10.0.0.54
    }

    # Another stub domain
    legacy.internal:53 {
        errors
        cache 30
        forward . 192.168.1.1
    }
```

### 4.2 External DNS Servers

```yaml
# Use specific upstream DNS
forward . 8.8.8.8 8.8.4.4 {
    max_concurrent 1000
    policy round_robin    # or: random, sequential
    health_check 5s
}
```

---

## Part 5: DNS Debugging

### 5.1 DNS Debug Pod

```yaml
# dns-debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-debug
spec:
  containers:
  - name: dnsutils
    image: registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3
    command: ["sleep", "infinity"]
```

```bash
kubectl apply -f dns-debug-pod.yaml

# Comprehensive DNS testing
kubectl exec -it dns-debug -- sh

# Test basic resolution
nslookup kubernetes.default

# Test external resolution
nslookup google.com

# Detailed query
dig +search +noall +answer kubernetes.default

# Check CoreDNS directly
dig @10.96.0.10 kubernetes.default.svc.cluster.local

# Trace resolution
dig +trace google.com

exit
```

### 5.2 Common DNS Issues

```bash
# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100

# Check CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153 &
curl localhost:9153/metrics | grep coredns

# Check pod DNS config
kubectl exec dns-debug -- cat /etc/resolv.conf

# Test if CoreDNS is reachable
kubectl exec dns-debug -- nc -vz 10.96.0.10 53
```

### 5.3 DNS Troubleshooting Script

```bash
#!/bin/bash
# dns-troubleshoot.sh

echo "=== DNS Troubleshooting ==="

echo -e "\n--- CoreDNS Pods ---"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

echo -e "\n--- CoreDNS Service ---"
kubectl get svc kube-dns -n kube-system

echo -e "\n--- Test Internal DNS ---"
kubectl run dns-test --rm -it --restart=Never --image=busybox:1.36 -- \
  nslookup kubernetes.default 2>&1

echo -e "\n--- Test External DNS ---"
kubectl run dns-test-ext --rm -it --restart=Never --image=busybox:1.36 -- \
  nslookup google.com 2>&1

echo -e "\n--- CoreDNS Logs (last 20 lines) ---"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20

echo -e "\n--- CoreDNS ConfigMap ---"
kubectl get configmap coredns -n kube-system -o yaml
```

---

## Part 6: Advanced DNS Patterns

### 6.1 ExternalName for Service Aliasing

```yaml
# external-name-alias.yaml
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  type: ExternalName
  externalName: prod-db.example.com
---
# Can also point to another service
apiVersion: v1
kind: Service
metadata:
  name: api-alias
  namespace: frontend
spec:
  type: ExternalName
  externalName: api-service.backend.svc.cluster.local
```

### 6.2 DNS-Based Service Discovery Pattern

```yaml
# service-registry.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-registry
data:
  services: |
    database=postgres.data.svc.cluster.local
    cache=redis.cache.svc.cluster.local
    queue=rabbitmq.messaging.svc.cluster.local
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:1.0
        envFrom:
        - configMapRef:
            name: service-registry
```

### 6.3 Split-Horizon DNS

```yaml
# Internal services resolve to internal IPs
# External services resolve to external IPs

# For pods with dnsPolicy: ClusterFirst (default)
# - *.cluster.local -> CoreDNS -> Kubernetes
# - everything else -> CoreDNS -> upstream DNS

# Custom split for specific domains
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }
        forward . /etc/resolv.conf
        cache 30
    }

    # Internal view for internal.example.com
    internal.example.com:53 {
        file /etc/coredns/internal.db
        cache 30
    }
```

---

## Part 7: Hands-on Challenges

### Challenge 1: DNS Performance Testing

```bash
# Create test script
cat <<'EOF' > /tmp/dns-perf.sh
#!/bin/sh
for i in $(seq 1 100); do
  start=$(date +%s%N)
  nslookup kubernetes.default > /dev/null 2>&1
  end=$(date +%s%N)
  echo $((($end - $start) / 1000000))
done | awk '{sum+=$1} END {print "Average: " sum/NR "ms"}'
EOF

kubectl run dns-perf --rm -it --image=busybox:1.36 -- sh /dev/stdin < /tmp/dns-perf.sh
```

### Challenge 2: Custom Domain Resolution

Configure CoreDNS to:
1. Resolve `*.apps.local` to a specific service
2. Forward `corporate.com` to internal DNS
3. Block resolution of `ads.example.com`

### Challenge 3: DNS Failover

Set up DNS configuration with:
1. Primary upstream DNS
2. Secondary failover DNS
3. Health checks
4. Appropriate caching

---

## Verification Tasks

1. [ ] Explored CoreDNS configuration
2. [ ] Tested all DNS resolution patterns
3. [ ] Configured custom DNS policy for pod
4. [ ] Set up stub domains
5. [ ] Debugged DNS issues
6. [ ] Implemented advanced DNS patterns

---

## Key Takeaways

- CoreDNS is the cluster DNS server
- Services get automatic DNS records
- Pod DNS can be customized via dnsPolicy
- Stub domains enable hybrid DNS architectures
- DNS debugging is crucial for troubleshooting
- External names enable service aliasing

---

## Next Steps

Continue to [Exercise 5: CNI Plugins](01-networking-deep-dive-exercises-05-cni-plugins.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CoreDNS Fundamentals
- DNS Resolution Patterns
- Custom DNS Configuration
- Stub Domains and Upstream DNS

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
