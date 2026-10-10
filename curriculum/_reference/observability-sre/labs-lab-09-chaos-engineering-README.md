# Lab 09: Chaos Engineering

## Overview
Implement chaos engineering practices using Chaos Mesh and LitmusChaos to proactively discover system weaknesses and improve reliability.

## Prerequisites
- Kubernetes cluster (minikube or kind)
- kubectl configured
- Helm 3.x installed
- Understanding of failure modes
- Observability stack from previous labs

## Learning Objectives
- Deploy chaos engineering platforms
- Design and execute chaos experiments
- Implement steady-state hypothesis validation
- Conduct GameDay exercises
- Build resilience testing into CI/CD

## Lab Environment

### Kubernetes Setup
```bash
# Create kind cluster with multiple nodes
cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

kind create cluster --name chaos-lab --config kind-config.yaml

# Verify cluster
kubectl get nodes
```

### Application Deployment
```yaml
# demo-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: demo
  labels:
    app: web-frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      containers:
        - name: web
          image: nginx:alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: web-frontend
  namespace: demo
spec:
  selector:
    app: web-frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
  namespace: demo
  labels:
    app: api-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-backend
  template:
    metadata:
      labels:
        app: api-backend
    spec:
      containers:
        - name: api
          image: hashicorp/http-echo
          args:
            - "-listen=:8080"
            - "-text=Hello from API"
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
```

---

## Part 1: Guided Exercises

### Exercise 1.1: Chaos Mesh Installation

**Objective:** Deploy Chaos Mesh on Kubernetes.

**Step 1:** Install Chaos Mesh using Helm.

```bash
# Add Chaos Mesh repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Create namespace
kubectl create namespace chaos-mesh

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.securityMode=false

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n chaos-mesh --timeout=300s

# Verify installation
kubectl get pods -n chaos-mesh
```

**Step 2:** Access Chaos Mesh Dashboard.

```bash
# Port forward to dashboard
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333 &

# Access at http://localhost:2333
```

**Step 3:** Create RBAC for experiments.

```yaml
# chaos-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: chaos-mesh-manager
rules:
  - apiGroups: ["chaos-mesh.org"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: chaos-mesh-manager-binding
subjects:
  - kind: ServiceAccount
    name: default
    namespace: demo
roleRef:
  kind: ClusterRole
  name: chaos-mesh-manager
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f chaos-rbac.yaml
```

**Verification:**
- [ ] Chaos Mesh pods running
- [ ] Dashboard accessible
- [ ] RBAC configured

---

### Exercise 1.2: Pod Chaos Experiments

**Objective:** Test application resilience to pod failures.

**Step 1:** Deploy target application.

```bash
kubectl create namespace demo
kubectl apply -f demo-app/deployment.yaml
kubectl wait --for=condition=Ready pods --all -n demo --timeout=120s
```

**Step 2:** Create pod kill experiment.

```yaml
# experiments/pod-kill.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-frontend
  namespace: demo
spec:
  action: pod-kill
  mode: one  # Kill one pod at a time
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: web-frontend
  scheduler:
    cron: "@every 2m"  # Kill a pod every 2 minutes
```

```bash
kubectl apply -f experiments/pod-kill.yaml

# Watch pod status
watch kubectl get pods -n demo
```

**Step 3:** Create pod failure experiment.

```yaml
# experiments/pod-failure.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-backend
  namespace: demo
spec:
  action: pod-failure
  mode: fixed-percent
  value: "50"  # Fail 50% of matching pods
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: api-backend
  duration: "60s"
```

```bash
kubectl apply -f experiments/pod-failure.yaml
```

**Step 4:** Create container kill experiment.

```yaml
# experiments/container-kill.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: container-kill
  namespace: demo
spec:
  action: container-kill
  mode: one
  containerNames:
    - web
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: web-frontend
  duration: "30s"
```

**Step 5:** Observe and validate.

```bash
# Check experiment status
kubectl get podchaos -n demo

# Monitor application availability
while true; do
  kubectl run -n demo curl-test --rm -i --restart=Never \
    --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://web-frontend
  sleep 2
done
```

**Verification:**
- [ ] Pods killed and recovered
- [ ] Application remains available
- [ ] Experiment status shows completed

---

### Exercise 1.3: Network Chaos Experiments

**Objective:** Test application behavior under network failures.

**Step 1:** Create network delay experiment.

```yaml
# experiments/network-delay.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay
  namespace: demo
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: api-backend
  delay:
    latency: "200ms"
    jitter: "50ms"
    correlation: "25"
  duration: "5m"
  direction: to
  target:
    selector:
      namespaces:
        - demo
      labelSelectors:
        app: web-frontend
    mode: all
```

