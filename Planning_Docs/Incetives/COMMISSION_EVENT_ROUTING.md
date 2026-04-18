# RevenueTrust — Commission Event Routing Matrix

**Version:** 2.6  
**Date:** April 14, 2026  
**Source:** CommissionEventHandler.cls + Architecture Feedback (4 rounds) + Full Implementation  
**Status:** 43/45 event types operationally complete. 2/45 handler-ready (Team Selling extension). 27 alert types. 4 families. Any-object commissioning via PipelineObjectService. Custom formula engine via FormulaEvaluator.

---

## 1. Deal Lifecycle State Machine

```
                    DEAL_CLOSED                      DEAL_LOST
        Open ──────────────────► Won ──────────────────────────► Lost
         ▲                        │                               │
         │         DEAL_REOPENED  │            DEAL_REOPENED       │
         │◄───────────────────────┘◄──────────────────────────────┘
         │
         │  DEAL_CLOSED (re-close)
         └────────────────────────► Won (2nd+ close)
```

**All transitions detected by:** `OpportunityCommissionTriggerHandler.cls`  
**All transitions processed by:** `CommissionEventHandler.cls`  
**Stage configuration:** `Incentive_Configuration__c.Won_Stages__c` / `Lost_Stages__c`  
**Kill switch:** `Trigger_Control__mdt` per trigger

---

## 2. Event Types Published by Trigger Handler

| Event Type                      | Trigger Condition                                 | Previous_Value            | New_Value             |
| ------------------------------- | ------------------------------------------------- | ------------------------- | --------------------- |
| `DEAL_CLOSED`                   | Stage moved TO a configured Won stage             | Old stage name            | New stage name (won)  |
| `DEAL_LOST`                     | Stage moved TO a configured Lost stage            | Old stage name            | New stage name (lost) |
| `DEAL_REOPENED`                 | Stage moved FROM Won or Lost TO an open stage     | Old stage name (won/lost) | New stage name (open) |
| `AMOUNT_CHANGED`                | Amount changed while deal is in an open stage     | Old amount                | New amount            |
| `AMOUNT_CHANGED_POST_CLOSE`     | Amount changed while deal is in a Won stage       | Old amount                | New amount            |
| `CLOSE_DATE_CHANGED`            | Close date changed while deal is in an open stage | Old date                  | New date              |
| `CLOSE_DATE_CHANGED_POST_CLOSE` | Close date changed while deal is in a Won stage   | Old date                  | New date              |
| `STAGE_CHANGED`                 | Non-terminal stage change (open → open)           | Old stage                 | New stage             |

---

## 3. DEAL_CLOSED — Complete Routing

### 3.1 First-Time Close (No Prior Commission History)

```
Path:      Open → Won (first time)
Calcs:     None
Action:    CommissionService.processOpportunity() — full 7-step calculation
Result:    Comp_Calculation__c records created with Calculation_Status = 'Projected'
```

### 3.2 Re-Close After Reopen — Projected Only

```
Path:      Open → Won → Reopened → Won
Calcs:     Projected only (from original close, not yet validated)
Action:    Delete all Projected → recalculate fresh
Result:    New Projected Comp_Calculation__c records at current values
```

### 3.3 Re-Close After Reopen — Same Amount & Period

```
Path:      Open → Won → Reopened → Won (amount unchanged, same period)
Calcs:     Validated/Paid originals exist
Action:    No action. Originals are still valid.
Result:    Log for audit. No new records.
Alert:     None
```

### 3.4 Re-Close After Reopen — Amount or Period Changed (Not Frozen)

```
Path:      Open → Won ($500K) → Reopened → Won ($420K)
           OR: Won (April close) → Reopened → Won (May close, different period)
Calcs:     Validated/Paid originals at old amount/period
Frozen:    No — original period still open
Action:    Alert admin: RECLOSE_DELTA_REPROCESSING
Result:    Failed_Event__c created. Admin triggers manual reprocessing:
           → System creates Reversal records (negative of originals)
           → System creates new Original records at current values
           → Net delta visible in admin dashboard
```

### 3.5 Re-Close After Reopen — Amount or Period Changed (Frozen Period)

```
Path:      Open → Won ($500K, Q1) → Reopened → Won ($420K, Q2)
           Original commissions in Q1 which is now Frozen
Calcs:     Validated/Paid originals in frozen Q1
Frozen:    Yes — Q1 is frozen
Action:    Alert admin: RECLOSE_FROZEN_PERIOD_ADJUSTMENT
Result:    Failed_Event__c created. Admin creates ADJUSTMENT entries in
           current period for the delta ($80K reduction).
           Frozen Q1 entries remain untouched.
```

### 3.6 Re-Close After Clawback (Won → Lost → Reopened → Won)

```
Path:      Open → Won (calcs created) → Lost (clawback processed) → Reopened → Won
Calcs:     Original + Clawback entries exist
Action:    Alert admin: RECLOSE_AFTER_CLAWBACK
Result:    Failed_Event__c created. Admin must:
           1. Reverse the clawback (create Reversal of the Clawback)
           2. Recalculate commissions at current values
           3. Potentially different amount/period than original
```

---

## 4. DEAL_LOST — Complete Routing

### Key Principle: Check Commission HISTORY, Not Previous Stage

The previous stage (from the event) only tells you the immediate transition. For the path Won→Reopened→Lost, the previous stage is an Open stage — but Validated/Paid commissions from the original close still exist. **The ledger is the source of truth.**

### 4.1 Direct Won → Lost (Validated/Paid, Not Frozen)

```
Path:      Open → Won (commissions calculated + validated) → Lost
Calcs:     Validated/Paid originals
Frozen:    No
Action:    Alert admin: CLAWBACK_EVALUATION_REQUIRED
Result:    Failed_Event__c created. Admin evaluates Clawback_Policy__c:
           - Full clawback → 100% recovery
           - Time-decayed → recovery % based on days since commission
           - Partial → fixed % recovery
           - Grace period → no clawback if within grace window
           System creates Clawback Comp_Calculation__c records (negative amounts)
```

### 4.2 Direct Won → Lost (Validated/Paid, Frozen Period)

```
Path:      Open → Won (Q1, commissions validated) → Lost (Q2, Q1 now frozen)
Calcs:     Validated/Paid originals in frozen Q1
Frozen:    Yes
Action:    Alert admin: CLAWBACK_FROZEN_PERIOD
Result:    Failed_Event__c created. Admin creates clawback entries as
           ADJUSTMENT records in the current period (Q2).
           Frozen Q1 entries remain untouched.
```

