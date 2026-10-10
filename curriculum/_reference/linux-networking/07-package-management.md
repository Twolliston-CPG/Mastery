# Package Management

## Overview

Package management is fundamental to system administration. This module covers package managers for Debian/Ubuntu (apt) and RHEL/CentOS (yum/dnf), along with building and distributing packages.

## Learning Objectives

By the end of this module, you will be able to:
- Install, update, and remove packages
- Manage package repositories
- Query package information
- Handle dependencies
- Build basic packages

---

## Understanding Package Managers

### Package Manager Landscape

**Linux Package Managers:**

```
  Debian/Ubuntu Family          RHEL/CentOS/Fedora Family
  dpkg (low-level)              rpm (low-level)
  apt (high-level)              yum/dnf (high-level)
  Package format: .deb          Package format: .rpm
  Universal Formats
  Snap (Canonical)
  Flatpak (Red Hat)
  AppImage (portable)
```


### What's in a Package?

**What is inside a package**

**Metadata**

- Name, version, architecture
- Dependencies — the part that makes it a package rather than an archive
- Description
- Maintainer
- Pre- and post- install and remove scripts

**Files, and where they land**

| Contents | Destination |
|---|---|
| Binaries | `/usr/bin`, `/usr/sbin` |
| Libraries | `/usr/lib` |
| Configuration | `/etc` — your edits are preserved across upgrades |
| Documentation | `/usr/share/doc` |
| Man pages | `/usr/share/man` |

The install scripts are worth knowing about: they run **as root**, which is why installing a package
from an untrusted repository is equivalent to giving that repository a root shell.

---

## APT Package Management (Debian/Ubuntu)

### Basic APT Commands

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade
sudo apt full-upgrade    # Also handles dependencies

# Install package
sudo apt install nginx
sudo apt install nginx php-fpm mysql-server  # Multiple

# Remove package
sudo apt remove nginx              # Keep config files
sudo apt purge nginx               # Remove config too
sudo apt autoremove                # Remove unused dependencies

# Search for packages
apt search nginx
apt-cache search nginx

# Show package info
apt show nginx
apt-cache show nginx
apt-cache policy nginx    # Show versions and sources
```

### APT Repository Management

```bash
# List configured repositories
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/

# Repository format
# deb http://archive.ubuntu.com/ubuntu/ jammy main restricted
# deb-src http://archive.ubuntu.com/ubuntu/ jammy main restricted

# Add repository
sudo add-apt-repository ppa:ondrej/php
sudo add-apt-repository "deb http://repo.example.com stable main"

# Add GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Modern key-based repository (Ubuntu 22.04+)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Remove repository
sudo add-apt-repository --remove ppa:ondrej/php
```

### Advanced APT Operations

```bash
# Hold package version (prevent upgrades)
sudo apt-mark hold nginx
sudo apt-mark unhold nginx
apt-mark showhold

# Simulate install
apt install --dry-run nginx

# Download without installing
apt download nginx
apt-get download nginx

# Install local .deb file
sudo apt install ./package.deb
# or
sudo dpkg -i package.deb
sudo apt --fix-broken install  # Fix dependencies

# List installed packages
dpkg -l
dpkg -l | grep nginx
apt list --installed

# List files in package
dpkg -L nginx

# Find which package owns a file
dpkg -S /usr/sbin/nginx

# Show reverse dependencies
apt rdepends nginx
```

### APT Configuration

```bash
# Main config file
/etc/apt/apt.conf

# Config directory
/etc/apt/apt.conf.d/

# Common configurations
# /etc/apt/apt.conf.d/99custom
APT::Get::Assume-Yes "true";     # Don't prompt
APT::Install-Recommends "false"; # Skip recommended packages

# Proxy configuration
Acquire::http::Proxy "http://proxy:8080";
Acquire::https::Proxy "http://proxy:8080";
```

---

## YUM/DNF Package Management (RHEL/CentOS)

### Basic YUM/DNF Commands

```bash
# Note: dnf is the successor to yum
# On RHEL 8+/CentOS 8+, yum is symlink to dnf

# Update package lists and upgrade
sudo yum update          # Updates all packages
sudo dnf upgrade         # Same as update

# Install package
sudo yum install nginx
sudo dnf install nginx

# Remove package
sudo yum remove nginx
sudo dnf remove nginx
sudo yum autoremove      # Remove unused dependencies

# Search packages
yum search nginx
dnf search nginx

# Show package info
yum info nginx
dnf info nginx

# List packages
yum list installed
yum list available
dnf list --installed
```

### YUM Repository Management

```bash
# List repositories
yum repolist
yum repolist all    # Include disabled
dnf repolist

# Enable/disable repository
yum-config-manager --enable epel
yum-config-manager --disable epel
dnf config-manager --enable epel

# Add repository
sudo yum install epel-release
sudo dnf install epel-release

