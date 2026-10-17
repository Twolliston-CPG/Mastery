# Figure 15.1 — Nine ways a pod fails to start, and where each one lives

> Week 15 · badges ① to ⑪ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 15.1 — Nine ways a pod fails to start, and where each one lives](figure-15.1-nine-ways-a-pod-fails-to.png)

This is the decision tree from the week's blog post. Each branch is a phase you can read in one `kubectl get pods`, and each leaf names the command that proves it.

## What to say, badge by badge

- **Open.** “Anyone can apply a manifest. What gets hired is diagnosing a broken cluster under time pressure while saying what you are thinking. This tree is the thing you say. The first word of STATUS picks the branch.”
- **① kubectl get pods.** “Two columns tell you which branch: STATUS and RESTARTS. Pending and ContainerCreating have zero restarts and never ran. Running with climbing restarts is dying after it starts. Running with zero Ready is alive but excluded.”
- **② Pending.** “The scheduler could not place it. `kubectl describe pod` shows a FailedScheduling event with the reason. There are three usual reasons, badges 6 to 8.”
- **③ ContainerCreating.** “It has a node but the kubelet cannot start it. Almost always the image or a volume. Describe shows which, in the events at the bottom.”
- **④ Running, restarting.** “The container starts and dies. The exit code and the previous container's logs tell you whether the app quit, the kernel killed it, or the probe did.”
- **⑤ Running, not Ready.** “The process is alive but the readiness probe fails, so the Service removes it from the endpoints. The app looks down from outside and looks fine from inside.”
- **⑥ insufficient resources.** “Requests larger than any node has free. On kind this is easy to trigger: ask for 100 CPUs. In production it is the usual Monday-morning cause.”
- **⑦ taint or affinity.** “Every node has a taint the pod does not tolerate, or an affinity rule nothing satisfies. Describe names the taint.”
- **⑧ PVC unbound.** “The claim is waiting for a volume that cannot be provisioned: no default StorageClass, or an access mode the class cannot give. Stateful pods stall here.”
- **⑨ OOMKilled.** “Exit code 137. Memory over the limit is killed instantly, where CPU over the limit is only throttled. That asymmetry is the exit criterion and the question interviewers love. Requests equal to limits makes the pod Guaranteed and last to be evicted.”
- **⑩ RBAC forbidden.** “Not a pod state, but it looks like one when a controller cannot create what it needs. `kubectl auth can-i --as` answers it in one line; a Role plus a RoleBinding fixes it.”
- **⑪ QoS.** “Guaranteed when every container's requests equal its limits. Burstable when requests are lower. BestEffort when there are none, and those die first under pressure.”
- **Close.** “Read the status, pick the branch, run the one command that proves the leaf, say it out loud. Friday you build five of these on demand; they are Gate 4, two weeks from now.”

**Print it:** [`figure-15.1-numbered-spoken.pdf`](figure-15.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 15
```
