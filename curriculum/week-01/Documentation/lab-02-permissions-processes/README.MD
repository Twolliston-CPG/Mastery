# Lab 2 — Permissions, Users, and Processes (Step-by-Step Guide)

> Source: `curriculum/week-01/labs/lab-02-permissions-processes.md`
> Time: ~3 hours · Environment: **macOS host** + **Arch Linux VM on GCP** (`lab`, project `twollist-twots-lab`, zone `us-east1-b`)

Every step is tagged with where you run it:

| Tag | Meaning |
|---|---|
| 🍎 **[macOS]** | Run on your Mac, in Terminal (`gcloud` is installed here, not on the VM) |
| 🐧 **[Arch VM]** | Run inside the Arch Linux VM, logged in as your normal user (`arch`), **not root** |
| ✍️ **Your answer** | A space for you to write. Type directly under the prompt |

> ⚠️ **Do the whole lab as your normal user, not root.** Root ignores file permissions, so the
> directory experiment in Part 1 will "work" as root and you'll miss the entire point.

---

## Part 0 — Get into the VM (10 min)

### Step 0.1 — Start the VM · 🍎 [macOS]
Your VM is currently stopped. Start it:
```bash
gcloud compute instances start lab --zone=us-east1-b
```

### Step 0.2 — SSH in through IAP · 🍎 [macOS]
The VM has no public SSH port, so you connect through Identity-Aware Proxy:
```bash
gcloud compute ssh arch@lab --zone us-east1-b --project twollist-twots-lab --tunnel-through-iap
```
The prompt changes to `[arch@lab ~]$`. From here on, every 🐧 step is typed into this SSH session.
> If it fails with `4003: failed to connect to backend`, the VM is still booting. Wait a minute and
> run it again.

### Step 0.3 — Check sudo and install the tools this lab needs · 🐧 [Arch VM]
```bash
sudo -v                                     # should ask for your password, then return silently
sudo pacman -Syu --needed psmisc htop nano  # pstree, htop, and an editor for visudo
```
> If `sudo -v` says you're not in sudoers, run `su -` (root password), then
> `pacman -S sudo`, `usermod -aG wheel arch`, `EDITOR=nano visudo` and uncomment
> `%wheel ALL=(ALL:ALL) ALL`. Type `exit`, log out, and log back in.

---

## Part 1 — Permissions (60 min) · all 🐧 [Arch VM]

### Step 1.1 — Create the workspace
```bash
mkdir -p ~/lab2 && cd ~/lab2
touch file.txt && mkdir dir
ls -l          # decode every character of "-rw-r--r--"
stat file.txt  # the full picture
```

**How to read a mode string:**

| Position | Field | Example | Octal |
|---|---|---|---|
| 1 | Type | `-` file, `d` dir, `l` symlink, `c` char dev, `b` block dev, `s` socket, `p` pipe | — |
| 2–4 | Owner | `rw-` | 4+2 = **6** |
| 5–7 | Group | `r--` | **4** |
| 8–10 | Other | `r--` | **4** |

`r`=4, `w`=2, `x`=1, add them per triplet → `rw-r--r--` = `644`.

✍️ **Your answer — decode the `ls -l` line for `file.txt` and `dir`:**

| Item | Mode string you saw | Type | Owner | Group | Other | Octal |
|---|---|---|---|---|---|---|
| `file.txt` | | | | | | |
| `dir` | | | | | | |

### Step 1.2 — Practice `chmod` (run each line, then check with `ls -l` and `stat`)
```bash
chmod 600 file.txt;  ls -l file.txt     # owner rw only
chmod 644 file.txt;  ls -l file.txt     # owner rw, everyone read
chmod 755 dir;       ls -ld dir         # standard directory
chmod 700 dir;       ls -ld dir         # private directory
chmod u+x,g-r,o= file.txt; ls -l file.txt   # symbolic form
```
> Tip: `stat -c '%A %a %n' file.txt` prints the symbolic and octal mode side by side.

