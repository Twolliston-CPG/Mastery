# Lab 11: Technical Leadership and Decision Making

## Lab Overview

| Attribute | Details |
|-----------|---------|
| **Duration** | 3 hours |
| **Level** | Advanced |
| **Prerequisites** | Software architecture experience, team leadership |
| **Environment** | Documentation tools, collaboration platforms |
| **Learning Objectives** | Make effective technical decisions, document architecture choices, build consensus |

## Introduction

Technical leadership requires making decisions that balance short-term needs with long-term sustainability. This lab covers frameworks for technical decision-making, including Architecture Decision Records (ADRs), RFC processes, and techniques for building consensus across teams.

## Part 1: Architecture Decision Records

### ADR Framework

**Architecture Decision Record**

````markdown
# ADR-001: [Short title]

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-00X

## Context
What is the issue we are seeing that motivates this decision?

## Decision
What is the change we are proposing, and doing?

## Consequences
What becomes easier, and what becomes harder, because of this change?

---
Date: YYYY-MM-DD
Deciders: [names]
Consulted: [names]
Informed: [names]
````

**Consequences is the section that makes an ADR worth writing.** Anyone can record what was chosen;
recording what it *cost* is what lets a future reader — often you — tell the difference between a
decision that was wrong and a decision that was right under conditions that have since changed.

An ADR is immutable once accepted. You do not edit it, you supersede it with a new one that links
back — which is why the status line has a `Superseded by` option.

### Exercise 1.1: ADR Template and Workflow

```markdown
<!-- docs/adr/template.md -->
# ADR-NNN: [Short Title]

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Date

YYYY-MM-DD

## Decision Makers

- [Primary decision maker]
- [Other stakeholders involved in the decision]

## Context

### Problem Statement

_Describe the issue or opportunity that requires a decision. Include relevant background information._

### Requirements

_What must the solution provide?_

- Functional requirement 1
- Functional requirement 2
- Non-functional requirement 1 (e.g., scalability, security)

### Constraints

_What are the boundaries of the solution space?_

- Budget: $X
- Timeline: Y months
- Team capacity: Z engineers
- Must integrate with: [existing systems]

## Options Considered

### Option 1: [Name]

**Description:** Brief description of this approach.

**Pros:**
- Pro 1
- Pro 2

**Cons:**
- Con 1
- Con 2

**Estimated effort:** X person-months
**Estimated cost:** $Y

### Option 2: [Name]

**Description:** Brief description of this approach.

**Pros:**
- Pro 1
- Pro 2

**Cons:**
- Con 1
- Con 2

**Estimated effort:** X person-months
**Estimated cost:** $Y

### Option 3: [Name] (if applicable)

...

## Decision

We will implement **Option N** because:

1. Reason 1
2. Reason 2
3. Reason 3

## Consequences

### Positive

- Benefit 1
- Benefit 2

### Negative

- Drawback 1 (and how we'll mitigate it)
- Drawback 2 (and how we'll mitigate it)

### Neutral

- Observation 1

## Implementation Plan

### Phase 1: [Description] (Timeline: X weeks)
- Task 1
- Task 2

### Phase 2: [Description] (Timeline: Y weeks)
- Task 3
- Task 4

### Success Metrics

How will we know this decision was successful?

- Metric 1: [Target]
- Metric 2: [Target]

## Related ADRs

- [ADR-XXX](./adr-xxx.md): [Relationship]

## References

- [Link to relevant documentation]
- [Link to design docs]
- [Link to discussions]
```

### Exercise 1.2: ADR Management System

````python
# adr_manager/service.py
from dataclasses import dataclass, field
from typing import List, Optional, Dict
from datetime import datetime
from enum import Enum
import re
import os
from pathlib import Path

class ADRStatus(str, Enum):
    PROPOSED = "proposed"
    ACCEPTED = "accepted"
    DEPRECATED = "deprecated"
    SUPERSEDED = "superseded"
    REJECTED = "rejected"

@dataclass
class ADR:
    number: int
    title: str
    status: ADRStatus
    context: str
    decision: str
    consequences: Dict[str, List[str]]
    options_considered: List[Dict]
    date: datetime
    deciders: List[str]
    superseded_by: Optional[int] = None
    supersedes: Optional[int] = None
    related: List[int] = field(default_factory=list)
    tags: List[str] = field(default_factory=list)
    file_path: Optional[str] = None

