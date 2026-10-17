# Threat Modeling Session Checklist

## Pre-Session Preparation (1 Week Before)

### Participant Coordination
- [ ] Identify required participants
  - [ ] Product owner/manager
  - [ ] Architect or tech lead
  - [ ] Senior developers (1-2)
  - [ ] Operations/SRE (for deployment discussion)
  - [ ] Security champion (if available)
- [ ] Send calendar invite with agenda
- [ ] Request architecture documentation
- [ ] Confirm attendance 2 days before

### Material Gathering
- [ ] Obtain existing architecture diagrams
- [ ] Review system documentation
- [ ] Check for previous threat models
- [ ] Review recent security assessments
- [ ] Identify data classification

### Session Setup
- [ ] Book appropriate meeting room
- [ ] Test video conferencing (if remote)
- [ ] Prepare whiteboard/digital collaboration tool
- [ ] Create initial DFD draft (if possible)
- [ ] Prepare STRIDE reference materials
- [ ] Have threat model template ready

---

## Pre-Session Preparation (Day Before)

### Final Preparation
- [ ] Review all gathered materials
- [ ] Finalize DFD draft
- [ ] Prepare agenda with times
- [ ] Create threat checklist relevant to system type
- [ ] Test all tools and technology
- [ ] Prepare parking lot document

### Material Checklist
- [ ] Blank DFD template
- [ ] STRIDE reference card
- [ ] Risk rating matrix
- [ ] Session notes template
- [ ] Previous findings (if refresh)
- [ ] Relevant attack scenarios

---

## Session Execution

### Opening (10-15 minutes)
- [ ] Welcome and introductions
- [ ] State session objectives
- [ ] Review agenda
- [ ] Set ground rules
  - [ ] One conversation at a time
  - [ ] No bad questions
  - [ ] Focus on system, not people
  - [ ] Parking lot for tangents
  - [ ] Timebox discussions

### System Overview (20-30 minutes)
- [ ] Have owner explain business purpose
- [ ] Document key features
- [ ] Identify user types and roles
- [ ] Understand data types handled
- [ ] Clarify compliance requirements
- [ ] Note integration points

### Architecture Review (30-45 minutes)
- [ ] Build/refine DFD together
- [ ] Identify all components
  - [ ] External entities
  - [ ] Processes
  - [ ] Data stores
- [ ] Document all data flows
- [ ] Draw trust boundaries
- [ ] Validate with participants
- [ ] Note technologies used

### Threat Identification (60-90 minutes)
- [ ] Apply STRIDE to each component
- [ ] For each data flow:
  - [ ] Consider spoofing threats
  - [ ] Consider tampering threats
  - [ ] Consider repudiation threats
  - [ ] Consider information disclosure
  - [ ] Consider denial of service
  - [ ] Consider elevation of privilege
- [ ] Discuss attack scenarios
- [ ] Document existing controls
- [ ] Note assumptions

### Risk Assessment (20-30 minutes)
- [ ] Rate likelihood for each threat
- [ ] Rate impact for each threat
- [ ] Calculate risk level
- [ ] Prioritize findings
- [ ] Identify quick wins
- [ ] Note accepted risks

### Wrap-Up (15-20 minutes)
- [ ] Summarize key findings
- [ ] Review top priority threats
- [ ] Assign action items
- [ ] Agree on next steps
- [ ] Set follow-up timeline
- [ ] Collect feedback
- [ ] Thank participants

---

## Post-Session (Within 1 Week)

### Documentation
- [ ] Clean up session notes
- [ ] Finalize DFD diagram
- [ ] Complete threat documentation
- [ ] Add threat IDs
- [ ] Document mitigations

### Communication
- [ ] Send summary to participants
- [ ] Share findings with stakeholders
- [ ] Create tickets for tracking
- [ ] Update threat model repository

### Follow-Up
- [ ] Answer parking lot questions
- [ ] Schedule follow-up if needed
- [ ] Track remediation progress
- [ ] Update model as needed

---

## Session Facilitation Tips

### Keeping Discussion Productive
- If stuck: "Let's move to a different component"
- If tangent: "Great point, let's add that to parking lot"
- If dominant: "Let's hear from others"
- If quiet: "Alex, what's your perspective?"
- If conflict: "Both valid points, let's capture both"

### Questions to Ask
- "What's the most valuable data here?"
- "What would an attacker want?"
- "What happens if this fails?"
- "How is this authenticated?"
- "What's logged here?"
- "Who has access to this?"

### Common Pitfalls to Avoid
- [ ] Don't skip trust boundaries
- [ ] Don't forget admin/ops flows
- [ ] Don't ignore logging and monitoring
- [ ] Don't assume controls work perfectly
- [ ] Don't let one person dominate
- [ ] Don't go too deep too fast
- [ ] Don't forget external services
- [ ] Don't skip session wrap-up

---

## Quick Reference: STRIDE

| Category | Question | Example Threats |
|----------|----------|-----------------|
| **S**poofing | Who might pretend to be someone else? | Stolen credentials, session hijacking |
| **T**ampering | What could be modified? | Data manipulation, code injection |
| **R**epudiation | What actions might be denied? | Missing logs, log tampering |
| **I**nfo Disclosure | What could be exposed? | Data leaks, error messages |
| **D**enial of Service | What could be disrupted? | Resource exhaustion, crashes |
| **E**levation | Who could gain unauthorized access? | Privilege escalation, admin bypass |

---

## Session Notes Template

```markdown
# Threat Model Session Notes

## Session Details
- **Date**:
- **System**:
- **Facilitator**:
- **Participants**:
- **Duration**:

## System Summary
[Brief description]

## Key Decisions
1.
2.

## Assumptions
1.
2.

## Threats Identified
| ID | Component | STRIDE | Description | Risk |
|----|-----------|--------|-------------|------|
| T-01 | | | | |

## Action Items
| Action | Owner | Due Date |
|--------|-------|----------|
| | | |

## Parking Lot
-

## Next Steps
-
```

---

## Resources

- [Facilitation Guide](content-07-mastery-facilitation.md)
- [STRIDE Worksheet](templates-stride-worksheet.md)
- [Threat Model Template](templates-threat-model-template.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Pre-Session Preparation (1 Week Before)
- Pre-Session Preparation (Day Before)
- Session Execution
- Post-Session (Within 1 Week)

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
