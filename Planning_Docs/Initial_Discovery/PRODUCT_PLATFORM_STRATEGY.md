# Unified Revenue Execution Platform — Product & Market Strategy

**Applications Reviewed:**

- Forecasting App — Temenos ORG (Salesforce Aura/LWC)
- Commissions App — Kony ORG (Salesforce Visualforce)

**Date:** 2026-04-01  
**Status:** Strategic Product Vision

---

## Table of Contents

1. [The Big Picture — What You Actually Have](#1-the-big-picture--what-you-actually-have)
2. [The Three Pillars of the Platform](#2-the-three-pillars-of-the-platform)
3. [Gong / Momentum Deal Signal Integration](#3-gong--momentum-deal-signal-integration)
4. [Commissions Application — Deep Analysis](#4-commissions-application--deep-analysis)
5. [Why Forecasting + Commissions + Signals is the Winning Bundle](#5-why-forecasting--commissions--signals-is-the-winning-bundle)
6. [Competitive Landscape — Combined Platform View](#6-competitive-landscape--combined-platform-view)
7. [Technology Modernization Path (VF + Aura → Modern Stack)](#7-technology-modernization-path-vf--aura--modern-stack)
8. [Phased Roadmap](#8-phased-roadmap)
9. [Market Sizing & Commercial Model](#9-market-sizing--commercial-model)
10. [The Core Insight — Why This Wins](#10-the-core-insight--why-this-wins)

---

## 1. The Big Picture — What You Actually Have

Most revenue software companies spend years building one of these three things:

| Pillar                      | What You Already Have                                                                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Forecast Governance**     | Multi-level hierarchical override chain, partial submit, freeze, budget mode, historical notes — production-proven at Temenos                               |
| **Commission Intelligence** | Multi-role calculation engine (8+ roles), tiered accelerators, draws/clawbacks, collection-aware payouts, plan dependency logic — production-proven at Kony |
| **Deal Signal Layer**       | Integration target for Gong/Momentum — to be built                                                                                                          |

You have two of the three pillars already built and battle-tested in production. The third (deal signals) is an integration, not a build from scratch.

Most startups in the Revenue Operations space have _none_ of these three built. Vendors like Clari and Spiff have spent $200M+ building equivalent functionality. You have it.

The product opportunity is to unify these three pillars into a single platform:

```
┌─────────────────────────────────────────────────────────────┐
│           REVENUE EXECUTION PLATFORM                        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  FORECAST   │  │   SIGNALS   │  │    COMMISSIONS      │ │
│  │ GOVERNANCE  │◄─┤  (Gong /   ├─►│   INTELLIGENCE      │ │
│  │             │  │  Momentum) │  │                     │ │
│  │ Multi-level │  │            │  │ Multi-role calc     │ │
│  │ override    │  │ Deal health│  │ Tiered accelerators │ │
│  │ Freeze/lock │  │ Call intel │  │ Draws/clawbacks     │ │
│  │ Budget mode │  │ Activity   │  │ Plan dependency     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              AGENTIC AI LAYER                        │   │
│  │  Deal predictions · Manager calibration · Coaching  │   │
│  │  Commission dispute resolution · Payout forecasting │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. The Three Pillars of the Platform

### Pillar 1 — Forecast Governance (from Temenos)

What it solves: Bottom-up hierarchical commit process with full audit trail.

**Production-proven capabilities:**

- 4-level override chain: Manager → Sub-Director → Director → COO
- Per-deal status lifecycle: New → Dirty → Saved → Submitted → Frozen
- Partial save/submit (work-in-progress forecasting)
- Deal-share deduplication at COO rollup
- Budget vs. Forecast dual mode
- Local currency per territory
- Historical notes per deal per period

**What makes it different from Salesforce native:**
Salesforce native forecasting rolls up from Opportunity Products. If a manager wants to override their deal's forecast value without touching the actual Opportunity Amount, they can't — without this application. Every override, every status, every hierarchy level is tracked independently. That is the core IP.

---

### Pillar 2 — Commission Intelligence (from Kony)

What it solves: Accurate, auditable, multi-role commission calculation with full payment lifecycle.

**Production-proven capabilities:**

- 8+ eligible roles per deal: AE, BDR, SE, CSM, DCP, CSA, Manager, Partner Rep
- 3 commission bases: Booking, Count, Revenue Recognition
- Tiered accelerators: 0-100% (base), 100-150% (quarterly), 150%+ (annual)
- Payout table tiers (Comp_Payout_Table\_\_c)
- Commission caps: per-deal and plan-level
- Draw / Advance / Payback / Clawback lifecycle
- Collection-aware payouts (commission reduced if invoice unpaid)
- Multi-year deal bonus
- Plan dependency with threshold activation
- Manager hierarchy cascading bonuses
- Revenue recognition basis (separate path for rev-rec plans)
- Approval workflows: SPIFF, SAL, PS Commission, Sold Margin

**What makes it different from Salesforce native:**
Salesforce has no native commission calculation. Every company builds this manually in Excel or pays $40-80/user/month for Xactly/Spiff/CaptivateIQ. This application handles the calculation logic that all those vendors charge for.

---

### Pillar 3 — Deal Signal Layer (to be integrated)

What it solves: Objective, AI-derived deal health signals that remove the subjectivity from both forecasting and commission qualification.

**Gong integration targets:**

- Call sentiment analysis per deal (positive/negative/neutral trend)
- Engagement score: number of contacts engaged, multi-threading depth
- Talk ratio: seller-to-buyer talk time (high seller talk ratio = risk signal)
- Next steps confirmed: does the deal have a committed next step after each call?
- Decision maker engaged: has the economic buyer been on a call?
- Competitor mentions: flags competitor discussions
- Deal risk score: Gong's proprietary composite score

**Momentum integration targets:**

- Email response time: how quickly is the prospect responding?
- Stakeholder map: who is engaging, who has gone dark
- Relationship strength per contact
- Deal velocity: is the deal moving faster or slower than historical average?
- Auto-captured activity log: eliminates manual CRM updates

**How signals feed the platform:**

- Into **Forecasting**: Augment the deal row with a signal health badge (green/amber/red); flag deals where manager's category (Forecast) conflicts with Gong's risk score (High Risk)
- Into **Commissions**: Flag deals where signals suggest potential churn risk (Gong sentiment declining post-close) as candidates for clawback monitoring; reduce commission hold release threshold when signals show strong customer health
- Into **AI layer**: Gong signals are features in the deal close probability model; call sentiment trend is one of the strongest predictors of close vs. slip

---

## 3. Gong / Momentum Deal Signal Integration

### Architecture

```
Gong API / Momentum API
        │
        ▼
   Integration Layer
   (Node.js adapter)
        │
        ├──► Salesforce (via REST API)
        │    Writes to: Deal_Signal__c (new custom object)
        │    Fields: Gong_Risk_Score, Engagement_Score,
        │            Last_Call_Sentiment, Decision_Maker_Engaged,
        │            Days_Since_Last_Activity, Stakeholder_Count
        │
        └──► Platform DB (PostgreSQL)
             For non-Salesforce deployments
```

### New Object: Deal_Signal\_\_c

| Field                         | Source     | Type                                 | Used For                     |
| ----------------------------- | ---------- | ------------------------------------ | ---------------------------- |
| `Opportunity__c`              | -          | Lookup                               | Join to deal                 |
| `Gong_Risk_Score__c`          | Gong       | Number                               | Forecast override alert      |
| `Gong_Engagement_Score__c`    | Gong       | Number                               | Deal health                  |
| `Last_Call_Sentiment__c`      | Gong       | Picklist (Positive/Neutral/Negative) | Commission clawback signal   |
| `Decision_Maker_Engaged__c`   | Gong       | Boolean                              | Forecast category validation |
| `Competitor_Mentioned__c`     | Gong       | Boolean                              | Risk flag                    |
| `Email_Response_Time_Hrs__c`  | Momentum   | Number                               | Deal velocity                |
| `Days_Since_Last_Activity__c` | Momentum   | Number                               | Staleness alert              |
| `Relationship_Strength__c`    | Momentum   | Picklist                             | Health composite             |
| `Stakeholder_Count__c`        | Momentum   | Number                               | Multi-thread indicator       |
| `Signal_Updated__c`           | -          | DateTime                             | Freshness                    |
| `Composite_Health_Score__c`   | Calculated | Number (0-100)                       | Single signal for UI         |

### Integration Sync Frequency

| Trigger                | Frequency                    | Rationale                         |
| ---------------------- | ---------------------------- | --------------------------------- |
| Forecast period opens  | Full sync all active deals   | Baseline signals for new period   |
| Manager opens deal row | On-demand refresh            | Fresh signal at point of decision |
| Daily batch            | All deals in active forecast | Keep signals current              |
| Post-call (webhook)    | Real-time via Gong webhook   | Immediate sentiment update        |

### How Signals Appear in the Forecasting UI

In the Manager View deal row, a new **Signal Badge** column is added:

- 🟢 Healthy (Score 70–100)
- 🟡 Watch (Score 40–69)
- 🔴 At Risk (Score 0–39)

Clicking the badge expands a signal detail panel showing:

- Last call sentiment + date
- Engagement score vs. deal stage benchmark
- Decision maker status
- Days since last activity
- Competitor flag

**Conflict Alert:** If manager selects "Forecast" category but Gong risk score is > 70 (high risk), the row displays a warning: _"Signal conflict: Gong risk score is High for this deal. Consider Cover or Pipeline."_

---

## 4. Commissions Application — Deep Analysis

### Current State (Visualforce)

The Kony commissions application is built entirely on Visualforce pages with jQuery DataTables, Select2 dropdowns, and Remote Actions to Apex. This is a 2015-era Salesforce pattern that is:

- Not mobile-responsive
- Not componentized (monolithic VF pages)
- Not embeddable in Lightning without iframe hacks
- Not independently deployable outside Salesforce

The **business logic** (CommissionsProcessFY19.cls at ~1200 lines) is the asset. The VF UI is the liability.

### What the Business Logic Does — Summary

The core engine handles:

1. **Role detection per deal** — For each closed opportunity, identifies all eligible commission earners (AE, BDR, SE, CSM, DCP, CSA, Partner Rep, Managers) and their applicable plans

2. **Rate selection** — Looks up each role's Comp_Plan\_\_c, evaluates current quota attainment, selects the appropriate rate (base/quarterly accelerator/annual accelerator)

3. **Commissionable value** — Applies deal-type rules: Subscription gets full booking value, Services gets margin-based value, Renewals require Eligible_Comp_Renewals\_\_c check

4. **Multi-year bonus** — If deal term >= threshold, applies bonus rate on top of base

5. **Collection adjustment** — If invoice not fully paid (New_Percent_Collected\_\_c < 100), reduces commission proportionally

6. **Cap enforcement** — Checks per-deal cap and plan-level cap, creates "Reached Cap" Comp_Calculation record for the excess

7. **Manager cascade** — Walks the user hierarchy above each eligible rep and applies manager bonus plans

8. **Payment hold logic** — Creates Comp_Calculation with Hold flags if renewal attainment, ACV quota, or collection conditions not met

9. **Accelerator settlement** — On year-end or threshold crossing, releases held accelerator amounts

### What Is Missing vs. Modern Commission Platforms

| Feature                             | Kony App Today                | Gap                                                      |
| ----------------------------------- | ----------------------------- | -------------------------------------------------------- |
| Rep self-service portal             | Basic VF page                 | No mobile, no real-time updates                          |
| Commission dispute workflow         | Not present                   | Reps can't formally dispute a calculation                |
| What-if simulator                   | Not present                   | Reps can't model "if I close this deal, what do I earn?" |
| Real-time attainment visibility     | Admin-only                    | Reps don't see live quota progress                       |
| Plan acknowledgment / e-sign        | Not present                   | Legal compliance risk                                    |
| ASC 606 revenue recognition split   | Partial (rev-rec path exists) | Not fully automated                                      |
| Territory change mid-year handling  | Not present                   | Manual process                                           |
| Quota crediting rules by product    | Not present                   | All bookings credited equally                            |
| Payout calendar / payment schedule  | Partial                       | No automated payroll file export                         |
| Audit log / calculation explanation | Not present                   | Can't show rep why they got $X                           |

These gaps are exactly what Xactly, Spiff, and CaptivateIQ charge $40–80/user/month to solve. The core calculation engine is already built — these are UI and workflow gaps.

---

## 5. Why Forecasting + Commissions + Signals is the Winning Bundle

### The Flywheel

```
SIGNALS (Gong/Momentum)
  │  Deal health data flows in
  ▼
FORECASTING (Temenos)
  │  Informed by signals, manager submits more accurate forecast
  │  Accurate forecast = accurate quota retirement
  ▼
COMMISSIONS (Kony)
  │  Quota attainment calculated correctly
  │  Right people paid the right amount at the right time
  ▼
TRUST
  │  Reps trust the system → better CRM hygiene → better signals
  └──────────────────────────────────────────────────────────►
```

This flywheel is what no single-point vendor can replicate:

- **Clari** has signals + forecasting but no commissions
- **Xactly / Spiff** has commissions but no forecasting or signals
- **Gong** has signals but no forecasting or commissions
- **Salesforce** has weak versions of all three, none integrated

### The Data Unification Advantage

When all three pillars share the same data model, you can answer questions that no vendor can today:

| Question                                                          | Requires                                                       |
| ----------------------------------------------------------------- | -------------------------------------------------------------- |
| "Is this manager sandbagging?"                                    | Forecasting history + Commissions attainment history           |
| "Which reps close what they forecast?"                            | Forecast overrides + Actual close data                         |
| "Are deals that Gong flags as at-risk actually slipping?"         | Signals + Forecast outcomes                                    |
| "Which commission plan design drives the best forecast accuracy?" | Comp_Plan**c + Forecast_Override**c history                    |
| "Is this rep underforecasting to protect accelerators?"           | Commission attainment thresholds + forecast submission pattern |
| "What would rep earnings be under our new plan?"                  | Comp_Plan**c simulator + Forecast_Override**c pipeline         |

The last question alone is worth the platform subscription. Every year, companies redesign comp plans and have no way to model the impact on rep behavior and earnings before rolling it out.

### The Critical Business Hook: Rep Trust

Commission disputes are one of the biggest sources of sales rep turnover. When reps don't trust that their commissions are calculated correctly, they spend time checking spreadsheets instead of selling, and they leave.

The combination of:

- Transparent calculation breakdown (Comp_Calculation**c with Plan_Rate**c showing exactly what rate was applied and why)
- Real-time attainment visibility
- Dispute workflow
- What-if simulator ("if I close the Barclays deal this quarter, I earn $X and cross the 100% threshold")

...creates rep trust. And rep trust is the single metric that HR, Finance, and CRO all care about equally.

---

## 6. Competitive Landscape — Combined Platform View

### Forecast-Only Vendors

| Vendor              | Forecast     | Commissions | Signals       | Hierarchy Depth | Governance     |
| ------------------- | ------------ | ----------- | ------------- | --------------- | -------------- |
| **This Platform**   | ✅ Deep      | ✅ Deep     | ✅ Integrated | N-level         | Freeze/partial |
| Clari               | ✅ Strong    | ❌          | ✅ Strong     | 2-level adj     | Weak           |
| Aviso               | ✅ Strong AI | ❌          | Partial       | 2-level         | Weak           |
| Salesforce Einstein | ✅ Basic     | ❌          | Basic         | 2-level         | None           |
| Boostup.ai          | ✅ Mid       | ❌          | Partial       | 2-level         | None           |

### Commission-Only Vendors

| Vendor             | Commissions | Forecast | Signals       | Price          |
| ------------------ | ----------- | -------- | ------------- | -------------- |
| **This Platform**  | ✅ Deep     | ✅ Deep  | ✅ Integrated | TBD            |
| Xactly             | ✅ Deep     | ❌       | ❌            | $50–80/user/mo |
| Spiff (Salesforce) | ✅ Strong   | ❌       | ❌            | $35–65/user/mo |
| CaptivateIQ        | ✅ Strong   | ❌       | ❌            | $40–75/user/mo |
| Performio          | ✅ Mid      | ❌       | ❌            | $25–50/user/mo |
| Salesforce Spiff   | ✅ Basic    | ❌       | ❌            | Bundled        |

### Signal/Intelligence Vendors

| Vendor            | Signals                    | Forecast | Commissions |
| ----------------- | -------------------------- | -------- | ----------- |
| Gong              | ✅ Best-in-class           | Weak     | ❌          |
| Momentum          | ✅ Strong (email/calendar) | ❌       | ❌          |
| People.ai         | ✅ Activity-based          | ❌       | ❌          |
| Chorus (ZoomInfo) | ✅ Call-based              | ❌       | ❌          |

### The Gap in the Market

No single vendor combines all three at depth. The closest is Salesforce (Revenue Cloud + Spiff + Einstein) but:

- Revenue Cloud is $150+/user/month on top of Sales Cloud
- Spiff is now owned by Salesforce but not deeply integrated with forecasting
- Einstein Forecasting has all the native limitations documented earlier
- None of them have the hierarchical override governance this app provides

**The platform opportunity: Price at $60–90/user/month all-in and offer what a customer would otherwise spend $100–180/user/month assembling from three separate vendors.**

---

## 7. Technology Strategy — Salesforce-Native First, Full-Stack Later

### Guiding Principle

**Salesforce is the launch distribution channel, not the long-term architecture constraint.**

Launching Salesforce-native (LWC + Apex + AppExchange) eliminates the single biggest risk for a new product: the CRM integration problem. Every non-Salesforce product spends 6–12 months building connectors before writing a single line of business logic. Salesforce-native skips that entirely. First customers arrive at month 4, not month 18.

The full-stack migration happens _after_ product-market fit is established — with real customer data, real revenue, and real knowledge of where Salesforce's constraints actually bite.

### Current Technical Debt

| Component           | Current Tech              | Issue                                                              |
| ------------------- | ------------------------- | ------------------------------------------------------------------ |
| Forecasting UI      | Salesforce Aura           | Deprecated; Salesforce pushing LWC — must migrate                  |
| Commissions UI      | Visualforce               | No Lightning compatibility, no mobile, monolithic — must rebuild   |
| Commissions Engine  | Apex (~1200 lines)        | Sound logic, but Salesforce-only runtime; governor limits at scale |
| Forecasting Backend | Apex @AuraEnabled         | Sound logic; Salesforce-only                                       |
| Data                | Salesforce custom objects | Per-org; no multi-tenant SaaS capability until Phase 3             |

### Phase 1 & 2 Stack — Salesforce Native (LWC)

```
UI:           Lightning Web Components (LWC)
              SLDS design system (native Salesforce look and feel)
              LWC OSS-compatible patterns (eases Phase 3 migration)

Backend:      Apex @AuraEnabled / @InvocableMethod
              Platform Events for async processing
              Named Credentials for external API calls (Gong, Zoom, Momentum)
              Apex Callouts → Claude API (AI layer via external endpoint)

Data:         Salesforce custom objects (existing schema, extended)
              Custom Metadata Types (weight profiles, scoring config)
              Big Objects (audit log / score history — avoids data storage limits)

Signals:      Named Credentials + Apex HTTP callouts (scheduled + on-demand)
              Platform Events to decouple signal ingestion from UI refresh
              Deal_Signal__c custom object (canonical signal store)

Notifications: Salesforce Notification Builder (in-app)
               Apex callouts → Slack API (Bolt webhooks)
               Apex callouts → MS Teams Bot Framework

Distribution: Salesforce AppExchange managed package
              1st-generation managed package → upgradeable in customer orgs
```

### Phase 3 Stack — Full-Stack Migration (after PMF)

```
Frontend:     React + TypeScript (Next.js)
              SLDS-inspired design system — familiar to existing customers
              LWC components ported to React (component logic maps 1:1)

Backend:      Node.js (TypeScript) microservices
              Forecasting Service | Commission Service | Signal Service | AI Service
              REST API (CRUD) + GraphQL (complex nested queries)

Data:         PostgreSQL (multi-tenant schema)
              Salesforce objects → PostgreSQL tables (direct schema mapping)
              Redis (caching, session state)
              TimescaleDB (signal time-series history)

AI Layer:     Python FastAPI microservice
              XGBoost / LightGBM (close probability model)
              Claude API (natural language forecast editing, coaching, disputes)

CRM Layer:    Adapter pattern — Salesforce is Adapter 1, not the platform
              Adapter 1: Salesforce REST + Bulk API
              Adapter 2: HubSpot (Phase 3 expansion)
              New CRM = new adapter only; core product unchanged

Signal Layer: Direct webhook receivers (no Named Credential middleman)
              Gong webhooks, Zoom webhooks, Momentum webhooks
              Write to deal_signals PostgreSQL table (same canonical schema)

Auth:         Auth0 / Clerk (SSO, SAML, OIDC)
              RBAC at API layer

Infra:        AWS (ECS Fargate, RDS PostgreSQL, ElastiCache Redis)
```

### Why the Migration Is Straightforward (Not a Rewrite)

Salesforce custom objects map directly to PostgreSQL tables with no redesign:

| Salesforce Object      | PostgreSQL Table     | Migration Type     |
| ---------------------- | -------------------- | ------------------ |
| `Forecast_Override__c` | `forecast_overrides` | Schema translation |
| `Forecast_User__c`     | `forecast_users`     | Schema translation |
| `Forecast__c`          | `forecasts`          | Schema translation |
| `Comp_Plan__c`         | `comp_plans`         | Schema translation |
| `Comp_Calculation__c`  | `comp_calculations`  | Schema translation |
| `Commission_Draw__c`   | `commission_draws`   | Schema translation |
| `Deal_Signal__c`       | `deal_signals`       | Schema translation |

Apex business logic maps to TypeScript/Python service methods:

| Apex Class                                      | Service Method                          | Migration Type                                    |
| ----------------------------------------------- | --------------------------------------- | ------------------------------------------------- |
| `SL_OpportunityForecastCtrl.saveForecastData()` | `ForecastService.save()`                | Logic port                                        |
| `CommissionsProcessFY19.processCommission()`    | `CommissionService.calculate()`         | Logic port                                        |
| `CommissionDrawTriggerHandler`                  | `CommissionService.updateDrawBalance()` | Logic port                                        |
| Score calculation engine                        | `ScoringService.calculate()`            | Already designed in TypeScript (see scoring spec) |

By Phase 3, the Apex logic will have been battle-tested in production for 12+ months. The port is a translation, not a redesign.

---

## 8. Phased Roadmap

### Phase 1 — Salesforce Native AppExchange Package (Months 1–4)

**Goal:** Ship a Salesforce managed package (LWC) combining both apps with signal integration.  
**Stack:** LWC + Apex + Salesforce custom objects + Named Credentials for external signals.

Forecasting (Aura → LWC migration):

- [ ] Migrate `SL_OpportunityForecastCmp` and all child components Aura → LWC
- [ ] Make hierarchy levels configurable via Custom Metadata (not hard-coded 4 levels)
- [ ] Make metrics configurable (not hard-coded NBV/ACV)
- [ ] Make categories configurable per forecast template

Commissions (VF → LWC rebuild):

- [ ] Rebuild `commissiondb.page` as LWC rep self-service portal
- [ ] Rebuild `CommissionsAdminDashBoard.page` as LWC admin dashboard
- [ ] Add calculation breakdown view (transparent rate + attainment explanation per deal)
- [ ] Add what-if simulator ("if I close this deal this quarter, I earn $X")
- [ ] Add dispute workflow (rep raises flag → admin reviews → resolution logged)
- [ ] Plan acknowledgment / e-sign component (legal compliance)

Signal Integration (via Named Credentials + Apex callouts):

- [ ] `Deal_Signal__c` custom object (canonical signal store)
- [ ] Gong scheduled sync + webhook receiver (Platform Event)
- [ ] Momentum scheduled sync + webhook receiver
- [ ] Zoom Meetings API sync
- [ ] Composite health score calculation (Apex, deterministic formula)
- [ ] Score card LWC component (breakdown panel, adjustment list, score history)
- [ ] Weight profile Custom Metadata Type + admin configuration UI
- [ ] Signal badge in forecast deal row with conflict alert

Notifications:

- [ ] Slack app (Apex callouts → Slack Bolt API)
- [ ] MS Teams bot (Apex callouts → Bot Framework)
- [ ] In-app Salesforce notification builder rules

**Output:** AppExchange managed package. First paying customers from existing Salesforce networks.

---

### Phase 2 — AI Layer on Salesforce (Months 4–9, overlaps Phase 1)

**Goal:** Add AI-driven intelligence as premium tier features. AI runs as external microservice called via Apex Named Credential callouts — keeps AI infra outside Salesforce governor limits.  
**Stack:** Apex callouts → Python FastAPI (Claude API + XGBoost models) hosted externally.

Forecasting AI:

- [ ] Manager Accuracy Scoring (historical override vs. actual close — computed externally, stored in `Manager_Accuracy__c`)
- [ ] Deal Close Probability model (XGBoost, served via external API endpoint)
- [ ] Anomaly detection batch (quarter slippage, NBV cliff, category regression)
- [ ] Predictive territory roll-up in Summary Table

Commissions AI:

- [ ] Payout forecasting ("at current pipeline, rep earns $X this quarter")
- [ ] Plan design simulator (model impact of changing accelerator thresholds)
- [ ] Clawback risk scoring (post-close signal monitoring via Gong)
- [ ] Commission dispute assistant (Claude API generates NL explanation of any calculation)

Signal Intelligence:

- [ ] Dialpad + Aircall integrations (Named Credentials)
- [ ] Salesforce OpenCTI framework listener (covers all OpenCTI-compliant CTI vendors)
- [ ] Post-close signal monitoring for clawback risk window
- [ ] Live preview on weight configuration (score diff for current deals)

**Output:** AI-differentiated package. Premium tier pricing unlocked. Target 20–30 customers.

---

### Phase 3 — Full-Stack Migration (Months 10–18)

**Goal:** Extract platform from Salesforce runtime. Salesforce becomes Adapter 1. No new CRM integration work needed for Salesforce customers — they flip a config switch, not a migration.  
**Stack:** React + Node.js/Python + PostgreSQL + AWS. Salesforce CRM adapter retained.

- [ ] React frontend (LWC components ported — same UX, same flows, platform-independent)
- [ ] Node.js API layer (Apex logic ported to TypeScript services — same algorithms)
- [ ] PostgreSQL multi-tenant schema (Salesforce objects → tables, direct mapping)
- [ ] Salesforce adapter (REST + Bulk API — reads/writes Salesforce objects as before)
- [ ] Direct Gong/Zoom/Momentum webhooks (no Named Credential middleman)
- [ ] HubSpot CRM adapter (Adapter 2 — first non-Salesforce CRM support)
- [ ] Auth0 SSO, RBAC at API layer
- [ ] AWS deployment (ECS, RDS, ElastiCache)

**Output:** Full SaaS platform. Salesforce customers continue uninterrupted. HubSpot market opens.

---

### Phase 4 — Agentic Features + Market Expansion (Months 16–24)

- [ ] Natural language forecast editing via Claude API
- [ ] Autonomous coaching agent (deal-specific nudges, commission guidance)
- [ ] Scenario planning (Commit / Best Case / Worst Case / Budget simultaneously)
- [ ] Territory planning AI (quota allocation from historical attainment + pipeline signals)
- [ ] Slack / Teams bot: end-to-end dispute resolution, forecast submission in conversation
- [ ] Mobile app (React Native)
- [ ] Dynamics 365 CRM adapter (Adapter 3)
- [ ] Email integration: Gmail + Outlook (metadata signals, sentiment with consent model)

**Output:** Full agentic platform. Market expansion to Dynamics 365 segment.

---

- [ ] Node.js / Python API layer (replaces Apex)
- [ ] PostgreSQL multi-tenant schema
- [ ] Salesforce CRM connector (adapter)
- [ ] HubSpot CRM connector (adapter)
- [ ] Gong native webhook integration (real-time, not batch)
- [ ] Momentum native integration
- [ ] Auth0 SSO
- [ ] AWS deployment (ECS + RDS + ElastiCache)

**Output:** Full SaaS product. Addressable market expands from Salesforce-only to all CRM users.

---

### Phase 4 — Agentic Features (Months 10–18)

- [ ] Natural language forecast editing ("Move HSBC to Q3, drop by 500k")
- [ ] Autonomous coaching agent (deal-specific nudges per manager)
- [ ] Commission plan designer agent ("Build me a plan for 80 reps targeting $50M ARR")
- [ ] Scenario planning: Commit / Best Case / Worst Case / Budget simultaneously
- [ ] Territory planning: AI-suggested quota allocation based on historical attainment + pipeline signals
- [ ] Slack / Teams bot for forecast updates and commission queries
- [ ] Mobile app (React Native)

---

## 9. Market Sizing & Commercial Model

### Target Segments

**Primary (Phase 1–2):** Enterprise software, fintech, and SaaS companies

- Already on Salesforce
- 50–500 person sales org
- Deal sizes $100K–$50M
- Pain: Salesforce native forecasting ceiling + Excel commissions

**Secondary (Phase 3+):** Any company with 20+ person sales org

- CRM-agnostic
- Deal sizes $10K+
- Pain: Forecasting accuracy + commission transparency

### Pricing Architecture

| Tier              | Includes                                               | Price                    | Target                                    |
| ----------------- | ------------------------------------------------------ | ------------------------ | ----------------------------------------- |
| **Forecast**      | Forecasting governance only (N-level, configurable)    | $25/user/mo              | Small teams wanting better than native SF |
| **Commissions**   | Commission calculation, rep portal, draws, clawbacks   | $30/user/mo              | Companies replacing Excel commissions     |
| **Platform**      | Forecast + Commissions + Gong/Momentum signals         | $55/user/mo              | Full RevOps platform buyers               |
| **Platform + AI** | Platform + AI predictions + coaching + what-if         | $80/user/mo              | Enterprise buyers                         |
| **Enterprise**    | Custom hierarchy, multi-CRM, SSO, SOC 2, dedicated CSM | $100–150/user/mo + setup | 500+ seat orgs                            |

### ARR Projections (Conservative)

| Milestone                           | Customers | Avg Users | Avg Tier | ARR    |
| ----------------------------------- | --------- | --------- | -------- | ------ |
| Month 12 (AppExchange launch)       | 10        | 100       | $55      | $660K  |
| Month 18 (Post-AI layer)            | 30        | 150       | $70      | $3.8M  |
| Month 24 (Platform independence)    | 75        | 175       | $75      | $11.8M |
| Month 36 (Full platform, multi-CRM) | 200       | 200       | $80      | $38.4M |

These are achievable with a focused enterprise sales motion. Clari reached $100M ARR with a smaller initial feature set. The combined platform is a stronger offering than Clari was at Series A.

---

## 10. The Core Insight — Why This Wins

The enterprise revenue problem has three layers that companies are forced to solve separately today:

```
Layer 1: What will we close? (Forecasting)
         → Answered by: Clari, Aviso, Salesforce Einstein, spreadsheets
         → Solved by THIS PLATFORM: governance + hierarchy + AI prediction

Layer 2: Why will it close? (Deal Signals)
         → Answered by: Gong, Momentum, People.ai
         → Solved by THIS PLATFORM: Gong/Momentum integration feeding into forecast decisions

Layer 3: What does the team earn when it closes? (Commissions)
         → Answered by: Xactly, Spiff, CaptivateIQ, Excel
         → Solved by THIS PLATFORM: multi-role calc + accelerators + draws/clawbacks
```

The insight that no competitor has operationalized yet:

**Layer 3 (Commissions) directly shapes the behavior that determines Layer 1 (Forecasting).**

- A rep who is 95% to quota with a $200K accelerator threshold will sandbagg their forecast to close one big deal next quarter and cross the threshold
- A rep who has already crossed 150% will pull in every possible deal before year-end
- A manager whose bonus depends on team attainment submits optimistic forecasts even when Gong says deals are at risk

When you know both the commission plan and the forecast submission, you can model and detect this behavior. No single-point vendor can do this because they only have one layer. This platform has all three.

That is the moat. Not the features individually — the **connection between them**.

---

_Document prepared based on direct source code analysis of Temenos ORG (Forecasting) and Kony ORG (Commissions) Salesforce applications._
