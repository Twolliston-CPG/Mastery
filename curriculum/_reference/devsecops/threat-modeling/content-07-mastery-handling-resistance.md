# Handling Resistance to Threat Modeling

## Overview

Resistance to threat modeling is common and takes many forms. Understanding the root causes and having strategies to address them is essential for building a successful program.

---

## Common Resistance Patterns

### Types of Resistance

```yaml
resistance_types:
  time_pressure:
    manifestation: "We don't have time for this"
    root_cause: Competing priorities, unclear value
    frequency: Very common

  security_skepticism:
    manifestation: "Security will just slow us down"
    root_cause: Past negative experiences, perception of overhead
    frequency: Common

  ownership_conflict:
    manifestation: "That's security's job, not ours"
    root_cause: Unclear responsibilities, siloed thinking
    frequency: Common

  fear_of_exposure:
    manifestation: "I don't want to document vulnerabilities"
    root_cause: Fear of blame, audit concerns
    frequency: Moderate

  competency_concern:
    manifestation: "I'm not a security expert"
    root_cause: Imposter syndrome, lack of training
    frequency: Common

  methodology_fatigue:
    manifestation: "Another process to follow"
    root_cause: Process overload, change fatigue
    frequency: Moderate

  past_failure:
    manifestation: "We tried this before and it didn't work"
    root_cause: Poor previous implementation
    frequency: Occasional
```

### Stakeholder-Specific Resistance

**RESISTANCE BY STAKEHOLDER**

**Developers**

- "I already write secure code"
- "This feels like busywork"
- "Security tools are too noisy"
- "I'm not a security expert"

**Product Managers**

- "This will delay our release"
- "Our users don't care about security"
- "Can't we do this after launch?"
- "What's the ROI?"

**Engineering Leaders**

- "My team is already stretched"
- "We have other priorities"
- "Show me the business case"
- "Our platform handles security"

**Executives**

- "We've never had a breach"
- "We're compliant already"
- "Security is a cost center"
- "What's the minimum we need?"


---

## Understanding Root Causes

### Empathy-Based Analysis

```yaml
resistance_empathy:
  developer_perspective:
    pressures:
      - Sprint deadlines
      - Feature expectations
      - Technical debt
      - On-call duties
    valid_concerns:
      - Time is genuinely limited
      - Security findings create work
      - Not trained in security
    what_they_need:
      - Efficient process
      - Clear guidance
      - Tooling support
      - Recognition for security work

  manager_perspective:
    pressures:
      - Revenue targets
      - Customer commitments
      - Resource constraints
      - Competitive pressure
    valid_concerns:
      - Security isn't directly revenue-generating
      - Hard to measure security ROI
      - Unknown time investment
    what_they_need:
      - Clear time estimates
      - Business value articulation
      - Metrics and visibility
      - Executive cover

  executive_perspective:
    pressures:
      - Shareholder expectations
      - Market competition
      - Regulatory environment
      - Risk management
    valid_concerns:
      - Many competing priorities
      - Limited budget
      - Uncertain ROI
    what_they_need:
      - Risk-based framing
      - Peer benchmarking
      - Incident cost data
      - Compliance alignment
```

---

## Response Strategies

### Addressing Time Concerns

```yaml
time_objection:
  objection: "We don't have time for threat modeling"

  responses:
    shift_left_economics:
      message: "Finding issues in design costs 10-100x less than in production"
      evidence:
        - IBM study: $100 in design vs $10,000 in production
        - NIST data on cost of late fixes
        - Your own incident costs

    efficiency_focus:
      message: "Threat modeling actually saves time overall"
      evidence:
        - Fewer security review cycles
        - Less rework from late findings
        - Faster compliance audits

    right_sizing:
      message: "We can scale effort to risk level"
      approach:
        - Quick checklist for low-risk changes
        - Full session for high-risk systems
        - Automated tools for common patterns

    integration:
      message: "Embed in existing activities"
      approach:
        - Add to design review
        - Include in sprint planning
        - Part of architecture decisions

  practical_tactics:
    - Start with 60-minute sessions, not half-day
    - Prepare materials in advance
    - Focus on highest-risk areas
    - Use templates to accelerate
```

### Addressing Ownership Concerns

