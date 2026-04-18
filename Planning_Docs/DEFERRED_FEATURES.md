# RevenueTrust — Deferred Features & Future Work

**Version:** 1.0  
**Date:** April 14, 2026  
**Status:** Living document — updated after each implementation milestone  
**Purpose:** Single source of truth for all features intentionally deferred from V1, organized by module and priority.

---

## How to Read This Document

| Priority | Meaning                                                       |
| -------- | ------------------------------------------------------------- |
| **P1**   | Required for GA — must ship before first customer install     |
| **P2**   | Required for enterprise readiness — needed by end of V1 cycle |
| **P3**   | V2 backlog — nice-to-have, not blocking                       |
| **P4**   | Exploratory — requires design work before committing          |

---

## 1. Forecasting Module

### 1.1 Apex — Deferred from Controller Spec V1.1

| #   | Feature                                                           | Spec Ref                              | Priority | Notes                                                                                                                                                                                                                                                                      |
| --- | ----------------------------------------------------------------- | ------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-1 | `reopenPeriod(Id periodId)`                                       | §11.8                                 | **P2**   | Unfreeze a frozen period. Rare admin action. Must update `Forecast_Period__c.Status__c = 'Open'`, publish `PERIOD_REOPENED` event (Commission Event Routing event #43). Requires `Platform_Admin` permission. Must create `Forecast_Change_Event__c` with type `Unfreeze`. |
| F-2 | `aiPredicted` field population on `ForecastSummaryDTO`            | §11.16                                | **P3**   | Currently field exists on DTO but never populated. Requires: (a) Close_Probability**c on Forecast_Override**c or pipeline record, (b) nightly batch to compute predicted totals. Source: `Forecast_Override__c.Close_Probability__c * metric value`, summed.               |
| F-3 | `managerAccuracy` field population on `ForecastSummaryDTO`        | §11.16                                | **P3**   | Requires `Forecast_Accuracy__c.Accuracy_Score__c` object + weekly batch to compare forecast vs. actuals. Eventually consistent (up to 7 days).                                                                                                                             |
| F-4 | Custom pipeline object support in `ForecastDataService`           | §4.1, FORECASTING_OBJECT_MODEL §DP-F1 | **P2**   | Currently `getPipelineRecordsForScope()` uses `PipelineObjectService` but hardcodes some Opportunity field names (CloseDate, Amount, StageName, OwnerId). Full abstraction via `Field_Mapping__mdt` needed for custom objects.                                             |
| F-5 | Territory-based scope in `ForecastDataService`                    | §4.1                                  | **P2**   | Currently only ownership-based hierarchy (OwnerId chain) is implemented. Territory-based and Custom_Field-based scopes need `Hierarchy_Source__mdt` integration.                                                                                                           |
| F-6 | Stage filter (exclude terminal stages unless they have overrides) | §4.1 step 6                           | **P1**   | `getPipelineRecordsForScope()` does not exclude Closed Won/Lost stages from pipeline query. Should exclude terminal stages unless a Forecast_Override\_\_c exists.                                                                                                         |

### 1.2 LWC Components — Not Yet Built

| #    | Feature                                         | Week   | Priority | Dependencies                                                                                         |
| ---- | ----------------------------------------------- | ------ | -------- | ---------------------------------------------------------------------------------------------------- |
| F-7  | LWC Forecast Grid (Manager View, Director View) | Week 2 | **P1**   | ForecastController @AuraEnabled API (done)                                                           |
| F-8  | Filter Panel + Summary Table + Pagination       | Week 2 | **P1**   | ForecastQueryRequest DTO (done)                                                                      |
| F-9  | LWC Inline Estimator                            | Week 3 | **P1**   | AttainmentDTO in participant context (done). Client-side JS tier calculation using cached plan data. |
| F-10 | Period Picker + Scope Selector                  | Week 2 | **P1**   | ForecastConfigDTO.periods + ForecastParticipantContextDTO.availableScopes (done)                     |

### 1.3 Batch Jobs — Partial

| #    | Feature                 | Status      | Priority | Notes                                                              |
| ---- | ----------------------- | ----------- | -------- | ------------------------------------------------------------------ |
| F-11 | `HealthScoreBatch`      | Not started | **P2**   | Nightly refresh of Deal_Signal\_\_c health scores                  |
| F-12 | `ManagerAccuracyBatch`  | Not started | **P3**   | Weekly: compare forecast snapshots to actuals for accuracy scoring |
| F-13 | `ForecastAccuracyBatch` | Not started | **P3**   | Populates Forecast_Accuracy\_\_c for F-3                           |

---

## 2. Incentives / Commissions Module

### 2.1 Apex — Deferred

| #   | Feature                                                | Spec Ref                            | Priority | Notes                                                                                                                                                   |
| --- | ------------------------------------------------------ | ----------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I-1 | `CommissionEventHandler.handleRevRecPosted()` overload | COMMISSION_EVENT_ROUTING §Phase 2   | **P2**   | TODO in code (line 503). Needs filter to Revenue_Recognition plans only.                                                                                |
| I-2 | Line-item level commissioning                          | INCENTIVES_OBJECT_MODEL §DP-I       | **P3**   | V2 consideration: each OLI commissioned independently at product-specific rate. Currently plan-level only.                                              |
| I-3 | `Incentive_Snapshot__c` object                         | INCENTIVES_OBJECT_MODEL §DP-I3      | **P3**   | Not for V1. Forecasting module's `Forecast_Snapshot__c` covers attainment at snapshot time. Add later if historical incentive state queries are needed. |
| I-4 | Recoverable draw / advance against future earnings     | INCENTIVES_OBJECT_MODEL §onboarding | **P3**   | Draw mechanism where advance is repaid from commissions. Needs `Draw_Balance__c` tracking.                                                              |
| I-5 | `Payment_Schedule__c` vesting/deferred installments    | INCENTIVES_OBJECT_MODEL §Payment    | **P2**   | Object deployed but no Apex service. Tracks individual vesting installments per `Comp_Calculation__c`.                                                  |
| I-6 | Role-based eligibility on forecast templates           | INCENTIVES_OBJECT_MODEL §future     | **P3**   | Incentives module has `Role_Eligibility__c` junction. Forecasting should adopt same pattern when role-based forecast template filtering is needed.      |

### 2.2 LWC Components — Not Yet Built

| #    | Feature                                                                                                                                                                         | Week     | Priority | Dependencies                                                                                  |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- | --------------------------------------------------------------------------------------------- |
| I-7  | **LWC Rep Commission Portal** — earnings summary, attainment gauges, per-deal commission trace, payout timeline, plan acceptance, dispute filing                                | Week 3   | **P1**   | CommissionService (done), PayrollRestApi (done)                                               |
| I-8  | **LWC Admin Commission Dashboard** — all calculations view, status filters (Projected/Validated/Paid/Disputed), CSV export, processing panel, batch trigger, failed event queue | Week 3   | **P1**   | CommissionService (done), CalculationInvalidationService (done)                               |
| I-9  | **LWC Plan Designer** — template builder, tier/rate editor, quota assignment, cap configuration, eligibility rules, formula builder (integrates FormulaEvaluator)               | Week 3-4 | **P1**   | Incentive_Plan_Template**c (deployed), Commission_Tier**c (deployed), FormulaEvaluator (done) |
| I-10 | **LWC Plan Approval Flow** — exec review screen, multi-approver routing (serial/parallel), simulation preview, comment/reject UI                                                | Week 6   | **P2**   | Plan_Approval**c (deployed), Comp_Plan**c lifecycle fields (deployed)                         |
| I-11 | **LWC Plan Acceptance Flow** — participant acceptance, digital signature capture, dispute/counter, acknowledgement tracking                                                     | Week 6   | **P2**   | Plan_Acceptance\_\_c (deployed), acceptance mode config (Hard/Soft/None)                      |
| I-12 | **LWC Calculation Trace Viewer** — per-deal commission breakdown, tier progression, cap application, formula evaluation trace                                                   | Week 3   | **P1**   | CommissionService calculation trace (done)                                                    |
| I-13 | **LWC Quota Management** — bulk quota assignment, mid-year adjustment workflow, territory-based distribution                                                                    | Week 4   | **P2**   | Quota\_\_c (deployed), bulk adjustment workflow                                               |
| I-14 | **LWC Clawback Review Queue** — admin review of clawback evaluations, approve/deny/modify, impact preview                                                                       | Week 4   | **P2**   | Clawback_Policy**c (deployed), Failed_Event**c alert queue (done)                             |
| I-15 | **LWC Failed Event Queue** — admin triage of all 27 alert types, resolution workflow, bulk actions                                                                              | Week 4   | **P1**   | CommissionEventHandler (done), Failed_Event\_\_c (deployed)                                   |
| I-16 | **LWC Deal Credit Split Manager** — split creation/editing, approval workflow, percentage validation                                                                            | Week 4   | **P2**   | DealCreditSplitHandler (done), Deal_Credit_Split\_\_c (deployed)                              |
| I-17 | **LWC Commission Statements** — period-end statement generation, PDF export, delivery tracking                                                                                  | Week 5   | **P2**   | PayrollRestApi (done), Comp_Calculation\_\_c (deployed)                                       |

### 2.3 Tests — Failing

| #    | Issue                              | Priority | Notes                                                                                               |
| ---- | ---------------------------------- | -------- | --------------------------------------------------------------------------------------------------- |
| I-18 | 2 `CommissionServiceTest` failures | **P1**   | Test expectations need updating after engine rewrite. Assertions mismatch on new calculation logic. |

---

## 3. Health & Behavior Intelligence Module

### 3.1 Apex — Not Yet Built (Objects Deployed)

| #   | Feature                                        | Spec Ref                             | Priority | Notes                                                                                                            |
| --- | ---------------------------------------------- | ------------------------------------ | -------- | ---------------------------------------------------------------------------------------------------------------- |
| H-1 | `HealthScoreCalculator.cls`                    | HEALTH_AND_BEHAVIOR_OBJECT_MODEL     | **P2**   | Core scoring engine. Objects deployed (15 objects, 225 fields). No Apex yet.                                     |
| H-2 | CRM Signal Adapter                             | HEALTH_AND_BEHAVIOR_OBJECT_MODEL     | **P2**   | Abstract adapter pattern for CRM data → Deal_Signal\_\_c                                                         |
| H-3 | `SignalEventHandler.cls` — full implementation | Deployed as stub                     | **P2**   | Currently stub with debug logging only. Needs signal processing logic.                                           |
| H-4 | `Behavioral_Flag__c` lifecycle management      | HEALTH_AND_BEHAVIOR_OBJECT_MODEL §DP | **P2**   | Full lifecycle: flag creation, review, resolution, escalation                                                    |
| H-5 | `Deal_Signal_Snapshot__c` object               | HEALTH_AND_BEHAVIOR_OBJECT_MODEL §V2 | **P4**   | V2 consideration: historical signal replay. Not required for V1 unless customers need temporal signal analytics. |

### 3.2 LWC Components — Not Yet Built

| #   | Feature                           | Week   | Priority | Dependencies                                             |
| --- | --------------------------------- | ------ | -------- | -------------------------------------------------------- |
| H-6 | LWC Health Badge + Conflict Alert | Week 4 | **P2**   | HealthScoreCalculator (H-1), Deal_Signal\_\_c (deployed) |
| H-7 | LWC Manager Decision Cockpit      | Week 5 | **P2**   | Forecast Grid (F-7), Health Badge (H-6), incentive data  |

---

## 4. Cross-Module / Platform

### 4.1 Governance Engine

| #   | Feature                                            | Spec Ref                | Priority | Notes                                                                                                                 |
| --- | -------------------------------------------------- | ----------------------- | -------- | --------------------------------------------------------------------------------------------------------------------- |
| X-1 | `GovernanceEngine.cls` — full rule evaluation      | Forecast spec §5, §11.6 | **P2**   | Currently stub. Needs CG-1 through CG-7 comp-aware governance rules. Handler routing done; evaluation logic deferred. |
| X-2 | `GovernanceEventHandler.cls` — full implementation | Deployed as stub        | **P2**   | Currently stub with debug logging. Needs actual rule processing, severity classification, reviewer assignment.        |

### 4.2 Notifications

| #   | Feature                                            | Week   | Priority | Notes                                                                                      |
| --- | -------------------------------------------------- | ------ | -------- | ------------------------------------------------------------------------------------------ |
| X-3 | Notification Service (in-app, email, Slack, Teams) | Week 6 | **P2**   | `CustomNotificationType` used for submit notification. Full multi-channel delivery needed. |
| X-4 | Slack/Teams Integration                            | Week 8 | **P3**   | `SlackService.cls`, `TeamsService.cls`                                                     |

### 4.3 Signal / Adapter Architecture

| #   | Feature                                           | Week   | Priority | Notes                                                 |
| --- | ------------------------------------------------- | ------ | -------- | ----------------------------------------------------- |
| X-5 | Abstract Signal Adapter + CRM Adapter + Gong stub | Week 7 | **P3**   | Pluggable adapter pattern for external signal sources |

### 4.4 Batch Jobs — Remaining

| #   | Feature                   | Status      | Priority | Notes                                               |
| --- | ------------------------- | ----------- | -------- | --------------------------------------------------- |
| X-6 | `MonthlyProcessingBatch`  | Not started | **P1**   | End-of-month commission processing, period rollover |
| X-7 | `HoldExpirationBatch`     | Done        | --       | Implemented                                         |
| X-8 | `ActivityCommissionBatch` | Done        | --       | Implemented                                         |

### 4.5 Onboarding & Configuration

| #    | Feature                              | Spec Ref      | Priority | Notes                                                                                                                                                                |
| ---- | ------------------------------------ | ------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-9  | Onboarding Setup Wizard (LWC Flow)   | All specs     | **P1**   | Org discovery, terminal stage capture, hierarchy source selection, metric/category setup, period generation, participant initialization. Every spec references this. |
| X-10 | Industry template seeding via wizard | Scripts exist | **P2**   | `seedIndustryTemplates.apex` (23 templates) and `seedCalculationTemplates.apex` (10 templates) exist as anonymous Apex. Need LWC integration.                        |

---

## 5. Packaging & Distribution

| #   | Feature                         | Priority | Notes                                                                                                                                                    |
| --- | ------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P-1 | Migrate from 1GP to 2GP         | **P2**   | Currently 1GP on Dev Edition. Need Dev Hub org for 2GP. REVT namespace registered.                                                                       |
| P-2 | Extension pack for Team Selling | **P2**   | `extensions/team-selling/` created with triggers for OpportunitySplit/OpportunityTeamMember. Subscriber post-install.                                    |
| P-3 | Permission Set refinement       | **P2**   | `RevenueTrust_Full_Access` is a single monolithic permission set (5,268 lines). Should split into module-level permission sets for customer flexibility. |

---

## Summary by Priority

| Priority | Count | Description                                                                                                                                                                                                                                                                                                |
| -------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **P1**   | 14    | Must ship for GA: Stage filter fix, LWC Forecast Grid/Filter/Estimator/Period Picker, LWC Rep Commission Portal, LWC Admin Commission Dashboard, LWC Plan Designer, LWC Calculation Trace, LWC Failed Event Queue, Monthly Batch, Onboarding Wizard, 2 test fixes                                          |
| **P2**   | 27    | Enterprise readiness: reopenPeriod, territory scope, custom pipeline objects, all Health & Behavior Apex, Governance Engine, Notifications, LWC Plan Approval/Acceptance flows, Quota Management, Clawback Review Queue, Deal Credit Split Manager, Commission Statements, Payment Schedule, 2GP migration |
| **P3**   | 9     | V2 backlog: AI predicted, manager accuracy, line-item commissions, Incentive Snapshot, recoverable draw, Signal Adapters, Slack/Teams                                                                                                                                                                      |
| **P4**   | 1     | Exploratory: Deal_Signal_Snapshot\_\_c                                                                                                                                                                                                                                                                     |

---

_RevenueTrust Deferred Features V1.1 — April 14, 2026_  
_51 items tracked. 14 P1, 27 P2, 9 P3, 1 P4._