### 4.3 Won → Reopened → Lost (Validated/Paid, Not Frozen)

```
Path:      Open → Won (commissions) → Reopened (admin review) → Lost
Calcs:     Validated/Paid originals from the Won phase
Frozen:    No
Action:    Alert admin: CLAWBACK_EVALUATION_REQUIRED (same as 4.1)
Result:    Same as direct Won→Lost. Commission history determines action,
           not the intermediate Reopened stage.
```

### 4.4 Won → Reopened → Lost (Validated/Paid, Frozen Period)

```
Path:      Open → Won (Q1) → Reopened (Q2) → Lost (Q2, Q1 frozen)
Calcs:     Validated/Paid originals in frozen Q1
Frozen:    Yes
Action:    Alert admin: CLAWBACK_FROZEN_PERIOD (same as 4.2)
Result:    Same as direct Won→Lost with frozen period.
```

### 4.5 Won → Lost (Projected Only)

```
Path:      Open → Won (commissions projected but not validated) → Lost
Calcs:     Projected only
Action:    Delete all Projected Comp_Calculation__c records
Result:    Clean slate. No clawback needed — nothing was earned.
Alert:     None
```

### 4.6 Open → Lost (Never Closed)

```
Path:      Open → Lost (deal never won)
Calcs:     Projected from pipeline projections (if any), or None
Action:    Delete any Projected records. No clawback.
Result:    Clean. No commission action.
Alert:     None
```

### 4.7 Open → Lost (No Commission History)

```
Path:      Open → Lost
Calcs:     None
Action:    No action
Result:    Nothing to do
Alert:     None
```

---

## 5. DEAL_REOPENED — Complete Routing

### 5.1 Won → Reopened (Validated/Paid, Not Frozen)

```
Path:      Open → Won (commissions validated/paid) → Reopened
Calcs:     Validated/Paid originals
Frozen:    No
Action:    Alert admin: DEAL_REOPENED_REVIEW_REQUIRED
Result:    Failed_Event__c created. Admin decides:
           - Hold commissions pending outcome
           - Reverse commissions proactively
           - Keep commissions (if reopening is administrative)
```

### 5.2 Won → Reopened (Validated/Paid, Frozen Period)

```
Path:      Open → Won (Q1, commissions paid) → Reopened (Q2, Q1 frozen)
Calcs:     Validated/Paid originals in frozen Q1
Frozen:    Yes
Action:    Alert admin: DEAL_REOPENED_FROZEN_PERIOD
Result:    Failed_Event__c created. Admin knows frozen entries can't be modified.
           Any corrections must be adjustment entries in current period.
```

### 5.3 Won → Reopened (Projected Only)

```
Path:      Open → Won (projected, not yet validated) → Reopened
Calcs:     Projected only
Action:    Delete all Projected Comp_Calculation__c records
Result:    Clean slate — deal is back in open pipeline
Alert:     None
```

### 5.4 Lost → Reopened (After Clawback — Won→Lost→Reopened)

```
Path:      Open → Won (commissions) → Lost (clawback processed) → Reopened
Calcs:     Original + Clawback entries
Action:    Alert admin: CLAWBACK_REVERSAL_REVIEW
Result:    Failed_Event__c created. Admin reviews:
           - If deal is likely to re-close: reverse the clawback
           - If uncertain: wait for re-close before reversing
           Deal is back in pipeline — no new commission action until re-close.
```

### 5.5 Lost → Reopened (Open→Lost→Reopened, No Prior Commissions)

```
Path:      Open → Lost → Reopened
Calcs:     None (or Projected that were already deleted on Lost)
Action:    Delete any remaining Projected. No other action.
Result:    Deal is back in pipeline. Standard flow resumes.
Alert:     None
```

---

## 6. POST-CLOSE CHANGES — Complete Routing

### 6.1 Amount Changed After Close (Validated/Paid Exist)

```
Event:     AMOUNT_CHANGED_POST_CLOSE
Calcs:     Validated/Paid originals at old amount
Action:    Alert admin: AMOUNT_CHANGED_POST_CLOSE
Result:    Failed_Event__c created. Admin triggers reprocessing.
```

### 6.2 Amount Changed After Close (Projected Only)

```
Event:     AMOUNT_CHANGED_POST_CLOSE
Calcs:     Projected only
Action:    Delete Projected → recalculate at new amount
Result:    New Projected records at updated amount
Alert:     None
```

### 6.3 Close Date Changed After Close (Validated/Paid Exist)

```
Event:     CLOSE_DATE_CHANGED_POST_CLOSE
Calcs:     Validated/Paid originals at old close date
Action:    Alert admin: CLOSE_DATE_CHANGED_POST_CLOSE
Result:    Failed_Event__c created. If date moves to different fiscal period,
           this may affect attainment, rate tier, and payout period.
           Admin must evaluate impact and trigger reprocessing.
```

### 6.4 Close Date Changed After Close (Projected Only)

```
Event:     CLOSE_DATE_CHANGED_POST_CLOSE
Calcs:     Projected only
Action:    Delete Projected → recalculate with new date
Result:    New Projected records with updated period assignment
Alert:     None
```

### 6.5 Amount Changed (Pre-Close)

```
Event:     AMOUNT_CHANGED
Calcs:     May have Projected from pipeline projections
Action:    Delete Projected → (future: recalculate projections)
Result:    Updated projections reflect new amount
Alert:     None
```

### 6.6 Close Date Changed (Pre-Close)

```
Event:     CLOSE_DATE_CHANGED
Calcs:     May have Projected with period assignment
Action:    Delete Projected → (future: recalculate with new period)
Result:    Updated period assignment
Alert:     None
```

### 6.7 Stage Changed (Pre-Close, Non-Terminal)

```
Event:     STAGE_CHANGED
Calcs:     May have Projected
Action:    Delete Projected → (future: recalculate if stage-dependent logic exists)
Result:    Projections recalculated
Alert:     None
```

---

## 7. Alert Types Summary

