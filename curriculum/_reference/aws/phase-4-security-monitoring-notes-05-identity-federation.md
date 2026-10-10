# 05 — Identity & Federation (Cognito, IAM Identity Center, STS)

## Overview

Identity federation allows users to access AWS resources using existing credentials from external identity providers (Google, SocialGraph, corporate Active Directory, etc.) instead of creating IAM users for each person. The exam tests Cognito heavily, especially the difference between User Pools and Identity Pools.

---

## Amazon Cognito

Cognito has two distinct components that work together but serve different purposes.

### User Pools vs Identity Pools

| Feature | User Pools | Identity Pools (Federated Identities) |
|---------|------------|--------------------------------------|
| **Primary function** | **Authentication** (who are you?) | **Authorization** (what can you access?) |
| **What it provides** | JWT tokens (ID token, access token, refresh token) | Temporary AWS credentials (access key, secret key, session token) |
| **User directory** | Yes — manages user sign-up, sign-in, profiles | No — does not store users |
| **Sign-up/sign-in** | Built-in hosted UI or custom UI | No sign-in capability |
| **MFA** | Yes | No (handled by upstream IdP or User Pool) |
| **Social sign-in** | Yes (Google, SocialGraph, Apple, Amazon) | Yes (via User Pool or directly) |
| **SAML/OIDC federation** | Yes (enterprise IdP like IdentityCo, Azure AD) | Yes |
| **Outputs** | JWT tokens for API authentication | AWS STS credentials for AWS service access |
| **Use case** | "Sign in to my web/mobile app" | "Access S3, DynamoDB, etc. from my app" |
| **Lambda triggers** | Yes (pre/post sign-up, pre/post auth, custom message) | No |
| **Customizable** | Hosted UI branding, Lambda triggers, custom auth flows | IAM role mapping based on user attributes |

### When You Need Both Together