# Add custom repository
cat > /etc/yum.repos.d/custom.repo << 'EOF'
[custom]
name=Custom Repository
baseurl=https://repo.example.com/centos/$releasever/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.example.com/RPM-GPG-KEY
EOF

# Import GPG key
sudo rpm --import https://repo.example.com/RPM-GPG-KEY

# Clean cache
yum clean all
dnf clean all
```

### Advanced YUM/DNF Operations

```bash
# Download without installing
yumdownloader nginx
dnf download nginx

# Install local RPM
sudo yum localinstall package.rpm
sudo rpm -ivh package.rpm

# Query installed packages
rpm -qa                  # All packages
rpm -qa | grep nginx     # Filter
rpm -qi nginx            # Package info
rpm -ql nginx            # Files in package
rpm -qf /usr/sbin/nginx  # Package owning file

# Verify package
rpm -V nginx

# History and rollback
yum history
yum history info 15
yum history undo 15
dnf history
dnf history rollback 15

# Lock package version
yum versionlock nginx
dnf versionlock nginx
```

### DNF Modules (RHEL 8+)

```bash
# List modules
dnf module list

# List module streams
dnf module list nodejs

# Enable module stream
sudo dnf module enable nodejs:18

# Install module
sudo dnf module install nodejs:18

# Switch streams
sudo dnf module reset nodejs
sudo dnf module enable nodejs:20
sudo dnf module install nodejs:20
```

---

## Comparing APT and YUM/DNF

| Task | APT (Debian/Ubuntu) | YUM/DNF (RHEL) |
|---|---|---|
| Update repos | apt update | yum check-update |
| Upgrade packages | apt upgrade | yum update |
| Install | apt install PKG | yum install PKG |
| Remove | apt remove PKG | yum remove PKG |
| Search | apt search PKG | yum search PKG |
| Package info | apt show PKG | yum info PKG |
| List installed | dpkg -l | rpm -qa |
| Files in pkg | dpkg -L PKG | rpm -ql PKG |
| Package owns file | dpkg -S FILE | rpm -qf FILE |
| Clean cache | apt clean | yum clean all |


---

## Building Packages

### Building DEB Packages

```bash
# Install build tools
sudo apt install build-essential devscripts debhelper

# Simple package structure
mypackage-1.0/
├── debian/
│   ├── changelog
│   ├── compat
│   ├── control
│   ├── copyright
│   ├── install
│   └── rules
└── src/
    └── myapp.sh

# debian/control
Source: mypackage
Section: utils
Priority: optional
Maintainer: Your Name <you@example.com>
Build-Depends: debhelper (>= 9)

Package: mypackage
Architecture: all
Depends: ${shlibs:Depends}, ${misc:Depends}
Description: My Package
 A longer description of my package.

# debian/rules
#!/usr/bin/make -f
%:
	dh $@

# Build package
cd mypackage-1.0
debuild -us -uc

# Result: mypackage_1.0_all.deb
```

### Building RPM Packages

```bash
# Install build tools
sudo yum install rpm-build rpmdevtools

# Setup RPM build environment
rpmdev-setuptree
# Creates ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create spec file
# ~/rpmbuild/SPECS/mypackage.spec
Name:           mypackage
Version:        1.0
Release:        1%{?dist}
Summary:        My Package

License:        MIT
URL:            https://example.com
Source0:        %{name}-%{version}.tar.gz

%description
A longer description of my package.

%prep
%setup -q

%build
# Build commands here

%install
mkdir -p %{buildroot}/usr/local/bin
install -m 755 myapp.sh %{buildroot}/usr/local/bin/

%files
/usr/local/bin/myapp.sh

%changelog
* Mon Jan 15 2024 Your Name <you@example.com> - 1.0-1
- Initial package

# Build package
rpmbuild -ba ~/rpmbuild/SPECS/mypackage.spec

# Result: ~/rpmbuild/RPMS/noarch/mypackage-1.0-1.noarch.rpm
```

### FPM - Easy Package Building

```bash
# Install fpm
sudo apt install ruby ruby-dev gcc make
sudo gem install fpm

# Create package from directory
fpm -s dir -t deb -n mypackage -v 1.0 \
    --prefix /opt/myapp \
    /path/to/app/

# Create package from script
fpm -s dir -t rpm -n mypackage -v 1.0 \
    --after-install postinstall.sh \
    --before-remove preremove.sh \
    /path/to/files/

# Convert between formats
fpm -s deb -t rpm mypackage_1.0_all.deb

# With dependencies
fpm -s dir -t deb -n mypackage -v 1.0 \
    -d "nginx >= 1.18" \
    -d "python3" \
    /path/to/files/
```

---

## Universal Package Formats

### Snap Packages

```bash
# Install snapd
sudo apt install snapd

# Find packages
snap find docker

