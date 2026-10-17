#!/usr/bin/env python3
"""Render Figure W.1 for every week into curriculum/week-WW/content/, with the spoken script.

Same visual language as the project and setup figures (generate-figures.py): vendor
icons, nested boundaries that carry a fact, two-line captions, crimson for the path
to follow first, dashed gray for context. Each node caption starts with a crimson
badge ① … ⑭, and content/FIGURE.md holds the script to say for each badge.

The specs live in week_figures/ in a small Mermaid-shaped DSL so they stay readable:

    subgraph ID["title"] … end        a boundary (style from CLUSTER_STYLE, else enclosure/zone)
    ID["① title<br/><small>detail</small>"]:::class   a node; class crit | warn | data | mut | n
    A ==> B ==> C                     the path to follow first (crimson)
    A --> B                           a normal relationship
    A -.-> B · A -.->|"label"| B      context, dashed

ICONS maps each node id to an icon class, per week.

    pip install diagrams          # also needs graphviz on PATH
    ./generate-week-figures.py                 # all 26
    ./generate-week-figures.py --only 14       # one week
    ./generate-week-figures.py --no-docs       # images only, leave FIGURE.md and the README alone
"""
from __future__ import annotations

import argparse
import html
import importlib.util
import os
import re
import sys
import textwrap

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("genfig", os.path.join(_HERE, "generate-figures.py"))
gf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gf)                       # sets sys.path, chdir(~), imports diagrams

from diagrams import Cluster, Diagram, Edge  # noqa: E402
import diagrams.aws.compute as awsc, diagrams.aws.cost as awscost, diagrams.aws.database as awsd  # noqa: E402
import diagrams.aws.general as awsg, diagrams.aws.integration as awsi, diagrams.aws.management as awsm  # noqa: E402
import diagrams.aws.network as awsn, diagrams.aws.security as awss, diagrams.aws.storage as awsst  # noqa: E402
import diagrams.generic.device as gdev, diagrams.generic.network as gnet, diagrams.generic.os as gos  # noqa: E402
import diagrams.generic.storage as gsto  # noqa: E402
import diagrams.k8s.clusterconfig as kcc, diagrams.k8s.compute as kc, diagrams.k8s.controlplane as kcp  # noqa: E402
import diagrams.k8s.infra as ki, diagrams.k8s.network as kn, diagrams.k8s.others as ko  # noqa: E402
import diagrams.k8s.podconfig as kpc, diagrams.k8s.rbac as kr, diagrams.k8s.storage as ks  # noqa: E402
import diagrams.onprem.certificates as ocert, diagrams.onprem.ci as oci, diagrams.onprem.client as ocl  # noqa: E402
import diagrams.onprem.compute as ocomp, diagrams.onprem.container as ocont, diagrams.onprem.database as odb  # noqa: E402
import diagrams.onprem.dns as odns, diagrams.onprem.gitops as ogit, diagrams.onprem.iac as oiac  # noqa: E402
import diagrams.onprem.monitoring as omon, diagrams.onprem.network as onet, diagrams.onprem.security as osec  # noqa: E402
import diagrams.onprem.tracing as otr, diagrams.onprem.vcs as ovcs  # noqa: E402
import diagrams.programming.flowchart as fc, diagrams.programming.language as lang  # noqa: E402

REG = {}
for mod in (awsc, awscost, awsd, awsg, awsi, awsm, awsn, awss, awsst, gdev, gnet, gos, gsto, kcc, kc, kcp, ki, kn, ko,
            kpc, kr, ks, ocert, oci, ocl, ocomp, ocont, odb, odns, ogit, oiac, omon, onet, osec, otr, ovcs, fc, lang):
    for name in dir(mod):
        obj = getattr(mod, name)
        if isinstance(obj, type) and name[0].isupper():
            REG.setdefault(f"{mod.__name__.split('.')[-2]}.{mod.__name__.split('.')[-1]}.{name}", obj)
            REG.setdefault(name, obj)             # short name wins only if unique-first