```bash
kubectl apply -f experiments/network-delay.yaml
```

**Step 2:** Create network partition experiment.

```yaml
# experiments/network-partition.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition
  namespace: demo
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: api-backend
  direction: both
  target:
    selector:
      namespaces:
        - demo
      labelSelectors:
        app: web-frontend
    mode: all
  duration: "2m"
```

**Step 3:** Create packet loss experiment.

```yaml
# experiments/packet-loss.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: packet-loss
  namespace: demo
spec:
  action: loss
  mode: all
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: web-frontend
  loss:
    loss: "30"       # 30% packet loss
    correlation: "25"
  duration: "3m"
```

**Step 4:** Create bandwidth limit experiment.

```yaml
# experiments/bandwidth-limit.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: bandwidth-limit
  namespace: demo
spec:
  action: bandwidth
  mode: all
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: web-frontend
  bandwidth:
    rate: "1mbps"
    limit: 20971520
    buffer: 10000
  duration: "5m"
```

**Verification:**
- [ ] Latency visible in metrics
- [ ] Application handles partition gracefully
- [ ] Packet loss effects observed

---

### Exercise 1.4: Resource Stress Experiments

**Objective:** Test application behavior under resource pressure.

**Step 1:** Create CPU stress experiment.

```yaml
# experiments/cpu-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress
  namespace: demo
spec:
  mode: one
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: web-frontend
  stressors:
    cpu:
      workers: 2
      load: 80  # 80% CPU usage
  duration: "3m"
```

**Step 2:** Create memory stress experiment.

```yaml
# experiments/memory-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: memory-stress
  namespace: demo
spec:
  mode: one
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: web-frontend
  stressors:
    memory:
      workers: 2
      size: "200Mi"  # Consume 200Mi memory
  duration: "2m"
```

**Step 3:** Create disk I/O stress experiment.

```yaml
# experiments/io-stress.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-stress
  namespace: demo
spec:
  action: latency
  mode: one
  selector:
    namespaces:
      - demo
    labelSelectors:
      app: api-backend
  volumePath: /var/log
  path: "*"
  delay: "100ms"
  percent: 50
  duration: "5m"
```

**Step 4:** Monitor resource usage during experiments.

```bash
# Watch resource usage
kubectl top pods -n demo --containers

# Check if pods are OOMKilled
kubectl get events -n demo --field-selector reason=OOMKilled
```

**Verification:**
- [ ] CPU stress affects performance
- [ ] Memory stress triggers OOM handling
- [ ] I/O latency visible in application

---

### Exercise 1.5: Chaos Workflows

**Objective:** Create complex chaos scenarios with workflows.

**Step 1:** Create a workflow with multiple experiments.

```yaml
# experiments/workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: chaos-workflow
  namespace: demo
spec:
  entry: the-entry
  templates:
    - name: the-entry
      templateType: Serial
      deadline: 30m
      children:
        - network-delay-step
        - wait-step
        - pod-kill-step
        - cleanup-step

    - name: network-delay-step
      templateType: NetworkChaos
      deadline: 5m
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces:
            - demo
          labelSelectors:
            app: api-backend
        delay:
          latency: "100ms"
        duration: "3m"

    - name: wait-step
      templateType: Suspend
      deadline: 1m
      suspend:
        duration: "30s"

    - name: pod-kill-step
      templateType: PodChaos
      deadline: 5m
      podChaos:
        action: pod-kill
        mode: one
        selector:
          namespaces:
            - demo
          labelSelectors:
            app: web-frontend

    - name: cleanup-step
      templateType: Suspend
      deadline: 1m
      suspend:
        duration: "10s"
```

**Step 2:** Create parallel chaos workflow.

```yaml
# experiments/parallel-workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: parallel-chaos
  namespace: demo
spec:
  entry: parallel-entry
  templates:
    - name: parallel-entry
      templateType: Parallel
      deadline: 10m
      children:
        - network-chaos
        - stress-chaos

    - name: network-chaos
      templateType: NetworkChaos
      deadline: 5m
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces:
            - demo
          labelSelectors:
            app: api-backend
        delay:
          latency: "50ms"
        duration: "3m"

    - name: stress-chaos
      templateType: StressChaos
      deadline: 5m
      stressChaos:
        mode: one
        selector:
          namespaces:
            - demo
          labelSelectors:
            app: web-frontend
        stressors:
          cpu:
            workers: 1
            load: 50
        duration: "3m"
```

**Step 3:** Execute and monitor workflows.

