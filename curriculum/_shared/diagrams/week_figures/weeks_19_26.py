F = {}

F[19] = dict(
 title="Where each control sits: before the plan, at the door, on the wire, at runtime",
 intro="Scanning finds problems; policy prevents them. The figure places every control on the path a workload takes, so you can say where each one would have stopped a given attack.",
 body='''
  subgraph TFP["Before infrastructure exists"]
    direction LR
    PL["① terraform plan as JSON"]:::n
    CT["② Conftest + Rego<br/><small>a public S3 bucket fails the PR · warn vs deny</small>"]:::warn
  end
  subgraph ADM["At the API server · admission"]
    direction LR
    PSS["③ Pod Security Standards<br/><small>namespace label · restricted · a privileged pod is rejected</small>"]:::warn
    KYV["④ Kyverno<br/><small>validate · mutate · verifyImages · non-root, limits, no :latest, signed</small>"]:::warn
    FP["⑤ failurePolicy<br/><small>Fail = secure and brittle · BF-52: locked out of your own cluster</small>"]:::warn
  end
  POD["⑥ the pod runs<br/><small>restricted · signed · limited</small>"]:::crit
  subgraph NET["On the wire"]
    direction LR
    NP["⑦ NetworkPolicy<br/><small>default-deny ingress and egress · allow DNS to kube-dns on 53 first</small>"]:::warn
  end
  subgraph SEC["Secrets"]
    direction LR
    ESO["⑧ External Secrets Operator<br/><small>IRSA → Secrets Manager → Kubernetes Secret · the value never enters Git</small>"]:::data
  end
  subgraph RT["At runtime"]
    direction LR
    FAL["⑨ Falco<br/><small>syscalls · a shell spawned in a container → alert</small>"]:::warn
  end
  CN["⑩ control narrative<br/><small>threat → control → evidence · every accepted risk has an owner and an expiry</small>"]:::n
  PL ==> CT ==> PSS ==> KYV ==> POD
  KYV -.-> FP
  POD ==> NP
  ESO --> POD
  POD -.-> FAL
  CT -.-> CN
  FAL -.-> CN
''',
 link="linkStyle 0,1,2,3,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="four",
 open="The shift this week is from 'we detect insecure deployments' to 'insecure deployments cannot happen'. This figure is a map of where the word cannot gets enforced: before the plan, at the API server, on the wire, and at runtime. Walk it left to right.",
 badges=[
  ("terraform plan as JSON", "The plan is data. `terraform show -json` turns it into something a policy engine can read before anything is created."),
  ("Conftest and Rego", "A Rego rule reads the plan and denies a public S3 bucket. The PR fails before apply. Deny fails the build; warn only shows, which is how you introduce a rule without breaking everyone on day one. Compare it with checkov: Conftest is your rules, checkov is theirs."),
  ("Pod Security Standards", "Built in. Label a namespace `restricted` and the API server rejects a privileged pod, a root user, a host path. No controller to install. Start here, then add Kyverno for what PSS cannot express."),
  ("Kyverno", "Policies as Kubernetes objects. Validate rejects pods without limits or with the `:latest` tag. Mutate adds defaults. verifyImages is the week-18 signature check at the door. Four rules, and all four are exit criteria."),
  ("failurePolicy", "When the webhook is down, Fail means nothing gets admitted, Ignore means everything does. Fail is secure and brittle. BF-52 is you writing a policy that locks you out of your own cluster, then recovering by editing the webhook configuration. That is blog post 10."),
  ("the pod runs", "Only now. It is non-root, limited, signed, in a restricted namespace. Everything above was decided before a single byte of it executed."),
  ("NetworkPolicy", "Default-deny for ingress and egress in the namespace, then allow what the app needs. The trap every first attempt hits: without an explicit allow to kube-dns on port 53, nothing can resolve a name and everything looks broken. Demonstrate one blocked flow."),
  ("External Secrets Operator", "The operator uses IRSA to read Secrets Manager and writes a Kubernetes Secret. The value never enters Git, never enters a CI log, and rotates when the source rotates. Bravo's secrets all arrive this way."),
  ("Falco", "Watches syscalls on the node. A shell spawned inside a container, a write to /etc, an outbound connection from a process that never makes one: each becomes an alert. Prevention above, detection here, because prevention is never complete."),
  ("control narrative", "A table: the threat from the STRIDE model, the control that addresses it, and the evidence that proves the control works. Accepted risks get an owner and an expiry. This is the document a security reviewer actually reads, and it is a Bravo deliverable."),
 ],
 close="Deny in the plan, refuse at the door, drop on the wire, alert at runtime, and a table that maps each one to a threat. Prevent where you can; detect where you cannot; write both down.",
)

