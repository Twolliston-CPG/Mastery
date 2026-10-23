# Week 01 · Lab 01 — Arch VM on GCP: Environment Setup and Filesystem Tour

Week 1, Lab 1 of the [twots curriculum](https://github.com/Twolliston-CPG/mastery/tree/main/curriculum),
run on the **Arch path**: an Arch Linux VM on GCP, built with the course's Terraform (`curriculum/_setup/gcp-lab`).

| | |
|---|---|
| **Workstation** | macOS (zsh), `gcloud` + `terraform` installed via Homebrew |
| **VM** | `lab`, Arch Linux, GCP project `twollist-twots-lab`, zone `us-east1-b` |
| **Login user** | `arch` (created by cloud-init; has `sudo`) |
| **Access** | SSH through Identity-Aware Proxy (IAP), no public SSH port |
| **Goal** | Bootstrapped VM with a verified `clean` snapshot; filesystem tour; `find` fluency; dotfiles in Git |

**Part 1 result: ✅ Passed.** A VM booted from the `clean` snapshot had the lab tools installed and did not
contain a file created after the snapshot was taken.

---

## Where each command runs

| Prompt | Location | Tools available |
|---|---|---|
| `➜  gcp-lab git:(twollist-twots)` | 💻 Mac, inside `curriculum/_setup/gcp-lab` | `gcloud`, `terraform` |
| `[arch@lab ~]$` | 🐧 The lab VM | `pacman`, `ls`, all lab commands |
| `[arch@restore-test ~]$` | 🧪 Throwaway test VM | same as the lab VM |

## Contents
1. [Part 1 — VM setup, snapshot, restore test](#part-1--vm-setup-snapshot-and-restore-test)
2. [Part 2 — Filesystem hierarchy](#part-2--filesystem-hierarchy)
3. [Part 3 — `find` drills](#part-3--find-drills)
4. [Part 4 — Dotfiles in Git](#part-4--dotfiles-in-git)
5. [What broke, and how it was fixed](#what-broke-and-how-it-was-fixed)

---

## Part 1 — VM setup, snapshot, and restore test

### 1.1 Set the zone and go to the Terraform folder (💻 Mac)
```bash
cd ~/Documents/twots/curriculum/_setup/gcp-lab
ZONE=us-east1-b
gcloud config set compute/zone us-east1-b    # default zone, so gcloud never sees an empty one
```

### 1.2 Start the VM and connect (💻 Mac)
```bash
gcloud compute instances start lab --zone=$ZONE
terraform output -raw ssh_command            # prints: gcloud compute ssh arch@lab --project=twollist-twots-lab --zone=us-east1-b --tunnel-through-iap
$(terraform output -raw ssh_command)         # logs in as arch -> prompt becomes [arch@lab ~]$
```

### 1.3 Bootstrap the VM
💻 Mac, to copy the course's bootstrap script to the VM:
```bash
$(terraform output -raw bootstrap_command)
```
🐧 VM:
```bash
less arch-bootstrap.sh       # read it first
bash arch-bootstrap.sh       # run as arch, not with sudo; the script calls sudo itself
sudo reboot                  # if the kernel was upgraded
pacman -Q tree jq htop git vim curl net-tools shellcheck lsof   # verify
```

### 1.4 Stop the VM before snapshotting (💻 Mac)
```bash
gcloud compute instances stop lab --zone=$ZONE    # stop, not suspend: we want a clean disk image
```

### 1.5 Take the `clean` snapshot (💻 Mac)
```bash
gcloud compute instances describe lab --zone=$ZONE --format='value(disks[0].source)'
#   -> .../zones/us-east1-b/disks/lab   (boot disk is named "lab")

gcloud compute snapshots describe clean \
  --format='table(name,creationTimestamp,sourceDisk.basename(),status)'
gcloud compute snapshots list                     # "clean" shows READY
```
If a snapshot named `clean` already exists, see Problem 2 under [What broke](#what-broke-and-how-it-was-fixed).

### 1.6 Plant a canary file on the live VM
💻 Mac:
```bash
gcloud compute instances start lab --zone=$ZONE
$(terraform output -raw ssh_command)
```
🐧 VM:
```bash
echo "this file is NOT in the clean snapshot" > ~/CANARY
ls ~/CANARY
exit
```

### 1.7 Prove the snapshot restores on a throwaway VM (💻 Mac)

GCP has no in-place snapshot restore, and the course marks restoring onto the Terraform-managed VM
as untested. So the test boots a **separate** VM from the snapshot and leaves `lab` untouched.

```bash
# same private subnet as the lab VM
SUBNET=$(gcloud compute instances describe lab --zone=$ZONE \
  --format='value(networkInterfaces[0].subnetwork)')

# disk from the snapshot
gcloud compute disks create restore-test --zone=$ZONE --source-snapshot=clean

# test VM with the lab VM's settings: same subnet, no public IP, "lab" tag for the IAP firewall rule,
# no service account, and the arch user's SSH key
gcloud compute instances create restore-test --zone=$ZONE \
  --machine-type=e2-medium \
  --disk=name=restore-test,boot=yes,auto-delete=yes \
  --subnet="$SUBNET" --no-address --tags=lab \
  --no-service-account --no-scopes \
  --metadata=block-project-ssh-keys=true,ssh-keys="arch:$(cat ~/.ssh/google_compute_engine.pub)"

# wait 1–3 minutes for first boot, then connect
gcloud compute ssh arch@restore-test --zone=us-east1-b --tunnel-through-iap
```

🧪 Test VM:
```bash
ls ~/CANARY        # expected: No such file or directory
pacman -Q tree jq  # expected: tools installed
exit
```

**Actual output:**
```text
ls: cannot access '/home/arch/CANARY': No such file or directory
tree 2.3.2-1
jq 1.8.2-1
```
This shows the snapshot holds the bootstrapped state from before the canary was created, so the
restore works.

### 1.8 Clean up
💻 Mac, to delete the test VM (its disk is removed with it because of `auto-delete=yes`):
```bash
gcloud compute instances delete restore-test --zone=us-east1-b --quiet
gcloud compute instances list        # only "lab" should remain
```
🐧 VM, to remove the canary from the real VM:
```bash
rm ~/CANARY
```
💻 Mac, at the end of every session:
```bash
gcloud compute instances stop lab --zone=$ZONE
```

---

## Part 2 — Filesystem hierarchy

All steps run on 🐧 the VM, as `arch`.

### 2.1 Look at the top level
```bash
tree -L 1 /
ls -l / | grep -- '->'      # which top-level entries are symlinks
```
**Arch difference:** `/bin`, `/sbin` and `/lib` are symlinks into `/usr`, and every executable lives in
`/usr/bin`. `/media` may not exist.

### 2.2 From memory, one line for each directory
| Directory | What it's for |
|---|---|
| `/bin` | Essential user commands (`ls`, `cp`, `bash`). On Arch a symlink to `/usr/bin` |
| `/sbin` | Essential admin commands (`mount`, `ip`). On Arch also a symlink to `/usr/bin` |
| `/usr` | Almost all installed software: binaries, libraries, docs. Owned by the package manager |
| `/usr/local` | Software you install by hand, outside the package manager, so `pacman` never touches it |
| `/etc` | This machine's configuration, mostly plain text files |
| `/var` | Data that changes while the system runs: logs, caches, queues, package database |
| `/var/log` | Logs. On Arch most go to the binary systemd journal in `/var/log/journal` |
| `/tmp` | Scratch files, deleted on reboot. A RAM-backed tmpfs on Arch |
| `/opt` | Self-contained third-party software that keeps its own directory tree |
| `/home` | One directory per normal user (`/home/arch`) |
| `/root` | The root user's home directory, kept apart from `/home` |
| `/proc` | Virtual files the kernel generates: processes, CPU, memory |
| `/sys` | Virtual files exposing devices, drivers and kernel settings |
| `/dev` | Device files (disks, terminals, `/dev/null`) |
| `/boot` | Kernel, initramfs and bootloader files |
| `/mnt` | Mount point you use by hand for temporary filesystems |
| `/media` | Mount point for removable media. May not exist on Arch |
| `/srv` | Data this machine serves, such as web or FTP content |

Your home is `/home/arch`, and `/root` belongs to root:
```bash
ls /root          # Permission denied as arch
sudo ls /root     # works
```

### 2.3 Find where a binary really lives
```bash
which ls
readlink -f "$(which ls)"
file "$(which ls)"
```

### 2.4 Read from `/proc`
The kernel generates these files on demand; nothing in them is stored on disk.
```bash
grep 'model name' /proc/cpuinfo | head -1
head -5 /proc/meminfo
cat /proc/loadavg
ls /proc/self/
tr '\0' '\n' < /proc/self/environ | head    # USER=arch, HOME=/home/arch
cat /proc/self/limits
```

### 2.5 Inspect sshd through `/proc`
sshd is owned by root, so reading its file descriptors needs `sudo`.
```bash
PID=$(pgrep -f 'sshd' | head -1); echo "$PID"
ls -l /proc/$PID/fd               # as arch: Permission denied
sudo ls -l /proc/$PID/fd          # works
sudo cat /proc/$PID/cmdline | tr '\0' ' '; echo
```

### 2.6 `lsof` and `/proc` show the same thing
```bash
lsof -p $$          # your shell's open files
ls -l /proc/$$/fd   # the same files, raw
```

**My notes:**
- What `/proc/self/fd` shows: one symlink per file the process currently has open, named by file
  descriptor number. `0`, `1` and `2` are stdin, stdout and stderr, pointing at the terminal
  (`/dev/pts/N`). Other numbers are files, sockets and pipes, and `ls -l` shows where each points.
- Why `lsof` is a nicer interface to `/proc`: it reads `/proc/*/fd` for every process and adds the
  process name, user, file type and socket details in columns. You can also ask "who has this file
  or port open?" instead of walking directories by hand.

---

## Part 3 — `find` drills

All steps run on 🐧 the VM.

### 3.1 Create practice files
Arch writes most logs to the binary systemd journal, so there are few `.log` files to practice on.
These commands make some:
```bash
mkdir -p ~/findlab && cd ~/findlab
touch -d '10 days ago' old1.log old2.log
touch new.log notes.txt empty.txt
echo "ERROR disk full" > "has space.log"
```

### 3.2 The 10 `find` commands
Write each one yourself before checking it against the reference here.
```bash
find /etc -name '*.conf' -type f 2>/dev/null           # 1. .conf files under /etc
sudo find /var/log -mtime -1                           # 2. modified in last 24h (journal needs sudo)
sudo find /var/log -mmin -1440                         # 2b. same window in minutes (24h x 60 = 1440)
find /usr -size +1M -type f 2>/dev/null                # 3. larger than 1 MB under /usr
find ~ -empty                                          # 4. empty files in /home/arch
find /tmp -user root 2>/dev/null                       # 5. owned by root under /tmp (tmpfs on Arch)
find / -type d -name bin 2>/dev/null                   # 6. directories named bin
find / -xdev -perm 0777 -type f 2>/dev/null            # 7. mode exactly 777, one filesystem
find ~/findlab -name '*.log' -mtime +7 -print          # 8a. LOOK first
find ~/findlab -name '*.log' -mtime +7 -delete         # 8b. then delete
find ~/findlab -type f -printf '%s %p\n' | sort -rn | head   # 9. size + path, largest first, top 10
find ~/findlab ! -name '*.txt' -type f                 # 10. everything not *.txt
```
- **#7:** world-writable files let any user change them, which is a security risk.
- **#8:** always run with `-print` before `-delete`.

### 3.3 Why `-print0` matters
```bash
cd ~/findlab
find . -name '*.log' | xargs grep -l ERROR            # breaks on "has space.log"
find . -name '*.log' -print0 | xargs -0 grep -l ERROR # works
find . -name '*.log' -exec grep -l ERROR {} +         # also works: find runs grep itself, no pipe
```
Plain `xargs` splits input on spaces, so `has space.log` is read as two files: `has` and `space.log`.
With `-print0` and `-0`, filenames are separated by a null byte instead, and a filename cannot
contain a null byte.

`-exec … {} +` avoids the problem differently: `find` passes each filename to `grep` as its own
argument, so no text is split. The `+` batches many files into one `grep` call, like `xargs`; with
`\;` instead it would start one `grep` per file.

---

## Part 4 — Dotfiles in Git

All steps run on 🐧 the VM.

### 4.1 Set your git identity
A fresh VM has no git identity configured.
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

### 4.2 Create the repo
```bash
mkdir -p ~/dotfiles && cd ~/dotfiles && git init
```

### 4.3 Create `~/dotfiles/.bashrc_custom`
```bash
cat > ~/dotfiles/.bashrc_custom <<'SH'
# --- history ---
export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend

# --- aliases ---
alias ll='ls -alFh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me'

# --- prompt with git branch ---
parse_git_branch() { git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'; }
export PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[33m\]$(parse_git_branch)\[\e[0m\]\$ '

# --- safety ---
alias rm='rm -i'
set -o noclobber     # don't overwrite files with > ; use >| to force
SH
```

### 4.4 Load it from `~/.bashrc`
```bash
[ -f ~/.bashrc ] || cp /etc/skel/.bashrc ~/      # cloud-init users sometimes have none
echo 'source ~/dotfiles/.bashrc_custom' >> ~/.bashrc
source ~/.bashrc
ll                     # test an alias
cd ~/dotfiles          # prompt now shows (main)
```
This file changes how two everyday commands behave:
- `noclobber` stops `>` from overwriting a file that already exists. Use `>|` when you mean to
  overwrite.
- `rm` now asks for confirmation before deleting.

### 4.5 Commit
```bash
git add .
git commit -m "feat(shell): add aliases, history config, and git-aware prompt"
git log --oneline
```

---

## Challenge (no help)
1. Write a one-liner that prints the 10 largest files under `/usr`, with human-readable sizes,
   largest first, and no permission-denied noise.
   ```bash
   # my answer:
   find /usr -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -10 | numfmt --field=1 --to=iec
   ```
   `find` prints the byte size and path, `sort -rn` puts the biggest first, `head -10` keeps ten,
   and `numfmt` turns the size column into `4.2M`-style units. Sorting happens on raw bytes
   before formatting, which is why `numfmt` comes last.
2. Why does `du -sh /usr/*` give different totals than adding up `find`'s file sizes?
   - my answer: `du` reports disk space allocated, in whole filesystem blocks, while `find`'s `%s`
     reports each file's apparent length in bytes. A 10-byte file still takes a 4 KB block, so `du`
     is larger on trees with many small files. Sparse files go the other way. `du` also counts
     directories and symlinks themselves and counts a hard-linked file once, while
     `find -type f` skips directories and symlinks and lists every hard link separately.

---

## End of session (💻 Mac)
```bash
gcloud compute instances stop lab --zone=us-east1-b
```

---

## Lab 1 exit check
- [x] Arch VM bootstrapped (`pacman -Q tree jq` succeeds)
- [x] `clean` snapshot taken
- [x] Snapshot restore verified on a throwaway VM: `CANARY` absent, tools present
- [ ] Test VM deleted and `~/CANARY` removed from `lab`
- [ ] Can explain 10+ top-level directories, including Arch's `/usr` symlinks and `/root` vs `/home/arch`
- [ ] All 10 `find` commands written without looking up syntax
- [ ] Can explain why `-print0` / `xargs -0` matters
- [ ] Dotfiles repo committed

---

## What broke, and how it was fixed

### Problem 1 — `could not parse resource []`
```text
$ gcloud compute instances describe lab --zone=$ZONE --format='value(disks[0].source)'
ERROR: (gcloud.compute.instances.describe) could not parse resource []
```
**Cause:** `$ZONE` was empty. Shell variables exist only in the terminal tab where you set them. In a
new tab the command ran as `--zone=` with no value.

**Fix:**
```bash
ZONE=us-east1-b
echo "$ZONE"                                   # confirm it prints us-east1-b
gcloud config set compute/zone us-east1-b      # permanent default, so it can't happen again
```
**Lesson:** an unset variable expands to nothing without any warning. This is why the course's Bash
scripts use `set -u`.

---

### Problem 2 — Snapshot `clean` already exists (409)
```text
$ gcloud compute disks snapshot lab --zone=$ZONE --snapshot-names=clean
ERROR: (gcloud.compute.disks.snapshot) HTTPError 409: The resource
'projects/twollist-twots-lab/global/snapshots/clean' already exists
```
**Cause:** a `clean` snapshot had already been taken, during step 12 of `gcp-lab/README.md`. Snapshot
names are unique per project, and GCP will not overwrite one.

**Fix:** check when the existing snapshot was made:
```bash
gcloud compute snapshots describe clean \
  --format='table(name,creationTimestamp,sourceDisk.basename(),status)'
```
- If it was taken **after** the bootstrap, keep it. The restore test in step 7 confirmed this:
  `tree` and `jq` were present.
- If it was taken **before** the bootstrap, or you aren't sure, replace it while the VM is stopped:
  ```bash
  gcloud compute snapshots delete clean --quiet
  gcloud compute disks snapshot lab --zone=$ZONE --snapshot-names=clean
  ```
- To keep both, save the new one under a dated name instead, such as
  `--snapshot-names=clean-$(date +%Y%m%d)`.

---

### Problem 3 — `zsh: command not found: ^[[33m╷^[[0m^[[0m`
```text
➜  twots git:(twollist-twots) $(terraform output -raw ssh_command)
zsh: command not found: ^[[33m╷^[[0m^[[0m
```
**Cause:** the command was run from the **repo root**, not from `curriculum/_setup/gcp-lab`. Outside
that folder Terraform has no state, so it printed a colored error box instead of the SSH command.
`$( … )` then tried to run that error text as a command. The `╷` and `^[[33m` are Terraform's box
border and color codes.

**Fix:** run it from the Terraform folder:
```bash
cd ~/Documents/twots/curriculum/_setup/gcp-lab
$(terraform output -raw ssh_command)
```
Or run it from any folder with `-chdir`, optionally saved as an alias in `~/.zshrc`:
```bash
alias labssh='$(terraform -chdir=$HOME/Documents/twots/curriculum/_setup/gcp-lab output -raw ssh_command)'
```
**Lesson:** always run `terraform output -raw …` on its own first, to see what `$( … )` is about to
execute. The `%` printed after it is zsh marking that the output had no trailing newline. It is
harmless.

---

### Problem 4 — `gcloud: command not found` / `terraform: command not found`
```text
[arch@lab ~]$ gcloud compute instances start lab --zone=$ZONE
-bash: gcloud: command not found
-bash: terraform: command not found
```
**Cause:** the SSH connection had already worked; note the `[arch@lab ~]$` prompt. Mac commands were
then typed **inside the VM**, where `gcloud` and `terraform` are not installed.

**Fix:** check the prompt before running anything. `➜ gcp-lab …` means Mac and `[arch@lab ~]$` means
VM. Run VM steps at the VM prompt, and type `exit` to get back to the Mac.

---

### Problem 5 — IAP `4003: failed to connect to backend` on the test VM
```text
$ gcloud compute ssh arch@restore-test --zone=us-east1-b --tunnel-through-iap
ERROR: [0] Error during local connection to [stdin]: Error while connecting
[4003: 'failed to connect to backend']. (Failed to connect to port 22)
```
**Cause:** the test VM was still on its first boot. IAP reached Google's network, but sshd on the VM
was not listening yet. A VM created from a snapshot gets a new instance identity, so cloud-init
re-runs, and SSH can take 1–3 minutes to come up.

**Fix:** wait and retry. It connected on the next attempt. If it hadn't, these were the next checks:
```bash
gcloud compute instances describe restore-test --zone=us-east1-b --format='value(status)'   # RUNNING?
gcloud compute instances get-serial-port-output restore-test --zone=us-east1-b | tail -40   # boot log: sshd started?
gcloud compute firewall-rules list \
  --format='table(name,network.basename(),sourceRanges.list(),allowed[].map().firewall_rule().list(),targetTags.list())'
#   needs: source 35.235.240.0/20, tcp:22, target tag "lab", same network as the VM
gcloud compute ssh restore-test --zone=us-east1-b --tunnel-through-iap --troubleshoot
```
**Lesson:** "connection refused" or "failed to connect to backend" right after a VM is created usually
means it is still booting, not that it is misconfigured. Check the serial console before changing
firewall rules.