class ADRManager:
    def __init__(self, adr_directory: str = "docs/adr"):
        self.adr_dir = Path(adr_directory)
        self.adr_dir.mkdir(parents=True, exist_ok=True)

    def create_adr(self, title: str, context: str, deciders: List[str]) -> ADR:
        """Create a new ADR with the next available number."""
        next_number = self._get_next_number()

        adr = ADR(
            number=next_number,
            title=title,
            status=ADRStatus.PROPOSED,
            context=context,
            decision="",
            consequences={"positive": [], "negative": [], "neutral": []},
            options_considered=[],
            date=datetime.now(),
            deciders=deciders
        )

        self._save_adr(adr)
        return adr

    def _get_next_number(self) -> int:
        """Get the next available ADR number."""
        existing = list(self.adr_dir.glob("adr-*.md"))
        if not existing:
            return 1

        numbers = []
        for f in existing:
            match = re.search(r'adr-(\d+)', f.stem)
            if match:
                numbers.append(int(match.group(1)))

        return max(numbers) + 1 if numbers else 1

    def _save_adr(self, adr: ADR):
        """Save ADR to markdown file."""
        filename = f"adr-{adr.number:03d}-{self._slugify(adr.title)}.md"
        filepath = self.adr_dir / filename
        adr.file_path = str(filepath)

        content = self._render_adr(adr)
        filepath.write_text(content)

    def _render_adr(self, adr: ADR) -> str:
        """Render ADR to markdown format."""
        status_line = f"**Status:** {adr.status.value.title()}"
        if adr.superseded_by:
            status_line += f" (superseded by [ADR-{adr.superseded_by:03d}](./adr-{adr.superseded_by:03d}.md))"

        options_md = ""
        for i, opt in enumerate(adr.options_considered, 1):
            options_md += f"\n### Option {i}: {opt.get('name', 'Unnamed')}\n\n"
            options_md += f"{opt.get('description', '')}\n\n"
            options_md += "**Pros:**\n"
            for pro in opt.get('pros', []):
                options_md += f"- {pro}\n"
            options_md += "\n**Cons:**\n"
            for con in opt.get('cons', []):
                options_md += f"- {con}\n"

        return f"""# ADR-{adr.number:03d}: {adr.title}

## Status

{status_line}

## Date

{adr.date.strftime('%Y-%m-%d')}

## Decision Makers

{chr(10).join(f'- {d}' for d in adr.deciders)}

## Context

{adr.context}

## Options Considered

{options_md}

## Decision

{adr.decision}

## Consequences

### Positive

{chr(10).join(f'- {c}' for c in adr.consequences.get('positive', []))}

### Negative

{chr(10).join(f'- {c}' for c in adr.consequences.get('negative', []))}

### Neutral

{chr(10).join(f'- {c}' for c in adr.consequences.get('neutral', []))}

## Related ADRs

{chr(10).join(f'- [ADR-{r:03d}](./adr-{r:03d}.md)' for r in adr.related) or 'None'}

## Tags

{', '.join(f'`{t}`' for t in adr.tags) or 'None'}
"""

    def accept_adr(self, number: int, decision: str, consequences: Dict):
        """Accept an ADR and record the decision."""
        adr = self.get_adr(number)
        adr.status = ADRStatus.ACCEPTED
        adr.decision = decision
        adr.consequences = consequences
        self._save_adr(adr)

    def supersede_adr(self, old_number: int, new_number: int):
        """Mark an ADR as superseded by another."""
        old_adr = self.get_adr(old_number)
        new_adr = self.get_adr(new_number)

        old_adr.status = ADRStatus.SUPERSEDED
        old_adr.superseded_by = new_number
        new_adr.supersedes = old_number

        self._save_adr(old_adr)
        self._save_adr(new_adr)

    def get_adr(self, number: int) -> ADR:
        """Load an ADR by number."""
        files = list(self.adr_dir.glob(f"adr-{number:03d}-*.md"))
        if not files:
            raise ValueError(f"ADR-{number:03d} not found")

        return self._parse_adr(files[0])

    def list_adrs(self, status: Optional[ADRStatus] = None, tags: List[str] = None) -> List[ADR]:
        """List all ADRs, optionally filtered."""
        adrs = []
        for f in sorted(self.adr_dir.glob("adr-*.md")):
            adr = self._parse_adr(f)
            if status and adr.status != status:
                continue
            if tags and not any(t in adr.tags for t in tags):
                continue
            adrs.append(adr)
        return adrs

    def generate_index(self) -> str:
        """Generate an index of all ADRs."""
        adrs = self.list_adrs()

        content = """# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for significant
architectural decisions made in this project.

## Index

| Number | Title | Status | Date |
|--------|-------|--------|------|
"""
        for adr in adrs:
            filename = Path(adr.file_path).name
            content += f"| [{adr.number:03d}](./{filename}) | {adr.title} | {adr.status.value.title()} | {adr.date.strftime('%Y-%m-%d')} |\n"

        content += """
## ADR Process

1. **Propose**: Create a new ADR using the template
2. **Review**: Discuss with stakeholders
3. **Decide**: Accept, reject, or modify
4. **Document**: Record the decision and rationale
5. **Communicate**: Share with the team

## Creating a New ADR

```bash
./scripts/new-adr.sh "Title of Decision"
```
"""
        index_path = self.adr_dir / "README.md"
        index_path.write_text(content)
        return content

    def _slugify(self, text: str) -> str:
        """Convert text to URL-friendly slug."""
        return re.sub(r'[^\w\s-]', '', text.lower()).replace(' ', '-')[:50]

    def _parse_adr(self, filepath: Path) -> ADR:
        """Parse an ADR from a markdown file."""
        content = filepath.read_text()
        # Simplified parsing - in production, use a proper markdown parser
        number_match = re.search(r'ADR-(\d+)', content)
        title_match = re.search(r'# ADR-\d+: (.+)', content)
        status_match = re.search(r'\*\*Status:\*\* (\w+)', content)

        return ADR(
            number=int(number_match.group(1)) if number_match else 0,
            title=title_match.group(1).strip() if title_match else "",
            status=ADRStatus(status_match.group(1).lower()) if status_match else ADRStatus.PROPOSED,
            context="",  # Would need proper parsing
            decision="",
            consequences={"positive": [], "negative": [], "neutral": []},
            options_considered=[],
            date=datetime.now(),
            deciders=[],
            file_path=str(filepath)
        )
