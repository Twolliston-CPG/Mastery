# Threat Modeling Facilitation

## Overview

Effective facilitation is the difference between a threat modeling session that produces actionable insights and one that wastes everyone's time. This guide covers the skills needed to lead productive threat modeling sessions.

---

## Facilitation Fundamentals

### The Facilitator Role

```yaml
facilitator_responsibilities:
  before_session:
    - Schedule with right participants
    - Gather architectural artifacts
    - Prepare materials and tools
    - Set clear objectives
    - Review previous threat models

  during_session:
    - Guide discussion without dominating
    - Ensure all voices are heard
    - Keep focus on security
    - Manage time effectively
    - Document findings in real-time

  after_session:
    - Clean up documentation
    - Distribute findings
    - Create tracking items
    - Follow up on questions
    - Schedule reviews if needed
```

### Key Skills

**Facilitator skills**

| Technical | Interpersonal |
|---|---|
| Security knowledge | Active listening |
| Architecture | Asking good questions |
| Attack techniques | Managing conflict |
| Tool proficiency | Reading the room |
| Risk assessment | Building consensus |

| Process | Communication |
|---|---|
| Time management | Clear explanations |
| Agenda adherence | Visual thinking |
| Documentation | Summarising |
| Decision facilitation | Technical translation |
| Action tracking | Persuasion |

The left-hand column is what gets someone the role and the right-hand column is what makes them good
at it. A session run by the most knowledgeable person in the room, who answers their own questions,
produces the threat model that person would have written alone — and loses the reason for gathering
everyone in the first place.

---

## Session Preparation

### Participant Selection

```yaml
participant_selection:
  essential_roles:
    - role: Product owner/manager
      contribution: Business context, requirements
      time_needed: Full session

    - role: Architect/tech lead
      contribution: System design, data flows
      time_needed: Full session

    - role: Senior developer
      contribution: Implementation details
      time_needed: Full session

    - role: Operations/SRE
      contribution: Deployment, infrastructure
      time_needed: Partial (deployment discussion)

  optional_roles:
    - role: QA/Test
      contribution: Test coverage, edge cases
      when_needed: Complex systems

    - role: Security champion
      contribution: Security perspective
      when_needed: If no security expert facilitating

    - role: Compliance
      contribution: Regulatory requirements
      when_needed: Regulated industries

  group_size:
    optimal: 4-6 people
    maximum: 8 people
    too_small: < 3 people (missing perspectives)
    too_large: > 8 people (coordination overhead)
```

### Pre-Session Checklist

```
One Week Before:
□ Identify and invite participants
□ Request architectural diagrams
□ Gather relevant documentation
□ Review previous security assessments
□ Prepare session agenda

One Day Before:
□ Confirm attendance
□ Review all materials
□ Prepare whiteboard/tool
□ Create initial DFD draft
□ Prepare threat checklists

Day of Session:
□ Test video/screen sharing
□ Open threat modeling tool
□ Have templates ready
□ Prepare parking lot for side topics
□ Verify recording setup (if applicable)
```

### Agenda Template

```yaml
session_agenda:
  total_duration: 2-4 hours

  intro:
    duration: 10-15 minutes
    activities:
      - Introductions
      - Session objectives
      - Ground rules
      - Review agenda

  system_overview:
    duration: 20-30 minutes
    activities:
      - Business context
      - System purpose
      - Key features
      - User types
      - Data classification

  architecture_review:
    duration: 30-45 minutes
    activities:
      - Build/refine DFD
      - Identify trust boundaries
      - Document data flows
      - Clarify components

  threat_identification:
    duration: 60-90 minutes
    activities:
      - STRIDE analysis
      - Per-component threats
      - Per-dataflow threats
      - Discuss attack scenarios

  risk_assessment:
    duration: 20-30 minutes
    activities:
      - Prioritize threats
      - Assess likelihood/impact
      - Identify existing controls
      - Determine residual risk

  wrap_up:
    duration: 15-20 minutes
    activities:
      - Summarize findings
      - Assign action items
      - Agree on next steps
      - Collect feedback
```

---

## Running the Session

### Opening the Session

