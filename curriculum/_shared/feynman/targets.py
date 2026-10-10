"""Turn a reference file's own headings into explain-targets."""
import re

H2 = re.compile(r"^##\s+(.+?)\s*$", re.M)
H3 = re.compile(r"^###\s+(.+?)\s*$", re.M)
H1 = re.compile(r"^#\s+(.+?)\s*$", re.M)

# Structural scaffolding, not content. A heading that only tells you where you
# are in the document is a useless thing to be asked to explain.
SKIP = {
    "overview", "prerequisites", "objectives", "learning objectives", "goals",
    "table of contents", "contents", "toc", "summary", "introduction", "intro",
    "next steps", "what's next", "references", "resources", "further reading",
    "additional resources", "labs", "lab environment", "lab setup", "structure",
    "best practices", "knowledge check", "common mistakes", "exercises",
    "hands-on exercises", "setup", "cleanup", "teardown", "conclusion",
    "key takeaways", "takeaways", "checklist", "verification", "validation",
    "solution", "solutions", "requirements", "deliverables", "assessment",
    "grading", "scenario", "tasks", "notes", "tips", "appendix", "glossary",
    "faq", "files", "commands", "time", "difficulty", "duration", "estimated time",
    "what you'll learn", "what you will learn", "success criteria", "quiz",
    "practice", "review", "recap", "example", "examples", "usage", "syntax",
    "installation", "install", "getting started", "quick start", "background",
    "concepts", "concept", "theory", "discussion", "questions", "answers",
    "reflection", "retrospective", "wrap-up", "credits", "license", "changelog",
    "objective", "duration", "features", "running tests", "usage examples",
    "assessment overview", "scoring", "rubric", "submission", "hints",
    "next lab", "previous lab", "required tools", "required knowledge",
    "environment setup", "initial setup", "installation options",
    "directory structure", "file structure", "learning path", "study path",
    "roadmap", "curriculum", "syllabus", "agenda", "outline",
    # A second pass, from auditing what actually leaked through: headings that
    # describe the document, the assignment, or the price -- never an idea.
    "executive summary", "cost estimate", "estimated cost", "cost", "costs",
    "cost breakdown", "lab environment setup", "learning goals", "lab overview",
    "architecture diagram", "diagram", "diagrams", "company background",
    "company profile", "business context", "acceptance criteria", "time estimate",
    "project tasks", "lab tasks", "evaluation criteria", "the challenge",
    "the solution", "why this matters for the exam", "why this matters",
    "strengths", "weaknesses", "limitations", "recommendations", "recommendation",
    "bonus challenges", "bonus", "self-check", "self check", "submission requirements",
    "what you will build", "what you'll build", "implementation",
    "implementation guide", "implementation steps", "troubleshooting",
    "validation script", "labs in this phase", "the brief", "starting point",
    "answers and explanations", "services covered", "phase overview",
    "phase project", "progress checklist", "content structure", "constraints",
    "scope", "deliverable", "context", "problem", "the problem", "approach",
    "the approach", "results", "outcome", "outcomes", "lessons learned",
    "what to do", "how it works", "walkthrough", "steps", "procedure",
    "architecture", "architecture overview", "design", "high-level design",
    "extension challenges", "system description", "organization profile",
    "results and metrics", "discussion questions", "technology stack",
    "when done", "tips for success", "verification checklist",
    "what you learned", "key learnings", "advanced topics", "professional topics",
}
# A heading that is a filename is a pointer, not an idea.
FILENAME = re.compile(r"^[\w./-]+\.(?:ya?ml|json|tf|py|sh|md|txt|toml|ini|conf)$", re.I)
# Patterns rather than exact names -- "Guided Exercises", "Files in This
# Directory", "What's Next?" are all navigation wearing a heading.
SKIP_SUB = (
    "exercise", "in this directory", "what's next", "whats next", "next?",
    "tier 1", "tier 2", "tier 3", "guided instruction", "grading",
    "points)", "your task", "submission", "start with lab", "answer key",
    "mock exam",
    "further read", "see also", "read more", "learn more", "table of",
    "how to use", "using this", "about this", "in this module", "in this lab",
)
# "Part 3: Multi-Cluster Applications" -> "Multi-Cluster Applications"
PREFIX = re.compile(r"^(?:part|step|phase|module|lab|exercise|section|chapter|day|week|task|question|q)\s*\d+\s*[:.\-–]\s*",
                    re.I)
NUMBERED = re.compile(r"^\d+[.)]\s*")
MARKUP = re.compile(r"[`*_]|<[^>]+>")
# "Prometheus & PromQL (20 points)" -> "Prometheus & PromQL"
SUFFIX = re.compile(r"\s*\((?:\d+\s*(?:points?|pts|min(?:utes)?)|guided|semi-guided|optional)\)\s*$", re.I)
TIMED = re.compile(r"^(?:duration|time|estimated)\s*[:–-]", re.I)


def clean(h: str) -> str:
    h = MARKUP.sub("", h).strip()
    h = PREFIX.sub("", h)
    h = NUMBERED.sub("", h)
    h = SUFFIX.sub("", h)
    if TIMED.match(h):
        return ""
    return h.strip(" :–—-")


def pick(text: str, title: str, want: int = 4) -> list[str]:
    """The most substantive headings in the file, in document order."""
    out: list[str] = []
    for pat in (H2, H3):
        for raw in pat.findall(text):
            h = clean(raw)
            if not h or len(h) < 4 or len(h) > 78:
                continue
            low = h.lower()
            if low in SKIP or any(s in low for s in SKIP_SUB) or FILENAME.match(h):
                continue
            if h.lower().startswith(("part ", "step ", "appendix")):
                continue
            if h not in out:
                out.append(h)
        if len(out) >= want:
            break
    if not out:                       # nothing substantive -- fall back to the title
        t = clean(title)
        return [t] if t else []
    return out[:want]