````

## Part 2: RFC Process

### Exercise 2.1: RFC Template

````markdown
<!-- docs/rfcs/template.md -->
# RFC: [Title]

- **RFC Number:** RFC-NNNN
- **Author(s):** [Names and email addresses]
- **Status:** [Draft | Under Review | Accepted | Rejected | Withdrawn]
- **Created:** YYYY-MM-DD
- **Last Updated:** YYYY-MM-DD
- **Review Period Ends:** YYYY-MM-DD

## Summary

_One paragraph explanation of the proposal._

## Motivation

### Problem

_What problem does this RFC solve?_

### Goals

_What are the specific goals of this proposal?_

- Goal 1
- Goal 2
- Goal 3

### Non-Goals

_What is explicitly out of scope?_

- Non-goal 1
- Non-goal 2

## Proposal

### Overview

_High-level description of the proposed solution._

### Detailed Design

_Technical details of the implementation._

#### Component 1

_Description of component 1_

```yaml
# Example configuration or code
```

#### Component 2

_Description of component 2_

### API Changes

_Any API additions, modifications, or deprecations._

````
GET /api/v1/new-endpoint
POST /api/v1/new-endpoint
````

### Data Model Changes

_Any database schema or data structure changes._

```sql
ALTER TABLE users ADD COLUMN new_field VARCHAR(255);
```

### Migration Strategy

_How will existing systems/data be migrated?_

1. Step 1
2. Step 2
3. Step 3

## Drawbacks

_Why should we NOT do this?_

-
-

## Alternatives Considered

### Alternative 1: [Name]

_Description and why it wasn't chosen._

### Alternative 2: [Name]

_Description and why it wasn't chosen._

## Unresolved Questions

_What aspects of the design are still to be determined?_

1. Question 1
2. Question 2

## Future Possibilities

_What future work might this enable or suggest?_

-
-

## Implementation Plan

### Phase 1 (Estimated: X weeks)