✍️ **Your answer — fill in what you saw:**

| Command | Mode string | Octal |
|---|---|---|
| `chmod 600 file.txt` | | |
| `chmod 644 file.txt` | | |
| `chmod 755 dir` | | |
| `chmod 700 dir` | | |
| `chmod u+x,g-r,o= file.txt` | | |

### Step 1.3 — `umask` (why new files are 644, not 666)
```bash
umask                                    # usually 0022 on Arch
touch new1 && ls -l new1                 # 644 = 666 & ~022
umask 077 && touch new2 && ls -l new2    # 600
umask 022                                # put it back!
```

✍️ **Your answer — in your own words, why did `new2` come out as `600`?**

>

### Step 1.4 — Ownership
```bash
sudo chown root file.txt && ls -l file.txt
sudo chown $USER:$USER file.txt && ls -l file.txt
sudo chgrp adm file.txt && ls -l file.txt
```
> If `chown $USER:$USER` errors with "invalid group", your primary group has a different name:
> run `id -gn` and use `sudo chown $USER:$(id -gn) file.txt` instead.

### Step 1.5 — ⭐ The directory experiment (the point of the lab)
```bash
mkdir -p ~/lab2/parent/child
echo "secret" > ~/lab2/parent/child/data.txt
chmod 644 ~/lab2/parent/child/data.txt     # you have read on the FILE

chmod 644 ~/lab2/parent                    # remove EXECUTE on the parent dir
cat ~/lab2/parent/child/data.txt           # what happens?
ls ~/lab2/parent                           # and this?
ls -l ~/lab2/parent                        # bonus: look at the ??? fields

namei -l ~/lab2/parent/child/data.txt      # THIS is how you diagnose it
chmod 755 ~/lab2/parent                    # restore
```

**Optional extra (proves the `x` without `r` case):**
```bash
chmod 311 ~/lab2/parent                    # -wx--x--x : traverse yes, list no
ls ~/lab2/parent                           # ?
cat ~/lab2/parent/child/data.txt           # ? (you know the exact name)
chmod 755 ~/lab2/parent                    # restore
```

✍️ **Your answer — write down what you observed:**

| Command (parent dir = `644`) | What happened / error message |
|---|---|
| `cat .../child/data.txt` | |
| `ls ~/lab2/parent` | |
| `ls -l ~/lab2/parent` | |
| `namei -l ...` — which path component is the problem? | |

| Command (parent dir = `311`, optional) | What happened |
|---|---|
| `ls ~/lab2/parent` | |
| `cat .../child/data.txt` | |

✍️ **Your answer — explain `r`, `w`, `x` on a directory in your own words:**

- `r` on a directory means:
- `w` on a directory means:
- `x` on a directory means:
- Why could you **not** read the file even though the file itself was `644`?

>

### Step 1.6 — Special bits
```bash
ls -l /usr/bin/passwd     # -rwsr-xr-x  <- 's' = setuid
ls -ld /tmp               # drwxrwxrwt  <- 't' = sticky bit
```

The lab's `chmod u+s somefile; chmod g+s somedir; chmod +t somedir` needs those to exist first:
```bash
cd ~/lab2
touch somefile && mkdir somedir
chmod u+s somefile;  ls -l somefile     # note: capital S = setuid set but no x underneath
chmod g+s somedir;   ls -ld somedir     # setgid on a dir: new files inherit the dir's group
chmod +t somedir;    ls -ld somedir     # sticky bit
```

Bonus — the security angle (finds every setuid file on the system):
```bash
sudo find / -xdev -perm -4000 -type f 2>/dev/null
```

✍️ **Your answer:**

- What does setuid do for `/usr/bin/passwd`, and why does it need it?

  >

- Why is the sticky bit on `/tmp` important?

  >

- Why do you see a capital `S` on `somefile` instead of lowercase `s`?

  >

