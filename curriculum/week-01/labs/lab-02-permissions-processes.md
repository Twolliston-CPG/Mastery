# Lab 2 — Permissions, Users, and Processes

**Time:** 3 hours

## Objectives
- Read and set permissions without thinking
- Understand what permission bits mean **on a directory** (the part people miss)
- Read `ps`/`top` output and reason about process state

---

## Part 1 — Permissions (60 min)

```bash
mkdir -p ~/lab2 && cd ~/lab2
touch file.txt && mkdir dir

ls -l                      # decode every character of "-rw-r--r--"
stat file.txt              # the full picture
```

### Decode the mode string
**Reading a permission string**

```text
-  rw-  r--  r--
│   │    │    └── other:  r--  = 4
│   │    └─────── group:  r--  = 4
│   └──────────── owner:  rw-  = 6
└──────────────── type:   -=file  d=dir  l=symlink  c=char  b=block  s=socket  p=pipe
                                                                        → 644
```

| Position | Field | This example | Octal |
|---|---|---|---|
| 1 | Type | `-` (regular file) | — |
| 2–4 | Owner | `rw-` | 6 |
| 5–7 | Group | `r--` | 4 |
| 8–10 | Other | `r--` | 4 |

Type characters: `-` file · `d` directory · `l` symlink · `c` character device · `b` block device ·
`s` socket · `p` named pipe.

Each triplet is read as bits: `r`=4, `w`=2, `x`=1, added together. So `rw-` is 4+2=**6** and `r--`
is **4**, giving `644`.

### Tasks
```bash
# 1. Set each of these and verify with ls -l and stat
chmod 600 file.txt     # owner rw only
chmod 644 file.txt     # owner rw, everyone read
chmod 755 dir          # standard directory
chmod 700 dir          # private directory
chmod u+x,g-r,o= file.txt   # symbolic form

# 2. umask -- why new files are 644 and not 666
umask                  # usually 022
touch new1 && ls -l new1        # 644 = 666 & ~022
umask 077 && touch new2 && ls -l new2   # 600
umask 022

# 3. Ownership
sudo chown root file.txt && ls -l file.txt
sudo chown $USER:$USER file.txt
sudo chgrp adm file.txt
```

### The directory experiment — do this, it is the point of the lab
```bash
mkdir -p ~/lab2/parent/child
echo "secret" > ~/lab2/parent/child/data.txt
chmod 644 ~/lab2/parent/child/data.txt     # you have read on the FILE

chmod 644 ~/lab2/parent                     # remove EXECUTE on the parent dir
cat ~/lab2/parent/child/data.txt            # what happens?
ls ~/lab2/parent                            # and this?

namei -l ~/lab2/parent/child/data.txt       # THIS is how you diagnose it
chmod 755 ~/lab2/parent                     # restore
```

**Write down what you observed.** On a directory: `r` = list names, `w` = create/delete entries,
`x` = **traverse into it**. You can have `r` without `x` (see names, can't read files) and `x`
without `r` (read a file if you know its exact name, can't list).

### Special bits
```bash
ls -l /usr/bin/passwd      # -rwsr-xr-x  <- the 's' is setuid
# passwd must edit /etc/shadow, which is root-only. setuid runs it as the file's owner.
# This is also a classic privilege escalation vector -- see Lab 1's perm-0777 question.

ls -ld /tmp                # drwxrwxrwt  <- the 't' is the sticky bit
# /tmp is world-writable, but sticky means you can only delete YOUR OWN files.

chmod u+s somefile; chmod g+s somedir; chmod +t somedir
```

---

## Part 2 — Users and groups (45 min)

```bash
# Who am I, really
id; whoami; groups
cat /etc/passwd | head -3      # username:x:UID:GID:comment:home:shell
cat /etc/group | head -3
sudo cat /etc/shadow | head -2 # password hashes -- note the permissions on this file

# Create a service account (the way you would for an application)
sudo useradd -r -s /usr/sbin/nologin -d /opt/appsvc -m appsvc
id appsvc
```

**Why `-r` and `-s /usr/sbin/nologin`?** A service account should not be loginable. `-r` marks it as
a system account (UID below 1000, no aging). This is exactly the "run as non-root" principle you'll
apply to containers in week 4 and to Kubernetes pods in week 15.

```bash
# Groups
sudo groupadd deployers
sudo usermod -aG deployers $USER
# NOTE: group changes require a NEW LOGIN to take effect
newgrp deployers          # or log out and back in
groups

# sudoers -- ALWAYS use visudo, it validates before saving
sudo visudo -f /etc/sudoers.d/deployers
# %deployers ALL=(ALL) NOPASSWD: /bin/systemctl restart myapp
```

**A syntax error in `/etc/sudoers` edited without `visudo` can lock you out of sudo entirely.** That
is a genuinely bad day. `visudo` validates first.

---

## Part 3 — Processes (60 min)

```bash
# Snapshot views
ps aux | head
ps -ef | head
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu | head

# Process tree -- see the parent/child relationships
ps -ef --forest | head -40
pstree -p | head -20

# Live views
top        # then press: M (sort memory), P (cpu), 1 (per-core), c (full cmd), k (kill)
htop
```

### Process states — memorize these
| STAT | Meaning |
|---|---|
| `R` | Running or runnable |
| `S` | Interruptible sleep (waiting for an event) — **most processes, most of the time** |
| `D` | **Uninterruptible sleep** — blocked on I/O. Can't be killed. Counts toward load average. |
| `Z` | Zombie — finished, parent hasn't reaped it (BF-09) |
| `T` | Stopped |
| `<` `N` | High / low priority |
| `s` | Session leader |
| `+` | Foreground process group |

**`D` state is the interesting one.** A process stuck in `D` won't respond to `kill -9`, and a pile
of them means an I/O problem (a hung NFS mount, a failing disk) — not a CPU problem.

### Signals
```bash
sleep 300 &
jobs
kill %1                 # SIGTERM (15) -- polite, app can clean up
sleep 300 & kill -9 %1  # SIGKILL (9) -- kernel kills it, NO cleanup
sleep 300 & kill -STOP %1; jobs; kill -CONT %1
kill -l                 # full signal list
```

**Always try SIGTERM first.** SIGKILL gives the process no chance to flush buffers, close files, or
deregister. This is exactly what Kubernetes does: `SIGTERM`, wait `terminationGracePeriodSeconds`,
then `SIGKILL`.

### Job control
```bash
sleep 300                # Ctrl+Z to suspend
jobs
bg %1                    # resume in background
fg %1                    # bring to foreground
nohup long_task.sh &     # survives logout
disown -h %1
```

---

## Challenge

Write one command each that:
1. Shows the top 5 processes by memory, with RSS in MB
2. Finds every process owned by a user whose shell is `nologin` (a service account running something)
3. Shows how long the oldest running process has been up
4. Kills every process matching a pattern — safely (dry run first)
5. Finds any process in `D` state

---

## Exit check
- [ ] Convert between symbolic and octal in your head
- [ ] Explain what `r`, `w`, `x` mean **on a directory** and demonstrate the traverse case
- [ ] Explain setuid and why `find / -perm -4000` matters for security
- [ ] Name all seven process states and what `D` implies
- [ ] Explain the difference between SIGTERM and SIGKILL and why it matters for containers
