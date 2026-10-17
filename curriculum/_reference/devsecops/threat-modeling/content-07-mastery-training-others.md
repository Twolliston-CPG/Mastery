# Training Others in Threat Modeling

## Overview

Building organizational capability requires training developers, architects, and security champions to conduct threat modeling independently. This guide covers how to design and deliver effective threat modeling training.

---

## Training Program Design

### Audience Segmentation

```yaml
training_audiences:
  all_developers:
    goal: Participate effectively in threat modeling sessions
    depth: Awareness level
    duration: 2-4 hours
    key_outcomes:
      - Understand why threat modeling matters
      - Know how to contribute to sessions
      - Recognize common threat patterns
      - Understand basic STRIDE concepts

  security_champions:
    goal: Lead threat modeling for their teams
    depth: Practitioner level
    duration: 16-24 hours
    key_outcomes:
      - Facilitate basic threat models
      - Create data flow diagrams
      - Apply STRIDE systematically
      - Prioritize and document findings
      - Use threat modeling tools

  security_engineers:
    goal: Expert-level threat modeling capability
    depth: Expert level
    duration: 40+ hours
    key_outcomes:
      - Lead complex threat models
      - Train and mentor others
      - Customize methodology
      - Integrate with SDLC
      - Program management

  architects:
    goal: Incorporate security into design
    depth: Practitioner level
    duration: 8-16 hours
    key_outcomes:
      - Design with security in mind
      - Create secure architectures
      - Identify threats during design
      - Apply security patterns
```

### Curriculum Structure

**THREAT MODELING CURRICULUM**

**Foundation (All)**

- Security Fundamentals
- What is Threat Modeling
- Why It Matters
- How to Participate

**Practitioner (Champions + Engineers)**

- STRIDE Deep Dive
- Data Flow Diagrams
- Threat Identification
- Risk Assessment
- Tool Usage
- Facilitation Skills

**Expert (Security Engineers)**

- Multiple Methodologies
- Complex Architectures
- Threat Intelligence Integration
- Program Management
- Training Others
- Continuous Improvement

**Specialized (As Needed)**

- Cloud Security Threat Modeling
- API Security
- ML/AI Systems
- Industry-Specific (Healthcare, Finance)


---

## Training Content Development

### Module: Introduction to Threat Modeling (2 hours)

```yaml
intro_module:
  objectives:
    - Explain what threat modeling is and why it matters
    - Describe when threat modeling should occur
    - List the four key questions of threat modeling
    - Participate constructively in a threat modeling session

  outline:
    section_1_why:
      duration: 20 minutes
      content:
        - Cost of late security fixes
        - Real breach examples
        - Shift-left benefits
      activities:
        - Discussion: "What would a breach cost us?"

    section_2_what:
      duration: 30 minutes
      content:
        - Four questions framework
        - DFD overview
        - STRIDE introduction
      activities:
        - Identify assets in a simple system

    section_3_when:
      duration: 15 minutes
      content:
        - New projects
        - Major changes
        - Integration of threat modeling in SDLC
      activities:
        - Map threat modeling to your team's process

    section_4_how_to_participate:
      duration: 25 minutes
      content:
        - Roles in a session
        - Types of input needed
        - Common questions to expect
      activities:
        - Role-play session scenarios

    section_5_mini_exercise:
      duration: 30 minutes
      content:
        - Simple system walk-through
        - Group threat identification
        - Discussion of findings
      activities:
        - Hands-on: Find threats in sample app
```

### Module: STRIDE Methodology (4 hours)

```yaml
stride_module:
  objectives:
    - Define each STRIDE category with examples
    - Apply STRIDE to system components
    - Identify appropriate mitigations for each category
    - Avoid common STRIDE mistakes

  outline:
    section_1_overview:
      duration: 30 minutes
      content:
        - STRIDE history and purpose
        - When to use STRIDE
        - STRIDE vs other methodologies
      activities:
        - Match threats to STRIDE categories

    section_2_spoofing:
      duration: 25 minutes
      content:
        - Definition and examples
        - Common spoofing attacks
        - Mitigations (authentication)
      activities:
        - Identify spoofing in scenario
        - Design authentication controls

    section_3_tampering:
      duration: 25 minutes
      content:
        - Definition and examples
        - Data and code tampering
        - Mitigations (integrity)
      activities:
        - Find tampering opportunities
        - Select integrity controls

    section_4_repudiation:
      duration: 25 minutes
      content:
        - Definition and examples
        - Audit and logging
        - Mitigations (non-repudiation)
      activities:
        - Design audit requirements

    section_5_information_disclosure:
      duration: 25 minutes
      content:
        - Definition and examples
        - Data exposure scenarios
        - Mitigations (confidentiality)
      activities:
        - Classify data sensitivity
        - Apply encryption/access controls

    section_6_denial_of_service:
      duration: 25 minutes
      content:
        - Definition and examples
        - Availability attacks
        - Mitigations (resilience)
      activities:
        - Identify DoS vectors
        - Design resilience

    section_7_elevation_of_privilege:
      duration: 25 minutes
      content:
        - Definition and examples
        - Privilege escalation
        - Mitigations (authorization)
      activities:
        - Find privilege escalation paths
        - Design least privilege

    section_8_practical_exercise:
      duration: 60 minutes
      content:
        - Full STRIDE analysis of system
        - Group work with facilitated discussion
      activities:
        - Complete STRIDE worksheet for real system
```

