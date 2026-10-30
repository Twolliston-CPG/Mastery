# Figure 27.1 — A cluster you built by hand, and what kubeadm wrote

> Week 27 · badges ① to ⑩ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 27.1 — A cluster you built by hand, and what kubeadm wrote](figure-27.1-a-cluster-you-built-by-hand.png)

kind hides the quarter of the exam that lives on real nodes. The blue path is one cluster from kubeadm init to an upgraded worker; every box is a file or a command you can point at on k8s-cp.

## What to say, badge by badge

- **Open.** “Week 17 you ran kubeadm once, by hand. This week you own it. Two or three VMs in the lab project, no kind, and by Saturday you have initialised, joined, backed up, restored, upgraded and broken the cluster, and you can say what every file under /etc/kubernetes is for. That is the quarter of the exam kind could not teach.”
- **① kubeadm init.** “On k8s-cp. Preflight wants two CPUs and a few gigabytes; the pod network CIDR has to match the CNI you install next; and the join command it prints is the token plus the CA hash, so save it. Everything the next four badges describe is what this one command wrote.”
- **② four static pods.** “The kubelet reads /etc/kubernetes/manifests and runs whatever is there with no API server involved. That is how the API server itself starts. A typo in one of those files takes the control plane down, and kubectl cannot tell you, because kubectl needs the thing that is down. crictl can.”
- **③ PKI and kubeconfigs.** “A CA in /etc/kubernetes/pki, client certificates for every component, and admin.conf for you. kubeadm certs check-expiration shows the dates; the client certificates last a year and renew with one command. A kubeconfig is three things: a server, a CA to trust it by, and a credential.”
- **④ Calico.** “Nodes stay NotReady until a CNI runs. Calico in VXLAN mode here, chosen because it enforces NetworkPolicy, which week 19 showed the kind default does not. Every pod gets an address from the CIDR you passed to init.”
- **⑤ kubeadm join.** “A worker joins with a token that lives twenty-four hours and a hash of the CA, so the worker can prove it is talking to the right control plane. Lose the token and kubeadm token create prints a new one; the hash does not change.”
- **⑥ etcd snapshot and restore.** “etcdctl snapshot save, with the three certificate flags, because etcd listens with TLS and nothing else. Restore into a new data directory, point the static-pod manifest at it, and prove it: an object created after the snapshot must be gone. Do it twice; the exam asks for exactly this.”
- **⑦ upgrade one minor.** “The nodes are installed one minor below the exam's version on purpose. kubeadm upgrade plan, then apply on the control plane, then its kubelet. Each worker: drain, upgrade the packages, kubeadm upgrade node, restart the kubelet, uncordon. The order is the content.”
- **⑧ HA control plane.** “Three control planes behind a load balancer on 6443, etcd either stacked on them or external. You read it and can draw it; you do not build it here. The exam asks you to know the shape.”
- **⑨ node break/fix.** “Six new scenarios, BF-59 to BF-64, all on real nodes: the kubelet stopped or using the wrong cgroup driver, an expired or mis-pathed certificate in a kubeconfig, a manifest typo, the CNI gone, containerd stopped, etcd unreachable. Each one starts with systemctl and journalctl, not kubectl.”
- **⑩ book the exam now.** “Monday of this week, for the end of week 30. An unbooked exam slips. The package carries two simulator sessions and a free retake, so the risk of booking early is small and the cost of not booking is the whole module.”
- **Close.** “Init, static pods, certificates, CNI, join, snapshot, upgrade. Seven things kubeadm did or you did, in order, each one a file you can open. Next week fills in the objects the 2025 blueprint added; this week is the cluster they run on.”

**Print it:** [`figure-27.1-numbered-spoken.pdf`](figure-27.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 27
```
