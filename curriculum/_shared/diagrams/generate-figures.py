#!/usr/bin/env python3
"""Render the three flagship project architecture figures with official AWS icons.

Mermaid handles every diagram inside the curriculum -- it renders natively on
GitHub and diffs in a pull request. What Mermaid cannot draw is a vendor service
icon, and the three project READMEs are portfolio artifacts that a hiring manager
actually looks at. That is the one place the extra build step returns something.

The visual language matches _shared/diagrams/STYLE.md exactly:

    ink        #2d3436   all text
    line       #7a7a7a   default edges and borders
    container  #aeb6be   boundary frames
    CRITICAL   #c7254e   the path that matters -- solid, 1.8pt
    group wash #eef4fb   the data tier

Boundaries nest outermost-first and carry a fact, not just a name. Captions are
two lines: what it is, then the design decision that makes it non-generic.

    pip install -r requirements.txt   # pinned diagrams + graphviz bindings; needs graphviz (dot) on PATH
    ./generate-figures.py --out ../../projects
"""
from __future__ import annotations

import argparse
import os
import sys

# The repo may contain a directory named `diagrams`; make sure the library wins.
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path = [p for p in sys.path if os.path.abspath(p or os.getcwd()) != _HERE]
os.chdir(os.path.expanduser("~"))

from diagrams import Cluster, Diagram, Edge  # noqa: E402
from diagrams.aws.compute import ECR, EKS, EC2  # noqa: E402
from diagrams.aws.database import RDS  # noqa: E402
from diagrams.aws.general import Users  # noqa: E402
from diagrams.aws.management import Cloudwatch, SystemsManager  # noqa: E402
from diagrams.aws.network import ALB, Endpoint, NATGateway, Route53  # noqa: E402
from diagrams.aws.security import SecretsManager  # noqa: E402
from diagrams.aws.storage import S3  # noqa: E402
from diagrams.k8s.compute import Pod  # noqa: E402
from diagrams.onprem.ci import GithubActions  # noqa: E402
from diagrams.onprem.gitops import Argocd  # noqa: E402
from diagrams.onprem.security import Trivy, Vault  # noqa: E402
from diagrams.onprem.container import Docker  # noqa: E402
from diagrams.k8s.network import NetworkPolicy  # noqa: E402
from diagrams.onprem.vcs import Github  # noqa: E402

# ------------------------------------------------------------------ style ----
FONT = "Helvetica"
INK, LINE, CONTAINER, CRITICAL, WASH = "#2d3436", "#7a7a7a", "#aeb6be", "#c7254e", "#eef4fb"

GRAPH = {
    "fontname": FONT, "fontsize": "13", "fontcolor": INK,
    "pad": "0.5", "nodesep": "0.45", "ranksep": "0.85",
    "splines": "spline", "bgcolor": "white", "dpi": "144",
    "newrank": "true", "compound": "true",
}
NODE = {
    "fontname": FONT, "fontsize": "10", "fontcolor": INK,
    "width": "1.25", "height": "1.55", "imagescale": "true", "fixedsize": "true",
}
EDGE = {"fontname": FONT, "fontsize": "9", "fontcolor": INK, "color": LINE}

RED = dict(color=CRITICAL, penwidth="1.8")          # the path that matters
GREY = dict(color=LINE, style="dashed")             # context, side effects
SOLID = dict(color=LINE)                            # a normal relationship
LOOSE = dict(constraint="false")                    # must not steer the layout
INVIS = dict(style="invis")                         # rank-ordering only, never drawn


def _frame(label, *, style, color, penwidth, fontsize):
    return dict(
        graph_attr={
            "style": style, "color": color, "penwidth": penwidth,
            "fontname": FONT, "fontsize": fontsize, "fontcolor": INK,
            "labeljust": "l", "bgcolor": "#ffffff",
        },
        label=label,
    )


def boundary(label):
    """Outermost logical boundary -- a Region, an environment. Dashed."""
    return _frame(label, style="dashed", color=CONTAINER, penwidth="1.6", fontsize="12")


def enclosure(label):
    """A concrete boundary -- a VPC, a cluster, a CI system. Solid."""
    return _frame(label, style="solid", color=CONTAINER, penwidth="1.6", fontsize="11")


def zone(label):
    """A subdivision -- availability zones, a stage. Thin dashed."""
    return _frame(label, style="dashed", color=CONTAINER, penwidth="1.0", fontsize="10")


def tier(label):
    """A grouped tier that deserves emphasis -- the data plane. Washed."""
    return dict(
        graph_attr={
            "style": "filled", "color": CONTAINER, "penwidth": "1.0", "fillcolor": WASH,
            "fontname": FONT, "fontsize": "9", "fontcolor": INK, "labeljust": "l",
        },
        label=label,
    )


