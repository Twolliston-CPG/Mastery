# Exercise 1: Tekton Pipeline Setup

## Objective

Deploy and configure Tekton Pipelines for cloud-native CI/CD with reusable tasks, pipelines, and webhook triggers.

## Prerequisites

- Running Kubernetes cluster
- kubectl configured
- Container registry access

## Tasks

### Task 1: Install Tekton Components

```bash
# Install Tekton Pipelines
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton Triggers
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# Install Tekton Dashboard
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Verify installation
kubectl get pods -n tekton-pipelines
kubectl get pods -n tekton-pipelines-resolvers
```

### Task 2: Create Docker Registry Secret

```yaml
# registry-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-credentials
  namespace: default
  annotations:
    tekton.dev/docker-0: https://index.docker.io/v1/
type: kubernetes.io/basic-auth
stringData:
  username: <docker-username>
  password: <docker-password>

---
# Service account for pipeline
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-build-sa
  namespace: default
secrets:
- name: docker-credentials
```

### Task 3: Create Reusable Tasks

```yaml
# tasks/git-clone.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: git-clone
spec:
  description: Clone a git repository
  params:
  - name: url
    type: string
    description: Repository URL
  - name: revision
    type: string
    default: main
    description: Branch or tag to checkout
  - name: depth
    type: string
    default: "1"
    description: Clone depth (0 for full history)

  workspaces:
  - name: output
    description: Workspace to clone into

  results:
  - name: commit
    description: The commit SHA
  - name: url
    description: The repository URL

  steps:
  - name: clone
    image: gcr.io/tekton-releases/github.com/tektoncd/pipeline/cmd/git-init:v0.40.0
    script: |
      #!/bin/sh
      set -e

      CHECKOUT_DIR="$(workspaces.output.path)/source"

      git clone --depth $(params.depth) --branch $(params.revision) \
        $(params.url) ${CHECKOUT_DIR}

      cd ${CHECKOUT_DIR}
      RESULT_SHA=$(git rev-parse HEAD)

      echo -n "${RESULT_SHA}" | tee $(results.commit.path)
      echo -n "$(params.url)" | tee $(results.url.path)

      echo "Cloned $(params.url) at revision ${RESULT_SHA}"

---
# tasks/kaniko-build.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kaniko-build
spec:
  description: Build and push container image using Kaniko
  params:
  - name: IMAGE
    type: string
    description: Image name with tag
  - name: DOCKERFILE
    type: string
    default: ./Dockerfile
  - name: CONTEXT
    type: string
    default: .
  - name: EXTRA_ARGS
    type: array
    default: []

  workspaces:
  - name: source
  - name: dockerconfig
    optional: true
    description: Docker config.json

  results:
  - name: IMAGE_DIGEST
    description: Digest of the built image
  - name: IMAGE_URL
    description: URL of the built image

  steps:
  - name: build-and-push
    image: gcr.io/kaniko-project/executor:v1.18.0
    args:
    - --dockerfile=$(params.DOCKERFILE)
    - --context=$(workspaces.source.path)/source/$(params.CONTEXT)
    - --destination=$(params.IMAGE)
    - --digest-file=$(results.IMAGE_DIGEST.path)
    - $(params.EXTRA_ARGS[*])
    env:
    - name: DOCKER_CONFIG
      value: $(workspaces.dockerconfig.path)
    securityContext:
      runAsUser: 0

  - name: write-url
    image: bash:5.2
    script: |
      echo -n "$(params.IMAGE)" | tee $(results.IMAGE_URL.path)

---
# tasks/trivy-scan.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: trivy-scan
spec:
  description: Scan container image for vulnerabilities
  params:
  - name: IMAGE
    type: string
  - name: SEVERITY
    type: string
    default: CRITICAL,HIGH
  - name: EXIT_CODE
    type: string
    default: "1"
    description: Exit code when vulnerabilities found

  steps:
  - name: scan
    image: aquasec/trivy:0.48.0
    script: |
      #!/bin/sh
      trivy image \
        --severity $(params.SEVERITY) \
        --exit-code $(params.EXIT_CODE) \
        --ignore-unfixed \
        --no-progress \
        --format table \
        $(params.IMAGE)

---
# tasks/kubectl-apply.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kubectl-apply
spec:
  description: Apply Kubernetes manifests
  params:
  - name: MANIFEST_DIR
    type: string
    default: k8s
  - name: NAMESPACE
    type: string
    default: default

  workspaces:
  - name: source
  - name: kubeconfig
    optional: true

  steps:
  - name: apply
    image: bitnami/kubectl:1.28
    script: |
      #!/bin/bash
      set -e

      if [ -f "$(workspaces.kubeconfig.path)/kubeconfig" ]; then
        export KUBECONFIG="$(workspaces.kubeconfig.path)/kubeconfig"
      fi

      cd $(workspaces.source.path)/source/$(params.MANIFEST_DIR)

      echo "Applying manifests to namespace $(params.NAMESPACE)..."
      kubectl apply -f . -n $(params.NAMESPACE)

      echo "Waiting for rollout..."
      kubectl rollout status deployment --timeout=300s -n $(params.NAMESPACE) || true
```

