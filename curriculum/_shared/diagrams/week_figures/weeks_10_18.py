F = {}

F[10] = dict(
 title="What Terraform does when you type apply",
 intro="Terraform is a syntax-and-lifecycle problem once you know what the resources are, and month 2 taught you that. The blue path is the lifecycle: read config, read the world, diff, call the API, record the result.",
 body='''
  CFG["① configuration<br/><small>*.tf · HCL · variables, outputs, providers</small>"]:::crit
  INIT["② terraform init<br/><small>downloads providers · configures the backend · .terraform.lock.hcl</small>"]:::crit
  PLAN["③ terraform plan<br/><small>refresh: read real resources · diff against state · build the graph</small>"]:::crit
  ST["④ state<br/><small>S3 backend · versioned · locked while an apply runs</small>"]:::data
  APPLY["⑤ terraform apply<br/><small>provider API calls, in dependency order</small>"]:::crit
  RES["⑥ real resources<br/><small>the week-5 EC2 instance, now in code</small>"]:::crit
  DRIFT["⑦ drift<br/><small>a console change · plan shows the diff · you decide who wins</small>"]:::warn
  IMP["⑧ terraform import<br/><small>adopt a console-made resource · plan to empty</small>"]:::n
  MV["⑨ state mv · moved block<br/><small>rename without destroy</small>"]:::n
  CORR["⑩ corrupted local state<br/><small>recover from the backend's previous version</small>"]:::warn
  ALPHA["⑪ ⚑ Alpha kickoff<br/><small>repo · modules/ · environments/dev · first module</small>"]:::n
  CFG ==> INIT ==> PLAN ==> APPLY ==> RES
  PLAN --> ST
  APPLY --> ST
  RES -.-> DRIFT -.-> PLAN
  RES -.-> IMP -.-> ST
  ST -.-> MV
  ST -.-> CORR
  RES -.-> ALPHA
''',
 link="linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Tuesday you sit the SAA. Wednesday you start Terraform, and the reason that order works is this picture: you already know what every resource is, so all that is left is the lifecycle. Five boxes on the blue line.",
 badges=[
  ("configuration", "HCL files describe the desired world: resources, variables, outputs, and which providers to use. Nothing happens by writing them. They are a declaration, not a script."),
  ("terraform init", "Downloads the providers, pins their versions in the lock file, and configures where state will live. The lock file is committed; it is what makes two machines produce the same plan."),
  ("terraform plan", "Three steps in one command. Refresh reads the real resources through the provider. Then Terraform diffs the configuration against the state. Then it builds a dependency graph and prints what it would do. Read the plan every time. Read the graph once, with `terraform graph`, so you believe the order."),
  ("state", "The map from configuration addresses to real resource IDs. It lives in an S3 bucket, versioned, and a lock object stops two applies colliding. Losing state does not destroy anything, but it loses the map, and rebuilding the map is the import work in badge 8."),
  ("terraform apply", "The provider calls the API, in dependency order, and writes each result into state as it goes. An apply that fails halfway leaves a partial state that is still correct about what exists."),
  ("real resources", "The week-5 EC2 instance, now reproducible. Destroy it and apply it until the loop is muscle memory. That loop is what makes the clean-account test in week 13 possible."),
  ("drift", "Change something in the console. The next plan shows the difference. Terraform does not decide who wins; you do. Drift you did not expect is an incident; drift you expected is a plan you have not applied yet."),
  ("terraform import", "Adopt a resource someone created by hand: write the configuration, import the ID into state, and plan. The goal is a plan with no changes. That is the exit criterion, and it is how brownfield accounts get into code."),
  ("state mv and moved blocks", "Renaming a resource in configuration looks like destroy-and-create to Terraform. A moved block, or state mv, tells it the resource only changed names. Week 11 does this across module boundaries."),
  ("corrupted local state", "Corrupt the local copy on purpose, then recover it from the backend's previous version. Versioning on the state bucket is the recovery path, and you should have used it once before you need it."),
  ("Alpha kickoff", "Saturday: the repository, a modules directory, a dev environment, and the first module. Nothing fancy; the structure is what matters, because weeks 11 to 13 fill it in."),
 ],
 close="Declare, init, plan, apply, record. Everything else, drift and import and moved, is the state map disagreeing with the world and you deciding which one is right.",
)