def icon(name):
    if name in REG:
        return REG[name]
    raise KeyError(f"no icon class {name!r}")

# ---------------------------------------------------------------- per-week icon maps ----
ICONS = {
 1: dict(A1="Bash", A2="LinuxGeneral", A3="Decision", A4="Storage", A5="PredefinedProcess", A6="Document", A7="Vault", G1="Git", G2="Github", BF="Action"),
 2: dict(U="Client", D="Coredns", C="Subnet", T="Router", H="Server", S1="LinuxGeneral", S2="Document", S3="Vault", S4="Storage", B="Document"),
 3: dict(CL="Client", DN="Coredns", RT="Router", FW="Firewall", NG="Nginx", UP="Switch", AP="Python", AC="LetsEncrypt", TF="Vault", GT="Git"),
 4: dict(B1="Docker", B2="Docker", B3="Storage", R1="LinuxGeneral", R2="PredefinedProcess", R3="Limits", C1="Python", C2="PostgreSQL", C3="Nginx", C4="LinuxGeneral", EX="Decision"),
 5: dict(E1="User", E2="IAMPermissions", E3="Organizations", E4="IAM", E5="Action", I1="IAMRole", I2="EC2", I3="Vault", I4="Python", X="IAMRole", G="Budgets"),
 6: dict(NET="InternetAlt1", IG="InternetGateway", NAT="NATGateway", BAS="EC2", A="EC2", D="RDS", EP="Endpoint", FL="VPCFlowLogs", SG="Firewall", S3="S3"),
 7: dict(U="Users", R53="Route53", ALB="ALB", TG="Switch", I1="EC2", I2="EC2", M1="Action", P="RDS", S="RDS", RR="RDS", M2="Action", DDB="Dynamodb", LAM="Lambda"),
 8: dict(API="Client", SQS="SQS", LAM="Lambda", DLQ="SQS", KMS="KMS", SEC="SecretsManager", CW="CloudwatchAlarm", SNS="SNS", CT="Cloudtrail", CF="CloudFront", ORG="Organizations"),
 9: dict(E1="Document", CAT="Decision", WK="Action", RB="Server", AN="MultipleDocuments", E2="Document", E3="Document", WB="Action", GATE="StartEnd", SUN="Delay", BK="Action"),
 10: dict(CFG="Document", INIT="Terraform", PLAN="Terraform", ST="S3", APPLY="Terraform", RES="EC2", DRIFT="Decision", IMP="Action", MV="Action", CORR="Action", ALPHA="Github"),
 11: dict(DEV="Terraform", PROD="Terraform", NET="VPC", COMP="AutoScaling", DB="RDS", CNT="Action", FE="Action", MOVED="Action", VER="Git", TST="Trivy"),
 12: dict(PR="Github", GH="GithubActions", JWT="Document", IDP="IAM", STS="IAMRole", RP="IAMRole", RA="IAMRole", PIPE="GithubActions", ECR="ECR", BP="Github", BAD="Decision"),
 13: dict(ACCT="Organizations", CMD="Terraform", NET="VPC", CMP="AutoScaling", DBM="RDS", OBS="Cloudwatch", CI="GithubActions", STATE="S3", ENV="Terraform", DOCS="Document", NUM="Action", TD="Action", TFA="Document"),
 14: dict(K="Client", API="APIServer", ETCD="ETCD", CM="ControllerManager", SCH="Scheduler", KL="Kubelet", POD="Pod", SVC="Service", ING="Ingress", CFG="ConfigMap", FAIL="Decision"),
 15: dict(P="Client", PEND="Pod", CC="Pod", RUNX="Pod", RNR="Pod", L1="Limits", L2="Node", L3="PVC", L4="Docker", L5="ConfigMap", L6="Limits", L7="Pod", L8="Decision", L9="Service", RB="Role", QOS="Quota"),
 16: dict(SA="ServiceAccount", WH="APIServer", TOK="Document", OIDC="EKS", IDP="IAM", SDK="Python", STS="IAMRole", CRED="Vault", S3="S3", BRK="Decision", ARGO="Argocd", COST="Budgets"),
 17: dict(S1="Decision", S2="Document", S3="Decision", S4="PredefinedProcess", S5="Action", S6="Action", S7="StartEnd", MAP="MultipleDocuments", GATE="Action", KC="Decision", BR="Document"),
 18: dict(C="Github", GL="Vault", SG="GithubActions", TF="Trivy", BLD="Docker", TI="Trivy", SB="Document", CS="Vault", ECR="ECR", ADM="APIServer", EV="MultipleDocuments", SL="Document"),
 19: dict(PL="Document", CT="GithubActions", PSS="APIServer", KYV="CRD", FP="Decision", POD="Pod", NP="NetworkPolicy", ESO="Secret", FAL="Action", CN="Document"),
 20: dict(APP="Python", SM="Prometheus", PQ="Prometheus", RR="Document", SLI="Action", SLO="Action", BR="Action", AM="Action", PG="Mobile", GF="Grafana", OT="Jaeger", CARD="Decision"),
 21: dict(DET="Prometheus", DEC="Users", MIT="Action", DIA="Decision", RES="Action", PM="Document", AI="MultipleDocuments", RB="Document", CH="Action", DORA="Grafana", G5="StartEnd"),
 22: dict(DEV="User", PAIN="Decision", SY="Document", SCH="Action", TPL="Github", REG="Terraform", ROAD="Server", NG="Document", MET="Grafana", BB="Decision", BRIEF="Document"),
 23: dict(PR="Github", VAL="GithubActions", PLAN="Terraform", COST="CostExplorer", MRG="Git", NS="NetworkPolicy", IAM="IAMRole", ECR="ECR", DNS="Route53", OBS="Grafana", RUN="Pod", DEL="Action", EX="MultipleDocuments"),
 24: dict(GS="Document", CR="Document", TR="Document", EH="Document", ADR="MultipleDocuments", RBK="MultipleDocuments", DIA="Action", ST="User", VID="Action", RM="Github", PIN="Github", KC="Decision"),
 25: dict(IJ="MultipleDocuments", PJ="Github", BL="Document", STAR="Document", EXP="Action", SD="Action", LIVE="Bash", Q="Document", MOCK="Users", REV="Action", APP="Client"),
 26: dict(APP="Client", INT="Users", G6="StartEnd", MOCK="Users", NETW="Users", BLD="Github", RET="Document", PLAN="Document", LAG="Delay", GATES="MultipleDocuments"),
}
# Boundary styles that differ from the default (top-level = enclosure, nested = zone).
CLUSTER_STYLE = {
 1: dict(HOST="boundary", GIT="rounded"), 2: dict(SRV="rounded"), 4: dict(STACK="tier"), 5: dict(INST="tier"),
 6: dict(VPC="boundary", DAT="tier"), 7: dict(ASG="zone", RDS="tier"), 8: dict(K="tier"), 11: dict(MOD="tier"),
 13: dict(OUT="tier"), 19: dict(TFP="zone", ADM="enclosure", NET="zone", SEC="tier", RT="zone"),
 22: {}, 23: dict(GEN="tier"), 25: dict(SRC="tier", KIT="enclosure"),
}
RANKSEP = {6: "0.7", 15: "0.6", 19: "0.8", 23: "0.8"}
DIRECTION = {15: "TB"}   # a decision tree reads top-down; everything else is a left-to-right path

