# kubectl Speed Drill

> Weeks 14–26. **Target: each item written correctly in under 30 seconds, from memory.**
> If you take CKA, this drill *is* the exam — it is scored on speed as much as knowledge.

## Setup that pays for itself immediately

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"       # k run nginx --image=nginx $do > pod.yaml
export now="--force --grace-period=0"      # k delete pod x $now
source <(kubectl completion bash)          # or zsh
complete -F __start_kubectl k
```

## Tier 1 — Generate manifests imperatively (never hand-write YAML from scratch)

| Task | Command |
|---|---|
| Pod YAML | `k run nginx --image=nginx $do > pod.yaml` |
| Deployment YAML | `k create deploy web --image=nginx --replicas=3 $do > d.yaml` |
| Service for a deploy | `k expose deploy web --port=80 --target-port=8080 $do > svc.yaml` |
| NodePort service | `k create svc nodeport web --tcp=80:8080 $do` |
| ConfigMap from literals | `k create cm app --from-literal=KEY=val $do` |
| ConfigMap from file | `k create cm app --from-file=./config.yaml $do` |
| Secret | `k create secret generic db --from-literal=password=s3cr3t $do` |
| Job | `k create job pi --image=perl -- perl -Mbignum -wle 'print bpi(200)' $do` |
| CronJob | `k create cj backup --image=busybox --schedule="*/5 * * * *" -- /bin/sh -c date $do` |
| ServiceAccount | `k create sa deployer $do` |
| Role | `k create role pod-reader --verb=get,list,watch --resource=pods $do` |
| RoleBinding | `k create rolebinding rb --role=pod-reader --serviceaccount=app:deployer $do` |
| ClusterRoleBinding | `k create clusterrolebinding crb --clusterrole=view --serviceaccount=app:deployer $do` |
| Ingress | `k create ingress web --rule="app.local/*=web:80" $do` |
| Namespace | `k create ns staging $do` |
| Quota | `k create quota q --hard=cpu=2,memory=4Gi,pods=10 -n staging $do` |

## Tier 2 — Inspect and debug (the interview commands)

| Task | Command |
|---|---|
| Events, newest last | `k get events --sort-by=.lastTimestamp` |
| Events for one pod | `k describe pod X \| sed -n '/Events/,$p'` |
| Crashed container logs | `k logs X --previous` |
| Logs from all pods of a deploy | `k logs -l app=web --all-containers --tail=50` |
| Exec | `k exec -it X -- sh` |
| Debug a distroless pod | `k debug X -it --image=busybox --target=app` |
| Debug a node | `k debug node/NODE -it --image=busybox` |
| Port-forward | `k port-forward svc/web 8080:80` |
| Endpoints (selector check) | `k get endpoints web` |
| Show labels | `k get pods --show-labels` |
| Who am I / can I | `k auth can-i list pods --as=system:serviceaccount:app:sa -n prod` |
| Everything in a namespace | `k get all -n app` |
| Resource usage | `k top pod --containers` |
| Node capacity | `k describe node N \| grep -A5 'Allocated resources'` |
| Node taints | `k get nodes -o json \| jq '.items[].spec.taints'` |
| Sort pods by restarts | `k get pods --sort-by=.status.containerStatuses[0].restartCount` |
| Find pods on one node | `k get pods -A --field-selector spec.nodeName=NODE` |
| Raw API | `k get --raw /api/v1/nodes \| jq` |

## Tier 3 — JSONPath and edits

```bash
k get pods -o jsonpath='{.items[*].metadata.name}'
k get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
k get pod X -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
k get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

k set image deploy/web web=nginx:1.27
k scale deploy web --replicas=5
k rollout status deploy/web
k rollout undo deploy/web
k rollout history deploy/web
k patch deploy web -p '{"spec":{"replicas":3}}'
k annotate deploy web kubernetes.io/change-cause="bump to 1.27"
k label pod X env=prod --overwrite
k cordon NODE && k drain NODE --ignore-daemonsets --delete-emptydir-data
```

## Tier 4 — Write from blank (the real test)

Set a 10-minute timer. No reference. Produce a single YAML file containing:

1. A `Namespace` called `shop`
2. A `Deployment` `api`, 3 replicas, image `nginx:1.27`, port 8080
   - requests 100m/128Mi, limits 500m/256Mi
   - readiness probe on `/ready`, liveness on `/health` with a startup probe
   - non-root, read-only root filesystem, all capabilities dropped
3. A `Service` selecting it on port 80 → 8080
4. An `Ingress` for `shop.local` with `ingressClassName: contour`
5. A `ConfigMap` mounted as a volume at `/etc/app`
6. A `ServiceAccount`, `Role` (get/list pods), and `RoleBinding`
7. A `NetworkPolicy` that default-denies and then allows DNS + ingress from the ingress controller

Then: `kubectl apply --dry-run=server -f -` to validate it.

**Score yourself:** under 10 min with no reference = CKA-ready and comfortably above the junior bar.