- [ ] Task 1
- [ ] Task 2

### Phase 2 (Estimated: Y weeks)

- [ ] Task 3
- [ ] Task 4

### Success Criteria

_How will we measure success?_

| Metric | Current | Target |
|--------|---------|--------|
| Metric 1 | X | Y |
| Metric 2 | A | B |

## Stakeholders

| Role | Name | Approval Required |
|------|------|-------------------|
| Engineering Lead | @name | Yes |
| Product Owner | @name | Yes |
| Security | @name | Advisory |
| Platform Team | @name | Advisory |

## References

- [Link 1]()
- [Link 2]()

---

## Review Log

| Date | Reviewer | Feedback Summary | Status |
|------|----------|------------------|--------|
| YYYY-MM-DD | @name | Initial review comments | Addressed |
````

### Exercise 2.2: RFC Workflow Automation

```yaml
# .github/workflows/rfc-process.yaml
name: RFC Process

on:
  pull_request:
    paths:
      - 'docs/rfcs/**'
    types: [opened, edited, synchronize]

jobs:
  validate-rfc:
    name: Validate RFC
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check RFC format
        run: |
          for file in docs/rfcs/*.md; do
            if [[ "$file" != *"template.md"* ]] && [[ "$file" != *"README.md"* ]]; then
              echo "Validating: $file"

              # Check required sections
              required_sections=(
                "## Summary"
                "## Motivation"
                "## Proposal"
                "## Drawbacks"
                "## Alternatives Considered"
              )

              for section in "${required_sections[@]}"; do
                if ! grep -q "$section" "$file"; then
                  echo "ERROR: Missing section '$section' in $file"
                  exit 1
                fi
              done

              echo "✓ $file is valid"
            fi
          done

      - name: Extract RFC metadata
        id: metadata
        run: |
          file=$(git diff --name-only HEAD~1 | grep 'docs/rfcs/.*\.md' | head -1)
          if [ -n "$file" ]; then
            title=$(grep -m1 '^# RFC:' "$file" | sed 's/# RFC: //')
            author=$(grep -m1 'Author(s):' "$file" | sed 's/.*Author(s):\*\* //')
            status=$(grep -m1 'Status:' "$file" | sed 's/.*Status:\*\* //')

            echo "title=$title" >> $GITHUB_OUTPUT
            echo "author=$author" >> $GITHUB_OUTPUT
            echo "status=$status" >> $GITHUB_OUTPUT
          fi

  notify-stakeholders:
    name: Notify Stakeholders
    runs-on: ubuntu-latest
    needs: validate-rfc
    if: github.event.action == 'opened'
    steps:
      - uses: actions/checkout@v4

      - name: Send Slack notification
        uses: slackapi/slack-github-action@v1
        with:
          channel-id: ${{ secrets.RFC_CHANNEL_ID }}
          slack-message: |
            :page_facing_up: *New RFC Submitted*

            *Title:* ${{ needs.validate-rfc.outputs.title }}
            *Author:* ${{ needs.validate-rfc.outputs.author }}
            *PR:* ${{ github.event.pull_request.html_url }}

            Please review and provide feedback!

  check-approvals:
    name: Check Approvals
    runs-on: ubuntu-latest
    if: github.event.pull_request.merged == true
    steps:
      - uses: actions/checkout@v4

      - name: Verify required approvals
        uses: actions/github-script@v7
        with:
          script: |
            const { data: reviews } = await github.rest.pulls.listReviews({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number
            });

            const approvals = reviews
              .filter(r => r.state === 'APPROVED')
              .map(r => r.user.login);

            // Check against required approvers (from RFC metadata)
            const requiredApprovers = ['eng-lead', 'product-owner'];
            const missingApprovals = requiredApprovers.filter(a => !approvals.includes(a));

            if (missingApprovals.length > 0) {
              core.setFailed(`Missing required approvals from: ${missingApprovals.join(', ')}`);
            }
```

## Part 3: Decision-Making Frameworks

### Exercise 3.1: RAPID Decision Framework