F[20] = dict(
 title="From a request to an alert that means users are hurting",
 intro="Most dashboards are decoration. This path runs from instrumentation to a burn-rate alert, and the test of every box is whether it helps answer one question: are users having a bad time right now?",
 body='''
  APP["① instrumented app<br/><small>counter · histogram · gauge · /metrics</small>"]:::crit
  SM["② ServiceMonitor → Prometheus<br/><small>scrape every 15 s · pull, not push · TSDB</small>"]:::crit
  PQ["③ PromQL<br/><small>rate(x[5m]) · histogram_quantile(0.99, sum by (le)) · never average percentiles</small>"]:::crit
  RR["④ recording rules<br/><small>precompute the expensive ratios</small>"]:::data
  SLI["⑤ SLI<br/><small>good requests / total · latency under 300 ms</small>"]:::crit
  SLO["⑥ SLO 99.9 %<br/><small>error budget = 0.1 % · 43.8 min per 30 days</small>"]:::crit
  BR["⑦ burn-rate alerts<br/><small>14.4× over 1 h and 5 m → page · 6× over 6 h and 30 m → ticket</small>"]:::warn
  AM["⑧ Alertmanager<br/><small>group · inhibit · route · silence</small>"]:::n
  PG["⑨ the page<br/><small>symptom-based: users are hurting · never cause-based: CPU is high</small>"]:::crit
  GF["⑩ Grafana<br/><small>one dashboard · answers the question in 5 seconds</small>"]:::n
  OT["⑪ OpenTelemetry traces<br/><small>app → database · the slow span · logs with trace IDs</small>"]:::data
  CARD["⑫ cardinality explosion<br/><small>a user ID as a label · series count × 10,000 · reproduce it, then fix it</small>"]:::warn
  APP ==> SM ==> PQ ==> SLI ==> SLO ==> BR ==> PG
  PQ --> RR --> SLI
  BR --> AM --> PG
  PQ -.-> GF
  APP -.-> OT
  SM -.-> CARD
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="four",
 open="A dashboard passes one test: can someone tell users are having a bad time within five seconds of looking at it. This figure is the path from a line of instrumentation to a page that fires only when that is true. Follow the blue line; the numbers in badges 6 and 7 are the ones to memorize.",
 badges=[
  ("instrumented app", "Three metric types cover almost everything. A counter for requests and errors, a histogram for latency with buckets you chose deliberately, a gauge for things that go up and down. Exposed at /metrics in the format you previewed in week 4."),
  ("ServiceMonitor and Prometheus", "Prometheus pulls. A ServiceMonitor tells it which Services to scrape, every 15 seconds by default. Samples land in a time-series database keyed by metric name and labels. Pull means the app does not need to know where Prometheus is."),
  ("PromQL", "`rate` over a window turns a counter into a per-second rate. For percentiles, sum the histogram buckets keeping `le`, then `histogram_quantile`. Averaging 99th percentiles across instances is wrong and the most common mistake in the drill. Ten queries from scratch, no copy-paste."),
  ("recording rules", "Precompute the ratios that dashboards and alerts both need. One rule evaluated every 30 seconds beats fifty dashboards computing the same thing."),
  ("SLI", "A service level indicator is a ratio: good events over total. Requests under 300 milliseconds over all requests. Pick the one that tracks user experience, not the one that is easy to measure."),
  ("SLO", "The target: 99.9 percent of requests good, over 30 days. The error budget is the other 0.1 percent, which is 43.8 minutes a month. Compute it by hand once. The budget is what makes risk a number you can spend."),
  ("burn-rate alerts", "Burn rate is how fast you are spending the budget. A rate of 14.4 over the last hour, confirmed by the last 5 minutes, means the whole month's budget goes in two days: page. A rate of 6 over 6 hours, confirmed by 30 minutes: open a ticket. Two windows each, so a blip does not page and a slow burn is not missed."),
  ("Alertmanager", "Groups related alerts into one notification, inhibits the noisy ones when a parent fires, routes by severity, and lets you silence during maintenance. Alert design is here as much as in PromQL."),
  ("the page", "Symptom-based: the error rate or latency users see. Never cause-based: CPU high, disk at 80 percent. Causes go on the dashboard for the person who was paged, not on the pager."),
  ("Grafana", "One dashboard, top row answers the question. Error rate, latency percentiles, traffic, saturation. If the five-second test fails, remove panels until it passes."),
  ("OpenTelemetry traces", "A trace follows one request across services. The span that is slow is the one you fix. Logs carry the trace ID so you can jump from a log line to its trace."),
  ("cardinality explosion", "Put a user ID in a label and every user becomes a new series. Ten thousand users, ten thousand times the memory. Reproduce it, watch Prometheus suffer, then fix it by moving the ID to the trace or the log where it belongs."),
 ],
 close="Instrument, scrape, query, define good, set a budget, alert on the burn. The page means users are hurting; everything else is on the dashboard for the person who answers it.",
)

F[21] = dict(
 title="An incident, from the first alert to the postmortem that changes something",
 intro="Three real incidents you ran and three blameless postmortems you wrote are worth more in a behavioral interview than any README. The blue path is the incident; the loop at the end is what makes the next one shorter.",
 body='''
  DET["① detect<br/><small>the burn-rate alert from week 20</small>"]:::crit
  DEC["② declare<br/><small>severity SEV1 to SEV3 · roles: incident commander, comms, ops · even when you are all three</small>"]:::crit
  MIT["③ mitigate FIRST<br/><small>roll back · scale up · feature flag off · 'let me check the logs' costs 40 minutes</small>"]:::crit
  DIA["④ diagnose<br/><small>the week-17 ladder, now with a timer</small>"]:::crit
  RES["⑤ resolve<br/><small>the real fix · verified by the SLI recovering</small>"]:::crit
  PM["⑥ blameless postmortem<br/><small>timeline · contributing factors · what went well · no names in the causes</small>"]:::crit
  AI["⑦ action items<br/><small>each with an owner, a date, and a way to verify it happened</small>"]:::warn
  RB["⑧ runbook<br/><small>updated, or written if it did not exist</small>"]:::data
  CH["⑨ chaos experiment<br/><small>kill a pod, fill a disk, partition the network · on purpose, in daylight</small>"]:::n
  DORA["⑩ DORA four keys<br/><small>deploy frequency · lead time · change failure rate · time to restore</small>"]:::data
  G5["⑪ ★ Gate 5<br/><small>CVE blocked live · unsigned image refused live · PromQL + SLO from scratch · Bravo acceptance</small>"]:::warn
  DET ==> DEC ==> MIT ==> DIA ==> RES ==> PM ==> AI
  AI --> RB
  RB -.-> CH -.-> DET
  RES -.-> DORA
  PM -.-> G5
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Tuesday you run three real incidents against your own stack, and by Friday you have three postmortems. This figure is one incident end to end. The order of badges 3 and 4 is the whole lesson.",
 badges=[
  ("detect", "The alert from week 20 fires because users are hurting, not because a CPU is busy. Time zero is when the alert fired, and the timeline starts there."),
  ("declare", "Name a severity and take the roles. SEV1 is users cannot do the core thing. One person can be incident commander, communicator, and operator, but saying which hat you are wearing keeps you from skipping the communication."),
  ("mitigate first", "Stop the bleeding before you understand the wound. Roll back the deploy, scale up, turn the flag off. 'Let me just check the logs' is the instinct, and it costs forty minutes of user impact. Mitigation is allowed to be ugly."),
  ("diagnose", "Now the week-17 ladder: symptom, change, hypothesis, layers, confirm. With a timer running, because the timeline will show how long it took."),
  ("resolve", "The real fix, and the proof is the SLI recovering, not a feeling. Note the time; time to restore is a DORA number."),
  ("blameless postmortem", "A timeline with timestamps, the contributing factors, what went well, what was lucky. No names in the causes: a person did something because the system made it the obvious thing to do. Blameless means blameless, or nobody tells the truth next time."),
  ("action items", "Every action item has three things: an owner, a date, and a way to verify it was done. An action item without those is a wish. This is the sentence interviewers want to hear you say."),
  ("runbook", "Update the runbook, or write the one that should have existed. The template is in _shared. A runbook is the postmortem's most durable output."),
  ("chaos experiment", "Kill a pod, fill a disk, partition the network, on purpose, during the day, with the runbook open. Chaos engineering is rehearsing the incident before it chooses the time."),
  ("DORA four keys", "Deployment frequency, lead time for changes, change failure rate, time to restore. Measure yours for Bravo. They are the numbers an engineering leader uses to describe a team, and now you can describe yourself with them."),
  ("Gate 5", "Friday: the pipeline blocks a critical CVE live, refuses an unsigned image live, you write a PromQL query and a valid SLO from scratch, and Bravo meets its acceptance criteria. Then the demo video Saturday."),
 ],
 close="Detect, declare, mitigate before you diagnose, fix, write it down without blame, and leave an action item someone can verify. Three of those, written by you, are an interview story bank.",
)

