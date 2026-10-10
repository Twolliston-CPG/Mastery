# Module 4: Users and Permissions

## Introduction

Linux is a multi-user operating system designed with security in mind. Understanding users, groups, and permissions is fundamental to system administration and security. This module covers user management, file permissions, and access control.

## Learning Objectives

After completing this module, you will be able to:
- Create and manage users and groups
- Understand file permission systems
- Configure sudo access
- Implement the principle of least privilege

## Users and Groups

### User Fundamentals

**What a Linux user actually is**

A row in `/etc/passwd`, and nothing more. Every user has:

| Field | Meaning |
|---|---|
| Username | The name you log in with |
| UID | Numeric user ID — `0` is root, `1–999` are system accounts, `1000+` are people |
| GID | Primary group ID |
| Home directory | Usually `/home/username` |
| Shell | Default login shell — `/bin/bash`, `/bin/zsh`, or `/usr/sbin/nologin` to deny login |
| GECOS | Free-text information: full name, office, contact |

**The files behind it**

| File | Holds |
|---|---|
| `/etc/passwd` | Account information — world-readable, which is why it holds no passwords |
| `/etc/shadow` | Password hashes and ageing — root-only |
| `/etc/group` | Group membership |
| `/etc/gshadow` | Group passwords, rarely used |

The kernel only ever sees the **UID**. The name is a convenience for humans, which is why two
usernames sharing UID 0 are two names for root.

### /etc/passwd File

```bash
# Format: username:password:UID:GID:GECOS:home:shell

# View passwd entries
cat /etc/passwd

# Example entries
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
john:x:1000:1000:John Doe,,,:/home/john:/bin/bash
```

### /etc/shadow File

```bash
# Format: username:password:lastchange:min:max:warn:inactive:expire:reserved

# Only root can read
sudo cat /etc/shadow

# Example entry
john:$6$xyz...:19000:0:99999:7:::

# Password field meanings:
# $6$ = SHA-512 hash
# *   = Account disabled
# !   = Password locked
# !!  = No password set
```

## User Management Commands

### Creating Users

```bash
# Create a new user
sudo useradd username

# Create user with options
sudo useradd -m -s /bin/bash -c "Full Name" -G sudo,docker username

# Options:
# -m        Create home directory
# -s        Set default shell
# -c        Set comment (GECOS)
# -G        Add to supplementary groups
# -d        Specify home directory
# -u        Specify UID
# -g        Specify primary group

# Interactive user creation (Debian/Ubuntu)
sudo adduser username
```

### Modifying Users

```bash
# Change username
sudo usermod -l newname oldname

# Change home directory
sudo usermod -d /new/home -m username

# Add user to group
sudo usermod -aG groupname username

# Change shell
sudo usermod -s /bin/zsh username

# Lock user account
sudo usermod -L username

# Unlock user account
sudo usermod -U username

# Set account expiration
sudo usermod -e 2024-12-31 username
```

### Deleting Users

```bash
# Delete user (keep home directory)
sudo userdel username

# Delete user and home directory
sudo userdel -r username

# Interactive deletion (Debian/Ubuntu)
sudo deluser --remove-home username
```

### Password Management

```bash
# Set/change password
sudo passwd username

# Change your own password
passwd

# Force password change at next login
sudo passwd -e username

# Set password expiration policy
sudo chage -M 90 username  # Max days
sudo chage -m 7 username   # Min days
sudo chage -W 14 username  # Warning days

# View password aging
sudo chage -l username
```

## Group Management

### Group Commands

```bash
# Create a group
sudo groupadd groupname

# Create with specific GID
sudo groupadd -g 2000 groupname

# Delete a group
sudo groupdel groupname

# Modify a group
sudo groupmod -n newname oldname

# View groups
groups                    # Your groups
groups username          # Another user's groups
id username              # Detailed info
```

### Managing Group Membership

