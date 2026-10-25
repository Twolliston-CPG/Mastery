# Zero to Hired — 6-Month DevOps / DevSecOps / Platform Engineering Track

> A 26-week, 1,000+ hour program for a student starting at zero, studying 4–8+ hours/day,
> targeting AWS SAA + HashiCorp Terraform Associate (+ optional KCSA, and CKA in a four-week module after week 26),
> three shipped portfolio projects, and a job offer.

**Built:** 2026-09-20 · **Audience:** absolute beginner with full-time study availability

---

## Read in this order

| # | File | What it is |
|---|---|---|
| 1 | **[ROADMAP.md](ROADMAP.md)** | The strategy. Honest framing, the 9 core recommendations, the 6-month arc, monthly go/no-go gates, failure modes. **Start here.** |
| 2 | **[curriculum/STEP-BY-STEP.md](curriculum/STEP-BY-STEP.md)** | **The operating manual.** What you actually do on an ordinary Tuesday, and how that compounds into 26 weeks. Four nested loops: day, week, gate, program — plus what to do when you fail a gate or fall behind. |
| 3 | **[WEEK-BY-WEEK.md](WEEK-BY-WEEK.md)** | The execution plan. All 26 weeks: focus, labs, deliverable, recall drills, exit criteria. |
| 4 | **[CERTIFICATIONS.md](CERTIFICATIONS.md)** | Cert strategy and sequencing, honest signal-value ratings, three tracks (including why I'd swap KCNA for CKA), study resources, exam tactics. |
| 5 | **[PROJECTS.md](PROJECTS.md)** | Three flagship projects with hard acceptance criteria, 12 micro-projects, and how to present them so they actually convert. |
| 6 | **[JOB-SEARCH.md](JOB-SEARCH.md)** | Starts week 14, not week 26. Target titles, pipeline math, résumé rules for career changers, referral scripts, interview loop prep. |
| 7 | **[curriculum/](curriculum/)** | **The actual content.** All 26 weeks — labs, worked solutions, running code, assessments — plus a 58-scenario break/fix library, drills, an interview bank, 623 files of anonymized reference material, and three project implementations. Start at [curriculum/START-HERE.md](curriculum/START-HERE.md). |
| 8 | **[KUBERNETES-MASTERY.md](KUBERNETES-MASTERY.md)** | The Kubernetes mastery ladder: five rungs, twelve topics, the rubric, the eleven Go deeper labs, the long-lived cluster, the reading, the scoring. The exam is rung two; this is the rest |

---

## The 30-second version

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![The 30-second version — diagram](_figures/README-0-8d1b87e9.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  M1["<b>M1</b> Foundations<br/><small>Linux · networking · Git · Python · Docker</small>"]:::n
  M2["<b>M2</b> AWS<br/><small>IAM · VPC · compute · storage · data</small>"]:::n
  M3["<b>M3</b> AWS + IaC<br/><small>Terraform · GitHub Actions · OIDC</small>"]:::n
  M4["<b>M4</b> IaC + K8s<br/><small>Kubernetes core · EKS · ArgoCD</small>"]:::n
  M5["<b>M5</b> DevSecOps<br/><small>supply chain · policy · runtime · secrets</small>"]:::n
  M6["<b>M6</b> Platform + SRE<br/><small>observability · IDP · interviews</small>"]:::n

  SAA["★ SAA<br/><small>wk 10</small>"]:::crit
  TF["★ Terraform Assoc<br/><b>APPLY</b> · wk 14"]:::crit
  KCSA["★ KCSA<br/><small>wk 25 · optional</small>"]:::crit
  CKA["★ CKA<br/><small>wks 27–30 · its own module</small>"]:::crit

  A["<b>Project ALPHA</b><br/><small>cloud foundation</small>"]:::n
  B["<b>Project BRAVO</b><br/><small>secure delivery</small>"]:::n
  C["<b>Project CHARLIE</b><br/><small>developer platform</small>"]:::n

  M1 --> M2 --> M3 --> M4 --> M5 --> M6
  M3 -.-> SAA
  M4 -.-> TF
  M6 -.-> KCSA
  M6 -.-> CKA
  M3 --> A
  M5 --> B
  M6 --> C

  linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px
```

</details>

**Three non-negotiables**
1. **70% keyboard, 30% input.** Beginners invert this and stall at month 3.
2. **Apply from week 14.** The pipeline has a 6–10 week lag; starting at week 26 means hired at month 9.
3. **One rest day per week.** 26 weeks at this intensity is won on sustainability, not heroics.

---

## Honest expected outcome

At 4–8 hrs/day for 26 weeks (~1,000–1,300 focused hours) with all three projects shipped and 2–4 certs
earned, the most likely outcome is **an offer in month 6–10**, not month 6. Plan runway for 9 months.
The roadmap is built so that month 6 is when the *pipeline is full and converting* — not when it starts.

See [ROADMAP.md § Honest framing](ROADMAP.md#1-honest-framing--read-this-before-anything-else).

---

## The curriculum

[`curriculum/`](curriculum/) contains everything needed to actually execute the 26 weeks, plus the four-week CKA module (weeks 27–30) that runs alongside the job search.

**`curriculum/`**

| File | What it is |
|---|---|
| `START-HERE.md` | day-one setup and the rules that make the rest work |
| `STEP-BY-STEP.md` | the operating manual — the daily, weekly, gate and program loops |
| `SOURCES.md` | provenance and the anonymization record |
| `_setup/` | runnable scripts: toolchain, AWS guardrails, kind, teardown |
| `_shared/` | 58 break/fix scenarios · drills · Anki · interview bank · templates |
| `_reference/` | 623 anonymized files, ~338k lines, mapped week by week |
| week-01/ … week-26/   README · labs/ · solutions/ · assessment.md |  |
| `projects/` | alpha (validated Terraform) · bravo · charlie (working validator + CLI) |


| | |
|---|---|
| Written for this curriculum | ~21,000 lines across 144 week files + shared assets + projects |
| Curated reference library | 623 files, ~338,000 lines, fully anonymized |
| Break/fix scenarios with solutions | 58 |
| Interview questions with model answers | ~60 |
| Gates | 6, each demonstrated rather than self-assessed |

Everything executable was verified — `terraform validate`, `conftest verify`, `kubectl kustomize`,
`docker compose config`, `bash -n`, and YAML/JSON parsing. See
[curriculum/SOURCES.md](curriculum/SOURCES.md).
