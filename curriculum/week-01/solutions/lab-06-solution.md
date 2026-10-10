# Lab 6 — Solutions

## Challenge 1 — You committed a password and pushed. First step?

**Rotate the credential. Immediately.**

Everything else is secondary, and this ordering is the whole point of the question. The moment it
was pushed it is on GitHub's servers, in every clone, in forks, in CI caches, and — for a public
repo — very likely already harvested by a scanner. **Credential-scraping bots find public AWS keys in
seconds, not hours.** Rewriting history does not un-leak it.

Only after rotation:

```bash
# 1. Remove it from history
pip install git-filter-repo
git filter-repo --invert-paths --path secrets.env        # remove a whole file
# or replace a string everywhere:
echo 'literal:AKIAIOSFODNN7EXAMPLE==>REDACTED' > /tmp/replace.txt
git filter-repo --replace-text /tmp/replace.txt

# 2. Force push (coordinate with everyone first)
git push --force-with-lease --all
git push --force-with-lease --tags

# 3. Every collaborator must RE-CLONE. Their old clone still has it.
# 4. Ask GitHub Support to purge cached views of the old commits.
# 5. Prevent recurrence:
pre-commit install          # with gitleaks + detect-private-key
```

**Why `--force-with-lease` and not `--force`:** it refuses the push if someone else has pushed since
your last fetch, so you can't silently destroy their work.

**In an interview, lead with rotation.** Plenty of candidates describe elaborate git surgery and
never mention that the secret is already burned — that answer fails.

## Challenge 2 — Squash 5 commits without an editor

```bash
git reset --soft HEAD~5
git commit -m "feat: the squashed change"
```
`--soft` moves the branch pointer back but leaves everything staged. One new commit replaces five.
Faster and more predictable than interactive rebase when you want *all* of them squashed.

## Challenge 3 — Recover from `git reset --hard`

```bash
git reflog
# 8a3f2c1 HEAD@{0}: reset: moving to HEAD~1
# 4d9e1b7 HEAD@{1}: commit: the work you thought you lost
git reset --hard 4d9e1b7
# or, to keep the current branch intact:
git switch -c recovered 4d9e1b7
```

**`git reflog` is the single most valuable recovery command in git.** It records every position HEAD
has held for ~90 days, including commits that are no longer reachable from any branch. Almost
nothing is truly lost until `git gc` runs.

## Challenge 4 — Which commit introduced a string?

```bash
git log -S 'TODO' --oneline -- path/to/file      # "pickaxe": commits changing the COUNT of matches
git log -G 'TODO.*urgent' --oneline              # regex on the diff itself
git log -p -S 'TODO' -- path/to/file             # with the diffs
git blame path/to/file                            # line-by-line, last change only
git blame -L 40,60 path/to/file
```

`-S` and `-G` differ: `-S` finds commits where the *number of occurrences* changed (added or
removed), `-G` finds commits whose diff text matches the regex. `-S` is usually what you want.

## The undo cheat sheet

| Situation | Command | Destructive? |
|---|---|---|
| Discard working-tree changes | `git restore <file>` | **yes** |
| Unstage, keep changes | `git restore --staged <file>` | no |
| Fix the last commit message | `git commit --amend` | rewrites history |
| Undo last commit, keep staged | `git reset --soft HEAD~1` | rewrites history |
| Undo last commit, keep unstaged | `git reset HEAD~1` | rewrites history |
| Undo last commit, discard work | `git reset --hard HEAD~1` | **yes**, rewrites |
| Undo a **pushed** commit | `git revert <sha>` | no — safe |
| Recover anything | `git reflog` | no |

**The rule:** `reset`/`amend`/`rebase` rewrite history and are only for unpushed commits. `revert` is
the only safe undo for anything others may have pulled.

## Conventional commits

```
<type>(<scope>): <subject>

<body>

<footer>
```
Types: `feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci` `chore`

```
feat(monitoring): add inode usage to system report

Disk-full incidents caused by inode exhaustion show free space in
`df -h`, so the existing check missed them entirely. Adds a per-
filesystem inode check using `df -Pi` with the same threshold.

Refs: #14
```

Why bother: it makes `git log --oneline` readable, it drives automated changelog and semantic
version bumping in week 12, and it is an immediate, free signal of professionalism in a portfolio
repo.
