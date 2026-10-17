# Lab 05: Shell Script Automation

## Overview

Write production-quality shell scripts for system automation. This lab covers scripting best practices, error handling, and real-world automation scenarios.

## Objectives

- Write robust shell scripts
- Implement error handling and logging
- Parse arguments and configuration
- Create reusable functions
- Build automation tools

## Prerequisites

- Lab 04 completed
- Basic shell scripting knowledge

## Time Estimate

- Guided: 3-4 hours
- Challenge: 2-3 hours

---

## Tier 1: Guided Instructions

### Exercise 1: Script Foundation

```bash
# Create scripts directory
mkdir -p ~/scripts
cd ~/scripts

# Create first script
cat > hello.sh << 'EOF'
#!/bin/bash
#
# Script: hello.sh
# Description: Hello world with best practices
# Author: DevOps Student
# Date: 2024-01-15
#

set -euo pipefail

echo "Hello, World!"
echo "Current user: $(whoami)"
echo "Current date: $(date)"
EOF

# Make executable and run
chmod +x hello.sh
./hello.sh
```

### Exercise 2: Variables and Input

```bash
cat > greet.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Default values
NAME=${1:-"Guest"}
GREETING=${2:-"Hello"}

# Display greeting
echo "$GREETING, $NAME!"

# Read user input
read -p "What's your favorite color? " color
echo "Nice! $color is a great color."

# Use environment variables
echo "Your home directory: $HOME"
echo "Your shell: $SHELL"
EOF

chmod +x greet.sh
./greet.sh
./greet.sh "John" "Welcome"
```

### Exercise 3: Conditionals

```bash
cat > check_system.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== System Check ==="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Running as root"
else
    echo "Running as regular user"
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ $DISK_USAGE -gt 90 ]]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}%"
elif [[ $DISK_USAGE -gt 70 ]]; then
    echo "NOTICE: Disk usage is ${DISK_USAGE}%"
else
    echo "OK: Disk usage is ${DISK_USAGE}%"
fi

# Check if command exists
if command -v docker &>/dev/null; then
    echo "Docker is installed"
else
    echo "Docker is not installed"
fi

# Check file existence
if [[ -f /etc/nginx/nginx.conf ]]; then
    echo "Nginx config exists"
else
    echo "Nginx config not found"
fi
EOF

chmod +x check_system.sh
./check_system.sh
```

### Exercise 4: Loops

```bash
cat > process_files.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Create test files
mkdir -p /tmp/testfiles
for i in {1..5}; do
    echo "Content of file $i" > /tmp/testfiles/file${i}.txt
done

# For loop - iterate over files
echo "=== Processing Files ==="
for file in /tmp/testfiles/*.txt; do
    echo "File: $file"
    echo "Content: $(cat "$file")"
    echo "---"
done

# While loop - read lines from file
echo "=== Reading /etc/passwd (first 5) ==="
head -5 /etc/passwd | while IFS=: read -r user pass uid gid comment home shell; do
    echo "User: $user, UID: $uid, Shell: $shell"
done

# Until loop
echo "=== Countdown ==="
count=5
until [[ $count -eq 0 ]]; do
    echo "$count..."
    ((count--))
    sleep 1
done
echo "Done!"

# Cleanup
rm -rf /tmp/testfiles
EOF

chmod +x process_files.sh
./process_files.sh
```

### Exercise 5: Functions

```bash
cat > functions_demo.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Check if file exists
file_exists() {
    local file=$1
    [[ -f "$file" ]]
}

# Get system info
get_system_info() {
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
}

# Calculate disk usage percentage
get_disk_usage() {
    local mount_point=${1:-"/"}
    df "$mount_point" | awk 'NR==2 {print $5}'
}

# Main script
log "INFO" "Script started"

log "INFO" "Checking files..."
if file_exists "/etc/passwd"; then
    log "INFO" "/etc/passwd exists"
else
    log "ERROR" "/etc/passwd not found"
fi

log "INFO" "Gathering system info..."
get_system_info

log "INFO" "Disk usage: $(get_disk_usage /)"

log "INFO" "Script completed"
EOF

chmod +x functions_demo.sh
./functions_demo.sh
```

### Exercise 6: Argument Parsing

```bash
cat > backup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Default values
SOURCE=""
DESTINATION="/backup"
COMPRESS=false
VERBOSE=false

# Usage function
usage() {
    cat << USAGE
Usage: $(basename "$0") [OPTIONS] SOURCE

Options:
    -d, --dest DIR      Destination directory (default: /backup)
    -c, --compress      Compress backup
    -v, --verbose       Verbose output
    -h, --help          Show this help

Examples:
    $(basename "$0") /var/www
    $(basename "$0") -c -d /mnt/backup /var/www
USAGE
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dest)
            DESTINATION="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            SOURCE="$1"
            shift
            ;;
    esac
done

# Validate
if [[ -z "$SOURCE" ]]; then
    echo "Error: SOURCE is required"
    usage
    exit 1
fi

# Log function
log() {
    if $VERBOSE; then
        echo "[$(date '+%H:%M:%S')] $*"
    fi
}

# Perform backup
log "Starting backup"
log "Source: $SOURCE"
log "Destination: $DESTINATION"
log "Compress: $COMPRESS"

# Create destination
mkdir -p "$DESTINATION"

# Backup
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
if $COMPRESS; then
    BACKUP_FILE="$DESTINATION/${BACKUP_NAME}.tar.gz"
    log "Creating compressed backup: $BACKUP_FILE"
    tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"
else
    BACKUP_DIR="$DESTINATION/${BACKUP_NAME}"
    log "Creating backup: $BACKUP_DIR"
    cp -r "$SOURCE" "$BACKUP_DIR"
fi

echo "Backup complete!"
EOF

chmod +x backup.sh
# Test
mkdir -p /tmp/testdata
echo "test" > /tmp/testdata/file.txt
./backup.sh -v -c -d /tmp/backups /tmp/testdata
ls -la /tmp/backups/
```

