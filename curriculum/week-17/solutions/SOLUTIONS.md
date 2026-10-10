# Week 17 Solutions

---

## Lab 1 — The rebuild

If you got stuck, the reference is
[`../week-14/solutions/k8s-stack/`](../../week-14/solutions/k8s-stack/). But **note where you got
stuck** — that's the data.

### The things people forget, in order of frequency

1. **`ingressClassName`** — without it the controller ignores the Ingress and you get a 404
2. **`securityContext.fsGroup`** on the StatefulSet — without it the mounted volume isn't writable by
   the non-root user and Postgres fails to initialize
3. **`PGDATA` subdirectory** — the Postgres image refuses to initialize into a non-empty mount point,
   and a real PV has `lost+found`
4. **Named `targetPort`** — using a number means a `containerPort` change silently breaks the Service
5. **`LimitRange` alongside `ResourceQuota`** — with a quota in place, a pod with no requests is
   **rejected**; the LimitRange supplies defaults so ordinary manifests still work
6. **`emptyDir` mounts for `readOnlyRootFilesystem`** — nginx needs `/var/cache/nginx`, `/var/run`,
   `/tmp`

**#5 is the subtle one** and it catches people in real multi-tenant clusters: you add a quota to
control costs, and suddenly every team's deployments start failing with
`must specify limits.cpu`. The LimitRange is what makes a quota usable.

### `kubectl explain` fluency

```bash
kubectl explain deployment.spec.strategy.rollingUpdate
kubectl explain pod.spec.containers.securityContext
kubectl explain pod.spec.securityContext --recursive | head -40
kubectl explain networkpolicy.spec.egress.to
```
Available during the CKA exam and faster than the docs site. `--recursive` dumps the whole subtree,
which is how you find the field name you half-remember.

---

## Lab 2 — Gate 4 rehearsal

### Why narration is the scored skill

An interviewer cannot see you think. If you work silently for four minutes and then say "it was the
liveness probe," they have learned only that you got it right — possibly by guessing.

If you narrate — *"the pod is restarting but the logs look clean, so something external is killing
it; that's either OOM or a probe; let me check `lastState` for the exit code"* — they have learned
that you have a **method**, which is the thing that transfers to problems you haven't seen.

**Saying "I don't know, but here's how I'd find out" is a passing answer. Silence is not.**

### The five scenarios, with target times

| # | Scenario | Target | The tell |
|---|---|---|---|
| BF-43 | OOMKilled | 5 min | `lastState.terminated.reason: OOMKilled`, exit 137 |
| BF-44 | Liveness restart loop | 8 min | **Logs are normal** but it restarts; `describe` shows `Liveness probe failed` |
| BF-45 | Unschedulable | 5 min | `describe pod` → `FailedScheduling` names it verbatim |
| BF-46 | PVC Pending | 8 min | `describe pvc` → no default SC / typo / WaitForFirstConsumer |
| BF-48 | RBAC Forbidden | 5 min | The error names who, verb, resource, apiGroup, namespace |

**If any takes over 15 minutes, the gap is almost always "didn't read the events first."**
`kubectl describe pod` and `kubectl get events --sort-by=.lastTimestamp` answer roughly 70% of these
directly.

### The common anti-patterns in rehearsal

| Anti-pattern | Fix |
|---|---|
| Running `kubectl logs` first on a pod that never started | `describe` first, always |
| Editing the live resource to "try something" | Diagnose before changing. An interviewer will ask what you expect the change to prove. |
| Going straight to the most interesting hypothesis | Walk the layers in order. The boring cause is usually the cause. |
| Silence while typing | Narrate. Every command should be preceded by what you expect it to show. |

---

## Lab 3 — Bravo design

### Why the threat model comes before the code

Two reasons, and the second is the one that matters in an interview.

**First:** it tells you which controls to build. Without it you build the tools you've heard of
rather than the controls the system needs, and you end up with four scanners and no admission
control.

**Second:** *"I threat-modeled it first"* is a completely different statement from *"I added
security scanning."* One describes a process; the other describes a tool purchase. The control
narrative table is the artifact that proves the first.

### The control narrative — the format that matters

```markdown
| Threat (STRIDE) | Control | Where it runs | Evidence |
|---|---|---|---|
| Spoofing: forged image in the registry | cosign keyless signing + Kyverno `verifyImages` | CI + admission | `evidence/unsigned-image-rejected.png` |
| Tampering: malicious transitive dependency | Trivy fs scan, fail on CRITICAL | CI, pre-build | `evidence/cve-blocked-build.png` |
| Info disclosure: secret committed | gitleaks | pre-commit + CI | `evidence/gitleaks-blocked-commit.png` |
| EoP: container escape via privileged pod | PSS `restricted` + Kyverno | admission | `evidence/privileged-pod-rejected.png` |
| Lateral movement between namespaces | NetworkPolicy default-deny | runtime | `evidence/netpol-blocked.txt` |
| Repudiation: who deployed what | ArgoCD + Git history | delivery | `evidence/argocd-history.png` |
```

Three columns do the work:
- **Threat** — proves you started from risk, not from tools
- **Control** — the specific mechanism
- **Evidence** — the thing almost nobody has, and the thing an auditor (or interviewer) actually
  wants

### Scope discipline for Bravo

Weeks 18–21 are four weeks. The temptation is to add every tool. **Don't.** One tool per control
category, each one actually demonstrated blocking something:

| Category | Pick one |
|---|---|
| SAST | Semgrep |
| Dependency/container scanning | Trivy |
| Secret scanning | gitleaks |
| SBOM | syft |
| Signing | cosign |
| Admission policy | Kyverno |
| Runtime detection | Falco |
| Secrets delivery | External Secrets |

**A pipeline with eight tools where you can demonstrate all eight blocking something beats one with
twenty where you can demonstrate none.** Depth over breadth is the same principle as everywhere else
in this program.