F[22] = dict(
 title="The golden path, as a product",
 intro="Platform engineering is product management applied to infrastructure. The figure reads like a product: a user with a pain, a contract they write, a paved road that does the rest, and the metrics that say whether it worked.",
 body='''
  DEV["① the user<br/><small>a product engineer · not a Kubernetes expert · does not want to be</small>"]:::crit
  PAIN["② the pain today<br/><small>N tickets · days to a running service · copy-paste from the last repo</small>"]:::warn
  SY["③ service.yaml<br/><small>name · owner · language · port · tier · dependencies · the only thing they write</small>"]:::crit
  SCH["④ JSON schema + validation<br/><small>errors say how to fix it · the error message is the product</small>"]:::crit
  TPL["⑤ template-service/<br/><small>scaffolds a repo · ships hardened by default</small>"]:::n
  REG["⑥ module registry<br/><small>versioned Terraform · runtime, pipeline, database, storage, observability</small>"]:::data
  ROAD["⑦ the paved road<br/><small>namespace · pipeline · dashboard · alerts · SLO · runbook stub · all generated</small>"]:::crit
  NG["⑧ non-goals and escape hatches<br/><small>what it will not do · how to go off-road, supported</small>"]:::mut
  MET["⑨ DX metrics<br/><small>time to first deploy · tickets per service · cognitive load</small>"]:::data
  BB["⑩ build vs Backstage<br/><small>a written decision with reasons</small>"]:::n
  BRIEF["⑪ ⚑ the product brief<br/><small>user · pain · paved road · non-goals · riskiest assumption</small>"]:::warn
  DEV ==> SY ==> SCH ==> ROAD
  DEV -.-> PAIN
  TPL --> SY
  REG --> ROAD
  ROAD -.-> NG
  ROAD -.-> MET
  BB -.-> ROAD
  PAIN -.-> BRIEF
''',
 link="linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Explain a golden path in sixty seconds without saying self-service more than once. This figure is the sixty seconds. It starts with a person and a pain, not with a technology.",
 badges=[
  ("the user", "A product engineer who wants to ship a feature. They do not know Kubernetes and the platform's job is to keep it that way. Every design decision is tested against this person."),
  ("the pain today", "Count it: how many tickets to get a service running, how many days, how much copying from the last repository. The brief quantifies the pain so the platform can be measured against it."),
  ("service.yaml", "The contract. Name, owner, language, port, tier, dependencies. It is the only file the user writes, and every field exists because something downstream needs it. The charlie project in _reference shows the shape."),
  ("JSON schema and validation", "The schema rejects a bad file, and the error says exactly what to change. The error message is the product: a validation that says 'invalid' makes the user ask you, and then it is not a platform."),
  ("template-service", "A repository scaffold with the Dockerfile, the pipeline, and the health endpoints already correct. Hardened by default, so the easy way is the right way without the user choosing it."),
  ("module registry", "Versioned Terraform modules for runtime, pipeline, database, storage, and observability. The weeks 10 to 13 modules, now consumed by a controller instead of a person."),
  ("the paved road", "What the contract turns into: a namespace with quotas, a pipeline, a dashboard, alerts, an SLO, a runbook stub. All of it generated. The user opts out of nothing because nothing is opt-in."),
  ("non-goals and escape hatches", "The brief says what the platform will not do, and the docs say how to go off the paved road with support rather than in secret. Platforms die when the only way off is to work around them."),
  ("DX metrics", "Time to first deploy, tickets per service, and the cognitive load the user carries. Measure before and after. A platform that cannot show the number did not move it."),
  ("build versus Backstage", "A written decision. Backstage is a portal with a learning curve; for one person and three services it is overhead. Say why, in an ADR, so the decision can be revisited when the answer changes."),
  ("the product brief", "Tuesday's deliverable: user, pain, paved road, non-goals, how you will know it worked, and the riskiest assumption. Everything in weeks 23 and 24 is checked against this page."),
 ],
 close="A person, a pain, one file, a road that makes the right thing the easy thing, and a number that says it worked. That is a golden path, and most candidates cannot explain it.",
)