# ---------------------------------------------------------------- style ----
INK, MUTED, CRIMSON = "#2d3436", "#7a8288", "#c7254e"
TITLE_COLOR = {"crit": "#1b3a5c", "warn": "#8a3a1e", "data": INK, "mut": MUTED, "n": INK}
# The icon is anchored at the TOP of a taller node box, so the three-line caption has
# the bottom 0.8in to itself instead of overlapping the icon (imagepos needs Graphviz >= 2.44).
NODE = {**gf.NODE, "labelloc": "b", "height": "2.05", "imagepos": "tc"}

def caption(badge, title, detail, cls):
    t = html.escape(title, quote=False)
    rows = [f'<TR><TD><FONT POINT-SIZE="11" COLOR="{CRIMSON}"><B>{badge}</B></FONT> '
            f'<FONT POINT-SIZE="10" COLOR="{TITLE_COLOR[cls]}">{"<B>" if cls == "crit" else ""}{t}{"</B>" if cls == "crit" else ""}</FONT></TD></TR>'
            if badge else
            f'<TR><TD><FONT POINT-SIZE="10" COLOR="{TITLE_COLOR[cls]}">{t}</FONT></TD></TR>']
    for line in textwrap.wrap(detail, 34)[:3] if detail else []:
        rows.append(f'<TR><TD><FONT POINT-SIZE="8" COLOR="{MUTED}">{html.escape(line, quote=False)}</FONT></TD></TR>')
    return '<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0" CELLPADDING="1">' + "".join(rows) + '</TABLE>>'

