# Lab 5: Platform Metrics and Developer Productivity

## Lab Overview

| Attribute | Details |
|-----------|---------|
| **Duration** | 3-4 hours |
| **Level** | Advanced |
| **Prerequisites** | Prometheus, Grafana, Platform fundamentals |
| **Environment** | Kubernetes cluster, Prometheus stack |
| **Learning Objectives** | Measure platform effectiveness, track DORA metrics, implement SPACE framework |

## Introduction

Effective platform engineering requires measuring impact on developer productivity and experience. This lab covers implementing comprehensive metrics to track platform adoption, developer satisfaction, and engineering efficiency using industry-standard frameworks.

## Part 1: DORA Metrics Implementation

### Understanding DORA Metrics

**The DORA metrics**

Four measures, two of throughput and two of stability. The pairing is the point:
optimising either half alone is easy and meaningless. Elite performers move fast
*and* break less, because the same practices — small batches, automated testing,
fast rollback — produce both.

| | Metric | What it asks | Elite | High | Medium | Low |
|---|---|---|---|---|---|---|
| **Throughput** | Deployment frequency | How often do you deploy to production? | Multiple per day | Weekly → monthly | Monthly → yearly | Less than once per 6 months |
| **Throughput** | Lead time for changes | How long from commit to running in production? | < 1 hour | 1 day → 1 week | 1 week → 1 month | > 1 month |
| **Stability** | Change failure rate | What share of deployments cause a degradation? | 0–15% | 16–30% | 31–45% | > 45% |
| **Stability** | Mean time to recovery | How long to restore service after a failure? | < 1 hour | < 1 day | 1 day → 1 week | > 1 week |

Measure them from systems you already have — deployment frequency and lead time
from your CI/CD events, change failure rate and MTTR from your incident tracker.
A DORA dashboard assembled by hand from a spreadsheet stops being updated in about
three weeks.

### Exercise 1.1: DORA Metrics Collector

```go
// cmd/dora-collector/main.go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"
)

// Metrics definitions
var (
	deploymentFrequency = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dora_deployments_total",
			Help: "Total number of deployments",
		},
		[]string{"team", "service", "environment", "status"},
	)

	leadTimeForChanges = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "dora_lead_time_seconds",
			Help:    "Lead time from commit to production deployment",
			Buckets: []float64{3600, 86400, 604800, 2592000}, // 1h, 1d, 1w, 1m
		},
		[]string{"team", "service"},
	)

	changeFailureRate = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "dora_change_failure_rate",
			Help: "Percentage of deployments causing failures",
		},
		[]string{"team", "service"},
	)

	meanTimeToRecovery = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "dora_mttr_seconds",
			Help:    "Mean time to recovery from failures",
			Buckets: []float64{300, 3600, 86400, 604800}, // 5m, 1h, 1d, 1w
		},
		[]string{"team", "service"},
	)

	deploymentDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "dora_deployment_duration_seconds",
			Help:    "Duration of deployment process",
			Buckets: []float64{60, 300, 600, 1800, 3600},
		},
		[]string{"team", "service", "environment"},
	)
)

func init() {
	prometheus.MustRegister(deploymentFrequency)
	prometheus.MustRegister(leadTimeForChanges)
	prometheus.MustRegister(changeFailureRate)
	prometheus.MustRegister(meanTimeToRecovery)
	prometheus.MustRegister(deploymentDuration)
}

// DeploymentEvent represents a deployment webhook payload
type DeploymentEvent struct {
	ID          string    `json:"id"`
	Team        string    `json:"team"`
	Service     string    `json:"service"`
	Environment string    `json:"environment"`
	Status      string    `json:"status"` // success, failure, rollback
	CommitSHA   string    `json:"commit_sha"`
	CommitTime  time.Time `json:"commit_time"`
	DeployTime  time.Time `json:"deploy_time"`
	Duration    float64   `json:"duration_seconds"`
}

// IncidentEvent represents an incident for MTTR tracking
type IncidentEvent struct {
	ID           string    `json:"id"`
	Team         string    `json:"team"`
	Service      string    `json:"service"`
	Severity     string    `json:"severity"`
	StartTime    time.Time `json:"start_time"`
	ResolvedTime time.Time `json:"resolved_time"`
	DeploymentID string    `json:"deployment_id,omitempty"`
}

type DORACollector struct {
	logger *zap.Logger
	store  MetricsStore
}

type MetricsStore interface {
	SaveDeployment(ctx context.Context, event DeploymentEvent) error
	SaveIncident(ctx context.Context, event IncidentEvent) error
	GetDeploymentsInRange(ctx context.Context, start, end time.Time) ([]DeploymentEvent, error)
	GetIncidentsInRange(ctx context.Context, start, end time.Time) ([]IncidentEvent, error)
}

func NewDORACollector(logger *zap.Logger, store MetricsStore) *DORACollector {
	return &DORACollector{
		logger: logger,
		store:  store,
	}
}

func (c *DORACollector) HandleDeployment(w http.ResponseWriter, r *http.Request) {
	var event DeploymentEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Record deployment
	deploymentFrequency.WithLabelValues(
		event.Team,
		event.Service,
		event.Environment,
		event.Status,
	).Inc()

	// Record lead time (only for production deployments)
	if event.Environment == "production" && event.Status == "success" {
		leadTime := event.DeployTime.Sub(event.CommitTime).Seconds()
		leadTimeForChanges.WithLabelValues(
			event.Team,
			event.Service,
		).Observe(leadTime)
	}

	// Record deployment duration
	deploymentDuration.WithLabelValues(
		event.Team,
		event.Service,
		event.Environment,
	).Observe(event.Duration)

	// Save to store for aggregation
	if err := c.store.SaveDeployment(r.Context(), event); err != nil {
		c.logger.Error("failed to save deployment", zap.Error(err))
	}

	c.logger.Info("deployment recorded",
		zap.String("team", event.Team),
		zap.String("service", event.Service),
		zap.String("status", event.Status),
	)

	w.WriteHeader(http.StatusAccepted)
}

func (c *DORACollector) HandleIncident(w http.ResponseWriter, r *http.Request) {
	var event IncidentEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Calculate MTTR
	mttr := event.ResolvedTime.Sub(event.StartTime).Seconds()
	meanTimeToRecovery.WithLabelValues(
		event.Team,
		event.Service,
	).Observe(mttr)

	// Save for CFR calculation
	if err := c.store.SaveIncident(r.Context(), event); err != nil {
		c.logger.Error("failed to save incident", zap.Error(err))
	}

	c.logger.Info("incident recorded",
		zap.String("team", event.Team),
		zap.String("service", event.Service),
		zap.Duration("mttr", time.Duration(mttr)*time.Second),
	)

	w.WriteHeader(http.StatusAccepted)
}

// CalculateChangeFailureRate computes CFR for all teams/services
func (c *DORACollector) CalculateChangeFailureRate(ctx context.Context) error {
	end := time.Now()
	start := end.AddDate(0, 0, -30) // Last 30 days

	deployments, err := c.store.GetDeploymentsInRange(ctx, start, end)
	if err != nil {
		return err
	}

	incidents, err := c.store.GetIncidentsInRange(ctx, start, end)
	if err != nil {
		return err
	}

	// Group by team/service
	type key struct{ team, service string }
	deployCounts := make(map[key]int)
	failureCounts := make(map[key]int)

	for _, d := range deployments {
		if d.Environment == "production" {
			k := key{d.Team, d.Service}
			deployCounts[k]++
		}
	}

	// Count deployment-related incidents
	for _, i := range incidents {
		if i.DeploymentID != "" {
			k := key{i.Team, i.Service}
			failureCounts[k]++
		}
	}

	// Update metrics
	for k, total := range deployCounts {
		failures := failureCounts[k]
		rate := float64(failures) / float64(total)
		changeFailureRate.WithLabelValues(k.team, k.service).Set(rate)
	}

	return nil
}

func main() {
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	// Initialize store (PostgreSQL, etc.)
	store := NewPostgresStore(/* connection config */)

	collector := NewDORACollector(logger, store)

	// Start background CFR calculation
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		for range ticker.C {
			if err := collector.CalculateChangeFailureRate(context.Background()); err != nil {
				logger.Error("failed to calculate CFR", zap.Error(err))
			}
		}
	}()

	http.HandleFunc("/webhook/deployment", collector.HandleDeployment)
	http.HandleFunc("/webhook/incident", collector.HandleIncident)
	http.Handle("/metrics", promhttp.Handler())

	logger.Info("starting DORA metrics collector", zap.Int("port", 8080))
	http.ListenAndServe(":8080", nil)
}
```

