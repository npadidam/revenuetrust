# Forecasting Application — Commercialization & Agentic AI Strategy

**Based on:** Code review of Temenos ORG custom-built Salesforce Forecasting Aura Application  
**Date:** 2026-04-01  
**Status:** Strategic Assessment

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Commercial Viability Assessment](#2-commercial-viability-assessment)
3. [Current Strengths Worth Preserving](#3-current-strengths-worth-preserving)
4. [Flexibility Gaps — What Must Change](#4-flexibility-gaps--what-must-change)
5. [Agentic AI Opportunities](#5-agentic-ai-opportunities)
6. [Productization Roadmap](#6-productization-roadmap)
7. [Risks & Mitigations](#7-risks--mitigations)
8. [Competitive Landscape](#8-competitive-landscape)
9. [Target Market & Positioning](#9-target-market--positioning)

---

## 1. Executive Summary

The current application is a **production-proven, enterprise-grade forecasting system** with genuine competitive differentiation. It solves a specific, expensive pain point — reconciling bottom-up deal forecasts across a multi-level sales hierarchy with currency localization, partial save/submit granularity, and full audit governance — that most off-the-shelf tools handle poorly.

**Verdict: Strong commercialization candidate**, subject to three foundational changes:

1. Decoupling from Salesforce-only deployment
2. Making the hierarchy, metrics, and categories configurable rather than hard-coded
3. Layering Agentic AI on top of the data model, which already captures the right signals

The AI opportunity is not superficial here. The application's data model — with per-deal status history, manager override trends, hierarchy-level comparisons, and timestamped submissions — is exactly the structure needed for meaningful deal prediction and manager calibration models.

---

## 2. Commercial Viability Assessment

### What Drives the Value Proposition

Enterprise sales organizations running a 100+ person sales force have a chronic forecasting problem: by the time a CEO-level number is assembled, it has passed through 3–4 human filters (Manager → Sub-Director → Director → COO), each introducing bias, optimism, or sandbagging. The reconciliation is done in spreadsheets, in CRM comments, or not at all.

This application solves that with:

- A structured override chain where each level can see and adjust the level below
- Deal-by-deal accountability with a full status trail
- A freeze mechanism that locks final committed numbers
- Historical note threading per opportunity across forecast periods

These capabilities have real dollar value. Forecast accuracy improvements of even 5–10% at a $500M revenue company translate to material planning decisions (hiring, capacity, cash management).

### Market Sizing (Rough)

| Segment                       | Description                                         | Rough TAM                         |
| ----------------------------- | --------------------------------------------------- | --------------------------------- |
| Enterprise Software Companies | Complex multi-product deals, multi-level sales orgs | $2B+ (Revenue Intelligence space) |
| Financial Services Sales      | Asset management, banking software sales            | $500M                             |
| Global SaaS Companies         | ARR forecasting with territory splits               | $1B+                              |

The Revenue Intelligence / Sales Forecasting software market (Clari, Prophix, Anaplan, Salesforce Einstein) is valued at ~$3–5B and growing. The differentiated entry point here is **hierarchical override governance** + **AI-assisted accuracy calibration**, which none of the major players do well at the deal level.

---

## 3. Current Strengths Worth Preserving

These capabilities represent real IP developed through production use. They must survive any rewrite.

### 3.1 Multi-Level Hierarchy with Copy-Down

The 4-level chain (Manager → Sub-Director → Director → COO) with per-level override storage and the ability to copy-down from the level below is architecturally non-trivial. Most tools either aggregate blindly or require manual exports between levels.

**Preserve:** The `Forecast_Override__c` self-referential lookup pattern (`Previous_Level_Forecast_Override__c`) that chains levels together. This is the data model's core innovation.

### 3.2 Partial Save / Partial Submit

The distinction between saving filtered deals vs. all deals, reflected as "Partially Saved" vs. "Saved" status, mirrors real workflow needs. Sales teams rarely review every deal in one sitting.

**Preserve:** The full/partial flag on all persistence operations and the `Forecast_Status__c` enum that tracks this state.

### 3.3 Trend Indicators with Business-Meaningful Thresholds

The `Value_Trend__c` and `ACV_Value_Trend__c` fields, driven by ±100k NBV and ±50k ACV thresholds, are the result of domain knowledge about what constitutes a material change. Generic dashboards don't know this.

**Preserve:** The concept of configurable materiality thresholds per metric.

### 3.4 Deal-Share Deduplication at COO Level

Excluding same-region deal shares from COO rollups to prevent double-counting is the kind of edge case that takes years of production complaints to identify and fix. It is solved here.

**Preserve:** The `isDealShareInSameRegionAsMainDeal` flag and COO-level rollup exclusion logic.

### 3.5 Budget vs. Forecast Dual Mode

Running both budget planning and in-year forecasting in the same UI — with different category options and visual styling — is rare and valuable. Most orgs run these as completely separate tools.

**Preserve:** The `Budget_Mode__c` flag on the forecast period and the conditional rendering it drives.

### 3.6 Historical Notes per Deal per Forecast Period

The `Forecast_Comment__c` linked to Opportunity + User + Forecast period, surfaced via a modal in the deal row, creates a lightweight CRM-within-CRM for forecast narrative. This is frequently requested by sales ops teams.

**Preserve:** The historical comments modal and the `getLastForecastComment()` retrieval pattern.

---

## 4. Flexibility Gaps — What Must Change

These are constraints that are currently hard-coded in the Aura components or Apex layer. Each one limits the addressable customer base.

### 4.1 Fixed 4-Level Hierarchy

**Current state:** Manager, Sub-Director, Director, COO are hard-coded enum values in `Forecast_User__c.Forecast_Level__c` and drive conditional rendering throughout the components.

**Problem:** A 200-person startup has Manager → VP → CRO (3 levels). A global enterprise may have Manager → Regional Director → Area VP → Global VP → CRO (5 levels).

**Required change:** Replace fixed levels with a configurable N-level hierarchy where each level is a named node in a parent-child relationship. The UI renders levels dynamically based on org configuration.

### 4.2 Hard-Coded Metrics: NBV and ACV

**Current state:** Every component, every Apex method, every summary table is built around exactly two metrics: NBV (Net Booking Value) and ACV (Annual Contract Value).

**Problem:** A SaaS company cares about ARR. A hardware company cares about Units. A consulting firm cares about Billable Days. A company with multiple product lines may want to forecast 4–5 metrics simultaneously.

**Required change:** Metrics should be configurable per forecast template: name, aggregation method (sum/average), currency flag, display format, and trend threshold.

### 4.3 Fixed Trend Thresholds (±100k / ±50k)

**Current state:** `SL_ForecastManagerViewHelper.js` has the values 100000 and 50000 hard-coded in the `changeStatus()` method.

**Problem:** For a company selling $10k SaaS deals, a $100k threshold is meaningless. For a company selling $50M infrastructure deals, it's noise.

**Required change:** Threshold values stored in metadata/config and applied per forecast template or per metric.

### 4.4 Fixed Forecast Categories

**Current state:** `Forecast_Category__c` picklist options (Closed, Forecast, Cover, Pipeline, Lost) are set in the component markup and Apex. Budget mode swaps one option but doesn't generalize.

**Problem:** Salesforce native uses Commit/Best Case/Pipeline/Omitted. Clari uses their own taxonomy. Every company maps stages differently.

**Required change:** Category options configured per forecast template with mapping rules from CRM opportunity stages.

### 4.5 Salesforce-Only Deployment

**Current state:** Entire UI is Aura (Salesforce-proprietary), all backend is Apex, data lives in Salesforce custom objects.

**Problem:** Cuts TAM to Salesforce customers only (~150k companies). HubSpot, Pipedrive, Dynamics, and Zoho users — plus companies with no CRM — are excluded.

**Required change:**

- UI: Rebuild in React (or migrate to LWC OSS as an interim step)
- Backend: Extract business logic to a Node.js or Python API layer
- Data: Migrate schema to PostgreSQL or another portable RDBMS
- CRM connectivity: Build an adapter pattern with Salesforce as the first connector

### 4.6 Fixed Fiscal Calendar (Q1–Q4 Calendar Year)

**Current state:** Quarter selection is built around standard Q1–Q4. The `validateQtrChange()` method compares against system-date-derived quarters.

**Problem:** Many companies run April–March or October–September fiscal years. Monthly forecasting (SaaS ARR tracking) is increasingly common.

**Required change:** Fiscal calendar should be configurable: period type (month/quarter), period start, period labels. The quarter selector should derive options from the configured calendar.

### 4.7 No Scenario Planning Beyond Two Modes

**Current state:** The application supports Standard Forecast and Budget as two separate modes.

**Problem:** Enterprise planning needs Commit / Best Case / Worst Case / Budget as simultaneous scenarios that can be compared side-by-side.

**Required change:** Support N named scenarios per forecast period, each with its own set of override records. Summary table can show a scenario comparison view.

---

## 5. Agentic AI Opportunities

The existing data model already captures the right signals for meaningful AI. This is not a case of bolting AI onto irrelevant data — the schema was built (even if unintentionally) to record exactly what a prediction model needs.

### 5.1 Deal Close Probability (Tier 1 — Build First)

**What it does:** Assigns a close probability to each deal in the forecast grid, distinct from the manually selected Forecast Category.

**Data signals already available:**

- `Forecast_Category__c` history across periods (how many times has this deal been in "Forecast"?)
- `Close_Date_Override__c` slippage (how many quarters has the close date moved?)
- `Value_Trend__c` / `ACV_Value_Trend__c` (is the deal growing or shrinking?)
- `Category_Trend__c` (is the deal moving toward or away from Closed?)
- Manager's historical accuracy (see 5.2)
- `Opportunity.StageName`, `Opportunity.Amount`, `Opportunity.Age`
- `Deal_Score__c` (already on the opportunity)

**Model type:** Gradient Boosted Trees (XGBoost/LightGBM) trained on historical closed opportunities with labels = [Won, Lost, Slipped-beyond-period].

**Output in UI:** A probability badge (e.g., "72%") displayed next to each deal row, color-coded green/amber/red. Optionally, a recommended category override when the model's prediction significantly diverges from the manager's category.

**Cold-start mitigation:** Train a cross-customer base model on anonymized aggregate data. Fine-tune per customer as their history grows.

### 5.2 Manager Accuracy Calibration (Tier 1 — Build First)

**What it does:** Scores each manager's historical forecast accuracy and surfaces this to Directors reviewing manager submissions.

**How it works:**

- Compare `Previous_Forecast_Override__c.NBV__c` (what manager submitted) to `Opportunity.Amount` at close (what actually happened)
- Per manager: calculate hit rate by category — "When this manager calls Forecast, it closes 58% of the time at or above the submitted value"
- Track quarter slippage rate: "This manager's deals slip on average 1.2 quarters"

**Output in UI:**

- Small accuracy badge on each manager's deals in the Director View (e.g., "Manager: 64% accurate")
- Director-level summary panel: ranked accuracy table for each manager in the territory
- Suggested adjustment: "Based on historical accuracy, AI suggests adjusting Manager A's total from 2.1M to 1.8M"

**Value:** Directors currently apply intuition-based adjustments. This makes the adjustment data-driven and auditable.

### 5.3 Anomaly Detection & Proactive Alerts (Tier 1 — Build First)

**What it does:** Flags deals that exhibit statistically unusual patterns requiring human review, proactively surfaced rather than waiting for a manager to scroll to them.

**Anomaly types to detect:**

- **Quarter slippage loop:** Deal has moved close date 3+ consecutive periods
- **NBV cliff:** Deal NBV dropped >40% in a single period change
- **Category regression:** Deal moved from Forecast → Cover → Pipeline (backward movement)
- **Staleness:** Deal has had no forecast updates in 2+ periods despite being in the active pipeline
- **Coverage gap:** Territory has less than 3x pipeline coverage for the current quarter target

**Output in UI:**

- A flagged deals panel at the top of the forecast grid (dismissible per period)
- Inline warning icon on specific deal rows with hover tooltip explaining the anomaly
- Summary count in the header: "3 deals require attention"

### 5.4 Predictive Territory Roll-Up (Tier 2)

**What it does:** At the Director/COO level, shows not just what was submitted bottom-up, but what the AI predicts the territory will actually close — with a confidence interval.

**How it works:**

- Apply deal close probabilities (5.1) across all deals in the territory
- Weight by manager accuracy calibration (5.2)
- Output: Expected Close (probability-weighted sum), Conservative (P25), Optimistic (P75)
- Compare to: Manager-submitted total, Director override total, Territory target

**Output in UI:**

- A new row in the Summary Table: "AI Predicted Close: $4.2M ± $600K"
- Side-by-side comparison: Target | Manager Submitted | Director Override | AI Prediction
- Color indicator: Is the submitted forecast above or below AI prediction by more than 15%?

**Value:** Gives COO/CRO a sanity check on the submitted numbers before they become the company's plan.

### 5.5 Natural Language Forecast Editing (Tier 2)

**What it does:** Allows managers to describe a deal change in plain English and have the agent translate it into field updates.

**Example interactions:**

- _"Move the HSBC deal to Q3 and drop the value by 500k, legal review is taking longer than expected"_ → Updates `Close_Date_Override__c` and `NBV__c`, appends note
- _"Mark all Cover deals as Pipeline for this quarter"_ → Bulk category update with confirmation
- _"Show me all deals that have slipped more than once"_ → Dynamic filter application

**Architecture:**

- Claude API (or equivalent) with a function-calling schema that maps to `Forecast_Override__c` field updates
- Confirmation step before any writes: show a diff of what will change
- Writes to `Notes__c` automatically with the natural language input as audit trail

**Why this matters:** Managers currently spend significant time clicking through 40-row paginated tables to make individual changes. Voice/text input dramatically reduces friction.

### 5.6 Automated Coaching Nudges (Tier 3)

**What it does:** An AI agent that reviews each manager's open pipeline and proactively surfaces deal-specific coaching suggestions.

**Example nudges:**

- _"Deal: Barclays (Forecast, Q2, $1.2M) — No legal docs signed. 82% of deals in this category without signed legal docs slip to next quarter."_
- _"Deal: ING (Cover, Q2, $800K) — Last activity was 45 days ago. Deals with no activity for 30+ days close at 23%."_
- _"Manager summary: You have $4.1M submitted for Q2 but your historical Q2 close rate is 71%. Suggested commit: $2.9M."_

**Architecture:**

- Scheduled agent runs nightly or on-demand
- Pulls deal context from CRM + `Forecast_Override__c` history
- Generates nudge text via LLM with structured deal context in the prompt
- Delivers in-app (notification panel) or via email/Slack

---

## 6. Productization Roadmap

### Phase 1 — Harden & Package (Months 1–4)

**Goal:** Make the existing Salesforce app distributable as a managed package to other Salesforce orgs.

- [ ] Make hierarchy levels configurable (remove hard-coded 4-level enum)
- [ ] Make metrics configurable (remove hard-coded NBV/ACV fields)
- [ ] Make trend thresholds configurable via custom metadata
- [ ] Make forecast categories configurable per template
- [ ] Build an Admin Setup UI (configure hierarchy, metrics, categories, fiscal calendar)
- [ ] Migrate Aura components to LWC (Salesforce is deprecating Aura)
- [ ] Comprehensive test coverage (target 90%+ Apex coverage)
- [ ] Salesforce AppExchange listing preparation

**Output:** A Salesforce-native managed package installable by any Salesforce Enterprise customer.

### Phase 2 — AI Layer on Salesforce (Months 3–6, overlaps Phase 1)

**Goal:** Ship AI features on the Salesforce platform using the existing data model.

- [ ] Manager Accuracy Scoring (uses existing `Forecast_Override__c` history)
- [ ] Deal Close Probability model (train on closed opportunities)
- [ ] Anomaly Detection alerts in the UI
- [ ] Integrate with Claude API for natural language forecast editing
- [ ] Predictive territory roll-up in the Summary Table

**Output:** AI-enhanced managed package. This is the key differentiator for AppExchange and direct sales.

### Phase 3 — Platform Independence (Months 5–10)

**Goal:** Break free from Salesforce-only deployment to expand TAM.

- [ ] Extract business logic to a Node.js / Python API layer
- [ ] Rebuild UI in React with SLDS-inspired design system
- [ ] Build CRM connectors: Salesforce (adapter 1), HubSpot (adapter 2)
- [ ] PostgreSQL data model with multi-tenant isolation
- [ ] Auth: SSO via SAML/OIDC, role-based access control
- [ ] Deploy to cloud (AWS/GCP): API + UI + background AI jobs

**Output:** A standalone SaaS product that works with or without Salesforce.

### Phase 4 — Agentic Features & Expansion (Months 9–18)

**Goal:** Full agentic forecasting assistant and expanded market reach.

- [ ] Autonomous forecast coaching agent (deal-specific nudges)
- [ ] Scenario planning: Commit / Best Case / Worst Case simultaneous views
- [ ] CRM connectors: Dynamics 365, Pipedrive, Zoho
- [ ] Mobile-friendly interface for managers on the go
- [ ] Slack / Teams integration for forecast notifications and quick updates
- [ ] API-first architecture for customer integrations

**Output:** Market-ready SaaS product with AI-native differentiation.

---

## 7. Risks & Mitigations

### Risk 1: Salesforce as Competitor

**Threat:** Salesforce sells Einstein Forecasting and Revenue Intelligence. If you stay Salesforce-native, you compete on their platform and they can bundle and undercut.

**Mitigation:**

- Phase 1 (AppExchange) builds revenue and validates the market, but Phase 3 (platform independence) is non-negotiable for long-term defensibility
- Differentiate on the multi-level override governance and AI accuracy calibration — Einstein Forecasting does not do per-manager accuracy scoring or hierarchical override chains
- Build the CRM-agnostic version before Salesforce can copy the specific differentiation

### Risk 2: AI Cold-Start Problem

**Threat:** Deal prediction models need 2–3 years of closed opportunity history to be accurate. New customers have no history.

**Mitigation:**

- Train a cross-customer base model on anonymized aggregate data from early design partners
- Use rule-based heuristics as a fallback during the first 6 months (e.g., "Deals in Forecast category with signed legal close at 70% historically")
- Be transparent in the UI about model confidence: show low confidence scores when history is thin
- Allow customers to seed the model by exporting historical data from their CRM on onboarding

### Risk 3: Sales Process Variability

**Threat:** The current model fits enterprise software companies (like Temenos) well. It assumes a quarterly cadence, NBV/ACV metrics, and a specific stage vocabulary. A manufacturing company or SaaS startup has a completely different mental model.

**Mitigation:**

- Phase 1 targets only enterprise software / financial technology companies — the Temenos adjacent market
- Configuration work in Phase 1 (custom metrics, categories, fiscal calendar) broadens fit before Phase 3
- Do not try to serve all verticals at once; build deep domain fit in one vertical first

### Risk 4: Aura Framework Deprecation

**Threat:** Salesforce has announced Aura is being sunset in favor of LWC. Building commercial features on Aura creates technical debt immediately.

**Mitigation:**

- Include Aura-to-LWC migration as a mandatory deliverable in Phase 1
- Do not invest new feature development in Aura components — any net-new UI work goes into LWC or React
- This is a known migration with clear Salesforce documentation; it is effort but not a blocker

### Risk 5: Data Privacy / Multi-Tenancy

**Threat:** Revenue forecasting data is among the most sensitive data a company holds. A multi-tenant SaaS product must guarantee strict data isolation.

**Mitigation:**

- Schema-level tenant isolation (not just row-level) for Phase 3 cloud deployment
- SOC 2 Type II certification as a Phase 3 exit requirement before enterprise sales
- All AI model training must use per-tenant isolated datasets — never cross-contaminate customer data

---

## 8. Competitive Landscape

| Competitor                          | Strengths                                        | Weaknesses vs. This Application                                                                |
| ----------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| **Clari**                           | Beautiful UI, strong AI, well-funded             | No per-deal hierarchical override chain; black-box AI with limited manager accountability      |
| **Salesforce Einstein Forecasting** | Native CRM integration, no additional deployment | 2-level hierarchy max; no partial submit/save granularity; AI is not explainable at deal level |
| **Anaplan**                         | Very flexible planning tool                      | Overkill complexity; expensive; not sales-process-native; no deal-level AI                     |
| **Prophix**                         | Strong financial planning                        | Finance-first, not sales-process-native; weak CRM integration                                  |
| **Spreadsheets (Excel/Sheets)**     | Zero switching cost, universally understood      | No audit trail; manual aggregation errors; no AI; not real-time                                |

**Differentiation Summary:**

- More governance than Clari (hierarchical override with freeze)
- More deal-level granularity than Einstein Forecasting
- Less complexity than Anaplan
- More accurate than spreadsheets
- AI that explains _why_ via manager accuracy scoring, not just _what_

---

## 9. Target Market & Positioning

### Primary Target: Enterprise Software & Fintech Sales Organizations

**Profile:**

- 50–500 person sales org
- 3–5 level sales hierarchy (Manager through CRO)
- Deal sizes $100K–$50M (NBV/ACV meaningful at this scale)
- Already using Salesforce (Phase 1) or HubSpot (Phase 3)
- Pain: Manual spreadsheet forecasting or generic CRM forecasting that loses accuracy at the Director/COO level

**Buyer:** VP of Sales Operations, CRO, Head of Revenue Planning

**Champion:** Sales Operations Manager (the person who currently runs the spreadsheet process)

### Positioning Statement

_"The only forecasting platform built for how enterprise sales hierarchies actually work — with deal-level overrides at every level, manager accuracy intelligence, and an AI agent that tells you what your pipeline will really close, not just what your team submitted."_

### Pricing Model (Suggested)

| Tier         | Description                                                         | Target Price                   |
| ------------ | ------------------------------------------------------------------- | ------------------------------ |
| Starter      | Up to 3 hierarchy levels, 2 metrics, no AI                          | $15–25/user/month              |
| Professional | Unlimited levels and metrics, AI close probability + anomaly alerts | $40–60/user/month              |
| Enterprise   | Full agentic features, multi-CRM, custom integrations, SOC 2        | $80–120/user/month + setup fee |

Sales org of 200 people at Professional tier = ~$96–144K ARR per customer. 50 customers = $5–7M ARR. Very achievable for a focused vertical SaaS.

---

_Document prepared based on direct source code analysis of the Temenos ORG custom Salesforce forecasting application._