# ---------------------------------------------------------------- the DSL parser ----
NODE_RE = re.compile(r'^(\w+)\["(.*)"\](?::::(\w+))?$')
SUB_RE = re.compile(r'^subgraph (\w+)\["(.*)"\]$')
EDGE_TOK = re.compile(r'\s*(==>|-->|-\.->)(?:\|"([^"]*)"\|)?\s*')
CIRCLED = "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭"

def unhtml(s):
    s = s.replace("&quot;", '"').replace("&nbsp;", " ")
    return re.sub(r"<[^>]+>", "", s).strip()

def parse(body):
    """Returns (tree, edges). tree: list of ('node', id, label, cls) | ('cluster', id, title, children)."""
    root, stack, edges = [], [], []
    for raw in body.splitlines():
        line = raw.strip()
        if not line or line.startswith("direction") or line.startswith("linkStyle"):
            continue
        m = SUB_RE.match(line)
        if m:
            node = ("cluster", m.group(1), m.group(2), [])
            (stack[-1][3] if stack else root).append(node); stack.append(node); continue
        if line == "end":
            stack.pop(); continue
        m = NODE_RE.match(line)
        if m:
            (stack[-1][3] if stack else root).append(("node", m.group(1), m.group(2), m.group(3) or "n")); continue
        # an edge chain
        parts = EDGE_TOK.split(line)
        ids = parts[0::3]; ops = parts[1::3]; labels = parts[2::3]
        for i, op in enumerate(ops):
            edges.append((ids[i].strip(), ids[i + 1].strip(), op, labels[i]))
    return root, edges

def split_label(label):
    head, _, tail = label.partition("<br/>")
    head = unhtml(head)
    badge = head[0] if head and head[0] in CIRCLED else ""
    title = head[1:].strip() if badge else head
    return badge, title, unhtml(tail)

# ---------------------------------------------------------------- build ----
def frame(week, cid, title, depth):
    style = CLUSTER_STYLE.get(week, {}).get(cid) or ("enclosure" if depth == 0 else "zone")
    return getattr(gf, style)(unhtml(title))

def build(week, spec, out_dir, slug):
    tree, edges = parse(spec["body"])
    nodes = {}
    def emit(items, depth):
        for it in items:
            if it[0] == "cluster":
                with Cluster(**frame(week, it[1], it[2], depth)):
                    emit(it[3], depth + 1)
            else:
                _, nid, label, cls = it
                badge, title, detail = split_label(label)
                nodes[nid] = icon(ICONS[week][nid])(caption(badge, title, detail, cls))
    path = os.path.join(out_dir, f"figure-{week}.1-{slug}")
    with Diagram("", filename=path, show=False, direction=DIRECTION.get(week, "LR"), outformat=["png", "svg"],
                 graph_attr={**gf.GRAPH, "nodesep": "0.85", "ranksep": RANKSEP.get(week, "0.9")},
                 node_attr=NODE, edge_attr=gf.EDGE):
        emit(tree, 0)
        for a, b, op, label in edges:
            style = gf.RED if op == "==>" else gf.SOLID if op == "-->" else gf.GREY
            kw = dict(style)
            if label:
                kw["label"] = label
            nodes[a] >> Edge(**kw) >> nodes[b]
    return path

