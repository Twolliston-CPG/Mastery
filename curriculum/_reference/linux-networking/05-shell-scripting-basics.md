# Shell Scripting Basics

## Overview

Shell scripting is the foundation of automation in Linux/Unix environments. This module covers Bash scripting fundamentals including variables, control structures, functions, and best practices for writing maintainable scripts.

## Learning Objectives

By the end of this module, you will be able to:
- Write and execute shell scripts
- Use variables and command substitution
- Implement control flow (conditionals, loops)
- Create and use functions
- Handle user input and arguments
- Apply debugging techniques

---

## Getting Started

### Your First Script

```bash
#!/bin/bash
# hello.sh - My first script

echo "Hello, World!"
```

```bash
# Make it executable
chmod +x hello.sh

# Run it
./hello.sh
# or
bash hello.sh
```

### The Shebang

```bash
#!/bin/bash           # Use Bash
#!/bin/sh             # Use POSIX shell
#!/usr/bin/env bash   # Find bash in PATH (more portable)
#!/usr/bin/env python # Works for any interpreter

# The shebang MUST be the first line
# No spaces before #!
```

### Script Structure

```bash
#!/bin/bash
#
# Script Name: backup.sh
# Description: Backup important files
# Author: Your Name
# Date: 2024-01-15
# Version: 1.0
#

# Exit on error
set -e

# Variables
BACKUP_DIR="/backup"
SOURCE_DIR="/var/www"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Main logic
log "Starting backup..."
# ... backup commands ...
log "Backup complete!"
```

---

## Variables

### Variable Basics

```bash
# Assign variables (no spaces around =)
name="John"
count=10
file_path="/var/log/syslog"

# Use variables
echo "Hello, $name"
echo "Hello, ${name}"  # Preferred for clarity

# Read-only variables
readonly PI=3.14159
PI=3.14  # Error: cannot modify readonly variable

# Unset variables
unset name
```

### Variable Types

```bash
# Strings
greeting="Hello, World"

# Numbers (integers only in pure bash)
count=42
result=$((count + 10))  # Arithmetic

# Arrays
fruits=("apple" "banana" "cherry")
echo ${fruits[0]}        # First element
echo ${fruits[@]}        # All elements
echo ${#fruits[@]}       # Array length

# Associative arrays (Bash 4+)
declare -A person
person[name]="John"
person[age]=30
echo ${person[name]}
```

### Special Variables

```bash
$0          # Script name
$1, $2...   # Positional parameters
$#          # Number of arguments
$@          # All arguments (as separate words)
$*          # All arguments (as single word)
$?          # Exit status of last command
$$          # Current process ID
$!          # PID of last background command
$_          # Last argument of previous command

# Example
#!/bin/bash
echo "Script name: $0"
echo "First argument: $1"
echo "Number of arguments: $#"
echo "All arguments: $@"
```

### Variable Expansion

```bash
name="John"

# Default values
echo ${name:-"Unknown"}     # Use default if unset
echo ${name:="Unknown"}     # Set and use default if unset
echo ${name:+"Known"}       # Use alternative if set
echo ${name:?"Error: name not set"}  # Error if unset

# String operations
file="document.txt"
echo ${#file}              # Length: 12
echo ${file%.txt}          # Remove suffix: document
echo ${file#doc}           # Remove prefix: ument.txt
echo ${file%.*}            # Remove extension: document
echo ${file##*.}           # Get extension: txt
echo ${file^^}             # Uppercase: DOCUMENT.TXT
echo ${file,,}             # Lowercase: document.txt
echo ${file/doc/DOC}       # Replace: DOCument.txt
```

### Command Substitution

```bash
# Modern syntax (preferred)
current_date=$(date +%Y-%m-%d)
file_count=$(ls | wc -l)
user=$(whoami)

# Legacy syntax (still works)
current_date=`date +%Y-%m-%d`

# Nested substitution
echo "Files modified today: $(find . -mtime 0 | wc -l)"

# Use in strings
echo "Today is $(date +%A)"
echo "Current user: $(whoami)@$(hostname)"
```