---

## Part 2 — Users and groups (45 min) · all 🐧 [Arch VM]

### Step 2.1 — Who am I, really
```bash
id; whoami; groups
head -3 /etc/passwd          # username:x:UID:GID:comment:home:shell
head -3 /etc/group
ls -l /etc/shadow            # note the permissions on this file
sudo head -2 /etc/shadow     # password hashes
```

✍️ **Your answer — your `id` output, and what are the permissions on `/etc/shadow`?**

>

### Step 2.2 — Create a service account
```bash
sudo useradd -r -s /usr/sbin/nologin -d /opt/appsvc -m appsvc
id appsvc
grep appsvc /etc/passwd
```
> On Arch, `/usr/sbin` is a symlink to `/usr/bin`, so `/usr/sbin/nologin` works fine.
> Test it: `sudo su - appsvc` should refuse with "This account is currently not available."

✍️ **Your answer — what UID did `appsvc` get, and why is it below 1000? Why `nologin`?**

>

### Step 2.3 — Groups
```bash
sudo groupadd deployers
sudo usermod -aG deployers $USER
groups                 # deployers is NOT listed yet — group changes need a new login
newgrp deployers       # starts a NEW subshell with the group active
groups                 # now it's there
exit                   # leave the newgrp subshell
```
> ⚠️ Never forget the `-a` in `usermod -aG`. Without it, `-G` **replaces** all your groups
> (including `wheel`) and you can lose sudo.

### Step 2.4 — sudoers via `visudo`
Arch's default `visudo` editor is `vi`; use nano instead:
```bash
sudo EDITOR=nano visudo -f /etc/sudoers.d/deployers
```
In the editor, add this single line, then save (`Ctrl+O`, Enter) and exit (`Ctrl+X`):
```text
%deployers ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp
```
Verify:
```bash
sudo visudo -c                           # checks all sudoers files for syntax
sudo ls -l /etc/sudoers.d/deployers      # should be -r--r----- (0440)
sudo -l                                  # lists what you're allowed to run
```
> The lab says `/bin/systemctl`; on Arch both paths work (`/bin` → `/usr/bin`), but sudo matches
> the path you write, so use the real one: `/usr/bin/systemctl`.

✍️ **Your answer — why must you always use `visudo` instead of editing `/etc/sudoers` directly?**

>

---

## Part 3 — Processes (60 min) · all 🐧 [Arch VM]

### Step 3.1 — Snapshot views
```bash
ps aux | head
ps -ef | head
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu | head
```

### Step 3.2 — Process trees
```bash
ps -ef --forest | head -40
pstree -p | head -20
```

