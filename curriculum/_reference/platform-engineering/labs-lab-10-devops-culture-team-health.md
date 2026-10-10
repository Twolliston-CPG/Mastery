# Lab 10: DevOps Culture and Team Health

## Lab Overview

| Attribute | Details |
|-----------|---------|
| **Duration** | 3 hours |
| **Level** | Intermediate |
| **Prerequisites** | Team leadership experience, basic survey tools |
| **Environment** | Collaboration tools, survey platforms |
| **Learning Objectives** | Assess team health, implement cultural practices, measure improvement |

## Introduction

Technical excellence alone doesn't create high-performing teams. This lab covers implementing practices that foster psychological safety, continuous improvement, and sustainable pace. You'll learn to assess team health, run effective retrospectives, and build a culture of learning.

## Part 1: Team Health Assessment

### Health Check Models

**Squad health check**

Each team rates itself on eleven dimensions, using three levels: 🟢 *awesome* · 🟡 *some issues* ·
🔴 *bad*.

| | | |
|---|---|---|
| Delivering value | Easy to release | Health of codebase |
| Learning | Mission | Fun |
| Pawns or players | Speed | Suitable process |
| Support | Teamwork | |

Two rules make this useful rather than theatrical:

- **The team rates itself.** A score assigned from outside measures how the team feels about being
  measured, not how it is doing.
- **The trend is the data, not the colour.** One red is a conversation. The same dimension going from
  green to yellow to red over three quarters is a finding — and it is usually the one nobody was
  raising in a retro.

*Pawns or players* is the dimension worth watching. It asks whether the team controls its own work,
and it is the one a platform most directly moves — in either direction.

### Exercise 1.1: Health Check Survey Implementation

