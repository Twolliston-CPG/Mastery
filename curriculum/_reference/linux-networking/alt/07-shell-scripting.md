# Module 7: Shell Scripting

## Introduction

Shell scripting is the gateway to automation in DevOps. A well-written script can save hours of manual work and ensure consistency. This module teaches you to write robust, maintainable shell scripts.

## Learning Objectives

After completing this module, you will be able to:
- Write shell scripts from scratch
- Use variables, conditionals, and loops
- Handle command-line arguments
- Implement error handling
- Write reusable functions
- Follow shell scripting best practices

## Shell Script Basics

### Creating Your First Script

```bash
#!/bin/bash
# My first shell script
# Author: Your Name
# Date: 2024-01-01

echo "Hello, DevOps!"
echo "Today is $(date)"
echo "You are logged in as: $USER"
```

Save as `hello.sh` and run:

```bash
chmod +x hello.sh
./hello.sh
```

### Script Structure

```bash
#!/bin/bash
#
# Script Name: backup.sh
# Description: Backup important files
# Author: DevOps Team
# Version: 1.0
# Usage: ./backup.sh <source> <destination>
#
#===============================================

# Exit on error, undefined variables, pipe failures
set -euo pipefail

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/backup.log"

# Functions go here
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Main script logic
main() {
    log "Starting backup..."
    # ... backup logic ...
    log "Backup complete"
}

# Run main function
main "$@"
```

### The Shebang

```bash
#!/bin/bash           # Use bash explicitly
#!/usr/bin/env bash   # Find bash in PATH (more portable)
#!/bin/sh             # POSIX shell (most portable)
#!/usr/bin/env python # Can be used for other languages
```

## Variables

### Variable Basics

```bash
# Assignment (no spaces around =)
name="Alice"
count=42
path="/var/log"

# Usage (dollar sign)
echo "Hello, $name"
echo "Count is ${count}"

# Braces for clarity
echo "${name}_backup"     # Correct: Alice_backup
echo "$name_backup"       # Wrong: looks for $name_backup

# Command substitution
today=$(date +%Y-%m-%d)
files=$(ls -1 | wc -l)

# Arithmetic
count=$((count + 1))
result=$((5 * 10))
```

### Special Variables

```bash
$0          # Script name
$1, $2...   # Positional arguments
$#          # Number of arguments
$@          # All arguments (as separate strings)
$*          # All arguments (as single string)
$?          # Exit status of last command
$$          # Current process ID
$!          # PID of last background process
```

### Variable Expansion

```bash
# Default values
echo "${name:-default}"      # Use default if unset
echo "${name:=default}"      # Set and use default if unset
echo "${name:?error msg}"    # Error if unset
echo "${name:+alternate}"    # Use alternate if set

# String operations
path="/home/user/documents/file.txt"
echo "${path##*/}"           # file.txt (remove longest prefix)
echo "${path%/*}"            # /home/user/documents (remove shortest suffix)
echo "${path%.txt}"          # /home/user/documents/file (remove .txt)
echo "${#path}"              # Length of string

# Substring
string="Hello World"
echo "${string:0:5}"         # Hello (start:length)
echo "${string:6}"           # World (from position 6)

# Replacement
echo "${string/World/DevOps}"  # Hello DevOps (first match)
echo "${string//o/O}"          # HellO WOrld (all matches)
```

## Conditionals

### if Statements

```bash
# Basic if
if [ condition ]; then
    commands
fi

# if-else
if [ condition ]; then
    commands
else
    other_commands
fi

# if-elif-else
if [ condition1 ]; then
    commands1
elif [ condition2 ]; then
    commands2
else
    default_commands
fi
```

### Test Conditions

```bash
# String tests
[ -z "$var" ]        # True if empty
[ -n "$var" ]        # True if not empty
[ "$a" = "$b" ]      # String equality
[ "$a" != "$b" ]     # String inequality

# Numeric tests
[ "$a" -eq "$b" ]    # Equal
[ "$a" -ne "$b" ]    # Not equal
[ "$a" -lt "$b" ]    # Less than
[ "$a" -le "$b" ]    # Less than or equal
[ "$a" -gt "$b" ]    # Greater than
[ "$a" -ge "$b" ]    # Greater than or equal

# File tests
[ -e "$file" ]       # Exists
[ -f "$file" ]       # Is a regular file
[ -d "$path" ]       # Is a directory
[ -r "$file" ]       # Is readable
[ -w "$file" ]       # Is writable
[ -x "$file" ]       # Is executable
[ -s "$file" ]       # Has size > 0
[ -L "$file" ]       # Is symbolic link

# Logical operators
[ condition1 ] && [ condition2 ]    # AND
[ condition1 ] || [ condition2 ]    # OR
[ ! condition ]                     # NOT
```