| Alert Type                         | Created By            | Scenario                                           | Admin Action Required                                        |
| ---------------------------------- | --------------------- | -------------------------------------------------- | ------------------------------------------------------------ |
| `CLAWBACK_EVALUATION_REQUIRED`     | handleDealLost        | Won→Lost with Validated/Paid calcs (not frozen)    | Evaluate Clawback_Policy\_\_c rules, create Clawback entries |
| `CLAWBACK_FROZEN_PERIOD`           | handleDealLost        | Won→Lost with calcs in frozen period               | Create clawback as Adjustment in current period              |
| `CLAWBACK_REVERSAL_REVIEW`         | handleDealReopened    | Lost→Reopened after clawback was processed         | Decide whether to reverse the clawback                       |
| `DEAL_REOPENED_REVIEW_REQUIRED`    | handleDealReopened    | Won→Reopened with Validated/Paid (not frozen)      | Decide: hold, reverse, or keep commissions                   |
| `DEAL_REOPENED_FROZEN_PERIOD`      | handleDealReopened    | Won→Reopened with calcs in frozen period           | Any corrections as adjustments in current period             |
| `RECLOSE_AFTER_CLAWBACK`           | handleDealClosed      | Won→Lost→Reopened→Won (clawback exists)            | Reverse clawback + recalculate commissions                   |
| `RECLOSE_DELTA_REPROCESSING`       | handleDealClosed      | Won→Reopened→Won with changed amount/period        | Trigger reprocessing (reversal + new calculation)            |
| `RECLOSE_FROZEN_PERIOD_ADJUSTMENT` | handleDealClosed      | Won→Reopened→Won with calcs in frozen period       | Create adjustment entries in current period                  |
| `AMOUNT_CHANGED_POST_CLOSE`        | handlePostCloseChange | Amount changed on closed deal (Validated/Paid)     | Evaluate impact, trigger reprocessing                        |
| `CLOSE_DATE_CHANGED_POST_CLOSE`    | handlePostCloseChange | Close date changed on closed deal (Validated/Paid) | Evaluate period impact, trigger reprocessing                 |

> **Note:** This table shows Phase 1A alerts only (10 types). For the complete alert registry including Phases 1B–2 (27 total), see §11.5.

---

## 8. Complete Scenario Matrix (All 22 Paths)

| #                      | Event                         | Path                          | Calcs Exist | Type     | Frozen?          | Action                                  |
| ---------------------- | ----------------------------- | ----------------------------- | ----------- | -------- | ---------------- | --------------------------------------- |
| **DEAL_CLOSED**        |                               |                               |             |          |                  |                                         |
| 1                      | DEAL_CLOSED                   | Open → Won (first)            | None        | —        | —                | Standard calculation                    |
| 2                      | DEAL_CLOSED                   | Reopen → Won (re-close)       | Projected   | —        | —                | Delete + recalculate                    |
| 3                      | DEAL_CLOSED                   | Reopen → Won (re-close)       | Val/Paid    | Original | Same amt/period  | No action                               |
| 4                      | DEAL_CLOSED                   | Reopen → Won (re-close)       | Val/Paid    | Original | No, amt changed  | Alert: RECLOSE_DELTA_REPROCESSING       |
| 5                      | DEAL_CLOSED                   | Reopen → Won (re-close)       | Val/Paid    | Original | Yes, amt changed | Alert: RECLOSE_FROZEN_PERIOD_ADJUSTMENT |
| 6                      | DEAL_CLOSED                   | Won→Lost→Reopen→Won           | Clawback    | —        | —                | Alert: RECLOSE_AFTER_CLAWBACK           |
| **DEAL_LOST**          |                               |                               |             |          |                  |                                         |
| 7                      | DEAL_LOST                     | Won → Lost (direct)           | Val/Paid    | Original | No               | Alert: CLAWBACK_EVALUATION_REQUIRED     |
| 8                      | DEAL_LOST                     | Won → Lost (direct)           | Val/Paid    | Original | Yes              | Alert: CLAWBACK_FROZEN_PERIOD           |
| 9                      | DEAL_LOST                     | Won → Reopen → Lost           | Val/Paid    | Original | No               | Alert: CLAWBACK_EVALUATION_REQUIRED     |
| 10                     | DEAL_LOST                     | Won → Reopen → Lost           | Val/Paid    | Original | Yes              | Alert: CLAWBACK_FROZEN_PERIOD           |
| 11                     | DEAL_LOST                     | Won → Lost                    | Projected   | —        | —                | Delete projected                        |
| 12                     | DEAL_LOST                     | Open → Lost                   | Projected   | —        | —                | Delete projected                        |
| 13                     | DEAL_LOST                     | Open → Lost                   | None        | —        | —                | No action                               |
| **DEAL_REOPENED**      |                               |                               |             |          |                  |                                         |
| 14                     | DEAL_REOPENED                 | Won → Reopened                | Val/Paid    | —        | No               | Alert: DEAL_REOPENED_REVIEW_REQUIRED    |
| 15                     | DEAL_REOPENED                 | Won → Reopened                | Val/Paid    | —        | Yes              | Alert: DEAL_REOPENED_FROZEN_PERIOD      |
| 16                     | DEAL_REOPENED                 | Won → Reopened                | Projected   | —        | —                | Delete projected                        |
| 17                     | DEAL_REOPENED                 | Lost → Reopened (clawback)    | Clawback    | —        | —                | Alert: CLAWBACK_REVERSAL_REVIEW         |
| 18                     | DEAL_REOPENED                 | Lost → Reopened (no clawback) | None/Proj   | —        | —                | Delete projected                        |
| **POST-CLOSE CHANGES** |                               |                               |             |          |                  |                                         |
| 19                     | AMOUNT_CHANGED_POST_CLOSE     | Amount changed (closed)       | Val/Paid    | —        | —                | Alert: AMOUNT_CHANGED_POST_CLOSE        |
| 20                     | AMOUNT_CHANGED_POST_CLOSE     | Amount changed (closed)       | Projected   | —        | —                | Delete + recalculate                    |
| 21                     | CLOSE_DATE_CHANGED_POST_CLOSE | Date changed (closed)         | Val/Paid    | —        | —                | Alert: CLOSE_DATE_CHANGED_POST_CLOSE    |
| 22                     | CLOSE_DATE_CHANGED_POST_CLOSE | Date changed (closed)         | Projected   | —        | —                | Delete + recalculate                    |

---

## 9. Design Principles

1. **The ledger is the source of truth, not the stage transition.** Previous stage tells you the immediate transition; `Comp_Calculation__c` history tells you the financial reality.

2. **Projected records are provisional.** They can be deleted and recreated freely (spec §11.3).

3. **Validated/Paid records are immutable.** Changes are made via Reversal + new Original records, never by modifying existing records (spec §1.5.4).

4. **Frozen period entries cannot be modified.** Any corrections must be Adjustment entries in the current period.

