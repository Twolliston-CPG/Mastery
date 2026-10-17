# Lab 01: Docker Installation and First Container

## Objectives

- Install Docker on a Linux system
- Configure Docker daemon
- Run your first container
- Understand basic Docker commands

## Prerequisites

- Linux VM (Ubuntu 22.04 recommended)
- sudo/root access
- Basic command-line knowledge

## Lab Environment

Use AWS/GCP free tier or local VM with:
- 2 vCPUs
- 4GB RAM
- 20GB disk

---

## Part 1: Docker Installation (Guided)

### Step 1: Update System

```bash
# Update package index
sudo apt-get update
sudo apt-get upgrade -y

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

### Step 2: Add Docker Repository

```bash
# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Step 3: Install Docker Engine

```bash
# Update package index
sudo apt-get update

# Install Docker
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
docker --version
sudo docker run hello-world
```

### Step 4: Configure Non-Root Access

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes (or log out/in)
newgrp docker

# Verify
docker run hello-world
```

### Validation

```bash
#!/bin/bash
# validate-part1.sh

echo "=== Docker Installation Validation ==="

# Check Docker installed
if command -v docker &> /dev/null; then
    echo "✓ Docker is installed: $(docker --version)"
else
    echo "✗ Docker is not installed"
    exit 1
fi

# Check Docker daemon running
if systemctl is-active --quiet docker; then
    echo "✓ Docker daemon is running"
else
    echo "✗ Docker daemon is not running"
    exit 1
fi

# Check non-root access
if docker ps &> /dev/null; then
    echo "✓ Non-root access configured"
else
    echo "✗ Cannot run docker as non-root user"
    exit 1
fi

# Run test container
if docker run --rm hello-world &> /dev/null; then
    echo "✓ Successfully ran test container"
else
    echo "✗ Failed to run test container"
    exit 1
fi

echo ""
echo "All checks passed!"
```

---

## Part 2: Docker Daemon Configuration (Semi-Guided)

### Objective

Configure Docker daemon with custom settings for logging, storage, and networking.

### Tasks

1. Create daemon configuration file at `/etc/docker/daemon.json`
2. Configure the following settings:
   - JSON logging driver with max 10MB files, keep 3 files
   - Default address pool: 172.20.0.0/16
   - Enable live-restore
   - Set storage driver to overlay2
3. Restart Docker daemon and verify configuration

### Hints

<details>
<summary>Configuration Structure</summary>

```json
{
  "log-driver": "json-file",
  "log-opts": { },
  "storage-driver": "...",
  "live-restore": true,
  "default-address-pools": [{ }]
}
```
</details>

<details>
<summary>Restart Commands</summary>

```bash
sudo systemctl restart docker
docker info | grep -E "(Storage|Logging|Address)"
```
</details>

### Validation

```bash
#!/bin/bash
# validate-part2.sh

echo "=== Daemon Configuration Validation ==="

# Check config file exists
if [ -f /etc/docker/daemon.json ]; then
    echo "✓ daemon.json exists"
else
    echo "✗ daemon.json not found"
    exit 1
fi

# Check logging driver
LOG_DRIVER=$(docker info --format '{{.LoggingDriver}}')
if [ "$LOG_DRIVER" = "json-file" ]; then
    echo "✓ Logging driver: $LOG_DRIVER"
else
    echo "✗ Expected json-file logging driver"
fi

# Check storage driver
STORAGE=$(docker info --format '{{.Driver}}')
if [ "$STORAGE" = "overlay2" ]; then
    echo "✓ Storage driver: $STORAGE"
else
    echo "✗ Expected overlay2 storage driver"
fi

# Check live-restore
if docker info | grep -q "Live Restore Enabled: true"; then
    echo "✓ Live restore enabled"
else
    echo "✗ Live restore not enabled"
fi

