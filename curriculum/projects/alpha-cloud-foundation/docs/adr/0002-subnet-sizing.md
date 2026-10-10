# ADR-0002: Subnet sizing and the free-space reservation

- **Status:** Accepted
- **Date:** 2026-03-02

## Context

A VPC CIDR cannot be shrunk, and overlapping CIDRs make VPC peering and Transit Gateway attachment
impossible — permanently. Re-CIDRing a live VPC means rebuilding it. Whatever we choose now, we live
with.

Two forces pull in opposite directions:
- Public subnets hold only NAT gateway and load balancer ENIs — a handful of addresses.
- App subnets may one day run EKS, where the AWS VPC CNI assigns **one subnet IP per pod**. A /24
  (251 usable) supports roughly 200 pods. That runs out fast.

## Options considered

**A. Uniform /20 for every subnet.** Simple, symmetric, and wastes ~4,000 addresses per public
subnet for no benefit. Consumes the VPC faster.

**B. Uniform /24 for every subnet.** Compact, but caps the app tier at ~200 pods and would force a
rebuild if EKS ever lands here.

**C. Size to purpose: /24 public and data, /20 app, ~75% of the VPC left unallocated.** More
arithmetic, needs documenting.

## Decision

**Option C.** Public and data subnets get `/24` (251 usable). App subnets get `/20` (4,091 usable).
Roughly 75% of each `/16` is left unallocated.

## Consequences

**Positive:** the app tier can absorb an EKS migration without a re-CIDR. Free space accommodates a
new environment, a TGW attachment, or a second cluster. Addresses cost nothing, so the reservation
is free.

**Negative:** the CIDR math is non-obvious, so it is encoded in `locals` in the network module with
comments and exposed via the `subnet_plan` output rather than left implicit.

**Revisit if:** we adopt EKS prefix delegation or custom networking, which change pod IP consumption
substantially.
