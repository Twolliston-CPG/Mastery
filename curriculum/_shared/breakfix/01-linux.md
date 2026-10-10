# Break/Fix: Linux (BF-01 – BF-10)

Run each break on a throwaway VM. Never on your real machine.

---

## BF-01 — Disk full

**SYMPTOM:** Application won't start. Logs say "No space left on device." `df -h` shows `/` at 100%.

**BREAK:**
```bash
sudo fallocate -l $(($(df --output=avail -B1 / | tail -1) - 50000000)) /var/log/huge.bin
```

**DIAGNOSIS:**
```bash
df -h                                   # confirm which filesystem
du -xh / 2>/dev/null | sort -rh | head -20   # -x stays on one filesystem
sudo du -xh /var | sort -rh | head -10       # walk down the tree
lsof +L1                                # CRITICAL: deleted-but-open files
```

**ROOT CAUSE:** A single 8 GB file in `/var/log`.

**FIX:** `sudo rm /var/log/huge.bin`

**THE TRAP THAT CATCHES EVERYONE:** If `du` totals don't match `df`, a process is holding a deleted
file open. The space is not freed until the process closes it. `lsof +L1` finds them; restarting the
holding process (usually a logger) releases the space. **This is a classic interview question** —
"df says full, du says empty, what's happening?"

**PREVENT:** logrotate config, a disk-usage alarm at 80%, separate `/var` partition.

---

## BF-02 — Runaway CPU

**SYMPTOM:** System sluggish, load average climbing, SSH slow to respond.

**BREAK:** `yes > /dev/null & yes > /dev/null & yes > /dev/null &`

**DIAGNOSIS:**
```bash
uptime                      # load avg vs core count -- load 8 on 2 cores = trouble
top -o %CPU                 # or: htop
ps -eo pid,ppid,%cpu,%mem,etime,cmd --sort=-%cpu | head
pidstat 1 5                 # per-process over time
```

**ROOT CAUSE:** Three `yes` processes pinning all cores.

**FIX:** `pkill yes` — or `renice -n 19 -p <pid>` if you need it to finish but not starve others.

**KEY INSIGHT:** Load average counts processes *waiting for CPU or uninterruptible I/O*. High load
with low CPU% means I/O wait, not CPU — check `iostat -x 1` and the `wa` column in `top`. Knowing
that distinction is a senior-sounding answer.

**PREVENT:** systemd `CPUQuota=`, cgroup limits, CPU alarm.

---

## BF-03 — Permission denied on an executable

**SYMPTOM:** `./deploy.sh` → `bash: ./deploy.sh: Permission denied`

**BREAK:** `chmod 644 deploy.sh`

**DIAGNOSIS:**
```bash
ls -l deploy.sh             # -rw-r--r--  : no execute bit
namei -l $(pwd)/deploy.sh   # walks EVERY directory in the path
mount | grep noexec         # filesystem mounted noexec?
```

**ROOT CAUSE:** Missing execute bit.

**FIX:** `chmod +x deploy.sh`

**THE THREE CAUSES, IN ORDER OF FREQUENCY:**
1. No execute bit on the file
2. No execute (traverse) bit on a *parent directory* — `namei -l` is how you see this
3. Filesystem mounted `noexec` (common on `/tmp` in hardened builds)

A candidate who names all three has clearly hit this in real life.

---

## BF-04 — Broken PATH

**SYMPTOM:** `ls`, `cat`, everything → `command not found`. Terminal appears bricked.

**BREAK:** `export PATH=/nonexistent`

**DIAGNOSIS:** You can still use shell builtins and absolute paths.
```bash
echo $PATH                  # echo is a builtin, still works
/bin/ls                     # absolute paths still work
```

**FIX:** `export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`

**KEY INSIGHT:** Knowing that builtins survive and absolute paths always work is the difference
between "I'd reboot" and "I'd fix it in ten seconds." If it's in `~/.bashrc`, the fix is
`/usr/bin/vi ~/.bashrc`.

**PREVENT:** Always *append* — `export PATH="$PATH:/new/dir"` — never overwrite.

---

## BF-05 — systemd service fails to start

**SYMPTOM:** `systemctl start myapp` → "Job failed. See 'journalctl -xe'."

**BREAK:** Write a unit with a typo'd `ExecStart` path.

**DIAGNOSIS:**
```bash
systemctl status myapp -l --no-pager
journalctl -u myapp -n 50 --no-pager
journalctl -u myapp -f                 # follow while you retry
systemd-analyze verify /etc/systemd/system/myapp.service
systemctl cat myapp                    # shows the EFFECTIVE unit incl. drop-ins
```

**ROOT CAUSE:** `ExecStart` points at a nonexistent binary (status code 203/EXEC).

**FIX:** Correct the path → `sudo systemctl daemon-reload` → `sudo systemctl start myapp`

