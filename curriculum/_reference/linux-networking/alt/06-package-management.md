# Module 6: Package Management

## Introduction

Package managers are essential tools for installing, updating, and managing software on Linux systems. Different Linux distributions use different package managers, but they all serve the same fundamental purpose. This module covers package management across major distributions.

## Learning Objectives

After completing this module, you will be able to:
- Understand package management concepts
- Use apt/dpkg on Debian-based systems
- Use yum/dnf/rpm on RHEL-based systems
- Manage repositories
- Handle dependencies

## Package Management Concepts

### What is a Package?

**What is inside a package**

| Contents | Where it lands |
|---|---|
| Binaries | `/usr/bin`, `/usr/sbin` |
| Libraries | `/usr/lib` |
| Configuration | `/etc` — and the package manager will not silently overwrite your edits |
| Documentation | Man pages, `/usr/share/doc` |
| Metadata | Name, version, dependencies, description |
| Scripts | Pre- and post- install and remove hooks |

**Package formats**

| Format | Distributions |
|---|---|
| `.deb` | Debian, Ubuntu, Linux Mint |
| `.rpm` | RHEL, CentOS Stream, Fedora, SUSE |

The metadata is the part that matters. A package is not an archive — it is an archive *plus a
declaration of what else must be present*, which is what lets the package manager refuse an install
that would break something already on the system.

### Package Manager Comparison

**Package managers by distribution**

| | Debian / Ubuntu | RHEL / CentOS / Fedora |
|---|---|---|
| High-level *(resolves dependencies)* | `apt` | `dnf` (formerly `yum`) |
| Low-level *(one file, no resolution)* | `dpkg` | `rpm` |

| Operation | Debian / Ubuntu | RHEL / Fedora |
|---|---|---|
| Refresh metadata | `apt update` | `dnf check-update` |
| Install | `apt install pkg` | `dnf install pkg` |
| Remove | `apt remove pkg` | `dnf remove pkg` |
| Upgrade everything | `apt upgrade` | `dnf upgrade` |
| Search | `apt search term` | `dnf search term` |
| Show details | `apt show pkg` | `dnf info pkg` |
| Install a local file | `dpkg -i file.deb` | `rpm -i file.rpm` |
| List installed | `dpkg -l` | `rpm -qa` |

`apt update` and `apt upgrade` are different commands, and forgetting the first is why an install
sometimes fetches a version that no longer exists on the mirror.

## APT (Debian/Ubuntu)

### Basic Operations

```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade
sudo apt full-upgrade  # May remove packages if needed

# Install packages
sudo apt install package-name
sudo apt install package1 package2

# Install specific version
sudo apt install package=version

# Remove packages
sudo apt remove package-name
sudo apt purge package-name  # Also removes config files
sudo apt autoremove          # Remove unused dependencies

# Search packages
apt search keyword
apt-cache search keyword

# Show package info
apt show package-name
apt-cache show package-name

# List installed packages
apt list --installed
dpkg -l
```

### Managing Repositories

```bash
# Repository configuration files
/etc/apt/sources.list
/etc/apt/sources.list.d/

# Add repository (Ubuntu PPA)
sudo add-apt-repository ppa:user/repo
sudo apt update

# Add repository manually
echo "deb http://repo.example.com/ubuntu focal main" | \
    sudo tee /etc/apt/sources.list.d/example.list

# Add GPG key
curl -fsSL https://repo.example.com/key.gpg | \
    sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/example.gpg

# Remove repository
sudo add-apt-repository --remove ppa:user/repo
# Or delete the file from sources.list.d/
```

### DPKG (Low-Level)

```bash
# Install local .deb file
sudo dpkg -i package.deb

# Fix broken dependencies after dpkg install
sudo apt install -f

# Remove package
sudo dpkg -r package-name
sudo dpkg -P package-name  # Purge with config

# List installed packages
dpkg -l
dpkg -l | grep nginx

# Show package contents
dpkg -L package-name

# Find package owning file
dpkg -S /usr/bin/nginx

# Get package info
dpkg -s package-name

# Extract package without installing
dpkg -x package.deb /destination/
```

### APT Configuration

```bash
# apt configuration
/etc/apt/apt.conf
/etc/apt/apt.conf.d/

# Example: Configure proxy
# /etc/apt/apt.conf.d/proxy
Acquire::http::Proxy "http://proxy.example.com:8080";
Acquire::https::Proxy "http://proxy.example.com:8080";

# Example: Keep downloaded packages
# /etc/apt/apt.conf.d/keep-cache
Binary::apt::APT::Keep-Downloaded-Packages "true";

# Pin package versions
# /etc/apt/preferences.d/hold-nginx
Package: nginx
Pin: version 1.18.*
Pin-Priority: 1001
```

## YUM/DNF (RHEL/CentOS/Fedora)

### Basic Operations

