# Advanced Shell Scripting

## Overview

Building on shell scripting basics, this module covers advanced topics including text processing, regular expressions, advanced I/O, error handling patterns, and production-ready script development.

## Learning Objectives

By the end of this module, you will be able to:
- Process text with grep, sed, and awk
- Use regular expressions effectively
- Implement advanced I/O patterns
- Create robust error handling
- Write production-quality scripts

---

## Text Processing Tools

### grep - Pattern Searching

```bash
# Basic grep
grep "pattern" file.txt
grep "error" /var/log/syslog

# Common options
grep -i "pattern" file        # Case insensitive
grep -v "pattern" file        # Invert match
grep -n "pattern" file        # Show line numbers
grep -c "pattern" file        # Count matches
grep -l "pattern" *.txt       # List files with matches
grep -r "pattern" directory/  # Recursive
grep -w "word" file           # Match whole word
grep -A 3 "pattern" file      # 3 lines after
grep -B 3 "pattern" file      # 3 lines before
grep -C 3 "pattern" file      # 3 lines context

# Multiple patterns
grep -E "pattern1|pattern2" file
grep -e "pattern1" -e "pattern2" file

# Regular expressions
grep -E "[0-9]{3}-[0-9]{4}" file    # Phone numbers
grep -E "^[A-Z]" file               # Lines starting with capital
grep -E "error|warning|critical" log

# Practical examples
grep -r "TODO" --include="*.py" .    # Find TODOs in Python files
grep -v "^#" config.conf | grep -v "^$"  # Remove comments and empty lines
ps aux | grep -v grep | grep nginx   # Find nginx without grep itself
```

### sed - Stream Editor

```bash
# Basic substitution
sed 's/old/new/' file          # Replace first occurrence
sed 's/old/new/g' file         # Replace all occurrences
sed 's/old/new/gi' file        # Case insensitive

# In-place editing
sed -i 's/old/new/g' file      # Edit file directly
sed -i.bak 's/old/new/g' file  # Create backup

# Address ranges
sed '5s/old/new/' file         # Only line 5
sed '1,10s/old/new/' file      # Lines 1-10
sed '/start/,/end/s/old/new/' file  # Between patterns

# Delete lines
sed '/pattern/d' file          # Delete matching lines
sed '1d' file                  # Delete first line
sed '$d' file                  # Delete last line
sed '1,5d' file                # Delete lines 1-5

# Insert and append
sed '3i\New line' file         # Insert before line 3
sed '3a\New line' file         # Append after line 3
sed '/pattern/a\New line' file # Append after pattern

# Multiple commands
sed -e 's/one/1/g' -e 's/two/2/g' file
sed 's/one/1/g; s/two/2/g' file

# Practical examples
sed 's/\r$//' file             # Remove Windows line endings
sed '/^$/d' file               # Remove empty lines
sed 's/^/    /' file           # Add indent
sed 's/[[:space:]]*$//' file   # Remove trailing whitespace
sed -n '10,20p' file           # Print lines 10-20
```

### awk - Pattern Processing

```bash
# Basic structure: awk 'pattern { action }' file

# Print fields
awk '{print $1}' file          # First field
awk '{print $1, $3}' file      # First and third fields
awk '{print $NF}' file         # Last field
awk '{print NR, $0}' file      # Line number and line

# Field separator
awk -F: '{print $1}' /etc/passwd  # Colon separator
awk -F',' '{print $2}' file.csv   # Comma separator

# Patterns
awk '/pattern/ {print}' file      # Lines matching pattern
awk '$3 > 100 {print}' file       # Third field > 100
awk 'NR==5 {print}' file          # Line 5
awk 'NR>=5 && NR<=10' file        # Lines 5-10

# Built-in variables
awk '{print NR}' file          # Line number
awk '{print NF}' file          # Number of fields
awk 'END {print NR}' file      # Total lines
awk '{sum+=$1} END {print sum}' file  # Sum first field

# BEGIN and END blocks
awk 'BEGIN {print "Header"} {print} END {print "Footer"}' file

# Practical examples
# Calculate average
awk '{sum+=$1; count++} END {print sum/count}' numbers.txt

# Print users with specific shell
awk -F: '$7 == "/bin/bash" {print $1}' /etc/passwd

# Format output
awk '{printf "%-20s %10d\n", $1, $2}' file

# Sum disk usage
df -h | awk 'NR>1 {print $5}' | tr -d '%' | awk '{sum+=$1} END {print sum}'

# Extract Apache access log IPs
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head
```

---

## Regular Expressions

### Basic Patterns

