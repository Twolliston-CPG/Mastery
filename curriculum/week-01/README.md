# Week 1 — Linux I, Git, and the Environment

> **Thesis:** Every DevOps concept you will meet for the rest of your career is a Linux concept, a
> networking concept, or a Git concept wearing a cloud costume. A container is namespaces and
> cgroups. A Kubernetes Service is iptables. A VPC is routing and subnetting.
> **Skipping this week is why people plateau at "I can follow a tutorial."**

| | |
|---|---|
| **Hours** | 30–45 |
| **Deliverable** | `sysreport.sh` in a public GitHub repo with a real README |
| **Break/Fix** | BF-01 – BF-04 |
| **Exit check** | Navigate, inspect, and modify a Linux system without googling basic commands |

---

## Day plan

| Day | Focus | Lab |
|---|---|---|
| Mon | Environment + filesystem + navigation | Lab 1 |
| Tue | Permissions, users, processes | Lab 2 |
| Wed | Text processing: grep, sed, awk, jq | Lab 3 |
| Thu | Bash scripting proper | Lab 4 |
| Fri | **Break/Fix** BF-01–04, then ship the deliverable | Lab 5 |
| Sat | Git fundamentals + push everything | Lab 6 |
| Sun | Review, write notes, plan week 2 | — |

---

## Reading map

**Primary (read once, then build):**
- `_reference/linux-networking/01-linux-fundamentals.md`
- `_reference/linux-networking/02-filesystem-deep-dive.md`
- `_reference/linux-networking/03-users-permissions.md`
- `_reference/linux-networking/04-process-management.md`
- `_reference/linux-networking/05-shell-scripting-basics.md`
- `_reference/linux-networking/06-advanced-shell-scripting.md`

**Alternate explanation if something doesn't click:**
- `_reference/linux-networking/alt/01-linux-introduction.md` … `alt/07-shell-scripting.md`

**Free primary sources worth using instead of a course:**
- The `man` pages. Seriously — `man 7 signal`, `man 5 crontab`, `man 1 find`.
- Linux Journey (linuxjourney.com) — free, short, well-sequenced
- `explainshell.com` — paste any command, get every flag explained
- ShellCheck (shellcheck.net) — run every script through it

> **The 70/30 rule starts today.** Read a section once, then build the lab from a blank file with
> only `man` and the docs. If you can't start from blank, you haven't learned it.

---

## Labs

| # | Lab | Time |
|---|---|---|
| 1 | [Environment setup and filesystem tour](labs/lab-01-environment.md) | 3h |
| 2 | [Permissions, users, and processes](labs/lab-02-permissions-processes.md) | 3h |
| 3 | [Text processing — the log analysis lab](labs/lab-03-text-processing.md) | 3h |
| 4 | [Bash scripting: build `sysreport.sh`](labs/lab-04-bash-sysreport.md) | 4h |
| 5 | [Break/Fix Friday](labs/lab-05-breakfix.md) | 2h |
| 6 | [Git fundamentals and your first repo](labs/lab-06-git.md) | 3h |

Solutions in [`solutions/`](solutions/). **Open them only after a genuine attempt** — reading a
solution feels like learning and isn't.

---

## Daily drills (Block 4, 45 min)

- `_shared/drills/bash-oneliners.md` — Text processing + Files sections
- Anki: import `_shared/anki/linux-networking.tsv`, review daily from today
- **Write 5 of your own cards** from anything that surprised you

---

## Exit criteria

Tick every box before moving to week 2.

- [ ] Navigate a Linux filesystem and find any file without looking up `find` syntax
- [ ] Explain the difference between `644` and `755`, and what those bits mean **on a directory**
- [ ] Read `ps`/`top` output and identify the top CPU and memory consumers
- [ ] Write a Bash script from blank with `set -euo pipefail`, argument parsing, and error handling
- [ ] Extract a top-10 report from a 100k-line log using only `grep`/`awk`/`sort`/`uniq`
- [ ] `git init`, branch, commit, push, and open a PR without a reference
- [ ] `sysreport.sh` is public on GitHub with a README someone else could follow
- [ ] 4 break/fix entries in `progress/incident-journal.md`

---

## Setup checklist (do this first, Monday morning)

```bash
bash ../_setup/macos-setup.sh      # install everything (linux-setup.sh on Linux/WSL)
bash ../_setup/verify.sh           # confirm

mkdir -p ~/mastery/progress
cd ~/mastery
git init
cp ../_shared/templates/PROJECT-README-template.md README.md
```

Create `progress/progress.md` and `progress/incident-journal.md` now. You will fill them every week
for 26 weeks, and they become your interview story bank.
