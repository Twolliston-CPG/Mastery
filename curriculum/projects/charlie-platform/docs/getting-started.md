# Ship your first service

Five minutes of your time, about eight minutes of waiting.

You do **not** need to know Kubernetes, Terraform, or AWS.

## 1. Set your team, once

```bash
git config --global platform.team team-yourteam
```
(If you don't know your team name, run `platform validate` on any existing service — the error lists
the valid ones.)

## 2. Create the service

```bash
git clone https://github.com/org/platform && cd platform
./cli/platform new-service --name my-first-api --language python --tier experimental
```

That writes `services/my-first-api/service.yaml`, validates it, and opens a pull request.

Prefer to do it by hand? Create the file yourself:

```yaml
apiVersion: platform.internal/v1
kind: Service
metadata:
  name: my-first-api
  owner: team-yourteam
spec:
  language: python
  port: 8080
  tier: experimental
```

**The file must be at `services/<name>/service.yaml`.**

## 3. Read the bot's comment

Within about two minutes a bot comments on your PR with:
- everything that will be created
- **what it will cost per month**

If anything is wrong with your file, the comment says exactly what and how to fix it.

## 4. Get one approval, then merge

## 5. Wait about eight minutes

You'll get a comment with your URLs:

| | |
|---|---|
| Repository | `github.com/org/my-first-api` — already contains working code |
| URL | `https://my-first-api.internal` |
| Dashboard | `https://grafana.internal/d/my-first-api` |
| Runbook | in your new repository |

**That's it.** Your service is running, monitored, has alerts, and has a pipeline. Push to your new
repository and it deploys.

---

## What you got without asking

- A hardened container image (non-root, distroless, read-only filesystem)
- A pipeline with linting, tests, SAST, dependency scanning, an SBOM, and image signing
- A Kubernetes namespace with quotas and a default-deny NetworkPolicy
- A Grafana dashboard and alerts appropriate to your tier
- A runbook stub

## Next

- **[Choosing a tier](tiers.md)** — the one decision that matters
- **[Adding a database](../platform/schemas/service.schema.json)** — two lines of YAML; the schema is the field reference
- **[Going off the paved road](escape-hatches.md)** — if the platform doesn't support what you need

## Something went wrong?

The validation error should tell you what to do. If it doesn't, **that's a bug in the platform** —
tell us in `#platform` and we'll fix the message.