```python
# team_health/survey.py
from dataclasses import dataclass, field
from typing import List, Dict, Optional
from datetime import datetime
from enum import Enum
import statistics

class HealthStatus(str, Enum):
    GREEN = "green"
    YELLOW = "yellow"
    RED = "red"

class TrendDirection(str, Enum):
    UP = "up"
    STABLE = "stable"
    DOWN = "down"

@dataclass
class HealthDimension:
    name: str
    description: str
    awesome_example: str  # What green looks like
    bad_example: str      # What red looks like

SQUAD_HEALTH_DIMENSIONS = [
    HealthDimension(
        name="Delivering Value",
        description="We deliver great stuff! We're proud of it and our stakeholders are happy.",
        awesome_example="We deliver great stuff! We're proud of it and stakeholders are really happy.",
        bad_example="We deliver crap. We feel ashamed to deliver it. Stakeholders hate us."
    ),
    HealthDimension(
        name="Easy to Release",
        description="Releasing is simple, safe, painless and mostly automated.",
        awesome_example="Releasing is simple, safe, painless & mostly automated.",
        bad_example="Releasing is risky, painful, lots of manual work, takes forever."
    ),
    HealthDimension(
        name="Health of Codebase",
        description="We're proud of the quality of our code! It's clean, easy to read, and has good test coverage.",
        awesome_example="We're proud of our code! Clean, easy to read, well tested.",
        bad_example="Our code is a pile of dung. Technical debt is raging out of control."
    ),
    HealthDimension(
        name="Learning",
        description="We're learning lots of interesting stuff all the time!",
        awesome_example="We're learning lots of interesting stuff all the time!",
        bad_example="We never have time to learn anything new."
    ),
    HealthDimension(
        name="Mission",
        description="We know exactly why we are here and we're excited about it!",
        awesome_example="We know exactly why we're here and we're excited about it!",
        bad_example="We have no idea why we're here. No clear vision or purpose."
    ),
    HealthDimension(
        name="Fun",
        description="We love going to work and have great fun working together!",
        awesome_example="We love going to work and have great fun together!",
        bad_example="Boooring. Work sucks."
    ),
    HealthDimension(
        name="Pawns or Players",
        description="We're in control of our own destiny! We decide what to build and how to build it.",
        awesome_example="We're in control of our destiny! We decide what to build and how.",
        bad_example="We're just pawns in a game with no influence over what we build."
    ),
    HealthDimension(
        name="Speed",
        description="We get stuff done really quickly! No waiting and no delays.",
        awesome_example="We get stuff done really quickly! No waiting and no delays.",
        bad_example="We never get anything done. Constantly stuck waiting or delayed."
    ),
    HealthDimension(
        name="Suitable Process",
        description="Our way of working fits us perfectly!",
        awesome_example="Our way of working fits us perfectly!",
        bad_example="Our way of working sucks. Too much bureaucracy or chaos."
    ),
    HealthDimension(
        name="Support",
        description="We always get great support and help when needed!",
        awesome_example="We always get great support and help when needed!",
        bad_example="We're on our own. No help available, feel stuck."
    ),
    HealthDimension(
        name="Teamwork",
        description="We're a great team! We work well together and collaborate effectively.",
        awesome_example="We're a great team that works well together!",
        bad_example="We're a bunch of individuals, not really working as a team."
    ),
]

@dataclass
class HealthCheckResponse:
    dimension: str
    status: HealthStatus
    trend: TrendDirection
    comment: Optional[str] = None
    respondent_id: str = ""
    timestamp: datetime = field(default_factory=datetime.utcnow)

@dataclass
class TeamHealthReport:
    team_name: str
    survey_date: datetime
    responses: List[HealthCheckResponse]
    participant_count: int

    def get_dimension_summary(self, dimension: str) -> Dict:
        dim_responses = [r for r in self.responses if r.dimension == dimension]
        if not dim_responses:
            return {}

        status_counts = {
            HealthStatus.GREEN: 0,
            HealthStatus.YELLOW: 0,
            HealthStatus.RED: 0
        }
        trend_counts = {
            TrendDirection.UP: 0,
            TrendDirection.STABLE: 0,
            TrendDirection.DOWN: 0
        }

        for r in dim_responses:
            status_counts[r.status] += 1
            trend_counts[r.trend] += 1

        # Determine overall status (majority wins, ties go to worse)
        max_status_count = max(status_counts.values())
        for status in [HealthStatus.RED, HealthStatus.YELLOW, HealthStatus.GREEN]:
            if status_counts[status] == max_status_count:
                overall_status = status
                break

        # Determine overall trend
        max_trend_count = max(trend_counts.values())
        for trend in [TrendDirection.DOWN, TrendDirection.STABLE, TrendDirection.UP]:
            if trend_counts[trend] == max_trend_count:
                overall_trend = trend
                break

        return {
            "dimension": dimension,
            "overall_status": overall_status,
            "overall_trend": overall_trend,
            "status_distribution": status_counts,
            "trend_distribution": trend_counts,
            "comments": [r.comment for r in dim_responses if r.comment],
            "response_count": len(dim_responses)
        }

    def generate_summary(self) -> Dict:
        summaries = {}
        for dim in SQUAD_HEALTH_DIMENSIONS:
            summaries[dim.name] = self.get_dimension_summary(dim.name)

        # Calculate overall health score (green=3, yellow=2, red=1)
        scores = []
        for dim_name, summary in summaries.items():
            if summary:
                status = summary["overall_status"]
                if status == HealthStatus.GREEN:
                    scores.append(3)
                elif status == HealthStatus.YELLOW:
                    scores.append(2)
                else:
                    scores.append(1)

        avg_score = statistics.mean(scores) if scores else 0

        return {
            "team": self.team_name,
            "date": self.survey_date.isoformat(),
            "participant_count": self.participant_count,
            "dimensions": summaries,
            "overall_score": round(avg_score, 2),
            "health_rating": self._score_to_rating(avg_score)
        }

    def _score_to_rating(self, score: float) -> str:
        if score >= 2.5:
            return "Healthy"
        elif score >= 2.0:
            return "Some Concerns"
        else:
            return "Needs Attention"


class TeamHealthService:
    def __init__(self, db):
        self.db = db

    async def create_survey(self, team_name: str, dimensions: List[str] = None) -> str:
        """Create a new health check survey for a team."""
        survey_id = generate_id()
        dimensions = dimensions or [d.name for d in SQUAD_HEALTH_DIMENSIONS]

        await self.db.surveys.insert({
            "id": survey_id,
            "team": team_name,
            "dimensions": dimensions,
            "created_at": datetime.utcnow(),
            "status": "active",
            "responses": []
        })

        return survey_id

    async def submit_response(self, survey_id: str, responses: List[HealthCheckResponse]):
        """Submit a health check response."""
        await self.db.surveys.update(
            {"id": survey_id},
            {"$push": {"responses": {"$each": [r.__dict__ for r in responses]}}}
        )

    async def generate_report(self, survey_id: str) -> TeamHealthReport:
        """Generate a health report from survey responses."""
        survey = await self.db.surveys.find_one({"id": survey_id})

        responses = [
            HealthCheckResponse(**r) for r in survey["responses"]
        ]

        unique_respondents = len(set(r.respondent_id for r in responses))

        return TeamHealthReport(
            team_name=survey["team"],
            survey_date=survey["created_at"],
            responses=responses,
            participant_count=unique_respondents
        )

    async def get_trend(self, team_name: str, months: int = 6) -> List[Dict]:
        """Get health trend over time."""
        cutoff = datetime.utcnow() - timedelta(days=months * 30)

        surveys = await self.db.surveys.find({
            "team": team_name,
            "created_at": {"$gte": cutoff}
        }).sort("created_at", 1).to_list(100)

        trends = []
        for survey in surveys:
            report = TeamHealthReport(
                team_name=survey["team"],
                survey_date=survey["created_at"],
                responses=[HealthCheckResponse(**r) for r in survey["responses"]],
                participant_count=len(set(r["respondent_id"] for r in survey["responses"]))
            )
            summary = report.generate_summary()
            trends.append({
                "date": summary["date"],
                "overall_score": summary["overall_score"],
                "dimensions": {
                    name: dim["overall_status"].value
                    for name, dim in summary["dimensions"].items()
                    if dim
                }
            })

        return trends
```