# Install package
sudo snap install docker
sudo snap install code --classic  # Classic confinement

# List installed
snap list

# Update
sudo snap refresh
sudo snap refresh docker

# Remove
sudo snap remove docker

# Package info
snap info docker

# Services
snap services docker
snap start docker.dockerd
```

### Flatpak

```bash
# Install flatpak
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Search
flatpak search vscode

# Install
flatpak install flathub com.visualstudio.code

# Run
flatpak run com.visualstudio.code

# List installed
flatpak list

# Update
flatpak update

# Remove
flatpak uninstall com.visualstudio.code
```

---

## Package Security

### Verifying Packages

```bash
# APT - verify installed packages
debsums nginx
debsums -c  # Show only changed files

# RPM - verify packages
rpm -V nginx
rpm -Va  # Verify all packages

# Check package signatures
dpkg-sig --verify package.deb
rpm -K package.rpm
```

### Security Updates

```bash
# Ubuntu/Debian - security updates only
sudo apt update
sudo apt upgrade -y --only-upgrade
# Or use unattended-upgrades

# Configure automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# RHEL/CentOS - security updates
sudo yum update --security
sudo dnf update --security

# Check for security updates
yum updateinfo list security
dnf updateinfo list --security
```

### Auditing Installed Packages

```bash
# List all installed packages with versions
dpkg-query -W -f='${Package} ${Version}\n' > installed_packages.txt
rpm -qa --qf '%{NAME} %{VERSION}\n' > installed_packages.txt

# Check for known vulnerabilities
# Debian/Ubuntu
apt list --installed 2>/dev/null | while read pkg; do
    pkg_name=$(echo "$pkg" | cut -d'/' -f1)
    # Check against CVE database (conceptual)
done

# Use tools like:
# - lynis (security auditing)
# - openscap (compliance checking)
```

---

## Practical Exercises

### Exercise 1: Repository Management

```bash
# 1. Add Docker repository (Ubuntu)
sudo apt update
sudo apt install ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 2. Update and install
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io

# 3. Verify
docker --version
```

### Exercise 2: Package Investigation

```bash
#!/bin/bash
# Script to investigate a package

PACKAGE=${1:-nginx}

echo "=== Package Investigation: $PACKAGE ==="

# Detect package manager
if command -v apt &>/dev/null; then
    echo -e "\n--- Package Info ---"
    apt show "$PACKAGE" 2>/dev/null

    echo -e "\n--- Files in Package ---"
    dpkg -L "$PACKAGE" 2>/dev/null | head -20

    echo -e "\n--- Dependencies ---"
    apt depends "$PACKAGE" 2>/dev/null

elif command -v yum &>/dev/null; then
    echo -e "\n--- Package Info ---"
    yum info "$PACKAGE" 2>/dev/null

    echo -e "\n--- Files in Package ---"
    rpm -ql "$PACKAGE" 2>/dev/null | head -20

    echo -e "\n--- Dependencies ---"
    yum deplist "$PACKAGE" 2>/dev/null
fi
```

### Exercise 3: Build Simple Package

```bash
# Create a simple script package using fpm

# 1. Create script
mkdir -p mytools/usr/local/bin
cat > mytools/usr/local/bin/sysinfo << 'EOF'
#!/bin/bash
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Memory: $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
EOF
chmod +x mytools/usr/local/bin/sysinfo

# 2. Build package
fpm -s dir -t deb -n sysinfo-tools -v 1.0 \
    --description "System information tools" \
    --maintainer "you@example.com" \
    -C mytools .

# 3. Install and test
sudo dpkg -i sysinfo-tools_1.0_amd64.deb
sysinfo
```

---

## Key Takeaways

1. **Know your distro** - apt for Debian/Ubuntu, yum/dnf for RHEL
2. **Always update first** - Run `apt update` or `yum check-update`
3. **Trust but verify** - Check package sources and signatures
4. **Keep systems updated** - Especially security updates
5. **Use package managers** - Avoid manual installs when possible
6. **Document custom repos** - Track what you've added
7. **Consider automation** - Ansible, Puppet for package management at scale

---

## Next Module

[Networking Fundamentals](./08-networking-fundamentals.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Understanding Package Managers
- APT Package Management (Debian/Ubuntu)
- YUM/DNF Package Management (RHEL/CentOS)
- Comparing APT and YUM/DNF

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The kernel manages processes."* |
| ✓ | *"A process is an entry in the kernel's task table with its own memory map and file-descriptor table. `fork()` copies it, `exec()` replaces the program inside it, and the parent must call `wait()` or the entry stays behind as a zombie."* |

**Trace it:** `ls -l /etc` → characters on your terminal. Name every syscall and every kernel structure between the keypress and the output.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) and the [LWN namespaces series](https://lwn.net/Articles/531114/) — the primary sources, not summaries of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#linux-networking)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
