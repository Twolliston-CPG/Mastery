# Figure 14.1 — What happens when you kubectl apply a Deployment

> Week 14 · badges ① to ⑪ · about four minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 14.1 — What happens when you kubectl apply a Deployment](figure-14.1-what-happens-when-you-kubectl-apply.png)

The control plane is a loop of controllers watching one database. Follow the blue path from your terminal to a running container, then the dashed path back out through a Service and the Ingress.

## What to say, badge by badge

- **Open.** “This is the hinge week, and Wednesday you also send ten applications. The technical picture is one loop: everything you ask for is written to one database, and controllers keep making the world match it. Follow the blue line from your terminal to a running container.”
- **① kubectl apply.** “kubectl turns a YAML file into an HTTP request to the API server. Nothing else in the cluster ever hears from you directly. `kubectl -v=8` shows the request if you want to see it.”
- **② kube-apiserver.** “Three gates in order: who are you, may you do this, and admission, which can mutate or reject the object. Then it writes to etcd. It is the only component that talks to etcd, which is why it is the thing every other component watches.”
- **③ etcd.** “The desired state of everything, with history. On kind it is a static pod on the control-plane node. Lose etcd without a backup and the cluster forgets what it was supposed to run.”
- **④ controller manager.** “A Deployment controller sees a new Deployment and creates a ReplicaSet. The ReplicaSet controller sees it and creates N Pods. Each controller watches one kind of object and makes one kind of child. That is the whole design, repeated.”
- **⑤ scheduler.** “A pod with no node assigned is the scheduler's queue. It filters nodes by resources, taints, and affinity, scores the rest, and writes the choice back. Pending forever means the filter emptied the list, and `kubectl describe` says why.”
- **⑥ kubelet.** “The agent on the node sees a pod assigned to it, pulls the image, and starts the containers. The events read Scheduled, Pulling, Pulled, Created, Started. Watch them with `kubectl get events -w`.”
- **⑦ the pod.** “One IP address, shared by all containers in it, who also share network and IPC namespaces. That is why a sidecar can talk to the app on localhost. The week-4 namespaces, grouped.”
- **⑧ Service.** “A stable virtual IP. kube-proxy writes iptables rules that spread it across the pod IPs whose readiness probe passes. A Service with no endpoints means the selector matched nothing or nothing is ready.”
- **⑨ Ingress.** “Host and path rules pointing at Services, implemented by Contour on this cluster. Without `ingressClassName`, the controller ignores the resource and you get a 404 that looks like a routing bug.”
- **⑩ ConfigMap and Secret.** “Configuration and secrets, mounted as files or injected as environment. A Secret is base64 encoded, not encrypted; week 19 is where real secret handling lives.”
- **⑪ the three failures.** “ImagePullBackOff is the registry, the tag, or credentials. CrashLoopBackOff is the process exiting; read the previous container's logs. No endpoints is the selector or readiness. Diagnose all three from events and logs, before week 15 adds six more.”
- **Close.** “Write to one database, let controllers converge, and route in through a Service and an Ingress. By Saturday the week-4 Compose stack runs here. And Tuesday the applications go out, because the pipeline has a ten-week lag.”

**Print it:** [`figure-14.1-numbered-spoken.pdf`](figure-14.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 14
```