```bash
# Add user to group
sudo usermod -aG groupname username

# Alternative method
sudo gpasswd -a username groupname

# Remove user from group
sudo gpasswd -d username groupname

# Set group administrators
sudo gpasswd -A admin_user groupname

# View group members
getent group groupname
```

## File Permissions

### Permission Basics

**File permission structure**

```text
-rwxrwxrwx  1  owner  group  size  date  filename
│├─┤├─┤├─┤
│ │  │  └── other  — everyone else
│ │  └───── group  — members of the owning group
│ └──────── owner  — the owning user
└────────── type
```

The three triplets are checked in order and the **first match wins**. If you own the file, only the
owner bits apply — being in the group as well does not add to them. That is why removing your own
write bit stops you writing even when the group has `w`.

### Numeric Permissions

```bash
# Permission calculation
# rwx = 4+2+1 = 7
# rw- = 4+2+0 = 6
# r-x = 4+0+1 = 5
# r-- = 4+0+0 = 4

# Common permission values
chmod 755 file  # rwxr-xr-x (directories, scripts)
chmod 644 file  # rw-r--r-- (regular files)
chmod 600 file  # rw------- (private files)
chmod 700 dir   # rwx------ (private directories)
chmod 777 file  # rwxrwxrwx (AVOID - insecure)
```

### Changing Permissions

```bash
# Numeric method
chmod 755 file
chmod 644 file

# Symbolic method
chmod u+x file      # Add execute for owner
chmod g-w file      # Remove write for group
chmod o=r file      # Set others to read only
chmod a+r file      # Add read for all
chmod u=rwx,g=rx,o=r file

# Recursive
chmod -R 755 directory/

# Reference another file
chmod --reference=file1 file2
```

### Changing Ownership

```bash
# Change owner
sudo chown newowner file

# Change group
sudo chgrp newgroup file
# Or
sudo chown :newgroup file

# Change both
sudo chown newowner:newgroup file

# Recursive
sudo chown -R user:group directory/
```

### Directory Permissions

```bash
# Directory permissions work differently:
# r = list contents (ls)
# w = create/delete files
# x = access directory (cd)

# Common directory permissions
chmod 755 dir   # Owner full, others can read/access
chmod 750 dir   # Owner full, group read/access, others none
chmod 700 dir   # Owner only

# Example: Web directory
sudo mkdir /var/www/mysite
sudo chown www-data:www-data /var/www/mysite
sudo chmod 755 /var/www/mysite
```

## Special Permissions

### SUID, SGID, and Sticky Bit

```bash
# SUID (Set User ID) - 4000
# File executes as owner, not as user running it
chmod u+s file
chmod 4755 file

# Example: passwd command runs as root
ls -l /usr/bin/passwd
-rwsr-xr-x 1 root root ... /usr/bin/passwd

# SGID (Set Group ID) - 2000
# Files: Execute as group owner
# Directories: New files inherit group
chmod g+s directory
chmod 2755 directory

# Sticky Bit - 1000
# Only owner can delete files in directory
chmod +t directory
chmod 1777 directory

# Example: /tmp directory
ls -ld /tmp
drwxrwxrwt 1 root root ... /tmp
```

### Finding Special Permissions

```bash
# Find SUID files
find / -perm -4000 -type f 2>/dev/null

# Find SGID files
find / -perm -2000 -type f 2>/dev/null

# Find world-writable files
find / -perm -002 -type f 2>/dev/null

# Find files without owner
find / -nouser 2>/dev/null
```

## Sudo Configuration

### Understanding Sudo

```bash
# Run command as root
sudo command

# Run as different user
sudo -u username command

# Edit files as root
sudo nano /etc/hosts
# Or use sudoedit
sudoedit /etc/hosts

# Run shell as root
sudo -i    # Login shell
sudo -s    # Non-login shell

# List sudo privileges
sudo -l
```

### Sudoers File