F[23] = dict(
 title="One pull request to a running service",
 intro="Nothing here is new technology. It is Terraform, CI, GitOps, the security gates, and observability from months 1 to 5, wired together behind one contract. Follow the blue path from a file to a service with zero manual steps.",
 body='''
  PR["① PR adds services/name/service.yaml"]:::crit
  VAL["② validate<br/><small>schema + business rules · a bad file fails in seconds with the fix in the message</small>"]:::warn
  PLAN["③ plan<br/><small>changed services only · the diff as a PR comment</small>"]:::crit
  COST["④ cost estimate<br/><small>in the PR, before merge · Infracost</small>"]:::data
  MRG["⑤ merge<br/><small>the human decision</small>"]:::crit
  subgraph GEN["⑥ provision · generated, zero manual steps"]
    direction LR
    NS["namespace<br/><small>quota · default-deny NetworkPolicy</small>"]:::n
    IAM["IRSA role<br/><small>least privilege from the declared dependencies only</small>"]:::warn
    ECR["ECR + pipeline<br/><small>from the template</small>"]:::n
    DNS["DNS + ArgoCD Application"]:::n
  end
  OBS["⑦ generated observability<br/><small>dashboard · alerts · SLO per tier · runbook stub · never opt-in</small>"]:::crit
  RUN["⑧ the running service<br/><small>tier decides: critical = 3 AZs, PDB, 99.9 % SLO</small>"]:::crit
  DEL["⑨ delete the file<br/><small>deprovision with guardrails · critical needs a second approval</small>"]:::warn
  EX["⑩ two example services<br/><small>hello-api minimal · orders-api with postgres + s3, tier critical</small>"]:::mut
  PR ==> VAL ==> PLAN ==> MRG ==> NS ==> RUN
  PLAN --> COST --> MRG
  MRG --> IAM
  MRG --> ECR
  MRG --> DNS
  MRG ==> OBS ==> RUN
  RUN -.-> DEL
  RUN -.-> EX
''',
 link="linkStyle 0,1,2,3,4,8,9 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Everything from months 1 to 5 composes here. A developer adds one file and merges; ten minutes later a service is running with a dashboard, an SLO, and a least-privilege role they never wrote. The figure is that ten minutes.",
 badges=[
  ("the pull request", "One file in services, named for the service. The developer does not touch Terraform, Kubernetes, or IAM. If they have to, the platform has a gap."),
  ("validate", "Schema first, then business rules: the owner must exist in teams.yaml, the tier must be one of three, a critical tier must declare an SLO. The error names the field and the fix. The break/fix for the week is a malformed file, because the error message is the feature."),
  ("plan", "Only the services whose files changed are planned. The diff goes on the PR as a comment, which is what the reviewer reads."),
  ("cost estimate", "Infracost turns the plan into dollars per month and posts it next to the diff. A tier that costs four times more is a conversation before merge, not a surprise on the bill."),
  ("merge", "The one human decision in the flow. Everything after it is a machine following the contract."),
  ("provision", "A namespace with resource quotas and a default-deny policy. An IRSA role whose permissions are generated from the declared dependencies, so a service that declares one S3 bucket read-write gets exactly that. An ECR repository and a pipeline from the template. A DNS record and an ArgoCD Application that deploys it."),
  ("generated observability", "A dashboard, alerts, an SLO appropriate to the tier, and a runbook stub with the service's name already in it. The developer does not opt in and cannot opt out. Week 20's lesson, delivered by default."),
  ("the running service", "The tier decides the shape. Critical means three availability zones, a PodDisruptionBudget, and a 99.9 percent SLO. Experimental means one replica and an auto-expiry so nothing is production without an SLO."),
  ("delete the file", "Deleting the file deprovisions everything, through the same pipeline, with guardrails: a critical service needs a second approval and the data store is retained. Deprovisioning that is harder than provisioning is how platforms accumulate ghosts."),
  ("two example services", "hello-api with nothing declared, and orders-api with Postgres, an S3 bucket, and tier critical. Both provisioned through the platform. They are the stranger test's starting point next week."),
 ],
 close="Validate, plan with a price, merge, generate everything, run, and remove cleanly. Zero manual steps between merge and a running service is the exit criterion, and Gate 6 times it.",
)

