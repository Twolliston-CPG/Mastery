# Week 1 Assessment

> Closed book. 45 minutes. Write answers out, then check. **Anything you miss becomes an Anki card
> today.**

## Part A — Recall (15 min)

1. What do `-e`, `-u`, and `-o pipefail` each do, and which causes the most surprising bugs by its absence?
2. `df -h` shows 100% but `du` accounts for only half the space. What's happening and how do you confirm it?
3. What do `r`, `w`, and `x` mean on a **directory**?
4. What is exit code 137 and what causes it?
5. Name all seven process states. Which one can't be killed, and why?
6. Difference between SIGTERM and SIGKILL. Why does it matter for containers?
7. What does `chmod u+s` do and why is it a security concern?
8. What's in a git commit object?
9. `reset` vs `revert` — when is each safe?
10. What permissions must `~/.ssh` and `authorized_keys` have?

## Part B — Write the command (15 min)

11. Top 10 IPs by request count from an access log
12. The 20 largest files under `/var`, human-readable, no permission errors
13. Every file modified in the last 30 minutes under `/etc`
14. Which process is listening on port 8443
15. All processes in `D` state
16. Delete `.tmp` files older than 7 days — show the safe two-step
17. Find deleted-but-open files consuming disk
18. Squash the last 4 commits into one, without an editor
19. Recover a commit destroyed by `git reset --hard`
20. Safely iterate over filenames that may contain spaces

## Part C — Diagnose (15 min)

21. A colleague says "the server is out of disk" but `df -h` shows 40% used and the app still can't
    write files. What do you check?
22. A script works when you run it, fails from cron. Three likely causes, in order.
23. `./deploy.sh` gives "Permission denied". Three possible causes.
24. `systemctl start myapp` fails. Walk through your diagnosis and name three exit codes and what
    they mean.
25. You can read a file's permissions and they're `644`, owned by you — but `cat` says permission
    denied. Why, and what command proves it?

---

# Answer key

**A1.** `-e` exit on non-zero; `-u` error on undefined variable; `-o pipefail` fail the pipeline if
any stage fails. **`pipefail`** — without it `generate | tee out.txt` reports success even when the
generator crashed, silently producing an empty file.

**A2.** A process holds a deleted file open — the inode isn't freed until the fd closes. `lsof +L1`
shows files with link count 0. Fix by restarting the holder, or truncate via
`: > /proc/<pid>/fd/<n>`.

**A3.** `r` list names · `w` create/delete/rename entries · `x` **traverse into it**. You can have
`r` without `x` (see names, can't read files) and `x` without `r` (open a known filename, can't
list). `w` on a directory lets you delete a file you can't write — which is why `/tmp` has the
sticky bit.

**A4.** SIGKILL (128 + 9). In a container it is almost always the OOM killer. Confirm with
`OOMKilled: true`.

**A5.** `R` running/runnable · `S` interruptible sleep · `D` uninterruptible sleep · `Z` zombie ·
`T` stopped · `I` idle kernel thread · plus modifiers `<` `N` `s` `+`. **`D` can't be killed** —
the kernel won't deliver a signal until the blocking I/O completes or fails. A pile of them means an
I/O problem, not a CPU problem. (A zombie also can't be killed, but for the opposite reason: it's
already dead — kill the parent.)

**A6.** SIGTERM (15) is catchable: the app can flush buffers, close connections, deregister. SIGKILL
(9) is not: the kernel kills it instantly with no cleanup. **Kubernetes sends SIGTERM, waits
`terminationGracePeriodSeconds`, then SIGKILL** — an app that ignores SIGTERM drops in-flight
requests on every deploy.

**A7.** setuid: the binary runs with the **file owner's** privileges rather than the caller's. `passwd`
needs it to write `/etc/shadow`. It's a classic privilege-escalation vector — a setuid-root binary
with a bug, or a writable setuid file, is a root shell. Audit with `find / -perm -4000 -type f`.

**A8.** A pointer to a tree object (the directory snapshot), pointer(s) to parent commit(s), author
and committer with timestamps, and the message. Content lives in blobs addressed by hash. A branch
is just a file containing a commit hash — which is why branching is instant.

**A9.** `reset` moves the branch pointer and rewrites history — safe only for unpushed commits.
`revert` creates a new commit that undoes a previous one — the only safe option for anything already
pushed.

**A10.** `~/.ssh` = 700, `authorized_keys` = 600, private keys = 600. sshd refuses to use keys if
either is group- or world-writable.

---

**B11.** `awk '{c[$1]++} END {for (i in c) print c[i], i}' access.log | sort -rn | head -10`

**B12.** `find /var -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -20 | numfmt --to=iec --field=1`

**B13.** `find /etc -type f -mmin -30`

**B14.** `sudo ss -tlnp | grep :8443` (or `sudo lsof -i :8443`)

**B15.** `ps -eo pid,stat,wchan:20,comm | awk '$2 ~ /^D/'`

**B16.**
```bash
find . -name '*.tmp' -mtime +7 -print     # look first
find . -name '*.tmp' -mtime +7 -delete    # then delete
```

**B17.** `lsof +L1`

**B18.** `git reset --soft HEAD~4 && git commit -m "feat: squashed"`

**B19.** `git reflog`, find the hash, `git reset --hard <sha>` (or `git switch -c recovered <sha>`)

**B20.**
```bash
while IFS= read -r -d '' f; do printf '%s\n' "$f"; done < <(find . -type f -print0)
# or
find . -type f -print0 | xargs -0 command
```

---

**C21.** **Inodes.** `df -i`. Millions of small files exhaust the inode table while blocks remain
free. Find the culprit with
`for d in /*; do echo "$(find $d -xdev 2>/dev/null | wc -l) $d"; done | sort -rn`.
(Also check: a deleted-but-open file, or a different filesystem than the one you looked at.)

**C22.** (1) **Empty environment** — cron's `PATH` is roughly `/usr/bin:/bin`, so `aws`, `terraform`,
and venv binaries aren't found. (2) **No output capture**, so failures were silent all along.
(3) **Relative paths** resolving against `$HOME` instead of where you expected. Reproduce with
`env -i /bin/sh -c '/path/to/script.sh'`. Modern answer: use a systemd timer.

**C23.** (1) No execute bit on the file. (2) **No execute/traverse bit on a parent directory** —
`namei -l` shows this. (3) Filesystem mounted `noexec` — check `mount | grep noexec`.
(Bonus fourth: a missing or CRLF-terminated shebang gives a confusingly similar error.)

**C24.** `systemctl status myapp -l`, then `journalctl -u myapp -n 50`, then
`systemd-analyze verify` the unit, then `systemctl cat myapp` to see the effective unit including
drop-ins. Codes: **203/EXEC** binary not found or not executable · **200/CHDIR** `WorkingDirectory`
doesn't exist · **217/USER** the `User=` doesn't exist · **1** the application itself errored, so read
*its* logs. **And: `daemon-reload` after any unit edit** — systemd caches units, and forgetting this
is the #1 mistake.

**C25.** A parent directory lacks the execute (traverse) bit. The file's own permissions are
irrelevant if you can't walk the path to it. **`namei -l /full/path/to/file`** prints the permissions
of every component and shows you exactly which one is wrong.

---

## Scoring

| Score | Meaning |
|---|---|
| 22–25 | Solid. Move to week 2. |
| 18–21 | Fine. Make Anki cards from the misses and move on. |
| 13–17 | Re-do the labs for the sections you missed before week 2. |
| < 13 | **Spend two extra days here.** Week 5's AWS material assumes all of this. |

Everything you missed becomes an Anki card **today**, in your own words.
