# Lab 02: Filesystem Navigation

## Overview

Master Linux filesystem navigation and file management. This lab covers essential skills for navigating directories, manipulating files, and understanding the Linux file hierarchy.

## Objectives

- Navigate the Linux filesystem confidently
- Create, copy, move, and delete files/directories
- Understand file permissions and ownership
- Use links (hard and symbolic)
- Find files and search content

## Prerequisites

- Lab 01 completed (Linux VM running)
- SSH access to your VM

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Basic Navigation

```bash
# Connect to your VM
ssh -i ~/.ssh/devops-lab-key.pem ubuntu@<YOUR_IP>

# Print current directory
pwd
# Output: /home/ubuntu

# List directory contents
ls
ls -l           # Long format
ls -la          # Include hidden files
ls -lh          # Human-readable sizes
ls -lt          # Sort by time

# Change directory
cd /var/log
pwd             # /var/log

cd              # Go to home directory
cd ~            # Also goes home
cd -            # Go to previous directory

# Explore system directories
cd /
ls
# bin  boot  dev  etc  home  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```

### Exercise 2: File Operations

```bash
# Create directory structure
cd ~
mkdir devops-lab
cd devops-lab

mkdir -p projects/app1 projects/app2 configs scripts
# -p creates parent directories as needed

# View structure
tree .
# If tree not installed: find . -type d

# Create files
touch readme.txt
touch configs/app.conf configs/db.conf

# Create file with content
echo "Hello DevOps" > readme.txt
cat readme.txt

# Append content
echo "Learning Linux" >> readme.txt
cat readme.txt

# Create file with multiple lines
cat > notes.txt << 'EOF'
Line 1: Getting started
Line 2: Navigation complete
Line 3: Files are easy
EOF

cat notes.txt
```

### Exercise 3: Copy, Move, Delete

```bash
# Copy files
cp readme.txt readme.backup.txt
ls

# Copy to directory
cp readme.txt projects/app1/
ls projects/app1/

# Copy directory (recursive)
cp -r configs/ backup-configs/
ls

# Move files
mv notes.txt projects/app2/
ls projects/app2/

# Rename files (move to same location)
mv readme.backup.txt readme.old
ls

# Delete files
rm readme.old
ls

# Delete directory
rm -r backup-configs/
ls

# Delete empty directory
mkdir temp
rmdir temp

# Interactive deletion
rm -i projects/app1/readme.txt
# Answer: y
```

### Exercise 4: Viewing File Content

```bash
# Create a longer file
seq 1 100 > numbers.txt

# View entire file
cat numbers.txt

# View first lines
head numbers.txt
head -20 numbers.txt

# View last lines
tail numbers.txt
tail -5 numbers.txt

# Page through file
less numbers.txt
# Press: space (next page), b (previous), / (search), q (quit)

# View with line numbers
cat -n numbers.txt | head

# View system logs
sudo cat /var/log/syslog | head -20
sudo tail -f /var/log/syslog
# Press Ctrl+C to exit tail -f
```

### Exercise 5: File Permissions

```bash
# Create test files
touch script.sh secret.txt public.txt

# View permissions
ls -l
# -rw-rw-r-- 1 ubuntu ubuntu 0 Jan 15 10:00 script.sh

# Understanding permissions:
# -rw-rw-r--
# │└┬┘└┬┘└┬┘
# │ │  │  └── Others: r-- (read only)
# │ │  └───── Group:  rw- (read/write)
# │ └──────── Owner:  rw- (read/write)
# └────────── Type:   - (regular file)

# Change permissions (symbolic)
chmod u+x script.sh           # Add execute for owner
chmod g-w script.sh           # Remove write for group
chmod o-r secret.txt          # Remove read for others
ls -l

# Change permissions (numeric)
chmod 755 script.sh           # rwxr-xr-x
chmod 600 secret.txt          # rw-------
chmod 644 public.txt          # rw-r--r--
ls -l

# Change ownership (requires sudo)
sudo chown root:root secret.txt
ls -l secret.txt
sudo chown ubuntu:ubuntu secret.txt
```

### Exercise 6: Links

```bash
# Create a file
echo "Original content" > original.txt

# Create hard link
ln original.txt hardlink.txt
ls -li  # Note same inode number

# Create symbolic link
ln -s original.txt symlink.txt
ls -l   # Note symlink indicator (->)

# Both links work
cat hardlink.txt
cat symlink.txt

# Modify through hard link
echo "Modified" >> hardlink.txt
cat original.txt  # Shows modification

# Delete original
rm original.txt

# Check links
cat hardlink.txt   # Still works!
cat symlink.txt    # Broken link!

# Cleanup
rm hardlink.txt symlink.txt
```

### Exercise 7: Finding Files

```bash
# Find by name
find /etc -name "*.conf" 2>/dev/null | head -10

# Find by type
find /var/log -type f -name "*.log" 2>/dev/null | head

# Find by size
find /var -size +10M -type f 2>/dev/null

# Find by modification time
find /var/log -mtime -1 -type f 2>/dev/null  # Modified in last day

# Find and execute
find . -name "*.txt" -exec cat {} \;

# Locate (faster but uses database)
sudo updatedb  # Update database first
locate sshd_config

# Which - find executables in PATH
which python3
which bash

# Search file content
grep "ubuntu" /etc/passwd
grep -r "error" /var/log/syslog 2>/dev/null | head
grep -i "error" /var/log/syslog 2>/dev/null | wc -l
```

### Exercise 8: Disk Usage