```yaml
# frameworks/rapid-template.yaml
# RAPID: Recommend, Agree, Perform, Input, Decide

decision:
  title: "[Decision Title]"
  date: "YYYY-MM-DD"
  status: "pending | decided | implemented"

  context: |
    Brief description of the decision to be made.

  roles:
    recommend:
      # Who is responsible for making the recommendation?
      - name: "[Person/Team]"
        responsibility: "Gather data, analyze options, propose solution"

    agree:
      # Who must agree for the decision to proceed?
      # These are veto holders.
      - name: "[Person/Team]"
        area: "Security implications"
      - name: "[Person/Team]"
        area: "Budget approval"

    perform:
      # Who will execute the decision?
      - name: "[Person/Team]"
        responsibility: "Implementation lead"
      - name: "[Person/Team]"
        responsibility: "Testing and validation"

    input:
      # Who provides input but doesn't have decision authority?
      - name: "[Person/Team]"
        perspective: "Customer experience"
      - name: "[Person/Team]"
        perspective: "Operations"

    decide:
      # Who makes the final call?
      - name: "[Person]"
        authority: "Tie-breaker, final accountability"

  timeline:
    input_deadline: "YYYY-MM-DD"
    decision_deadline: "YYYY-MM-DD"
    implementation_start: "YYYY-MM-DD"

  recommendation:
    summary: ""
    rationale: ""
    risks: []

  decision_record:
    outcome: ""
    date: ""
    deciding_factors: []
```

### Exercise 3.2: Decision Matrix Tool

```python
# decision_matrix/tool.py
from dataclasses import dataclass
from typing import List, Dict
import json

@dataclass
class Criterion:
    name: str
    weight: float  # 0.0 to 1.0
    description: str

@dataclass
class Option:
    name: str
    description: str
    scores: Dict[str, float]  # criterion_name -> score (1-5)

class DecisionMatrix:
    def __init__(self, title: str):
        self.title = title
        self.criteria: List[Criterion] = []
        self.options: List[Option] = []

    def add_criterion(self, name: str, weight: float, description: str = ""):
        """Add a criterion to evaluate options against."""
        if not 0.0 <= weight <= 1.0:
            raise ValueError("Weight must be between 0 and 1")

        self.criteria.append(Criterion(
            name=name,
            weight=weight,
            description=description
        ))

    def add_option(self, name: str, description: str = ""):
        """Add an option to evaluate."""
        self.options.append(Option(
            name=name,
            description=description,
            scores={}
        ))

    def score_option(self, option_name: str, criterion_name: str, score: float):
        """Score an option on a specific criterion (1-5 scale)."""
        if not 1.0 <= score <= 5.0:
            raise ValueError("Score must be between 1 and 5")

        option = next((o for o in self.options if o.name == option_name), None)
        if not option:
            raise ValueError(f"Option '{option_name}' not found")

        option.scores[criterion_name] = score

    def calculate_scores(self) -> List[Dict]:
        """Calculate weighted scores for all options."""
        results = []

        for option in self.options:
            weighted_total = 0
            raw_total = 0
            breakdown = []

            for criterion in self.criteria:
                score = option.scores.get(criterion.name, 0)
                weighted_score = score * criterion.weight
                weighted_total += weighted_score
                raw_total += score

                breakdown.append({
                    "criterion": criterion.name,
                    "weight": criterion.weight,
                    "raw_score": score,
                    "weighted_score": round(weighted_score, 2)
                })

            results.append({
                "option": option.name,
                "description": option.description,
                "weighted_total": round(weighted_total, 2),
                "raw_total": raw_total,
                "breakdown": breakdown
            })

        # Sort by weighted total descending
        results.sort(key=lambda x: x["weighted_total"], reverse=True)
        return results

    def render_markdown(self) -> str:
        """Render the decision matrix as markdown."""
        results = self.calculate_scores()

        md = f"# Decision Matrix: {self.title}\n\n"

        # Criteria table
        md += "## Evaluation Criteria\n\n"
        md += "| Criterion | Weight | Description |\n"
        md += "|-----------|--------|-------------|\n"
        for c in self.criteria:
            md += f"| {c.name} | {c.weight:.0%} | {c.description} |\n"

        md += "\n## Scoring Matrix\n\n"
        md += "| Option |"
        for c in self.criteria:
            md += f" {c.name} |"
        md += " **Weighted Total** |\n"

        md += "|--------|"
        for _ in self.criteria:
            md += "--------|"
        md += "--------|\n"

        for r in results:
            md += f"| {r['option']} |"
            for c in self.criteria:
                breakdown = next(
                    (b for b in r['breakdown'] if b['criterion'] == c.name),
                    None
                )
                if breakdown:
                    md += f" {breakdown['raw_score']} |"
                else:
                    md += " - |"
            md += f" **{r['weighted_total']:.2f}** |\n"

        md += "\n## Recommendation\n\n"
        if results:
            winner = results[0]
            md += f"Based on the weighted analysis, **{winner['option']}** "
            md += f"scores highest with a weighted total of **{winner['weighted_total']:.2f}**.\n"

        return md

    def to_json(self) -> str:
        """Export decision matrix as JSON."""
        return json.dumps({
            "title": self.title,
            "criteria": [
                {"name": c.name, "weight": c.weight, "description": c.description}
                for c in self.criteria
            ],
            "options": [
                {"name": o.name, "description": o.description, "scores": o.scores}
                for o in self.options
            ],
            "results": self.calculate_scores()
        }, indent=2)


# Example usage
def example_database_decision():
    matrix = DecisionMatrix("Database Selection for User Service")

    # Add criteria
    matrix.add_criterion("performance", 0.25, "Query performance and scalability")
    matrix.add_criterion("reliability", 0.25, "Uptime and data durability")
    matrix.add_criterion("operability", 0.20, "Ease of management and monitoring")
    matrix.add_criterion("cost", 0.15, "Total cost of ownership")
    matrix.add_criterion("team_familiarity", 0.15, "Team experience with the technology")

    # Add options
    matrix.add_option("PostgreSQL", "Open-source relational database")
    matrix.add_option("MySQL", "Open-source relational database")
    matrix.add_option("MongoDB", "Document-oriented NoSQL database")
    matrix.add_option("DynamoDB", "AWS managed NoSQL database")

    # Score options
    scores = {
        "PostgreSQL": {"performance": 4, "reliability": 5, "operability": 4, "cost": 5, "team_familiarity": 5},
        "MySQL": {"performance": 4, "reliability": 4, "operability": 4, "cost": 5, "team_familiarity": 4},
        "MongoDB": {"performance": 4, "reliability": 4, "operability": 3, "cost": 4, "team_familiarity": 2},
        "DynamoDB": {"performance": 5, "reliability": 5, "operability": 5, "cost": 3, "team_familiarity": 2},
    }

    for option, option_scores in scores.items():
        for criterion, score in option_scores.items():
            matrix.score_option(option, criterion, score)

    return matrix.render_markdown()
```