### Exercise 7: Error Handling

```bash
cat > robust_script.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Error handling
trap 'echo "Error on line $LINENO. Exit code: $?"' ERR

# Cleanup on exit
cleanup() {
    local exit_code=$?
    echo "Cleaning up..."
    [[ -f /tmp/script.lock ]] && rm -f /tmp/script.lock
    exit $exit_code
}
trap cleanup EXIT

# Check if already running
if [[ -f /tmp/script.lock ]]; then
    echo "Script is already running"
    exit 1
fi
touch /tmp/script.lock

# Die function
die() {
    echo "FATAL: $1" >&2
    exit "${2:-1}"
}

# Safe command execution
safe_exec() {
    if ! "$@"; then
        die "Command failed: $*"
    fi
}

# Retry function
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying in $delay seconds..."
        sleep $delay
        ((attempt++))
    done
    return 1
}

# Main script
echo "Running robust script..."

# Example: retry a command
# retry 3 2 curl -s http://example.com

# Example: safe execution
safe_exec echo "This will work"

# This would trigger error handling:
# safe_exec false

echo "Script completed successfully"
EOF

chmod +x robust_script.sh
./robust_script.sh
```

### Exercise 8: Complete Automation Script

```bash
cat > deploy.sh << 'EOF'
#!/bin/bash
#
# deploy.sh - Application deployment script
# Usage: ./deploy.sh [-e environment] [-v]
#

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/deploy.log"

# Default values
ENVIRONMENT="development"
VERBOSE=false
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Logging
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)  color=$GREEN ;;
        WARN)  color=$YELLOW ;;
        ERROR) color=$RED ;;
        *)     color=$NC ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}" | tee -a "$LOG_FILE"
}

# Usage
usage() {
    cat << EOF
Deployment Script

Usage: $(basename "$0") [OPTIONS]

Options:
    -e, --environment ENV   Environment (development|staging|production)
    -v, --verbose           Verbose output
    -n, --dry-run           Show what would be done
    -h, --help              Show this help

Examples:
    $(basename "$0") -e production
    $(basename "$0") -e staging -v --dry-run
EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    case $ENVIRONMENT in
        development|staging|production)
            log INFO "Environment: $ENVIRONMENT"
            ;;
        *)
            log ERROR "Invalid environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Pre-deploy checks
pre_deploy_checks() {
    log INFO "Running pre-deploy checks..."

    # Check required tools
    for cmd in git curl; do
        if ! command -v $cmd &>/dev/null; then
            log ERROR "Required command not found: $cmd"
            return 1
        fi
    done

    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ $disk_usage -gt 90 ]]; then
        log ERROR "Disk usage too high: ${disk_usage}%"
        return 1
    fi

    log INFO "Pre-deploy checks passed"
}

# Deploy application
deploy() {
    log INFO "Starting deployment..."

    if $DRY_RUN; then
        log WARN "DRY RUN - No actual changes will be made"
    fi

    # Simulate deployment steps
    local steps=(
        "Pulling latest code"
        "Installing dependencies"
        "Running migrations"
        "Restarting services"
        "Running health checks"
    )

    for step in "${steps[@]}"; do
        log INFO "Step: $step"
        if ! $DRY_RUN; then
            sleep 1  # Simulate work
        fi
    done

    log INFO "Deployment complete!"
}

# Post-deploy
post_deploy() {
    log INFO "Running post-deploy tasks..."
    log INFO "Sending notifications..."
    log INFO "Post-deploy complete"
}

# Main
main() {
    parse_args "$@"

    log INFO "=== Deployment Started ==="
    log INFO "Script: $0"
    log INFO "Environment: $ENVIRONMENT"

    validate_environment
    pre_deploy_checks
    deploy
    post_deploy

    log INFO "=== Deployment Finished ==="
}

main "$@"
EOF

chmod +x deploy.sh
./deploy.sh -e staging -v --dry-run
```

---

## Tier 2: Semi-Guided Exercises

### Exercise A: Log Analyzer

Create a script that:
1. Parses Apache/Nginx access logs
2. Extracts top IPs, URLs, status codes
3. Generates HTML report
4. Runs via cron

### Exercise B: System Maintenance

Create a script that:
1. Updates system packages
2. Cleans old logs and temp files
3. Checks disk space
4. Sends email report

### Exercise C: Service Monitor

Create a script that:
1. Monitors multiple services
2. Restarts if not running
3. Logs all actions
4. Alerts on repeated failures

---

## Tier 3: Challenge

Create a complete automation toolkit with:
1. Backup manager
2. User provisioning
3. Log rotation
4. Health monitoring
5. Deployment automation

---

## Key Takeaways

1. **Use set -euo pipefail** - Catch errors early
2. **Functions improve readability** - Modular code
3. **Parse arguments properly** - Flexible scripts
4. **Handle errors gracefully** - Traps and cleanup
5. **Log everything** - Debugging aid

---

## Next Lab

[Lab 06: Log Analysis](lab-06-log-analysis-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Script Foundation
- Variables and Input
- Conditionals
- Loops

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
