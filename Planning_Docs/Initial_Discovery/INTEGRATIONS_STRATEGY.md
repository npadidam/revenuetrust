# Integrations Strategy — CTI, Collaboration & Communication Layer

**Platform:** Revenue Execution Platform  
**Date:** 2026-04-01  
**Scope:** Momentum, Zoom, CTI ecosystem, Slack, MS Teams, Email (phased)

---

## Table of Contents

1. [Integration Philosophy](#1-integration-philosophy)
2. [Signal Taxonomy — What Each Integration Provides](#2-signal-taxonomy--what-each-integration-provides)
3. [CTI Landscape & Prioritization](#3-cti-landscape--prioritization)
4. [Momentum Integration](#4-momentum-integration)
5. [Zoom Integration (Phone + Meetings)](#5-zoom-integration-phone--meetings)
6. [Other CTI Apps](#6-other-cti-apps)
7. [Slack Integration](#7-slack-integration)
8. [MS Teams Integration](#8-ms-teams-integration)
9. [Email Integration (Phase 3)](#9-email-integration-phase-3)
10. [Unified Signal Architecture](#10-unified-signal-architecture)
11. [How Signals Feed Forecasting & Commissions](#11-how-signals-feed-forecasting--commissions)
12. [Build vs. Partner Decision](#12-build-vs-partner-decision)
13. [Integration Roadmap](#13-integration-roadmap)

---

## 1. Integration Philosophy

Every integration must answer one question before being built:

**"Does this signal change a forecast decision or a commission outcome?"**

If yes — build it. If no — defer it.

The platform is not a data aggregator. It is a revenue decision engine. Every signal that flows in should either:

- Change what a manager submits in their forecast (forecast signal)
- Change when or how much a rep gets paid (commission signal)
- Surface a coaching opportunity for a manager (behavioral signal)
- Trigger a notification that prompts a human to take action (workflow signal)

This keeps integrations purposeful and prevents the platform from becoming a dashboard graveyard.

### Integration Layers

```
┌────────────────────────────────────────────────────────────┐
│                    SIGNAL SOURCES                          │
│                                                            │
│  CTI Layer          Collaboration Layer   Email Layer      │
│  ──────────         ─────────────────     ───────────      │
│  Gong               Slack                 Gmail (P3)       │
│  Momentum           MS Teams              Outlook (P3)     │
│  Zoom Phone                               Outreach (P3)    │
│  Dialpad                                  Salesloft (P3)   │
│  RingCentral                                               │
│  Aircall                                                   │
│  Salesforce CTI                                            │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│              SIGNAL NORMALIZATION LAYER                    │
│     Adapter per source → Canonical Signal Schema           │
│     deal_signals table / Deal_Signal__c object             │
└────────────────┬───────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌───────────────┐  ┌──────────────────┐
│  FORECASTING  │  │   COMMISSIONS    │
│   (Temenos)   │  │    (Kony)        │
│               │  │                  │
│ Signal badge  │  │ Clawback risk    │
│ Conflict alert│  │ Payout hold flag │
│ AI prediction │  │ Dispute evidence │
└───────────────┘  └──────────────────┘
        │                 │
        └────────┬────────┘
                 ▼
┌────────────────────────────────────────────────────────────┐
│           NOTIFICATION DELIVERY LAYER                      │
│     Slack · MS Teams · In-App · Email digest               │
└────────────────────────────────────────────────────────────┘
```

---

## 2. Signal Taxonomy — What Each Integration Provides

Not all signals are equal. This table defines what each source contributes and what platform feature it enables:

| Signal                                     | Source                   | Type     | Feeds Into                               |
| ------------------------------------------ | ------------------------ | -------- | ---------------------------------------- |
| Call sentiment (positive/negative/neutral) | Gong, Zoom, Dialpad      | Call     | Forecast risk badge, AI close prediction |
| Talk ratio (seller vs buyer)               | Gong, Chorus             | Call     | Deal health score                        |
| Decision maker engaged                     | Gong, Momentum           | Activity | Forecast category validation             |
| Competitor mentioned                       | Gong                     | Call     | Risk flag on deal row                    |
| Next steps confirmed                       | Gong                     | Call     | Deal velocity score                      |
| Email response time                        | Momentum                 | Email    | Staleness alert                          |
| Stakeholder map (who is engaged)           | Momentum                 | Activity | Multi-thread score                       |
| Relationship strength per contact          | Momentum                 | Activity | Deal health                              |
| Days since last activity                   | Momentum, Zoom           | Activity | Staleness / anomaly alert                |
| Call duration trend                        | Zoom, Dialpad, Aircall   | Call     | Engagement trend                         |
| Meeting attended (AE vs no-show)           | Zoom, Teams              | Calendar | Engagement score                         |
| Transcript keywords                        | Gong, Zoom, Dialpad      | Call NLP | Risk topics, champion language           |
| Forecast notification acknowledged         | Slack, Teams             | Workflow | Audit trail                              |
| Commission query from rep                  | Slack, Teams             | Workflow | Dispute initiation                       |
| Email thread sentiment                     | Gmail, Outlook (P3)      | Email    | Late-stage deal risk                     |
| Auto-logged activity count                 | Outreach, Salesloft (P3) | Activity | CRM hygiene score                        |

---

## 3. CTI Landscape & Prioritization

### The CTI Market — Who Matters

| Vendor                       | Type                          | Market Position                         | Salesforce Native            | API Quality               | Priority             |
| ---------------------------- | ----------------------------- | --------------------------------------- | ---------------------------- | ------------------------- | -------------------- |
| **Gong**                     | Conversation intelligence     | Market leader, $7B valuation            | Yes (managed pkg)            | Excellent REST + webhooks | P1 — already planned |
| **Momentum**                 | Email/calendar signal capture | Strong mid-market, Slack-native         | Yes                          | Good REST                 | P1 — already planned |
| **Zoom Phone**               | UCaaS + meetings              | 2nd largest video, growing CTI          | Yes (Salesforce integration) | Excellent REST + webhooks | P1                   |
| **Dialpad**                  | AI-native CTI                 | Strong AI transcription, mid-market     | Yes                          | Very good REST            | P2                   |
| **Aircall**                  | Cloud phone + CTI             | SMB/mid-market leader, API-first        | Yes                          | Excellent REST + webhooks | P2                   |
| **RingCentral**              | UCaaS legacy                  | Enterprise legacy, large installed base | Yes                          | Good REST                 | P2                   |
| **Salesloft**                | Sales engagement + CTI        | Strong enterprise, owns Drift           | Yes                          | Good REST                 | P3                   |
| **Outreach**                 | Sales engagement + CTI        | Strong enterprise                       | Yes                          | Good REST                 | P3                   |
| **Salesforce CTI (OpenCTI)** | Native CTI framework          | Salesforce embedded                     | Native                       | Framework-based           | P2                   |
| **Five9**                    | Contact centre                | Enterprise contact centre               | Yes                          | Good                      | P3 (different buyer) |
| **Twilio Flex**              | Programmable contact centre   | Developer-first                         | Via Twilio                   | Excellent                 | P3                   |
| **8x8**                      | UCaaS + contact centre        | Enterprise                              | Yes                          | Moderate                  | P3                   |
| **Cisco Webex**              | UCaaS enterprise              | Large enterprise, government            | Yes                          | Moderate                  | P3                   |

### Prioritization Rationale

**P1 (Build first):** Gong + Momentum + Zoom

- These three together cover >70% of the target market (enterprise software / SaaS / fintech companies)
- Gong is present in virtually every enterprise software sales team
- Zoom is the dominant video/phone platform post-2020
- Momentum fills the email/calendar signal gap Gong doesn't own

**P2 (Build next):** Dialpad + Aircall + Salesforce OpenCTI

- Dialpad: growing fast in AI-native CTI, strong mid-market, transcript quality rivals Gong
- Aircall: the API-first choice for fast-growing companies; high overlap with HubSpot users
- Salesforce OpenCTI: embedded CTI framework that lets any P2/P3 CTI vendor work within the Salesforce UI — building this once means all CTI vendors that support OpenCTI work automatically

**P3 (Later):** Salesloft, Outreach, RingCentral, Five9

- Salesloft and Outreach are sales engagement platforms with CTI as one feature — their primary value is cadence/sequence management, which is adjacent but not core to this platform
- RingCentral: large installed base but declining mindshare; engineering effort high, signal quality lower
- Five9 and contact centre vendors: different buyer persona (contact centre ops vs. sales ops)

---

## 4. Momentum Integration

### What Momentum Does

Momentum is purpose-built for capturing relationship and email signals from Gmail/Outlook and surfacing them in Slack. It auto-logs emails, meetings, and contacts to Salesforce without rep data entry, and provides relationship intelligence (who knows whom, how strong is the relationship, when did it last touch).

### Signals Available via Momentum API

| Signal                                      | API Field                    | Platform Use                    |
| ------------------------------------------- | ---------------------------- | ------------------------------- |
| Email response time (hours)                 | `response_time_hrs`          | Staleness flag in forecast row  |
| Last email date                             | `last_email_date`            | Days-since-activity calculation |
| Stakeholder count (unique contacts engaged) | `stakeholder_count`          | Multi-thread score              |
| Relationship strength per contact           | `relationship_score` (0–100) | Deal health composite           |
| Meeting attendance rate                     | `meeting_attended_pct`       | Engagement score                |
| Champion identified                         | `champion_contact_id`        | Forecast confidence boost       |
| Decision maker email response               | `dm_last_response_date`      | DM engaged flag                 |
| Sentiment of latest email thread            | `thread_sentiment`           | Risk signal                     |
| Auto-logged activity count                  | `auto_logged_count`          | CRM hygiene score               |
| Contact gone dark (no response > N days)    | `dark_contacts[]`            | Proactive alert                 |

### Integration Design

**Sync method:** Momentum webhook (real-time on email/meeting events) + daily full-sync batch

**Webhook events to subscribe:**

- `contact.went_dark` — fires when a key contact has not responded in configurable N days
- `stakeholder.added` — new contact engaged on deal
- `relationship.strength_changed` — relationship score crossed threshold
- `meeting.scheduled` / `meeting.attended` / `meeting.no_show`

**Slack-native advantage:** Momentum already delivers signals _into Slack_. Rather than duplicating this, the platform should:

1. Subscribe to Momentum's Slack-delivered alerts via Slack Events API
2. Enrich those alerts with forecast context (is this deal in Forecast category? What is the manager's submitted NBV?)
3. Re-deliver as a richer, contextual Slack message that links directly into the forecast app

This means the platform does not compete with Momentum's Slack experience — it extends it with forecast and commission context.

### Momentum → Forecast UI

In the forecast deal row expanded view, a **Relationship Panel** section:

```
Momentum Signals — Updated 2h ago
────────────────────────────────────
Stakeholders engaged:    4 contacts
Decision maker:          Last responded 3 days ago  🟢
Champion (Sarah Chen):   Relationship score 82/100  🟢
Last activity:           Email — Yesterday
Contacts gone dark:      1 contact (VP Finance)    🟡
Email response time:     4.2 hrs avg               🟢
```

---

## 5. Zoom Integration (Phone + Meetings)

### Why Zoom Is P1

Zoom expanded from video meetings into Zoom Phone (UCaaS), Zoom Contact Center, and Zoom Revenue Accelerator (their Gong-competitor). The Zoom ecosystem now covers:

- Video call recordings with transcription (Zoom Meetings)
- Phone call recordings with transcription (Zoom Phone)
- AI-summarized call notes (Zoom AI Companion)
- Calendar integration (Zoom Calendar)
- Contact engagement tracking

For companies that use Zoom but not Gong, Zoom's own call intelligence (Revenue Accelerator) provides Gong-equivalent signals. The platform should treat Zoom Revenue Accelerator as a first-class signal source alongside Gong.

### Zoom APIs Available

| API                          | What It Provides                                                 | Platform Use           |
| ---------------------------- | ---------------------------------------------------------------- | ---------------------- |
| Zoom Meetings API            | Meeting recordings, attendance, duration                         | Engagement score       |
| Zoom Phone API               | Call logs, recordings, duration, outcome                         | Activity signal        |
| Zoom Revenue Accelerator API | Deal risk score, call sentiment, next steps, competitor mentions | Direct Gong equivalent |
| Zoom Events webhooks         | Real-time meeting start/end, recording complete                  | Trigger signal refresh |
| Zoom Contact Center API      | Contact engagement, case data                                    | Enterprise signal      |

### Zoom Revenue Accelerator vs. Gong

| Feature                        | Gong                 | Zoom Revenue Accelerator                |
| ------------------------------ | -------------------- | --------------------------------------- |
| Call recording + transcription | ✅ Best-in-class     | ✅ Strong (leverages Zoom native)       |
| Deal risk score                | ✅                   | ✅                                      |
| Call sentiment                 | ✅                   | ✅                                      |
| Competitor detection           | ✅ Strong NLP        | ✅ Good                                 |
| Email signal capture           | ✅ (via Gong Engage) | ❌ (Meetings only)                      |
| CRM auto-log                   | ✅                   | ✅                                      |
| Market share                   | Dominant             | Growing fast                            |
| Price                          | $100–140/user/mo     | Bundled with Zoom Phone ($10–30 add-on) |

**Key point for platform:** For companies using Zoom Phone, Zoom Revenue Accelerator is already included or cheap to add. The platform should treat it as the Gong equivalent for Zoom shops. Single canonical signal schema means the platform doesn't care whether signals come from Gong or Zoom Revenue Accelerator — both write to the same `deal_signals` table.

### Zoom Integration Design

**Primary connection:** Zoom OAuth 2.0 app (published in Zoom App Marketplace)

**Webhooks to subscribe:**

- `recording.completed` — transcription available; trigger sentiment analysis
- `meeting.ended` — meeting attended; update engagement score
- `phone.callee_missed` — missed call; contribute to staleness score
- `phone.recording_completed` — phone call transcription ready

**Data extraction flow:**

```
Zoom webhook → Platform webhook receiver
    → Fetch transcript via Zoom Recordings API
    → Run NLP pipeline (sentiment, keyword extraction, next steps detection)
    → Write to deal_signals table (matched to Opportunity via CRM contact lookup)
    → Trigger forecast row refresh if deal is in active forecast period
    → Publish Slack/Teams notification if risk score crossed threshold
```

**Zoom-specific signal additions to canonical schema:**

| Field                       | Source                   | Notes                                   |
| --------------------------- | ------------------------ | --------------------------------------- |
| `zoom_meeting_count_30d`    | Zoom Meetings            | Meetings in last 30 days                |
| `zoom_avg_meeting_duration` | Zoom Meetings            | Engagement depth                        |
| `zoom_no_show_count`        | Zoom Meetings            | Prospect no-shows — strong churn signal |
| `zoom_phone_call_count_30d` | Zoom Phone               | Outbound call activity                  |
| `zoom_revenue_accel_score`  | Zoom Revenue Accelerator | Direct deal risk (if enabled)           |
| `zoom_next_step_confirmed`  | Zoom Revenue Accelerator | Next steps from last call               |

---

## 6. Other CTI Apps

### Dialpad

**Why it matters:** Dialpad is the fastest-growing AI-native CTI vendor. Every call is transcribed in real-time (not async), and their AI summary (Ai Recap) generates call summaries automatically. Strong in mid-market SaaS companies.

**Unique signals:**

- `dialpad_ai_sentiment` — real-time sentiment (not post-call batch like Gong)
- `dialpad_ai_action_items` — extracted action items from call
- `dialpad_call_score` — proprietary quality score
- `dialpad_coaching_moments` — specific moments flagged for manager coaching

**Integration:** Dialpad Webhooks API + Dialpad Data Export API. OAuth 2.0. Well-documented.

**Platform advantage:** Dialpad's real-time sentiment means the platform can update deal signals _during_ a call, not just after. For deals in the active forecast, a real-time signal drop could trigger an in-app alert to the manager.

---

### Aircall

**Why it matters:** Aircall is the API-first cloud phone for fast-growing companies. Extremely popular with HubSpot customers. When the platform expands to HubSpot adapter (Phase 3), Aircall is the most common CTI in that segment.

**Unique signals:**

- `aircall_call_duration` — strong proxy for engagement quality
- `aircall_missed_call_count` — prospect responsiveness
- `aircall_first_call_resolution` — CS signal (useful for renewal commission holds)
- `aircall_tag_list` — custom tags added by reps post-call (can be mapped to deal stages)

**Integration:** Aircall Webhooks (events: `call.ended`, `call.missed`, `voicemail.created`) + REST API.

---

### Salesforce OpenCTI Framework

**Why it matters:** Rather than building separate integrations for every CTI vendor, Salesforce's OpenCTI framework provides a standard interface that any CTI vendor implementing the Salesforce CTI adapter can plug into. Building an OpenCTI listener once means RingCentral, Avaya, Genesys, and any future OpenCTI-compliant vendor works automatically within the Salesforce-deployed version of the platform.

**What to capture from OpenCTI:**

- `callStarted` / `callEnded` events → update last activity timestamp
- `screenPopInfo` — which record the call was logged against (deal matching)
- Call outcome codes → map to platform signal (connected/voicemail/no-answer)
- Duration → engagement signal

**Implementation:** Salesforce OpenCTI JavaScript API in LWC components. Single implementation, multi-vendor coverage.

---

## 7. Slack Integration

### What Slack Delivers to the Platform

Slack serves two distinct functions:

1. **Inbound notifications** — platform pushes alerts to Slack (deal risk, forecast status, commission updates)
2. **Outbound actions** — reps and managers take actions from within Slack (submit forecast acknowledgment, raise commission dispute, approve a hold release)

The goal is to bring the platform's key decision moments into Slack so users don't need to switch context to the web app for routine actions.

### Slack App Architecture

```
Platform Backend
    │
    ├──► Slack Incoming Webhooks (simple one-way push notifications)
    │
    └──► Slack Bolt SDK (bidirectional: events, interactive components, slash commands)
             │
             ├── Events API (listens to messages, reactions, mentions)
             ├── Block Kit (rich interactive messages with buttons, modals)
             ├── Slash Commands (/forecast, /commission, /dealhealth)
             └── Shortcuts (right-click actions on messages)
```

### Notification Types

#### Forecast Notifications

| Trigger                       | Channel               | Recipients                           | Message Content                                                                     |
| ----------------------------- | --------------------- | ------------------------------------ | ----------------------------------------------------------------------------------- |
| Forecast period opens         | #sales-forecast or DM | All forecast users                   | Period name, open/close dates, territory assigned, link to forecast app             |
| Manager submits forecast      | DM                    | Their sub-director                   | "Team X has submitted Q2 forecast. Total: $4.2M across 23 deals. Review →"          |
| Director submits to COO       | DM                    | COO                                  | Territory submitted, total NBV, drill-down link                                     |
| Forecast frozen by COO        | #sales-ops            | All directors                        | Region, frozen total, frozen timestamp                                              |
| Forecast deadline approaching | DM                    | Users with unsaved/unsubmitted deals | "You have 14 deals unsaved in Q2 forecast. Deadline: Friday 5pm. Submit now →"      |
| Deal signal conflict detected | DM                    | Deal owner's manager                 | "Barclays (Forecast, $1.2M) has a High risk score from Gong. Consider reviewing. →" |
| Quarter slippage detected     | DM                    | Deal owner + manager                 | "HSBC has slipped for the 3rd consecutive quarter. Now in Q3. →"                    |

#### Commission Notifications

| Trigger                            | Channel | Recipients             | Message Content                                                                                                           |
| ---------------------------------- | ------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Deal closes, commission calculated | DM      | Rep                    | "Congratulations! $8,400 commission calculated for Barclays deal. Paid next cycle. →"                                     |
| Accelerator threshold crossed      | DM      | Rep                    | "You've crossed 100% quota attainment. Quarterly accelerator now active! Current earnings: $42,000."                      |
| Commission payment processed       | DM      | Rep                    | "Payment of $12,600 processed for March cycle. YTD: $67,200."                                                             |
| Commission hold applied            | DM      | Rep                    | "Commission hold on ING deal ($3,200) — renewal ACV quota not yet met. Hold releases when Q3 renewal target is achieved." |
| Clawback triggered                 | DM      | Rep + Manager          | "Clawback of $2,800 applied — HSBC contract terminated within 90 days of close. Balance adjusted."                        |
| Draw request submitted             | DM      | Rep + Commission Admin | "Draw request of $5,000 submitted by [Rep Name]. Pending admin approval."                                                 |

#### Deal Signal Notifications

| Trigger                                | Channel | Recipients           | Message Content                                                                                                    |
| -------------------------------------- | ------- | -------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Contact goes dark                      | DM      | Deal AE + Manager    | "VP Finance at Barclays has not responded in 14 days. Last contact: Sarah Chen. Relationship score dropped to 42." |
| Decision maker re-engages              | DM      | Deal AE              | "Good news: CFO at HSBC opened your proposal email and responded. Momentum score: 78 (+12)."                       |
| Gong risk score crossed High threshold | DM      | Deal owner + manager | "Deal risk: [Deal Name] Gong risk score moved to High (82). Last call: negative sentiment on pricing. Review →"    |
| Competitor first mentioned             | DM      | Deal AE + Manager    | "Competitor mention detected: 'Clari' mentioned in latest call for Barclays deal."                                 |

### Slack Slash Commands

**`/forecast [territory] [period]`**
Opens a Slack modal with the user's current forecast summary:

- Total submitted NBV by quarter
- Count of deals: New / Dirty / Saved / Submitted
- Deadline status
- Quick link to open forecast app

**`/commission [quarter]`**
Opens a Slack modal showing the rep's commission summary:

- YTD earnings
- Current quarter: eligible, paid, on hold
- Attainment % with accelerator threshold distance
- "What if I close [deal]?" quick simulator

**`/dealhealth [opportunity name or number]`**
Returns a deal health card in Slack:

- Gong risk score + trend
- Momentum relationship score
- Days since last activity
- Decision maker status
- Current forecast category + manager's submitted NBV

**`/holdrelease [commission hold ID]`** (Admin only)
Initiates a hold release workflow from Slack — admin approves in the Slack modal, platform updates Comp_Calculation\_\_c hold flag.

### Interactive Actions from Slack

Using Slack Block Kit buttons and modals, users can take these actions without opening the web app:

| Action                                   | Triggered By                      | What Happens                                                   |
| ---------------------------------------- | --------------------------------- | -------------------------------------------------------------- |
| Acknowledge forecast submission reminder | Button in DM                      | Logs acknowledgment, clears reminder                           |
| Approve commission hold release          | Button in admin DM                | Calls platform API, updates hold flag                          |
| Raise commission dispute                 | Button in commission notification | Opens modal: reason picker + free text; creates dispute record |
| Snooze deal signal alert                 | Button in risk alert              | Snoozes for 7 days, logs reason                                |
| Open deal in forecast app                | Button in any deal alert          | Deep link to deal row in forecast app                          |

### Slack Channel Strategy

| Channel                       | Purpose                                           | Audience               |
| ----------------------------- | ------------------------------------------------- | ---------------------- |
| `#forecast-[region]-[period]` | Regional forecast thread for the period           | Regional team          |
| `#commission-announcements`   | Threshold crossed, payment processed              | All reps               |
| `#revenue-ops-alerts`         | Signal conflicts, anomalies, frozen forecasts     | RevOps / Sales Ops     |
| DMs                           | Personal notifications (commission, deal signals) | Individual rep/manager |

---

## 8. MS Teams Integration

### Architecture Differences from Slack

MS Teams uses Microsoft's Bot Framework and Graph API rather than Slack's Bolt SDK. Key differences:

- **Adaptive Cards** replace Slack Block Kit (richer layout capability, native Office 365 styling)
- **Graph API** is required for sending messages, creating tabs, reading calendar/email data
- **Bot registration** via Azure Active Directory (not Slack OAuth)
- **Tabs** — Teams supports embedding full web apps as tabs inside Teams channels/chats (stronger than Slack for full UI embedding)
- **Meeting intelligence** — if the customer uses Microsoft Teams meetings (not Zoom), the Graph API provides meeting recordings, transcripts, and attendance data

### Why Teams Matters

In many enterprise organizations — particularly in financial services, banking, and government-adjacent companies — MS Teams is mandatory. Temenos's core customer base (banking software) skews heavily toward Microsoft shops. This makes Teams a P1 integration for the primary target segment, even if Slack is more common in SaaS-native companies.

**Rule of thumb:** Build Slack first (SaaS / startup / scale-up companies), Teams second (enterprise / financial services / Microsoft shops). Both use the same platform notification API — only the delivery adapter differs.

### Teams-Specific Advantages Over Slack

| Feature                       | Teams                                    | Slack                                 |
| ----------------------------- | ---------------------------------------- | ------------------------------------- |
| Embedded web app as Tab       | ✅ First-class (full web app in channel) | ❌ Limited (links, not embedded apps) |
| Meeting intelligence (native) | ✅ Graph API transcripts                 | ❌ Requires Gong/Zoom                 |
| Calendar signal capture       | ✅ Outlook Calendar via Graph            | ❌ Requires Momentum                  |
| Email signal capture          | ✅ Outlook via Graph (Phase 3 shortcut)  | ❌ Requires Gmail/Outlook connector   |
| Enterprise SSO                | ✅ Azure AD native                       | ✅ SAML via Slack                     |
| Compliance/retention policies | ✅ Enterprise-grade                      | ✅ Enterprise grid                    |

**Key insight:** For Teams-native organizations, the Graph API gives the platform email and calendar signals _for free_ without building a separate Outlook/email integration. This collapses Phase 3 (email integration) into Phase 2 for Microsoft-shop customers.

### Teams Integration Design

**Bot Framework implementation:**

- Register bot in Azure AD with required Graph API scopes
- Deploy bot service (Node.js using `botbuilder` SDK)
- Bot handles proactive messages (platform → Teams) and interactive cards (Teams → platform)

**Adaptive Card — Commission Notification Example:**

```json
{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "text": "Commission Calculated",
      "weight": "Bolder",
      "size": "Medium"
    },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Deal", "value": "Barclays — Q2 Subscription" },
        { "title": "Amount", "value": "$8,400" },
        {
          "title": "Rate Applied",
          "value": "Quarterly Accelerator (112% attainment)"
        },
        { "title": "Payment Date", "value": "April 15, 2026" }
      ]
    },
    {
      "type": "ActionSet",
      "actions": [
        {
          "type": "Action.OpenUrl",
          "title": "View Breakdown",
          "url": "https://app.platform.com/commissions/[id]"
        },
        {
          "type": "Action.Submit",
          "title": "Raise Dispute",
          "data": { "action": "dispute", "commId": "C-12345" }
        }
      ]
    }
  ]
}
```

**Teams Tab — Forecast App Embed:**
The forecast web app (Phase 3 React build) can be embedded directly as a Teams Tab, providing the full forecast grid experience inside Teams. Particularly valuable for managers who live in Teams and don't want to switch to a browser app for their weekly forecast review.

**Graph API — Meeting Signal Extraction:**
For organizations using Teams meetings (not Zoom):

- Subscribe to `communications/callRecords` change notifications
- Fetch transcript via `callRecords/{id}/sessions/{id}/segments`
- Run same NLP pipeline as Gong/Zoom transcript processing
- Write to `deal_signals` via same canonical schema

This means Teams-native customers get call intelligence signals without buying Gong — a significant cost saving and adoption accelerator.

---

## 9. Email Integration (Phase 3)

### Why Phase 3 (Not Earlier)

Email integration is intentionally deferred because:

1. Momentum already captures email signals for Momentum customers (Phase 1 covers this)
2. Teams Graph API provides Outlook signals for Microsoft shops (Phase 2 covers this)
3. Building a standalone email integration (Gmail + Outlook) correctly requires solving deliverability, OAuth token management, data privacy (email content is sensitive), and SOC 2 compliance — significant engineering and legal overhead
4. The signal value from email is mostly covered by Phase 1 and 2 sources for the initial target market

When built, email integration should cover:

### Gmail Integration (Google Workspace)

**Scope:** Signal capture only (not a full email client — this is not Outreach/Salesloft)

| Signal Captured                   | Method                                      | Platform Use                         |
| --------------------------------- | ------------------------------------------- | ------------------------------------ |
| Email sent to prospect domain     | Gmail API + label matching                  | Activity log, last-contact date      |
| Reply received                    | Gmail API watch (push notification)         | Response time calculation            |
| Email opened (via tracking pixel) | Custom tracking service                     | Engagement signal (read vs. ignored) |
| Thread sentiment                  | NLP on email body (with consent)            | Late-stage risk signal               |
| Attachment opened                 | Document tracking (via DocSend integration) | Proposal engagement signal           |

**Privacy considerations:** Email body content should only be processed with explicit user consent and clear disclosure. Signal capture (metadata: timestamps, response rates) is less sensitive than content analysis. Phase 3 should start with metadata-only signals and add content signals (sentiment) in Phase 4 with explicit consent model.

### Outlook Integration (Microsoft 365)

For non-Teams organizations using Outlook (rare, but exists), the same signals as Gmail via Microsoft Graph API `mail` scope.

For Teams-native organizations, this is already covered by Phase 2 Teams integration.

### Outreach / Salesloft Integration (Phase 3+)

Outreach and Salesloft are sales engagement platforms — they manage email sequences, call tasks, and LinkedIn touches. They are not just email tools; they are activity orchestration platforms.

**What they contribute beyond email:**

- Sequence enrollment status (is this prospect in an active nurture sequence?)
- Touch count per channel (email/call/LinkedIn) over trailing 30/60/90 days
- Meeting booked via sequence (strong positive signal)
- Unsubscribed / bounced (negative signal)
- Reply rate by template (quality of messaging — useful for coaching)

**Integration approach:** Both Outreach and Salesloft have REST APIs and webhooks. Treat them as activity signal sources feeding the same `deal_signals` canonical schema. The platform does not manage sequences — it consumes the engagement data they produce.

---

## 10. Unified Signal Architecture

### Canonical Signal Schema (deal_signals table)

```sql
CREATE TABLE deal_signals (
    id                          UUID PRIMARY KEY,
    opportunity_id              VARCHAR NOT NULL,       -- CRM opportunity ID
    tenant_id                   UUID NOT NULL,          -- Multi-tenant isolation
    signal_date                 TIMESTAMPTZ NOT NULL,   -- When signal was captured

    -- Source metadata
    source                      VARCHAR NOT NULL,       -- gong | momentum | zoom | dialpad | aircall | teams | outlook | outreach
    source_record_id            VARCHAR,                -- ID in source system (call ID, email ID)

    -- Activity signals
    last_activity_date          DATE,
    days_since_last_activity    INTEGER,
    activity_count_30d          INTEGER,

    -- Call signals
    call_count_30d              INTEGER,
    avg_call_duration_mins      DECIMAL,
    call_sentiment              VARCHAR,                -- positive | neutral | negative
    talk_ratio_seller           DECIMAL,                -- 0.0–1.0
    competitor_mentioned        BOOLEAN,
    next_step_confirmed         BOOLEAN,
    decision_maker_on_call      BOOLEAN,

    -- Relationship signals (Momentum / Teams)
    stakeholder_count           INTEGER,
    relationship_strength       DECIMAL,                -- 0–100
    champion_identified         BOOLEAN,
    decision_maker_engaged      BOOLEAN,
    dm_last_response_date       DATE,
    contacts_gone_dark          INTEGER,
    email_response_time_hrs     DECIMAL,

    -- Meeting signals (Zoom / Teams)
    meeting_count_30d           INTEGER,
    meeting_no_show_count       INTEGER,
    avg_meeting_duration_mins   DECIMAL,

    -- Vendor-specific scores
    gong_risk_score             DECIMAL,                -- 0–100
    gong_engagement_score       DECIMAL,
    zoom_revenue_accel_score    DECIMAL,
    dialpad_call_score          DECIMAL,
    momentum_score              DECIMAL,

    -- Composite (platform-calculated)
    composite_health_score      DECIMAL,                -- 0–100, platform-owned
    health_category             VARCHAR,                -- healthy | watch | at_risk

    -- Forecast context
    in_active_forecast          BOOLEAN,
    forecast_category           VARCHAR,                -- Manager's submitted category
    signal_forecast_conflict    BOOLEAN,                -- True if category vs. risk score diverge

    created_at                  TIMESTAMPTZ DEFAULT now(),
    updated_at                  TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common query patterns
CREATE INDEX idx_deal_signals_opp ON deal_signals(opportunity_id, signal_date DESC);
CREATE INDEX idx_deal_signals_tenant ON deal_signals(tenant_id, signal_date DESC);
CREATE INDEX idx_deal_signals_conflict ON deal_signals(tenant_id, signal_forecast_conflict) WHERE signal_forecast_conflict = TRUE;
```

### Composite Health Score Calculation

The platform owns one number: `composite_health_score` (0–100). This is the single signal shown on the forecast deal row badge. Customers should never need to interpret 6 different vendor scores simultaneously.

```
composite_health_score = weighted average of:

  40% → Primary vendor score
         (Gong risk score if Gong connected,
          Zoom Revenue Accelerator if Zoom connected,
          Dialpad call score if Dialpad connected,
          else: 50 neutral)

  20% → Relationship score
         (Momentum score if connected,
          Teams-derived relationship if connected,
          else: days_since_last_activity proxy)

  20% → Activity recency
         (days_since_last_activity: <7 days = 100,
          7–14 days = 75, 14–30 days = 50, >30 days = 20)

  20% → Engagement depth
         (decision_maker_engaged + stakeholder_count + meeting_count_30d composite)

Adjustments (subtract from score):
  -15 if competitor_mentioned = TRUE
  -20 if dm_last_response_date > 21 days ago
  -10 if meeting_no_show_count > 1 in last 30 days
  +10 if next_step_confirmed = TRUE
  +5  if decision_maker_on_call = TRUE in last 14 days
```

---

## 11. How Signals Feed Forecasting & Commissions

### Into Forecasting

**Signal badge on deal row:**
Every deal row in the forecast grid shows a health badge using `composite_health_score`:

- 🟢 70–100: Healthy
- 🟡 40–69: Watch
- 🔴 0–39: At Risk

**Forecast category conflict alert:**

```
if (manager_category IN ['Forecast', 'Commit'])
    AND (composite_health_score < 40 OR gong_risk_score > 70):
    show_conflict_banner = TRUE
    message = "Signal conflict: deal health is At Risk.
               Consider reviewing before submitting as Forecast."
```

**AI close probability input:**
`composite_health_score` + individual signal fields are features in the deal close probability model. Signals from Gong (especially competitor mention + decision maker engagement) are among the top predictive features for enterprise software deals.

**Anomaly detection enhancement:**

- `contacts_gone_dark > 2` + deal in Forecast category → anomaly flag
- `days_since_last_activity > 30` + deal in Forecast category → staleness alert
- `competitor_mentioned = TRUE` + deal moving from Cover to Forecast → risk escalation

### Into Commissions

**Post-close health monitoring (clawback risk):**
After a deal closes and commission is calculated, signal monitoring continues for the `clawback_window` (typically 90 days):

```
if (days_since_close < clawback_window)
    AND (composite_health_score < 30 OR call_sentiment = 'negative' for 2+ consecutive calls):
    set clawback_risk_flag = HIGH
    notify commission admin
```

This does not automatically trigger a clawback — it flags the deal for admin review. The admin can then investigate with the customer success team before the clawback window expires.

**Commission hold release acceleration:**
When a commission is on hold (e.g., waiting for collection), signal health can inform the release decision:

```
if (hold_type = 'collection')
    AND (relationship_strength > 70)
    AND (dm_engaged = TRUE)
    AND (email_response_time_hrs < 24):
    suggest_early_release = TRUE
```

Strong relationship signals suggest payment is likely even before the invoice is technically paid — admin can release the hold early with confidence.

---

## 12. Build vs. Partner Decision

| Integration        | Decision                            | Rationale                                                                      |
| ------------------ | ----------------------------------- | ------------------------------------------------------------------------------ |
| Gong               | **Build native integration**        | P1, critical signal source, well-documented API, high customer overlap         |
| Momentum           | **Build native integration**        | P1, strong Slack-native signals, complement to Gong                            |
| Zoom               | **Build native integration**        | P1, dominant video platform, Revenue Accelerator is free Gong alternative      |
| Dialpad            | **Build native integration**        | P2, excellent API, growing fast in target segment                              |
| Aircall            | **Build native integration**        | P2, API-first, critical for HubSpot customer segment (Phase 3)                 |
| Salesforce OpenCTI | **Build framework listener**        | P2, one build covers all OpenCTI-compliant vendors                             |
| Slack              | **Build native app**                | P1, dominant in SaaS/startup target segment                                    |
| MS Teams           | **Build native app**                | P1, dominant in enterprise/financial services segment                          |
| Gmail              | **Build native (Phase 3)**          | Covered by Momentum until Phase 3                                              |
| Outlook            | **Build native (Phase 3)**          | Covered by Teams Graph API for Teams customers                                 |
| Outreach           | **Build signal consumer (Phase 3)** | Activity signals only, not sequence management                                 |
| Salesloft          | **Build signal consumer (Phase 3)** | Activity signals only                                                          |
| RingCentral        | **Partner / OpenCTI**               | High effort, lower signal quality, declining mindshare — use OpenCTI framework |
| Five9 / Genesys    | **Not now**                         | Contact centre buyer, different persona                                        |

---

## 13. Integration Roadmap

### Phase 1 — Core Signals + Slack (AppExchange launch, Months 1–4)

- [ ] Gong API integration → `deal_signals` table / `Deal_Signal__c`
- [ ] Momentum webhook integration → relationship signals
- [ ] Zoom Meetings API → meeting attendance and duration signals
- [ ] Composite health score calculation engine
- [ ] Signal badge in forecast deal row (🟢/🟡/🔴)
- [ ] Forecast category conflict alert
- [ ] Slack app — inbound notifications (forecast, commission, signal alerts)
- [ ] Slack slash commands (`/forecast`, `/commission`, `/dealhealth`)
- [ ] Slack interactive actions (dispute raise, alert snooze, hold release approval)

### Phase 2 — Teams + Deeper CTI (Months 4–8)

- [ ] MS Teams bot + Adaptive Cards
- [ ] MS Teams Tab — embedded forecast app
- [ ] Teams Graph API — meeting transcripts as Gong alternative
- [ ] Zoom Phone API + Zoom Revenue Accelerator signals
- [ ] Dialpad webhook integration
- [ ] Aircall webhook integration
- [ ] Salesforce OpenCTI framework listener
- [ ] Post-close signal monitoring for clawback risk
- [ ] Commission hold release acceleration via signal health

### Phase 3 — Email + Sales Engagement (Months 9–14)

- [ ] Gmail API — metadata signals (response time, thread activity)
- [ ] Outlook via Graph API (for non-Teams orgs)
- [ ] Email sentiment analysis (with explicit consent model)
- [ ] Outreach signal consumer (activity counts, sequence status)
- [ ] Salesloft signal consumer
- [ ] Document engagement tracking (DocSend / PandaDoc proposal opens)

### Phase 4 — Agentic Integrations (Months 12–18)

- [ ] Slack bot responds to natural language forecast queries ("What's my Q2 forecast total?")
- [ ] Teams bot handles commission disputes end-to-end via conversation
- [ ] Automated signal-to-action: bot suggests forecast category change based on signal shift
- [ ] Weekly AI digest: Slack/Teams message summarising territory forecast health, top risks, commission pipeline — generated by LLM from structured signal data

---

_Document prepared as part of the Revenue Execution Platform product strategy._