def rounded(label, color=CONTAINER):
    """A soft grouping that is not an infrastructure boundary."""
    return _frame(label, style="rounded", color=color, penwidth="1.2", fontsize="11")


# ------------------------------------------------------------------ ALPHA ----
def alpha(out: str) -> None:
    """Project ALPHA -- production-shaped cloud infrastructure, entirely in code."""
    path = os.path.join(out, "alpha-cloud-foundation", "docs", "architecture")
    os.makedirs(os.path.dirname(path), exist_ok=True)

    with Diagram("", filename=path, show=False, direction="TB", outformat=["png", "svg"],
                 graph_attr=GRAPH, node_attr=NODE, edge_attr=EDGE):

        users = Users("Users")

        with Cluster(**rounded("Delivery · no long-lived AWS credentials exist")):
            gh = Github("GitHub\npull request")
            gha = GithubActions("Actions\nOIDC → STS, 1-hour role")

        with Cluster(**boundary("Region · us-east-1")):
            r53 = Route53("Route 53\nalias record at the apex")

            with Cluster(**enclosure(
                    "VPC 10.20.0.0/16 · 75% of the range left free for growth")):
                alb = ALB("Application Load Balancer\nACM cert · HTTPS only")

                with Cluster(**zone("Availability Zones ×2")):
                    # Tier order is enforced below with invisible edges: Graphviz
                    # otherwise ranks these by the visible edges alone and puts the
                    # public tier under the app tier, which reads as wrong.
                    with Cluster(**tier("public subnets · /24 · NAT and ALB only")):
                        nat = NATGateway("NAT gateway\none per AZ in prod")
                        s3ep = Endpoint("S3 gateway endpoint\nfree · removes NAT data cost")

                    with Cluster(**tier("app subnets · /20 · sized for pod IPs")):
                        app_a = EC2("ASG · AZ-a\nELB health check · 300s grace")
                        app_b = EC2("ASG · AZ-b\nIMDSv2 required")

                    with Cluster(**tier("data subnets · /24 · NO default route")):
                        rds = RDS("RDS PostgreSQL\nMulti-AZ · KMS · 14d backups")

            with Cluster(**rounded("Supporting · regional")):
                sm = SecretsManager("Secrets Manager\npassword generated by RDS,\nTerraform never sees it")
                cw = Cloudwatch("CloudWatch\nsymptom alarms · dashboard")

        # the request path -- the thing to follow first
        users >> Edge(**RED) >> r53 >> Edge(**RED) >> alb
        alb >> Edge(**RED) >> app_a
        alb >> Edge(**RED) >> app_b
        app_a >> Edge(**RED) >> rds
        app_b >> Edge(**RED) >> rds

        # tier ordering: public above app above data
        nat >> Edge(**INVIS) >> app_a
        s3ep >> Edge(**INVIS) >> app_b

        # context -- deliberately loose so it does not steer the layout
        gh >> Edge(**SOLID, label="plan on PR") >> gha
        gha >> Edge(**RED, label="apply on merge\nafter approval", **LOOSE) >> alb
        app_a >> Edge(**GREY, label="egress", **LOOSE) >> nat
        app_b >> Edge(**GREY, label="S3 without NAT", **LOOSE) >> s3ep
        rds >> Edge(**GREY, **LOOSE) >> sm
        alb >> Edge(**GREY, **LOOSE) >> cw