F[11] = dict(
 title="Module contract, environments, and the count index shift",
 intro="The skill that gets paid is module design: a contract another engineer can consume without reading your implementation, and refactoring that never destroys production. The orange box is the bug that makes blog post 6.",
 body='''
  subgraph ENV["Root modules · one per environment"]
    direction LR
    DEV["① environments/dev<br/><small>small instances · single NAT · own state</small>"]:::crit
    PROD["② environments/prod<br/><small>same modules, different inputs · own state</small>"]:::crit
  end
  subgraph MOD["Modules · the contract is variables in, outputs out"]
    direction LR
    NET["③ network<br/><small>cidr in · subnet IDs out</small>"]:::crit
    COMP["④ compute<br/><small>subnet IDs in · ASG, ALB DNS out</small>"]:::crit
    DB["⑤ database<br/><small>subnet IDs, SG in · endpoint out</small>"]:::data
  end
  CNT["⑥ count<br/><small>resource[0] [1] [2] · remove [0] and [1] [2] shift → destroy and recreate</small>"]:::warn
  FE["⑦ for_each<br/><small>resource[&quot;a&quot;] [&quot;b&quot;] · keyed by a stable name · remove one, touch one</small>"]:::crit
  MOVED["⑧ moved block<br/><small>refactor into a module · zero destroys in the plan</small>"]:::n
  VER["⑨ versioning<br/><small>git tag v1.2.0 · source = ...?ref=v1.2.0</small>"]:::n
  TST["⑩ tflint · checkov · terraform test<br/><small>clean, or every exception in an ADR</small>"]:::warn
  DEV ==> NET ==> COMP ==> DB
  PROD ==> NET
  CNT -.->|"the bug, BF-34"| FE
  FE --> NET
  MOVED -.-> COMP
  VER -.-> NET
  TST -.-> DEV
''',
 link="linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Anyone can write a main.tf. This week is about the shape of code a second engineer can consume, two environments that share it, and the one iteration mistake that deletes production subnets. The orange box is that mistake.",
 badges=[
  ("environments/dev", "A root module with its own state file and small, cheap inputs: one NAT, small instances. It calls the same three modules prod does."),
  ("environments/prod", "Same modules, different variable values, separate state. The test that you got this right: a change to a module shows up in both plans, and a change to an input shows up in one."),
  ("network module", "Takes a CIDR, returns subnet IDs. The caller never sees route tables or NAT gateways. That is the contract: variables in, outputs out, implementation private."),
  ("compute module", "Takes subnet IDs, returns the ASG and the ALB's DNS name. It knows nothing about how the subnets were made. Modules compose through outputs, never by reaching into each other."),
  ("database module", "Takes subnet IDs and a security group, returns an endpoint. The password is generated by RDS and lands in Secrets Manager; Terraform never holds it."),
  ("count", "Three subnets as resource[0], [1], [2]. Remove the first and Terraform sees [1] become [0] and [2] become [1]: it plans to modify two and destroy one. In production that is three subnets gone to remove one. BF-34, and you reproduce it before you fix it."),
  ("for_each", "The same three subnets keyed by a stable name: resource[\"a\"], [\"b\"], [\"c\"]. Remove \"a\" and the plan touches exactly one. The migration from count to for_each is a set of state mv commands, which you also do by hand."),
  ("moved block", "Pull a resource into a module and the address changes. A moved block says old address, new address, and the plan shows zero destroys. The exit criterion is that zero."),
  ("versioning", "Tag the module repository and pin the ref in the source string. An environment on v1.2.0 does not change when v1.3.0 lands. Unpinned modules are how prod changes when nobody touched it."),
  ("validation and testing", "tflint for mistakes the provider would reject, checkov for security findings, `terraform test` for behaviour. Clean, or every exception written down in an ADR with a reason."),
 ],
 close="Contract, composition, stable keys, and refactors that destroy nothing. By Saturday dev and prod both deploy from the same modules, and Alpha is a real project.",
)

