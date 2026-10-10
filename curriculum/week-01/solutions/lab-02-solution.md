# Lab 2 — Solutions

## Part 1 — The directory experiment

```bash
chmod 644 ~/lab2/parent          # rw-r--r--  : no execute
cat ~/lab2/parent/child/data.txt # -> Permission denied
ls ~/lab2/parent                 # -> WORKS (lists names)
```

**What happened:** you can still *list* the directory because `r` is set, but you cannot *traverse*
into it because `x` is not. Path resolution requires execute on **every** directory in the path.

```bash
namei -l ~/lab2/parent/child/data.txt
# f: /home/u/lab2/parent/child/data.txt
#  drwxr-xr-x root  root  /
#  drwxr-xr-x root  root  home
#  drwxr-xr-x u     u     u
#  drwxr-xr-x u     u     lab2
#  drw-r--r-- u     u     parent      <-- missing x. This line is the bug.
#  ?          ?     ?     child
```

The inverse also exists: `chmod 111` (execute only) on a directory means you **can** open a file if
you know its exact name, but `ls` fails. That's a real hardening pattern for directories containing
secrets.

**Directory bits, stated properly:**
| Bit | On a file | On a directory |
|---|---|---|
| `r` | read contents | list entry names |
| `w` | modify contents | create/delete/rename entries |
| `x` | execute it | **traverse into it** |

Note that `w` on a directory lets you **delete a file you have no write permission on** — deletion
modifies the directory, not the file. That's what the sticky bit on `/tmp` exists to prevent.

## Part 2 — Groups don't apply until a new session

```bash
sudo usermod -aG deployers $USER
groups            # deployers NOT listed
```
Group membership is baked into the process credentials at login. `newgrp deployers` starts a new
shell with it, or log out and back in. **In practice this confuses people constantly** — "I added
myself to the docker group and it still says permission denied."

## Part 3 — Challenge answers

```bash
# 1. Top 5 by memory, RSS in MB
ps -eo pid,rss,comm --sort=-rss --no-headers \
  | head -5 \
  | awk '{printf "%-8s %8.1f MB  %s\n", $1, $2/1024, $3}'

# 2. Processes owned by nologin service accounts
for u in $(awk -F: '$7 ~ /nologin|false/ {print $1}' /etc/passwd); do
  ps -u "$u" -o pid,user,comm --no-headers 2>/dev/null
done

# 3. Oldest running process
ps -eo etime,pid,comm --sort=-etime --no-headers | head -1

# 4. Safe pattern kill -- ALWAYS dry run first
pgrep -af 'pattern'          # LOOK at what matches
pkill -f 'pattern'           # then kill
# safer still, one at a time:
pgrep -f 'pattern' | while read -r pid; do
  echo "would kill $pid: $(ps -p "$pid" -o comm=)"
done

# 5. Processes in D (uninterruptible sleep)
ps -eo pid,stat,wchan:20,comm | awk '$2 ~ /^D/'
```

**On #5:** the `wchan` column shows the kernel function the process is blocked in, which tells you
*what* it's waiting on — often an NFS or disk operation. A pile of `D`-state processes means an I/O
problem, and `kill -9` will not help, because the kernel won't deliver a signal until the I/O
completes or fails.

## Signals worth knowing

| Signal | Num | Catchable | Use |
|---|---|---|---|
| SIGHUP | 1 | yes | Reload config (nginx, many daemons) |
| SIGINT | 2 | yes | Ctrl+C |
| SIGKILL | 9 | **no** | Last resort — no cleanup, no flush |
| SIGTERM | 15 | yes | **Default, polite shutdown** |
| SIGSTOP | 19 | **no** | Suspend |
| SIGCONT | 18 | yes | Resume |

**The container connection:** Kubernetes sends SIGTERM, waits `terminationGracePeriodSeconds`
(default 30), then SIGKILL. If your app ignores SIGTERM, every deployment takes 30 extra seconds per
pod and in-flight requests get dropped. Handling SIGTERM properly is a real production concern and a
good interview point.