✍️ **Your answer — what is PID 1 on your VM, and what is the parent (PPID) of your shell?**
(Hint: `echo $$` gives your shell's PID.)

>

### Step 3.3 — Live views
```bash
top     # press: M (sort memory), P (cpu), 1 (per-core), c (full cmd), q (quit)
htop    # F6 to sort, F5 tree view, q to quit
```

### Step 3.4 — Process states (memorize)

| STAT | Meaning |
|---|---|
| `R` | Running or runnable |
| `S` | Interruptible sleep — most processes, most of the time |
| `D` | **Uninterruptible sleep** — blocked on I/O. Can't be killed. Counts toward load average |
| `Z` | Zombie — finished, parent hasn't reaped it |
| `T` | Stopped |
| `<` / `N` | High / low priority |
| `s` | Session leader |
| `+` | Foreground process group |

### Step 3.5 — Signals (run one line at a time)
```bash
sleep 300 &
jobs
kill %1                     # SIGTERM (15) — polite
jobs

sleep 300 & kill -9 %1      # SIGKILL (9) — no cleanup
jobs

sleep 300 &
kill -STOP %1; jobs         # shows "Stopped"
ps -o pid,stat,cmd -C sleep # STAT column shows T
kill -CONT %1; jobs         # running again
kill %1                     # clean up

kill -l                     # full signal list
```

✍️ **Your answer — what did `jobs` print after `kill %1` vs `kill -9 %1`? What STAT did the stopped sleep show?**

>

### Step 3.6 — Job control
```bash
sleep 300          # now press Ctrl+Z to suspend
jobs
bg %1              # resume in background
fg %1              # bring to foreground — then press Ctrl+C to end it
```

`long_task.sh` doesn't exist yet; create it first:
```bash
cat > ~/lab2/long_task.sh <<'EOF'
#!/bin/bash
for i in $(seq 1 120); do echo "tick $i"; sleep 5; done
EOF
chmod +x ~/lab2/long_task.sh

cd ~/lab2
nohup ./long_task.sh &     # output goes to nohup.out
jobs
disown -h %1               # don't send it SIGHUP when the shell exits
tail -f nohup.out          # Ctrl+C to stop watching (the task keeps running)
```
Prove it survives logout:
```bash
exit                       # 🐧 log out of SSH
```
```bash
gcloud compute ssh arch@lab --zone us-east1-b --project twollist-twots-lab --tunnel-through-iap   # 🍎 [macOS] log back in
```
```bash
pgrep -af long_task        # 🐧 still running?
pkill -f long_task.sh      # 🐧 clean up
```

✍️ **Your answer — was `long_task.sh` still running after you reconnected? Why?**

>

---

## Challenge · 🐧 [Arch VM]

Write **one command each**. Test it on the VM, paste the command in the code block, and note what it
showed under **Output / notes**.

> Hints for setting up test cases:
> - For #2, your `appsvc` account has a `nologin` shell. Start something as it with
>   `sudo -u appsvc sleep 600 &` so there's a process to find.
> - For #4, start a few `sleep 999 &` processes as targets.

### 1. Top 5 processes by memory, with RSS in MB
```bash
# your command here
```
**Output / notes:**

>

### 2. Every process owned by a user whose shell is `nologin`
```bash
# your command here
```
**Output / notes:**

>

### 3. How long the oldest running process has been up
```bash
# your command here
```
**Output / notes:**

>

### 4. Kill every process matching a pattern — safely (dry run first)
```bash
# dry run command:

# real kill command:

```
**Output / notes:**

>

### 5. Find any process in `D` state
```bash
# your command here
```
**Output / notes (what does an empty result mean?):**

>

---

## Exit check

Tick each box once you can do it, and write a short answer underneath.

- [ ] **Convert between symbolic and octal in your head**

  ✍️ Convert: `rwxr-x---` = ____ · `640` = ____ · `rw-rw-r--` = ____ · `711` = ____

- [ ] **Explain what `r`, `w`, `x` mean on a directory and demonstrate the traverse case**

  ✍️

  >

- [ ] **Explain setuid and why `find / -perm -4000` matters for security**

  ✍️

  >

- [ ] **Name all seven process states and what `D` implies**

  ✍️

  >

- [ ] **Explain the difference between SIGTERM and SIGKILL and why it matters for containers**

  ✍️

  >

---

## Cleanup and shutdown

### Clean up lab objects · 🐧 [Arch VM]
```bash
umask                                       # confirm it's back to 0022
sudo rm /etc/sudoers.d/deployers            # optional: remove the practice sudo rule
sudo userdel -r appsvc                      # optional: remove the service account
sudo gpasswd -d $USER deployers && sudo groupdel deployers   # optional
```
> Keep `~/lab2` if you want to come back to it.

### Shut down the VM · 🐧 [Arch VM] then 🍎 [macOS]
```bash
exit                         # 🐧 leave the SSH session and get back to the Mac prompt
```
```bash
gcloud compute instances stop lab --zone=us-east1-b    # 🍎 [macOS]
gcloud compute instances list                          # 🍎 [macOS] lab should show TERMINATED
```