```yaml
ownership_objection:
  objection: "Security should do this, not us"

  responses:
    shared_responsibility:
      message: "Everyone owns security; we help, not replace"
      framing:
        - Developers know the system best
        - Security provides expertise and tools
        - Together we're more effective

    expertise_distribution:
      message: "You're already making security decisions"
      examples:
        - Authentication design
        - Data storage choices
        - API design
        - "Threat modeling makes these explicit"

    support_commitment:
      message: "We'll train and support you"
      offer:
        - Training for team
        - Facilitation support
        - Templates and tools
        - Expert consultation

  practical_tactics:
    - Security facilitates, team participates
    - Train security champions
    - Provide playbooks and checklists
    - Celebrate team contributions
```

### Addressing Value Skepticism

```yaml
value_objection:
  objection: "What's the ROI of threat modeling?"

  responses:
    cost_avoidance:
      message: "Prevention is dramatically cheaper than response"
      data:
        - Average breach cost: $4.5M (IBM)
        - Cost per vulnerability in production: $10K+
        - Threat model session: 4-8 hours

    real_examples:
      message: "Here's what we've prevented"
      examples:
        - Threat model found auth bypass before release
        - Identified data exposure before customer impact
        - Prevented compliance violation

    peer_benchmarking:
      message: "Leading organizations do this"
      examples:
        - Microsoft SDL requirement
        - Google security review process
        - Financial services standards

    regulatory_alignment:
      message: "This supports compliance"
      frameworks:
        - PCI DSS requires threat analysis
        - HIPAA risk assessment
        - SOC 2 risk identification

  practical_tactics:
    - Track and publicize finds
    - Calculate avoided costs
    - Show reduced security review cycles
    - Demonstrate faster audits
```

### Addressing Fear of Documentation

```yaml
documentation_objection:
  objection: "I don't want to write down our vulnerabilities"

  responses:
    legal_protection:
      message: "Documentation shows due diligence"
      framing:
        - Proves we're proactively managing risk
        - Better than discovering in breach investigation
        - Legal/compliance teams prefer this

    controlled_access:
      message: "We protect threat model documentation"
      controls:
        - Access restricted to need-to-know
        - Stored in secure repositories
        - Not shared externally

    action_oriented:
      message: "We document to fix, not just to list"
      approach:
        - Findings become action items
        - Track remediation
        - Close out addressed risks

  practical_tactics:
    - Involve legal early
    - Establish documentation policies
    - Show similar industry practices
    - Emphasize improvement focus
```

---

## Building Allies

### Identifying Champions

```yaml
ally_identification:
  characteristics:
    - Interested in security
    - Respected by peers
    - Influence in organization
    - Open to new approaches

  likely_allies:
    developers:
      - Senior engineers who've seen incidents
      - Those interested in security career path
      - Quality-focused individuals

    managers:
      - Those burned by past incidents
      - Compliance-aware leaders
      - Customer-focused product managers

    executives:
      - CISO and security leadership
      - Risk-aware business leaders
      - Those with security background

  cultivation_approach:
    - One-on-one conversations
    - Share success stories
    - Offer early involvement
    - Recognize contributions
```

### Creating Success Stories

```yaml
success_stories:
  structure:
    before:
      - What was the situation?
      - What were the risks?

    action:
      - What did threat modeling involve?
      - Who participated?
      - What was found?

    result:
      - What was prevented/fixed?
      - What would have happened otherwise?
      - What was the value?

  example:
    title: "Authentication Bypass Prevented"
    before: |
      New customer portal under development.
      Tight deadline, security review scheduled for end.

    action: |
      Threat modeling session during design phase.
      Identified that password reset flow allowed enumeration.
      Also found session token not properly invalidated.

    result: |
      Both issues fixed before code complete.
      Estimated savings: 40+ hours of rework.
      Avoided potential customer data exposure.
      Dev team now requests threat modeling.

  distribution:
    - Share in engineering all-hands
    - Include in security newsletter
    - Present in leadership meetings
    - Add to training materials
```

---

## Gradual Adoption Strategy

### Start Small