### Exercise 1.2: DORA Metrics Dashboard

```yaml
# grafana/dashboards/dora-metrics.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dora-metrics-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dora-metrics.json: |
    {
      "title": "DORA Metrics Dashboard",
      "uid": "dora-metrics",
      "tags": ["dora", "devops", "platform"],
      "timezone": "browser",
      "refresh": "5m",
      "panels": [
        {
          "title": "DORA Performance Summary",
          "type": "stat",
          "gridPos": {"x": 0, "y": 0, "w": 24, "h": 4},
          "targets": [
            {
              "expr": "sum(increase(dora_deployments_total{environment=\"production\",status=\"success\"}[7d]))",
              "legendFormat": "Deployments (7d)"
            },
            {
              "expr": "histogram_quantile(0.50, sum(rate(dora_lead_time_seconds_bucket[7d])) by (le)) / 3600",
              "legendFormat": "Lead Time (hours)"
            },
            {
              "expr": "avg(dora_change_failure_rate) * 100",
              "legendFormat": "Change Failure Rate (%)"
            },
            {
              "expr": "histogram_quantile(0.50, sum(rate(dora_mttr_seconds_bucket[30d])) by (le)) / 3600",
              "legendFormat": "MTTR (hours)"
            }
          ],
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "orientation": "horizontal"
          }
        },
        {
          "title": "Deployment Frequency by Team",
          "type": "timeseries",
          "gridPos": {"x": 0, "y": 4, "w": 12, "h": 8},
          "targets": [
            {
              "expr": "sum by (team) (increase(dora_deployments_total{environment=\"production\",status=\"success\"}[1d]))",
              "legendFormat": "{{team}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "short",
              "custom": {
                "drawStyle": "bars",
                "barAlignment": 0
              }
            }
          }
        },
        {
          "title": "Lead Time for Changes (p50)",
          "type": "timeseries",
          "gridPos": {"x": 12, "y": 4, "w": 12, "h": 8},
          "targets": [
            {
              "expr": "histogram_quantile(0.50, sum by (team, le) (rate(dora_lead_time_seconds_bucket[1d]))) / 3600",
              "legendFormat": "{{team}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "h",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": 0, "color": "green"},
                  {"value": 24, "color": "yellow"},
                  {"value": 168, "color": "orange"},
                  {"value": 720, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "title": "Change Failure Rate",
          "type": "gauge",
          "gridPos": {"x": 0, "y": 12, "w": 8, "h": 6},
          "targets": [
            {
              "expr": "avg(dora_change_failure_rate) * 100",
              "legendFormat": "CFR %"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percent",
              "min": 0,
              "max": 100,
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": 0, "color": "green"},
                  {"value": 15, "color": "yellow"},
                  {"value": 30, "color": "orange"},
                  {"value": 45, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "title": "Mean Time to Recovery",
          "type": "gauge",
          "gridPos": {"x": 8, "y": 12, "w": 8, "h": 6},
          "targets": [
            {
              "expr": "histogram_quantile(0.50, sum(rate(dora_mttr_seconds_bucket[30d])) by (le)) / 3600",
              "legendFormat": "MTTR (hours)"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "h",
              "min": 0,
              "max": 168,
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"value": 0, "color": "green"},
                  {"value": 1, "color": "yellow"},
                  {"value": 24, "color": "orange"},
                  {"value": 168, "color": "red"}
                ]
              }
            }
          }
        },
        {
          "title": "DORA Performance Level",
          "type": "table",
          "gridPos": {"x": 16, "y": 12, "w": 8, "h": 6},
          "targets": [
            {
              "expr": "topk(10, sum by (team) (increase(dora_deployments_total{environment=\"production\"}[30d])))",
              "format": "table",
              "instant": true
            }
          ],
          "transformations": [
            {
              "id": "organize",
              "options": {
                "renameByName": {
                  "team": "Team",
                  "Value": "Deployments (30d)"
                }
              }
            }
          ]
        }
      ]
    }
```