---

## Control Structures

### Conditionals (if/elif/else)

```bash
# Basic if
if [ condition ]; then
    # commands
fi

# if-else
if [ condition ]; then
    # commands
else
    # commands
fi

# if-elif-else
if [ condition1 ]; then
    # commands
elif [ condition2 ]; then
    # commands
else
    # commands
fi

# Example
age=25
if [ $age -lt 18 ]; then
    echo "Minor"
elif [ $age -lt 65 ]; then
    echo "Adult"
else
    echo "Senior"
fi
```

### Test Conditions

```bash
# Numeric comparisons
[ $a -eq $b ]    # Equal
[ $a -ne $b ]    # Not equal
[ $a -lt $b ]    # Less than
[ $a -le $b ]    # Less than or equal
[ $a -gt $b ]    # Greater than
[ $a -ge $b ]    # Greater than or equal

# String comparisons
[ "$a" = "$b" ]   # Equal
[ "$a" != "$b" ]  # Not equal
[ -z "$a" ]       # Empty string
[ -n "$a" ]       # Non-empty string

# File tests
[ -e "$file" ]    # Exists
[ -f "$file" ]    # Regular file
[ -d "$file" ]    # Directory
[ -r "$file" ]    # Readable
[ -w "$file" ]    # Writable
[ -x "$file" ]    # Executable
[ -s "$file" ]    # Size > 0
[ -L "$file" ]    # Symbolic link

# Logical operators
[ condition1 ] && [ condition2 ]  # AND
[ condition1 ] || [ condition2 ]  # OR
[ ! condition ]                   # NOT
```

### Double Brackets (Bash-specific)

```bash
# [[ ]] is more powerful and safer
[[ $string =~ ^[0-9]+$ ]]     # Regex match
[[ $string == *.txt ]]        # Pattern match
[[ $a -gt 5 && $a -lt 10 ]]  # Combined conditions

# Example: Validate email
email="user@example.com"
if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Valid email"
fi
```

### Case Statement

```bash
# Syntax
case $variable in
    pattern1)
        # commands
        ;;
    pattern2)
        # commands
        ;;
    *)
        # default
        ;;
esac

# Example
read -p "Enter your choice (y/n): " choice
case $choice in
    y|Y|yes|Yes)
        echo "You chose yes"
        ;;
    n|N|no|No)
        echo "You chose no"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac
```

---

## Loops

### For Loop

```bash
# Loop over list
for item in apple banana cherry; do
    echo "Fruit: $item"
done

# Loop over range
for i in {1..5}; do
    echo "Number: $i"
done

# Loop with step
for i in {0..10..2}; do
    echo "Even: $i"
done

# C-style for loop
for ((i=0; i<5; i++)); do
    echo "Index: $i"
done

# Loop over files
for file in *.txt; do
    echo "Processing: $file"
done

# Loop over command output
for user in $(cat /etc/passwd | cut -d: -f1); do
    echo "User: $user"
done

# Loop over array
fruits=("apple" "banana" "cherry")
for fruit in "${fruits[@]}"; do
    echo "Fruit: $fruit"
done
```

### While Loop

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

# Infinite loop (use with caution)
while true; do
    echo "Running..."
    sleep 1
done

# Read user input until 'quit'
while read -p "Enter command: " cmd; do
    if [ "$cmd" = "quit" ]; then
        break
    fi
    echo "You entered: $cmd"
done
```

### Until Loop

```bash
# Run until condition is true
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
# Output: 1 2 3 4

# continue - skip iteration
for i in {1..5}; do
    if [ $i -eq 3 ]; then
        continue
    fi
    echo $i
done
# Output: 1 2 4 5
```

---

## Functions

### Function Basics

```bash
# Definition (two styles)
function greet {
    echo "Hello, $1!"
}

# or (preferred for portability)
greet() {
    echo "Hello, $1!"
}

# Call function
greet "World"
greet "John"
```

### Function Parameters

```bash
# Parameters are positional
add() {
    local sum=$(($1 + $2))
    echo $sum
}