```
Character Classes:
.       Any single character
[abc]   Any of a, b, or c
[^abc]  Not a, b, or c
[a-z]   Range a to z
[0-9]   Any digit

Anchors:
^       Start of line
$       End of line
\b      Word boundary

Quantifiers:
*       Zero or more
+       One or more (extended regex)
?       Zero or one (extended regex)
{n}     Exactly n
{n,}    n or more
{n,m}   Between n and m
```

### Extended Regular Expressions

```bash
# Use -E for extended regex (or egrep)
grep -E 'pattern' file

# Examples
grep -E 'colou?r' file           # color or colour
grep -E '[0-9]{3}-[0-9]{4}' file # Phone numbers
grep -E '^[A-Z][a-z]+' file      # Capitalized words
grep -E '\b\w{5}\b' file         # 5-letter words

# Email pattern
grep -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' file

# IP address pattern
grep -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' file

# URL pattern
grep -E 'https?://[a-zA-Z0-9./?=&_-]+' file
```

### Using Regex in Bash

```bash
# Pattern matching with [[]]
if [[ $string =~ ^[0-9]+$ ]]; then
    echo "String is a number"
fi

# Capture groups
if [[ $email =~ ^([^@]+)@(.+)$ ]]; then
    user="${BASH_REMATCH[1]}"
    domain="${BASH_REMATCH[2]}"
    echo "User: $user, Domain: $domain"
fi

# Validate input
validate_date() {
    if [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    fi
    return 1
}
```

---

## Advanced I/O

### File Descriptors

```bash
# Standard file descriptors
# 0 = stdin
# 1 = stdout
# 2 = stderr

# Redirect stderr to file
command 2> errors.log

# Redirect both stdout and stderr
command > output.log 2>&1
command &> output.log  # Bash shorthand

# Redirect stderr to stdout
command 2>&1 | grep "error"

# Discard output
command > /dev/null 2>&1
```

### Custom File Descriptors

```bash
# Open file for reading
exec 3< input.txt
while read -r line <&3; do
    echo "$line"
done
exec 3<&-  # Close

# Open file for writing
exec 4> output.txt
echo "Hello" >&4
echo "World" >&4
exec 4>&-  # Close

# Open file for read/write
exec 5<> file.txt
read line <&5
echo "New content" >&5
exec 5>&-

# Practical example: Logging
exec 3>&1  # Save stdout
exec 4>&2  # Save stderr
exec 1>output.log
exec 2>error.log

# Commands here write to files
echo "This goes to output.log"
echo "This goes to error.log" >&2

# Restore
exec 1>&3 3>&-
exec 2>&4 4>&-
```

### Process Substitution

```bash
# Treat command output as file
diff <(ls dir1) <(ls dir2)

# Multiple inputs
paste <(cut -f1 file1) <(cut -f2 file2)

# While loop without subshell
while read -r line; do
    # Process line
    count=$((count + 1))
done < <(cat file.txt)
echo "Count: $count"  # Variable survives

# Compare sorted outputs
comm <(sort file1) <(sort file2)
```

### Named Pipes (FIFOs)

```bash
# Create named pipe
mkfifo /tmp/mypipe

# Producer (in one terminal)
echo "Hello" > /tmp/mypipe

# Consumer (in another terminal)
cat < /tmp/mypipe

# Cleanup
rm /tmp/mypipe

# Use case: Inter-process communication
mkfifo /tmp/log_pipe
tail -f /tmp/log_pipe | grep --line-buffered "ERROR" > errors.log &
echo "INFO: Starting" > /tmp/log_pipe
echo "ERROR: Something failed" > /tmp/log_pipe
```

---

## Advanced Error Handling

### Error Handling Patterns

```bash
#!/bin/bash
set -euo pipefail

# Die function
die() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Try-catch pattern
try() {
    [[ $- = *e* ]]; SAVED_OPT=$?
    set +e
}

catch() {
    export EXIT_CODE=$?
    (( SAVED_OPT )) && set +e
    return $EXIT_CODE
}

# Usage
try
(
    # Commands that might fail
    risky_command
)
catch || {
    echo "Command failed with exit code: $EXIT_CODE"
}

# Retry pattern
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying in $delay seconds..."
        sleep $delay
        ((attempt++))
    done

    return 1
}

# Usage
retry 3 5 curl -s http://example.com
```

### Cleanup with Traps

