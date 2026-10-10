# Lab 03: Container Operations

## Objectives

- Master container lifecycle management
- Work with container logs and debugging
- Understand resource constraints
- Practice container troubleshooting

## Prerequisites

- Completed Labs 01-02
- Docker installed and configured

---

## Part 1: Container Lifecycle (Guided)

### Step 1: Container States

```bash
# Create a container (does not start)
docker create --name lifecycle-demo nginx:alpine
docker ps -a --filter name=lifecycle-demo

# Start the container
docker start lifecycle-demo
docker ps --filter name=lifecycle-demo

# Pause the container
docker pause lifecycle-demo
docker ps --filter name=lifecycle-demo

# Unpause
docker unpause lifecycle-demo

# Stop gracefully (SIGTERM, then SIGKILL after timeout)
docker stop lifecycle-demo

# Start again
docker start lifecycle-demo

# Restart
docker restart lifecycle-demo

# Kill (SIGKILL immediately)
docker kill lifecycle-demo

# Remove
docker rm lifecycle-demo
```

### Step 2: Auto-Restart Policies

```bash
# Always restart
docker run -d --name always-restart --restart always nginx:alpine

# Restart on failure (max 3 times)
docker run -d --name on-failure --restart on-failure:3 nginx:alpine

# Restart unless stopped manually
docker run -d --name unless-stopped --restart unless-stopped nginx:alpine

# View restart count
docker inspect --format '{{.RestartCount}}' always-restart

# Test restart
docker exec always-restart kill 1
sleep 2
docker ps --filter name=always-restart

# Cleanup
docker rm -f always-restart on-failure unless-stopped
```

### Step 3: Environment Variables and Working Directory

```bash
# Run with environment variables
docker run -d --name env-demo \
  -e APP_NAME="My App" \
  -e APP_ENV=production \
  -e DATABASE_URL="postgres://db:5432" \
  --env-file <(echo "SECRET_KEY=abc123") \
  nginx:alpine

# View environment
docker exec env-demo env | grep APP

# Working directory
docker run --rm -w /custom/path alpine pwd

# Cleanup
docker rm -f env-demo
```

### Validation

```bash
#!/bin/bash
# validate-part1.sh

echo "=== Part 1 Validation ==="

# Test restart policy
docker run -d --name restart-test --restart on-failure:3 alpine sh -c "exit 1"
sleep 5
COUNT=$(docker inspect --format '{{.RestartCount}}' restart-test)
docker rm -f restart-test

if [ "$COUNT" = "3" ]; then
    echo "✓ Restart policy works correctly (count: $COUNT)"
else
    echo "! Restart count: $COUNT (expected 3)"
fi

echo "Part 1 validation complete!"
```

---

## Part 2: Logs and Debugging (Semi-Guided)

### Objective

Master container logging and debugging techniques.

### Tasks

1. Run a container that generates logs every second
2. View logs with different options (follow, tail, since, timestamps)
3. Configure logging driver for JSON with size limits
4. Use docker exec for debugging

### Step 1: Create Logging Application

```bash
# Run container that logs every second
docker run -d --name log-demo alpine sh -c '
i=0
while true; do
  i=$((i + 1))
  echo "[$(date -Iseconds)] Log entry $i - Status: OK"
  if [ $((i % 5)) -eq 0 ]; then
    echo "[$(date -Iseconds)] Log entry $i - Status: WARNING" >&2
  fi
  sleep 1
done
'
```

### Commands to Practice

```bash
# Follow logs
docker logs -f log-demo

# Last 10 lines
docker logs --tail 10 log-demo

# Logs with timestamps
docker logs -t log-demo

# Logs since specific time
docker logs --since 30s log-demo

# Separate stdout/stderr
docker logs log-demo 2>/dev/null  # stdout only
docker logs log-demo 2>&1 1>/dev/null  # stderr only
```

### Step 2: Debug with exec

```bash
# Interactive shell
docker exec -it log-demo sh

# Run specific command
docker exec log-demo ps aux
docker exec log-demo cat /etc/os-release

# As different user
docker exec -u root log-demo whoami

# With environment variable
docker exec -e MY_VAR=value log-demo env

# Cleanup
docker rm -f log-demo
```

### Validation

```bash
#!/bin/bash
# validate-part2.sh

echo "=== Part 2 Validation ==="

# Create test container with custom log driver
docker run -d --name log-test \
  --log-driver json-file \
  --log-opt max-size=1m \
  --log-opt max-file=3 \
  alpine sh -c 'while true; do echo "test log"; sleep 0.1; done'

sleep 3

# Verify logs exist
if docker logs --tail 5 log-test | grep -q "test log"; then
    echo "✓ Container logging works"
else
    echo "✗ Container logging failed"
fi

# Verify log options
LOG_CONFIG=$(docker inspect --format '{{.HostConfig.LogConfig.Config}}' log-test)
if echo "$LOG_CONFIG" | grep -q "max-size"; then
    echo "✓ Log options configured"
else
    echo "✗ Log options not found"
fi

docker rm -f log-test

echo "Part 2 validation complete!"
```

---

## Part 3: Resource Constraints (Semi-Guided)

### Objective

Configure and monitor container resource limits.

### Tasks

1. Run containers with memory limits
2. Run containers with CPU limits
3. Monitor resource usage with docker stats
4. Test OOM (Out of Memory) behavior

### Commands Reference