F[12] = dict(
 title="OIDC: how a workflow gets AWS credentials with no secret anywhere",
 intro="Static keys in GitHub secrets are the most common amateur tell. The blue path replaces them with a short-lived token that AWS verifies by signature and by claim. Two roles, deliberately different, sit at the end.",
 body='''
  PR["① pull request or merge<br/><small>triggers the workflow</small>"]:::crit
  GH["② GitHub OIDC issuer<br/><small>token.actions.githubusercontent.com · signs a JWT</small>"]:::crit
  JWT["③ the token<br/><small>sub = repo:org/repo:ref:refs/heads/main · aud = sts.amazonaws.com · minutes, not days</small>"]:::data
  IDP["④ IAM OIDC provider<br/><small>trusts the issuer · one per account</small>"]:::crit
  STS["⑤ AssumeRoleWithWebIdentity<br/><small>signature checked · trust-policy condition on sub</small>"]:::crit
  RP["⑥ plan role<br/><small>read-only · any branch · PRs must plan</small>"]:::n
  RA["⑦ apply role<br/><small>pinned to environment:prod · protected, approval required</small>"]:::warn
  PIPE["⑧ the pipeline<br/><small>fmt → validate → tflint → checkov → plan → PR comment → approval → apply</small>"]:::crit
  ECR["⑨ container build<br/><small>multi-arch · ECR · semver tag + git SHA</small>"]:::data
  BP["⑩ branch protection<br/><small>all checks green · concurrency: cancel-in-progress false</small>"]:::n
  BAD["⑪ the dangerous trust policy<br/><small>sub = repo:org/repo:* lets any branch apply</small>"]:::warn
  PR ==> GH ==> JWT ==> IDP ==> STS ==> RA ==> PIPE
  STS --> RP --> PIPE
  PIPE -.-> ECR
  BP -.-> PR
  BAD -.-> STS
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Three hours of work this week read as three years of experience, and this is the picture of it. No access key exists. A workflow proves who it is with a signed token, and AWS decides what that identity may do. Follow the blue path, then look at the two roles.",
 badges=[
  ("pull request or merge", "The workflow starts with a context: which repository, which branch or environment, which event. That context is about to become the identity."),
  ("GitHub OIDC issuer", "GitHub runs an OpenID Connect issuer. On request, it signs a JSON Web Token with its private key and publishes the public key at a well-known URL. Anyone can verify; only GitHub can sign."),
  ("the token", "The claims are the whole story. `sub` says repo, and ref or environment. `aud` says who the token is for: sts.amazonaws.com. It expires in minutes. There is nothing in it worth stealing for long."),
  ("IAM OIDC provider", "One per AWS account, pointing at GitHub's issuer. This is AWS agreeing to check signatures from that issuer. It grants nothing by itself."),
  ("AssumeRoleWithWebIdentity", "The workflow hands the token to STS. STS verifies the signature against the published key, then evaluates the role's trust policy against the claims. The condition on `sub` is the access control. STS returns temporary credentials, and the job runs."),
  ("plan role", "Read-only. Trusted for any branch, because a pull request from any branch must be able to produce a plan. Read-only means a malicious PR can look but not touch."),
  ("apply role", "Trusted only for `environment:prod`, a GitHub environment with required reviewers. Merging is not enough; a human approves the deployment, and only then does a token with that claim exist."),
  ("the pipeline", "fmt, validate, tflint, checkov, plan, a comment on the PR with the plan, approval, apply. Cheap checks first, so a formatting error does not spend a plan. The plan comment is what the reviewer actually reads."),
  ("container build", "Multi-arch, pushed to ECR with two tags: a semver for humans and the git SHA for provenance. Week 18 signs the digest; this is where the digest is born."),
  ("branch protection", "Every check green before merge. The concurrency group has cancel-in-progress false, because cancelling an apply halfway through is how you get a half-built environment."),
  ("the dangerous trust policy", "`repo:org/repo:*` matches every branch and every PR. On the plan role it is fine. On the apply role it means anyone who can push a branch can deploy to production. Say this in the interview; it is the question they ask."),
 ],
 close="So: no key exists, identity is a signed claim, and the claim decides the role. The exit criterion is a grep for AKIA that returns nothing, in the tree and in the history.",
)

F[13] = dict(
 title="Project Alpha as a reviewer sees it",
 intro="Shipping is a skill. The figure is the gate: one command in a clean account produces a working three-tier environment, delivered by a pipeline with no static credentials, with the documentation that lets a stranger believe it.",
 body='''
  ACCT["① a clean AWS account<br/><small>nothing in it · the only honest test</small>"]:::crit
  CMD["② one command<br/><small>terraform apply · from the README, no tribal knowledge</small>"]:::crit
  subgraph OUT["What appears"]
    direction LR
    NET["③ network<br/><small>VPC · 2 AZs · 3 tiers</small>"]:::crit
    CMP["④ compute<br/><small>ALB → ASG · IMDSv2</small>"]:::crit
    DBM["⑤ database<br/><small>RDS Multi-AZ · secret never in Terraform</small>"]:::data
    OBS["⑥ observability<br/><small>symptom alarms · dashboard</small>"]:::n
  end
  CI["⑦ delivery<br/><small>plan on PR · apply on merge · OIDC · zero static credentials</small>"]:::crit
  STATE["⑧ state<br/><small>remote · versioned · locked</small>"]:::data
  ENV["⑨ dev and prod<br/><small>same modules · different inputs</small>"]:::n
  DOCS["⑩ documentation<br/><small>README · diagram · ADRs · cost table · what broke</small>"]:::crit
  NUM["⑪ measured numbers<br/><small>ASG recovery · RDS failover · apply time · monthly cost</small>"]:::warn
  TD["⑫ teardown verified<br/><small>destroy to zero · bill checked</small>"]:::warn
  TFA["⑬ Terraform Associate prep<br/><small>15 h · HCP Terraform objectives are the gap</small>"]:::mut
  ACCT ==> CMD ==> NET ==> CMP ==> DBM
  CMP --> OBS
  CI ==> CMD
  CI --> STATE
  ENV -.-> CMD
  DBM ==> DOCS
  NUM -.-> DOCS
  CMD -.-> TD
  DOCS -.-> TFA
''',
 link="linkStyle 0,1,2,3,5,8 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="This is Alpha the way a hiring manager would review it. Not the code, the claims. Every box is a claim the README makes, and Thursday you prove the whole picture in an account that has nothing in it.",
 badges=[
  ("a clean AWS account", "Ideally a separate account. Otherwise destroy everything, empty the state bucket, and start from nothing. Any leftover resource makes the test a lie."),
  ("one command", "The README says what to run, and that is all you run. If a step lives only in your head, write it down or automate it. This is the one-command claim, and Gate 3 is checking it literally."),
  ("network", "The week-6 VPC: two AZs, three tiers, data tier with no route out. Produced by the network module with a CIDR as its only required input."),
  ("compute", "The week-7 ALB in front of an auto-scaling group, instances on IMDSv2, no SSH port anywhere. Produced by the compute module."),
  ("database", "RDS Multi-AZ. The password is generated by RDS and stored in Secrets Manager; Terraform never sees the value and it is not in state in the clear."),
  ("observability", "The module you finish Monday and Tuesday: alarms on symptoms, 5xx rate and latency, not on causes, and a dashboard that shows them. Week 20 goes deeper; this is enough to be honest."),
  ("delivery", "Plan on every pull request, apply on merge after approval, both through the week-12 OIDC roles. The grep for AKIA returns nothing. That is the single most credible line in the project."),
  ("state", "Remote in S3, versioned, locked during apply. A reviewer who asks what happens when two people apply at once gets an answer."),
  ("dev and prod", "Two environments from the same modules with different inputs. Prod has a NAT per AZ and bigger instances; dev has one NAT and small ones. The difference is a variables file."),
  ("documentation", "A README with the one command, an architecture diagram, ADRs for the decisions you would be asked about, a cost table, and a section called what broke. The last one is read more than any other."),
  ("measured numbers", "ASG recovery time, RDS failover downtime, how long the apply takes, what a month costs. Your numbers, from Thursday's run. Numbers are what turn a project into a story."),
  ("teardown verified", "Destroy, then check the bill the next day. A project that costs money after it is done is not done."),
  ("Terraform Associate prep", "Fifteen hours is enough, and most of it goes to the one domain a self-taught project never touches: HCP Terraform workspaces, VCS-driven runs, remote execution. Book the exam for Monday."),
 ],
 close="One command, a clean account, no credentials, numbers you measured, and a document a stranger can follow. Ship it with three known rough edges rather than polish it into week 16.",
)

F[14] = dict(
 title="What happens when you kubectl apply a Deployment",
 intro="The control plane is a loop of controllers watching one database. Follow the blue path from your terminal to a running container, then the dashed path back out through a Service and the Ingress.",
 body='''
  K["① kubectl apply<br/><small>a Deployment manifest · REST to the API</small>"]:::crit
  API["② kube-apiserver<br/><small>authn → authz → admission · the only thing that talks to etcd</small>"]:::crit
  ETCD["③ etcd<br/><small>the desired state · every object, every version</small>"]:::data
  CM["④ controller manager<br/><small>Deployment → ReplicaSet → N Pods</small>"]:::crit
  SCH["⑤ scheduler<br/><small>picks a node · resources, taints, affinity</small>"]:::crit
  KL["⑥ kubelet<br/><small>pulls the image · starts containers · Scheduled → Pulling → Pulled → Created → Started</small>"]:::crit
  POD["⑦ the pod<br/><small>one IP · containers share net and IPC</small>"]:::crit
  SVC["⑧ Service ClusterIP<br/><small>a stable VIP · kube-proxy iptables · endpoints = ready pods</small>"]:::n
  ING["⑨ Ingress<br/><small>ingressClassName: contour · host and path to Service</small>"]:::n
  CFG["⑩ ConfigMap · Secret<br/><small>mounted or env · a Secret is base64, not encryption</small>"]:::data
  FAIL["⑪ the three failures<br/><small>ImagePullBackOff · CrashLoopBackOff · Service with no endpoints</small>"]:::warn
  K ==> API ==> ETCD
  API ==> CM ==> SCH ==> KL ==> POD
  ING -.-> SVC -.-> POD
  CFG -.-> POD
  POD -.-> FAIL
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="four",
 open="This is the hinge week, and Wednesday you also send ten applications. The technical picture is one loop: everything you ask for is written to one database, and controllers keep making the world match it. Follow the blue line from your terminal to a running container.",
 badges=[
  ("kubectl apply", "kubectl turns a YAML file into an HTTP request to the API server. Nothing else in the cluster ever hears from you directly. `kubectl -v=8` shows the request if you want to see it."),
  ("kube-apiserver", "Three gates in order: who are you, may you do this, and admission, which can mutate or reject the object. Then it writes to etcd. It is the only component that talks to etcd, which is why it is the thing every other component watches."),
  ("etcd", "The desired state of everything, with history. On kind it is a static pod on the control-plane node. Lose etcd without a backup and the cluster forgets what it was supposed to run."),
  ("controller manager", "A Deployment controller sees a new Deployment and creates a ReplicaSet. The ReplicaSet controller sees it and creates N Pods. Each controller watches one kind of object and makes one kind of child. That is the whole design, repeated."),
  ("scheduler", "A pod with no node assigned is the scheduler's queue. It filters nodes by resources, taints, and affinity, scores the rest, and writes the choice back. Pending forever means the filter emptied the list, and `kubectl describe` says why."),
  ("kubelet", "The agent on the node sees a pod assigned to it, pulls the image, and starts the containers. The events read Scheduled, Pulling, Pulled, Created, Started. Watch them with `kubectl get events -w`."),
  ("the pod", "One IP address, shared by all containers in it, who also share network and IPC namespaces. That is why a sidecar can talk to the app on localhost. The week-4 namespaces, grouped."),
  ("Service", "A stable virtual IP. kube-proxy writes iptables rules that spread it across the pod IPs whose readiness probe passes. A Service with no endpoints means the selector matched nothing or nothing is ready."),
  ("Ingress", "Host and path rules pointing at Services, implemented by Contour on this cluster. Without `ingressClassName`, the controller ignores the resource and you get a 404 that looks like a routing bug."),
  ("ConfigMap and Secret", "Configuration and secrets, mounted as files or injected as environment. A Secret is base64 encoded, not encrypted; week 19 is where real secret handling lives."),
  ("the three failures", "ImagePullBackOff is the registry, the tag, or credentials. CrashLoopBackOff is the process exiting; read the previous container's logs. No endpoints is the selector or readiness. Diagnose all three from events and logs, before week 15 adds six more."),
 ],
 close="Write to one database, let controllers converge, and route in through a Service and an Ingress. By Saturday the week-4 Compose stack runs here. And Tuesday the applications go out, because the pipeline has a ten-week lag.",
)