## Part 2: SPACE Framework Implementation

### Understanding SPACE

**SPACE Framework**

**S - Satisfaction and Well-being**

  - Developer satisfaction surveys
  - Burnout indicators
  - Team health metrics

**P - Performance**

  - Code quality metrics
  - Reliability (uptime, error rates)
  - Customer satisfaction

**A - Activity**

  - Commits, PRs, code reviews
  - Deployments
  - Documentation updates

**C - Communication and Collaboration**

  - PR review turnaround
  - Knowledge sharing
  - Meeting efficiency

**E - Efficiency and Flow**

  - Cycle time
  - Context switching
  - Time in meetings vs focus time


### Exercise 2.1: Developer Productivity Metrics

```python
# space_metrics/collector.py
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import asyncio
from prometheus_client import Counter, Histogram, Gauge, Summary
import aiohttp

# Prometheus metrics
pr_cycle_time = Histogram(
    'space_pr_cycle_time_hours',
    'Pull request cycle time in hours',
    ['team', 'repo'],
    buckets=[1, 4, 8, 24, 48, 72, 168]
)

pr_review_time = Histogram(
    'space_pr_review_time_hours',
    'Time to first review in hours',
    ['team', 'repo'],
    buckets=[0.5, 1, 2, 4, 8, 24, 48]
)

pr_merge_rate = Gauge(
    'space_pr_merge_rate',
    'Percentage of PRs merged without changes',
    ['team', 'repo']
)

code_review_coverage = Gauge(
    'space_code_review_coverage',
    'Percentage of code changes reviewed',
    ['team', 'repo']
)

developer_satisfaction = Gauge(
    'space_developer_satisfaction',
    'Developer satisfaction score (1-10)',
    ['team', 'dimension']
)

focus_time_ratio = Gauge(
    'space_focus_time_ratio',
    'Ratio of focus time to total work time',
    ['team']
)

knowledge_sharing_score = Gauge(
    'space_knowledge_sharing_score',
    'Knowledge sharing activity score',
    ['team']
)


@dataclass
class PRMetrics:
    repo: str
    team: str
    created_at: datetime
    first_review_at: Optional[datetime]
    merged_at: Optional[datetime]
    closed_at: Optional[datetime]
    review_comments: int
    change_requests: int
    additions: int
    deletions: int


class SPACEMetricsCollector:
    def __init__(self, github_token: str, survey_api: str):
        self.github_token = github_token
        self.survey_api = survey_api
        self.session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            headers={"Authorization": f"Bearer {self.github_token}"}
        )
        return self

    async def __aexit__(self, *args):
        if self.session:
            await self.session.close()

    async def collect_github_metrics(self, org: str, repos: List[str]):
        """Collect PR and activity metrics from GitHub."""
        for repo in repos:
            prs = await self._fetch_prs(org, repo)
            team = await self._get_team_for_repo(org, repo)

            for pr in prs:
                metrics = self._calculate_pr_metrics(pr, repo, team)
                self._record_pr_metrics(metrics)

    async def _fetch_prs(self, org: str, repo: str, days: int = 30) -> List[dict]:
        """Fetch PRs from GitHub GraphQL API."""
        query = """
        query($org: String!, $repo: String!, $since: DateTime!) {
          repository(owner: $org, name: $repo) {
            pullRequests(first: 100, orderBy: {field: CREATED_AT, direction: DESC}) {
              nodes {
                number
                createdAt
                mergedAt
                closedAt
                additions
                deletions
                reviews(first: 10) {
                  nodes {
                    createdAt
                    state
                  }
                }
                comments {
                  totalCount
                }
              }
            }
          }
        }
        """

        since = (datetime.utcnow() - timedelta(days=days)).isoformat()
        variables = {"org": org, "repo": repo, "since": since}

        async with self.session.post(
            "https://api.github.com/graphql",
            json={"query": query, "variables": variables}
        ) as response:
            data = await response.json()
            return data["data"]["repository"]["pullRequests"]["nodes"]

    def _calculate_pr_metrics(self, pr: dict, repo: str, team: str) -> PRMetrics:
        """Calculate metrics for a single PR."""
        created_at = datetime.fromisoformat(pr["createdAt"].replace("Z", "+00:00"))

        first_review_at = None
        change_requests = 0
        if pr["reviews"]["nodes"]:
            first_review = pr["reviews"]["nodes"][0]
            first_review_at = datetime.fromisoformat(
                first_review["createdAt"].replace("Z", "+00:00")
            )
            change_requests = sum(
                1 for r in pr["reviews"]["nodes"]
                if r["state"] == "CHANGES_REQUESTED"
            )

        merged_at = None
        if pr["mergedAt"]:
            merged_at = datetime.fromisoformat(pr["mergedAt"].replace("Z", "+00:00"))

        closed_at = None
        if pr["closedAt"]:
            closed_at = datetime.fromisoformat(pr["closedAt"].replace("Z", "+00:00"))

        return PRMetrics(
            repo=repo,
            team=team,
            created_at=created_at,
            first_review_at=first_review_at,
            merged_at=merged_at,
            closed_at=closed_at,
            review_comments=pr["comments"]["totalCount"],
            change_requests=change_requests,
            additions=pr["additions"],
            deletions=pr["deletions"]
        )

    def _record_pr_metrics(self, metrics: PRMetrics):
        """Record PR metrics to Prometheus."""
        # Cycle time (creation to merge)
        if metrics.merged_at:
            cycle_hours = (metrics.merged_at - metrics.created_at).total_seconds() / 3600
            pr_cycle_time.labels(
                team=metrics.team,
                repo=metrics.repo
            ).observe(cycle_hours)

        # Time to first review
        if metrics.first_review_at:
            review_hours = (metrics.first_review_at - metrics.created_at).total_seconds() / 3600
            pr_review_time.labels(
                team=metrics.team,
                repo=metrics.repo
            ).observe(review_hours)

    async def collect_survey_metrics(self):
        """Collect developer satisfaction from surveys."""
        async with self.session.get(f"{self.survey_api}/latest") as response:
            surveys = await response.json()

        for survey in surveys:
            team = survey["team"]

            # Record satisfaction dimensions
            for dimension, score in survey["scores"].items():
                developer_satisfaction.labels(
                    team=team,
                    dimension=dimension
                ).set(score)

    async def collect_calendar_metrics(self, teams: List[str]):
        """Analyze calendar data for focus time metrics."""
        # This would integrate with Google Calendar, Outlook, etc.
        for team in teams:
            # Calculate focus time ratio
            focus_hours, meeting_hours = await self._analyze_team_calendar(team)
            total_hours = focus_hours + meeting_hours
            if total_hours > 0:
                ratio = focus_hours / total_hours
                focus_time_ratio.labels(team=team).set(ratio)

    async def calculate_knowledge_sharing(self, org: str):
        """Calculate knowledge sharing scores."""
        # Factors: documentation updates, code review participation,
        # tech talks, mentoring sessions
        teams = await self._get_all_teams(org)

        for team in teams:
            score = await self._calculate_team_knowledge_score(team)
            knowledge_sharing_score.labels(team=team).set(score)


class SPACEReportGenerator:
    """Generate SPACE framework reports."""

    def __init__(self, prometheus_url: str):
        self.prometheus_url = prometheus_url

    async def generate_team_report(self, team: str, period_days: int = 30) -> dict:
        """Generate comprehensive SPACE report for a team."""
        return {
            "team": team,
            "period": f"{period_days} days",
            "generated_at": datetime.utcnow().isoformat(),
            "satisfaction": await self._get_satisfaction_metrics(team),
            "performance": await self._get_performance_metrics(team),
            "activity": await self._get_activity_metrics(team),
            "communication": await self._get_communication_metrics(team),
            "efficiency": await self._get_efficiency_metrics(team),
            "recommendations": self._generate_recommendations(team)
        }

    async def _get_satisfaction_metrics(self, team: str) -> dict:
        """Get satisfaction and well-being metrics."""
        return {
            "overall_satisfaction": await self._query_prometheus(
                f'avg(space_developer_satisfaction{{team="{team}"}})'
            ),
            "by_dimension": {
                "tooling": await self._query_prometheus(
                    f'space_developer_satisfaction{{team="{team}",dimension="tooling"}}'
                ),
                "work_life_balance": await self._query_prometheus(
                    f'space_developer_satisfaction{{team="{team}",dimension="work_life_balance"}}'
                ),
                "team_culture": await self._query_prometheus(
                    f'space_developer_satisfaction{{team="{team}",dimension="team_culture"}}'
                ),
                "growth_opportunities": await self._query_prometheus(
                    f'space_developer_satisfaction{{team="{team}",dimension="growth"}}'
                )
            }
        }

    async def _get_performance_metrics(self, team: str) -> dict:
        """Get performance metrics."""
        return {
            "deployment_success_rate": await self._query_prometheus(
                f'sum(dora_deployments_total{{team="{team}",status="success"}}) / '
                f'sum(dora_deployments_total{{team="{team}"}})'
            ),
            "service_reliability": await self._query_prometheus(
                f'avg(up{{team="{team}"}})'
            ),
            "p99_latency_ms": await self._query_prometheus(
                f'histogram_quantile(0.99, http_request_duration_seconds_bucket{{team="{team}"}})'
            )
        }

    async def _get_activity_metrics(self, team: str) -> dict:
        """Get activity metrics."""
        return {
            "prs_merged_per_week": await self._query_prometheus(
                f'sum(increase(github_prs_merged_total{{team="{team}"}}[7d]))'
            ),
            "commits_per_week": await self._query_prometheus(
                f'sum(increase(github_commits_total{{team="{team}"}}[7d]))'
            ),
            "deployments_per_week": await self._query_prometheus(
                f'sum(increase(dora_deployments_total{{team="{team}"}}[7d]))'
            )
        }

    async def _get_communication_metrics(self, team: str) -> dict:
        """Get communication and collaboration metrics."""
        return {
            "avg_pr_review_time_hours": await self._query_prometheus(
                f'histogram_quantile(0.50, space_pr_review_time_hours_bucket{{team="{team}"}})'
            ),
            "code_review_participation": await self._query_prometheus(
                f'space_code_review_coverage{{team="{team}"}}'
            ),
            "knowledge_sharing_score": await self._query_prometheus(
                f'space_knowledge_sharing_score{{team="{team}"}}'
            )
        }

    async def _get_efficiency_metrics(self, team: str) -> dict:
        """Get efficiency and flow metrics."""
        return {
            "pr_cycle_time_hours": await self._query_prometheus(
                f'histogram_quantile(0.50, space_pr_cycle_time_hours_bucket{{team="{team}"}})'
            ),
            "focus_time_ratio": await self._query_prometheus(
                f'space_focus_time_ratio{{team="{team}"}}'
            ),
            "lead_time_hours": await self._query_prometheus(
                f'histogram_quantile(0.50, dora_lead_time_seconds_bucket{{team="{team}"}}) / 3600'
            )
        }

    def _generate_recommendations(self, team: str) -> List[str]:
        """Generate actionable recommendations based on metrics."""
        recommendations = []

        # This would analyze the metrics and generate specific recommendations
        # Example logic:
        # if pr_review_time > 24:
        #     recommendations.append("Consider implementing review SLOs")
        # if focus_time_ratio < 0.5:
        #     recommendations.append("Review meeting load")

        return recommendations
```