result=$(add 5 3)
echo "5 + 3 = $result"

# All arguments
process_all() {
    echo "Number of args: $#"
    for arg in "$@"; do
        echo "Arg: $arg"
    done
}

process_all one two three
```

### Return Values

```bash
# Return exit status (0-255)
is_even() {
    if [ $(($1 % 2)) -eq 0 ]; then
        return 0  # true/success
    else
        return 1  # false/failure
    fi
}

if is_even 4; then
    echo "4 is even"
fi

# Return value via echo (capture with $())
calculate() {
    local result=$(($1 * $2))
    echo $result
}

answer=$(calculate 6 7)
echo "6 * 7 = $answer"
```

### Local Variables

```bash
# Without local (global scope)
set_global() {
    var="global value"
}

# With local (function scope)
set_local() {
    local var="local value"
    echo "Inside: $var"
}

var="original"
set_global
echo "After set_global: $var"  # global value

var="original"
set_local
echo "After set_local: $var"   # original
```

---

## Input and Output

### Reading Input

```bash
# Basic read
read name
echo "Hello, $name"

# With prompt
read -p "Enter your name: " name

# Silent input (for passwords)
read -s -p "Enter password: " password
echo  # New line after silent input

# With timeout
read -t 5 -p "Enter (5 sec timeout): " response

# With default
read -p "Enter name [John]: " name
name=${name:-John}

# Read into array
read -a words <<< "one two three"
echo ${words[1]}  # two
```

### Output

```bash
# Standard output
echo "Hello, World"
printf "Name: %s, Age: %d\n" "John" 25

# Standard error
echo "Error: something went wrong" >&2

# Suppress output
command > /dev/null 2>&1

# Append to file
echo "log entry" >> logfile.txt

# Redirect both stdout and stderr
command > output.txt 2>&1
command &> output.txt  # Bash shorthand
```

### Here Documents

```bash
# Multi-line input
cat << EOF
This is line 1
This is line 2
Variable: $USER
EOF

# Suppress variable expansion
cat << 'EOF'
This is literal: $USER
No expansion happens
EOF

# Here string (single line)
grep "pattern" <<< "search this string"
```

---

## Error Handling

### Exit Status

```bash
# Check exit status
command
if [ $? -eq 0 ]; then
    echo "Command succeeded"
else
    echo "Command failed"
fi

# Inline check
command && echo "Success" || echo "Failure"

# Set exit status
exit 0   # Success
exit 1   # Failure
```

### Error Handling Options

```bash
#!/bin/bash

# Exit on error
set -e

# Exit on undefined variable
set -u

# Exit on pipe failure
set -o pipefail

# Combined (recommended for scripts)
set -euo pipefail

# Debug mode
set -x  # Print commands before execution

# Common pattern at script start
set -euo pipefail
```

### Trap for Cleanup

```bash
#!/bin/bash
set -e

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/tempfile.$$
}

# Call cleanup on exit (normal or error)
trap cleanup EXIT

# Call cleanup on specific signals
trap cleanup SIGINT SIGTERM

# Create temp file
echo "data" > /tmp/tempfile.$$

# Script continues...
# Cleanup runs automatically on exit
```

---

## Debugging

### Debug Mode

```bash
# Run with debug
bash -x script.sh

# Debug section of script
set -x
# debugged commands
set +x

# Print script name and line number
export PS4='+(${BASH_SOURCE}:${LINENO}): '
```

### Common Debugging Techniques

```bash
# Print variables
echo "DEBUG: var=$var" >&2

# Validate inputs
if [ -z "$1" ]; then
    echo "Error: No argument provided" >&2
    exit 1
fi

# Use meaningful exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_USAGE=2

# Verbose mode
VERBOSE=false
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[$(date '+%H:%M:%S')] $1"
    fi
}
```

---

## Best Practices

### Script Template

```bash
#!/usr/bin/env bash
#
# Script: template.sh
# Description: Template for new scripts
# Usage: ./template.sh [options] arguments
#

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Default values
VERBOSE=false
DEBUG=false