### Exercise 1.2: Health Check Dashboard

```typescript
// components/TeamHealthDashboard.tsx
import React, { useState, useEffect } from 'react';
import {
  Grid,
  Card,
  CardContent,
  Typography,
  Chip,
  Tooltip,
  Box,
} from '@material-ui/core';
import {
  TrendingUp,
  TrendingDown,
  TrendingFlat,
} from '@material-ui/icons';
import { Line } from 'react-chartjs-2';
import { useApi } from '@backstage/core-plugin-api';
import { teamHealthApiRef } from '../api';

interface DimensionStatus {
  dimension: string;
  overall_status: 'green' | 'yellow' | 'red';
  overall_trend: 'up' | 'stable' | 'down';
  comments: string[];
}

interface HealthReport {
  team: string;
  date: string;
  overall_score: number;
  health_rating: string;
  dimensions: Record<string, DimensionStatus>;
}

export const TeamHealthDashboard: React.FC<{ teamName: string }> = ({ teamName }) => {
  const healthApi = useApi(teamHealthApiRef);
  const [report, setReport] = useState<HealthReport | null>(null);
  const [trend, setTrend] = useState<any[]>([]);

  useEffect(() => {
    const loadData = async () => {
      const [latestReport, trendData] = await Promise.all([
        healthApi.getLatestReport(teamName),
        healthApi.getTrend(teamName, 6),
      ]);
      setReport(latestReport);
      setTrend(trendData);
    };
    loadData();
  }, [healthApi, teamName]);

  if (!report) {
    return <Typography>Loading...</Typography>;
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'green':
        return '#4caf50';
      case 'yellow':
        return '#ff9800';
      case 'red':
        return '#f44336';
      default:
        return '#9e9e9e';
    }
  };

  const getTrendIcon = (trend: string) => {
    switch (trend) {
      case 'up':
        return <TrendingUp style={{ color: '#4caf50' }} />;
      case 'down':
        return <TrendingDown style={{ color: '#f44336' }} />;
      default:
        return <TrendingFlat style={{ color: '#9e9e9e' }} />;
    }
  };

  const trendChartData = {
    labels: trend.map(t => new Date(t.date).toLocaleDateString()),
    datasets: [
      {
        label: 'Health Score',
        data: trend.map(t => t.overall_score),
        borderColor: '#2196f3',
        backgroundColor: 'rgba(33, 150, 243, 0.1)',
        tension: 0.4,
      },
    ],
  };

  return (
    <Grid container spacing={3}>
      {/* Overall Score */}
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Overall Health
            </Typography>
            <Box display="flex" alignItems="center" justifyContent="center">
              <Typography variant="h2" style={{ fontWeight: 'bold' }}>
                {report.overall_score.toFixed(1)}
              </Typography>
              <Typography variant="body1" style={{ marginLeft: 8 }}>
                / 3.0
              </Typography>
            </Box>
            <Typography
              variant="h6"
              align="center"
              style={{ color: getStatusColor(report.health_rating === 'Healthy' ? 'green' : 'yellow') }}
            >
              {report.health_rating}
            </Typography>
          </CardContent>
        </Card>
      </Grid>

      {/* Trend Chart */}
      <Grid item xs={12} md={8}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              6-Month Trend
            </Typography>
            <Line
              data={trendChartData}
              options={{
                scales: {
                  y: {
                    min: 1,
                    max: 3,
                  },
                },
                plugins: {
                  legend: {
                    display: false,
                  },
                },
              }}
            />
          </CardContent>
        </Card>
      </Grid>

      {/* Dimension Cards */}
      {Object.entries(report.dimensions).map(([name, dimension]) => (
        <Grid item xs={12} sm={6} md={4} key={name}>
          <Card
            style={{
              borderLeft: `4px solid ${getStatusColor(dimension.overall_status)}`,
            }}
          >
            <CardContent>
              <Box display="flex" justifyContent="space-between" alignItems="center">
                <Typography variant="subtitle1" style={{ fontWeight: 'bold' }}>
                  {name}
                </Typography>
                {getTrendIcon(dimension.overall_trend)}
              </Box>
              <Chip
                label={dimension.overall_status.toUpperCase()}
                style={{
                  backgroundColor: getStatusColor(dimension.overall_status),
                  color: 'white',
                  marginTop: 8,
                }}
                size="small"
              />
              {dimension.comments.length > 0 && (
                <Tooltip
                  title={
                    <div>
                      {dimension.comments.map((c, i) => (
                        <p key={i}>&quot;{c}&quot;</p>
                      ))}
                    </div>
                  }
                >
                  <Typography
                    variant="body2"
                    color="textSecondary"
                    style={{ marginTop: 8, cursor: 'pointer' }}
                  >
                    {dimension.comments.length} comment(s)
                  </Typography>
                </Tooltip>
              )}
            </CardContent>
          </Card>
        </Grid>
      ))}
    </Grid>
  );
};
```