5. **Complex scenarios create admin alerts, not automatic actions.** When Validated/Paid commissions are at risk, the system flags the situation in `Failed_Event__c` for human review rather than making irreversible financial changes automatically.

6. **Clawback follows policy rules.** `Clawback_Policy__c` defines: full/time-decayed/partial recovery, grace period, affects-attainment flag. The system evaluates the policy but the admin confirms before processing.

---

## 10. Safety Mechanisms

| Mechanism                    | Object                                                    | Purpose                                                                   |
| ---------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------- |
| **Trigger kill switch**      | `Trigger_Control__mdt`                                    | Disable any trigger without code deployment                               |
| **Configurable stages**      | `Incentive_Configuration__c.Won_Stages__c/Lost_Stages__c` | Not hardcoded "Closed Won" — supports any org's stage names               |
| **Admin alerts**             | `Failed_Event__c`                                         | Complex scenarios flagged for human review, not auto-processed            |
| **Immutable ledger**         | `Comp_Calculation__c`                                     | Validated/Paid records never modified; changes via Reversal + new records |
| **Frozen period protection** | `Forecast_Period__c.Status__c = 'Frozen'`                 | Historical financial data cannot be silently changed                      |
| **Audit trail**              | `Incentive_Change_Event__c`                               | Every commission lifecycle event logged for compliance                    |

---

## 11. AUTHORITATIVE EVENT FRAMEWORK

This section is the **single source of truth** for the event model. Implementers should reference ONLY this section.

> **Taxonomy freeze governance:** Any future change to event types, alert types, family membership, source ownership, or completeness counts MUST update ALL of: §11.4 event registry, §11.5 alert registry, §11.7 phase summary, §12.3 ingestion inventory, and the document footer. No partial updates. No definitions duplicated in implementation plans, backlog docs, or module notes — reference §11 only.

### 11.1 The Four Event Families

| Family | Name                                     | What Changed                                                                 | Source                                              |
| ------ | ---------------------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------------- |
| **A**  | **Deal Lifecycle**                       | Stage transitions (close, lost, reopen)                                      | Opportunity trigger                                 |
| **B**  | **Deal Value & Timing**                  | Amount, close date, product mix, currency, quota credit, revenue recognition | Opportunity trigger + OLI trigger + Rev Rec trigger |
| **C**  | **Credit, Eligibility & Classification** | Who gets paid, which plan applies, what type of deal                         | Opportunity trigger + Team/Split trigger            |
| **D**  | **Administrative, Policy & Ledger**      | Rule changes, manual adjustments, holds, period transitions                  | Admin actions + config triggers + batch jobs        |

---

### 11.2 Naming Conventions

> **Events** describe facts: `{THING}_{WHAT_HAPPENED}` — e.g., `DEAL_CLOSED`, `OWNER_CHANGED`  
> **Alerts** describe required action: `{CONTEXT}_{ACTION_NEEDED}` — e.g., `CLAWBACK_EVALUATION_REQUIRED`

### 11.3 Key Design Rules

1. **PARTICIPANT_SET_CHANGED canonical abstraction:** Owner, team, split, territory changes are low-level audit events that normalize to one canonical routing: `handleParticipantSetChanged()`. Routing: Projected → recalc. Validated/Paid → alert. Frozen → adjustment only.

2. **Single event type for open + closed:** Events like `PRODUCT_MIX_CHANGED` and `RECORD_TYPE_CHANGED` fire on both open and closed deals. Routing branches by stage + calc status — no separate `_POST_CLOSE` variant needed for these.

3. **Hold and Calculation are independent dimensions:** `Calculation_Status__c` (Projected→Validated→Paid) and `Hold_Status__c` (Not_Held→Held→Released) are parallel. A record can be `Validated + Held`. Calculation_Status does NOT change on hold.