```bash
#!/bin/bash

# Temporary file management
TEMP_DIR=""
TEMP_FILES=()

cleanup() {
    local exit_code=$?

    # Remove temporary files
    for file in "${TEMP_FILES[@]}"; do
        [ -f "$file" ] && rm -f "$file"
    done

    # Remove temporary directory
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"

    exit $exit_code
}

trap cleanup EXIT INT TERM

# Create temp directory
TEMP_DIR=$(mktemp -d)

# Create temp file
create_temp_file() {
    local file=$(mktemp)
    TEMP_FILES+=("$file")
    echo "$file"
}

# Usage
temp=$(create_temp_file)
echo "data" > "$temp"
# Cleanup happens automatically on exit
```

### Error Logging

```bash
#!/bin/bash

# Log levels
LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FILE=${LOG_FILE:-/var/log/script.log}

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check log level
    if [ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]; then
        echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    fi
}

# Usage
log DEBUG "Detailed debugging info"
log INFO "Script started"
log WARN "Something looks wrong"
log ERROR "Something failed"
```

---

## Parallel Processing

### Background Jobs

```bash
# Run commands in parallel
command1 &
command2 &
command3 &
wait  # Wait for all

# Capture exit codes
pids=()
command1 & pids+=($!)
command2 & pids+=($!)
command3 & pids+=($!)

for pid in "${pids[@]}"; do
    wait "$pid"
    echo "PID $pid exited with status $?"
done
```

### xargs for Parallel Execution

```bash
# Process files in parallel
find . -name "*.txt" | xargs -P 4 -I {} gzip {}

# Maximum parallelism
find . -type f | xargs -P 0 command

# Null-separated input (for filenames with spaces)
find . -name "*.log" -print0 | xargs -0 -P 4 rm

# Example: Parallel downloads
cat urls.txt | xargs -P 10 -I {} curl -O {}
```

### GNU Parallel

```bash
# Install
sudo apt install parallel

# Basic usage
parallel gzip ::: *.txt

# From file
parallel -a hosts.txt ping -c 1

# With arguments
parallel "echo Processing {}; sleep 1" ::: {1..10}

# Control parallelism
parallel -j 4 command ::: inputs

# Show progress
parallel --progress command ::: inputs

# Practical: Check hosts
cat hosts.txt | parallel -j 20 "ping -c 1 {} && echo {} is up"
```

---

## Configuration Management

### Reading Configuration Files

```bash
# Source shell config file
source /etc/myapp/config.sh

# Parse INI-style config
parse_ini() {
    local file=$1
    local section=""

    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        # Handle sections
        if [[ "$key" =~ ^\[.*\]$ ]]; then
            section="${key:1:-1}_"
            continue
        fi

        # Clean whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Export variable
        export "${section}${key}=${value}"
    done < "$file"
}

# Usage
parse_ini config.ini
echo "Database host: $database_host"
```

### Environment Files

```bash
# .env file format
# DATABASE_HOST=localhost
# DATABASE_PORT=5432

# Load .env file
load_env() {
    local file=${1:-.env}

    if [ -f "$file" ]; then
        set -a  # Auto-export
        source "$file"
        set +a
    fi
}

# Safe loading (no command execution)
safe_load_env() {
    local file=${1:-.env}

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        # Remove quotes
        value="${value%\"}"
        value="${value#\"}"

        export "$key=$value"
    done < "$file"
}
```

---

## Script Organization

### Modular Scripts

```bash
# lib/logging.sh
log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# lib/utils.sh
die() { log_error "$1"; exit "${2:-1}"; }
require_root() { [[ $EUID -eq 0 ]] || die "Must run as root"; }

# main.sh
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Main logic
main() {
    require_root
    log_info "Starting script"
    # ...
}

main "$@"
```

### Plugin Architecture

```bash
#!/bin/bash

PLUGIN_DIR="${SCRIPT_DIR}/plugins"

# Load all plugins
load_plugins() {
    for plugin in "$PLUGIN_DIR"/*.sh; do
        [ -f "$plugin" ] && source "$plugin"
    done
}

# Run plugin hooks
run_hook() {
    local hook_name=$1
    shift

    # Find and run all functions matching hook name
    for func in $(declare -F | grep "^declare -f ${hook_name}_" | cut -d' ' -f3); do
        $func "$@"
    done
}

# Plugin example (plugins/backup.sh):
# pre_deploy_backup() {
#     echo "Creating backup before deploy..."
# }

# Usage
load_plugins
run_hook "pre_deploy"
# Actual deploy logic
run_hook "post_deploy"
```

---

## Testing Scripts

### Basic Testing