```bash
# Edit sudoers safely
sudo visudo

# Sudoers file location
/etc/sudoers
/etc/sudoers.d/   # Drop-in directory

# Basic syntax
# user  host=(runas)  commands
john    ALL=(ALL:ALL) ALL        # Full sudo access
john    ALL=(ALL) NOPASSWD: ALL  # No password required

# Group syntax (prefix with %)
%sudo   ALL=(ALL:ALL) ALL
%wheel  ALL=(ALL) ALL

# Specific commands
john    ALL=(ALL) /usr/bin/apt update, /usr/bin/apt upgrade
john    ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx
```

### Sudo Best Practices

```bash
# Create user-specific file
sudo visudo -f /etc/sudoers.d/john

# Content:
john ALL=(ALL) /usr/bin/docker, /usr/bin/systemctl restart nginx

# Use aliases for organization
# /etc/sudoers
Cmnd_Alias DOCKER_CMDS = /usr/bin/docker
Cmnd_Alias SERVICE_CMDS = /usr/bin/systemctl restart nginx, \
                          /usr/bin/systemctl restart apache2

john ALL=(ALL) DOCKER_CMDS, SERVICE_CMDS
```

## Access Control Lists (ACLs)

### ACL Basics

```bash
# Check if filesystem supports ACLs
mount | grep acl

# View ACLs
getfacl file

# Set ACL for user
setfacl -m u:username:rwx file

# Set ACL for group
setfacl -m g:groupname:rx file

# Set default ACL for directory
setfacl -d -m u:username:rwx directory/

# Remove specific ACL
setfacl -x u:username file

# Remove all ACLs
setfacl -b file

# Copy ACLs
getfacl file1 | setfacl --set-file=- file2
```

### ACL Examples

```bash
# Scenario: Project directory with multiple access levels
sudo mkdir /project
sudo chown root:developers /project
sudo chmod 770 /project

# Add read access for auditor
sudo setfacl -m u:auditor:rx /project

# Add write access for manager
sudo setfacl -m u:manager:rwx /project

# Set defaults for new files
sudo setfacl -d -m g:developers:rwx /project
sudo setfacl -d -m u:auditor:rx /project

# View result
getfacl /project
```

## Practical Examples

### Creating a Development Environment

```bash
#!/bin/bash
# setup-dev-env.sh

# Create development group
sudo groupadd developers

# Create user
sudo useradd -m -s /bin/bash -G developers newdev
sudo passwd newdev

# Create project directory
sudo mkdir -p /var/projects
sudo chown root:developers /var/projects
sudo chmod 2775 /var/projects  # SGID for group inheritance

# Set up sudo access for deployment
echo "newdev ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/systemctl restart nginx" | \
    sudo tee /etc/sudoers.d/newdev

# Set proper permissions
sudo chmod 440 /etc/sudoers.d/newdev
```

### Secure File Sharing

```bash
#!/bin/bash
# setup-shared-folder.sh

SHARE_DIR="/shared"
GROUP_NAME="fileshare"

# Create group and directory
sudo groupadd $GROUP_NAME
sudo mkdir -p $SHARE_DIR

# Set ownership and permissions
sudo chown root:$GROUP_NAME $SHARE_DIR
sudo chmod 2770 $SHARE_DIR  # SGID

# Add sticky bit to prevent deletion by non-owners
sudo chmod +t $SHARE_DIR

# Final permissions: drwxrws--T
```

## Summary

Key user and permission concepts:

1. **Users** are managed via useradd, usermod, userdel
2. **Groups** organize users for access control
3. **Permissions** use rwx for owner, group, others
4. **Special permissions** (SUID, SGID, sticky) enable advanced control
5. **Sudo** provides controlled root access

## Knowledge Check

1. What is the difference between /etc/passwd and /etc/shadow?
2. How do you add a user to a group without removing existing groups?
3. What does chmod 755 mean?
4. When would you use the SGID bit on a directory?
5. How do you grant sudo access for specific commands only?

## Next Module

Continue to [Module 5: Process Management](./05-process-management.md) for managing Linux processes.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Users and Groups
- User Management Commands
- Group Management
- File Permissions

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