4. **Trigger ownership — no cross-fire:** OLI trigger owns product mix events. Rev Rec trigger owns revenue schedule events. They do not cascade into each other (per §7.4.2 principle #5).

5. **Calculation invalidation requires impact preview + admin approval:** Rule/plan changes that affect Validated/Paid records must go through: detection → impact scope → admin preview → approval → execution.

6. **Attainment ripple boundaries:** Controlled by `Attainment_Recompute_Scope__c`: Current_Deal_Only, Participant_Period (default), Participant_Annual, Pool_Period, Manual_Only. Never auto-ripple into frozen periods or Paid calcs.

7. **Standard frozen-period pattern:** For ANY event where Validated/Paid calcs exist in a frozen period, use the frozen variant of the alert type. Admin creates adjustment entries in current period.

### 11.4 Complete Event Type Registry (45 types)

#### Family A: Deal Lifecycle (8 types — all Phase 1A ✅)

| #   | Event Type                      | Source      | Phase | Implemented |
| --- | ------------------------------- | ----------- | ----- | ----------- |
| 1   | `DEAL_CLOSED`                   | Opp trigger | 1A    | ✅          |
| 2   | `DEAL_LOST`                     | Opp trigger | 1A    | ✅          |
| 3   | `DEAL_REOPENED`                 | Opp trigger | 1A    | ✅          |
| 4   | `STAGE_CHANGED`                 | Opp trigger | 1A    | ✅          |
| 5   | `AMOUNT_CHANGED`                | Opp trigger | 1A    | ✅          |
| 6   | `AMOUNT_CHANGED_POST_CLOSE`     | Opp trigger | 1A    | ✅          |
| 7   | `CLOSE_DATE_CHANGED`            | Opp trigger | 1A    | ✅          |
| 8   | `CLOSE_DATE_CHANGED_POST_CLOSE` | Opp trigger | 1A    | ✅          |

#### Family B: Deal Value & Timing (5 types)

| #   | Event Type                  | Source                             | Status                  | Notes                                                                                                                                     |
| --- | --------------------------- | ---------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 9   | `PRODUCT_MIX_CHANGED`       | OLI trigger                        | ✅ Trigger + routing    | 6 subtypes: LINE_ADDED/REMOVED/REPLACED/REPRICED/REDATED/QUANTITY                                                                         |
| 10  | `QUOTA_CREDIT_CHANGED`      | Opp trigger (dynamic watch fields) | ✅ Trigger + routing    | Watch fields from Incentive_Configuration\_\_c                                                                                            |
| 11  | `REVENUE_RECOGNITION_EVENT` | CommissionEventHandler routing     | ✅ Routing (3 subtypes) | No dedicated Rev Rec object trigger — events created via API or admin action. Full routing for REV_REC_POSTED/CORRECTED/SCHEDULE_CHANGED. |
| 12  | `CURRENCY_CHANGED`          | Opp trigger                        | ✅ Trigger + routing    | Guarded by UserInfo.isMultiCurrencyOrganization()                                                                                         |
| 13  | `BOOKING_VALUE_RESTATED`    | CommissionEventHandler routing     | ✅ Routing only         | No trigger source — created by admin/finance action. Delegates to handlePostCloseChange.                                                  |

#### Family C: Credit, Eligibility & Classification (11 types)

| #   | Event Type                       | Source                             | Status               | Notes                                                                               |
| --- | -------------------------------- | ---------------------------------- | -------------------- | ----------------------------------------------------------------------------------- |
| 14  | `OWNER_CHANGED`                  | Opp trigger                        | ✅ Trigger + routing | → PARTICIPANT_SET_CHANGED canonical handler                                         |
| 15  | `OWNER_CHANGED_POST_CLOSE`       | Opp trigger                        | ✅ Trigger + routing | Same canonical handler                                                              |
| 16  | `RECORD_TYPE_CHANGED`            | Opp trigger                        | ✅ Trigger + routing | Dynamic RecordTypeId access, routes by stage                                        |
| 17  | `ELIGIBILITY_CHANGED`            | Opp trigger (dynamic watch fields) | ✅ Trigger + routing | Fields from Eligibility_Watch_Fields\_\_c config                                    |
| 18  | `ELIGIBILITY_CHANGED_POST_CLOSE` | Opp trigger                        | ✅ Trigger + routing |                                                                                     |
| 19  | `PROBABILITY_CHANGED`            | Opp trigger                        | ✅ Trigger + routing | Threshold crossing detection                                                        |
| 20  | `TERRITORY_CHANGED`              | Opp trigger (dynamic field)        | ✅ Trigger + routing | Field from Territory_Field\_\_c config                                              |
| 21  | `SPLIT_CHANGED`                  | Deal_Credit_Split\_\_c trigger     | ✅ Trigger + routing | Platform-owned splits (no Team Selling needed)                                      |
| 22  | `SPLIT_CHANGED_POST_CLOSE`       | Deal_Credit_Split\_\_c trigger     | ✅ Trigger + routing |                                                                                     |
| 23  | `TEAM_MEMBER_CHANGED`            | Extension trigger (post-install)   | ⚠ Handler ready      | Trigger requires Team Selling feature. Handler deployed, trigger in extension pack. |
| 24  | `TEAM_MEMBER_CHANGED_POST_CLOSE` | Extension trigger (post-install)   | ⚠ Handler ready      | Same — requires subscriber deployment                                               |

#### Family D: Administrative, Policy & Ledger (21 types)

| #   | Event Type                          | Source                         | Status                           | Notes                                                                            |
| --- | ----------------------------------- | ------------------------------ | -------------------------------- | -------------------------------------------------------------------------------- |
| —   | **Manual / Ledger**                 |                                |                                  |                                                                                  |
| 25  | `MANUAL_ADJUSTMENT_CREATED`         | IncentiveChangeEventService    | ✅ Routing + audit               | Logged when admin creates adjustment Comp_Calculation\_\_c                       |
| 26  | `MANUAL_ADJUSTMENT_REVERSED`        | IncentiveChangeEventService    | ✅ Routing + audit               |                                                                                  |
| 27  | `MANUAL_OVERRIDE_APPLIED`           | IncentiveChangeEventService    | ✅ Routing + audit               |                                                                                  |
| 28  | `CLAWBACK_CREATED`                  | IncentiveChangeEventService    | ✅ Routing + audit               |                                                                                  |
| 29  | `CLAWBACK_REVERSED`                 | IncentiveChangeEventService    | ✅ Routing + audit               |                                                                                  |
| 30  | `REVERSAL_CREATED`                  | IncentiveChangeEventService    | ✅ Routing + audit               |                                                                                  |
| 31  | `COMMISSION_HOLD_APPLIED`           | CommissionHoldService          | ✅ Service + audit               | applyHold() updates Hold_Status + logs event                                     |
| 32  | `COMMISSION_HOLD_RELEASED`          | CommissionHoldService          | ✅ Service + audit               | releaseHold() + CustomerPaymentRestApi                                           |
| 33  | `COMMISSION_HOLD_EXPIRED`           | HoldExpirationBatch            | ✅ Batch + audit                 | Scheduled detection of expired holds                                             |
| —   | **Calculation Invalidation**        |                                |                                  |                                                                                  |
| 34  | `CALCULATION_INVALIDATION_DETECTED` | Config object triggers (5)     | ✅ Triggers + service            | CalculationInvalidationService full implementation                               |
| 35  | `RETRO_RECALCULATION_APPROVED`      | CommissionEventHandler routing | ✅ Routing + audit               | Admin approval action routed for audit trail                                     |
| 36  | `PLAN_ASSIGNMENT_CHANGED`           | CompPlanTrigger                | ✅ Trigger + routing             | Template or status change detected                                               |
| 37  | `RATE_TABLE_CHANGED`                | CommissionTierTrigger          | ✅ Trigger + routing             |                                                                                  |
| 38  | `CAP_RULE_CHANGED`                  | PlanCapTrigger                 | ✅ Trigger + routing             |                                                                                  |
| 39  | `PRODUCT_ELIGIBILITY_RULE_CHANGED`  | ProductEligibilityTrigger      | ✅ Trigger + routing             |                                                                                  |
| 40  | `ROLE_ELIGIBILITY_RULE_CHANGED`     | RoleEligibilityTrigger         | ✅ Trigger + routing             |                                                                                  |
| —   | **Period & Policy**                 |                                |                                  |                                                                                  |
| 41  | `PERIOD_FROZEN`                     | ForecastPeriodTrigger          | ✅ Trigger + PeriodFreezeHandler | Full reclassification of unresolved alerts                                       |
| 42  | `CLAWBACK_POLICY_CHANGED`           | ClawbackPolicyTrigger          | ✅ Trigger + routing             | Routes to CalculationInvalidationService                                         |
| 43  | `PERIOD_REOPENED`                   | ForecastPeriodTrigger          | ✅ Trigger + event               | Published when status changes FROM Frozen                                        |
| 44  | `BOOKING_CANCELLED`                 | CommissionEventHandler routing | ✅ Routing only                  | No trigger source — created by admin action. Delegates to handleDealLost.        |
| 45  | `BOOKING_REDUCED`                   | CommissionEventHandler routing | ✅ Routing only                  | No trigger source — created by admin action. Delegates to handlePostCloseChange. |

### 11.5 Complete Alert Type Registry (27 types)

| #   | Alert Type                                      | Family | Trigger Context                                   | Phase    |
| --- | ----------------------------------------------- | ------ | ------------------------------------------------- | -------- |
| —   | **Deal Lifecycle Alerts (1A ✅)**               |        |                                                   |          |
| 1   | `CLAWBACK_EVALUATION_REQUIRED`                  | A      | Won→Lost, calcs exist, not frozen                 | 1A ✅    |
| 2   | `CLAWBACK_FROZEN_PERIOD`                        | A      | Won→Lost, calcs in frozen period                  | 1A ✅    |
| 3   | `CLAWBACK_REVERSAL_REVIEW`                      | A      | Lost→Reopened after clawback                      | 1A ✅    |
| 4   | `DEAL_REOPENED_REVIEW_REQUIRED`                 | A      | Won→Reopened, calcs exist, not frozen             | 1A ✅    |
| 5   | `DEAL_REOPENED_FROZEN_PERIOD`                   | A      | Won→Reopened, calcs in frozen period              | 1A ✅    |
| 6   | `RECLOSE_AFTER_CLAWBACK`                        | A      | Won→Lost→Reopen→Won, clawbacks exist              | 1A ✅    |
| 7   | `RECLOSE_DELTA_REPROCESSING`                    | A      | Re-close, amount/period changed, not frozen       | 1A ✅    |
| 8   | `RECLOSE_FROZEN_PERIOD_ADJUSTMENT`              | A      | Re-close, calcs in frozen period                  | 1A ✅    |
| 9   | `AMOUNT_CHANGED_POST_CLOSE`                     | A      | Amount changed on closed deal, calcs exist        | 1A ✅    |
| 10  | `CLOSE_DATE_CHANGED_POST_CLOSE`                 | A      | Close date changed on closed deal                 | 1A ✅    |
| —   | **Credit / Eligibility Alerts (1B)**            |        |                                                   |          |
| 11  | `CREDIT_REALLOCATION_REQUIRED`                  | C      | Participant set changed, calcs exist, not frozen  | 1B-Alpha |
| 12  | `CREDIT_REALLOCATION_FROZEN_PERIOD`             | C      | Participant set changed, calcs in frozen period   | 1B-Alpha |
| 13  | `COMMISSION_ELIGIBILITY_CHANGED_POST_CLOSE`     | C      | Eligibility field changed on closed deal          | 1B-Alpha |
| 14  | `TRANSACTION_CLASSIFICATION_CHANGED_POST_CLOSE` | C      | Record type changed on closed deal                | 1B-Alpha |
| 15  | `PRODUCT_ELIGIBILITY_CHANGED_POST_CLOSE`        | B      | Product mix changed on closed deal, not frozen    | 1B-Beta  |
| 16  | `PRODUCT_ELIGIBILITY_FROZEN_PERIOD`             | B      | Product mix changed on closed deal, frozen        | 1B-Beta  |
| 17  | `COMMISSION_ELIGIBILITY_FROZEN_PERIOD`          | C      | Eligibility field changed, calcs in frozen period | 1B-Alpha |
| 18  | `TRANSACTION_CLASSIFICATION_FROZEN_PERIOD`      | C      | Record type changed, calcs in frozen period       | 1B-Alpha |
| —   | **Quota / Attainment Alerts (1C)**              |        |                                                   |          |
| 19  | `QUOTA_CREDIT_CORRECTION_REQUIRED`              | B      | Quota credit field changed, calcs validated/paid  | 1C       |
| 20  | `ATTAINMENT_RECOMPUTE_REQUIRED`                 | B      | Quota credit change crosses tier boundary         | 1C       |
| —   | **Administrative Alerts (1C)**                  |        |                                                   |          |
| 21  | `RETRO_RECALCULATION_REVIEW_REQUIRED`           | D      | Rule/plan change affects existing calcs           | 1C       |
| 22  | `RULE_CHANGE_FROZEN_PERIOD_IMPACT`              | D      | Rule change affects frozen period calcs           | 1C       |
| 23  | `UNRESOLVED_EVENT_ENTERED_FROZEN_PERIOD`        | D      | Period frozen with pending alerts                 | 1C       |
| 24  | `REMEDIATION_PATH_CHANGED_DUE_TO_PERIOD_STATUS` | D      | Period status change affects alert remediation    | 1C       |
| 25  | `RETRO_RECALCULATION_APPROVED`                  | D      | Admin approved retro reprocessing                 | 1C       |
| 26  | `CASCADE_BOUNDARY_REACHED`                      | D      | Attainment ripple hit boundary                    | 1C       |
| 27  | `CALCULATION_INVALIDATION_DETECTED`             | D      | Rule/plan change detected                         | 1C       |

### 11.6 Config Fields Required

| Object                       | Field                           | Type                 | Purpose                                                                                              |
| ---------------------------- | ------------------------------- | -------------------- | ---------------------------------------------------------------------------------------------------- |
| `Incentive_Configuration__c` | `Attainment_Recompute_Scope__c` | Picklist             | Ripple boundary: Current_Deal_Only, Participant_Period, Participant_Annual, Pool_Period, Manual_Only |
| `Incentive_Configuration__c` | `Owner_Change_Policy__c`        | Picklist             | Credit_Stays_With_Closer, Credit_Transfers, Admin_Review_Required                                    |
| `Incentive_Configuration__c` | `Eligibility_Watch_Fields__c`   | LongTextArea(2000)   | Opp fields to monitor (include value-source fields from Commissionable_Value_Map\_\_c)               |
| `Incentive_Configuration__c` | `Quota_Credit_Watch_Fields__c`  | LongTextArea(1000)   | Opp fields used for quota credit                                                                     |
| `Incentive_Configuration__c` | `Territory_Field__c`            | Text(100)            | Which Opp field holds territory                                                                      |
| `Comp_Calculation__c`        | `Hold_Status__c`                | Picklist(restricted) | Not_Held, Held, Partially_Released, Released, Expired. Independent of Calculation_Status\_\_c.       |
| `Commission_Event__e`        | `Change_Subtype__c`             | Text(50)             | Semantic subtype (LINE_ADDED, REV_REC_POSTED, etc.)                                                  |

### 11.7 Implementation Phases

| Phase        | Scope                                                                           | Event Types | Status                                                                                                                                   |
| ------------ | ------------------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **1A**       | Deal lifecycle + basic economics                                                | 8 types     | ✅ Trigger + routing + full handler logic                                                                                                |
| **1B-Alpha** | Opp trigger: owner, record type, eligibility, PARTICIPANT_SET_CHANGED           | 5 types     | ✅ Trigger + routing                                                                                                                     |
| **1B-Beta**  | OLI trigger: product mix. Family D: ledger events, hold/release                 | 10 types    | ✅ Trigger + routing + services                                                                                                          |
| **1C**       | Quota credit, territory, probability, rev rec, calc invalidation, period freeze | 12 types    | ✅ Trigger + routing + services                                                                                                          |
| **2**        | Splits, teams, currency, booking cancel/reduce, policy changes                  | 10 types    | ✅ 8/10 fully implemented. 2 (TEAM_MEMBER) have handler + routing but trigger requires post-install extension (Team Selling dependency). |

**Implementation completeness summary:**

- **43 of 45 event types:** Operationally complete (source + routing + handling path implemented)
- **2 of 45 event types:** Routing + handler deployed, trigger source requires subscriber post-install (TEAM_MEMBER_CHANGED, TEAM_MEMBER_CHANGED_POST_CLOSE — requires Salesforce Team Selling feature)
- **Events with routing but no automatic trigger source** (admin-initiated): BOOKING_CANCELLED, BOOKING_REDUCED, BOOKING_VALUE_RESTATED, RETRO_RECALCULATION_APPROVED, REVENUE_RECOGNITION_EVENT — these are created by admin actions or external systems via API, not by Salesforce triggers. The routing is complete; the event production is intentionally manual/API-driven.

---

## Appendix: Evolution Changelog

| Version | Date   | Changes                                                                                                                                                                                                            |
| ------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| V1.0    | Apr 3  | Initial 22 scenarios, 10 alert types, 6 safety mechanisms                                                                                                                                                          |
| V2.0    | Apr 3  | Added 4 event families, expanded to 40 event types                                                                                                                                                                 |
| V2.1    | Apr 3  | Corrected taxonomy, PARTICIPANT_SET_CHANGED abstraction, calc invalidation workflow, attainment ripple boundaries, hold/release events, rev rec routing                                                            |
| V2.2    | Apr 3  | Product mix open/closed parity, hold/calc independent dimensions, trigger ownership, PROBABILITY moved to Family C                                                                                                 |
| V2.3    | Apr 3  | Consolidated §11-13 into single authoritative §11. Added frozen-period alert variants for all B/C events. 45 event types, 27 alert types.                                                                          |
| V2.4    | Apr 3  | ALL PHASES IMPLEMENTED. Deal_Credit_Split\_\_c replaces OpportunitySplit dependency. Split/team triggers available via extension pack. Updated implementation status to Complete across all phases.                |
| V2.5    | Apr 3  | Added §12: Activity commission event sources (Task/Event triggers + batch), external transaction import (REST APIs), customer payment API, payroll API. Complete trigger/handler/API inventory (23 event sources). |
| V2.6    | Apr 14 | Added §13: Pipeline Object Abstraction (PipelineObjectService + GenericCommissionTriggerHandler). All 45 event types work on any SObject. Custom Formula Engine (Commission_Formula\_\_c + FormulaEvaluator).      |

---

---

## 12. ADDITIONAL EVENT SOURCES (V2.5)

### 12.1 Activity Commission Events

Activity-based commissions (BDR/SDR) use a separate trigger path from the main Opportunity trigger. They do NOT flow through the Commission_Event\_\_e Platform Event — they process synchronously via ActivityCommissionService.

| Trigger                   | Object    | What It Does                                                     |
| ------------------------- | --------- | ---------------------------------------------------------------- |
| `ActivityTaskTrigger`     | Task      | Evaluates call-based Activity_Commission_Rule\_\_c rules         |
| `ActivityEventTrigger`    | Event     | Evaluates meeting/demo-based rules                               |
| `ActivityCommissionBatch` | Scheduled | Catches qualified opps created by BDRs (periodic reconciliation) |

These are **not routed through CommissionEventHandler** because activities are a fundamentally different calculation path — they don't involve Opportunities in the same way. The activity engine has its own service (ActivityCommissionService) with its own cap enforcement and filter criteria evaluation.

### 12.2 External Transaction Events

Imported transactions from external systems (ERP, billing, POS) are processed via REST API, not triggers.

| API Endpoint                                      | Method | What It Does                                                       |
| ------------------------------------------------- | ------ | ------------------------------------------------------------------ |
| `/services/apexrest/revenuetrust/transactions`    | POST   | Imports external transactions → match → validate → commission calc |
| `/services/apexrest/revenuetrust/payments`        | POST   | Imports customer payments → triggers hold releases                 |
| `/services/apexrest/revenuetrust/payroll`         | GET    | Retrieves validated unpaid commissions for payroll                 |
| `/services/apexrest/revenuetrust/payroll/confirm` | POST   | Receives payroll confirmation → marks calcs as Paid                |

Source-of-truth rule: Imported_Transaction**c OR Opportunity — never both. Enforced by validation on Comp_Calculation**c.

### 12.3 Complete Commission Ingestion / Routing Inventory

#### Core Commission Event Producers (21 deployed)

| #   | Producer                                  | Object/Endpoint                    | Event Types                                 | Status      |
| --- | ----------------------------------------- | ---------------------------------- | ------------------------------------------- | ----------- |
| —   | **Triggers — Deal Lifecycle & Economics** |                                    |                                             |             |
| 1   | OpportunityCommissionTrigger              | Opportunity (after update)         | 17 Family A/B/C event types                 | ✅ Deployed |
| 2   | OpportunityLineItemTrigger                | OpportunityLineItem                | PRODUCT_MIX_CHANGED + 6 subtypes            | ✅ Deployed |
| 3   | DealCreditSplitTrigger                    | Deal_Credit_Split\_\_c             | SPLIT_CHANGED/\_POST_CLOSE + 5 subtypes     | ✅ Deployed |
| —   | **Triggers — Activity Commissions**       |                                    |                                             |             |
| 4   | ActivityTaskTrigger                       | Task                               | Activity commission processing              | ✅ Deployed |
| 5   | ActivityEventTrigger                      | Event                              | Activity commission processing              | ✅ Deployed |
| —   | **Triggers — Config Change Invalidation** |                                    |                                             |             |
| 6   | CompPlanTrigger                           | Comp_Plan\_\_c                     | PLAN_ASSIGNMENT_CHANGED                     | ✅ Deployed |
| 7   | CommissionTierTrigger                     | Commission_Tier\_\_c               | RATE_TABLE_CHANGED                          | ✅ Deployed |
| 8   | PlanCapTrigger                            | Plan_Cap\_\_c                      | CAP_RULE_CHANGED                            | ✅ Deployed |
| 9   | ProductEligibilityTrigger                 | Template_Product_Eligibility\_\_c  | PRODUCT_ELIGIBILITY_RULE_CHANGED            | ✅ Deployed |
| 10  | RoleEligibilityTrigger                    | Template_Role_Eligibility\_\_c     | ROLE_ELIGIBILITY_RULE_CHANGED               | ✅ Deployed |
| 11  | ClawbackPolicyTrigger                     | Clawback_Policy\_\_c               | CLAWBACK_POLICY_CHANGED                     | ✅ Deployed |
| —   | **Triggers — Period Management**          |                                    |                                             |             |
| 12  | ForecastPeriodTrigger                     | Forecast_Period\_\_c               | PERIOD_FROZEN / PERIOD_REOPENED             | ✅ Deployed |
| —   | **Platform Event Router**                 |                                    |                                             |             |
| 13  | CommissionEventTrigger                    | Commission_Event\_\_e              | Routes all events to CommissionEventHandler | ✅ Deployed |
| —   | **REST APIs — External Data Ingestion**   |                                    |                                             |             |
| 14  | ImportTransactionRestApi                  | POST /revenuetrust/transactions    | External transaction import                 | ✅ Deployed |
| 15  | CustomerPaymentRestApi                    | POST /revenuetrust/payments        | Customer payment + hold release             | ✅ Deployed |
| 16  | PayrollRestApi                            | GET /revenuetrust/payroll          | Payroll data retrieval                      | ✅ Deployed |
| 17  | PayrollRestApi                            | POST /revenuetrust/payroll/confirm | Payroll confirmation                        | ✅ Deployed |
| —   | **Batch Jobs**                            |                                    |                                             |             |
| 18  | HoldExpirationBatch                       | Scheduled                          | Detects + expires held commissions          | ✅ Deployed |
| 19  | ActivityCommissionBatch                   | Scheduled                          | Qualified opp reconciliation for BDR plans  | ✅ Deployed |

**Total deployed: 19 event producers** (12 triggers + 4 REST APIs + 2 batch jobs + 1 Platform Event router)

#### Extension Pack Producers (2 — subscriber post-install)

| #   | Producer                     | Object                | Event Types                                 | Status                                      |
| --- | ---------------------------- | --------------------- | ------------------------------------------- | ------------------------------------------- |
| 20  | OpportunitySplitTrigger      | OpportunitySplit      | SPLIT_CHANGED (requires Team Selling)       | Handler deployed, trigger in extension pack |
| 21  | OpportunityTeamMemberTrigger | OpportunityTeamMember | TEAM_MEMBER_CHANGED (requires Team Selling) | Handler deployed, trigger in extension pack |

#### Shared Platform Event Subscribers (non-core to commission routing)

| #   | Subscriber             | Platform Event             | Purpose                                                                | Status |
| --- | ---------------------- | -------------------------- | ---------------------------------------------------------------------- | ------ |
| —   | GovernanceEventTrigger | Governance_Eval_Event\_\_e | Routes to GovernanceEventHandler (governance rule evaluation — Week 4) | Stub   |
| —   | SignalEventTrigger     | Signal_Event\_\_e          | Routes to SignalEventHandler (health score processing — Week 7)        | Stub   |

These are NOT commission event producers. They are shared platform infrastructure that will serve the Deal Health and Governance modules. Listed here for completeness but not counted in the commission routing inventory.

**Canonical counts:**

Commission-specific:

- **19 deployed commission producers** (12 triggers + 4 REST APIs + 2 batch jobs + 1 PE router)
- **2 extension-pack commission producers** (subscriber post-install for Team Selling)
- **= 21 commission ingestion points**

Shared platform infrastructure (non-commission):

- **2 shared platform subscribers** (GovernanceEventTrigger, SignalEventTrigger — stubs for future modules)

Total:

- **21 commission ingestion points + 2 shared platform subscribers = 23 total platform ingestion points**

---

---

## 13. PIPELINE OBJECT ABSTRACTION (V2.6)

### 13.1 Any-Object Commission Support

All 45 event types now work on ANY SObject — not just Opportunity. Two new classes enable this:

| Class                                 | Role                                                                                                                                                 |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PipelineObjectService.cls`           | Abstracts field access. All engine code calls this instead of querying Opportunity directly. Uses `Field_Mapping__mdt` for dynamic field resolution. |
| `GenericCommissionTriggerHandler.cls` | Generic trigger handler subscriber orgs call from their custom object trigger (3 lines). Detects all lifecycle events using PipelineObjectService.   |

### 13.2 How It Fits the Existing Architecture

```
BEFORE (Opportunity only):
  OpportunityCommissionTrigger → OpportunityCommissionTriggerHandler → Commission_Event__e → CommissionEventHandler → CommissionService

AFTER (any object):
  {AnyObject}Trigger → GenericCommissionTriggerHandler → Commission_Event__e → CommissionEventHandler → CommissionService
  (CommissionService uses PipelineObjectService for ALL record access)
```

The entire routing framework (45 event types, 27 alerts, all handlers, all services) works unchanged — PipelineObjectService provides the abstraction layer.

### 13.3 Custom Formula Engine

Commission_Formula\_\_c + FormulaEvaluator.cls provide user-defined calculation formulas:

- Safe expression language: arithmetic, IF/THEN/ELSE, MIN/MAX/ABS/ROUND
- JSON variable bindings to any pipeline record field
- JSON conditions (all must pass for formula to apply)
- Result types: Commission_Amount, Commission_Rate, Commissionable_Value
- Sandboxed: no DML, no SOQL, no system access

See Incentives Object Model V2.0 §18.2 for full details, formula examples, and field definitions.

---

_Commission Event Routing Matrix V2.6_  
_4 Families. 45 Event Types. 27 Alert Types._  
_43/45 operationally complete. 2/45 handler-ready (Team Selling extension)._  
_Any-object commissioning via PipelineObjectService + GenericCommissionTriggerHandler._  
_Custom formula engine for user-defined calculations._  
_§11 is the single source of truth for event types, alert types, source ownership, and routing status. Do not duplicate these definitions elsewhere._
