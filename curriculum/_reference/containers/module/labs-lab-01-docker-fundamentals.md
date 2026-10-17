# Lab 3.1: Docker Fundamentals

> **Duration:** 60-90 minutes
> **Environment:** Docker installed locally
> **Difficulty:** Beginner

---

## Objectives

- Understand Docker architecture
- Run and manage containers
- Work with images and registries
- Inspect and debug containers

---

## Prerequisites

```bash
# Verify Docker installation
docker version
docker info
```

---

## Part 1: Running Containers

### Exercise 1.1: Your First Container

```bash
# Run a simple container
docker run hello-world

# Understanding what happened:
# 1. Docker looked for 'hello-world' image locally
# 2. Pulled it from Docker Hub (registry)
# 3. Created a container from the image
# 4. Ran the container (printed message)
# 5. Container exited

# List running containers
docker ps
# (empty - hello-world already exited)

# List all containers (including stopped)
docker ps -a
# Shows hello-world container with "Exited" status
```

### Exercise 1.2: Interactive Containers

```bash
# Run Ubuntu interactively
docker run -it ubuntu:22.04 bash

# Inside the container:
cat /etc/os-release
whoami
ls -la /
ps aux
exit

# Run Alpine (smaller)
docker run -it alpine sh
cat /etc/os-release
apk add curl
curl --version
exit
```

### Exercise 1.3: Detached Containers

```bash
# Run nginx in background
docker run -d --name web nginx:1.25

# Verify it's running
docker ps

# View logs
docker logs web
docker logs -f web  # Follow logs (Ctrl+C to stop)

# Get container details
docker inspect web | head -50

# Stop the container
docker stop web

# Start it again
docker start web

# Remove (must be stopped first)
docker stop web
docker rm web

# Force remove running container
docker rm -f web
```

### Exercise 1.4: Port Mapping

```bash
# Run nginx with port mapping
docker run -d --name web -p 8080:80 nginx:1.25

# Access it
curl http://localhost:8080

# View port mappings
docker port web

# Run multiple on different ports
docker run -d --name web2 -p 8081:80 nginx:1.25
docker run -d --name web3 -p 8082:80 nginx:1.25

curl http://localhost:8081
curl http://localhost:8082

# Clean up
docker rm -f web web2 web3
```

---

## Part 2: Working with Images

### Exercise 2.1: Image Management

```bash
# List images
docker images

# Pull specific version
docker pull nginx:1.24
docker pull nginx:1.25

# List nginx images
docker images nginx

# Remove image
docker rmi nginx:1.24

# Remove all unused images
docker image prune

# Show image history (layers)
docker history nginx:1.25

# Inspect image
docker inspect nginx:1.25 | head -100
```

### Exercise 2.2: Image Layers

```bash
# Create a simple Dockerfile
mkdir -p ~/docker-lab/layers
cd ~/docker-lab/layers

cat > Dockerfile << 'EOF'
FROM alpine:3.19
RUN apk add --no-cache curl
RUN echo "Hello" > /hello.txt
CMD ["cat", "/hello.txt"]
EOF

# Build and observe layers
docker build -t layer-test .

# View layers
docker history layer-test

# Modify and rebuild
cat >> Dockerfile << 'EOF'
RUN echo "World" >> /hello.txt
EOF

docker build -t layer-test:v2 .

# Notice cached layers
docker history layer-test:v2
```

### Exercise 2.3: Working with Registries

```bash
# Tag image for a registry
docker tag layer-test:v2 myusername/layer-test:v2

# Login to Docker Hub (requires account)
# docker login

# Push to registry
# docker push myusername/layer-test:v2

# Pull from registry
# docker pull myusername/layer-test:v2

# Use a different registry (example: GitHub Container Registry)
# docker tag layer-test:v2 ghcr.io/myusername/layer-test:v2
# docker push ghcr.io/myusername/layer-test:v2
```

---

## Part 3: Container Lifecycle

### Exercise 3.1: Container States

```bash
# Create container without starting
docker create --name mycontainer alpine echo "Hello"

# List all containers
docker ps -a
# Status: Created

# Start the container
docker start mycontainer

docker ps -a
# Status: Exited (0) - it ran and completed

# View output
docker logs mycontainer

# Restart (runs again)
docker start mycontainer
docker logs mycontainer
# Shows "Hello" twice now

# Remove
docker rm mycontainer
```

### Exercise 3.2: Resource Limits

```bash
# Run with memory limit
docker run -d --name limited \
    --memory 100m \
    --cpus 0.5 \
    nginx:1.25

# Check resource usage
docker stats limited --no-stream

# View limits
docker inspect limited | grep -A 10 "Memory"

# Clean up
docker rm -f limited
```