# ---------------------------------------------------------------- docs ----
def slugify(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return "-".join(s.split("-")[:6])

def write_docs(week, spec, slug, content_dir, readme):
    png = f"figure-{week}.1-{slug}.png"
    walk = [f"- **Open.** “{spec['open']}”"]
    for i, (title, quote) in enumerate(spec["badges"]):
        walk.append(f"- **{CIRCLED[i]} {title}.** “{quote}”")
    walk.append(f"- **Close.** “{spec['close']}”")
    n = len(spec["badges"])
    fig = (f"# Figure {week}.1 — {spec['title']}\n\n"
           f"> Week {week} · badges ① to {CIRCLED[n-1]} · about {spec['minutes']} minutes at a normal pace. "
           f"Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.\n\n"
           f"![Figure {week}.1 — {spec['title']}]({png})\n\n{spec['intro']}\n\n"
           f"## What to say, badge by badge\n\n" + "\n".join(walk) + "\n\n"
           f"## Use it\n\n- Read the figure before the day plan. Say the script out loud on Friday with the file closed.\n"
           f"- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.\n"
           f"- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:\n\n"
           f"```bash\npython3 ../../_shared/diagrams/generate-week-figures.py --only {week}\n```\n")
    with open(os.path.join(content_dir, "FIGURE.md"), "w", encoding="utf-8") as f:
        f.write(fig)
    section = (f"## The week in one figure\n\n"
               f"**Figure {week}.1 — {spec['title']}.** {spec['intro']}\n\n"
               f"![Figure {week}.1 — {spec['title']}](content/{png})\n\n"
               f"**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each "
               f"of the {n} badges, about {spec['minutes']} minutes. Read the figure before the day plan; say the script on Friday.\n\n---\n\n")
    text = open(readme, encoding="utf-8").read()
    m = re.search(r"## The week in one figure\n.*?\n---\n\n", text, re.S)
    text = text[:m.start()] + section + text[m.end():] if m else re.sub(r"^## ", section + "## ", text, count=1, flags=re.M)
    with open(readme, "w", encoding="utf-8") as f:
        f.write(text)

def load_specs():
    specs = {}
    pkg = os.path.join(_HERE, "week_figures")
    for fn in sorted(os.listdir(pkg)):
        if fn.startswith("weeks_") and fn.endswith(".py"):
            s = importlib.util.spec_from_file_location(fn[:-3], os.path.join(pkg, fn))
            m = importlib.util.module_from_spec(s); s.loader.exec_module(m); specs.update(m.F)
    return specs

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", type=int)
    ap.add_argument("--no-docs", action="store_true", help="render images only")
    args = ap.parse_args()
    root = os.path.abspath(os.path.join(_HERE, "..", ".."))
    for week, spec in sorted(load_specs().items()):
        if args.only and args.only != week:
            continue
        wdir = os.path.join(root, f"week-{week:02d}")
        content = os.path.join(wdir, "content"); os.makedirs(content, exist_ok=True)
        slug = slugify(spec["title"])
        for old in os.listdir(content):                 # one figure per week: drop stale renders
            if old.startswith(f"figure-{week}.1-") and not old.startswith(f"figure-{week}.1-{slug}."):
                os.remove(os.path.join(content, old))
        build(week, spec, content, slug)
        if not args.no_docs:
            write_docs(week, spec, slug, content, os.path.join(wdir, "README.md"))
        print(f"  week {week:2d} -> week-{week:02d}/content/figure-{week}.1-{slug}.png")
    return 0

if __name__ == "__main__":
    sys.exit(main())
