#!/usr/bin/env python3
"""Render the lab-platform and guardrail figures for curriculum/_setup/ARCHITECTURE.md.

Same visual language as generate-figures.py (which draws the three project
architectures): vendor icons, nested boundaries that each carry a fact, two-line
captions, crimson for the one path the reader should follow first, dashed gray
for context. The style helpers are imported from that script so there is one
definition of the look.

    pip install diagrams          # also needs graphviz on PATH
    ./generate-setup-figures.py                 # all ten figures
    ./generate-setup-figures.py --only 4        # one figure
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("genfig", os.path.join(_HERE, "generate-figures.py"))
gf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gf)                       # sets sys.path, chdir(~), imports diagrams

from diagrams import Cluster, Diagram, Edge  # noqa: E402
from diagrams.aws.compute import EC2  # noqa: E402
from diagrams.aws.cost import Budgets  # noqa: E402
from diagrams.aws.integration import EventbridgeScheduler  # noqa: E402
from diagrams.aws.management import CloudwatchLogs  # noqa: E402
from diagrams.aws.network import Endpoint, InternetGateway  # noqa: E402
from diagrams.aws.security import IAMRole  # noqa: E402
from diagrams.aws.storage import S3  # noqa: E402
from diagrams.gcp.compute import ComputeEngine  # noqa: E402
from diagrams.gcp.devtools import Scheduler  # noqa: E402
from diagrams.gcp.network import FirewallRules  # noqa: E402
from diagrams.gcp.operations import Logging  # noqa: E402
from diagrams.gcp.security import IAP, Iam  # noqa: E402
from diagrams.gcp.storage import GCS  # noqa: E402
from diagrams.k8s.compute import Pod  # noqa: E402
from diagrams.k8s.infra import Master, Node  # noqa: E402
from diagrams.k8s.network import Ingress, Service  # noqa: E402
from diagrams.onprem.ci import GithubActions  # noqa: E402
from diagrams.onprem.client import Client, User  # noqa: E402
from diagrams.onprem.iac import Terraform  # noqa: E402
from diagrams.onprem.security import Trivy, Vault  # noqa: E402
from diagrams.onprem.vcs import Git, Github  # noqa: E402
from diagrams.programming.flowchart import (Action, Decision, Document,  # noqa: E402
                                            InputOutput, MultipleDocuments, StartEnd)
from diagrams.programming.language import Bash, Python  # noqa: E402

GRAPH, NODE, EDGE = gf.GRAPH, gf.NODE, gf.EDGE
RED, GREY, SOLID, LOOSE, INVIS = gf.RED, gf.GREY, gf.SOLID, gf.LOOSE, gf.INVIS
boundary, enclosure, zone, tier, rounded = gf.boundary, gf.enclosure, gf.zone, gf.tier, gf.rounded
MUTED = dict(color="#aeb6be", style="dashed")       # de-emphasised context


def fig(out: str, n: int, slug: str, direction: str, **graph_extra):
    path = os.path.join(out, f"figure-{n}-{slug}")
    return Diagram("", filename=path, show=False, direction=direction,
                   outformat=["png", "svg"],
                   graph_attr={**GRAPH, "nodesep": "0.9", **graph_extra},
                   node_attr=NODE, edge_attr=EDGE)


# ------------------------------------------------------------ 1 · the repo ----
def f1_repository(out):
    with fig(out, 1, "repository-as-a-system", "LR", ranksep="1.0"):
        with Cluster(**boundary("Repository · thewayofthesurge · private · ~800 Markdown files · 390k lines")):
            with Cluster(**rounded("Strategy · read by a human deciding whether to commit")):
                strat = Document("Root *.md\nROADMAP · CERTIFICATIONS · PROJECTS · JOB-SEARCH")

            with Cluster(**enclosure("curriculum/ · the execution layer")):
                with Cluster(**zone("week-01 … week-26 · gates at 4 · 9 · 13 · 17 · 21 · 26")):
                    week = Document("README.md\nthesis · day plan · reading map · exit criteria")
                    labs = MultipleDocuments("labs/ · solutions/ · assessment.md")
                with Cluster(**zone("_shared/ · cross-cutting")):
                    bf = MultipleDocuments("58 break/fix scenarios\ndrills · Anki · interview bank · templates")
                    tool = Python("diagrams/ + feynman/ toolchain\ncheck-diagrams.py · 5 checks · ~1 s")
                with Cluster(**tier("_reference/ · 626 files · ten domains · anonymized · a lookup, not a course")):
                    ref = MultipleDocuments("long-form material\nFeynman block appended to every file")
                with Cluster(**zone("_setup/ · the lab platform")):
                    setup = Terraform("aws-lab · gcp-lab\n6 root modules · per-OS setup scripts")
                with Cluster(**zone("projects/ · three flagship implementations")):
                    proj = Terraform("alpha · bravo · charlie\n3 roots + 4 modules")

            with Cluster(**rounded("Guardrails · the only thing between an edit and 600 broken files")):
                pre = Git("pre-commit\ngitleaks · fmt · diagrams · keys · size")
                ci = GithubActions("ci.yml · 3 required checks\nsecrets-scan · content-checks · terraform-validate")
                iac = Terraform("infra/github\nthe repository itself, as code")

        week >> Edge(**RED, label="reading map names exact files") >> ref
        week >> Edge(**SOLID) >> labs
        labs >> Edge(**GREY, label="run on the lab VM / kind") >> setup
        tool >> Edge(**GREY, label="generates Feynman blocks + figures", **LOOSE) >> ref
        strat >> Edge(**INVIS) >> week
        bf >> Edge(**INVIS) >> tool
        pre >> Edge(**RED) >> ci
        ci >> Edge(**GREY, label="required by the ruleset", **LOOSE) >> iac
        proj >> Edge(**INVIS) >> pre


# ------------------------------------------- 2 · commit-to-merge guardrails ----
def f2_guardrails(out):
    with fig(out, 2, "commit-to-merge-guardrails", "LR", ranksep="0.9"):
        you = User("You\nlaptop · one clone")

        with Cluster(**enclosure("pre-commit · once per clone · a failing hook blocks the commit · no fixers")):
            gl = Trivy("gitleaks v8.30.1\nstaged diff · allowlist of decoded placeholders")
            fmt = Terraform("terraform fmt -check\nevery root, not just infra/")
            chk = Python("check-diagrams.py\nchanged .md · 5 checks incl. relative links")
            misc = Document("private-key · 5 MB limit\nyaml · merge markers · symlinks")

        push = Github("push · PR or main")

        with Cluster(**enclosure("GitHub Actions · GitHub-authored actions only · SHA-pinned · token read-only · no credentials persisted")):
            sec = GithubActions("secrets-scan · 10 min\ngitleaks v8.30.1, sha256-verified download\nfull history, fetch-depth 0")
            con = GithubActions("content-checks · 10 min\n174 authored files, then 626 reference files")
            tfv = GithubActions("terraform-validate · 15 min\nfmt repo-wide · init+validate on 9 roots\none job: the name is a required check")

        with Cluster(**rounded("Ruleset · protect-default-branch · needs GitHub Pro on a private repo")):
            rule = Github("all 3 checks green · branch current with main\nno deletion · no force-push · linear history\nbypass: admin, through a PR only")

        main = Git("main\nsquash-only · branch auto-delete")
        dep = GithubActions("Dependabot · Mondays\naction SHAs + 9 Terraform roots")

        you >> Edge(**RED) >> gl
        gl >> Edge(**SOLID) >> fmt >> Edge(**SOLID) >> chk >> Edge(**SOLID) >> misc
        misc >> Edge(**RED) >> push
        push >> Edge(**RED) >> sec
        push >> Edge(**SOLID) >> con
        push >> Edge(**SOLID) >> tfv
        sec >> Edge(**RED) >> rule
        con >> Edge(**SOLID) >> rule
        tfv >> Edge(**SOLID) >> rule
        rule >> Edge(**RED, label="merge") >> main
        dep >> Edge(**GREY, label="opens PRs that run the same checks", **LOOSE) >> push


# --------------------------------------------- 3 · the repository as code ----
def f3_repo_as_code(out):
    with fig(out, 3, "repository-as-code", "LR", ranksep="1.0"):
        pat = User("You\nfine-grained PAT · Administration RW · ≤90 days\nshell env only, never in a file")

        with Cluster(**enclosure("infra/github · Terraform · state local and gitignored · bootstrap: the config lives in the repo it creates")):
            tf = Terraform("github_repository\nprivate · squash-only · auto_init=false\narchive_on_destroy · prevent_destroy")

        with Cluster(**boundary("GitHub · account")):
            with Cluster(**zone("pass 1 · works on the Free plan")):
                repo = Github("thewayofthesurge\nissues on · wiki, projects, discussions off")
                act = GithubActions("Actions policy\nGitHub-owned actions only · no cross-repo access")
                dep = Github("Dependabot\nalerts + security updates")
            with Cluster(**zone("pass 2 · after the first CI run is green")):
                rule = Github("ruleset · enable_rulesets=true\nPro required on private repos")
                sig = Github("required signatures\nonly after SSH signing works locally")
            with Cluster(**zone("no Terraform resource · one gh api call")):
                tok = Github("account default GITHUB_TOKEN = read\nActions may not approve PRs")

        local = Git("git push -u origin main\nthe codebase, including infra/github, uploads itself")

        pat >> Edge(**RED) >> tf >> Edge(**RED, label="apply") >> repo
        repo >> Edge(**SOLID) >> act
        repo >> Edge(**SOLID) >> dep
        repo >> Edge(**GREY, label="second apply", **LOOSE) >> rule
        rule >> Edge(**MUTED, label="third apply", **LOOSE) >> sig
        repo >> Edge(**GREY, **LOOSE) >> tok
        tf >> Edge(**RED, label="then", **LOOSE) >> local
        local >> Edge(**RED) >> repo


# ---------------------------------------------------- 4 · GCP lab topology ----
def f4_gcp_lab(out):
    with fig(out, 4, "gcp-lab-topology", "TB", ranksep="1.0"):
        you = User("You\ngcloud compute ssh --tunnel-through-iap")
        iap = IAP("Identity-Aware Proxy\nIAM-gated · 35.235.240.0/20")
        net = Client("Internet\nephemeral external IP · egress only")

        with Cluster(**boundary("Project · dedicated · gcloud projects delete removes everything")):
            with Cluster(**enclosure("VPC lab · custom, not default · implied deny-all ingress · allow-all egress")):
                with Cluster(**zone("subnet lab · 10.10.0.0/24 · us-central1 · flow logs 5 s / 50 % · Private Google Access")):
                    fw_ssh = FirewallRules("lab-allow-iap-ssh\ntcp/22 · from the IAP range only")
                    fw_web = FirewallRules("lab-allow-web\n80/443 · absent until open_web")
                    vm = ComputeEngine("VM lab · e2-medium · 20 GB\nno service account · Shielded VM\nOS Login (Ubuntu) · serial console off")

            with Cluster(**rounded("Auto-stop · 00:00 America/New_York · stop only, never start")):
                sched = Scheduler("instance schedule policy\nvm_stop_schedule only")
                role = Iam("custom role · 2 permissions\nstart/stop → Compute service agent")

            with Cluster(**tier("State · gs://<project>-tfstate · prefix lab/ and image/")):
                st = GCS("bucket · versioned, 10 kept\nsoft-delete 7 d · no public access\nnative .tflock object")
                log = Logging("Cloud Audit Logs\nDATA_READ + DATA_WRITE")

        tfl = Terraform("terraform on your laptop\nADC credential · backend.hcl")

        you >> Edge(**RED) >> iap >> Edge(**RED) >> fw_ssh >> Edge(**RED) >> vm
        fw_web >> Edge(**GREY, label="when open_web = true") >> vm
        vm >> Edge(**GREY, label="apt / pacman") >> net
        role >> Edge(**GREY) >> sched >> Edge(**GREY, label="stops nightly", **LOOSE) >> vm
        tfl >> Edge(**SOLID, label="state + lock object", **LOOSE) >> st
        st >> Edge(**GREY, **LOOSE) >> log


# ----------------------------------------- 5 · GCP state and image pipeline ----
def f5_gcp_supply_chain(out):
    with fig(out, 5, "gcp-state-and-image-supply-chain", "LR", ranksep="0.9"):
        with Cluster(**enclosure("state/ · applied once · keeps its OWN state locally (the only place that is correct)")):
            sttf = Terraform("google_storage_bucket\nprevent_destroy + force_destroy=false\ndestroy is refused twice")
            bucket = GCS("<project>-tfstate\nuniform access · versioned · soft-delete 7 d")
            hcl = Document("backend.hcl · one line\nbucket name · gitignored")

        with Cluster(**enclosure("image/ · Arch only · fetch.sh → terraform apply")):
            with Cluster(**zone("download · geo.mirror.pkgbuild.com · monthly build · ~600 MB")):
                mirror = Client("Arch cloud image\nqcow2 + .SHA256 + .sig")
            with Cluster(**zone("verify · two checks that prove different things")):
                sha = Bash("SHA256 from the same mirror\ncatches corruption\nproves nothing about origin")
                gpg = Vault("gpgv · own keyring, no agent\nfingerprint pinned 1B9A…6F8F\nsubkey expires May 2027")
            with Cluster(**zone("convert · package")):
                conv = Bash("qemu-img convert\nqcow2 → raw · whole GiB")
                tar = Document("arch-YYYYMMDD.tar.gz\none file named disk.raw · oldgnu · sparse")
            with Cluster(**tier("import · in YOUR project")):
                stage = GCS("<project>-images · staging\nforce_destroy · tarball kept")
                img = ComputeEngine("google_compute_image\narch-YYYYMMDD · family arch\nUEFI · gVNIC · create_before_destroy")

        with Cluster(**enclosure("gcp-lab/ · the VM")):
            vm = ComputeEngine("boot disk from the family\n…/global/images/family/arch\nfull path: the shorthand 403s")

        sttf >> Edge(**RED) >> bucket >> Edge(**RED, label="terraform output") >> hcl
        hcl >> Edge(**GREY, label="init -backend-config · prefix image/", **LOOSE) >> img
        hcl >> Edge(**GREY, label="prefix lab/", **LOOSE) >> vm
        mirror >> Edge(**RED) >> sha >> Edge(**RED) >> gpg >> Edge(**RED) >> conv
        conv >> Edge(**RED) >> tar >> Edge(**RED, label="upload") >> stage >> Edge(**RED) >> img
        img >> Edge(**RED, label="family, so a new build never forces a rebuild") >> vm


# ---------------------------------------------------- 6 · AWS lab topology ----
def f6_aws_lab(out):
    with fig(out, 6, "aws-lab-topology", "TB", ranksep="1.0"):
        you = User("You\naws ec2-instance-connect ssh")
        net = Client("Internet\npublic IP · egress only · no NAT to pay for")

        with Cluster(**boundary("Account · us-east-1 · budgets $25 / $50 / $100 set BEFORE any resource")):
            with Cluster(**enclosure("VPC lab · 10.20.0.0/16 · default security group stripped of all rules")):
                igw = InternetGateway("Internet gateway\n0.0.0.0/0 route")
                with Cluster(**zone("subnet 10.20.0.0/24 · map_public_ip_on_launch = false")):
                    eice = Endpoint("EC2 Instance Connect Endpoint\nSG → SG, tcp/22 only")
                    vm = EC2("VM lab · t3.medium · gp3 20 GB, encrypted\nIMDSv2, hop limit 1 · NO IAM role\nAMI changes ignored")
                with Cluster(**tier("evidence")):
                    flow = CloudwatchLogs("VPC flow logs · ALL\n/lab/vpc-flow · 14 days")

            with Cluster(**rounded("Auto-stop · cron(0 0 * * ? *) America/New_York")):
                sch = EventbridgeScheduler("EventBridge Scheduler\naws-sdk:ec2:stopInstances · no Lambda")
                role = IAMRole("role lab-auto-stop\nec2:StopInstances on this one instance")

            with Cluster(**tier("State · tfstate-lab-<account>-<region>")):
                s3 = S3("S3 bucket · versioned · SSE-S3\nTLS-only · ACLs off · use_lockfile\nold versions expire at 90 d")

        bud = Budgets("01-aws-guardrails.sh\n80 % actual + 100 % forecast alerts")

        you >> Edge(**RED) >> eice >> Edge(**RED, label="referenced SG, not a CIDR") >> vm
        vm >> Edge(**GREY) >> igw >> Edge(**GREY) >> net
        role >> Edge(**GREY) >> sch >> Edge(**GREY, label="stops nightly", **LOOSE) >> vm
        vm >> Edge(**GREY, **LOOSE) >> flow
        bud >> Edge(**MUTED, **LOOSE) >> s3


# ------------------------------------------------------- 7 · kind cluster ----
def f7_kind(out):
    with fig(out, 7, "kind-cluster", "LR", ranksep="1.0"):
        you = User("You · curl http://localhost\n127.0.0.1 only, never the LAN")

        with Cluster(**boundary("Docker on the laptop · kind cluster mastery · 02-kind-cluster.sh")):
            with Cluster(**enclosure("control-plane · label ingress-ready=true · hostPort 80/443 → 127.0.0.1")):
                cp = Master("kind-control-plane\ntainted; Envoy tolerates it")
                envoy = Pod("Envoy DaemonSet\nContour v1.33.7 · nodeSelector ingress-ready")
                contour = Pod("contour controller\nIngressClass contour · xDS to Envoy")
            with Cluster(**zone("workers ×2")):
                w = Node("kind-worker · kind-worker2")
                ing = Ingress("Ingress · class contour\nweek 14 shop.local")
                svc = Service("app Service\nnamespace-local backend (BF-49)")
                app = Pod("lab workloads\nweeks 14–26")
            with Cluster(**rounded("cluster add-ons · pinned")):
                ms = Pod("metrics-server v0.9.0\nHPA labs")
                kyv = Pod("Kyverno · weeks 18–19\nexcludes projectcontour")

        gone = Trivy("ingress-nginx\nretired upstream 2026 · repo gone")

        you >> Edge(**RED) >> cp >> Edge(**RED) >> envoy >> Edge(**RED, label="routes by host + path") >> ing
        ing >> Edge(**RED) >> svc >> Edge(**RED) >> app
        contour >> Edge(**GREY, label="config") >> envoy
        w >> Edge(**INVIS) >> ing
        ms >> Edge(**GREY, **LOOSE) >> app
        kyv >> Edge(**GREY, label="admission", **LOOSE) >> app
        gone >> Edge(**MUTED, label="replaced by", **LOOSE) >> contour


# --------------------------------------------------- 8 · nightly teardown ----
def f8_teardown(out):
    with fig(out, 8, "nightly-teardown", "LR", ranksep="1.1"):
        start = StartEnd("03-teardown.sh\nnightly · from the curriculum root")
        find = Action("find .terraform dirs\nmaxdepth 6 · was 4, which missed\nalpha/environments/{dev,prod}")
        skip = Decision(".teardown-skip\npresent?")
        keep = Action("left alone\ngcp-lab (stops nightly) · image · state · infra/github")
        destroy = Action("terraform destroy -auto-approve\nno questions asked")
        kind = Decision("kind clusters\ny/N each, read from /dev/tty")
        aws = Action("AWS orphans\nEC2 · NAT · RDS · ELB · EKS")
        gcp = Action("GCP orphans\nVMs · unattached disks\nreserved IPs")
        end = StartEnd("Anything listed is still billing.\nKill it.")
        bud = Budgets("budgets + nightly stop\nthe budget alerts; the schedule limits")

        start >> Edge(**RED) >> find >> Edge(**RED) >> skip
        skip >> Edge(**GREY, label="yes") >> keep
        skip >> Edge(**RED, label="no") >> destroy
        destroy >> Edge(**RED) >> kind >> Edge(**RED) >> aws >> Edge(**RED) >> gcp >> Edge(**RED) >> end
        keep >> Edge(**INVIS) >> kind
        bud >> Edge(**MUTED, **LOOSE) >> end


# ---------------------------------------------- 9 · what the review did ----
def f9_review(out):
    with fig(out, 9, "the-review", "LR", ranksep="0.9"):
        before = Github("main @ 98c8907\n+ pending GCP lab change")

        with Cluster(**enclosure("Scan · everything local · nothing sent anywhere")):
            sec = Trivy("gitleaks (history + untracked)\ncheckov · trivy · tflint")
            tf = Terraform("terraform fmt + validate\nall 9 roots")
            sh = Bash("shellcheck\nevery setup script")
            py = Python("check-diagrams.py · Feynman dry run\n+ custom relative-link pass")
            up = Github("upstream verification\naction SHAs · checksums · tags")

        with Cluster(**rounded("Findings · ranked by blast radius")):
            f = Document("7 findings, ranked\n1 teardown depth · 2 curl | sudo sh ×5\n3 CI: 1 of 9 roots · 4 project ID baked in\n5 anonymization residue · 6 437 dead links\n7 ingress-nginx retired upstream")

        with Cluster(**enclosure("Fix · 8 commits on main · each scoped to one concern · hooks run on every one")):
            c1 = Git("GCP lab\nOS Login · no baked project ID")
            c2 = Git("Guardrails\n9 roots in CI · PR-only bypass")
            c3 = Git("Setup\n00-toolchain.sh retired · teardown depth 6")
            c4 = Git("kind\nContour v1.33.7 · 11 files migrated")
            c5 = Git("Reference\nanonymization residue stripped")
            c6 = Git("Content\n314 links rewritten · 123 unlinked\n209 files · checker enforces")

        after = Github("main @ 4020fdf\ntree clean · every check green")

        for tool in (sec, tf, sh, py, up):
            before >> Edge(**SOLID) >> tool
            tool >> Edge(**GREY) >> f
        before >> Edge(**RED, **LOOSE) >> f
        for c in (c1, c2, c3, c4, c5, c6):
            f >> Edge(**SOLID) >> c
            c >> Edge(**SOLID) >> after
        f >> Edge(**RED, **LOOSE) >> after


# ------------------------------------------------ 10 · the link resolver ----
def f10_resolver(out):
    with fig(out, 10, "link-resolver", "LR", ranksep="1.1"):
        inp = InputOutput("relative link target\noutside code fences and inline code\n2,519 across 800 files")
        exists = Decision("exists on disk?")
        ok = StartEnd("fine · 2,082")
        skipq = Decision("http · mailto · # · /\n{var} · … · xxx · bare word?")
        skipped = Action("skip · a placeholder\nor code, not a path")
        flat = Action("flatten · strip ../ · join with -\n../lab-09-x/README.md\n→ lab-09-x-README.md")
        match = Decision("exactly one file ends with it?\nsame dir → domain → library")
        rewrite = Action("rewrite to the relative path\n314 links")
        unlink = Action("unlink · keep the text\n123 links · the file was never imported")
        done = StartEnd("209 files touched\nchecker now fails on any new one")

        inp >> Edge(**RED) >> exists
        exists >> Edge(**GREY, label="yes") >> ok
        exists >> Edge(**RED, label="no") >> skipq
        skipq >> Edge(**GREY, label="yes") >> skipped
        skipq >> Edge(**RED, label="no") >> flat >> Edge(**RED) >> match
        match >> Edge(**RED, label="yes") >> rewrite
        match >> Edge(**SOLID, label="no, or ambiguous") >> unlink
        rewrite >> Edge(**RED) >> done
        unlink >> Edge(**SOLID) >> done


FIGURES = {1: f1_repository, 2: f2_guardrails, 3: f3_repo_as_code, 4: f4_gcp_lab,
           5: f5_gcp_supply_chain, 6: f6_aws_lab, 7: f7_kind, 8: f8_teardown,
           9: f9_review, 10: f10_resolver}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(_HERE, "..", "..", "_setup", "figures"),
                    help="output directory (default: curriculum/_setup/figures)")
    ap.add_argument("--only", type=int, choices=sorted(FIGURES), help="render one figure")
    args = ap.parse_args()
    out = os.path.abspath(os.path.expanduser(args.out))
    os.makedirs(out, exist_ok=True)
    for n, fn in FIGURES.items():
        if args.only and args.only != n:
            continue
        fn(out)
        print(f"  figure {n:2d} -> {out}/figure-{n}-*.png|svg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
