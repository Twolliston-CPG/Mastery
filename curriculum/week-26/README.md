# Week 26 — Full-Time Conversion ★ GATE 6

> **This is not the finish line. It is the point where the pipeline is full and converting.**
> The most likely offer window is month 6–10. Week 26 is where the program converts into a cadence
> that carries you there.

| | |
|---|---|
| **Hours** | ~40 — **20 interviewing, 10 building, 10 prep and networking** |
| **★ GATE 6** | A stranger deploys a service via pull request in under 10 minutes, unaided |
| **Deliverable** | A full pipeline, a sustainable weekly cadence, and a written plan for weeks 27+ |

## The week in one figure

**Figure 26.1 — The weekly cadence that carries months 6 to 10.** Not the finish line: the point where the pipeline is full and converting. The figure is one week of the cadence you will repeat, plus the sixth gate and the retrospective that writes the plan for weeks 27 and beyond. Badges are numbered in the order to walk them; the blue path is the one to follow first.

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  APP["① Monday: 20+ applications<br/><small>every open thread followed up · the tracker is the source of truth</small>"]:::crit
  INT["② interviews<br/><small>research each company individually · the kit from week 25</small>"]:::crit
  G6["③ ★ Gate 6<br/><small>a stranger deploys a service by PR in under 10 minutes, unaided · timed</small>"]:::warn
  MOCK["④ two more mocks<br/><small>on whatever last week's interviews exposed</small>"]:::n
  NETW["⑤ networking<br/><small>5 conversations · 1 event · people, not postings</small>"]:::n
  BLD["⑥ build what the interviews exposed<br/><small>failed on ApplicationSets → that is Saturday · the rejection is the curriculum</small>"]:::crit
  RET["⑦ program retrospective<br/><small>the numbers · funnel diagnosis · rejection reasons · the five best Surprised lines · sustainability</small>"]:::data
  PLAN["⑧ weeks 27+ plan<br/><small>20 h interviewing · 10 h building · 10 h prep and networking · written down</small>"]:::crit
  LAG["⑨ the pipeline lag<br/><small>6 to 10 weeks from application to offer · started week 14 → offers in months 6 to 10</small>"]:::mut
  GATES["⑩ all six gates<br/><small>1 stack from a fresh VM · 2 SAA 80 % · 3 Alpha one command · 4 five clusters narrated · 5 Bravo refuses · 6 Charlie in 10 min</small>"]:::data
  APP ==> INT ==> BLD ==> RET ==> PLAN
  INT --> MOCK --> BLD
  INT --> NETW
  G6 -.-> RET
  LAG -.-> APP
  GATES -.-> G6
  PLAN -.->|"repeat weekly"| APP
  linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px
```

**What to say, badge by badge** · about three minutes at a normal pace. Point at each badge as you say its line.

- **Open.** “This is week 26, and it is also every week after it. Twenty hours interviewing, ten building, ten on prep and people. The figure is the loop, the sixth gate sits beside it, and the retrospective at the end writes the next plan.”
- **① Monday applications.** “Twenty or more, and every open thread followed up. The tracker is the source of truth: company, role, date, source, status. A pipeline you cannot see is a pipeline you cannot diagnose.”
- **② interviews.** “Each one with its own research: what the company runs, what broke publicly, what the team's blog says. The kit from week 25 is the answer bank; the research is what makes the answers land.”
- **③ Gate 6.** “Wednesday, the final attempt: a stranger deploys a service through a pull request in under ten minutes with no help. Timed, recorded. It proves the platform, the docs, and the week-24 stranger test all at once.”
- **④ two more mocks.** “Targeted at whatever last week's real interviews exposed. The mock is cheap practice for the expensive thing.”
- **⑤ networking.** “Five conversations and one event. People refer people; postings are the slowest door. Say what you built in thirty seconds and ask about their work.”
- **⑥ build what the interviews exposed.** “Failed a question on ApplicationSets? That is Saturday's work. Fumbled cost optimization? Add a FinOps dashboard to Charlie. Every rejection is a curriculum, and a candidate still shipping interviews with no desperation in their voice.”
- **⑦ program retrospective.** “Sunday: the numbers, applications and screens and onsites and offers; a funnel diagnosis of where it narrows; rejection reasons; the five best lines from the Surprised column of the journal; and whether the pace is sustainable.”
- **⑧ weeks 27 plus plan.** “Written down: twenty hours interviewing, ten building, ten on preparation and networking. The plan is what turns the end of the program into a cadence instead of a stop.”
- **⑨ the pipeline lag.** “Six to ten weeks from application to offer. Applications started in week 14, so the likely offer window is months six to ten. Knowing the lag is what keeps week 26 from feeling like failure.”
- **⑩ all six gates.** “A stack from a fresh VM, the SAA at eighty percent, Alpha in one command, five clusters narrated, Bravo refusing a CVE and an unsigned image, Charlie in ten minutes. Six proofs, each one a story.”
- **Close.** “Apply, interview, build what they exposed, write down what you learned, repeat. The program ends; the cadence does not, and the cadence is what converts.”

---

## The week's shape
| Day | Focus |
|---|---|
| Mon | 20+ applications. Every open thread followed up. |
| Tue | Interviews + prep. Company research for each one, individually. |
| Wed | ★ **Gate 6 final attempt** + continued building |
| Thu | Interviews + 2 more mocks |
| Fri | Networking: 5 conversations, 1 event |
| Sat | Build: iterate whichever project your interviews exposed as weakest |
| Sun | **Program retrospective. Write the weeks 27+ plan.** |

## Keep building — this is not optional

A candidate who is still shipping during their job search interviews differently from one who is
waiting. You have new material, momentum, and no desperation in your voice. It is also the best
available defense against the morale erosion of a long search.

**Let the interviews drive what you build.** Failed a question on ArgoCD ApplicationSets? That's this
weekend. Couldn't answer something about cost optimization? Add a FinOps dashboard to Charlie. Every
rejection is a curriculum.

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

## ★ GATE 6 and the program retrospective — [assessment.md](assessment.md)
