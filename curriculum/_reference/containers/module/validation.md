# Module 3: Validation Checklist

> Complete this checklist to verify your mastery of Container concepts

---

## Self-Assessment

Rate your confidence (1-5) for each skill:

---

## Docker Fundamentals

| Skill | Confidence | Verified |
|-------|------------|----------|
| Run containers (interactive, detached) | [ ] /5 | [ ] |
| Map ports and volumes | [ ] /5 | [ ] |
| View logs and exec into containers | [ ] /5 | [ ] |
| Manage images (pull, push, tag) | [ ] /5 | [ ] |
| Inspect containers and images | [ ] /5 | [ ] |

---

## Dockerfile Skills

| Skill | Confidence | Verified |
|-------|------------|----------|
| Write production-ready Dockerfiles | [ ] /5 | [ ] |
| Implement multi-stage builds | [ ] /5 | [ ] |
| Optimize layer caching | [ ] /5 | [ ] |
| Create effective .dockerignore | [ ] /5 | [ ] |
| Use BuildKit features | [ ] /5 | [ ] |

---

## Container Security

| Skill | Confidence | Verified |
|-------|------------|----------|
| Scan images for vulnerabilities | [ ] /5 | [ ] |
| Lint Dockerfiles (Hadolint) | [ ] /5 | [ ] |
| Run containers as non-root | [ ] /5 | [ ] |
| Apply security best practices | [ ] /5 | [ ] |
| Generate SBOMs | [ ] /5 | [ ] |

---

## Docker Compose

| Skill | Confidence | Verified |
|-------|------------|----------|
| Define multi-service applications | [ ] /5 | [ ] |
| Configure networks and volumes | [ ] /5 | [ ] |
| Implement health checks | [ ] /5 | [ ] |
| Use environment files | [ ] /5 | [ ] |
| Manage different environments | [ ] /5 | [ ] |

---

## Practical Verification

```bash
# Commands I can execute confidently:
[ ] docker build -t myapp --target production .
[ ] docker run -d -p 8080:80 -v data:/app/data --name web nginx
[ ] docker compose up -d --build
[ ] trivy image --severity HIGH,CRITICAL myapp:latest
[ ] hadolint Dockerfile
[ ] docker exec -it container_name sh
```

---

## Labs Completed

- [ ] Lab 3.1: Docker Fundamentals
- [ ] Lab 3.2: Building Images
- [ ] Lab 3.3: Security Scanning
- [ ] Lab 3.4: Docker Compose

---

## Project Status

- [ ] All services build successfully
- [ ] Images pass security scans
- [ ] Containers run as non-root
- [ ] Health checks working
- [ ] Documentation complete

---

## Knowledge Check

1. What is a multi-stage build and why use it?
   ```
   Answer: ________________________________
   ```

2. How do you scan a Docker image for vulnerabilities?
   ```
   Answer: ________________________________
   ```

3. What's the difference between COPY and ADD?
   ```
   Answer: ________________________________
   ```

4. How do you run a container as non-root?
   ```
   Answer: ________________________________
   ```

5. What does `docker compose down -v` do?
   ```
   Answer: ________________________________
   ```

<details>
<summary>Answers</summary>

1. Multi-stage builds use multiple FROM statements to separate build and runtime stages, reducing final image size
2. `trivy image <image-name>` or `docker scout cves <image-name>`
3. COPY only copies files; ADD can extract archives and fetch URLs (prefer COPY)
4. Add `USER <username>` in Dockerfile after creating the user with `useradd` or `adduser`
5. Stops containers, removes them, and deletes associated volumes
</details>

---

## Module Completion

### Requirements
- [ ] All labs completed
- [ ] Project passes criteria
- [ ] Average confidence >= 3/5

### Sign-off

Date Completed: ________________

Notes:
```
_____________________________________________
```

---

## Next Steps

Proceed to Module 4: Kubernetes Foundations

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Self-Assessment
- Docker Fundamentals
- Dockerfile Skills
- Container Security

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