**EXIT CODES WORTH MEMORIZING:**
| Code | Meaning |
|---|---|
| 203/EXEC | Binary not found or not executable |
| 200/CHDIR | `WorkingDirectory` doesn't exist |
| 217/USER | `User=` doesn't exist |
| 1 | The app itself errored — read *its* logs, not systemd's |

**FORGETTING `daemon-reload` AFTER EDITING A UNIT IS THE #1 MISTAKE.** systemd caches units.

---

## BF-06 — SSH locked out (permissions)

**SYMPTOM:** Key-based SSH suddenly prompts for a password, or rejects outright.

**BREAK:** `chmod 777 ~/.ssh && chmod 644 ~/.ssh/authorized_keys`

**DIAGNOSIS:** From the client: `ssh -vvv user@host` — look for `Authentications that can continue`.
On the server: `sudo journalctl -u ssh -n 30` → "Authentication refused: bad ownership or modes".

**ROOT CAUSE:** sshd refuses to use keys when `~/.ssh` or `authorized_keys` are group/world-writable.

**FIX:**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R "$USER:$USER" ~/.ssh
```

**RULE:** `.ssh` = 700, `authorized_keys` = 600, private keys = 600, `.pub` = 644.

**ALWAYS KEEP A SECOND SESSION OPEN** when editing sshd config. Verify the new session works before
closing the old one. This habit will save you at least once in your career.

---

## BF-07 — Cron job that never runs

**SYMPTOM:** Entry is in `crontab -l`, but the job never produces output.

**BREAK:** A crontab entry calling a script that relies on `$PATH` or `~` expansion.

**DIAGNOSIS:**
```bash
grep CRON /var/log/syslog | tail -20    # did cron even fire?
journalctl -u cron -n 30                # systemd systems
# Then reproduce cron's environment:
env -i /bin/sh -c '/path/to/script.sh'
```

**ROOT CAUSE:** cron runs with a nearly empty environment. `PATH` is typically just
`/usr/bin:/bin`. `aws`, `terraform`, `python3` from a venv — none are found.

**FIX:** Absolute paths inside the script, and set what you need at the top of the crontab:
```cron
PATH=/usr/local/bin:/usr/bin:/bin
0 2 * * * /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1
```

**THE FOUR CRON GOTCHAS:** (1) empty environment, (2) `%` must be escaped as `\%`, (3) no output
capture means failures are silent, (4) relative paths resolve against `$HOME`.

**MODERN ANSWER:** For anything that matters, use a **systemd timer** — real logging via journald,
dependency ordering, and `systemctl list-timers` to see state. Saying this in an interview shows
currency.

---

## BF-08 — Out of inodes

**SYMPTOM:** "No space left on device" — but `df -h` shows plenty of free space.

**BREAK:** `mkdir /tmp/inodes && cd /tmp/inodes && for i in $(seq 1 200000); do touch "f$i"; done`

**DIAGNOSIS:**
```bash
df -h          # space looks fine
df -i          # INODES at 100%  <-- the answer
for d in /*; do echo "$(find $d -xdev 2>/dev/null | wc -l) $d"; done | sort -rn | head
```

**ROOT CAUSE:** Millions of tiny files exhausted the inode table. Classic causes: unrotated session
files, a runaway `/tmp`, mail spool, or a logging bug writing one file per event.

**FIX:** Delete the files. `find /tmp/inodes -type f -delete` (faster than `rm *`, which can blow
the argument limit).

**WHY THIS IS A GREAT SCENARIO:** "Disk full but `df` shows space free" separates people who have
actually run systems from people who have read about them.

---

## BF-09 — Zombie and orphan processes

**SYMPTOM:** `ps` shows processes in state `Z`. Process count climbing.

**DIAGNOSIS:**
```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^Z/'
ps -ef --forest | head -40          # find the parent that isn't reaping
```

**ROOT CAUSE:** Parent process isn't calling `wait()` to reap its children.

**FIX:** You cannot kill a zombie — it's already dead. Kill or restart the **parent**; `init`/systemd
then reaps the orphans.

**WHY IT MATTERS FOR CONTAINERS:** A process running as PID 1 in a container must reap children. If
your app isn't designed for that, zombies accumulate. Fix: `docker run --init`, or use `tini`.
**This connects directly to week 4** and is a strong interview answer.

---

## BF-10 — Log file written but disk not freed

**SYMPTOM:** You deleted a 10 GB log. `df` still shows it full.

**BREAK:**
```bash
python3 -c "
import time
f=open('/tmp/big.log','w')
f.write('x'*500_000_000); f.flush()
import os; os.remove('/tmp/big.log')
time.sleep(600)" &
```

**DIAGNOSIS:** `lsof +L1` → shows the file with link count 0, still held open.

**FIX:** Restart the holding process. Or, without a restart, truncate through the fd:
```bash
: > /proc/<pid>/fd/<fd_number>
```

**PREVENT:** logrotate with `copytruncate`, or have the app reopen its log on `SIGHUP`.

**INTERVIEW GOLD:** This is BF-01's trap as its own scenario because it comes up constantly in real
incidents and almost nobody gets it on the first try.
