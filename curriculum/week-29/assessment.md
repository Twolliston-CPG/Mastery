# Week 29 Assessment

> Closed book, 30 min. The real assessment this week is the two mock scores; this is the knowledge
> underneath them. Exam figures are planning estimates; confirm them in the candidate handbook.

## Part A — Say it (15 min)

1. State the per-task ritual, all six steps, in order.
2. Why is `expandtab` in `.vimrc` not optional in the exam?
3. `kubectl run x --image=busybox -- sleep 3600` versus the same with `--command`. What differs, and when does it matter?
4. A pod is Pending and `describe` shows **no** events. Which component is down, and why does every other Pending cause write an event?
5. `kubectl` on the control plane says `Forbidden` for `get nodes`, as user `system:node:k8s-cp`. Which file is wrong, and what did it get swapped with?
6. Node `NotReady`: name the three commands you run on the node, in order.
7. Pods on one node stuck `ContainerCreating` with `network plugin not ready`. Which family is it, and what is the first thing you check in `kube-system`?
8. Cluster names resolve, external names do not. What is the one line in the CoreDNS ConfigMap to read?
9. Name the four exam troubleshooting families and the first command for each.
10. State the two-minute rule and the reason it is two and not five.
11. Why do the long tasks (etcd restore, node upgrade) go in the middle of the order and not last?
12. The blueprint weights, all five, from memory.
13. The three etcdctl cert flags, and where to copy them from in under ten seconds.
14. What does "the fix must survive a reboot" change about a `systemctl` answer?
15. You finished a task in the wrong context. What does it score, and what is the cheapest habit that prevents it?

## Part B — Write it (15 min)

Write from memory, then validate each with `kubectl apply --dry-run=server -f -` on kind:

16. A NetworkPolicy allowing DNS egress to CoreDNS from every pod in a namespace
17. A CronJob every ten minutes, `Forbid` concurrency, history 3 and 1
18. A pod with a `nodeSelector`, a toleration for the control-plane taint, and two containers sharing an `emptyDir`
19. A `hostPath` PV with `Retain`, class `manual`, and the PVC that binds it
20. A Gateway on HTTP 80 and an HTTPRoute for one host to one service
21. The `etcdctl snapshot save` command with its three cert flags, and the `etcdutl snapshot restore` with a new data dir

## Scoring

| Band | Means |
|---|---|
| Part A 13+ and Part B all six valid | ready for killer.sh session 1 as a predictor |
| Part A 10 to 12 | redo Lab 1 Part 5 and Lab 2 before Friday |
| Below 10 | the weak families are already known; week 30 Tuesday and Thursday are decided |