## Part 3: Platform Adoption Metrics

### Exercise 3.1: Platform Usage Tracking

```yaml
# platform-metrics/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: platform-adoption-rules
  namespace: monitoring
spec:
  groups:
    - name: platform.adoption
      interval: 5m
      rules:
        # Template usage
        - record: platform:template_usage:total
          expr: sum by (template) (increase(backstage_scaffolder_tasks_total[30d]))

        - record: platform:template_adoption:rate
          expr: |
            sum(increase(backstage_scaffolder_tasks_total{status="completed"}[30d])) /
            sum(increase(backstage_scaffolder_tasks_total[30d]))

        # Self-service infrastructure
        - record: platform:self_service:requests
          expr: sum by (resource_type) (increase(crossplane_claims_created_total[30d]))

        - record: platform:self_service:success_rate
          expr: |
            sum(crossplane_claims_status{status="Ready"}) /
            sum(crossplane_claims_status)

        # Developer portal engagement
        - record: platform:portal:daily_active_users
          expr: count(count by (user) (backstage_request_total[24h]))

        - record: platform:portal:feature_usage
          expr: sum by (feature) (increase(backstage_feature_usage_total[7d]))

        # Golden path compliance
        - record: platform:golden_path:compliance
          expr: |
            sum(kube_deployment_labels{label_golden_path="true"}) /
            sum(kube_deployment_labels)

    - name: platform.alerts
      rules:
        - alert: LowPlatformAdoption
          expr: platform:template_adoption:rate < 0.5
          for: 7d
          labels:
            severity: warning
          annotations:
            summary: "Low platform template adoption"
            description: "Only {{ $value | humanizePercentage }} of template tasks are completing successfully"

        - alert: SelfServiceFailures
          expr: platform:self_service:success_rate < 0.9
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "High self-service infrastructure failure rate"
            description: "Self-service success rate is {{ $value | humanizePercentage }}"
```

