# Microsoft Threat Modeling Tool

## Overview

The Microsoft Threat Modeling Tool (TMT) is a free desktop application that provides a structured approach to threat modeling using data flow diagrams and automated threat generation.

**Key Features:**
- Native Windows application
- STRIDE-based threat generation
- Customizable templates and rules
- Azure-specific templates
- Integration with SDL process

---

## Installation

### System Requirements

- Windows 10 or later
- .NET Framework 4.7.2+

### Download

```
1. Visit: https://aka.ms/threatmodelingtool
2. Download the installer
3. Run ThreatModelingTool.exe
```

### First Launch

```
On first launch:
1. Accept license agreement
2. Choose template:
   - SDL TM Knowledge Base (default)
   - Azure Threat Model Template
   - Custom template
3. Start modeling
```

---

## Interface Overview

**Microsoft Threat Modeling Tool — the layout**

| Pane | Contains |
|---|---|
| **Stencils** *(left)* | Process ○ · External entity □ · Data store ═ · Data flow → · Trust boundary ┄ |
| **Canvas** *(centre)* | Where you draw the data flow diagram |
| **Threat list** *(bottom)* | Generated threats, one row each |

**Threat list columns**

| ID | Title | Category | State | Priority |
|---|---|---|---|---|
| 1 | SQL injection | Tampering | Active | High |
| 2 | Authentication bypass | Spoofing | Active | High |

The tool generates the threat list *from the diagram* by applying STRIDE per element. That is its
strength and its trap: it will never miss a category, and it will happily produce two hundred
generated threats for a diagram of six elements. Triaging them — marking most as not applicable, with
a reason — is the actual work, and the reason matters more than the verdict.

---

## Creating a Threat Model

### Step 1: Start New Model

```
File → New Model → Select Template
- SDL TM Knowledge Base (general)
- Azure Threat Model (cloud)
- Custom (your templates)
```

### Step 2: Set Model Properties

```
Right-click canvas → Properties

Model Properties:
- Title: "Customer Portal API"
- Author: "Security Team"
- Date: Auto-populated
- Version: "1.0"
- Status: "Draft"
```

### Step 3: Add Elements

**Drag and drop from stencils:**

| Stencil | Use Case |
|---------|----------|
| Generic Process | Applications, services |
| Web Application | Web servers, APIs |
| Windows Service | Background services |
| Database | SQL Server, PostgreSQL |
| File System | File storage |
| Browser | User client |
| External Interactor | Third-party systems |

### Step 4: Configure Element Properties

```
Right-click element → Properties

Process Properties:
- Name: "API Gateway"
- Code Type: Web Application
- Runs As: Network Service
- Sanitizes Input: Yes/No
- Validates Input: Yes/No
- Accepts Binary Data: Yes/No
- Runs at Elevated Privileges: Yes/No
```

### Step 5: Add Data Flows

```
1. Click Data Flow in stencils
2. Click source element
3. Drag to destination element
4. Configure flow properties:
   - Name: "User Credentials"
   - Protocol: HTTPS
   - Data Classification: Confidential
   - Authenticated: Yes
   - Authorization: Role-based
```

### Step 6: Add Trust Boundaries

```
1. Click Trust Boundary in stencils
2. Draw around elements
3. Name the boundary:
   - "DMZ"
   - "Internal Network"
   - "Cloud VPC"
```

---

## Automatic Threat Generation

### Running Analysis

```
View → Analysis View

TMT automatically generates threats based on:
1. Element types
2. Element properties
3. Data flow characteristics
4. Trust boundary crossings
```

### Threat Properties

```
Each generated threat includes:
- ID: Unique identifier
- Title: Descriptive name
- Category: STRIDE category
- Description: Detailed explanation
- Interaction: Which elements involved
- State: Not Started, Active, Needs Investigation, Mitigated, Not Applicable
- Priority: High, Medium, Low
- Justification: Your notes
```

### Threat States

| State | Meaning | Action Required |
|-------|---------|-----------------|
| Not Started | New threat | Review and triage |
| Needs Investigation | Requires research | Gather more info |
| Active | Valid threat | Design mitigation |
| Mitigated | Controls in place | Document controls |
| Not Applicable | Not relevant | Document reason |

---

## Customizing Threat Generation

### Element Properties Impact

```yaml
# Setting these properties affects threat generation:

process:
  sanitizes_input: true    # Reduces injection threats
  validates_input: true    # Reduces tampering threats
  runs_elevated: false     # Reduces elevation threats
  handles_sensitive_data: true  # Increases disclosure threats

data_flow:
  encrypted: true          # Reduces interception threats
  authenticated: true      # Reduces spoofing threats
  crosses_boundary: true   # Increases attack surface
```