### Modern Test Syntax

```bash
# Double brackets (bash extension)
[[ $string == pattern* ]]    # Pattern matching
[[ $string =~ regex ]]       # Regex matching
[[ -z $var ]]                # No quotes needed

# Example: check if string contains substring
if [[ "$text" == *"error"* ]]; then
    echo "Found error"
fi

# Example: regex match
if [[ "$email" =~ ^[A-Za-z0-9]+@[A-Za-z0-9]+\.[A-Za-z]+$ ]]; then
    echo "Valid email"
fi
```

### Case Statements

```bash
case "$option" in
    start)
        echo "Starting service..."
        ;;
    stop)
        echo "Stopping service..."
        ;;
    restart)
        echo "Restarting service..."
        ;;
    status)
        echo "Service status..."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
```

## Loops

### For Loops

```bash
# Iterate over list
for item in apple banana cherry; do
    echo "Fruit: $item"
done

# Iterate over files
for file in *.txt; do
    echo "Processing: $file"
done

# Iterate over command output
for user in $(cat /etc/passwd | cut -d: -f1); do
    echo "User: $user"
done

# C-style for loop
for ((i=0; i<10; i++)); do
    echo "Number: $i"
done

# Iterate over array
fruits=("apple" "banana" "cherry")
for fruit in "${fruits[@]}"; do
    echo "$fruit"
done
```

### While Loops

```bash
# Basic while
count=0
while [ $count -lt 5 ]; do
    echo "Count: $count"
    ((count++))
done

# Read file line by line
while IFS= read -r line; do
    echo "Line: $line"
done < file.txt

# Infinite loop with break
while true; do
    read -p "Continue? (y/n) " answer
    if [ "$answer" = "n" ]; then
        break
    fi
done

# Read from command output
while read -r pid name; do
    echo "PID: $pid, Name: $name"
done < <(ps aux | awk '{print $2, $11}')
```

### Until Loops

```bash
# Until condition is true
count=0
until [ $count -ge 5 ]; do
    echo "Count: $count"
    ((count++))
done
```

### Loop Control

```bash
# break - exit loop
for i in {1..10}; do
    if [ $i -eq 5 ]; then
        break
    fi
    echo $i
done

# continue - skip iteration
for i in {1..10}; do
    if [ $((i % 2)) -eq 0 ]; then
        continue
    fi
    echo $i  # Only odd numbers
done
```

## Functions

### Function Definition

```bash
# Method 1
function greet {
    echo "Hello, $1!"
}

# Method 2 (preferred, more portable)
greet() {
    echo "Hello, $1!"
}

# Call function
greet "Alice"
greet "Bob"
```

### Function Arguments and Returns

```bash
# Function with multiple arguments
add_numbers() {
    local num1=$1
    local num2=$2
    echo $((num1 + num2))
}

result=$(add_numbers 5 3)
echo "Result: $result"

# Return values (0 = success, non-zero = failure)
check_file() {
    local file=$1
    if [ -f "$file" ]; then
        return 0
    else
        return 1
    fi
}

if check_file "/etc/passwd"; then
    echo "File exists"
fi

# Local variables
my_function() {
    local local_var="I'm local"
    global_var="I'm global"
    echo "$local_var"
}
```

### Useful Function Patterns

```bash
# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log INFO "Script started"
log ERROR "Something went wrong"

# Die function (error and exit)
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Usage check
[ -z "$1" ] && die "Usage: $0 <filename>"

# Retry function
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local cmd="$@"

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if $cmd; then
            return 0
        fi
        echo "Attempt $attempt failed. Retrying in ${delay}s..."
        sleep $delay
        ((attempt++))
    done

    return 1
}

retry 3 5 curl -f http://example.com
```

## Error Handling

### Exit Codes

```bash
# Check exit code
if command; then
    echo "Command succeeded"
else
    echo "Command failed with code: $?"
fi

# Set exit code
exit 0    # Success
exit 1    # General error
exit 2    # Misuse of command

# Common exit codes
# 0   - Success
# 1   - General error
# 2   - Misuse of shell command
# 126 - Command not executable
# 127 - Command not found
# 128+N - Fatal error signal N
```

### Set Options for Safety

```bash
#!/bin/bash

# Recommended for all scripts
set -e          # Exit on error
set -u          # Error on undefined variables
set -o pipefail # Catch errors in pipes

# Combined
set -euo pipefail

# Debug mode
set -x          # Print commands as executed

# Temporarily disable
set +e
command_that_might_fail
set -e
```