F[15] = dict(
 title="Nine ways a pod fails to start, and where each one lives",
 intro="This is the decision tree from the week's blog post. Each branch is a phase you can read in one `kubectl get pods`, and each leaf names the command that proves it.",
 body='''
  P["① kubectl get pods<br/><small>read STATUS and RESTARTS first</small>"]:::crit
  PEND["② Pending<br/><small>never scheduled</small>"]:::warn
  CC["③ ContainerCreating<br/><small>scheduled, not started</small>"]:::warn
  RUNX["④ Running, restarting<br/><small>starts, then dies</small>"]:::warn
  RNR["⑤ Running, not Ready<br/><small>alive, no traffic</small>"]:::warn
  L1["⑥ insufficient resources<br/><small>requests too big · describe shows FailedScheduling</small>"]:::n
  L2["⑦ taint or affinity<br/><small>no node tolerates it</small>"]:::n
  L3["⑧ PVC unbound<br/><small>no StorageClass · wrong access mode</small>"]:::data
  L4["ImagePullBackOff<br/><small>tag · registry · pull secret</small>"]:::n
  L5["missing ConfigMap or Secret<br/><small>mount fails · describe says which</small>"]:::data
  L6["⑨ OOMKilled, exit 137<br/><small>memory over limit · killed, not throttled</small>"]:::warn
  L7["CrashLoopBackOff<br/><small>app exits · logs --previous</small>"]:::n
  L8["liveness probe<br/><small>too aggressive · restarts a healthy slow app · BF-44</small>"]:::warn
  L9["readiness probe failing<br/><small>endpoints empty · Service returns nothing</small>"]:::n
  RB["⑩ RBAC forbidden<br/><small>kubectl auth can-i · Role + RoleBinding</small>"]:::n
  QOS["⑪ QoS<br/><small>Guaranteed: requests = limits · Burstable · BestEffort evicted first</small>"]:::data
  P ==> PEND
  P ==> CC
  P ==> RUNX
  P ==> RNR
  PEND --> L1
  PEND --> L2
  PEND --> L3
  CC --> L4
  CC --> L5
  RUNX --> L6
  RUNX --> L7
  RUNX --> L8
  RNR --> L9
  P -.-> RB
  L6 -.-> QOS
''',
 link="linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Anyone can apply a manifest. What gets hired is diagnosing a broken cluster under time pressure while saying what you are thinking. This tree is the thing you say. The first word of STATUS picks the branch.",
 badges=[
  ("kubectl get pods", "Two columns tell you which branch: STATUS and RESTARTS. Pending and ContainerCreating have zero restarts and never ran. Running with climbing restarts is dying after it starts. Running with zero Ready is alive but excluded."),
  ("Pending", "The scheduler could not place it. `kubectl describe pod` shows a FailedScheduling event with the reason. There are three usual reasons, badges 6 to 8."),
  ("ContainerCreating", "It has a node but the kubelet cannot start it. Almost always the image or a volume. Describe shows which, in the events at the bottom."),
  ("Running, restarting", "The container starts and dies. The exit code and the previous container's logs tell you whether the app quit, the kernel killed it, or the probe did."),
  ("Running, not Ready", "The process is alive but the readiness probe fails, so the Service removes it from the endpoints. The app looks down from outside and looks fine from inside."),
  ("insufficient resources", "Requests larger than any node has free. On kind this is easy to trigger: ask for 100 CPUs. In production it is the usual Monday-morning cause."),
  ("taint or affinity", "Every node has a taint the pod does not tolerate, or an affinity rule nothing satisfies. Describe names the taint."),
  ("PVC unbound", "The claim is waiting for a volume that cannot be provisioned: no default StorageClass, or an access mode the class cannot give. Stateful pods stall here."),
  ("OOMKilled", "Exit code 137. Memory over the limit is killed instantly, where CPU over the limit is only throttled. That asymmetry is the exit criterion and the question interviewers love. Requests equal to limits makes the pod Guaranteed and last to be evicted."),
  ("RBAC forbidden", "Not a pod state, but it looks like one when a controller cannot create what it needs. `kubectl auth can-i --as` answers it in one line; a Role plus a RoleBinding fixes it."),
  ("QoS", "Guaranteed when every container's requests equal its limits. Burstable when requests are lower. BestEffort when there are none, and those die first under pressure."),
 ],
 close="Read the status, pick the branch, run the one command that proves the leaf, say it out loud. Friday you build five of these on demand; they are Gate 4, two weeks from now.",
)