```bash
#!/bin/bash
# test_functions.sh

source ./functions.sh

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

assert_equals() {
    local expected=$1
    local actual=$2
    local message=${3:-"Assertion failed"}

    ((TESTS_RUN++))

    if [ "$expected" = "$actual" ]; then
        ((TESTS_PASSED++))
        echo "✓ PASS: $message"
    else
        echo "✗ FAIL: $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
    fi
}

assert_true() {
    local condition=$1
    local message=${2:-"Assertion failed"}

    ((TESTS_RUN++))

    if eval "$condition"; then
        ((TESTS_PASSED++))
        echo "✓ PASS: $message"
    else
        echo "✗ FAIL: $message"
    fi
}

# Tests
test_add() {
    result=$(add 2 3)
    assert_equals "5" "$result" "add(2,3) should equal 5"
}

test_is_number() {
    assert_true 'is_number 42' "42 should be a number"
    assert_true '! is_number abc' "abc should not be a number"
}

# Run tests
test_add
test_is_number

# Summary
echo ""
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"

[ $TESTS_RUN -eq $TESTS_PASSED ]
```

### Using BATS

```bash
# Install bats
git clone https://github.com/bats-core/bats-core.git
cd bats-core && sudo ./install.sh /usr/local

# test/example.bats
#!/usr/bin/env bats

setup() {
    source ./functions.sh
}

@test "add returns correct sum" {
    result=$(add 2 3)
    [ "$result" -eq 5 ]
}

@test "is_number returns true for numbers" {
    run is_number 42
    [ "$status" -eq 0 ]
}

@test "is_number returns false for strings" {
    run is_number abc
    [ "$status" -eq 1 ]
}

# Run tests
bats test/*.bats
```

---

## Practical Exercises

### Exercise 1: Log Analyzer

```bash
#!/bin/bash
# Analyze Apache access logs

LOG_FILE=${1:-/var/log/apache2/access.log}

echo "=== Apache Log Analysis ==="
echo ""

echo "Top 10 IPs:"
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10
echo ""

echo "Top 10 URLs:"
awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10
echo ""

echo "HTTP Status Codes:"
awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn
echo ""

echo "Requests per hour:"
awk -F'[][]' '{print $2}' "$LOG_FILE" | \
    awk -F: '{print $1":"$2}' | sort | uniq -c
```

### Exercise 2: Deployment Script

```bash
#!/bin/bash
set -euo pipefail

# Configuration
APP_DIR="/var/www/myapp"
BACKUP_DIR="/var/backups/myapp"
GIT_REPO="git@github.com:user/myapp.git"
BRANCH="main"

# Functions
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $1"; exit 1; }

backup() {
    log "Creating backup..."
    local backup_file="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$backup_file" -C "$APP_DIR" . || die "Backup failed"
    log "Backup created: $backup_file"
}

deploy() {
    log "Deploying application..."
    cd "$APP_DIR"
    git fetch origin || die "Git fetch failed"
    git checkout "$BRANCH" || die "Checkout failed"
    git pull origin "$BRANCH" || die "Git pull failed"
}

post_deploy() {
    log "Running post-deploy tasks..."
    cd "$APP_DIR"
    [ -f "package.json" ] && npm install
    [ -f "requirements.txt" ] && pip install -r requirements.txt
    systemctl restart myapp || die "Service restart failed"
}

# Main
main() {
    log "Starting deployment..."
    backup
    deploy
    post_deploy
    log "Deployment complete!"
}

main "$@"
```

### Exercise 3: System Health Monitor

```bash
#!/bin/bash
# System health check script

THRESHOLDS=(
    "cpu:80"
    "memory:90"
    "disk:85"
)

check_cpu() {
    local usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    echo "$usage"
}

check_memory() {
    local usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    echo "$usage"
}

check_disk() {
    local usage=$(df / | awk 'NR==2 {print int($5)}')
    echo "$usage"
}

# Check all metrics
check_health() {
    local alerts=0

    for threshold in "${THRESHOLDS[@]}"; do
        local metric="${threshold%:*}"
        local limit="${threshold#*:}"
        local current=$(check_$metric)

        if [ "$current" -gt "$limit" ]; then
            echo "ALERT: $metric at $current% (threshold: $limit%)"
            ((alerts++))
        else
            echo "OK: $metric at $current%"
        fi
    done

    return $alerts
}

check_health
exit $?
```

---

## Key Takeaways

1. **Master text processing** - grep, sed, awk are essential tools
2. **Use regex wisely** - Powerful but can be complex
3. **Handle errors properly** - set -euo pipefail and traps
4. **Parallelize when possible** - xargs -P, GNU parallel
5. **Write modular code** - Source libraries, use functions
6. **Test your scripts** - Even simple tests catch bugs
7. **Document thoroughly** - Comments, usage messages, examples

---

## Next Module

[Package Management](./07-package-management.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Text Processing Tools
- Regular Expressions
- Advanced I/O
- Advanced Error Handling

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