```bash
# Check for updates
dnf check-update
yum check-update

# Install packages
sudo dnf install package-name
sudo yum install package-name

# Install specific version
sudo dnf install package-name-version

# Install local rpm
sudo dnf install ./package.rpm

# Remove packages
sudo dnf remove package-name
sudo dnf autoremove

# Update packages
sudo dnf update
sudo dnf update package-name  # Update specific package

# Search packages
dnf search keyword

# Show package info
dnf info package-name

# List installed packages
dnf list installed
rpm -qa
```

### Managing Repositories

```bash
# Repository configuration
/etc/yum.repos.d/

# List repositories
dnf repolist
dnf repolist all  # Include disabled

# Enable/disable repository
sudo dnf config-manager --enable repo-name
sudo dnf config-manager --disable repo-name

# Add repository
sudo dnf config-manager --add-repo https://repo.example.com/example.repo

# Import GPG key
sudo rpm --import https://repo.example.com/RPM-GPG-KEY

# Example repository file
# /etc/yum.repos.d/example.repo
[example]
name=Example Repository
baseurl=https://repo.example.com/centos/$releasever/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.example.com/RPM-GPG-KEY
```

### RPM (Low-Level)

```bash
# Install rpm
sudo rpm -ivh package.rpm

# Upgrade rpm
sudo rpm -Uvh package.rpm

# Remove package
sudo rpm -e package-name

# List installed packages
rpm -qa
rpm -qa | grep nginx

# Query package info
rpm -qi package-name

# List package files
rpm -ql package-name

# Find package owning file
rpm -qf /usr/sbin/nginx

# Verify package
rpm -V package-name

# Extract rpm without installing
rpm2cpio package.rpm | cpio -idmv
```

### DNF Groups and Modules

```bash
# List available groups
dnf group list

# Install group
sudo dnf group install "Development Tools"

# List modules
dnf module list

# Enable module stream
sudo dnf module enable nodejs:16

# Install module
sudo dnf module install nodejs:16

# Switch module stream
sudo dnf module reset nodejs
sudo dnf module enable nodejs:18
```

## Common Tasks

### Finding Packages

```bash
# Debian/Ubuntu
apt search nginx
apt-cache search --names-only nginx
apt-file search /usr/bin/nginx  # Search by file

# RHEL/CentOS
dnf search nginx
dnf provides /usr/sbin/nginx  # Search by file
```

### Holding Package Versions

```bash
# Debian/Ubuntu - prevent updates
sudo apt-mark hold package-name
sudo apt-mark unhold package-name
apt-mark showhold

# RHEL/CentOS - versionlock
sudo dnf install dnf-plugins-core
sudo dnf versionlock add package-name
sudo dnf versionlock delete package-name
sudo dnf versionlock list
```

### Cleaning Package Cache

```bash
# Debian/Ubuntu
sudo apt clean          # Remove all cached packages
sudo apt autoclean      # Remove old cached packages
du -sh /var/cache/apt   # Check cache size

# RHEL/CentOS
sudo dnf clean all
sudo dnf clean packages
du -sh /var/cache/dnf
```

### Viewing Package History

```bash
# Debian/Ubuntu
cat /var/log/apt/history.log
cat /var/log/dpkg.log

# RHEL/CentOS
dnf history
dnf history info ID
sudo dnf history undo ID  # Rollback
```

## Building from Source

### When to Build from Source

```yaml
reasons_to_build:
  - Package not available in repositories
  - Need newer version than available
  - Need custom compilation options
  - Need to apply patches
  - Learning/development purposes

considerations:
  - No automatic updates
  - Must handle dependencies manually
  - May conflict with system packages
```

### General Build Process

```bash
# Install build dependencies
# Debian/Ubuntu
sudo apt install build-essential

# RHEL/CentOS
sudo dnf groupinstall "Development Tools"

# Common build steps
./configure --prefix=/usr/local
make
sudo make install

# With checkinstall (creates package)
sudo apt install checkinstall
./configure
make
sudo checkinstall  # Creates .deb
```

## Package Management Best Practices

```yaml
best_practices:
  security:
    - Always update package lists before installing
    - Use official repositories when possible
    - Verify GPG signatures
    - Keep system updated for security patches
    - Audit third-party repositories

  maintenance:
    - Remove unused packages regularly
    - Clean package cache periodically
    - Hold critical packages when needed
    - Test updates in staging first
    - Document custom repositories

  automation:
    - Use configuration management tools
    - Automate security updates
    - Version control repository configuration
```

## Summary

Key package management concepts:

1. **apt/dpkg** for Debian-based systems
2. **dnf/yum/rpm** for RHEL-based systems
3. **Repositories** provide trusted package sources
4. **Dependencies** are automatically resolved
5. **Pinning/holding** controls package versions

## Knowledge Check

1. What is the difference between `apt remove` and `apt purge`?
2. How do you add a third-party repository?
3. How do you prevent a package from being upgraded?
4. What command finds which package provides a file?
5. How do you rollback a package update?

## Next Module

Continue to [Module 7: Shell Scripting](./07-shell-scripting.md) for automating Linux tasks.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Package Management Concepts
- APT (Debian/Ubuntu)
- YUM/DNF (RHEL/CentOS/Fedora)
- Common Tasks

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