F[24] = dict(
 title="The documentation set and the stranger test",
 intro="A platform nobody can use without asking you is a set of scripts with a good story. This week the documentation is the deliverable, and one stranger decides whether it worked.",
 body='''
  GS["① getting-started.md<br/><small>the five-minute path · the only page most users read</small>"]:::crit
  CR["② contract reference<br/><small>every field of service.yaml · the schema, documented</small>"]:::crit
  TR["③ tiers.md<br/><small>readable by a product manager · what critical costs and buys</small>"]:::n
  EH["④ escape-hatches.md<br/><small>going off the paved road is supported · the page nobody writes</small>"]:::n
  ADR["⑤ ADRs ×4+<br/><small>build vs Backstage · the tier model · IRSA generation · deprovision guardrails</small>"]:::data
  RBK["⑥ runbooks<br/><small>validation failures · stuck provisioning · rollback</small>"]:::data
  DIA["⑦ architecture diagram<br/><small>generate-figures.py · icons · the figure a hiring manager sees</small>"]:::n
  ST["⑧ the stranger test<br/><small>watch someone use it · say nothing · fix every hesitation</small>"]:::warn
  VID["⑨ demo video<br/><small>5 minutes · file to running service, timed</small>"]:::crit
  RM["⑩ README<br/><small>measured numbers · cost table · what broke</small>"]:::crit
  PIN["⑪ GitHub profile<br/><small>Alpha, Bravo, Charlie pinned</small>"]:::mut
  KC["⑫ KCSA decision<br/><small>take it only if the application mix is security-weighted · else interview prep</small>"]:::mut
  GS ==> ST ==> VID ==> RM
  CR --> GS
  TR --> GS
  EH --> GS
  ADR -.-> RM
  RBK -.-> RM
  DIA -.-> RM
  RM --> PIN
  RM -.-> KC
''',
 link="linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="Charlie works. This week decides whether anyone but you can tell. The documentation set on the left feeds one page, and that page is tested by a person who has never seen the project while you watch and say nothing.",
 badges=[
  ("getting-started", "The five-minute path: copy a template, edit six fields, open a PR, watch it run. Most users read this page and nothing else, so it has to be enough by itself."),
  ("contract reference", "Every field of service.yaml, what it accepts, what it does downstream, and what the error looks like when it is wrong. The schema is the source; this page is the schema with sentences."),
  ("tiers", "What experimental, standard, and critical each give you and cost you. Written so a product manager can choose without an engineer in the room."),
  ("escape hatches", "How to do the thing the platform does not support, with support. Nobody writes this page, and its absence is why people work around platforms in secret."),
  ("ADRs", "At least four: why not Backstage, why three tiers, how the IAM role is generated from dependencies, why deprovisioning needs a second approval. The decisions you will be asked about in interviews, written the week you made them."),
  ("runbooks", "What to do when validation fails, when provisioning sticks, when a rollback is needed. The week-21 template, three times."),
  ("architecture diagram", "The icon figure from the generator, the same style as the project READMEs. It is the one image a hiring manager looks at before deciding to read."),
  ("the stranger test", "Wednesday: someone who has never seen the project deploys a service using only the README while you watch. Every time they hesitate, that is a bug in the docs. Fix every one. Say nothing during the test; help afterwards."),
  ("demo video", "Five minutes, file to running service, with a timer visible. It is the asset that gets watched when a résumé is skimmed."),
  ("README", "Measured numbers: time to a running service, cost per tier per month, how long deprovisioning takes. A cost table. A section called what broke. Honesty reads as seniority."),
  ("GitHub profile", "Alpha, Bravo, and Charlie pinned, in that order. Three projects a stranger can run beat any list of skills."),
  ("KCSA decision", "Take it only if the applications you are sending are genuinely security-weighted. Otherwise the thirty hours buy more as interview preparation, which is next week."),
 ],
 close="Docs feed one page, one stranger tests it, the video proves it in five minutes, and the README carries the numbers. Then pin all three projects, because week 25 is interviews.",
)