## Part 2: Retrospectives and Continuous Improvement

### Exercise 2.1: Retrospective Templates

```yaml
# retrospectives/templates.yaml
templates:
  - name: standard
    title: "Start, Stop, Continue"
    description: "Classic retrospective format"
    columns:
      - name: start
        title: "Start Doing"
        color: "#4caf50"
        prompt: "What should we start doing?"
      - name: stop
        title: "Stop Doing"
        color: "#f44336"
        prompt: "What should we stop doing?"
      - name: continue
        title: "Continue Doing"
        color: "#2196f3"
        prompt: "What's working well?"

  - name: sailboat
    title: "Sailboat"
    description: "Navigate your team's journey"
    columns:
      - name: wind
        title: "Wind (Helps Us)"
        color: "#4caf50"
        icon: "air"
        prompt: "What's pushing us forward?"
      - name: anchor
        title: "Anchor (Slows Us)"
        color: "#f44336"
        icon: "anchor"
        prompt: "What's holding us back?"
      - name: rocks
        title: "Rocks (Risks)"
        color: "#ff9800"
        icon: "warning"
        prompt: "What risks do we see ahead?"
      - name: island
        title: "Island (Goals)"
        color: "#2196f3"
        icon: "flag"
        prompt: "Where are we trying to go?"

  - name: four_ls
    title: "4 L's"
    description: "Liked, Learned, Lacked, Longed For"
    columns:
      - name: liked
        title: "Liked"
        color: "#4caf50"
        prompt: "What did you like about this iteration?"
      - name: learned
        title: "Learned"
        color: "#2196f3"
        prompt: "What did you learn?"
      - name: lacked
        title: "Lacked"
        color: "#f44336"
        prompt: "What was missing or lacking?"
      - name: longed_for
        title: "Longed For"
        color: "#9c27b0"
        prompt: "What do you wish for going forward?"

  - name: glad_sad_mad
    title: "Glad, Sad, Mad"
    description: "Emotional retrospective"
    columns:
      - name: glad
        title: "Glad"
        color: "#4caf50"
        emoji: "😊"
        prompt: "What made you happy?"
      - name: sad
        title: "Sad"
        color: "#2196f3"
        emoji: "😢"
        prompt: "What disappointed you?"
      - name: mad
        title: "Mad"
        color: "#f44336"
        emoji: "😠"
        prompt: "What frustrated you?"

  - name: starfish
    title: "Starfish"
    description: "Five-point retrospective"
    columns:
      - name: keep
        title: "Keep Doing"
        color: "#4caf50"
      - name: less
        title: "Do Less"
        color: "#ff9800"
      - name: more
        title: "Do More"
        color: "#2196f3"
      - name: stop
        title: "Stop Doing"
        color: "#f44336"
      - name: start
        title: "Start Doing"
        color: "#9c27b0"
```

### Exercise 2.2: Action Item Tracking

