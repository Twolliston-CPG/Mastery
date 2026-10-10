# Lab 11: Network Security

## Objectives

- Configure network segmentation with Kubernetes Network Policies
- Implement Web Application Firewall (WAF)
- Deploy Intrusion Detection System (IDS)
- Configure Zero Trust network access

## Prerequisites

- Kubernetes cluster with Calico or Cilium CNI
- AWS account (for WAF)
- Docker installed

## Duration

2.5 hours

## Part 1: Kubernetes Network Policies (45 minutes)

### Task 1.1: Default Deny All

```yaml
# network-policies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Task 1.2: Application-Specific Policies

```yaml
# network-policies/app-policies.yaml
---
# Frontend - Allow ingress from load balancer, egress to backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
  - to:  # DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
---
# Backend - Allow from frontend, egress to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:  # DNS
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
---
# Database - Only allow from backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
  egress: []  # No egress allowed
```

### Task 1.3: Test Network Policies

```bash
# Apply policies
kubectl apply -f network-policies/

# Test connectivity (should succeed)
kubectl exec -n production frontend-pod -- wget -qO- http://backend:8080/health

# Test blocked connectivity (should timeout)
kubectl exec -n production frontend-pod -- wget -qO- --timeout=5 http://postgres:5432
```

## Part 2: Web Application Firewall (45 minutes)

### Task 2.1: AWS WAF Configuration

```hcl
# terraform/waf.tf
resource "aws_wafv2_web_acl" "main" {
  name        = "production-waf"
  description = "Production WAF ACL"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Common
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRules"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting
  rule {
    name     = "RateLimitRule"
    priority = 3
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ProductionWAF"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
```

### Task 2.2: ModSecurity with NGINX

```yaml
# modsecurity/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-modsecurity
  namespace: ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-modsecurity
  template:
    metadata:
      labels:
        app: nginx-modsecurity
    spec:
      containers:
      - name: nginx
        image: owasp/modsecurity-crs:nginx-alpine
        ports:
        - containerPort: 80
        env:
        - name: PARANOIA
          value: "2"
        - name: ANOMALY_INBOUND
          value: "10"
        - name: BACKEND
          value: "http://app-service:8080"
        volumeMounts:
        - name: modsec-config
          mountPath: /etc/modsecurity.d/owasp-crs/rules/CUSTOM-RULES.conf
          subPath: custom-rules.conf
      volumes:
      - name: modsec-config
        configMap:
          name: modsecurity-custom-rules
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: modsecurity-custom-rules
  namespace: ingress
data:
  custom-rules.conf: |
    # Block requests with SQL injection patterns
    SecRule REQUEST_URI|ARGS "@rx (?i)(select|insert|update|delete|drop).*(from|into|set)" \
        "id:100001,phase:2,deny,status:403,msg:'SQL Injection Attempt'"

    # Block XSS attempts
    SecRule REQUEST_URI|ARGS "@rx <script" \
        "id:100002,phase:2,deny,status:403,msg:'XSS Attempt'"

    # Rate limit by IP
    SecRule IP:REQUEST_COUNT "@gt 100" \
        "id:100003,phase:1,deny,status:429,msg:'Rate limit exceeded'"
```

## Part 3: Intrusion Detection (45 minutes)

### Task 3.1: Deploy Suricata IDS

```yaml
# suricata/deployment.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: suricata
  namespace: security
spec:
  selector:
    matchLabels:
      app: suricata
  template:
    metadata:
      labels:
        app: suricata
    spec:
      hostNetwork: true
      containers:
      - name: suricata
        image: jasonish/suricata:latest
        securityContext:
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        args: ["-c", "/etc/suricata/suricata.yaml", "-i", "eth0"]
        volumeMounts:
        - name: config
          mountPath: /etc/suricata/suricata.yaml
          subPath: suricata.yaml
        - name: rules
          mountPath: /var/lib/suricata/rules
        - name: logs
          mountPath: /var/log/suricata
      volumes:
      - name: config
        configMap:
          name: suricata-config
      - name: rules
        configMap:
          name: suricata-rules
      - name: logs
        hostPath:
          path: /var/log/suricata
```

### Task 3.2: Custom Detection Rules

```text
# suricata-rules/custom.rules
# Detect SSH brute force
alert tcp any any -> $HOME_NET 22 (msg:"SSH Brute Force Attempt"; \
    flow:to_server,established; threshold:type both, track by_src, count 10, seconds 60; \
    sid:1000001; rev:1;)

# Detect SQL injection in HTTP
alert http any any -> $HTTP_SERVERS $HTTP_PORTS (msg:"SQL Injection Attempt"; \
    flow:to_server,established; content:"SELECT"; nocase; http_uri; \
    content:"FROM"; nocase; http_uri; distance:0; sid:1000002; rev:1;)

# Detect cryptocurrency mining
alert tcp $HOME_NET any -> any any (msg:"Crypto Mining Pool Connection"; \
    flow:to_server,established; content:"stratum+tcp://"; sid:1000003; rev:1;)

# Detect reverse shell
alert tcp $HOME_NET any -> $EXTERNAL_NET any (msg:"Possible Reverse Shell"; \
    flow:to_server,established; content:"/bin/sh"; sid:1000004; rev:1;)
```

## Part 4: Zero Trust Implementation (45 minutes)

### Task 4.1: Istio Service Mesh mTLS

```yaml
# istio/peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# istio/authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Empty spec = deny all
```

### Task 4.2: Verify mTLS

```bash
# Check mTLS status
istioctl authn tls-check frontend.production backend.production

# Test connectivity with mTLS
kubectl exec -it frontend-pod -n production -- curl https://backend:8080/health --cacert /etc/certs/root-cert.pem
```

## Verification

Complete the following checklist:

- [ ] Implemented default-deny network policies
- [ ] Created application-specific network policies
- [ ] Deployed and configured WAF
- [ ] Set up Suricata IDS with custom rules
- [ ] Configured Istio mTLS

## Summary

In this lab, you:
- Implemented network segmentation with Kubernetes Network Policies
- Deployed Web Application Firewall
- Set up Intrusion Detection with Suricata
- Configured Zero Trust with Istio mTLS

## Next Steps

- Lab 12: DevSecOps Implementation
- Review NIST Zero Trust Architecture
- Study network security best practices

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Kubernetes Network Policies
- Web Application Firewall
- Intrusion Detection
- Zero Trust Implementation

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
