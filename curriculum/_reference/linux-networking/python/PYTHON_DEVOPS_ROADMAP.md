# Python for DevOps: Elite Engineer Roadmap

A comprehensive, hands-on learning path to master Python for DevOps — from fundamentals to production-grade automation.

---

## How to Use This Roadmap

### Structure
Each phase contains:
- **Overview**: Skill level, time estimate, prerequisites
- **Learning Objectives**: What you'll master
- **Content**: Core concepts with book references
- **Micro-Labs**: 15-30 minute hands-on exercises
- **Phase Lab**: 2-4 hour integrative project
- **Common Mistakes**: Pitfalls to avoid
- **Checkpoint**: Self-assessment before advancing
- **Interview Questions**: Real-world preparation

### Symbols
| Symbol | Meaning |
|--------|---------|
| 📖 | Book reference |
| 🔬 | Micro-lab (15-30 min) |
| 🧪 | Phase lab (2-4 hours) |
| ⚠️ | Common mistake |
| ✅ | Checkpoint item |
| 💼 | Interview question |
| 🏠 | Local environment |
| ☁️ | Cloud environment |

### Book References
- **[ORA]** = "Python for DevOps: Learn Ruthlessly Effective Automation" (O'Reilly)
- **[BPB]** = "Python for DevOps: Master Automation" (BPB Publications)

---

# PART I: FOUNDATIONS
*Estimated Time: 6-8 weeks*

---

## Phase 1: Python Core for DevOps

| | |
|---|---|
| **Skill Level** | Beginner |
| **Time Estimate** | 2-3 weeks |
| **Prerequisites** | Basic command line familiarity |
| **Environment** | 🏠 Local (any OS) |

### Learning Objectives
By the end of this phase, you will:
- Write Python scripts confidently for automation tasks
- Handle files, errors, and data structures effectively
- Use regular expressions for text processing
- Build reusable functions and modules

---

### 1.1 Python Environment Setup

**Concepts:**
- Python installation methods (system, pyenv, conda)
- Virtual environments fundamentals
- IDE/editor setup (VS Code, PyCharm, vim)
- The Python REPL and IPython

📖 **References:** [ORA] Ch.1 pp.1-3 | [BPB] Ch.1 "Getting Started with Python"

**Key Setup Steps:**
```bash
# Install pyenv (recommended for managing Python versions)
curl https://pyenv.run | bash

# Install Python 3.11+
pyenv install 3.12.0
pyenv global 3.12.0

# Create project structure
mkdir -p ~/devops-labs/{phase1,phase2,phase3}
cd ~/devops-labs/phase1
python -m venv venv
source venv/bin/activate
```

---

🔬 **Micro-Lab 1.1: Environment Verification** (15 min)
**Objective** — Verify your Python environment is correctly configured

**Tasks**

1. Create a new directory ~/devops-labs/phase1
2. Create and activate a virtual environment
3. Create a script that prints:
   - Python version
   - Virtual environment path
   - Current working directory
   - All environment variables containing "PYTHON"

**Starter code**

```python
import sys
import os

def show_environment():
    # TODO: Print Python version (sys.version)
    # TODO: Print venv path (sys.prefix)
    # TODO: Print cwd (os.getcwd())
    # TODO: Filter and print PYTHON env vars
    pass

if __name__ == "__main__":
    show_environment()
```

**Success criteria**

- Script runs without errors
- All four pieces of information display correctly
- Virtual environment path differs from system Python


---

### 1.2 Variables, Data Types, and Structures

**Concepts:**
- Primitive types: int, float, str, bool, None
- Collections: list, tuple, dict, set
- Mutability and memory model
- Type hints for documentation

📖 **References:** [ORA] Ch.1 pp.4-22 | [BPB] Ch.1 "Variables, data types, and structures"

**Essential Patterns:**
```python
# Type hints for DevOps scripts
from typing import Dict, List, Optional

def get_server_config(hostname: str) -> Dict[str, str]:
    """Return configuration for a given server."""
    configs: Dict[str, Dict[str, str]] = {
        "web-01": {"role": "frontend", "env": "prod"},
        "db-01": {"role": "database", "env": "prod"},
    }
    return configs.get(hostname, {"role": "unknown", "env": "unknown"})

# Dictionary comprehensions for transformations
servers = ["web-01", "web-02", "db-01"]
server_ips = {s: f"10.0.1.{i+10}" for i, s in enumerate(servers)}

# Set operations for inventory management
prod_servers = {"web-01", "web-02", "db-01"}
maintenance = {"web-02", "cache-01"}
affected = prod_servers & maintenance  # intersection
```

---

🔬 **Micro-Lab 1.2: Server Inventory Manager** (30 min)
**Objective** — Build a server inventory using Python data structures

**Tasks**

1. Create a dictionary representing 5 servers with:
   - hostname (key)
   - ip, role, environment, status (nested dict values)
2. Write functions to:
   - List all servers in a specific environment
   - Find servers by role
   - Count servers by status
3. Use set operations to find:
   - Servers that are both "prod" AND "critical"
   - Servers in "staging" OR "dev"

**Starter code**

```python
from typing import Dict, List, Set

# Server inventory structure
inventory: Dict[str, Dict[str, str]] = {
    "web-01": {
        "ip": "10.0.1.10",
        "role": "frontend",
        "env": "prod",
        "status": "running"
    },
    # TODO: Add 4 more servers
}

def servers_by_env(inv: Dict, env: str) -> List[str]:
    """Return list of hostnames in given environment."""
    # TODO: Implement
    pass

def servers_by_role(inv: Dict, role: str) -> List[str]:
    """Return list of hostnames with given role."""
    # TODO: Implement
    pass

def count_by_status(inv: Dict) -> Dict[str, int]:
    """Return count of servers per status."""
    # TODO: Implement
    pass

# TODO: Create sets and perform operations
```

**Success criteria**

- All functions return correct results
- Set operations produce expected intersections/unions
- Code uses type hints


---

### 1.3 Control Flow and Comprehensions

**Concepts:**
- Conditional statements (if/elif/else)
- Loops (for, while) with else clauses
- Comprehensions (list, dict, set, generator)
- Exception handling fundamentals

📖 **References:** [ORA] Ch.1 pp.6-10, 31-32 | [BPB] Ch.1 "Control structures"

**DevOps Patterns:**
```python
# Retry pattern with exponential backoff
import time

def retry_operation(func, max_retries=3, base_delay=1):
    """Retry a function with exponential backoff."""
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            delay = base_delay * (2 ** attempt)
            print(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s...")
            time.sleep(delay)

# Generator for processing large log files
def parse_log_lines(filepath: str):
    """Yield parsed log entries one at a time."""
    with open(filepath) as f:
        for line in f:
            if line.strip():
                yield parse_log_entry(line)

# Filter with comprehension
error_logs = [log for log in parse_log_lines("/var/log/app.log")
              if log.get("level") == "ERROR"]
```

---

🔬 **Micro-Lab 1.3: Health Check with Retry** (30 min)
**Objective** — Implement a service health checker with retry logic

**Tasks**

1. Create a mock health check function that randomly fails
2. Implement retry with exponential backoff
3. Track and report:
   - Number of attempts
   - Total time elapsed
   - Final status
4. Use generator to check multiple services

**Starter code**

```python
import random
import time
from typing import Generator, Dict, Any

def mock_health_check(service: str) -> bool:
    """Simulate health check that fails 70% of time."""
    return random.random() > 0.7

def check_with_retry(
    service: str,
    max_retries: int = 5,
    base_delay: float = 0.5
) -> Dict[str, Any]:
    """
    Check service health with exponential backoff.

    Returns dict with: service, healthy, attempts, elapsed_time
    """
    # TODO: Implement retry logic
    # TODO: Track attempts and time
    pass

def check_all_services(services: list) -> Generator[Dict, None, None]:
    """Yield health check results for all services."""
    # TODO: Implement generator
    pass

# Test with services
services = ["api", "database", "cache", "queue", "storage"]
# TODO: Run checks and summarize results
```

**Success criteria**

- Retry logic works with exponential backoff
- All metrics are tracked correctly
- Generator yields results one at a time


---

### 1.4 Functions and Modules

**Concepts:**
- Function definition, arguments, return values
- *args and **kwargs
- Decorators for cross-cutting concerns
- Module organization and imports
- The `if __name__ == "__main__"` pattern

📖 **References:** [ORA] Ch.1 pp.23-26 | [BPB] Ch.1 "Functions and modules"

**DevOps Patterns:**
```python
# Decorator for timing operations
import functools
import time
from typing import Callable, Any

def timed(func: Callable) -> Callable:
    """Decorator to measure function execution time."""
    @functools.wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"{func.__name__} completed in {elapsed:.3f}s")
        return result
    return wrapper

@timed
def deploy_service(service: str, version: str) -> bool:
    """Deploy a service (simulated)."""
    time.sleep(1)  # Simulate deployment
    return True

# Module structure for DevOps toolkit
# devops_toolkit/
# ├── __init__.py
# ├── aws/
# │   ├── __init__.py
# │   ├── ec2.py
# │   └── s3.py
# ├── monitoring/
# │   ├── __init__.py
# │   └── metrics.py
# └── utils/
#     ├── __init__.py
#     └── retry.py
```

---

🔬 **Micro-Lab 1.4: Decorator Toolkit** (30 min)
**Objective** — Build reusable decorators for DevOps automation

**Tasks**

1. Create a @timed decorator that logs execution time
2. Create a @logged decorator that logs function calls with args
3. Create a @retry decorator with configurable attempts
4. Stack multiple decorators on a single function

**Starter code**

```python
import functools
import time
import logging
from typing import Callable, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def timed(func: Callable) -> Callable:
    """Log execution time of decorated function."""
    @functools.wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        # TODO: Implement timing logic
        pass
    return wrapper

def logged(func: Callable) -> Callable:
    """Log function calls with arguments."""
    @functools.wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        # TODO: Log function name and args
        # TODO: Log return value
        pass
    return wrapper

def retry(max_attempts: int = 3, delay: float = 1.0):
    """Decorator factory for retry logic."""
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            # TODO: Implement retry logic
            pass
        return wrapper
    return decorator

# Test stacked decorators
@logged
@timed
@retry(max_attempts=3, delay=0.5)
def fetch_config(service: str) -> dict:
    """Fetch configuration for a service."""
    import random
    if random.random() < 0.5:
        raise ConnectionError("Failed to fetch config")
    return {"service": service, "version": "1.0.0"}

# TODO: Test the function
```

**Success criteria**

- All decorators work independently
- Stacked decorators execute in correct order
- @retry handles exceptions and retries appropriately


---

### 1.5 File Operations and Filesystem

**Concepts:**
- Reading and writing files (text, binary)
- Context managers (with statement)
- Path manipulation with `pathlib`
- Directory traversal with `os.walk`
- File permissions and metadata

📖 **References:** [ORA] Ch.2 pp.35-55 | [BPB] Ch.1 "Working with files in Python"

**DevOps Patterns:**
```python
from pathlib import Path
import json
import os

# Modern path handling with pathlib
config_dir = Path("/etc/myapp")
config_file = config_dir / "config.json"

# Safe file writing with atomic replacement
def write_config_atomic(path: Path, config: dict) -> None:
    """Write config atomically to prevent corruption."""
    temp_path = path.with_suffix(".tmp")
    with open(temp_path, "w") as f:
        json.dump(config, f, indent=2)
    temp_path.replace(path)  # Atomic on POSIX

# Find all log files recursively
def find_logs(root: Path, pattern: str = "*.log") -> list[Path]:
    """Find all matching log files under root."""
    return list(root.rglob(pattern))

# Process large files efficiently
def tail_file(path: Path, lines: int = 100) -> list[str]:
    """Return last N lines of a file efficiently."""
    with open(path, "rb") as f:
        f.seek(0, 2)  # Seek to end
        size = f.tell()
        # Read chunks from end until we have enough lines
        # ... implementation
```

---

🔬 **Micro-Lab 1.5: Log Analyzer** (30 min)
**Objective** — Build a log file analyzer using filesystem operations

**Tasks**

1. Create sample log files with various log levels
2. Write functions to:
   - Find all .log files in a directory tree
   - Parse log lines (timestamp, level, message)
   - Count entries by log level
   - Find logs within a time range
3. Generate a summary report

**Starter code**

```python
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Iterator
from dataclasses import dataclass

@dataclass
class LogEntry:
    timestamp: datetime
    level: str
    message: str
    source_file: Path

def create_sample_logs(base_dir: Path) -> None:
    """Create sample log files for testing."""
    base_dir.mkdir(parents=True, exist_ok=True)

    # Sample log content
    logs = [
        "2024-01-15 10:30:00 INFO Application started",
        "2024-01-15 10:30:05 DEBUG Loading configuration",
        "2024-01-15 10:30:10 ERROR Database connection failed",
        "2024-01-15 10:31:00 INFO Retrying connection",
        "2024-01-15 10:31:05 INFO Database connected",
    ]

    (base_dir / "app.log").write_text("\n".join(logs))
    # TODO: Create more log files in subdirectories

def find_log_files(root: Path) -> List[Path]:
    """Find all .log files recursively."""
    # TODO: Implement
    pass

def parse_log_line(line: str, source: Path) -> LogEntry:
    """Parse a log line into a LogEntry."""
    # TODO: Implement
    pass

def analyze_logs(log_files: List[Path]) -> Dict[str, int]:
    """Count log entries by level across all files."""
    # TODO: Implement
    pass

# TODO: Main analysis workflow
```

**Success criteria**

- Successfully finds all log files
- Correctly parses log format
- Accurate counts by level
- Handles malformed lines gracefully


---

### 1.6 Regular Expressions

**Concepts:**
- Pattern syntax (character classes, quantifiers, anchors)
- Searching, matching, and substitution
- Groups and named groups
- Compiling patterns for performance
- Common DevOps regex patterns

📖 **References:** [ORA] Ch.1 pp.26-31 | [BPB] Ch.3 "Working with regular expressions"

**DevOps Patterns:**
```python
import re
from typing import Optional, Dict

# Common DevOps regex patterns
PATTERNS = {
    "ip_address": re.compile(
        r"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}"
        r"(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
    ),
    "log_line": re.compile(
        r"^(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+"
        r"(?P<level>DEBUG|INFO|WARNING|ERROR|CRITICAL)\s+"
        r"(?P<message>.+)$"
    ),
    "semver": re.compile(
        r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
        r"(?:-(?P<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
        r"(?:\+(?P<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
    ),
    "docker_image": re.compile(
        r"^(?:(?P<registry>[^/]+)/)?(?P<image>[^:]+)(?::(?P<tag>.+))?$"
    ),
}

def extract_ips(text: str) -> list[str]:
    """Extract all IP addresses from text."""
    return PATTERNS["ip_address"].findall(text)

def parse_log(line: str) -> Optional[Dict[str, str]]:
    """Parse a log line into components."""
    match = PATTERNS["log_line"].match(line)
    return match.groupdict() if match else None
```

---

🔬 **Micro-Lab 1.6: Config Sanitizer** (30 min)
**Objective** — Use regex to find and sanitize sensitive data in config files

**Tasks**

1. Create regex patterns to detect:
   - API keys (various formats)
   - Passwords in connection strings
   - AWS access keys
   - Private keys
2. Write a sanitizer that replaces sensitive values with [REDACTED]
3. Process a directory of config files

**Starter code**

```python
import re
from pathlib import Path
from typing import List, Tuple

# Sensitive data patterns
SENSITIVE_PATTERNS = {
    "aws_access_key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "aws_secret_key": re.compile(
        r"(?i)(aws_secret_access_key|secret_key)\s*[=:]\s*['\"]?([A-Za-z0-9/+=]{40})['\"]?"
    ),
    # TODO: Add more patterns
    "api_key": None,  # Generic API key pattern
    "password": None,  # Password in connection string
    "private_key": None,  # BEGIN PRIVATE KEY blocks
}

def compile_patterns() -> Dict[str, re.Pattern]:
    """Compile all regex patterns."""
    # TODO: Implement remaining patterns
    pass

def find_sensitive(text: str) -> List[Tuple[str, str, int, int]]:
    """
    Find sensitive data in text.
    Returns: [(pattern_name, matched_text, start, end), ...]
    """
    # TODO: Implement
    pass

def sanitize_text(text: str) -> str:
    """Replace sensitive data with [REDACTED]."""
    # TODO: Implement
    pass

def sanitize_directory(dir_path: Path, extensions: List[str]) -> Dict[str, int]:
    """
    Sanitize all matching files in directory.
    Returns count of redactions per file.
    """
    # TODO: Implement
    pass

# Test with sample configs
```

**Success criteria**

- All sensitive patterns correctly detected
- Sanitization preserves file structure
- Reports accurate counts
- Handles edge cases (partial matches, etc.)


---

### 1.7 Error Handling and Exceptions

**Concepts:**
- try/except/else/finally blocks
- Built-in exception hierarchy
- Creating custom exceptions
- Exception chaining
- Logging exceptions properly

📖 **References:** [ORA] Ch.1 pp.10 | [BPB] Ch.1 "Error handling and exceptions"

**DevOps Patterns:**
```python
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Custom exception hierarchy
class DeploymentError(Exception):
    """Base exception for deployment operations."""
    pass

class ServiceUnavailableError(DeploymentError):
    """Service is not responding."""
    def __init__(self, service: str, message: str = ""):
        self.service = service
        super().__init__(f"Service {service} unavailable: {message}")

class ConfigurationError(DeploymentError):
    """Invalid configuration."""
    pass

# Proper exception handling
def deploy(service: str, version: str) -> bool:
    """Deploy a service with proper error handling."""
    try:
        config = load_config(service)
    except FileNotFoundError as e:
        raise ConfigurationError(f"Config not found for {service}") from e

    try:
        result = perform_deployment(service, version, config)
    except ConnectionError as e:
        logger.exception("Deployment failed due to connection error")
        raise ServiceUnavailableError(service, str(e)) from e
    except Exception:
        logger.exception("Unexpected error during deployment")
        raise
    else:
        logger.info(f"Successfully deployed {service}:{version}")
        return True
    finally:
        cleanup_temp_files(service)
```

---

🔬 **Micro-Lab 1.7: Robust Configuration Loader** (30 min)
**Objective** — Build a config loader with comprehensive error handling

**Tasks**

1. Create custom exceptions for config errors
2. Implement a config loader that handles:
   - File not found
   - Permission denied
   - Invalid JSON/YAML
   - Missing required fields
   - Type validation errors
3. Provide helpful error messages with context

**Starter code**

```python
import json
from pathlib import Path
from typing import Any, Dict, List
from dataclasses import dataclass

# Custom exceptions
class ConfigError(Exception):
    """Base configuration error."""
    pass

class ConfigNotFoundError(ConfigError):
    """Configuration file not found."""
    # TODO: Add path attribute
    pass

class ConfigParseError(ConfigError):
    """Failed to parse configuration."""
    # TODO: Add line number if available
    pass

class ConfigValidationError(ConfigError):
    """Configuration validation failed."""
    # TODO: Add field and expected type
    pass

@dataclass
class ConfigSchema:
    """Define required fields and types."""
    required_fields: Dict[str, type]
    optional_fields: Dict[str, type] = None

def load_config(
    path: Path,
    schema: ConfigSchema = None
) -> Dict[str, Any]:
    """
    Load and validate configuration file.

    Raises:
        ConfigNotFoundError: File doesn't exist
        ConfigParseError: Invalid JSON
        ConfigValidationError: Schema validation failed
    """
    # TODO: Implement with proper error handling
    pass

def validate_config(config: Dict, schema: ConfigSchema) -> List[str]:
    """Validate config against schema, return list of errors."""
    # TODO: Implement
    pass

# Test with various error conditions
```

**Success criteria**

- Each error type provides clear, actionable messages
- Exception chaining preserves original errors
- Validation reports all errors, not just first one


---

### 🧪 Phase 1 Lab: DevOps Toolkit Foundation (3-4 hours)

**Objective** — Build a reusable DevOps toolkit package

**Scenario**

You're creating the foundation of a Python toolkit that your team will use
for automation. It needs to be well-structured, tested, and documented.

**Requirements**

1. Package Structure:
   **`devops_toolkit/`**

   - `__init__.py`
   - `config/`
     - `__init__.py`
     - `loader.py` — Config loading with validation
     - `schema.py` — Schema definitions
   - `logging/`
     - `__init__.py`
     - `setup.py` — Logging configuration
   - `utils/`
     - `__init__.py`
     - `decorators.py` — @timed, @retry, @logged
     - `filesystem.py` — File operations
     - `patterns.py` — Regex patterns
   - `exceptions.py` — Custom exceptions

2. Features to Implement:
   - Config loader supporting JSON and YAML
   - Structured logging setup
   - Utility decorators (@timed, @retry, @logged)
   - Common regex patterns for DevOps
   - Custom exception hierarchy

3. Testing Requirements:
   - Unit tests for each module
   - At least 80% code coverage
   - Test both success and failure cases

4. Documentation:
   - Docstrings on all public functions
   - README with usage examples

**Deliverables**

- [ ] Complete package structure
- [ ] All modules implemented
- [ ] Test suite with pytest
- [ ] README.md with examples

**Stretch goals**

- [ ] Type hints throughout
- [ ] CLI entry point using the package
- [ ] GitHub Actions workflow for testing


---

### ⚠️ Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Bare `except:` | Catches SystemExit, KeyboardInterrupt | Use `except Exception:` minimum |
| Not using `with` | Resource leaks | Always use context managers for files |
| String concatenation in loops | O(n²) performance | Use `"".join()` or f-strings |
| Mutable default arguments | Shared state bugs | Use `None` and create inside function |
| Ignoring return values | Silent failures | Always check or explicitly ignore |
| Hardcoded paths | Non-portable scripts | Use `pathlib` and environment variables |

---

### ✅ Checkpoint: Phase 1 Self-Assessment

Before proceeding, verify you can:

- [ ] Create and manage virtual environments
- [ ] Write functions with proper type hints
- [ ] Use list/dict/set comprehensions fluently
- [ ] Handle errors with appropriate exception types
- [ ] Read/write files using context managers
- [ ] Use `pathlib` for all path operations
- [ ] Write and use decorators
- [ ] Create and use regex patterns
- [ ] Structure code into modules and packages
- [ ] Write basic unit tests with pytest

---

### 💼 Interview Questions: Phase 1

1. **What's the difference between `is` and `==` in Python?**
   <details>
   <summary>Answer</summary>
   `is` checks identity (same object in memory), `==` checks equality (same value). Use `is` only for None, True, False comparisons.
   </details>

2. **Explain the GIL and its implications for DevOps scripts.**
   <details>
   <summary>Answer</summary>
   The Global Interpreter Lock prevents true parallel Python execution. For I/O-bound DevOps tasks (API calls, file ops), use asyncio or threading. For CPU-bound tasks, use multiprocessing.
   </details>

3. **How would you safely update a configuration file in production?**
   <details>
   <summary>Answer</summary>
   Write to a temp file first, validate contents, then atomically rename/replace. This prevents corruption if the process is interrupted.
   </details>

4. **What happens when you modify a list while iterating over it?**
   <details>
   <summary>Answer</summary>
   Undefined behavior - items may be skipped or processed twice. Create a copy to iterate, or use list comprehension to filter.
   </details>

---

## Phase 2: Linux System Administration with Python

| | |
|---|---|
| **Skill Level** | Beginner-Intermediate |
| **Time Estimate** | 2 weeks |
| **Prerequisites** | Phase 1, Basic Linux CLI |
| **Environment** | 🏠 Linux VM or container |

### Learning Objectives
By the end of this phase, you will:
- Automate common Linux administration tasks
- Manage processes, users, and services programmatically
- Understand when to use Python vs shell scripts
- Build system monitoring and health check tools

---

### 2.1 Linux Filesystem Operations

**Concepts:**
- Linux filesystem hierarchy
- File types and special files
- Permissions, ownership, and ACLs
- Mount points and disk management
- Symbolic and hard links

📖 **References:** [ORA] Ch.2, Ch.4 pp.87-92 | [BPB] Ch.2 "Introduction to Linux file system"

**Essential Commands from Python:**
```python
import os
import stat
import shutil
from pathlib import Path

# Check file type
def get_file_type(path: Path) -> str:
    """Determine file type."""
    mode = path.stat().st_mode
    if stat.S_ISREG(mode): return "regular"
    if stat.S_ISDIR(mode): return "directory"
    if stat.S_ISLNK(mode): return "symlink"
    if stat.S_ISBLK(mode): return "block device"
    if stat.S_ISCHR(mode): return "character device"
    if stat.S_ISFIFO(mode): return "named pipe"
    if stat.S_ISSOCK(mode): return "socket"
    return "unknown"

# Check and modify permissions
def make_executable(path: Path) -> None:
    """Add execute permission for owner."""
    current = path.stat().st_mode
    path.chmod(current | stat.S_IXUSR)

# Disk usage
def get_disk_usage(path: Path) -> dict:
    """Get disk usage statistics."""
    usage = shutil.disk_usage(path)
    return {
        "total_gb": usage.total / (1024**3),
        "used_gb": usage.used / (1024**3),
        "free_gb": usage.free / (1024**3),
        "percent_used": (usage.used / usage.total) * 100
    }
```

---

🔬 **Micro-Lab 2.1: Disk Space Monitor** (30 min)
**Objective** — Build a disk space monitoring tool

**Tasks**

1. Get disk usage for all mount points
2. Identify partitions above threshold (e.g., 80%)
3. Find largest directories consuming space
4. Generate alert-ready output

**Starter code**

```python
import shutil
import subprocess
from pathlib import Path
from typing import List, Dict
from dataclasses import dataclass

@dataclass
class PartitionInfo:
    mount_point: str
    total_gb: float
    used_gb: float
    free_gb: float
    percent_used: float

def get_mount_points() -> List[str]:
    """Get list of mount points from system."""
    # Parse /proc/mounts or use df command
    result = subprocess.run(
        ["df", "-h", "--output=target"],
        capture_output=True, text=True
    )
    # TODO: Parse output, skip header and virtual filesystems
    pass

def analyze_partition(mount_point: str) -> PartitionInfo:
    """Get usage info for a partition."""
    # TODO: Implement using shutil.disk_usage
    pass

def find_large_dirs(path: Path, top_n: int = 10) -> List[tuple]:
    """Find top N directories by size."""
    # TODO: Implement (consider using du command or os.walk)
    pass

def check_thresholds(
    partitions: List[PartitionInfo],
    warning: float = 80.0,
    critical: float = 90.0
) -> Dict[str, List[PartitionInfo]]:
    """Categorize partitions by threshold."""
    # TODO: Return {"warning": [...], "critical": [...]}
    pass

# TODO: Main monitoring workflow
```

**Success criteria**

- Correctly identifies all real partitions
- Accurate usage calculations
- Proper threshold categorization
- Clean, alerting-system-ready output


---

### 2.2 Process Management

**Concepts:**
- Process creation with subprocess
- Process monitoring with psutil
- Signals and process control
- Daemon processes
- Resource limits (ulimit, cgroups)

📖 **References:** [ORA] Ch.3 pp.57-61, Ch.9 pp.237-243 | [BPB] Ch.2 "Using Python for process management"

**Essential Patterns:**
```python
import subprocess
import signal
import os
from typing import Optional

# Run command and capture output
def run_command(cmd: list[str], timeout: int = 30) -> tuple[int, str, str]:
    """Run command with timeout, return (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"

# Process monitoring with psutil
import psutil

def get_process_info(pid: int) -> Optional[dict]:
    """Get detailed info about a process."""
    try:
        proc = psutil.Process(pid)
        return {
            "pid": pid,
            "name": proc.name(),
            "status": proc.status(),
            "cpu_percent": proc.cpu_percent(),
            "memory_mb": proc.memory_info().rss / (1024 * 1024),
            "connections": len(proc.connections()),
            "open_files": len(proc.open_files()),
        }
    except psutil.NoSuchProcess:
        return None

# Graceful process termination
def terminate_process(pid: int, timeout: int = 10) -> bool:
    """Terminate process gracefully, then forcefully if needed."""
    try:
        proc = psutil.Process(pid)
        proc.terminate()  # SIGTERM
        proc.wait(timeout=timeout)
        return True
    except psutil.TimeoutExpired:
        proc.kill()  # SIGKILL
        return True
    except psutil.NoSuchProcess:
        return False
```

---

🔬 **Micro-Lab 2.2: Process Manager** (30 min)
**Objective** — Build a process monitoring and management tool

**Tasks**

1. List all processes with CPU/memory usage
2. Find processes matching a pattern
3. Implement graceful shutdown with timeout
4. Monitor a process until it exits

**Starter code**

```python
import psutil
import time
from typing import List, Optional, Callable
from dataclasses import dataclass

@dataclass
class ProcessInfo:
    pid: int
    name: str
    cpu_percent: float
    memory_mb: float
    status: str
    username: str

def list_processes(
    sort_by: str = "cpu_percent",
    limit: int = 20
) -> List[ProcessInfo]:
    """List top processes by resource usage."""
    # TODO: Implement
    pass

def find_processes(pattern: str) -> List[ProcessInfo]:
    """Find processes matching name pattern."""
    # TODO: Implement using regex or fnmatch
    pass

def graceful_shutdown(
    pid: int,
    timeout: int = 30,
    on_progress: Optional[Callable] = None
) -> dict:
    """
    Gracefully shutdown a process.
    1. Send SIGTERM
    2. Wait up to timeout
    3. Send SIGKILL if still running

    Returns: {"success": bool, "method": "term"|"kill", "elapsed": float}
    """
    # TODO: Implement
    pass

def monitor_process(
    pid: int,
    interval: float = 1.0,
    callback: Optional[Callable] = None
) -> List[ProcessInfo]:
    """Monitor process until it exits, collecting metrics."""
    # TODO: Implement
    pass

# TODO: Demo workflow
```

**Success criteria**

- Accurate process enumeration
- Pattern matching works correctly
- Graceful shutdown respects timeout
- Monitoring captures metrics over time


---

### 2.3 User and Group Management

**Concepts:**
- User account lifecycle
- Group management
- Password and authentication
- SSH key management
- sudo and privilege escalation

📖 **References:** [BPB] Ch.6 "User management automation"

**Essential Patterns:**
```python
import subprocess
import pwd
import grp
from pathlib import Path
from typing import Optional

def user_exists(username: str) -> bool:
    """Check if user exists on system."""
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False

def create_user(
    username: str,
    groups: list[str] = None,
    shell: str = "/bin/bash",
    create_home: bool = True
) -> bool:
    """Create a new user account."""
    cmd = ["useradd"]
    if create_home:
        cmd.append("-m")
    if shell:
        cmd.extend(["-s", shell])
    if groups:
        cmd.extend(["-G", ",".join(groups)])
    cmd.append(username)

    result = subprocess.run(cmd, capture_output=True)
    return result.returncode == 0

def setup_ssh_key(username: str, public_key: str) -> None:
    """Set up SSH authorized key for user."""
    user_info = pwd.getpwnam(username)
    ssh_dir = Path(user_info.pw_dir) / ".ssh"
    ssh_dir.mkdir(mode=0o700, exist_ok=True)

    auth_keys = ssh_dir / "authorized_keys"
    with open(auth_keys, "a") as f:
        f.write(public_key + "\n")

    auth_keys.chmod(0o600)
    # Change ownership
    import os
    os.chown(ssh_dir, user_info.pw_uid, user_info.pw_gid)
    os.chown(auth_keys, user_info.pw_uid, user_info.pw_gid)
```

---

🔬 **Micro-Lab 2.3: User Provisioning System** (30 min)
**Objective** — Build an automated user provisioning system

**Tasks**

1. Read user definitions from YAML file
2. Create users with specified groups and shell
3. Set up SSH keys from file or URL
4. Generate audit report of changes

**Starter code**

```python
import yaml
import pwd
import subprocess
from pathlib import Path
from typing import List, Dict
from dataclasses import dataclass
from enum import Enum

class ActionResult(Enum):
    CREATED = "created"
    UPDATED = "updated"
    UNCHANGED = "unchanged"
    FAILED = "failed"

@dataclass
class UserSpec:
    username: str
    groups: List[str]
    shell: str
    ssh_keys: List[str]
    state: str = "present"  # or "absent"

@dataclass
class ProvisionResult:
    username: str
    action: ActionResult
    details: str

def load_user_specs(yaml_path: Path) -> List[UserSpec]:
    """Load user specifications from YAML."""
    # TODO: Implement
    pass

def provision_user(spec: UserSpec, dry_run: bool = False) -> ProvisionResult:
    """Provision a single user according to spec."""
    # TODO: Implement
    # - Check if user exists
    # - Create or update as needed
    # - Set up SSH keys
    # - Handle state: absent (remove user)
    pass

def provision_all(
    specs: List[UserSpec],
    dry_run: bool = False
) -> List[ProvisionResult]:
    """Provision all users and return results."""
    # TODO: Implement
    pass

def generate_report(results: List[ProvisionResult]) -> str:
    """Generate human-readable report."""
    # TODO: Implement
    pass

# Sample YAML structure:
# users:
#   - username: deploy
#     groups: [docker, sudo]
#     shell: /bin/bash
#     ssh_keys:
#       - ssh-ed25519 AAAA... deploy@example.com
#   - username: olduser
#     state: absent
```

**Success criteria**

- Correctly parses YAML user specs
- Idempotent operations (running twice = same result)
- Proper dry-run mode
- Comprehensive audit report


---

### 2.4 Service Management with systemd

**Concepts:**
- systemd unit files
- Service states and lifecycle
- Programmatic service control
- Journal log access
- Timer units for scheduling

📖 **References:** [ORA] Ch.5 pp.137-143 | [BPB] Ch.2 "Starting and stopping services"

**Essential Patterns:**
```python
import subprocess
from typing import Optional
from dataclasses import dataclass
from enum import Enum

class ServiceState(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    FAILED = "failed"
    UNKNOWN = "unknown"

@dataclass
class ServiceStatus:
    name: str
    state: ServiceState
    sub_state: str
    pid: Optional[int]
    memory_mb: Optional[float]
    uptime_seconds: Optional[int]

def systemctl(action: str, service: str) -> tuple[bool, str]:
    """Run systemctl command."""
    result = subprocess.run(
        ["systemctl", action, service],
        capture_output=True,
        text=True
    )
    return result.returncode == 0, result.stderr or result.stdout

def get_service_status(service: str) -> ServiceStatus:
    """Get detailed service status."""
    result = subprocess.run(
        ["systemctl", "show", service,
         "--property=ActiveState,SubState,MainPID,MemoryCurrent"],
        capture_output=True,
        text=True
    )
    # Parse properties
    props = dict(line.split("=", 1) for line in result.stdout.strip().split("\n") if "=" in line)

    return ServiceStatus(
        name=service,
        state=ServiceState(props.get("ActiveState", "unknown")),
        sub_state=props.get("SubState", ""),
        pid=int(props["MainPID"]) if props.get("MainPID", "0") != "0" else None,
        memory_mb=int(props.get("MemoryCurrent", 0)) / (1024*1024) or None,
        uptime_seconds=None  # Would need additional parsing
    )

def get_journal_logs(service: str, lines: int = 100) -> list[str]:
    """Get recent journal logs for service."""
    result = subprocess.run(
        ["journalctl", "-u", service, "-n", str(lines), "--no-pager"],
        capture_output=True,
        text=True
    )
    return result.stdout.strip().split("\n")
```

---

🔬 **Micro-Lab 2.4: Service Health Dashboard** (30 min)
**Objective** — Build a service monitoring dashboard

**Tasks**

1. Monitor a list of critical services
2. Collect status, resource usage, and uptime
3. Detect state changes and alert
4. Collect recent errors from journal

**Starter code**

```python
import subprocess
import time
from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime

@dataclass
class ServiceHealth:
    name: str
    is_healthy: bool
    state: str
    cpu_percent: Optional[float] = None
    memory_mb: Optional[float] = None
    error_count: int = 0
    last_errors: List[str] = field(default_factory=list)

def check_service_health(service: str) -> ServiceHealth:
    """Comprehensive health check for a service."""
    # TODO: Implement
    # - Get service state
    # - Get resource usage
    # - Count errors in journal
    # - Get last N error messages
    pass

def monitor_services(
    services: List[str],
    interval: int = 10,
    on_change: Optional[callable] = None
) -> None:
    """Continuously monitor services, call on_change when state changes."""
    previous_states: Dict[str, str] = {}

    while True:
        for service in services:
            # TODO: Check health
            # TODO: Detect state change
            # TODO: Call on_change if changed
            pass
        time.sleep(interval)

def generate_dashboard(healths: List[ServiceHealth]) -> str:
    """Generate ASCII dashboard."""
    # TODO: Create formatted output
    # Service         State      CPU    Memory   Errors
    # nginx           active     2.1%   50 MB    0
    # postgresql      active     15.3%  512 MB   2
    pass

# Services to monitor
CRITICAL_SERVICES = [
    "nginx",
    "postgresql",
    "redis",
    "docker",
]
```

**Success criteria**

- Accurate health status for all services
- Detects and reports state changes
- Collects and displays error logs
- Clean dashboard output


---

### 🧪 Phase 2 Lab: System Administration Toolkit (3-4 hours)

```
OBJECTIVE: Build a comprehensive Linux system administration toolkit

SCENARIO:
You're the automation engineer for a team managing 50+ Linux servers.
Build tools to automate common administration tasks.

REQUIREMENTS:

1. System Info Collector:
   - Gather CPU, memory, disk, network info
   - Detect OS distribution and version
   - List installed packages
   - Export as JSON

2. User Audit Tool:
   - List all users with their groups
   - Find users with sudo access
   - Identify inactive users (no login > 90 days)
   - Find users with weak configurations

3. Service Manager:
   - List all services with status
   - Bulk start/stop/restart operations
   - Health check with configurable criteria
   - Journal log aggregation

4. Security Scanner:
   - Check for world-writable files
   - Find SUID/SGID binaries
   - Check SSH configuration
   - Verify firewall status
   - Report findings with severity

DELIVERABLES:
- [ ] sysinfo.py - System information collector
- [ ] useraudit.py - User audit tool
- [ ] svcmanager.py - Service management tool
- [ ] secscan.py - Security scanner
- [ ] README.md - Usage documentation

BONUS:
- [ ] Unified CLI interface for all tools
- [ ] HTML report generation
- [ ] Ansible inventory generation from sysinfo
```

---

### ⚠️ Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Using `shell=True` unnecessarily | Security risk (injection) | Pass command as list |
| Not checking subprocess return codes | Silent failures | Always check `returncode` |
| Parsing command output with regex | Fragile, locale-dependent | Use `--output` flags or parse `/proc` |
| Running as root unnecessarily | Security risk | Use sudo only when needed |
| Hardcoding paths | Non-portable | Use `/etc/os-release`, `which`, etc. |
| Not handling process zombies | Resource leaks | Always wait() on child processes |

---

### ✅ Checkpoint: Phase 2 Self-Assessment

- [ ] Query and interpret disk usage across partitions
- [ ] Find and manage processes by various criteria
- [ ] Create, modify, and remove user accounts programmatically
- [ ] Control systemd services and read their logs
- [ ] Write scripts that work across different Linux distributions
- [ ] Handle subprocess execution safely with proper error handling
- [ ] Use psutil for detailed system information

---

### 💼 Interview Questions: Phase 2

1. **How would you safely restart a service with zero downtime?**
   <details>
   <summary>Answer</summary>
   Use `systemctl reload` if supported (graceful reload). Otherwise, implement blue-green: start new instance, health check, redirect traffic, stop old instance.
   </details>

2. **What's the difference between subprocess.run() and subprocess.Popen()?**
   <details>
   <summary>Answer</summary>
   `run()` is synchronous and waits for completion. `Popen()` is async - gives you a process object to interact with while running. Use Popen for long-running processes or when you need to stream output.
   </details>

3. **How do you handle log rotation in a long-running Python daemon?**
   <details>
   <summary>Answer</summary>
   Use `logging.handlers.WatchedFileHandler` which detects when log file is rotated and reopens it. Or use `RotatingFileHandler`/`TimedRotatingFileHandler` to handle rotation in Python.
   </details>

---

## Phase 3: Command-Line Tool Development

| | |
|---|---|
| **Skill Level** | Intermediate |
| **Time Estimate** | 1.5 weeks |
| **Prerequisites** | Phase 1-2 |
| **Environment** | 🏠 Local |

### Learning Objectives
By the end of this phase, you will:
- Build professional CLI tools with argument parsing
- Create interactive command-line experiences
- Package and distribute CLI applications
- Implement plugin architectures

---

### 3.1 Argument Parsing with argparse

**Concepts:**
- Positional vs optional arguments
- Subcommands for complex CLIs
- Argument groups and mutual exclusion
- Custom types and validation
- Auto-generated help

📖 **References:** [ORA] Ch.3 pp.65-69 | [BPB] Ch.4 "Command-line argument parsing"

**Professional Pattern:**
```python
import argparse
import sys
from typing import Optional

def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser with all subcommands."""
    parser = argparse.ArgumentParser(
        prog="devops",
        description="DevOps automation toolkit",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  devops deploy web-app --env production
  devops logs api-server --since 1h --level ERROR
  devops health --all --format json
        """
    )

    parser.add_argument(
        "-v", "--verbose",
        action="count",
        default=0,
        help="Increase verbosity (-v, -vv, -vvv)"
    )
    parser.add_argument(
        "--config",
        type=argparse.FileType("r"),
        help="Configuration file"
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Deploy subcommand
    deploy = subparsers.add_parser("deploy", help="Deploy a service")
    deploy.add_argument("service", help="Service to deploy")
    deploy.add_argument("--env", choices=["dev", "staging", "prod"], required=True)
    deploy.add_argument("--version", default="latest")
    deploy.add_argument("--dry-run", action="store_true")

    # Logs subcommand
    logs = subparsers.add_parser("logs", help="View service logs")
    logs.add_argument("service", help="Service name")
    logs.add_argument("--since", default="1h", help="Time range (e.g., 1h, 30m, 2d)")
    logs.add_argument("--level", choices=["DEBUG", "INFO", "WARN", "ERROR"])
    logs.add_argument("-f", "--follow", action="store_true", help="Follow log output")

    return parser

def main(args: Optional[list] = None) -> int:
    """Main entry point."""
    parser = create_parser()
    parsed = parser.parse_args(args)

    if not parsed.command:
        parser.print_help()
        return 1

    # Dispatch to command handlers
    handlers = {
        "deploy": handle_deploy,
        "logs": handle_logs,
    }

    return handlers[parsed.command](parsed)
```

---

🔬 **Micro-Lab 3.1: Multi-Command CLI** (30 min)
**Objective** — Build a server management CLI with subcommands

**Tasks**

1. Create a CLI with these subcommands:
   - list: List servers (with filters)
   - info: Show server details
   - ssh: Connect to server
   - exec: Run command on server(s)
2. Implement common options (--verbose, --config, --format)
3. Add input validation and helpful error messages

**Starter code**

```python
import argparse
import sys
from typing import List, Optional

def add_common_args(parser: argparse.ArgumentParser) -> None:
    """Add common arguments to a parser."""
    # TODO: Add --verbose, --config, --format
    pass

def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="servermgr",
        description="Server management CLI"
    )
    add_common_args(parser)

    subparsers = parser.add_subparsers(dest="command", required=True)

    # TODO: Add 'list' subcommand with --env, --role filters

    # TODO: Add 'info' subcommand with server argument

    # TODO: Add 'ssh' subcommand with server, --user, --port

    # TODO: Add 'exec' subcommand with servers (multiple), --command

    return parser

def handle_list(args) -> int:
    """Handle list command."""
    # TODO: Implement
    pass

def handle_info(args) -> int:
    """Handle info command."""
    # TODO: Implement
    pass

def handle_ssh(args) -> int:
    """Handle ssh command."""
    # TODO: Implement
    pass

def handle_exec(args) -> int:
    """Handle exec command."""
    # TODO: Implement
    pass

def main(argv: Optional[List[str]] = None) -> int:
    parser = create_parser()
    args = parser.parse_args(argv)

    handlers = {
        "list": handle_list,
        "info": handle_info,
        "ssh": handle_ssh,
        "exec": handle_exec,
    }

    return handlers[args.command](args)

if __name__ == "__main__":
    sys.exit(main())
```

**Success criteria**

- All subcommands have appropriate arguments
- Help text is clear and complete
- Invalid input produces helpful errors
- Common options work across all commands


---

### 3.2 Building CLIs with Click

**Concepts:**
- Decorators for command definition
- Automatic help generation
- Option and argument types
- Command groups and nesting
- Context passing

📖 **References:** [ORA] Ch.3 pp.69-73 | [BPB] Ch.4 "Building interactive CLI with click"

**Professional Pattern:**
```python
import click
from typing import Optional

@click.group()
@click.option("-v", "--verbose", count=True, help="Increase verbosity")
@click.option("--config", type=click.Path(exists=True), help="Config file")
@click.pass_context
def cli(ctx: click.Context, verbose: int, config: Optional[str]) -> None:
    """DevOps automation toolkit."""
    ctx.ensure_object(dict)
    ctx.obj["verbose"] = verbose
    ctx.obj["config"] = config

@cli.command()
@click.argument("service")
@click.option("--env", type=click.Choice(["dev", "staging", "prod"]), required=True)
@click.option("--version", default="latest", help="Version to deploy")
@click.option("--dry-run", is_flag=True, help="Show what would be done")
@click.pass_context
def deploy(ctx: click.Context, service: str, env: str, version: str, dry_run: bool) -> None:
    """Deploy a service to an environment."""
    verbose = ctx.obj["verbose"]

    if dry_run:
        click.echo(f"Would deploy {service}:{version} to {env}")
        return

    with click.progressbar(range(100), label="Deploying") as bar:
        for _ in bar:
            import time
            time.sleep(0.02)

    click.secho(f"✓ Deployed {service}:{version} to {env}", fg="green")

@cli.command()
@click.argument("service")
@click.option("--since", default="1h", help="Time range")
@click.option("-f", "--follow", is_flag=True, help="Follow log output")
def logs(service: str, since: str, follow: bool) -> None:
    """View service logs."""
    click.echo(f"Fetching logs for {service} since {since}...")
    # Implementation

if __name__ == "__main__":
    cli()
```

---

🔬 **Micro-Lab 3.2: Interactive Deployment CLI** (30 min)
**Objective** — Build an interactive deployment tool with Click

**Tasks**

1. Create a deployment CLI with interactive prompts
2. Add progress bars for long operations
3. Use colors for status output
4. Implement confirmation prompts for dangerous operations

**Starter code**

```python
import click
import time
from typing import List

@click.group()
@click.version_option(version="1.0.0")
def cli():
    """Deployment automation tool."""
    pass

@cli.command()
@click.argument("service")
@click.option("--env", type=click.Choice(["dev", "staging", "prod"]))
@click.option("--version", prompt="Version to deploy")
@click.option("--force", is_flag=True, help="Skip confirmation")
def deploy(service: str, env: str, version: str, force: bool):
    """Deploy a service."""
    # TODO: If env is prod and not force, confirm
    # TODO: Show deployment progress with progress bar
    # TODO: Use colors for success/failure
    pass

@cli.command()
@click.argument("services", nargs=-1, required=True)
@click.option("--parallel", is_flag=True, help="Deploy in parallel")
def deploy_batch(services: tuple, parallel: bool):
    """Deploy multiple services."""
    # TODO: Show overall progress
    # TODO: Report success/failure for each
    pass

@cli.command()
@click.argument("service")
@click.confirmation_option(prompt="Are you sure you want to rollback?")
def rollback(service: str):
    """Rollback to previous version."""
    # TODO: Implement with status output
    pass

@cli.command()
def interactive():
    """Interactive deployment wizard."""
    # TODO: Use click.prompt for each field
    # service = click.prompt("Service name")
    # env = click.prompt("Environment", type=click.Choice([...]))
    # etc.
    pass

if __name__ == "__main__":
    cli()
```

**Success criteria**

- Interactive prompts work correctly
- Progress bars display accurately
- Colors indicate status clearly
- Confirmations prevent accidental actions


---

### 3.3 Fire for Quick CLI Generation

**Concepts:**
- Automatic CLI from functions/classes
- Zero configuration required
- Type inference from annotations
- Good for rapid prototyping

📖 **References:** [ORA] Ch.3 pp.73-78

**Quick Pattern:**
```python
import fire
from typing import List, Optional
from dataclasses import dataclass

@dataclass
class Server:
    name: str
    ip: str
    env: str

class ServerManager:
    """Server management operations."""

    def __init__(self, config_file: str = "servers.yaml"):
        self.config_file = config_file
        self.servers = self._load_servers()

    def _load_servers(self) -> List[Server]:
        # Load from config
        return []

    def list(self, env: Optional[str] = None, format: str = "table") -> None:
        """List all servers, optionally filtered by environment."""
        servers = self.servers
        if env:
            servers = [s for s in servers if s.env == env]

        for s in servers:
            print(f"{s.name}\t{s.ip}\t{s.env}")

    def info(self, name: str) -> dict:
        """Get detailed info about a server."""
        server = next((s for s in self.servers if s.name == name), None)
        if not server:
            raise ValueError(f"Server {name} not found")
        return {"name": server.name, "ip": server.ip, "env": server.env}

    def deploy(self, service: str, env: str, version: str = "latest") -> str:
        """Deploy a service to servers in an environment."""
        return f"Deployed {service}:{version} to {env}"

if __name__ == "__main__":
    fire.Fire(ServerManager)

# Usage:
# python server_mgr.py list --env=prod
# python server_mgr.py info web-01
# python server_mgr.py deploy api prod --version=2.0.0
```

---

### 3.4 Plugin Architectures

**Concepts:**
- Entry points for extensibility
- Dynamic module loading
- Plugin discovery and registration
- Configuration for plugins

📖 **References:** [ORA] Ch.3 pp.78-79

**Plugin System Pattern:**
```python
import importlib
import pkgutil
from abc import ABC, abstractmethod
from typing import Dict, Type
from pathlib import Path

# Base plugin class
class DeployPlugin(ABC):
    """Base class for deployment plugins."""

    name: str  # Plugin name

    @abstractmethod
    def deploy(self, service: str, version: str, config: dict) -> bool:
        """Execute deployment."""
        pass

    @abstractmethod
    def rollback(self, service: str) -> bool:
        """Rollback deployment."""
        pass

# Plugin registry
class PluginRegistry:
    """Registry for discovering and managing plugins."""

    def __init__(self):
        self._plugins: Dict[str, Type[DeployPlugin]] = {}

    def register(self, plugin_class: Type[DeployPlugin]) -> None:
        """Register a plugin class."""
        self._plugins[plugin_class.name] = plugin_class

    def get(self, name: str) -> Type[DeployPlugin]:
        """Get a plugin by name."""
        if name not in self._plugins:
            raise KeyError(f"Plugin '{name}' not found")
        return self._plugins[name]

    def discover(self, package_name: str) -> None:
        """Discover plugins in a package."""
        package = importlib.import_module(package_name)

        for _, name, _ in pkgutil.iter_modules(package.__path__):
            module = importlib.import_module(f"{package_name}.{name}")

            for attr_name in dir(module):
                attr = getattr(module, attr_name)
                if (isinstance(attr, type) and
                    issubclass(attr, DeployPlugin) and
                    attr is not DeployPlugin):
                    self.register(attr)

# Example plugin
class KubernetesPlugin(DeployPlugin):
    name = "kubernetes"

    def deploy(self, service: str, version: str, config: dict) -> bool:
        print(f"Deploying {service}:{version} to Kubernetes")
        return True

    def rollback(self, service: str) -> bool:
        print(f"Rolling back {service} on Kubernetes")
        return True
```

---

🔬 **Micro-Lab 3.4: Extensible Notification System** (45 min)
**Objective** — Build a plugin-based notification system

**Tasks**

1. Define a NotificationPlugin base class
2. Implement plugins for: Slack, Email, PagerDuty
3. Create a plugin discovery mechanism
4. Build a CLI that uses the plugins

**Starter code**

```python
from abc import ABC, abstractmethod
from typing import Dict, Type, List
from dataclasses import dataclass
import importlib

@dataclass
class Notification:
    title: str
    message: str
    severity: str  # info, warning, critical
    tags: Dict[str, str]

class NotificationPlugin(ABC):
    """Base class for notification plugins."""

    name: str

    @abstractmethod
    def configure(self, config: dict) -> None:
        """Configure the plugin."""
        pass

    @abstractmethod
    def send(self, notification: Notification) -> bool:
        """Send a notification."""
        pass

    @abstractmethod
    def validate_config(self, config: dict) -> List[str]:
        """Validate config, return list of errors."""
        pass

class SlackPlugin(NotificationPlugin):
    name = "slack"

    def configure(self, config: dict) -> None:
        # TODO: Store webhook_url, channel, etc.
        pass

    def send(self, notification: Notification) -> bool:
        # TODO: Send to Slack
        pass

    def validate_config(self, config: dict) -> List[str]:
        # TODO: Check required fields
        pass

# TODO: Implement EmailPlugin

# TODO: Implement PagerDutyPlugin

class NotificationManager:
    """Manages notification plugins."""

    def __init__(self):
        self._plugins: Dict[str, NotificationPlugin] = {}

    def register(self, plugin: NotificationPlugin, config: dict) -> None:
        # TODO: Validate and configure plugin
        pass

    def send_all(self, notification: Notification) -> Dict[str, bool]:
        # TODO: Send to all registered plugins
        pass

    def send_to(self, plugin_name: str, notification: Notification) -> bool:
        # TODO: Send to specific plugin
        pass

# TODO: Build CLI using click
```

**Success criteria**

- Plugins are easily discoverable and registrable
- Each plugin validates its own configuration
- Manager can send to all or specific plugins
- CLI provides interface to all functionality


---

### 🧪 Phase 3 Lab: Complete DevOps CLI Tool (4 hours)

```
OBJECTIVE: Build a production-ready DevOps CLI tool

SCENARIO:
Create a comprehensive CLI tool that your team will use daily
for infrastructure and deployment management.

REQUIREMENTS:

1. Core Features:
   devops config [get|set|list]     # Manage configuration
   devops server [list|info|ssh]    # Server management
   devops deploy [service] [env]    # Deployment
   devops logs [service]            # Log viewing
   devops health [--all|service]    # Health checks

2. Technical Requirements:
   - Use Click for the CLI framework
   - Configuration stored in ~/.devops/config.yaml
   - Support for multiple profiles (dev, staging, prod)
   - JSON and table output formats
   - Verbose/quiet modes
   - Colored output

3. User Experience:
   - Clear, helpful error messages
   - Progress bars for long operations
   - Confirmation for destructive actions
   - Shell completion support

4. Plugin System:
   - Pluggable deployment backends
   - Pluggable notification channels
   - Plugin discovery from entry points

DELIVERABLES:
- [ ] Complete CLI package structure
- [ ] All commands implemented
- [ ] Plugin system working
- [ ] Unit tests for commands
- [ ] Man page or --help documentation
- [ ] Shell completion scripts

BONUS:
- [ ] Publish to PyPI (test.pypi.org)
- [ ] Docker image with CLI installed
```

---

### ✅ Checkpoint: Phase 3 Self-Assessment

- [ ] Build complex CLI tools with argparse
- [ ] Use Click for elegant CLI development
- [ ] Create interactive prompts and progress bars
- [ ] Implement plugin/extension systems
- [ ] Package CLI tools for distribution
- [ ] Write effective help text and documentation

---

## Phase 4: Data Processing and APIs

| | |
|---|---|
| **Skill Level** | Intermediate |
| **Time Estimate** | 1.5 weeks |
| **Prerequisites** | Phase 1-3 |
| **Environment** | 🏠 Local |

### Learning Objectives
By the end of this phase, you will:
- Parse and generate various data formats (JSON, YAML, XML, CSV)
- Interact with REST APIs effectively
- Process and analyze data with pandas
- Implement webhook receivers

---

### 4.1 Working with Data Formats

**Concepts:**
- JSON: parsing, generation, streaming
- YAML: configuration files
- XML: parsing with ElementTree
- CSV: reading, writing, large files
- Data serialization patterns

📖 **References:** [ORA] Ch.2 pp.35-46 | [BPB] Ch.3 "Working with JSON, XML, and CSV"

**Essential Patterns:**
```python
import json
import yaml
from pathlib import Path
from typing import Any, Dict, Iterator
import csv

# JSON handling with custom encoders
from datetime import datetime
from dataclasses import dataclass, asdict

@dataclass
class Deployment:
    service: str
    version: str
    timestamp: datetime
    status: str

class CustomEncoder(json.JSONEncoder):
    def default(self, obj: Any) -> Any:
        if isinstance(obj, datetime):
            return obj.isoformat()
        if hasattr(obj, '__dataclass_fields__'):
            return asdict(obj)
        return super().default(obj)

# Streaming large JSON files
def stream_json_array(path: Path) -> Iterator[dict]:
    """Stream large JSON array without loading entirely."""
    import ijson
    with open(path, "rb") as f:
        for item in ijson.items(f, "item"):
            yield item

# YAML with custom types
def load_yaml_config(path: Path) -> dict:
    """Load YAML config with environment variable substitution."""
    import os
    import re

    content = path.read_text()

    # Substitute ${VAR} and ${VAR:-default}
    def replace_env(match):
        var = match.group(1)
        default = match.group(2)
        return os.environ.get(var, default or "")

    content = re.sub(r'\$\{(\w+)(?::-([^}]*))?\}', replace_env, content)
    return yaml.safe_load(content)
```

---

🔬 **Micro-Lab 4.1: Config Format Converter** (30 min)
**Objective** — Build a config format conversion tool

**Tasks**

1. Convert between JSON, YAML, and TOML
2. Support environment variable substitution
3. Validate against JSON Schema
4. Pretty-print output with options

**Starter code**

```python
import json
import yaml
from pathlib import Path
from typing import Any, Dict

# pip install toml jsonschema

def load_config(path: Path) -> Dict[str, Any]:
    """Load config from any supported format."""
    suffix = path.suffix.lower()
    content = path.read_text()

    # TODO: Detect format and parse
    # Supported: .json, .yaml, .yml, .toml
    pass

def save_config(config: Dict[str, Any], path: Path, **options) -> None:
    """Save config to specified format."""
    # TODO: Format based on extension
    # Options: indent, sort_keys, etc.
    pass

def convert(
    input_path: Path,
    output_path: Path,
    substitute_env: bool = True
) -> None:
    """Convert config from one format to another."""
    # TODO: Load, optionally substitute env vars, save
    pass

def substitute_env_vars(config: Dict[str, Any]) -> Dict[str, Any]:
    """Recursively substitute ${VAR} patterns."""
    # TODO: Implement recursive substitution
    pass

def validate_schema(config: Dict, schema_path: Path) -> List[str]:
    """Validate config against JSON Schema."""
    # TODO: Implement using jsonschema
    pass

# CLI interface
if __name__ == "__main__":
    import argparse
    # TODO: Build CLI
```

**Success criteria**

- All format conversions work correctly
- Environment variables are substituted
- Schema validation reports all errors
- Output is properly formatted


---

### 4.2 REST API Interaction

**Concepts:**
- HTTP methods and status codes
- Authentication methods (API key, OAuth, JWT)
- Rate limiting and retry logic
- Pagination handling
- Error handling

📖 **References:** [BPB] Ch.3 "Working with RESTful APIs", Ch.1 "Interfacing with APIs"

**Professional Patterns:**
```python
import requests
from typing import Any, Dict, Iterator, Optional
from dataclasses import dataclass
import time
from functools import wraps

@dataclass
class APIConfig:
    base_url: str
    api_key: Optional[str] = None
    timeout: int = 30
    max_retries: int = 3

class APIClient:
    """Robust REST API client."""

    def __init__(self, config: APIConfig):
        self.config = config
        self.session = requests.Session()
        if config.api_key:
            self.session.headers["Authorization"] = f"Bearer {config.api_key}"

    def _request(
        self,
        method: str,
        path: str,
        **kwargs
    ) -> requests.Response:
        """Make request with retry logic."""
        url = f"{self.config.base_url}{path}"

        for attempt in range(self.config.max_retries):
            try:
                response = self.session.request(
                    method, url,
                    timeout=self.config.timeout,
                    **kwargs
                )

                # Handle rate limiting
                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", 60))
                    time.sleep(retry_after)
                    continue

                response.raise_for_status()
                return response

            except requests.exceptions.RequestException as e:
                if attempt == self.config.max_retries - 1:
                    raise
                time.sleep(2 ** attempt)

        raise RuntimeError("Max retries exceeded")

    def get(self, path: str, **kwargs) -> Dict[str, Any]:
        return self._request("GET", path, **kwargs).json()

    def post(self, path: str, data: Dict, **kwargs) -> Dict[str, Any]:
        return self._request("POST", path, json=data, **kwargs).json()

    def paginate(
        self,
        path: str,
        page_param: str = "page",
        per_page: int = 100
    ) -> Iterator[Dict]:
        """Paginate through results."""
        page = 1
        while True:
            params = {page_param: page, "per_page": per_page}
            response = self.get(path, params=params)

            items = response.get("items", response.get("data", []))
            if not items:
                break

            yield from items
            page += 1
```

---

🔬 **Micro-Lab 4.2: GitHub API Client** (45 min)
**Objective** — Build a GitHub API client for DevOps tasks

**Tasks**

1. Authenticate using personal access token
2. List repositories with filtering
3. Get commit history for a repo
4. Create and manage issues
5. Handle rate limiting gracefully

**Starter code**

```python
import requests
from typing import Iterator, Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime

@dataclass
class Repository:
    name: str
    full_name: str
    description: Optional[str]
    language: Optional[str]
    stars: int
    updated_at: datetime

@dataclass
class Commit:
    sha: str
    message: str
    author: str
    date: datetime

class GitHubClient:
    BASE_URL = "https://api.github.com"

    def __init__(self, token: str):
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json"
        })

    def _request(self, method: str, path: str, **kwargs) -> requests.Response:
        """Make request with rate limit handling."""
        # TODO: Implement with rate limit checking
        # Check X-RateLimit-Remaining header
        # Sleep if needed based on X-RateLimit-Reset
        pass

    def _paginate(self, path: str, **kwargs) -> Iterator[Dict]:
        """Handle GitHub's Link header pagination."""
        # TODO: Implement following Link: <url>; rel="next"
        pass

    def list_repos(
        self,
        org: Optional[str] = None,
        type: str = "all",
        sort: str = "updated"
    ) -> Iterator[Repository]:
        """List repositories for user or org."""
        # TODO: Implement
        pass

    def get_commits(
        self,
        owner: str,
        repo: str,
        since: Optional[datetime] = None,
        author: Optional[str] = None
    ) -> Iterator[Commit]:
        """Get commits for a repository."""
        # TODO: Implement
        pass

    def create_issue(
        self,
        owner: str,
        repo: str,
        title: str,
        body: str,
        labels: List[str] = None
    ) -> Dict:
        """Create an issue."""
        # TODO: Implement
        pass

    def get_rate_limit(self) -> Dict:
        """Get current rate limit status."""
        # TODO: Implement
        pass

# Demo usage
if __name__ == "__main__":
    import os
    token = os.environ.get("GITHUB_TOKEN")
    client = GitHubClient(token)

    # TODO: Demo various operations
```

**Success criteria**

- Authentication works correctly
- Pagination handles all results
- Rate limiting is respected
- All API operations work


---

### 4.3 Webhook Implementation

**Concepts:**
- Webhook receiver with Flask/FastAPI
- Signature verification
- Event processing
- Retry handling
- Queue integration

**Webhook Receiver Pattern:**
```python
from flask import Flask, request, jsonify
import hmac
import hashlib
import os
from functools import wraps

app = Flask(__name__)

def verify_signature(secret: str):
    """Decorator to verify webhook signatures."""
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            signature = request.headers.get("X-Hub-Signature-256")
            if not signature:
                return jsonify({"error": "Missing signature"}), 401

            expected = "sha256=" + hmac.new(
                secret.encode(),
                request.data,
                hashlib.sha256
            ).hexdigest()

            if not hmac.compare_digest(signature, expected):
                return jsonify({"error": "Invalid signature"}), 401

            return f(*args, **kwargs)
        return wrapper
    return decorator

@app.route("/webhook/github", methods=["POST"])
@verify_signature(os.environ.get("GITHUB_WEBHOOK_SECRET", ""))
def github_webhook():
    """Handle GitHub webhooks."""
    event = request.headers.get("X-GitHub-Event")
    payload = request.json

    handlers = {
        "push": handle_push,
        "pull_request": handle_pr,
        "issues": handle_issue,
    }

    handler = handlers.get(event)
    if handler:
        handler(payload)

    return jsonify({"status": "ok"}), 200

def handle_push(payload: dict) -> None:
    """Handle push events."""
    repo = payload["repository"]["full_name"]
    branch = payload["ref"].split("/")[-1]
    commits = payload["commits"]
    print(f"Push to {repo}/{branch}: {len(commits)} commits")
```

---

### 4.4 Data Analysis with Pandas

**Concepts:**
- DataFrames and Series
- Data loading and export
- Filtering and transformation
- Aggregation and grouping
- Time series analysis

📖 **References:** [BPB] Ch.3 "Data manipulation and analysis using Pandas"

**DevOps Analysis Patterns:**
```python
import pandas as pd
from datetime import datetime, timedelta

# Load deployment history
def load_deployment_data(path: str) -> pd.DataFrame:
    """Load and prepare deployment data."""
    df = pd.read_csv(path, parse_dates=["timestamp"])
    df["duration_seconds"] = pd.to_timedelta(df["duration"]).dt.total_seconds()
    return df

# Deployment frequency analysis
def deployment_frequency(df: pd.DataFrame) -> pd.DataFrame:
    """Calculate deployments per day by service."""
    return df.groupby([
        df["timestamp"].dt.date,
        "service"
    ]).size().unstack(fill_value=0)

# Mean Time to Recovery (MTTR)
def calculate_mttr(incidents: pd.DataFrame) -> float:
    """Calculate MTTR from incident data."""
    incidents["duration"] = (
        incidents["resolved_at"] - incidents["created_at"]
    ).dt.total_seconds() / 3600  # hours
    return incidents["duration"].mean()

# Deployment success rate
def success_rate_by_service(df: pd.DataFrame) -> pd.Series:
    """Calculate deployment success rate by service."""
    return df.groupby("service").apply(
        lambda x: (x["status"] == "success").mean() * 100
    ).round(2)
```

---

🔬 **Micro-Lab 4.4: Deployment Analytics Dashboard** (45 min)
**Objective** — Analyze deployment data and generate reports

**Tasks**

1. Load deployment history from CSV
2. Calculate key metrics:
   - Deployment frequency by service
   - Success/failure rates
   - Average deployment duration
   - Peak deployment times
3. Identify problematic patterns
4. Generate summary report

**Starter code**

```python
import pandas as pd
from pathlib import Path
from typing import Dict
from dataclasses import dataclass

@dataclass
class DeploymentMetrics:
    total_deployments: int
    success_rate: float
    avg_duration_minutes: float
    peak_hour: int
    most_deployed_service: str
    problematic_services: list  # > 20% failure rate

def generate_sample_data(path: Path, n_records: int = 1000) -> None:
    """Generate sample deployment data."""
    import random
    from datetime import datetime, timedelta

    services = ["api", "web", "worker", "scheduler", "cache"]
    environments = ["dev", "staging", "prod"]
    statuses = ["success", "success", "success", "success", "failed"]  # 80% success

    records = []
    base_date = datetime.now() - timedelta(days=90)

    for _ in range(n_records):
        records.append({
            "timestamp": base_date + timedelta(
                days=random.randint(0, 90),
                hours=random.randint(6, 22),
                minutes=random.randint(0, 59)
            ),
            "service": random.choice(services),
            "environment": random.choice(environments),
            "version": f"1.{random.randint(0,9)}.{random.randint(0,99)}",
            "status": random.choice(statuses),
            "duration_seconds": random.randint(30, 600),
            "deployer": f"user{random.randint(1, 5)}"
        })

    pd.DataFrame(records).to_csv(path, index=False)

def load_deployments(path: Path) -> pd.DataFrame:
    """Load and prepare deployment data."""
    # TODO: Load CSV, parse dates, add derived columns
    pass

def calculate_metrics(df: pd.DataFrame) -> DeploymentMetrics:
    """Calculate deployment metrics."""
    # TODO: Implement all metrics
    pass

def deployment_trends(df: pd.DataFrame) -> pd.DataFrame:
    """Get daily deployment trends."""
    # TODO: Group by date, count, success rate
    pass

def identify_issues(df: pd.DataFrame) -> Dict[str, list]:
    """Identify deployment issues and patterns."""
    # TODO: Find:
    # - Services with high failure rates
    # - Times with many failures
    # - Slow deployments
    # - Frequent deployers of failed deploys
    pass

def generate_report(metrics: DeploymentMetrics, issues: Dict) -> str:
    """Generate markdown report."""
    # TODO: Create formatted report
    pass

# Main analysis
if __name__ == "__main__":
    data_path = Path("deployments.csv")

    # Generate sample data if needed
    if not data_path.exists():
        generate_sample_data(data_path)

    df = load_deployments(data_path)
    metrics = calculate_metrics(df)
    issues = identify_issues(df)
    report = generate_report(metrics, issues)
    print(report)
```

**Success criteria**

- All metrics calculated correctly
- Trends show daily patterns
- Issues are accurately identified
- Report is clear and actionable


---

### 🧪 Phase 4 Lab: Infrastructure Metrics Collector (4 hours)

```
OBJECTIVE: Build a metrics collection and analysis system

SCENARIO:
Create a system that collects metrics from various sources, stores them,
and provides analysis and alerting capabilities.

REQUIREMENTS:

1. Data Collection:
   - Collect system metrics (CPU, memory, disk) via psutil
   - Collect application metrics via REST API
   - Receive push metrics via webhook endpoint
   - Store in SQLite or time-series database

2. Data Processing:
   - Normalize metrics from different sources
   - Calculate derived metrics (rates, percentages)
   - Aggregate over time windows
   - Handle missing data

3. Analysis:
   - Calculate statistics (mean, p95, p99)
   - Detect anomalies using simple thresholds
   - Identify trends
   - Compare current vs historical

4. Reporting:
   - Generate JSON/CSV exports
   - Create summary reports
   - Provide CLI for querying

DELIVERABLES:
- [ ] metrics_collector.py - Collection agents
- [ ] metrics_store.py - Storage backend
- [ ] metrics_analyzer.py - Analysis functions
- [ ] webhook_receiver.py - Webhook endpoint
- [ ] metrics_cli.py - Query interface
- [ ] Sample data and tests

BONUS:
- [ ] Prometheus exposition format
- [ ] Grafana dashboard JSON
- [ ] Alerting via Slack/email
```

---

### ✅ Checkpoint: Phase 4 Self-Assessment

- [ ] Parse and generate JSON, YAML, CSV, XML
- [ ] Build robust REST API clients with retry logic
- [ ] Handle API pagination and rate limiting
- [ ] Implement webhook receivers with signature verification
- [ ] Use pandas for data analysis
- [ ] Calculate DevOps metrics (MTTR, deployment frequency, etc.)

---

### 💼 Interview Questions: Phase 4

1. **How would you handle a REST API that has aggressive rate limiting?**
   <details>
   <summary>Answer</summary>
   Check X-RateLimit headers proactively, implement exponential backoff, use a token bucket algorithm, cache responses where appropriate, and batch requests when possible.
   </details>

2. **What's the difference between JSON and YAML for configuration?**
   <details>
   <summary>Answer</summary>
   YAML: human-readable, supports comments, allows references/anchors, cleaner for nested structures. JSON: stricter parsing, universal support, better for data interchange. YAML is preferred for configs, JSON for APIs.
   </details>

3. **How would you secure a webhook endpoint?**
   <details>
   <summary>Answer</summary>
   Verify signatures using HMAC, use HTTPS only, validate Content-Type, implement IP allowlisting if possible, use unique endpoint URLs, log and monitor all requests.
   </details>

---

# PART II: CONTAINERS AND CLOUD
*Estimated Time: 6-8 weeks*

---

## Phase 5: Testing for DevOps

| | |
|---|---|
| **Skill Level** | Intermediate |
| **Time Estimate** | 1.5 weeks |
| **Prerequisites** | Phase 1-4 |
| **Environment** | 🏠 Local |

### Learning Objectives
By the end of this phase, you will:
- Write comprehensive tests with pytest
- Test infrastructure with Testinfra
- Implement test-driven development
- Create CI-ready test suites

---

### 5.1 pytest Fundamentals

**Concepts:**
- Test discovery and organization
- Assertions and matchers
- Fixtures: scope, parametrization
- Mocking and patching
- Test coverage

📖 **References:** [ORA] Ch.8 pp.193-217 | [BPB] Ch.1 "Introduction to TDD"

**Professional Patterns:**
```python
import pytest
from unittest.mock import Mock, patch, MagicMock
from typing import Generator

# Fixture with different scopes
@pytest.fixture(scope="module")
def db_connection():
    """Database connection shared across module."""
    conn = create_connection()
    yield conn
    conn.close()

@pytest.fixture
def mock_api_client():
    """Mock API client for testing."""
    client = Mock()
    client.get.return_value = {"status": "ok", "data": []}
    client.post.return_value = {"id": 123}
    return client

# Parametrized tests
@pytest.mark.parametrize("input,expected", [
    ("v1.0.0", (1, 0, 0)),
    ("v2.1.3", (2, 1, 3)),
    ("v10.20.30", (10, 20, 30)),
])
def test_parse_version(input: str, expected: tuple):
    assert parse_version(input) == expected

# Testing exceptions
def test_invalid_config_raises():
    with pytest.raises(ConfigError) as exc_info:
        load_config("nonexistent.yaml")
    assert "not found" in str(exc_info.value)

# Mocking external services
@patch("mymodule.requests.get")
def test_api_call(mock_get):
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = {"data": "test"}

    result = fetch_data("https://api.example.com/data")

    assert result == {"data": "test"}
    mock_get.assert_called_once()
```

---

🔬 **Micro-Lab 5.1: Test Suite for Deployment Module** (45 min)
**Objective** — Write comprehensive tests for a deployment module

**Tasks**

1. Write unit tests for deployment functions
2. Use fixtures for common test data
3. Mock external dependencies (API, filesystem)
4. Achieve 90%+ code coverage

**Module to test**

```python
# deploy.py
from dataclasses import dataclass
from typing import Optional
import requests

@dataclass
class DeployConfig:
    service: str
    version: str
    environment: str
    replicas: int = 1

class DeploymentError(Exception):
    pass

def validate_config(config: DeployConfig) -> list[str]:
    """Validate deployment configuration."""
    errors = []
    if not config.service:
        errors.append("Service name required")
    if not config.version.startswith("v"):
        errors.append("Version must start with 'v'")
    if config.environment not in ("dev", "staging", "prod"):
        errors.append("Invalid environment")
    if config.replicas < 1:
        errors.append("Replicas must be >= 1")
    return errors

def deploy(config: DeployConfig, api_url: str) -> dict:
    """Execute deployment via API."""
    errors = validate_config(config)
    if errors:
        raise DeploymentError(f"Invalid config: {errors}")

    response = requests.post(
        f"{api_url}/deploy",
        json={
            "service": config.service,
            "version": config.version,
            "env": config.environment,
            "replicas": config.replicas,
        }
    )
    response.raise_for_status()
    return response.json()
```

**Write tests**

```python
# test_deploy.py
import pytest
from unittest.mock import patch, Mock
from deploy import DeployConfig, validate_config, deploy, DeploymentError

# TODO: Create fixtures for valid and invalid configs

# TODO: Test validate_config with various inputs

# TODO: Test deploy success case with mocked API

# TODO: Test deploy with validation errors

# TODO: Test deploy with API errors

# TODO: Test edge cases
```

**Success criteria**

- All validation rules are tested
- API calls are properly mocked
- Error cases are covered
- 90%+ code coverage


---

### 5.2 Infrastructure Testing with Testinfra

**Concepts:**
- System state assertions
- Package, service, file testing
- Remote host testing
- Integration with Ansible/Docker
- CI/CD integration

📖 **References:** [ORA] Ch.8 pp.206-216

**Testinfra Patterns:**
```python
import pytest
import testinfra

# Test with local connection
def test_nginx_installed(host):
    nginx = host.package("nginx")
    assert nginx.is_installed
    assert nginx.version.startswith("1.")

def test_nginx_running(host):
    nginx = host.service("nginx")
    assert nginx.is_running
    assert nginx.is_enabled

def test_nginx_config(host):
    config = host.file("/etc/nginx/nginx.conf")
    assert config.exists
    assert config.is_file
    assert config.user == "root"
    assert config.mode == 0o644
    assert config.contains("worker_processes")

def test_port_listening(host):
    assert host.socket("tcp://0.0.0.0:80").is_listening
    assert host.socket("tcp://0.0.0.0:443").is_listening

# Parametrized host testing
@pytest.fixture(scope="module")
def host(request):
    """Connect to remote host."""
    return testinfra.get_host(
        f"ssh://admin@{request.param}",
        ssh_config="/path/to/ssh_config"
    )

@pytest.mark.parametrize("host", ["web-01", "web-02"], indirect=True)
def test_web_servers(host):
    assert host.service("nginx").is_running
```

---

🔬 **Micro-Lab 5.2: Infrastructure Test Suite** (45 min)
**Objective** — Create infrastructure tests for a web application stack

**Tasks**

1. Test Docker container configuration
2. Verify required services are running
3. Check security configurations
4. Validate network connectivity

**Starter code**

```python
import pytest
import testinfra
import subprocess

@pytest.fixture(scope="module")
def docker_container():
    """Start a test container."""
    container_id = subprocess.check_output([
        "docker", "run", "-d",
        "--name", "test_web",
        "nginx:alpine"
    ]).decode().strip()

    yield container_id

    subprocess.run(["docker", "rm", "-f", container_id])

@pytest.fixture(scope="module")
def host(docker_container):
    """Connect to the container."""
    return testinfra.get_host(f"docker://{docker_container}")

class TestPackages:
    """Test required packages are installed."""

    @pytest.mark.parametrize("package", [
        "nginx",
        "curl",
    ])
    def test_package_installed(self, host, package):
        # TODO: Implement
        pass

class TestServices:
    """Test services are configured correctly."""

    def test_nginx_running(self, host):
        # TODO: Implement
        pass

    def test_nginx_enabled(self, host):
        # TODO: Implement (may need adjustment for Alpine)
        pass

class TestConfiguration:
    """Test configuration files."""

    def test_nginx_conf_exists(self, host):
        # TODO: Implement
        pass

    def test_nginx_conf_valid(self, host):
        # Run nginx -t to validate config
        # TODO: Implement
        pass

    def test_no_default_page(self, host):
        # TODO: Check that default welcome page is removed/replaced
        pass

class TestSecurity:
    """Test security configurations."""

    def test_no_root_process(self, host):
        # TODO: Verify nginx worker processes not running as root
        pass

    def test_sensitive_files_permissions(self, host):
        # TODO: Check permissions on sensitive files
        pass

class TestNetwork:
    """Test network configuration."""

    def test_port_80_listening(self, host):
        # TODO: Implement
        pass

    def test_http_response(self, host):
        # TODO: Use curl to test HTTP response
        pass
```

**Success criteria**

- All tests run against Docker container
- Proper cleanup after tests
- Tests cover packages, services, config, security, network


---

### 🧪 Phase 5 Lab: CI-Ready Test Framework (3-4 hours)

**Objective** — Build a comprehensive test framework for DevOps automation

**Scenario**

Create a test framework that can be used across your team's automation
projects, with CI/CD integration.

**Requirements**

1. Test Framework Structure:
   **`tests/`**

   - `conftest.py` — Shared fixtures
   - `unit/` — Unit tests
     - `test_config.py`
     - `test_deploy.py`
   - `integration/` — Integration tests
     - `test_api.py`
     - `test_database.py`
   - `infrastructure/` — Testinfra tests
     - `test_web_stack.py`
   - `fixtures/` — Test data
     - `configs/`
     - `mocks/`

2. Shared Fixtures:
   - Mock API clients
   - Test configuration loaders
   - Docker container management
   - Temporary directories/files

3. CI Integration:
   - pytest.ini with sensible defaults
   - Coverage configuration
   - Parallel test execution
   - JUnit XML output

4. Test Categories:
   - @pytest.mark.unit
   - @pytest.mark.integration
   - @pytest.mark.infrastructure
   - @pytest.mark.slow

**Deliverables**

- [ ] Complete test directory structure
- [ ] Shared fixtures in conftest.py
- [ ] Sample tests for each category
- [ ] pytest.ini configuration
- [ ] .coveragerc configuration
- [ ] GitHub Actions workflow for tests
- [ ] Makefile with test commands

**Test commands**

  make test           # Run all tests
  make test-unit      # Run unit tests only
  make test-fast      # Run non-slow tests
  make coverage       # Run with coverage report


---

### ✅ Checkpoint: Phase 5 Self-Assessment

- [ ] Write parametrized tests with pytest
- [ ] Use fixtures effectively (scope, dependencies)
- [ ] Mock external dependencies
- [ ] Write infrastructure tests with Testinfra
- [ ] Configure pytest for CI/CD
- [ ] Achieve and maintain code coverage targets

---

## Phase 6: Docker Containerization

| | |
|---|---|
| **Skill Level** | Intermediate |
| **Time Estimate** | 2 weeks |
| **Prerequisites** | Phase 1-5 |
| **Environment** | 🏠 Docker installed locally |

### Learning Objectives
By the end of this phase, you will:
- Write efficient, secure Dockerfiles
- Build and manage Docker images programmatically
- Use Docker Compose for multi-container applications
- Implement Docker in CI/CD pipelines

---

### 6.1 Dockerfile Best Practices

**Concepts:**
- Multi-stage builds
- Layer caching optimization
- Security hardening
- Size optimization
- Build arguments and secrets

📖 **References:** [ORA] Ch.11 pp.275-298 | [BPB] Ch.5 "Containerizing Python applications"

**Optimized Python Dockerfile:**
```dockerfile
# Build stage
FROM python:3.12-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Production stage
FROM python:3.12-slim

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels and install
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache /wheels/*

# Copy application
COPY --chown=appuser:appgroup . .

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')"

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:create_app()"]
```

---

🔬 **Micro-Lab 6.1: Optimized Container Build** (45 min)
**Objective** — Optimize a Python application's Docker image

**Tasks**

1. Start with a naive Dockerfile (500MB+ image)
2. Optimize using multi-stage builds
3. Reduce to under 150MB
4. Add security hardening
5. Implement proper caching

NAIVE DOCKERFILE (optimize this):
```python
FROM python:3.12

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN pip install -r requirements.txt

EXPOSE 8000

CMD ["python", "app.py"]
```

SAMPLE requirements.txt:
```python
flask==3.0.0
gunicorn==21.2.0
psycopg2-binary==2.9.9
requests==2.31.0
pydantic==2.5.0
```

**Optimization checklist**

- [ ] Use slim or alpine base image
- [ ] Multi-stage build for smaller final image
- [ ] Copy requirements.txt before code (caching)
- [ ] Remove unnecessary packages
- [ ] Create non-root user
- [ ] Add .dockerignore
- [ ] Add health check
- [ ] Pin base image version

**Measure**

- Image size before: ____
- Image size after: ____
- Build time before: ____
- Build time after: ____

**Success criteria**

- Final image under 150MB
- Runs as non-root user
- Health check works
- Build uses caching effectively


---

### 6.2 Docker SDK for Python

**Concepts:**
- docker-py library
- Container lifecycle management
- Image building and pushing
- Network and volume management
- Event streaming

📖 **References:** [ORA] Ch.11 | [BPB] Ch.5

**Docker SDK Patterns:**
```python
import docker
from docker.models.containers import Container
from typing import Optional, Iterator
import io

class DockerManager:
    """Manage Docker resources with Python."""

    def __init__(self):
        self.client = docker.from_env()

    def build_image(
        self,
        path: str,
        tag: str,
        build_args: dict = None
    ) -> tuple[str, Iterator]:
        """Build a Docker image."""
        image, logs = self.client.images.build(
            path=path,
            tag=tag,
            buildargs=build_args or {},
            rm=True,
        )
        return image.id, logs

    def run_container(
        self,
        image: str,
        name: str,
        ports: dict = None,
        environment: dict = None,
        volumes: dict = None,
        detach: bool = True,
    ) -> Container:
        """Run a container with specified configuration."""
        return self.client.containers.run(
            image,
            name=name,
            ports=ports,
            environment=environment,
            volumes=volumes,
            detach=detach,
            remove=False,
        )

    def get_container_logs(
        self,
        container_id: str,
        tail: int = 100,
        follow: bool = False
    ) -> Iterator[str]:
        """Get container logs."""
        container = self.client.containers.get(container_id)
        logs = container.logs(
            tail=tail,
            follow=follow,
            stream=True
        )
        for chunk in logs:
            yield chunk.decode("utf-8")

    def container_health(self, container_id: str) -> dict:
        """Get container health status."""
        container = self.client.containers.get(container_id)
        container.reload()

        state = container.attrs["State"]
        return {
            "status": state["Status"],
            "running": state["Running"],
            "health": state.get("Health", {}).get("Status"),
            "started_at": state["StartedAt"],
        }
```

---

🔬 **Micro-Lab 6.2: Container Management Tool** (45 min)
**Objective** — Build a Docker management CLI using docker-py

**Tasks**

1. List containers with filtering
2. Start/stop containers
3. View logs with follow option
4. Execute commands in containers
5. Monitor container stats

**Starter code**

```python
import docker
import click
from typing import Optional
from rich.console import Console
from rich.table import Table

console = Console()

@click.group()
def cli():
    """Docker container management tool."""
    pass

@cli.command()
@click.option("--all", "-a", is_flag=True, help="Show all containers")
@click.option("--format", type=click.Choice(["table", "json"]))
def ps(all: bool, format: str):
    """List containers."""
    client = docker.from_env()
    # TODO: List containers
    # TODO: Display as table or JSON
    pass

@cli.command()
@click.argument("container")
@click.option("--tail", default=100, help="Number of lines")
@click.option("-f", "--follow", is_flag=True, help="Follow output")
def logs(container: str, tail: int, follow: bool):
    """View container logs."""
    # TODO: Implement
    pass

@cli.command()
@click.argument("container")
@click.argument("command", nargs=-1)
def exec(container: str, command: tuple):
    """Execute command in container."""
    # TODO: Implement
    pass

@cli.command()
@click.argument("container")
def stats(container: str):
    """Show container resource usage."""
    # TODO: Show CPU, memory, network I/O
    pass

@cli.command()
@click.argument("containers", nargs=-1)
@click.option("--timeout", default=10)
def stop(containers: tuple, timeout: int):
    """Stop one or more containers."""
    # TODO: Implement with progress
    pass

@cli.command()
@click.argument("pattern")
def cleanup(pattern: str):
    """Remove containers matching pattern."""
    # TODO: Find and remove with confirmation
    pass

if __name__ == "__main__":
    cli()
```

**Success criteria**

- All commands work correctly
- Proper error handling for missing containers
- Follow mode streams logs in real-time
- Stats update continuously


---

### 6.3 Docker Compose with Python

**Concepts:**
- docker-compose file structure
- Service dependencies and ordering
- Environment management
- Volume and network configuration
- Programmatic compose management

📖 **References:** [ORA] Ch.11 pp.283-295 | [BPB] Ch.5 "Docker Compose"

**Docker Compose for Development:**
```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: development
    volumes:
      - .:/app
      - /app/.venv  # Exclude venv
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379/0
      - DEBUG=true
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    command: flask run --host=0.0.0.0 --reload

  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=app
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  worker:
    build:
      context: .
      target: development
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    command: celery -A app.celery worker --loglevel=info

volumes:
  postgres_data:
  redis_data:
```

**Managing Compose with Python:**
```python
import subprocess
import yaml
from pathlib import Path
from typing import List, Optional

class ComposeManager:
    """Manage docker-compose projects."""

    def __init__(self, compose_file: Path):
        self.compose_file = compose_file
        self.project_dir = compose_file.parent

    def _run(self, *args, capture: bool = False) -> subprocess.CompletedProcess:
        """Run docker-compose command."""
        cmd = ["docker-compose", "-f", str(self.compose_file)] + list(args)
        return subprocess.run(
            cmd,
            cwd=self.project_dir,
            capture_output=capture,
            text=True
        )

    def up(self, services: List[str] = None, detach: bool = True) -> None:
        """Start services."""
        args = ["up"]
        if detach:
            args.append("-d")
        if services:
            args.extend(services)
        self._run(*args)

    def down(self, volumes: bool = False) -> None:
        """Stop and remove services."""
        args = ["down"]
        if volumes:
            args.append("-v")
        self._run(*args)

    def logs(self, service: str = None, follow: bool = False, tail: int = 100):
        """Get service logs."""
        args = ["logs", f"--tail={tail}"]
        if follow:
            args.append("-f")
        if service:
            args.append(service)
        self._run(*args)

    def get_services(self) -> List[str]:
        """Get list of defined services."""
        with open(self.compose_file) as f:
            config = yaml.safe_load(f)
        return list(config.get("services", {}).keys())

    def service_status(self, service: str) -> dict:
        """Get status of a service."""
        result = self._run("ps", service, capture=True)
        # Parse output
        return {"output": result.stdout}
```

---

### 🧪 Phase 6 Lab: Containerized Development Environment (4 hours)

```
OBJECTIVE: Create a complete containerized development environment

SCENARIO:
Build a containerized stack for a Python web application with:
- Web application (Flask/FastAPI)
- Background worker (Celery)
- Database (PostgreSQL)
- Cache (Redis)
- Message queue (RabbitMQ)

REQUIREMENTS:

1. Dockerfiles:
   - Multi-stage build for production
   - Development target with hot reload
   - Properly sized images
   - Security hardening

2. Docker Compose:
   - Development environment (docker-compose.yml)
   - Production environment (docker-compose.prod.yml)
   - Override file for local development

3. Management Scripts:
   - dev.py - Development environment management
     - start/stop/restart
     - logs viewing
     - database migrations
     - shell access

4. Health Monitoring:
   - Health check endpoints
   - Container health checks
   - Simple monitoring script

DELIVERABLES:
- [ ] Dockerfile with multi-stage build
- [ ] docker-compose.yml for development
- [ ] docker-compose.prod.yml for production
- [ ] docker-compose.override.yml for local
- [ ] dev.py management script
- [ ] Sample application code
- [ ] README with setup instructions

BONUS:
- [ ] GitHub Actions for building images
- [ ] Automated vulnerability scanning
- [ ] Local Kubernetes testing with kind
```

---

### ✅ Checkpoint: Phase 6 Self-Assessment

- [ ] Write optimized, multi-stage Dockerfiles
- [ ] Reduce image size to under 150MB for Python apps
- [ ] Use docker-py for container management
- [ ] Create complete docker-compose environments
- [ ] Implement proper health checks
- [ ] Build images in CI/CD pipelines

---

---

## 📘 Phase 7: Kubernetes Orchestration with Python

| Attribute | Value |
|-----------|-------|
| **Skill Level** | Advanced |
| **Time Estimate** | 6-8 weeks |
| **Prerequisites** | Phase 6 (Docker Mastery) |
| **Environment** | Local (minikube/kind) + Cloud Kubernetes |

### Learning Objectives
By the end of this phase, you will be able to:
- Deploy and manage Kubernetes clusters programmatically
- Use the official Kubernetes Python client for automation
- Create custom operators and controllers
- Implement GitOps workflows
- Build Helm charts and manage releases with Python

### 7.1 Kubernetes Fundamentals for DevOps
**📖 References:** [ORA: Ch.9-10], [BPB: Ch.14]

**Core Concepts:**

- Architecture
  - Control Plane (API Server, etcd, Scheduler, Controller Manager)
  - Worker Nodes (kubelet, kube-proxy, Container Runtime)
  - Networking (CNI, Services, Ingress)
- Workloads
  - Pods (basic unit)
  - Deployments (declarative updates)
  - StatefulSets (stateful applications)
  - DaemonSets (node-level services)
  - Jobs/CronJobs (batch processing)
- Configuration
  - ConfigMaps
  - Secrets
  - Resource Quotas
- Storage
  - Persistent Volumes (PV)
  - Persistent Volume Claims (PVC)
  - Storage Classes


**Setting Up Local Kubernetes:**
```python
#!/usr/bin/env python3
"""
Local Kubernetes cluster management with kind (Kubernetes in Docker)
"""
import subprocess
import yaml
import time
from pathlib import Path

class KindClusterManager:
    """Manage kind clusters for local development."""

    def __init__(self, cluster_name: str = "devops-lab"):
        self.cluster_name = cluster_name
        self.kubeconfig = Path.home() / ".kube" / f"kind-{cluster_name}"

    def create_cluster(self, nodes: int = 3, with_registry: bool = True):
        """Create a multi-node kind cluster."""
        config = {
            "kind": "Cluster",
            "apiVersion": "kind.x-k8s.io/v1alpha4",
            "nodes": [
                {"role": "control-plane"},
                *[{"role": "worker"} for _ in range(nodes - 1)]
            ],
            "containerdConfigPatches": [
                """
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
  endpoint = ["http://kind-registry:5000"]
"""
            ] if with_registry else []
        }

        config_file = Path(f"/tmp/{self.cluster_name}-config.yaml")
        config_file.write_text(yaml.dump(config))

        # Create local registry if requested
        if with_registry:
            self._create_local_registry()

        # Create the cluster
        subprocess.run([
            "kind", "create", "cluster",
            "--name", self.cluster_name,
            "--config", str(config_file),
            "--kubeconfig", str(self.kubeconfig)
        ], check=True)

        if with_registry:
            self._connect_registry_to_cluster()

        print(f"✅ Cluster '{self.cluster_name}' created!")
        print(f"   KUBECONFIG: {self.kubeconfig}")
        return self.kubeconfig

    def _create_local_registry(self):
        """Create a local Docker registry for the cluster."""
        registry_name = "kind-registry"

        # Check if registry exists
        result = subprocess.run(
            ["docker", "inspect", registry_name],
            capture_output=True
        )

        if result.returncode != 0:
            subprocess.run([
                "docker", "run", "-d",
                "--restart=always",
                "-p", "5000:5000",
                "--name", registry_name,
                "registry:2"
            ], check=True)
            print("📦 Local registry created at localhost:5000")

    def _connect_registry_to_cluster(self):
        """Connect the local registry to the kind network."""
        subprocess.run([
            "docker", "network", "connect",
            "kind", "kind-registry"
        ], capture_output=True)  # May already be connected

    def delete_cluster(self):
        """Delete the kind cluster."""
        subprocess.run([
            "kind", "delete", "cluster",
            "--name", self.cluster_name
        ], check=True)
        print(f"🗑️ Cluster '{self.cluster_name}' deleted")

    def get_nodes(self) -> list:
        """List all nodes in the cluster."""
        result = subprocess.run(
            ["kubectl", "--kubeconfig", str(self.kubeconfig),
             "get", "nodes", "-o", "json"],
            capture_output=True, text=True, check=True
        )
        import json
        data = json.loads(result.stdout)
        return [node["metadata"]["name"] for node in data.get("items", [])]


if __name__ == "__main__":
    manager = KindClusterManager("devops-lab")
    manager.create_cluster(nodes=3, with_registry=True)
```

### 7.2 Kubernetes Python Client
**📖 References:** [ORA: Ch.10], [BPB: Ch.14]

```python
#!/usr/bin/env python3
"""
Kubernetes Python Client - Core Operations
pip install kubernetes
"""
from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException
import yaml
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime

@dataclass
class PodStatus:
    """Structured pod status information."""
    name: str
    namespace: str
    phase: str
    ready: bool
    restarts: int
    age: str
    node: str

class KubernetesManager:
    """
    Comprehensive Kubernetes cluster management.

    This class provides a Pythonic interface to common
    Kubernetes operations for DevOps automation.
    """

    def __init__(self, kubeconfig: Optional[str] = None, context: Optional[str] = None):
        """
        Initialize Kubernetes client.

        Args:
            kubeconfig: Path to kubeconfig file (uses default if None)
            context: Kubernetes context to use
        """
        if kubeconfig:
            config.load_kube_config(config_file=kubeconfig, context=context)
        else:
            try:
                config.load_incluster_config()  # Running inside cluster
            except config.ConfigException:
                config.load_kube_config(context=context)  # Running locally

        self.core_v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.batch_v1 = client.BatchV1Api()
        self.networking_v1 = client.NetworkingV1Api()
        self.custom_objects = client.CustomObjectsApi()

    # ==================== Namespace Operations ====================

    def create_namespace(self, name: str, labels: Dict[str, str] = None) -> bool:
        """Create a new namespace."""
        namespace = client.V1Namespace(
            metadata=client.V1ObjectMeta(
                name=name,
                labels=labels or {}
            )
        )
        try:
            self.core_v1.create_namespace(body=namespace)
            print(f"✅ Namespace '{name}' created")
            return True
        except ApiException as e:
            if e.status == 409:
                print(f"⚠️ Namespace '{name}' already exists")
                return True
            raise

    def delete_namespace(self, name: str) -> bool:
        """Delete a namespace and all its resources."""
        try:
            self.core_v1.delete_namespace(name=name)
            print(f"🗑️ Namespace '{name}' marked for deletion")
            return True
        except ApiException as e:
            if e.status == 404:
                print(f"⚠️ Namespace '{name}' not found")
                return False
            raise

    # ==================== Pod Operations ====================

    def list_pods(self, namespace: str = "default",
                  label_selector: str = None) -> List[PodStatus]:
        """List all pods with detailed status."""
        pods = self.core_v1.list_namespaced_pod(
            namespace=namespace,
            label_selector=label_selector
        )

        result = []
        for pod in pods.items:
            # Calculate age
            created = pod.metadata.creation_timestamp
            age = datetime.now(created.tzinfo) - created
            age_str = self._format_age(age)

            # Get restart count
            restarts = 0
            if pod.status.container_statuses:
                restarts = sum(c.restart_count for c in pod.status.container_statuses)

            # Check readiness
            ready = all(
                c.ready for c in (pod.status.container_statuses or [])
            )

            result.append(PodStatus(
                name=pod.metadata.name,
                namespace=pod.metadata.namespace,
                phase=pod.status.phase,
                ready=ready,
                restarts=restarts,
                age=age_str,
                node=pod.spec.node_name or "Pending"
            ))

        return result

    def get_pod_logs(self, name: str, namespace: str = "default",
                     container: str = None, tail_lines: int = 100,
                     previous: bool = False) -> str:
        """Get logs from a pod."""
        return self.core_v1.read_namespaced_pod_log(
            name=name,
            namespace=namespace,
            container=container,
            tail_lines=tail_lines,
            previous=previous
        )

    def exec_in_pod(self, name: str, namespace: str, command: List[str],
                    container: str = None) -> str:
        """Execute a command in a pod."""
        from kubernetes.stream import stream

        resp = stream(
            self.core_v1.connect_get_namespaced_pod_exec,
            name=name,
            namespace=namespace,
            container=container,
            command=command,
            stderr=True,
            stdin=False,
            stdout=True,
            tty=False
        )
        return resp

    # ==================== Deployment Operations ====================

    def create_deployment(self, name: str, namespace: str,
                         image: str, replicas: int = 1,
                         port: int = 80, env: Dict[str, str] = None,
                         resources: Dict = None) -> bool:
        """Create a deployment with best practices."""

        # Default resource limits
        if resources is None:
            resources = {
                "requests": {"cpu": "100m", "memory": "128Mi"},
                "limits": {"cpu": "500m", "memory": "512Mi"}
            }

        # Environment variables
        env_vars = [
            client.V1EnvVar(name=k, value=v)
            for k, v in (env or {}).items()
        ]

        # Container spec
        container = client.V1Container(
            name=name,
            image=image,
            ports=[client.V1ContainerPort(container_port=port)],
            env=env_vars,
            resources=client.V1ResourceRequirements(
                requests=resources.get("requests"),
                limits=resources.get("limits")
            ),
            liveness_probe=client.V1Probe(
                http_get=client.V1HTTPGetAction(
                    path="/health",
                    port=port
                ),
                initial_delay_seconds=10,
                period_seconds=10
            ),
            readiness_probe=client.V1Probe(
                http_get=client.V1HTTPGetAction(
                    path="/ready",
                    port=port
                ),
                initial_delay_seconds=5,
                period_seconds=5
            )
        )

        # Pod template
        template = client.V1PodTemplateSpec(
            metadata=client.V1ObjectMeta(
                labels={"app": name}
            ),
            spec=client.V1PodSpec(
                containers=[container],
                security_context=client.V1PodSecurityContext(
                    run_as_non_root=True,
                    run_as_user=1000
                )
            )
        )

        # Deployment spec
        spec = client.V1DeploymentSpec(
            replicas=replicas,
            selector=client.V1LabelSelector(
                match_labels={"app": name}
            ),
            template=template,
            strategy=client.V1DeploymentStrategy(
                type="RollingUpdate",
                rolling_update=client.V1RollingUpdateDeployment(
                    max_surge="25%",
                    max_unavailable="25%"
                )
            )
        )

        # Deployment object
        deployment = client.V1Deployment(
            api_version="apps/v1",
            kind="Deployment",
            metadata=client.V1ObjectMeta(name=name),
            spec=spec
        )

        try:
            self.apps_v1.create_namespaced_deployment(
                namespace=namespace,
                body=deployment
            )
            print(f"✅ Deployment '{name}' created in '{namespace}'")
            return True
        except ApiException as e:
            if e.status == 409:
                print(f"⚠️ Deployment '{name}' already exists, updating...")
                self.apps_v1.patch_namespaced_deployment(
                    name=name,
                    namespace=namespace,
                    body=deployment
                )
                return True
            raise

    def scale_deployment(self, name: str, namespace: str, replicas: int) -> bool:
        """Scale a deployment to the specified number of replicas."""
        patch = {"spec": {"replicas": replicas}}
        self.apps_v1.patch_namespaced_deployment_scale(
            name=name,
            namespace=namespace,
            body=patch
        )
        print(f"📈 Deployment '{name}' scaled to {replicas} replicas")
        return True

    def rollout_restart(self, name: str, namespace: str) -> bool:
        """Trigger a rolling restart of a deployment."""
        patch = {
            "spec": {
                "template": {
                    "metadata": {
                        "annotations": {
                            "kubectl.kubernetes.io/restartedAt": datetime.utcnow().isoformat()
                        }
                    }
                }
            }
        }
        self.apps_v1.patch_namespaced_deployment(
            name=name,
            namespace=namespace,
            body=patch
        )
        print(f"🔄 Deployment '{name}' restarting...")
        return True

    def get_deployment_status(self, name: str, namespace: str) -> Dict:
        """Get detailed deployment status."""
        deployment = self.apps_v1.read_namespaced_deployment(
            name=name,
            namespace=namespace
        )

        return {
            "name": deployment.metadata.name,
            "replicas": {
                "desired": deployment.spec.replicas,
                "ready": deployment.status.ready_replicas or 0,
                "available": deployment.status.available_replicas or 0,
                "unavailable": deployment.status.unavailable_replicas or 0
            },
            "image": deployment.spec.template.spec.containers[0].image,
            "strategy": deployment.spec.strategy.type,
            "conditions": [
                {
                    "type": c.type,
                    "status": c.status,
                    "reason": c.reason
                }
                for c in (deployment.status.conditions or [])
            ]
        }

    # ==================== Service Operations ====================

    def create_service(self, name: str, namespace: str, port: int,
                       target_port: int = None, service_type: str = "ClusterIP") -> bool:
        """Create a Kubernetes service."""
        service = client.V1Service(
            metadata=client.V1ObjectMeta(name=name),
            spec=client.V1ServiceSpec(
                selector={"app": name},
                ports=[client.V1ServicePort(
                    port=port,
                    target_port=target_port or port
                )],
                type=service_type
            )
        )

        try:
            self.core_v1.create_namespaced_service(
                namespace=namespace,
                body=service
            )
            print(f"✅ Service '{name}' created")
            return True
        except ApiException as e:
            if e.status == 409:
                print(f"⚠️ Service '{name}' already exists")
                return True
            raise

    # ==================== ConfigMap & Secret Operations ====================

    def create_configmap(self, name: str, namespace: str,
                         data: Dict[str, str]) -> bool:
        """Create or update a ConfigMap."""
        configmap = client.V1ConfigMap(
            metadata=client.V1ObjectMeta(name=name),
            data=data
        )

        try:
            self.core_v1.create_namespaced_config_map(
                namespace=namespace,
                body=configmap
            )
            print(f"✅ ConfigMap '{name}' created")
        except ApiException as e:
            if e.status == 409:
                self.core_v1.replace_namespaced_config_map(
                    name=name,
                    namespace=namespace,
                    body=configmap
                )
                print(f"🔄 ConfigMap '{name}' updated")
        return True

    def create_secret(self, name: str, namespace: str,
                      data: Dict[str, str], secret_type: str = "Opaque") -> bool:
        """Create or update a Secret (data should be base64 encoded)."""
        import base64

        encoded_data = {
            k: base64.b64encode(v.encode()).decode()
            for k, v in data.items()
        }

        secret = client.V1Secret(
            metadata=client.V1ObjectMeta(name=name),
            type=secret_type,
            data=encoded_data
        )

        try:
            self.core_v1.create_namespaced_secret(
                namespace=namespace,
                body=secret
            )
            print(f"✅ Secret '{name}' created")
        except ApiException as e:
            if e.status == 409:
                self.core_v1.replace_namespaced_secret(
                    name=name,
                    namespace=namespace,
                    body=secret
                )
                print(f"🔄 Secret '{name}' updated")
        return True

    # ==================== Watch Events ====================

    def watch_pods(self, namespace: str = "default", timeout: int = 60):
        """Watch pod events in real-time."""
        w = watch.Watch()
        print(f"👀 Watching pods in '{namespace}' (timeout: {timeout}s)...")

        for event in w.stream(
            self.core_v1.list_namespaced_pod,
            namespace=namespace,
            timeout_seconds=timeout
        ):
            event_type = event["type"]
            pod = event["object"]
            print(f"  {event_type}: {pod.metadata.name} - {pod.status.phase}")

    # ==================== Utility Methods ====================

    def _format_age(self, delta) -> str:
        """Format a timedelta as a human-readable age string."""
        seconds = int(delta.total_seconds())
        if seconds < 60:
            return f"{seconds}s"
        elif seconds < 3600:
            return f"{seconds // 60}m"
        elif seconds < 86400:
            return f"{seconds // 3600}h"
        else:
            return f"{seconds // 86400}d"

    def apply_yaml(self, yaml_file: str, namespace: str = "default") -> bool:
        """Apply a YAML manifest file."""
        from kubernetes import utils

        with open(yaml_file) as f:
            docs = list(yaml.safe_load_all(f))

        for doc in docs:
            if doc is None:
                continue
            utils.create_from_dict(
                client.ApiClient(),
                doc,
                namespace=namespace
            )

        print(f"✅ Applied {yaml_file}")
        return True


# Example usage
if __name__ == "__main__":
    k8s = KubernetesManager()

    # Create namespace
    k8s.create_namespace("demo-app", labels={"env": "development"})

    # Deploy application
    k8s.create_deployment(
        name="web-app",
        namespace="demo-app",
        image="nginx:alpine",
        replicas=3,
        port=80,
        env={"APP_ENV": "development"}
    )

    # Create service
    k8s.create_service("web-app", "demo-app", port=80)

    # Check status
    status = k8s.get_deployment_status("web-app", "demo-app")
    print(f"\nDeployment Status: {status}")

    # List pods
    pods = k8s.list_pods("demo-app")
    for pod in pods:
        print(f"  {pod.name}: {pod.phase} (restarts: {pod.restarts})")
```

### 7.3 Helm Chart Management with Python
**📖 References:** [ORA: Ch.10], [BPB: Ch.14]

```python
#!/usr/bin/env python3
"""
Helm Chart Management with Python
Manage Helm releases programmatically
"""
import subprocess
import json
import yaml
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass

@dataclass
class HelmRelease:
    """Represents a Helm release."""
    name: str
    namespace: str
    revision: int
    status: str
    chart: str
    app_version: str

class HelmManager:
    """
    Manage Helm charts and releases programmatically.

    Requires helm CLI to be installed.
    """

    def __init__(self, kubeconfig: Optional[str] = None):
        self.kubeconfig = kubeconfig
        self._verify_helm()

    def _verify_helm(self):
        """Verify Helm is installed."""
        try:
            subprocess.run(["helm", "version"], capture_output=True, check=True)
        except FileNotFoundError:
            raise RuntimeError("Helm CLI not found. Please install Helm first.")

    def _run_helm(self, args: List[str], capture_output: bool = True) -> subprocess.CompletedProcess:
        """Run a Helm command."""
        cmd = ["helm"] + args
        if self.kubeconfig:
            cmd.extend(["--kubeconfig", self.kubeconfig])

        return subprocess.run(
            cmd,
            capture_output=capture_output,
            text=True,
            check=True
        )

    # ==================== Repository Management ====================

    def add_repo(self, name: str, url: str) -> bool:
        """Add a Helm repository."""
        try:
            self._run_helm(["repo", "add", name, url])
            self._run_helm(["repo", "update"])
            print(f"✅ Repository '{name}' added: {url}")
            return True
        except subprocess.CalledProcessError:
            print(f"⚠️ Repository '{name}' may already exist")
            return True

    def update_repos(self) -> bool:
        """Update all Helm repositories."""
        self._run_helm(["repo", "update"])
        print("✅ Helm repositories updated")
        return True

    def search_charts(self, keyword: str) -> List[Dict]:
        """Search for charts in repositories."""
        result = self._run_helm([
            "search", "repo", keyword, "-o", "json"
        ])
        return json.loads(result.stdout)

    # ==================== Release Management ====================

    def install(self, release_name: str, chart: str, namespace: str = "default",
                values: Dict = None, values_file: str = None,
                version: str = None, wait: bool = True,
                timeout: str = "5m") -> bool:
        """
        Install a Helm chart.

        Args:
            release_name: Name for the release
            chart: Chart reference (repo/chart or path)
            namespace: Target namespace
            values: Dictionary of values to set
            values_file: Path to values.yaml file
            version: Specific chart version
            wait: Wait for resources to be ready
            timeout: Timeout for wait
        """
        args = ["install", release_name, chart, "-n", namespace, "--create-namespace"]

        if version:
            args.extend(["--version", version])

        if values_file:
            args.extend(["-f", values_file])

        if values:
            for key, value in self._flatten_dict(values).items():
                args.extend(["--set", f"{key}={value}"])

        if wait:
            args.extend(["--wait", "--timeout", timeout])

        args.extend(["-o", "json"])

        result = self._run_helm(args)
        print(f"✅ Installed '{release_name}' in namespace '{namespace}'")
        return True

    def upgrade(self, release_name: str, chart: str, namespace: str = "default",
                values: Dict = None, values_file: str = None,
                version: str = None, install: bool = True,
                wait: bool = True) -> bool:
        """
        Upgrade a Helm release.

        Args:
            release_name: Name of the release
            chart: Chart reference
            namespace: Target namespace
            values: Dictionary of values to set
            values_file: Path to values.yaml file
            version: Specific chart version
            install: Install if release doesn't exist
            wait: Wait for resources to be ready
        """
        args = ["upgrade", release_name, chart, "-n", namespace]

        if install:
            args.append("--install")

        if version:
            args.extend(["--version", version])

        if values_file:
            args.extend(["-f", values_file])

        if values:
            for key, value in self._flatten_dict(values).items():
                args.extend(["--set", f"{key}={value}"])

        if wait:
            args.append("--wait")

        self._run_helm(args)
        print(f"✅ Upgraded '{release_name}'")
        return True

    def uninstall(self, release_name: str, namespace: str = "default") -> bool:
        """Uninstall a Helm release."""
        self._run_helm(["uninstall", release_name, "-n", namespace])
        print(f"🗑️ Uninstalled '{release_name}'")
        return True

    def list_releases(self, namespace: str = None, all_namespaces: bool = False) -> List[HelmRelease]:
        """List Helm releases."""
        args = ["list", "-o", "json"]

        if all_namespaces:
            args.append("-A")
        elif namespace:
            args.extend(["-n", namespace])

        result = self._run_helm(args)
        releases = json.loads(result.stdout)

        return [
            HelmRelease(
                name=r["name"],
                namespace=r["namespace"],
                revision=int(r["revision"]),
                status=r["status"],
                chart=r["chart"],
                app_version=r.get("app_version", "")
            )
            for r in releases
        ]

    def get_values(self, release_name: str, namespace: str = "default",
                   all_values: bool = False) -> Dict:
        """Get values for a release."""
        args = ["get", "values", release_name, "-n", namespace, "-o", "json"]
        if all_values:
            args.append("-a")

        result = self._run_helm(args)
        return json.loads(result.stdout) if result.stdout.strip() else {}

    def rollback(self, release_name: str, revision: int = 0,
                 namespace: str = "default") -> bool:
        """
        Rollback a release to a previous revision.

        Args:
            release_name: Name of the release
            revision: Revision number (0 = previous)
            namespace: Target namespace
        """
        args = ["rollback", release_name, str(revision), "-n", namespace]
        self._run_helm(args)
        print(f"⏪ Rolled back '{release_name}' to revision {revision or 'previous'}")
        return True

    def history(self, release_name: str, namespace: str = "default") -> List[Dict]:
        """Get release history."""
        result = self._run_helm([
            "history", release_name, "-n", namespace, "-o", "json"
        ])
        return json.loads(result.stdout)

    # ==================== Chart Development ====================

    def create_chart(self, name: str, path: str = ".") -> Path:
        """Create a new Helm chart scaffold."""
        self._run_helm(["create", name], capture_output=False)
        chart_path = Path(path) / name
        print(f"✅ Created chart at {chart_path}")
        return chart_path

    def lint_chart(self, chart_path: str) -> bool:
        """Lint a Helm chart."""
        try:
            self._run_helm(["lint", chart_path])
            print(f"✅ Chart '{chart_path}' passed linting")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Chart linting failed: {e.stderr}")
            return False

    def template(self, release_name: str, chart_path: str,
                 values: Dict = None, namespace: str = "default") -> str:
        """Render chart templates locally."""
        args = ["template", release_name, chart_path, "-n", namespace]

        if values:
            for key, value in self._flatten_dict(values).items():
                args.extend(["--set", f"{key}={value}"])

        result = self._run_helm(args)
        return result.stdout

    def package_chart(self, chart_path: str, destination: str = ".") -> str:
        """Package a chart into a .tgz archive."""
        result = self._run_helm(["package", chart_path, "-d", destination])
        # Parse the output to get the package path
        output = result.stdout.strip()
        print(f"📦 {output}")
        return output

    # ==================== Utility Methods ====================

    def _flatten_dict(self, d: Dict, parent_key: str = "") -> Dict:
        """Flatten a nested dictionary for Helm --set values."""
        items = []
        for k, v in d.items():
            new_key = f"{parent_key}.{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(self._flatten_dict(v, new_key).items())
            elif isinstance(v, list):
                for i, item in enumerate(v):
                    if isinstance(item, dict):
                        items.extend(self._flatten_dict(item, f"{new_key}[{i}]").items())
                    else:
                        items.append((f"{new_key}[{i}]", item))
            else:
                items.append((new_key, v))
        return dict(items)


# Example usage
if __name__ == "__main__":
    helm = HelmManager()

    # Add common repositories
    helm.add_repo("bitnami", "https://charts.bitnami.com/bitnami")
    helm.add_repo("prometheus-community",
                  "https://prometheus-community.github.io/helm-charts")

    # Install nginx ingress controller
    helm.install(
        release_name="ingress-nginx",
        chart="bitnami/nginx-ingress-controller",
        namespace="ingress-system",
        values={
            "replicaCount": 2,
            "service": {"type": "LoadBalancer"}
        }
    )

    # List releases
    releases = helm.list_releases(all_namespaces=True)
    for release in releases:
        print(f"  {release.name}: {release.status} ({release.chart})")
```

---

### 🔬 Micro-Lab 7.1: Deploy Application to Kubernetes (30 min)

**Objective:** Deploy a multi-tier application using the Kubernetes Python client

**Step-by-Step Instructions:**

```python
# k8s_deploy_lab.py
"""
Lab: Deploy a web application with database to Kubernetes
"""
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import time

def deploy_complete_app():
    """Deploy a complete application stack."""
    config.load_kube_config()

    core_v1 = client.CoreV1Api()
    apps_v1 = client.AppsV1Api()

    namespace = "lab-app"

    # Step 1: Create namespace
    print("Step 1: Creating namespace...")
    # TODO: Create the namespace using core_v1.create_namespace()

    # Step 2: Create ConfigMap for app configuration
    print("Step 2: Creating ConfigMap...")
    # TODO: Create a ConfigMap with database connection settings

    # Step 3: Create Secret for database credentials
    print("Step 3: Creating Secret...")
    # TODO: Create a Secret with database password

    # Step 4: Deploy Redis database
    print("Step 4: Deploying Redis...")
    # TODO: Create Redis deployment and service

    # Step 5: Deploy web application
    print("Step 5: Deploying web application...")
    # TODO: Create web app deployment with ConfigMap and Secret mounted

    # Step 6: Create service for web app
    print("Step 6: Creating service...")
    # TODO: Create a NodePort service for the web app

    # Step 7: Wait for deployment
    print("Step 7: Waiting for pods to be ready...")
    # TODO: Implement wait logic

    print("\n✅ Application deployed successfully!")
    # TODO: Print access instructions

if __name__ == "__main__":
    deploy_complete_app()
```

**Challenge Mode:** Add horizontal pod autoscaling based on CPU utilization

**Success Criteria:**
- [ ] Namespace created with proper labels
- [ ] ConfigMap contains application configuration
- [ ] Secret contains encoded credentials
- [ ] Redis deployment running with 1 replica
- [ ] Web app deployment running with 3 replicas
- [ ] Services expose applications correctly
- [ ] All pods reach Running state

---

### 🔬 Micro-Lab 7.2: Kubernetes Event Monitor (20 min)

**Objective:** Build a real-time Kubernetes event monitoring system

```python
# k8s_event_monitor.py
"""
Lab: Build a Kubernetes event monitoring system
"""
from kubernetes import client, config, watch
from datetime import datetime
import json

class EventMonitor:
    """Monitor Kubernetes events in real-time."""

    def __init__(self):
        config.load_kube_config()
        self.core_v1 = client.CoreV1Api()

    def watch_events(self, namespace: str = None, event_types: list = None):
        """
        Watch events with filtering.

        Args:
            namespace: Filter by namespace (None = all)
            event_types: Filter by type ['Normal', 'Warning']
        """
        w = watch.Watch()

        # TODO: Implement the watch logic
        # - Watch events using w.stream()
        # - Filter by event_types if specified
        # - Format and display events with timestamps
        # - Color-code based on event type (Warning = red)
        pass

    def get_recent_warnings(self, namespace: str = None,
                           minutes: int = 30) -> list:
        """Get warning events from the last N minutes."""
        # TODO: Implement filtering logic
        pass

if __name__ == "__main__":
    monitor = EventMonitor()
    # Watch warning events only
    monitor.watch_events(event_types=["Warning"])
```

---

### 🧪 Phase Lab 7: Kubernetes Deployment Pipeline

**Duration:** 4-6 hours

**Scenario:** Build a complete Kubernetes deployment automation system

**Project structure**

**`k8s-deployer/`**

- `src/`
  - `__init__.py`
  - `cluster.py` — Cluster management
  - `deployer.py` — Deployment automation
  - `monitor.py` — Health monitoring
  - `rollback.py` — Rollback capabilities
- `charts/`
  - `webapp/`
    - `Chart.yaml`
    - `values.yaml`
    - `templates/`
- `manifests/`
  - `namespace.yaml`
  - `rbac.yaml`
- `tests/`
  - `test_deployer.py`
- `deploy.py` — CLI entry point
- `requirements.txt`

**Requirements**

1. Cluster Management:
   - Support multiple cluster contexts
   - Health checks before deployment
   - Resource quota validation
   - Namespace management

2. Deployment Features:
   - Blue-green deployments
   - Canary deployments with traffic splitting
   - Automatic rollback on failures
   - Pre/post deployment hooks

3. Monitoring:
   - Pod readiness checks
   - Event monitoring during deployment
   - Resource usage tracking
   - Deployment progress reporting

4. CLI Interface:
   deploy.py deploy --app myapp --version 1.2.3 --strategy canary
   deploy.py rollback --app myapp --revision 5
   deploy.py status --app myapp
   deploy.py logs --app myapp --follow

**Deliverables**

- [ ] Complete Python package with CLI
- [ ] Support for blue-green and canary deployments
- [ ] Automatic rollback on health check failures
- [ ] Comprehensive logging and monitoring
- [ ] Unit tests with mocked Kubernetes client
- [ ] Sample Helm chart
- [ ] Documentation with examples

**Bonus**

- [ ] Slack/Teams notifications on deployment events
- [ ] Prometheus metrics for deployment tracking
- [ ] Integration with ArgoCD for GitOps


---

### ⚠️ Common Mistakes: Phase 7

| Mistake | Problem | Solution |
|---------|---------|----------|
| Not handling API errors | Crashes on 404/409 responses | Always catch `ApiException` and handle status codes |
| Ignoring resource limits | Pods get OOMKilled | Always set requests and limits |
| Missing health probes | Unhealthy pods receive traffic | Define liveness and readiness probes |
| Hardcoding namespaces | Can't deploy to different envs | Parameterize namespace in all operations |
| Not waiting for rollouts | Proceeding before pods ready | Use watch or polling to confirm readiness |
| Storing secrets in code | Security vulnerability | Use Kubernetes Secrets or external vaults |

---

### 🎯 Interview Questions: Phase 7

<details>
<summary><strong>Q: Explain the difference between a Deployment, StatefulSet, and DaemonSet.</strong></summary>

**Deployment:** Manages stateless applications with identical, interchangeable pods. Supports rolling updates and rollbacks. Pods have random names and can be rescheduled anywhere.

**StatefulSet:** For stateful applications requiring:
- Stable, unique network identifiers (pod-0, pod-1)
- Stable persistent storage
- Ordered deployment and scaling
- Examples: databases, distributed systems like Kafka

**DaemonSet:** Ensures a copy of a pod runs on all (or selected) nodes. Used for:
- Log collectors (fluentd)
- Monitoring agents (node-exporter)
- Network plugins (CNI)
- Storage daemons

```python
# When to use each:
# Deployment: web servers, APIs, microservices
# StatefulSet: PostgreSQL, MongoDB, Redis clusters
# DaemonSet: Prometheus node-exporter, filebeat
```

</details>

<details>
<summary><strong>Q: How would you implement zero-downtime deployments in Kubernetes?</strong></summary>

**Key strategies:**

1. **Rolling Updates (default)**
   - Set `maxSurge` and `maxUnavailable` appropriately
   - Ensure readiness probes are configured

2. **Readiness Probes**
   - Pod only receives traffic when ready
   - Check application health, not just container

3. **PreStop Hooks**
   - Allow graceful shutdown
   - Give time for connection draining

4. **Pod Disruption Budgets**
   - Prevent too many pods being unavailable

```python
# Example configuration
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 0  # Zero downtime
  template:
    spec:
      containers:
      - name: app
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
      terminationGracePeriodSeconds: 30
```

</details>

<details>
<summary><strong>Q: Describe how you would debug a pod that's stuck in CrashLoopBackOff.</strong></summary>

**Systematic debugging approach:**

```python
from kubernetes import client, config

def debug_crashloop_pod(name: str, namespace: str):
    config.load_kube_config()
    v1 = client.CoreV1Api()

    # 1. Get pod details
    pod = v1.read_namespaced_pod(name, namespace)

    # 2. Check container statuses
    for cs in pod.status.container_statuses or []:
        if cs.state.waiting:
            print(f"Waiting: {cs.state.waiting.reason}")
            print(f"Message: {cs.state.waiting.message}")
        if cs.last_state.terminated:
            print(f"Exit Code: {cs.last_state.terminated.exit_code}")
            print(f"Reason: {cs.last_state.terminated.reason}")

    # 3. Get current logs
    try:
        logs = v1.read_namespaced_pod_log(name, namespace, tail_lines=50)
        print(f"Current logs:\n{logs}")
    except: pass

    # 4. Get previous container logs
    try:
        prev_logs = v1.read_namespaced_pod_log(
            name, namespace, previous=True, tail_lines=50
        )
        print(f"Previous logs:\n{prev_logs}")
    except: pass

    # 5. Check events
    events = v1.list_namespaced_event(
        namespace,
        field_selector=f"involvedObject.name={name}"
    )
    for e in events.items:
        print(f"Event: {e.reason} - {e.message}")

    # 6. Describe pod for resource issues
    # Check: image pull errors, resource limits, volume mounts
```

**Common causes:**
- Application crash (check logs)
- Missing dependencies
- Configuration errors (env vars, config maps)
- Resource limits too low
- Liveness probe failing
- Image pull errors

</details>

---

### ✅ Checkpoint: Phase 7 Self-Assessment

- [ ] Set up local Kubernetes cluster with kind
- [ ] Create/update/delete Kubernetes resources with Python client
- [ ] Deploy applications with proper health checks
- [ ] Manage ConfigMaps and Secrets programmatically
- [ ] Use Helm to manage chart releases
- [ ] Implement rolling updates with zero downtime
- [ ] Monitor pod events and logs
- [ ] Debug common Kubernetes issues

---

## 📘 Phase 8: Cloud Platform Mastery with Python

| Attribute | Value |
|-----------|-------|
| **Skill Level** | Advanced |
| **Time Estimate** | 8-10 weeks |
| **Prerequisites** | Phase 7 (Kubernetes) |
| **Environment** | AWS/GCP/Azure accounts (free tiers) |

### Learning Objectives
By the end of this phase, you will be able to:
- Automate AWS infrastructure using Boto3
- Manage GCP resources with the Python client libraries
- Work with Azure using the Azure SDK for Python
- Implement multi-cloud automation strategies
- Build cost-effective, scalable cloud architectures

### 8.1 AWS Automation with Boto3
**📖 References:** [ORA: Ch.6-7], [BPB: Ch.12]

**AWS Services for DevOps:**

- Compute
  - EC2 (Virtual Machines)
  - Lambda (Serverless)
  - ECS/EKS (Containers)
  - Auto Scaling
- Storage
  - S3 (Object Storage)
  - EBS (Block Storage)
  - EFS (File Storage)
- Networking
  - VPC (Virtual Networks)
  - Route53 (DNS)
  - CloudFront (CDN)
- Database
  - RDS (Relational)
  - DynamoDB (NoSQL)
  - ElastiCache (Caching)
- DevOps Services
  - CodePipeline
  - CodeBuild
  - CodeDeploy
  - ECR (Container Registry)
- Monitoring
  - CloudWatch
  - X-Ray
  - CloudTrail


```python
#!/usr/bin/env python3
"""
AWS Infrastructure Automation with Boto3
pip install boto3
"""
import boto3
from botocore.exceptions import ClientError
from typing import Dict, List, Optional
from dataclasses import dataclass
import json
import time

@dataclass
class EC2Instance:
    """Represents an EC2 instance."""
    instance_id: str
    name: str
    state: str
    instance_type: str
    public_ip: Optional[str]
    private_ip: str
    launch_time: str

class AWSManager:
    """
    Comprehensive AWS infrastructure management.

    Provides a Pythonic interface to common AWS operations
    for DevOps automation.
    """

    def __init__(self, region: str = "us-east-1", profile: str = None):
        """
        Initialize AWS clients.

        Args:
            region: AWS region
            profile: AWS profile name (from ~/.aws/credentials)
        """
        session_kwargs = {"region_name": region}
        if profile:
            session_kwargs["profile_name"] = profile

        self.session = boto3.Session(**session_kwargs)
        self.region = region

        # Initialize service clients
        self.ec2 = self.session.client("ec2")
        self.ec2_resource = self.session.resource("ec2")
        self.s3 = self.session.client("s3")
        self.s3_resource = self.session.resource("s3")
        self.iam = self.session.client("iam")
        self.lambda_client = self.session.client("lambda")
        self.cloudwatch = self.session.client("cloudwatch")
        self.ssm = self.session.client("ssm")
        self.sts = self.session.client("sts")

    def get_account_id(self) -> str:
        """Get the current AWS account ID."""
        return self.sts.get_caller_identity()["Account"]

    # ==================== EC2 Operations ====================

    def list_instances(self, filters: List[Dict] = None) -> List[EC2Instance]:
        """
        List EC2 instances with optional filtering.

        Args:
            filters: List of filters [{"Name": "tag:Env", "Values": ["prod"]}]
        """
        params = {}
        if filters:
            params["Filters"] = filters

        response = self.ec2.describe_instances(**params)
        instances = []

        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                name = ""
                for tag in instance.get("Tags", []):
                    if tag["Key"] == "Name":
                        name = tag["Value"]
                        break

                instances.append(EC2Instance(
                    instance_id=instance["InstanceId"],
                    name=name,
                    state=instance["State"]["Name"],
                    instance_type=instance["InstanceType"],
                    public_ip=instance.get("PublicIpAddress"),
                    private_ip=instance.get("PrivateIpAddress", ""),
                    launch_time=str(instance["LaunchTime"])
                ))

        return instances

    def launch_instance(self, name: str, instance_type: str = "t3.micro",
                       ami_id: str = None, key_name: str = None,
                       security_group_ids: List[str] = None,
                       subnet_id: str = None, user_data: str = None,
                       tags: Dict[str, str] = None) -> str:
        """
        Launch a new EC2 instance.

        Args:
            name: Name tag for the instance
            instance_type: EC2 instance type
            ami_id: AMI ID (uses latest Amazon Linux 2 if not specified)
            key_name: SSH key pair name
            security_group_ids: List of security group IDs
            subnet_id: VPC subnet ID
            user_data: Startup script
            tags: Additional tags

        Returns:
            Instance ID
        """
        # Get latest Amazon Linux 2 AMI if not specified
        if not ami_id:
            ami_id = self._get_latest_amazon_linux_ami()

        # Build tags
        all_tags = {"Name": name, **(tags or {})}
        tag_specs = [{
            "ResourceType": "instance",
            "Tags": [{"Key": k, "Value": v} for k, v in all_tags.items()]
        }]

        params = {
            "ImageId": ami_id,
            "InstanceType": instance_type,
            "MinCount": 1,
            "MaxCount": 1,
            "TagSpecifications": tag_specs,
        }

        if key_name:
            params["KeyName"] = key_name
        if security_group_ids:
            params["SecurityGroupIds"] = security_group_ids
        if subnet_id:
            params["SubnetId"] = subnet_id
        if user_data:
            params["UserData"] = user_data

        response = self.ec2.run_instances(**params)
        instance_id = response["Instances"][0]["InstanceId"]

        print(f"✅ Launched instance: {instance_id}")
        return instance_id

    def stop_instances(self, instance_ids: List[str]) -> bool:
        """Stop EC2 instances."""
        self.ec2.stop_instances(InstanceIds=instance_ids)
        print(f"⏹️ Stopping instances: {instance_ids}")
        return True

    def start_instances(self, instance_ids: List[str]) -> bool:
        """Start EC2 instances."""
        self.ec2.start_instances(InstanceIds=instance_ids)
        print(f"▶️ Starting instances: {instance_ids}")
        return True

    def terminate_instances(self, instance_ids: List[str]) -> bool:
        """Terminate EC2 instances."""
        self.ec2.terminate_instances(InstanceIds=instance_ids)
        print(f"🗑️ Terminating instances: {instance_ids}")
        return True

    def wait_for_instance(self, instance_id: str, state: str = "running",
                         timeout: int = 300) -> bool:
        """Wait for instance to reach specified state."""
        waiter = self.ec2.get_waiter(f"instance_{state}")
        waiter.wait(
            InstanceIds=[instance_id],
            WaiterConfig={"Delay": 5, "MaxAttempts": timeout // 5}
        )
        print(f"✅ Instance {instance_id} is {state}")
        return True

    def _get_latest_amazon_linux_ami(self) -> str:
        """Get the latest Amazon Linux 2 AMI ID."""
        response = self.ssm.get_parameter(
            Name="/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
        )
        return response["Parameter"]["Value"]

    # ==================== S3 Operations ====================

    def create_bucket(self, bucket_name: str, versioning: bool = True,
                      encryption: bool = True, public_access_block: bool = True) -> bool:
        """
        Create an S3 bucket with best practices.

        Args:
            bucket_name: Globally unique bucket name
            versioning: Enable versioning
            encryption: Enable default encryption
            public_access_block: Block all public access
        """
        try:
            # Create bucket
            create_params = {"Bucket": bucket_name}
            if self.region != "us-east-1":
                create_params["CreateBucketConfiguration"] = {
                    "LocationConstraint": self.region
                }
            self.s3.create_bucket(**create_params)

            # Enable versioning
            if versioning:
                self.s3.put_bucket_versioning(
                    Bucket=bucket_name,
                    VersioningConfiguration={"Status": "Enabled"}
                )

            # Enable encryption
            if encryption:
                self.s3.put_bucket_encryption(
                    Bucket=bucket_name,
                    ServerSideEncryptionConfiguration={
                        "Rules": [{
                            "ApplyServerSideEncryptionByDefault": {
                                "SSEAlgorithm": "AES256"
                            }
                        }]
                    }
                )

            # Block public access
            if public_access_block:
                self.s3.put_public_access_block(
                    Bucket=bucket_name,
                    PublicAccessBlockConfiguration={
                        "BlockPublicAcls": True,
                        "IgnorePublicAcls": True,
                        "BlockPublicPolicy": True,
                        "RestrictPublicBuckets": True
                    }
                )

            print(f"✅ Created bucket: {bucket_name}")
            return True

        except ClientError as e:
            if e.response["Error"]["Code"] == "BucketAlreadyOwnedByYou":
                print(f"⚠️ Bucket {bucket_name} already exists")
                return True
            raise

    def upload_file(self, bucket_name: str, file_path: str,
                    key: str = None, extra_args: Dict = None) -> str:
        """
        Upload a file to S3.

        Args:
            bucket_name: Target bucket
            file_path: Local file path
            key: S3 object key (uses filename if not specified)
            extra_args: Extra arguments (ContentType, Metadata, etc.)

        Returns:
            S3 URI (s3://bucket/key)
        """
        from pathlib import Path

        if key is None:
            key = Path(file_path).name

        self.s3.upload_file(
            file_path, bucket_name, key,
            ExtraArgs=extra_args
        )

        s3_uri = f"s3://{bucket_name}/{key}"
        print(f"✅ Uploaded: {s3_uri}")
        return s3_uri

    def download_file(self, bucket_name: str, key: str,
                      local_path: str) -> str:
        """Download a file from S3."""
        self.s3.download_file(bucket_name, key, local_path)
        print(f"✅ Downloaded to: {local_path}")
        return local_path

    def list_objects(self, bucket_name: str, prefix: str = "") -> List[Dict]:
        """List objects in an S3 bucket."""
        paginator = self.s3.get_paginator("list_objects_v2")
        objects = []

        for page in paginator.paginate(Bucket=bucket_name, Prefix=prefix):
            for obj in page.get("Contents", []):
                objects.append({
                    "key": obj["Key"],
                    "size": obj["Size"],
                    "last_modified": str(obj["LastModified"]),
                    "storage_class": obj.get("StorageClass", "STANDARD")
                })

        return objects

    def generate_presigned_url(self, bucket_name: str, key: str,
                               expiration: int = 3600,
                               operation: str = "get_object") -> str:
        """Generate a presigned URL for temporary access."""
        url = self.s3.generate_presigned_url(
            operation,
            Params={"Bucket": bucket_name, "Key": key},
            ExpiresIn=expiration
        )
        return url

    # ==================== CloudWatch Operations ====================

    def put_metric(self, namespace: str, metric_name: str, value: float,
                   unit: str = "Count", dimensions: Dict[str, str] = None):
        """Publish a custom CloudWatch metric."""
        metric_data = {
            "MetricName": metric_name,
            "Value": value,
            "Unit": unit,
        }

        if dimensions:
            metric_data["Dimensions"] = [
                {"Name": k, "Value": v} for k, v in dimensions.items()
            ]

        self.cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=[metric_data]
        )

    def get_metric_statistics(self, namespace: str, metric_name: str,
                             dimensions: Dict[str, str], period: int = 300,
                             hours: int = 1, statistics: List[str] = None) -> List[Dict]:
        """Get CloudWatch metric statistics."""
        from datetime import datetime, timedelta

        response = self.cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=[{"Name": k, "Value": v} for k, v in dimensions.items()],
            StartTime=datetime.utcnow() - timedelta(hours=hours),
            EndTime=datetime.utcnow(),
            Period=period,
            Statistics=statistics or ["Average", "Maximum", "Minimum"]
        )

        return response["Datapoints"]

    def create_alarm(self, alarm_name: str, namespace: str, metric_name: str,
                    threshold: float, comparison: str = "GreaterThanThreshold",
                    dimensions: Dict[str, str] = None, period: int = 300,
                    evaluation_periods: int = 2, sns_topic_arn: str = None) -> bool:
        """Create a CloudWatch alarm."""
        params = {
            "AlarmName": alarm_name,
            "MetricName": metric_name,
            "Namespace": namespace,
            "Threshold": threshold,
            "ComparisonOperator": comparison,
            "Period": period,
            "EvaluationPeriods": evaluation_periods,
            "Statistic": "Average",
        }

        if dimensions:
            params["Dimensions"] = [
                {"Name": k, "Value": v} for k, v in dimensions.items()
            ]

        if sns_topic_arn:
            params["AlarmActions"] = [sns_topic_arn]

        self.cloudwatch.put_metric_alarm(**params)
        print(f"✅ Created alarm: {alarm_name}")
        return True

    # ==================== Lambda Operations ====================

    def create_lambda_function(self, function_name: str, runtime: str,
                               handler: str, role_arn: str,
                               zip_file: bytes = None, s3_bucket: str = None,
                               s3_key: str = None, environment: Dict = None,
                               timeout: int = 30, memory_size: int = 128) -> str:
        """
        Create a Lambda function.

        Args:
            function_name: Name of the function
            runtime: Runtime (python3.9, python3.10, etc.)
            handler: Handler (module.function)
            role_arn: IAM role ARN for execution
            zip_file: Deployment package bytes (or use S3)
            s3_bucket: S3 bucket containing deployment package
            s3_key: S3 key for deployment package
            environment: Environment variables
            timeout: Function timeout in seconds
            memory_size: Memory allocation in MB

        Returns:
            Function ARN
        """
        params = {
            "FunctionName": function_name,
            "Runtime": runtime,
            "Role": role_arn,
            "Handler": handler,
            "Timeout": timeout,
            "MemorySize": memory_size,
        }

        if zip_file:
            params["Code"] = {"ZipFile": zip_file}
        elif s3_bucket and s3_key:
            params["Code"] = {"S3Bucket": s3_bucket, "S3Key": s3_key}
        else:
            raise ValueError("Either zip_file or s3_bucket/s3_key required")

        if environment:
            params["Environment"] = {"Variables": environment}

        try:
            response = self.lambda_client.create_function(**params)
            print(f"✅ Created Lambda function: {function_name}")
            return response["FunctionArn"]
        except ClientError as e:
            if e.response["Error"]["Code"] == "ResourceConflictException":
                # Function exists, update it
                update_params = {
                    "FunctionName": function_name,
                }
                if zip_file:
                    update_params["ZipFile"] = zip_file
                else:
                    update_params["S3Bucket"] = s3_bucket
                    update_params["S3Key"] = s3_key

                response = self.lambda_client.update_function_code(**update_params)
                print(f"🔄 Updated Lambda function: {function_name}")
                return response["FunctionArn"]
            raise

    def invoke_lambda(self, function_name: str, payload: Dict,
                      invocation_type: str = "RequestResponse") -> Dict:
        """
        Invoke a Lambda function.

        Args:
            function_name: Function name or ARN
            payload: Event payload
            invocation_type: RequestResponse (sync) or Event (async)

        Returns:
            Response payload
        """
        response = self.lambda_client.invoke(
            FunctionName=function_name,
            InvocationType=invocation_type,
            Payload=json.dumps(payload)
        )

        if invocation_type == "RequestResponse":
            return json.loads(response["Payload"].read())
        return {"StatusCode": response["StatusCode"]}


# Example usage
if __name__ == "__main__":
    aws = AWSManager(region="us-east-1")

    # List all running instances
    instances = aws.list_instances(
        filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )

    print("\n📊 Running EC2 Instances:")
    for inst in instances:
        print(f"  {inst.name} ({inst.instance_id}): {inst.instance_type}")

    # Create S3 bucket
    aws.create_bucket(
        bucket_name=f"devops-data-{aws.get_account_id()}",
        versioning=True,
        encryption=True
    )
```

### 8.2 GCP Automation with Python
**📖 References:** [ORA: Ch.6], [BPB: Ch.12]

```python
#!/usr/bin/env python3
"""
GCP Infrastructure Automation
pip install google-cloud-compute google-cloud-storage google-cloud-monitoring
"""
from google.cloud import compute_v1
from google.cloud import storage
from google.cloud import monitoring_v3
from google.api_core.exceptions import NotFound, Conflict
from typing import Dict, List, Optional
from dataclasses import dataclass
import time

@dataclass
class GCEInstance:
    """Represents a GCE instance."""
    name: str
    zone: str
    machine_type: str
    status: str
    internal_ip: str
    external_ip: Optional[str]

class GCPManager:
    """
    Google Cloud Platform infrastructure management.

    Requires GOOGLE_APPLICATION_CREDENTIALS environment variable
    or Application Default Credentials.
    """

    def __init__(self, project_id: str):
        """
        Initialize GCP clients.

        Args:
            project_id: GCP project ID
        """
        self.project_id = project_id

        # Initialize service clients
        self.compute_instances = compute_v1.InstancesClient()
        self.compute_images = compute_v1.ImagesClient()
        self.compute_zones = compute_v1.ZonesClient()
        self.storage = storage.Client(project=project_id)

    # ==================== Compute Engine Operations ====================

    def list_instances(self, zone: str = None) -> List[GCEInstance]:
        """
        List GCE instances.

        Args:
            zone: Specific zone or None for all zones
        """
        instances = []

        if zone:
            zones = [zone]
        else:
            # Get all zones
            zones = [z.name for z in self.compute_zones.list(project=self.project_id)]

        for z in zones:
            try:
                request = compute_v1.ListInstancesRequest(
                    project=self.project_id,
                    zone=z
                )
                for instance in self.compute_instances.list(request):
                    # Extract IPs
                    internal_ip = ""
                    external_ip = None

                    for iface in instance.network_interfaces:
                        internal_ip = iface.network_i_p
                        for config in iface.access_configs:
                            external_ip = config.nat_i_p

                    instances.append(GCEInstance(
                        name=instance.name,
                        zone=z,
                        machine_type=instance.machine_type.split("/")[-1],
                        status=instance.status,
                        internal_ip=internal_ip,
                        external_ip=external_ip
                    ))
            except Exception:
                continue  # Zone may not exist or be accessible

        return instances

    def create_instance(self, name: str, zone: str,
                       machine_type: str = "e2-micro",
                       image_family: str = "debian-11",
                       image_project: str = "debian-cloud",
                       disk_size_gb: int = 10,
                       network: str = "default",
                       startup_script: str = None,
                       labels: Dict[str, str] = None) -> str:
        """
        Create a GCE instance.

        Args:
            name: Instance name
            zone: Target zone
            machine_type: Machine type (e2-micro, n1-standard-1, etc.)
            image_family: OS image family
            image_project: Project containing the image
            disk_size_gb: Boot disk size
            network: VPC network name
            startup_script: Startup script content
            labels: Instance labels

        Returns:
            Instance self link
        """
        # Get the latest image from the family
        image = self.compute_images.get_from_family(
            project=image_project,
            family=image_family
        )

        # Configure the instance
        instance = compute_v1.Instance()
        instance.name = name
        instance.machine_type = f"zones/{zone}/machineTypes/{machine_type}"
        instance.labels = labels or {}

        # Boot disk
        disk = compute_v1.AttachedDisk()
        disk.boot = True
        disk.auto_delete = True
        disk.initialize_params = compute_v1.AttachedDiskInitializeParams()
        disk.initialize_params.source_image = image.self_link
        disk.initialize_params.disk_size_gb = disk_size_gb
        disk.initialize_params.disk_type = f"zones/{zone}/diskTypes/pd-standard"
        instance.disks = [disk]

        # Network interface
        network_interface = compute_v1.NetworkInterface()
        network_interface.network = f"global/networks/{network}"

        # External IP
        access_config = compute_v1.AccessConfig()
        access_config.name = "External NAT"
        access_config.type_ = "ONE_TO_ONE_NAT"
        network_interface.access_configs = [access_config]

        instance.network_interfaces = [network_interface]

        # Startup script
        if startup_script:
            instance.metadata = compute_v1.Metadata()
            instance.metadata.items = [
                compute_v1.Items(key="startup-script", value=startup_script)
            ]

        # Create the instance
        request = compute_v1.InsertInstanceRequest(
            project=self.project_id,
            zone=zone,
            instance_resource=instance
        )

        operation = self.compute_instances.insert(request)
        self._wait_for_operation(operation, zone)

        print(f"✅ Created instance: {name} in {zone}")
        return f"projects/{self.project_id}/zones/{zone}/instances/{name}"

    def delete_instance(self, name: str, zone: str) -> bool:
        """Delete a GCE instance."""
        request = compute_v1.DeleteInstanceRequest(
            project=self.project_id,
            zone=zone,
            instance=name
        )

        operation = self.compute_instances.delete(request)
        self._wait_for_operation(operation, zone)

        print(f"🗑️ Deleted instance: {name}")
        return True

    def start_instance(self, name: str, zone: str) -> bool:
        """Start a stopped GCE instance."""
        request = compute_v1.StartInstanceRequest(
            project=self.project_id,
            zone=zone,
            instance=name
        )

        operation = self.compute_instances.start(request)
        self._wait_for_operation(operation, zone)

        print(f"▶️ Started instance: {name}")
        return True

    def stop_instance(self, name: str, zone: str) -> bool:
        """Stop a running GCE instance."""
        request = compute_v1.StopInstanceRequest(
            project=self.project_id,
            zone=zone,
            instance=name
        )

        operation = self.compute_instances.stop(request)
        self._wait_for_operation(operation, zone)

        print(f"⏹️ Stopped instance: {name}")
        return True

    def _wait_for_operation(self, operation, zone: str, timeout: int = 300):
        """Wait for a zone operation to complete."""
        from google.cloud.compute_v1.services.zone_operations import ZoneOperationsClient

        ops_client = ZoneOperationsClient()

        start_time = time.time()
        while time.time() - start_time < timeout:
            result = ops_client.get(
                project=self.project_id,
                zone=zone,
                operation=operation.name
            )

            if result.status == compute_v1.Operation.Status.DONE:
                if result.error:
                    raise Exception(f"Operation failed: {result.error}")
                return result

            time.sleep(2)

        raise TimeoutError(f"Operation timed out after {timeout}s")

    # ==================== Cloud Storage Operations ====================

    def create_bucket(self, bucket_name: str, location: str = "US",
                      storage_class: str = "STANDARD",
                      uniform_access: bool = True) -> str:
        """
        Create a Cloud Storage bucket.

        Args:
            bucket_name: Globally unique bucket name
            location: Bucket location (US, EU, ASIA, or specific region)
            storage_class: STANDARD, NEARLINE, COLDLINE, ARCHIVE
            uniform_access: Enable uniform bucket-level access

        Returns:
            Bucket self link
        """
        bucket = self.storage.bucket(bucket_name)
        bucket.storage_class = storage_class
        bucket.iam_configuration.uniform_bucket_level_access_enabled = uniform_access

        try:
            bucket = self.storage.create_bucket(bucket, location=location)
            print(f"✅ Created bucket: {bucket_name}")
            return bucket.self_link
        except Conflict:
            print(f"⚠️ Bucket {bucket_name} already exists")
            return f"gs://{bucket_name}"

    def upload_blob(self, bucket_name: str, source_file: str,
                    destination_blob: str = None) -> str:
        """Upload a file to Cloud Storage."""
        from pathlib import Path

        if destination_blob is None:
            destination_blob = Path(source_file).name

        bucket = self.storage.bucket(bucket_name)
        blob = bucket.blob(destination_blob)
        blob.upload_from_filename(source_file)

        uri = f"gs://{bucket_name}/{destination_blob}"
        print(f"✅ Uploaded: {uri}")
        return uri

    def download_blob(self, bucket_name: str, source_blob: str,
                      destination_file: str) -> str:
        """Download a file from Cloud Storage."""
        bucket = self.storage.bucket(bucket_name)
        blob = bucket.blob(source_blob)
        blob.download_to_filename(destination_file)

        print(f"✅ Downloaded to: {destination_file}")
        return destination_file

    def list_blobs(self, bucket_name: str, prefix: str = "") -> List[Dict]:
        """List blobs in a bucket."""
        bucket = self.storage.bucket(bucket_name)
        blobs = []

        for blob in bucket.list_blobs(prefix=prefix):
            blobs.append({
                "name": blob.name,
                "size": blob.size,
                "updated": str(blob.updated),
                "storage_class": blob.storage_class
            })

        return blobs

    def generate_signed_url(self, bucket_name: str, blob_name: str,
                           expiration: int = 3600) -> str:
        """Generate a signed URL for temporary access."""
        from datetime import timedelta

        bucket = self.storage.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        url = blob.generate_signed_url(
            expiration=timedelta(seconds=expiration),
            method="GET"
        )
        return url


# Example usage
if __name__ == "__main__":
    gcp = GCPManager(project_id="my-project-id")

    # List instances
    instances = gcp.list_instances()
    print("\n📊 GCE Instances:")
    for inst in instances:
        print(f"  {inst.name}: {inst.status} ({inst.machine_type})")

    # Create instance
    gcp.create_instance(
        name="devops-server",
        zone="us-central1-a",
        machine_type="e2-small",
        startup_script="#!/bin/bash\napt-get update && apt-get install -y nginx"
    )
```

### 8.3 Azure Automation with Python SDK
**📖 References:** [ORA: Ch.6], [BPB: Ch.12]

```python
#!/usr/bin/env python3
"""
Azure Infrastructure Automation
pip install azure-identity azure-mgmt-compute azure-mgmt-storage azure-mgmt-resource
"""
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.storage import StorageManagementClient
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.core.exceptions import ResourceExistsError
from typing import Dict, List, Optional
from dataclasses import dataclass

@dataclass
class AzureVM:
    """Represents an Azure VM."""
    name: str
    resource_group: str
    location: str
    vm_size: str
    status: str
    private_ip: Optional[str]
    public_ip: Optional[str]

class AzureManager:
    """
    Azure infrastructure management with Python SDK.

    Uses DefaultAzureCredential for authentication (supports
    environment variables, managed identity, Azure CLI, etc.)
    """

    def __init__(self, subscription_id: str):
        """
        Initialize Azure clients.

        Args:
            subscription_id: Azure subscription ID
        """
        self.subscription_id = subscription_id
        self.credential = DefaultAzureCredential()

        # Initialize management clients
        self.compute = ComputeManagementClient(self.credential, subscription_id)
        self.storage = StorageManagementClient(self.credential, subscription_id)
        self.resource = ResourceManagementClient(self.credential, subscription_id)
        self.network = NetworkManagementClient(self.credential, subscription_id)

    # ==================== Resource Group Operations ====================

    def create_resource_group(self, name: str, location: str,
                              tags: Dict[str, str] = None) -> bool:
        """Create a resource group."""
        self.resource.resource_groups.create_or_update(
            name,
            {"location": location, "tags": tags or {}}
        )
        print(f"✅ Resource group '{name}' created in {location}")
        return True

    def delete_resource_group(self, name: str, no_wait: bool = False) -> bool:
        """Delete a resource group and all its resources."""
        poller = self.resource.resource_groups.begin_delete(name)
        if not no_wait:
            poller.wait()
        print(f"🗑️ Resource group '{name}' deleted")
        return True

    # ==================== Virtual Machine Operations ====================

    def list_vms(self, resource_group: str = None) -> List[AzureVM]:
        """List Azure VMs."""
        vms = []

        if resource_group:
            vm_list = self.compute.virtual_machines.list(resource_group)
        else:
            vm_list = self.compute.virtual_machines.list_all()

        for vm in vm_list:
            # Get instance view for status
            rg = vm.id.split("/")[4]
            instance_view = self.compute.virtual_machines.instance_view(rg, vm.name)

            status = "Unknown"
            for s in instance_view.statuses:
                if s.code.startswith("PowerState/"):
                    status = s.display_status

            # Get IPs
            private_ip = None
            public_ip = None

            for nic_ref in vm.network_profile.network_interfaces:
                nic_name = nic_ref.id.split("/")[-1]
                nic = self.network.network_interfaces.get(rg, nic_name)

                for ip_config in nic.ip_configurations:
                    private_ip = ip_config.private_ip_address
                    if ip_config.public_ip_address:
                        pip_name = ip_config.public_ip_address.id.split("/")[-1]
                        pip = self.network.public_ip_addresses.get(rg, pip_name)
                        public_ip = pip.ip_address

            vms.append(AzureVM(
                name=vm.name,
                resource_group=rg,
                location=vm.location,
                vm_size=vm.hardware_profile.vm_size,
                status=status,
                private_ip=private_ip,
                public_ip=public_ip
            ))

        return vms

    def create_vm(self, name: str, resource_group: str, location: str,
                  vm_size: str = "Standard_B1s",
                  image_reference: Dict = None,
                  admin_username: str = "azureuser",
                  admin_password: str = None,
                  ssh_public_key: str = None,
                  tags: Dict[str, str] = None) -> str:
        """
        Create an Azure VM with networking.

        Args:
            name: VM name
            resource_group: Target resource group
            location: Azure region
            vm_size: VM size (Standard_B1s, Standard_D2s_v3, etc.)
            image_reference: OS image (defaults to Ubuntu 22.04)
            admin_username: Admin username
            admin_password: Admin password (for password auth)
            ssh_public_key: SSH public key (for SSH auth)
            tags: Resource tags

        Returns:
            VM resource ID
        """
        # Default to Ubuntu 22.04 LTS
        if image_reference is None:
            image_reference = {
                "publisher": "Canonical",
                "offer": "0001-com-ubuntu-server-jammy",
                "sku": "22_04-lts-gen2",
                "version": "latest"
            }

        # Create VNet
        vnet_name = f"{name}-vnet"
        subnet_name = "default"

        vnet_result = self.network.virtual_networks.begin_create_or_update(
            resource_group, vnet_name,
            {
                "location": location,
                "address_space": {"address_prefixes": ["10.0.0.0/16"]},
                "subnets": [{"name": subnet_name, "address_prefix": "10.0.0.0/24"}]
            }
        ).result()

        subnet = self.network.subnets.get(resource_group, vnet_name, subnet_name)

        # Create public IP
        pip_name = f"{name}-pip"
        pip_result = self.network.public_ip_addresses.begin_create_or_update(
            resource_group, pip_name,
            {
                "location": location,
                "sku": {"name": "Standard"},
                "public_ip_allocation_method": "Static"
            }
        ).result()

        # Create NIC
        nic_name = f"{name}-nic"
        nic_result = self.network.network_interfaces.begin_create_or_update(
            resource_group, nic_name,
            {
                "location": location,
                "ip_configurations": [{
                    "name": "ipconfig1",
                    "subnet": {"id": subnet.id},
                    "public_ip_address": {"id": pip_result.id}
                }]
            }
        ).result()

        # Configure authentication
        os_profile = {
            "computer_name": name,
            "admin_username": admin_username,
        }

        if ssh_public_key:
            os_profile["linux_configuration"] = {
                "disable_password_authentication": True,
                "ssh": {
                    "public_keys": [{
                        "path": f"/home/{admin_username}/.ssh/authorized_keys",
                        "key_data": ssh_public_key
                    }]
                }
            }
        else:
            os_profile["admin_password"] = admin_password

        # Create VM
        vm_params = {
            "location": location,
            "tags": tags or {},
            "hardware_profile": {"vm_size": vm_size},
            "storage_profile": {
                "image_reference": image_reference,
                "os_disk": {
                    "create_option": "FromImage",
                    "managed_disk": {"storage_account_type": "Standard_LRS"}
                }
            },
            "os_profile": os_profile,
            "network_profile": {
                "network_interfaces": [{"id": nic_result.id}]
            }
        }

        poller = self.compute.virtual_machines.begin_create_or_update(
            resource_group, name, vm_params
        )
        vm_result = poller.result()

        print(f"✅ Created VM: {name}")
        return vm_result.id

    def start_vm(self, name: str, resource_group: str) -> bool:
        """Start a VM."""
        poller = self.compute.virtual_machines.begin_start(resource_group, name)
        poller.wait()
        print(f"▶️ Started VM: {name}")
        return True

    def stop_vm(self, name: str, resource_group: str,
                deallocate: bool = True) -> bool:
        """Stop a VM."""
        if deallocate:
            poller = self.compute.virtual_machines.begin_deallocate(
                resource_group, name
            )
        else:
            poller = self.compute.virtual_machines.begin_power_off(
                resource_group, name
            )
        poller.wait()
        print(f"⏹️ Stopped VM: {name}")
        return True

    def delete_vm(self, name: str, resource_group: str) -> bool:
        """Delete a VM."""
        poller = self.compute.virtual_machines.begin_delete(resource_group, name)
        poller.wait()
        print(f"🗑️ Deleted VM: {name}")
        return True

    # ==================== Storage Account Operations ====================

    def create_storage_account(self, name: str, resource_group: str,
                               location: str, sku: str = "Standard_LRS",
                               kind: str = "StorageV2") -> str:
        """
        Create a storage account.

        Args:
            name: Storage account name (globally unique, 3-24 chars, lowercase)
            resource_group: Target resource group
            location: Azure region
            sku: Storage SKU (Standard_LRS, Standard_GRS, Premium_LRS)
            kind: Account kind (StorageV2, BlobStorage, FileStorage)

        Returns:
            Storage account ID
        """
        params = {
            "sku": {"name": sku},
            "kind": kind,
            "location": location,
            "enable_https_traffic_only": True,
            "minimum_tls_version": "TLS1_2"
        }

        poller = self.storage.storage_accounts.begin_create(
            resource_group, name, params
        )
        result = poller.result()

        print(f"✅ Created storage account: {name}")
        return result.id

    def get_storage_keys(self, name: str, resource_group: str) -> List[str]:
        """Get storage account access keys."""
        keys = self.storage.storage_accounts.list_keys(resource_group, name)
        return [k.value for k in keys.keys]


# Example usage
if __name__ == "__main__":
    import os

    subscription_id = os.environ.get("AZURE_SUBSCRIPTION_ID")
    azure = AzureManager(subscription_id)

    # Create resource group
    azure.create_resource_group(
        name="devops-rg",
        location="eastus",
        tags={"environment": "development"}
    )

    # List VMs
    vms = azure.list_vms()
    print("\n📊 Azure VMs:")
    for vm in vms:
        print(f"  {vm.name}: {vm.status} ({vm.vm_size})")
```

---

### 🔬 Micro-Lab 8.1: Multi-Cloud Resource Manager (45 min)

**Objective:** Build a unified interface for managing resources across AWS, GCP, and Azure

```python
# multi_cloud_manager.py
"""
Lab: Create a unified multi-cloud resource management interface
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Optional
from enum import Enum

class CloudProvider(Enum):
    AWS = "aws"
    GCP = "gcp"
    AZURE = "azure"

@dataclass
class CloudInstance:
    """Unified cloud instance representation."""
    provider: CloudProvider
    id: str
    name: str
    status: str
    instance_type: str
    region: str
    public_ip: Optional[str]
    private_ip: str

class CloudManager(ABC):
    """Abstract base class for cloud managers."""

    @abstractmethod
    def list_instances(self) -> List[CloudInstance]:
        pass

    @abstractmethod
    def create_instance(self, name: str, instance_type: str,
                       region: str) -> CloudInstance:
        pass

    @abstractmethod
    def delete_instance(self, instance_id: str) -> bool:
        pass

class MultiCloudManager:
    """
    Unified multi-cloud resource manager.

    TODO: Implement this class that:
    1. Accepts configurations for multiple cloud providers
    2. Lists resources across all configured clouds
    3. Creates resources in specified cloud
    4. Provides cost comparison across clouds
    5. Implements cloud-agnostic tagging strategy
    """

    def __init__(self):
        self.providers: dict[CloudProvider, CloudManager] = {}

    def register_provider(self, provider: CloudProvider,
                         manager: CloudManager):
        """Register a cloud provider manager."""
        # TODO: Implement registration
        pass

    def list_all_instances(self) -> List[CloudInstance]:
        """List instances across all registered clouds."""
        # TODO: Implement cross-cloud listing
        pass

    def find_cheapest_option(self, vcpus: int, memory_gb: int,
                            regions: List[str] = None) -> dict:
        """Find the cheapest instance option across clouds."""
        # TODO: Implement cost comparison
        pass

if __name__ == "__main__":
    manager = MultiCloudManager()
    # TODO: Register providers and test operations
```

**Challenge:** Add support for spot/preemptible instances and cost optimization

---

### 🧪 Phase Lab 8: Cloud Infrastructure Automation Platform

**Duration:** 6-8 hours

**Scenario:** Build a comprehensive cloud automation platform

**Project structure**

**`cloud-automator/`**

- `src/`
  - `__init__.py`
  - `providers/`
    - `__init__.py`
    - `base.py` — Abstract base classes
    - `aws_provider.py`
    - `gcp_provider.py`
    - `azure_provider.py`
  - `resources/`
    - `__init__.py`
    - `compute.py` — VM management
    - `storage.py` — Object storage
    - `network.py` — VPC/Networking
    - `database.py` — Managed databases
  - `automation/`
    - `__init__.py`
    - `scheduler.py` — Start/stop schedules
    - `backup.py` — Backup automation
    - cost_optimizer.py # Cost optimization
  - `cli.py` — CLI interface
- `tests/`
  - `test_providers.py`
  - `test_automation.py`
- `configs/`
  - `environments.yaml`
- `requirements.txt`
- `README.md`

**Requirements**

1. Multi-Cloud Support:
   - Unified interface for AWS, GCP, Azure
   - Provider-agnostic resource definitions
   - Cloud-specific optimizations

2. Resource Management:
   - Create/Read/Update/Delete for all resource types
   - Tagging strategy enforcement
   - Resource dependency tracking

3. Automation Features:
   - Scheduled start/stop for dev environments
   - Automated snapshots and backups
   - Unused resource identification
   - Cost reporting by tag/project

4. CLI Interface:
   cloud-automator list --provider aws --resource compute
   cloud-automator create compute --provider gcp --config vm.yaml
   cloud-automator schedule stop --resources "tag:env=dev" --cron "0 18 * * 1-5"
   cloud-automator cost-report --period monthly --group-by project

**Deliverables**

- [ ] Provider implementations for at least 2 clouds
- [ ] Resource management for compute, storage, networking
- [ ] Scheduler for automated operations
- [ ] Cost analysis and reporting
- [ ] Comprehensive CLI
- [ ] Unit and integration tests
- [ ] Documentation

**Bonus**

- [ ] Terraform state import/export
- [ ] Drift detection
- [ ] Slack notifications for cost alerts


---

### ⚠️ Common Mistakes: Phase 8

| Mistake | Problem | Solution |
|---------|---------|----------|
| Hardcoding credentials | Security vulnerability | Use environment variables, IAM roles, or secret managers |
| Not handling pagination | Missing resources in large accounts | Always use paginators for list operations |
| Ignoring rate limits | API throttling errors | Implement exponential backoff and retries |
| Missing error handling | Crashes on API errors | Catch specific exceptions (ClientError, etc.) |
| Not waiting for operations | Acting on incomplete resources | Use waiters or poll for completion |
| Ignoring regional scope | Missing resources in other regions | Query all relevant regions |

---

### 🎯 Interview Questions: Phase 8

<details>
<summary><strong>Q: How would you design a system to automatically shut down development resources outside business hours?</strong></summary>

**Architecture:**

```python
"""
Scheduled Resource Management System Design
"""

# 1. Resource Tagging Strategy
# Tag all dev resources with: environment=development, auto-stop=true

# 2. Lambda Function for Stop/Start
import boto3
from datetime import datetime

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    action = event.get('action', 'stop')  # stop or start

    # Find tagged instances
    filters = [
        {'Name': 'tag:environment', 'Values': ['development']},
        {'Name': 'tag:auto-stop', 'Values': ['true']},
        {'Name': 'instance-state-name',
         'Values': ['running'] if action == 'stop' else ['stopped']}
    ]

    instances = ec2.describe_instances(Filters=filters)
    instance_ids = [
        i['InstanceId']
        for r in instances['Reservations']
        for i in r['Instances']
    ]

    if instance_ids:
        if action == 'stop':
            ec2.stop_instances(InstanceIds=instance_ids)
        else:
            ec2.start_instances(InstanceIds=instance_ids)

    return {'affected_instances': instance_ids}

# 3. EventBridge Rules
# Stop: cron(0 18 ? * MON-FRI *)  # 6 PM weekdays
# Start: cron(0 9 ? * MON-FRI *)  # 9 AM weekdays

# 4. Extend to other services (RDS, EKS node groups, etc.)
# 5. Add SNS notifications for cost savings reports
```

**Key considerations:**
- Time zone handling
- Holiday calendars
- Override mechanisms for on-call scenarios
- Cost tracking and reporting

</details>

<details>
<summary><strong>Q: How do you handle credentials securely in cloud automation scripts?</strong></summary>

**Best practices (ranked by security):**

1. **IAM Roles (Best)**
```python
# When running on EC2/Lambda/ECS
# No credentials needed - uses instance metadata
import boto3
client = boto3.client('s3')  # Automatic credential chain
```

2. **Service Account / Managed Identity**
```python
# GCP - Workload Identity
# Azure - Managed Identity
from azure.identity import ManagedIdentityCredential
credential = ManagedIdentityCredential()
```

3. **Secrets Manager**
```python
import boto3
import json

def get_credentials(secret_name: str) -> dict:
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])
```

4. **Environment Variables (CI/CD)**
```python
import os
AWS_ACCESS_KEY = os.environ.get('AWS_ACCESS_KEY_ID')
# Never commit .env files with real credentials
```

**Never:**
- Hardcode credentials in source code
- Commit credentials to version control
- Log credentials in application output
- Store credentials in plain text files

</details>

---

### ✅ Checkpoint: Phase 8 Self-Assessment

- [ ] Create and manage EC2 instances with Boto3
- [ ] Work with S3 buckets (create, upload, download, presigned URLs)
- [ ] Set up CloudWatch alarms and metrics
- [ ] Create GCE instances with the Python client
- [ ] Manage Cloud Storage buckets and objects
- [ ] Create Azure VMs with networking
- [ ] Implement multi-cloud resource management
- [ ] Apply security best practices for credentials

---

# Part III: Infrastructure Automation

---

## 📘 Phase 9: Infrastructure as Code with Python

| Attribute | Value |
|-----------|-------|
| **Skill Level** | Advanced |
| **Time Estimate** | 6-8 weeks |
| **Prerequisites** | Phase 8 (Cloud Platform Mastery) |
| **Environment** | Local + Cloud accounts |

### Learning Objectives
By the end of this phase, you will be able to:
- Manage infrastructure with Terraform using Python automation
- Build infrastructure with Pulumi's Python SDK
- Implement infrastructure testing strategies
- Create reusable infrastructure modules
- Implement drift detection and remediation

### 9.1 Terraform Automation with Python
**📖 References:** [ORA: Ch.11], [BPB: Ch.15]

```python
#!/usr/bin/env python3
"""
Terraform Automation with Python
Manage Terraform workflows programmatically
"""
import subprocess
import json
import os
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass
import hcl2  # pip install python-hcl2

@dataclass
class TerraformOutput:
    """Represents a Terraform output value."""
    name: str
    value: any
    sensitive: bool
    type: str

@dataclass
class TerraformResource:
    """Represents a Terraform resource."""
    address: str
    type: str
    name: str
    provider: str
    values: Dict

class TerraformManager:
    """
    Automate Terraform operations with Python.

    Provides a wrapper around the Terraform CLI with
    structured output parsing and error handling.
    """

    def __init__(self, working_dir: str, var_file: str = None,
                 backend_config: Dict = None):
        """
        Initialize Terraform manager.

        Args:
            working_dir: Directory containing Terraform files
            var_file: Path to .tfvars file
            backend_config: Backend configuration overrides
        """
        self.working_dir = Path(working_dir)
        self.var_file = var_file
        self.backend_config = backend_config or {}
        self._verify_terraform()

    def _verify_terraform(self):
        """Verify Terraform is installed."""
        try:
            result = subprocess.run(
                ["terraform", "version", "-json"],
                capture_output=True, text=True, check=True
            )
            version_info = json.loads(result.stdout)
            print(f"Terraform {version_info['terraform_version']}")
        except FileNotFoundError:
            raise RuntimeError("Terraform not found. Please install Terraform.")

    def _run_terraform(self, args: List[str], capture_json: bool = False,
                       auto_approve: bool = False) -> subprocess.CompletedProcess:
        """Run a Terraform command."""
        cmd = ["terraform"] + args

        if capture_json and "-json" not in args:
            cmd.append("-json")

        if auto_approve and "apply" in args or "destroy" in args:
            cmd.append("-auto-approve")

        env = os.environ.copy()
        env["TF_IN_AUTOMATION"] = "true"

        return subprocess.run(
            cmd,
            cwd=self.working_dir,
            capture_output=True,
            text=True,
            env=env
        )

    # ==================== Core Operations ====================

    def init(self, upgrade: bool = False, reconfigure: bool = False) -> bool:
        """
        Initialize Terraform working directory.

        Args:
            upgrade: Upgrade modules and plugins
            reconfigure: Reconfigure backend
        """
        args = ["init"]

        if upgrade:
            args.append("-upgrade")
        if reconfigure:
            args.append("-reconfigure")

        for key, value in self.backend_config.items():
            args.extend(["-backend-config", f"{key}={value}"])

        result = self._run_terraform(args)

        if result.returncode != 0:
            print(f"❌ Init failed: {result.stderr}")
            return False

        print("✅ Terraform initialized")
        return True

    def plan(self, output_file: str = None, destroy: bool = False,
             target: List[str] = None, var: Dict[str, str] = None) -> Dict:
        """
        Create an execution plan.

        Args:
            output_file: Save plan to file
            destroy: Create destruction plan
            target: Target specific resources
            var: Variable overrides

        Returns:
            Plan summary
        """
        args = ["plan"]

        if output_file:
            args.extend(["-out", output_file])
        if destroy:
            args.append("-destroy")
        if self.var_file:
            args.extend(["-var-file", self.var_file])
        if target:
            for t in target:
                args.extend(["-target", t])
        if var:
            for k, v in var.items():
                args.extend(["-var", f"{k}={v}"])

        args.append("-json")

        result = self._run_terraform(args)

        # Parse JSON output lines
        changes = {"add": 0, "change": 0, "destroy": 0}
        resources = []

        for line in result.stdout.strip().split("\n"):
            if not line:
                continue
            try:
                msg = json.loads(line)
                if msg.get("type") == "change_summary":
                    changes = msg.get("changes", changes)
                elif msg.get("type") == "resource_drift":
                    resources.append(msg.get("change", {}))
            except json.JSONDecodeError:
                continue

        print(f"📋 Plan: +{changes['add']} ~{changes['change']} -{changes['destroy']}")
        return {"changes": changes, "resources": resources}

    def apply(self, plan_file: str = None, auto_approve: bool = False,
              target: List[str] = None, var: Dict[str, str] = None) -> bool:
        """
        Apply Terraform changes.

        Args:
            plan_file: Apply from saved plan
            auto_approve: Skip confirmation
            target: Target specific resources
            var: Variable overrides
        """
        args = ["apply"]

        if plan_file:
            args.append(plan_file)
        else:
            if self.var_file:
                args.extend(["-var-file", self.var_file])
            if target:
                for t in target:
                    args.extend(["-target", t])
            if var:
                for k, v in var.items():
                    args.extend(["-var", f"{k}={v}"])

        if auto_approve:
            args.append("-auto-approve")

        result = self._run_terraform(args)

        if result.returncode != 0:
            print(f"❌ Apply failed: {result.stderr}")
            return False

        print("✅ Terraform apply complete")
        return True

    def destroy(self, auto_approve: bool = False,
                target: List[str] = None) -> bool:
        """Destroy Terraform-managed infrastructure."""
        args = ["destroy"]

        if self.var_file:
            args.extend(["-var-file", self.var_file])
        if target:
            for t in target:
                args.extend(["-target", t])
        if auto_approve:
            args.append("-auto-approve")

        result = self._run_terraform(args)

        if result.returncode != 0:
            print(f"❌ Destroy failed: {result.stderr}")
            return False

        print("🗑️ Infrastructure destroyed")
        return True

    # ==================== State Management ====================

    def get_outputs(self) -> Dict[str, TerraformOutput]:
        """Get all Terraform outputs."""
        result = self._run_terraform(["output", "-json"])

        if result.returncode != 0:
            return {}

        outputs = {}
        data = json.loads(result.stdout)

        for name, info in data.items():
            outputs[name] = TerraformOutput(
                name=name,
                value=info.get("value"),
                sensitive=info.get("sensitive", False),
                type=str(info.get("type", "unknown"))
            )

        return outputs

    def get_state(self) -> List[TerraformResource]:
        """Get current Terraform state."""
        result = self._run_terraform(["show", "-json"])

        if result.returncode != 0:
            return []

        state = json.loads(result.stdout)
        resources = []

        # Parse resources from state
        for module in state.get("values", {}).get("root_module", {}).get("resources", []):
            resources.append(TerraformResource(
                address=module.get("address"),
                type=module.get("type"),
                name=module.get("name"),
                provider=module.get("provider_name"),
                values=module.get("values", {})
            ))

        return resources

    def import_resource(self, address: str, resource_id: str) -> bool:
        """Import existing infrastructure into Terraform state."""
        args = ["import"]

        if self.var_file:
            args.extend(["-var-file", self.var_file])

        args.extend([address, resource_id])

        result = self._run_terraform(args)

        if result.returncode != 0:
            print(f"❌ Import failed: {result.stderr}")
            return False

        print(f"✅ Imported: {address}")
        return True

    def state_mv(self, source: str, destination: str) -> bool:
        """Move a resource within Terraform state."""
        result = self._run_terraform(["state", "mv", source, destination])

        if result.returncode != 0:
            print(f"❌ State move failed: {result.stderr}")
            return False

        print(f"✅ Moved: {source} -> {destination}")
        return True

    def state_rm(self, address: str) -> bool:
        """Remove a resource from Terraform state (doesn't destroy)."""
        result = self._run_terraform(["state", "rm", address])

        if result.returncode != 0:
            print(f"❌ State remove failed: {result.stderr}")
            return False

        print(f"✅ Removed from state: {address}")
        return True

    # ==================== Validation & Formatting ====================

    def validate(self) -> Dict:
        """Validate Terraform configuration."""
        result = self._run_terraform(["validate", "-json"])
        validation = json.loads(result.stdout)

        if validation.get("valid"):
            print("✅ Configuration is valid")
        else:
            print("❌ Configuration has errors:")
            for diag in validation.get("diagnostics", []):
                print(f"  - {diag.get('summary')}")

        return validation

    def fmt(self, check: bool = False, recursive: bool = True) -> bool:
        """Format Terraform files."""
        args = ["fmt"]

        if check:
            args.append("-check")
        if recursive:
            args.append("-recursive")

        result = self._run_terraform(args)
        return result.returncode == 0

    # ==================== Workspace Management ====================

    def workspace_list(self) -> List[str]:
        """List all workspaces."""
        result = self._run_terraform(["workspace", "list"])
        workspaces = []

        for line in result.stdout.strip().split("\n"):
            ws = line.strip().lstrip("* ")
            if ws:
                workspaces.append(ws)

        return workspaces

    def workspace_select(self, name: str) -> bool:
        """Select a workspace."""
        result = self._run_terraform(["workspace", "select", name])
        return result.returncode == 0

    def workspace_new(self, name: str) -> bool:
        """Create a new workspace."""
        result = self._run_terraform(["workspace", "new", name])
        return result.returncode == 0


# Example usage
if __name__ == "__main__":
    tf = TerraformManager(
        working_dir="./infrastructure",
        var_file="prod.tfvars"
    )

    # Initialize
    tf.init()

    # Validate
    tf.validate()

    # Plan
    plan_summary = tf.plan(output_file="tfplan")
    print(f"Changes: {plan_summary['changes']}")

    # Apply (with auto-approve for automation)
    # tf.apply(plan_file="tfplan", auto_approve=True)

    # Get outputs
    outputs = tf.get_outputs()
    for name, output in outputs.items():
        if not output.sensitive:
            print(f"{name}: {output.value}")
```

### 9.2 Pulumi with Python SDK
**📖 References:** [ORA: Ch.11], [BPB: Ch.15]

```python
#!/usr/bin/env python3
"""
Infrastructure as Code with Pulumi Python SDK
pip install pulumi pulumi-aws pulumi-gcp pulumi-azure-native
"""
import pulumi
from pulumi import Config, Output, ResourceOptions
import pulumi_aws as aws
from typing import Dict, List, Optional

# ==================== VPC Module ====================

class VPCComponent(pulumi.ComponentResource):
    """
    Reusable VPC component with subnets and NAT gateway.

    This demonstrates Pulumi's component resource pattern
    for creating reusable infrastructure modules.
    """

    def __init__(self, name: str, cidr_block: str = "10.0.0.0/16",
                 availability_zones: List[str] = None,
                 enable_nat_gateway: bool = True,
                 opts: ResourceOptions = None):
        """
        Create a VPC with public and private subnets.

        Args:
            name: Component name
            cidr_block: VPC CIDR block
            availability_zones: List of AZs to use
            enable_nat_gateway: Create NAT gateway for private subnets
            opts: Pulumi resource options
        """
        super().__init__("custom:network:VPC", name, None, opts)

        self.availability_zones = availability_zones or ["us-east-1a", "us-east-1b"]

        # Create VPC
        self.vpc = aws.ec2.Vpc(
            f"{name}-vpc",
            cidr_block=cidr_block,
            enable_dns_hostnames=True,
            enable_dns_support=True,
            tags={"Name": f"{name}-vpc"},
            opts=ResourceOptions(parent=self)
        )

        # Internet Gateway
        self.igw = aws.ec2.InternetGateway(
            f"{name}-igw",
            vpc_id=self.vpc.id,
            tags={"Name": f"{name}-igw"},
            opts=ResourceOptions(parent=self)
        )

        # Public subnets
        self.public_subnets = []
        self.private_subnets = []

        for i, az in enumerate(self.availability_zones):
            # Public subnet
            public_subnet = aws.ec2.Subnet(
                f"{name}-public-{i}",
                vpc_id=self.vpc.id,
                cidr_block=f"10.0.{i}.0/24",
                availability_zone=az,
                map_public_ip_on_launch=True,
                tags={"Name": f"{name}-public-{az}"},
                opts=ResourceOptions(parent=self)
            )
            self.public_subnets.append(public_subnet)

            # Private subnet
            private_subnet = aws.ec2.Subnet(
                f"{name}-private-{i}",
                vpc_id=self.vpc.id,
                cidr_block=f"10.0.{100 + i}.0/24",
                availability_zone=az,
                tags={"Name": f"{name}-private-{az}"},
                opts=ResourceOptions(parent=self)
            )
            self.private_subnets.append(private_subnet)

        # Public route table
        self.public_route_table = aws.ec2.RouteTable(
            f"{name}-public-rt",
            vpc_id=self.vpc.id,
            routes=[{
                "cidr_block": "0.0.0.0/0",
                "gateway_id": self.igw.id
            }],
            tags={"Name": f"{name}-public-rt"},
            opts=ResourceOptions(parent=self)
        )

        # Associate public subnets with route table
        for i, subnet in enumerate(self.public_subnets):
            aws.ec2.RouteTableAssociation(
                f"{name}-public-rta-{i}",
                subnet_id=subnet.id,
                route_table_id=self.public_route_table.id,
                opts=ResourceOptions(parent=self)
            )

        # NAT Gateway (optional)
        if enable_nat_gateway:
            self.eip = aws.ec2.Eip(
                f"{name}-nat-eip",
                domain="vpc",
                tags={"Name": f"{name}-nat-eip"},
                opts=ResourceOptions(parent=self)
            )

            self.nat_gateway = aws.ec2.NatGateway(
                f"{name}-nat",
                subnet_id=self.public_subnets[0].id,
                allocation_id=self.eip.id,
                tags={"Name": f"{name}-nat"},
                opts=ResourceOptions(parent=self)
            )

            # Private route table
            self.private_route_table = aws.ec2.RouteTable(
                f"{name}-private-rt",
                vpc_id=self.vpc.id,
                routes=[{
                    "cidr_block": "0.0.0.0/0",
                    "nat_gateway_id": self.nat_gateway.id
                }],
                tags={"Name": f"{name}-private-rt"},
                opts=ResourceOptions(parent=self)
            )

            # Associate private subnets
            for i, subnet in enumerate(self.private_subnets):
                aws.ec2.RouteTableAssociation(
                    f"{name}-private-rta-{i}",
                    subnet_id=subnet.id,
                    route_table_id=self.private_route_table.id,
                    opts=ResourceOptions(parent=self)
                )

        # Register outputs
        self.register_outputs({
            "vpc_id": self.vpc.id,
            "public_subnet_ids": [s.id for s in self.public_subnets],
            "private_subnet_ids": [s.id for s in self.private_subnets]
        })


# ==================== EKS Cluster Component ====================

class EKSClusterComponent(pulumi.ComponentResource):
    """Reusable EKS cluster component."""

    def __init__(self, name: str, vpc_id: Output[str],
                 subnet_ids: List[Output[str]],
                 node_instance_type: str = "t3.medium",
                 desired_capacity: int = 2,
                 opts: ResourceOptions = None):
        """Create an EKS cluster with managed node group."""
        super().__init__("custom:container:EKSCluster", name, None, opts)

        # IAM Role for EKS Cluster
        self.cluster_role = aws.iam.Role(
            f"{name}-cluster-role",
            assume_role_policy=json.dumps({
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "eks.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }),
            opts=ResourceOptions(parent=self)
        )

        # Attach required policies
        aws.iam.RolePolicyAttachment(
            f"{name}-cluster-policy",
            role=self.cluster_role.name,
            policy_arn="arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
            opts=ResourceOptions(parent=self)
        )

        # EKS Cluster
        self.cluster = aws.eks.Cluster(
            f"{name}-cluster",
            role_arn=self.cluster_role.arn,
            vpc_config={
                "subnet_ids": subnet_ids,
                "endpoint_private_access": True,
                "endpoint_public_access": True
            },
            tags={"Name": name},
            opts=ResourceOptions(parent=self)
        )

        # Node group IAM role
        self.node_role = aws.iam.Role(
            f"{name}-node-role",
            assume_role_policy=json.dumps({
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "ec2.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }),
            opts=ResourceOptions(parent=self)
        )

        # Node policies
        for policy in [
            "AmazonEKSWorkerNodePolicy",
            "AmazonEKS_CNI_Policy",
            "AmazonEC2ContainerRegistryReadOnly"
        ]:
            aws.iam.RolePolicyAttachment(
                f"{name}-node-{policy}",
                role=self.node_role.name,
                policy_arn=f"arn:aws:iam::aws:policy/{policy}",
                opts=ResourceOptions(parent=self)
            )

        # Managed node group
        self.node_group = aws.eks.NodeGroup(
            f"{name}-nodes",
            cluster_name=self.cluster.name,
            node_role_arn=self.node_role.arn,
            subnet_ids=subnet_ids,
            scaling_config={
                "desired_size": desired_capacity,
                "max_size": desired_capacity * 2,
                "min_size": 1
            },
            instance_types=[node_instance_type],
            tags={"Name": f"{name}-nodes"},
            opts=ResourceOptions(parent=self)
        )

        self.register_outputs({
            "cluster_name": self.cluster.name,
            "cluster_endpoint": self.cluster.endpoint,
            "kubeconfig": self._generate_kubeconfig()
        })

    def _generate_kubeconfig(self) -> Output[str]:
        """Generate kubeconfig for the cluster."""
        return Output.all(
            self.cluster.name,
            self.cluster.endpoint,
            self.cluster.certificate_authority
        ).apply(lambda args: f"""
apiVersion: v1
clusters:
- cluster:
    server: {args[1]}
    certificate-authority-data: {args[2]['data']}
  name: {args[0]}
contexts:
- context:
    cluster: {args[0]}
    user: {args[0]}
  name: {args[0]}
current-context: {args[0]}
kind: Config
users:
- name: {args[0]}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - eks
        - get-token
        - --cluster-name
        - {args[0]}
""")


# ==================== Main Stack ====================

import json

# Configuration
config = Config()
environment = config.get("environment") or "dev"
project_name = pulumi.get_project()

# Create VPC
vpc = VPCComponent(
    f"{project_name}-{environment}",
    cidr_block="10.0.0.0/16",
    availability_zones=["us-east-1a", "us-east-1b"],
    enable_nat_gateway=environment == "prod"
)

# Create EKS Cluster
eks = EKSClusterComponent(
    f"{project_name}-{environment}",
    vpc_id=vpc.vpc.id,
    subnet_ids=[s.id for s in vpc.private_subnets],
    node_instance_type="t3.medium" if environment == "prod" else "t3.small",
    desired_capacity=3 if environment == "prod" else 2
)

# Exports
pulumi.export("vpc_id", vpc.vpc.id)
pulumi.export("cluster_name", eks.cluster.name)
pulumi.export("cluster_endpoint", eks.cluster.endpoint)
```

---

### 🔬 Micro-Lab 9.1: Terraform Module Development (45 min)

**Objective:** Create a reusable Terraform module with Python automation

```python
# terraform_module_lab.py
"""
Lab: Create and test a Terraform module
"""
from pathlib import Path
import json

def create_module_structure(module_name: str, base_path: str = "."):
    """
    Create a Terraform module structure.

    Module structure:
    modules/<name>/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    └── README.md
    """
    module_path = Path(base_path) / "modules" / module_name

    # TODO: Create the directory structure
    # TODO: Generate main.tf with resource definitions
    # TODO: Generate variables.tf with input variables
    # TODO: Generate outputs.tf with output values
    # TODO: Generate versions.tf with provider requirements
    # TODO: Generate README.md with documentation

    pass

def generate_module_documentation(module_path: str) -> str:
    """
    Generate documentation from Terraform files.

    Parse .tf files and generate markdown documentation
    with variables, outputs, and usage examples.
    """
    # TODO: Parse variables.tf for inputs
    # TODO: Parse outputs.tf for outputs
    # TODO: Generate markdown documentation
    pass

if __name__ == "__main__":
    # Create an S3 bucket module
    create_module_structure("s3-bucket")

    # Create documentation
    docs = generate_module_documentation("modules/s3-bucket")
    print(docs)
```

**Challenge:** Add automated testing with Terratest patterns

---

### 🧪 Phase Lab 9: Infrastructure as Code Pipeline

**Duration:** 6-8 hours

**Scenario:** Build a complete IaC automation platform

**Project structure**

**`iac-platform/`**

- `modules/`
  - `networking/`
  - `compute/`
  - `database/`
  - `security/`
- `environments/`
  - `dev/`
  - `staging/`
  - `prod/`
- `automation/`
  - `__init__.py`
  - `terraform_runner.py`
  - `drift_detector.py`
  - `cost_estimator.py`
  - `compliance_checker.py`
- `tests/`
  - `test_modules.py`
  - `test_compliance.py`
- `cli.py`
- `requirements.txt`

**Requirements**

1. Module Management:
   - Reusable Terraform modules
   - Version pinning and upgrades
   - Module documentation generation

2. Drift Detection:
   - Scheduled state comparison
   - Alert on unexpected changes
   - Automatic remediation options

3. Cost Estimation:
   - Pre-apply cost estimates
   - Monthly cost tracking
   - Budget alerts

4. Compliance Checking:
   - Security policy validation
   - Tagging enforcement
   - Best practice verification

**Deliverables**

- [ ] At least 3 reusable modules
- [ ] Drift detection automation
- [ ] Cost estimation integration
- [ ] Compliance rule engine
- [ ] CLI for all operations
- [ ] CI/CD integration examples


---

### ✅ Checkpoint: Phase 9 Self-Assessment

- [ ] Automate Terraform workflows with Python
- [ ] Manage Terraform state programmatically
- [ ] Create Pulumi infrastructure with Python
- [ ] Build reusable infrastructure components
- [ ] Implement drift detection
- [ ] Generate infrastructure documentation

---

## 📘 Phase 10: Configuration Management with Python

| Attribute | Value |
|-----------|-------|
| **Skill Level** | Advanced |
| **Time Estimate** | 4-6 weeks |
| **Prerequisites** | Phase 9 (Infrastructure as Code) |
| **Environment** | Local VMs or cloud instances |

### Learning Objectives
By the end of this phase, you will be able to:
- Automate Ansible playbook execution with Python
- Develop custom Ansible modules in Python
- Integrate configuration management with CI/CD
- Implement configuration drift detection
- Build dynamic inventory systems

### 10.1 Ansible Automation with Python
**📖 References:** [ORA: Ch.11], [BPB: Ch.13]

```python
#!/usr/bin/env python3
"""
Ansible Automation with Python
Control Ansible programmatically for configuration management
"""
import subprocess
import json
import yaml
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass
import tempfile

@dataclass
class PlaybookResult:
    """Result of a playbook execution."""
    success: bool
    changed: int
    failed: int
    skipped: int
    unreachable: int
    hosts: Dict[str, Dict]

class AnsibleManager:
    """
    Manage Ansible operations programmatically.

    Provides a Python interface for running playbooks,
    managing inventory, and working with Ansible vault.
    """

    def __init__(self, inventory_path: str = None,
                 vault_password_file: str = None,
                 config_file: str = None):
        """
        Initialize Ansible manager.

        Args:
            inventory_path: Path to inventory file or directory
            vault_password_file: Path to vault password file
            config_file: Path to ansible.cfg
        """
        self.inventory_path = inventory_path
        self.vault_password_file = vault_password_file
        self.config_file = config_file
        self._verify_ansible()

    def _verify_ansible(self):
        """Verify Ansible is installed."""
        try:
            result = subprocess.run(
                ["ansible", "--version"],
                capture_output=True, text=True, check=True
            )
            version_line = result.stdout.split("\n")[0]
            print(f"✓ {version_line}")
        except FileNotFoundError:
            raise RuntimeError("Ansible not found. Please install Ansible.")

    def _build_base_args(self) -> List[str]:
        """Build common command arguments."""
        args = []

        if self.inventory_path:
            args.extend(["-i", self.inventory_path])

        if self.vault_password_file:
            args.extend(["--vault-password-file", self.vault_password_file])

        return args

    # ==================== Playbook Operations ====================

    def run_playbook(self, playbook_path: str,
                     extra_vars: Dict = None,
                     limit: str = None,
                     tags: List[str] = None,
                     skip_tags: List[str] = None,
                     check: bool = False,
                     diff: bool = False,
                     verbose: int = 0) -> PlaybookResult:
        """
        Run an Ansible playbook.

        Args:
            playbook_path: Path to playbook file
            extra_vars: Extra variables to pass
            limit: Limit execution to specific hosts
            tags: Only run tasks with these tags
            skip_tags: Skip tasks with these tags
            check: Dry run mode
            diff: Show differences
            verbose: Verbosity level (0-4)

        Returns:
            PlaybookResult with execution details
        """
        cmd = ["ansible-playbook", playbook_path]
        cmd.extend(self._build_base_args())

        if extra_vars:
            cmd.extend(["-e", json.dumps(extra_vars)])

        if limit:
            cmd.extend(["--limit", limit])

        if tags:
            cmd.extend(["--tags", ",".join(tags)])

        if skip_tags:
            cmd.extend(["--skip-tags", ",".join(skip_tags)])

        if check:
            cmd.append("--check")

        if diff:
            cmd.append("--diff")

        if verbose > 0:
            cmd.append("-" + "v" * min(verbose, 4))

        # Use JSON callback for structured output
        env = {"ANSIBLE_STDOUT_CALLBACK": "json"}

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env={**subprocess.os.environ, **env}
        )

        return self._parse_playbook_result(result)

    def _parse_playbook_result(self, result: subprocess.CompletedProcess) -> PlaybookResult:
        """Parse playbook execution result."""
        try:
            output = json.loads(result.stdout)
            stats = output.get("stats", {})

            total_changed = 0
            total_failed = 0
            total_skipped = 0
            total_unreachable = 0
            hosts = {}

            for host, host_stats in stats.items():
                hosts[host] = host_stats
                total_changed += host_stats.get("changed", 0)
                total_failed += host_stats.get("failures", 0)
                total_skipped += host_stats.get("skipped", 0)
                total_unreachable += host_stats.get("unreachable", 0)

            success = total_failed == 0 and total_unreachable == 0

            return PlaybookResult(
                success=success,
                changed=total_changed,
                failed=total_failed,
                skipped=total_skipped,
                unreachable=total_unreachable,
                hosts=hosts
            )

        except json.JSONDecodeError:
            # Fallback for non-JSON output
            return PlaybookResult(
                success=result.returncode == 0,
                changed=0,
                failed=1 if result.returncode != 0 else 0,
                skipped=0,
                unreachable=0,
                hosts={}
            )

    # ==================== Ad-hoc Commands ====================

    def run_command(self, hosts: str, module: str,
                    args: str = None, become: bool = False) -> Dict:
        """
        Run an ad-hoc Ansible command.

        Args:
            hosts: Host pattern
            module: Module name (e.g., 'ping', 'shell', 'copy')
            args: Module arguments
            become: Use privilege escalation

        Returns:
            Dict with results per host
        """
        cmd = ["ansible", hosts, "-m", module]
        cmd.extend(self._build_base_args())

        if args:
            cmd.extend(["-a", args])

        if become:
            cmd.append("--become")

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True
        )

        # Parse output (simplified)
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    def ping_hosts(self, hosts: str = "all") -> Dict[str, bool]:
        """Ping hosts to check connectivity."""
        result = self.run_command(hosts, "ping")
        # Parse ping results
        host_status = {}

        for line in result["stdout"].split("\n"):
            if "SUCCESS" in line:
                host = line.split("|")[0].strip()
                host_status[host] = True
            elif "UNREACHABLE" in line or "FAILED" in line:
                host = line.split("|")[0].strip()
                host_status[host] = False

        return host_status

    # ==================== Inventory Management ====================

    def get_inventory(self, host_pattern: str = "all") -> Dict:
        """Get inventory as structured data."""
        cmd = ["ansible-inventory", "--list"]
        cmd.extend(self._build_base_args())

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )

        return json.loads(result.stdout)

    def create_dynamic_inventory(self, hosts: List[Dict]) -> str:
        """
        Create a temporary dynamic inventory file.

        Args:
            hosts: List of host definitions with:
                - name: hostname or IP
                - groups: list of group names
                - vars: host variables

        Returns:
            Path to temporary inventory file
        """
        inventory = {"all": {"children": {}}}

        for host in hosts:
            for group in host.get("groups", ["ungrouped"]):
                if group not in inventory["all"]["children"]:
                    inventory["all"]["children"][group] = {"hosts": {}}

                inventory["all"]["children"][group]["hosts"][host["name"]] = host.get("vars", {})

        # Write to temp file
        fd, path = tempfile.mkstemp(suffix=".json")
        with open(path, "w") as f:
            json.dump(inventory, f)

        return path

    # ==================== Vault Operations ====================

    def vault_encrypt(self, content: str, vault_id: str = None) -> str:
        """Encrypt content with Ansible Vault."""
        cmd = ["ansible-vault", "encrypt_string", "--stdin-name", "secret"]

        if vault_id:
            cmd.extend(["--vault-id", vault_id])
        elif self.vault_password_file:
            cmd.extend(["--vault-password-file", self.vault_password_file])

        result = subprocess.run(
            cmd,
            input=content,
            capture_output=True,
            text=True,
            check=True
        )

        return result.stdout

    def vault_decrypt(self, encrypted_content: str) -> str:
        """Decrypt Ansible Vault content."""
        # Write encrypted content to temp file
        fd, path = tempfile.mkstemp()
        with open(path, "w") as f:
            f.write(encrypted_content)

        cmd = ["ansible-vault", "decrypt", path, "--output", "-"]

        if self.vault_password_file:
            cmd.extend(["--vault-password-file", self.vault_password_file])

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )

        Path(path).unlink()  # Clean up
        return result.stdout


# Example usage
if __name__ == "__main__":
    ansible = AnsibleManager(
        inventory_path="inventory/",
        vault_password_file=".vault_pass"
    )

    # Ping all hosts
    status = ansible.ping_hosts()
    print(f"Host status: {status}")

    # Run a playbook
    result = ansible.run_playbook(
        "playbooks/deploy.yml",
        extra_vars={"version": "1.2.3"},
        limit="webservers",
        check=True  # Dry run
    )

    print(f"Playbook result: {result}")
```

### 10.2 Custom Ansible Modules
**📖 References:** [ORA: Ch.11], [BPB: Ch.13]

```python
#!/usr/bin/env python3
"""
Custom Ansible Module: Manage Application Configuration
Place in: library/app_config.py
"""

DOCUMENTATION = '''
---
module: app_config
short_description: Manage application configuration files
description:
    - Manages JSON/YAML configuration files for applications
    - Supports merging, validation, and atomic updates
options:
    path:
        description: Path to the configuration file
        required: true
        type: str
    state:
        description: Desired state of the configuration
        choices: ['present', 'absent', 'merged']
        default: present
        type: str
    content:
        description: Configuration content (dict)
        required: false
        type: dict
    format:
        description: Configuration file format
        choices: ['json', 'yaml']
        default: json
        type: str
    validate:
        description: Validate configuration with JSON schema
        required: false
        type: dict
    backup:
        description: Create backup before modifying
        default: true
        type: bool
author: DevOps Team
'''

EXAMPLES = '''
# Set application configuration
- name: Configure application
  app_config:
    path: /etc/myapp/config.json
    content:
      database:
        host: localhost
        port: 5432
      logging:
        level: INFO

# Merge configuration
- name: Update logging level
  app_config:
    path: /etc/myapp/config.json
    state: merged
    content:
      logging:
        level: DEBUG
'''

RETURN = '''
changed:
    description: Whether the file was modified
    type: bool
    returned: always
backup_path:
    description: Path to backup file if created
    type: str
    returned: when backup=true and file modified
diff:
    description: Configuration differences
    type: dict
    returned: when changed
'''

from ansible.module_utils.basic import AnsibleModule
import json
import os
import shutil
from datetime import datetime
from copy import deepcopy

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

try:
    import jsonschema
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False


def deep_merge(base: dict, updates: dict) -> dict:
    """Recursively merge updates into base dictionary."""
    result = deepcopy(base)

    for key, value in updates.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = deepcopy(value)

    return result


def load_config(path: str, format: str) -> dict:
    """Load configuration from file."""
    if not os.path.exists(path):
        return {}

    with open(path, 'r') as f:
        if format == 'yaml':
            return yaml.safe_load(f) or {}
        else:
            return json.load(f)


def save_config(path: str, config: dict, format: str):
    """Save configuration to file atomically."""
    # Write to temp file first
    temp_path = f"{path}.tmp"

    with open(temp_path, 'w') as f:
        if format == 'yaml':
            yaml.safe_dump(config, f, default_flow_style=False)
        else:
            json.dump(config, f, indent=2)

    # Atomic rename
    os.rename(temp_path, path)


def validate_config(config: dict, schema: dict) -> tuple:
    """Validate configuration against JSON schema."""
    if not HAS_JSONSCHEMA:
        return False, "jsonschema module not installed"

    try:
        jsonschema.validate(config, schema)
        return True, None
    except jsonschema.ValidationError as e:
        return False, str(e)


def create_backup(path: str) -> str:
    """Create a timestamped backup of the file."""
    if not os.path.exists(path):
        return None

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = f"{path}.{timestamp}.bak"
    shutil.copy2(path, backup_path)
    return backup_path


def main():
    module = AnsibleModule(
        argument_spec={
            'path': {'type': 'str', 'required': True},
            'state': {'type': 'str', 'choices': ['present', 'absent', 'merged'], 'default': 'present'},
            'content': {'type': 'dict', 'required': False, 'default': {}},
            'format': {'type': 'str', 'choices': ['json', 'yaml'], 'default': 'json'},
            'validate': {'type': 'dict', 'required': False},
            'backup': {'type': 'bool', 'default': True},
        },
        supports_check_mode=True
    )

    path = module.params['path']
    state = module.params['state']
    content = module.params['content']
    format = module.params['format']
    schema = module.params['validate']
    backup = module.params['backup']

    # Check dependencies
    if format == 'yaml' and not HAS_YAML:
        module.fail_json(msg="PyYAML is required for YAML format")

    result = {
        'changed': False,
        'path': path,
    }

    # Load current configuration
    current_config = load_config(path, format)

    if state == 'absent':
        if os.path.exists(path):
            if not module.check_mode:
                if backup:
                    result['backup_path'] = create_backup(path)
                os.remove(path)
            result['changed'] = True

    elif state == 'present':
        if current_config != content:
            # Validate new configuration
            if schema:
                valid, error = validate_config(content, schema)
                if not valid:
                    module.fail_json(msg=f"Configuration validation failed: {error}")

            if not module.check_mode:
                if backup and os.path.exists(path):
                    result['backup_path'] = create_backup(path)
                save_config(path, content, format)

            result['changed'] = True
            result['diff'] = {
                'before': current_config,
                'after': content
            }

    elif state == 'merged':
        merged_config = deep_merge(current_config, content)

        if current_config != merged_config:
            # Validate merged configuration
            if schema:
                valid, error = validate_config(merged_config, schema)
                if not valid:
                    module.fail_json(msg=f"Configuration validation failed: {error}")

            if not module.check_mode:
                if backup and os.path.exists(path):
                    result['backup_path'] = create_backup(path)
                save_config(path, merged_config, format)

            result['changed'] = True
            result['diff'] = {
                'before': current_config,
                'after': merged_config
            }

    module.exit_json(**result)


if __name__ == '__main__':
    main()
```

---

### 🧪 Phase Lab 10: Configuration Management Platform

**Duration:** 4-6 hours

**Scenario:** Build an automated configuration management system

**Project structure**

**`config-manager/`**

- `playbooks/`
  - `site.yml`
  - `webservers.yml`
  - `databases.yml`
  - `monitoring.yml`
- `roles/`
  - `common/`
  - `nginx/`
  - `postgresql/`
  - `prometheus/`
- `library/`
  - `app_config.py` — Custom module
- `inventory/`
  - `production/`
  - `staging/`
  - `development/`
- `automation/`
  - `__init__.py`
  - `ansible_runner.py`
  - `drift_checker.py`
  - `config_validator.py`
- `tests/`
  - `test_playbooks.py`
- `cli.py`

**Requirements**

1. Ansible Automation:
   - Python wrapper for playbook execution
   - Dynamic inventory from cloud providers
   - Parallel execution across environments

2. Configuration Drift Detection:
   - Scheduled compliance checks
   - Drift reporting and alerting
   - Automatic remediation

3. Secret Management:
   - Ansible Vault integration
   - External secret store support
   - Secret rotation automation

**Deliverables**

- [ ] At least 4 reusable roles
- [ ] Custom Ansible module
- [ ] Dynamic inventory script
- [ ] Drift detection automation
- [ ] CLI for all operations


---

## 📘 Phase 11: CI/CD Pipeline Automation

| Attribute | Value |
|-----------|-------|
| **Skill Level** | Advanced |
| **Time Estimate** | 6-8 weeks |
| **Prerequisites** | Phase 10 (Configuration Management) |
| **Environment** | GitHub/GitLab + CI runners |

### Learning Objectives
By the end of this phase, you will be able to:
- Build CI/CD pipelines with GitHub Actions and GitLab CI
- Create Python automation for Jenkins pipelines
- Implement advanced deployment strategies
- Build automated testing and quality gates
- Integrate security scanning into pipelines

### 11.1 GitHub Actions Automation
**📖 References:** [ORA: Ch.12], [BPB: Ch.16]

```python
#!/usr/bin/env python3
"""
GitHub Actions Automation with Python
Manage workflows and actions programmatically
"""
import requests
from typing import Dict, List, Optional
from dataclasses import dataclass
from datetime import datetime
import base64
import yaml
import os

@dataclass
class WorkflowRun:
    """Represents a GitHub Actions workflow run."""
    id: int
    name: str
    status: str
    conclusion: Optional[str]
    created_at: str
    updated_at: str
    html_url: str
    head_branch: str
    head_sha: str

@dataclass
class WorkflowJob:
    """Represents a job within a workflow run."""
    id: int
    name: str
    status: str
    conclusion: Optional[str]
    started_at: Optional[str]
    completed_at: Optional[str]
    steps: List[Dict]

class GitHubActionsManager:
    """
    Manage GitHub Actions workflows and runs.

    Provides automation capabilities for:
    - Triggering workflows
    - Monitoring run status
    - Managing secrets
    - Analyzing workflow performance
    """

    def __init__(self, token: str, owner: str, repo: str):
        """
        Initialize GitHub Actions manager.

        Args:
            token: GitHub personal access token
            owner: Repository owner
            repo: Repository name
        """
        self.token = token
        self.owner = owner
        self.repo = repo
        self.base_url = f"https://api.github.com/repos/{owner}/{repo}"
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        }

    def _request(self, method: str, endpoint: str,
                 data: Dict = None, params: Dict = None) -> Dict:
        """Make an authenticated request to GitHub API."""
        url = f"{self.base_url}{endpoint}"

        response = requests.request(
            method=method,
            url=url,
            headers=self.headers,
            json=data,
            params=params
        )

        if response.status_code >= 400:
            raise Exception(f"GitHub API error: {response.status_code} - {response.text}")

        return response.json() if response.text else {}

    # ==================== Workflow Operations ====================

    def list_workflows(self) -> List[Dict]:
        """List all workflows in the repository."""
        result = self._request("GET", "/actions/workflows")
        return result.get("workflows", [])

    def get_workflow(self, workflow_id: int) -> Dict:
        """Get a specific workflow by ID."""
        return self._request("GET", f"/actions/workflows/{workflow_id}")

    def trigger_workflow(self, workflow_id: int, ref: str = "main",
                        inputs: Dict[str, str] = None) -> bool:
        """
        Trigger a workflow dispatch event.

        Args:
            workflow_id: Workflow ID or filename
            ref: Git reference (branch, tag, or SHA)
            inputs: Workflow input parameters
        """
        data = {"ref": ref}
        if inputs:
            data["inputs"] = inputs

        self._request("POST", f"/actions/workflows/{workflow_id}/dispatches", data=data)
        print(f"✅ Triggered workflow {workflow_id} on {ref}")
        return True

    # ==================== Workflow Runs ====================

    def list_workflow_runs(self, workflow_id: int = None,
                          status: str = None,
                          branch: str = None,
                          per_page: int = 30) -> List[WorkflowRun]:
        """
        List workflow runs with optional filtering.

        Args:
            workflow_id: Filter by workflow
            status: Filter by status (queued, in_progress, completed)
            branch: Filter by branch
            per_page: Results per page
        """
        params = {"per_page": per_page}
        if status:
            params["status"] = status
        if branch:
            params["branch"] = branch

        if workflow_id:
            endpoint = f"/actions/workflows/{workflow_id}/runs"
        else:
            endpoint = "/actions/runs"

        result = self._request("GET", endpoint, params=params)

        return [
            WorkflowRun(
                id=run["id"],
                name=run["name"],
                status=run["status"],
                conclusion=run.get("conclusion"),
                created_at=run["created_at"],
                updated_at=run["updated_at"],
                html_url=run["html_url"],
                head_branch=run["head_branch"],
                head_sha=run["head_sha"]
            )
            for run in result.get("workflow_runs", [])
        ]

    def get_workflow_run(self, run_id: int) -> WorkflowRun:
        """Get details of a specific workflow run."""
        run = self._request("GET", f"/actions/runs/{run_id}")
        return WorkflowRun(
            id=run["id"],
            name=run["name"],
            status=run["status"],
            conclusion=run.get("conclusion"),
            created_at=run["created_at"],
            updated_at=run["updated_at"],
            html_url=run["html_url"],
            head_branch=run["head_branch"],
            head_sha=run["head_sha"]
        )

    def wait_for_run(self, run_id: int, timeout: int = 600,
                     poll_interval: int = 10) -> WorkflowRun:
        """Wait for a workflow run to complete."""
        import time
        start_time = time.time()

        while time.time() - start_time < timeout:
            run = self.get_workflow_run(run_id)

            if run.status == "completed":
                return run

            print(f"⏳ Run {run_id}: {run.status}...")
            time.sleep(poll_interval)

        raise TimeoutError(f"Workflow run {run_id} did not complete within {timeout}s")

    def cancel_run(self, run_id: int) -> bool:
        """Cancel a workflow run."""
        self._request("POST", f"/actions/runs/{run_id}/cancel")
        print(f"🛑 Cancelled run {run_id}")
        return True

    def rerun_workflow(self, run_id: int, failed_only: bool = False) -> bool:
        """Re-run a workflow."""
        endpoint = f"/actions/runs/{run_id}/rerun"
        if failed_only:
            endpoint = f"/actions/runs/{run_id}/rerun-failed-jobs"

        self._request("POST", endpoint)
        print(f"🔄 Re-running workflow {run_id}")
        return True

    # ==================== Jobs ====================

    def list_jobs(self, run_id: int) -> List[WorkflowJob]:
        """List jobs for a workflow run."""
        result = self._request("GET", f"/actions/runs/{run_id}/jobs")

        return [
            WorkflowJob(
                id=job["id"],
                name=job["name"],
                status=job["status"],
                conclusion=job.get("conclusion"),
                started_at=job.get("started_at"),
                completed_at=job.get("completed_at"),
                steps=job.get("steps", [])
            )
            for job in result.get("jobs", [])
        ]

    def get_job_logs(self, job_id: int) -> str:
        """Download logs for a job."""
        response = requests.get(
            f"{self.base_url}/actions/jobs/{job_id}/logs",
            headers=self.headers,
            allow_redirects=True
        )
        return response.text

    # ==================== Secrets ====================

    def get_public_key(self) -> Dict:
        """Get the repository's public key for encrypting secrets."""
        return self._request("GET", "/actions/secrets/public-key")

    def list_secrets(self) -> List[str]:
        """List all repository secrets (names only)."""
        result = self._request("GET", "/actions/secrets")
        return [s["name"] for s in result.get("secrets", [])]

    def create_or_update_secret(self, name: str, value: str) -> bool:
        """
        Create or update a repository secret.

        Uses libsodium for encryption (requires pynacl).
        """
        from nacl import encoding, public

        # Get public key
        key_data = self.get_public_key()
        public_key = public.PublicKey(
            key_data["key"].encode("utf-8"),
            encoding.Base64Encoder()
        )

        # Encrypt the secret
        sealed_box = public.SealedBox(public_key)
        encrypted = sealed_box.encrypt(value.encode("utf-8"))
        encrypted_value = base64.b64encode(encrypted).decode("utf-8")

        # Create/update secret
        self._request(
            "PUT",
            f"/actions/secrets/{name}",
            data={
                "encrypted_value": encrypted_value,
                "key_id": key_data["key_id"]
            }
        )

        print(f"✅ Secret '{name}' updated")
        return True

    def delete_secret(self, name: str) -> bool:
        """Delete a repository secret."""
        self._request("DELETE", f"/actions/secrets/{name}")
        print(f"🗑️ Deleted secret '{name}'")
        return True

    # ==================== Analytics ====================

    def get_workflow_usage(self, workflow_id: int) -> Dict:
        """Get workflow timing usage."""
        return self._request("GET", f"/actions/workflows/{workflow_id}/timing")

    def get_run_usage(self, run_id: int) -> Dict:
        """Get usage for a specific run."""
        return self._request("GET", f"/actions/runs/{run_id}/timing")


# Example usage
if __name__ == "__main__":
    token = os.environ.get("GITHUB_TOKEN")
    gh = GitHubActionsManager(token, "myorg", "myrepo")

    # List workflows
    workflows = gh.list_workflows()
    for wf in workflows:
        print(f"{wf['name']} (ID: {wf['id']})")

    # Trigger a workflow
    gh.trigger_workflow(
        workflow_id="deploy.yml",
        ref="main",
        inputs={"environment": "staging"}
    )

    # Get recent runs
    runs = gh.list_workflow_runs(status="completed", per_page=5)
    for run in runs:
        status_emoji = "✅" if run.conclusion == "success" else "❌"
        print(f"{status_emoji} {run.name}: {run.conclusion}")
```

### 11.2 Jenkins Pipeline Automation
**📖 References:** [ORA: Ch.12], [BPB: Ch.16]

```python
#!/usr/bin/env python3
"""
Jenkins Automation with Python
Manage Jenkins jobs and pipelines programmatically
pip install python-jenkins
"""
import jenkins
from typing import Dict, List, Optional
from dataclasses import dataclass
import time
import xml.etree.ElementTree as ET

@dataclass
class JenkinsBuild:
    """Represents a Jenkins build."""
    number: int
    result: Optional[str]
    building: bool
    duration: int
    timestamp: int
    url: str

@dataclass
class JenkinsJob:
    """Represents a Jenkins job."""
    name: str
    url: str
    color: str
    last_build: Optional[JenkinsBuild]

class JenkinsManager:
    """
    Manage Jenkins jobs and builds programmatically.

    Features:
    - Job management (create, update, delete)
    - Build triggering and monitoring
    - Pipeline management
    - Credential management
    """

    def __init__(self, url: str, username: str, password: str):
        """
        Initialize Jenkins connection.

        Args:
            url: Jenkins server URL
            username: Jenkins username
            password: Jenkins API token or password
        """
        self.server = jenkins.Jenkins(url, username=username, password=password)
        self._verify_connection()

    def _verify_connection(self):
        """Verify Jenkins connection."""
        user = self.server.get_whoami()
        version = self.server.get_version()
        print(f"✓ Connected to Jenkins {version} as {user['fullName']}")

    # ==================== Job Management ====================

    def list_jobs(self, folder: str = None) -> List[JenkinsJob]:
        """List all jobs, optionally within a folder."""
        if folder:
            jobs = self.server.get_job_info(folder).get("jobs", [])
        else:
            jobs = self.server.get_jobs()

        result = []
        for job in jobs:
            job_info = self.server.get_job_info(job["name"])
            last_build = None

            if job_info.get("lastBuild"):
                build_info = self.server.get_build_info(
                    job["name"],
                    job_info["lastBuild"]["number"]
                )
                last_build = JenkinsBuild(
                    number=build_info["number"],
                    result=build_info.get("result"),
                    building=build_info["building"],
                    duration=build_info["duration"],
                    timestamp=build_info["timestamp"],
                    url=build_info["url"]
                )

            result.append(JenkinsJob(
                name=job["name"],
                url=job.get("url", ""),
                color=job.get("color", ""),
                last_build=last_build
            ))

        return result

    def create_job(self, name: str, config_xml: str) -> bool:
        """Create a new Jenkins job."""
        self.server.create_job(name, config_xml)
        print(f"✅ Created job: {name}")
        return True

    def update_job(self, name: str, config_xml: str) -> bool:
        """Update an existing Jenkins job."""
        self.server.reconfig_job(name, config_xml)
        print(f"🔄 Updated job: {name}")
        return True

    def delete_job(self, name: str) -> bool:
        """Delete a Jenkins job."""
        self.server.delete_job(name)
        print(f"🗑️ Deleted job: {name}")
        return True

    def get_job_config(self, name: str) -> str:
        """Get job configuration XML."""
        return self.server.get_job_config(name)

    def create_pipeline_job(self, name: str, jenkinsfile: str,
                           description: str = "",
                           scm_url: str = None,
                           branch: str = "main") -> bool:
        """
        Create a Pipeline job from Jenkinsfile content or SCM.

        Args:
            name: Job name
            jenkinsfile: Jenkinsfile content (if inline)
            description: Job description
            scm_url: Git repository URL (for SCM-based pipeline)
            branch: Git branch
        """
        if scm_url:
            # Pipeline from SCM
            config = f'''<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>{description}</description>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>{scm_url}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/{branch}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
</flow-definition>'''
        else:
            # Inline pipeline
            config = f'''<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>{description}</description>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script><![CDATA[{jenkinsfile}]]></script>
    <sandbox>true</sandbox>
  </definition>
</flow-definition>'''

        return self.create_job(name, config)

    # ==================== Build Operations ====================

    def trigger_build(self, job_name: str, parameters: Dict = None,
                     wait: bool = False, timeout: int = 600) -> Optional[int]:
        """
        Trigger a build and optionally wait for completion.

        Args:
            job_name: Name of the job
            parameters: Build parameters
            wait: Wait for build to complete
            timeout: Timeout in seconds when waiting

        Returns:
            Build number if wait=True and completed
        """
        queue_id = self.server.build_job(job_name, parameters=parameters)
        print(f"🚀 Triggered build for {job_name} (queue: {queue_id})")

        if not wait:
            return None

        # Wait for build to start
        build_number = None
        start_time = time.time()

        while time.time() - start_time < 60:
            queue_item = self.server.get_queue_item(queue_id)
            if queue_item.get("executable"):
                build_number = queue_item["executable"]["number"]
                break
            time.sleep(2)

        if not build_number:
            raise TimeoutError("Build did not start within 60 seconds")

        # Wait for build to complete
        return self.wait_for_build(job_name, build_number, timeout)

    def wait_for_build(self, job_name: str, build_number: int,
                       timeout: int = 600) -> int:
        """Wait for a build to complete."""
        start_time = time.time()

        while time.time() - start_time < timeout:
            build_info = self.server.get_build_info(job_name, build_number)

            if not build_info["building"]:
                result = build_info.get("result", "UNKNOWN")
                emoji = "✅" if result == "SUCCESS" else "❌"
                print(f"{emoji} Build #{build_number}: {result}")
                return build_number

            print(f"⏳ Build #{build_number} in progress...")
            time.sleep(10)

        raise TimeoutError(f"Build did not complete within {timeout}s")

    def get_build_info(self, job_name: str, build_number: int) -> JenkinsBuild:
        """Get detailed build information."""
        build = self.server.get_build_info(job_name, build_number)
        return JenkinsBuild(
            number=build["number"],
            result=build.get("result"),
            building=build["building"],
            duration=build["duration"],
            timestamp=build["timestamp"],
            url=build["url"]
        )

    def get_build_console(self, job_name: str, build_number: int) -> str:
        """Get build console output."""
        return self.server.get_build_console_output(job_name, build_number)

    def stop_build(self, job_name: str, build_number: int) -> bool:
        """Stop a running build."""
        self.server.stop_build(job_name, build_number)
        print(f"🛑 Stopped build #{build_number}")
        return True

    # ==================== Node Management ====================

    def list_nodes(self) -> List[Dict]:
        """List all Jenkins nodes/agents."""
        nodes = self.server.get_nodes()
        result = []

        for node in nodes:
            node_info = self.server.get_node_info(node["name"])
            result.append({
                "name": node["name"],
                "offline": node_info.get("offline", False),
                "temporarilyOffline": node_info.get("temporarilyOffline", False),
                "numExecutors": node_info.get("numExecutors", 0)
            })

        return result

    def set_node_offline(self, node_name: str, message: str = "") -> bool:
        """Set a node offline."""
        self.server.disable_node(node_name, message)
        print(f"⏸️ Node '{node_name}' set offline")
        return True

    def set_node_online(self, node_name: str) -> bool:
        """Set a node online."""
        self.server.enable_node(node_name)
        print(f"▶️ Node '{node_name}' set online")
        return True


# Example Jenkinsfile generator
def generate_jenkinsfile(stages: List[Dict], agent: str = "any",
                        environment: Dict = None) -> str:
    """
    Generate a Jenkinsfile from structured data.

    Args:
        stages: List of stage definitions
        agent: Agent specification
        environment: Environment variables
    """
    lines = ["pipeline {"]
    lines.append(f"    agent {agent}")

    if environment:
        lines.append("    environment {")
        for key, value in environment.items():
            lines.append(f"        {key} = '{value}'")
        lines.append("    }")

    lines.append("    stages {")

    for stage in stages:
        lines.append(f"        stage('{stage['name']}') {{")
        lines.append("            steps {")

        for step in stage.get("steps", []):
            if step["type"] == "sh":
                lines.append(f"                sh '{step['script']}'")
            elif step["type"] == "echo":
                lines.append(f"                echo '{step['message']}'")

        lines.append("            }")
        lines.append("        }")

    lines.append("    }")
    lines.append("}")

    return "\n".join(lines)


# Example usage
if __name__ == "__main__":
    jenkins_mgr = JenkinsManager(
        url="http://localhost:8080",
        username="admin",
        password=os.environ.get("JENKINS_TOKEN")
    )

    # Generate and create a pipeline
    jenkinsfile = generate_jenkinsfile(
        stages=[
            {
                "name": "Build",
                "steps": [
                    {"type": "sh", "script": "python -m build"}
                ]
            },
            {
                "name": "Test",
                "steps": [
                    {"type": "sh", "script": "pytest tests/"}
                ]
            },
            {
                "name": "Deploy",
                "steps": [
                    {"type": "sh", "script": "deploy.sh"}
                ]
            }
        ],
        environment={"PYTHONPATH": "."}
    )

    jenkins_mgr.create_pipeline_job(
        name="my-python-app",
        jenkinsfile=jenkinsfile,
        description="Python application CI/CD"
    )
```

---

### 🧪 Phase Lab 11: CI/CD Pipeline Generator

**Duration:** 6-8 hours

**Scenario:** Build a tool that generates CI/CD pipelines from configuration

**Project structure**

**`pipeline-generator/`**

- `src/`
  - `__init__.py`
  - `parsers/`
    - `__init__.py`
    - `github_actions.py`
    - `gitlab_ci.py`
    - `jenkins.py`
  - `generators/`
    - `__init__.py`
    - `github_actions.py`
    - `gitlab_ci.py`
    - `jenkinsfile.py`
  - `templates/`
    - `python.yaml`
    - `nodejs.yaml`
    - `docker.yaml`
  - `cli.py`
- `tests/`
- `examples/`
- `requirements.txt`

**Requirements**

1. Pipeline Definition:
   - YAML-based pipeline configuration
   - Language/framework detection
   - Template inheritance

2. Generator Support:
   - GitHub Actions workflows
   - GitLab CI pipelines
   - Jenkinsfile generation

3. Features:
   - Secret management
   - Matrix builds
   - Deployment strategies
   - Notification integration

**Deliverables**

- [ ] Pipeline configuration schema
- [ ] Generators for 3 CI systems
- [ ] Language-specific templates
- [ ] CLI with validation
- [ ] Documentation and examples


---

## 📘 Phase 12: Monitoring & Observability

| Attribute | Value |
|-----------|-------|
| **Skill Level** | Advanced |
| **Time Estimate** | 6-8 weeks |
| **Prerequisites** | Phase 11 (CI/CD Pipelines) |
| **Environment** | Local + Prometheus/Grafana stack |

### Learning Objectives
By the end of this phase, you will be able to:
- Implement custom metrics with Prometheus client
- Build monitoring dashboards programmatically
- Create alerting systems and runbooks
- Implement distributed tracing
- Build log aggregation and analysis tools

### 12.1 Prometheus Metrics with Python
**📖 References:** [ORA: Ch.13], [BPB: Ch.11]

```python
#!/usr/bin/env python3
"""
Prometheus Metrics Implementation with Python
pip install prometheus-client
"""
from prometheus_client import (
    Counter, Gauge, Histogram, Summary,
    CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST,
    push_to_gateway, start_http_server
)
from functools import wraps
import time
from typing import Callable, Dict, List
from contextlib import contextmanager

# ==================== Custom Metrics Registry ====================

class MetricsManager:
    """
    Centralized metrics management for applications.

    Provides a clean interface for creating and managing
    Prometheus metrics with automatic labeling.
    """

    def __init__(self, namespace: str = "app", subsystem: str = "",
                 default_labels: Dict[str, str] = None):
        """
        Initialize metrics manager.

        Args:
            namespace: Metrics namespace (prefix)
            subsystem: Metrics subsystem
            default_labels: Labels applied to all metrics
        """
        self.namespace = namespace
        self.subsystem = subsystem
        self.default_labels = default_labels or {}
        self.registry = CollectorRegistry()
        self._metrics = {}

    def _metric_name(self, name: str) -> str:
        """Generate full metric name."""
        parts = [self.namespace]
        if self.subsystem:
            parts.append(self.subsystem)
        parts.append(name)
        return "_".join(parts)

    # ==================== Metric Creation ====================

    def counter(self, name: str, description: str,
                labels: List[str] = None) -> Counter:
        """
        Create a Counter metric.

        Counters only increase (e.g., request count, errors).
        """
        full_name = self._metric_name(name)
        if full_name not in self._metrics:
            all_labels = list(self.default_labels.keys()) + (labels or [])
            self._metrics[full_name] = Counter(
                full_name,
                description,
                labelnames=all_labels,
                registry=self.registry
            )
        return self._metrics[full_name]

    def gauge(self, name: str, description: str,
              labels: List[str] = None) -> Gauge:
        """
        Create a Gauge metric.

        Gauges can increase or decrease (e.g., temperature, queue size).
        """
        full_name = self._metric_name(name)
        if full_name not in self._metrics:
            all_labels = list(self.default_labels.keys()) + (labels or [])
            self._metrics[full_name] = Gauge(
                full_name,
                description,
                labelnames=all_labels,
                registry=self.registry
            )
        return self._metrics[full_name]

    def histogram(self, name: str, description: str,
                  labels: List[str] = None,
                  buckets: List[float] = None) -> Histogram:
        """
        Create a Histogram metric.

        Histograms track value distributions (e.g., request duration).
        """
        full_name = self._metric_name(name)
        if full_name not in self._metrics:
            all_labels = list(self.default_labels.keys()) + (labels or [])
            kwargs = {
                "labelnames": all_labels,
                "registry": self.registry
            }
            if buckets:
                kwargs["buckets"] = buckets

            self._metrics[full_name] = Histogram(
                full_name,
                description,
                **kwargs
            )
        return self._metrics[full_name]

    def summary(self, name: str, description: str,
                labels: List[str] = None) -> Summary:
        """
        Create a Summary metric.

        Summaries track quantiles of observations.
        """
        full_name = self._metric_name(name)
        if full_name not in self._metrics:
            all_labels = list(self.default_labels.keys()) + (labels or [])
            self._metrics[full_name] = Summary(
                full_name,
                description,
                labelnames=all_labels,
                registry=self.registry
            )
        return self._metrics[full_name]

    # ==================== Decorators ====================

    def count_calls(self, counter_name: str, labels: Dict[str, str] = None):
        """Decorator to count function calls."""
        def decorator(func: Callable):
            counter = self.counter(
                counter_name,
                f"Number of calls to {func.__name__}",
                list((labels or {}).keys())
            )

            @wraps(func)
            def wrapper(*args, **kwargs):
                label_values = {**self.default_labels, **(labels or {})}
                counter.labels(**label_values).inc()
                return func(*args, **kwargs)

            return wrapper
        return decorator

    def time_calls(self, histogram_name: str, labels: Dict[str, str] = None,
                   buckets: List[float] = None):
        """Decorator to measure function execution time."""
        def decorator(func: Callable):
            histogram = self.histogram(
                histogram_name,
                f"Execution time of {func.__name__}",
                list((labels or {}).keys()),
                buckets
            )

            @wraps(func)
            def wrapper(*args, **kwargs):
                label_values = {**self.default_labels, **(labels or {})}
                with histogram.labels(**label_values).time():
                    return func(*args, **kwargs)

            return wrapper
        return decorator

    @contextmanager
    def track_in_progress(self, gauge_name: str, labels: Dict[str, str] = None):
        """Context manager to track in-progress operations."""
        gauge = self.gauge(
            gauge_name,
            "Number of in-progress operations",
            list((labels or {}).keys())
        )
        label_values = {**self.default_labels, **(labels or {})}
        gauge.labels(**label_values).inc()
        try:
            yield
        finally:
            gauge.labels(**label_values).dec()

    # ==================== Export ====================

    def get_metrics(self) -> bytes:
        """Generate metrics in Prometheus format."""
        return generate_latest(self.registry)

    def push_metrics(self, gateway: str, job: str,
                     grouping_key: Dict[str, str] = None):
        """Push metrics to Prometheus Pushgateway."""
        push_to_gateway(
            gateway, job,
            self.registry,
            grouping_key=grouping_key
        )

    def start_http_server(self, port: int = 8000):
        """Start HTTP server for Prometheus scraping."""
        start_http_server(port, registry=self.registry)
        print(f"📊 Metrics server started on port {port}")


# ==================== Application Metrics Example ====================

class ApplicationMetrics:
    """
    Example: Metrics for a web application.

    Demonstrates common metric patterns for APIs.
    """

    def __init__(self, app_name: str, version: str):
        self.manager = MetricsManager(
            namespace=app_name,
            default_labels={"version": version}
        )

        # HTTP metrics
        self.http_requests = self.manager.counter(
            "http_requests_total",
            "Total HTTP requests",
            ["method", "endpoint", "status"]
        )

        self.http_duration = self.manager.histogram(
            "http_request_duration_seconds",
            "HTTP request duration in seconds",
            ["method", "endpoint"],
            buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
        )

        self.http_in_progress = self.manager.gauge(
            "http_requests_in_progress",
            "HTTP requests currently in progress",
            ["method", "endpoint"]
        )

        # Business metrics
        self.orders_total = self.manager.counter(
            "orders_total",
            "Total orders processed",
            ["status", "payment_method"]
        )

        self.order_value = self.manager.histogram(
            "order_value_dollars",
            "Order value in dollars",
            ["currency"],
            buckets=[10, 25, 50, 100, 250, 500, 1000, 2500, 5000]
        )

        # System metrics
        self.db_connections = self.manager.gauge(
            "db_connections",
            "Database connection pool size",
            ["pool"]
        )

        self.cache_hits = self.manager.counter(
            "cache_hits_total",
            "Cache hit count",
            ["cache_name"]
        )

        self.cache_misses = self.manager.counter(
            "cache_misses_total",
            "Cache miss count",
            ["cache_name"]
        )

    def record_request(self, method: str, endpoint: str,
                       status: int, duration: float):
        """Record HTTP request metrics."""
        labels = {"version": self.manager.default_labels["version"]}

        self.http_requests.labels(
            method=method,
            endpoint=endpoint,
            status=str(status),
            **labels
        ).inc()

        self.http_duration.labels(
            method=method,
            endpoint=endpoint,
            **labels
        ).observe(duration)

    def record_order(self, status: str, payment_method: str,
                    value: float, currency: str = "USD"):
        """Record order metrics."""
        labels = {"version": self.manager.default_labels["version"]}

        self.orders_total.labels(
            status=status,
            payment_method=payment_method,
            **labels
        ).inc()

        self.order_value.labels(
            currency=currency,
            **labels
        ).observe(value)

    def cache_operation(self, cache_name: str, hit: bool):
        """Record cache hit/miss."""
        labels = {"version": self.manager.default_labels["version"]}

        if hit:
            self.cache_hits.labels(cache_name=cache_name, **labels).inc()
        else:
            self.cache_misses.labels(cache_name=cache_name, **labels).inc()


# Flask integration example
def create_flask_metrics_middleware(app_metrics: ApplicationMetrics):
    """Create Flask middleware for automatic metrics."""
    from flask import Flask, request, g

    def before_request():
        g.start_time = time.time()
        labels = {"version": app_metrics.manager.default_labels["version"]}
        app_metrics.http_in_progress.labels(
            method=request.method,
            endpoint=request.endpoint or "unknown",
            **labels
        ).inc()

    def after_request(response):
        duration = time.time() - g.start_time
        labels = {"version": app_metrics.manager.default_labels["version"]}

        app_metrics.record_request(
            method=request.method,
            endpoint=request.endpoint or "unknown",
            status=response.status_code,
            duration=duration
        )

        app_metrics.http_in_progress.labels(
            method=request.method,
            endpoint=request.endpoint or "unknown",
            **labels
        ).dec()

        return response

    return before_request, after_request


# Example usage
if __name__ == "__main__":
    # Create application metrics
    metrics = ApplicationMetrics("myapp", "1.0.0")

    # Start metrics server
    metrics.manager.start_http_server(8000)

    # Simulate some activity
    import random

    while True:
        # Simulate HTTP requests
        metrics.record_request(
            method=random.choice(["GET", "POST", "PUT"]),
            endpoint=random.choice(["/api/users", "/api/orders", "/api/products"]),
            status=random.choice([200, 200, 200, 201, 400, 500]),
            duration=random.uniform(0.01, 2.0)
        )

        # Simulate orders
        if random.random() > 0.7:
            metrics.record_order(
                status=random.choice(["completed", "pending", "failed"]),
                payment_method=random.choice(["card", "paypal", "crypto"]),
                value=random.uniform(10, 500)
            )

        # Simulate cache operations
        metrics.cache_operation(
            cache_name="user_cache",
            hit=random.random() > 0.3
        )

        time.sleep(0.5)
```

### 12.2 Grafana Dashboard Automation
**📖 References:** [ORA: Ch.13], [BPB: Ch.11]

```python
#!/usr/bin/env python3
"""
Grafana Dashboard Automation with Python
pip install requests
"""
import requests
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
import json

@dataclass
class GrafanaPanel:
    """Represents a Grafana dashboard panel."""
    title: str
    type: str  # graph, gauge, stat, table, etc.
    targets: List[Dict]
    gridPos: Dict
    options: Dict = None
    fieldConfig: Dict = None

@dataclass
class GrafanaRow:
    """Represents a collapsible row in a dashboard."""
    title: str
    collapsed: bool = False
    panels: List[GrafanaPanel] = None

class GrafanaManager:
    """
    Manage Grafana dashboards and datasources programmatically.

    Enables Infrastructure as Code for monitoring dashboards.
    """

    def __init__(self, url: str, api_key: str):
        """
        Initialize Grafana connection.

        Args:
            url: Grafana server URL
            api_key: Grafana API key
        """
        self.url = url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

    def _request(self, method: str, endpoint: str,
                 data: Dict = None) -> Dict:
        """Make an authenticated request to Grafana API."""
        url = f"{self.url}{endpoint}"

        response = requests.request(
            method=method,
            url=url,
            headers=self.headers,
            json=data
        )

        if response.status_code >= 400:
            raise Exception(f"Grafana API error: {response.status_code} - {response.text}")

        return response.json() if response.text else {}

    # ==================== Dashboard Operations ====================

    def create_dashboard(self, title: str, panels: List[GrafanaPanel],
                        folder_id: int = 0, tags: List[str] = None,
                        refresh: str = "5s", time_from: str = "now-1h",
                        time_to: str = "now") -> Dict:
        """
        Create or update a dashboard.

        Args:
            title: Dashboard title
            panels: List of panels
            folder_id: Folder ID (0 = General)
            tags: Dashboard tags
            refresh: Auto-refresh interval
            time_from: Default time range start
            time_to: Default time range end
        """
        dashboard = {
            "title": title,
            "tags": tags or [],
            "timezone": "browser",
            "refresh": refresh,
            "time": {
                "from": time_from,
                "to": time_to
            },
            "panels": [self._build_panel(p, i) for i, p in enumerate(panels)]
        }

        payload = {
            "dashboard": dashboard,
            "folderId": folder_id,
            "overwrite": True
        }

        result = self._request("POST", "/api/dashboards/db", payload)
        print(f"✅ Dashboard '{title}' created: {result.get('url')}")
        return result

    def _build_panel(self, panel: GrafanaPanel, index: int) -> Dict:
        """Build panel JSON from GrafanaPanel."""
        panel_dict = {
            "id": index + 1,
            "title": panel.title,
            "type": panel.type,
            "gridPos": panel.gridPos,
            "targets": panel.targets,
            "datasource": {"type": "prometheus", "uid": "prometheus"}
        }

        if panel.options:
            panel_dict["options"] = panel.options

        if panel.fieldConfig:
            panel_dict["fieldConfig"] = panel.fieldConfig

        return panel_dict

    def get_dashboard(self, uid: str) -> Dict:
        """Get dashboard by UID."""
        return self._request("GET", f"/api/dashboards/uid/{uid}")

    def delete_dashboard(self, uid: str) -> bool:
        """Delete a dashboard."""
        self._request("DELETE", f"/api/dashboards/uid/{uid}")
        print(f"🗑️ Dashboard {uid} deleted")
        return True

    def list_dashboards(self, folder_id: int = None,
                       tags: List[str] = None) -> List[Dict]:
        """List dashboards with optional filtering."""
        params = []
        if folder_id is not None:
            params.append(f"folderIds={folder_id}")
        if tags:
            for tag in tags:
                params.append(f"tag={tag}")

        query = "&".join(params) if params else ""
        return self._request("GET", f"/api/search?type=dash-db&{query}")

    # ==================== Folder Operations ====================

    def create_folder(self, title: str) -> Dict:
        """Create a dashboard folder."""
        result = self._request("POST", "/api/folders", {"title": title})
        print(f"📁 Folder '{title}' created")
        return result

    def list_folders(self) -> List[Dict]:
        """List all folders."""
        return self._request("GET", "/api/folders")

    # ==================== Alert Operations ====================

    def create_alert_rule(self, name: str, folder_uid: str,
                         query: str, condition: str,
                         labels: Dict[str, str] = None,
                         annotations: Dict[str, str] = None) -> Dict:
        """Create an alert rule."""
        rule = {
            "name": name,
            "folderUID": folder_uid,
            "condition": condition,
            "data": [
                {
                    "refId": "A",
                    "queryType": "",
                    "relativeTimeRange": {
                        "from": 600,
                        "to": 0
                    },
                    "datasourceUid": "prometheus",
                    "model": {
                        "expr": query,
                        "refId": "A"
                    }
                }
            ],
            "labels": labels or {},
            "annotations": annotations or {}
        }

        result = self._request("POST", "/api/v1/provisioning/alert-rules", rule)
        print(f"🔔 Alert rule '{name}' created")
        return result


# ==================== Dashboard Builder ====================

class DashboardBuilder:
    """
    Fluent builder for creating Grafana dashboards.

    Example:
        dashboard = (DashboardBuilder("My Dashboard")
            .add_row("HTTP Metrics")
            .add_stat_panel("Requests/sec", "rate(http_requests_total[5m])")
            .add_graph_panel("Latency", "histogram_quantile(0.99, ...)")
            .build())
    """

    def __init__(self, title: str, tags: List[str] = None):
        self.title = title
        self.tags = tags or []
        self.panels: List[GrafanaPanel] = []
        self._current_y = 0
        self._current_x = 0

    def add_row(self, title: str, collapsed: bool = False) -> "DashboardBuilder":
        """Add a row to organize panels."""
        self.panels.append(GrafanaPanel(
            title=title,
            type="row",
            targets=[],
            gridPos={"h": 1, "w": 24, "x": 0, "y": self._current_y}
        ))
        self._current_y += 1
        self._current_x = 0
        return self

    def add_stat_panel(self, title: str, query: str,
                       unit: str = "short", width: int = 6,
                       height: int = 4, thresholds: List[Dict] = None) -> "DashboardBuilder":
        """Add a stat panel (single value display)."""
        self.panels.append(GrafanaPanel(
            title=title,
            type="stat",
            targets=[{"expr": query, "refId": "A"}],
            gridPos={"h": height, "w": width, "x": self._current_x, "y": self._current_y},
            options={
                "colorMode": "value",
                "graphMode": "area",
                "justifyMode": "auto"
            },
            fieldConfig={
                "defaults": {
                    "unit": unit,
                    "thresholds": {
                        "mode": "absolute",
                        "steps": thresholds or [
                            {"color": "green", "value": None},
                            {"color": "yellow", "value": 80},
                            {"color": "red", "value": 90}
                        ]
                    }
                }
            }
        ))
        self._advance_position(width, height)
        return self

    def add_gauge_panel(self, title: str, query: str,
                        min_val: float = 0, max_val: float = 100,
                        unit: str = "percent", width: int = 6,
                        height: int = 6) -> "DashboardBuilder":
        """Add a gauge panel."""
        self.panels.append(GrafanaPanel(
            title=title,
            type="gauge",
            targets=[{"expr": query, "refId": "A"}],
            gridPos={"h": height, "w": width, "x": self._current_x, "y": self._current_y},
            options={
                "showThresholdLabels": False,
                "showThresholdMarkers": True
            },
            fieldConfig={
                "defaults": {
                    "unit": unit,
                    "min": min_val,
                    "max": max_val,
                    "thresholds": {
                        "mode": "percentage",
                        "steps": [
                            {"color": "green", "value": None},
                            {"color": "yellow", "value": 70},
                            {"color": "red", "value": 90}
                        ]
                    }
                }
            }
        ))
        self._advance_position(width, height)
        return self

    def add_graph_panel(self, title: str, queries: List[str],
                        legends: List[str] = None, unit: str = "short",
                        width: int = 12, height: int = 8) -> "DashboardBuilder":
        """Add a time series graph panel."""
        targets = [
            {"expr": q, "refId": chr(65 + i), "legendFormat": legends[i] if legends else ""}
            for i, q in enumerate(queries)
        ] if isinstance(queries, list) else [{"expr": queries, "refId": "A"}]

        self.panels.append(GrafanaPanel(
            title=title,
            type="timeseries",
            targets=targets,
            gridPos={"h": height, "w": width, "x": self._current_x, "y": self._current_y},
            options={
                "tooltip": {"mode": "multi"},
                "legend": {"displayMode": "list", "placement": "bottom"}
            },
            fieldConfig={
                "defaults": {
                    "unit": unit,
                    "custom": {
                        "lineWidth": 1,
                        "fillOpacity": 10,
                        "pointSize": 5,
                        "showPoints": "auto"
                    }
                }
            }
        ))
        self._advance_position(width, height)
        return self

    def add_table_panel(self, title: str, query: str,
                        width: int = 24, height: int = 8) -> "DashboardBuilder":
        """Add a table panel."""
        self.panels.append(GrafanaPanel(
            title=title,
            type="table",
            targets=[{"expr": query, "refId": "A", "format": "table", "instant": True}],
            gridPos={"h": height, "w": width, "x": self._current_x, "y": self._current_y},
            options={
                "showHeader": True,
                "sortBy": []
            }
        ))
        self._advance_position(width, height)
        return self

    def _advance_position(self, width: int, height: int):
        """Advance panel position."""
        self._current_x += width
        if self._current_x >= 24:
            self._current_x = 0
            self._current_y += height

    def build(self) -> List[GrafanaPanel]:
        """Build and return the panels list."""
        return self.panels


# Example usage
if __name__ == "__main__":
    import os

    grafana = GrafanaManager(
        url="http://localhost:3000",
        api_key=os.environ.get("GRAFANA_API_KEY")
    )

    # Build a comprehensive application dashboard
    panels = (DashboardBuilder("Application Metrics", tags=["python", "api"])
        .add_row("HTTP Overview")
        .add_stat_panel(
            "Requests/sec",
            'sum(rate(myapp_http_requests_total[5m]))',
            unit="reqps"
        )
        .add_stat_panel(
            "Error Rate",
            'sum(rate(myapp_http_requests_total{status=~"5.."}[5m])) / sum(rate(myapp_http_requests_total[5m])) * 100',
            unit="percent"
        )
        .add_stat_panel(
            "P99 Latency",
            'histogram_quantile(0.99, sum(rate(myapp_http_request_duration_seconds_bucket[5m])) by (le))',
            unit="s"
        )
        .add_stat_panel(
            "Active Connections",
            'sum(myapp_http_requests_in_progress)',
            unit="short"
        )
        .add_row("Request Latency")
        .add_graph_panel(
            "Latency Percentiles",
            [
                'histogram_quantile(0.50, sum(rate(myapp_http_request_duration_seconds_bucket[5m])) by (le))',
                'histogram_quantile(0.90, sum(rate(myapp_http_request_duration_seconds_bucket[5m])) by (le))',
                'histogram_quantile(0.99, sum(rate(myapp_http_request_duration_seconds_bucket[5m])) by (le))'
            ],
            legends=["p50", "p90", "p99"],
            unit="s"
        )
        .add_graph_panel(
            "Requests by Endpoint",
            'sum(rate(myapp_http_requests_total[5m])) by (endpoint)',
            unit="reqps"
        )
        .add_row("Business Metrics")
        .add_graph_panel(
            "Orders by Status",
            'sum(rate(myapp_orders_total[5m])) by (status)',
            unit="short"
        )
        .add_graph_panel(
            "Order Value Distribution",
            'histogram_quantile(0.50, sum(rate(myapp_order_value_dollars_bucket[5m])) by (le))',
            unit="currencyUSD"
        )
        .build())

    # Create the dashboard
    grafana.create_dashboard(
        title="Application Performance",
        panels=panels,
        tags=["python", "api", "production"],
        refresh="10s"
    )
```

---

### ✅ Checkpoint: Phase 12 Self-Assessment

- [ ] Implement custom Prometheus metrics in Python applications
- [ ] Create metric decorators for automatic instrumentation
- [ ] Build Grafana dashboards programmatically
- [ ] Set up alerting rules with Grafana
- [ ] Implement distributed tracing with OpenTelemetry
- [ ] Build log aggregation and analysis tools

---

# Part IV: Advanced Topics & Specializations

---

## Phase 13: Serverless Architecture with Python ☁️
**Estimated Time: 2-3 weeks**

> "Serverless isn't about no servers—it's about no server management. Python makes serverless feel natural."

### Phase Overview

| Topic | Time | Priority | Difficulty |
|-------|------|----------|------------|
| AWS Lambda Functions | 4 days | High | Medium |
| Azure Functions | 3 days | Medium | Medium |
| Google Cloud Functions | 3 days | Medium | Medium |
| Serverless Framework | 3 days | High | Medium |
| Event-Driven Architecture | 2 days | High | Hard |

### Learning Objectives

By the end of this phase, you will:
- [ ] Build and deploy AWS Lambda functions with Python
- [ ] Implement Azure Functions with Python
- [ ] Create Google Cloud Functions
- [ ] Use Serverless Framework for multi-cloud deployments
- [ ] Design event-driven serverless architectures
- [ ] Optimize cold starts and performance

---

### 13.1 AWS Lambda Functions

```python
"""
AWS Lambda Functions: Event-Driven Serverless Computing

Lambda is AWS's serverless compute service that runs code in response
to events and automatically manages the underlying compute resources.
"""

import json
import os
import logging
import boto3
from typing import Any, Callable
from functools import wraps
from dataclasses import dataclass, asdict
from datetime import datetime

# Configure logging for Lambda
logger = logging.getLogger()
logger.setLevel(logging.INFO)


# ============================================================
# Lambda Response Helpers
# ============================================================

@dataclass
class LambdaResponse:
    """Standardized Lambda API Gateway response."""
    statusCode: int
    body: str
    headers: dict = None

    def __post_init__(self):
        if self.headers is None:
            self.headers = {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            }

    def to_dict(self) -> dict:
        return {
            "statusCode": self.statusCode,
            "headers": self.headers,
            "body": self.body
        }


def api_response(status_code: int, body: Any) -> dict:
    """Create an API Gateway compatible response."""
    return LambdaResponse(
        statusCode=status_code,
        body=json.dumps(body, default=str)
    ).to_dict()


def success_response(data: Any, message: str = "Success") -> dict:
    """Return a success response."""
    return api_response(200, {"status": "success", "message": message, "data": data})


def error_response(status_code: int, message: str, error_code: str = None) -> dict:
    """Return an error response."""
    body = {"status": "error", "message": message}
    if error_code:
        body["error_code"] = error_code
    return api_response(status_code, body)


# ============================================================
# Lambda Decorators
# ============================================================

def lambda_handler_decorator(func: Callable) -> Callable:
    """
    Decorator that wraps Lambda handlers with common functionality:
    - Logging
    - Error handling
    - Performance tracking
    """
    @wraps(func)
    def wrapper(event: dict, context: Any) -> dict:
        request_id = context.aws_request_id if context else "local"
        start_time = datetime.now()

        logger.info(f"[{request_id}] Lambda invoked: {func.__name__}")
        logger.info(f"[{request_id}] Event: {json.dumps(event, default=str)[:500]}")

        try:
            result = func(event, context)

            duration = (datetime.now() - start_time).total_seconds() * 1000
            logger.info(f"[{request_id}] Completed in {duration:.2f}ms")

            return result

        except ValueError as e:
            logger.error(f"[{request_id}] Validation error: {str(e)}")
            return error_response(400, str(e), "VALIDATION_ERROR")

        except PermissionError as e:
            logger.error(f"[{request_id}] Permission error: {str(e)}")
            return error_response(403, str(e), "PERMISSION_DENIED")

        except FileNotFoundError as e:
            logger.error(f"[{request_id}] Not found: {str(e)}")
            return error_response(404, str(e), "NOT_FOUND")

        except Exception as e:
            logger.exception(f"[{request_id}] Unexpected error: {str(e)}")
            return error_response(500, "Internal server error", "INTERNAL_ERROR")

    return wrapper


def require_auth(func: Callable) -> Callable:
    """Decorator that requires authentication."""
    @wraps(func)
    def wrapper(event: dict, context: Any) -> dict:
        # Check for authorization header
        headers = event.get("headers", {}) or {}
        auth_header = headers.get("Authorization") or headers.get("authorization")

        if not auth_header:
            return error_response(401, "Missing authorization header", "UNAUTHORIZED")

        # Validate token (simplified - use proper JWT validation in production)
        if not auth_header.startswith("Bearer "):
            return error_response(401, "Invalid authorization format", "UNAUTHORIZED")

        token = auth_header[7:]

        # Add user context to event
        event["user_context"] = {"token": token}

        return func(event, context)

    return wrapper


def validate_body(*required_fields: str) -> Callable:
    """Decorator that validates required fields in request body."""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(event: dict, context: Any) -> dict:
            body = event.get("body")

            if not body:
                return error_response(400, "Request body is required", "MISSING_BODY")

            # Parse body if string
            if isinstance(body, str):
                try:
                    body = json.loads(body)
                except json.JSONDecodeError:
                    return error_response(400, "Invalid JSON body", "INVALID_JSON")

            # Check required fields
            missing_fields = [f for f in required_fields if f not in body]
            if missing_fields:
                return error_response(
                    400,
                    f"Missing required fields: {', '.join(missing_fields)}",
                    "MISSING_FIELDS"
                )

            event["parsed_body"] = body
            return func(event, context)

        return wrapper
    return decorator


# ============================================================
# Lambda Handler Examples
# ============================================================

@lambda_handler_decorator
def api_handler(event: dict, context: Any) -> dict:
    """
    Main API Gateway handler with routing.

    This handler routes requests to appropriate functions based on
    HTTP method and path.
    """
    http_method = event.get("httpMethod", "GET")
    path = event.get("path", "/")

    # Route to appropriate handler
    routes = {
        ("GET", "/health"): health_check,
        ("GET", "/users"): list_users,
        ("POST", "/users"): create_user,
        ("GET", "/users/{id}"): get_user,
        ("PUT", "/users/{id}"): update_user,
        ("DELETE", "/users/{id}"): delete_user,
    }

    # Match path patterns
    for (method, route), handler in routes.items():
        if method == http_method and _match_path(route, path):
            return handler(event, context)

    return error_response(404, f"Route not found: {http_method} {path}")


def _match_path(pattern: str, path: str) -> bool:
    """Match URL path against pattern with parameters."""
    pattern_parts = pattern.split("/")
    path_parts = path.split("/")

    if len(pattern_parts) != len(path_parts):
        return False

    for p, actual in zip(pattern_parts, path_parts):
        if p.startswith("{") and p.endswith("}"):
            continue  # Parameter placeholder
        if p != actual:
            return False

    return True


def health_check(event: dict, context: Any) -> dict:
    """Health check endpoint."""
    return success_response({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": os.environ.get("VERSION", "1.0.0")
    })


@validate_body("name", "email")
def create_user(event: dict, context: Any) -> dict:
    """Create a new user."""
    body = event["parsed_body"]

    # Simulate user creation
    user = {
        "id": "usr_" + context.aws_request_id[:8] if context else "usr_local",
        "name": body["name"],
        "email": body["email"],
        "created_at": datetime.utcnow().isoformat()
    }

    logger.info(f"Created user: {user['id']}")

    return api_response(201, {"status": "success", "data": user})


def list_users(event: dict, context: Any) -> dict:
    """List users with pagination."""
    query_params = event.get("queryStringParameters") or {}

    limit = int(query_params.get("limit", 10))
    offset = int(query_params.get("offset", 0))

    # Simulate fetching users from database
    users = [
        {"id": f"usr_{i}", "name": f"User {i}", "email": f"user{i}@example.com"}
        for i in range(offset, offset + limit)
    ]

    return success_response({
        "users": users,
        "pagination": {"limit": limit, "offset": offset, "total": 100}
    })


def get_user(event: dict, context: Any) -> dict:
    """Get a single user by ID."""
    path_params = event.get("pathParameters") or {}
    user_id = path_params.get("id")

    if not user_id:
        return error_response(400, "User ID is required")

    # Simulate fetching user
    user = {"id": user_id, "name": "John Doe", "email": "john@example.com"}

    return success_response(user)


def update_user(event: dict, context: Any) -> dict:
    """Update a user."""
    path_params = event.get("pathParameters") or {}
    user_id = path_params.get("id")

    body = event.get("body")
    if isinstance(body, str):
        body = json.loads(body)

    # Simulate update
    user = {"id": user_id, **body, "updated_at": datetime.utcnow().isoformat()}

    return success_response(user, "User updated successfully")


def delete_user(event: dict, context: Any) -> dict:
    """Delete a user."""
    path_params = event.get("pathParameters") or {}
    user_id = path_params.get("id")

    logger.info(f"Deleted user: {user_id}")

    return api_response(204, None)


# ============================================================
# Event Processing Handlers
# ============================================================

@lambda_handler_decorator
def s3_event_handler(event: dict, context: Any) -> dict:
    """
    Process S3 events (file uploads, deletions).

    This handler is triggered when files are uploaded to or deleted from S3.
    """
    s3_client = boto3.client("s3")

    for record in event.get("Records", []):
        event_name = record.get("eventName", "")
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        logger.info(f"Processing S3 event: {event_name} for {bucket}/{key}")

        if "ObjectCreated" in event_name:
            # Process new file
            response = s3_client.head_object(Bucket=bucket, Key=key)
            content_type = response.get("ContentType")
            size = response.get("ContentLength")

            logger.info(f"New file: {key} ({content_type}, {size} bytes)")

            # Add your processing logic here
            # Examples: resize images, extract metadata, trigger workflows

        elif "ObjectRemoved" in event_name:
            logger.info(f"File deleted: {key}")
            # Handle deletion (cleanup related resources)

    return {"statusCode": 200, "processed": len(event.get("Records", []))}


@lambda_handler_decorator
def sqs_event_handler(event: dict, context: Any) -> dict:
    """
    Process SQS messages.

    This handler processes messages from an SQS queue.
    """
    processed = []
    failed = []

    for record in event.get("Records", []):
        message_id = record.get("messageId")
        body = record.get("body")

        try:
            # Parse message body
            message = json.loads(body) if isinstance(body, str) else body

            logger.info(f"Processing message {message_id}: {message}")

            # Process the message
            process_message(message)

            processed.append(message_id)

        except Exception as e:
            logger.error(f"Failed to process message {message_id}: {str(e)}")
            failed.append({"messageId": message_id, "error": str(e)})

    # Return batch item failures for partial batch response
    if failed:
        return {
            "batchItemFailures": [
                {"itemIdentifier": f["messageId"]} for f in failed
            ]
        }

    return {"statusCode": 200, "processed": len(processed)}


def process_message(message: dict):
    """Process a single message from the queue."""
    message_type = message.get("type")

    handlers = {
        "user_created": handle_user_created,
        "order_placed": handle_order_placed,
        "payment_processed": handle_payment_processed,
    }

    handler = handlers.get(message_type)
    if handler:
        handler(message.get("data", {}))
    else:
        logger.warning(f"Unknown message type: {message_type}")


def handle_user_created(data: dict):
    """Handle user creation event."""
    logger.info(f"Processing user created: {data}")
    # Send welcome email, create default resources, etc.


def handle_order_placed(data: dict):
    """Handle order placement event."""
    logger.info(f"Processing order: {data}")
    # Update inventory, notify warehouse, etc.


def handle_payment_processed(data: dict):
    """Handle payment processing event."""
    logger.info(f"Processing payment: {data}")
    # Update order status, send receipt, etc.


@lambda_handler_decorator
def dynamodb_stream_handler(event: dict, context: Any) -> dict:
    """
    Process DynamoDB Streams events.

    This handler reacts to changes in a DynamoDB table.
    """
    for record in event.get("Records", []):
        event_name = record.get("eventName")

        # Parse the DynamoDB record
        if event_name == "INSERT":
            new_image = record["dynamodb"].get("NewImage")
            item = _parse_dynamodb_item(new_image)
            logger.info(f"New item inserted: {item}")

        elif event_name == "MODIFY":
            old_image = record["dynamodb"].get("OldImage")
            new_image = record["dynamodb"].get("NewImage")
            old_item = _parse_dynamodb_item(old_image)
            new_item = _parse_dynamodb_item(new_image)
            logger.info(f"Item modified: {old_item} -> {new_item}")

        elif event_name == "REMOVE":
            old_image = record["dynamodb"].get("OldImage")
            item = _parse_dynamodb_item(old_image)
            logger.info(f"Item removed: {item}")

    return {"statusCode": 200}


def _parse_dynamodb_item(item: dict) -> dict:
    """Parse DynamoDB item format to regular dict."""
    if not item:
        return {}

    result = {}
    for key, value in item.items():
        type_key = list(value.keys())[0]
        result[key] = value[type_key]

    return result


# ============================================================
# Scheduled Lambda (CloudWatch Events)
# ============================================================

@lambda_handler_decorator
def scheduled_task_handler(event: dict, context: Any) -> dict:
    """
    Handle scheduled CloudWatch Events.

    This handler runs on a schedule (cron or rate expression).
    """
    logger.info("Running scheduled task")

    # Determine which task to run based on the event
    task_type = event.get("task_type", "default")

    tasks = {
        "cleanup": run_cleanup_task,
        "report": run_report_task,
        "sync": run_sync_task,
        "default": run_default_task,
    }

    task_func = tasks.get(task_type, run_default_task)
    result = task_func()

    return {"statusCode": 200, "task": task_type, "result": result}


def run_cleanup_task() -> dict:
    """Clean up old resources."""
    logger.info("Running cleanup task")
    # Delete old logs, expired sessions, temporary files, etc.
    return {"cleaned_items": 42}


def run_report_task() -> dict:
    """Generate and send reports."""
    logger.info("Running report task")
    # Generate daily/weekly reports
    return {"report_sent": True}


def run_sync_task() -> dict:
    """Synchronize data across services."""
    logger.info("Running sync task")
    # Sync data between databases or services
    return {"synced_records": 150}


def run_default_task() -> dict:
    """Default scheduled task."""
    logger.info("Running default scheduled task")
    return {"status": "completed"}


# ============================================================
# Lambda Layer Manager
# ============================================================

class LambdaLayerManager:
    """
    Manage Lambda layers for shared code and dependencies.

    Lambda Layers allow sharing code, libraries, and custom runtimes
    across multiple functions.
    """

    def __init__(self):
        self.lambda_client = boto3.client("lambda")

    def create_layer(self, name: str, description: str,
                     zip_file: bytes, runtimes: list = None) -> dict:
        """Create a new Lambda layer."""
        if runtimes is None:
            runtimes = ["python3.9", "python3.10", "python3.11"]

        response = self.lambda_client.publish_layer_version(
            LayerName=name,
            Description=description,
            Content={"ZipFile": zip_file},
            CompatibleRuntimes=runtimes,
            CompatibleArchitectures=["x86_64", "arm64"]
        )

        logger.info(f"Created layer: {name} v{response['Version']}")
        return response

    def list_layer_versions(self, name: str) -> list:
        """List all versions of a layer."""
        response = self.lambda_client.list_layer_versions(LayerName=name)
        return response.get("LayerVersions", [])

    def delete_old_versions(self, name: str, keep_versions: int = 3) -> list:
        """Delete old layer versions, keeping the most recent ones."""
        versions = self.list_layer_versions(name)
        deleted = []

        if len(versions) > keep_versions:
            for version in versions[keep_versions:]:
                version_number = version["Version"]
                self.lambda_client.delete_layer_version(
                    LayerName=name,
                    VersionNumber=version_number
                )
                deleted.append(version_number)
                logger.info(f"Deleted layer version: {name}:{version_number}")

        return deleted
```

#### 🔬 Micro-Lab 13.1: Build a Serverless API

**Objective**: Create a complete serverless REST API with AWS Lambda.

```bash
# Step 1: Create project structure
mkdir -p serverless-api/{src,tests,layers}
cd serverless-api

# Step 2: Create requirements.txt
cat > requirements.txt << 'EOF'
boto3>=1.28.0
requests>=2.31.0
pydantic>=2.0.0
EOF

# Step 3: Create the Lambda function
cat > src/handler.py << 'EOF'
# Copy the api_handler code from above
EOF

# Step 4: Package and deploy (simplified)
zip -r function.zip src/
aws lambda create-function \
    --function-name serverless-api \
    --runtime python3.11 \
    --handler src.handler.api_handler \
    --zip-file fileb://function.zip \
    --role arn:aws:iam::ACCOUNT:role/lambda-execution-role

# Step 5: Create API Gateway
aws apigatewayv2 create-api \
    --name serverless-api \
    --protocol-type HTTP \
    --target arn:aws:lambda:REGION:ACCOUNT:function:serverless-api
```

---

### 13.2 Serverless Framework

```python
"""
Serverless Framework: Multi-Cloud Serverless Deployment

The Serverless Framework simplifies deploying serverless applications
across multiple cloud providers with a unified configuration.
"""

import yaml
import subprocess
import json
import os
from pathlib import Path
from typing import Optional
from dataclasses import dataclass, field


@dataclass
class ServerlessFunction:
    """Represents a serverless function configuration."""
    name: str
    handler: str
    events: list = field(default_factory=list)
    environment: dict = field(default_factory=dict)
    timeout: int = 30
    memory_size: int = 128
    layers: list = field(default_factory=list)
    vpc: dict = None

    def to_dict(self) -> dict:
        config = {
            "handler": self.handler,
            "timeout": self.timeout,
            "memorySize": self.memory_size,
        }

        if self.events:
            config["events"] = self.events
        if self.environment:
            config["environment"] = self.environment
        if self.layers:
            config["layers"] = self.layers
        if self.vpc:
            config["vpc"] = self.vpc

        return config


@dataclass
class ServerlessConfig:
    """Serverless Framework configuration generator."""
    service: str
    provider: str = "aws"
    runtime: str = "python3.11"
    region: str = "us-east-1"
    stage: str = "dev"
    functions: dict = field(default_factory=dict)
    plugins: list = field(default_factory=list)
    custom: dict = field(default_factory=dict)
    resources: dict = field(default_factory=dict)

    def add_function(self, func: ServerlessFunction) -> "ServerlessConfig":
        """Add a function to the configuration."""
        self.functions[func.name] = func.to_dict()
        return self

    def add_http_function(self, name: str, handler: str,
                          path: str, method: str = "get",
                          authorizer: str = None,
                          cors: bool = True) -> "ServerlessConfig":
        """Add an HTTP-triggered function."""
        event = {
            "http": {
                "path": path,
                "method": method,
                "cors": cors
            }
        }

        if authorizer:
            event["http"]["authorizer"] = authorizer

        func = ServerlessFunction(
            name=name,
            handler=handler,
            events=[event]
        )
        return self.add_function(func)

    def add_schedule_function(self, name: str, handler: str,
                              schedule: str, input: dict = None) -> "ServerlessConfig":
        """Add a scheduled function."""
        event = {"schedule": schedule}
        if input:
            event = {"schedule": {"rate": schedule, "input": input}}

        func = ServerlessFunction(name=name, handler=handler, events=[event])
        return self.add_function(func)

    def add_sqs_function(self, name: str, handler: str,
                         queue_arn: str, batch_size: int = 10) -> "ServerlessConfig":
        """Add an SQS-triggered function."""
        event = {
            "sqs": {
                "arn": queue_arn,
                "batchSize": batch_size
            }
        }

        func = ServerlessFunction(name=name, handler=handler, events=[event])
        return self.add_function(func)

    def add_s3_function(self, name: str, handler: str,
                        bucket: str, event: str = "s3:ObjectCreated:*",
                        rules: list = None) -> "ServerlessConfig":
        """Add an S3-triggered function."""
        s3_event = {
            "s3": {
                "bucket": bucket,
                "event": event
            }
        }

        if rules:
            s3_event["s3"]["rules"] = rules

        func = ServerlessFunction(name=name, handler=handler, events=[s3_event])
        return self.add_function(func)

    def add_plugin(self, plugin: str) -> "ServerlessConfig":
        """Add a plugin."""
        if plugin not in self.plugins:
            self.plugins.append(plugin)
        return self

    def add_dynamodb_table(self, name: str, partition_key: str,
                           sort_key: str = None,
                           billing_mode: str = "PAY_PER_REQUEST") -> "ServerlessConfig":
        """Add a DynamoDB table resource."""
        if "Resources" not in self.resources:
            self.resources["Resources"] = {}

        key_schema = [{"AttributeName": partition_key, "KeyType": "HASH"}]
        attribute_defs = [{"AttributeName": partition_key, "AttributeType": "S"}]

        if sort_key:
            key_schema.append({"AttributeName": sort_key, "KeyType": "RANGE"})
            attribute_defs.append({"AttributeName": sort_key, "AttributeType": "S"})

        self.resources["Resources"][f"{name}Table"] = {
            "Type": "AWS::DynamoDB::Table",
            "Properties": {
                "TableName": "${self:service}-${self:provider.stage}-" + name,
                "BillingMode": billing_mode,
                "KeySchema": key_schema,
                "AttributeDefinitions": attribute_defs
            }
        }

        return self

    def to_dict(self) -> dict:
        """Convert to serverless.yml format."""
        config = {
            "service": self.service,
            "provider": {
                "name": self.provider,
                "runtime": self.runtime,
                "region": self.region,
                "stage": "${opt:stage, '" + self.stage + "'}",
                "environment": {
                    "STAGE": "${self:provider.stage}"
                }
            },
            "functions": self.functions
        }

        if self.plugins:
            config["plugins"] = self.plugins
        if self.custom:
            config["custom"] = self.custom
        if self.resources:
            config["resources"] = self.resources

        return config

    def generate(self, output_path: str = "serverless.yml"):
        """Generate serverless.yml file."""
        config = self.to_dict()

        with open(output_path, "w") as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)

        print(f"Generated {output_path}")
        return output_path


class ServerlessDeployer:
    """Deploy and manage Serverless Framework applications."""

    def __init__(self, working_dir: str = "."):
        self.working_dir = Path(working_dir)

    def _run_command(self, command: list, capture: bool = True) -> subprocess.CompletedProcess:
        """Run a serverless command."""
        return subprocess.run(
            ["serverless"] + command,
            cwd=self.working_dir,
            capture_output=capture,
            text=True
        )

    def deploy(self, stage: str = "dev", verbose: bool = False) -> dict:
        """Deploy the serverless application."""
        cmd = ["deploy", "--stage", stage]
        if verbose:
            cmd.append("--verbose")

        result = self._run_command(cmd)

        if result.returncode != 0:
            raise RuntimeError(f"Deployment failed: {result.stderr}")

        return self._parse_deploy_output(result.stdout)

    def deploy_function(self, function_name: str, stage: str = "dev") -> dict:
        """Deploy a single function (faster than full deploy)."""
        cmd = ["deploy", "function", "-f", function_name, "--stage", stage]

        result = self._run_command(cmd)

        if result.returncode != 0:
            raise RuntimeError(f"Function deployment failed: {result.stderr}")

        return {"function": function_name, "status": "deployed"}

    def remove(self, stage: str = "dev") -> bool:
        """Remove the serverless application."""
        cmd = ["remove", "--stage", stage]

        result = self._run_command(cmd)
        return result.returncode == 0

    def invoke(self, function_name: str, data: dict = None,
               stage: str = "dev", local: bool = False) -> dict:
        """Invoke a function."""
        cmd = ["invoke"]

        if local:
            cmd.append("local")

        cmd.extend(["-f", function_name, "--stage", stage])

        if data:
            cmd.extend(["-d", json.dumps(data)])

        result = self._run_command(cmd)

        if result.returncode != 0:
            raise RuntimeError(f"Invocation failed: {result.stderr}")

        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return {"output": result.stdout}

    def logs(self, function_name: str, stage: str = "dev",
             tail: bool = False) -> str:
        """Get function logs."""
        cmd = ["logs", "-f", function_name, "--stage", stage]

        if tail:
            cmd.append("--tail")

        result = self._run_command(cmd)
        return result.stdout

    def info(self, stage: str = "dev") -> dict:
        """Get deployment info."""
        cmd = ["info", "--stage", stage, "--verbose"]

        result = self._run_command(cmd)
        return {"info": result.stdout}

    def _parse_deploy_output(self, output: str) -> dict:
        """Parse deployment output for key information."""
        result = {
            "endpoints": [],
            "functions": [],
            "stack": None
        }

        lines = output.split("\n")
        for line in lines:
            if "endpoints:" in line.lower():
                continue
            if line.strip().startswith(("GET", "POST", "PUT", "DELETE", "ANY")):
                result["endpoints"].append(line.strip())
            elif "function:" in line.lower():
                result["functions"].append(line.strip())

        return result


# Example: Generate a complete serverless configuration
def create_api_config() -> ServerlessConfig:
    """Create a complete API configuration."""
    config = ServerlessConfig(
        service="my-serverless-api",
        region="us-east-1"
    )

    # Add plugins
    config.add_plugin("serverless-python-requirements")
    config.add_plugin("serverless-offline")

    # Add HTTP endpoints
    config.add_http_function("health", "src/handlers.health_check", "/health")
    config.add_http_function("createUser", "src/handlers.create_user", "/users", "post")
    config.add_http_function("getUser", "src/handlers.get_user", "/users/{id}")
    config.add_http_function("listUsers", "src/handlers.list_users", "/users")
    config.add_http_function("updateUser", "src/handlers.update_user", "/users/{id}", "put")
    config.add_http_function("deleteUser", "src/handlers.delete_user", "/users/{id}", "delete")

    # Add scheduled function
    config.add_schedule_function(
        "cleanupJob",
        "src/handlers.cleanup_handler",
        "rate(1 day)"
    )

    # Add DynamoDB table
    config.add_dynamodb_table("users", partition_key="id")

    # Custom configuration
    config.custom = {
        "pythonRequirements": {
            "dockerizePip": True,
            "slim": True
        }
    }

    return config


if __name__ == "__main__":
    # Generate serverless.yml
    config = create_api_config()
    config.generate("serverless.yml")

    # Deploy
    deployer = ServerlessDeployer()
    # result = deployer.deploy(stage="dev")
    # print(f"Deployed: {result}")
```

---

### 📝 Phase Lab 13: Event-Driven Order Processing System

**Objective**: Build a complete event-driven order processing system using serverless architecture.

**Requirements**:
1. API endpoints for order management
2. Asynchronous order processing with SQS
3. Inventory updates with DynamoDB Streams
4. Email notifications with SNS
5. File storage in S3

```python
"""
Phase Lab 13: Event-Driven Order Processing System
"""

# serverless.yml configuration
ORDER_SYSTEM_CONFIG = """
service: order-processing-system

provider:
  name: aws
  runtime: python3.11
  region: us-east-1
  stage: ${opt:stage, 'dev'}
  environment:
    ORDERS_TABLE: ${self:service}-orders-${self:provider.stage}
    INVENTORY_TABLE: ${self:service}-inventory-${self:provider.stage}
    ORDER_QUEUE_URL: !Ref OrderQueue
    NOTIFICATION_TOPIC_ARN: !Ref NotificationTopic

  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:*
          Resource:
            - !GetAtt OrdersTable.Arn
            - !GetAtt InventoryTable.Arn
        - Effect: Allow
          Action:
            - sqs:*
          Resource:
            - !GetAtt OrderQueue.Arn
        - Effect: Allow
          Action:
            - sns:Publish
          Resource:
            - !Ref NotificationTopic

functions:
  # API Functions
  createOrder:
    handler: src/api.create_order
    events:
      - http:
          path: /orders
          method: post
          cors: true

  getOrder:
    handler: src/api.get_order
    events:
      - http:
          path: /orders/{orderId}
          method: get
          cors: true

  listOrders:
    handler: src/api.list_orders
    events:
      - http:
          path: /orders
          method: get
          cors: true

  # Order Processing
  processOrder:
    handler: src/processor.process_order
    events:
      - sqs:
          arn: !GetAtt OrderQueue.Arn
          batchSize: 5

  # Inventory Sync
  syncInventory:
    handler: src/inventory.sync_from_stream
    events:
      - stream:
          type: dynamodb
          arn: !GetAtt OrdersTable.StreamArn
          batchSize: 10
          startingPosition: TRIM_HORIZON

  # Notifications
  sendNotification:
    handler: src/notifications.send_notification
    events:
      - sns:
          arn: !Ref NotificationTopic
          topicName: order-notifications

resources:
  Resources:
    OrdersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:provider.environment.ORDERS_TABLE}
        BillingMode: PAY_PER_REQUEST
        KeySchema:
          - AttributeName: orderId
            KeyType: HASH
        AttributeDefinitions:
          - AttributeName: orderId
            AttributeType: S
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES

    InventoryTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:provider.environment.INVENTORY_TABLE}
        BillingMode: PAY_PER_REQUEST
        KeySchema:
          - AttributeName: productId
            KeyType: HASH
        AttributeDefinitions:
          - AttributeName: productId
            AttributeType: S

    OrderQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-order-queue-${self:provider.stage}
        VisibilityTimeout: 300
        MessageRetentionPeriod: 1209600
        RedrivePolicy:
          deadLetterTargetArn: !GetAtt OrderDLQ.Arn
          maxReceiveCount: 3

    OrderDLQ:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-order-dlq-${self:provider.stage}

    NotificationTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: ${self:service}-notifications-${self:provider.stage}

plugins:
  - serverless-python-requirements
"""


# src/api.py - API Handlers
import json
import os
import uuid
from datetime import datetime
import boto3


dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")


def create_order(event, context):
    """Create a new order and queue for processing."""
    body = json.loads(event.get("body", "{}"))

    # Validate required fields
    required = ["customerId", "items"]
    missing = [f for f in required if f not in body]
    if missing:
        return response(400, {"error": f"Missing fields: {missing}"})

    # Create order
    order_id = str(uuid.uuid4())
    order = {
        "orderId": order_id,
        "customerId": body["customerId"],
        "items": body["items"],
        "status": "PENDING",
        "totalAmount": calculate_total(body["items"]),
        "createdAt": datetime.utcnow().isoformat(),
        "updatedAt": datetime.utcnow().isoformat()
    }

    # Save to DynamoDB
    table = dynamodb.Table(os.environ["ORDERS_TABLE"])
    table.put_item(Item=order)

    # Queue for processing
    sqs.send_message(
        QueueUrl=os.environ["ORDER_QUEUE_URL"],
        MessageBody=json.dumps({
            "orderId": order_id,
            "action": "PROCESS"
        })
    )

    return response(201, {"order": order})


def get_order(event, context):
    """Get order by ID."""
    order_id = event["pathParameters"]["orderId"]

    table = dynamodb.Table(os.environ["ORDERS_TABLE"])
    result = table.get_item(Key={"orderId": order_id})

    if "Item" not in result:
        return response(404, {"error": "Order not found"})

    return response(200, {"order": result["Item"]})


def list_orders(event, context):
    """List orders with pagination."""
    query_params = event.get("queryStringParameters") or {}

    table = dynamodb.Table(os.environ["ORDERS_TABLE"])

    scan_kwargs = {"Limit": int(query_params.get("limit", 20))}

    if "lastKey" in query_params:
        scan_kwargs["ExclusiveStartKey"] = {"orderId": query_params["lastKey"]}

    result = table.scan(**scan_kwargs)

    response_body = {
        "orders": result.get("Items", []),
        "count": result.get("Count", 0)
    }

    if "LastEvaluatedKey" in result:
        response_body["lastKey"] = result["LastEvaluatedKey"]["orderId"]

    return response(200, response_body)


def calculate_total(items):
    """Calculate order total."""
    return sum(item.get("price", 0) * item.get("quantity", 1) for item in items)


def response(status_code, body):
    """Generate API response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body, default=str)
    }


# src/processor.py - Order Processor
def process_order(event, context):
    """Process orders from SQS queue."""
    sns = boto3.client("sns")

    for record in event.get("Records", []):
        message = json.loads(record["body"])
        order_id = message["orderId"]

        print(f"Processing order: {order_id}")

        # Get order details
        table = dynamodb.Table(os.environ["ORDERS_TABLE"])
        result = table.get_item(Key={"orderId": order_id})
        order = result.get("Item")

        if not order:
            print(f"Order not found: {order_id}")
            continue

        try:
            # Validate inventory
            if not validate_inventory(order["items"]):
                update_order_status(order_id, "FAILED", "Insufficient inventory")
                continue

            # Reserve inventory
            reserve_inventory(order["items"])

            # Update order status
            update_order_status(order_id, "PROCESSING")

            # Simulate payment processing
            process_payment(order)

            # Update final status
            update_order_status(order_id, "COMPLETED")

            # Send notification
            sns.publish(
                TopicArn=os.environ["NOTIFICATION_TOPIC_ARN"],
                Message=json.dumps({
                    "type": "ORDER_COMPLETED",
                    "orderId": order_id,
                    "customerId": order["customerId"],
                    "totalAmount": order["totalAmount"]
                }),
                Subject="Order Completed"
            )

        except Exception as e:
            print(f"Error processing order {order_id}: {str(e)}")
            update_order_status(order_id, "FAILED", str(e))
            raise

    return {"processed": len(event.get("Records", []))}


def validate_inventory(items):
    """Check if all items are in stock."""
    table = dynamodb.Table(os.environ["INVENTORY_TABLE"])

    for item in items:
        result = table.get_item(Key={"productId": item["productId"]})
        inventory = result.get("Item", {})

        if inventory.get("quantity", 0) < item["quantity"]:
            return False

    return True


def reserve_inventory(items):
    """Reserve inventory for order items."""
    table = dynamodb.Table(os.environ["INVENTORY_TABLE"])

    for item in items:
        table.update_item(
            Key={"productId": item["productId"]},
            UpdateExpression="SET quantity = quantity - :qty",
            ExpressionAttributeValues={":qty": item["quantity"]},
            ConditionExpression="quantity >= :qty"
        )


def update_order_status(order_id, status, error=None):
    """Update order status in DynamoDB."""
    table = dynamodb.Table(os.environ["ORDERS_TABLE"])

    update_expr = "SET #status = :status, updatedAt = :updated"
    expr_values = {
        ":status": status,
        ":updated": datetime.utcnow().isoformat()
    }

    if error:
        update_expr += ", errorMessage = :error"
        expr_values[":error"] = error

    table.update_item(
        Key={"orderId": order_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues=expr_values
    )


def process_payment(order):
    """Simulate payment processing."""
    # In production, integrate with payment gateway
    print(f"Processing payment of ${order['totalAmount']} for order {order['orderId']}")


# src/notifications.py - Notification Handler
def send_notification(event, context):
    """Handle SNS notifications."""
    ses = boto3.client("ses")

    for record in event.get("Records", []):
        message = json.loads(record["Sns"]["Message"])

        notification_type = message.get("type")

        if notification_type == "ORDER_COMPLETED":
            send_order_confirmation(ses, message)
        elif notification_type == "ORDER_FAILED":
            send_order_failure(ses, message)
        else:
            print(f"Unknown notification type: {notification_type}")

    return {"processed": len(event.get("Records", []))}


def send_order_confirmation(ses, data):
    """Send order confirmation email."""
    # In production, look up customer email
    print(f"Sending confirmation for order {data['orderId']}")
    # ses.send_email(...)


def send_order_failure(ses, data):
    """Send order failure notification."""
    print(f"Sending failure notification for order {data['orderId']}")


print("Phase Lab 13: Order Processing System Configuration")
print("=" * 50)
print("This system demonstrates:")
print("1. REST API with Lambda + API Gateway")
print("2. Async processing with SQS")
print("3. DynamoDB for data storage")
print("4. SNS for notifications")
print("5. Event-driven architecture patterns")
```

---

### ✅ Checkpoint: Phase 13 Self-Assessment

- [ ] Build Lambda functions with proper error handling
- [ ] Implement API Gateway integrations
- [ ] Process events from S3, SQS, DynamoDB Streams
- [ ] Use Serverless Framework for deployment
- [ ] Design event-driven architectures
- [ ] Optimize Lambda cold starts and performance

---

## Phase 14: Security Automation (DevSecOps) 🔐
**Estimated Time: 2-3 weeks**

> "Security is not a feature—it's a process. Automate it or fall behind the threats."

### Phase Overview

| Topic | Time | Priority | Difficulty |
|-------|------|----------|------------|
| Secrets Management | 3 days | Critical | Medium |
| Vulnerability Scanning | 3 days | Critical | Medium |
| Security Policies as Code | 3 days | High | Hard |
| Compliance Automation | 3 days | High | Hard |
| Incident Response Automation | 2 days | High | Hard |

### Learning Objectives

By the end of this phase, you will:
- [ ] Implement secure secrets management
- [ ] Automate vulnerability scanning and remediation
- [ ] Write security policies as code
- [ ] Build compliance automation tools
- [ ] Create incident response automation

---

### 14.1 Secrets Management

```python
"""
Secrets Management: Secure Handling of Sensitive Data

Proper secrets management is critical for DevOps security.
Never hardcode secrets—always use secure vaults and rotation.
"""

import os
import json
import base64
import hashlib
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass
from datetime import datetime, timedelta
from functools import lru_cache
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


@dataclass
class Secret:
    """Represents a secret with metadata."""
    name: str
    value: str
    version: str = None
    created_at: datetime = None
    expires_at: datetime = None
    tags: dict = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()

    @property
    def is_expired(self) -> bool:
        """Check if the secret has expired."""
        if self.expires_at is None:
            return False
        return datetime.utcnow() > self.expires_at

    def mask(self) -> str:
        """Return masked version of the secret value."""
        if len(self.value) <= 4:
            return "****"
        return self.value[:2] + "*" * (len(self.value) - 4) + self.value[-2:]


class AWSSecretsManager:
    """
    AWS Secrets Manager client for secure secret storage.

    AWS Secrets Manager provides:
    - Encryption at rest using KMS
    - Automatic rotation
    - Fine-grained access control with IAM
    - Audit logging with CloudTrail
    """

    def __init__(self, region_name: str = None):
        self.client = boto3.client(
            "secretsmanager",
            region_name=region_name or os.environ.get("AWS_REGION", "us-east-1")
        )
        self._cache: Dict[str, Secret] = {}
        self._cache_ttl = timedelta(minutes=5)

    def create_secret(self, name: str, value: str,
                      description: str = None,
                      tags: dict = None,
                      kms_key_id: str = None) -> Secret:
        """Create a new secret."""
        kwargs = {
            "Name": name,
            "SecretString": value
        }

        if description:
            kwargs["Description"] = description
        if kms_key_id:
            kwargs["KmsKeyId"] = kms_key_id
        if tags:
            kwargs["Tags"] = [{"Key": k, "Value": v} for k, v in tags.items()]

        try:
            response = self.client.create_secret(**kwargs)

            secret = Secret(
                name=name,
                value=value,
                version=response["VersionId"],
                tags=tags
            )

            logger.info(f"Created secret: {name}")
            return secret

        except ClientError as e:
            if e.response["Error"]["Code"] == "ResourceExistsException":
                logger.warning(f"Secret {name} already exists, updating...")
                return self.update_secret(name, value)
            raise

    def get_secret(self, name: str, version: str = None,
                   use_cache: bool = True) -> Optional[Secret]:
        """Retrieve a secret by name."""
        cache_key = f"{name}:{version or 'latest'}"

        # Check cache
        if use_cache and cache_key in self._cache:
            cached = self._cache[cache_key]
            if not cached.is_expired:
                return cached

        try:
            kwargs = {"SecretId": name}
            if version:
                kwargs["VersionId"] = version

            response = self.client.get_secret_value(**kwargs)

            # Handle both string and binary secrets
            if "SecretString" in response:
                value = response["SecretString"]
            else:
                value = base64.b64decode(response["SecretBinary"]).decode()

            secret = Secret(
                name=name,
                value=value,
                version=response["VersionId"],
                created_at=response.get("CreatedDate")
            )

            # Cache the secret
            self._cache[cache_key] = secret

            return secret

        except ClientError as e:
            if e.response["Error"]["Code"] == "ResourceNotFoundException":
                logger.warning(f"Secret not found: {name}")
                return None
            raise

    def get_secret_json(self, name: str) -> Optional[dict]:
        """Get secret and parse as JSON."""
        secret = self.get_secret(name)
        if secret:
            try:
                return json.loads(secret.value)
            except json.JSONDecodeError:
                logger.error(f"Secret {name} is not valid JSON")
        return None

    def update_secret(self, name: str, value: str) -> Secret:
        """Update an existing secret."""
        response = self.client.put_secret_value(
            SecretId=name,
            SecretString=value
        )

        # Invalidate cache
        self._invalidate_cache(name)

        logger.info(f"Updated secret: {name}")

        return Secret(
            name=name,
            value=value,
            version=response["VersionId"]
        )

    def delete_secret(self, name: str, force: bool = False,
                      recovery_window_days: int = 30) -> bool:
        """Delete a secret."""
        kwargs = {"SecretId": name}

        if force:
            kwargs["ForceDeleteWithoutRecovery"] = True
        else:
            kwargs["RecoveryWindowInDays"] = recovery_window_days

        try:
            self.client.delete_secret(**kwargs)
            self._invalidate_cache(name)
            logger.info(f"Deleted secret: {name}")
            return True
        except ClientError as e:
            logger.error(f"Failed to delete secret {name}: {e}")
            return False

    def rotate_secret(self, name: str, rotation_lambda_arn: str = None,
                      rotation_days: int = 30) -> dict:
        """Enable or trigger secret rotation."""
        if rotation_lambda_arn:
            # Enable automatic rotation
            response = self.client.rotate_secret(
                SecretId=name,
                RotationLambdaARN=rotation_lambda_arn,
                RotationRules={"AutomaticallyAfterDays": rotation_days}
            )
        else:
            # Trigger immediate rotation
            response = self.client.rotate_secret(SecretId=name)

        self._invalidate_cache(name)
        logger.info(f"Rotated secret: {name}")

        return response

    def list_secrets(self, prefix: str = None, max_results: int = 100) -> list:
        """List all secrets with optional prefix filter."""
        secrets = []
        paginator = self.client.get_paginator("list_secrets")

        filters = []
        if prefix:
            filters.append({"Key": "name", "Values": [prefix]})

        for page in paginator.paginate(
            Filters=filters,
            MaxResults=min(max_results, 100)
        ):
            for secret in page.get("SecretList", []):
                secrets.append({
                    "name": secret["Name"],
                    "description": secret.get("Description"),
                    "last_changed": secret.get("LastChangedDate"),
                    "tags": {t["Key"]: t["Value"] for t in secret.get("Tags", [])}
                })

        return secrets

    def _invalidate_cache(self, name: str):
        """Invalidate cached entries for a secret."""
        keys_to_remove = [k for k in self._cache if k.startswith(f"{name}:")]
        for key in keys_to_remove:
            del self._cache[key]


class HashiCorpVaultClient:
    """
    HashiCorp Vault client for enterprise secrets management.

    Vault provides:
    - Dynamic secrets (database credentials, cloud credentials)
    - Secret leasing and renewal
    - Encryption as a service
    - Multiple auth methods
    """

    def __init__(self, vault_addr: str = None, token: str = None):
        import hvac

        self.vault_addr = vault_addr or os.environ.get("VAULT_ADDR", "http://localhost:8200")
        self.token = token or os.environ.get("VAULT_TOKEN")

        self.client = hvac.Client(url=self.vault_addr, token=self.token)

        if not self.client.is_authenticated():
            raise ValueError("Vault authentication failed")

    def read_secret(self, path: str, mount_point: str = "secret") -> Optional[dict]:
        """Read a secret from Vault."""
        try:
            response = self.client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point=mount_point
            )
            return response["data"]["data"]
        except Exception as e:
            logger.error(f"Failed to read secret {path}: {e}")
            return None

    def write_secret(self, path: str, data: dict,
                     mount_point: str = "secret") -> bool:
        """Write a secret to Vault."""
        try:
            self.client.secrets.kv.v2.create_or_update_secret(
                path=path,
                secret=data,
                mount_point=mount_point
            )
            logger.info(f"Wrote secret to {path}")
            return True
        except Exception as e:
            logger.error(f"Failed to write secret {path}: {e}")
            return False

    def delete_secret(self, path: str, mount_point: str = "secret") -> bool:
        """Delete a secret from Vault."""
        try:
            self.client.secrets.kv.v2.delete_metadata_and_all_versions(
                path=path,
                mount_point=mount_point
            )
            logger.info(f"Deleted secret at {path}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete secret {path}: {e}")
            return False

    def generate_database_credentials(self, role: str) -> dict:
        """Generate dynamic database credentials."""
        response = self.client.secrets.database.generate_credentials(name=role)
        return {
            "username": response["data"]["username"],
            "password": response["data"]["password"],
            "lease_id": response["lease_id"],
            "lease_duration": response["lease_duration"]
        }

    def generate_aws_credentials(self, role: str) -> dict:
        """Generate dynamic AWS credentials."""
        response = self.client.secrets.aws.generate_credentials(name=role)
        return {
            "access_key": response["data"]["access_key"],
            "secret_key": response["data"]["secret_key"],
            "security_token": response["data"].get("security_token"),
            "lease_id": response["lease_id"],
            "lease_duration": response["lease_duration"]
        }

    def encrypt_data(self, plaintext: str, key_name: str) -> str:
        """Encrypt data using Vault's transit secrets engine."""
        encoded = base64.b64encode(plaintext.encode()).decode()
        response = self.client.secrets.transit.encrypt_data(
            name=key_name,
            plaintext=encoded
        )
        return response["data"]["ciphertext"]

    def decrypt_data(self, ciphertext: str, key_name: str) -> str:
        """Decrypt data using Vault's transit secrets engine."""
        response = self.client.secrets.transit.decrypt_data(
            name=key_name,
            ciphertext=ciphertext
        )
        return base64.b64decode(response["data"]["plaintext"]).decode()


class SecretRotator:
    """
    Automated secret rotation for various credential types.

    Supports rotating:
    - Database passwords
    - API keys
    - SSL certificates
    - Cloud credentials
    """

    def __init__(self, secrets_manager: AWSSecretsManager):
        self.secrets_manager = secrets_manager

    def rotate_database_password(self, secret_name: str,
                                  db_client,
                                  username: str) -> bool:
        """Rotate a database password."""
        import secrets as python_secrets

        # Generate new password
        new_password = python_secrets.token_urlsafe(32)

        try:
            # Get current credentials
            current = self.secrets_manager.get_secret_json(secret_name)

            if not current:
                logger.error(f"Secret {secret_name} not found")
                return False

            # Update password in database
            db_client.execute(
                f"ALTER USER {username} IDENTIFIED BY %s",
                (new_password,)
            )

            # Update secret
            current["password"] = new_password
            current["last_rotated"] = datetime.utcnow().isoformat()

            self.secrets_manager.update_secret(
                secret_name,
                json.dumps(current)
            )

            logger.info(f"Rotated database password for {username}")
            return True

        except Exception as e:
            logger.error(f"Failed to rotate database password: {e}")
            return False

    def rotate_api_key(self, secret_name: str,
                       api_client,
                       key_id: str) -> bool:
        """Rotate an API key."""
        try:
            # Generate new key via API
            new_key_response = api_client.create_api_key()
            new_key = new_key_response["api_key"]

            # Update secret
            self.secrets_manager.update_secret(
                secret_name,
                json.dumps({
                    "api_key": new_key,
                    "key_id": new_key_response.get("key_id"),
                    "last_rotated": datetime.utcnow().isoformat()
                })
            )

            # Deactivate old key
            api_client.delete_api_key(key_id)

            logger.info(f"Rotated API key: {secret_name}")
            return True

        except Exception as e:
            logger.error(f"Failed to rotate API key: {e}")
            return False


# Environment-aware secrets loading
class SecretsConfig:
    """
    Environment-aware secrets configuration.

    Loads secrets from:
    1. Environment variables (for local development)
    2. AWS Secrets Manager (for deployed environments)
    3. Local .env file (for local development fallback)
    """

    def __init__(self, environment: str = None):
        self.environment = environment or os.environ.get("ENVIRONMENT", "development")
        self._secrets: Dict[str, str] = {}
        self._secrets_manager = None

        if self.environment in ("staging", "production"):
            self._secrets_manager = AWSSecretsManager()

    @lru_cache(maxsize=100)
    def get(self, key: str, default: str = None) -> Optional[str]:
        """Get a secret value."""
        # Try environment variable first
        value = os.environ.get(key)
        if value:
            return value

        # Try secrets manager for non-development environments
        if self._secrets_manager:
            secret = self._secrets_manager.get_secret(key)
            if secret:
                return secret.value

        # Return default
        return default

    def get_json(self, key: str) -> Optional[dict]:
        """Get a secret and parse as JSON."""
        value = self.get(key)
        if value:
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return None
        return None

    def require(self, key: str) -> str:
        """Get a required secret, raising if not found."""
        value = self.get(key)
        if not value:
            raise ValueError(f"Required secret not found: {key}")
        return value


# Example usage
if __name__ == "__main__":
    # AWS Secrets Manager
    secrets = AWSSecretsManager()

    # Create a secret
    db_creds = {
        "host": "db.example.com",
        "port": 5432,
        "username": "admin",
        "password": "super-secret-password",
        "database": "myapp"
    }

    # secrets.create_secret(
    #     name="myapp/database/credentials",
    #     value=json.dumps(db_creds),
    #     description="Database credentials for MyApp",
    #     tags={"environment": "production", "service": "myapp"}
    # )

    # Retrieve secret
    # secret = secrets.get_secret_json("myapp/database/credentials")
    # print(f"Database host: {secret['host']}")
```

---

### 14.2 Vulnerability Scanning

```python
"""
Vulnerability Scanning: Automated Security Analysis

Automated vulnerability scanning is essential for continuous security.
Scan containers, dependencies, and infrastructure for vulnerabilities.
"""

import subprocess
import json
import os
import tempfile
from typing import List, Optional
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import requests


class Severity(Enum):
    """Vulnerability severity levels."""
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    UNKNOWN = "UNKNOWN"

    @classmethod
    def from_string(cls, value: str) -> "Severity":
        """Convert string to Severity enum."""
        try:
            return cls[value.upper()]
        except KeyError:
            return cls.UNKNOWN


@dataclass
class Vulnerability:
    """Represents a security vulnerability."""
    id: str
    package: str
    version: str
    severity: Severity
    title: str
    description: str = ""
    fixed_version: str = None
    cvss_score: float = None
    references: list = field(default_factory=list)

    @property
    def is_fixable(self) -> bool:
        """Check if there's a fix available."""
        return self.fixed_version is not None


@dataclass
class ScanResult:
    """Results of a vulnerability scan."""
    target: str
    scan_type: str
    timestamp: datetime
    vulnerabilities: List[Vulnerability]
    metadata: dict = field(default_factory=dict)

    @property
    def critical_count(self) -> int:
        return sum(1 for v in self.vulnerabilities if v.severity == Severity.CRITICAL)

    @property
    def high_count(self) -> int:
        return sum(1 for v in self.vulnerabilities if v.severity == Severity.HIGH)

    @property
    def total_count(self) -> int:
        return len(self.vulnerabilities)

    @property
    def fixable_count(self) -> int:
        return sum(1 for v in self.vulnerabilities if v.is_fixable)

    def get_by_severity(self, severity: Severity) -> List[Vulnerability]:
        """Get vulnerabilities by severity level."""
        return [v for v in self.vulnerabilities if v.severity == severity]

    def to_dict(self) -> dict:
        """Convert to dictionary for reporting."""
        return {
            "target": self.target,
            "scan_type": self.scan_type,
            "timestamp": self.timestamp.isoformat(),
            "summary": {
                "total": self.total_count,
                "critical": self.critical_count,
                "high": self.high_count,
                "fixable": self.fixable_count
            },
            "vulnerabilities": [
                {
                    "id": v.id,
                    "package": v.package,
                    "version": v.version,
                    "severity": v.severity.value,
                    "title": v.title,
                    "fixed_version": v.fixed_version
                }
                for v in self.vulnerabilities
            ]
        }


class TrivyScanner:
    """
    Trivy vulnerability scanner wrapper.

    Trivy scans:
    - Container images
    - File systems
    - Git repositories
    - Kubernetes clusters
    - Infrastructure as Code
    """

    def __init__(self, trivy_path: str = "trivy"):
        self.trivy_path = trivy_path

    def scan_image(self, image: str,
                   severity_filter: list = None) -> ScanResult:
        """Scan a container image for vulnerabilities."""
        cmd = [
            self.trivy_path, "image",
            "--format", "json",
            "--quiet"
        ]

        if severity_filter:
            cmd.extend(["--severity", ",".join(severity_filter)])

        cmd.append(image)

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Trivy scan failed: {result.stderr}")

        return self._parse_trivy_output(result.stdout, image, "image")

    def scan_filesystem(self, path: str) -> ScanResult:
        """Scan a filesystem path for vulnerabilities."""
        cmd = [
            self.trivy_path, "fs",
            "--format", "json",
            "--quiet",
            path
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Trivy scan failed: {result.stderr}")

        return self._parse_trivy_output(result.stdout, path, "filesystem")

    def scan_iac(self, path: str) -> ScanResult:
        """Scan Infrastructure as Code for misconfigurations."""
        cmd = [
            self.trivy_path, "config",
            "--format", "json",
            "--quiet",
            path
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Trivy scan failed: {result.stderr}")

        return self._parse_trivy_output(result.stdout, path, "iac")

    def _parse_trivy_output(self, output: str, target: str,
                           scan_type: str) -> ScanResult:
        """Parse Trivy JSON output into ScanResult."""
        data = json.loads(output)
        vulnerabilities = []

        results = data.get("Results", [])
        for result in results:
            for vuln in result.get("Vulnerabilities", []):
                vulnerabilities.append(Vulnerability(
                    id=vuln.get("VulnerabilityID", ""),
                    package=vuln.get("PkgName", ""),
                    version=vuln.get("InstalledVersion", ""),
                    severity=Severity.from_string(vuln.get("Severity", "")),
                    title=vuln.get("Title", ""),
                    description=vuln.get("Description", ""),
                    fixed_version=vuln.get("FixedVersion"),
                    cvss_score=vuln.get("CVSS", {}).get("nvd", {}).get("V3Score"),
                    references=vuln.get("References", [])
                ))

        return ScanResult(
            target=target,
            scan_type=scan_type,
            timestamp=datetime.utcnow(),
            vulnerabilities=vulnerabilities,
            metadata={"scanner": "trivy", "schema_version": data.get("SchemaVersion")}
        )


class DependencyScanner:
    """
    Scan Python dependencies for known vulnerabilities.

    Uses multiple sources:
    - Safety DB (PyUp.io)
    - OSV (Open Source Vulnerabilities)
    - pip-audit (Python Package Index)
    """

    def __init__(self):
        self.osv_api = "https://api.osv.dev/v1/query"

    def scan_requirements(self, requirements_file: str) -> ScanResult:
        """Scan a requirements.txt file for vulnerabilities."""
        vulnerabilities = []

        with open(requirements_file) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue

                # Parse package==version
                parts = line.split("==")
                if len(parts) == 2:
                    package, version = parts
                    vulns = self._check_osv(package, version)
                    vulnerabilities.extend(vulns)

        return ScanResult(
            target=requirements_file,
            scan_type="python-dependencies",
            timestamp=datetime.utcnow(),
            vulnerabilities=vulnerabilities
        )

    def scan_pip_audit(self) -> ScanResult:
        """Use pip-audit to scan installed packages."""
        result = subprocess.run(
            ["pip-audit", "--format", "json"],
            capture_output=True,
            text=True
        )

        vulnerabilities = []

        if result.stdout:
            data = json.loads(result.stdout)
            for vuln in data.get("vulnerabilities", []):
                vulnerabilities.append(Vulnerability(
                    id=vuln.get("id", ""),
                    package=vuln.get("name", ""),
                    version=vuln.get("version", ""),
                    severity=Severity.from_string(vuln.get("severity", "UNKNOWN")),
                    title=vuln.get("description", ""),
                    fixed_version=vuln.get("fix_versions", [None])[0]
                ))

        return ScanResult(
            target="installed-packages",
            scan_type="pip-audit",
            timestamp=datetime.utcnow(),
            vulnerabilities=vulnerabilities
        )

    def _check_osv(self, package: str, version: str) -> List[Vulnerability]:
        """Check OSV database for vulnerabilities."""
        payload = {
            "package": {
                "name": package,
                "ecosystem": "PyPI"
            },
            "version": version
        }

        try:
            response = requests.post(self.osv_api, json=payload)
            response.raise_for_status()
            data = response.json()

            vulnerabilities = []
            for vuln in data.get("vulns", []):
                severity = Severity.UNKNOWN
                if "database_specific" in vuln:
                    severity_str = vuln["database_specific"].get("severity", "")
                    severity = Severity.from_string(severity_str)

                vulnerabilities.append(Vulnerability(
                    id=vuln.get("id", ""),
                    package=package,
                    version=version,
                    severity=severity,
                    title=vuln.get("summary", ""),
                    description=vuln.get("details", ""),
                    references=[ref.get("url") for ref in vuln.get("references", [])]
                ))

            return vulnerabilities

        except Exception as e:
            print(f"OSV check failed for {package}: {e}")
            return []


class SecurityReporter:
    """Generate security scan reports."""

    def __init__(self, results: List[ScanResult]):
        self.results = results

    def generate_summary(self) -> dict:
        """Generate a summary report of all scans."""
        total_vulns = sum(r.total_count for r in self.results)
        total_critical = sum(r.critical_count for r in self.results)
        total_high = sum(r.high_count for r in self.results)
        total_fixable = sum(r.fixable_count for r in self.results)

        return {
            "scan_count": len(self.results),
            "total_vulnerabilities": total_vulns,
            "by_severity": {
                "critical": total_critical,
                "high": total_high,
                "medium": sum(
                    len(r.get_by_severity(Severity.MEDIUM)) for r in self.results
                ),
                "low": sum(
                    len(r.get_by_severity(Severity.LOW)) for r in self.results
                )
            },
            "fixable": total_fixable,
            "pass": total_critical == 0 and total_high == 0,
            "results": [r.to_dict() for r in self.results]
        }

    def generate_markdown_report(self) -> str:
        """Generate a Markdown security report."""
        summary = self.generate_summary()

        lines = [
            "# Security Scan Report",
            f"",
            f"**Generated**: {datetime.utcnow().isoformat()}",
            f"**Status**: {'✅ PASS' if summary['pass'] else '❌ FAIL'}",
            f"",
            "## Summary",
            f"",
            f"| Severity | Count |",
            f"|----------|-------|",
            f"| Critical | {summary['by_severity']['critical']} |",
            f"| High | {summary['by_severity']['high']} |",
            f"| Medium | {summary['by_severity']['medium']} |",
            f"| Low | {summary['by_severity']['low']} |",
            f"| **Total** | **{summary['total_vulnerabilities']}** |",
            f"| Fixable | {summary['fixable']} |",
            f"",
        ]

        for result in self.results:
            lines.extend([
                f"## {result.target}",
                f"",
                f"**Type**: {result.scan_type}",
                f"**Vulnerabilities**: {result.total_count}",
                f"",
            ])

            if result.vulnerabilities:
                lines.extend([
                    "| ID | Package | Severity | Fixed Version |",
                    "|----|---------|----------|---------------|"
                ])

                for vuln in sorted(result.vulnerabilities,
                                   key=lambda v: list(Severity).index(v.severity)):
                    fixed = vuln.fixed_version or "N/A"
                    lines.append(
                        f"| {vuln.id} | {vuln.package}@{vuln.version} | "
                        f"{vuln.severity.value} | {fixed} |"
                    )

                lines.append("")

        return "\n".join(lines)

    def check_policy(self, max_critical: int = 0,
                     max_high: int = 0) -> tuple:
        """Check if scan results meet security policy."""
        summary = self.generate_summary()

        violations = []

        if summary["by_severity"]["critical"] > max_critical:
            violations.append(
                f"Critical vulnerabilities: {summary['by_severity']['critical']} "
                f"(max: {max_critical})"
            )

        if summary["by_severity"]["high"] > max_high:
            violations.append(
                f"High vulnerabilities: {summary['by_severity']['high']} "
                f"(max: {max_high})"
            )

        passed = len(violations) == 0
        return passed, violations


# CI/CD Integration
def run_security_gate(image: str = None,
                      requirements_file: str = None,
                      fail_on_high: bool = True) -> bool:
    """
    Run security gate checks for CI/CD pipelines.

    Returns True if all checks pass, False otherwise.
    """
    results = []

    # Scan container image
    if image:
        trivy = TrivyScanner()
        try:
            result = trivy.scan_image(image)
            results.append(result)
            print(f"Image scan: {result.total_count} vulnerabilities found")
        except Exception as e:
            print(f"Image scan failed: {e}")
            return False

    # Scan dependencies
    if requirements_file:
        dep_scanner = DependencyScanner()
        result = dep_scanner.scan_requirements(requirements_file)
        results.append(result)
        print(f"Dependency scan: {result.total_count} vulnerabilities found")

    # Generate report and check policy
    if results:
        reporter = SecurityReporter(results)

        max_high = 0 if fail_on_high else 999
        passed, violations = reporter.check_policy(max_critical=0, max_high=max_high)

        # Print report
        print(reporter.generate_markdown_report())

        if not passed:
            print("\n❌ Security gate FAILED:")
            for v in violations:
                print(f"  - {v}")
            return False

        print("\n✅ Security gate PASSED")
        return True

    return True


if __name__ == "__main__":
    # Run security checks
    # passed = run_security_gate(
    #     image="myapp:latest",
    #     requirements_file="requirements.txt"
    # )
    pass
```

---

### 📝 Phase Lab 14: DevSecOps Pipeline

**Objective**: Build a comprehensive security automation pipeline.

```python
"""
Phase Lab 14: DevSecOps Pipeline

Build a complete DevSecOps pipeline that:
1. Scans code for vulnerabilities
2. Checks secrets for exposure
3. Validates infrastructure as code
4. Generates compliance reports
"""

import os
import json
import subprocess
from datetime import datetime
from typing import List, Dict, Any
from dataclasses import dataclass, field
import re


@dataclass
class SecurityCheck:
    """Represents a security check result."""
    name: str
    category: str
    status: str  # "pass", "fail", "warn", "skip"
    findings: List[Dict[str, Any]] = field(default_factory=list)
    message: str = ""

    @property
    def passed(self) -> bool:
        return self.status == "pass"


class DevSecOpsPipeline:
    """
    Comprehensive DevSecOps pipeline.

    Runs multiple security checks:
    - Static Application Security Testing (SAST)
    - Software Composition Analysis (SCA)
    - Secrets scanning
    - Infrastructure as Code scanning
    - Container security
    """

    def __init__(self, project_path: str):
        self.project_path = project_path
        self.checks: List[SecurityCheck] = []

    def run_sast(self) -> SecurityCheck:
        """Run Static Application Security Testing with Bandit."""
        try:
            result = subprocess.run(
                ["bandit", "-r", self.project_path, "-f", "json", "-q"],
                capture_output=True,
                text=True
            )

            findings = []
            if result.stdout:
                data = json.loads(result.stdout)
                for issue in data.get("results", []):
                    findings.append({
                        "file": issue["filename"],
                        "line": issue["line_number"],
                        "severity": issue["issue_severity"],
                        "confidence": issue["issue_confidence"],
                        "issue": issue["issue_text"],
                        "code": issue.get("code", "")
                    })

            status = "pass" if not findings else "fail"
            high_severity = [f for f in findings if f["severity"] == "HIGH"]

            if high_severity:
                status = "fail"
                message = f"Found {len(high_severity)} high severity issues"
            elif findings:
                status = "warn"
                message = f"Found {len(findings)} potential security issues"
            else:
                message = "No security issues found"

            check = SecurityCheck(
                name="SAST (Bandit)",
                category="code-security",
                status=status,
                findings=findings,
                message=message
            )

        except FileNotFoundError:
            check = SecurityCheck(
                name="SAST (Bandit)",
                category="code-security",
                status="skip",
                message="Bandit not installed"
            )

        self.checks.append(check)
        return check

    def run_secrets_scan(self) -> SecurityCheck:
        """Scan for exposed secrets using detect-secrets."""
        try:
            result = subprocess.run(
                ["detect-secrets", "scan", self.project_path, "--all-files"],
                capture_output=True,
                text=True
            )

            findings = []
            if result.stdout:
                data = json.loads(result.stdout)
                for file_path, secrets in data.get("results", {}).items():
                    for secret in secrets:
                        findings.append({
                            "file": file_path,
                            "line": secret.get("line_number"),
                            "type": secret.get("type"),
                            "hashed_secret": secret.get("hashed_secret", "")[:8] + "..."
                        })

            status = "fail" if findings else "pass"
            message = f"Found {len(findings)} potential secrets" if findings else "No secrets detected"

            check = SecurityCheck(
                name="Secrets Scan",
                category="secrets",
                status=status,
                findings=findings,
                message=message
            )

        except FileNotFoundError:
            check = SecurityCheck(
                name="Secrets Scan",
                category="secrets",
                status="skip",
                message="detect-secrets not installed"
            )

        self.checks.append(check)
        return check

    def run_dependency_check(self) -> SecurityCheck:
        """Run Software Composition Analysis."""
        requirements_file = os.path.join(self.project_path, "requirements.txt")

        if not os.path.exists(requirements_file):
            check = SecurityCheck(
                name="Dependency Check",
                category="dependencies",
                status="skip",
                message="No requirements.txt found"
            )
            self.checks.append(check)
            return check

        try:
            result = subprocess.run(
                ["safety", "check", "-r", requirements_file, "--json"],
                capture_output=True,
                text=True
            )

            findings = []
            if result.stdout:
                data = json.loads(result.stdout)
                for vuln in data.get("vulnerabilities", []):
                    findings.append({
                        "package": vuln[0],
                        "affected_version": vuln[1],
                        "installed_version": vuln[2],
                        "vulnerability": vuln[3],
                        "id": vuln[4]
                    })

            status = "fail" if findings else "pass"
            message = f"Found {len(findings)} vulnerable dependencies" if findings else "All dependencies secure"

            check = SecurityCheck(
                name="Dependency Check (Safety)",
                category="dependencies",
                status=status,
                findings=findings,
                message=message
            )

        except (FileNotFoundError, json.JSONDecodeError):
            check = SecurityCheck(
                name="Dependency Check",
                category="dependencies",
                status="skip",
                message="Safety not installed or scan failed"
            )

        self.checks.append(check)
        return check

    def run_iac_scan(self) -> SecurityCheck:
        """Scan Infrastructure as Code with Checkov."""
        terraform_files = []
        for root, dirs, files in os.walk(self.project_path):
            for f in files:
                if f.endswith(".tf"):
                    terraform_files.append(os.path.join(root, f))

        if not terraform_files:
            check = SecurityCheck(
                name="IaC Scan (Checkov)",
                category="infrastructure",
                status="skip",
                message="No Terraform files found"
            )
            self.checks.append(check)
            return check

        try:
            result = subprocess.run(
                ["checkov", "-d", self.project_path, "-o", "json", "--quiet"],
                capture_output=True,
                text=True
            )

            findings = []
            if result.stdout:
                data = json.loads(result.stdout)
                for check_result in data.get("results", {}).get("failed_checks", []):
                    findings.append({
                        "check_id": check_result.get("check_id"),
                        "check_name": check_result.get("check_name"),
                        "file": check_result.get("file_path"),
                        "resource": check_result.get("resource"),
                        "guideline": check_result.get("guideline", "")
                    })

            status = "fail" if findings else "pass"
            message = f"Found {len(findings)} IaC misconfigurations" if findings else "IaC configuration secure"

            check = SecurityCheck(
                name="IaC Scan (Checkov)",
                category="infrastructure",
                status=status,
                findings=findings,
                message=message
            )

        except (FileNotFoundError, json.JSONDecodeError):
            check = SecurityCheck(
                name="IaC Scan",
                category="infrastructure",
                status="skip",
                message="Checkov not installed or scan failed"
            )

        self.checks.append(check)
        return check

    def run_license_check(self) -> SecurityCheck:
        """Check for problematic licenses in dependencies."""
        problematic_licenses = [
            "GPL", "AGPL", "LGPL", "SSPL", "BSL",
            "Commons Clause", "Elastic License"
        ]

        try:
            result = subprocess.run(
                ["pip-licenses", "--format=json"],
                capture_output=True,
                text=True
            )

            findings = []
            if result.stdout:
                packages = json.loads(result.stdout)
                for pkg in packages:
                    license_name = pkg.get("License", "UNKNOWN")
                    for problematic in problematic_licenses:
                        if problematic.lower() in license_name.lower():
                            findings.append({
                                "package": pkg["Name"],
                                "version": pkg["Version"],
                                "license": license_name
                            })
                            break

            status = "warn" if findings else "pass"
            message = f"Found {len(findings)} packages with restrictive licenses" if findings else "All licenses compatible"

            check = SecurityCheck(
                name="License Check",
                category="compliance",
                status=status,
                findings=findings,
                message=message
            )

        except (FileNotFoundError, json.JSONDecodeError):
            check = SecurityCheck(
                name="License Check",
                category="compliance",
                status="skip",
                message="pip-licenses not installed"
            )

        self.checks.append(check)
        return check

    def run_all_checks(self) -> List[SecurityCheck]:
        """Run all security checks."""
        self.checks = []

        print("🔍 Running DevSecOps Pipeline...")
        print("=" * 50)

        checks_to_run = [
            ("SAST", self.run_sast),
            ("Secrets", self.run_secrets_scan),
            ("Dependencies", self.run_dependency_check),
            ("IaC", self.run_iac_scan),
            ("Licenses", self.run_license_check),
        ]

        for name, check_func in checks_to_run:
            print(f"\n▶ Running {name} check...")
            result = check_func()
            status_emoji = {
                "pass": "✅",
                "fail": "❌",
                "warn": "⚠️",
                "skip": "⏭️"
            }.get(result.status, "❓")
            print(f"  {status_emoji} {result.message}")

        return self.checks

    def generate_report(self) -> Dict[str, Any]:
        """Generate a comprehensive security report."""
        passed = sum(1 for c in self.checks if c.status == "pass")
        failed = sum(1 for c in self.checks if c.status == "fail")
        warned = sum(1 for c in self.checks if c.status == "warn")
        skipped = sum(1 for c in self.checks if c.status == "skip")

        overall_status = "pass"
        if failed > 0:
            overall_status = "fail"
        elif warned > 0:
            overall_status = "warn"

        return {
            "timestamp": datetime.utcnow().isoformat(),
            "project": self.project_path,
            "overall_status": overall_status,
            "summary": {
                "total_checks": len(self.checks),
                "passed": passed,
                "failed": failed,
                "warnings": warned,
                "skipped": skipped
            },
            "checks": [
                {
                    "name": c.name,
                    "category": c.category,
                    "status": c.status,
                    "message": c.message,
                    "findings_count": len(c.findings),
                    "findings": c.findings[:10]  # Limit findings in report
                }
                for c in self.checks
            ]
        }

    def should_fail_pipeline(self) -> bool:
        """Determine if pipeline should fail based on results."""
        return any(c.status == "fail" for c in self.checks)


def main():
    """Run DevSecOps pipeline example."""
    import sys

    project_path = sys.argv[1] if len(sys.argv) > 1 else "."

    pipeline = DevSecOpsPipeline(project_path)
    pipeline.run_all_checks()

    report = pipeline.generate_report()

    print("\n" + "=" * 50)
    print("📊 SECURITY REPORT")
    print("=" * 50)
    print(json.dumps(report, indent=2))

    if pipeline.should_fail_pipeline():
        print("\n❌ Pipeline FAILED - Security issues must be addressed")
        sys.exit(1)
    else:
        print("\n✅ Pipeline PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
```

---

### ✅ Checkpoint: Phase 14 Self-Assessment

- [ ] Implement secure secrets management with AWS Secrets Manager
- [ ] Configure HashiCorp Vault for dynamic secrets
- [ ] Automate vulnerability scanning with Trivy
- [ ] Build security gates for CI/CD pipelines
- [ ] Create compliance automation tools
- [ ] Implement secret rotation automation

---

## Phase 15: MLOps with Python 🤖
**Estimated Time: 2-3 weeks**

> "MLOps is DevOps for Machine Learning—automating the entire ML lifecycle from training to production."

### Phase Overview

| Topic | Time | Priority | Difficulty |
|-------|------|----------|------------|
| ML Pipeline Automation | 4 days | High | Hard |
| Model Serving | 3 days | High | Medium |
| Feature Stores | 3 days | Medium | Hard |
| Model Monitoring | 3 days | High | Hard |
| Experiment Tracking | 2 days | High | Medium |

### Learning Objectives

By the end of this phase, you will:
- [ ] Build automated ML training pipelines
- [ ] Deploy models with FastAPI and containerization
- [ ] Implement feature stores for ML
- [ ] Monitor model performance and data drift
- [ ] Track experiments with MLflow

---

### 15.1 ML Pipeline Automation

```python
"""
ML Pipeline Automation: End-to-End Machine Learning Workflows

MLOps pipelines automate the entire ML lifecycle:
- Data ingestion and preprocessing
- Feature engineering
- Model training and validation
- Model deployment and serving
- Monitoring and retraining
"""

import os
import json
import pickle
import hashlib
from typing import Any, Dict, List, Optional, Callable
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
import logging

# ML Libraries
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    mean_squared_error, mean_absolute_error, r2_score
)

logger = logging.getLogger(__name__)


@dataclass
class PipelineConfig:
    """Configuration for ML pipeline."""
    name: str
    version: str
    data_path: str
    model_path: str
    target_column: str
    feature_columns: List[str] = field(default_factory=list)
    test_size: float = 0.2
    random_state: int = 42
    cross_validation_folds: int = 5
    metrics: List[str] = field(default_factory=lambda: ["accuracy"])


@dataclass
class PipelineArtifact:
    """Artifact produced by a pipeline step."""
    name: str
    path: str
    artifact_type: str
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.utcnow)

    def save_metadata(self):
        """Save artifact metadata."""
        meta_path = Path(self.path).with_suffix(".meta.json")
        with open(meta_path, "w") as f:
            json.dump({
                "name": self.name,
                "type": self.artifact_type,
                "created_at": self.created_at.isoformat(),
                "metadata": self.metadata
            }, f, indent=2)


class MLPipeline:
    """
    Automated ML Pipeline.

    Orchestrates the entire ML workflow:
    1. Data loading and validation
    2. Feature engineering
    3. Model training
    4. Evaluation
    5. Model registration
    """

    def __init__(self, config: PipelineConfig):
        self.config = config
        self.artifacts: Dict[str, PipelineArtifact] = {}
        self.metrics: Dict[str, float] = {}
        self.run_id = self._generate_run_id()

        # Create artifact directory
        self.artifact_dir = Path(config.model_path) / self.run_id
        self.artifact_dir.mkdir(parents=True, exist_ok=True)

        logger.info(f"Initialized pipeline: {config.name} v{config.version}")
        logger.info(f"Run ID: {self.run_id}")

    def _generate_run_id(self) -> str:
        """Generate unique run ID."""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        hash_input = f"{self.config.name}{timestamp}"
        short_hash = hashlib.md5(hash_input.encode()).hexdigest()[:8]
        return f"{timestamp}_{short_hash}"

    def load_data(self, path: str = None) -> pd.DataFrame:
        """Load and validate data."""
        data_path = path or self.config.data_path

        logger.info(f"Loading data from {data_path}")

        # Support multiple file formats
        if data_path.endswith(".csv"):
            df = pd.read_csv(data_path)
        elif data_path.endswith(".parquet"):
            df = pd.read_parquet(data_path)
        elif data_path.endswith(".json"):
            df = pd.read_json(data_path)
        else:
            raise ValueError(f"Unsupported file format: {data_path}")

        # Data validation
        self._validate_data(df)

        # Store artifact
        self.artifacts["raw_data"] = PipelineArtifact(
            name="raw_data",
            path=data_path,
            artifact_type="dataset",
            metadata={
                "shape": df.shape,
                "columns": list(df.columns),
                "dtypes": df.dtypes.astype(str).to_dict()
            }
        )

        logger.info(f"Loaded {len(df)} rows, {len(df.columns)} columns")

        return df

    def _validate_data(self, df: pd.DataFrame):
        """Validate data against schema."""
        # Check target column exists
        if self.config.target_column not in df.columns:
            raise ValueError(f"Target column '{self.config.target_column}' not found")

        # Check for required features
        missing_features = set(self.config.feature_columns) - set(df.columns)
        if missing_features:
            raise ValueError(f"Missing feature columns: {missing_features}")

        # Check for null values in critical columns
        null_counts = df[self.config.feature_columns + [self.config.target_column]].isnull().sum()
        if null_counts.any():
            logger.warning(f"Null values found:\n{null_counts[null_counts > 0]}")

    def preprocess(self, df: pd.DataFrame) -> tuple:
        """Preprocess data for training."""
        logger.info("Preprocessing data...")

        # Select features
        if self.config.feature_columns:
            X = df[self.config.feature_columns].copy()
        else:
            X = df.drop(columns=[self.config.target_column]).copy()

        y = df[self.config.target_column].copy()

        # Handle missing values
        X = X.fillna(X.median(numeric_only=True))

        # Encode categorical variables
        encoders = {}
        for col in X.select_dtypes(include=["object"]).columns:
            encoders[col] = LabelEncoder()
            X[col] = encoders[col].fit_transform(X[col].astype(str))

        # Scale numeric features
        scaler = StandardScaler()
        numeric_cols = X.select_dtypes(include=[np.number]).columns
        X[numeric_cols] = scaler.fit_transform(X[numeric_cols])

        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y,
            test_size=self.config.test_size,
            random_state=self.config.random_state
        )

        # Save preprocessing artifacts
        self._save_preprocessor({
            "scaler": scaler,
            "encoders": encoders,
            "feature_columns": list(X.columns)
        })

        logger.info(f"Train set: {len(X_train)}, Test set: {len(X_test)}")

        return X_train, X_test, y_train, y_test

    def _save_preprocessor(self, preprocessor: dict):
        """Save preprocessing artifacts."""
        path = self.artifact_dir / "preprocessor.pkl"
        with open(path, "wb") as f:
            pickle.dump(preprocessor, f)

        self.artifacts["preprocessor"] = PipelineArtifact(
            name="preprocessor",
            path=str(path),
            artifact_type="preprocessor",
            metadata={"feature_columns": preprocessor["feature_columns"]}
        )

    def train(self, model, X_train, y_train, X_test, y_test) -> dict:
        """Train and evaluate model."""
        logger.info(f"Training model: {type(model).__name__}")

        # Train
        model.fit(X_train, y_train)

        # Predictions
        y_pred_train = model.predict(X_train)
        y_pred_test = model.predict(X_test)

        # Calculate metrics
        metrics = self._calculate_metrics(y_train, y_pred_train, prefix="train_")
        metrics.update(self._calculate_metrics(y_test, y_pred_test, prefix="test_"))

        # Cross-validation
        cv_scores = cross_val_score(
            model, X_train, y_train,
            cv=self.config.cross_validation_folds
        )
        metrics["cv_mean"] = cv_scores.mean()
        metrics["cv_std"] = cv_scores.std()

        self.metrics = metrics

        # Save model
        self._save_model(model, metrics)

        logger.info(f"Training complete. Test accuracy: {metrics.get('test_accuracy', 'N/A'):.4f}")

        return metrics

    def _calculate_metrics(self, y_true, y_pred, prefix: str = "") -> dict:
        """Calculate model metrics."""
        metrics = {}

        # Determine if classification or regression
        unique_values = len(np.unique(y_true))
        is_classification = unique_values < 20

        if is_classification:
            metrics[f"{prefix}accuracy"] = accuracy_score(y_true, y_pred)
            metrics[f"{prefix}precision"] = precision_score(y_true, y_pred, average="weighted", zero_division=0)
            metrics[f"{prefix}recall"] = recall_score(y_true, y_pred, average="weighted", zero_division=0)
            metrics[f"{prefix}f1"] = f1_score(y_true, y_pred, average="weighted", zero_division=0)
        else:
            metrics[f"{prefix}mse"] = mean_squared_error(y_true, y_pred)
            metrics[f"{prefix}rmse"] = np.sqrt(metrics[f"{prefix}mse"])
            metrics[f"{prefix}mae"] = mean_absolute_error(y_true, y_pred)
            metrics[f"{prefix}r2"] = r2_score(y_true, y_pred)

        return metrics

    def _save_model(self, model, metrics: dict):
        """Save trained model."""
        path = self.artifact_dir / "model.pkl"
        with open(path, "wb") as f:
            pickle.dump(model, f)

        self.artifacts["model"] = PipelineArtifact(
            name="model",
            path=str(path),
            artifact_type="model",
            metadata={
                "model_type": type(model).__name__,
                "metrics": metrics
            }
        )
        self.artifacts["model"].save_metadata()

    def run(self, model) -> dict:
        """Run the complete pipeline."""
        logger.info(f"Starting pipeline run: {self.run_id}")

        start_time = datetime.utcnow()

        try:
            # Load data
            df = self.load_data()

            # Preprocess
            X_train, X_test, y_train, y_test = self.preprocess(df)

            # Train
            metrics = self.train(model, X_train, y_train, X_test, y_test)

            # Record run info
            duration = (datetime.utcnow() - start_time).total_seconds()

            run_info = {
                "run_id": self.run_id,
                "pipeline": self.config.name,
                "version": self.config.version,
                "status": "success",
                "duration_seconds": duration,
                "metrics": metrics,
                "artifacts": {k: v.path for k, v in self.artifacts.items()}
            }

            # Save run info
            with open(self.artifact_dir / "run_info.json", "w") as f:
                json.dump(run_info, f, indent=2)

            logger.info(f"Pipeline completed in {duration:.2f}s")

            return run_info

        except Exception as e:
            logger.error(f"Pipeline failed: {e}")
            raise


class ModelRegistry:
    """
    Model Registry for versioning and deployment.

    Tracks model versions, stages, and deployments.
    """

    def __init__(self, registry_path: str):
        self.registry_path = Path(registry_path)
        self.registry_path.mkdir(parents=True, exist_ok=True)
        self.registry_file = self.registry_path / "registry.json"
        self.registry = self._load_registry()

    def _load_registry(self) -> dict:
        """Load registry from file."""
        if self.registry_file.exists():
            with open(self.registry_file) as f:
                return json.load(f)
        return {"models": {}}

    def _save_registry(self):
        """Save registry to file."""
        with open(self.registry_file, "w") as f:
            json.dump(self.registry, f, indent=2)

    def register_model(self, name: str, version: str,
                       artifact_path: str, metrics: dict,
                       stage: str = "staging") -> dict:
        """Register a new model version."""
        if name not in self.registry["models"]:
            self.registry["models"][name] = {"versions": []}

        model_info = {
            "version": version,
            "artifact_path": artifact_path,
            "metrics": metrics,
            "stage": stage,
            "registered_at": datetime.utcnow().isoformat(),
            "transitions": []
        }

        self.registry["models"][name]["versions"].append(model_info)
        self.registry["models"][name]["latest"] = version

        self._save_registry()

        logger.info(f"Registered model: {name} v{version} ({stage})")

        return model_info

    def transition_stage(self, name: str, version: str,
                         new_stage: str, comment: str = ""):
        """Transition model to a new stage."""
        if name not in self.registry["models"]:
            raise ValueError(f"Model {name} not found")

        for model in self.registry["models"][name]["versions"]:
            if model["version"] == version:
                old_stage = model["stage"]
                model["stage"] = new_stage
                model["transitions"].append({
                    "from": old_stage,
                    "to": new_stage,
                    "timestamp": datetime.utcnow().isoformat(),
                    "comment": comment
                })
                self._save_registry()

                logger.info(f"Transitioned {name} v{version}: {old_stage} -> {new_stage}")
                return

        raise ValueError(f"Version {version} not found for model {name}")

    def get_production_model(self, name: str) -> Optional[dict]:
        """Get the current production model."""
        if name not in self.registry["models"]:
            return None

        for model in self.registry["models"][name]["versions"]:
            if model["stage"] == "production":
                return model

        return None

    def compare_models(self, name: str, metric: str = "test_accuracy") -> list:
        """Compare all versions of a model by metric."""
        if name not in self.registry["models"]:
            return []

        versions = self.registry["models"][name]["versions"]
        return sorted(
            versions,
            key=lambda m: m["metrics"].get(metric, 0),
            reverse=True
        )


# Example usage
if __name__ == "__main__":
    from sklearn.ensemble import RandomForestClassifier

    # Configure pipeline
    config = PipelineConfig(
        name="customer-churn",
        version="1.0.0",
        data_path="data/customers.csv",
        model_path="models",
        target_column="churned",
        feature_columns=["age", "tenure", "monthly_charges", "total_charges"],
        test_size=0.2
    )

    # Run pipeline
    # pipeline = MLPipeline(config)
    # model = RandomForestClassifier(n_estimators=100, random_state=42)
    # results = pipeline.run(model)

    # Register model
    # registry = ModelRegistry("model_registry")
    # registry.register_model(
    #     name="customer-churn",
    #     version="1.0.0",
    #     artifact_path=results["artifacts"]["model"],
    #     metrics=results["metrics"],
    #     stage="staging"
    # )

    print("MLPipeline example - requires data file to run")
```

---

### 15.2 Model Serving with FastAPI

```python
"""
Model Serving: Deploy ML Models as APIs

FastAPI provides a high-performance framework for serving ML models
with automatic documentation, validation, and async support.
"""

import os
import pickle
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime
from pathlib import Path
from contextlib import asynccontextmanager

import numpy as np
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator

logger = logging.getLogger(__name__)


# ============================================================
# Request/Response Models
# ============================================================

class PredictionRequest(BaseModel):
    """Request model for predictions."""
    features: Dict[str, Any] = Field(..., description="Feature values for prediction")
    request_id: Optional[str] = Field(None, description="Optional request tracking ID")

    class Config:
        json_schema_extra = {
            "example": {
                "features": {
                    "age": 35,
                    "tenure": 24,
                    "monthly_charges": 65.5,
                    "total_charges": 1572.0
                },
                "request_id": "req_123"
            }
        }


class BatchPredictionRequest(BaseModel):
    """Request model for batch predictions."""
    instances: List[Dict[str, Any]] = Field(..., description="List of feature dictionaries")
    request_id: Optional[str] = None


class PredictionResponse(BaseModel):
    """Response model for predictions."""
    prediction: Any
    probability: Optional[List[float]] = None
    model_version: str
    request_id: Optional[str] = None
    latency_ms: float


class BatchPredictionResponse(BaseModel):
    """Response model for batch predictions."""
    predictions: List[Any]
    probabilities: Optional[List[List[float]]] = None
    model_version: str
    request_id: Optional[str] = None
    latency_ms: float
    batch_size: int


class ModelInfo(BaseModel):
    """Model metadata."""
    name: str
    version: str
    loaded_at: str
    features: List[str]
    model_type: str


class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    model_loaded: bool
    uptime_seconds: float


# ============================================================
# Model Manager
# ============================================================

class ModelManager:
    """
    Manages model loading, versioning, and inference.

    Features:
    - Lazy loading
    - Version management
    - Hot reloading
    - Preprocessing pipeline
    """

    def __init__(self, model_dir: str = "models"):
        self.model_dir = Path(model_dir)
        self.model = None
        self.preprocessor = None
        self.model_version = None
        self.model_type = None
        self.feature_columns = []
        self.loaded_at = None
        self.start_time = datetime.utcnow()

    def load_model(self, version: str = "latest"):
        """Load model and preprocessor."""
        # Find model path
        if version == "latest":
            model_dirs = sorted(self.model_dir.glob("*"), reverse=True)
            if not model_dirs:
                raise FileNotFoundError(f"No models found in {self.model_dir}")
            model_path = model_dirs[0]
        else:
            model_path = self.model_dir / version

        if not model_path.exists():
            raise FileNotFoundError(f"Model not found: {model_path}")

        # Load model
        with open(model_path / "model.pkl", "rb") as f:
            self.model = pickle.load(f)

        # Load preprocessor
        preprocessor_path = model_path / "preprocessor.pkl"
        if preprocessor_path.exists():
            with open(preprocessor_path, "rb") as f:
                self.preprocessor = pickle.load(f)
                self.feature_columns = self.preprocessor.get("feature_columns", [])

        self.model_version = model_path.name
        self.model_type = type(self.model).__name__
        self.loaded_at = datetime.utcnow()

        logger.info(f"Loaded model: {self.model_version} ({self.model_type})")

    def preprocess(self, features: Dict[str, Any]) -> np.ndarray:
        """Preprocess features for prediction."""
        if not self.preprocessor:
            # No preprocessing - just convert to array
            return np.array([list(features.values())])

        # Create dataframe with expected columns
        import pandas as pd
        df = pd.DataFrame([features])

        # Ensure all columns present
        for col in self.feature_columns:
            if col not in df.columns:
                df[col] = 0  # Default value

        # Reorder columns
        df = df[self.feature_columns]

        # Apply encoders
        encoders = self.preprocessor.get("encoders", {})
        for col, encoder in encoders.items():
            if col in df.columns:
                try:
                    df[col] = encoder.transform(df[col].astype(str))
                except ValueError:
                    df[col] = 0  # Unknown category

        # Apply scaler
        scaler = self.preprocessor.get("scaler")
        if scaler:
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            df[numeric_cols] = scaler.transform(df[numeric_cols])

        return df.values

    def predict(self, features: Dict[str, Any]) -> tuple:
        """Make a single prediction."""
        if self.model is None:
            raise RuntimeError("Model not loaded")

        X = self.preprocess(features)
        prediction = self.model.predict(X)[0]

        # Get probabilities if available
        probabilities = None
        if hasattr(self.model, "predict_proba"):
            probabilities = self.model.predict_proba(X)[0].tolist()

        return prediction, probabilities

    def predict_batch(self, instances: List[Dict[str, Any]]) -> tuple:
        """Make batch predictions."""
        if self.model is None:
            raise RuntimeError("Model not loaded")

        # Preprocess all instances
        X_list = [self.preprocess(inst) for inst in instances]
        X = np.vstack(X_list)

        predictions = self.model.predict(X).tolist()

        probabilities = None
        if hasattr(self.model, "predict_proba"):
            probabilities = self.model.predict_proba(X).tolist()

        return predictions, probabilities

    @property
    def is_loaded(self) -> bool:
        """Check if model is loaded."""
        return self.model is not None

    @property
    def uptime(self) -> float:
        """Get uptime in seconds."""
        return (datetime.utcnow() - self.start_time).total_seconds()


# ============================================================
# FastAPI Application
# ============================================================

# Global model manager
model_manager = ModelManager()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    logger.info("Starting model serving application...")
    try:
        model_manager.load_model()
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.warning(f"Failed to load model on startup: {e}")

    yield

    # Shutdown
    logger.info("Shutting down...")


# Create FastAPI app
app = FastAPI(
    title="ML Model Serving API",
    description="High-performance ML model inference API",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# API Endpoints
# ============================================================

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Check API health status."""
    return HealthResponse(
        status="healthy" if model_manager.is_loaded else "degraded",
        model_loaded=model_manager.is_loaded,
        uptime_seconds=model_manager.uptime
    )


@app.get("/model/info", response_model=ModelInfo)
async def get_model_info():
    """Get information about the loaded model."""
    if not model_manager.is_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")

    return ModelInfo(
        name="ml-model",
        version=model_manager.model_version,
        loaded_at=model_manager.loaded_at.isoformat(),
        features=model_manager.feature_columns,
        model_type=model_manager.model_type
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest, background_tasks: BackgroundTasks):
    """Make a single prediction."""
    if not model_manager.is_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")

    start_time = datetime.utcnow()

    try:
        prediction, probability = model_manager.predict(request.features)

        latency = (datetime.utcnow() - start_time).total_seconds() * 1000

        # Log prediction in background
        background_tasks.add_task(
            log_prediction,
            request_id=request.request_id,
            features=request.features,
            prediction=prediction,
            latency=latency
        )

        return PredictionResponse(
            prediction=prediction,
            probability=probability,
            model_version=model_manager.model_version,
            request_id=request.request_id,
            latency_ms=latency
        )

    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/predict/batch", response_model=BatchPredictionResponse)
async def predict_batch(request: BatchPredictionRequest, background_tasks: BackgroundTasks):
    """Make batch predictions."""
    if not model_manager.is_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")

    if len(request.instances) > 1000:
        raise HTTPException(status_code=400, detail="Batch size exceeds limit of 1000")

    start_time = datetime.utcnow()

    try:
        predictions, probabilities = model_manager.predict_batch(request.instances)

        latency = (datetime.utcnow() - start_time).total_seconds() * 1000

        return BatchPredictionResponse(
            predictions=predictions,
            probabilities=probabilities,
            model_version=model_manager.model_version,
            request_id=request.request_id,
            latency_ms=latency,
            batch_size=len(request.instances)
        )

    except Exception as e:
        logger.error(f"Batch prediction failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/model/reload")
async def reload_model(version: str = "latest"):
    """Reload the model (hot reload)."""
    try:
        model_manager.load_model(version)
        return {
            "status": "success",
            "message": f"Model reloaded: {model_manager.model_version}"
        }
    except Exception as e:
        logger.error(f"Model reload failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def log_prediction(request_id: str, features: dict,
                        prediction: Any, latency: float):
    """Log prediction for monitoring (background task)."""
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "request_id": request_id,
        "features": features,
        "prediction": prediction,
        "latency_ms": latency,
        "model_version": model_manager.model_version
    }

    # In production, send to monitoring system
    logger.info(f"Prediction: {log_entry}")


# ============================================================
# Dockerfile for containerized deployment
# ============================================================

DOCKERFILE = """
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8000

# Run with uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
"""


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

### 📝 Phase Lab 15: End-to-End MLOps Platform

**Objective**: Build a complete MLOps platform with training, serving, and monitoring.

```python
"""
Phase Lab 15: End-to-End MLOps Platform

Build a complete MLOps platform that:
1. Manages ML experiments with MLflow
2. Trains models with automated pipelines
3. Serves models via REST API
4. Monitors model performance and data drift
"""

import os
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)


# ============================================================
# Experiment Tracking with MLflow
# ============================================================

class ExperimentTracker:
    """
    MLflow-style experiment tracking.

    Tracks:
    - Parameters (hyperparameters)
    - Metrics (accuracy, loss, etc.)
    - Artifacts (models, plots, etc.)
    - Code versions
    """

    def __init__(self, experiment_name: str, tracking_uri: str = "file:./mlruns"):
        self.experiment_name = experiment_name
        self.tracking_uri = tracking_uri
        self.current_run = None
        self.runs = []

    def start_run(self, run_name: str = None) -> str:
        """Start a new experiment run."""
        run_id = f"run_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"

        self.current_run = {
            "run_id": run_id,
            "run_name": run_name or run_id,
            "experiment": self.experiment_name,
            "start_time": datetime.utcnow().isoformat(),
            "end_time": None,
            "status": "running",
            "params": {},
            "metrics": {},
            "artifacts": [],
            "tags": {}
        }

        logger.info(f"Started run: {run_id}")
        return run_id

    def log_param(self, key: str, value: Any):
        """Log a single parameter."""
        if self.current_run:
            self.current_run["params"][key] = value

    def log_params(self, params: Dict[str, Any]):
        """Log multiple parameters."""
        if self.current_run:
            self.current_run["params"].update(params)

    def log_metric(self, key: str, value: float, step: int = None):
        """Log a single metric."""
        if self.current_run:
            if key not in self.current_run["metrics"]:
                self.current_run["metrics"][key] = []

            self.current_run["metrics"][key].append({
                "value": value,
                "step": step,
                "timestamp": datetime.utcnow().isoformat()
            })

    def log_metrics(self, metrics: Dict[str, float], step: int = None):
        """Log multiple metrics."""
        for key, value in metrics.items():
            self.log_metric(key, value, step)

    def log_artifact(self, local_path: str, artifact_path: str = None):
        """Log an artifact file."""
        if self.current_run:
            self.current_run["artifacts"].append({
                "local_path": local_path,
                "artifact_path": artifact_path or os.path.basename(local_path),
                "logged_at": datetime.utcnow().isoformat()
            })

    def set_tag(self, key: str, value: str):
        """Set a tag on the current run."""
        if self.current_run:
            self.current_run["tags"][key] = value

    def end_run(self, status: str = "finished"):
        """End the current run."""
        if self.current_run:
            self.current_run["end_time"] = datetime.utcnow().isoformat()
            self.current_run["status"] = status
            self.runs.append(self.current_run)

            # Save run
            self._save_run(self.current_run)

            logger.info(f"Ended run: {self.current_run['run_id']} ({status})")
            self.current_run = None

    def _save_run(self, run: dict):
        """Save run to tracking store."""
        run_dir = os.path.join(
            self.tracking_uri.replace("file:", ""),
            self.experiment_name,
            run["run_id"]
        )
        os.makedirs(run_dir, exist_ok=True)

        with open(os.path.join(run_dir, "run.json"), "w") as f:
            json.dump(run, f, indent=2)

    def get_best_run(self, metric: str, mode: str = "max") -> Optional[dict]:
        """Get the best run by a metric."""
        if not self.runs:
            return None

        def get_metric_value(run):
            values = run["metrics"].get(metric, [])
            if values:
                return values[-1]["value"]
            return float("-inf") if mode == "max" else float("inf")

        return sorted(
            self.runs,
            key=get_metric_value,
            reverse=(mode == "max")
        )[0]


# ============================================================
# Model Monitoring
# ============================================================

@dataclass
class DataProfile:
    """Statistical profile of a dataset."""
    column: str
    dtype: str
    count: int
    null_count: int
    mean: float = None
    std: float = None
    min: float = None
    max: float = None
    unique_count: int = None
    distribution: Dict[str, int] = field(default_factory=dict)


class ModelMonitor:
    """
    Monitor model performance and data drift.

    Detects:
    - Data drift (feature distribution changes)
    - Prediction drift (output distribution changes)
    - Performance degradation
    """

    def __init__(self, reference_data: pd.DataFrame):
        self.reference_profile = self._create_profile(reference_data)
        self.alerts = []

    def _create_profile(self, df: pd.DataFrame) -> Dict[str, DataProfile]:
        """Create statistical profile of dataframe."""
        profile = {}

        for col in df.columns:
            col_data = df[col]

            p = DataProfile(
                column=col,
                dtype=str(col_data.dtype),
                count=len(col_data),
                null_count=col_data.isnull().sum()
            )

            if np.issubdtype(col_data.dtype, np.number):
                p.mean = float(col_data.mean())
                p.std = float(col_data.std())
                p.min = float(col_data.min())
                p.max = float(col_data.max())
            else:
                p.unique_count = col_data.nunique()
                p.distribution = col_data.value_counts().head(10).to_dict()

            profile[col] = p

        return profile

    def check_data_drift(self, current_data: pd.DataFrame,
                         threshold: float = 0.1) -> Dict[str, Any]:
        """Check for data drift using statistical tests."""
        current_profile = self._create_profile(current_data)
        drift_report = {"drifted_columns": [], "details": {}}

        for col, ref_profile in self.reference_profile.items():
            if col not in current_profile:
                continue

            curr_profile = current_profile[col]

            # Check numeric columns
            if ref_profile.mean is not None:
                # Simple drift detection using mean/std
                mean_shift = abs(ref_profile.mean - curr_profile.mean)
                relative_shift = mean_shift / (ref_profile.std + 1e-10)

                drifted = relative_shift > threshold * 3  # 3-sigma rule

                drift_report["details"][col] = {
                    "type": "numeric",
                    "reference_mean": ref_profile.mean,
                    "current_mean": curr_profile.mean,
                    "relative_shift": relative_shift,
                    "drifted": drifted
                }

                if drifted:
                    drift_report["drifted_columns"].append(col)
                    self._add_alert(f"Data drift detected in {col}", "warning")

            # Check categorical columns
            elif ref_profile.distribution:
                ref_dist = ref_profile.distribution
                curr_dist = curr_profile.distribution

                # Calculate distribution difference
                all_categories = set(ref_dist.keys()) | set(curr_dist.keys())
                diff = sum(
                    abs(ref_dist.get(c, 0) - curr_dist.get(c, 0))
                    for c in all_categories
                )
                total = sum(ref_dist.values()) + sum(curr_dist.values())
                drift_score = diff / total if total > 0 else 0

                drifted = drift_score > threshold

                drift_report["details"][col] = {
                    "type": "categorical",
                    "drift_score": drift_score,
                    "drifted": drifted
                }

                if drifted:
                    drift_report["drifted_columns"].append(col)

        drift_report["overall_drift"] = len(drift_report["drifted_columns"]) > 0

        return drift_report

    def check_prediction_drift(self, predictions: np.ndarray,
                               reference_predictions: np.ndarray,
                               threshold: float = 0.1) -> Dict[str, Any]:
        """Check for prediction distribution drift."""
        ref_mean = np.mean(reference_predictions)
        ref_std = np.std(reference_predictions)
        curr_mean = np.mean(predictions)
        curr_std = np.std(predictions)

        mean_shift = abs(ref_mean - curr_mean) / (ref_std + 1e-10)
        std_ratio = curr_std / (ref_std + 1e-10)

        drifted = mean_shift > 3 or std_ratio > 2 or std_ratio < 0.5

        if drifted:
            self._add_alert("Prediction drift detected", "critical")

        return {
            "reference_mean": float(ref_mean),
            "reference_std": float(ref_std),
            "current_mean": float(curr_mean),
            "current_std": float(curr_std),
            "mean_shift_sigma": float(mean_shift),
            "std_ratio": float(std_ratio),
            "drifted": drifted
        }

    def check_performance(self, y_true: np.ndarray, y_pred: np.ndarray,
                          baseline_accuracy: float,
                          threshold: float = 0.05) -> Dict[str, Any]:
        """Check for model performance degradation."""
        from sklearn.metrics import accuracy_score

        current_accuracy = accuracy_score(y_true, y_pred)
        degradation = baseline_accuracy - current_accuracy

        degraded = degradation > threshold

        if degraded:
            self._add_alert(
                f"Model performance degraded by {degradation:.2%}",
                "critical"
            )

        return {
            "baseline_accuracy": baseline_accuracy,
            "current_accuracy": current_accuracy,
            "degradation": degradation,
            "degraded": degraded
        }

    def _add_alert(self, message: str, severity: str):
        """Add monitoring alert."""
        alert = {
            "timestamp": datetime.utcnow().isoformat(),
            "message": message,
            "severity": severity
        }
        self.alerts.append(alert)
        logger.warning(f"Alert [{severity}]: {message}")

    def get_alerts(self, since: datetime = None) -> List[Dict[str, Any]]:
        """Get recent alerts."""
        if since is None:
            since = datetime.utcnow() - timedelta(hours=24)

        return [
            a for a in self.alerts
            if datetime.fromisoformat(a["timestamp"]) > since
        ]


# ============================================================
# Feature Store (Simplified)
# ============================================================

class FeatureStore:
    """
    Simple feature store for ML features.

    Features:
    - Feature versioning
    - Point-in-time lookups
    - Feature serving
    """

    def __init__(self, store_path: str = "feature_store"):
        self.store_path = store_path
        os.makedirs(store_path, exist_ok=True)
        self.feature_groups = {}

    def create_feature_group(self, name: str, schema: Dict[str, str],
                             entity_column: str, timestamp_column: str = None):
        """Create a new feature group."""
        self.feature_groups[name] = {
            "name": name,
            "schema": schema,
            "entity_column": entity_column,
            "timestamp_column": timestamp_column,
            "created_at": datetime.utcnow().isoformat()
        }

        # Save metadata
        with open(os.path.join(self.store_path, f"{name}_meta.json"), "w") as f:
            json.dump(self.feature_groups[name], f, indent=2)

        logger.info(f"Created feature group: {name}")

    def ingest_features(self, group_name: str, df: pd.DataFrame):
        """Ingest features into the store."""
        if group_name not in self.feature_groups:
            raise ValueError(f"Feature group {group_name} not found")

        # Validate schema
        group = self.feature_groups[group_name]
        for col, dtype in group["schema"].items():
            if col not in df.columns:
                raise ValueError(f"Missing column: {col}")

        # Save features
        path = os.path.join(self.store_path, f"{group_name}.parquet")

        if os.path.exists(path):
            existing = pd.read_parquet(path)
            df = pd.concat([existing, df], ignore_index=True)
            df = df.drop_duplicates(subset=[group["entity_column"]], keep="last")

        df.to_parquet(path, index=False)

        logger.info(f"Ingested {len(df)} records to {group_name}")

    def get_features(self, group_name: str, entity_ids: List[str],
                     feature_names: List[str] = None) -> pd.DataFrame:
        """Retrieve features for entities."""
        if group_name not in self.feature_groups:
            raise ValueError(f"Feature group {group_name} not found")

        path = os.path.join(self.store_path, f"{group_name}.parquet")

        if not os.path.exists(path):
            return pd.DataFrame()

        df = pd.read_parquet(path)
        group = self.feature_groups[group_name]

        # Filter by entity IDs
        df = df[df[group["entity_column"]].isin(entity_ids)]

        # Select specific features
        if feature_names:
            cols = [group["entity_column"]] + feature_names
            df = df[[c for c in cols if c in df.columns]]

        return df

    def get_training_data(self, group_name: str, label_column: str = None,
                          start_date: str = None, end_date: str = None) -> pd.DataFrame:
        """Get training data with optional time filtering."""
        path = os.path.join(self.store_path, f"{group_name}.parquet")

        if not os.path.exists(path):
            return pd.DataFrame()

        df = pd.read_parquet(path)
        group = self.feature_groups[group_name]

        # Filter by time if timestamp column exists
        if group["timestamp_column"] and start_date:
            df = df[df[group["timestamp_column"]] >= start_date]
        if group["timestamp_column"] and end_date:
            df = df[df[group["timestamp_column"]] <= end_date]

        return df


# ============================================================
# Complete MLOps Pipeline Orchestration
# ============================================================

class MLOpsPlatform:
    """
    Complete MLOps platform orchestrator.

    Coordinates:
    - Experiment tracking
    - Model training
    - Model serving
    - Model monitoring
    - Feature management
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.experiment_tracker = ExperimentTracker(config.get("experiment_name", "default"))
        self.feature_store = FeatureStore(config.get("feature_store_path", "feature_store"))
        self.monitor = None  # Initialized when reference data is available

    def run_training_pipeline(self, model_class, model_params: Dict[str, Any],
                              training_data: pd.DataFrame,
                              target_column: str,
                              feature_columns: List[str]) -> Dict[str, Any]:
        """Run complete training pipeline."""
        # Start experiment tracking
        run_id = self.experiment_tracker.start_run(
            run_name=f"train_{datetime.utcnow().strftime('%Y%m%d')}"
        )

        try:
            # Log parameters
            self.experiment_tracker.log_params(model_params)
            self.experiment_tracker.set_tag("model_type", model_class.__name__)

            # Prepare data
            X = training_data[feature_columns]
            y = training_data[target_column]

            from sklearn.model_selection import train_test_split
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )

            # Train model
            model = model_class(**model_params)
            model.fit(X_train, y_train)

            # Evaluate
            from sklearn.metrics import accuracy_score, f1_score
            y_pred = model.predict(X_test)

            metrics = {
                "accuracy": accuracy_score(y_test, y_pred),
                "f1_score": f1_score(y_test, y_pred, average="weighted")
            }

            self.experiment_tracker.log_metrics(metrics)

            # Save model
            import pickle
            model_path = f"models/{run_id}/model.pkl"
            os.makedirs(os.path.dirname(model_path), exist_ok=True)
            with open(model_path, "wb") as f:
                pickle.dump(model, f)

            self.experiment_tracker.log_artifact(model_path)
            self.experiment_tracker.end_run("finished")

            # Initialize monitor with reference data
            self.monitor = ModelMonitor(X_test)

            return {
                "run_id": run_id,
                "metrics": metrics,
                "model_path": model_path
            }

        except Exception as e:
            self.experiment_tracker.end_run("failed")
            raise

    def run_monitoring_check(self, current_data: pd.DataFrame,
                             predictions: np.ndarray = None,
                             y_true: np.ndarray = None) -> Dict[str, Any]:
        """Run monitoring checks."""
        if self.monitor is None:
            raise RuntimeError("Monitor not initialized. Run training first.")

        report = {
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {}
        }

        # Data drift check
        drift_report = self.monitor.check_data_drift(current_data)
        report["checks"]["data_drift"] = drift_report

        # Performance check (if labels available)
        if y_true is not None and predictions is not None:
            # Get baseline from best run
            best_run = self.experiment_tracker.get_best_run("accuracy")
            if best_run:
                baseline = best_run["metrics"]["accuracy"][-1]["value"]
                perf_report = self.monitor.check_performance(
                    y_true, predictions, baseline
                )
                report["checks"]["performance"] = perf_report

        # Get alerts
        report["alerts"] = self.monitor.get_alerts()

        return report


# Example usage
def main():
    """Demonstrate MLOps platform usage."""
    print("=" * 60)
    print("MLOps Platform Demo")
    print("=" * 60)

    # Create sample data
    np.random.seed(42)
    n_samples = 1000

    data = pd.DataFrame({
        "feature_1": np.random.randn(n_samples),
        "feature_2": np.random.randn(n_samples),
        "feature_3": np.random.rand(n_samples),
        "target": np.random.choice([0, 1], n_samples)
    })

    # Initialize platform
    config = {
        "experiment_name": "customer_churn",
        "feature_store_path": "feature_store"
    }

    platform = MLOpsPlatform(config)

    # Create feature group
    platform.feature_store.create_feature_group(
        name="customer_features",
        schema={
            "customer_id": "string",
            "feature_1": "float",
            "feature_2": "float",
            "feature_3": "float"
        },
        entity_column="customer_id"
    )

    print("\n✓ Feature store initialized")

    # Run training pipeline
    from sklearn.ensemble import RandomForestClassifier

    result = platform.run_training_pipeline(
        model_class=RandomForestClassifier,
        model_params={"n_estimators": 100, "max_depth": 10},
        training_data=data,
        target_column="target",
        feature_columns=["feature_1", "feature_2", "feature_3"]
    )

    print(f"\n✓ Training complete")
    print(f"  Run ID: {result['run_id']}")
    print(f"  Accuracy: {result['metrics']['accuracy']:.4f}")
    print(f"  F1 Score: {result['metrics']['f1_score']:.4f}")

    # Simulate monitoring (with slight drift)
    new_data = pd.DataFrame({
        "feature_1": np.random.randn(100) + 0.5,  # Shifted mean
        "feature_2": np.random.randn(100),
        "feature_3": np.random.rand(100)
    })

    monitoring_report = platform.run_monitoring_check(new_data)

    print(f"\n✓ Monitoring check complete")
    print(f"  Data drift detected: {monitoring_report['checks']['data_drift']['overall_drift']}")
    if monitoring_report['checks']['data_drift']['drifted_columns']:
        print(f"  Drifted columns: {monitoring_report['checks']['data_drift']['drifted_columns']}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
```

---

### ✅ Checkpoint: Phase 15 Self-Assessment

- [ ] Build automated ML training pipelines
- [ ] Deploy models with FastAPI
- [ ] Implement experiment tracking with MLflow patterns
- [ ] Monitor model performance and data drift
- [ ] Create feature stores for ML features
- [ ] Implement model versioning and registry

---

## Phase 16: Platform Engineering Specializations 🌐
**Estimated Time: 3-4 weeks**

> "Modern platform engineering combines GitOps, service mesh, chaos engineering, and FinOps to build resilient, cost-effective systems."

### Phase Overview

| Topic | Time | Priority | Difficulty |
|-------|------|----------|------------|
| GitOps with ArgoCD/Flux | 5 days | High | Medium |
| Service Mesh with Istio | 5 days | High | Hard |
| Chaos Engineering | 4 days | Medium | Hard |
| FinOps & Cost Optimization | 4 days | High | Medium |

### Learning Objectives

By the end of this phase, you will:
- [ ] Implement GitOps workflows with ArgoCD
- [ ] Configure service mesh with Istio
- [ ] Design and run chaos experiments
- [ ] Build cloud cost optimization tools
- [ ] Create platform automation tooling

---

### 16.1 GitOps with ArgoCD

```python
"""
GitOps: Infrastructure and Application Automation

GitOps uses Git as the single source of truth for declarative infrastructure
and applications. ArgoCD and Flux are popular GitOps tools.
"""

import os
import json
import yaml
import subprocess
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
import requests
import logging

logger = logging.getLogger(__name__)


@dataclass
class ArgoApplication:
    """Represents an ArgoCD Application resource."""
    name: str
    project: str
    repo_url: str
    path: str
    target_revision: str = "HEAD"
    destination_server: str = "https://kubernetes.default.svc"
    destination_namespace: str = "default"
    sync_policy: dict = None
    helm_values: dict = None
    kustomize_images: list = None

    def to_manifest(self) -> dict:
        """Generate ArgoCD Application manifest."""
        manifest = {
            "apiVersion": "argoproj.io/v1alpha1",
            "kind": "Application",
            "metadata": {
                "name": self.name,
                "namespace": "argocd"
            },
            "spec": {
                "project": self.project,
                "source": {
                    "repoURL": self.repo_url,
                    "path": self.path,
                    "targetRevision": self.target_revision
                },
                "destination": {
                    "server": self.destination_server,
                    "namespace": self.destination_namespace
                }
            }
        }

        # Add Helm values if specified
        if self.helm_values:
            manifest["spec"]["source"]["helm"] = {
                "values": yaml.dump(self.helm_values)
            }

        # Add Kustomize images if specified
        if self.kustomize_images:
            manifest["spec"]["source"]["kustomize"] = {
                "images": self.kustomize_images
            }

        # Add sync policy
        if self.sync_policy:
            manifest["spec"]["syncPolicy"] = self.sync_policy
        else:
            # Default sync policy with auto-sync and self-heal
            manifest["spec"]["syncPolicy"] = {
                "automated": {
                    "prune": True,
                    "selfHeal": True
                },
                "syncOptions": [
                    "CreateNamespace=true"
                ]
            }

        return manifest


class ArgoCDClient:
    """
    ArgoCD API client for GitOps operations.

    Provides programmatic access to ArgoCD for:
    - Application management
    - Sync operations
    - Health monitoring
    - Rollback operations
    """

    def __init__(self, server_url: str, auth_token: str = None):
        self.server_url = server_url.rstrip("/")
        self.auth_token = auth_token or os.environ.get("ARGOCD_TOKEN")
        self.session = requests.Session()

        if self.auth_token:
            self.session.headers["Authorization"] = f"Bearer {self.auth_token}"

    def _request(self, method: str, endpoint: str, **kwargs) -> dict:
        """Make an API request to ArgoCD."""
        url = f"{self.server_url}/api/v1/{endpoint}"

        response = self.session.request(method, url, **kwargs)
        response.raise_for_status()

        return response.json() if response.content else {}

    # Application Management
    def list_applications(self, project: str = None) -> List[dict]:
        """List all ArgoCD applications."""
        params = {}
        if project:
            params["project"] = project

        result = self._request("GET", "applications", params=params)
        return result.get("items", [])

    def get_application(self, name: str) -> dict:
        """Get application details."""
        return self._request("GET", f"applications/{name}")

    def create_application(self, app: ArgoApplication) -> dict:
        """Create a new ArgoCD application."""
        manifest = app.to_manifest()
        return self._request("POST", "applications", json=manifest)

    def update_application(self, app: ArgoApplication) -> dict:
        """Update an existing application."""
        manifest = app.to_manifest()
        return self._request("PUT", f"applications/{app.name}", json=manifest)

    def delete_application(self, name: str, cascade: bool = True) -> dict:
        """Delete an application."""
        params = {"cascade": str(cascade).lower()}
        return self._request("DELETE", f"applications/{name}", params=params)

    # Sync Operations
    def sync_application(self, name: str,
                         revision: str = None,
                         prune: bool = True,
                         dry_run: bool = False) -> dict:
        """Trigger a sync operation."""
        body = {
            "prune": prune,
            "dryRun": dry_run
        }

        if revision:
            body["revision"] = revision

        return self._request("POST", f"applications/{name}/sync", json=body)

    def get_sync_status(self, name: str) -> dict:
        """Get application sync status."""
        app = self.get_application(name)
        return {
            "sync_status": app.get("status", {}).get("sync", {}),
            "health_status": app.get("status", {}).get("health", {}),
            "operation_state": app.get("status", {}).get("operationState", {})
        }

    def wait_for_sync(self, name: str, timeout: int = 300) -> bool:
        """Wait for application sync to complete."""
        import time

        start_time = time.time()

        while time.time() - start_time < timeout:
            status = self.get_sync_status(name)

            sync_status = status["sync_status"].get("status")
            health_status = status["health_status"].get("status")

            if sync_status == "Synced" and health_status == "Healthy":
                return True

            if status["operation_state"].get("phase") == "Failed":
                raise RuntimeError(f"Sync failed: {status['operation_state'].get('message')}")

            time.sleep(5)

        raise TimeoutError(f"Sync timed out after {timeout}s")

    # Rollback Operations
    def rollback_application(self, name: str, revision_id: int) -> dict:
        """Rollback to a previous revision."""
        body = {"id": revision_id}
        return self._request("POST", f"applications/{name}/rollback", json=body)

    def get_application_history(self, name: str) -> List[dict]:
        """Get application revision history."""
        app = self.get_application(name)
        return app.get("status", {}).get("history", [])

    # Resource Management
    def get_resources(self, name: str) -> List[dict]:
        """Get application resources."""
        result = self._request("GET", f"applications/{name}/resource-tree")
        return result.get("nodes", [])

    def get_resource_logs(self, name: str, namespace: str,
                          resource_name: str, container: str = None) -> str:
        """Get logs from a pod resource."""
        params = {
            "namespace": namespace,
            "name": resource_name,
            "kind": "Pod"
        }

        if container:
            params["container"] = container

        result = self._request("GET", f"applications/{name}/logs", params=params)
        return result.get("logs", "")


class GitOpsManager:
    """
    GitOps workflow manager for ArgoCD.

    Manages:
    - Application definitions
    - Environment promotion
    - Rollback strategies
    - Multi-cluster deployments
    """

    def __init__(self, argocd_client: ArgoCDClient, repo_path: str):
        self.argocd = argocd_client
        self.repo_path = Path(repo_path)

    def generate_application_set(self, name: str, environments: List[str],
                                 repo_url: str, base_path: str) -> dict:
        """
        Generate an ArgoCD ApplicationSet for multi-environment deployment.

        ApplicationSets automatically generate Applications for each environment.
        """
        return {
            "apiVersion": "argoproj.io/v1alpha1",
            "kind": "ApplicationSet",
            "metadata": {
                "name": name,
                "namespace": "argocd"
            },
            "spec": {
                "generators": [
                    {
                        "list": {
                            "elements": [
                                {"env": env, "cluster": f"https://{env}.cluster.local"}
                                for env in environments
                            ]
                        }
                    }
                ],
                "template": {
                    "metadata": {
                        "name": f"{name}-{{{{env}}}}"
                    },
                    "spec": {
                        "project": "default",
                        "source": {
                            "repoURL": repo_url,
                            "path": f"{base_path}/{{{{env}}}}",
                            "targetRevision": "HEAD"
                        },
                        "destination": {
                            "server": "{{cluster}}",
                            "namespace": name
                        },
                        "syncPolicy": {
                            "automated": {
                                "prune": True,
                                "selfHeal": True
                            }
                        }
                    }
                }
            }
        }

    def promote_environment(self, app_name: str,
                           source_env: str,
                           target_env: str) -> dict:
        """
        Promote an application from one environment to another.

        This copies the configuration from source to target environment.
        """
        source_path = self.repo_path / source_env / app_name
        target_path = self.repo_path / target_env / app_name

        if not source_path.exists():
            raise FileNotFoundError(f"Source path not found: {source_path}")

        # Copy configuration
        import shutil
        if target_path.exists():
            shutil.rmtree(target_path)
        shutil.copytree(source_path, target_path)

        # Update environment-specific values
        values_file = target_path / "values.yaml"
        if values_file.exists():
            with open(values_file) as f:
                values = yaml.safe_load(f)

            values["environment"] = target_env

            with open(values_file, "w") as f:
                yaml.dump(values, f)

        # Git commit and push
        self._git_commit(f"Promote {app_name} from {source_env} to {target_env}")

        return {
            "status": "promoted",
            "source": source_env,
            "target": target_env,
            "application": app_name
        }

    def _git_commit(self, message: str):
        """Commit and push changes."""
        subprocess.run(["git", "add", "."], cwd=self.repo_path, check=True)
        subprocess.run(["git", "commit", "-m", message], cwd=self.repo_path, check=True)
        subprocess.run(["git", "push"], cwd=self.repo_path, check=True)

    def create_progressive_rollout(self, app_name: str,
                                   new_image: str,
                                   strategy: str = "canary") -> dict:
        """
        Create a progressive rollout configuration.

        Supports canary and blue-green deployment strategies.
        """
        if strategy == "canary":
            rollout = {
                "apiVersion": "argoproj.io/v1alpha1",
                "kind": "Rollout",
                "metadata": {"name": app_name},
                "spec": {
                    "replicas": 5,
                    "strategy": {
                        "canary": {
                            "steps": [
                                {"setWeight": 20},
                                {"pause": {"duration": "5m"}},
                                {"setWeight": 40},
                                {"pause": {"duration": "5m"}},
                                {"setWeight": 60},
                                {"pause": {"duration": "5m"}},
                                {"setWeight": 80},
                                {"pause": {"duration": "5m"}}
                            ],
                            "trafficRouting": {
                                "istio": {
                                    "virtualService": {
                                        "name": app_name,
                                        "routes": ["primary"]
                                    }
                                }
                            }
                        }
                    },
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": app_name, "image": new_image}
                            ]
                        }
                    }
                }
            }
        else:  # blue-green
            rollout = {
                "apiVersion": "argoproj.io/v1alpha1",
                "kind": "Rollout",
                "metadata": {"name": app_name},
                "spec": {
                    "replicas": 5,
                    "strategy": {
                        "blueGreen": {
                            "activeService": f"{app_name}-active",
                            "previewService": f"{app_name}-preview",
                            "autoPromotionEnabled": False,
                            "prePromotionAnalysis": {
                                "templates": [
                                    {"templateName": "success-rate"}
                                ]
                            }
                        }
                    }
                }
            }

        return rollout


# Example: Complete GitOps Workflow
def gitops_deployment_workflow():
    """Demonstrate a complete GitOps deployment workflow."""
    print("=" * 60)
    print("GitOps Deployment Workflow with ArgoCD")
    print("=" * 60)

    # Initialize ArgoCD client
    # argocd = ArgoCDClient(
    #     server_url="https://argocd.example.com",
    #     auth_token=os.environ.get("ARGOCD_TOKEN")
    # )

    # Define application
    app = ArgoApplication(
        name="my-microservice",
        project="default",
        repo_url="https://github.com/org/gitops-repo.git",
        path="applications/my-microservice/production",
        destination_namespace="production",
        sync_policy={
            "automated": {"prune": True, "selfHeal": True},
            "syncOptions": ["CreateNamespace=true"]
        },
        helm_values={
            "replicaCount": 3,
            "image": {
                "repository": "myregistry/my-microservice",
                "tag": "v1.2.3"
            },
            "resources": {
                "requests": {"cpu": "100m", "memory": "128Mi"},
                "limits": {"cpu": "500m", "memory": "512Mi"}
            }
        }
    )

    print(f"\nApplication Manifest:")
    print(yaml.dump(app.to_manifest(), default_flow_style=False))

    print("\nGitOps Workflow Steps:")
    print("1. Developer pushes code changes")
    print("2. CI pipeline builds and tests")
    print("3. CI updates image tag in GitOps repo")
    print("4. ArgoCD detects changes")
    print("5. ArgoCD syncs cluster to desired state")
    print("6. Monitoring validates deployment")

    return app


if __name__ == "__main__":
    gitops_deployment_workflow()
```

---

### 16.2 Service Mesh with Istio

```python
"""
Service Mesh: Traffic Management and Observability

Istio provides a service mesh that adds traffic management, security,
and observability to microservices without code changes.
"""

import yaml
import json
from typing import Dict, List, Optional
from dataclasses import dataclass, field
from enum import Enum


class LoadBalancerType(Enum):
    """Load balancer algorithms."""
    ROUND_ROBIN = "ROUND_ROBIN"
    LEAST_CONN = "LEAST_CONN"
    RANDOM = "RANDOM"
    PASSTHROUGH = "PASSTHROUGH"


@dataclass
class TrafficPolicy:
    """Traffic policy configuration."""
    connection_pool_size: int = 100
    max_requests_per_connection: int = 10
    connect_timeout: str = "10s"
    http2_max_requests: int = 1000
    outlier_detection: dict = None

    def to_dict(self) -> dict:
        policy = {
            "connectionPool": {
                "tcp": {"maxConnections": self.connection_pool_size},
                "http": {
                    "h2UpgradePolicy": "UPGRADE",
                    "http1MaxPendingRequests": self.max_requests_per_connection,
                    "http2MaxRequests": self.http2_max_requests
                }
            }
        }

        if self.outlier_detection:
            policy["outlierDetection"] = self.outlier_detection

        return policy


class IstioResourceGenerator:
    """
    Generate Istio resources for service mesh configuration.

    Creates:
    - VirtualService: Traffic routing rules
    - DestinationRule: Traffic policies
    - Gateway: Ingress configuration
    - ServiceEntry: External service access
    """

    def create_virtual_service(self, name: str, host: str,
                               routes: List[dict],
                               gateways: List[str] = None) -> dict:
        """
        Create an Istio VirtualService.

        VirtualServices define traffic routing rules.
        """
        vs = {
            "apiVersion": "networking.istio.io/v1beta1",
            "kind": "VirtualService",
            "metadata": {"name": name},
            "spec": {
                "hosts": [host],
                "http": routes
            }
        }

        if gateways:
            vs["spec"]["gateways"] = gateways

        return vs

    def create_canary_routing(self, name: str, host: str,
                              stable_version: str,
                              canary_version: str,
                              canary_weight: int = 10) -> dict:
        """Create canary deployment routing."""
        routes = [
            {
                "match": [{"headers": {"x-canary": {"exact": "true"}}}],
                "route": [
                    {
                        "destination": {
                            "host": host,
                            "subset": canary_version
                        }
                    }
                ]
            },
            {
                "route": [
                    {
                        "destination": {
                            "host": host,
                            "subset": stable_version
                        },
                        "weight": 100 - canary_weight
                    },
                    {
                        "destination": {
                            "host": host,
                            "subset": canary_version
                        },
                        "weight": canary_weight
                    }
                ]
            }
        ]

        return self.create_virtual_service(name, host, routes)

    def create_ab_testing(self, name: str, host: str,
                          version_a: str, version_b: str,
                          header_match: dict) -> dict:
        """Create A/B testing routing based on headers."""
        routes = [
            {
                "match": [{"headers": header_match}],
                "route": [
                    {"destination": {"host": host, "subset": version_b}}
                ]
            },
            {
                "route": [
                    {"destination": {"host": host, "subset": version_a}}
                ]
            }
        ]

        return self.create_virtual_service(name, host, routes)

    def create_destination_rule(self, name: str, host: str,
                                subsets: List[dict],
                                traffic_policy: TrafficPolicy = None) -> dict:
        """
        Create an Istio DestinationRule.

        DestinationRules define policies applied after routing.
        """
        dr = {
            "apiVersion": "networking.istio.io/v1beta1",
            "kind": "DestinationRule",
            "metadata": {"name": name},
            "spec": {
                "host": host,
                "subsets": subsets
            }
        }

        if traffic_policy:
            dr["spec"]["trafficPolicy"] = traffic_policy.to_dict()

        # Add circuit breaker
        dr["spec"]["trafficPolicy"] = dr["spec"].get("trafficPolicy", {})
        dr["spec"]["trafficPolicy"]["outlierDetection"] = {
            "consecutive5xxErrors": 5,
            "interval": "30s",
            "baseEjectionTime": "30s",
            "maxEjectionPercent": 50
        }

        return dr

    def create_gateway(self, name: str, hosts: List[str],
                       port: int = 443, protocol: str = "HTTPS",
                       tls_mode: str = "SIMPLE",
                       credential_name: str = None) -> dict:
        """Create an Istio Gateway for ingress traffic."""
        gateway = {
            "apiVersion": "networking.istio.io/v1beta1",
            "kind": "Gateway",
            "metadata": {"name": name},
            "spec": {
                "selector": {"istio": "ingressgateway"},
                "servers": [
                    {
                        "port": {
                            "number": port,
                            "name": protocol.lower(),
                            "protocol": protocol
                        },
                        "hosts": hosts
                    }
                ]
            }
        }

        if protocol == "HTTPS" and credential_name:
            gateway["spec"]["servers"][0]["tls"] = {
                "mode": tls_mode,
                "credentialName": credential_name
            }

        return gateway

    def create_retry_policy(self, attempts: int = 3,
                           per_try_timeout: str = "2s",
                           retry_on: str = "5xx,reset,connect-failure") -> dict:
        """Create a retry policy configuration."""
        return {
            "attempts": attempts,
            "perTryTimeout": per_try_timeout,
            "retryOn": retry_on
        }

    def create_timeout_policy(self, timeout: str = "30s") -> dict:
        """Create a timeout policy."""
        return {"timeout": timeout}

    def create_fault_injection(self, delay_percent: int = None,
                              delay_duration: str = None,
                              abort_percent: int = None,
                              abort_code: int = None) -> dict:
        """Create fault injection for testing."""
        fault = {}

        if delay_percent and delay_duration:
            fault["delay"] = {
                "percentage": {"value": delay_percent},
                "fixedDelay": delay_duration
            }

        if abort_percent and abort_code:
            fault["abort"] = {
                "percentage": {"value": abort_percent},
                "httpStatus": abort_code
            }

        return fault

    def create_rate_limit(self, name: str, host: str,
                          requests_per_second: int) -> dict:
        """Create rate limiting configuration using EnvoyFilter."""
        return {
            "apiVersion": "networking.istio.io/v1alpha3",
            "kind": "EnvoyFilter",
            "metadata": {"name": f"{name}-ratelimit"},
            "spec": {
                "workloadSelector": {"labels": {"app": name}},
                "configPatches": [
                    {
                        "applyTo": "HTTP_FILTER",
                        "match": {
                            "context": "SIDECAR_INBOUND",
                            "listener": {"filterChain": {"filter": {"name": "envoy.filters.network.http_connection_manager"}}}
                        },
                        "patch": {
                            "operation": "INSERT_BEFORE",
                            "value": {
                                "name": "envoy.filters.http.local_ratelimit",
                                "typed_config": {
                                    "@type": "type.googleapis.com/udpa.type.v1.TypedStruct",
                                    "type_url": "type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit",
                                    "value": {
                                        "stat_prefix": "http_local_rate_limiter",
                                        "token_bucket": {
                                            "max_tokens": requests_per_second,
                                            "tokens_per_fill": requests_per_second,
                                            "fill_interval": "1s"
                                        }
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        }


class ServiceMeshManager:
    """
    Manage service mesh configurations.

    Provides high-level operations for:
    - Traffic management
    - Security policies
    - Observability configuration
    """

    def __init__(self):
        self.generator = IstioResourceGenerator()
        self.resources = []

    def configure_service(self, name: str, host: str,
                          versions: List[str],
                          canary_percentage: int = 0) -> List[dict]:
        """Configure a service with traffic policies."""
        resources = []

        # Create subsets for each version
        subsets = [
            {"name": v, "labels": {"version": v}}
            for v in versions
        ]

        # DestinationRule with circuit breaker
        dr = self.generator.create_destination_rule(
            name=f"{name}-destination",
            host=host,
            subsets=subsets,
            traffic_policy=TrafficPolicy(
                connection_pool_size=100,
                outlier_detection={
                    "consecutive5xxErrors": 5,
                    "interval": "10s",
                    "baseEjectionTime": "30s"
                }
            )
        )
        resources.append(dr)

        # VirtualService with routing
        if canary_percentage > 0 and len(versions) >= 2:
            vs = self.generator.create_canary_routing(
                name=f"{name}-vs",
                host=host,
                stable_version=versions[0],
                canary_version=versions[1],
                canary_weight=canary_percentage
            )
        else:
            routes = [
                {
                    "route": [{"destination": {"host": host, "subset": versions[0]}}],
                    "retries": self.generator.create_retry_policy(),
                    "timeout": "30s"
                }
            ]
            vs = self.generator.create_virtual_service(f"{name}-vs", host, routes)

        resources.append(vs)
        self.resources.extend(resources)

        return resources

    def enable_mtls(self, namespace: str = "default") -> dict:
        """Enable mutual TLS for a namespace."""
        return {
            "apiVersion": "security.istio.io/v1beta1",
            "kind": "PeerAuthentication",
            "metadata": {
                "name": "default",
                "namespace": namespace
            },
            "spec": {
                "mtls": {"mode": "STRICT"}
            }
        }

    def create_authorization_policy(self, name: str,
                                    allowed_sources: List[str],
                                    allowed_methods: List[str] = None) -> dict:
        """Create an authorization policy for access control."""
        policy = {
            "apiVersion": "security.istio.io/v1beta1",
            "kind": "AuthorizationPolicy",
            "metadata": {"name": name},
            "spec": {
                "selector": {"matchLabels": {"app": name}},
                "rules": [
                    {
                        "from": [
                            {"source": {"principals": allowed_sources}}
                        ]
                    }
                ]
            }
        }

        if allowed_methods:
            policy["spec"]["rules"][0]["to"] = [
                {"operation": {"methods": allowed_methods}}
            ]

        return policy

    def generate_manifests(self) -> str:
        """Generate YAML manifests for all resources."""
        return yaml.dump_all(self.resources, default_flow_style=False)


# Example usage
if __name__ == "__main__":
    manager = ServiceMeshManager()

    # Configure a service with canary deployment
    resources = manager.configure_service(
        name="payment-service",
        host="payment.default.svc.cluster.local",
        versions=["v1", "v2"],
        canary_percentage=10
    )

    print("Generated Istio Resources:")
    print("=" * 50)
    for r in resources:
        print(yaml.dump(r, default_flow_style=False))
        print("---")
```

---

### 16.3 Chaos Engineering

```python
"""
Chaos Engineering: Building Resilient Systems

Chaos Engineering is the discipline of experimenting on a system
to build confidence in its capability to withstand turbulent conditions.
"""

import os
import json
import random
import time
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
import logging
import subprocess

logger = logging.getLogger(__name__)


class ChaosExperimentType(Enum):
    """Types of chaos experiments."""
    POD_FAILURE = "pod-failure"
    NETWORK_LATENCY = "network-latency"
    NETWORK_PARTITION = "network-partition"
    CPU_STRESS = "cpu-stress"
    MEMORY_STRESS = "memory-stress"
    DISK_STRESS = "disk-stress"
    HTTP_ABORT = "http-abort"
    DNS_FAILURE = "dns-failure"


@dataclass
class ChaosExperiment:
    """Represents a chaos experiment configuration."""
    name: str
    type: ChaosExperimentType
    target_selector: dict
    duration: str
    parameters: dict = field(default_factory=dict)
    steady_state_hypothesis: dict = None
    rollback_on_failure: bool = True

    def to_chaos_mesh_spec(self) -> dict:
        """Convert to Chaos Mesh specification."""
        type_mapping = {
            ChaosExperimentType.POD_FAILURE: "PodChaos",
            ChaosExperimentType.NETWORK_LATENCY: "NetworkChaos",
            ChaosExperimentType.NETWORK_PARTITION: "NetworkChaos",
            ChaosExperimentType.CPU_STRESS: "StressChaos",
            ChaosExperimentType.MEMORY_STRESS: "StressChaos",
        }

        kind = type_mapping.get(self.type, "PodChaos")

        spec = {
            "apiVersion": "chaos-mesh.org/v1alpha1",
            "kind": kind,
            "metadata": {"name": self.name},
            "spec": {
                "selector": self.target_selector,
                "duration": self.duration
            }
        }

        # Add type-specific configuration
        if self.type == ChaosExperimentType.POD_FAILURE:
            spec["spec"]["action"] = "pod-kill"
            spec["spec"]["mode"] = self.parameters.get("mode", "one")

        elif self.type == ChaosExperimentType.NETWORK_LATENCY:
            spec["spec"]["action"] = "delay"
            spec["spec"]["delay"] = {
                "latency": self.parameters.get("latency", "100ms"),
                "correlation": self.parameters.get("correlation", "25"),
                "jitter": self.parameters.get("jitter", "10ms")
            }

        elif self.type == ChaosExperimentType.NETWORK_PARTITION:
            spec["spec"]["action"] = "partition"
            spec["spec"]["direction"] = self.parameters.get("direction", "both")

        elif self.type == ChaosExperimentType.CPU_STRESS:
            spec["spec"]["stressors"] = {
                "cpu": {
                    "workers": self.parameters.get("workers", 1),
                    "load": self.parameters.get("load", 100)
                }
            }

        elif self.type == ChaosExperimentType.MEMORY_STRESS:
            spec["spec"]["stressors"] = {
                "memory": {
                    "workers": self.parameters.get("workers", 1),
                    "size": self.parameters.get("size", "256MB")
                }
            }

        return spec

    def to_litmus_spec(self) -> dict:
        """Convert to LitmusChaos specification."""
        return {
            "apiVersion": "litmuschaos.io/v1alpha1",
            "kind": "ChaosEngine",
            "metadata": {"name": f"{self.name}-engine"},
            "spec": {
                "appinfo": {
                    "appns": self.target_selector.get("namespaces", ["default"])[0],
                    "applabel": self._format_labels(self.target_selector.get("labelSelectors", {})),
                    "appkind": "deployment"
                },
                "engineState": "active",
                "chaosServiceAccount": "litmus-admin",
                "experiments": [
                    {
                        "name": self._get_litmus_experiment_name(),
                        "spec": {
                            "components": {
                                "env": self._get_litmus_env_vars()
                            }
                        }
                    }
                ]
            }
        }

    def _format_labels(self, labels: dict) -> str:
        """Format labels for Litmus."""
        return ",".join(f"{k}={v}" for k, v in labels.items())

    def _get_litmus_experiment_name(self) -> str:
        """Get corresponding Litmus experiment name."""
        mapping = {
            ChaosExperimentType.POD_FAILURE: "pod-delete",
            ChaosExperimentType.CPU_STRESS: "pod-cpu-hog",
            ChaosExperimentType.MEMORY_STRESS: "pod-memory-hog",
            ChaosExperimentType.NETWORK_LATENCY: "pod-network-latency",
        }
        return mapping.get(self.type, "pod-delete")

    def _get_litmus_env_vars(self) -> list:
        """Get environment variables for Litmus experiment."""
        env_vars = [
            {"name": "TOTAL_CHAOS_DURATION", "value": self._parse_duration(self.duration)}
        ]

        if self.type == ChaosExperimentType.CPU_STRESS:
            env_vars.append({"name": "CPU_CORES", "value": str(self.parameters.get("workers", 1))})

        if self.type == ChaosExperimentType.MEMORY_STRESS:
            env_vars.append({"name": "MEMORY_CONSUMPTION", "value": self.parameters.get("size", "500")})

        if self.type == ChaosExperimentType.NETWORK_LATENCY:
            env_vars.append({"name": "NETWORK_LATENCY", "value": self.parameters.get("latency", "2000")})

        return env_vars

    def _parse_duration(self, duration: str) -> str:
        """Parse duration string to seconds."""
        if duration.endswith("s"):
            return duration[:-1]
        if duration.endswith("m"):
            return str(int(duration[:-1]) * 60)
        if duration.endswith("h"):
            return str(int(duration[:-1]) * 3600)
        return duration


class ChaosOrchestrator:
    """
    Orchestrate chaos experiments with proper controls.

    Features:
    - Steady state validation
    - Automatic rollback
    - Observability integration
    - Blast radius control
    """

    def __init__(self, kubeconfig: str = None):
        self.kubeconfig = kubeconfig
        self.active_experiments = []
        self.experiment_history = []

    def run_experiment(self, experiment: ChaosExperiment,
                       validation_func: Callable[[], bool] = None,
                       dry_run: bool = False) -> Dict:
        """
        Run a chaos experiment with proper safety controls.

        Steps:
        1. Validate steady state (pre-check)
        2. Inject chaos
        3. Observe system behavior
        4. Validate steady state (post-check)
        5. Rollback if needed
        """
        result = {
            "experiment": experiment.name,
            "type": experiment.type.value,
            "start_time": datetime.utcnow().isoformat(),
            "status": "pending",
            "steady_state_before": None,
            "steady_state_after": None,
            "findings": []
        }

        logger.info(f"Starting chaos experiment: {experiment.name}")

        try:
            # Step 1: Validate steady state before
            if validation_func:
                logger.info("Validating steady state before experiment...")
                result["steady_state_before"] = validation_func()

                if not result["steady_state_before"]:
                    result["status"] = "aborted"
                    result["findings"].append("System not in steady state before experiment")
                    return result

            # Step 2: Inject chaos
            if not dry_run:
                logger.info(f"Injecting chaos: {experiment.type.value}")
                self._apply_chaos(experiment)
                self.active_experiments.append(experiment)

                # Wait for experiment duration
                duration_seconds = self._parse_duration_seconds(experiment.duration)
                logger.info(f"Chaos active for {duration_seconds}s...")

                # Monitor during chaos
                for i in range(0, duration_seconds, 10):
                    time.sleep(min(10, duration_seconds - i))

                    # Check if we should abort
                    if validation_func:
                        current_state = validation_func()
                        if not current_state and experiment.rollback_on_failure:
                            logger.warning("System degraded beyond threshold, rolling back")
                            self._rollback_chaos(experiment)
                            result["status"] = "rolled_back"
                            result["findings"].append(f"Rolled back at {i}s due to system degradation")
                            return result

            # Step 3: Cleanup chaos
            if not dry_run:
                self._rollback_chaos(experiment)
                self.active_experiments.remove(experiment)

            # Step 4: Validate steady state after
            if validation_func:
                logger.info("Validating steady state after experiment...")
                time.sleep(30)  # Allow system to recover
                result["steady_state_after"] = validation_func()

            result["status"] = "completed"
            result["end_time"] = datetime.utcnow().isoformat()

            # Analyze results
            if result["steady_state_before"] and result["steady_state_after"]:
                result["findings"].append("System recovered successfully")
            elif result["steady_state_before"] and not result["steady_state_after"]:
                result["findings"].append("System did not recover - resilience issue detected")

        except Exception as e:
            logger.error(f"Experiment failed: {e}")
            result["status"] = "failed"
            result["error"] = str(e)

            # Rollback on failure
            if experiment in self.active_experiments:
                self._rollback_chaos(experiment)
                self.active_experiments.remove(experiment)

        self.experiment_history.append(result)
        return result

    def _apply_chaos(self, experiment: ChaosExperiment):
        """Apply chaos to the cluster."""
        spec = experiment.to_chaos_mesh_spec()

        # Apply using kubectl
        import yaml
        manifest = yaml.dump(spec)

        cmd = ["kubectl", "apply", "-f", "-"]
        if self.kubeconfig:
            cmd.extend(["--kubeconfig", self.kubeconfig])

        proc = subprocess.run(cmd, input=manifest, text=True, capture_output=True)

        if proc.returncode != 0:
            raise RuntimeError(f"Failed to apply chaos: {proc.stderr}")

    def _rollback_chaos(self, experiment: ChaosExperiment):
        """Remove chaos from the cluster."""
        spec = experiment.to_chaos_mesh_spec()

        import yaml
        manifest = yaml.dump(spec)

        cmd = ["kubectl", "delete", "-f", "-"]
        if self.kubeconfig:
            cmd.extend(["--kubeconfig", self.kubeconfig])

        subprocess.run(cmd, input=manifest, text=True, capture_output=True)

    def _parse_duration_seconds(self, duration: str) -> int:
        """Parse duration string to seconds."""
        if duration.endswith("s"):
            return int(duration[:-1])
        if duration.endswith("m"):
            return int(duration[:-1]) * 60
        if duration.endswith("h"):
            return int(duration[:-1]) * 3600
        return int(duration)

    def generate_report(self) -> Dict:
        """Generate chaos experiment report."""
        successful = sum(1 for e in self.experiment_history if e["status"] == "completed")
        failed = sum(1 for e in self.experiment_history if e["status"] == "failed")
        rolled_back = sum(1 for e in self.experiment_history if e["status"] == "rolled_back")

        return {
            "summary": {
                "total_experiments": len(self.experiment_history),
                "successful": successful,
                "failed": failed,
                "rolled_back": rolled_back
            },
            "experiments": self.experiment_history,
            "recommendations": self._generate_recommendations()
        }

    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on experiment results."""
        recommendations = []

        for exp in self.experiment_history:
            if exp["status"] == "rolled_back":
                recommendations.append(
                    f"Improve resilience for {exp['type']} scenarios - "
                    f"experiment {exp['experiment']} caused system degradation"
                )

            if not exp.get("steady_state_after"):
                recommendations.append(
                    f"System did not recover from {exp['type']} - "
                    f"consider adding circuit breakers or retries"
                )

        return recommendations


# Example: Run chaos experiments
def run_chaos_gameday():
    """Run a chaos engineering game day."""
    print("=" * 60)
    print("Chaos Engineering Game Day")
    print("=" * 60)

    orchestrator = ChaosOrchestrator()

    # Define experiments
    experiments = [
        ChaosExperiment(
            name="payment-pod-failure",
            type=ChaosExperimentType.POD_FAILURE,
            target_selector={
                "namespaces": ["production"],
                "labelSelectors": {"app": "payment-service"}
            },
            duration="2m",
            parameters={"mode": "one"}
        ),
        ChaosExperiment(
            name="network-latency-test",
            type=ChaosExperimentType.NETWORK_LATENCY,
            target_selector={
                "namespaces": ["production"],
                "labelSelectors": {"app": "api-gateway"}
            },
            duration="5m",
            parameters={
                "latency": "500ms",
                "jitter": "100ms"
            }
        ),
        ChaosExperiment(
            name="cpu-stress-test",
            type=ChaosExperimentType.CPU_STRESS,
            target_selector={
                "namespaces": ["production"],
                "labelSelectors": {"app": "order-service"}
            },
            duration="3m",
            parameters={
                "workers": 2,
                "load": 80
            }
        )
    ]

    print("\nPlanned Experiments:")
    for exp in experiments:
        print(f"  - {exp.name}: {exp.type.value} for {exp.duration}")

    # Generate Chaos Mesh manifests
    print("\nGenerated Chaos Mesh Manifests:")
    import yaml
    for exp in experiments:
        print(f"\n# {exp.name}")
        print(yaml.dump(exp.to_chaos_mesh_spec(), default_flow_style=False))

    return experiments


if __name__ == "__main__":
    run_chaos_gameday()
```

---

### 16.4 FinOps & Cost Optimization

```python
"""
FinOps: Cloud Financial Management

FinOps is the practice of bringing financial accountability to cloud spending.
Python tools help automate cost analysis, optimization, and governance.
"""

import os
import json
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from decimal import Decimal
from collections import defaultdict
import boto3
import logging

logger = logging.getLogger(__name__)


@dataclass
class CostRecord:
    """Represents a cost record from cloud billing."""
    service: str
    resource_id: str
    resource_type: str
    cost: Decimal
    usage_quantity: float
    usage_unit: str
    start_time: datetime
    end_time: datetime
    tags: Dict[str, str] = field(default_factory=dict)
    region: str = None
    account_id: str = None


@dataclass
class CostAnomaly:
    """Represents a cost anomaly detection result."""
    resource_id: str
    service: str
    expected_cost: Decimal
    actual_cost: Decimal
    deviation_percent: float
    detected_at: datetime
    severity: str  # low, medium, high, critical


class AWSCostAnalyzer:
    """
    AWS Cost and Usage analyzer.

    Provides:
    - Cost breakdown by service, tag, region
    - Trend analysis
    - Anomaly detection
    - Savings recommendations
    """

    def __init__(self, profile_name: str = None):
        session = boto3.Session(profile_name=profile_name)
        self.ce_client = session.client("ce")  # Cost Explorer
        self.organizations = session.client("organizations")

    def get_cost_and_usage(self, start_date: str, end_date: str,
                           granularity: str = "DAILY",
                           group_by: List[str] = None) -> Dict:
        """
        Get cost and usage data from AWS Cost Explorer.

        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            granularity: DAILY, MONTHLY, or HOURLY
            group_by: Dimensions to group by (SERVICE, REGION, etc.)
        """
        kwargs = {
            "TimePeriod": {"Start": start_date, "End": end_date},
            "Granularity": granularity,
            "Metrics": ["BlendedCost", "UnblendedCost", "UsageQuantity"]
        }

        if group_by:
            kwargs["GroupBy"] = [
                {"Type": "DIMENSION", "Key": dim}
                for dim in group_by
            ]

        response = self.ce_client.get_cost_and_usage(**kwargs)
        return self._parse_cost_response(response)

    def _parse_cost_response(self, response: Dict) -> Dict:
        """Parse Cost Explorer response into structured format."""
        results = []

        for result in response.get("ResultsByTime", []):
            period_start = result["TimePeriod"]["Start"]
            period_end = result["TimePeriod"]["End"]

            if "Groups" in result:
                for group in result["Groups"]:
                    results.append({
                        "start": period_start,
                        "end": period_end,
                        "dimensions": group["Keys"],
                        "cost": Decimal(group["Metrics"]["BlendedCost"]["Amount"]),
                        "usage": float(group["Metrics"].get("UsageQuantity", {}).get("Amount", 0))
                    })
            else:
                results.append({
                    "start": period_start,
                    "end": period_end,
                    "cost": Decimal(result["Total"]["BlendedCost"]["Amount"]),
                    "usage": float(result["Total"].get("UsageQuantity", {}).get("Amount", 0))
                })

        return {
            "results": results,
            "total_cost": sum(r["cost"] for r in results),
            "period": {"start": response["ResultsByTime"][0]["TimePeriod"]["Start"],
                      "end": response["ResultsByTime"][-1]["TimePeriod"]["End"]}
        }

    def get_cost_by_service(self, days: int = 30) -> Dict[str, Decimal]:
        """Get costs broken down by service."""
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")

        data = self.get_cost_and_usage(start_date, end_date, "MONTHLY", ["SERVICE"])

        costs_by_service = defaultdict(Decimal)
        for result in data["results"]:
            service = result["dimensions"][0]
            costs_by_service[service] += result["cost"]

        return dict(sorted(costs_by_service.items(), key=lambda x: x[1], reverse=True))

    def get_cost_by_tag(self, tag_key: str, days: int = 30) -> Dict[str, Decimal]:
        """Get costs broken down by a specific tag."""
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")

        response = self.ce_client.get_cost_and_usage(
            TimePeriod={"Start": start_date, "End": end_date},
            Granularity="MONTHLY",
            Metrics=["BlendedCost"],
            GroupBy=[{"Type": "TAG", "Key": tag_key}]
        )

        costs_by_tag = {}
        for result in response.get("ResultsByTime", []):
            for group in result.get("Groups", []):
                tag_value = group["Keys"][0].replace(f"${tag_key}$", "") or "untagged"
                cost = Decimal(group["Metrics"]["BlendedCost"]["Amount"])
                costs_by_tag[tag_value] = costs_by_tag.get(tag_value, Decimal(0)) + cost

        return dict(sorted(costs_by_tag.items(), key=lambda x: x[1], reverse=True))

    def get_savings_recommendations(self) -> List[Dict]:
        """Get AWS Cost Explorer savings recommendations."""
        recommendations = []

        # Reserved Instance recommendations
        try:
            ri_response = self.ce_client.get_reservation_purchase_recommendation(
                Service="Amazon Elastic Compute Cloud - Compute",
                TermInYears="ONE_YEAR",
                PaymentOption="NO_UPFRONT",
                LookbackPeriodInDays="SIXTY_DAYS"
            )

            for rec in ri_response.get("Recommendations", []):
                for detail in rec.get("RecommendationDetails", []):
                    recommendations.append({
                        "type": "reserved_instance",
                        "service": "EC2",
                        "instance_type": detail.get("InstanceDetails", {}).get("EC2InstanceDetails", {}).get("InstanceType"),
                        "estimated_savings": Decimal(detail.get("EstimatedMonthlySavingsAmount", "0")),
                        "estimated_savings_percent": float(detail.get("EstimatedMonthlySavingsPercentage", 0))
                    })
        except Exception as e:
            logger.warning(f"Could not get RI recommendations: {e}")

        # Savings Plans recommendations
        try:
            sp_response = self.ce_client.get_savings_plans_purchase_recommendation(
                SavingsPlansType="COMPUTE_SP",
                TermInYears="ONE_YEAR",
                PaymentOption="NO_UPFRONT",
                LookbackPeriodInDays="SIXTY_DAYS"
            )

            for rec in sp_response.get("SavingsPlansPurchaseRecommendation", {}).get("SavingsPlansPurchaseRecommendationDetails", []):
                recommendations.append({
                    "type": "savings_plan",
                    "commitment": Decimal(rec.get("HourlyCommitmentToPurchase", "0")),
                    "estimated_savings": Decimal(rec.get("EstimatedMonthlySavingsAmount", "0")),
                    "estimated_roi": float(rec.get("EstimatedROI", 0))
                })
        except Exception as e:
            logger.warning(f"Could not get Savings Plans recommendations: {e}")

        return recommendations

    def detect_anomalies(self, days: int = 30,
                         threshold_percent: float = 50.0) -> List[CostAnomaly]:
        """Detect cost anomalies compared to historical average."""
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")

        # Get daily costs by service
        data = self.get_cost_and_usage(start_date, end_date, "DAILY", ["SERVICE"])

        # Calculate averages and detect anomalies
        service_costs = defaultdict(list)
        for result in data["results"]:
            service = result["dimensions"][0]
            service_costs[service].append(result["cost"])

        anomalies = []
        for service, costs in service_costs.items():
            if len(costs) < 7:
                continue

            avg_cost = sum(costs[:-1]) / len(costs[:-1])
            latest_cost = costs[-1]

            if avg_cost > 0:
                deviation = ((latest_cost - avg_cost) / avg_cost) * 100

                if abs(deviation) > threshold_percent:
                    severity = "low"
                    if abs(deviation) > 100:
                        severity = "medium"
                    if abs(deviation) > 200:
                        severity = "high"
                    if abs(deviation) > 500:
                        severity = "critical"

                    anomalies.append(CostAnomaly(
                        resource_id=service,
                        service=service,
                        expected_cost=avg_cost,
                        actual_cost=latest_cost,
                        deviation_percent=float(deviation),
                        detected_at=datetime.now(),
                        severity=severity
                    ))

        return sorted(anomalies, key=lambda x: abs(x.deviation_percent), reverse=True)


class ResourceOptimizer:
    """
    Identify and optimize underutilized resources.

    Analyzes:
    - EC2 instances (CPU, memory utilization)
    - EBS volumes (unused, unattached)
    - RDS instances (utilization)
    - S3 buckets (storage optimization)
    """

    def __init__(self, profile_name: str = None):
        session = boto3.Session(profile_name=profile_name)
        self.ec2 = session.client("ec2")
        self.cloudwatch = session.client("cloudwatch")
        self.rds = session.client("rds")
        self.s3 = session.client("s3")

    def find_idle_ec2_instances(self, cpu_threshold: float = 5.0,
                                 days: int = 14) -> List[Dict]:
        """Find EC2 instances with low CPU utilization."""
        idle_instances = []

        # Get all running instances
        instances = self.ec2.describe_instances(
            Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
        )

        for reservation in instances["Reservations"]:
            for instance in reservation["Instances"]:
                instance_id = instance["InstanceId"]
                instance_type = instance["InstanceType"]

                # Get CPU utilization
                avg_cpu = self._get_average_cpu(instance_id, days)

                if avg_cpu is not None and avg_cpu < cpu_threshold:
                    idle_instances.append({
                        "instance_id": instance_id,
                        "instance_type": instance_type,
                        "average_cpu": avg_cpu,
                        "launch_time": instance["LaunchTime"].isoformat(),
                        "tags": {t["Key"]: t["Value"] for t in instance.get("Tags", [])},
                        "recommendation": self._get_rightsizing_recommendation(instance_type, avg_cpu)
                    })

        return idle_instances

    def _get_average_cpu(self, instance_id: str, days: int) -> Optional[float]:
        """Get average CPU utilization for an instance."""
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=days)

        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace="AWS/EC2",
                MetricName="CPUUtilization",
                Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,
                Statistics=["Average"]
            )

            datapoints = response.get("Datapoints", [])
            if datapoints:
                return sum(d["Average"] for d in datapoints) / len(datapoints)

        except Exception as e:
            logger.warning(f"Could not get CPU metrics for {instance_id}: {e}")

        return None

    def _get_rightsizing_recommendation(self, current_type: str,
                                        avg_cpu: float) -> str:
        """Get rightsizing recommendation based on utilization."""
        # Simplified recommendation logic
        if avg_cpu < 1:
            return "Consider terminating or stopping this instance"
        elif avg_cpu < 5:
            return f"Consider downsizing from {current_type}"
        elif avg_cpu < 20:
            return "Instance appears underutilized, review workload"
        else:
            return "Utilization appears normal"

    def find_unattached_ebs_volumes(self) -> List[Dict]:
        """Find EBS volumes not attached to any instance."""
        unattached = []

        volumes = self.ec2.describe_volumes(
            Filters=[{"Name": "status", "Values": ["available"]}]
        )

        for volume in volumes["Volumes"]:
            unattached.append({
                "volume_id": volume["VolumeId"],
                "size_gb": volume["Size"],
                "volume_type": volume["VolumeType"],
                "create_time": volume["CreateTime"].isoformat(),
                "tags": {t["Key"]: t["Value"] for t in volume.get("Tags", [])},
                "monthly_cost_estimate": self._estimate_ebs_cost(volume["Size"], volume["VolumeType"])
            })

        return unattached

    def _estimate_ebs_cost(self, size_gb: int, volume_type: str) -> Decimal:
        """Estimate monthly cost for EBS volume."""
        # Simplified pricing (actual prices vary by region)
        price_per_gb = {
            "gp2": Decimal("0.10"),
            "gp3": Decimal("0.08"),
            "io1": Decimal("0.125"),
            "io2": Decimal("0.125"),
            "st1": Decimal("0.045"),
            "sc1": Decimal("0.025"),
            "standard": Decimal("0.05")
        }

        return size_gb * price_per_gb.get(volume_type, Decimal("0.10"))


class CostDashboard:
    """Generate cost reports and dashboards."""

    def __init__(self, analyzer: AWSCostAnalyzer, optimizer: ResourceOptimizer):
        self.analyzer = analyzer
        self.optimizer = optimizer

    def generate_report(self, days: int = 30) -> Dict:
        """Generate comprehensive cost report."""
        report = {
            "generated_at": datetime.utcnow().isoformat(),
            "period_days": days,
            "sections": {}
        }

        # Cost by service
        logger.info("Analyzing costs by service...")
        costs_by_service = self.analyzer.get_cost_by_service(days)
        report["sections"]["cost_by_service"] = {
            "data": {k: float(v) for k, v in costs_by_service.items()},
            "total": float(sum(costs_by_service.values()))
        }

        # Anomalies
        logger.info("Detecting anomalies...")
        anomalies = self.analyzer.detect_anomalies(days)
        report["sections"]["anomalies"] = [
            {
                "service": a.service,
                "expected": float(a.expected_cost),
                "actual": float(a.actual_cost),
                "deviation_percent": a.deviation_percent,
                "severity": a.severity
            }
            for a in anomalies
        ]

        # Savings recommendations
        logger.info("Getting savings recommendations...")
        recommendations = self.analyzer.get_savings_recommendations()
        report["sections"]["savings_recommendations"] = [
            {k: float(v) if isinstance(v, Decimal) else v for k, v in rec.items()}
            for rec in recommendations
        ]

        # Optimization opportunities
        logger.info("Finding optimization opportunities...")
        idle_instances = self.optimizer.find_idle_ec2_instances()
        unattached_volumes = self.optimizer.find_unattached_ebs_volumes()

        report["sections"]["optimization"] = {
            "idle_ec2_instances": idle_instances,
            "unattached_ebs_volumes": unattached_volumes,
            "potential_monthly_savings": self._calculate_potential_savings(
                idle_instances, unattached_volumes
            )
        }

        return report

    def _calculate_potential_savings(self, idle_instances: List,
                                     unattached_volumes: List) -> float:
        """Calculate potential monthly savings from optimizations."""
        savings = Decimal(0)

        # EBS savings
        for vol in unattached_volumes:
            savings += vol["monthly_cost_estimate"]

        # Simplified EC2 savings estimate
        # In practice, you'd look up actual instance pricing
        savings += len(idle_instances) * Decimal("20")  # Rough estimate

        return float(savings)

    def print_summary(self, report: Dict):
        """Print a formatted summary of the cost report."""
        print("=" * 60)
        print("CLOUD COST REPORT")
        print(f"Generated: {report['generated_at']}")
        print(f"Period: Last {report['period_days']} days")
        print("=" * 60)

        # Total cost
        total = report["sections"]["cost_by_service"]["total"]
        print(f"\nTotal Cost: ${total:,.2f}")

        # Top services
        print("\nTop 5 Services by Cost:")
        services = report["sections"]["cost_by_service"]["data"]
        for i, (service, cost) in enumerate(list(services.items())[:5], 1):
            print(f"  {i}. {service}: ${cost:,.2f}")

        # Anomalies
        anomalies = report["sections"]["anomalies"]
        if anomalies:
            print(f"\nCost Anomalies Detected: {len(anomalies)}")
            for a in anomalies[:3]:
                print(f"  - {a['service']}: {a['deviation_percent']:+.1f}% ({a['severity']})")

        # Optimization opportunities
        opt = report["sections"]["optimization"]
        print(f"\nOptimization Opportunities:")
        print(f"  - Idle EC2 instances: {len(opt['idle_ec2_instances'])}")
        print(f"  - Unattached EBS volumes: {len(opt['unattached_ebs_volumes'])}")
        print(f"  - Potential monthly savings: ${opt['potential_monthly_savings']:,.2f}")

        print("\n" + "=" * 60)


# Example usage
if __name__ == "__main__":
    print("FinOps Cost Optimization Tools")
    print("=" * 50)
    print("\nExample usage:")
    print("  analyzer = AWSCostAnalyzer()")
    print("  costs = analyzer.get_cost_by_service(days=30)")
    print("  anomalies = analyzer.detect_anomalies()")
    print("  recommendations = analyzer.get_savings_recommendations()")
```

---

### 📝 Phase Lab 16: Platform Engineering Dashboard

**Objective**: Build a unified platform engineering dashboard combining GitOps, service mesh, chaos, and FinOps.

```python
"""
Phase Lab 16: Platform Engineering Dashboard

Build a comprehensive platform dashboard that:
1. Shows GitOps deployment status
2. Displays service mesh health
3. Tracks chaos experiment results
4. Reports cloud costs and optimization opportunities
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Any
import json


@dataclass
class PlatformStatus:
    """Overall platform status."""
    gitops_apps: int = 0
    gitops_healthy: int = 0
    mesh_services: int = 0
    mesh_healthy: int = 0
    chaos_experiments_run: int = 0
    chaos_success_rate: float = 0.0
    monthly_cost: float = 0.0
    cost_trend: float = 0.0
    potential_savings: float = 0.0


class PlatformDashboard:
    """
    Unified Platform Engineering Dashboard.

    Aggregates data from:
    - ArgoCD (GitOps)
    - Istio (Service Mesh)
    - Chaos Mesh/Litmus (Chaos Engineering)
    - AWS Cost Explorer (FinOps)
    """

    def __init__(self):
        self.status = PlatformStatus()
        self.alerts = []
        self.metrics_history = []

    def collect_gitops_metrics(self, argocd_client=None) -> Dict:
        """Collect GitOps metrics from ArgoCD."""
        # Simulated data for demonstration
        return {
            "total_applications": 25,
            "synced": 23,
            "out_of_sync": 2,
            "healthy": 22,
            "degraded": 1,
            "progressing": 2,
            "recent_deployments": [
                {"app": "payment-service", "status": "synced", "time": "10m ago"},
                {"app": "order-service", "status": "synced", "time": "1h ago"},
            ]
        }

    def collect_mesh_metrics(self, prometheus_url: str = None) -> Dict:
        """Collect service mesh metrics."""
        # Simulated metrics
        return {
            "total_services": 15,
            "healthy": 14,
            "request_rate": 1250,
            "error_rate": 0.2,
            "p50_latency_ms": 45,
            "p99_latency_ms": 250,
            "mtls_enabled": True,
            "circuit_breakers_open": 0
        }

    def collect_chaos_metrics(self) -> Dict:
        """Collect chaos engineering metrics."""
        return {
            "experiments_run_30d": 15,
            "success_rate": 87.5,
            "findings": [
                "Payment service needs circuit breaker improvement",
                "Order service recovered well from pod failures"
            ],
            "next_scheduled": "2024-01-15 09:00 UTC"
        }

    def collect_cost_metrics(self, cost_analyzer=None) -> Dict:
        """Collect FinOps metrics."""
        return {
            "monthly_cost": 45000,
            "vs_last_month": -5.2,
            "top_services": {
                "EC2": 18000,
                "RDS": 12000,
                "S3": 5000,
                "Lambda": 3000
            },
            "anomalies": 2,
            "optimization_opportunities": {
                "idle_instances": 5,
                "unattached_volumes": 12,
                "potential_savings": 2500
            }
        }

    def generate_dashboard(self) -> Dict:
        """Generate complete dashboard data."""
        gitops = self.collect_gitops_metrics()
        mesh = self.collect_mesh_metrics()
        chaos = self.collect_chaos_metrics()
        cost = self.collect_cost_metrics()

        # Update status
        self.status.gitops_apps = gitops["total_applications"]
        self.status.gitops_healthy = gitops["healthy"]
        self.status.mesh_services = mesh["total_services"]
        self.status.mesh_healthy = mesh["healthy"]
        self.status.chaos_experiments_run = chaos["experiments_run_30d"]
        self.status.chaos_success_rate = chaos["success_rate"]
        self.status.monthly_cost = cost["monthly_cost"]
        self.status.cost_trend = cost["vs_last_month"]
        self.status.potential_savings = cost["optimization_opportunities"]["potential_savings"]

        # Generate alerts
        self._check_alerts(gitops, mesh, chaos, cost)

        return {
            "timestamp": datetime.utcnow().isoformat(),
            "overall_health": self._calculate_overall_health(),
            "status": {
                "gitops": gitops,
                "service_mesh": mesh,
                "chaos_engineering": chaos,
                "finops": cost
            },
            "alerts": self.alerts,
            "recommendations": self._generate_recommendations(gitops, mesh, chaos, cost)
        }

    def _calculate_overall_health(self) -> str:
        """Calculate overall platform health."""
        scores = [
            self.status.gitops_healthy / max(self.status.gitops_apps, 1) * 100,
            self.status.mesh_healthy / max(self.status.mesh_services, 1) * 100,
            self.status.chaos_success_rate
        ]

        avg_score = sum(scores) / len(scores)

        if avg_score >= 95:
            return "excellent"
        elif avg_score >= 85:
            return "good"
        elif avg_score >= 70:
            return "fair"
        else:
            return "needs_attention"

    def _check_alerts(self, gitops: Dict, mesh: Dict,
                      chaos: Dict, cost: Dict):
        """Check for conditions that warrant alerts."""
        self.alerts = []

        if gitops["out_of_sync"] > 0:
            self.alerts.append({
                "severity": "warning",
                "category": "gitops",
                "message": f"{gitops['out_of_sync']} applications out of sync"
            })

        if mesh["error_rate"] > 1.0:
            self.alerts.append({
                "severity": "critical",
                "category": "service_mesh",
                "message": f"High error rate: {mesh['error_rate']}%"
            })

        if cost["anomalies"] > 0:
            self.alerts.append({
                "severity": "warning",
                "category": "finops",
                "message": f"{cost['anomalies']} cost anomalies detected"
            })

    def _generate_recommendations(self, gitops: Dict, mesh: Dict,
                                   chaos: Dict, cost: Dict) -> List[str]:
        """Generate platform recommendations."""
        recommendations = []

        if gitops["degraded"] > 0:
            recommendations.append(
                f"Investigate {gitops['degraded']} degraded applications in ArgoCD"
            )

        if mesh["p99_latency_ms"] > 200:
            recommendations.append(
                f"Review high P99 latency ({mesh['p99_latency_ms']}ms) - consider caching or optimization"
            )

        if chaos["success_rate"] < 90:
            recommendations.append(
                "Improve system resilience based on chaos experiment findings"
            )

        if cost["optimization_opportunities"]["potential_savings"] > 1000:
            recommendations.append(
                f"Potential monthly savings of ${cost['optimization_opportunities']['potential_savings']:,} available"
            )

        return recommendations

    def print_dashboard(self, data: Dict):
        """Print formatted dashboard to console."""
        print("\n" + "=" * 70)
        print("                    PLATFORM ENGINEERING DASHBOARD")
        print("=" * 70)
        print(f"Generated: {data['timestamp']}")
        print(f"Overall Health: {data['overall_health'].upper()}")
        print("-" * 70)

        # GitOps Section
        g = data["status"]["gitops"]
        print(f"\n📦 GITOPS (ArgoCD)")
        print(f"   Applications: {g['total_applications']} total, {g['synced']} synced, {g['healthy']} healthy")
        print(f"   Out of sync: {g['out_of_sync']}, Degraded: {g['degraded']}")

        # Service Mesh Section
        m = data["status"]["service_mesh"]
        print(f"\n🔗 SERVICE MESH (Istio)")
        print(f"   Services: {m['total_services']} total, {m['healthy']} healthy")
        print(f"   Traffic: {m['request_rate']} req/s, {m['error_rate']}% errors")
        print(f"   Latency: p50={m['p50_latency_ms']}ms, p99={m['p99_latency_ms']}ms")

        # Chaos Engineering Section
        c = data["status"]["chaos_engineering"]
        print(f"\n🔥 CHAOS ENGINEERING")
        print(f"   Experiments (30d): {c['experiments_run_30d']}, Success rate: {c['success_rate']}%")
        if c['findings']:
            print(f"   Latest finding: {c['findings'][0]}")

        # FinOps Section
        f = data["status"]["finops"]
        print(f"\n💰 FINOPS")
        print(f"   Monthly cost: ${f['monthly_cost']:,} ({f['vs_last_month']:+.1f}% vs last month)")
        print(f"   Potential savings: ${f['optimization_opportunities']['potential_savings']:,}")

        # Alerts
        if data["alerts"]:
            print(f"\n⚠️  ALERTS ({len(data['alerts'])})")
            for alert in data["alerts"]:
                icon = "🔴" if alert["severity"] == "critical" else "🟡"
                print(f"   {icon} [{alert['category']}] {alert['message']}")

        # Recommendations
        if data["recommendations"]:
            print(f"\n💡 RECOMMENDATIONS")
            for i, rec in enumerate(data["recommendations"], 1):
                print(f"   {i}. {rec}")

        print("\n" + "=" * 70)


def main():
    """Run the Platform Engineering Dashboard."""
    dashboard = PlatformDashboard()
    data = dashboard.generate_dashboard()
    dashboard.print_dashboard(data)

    # Save to JSON
    with open("platform_dashboard.json", "w") as f:
        json.dump(data, f, indent=2, default=str)

    print("\nDashboard data saved to platform_dashboard.json")


if __name__ == "__main__":
    main()
```

---

### ✅ Checkpoint: Phase 16 Self-Assessment

- [ ] Implement GitOps workflows with ArgoCD
- [ ] Configure service mesh with Istio
- [ ] Design and run chaos experiments
- [ ] Build cloud cost optimization tools
- [ ] Create unified platform dashboards
- [ ] Understand progressive delivery patterns

---

## Phase 17: Capstone Projects & Portfolio Building (Weeks 49-52)

| Focus | Key Skills | Time Investment |
|-------|-----------|-----------------|
| Integration Projects | End-to-end systems, architecture | 25 hours |
| Portfolio Development | Documentation, presentation | 15 hours |
| Career Preparation | Interviews, contributions | 10 hours |

### Learning Objectives
- Build production-grade systems integrating all learned concepts
- Create a compelling portfolio demonstrating DevOps expertise
- Prepare for senior DevOps/Platform Engineering roles
- Contribute to open source and community

---

### 17.1 Capstone Project 1: Enterprise Deployment Platform

**Build a complete deployment platform that organizations actually use.**

```python
#!/usr/bin/env python3
"""
Enterprise Deployment Platform - Capstone Project 1

A production-grade deployment platform integrating:
- Multi-environment GitOps pipelines
- Kubernetes orchestration
- Observability stack
- Security automation
- Cost management
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Callable
from enum import Enum
from datetime import datetime, timedelta
import asyncio
import json
import hashlib
import uuid
from abc import ABC, abstractmethod
from concurrent.futures import ThreadPoolExecutor
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# =============================================================================
# Core Domain Models
# =============================================================================

class DeploymentStatus(Enum):
    PENDING = "pending"
    VALIDATING = "validating"
    BUILDING = "building"
    TESTING = "testing"
    DEPLOYING = "deploying"
    VERIFYING = "verifying"
    COMPLETED = "completed"
    FAILED = "failed"
    ROLLED_BACK = "rolled_back"


class Environment(Enum):
    DEV = "dev"
    STAGING = "staging"
    PRODUCTION = "production"


@dataclass
class Application:
    """Represents a deployable application."""
    name: str
    repository: str
    team: str
    tier: str  # critical, standard, experimental
    environments: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    health_checks: List[Dict[str, str]] = field(default_factory=list)
    dependencies: List[str] = field(default_factory=list)
    rollback_strategy: str = "automatic"
    created_at: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "repository": self.repository,
            "team": self.team,
            "tier": self.tier,
            "environments": self.environments,
            "health_checks": self.health_checks,
            "dependencies": self.dependencies,
            "rollback_strategy": self.rollback_strategy
        }


@dataclass
class DeploymentRequest:
    """A deployment request with full context."""
    id: str
    application: Application
    environment: Environment
    version: str
    commit_sha: str
    requested_by: str
    strategy: str = "rolling"  # rolling, blue-green, canary
    canary_percentage: int = 10
    auto_rollback: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.now)

    @classmethod
    def create(cls, app: Application, env: Environment, version: str,
               commit_sha: str, requested_by: str, **kwargs) -> "DeploymentRequest":
        return cls(
            id=str(uuid.uuid4())[:8],
            application=app,
            environment=env,
            version=version,
            commit_sha=commit_sha,
            requested_by=requested_by,
            **kwargs
        )


@dataclass
class DeploymentResult:
    """Result of a deployment operation."""
    request_id: str
    status: DeploymentStatus
    started_at: datetime
    completed_at: Optional[datetime] = None
    stages: List[Dict[str, Any]] = field(default_factory=list)
    metrics: Dict[str, Any] = field(default_factory=dict)
    rollback_info: Optional[Dict[str, Any]] = None
    error: Optional[str] = None

    @property
    def duration(self) -> Optional[timedelta]:
        if self.completed_at:
            return self.completed_at - self.started_at
        return None


# =============================================================================
# Pipeline Stages
# =============================================================================

class PipelineStage(ABC):
    """Abstract base for pipeline stages."""

    def __init__(self, name: str):
        self.name = name
        self.start_time: Optional[datetime] = None
        self.end_time: Optional[datetime] = None

    @abstractmethod
    async def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Execute the stage and return results."""
        pass

    async def run(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """Run with timing and error handling."""
        self.start_time = datetime.now()
        try:
            result = await self.execute(context)
            result["success"] = True
        except Exception as e:
            result = {"success": False, "error": str(e)}
            logger.error(f"Stage {self.name} failed: {e}")
        finally:
            self.end_time = datetime.now()
            result["duration_seconds"] = (self.end_time - self.start_time).total_seconds()
        return result


class ValidationStage(PipelineStage):
    """Validate deployment request and prerequisites."""

    def __init__(self):
        super().__init__("validation")

    async def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        request: DeploymentRequest = context["request"]
        validations = []

        # Check application exists
        validations.append({
            "check": "application_exists",
            "passed": True,
            "message": f"Application {request.application.name} found"
        })

        # Check environment access
        env_config = request.application.environments.get(request.environment.value)
        validations.append({
            "check": "environment_configured",
            "passed": env_config is not None,
            "message": f"Environment {request.environment.value} configured"
        })

        # Check dependencies are healthy
        for dep in request.application.dependencies:
            validations.append({
                "check": f"dependency_{dep}",
                "passed": True,  # Would check actual dependency health
                "message": f"Dependency {dep} is healthy"
            })

        # Check deployment window (production only)
        if request.environment == Environment.PRODUCTION:
            hour = datetime.now().hour
            in_window = 9 <= hour <= 17  # 9 AM to 5 PM
            validations.append({
                "check": "deployment_window",
                "passed": in_window,
                "message": "Within deployment window" if in_window else "Outside deployment window"
            })

        all_passed = all(v["passed"] for v in validations)
        if not all_passed:
            failed = [v for v in validations if not v["passed"]]
            raise ValueError(f"Validation failed: {failed}")

        return {"validations": validations, "all_passed": all_passed}


class SecurityScanStage(PipelineStage):
    """Run security scans on the deployment artifact."""

    def __init__(self):
        super().__init__("security_scan")

    async def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        request: DeploymentRequest = context["request"]

        # Simulate security scans
        scans = {
            "vulnerability_scan": {
                "tool": "trivy",
                "critical": 0,
                "high": 2,
                "medium": 5,
                "low": 12,
                "passed": True  # No critical vulnerabilities
            },
            "secrets_scan": {
                "tool": "gitleaks",
                "secrets_found": 0,
                "passed": True
            },
            "sast_scan": {
                "tool": "bandit",
                "issues_found": 3,
                "severity": "low",
                "passed": True
            },
            "license_scan": {
                "tool": "license-checker",
                "copyleft_found": 0,
                "passed": True
            }
        }

        # Check for blocking issues
        blocking = []
        if scans["vulnerability_scan"]["critical"] > 0:
            blocking.append("Critical vulnerabilities found")
        if scans["secrets_scan"]["secrets_found"] > 0:
            blocking.append("Secrets detected in code")

        if blocking:
            raise ValueError(f"Security scan failed: {blocking}")

        return {"scans": scans, "blocking_issues": blocking}


class BuildStage(PipelineStage):
    """Build and push container image."""

    def __init__(self):
        super().__init__("build")

    async def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        request: DeploymentRequest = context["request"]

        # Generate image tag
        image_tag = f"{request.application.name}:{request.version}-{request.commit_sha[:7]}"
        registry = "registry.company.com"
        full_image = f"{registry}/{image_tag}"

        # Simulate build steps
        build_steps = [
            {"step": "checkout", "status": "completed", "duration": 5},
            {"step": "install_dependencies", "status": "completed", "duration": 45},
            {"step": "run_tests", "status": "completed", "duration": 120},
            {"step": "build_image", "status": "completed", "duration": 60},
            {"step": "push_image", "status": "completed", "duration": 30}
        ]

        # Generate image digest
        image_digest = hashlib.sha256(full_image.encode()).hexdigest()[:12]

        return {
            "image": full_image,
            "digest": f"sha256:{image_digest}",
            "build_steps": build_steps,
            "size_mb": 245
        }


class DeployStage(PipelineStage):
    """Deploy to Kubernetes cluster."""

    def __init__(self):
        super().__init__("deploy")

    async def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        request: DeploymentRequest = context["request"]
        build_result = context["stages"].get("build", {})

        strategy = request.strategy
        namespace = f"{request.application.name}-{request.environment.value}"

        if strategy == "rolling":
            return await self._rolling_deploy(request, build_result, namespace)
        elif strategy == "blue-green":
            return await self._blue_green_deploy(request, build_result, namespace)
        elif strategy == "canary":
            return await self._canary_deploy(request, build_result, namespace)
        else:
            raise ValueError(f"Unknown strategy: {strategy}")

    async def _rolling_deploy(self, request: DeploymentRequest,
                              build_result: Dict, namespace: str) -> Dict:
        """Standard rolling deployment."""
        replicas = 3
        steps = []

        for i in range(replicas):
            steps.append({
                "replica": i + 1,
                "status": "updated",
                "old_pod": f"pod-{uuid.uuid4().hex[:8]}",
                "new_pod": f"pod-{uuid.uuid4().hex[:8]}"
            })
            await asyncio.sleep(0.1)  # Simulate time

        return {
            "strategy": "rolling",
            "namespace": namespace,
            "replicas_updated": replicas,
            "steps": steps,
            "image": build_result.get("image")
        }

    async def _blue_green_deploy(self, request: DeploymentRequest,
                                  build_result: Dict, namespace: str) -> Dict:
        """Blue-green deployment with instant cutover."""
        return {
            "strategy": "blue-green",
            "namespace": namespace,
            "old_deployment": "blue",
            "new_deployment": "green",
            "traffic_switched": True,
            "image": build_result.get("image")
        }

    async def _canary_deploy(self, request: DeploymentRequest,
                             build_result: Dict, namespace: str) -> Dict:
        """Canary deployment with gradual traffic shift."""
        percentages = [10, 25, 50, 75, 100]
        steps = []

        for pct in percentages:
            if pct <= request.canary_percentage or pct == 100:
                steps.append({
                    "traffic_percentage": pct,
                    "status": "completed",
                    "error_rate": 0.1  # Simulated
                })

        return {
            "strategy": "canary",
            "namespace": namespace,
            "final_percentage": 100,
            "steps": steps,
            "image": build_result.get("image")
        }


class VerificationStage(PipelineStage):
    """Verify deployment health and functionality."""

    def __init__(self):
        super().__init__("verification")

    async def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        request: DeploymentRequest = context["request"]

        verifications = []

        # Health check verification
        for hc in request.application.health_checks:
            verifications.append({
                "type": "health_check",
                "endpoint": hc.get("path", "/health"),
                "status_code": 200,
                "response_time_ms": 45,
                "passed": True
            })

        # Readiness verification
        verifications.append({
            "type": "readiness",
            "pods_ready": 3,
            "pods_total": 3,
            "passed": True
        })

        # Smoke tests
        verifications.append({
            "type": "smoke_tests",
            "tests_run": 5,
            "tests_passed": 5,
            "passed": True
        })

        # Metrics verification (no error spike)
        verifications.append({
            "type": "error_rate",
            "current": 0.1,
            "threshold": 1.0,
            "passed": True
        })

        all_passed = all(v["passed"] for v in verifications)

        return {
            "verifications": verifications,
            "all_passed": all_passed,
            "recommendation": "proceed" if all_passed else "rollback"
        }


# =============================================================================
# Deployment Pipeline Orchestrator
# =============================================================================

class DeploymentPipeline:
    """Orchestrates the complete deployment pipeline."""

    def __init__(self):
        self.stages: List[PipelineStage] = [
            ValidationStage(),
            SecurityScanStage(),
            BuildStage(),
            DeployStage(),
            VerificationStage()
        ]
        self.hooks: Dict[str, List[Callable]] = {
            "pre_deploy": [],
            "post_deploy": [],
            "on_failure": [],
            "on_rollback": []
        }

    def add_hook(self, event: str, callback: Callable):
        """Add a lifecycle hook."""
        if event in self.hooks:
            self.hooks[event].append(callback)

    async def _run_hooks(self, event: str, context: Dict[str, Any]):
        """Run all hooks for an event."""
        for hook in self.hooks.get(event, []):
            try:
                if asyncio.iscoroutinefunction(hook):
                    await hook(context)
                else:
                    hook(context)
            except Exception as e:
                logger.warning(f"Hook failed for {event}: {e}")

    async def execute(self, request: DeploymentRequest) -> DeploymentResult:
        """Execute the full deployment pipeline."""
        result = DeploymentResult(
            request_id=request.id,
            status=DeploymentStatus.PENDING,
            started_at=datetime.now()
        )

        context = {
            "request": request,
            "stages": {},
            "result": result
        }

        try:
            # Pre-deploy hooks
            await self._run_hooks("pre_deploy", context)

            # Execute each stage
            for stage in self.stages:
                status_map = {
                    "validation": DeploymentStatus.VALIDATING,
                    "security_scan": DeploymentStatus.VALIDATING,
                    "build": DeploymentStatus.BUILDING,
                    "deploy": DeploymentStatus.DEPLOYING,
                    "verification": DeploymentStatus.VERIFYING
                }
                result.status = status_map.get(stage.name, DeploymentStatus.DEPLOYING)

                logger.info(f"Executing stage: {stage.name}")
                stage_result = await stage.run(context)

                context["stages"][stage.name] = stage_result
                result.stages.append({
                    "name": stage.name,
                    "result": stage_result
                })

                if not stage_result.get("success"):
                    raise ValueError(f"Stage {stage.name} failed: {stage_result.get('error')}")

            # Success!
            result.status = DeploymentStatus.COMPLETED
            result.completed_at = datetime.now()

            # Post-deploy hooks
            await self._run_hooks("post_deploy", context)

        except Exception as e:
            result.status = DeploymentStatus.FAILED
            result.error = str(e)
            result.completed_at = datetime.now()

            # Failure hooks
            await self._run_hooks("on_failure", context)

            # Auto-rollback if enabled
            if request.auto_rollback:
                await self._rollback(request, result, context)

        return result

    async def _rollback(self, request: DeploymentRequest,
                        result: DeploymentResult, context: Dict[str, Any]):
        """Perform automatic rollback."""
        logger.warning(f"Initiating rollback for deployment {request.id}")

        result.rollback_info = {
            "triggered_at": datetime.now().isoformat(),
            "reason": result.error,
            "status": "completed"
        }
        result.status = DeploymentStatus.ROLLED_BACK

        await self._run_hooks("on_rollback", context)


# =============================================================================
# Deployment Manager
# =============================================================================

class DeploymentManager:
    """High-level deployment management interface."""

    def __init__(self):
        self.pipeline = DeploymentPipeline()
        self.applications: Dict[str, Application] = {}
        self.deployments: Dict[str, DeploymentResult] = {}
        self.locks: Dict[str, asyncio.Lock] = {}

    def register_application(self, app: Application):
        """Register an application for deployment."""
        self.applications[app.name] = app
        self.locks[app.name] = asyncio.Lock()
        logger.info(f"Registered application: {app.name}")

    async def deploy(self, app_name: str, environment: str,
                     version: str, commit_sha: str,
                     requested_by: str, **kwargs) -> DeploymentResult:
        """Deploy an application to an environment."""

        if app_name not in self.applications:
            raise ValueError(f"Unknown application: {app_name}")

        app = self.applications[app_name]
        env = Environment(environment)

        # Create deployment request
        request = DeploymentRequest.create(
            app=app,
            env=env,
            version=version,
            commit_sha=commit_sha,
            requested_by=requested_by,
            **kwargs
        )

        # Acquire lock to prevent concurrent deployments
        async with self.locks[app_name]:
            logger.info(f"Starting deployment {request.id} for {app_name} to {environment}")
            result = await self.pipeline.execute(request)
            self.deployments[request.id] = result

        return result

    def get_deployment(self, deployment_id: str) -> Optional[DeploymentResult]:
        """Get deployment result by ID."""
        return self.deployments.get(deployment_id)

    def get_recent_deployments(self, app_name: Optional[str] = None,
                                limit: int = 10) -> List[DeploymentResult]:
        """Get recent deployments, optionally filtered by application."""
        deployments = list(self.deployments.values())
        deployments.sort(key=lambda d: d.started_at, reverse=True)
        return deployments[:limit]


# =============================================================================
# API Layer (FastAPI)
# =============================================================================

def create_deployment_api(manager: DeploymentManager):
    """Create FastAPI application for deployment management."""

    # Note: In production, import FastAPI and create actual routes
    # This demonstrates the API structure

    api_spec = {
        "POST /api/v1/deployments": {
            "description": "Create a new deployment",
            "request_body": {
                "application": "string",
                "environment": "dev|staging|production",
                "version": "string",
                "commit_sha": "string",
                "strategy": "rolling|blue-green|canary"
            },
            "response": {
                "deployment_id": "string",
                "status": "string"
            }
        },
        "GET /api/v1/deployments/{id}": {
            "description": "Get deployment status",
            "response": {
                "id": "string",
                "status": "string",
                "stages": "array",
                "duration": "string"
            }
        },
        "POST /api/v1/deployments/{id}/rollback": {
            "description": "Trigger manual rollback",
            "response": {
                "status": "string"
            }
        },
        "GET /api/v1/applications": {
            "description": "List registered applications",
            "response": {
                "applications": "array"
            }
        },
        "GET /api/v1/metrics": {
            "description": "Deployment metrics and statistics",
            "response": {
                "total_deployments": "int",
                "success_rate": "float",
                "avg_duration": "float"
            }
        }
    }

    return api_spec


# =============================================================================
# Demo / Testing
# =============================================================================

async def demo_deployment():
    """Demonstrate the deployment platform."""

    # Initialize manager
    manager = DeploymentManager()

    # Register applications
    web_app = Application(
        name="web-frontend",
        repository="github.com/company/web-frontend",
        team="platform",
        tier="critical",
        environments={
            "dev": {"replicas": 1, "resources": "small"},
            "staging": {"replicas": 2, "resources": "medium"},
            "production": {"replicas": 5, "resources": "large"}
        },
        health_checks=[
            {"path": "/health", "interval": 30},
            {"path": "/ready", "interval": 10}
        ],
        dependencies=["api-gateway", "user-service"]
    )

    api_service = Application(
        name="api-gateway",
        repository="github.com/company/api-gateway",
        team="platform",
        tier="critical",
        environments={
            "dev": {"replicas": 1},
            "staging": {"replicas": 2},
            "production": {"replicas": 10}
        },
        health_checks=[{"path": "/health"}]
    )

    manager.register_application(web_app)
    manager.register_application(api_service)

    # Add hooks
    manager.pipeline.add_hook("pre_deploy", lambda ctx:
        logger.info(f"🚀 Starting deployment for {ctx['request'].application.name}"))
    manager.pipeline.add_hook("post_deploy", lambda ctx:
        logger.info(f"✅ Deployment completed for {ctx['request'].application.name}"))
    manager.pipeline.add_hook("on_failure", lambda ctx:
        logger.error(f"❌ Deployment failed: {ctx['result'].error}"))

    # Execute deployments
    print("\n" + "=" * 70)
    print("ENTERPRISE DEPLOYMENT PLATFORM - DEMO")
    print("=" * 70)

    # Deploy to staging
    print("\n📦 Deploying web-frontend to staging...")
    result = await manager.deploy(
        app_name="web-frontend",
        environment="staging",
        version="2.5.0",
        commit_sha="abc123def456",
        requested_by="ci-system",
        strategy="rolling"
    )

    print(f"\n📊 Deployment Result:")
    print(f"   ID: {result.request_id}")
    print(f"   Status: {result.status.value}")
    print(f"   Duration: {result.duration}")
    print(f"   Stages completed: {len(result.stages)}")

    # Show stage details
    print("\n📋 Stage Details:")
    for stage in result.stages:
        name = stage["name"]
        success = stage["result"].get("success", False)
        duration = stage["result"].get("duration_seconds", 0)
        icon = "✅" if success else "❌"
        print(f"   {icon} {name}: {duration:.2f}s")

    print("\n" + "=" * 70)


if __name__ == "__main__":
    asyncio.run(demo_deployment())
```

**Micro-Lab 17.1a**: Extend the deployment platform to support deployment freezes (prevent production deployments during specified periods).

**Micro-Lab 17.1b**: Add Slack/Teams notification integration for deployment events.

---

### 17.2 Capstone Project 2: Full-Stack Observability Platform

**Build a comprehensive observability solution with metrics, logs, traces, and alerts.**

```python
#!/usr/bin/env python3
"""
Full-Stack Observability Platform - Capstone Project 2

Integrates:
- Metrics collection and aggregation
- Centralized logging
- Distributed tracing
- Alerting and incident management
- SLO/SLI tracking
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Set
from enum import Enum
from datetime import datetime, timedelta
from collections import defaultdict
import asyncio
import json
import statistics
import random
import uuid


# =============================================================================
# Core Domain Models
# =============================================================================

class MetricType(Enum):
    COUNTER = "counter"
    GAUGE = "gauge"
    HISTOGRAM = "histogram"
    SUMMARY = "summary"


class AlertSeverity(Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


class IncidentStatus(Enum):
    TRIGGERED = "triggered"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"


@dataclass
class Metric:
    """A single metric data point."""
    name: str
    value: float
    metric_type: MetricType
    labels: Dict[str, str] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)

    @property
    def key(self) -> str:
        label_str = ",".join(f"{k}={v}" for k, v in sorted(self.labels.items()))
        return f"{self.name}{{{label_str}}}"


@dataclass
class LogEntry:
    """A structured log entry."""
    timestamp: datetime
    level: str
    service: str
    message: str
    trace_id: Optional[str] = None
    span_id: Optional[str] = None
    attributes: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict:
        return {
            "timestamp": self.timestamp.isoformat(),
            "level": self.level,
            "service": self.service,
            "message": self.message,
            "trace_id": self.trace_id,
            "span_id": self.span_id,
            **self.attributes
        }


@dataclass
class Span:
    """A distributed trace span."""
    trace_id: str
    span_id: str
    parent_span_id: Optional[str]
    operation_name: str
    service_name: str
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str = "ok"
    attributes: Dict[str, Any] = field(default_factory=dict)
    events: List[Dict[str, Any]] = field(default_factory=list)

    @property
    def duration_ms(self) -> Optional[float]:
        if self.end_time:
            return (self.end_time - self.start_time).total_seconds() * 1000
        return None

    def add_event(self, name: str, attributes: Dict[str, Any] = None):
        self.events.append({
            "name": name,
            "timestamp": datetime.now().isoformat(),
            "attributes": attributes or {}
        })


@dataclass
class SLI:
    """Service Level Indicator definition."""
    name: str
    description: str
    metric_query: str
    good_threshold: float
    total_query: Optional[str] = None

    def calculate(self, good_count: int, total_count: int) -> float:
        """Calculate SLI value as a percentage."""
        if total_count == 0:
            return 100.0
        return (good_count / total_count) * 100


@dataclass
class SLO:
    """Service Level Objective definition."""
    name: str
    sli: SLI
    target_percentage: float
    window_days: int = 30
    burn_rate_threshold: float = 1.0

    def error_budget_remaining(self, current_sli: float) -> float:
        """Calculate remaining error budget as a percentage."""
        allowed_bad = 100 - self.target_percentage
        actual_bad = 100 - current_sli
        if allowed_bad == 0:
            return 0 if actual_bad > 0 else 100
        return max(0, ((allowed_bad - actual_bad) / allowed_bad) * 100)


@dataclass
class AlertRule:
    """An alerting rule definition."""
    name: str
    expression: str
    severity: AlertSeverity
    for_duration: timedelta
    labels: Dict[str, str] = field(default_factory=dict)
    annotations: Dict[str, str] = field(default_factory=dict)

    def evaluate(self, value: float, threshold: float, operator: str) -> bool:
        """Evaluate the alert condition."""
        ops = {
            ">": lambda a, b: a > b,
            ">=": lambda a, b: a >= b,
            "<": lambda a, b: a < b,
            "<=": lambda a, b: a <= b,
            "==": lambda a, b: a == b,
            "!=": lambda a, b: a != b
        }
        return ops.get(operator, lambda a, b: False)(value, threshold)


@dataclass
class Incident:
    """An incident from triggered alerts."""
    id: str
    title: str
    severity: AlertSeverity
    status: IncidentStatus
    triggered_at: datetime
    acknowledged_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    assigned_to: Optional[str] = None
    alerts: List[str] = field(default_factory=list)
    timeline: List[Dict[str, Any]] = field(default_factory=list)

    def acknowledge(self, user: str):
        self.status = IncidentStatus.ACKNOWLEDGED
        self.acknowledged_at = datetime.now()
        self.assigned_to = user
        self.timeline.append({
            "timestamp": datetime.now().isoformat(),
            "action": "acknowledged",
            "user": user
        })

    def resolve(self, user: str, resolution: str):
        self.status = IncidentStatus.RESOLVED
        self.resolved_at = datetime.now()
        self.timeline.append({
            "timestamp": datetime.now().isoformat(),
            "action": "resolved",
            "user": user,
            "resolution": resolution
        })


# =============================================================================
# Metrics System
# =============================================================================

class MetricsCollector:
    """Collects and aggregates metrics."""

    def __init__(self, retention_hours: int = 24):
        self.metrics: Dict[str, List[Metric]] = defaultdict(list)
        self.retention = timedelta(hours=retention_hours)

    def record(self, metric: Metric):
        """Record a metric data point."""
        self.metrics[metric.key].append(metric)
        self._cleanup_old_metrics(metric.key)

    def counter(self, name: str, value: float = 1, labels: Dict[str, str] = None):
        """Record a counter metric."""
        self.record(Metric(name, value, MetricType.COUNTER, labels or {}))

    def gauge(self, name: str, value: float, labels: Dict[str, str] = None):
        """Record a gauge metric."""
        self.record(Metric(name, value, MetricType.GAUGE, labels or {}))

    def histogram(self, name: str, value: float, labels: Dict[str, str] = None):
        """Record a histogram metric."""
        self.record(Metric(name, value, MetricType.HISTOGRAM, labels or {}))

    def _cleanup_old_metrics(self, key: str):
        """Remove metrics older than retention period."""
        cutoff = datetime.now() - self.retention
        self.metrics[key] = [m for m in self.metrics[key] if m.timestamp > cutoff]

    def query(self, name: str, labels: Dict[str, str] = None,
              start: datetime = None, end: datetime = None) -> List[Metric]:
        """Query metrics by name and labels."""
        results = []
        for key, metrics in self.metrics.items():
            if not key.startswith(name):
                continue

            for metric in metrics:
                # Check label match
                if labels:
                    if not all(metric.labels.get(k) == v for k, v in labels.items()):
                        continue

                # Check time range
                if start and metric.timestamp < start:
                    continue
                if end and metric.timestamp > end:
                    continue

                results.append(metric)

        return sorted(results, key=lambda m: m.timestamp)

    def aggregate(self, name: str, labels: Dict[str, str] = None,
                  function: str = "avg", window: timedelta = None) -> Optional[float]:
        """Aggregate metrics using a function."""
        metrics = self.query(name, labels)

        if window:
            cutoff = datetime.now() - window
            metrics = [m for m in metrics if m.timestamp > cutoff]

        if not metrics:
            return None

        values = [m.value for m in metrics]

        functions = {
            "sum": sum,
            "avg": statistics.mean,
            "min": min,
            "max": max,
            "count": len,
            "p50": lambda v: statistics.quantiles(v, n=100)[49] if len(v) >= 2 else v[0],
            "p95": lambda v: statistics.quantiles(v, n=100)[94] if len(v) >= 2 else v[0],
            "p99": lambda v: statistics.quantiles(v, n=100)[98] if len(v) >= 2 else v[0]
        }

        return functions.get(function, statistics.mean)(values)


# =============================================================================
# Logging System
# =============================================================================

class LogAggregator:
    """Centralized log aggregation and search."""

    def __init__(self, max_entries: int = 100000):
        self.logs: List[LogEntry] = []
        self.max_entries = max_entries
        self.indices: Dict[str, Set[int]] = defaultdict(set)

    def ingest(self, entry: LogEntry):
        """Ingest a log entry."""
        idx = len(self.logs)
        self.logs.append(entry)

        # Build indices
        self.indices[f"service:{entry.service}"].add(idx)
        self.indices[f"level:{entry.level}"].add(idx)
        if entry.trace_id:
            self.indices[f"trace:{entry.trace_id}"].add(idx)

        # Trim if necessary
        if len(self.logs) > self.max_entries:
            self._trim_logs()

    def _trim_logs(self):
        """Remove oldest logs when limit exceeded."""
        trim_count = len(self.logs) - self.max_entries
        self.logs = self.logs[trim_count:]
        # Rebuild indices
        self._rebuild_indices()

    def _rebuild_indices(self):
        """Rebuild all indices."""
        self.indices.clear()
        for idx, entry in enumerate(self.logs):
            self.indices[f"service:{entry.service}"].add(idx)
            self.indices[f"level:{entry.level}"].add(idx)
            if entry.trace_id:
                self.indices[f"trace:{entry.trace_id}"].add(idx)

    def search(self, query: str = None, service: str = None,
               level: str = None, trace_id: str = None,
               start: datetime = None, end: datetime = None,
               limit: int = 100) -> List[LogEntry]:
        """Search logs with filters."""

        # Start with candidate indices
        candidates = None

        if service:
            candidates = self.indices.get(f"service:{service}", set())
        if level:
            level_indices = self.indices.get(f"level:{level}", set())
            candidates = level_indices if candidates is None else candidates & level_indices
        if trace_id:
            trace_indices = self.indices.get(f"trace:{trace_id}", set())
            candidates = trace_indices if candidates is None else candidates & trace_indices

        # If no index filters, check all
        if candidates is None:
            candidates = set(range(len(self.logs)))

        results = []
        for idx in sorted(candidates, reverse=True):
            if idx >= len(self.logs):
                continue

            entry = self.logs[idx]

            # Time range filter
            if start and entry.timestamp < start:
                continue
            if end and entry.timestamp > end:
                continue

            # Text query filter
            if query and query.lower() not in entry.message.lower():
                continue

            results.append(entry)

            if len(results) >= limit:
                break

        return results

    def get_error_summary(self, window: timedelta = None) -> Dict[str, int]:
        """Get error counts by service."""
        errors = self.search(level="ERROR")

        if window:
            cutoff = datetime.now() - window
            errors = [e for e in errors if e.timestamp > cutoff]

        summary = defaultdict(int)
        for entry in errors:
            summary[entry.service] += 1

        return dict(summary)


# =============================================================================
# Distributed Tracing
# =============================================================================

class TraceCollector:
    """Distributed tracing collection and analysis."""

    def __init__(self):
        self.traces: Dict[str, List[Span]] = defaultdict(list)

    def record_span(self, span: Span):
        """Record a completed span."""
        self.traces[span.trace_id].append(span)

    def get_trace(self, trace_id: str) -> List[Span]:
        """Get all spans for a trace."""
        spans = self.traces.get(trace_id, [])
        return sorted(spans, key=lambda s: s.start_time)

    def build_trace_tree(self, trace_id: str) -> Dict[str, Any]:
        """Build a tree representation of a trace."""
        spans = self.get_trace(trace_id)
        if not spans:
            return {}

        span_map = {s.span_id: s for s in spans}
        root = None
        children: Dict[str, List[Span]] = defaultdict(list)

        for span in spans:
            if span.parent_span_id is None:
                root = span
            else:
                children[span.parent_span_id].append(span)

        def build_node(span: Span) -> Dict:
            return {
                "span_id": span.span_id,
                "operation": span.operation_name,
                "service": span.service_name,
                "duration_ms": span.duration_ms,
                "status": span.status,
                "children": [build_node(c) for c in children.get(span.span_id, [])]
            }

        return build_node(root) if root else {}

    def analyze_latency(self, service: str, operation: str,
                        window: timedelta = None) -> Dict[str, float]:
        """Analyze latency distribution for an operation."""
        durations = []
        cutoff = datetime.now() - window if window else None

        for trace_id, spans in self.traces.items():
            for span in spans:
                if span.service_name != service or span.operation_name != operation:
                    continue
                if cutoff and span.start_time < cutoff:
                    continue
                if span.duration_ms:
                    durations.append(span.duration_ms)

        if not durations:
            return {}

        return {
            "count": len(durations),
            "min": min(durations),
            "max": max(durations),
            "avg": statistics.mean(durations),
            "p50": statistics.median(durations),
            "p95": statistics.quantiles(durations, n=100)[94] if len(durations) >= 2 else durations[0],
            "p99": statistics.quantiles(durations, n=100)[98] if len(durations) >= 2 else durations[0]
        }

    def find_slow_traces(self, threshold_ms: float, limit: int = 10) -> List[Dict]:
        """Find traces exceeding latency threshold."""
        slow_traces = []

        for trace_id, spans in self.traces.items():
            root_span = next((s for s in spans if s.parent_span_id is None), None)
            if root_span and root_span.duration_ms and root_span.duration_ms > threshold_ms:
                slow_traces.append({
                    "trace_id": trace_id,
                    "duration_ms": root_span.duration_ms,
                    "operation": root_span.operation_name,
                    "service": root_span.service_name,
                    "span_count": len(spans)
                })

        return sorted(slow_traces, key=lambda t: t["duration_ms"], reverse=True)[:limit]


# =============================================================================
# Alerting System
# =============================================================================

class AlertManager:
    """Manages alerts and incidents."""

    def __init__(self, metrics_collector: MetricsCollector):
        self.metrics = metrics_collector
        self.rules: List[AlertRule] = []
        self.active_alerts: Dict[str, Dict] = {}
        self.incidents: Dict[str, Incident] = {}
        self.notification_channels: List[Dict] = []

    def add_rule(self, rule: AlertRule):
        """Add an alert rule."""
        self.rules.append(rule)

    def add_notification_channel(self, channel_type: str, config: Dict):
        """Add a notification channel (Slack, PagerDuty, etc.)."""
        self.notification_channels.append({
            "type": channel_type,
            "config": config
        })

    def evaluate_rules(self) -> List[Dict]:
        """Evaluate all alert rules."""
        fired_alerts = []

        for rule in self.rules:
            # Parse expression (simplified)
            # Format: "metric_name{labels} > threshold"
            parts = rule.expression.split()
            if len(parts) != 3:
                continue

            metric_expr, operator, threshold = parts
            threshold = float(threshold)

            # Extract metric name and labels
            if "{" in metric_expr:
                name = metric_expr.split("{")[0]
                label_str = metric_expr.split("{")[1].rstrip("}")
                labels = dict(l.split("=") for l in label_str.split(",")) if label_str else {}
            else:
                name = metric_expr
                labels = {}

            # Get current value
            current_value = self.metrics.aggregate(name, labels, "avg", timedelta(minutes=5))

            if current_value is not None and rule.evaluate(current_value, threshold, operator):
                alert_key = f"{rule.name}:{name}"

                if alert_key not in self.active_alerts:
                    self.active_alerts[alert_key] = {
                        "rule": rule.name,
                        "started_at": datetime.now(),
                        "value": current_value,
                        "threshold": threshold
                    }

                    fired_alerts.append({
                        "rule": rule.name,
                        "severity": rule.severity.value,
                        "value": current_value,
                        "threshold": threshold,
                        "labels": labels
                    })

        return fired_alerts

    def create_incident(self, alerts: List[Dict]) -> Incident:
        """Create an incident from alerts."""
        if not alerts:
            return None

        # Determine severity (highest from alerts)
        severity = max(
            (AlertSeverity(a["severity"]) for a in alerts),
            key=lambda s: ["info", "warning", "error", "critical"].index(s.value)
        )

        incident = Incident(
            id=str(uuid.uuid4())[:8],
            title=f"Alert: {alerts[0]['rule']}",
            severity=severity,
            status=IncidentStatus.TRIGGERED,
            triggered_at=datetime.now(),
            alerts=[a["rule"] for a in alerts]
        )

        incident.timeline.append({
            "timestamp": datetime.now().isoformat(),
            "action": "created",
            "alerts": incident.alerts
        })

        self.incidents[incident.id] = incident
        return incident


# =============================================================================
# SLO Management
# =============================================================================

class SLOManager:
    """Manages SLOs and error budgets."""

    def __init__(self, metrics_collector: MetricsCollector):
        self.metrics = metrics_collector
        self.slos: Dict[str, SLO] = {}

    def register_slo(self, slo: SLO):
        """Register an SLO."""
        self.slos[slo.name] = slo

    def calculate_sli(self, slo_name: str) -> Optional[Dict[str, Any]]:
        """Calculate current SLI value for an SLO."""
        slo = self.slos.get(slo_name)
        if not slo:
            return None

        window = timedelta(days=slo.window_days)

        # Simulate SLI calculation
        # In reality, would query actual metrics
        good_count = random.randint(9900, 10000)
        total_count = 10000

        current_sli = slo.sli.calculate(good_count, total_count)
        error_budget = slo.error_budget_remaining(current_sli)

        return {
            "slo_name": slo_name,
            "sli_name": slo.sli.name,
            "target": slo.target_percentage,
            "current_sli": round(current_sli, 4),
            "error_budget_remaining": round(error_budget, 2),
            "window_days": slo.window_days,
            "good_events": good_count,
            "total_events": total_count,
            "status": "ok" if current_sli >= slo.target_percentage else "burning"
        }

    def get_all_slo_status(self) -> List[Dict[str, Any]]:
        """Get status for all SLOs."""
        return [self.calculate_sli(name) for name in self.slos.keys()]


# =============================================================================
# Unified Observability Platform
# =============================================================================

class ObservabilityPlatform:
    """Unified observability platform integrating all components."""

    def __init__(self):
        self.metrics = MetricsCollector()
        self.logs = LogAggregator()
        self.traces = TraceCollector()
        self.alerts = AlertManager(self.metrics)
        self.slos = SLOManager(self.metrics)

    def ingest_telemetry(self, data: Dict[str, Any]):
        """Ingest telemetry data (metrics, logs, or traces)."""
        data_type = data.get("type")

        if data_type == "metric":
            self.metrics.record(Metric(
                name=data["name"],
                value=data["value"],
                metric_type=MetricType(data.get("metric_type", "gauge")),
                labels=data.get("labels", {})
            ))

        elif data_type == "log":
            self.logs.ingest(LogEntry(
                timestamp=datetime.fromisoformat(data["timestamp"]),
                level=data["level"],
                service=data["service"],
                message=data["message"],
                trace_id=data.get("trace_id"),
                span_id=data.get("span_id"),
                attributes=data.get("attributes", {})
            ))

        elif data_type == "span":
            span = Span(
                trace_id=data["trace_id"],
                span_id=data["span_id"],
                parent_span_id=data.get("parent_span_id"),
                operation_name=data["operation"],
                service_name=data["service"],
                start_time=datetime.fromisoformat(data["start_time"]),
                end_time=datetime.fromisoformat(data["end_time"]) if data.get("end_time") else None,
                status=data.get("status", "ok"),
                attributes=data.get("attributes", {})
            )
            self.traces.record_span(span)

    def correlate(self, trace_id: str) -> Dict[str, Any]:
        """Correlate metrics, logs, and traces for a request."""
        trace_spans = self.traces.get_trace(trace_id)
        trace_logs = self.logs.search(trace_id=trace_id)

        if not trace_spans:
            return {"error": "Trace not found"}

        root_span = next((s for s in trace_spans if s.parent_span_id is None), trace_spans[0])

        # Get metrics for involved services
        services = list(set(s.service_name for s in trace_spans))

        return {
            "trace_id": trace_id,
            "trace_tree": self.traces.build_trace_tree(trace_id),
            "total_duration_ms": root_span.duration_ms,
            "span_count": len(trace_spans),
            "services_involved": services,
            "logs": [log.to_dict() for log in trace_logs],
            "log_count": len(trace_logs),
            "errors": [log.to_dict() for log in trace_logs if log.level == "ERROR"]
        }

    def get_service_health(self, service: str) -> Dict[str, Any]:
        """Get comprehensive health view for a service."""
        # Recent metrics
        error_rate = self.metrics.aggregate(
            "http_requests_total",
            {"service": service, "status": "5xx"},
            "sum",
            timedelta(minutes=5)
        ) or 0

        total_requests = self.metrics.aggregate(
            "http_requests_total",
            {"service": service},
            "sum",
            timedelta(minutes=5)
        ) or 1

        # Recent logs
        error_logs = self.logs.search(
            service=service,
            level="ERROR",
            start=datetime.now() - timedelta(minutes=15)
        )

        # Latency
        latency = self.traces.analyze_latency(
            service,
            "handle_request",
            timedelta(minutes=15)
        )

        return {
            "service": service,
            "timestamp": datetime.now().isoformat(),
            "health": {
                "error_rate_percent": (error_rate / total_requests) * 100,
                "request_count_5m": total_requests,
                "error_log_count_15m": len(error_logs)
            },
            "latency": latency,
            "recent_errors": [log.message for log in error_logs[:5]]
        }

    def generate_dashboard(self) -> Dict[str, Any]:
        """Generate a unified observability dashboard."""
        return {
            "timestamp": datetime.now().isoformat(),
            "metrics": {
                "total_series": len(self.metrics.metrics),
                "data_points_24h": sum(len(m) for m in self.metrics.metrics.values())
            },
            "logs": {
                "total_entries": len(self.logs.logs),
                "error_summary": self.logs.get_error_summary(timedelta(hours=1))
            },
            "traces": {
                "total_traces": len(self.traces.traces),
                "slow_traces": self.traces.find_slow_traces(1000, limit=5)
            },
            "alerts": {
                "active_count": len(self.alerts.active_alerts),
                "rules_count": len(self.alerts.rules)
            },
            "slos": self.slos.get_all_slo_status()
        }


# =============================================================================
# Demo
# =============================================================================

def demo_observability():
    """Demonstrate the observability platform."""

    platform = ObservabilityPlatform()

    # Register SLOs
    availability_sli = SLI(
        name="api_availability",
        description="Percentage of successful API requests",
        metric_query='sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))',
        good_threshold=0.99
    )

    platform.slos.register_slo(SLO(
        name="api_availability_slo",
        sli=availability_sli,
        target_percentage=99.9,
        window_days=30
    ))

    # Add alert rules
    platform.alerts.add_rule(AlertRule(
        name="high_error_rate",
        expression="error_rate{service=api} > 5",
        severity=AlertSeverity.CRITICAL,
        for_duration=timedelta(minutes=5),
        annotations={"summary": "Error rate exceeds 5%"}
    ))

    # Simulate telemetry ingestion
    services = ["api-gateway", "user-service", "order-service"]

    for _ in range(100):
        service = random.choice(services)

        # Metrics
        platform.ingest_telemetry({
            "type": "metric",
            "name": "http_requests_total",
            "value": 1,
            "metric_type": "counter",
            "labels": {"service": service, "status": random.choice(["200", "200", "200", "500"])}
        })

        # Logs
        platform.ingest_telemetry({
            "type": "log",
            "timestamp": datetime.now().isoformat(),
            "level": random.choice(["INFO", "INFO", "INFO", "WARN", "ERROR"]),
            "service": service,
            "message": f"Request processed by {service}"
        })

    # Generate dashboard
    print("\n" + "=" * 70)
    print("FULL-STACK OBSERVABILITY PLATFORM")
    print("=" * 70)

    dashboard = platform.generate_dashboard()

    print(f"\n📊 METRICS")
    print(f"   Total series: {dashboard['metrics']['total_series']}")
    print(f"   Data points (24h): {dashboard['metrics']['data_points_24h']}")

    print(f"\n📝 LOGS")
    print(f"   Total entries: {dashboard['logs']['total_entries']}")
    print(f"   Errors by service: {dashboard['logs']['error_summary']}")

    print(f"\n🔍 TRACES")
    print(f"   Total traces: {dashboard['traces']['total_traces']}")

    print(f"\n🚨 ALERTS")
    print(f"   Active: {dashboard['alerts']['active_count']}")
    print(f"   Rules: {dashboard['alerts']['rules_count']}")

    print(f"\n🎯 SLOs")
    for slo in dashboard['slos']:
        if slo:
            status_icon = "✅" if slo['status'] == 'ok' else "🔥"
            print(f"   {status_icon} {slo['slo_name']}: {slo['current_sli']:.2f}% (target: {slo['target']}%)")
            print(f"      Error budget remaining: {slo['error_budget_remaining']:.1f}%")

    print("\n" + "=" * 70)


if __name__ == "__main__":
    demo_observability()
```

**Micro-Lab 17.2a**: Add anomaly detection for metrics using statistical methods.

**Micro-Lab 17.2b**: Implement a runbook automation system that triggers remediation actions.

---

### 17.3 Capstone Project 3: Multi-Cloud Infrastructure Platform

**Build a platform-agnostic infrastructure management system.**

```python
#!/usr/bin/env python3
"""
Multi-Cloud Infrastructure Platform - Capstone Project 3

A unified platform for managing infrastructure across:
- AWS, Azure, GCP
- Kubernetes clusters
- On-premises resources
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Protocol, Type
from enum import Enum
from datetime import datetime
from abc import ABC, abstractmethod
import json
import hashlib


# =============================================================================
# Core Abstractions
# =============================================================================

class CloudProvider(Enum):
    AWS = "aws"
    AZURE = "azure"
    GCP = "gcp"
    KUBERNETES = "kubernetes"
    ONPREM = "onprem"


class ResourceState(Enum):
    PENDING = "pending"
    CREATING = "creating"
    RUNNING = "running"
    UPDATING = "updating"
    DELETING = "deleting"
    DELETED = "deleted"
    FAILED = "failed"


@dataclass
class ResourceSpec:
    """Abstract specification for a cloud resource."""
    name: str
    resource_type: str
    provider: CloudProvider
    region: str
    properties: Dict[str, Any] = field(default_factory=dict)
    tags: Dict[str, str] = field(default_factory=dict)
    dependencies: List[str] = field(default_factory=list)

    @property
    def resource_id(self) -> str:
        """Generate unique resource ID."""
        key = f"{self.provider.value}:{self.region}:{self.resource_type}:{self.name}"
        return hashlib.sha256(key.encode()).hexdigest()[:16]

    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "type": self.resource_type,
            "provider": self.provider.value,
            "region": self.region,
            "properties": self.properties,
            "tags": self.tags,
            "dependencies": self.dependencies
        }


@dataclass
class ResourceStatus:
    """Current status of a resource."""
    resource_id: str
    state: ResourceState
    provider_id: Optional[str] = None
    outputs: Dict[str, Any] = field(default_factory=dict)
    last_updated: datetime = field(default_factory=datetime.now)
    error: Optional[str] = None


class CloudProviderInterface(ABC):
    """Interface for cloud provider implementations."""

    @abstractmethod
    def create_resource(self, spec: ResourceSpec) -> ResourceStatus:
        pass

    @abstractmethod
    def update_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        pass

    @abstractmethod
    def delete_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        pass

    @abstractmethod
    def get_resource_status(self, spec: ResourceSpec) -> Optional[ResourceStatus]:
        pass

    @abstractmethod
    def list_resources(self, resource_type: str, region: str) -> List[Dict]:
        pass


# =============================================================================
# Provider Implementations
# =============================================================================

class AWSProvider(CloudProviderInterface):
    """AWS cloud provider implementation."""

    def __init__(self, region: str = "us-east-1"):
        self.region = region
        self.resources: Dict[str, ResourceStatus] = {}

    def create_resource(self, spec: ResourceSpec) -> ResourceStatus:
        print(f"[AWS] Creating {spec.resource_type}: {spec.name}")

        # Simulate resource creation
        provider_id = f"arn:aws:{spec.resource_type}:{spec.region}:123456789012:{spec.name}"

        status = ResourceStatus(
            resource_id=spec.resource_id,
            state=ResourceState.RUNNING,
            provider_id=provider_id,
            outputs=self._generate_outputs(spec)
        )

        self.resources[spec.resource_id] = status
        return status

    def update_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        print(f"[AWS] Updating {spec.resource_type}: {spec.name}")

        current.state = ResourceState.UPDATING
        current.outputs = self._generate_outputs(spec)
        current.state = ResourceState.RUNNING
        current.last_updated = datetime.now()

        return current

    def delete_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        print(f"[AWS] Deleting {spec.resource_type}: {spec.name}")

        current.state = ResourceState.DELETED
        current.last_updated = datetime.now()

        if spec.resource_id in self.resources:
            del self.resources[spec.resource_id]

        return current

    def get_resource_status(self, spec: ResourceSpec) -> Optional[ResourceStatus]:
        return self.resources.get(spec.resource_id)

    def list_resources(self, resource_type: str, region: str) -> List[Dict]:
        return [
            {"id": s.provider_id, "state": s.state.value}
            for s in self.resources.values()
        ]

    def _generate_outputs(self, spec: ResourceSpec) -> Dict[str, Any]:
        """Generate resource outputs based on type."""
        outputs = {}

        if spec.resource_type == "ec2_instance":
            outputs = {
                "instance_id": f"i-{spec.resource_id[:17]}",
                "private_ip": "10.0.1.100",
                "public_ip": "54.123.45.67"
            }
        elif spec.resource_type == "rds_instance":
            outputs = {
                "endpoint": f"{spec.name}.cluster-xyz.{spec.region}.rds.amazonaws.com",
                "port": 5432
            }
        elif spec.resource_type == "s3_bucket":
            outputs = {
                "bucket_arn": f"arn:aws:s3:::{spec.name}",
                "bucket_url": f"https://{spec.name}.s3.amazonaws.com"
            }
        elif spec.resource_type == "vpc":
            outputs = {
                "vpc_id": f"vpc-{spec.resource_id[:17]}",
                "cidr_block": spec.properties.get("cidr_block", "10.0.0.0/16")
            }

        return outputs


class AzureProvider(CloudProviderInterface):
    """Azure cloud provider implementation."""

    def __init__(self, subscription_id: str = "00000000-0000-0000-0000-000000000000"):
        self.subscription_id = subscription_id
        self.resources: Dict[str, ResourceStatus] = {}

    def create_resource(self, spec: ResourceSpec) -> ResourceStatus:
        print(f"[Azure] Creating {spec.resource_type}: {spec.name}")

        resource_group = spec.properties.get("resource_group", "default-rg")
        provider_id = f"/subscriptions/{self.subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.Compute/{spec.resource_type}/{spec.name}"

        status = ResourceStatus(
            resource_id=spec.resource_id,
            state=ResourceState.RUNNING,
            provider_id=provider_id,
            outputs=self._generate_outputs(spec)
        )

        self.resources[spec.resource_id] = status
        return status

    def update_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        print(f"[Azure] Updating {spec.resource_type}: {spec.name}")
        current.state = ResourceState.RUNNING
        current.last_updated = datetime.now()
        return current

    def delete_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        print(f"[Azure] Deleting {spec.resource_type}: {spec.name}")
        current.state = ResourceState.DELETED
        if spec.resource_id in self.resources:
            del self.resources[spec.resource_id]
        return current

    def get_resource_status(self, spec: ResourceSpec) -> Optional[ResourceStatus]:
        return self.resources.get(spec.resource_id)

    def list_resources(self, resource_type: str, region: str) -> List[Dict]:
        return list(self.resources.values())

    def _generate_outputs(self, spec: ResourceSpec) -> Dict[str, Any]:
        if spec.resource_type == "virtual_machine":
            return {
                "vm_id": spec.resource_id,
                "private_ip": "10.0.0.4",
                "public_ip": "52.168.100.200"
            }
        return {}


class GCPProvider(CloudProviderInterface):
    """GCP cloud provider implementation."""

    def __init__(self, project_id: str = "my-project"):
        self.project_id = project_id
        self.resources: Dict[str, ResourceStatus] = {}

    def create_resource(self, spec: ResourceSpec) -> ResourceStatus:
        print(f"[GCP] Creating {spec.resource_type}: {spec.name}")

        provider_id = f"projects/{self.project_id}/zones/{spec.region}/{spec.resource_type}/{spec.name}"

        status = ResourceStatus(
            resource_id=spec.resource_id,
            state=ResourceState.RUNNING,
            provider_id=provider_id,
            outputs=self._generate_outputs(spec)
        )

        self.resources[spec.resource_id] = status
        return status

    def update_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        print(f"[GCP] Updating {spec.resource_type}: {spec.name}")
        current.state = ResourceState.RUNNING
        current.last_updated = datetime.now()
        return current

    def delete_resource(self, spec: ResourceSpec, current: ResourceStatus) -> ResourceStatus:
        print(f"[GCP] Deleting {spec.resource_type}: {spec.name}")
        current.state = ResourceState.DELETED
        if spec.resource_id in self.resources:
            del self.resources[spec.resource_id]
        return current

    def get_resource_status(self, spec: ResourceSpec) -> Optional[ResourceStatus]:
        return self.resources.get(spec.resource_id)

    def list_resources(self, resource_type: str, region: str) -> List[Dict]:
        return list(self.resources.values())

    def _generate_outputs(self, spec: ResourceSpec) -> Dict[str, Any]:
        if spec.resource_type == "compute_instance":
            return {
                "self_link": f"https://compute.googleapis.com/compute/v1/projects/{self.project_id}/zones/{spec.region}/instances/{spec.name}",
                "internal_ip": "10.128.0.2",
                "external_ip": "35.192.100.50"
            }
        return {}


# =============================================================================
# Infrastructure State Management
# =============================================================================

@dataclass
class InfrastructureState:
    """Represents the complete infrastructure state."""
    resources: Dict[str, ResourceSpec] = field(default_factory=dict)
    statuses: Dict[str, ResourceStatus] = field(default_factory=dict)
    version: int = 0
    last_applied: Optional[datetime] = None

    def add_resource(self, spec: ResourceSpec):
        self.resources[spec.resource_id] = spec

    def remove_resource(self, resource_id: str):
        if resource_id in self.resources:
            del self.resources[resource_id]
        if resource_id in self.statuses:
            del self.statuses[resource_id]

    def to_dict(self) -> Dict:
        return {
            "version": self.version,
            "last_applied": self.last_applied.isoformat() if self.last_applied else None,
            "resources": {k: v.to_dict() for k, v in self.resources.items()},
            "statuses": {k: {"state": v.state.value, "provider_id": v.provider_id}
                        for k, v in self.statuses.items()}
        }

    def save(self, path: str):
        with open(path, 'w') as f:
            json.dump(self.to_dict(), f, indent=2)

    @classmethod
    def load(cls, path: str) -> "InfrastructureState":
        try:
            with open(path, 'r') as f:
                data = json.load(f)
            state = cls(version=data.get("version", 0))
            # Reconstruct resources from data
            return state
        except FileNotFoundError:
            return cls()


# =============================================================================
# Infrastructure Orchestrator
# =============================================================================

class InfrastructureOrchestrator:
    """Orchestrates infrastructure changes across clouds."""

    def __init__(self):
        self.providers: Dict[CloudProvider, CloudProviderInterface] = {
            CloudProvider.AWS: AWSProvider(),
            CloudProvider.AZURE: AzureProvider(),
            CloudProvider.GCP: GCPProvider()
        }
        self.state = InfrastructureState()

    def plan(self, desired_specs: List[ResourceSpec]) -> Dict[str, Any]:
        """Generate an execution plan."""
        plan = {
            "create": [],
            "update": [],
            "delete": [],
            "no_change": []
        }

        desired_ids = set()

        for spec in desired_specs:
            desired_ids.add(spec.resource_id)
            current = self.state.resources.get(spec.resource_id)

            if current is None:
                plan["create"].append(spec.to_dict())
            elif current.to_dict() != spec.to_dict():
                plan["update"].append({
                    "current": current.to_dict(),
                    "desired": spec.to_dict()
                })
            else:
                plan["no_change"].append(spec.name)

        # Find resources to delete
        for resource_id, spec in self.state.resources.items():
            if resource_id not in desired_ids:
                plan["delete"].append(spec.to_dict())

        return plan

    def apply(self, desired_specs: List[ResourceSpec], auto_approve: bool = False) -> Dict[str, Any]:
        """Apply infrastructure changes."""
        plan = self.plan(desired_specs)

        print("\n" + "=" * 60)
        print("INFRASTRUCTURE PLAN")
        print("=" * 60)
        print(f"  Create: {len(plan['create'])} resources")
        print(f"  Update: {len(plan['update'])} resources")
        print(f"  Delete: {len(plan['delete'])} resources")
        print(f"  No change: {len(plan['no_change'])} resources")
        print("=" * 60)

        if not auto_approve:
            # In real implementation, would prompt for approval
            pass

        results = {
            "created": [],
            "updated": [],
            "deleted": [],
            "failed": []
        }

        # Sort by dependencies (topological sort)
        sorted_specs = self._sort_by_dependencies(desired_specs)

        # Create/Update resources
        for spec in sorted_specs:
            try:
                provider = self.providers.get(spec.provider)
                if not provider:
                    raise ValueError(f"No provider for {spec.provider}")

                current_status = self.state.statuses.get(spec.resource_id)

                if current_status is None:
                    # Create
                    status = provider.create_resource(spec)
                    results["created"].append(spec.name)
                else:
                    # Update
                    status = provider.update_resource(spec, current_status)
                    results["updated"].append(spec.name)

                self.state.resources[spec.resource_id] = spec
                self.state.statuses[spec.resource_id] = status

            except Exception as e:
                results["failed"].append({"resource": spec.name, "error": str(e)})

        # Delete resources not in desired state
        for resource_id, spec in list(self.state.resources.items()):
            if resource_id not in {s.resource_id for s in desired_specs}:
                try:
                    provider = self.providers.get(spec.provider)
                    current_status = self.state.statuses.get(resource_id)
                    if provider and current_status:
                        provider.delete_resource(spec, current_status)
                    self.state.remove_resource(resource_id)
                    results["deleted"].append(spec.name)
                except Exception as e:
                    results["failed"].append({"resource": spec.name, "error": str(e)})

        self.state.version += 1
        self.state.last_applied = datetime.now()

        return results

    def _sort_by_dependencies(self, specs: List[ResourceSpec]) -> List[ResourceSpec]:
        """Topologically sort resources by dependencies."""
        # Simple implementation - production would use proper topo sort
        sorted_specs = []
        remaining = list(specs)
        resolved = set()

        while remaining:
            for spec in remaining[:]:
                deps_met = all(
                    dep in resolved or dep not in {s.name for s in specs}
                    for dep in spec.dependencies
                )
                if deps_met:
                    sorted_specs.append(spec)
                    resolved.add(spec.name)
                    remaining.remove(spec)

        return sorted_specs

    def get_outputs(self, resource_name: str) -> Optional[Dict[str, Any]]:
        """Get outputs for a resource by name."""
        for resource_id, spec in self.state.resources.items():
            if spec.name == resource_name:
                status = self.state.statuses.get(resource_id)
                return status.outputs if status else None
        return None

    def destroy_all(self) -> Dict[str, Any]:
        """Destroy all managed infrastructure."""
        return self.apply([], auto_approve=True)


# =============================================================================
# Infrastructure Definition DSL
# =============================================================================

class InfrastructureBuilder:
    """Fluent builder for infrastructure definitions."""

    def __init__(self):
        self.specs: List[ResourceSpec] = []

    def aws_ec2(self, name: str, **kwargs) -> "InfrastructureBuilder":
        """Add an AWS EC2 instance."""
        self.specs.append(ResourceSpec(
            name=name,
            resource_type="ec2_instance",
            provider=CloudProvider.AWS,
            region=kwargs.pop("region", "us-east-1"),
            properties={
                "instance_type": kwargs.get("instance_type", "t3.micro"),
                "ami": kwargs.get("ami", "ami-12345678"),
                "subnet_id": kwargs.get("subnet_id"),
                **kwargs
            },
            tags=kwargs.get("tags", {}),
            dependencies=kwargs.get("dependencies", [])
        ))
        return self

    def aws_rds(self, name: str, **kwargs) -> "InfrastructureBuilder":
        """Add an AWS RDS instance."""
        self.specs.append(ResourceSpec(
            name=name,
            resource_type="rds_instance",
            provider=CloudProvider.AWS,
            region=kwargs.pop("region", "us-east-1"),
            properties={
                "engine": kwargs.get("engine", "postgres"),
                "engine_version": kwargs.get("engine_version", "14"),
                "instance_class": kwargs.get("instance_class", "db.t3.micro"),
                "allocated_storage": kwargs.get("allocated_storage", 20),
                **kwargs
            },
            tags=kwargs.get("tags", {}),
            dependencies=kwargs.get("dependencies", [])
        ))
        return self

    def aws_s3(self, name: str, **kwargs) -> "InfrastructureBuilder":
        """Add an AWS S3 bucket."""
        self.specs.append(ResourceSpec(
            name=name,
            resource_type="s3_bucket",
            provider=CloudProvider.AWS,
            region=kwargs.pop("region", "us-east-1"),
            properties={
                "versioning": kwargs.get("versioning", True),
                "encryption": kwargs.get("encryption", "AES256"),
                **kwargs
            },
            tags=kwargs.get("tags", {})
        ))
        return self

    def aws_vpc(self, name: str, cidr_block: str, **kwargs) -> "InfrastructureBuilder":
        """Add an AWS VPC."""
        self.specs.append(ResourceSpec(
            name=name,
            resource_type="vpc",
            provider=CloudProvider.AWS,
            region=kwargs.pop("region", "us-east-1"),
            properties={
                "cidr_block": cidr_block,
                "enable_dns_hostnames": kwargs.get("enable_dns_hostnames", True),
                **kwargs
            },
            tags=kwargs.get("tags", {})
        ))
        return self

    def azure_vm(self, name: str, **kwargs) -> "InfrastructureBuilder":
        """Add an Azure Virtual Machine."""
        self.specs.append(ResourceSpec(
            name=name,
            resource_type="virtual_machine",
            provider=CloudProvider.AZURE,
            region=kwargs.pop("region", "eastus"),
            properties={
                "vm_size": kwargs.get("vm_size", "Standard_B1s"),
                "resource_group": kwargs.get("resource_group", "default-rg"),
                **kwargs
            },
            tags=kwargs.get("tags", {})
        ))
        return self

    def gcp_instance(self, name: str, **kwargs) -> "InfrastructureBuilder":
        """Add a GCP Compute Instance."""
        self.specs.append(ResourceSpec(
            name=name,
            resource_type="compute_instance",
            provider=CloudProvider.GCP,
            region=kwargs.pop("zone", "us-central1-a"),
            properties={
                "machine_type": kwargs.get("machine_type", "e2-micro"),
                **kwargs
            },
            tags=kwargs.get("tags", {})
        ))
        return self

    def build(self) -> List[ResourceSpec]:
        """Return the infrastructure specifications."""
        return self.specs


# =============================================================================
# Demo
# =============================================================================

def demo_multi_cloud():
    """Demonstrate multi-cloud infrastructure management."""

    print("\n" + "=" * 70)
    print("MULTI-CLOUD INFRASTRUCTURE PLATFORM")
    print("=" * 70)

    # Define infrastructure using builder
    infra = (InfrastructureBuilder()
        .aws_vpc("production-vpc", "10.0.0.0/16",
                 tags={"environment": "production"})
        .aws_ec2("web-server-1",
                 instance_type="t3.medium",
                 dependencies=["production-vpc"],
                 tags={"role": "web"})
        .aws_ec2("web-server-2",
                 instance_type="t3.medium",
                 dependencies=["production-vpc"],
                 tags={"role": "web"})
        .aws_rds("primary-db",
                 engine="postgres",
                 engine_version="14",
                 instance_class="db.r5.large",
                 dependencies=["production-vpc"],
                 tags={"role": "database"})
        .aws_s3("app-assets-bucket",
                versioning=True,
                tags={"purpose": "static-assets"})
        .azure_vm("backup-processor",
                  vm_size="Standard_B2s",
                  resource_group="backup-rg")
        .gcp_instance("analytics-worker",
                      machine_type="n1-standard-2",
                      zone="us-central1-a")
        .build()
    )

    # Create orchestrator
    orchestrator = InfrastructureOrchestrator()

    # Generate and show plan
    plan = orchestrator.plan(infra)
    print(f"\n📋 PLAN SUMMARY:")
    print(f"   Resources to create: {len(plan['create'])}")
    for resource in plan['create']:
        print(f"      + {resource['provider']}/{resource['type']}: {resource['name']}")

    # Apply infrastructure
    print("\n🚀 APPLYING INFRASTRUCTURE...")
    results = orchestrator.apply(infra, auto_approve=True)

    print(f"\n✅ APPLY RESULTS:")
    print(f"   Created: {len(results['created'])} resources")
    print(f"   Updated: {len(results['updated'])} resources")
    print(f"   Failed: {len(results['failed'])} resources")

    # Show outputs
    print(f"\n📤 RESOURCE OUTPUTS:")
    for spec in infra:
        outputs = orchestrator.get_outputs(spec.name)
        if outputs:
            print(f"   {spec.name}:")
            for key, value in outputs.items():
                print(f"      {key}: {value}")

    # Show state summary
    print(f"\n📊 STATE SUMMARY:")
    print(f"   Version: {orchestrator.state.version}")
    print(f"   Total resources: {len(orchestrator.state.resources)}")
    print(f"   Last applied: {orchestrator.state.last_applied}")

    print("\n" + "=" * 70)


if __name__ == "__main__":
    demo_multi_cloud()
```

**Micro-Lab 17.3a**: Add support for infrastructure drift detection.

**Micro-Lab 17.3b**: Implement cost estimation before applying changes.

---

### 17.4 Portfolio Project Guidelines

**Building a compelling portfolio that demonstrates DevOps expertise.**

```python
#!/usr/bin/env python3
"""
Portfolio Project Framework

Guidelines and tools for building a standout DevOps portfolio.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from enum import Enum
from datetime import datetime
import json


class SkillCategory(Enum):
    PYTHON = "Python Programming"
    AUTOMATION = "Automation & Scripting"
    CONTAINERS = "Containers & Orchestration"
    CLOUD = "Cloud Platforms"
    IAC = "Infrastructure as Code"
    CICD = "CI/CD Pipelines"
    OBSERVABILITY = "Monitoring & Observability"
    SECURITY = "Security & Compliance"
    NETWORKING = "Networking"
    DATABASE = "Database Management"


@dataclass
class PortfolioProject:
    """A portfolio project definition."""
    title: str
    description: str
    skills_demonstrated: List[SkillCategory]
    technologies: List[str]
    github_url: str
    demo_url: Optional[str] = None
    documentation_url: Optional[str] = None
    complexity: str = "intermediate"  # beginner, intermediate, advanced
    time_to_build: str = "1-2 weeks"
    highlights: List[str] = field(default_factory=list)
    metrics: Dict[str, Any] = field(default_factory=dict)

    def to_readme(self) -> str:
        """Generate README content for the project."""
        skills = ", ".join(s.value for s in self.skills_demonstrated)
        tech = ", ".join(self.technologies)
        highlights = "\n".join(f"- {h}" for h in self.highlights)

        return f"""# {self.title}

## Overview
{self.description}

## Skills Demonstrated
{skills}

## Technologies Used
{tech}

## Key Highlights
{highlights}

## Project Metrics
{json.dumps(self.metrics, indent=2)}

## Getting Started
See the documentation for setup instructions.

## Links
- [GitHub Repository]({self.github_url})
{f'- [Live Demo]({self.demo_url})' if self.demo_url else ''}
{f'- [Documentation]({self.documentation_url})' if self.documentation_url else ''}
"""


class PortfolioBuilder:
    """Helps build a comprehensive DevOps portfolio."""

    RECOMMENDED_PROJECTS = [
        {
            "title": "Kubernetes Deployment Platform",
            "description": "End-to-end platform for deploying applications to Kubernetes with GitOps workflows",
            "skills": [SkillCategory.CONTAINERS, SkillCategory.CICD, SkillCategory.IAC],
            "technologies": ["Python", "Kubernetes", "ArgoCD", "Helm", "GitHub Actions"],
            "complexity": "advanced",
            "key_features": [
                "Multi-environment deployments (dev/staging/prod)",
                "Automatic rollbacks on failure",
                "Slack notifications",
                "Cost tracking",
                "Audit logging"
            ]
        },
        {
            "title": "Cloud Cost Optimizer",
            "description": "Tool that analyzes cloud spending and recommends optimizations",
            "skills": [SkillCategory.CLOUD, SkillCategory.PYTHON, SkillCategory.AUTOMATION],
            "technologies": ["Python", "AWS/GCP/Azure SDKs", "Pandas", "FastAPI", "React"],
            "complexity": "intermediate",
            "key_features": [
                "Multi-cloud support",
                "Idle resource detection",
                "Right-sizing recommendations",
                "Scheduled reports",
                "Slack/Email alerts"
            ]
        },
        {
            "title": "Infrastructure Testing Framework",
            "description": "Comprehensive testing framework for infrastructure code",
            "skills": [SkillCategory.IAC, SkillCategory.PYTHON, SkillCategory.SECURITY],
            "technologies": ["Python", "Terraform", "pytest", "Checkov", "InSpec"],
            "complexity": "advanced",
            "key_features": [
                "Policy-as-code validation",
                "Security scanning",
                "Compliance checking",
                "Integration with CI/CD",
                "Detailed reports"
            ]
        },
        {
            "title": "Observability Stack",
            "description": "Custom observability solution with metrics, logs, and traces",
            "skills": [SkillCategory.OBSERVABILITY, SkillCategory.PYTHON, SkillCategory.CONTAINERS],
            "technologies": ["Python", "Prometheus", "Grafana", "Loki", "Jaeger", "OpenTelemetry"],
            "complexity": "advanced",
            "key_features": [
                "Custom metrics collection",
                "Log aggregation",
                "Distributed tracing",
                "Alerting with runbooks",
                "SLO tracking"
            ]
        },
        {
            "title": "Secrets Management System",
            "description": "Centralized secrets management with rotation and auditing",
            "skills": [SkillCategory.SECURITY, SkillCategory.PYTHON, SkillCategory.AUTOMATION],
            "technologies": ["Python", "HashiCorp Vault", "AWS Secrets Manager", "FastAPI"],
            "complexity": "intermediate",
            "key_features": [
                "Automatic secret rotation",
                "Access audit logging",
                "Multi-backend support",
                "CLI and API interfaces",
                "Integration with CI/CD"
            ]
        },
        {
            "title": "Incident Response Automation",
            "description": "Automated incident detection and response system",
            "skills": [SkillCategory.AUTOMATION, SkillCategory.OBSERVABILITY, SkillCategory.PYTHON],
            "technologies": ["Python", "PagerDuty", "Slack", "Runbooks", "Ansible"],
            "complexity": "advanced",
            "key_features": [
                "Alert correlation",
                "Automatic remediation",
                "Escalation workflows",
                "Post-incident reports",
                "Runbook execution"
            ]
        }
    ]

    PORTFOLIO_STRUCTURE = """
    portfolio/
    ├── README.md                 # Overview and navigation
    ├── resume.md                 # Technical resume
    ├── projects/
    │   ├── deployment-platform/
    │   │   ├── README.md
    │   │   ├── docs/
    │   │   ├── src/
    │   │   ├── tests/
    │   │   └── .github/workflows/
    │   ├── cost-optimizer/
    │   └── ...
    ├── contributions/            # Open source contributions
    │   └── README.md
    ├── certifications/           # Certification badges/info
    │   └── README.md
    └── blog/                     # Technical writing samples
        └── README.md
    """

    @staticmethod
    def generate_readme_template() -> str:
        """Generate main portfolio README template."""
        return """# DevOps Engineering Portfolio

## About Me
[Brief introduction - 2-3 sentences about your background and interests]

## Core Competencies

### Infrastructure & Cloud
- AWS/GCP/Azure architecture and automation
- Terraform, CloudFormation, Pulumi
- Kubernetes and container orchestration

### CI/CD & Automation
- GitHub Actions, GitLab CI, Jenkins
- Python automation scripts
- GitOps with ArgoCD/Flux

### Observability & Reliability
- Prometheus, Grafana, Loki
- Distributed tracing with Jaeger/Zipkin
- SLO/SLI implementation

### Security
- DevSecOps pipeline integration
- Secrets management
- Compliance automation

## Featured Projects

| Project | Description | Technologies | Complexity |
|---------|-------------|--------------|------------|
| [Project 1](#) | Brief description | Tech stack | Advanced |
| [Project 2](#) | Brief description | Tech stack | Intermediate |

## Certifications
- [Certification 1]
- [Certification 2]

## Open Source Contributions
- [Contribution 1]
- [Contribution 2]

## Technical Writing
- [Blog Post 1]
- [Blog Post 2]

## Contact
- LinkedIn: [Your Profile]
- Email: [Your Email]
- GitHub: [Your GitHub]
"""

    @staticmethod
    def project_evaluation_criteria() -> Dict[str, List[str]]:
        """Criteria for evaluating portfolio projects."""
        return {
            "code_quality": [
                "Clean, readable code with consistent style",
                "Proper error handling and logging",
                "Comprehensive unit and integration tests",
                "Type hints and documentation",
                "No security vulnerabilities"
            ],
            "documentation": [
                "Clear README with setup instructions",
                "Architecture diagrams",
                "API documentation if applicable",
                "Runbook for operations",
                "Contribution guidelines"
            ],
            "devops_practices": [
                "CI/CD pipeline with tests",
                "Infrastructure as Code",
                "Container/Kubernetes deployment",
                "Monitoring and alerting",
                "Security scanning"
            ],
            "professionalism": [
                "Git history with meaningful commits",
                "Branch protection and PR workflow",
                "Semantic versioning",
                "Changelog maintenance",
                "Issue templates"
            ],
            "innovation": [
                "Solves a real problem",
                "Demonstrates technical depth",
                "Shows learning and growth",
                "Includes performance optimizations",
                "Extensible design"
            ]
        }

    @staticmethod
    def interview_preparation() -> Dict[str, List[str]]:
        """Common interview topics for each project."""
        return {
            "architecture_questions": [
                "Walk me through the architecture of this project",
                "Why did you choose these technologies?",
                "What trade-offs did you consider?",
                "How would you scale this system?",
                "What would you do differently?"
            ],
            "implementation_questions": [
                "Explain your CI/CD pipeline",
                "How do you handle secrets management?",
                "What's your testing strategy?",
                "How do you monitor this in production?",
                "How do you handle failures?"
            ],
            "behavioral_questions": [
                "What was the most challenging part?",
                "How did you learn new technologies for this?",
                "How would you onboard a new team member?",
                "What feedback have you received?",
                "What's on your roadmap for this project?"
            ]
        }


def main():
    """Generate portfolio guidelines."""
    builder = PortfolioBuilder()

    print("=" * 70)
    print("DEVOPS PORTFOLIO BUILDING GUIDE")
    print("=" * 70)

    print("\n📂 RECOMMENDED PORTFOLIO STRUCTURE:")
    print(builder.PORTFOLIO_STRUCTURE)

    print("\n🚀 RECOMMENDED PROJECTS:")
    for i, project in enumerate(builder.RECOMMENDED_PROJECTS, 1):
        print(f"\n{i}. {project['title']}")
        print(f"   Complexity: {project['complexity']}")
        print(f"   Technologies: {', '.join(project['technologies'][:3])}...")
        print(f"   Key Features:")
        for feature in project['key_features'][:3]:
            print(f"      - {feature}")

    print("\n📋 EVALUATION CRITERIA:")
    criteria = builder.project_evaluation_criteria()
    for category, items in criteria.items():
        print(f"\n   {category.replace('_', ' ').title()}:")
        for item in items[:3]:
            print(f"      ✓ {item}")

    print("\n💼 INTERVIEW PREPARATION:")
    prep = builder.interview_preparation()
    for category, questions in prep.items():
        print(f"\n   {category.replace('_', ' ').title()}:")
        for q in questions[:2]:
            print(f"      • {q}")

    print("\n" + "=" * 70)


if __name__ == "__main__":
    main()
```

---

### 17.5 Cross-Phase Integration Projects

**Projects that integrate skills from multiple phases.**

```python
#!/usr/bin/env python3
"""
Cross-Phase Integration Projects

These projects combine skills from multiple phases of the roadmap.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Any
from enum import Enum


@dataclass
class IntegrationProject:
    """A cross-phase integration project."""
    name: str
    description: str
    phases_covered: List[int]
    skills_integrated: List[str]
    architecture: str
    components: List[Dict[str, Any]]
    learning_outcomes: List[str]
    difficulty: str
    estimated_hours: int


INTEGRATION_PROJECTS = [
    IntegrationProject(
        name="Full-Stack Application Deployment Pipeline",
        description="""
        Build a complete CI/CD pipeline for a microservices application, from
        code commit to production deployment with full observability.
        """,
        phases_covered=[1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 13],
        skills_integrated=[
            "Python scripting",
            "Git automation",
            "Docker containerization",
            "Kubernetes orchestration",
            "CI/CD pipelines",
            "Infrastructure as Code",
            "Monitoring and alerting"
        ],
        architecture="""
        ┌─────────────────────────────────────────────────────────────┐
        │                      Developer Workflow                       │
        └─────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                    GitHub Actions CI                          │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
        │  │  Lint    │→│  Test    │→│  Build   │→│  Push    │     │
        │  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
        └─────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                    ArgoCD GitOps                              │
        │           Sync manifests → Deploy to Kubernetes               │
        └─────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                   Kubernetes Cluster                          │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
        │  │  Frontend  │  │  Backend   │  │  Database  │            │
        │  │   Pods     │  │   Pods     │  │   Pod      │            │
        │  └────────────┘  └────────────┘  └────────────┘            │
        └─────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                  Observability Stack                          │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
        │  │ Prometheus │  │   Loki     │  │  Jaeger    │            │
        │  │  Metrics   │  │   Logs     │  │  Traces    │            │
        │  └────────────┘  └────────────┘  └────────────┘            │
        │                        │                                      │
        │                   ┌────────────┐                             │
        │                   │  Grafana   │                             │
        │                   │ Dashboards │                             │
        │                   └────────────┘                             │
        └─────────────────────────────────────────────────────────────┘
        """,
        components=[
            {
                "name": "Python Microservices",
                "phase": 1,
                "description": "Build FastAPI microservices with proper structure"
            },
            {
                "name": "Docker Configuration",
                "phase": 5,
                "description": "Multi-stage Dockerfiles, docker-compose for local dev"
            },
            {
                "name": "Kubernetes Manifests",
                "phase": 6,
                "description": "Deployments, Services, ConfigMaps, Secrets"
            },
            {
                "name": "Helm Charts",
                "phase": 6,
                "description": "Parameterized charts for multi-environment"
            },
            {
                "name": "GitHub Actions",
                "phase": 10,
                "description": "CI pipeline with testing, building, security scans"
            },
            {
                "name": "ArgoCD Application",
                "phase": 10,
                "description": "GitOps deployment with auto-sync"
            },
            {
                "name": "Terraform Infrastructure",
                "phase": 9,
                "description": "EKS/GKE cluster and supporting resources"
            },
            {
                "name": "Prometheus Monitoring",
                "phase": 7,
                "description": "Custom metrics, ServiceMonitors, alerts"
            },
            {
                "name": "Grafana Dashboards",
                "phase": 7,
                "description": "Application and infrastructure dashboards"
            }
        ],
        learning_outcomes=[
            "Design and implement production-grade CI/CD pipelines",
            "Deploy and manage microservices on Kubernetes",
            "Implement GitOps workflows with ArgoCD",
            "Build comprehensive monitoring and alerting",
            "Apply security best practices throughout the pipeline"
        ],
        difficulty="Advanced",
        estimated_hours=80
    ),
    IntegrationProject(
        name="Self-Healing Infrastructure Platform",
        description="""
        Create an infrastructure platform that automatically detects issues
        and remediate them without human intervention.
        """,
        phases_covered=[3, 4, 7, 8, 9, 12, 16],
        skills_integrated=[
            "Python automation",
            "Cloud APIs (AWS/GCP)",
            "Monitoring systems",
            "Infrastructure as Code",
            "Event-driven architecture",
            "Chaos engineering"
        ],
        architecture="""
        ┌─────────────────────────────────────────────────────────────┐
        │                    Detection Layer                            │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
        │  │ CloudWatch │  │ Prometheus │  │  Custom    │            │
        │  │  Alarms    │  │   Alerts   │  │  Checks    │            │
        │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘            │
        └────────┼───────────────┼───────────────┼────────────────────┘
                 │               │               │
                 └───────────────┼───────────────┘
                                 ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                  Event Processing                             │
        │  ┌────────────────────────────────────────────────────────┐ │
        │  │               EventBridge / SNS / SQS                   │ │
        │  └────────────────────────────────────────────────────────┘ │
        └─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                 Remediation Engine                            │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
        │  │  Lambda    │  │  Step      │  │  Ansible   │            │
        │  │ Functions  │  │ Functions  │  │  Runbooks  │            │
        │  └────────────┘  └────────────┘  └────────────┘            │
        │                                                               │
        │  ┌────────────────────────────────────────────────────────┐ │
        │  │              Remediation Actions                        │ │
        │  │  • Restart failed services                              │ │
        │  │  • Scale out on high load                               │ │
        │  │  • Rotate unhealthy instances                           │ │
        │  │  • Failover to backup region                            │ │
        │  │  • Clear caches / restart queues                        │ │
        │  └────────────────────────────────────────────────────────┘ │
        └─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
        ┌─────────────────────────────────────────────────────────────┐
        │               Verification & Notification                     │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
        │  │  Health    │  │   Slack    │  │  Incident  │            │
        │  │  Checks    │  │   Notify   │  │   Ticket   │            │
        │  └────────────┘  └────────────┘  └────────────┘            │
        └─────────────────────────────────────────────────────────────┘
        """,
        components=[
            {
                "name": "Health Check Framework",
                "description": "Python-based health checking with multiple protocols"
            },
            {
                "name": "Event Processor",
                "description": "AWS Lambda/Step Functions for event processing"
            },
            {
                "name": "Runbook Library",
                "description": "Ansible playbooks for common remediation tasks"
            },
            {
                "name": "Chaos Testing",
                "description": "Validation that self-healing works correctly"
            },
            {
                "name": "Audit Trail",
                "description": "Complete logging of all remediation actions"
            }
        ],
        learning_outcomes=[
            "Design event-driven automation architectures",
            "Implement automatic remediation workflows",
            "Build resilient systems that recover automatically",
            "Create comprehensive audit and compliance trails",
            "Apply chaos engineering to validate self-healing"
        ],
        difficulty="Advanced",
        estimated_hours=60
    ),
    IntegrationProject(
        name="Developer Platform Portal",
        description="""
        Build an internal developer platform that abstracts infrastructure
        complexity and provides self-service capabilities.
        """,
        phases_covered=[1, 2, 5, 6, 9, 10, 11, 16],
        skills_integrated=[
            "Full-stack Python development",
            "Kubernetes operators",
            "Terraform modules",
            "API design",
            "User experience"
        ],
        architecture="""
        ┌─────────────────────────────────────────────────────────────┐
        │                   Developer Portal UI                         │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
        │  │  Service   │  │Environment │  │  Resource  │            │
        │  │  Catalog   │  │  Manager   │  │  Browser   │            │
        │  └────────────┘  └────────────┘  └────────────┘            │
        └─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                    Platform API                               │
        │  ┌────────────────────────────────────────────────────────┐ │
        │  │  /services  /environments  /deployments  /resources    │ │
        │  └────────────────────────────────────────────────────────┘ │
        └─────────────────────────────────────────────────────────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │  Kubernetes  │ │   Terraform  │ │    CI/CD     │
        │  Controller  │ │   Runner     │ │  Triggers    │
        └──────────────┘ └──────────────┘ └──────────────┘
                 │               │               │
                 ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │  Kubernetes  │ │    Cloud     │ │   GitHub     │
        │   Cluster    │ │   Provider   │ │   Actions    │
        └──────────────┘ └──────────────┘ └──────────────┘
        """,
        components=[
            {
                "name": "FastAPI Backend",
                "description": "REST API for platform operations"
            },
            {
                "name": "React Frontend",
                "description": "Developer-friendly UI"
            },
            {
                "name": "Service Templates",
                "description": "Cookiecutter templates for new services"
            },
            {
                "name": "Terraform Modules",
                "description": "Self-service infrastructure components"
            },
            {
                "name": "Kubernetes Operator",
                "description": "Custom operator for platform resources"
            }
        ],
        learning_outcomes=[
            "Design internal developer platforms",
            "Build self-service infrastructure capabilities",
            "Create intuitive developer experiences",
            "Implement proper access control and governance",
            "Scale platform capabilities across the organization"
        ],
        difficulty="Expert",
        estimated_hours=120
    )
]


def display_integration_projects():
    """Display all integration projects."""

    print("\n" + "=" * 70)
    print("CROSS-PHASE INTEGRATION PROJECTS")
    print("=" * 70)

    for project in INTEGRATION_PROJECTS:
        print(f"\n{'─' * 70}")
        print(f"📦 {project.name}")
        print(f"{'─' * 70}")

        print(f"\n📝 Description:{project.description}")

        print(f"\n📊 Phases Covered: {project.phases_covered}")
        print(f"⏱️  Estimated Time: {project.estimated_hours} hours")
        print(f"🎯 Difficulty: {project.difficulty}")

        print(f"\n🛠️  Skills Integrated:")
        for skill in project.skills_integrated:
            print(f"   • {skill}")

        print(f"\n🏗️  Architecture:")
        print(project.architecture)

        print(f"\n📦 Components:")
        for comp in project.components[:5]:
            print(f"   • {comp['name']}: {comp['description']}")

        print(f"\n🎓 Learning Outcomes:")
        for outcome in project.learning_outcomes:
            print(f"   ✓ {outcome}")


if __name__ == "__main__":
    display_integration_projects()
```

---

### Phase Lab 17: Complete Capstone Implementation

**Objective**: Implement one of the capstone projects end-to-end.

**Requirements**:
1. Choose one capstone project (17.1, 17.2, or 17.3)
2. Design complete architecture with diagrams
3. Implement all core components
4. Write comprehensive tests (unit, integration, e2e)
5. Create CI/CD pipeline for the project
6. Deploy to a cloud environment
7. Set up monitoring and alerting
8. Write complete documentation
9. Create demo video or presentation
10. Publish to GitHub with proper structure

**Deliverables**:
- [ ] Architecture design document
- [ ] Working codebase with tests
- [ ] CI/CD pipeline configuration
- [ ] Deployed application
- [ ] Monitoring dashboards
- [ ] README with setup instructions
- [ ] API documentation
- [ ] Demo presentation

**Evaluation Criteria**:
- Code quality and organization
- Test coverage (>80%)
- Documentation completeness
- Production readiness
- Security considerations
- Operational excellence

---

### ✅ Checkpoint: Phase 17 Self-Assessment

- [ ] Complete at least one capstone project
- [ ] Build comprehensive portfolio
- [ ] Document all projects properly
- [ ] Set up personal GitHub with clean history
- [ ] Prepare for technical interviews
- [ ] Contribute to open source projects

---

## 🎓 Roadmap Completion Checklist

### Phase Completion Tracker

| Phase | Topic | Status |
|-------|-------|--------|
| 1 | Python Fundamentals | ☐ |
| 2 | Advanced Python | ☐ |
| 3 | System Automation | ☐ |
| 4 | Network & API Automation | ☐ |
| 5 | Containers & Docker | ☐ |
| 6 | Kubernetes & Orchestration | ☐ |
| 7 | Monitoring & Observability | ☐ |
| 8 | Cloud Platforms | ☐ |
| 9 | Infrastructure as Code | ☐ |
| 10 | CI/CD Pipelines | ☐ |
| 11 | Advanced CI/CD | ☐ |
| 12 | Configuration Management | ☐ |
| 13 | Serverless Architecture | ☐ |
| 14 | Security Automation (DevSecOps) | ☐ |
| 15 | MLOps | ☐ |
| 16 | Platform Engineering | ☐ |
| 17 | Capstone Projects | ☐ |

### Skills Certification Matrix

| Skill Area | Beginner | Intermediate | Advanced | Expert |
|------------|----------|--------------|----------|--------|
| Python Programming | ☐ | ☐ | ☐ | ☐ |
| Automation & Scripting | ☐ | ☐ | ☐ | ☐ |
| Containers & Kubernetes | ☐ | ☐ | ☐ | ☐ |
| Cloud Platforms | ☐ | ☐ | ☐ | ☐ |
| Infrastructure as Code | ☐ | ☐ | ☐ | ☐ |
| CI/CD Pipelines | ☐ | ☐ | ☐ | ☐ |
| Monitoring & Observability | ☐ | ☐ | ☐ | ☐ |
| Security & Compliance | ☐ | ☐ | ☐ | ☐ |
| Platform Engineering | ☐ | ☐ | ☐ | ☐ |

### Recommended Certifications

1. **AWS**
   - AWS Certified Solutions Architect
   - AWS Certified DevOps Engineer
   - AWS Certified Security Specialty

2. **Google Cloud**
   - Google Cloud Professional DevOps Engineer
   - Google Cloud Professional Cloud Architect

3. **Kubernetes**
   - Certified Kubernetes Administrator (CKA)
   - Certified Kubernetes Application Developer (CKAD)
   - Certified Kubernetes Security Specialist (CKS)

4. **HashiCorp**
   - Terraform Associate
   - Vault Associate

5. **Linux**
   - Linux Foundation Certified System Administrator

---

## 📚 Quick Reference

### Essential Tools by Phase

| Phase | Primary Tools |
|-------|---------------|
| 1-2 | Python, pip, venv, pytest |
| 3 | subprocess, psutil, pathlib |
| 4 | requests, FastAPI, asyncio |
| 5 | Docker, docker-compose |
| 6 | kubectl, Helm, k9s |
| 7 | Prometheus, Grafana, Loki |
| 8 | AWS CLI, boto3, gcloud |
| 9 | Terraform, Pulumi |
| 10-11 | GitHub Actions, GitLab CI |
| 12 | Ansible, Salt |
| 13 | Serverless Framework |
| 14 | Trivy, Bandit, Vault |
| 15 | MLflow, DVC |
| 16 | ArgoCD, Istio, Chaos Mesh |

### Command Cheat Sheet

```bash
# Python
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pytest -v --cov=src tests/

# Docker
docker build -t app:latest .
docker-compose up -d
docker logs -f container_name

# Kubernetes
kubectl apply -f manifests/
kubectl get pods -n namespace
kubectl logs -f deployment/app
kubectl port-forward svc/app 8080:80

# Terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Git
git checkout -b feature/new-feature
git add . && git commit -m "feat: add feature"
git push -u origin feature/new-feature
```

---

## 🏆 Congratulations!

You have completed the **Elite Python for DevOps Roadmap**!

By following this comprehensive guide, you have developed expertise in:

- **Python Programming**: From fundamentals to advanced patterns
- **Automation**: System, network, and cloud automation
- **Containers**: Docker and Kubernetes mastery
- **Cloud Platforms**: AWS, GCP, Azure proficiency
- **Infrastructure as Code**: Terraform and configuration management
- **CI/CD**: End-to-end pipeline design and implementation
- **Observability**: Metrics, logs, traces, and SLOs
- **Security**: DevSecOps and compliance automation
- **Platform Engineering**: GitOps, service mesh, chaos engineering
- **Leadership**: Architecture decisions and team enablement

**Next Steps**:
1. Complete remaining capstone projects
2. Contribute to open source
3. Pursue relevant certifications
4. Share knowledge through blogs/talks
5. Mentor others on their DevOps journey

---

*This roadmap was designed to take you from beginner to elite-level Python DevOps engineer. Continue learning, building, and sharing!*

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Python Core for DevOps
- Linux System Administration with Python
- Command-Line Tool Development
- Data Processing and APIs

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
