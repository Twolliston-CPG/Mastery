# Figure 29.1 — The exam is a speed test, and this is the speed

> Week 29 · badges ① to ⑩ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 29.1 — The exam is a speed test, and this is the speed](figure-29.1-the-exam-is-a-speed-test.png)

The knowledge is weeks 14 to 28. The exam measures how fast you can turn it into objects in a terminal you do not control, with a clock running. The blue path is the week: the terminal, the ritual, the four families of failure, a mock exam, and the first simulator session that tells you what to drill in week 30.

## What to say, badge by badge

- **Open.** “You know Kubernetes. The question this week answers is whether you can prove it in two hours, in a remote desktop, with the docs as your only reference and a context switch at the top of every task. Speed is a skill, and it is trained the same way the diagnostic loop was: timed, repeated, logged.”
- **① the exam terminal.** “An alias for kubectl, a shell variable holding the dry-run flags so YAML comes out of one short command, kubectl explain for any field you have forgotten, and a vim that indents YAML with two spaces. Set these up in the first minute of the exam; they pay for themselves on the second task.”
- **② the per-task ritual.** “Read the task to the end and name the end state before touching anything. Switch to the context the task names, and verify you did. Do the task. Verify the end state, with a command, not a feeling. The ritual is what stops a correct answer landing in the wrong cluster.”
- **③ the docs in thirty seconds.** “The Kubernetes documentation is allowed and it is the only thing that is. Twenty pages you can reach by a search term you already know: PersistentVolume, NetworkPolicy, Ingress, CronJob, kubeadm upgrade, etcd backup. Finding a page is a scored skill in practice.”
- **④ four troubleshooting families.** “The exam's largest domain, and every task in it is one of four: the application is wrong, the control plane is wrong, the worker node is wrong, or the network between them is wrong. Classifying first is what makes the next badge possible.”
- **⑤ the first command per family.** “describe pod for the application. crictl ps and the static-pod logs on the control plane, because kubectl is the thing that is down. systemctl status kubelet and journalctl on a worker. get endpoints and a NetworkPolicy list for the network. One command each, and it halves the problem.”
- **⑥ mock exam 1.** “Eighteen tasks with weights that sum to a hundred, spread like the blueprint, two hours, no notes. Score it honestly against the sheet. It is harder than you want it to be and that is the point.”
- **⑦ killer.sh session 1.** “The simulator that ships with the exam, harder than the exam. Two hours cold, then the rest of the thirty-six-hour window on the solutions, redoing every task you missed until it is fast. The score matters less than the list it produces.”
- **⑧ weak-domain tally.** “Count the misses by domain across the mock and the simulator. The two worst are Tuesday and Thursday of week 30. Everything else is done.”
- **⑨ triage.** “Tasks have weights and the clock does not care. Read the weights first, take the cheap sure ones, give any task two minutes before you flag it and move on, and never leave a cheap task at zero because an expensive one ate the time.”
- **⑩ break/fix, timed.** “Every scenario from BF-41 to BF-64 run from a script on the kubeadm cluster, under ten minutes each, narrated. By Friday the four families are reflex.”
- **Close.** “Terminal, ritual, four families, one command each, a mock, a simulator, a list of what to drill. Week 30 drills the list and sits the exam.”

**Print it:** [`figure-29.1-numbered-spoken.pdf`](figure-29.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 29
```