### Exercise 3.3: Environment Variables

```bash
# Pass environment variables
docker run -d --name envtest \
    -e MY_VAR="hello" \
    -e ANOTHER_VAR="world" \
    alpine sleep 3600

# Check variables inside
docker exec envtest env

# Using env file
cat > ~/docker-lab/env.list << 'EOF'
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=myapp
EOF

docker run -d --name envfiletest \
    --env-file ~/docker-lab/env.list \
    alpine sleep 3600

docker exec envfiletest env | grep DATABASE

# Clean up
docker rm -f envtest envfiletest
```

---

## Part 4: Debugging Containers

### Exercise 4.1: Logs and Exec

```bash
# Run a container that generates logs
docker run -d --name logtest nginx:1.25

# Make some requests
curl http://localhost 2>/dev/null || true

# View logs
docker logs logtest

# Follow logs
docker logs -f logtest &
# Make another request, see it appear
curl http://localhost 2>/dev/null || true
# Ctrl+C to stop

# Shell into running container
docker exec -it logtest bash

# Inside the container
cat /etc/nginx/nginx.conf
ls -la /var/log/nginx/
cat /var/log/nginx/access.log
exit

# Run a command without shell
docker exec logtest cat /etc/nginx/nginx.conf

docker rm -f logtest
```

### Exercise 4.2: Inspect and Stats

```bash
# Run a container
docker run -d --name inspect-test nginx:1.25

# Full inspection
docker inspect inspect-test > inspect-output.json

# Get specific fields
docker inspect -f '{{.NetworkSettings.IPAddress}}' inspect-test
docker inspect -f '{{.State.Pid}}' inspect-test
docker inspect -f '{{json .Config.Env}}' inspect-test | jq

# View resource usage
docker stats inspect-test --no-stream

# View processes
docker top inspect-test

# Clean up
docker rm -f inspect-test
```

### Exercise 4.3: Troubleshooting Failed Containers

```bash
# Create a failing container
docker run -d --name failing-app alpine sh -c "echo 'Starting...' && sleep 2 && exit 1"

# Wait for it to fail
sleep 3
docker ps -a | grep failing

# Check logs
docker logs failing-app

# Create a container that won't start
cat > ~/docker-lab/bad-dockerfile << 'EOF'
FROM alpine
CMD ["nonexistent-command"]
EOF

docker build -t bad-app -f ~/docker-lab/bad-dockerfile ~/docker-lab/
docker run --name bad-run bad-app

# Check status
docker ps -a | grep bad-run
docker logs bad-run

# Debug by overriding command
docker run -it bad-app sh
# Now you can investigate
which nonexistent-command
exit

# Clean up
docker rm -f failing-app bad-run
```

---

## Part 5: Practical Exercises

### Exercise 5.1: Run a Database

```bash
# Run PostgreSQL
docker run -d \
    --name postgres \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=testdb \
    -p 5432:5432 \
    postgres:16-alpine

# Wait for startup
sleep 5

# Connect to database
docker exec -it postgres psql -U admin -d testdb

# Inside psql:
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO users (name) VALUES ('Alice'), ('Bob');
SELECT * FROM users;
\q

# Clean up
docker rm -f postgres
```

### Exercise 5.2: Run Redis

```bash
# Run Redis
docker run -d --name redis -p 6379:6379 redis:7-alpine

# Use redis-cli
docker exec -it redis redis-cli

# Inside redis-cli:
SET greeting "Hello Docker"
GET greeting
KEYS *
exit

docker rm -f redis
```

### Exercise 5.3: Explore northwind-platform Containers

```bash
cd ~/projects/northwind-platform

# List all Dockerfiles
find . -name "Dockerfile" -type f

# Examine a service's Dockerfile
cat services/api-gateway/Dockerfile 2>/dev/null || echo "Path may differ"

# Build one of the services (if buildable locally)
# docker build -t northwind/api-gateway services/api-gateway/

# Return to lab
cd ~/docker-lab
```

---

## Validation Checklist

- [ ] I can run containers in interactive and detached mode
- [ ] I understand port mapping (-p)
- [ ] I can manage images (pull, list, remove)
- [ ] I can pass environment variables to containers
- [ ] I can debug containers using logs and exec
- [ ] I can inspect container details
- [ ] I can run common databases in containers

---

## Knowledge Check

1. What's the difference between `docker run` and `docker start`?
2. How do you view the logs of a running container?
3. What does `-p 8080:80` mean?
4. How do you get a shell inside a running container?
5. What's the difference between `docker rm` and `docker rmi`?

---

## Next Lab

Continue to [Lab 3.2: Building Images](labs-lab-02-building-images.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Running Containers
- Working with Images
- Container Lifecycle
- Debugging Containers

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