### Trap for Cleanup

```bash
#!/bin/bash

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f "$TEMP_FILE"
    # Other cleanup tasks
}

# Set trap for various signals
trap cleanup EXIT        # Run on exit
trap cleanup ERR         # Run on error
trap cleanup SIGINT      # Run on Ctrl+C
trap cleanup SIGTERM     # Run on termination

# Create temp file
TEMP_FILE=$(mktemp)

# Your script logic here
# cleanup will run automatically on exit
```

## Input and Arguments

### Command-Line Arguments

```bash
#!/bin/bash

# Simple argument handling
if [ $# -lt 2 ]; then
    echo "Usage: $0 <source> <destination>"
    exit 1
fi

source=$1
destination=$2

echo "Copying from $source to $destination"
```

### Using getopts

```bash
#!/bin/bash

usage() {
    echo "Usage: $0 [-v] [-f file] [-n count] [-h]"
    echo "  -v        Verbose mode"
    echo "  -f FILE   Input file"
    echo "  -n COUNT  Number of iterations"
    echo "  -h        Show this help"
    exit 1
}

# Default values
verbose=false
file=""
count=1

# Parse options
while getopts "vf:n:h" opt; do
    case $opt in
        v)
            verbose=true
            ;;
        f)
            file=$OPTARG
            ;;
        n)
            count=$OPTARG
            ;;
        h)
            usage
            ;;
        \?)
            usage
            ;;
    esac
done

# Shift past options to get positional arguments
shift $((OPTIND-1))

# Use the options
[ "$verbose" = true ] && echo "Verbose mode enabled"
[ -n "$file" ] && echo "File: $file"
echo "Count: $count"
echo "Remaining arguments: $@"
```

### Reading User Input

```bash
# Simple read
read -p "Enter your name: " name
echo "Hello, $name"

# Read with timeout
read -t 5 -p "Enter value (5s timeout): " value

# Read silently (passwords)
read -s -p "Enter password: " password
echo

# Read with default
read -p "Enter port [8080]: " port
port=${port:-8080}
```

## Practical Examples

### Backup Script

```bash
#!/bin/bash
set -euo pipefail

# Configuration
BACKUP_DIR="/backups"
SOURCE_DIRS="/etc /home /var/www"
RETENTION_DAYS=30

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/backup_${timestamp}.tar.gz"

    log "Creating backup: $backup_file"
    tar -czf "$backup_file" $SOURCE_DIRS 2>/dev/null || true
    log "Backup created: $(du -h "$backup_file" | cut -f1)"
}

# Clean old backups
cleanup_old() {
    log "Removing backups older than $RETENTION_DAYS days"
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete
}

# Main
main() {
    mkdir -p "$BACKUP_DIR"
    create_backup
    cleanup_old
    log "Backup complete"
}

main
```

### Service Health Check

```bash
#!/bin/bash
set -euo pipefail

SERVICES=("nginx" "postgresql" "redis")
ALERT_EMAIL="admin@example.com"

check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        echo "✓ $service is running"
        return 0
    else
        echo "✗ $service is NOT running"
        return 1
    fi
}

main() {
    local failed=()

    for service in "${SERVICES[@]}"; do
        if ! check_service "$service"; then
            failed+=("$service")
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        echo "ALERT: Services down: ${failed[*]}"
        # Send alert email
        exit 1
    fi

    echo "All services healthy"
}

main
```

## Best Practices

```yaml
shell_scripting_best_practices:
  always:
    - Use shebang (#!/bin/bash)
    - Use set -euo pipefail
    - Quote variables ("$var")
    - Use meaningful variable names
    - Add comments and documentation
    - Implement proper error handling
    - Use functions for reusability
    - Validate inputs

  avoid:
    - Unquoted variables
    - Using eval
    - Hardcoding paths
    - Ignoring exit codes
    - Overly complex one-liners
    - Parsing ls output

  testing:
    - Use shellcheck for linting
    - Test with different inputs
    - Test error conditions
    - Test in clean environment
```

## Summary

Shell scripting is essential for DevOps automation:

1. **Variables** - Store and manipulate data
2. **Conditionals** - Make decisions
3. **Loops** - Repeat operations
4. **Functions** - Organize reusable code
5. **Error handling** - Make scripts robust

## Knowledge Check

1. What does `set -euo pipefail` do?
2. How do you read command-line arguments?
3. What's the difference between `$@` and `$*`?
4. How do you define a function in bash?
5. What does `trap` do?

## Next Module

Continue to [Module 8: Networking Fundamentals](./08-networking-fundamentals.md) to learn networking concepts.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Shell Script Basics
- Variables
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
