# Revenue Execution Platform — Unified Product Specification

**Modules:** Forecasting · Sales Incentives · Deal Health · Behavior Intelligence  
**Version:** 5.0 — Industry-Agnostic + Competitive Coverage + Architectural Boundaries + Operational Hardening  
**Date:** 2026-04-01  
**Inputs:** FORECASTING_REQUIREMENTS.md · COMMISSIONS_MODULE_REQUIREMENTS.md · COMMISSIONS_GAP_ANALYSIS.md · TRANSPARENT_SCORING_DESIGN.md · COMMERCIALIZATION_AND_AI_STRATEGY.md · PRODUCT_PLATFORM_STRATEGY.md

---

## Table of Contents

1. [Platform Vision & Architecture](#1-platform-vision--architecture)
2. [Personas & Roles](#2-personas--roles)
3. [Module 1 — Forecasting](#3-module-1--forecasting)
4. [Module 2 — Sales Incentives](#4-module-2--sales-incentives)
5. [Module 3 — Deal Health](#5-module-3--deal-health)
6. [Module 4 — Behavior Intelligence](#6-module-4--behavior-intelligence)
7. [Cross-Module Integration — The Data Flywheel](#7-cross-module-integration--the-data-flywheel)
8. [Unified Data Model](#8-unified-data-model)
9. [AI Layer](#9-ai-layer)
10. [Notifications & Alerting](#10-notifications--alerting)
11. [Unified UI/UX Principles](#11-unified-uiux-principles)
12. [Security & Permissions](#12-security--permissions)
13. [Performance Requirements](#13-performance-requirements)
14. [Integration Architecture](#14-integration-architecture)
15. [Phased Build Roadmap](#15-phased-build-roadmap)

---

## 1. Platform Vision & Architecture

### 1.1 The Core Problem

Enterprise revenue operations require three questions to be answered simultaneously, and no single vendor answers all three today:

| Layer                | Question                                                                        | Today's Answer                             |
| -------------------- | ------------------------------------------------------------------------------- | ------------------------------------------ |
| **Forecasting**      | What will we close this quarter?                                                | Clari / Salesforce Einstein / spreadsheets |
| **Deal Health**      | Why will it close — or not?                                                     | Gong / Momentum / People.ai                |
| **Sales Incentives** | What does the team earn when it closes — and does that shape _how_ they behave? | Xactly / Spiff / Excel                     |

The fourth layer — **Behavior Intelligence** — exists nowhere yet. It answers: _Given what we know about commissions and forecasting together, what behaviors are we seeing, predicting, or creating?_

### 1.2 The Platform

```
┌──────────────────────────────────────────────────────────────────────┐
│                    REVENUE EXECUTION PLATFORM                        │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │  FORECASTING │  │ DEAL HEALTH  │  │   SALES      │  │BEHAVIOR  │ │
│  │              │  │              │  │  INCENTIVES  │  │INTEL     │ │
│  │ Multi-level  │◄─┤ Composite    ├─►│              │◄─┤          │ │
│  │ override     │  │ health score │  │ Multi-role   │  │Sandbagg- │ │
│  │ Hierarchy    │  │ Gong signals │  │ commission   │  │ing detect│ │
│  │ Freeze/lock  │  │ Relationship │  │ Accelerators │  │Accuracy  │ │
│  │ Budget mode  │  │ Activity     │  │ Draws/claw-  │  │calibrat. │ │
│  │ Notes thread │  │ Engagement   │  │ backs        │  │Anomaly   │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  │detection │ │
│                                                          └──────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                     AI LAYER                                  │    │
│  │  Close probability · Manager accuracy · Payout forecasting   │    │
│  │  Plan design simulation · Natural language editing · Coaching │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.3 What Makes This Defensible

Every competitor owns exactly one layer. The moat is **knowing all three simultaneously**:

- A rep at 95% quota attainment with a $200K accelerator threshold will sandbagg their forecast to land one big deal next quarter to cross the threshold. You can only detect this if you have both commission attainment data AND forecast submission history.
- A manager whose bonus depends on team attainment submits optimistic forecasts even when deal health signals say otherwise. You can detect this only if you have signals + forecast + commission data.
- The platform can answer: _"What commission plan structure produces the most accurate forecasting behavior?"_ — a question no single-layer vendor can approach.

### 1.4 Competitive Positioning

**Positioning statement:** The CRM-native revenue execution layer that governs forecasts, explains incentives, and detects when compensation economics distort the number — all inside the workflow where forecast decisions are made.

#### 1.4.1 Four Universal Gaps No Competitor Delivers

| Gap                                                                  | What It Means                                                                                                                                                                                            | Closest Competitor | How Close                                                                 |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------- |
| **Comp-aware forecast governance**                                   | Governance actions (approve/freeze/require justification) triggered by compensation exposure — e.g., "participant moved record to high-confidence category while payout jumps 40%; require manager note" | Xactly             | ~30% (data integration exists, governance enforcement doesn't)            |
| **Explainable revenue-behavior intelligence**                        | Structured explanation linking payout delta + plan mechanics + observed forecast adjustments + recommended governance action — not just "AI says risky"                                                  | None               | 0% — No product attempts this                                             |
| **One-screen manager decision cockpit**                              | Forecast rollup + pipeline list + per-record incentive estimator + signal trail + override audit in one workflow screen                                                                                  | None               | 0% — Every user bounces between 3–4 tools                                 |
| **CRM-native, real-time incentive visibility during forecast calls** | Incentive impact visible while manager reviews forecast in real-time — zero sync delay, not in a separate tool                                                                                           | Spiff              | ~40% (Salesforce-embedded but 2-hour sync delay, no forecast integration) |

#### 1.4.2 Competitive Landscape

| Competitor                                    | What They Do Well                                                 | What They Cannot Do                                                                                                                                                                                  |
| --------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Clari** (~$100–200/user/mo)                 | Forecast rollups, AI deal scoring, pipeline inspection            | No incentive capabilities at all. AI insights have zero comp-plan awareness. No automated forecast change alerts. 101 G2 mentions of mandatory Salesforce field dependencies forcing tool-switching. |
| **Xactly** (~$75–150/user/mo)                 | Commission calculation, data consolidation across comp + forecast | Outdated UI (38+ G2 mentions). 66 G2 mentions of slow performance. Broken audit logs. Annual setup burden. No governance enforcement loop — combines data but doesn't act on it.                     |
| **Salesforce Spiff** (~$75/user + onboarding) | CRM-native commission tool, decent estimator                      | 2-hour Salesforce sync delay. Post-acquisition deterioration (price hikes, stalled innovation, overwhelmed support). No future earnings projection. No forecast governance. No deal health signals.  |
| **CaptivateIQ** (~$50–100/user/mo)            | Clean commission statements, Forrester Leader positioning         | Limited analytics depth — users supplement with external BI tools. Slow page loads. No mobile app. No forecasting or deal health. Clunky multi-year navigation.                                      |
| **Gong** (~$100–150/user/mo)                  | Signal scoring (300+ signals), conversation intelligence          | No commission awareness — deal scores have zero comp-plan context. No forecast governance workflow. "Black box" scoring feels opaque.                                                                |
| **Varicent** (enterprise pricing)             | Powerful SPM engine, territory/quota planning                     | Legacy complexity — heavy professional services required. No CRM-native experience. No deal-level forecast governance. Aging UI.                                                                     |

#### 1.4.3 Cost Displacement Positioning

| Current Stack                        | Typical Cost     | RevenueTrust Replaces                                                    | Target Price    |
| ------------------------------------ | ---------------- | ------------------------------------------------------------------------ | --------------- |
| Clari + Spiff                        | $175–275/user/mo | Full stack                                                               | $55–80/user/mo  |
| Clari + Xactly                       | $175–250/user/mo | Full stack                                                               | $55–80/user/mo  |
| Clari + Gong + Spiff                 | $275–475/user/mo | Forecast + Incentives + Signals (keep Gong as signal adapter or replace) | $80–100/user/mo |
| Spreadsheets + basic CRM forecasting | $0–25/user/mo    | Entire workflow                                                          | $25–55/user/mo  |

#### 1.4.4 Three Core Differentiators

**Differentiator 1 — Comp-Aware Forecast Governance (not just comp-aware forecasts)**

> Governance workflows where approvals, overrides, and freeze actions are **conditioned on compensation exposure**. Existing vendors market "combine incentive data with forecast for better visibility" — we enforce governance triggered by incentive economics. See §7.3.

**Differentiator 2 — Explainable Revenue-Behavior Intelligence**

> Structured, human-auditable explanations linking: (1) payout delta, (2) plan mechanics (tier/accelerator/SPIF), (3) observed forecast adjustments, (4) recommended governance action. Closest competitor explainability: Gong's per-score positive/negative signals — not comp-plan-aware. See §6.10.

**Differentiator 3 — One-Screen Manager Decision Cockpit**

> Single workflow screen joining forecast rollup + pipeline record list + per-record incentive estimator + signal trail + override audit. Current state: each component available separately in different tools; managers bounce between 3–4 tabs during a single forecast call. See §11.5.

### 1.5 Authoritative Data Ownership & State Boundaries

The platform is both **CRM-native** (lives inside the CRM workflow) and a **computational control layer** (owns forecast governance, incentive calculations, health scoring, and behavior intelligence). These two roles fight each other unless ownership boundaries are explicit.

#### 1.5.1 Ownership Model

| Data Domain                                                                                              | Authoritative Owner                               | Why                                                                                                                                                                                                                                            |
| -------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Pipeline record base state** (stage, close date, amount, owner, account)                               | **CRM**                                           | The CRM is the transactional system of record for pipeline. The platform reads but never writes these fields.                                                                                                                                  |
| **Forecast overrides** (metric values, category, notes, per hierarchy level)                             | **Platform**                                      | Forecast overrides are the platform's core IP. They do not exist in the CRM's native forecast object. The platform creates, stores, and governs these records.                                                                                 |
| **Governance events** (triggers, approvals, denials, justifications, badges)                             | **Platform**                                      | Governance is the platform's exclusive domain. No CRM object or workflow touches governance state.                                                                                                                                             |
| **Incentive calculations** (commissionable value, rate tier applied, payout amount, attainment snapshot) | **Platform**                                      | The platform is the authoritative calculation engine. Incentive results are immutable ledger entries — never recalculated in place; corrections create new adjustment records.                                                                 |
| **Attainment snapshots**                                                                                 | **Platform (snapshot-stored, not live-computed)** | Attainment is snapshot-stored at each calculation event. The snapshot is the authoritative attainment at the moment the calculation ran. Current attainment is derived from the latest snapshot + any uncalculated closed transactions.        |
| **Health scores**                                                                                        | **Platform**                                      | Scores are calculated and stored by the platform. CRM receives a mirrored score badge field for display convenience, but the platform's Pipeline Signal record is authoritative.                                                               |
| **Signal data** (from adapters)                                                                          | **Platform (canonical copy)**                     | Adapters pull from external sources. The platform normalizes and stores a canonical copy. The external source remains the upstream truth, but the platform's canonical copy is what scoring, governance, and behavior intelligence operate on. |
| **Behavioral flags** (sandbagging, optimism, threshold approach)                                         | **Platform**                                      | Exclusively platform-owned. Never surfaced as CRM fields.                                                                                                                                                                                      |
| **Manager accuracy**                                                                                     | **Platform**                                      | Computed from platform-owned forecast override history vs. CRM-owned close outcomes.                                                                                                                                                           |
| **Close probability** (AI)                                                                               | **Platform**                                      | Persisted on the platform's Forecast Override record, NOT written back to the CRM's pipeline record. Visible only within platform UI.                                                                                                          |

#### 1.5.2 Conflict Resolution Rules

When CRM state and platform state diverge, these rules apply:

| Scenario                                                                                                                        | Resolution                                                                                                                                                                                                                                                                                                                                                               | Rationale                                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CRM pipeline record changes after a governance action was taken                                                                 | **CRM wins for base fields** (stage, amount, close date). **Platform re-evaluates governance rules** against the new CRM state. If a governance approval was granted on the old state, and the CRM change invalidates the basis for approval, the platform flags the governance event as "stale — basis changed" and re-triggers evaluation.                             | CRM is the transactional source of truth. Governance must react to reality.                                                                                                                                                            |
| CRM close date changes after a forecast override was submitted                                                                  | **Platform retains the submitted override** but marks it with a "CRM divergence" warning badge. Reviewer sees: "CRM close date moved to {date} after this override was submitted." Override is not auto-changed — reviewer must acknowledge or re-submit.                                                                                                                | Forecast overrides are the platform's deliberate, human-reviewed state. Automatic sync would undermine governance.                                                                                                                     |
| CRM deal closes after a governance approval is pending (CG-3)                                                                   | **Pending approval is auto-resolved as "superseded."** Commission calculation proceeds using actual close data, not the pending forecast override. Governance event logged as "Superseded by close event."                                                                                                                                                               | Reality takes precedence over pending governance.                                                                                                                                                                                      |
| Incentive calculation exists but CRM deal is later re-opened or amount changed                                                  | **Platform does NOT auto-mutate the existing calculation.** Instead, the next processing run creates a new Incentive Calculation record reflecting the current state — effectively an adjustment. Original record remains for audit.                                                                                                                                     | Immutable ledger principle. Incentive calculations are event-sourced snapshots, not mutable recalculations.                                                                                                                            |
| Health score computed from adapter data that is stale (adapter sync failed)                                                     | **Platform uses last-known-good data with staleness badge.** Score card shows: "Signal source: {adapter} — last synced {time}. Data may be stale." Staleness threshold configurable (default: 24 hours). If stale beyond threshold, score is flagged but NOT zeroed — missing signal redistribution does NOT apply to stale data, only to absent adapters.               | Stale data is better than no data. But the user must know it's stale.                                                                                                                                                                  |
| CRM pipeline record deleted while platform has active Forecast Override, Governance Event, and/or Incentive Calculation records | **Platform retains all records** with a `Source_Record_Deleted` status badge. Records are excluded from active rollups, incentive estimator, and governance evaluation. Records are preserved for audit and historical reporting. Cockpit shows: "Source record deleted in CRM on {date}. Platform records retained for audit." Admin can manually archive after review. | Admins accidentally delete deals. Platform data (especially immutable incentive ledger entries) must survive CRM deletions. Deletion detection via scheduled reconciliation batch (daily) or CRM delete trigger if subscriber permits. |

#### 1.5.3 Write-Back Policy

The platform writes back to CRM only for **display convenience** — never for authoritative state:

| Field Written to CRM                                   | Purpose                                                     | Authoritative Source                |
| ------------------------------------------------------ | ----------------------------------------------------------- | ----------------------------------- |
| Health score badge (numeric field on pipeline record)  | Display in CRM list views and reports                       | Platform's Pipeline Signal record   |
| Alert flag (checkbox on pipeline record)               | Highlight records with active governance flags in CRM views | Platform's Governance Event records |
| Last forecast category (text field on pipeline record) | Allow CRM reports to group by forecast category             | Platform's Forecast Override record |

Write-back is:

- **Asynchronous** (via Platform Event in Phase 1, via CRM Adapter write method in Phase 3)
- **Non-blocking** — if CRM write-back fails, the platform continues operating. Write-back failures are logged and retried.
- **Configurable** — admins can disable any write-back field. Some orgs may not want platform data in CRM at all.

#### 1.5.4 Event-Sourcing Guarantee for Incentive Calculations

Incentive calculations follow an **append-only ledger model**:

1. Each processing event creates new Incentive Calculation records — it never updates existing ones.
2. If a transaction is reprocessed (amount changed, new eligible participant discovered, rate correction), new records are created with a `Processing_Run_Id` and `Adjustment_Type` (Original, Amendment, Reversal, Clawback).
3. The current state for any transaction × participant is derived by aggregating all Incentive Calculation records for that combination, ordered by processing run.
4. This means: any historical incentive state can be reconstructed by replaying records up to a given processing run. Audit trail is inherent in the data model.

### 1.6 Module Isolation Rules

Without explicit boundaries, the four modules risk becoming one giant interconnected system with shared assumptions everywhere. These rules define what each module **may** and **may not** do — violations are architectural bugs, not judgment calls.

#### 1.6.1 Per-Module Contracts

**Forecasting (Module 1) MAY:**

- Read CRM pipeline base state (via CRM Adapter)
- Write Forecast Override records (platform-owned)
- Write Forecast Comment records
- Read health scores (from Deal Health) for display in pipeline row
- Read incentive estimates (from Sales Incentives) for inline estimator display
- Publish governance evaluation requests (consumed by Governance Engine)
- Read governance events for display in Cockpit

**Forecasting MAY NOT:**

- Directly calculate incentives or write incentive records
- Directly mutate health score or Pipeline Signal records
- Directly write behavioral flags
- Write to CRM pipeline base fields (stage, amount, close date)

---

**Sales Incentives (Module 2) MAY:**

- Read closed pipeline events (via Platform Event / CRM Adapter)
- Write immutable Incentive Calculation records (append-only ledger)
- Write Draw Records, Payment Records, Payment Schedules
- Expose Incentive Impact Calculator API (consumed by Forecasting inline estimator and Governance Engine)
- Read attainment snapshots (own records)

**Sales Incentives MAY NOT:**

- Directly change forecast override state (categories, metric values, close dates)
- Directly write governance decisions (approve/deny/escalate)
- Directly write health scores or behavioral flags
- Mutate existing Incentive Calculation records (append-only — see §1.5.4)

---

**Deal Health (Module 3) MAY:**

- Consume normalized signal records from Signal Adapters
- Write Pipeline Signal records and Signal Change History
- Write Health Score Profile configuration
- Publish threshold-crossing alerts (consumed by Behavior Intelligence)
- Write display-convenience badges to CRM (async, non-authoritative — see §1.5.3)

**Deal Health MAY NOT:**

- Directly write CRM base fields (only async mirror badges, never authoritative)
- Directly write forecast overrides or incentive records
- Directly write governance decisions or behavioral flags

---

**Behavior Intelligence (Module 4) MAY:**

- Read forecast override history (from Forecasting)
- Read incentive attainment snapshots and plan configuration (from Sales Incentives)
- Read health scores and signal data (from Deal Health)
- Write Behavioral Flag records
- Write Behavior Explanation records
- Write Manager Accuracy records
- Generate coaching nudges (delivered via Notification system)
- Generate recommendations for governance review

**Behavior Intelligence MAY NOT:**

- Directly freeze, override, or modify any forecast state
- Directly approve, deny, or block any governance action
- Directly modify incentive calculations or attainment records
- Directly modify health scores or signal data
- Auto-penalize compensation based on behavioral flags
- Auto-freeze a forecast based on behavioral analysis

The last two prohibitions are critical: Behavior Intelligence is a **detection and explanation** module, never an **enforcement** module. It surfaces patterns for human review. Enforcement is exclusively the domain of deterministic Governance Rules (§7.3).

#### 1.6.2 Insight vs. Enforcement Boundary

The platform produces two fundamentally different classes of output. They must never blur:

| Class           | Examples                                                                                                                        | Who Acts on It                          | Can Block Workflow?                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------- |
| **Enforcement** | Governance rule triggers (CG-1–CG-7), forecast freeze, submission gating, approval requirements                                 | Deterministic rules engine              | **Yes** — but only deterministic Tier 1 logic (§9.2.1)                                  |
| **Insight**     | Health scores, behavioral flags, coaching nudges, anomaly alerts, behavior explanations, AI close probability, payout forecasts | Humans (managers, reviewers, Sales Ops) | **No** — insights recommend, prioritize, explain, and suggest review. They never block. |

**The rule:** Only deterministic governance rules may enforce. AI and Behavior Intelligence may only recommend, prioritize, explain, and suggest review. No predictive or narrative output (Tier 2 or Tier 3 per §9.2.1) can gate a workflow action.

This means:

- A behavioral flag (sandbagging signal) can appear in the Cockpit governance queue as an informational escalation (non-blocking)
- A behavioral flag **cannot** block a forecast submission or require approval on its own
- A governance rule (CG-2) triggered by **deterministic** compensation threshold proximity **can** block — because it evaluates a mathematical fact, not an inferred behavior
- AI close probability can inform a coaching nudge — it **cannot** trigger a governance hold

---

## 2. Personas & Roles

| Persona                                   | Primary Module Usage                     | Key Jobs-to-Be-Done                                                                                    |
| ----------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Sales Rep / AE**                        | Incentives, Deal Health                  | Understand earnings, track attainment, see deal risk signals, know what a deal is worth before closing |
| **Sales Manager (L1)**                    | Forecasting, Deal Health, Behavior Intel | Submit deal forecasts, review deal health, understand which deals to prioritize                        |
| **Sub-Director / Regional Director (L2)** | Forecasting, Behavior Intel              | Review manager submissions, override as needed, detect sandbagging patterns                            |
| **VP Sales / Director (L3)**              | Forecasting, Behavior Intel              | Cross-territory view, override and submit to COO, interpret AI predictions                             |
| **CRO / COO (L4+)**                       | Forecasting, Behavior Intel              | Freeze finalized forecasts, review AI-predicted vs. submitted numbers                                  |
| **Commissions Admin / Finance**           | Sales Incentives                         | Process commissions, manage draws, export to payroll, audit calculations                               |
| **Sales Operations**                      | All modules                              | Configure plans, hierarchies, metrics, categories, weight profiles                                     |
| **HR / Compensation Team**                | Sales Incentives                         | Design plans, run plan simulations, manage plan acceptance workflow                                    |

---

## 3. Module 1 — Forecasting

### 3.1 Core Capability

A configurable, multi-level hierarchical pipeline forecasting engine. Any number of review levels, any metric set, any time period cadence, and any pipeline record type can be modeled. Each hierarchy level independently overrides pipeline values with full audit trail. No field, level name, metric name, period type, or category is hardcoded — every dimension is defined by the org's admin at setup time.

**Industry examples of the same engine applied differently:**

| Industry           | Record Type        | Metric 1       | Metric 2          | Periods   | Hierarchy                                                |
| ------------------ | ------------------ | -------------- | ----------------- | --------- | -------------------------------------------------------- |
| Enterprise SaaS    | Opportunity        | TCV            | ARR               | Quarterly | AE → Regional Director → VP → CRO                        |
| Insurance          | Policy Application | Premium Value  | Policy Count      | Monthly   | Agent → Branch Manager → Regional VP → Chief Underwriter |
| Real Estate        | Property Listing   | Sale Price     | Commission Value  | Monthly   | Agent → Team Lead → Broker → Managing Director           |
| Manufacturing      | Project Bid        | Contract Value | Margin            | Quarterly | Sales Engineer → Area Manager → Division VP → COO        |
| Healthcare IT      | RFP / Contract     | Contract Value | Recurring Revenue | Quarterly | Account Exec → District Manager → Regional VP → CRO      |
| Financial Services | Investment Mandate | AUM Commitment | Fee Revenue       | Monthly   | Advisor → Team Manager → Regional Director → CIO         |

---

### 3.2 Forecast Template Configuration

A **Forecast Template** is the top-level configuration object that defines the rules for a forecasting deployment. Multiple templates can coexist (e.g., one per product line, one per region, one for budget vs. forecast).

Each template configures:

#### 3.2.1 Hierarchy Levels

| Config Field           | Description                          | Example Values                          |
| ---------------------- | ------------------------------------ | --------------------------------------- |
| Level Count            | Number of review levels (2–10)       | 3, 4, 5                                 |
| Level Labels           | Display name per level               | ["Rep", "Manager", "Director", "CRO"]   |
| Level Permissions      | Can submit, can freeze, can override | Configurable per level                  |
| Top-Level Action Label | Label for the final lock action      | "Freeze", "Lock", "Approve", "Finalize" |

The top-level user (highest hierarchy level) holds the lock/freeze authority. The concept of "who can freeze" is determined by hierarchy position, not by a hardcoded role name.

#### 3.2.2 Forecast Metrics

Each template defines 1–6 metrics. A metric is a configurable value that participants override on each pipeline record.

| Config Field    | Description                                        | Example                                            |
| --------------- | -------------------------------------------------- | -------------------------------------------------- |
| Metric Name     | Display label                                      | "TCV", "ARR", "Premium", "Units", "Contract Value" |
| Metric Type     | Currency / Number / Percentage                     | Currency                                           |
| Aggregation     | Sum / Average / Count                              | Sum                                                |
| Trend Threshold | Absolute change that triggers a trend indicator    | 100,000 (currency) / 50 (units)                    |
| Trend Direction | Higher = better or Lower = better                  | Higher                                             |
| Display Format  | Currency symbol, decimal places, thousands scaling | $M, $K, #                                          |
| Required        | Whether this metric must be filled to submit       | True / False                                       |

#### 3.2.3 Forecast Categories

Configurable ordered list of categories, with behavior rules per category:

| Config Field           | Description                                                  | Example Sets                                            |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------- |
| Category Name          | Display label                                                | "Commit", "Best Case", "Pipeline", "Closed Won", "Lost" |
| Category Color         | Hex color for UI                                             | #2ECC71 (green for Commit)                              |
| Counts Toward Target   | Whether this category is included in coverage calculations   | True for Commit/Best Case                               |
| Terminal               | Once set, no further changes allowed                         | True for Closed Won / Lost                              |
| Regression Warning     | Moving to this category from a higher one triggers a warning | True for "Pipeline"                                     |
| Budget Mode Equivalent | The corresponding category when template runs in budget mode | "Budget" maps to "Commit"                               |

#### 3.2.4 Time Periods

| Config Field            | Description                                  | Examples                                            |
| ----------------------- | -------------------------------------------- | --------------------------------------------------- |
| Period Type             | The forecasting cadence                      | Weekly, Monthly, Quarterly, Annual                  |
| Period Labels           | Display names per period                     | ["Q1", "Q2", "Q3", "Q4"] or ["Jan", "Feb", "Mar" …] |
| Fiscal Year Start       | Month the fiscal year begins                 | April (April–March FY)                              |
| Future Periods Only     | Whether past periods are locked for editing  | True / False                                        |
| Period Count in Summary | How many periods appear in the summary table | 4 (quarters), 12 (months), 52 (weeks)               |

#### 3.2.5 Pipeline Record Context Fields

The set of read-only context columns displayed on each pipeline record row. These are mapped from the source CRM or data system and are fully configurable:

| Config Field      | Description                | SaaS Example       | Insurance Example   |
| ----------------- | -------------------------- | ------------------ | ------------------- |
| Record Identifier | Auto-number or name        | Opportunity Number | Application ID      |
| Record Name       | Primary display name       | Opportunity Name   | Policy Name         |
| Owner             | Assigned rep               | Owner Name         | Agent Name          |
| Category 1        | Segment/type field         | Deal Type          | Product Line        |
| Category 2        | Sub-type field             | Platform           | Coverage Type       |
| Stage             | Current pipeline stage     | Stage Name         | Underwriting Status |
| Reference Value   | External benchmark         | Renewal ACV        | Prior Year Premium  |
| Custom Fields 1–5 | Additional context columns | Region, Sub-Region | Territory, Channel  |

#### 3.2.6 Territory / Scope Grouping

| Config Field       | Description                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| Scope Object Label | What a "territory" is called ("Territory", "Region", "Branch", "Portfolio") |
| Scope Hierarchy    | Whether scopes are nested (Region > Sub-Region > Territory)                 |
| Deduplication Rule | When a record appears in multiple scopes, which scope's rollup owns it      |
| Currency Per Scope | Optional local currency mapping per scope                                   |

---

### 3.3 Pipeline Record Row

Each pipeline record (deal, policy, property, bid, mandate — whatever the configured record type is) appears as one row in the forecast grid.

#### 3.3.1 Read-Only Context Fields

Populated from source system at load time. Displayed based on the template's configured context field mapping (see §3.2.5). Common columns: record identifier, name, owner, stage, segment, reference value, previous-level submitted values.

#### 3.3.2 Editable Fields per Level

| Field               | Type                         | Notes                                                     |
| ------------------- | ---------------------------- | --------------------------------------------------------- |
| Forecast Period     | Configured period picker     | Future periods only (if template enforces it)             |
| Metric 1 … Metric N | Per template config          | Numeric/currency inputs; one column per configured metric |
| Forecast Category   | Configured category picklist | Options from §3.2.3                                       |
| Level Notes         | Long text                    | Editable by owning level; read-only to higher levels      |

#### 3.3.3 Trend Indicators

When a metric value changes from its previous-period value, a directional indicator fires if the delta exceeds the metric's configured trend threshold:

- Delta ≥ +threshold → green up-arrow
- Delta ≤ −threshold → red down-arrow
- Category moved toward a regression-flagged category → orange warning

Thresholds are per-metric per-template, not global constants.

#### 3.3.4 Row Status & Color

| Status          | Color     | Meaning                           |
| --------------- | --------- | --------------------------------- |
| New             | Red       | Record loaded, no edits made      |
| Dirty           | Yellow    | Edited, not yet saved             |
| Saved           | Blue      | Saved, not submitted              |
| Submitted       | Green     | Submitted to next level           |
| Locked / Frozen | Dark Grey | Top-level lock applied; immutable |

#### 3.3.5 Inline Incentive Estimator

Each pipeline record row displays real-time incentive impact data when the participant has an active Incentive Plan. This addresses the #1 competitor gap: managers currently cannot see what a deal is worth to a rep during a forecast call without switching to a separate commission tool.

**Columns (visible when Sales Incentives module is active):**

| Column              | Value                                                          | Calculation                                              |
| ------------------- | -------------------------------------------------------------- | -------------------------------------------------------- |
| Incentive Rate      | Current applicable rate %                                      | From participant's active plan × current attainment tier |
| Payout Estimate     | Estimated payout if this record closes at current metric value | Metric value × commissionable value formula × rate       |
| Threshold Proximity | Distance to next rate tier                                     | Quota threshold − current attainment (absolute and %)    |
| Tier Impact         | What happens if this record crosses a tier boundary            | "Closes → Tier 2 (+4% on all)" or "No tier change"       |
| Governance Flag     | Any active comp-aware governance flag (§7.3)                   | ⚠ CG-2, ℹ CG-7, etc.                                     |

**Behavior:**

- Recalculates in < 500ms on every override save (same engine as §7.3.4)
- When a manager changes the metric value or category, the incentive columns update immediately — no page refresh, no sync delay
- Hovering over the Payout Estimate shows a tooltip with the full incentive trace: plan name, rate tier, commissionable value formula applied, attainment context
- Clicking the Payout Estimate opens the full Incentive Trace panel in the Manager Decision Cockpit detail view (§11.5)
- Columns are hideable per user preference; default ON for managers, OFF for reps (configurable)

---

### 3.4 Forecast Record Lifecycle

```
New
  → [User edits any field] → Dirty
  → [Save action] → Saved
  → [Submit action] → Submitted (read-only for submitting level; visible to next level)
  → [Top-level lock action] → Frozen / Locked (immutable for all users)
```

Both Save and Submit support two modes:

- **Partial:** Only currently filtered/visible records are acted on
- **Full:** All records in the current scope, regardless of active filters

The scope-level status (e.g., "this territory's forecast status") reflects whether all, some, or no records have been submitted: `Not Started → Partially Saved → Saved → Partially Submitted → Submitted → Frozen`.

---

### 3.5 Actions

| Action                     | Available To   | Behavior                                                                                                                                           |
| -------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Save**                   | All levels     | Persists dirty records (partial or full). Updates scope status.                                                                                    |
| **Submit**                 | All levels     | Marks submitted records read-only for current user; makes them visible as "Previous Level" to the level above.                                     |
| **Copy from Level Below**  | Levels 2+      | Copies submitted values from the immediately lower level into current level as Dirty. Only applies to records where the level below has submitted. |
| **Copy from Prior Period** | Level 1        | Copies the current user's own submitted values from the previous forecast period into current period as Dirty.                                     |
| **Lock / Freeze**          | Top level only | Locks all records in the scope permanently. Label is configurable ("Freeze", "Finalize", "Approve").                                               |
| **Export**                 | All levels     | CSV/Excel export of the current filtered view.                                                                                                     |

All destructive or irreversible actions (Submit, Lock, Copy) display a confirmation dialog before executing.

---

### 3.6 Summary Table

Displays aggregated metric totals, grouped by configured forecast categories, across all configured time periods.

| Config           | Behavior                                                                                                                                           |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rows             | One row per configured forecast category + one Total row                                                                                           |
| Columns          | One column per configured period (Q1–Q4, or Jan–Dec, or Week 1–52, etc.) + Total column                                                            |
| Metric Toggle    | When multiple metrics are configured, a dropdown switches the summary between them; or a side-by-side view shows metrics simultaneously            |
| Segment Views    | Configurable sub-table views (e.g., by deal type, by product, by segment) — defined per template, not hardcoded                                    |
| Auto-Refresh     | Recalculates whenever a filter changes (client-side, no server call)                                                                               |
| AI Predicted Row | At the top-level hierarchy view, an additional "AI Predicted" row shows the probability-weighted pipeline total vs. submitted total (see Module 4) |

---

### 3.7 Historical Notes

Each pipeline record row has a notes section. An expandable "Comments History" button shows all notes entered for that record across prior forecast periods, sorted newest first. Notes are stored as a comment object keyed to: Record ID + User ID + Forecast Period. Visible to all levels; editable only by the level that owns each note.

---

### 3.8 Budget Mode

Any forecast template can be run in a secondary "Budget Mode" by toggling a flag on the period definition. Budget mode:

- Substitutes the budget-mapped category labels (configurable per category — see §3.2.3)
- Applies distinct visual styling to the summary table header to distinguish budget from forecast
- Allows Budget and Forecast periods to coexist in the period selector
- Enables side-by-side Budget vs. Forecast comparison in the summary table (Phase 2)

---

### 3.9 Scenario Planning (Phase 2)

Up to N named scenarios per forecast period (e.g., Commit / Best Case / Worst Case / Budget). Each scenario stores its own independent set of override values. The summary table can show all scenarios as side-by-side columns. Individual record rows show the active scenario's values with a scenario selector toggle. Scenarios do not affect each other's values.

---

### 3.10 Multi-Currency Support

Each scope (territory, branch, region) can be assigned a local currency. Users toggle between local currency and a configured base currency (e.g., USD, EUR) per session. Exchange rates are sourced from a configurable rate table (custom metadata or external API). All summary table calculations normalize to the base currency; local values are shown as secondary display only.

---

### 3.11 Business Rules

| Rule                       | Behavior                                                                                                                                                                                                                        |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Period Validation          | If the template enforces "future periods only", past periods are non-selectable. Validation message is configurable.                                                                                                            |
| Hierarchy Read-Only        | Submitted records are read-only for the submitting user and all levels below. The level above can still override.                                                                                                               |
| Lock Immutability          | Once the top-level lock action is applied to a scope, no edits are allowed by any user, including the top-level user.                                                                                                           |
| Record Share Deduplication | When a pipeline record appears in multiple scopes at the top level (e.g., a deal split across regions), the deduplication rule defined in the template determines which scope's rollup includes it, preventing double-counting. |
| Copy Eligibility           | Copy from Level Below only operates on records where the level below has a submitted value. Records with no lower-level submission are skipped.                                                                                 |
| Partial Status             | The scope-level status reflects partial vs. full completion: "Partially Submitted" when some but not all records have been submitted.                                                                                           |
| Notes Ownership            | Notes entered at a given hierarchy level are read-only for all higher levels. Only the owning level can edit their own notes.                                                                                                   |

---

## 4. Module 2 — Sales Incentives

### 4.1 Core Capability

A configurable, end-to-end incentive compensation engine. The platform is entirely role-agnostic, industry-agnostic, and deal-type-agnostic. No participant title (AE, Agent, Broker, Rep), no transaction category (Subscription, Policy, Project, Property), and no field name is hardcoded. All are defined at configuration time.

**Industry examples of the same engine applied differently:**

| Industry           | Participants                                        | Transaction Categories                        | Trigger                             | Commissionable Basis                  |
| ------------------ | --------------------------------------------------- | --------------------------------------------- | ----------------------------------- | ------------------------------------- |
| Enterprise SaaS    | AE, BDR, SE, CSM, Partner Rep, Manager              | New Subscription, Renewal, Services, Training | Deal close / Rev Rec event          | Booking value / recognized revenue    |
| Insurance          | Agent, Broker, Agency Manager, Underwriter          | Life, Property, Auto, Health                  | Policy issued / Policy renewed      | Annual premium / Policy value         |
| Real Estate        | Listing Agent, Buyer Agent, Team Lead, Broker       | Residential Sale, Commercial Sale, Lease      | Transaction close                   | Sale price × commission %             |
| Manufacturing      | Sales Engineer, Territory Manager, Channel Partner  | Direct Sale, Distributor, Replacement Parts   | Purchase order                      | Contract value / Gross margin         |
| Financial Services | Advisor, Wealth Manager, Branch Manager             | New Account, AUM Growth, Referral             | Account funded / AUM threshold      | Assets under management / Fee revenue |
| Telecommunications | Sales Rep, Channel Agent, Retention Specialist      | New Contract, Upgrade, Retention Win          | Contract signed / Service activated | Monthly recurring value × term        |
| Healthcare IT      | Account Exec, Clinical Specialist, Partner          | New Implementation, Renewal, Expansion        | Contract execution                  | Contract value / Recognized revenue   |
| Retail             | Store Associate, Category Manager, District Manager | Product Sale, Bundle, High-Margin SKU         | Point of sale                       | Revenue / Gross margin                |

---

### 4.2 Incentive Plan Configuration

An **Incentive Plan** is the core configuration object. It defines the rules for who earns, on what, how much, and when. Multiple plans coexist simultaneously within one org — different plans for different roles, regions, products, or fiscal periods.

#### 4.2.1 Plan Scope

Every plan has a scope that determines which transactions it applies to:

| Scope Level | Description                                                               | Example                               |
| ----------- | ------------------------------------------------------------------------- | ------------------------------------- |
| Individual  | Applies to a single named participant                                     | A specific rep's personal plan        |
| Role        | Applies to all participants in a configured role                          | All agents in the "Field Sales" role  |
| Team        | Applies to a defined group of participants, with pool or split logic      | A named account team                  |
| Territory   | Applies to all eligible participants within a geographic or segment scope | All reps in the "Northeast" territory |
| Global      | Applies to all eligible participants regardless of scope                  | A company-wide SPIFF or bonus pool    |

#### 4.2.2 Plan Trigger

The event that causes the plan to fire and create a commission calculation:

| Trigger Type        | Fires When                                                       | Industry Example                                         |
| ------------------- | ---------------------------------------------------------------- | -------------------------------------------------------- |
| Transaction Close   | Source record reaches a terminal "won" status                    | Deal closed, policy issued, property sold                |
| Stage / Milestone   | Source record reaches a configured intermediate stage            | Signed LOI, underwriting approval, contract execution    |
| Activity Completion | A configured activity type is logged                             | Demo delivered, site visit completed, referral submitted |
| Revenue Event       | An external revenue recognition or invoice event                 | Rev Rec line item, invoice payment received              |
| Recurring Schedule  | A scheduled job fires on a cadence                               | Monthly renewal commission, quarterly residual           |
| Threshold Crossing  | A participant's cumulative attainment crosses a configured level | Rep crosses 100% quota → accelerator unlocked            |
| Manual              | Admin-triggered for one-off adjustments                          | Discretionary bonus, correction                          |

Multiple triggers can coexist on a single plan. Each trigger type has configurable conditions (e.g., "fire only if transaction probability ≥ 90%", "fire only if transaction category = New Business").

#### 4.2.3 Commissionable Value Formula

The value that the commission rate is applied to. Fully configurable per plan:

| Formula Type           | Description                                           | Example                                           |
| ---------------------- | ----------------------------------------------------- | ------------------------------------------------- |
| Full Transaction Value | Total value of the transaction                        | Total contract value                              |
| Partial Value (%)      | A configured percentage of the transaction value      | 60% of contract = commissionable                  |
| Line-Item Specific     | Only specific product/service lines qualify           | Only "Core License" line items                    |
| Gross Margin           | Revenue minus configured cost basis                   | (Sale price − COGS) × rate                        |
| Recurring Value        | Extracted recurring component (MRR/ARR)               | Annual contract ÷ term in months                  |
| Year-N Value           | A specific year's value from a multi-year transaction | Year 1 value from a 3-year contract               |
| Custom Expression      | A formula built from transaction fields               | `(Base_Price × Committed_Term) − Discount_Amount` |
| Collection-Adjusted    | Value reduced proportionally by payment received      | `Full_Value × (Amount_Collected / Total_Invoice)` |
| Revenue-Recognized     | Value from an external recognition event              | Rev Rec line amount                               |

Split ratios (e.g., vertical territory splits) are applied as a multiplier on any formula.

#### 4.2.4 Rate Structure

The rate structure defines how much the participant earns on the commissionable value. Eight rate structure types are supported:

| Structure Type             | How It Works                                                               | Config Fields                       | Industry Use                                   |
| -------------------------- | -------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------- |
| **Flat Rate**              | Single fixed % regardless of attainment                                    | Rate %                              | Simple agent plans                             |
| **Quota-Based Flat**       | Fixed % that only applies once a quota threshold is met                    | Quota amount, minimum attainment %  | Sales plans with floor requirement             |
| **Tiered Rate Bands**      | Different rates apply to different value bands within a single transaction | Band table: (min, max, rate%)       | Real estate, manufacturing, financial services |
| **Attainment Accelerator** | Rate increases as cumulative attainment crosses thresholds                 | N tiers: (attainment %, rate%)      | SaaS AE plans, insurance agents                |
| **Activity Reward**        | Fixed dollar or % reward per completed activity                            | Activity type, reward amount        | BDR, inside sales, retail                      |
| **Milestone Payout**       | Percentage of total commission paid at each stage                          | Stage table: (stage name, payout %) | Complex B2B, implementation-gated              |
| **Gross Margin Rate**      | Rate applied to the margin, not the revenue                                | Margin calculation method, rate %   | Manufacturing, distribution                    |
| **Pool Distribution**      | A pool funded by transactions; distributed to participants per rules       | Funding formula, distribution rule  | Team plans, bonus pools                        |

Rate structures can be combined within a single plan (e.g., flat base rate + attainment accelerator tiers on top).

#### 4.2.5 Attainment & Quota

| Config Field              | Description                                                                                 |
| ------------------------- | ------------------------------------------------------------------------------------------- |
| Quota Period              | The period over which attainment accumulates (weekly, monthly, quarterly, annually, custom) |
| Quota Amount              | Target for the period; can differ per period (Q1 ≠ Q2)                                      |
| Quota Currency            | The currency in which quota is denominated                                                  |
| Attainment Basis          | What counts toward quota (transaction value, unit count, recurring value, margin)           |
| Cumulative vs. Per-Period | Whether attainment resets each period or accumulates across the year                        |
| Quota Retirement Rule     | Whether a transaction retires quota, and how much (full value, partial, none)               |
| Accelerator Threshold(s)  | Attainment percentage(s) that unlock a higher rate tier                                     |

#### 4.2.6 Modifiers

Post-calculation adjustments applied to the base commission amount:

| Modifier Type         | Description                                                    | Config Fields                                       |
| --------------------- | -------------------------------------------------------------- | --------------------------------------------------- |
| Duration Bonus        | Higher rate for longer-term transactions                       | Minimum term, bonus rate                            |
| Duration Penalty      | Lower rate for short-term transactions                         | Maximum term for penalty, reduction %               |
| Collection Adjustment | Commission reduced proportionally if payment not received      | Trigger (% collected threshold), adjustment formula |
| Plan Cap              | Maximum total commission payable under this plan in the period | Cap amount or cap as % of quota                     |
| Per-Transaction Cap   | Maximum commission on any single transaction                   | Cap amount                                          |
| Dependent Plan Gate   | This plan only pays if another plan has crossed a threshold    | Linked plan, required attainment %                  |
| Hold Condition        | Commission calculated but held pending a future event          | Trigger condition, release condition                |

#### 4.2.7 Plan Scope & Period

| Config Field         | Description                                                                   |
| -------------------- | ----------------------------------------------------------------------------- |
| Fiscal Period        | The year or period this plan covers                                           |
| Effective Date Range | Start and end dates for plan activation                                       |
| Plan Label           | Admin-defined name (e.g., "FY26 Enterprise AE Plan", "Q1 Agency Bonus")       |
| Currency             | The currency commissions are paid in                                          |
| Reprocess Policy     | Whether previously processed transactions can be recalculated on plan changes |

---

### 4.3 Participant Role Configuration

Participant Roles replace hardcoded job titles. A role is a named configuration that defines:

| Config Field                    | Description                                                     | Example Values                                                               |
| ------------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Role Name                       | Display name                                                    | "Account Executive", "Insurance Agent", "Listing Agent", "Territory Manager" |
| Role Code                       | System identifier                                               | `AE`, `AGENT`, `LISTING_AGENT`, `TM`                                         |
| Linked Plans                    | Which incentive plans apply to this role                        | Many-to-many                                                                 |
| Eligible Transaction Categories | Which transaction types this role can earn on                   | Configurable per role                                                        |
| Hierarchy Role                  | Whether this role earns override/manager commissions on reports | Boolean                                                                      |
| Commission Split %              | Default split % when this role participates alongside others    | Overridable per plan                                                         |

**Participant-to-Transaction Mapping** (replaces hardcoded eligibility table):

Instead of a hardcoded matrix (AE × Subscription = ✓, BDR × Renewal = —), eligibility is defined by a declarative rule per role per transaction category:

```
Role: [Account Executive]
  Eligible for: [New Business, Expansion, Renewal]    → condition: is_transaction_owner = TRUE
  Eligible for: [Services]                            → condition: probability >= 100 AND services_type IN configured_list
  Not eligible for: [Internal Transfer]

Role: [Business Development Rep]
  Eligible for: [New Business]                        → condition: bdr_sourced = TRUE
  Not eligible for: [Renewal, Expansion]

Role: [Customer Success Manager]
  Eligible for: [Renewal, Expansion]                 → condition: is_account_csm = TRUE
  Eligible for: [New Business]                        → condition: existing_customer = TRUE AND csm_eligible = TRUE
```

Rules are evaluated per transaction at processing time. Conditions reference transaction fields, participant fields, or custom attributes — all configurable by the admin without code changes.

---

### 4.4 Transaction Category Configuration

Transaction Categories replace hardcoded deal types (Subscription/Renewal/Services/Training). Each category is defined by:

| Config Field              | Description                                                 | Example: SaaS      | Example: Insurance     |
| ------------------------- | ----------------------------------------------------------- | ------------------ | ---------------------- |
| Category Name             | Display label                                               | "New Subscription" | "New Life Policy"      |
| Category Code             | System identifier                                           | `NEW_SUB`          | `LIFE_NEW`             |
| Commissionable Value Rule | Which value formula applies by default                      | Full booking value | Annual premium         |
| Eligible Roles            | Roles that can earn on this category                        | AE, BDR, SE, CSM   | Agent, Agency Manager  |
| Processing Conditions     | Conditions the transaction must meet to trigger commissions | Probability = 100  | Policy status = Issued |
| Quota Category            | Which quota bucket this credits toward                      | New Business       | Life Division          |
| Reprocessable             | Whether this category allows commission reprocessing        | Yes                | Yes                    |

Transaction categories are fully extensible. An insurance company adds "Homeowner Renewal" and "Commercial Property" as categories without any code changes. A real estate platform adds "Residential", "Commercial", "Land" categories. Each gets its own eligibility rules, value formulas, and rate plans.

---

### 4.5 Commission Calculation Engine

The calculation engine is a rules-based pipeline that executes in defined steps. Every step is configurable; none reference industry-specific values.

#### Step 1 — Identify Participants

For the incoming transaction event, resolve the list of eligible participants:

1. Evaluate each configured role's eligibility conditions against the transaction
2. For each eligible role, identify the specific person(s) filling that role on this transaction (from transaction fields, account assignments, or explicit lookup objects)
3. Add manager/hierarchy participants if any active plan has hierarchy eligibility enabled

#### Step 2 — Resolve Active Plans

For each participant, find all active Incentive Plans that:

- Are in effect for this transaction's date
- Match the transaction's category
- Match the participant's role
- Pass scope conditions (territory, region, global)

Priority order when multiple plans match: Individual → Role → Territory → Global (configurable).

#### Step 3 — Compute Commissionable Value

Apply the plan's configured Commissionable Value Formula (see §4.2.3) to the transaction. This may involve reading line-item data, external cost records, or collection/payment status — all via configurable field mappings, not hardcoded logic.

#### Step 4 — Apply Rate Structure

Evaluate the plan's Rate Structure (see §4.2.4) against the commissionable value and the participant's current attainment:

- For **flat or quota-based** plans: multiply commissionable value × applicable rate
- For **tiered band** plans: split commissionable value across bands and sum
- For **attainment accelerator** plans: look up current attainment %, find applicable tier, apply that tier's rate
- For **milestone** plans: determine current stage, pay the configured % for that stage milestone
- For **activity** plans: count qualifying activities and apply per-activity reward
- For **pool** plans: fund the pool; defer distribution to the pool's distribution schedule

Multiple rate structures on the same plan produce multiple calculation records (one per rate tier / milestone stage), each visible independently in the breakdown.

#### Step 5 — Apply Modifiers

In order: Duration Bonus → Duration Penalty → Collection Adjustment → Per-Transaction Cap → Plan Cap → Dependent Plan Gate. Each modifier either adjusts the amount or places the calculation in a Hold state with a hold reason.

#### Step 6 — Persist Calculation Records

One **Incentive Calculation Record** is created per: Transaction × Participant × Plan × Rate Tier / Milestone. This is the immutable ledger entry. Key fields:

| Field                | Description                                                                                  |
| -------------------- | -------------------------------------------------------------------------------------------- |
| Calculated Amount    | The commission dollar amount                                                                 |
| Rate Applied         | The specific rate % used                                                                     |
| Rate Tier Label      | Human-readable label of the tier ("Base Rate", "Tier 2 Accelerator", "Milestone 1 — Signed") |
| Commissionable Value | The value the rate was applied to                                                            |
| Hold Status          | Whether payment is held and for what reason                                                  |
| Quota Retired        | Whether and how much quota was credited                                                      |
| Processing Trigger   | What event caused this calculation                                                           |
| Audit Trail          | Snapshot of all inputs at time of calculation                                                |

#### Step 7 — Reprocessing Detection

When a transaction is reprocessed (plan change, participant change, correction), the engine compares new calculation records against existing ones. Net-new records are added; existing records are preserved. Admin is prompted to review and confirm before committing changes. A complete diff (added, modified, unchanged) is shown before confirmation.

---

### 4.6 Draws, Advances & Paybacks

Draws are cash payments made against future earned commissions. The draw balance is tracked per participant.

| Transaction Type | Effect on Balance | When Used                                                     |
| ---------------- | ----------------- | ------------------------------------------------------------- |
| Draw             | Increases balance | Advance against expected future earnings                      |
| Advance          | Increases balance | One-time cash advance (e.g., onboarding)                      |
| Payback          | Decreases balance | Repayment of draw; floor is 0                                 |
| Clawback         | Decreases balance | Recovery of previously paid commission (e.g., customer churn) |

Each draw record stamps the participant's beginning and ending balance at the time of the transaction. Balance changes are applied in real time. The admin dashboard shows: Earned − Paid − Clawback + Draws = Delta (Net owed or Net overpaid).

---

### 4.7 Participant Self-Service Portal

The portal is metric-agnostic and driven by the participant's configured plans and quota settings.

| Section                  | Content                                                                                     | Notes                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| **Earnings Summary**     | Period-to-date earned, paid, upcoming, draw balance                                         | Periods are the configured fiscal periods from §4.2.5  |
| **Attainment Dashboard** | Visual attainment gauges per plan per period                                                | Gauge labels use plan's configured quota period labels |
| **By Plan**              | Per-plan breakdown: quota target, achieved, rate tier, earned                               | Rate tier labels are plan-configured, not hardcoded    |
| **By Transaction**       | Per-transaction earnings with full calculation breakdown                                    | Uses the audit trail from Step 6                       |
| **Upcoming Payments**    | Scheduled payment events in next 1–2 payment cycles                                         | Based on Payment_Schedule records                      |
| **Held Commissions**     | Calculations in Hold state with hold reason and release condition                           | Rep can see what's held and why                        |
| **What-If Simulator**    | Enter a hypothetical transaction → system shows projected impact on attainment and earnings | Respects all plan rules and current attainment state   |
| **My Plans**             | All active plans with configurable detail view; history of plan changes                     | Plan document with signature status                    |
| **Disputes**             | View and raise disputes on specific calculation records                                     | Links to dispute workflow                              |

---

### 4.8 Admin Incentive Dashboard

Fully configurable filter and column set. No hardcoded transaction types or role names.

**Filters (all dynamically derived from active config):**

- Fiscal Period (derived from plan periods — not hardcoded "Fiscal Year")
- Transaction (lookup or search)
- Participant (lookup or search)
- Role (derived from configured roles)
- Transaction Category (derived from configured categories)
- Plan (derived from active plans)
- Payment Status (Unpaid / Paid / Held / Disputed)

**Column Groups (configurable; default set below):**

| Column Group   | Fields                                              |
| -------------- | --------------------------------------------------- |
| Transaction    | Transaction name, close date, category              |
| Participant    | Name, role                                          |
| Plan           | Plan name, quota category                           |
| Commissionable | Commissionable value, collection %, adjusted value  |
| Rate           | Rate tier applied, rate % per tier                  |
| Earnings       | Amount per tier, total earned                       |
| Payment Status | Amount due, amount paid, clawback, draws, net delta |

Export to CSV/Excel. Chunked in configurable batch sizes (default: 1,000 records). Admin can save custom column configurations as named views.

---

### 4.9 Plan Acceptance Workflow

Plan acceptance is gated by configurable conditions:

1. **Publish:** Admin activates an Incentive Plan for a period. System identifies all participants assigned to the plan.
2. **Notify:** Configurable notification sent to participants: in-app, email, Slack, Teams.
3. **Review:** Participant opens plan details in self-service portal. Plan document (PDF or inline) displayed.
4. **Sign:** Participant accepts via:
   - In-platform digital signature (click-to-accept with audit log)
   - Integrated eSignature provider (DocuSign, AdobeSign — configurable)
5. **Gate:** Commission processing is configurable-gated on acceptance:
   - Hard gate: processing blocked until acceptance recorded
   - Soft gate: processing proceeds but admin notified of unsigned plans
   - No gate: acceptance tracked for record only
6. **Record:** Acceptance date, method, and optional signature document stored against the participant's plan record.

---

### 4.10 Commission Dispute Workflow

1. Participant flags a specific Incentive Calculation Record as disputed from the portal (provides reason and expected amount)
2. System creates a Dispute record linked to the calculation
3. Admin receives notification; dispute appears in a dedicated Dispute Queue
4. Admin reviews: calculation inputs, audit trail, plan rules. AI Dispute Assistant (see Module 4 §9.5) generates a natural-language explanation
5. Admin responds: explanation only, or correction (admin edits calculation or creates adjustment record)
6. Resolution status and explanation stored; participant notified
7. Dispute history visible in both rep portal and admin dashboard; dispute rate per plan is tracked as a plan quality metric

---

### 4.11 Payroll Integration

- Scheduled export job generates a payment file from Payment Records marked ready for payment
- **Configurable per integration:**
  - Output format: CSV flat file, JSON, direct API push
  - Column mapping: map platform fields to recipient system's expected field names
  - Payment frequency: weekly, bi-weekly, semi-monthly, monthly
  - Recipient system: ADP, Workday, SAP HR, NetSuite, or generic HTTP endpoint
  - Scope: export all, or filter by role, plan, territory, payment status
- **Export log:** Records each run with record count, total amount, status, any errors, and a per-record acknowledgment when the receiving system confirms receipt

---

## 5. Module 3 — Deal Health

### 5.1 Core Capability

A configurable, deterministic, fully explainable composite health score (0–100) for each pipeline record in the active forecast. The term "deal" is used generically throughout this module — it refers to whatever pipeline record type the org's Forecast Template defines (opportunity, policy application, property listing, project bid, investment mandate, etc.). Scores appear in the Forecasting pipeline row, the participant portal, and the manager's pipeline view. Scores are not black-box ML — every point is traceable to a specific signal.

**Industry examples of the same scoring engine applied differently:**

| Industry           | Pipeline Record    | Key Signals                                                   | "Decision Maker" Means    |
| ------------------ | ------------------ | ------------------------------------------------------------- | ------------------------- |
| Enterprise SaaS    | Opportunity        | Call recordings, email threads, CRM stage                     | Economic buyer / VP       |
| Insurance          | Policy Application | Agent–underwriter communication, document submissions         | Underwriting authority    |
| Real Estate        | Property Listing   | Buyer–agent communication, showing activity, offer status     | Buyer / Buyer's agent     |
| Manufacturing      | Project Bid        | RFP responses, site visit logs, engineering review status     | Procurement lead          |
| Financial Services | Investment Mandate | Client meeting cadence, compliance review, due diligence docs | Portfolio committee chair |
| Healthcare IT      | RFP / Contract     | Vendor demo attendance, clinical review board status          | CMIO / CTO                |

### 5.2 Score Architecture

```
Composite Health Score (0–100)
    = weighted_sum(Component Scores)
    + Adjustments (flat point modifiers)
    clamped to [0, 100]
    after Missing Signal Redistribution
```

#### 5.2.1 Health Score Template

A **Health Score Template** is the configuration object that defines which components are active, their weights, and which signal adapters feed them. Multiple templates can coexist (e.g., one per product line, one per deal size tier).

**Default Four Components (count, weights, and labels all configurable):**

| Component                       | Default Weight | Signal Type                                                | Example Adapters                                                                                                       |
| ------------------------------- | -------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Conversation Intelligence Score | 40%            | Conversation analytics platform                            | Gong, Zoom Revenue Accelerator, Dialpad, Chorus, or any adapter implementing the `ConversationSignalAdapter` interface |
| Relationship Score              | 25%            | Relationship intelligence / email metadata                 | Momentum, Teams Graph, Gmail metadata, or any adapter implementing the `RelationshipSignalAdapter` interface           |
| Activity Recency                | 20%            | All connected sources (mutual activity — both parties)     | Derived from any connected adapter that provides activity timestamps                                                   |
| Engagement Depth                | 15%            | All connected sources (stakeholder count, multi-threading) | Derived from any connected adapter that provides contact/stakeholder data                                              |

Admins can add, remove, rename, or reweight components. The only constraint is that active component weights must sum to 100%.

#### 5.2.2 Adjustment Rules Configuration

Adjustment rules are flat point modifiers applied after the weighted component sum. The platform ships with a default rule set (below); admins can add, remove, modify, or disable any rule.

| Signal (Default Label)                   | Default Adjustment | Default Trigger Condition                     | Configurable?                                   |
| ---------------------------------------- | ------------------ | --------------------------------------------- | ----------------------------------------------- |
| Competitor mentioned                     | −15                | `competitor_mentioned = TRUE` in last 30 days | Label, points, lookback window, enable/disable  |
| Key decision maker gone dark             | −20                | DM last response > 21 days                    | Label, points, days threshold, DM role tag      |
| Multiple no-shows                        | −10                | Meeting no-shows ≥ 2 in last 30 days          | Label, points, count threshold, lookback window |
| Next step confirmed                      | +10                | Next step confirmed in last interaction       | Label, points, recency window                   |
| Key decision maker on recent interaction | +8                 | DM participated in last 14 days               | Label, points, days threshold, DM role tag      |
| Multi-threaded (4+ contacts)             | +5                 | `stakeholder_count ≥ 4`                       | Label, points, count threshold                  |
| Champion re-engaged                      | +7                 | Champion responded after being dark ≥ 14 days | Label, points, dark days threshold              |

Custom adjustment rules can reference any boolean or numeric signal field from any connected adapter.

### 5.3 Signal Adapter Architecture

Each external signal source connects via a **Signal Adapter** — a standardized interface that normalizes vendor-specific data into the platform's canonical signal schema.

```
SignalAdapter {
  getHealthSignal(recordId)       → normalized 0–100 score
  getRelationshipSignals(recordId) → { dm_last_contact, champion_strength, stakeholder_count }
  getActivitySignals(recordId)     → { last_mutual_activity_date, interaction_count }
  getEngagementSignals(recordId)   → { call_count, meeting_count, response_rate }
  getAdjustmentSignals(recordId)   → { competitor_mentioned, next_step_confirmed, ... }
  getSyncStatus()                  → { last_sync, record_count, errors }
}
```

**Adapter normalization examples:**

| Adapter                  | Raw Signal                                  | Normalization to 0–100                                               |
| ------------------------ | ------------------------------------------- | -------------------------------------------------------------------- |
| Gong                     | `gong_risk_score` (0–100, higher = riskier) | `100 − gong_risk_score` (inverted)                                   |
| Zoom Revenue Accelerator | `conversation_health` (0–100)               | Direct mapping                                                       |
| Dialpad                  | `call_score` (0–100)                        | Direct mapping                                                       |
| Momentum                 | `relationship_score` (0–100)                | Direct mapping                                                       |
| Email Metadata (generic) | `avg_response_time_hours`                   | Decay curve: <2h → 90, 2–8h → 75, 8–24h → 55, 24–48h → 35, >48h → 15 |
| Custom / Proprietary     | Any numeric field                           | Admin-configured linear or step mapping                              |

**Adapter priority:** When multiple adapters provide the same signal type (e.g., two conversation intelligence tools), the admin configures a priority order per signal type. The highest-priority connected adapter is used; others serve as fallback.

### 5.3.1 Default Component Score Formulas

These formulas apply when the platform's built-in adapters are used. Orgs with custom adapters can override any formula.

**Conversation Intelligence Score:**

```
= SignalAdapter.getHealthSignal(recordId)   // normalized 0–100 by adapter
```

**Relationship Score:**

```
= (DM_engagement × 0.40) + (Champion_relationship × 0.35) + (Stakeholder_spread × 0.25)

DM_engagement:      days since last DM response:
                    ≤7 → 100 | 7–14 → 75 | 14–21 → 45 | >21 → 15 | never → 0
Champion_rel:       adapter relationship score (direct) OR email_response_time fallback:
                    <2h → 90 | 2–8h → 75 | 8–24h → 55 | 24–48h → 35 | >48h → 15
Stakeholder_spread: unique contacts engaged:
                    ≥5 → 100 | 4 → 80 | 3 → 60 | 2 → 40 | 1 → 20 | 0 → 0
```

Sub-weights (0.40 / 0.35 / 0.25) are configurable per Health Score Template.

**Activity Recency** (mutual activity only — requires both parties):

```
days_since_last_mutual_activity:
    0–3 → 100 | 4–7 → 85 | 8–14 → 65 | 15–21 → 45 | 22–30 → 25 | >30 → 10 | none → 0
```

Day thresholds and score bands are configurable per template.

**Engagement Depth:**

```
= (interaction_count_score × 0.30) + (meeting_count_score × 0.30) + (response_rate_score × 0.40)

interaction_count_score: ≥5 → 100 | 3–4 → 80 | 2 → 60 | 1 → 40 | 0 → 0
meeting_count_score:     ≥4 → 100 | 3 → 80 | 2 → 60 | 1 → 40 | 0 → 0
response_rate_score:     ≥80% → 100 | 60–79% → 75 | 40–59% → 50 | 20–39% → 30 | <20% → 10
```

Sub-weights and thresholds are configurable per template.

### 5.4 Missing Signal Redistribution

When a signal adapter is not connected (or returns no data for a record), its component weight is **not replaced with a neutral value** — it is redistributed proportionally to remaining connected components. The score card explicitly states which components are estimated vs. live, and by how much the weights shifted.

Example: If no conversation intelligence adapter is connected (Conversation Intelligence Score = 40% weight absent):

- Relationship Score: 25% → 25/60 × 100 = 41.7%
- Activity Recency: 20% → 20/60 × 100 = 33.3%
- Engagement Depth: 15% → 15/60 × 100 = 25.0%
- Score card shows: _"Conversation Intelligence Score not available — weights redistributed. Connect an adapter to activate."_

### 5.5 Score Card UI (Breakdown Panel)

Each pipeline record's health badge is clickable and expands a panel showing:

```
Record Health Score: 67 / 100
Close Probability:   71%  [AI — see Model]
Manager Category:    {configured category label}

Components:
  Conv. Intelligence  52/100   ({adapter name})  × 40%  =  20.8 pts
  Relationship Score  78/100   ({adapter name})  × 25%  =  19.5 pts
  Activity Recency    65/100   (Last 8 days)     × 20%  =  13.0 pts
  Engagement Depth    60/100   (3 contacts)      × 15%  =   9.0 pts
                                              Subtotal  =  62.3 pts

Adjustments:
  + Next step confirmed                                 +  10.0 pts
  - Competitor mentioned (last 14 days)                 - 15.0 pts
                                               Adjusted =  57.3 pts

                                               Clamped  =  57  → 67*

* Score smoothed by configurable rolling average (default: 7-day) to prevent single-event spikes.

Signal Freshness:
  {Adapter 1}:  Updated 2h ago   ✓
  {Adapter 2}:  Updated 6h ago   ✓
  CRM:          Updated 1d ago   ✓
```

Component names, adapter labels, and freshness thresholds are all derived from the Health Score Template and connected adapter configuration.

### 5.6 Conflict Alert in Forecasting UI

When a manager selects a high-confidence forecast category but the health score or AI close probability indicates high risk:

> **Signal Conflict:** This record is scored 34 (At Risk) and AI close probability is 28%. Manager has categorized as {high-confidence category}. Consider moving to {lower-confidence category}.

Category labels are derived from the Forecast Template's configured categories (see §3.2.3). Alert thresholds (score < X, probability < Y) are configurable per template. Alert is dismissible per record per period. Dismissal reason is logged.

### 5.7 Score Change Audit Trail

Every score change is logged in the **Score Change History** record:

- Previous score, new score, delta
- Which component(s) changed and by how much
- Signal adapter that triggered the change
- Timestamp

Score history chart available in the score card panel (configurable lookback window, default: 30 days).

### 5.8 Weight Configuration

Weights are configurable at four levels:

| Level               | Scope                                     | Who Can Edit            |
| ------------------- | ----------------------------------------- | ----------------------- |
| Platform Default    | All orgs                                  | Platform admin          |
| Org Default         | All records in org                        | Org admin / Sales Ops   |
| Role Profile        | All records for participants in that role | Sales Ops               |
| Individual Override | Specific participant's records            | Manager (with approval) |

Weight profiles are stored as **Health Score Profile** configuration records. Changes take effect within 1 sync cycle (not retroactive to history).

### 5.9 Signal Adapters & Sync

The platform ships with built-in adapters for common signal sources. Orgs can also build custom adapters using the `SignalAdapter` interface (see §5.3).

**Built-in Adapters:**

| Adapter                               | Signal Category           | Signals Provided                                                                             | Sync Method                             |
| ------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------- |
| Gong                                  | Conversation Intelligence | Risk score, engagement, call sentiment, DM on call, competitor mentions, next step confirmed | Webhook (real-time) + daily batch       |
| Momentum                              | Relationship Intelligence | Relationship strength, email response time, stakeholder map, deal velocity                   | Daily batch + on-demand                 |
| Zoom Revenue Accelerator              | Conversation Intelligence | Conversation health score, engagement score                                                  | Daily batch                             |
| Dialpad                               | Conversation Intelligence | Call scores, conversation data                                                               | Daily batch                             |
| CRM (Salesforce / HubSpot / Dynamics) | Pipeline & Activity       | Stage, activity log, close date, owner                                                       | Event-driven (trigger on record update) |
| Email Metadata (Gmail / Outlook)      | Relationship & Activity   | Response times, thread counts, contact frequency                                             | Daily batch (with consent model)        |
| Custom HTTP Adapter                   | Any                       | Admin-defined field mapping from any REST API                                                | Configurable schedule                   |

**Adding a new adapter:** Implement the `SignalAdapter` interface, register in the Signal Adapter Registry, and map output fields to the platform's canonical signal schema. No code changes to the scoring engine required.

### 5.10 Signal Freshness Policy

Without a consistent freshness model, the platform will produce confusing inconsistencies: health score says "fresh," behavioral flag says "stale," cockpit says "updated recently," and support tickets say "why doesn't this match Gong?"

#### 5.10.1 Signal State Enum

Every signal record carries a freshness state, computed from the adapter's last sync time:

| State       | Definition                                                      | Age Threshold (configurable per adapter) | Default                       |
| ----------- | --------------------------------------------------------------- | ---------------------------------------- | ----------------------------- |
| **LIVE**    | Data received within real-time window                           | ≤ sync_interval × 1.5                    | ≤ 15 min for webhook adapters |
| **RECENT**  | Data received within acceptable freshness window                | ≤ freshness_sla                          | ≤ 6 hours                     |
| **STALE**   | Data older than freshness SLA but not yet expired               | > freshness_sla AND ≤ hard_expire        | > 6 hours, ≤ 48 hours         |
| **EXPIRED** | Data too old to be trusted for scoring                          | > hard_expire                            | > 48 hours                    |
| **MISSING** | Adapter registered but has never delivered data for this record | No data exists                           | —                             |

#### 5.10.2 Default Adapter Freshness Configuration

| Adapter        | Sync Method           | Expected Cadence | Freshness SLA | Hard Expire |
| -------------- | --------------------- | ---------------- | ------------- | ----------- |
| Gong           | Webhook + daily batch | Real-time + 24h  | 6 hours       | 48 hours    |
| Momentum       | Daily batch           | 24 hours         | 36 hours      | 72 hours    |
| Zoom RA        | Daily batch           | 24 hours         | 36 hours      | 72 hours    |
| Dialpad        | Daily batch           | 24 hours         | 36 hours      | 72 hours    |
| CRM            | Event-driven          | Real-time        | 2 hours       | 24 hours    |
| Email Metadata | Daily batch           | 24 hours         | 36 hours      | 72 hours    |

#### 5.10.3 Freshness State Usage Across Platform

| Context                               | LIVE / RECENT                          | STALE                                                                  | EXPIRED                                                               | MISSING                                         |
| ------------------------------------- | -------------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------- | ----------------------------------------------- |
| **Health score calculation**          | Full weight applied                    | Full weight applied + staleness badge on score card                    | Component excluded, weight redistributed (same as MISSING)            | Weight redistributed (§5.4)                     |
| **Score card display**                | Green checkmark + "Updated {time} ago" | Yellow warning + "Last updated {time} — may be stale"                  | Red warning + "Data expired — not included in score"                  | Grey + "Not connected"                          |
| **Governance rule eligibility**       | Rules evaluate normally                | Rules evaluate normally + staleness context logged in governance event | Rules that depend on this signal skip with "insufficient data" status | Rules that depend on this signal skip           |
| **Behavior intelligence eligibility** | Flags evaluate normally                | Flags evaluate with reduced confidence (Medium → Low)                  | Flags that depend on this signal are suppressed                       | Flags that depend on this signal are suppressed |
| **Cockpit display**                   | No indicator                           | Subtle amber dot on signal trail                                       | Red dot + "Expired" label                                             | "No data"                                       |

---

## 6. Module 4 — Behavior Intelligence

### 6.1 Core Capability

Behavior Intelligence sits above the other three modules. It uses data that exists only because all three modules share the same platform — and answers questions that no single-module vendor can approach. All detection logic references configurable template fields, configurable categories, and configurable plan parameters — no metric name, category label, period type, or role name is hardcoded.

**Industry examples of cross-module intelligence:**

| Industry           | Behavior Detected                                                             | Data Required                                                                       |
| ------------------ | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Enterprise SaaS    | Rep sandbagging TCV to protect quarterly accelerator                          | Forecast override history + attainment vs. rate tier threshold + deal health        |
| Insurance          | Agent over-committing premium volume while underwriting signals are weak      | Forecast submissions + health scores on applications + incentive plan thresholds    |
| Real Estate        | Broker inflating listing pipeline while showing activity has stalled          | Forecast categories + activity recency signals + listing-based incentive attainment |
| Manufacturing      | Sales engineer clustering bid submissions at period end to trigger bonus tier | Transaction close dates + attainment distribution + rate tier boundaries            |
| Financial Services | Advisor over-forecasting AUM commitments while client engagement declining    | Override history + relationship signals + fee-based plan attainment                 |

### 6.2 Manager Accuracy Calibration

**What it is:** A historical score per manager measuring how accurately their submitted forecast reflects what actually closes.

**How it works:**

1. For each closed pipeline record, compare the manager's last submitted override value (for the template's primary metric) to the actual close value from the source system
2. Per manager, compute:
   - Hit Rate by Category: "When Manager A submits as {high-confidence category}, it closes at 62%"
   - Average Value Accuracy: "Manager A over-commits by 18% on primary metric"
   - Period Slip Rate: "Manager A's records slip an average of 1.4 periods from submission"
   - Category Accuracy: confusion matrix across configured forecast categories → configured terminal outcomes (Won / Lost / Slipped)

All category labels in the confusion matrix are derived from the Forecast Template's configured categories (see §3.2.3). "Won", "Lost", and "Slipped" are configurable terminal outcome labels.

**Where it appears:**

- Accuracy badge on each manager's pipeline rows in the next-level review view (e.g., "Manager: 64% accurate")
- Reviewer summary panel: ranked accuracy table across all managers in territory/scope
- Suggested adjustment: "Based on this manager's history, AI recommends adjusting submitted total from $2.1M to $1.7M"
- Trend line: is the manager's accuracy improving or degrading over the last N periods? (lookback window configurable, default: 4 periods)

**Accuracy refresh:** Recalculated weekly (batch) and immediately when a pipeline record reaches a terminal outcome.

### 6.3 Sandbagging Detection

**What it is:** Identifies patterns suggesting a participant is deliberately under-committing to protect incentive rate tier thresholds.

**Signals (all thresholds configurable):**

- Participant is at 88–99% of a rate tier attainment threshold (percentage range configurable)
- Participant has pipeline records in non-committed forecast categories that deal health signals indicate are high-health (score ≥ 70, threshold configurable)
- Participant's forecast submission for the current period is materially lower than their trailing N-period average close rate would predict (N configurable, default: 4)
- Participant has a rate tier threshold within 15% of current attainment (proximity % configurable)

**Output:**

- Flag in reviewer view: "Potential sandbagging signal: [Participant name] — 3 {non-committed category} records with health score ≥ 70 while at 94% quota attainment and $180K from {rate tier name} threshold"
- Flagged for reviewer, not surfaced to the participant
- Logging: flag dismissals by reviewers are tracked and form part of the reviewer's own accuracy profile

### 6.4 Optimism Bias Detection

**Counterpart to sandbagging:** Detects when a participant is over-committing while signals suggest pipeline records are weak.

**Signals (all thresholds configurable):**

- Participant has ≥ 3 records in a high-confidence forecast category with deal health score < 40
- Participant's historical high-confidence category → actual win rate is below 40%
- Multiple records in high-confidence category with no activity in last 14 days

Category references are resolved from the Forecast Template's configured categories. "High-confidence category" = any category where `Counts Toward Target = True` (see §3.2.3).

**Output:**

- Warning in reviewer view: "Optimism alert: [Participant name] — 4 records in {high-confidence category} with average health score 28"
- Coaching nudge generated (see §6.7)

### 6.5 Incentive Plan Behavior Model

**What it does:** Models how the current incentive plan structure is shaping observable behaviors — not just whether participants hit quota.

**Analyses:**

- **Threshold Clustering:** Histogram of attainment distribution across all participants. Unnatural spikes at configured rate tier boundaries indicate gaming.
- **Transaction Timing Concentration:** Are disproportionate transactions closing in the last portion of a period? (Pull-forward gaming). Period type derived from plan configuration.
- **Discount Correlation:** Are participants with margin-based commissionable value formulas giving fewer discounts? (Validates plan design)
- **Role Contribution Analysis:** For multi-role plans, is each configured participant role actually contributing to transactions where they earn incentive?

**Where it appears:**

- Admin / Finance dashboard: periodic plan behavior report (period cadence matches plan period)
- Plan Design Simulator input: feeds the "what-if" plan simulator

### 6.6 Anomaly Detection & Alerts

Proactively flagged in the Forecasting UI and via notifications:

| Anomaly Type         | Detection Logic                                                             | Alert                                                                    |
| -------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Period Slip Loop     | Record has moved close date 3+ consecutive periods                          | "This record has slipped 3 times. Consider {lower-confidence category}." |
| Primary Metric Cliff | Record's primary metric dropped > 40% in a single period change             | "Record value dropped {amount} in one period."                           |
| Category Regression  | Record moved backward through configured category sequence across periods   | "This record is moving backward."                                        |
| Staleness            | No forecast update in 2+ periods with record still in pipeline              | "No updates for {N} days. Is this record still active?"                  |
| Coverage Gap         | Territory/scope has < 2× pipeline coverage for period target                | "{Period} pipeline coverage is 1.4×. Target is 2×."                      |
| Threshold Approach   | Participant within 10% of rate tier threshold with 3+ non-committed records | Sandbagging detection (see §6.3)                                         |

All category names, period labels, and metric names in alerts are derived from the Forecast Template and Incentive Plan configurations.

### 6.7 Coaching Nudges

Automated record-specific guidance generated and delivered to managers (not participants directly):

**Examples (labels resolve from configured templates):**

- _"{Record name} ({high-confidence category}, {period label}, {value}) — No legal docs signed. 82% of {category}-stage records without legal docs slip to next period."_
- _"{Record name} ({mid-confidence category}, {period label}, {value}) — Last mutual activity was 38 days ago. Records with >30 days of inactivity close at 23% from this stage."_
- _"[Participant name] {period label} summary — Submitted {amount} for {period}, but their historical close rate for this period is 71%. Historical close: {amount}."_

**Generation:** Scheduled nightly agent; pulls record context from CRM adapter + forecast override history + signal adapter data. Delivers via in-app notification panel and optionally Slack/Teams/email (configurable per org).

### 6.8 Payout Forecasting

**What it does:** Projects each participant's expected earnings for the current period and full fiscal year, based on open pipeline × close probability × incentive plan rates.

**Inputs:** Open pipeline records × AI close probability × participant's active incentive plan rates × current attainment level (determines which rate tier applies). All inputs are resolved from the configured Forecast Template (pipeline records, metrics) and Incentive Plan (rate structure, attainment tiers).

**Output (in Participant portal and Admin dashboard):**

- Expected earnings: Current period | Full fiscal year
- Attainment milestone progress: "You are {amount} from the {rate tier name} threshold → {amount} additional earnings"
- Next threshold alert: "If you close these {N} records, you cross the {rate tier name} threshold and earn an additional {amount} on all future transactions this fiscal year"

All labels, tier names, and period references are derived from the incentive plan and forecast template configurations.

### 6.9 Plan Design Simulator

**What it does:** Allows Finance/HR to model a proposed incentive plan change and see its projected impact on participant behavior and total incentive expense before rolling it out.

**Inputs (configurable):**

- New base rate, new rate tier thresholds and rates
- Apply to: specific participant cohort or all participants
- Simulated pipeline: use current open pipeline or a scenario pipeline

**Outputs:**

- Per-participant: projected earnings under new plan vs. current plan
- Total incentive expense: current vs. proposed (delta and %)
- Behavioral impact estimate: will the new threshold clustering create sandbagging incentives?
- Attainment distribution projection: histogram of where participants would land under new plan

### 6.10 Structured Behavior Explanation Engine

**What it is:** The platform's second core differentiator. Moves past generic "AI says this is risky" to emit **structured, human-auditable explanations** that link compensation mechanics to observable forecast behavior. No competitor attempts this.

**Why it matters:** Competitors (Gong, Clari) show signal-based risk scores with per-signal positive/negative indicators — but these are not comp-plan-aware. A deal scored "at risk" because of low engagement is very different from a deal scored "at risk" because the rep's accelerator threshold incentivizes pushing it to next period. Only this platform can distinguish the two.

**How it works:** When a Behavioral Flag (sandbagging, optimism bias, threshold approach, timing concentration) is raised, the Explanation Engine generates a structured output:

```
BEHAVIOR EXPLANATION
═══════════════════

Participant:    J. Smith (Account Executive)
Pipeline Record: Acme Corp — $420,000
Period:         Q2 FY2027
Flag Type:      Potential Sandbagging

1. OBSERVED FORECAST ACTION
   → Participant moved Acme Corp from {high-confidence category} to {mid-confidence category}
     on April 2, despite deal health score increasing from 68 → 82 in the last 7 days.

2. COMPENSATION CONTEXT
   → Current attainment: $4,158,000 (94.5% of $4,400,000 quota)
   → Active plan: "Enterprise AE FY27" — Accelerated rate structure
   → Current rate tier: Tier 1 (8% on all transactions)
   → Next tier: Tier 2 at 100% attainment ($4,400,000) — rate jumps to 12%
   → Distance to threshold: $242,000
   → If Acme Corp ($420K) closes this period: attainment reaches 104.1%
     → ALL transactions in period retroactively paid at 12% (not just incremental)
     → Payout delta: +$87,600 (retroactive uplift on $4.58M at +4%)

3. DEAL HEALTH SIGNALS (contradict the category downgrade)
   → Health score: 82 (🟢) — up from 68 seven days ago
   → Decision maker on call April 1 ✓
   → Next step confirmed (contract review scheduled April 8) ✓
   → Response rate: 85% (above 80% threshold)
   → No negative signals in last 14 days

4. HISTORICAL PATTERN
   → J. Smith has downgraded 3 records from {high-confidence} to {mid-confidence}
     in the last 2 weeks of a period when within 15% of a tier threshold
     in 2 of the last 4 periods.
   → In both prior instances, the downgraded records closed within 14 days
     of the next period opening.

5. RECOMMENDED GOVERNANCE ACTION
   → Escalate to reviewer for category validation (Rule CG-2)
   → Suggested question: "Acme health score is 82 with DM engagement confirmed.
     What changed to justify moving from {high-confidence} to {mid-confidence}?"
   → If reviewer overrides back to {high-confidence}: log override with
     compensation context attached.
```

#### 6.10.1 Explanation Components

| Component                     | Data Source                                           | Always Present?            |
| ----------------------------- | ----------------------------------------------------- | -------------------------- |
| Observed Forecast Action      | Forecast Override change log                          | Yes                        |
| Compensation Context          | Incentive Plan + Incentive Impact Calculator (§7.3.4) | Yes                        |
| Deal Health Signals           | Pipeline Signal from connected adapters               | When health data available |
| Historical Pattern            | Behavioral Flag history for this participant          | When prior flags exist     |
| Recommended Governance Action | Governance Trigger Engine (§7.3.1)                    | Yes                        |

#### 6.10.2 Explanation Delivery

- **In-app:** Full structured explanation displayed in the Manager Decision Cockpit (§11.5) governance queue when the reviewer clicks a flag
- **Notification:** Summary version (components 1 + 2 + 5 only) delivered via Slack/Teams/email
- **AI-enhanced:** When LLM is enabled, the structured data is passed to Claude API to generate a natural-language narrative version. The structured version is always the source of truth; the narrative is supplementary.
- **Audit:** Full explanation stored in the Behavioral Flag record for compliance and historical analysis

#### 6.10.3 Explanation for Non-Flag Scenarios

The Explanation Engine also generates positive explanations when no flag is raised — these feed the coaching nudge system:

- "J. Smith moved Acme to {high-confidence} while 6% from tier threshold. This is consistent: health score 82, DM engaged, next step confirmed. No governance action required."
- "R. Patel's forecast submission is 12% above trailing average, but pipeline health scores support it (avg health: 74). Confidence: aligned."

These "green path" explanations build trust in the system — it's not just flagging problems, it's confirming when behavior is well-aligned with signals.

### 6.11 Behavior Intelligence Confidence & Interpretation Policy

Behavior Intelligence is the platform's biggest strategic opportunity and its biggest trust risk. If poorly framed, it becomes "AI that infers human motives from sales behavior" — politically radioactive and hard to defend. This policy ensures the module stays enterprise-safe.

**Core principle:** The system flags **patterns**, not **intent**. Explanations are **hypotheses**, not **verdicts**.

#### 6.11.1 Language Rules

| Never Say (Accusatory)              | Always Say (Observable)                                                                                   |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------- |
| "Rep is sandbagging"                | "Review-worthy anomaly: accelerator threshold proximity + unusual category movement + historical pattern" |
| "Manager is being dishonest"        | "Manager's submitted values have diverged from actuals by >25% for 3 consecutive periods"                 |
| "This rep is gaming the system"     | "Threshold clustering detected: 4 of 6 periods show attainment landing within 2% of tier boundary"        |
| "Rep is deliberately pushing deals" | "Close date movement correlates with period-end proximity and tier threshold distance"                    |

#### 6.11.2 Interpretation Safeguards

1. **Every behavioral flag must show observable evidence.** No flag can be raised without at least 2 corroborating data points (e.g., threshold proximity alone is never sufficient — it must be combined with category movement, health score contradiction, or historical pattern).
2. **Flags are hypotheses, not conclusions.** The UI labels every flag as: "Review-worthy pattern" or "Signal for review." Never "Confirmed sandbagging" or "Gaming detected."
3. **Users can dismiss, resolve, or override every flag.** Dismissal requires a note. Dismissal history is tracked as part of the reviewer's own accuracy profile — but dismissal is always permitted.
4. **No behavioral flag can auto-penalize compensation.** A sandbagging flag cannot trigger a commission hold, reduce a payout, or adjust a rate tier. Only explicit human action (admin creates adjustment record) can affect compensation.
5. **No behavioral flag can auto-freeze a forecast.** Flags inform the governance queue but cannot independently block submission or freeze actions. Only deterministic governance rules (§7.3, §1.6.2) can enforce.
6. **Confidence is explicitly stated.** Every flag shows signal strength: High (3+ corroborating signals), Medium (2 signals), Low (1 signal + pattern match). Low-confidence flags are shown in a separate "Low Confidence" section of the governance queue, not mixed with high-confidence flags.
7. **Behavioral patterns are computed per participant, never compared across participants in a way that creates a ranking.** No "most likely to sandbag" leaderboard. Patterns are evaluated individually against the participant's own history and plan parameters.

---

## 7. Cross-Module Integration — The Data Flywheel

### 7.1 How Modules Share Data

```
DEAL HEALTH (Module 3)
  → Score badge in Forecasting pipeline record row
  → Sandbagging detection signal in Behavior Intelligence
  → Post-close signal monitoring for clawback risk in Sales Incentives

FORECASTING (Module 1)
  → Manager override history feeds Manager Accuracy Calibration
  → Submitted vs. actual delta feeds Sandbagging Detection
  → Coverage gap feeds Anomaly Detection
  → Pipeline records feed Payout Forecasting

SALES INCENTIVES (Module 2)
  → Current attainment level determines which rate tier applies to Payout Forecast
  → Incentive thresholds feed Sandbagging Detection (is participant near a threshold?)
  → Plan trigger type (booking vs. collection vs. milestone) determines when Deal Health's post-close monitoring matters
  → Draw balance feeds Participant portal

BEHAVIOR INTELLIGENCE (Module 4)
  → Manager Accuracy displayed in next-level review view (Module 1)
  → Sandbagging flag in Forecasting pipeline record row (Module 1)
  → Payout Forecast in Participant portal (Module 2)
  → Coaching nudges delivered via notification system
```

### 7.2 Cross-Module Business Rules

| Rule                                       | Modules                      | Behavior                                                                                                                        |
| ------------------------------------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Deal Health → Forecast Conflict Alert      | Health + Forecasting         | When health score < 40 and category = Forecast, show conflict warning                                                           |
| Commission Threshold → Sandbagging Monitor | Incentives + Behavior Intel  | When rep attainment > 88%, increase sandbagging detection sensitivity                                                           |
| Rev Rec → Health Monitoring                | Incentives + Health          | Revenue-based commission plans trigger 90-day post-close health monitoring to detect clawback risk                              |
| Manager Accuracy → Suggested Adjustment    | Forecasting + Behavior Intel | Director View shows AI-suggested adjustment based on manager's historical accuracy vs. their submitted total                    |
| Payout Forecast → Rep Behavior             | Incentives + Behavior Intel  | When close probability × pipeline shows rep will cross accelerator threshold in N days, surface next-deal "worth" in rep portal |
| Coverage Gap → Commission Hold             | Forecasting + Incentives     | When territory pipeline coverage drops below 1.5×, trigger alert in admin and commission hold review                            |

### 7.3 Comp-Aware Governance Rules

This is the platform's primary competitive differentiator. Unlike any competitor that merely "combines commission data with forecast data," these rules **enforce governance actions** — approvals, justifications, escalations, and blocks — triggered by compensation economics. They answer: _"Is this forecast decision influenced by how the participant is compensated?"_

#### 7.3.1 Governance Trigger Engine

The platform monitors every forecast action (category change, value override, close date change, submission) and evaluates it against the participant's active incentive plan in real time. When a governance rule fires, it produces a **Governance Event** containing: the trigger, the compensation context, the required action, and the audit trail.

#### 7.3.2 Default Governance Rules (all configurable; admins can add/remove/modify)

| Rule ID | Trigger                                                                     | Compensation Context                                                                                                                                                     | Governance Action                                                                                                                                                                             | Severity      |
| ------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| CG-1    | Participant moves record to high-confidence category                        | Estimated payout increase > configurable % threshold (default: 25%)                                                                                                      | **Require justification note** before submission is accepted. Note and payout delta logged in audit trail.                                                                                    | Medium        |
| CG-2    | Participant moves record to high-confidence category                        | Participant is within configurable % (default: 15%) of a rate tier threshold                                                                                             | **Escalate to reviewer**: flag in reviewer's queue with message: "Participant is {amount} from {tier name} threshold. This category change would push attainment to {%}. Review recommended." | High          |
| CG-3    | Participant changes close date to current period                            | Record was in a future period AND moving it forward would cross a rate tier threshold this period                                                                        | **Require reviewer approval** before close date change is saved. Approval/denial logged.                                                                                                      | High          |
| CG-4    | Participant pushes record close date to next period                         | Participant is above current-period quota AND moving it forward would increase next-period attainment toward a higher tier                                               | **Flag as potential sandbagging** in reviewer view. Cross-reference with deal health score: if health ≥ 70, escalate severity.                                                                | Medium        |
| CG-5    | Reviewer submits forecast for scope                                         | Total submitted forecast value × rate tier rates produces a payout that exceeds budget threshold                                                                         | **Warn reviewer**: "Submitted forecast implies {amount} in incentive expense for this scope — {%} above budget. Confirm or adjust."                                                           | Low           |
| CG-6    | Multiple participants move records to high-confidence in same period window | Team-level pattern: ≥ 3 participants on the same plan make high-confidence moves within configurable window (default: 48 hours) AND all are near the same tier threshold | **Alert Sales Ops**: "Coordinated threshold approach detected across {N} participants on {plan name}. Review for plan design issue."                                                          | High          |
| CG-7    | Participant creates/edits forecast override                                 | Override value differs from previous-level value by > configurable % (default: 30%) AND participant's incentive on the delta exceeds configurable amount                 | **Attach incentive impact badge** to the override record showing the payout difference. Visible to all reviewers in the hierarchy.                                                            | Informational |

#### 7.3.3 Governance Action Types

| Action Type                       | Behavior                                                                                                                                | Blocking?                                                 |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **Require justification**         | Participant must enter a free-text note explaining the action. Note is stored in audit trail and visible to all reviewers.              | Soft block — action saved but flagged until note provided |
| **Require reviewer approval**     | Action is held in pending state. Reviewer receives notification. Reviewer approves (with optional note) or denies (with required note). | Hard block — action not committed until approved          |
| **Escalate to reviewer**          | Action proceeds but is flagged in reviewer's governance queue with full compensation context.                                           | Non-blocking — informational escalation                   |
| **Alert Sales Ops**               | Action proceeds. Separate alert sent to Sales Ops / plan administrators for systemic review.                                            | Non-blocking — systemic alert                             |
| **Warn with budget impact**       | Action proceeds after confirmation dialog showing budget/expense impact. Confirmation logged.                                           | Soft block — requires explicit acknowledgment             |
| **Attach incentive impact badge** | Visual indicator showing payout delta. No action required.                                                                              | Non-blocking — transparency layer                         |

#### 7.3.4 Incentive Impact Calculator (Real-Time)

Every governance rule depends on a real-time incentive impact calculation:

```
For a given participant + pipeline record + proposed forecast action:

1. Current attainment = sum of closed transactions in current period
2. Projected attainment = current attainment + value of all high-confidence records
3. Proposed attainment = projected attainment ± impact of the proposed action
4. Current rate tier = tier matching current attainment (from Incentive Plan)
5. Proposed rate tier = tier matching proposed attainment
6. Payout delta = (proposed value × proposed rate) − (current value × current rate)
7. Threshold proximity = distance to next tier boundary as % of quota
```

This calculation runs in < 500ms and is available on every pipeline record row in the forecast view (see §3.3.2 Inline Incentive Estimator).

#### 7.3.5 Governance Audit Trail

Every governance event is logged in a **Governance Event** record:

- Trigger: which rule fired and why
- Participant, pipeline record, forecast period
- Compensation context: attainment at time, tier, threshold proximity, payout delta
- Action taken: justification text, approval/denial, acknowledgment
- Reviewer who acted (if applicable)
- Timestamp

Governance events are queryable by Sales Ops and visible in the Manager Decision Cockpit (§11.5). Aggregate governance metrics (triggers per plan, approval rate, override frequency by tier proximity) feed the Incentive Plan Behavior Model (§6.5).

#### 7.3.6 Governance Rule Runtime Semantics

This section defines the operational behavior that engineering must implement. Without these semantics locked, governance rules would be ambiguous at build time.

**Evaluation Order & Concurrency:**

1. Rules are evaluated **synchronously** in the Forecast Override before-save trigger (the override is a platform-owned object — safe per AD-1).
2. All active rules evaluate against every qualifying action. **One action can trigger multiple rules simultaneously.**
3. Rules evaluate in **severity order: High → Medium → Low → Informational.** Within the same severity, rules evaluate in rule ID order (CG-1 before CG-2, etc.).
4. Evaluation is **non-short-circuiting** — all rules evaluate even if an earlier rule has already triggered. This ensures the full governance picture is visible to the reviewer.

**Conflict Precedence (when multiple rules fire on the same action):**

| Conflict Type                                                                                             | Resolution                                                                                                                                                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Multiple rules fire, all non-blocking                                                                     | All events created. All badges/escalations/alerts delivered. No conflict.                                                                                                                                                                                                                                                                     |
| One blocking rule (Require Approval) + one or more non-blocking rules                                     | **Blocking rule wins.** Action is held pending. All non-blocking events are also created and visible in the governance queue alongside the blocking event. Reviewer sees the full picture.                                                                                                                                                    |
| Multiple blocking rules fire on the same action                                                           | **Highest-severity blocking rule governs the block.** All blocking events are created. Action is held pending. Reviewer must resolve the highest-severity event first; lower-severity blocking events are auto-resolved when the highest-severity event is approved. If the highest-severity event is denied, all blocking events are denied. |
| Advisory rule fires but data required for evaluation is unavailable (e.g., attainment not yet calculated) | **Rule is skipped with a logged reason.** Event record created with status "Skipped — insufficient data." Visible in audit trail but no action required.                                                                                                                                                                                      |

**Approval State Machine:**

```
                    ┌──────────┐
                    │ TRIGGERED │ (governance rule fires)
                    └─────┬────┘
                          │
              ┌───────────┴───────────┐
              │                       │
        Non-blocking             Blocking (CG-3)
              │                       │
              ▼                       ▼
        ┌──────────┐          ┌──────────────┐
        │ RECORDED │          │   PENDING    │ (action held)
        └──────────┘          └──────┬───────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
                    ▼                ▼                ▼
              ┌──────────┐   ┌──────────┐    ┌──────────────┐
              │ APPROVED │   │  DENIED  │    │   EXPIRED    │
              └──────────┘   └──────────┘    └──────────────┘
                    │                │                │
                    ▼                ▼                ▼
              Action committed  Action reverted   Action reverted
              with approval     to previous        to previous
              audit trail       value; denial      value; expiry
                                note required      reason logged
```

**Pending Approval Behavior:**

| Question                                                                    | Answer                                                                                                                                                                                                                                                                                                                                   |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| What state is the record in while pending?                                  | The Forecast Override is saved with a `Pending_Approval` flag = true. The proposed field changes are stored on the override record but are **excluded from rollups and submissions** until approved. The pipeline table shows the record with a "Pending" status badge.                                                                  |
| Can the participant edit the record while it's pending?                     | **No.** The record is locked for editing until the pending governance event is resolved. The participant sees: "This record has a pending governance review. Editing is blocked until resolved."                                                                                                                                         |
| Can the reviewer override a denial later?                                   | **Yes.** A denied governance event can be re-opened by a reviewer at the same level or above. Re-opening creates a new Governance Event linked to the original, with status "Re-opened." The approval process restarts.                                                                                                                  |
| Can approvals be delegated?                                                 | **Yes.** Reviewers can designate a delegate via a platform-managed delegation record. Delegates can approve/deny on behalf of the delegator. Delegation is time-bound (start date / end date) and logged.                                                                                                                                |
| What happens if approval is still pending when the forecast period freezes? | **Pending approvals are auto-expired on freeze.** Action reverts to previous value. Governance event status set to "Expired — period frozen." Rationale: freeze is the highest-authority governance action.                                                                                                                              |
| What happens if the CRM record changes while approval is pending?           | See §1.5.2 conflict resolution. The governance event is flagged as "stale — basis changed." The platform re-evaluates whether the rule still applies. If the CRM change makes the rule no longer applicable (e.g., deal amount dropped, threshold no longer in range), the pending event is auto-resolved as "Superseded by CRM change." |

**Timeout / Expiration:**

- Pending approvals have a configurable expiration window (default: 48 hours).
- If not acted on within the window, the action reverts to previous value and the event is marked "Expired — timeout."
- 24 hours before expiration, a reminder notification is sent to the reviewer.
- Expiration window is configurable per governance rule (some orgs may want CG-3 to have a 4-hour window while CG-2 has 72 hours).

**Audit Guarantees:**

1. Every governance evaluation produces a Governance Event record, even if no rule triggers (status: "Evaluated — no rules triggered"). This proves the engine ran.
2. Governance Event records are **immutable after creation.** Resolution fields (approval, denial, expiry, notes) are append-only — they cannot be deleted or overwritten.
3. If the governance engine fails to evaluate (code error, governor limit), the action is **blocked by default** and a system error Governance Event is created with status "Evaluation Failed — action blocked." This ensures governance cannot be silently bypassed.
4. All governance events include the full compensation context snapshot at the time of evaluation (attainment, tier, threshold, payout delta). This snapshot is frozen — even if attainment changes later, the historical context is preserved for audit.

### 7.4 Cross-Module Event Orchestration

When an upstream event occurs (CRM change, signal update, period close), multiple modules may need to react. Without an explicit orchestration table, teams will create "just call everything" logic leading to unnecessary recomputes, governor pain, hard-to-debug cascades, and ghost side effects.

#### 7.4.1 Event → Recomputation Matrix

| Upstream Event                                          | Recompute                                                                                                                                            | Skip (no recomputation needed)                                                                                          |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Pipeline record amount changed**                      | Incentive estimator (inline), governance rules (re-evaluate CG-1/CG-7), behavior flags (threshold proximity check)                                   | Signal ingestion, health score (amount doesn't affect signals), manager accuracy                                        |
| **Pipeline record close date moved**                    | Forecast divergence badge (§1.5.2), governance rules (CG-3/CG-4), behavior flags (sandbagging/pull-in check)                                         | Attainment snapshot (hasn't closed yet), incentive ledger, health score components (date doesn't affect signal recency) |
| **Pipeline record stage changed**                       | Health score (stage progression component), CRM signal adapter refresh                                                                               | Incentive estimator (stage alone doesn't change payout), governance rules (unless stage = Closed Won)                   |
| **Pipeline record closed (won)**                        | **Full chain:** Final incentive calculation → attainment snapshot → rate tier re-evaluation → manager accuracy scoring → health score terminal state | Forecast submission flow (deal is closed — no more forecasting), governance rules (deal resolved)                       |
| **Pipeline record closed (lost)**                       | Manager accuracy scoring, health score terminal state, behavioral flag resolution (any open flags on this record auto-resolved)                      | Incentive calculation (nothing earned), governance rules                                                                |
| **Pipeline record deleted in CRM**                      | Mark platform records as "Source Deleted" (§1.5.2), exclude from rollups                                                                             | No recomputation — preserve for audit                                                                                   |
| **Signal adapter data updated**                         | Health score (affected components), behavior explanation refresh (if flag active)                                                                    | Incentive calculation, forecast overrides, attainment snapshot                                                          |
| **Forecast override saved**                             | Governance rules (synchronous, §7.3.6), incentive estimator (client-side), forecast divergence check                                                 | Health score, signal ingestion, incentive ledger                                                                        |
| **Forecast override submitted**                         | Rollup recalculation for scope, manager accuracy (submitted value recorded), coaching nudge eligibility check                                        | Health score, incentive calculation (not a close event)                                                                 |
| **Forecast period frozen**                              | Auto-expire pending governance approvals (§7.3.6), lock all overrides in scope                                                                       | No recomputation — freeze is a state lock, not a data change                                                            |
| **Incentive plan changed** (new period, rate update)    | Incentive estimator (invalidate cached plan data), payout forecast refresh, behavior model (threshold positions shifted)                             | Historical incentive ledger (immutable), health scores, forecast overrides                                              |
| **Incentive calculation completed**                     | Attainment snapshot update, behavior flags (new threshold proximity), payout forecast refresh                                                        | Health score, forecast overrides, signal ingestion                                                                      |
| **Governance event resolved** (approved/denied/expired) | For CG-3 (hard block): release or revert pending override. For all: update cockpit governance queue, log resolution.                                 | No downstream recomputation — governance resolution is a terminal state                                                 |

#### 7.4.2 Orchestration Principles

1. **No broadcast recomputation.** Every event has an explicit list of affected modules. The platform event handler routes only to listed consumers.
2. **Synchronous only for governance.** Governance rule evaluation runs synchronously on platform-owned object saves (§7.3.6). All other cross-module reactions are asynchronous via Platform Events.
3. **Idempotent consumers.** Every event consumer must handle duplicate delivery gracefully. Platform Events can replay; consumers must produce the same result on re-delivery.
4. **Fan-out limit.** A single upstream event may trigger at most 3 downstream recomputations. If an event appears to need more, it's a signal that the event should be decomposed into sub-events.
5. **No cascading triggers.** A downstream recomputation may NOT publish new events that trigger further recomputations in the same chain. If module A's reaction to event X produces a state change that module B cares about, module B subscribes directly to event X — not to module A's output. This prevents infinite cascades.

---

## 8. Unified Data Model

> **Implementation note:** This section defines the **logical data model** — the entities, relationships, and fields the platform requires regardless of deployment target. In Phase 1 (Salesforce managed package), these map to Salesforce custom objects (e.g., Forecast Period → `Forecast__c`). In Phase 3 (full-stack SaaS), they map to PostgreSQL tables. The logical names below are implementation-agnostic; Salesforce-specific `__c` suffixes and custom metadata types are Phase 1 naming conventions only.

### 8.1 Core Entities

| Logical Entity                         | Module           | Purpose                                                                                              |
| -------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------- |
| **Forecast Period**                    | Forecasting      | Forecast batch/period record; mode (forecast vs. budget), status (open/submitted/frozen)             |
| **Forecast Override**                  | Forecasting      | Per-record override per hierarchy level; self-referential previous-level and previous-period lookups |
| **Forecast Participant**               | Forecasting      | Participant × Scope × Forecast assignment; hierarchy level, submission status                        |
| **Forecast Comment**                   | Forecasting      | Historical notes per pipeline record per forecast period                                             |
| **Incentive Plan**                     | Sales Incentives | Plan definition: rate structure, thresholds, targets, eligibility rules, flags                       |
| **Incentive Calculation**              | Sales Incentives | Calculated incentive per transaction × participant × plan × rate tier                                |
| **Draw Record**                        | Sales Incentives | Draw / Advance / Payback records per participant; beginning/ending balance                           |
| **Incentive Summary**                  | Sales Incentives | Parent-level incentive summary per participant per period                                            |
| **Payment Record**                     | Sales Incentives | Payment events per transaction × participant × quota category                                        |
| **Commissionable Percentage**          | Sales Incentives | Protected configuration: commissionable percentage entries per transaction category                  |
| **Additional Participant Eligibility** | Sales Incentives | Additional participants eligible for specific transaction types                                      |
| **Pipeline Signal**                    | Deal Health      | Canonical signal store: normalized signals from all connected adapters per pipeline record           |
| **Signal Change History**              | Deal Health      | Audit trail of score changes with component-level delta                                              |
| **Health Score Profile**               | Deal Health      | Configuration: weight profiles by org, role, or participant                                          |
| **Manager Accuracy**                   | Behavior Intel   | Per-manager historical accuracy stats; refreshed weekly                                              |
| **Incentive Dispute**                  | Sales Incentives | Dispute records linked to Incentive Calculation                                                      |
| **Payment Schedule**                   | Sales Incentives | Deferred/vesting payment installments                                                                |
| **Plan Simulation Scenario**           | Behavior Intel   | Saved plan simulation scenarios for Finance/HR                                                       |
| **Behavioral Flag**                    | Behavior Intel   | Sandbagging/optimism flags, dismissed_by, dismissed_reason                                           |

### 8.2 Additional Entities (Not Currently Built)

| Logical Entity                    | Module           | Key Fields                                                                                                       |
| --------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Territory / Scope**             | Sales Incentives | Scope name, region, parent scope, assigned participants                                                          |
| **Rate Tier**                     | Sales Incentives | Child of Incentive Plan; min_value, max_value, rate% (for tiered rate band plans)                                |
| **Team Pool**                     | Sales Incentives | Pool amount, distribution rule, linked participants, funding trigger                                             |
| **Forecast Template**             | Forecasting      | Configuration: hierarchy levels, metrics, categories, periods, context fields                                    |
| **Health Score Template**         | Deal Health      | Configuration: components, weights, adapter mappings, adjustment rules                                           |
| **Signal Adapter Registration**   | Deal Health      | Adapter name, type, endpoint, field mapping, sync schedule                                                       |
| **Governance Event**              | Cross-Module     | Trigger rule ID, participant, record, period, compensation context, action type, resolution, reviewer, timestamp |
| **Governance Rule Configuration** | Cross-Module     | Rule ID, trigger condition, compensation threshold, action type, severity, enabled flag                          |
| **Behavior Explanation**          | Behavior Intel   | Linked to Behavioral Flag; structured components: action, comp context, signals, history, recommendation         |

### 8.3 Key Entity Relationships

```
Pipeline Record (from CRM / source system)
  ├── Forecast Override        (N — one per hierarchy level per forecast period)
  ├── Incentive Calculation    (N — one per participant × rate tier per processing run)
  ├── Draw Record              (N — draws/advances linked to transaction)
  ├── Payment Record           (N — payment events per participant)
  └── Pipeline Signal          (1 — current canonical signals from all adapters)
       └── Signal Change History (N — score change audit)

Participant (from identity provider / CRM user)
  ├── Incentive Plan           (N — one per fiscal year per plan type)
  ├── Forecast Participant     (N — one per scope per forecast period)
  ├── Manager Accuracy         (1 — rolling accuracy stats)
  └── Draw Balance             (derived field — maintained by draw record lifecycle)

Incentive Plan
  ├── Incentive Calculation    (N — calculations using this plan)
  ├── Rate Tier                (N — rate band tiers, if plan uses tiered structure)
  └── Dependent Plan           (self-reference — threshold dependency gate)

Forecast Template
  ├── Forecast Period          (N — one per active period)
  ├── Forecast Override        (N — overrides governed by this template's rules)
  └── Health Score Template    (optional 1:1 — linked scoring configuration)
```

### 8.4 Phase 1 Salesforce Implementation Mapping

For reference, the logical-to-Salesforce mapping for Phase 1:

| Logical Entity        | Salesforce Object          | Notes                                       |
| --------------------- | -------------------------- | ------------------------------------------- |
| Forecast Period       | `Forecast__c`              | Custom object                               |
| Forecast Override     | `Forecast_Override__c`     | Custom object with self-referential lookups |
| Forecast Participant  | `Forecast_User__c`         | Custom object                               |
| Forecast Comment      | `Forecast_Comment__c`      | Custom object                               |
| Incentive Plan        | `Comp_Plan__c`             | Custom object                               |
| Incentive Calculation | `Comp_Calculation__c`      | Custom object                               |
| Draw Record           | `Commission_Draw__c`       | Custom object                               |
| Payment Record        | `Payment_Detail__c`        | Custom object                               |
| Pipeline Signal       | `Deal_Signal__c`           | Custom object                               |
| Signal Change History | `Deal_Signal_History__c`   | Custom object                               |
| Health Score Profile  | `Deal_Health_Profile__mdt` | Custom metadata type                        |
| Manager Accuracy      | `Manager_Accuracy__c`      | Custom object                               |
| Behavioral Flag       | `Behavioral_Flag__c`       | Custom object                               |
| Rate Tier             | `Commission_Tier__c`       | Custom object                               |
| Territory / Scope     | `Territory__c`             | Custom object                               |

---

## 9. AI Layer

### 9.1 Architecture

AI runs as an external microservice (Python FastAPI + XGBoost/Claude API). In Phase 1 (Salesforce), called via Named Credential callouts to stay outside governor limits. In Phase 3 (full-stack), called as an internal service within the platform's API layer.

```
Platform Scheduled Job / User Action
        │
        ▼ (API call — Named Credential in Phase 1, internal service call in Phase 3)
AI Service (external)
   ├── Close Probability Model (XGBoost / LightGBM)
   ├── Manager Accuracy Service (statistical, no ML)
   ├── Anomaly Detection Rules Engine
   ├── Payout Forecasting Engine (actuarial calculation)
   ├── Plan Design Simulator (Monte Carlo projection)
   └── LLM Agent (Claude API — NL editing, coaching, dispute assistant)
        │
        ▼ (writes back via API / Platform Event)
Platform Data Store
   ├── Forecast Override → Close_Probability field
   ├── Manager Accuracy record
   ├── Behavioral Flag record
   └── Forecast Comment record (coaching nudges)
```

### 9.2 AI Trust Boundaries

Enterprise buyers in RevOps, Finance, and Forecasting need absolute clarity on which platform outputs they can audit, which are predictive estimates, and which are AI-generated narrative. Conflating these trust tiers erodes buyer confidence and creates compliance risk.

#### 9.2.1 Trust Tiers

**Tier 1 — Deterministic / Auditable (can block workflow, suitable for financial audit)**

Every output in this tier is computed from a formula with named inputs, no randomness, and full reproducibility. Given the same inputs, the output is identical every time. These outputs can safely trigger blocking governance actions and appear in financial reports.

| Output                                                           | Module           | Formula / Logic                                                                                                                         |
| ---------------------------------------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Incentive calculations (rate × commissionable value × modifiers) | Sales Incentives | Fully traceable from plan configuration + transaction data + attainment snapshot                                                        |
| Health score (composite)                                         | Deal Health      | Weighted sum of component scores + adjustment rules (§5.2). Every point traceable to a specific signal value.                           |
| Governance rule triggers (CG-1 through CG-7)                     | Cross-Module     | Boolean evaluation against compensation context thresholds. Deterministic: same override + same attainment state = same trigger result. |
| Manager accuracy (hit rate, value accuracy, slip rate)           | Behavior Intel   | Statistical calculation over closed records vs. submitted overrides. No model — pure math.                                              |
| Attainment & rate tier determination                             | Sales Incentives | Sum of closed transaction values vs. quota. Tier lookup against plan configuration.                                                     |
| Incentive Impact Calculator (payout delta, threshold proximity)  | Cross-Module     | Arithmetic from current attainment + proposed value + rate tier boundaries.                                                             |
| Missing signal redistribution (weight rebalancing)               | Deal Health      | Proportional redistribution formula. Fully specified in §5.4.                                                                           |

**Tier 2 — Predictive / Advisory (cannot block workflow, displayed with confidence indicators)**

These outputs use statistical models or ML. They inform decisions but never gate them. The UI always shows a confidence indicator and a "how was this computed" link.

| Output                                                          | Module                            | Model Type                                                | Confidence Indicator                                                                                                        |
| --------------------------------------------------------------- | --------------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Close probability (0–100%)                                      | All                               | XGBoost / LightGBM trained on historical closed records   | Shown as "AI — {N} historical records used for calibration." Below 50 records: "Low confidence — limited calibration data." |
| Payout forecast (projected earnings)                            | Sales Incentives + Behavior Intel | Actuarial: open pipeline × close probability × rate tiers | Shown as "Projected — based on current pipeline and AI close probabilities."                                                |
| Anomaly likelihood scores (slip loop risk, staleness risk)      | Behavior Intel                    | Rule-based engine with frequency thresholds               | Shown as "Detected pattern" not "Prediction."                                                                               |
| Predictive scope roll-up                                        | Forecasting                       | Probability-weighted sum across records                   | Shown as "AI-weighted — differs from submitted total by {delta}."                                                           |
| Behavioral flag confidence (sandbagging / optimism probability) | Behavior Intel                    | Rule + model hybrid                                       | Shown as "Signal strength: High / Medium / Low" based on number of corroborating signals.                                   |

**Tier 3 — Narrative / Assistive (never affects workflow state, human-editable before delivery)**

These outputs are generated by an LLM (Claude API). They are convenience features that help humans communicate, not decision engines. They are always presented as drafts, never as authoritative outputs.

| Output                                 | Module           | Generation Method                                         | Safeguards                                                                                                                                                                  |
| -------------------------------------- | ---------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Natural language forecast editing      | Forecasting      | Claude API with function-calling schema                   | **Always requires confirmation diff before writing.** User sees proposed changes, confirms or rejects. No silent writes.                                                    |
| Coaching nudges                        | Behavior Intel   | Claude API + rule templates (structured data → narrative) | **Delivered to managers only, never to participants.** Manager can edit or discard before acting. Nudge text is not stored as an authoritative record.                      |
| Dispute explanation prose              | Sales Incentives | Claude API (structured calculation data → plain English)  | **Admin reviews and edits before sending to participant.** The structured Tier 1 calculation data is the authoritative source; the prose is a human-readable summary of it. |
| Behavior explanation narrative (§6.10) | Behavior Intel   | Claude API (structured explanation → narrative)           | **Structured explanation (Tier 1) is always the source of truth.** Narrative is supplementary. UI shows both: structured components on top, optional narrative below.       |

#### 9.2.2 UI Treatment by Trust Tier

| Tier                       | Visual Indicator                            | Label Convention                                                                 | Can Gate Workflow?                                                                  |
| -------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Tier 1 — Deterministic** | No special indicator (this is the baseline) | Stated as fact: "Health Score: 67" / "Rate Tier: Accelerator" / "Payout: $8,400" | **Yes** — governance rules, blocking approvals, financial reports                   |
| **Tier 2 — Predictive**    | "AI" badge + confidence label               | Prefixed: "AI Close Probability: 71%" / "AI Projected Earnings: $42K"            | **No** — advisory only. Displayed alongside Tier 1 data but visually distinguished. |
| **Tier 3 — Narrative**     | "AI Draft" badge + edit controls            | Prefixed: "AI-generated summary — review before sending"                         | **No** — always requires human confirmation before any action                       |

#### 9.2.3 Fallback Policy

| Failure Mode                                                  | Behavior                                                                                                                                                                                                                                               |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AI service unreachable (Tier 2 predictions unavailable)       | Platform operates normally with Tier 1 outputs only. Tier 2 columns show "Unavailable" with tooltip: "AI service not responding. Deterministic features unaffected."                                                                                   |
| AI service returns low-confidence prediction                  | Prediction displayed with "Low Confidence" badge. Not used in any derived calculations (e.g., payout forecast falls back to pipeline value × historical close rate instead of AI probability).                                                         |
| LLM generates hallucinated or incoherent narrative (Tier 3)   | All Tier 3 outputs have a "Regenerate" button. Structured Tier 1 data is always displayed alongside. If the narrative contradicts the structured data, the structured data governs. Admin/manager can discard narrative entirely.                      |
| AI model retraining produces materially different predictions | Model version is logged on every prediction. When a new model version is deployed, the first prediction cycle is flagged: "Model updated — predictions may differ from prior period." Comparison view: old model vs. new model available for 1 period. |

#### 9.2.4 AI Operational Guardrails

These are non-negotiable rules that ensure AI remains an assistant, never a hidden dependency:

1. **All core workflows are fully functional without AI.** If the AI service is completely unavailable, the platform operates normally with Tier 1 (deterministic) outputs only. Forecasting, incentive calculations, governance rules, health scores, and the Manager Decision Cockpit all work without AI. No page fails to load, no action is blocked.
2. **Every AI-generated action requires human confirmation before write.** NL forecast editing shows a diff — user confirms. Coaching nudges are delivered to managers — manager decides whether to act. Dispute explanations are reviewed by admin — admin sends. No AI output directly mutates any record.
3. **Every AI-generated explanation must be traceable to structured source inputs.** If the AI says "this deal is at risk because of low engagement," the structured engagement data (call count, meeting count, response rate) must be displayed alongside the narrative. The structured data is the evidence; the narrative is the interpretation.
4. **AI cannot mutate immutable financial records.** The append-only incentive ledger (§1.5.4) is never written to by AI processes. AI can generate projected/estimated values (Tier 2) but these are stored in separate projection records, never in the Incentive Calculation ledger.
5. **AI cannot approve governance actions.** Governance approvals, denials, and escalation resolutions require human action. AI can recommend ("this looks like a valid category change based on signal data") but the approve/deny button must be clicked by a person.
6. **AI predictions are never used as inputs to deterministic calculations.** Close probability (Tier 2) is never multiplied into an Incentive Calculation (Tier 1). Payout forecasts (Tier 2) use close probability but are clearly labeled as projections, not payable amounts. The Tier 1/Tier 2 boundary is a hard wall.

### 9.3 AI Features

| Feature                           | Type                          | Module                       | When It Runs                                              |
| --------------------------------- | ----------------------------- | ---------------------------- | --------------------------------------------------------- |
| Close Probability                 | XGBoost model                 | All                          | Nightly batch + on-demand when pipeline record row opened |
| Manager Accuracy Scoring          | Statistical calculation       | Forecasting + Behavior Intel | Weekly batch + immediately on record close                |
| Anomaly Detection                 | Rule-based engine             | Forecasting + Behavior Intel | Nightly batch; triggered events for real-time alerts      |
| Predictive Scope Roll-Up          | Probability-weighted sum      | Forecasting                  | On demand from reviewer Summary Table                     |
| Payout Forecasting                | Actuarial calculation         | Sales Incentives             | Nightly batch; on-demand from Participant portal          |
| Plan Design Simulator             | Monte Carlo projection        | Behavior Intel               | On demand from Finance admin                              |
| Sandbagging Detection             | Rule + model hybrid           | Behavior Intel               | Nightly batch; on threshold proximity trigger             |
| Natural Language Forecast Editing | Claude API (function calling) | Forecasting                  | On user input in NL editing panel                         |
| Coaching Nudges                   | Claude API + rule templates   | Behavior Intel               | Nightly batch; delivered as notifications                 |
| Incentive Dispute Assistant       | Claude API                    | Sales Incentives             | On demand when dispute created                            |

### 9.4 Close Probability Model

**Training data:** Closed pipeline records (terminal outcomes) with features:

- Forecast category history across periods
- Number of times close date was slipped
- Primary metric and secondary metric trend direction
- Category trend (forward/backward)
- Record age, stage, value
- Manager historical accuracy
- Deal health score at time of submission
- Days since last activity
- Stakeholder count

**Output:** Probability (0–100%) stored on the Forecast Override record's close probability field.

**Cold-start:** Cross-customer base model trained on anonymized aggregate data. Per-customer fine-tuning after 6 months of closed data. Confidence indicator shown in UI when model has < 50 historical records to calibrate on.

### 9.5 Natural Language Forecast Editing

Managers can describe changes in plain English in the forecast UI:

- _"Move the HSBC record to next period and drop by 500K, legal review is delayed"_ → Updates close date override and primary metric, appends note with original input as audit trail
- _"Mark all {mid-confidence category} records as {low-confidence category}"_ → Bulk update with confirmation dialog showing diff
- _"Show me all records that have slipped more than twice"_ → Dynamic filter application

Architecture: Claude API with function-calling schema mapping to Forecast Override field updates. The function schema is dynamically generated from the active Forecast Template's configured metrics and categories. Always requires a confirmation diff before writing.

### 9.6 Incentive Dispute Assistant

When a participant disputes an incentive calculation, the AI generates a natural-language explanation:

Input to Claude: Participant name, transaction details, incentive plan parameters, all Incentive Calculation records for the transaction, attainment at time of processing.

Output: Plain-English explanation of how the incentive was calculated, which rate tier applied and why, what the attainment was at close, and whether there are any adjustments (holds, caps, collection adjustments).

Admin can edit the explanation before sending to participant. Interaction logged in the Incentive Dispute record.

---

## 10. Notifications & Alerting

### 10.1 Notification Types

| Event                                             | Recipient                                      | Channel                              |
| ------------------------------------------------- | ---------------------------------------------- | ------------------------------------ |
| Forecast period opens                             | All assigned participants (hierarchy level 1+) | In-app + Email                       |
| Level N submits to Level N+1                      | Next-level reviewer                            | In-app                               |
| Top-level user freezes scope                      | All participants in scope                      | In-app + Email                       |
| Incentive processed for transaction               | Participant                                    | In-app + Email                       |
| Incentive paid                                    | Participant                                    | In-app + Email                       |
| Incentive dispute created                         | Admin                                          | In-app + Slack                       |
| Dispute resolved                                  | Participant                                    | In-app + Email                       |
| Plan published (awaiting acceptance)              | Participant                                    | In-app + Email                       |
| Plan accepted                                     | Admin                                          | In-app                               |
| Draw balance updated                              | Participant                                    | In-app                               |
| Sandbagging flag raised                           | Reviewer (level N+1)                           | In-app (not to participant)          |
| Anomaly detected (slip loop, cliff, staleness)    | Manager / Sales Ops                            | In-app                               |
| Coverage gap alert                                | Reviewer / Sales Ops                           | In-app + Slack                       |
| Payout forecast update                            | Participant                                    | In-app (weekly digest)               |
| Coaching nudge                                    | Manager                                        | In-app + Slack                       |
| **Forecast category change**                      | Manager (for owned records)                    | In-app (real-time)                   |
| **Forecast metric value change > threshold**      | Reviewer (next level)                          | In-app + optional Slack              |
| **Close date moved (slip or pull-in)**            | Manager + Reviewer                             | In-app                               |
| **Governance rule triggered (CG-1 through CG-7)** | Reviewer + Sales Ops (by rule config)          | In-app + Slack/Teams                 |
| **Governance approval required (CG-3)**           | Reviewer                                       | In-app + Email (urgent)              |
| **Tier threshold approach**                       | Participant (own) + Manager                    | In-app                               |
| **Behavior explanation generated**                | Reviewer                                       | In-app (in Cockpit governance queue) |

### 10.2 Delivery Channels

- **In-app:** Platform notification panel + bell icon (Phase 1: Salesforce Notification Builder; Phase 3: native notification system)
- **Email:** Platform email service (Phase 1: Apex callouts → email template engine; Phase 3: SES/SendGrid)
- **Slack:** Slack Bolt API (webhook per org channel)
- **Microsoft Teams:** Teams Bot Framework webhook

All notification preferences configurable per user and per event type by admin.

---

## 11. Unified UI/UX Principles

### 11.1 Design System

Phase 1 (Salesforce-native): Salesforce Lightning Design System (SLDS). All components built as LWC (Lightning Web Components). No Aura, no Visualforce for new work.

Phase 3 (standalone): SLDS-inspired React design system. Familiar to Salesforce-trained users. Components port 1:1 from LWC.

### 11.2 Cross-Module Navigation

Single app container with module tabs:

- Forecasting | Deal Health | My Commissions | Admin: Commissions | Insights

The Deal Health badge is the common visual element — visible in Forecasting rows, Rep portal, and Manager pipeline view. Clicking always opens the same score card breakdown panel.

### 11.3 Shared Interaction Patterns

| Pattern                  | Behavior                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------ |
| Destructive actions      | Always require confirmation dialog (Submit, Freeze, Copy, Process Commissions)             |
| Loading states           | Spinner during all async operations                                                        |
| Success / Error feedback | Salesforce Toast notifications (green / red)                                               |
| Dirty state indication   | Yellow row highlight for any unsaved edit                                                  |
| Trend indicators         | Color-coded arrows (green up = positive, red down = negative) with configurable thresholds |
| Score badges             | 🟢 (≥70) · 🟡 (40–69) · 🔴 (<40) used consistently across all health scores                |
| Pagination               | 40 records per page with "Showing X–Y of Z" and Prev/Next                                  |
| Export                   | Every table with ≥ 5 columns has an Export button (CSV/Excel)                              |
| Filters                  | Persist in sessionStorage within the browser session                                       |

### 11.4 Role-Based View Customization

Each persona sees a tailored default view:

| Persona   | Default Landing             | Key Widgets                                                               |
| --------- | --------------------------- | ------------------------------------------------------------------------- |
| Rep       | My Commissions portal       | Attainment gauges, payout forecast, deal health on owned opportunities    |
| Manager   | Forecasting — Manager View  | Deal table, summary table, anomaly alerts, coaching nudges                |
| Director  | Forecasting — Director View | Multi-manager rollup, manager accuracy badges, AI predicted vs. submitted |
| Admin     | Admin Commission Dashboard  | Full org commission view, export, dispute queue                           |
| Sales Ops | Platform config             | Plan setup, hierarchy config, weight profiles, anomaly thresholds         |

### 11.5 Manager Decision Cockpit

The single most requested capability across competitor review platforms: **one screen** that eliminates tool-switching during forecast calls. This is the primary "demo that wins" feature — the view managers use every week.

#### 11.5.1 Layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ MANAGER DECISION COCKPIT — {Scope Label} — {Period Label}                    │
├────────────────────────┬─────────────────────────────────────────────────────┤
│ FORECAST SUMMARY       │ GOVERNANCE QUEUE                                    │
│                        │                                                     │
│ Target:    $4.2M       │ ⚠ CG-2: J.Smith moved Acme to Commit              │
│ Committed: $3.8M       │   → $42K from Accelerator tier. Review.            │
│ Best Case: $5.1M       │ ⚠ CG-4: R.Patel pushed BigCo to next period       │
│ Pipeline:  $8.6M       │   → Health score 78. Possible sandbagging.         │
│ Coverage:  2.0×        │ ℹ CG-7: M.Lee override +$320K on Initech          │
│                        │   → Payout delta: +$18K. Badge attached.           │
│ AI Predicted: $4.0M    │                                                     │
│ Manager Accuracy: 72%  │ [Approve] [Deny] [Dismiss with Note]               │
├────────────────────────┴─────────────────────────────────────────────────────┤
│ PIPELINE RECORDS                                                             │
│ ┌──────┬────────┬──────┬────────┬──────┬────────┬──────┬──────┬───────────┐ │
│ │Record│Category│Metric│Health  │AI    │Rep     │Incent│Payout│Governance │ │
│ │Name  │        │Value │Score   │Close%│Override│ Rate │Delta │Flag       │ │
│ ├──────┼────────┼──────┼────────┼──────┼────────┼──────┼──────┼───────────┤ │
│ │Acme  │Commit  │$420K │🟢 82   │76%   │$400K   │12%   │+$42K │⚠ CG-2    │ │
│ │BigCo │Pipeline│$800K │🟢 78   │68%   │—       │8%    │—     │⚠ CG-4    │ │
│ │Initech│BestCase│$320K│🟡 55   │52%   │$350K   │8%    │+$18K │ℹ CG-7    │ │
│ │TelCo │Commit  │$180K │🔴 31   │24%   │$200K   │12%   │—     │⚠ Conflict│ │
│ └──────┴────────┴──────┴────────┴──────┴────────┴──────┴──────┴───────────┘ │
├──────────────────────────────────────────────────────────────────────────────┤
│ RECORD DETAIL (expands on row click)                                         │
│ ┌─────────────────────┬─────────────────────┬──────────────────────────────┐ │
│ │ HEALTH SCORE CARD   │ INCENTIVE TRACE     │ OVERRIDE AUDIT TRAIL         │ │
│ │ (§5.5 breakdown)    │ Plan: Enterprise AE  │ L1 override: $400K (Apr 2)  │ │
│ │                     │ Rate: 12% (Tier 2)  │ L2 override: $420K (Apr 3)  │ │
│ │ Conv Intel:  82     │ Attainment: 94%     │ Note: "Legal signed Apr 1"  │ │
│ │ Relationship: 71    │ Threshold: $4.5M    │ Category: Pipeline→Commit   │ │
│ │ Activity:    90     │ Distance: $42K      │   changed Apr 2 by J.Smith  │ │
│ │ Engagement:  75     │ If closes: crosses  │                              │ │
│ │                     │   Tier 2 → +$8.4K   │ Signal trail:               │ │
│ │ Adjustments:        │   on all future txns │ • DM on call Apr 1 ✓       │ │
│ │ + Next step: +10    │                     │ • Next step confirmed ✓      │ │
│ │ - Competitor: -15   │ [Full Calculation ↗] │ • Competitor mentioned ✗     │ │
│ └─────────────────────┴─────────────────────┴──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 11.5.2 Cockpit Components

| Panel                      | Data Source                                           | Interactions                                                                  |
| -------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Forecast Summary**       | Forecast Override rollup for scope + period           | Click metrics to filter pipeline by category                                  |
| **Governance Queue**       | Governance Event records for this scope/period (§7.3) | Approve, deny, dismiss with note — actions logged                             |
| **Pipeline Records Table** | All pipeline records in scope for period              | Sort, filter, click to expand detail. Inline override editing.                |
| **Health Score Card**      | Pipeline Signal + Health Score Template (§5.5)        | Clickable components drill into adapter data                                  |
| **Incentive Trace**        | Real-time Incentive Impact Calculator (§7.3.4)        | Shows plan, rate, attainment, threshold proximity, and "if closes" projection |
| **Override Audit Trail**   | Forecast Override history + Forecast Comment          | Full chronological trace of who changed what, when, and why                   |
| **Signal Trail**           | Signal Change History                                 | Chronological feed of signal events from connected adapters                   |

#### 11.5.3 Cockpit Behavior

- **Real-time:** All data live — no page refresh required. Incentive calculations run on every override save (< 500ms).
- **Keyboard navigation:** Tab through records, Enter to expand detail, Esc to collapse. Arrow keys to move between pipeline rows.
- **Compact mode:** Collapse Forecast Summary and Governance Queue to maximize pipeline table height for large deal volumes.
- **Export:** Export entire cockpit view to PDF (for meeting prep) or CSV (for offline analysis).
- **Saved views:** Managers can save filter/sort configurations as named views.

### 11.6 Multi-Period Record Tracking

Pipeline records that span multiple forecast periods (multi-year deals, long sales cycles) require seamless cross-period navigation:

- **Period timeline:** Each pipeline record shows a horizontal timeline of all periods it has appeared in, with category and metric value per period
- **Period-over-period comparison:** Side-by-side view of any two periods for the same record, highlighting what changed
- **Slip history:** Visual indicator showing how many times the close date has moved and in which direction
- **Cross-period incentive impact:** For records spanning fiscal year boundaries, show the incentive plan that applies in each period (plans may change year-over-year)
- **Navigation:** Click any period in the timeline to jump to that period's forecast view with the record highlighted

### 11.7 Configuration Layering

The spec describes a highly configurable platform — any hierarchy, any metrics, any categories, any periods, any roles, any plans, any weights, any governance rules, any adapters. That's architecturally correct, but if every customer starts at "expert customization," the product becomes "setup consultant required before first value." That kills the speed-to-value positioning (§13.3).

**Design principle:** Configurable architecture, opinionated defaults. Default install must feel like "turn on, map a few fields, usable in days."

#### Layer 1 — Starter Templates (default install, zero configuration required)

Every configuration object ships with a pre-built Starter Template that works out of the box for common use cases:

| Configuration Object  | Starter Template              | What It Covers                                                                                                                                           |
| --------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Forecast Template     | "Standard Quarterly Forecast" | 4 hierarchy levels, 2 metrics (Primary Value, Secondary Value), 5 categories (Commit/Best Case/Pipeline/Closed Won/Lost), Quarterly periods, Calendar FY |
| Incentive Plan        | "Standard Accelerated Plan"   | Flat rate below quota, 2 accelerator tiers, quarterly attainment, booking trigger                                                                        |
| Health Score Template | "CRM-Only Health Score"       | 3 components (Activity Recency, Stage Progression, Deal Momentum), CRM adapter only, default weights, default adjustment rules                           |
| Governance Rules      | "Standard Governance Pack"    | CG-1 through CG-7 with default thresholds, all enabled                                                                                                   |

Starter templates are **read-only**. Admins can clone and modify, but never edit the originals. This ensures a known-good reset point.

#### Layer 2 — Admin Configuration (self-service, no code required)

Admins customize templates through the platform's configuration UI:

- Rename levels, metrics, categories, periods
- Add/remove configurable fields
- Adjust thresholds, weights, percentages
- Enable/disable governance rules
- Map CRM fields to template fields

This is the "80% of customers" layer. Documented in the Configuration Guide (part of the Pilot Kit, §13.3).

#### Layer 3 — Expert Customization (code or deep configuration)

For complex deployments:

- Custom Signal Adapters (Apex code)
- Custom commissionable value formulas
- Custom governance rules beyond CG-1 through CG-7
- Custom behavioral flag detection logic
- Multi-template deployments (different templates per product line/region)

This layer requires professional services or advanced admin expertise. It is never required for pilot or initial deployment.

**Rule:** No customer should need Layer 3 to see value. If a customer cannot go live with Layer 1 or Layer 2, the Starter Templates need improvement — not the customer's patience.

---

## 12. Security & Permissions

### 12.1 Permission Sets

| Permission Set               | Access                                                         |
| ---------------------------- | -------------------------------------------------------------- |
| Forecasting_Manager          | Manager View: read + edit own deals, submit, save              |
| Forecasting_Director         | Director View: read all deals in territory, override, submit   |
| Forecasting_COO              | Full read + freeze                                             |
| Commission_Rep_Portal        | Self-service portal, own commissions only                      |
| Commission_Admin             | All commission records, processing, export, dispute management |
| Deal_Health_Viewer           | Read deal health scores (own team)                             |
| Deal_Health_Admin            | Manage weight profiles, signal source configuration            |
| Behavior_Intelligence_Viewer | Sandbagging flags, manager accuracy (Director+)                |
| Platform_Admin               | All configuration: hierarchy, plans, periods, thresholds       |

### 12.2 Data Isolation Rules

- Forecast Override records visible only within assigned scope/territory hierarchy
- Incentive Calculation records visible to owning participant (own) and incentive admins
- Manager Accuracy data visible to reviewers at hierarchy level N+2 and above (not to the manager being scored)
- Sandbagging flags visible to reviewers at hierarchy level N+2 and above only
- Pipeline signals scoped to the participant's owned and team records

### 12.3 API Security

- All data access methods enforce field-level and object-level security (Phase 1: `WITH SECURITY_ENFORCED`; Phase 3: row-level security policies)
- Freeze action server-side validates that calling user holds the top-level hierarchy position for the scope
- Incentive processing validates calling user has Incentive Admin permission
- External AI service authenticated via per-org API key (Phase 1: Named Credential; Phase 3: OAuth2 client credentials)
- All PII in incentive data treated as sensitive; no cross-org data in AI training without explicit consent

---

## 13. Performance & Design Requirements

### 13.1 Operation Latency Thresholds

| Operation                                                 | Threshold                                                   |
| --------------------------------------------------------- | ----------------------------------------------------------- |
| Forecast page initial load (up to 500 records)            | ≤ 5 seconds                                                 |
| Manager Decision Cockpit initial load                     | ≤ 6 seconds                                                 |
| Filter operation (client-side)                            | ≤ 1 second                                                  |
| Save / Submit (up to 200 records)                         | ≤ 8 seconds                                                 |
| Freeze operation                                          | ≤ 10 seconds                                                |
| Incentive processing (single transaction)                 | ≤ 15 seconds                                                |
| **Inline Incentive Estimator recalculation**              | **≤ 500ms**                                                 |
| **Governance rule evaluation (per action)**               | **≤ 500ms**                                                 |
| Admin dashboard load (full fiscal year, all participants) | ≤ 10 seconds                                                |
| Health score calculation (single record)                  | ≤ 2 seconds                                                 |
| Health score batch (nightly, up to 10K records)           | ≤ 30 minutes                                                |
| AI close probability (single record, on-demand)           | ≤ 3 seconds                                                 |
| Payout forecast (per participant)                         | ≤ 5 seconds                                                 |
| Behavior Explanation generation                           | ≤ 3 seconds (structured) / ≤ 8 seconds (with LLM narrative) |

All list views paginated at 40 records. Data operations batched to respect platform limits (Phase 1: Salesforce governor limits; Phase 3: database connection pooling).

### 13.2 Zero-Sync-Delay Architecture

**Critical competitive differentiator.** Spiff's 2-hour Salesforce sync delay is one of the most cited pain points in competitor reviews (confirmed across G2, Reddit, SoftwareAdvice). The platform must guarantee:

- **CRM-native execution (Phase 1):** All commission estimates, health scores, and governance rules run as LWC components within the Salesforce runtime. No external round-trip required for inline incentive calculations. Data read directly from Salesforce objects — no ETL, no staging database, no sync job.
- **Event-driven updates:** When a CRM record changes (stage, amount, close date), the platform recalculates affected incentive estimates, health scores, and governance evaluations immediately via platform events — not on a scheduled batch.
- **Latency budget:** From CRM record save → updated inline incentive estimator visible to user: ≤ 2 seconds. From CRM record save → governance rule evaluation complete: ≤ 2 seconds.
- **Phase 3 equivalent:** In the full-stack deployment, the API layer maintains an in-memory cache of active pipeline records, incentive plans, and attainment snapshots. Cache invalidation is event-driven from the CRM adapter's subscription. Target latency unchanged.

### 13.3 Speed-to-Value Target

**Competitive positioning:** Xactly and Varicent implementations take 6–12 months with heavy consulting. CaptivateIQ takes 4–6 months. The platform targets:

| Milestone  | Timeline            | Deliverable                                                           |
| ---------- | ------------------- | --------------------------------------------------------------------- |
| Day 0      | Kickoff             | Org assessment: existing objects, plan structures, hierarchy          |
| Week 1–2   | Configuration       | Forecast Template + Incentive Plan setup from existing plan documents |
| Week 3–4   | Data mapping        | CRM field mapping, historical data import, signal adapter connection  |
| Week 5–6   | UAT                 | User acceptance testing with real pipeline data                       |
| Week 7–8   | Pilot               | Single team/region go-live with full Cockpit view                     |
| Week 9–12  | Rollout             | Org-wide deployment, training, governance rule tuning                 |
| **Day 90** | **Full production** | **All modules live for all configured teams**                         |

**Enablers:**

- Declarative configuration (Forecast Templates, Incentive Plans, Health Score Templates) — no code for standard setups
- Pre-built Signal Adapters for top-5 vendors (Gong, Momentum, Zoom RA, Dialpad, email metadata)
- Import wizard for existing commission plan documents (CSV/Excel upload → plan configuration)
- Setup validation engine that checks configuration completeness before go-live

---

## 14. Integration Architecture

### 14.1 Signal Sources

Signal source integrations are implemented via the Signal Adapter interface (see §5.3). See §5.9 for the full list of built-in adapters, supported signals, and sync methods. Custom adapters can be added without modifying the scoring or behavior intelligence engines.

### 14.2 Outbound Integrations

| Target                            | Data                                              | Trigger                                  |
| --------------------------------- | ------------------------------------------------- | ---------------------------------------- |
| Payroll (ADP / Workday / Generic) | Payment Records marked ready for payment          | Scheduled (weekly / bi-weekly / monthly) |
| eSignature (DocuSign / AdobeSign) | Incentive Plan document for participant signature | On plan publish                          |
| Slack                             | Notifications, coaching nudges, dispute alerts    | Event-driven                             |
| Microsoft Teams                   | Notifications, coaching nudges                    | Event-driven                             |
| Email                             | Incentive notifications, plan acceptance requests | Event-driven                             |

### 14.3 CRM Adapter Pattern

Platform defines a CRM Adapter interface. Each adapter normalizes CRM-specific entities into the platform's logical model. Salesforce is Adapter 1.

```
CRMAdapter {
  getPipelineRecords(filter)         → PipelineRecord[]
  getLineItems(recordId)             → LineItem[]
  getParticipants(filter)            → Participant[]
  getAccounts(filter)                → Account[]
  writeSignal(recordId, signal)      → void
  writeIncentiveResult(recordId, ic) → void
  subscribeToEvents(eventType, cb)   → void
}
```

Adapter 2: HubSpot. Adapter 3: Microsoft Dynamics 365. Core business logic unchanged per adapter.

### 14.4 Managed Package Constraints (Phase 1 — Salesforce)

This section forces implementation discipline on ISV-specific concerns. These are not architectural decisions — they are survival constraints. "Works in dev org" becomes "support nightmare in pilot" if these are ignored.

| Constraint                               | Rule                                                                                                                                                                                                                                                              | Rationale                                                                                                                                                                           |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Namespace safety**                     | All custom objects, fields, classes, components, Platform Events, and Custom Metadata Types are prefixed with the `RevenueTrust__` namespace. No unmanaged metadata.                                                                                              | Avoids collision with subscriber org metadata. Required for AppExchange.                                                                                                            |
| **Subscriber field mapping**             | The platform never references subscriber org custom fields directly. All CRM field access goes through a **Field Mapping** configuration layer (Custom Metadata: `RevenueTrust__Field_Mapping__mdt`) that maps logical field names to subscriber field API names. | Different orgs name their fields differently. `Amount` vs. `Deal_Value__c` vs. `Total_Contract_Value__c` — the platform can't assume.                                               |
| **Standard object abstraction**          | The platform interacts with standard Salesforce objects (Opportunity, Account, User, Task, Event) through a **CRM Abstraction Layer** that can be swapped for the CRM Adapter in Phase 3. No direct SOQL on standard objects outside this layer.                  | Ensures Phase 3 portability. Also isolates the package from subscriber org sharing rules and record types.                                                                          |
| **Permission Set Groups**                | The platform ships Permission Set Groups (not individual Permission Sets) as the primary assignment mechanism. Individual Permission Sets exist for granular composition but admins assign groups.                                                                | Simpler subscriber administration. Avoids the "assign 6 permission sets per user" antipattern.                                                                                      |
| **Async retry queue**                    | Platform Event consumers implement a dead-letter pattern: if processing fails after 3 retries, the event is logged in `RevenueTrust__Failed_Event__c` with error details, payload snapshot, and a "Retry" admin action.                                           | Platform Events can fail in subscriber orgs due to governor limits, conflicting automation, or data issues. Silent failure is unacceptable for commission calculations.             |
| **Test isolation**                       | All Apex tests create their own data using `@TestSetup` and test data factories. No tests rely on org data (`SeeAllData=false` enforced). Tests run in any org — dev, scratch, packaging, subscriber sandbox.                                                     | Required for AppExchange security review. Also ensures tests don't break in subscriber orgs with unique data shapes.                                                                |
| **Governor-safe batch sizes**            | All batch Apex jobs use a configurable scope size stored in Custom Metadata (`RevenueTrust__Batch_Config__mdt`). Default scope: 50 records. Admin can adjust based on org complexity.                                                                             | Subscriber orgs with heavy automation may need smaller batch sizes to stay within governor limits.                                                                                  |
| **Trigger isolation (AD-1)**             | The only trigger on a subscriber-owned object is the lightweight Opportunity trigger that publishes Platform Events. All processing runs in the Platform Event handler's isolated execution context.                                                              | Prevents the platform from consuming the subscriber's trigger budget. Prevents subscriber automation from breaking platform processing.                                             |
| **Custom Setting for org configuration** | Org-level runtime configuration (feature flags, batch sizes, freshness thresholds) stored in a Protected Custom Setting (`RevenueTrust__Config__c`), not Custom Metadata.                                                                                         | Custom Settings are readable at runtime without SOQL. Protected settings are not visible to subscriber admins — prevents accidental misconfiguration of internal platform behavior. |

---

## 15. Phased Build Roadmap

### Phase 1 — Foundation (Months 1–4)

**Goal:** Salesforce managed package (LWC) combining Forecasting + Incentives + Deal Health signals.

**Forecasting:**

- [x] All functional requirements in Module 1 (from existing production code)
- [ ] Migrate legacy UI to LWC
- [ ] Implement Forecast Template configuration object (§3.2)
- [ ] Make hierarchy N-level configurable (remove hard-coded level enum)
- [ ] Make metrics configurable (remove hard-coded metric names)
- [ ] Make trend thresholds configurable via configuration records
- [ ] Make forecast categories configurable per forecast template
- [ ] Configurable fiscal calendar (remove hard-coded period assumptions)
- [ ] **Inline Incentive Estimator columns in pipeline record row (§3.3.5)**
- [ ] **Multi-period record tracking timeline and cross-period navigation (§11.6)**
- [ ] **Forecast change notifications: category change, metric change, close date slip (§10)**

**Sales Incentives:**

- [x] Core calculation engine (from existing production code)
- [ ] Build LWC participant self-service portal
- [ ] Build LWC admin dashboard
- [ ] Implement Incentive Plan configuration object (§4.2)
- [ ] Implement Participant Role configuration (§4.3)
- [ ] Implement Transaction Category configuration (§4.4)
- [ ] Add calculation breakdown view (transparent rate + attainment explanation)
- [ ] **Real-time Incentive Impact Calculator — zero sync delay (§7.3.4, §13.2)**
- [ ] What-if simulator in participant portal
- [ ] Incentive dispute workflow
- [ ] Plan acceptance / eSignature integration
- [ ] Payroll export (flat file / configurable mapping)
- [ ] Automated notifications (processed, paid, disputed)
- [ ] Partial hold % on Incentive Calculation records

**Cross-Module — Comp-Aware Governance (KEY DIFFERENTIATOR):**

- [ ] **Governance Trigger Engine evaluating forecast actions against compensation context (§7.3.1)**
- [ ] **Default governance rules CG-1 through CG-7 (§7.3.2)**
- [ ] **Governance action types: require justification, require approval, escalate, alert, warn, badge (§7.3.3)**
- [ ] **Governance Event audit trail entity (§7.3.5)**
- [ ] **Governance Queue panel in Manager Decision Cockpit (§11.5)**
- [ ] **Governance rule configuration admin UI**

**Manager Decision Cockpit (KEY DIFFERENTIATOR):**

- [ ] **One-screen unified layout: forecast summary + governance queue + pipeline table + detail panels (§11.5)**
- [ ] **Record detail: health score card + incentive trace + override audit trail + signal trail**
- [ ] **Keyboard navigation, compact mode, saved views, PDF/CSV export**

**Deal Health:**

- [ ] Pipeline Signal entity (custom object in Phase 1)
- [ ] Implement Health Score Template configuration object (§5.2.1)
- [ ] Implement Signal Adapter interface and built-in adapters (§5.3)
- [ ] First adapter: Gong (scheduled sync + webhook receiver)
- [ ] Second adapter: Momentum (scheduled sync)
- [ ] Composite health score calculation engine (deterministic formula)
- [ ] Score card LWC component (breakdown panel, adjustment list, score history)
- [ ] Health Score Profile configuration UI
- [ ] Signal badge in Forecasting pipeline row + conflict alert

**Notifications:**

- [ ] In-app platform notification rules (including all forecast change alerts)
- [ ] Slack Bolt API integration
- [ ] Teams Bot Framework integration
- [ ] Governance event notifications (approval requests, escalations, alerts)

---

### Phase 2 — AI + Behavior Intelligence Layer (Months 4–9)

**Goal:** AI-differentiated premium tier. Behavior intelligence as category-of-one feature.

- [ ] Manager Accuracy Scoring (historical override vs. actual, computed externally)
- [ ] Close Probability model (XGBoost, external service)
- [ ] Anomaly detection batch (slip loops, metric cliffs, coverage gaps, staleness)
- [ ] Predictive scope roll-up in Summary Table
- [ ] Payout forecasting ("at current pipeline, participant earns $X this period")
- [ ] Sandbagging detection (threshold proximity + deal health + forecast submission)
- [ ] Optimism bias detection (high-confidence categories + low health scores + low win rates)
- [ ] **Structured Behavior Explanation Engine (§6.10) — linked payout delta + plan mechanics + forecast action + governance recommendation**
- [ ] **"Green path" explanations for well-aligned behavior (§6.10.3)**
- [ ] Incentive dispute assistant (Claude API — NL explanation of calculation)
- [ ] Coaching nudges (nightly agent, Slack/Teams delivery)
- [ ] Natural language forecast editing (Claude API function-calling)
- [ ] **Incentive Plan Behavior Model: threshold clustering, timing concentration, discount correlation (§6.5)**

---

### Phase 3 — Full-Stack Platform (Months 10–18)

**Goal:** Extract from Salesforce runtime. Multi-CRM. Multi-tenant SaaS.

- [ ] React + TypeScript frontend (LWC logic ports 1:1)
- [ ] Node.js / Python API layer (Apex logic ports to TypeScript services)
- [ ] PostgreSQL multi-tenant schema (direct mapping from logical data model §8)
- [ ] Salesforce CRM Adapter (Adapter 1)
- [ ] HubSpot CRM Adapter (Adapter 2)
- [ ] Direct signal adapter webhooks (not via Named Credentials)
- [ ] Auth0 SSO (SAML / OIDC)
- [ ] AWS deployment (ECS Fargate, RDS PostgreSQL, ElastiCache Redis)
- [ ] SOC 2 Type II certification process

**Sales Incentives additions (Phase 3 data model):**

- [ ] Territory / Scope entity + participant assignment + scope-scoped plan lookup
- [ ] Rate Tier entity (rate band table — tiered plan support)
- [ ] Team Pool entity (bonus pools with distribution rules)
- [ ] Deferred / vesting payment schedules
- [ ] Recurring / trail incentive scheduler (periodic job per active subscription)
- [ ] Gross margin incentive engine (COGS input, margin-based calculation)

---

### Phase 4 — Agentic + Market Expansion (Months 16–24)

**Goal:** Full agentic platform. Dynamics 365. Mobile. Scenario planning.

- [ ] Scenario planning: multiple forecast category sets simultaneously (e.g., Commit / Best Case / Worst Case / Budget)
- [ ] Incentive Plan Design Agent ("Build me a plan for 80 participants targeting $50M in primary metric")
- [ ] Territory planning AI (quota allocation from historical attainment + pipeline signals)
- [ ] Plan Design Simulator (Monte Carlo) for Finance/HR
- [ ] Mobile app (React Native)
- [ ] Microsoft Dynamics 365 CRM Adapter (Adapter 3)
- [ ] Email signal integration (Gmail + Outlook metadata with consent model)
- [ ] Behavior Intelligence analytics portal (full plan behavior model, threshold clustering)
- [ ] Multi-industry plan templates (Healthcare, Financial Services, Telecom, Manufacturing)
- [ ] Quota planning tools (model and assign quotas, historical regression analysis)

---

## Appendix A — Feature Traceability

| Feature                                                                 | Source Document                                            | Module                         | Phase |
| ----------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------ | ----- |
| Multi-level hierarchy override                                          | FORECASTING_REQUIREMENTS.md §3.3–3.4                       | Forecasting                    | 1     |
| Partial save / submit                                                   | FORECASTING_REQUIREMENTS.md §3.6–3.7                       | Forecasting                    | 1     |
| Freeze / lock                                                           | FORECASTING_REQUIREMENTS.md §3.8                           | Forecasting                    | 1     |
| Budget mode                                                             | FORECASTING_REQUIREMENTS.md §3.1                           | Forecasting                    | 1     |
| Historical notes threading                                              | FORECASTING_REQUIREMENTS.md §3.10                          | Forecasting                    | 1     |
| N-level configurable hierarchy                                          | COMMERCIALIZATION_AND_AI_STRATEGY.md §4.1                  | Forecasting                    | 1     |
| Configurable metrics                                                    | COMMERCIALIZATION_AND_AI_STRATEGY.md §4.2                  | Forecasting                    | 1     |
| Scenario planning                                                       | COMMERCIALIZATION_AND_AI_STRATEGY.md §4.7                  | Forecasting                    | 4     |
| Multi-role commission calculation                                       | COMMISSIONS_MODULE_REQUIREMENTS.md §4–6                    | Sales Incentives               | 1     |
| Accelerators (quarterly + annual)                                       | COMMISSIONS_MODULE_REQUIREMENTS.md §6.2                    | Sales Incentives               | 1     |
| Draws / paybacks / clawbacks                                            | COMMISSIONS_MODULE_REQUIREMENTS.md §8                      | Sales Incentives               | 1     |
| Collection/milestone-triggered incentives                               | COMMISSIONS_MODULE_REQUIREMENTS.md §6.8                    | Sales Incentives               | 1     |
| Reprocessing for new eligible participants                              | COMMISSIONS_MODULE_REQUIREMENTS.md §7                      | Sales Incentives               | 1     |
| Plan acceptance / eSignature                                            | COMMISSIONS_GAP_ANALYSIS.md Gap #9                         | Sales Incentives               | 1     |
| Payroll export                                                          | COMMISSIONS_GAP_ANALYSIS.md Gap #11                        | Sales Incentives               | 1     |
| Deferred / vesting schedules                                            | COMMISSIONS_GAP_ANALYSIS.md Gap #1                         | Sales Incentives               | 3     |
| Tiered rate bands                                                       | COMMISSIONS_GAP_ANALYSIS.md Gap #2                         | Sales Incentives               | 3     |
| Team / bonus pools                                                      | COMMISSIONS_GAP_ANALYSIS.md Gap #3                         | Sales Incentives               | 3     |
| Territory-based plans                                                   | COMMISSIONS_GAP_ANALYSIS.md Gap #5                         | Sales Incentives               | 3     |
| Composite health score                                                  | TRANSPARENT_SCORING_DESIGN.md §2                           | Deal Health                    | 1     |
| Four-component scoring                                                  | TRANSPARENT_SCORING_DESIGN.md §3                           | Deal Health                    | 1     |
| Adjustment rules                                                        | TRANSPARENT_SCORING_DESIGN.md §4                           | Deal Health                    | 1     |
| Missing signal redistribution                                           | TRANSPARENT_SCORING_DESIGN.md §6                           | Deal Health                    | 1     |
| Score card breakdown panel                                              | TRANSPARENT_SCORING_DESIGN.md §7                           | Deal Health                    | 1     |
| Weight configuration                                                    | TRANSPARENT_SCORING_DESIGN.md §5                           | Deal Health                    | 1     |
| Forecast conflict alert                                                 | PRODUCT_PLATFORM_STRATEGY.md §3                            | Deal Health + Forecasting      | 1     |
| Manager accuracy calibration                                            | COMMERCIALIZATION_AND_AI_STRATEGY.md §5.2                  | Behavior Intelligence          | 2     |
| Close probability model                                                 | COMMERCIALIZATION_AND_AI_STRATEGY.md §5.1                  | Behavior Intelligence          | 2     |
| Anomaly detection                                                       | COMMERCIALIZATION_AND_AI_STRATEGY.md §5.3                  | Behavior Intelligence          | 2     |
| Sandbagging detection                                                   | PRODUCT_PLATFORM_STRATEGY.md §10                           | Behavior Intelligence          | 2     |
| Payout forecasting                                                      | PRODUCT_PLATFORM_STRATEGY.md §8                            | Behavior Intelligence          | 2     |
| Natural language editing                                                | COMMERCIALIZATION_AND_AI_STRATEGY.md §5.5                  | Forecasting + AI               | 2     |
| Coaching nudges                                                         | COMMERCIALIZATION_AND_AI_STRATEGY.md §5.6                  | Behavior Intelligence          | 2     |
| Plan design simulator                                                   | COMMISSIONS_GAP_ANALYSIS.md + PRODUCT_PLATFORM_STRATEGY.md | Behavior Intelligence          | 4     |
| Incentive dispute assistant                                             | PRODUCT_PLATFORM_STRATEGY.md §4                            | Sales Incentives + AI          | 2     |
| Comp-aware governance rules (CG-1 to CG-7)                              | Competitor Analysis (all 3 reports)                        | Cross-Module                   | 1     |
| Governance Trigger Engine                                               | Competitor Analysis — universal gap #1                     | Cross-Module                   | 1     |
| Manager Decision Cockpit (one-screen)                                   | Competitor Analysis — universal gap #3                     | UI/UX                          | 1     |
| Inline Incentive Estimator in forecast view                             | Competitor Analysis — universal gap #4                     | Forecasting + Incentives       | 1     |
| Structured Behavior Explanation Engine                                  | Competitor Analysis — universal gap #2                     | Behavior Intelligence          | 2     |
| Zero-sync-delay architecture                                            | Competitor Analysis — Spiff 2-hour delay pain point        | Platform Architecture          | 1     |
| Multi-period record tracking                                            | Competitor Analysis — CaptivateIQ year-over-year pain      | Forecasting                    | 1     |
| Speed-to-value 90-day implementation                                    | Competitor Analysis — Xactly/Varicent 6-12 month pain      | Platform                       | 1     |
| Forecast change notifications                                           | Competitor Analysis — Clari no-auto-alerts pain            | Notifications                  | 1     |
| Governance event notifications                                          | Competitor Analysis — no governance workflow pain          | Notifications                  | 1     |
| Authoritative Data Ownership & State Boundaries                         | Architecture Feedback — critical issue #1                  | Platform Architecture (§1.5)   | 1     |
| CRM vs. Platform conflict resolution rules                              | Architecture Feedback — critical issue #1                  | Platform Architecture (§1.5.2) | 1     |
| Event-sourced incentive calculation ledger                              | Architecture Feedback — critical issue #1                  | Platform Architecture (§1.5.4) | 1     |
| Governance Rule Runtime Semantics                                       | Architecture Feedback — critical issue #2                  | Cross-Module (§7.3.6)          | 1     |
| Approval state machine (pending/approved/denied/expired)                | Architecture Feedback — critical issue #2                  | Cross-Module (§7.3.6)          | 1     |
| Governance conflict precedence & evaluation order                       | Architecture Feedback — critical issue #2                  | Cross-Module (§7.3.6)          | 1     |
| AI Trust Boundaries (Tier 1/2/3)                                        | Architecture Feedback — critical issue #3                  | AI Layer (§9.2)                | 1     |
| AI fallback policy (service unavailable, low confidence, hallucination) | Architecture Feedback — critical issue #3                  | AI Layer (§9.2.3)              | 1     |
| Module Isolation Rules (per-module may/may-not contracts)               | Operational Feedback #7                                    | Platform Architecture (§1.6)   | 1     |
| Insight vs. Enforcement boundary                                        | Operational Feedback #13                                   | Platform Architecture (§1.6.2) | 1     |
| Cross-Module Event Orchestration matrix                                 | Operational Feedback #8                                    | Cross-Module (§7.4)            | 1     |
| Behavior Intelligence Confidence & Interpretation Policy                | Operational Feedback #9                                    | Behavior Intelligence (§6.11)  | 1     |
| AI Operational Guardrails                                               | Operational Feedback #10                                   | AI Layer (§9.2.4)              | 1     |
| Configuration Layering (Starter/Admin/Expert)                           | Operational Feedback #11                                   | UI/UX (§11.7)                  | 1     |
| Signal Freshness State Enum (LIVE/RECENT/STALE/EXPIRED/MISSING)         | Operational Feedback #12                                   | Deal Health (§5.10)            | 1     |
| Managed Package Constraints                                             | Operational Feedback #14                                   | Integration (§14.4)            | 1     |
| CRM record deletion conflict resolution                                 | Operational Feedback #15                                   | Platform Architecture (§1.5.2) | 1     |