### Task 4: Create Build Pipeline

```yaml
# pipelines/build-and-deploy.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: build-and-deploy
spec:
  description: Build, scan, and deploy application

  params:
  - name: git-url
    type: string
    description: Git repository URL
  - name: git-revision
    type: string
    default: main
  - name: image-name
    type: string
    description: Container image name (without tag)
  - name: image-tag
    type: string
    default: latest
  - name: deploy-namespace
    type: string
    default: default

  workspaces:
  - name: shared-workspace
  - name: docker-credentials
  - name: kubeconfig
    optional: true

  tasks:
  # Stage 1: Clone repository
  - name: fetch-source
    taskRef:
      name: git-clone
    params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.git-revision)
    workspaces:
    - name: output
      workspace: shared-workspace

  # Stage 2: Run tests
  - name: run-tests
    runAfter: [fetch-source]
    taskSpec:
      workspaces:
      - name: source
      steps:
      - name: test
        image: node:20-alpine
        workingDir: $(workspaces.source.path)/source
        script: |
          #!/bin/sh
          if [ -f "package.json" ]; then
            npm ci
            npm test || echo "No tests found"
          fi
    workspaces:
    - name: source
      workspace: shared-workspace

  # Stage 3: Build container image
  - name: build-image
    runAfter: [run-tests]
    taskRef:
      name: kaniko-build
    params:
    - name: IMAGE
      value: $(params.image-name):$(tasks.fetch-source.results.commit)
    workspaces:
    - name: source
      workspace: shared-workspace
    - name: dockerconfig
      workspace: docker-credentials

  # Stage 4: Scan for vulnerabilities
  - name: scan-image
    runAfter: [build-image]
    taskRef:
      name: trivy-scan
    params:
    - name: IMAGE
      value: $(params.image-name):$(tasks.fetch-source.results.commit)
    - name: EXIT_CODE
      value: "0"  # Don't fail pipeline, just report

  # Stage 5: Deploy to Kubernetes
  - name: deploy
    runAfter: [scan-image]
    taskRef:
      name: kubectl-apply
    params:
    - name: NAMESPACE
      value: $(params.deploy-namespace)
    workspaces:
    - name: source
      workspace: shared-workspace
    - name: kubeconfig
      workspace: kubeconfig

  # Final tasks (always run)
  finally:
  - name: notify
    taskSpec:
      params:
      - name: pipeline-status
        type: string
      steps:
      - name: send-notification
        image: curlimages/curl:8.4.0
        script: |
          #!/bin/sh
          echo "Pipeline completed with status: $(params.pipeline-status)"
          # Add webhook notification here
    params:
    - name: pipeline-status
      value: "$(tasks.status)"
```

### Task 5: Create PipelineRun