### Exercise 3.2: Developer Experience Survey System

```python
# devex_survey/app.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime
from enum import Enum
import asyncpg
from prometheus_client import Gauge, generate_latest

app = FastAPI(title="Developer Experience Survey API")

# Prometheus metrics
nps_score = Gauge(
    'devex_nps_score',
    'Net Promoter Score for developer experience',
    ['team', 'category']
)

survey_response_rate = Gauge(
    'devex_survey_response_rate',
    'Survey response rate by team',
    ['team']
)


class SurveyCategory(str, Enum):
    PLATFORM_TOOLS = "platform_tools"
    CI_CD = "ci_cd"
    DOCUMENTATION = "documentation"
    ONBOARDING = "onboarding"
    SUPPORT = "support"
    OVERALL = "overall"


class SurveyQuestion(BaseModel):
    id: str
    category: SurveyCategory
    question: str
    question_type: str  # nps, rating, text
    required: bool = True


class SurveyResponse(BaseModel):
    respondent_id: str
    team: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    responses: Dict[str, int | str]
    feedback: Optional[str] = None


class SurveyTemplate(BaseModel):
    id: str
    name: str
    description: str
    questions: List[SurveyQuestion]
    frequency: str  # weekly, monthly, quarterly


# Standard DevEx survey questions
DEVEX_SURVEY = SurveyTemplate(
    id="devex-standard",
    name="Developer Experience Survey",
    description="Quarterly developer experience assessment",
    frequency="quarterly",
    questions=[
        # Platform Tools
        SurveyQuestion(
            id="platform_nps",
            category=SurveyCategory.PLATFORM_TOOLS,
            question="How likely are you to recommend our internal platform to another developer? (0-10)",
            question_type="nps"
        ),
        SurveyQuestion(
            id="platform_ease",
            category=SurveyCategory.PLATFORM_TOOLS,
            question="How easy is it to deploy a new service? (1-5)",
            question_type="rating"
        ),
        SurveyQuestion(
            id="platform_reliability",
            category=SurveyCategory.PLATFORM_TOOLS,
            question="How reliable is the platform infrastructure? (1-5)",
            question_type="rating"
        ),

        # CI/CD
        SurveyQuestion(
            id="cicd_speed",
            category=SurveyCategory.CI_CD,
            question="How satisfied are you with CI/CD pipeline speed? (1-5)",
            question_type="rating"
        ),
        SurveyQuestion(
            id="cicd_reliability",
            category=SurveyCategory.CI_CD,
            question="How often do CI/CD pipelines fail unexpectedly? (1-5, 5=rarely)",
            question_type="rating"
        ),

        # Documentation
        SurveyQuestion(
            id="docs_findability",
            category=SurveyCategory.DOCUMENTATION,
            question="How easy is it to find the documentation you need? (1-5)",
            question_type="rating"
        ),
        SurveyQuestion(
            id="docs_quality",
            category=SurveyCategory.DOCUMENTATION,
            question="How helpful is our technical documentation? (1-5)",
            question_type="rating"
        ),

        # Onboarding
        SurveyQuestion(
            id="onboarding_effectiveness",
            category=SurveyCategory.ONBOARDING,
            question="How effective was your onboarding experience? (1-5)",
            question_type="rating"
        ),

        # Support
        SurveyQuestion(
            id="support_responsiveness",
            category=SurveyCategory.SUPPORT,
            question="How responsive is the platform team to requests? (1-5)",
            question_type="rating"
        ),
        SurveyQuestion(
            id="support_quality",
            category=SurveyCategory.SUPPORT,
            question="How satisfied are you with support quality? (1-5)",
            question_type="rating"
        ),

        # Overall
        SurveyQuestion(
            id="overall_nps",
            category=SurveyCategory.OVERALL,
            question="Overall, how satisfied are you with developer experience at our company? (0-10)",
            question_type="nps"
        ),
        SurveyQuestion(
            id="feedback",
            category=SurveyCategory.OVERALL,
            question="What's the biggest improvement you'd like to see?",
            question_type="text",
            required=False
        )
    ]
)


class SurveyService:
    def __init__(self, db_pool: asyncpg.Pool):
        self.db = db_pool

    async def submit_response(self, response: SurveyResponse):
        """Submit a survey response and update metrics."""
        # Store response
        await self.db.execute("""
            INSERT INTO survey_responses (respondent_id, team, timestamp, responses, feedback)
            VALUES ($1, $2, $3, $4, $5)
        """, response.respondent_id, response.team, response.timestamp,
            response.responses, response.feedback)

        # Update metrics
        await self._update_metrics(response)

    async def _update_metrics(self, response: SurveyResponse):
        """Update Prometheus metrics based on response."""
        # Calculate NPS
        for question_id, value in response.responses.items():
            question = next(
                (q for q in DEVEX_SURVEY.questions if q.id == question_id),
                None
            )
            if question and question.question_type == "nps":
                # Get all NPS responses for this category and team
                nps = await self._calculate_nps(response.team, question.category)
                nps_score.labels(
                    team=response.team,
                    category=question.category.value
                ).set(nps)

    async def _calculate_nps(self, team: str, category: SurveyCategory) -> float:
        """Calculate Net Promoter Score."""
        responses = await self.db.fetch("""
            SELECT responses
            FROM survey_responses
            WHERE team = $1
            AND timestamp > NOW() - INTERVAL '90 days'
        """, team)

        if not responses:
            return 0

        scores = []
        for r in responses:
            for q in DEVEX_SURVEY.questions:
                if q.category == category and q.question_type == "nps":
                    if q.id in r['responses']:
                        scores.append(r['responses'][q.id])

        if not scores:
            return 0

        promoters = sum(1 for s in scores if s >= 9)
        detractors = sum(1 for s in scores if s <= 6)
        total = len(scores)

        return ((promoters - detractors) / total) * 100

    async def get_team_summary(self, team: str) -> dict:
        """Get survey summary for a team."""
        return await self.db.fetchrow("""
            WITH recent_responses AS (
                SELECT responses, timestamp
                FROM survey_responses
                WHERE team = $1
                AND timestamp > NOW() - INTERVAL '90 days'
            )
            SELECT
                COUNT(*) as response_count,
                AVG((responses->>'overall_nps')::int) as avg_nps,
                AVG((responses->>'platform_ease')::int) as avg_platform_ease,
                AVG((responses->>'cicd_speed')::int) as avg_cicd_speed,
                AVG((responses->>'docs_quality')::int) as avg_docs_quality,
                AVG((responses->>'support_quality')::int) as avg_support_quality
            FROM recent_responses
        """, team)


@app.get("/surveys/template")
async def get_survey_template():
    """Get the current survey template."""
    return DEVEX_SURVEY


@app.post("/surveys/responses")
async def submit_survey(response: SurveyResponse, service: SurveyService):
    """Submit a survey response."""
    await service.submit_response(response)
    return {"status": "submitted"}


@app.get("/surveys/summary/{team}")
async def get_team_summary(team: str, service: SurveyService):
    """Get survey summary for a team."""
    return await service.get_team_summary(team)


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest()
```

