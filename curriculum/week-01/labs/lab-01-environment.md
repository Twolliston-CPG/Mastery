# Lab 1 — Environment Setup and Filesystem Tour

**Time:** 3 hours · **Prereq:** none

## Objectives
- A working Linux VM you can break and rebuild
- Fluency with the filesystem hierarchy and navigation
- `find` without looking up the syntax

---

## Part 1 — Get a real Linux VM (45 min)

**Do not use WSL only.** You need to practice a full VM lifecycle — boot, network, snapshot,
destroy — because that is what cloud instances are.

Pick one:

```bash
# macOS / Linux -- lightest option
brew install multipass                    # or: sudo snap install multipass
multipass launch --name lab --cpus 2 --memory 4G --disk 20G 24.04
multipass shell lab

# Or UTM (macOS, free), VirtualBox (any), or a $6/mo cloud VM
```

> **Arch path:** the VM is a cloud x86 instance (GCP or AWS), not Multipass. Build it and run the bootstrap script
> as described in [`_setup/DISTRO.md`](../../_setup/DISTRO.md), then come back here. Every
> `multipass` command in the labs has a `gcloud` equivalent in the table on that page.

**Snapshot it now, before you break anything:**
```bash
multipass stop lab && multipass snapshot lab --name clean
# restore later with: multipass restore lab.clean
```

### Tasks
1. Launch the VM and SSH into it
2. `sudo apt update && sudo apt install -y tree jq curl git vim htop net-tools`
   (**Arch path:** these were installed by `arch-bootstrap.sh`, *if* you copied it to the VM and ran it in
   the runbook's bootstrap step; it does not run by itself. Confirm with `pacman -Q tree jq htop`. A
   `was not found` answer means the script was never copied or run: go back to that step)
3. Take the `clean` snapshot
4. Verify you can restore it (do this once now, so you trust it later)

---

## Part 2 — The filesystem hierarchy (45 min)

Run `tree -L 1 /` and then answer, **without searching**, what each of these is for:

`/bin` `/sbin` `/usr` `/usr/local` `/etc` `/var` `/var/log` `/tmp` `/opt` `/home` `/root`
`/proc` `/sys` `/dev` `/boot` `/mnt` `/media` `/srv`

### Tasks
```bash
# 1. Where does a binary actually live?
which ls; readlink -f $(which ls); file $(which ls)

# 2. /proc is not a real filesystem -- it is the kernel talking to you
cat /proc/cpuinfo | grep 'model name' | head -1
cat /proc/meminfo | head -5
cat /proc/loadavg
ls /proc/self/           # the shell's own process directory
cat /proc/self/environ | tr '\0' '\n' | head
cat /proc/self/limits

# 3. Pick any running process and inspect it through /proc
pgrep -f sshd | head -1
sudo ls -l /proc/$(pgrep -f sshd | head -1)/fd     # its open file descriptors
sudo cat /proc/$(pgrep -f sshd | head -1)/cmdline | tr '\0' ' '
```

**Write down in your own words:** what `/proc/self/fd` shows you, and why `lsof` is really just a
nicer interface to `/proc`.

---

## Part 3 — `find` until it is automatic (45 min)

Build the answer to each with `find`, then verify:

1. All `.conf` files under `/etc`
2. Files modified in the last 24 hours under `/var/log`
3. Files larger than 1 MB under `/usr`
4. Empty files in your home directory
5. All files owned by root under `/tmp`
6. All directories named `bin` anywhere
7. Files with permissions exactly 777 (there shouldn't be many — think about why that matters)
8. All `.log` files, and delete those older than 7 days (**use `-print` first, `-delete` second**)
9. All files, printing size and path, sorted largest first
10. Everything **not** matching `*.txt` in a directory

```bash
# Patterns worth memorizing
find /etc -name '*.conf' -type f
find /var/log -mmin -1440                     # minutes
find /var/log -mtime -1                       # days
find /usr -size +1M
find . -empty
find /tmp -user root
find / -type d -name bin 2>/dev/null          # 2>/dev/null hides permission noise
find / -xdev -perm 0777 -type f 2>/dev/null   # -xdev stays on one filesystem
find . -name '*.log' -mtime +7 -print          # LOOK FIRST
find . -name '*.log' -mtime +7 -delete         # then delete
find . -type f -printf '%s %p\n' | sort -rn | head
find . ! -name '*.txt' -type f

# The one you will use constantly -- safe for filenames with spaces:
find . -name '*.log' -print0 | xargs -0 grep -l 'ERROR'
# or
find . -name '*.log' -exec grep -l 'ERROR' {} +
```

**Why `-print0`/`-0`?** A filename containing a space breaks naive `xargs`. Null-separation is the
only safe way. This is a real bug class, not pedantry.

---

## Part 4 — Dotfiles in Git (45 min)

```bash
mkdir -p ~/dotfiles && cd ~/dotfiles && git init
```

Create `.bashrc_custom`:
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

echo 'source ~/dotfiles/.bashrc_custom' >> ~/.bashrc
source ~/.bashrc
```

Commit it with a conventional commit message — start the habit now:
```bash
cd ~/dotfiles
git add .
git commit -m "feat(shell): add aliases, history config, and git-aware prompt"
```

---

## Challenge (do this without help)

Write a one-liner that prints the **10 largest files** under `/usr`, showing **human-readable sizes**,
sorted largest first, with no permission-denied noise.

Then answer: why does `du -sh /usr/*` give different numbers than summing `find`'s file sizes?

---

## Exit check
- [ ] VM running, snapshot taken and successfully restored once
- [ ] Can explain what 10 of the top-level directories are for, from memory
- [ ] Wrote all 10 `find` commands without looking up syntax
- [ ] Dotfiles repo committed
- [ ] Can explain why `-print0`/`-0` matters
