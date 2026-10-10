# ★ GATE 4 — Kubernetes Diagnostic Competence

> **A gate, not a quiz.** Demonstrated under a timer, narrated aloud.

---

## Part 1 — The five scenarios (the gate)

**Setup:** a partner runs `break.sh` from week 15 without telling you which scenario fired. If you're
working alone, run it yourself, then walk away for ten minutes before starting.

**Rules:**
- Timer running, visible
- **Narrate out loud** the entire time, as if an interviewer is listening
- No notes, no previous solutions, no search — `kubectl explain` and kubernetes.io docs only
- 15 minutes maximum per scenario

**Pass:** **all five** diagnosed to root cause in under 15 minutes each, with narration.

| # | Scenario | Time | Root cause identified | Narrated |
|---|---|---|---|---|
| 1 | | | ☐ | ☐ |
| 2 | | | ☐ | ☐ |
| 3 | | | ☐ | ☐ |
| 4 | | | ☐ | ☐ |
| 5 | | | ☐ | ☐ |

**Record the last one.** Play it back. Count the silences longer than five seconds.

---

## Part 2 — Write from memory (45 min)

Blank file. No reference. Produce a single YAML document containing:

1. `Namespace` `shop` with Pod Security Standards `restricted` enforced
2. `Deployment` `api`, 3 replicas, image `nginx:1.27`, container port 8080
   - requests 100m/128Mi, limits 500m/256Mi
   - startup, liveness, and readiness probes with sensible values
   - non-root, read-only root filesystem, all capabilities dropped, seccomp RuntimeDefault
   - `maxSurge: 1, maxUnavailable: 0`
3. `Service` selecting it, port 80 → a **named** target port
4. `Ingress` for `shop.local` with the correct `ingressClassName`
5. `ConfigMap` mounted as a volume at `/etc/app`
6. `ServiceAccount`, `Role` (get/list/watch on pods and pods/log), `RoleBinding`
7. `PodDisruptionBudget` with `minAvailable: 2`
8. `NetworkPolicy`: default-deny ingress and egress, **plus an explicit DNS allow**

Then validate: `kubectl apply --dry-run=client -f -`

**Pass:** applies cleanly in under 45 minutes with no reference.

---

## Part 3 — Explain (20 min, out loud)

1. Kubernetes as a control loop, in one sentence.
2. requests vs limits — who enforces each, and the CPU/memory asymmetry.
3. The three probes, and the production disaster from getting liveness wrong.
4. How a Service routes traffic — name the component and the mechanism.
5. `kubectl get endpoints` — what does empty vs populated tell you?
6. IRSA end to end, in five steps.
7. Pull vs push delivery — the security argument.
8. The four-way Role/ClusterRole × RoleBinding/ClusterRoleBinding matrix.
9. Why StatefulSet PVCs are retained.
10. What gets orphaned when you delete an EKS cluster, and why.

---

## ★ Gate 4 result

| | |
|---|---|
| **PASS** — 5/5 under 15 min, Part 2 clean, Part 3 fluent | **Skip KCNA. Bank the hours toward CKA.** Move to week 18. |
| **NEAR** — 4/5, or Part 2 took 60 min | Rehearse two more days. Then re-test. **Consider KCNA** as a forcing function. |
| **FAIL** — 3 or fewer, or couldn't write from memory | **Take KCNA.** Use the deadline. Redo weeks 14–15 labs alongside week 18 — do **not** stop the job search or lose a whole week. |

**Failing this gate does not mean stopping.** It means Kubernetes needs more reps *in parallel* with
month 5, and that CKA moves to post-hire. Month 5's DevSecOps material is what differentiates you
from other juniors and it doesn't depend on Kubernetes mastery.

---

## Month 4 retrospective (Sunday)

1. **Applications sent in weeks 14–17.** Target was 40–60. What's the actual number?
2. **Responses so far.** At 2–5% cold conversion, 1–3 screens from 50 applications is *expected*.
   If it's zero after 60, the problem is upstream — résumé or targeting, not skill.
3. Conversations had. Target was 3/week.
4. Top 3 "Surprised" lines from the incident journal.
5. Gate 4 result and the KCNA decision, with the reason written down.
6. **Rest days taken.** Weeks 15–18 are where burnout hits. If you've been skipping them, that is the
   most important thing on this list.