## Part 4: Platform Value Metrics

### Exercise 4.1: Cost and Efficiency Tracking

```yaml
# grafana/dashboards/platform-value.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-value-dashboard
  namespace: monitoring
data:
  platform-value.json: |
    {
      "title": "Platform Value Dashboard",
      "panels": [
        {
          "title": "Developer Time Saved",
          "type": "stat",
          "targets": [
            {
              "expr": "sum(platform:time_saved_hours:total)",
              "legendFormat": "Hours Saved (30d)"
            }
          ],
          "description": "Estimated developer hours saved through platform automation"
        },
        {
          "title": "Self-Service vs Manual Requests",
          "type": "piechart",
          "targets": [
            {
              "expr": "sum(platform:self_service:requests)",
              "legendFormat": "Self-Service"
            },
            {
              "expr": "sum(platform:manual:requests)",
              "legendFormat": "Manual"
            }
          ]
        },
        {
          "title": "Cost per Deployment",
          "type": "timeseries",
          "targets": [
            {
              "expr": "sum(platform:infrastructure_cost:total) / sum(increase(dora_deployments_total[30d]))",
              "legendFormat": "Cost per Deploy"
            }
          ]
        },
        {
          "title": "New Service Time to Production",
          "type": "gauge",
          "targets": [
            {
              "expr": "histogram_quantile(0.50, platform:new_service_time_to_production_hours_bucket)",
              "legendFormat": "Median Hours"
            }
          ],
          "fieldConfig": {
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 4, "color": "yellow"},
                {"value": 24, "color": "red"}
              ]
            }
          }
        },
        {
          "title": "Platform ROI",
          "type": "stat",
          "targets": [
            {
              "expr": "(platform:value_delivered:total - platform:cost:total) / platform:cost:total * 100",
              "legendFormat": "ROI %"
            }
          ]
        }
      ]
    }
```