## Part 4: Building Consensus

### Exercise 4.1: Stakeholder Management

```yaml
# stakeholder/analysis-template.yaml
stakeholder_analysis:
  decision: "[Decision Title]"
  date: "YYYY-MM-DD"

  stakeholders:
    - name: "[Name/Role]"
      interest_level: high | medium | low
      influence_level: high | medium | low
      position: supporter | neutral | opponent | unknown
      key_concerns:
        - "Concern 1"
        - "Concern 2"
      engagement_strategy: |
        How to engage this stakeholder effectively
      communication_preference: "email | slack | meeting | document"

    - name: "[Name/Role]"
      interest_level: medium
      influence_level: high
      position: neutral
      key_concerns:
        - "Budget implications"
      engagement_strategy: |
        Schedule 1:1 to discuss budget and ROI
      communication_preference: "meeting"

  engagement_plan:
    phase_1_awareness:
      actions:
        - "Send overview document to all stakeholders"
        - "Schedule Q&A session"
      timeline: "Week 1"

    phase_2_consultation:
      actions:
        - "Individual meetings with high-influence stakeholders"
        - "Collect feedback and concerns"
      timeline: "Week 2-3"

    phase_3_alignment:
      actions:
        - "Present revised proposal addressing concerns"
        - "Build coalition of supporters"
      timeline: "Week 4"

    phase_4_decision:
      actions:
        - "Final stakeholder meeting"
        - "Document decision and commitments"
      timeline: "Week 5"
```

### Exercise 4.2: Consensus Building Workshop

