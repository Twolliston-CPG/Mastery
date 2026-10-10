# Going off the paved road

> **This is supported, not forbidden.**

Most platform teams never write this document, because it feels like admitting the platform is
incomplete. It is the opposite: **a platform that forbids exceptions creates shadow
infrastructure** — teams build what they need anyway, outside your visibility, without your security
controls, and you discover it during an incident.

## What the paved road covers

Stateless HTTP services, optionally with Postgres, S3, SQS, or Redis. Single region. Standard
pipeline per language.

## What it does not

Kafka · GPU workloads · StatefulSets · custom networking topologies · multi-region · anything
requiring a custom Kubernetes manifest · languages other than the four supported ones.

## What to do if you need one of those

**Talk to us in `#platform`.** We will help you build it directly with the underlying tools. You will
own more of it, and you will not get automatic pipeline updates, the generated dashboard, or the
generated alerts — so you take on that maintenance.

That is a normal, supported outcome. It is not a failure of the platform and it is not a failure of
your team.

## The part that matters to us

**If several teams need the same thing, tell us — that's a signal we should pave it.**

Escape hatches are our roadmap. A documented exception is visible; an undocumented workaround is a
liability we find out about at 3am.

## The one thing that is never negotiable

Security controls. Non-root containers, resource limits, NetworkPolicies, signed images, and
encryption at rest apply whether you are on the paved road or off it. If you need an exception to one
of those, it goes through a written risk acceptance with an owner and an expiry — see the control
narrative in the Bravo project for the format.
