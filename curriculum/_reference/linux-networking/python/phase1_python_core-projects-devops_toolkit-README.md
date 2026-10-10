# DevOps Toolkit

A Python package providing reusable components for DevOps automation.

## Installation

```bash
cd phase1_python_core/projects/devops_toolkit
pip install -e .
```

Or install dependencies directly:

```bash
pip install pyyaml pytest
```

## Features

### Configuration Management

Load and validate JSON/YAML configuration files with schema validation.

```python
from pathlib import Path
from devops_toolkit import load_config, ConfigSchema

# Define schema
schema = ConfigSchema()
schema.add_field("name", str, required=True)
schema.add_field("port", int, min_value=1, max_value=65535, default=8080)
schema.add_field("environment", str, allowed_values=["dev", "staging", "prod"])

# Load and validate
config = load_config(Path("config.yaml"), schema)
print(f"App: {config['name']} on port {config['port']}")
```

### Structured Logging

Set up consistent logging across all scripts.

```python
from devops_toolkit import setup_logging, get_logger

# Setup with JSON format for production
logger = setup_logging(
    level="INFO",
    log_file=Path("/var/log/app.log"),
    json_format=True,
    extra_fields={"app": "my-service", "version": "1.0.0"}
)

logger.info("Application started")
```

### Utility Decorators

Reusable decorators for common patterns.

```python
from devops_toolkit.utils import timed, retry, logged, cached

@logged
@timed
@retry(max_attempts=3, delay=1.0, exceptions=(ConnectionError,))
def fetch_data(url: str) -> dict:
    """Fetch data with retry, timing, and logging."""
    response = requests.get(url)
    return response.json()

@cached(ttl_seconds=300)
def get_config(service: str) -> dict:
    """Cache config for 5 minutes."""
    return fetch_config_from_remote(service)
```

### Regex Patterns

Pre-compiled patterns for DevOps tasks.

```python
from devops_toolkit.utils import PATTERNS, extract_ips, parse_log_line

# Extract IPs from text
log_text = "Connection from 192.168.1.1 to 10.0.0.5"
ips = extract_ips(log_text)  # ['192.168.1.1', '10.0.0.5']

# Parse log lines
entry = parse_log_line("2024-01-15 10:30:00 ERROR Database connection failed")
print(f"{entry.level}: {entry.message}")

# Validate versions
from devops_toolkit.utils.patterns import is_valid_semver, parse_semver
version = parse_semver("1.2.3-beta+build.123")
print(f"Major: {version.major}")
```

### Custom Exceptions

Consistent error handling across scripts.

```python
from devops_toolkit.exceptions import (
    ConfigNotFoundError,
    ConfigValidationError,
    ServiceUnavailableError,
)

try:
    config = load_config(Path("missing.yaml"))
except ConfigNotFoundError as e:
    print(f"Config file not found: {e.path}")
except ConfigValidationError as e:
    for error in e.errors:
        print(f"Validation error: {error}")
```

## Package Structure

**`devops_toolkit/`**

- `__init__.py` — Public API exports
- `exceptions.py` — Custom exception hierarchy
- `config/`
  - `__init__.py`
  - `loader.py` — Config file loading
  - `schema.py` — Schema validation
- `logging/`
  - `__init__.py`
  - `setup.py` — Logging configuration
- `utils/`
  - `__init__.py`
  - `decorators.py` — @timed, @retry, @logged, @cached
  - `filesystem.py` — File operations
  - `patterns.py` — Regex patterns
- `tests/`
  - `__init__.py`
  - `test_config.py`
  - `test_decorators.py`


## Running Tests

```bash
cd phase1_python_core/projects/devops_toolkit
pytest tests/ -v
```

## Usage Examples

### Complete Script Example

```python
#!/usr/bin/env python3
"""Example DevOps script using the toolkit."""

from pathlib import Path
from devops_toolkit import load_config, setup_logging, ConfigSchema
from devops_toolkit.utils import retry, timed
from devops_toolkit.exceptions import ConfigError, ServiceUnavailableError

# Setup logging
logger = setup_logging(level="INFO", colored=True)

# Define config schema
schema = ConfigSchema()
schema.add_field("services", list, required=True)
schema.add_field("timeout", int, default=30)
schema.add_field("environment", str, allowed_values=["dev", "staging", "prod"])

@timed
@retry(max_attempts=3, delay=2.0, exceptions=(ConnectionError,))
def check_service(service: str, timeout: int) -> bool:
    """Check if service is healthy."""
    logger.info(f"Checking {service}...")
    # Actual health check implementation here
    return True

def main():
    try:
        # Load configuration
        config = load_config(Path("config.yaml"), schema)
        logger.info(f"Loaded config for {config['environment']}")

        # Check all services
        for service in config["services"]:
            try:
                healthy = check_service(service, config["timeout"])
                status = "healthy" if healthy else "unhealthy"
                logger.info(f"{service}: {status}")
            except Exception as e:
                logger.error(f"{service}: check failed - {e}")

    except ConfigError as e:
        logger.error(f"Configuration error: {e}")
        raise SystemExit(1)

if __name__ == "__main__":
    main()
```

## License

MIT License

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Package Structure
- Configuration Management
- Structured Logging
- Utility Decorators

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