### Exercise 4.2: Value Stream Mapping

```go
// valuestream/mapper.go
package valuestream

import (
	"context"
	"time"
)

// Stage represents a stage in the value stream
type Stage struct {
	Name           string        `json:"name"`
	StartTime      time.Time     `json:"start_time"`
	EndTime        time.Time     `json:"end_time"`
	Duration       time.Duration `json:"duration"`
	WaitTime       time.Duration `json:"wait_time"`
	ProcessTime    time.Duration `json:"process_time"`
	PercentComplete float64      `json:"percent_complete"`
}

// ValueStream represents a complete value stream
type ValueStream struct {
	ID           string        `json:"id"`
	Type         string        `json:"type"` // feature, bugfix, etc.
	Team         string        `json:"team"`
	Service      string        `json:"service"`
	StartTime    time.Time     `json:"start_time"`
	EndTime      time.Time     `json:"end_time"`
	TotalLeadTime time.Duration `json:"total_lead_time"`
	Stages       []Stage       `json:"stages"`
	Efficiency   float64       `json:"efficiency"` // process_time / total_time
}

// ValueStreamMapper tracks and maps value streams
type ValueStreamMapper struct {
	store ValueStreamStore
}

// StandardStages defines the typical value stream stages
var StandardStages = []string{
	"idea",           // Idea proposed
	"planning",       // Work planned/refined
	"development",    // Code being written
	"code_review",    // PR under review
	"ci_pipeline",    // CI/CD running
	"staging",        // In staging environment
	"production",     // Deployed to production
	"monitoring",     // Being monitored for issues
}

func NewValueStreamMapper(store ValueStreamStore) *ValueStreamMapper {
	return &ValueStreamMapper{store: store}
}

// RecordStageTransition records a stage transition
func (m *ValueStreamMapper) RecordStageTransition(ctx context.Context, streamID, stage string, timestamp time.Time) error {
	stream, err := m.store.Get(ctx, streamID)
	if err != nil {
		return err
	}

	// Find or create stage
	stageIdx := -1
	for i, s := range stream.Stages {
		if s.Name == stage {
			stageIdx = i
			break
		}
	}

	if stageIdx == -1 {
		// New stage
		newStage := Stage{
			Name:      stage,
			StartTime: timestamp,
		}
		stream.Stages = append(stream.Stages, newStage)
	} else {
		// Update existing stage
		stream.Stages[stageIdx].EndTime = timestamp
		stream.Stages[stageIdx].Duration = timestamp.Sub(stream.Stages[stageIdx].StartTime)
	}

	// Calculate wait times
	for i := 1; i < len(stream.Stages); i++ {
		if !stream.Stages[i-1].EndTime.IsZero() && !stream.Stages[i].StartTime.IsZero() {
			stream.Stages[i].WaitTime = stream.Stages[i].StartTime.Sub(stream.Stages[i-1].EndTime)
		}
	}

	// Calculate efficiency
	var totalProcessTime, totalWaitTime time.Duration
	for _, s := range stream.Stages {
		totalProcessTime += s.ProcessTime
		totalWaitTime += s.WaitTime
	}
	if totalProcessTime+totalWaitTime > 0 {
		stream.Efficiency = float64(totalProcessTime) / float64(totalProcessTime+totalWaitTime)
	}

	return m.store.Save(ctx, stream)
}

// AnalyzeValueStream provides insights on a value stream
func (m *ValueStreamMapper) AnalyzeValueStream(ctx context.Context, streamID string) (*ValueStreamAnalysis, error) {
	stream, err := m.store.Get(ctx, streamID)
	if err != nil {
		return nil, err
	}

	analysis := &ValueStreamAnalysis{
		StreamID:    streamID,
		TotalTime:   stream.TotalLeadTime,
		Efficiency:  stream.Efficiency,
		Bottlenecks: make([]Bottleneck, 0),
	}

	// Identify bottlenecks
	for _, stage := range stream.Stages {
		if stage.WaitTime > time.Hour {
			analysis.Bottlenecks = append(analysis.Bottlenecks, Bottleneck{
				Stage:    stage.Name,
				WaitTime: stage.WaitTime,
				Impact:   "High",
				Suggestion: getBottleneckSuggestion(stage.Name),
			})
		}
	}

	return analysis, nil
}

// GetTeamValueStreamMetrics aggregates metrics for a team
func (m *ValueStreamMapper) GetTeamValueStreamMetrics(ctx context.Context, team string, period time.Duration) (*TeamMetrics, error) {
	streams, err := m.store.GetByTeam(ctx, team, period)
	if err != nil {
		return nil, err
	}

	metrics := &TeamMetrics{
		Team:   team,
		Period: period,
	}

	if len(streams) == 0 {
		return metrics, nil
	}

	var totalLeadTime time.Duration
	var totalEfficiency float64
	stageMetrics := make(map[string]*StageMetrics)

	for _, stream := range streams {
		totalLeadTime += stream.TotalLeadTime
		totalEfficiency += stream.Efficiency

		for _, stage := range stream.Stages {
			if _, ok := stageMetrics[stage.Name]; !ok {
				stageMetrics[stage.Name] = &StageMetrics{Name: stage.Name}
			}
			stageMetrics[stage.Name].TotalDuration += stage.Duration
			stageMetrics[stage.Name].TotalWaitTime += stage.WaitTime
			stageMetrics[stage.Name].Count++
		}
	}

	metrics.AverageLeadTime = totalLeadTime / time.Duration(len(streams))
	metrics.AverageEfficiency = totalEfficiency / float64(len(streams))
	metrics.StreamCount = len(streams)

	// Calculate stage averages
	for name, sm := range stageMetrics {
		metrics.StageMetrics = append(metrics.StageMetrics, StageMetrics{
			Name:            name,
			AverageDuration: sm.TotalDuration / time.Duration(sm.Count),
			AverageWaitTime: sm.TotalWaitTime / time.Duration(sm.Count),
		})
	}

	return metrics, nil
}

type ValueStreamAnalysis struct {
	StreamID    string        `json:"stream_id"`
	TotalTime   time.Duration `json:"total_time"`
	Efficiency  float64       `json:"efficiency"`
	Bottlenecks []Bottleneck  `json:"bottlenecks"`
}

type Bottleneck struct {
	Stage      string        `json:"stage"`
	WaitTime   time.Duration `json:"wait_time"`
	Impact     string        `json:"impact"`
	Suggestion string        `json:"suggestion"`
}

type TeamMetrics struct {
	Team              string         `json:"team"`
	Period            time.Duration  `json:"period"`
	AverageLeadTime   time.Duration  `json:"average_lead_time"`
	AverageEfficiency float64        `json:"average_efficiency"`
	StreamCount       int            `json:"stream_count"`
	StageMetrics      []StageMetrics `json:"stage_metrics"`
}

type StageMetrics struct {
	Name            string        `json:"name"`
	TotalDuration   time.Duration `json:"total_duration"`
	TotalWaitTime   time.Duration `json:"total_wait_time"`
	AverageDuration time.Duration `json:"average_duration"`
	AverageWaitTime time.Duration `json:"average_wait_time"`
	Count           int           `json:"count"`
}

func getBottleneckSuggestion(stage string) string {
	suggestions := map[string]string{
		"code_review":  "Consider implementing review SLOs or adding more reviewers",
		"ci_pipeline":  "Optimize CI pipeline performance or add parallelization",
		"staging":      "Automate staging validation or reduce manual testing",
		"planning":     "Break down work into smaller chunks or improve refinement",
	}
	if suggestion, ok := suggestions[stage]; ok {
		return suggestion
	}
	return "Investigate wait time causes"
}
```