# Functions
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [options] <argument>

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --debug     Enable debug mode

Arguments:
    argument        Description of argument

Examples:
    $SCRIPT_NAME -v myarg
    $SCRIPT_NAME --debug myarg
EOF
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            set -x
            shift
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            ARGUMENT="$1"
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "${ARGUMENT:-}" ]; then
    error "Missing required argument"
fi

# Main logic
main() {
    log "Starting script with argument: $ARGUMENT"

    if [ "$VERBOSE" = true ]; then
        log "Verbose mode enabled"
    fi

    # Your code here

    log "Script completed successfully"
}

main "$@"
```

### Coding Guidelines

```bash
# 1. Quote variables
echo "$variable"         # Good
echo $variable           # Bad (can break with spaces)

# 2. Use [[ ]] for tests
[[ -f "$file" ]]         # Good (Bash)
[ -f "$file" ]           # OK (POSIX)

# 3. Use functions for reusable code
validate_input() { ... }
process_file() { ... }

# 4. Use local in functions
local result=""

# 5. Use meaningful names
backup_directory="/backup"   # Good
bd="/backup"                 # Bad

# 6. Document your code
# Function: process_log
# Arguments: $1 - log file path
# Returns: 0 on success, 1 on error
```

---

## Practical Exercises

### Exercise 1: Argument Handling

```bash
#!/bin/bash
# Create a script that:
# - Accepts a filename as argument
# - Checks if file exists
# - Counts lines, words, and characters
# - Prints results

if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

file="$1"

if [ ! -f "$file" ]; then
    echo "Error: $file is not a file"
    exit 1
fi

lines=$(wc -l < "$file")
words=$(wc -w < "$file")
chars=$(wc -c < "$file")

echo "File: $file"
echo "Lines: $lines"
echo "Words: $words"
echo "Characters: $chars"
```

### Exercise 2: User Menu

```bash
#!/bin/bash
# Create an interactive menu

while true; do
    echo ""
    echo "=== System Info Menu ==="
    echo "1) Show date and time"
    echo "2) Show disk usage"
    echo "3) Show memory usage"
    echo "4) Show logged in users"
    echo "5) Exit"
    echo ""
    read -p "Enter choice: " choice

    case $choice in
        1) date ;;
        2) df -h ;;
        3) free -h ;;
        4) who ;;
        5) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
done
```

### Exercise 3: Log Rotation

```bash
#!/bin/bash
# Simple log rotation script

LOG_DIR="/var/log/myapp"
MAX_LOGS=5

rotate_logs() {
    local log_file="$1"

    # Remove oldest
    [ -f "${log_file}.${MAX_LOGS}" ] && rm "${log_file}.${MAX_LOGS}"

    # Rotate existing
    for ((i=MAX_LOGS-1; i>=1; i--)); do
        [ -f "${log_file}.${i}" ] && mv "${log_file}.${i}" "${log_file}.$((i+1))"
    done

    # Rotate current
    [ -f "${log_file}" ] && mv "${log_file}" "${log_file}.1"

    # Create new empty log
    touch "${log_file}"
}

# Rotate all logs in directory
for log in "$LOG_DIR"/*.log; do
    if [ -f "$log" ]; then
        echo "Rotating: $log"
        rotate_logs "$log"
    fi
done
```

---

## Key Takeaways

1. **Always use the shebang** - `#!/bin/bash` or `#!/usr/bin/env bash`
2. **Quote your variables** - Prevent word splitting issues
3. **Use `set -euo pipefail`** - Catch errors early
4. **Functions improve readability** - Break complex scripts into parts
5. **Validate inputs** - Check arguments and file existence
6. **Handle errors gracefully** - Use trap for cleanup
7. **Document your scripts** - Future you will thank you

---

## Next Module

[Advanced Shell Scripting](./06-advanced-shell-scripting.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Variables
- Control Structures
- Loops
- Functions

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