```python
# retrospectives/actions.py
from dataclasses import dataclass, field
from typing import List, Optional
from datetime import datetime, timedelta
from enum import Enum

class ActionStatus(str, Enum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    BLOCKED = "blocked"

class ActionPriority(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

@dataclass
class ActionItem:
    id: str
    title: str
    description: str
    owner: str
    team: str
    status: ActionStatus = ActionStatus.OPEN
    priority: ActionPriority = ActionPriority.MEDIUM
    due_date: Optional[datetime] = None
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    retro_id: Optional[str] = None
    tags: List[str] = field(default_factory=list)
    blockers: List[str] = field(default_factory=list)

class ActionItemService:
    def __init__(self, db, notification_service):
        self.db = db
        self.notifications = notification_service

    async def create_action(self, action: ActionItem) -> ActionItem:
        """Create a new action item from retrospective."""
        action.id = generate_id()

        # Set default due date if not provided (2 weeks)
        if not action.due_date:
            action.due_date = datetime.utcnow() + timedelta(days=14)

        await self.db.actions.insert(action.__dict__)

        # Notify owner
        await self.notifications.send(
            user=action.owner,
            message=f"New action item assigned: {action.title}",
            action_url=f"/actions/{action.id}"
        )

        return action

    async def update_status(self, action_id: str, status: ActionStatus, user: str):
        """Update action item status."""
        action = await self.db.actions.find_one({"id": action_id})

        old_status = action["status"]
        action["status"] = status.value
        action["updated_at"] = datetime.utcnow()

        if status == ActionStatus.COMPLETED:
            action["completed_at"] = datetime.utcnow()

        await self.db.actions.update({"id": action_id}, action)

        # Track completion rate for team metrics
        if status == ActionStatus.COMPLETED:
            await self._record_completion(action)

    async def get_team_actions(self, team: str, include_completed: bool = False) -> List[ActionItem]:
        """Get all action items for a team."""
        query = {"team": team}
        if not include_completed:
            query["status"] = {"$nin": [ActionStatus.COMPLETED.value, ActionStatus.CANCELLED.value]}

        actions = await self.db.actions.find(query).sort("due_date", 1).to_list(100)
        return [ActionItem(**a) for a in actions]

    async def get_overdue_actions(self, team: Optional[str] = None) -> List[ActionItem]:
        """Get overdue action items."""
        query = {
            "status": {"$in": [ActionStatus.OPEN.value, ActionStatus.IN_PROGRESS.value]},
            "due_date": {"$lt": datetime.utcnow()}
        }
        if team:
            query["team"] = team

        actions = await self.db.actions.find(query).to_list(100)
        return [ActionItem(**a) for a in actions]

    async def get_completion_metrics(self, team: str, months: int = 3) -> Dict:
        """Get action item completion metrics for a team."""
        cutoff = datetime.utcnow() - timedelta(days=months * 30)

        pipeline = [
            {"$match": {"team": team, "created_at": {"$gte": cutoff}}},
            {"$group": {
                "_id": "$status",
                "count": {"$sum": 1}
            }}
        ]

        results = await self.db.actions.aggregate(pipeline).to_list(10)

        counts = {r["_id"]: r["count"] for r in results}
        total = sum(counts.values())
        completed = counts.get(ActionStatus.COMPLETED.value, 0)

        return {
            "total_actions": total,
            "completed": completed,
            "completion_rate": round(completed / total * 100, 1) if total > 0 else 0,
            "by_status": counts,
            "average_completion_time": await self._get_avg_completion_time(team, cutoff)
        }

    async def _get_avg_completion_time(self, team: str, since: datetime) -> float:
        """Calculate average time to complete action items."""
        pipeline = [
            {"$match": {
                "team": team,
                "status": ActionStatus.COMPLETED.value,
                "created_at": {"$gte": since}
            }},
            {"$project": {
                "completion_time": {
                    "$subtract": ["$completed_at", "$created_at"]
                }
            }},
            {"$group": {
                "_id": None,
                "avg_time": {"$avg": "$completion_time"}
            }}
        ]

        results = await self.db.actions.aggregate(pipeline).to_list(1)
        if results:
            # Convert milliseconds to days
            return round(results[0]["avg_time"] / (1000 * 60 * 60 * 24), 1)
        return 0
```

## Part 3: Psychological Safety Practices

### Exercise 3.1: Blameless Postmortem Guide

