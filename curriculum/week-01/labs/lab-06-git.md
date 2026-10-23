# Lab 6 — Git Fundamentals and Your First Repo

**Time:** 3 hours

## Objectives
- The core workflow without thinking
- Understand what a commit actually *is*
- Publish the week's deliverable

---

## Part 1 — Configure git properly (20 min)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase true          # linear history on pull
git config --global core.editor "vim"
git config --global rerere.enabled true       # remembers conflict resolutions
git config --global push.autoSetupRemote true

# useful aliases
git config --global alias.st  "status -sb"
git config --global alias.lg  "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "reset HEAD --"

# SSH key for GitHub
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub     # add to github.com/settings/keys
ssh -T git@github.com
```

---

## Part 2 — What a commit actually is (40 min)

```bash
mkdir -p ~/lab6 && cd ~/lab6 && git init
echo "hello" > a.txt
git add a.txt
git commit -m "feat: add a.txt"

# Look inside
git cat-file -p HEAD                      # the commit object
git cat-file -p HEAD^{tree}               # the tree it points to
git cat-file -p $(git rev-parse HEAD:a.txt)   # the blob contents
find .git/objects -type f
```

**A commit is:** a pointer to a tree (directory snapshot), a pointer to its parent commit(s), plus
author/committer/message. Content is stored as blobs addressed by their SHA-1 hash. A branch is
just a **file containing a commit hash** — `cat .git/refs/heads/main`.

That's why branching is instant, and why rebasing "rewrites history" (new commits = new hashes).

```bash
cat .git/HEAD              # ref: refs/heads/main
cat .git/refs/heads/main   # a commit hash
```

---

## Part 3 — The workflow (60 min)

```bash
# Branching
git switch -c feat/new-thing      # modern; older: git checkout -b
echo "change" >> a.txt
git add -p                         # INTERACTIVE staging -- stage hunks, not files.
                                   # Learn this; it makes your commits reviewable.
git commit -m "feat: extend a.txt"

# Inspect
git status -sb
git diff                  # working tree vs index
git diff --staged         # index vs HEAD
git log --oneline --graph --decorate --all
git show HEAD

# Undo -- know the difference
git restore a.txt                    # discard working-tree changes
git restore --staged a.txt           # unstage, keep changes
git commit --amend                   # rewrite the last commit (only if unpushed)
git reset --soft  HEAD~1             # undo commit, KEEP changes staged
git reset --mixed HEAD~1             # undo commit, keep changes unstaged (default)
git reset --hard  HEAD~1             # undo commit, DISCARD changes  <-- destructive
git revert HEAD                      # new commit that undoes -- SAFE for pushed commits
```

**The rule:** `reset` rewrites history — only for local, unpushed commits. `revert` adds a new
commit — the only safe option for anything already pushed.

### Create and resolve a real conflict
```bash
git switch main
echo "main version" > conflict.txt && git add . && git commit -m "feat: main version"
git switch -c feat/other main~0
echo "other version" > conflict.txt && git add . && git commit -m "feat: other version"
git switch main
git merge feat/other        # CONFLICT

cat conflict.txt            # see the markers
git status
# edit to resolve, then:
git add conflict.txt
git commit
```

### Interactive rebase — clean up before a PR
```bash
git switch -c feat/messy
for i in 1 2 3 4; do echo "line $i" >> f.txt; git add .; git commit -m "wip $i"; done
git rebase -i HEAD~4
# change 'pick' to 'squash' (or 's') on lines 2-4, save, write a real message
git log --oneline
```

### `git bisect` — find the commit that broke it
```bash
git bisect start
git bisect bad HEAD
git bisect good HEAD~10
# git checks out the midpoint; test it, then:
git bisect good    # or: git bisect bad
# repeat until it names the culprit
git bisect reset
```
**This is a genuinely useful skill and an interview question.** It's a binary search — 10 commits
takes 3-4 tests, 1000 commits takes 10.

---

## Part 4 — Publish the deliverable (60 min)

```bash
cd ~/mastery-progress/sysreport    # or wherever lab 4 lives
git init && git branch -M main

cat > .gitignore <<'EOF2'
*.log
*.tmp
.DS_Store
.env
*.bak
EOF2

# Pre-commit hooks -- start this habit now
cat > .pre-commit-config.yaml <<'EOF2'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: detect-private-key
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
EOF2

pre-commit install
pre-commit run --all-files

git add .
git commit -m "feat: system health report script

Collects host, CPU, memory, disk, inode, process, network, and systemd
state. Supports table and JSON output, configurable thresholds, and
returns a non-zero exit code when any check exceeds threshold so it can
be used from monitoring."

gh repo create sysreport --public --source=. --push
```

**`detect-private-key` and `gitleaks` in pre-commit from week 1** means you will never be the person
who commits an AWS key. That habit is worth more than it costs.

---

## Challenge

1. You committed a password and pushed. What is the **first** thing you do, and why?
2. Squash the last 5 commits into 1 without an interactive editor
3. Recover a commit you deleted with `git reset --hard`
4. Find which commit introduced the string `TODO` in a file

---

## Exit check
- [ ] Explain what a commit object contains and why a branch is cheap
- [ ] Explain `reset` vs `revert` and when each is safe
- [ ] Resolved a merge conflict by hand
- [ ] Squashed commits with interactive rebase
- [ ] Used `git bisect` successfully
- [ ] `sysreport` is public on GitHub with pre-commit hooks passing