```bash
# Memory limits
docker run -d --name mem-test --memory=100m --memory-swap=100m nginx

# CPU limits
docker run -d --name cpu-test --cpus=0.5 nginx  # 50% of one CPU
docker run -d --name cpu-shares --cpu-shares=512 nginx  # Relative weight

# Combined limits
docker run -d --name limited \
  --memory=256m \
  --memory-swap=256m \
  --cpus=0.5 \
  --pids-limit=100 \
  nginx

# Monitor resources
docker stats
docker stats --no-stream
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Update limits on running container
docker update --memory=512m --cpus=1 limited
```

### OOM Test

```bash
# Create container with strict memory limit
docker run -d --name oom-test \
  --memory=50m \
  --memory-swap=50m \
  alpine sh -c '
    # Allocate memory until OOM
    dd if=/dev/zero of=/dev/null bs=1M &
    sleep 60
  '

# Watch for OOM
docker inspect --format '{{.State.OOMKilled}}' oom-test
docker logs oom-test
```

### Validation

```bash
#!/bin/bash
# validate-part3.sh

echo "=== Part 3 Validation ==="

# Run limited container
docker run -d --name limit-test \
  --memory=128m \
  --cpus=0.25 \
  nginx:alpine

sleep 2

# Verify memory limit
MEM_LIMIT=$(docker inspect --format '{{.HostConfig.Memory}}' limit-test)
if [ "$MEM_LIMIT" = "134217728" ]; then  # 128MB in bytes
    echo "✓ Memory limit set correctly (128MB)"
else
    echo "✗ Memory limit incorrect: $MEM_LIMIT"
fi

# Verify CPU limit
CPU_LIMIT=$(docker inspect --format '{{.HostConfig.NanoCpus}}' limit-test)
if [ "$CPU_LIMIT" = "250000000" ]; then  # 0.25 CPU
    echo "✓ CPU limit set correctly (0.25 CPUs)"
else
    echo "✗ CPU limit incorrect: $CPU_LIMIT"
fi

docker rm -f limit-test

echo "Part 3 validation complete!"
```

---

## Part 4: Challenge - Troubleshooting

### Scenario

You're given several problematic containers to debug and fix.

### Challenge 1: Container Won't Start

```bash
# This container fails to start - find out why and fix it
docker run -d --name broken1 \
  --memory=10m \
  nginx:alpine
```

### Challenge 2: Application Not Responding

```bash
# This container starts but the application doesn't respond
docker run -d --name broken2 \
  -p 8080:80 \
  --health-cmd="curl -f http://localhost:80 || exit 1" \
  --health-interval=5s \
  alpine sh -c "tail -f /dev/null"
```

### Challenge 3: High Resource Usage

```bash
# This container uses too many resources - identify and constrain it
docker run -d --name broken3 \
  alpine sh -c '
    # CPU-intensive task
    while true; do
      dd if=/dev/urandom of=/dev/null bs=1M count=100 2>/dev/null
    done
  '
```

### Challenge 4: Log Investigation

Create a debugging report that includes:

1. Container state and health status
2. Resource usage (CPU, memory)
3. Process list inside container
4. Recent logs with errors
5. Network configuration
6. Mounted volumes

### Investigation Script Template

```bash
#!/bin/bash
# investigate.sh

CONTAINER=$1

if [ -z "$CONTAINER" ]; then
    echo "Usage: $0 <container_name>"
    exit 1
fi

echo "=== Container Investigation Report ==="
echo "Container: $CONTAINER"
echo "Generated: $(date)"
echo ""

echo "=== State ==="
docker inspect --format 'Status: {{.State.Status}}
Running: {{.State.Running}}
Exit Code: {{.State.ExitCode}}
OOMKilled: {{.State.OOMKilled}}' $CONTAINER

# Add more sections...
```

### Validation

```bash
#!/bin/bash
# validate-challenge.sh

echo "=== Challenge Validation ==="

# Check investigation script exists
if [ -f investigate.sh ] && [ -x investigate.sh ]; then
    echo "✓ Investigation script exists and is executable"
else
    echo "✗ Investigation script not found or not executable"
fi

# Check broken1 is fixed and running
if docker ps --filter name=broken1-fixed --format '{{.Status}}' | grep -q "Up"; then
    echo "✓ Challenge 1: Container running"
else
    echo "✗ Challenge 1: Container not running"
fi

# Check broken3 has resource limits
CPU=$(docker inspect --format '{{.HostConfig.NanoCpus}}' broken3-fixed 2>/dev/null || echo "0")
MEM=$(docker inspect --format '{{.HostConfig.Memory}}' broken3-fixed 2>/dev/null || echo "0")

if [ "$CPU" != "0" ] && [ "$MEM" != "0" ]; then
    echo "✓ Challenge 3: Resource limits applied"
else
    echo "✗ Challenge 3: Resource limits not found"
fi

echo ""
echo "Challenge validation complete!"
```

---

## Deliverables

1. Understanding of container lifecycle states
2. Log investigation script
3. Fixed containers from challenges
4. Investigation report template

## Commands Reference

```bash
# Lifecycle
docker create/start/stop/restart/kill/rm/pause/unpause

# Inspection
docker ps/inspect/logs/stats/top/port

# Debugging
docker exec/attach/cp/diff/export

# Updates
docker update/rename/commit
```

## Resources

- [Docker Run Reference](https://docs.docker.com/engine/reference/run/)
- [Container Logging](https://docs.docker.com/config/containers/logging/)
- [Runtime Constraints](https://docs.docker.com/config/containers/resource_constraints/)

## Next Lab

Continue to [Lab 04: Docker Networking](../lab-04-docker-networking/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Container Lifecycle
- Logs and Debugging
- Resource Constraints
- Challenge - Troubleshooting

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