```bash
# Disk free space
df -h

# Directory size
du -sh /var/log
du -sh ~/*
du -sh /var/* 2>/dev/null | sort -hr | head

# Find largest files
find / -type f -size +50M 2>/dev/null | head
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Directory Structure

Create the following directory structure:

**~/webapp/**

- `config/`
  - `development/`
    - `app.conf`
  - `production/`
    - `app.conf`
  - `shared/`
    - `database.conf`
- `src/`
  - `controllers/`
  - `models/`
  - `views/`
- `tests/`
  - `unit/`
  - `integration/`
- `docs/`
  - `README.md`


Then:
1. Create all directories
2. Create all files with appropriate content
3. Set permissions: configs read-only, src read-write
4. Create a symlink from ~/webapp/README.md to docs/README.md

### Exercise B: Log Analysis

1. Create a fake log file with various log levels:
```bash
cat > /tmp/app.log << 'EOF'
2024-01-15 10:00:00 INFO Application started
2024-01-15 10:00:01 DEBUG Loading config
2024-01-15 10:00:02 INFO Server listening on port 8080
2024-01-15 10:01:00 WARNING High memory usage
2024-01-15 10:02:00 ERROR Database connection failed
2024-01-15 10:02:01 ERROR Retrying database connection
2024-01-15 10:02:02 INFO Database connected
2024-01-15 10:03:00 WARNING Slow query detected
EOF
```

2. Use grep to:
   - Count ERROR messages
   - Find all WARNING messages
   - Extract only timestamps of errors
   - Find lines containing "database" (case insensitive)

### Exercise C: Backup Script

Create a script that:
1. Creates a dated backup directory
2. Copies specific files to the backup
3. Sets appropriate permissions
4. Creates a symlink to "latest" backup

---

## Tier 3: Challenge

Complete all tasks in 45 minutes:

### Challenge Tasks

1. **Filesystem Exploration**
   - Find the 5 largest files in /var
   - Find all SUID files in /usr/bin
   - Count files in /etc by extension
   - Find files modified in the last hour

2. **Complex Directory Operations**
   - Create a nested structure 5 levels deep
   - Create files with specific permissions in each level
   - Create hard links between files in different directories
   - Create symbolic links that form a loop (and understand the result)

3. **Log Processing**
   - Download a sample Apache access log
   - Extract all unique IP addresses
   - Count requests per HTTP method
   - Find the most requested URLs

4. **Permission Challenge**
   - Create a shared directory that:
     - Only group members can write to
     - New files inherit the group
     - Only owners can delete their files
   - Test with different users

### Success Criteria

- [ ] Can navigate filesystem without looking up commands
- [ ] Understand inode concept and hard vs soft links
- [ ] Can set appropriate permissions for any scenario
- [ ] Can find files by various criteria
- [ ] Can analyze text files with grep

---

## Validation Script

```bash
#!/bin/bash

echo "=== Filesystem Lab Validation ==="

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check() {
    if eval "$1" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

cd ~

# Check directory structure
check "[ -d devops-lab ]" "devops-lab directory exists"
check "[ -d devops-lab/projects ]" "projects directory exists"
check "[ -d devops-lab/configs ]" "configs directory exists"

# Check file operations
check "[ -f devops-lab/readme.txt ]" "readme.txt exists"
check "grep -q 'DevOps' devops-lab/readme.txt" "readme.txt has content"

# Check permissions understanding
touch /tmp/test-perm.txt
chmod 755 /tmp/test-perm.txt
check "[ $(stat -c %a /tmp/test-perm.txt) = '755' ]" "chmod 755 works"
rm /tmp/test-perm.txt

# Check grep skills
check "grep -q 'ubuntu' /etc/passwd" "Can use grep to search"

# Check find skills
check "find /etc -name '*.conf' 2>/dev/null | head -1 | grep -q conf" "Can use find"

echo ""
echo "Validation complete!"
```

---

## Troubleshooting

### Permission Denied

```bash
# Check who you are
whoami
id

# Check file permissions
ls -la filename

# Check directory permissions
ls -la /path/to/directory

# Use sudo if needed
sudo cat /etc/shadow
```

### File Not Found

```bash
# Check current directory
pwd

# Check if file exists
ls -la filename

# Use absolute path
cat /full/path/to/file

# Use tab completion
cat /etc/host<TAB>
```

### Disk Full

```bash
# Check disk space
df -h

# Find large files
du -sh /* 2>/dev/null | sort -hr | head

# Clean up
sudo apt clean
sudo journalctl --vacuum-size=100M
```

---

## Key Takeaways

1. **Master basic navigation** - pwd, cd, ls are your foundation
2. **Understand paths** - Absolute (/home/user) vs relative (../parent)
3. **Permissions are crucial** - Wrong permissions cause many issues
4. **Links save space** - Hard links for data, soft links for flexibility
5. **find and grep are powerful** - Learn them well

---

## Next Lab

[Lab 03: User Administration](../lab-03-user-admin/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Basic Navigation
- File Operations
- Copy, Move, Delete
- Viewing File Content

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The kernel manages processes."* |
| ✓ | *"A process is an entry in the kernel's task table with its own memory map and file-descriptor table. `fork()` copies it, `exec()` replaces the program inside it, and the parent must call `wait()` or the entry stays behind as a zombie."* |

**Trace it:** `ls -l /etc` → characters on your terminal. Name every syscall and every kernel structure between the keypress and the output.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) and the [LWN namespaces series](https://lwn.net/Articles/531114/) — the primary sources, not summaries of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#linux-networking)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