```markdown
<!-- templates/postmortem-template.md -->
# Incident Postmortem: [Incident Title]

**Incident ID:** INC-XXXX
**Date:** YYYY-MM-DD
**Duration:** X hours Y minutes
**Severity:** SEV-1/2/3
**Author:** [Name]
**Reviewers:** [Names]

---

## Executive Summary

_A 2-3 sentence summary of what happened, impact, and resolution._

## Timeline

_All times in UTC_

| Time | Event |
|------|-------|
| HH:MM | First alert triggered |
| HH:MM | On-call engineer paged |
| HH:MM | Issue identified |
| HH:MM | Mitigation applied |
| HH:MM | Service restored |

## Impact

### Customer Impact
- Number of users affected: X
- Error rate: X%
- Duration of degradation: X minutes

### Business Impact
- Revenue impact: $X
- SLA impact: X minutes of downtime
- Support tickets created: X

## Root Cause Analysis

### What Happened

_Describe the technical failure chain. Be specific and factual._

### Why It Happened

_Use the "5 Whys" technique to identify underlying causes._

1. **Why did X fail?** Because Y happened.
2. **Why did Y happen?** Because Z was in place.
3. **Why was Z in place?** Because...
4. **Why...?** Because...
5. **Why...?** Root cause: ...

### Contributing Factors

_List all factors that contributed to the incident or its duration._

- [ ] Configuration change
- [ ] Code deployment
- [ ] Infrastructure change
- [ ] External dependency failure
- [ ] Monitoring gap
- [ ] Runbook/documentation issue
- [ ] Other: ___

## What Went Well

_Acknowledge what worked during the incident response._

-
-
-

## What Could Be Improved

_Focus on systems and processes, not individuals._

-
-
-

## Action Items

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| Add monitoring for X | @person | High | YYYY-MM-DD | Open |
| Update runbook for Y | @person | Medium | YYYY-MM-DD | Open |
| Implement circuit breaker | @person | High | YYYY-MM-DD | Open |

## Lessons Learned

_What did we learn that can help prevent similar incidents?_

1.
2.
3.

## References

- [Incident Slack Channel](#)
- [Related Dashboards](#)
- [Deployment Logs](#)

---

## Appendix

### Related Incidents

_List any related past incidents._

### Technical Deep Dive

_Include detailed technical analysis if needed._

---

**Review Sign-off:**

- [ ] Engineering Lead
- [ ] Product Owner
- [ ] On-Call Team
```

### Exercise 3.2: Psychological Safety Survey

```python
# safety/assessment.py
from dataclasses import dataclass
from typing import List, Dict
from datetime import datetime

PSYCHOLOGICAL_SAFETY_QUESTIONS = [
    {
        "id": "mistake_held_against",
        "text": "If I make a mistake on this team, it is NOT held against me.",
        "category": "safety",
        "reverse_scored": False
    },
    {
        "id": "problems_raised",
        "text": "Members of this team are able to bring up problems and tough issues.",
        "category": "voice",
        "reverse_scored": False
    },
    {
        "id": "reject_different",
        "text": "People on this team sometimes reject others for being different.",
        "category": "inclusion",
        "reverse_scored": True
    },
    {
        "id": "safe_to_risk",
        "text": "It is safe to take a risk on this team.",
        "category": "safety",
        "reverse_scored": False
    },
    {
        "id": "ask_for_help",
        "text": "It is easy to ask other members of this team for help.",
        "category": "help",
        "reverse_scored": False
    },
    {
        "id": "undermine_efforts",
        "text": "No one on this team would deliberately act in a way that undermines my efforts.",
        "category": "trust",
        "reverse_scored": False
    },
    {
        "id": "skills_valued",
        "text": "Working with members of this team, my unique skills and talents are valued and utilized.",
        "category": "belonging",
        "reverse_scored": False
    },
    # Additional questions for deeper assessment
    {
        "id": "admit_not_knowing",
        "text": "I feel comfortable admitting when I don't know something.",
        "category": "learning",
        "reverse_scored": False
    },
    {
        "id": "challenge_status_quo",
        "text": "I feel safe to challenge how we do things if I think there's a better way.",
        "category": "voice",
        "reverse_scored": False
    },
    {
        "id": "share_bad_news",
        "text": "I can share bad news with my team without fear of blame.",
        "category": "safety",
        "reverse_scored": False
    }
]

@dataclass
class SafetyResponse:
    question_id: str
    score: int  # 1-5 Likert scale
    respondent_id: str
    timestamp: datetime

class PsychologicalSafetyService:
    def __init__(self, db):
        self.db = db

    async def calculate_safety_score(self, team: str) -> Dict:
        """Calculate psychological safety score for a team."""
        responses = await self.db.safety_responses.find({
            "team": team,
            "timestamp": {"$gte": datetime.utcnow() - timedelta(days=90)}
        }).to_list(1000)

        if not responses:
            return {"error": "No responses found"}

        scores_by_question = {}
        for r in responses:
            if r["question_id"] not in scores_by_question:
                scores_by_question[r["question_id"]] = []

            # Handle reverse scoring
            question = next(q for q in PSYCHOLOGICAL_SAFETY_QUESTIONS
                          if q["id"] == r["question_id"])
            score = r["score"]
            if question["reverse_scored"]:
                score = 6 - score  # Reverse 1-5 scale

            scores_by_question[r["question_id"]].append(score)

        # Calculate averages
        question_averages = {
            qid: sum(scores) / len(scores)
            for qid, scores in scores_by_question.items()
        }

        # Group by category
        category_scores = {}
        for question in PSYCHOLOGICAL_SAFETY_QUESTIONS:
            cat = question["category"]
            if cat not in category_scores:
                category_scores[cat] = []
            if question["id"] in question_averages:
                category_scores[cat].append(question_averages[question["id"]])

        category_averages = {
            cat: sum(scores) / len(scores) if scores else 0
            for cat, scores in category_scores.items()
        }

        # Overall score
        all_scores = [v for v in question_averages.values()]
        overall = sum(all_scores) / len(all_scores) if all_scores else 0

        return {
            "team": team,
            "overall_score": round(overall, 2),
            "category_scores": {k: round(v, 2) for k, v in category_averages.items()},
            "question_scores": {k: round(v, 2) for k, v in question_averages.items()},
            "response_count": len(set(r["respondent_id"] for r in responses)),
            "interpretation": self._interpret_score(overall)
        }

    def _interpret_score(self, score: float) -> Dict:
        """Provide interpretation of safety score."""
        if score >= 4.0:
            return {
                "level": "High Safety",
                "description": "Team members feel very safe to take interpersonal risks.",
                "recommendations": [
                    "Maintain current practices",
                    "Share learnings with other teams",
                    "Continue measuring to detect changes"
                ]
            }
        elif score >= 3.0:
            return {
                "level": "Moderate Safety",
                "description": "Generally safe environment with room for improvement.",
                "recommendations": [
                    "Discuss survey results openly",
                    "Identify specific areas for improvement",
                    "Implement targeted interventions"
                ]
            }
        else:
            return {
                "level": "Low Safety",
                "description": "Team members may hesitate to speak up or take risks.",
                "recommendations": [
                    "Prioritize leadership intervention",
                    "Consider team coaching",
                    "Address specific concerns immediately",
                    "Increase frequency of 1:1s"
                ]
            }

    async def get_trend(self, team: str, months: int = 12) -> List[Dict]:
        """Get psychological safety trend over time."""
        results = []
        for i in range(months):
            end_date = datetime.utcnow() - timedelta(days=i * 30)
            start_date = end_date - timedelta(days=30)

            responses = await self.db.safety_responses.find({
                "team": team,
                "timestamp": {"$gte": start_date, "$lt": end_date}
            }).to_list(1000)

            if responses:
                # Calculate score for this period
                scores = [r["score"] for r in responses]
                avg = sum(scores) / len(scores)
                results.append({
                    "period": start_date.strftime("%Y-%m"),
                    "score": round(avg, 2),
                    "response_count": len(set(r["respondent_id"] for r in responses))
                })

        return list(reversed(results))
```