F[16] = dict(
 title="IRSA: how a pod gets AWS credentials without any credentials",
 intro="The week-5 question again, how does a workload get cloud credentials without holding one, answered for a pod. The blue path is a token exchange. ArgoCD and the cost rule sit beside it.",
 body='''
  SA["① ServiceAccount<br/><small>annotation: eks.amazonaws.com/role-arn</small>"]:::crit
  WH["② pod identity webhook<br/><small>mutating admission · injects a token volume + two env vars</small>"]:::crit
  TOK["③ projected SA token<br/><small>signed by the cluster · aud sts.amazonaws.com · 86400 s · sub system:serviceaccount:ns:name</small>"]:::data
  OIDC["④ cluster OIDC issuer<br/><small>public discovery URL · publishes the signing keys</small>"]:::n
  IDP["⑤ IAM OIDC provider<br/><small>trusts this cluster's issuer</small>"]:::crit
  SDK["⑥ SDK in the pod<br/><small>AWS_ROLE_ARN · AWS_WEB_IDENTITY_TOKEN_FILE · nothing else</small>"]:::crit
  STS["⑦ AssumeRoleWithWebIdentity<br/><small>signature via discovery · trust policy matches sub</small>"]:::crit
  CRED["⑧ temporary credentials<br/><small>scoped to one role · rotated by the SDK</small>"]:::crit
  S3["⑨ one S3 bucket<br/><small>the role allows this bucket, nothing else</small>"]:::data
  BRK["⑩ four ways it breaks<br/><small>wrong sub in trust · missing annotation · wrong audience · provider not created</small>"]:::warn
  ARGO["⑪ ArgoCD<br/><small>pull-based · app-of-apps · sync within 3 min · selfHeal reverts manual change</small>"]:::n
  COST["⑫ cost rule<br/><small>control plane $0.10/h ≈ $73/mo · destroy every night</small>"]:::warn
  SA ==> WH ==> TOK ==> SDK ==> STS ==> CRED ==> S3
  OIDC --> IDP --> STS
  STS -.-> BRK
  ARGO -.-> SA
  COST -.-> ARGO
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="four",
 open="A pod reads an S3 bucket with no credentials mounted anywhere, and you can explain every hop. That sentence is the exit criterion and the blog post. Week 5 answered it for an instance, week 12 for a workflow. Same shape, third time.",
 badges=[
  ("ServiceAccount", "A Kubernetes ServiceAccount with one annotation: the ARN of the IAM role it may become. The annotation is a request, not a grant; AWS decides later."),
  ("pod identity webhook", "A mutating admission webhook sees a pod using that ServiceAccount and injects two things: a projected volume holding a token, and two environment variables naming the role and the token file. The pod spec you wrote did not have them; the one that runs does."),
  ("projected SA token", "The API server signs a short-lived JWT for the ServiceAccount: audience sts.amazonaws.com, subject system:serviceaccount, the namespace, and the name, expiring in a day. It is mounted as a file and refreshed before expiry."),
  ("cluster OIDC issuer", "Every EKS cluster has a public OIDC discovery URL that publishes the keys the tokens are signed with. That URL is what lets AWS verify a token it did not issue."),
  ("IAM OIDC provider", "In IAM, an identity provider pointing at the cluster's issuer. One per cluster. Forget to create it and badge 7 fails with an error that names nothing useful; that is one of the four breaks."),
  ("SDK in the pod", "The SDK's credential chain finds AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE and knows what to do. Nothing in the container image, nothing in a Secret. `env` inside the pod shows exactly two variables."),
  ("AssumeRoleWithWebIdentity", "STS fetches the signing keys from the discovery URL, verifies the token, then evaluates the role's trust policy against the claims. The condition is on `sub`: this namespace, this ServiceAccount. A wildcard here is the same mistake as week 12's wildcard branch."),
  ("temporary credentials", "Scoped to the one role, expiring in an hour, refreshed by the SDK automatically. `aws sts get-caller-identity` from inside the pod shows assumed-role and the role name."),
  ("one S3 bucket", "The role allows one bucket. The pod can list it and read it, and a second bucket returns AccessDenied. Least privilege is the proof, not the policy."),
  ("four ways it breaks", "Wrong subject in the trust policy, missing annotation on the ServiceAccount, wrong audience on the token, OIDC provider never created. Break each one on purpose and note what the error looks like; three of the four errors are unhelpful."),
  ("ArgoCD", "Pull-based delivery: ArgoCD watches Git and makes the cluster match. App-of-apps means one application that declares the others. A Git change syncs within three minutes, and selfHeal reverts a manual kubectl edit, which you demonstrate."),
  ("cost rule", "The control plane alone is about ten cents an hour, seventy-three dollars a month, before nodes and the load balancer. Two deliberate weeks with nightly teardown cost about fifteen dollars total. Run the teardown script every night this week."),
 ],
 close="Annotation, injection, token, exchange, credentials. The pod is who it is, and AWS believes it because of a signature, not a secret. Sunday: destroy everything and check the bill.",
)

F[17] = dict(
 title="The diagnostic ladder you narrate at Gate 4",
 intro="Consolidation is not rest. The figure is the method you say out loud for five broken clusters, under fifteen minutes each, plus the two decisions the week asks for: KCNA and the Bravo design.",
 body='''
  S1["① SYMPTOM<br/><small>what exactly · who is affected · since when</small>"]:::crit
  S2["② CHANGE<br/><small>what changed · resolves most real incidents</small>"]:::crit
  S3["③ HYPOTHESIS<br/><small>the cheapest test that kills the idea</small>"]:::crit
  S4["④ LAYERS<br/><small>app → container → pod → node → network → cloud → DNS · in order</small>"]:::crit
  S5["⑤ CONFIRM<br/><small>prove the root cause · not a correlation</small>"]:::crit
  S6["⑥ FIX<br/><small>the smallest change</small>"]:::crit
  S7["⑦ PREVENT<br/><small>impossible, or at least loud</small>"]:::crit
  MAP["⑧ scenario-to-command map<br/><small>describe · logs --previous · get events · get endpoints · auth can-i · top</small>"]:::data
  GATE["⑨ ★ Gate 4<br/><small>5 scenarios · under 15 min each · narrated · plus Deployment, Service, Ingress, RBAC from memory</small>"]:::warn
  KC["⑩ KCNA decision<br/><small>passed comfortably → skip, bank $250 and 25 h toward CKA</small>"]:::mut
  BR["⑪ ⚑ Bravo design first<br/><small>architecture + STRIDE threat model before any code</small>"]:::n
  S1 ==> S2 ==> S3 ==> S4 ==> S5 ==> S6 ==> S7
  MAP -.-> S4
  S7 --> GATE
  GATE -.-> KC
  GATE -.-> BR
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="Scattered knowledge becomes retrievable under pressure this week, which is the only form that matters in an interview. The figure is the seven words you say, in order, every time something is broken. Then the gate, then two decisions.",
 badges=[
  ("symptom", "Say exactly what is broken, who it affects, and since when. Not 'the site is down' but 'checkout returns 503 for every user since 09:40'. Precision here halves the search."),
  ("change", "What changed? A deploy, a config edit, a node replaced, a certificate expiring. Most real incidents are answered by this question alone, and juniors skip it to go straight to the exciting layer."),
  ("hypothesis", "Name a cause and the cheapest test that would disprove it. A ten-second `kubectl get endpoints` beats a ten-minute log dive. Cheap tests first, always."),
  ("layers", "App, container, pod, node, network, cloud, DNS. Walk them in order. The discipline is not skipping to the one you find interesting; the order is what makes you fast when you are nervous."),
  ("confirm", "Prove it. A restart that fixed the symptom is a correlation. A log line that names the cause is a confirmation. Interviewers notice the difference."),
  ("fix", "The smallest change that resolves it. A rollback is a fix. A rebuild is a last resort you announce as one."),
  ("prevent", "What makes this impossible, or at least loud, next time? A probe, a limit, a policy, an alert. The incident journal entry ends with this line."),
  ("scenario-to-command map", "Each scenario type has a first command. Describe for scheduling and events, logs --previous for crashes, get endpoints for a dead Service, auth can-i for RBAC, top for resources. Internalize the map so your hands move while you talk."),
  ("Gate 4", "Wednesday, for real: five scenarios, each under fifteen minutes, narrated. Then Deployment, Service, Ingress, and a Role with its binding, written from memory. Rehearse Tuesday with a timer."),
  ("KCNA decision", "If the gate was comfortable, skip KCNA and bank the money and the hours toward the CKA, which is the one hiring managers filter on. If the gate was a struggle, take KCNA as a forcing function, knowing that is what you are buying."),
  ("Bravo design first", "Friday: draw the Bravo architecture and write the STRIDE threat model before a line of code exists. Weeks 18 to 21 build controls against named threats, not against a vague sense of security."),
 ],
 close="Seven words, in order, out loud. That is the skill the gate measures and the skill the interview measures. Everything else this week is deciding what to spend the next month on.",
)