```bash
# Apply workflow
kubectl apply -f experiments/workflow.yaml

# Monitor workflow status
kubectl get workflow -n demo
kubectl describe workflow chaos-workflow -n demo

# Watch experiment progress
watch kubectl get podchaos,networkchaos,stresschaos -n demo
```

**Verification:**
- [ ] Workflow executes all steps
- [ ] Steps execute in correct order
- [ ] Parallel experiments run simultaneously

---

## Part 2: Semi-Guided Exercises

### Exercise 2.1: LitmusChaos Implementation

**Objective:** Deploy and use LitmusChaos for chaos experiments.

**Requirements:**
1. Install LitmusChaos operator
2. Create ChaosEngine for experiments
3. Run pod-delete experiment
4. Analyze chaos results

**Hints:**
- Use LitmusChaos Helm chart
- ChaosExperiments define experiment types
- ChaosEngine triggers experiments
- ChaosResults show outcomes

**Starting Point:**
```bash
# Install LitmusChaos
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm install litmus litmuschaos/litmus \
  --namespace litmus \
  --create-namespace
```

---

### Exercise 2.2: Steady-State Hypothesis

**Objective:** Implement automated steady-state validation.

**Requirements:**
1. Define steady-state metrics
2. Create pre-experiment validation
3. Create post-experiment validation
4. Automate comparison

**Hints:**
- Use Prometheus queries for validation
- Define acceptable thresholds
- Compare before/after metrics

---

### Exercise 2.3: Chaos in CI/CD

**Objective:** Integrate chaos experiments into deployment pipeline.

**Requirements:**
1. Run chaos experiments in staging
2. Gate deployments on chaos results
3. Automatic rollback on failures
4. Report chaos results

---

### Exercise 2.4: Custom Chaos Experiments

**Objective:** Create custom chaos experiment types.

**Requirements:**
1. Define custom experiment CRD
2. Implement experiment controller
3. Create experiment templates
4. Document usage

---

## Part 3: Challenge Exercises

### Challenge 3.1: GameDay Exercise

**Objective:** Plan and execute a full GameDay chaos exercise.

**Scenario:**
Conduct a 4-hour GameDay to test:
- Multi-zone failure
- Database failover
- Cache invalidation
- External API outage

**Requirements:**
1. Create GameDay plan
2. Define success criteria
3. Execute experiments
4. Document findings

**Success Criteria:**
- [ ] All planned scenarios executed
- [ ] System recovery within SLO
- [ ] Action items documented
- [ ] Improvements identified

---

### Challenge 3.2: Automated Chaos Testing

**Objective:** Build automated chaos testing framework.

**Requirements:**
1. Scheduled chaos experiments
2. Automatic rollback on SLO breach
3. Results aggregation
4. Trend analysis

---

### Challenge 3.3: Multi-Cluster Chaos

**Objective:** Implement chaos across multiple clusters.

**Requirements:**
1. Cross-cluster experiment coordination
2. Regional failure simulation
3. Data plane chaos
4. Control plane chaos

---

## Cleanup

```bash
# Delete experiments
kubectl delete podchaos,networkchaos,stresschaos,workflow --all -n demo

# Delete Chaos Mesh
helm uninstall chaos-mesh -n chaos-mesh

# Delete demo app
kubectl delete namespace demo

# Delete kind cluster
kind delete cluster --name chaos-lab
```

## Additional Resources

- [Chaos Mesh Documentation](https://chaos-mesh.org/docs/)
- [LitmusChaos Documentation](https://docs.litmuschaos.io/)
- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [StreamCo Chaos Engineering](https://streamco.github.io/chaosmonkey/)

## Next Lab
Continue to [Lab 10: Capacity Planning](../lab-10-capacity-planning/README.md) to implement capacity planning practices.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Kubernetes Setup
- Application Deployment
- 1: Chaos Mesh Installation
- 2: Pod Chaos Experiments

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Prometheus monitors the service."* |
| ✓ | *"Prometheus discovers targets from the Kubernetes API, applies relabelling rules, scrapes `/metrics` over HTTP on an interval, and appends samples to a local TSDB. Nothing is pushed — so a target missing from a dashboard is a service-discovery problem, not an application one."* |

**Trace it:** A latency regression → a phone ringing. Name each hop: sample, rule evaluation, alert state transition, routing, notification — and where each one can silently stop.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [SRE Workbook ch. 5, *Alerting on SLOs*](https://sre.google/workbook/alerting-on-slos/) — free, and the best thing written on why static thresholds page you for nothing.
Full list per domain: [`SOURCES.md`](../SOURCES.md#observability-sre)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
