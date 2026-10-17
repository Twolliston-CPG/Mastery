# Figure 17.1 — The diagnostic ladder you narrate at Gate 4

> Week 17 · badges ① to ⑪ · about three minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 17.1 — The diagnostic ladder you narrate at Gate 4](figure-17.1-the-diagnostic-ladder-you-narrate-at.png)

Consolidation is not rest. The figure is the method you say out loud for five broken clusters, under fifteen minutes each, plus the two decisions the week asks for: KCNA and the Bravo design.

## What to say, badge by badge

- **Open.** “Scattered knowledge becomes retrievable under pressure this week, which is the only form that matters in an interview. The figure is the seven words you say, in order, every time something is broken. Then the gate, then two decisions.”
- **① symptom.** “Say exactly what is broken, who it affects, and since when. Not 'the site is down' but 'checkout returns 503 for every user since 09:40'. Precision here halves the search.”
- **② change.** “What changed? A deploy, a config edit, a node replaced, a certificate expiring. Most real incidents are answered by this question alone, and juniors skip it to go straight to the exciting layer.”
- **③ hypothesis.** “Name a cause and the cheapest test that would disprove it. A ten-second `kubectl get endpoints` beats a ten-minute log dive. Cheap tests first, always.”
- **④ layers.** “App, container, pod, node, network, cloud, DNS. Walk them in order. The discipline is not skipping to the one you find interesting; the order is what makes you fast when you are nervous.”
- **⑤ confirm.** “Prove it. A restart that fixed the symptom is a correlation. A log line that names the cause is a confirmation. Interviewers notice the difference.”
- **⑥ fix.** “The smallest change that resolves it. A rollback is a fix. A rebuild is a last resort you announce as one.”
- **⑦ prevent.** “What makes this impossible, or at least loud, next time? A probe, a limit, a policy, an alert. The incident journal entry ends with this line.”
- **⑧ scenario-to-command map.** “Each scenario type has a first command. Describe for scheduling and events, logs --previous for crashes, get endpoints for a dead Service, auth can-i for RBAC, top for resources. Internalize the map so your hands move while you talk.”
- **⑨ Gate 4.** “Wednesday, for real: five scenarios, each under fifteen minutes, narrated. Then Deployment, Service, Ingress, and a Role with its binding, written from memory. Rehearse Tuesday with a timer.”
- **⑩ KCNA decision.** “If the gate was comfortable, skip KCNA and bank the money and the hours toward the CKA, which is the one hiring managers filter on. If the gate was a struggle, take KCNA as a forcing function, knowing that is what you are buying.”
- **⑪ Bravo design first.** “Friday: draw the Bravo architecture and write the STRIDE threat model before a line of code exists. Weeks 18 to 21 build controls against named threats, not against a vague sense of security.”
- **Close.** “Seven words, in order, out loud. That is the skill the gate measures and the skill the interview measures. Everything else this week is deciding what to spend the next month on.”

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 17
```