```yaml
session_opening:
  set_context:
    - "We're here to identify potential security issues early"
    - "This is about the system, not individuals"
    - "All ideas are valuable - no bad questions"
    - "We won't solve everything today, but we'll prioritize"

  ground_rules:
    - One conversation at a time
    - No phones/laptops for non-session work
    - Encourage participation
    - Park tangential topics
    - Timebox discussions

  icebreaker_questions:
    - "What keeps you up at night about this system?"
    - "What's the worst thing that could happen?"
    - "What would an attacker want from this system?"
```

### Building the Diagram

```yaml
diagramming_techniques:
  start_simple:
    - Begin with user and main system
    - Add components as discussed
    - Let participants drive content
    - Verify as you go

  asking_questions:
    - "What happens when a user first connects?"
    - "Where does this data come from?"
    - "What other systems does this talk to?"
    - "Where is this data stored?"
    - "Who else has access to this?"

  handling_complexity:
    - Focus on security-relevant details
    - Abstract away internal implementation
    - Use swimlanes for ownership
    - Create multiple views if needed

  common_pitfalls:
    - Too much detail too early
    - Missing trust boundaries
    - Forgetting data at rest
    - Ignoring admin/ops flows
    - Not validating with participants
```

### Threat Identification Techniques

```yaml
threat_finding_methods:
  stride_per_element:
    process: For each component, ask STRIDE questions
    example:
      component: API Gateway
      spoofing: "How could an attacker impersonate a legitimate client?"
      tampering: "How could requests be modified in transit?"
      repudiation: "Could a user deny making a transaction?"
      disclosure: "What sensitive data could be exposed?"
      dos: "How could this service be overwhelmed?"
      elevation: "How could someone gain admin access?"

  data_flow_analysis:
    process: For each data flow, consider threats
    questions:
      - "What if this data is intercepted?"
      - "What if this data is modified?"
      - "What if this connection fails?"
      - "Is this encrypted? How?"

  attack_scenario_brainstorming:
    process: Think like an attacker
    prompts:
      - "If I wanted to steal customer data..."
      - "If a competitor wanted to disrupt us..."
      - "If an insider went rogue..."
      - "If this component was compromised..."

  assumption_challenging:
    process: Question implicit trust
    examples:
      - "Why do we trust this input?"
      - "What if this service is compromised?"
      - "How do we know this user is who they claim?"
```

### Managing Discussion Dynamics

```yaml
discussion_management:
  encouraging_participation:
    quiet_participants:
      - Direct questions: "Alex, what's your perspective on this?"
      - Round-robin: Go around the room for input
      - Written input: Have everyone write threats before discussing

    dominating_participants:
      - Acknowledge: "Good point, let's hear other perspectives"
      - Time limit: "Let's timebox this to 2 minutes"
      - Parking lot: "Let's capture this and come back"

  handling_conflict:
    disagreements:
      - "Interesting - we have different views. Let's explore both."
      - "What data would help us resolve this?"
      - "For now, let's document both perspectives."

    defensiveness:
      - Focus on system, not people
      - "This isn't about blame, it's about improvement"
      - "Everyone's goal is to make this more secure"

    tangents:
      - "Great point - let's add that to the parking lot"
      - "Can we capture that for follow-up?"
      - "Let's stay focused on [current topic]"

  keeping_momentum:
    when_stuck:
      - Change threat category
      - Move to different component
      - Take a short break
      - Use structured checklists

    when_going_too_deep:
      - "Good discussion - let's note this and move on"
      - "We can dive deeper in follow-up"
      - "What's the key takeaway here?"
```

---

## Remote Facilitation

### Tools for Remote Sessions

| Tool Type | Options | Purpose |
|-----------|---------|---------|
| Diagramming | Miro, Lucidchart, draw.io | Collaborative DFDs |
| Threat Modeling | OWASP Threat Dragon, MS TMT | Structured modeling |
| Video | Zoom, Teams, Meet | Face-to-face interaction |
| Documentation | Confluence, Notion, Google Docs | Real-time notes |
| Voting | Built-in polls, Mentimeter | Prioritization |

### Remote-Specific Techniques

```yaml
remote_techniques:
  engagement:
    - Use video (encourage cameras on)
    - Call on people by name
    - Use collaborative tools actively
    - Shorter sessions with breaks
    - More structured activities

  visual_collaboration:
    - Share screen for diagram
    - Give editing access to participants
    - Use cursor highlighting
    - Color-code contributions

  breakout_activities:
    - Small group threat finding
    - Individual brainstorming then share
    - Divide STRIDE categories

  asynchronous_options:
    - Pre-session diagram review
    - Async threat submission
    - Post-session voting on priorities
    - Written comments for follow-up
```