## Part 4: Building a Learning Culture

### Exercise 4.1: Learning Time Framework

```yaml
# learning/framework.yaml
learning_time_policy:
  name: "20% Learning Time"
  description: |
    Engineers are encouraged to spend 20% of their time on learning
    and improvement activities. This time is protected and valued.

  eligible_activities:
    technical:
      - Online courses and certifications
      - Reading technical books and papers
      - Contributing to open source
      - Internal tech talks (giving and attending)
      - Experimentation and prototyping
      - Pair programming with other teams

    professional:
      - Leadership development
      - Communication skills
      - Project management
      - Mentoring and coaching

    community:
      - Writing blog posts
      - Conference speaking
      - Meetup organization
      - Knowledge base contributions

  guidelines:
    frequency: "Minimum 1 day per sprint"
    scheduling: "Coordinate with team to maintain coverage"
    tracking: "Log activities in learning tracker"
    sharing: "Share learnings in team or guild meetings"

  success_metrics:
    - Certifications obtained
    - Tech talks given
    - Blog posts published
    - Knowledge base articles written
    - Skills self-assessment improvement
    - Peer feedback on growth
```

### Exercise 4.2: Knowledge Sharing System

```typescript
// components/KnowledgeHub.tsx
import React, { useState, useEffect } from 'react';
import {
  Grid,
  Card,
  CardContent,
  Typography,
  Chip,
  Avatar,
  Button,
  TextField,
} from '@material-ui/core';
import { useApi } from '@backstage/core-plugin-api';
import { knowledgeApiRef } from '../api';

interface LearningShare {
  id: string;
  title: string;
  summary: string;
  author: {
    name: string;
    avatar: string;
    team: string;
  };
  type: 'article' | 'video' | 'talk' | 'course';
  tags: string[];
  likes: number;
  sharedAt: string;
  url?: string;
}

export const KnowledgeHub: React.FC = () => {
  const knowledgeApi = useApi(knowledgeApiRef);
  const [shares, setShares] = useState<LearningShare[]>([]);
  const [filter, setFilter] = useState('');
  const [selectedTag, setSelectedTag] = useState<string | null>(null);

  useEffect(() => {
    loadShares();
  }, []);

  const loadShares = async () => {
    const data = await knowledgeApi.getRecentShares({ limit: 50 });
    setShares(data);
  };

  const filteredShares = shares.filter(share => {
    const matchesSearch = share.title.toLowerCase().includes(filter.toLowerCase()) ||
                         share.summary.toLowerCase().includes(filter.toLowerCase());
    const matchesTag = !selectedTag || share.tags.includes(selectedTag);
    return matchesSearch && matchesTag;
  });

  const allTags = [...new Set(shares.flatMap(s => s.tags))];

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'article':
        return '📝';
      case 'video':
        return '🎥';
      case 'talk':
        return '🎤';
      case 'course':
        return '📚';
      default:
        return '📄';
    }
  };

  return (
    <div>
      <Typography variant="h4" gutterBottom>
        Knowledge Hub
      </Typography>
      <Typography variant="body1" paragraph>
        Share what you've learned. Discover what others are exploring.
      </Typography>

      {/* Filters */}
      <Grid container spacing={2} style={{ marginBottom: 24 }}>
        <Grid item xs={12} md={6}>
          <TextField
            fullWidth
            placeholder="Search knowledge shares..."
            value={filter}
            onChange={e => setFilter(e.target.value)}
            variant="outlined"
            size="small"
          />
        </Grid>
        <Grid item xs={12} md={6}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {allTags.slice(0, 10).map(tag => (
              <Chip
                key={tag}
                label={tag}
                onClick={() => setSelectedTag(selectedTag === tag ? null : tag)}
                color={selectedTag === tag ? 'primary' : 'default'}
                size="small"
              />
            ))}
          </div>
        </Grid>
      </Grid>

      {/* Share Button */}
      <Button
        variant="contained"
        color="primary"
        style={{ marginBottom: 24 }}
        onClick={() => {/* Open share dialog */}}
      >
        Share Something You Learned
      </Button>

      {/* Knowledge Shares Grid */}
      <Grid container spacing={3}>
        {filteredShares.map(share => (
          <Grid item xs={12} md={6} lg={4} key={share.id}>
            <Card>
              <CardContent>
                <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8 }}>
                  <span style={{ fontSize: 24, marginRight: 8 }}>
                    {getTypeIcon(share.type)}
                  </span>
                  <Typography variant="h6">
                    {share.title}
                  </Typography>
                </div>

                <Typography variant="body2" color="textSecondary" paragraph>
                  {share.summary}
                </Typography>

                <div style={{ display: 'flex', gap: 4, marginBottom: 12, flexWrap: 'wrap' }}>
                  {share.tags.map(tag => (
                    <Chip key={tag} label={tag} size="small" variant="outlined" />
                  ))}
                </div>

                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center' }}>
                    <Avatar src={share.author.avatar} style={{ width: 24, height: 24, marginRight: 8 }} />
                    <Typography variant="body2">
                      {share.author.name}
                    </Typography>
                  </div>
                  <Typography variant="caption" color="textSecondary">
                    ❤️ {share.likes}
                  </Typography>
                </div>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </div>
  );
};
```