# ------------------------------------------------------------------ BRAVO ----
def bravo(out: str) -> None:
    """Project BRAVO -- make shipping something insecure structurally difficult."""
    path = os.path.join(out, "bravo-secure-delivery", "docs", "architecture")
    os.makedirs(os.path.dirname(path), exist_ok=True)

    with Diagram("", filename=path, show=False, direction="LR", outformat=["png", "svg"],
                 graph_attr={**GRAPH, "ranksep": "1.0"}, node_attr=NODE, edge_attr=EDGE):

        commit = Github("commit")

        with Cluster(**enclosure("CI · every gate hard-fails · cheapest checks first")):
            with Cluster(**zone("source")):
                gl = GithubActions("gitleaks\nsecrets · full history")
                sg = GithubActions("Semgrep\nSAST")
            with Cluster(**zone("dependencies and image")):
                tf = Trivy("Trivy fs\nfixable HIGH/CRITICAL")
                ti = Docker("build + Trivy image\ndistroless · non-root")
            with Cluster(**zone("provenance")):
                sy = GithubActions("syft\nSBOM, SPDX")
                cs = Vault("cosign sign\nsigns the DIGEST, not the tag")

        with Cluster(**boundary("Registry")):
            ecr = ECR("ECR\nimage + signature + SBOM attestation")

        argo = Argocd("ArgoCD\npull-based · selfHeal")

        with Cluster(**enclosure("EKS · admission and runtime")):
            with Cluster(**zone("admission")):
                kyv = Pod("Kyverno\nsigned images only · non-root\nlimits required · no :latest")
                pss = Pod("Pod Security Standards\nrestricted")
            with Cluster(**tier("runtime")):
                netpol = NetworkPolicy("NetworkPolicy\ndefault-deny + DNS")
                falco = Pod("Falco\nbehavioural detection")
                eso = SecretsManager("External Secrets\nvalue never enters Git")

        commit >> Edge(**RED) >> gl
        gl >> Edge(**SOLID) >> sg >> Edge(**SOLID) >> tf >> Edge(**SOLID) >> ti
        ti >> Edge(**SOLID) >> sy >> Edge(**RED) >> cs
        cs >> Edge(**RED, label="push") >> ecr
        ecr >> Edge(**RED) >> argo >> Edge(**RED, label="verified at admission") >> kyv
        kyv >> Edge(**SOLID) >> pss
        pss >> Edge(**GREY) >> netpol >> Edge(**GREY) >> falco
        falco >> Edge(**INVIS) >> eso


# ---------------------------------------------------------------- CHARLIE ----
def charlie(out: str) -> None:
    """Project CHARLIE -- one YAML file, one PR, a running service in ten minutes."""
    path = os.path.join(out, "charlie-platform", "docs", "architecture")
    os.makedirs(os.path.dirname(path), exist_ok=True)

    with Diagram("", filename=path, show=False, direction="LR", outformat=["png", "svg"],
                 graph_attr={**GRAPH, "ranksep": "1.0"}, node_attr=NODE, edge_attr=EDGE):

        dev = Users("Product engineer\nnot a Kubernetes expert")

        with Cluster(**rounded("The contract · the only thing a developer writes")):
            svc = Github("service.yaml\nname · owner · language\nport · tier · dependencies")

        with Cluster(**enclosure("On the pull request")):
            val = GithubActions("validate\nerrors say how to fix")
            plan = GithubActions("terraform plan\nchanged services only")
            cost = GithubActions("cost estimate\nposted before merge")

        with Cluster(**enclosure("Generated on merge · zero manual steps")):
            with Cluster(**zone("delivery")):
                ecr = ECR("ECR repo\n+ pipeline from the template")
                argo = Argocd("ArgoCD Application")
            with Cluster(**zone("access · least privilege by construction")):
                iam = SecretsManager("IRSA role\nscoped to declared dependencies only")
                ssm = SystemsManager("SSM contract\nthe platform's public API")
            with Cluster(**tier("always generated · never opt-in")):
                obs = Cloudwatch("dashboard · alerts\nSLO · runbook stub")

        with Cluster(**boundary("Running · tier decides the shape")):
            pod = Pod("Service\ncritical: 3 AZs, PDB, 99.9% SLO")
            db = RDS("Postgres\nif declared")
            bucket = S3("Bucket\nif declared")

        dev >> Edge(**RED) >> svc >> Edge(**RED) >> val
        val >> Edge(**SOLID) >> plan >> Edge(**SOLID) >> cost
        cost >> Edge(**RED, label="merge") >> ecr
        ecr >> Edge(**RED) >> argo >> Edge(**RED) >> pod
        pod >> Edge(**SOLID, label="if declared") >> db
        pod >> Edge(**SOLID, label="if declared") >> bucket

        # The generated resources belong to the service by CONTAINMENT -- drawing an
        # edge from each one to the pod produced four long loops that said nothing
        # the "Generated on merge" boundary did not already say. Invisible edges
        # keep them ranked together instead.
        iam >> Edge(**INVIS) >> ssm
        ssm >> Edge(**INVIS) >> obs
        obs >> Edge(**INVIS) >> ecr


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(_HERE, "..", "..", "projects"),
                    help="projects directory (default: curriculum/projects)")
    ap.add_argument("--only", choices=["alpha", "bravo", "charlie"],
                    help="render a single figure")
    args = ap.parse_args()

    out = os.path.abspath(os.path.expanduser(args.out))
    figures = {"alpha": alpha, "bravo": bravo, "charlie": charlie}
    for name, fn in figures.items():
        if args.only and args.only != name:
            continue
        fn(out)
        print(f"  {name:8s} -> {out}/{name if name != 'alpha' else 'alpha-cloud-foundation'}"
              f"{'' if name == 'alpha' else '-' + ('secure-delivery' if name == 'bravo' else 'platform')}"
              f"/docs/architecture.[png|svg]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
