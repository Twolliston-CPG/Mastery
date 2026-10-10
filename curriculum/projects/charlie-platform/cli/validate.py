#!/usr/bin/env python3
"""Validate a service.yaml against the platform contract.

The error messages ARE the feature. A validation error is the most-read
documentation in a platform: it arrives at the exact moment someone needs it,
and it is the only documentation a developer is guaranteed to see.

Every message answers four questions:
    WHERE   file and line
    WHAT    the invalid value
    OPTIONS the valid ones, WITH THEIR MEANING -- not just their names
    NEXT    a suggestion, and a docs link

Usage:
    ./validate.py services/orders-api/service.yaml
    ./validate.py services/*/service.yaml
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from difflib import get_close_matches
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("pyyaml is required:  pip install pyyaml")

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = ROOT / "platform" / "schemas" / "service.schema.json"
TEAMS_PATH = ROOT / "platform" / "teams" / "teams.yaml"
DOCS = "https://platform.internal/docs"

# What each enum value MEANS. Listing valid values without their meaning makes
# the developer go and read the docs; listing the meaning answers the question
# in place.
TIER_MEANING = {
    "critical": "3 replicas across AZs, PDB, 99.9% SLO, pages on-call 24/7, Multi-AZ database",
    "standard": "2 replicas, 99.5% SLO, creates tickets in business hours, single-AZ database",
    "experimental": "1 replica, no SLO, no paging, AUTO-EXPIRES after 30 days",
}
LANGUAGE_MEANING = {
    "python": "golden-path pipeline: ruff, pytest, semgrep, distroless image",
    "go":     "golden-path pipeline: go vet, go test, semgrep, static distroless image",
    "node":   "golden-path pipeline: eslint, jest, semgrep, distroless image",
    "java":   "golden-path pipeline: spotbugs, junit, semgrep, distroless JRE image",
}
DEPENDENCY_MEANING = {
    "postgres": "RDS instance + Secrets Manager secret + scoped security group rule",
    "s3":       "bucket + an IAM policy scoped to exactly that bucket",
    "sqs":      "queue + DLQ + scoped IAM policy",
    "redis":    "ElastiCache node + scoped security group rule",
}

SECRET_LOOKALIKE = re.compile(
    r"(AKIA[0-9A-Z]{16}|sk_live_|ghp_[A-Za-z0-9]{36}|-----BEGIN .* PRIVATE KEY-----|[A-Za-z0-9/+=]{40,})"
)


@dataclass
class Finding:
    path: Path
    line: int | None
    field: str
    message: str

    def render(self) -> str:
        where = f"{self.path}" + (f" line {self.line}" if self.line else "")
        return f"\033[1m{where}:\033[0m\n  \033[31m{self.field}\033[0m: {self.message}\n"


def line_of(text: str, *keys: str) -> int | None:
    """Best-effort line number for a dotted field path. Good enough to be useful."""
    needle = keys[-1] if keys else ""
    for i, line in enumerate(text.splitlines(), start=1):
        if re.match(rf"^\s*{re.escape(needle)}\s*:", line):
            return i
    return None


def enum_error(field: str, value, options: dict[str, str]) -> str:
    lines = [f'"{value}" is not a valid {field.split(".")[-1]}.', "", "  Valid values:"]
    width = max(len(k) for k in options)
    for name, meaning in options.items():
        lines.append(f"    {name.ljust(width)}  {meaning}")
    suggestion = get_close_matches(str(value), list(options), n=1, cutoff=0.5)
    if suggestion:
        lines += ["", f'  Did you mean "{suggestion[0]}"?']
    lines += ["", f"  Docs: {DOCS}/{field.split('.')[-1]}s"]
    return "\n".join(lines)


def validate(path: Path, teams: set[str]) -> list[Finding]:
    raw = path.read_text()
    out: list[Finding] = []

    def add(field: str, msg: str, key: str | None = None):
        out.append(Finding(path, line_of(raw, key or field.split(".")[-1]), field, msg))

    try:
        doc = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        mark = getattr(exc, "problem_mark", None)
        return [Finding(path, (mark.line + 1) if mark else None, "(yaml)",
                        f"could not parse this file: {getattr(exc, 'problem', exc)}\n"
                        f"  Check indentation -- YAML requires spaces, never tabs.")]

    if not isinstance(doc, dict):
        return [Finding(path, 1, "(root)", "expected a YAML mapping at the top level.")]

    meta = doc.get("metadata") or {}
    spec = doc.get("spec") or {}

    # ---- metadata.name -----------------------------------------------------
    name = meta.get("name")
    if not name:
        add("metadata.name",
            "is required.\n"
            "  It becomes the namespace, DNS name, ECR repository, and repo name,\n"
            "  and cannot be changed later without recreating the service.")
    elif not re.fullmatch(r"[a-z]([-a-z0-9]{0,38}[a-z0-9])?", str(name)):
        add("metadata.name",
            f'"{name}" is not a valid service name.\n'
            "  Must be a DNS-1123 label: start with a letter, then lowercase\n"
            "  letters, digits, or hyphens, ending with a letter or digit.\n"
            "  Maximum 40 characters.\n\n"
            f'  Suggestion: "{re.sub(r"[^a-z0-9-]", "-", str(name).lower()).strip("-")[:40]}"')

    # ---- metadata.owner ----------------------------------------------------
    owner = meta.get("owner")
    if not owner:
        add("metadata.owner",
            "is required.\n"
            "  An unowned service is nobody's problem at 3am and cannot be\n"
            f"  cost-attributed.\n\n  Valid owners: {', '.join(sorted(teams))}")
    elif owner not in teams:
        suggestion = get_close_matches(str(owner), sorted(teams), n=1, cutoff=0.4)
        msg = (f'"{owner}" is not a known team.\n\n'
               f"  Known teams: {', '.join(sorted(teams))}\n")
        if suggestion:
            msg += f'\n  Did you mean "{suggestion[0]}"?\n'
        msg += (f"\n  To add a team, open a PR against platform/teams/teams.yaml.\n"
                f"  Docs: {DOCS}/teams")
        add("metadata.owner", msg)

    # ---- spec.tier ---------------------------------------------------------
    tier = spec.get("tier")
    if not tier:
        add("spec.tier", enum_error("spec.tier", "(not set)", TIER_MEANING))
    elif tier not in TIER_MEANING:
        add("spec.tier", enum_error("spec.tier", tier, TIER_MEANING))

    # ---- spec.language -----------------------------------------------------
    lang = spec.get("language")
    if not lang:
        add("spec.language", enum_error("spec.language", "(not set)", LANGUAGE_MEANING))
    elif lang not in LANGUAGE_MEANING:
        add("spec.language", enum_error("spec.language", lang, LANGUAGE_MEANING))

    # ---- spec.port ---------------------------------------------------------
    port = spec.get("port")
    if port is None:
        add("spec.port", "is required. The port your application listens on.")
    elif not isinstance(port, int):
        add("spec.port", f'"{port}" must be a number, not a string. Remove the quotes.')
    elif port < 1024:
        add("spec.port",
            f"{port} is below 1024.\n"
            "  Containers run as non-root (UID 10001), which cannot bind privileged\n"
            "  ports. Use 8080 and let the Service map port 80 to it.")
    elif port > 65535:
        add("spec.port", f"{port} is not a valid port.")

    # ---- spec.dependencies -------------------------------------------------
    for i, dep in enumerate(spec.get("dependencies") or []):
        if not isinstance(dep, dict) or "type" not in dep:
            add(f"spec.dependencies[{i}]", "each dependency needs a `type`.", "dependencies")
            continue
        if dep["type"] not in DEPENDENCY_MEANING:
            add(f"spec.dependencies[{i}].type",
                enum_error("spec.dependencies.type", dep["type"], DEPENDENCY_MEANING),
                "dependencies")

    # ---- spec.env: refuse anything that looks like a credential ------------
    for i, item in enumerate(spec.get("env") or []):
        if not isinstance(item, dict):
            continue
        value = item.get("value")
        if value and SECRET_LOOKALIKE.search(str(value)):
            add(f"spec.env[{i}].value",
                f'the value of {item.get("name", "?")} looks like a credential.\n\n'
                "  Secrets must never be committed. Put it in AWS Secrets Manager and\n"
                "  reference it:\n\n"
                "      - name: " + str(item.get("name", "MY_SECRET")) + "\n"
                "        fromSecret: your-team/service/key-name\n\n"
                "  External Secrets resolves it at runtime; it never enters Git.\n"
                f"  Docs: {DOCS}/secrets", "env")
        if value is None and not item.get("fromSecret"):
            add(f"spec.env[{i}]",
                f'{item.get("name", "?")} needs either `value` or `fromSecret`.', "env")

    # ---- cross-field sanity ------------------------------------------------
    replicas = ((spec.get("resources") or {}).get("replicas") or {})
    if tier == "critical" and replicas.get("min", 3) < 2:
        add("spec.resources.replicas.min",
            f'{replicas.get("min")} is too low for tier "critical".\n'
            "  A critical service needs at least 2 replicas so a node drain or a\n"
            "  single pod failure does not take it down. Either raise this to 2+,\n"
            '  or use tier "standard".', "min")

    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2

    if not SCHEMA_PATH.exists():
        print(f"missing schema: {SCHEMA_PATH}", file=sys.stderr)
        return 2
    json.loads(SCHEMA_PATH.read_text())          # fail early if the schema is broken

    teams = {t["name"] for t in yaml.safe_load(TEAMS_PATH.read_text())["teams"]}

    findings: list[Finding] = []
    for arg in argv[1:]:
        p = Path(arg)
        if not p.exists():
            print(f"no such file: {p}", file=sys.stderr)
            return 2
        findings += validate(p, teams)

    if not findings:
        n = len(argv) - 1
        print(f"\033[32mOK\033[0m  {n} service definition{'s' if n != 1 else ''} valid")
        return 0

    print(f"\n\033[31m{len(findings)} problem(s) found\033[0m\n")
    for f in findings:
        print(f.render())
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