```markdown
<!-- workshops/consensus-building.md -->
# Consensus Building Workshop

## Overview

Duration: 2-3 hours
Participants: 5-15 people
Facilitator required: Yes

## Agenda

### 1. Opening (10 minutes)

- Welcome and ground rules
- Review decision to be made
- Clarify decision-making process

**Ground Rules:**
- Everyone's voice matters equally
- Disagree with ideas, not people
- Seek to understand before being understood
- Silence is not agreement

### 2. Context Setting (15 minutes)

Present:
- Background and problem statement
- Constraints and requirements
- Options being considered
- Evaluation criteria

### 3. Individual Reflection (10 minutes)

Each participant answers:
1. What's most important to you in this decision?
2. What concerns do you have about each option?
3. What would you need to feel comfortable with a decision?

### 4. Small Group Discussion (30 minutes)

- Groups of 3-4 people
- Discuss individual perspectives
- Identify common themes
- Note key disagreements

### 5. Full Group Sharing (20 minutes)

Each group shares:
- Key themes from discussion
- Main concerns raised
- Areas of agreement

### 6. Concern Resolution (30 minutes)

For each major concern:
1. Clarify the concern
2. Brainstorm mitigations
3. Check if concern is addressed

Use the "Concerns Ladder":
- Block: Cannot proceed unless addressed
- Concern: Should be addressed but won't block
- Reservation: Minor issue, can live with it
- Support: Actively in favor

### 7. Proposal Testing (15 minutes)

Test current proposal:
- Ask each person: "Can you support this proposal?"
- If no, ask: "What would need to change?"
- Iterate until consensus or impasse

### 8. Decision Documentation (10 minutes)

Record:
- Final decision
- Key modifications made
- Remaining concerns and mitigations
- Commitments from each stakeholder

### 9. Close (10 minutes)

- Summarize next steps
- Thank participants
- Schedule follow-up

## Facilitation Tips

### When Stuck

- "What would need to be true for you to support this?"
- "Let's park this and come back to it"
- "Can we try a smaller experiment first?"

### Managing Dominant Voices

- "Let's hear from someone who hasn't spoken yet"
- Use round-robin for initial sharing
- Written input before discussion

### Finding Common Ground

- "What do we all agree on?"
- "What's the best outcome we could achieve?"
- Focus on interests, not positions

## Post-Workshop

- [ ] Send summary within 24 hours
- [ ] Create action items with owners
- [ ] Schedule check-in for one week out
- [ ] Document learnings for future workshops
```

## Verification Checklist

After completing this lab, verify:

- [ ] ADR template is created and documented
- [ ] ADR management workflow is functional
- [ ] RFC process is defined with approval gates
- [ ] RAPID framework is understood by team
- [ ] Decision matrix tool is available
- [ ] Stakeholder analysis template exists
- [ ] Consensus building process is documented

## Troubleshooting

### Decisions Taking Too Long

1. Set clear deadlines
2. Limit decision scope
3. Use time-boxed discussions
4. Identify and resolve blockers early

### Lack of Participation

1. Make input async-first
2. Reach out to quiet stakeholders 1:1
3. Create safe spaces for dissent
4. Acknowledge all contributions

### Revisiting Decided Topics

1. Document decisions thoroughly
2. Include rationale and context
3. Set clear change process
4. Point back to ADR/RFC

## Summary

In this lab, you learned to:

- Create and manage Architecture Decision Records
- Run an RFC process for significant changes
- Use decision-making frameworks (RAPID, decision matrix)
- Analyze and engage stakeholders
- Build consensus across diverse groups
- Document decisions for future reference

Good technical leadership is about making decisions effectively and bringing others along. The frameworks and tools in this lab help ensure decisions are well-reasoned, well-documented, and have broad support.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Architecture Decision Records
- Decision
- Consequences
- Status

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The platform makes developers more productive."* |
| ✓ | *"A golden path is a template that produces a repository with CI, manifests, dashboards and alerts already wired, so the product team owns none of them. It reduces cognitive load by removing decisions, not by adding features — and without a documented escape hatch it is a cage."* |

**Trace it:** A developer commits `service.yaml` → a running service with a dashboard and a paging rule. Name every system that acts, and which team owns each one.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Team Topologies — cognitive load](https://teamtopologies.com/key-concepts) and the [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) — why golden paths exist at all.
Full list per domain: [`SOURCES.md`](../SOURCES.md#platform-engineering)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