## Verification Checklist

After completing this lab, verify:

- [ ] Team health survey is implemented and collecting data
- [ ] Health dashboard visualizes current status and trends
- [ ] Retrospective templates are available to teams
- [ ] Action items are tracked with owners and due dates
- [ ] Blameless postmortem template is in use
- [ ] Psychological safety is measured regularly
- [ ] Learning time policy is documented
- [ ] Knowledge sharing system is active

## Troubleshooting

### Low Survey Participation

1. Make surveys anonymous
2. Communicate value of feedback
3. Share how results drive change
4. Keep surveys short (5-10 minutes)

### Action Items Not Completing

1. Review prioritization
2. Ensure owners have capacity
3. Break down large items
4. Add to sprint planning

### Safety Scores Not Improving

1. Address specific low-scoring areas
2. Increase leadership involvement
3. Consider external facilitation
4. Be patient - culture changes slowly

## Summary

In this lab, you learned to:

- Implement team health assessments
- Run effective retrospectives
- Track improvement actions
- Foster psychological safety
- Build a learning culture
- Share knowledge across teams

Culture is the foundation of high-performing teams. Measuring and actively improving team health leads to better outcomes than focusing on technical excellence alone.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Team Health Assessment
- Retrospectives and Continuous Improvement
- Psychological Safety Practices
- Timeline

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
