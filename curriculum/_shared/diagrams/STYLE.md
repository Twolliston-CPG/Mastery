# Diagram Style Guide

> One visual language across the whole curriculum. Derived from the reference architecture figures:
> muted grays for structure, **crimson for the path that matters**, nested labelled containers,
> two-line captions.

---

## The theme header must be one line

```
%%{init: {'theme':'base','themeVariables':{...},'flowchart':{...}}}%%
```

Mermaid's own parser accepts a directive spread over several lines. Plenty of the things that
*render* Mermaid do not — GitLab, several editor previews, and older embeds detect directives
line-by-line and report a syntax error on every diagram in the file. One line costs nothing and works
everywhere.

For the same reason every diagram declares `classDef default`: if a renderer ignores the directive
entirely, unclassed nodes still come out in the house style instead of Mermaid's default yellow.
(The one exception is `stateDiagram`, where `default` is a reserved token and `classDef default` is a
parse error — see `check-diagrams.py`.)

## The palette

| Token | Hex | Class | Used for |
|---|---|---|---|
| **Ink** | `#2d3436` | — | All text. Near-black charcoal, not pure black. |
| **Line** | `#9aa3ab` | `n` | Default node borders and edges |
| **Container** | `#d4dae0` | — | Subgraph / boundary borders |
| **Primary** | `#2f6fb8` | `crit` | **The path that matters** — the flow the reader should follow first |
| **Primary wash** | `#eef4fb` | `crit` | Fill behind a primary node |
| **Warn** | `#c0522d` | `warn` | A refusal, a failure, a control that blocks. **Only that.** |
| **Warn wash** | `#fdf0ec` | `warn` | Fill behind a warning node |
| **Data wash** | `#f4f7fa` | `data` | Stores — databases, buckets, queues |
| **Muted** | `#cfd6dc` / `#7a8288` | `mut` | Deliberately de-emphasised: context, optional, legacy |
| **Canvas** | `#ffffff` | — | Everything else |

**Two accents, and they mean different things.** Blue is *"follow this"*. Orange-red is *"this is
where it refuses"*. Everything that is neither is gray — if half the diagram is coloured, none of it
reads as important.

This palette is taken from a production architecture figure: pale tinted lanes, thin gray
containers, one blue path through the middle, and red reserved for the places the system says no.

## Line semantics — these are load-bearing

| Style | Means |
|---|---|
| **Solid blue, 2px** (`==>` + `linkStyle stroke:#2f6fb8`) | The primary path. The thing the reader should follow first. |
| Solid gray, 1.3px (`-->`) | A normal, concrete relationship |
| **Dashed gray** (`-.->`)| Context, a side effect, an out-of-band signal, or something asynchronous |
| **Dashed crimson** | The path that becomes active *after* a failure or a flip |
| Dotted | A logical grouping, not a data flow |

## Containers

Nest them, outermost first, each with a short label that says what the boundary *is*:

```
Region → VPC → Availability Zones → subnet tier
Source → CI → Registry → Cluster
```

A boundary label should carry a fact, not just a name:
`VPC · non-overlapping CIDR · VPC endpoints` beats `VPC`.

## Node captions

Two lines. Name, then the detail that makes it non-generic.

```
RDS PostgreSQL<br/><span>Multi-AZ · KMS · 14d backups</span>
```

**The second line is where the diagram earns its place.** `RDS` tells the reader nothing they
couldn't guess; `Multi-AZ · KMS · 14d backups` tells them the design decision.

---

## The standard header

Paste this above every flowchart. It is the whole theme.

````
<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![The standard header — diagram](../../../_figures/curriculum-_shared-diagrams-STYLE-0-1a8d7695.png)

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
```

</details>
````

Then colour the edges that matter:

```
linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px
```

`linkStyle` indexes are **zero-based in declaration order**. Count carefully — an off-by-one paints
the wrong arrow, which is worse than painting none.

---

## Direction

| Use | Direction |
|---|---|
| A pipeline, a sequence, a timeline | `flowchart LR` |
| A layered architecture, a hierarchy | `flowchart TB` |
| A decision tree | `flowchart TD` |
| An ordered interaction between actors | `sequenceDiagram` |
| State machine (pod lifecycle, incident severity) | `stateDiagram-v2` |
| A schedule or a roadmap | `gantt` |

**`LR` for anything with more than five steps.** `TB` produces a tall thin column that nobody scrolls.

---

## When a diagram earns its place

Draw one when the **structure** is the point — a topology, an ordering, a boundary, a decision tree.

**Do not** draw one for a list with arrows between the items. That is a list, and a table reads
faster. Three of the diagrams in this curriculum were deleted for exactly that reason.

---

## Mermaid vs Graphviz — the honest split

| | Mermaid | Graphviz + icons |
|---|---|---|
| Renders on GitHub | **Yes, natively** | No — commit the SVG |
| Diffable in a PR | **Yes, it's text** | The source is, the SVG isn't |
| Toolchain needed | **None** | `graphviz` + icon assets |
| Vendor service icons | **No** | **Yes** |
| Layout control | Limited | Precise |

**Use Mermaid for everything in-repo.** It renders where the reader already is and survives without
a build step.

**Use Graphviz with vendor icons for the three flagship project architecture diagrams only** — those
are portfolio artifacts a hiring manager looks at, and that is where the extra polish returns
something. `generate-figures.py` in this directory produces them in the same visual language.