### Module: Facilitation Skills (4 hours)

```yaml
facilitation_module:
  objectives:
    - Plan and prepare for threat modeling sessions
    - Lead productive discussions with diverse participants
    - Handle common facilitation challenges
    - Document and follow up effectively

  outline:
    section_1_preparation:
      duration: 45 minutes
      content:
        - Gathering materials
        - Participant selection
        - Agenda creation
        - Tool setup
      activities:
        - Create session plan for scenario

    section_2_running_sessions:
      duration: 60 minutes
      content:
        - Opening effectively
        - Guiding discussion
        - Time management
        - Real-time documentation
      activities:
        - Practice session opening
        - Facilitation role-play

    section_3_handling_challenges:
      duration: 45 minutes
      content:
        - Difficult participants
        - Tangents and scope creep
        - Technical disputes
        - Low engagement
      activities:
        - Role-play challenging scenarios

    section_4_documentation:
      duration: 30 minutes
      content:
        - What to capture
        - Templates and tools
        - Follow-up process
      activities:
        - Practice documenting findings

    section_5_live_practice:
      duration: 60 minutes
      content:
        - Facilitated practice session
        - Peer feedback
        - Improvement discussion
      activities:
        - Each participant facilitates 10-minute segment
```

---

## Training Delivery Methods

### Instructor-Led Training

```yaml
instructor_led:
  advantages:
    - Interactive discussion
    - Real-time Q&A
    - Hands-on exercises with feedback
    - Relationship building

  best_practices:
    - Keep sessions under 4 hours
    - Include breaks every 60-90 minutes
    - Balance lecture with activities
    - Use real examples from organization
    - Invite guest speakers from dev teams

  format_options:
    in_person:
      - Whiteboard exercises
      - Small group work
      - Physical materials

    virtual:
      - Collaborative tools (Miro, Lucidchart)
      - Breakout rooms
      - Chat for questions
      - Recording for absent participants
```

### Self-Paced Learning

```yaml
self_paced:
  advantages:
    - Flexible timing
    - Scalable to large organizations
    - Consistent content delivery
    - Progress tracking

  content_types:
    video_lectures:
      - 5-10 minute segments
      - Concept explanations
      - Demonstrations

    interactive_exercises:
      - Quizzes after each section
      - Scenario-based questions
      - Hands-on labs

    reading_materials:
      - Reference documentation
      - Templates and checklists
      - Case studies

  platform_options:
    - Internal LMS
    - Confluence/wiki
    - Video hosting
    - Interactive lab environments
```

### Blended Approach (Recommended)

```yaml
blended_learning:
  structure:
    pre_work:
      - Self-paced foundational content
      - Reading materials
      - Pre-assessment quiz

    live_session:
      - Discussion of concepts
      - Hands-on exercises
      - Real-system practice
      - Q&A

    post_work:
      - Apply to real project
      - Mentored threat model
      - Certification assessment

  schedule_example:
    week_1:
      - Online: Intro to threat modeling (2 hours)
      - Online: STRIDE concepts (2 hours)

    week_2:
      - Live session: STRIDE practice (4 hours)

    week_3:
      - Online: DFD creation (2 hours)
      - Online: Tool training (2 hours)

    week_4:
      - Live session: Full threat model exercise (4 hours)

    week_5_6:
      - Mentored: Real project threat model
      - Assessment and certification
```

---

## Hands-On Exercises

### Exercise: STRIDE Analysis