```yaml
gradual_adoption:
  phase_1_pilot:
    duration: 1-2 months
    scope:
      - One willing team
      - One high-value project
      - Full facilitation support
    goals:
      - Demonstrate value
      - Build internal expertise
      - Develop process

  phase_2_expand:
    duration: 3-6 months
    scope:
      - Additional volunteer teams
      - New projects in scope
      - Champion training
    goals:
      - Scale capability
      - Refine process
      - Build library of examples

  phase_3_standardize:
    duration: 6-12 months
    scope:
      - Required for critical systems
      - Self-service for lower risk
      - Integrated with SDLC
    goals:
      - Consistent practice
      - Measurable coverage
      - Continuous improvement
```

### Quick Wins

```yaml
quick_wins:
  strategies:
    low_friction_start:
      - Threat model existing, well-understood system
      - Use simple methodology
      - Focus on high-impact findings
      - Celebrate discoveries

    visible_value:
      - Find real issues early
      - Quantify cost savings
      - Share success broadly
      - Recognize participants

    easy_participation:
      - Prepare all materials
      - Keep sessions short
      - Minimize follow-up burden
      - Provide clear guidance
```

---

## Escalation Strategies

### When Resistance Persists

```yaml
escalation_path:
  level_1_peer_influence:
    approach: Use successful teams as examples
    tactics:
      - Invite resisters to observe winning teams
      - Have peers share experiences
      - Show comparative metrics

  level_2_management_support:
    approach: Engage engineering leadership
    tactics:
      - Present data on coverage gaps
      - Show peer organization practices
      - Align with engineering goals

  level_3_executive_mandate:
    approach: Obtain executive sponsorship
    tactics:
      - Present risk assessment
      - Show regulatory requirements
      - Request formal policy

  level_4_gate_enforcement:
    approach: Make threat modeling a release requirement
    tactics:
      - Add to release checklist
      - Block releases without threat model
      - Audit compliance
```

### Framing for Executives

```yaml
executive_framing:
  risk_language:
    - "Unmitigated risk to customer data"
    - "Regulatory exposure without documentation"
    - "Competitive disadvantage vs. mature organizations"

  peer_pressure:
    - "Microsoft requires this for all products"
    - "Our competitors in [industry] have mature programs"
    - "Top engineering organizations consider this standard"

  incident_reference:
    - "Company X breach started with flaw threat modeling would find"
    - "Our industry sees X breaches per year from design flaws"
    - "Average cost of breach in our industry: $X million"

  metrics_commitment:
    - "We'll measure and report on findings"
    - "Here's how we'll track ROI"
    - "We'll start small and prove value"
```

---

## Maintaining Momentum

### Sustaining Engagement

```yaml
sustaining_engagement:
  recognition:
    - Celebrate threat modeling achievements
    - Highlight individual contributions
    - Create security champion awards
    - Include in performance reviews

  continuous_improvement:
    - Collect feedback regularly
    - Iterate on process
    - Update training
    - Share lessons learned

  integration:
    - Make it normal, not special
    - Embed in existing processes
    - Reduce friction continuously
    - Automate where possible

  community:
    - Build community of practice
    - Regular knowledge sharing
    - Cross-team collaboration
    - External connections
```

### Handling Backsliding

```yaml
backsliding_prevention:
  early_warning_signs:
    - Declining session attendance
    - Reduced threat model completions
    - Increasing shortcuts
    - Growing complaints

  intervention_tactics:
    - Check in with teams
    - Address specific concerns
    - Refresh training
    - Reassert value proposition
    - Engage leadership if needed

  process_reinforcement:
    - Regular audits of coverage
    - Metrics in leadership reports
    - Recognition for compliance
    - Consequences for gaps
```

---

## Objection Handling Quick Reference

| Objection | Key Response | Evidence to Cite |
|-----------|--------------|------------------|
| "No time" | Shift-left saves time overall | 10-100x cost difference |
| "Not my job" | You already make security decisions | Examples from their code |
| "No ROI" | Prevention cheaper than response | $4.5M average breach cost |
| "Not expert" | We'll train and support you | Champion program |
| "Will slow us" | Actually accelerates secure releases | Faster compliance audits |
| "Already secure" | Validate with threat model | Recent industry breaches |
| "Tried before" | New approach, better support | Pilot success stories |

---

## Next Steps

→ [Facilitation](content-07-mastery-facilitation.md)
→ [Training Others](content-07-mastery-training-others.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Common Resistance Patterns
- Understanding Root Causes
- Response Strategies
- Building Allies

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