```yaml
# pipelineruns/build-and-deploy-run.yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: build-and-deploy-
spec:
  pipelineRef:
    name: build-and-deploy

  params:
  - name: git-url
    value: https://github.com/myorg/myapp.git
  - name: git-revision
    value: main
  - name: image-name
    value: myregistry.io/myapp
  - name: deploy-namespace
    value: production

  workspaces:
  - name: shared-workspace
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi

  - name: docker-credentials
    secret:
      secretName: docker-credentials

  - name: kubeconfig
    emptyDir: {}

  serviceAccountName: tekton-build-sa

  timeout: 1h

  podTemplate:
    securityContext:
      fsGroup: 65532
```

### Task 6: Configure Webhook Triggers

```yaml
# triggers/github-trigger.yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
  - name: github-push-trigger
    interceptors:
    - ref:
        name: github
      params:
      - name: secretRef
        value:
          secretName: github-webhook-secret
          secretKey: token
      - name: eventTypes
        value: ["push", "pull_request"]

    - ref:
        name: cel
      params:
      - name: filter
        value: >-
          body.ref.startsWith('refs/heads/main') ||
          body.ref.startsWith('refs/heads/develop')

    bindings:
    - ref: github-binding
    template:
      ref: pipeline-template

---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-binding
spec:
  params:
  - name: git-url
    value: $(body.repository.clone_url)
  - name: git-revision
    value: $(body.after)
  - name: repo-name
    value: $(body.repository.name)

---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: pipeline-template
spec:
  params:
  - name: git-url
  - name: git-revision
  - name: repo-name

  resourcetemplates:
  - apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      generateName: $(tt.params.repo-name)-
    spec:
      pipelineRef:
        name: build-and-deploy
      params:
      - name: git-url
        value: $(tt.params.git-url)
      - name: git-revision
        value: $(tt.params.git-revision)
      - name: image-name
        value: myregistry.io/$(tt.params.repo-name)
      workspaces:
      - name: shared-workspace
        volumeClaimTemplate:
          spec:
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 1Gi
      - name: docker-credentials
        secret:
          secretName: docker-credentials
      serviceAccountName: tekton-build-sa

---
# Service and Ingress for webhook
apiVersion: v1
kind: Service
metadata:
  name: el-github-listener
spec:
  selector:
    eventlistener: github-listener
  ports:
  - port: 8080

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-webhook
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  rules:
  - host: tekton-webhook.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: el-github-listener
            port:
              number: 8080
  tls:
  - hosts:
    - tekton-webhook.example.com
    secretName: tekton-webhook-tls
```

## Validation

```bash
# Check Tekton installation
kubectl get pods -n tekton-pipelines

# Apply tasks
kubectl apply -f tasks/

# Apply pipeline
kubectl apply -f pipelines/

# Run pipeline manually
kubectl create -f pipelineruns/build-and-deploy-run.yaml

# Watch pipeline execution
tkn pipelinerun logs -f

# Check pipeline status
tkn pipelinerun list
tkn pipelinerun describe <run-name>

# Access dashboard
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097
```

## Success Criteria

- [ ] Tekton components installed and running
- [ ] Custom tasks created successfully
- [ ] Pipeline executes all stages
- [ ] Container image built and pushed
- [ ] Security scan completes
- [ ] Webhook triggers pipeline on git push

## Troubleshooting

```bash
# Check task logs
tkn task logs <task-name>

# Check pipelinerun status
tkn pipelinerun describe <run-name>

# Debug failed step
kubectl logs <pod-name> -c step-<step-name>

# Check event listener
kubectl logs -l eventlistener=github-listener
```

## Cleanup

```bash
# Delete pipeline runs
tkn pipelinerun delete --all

# Delete resources
kubectl delete -f triggers/
kubectl delete -f pipelines/
kubectl delete -f tasks/
```

## Next Exercise

Continue to [Exercise 2: GitHub Actions Integration](./02-github-actions.md) for cloud-hosted CI/CD.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Install Tekton Components
- Create Docker Registry Secret
- Create Reusable Tasks
- Create Build Pipeline

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