Most real-world applications use **both** — User Pool for authentication, then Identity Pool to get AWS credentials.

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![When You Need Both Together — sequence diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-0-b65b5d03.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
sequenceDiagram
  autonumber
  participant U as User / client<br/>(browser or app)
  participant UP as Cognito User Pool
  participant IP as Cognito Identity Pool
  participant STS as AWS STS
  participant SVC as AWS services<br/>(S3, DynamoDB, API Gateway)
  U->>UP: Sign in — username/password, or a social provider
  UP-->>U: JWT tokens (ID, access, refresh)
  U->>IP: Exchange the ID token
  IP->>IP: Validate the JWT, map claims to an IAM role
  IP->>STS: AssumeRoleWithWebIdentity
  STS-->>U: Temporary AWS credentials
  U->>SVC: Signed API call with those credentials
  Note over U,SVC: The credentials are short-lived and scoped to the mapped role.<br/>Nothing long-lived is ever stored on the device.
```

</details>

### Cognito User Pool — Authentication Flow

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Cognito User Pool — Authentication Flow — diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-1-93bac38c.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph A["Option A — Hosted UI &nbsp;<i>(simplest)</i>"]
    direction TB
    A1["User"] --> A2["Cognito Hosted UI<br/><i>AWS-hosted sign-in page</i>"] --> A3["Cognito validates"] --> A4["Redirect back to your app<br/>with tokens in the URL fragment"]
  end
  subgraph B["Option B — API / SDK &nbsp;<i>(your own UI)</i>"]
    direction TB
    B1["User"] --> B2["Your app's UI collects credentials"] --> B3["<code>InitiateAuth</code> from your app"] --> B4["Cognito returns JWT tokens to your app"]
  end
  subgraph C["Option C — Social or SAML federation"]
    direction TB
    C1["User"] --> C2["Cognito redirects to the IdP<br/><i>Google · a corporate SAML provider</i>"] --> C3["User authenticates at the IdP"] --> C4["IdP returns a token or SAML assertion"] --> C5["Cognito issues <b>its own</b> JWT tokens"]
  end
  class A1,A2,A3,B1,B2,B3,C1,C2,C3,C4 n
  class A4,B4 data
  class C5 crit

%% Option C is the one to understand: whatever the upstream provider is, your
%% application only ever sees a Cognito token. That indirection is why adding a
%% second identity provider later costs you no application changes.
```

</details>

### Cognito Identity Pool — Authorization Flow

**Authenticated users**

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Cognito Identity Pool — Authorization Flow — diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-2-79a510cb.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  T["JWT from the User Pool<br/><i>or a SAML / OIDC token</i>"]
  IP["Identity Pool<br/><i>maps the token to the <b>authenticated</b> IAM role</i>"]
  CR["AccessKeyId · SecretAccessKey · SessionToken"]
  APP["The app calls AWS services directly"]
  T ==> IP ==> CR ==> APP
  class T data
  class IP crit
  class CR crit
  class APP n
  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

**Unauthenticated (guest) users**

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Cognito Identity Pool — Authorization Flow — diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-3-ae93f405.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  N["No token"]
  IP["Identity Pool<br/><i>maps to the <b>unauthenticated</b> IAM role</i>"]
  CR["Temporary credentials<br/><i>minimal permissions</i>"]
  N ==> IP ==> CR
  class N mut
  class IP crit
  class CR n
  linkStyle 0,1 stroke:#2f6fb8,stroke-width:2px
```

</details>

The unauthenticated role is the one that gets forgotten. It is real IAM, attached to anyone who can
reach the Identity Pool id — which is shipped inside your mobile app. Whatever it permits, the
internet permits.

### Key Cognito Features for the Exam

| Feature | Details |
|---------|---------|
| **Hosted UI** | Pre-built sign-in page with customizable branding |
| **Adaptive authentication** | Risk-based adaptive authentication (block suspicious sign-ins) |
| **Lambda triggers** | Custom logic at key points in auth flow (pre-sign-up validation, post-auth actions, custom email, migrate user) |
| **Groups** | Assign users to groups with different IAM roles |
| **Custom attributes** | Add custom fields to user profiles |
| **Password policy** | Configure minimum length, required characters |
| **Account recovery** | Email or phone verification |

---

## Federation Methods

### SAML 2.0 Federation (Enterprise)

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![SAML 2.0 Federation (Enterprise) — diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-4-1a2ec72a.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  U["Corporate user"]
  IDP["Corporate IdP<br/><i>Active Directory + federation service</i>"]
  SA["SAML assertion"]
  STS["AWS STS<br/><code>AssumeRoleWithSAML</code>"]
  CR["Temporary AWS credentials"]
  ACC["Console or API access"]
  U ==> IDP ==> SA ==> STS ==> CR ==> ACC
  class U mut
  class IDP crit
  class SA data
  class STS crit
  class CR crit
  class ACC n
  linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px

%% No IAM user, no access key, nothing to leak. The role is assumed for an hour
%% at a time against an assertion the corporate IdP signed -- which also means
%% that disabling someone in Active Directory removes their AWS access
%% immediately, with no separate offboarding step to forget.
```

</details>

- Used for enterprise/corporate federation
- Common IdPs: Active Directory + ADFS, IdentityCo, Ping Identity, Azure AD
- User does not need an IAM user account
- STS returns temporary credentials

### OIDC (OpenID Connect) Federation

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![OIDC (OpenID Connect) Federation — diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-5-52900899.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  U["Mobile or web user"]
  OP["OIDC provider<br/><i>a public identity provider</i>"]
  TK["OIDC token"]
  STS["AWS STS<br/><code>AssumeRoleWithWebIdentity</code>"]
  CR["Temporary AWS credentials"]
  U ==> OP ==> TK ==> STS ==> CR
  class U mut
  class OP n
  class TK data
  class STS crit
  class CR crit
  linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px

%% The same mechanism IRSA uses in EKS: the cluster is registered as an OIDC
%% provider, the pod presents a projected ServiceAccount token, and STS hands
%% back credentials scoped to a role. One primitive, two very different-looking
%% features.
```

</details>

- **AWS recommends using Cognito Identity Pools instead of direct STS calls** for web/mobile apps
- Direct STS `AssumeRoleWithWebIdentity` works but Cognito is preferred (more features)

### Custom Identity Broker

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Custom Identity Broker — diagram](../../../_figures/curriculum-_reference-aws-phase-4-security-monitoring-notes-05-identity-federation-6-4afc422b.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  U["User"]
  BR["Custom identity broker<br/><i>your application</i>"]
  LDAP["Corporate LDAP / AD"]
  STS["STS<br/><code>AssumeRole</code> or <code>GetFederationToken</code>"]
  CR["Temporary credentials returned to the user"]
  U ==> BR ==> LDAP
  BR ==> STS ==> CR
  class U mut
  class BR crit
  class LDAP n
  class STS crit
  class CR crit
  linkStyle 0,2,3 stroke:#2f6fb8,stroke-width:2px

%% The legacy option, and the one to avoid now. Your broker holds long-lived AWS
%% credentials in order to mint short-lived ones, which puts the thing you were
%% trying to eliminate back in the middle of the diagram. Use SAML or OIDC
%% federation unless the identity source genuinely cannot speak either.
```

</details>

- Used when IdP is not SAML 2.0 compatible
- You build and manage the broker yourself
- Broker must have IAM permissions to call STS

---

## IAM Identity Center (formerly AWS SSO)

### What It Does
- **Single Sign-On** across multiple AWS accounts and business applications
- Central place to manage access for all AWS accounts in your Organization
- One login to access any account

### Key Features

| Feature | Description |
|---------|-------------|
| **Built-in identity store** | Create users and groups directly in IAM Identity Center |
| **External IdP** | Connect to Active Directory, IdentityCo, Azure AD via SAML 2.0 |
| **Permission Sets** | Define permissions (like IAM policies) and assign to users/groups per account |
| **AWS access portal** | Web portal where users see all accounts/apps they can access |
| **Multi-account access** | Assign different permissions per account (e.g., admin in dev, read-only in prod) |
| **Business app SSO** | SSO to Salesforce, Slack, Office 365, custom SAML apps |
| **Attribute-based access control (ABAC)** | Assign permissions based on user attributes (department, cost center) |

### IAM Identity Center vs Cognito

| IAM Identity Center | Cognito |
|---------------------|---------|
| For workforce users (employees) | For customer/external users (app users) |
| Accessing AWS accounts and business apps | Accessing your web/mobile application |
| Organization-level SSO | Application-level authentication |
| Replaces IAM users for human access | Provides user sign-up/sign-in for apps |

---

## AWS STS (Security Token Service)

### Key API Calls

| API Call | Use Case |
|----------|----------|
| `AssumeRole` | Cross-account access, least-privilege temporary access within same account |
| `AssumeRoleWithSAML` | Return temporary credentials after SAML authentication |
| `AssumeRoleWithWebIdentity` | Return temporary credentials after OIDC authentication (prefer Cognito) |
| `GetSessionToken` | MFA-protected API access (temporary credentials with MFA context) |
| `GetFederationToken` | Temporary credentials for federated users (via custom identity broker) |
| `DecodeAuthorizationMessage` | Decode an encoded authorization failure message |

### STS Credentials
- All STS credentials are temporary
- Include: AccessKeyId, SecretAccessKey, SessionToken, Expiration
- Duration: 15 minutes to 12 hours (depends on API call and role config)
- Cannot be revoked individually (but you can revoke all sessions for a role)

---

## Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| "Web app needs user sign-up with email verification" | Cognito User Pool |
| "Mobile app users need to upload to S3 directly" | Cognito User Pool (auth) + Identity Pool (AWS creds for S3) |
| "Allow unauthenticated guests limited S3 read access" | Cognito Identity Pool (unauthenticated role) |
| "Corporate users SSO into multiple AWS accounts" | IAM Identity Center |
| "Federation with Active Directory for AWS Console access" | SAML 2.0 with STS AssumeRoleWithSAML, or IAM Identity Center |
| "Social login (Google/SocialGraph) for mobile app" | Cognito User Pool with social provider |
| "10,000 external users need app access — don't create IAM users" | Cognito User Pool |
| "Employees need different permissions in dev vs prod accounts" | IAM Identity Center with Permission Sets |
| "Need MFA for API calls" | STS GetSessionToken |
| "Cross-account access from Account A to Account B" | STS AssumeRole |

---

## Next Steps

- Continue to **Note 06: CloudWatch** for metrics, alarms, logs, and dashboards
- Return to **Lab 05** after completing the monitoring notes

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Amazon Cognito
- Federation Methods
- IAM Identity Center (formerly AWS SSO)
- AWS STS (Security Token Service)

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
