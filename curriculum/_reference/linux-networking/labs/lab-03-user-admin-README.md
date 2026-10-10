# Lab 03: User Administration

## Overview

Learn to manage users, groups, and permissions on Linux systems. These skills are essential for system administration and security management.

## Objectives

- Create and manage user accounts
- Configure groups and group membership
- Set up sudo access
- Implement password policies
- Understand and configure PAM

## Prerequisites

- Lab 02 completed
- SSH access to Linux VM
- Root/sudo access

## Time Estimate

- Guided: 2-3 hours
- Challenge: 1-2 hours

---

## Tier 1: Guided Instructions

### Exercise 1: User Management

```bash
# View current user
whoami
id

# View all users
cat /etc/passwd
cat /etc/passwd | wc -l

# Understanding /etc/passwd format
# username:x:UID:GID:comment:home:shell
# ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash

# Create a new user
sudo useradd -m -s /bin/bash -c "Developer User" developer
# -m: create home directory
# -s: set shell
# -c: comment (full name)

# Verify user created
id developer
ls -la /home/developer
grep developer /etc/passwd

# Set password
sudo passwd developer
# Enter and confirm password

# Create user with specific UID
sudo useradd -m -u 1500 -s /bin/bash sysadmin
id sysadmin
```

### Exercise 2: Modifying Users

```bash
# Change user shell
sudo usermod -s /bin/zsh developer
# Change back
sudo usermod -s /bin/bash developer

# Add comment (full name)
sudo usermod -c "John Developer" developer
grep developer /etc/passwd

# Change home directory
sudo usermod -d /home/dev -m developer
# -m moves content to new directory
ls -la /home/

# Lock user account
sudo usermod -L developer
# Check: ! in password field
sudo grep developer /etc/shadow

# Unlock user account
sudo usermod -U developer

# Change username
sudo usermod -l newname oldname
```

### Exercise 3: Group Management

```bash
# View current groups
groups
id

# View all groups
cat /etc/group

# Create a group
sudo groupadd developers
sudo groupadd -g 2000 admins
# -g: specify GID

# Add user to group
sudo usermod -aG developers developer
# -a: append (important!)
# -G: supplementary groups

# Verify
id developer
groups developer

# Add multiple users to group
sudo usermod -aG developers sysadmin

# View group members
getent group developers

# Remove user from group
sudo gpasswd -d sysadmin developers

# Delete group
sudo groupdel developers
# Note: only works if no user has it as primary group
```

### Exercise 4: Sudo Configuration

```bash
# View sudoers file (never edit directly!)
sudo cat /etc/sudoers

# Edit sudoers safely
sudo visudo

# Add user to sudo group (Debian/Ubuntu)
sudo usermod -aG sudo developer

# Create sudoers.d file (recommended)
sudo visudo -f /etc/sudoers.d/developers

# Add content:
# developer ALL=(ALL) ALL

# Allow specific commands without password
sudo visudo -f /etc/sudoers.d/developers
# developer ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx

# Test sudo access
su - developer
sudo whoami
exit
```

### Exercise 5: Password Policies

```bash
# View password aging info
sudo chage -l developer

# Set password policies
sudo chage -M 90 developer   # Max age 90 days
sudo chage -m 7 developer    # Min age 7 days
sudo chage -W 14 developer   # Warn 14 days before expiry

# Force password change on next login
sudo chage -d 0 developer

# Set account expiration
sudo chage -E 2024-12-31 developer

# Verify
sudo chage -l developer

# Configure global password policy
# Edit /etc/login.defs
sudo cat /etc/login.defs | grep PASS
```

### Exercise 6: File Permissions Practice

```bash
# Create shared directory structure
sudo mkdir -p /projects/shared

# Set ownership
sudo chown root:developers /projects/shared

# Set permissions (rwxrwx---)
sudo chmod 770 /projects/shared

# Set SGID (new files inherit group)
sudo chmod g+s /projects/shared

# Test as developer
su - developer
cd /projects/shared
touch testfile.txt
ls -l testfile.txt
# Note: file has developers group
exit
```

### Exercise 7: ACL (Access Control Lists)

```bash
# Install ACL utilities if needed
sudo apt install acl

# Create test file
touch /tmp/acltest.txt

# View current ACL
getfacl /tmp/acltest.txt

# Add ACL for specific user
setfacl -m u:developer:rw /tmp/acltest.txt

# Add ACL for specific group
setfacl -m g:developers:r /tmp/acltest.txt

# View ACL
getfacl /tmp/acltest.txt

# Set default ACL on directory
sudo setfacl -d -m g:developers:rwx /projects/shared

# Remove ACL
setfacl -x u:developer /tmp/acltest.txt

# Remove all ACLs
setfacl -b /tmp/acltest.txt
```