### Custom Templates

Create custom templates for your organization:

```xml
<!-- CustomTemplate.tb7 -->
<ThreatModel>
  <Stencils>
    <Stencil name="Kubernetes Pod">
      <Properties>
        <Property name="Container Runtime" type="dropdown">
          <Option>containerd</Option>
          <Option>Docker</Option>
          <Option>CRI-O</Option>
        </Property>
        <Property name="Privileged" type="boolean"/>
        <Property name="Host Network" type="boolean"/>
      </Properties>
    </Stencil>
  </Stencils>

  <ThreatRules>
    <Rule id="k8s-privileged-container">
      <Condition>
        <Element type="Kubernetes Pod">
          <Property name="Privileged" value="true"/>
        </Element>
      </Condition>
      <Threat category="ElevationOfPrivilege">
        <Title>Privileged Container Escape</Title>
        <Description>
          A privileged container can escape to the host system,
          potentially compromising the entire node.
        </Description>
        <Mitigation>
          Avoid privileged containers. Use specific capabilities
          with securityContext.capabilities.add instead.
        </Mitigation>
      </Threat>
    </Rule>
  </ThreatRules>
</ThreatModel>
```

---

## Azure Template

### Azure-Specific Elements

**Azure Template includes:**

- Compute
  - Virtual Machine
  - App Service
  - Azure Functions
  - Container Instance
  - AKS
- Storage
  - Blob Storage
  - SQL Database
  - Cosmos DB
  - Redis Cache
- Networking
  - Virtual Network
  - Load Balancer
  - Application Gateway
  - VPN Gateway
- Identity
  - Azure AD
  - Managed Identity
  - Key Vault
- Integration
  - Service Bus
  - Event Hub
  - Logic Apps


### Azure-Specific Threats

| Element | Specific Threats |
|---------|-----------------|
| Blob Storage | Anonymous access, SAS token abuse |
| App Service | Deployment slot swapping |
| Azure AD | Token theft, consent phishing |
| Key Vault | Access policy misconfiguration |
| AKS | Pod escape, RBAC bypass |

---

## Exporting Results

### Report Generation

```
File → Generate Report

Available formats:
- HTML (interactive)
- CSV (for import to tracking systems)
- Word document
```

### Report Contents

```
1. Executive Summary
   - Model overview
   - Threat statistics
   - Risk summary

2. Diagram Views
   - Full DFD
   - Trust boundaries highlighted

3. Threat List
   - All threats with details
   - Grouped by category or element
   - Status summary

4. Mitigation Summary
   - Implemented controls
   - Pending items
```

### Integration with DevOps

```yaml
# Azure DevOps pipeline integration
- task: PowerShell@2
  inputs:
    targetType: 'inline'
    script: |
      $model = Get-Content "$(Build.SourcesDirectory)/threat-model.tm7" -Raw
      $threats = [xml]$model | Select-Xml "//Threat[@State='Active']"

      if ($threats.Count -gt 0) {
        Write-Host "##vso[task.logissue type=warning]$($threats.Count) active threats"
        foreach ($t in $threats) {
          Write-Host "- $($t.Node.Title)"
        }
      }
```

---

## Best Practices

### Diagram Guidelines

```
1. Start with context diagram
   - System as single box
   - External entities
   - Major data flows

2. Decompose to components
   - One level at a time
   - Keep diagrams readable (7±2 elements)
   - Link related diagrams

3. Consistent naming
   - Use clear, descriptive names
   - Include technology where relevant
   - Match actual system names
```

### Threat Management

```
Workflow:
1. Generate threats automatically
2. Review each threat:
   - Is it applicable?
   - What is the real risk?
   - What controls exist?

3. Update properties:
   - Adjust element settings
   - Re-run analysis

4. Document mitigations:
   - Specific controls
   - Validation method
   - Owner

5. Track over time:
   - Version the model
   - Update with changes
   - Re-assess periodically
```

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New model | Ctrl + N |
| Open model | Ctrl + O |
| Save | Ctrl + S |
| Delete | Delete |
| Undo | Ctrl + Z |
| Redo | Ctrl + Y |
| Toggle analysis | F5 |
| Zoom in | Ctrl + Mouse wheel |

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Template not loading | Reinstall, check .NET version |
| Threats not generating | Check element properties, boundaries |
| Slow performance | Reduce diagram complexity, close other apps |
| Export fails | Run as administrator, check disk space |

---

## Next Steps

→ [pytm - Python Threat Modeling](pytm.md)
→ [Threagile - Threat Modeling as Code](threagile.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Interface Overview
- Creating a Threat Model
- Automatic Threat Generation
- Customizing Threat Generation

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