echo ""
echo "Validation complete!"
```

---

## Part 3: Container Operations (Semi-Guided)

### Objective

Practice running containers with various options.

### Tasks

1. Run nginx container:
   - Detached mode
   - Name: web-server
   - Port 80 mapped to 8080
   - Automatic restart on failure

2. Run Alpine container interactively and install curl

3. View container logs, stats, and processes

4. Stop, start, and remove containers

### Commands Reference

```bash
# Run detached container
docker run -d --name <name> -p <host>:<container> <image>

# Run interactive container
docker run -it <image> <shell>

# Container management
docker logs <container>
docker stats <container>
docker top <container>
docker stop <container>
docker start <container>
docker rm <container>
```

### Validation

```bash
#!/bin/bash
# validate-part3.sh

echo "=== Container Operations Validation ==="

# Check nginx running
if docker ps --format '{{.Names}}' | grep -q "web-server"; then
    echo "✓ web-server container is running"

    # Check port mapping
    PORT=$(docker port web-server 80/tcp)
    if echo "$PORT" | grep -q "8080"; then
        echo "✓ Port 80 mapped to 8080"
    else
        echo "✗ Port mapping incorrect"
    fi
else
    echo "✗ web-server container not found"
fi

# Test web server
if curl -s localhost:8080 | grep -q "nginx"; then
    echo "✓ Web server responding"
else
    echo "✗ Web server not responding"
fi

echo ""
echo "Validation complete!"
```

---

## Part 4: Challenge - Complete Docker Setup

### Objective

Set up a complete Docker environment with custom configuration and security hardening.

### Requirements

1. Configure Docker daemon with:
   - Remote API access on port 2375 (localhost only)
   - Userland proxy disabled
   - Default ulimits (nofile: 65535)
   - Insecure registry for localhost:5000

2. Create and run a local registry container:
   - Name: local-registry
   - Port 5000
   - Persistent volume for storage

3. Pull, tag, and push an image to local registry

4. Run a container from your local registry

5. Create a cleanup script that:
   - Stops all running containers
   - Removes stopped containers
   - Removes unused images
   - Removes unused volumes
   - Shows disk usage before/after

### Validation Script

```bash
#!/bin/bash
# validate-challenge.sh

echo "=== Challenge Validation ==="

# Check remote API (localhost only)
if curl -s http://localhost:2375/version | grep -q "ApiVersion"; then
    echo "✓ Remote API accessible on localhost"
else
    echo "✗ Remote API not accessible"
fi

# Check local registry
if docker ps --format '{{.Names}}' | grep -q "local-registry"; then
    echo "✓ Local registry running"

    # Check registry volume
    if docker inspect local-registry | grep -q '"Type": "volume"'; then
        echo "✓ Registry using volume storage"
    else
        echo "✗ Registry not using volume"
    fi
else
    echo "✗ Local registry not running"
fi

# Check image in local registry
CATALOG=$(curl -s http://localhost:5000/v2/_catalog)
if echo "$CATALOG" | grep -q "repositories"; then
    echo "✓ Registry catalog accessible"
    echo "  Images: $CATALOG"
else
    echo "✗ Cannot access registry catalog"
fi

# Check cleanup script exists
if [ -f cleanup.sh ]; then
    echo "✓ Cleanup script exists"
else
    echo "✗ Cleanup script not found"
fi

echo ""
echo "Challenge validation complete!"
```

---

## Deliverables

1. Docker installed and configured
2. daemon.json with custom configuration
3. Running local registry with pushed image
4. cleanup.sh script
5. Screenshot of `docker info` output

## Resources

- [Docker Installation Guide](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Daemon Configuration](https://docs.docker.com/engine/reference/commandline/dockerd/)
- [Docker Registry](https://docs.docker.com/registry/)

## Next Lab

Continue to [Lab 02: Image Management](lab-02-image-management-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Docker Installation
- Docker Daemon Configuration
- Container Operations
- Challenge - Complete Docker Setup

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"A container isolates the application."* |
| ✓ | *"A container is an ordinary Linux process started with namespaces (what it can see), cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is no container object in the kernel — only a process with those features switched on."* |

**Trace it:** `docker run` → an isolated process. Name the namespaces in the order they are created, and which component actually calls `clone()`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#containers)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