## Verification Checklist

After completing this lab, verify:

- [ ] DORA metrics collector is receiving deployment events
- [ ] Lead time and cycle time histograms are populated
- [ ] Change failure rate is calculated correctly
- [ ] MTTR tracking captures incident resolution times
- [ ] SPACE framework metrics cover all dimensions
- [ ] Developer satisfaction surveys are collecting data
- [ ] Platform adoption metrics show template usage
- [ ] Value stream mapping identifies bottlenecks
- [ ] Grafana dashboards display all key metrics

## Troubleshooting

### Metrics Not Appearing

1. Verify webhook endpoints are receiving events
2. Check Prometheus scrape configuration
3. Validate metric labels match queries
4. Review metric cardinality limits

### Inaccurate Lead Time

1. Ensure commit timestamps are in UTC
2. Verify deployment events include commit SHA
3. Check for timezone conversion issues
4. Validate CI/CD pipeline reporting

### Survey Data Issues

1. Verify respondent authentication
2. Check database connection
3. Review survey submission logs
4. Validate metric aggregation logic

## Summary

In this lab, you learned to:

- Implement DORA metrics collection and visualization
- Apply the SPACE framework for holistic productivity measurement
- Track platform adoption and usage metrics
- Measure developer experience through surveys
- Calculate platform value and ROI
- Map value streams to identify bottlenecks

Effective measurement is essential for demonstrating platform value and identifying improvement opportunities. Use these metrics to guide platform evolution and communicate impact to stakeholders.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- DORA Metrics Implementation
- SPACE Framework Implementation
- Platform Adoption Metrics
- Platform Value Metrics

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