F[18] = dict(
 title="The pipeline that refuses",
 intro="Supply chain security is what makes you beat other juniors. The blue path is the pipeline; the orange boxes are where it says no, with evidence. Every gate hard-fails, cheapest first.",
 body='''
  C["① commit<br/><small>the PR</small>"]:::crit
  GL["② gitleaks<br/><small>secrets · full history</small>"]:::warn
  SG["③ Semgrep<br/><small>SAST · your own rule: no hardcoded DB URL</small>"]:::warn
  TF["④ Trivy fs<br/><small>SCA · fails on fixable HIGH and CRITICAL</small>"]:::warn
  BLD["⑤ build<br/><small>distroless · non-root · read-only · before/after size and CVE count recorded</small>"]:::crit
  TI["⑥ Trivy image<br/><small>the shipped layers, not the source</small>"]:::warn
  SB["⑦ syft SBOM<br/><small>SPDX · attached to the image as an attestation</small>"]:::data
  CS["⑧ cosign sign<br/><small>keyless · signs the DIGEST, not the tag · Fulcio cert · Rekor log</small>"]:::crit
  ECR["⑨ registry<br/><small>image + signature + SBOM, by digest</small>"]:::data
  ADM["⑩ admission verify<br/><small>Kyverno verifyImages · unsigned image refused</small>"]:::warn
  EV["⑪ evidence/<br/><small>screenshot: the CVE blocked · screenshot: the unsigned refusal</small>"]:::n
  SL["⑫ SLSA<br/><small>provenance levels · which control would have caught each real attack</small>"]:::mut
  C ==> GL ==> SG ==> TF ==> BLD ==> TI ==> SB ==> CS ==> ECR ==> ADM
  TF -.-> EV
  ADM -.-> EV
  CS -.-> SL
''',
 link="linkStyle 0,1,2,3,4,5,6,7,8 stroke:#2f6fb8,stroke-width:2px",
 minutes="four",
 open="Almost no candidate at this level can talk credibly about supply chain security, and hiring managers have been told to care since Log4Shell. This is a pipeline that refuses, and the two refusals come with screenshots. Follow the line; stop at every orange box.",
 badges=[
  ("commit", "A pull request opens. Everything to the right runs before a human looks at it, and the cheapest checks run first so a leaked key fails in seconds, not after a ten-minute build."),
  ("gitleaks", "Secrets, scanned across the full history, because a key deleted in the next commit is still in the repository. The same binary, the same version, runs in the pre-commit hook and in CI."),
  ("Semgrep", "Static analysis on the source. You write one rule yourself, no hardcoded database URL, so you understand that a scanner is a pattern someone chose, not an oracle."),
  ("Trivy on the filesystem", "Dependency scanning against the lockfiles. The gate fails on fixable HIGH and CRITICAL. Fixable is the key word: an unfixable finding goes to an exception with an expiry and an owner, which is the week-19 control narrative."),
  ("build", "Distroless base, non-root user, read-only filesystem. Measure the image size and CVE count before and after and write both numbers down. No shell in the image means no `kubectl exec sh`, for you and for an attacker."),
  ("Trivy on the image", "Scan what ships, not what you compiled from. Base image CVEs live here, and they are most of the count."),
  ("syft SBOM", "A software bill of materials in SPDX, attached to the image as an attestation. When the next Log4Shell lands, this is how you answer 'are we affected' in minutes instead of days."),
  ("cosign sign", "Keyless: the workflow's OIDC identity gets a short-lived certificate from Fulcio, the signature is recorded in the Rekor transparency log, and what is signed is the digest. A tag can be moved; a digest cannot."),
  ("registry", "The image, its signature, and its SBOM, all addressed by digest. Pulling by tag is convenience; verifying by digest is the control."),
  ("admission verify", "Kyverno's verifyImages checks the signature at admission against the expected identity. An unsigned image, or one signed by the wrong workflow, is refused before it runs. Push one on purpose and capture the refusal."),
  ("evidence", "Two screenshots in the repository: a deliberately introduced critical CVE blocking the build, and an unsigned image refused at admission. Evidence is what separates a control from a claim, and Gate 5 asks for it live."),
  ("SLSA", "The provenance levels give you vocabulary: who built it, from what, on what builder, with what guarantees. Thursday's case studies ask one question of each real attack: which of these boxes would have caught it."),
 ],
 close="Scan the source, harden the build, scan the image, describe it, sign the digest, verify at the door. Then prove it twice with a screenshot. That is the month that beats other juniors.",
)
