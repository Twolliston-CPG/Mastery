# Lab 1 — Solutions

## Part 2 — Filesystem hierarchy

| Path | Purpose |
|---|---|
| `/bin` | Essential user binaries. On modern systems a symlink to `/usr/bin`. |
| `/sbin` | System binaries, normally root-only (`fdisk`, `iptables`). Symlink to `/usr/sbin`. |
| `/usr` | Read-only user programs and data — the bulk of the OS |
| `/usr/local` | Software **you** installed, not from the package manager. Survives OS upgrades. |
| `/etc` | System-wide configuration. Text files. Everything you'd back up. |
| `/var` | Variable data that changes at runtime — logs, spool, caches, databases |
| `/var/log` | Log files. **This is what fills up and takes down the server** (BF-01). |
| `/tmp` | Temporary, world-writable with sticky bit, cleared on reboot |
| `/opt` | Self-contained third-party packages |
| `/home` | User home directories |
| `/root` | Root's home. Note: **not** `/home/root`. |
| `/proc` | Virtual FS — kernel and process state as files. Not on disk. |
| `/sys` | Virtual FS — device and kernel object tree. Not on disk. |
| `/dev` | Device files. `/dev/null`, `/dev/urandom`, `/dev/sda` |
| `/boot` | Kernel, initramfs, bootloader |
| `/mnt`, `/media` | Mount points — manual and removable respectively |
| `/srv` | Data served by this system (web roots, ftp) |

### `/proc/self/fd`
Shows every file descriptor the current process has open, as symlinks to their targets. It's the
mechanism behind `lsof` — which is why `lsof +L1` can find a deleted-but-open file (BF-01): the
symlink target says `(deleted)` but the fd still pins the inode, so the disk space isn't freed.

```bash
ls -l /proc/self/fd
# 0 -> /dev/pts/0   (stdin)
# 1 -> /dev/pts/0   (stdout)
# 2 -> /dev/pts/0   (stderr)
```

**Why this matters later:** a container is a process with a different view of `/proc`. Understanding
`/proc` now makes container isolation obvious in week 4.

## Part 3 — `find` answers

```bash
# 1
find /etc -name '*.conf' -type f 2>/dev/null
# 2
find /var/log -type f -mtime -1
# 3
find /usr -type f -size +1M
# 4
find ~ -type f -empty
# 5
find /tmp -user root
# 6
find / -type d -name bin 2>/dev/null
# 7
find / -xdev -type f -perm 0777 2>/dev/null
#    World-writable files are a privilege-escalation vector: any user can replace
#    the contents. If it's also executable and run by root, that's a root shell.
# 8
find . -name '*.log' -mtime +7 -print
find . -name '*.log' -mtime +7 -delete
# 9
find . -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head
# 10
find . -type f ! -name '*.txt'
```

### `-exec {} +` vs `-exec {} \;`
- `\;` runs the command **once per file** — 10,000 files means 10,000 process spawns. Slow.
- `+` batches files into as few invocations as possible, like `xargs`. Use this.

```bash
find . -name '*.log' -exec grep -l ERROR {} \;   # slow
find . -name '*.log' -exec grep -l ERROR {} +    # fast
```

## Challenge

```bash
find /usr -type f -printf '%s %p\n' 2>/dev/null \
  | sort -rn \
  | head -10 \
  | awk '{ $1 = sprintf("%.1fM", $1/1048576); print }'

# Or simpler, if GNU du is available:
find /usr -type f -print0 2>/dev/null | du -h --files0-from=- | sort -rh | head -10
```

**Why `du -sh /usr/*` differs from summing file sizes:**

1. **`du` reports disk usage, `find %s` reports apparent size.** A file's blocks on disk are
   allocated in units (typically 4 KiB), so a 10-byte file consumes 4096 bytes. Thousands of tiny
   files make `du` much larger than the apparent sum.
2. **Sparse files** report a large apparent size but occupy few blocks — `du` is smaller.
3. **Hard links** are counted once by `du` (it tracks inodes) but once per path by `find`.
4. `du -s` includes directory entries themselves; `find -type f` excludes them.

That block-allocation point is the same reason you can run out of **inodes** while `df -h` shows free
space (BF-08).
