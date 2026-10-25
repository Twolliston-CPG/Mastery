# Figure 28.1 — Everything the 2025 blueprint added, on your own cluster

> Week 28 · badges ① to ⑩ · about three minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 28.1 — Everything the 2025 blueprint added, on your own cluster](figure-28.1-everything-the-2025-blueprint-added-on.png)

The exam blueprint was revised in 2025 to add Kustomize, Helm, Gateway API, CRDs and operators, and dynamic provisioning. Weeks 14 to 19 touched most of it; this week does each one properly, on the kubeadm cluster, and then again from memory.

## What to say, badge by badge

- **Open.** “Last week was the cluster. This week is the list of objects the exam added in 2025, each one built on that cluster, each one timed. Nothing here is new to you except the Gateway split and the operator; everything else is a week-15 topic done at exam speed.”
- **① Kustomize.** “A base directory of plain manifests and overlays that patch it: replicas and an image tag for dev, something else for prod. One strategic-merge patch and one JSON patch, so you have written both forms. kubectl apply -k; no release object, no history, no templating.”
- **② Helm as an install tool.** “The exam does not ask you to author a chart. It asks you to add a repository, install a chart with a value overridden, upgrade it, roll it back, and read helm template before you apply. Four commands and the discipline of reading first.”
- **③ Gateway API.** “Three objects where Ingress had one, split by who owns them: the class is the implementation, the Gateway is the listener the platform runs, the HTTPRoute is the rule the application team writes. Match on host, path, and a header; split traffic between two Services by weight.”
- **④ CoreDNS.** “The cluster's resolver is a Deployment reading a ConfigMap called the Corefile. Add a stub domain that forwards to another server, restart nothing, and prove it with nslookup from a pod. Most DNS tasks on the exam are this ConfigMap.”
- **⑤ CRDs and an operator.** “Install a small, real operator with Helm. kubectl explain its custom resource the same way you explain a Pod. Create one and watch the operator make the underlying objects. Then write a CRD of your own with a validation schema and watch the API server reject a bad field.”
- **⑥ scheduling, under exam conditions.** “nodeName bypasses the scheduler entirely. nodeSelector and affinity ask for a node; taints refuse pods that do not tolerate them; a PriorityClass decides who is evicted. A static pod on a worker is a manifest in that worker's manifests directory, and the API server shows it with the node name appended.”
- **⑦ Jobs, CronJobs, DaemonSets.** “completions and parallelism, a backoffLimit that decides when a Job gives up, a CronJob's concurrencyPolicy and history limits, a DaemonSet that puts one pod on every node and tolerates the control plane taint if you tell it to.”
- **⑧ dynamic provisioning.** “On kubeadm nothing provisions storage until you install something. A provisioner, a StorageClass marked default, a claim that binds without naming a class, the reclaim policy on the volume, and an expansion that only works if the class allows it.”
- **⑨ break/fix.** “BF-45 and BF-46 from week 15 again, now on real nodes, plus two scenarios from the node set. Timed, narrated, journaled.”
- **⑩ from memory, timed.** “Saturday: every lab in this week repeated with the file closed, against the target time written at the end of each. The exam has no notes; this is the first week that trains that.”
- **Close.** “Kustomize, Helm, Gateway, CoreDNS, CRDs, scheduling, Jobs, storage. Eight objects, all on your cluster, all timed. Week 29 is where the speed comes from.”

**Print it:** [`figure-28.1-numbered-spoken.pdf`](figure-28.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 28
```