F[25] = dict(
 title="The interview kit, and where every piece of it comes from",
 intro="The mix inverts: interviewing is the primary activity at twenty hours a week. Nothing in the kit is invented this week; every piece is traced back to something you built, broke, or wrote in the previous twenty-four.",
 body='''
  subgraph SRC["What you already have"]
    direction LR
    IJ["① incident journal<br/><small>~50 entries · the story source</small>"]:::data
    PJ["② three projects<br/><small>Alpha · Bravo · Charlie · pinned</small>"]:::data
    BL["③ twelve blog posts<br/><small>every one is a talking point</small>"]:::data
  end
  subgraph KIT["The kit"]
    direction LR
    STAR["④ 8 STAR stories<br/><small>situation, task, action, result · timed at 90 s · a number in every result</small>"]:::crit
    EXP["⑤ project explanations<br/><small>30 s · 3 min · 15 min · each project, each length</small>"]:::crit
    SD["⑥ 3 system designs<br/><small>whiteboarded aloud · 45 min each · recorded</small>"]:::crit
    LIVE["⑦ live exercises<br/><small>bash · Python · Terraform · a broken cluster · under a timer</small>"]:::crit
    Q["⑧ your questions for them<br/><small>written down · about the work, not the perks</small>"]:::n
  end
  MOCK["⑨ 6 mock interviews<br/><small>at least 3 with real engineers · recorded</small>"]:::warn
  REV["⑩ review the recordings<br/><small>the weak spots · fix them, re-record</small>"]:::warn
  APP["⑪ 20+ applications<br/><small>this week · the pipeline keeps filling</small>"]:::mut
  IJ ==> STAR ==> MOCK ==> REV
  PJ --> EXP --> MOCK
  PJ --> SD --> MOCK
  BL -.-> STAR
  LIVE --> MOCK
  Q --> MOCK
  REV -.->|"re-run"| STAR
  APP -.-> MOCK
''',
 link="linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="You have three shipped projects, about fifty incident entries, and twelve blog posts. This week turns them into offers, and the figure shows the conversion: raw material on the left, the kit in the middle, six mock interviews that test it on the right.",
 badges=[
  ("incident journal", "Fifty entries, each with a symptom, a diagnosis, a fix, and what you would prevent. Every behavioral story in the kit starts as one of these lines."),
  ("three projects", "Alpha, Bravo, Charlie. Each one is a system design answer you have already built, and each README has measured numbers you can quote."),
  ("twelve blog posts", "Each one is a talking point you have already written out. The IRSA post is the answer to the workload identity question; the count-versus-for_each post is the Terraform question."),
  ("STAR stories", "Eight of them. Situation, task, action, result, and the result ends with a number. Timed at ninety seconds, because the untimed version is four minutes and loses the room. The template is in _shared."),
  ("project explanations", "Each project at three lengths: thirty seconds for a screen, three minutes for a hiring manager, fifteen for a deep dive. Write all nine and say them out loud until the thirty-second one is reflexive."),
  ("system designs", "Three scenarios from the interview bank, whiteboarded out loud for forty-five minutes each, recorded. The point is the narration, not the drawing: tradeoffs stated as you make them."),
  ("live exercises", "A bash one-liner, a Python function, a Terraform module, a broken cluster, each under a timer with someone watching. The broken cluster is Gate 4 again; the others are weeks 1, 4, and 11."),
  ("your questions", "Written down in advance, about the work: how deploys happen, what the on-call load is, what broke last quarter. The questions you ask are the last impression and they are graded."),
  ("mock interviews", "Six, at least three with real engineers, all recorded. Friday and Saturday. The ones with strangers are worth triple; friends are too kind."),
  ("review the recordings", "Watch them. Note every hesitation, every answer that ran long, every tradeoff you forgot. Fix those specifically and re-record the weak stories. This is the loop that makes week 26 different from week 25."),
  ("applications", "Twenty or more this week, with follow-ups on every open thread. The kit is useless if the pipeline empties."),
 ],
 close="Stories from the journal, designs from the projects, talking points from the posts, all tested six times on camera. Every piece is traceable to something you built, which is why it will sound true.",
)