```yaml
stride_exercise:
  scenario: E-commerce checkout API

  system_description: |
    Users submit orders through a web application. The checkout API
    processes payments via a third-party payment gateway. Order data
    is stored in a database, and confirmation emails are sent.

  components:
    - Web Application
    - Checkout API
    - Payment Gateway (external)
    - Order Database
    - Email Service

  instructions:
    1. Draw a simple DFD
    2. For each component, apply STRIDE
    3. Identify at least 2 threats per category
    4. Suggest mitigations
    5. Prioritize top 5 threats

  sample_answers:
    spoofing:
      - Session hijacking on web app
      - Fake payment confirmations
    tampering:
      - Order amount modification
      - Database record alteration
    repudiation:
      - User denies placing order
      - Missing payment audit trail
    information_disclosure:
      - Credit card data exposure
      - Order history leakage
    denial_of_service:
      - API overload during sales
      - Database connection exhaustion
    elevation_of_privilege:
      - Admin function access
      - Payment bypass

  debrief_questions:
    - Which threats were hardest to identify?
    - What additional information would help?
    - How would you prioritize these?
```

### Exercise: Threat Model a Real System

```yaml
real_system_exercise:
  setup:
    - Use a system from participant's organization
    - Prepare architectural materials
    - Have subject matter experts available

  structure:
    preparation: 30 minutes
      - Review architecture
      - Identify participants
      - Set scope

    facilitation: 90 minutes
      - Trainee facilitates with mentor support
      - Real threat identification
      - Documentation

    debrief: 30 minutes
      - What went well?
      - What was challenging?
      - What would you do differently?

  assessment_criteria:
    - Clear agenda and objectives
    - Accurate DFD creation
    - STRIDE coverage
    - Finding quality
    - Time management
    - Documentation completeness
```

---

## Certification and Assessment

### Competency Framework

```yaml
competency_levels:
  participant:
    description: Can participate in threat modeling sessions
    assessment:
      - Complete awareness training
      - Pass knowledge quiz (80%)
      - Participate in observed session
    privileges:
      - Required participant in team sessions

  practitioner:
    description: Can lead standard threat models
    assessment:
      - Complete practitioner training
      - Pass skills assessment
      - Lead 3 mentored sessions
      - Submit portfolio threat model
    privileges:
      - Lead team threat models
      - Train awareness level

  expert:
    description: Can handle complex scenarios and train others
    assessment:
      - Complete expert training
      - Lead 10+ threat models
      - Train practitioner level
      - Contribute to methodology
    privileges:
      - Lead any threat model
      - Train all levels
      - Approve threat models
```

### Assessment Methods

```yaml
assessment_methods:
  knowledge_test:
    format: Multiple choice, scenario-based
    topics:
      - STRIDE categories
      - DFD components
      - Risk assessment
      - Common threats
    passing_score: 80%

  practical_assessment:
    format: Observed facilitation
    criteria:
      - Session preparation
      - DFD accuracy
      - Threat identification completeness
      - Risk prioritization
      - Documentation quality
      - Time management
      - Stakeholder engagement

  portfolio_review:
    format: Submit completed threat model
    criteria:
      - Methodology application
      - Finding quality
      - Documentation standards
      - Actionable recommendations
```

---

## Sustaining Learning

### Ongoing Development

```yaml
ongoing_learning:
  regular_activities:
    - Monthly community of practice
    - Quarterly skill refreshers
    - Annual recertification

  knowledge_sharing:
    - Internal threat model repository
    - Case study presentations
    - Lunch and learn sessions
    - Lessons learned reviews

  external_resources:
    - Conferences (OWASP, BSides)
    - Industry publications
    - Vendor training
    - Certification (GIAC, ISC2)
```

### Mentorship Program

```yaml
mentorship:
  structure:
    - Pair new practitioners with experts
    - Shadow sessions before leading
    - Co-facilitate first sessions
    - Debrief and feedback loop

  mentor_responsibilities:
    - Guide through first 3-5 threat models
    - Provide constructive feedback
    - Answer questions
    - Model good practices

  mentee_responsibilities:
    - Prepare for sessions
    - Accept feedback gracefully
    - Document learnings
    - Progress toward independence
```

---

## Measuring Training Effectiveness

### Metrics

```yaml
training_metrics:
  participation:
    - Training completion rate
    - Certification pass rate
    - Time to certification

  application:
    - Threat models completed post-training
    - Champions actively facilitating
    - Self-service rate increase

  quality:
    - Threat model quality scores
    - Finding discovery rate
    - Stakeholder satisfaction

  business_impact:
    - Security issues found earlier
    - Remediation cost reduction
    - Compliance audit results
```

---

## Next Steps

→ [Handling Resistance](content-07-mastery-handling-resistance.md)
→ [Building a Program](content-05-enterprise-building-program.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Training Program Design
- Training Content Development
- Training Delivery Methods
- Certification and Assessment

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