---

## Capturing Findings

### Real-Time Documentation

```yaml
documentation_approach:
  during_session:
    - Capture threats as discussed
    - Note assumptions and decisions
    - Record action items immediately
    - Track questions for follow-up

  threat_capture_format:
    minimal:
      - Threat ID
      - Component affected
      - Threat description
      - Initial priority

    detailed:
      - Threat ID
      - STRIDE category
      - Affected component/data flow
      - Threat description
      - Attack scenario
      - Preconditions
      - Impact assessment
      - Existing controls
      - Recommended mitigations
      - Priority
      - Owner

  documentation_tools:
    structured: Threat Dragon, MS TMT
    flexible: Spreadsheet, Markdown tables
    integrated: Jira, GitHub Issues
```

### Session Notes Template

```markdown
# Threat Model Session Notes

## Session Information
- **Date**: [Date]
- **System**: [System name]
- **Facilitator**: [Name]
- **Participants**: [Names and roles]
- **Duration**: [Time]

## System Summary
[Brief description of system purpose and scope]

## Key Decisions
1. [Decision made during session]
2. [Another decision]

## Assumptions
1. [Assumption about environment]
2. [Assumption about threat actors]

## Threats Identified
| ID | Component | STRIDE | Description | Priority |
|----|-----------|--------|-------------|----------|
| T1 | API       | S      | Token theft | High     |
| T2 | DB        | I      | SQL injection| High    |

## Existing Controls
- [Control 1]
- [Control 2]

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| [Action]| [Name]| [Date]   | Open   |

## Parking Lot
- [Topic for future discussion]
- [Question to research]

## Next Steps
- [Follow-up action]
```

---

## After the Session

### Follow-Up Activities

```yaml
post_session:
  immediate:
    - Send thank you and summary
    - Share documented findings
    - Create tracking issues
    - Update threat model repository

  within_one_week:
    - Answer parking lot questions
    - Finalize threat documentation
    - Confirm ownership of items
    - Schedule follow-up if needed

  ongoing:
    - Track remediation progress
    - Update model on changes
    - Report metrics to leadership
    - Incorporate lessons learned
```

### Measuring Session Effectiveness

```yaml
session_metrics:
  output_metrics:
    - Number of threats identified
    - Threat severity distribution
    - Coverage of STRIDE categories
    - Action items created

  process_metrics:
    - Session duration vs planned
    - Participant engagement
    - Time to documentation complete
    - Follow-through on actions

  quality_metrics:
    - Threats confirmed by testing
    - False positives identified
    - Participant satisfaction
    - Repeat participation rate
```

---

## Common Facilitation Challenges

### Challenge: No One Knows the Architecture

```yaml
solution:
  before_session:
    - Request diagrams in advance
    - Interview key developers
    - Review code repositories
    - Check existing documentation

  during_session:
    - Build diagram together
    - Ask lots of questions
    - Validate with multiple people
    - Accept imperfect knowledge

  after_session:
    - Refine based on follow-up
    - Document unknowns
    - Create architecture documentation
```

### Challenge: Too Many Threats, Can't Prioritize

```yaml
solution:
  voting_techniques:
    - Dot voting (each person gets 3-5 votes)
    - Impact/likelihood matrix
    - Risk scoring framework

  structured_prioritization:
    - Focus on data sensitivity first
    - Consider existing controls
    - Align with business impact
    - Use dread or similar

  scope_limitation:
    - Focus on new/changed components
    - Prioritize critical data flows
    - Accept iterative improvement
```

### Challenge: Session Runs Too Long

```yaml
solution:
  prevention:
    - Strict timebox per section
    - Prepare participants in advance
    - Limit scope clearly
    - Have agenda visible

  recovery:
    - Pause and re-scope
    - Schedule continuation
    - Focus on highest priority
    - Delegate follow-up research
```

---

## Next Steps

→ [Training Others](content-07-mastery-training-others.md)
→ [Handling Resistance](content-07-mastery-handling-resistance.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Facilitation Fundamentals
- Session Preparation
- Running the Session
- Remote Facilitation

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
