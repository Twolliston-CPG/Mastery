# Python for DevOps - Hands-On Learning Path

A comprehensive, project-based learning environment to master Python for DevOps automation. Based on the Python for DevOps roadmap, this repository contains working scripts, projects, and labs for each phase.

## Quick Start

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or: venv\Scripts\activate  # Windows

# Install common dependencies
pip install requests pyyaml click psutil pytest docker
```

## Repository Structure

**`python-for-devops/`**

- `PYTHON_DEVOPS_ROADMAP.md` — Complete learning roadmap
- `README.md` — This file
- `phase1_python_core/` — Phase 1: Python Fundamentals
  - `labs/` — Micro-labs (15-30 min each)
    - `lab1_1_environment_verification.py`
    - `lab1_2_server_inventory.py`
    - `lab1_3_health_check_retry.py`
    - `lab1_4_decorator_toolkit.py`
    - `lab1_5_log_analyzer.py`
    - `lab1_6_config_sanitizer.py`
    - `lab1_7_robust_config_loader.py`
  - `projects/`
    - `devops_toolkit/` — Complete DevOps toolkit package
- `phase2_linux_admin/` — Phase 2: Linux Administration
  - `labs/`
    - `lab2_1_disk_monitor.py`
    - `lab2_2_process_manager.py`
    - `lab2_3_user_provisioning.py`
    - `lab2_4_service_dashboard.py`
- `phase3_cli_tools/` — Phase 3: CLI Development
  - `labs/`
    - `lab3_1_argparse_cli.py`
    - `lab3_2_click_cli.py`
- `phase4_data_apis/` — Phase 4: Data & APIs
  - `labs/`
    - `lab4_1_rest_api_client.py`
- `phase5_testing/` — Phase 5: Testing
  - `labs/`
    - `lab5_1_pytest_basics.py`
- `phase6_docker/` — Phase 6: Docker
  - `labs/`
    - `lab6_1_docker_automation.py`


## Phase Contents

### Phase 1: Python Core for DevOps (2-3 weeks)

**Objective:** Build strong Python fundamentals for automation tasks.

| Lab | Topic | Key Concepts |
|-----|-------|--------------|
| 1.1 | Environment Verification | Virtual environments, sys module, os module |
| 1.2 | Server Inventory | Data structures, type hints, set operations |
| 1.3 | Health Check with Retry | Generators, exponential backoff, exception handling |
| 1.4 | Decorator Toolkit | @timed, @retry, @logged, @cached decorators |
| 1.5 | Log Analyzer | pathlib, file I/O, dataclasses, regex |
| 1.6 | Config Sanitizer | Regex patterns, sensitive data detection |
| 1.7 | Robust Config Loader | Custom exceptions, schema validation |

**Project:** DevOps Toolkit - A complete Python package with config loading, logging, decorators, and utilities.

```bash
cd phase1_python_core/labs
python lab1_1_environment_verification.py
```

### Phase 2: Linux System Administration (2 weeks)

**Objective:** Automate common Linux administration tasks.

| Lab | Topic | Key Concepts |
|-----|-------|--------------|
| 2.1 | Disk Monitor | shutil.disk_usage, threshold alerts |
| 2.2 | Process Manager | psutil, process lifecycle, graceful shutdown |
| 2.3 | User Provisioning | pwd/grp modules, YAML config, idempotent operations |
| 2.4 | Service Dashboard | systemd/launchd interaction, health monitoring |

```bash
cd phase2_linux_admin/labs
python lab2_1_disk_monitor.py
```

### Phase 3: CLI Tool Development (1-2 weeks)

**Objective:** Build professional command-line tools.

| Lab | Topic | Key Concepts |
|-----|-------|--------------|
| 3.1 | argparse CLI | Subcommands, arguments, help text |
| 3.2 | Click CLI | Decorators, colored output, progress bars |

```bash
cd phase3_cli_tools/labs
python lab3_1_argparse_cli.py --help
python lab3_2_click_cli.py --help
```

### Phase 4: Data Processing and APIs (2 weeks)

**Objective:** Work with APIs and process data at scale.

| Lab | Topic | Key Concepts |
|-----|-------|--------------|
| 4.1 | REST API Client | requests, authentication, error handling, rate limiting |

```bash
cd phase4_data_apis/labs
python lab4_1_rest_api_client.py
```

### Phase 5: Testing for DevOps (1-2 weeks)

**Objective:** Write reliable tests for automation code.

| Lab | Topic | Key Concepts |
|-----|-------|--------------|
| 5.1 | pytest Basics | Fixtures, parametrization, mocking |

```bash
cd phase5_testing/labs
pytest lab5_1_pytest_basics.py -v
```

### Phase 6: Docker Containerization (2 weeks)

**Objective:** Automate Docker operations with Python.

| Lab | Topic | Key Concepts |
|-----|-------|--------------|
| 6.1 | Docker Automation | docker-py SDK, container lifecycle, image management |

```bash
cd phase6_docker/labs
python lab6_1_docker_automation.py
```

## Running the Labs

Each lab is a standalone script that can be run directly:

```bash
# Run any lab
python phase1_python_core/labs/lab1_1_environment_verification.py

# Run tests
pytest phase5_testing/labs/lab5_1_pytest_basics.py -v

# Install Phase 1 toolkit
cd phase1_python_core/projects/devops_toolkit
pip install -e .
```

## Prerequisites by Phase

| Phase | Requirements |
|-------|-------------|
| 1 | Python 3.9+, pyyaml |
| 2 | psutil (Linux/macOS recommended) |
| 3 | click |
| 4 | requests |
| 5 | pytest, pytest-cov |
| 6 | docker, Docker daemon |

Install all:
```bash
pip install pyyaml psutil click requests pytest pytest-cov docker
```

## Learning Path

1. **Start with Phase 1** - Complete all labs to build Python fundamentals
2. **Build the DevOps Toolkit** - Complete the Phase 1 project
3. **Progress sequentially** - Each phase builds on previous knowledge
4. **Practice daily** - Spend 1-2 hours per day on labs
5. **Apply to real projects** - Modify scripts for your environment

## Common Patterns Used

### Error Handling with Retry
```python
@retry(max_attempts=3, delay=1.0, exceptions=(ConnectionError,))
def connect_to_server():
    ...
```

### Configuration with Validation
```python
schema = ConfigSchema()
schema.add_field("port", int, min_value=1, max_value=65535)
config = load_config(Path("config.yaml"), schema)
```

### Logging Setup
```python
logger = setup_logging(level="INFO", json_format=True)
```

### CLI with Click
```python
@click.command()
@click.option('--env', type=click.Choice(['dev', 'prod']))
def deploy(env):
    ...
```

## Contributing

Feel free to add more labs, improve existing scripts, or fix bugs. Each lab should:

1. Be self-contained and runnable
2. Include comprehensive docstrings
3. Demonstrate real DevOps use cases
4. Handle errors gracefully

## Resources

- **Books Referenced:**
  - "Python for DevOps" (O'Reilly) - [ORA]
  - "Python for DevOps: Master Automation" (BPB) - [BPB]

- **Official Documentation:**
  - [Python Docs](https://docs.python.org/3/)
  - [Click](https://click.palletsprojects.com/)
  - [Docker SDK](https://docker-py.readthedocs.io/)

## License

MIT License - Feel free to use these scripts for learning and in your projects.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Repository Structure
- Phase Contents
- Running the Labs
- Prerequisites by Phase

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
