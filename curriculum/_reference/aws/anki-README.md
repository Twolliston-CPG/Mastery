# AWS SAA-C03 Anki Flashcard Deck

## 719 Exam-Focused Flashcards

### Card Breakdown

| File | Phases | Cards |
|------|--------|-------|
| `cards-phase1-2.tsv` | Foundations + Compute/Storage | 279 |
| `cards-phase3-4.tsv` | Databases/Integration + Security/Monitoring | 261 |
| `cards-phase5-6.tsv` | Advanced Architectures + Exam Strategy | 179 |
| **`aws-saa-complete-deck.tsv`** | **All phases combined** | **719** |

### Topic Tags

Cards are tagged hierarchically for targeted study:

```
AWS-SAA::Phase1::IAM
AWS-SAA::Phase1::VPC
AWS-SAA::Phase1::Route53
AWS-SAA::Phase1::ELB
AWS-SAA::Phase1::WellArchitected
AWS-SAA::Phase1::GlobalInfra
AWS-SAA::Phase2::EC2
AWS-SAA::Phase2::AutoScaling
AWS-SAA::Phase2::EBS
AWS-SAA::Phase2::Lambda
AWS-SAA::Phase2::Containers
AWS-SAA::Phase2::Beanstalk
AWS-SAA::Phase2::S3
AWS-SAA::Phase2::EFS
AWS-SAA::Phase2::FSx
AWS-SAA::Phase2::StorageGateway
AWS-SAA::Phase2::Snow
AWS-SAA::Phase3::RDS
AWS-SAA::Phase3::Aurora
AWS-SAA::Phase3::DynamoDB
AWS-SAA::Phase3::ElastiCache
AWS-SAA::Phase3::OtherDBs
AWS-SAA::Phase3::SQS
AWS-SAA::Phase3::SNS
AWS-SAA::Phase3::EventBridge
AWS-SAA::Phase3::Kinesis
AWS-SAA::Phase3::APIGateway
AWS-SAA::Phase3::StepFunctions
AWS-SAA::Phase4::KMS
AWS-SAA::Phase4::SecretsManager
AWS-SAA::Phase4::ParameterStore
AWS-SAA::Phase4::ACM
AWS-SAA::Phase4::WAF
AWS-SAA::Phase4::Shield
AWS-SAA::Phase4::GuardDuty
AWS-SAA::Phase4::Inspector
AWS-SAA::Phase4::Macie
AWS-SAA::Phase4::Config
AWS-SAA::Phase4::SecurityHub
AWS-SAA::Phase4::Cognito
AWS-SAA::Phase4::CloudWatch
AWS-SAA::Phase4::CloudTrail
AWS-SAA::Phase4::SystemsManager
AWS-SAA::Phase4::CloudFormation
AWS-SAA::Phase4::TrustedAdvisor
AWS-SAA::Phase5::Migration
AWS-SAA::Phase5::DR
AWS-SAA::Phase5::CloudFront
AWS-SAA::Phase5::GlobalAccelerator
AWS-SAA::Phase5::Hybrid
AWS-SAA::Phase5::Serverless
AWS-SAA::Phase5::Containers
AWS-SAA::Phase5::Analytics
AWS-SAA::Phase6::KeyNumbers
AWS-SAA::Phase6::Ports
AWS-SAA::Phase6::Keywords
```

### How to Import into Anki

#### Option 1: Import the Complete Deck (Recommended)

1. Open **Anki** desktop application
2. Go to **File > Import**
3. Select `aws-saa-complete-deck.tsv`
4. Configure import settings:
   - **Type**: "Basic"
   - **Deck**: Create a new deck called "AWS SAA-C03"
   - **Fields separated by**: Tab
   - **Field 1**: Front
   - **Field 2**: Back
   - **Field 3**: Tags
   - Check **"Allow HTML in fields"**
5. Click **Import**
6. All 719 cards will be imported with hierarchical tags

#### Option 2: Import by Phase

Import each phase file separately into different sub-decks:
- `cards-phase1-2.tsv` → Deck "AWS SAA-C03::Phase 1-2"
- `cards-phase3-4.tsv` → Deck "AWS SAA-C03::Phase 3-4"
- `cards-phase5-6.tsv` → Deck "AWS SAA-C03::Phase 5-6"

### Recommended Study Settings

#### New Cards Per Day
- **Weeks 1-8** (learning phases): 20-30 new cards/day
- **Weeks 9-10** (advanced): 15-20 new cards/day
- **Weeks 11-12** (review): 0 new cards, focus on review only

#### Review Settings
- **Maximum reviews/day**: 200-300 (increase as cards accumulate)
- **Learning steps**: 1m 10m 1d (default is fine)
- **Graduating interval**: 1 day
- **Easy interval**: 4 days

### Study Tips

1. **Study by phase** — use tags to filter cards matching your current study week
2. **Don't skip hard cards** — if you keep getting a card wrong, that's exactly what you need to study
3. **Review every day** — spaced repetition only works with daily review
4. **Supplement with labs** — flashcards build knowledge, labs build understanding
5. **Flag cards to edit** — if a card is confusing, mark it and rewrite in your own words

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- 719 Exam-Focused Flashcards
- Card Breakdown
- Topic Tags
- How to Import into Anki

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