F[26] = dict(
 title="The weekly cadence that carries months 6 to 10",
 intro="Not the finish line: the point where the pipeline is full and converting. The figure is one week of the cadence you will repeat, plus the sixth gate and the retrospective that writes the plan for weeks 27 and beyond.",
 body='''
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
''',
 link="linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="This is week 26, and it is also every week after it. Twenty hours interviewing, ten building, ten on prep and people. The figure is the loop, the sixth gate sits beside it, and the retrospective at the end writes the next plan.",
 badges=[
  ("Monday applications", "Twenty or more, and every open thread followed up. The tracker is the source of truth: company, role, date, source, status. A pipeline you cannot see is a pipeline you cannot diagnose."),
  ("interviews", "Each one with its own research: what the company runs, what broke publicly, what the team's blog says. The kit from week 25 is the answer bank; the research is what makes the answers land."),
  ("Gate 6", "Wednesday, the final attempt: a stranger deploys a service through a pull request in under ten minutes with no help. Timed, recorded. It proves the platform, the docs, and the week-24 stranger test all at once."),
  ("two more mocks", "Targeted at whatever last week's real interviews exposed. The mock is cheap practice for the expensive thing."),
  ("networking", "Five conversations and one event. People refer people; postings are the slowest door. Say what you built in thirty seconds and ask about their work."),
  ("build what the interviews exposed", "Failed a question on ApplicationSets? That is Saturday's work. Fumbled cost optimization? Add a FinOps dashboard to Charlie. Every rejection is a curriculum, and a candidate still shipping interviews with no desperation in their voice."),
  ("program retrospective", "Sunday: the numbers, applications and screens and onsites and offers; a funnel diagnosis of where it narrows; rejection reasons; the five best lines from the Surprised column of the journal; and whether the pace is sustainable."),
  ("weeks 27 plus plan", "Written down: twenty hours interviewing, ten building, ten on preparation and networking. The plan is what turns the end of the program into a cadence instead of a stop."),
  ("the pipeline lag", "Six to ten weeks from application to offer. Applications started in week 14, so the likely offer window is months six to ten. Knowing the lag is what keeps week 26 from feeling like failure."),
  ("all six gates", "A stack from a fresh VM, the SAA at eighty percent, Alpha in one command, five clusters narrated, Bravo refusing a CVE and an unsigned image, Charlie in ten minutes. Six proofs, each one a story."),
 ],
 close="Apply, interview, build what they exposed, write down what you learned, repeat. The program ends; the cadence does not, and the cadence is what converts.",
)