### Exercise 8: Deleting Users

```bash
# Create test user
sudo useradd -m -s /bin/bash testuser

# Delete user (keep home directory)
sudo userdel testuser
ls -la /home/testuser  # Still exists

# Delete user and home directory
sudo useradd -m testuser
sudo userdel -r testuser
ls -la /home/testuser  # Removed
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Development Team Setup

Create a development environment with:

1. Create three users: `dev1`, `dev2`, `dev3`
2. Create groups: `frontend`, `backend`, `devops`
3. Assign users:
   - dev1: frontend, backend
   - dev2: backend
   - dev3: devops, backend

4. Create project directories:
   **`/projects/`**

| File | What it is |
|---|---|
| `frontend/` | (frontend group access) |
| `backend/` | (backend group access) |
| `devops/` | (devops group access) |


5. Configure so:
   - Each group can read/write their directory
   - New files inherit the group
   - Only owners can delete files

### Exercise B: Restricted Shell User

Create a restricted user that:
1. Can only run specific commands
2. Cannot change directories
3. Has read-only access to certain files
4. Gets logged out after 5 minutes of inactivity

Hints:
- Use rbash (restricted bash)
- Configure PATH restriction
- Use /etc/profile.d/ for timeout

### Exercise C: Audit Configuration

1. Install and configure auditd
2. Set up monitoring for:
   - All sudo commands
   - Changes to /etc/passwd
   - Changes to /etc/shadow
   - SSH login attempts

3. Generate reports on:
   - Authentication attempts
   - File changes

---

## Tier 3: Challenge

Complete all tasks in 60 minutes:

### Challenge Tasks

1. **Complex User Environment**
   - Create 5 users with specific UIDs (3000-3004)
   - Create nested group structure:
     - all-staff (everyone)
     - engineering (subset)
     - senior-engineering (subset of engineering)
   - Configure sudo with different levels:
     - senior: all commands
     - regular: specific commands
     - junior: read-only access to logs

2. **Shared Project Directory**
   - Create /opt/project with:
     - Sticky bit set
     - SGID set
     - ACLs for different access levels
     - Default ACLs for new files

3. **Security Configuration**
   - Implement password policy:
     - Minimum 12 characters
     - Require complexity
     - Maximum 60 day age
     - Cannot reuse last 5 passwords
   - Configure login restrictions:
     - Lock after 5 failed attempts
     - Maximum 2 concurrent sessions

4. **Automation Script**
   - Write a script that:
     - Creates user from CSV file
     - Adds to appropriate groups
     - Sets up home directory template
     - Sends welcome email (simulated)

### Success Criteria

- [ ] All users created with correct properties
- [ ] Group membership correctly configured
- [ ] Sudo access works as expected
- [ ] Password policies enforced
- [ ] Shared directories work correctly
- [ ] ACLs configured properly
- [ ] Automation script works

---

## Validation Script

```bash
#!/bin/bash

echo "=== User Administration Lab Validation ==="

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

# Check users exist
check "id developer" "User 'developer' exists"
check "id sysadmin" "User 'sysadmin' exists"

# Check groups
check "getent group developers" "Group 'developers' exists"

# Check sudo configuration
check "sudo -l -U developer 2>/dev/null" "Sudo configured for developer"

# Check shared directory
check "[ -d /projects/shared ]" "/projects/shared exists"
check "[ $(stat -c %a /projects/shared) = '2770' ] || [ $(stat -c %a /projects/shared) = '2775' ]" \
    "/projects/shared has correct permissions"

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove test users
sudo userdel -r developer 2>/dev/null
sudo userdel -r sysadmin 2>/dev/null

# Remove test groups
sudo groupdel developers 2>/dev/null

# Remove directories
sudo rm -rf /projects

# Remove sudoers file
sudo rm -f /etc/sudoers.d/developers
```

---

## Key Takeaways

1. **Use useradd/usermod carefully** - The -a flag is crucial with -G
2. **Never edit sudoers directly** - Always use visudo
3. **Groups simplify permission management** - Use them liberally
4. **SGID on directories** - Ensures consistent group ownership
5. **Sticky bit protects shared directories** - Prevents deletion by others
6. **ACLs provide fine-grained control** - When standard permissions aren't enough

---

## Next Lab

[Lab 04: Process Control](../lab-04-process-control/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- User Management
- Modifying Users
- Group Management
- Sudo Configuration

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
