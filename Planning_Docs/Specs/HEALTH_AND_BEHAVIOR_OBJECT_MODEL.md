# RevenueTrust — Deal Health & Behavior Intelligence Object Model

**Version:** 1.2 — Spec Frozen  
**Date:** April 2, 2026  
**Status:** SPEC FROZEN — ready for implementation  
**Companion specs:** FORECASTING_OBJECT_MODEL.md V1.4 (frozen), INCENTIVES_OBJECT_MODEL.md V2.0 (any-object + formula engine), REVENUETRUST_OBJECT_MODEL.md (cross-module objects)  
**Unified Spec refs:** §5 (Deal Health), §5.10 (Signal Freshness), §6 (Behavior Intelligence), §6.10 (Explanation Engine), §6.11 (Interpretation Policy)

---

## Design Philosophy

Deal Health and Behavior Intelligence are tightly coupled — health signals feed behavior detection, and behavior patterns reference health score trends. They share signal infrastructure and the same onboarding discovery for external integrations. They are designed as **two modules sharing one signal foundation**.

Key constraints from the frozen specs:

- Deal Health scores are **Tier 1 — Deterministic** (§9.2.1). Every point traceable.
- Behavior Intelligence flags are **Insight, not Enforcement** (§1.6.2). Flags recommend, never block.
- AI close probability is **Tier 2 — Predictive/Advisory** (§9.2.1). Cannot gate workflows.
- Coaching nudges and behavior narratives are **Tier 3 — Narrative/Assistive** (§9.2.1). Human-editable before delivery.
- Signal freshness follows the 5-state enum: LIVE, RECENT, STALE, EXPIRED, MISSING (§5.10)

---

## 1. ONBOARDING WIZARD — DEAL HEALTH & BEHAVIOR INTELLIGENCE

### 1.1 Discovery (Automated)

| Discovery Check                     | Query / Method                                                                                                                | What We Learn                                                                        |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Conversation Intelligence tools** | Check for Gong, Chorus, Zoom Revenue Accelerator, Dialpad Named Credentials or Connected Apps                                 | Which CI tools are already connected to the org?                                     |
| **Relationship Intelligence tools** | Check for Momentum, People.ai Connected Apps                                                                                  | Relationship signal sources available?                                               |
| **Email Integration**               | Check for Einstein Activity Capture, Gmail/Outlook integration settings                                                       | Email metadata available for response time / engagement signals?                     |
| **Activity data richness**          | `SELECT COUNT() FROM Task WHERE CreatedDate = LAST_N_DAYS:90`, `SELECT COUNT() FROM Event WHERE CreatedDate = LAST_N_DAYS:90` | How much activity data exists? Sparse activity = lower Activity Recency reliability. |
| **Contact Roles**                   | `SELECT COUNT() FROM OpportunityContactRole`                                                                                  | Are contact roles populated? (drives Stakeholder Count and DM engagement signals)    |
| **Competitor field**                | Check if Opportunity has a Competitor\_\_c field or if standard Competitor product is used                                    | Competitor signal source                                                             |
| **Stage history**                   | Check if Opportunity Field History Tracking is enabled for StageName                                                          | Stage progression signal reliability                                                 |

### 1.2 Admin Questionnaire

**Question 1: Signal Sources**

> Which external tools does your team use for customer engagement? (We'll integrate with them for health scoring)
>
> - [ ] **Gong** — call recording and conversation intelligence
> - [ ] **Zoom Revenue Accelerator** — conversation health scores
> - [ ] **Chorus** — conversation analytics
> - [ ] **Dialpad** — call scoring
> - [ ] **Momentum** — relationship intelligence
> - [ ] **People.ai** — activity capture and scoring
> - [ ] **None of the above** — we'll use CRM-only signals (activity, stage, close date patterns)

**Question 2: Health Score Components**

> Which signals matter most for your pipeline health assessment? (Drag to reorder by importance, adjust weights)
>
> | Component                                                     | Default Weight | Your Weight |
> | ------------------------------------------------------------- | -------------- | ----------- |
> | Conversation Intelligence (call quality, engagement)          | 40%            | \_\_\_%     |
> | Relationship Strength (DM engagement, champion, stakeholders) | 25%            | \_\_\_%     |
> | Activity Recency (last mutual activity)                       | 20%            | \_\_\_%     |
> | Engagement Depth (call count, meetings, response rate)        | 15%            | \_\_\_%     |
>
> Note: If no Conversation Intelligence tool is connected, that component's weight is automatically redistributed to the others.

**Question 3: Decision Maker Identification**

> How do you identify the key decision maker on a deal?
>
> - [ ] **OpportunityContactRole** with Role = "Decision Maker" or "Economic Buyer"
> - [ ] **Custom field on Opportunity** — specify: {field API name}
> - [ ] **Contact field** — specify: {e.g., Contact.Title contains "VP", "Director", "C-Suite"}
> - [ ] **We don't track this formally** — skip DM-specific signals

**Question 4: Competitor Tracking**

> How do you track competitors on deals?
>
> - [ ] **Standard Competitors related list** (OpportunityCompetitor)
> - [ ] **Custom field on Opportunity** — specify: {field API name}
> - [ ] **Conversation intelligence flags** (Gong/Chorus competitor mentions)
> - [ ] **We don't track competitors** — skip competitor adjustment rule

**Question 5: Behavior Intelligence Appetite**

> Which behavioral patterns would you like the system to detect? (Select all that apply)
>
> - [ ] **Sandbagging detection** — reps under-committing while near incentive thresholds
> - [ ] **Optimism bias detection** — reps over-committing while deal signals are weak
> - [ ] **Deal timing patterns** — deals clustering at period end (pull-forward/push-out gaming)
> - [ ] **Manager accuracy tracking** — how accurate are managers' forecast submissions?
> - [ ] **Category regression alerts** — deals moving backward through forecast categories
> - [ ] **Coaching nudges** — AI-generated deal-specific guidance for managers
> - [ ] **None for now** — just health scores, no behavior intelligence (can enable later)

### 1.3 Configuration Generation

Based on answers, the wizard creates:

1. `Health_Score_Configuration__c` — global scoring config with component weights
2. `Health_Score_Component__c` records — one per active component with weight and adapter binding
3. `Adjustment_Rule__c` records — default rules enabled/disabled per admin choices
4. `Signal_Adapter_Config__c` records — one per detected/selected external tool
5. `Behavior_Detection_Config__c` — which detection patterns are active
6. `Detection_Rule__c` records — default detection rules per selected patterns

---

## 2. OBJECT DEFINITIONS — DEAL HEALTH MODULE

### 2.1 Health_Score_Configuration\_\_c (Health Score Template — Custom Object)

**Purpose:** Top-level configuration for health scoring in this org. Defines scoring parameters, thresholds, and display settings. Multiple configurations can coexist (e.g., one per business unit, one per deal size tier).

| #   | Field API Name                | Type        | Label                    | Notes                                                                |
| --- | ----------------------------- | ----------- | ------------------------ | -------------------------------------------------------------------- |
| 1   | Name                          | Text(80)    | Configuration Name       | e.g., "Enterprise Deal Health", "SMB Pipeline Score"                 |
| 2   | `Is_Active__c`                | Checkbox    | Active                   |                                                                      |
| 3   | `Is_Default__c`               | Checkbox    | Default                  | Used when no config specified for a deal                             |
| 4   | `Score_Range_Min__c`          | Number(3,0) | Score Range Min          | Always 0                                                             |
| 5   | `Score_Range_Max__c`          | Number(3,0) | Score Range Max          | Always 100                                                           |
| 6   | `Green_Threshold__c`          | Number(3,0) | Green Threshold          | Score ≥ this = healthy. Default: 70                                  |
| 7   | `Yellow_Threshold__c`         | Number(3,0) | Yellow Threshold         | Score ≥ this and < Green = at risk. Default: 40                      |
| 8   | `Smoothing_Window_Days__c`    | Number(2,0) | Smoothing Window         | Rolling average window to prevent single-event spikes. Default: 7    |
| 9   | `Recalc_Frequency__c`         | Picklist    | Recalculation Frequency  | Realtime (on signal change), Hourly, Daily_Batch                     |
| 10  | `Conflict_Alert_Enabled__c`   | Checkbox    | Conflict Alert Enabled   | Show alert when high-confidence forecast category + low health score |
| 11  | `Conflict_Score_Threshold__c` | Number(3,0) | Conflict Score Threshold | Health score below this triggers conflict alert. Default: 40         |
| 12  | `Pipeline_Object__c`          | Text(100)   | Pipeline Object          | Default: "Opportunity". Shared with Forecasting.                     |
| 13  | `DM_Identification_Method__c` | Picklist    | DM Identification        | Contact_Role, Custom_Opp_Field, Contact_Title, None                  |
| 14  | `DM_Identification_Field__c`  | Text(100)   | DM Field/Value           | Field API name or title pattern for DM identification                |
| 15  | `Competitor_Source__c`        | Picklist    | Competitor Source        | Standard_Competitor, Custom_Field, CI_Adapter, None                  |
| 16  | `Competitor_Field__c`         | Text(100)   | Competitor Field         | If Custom_Field source                                               |

---

### 2.2 Health_Score_Component\_\_c (Score Component — Child of Configuration)

**Purpose:** Defines each component of the composite health score. Replaces the hardcoded 4-component model with a configurable N-component model. Default: 4 components. Admin can add/remove/reweight.

| #   | Field API Name                  | Type               | Label                  | Notes                                                                                                                      |
| --- | ------------------------------- | ------------------ | ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Health_Score_Configuration__c` | MasterDetail       | Configuration          | → Health_Score_Configuration\_\_c                                                                                          |
| 2   | Name                            | Text(80)           | Component Name         | e.g., "Conversation Intelligence", "Relationship Strength", "Activity Recency", "Engagement Depth"                         |
| 3   | `Component_Code__c`             | Text(30)           | Component Code         | Unique within config: "CI", "REL", "ACT", "ENG". Immutable after data exists.                                              |
| 4   | `Weight_Pct__c`                 | Percent            | Weight %               | Must sum to 100% across active components in the config                                                                    |
| 5   | `Signal_Adapter__c`             | Lookup             | Primary Signal Adapter | → Signal_Adapter_Config\_\_c. Which adapter feeds this component's primary score.                                          |
| 6   | `Fallback_Adapter__c`           | Lookup             | Fallback Adapter       | → Signal_Adapter_Config\_\_c. Used when primary adapter has no data.                                                       |
| 7   | `Score_Formula__c`              | Picklist           | Score Formula          | Adapter_Direct (use adapter's normalized 0-100), CRM_Activity_Recency, CRM_Stage_Progression, CRM_Engagement_Depth, Custom |
| 8   | `Custom_Formula__c`             | LongTextArea(2000) | Custom Formula         | For Score_Formula = Custom. Admin-defined scoring expression.                                                              |
| 9   | `Is_Active__c`                  | Checkbox           | Active                 | Inactive = weight redistributed to remaining                                                                               |
| 10  | `Sort_Order__c`                 | Number(2,0)        | Display Order          |                                                                                                                            |

**Validation rule:** Sum of `Weight_Pct__c` across active components must = 100%. Enforced by before-save trigger.

**Built-in score formulas (Score_Formula picklist):**

| Formula                 | Logic                                                                                         | Used By                                         |
| ----------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `Adapter_Direct`        | Read adapter's `getHealthSignal()` → 0-100 directly                                           | Conversation Intelligence (Gong, Zoom RA, etc.) |
| `CRM_Activity_Recency`  | Days since last mutual activity: 0-3→100, 4-7→85, 8-14→65, 15-21→45, 22-30→25, >30→10, none→0 | Activity Recency (CRM-only)                     |
| `CRM_Stage_Progression` | Forward in 14d→90, Stalled 14-30d→50, Regressed→20, Stalled>30d→10                            | Stage Progression (CRM-only fallback)           |
| `CRM_Engagement_Depth`  | (interaction_count × 0.30) + (meeting_count × 0.30) + (response_rate × 0.40)                  | Engagement Depth (CRM-only)                     |
| `CRM_Relationship`      | (DM_engagement × 0.40) + (Champion × 0.35) + (Stakeholder_spread × 0.25)                      | Relationship (CRM-only fallback)                |
| `Custom`                | Admin-defined expression referencing Deal_Signal\_\_c fields                                  | Any custom component                            |

---

### 2.3 Adjustment_Rule\_\_c (Score Adjustment Rule — Child of Configuration)

**Purpose:** Defines flat-point modifiers applied after the weighted component sum. Admin can add/remove/modify rules.

| #   | Field API Name                  | Type         | Label                  | Notes                                                                                      |
| --- | ------------------------------- | ------------ | ---------------------- | ------------------------------------------------------------------------------------------ |
| 1   | `Health_Score_Configuration__c` | MasterDetail | Configuration          | → Health_Score_Configuration\_\_c                                                          |
| 2   | Name                            | Text(80)     | Rule Name              | e.g., "Competitor Mentioned", "DM Gone Dark", "Next Step Confirmed"                        |
| 3   | `Rule_Code__c`                  | Text(30)     | Rule Code              | Unique. Immutable after data.                                                              |
| 4   | `Adjustment_Points__c`          | Number(4,1)  | Points                 | Positive or negative. e.g., -15, +10, -20                                                  |
| 5   | `Trigger_Field__c`              | Text(100)    | Trigger Field          | Deal_Signal**c field to evaluate: "Competitor_Mentioned**c", "DM_Last_Response\_\_c", etc. |
| 6   | `Trigger_Operator__c`           | Picklist     | Operator               | Equals, Not_Equals, Greater_Than, Less_Than, Days_Since_Greater_Than, Is_True, Is_False    |
| 7   | `Trigger_Value__c`              | Text(100)    | Trigger Value          | Comparison value: "true", "21" (days), "2" (count), etc.                                   |
| 8   | `Lookback_Days__c`              | Number(3,0)  | Lookback Window (Days) | Only evaluate signals within this window. Null = all time.                                 |
| 9   | `Is_Active__c`                  | Checkbox     | Active                 |                                                                                            |
| 10  | `Sort_Order__c`                 | Number(2,0)  | Evaluation Order       |                                                                                            |

**Default rules shipped (7 rules matching spec §5.2.2):**

| Rule                     | Points | Trigger                                            | Default |
| ------------------------ | ------ | -------------------------------------------------- | ------- |
| Competitor Mentioned     | -15    | Competitor_Mentioned\_\_c = true, lookback 30 days | Active  |
| DM Gone Dark             | -20    | DM_Last_Response\_\_c days since > 21              | Active  |
| Multiple No-Shows        | -10    | No_Show_Count\_\_c ≥ 2, lookback 30 days           | Active  |
| Next Step Confirmed      | +10    | Next_Step_Confirmed\_\_c = true                    | Active  |
| DM on Recent Interaction | +8     | DM_Last_Response\_\_c days since < 14              | Active  |
| Multi-Threaded           | +5     | Stakeholder_Count\_\_c ≥ 4                         | Active  |
| Champion Re-Engaged      | +7     | Champion_Reengaged\_\_c = true, lookback 14 days   | Active  |

---

### 2.4 Signal_Adapter_Config\_\_c (Signal Adapter Registration — Custom Object)

**Purpose:** Registers and configures each signal source. One record per connected tool. The adapter Apex class reads this config at runtime.

| #   | Field API Name            | Type               | Label                 | Notes                                                                                                         |
| --- | ------------------------- | ------------------ | --------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | Name                      | Text(80)           | Adapter Name          | e.g., "Gong Production", "CRM Activity Adapter"                                                               |
| 2   | `Adapter_Type__c`         | Picklist           | Adapter Type          | Gong, Zoom_RA, Dialpad, Chorus, Momentum, People_AI, CRM, Email_Metadata, Custom_HTTP                         |
| 3   | `Adapter_Class__c`        | Text(100)          | Apex Class Name       | Fully qualified name of the SignalAdapter implementation. e.g., "RevenueTrust.GongSignalAdapter"              |
| 4   | `Named_Credential__c`     | Text(100)          | Named Credential      | For external APIs. Keeps auth secrets out of the object.                                                      |
| 5   | `Sync_Method__c`          | Picklist           | Sync Method           | Webhook_Realtime, Scheduled_Batch, Both, Event_Driven                                                         |
| 6   | `Sync_Schedule__c`        | Text(50)           | Batch Schedule        | CRON expression for scheduled sync. e.g., "0 0 2 \* \* ?" (daily 2am)                                         |
| 7   | `Freshness_SLA_Hours__c`  | Number(4,0)        | Freshness SLA (Hours) | RECENT threshold. Default per adapter type (§5.10.2)                                                          |
| 8   | `Hard_Expire_Hours__c`    | Number(4,0)        | Hard Expire (Hours)   | EXPIRED threshold. Default per adapter type.                                                                  |
| 9   | `Signal_Priority__c`      | Number(2,0)        | Priority              | When multiple adapters provide the same signal type, highest priority wins. 1 = highest.                      |
| 10  | `Is_Active__c`            | Checkbox           | Active                |                                                                                                               |
| 11  | `Last_Sync_On__c`         | DateTime           | Last Sync             |                                                                                                               |
| 12  | `Last_Sync_Status__c`     | Picklist           | Last Sync Status      | Success, Partial, Failed, Never_Run                                                                           |
| 13  | `Last_Sync_Records__c`    | Number(6,0)        | Records Synced        |                                                                                                               |
| 14  | `Last_Sync_Errors__c`     | LongTextArea(5000) | Sync Errors           |                                                                                                               |
| 15  | `Normalization_Config__c` | LongTextArea(2000) | Normalization Config  | JSON: field mapping from adapter's raw output to Deal_Signal\_\_c canonical fields. For Custom_HTTP adapters. |
| 16  | `Webhook_Endpoint__c`     | Text(500)          | Webhook Endpoint      | Platform-generated URL for adapters that push data via webhook                                                |

**CRM Adapter is always present:** A built-in CRM adapter record is auto-created on install. It reads from standard Salesforce objects (Task, Event, Opportunity, OpportunityContactRole) and is always active. It has no Named Credential — it queries the local org.

---

### 2.5 Deal_Signal\_\_c (Pipeline Signal — Custom Object)

**Purpose:** Canonical signal store. One record per pipeline record. Stores the latest normalized signals from ALL connected adapters + the computed composite health score.

**Updated from REVENUETRUST_OBJECT_MODEL.md — adding fields for adapter-sourced signals and component breakdown.**

| #   | Field API Name                                  | Type               | Label                  | Notes                                                                                        |
| --- | ----------------------------------------------- | ------------------ | ---------------------- | -------------------------------------------------------------------------------------------- |
| —   | **Core**                                        |                    |                        |                                                                                              |
| 1   | `Opportunity__c`                                | Lookup             | Pipeline Record        | → Opportunity. Unique per record.                                                            |
| 2   | `Health_Score_Configuration__c`                 | Lookup             | Scoring Configuration  | → Health_Score_Configuration\_\_c. Which config was used.                                    |
| 3   | `Health_Score__c`                               | Number(3,0)        | Health Score           | Composite 0-100 (after adjustments, clamped, smoothed)                                       |
| 4   | `Raw_Score__c`                                  | Number(5,1)        | Raw Score              | Before smoothing. For debugging.                                                             |
| 5   | `Score_Smoothed__c`                             | Number(3,0)        | Smoothed Score         | After rolling average. This is what the UI displays.                                         |
| 6   | `Score_Band__c`                                 | Picklist           | Score Band             | Green, Yellow, Red. Computed from thresholds. For reporting.                                 |
| —   | **Component Scores**                            |                    |                        |                                                                                              |
| 7   | `Component_1_Score__c`                          | Number(3,0)        | Component 1 Score      | 0-100. Slot 1 (default: Conversation Intelligence)                                           |
| 8   | `Component_2_Score__c`                          | Number(3,0)        | Component 2 Score      | Slot 2 (default: Relationship)                                                               |
| 9   | `Component_3_Score__c`                          | Number(3,0)        | Component 3 Score      | Slot 3 (default: Activity Recency)                                                           |
| 10  | `Component_4_Score__c`                          | Number(3,0)        | Component 4 Score      | Slot 4 (default: Engagement Depth)                                                           |
| 11  | `Component_5_Score__c`                          | Number(3,0)        | Component 5 Score      | Reserve slot                                                                                 |
| 12  | `Component_6_Score__c`                          | Number(3,0)        | Component 6 Score      | Reserve slot                                                                                 |
| 13  | `Component_Weights__c`                          | Text(200)          | Applied Weights        | JSON: {"CI": 40, "REL": 25, "ACT": 20, "ENG": 15}. After redistribution.                     |
| —   | **Adjustment**                                  |                    |                        |                                                                                              |
| 14  | `Adjustment_Points__c`                          | Number(5,1)        | Net Adjustment Points  | Sum of all triggered adjustment rules                                                        |
| 15  | `Adjustment_Details__c`                         | LongTextArea(5000) | Adjustment Details     | JSON: [{"rule": "competitor_mentioned", "points": -15}, {"rule": "next_step", "points": 10}] |
| —   | **Signal Data (canonical, adapter-normalized)** |                    |                        |                                                                                              |
| 16  | `Last_Mutual_Activity__c`                       | DateTime           | Last Mutual Activity   | From CRM or relationship adapter                                                             |
| 17  | `Stakeholder_Count__c`                          | Number(3,0)        | Stakeholder Count      | From CRM Contact Roles or relationship adapter                                               |
| 18  | `DM_Last_Response__c`                           | DateTime           | DM Last Response       |                                                                                              |
| 19  | `DM_Engagement_Score__c`                        | Number(3,0)        | DM Engagement Score    | 0-100                                                                                        |
| 20  | `Champion_Strength__c`                          | Number(3,0)        | Champion Strength      | 0-100 from relationship adapter                                                              |
| 21  | `Competitor_Mentioned__c`                       | Checkbox           | Competitor Mentioned   |                                                                                              |
| 22  | `Competitor_Name__c`                            | Text(200)          | Competitor Name(s)     | If known                                                                                     |
| 23  | `Next_Step_Confirmed__c`                        | Checkbox           | Next Step Confirmed    |                                                                                              |
| 24  | `Next_Step_Description__c`                      | Text(500)          | Next Step              | Text of the confirmed next step                                                              |
| 25  | `Call_Count_30d__c`                             | Number(4,0)        | Calls (Last 30d)       |                                                                                              |
| 26  | `Meeting_Count_30d__c`                          | Number(4,0)        | Meetings (Last 30d)    |                                                                                              |
| 27  | `Email_Response_Rate__c`                        | Percent            | Email Response Rate    |                                                                                              |
| 28  | `No_Show_Count_30d__c`                          | Number(3,0)        | No-Shows (Last 30d)    |                                                                                              |
| 29  | `Champion_Reengaged__c`                         | Checkbox           | Champion Re-Engaged    | Champion responded after dark period                                                         |
| 30  | `Stage_Progression__c`                          | Picklist           | Stage Progression      | Forward, Stalled, Regressed                                                                  |
| 31  | `Slip_Count__c`                                 | Number(3,0)        | Close Date Slip Count  |                                                                                              |
| 32  | `Days_In_Current_Stage__c`                      | Number(4,0)        | Days in Current Stage  |                                                                                              |
| —   | **Freshness & Adapter Metadata**                |                    |                        |                                                                                              |
| 33  | `Signal_Freshness__c`                           | Picklist           | Overall Freshness      | LIVE, RECENT, STALE, EXPIRED, MISSING. Worst of all active adapters.                         |
| 34  | `CI_Adapter_Name__c`                            | Text(50)           | CI Adapter             | Which adapter provided CI score. "None" if missing.                                          |
| 35  | `CI_Freshness__c`                               | Picklist           | CI Freshness           | Per-adapter freshness state                                                                  |
| 36  | `CI_Last_Sync__c`                               | DateTime           | CI Last Sync           |                                                                                              |
| 37  | `Relationship_Adapter_Name__c`                  | Text(50)           | Relationship Adapter   |                                                                                              |
| 38  | `Relationship_Freshness__c`                     | Picklist           | Relationship Freshness |                                                                                              |
| 39  | `Relationship_Last_Sync__c`                     | DateTime           | Relationship Last Sync |                                                                                              |
| 40  | `CRM_Last_Sync__c`                              | DateTime           | CRM Last Sync          | Always present (built-in adapter)                                                            |
| —   | **Scoring Metadata**                            |                    |                        |                                                                                              |
| 41  | `Last_Calculated__c`                            | DateTime           | Last Calculated        | When score was last recomputed                                                               |
| 42  | `Calculation_Version__c`                        | Number(6,0)        | Calculation Version    | Monotonic counter. Incremented on each recalculation. For optimistic locking.                |

**Total: 42 fields.** (Up from 25 in the old model — now includes component slots, adapter metadata, freshness per adapter, and canonical signal fields.)

---

### 2.6 Deal_Signal_History\_\_c (Score Change History — Custom Object)

**Purpose:** Audit trail of health score changes. One record per score-changing event.

| #   | Field API Name          | Type               | Label             | Notes                                                                                  |
| --- | ----------------------- | ------------------ | ----------------- | -------------------------------------------------------------------------------------- |
| 1   | `Deal_Signal__c`        | MasterDetail       | Pipeline Signal   | → Deal_Signal\_\_c                                                                     |
| 2   | `Previous_Score__c`     | Number(3,0)        | Previous Score    |                                                                                        |
| 3   | `New_Score__c`          | Number(3,0)        | New Score         |                                                                                        |
| 4   | `Delta__c`              | Number(5,1)        | Delta             |                                                                                        |
| 5   | `Component_Deltas__c`   | LongTextArea(2000) | Component Deltas  | JSON: {"CI": {"old": 52, "new": 65}, "ACT": {"old": 85, "new": 45}}                    |
| 6   | `Adjustment_Deltas__c`  | LongTextArea(2000) | Adjustment Deltas | JSON: rules that fired/stopped firing                                                  |
| 7   | `Signal_Source__c`      | Text(50)           | Triggering Source | Which adapter/event caused the recalculation                                           |
| 8   | `Trigger_Event__c`      | Text(200)          | Trigger Event     | Human-readable: "Gong call score updated", "No activity for 14 days", "Stage advanced" |
| 9   | `Score_Band_Changed__c` | Checkbox           | Band Changed      | True if Green↔Yellow↔Red transition occurred                                           |

**Total: 9 fields.**

---

## 3. OBJECT DEFINITIONS — BEHAVIOR INTELLIGENCE MODULE

### 3.1 Behavior_Detection_Config\_\_c (Behavior Detection Configuration — Custom Object)

**Purpose:** Controls which behavior detection patterns are active for this org. Created by onboarding wizard.

| #   | Field API Name                 | Type        | Label                         | Notes                                                                    |
| --- | ------------------------------ | ----------- | ----------------------------- | ------------------------------------------------------------------------ |
| 1   | Name                           | Text(80)    | Configuration Name            | "RevenueTrust Behavior Intelligence"                                     |
| 2   | `Sandbagging_Enabled__c`       | Checkbox    | Sandbagging Detection         |                                                                          |
| 3   | `Optimism_Enabled__c`          | Checkbox    | Optimism Bias Detection       |                                                                          |
| 4   | `Timing_Enabled__c`            | Checkbox    | Deal Timing Pattern Detection |                                                                          |
| 5   | `Accuracy_Enabled__c`          | Checkbox    | Manager Accuracy Tracking     |                                                                          |
| 6   | `Regression_Enabled__c`        | Checkbox    | Category Regression Alerts    |                                                                          |
| 7   | `Coaching_Enabled__c`          | Checkbox    | Coaching Nudge Generation     |                                                                          |
| 8   | `Min_Corroborating_Signals__c` | Number(1,0) | Min Corroborating Signals     | Per §6.11.2: minimum signals required to raise a flag. Default: 2        |
| 9   | `Flag_Retention_Days__c`       | Number(4,0) | Flag Retention (Days)         | How long resolved/dismissed flags are kept before archival. Default: 365 |
| 10  | `Coaching_Delivery__c`         | Picklist    | Coaching Delivery             | In_App_Only, In_App_And_Slack, In_App_And_Teams, In_App_And_Email        |
| 11  | `Is_Active__c`                 | Checkbox    | Active                        |                                                                          |

---

### 3.2 Detection_Rule\_\_c (Detection Rule — Child of Configuration)

**Purpose:** Configurable rules that detect specific behavioral patterns. Admin can adjust thresholds without code changes.

| #   | Field API Name                 | Type               | Label                     | Notes                                                                                                                                |
| --- | ------------------------------ | ------------------ | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `Behavior_Detection_Config__c` | MasterDetail       | Configuration             | → Behavior_Detection_Config\_\_c                                                                                                     |
| 2   | Name                           | Text(80)           | Rule Name                 | e.g., "Sandbagging — Threshold Proximity", "Optimism — Weak Deals in Commit"                                                         |
| 3   | `Detection_Type__c`            | Picklist           | Detection Type            | Sandbagging, Optimism_Bias, Timing_Concentration, Period_Slip_Loop, Threshold_Approach, Category_Regression, Coverage_Gap, Staleness |
| 4   | `Description__c`               | LongTextArea(2000) | Description               | Plain-English explanation of what this rule detects                                                                                  |
| 5   | `Threshold_1_Field__c`         | Text(100)          | Primary Threshold Field   | Which data point to evaluate. e.g., "attainment_pct", "health_score", "days_to_period_end"                                           |
| 6   | `Threshold_1_Operator__c`      | Picklist           | Operator                  | Greater_Than, Less_Than, Between, Equals                                                                                             |
| 7   | `Threshold_1_Value__c`         | Text(50)           | Threshold Value           | e.g., "88" (%), "70" (score), "7" (days)                                                                                             |
| 8   | `Threshold_2_Field__c`         | Text(100)          | Secondary Threshold Field | Second condition (AND logic). e.g., "health_score" for cross-referencing                                                             |
| 9   | `Threshold_2_Operator__c`      | Picklist           | Operator                  |                                                                                                                                      |
| 10  | `Threshold_2_Value__c`         | Text(50)           | Threshold Value           |                                                                                                                                      |
| 11  | `Lookback_Periods__c`          | Number(2,0)        | Lookback Periods          | How many historical periods to analyze. Default: 4                                                                                   |
| 12  | `Severity__c`                  | Picklist           | Flag Severity             | High, Medium, Low                                                                                                                    |
| 13  | `Is_Active__c`                 | Checkbox           | Active                    |                                                                                                                                      |
| 14  | `Is_Library__c`                | Checkbox           | Library Rule              | Shipped with package. Read-only. Admin clones to customize.                                                                          |

**Default detection rules shipped (matching spec §6.3–6.6):**

| Rule                                                    | Type                 | Primary Threshold                         | Secondary                                | Severity |
| ------------------------------------------------------- | -------------------- | ----------------------------------------- | ---------------------------------------- | -------- |
| Sandbagging — Near Threshold + Healthy Deals Downgraded | Sandbagging          | attainment_pct BETWEEN 88-99              | health_score ≥ 70 on non-committed deals | High     |
| Sandbagging — Period-End Push-Out                       | Sandbagging          | close_date moved out of period            | days_to_period_end ≤ 7                   | Medium   |
| Optimism — Weak Deals in High-Confidence                | Optimism_Bias        | committed_deal_count ≥ 3 with health < 40 | historical_win_rate < 40%                | High     |
| Optimism — Stale Committed Deals                        | Optimism_Bias        | committed_deal_no_activity_14d ≥ 1        | —                                        | Medium   |
| Timing — Period-End Clustering                          | Timing_Concentration | deals_closed_last_5_days_pct > 40%        | —                                        | Medium   |
| Slip Loop                                               | Period_Slip_Loop     | consecutive_slips ≥ 3                     | —                                        | Low      |
| Category Regression                                     | Category_Regression  | category_moved_backward = true            | —                                        | Low      |
| Coverage Gap                                            | Coverage_Gap         | coverage_ratio < 1.5                      | —                                        | Medium   |
| Deal Staleness                                          | Staleness            | no_forecast_update_periods ≥ 2            | —                                        | Low      |

---

### 3.3 Behavioral_Flag\_\_c (Behavioral Flag — Custom Object)

**Purpose:** One record per detected behavioral pattern. Created by the detection engine. Reviewed/dismissed by managers. Per spec §6.11: flags are hypotheses, not verdicts.

**Updated from REVENUETRUST_OBJECT_MODEL.md — adding evidence structure, explanation components, and language-safe fields.**

| #   | Field API Name                                        | Type                | Label                   | Notes                                                                                                                                                |
| --- | ----------------------------------------------------- | ------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| —   | **Relationships**                                     |                     |                         |                                                                                                                                                      |
| 1   | `Participant__c`                                      | Lookup              | Participant             | → User                                                                                                                                               |
| 2   | `Opportunity__c`                                      | Lookup              | Pipeline Record         | → Opportunity (null for participant-level flags like timing patterns)                                                                                |
| 3   | `Forecast_Period__c`                                  | Lookup              | Forecast Period         | → Forecast_Period\_\_c                                                                                                                               |
| 4   | `Detection_Rule__c`                                   | Lookup              | Detection Rule          | → Detection_Rule\_\_c that triggered this flag                                                                                                       |
| —   | **Flag Identity**                                     |                     |                         |                                                                                                                                                      |
| 5   | `Flag_Type__c`                                        | Restricted Picklist | Flag Type               | Sandbagging, Optimism_Bias, Threshold_Approach, Timing_Concentration, Period_Slip_Loop, Category_Regression, Coverage_Gap, Staleness                 |
| 6   | `Confidence__c`                                       | Restricted Picklist | Signal Strength         | High (3+ signals), Medium (2 signals), Low (1 signal + pattern). Per §6.11.2                                                                         |
| 7   | `Headline__c`                                         | Text(255)           | Headline                | Observable-language summary. e.g., "Review-worthy pattern: threshold proximity + category downgrade on high-health deal". NEVER accusatory (§6.11.1) |
| —   | **Evidence (Structured — Tier 1)**                    |                     |                         |                                                                                                                                                      |
| 8   | `Evidence_JSON__c`                                    | LongTextArea(10000) | Evidence Data           | JSON: all corroborating signals with values. Machine-readable.                                                                                       |
| 9   | `Evidence_Summary__c`                                 | LongTextArea(5000)  | Evidence Summary        | Human-readable bullet points of each signal. Auto-generated from JSON.                                                                               |
| 10  | `Signal_Count__c`                                     | Number(2,0)         | Corroborating Signals   | Count of independent signals supporting this flag                                                                                                    |
| —   | **Explanation (Structured — Tier 1, per spec §6.10)** |                     |                         |                                                                                                                                                      |
| 11  | `Explanation_Action__c`                               | LongTextArea(2000)  | 1. Observed Action      | What the participant did: "Moved Acme Corp from Commit to Pipeline on Apr 2"                                                                         |
| 12  | `Explanation_Comp_Context__c`                         | LongTextArea(2000)  | 2. Compensation Context | Attainment, tier, threshold proximity, payout delta                                                                                                  |
| 13  | `Explanation_Signals__c`                              | LongTextArea(2000)  | 3. Deal Health Signals  | Contradicting or supporting signals from health score                                                                                                |
| 14  | `Explanation_History__c`                              | LongTextArea(2000)  | 4. Historical Pattern   | Prior instances of this pattern for this participant                                                                                                 |
| 15  | `Explanation_Recommendation__c`                       | LongTextArea(2000)  | 5. Recommended Action   | Suggested governance action or review question                                                                                                       |
| —   | **AI Narrative (Tier 3 — optional)**                  |                     |                         |                                                                                                                                                      |
| 16  | `AI_Narrative__c`                                     | LongTextArea(32000) | AI Narrative            | LLM-generated natural language version. Supplementary to structured explanation.                                                                     |
| 17  | `AI_Model_Version__c`                                 | Text(20)            | AI Model Version        | Which LLM version generated the narrative                                                                                                            |
| —   | **Lifecycle**                                         |                     |                         |                                                                                                                                                      |
| 18  | `Status__c`                                           | Picklist            | Status                  | Active, Dismissed, Resolved, Superseded, Expired                                                                                                     |
| 19  | `Dismissed_By__c`                                     | Lookup              | Dismissed By            | → User                                                                                                                                               |
| 20  | `Dismissal_Reason__c`                                 | LongTextArea(5000)  | Dismissal Reason        | Required on dismiss                                                                                                                                  |
| 21  | `Dismissed_On__c`                                     | DateTime            | Dismissed On            |                                                                                                                                                      |
| 22  | `Resolution_Type__c`                                  | Picklist            | Resolution              | Dismissed_Valid_Reason, Dismissed_False_Positive, Resolved_Action_Taken, Superseded_By_New_Data, Expired_Period_Closed                               |
| 23  | `Created_On__c`                                       | DateTime            | Detected On             | When the detection engine raised this flag                                                                                                           |

**Total: 23 fields.**

---

### 3.4 Manager_Accuracy\_\_c (Manager Accuracy — Custom Object)

**Purpose:** Rolling accuracy statistics per manager. Refreshed weekly by batch job. One record per user.

| #   | Field API Name          | Type                | Label             | Notes                                                                  |
| --- | ----------------------- | ------------------- | ----------------- | ---------------------------------------------------------------------- |
| 1   | `User__c`               | Lookup              | Manager           | → User. Unique per user.                                               |
| 2   | `Hit_Rate__c`           | Percent             | Hit Rate          | When submitted as high-confidence, % that actually closed              |
| 3   | `Avg_Value_Delta__c`    | Percent             | Avg Value Delta   | Average over/under-commit %                                            |
| 4   | `Avg_Slip_Periods__c`   | Number(3,1)         | Avg Slip Rate     | Average periods deals slip from submission to close                    |
| 5   | `Accuracy_Score__c`     | Number(3,0)         | Accuracy Score    | Composite 0-100                                                        |
| 6   | `Periods_Evaluated__c`  | Number(3,0)         | Periods Evaluated | How many periods in the sample                                         |
| 7   | `Records_Evaluated__c`  | Number(5,0)         | Records Evaluated | Total deals used for accuracy calc                                     |
| 8   | `Category_Matrix__c`    | LongTextArea(10000) | Category Matrix   | JSON confusion matrix: submitted category → actual outcome             |
| 9   | `Trend__c`              | Picklist            | Trend             | Improving, Stable, Declining                                           |
| 10  | `Trend_Delta__c`        | Number(5,1)         | Trend Delta       | Change in accuracy score from prior calculation                        |
| 11  | `Last_Calculated__c`    | DateTime            | Last Calculated   |                                                                        |
| 12  | `Calculation_Method__c` | Picklist            | Method            | Statistical (default), Weighted_Recent (more weight to recent periods) |

**Total: 12 fields.**

---

### 3.5 Coaching_Nudge\_\_c (Coaching Nudge — Custom Object — NEW)

**Purpose:** Tracks delivery and response to coaching nudges generated by the behavior intelligence engine. Nudges are deal-specific guidance delivered to managers.

| #   | Field API Name        | Type               | Label            | Notes                                                                                                         |
| --- | --------------------- | ------------------ | ---------------- | ------------------------------------------------------------------------------------------------------------- |
| 1   | `Opportunity__c`      | Lookup             | Pipeline Record  | → Opportunity                                                                                                 |
| 2   | `Recipient__c`        | Lookup             | Recipient        | → User (the manager receiving the nudge)                                                                      |
| 3   | `Forecast_Period__c`  | Lookup             | Forecast Period  | → Forecast_Period\_\_c                                                                                        |
| 4   | `Behavioral_Flag__c`  | Lookup             | Related Flag     | → Behavioral_Flag\_\_c (if nudge triggered by a flag). Optional — some nudges are proactive, not flag-driven. |
| 5   | `Nudge_Type__c`       | Picklist           | Nudge Type       | Deal_Risk, Stale_Deal, Accuracy_Alert, Threshold_Opportunity, Proactive_Coaching                              |
| 6   | `Headline__c`         | Text(255)          | Headline         | Short attention-grabber: "Acme Corp — No legal docs signed. 82% of similar deals slip."                       |
| 7   | `Body__c`             | LongTextArea(5000) | Nudge Body       | Structured coaching content with data points                                                                  |
| 8   | `AI_Generated__c`     | Checkbox           | AI Generated     | True if body was generated by LLM. False if rule-template generated.                                          |
| 9   | `Delivery_Channel__c` | Picklist           | Delivery Channel | In_App, Slack, Teams, Email                                                                                   |
| 10  | `Delivered_On__c`     | DateTime           | Delivered On     |                                                                                                               |
| 11  | `Read_On__c`          | DateTime           | Read On          | When recipient opened/viewed the nudge (in-app tracking)                                                      |
| 12  | `Actioned__c`         | Checkbox           | Actioned         | True if recipient clicked through to deal / took an action                                                    |
| 13  | `Dismissed__c`        | Checkbox           | Dismissed        | True if recipient dismissed without action                                                                    |
| 14  | `Status__c`           | Picklist           | Status           | Pending, Delivered, Read, Actioned, Dismissed, Expired                                                        |

**Total: 14 fields.**

**Nudge generation:** Nightly batch job evaluates active pipeline records. For each record meeting nudge criteria (stale deals, high-risk committed deals, accuracy mismatches), generates a Coaching_Nudge\_\_c record and delivers via configured channel.

**Why separate from Behavioral_Flag\_\_c?** Flags are detection events reviewed in the governance queue. Nudges are proactive coaching messages delivered to managers' workflows. A flag MAY generate a nudge, but nudges also fire independently (e.g., "this deal has been stale for 30 days" doesn't need a behavioral flag — it's just a coaching prompt).

---

## 4. CROSS-MODULE OBJECTS

### 4.1 Governance_Event\_\_c

**Already fully defined** in REVENUETRUST_OBJECT_MODEL.md §4.1 and governed by Forecasting module's governance rules (§7.3). **20 fields.** No changes needed — this object is shared across modules.

### 4.2 Failed_Event\_\_c (Dead Letter Queue)

**Already defined** in REVENUETRUST_OBJECT_MODEL.md §4.4. **6 fields.** Shared across all Platform Event processing.

---

## 5. DECISION POINTS

### DP-H1: Health_Score_Configuration as Custom Object or Custom Metadata?

**Decision: Custom Object.** Same rationale as Forecasting DP-1. Setup Wizard creates records dynamically. Child objects (Component, Adjustment Rule) need proper lookups.

### DP-H2: How many component score slots on Deal_Signal\_\_c?

**Decision: 6 fixed slots** (4 default + 2 reserve). Same trade-off as Forecasting DP-2. 4 components is the norm. If an org needs 7+, they have a scoring design problem.

### DP-H3: Should Behavior Intelligence have its own Change Event?

**Decision: Not for V1.** Behavioral_Flag**c already has full lifecycle tracking (Status, Dismissed_By, Resolution_Type). Forecast_Change_Event**c captures the forecast-side actions that trigger flags. Adding a separate behavior event object adds complexity without clear V1 value. Reconsider if behavioral pattern analytics require their own temporal history.

### DP-H4: Coaching_Nudge\_\_c vs. generic Notification object?

**Decision: Dedicated object.** Nudges have coaching-specific fields (nudge type, actioned, deal context) that a generic notification doesn't capture. Nudge effectiveness tracking (read rate, action rate) is a product metric that informs nudge algorithm tuning.

---

## 6. ENTITY RELATIONSHIP DIAGRAM

```
Health_Score_Configuration__c
  ├── Health_Score_Component__c      (N — scoring components with weights)
  │     └── Signal_Adapter_Config__c (→ which adapter feeds this component)
  ├── Adjustment_Rule__c             (N — point modifiers)
  └── (applied to) Deal_Signal__c    (1 per Opportunity)
        └── Deal_Signal_History__c   (N — score change audit trail)

Behavior_Detection_Config__c
  └── Detection_Rule__c              (N — configurable detection thresholds)
        └── Behavioral_Flag__c       (N — detected patterns)
              └── Coaching_Nudge__c  (0-N — nudges triggered by flags)

Manager_Accuracy__c                  (1 per User — rolling accuracy stats)

Coaching_Nudge__c                    (also created independently, not always from flags)

Cross-Module (shared, not owned by this module):
  Governance_Event__c                — comp-aware governance (owned by Forecasting)
  Failed_Event__c                    — dead letter queue (shared)

External reads:
  Forecast_Override__c               — forecast submission history (for accuracy calc)
  Forecast_Change_Event__c           — behavioral pattern detection
  Quota__c                           — attainment for threshold proximity
  Commission_Tier__c                 — rate tier boundaries for sandbagging detection
  Opportunity                        — pipeline record base data
```

---

## 7. OBJECT COUNT — DEAL HEALTH & BEHAVIOR INTELLIGENCE

| Type                                    | Count                 | Objects                                                                        |
| --------------------------------------- | --------------------- | ------------------------------------------------------------------------------ |
| **Deal Health — Config**                | 3                     | Health_Score_Configuration**c, Health_Score_Component**c, Adjustment_Rule\_\_c |
| **Deal Health — Signal Infrastructure** | 1                     | Signal_Adapter_Config\_\_c                                                     |
| **Deal Health — Runtime**               | 2                     | Deal_Signal**c, Deal_Signal_History**c                                         |
| **Behavior Intel — Config**             | 2                     | Behavior_Detection_Config**c, Detection_Rule**c                                |
| **Behavior Intel — Runtime**            | 3                     | Behavioral_Flag**c, Manager_Accuracy**c, Coaching_Nudge\_\_c                   |
| **Module Total**                        | **11 custom objects** |                                                                                |
| Cross-Module (shared, not counted)      | 2                     | Governance_Event**c, Failed_Event**c                                           |

---

## 8. CONSOLIDATED FIELD COUNT

| Object                          | Fields   | Notes                                                    |
| ------------------------------- | -------- | -------------------------------------------------------- |
| Health_Score_Configuration\_\_c | 16       |                                                          |
| Health_Score_Component\_\_c     | 10       |                                                          |
| Adjustment_Rule\_\_c            | 10       |                                                          |
| Signal_Adapter_Config\_\_c      | 16       |                                                          |
| Deal_Signal\_\_c                | 42       | Largest object — canonical signal store                  |
| Deal_Signal_History\_\_c        | 9        |                                                          |
| Behavior_Detection_Config\_\_c  | 11       |                                                          |
| Detection_Rule\_\_c             | 14       |                                                          |
| Behavioral_Flag\_\_c            | 23       | Includes structured explanation (5 components per §6.10) |
| Manager_Accuracy\_\_c           | 12       |                                                          |
| Coaching_Nudge\_\_c             | 14       |                                                          |
| **Module Total**                | **~177** |                                                          |

**Combined platform total:**
| Module | Objects | Fields |
|---|---|---|
| Forecasting | 12 (10 objects + 2 CMTs) | 224 |
| Incentives | 27 (26 objects + Territory) | 353 |
| Deal Health + Behavior Intel | 11 | 177 |
| Cross-Module (shared) | 2 (Governance_Event, Failed_Event) | 26 |
| **PLATFORM TOTAL** | **52 (49 objects + 2 CMTs + Territory)** | **~780** |

---

## 9. STARTER TEMPLATES — DEFAULTS

### Deal Health Defaults

**Health_Score_Configuration\_\_c:** "Standard Pipeline Health Score"

- Green ≥ 70, Yellow ≥ 40, Smoothing = 7 days, Recalc = Daily_Batch

**Health_Score_Component\_\_c (4 records):**

| Component                 | Code | Weight | Formula              | Adapter                                        |
| ------------------------- | ---- | ------ | -------------------- | ---------------------------------------------- |
| Conversation Intelligence | CI   | 40%    | Adapter_Direct       | (none — redistributed until CI tool connected) |
| Relationship Strength     | REL  | 25%    | CRM_Relationship     | CRM (built-in)                                 |
| Activity Recency          | ACT  | 20%    | CRM_Activity_Recency | CRM (built-in)                                 |
| Engagement Depth          | ENG  | 15%    | CRM_Engagement_Depth | CRM (built-in)                                 |

**Adjustment_Rule\_\_c (7 default rules):** As listed in §2.3.

### Behavior Intelligence Defaults

**Behavior_Detection_Config\_\_c:** All detections enabled except Coaching (requires AI service setup).

**Detection_Rule\_\_c (9 default rules):** As listed in §3.2.

---

---

## 10. V1.1 REFINEMENTS

### 10.1 Competitor Source — Custom Object Support

**Problem:** V1.0 Discovery only checks for a custom field on Opportunity or the standard OpportunityCompetitor. Many orgs have a dedicated `Competitor__c` custom object (or similar) with detailed competitive intelligence.

**Updated Discovery Check:**

| Discovery Check                     | Query                                                                                                                  | What We Learn                                        |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Standard Competitors**            | `SELECT COUNT() FROM OpportunityCompetitor`                                                                            | Using standard product competitor tracking?          |
| **Custom Competitor Object**        | `Schema.getGlobalDescribe()` — scan for objects with "Competitor" in name that have a Lookup to Opportunity or Account | Custom competitor object exists?                     |
| **Competitor Field on Opportunity** | Check for picklist/text fields with "Competitor" in label                                                              | Inline competitor tracking?                          |
| **CI-Detected Competitors**         | Check Signal_Adapter_Config where Adapter_Type = Gong/Chorus (these detect competitor mentions in calls)               | Competitor detection from conversation intelligence? |

**Updated Question 4 (Competitor Tracking):**

> How do you track competitors on deals?
>
> - [ ] **Standard Competitors related list** (OpportunityCompetitor)
> - [ ] **Custom Competitor object**: {auto-detected: show discovered object name}
> - [ ] **Custom field on Opportunity**: {auto-detected: show discovered field}
> - [ ] **Conversation intelligence flags** (Gong/Chorus competitor mentions)
> - [ ] **Multiple sources** — we use {checkboxes for combination}
> - [ ] **We don't track competitors** — skip competitor signals

**Updated Health_Score_Configuration\_\_c:**

| #   | Field API Name                   | Type      | Label                      | Notes                                                                                            |
| --- | -------------------------------- | --------- | -------------------------- | ------------------------------------------------------------------------------------------------ |
| 15  | `Competitor_Source__c`           | Picklist  | Competitor Source          | **Updated values:** Standard_Competitor, Custom_Object, Custom_Field, CI_Adapter, Multiple, None |
| 16  | `Competitor_Field__c`            | Text(100) | Competitor Field           | For Custom_Field source                                                                          |
| 17  | `Competitor_Object__c`           | Text(100) | Competitor Object API Name | For Custom_Object source. e.g., "Competitor**c", "Competitive_Intel**c"                          |
| 18  | `Competitor_Opp_Lookup_Field__c` | Text(100) | Competitor→Opp Lookup      | The lookup field on the competitor object that links to Opportunity. e.g., "Opportunity\_\_c"    |

**Updated Deal_Signal\_\_c — competitor fields:**

| #   | Field API Name            | Type               | Label              | Notes                                                                                                                                                        |
| --- | ------------------------- | ------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 22  | `Competitor_Mentioned__c` | Checkbox           | Competitor Present | True if ANY source reports competitor presence                                                                                                               |
| 43  | `Competitor_Names__c`     | LongTextArea(2000) | Competitor Names   | JSON array: [{"name": "Clari", "source": "Gong", "mentioned_on": "2027-04-01"}, {"name": "Xactly", "source": "Custom_Object"}]. Aggregated from ALL sources. |
| 44  | `Competitor_Count__c`     | Number(3,0)        | Competitor Count   | How many distinct competitors detected                                                                                                                       |
| 45  | `Primary_Competitor__c`   | Text(100)          | Primary Competitor | Most mentioned or most recent. For quick display.                                                                                                            |

---

### 10.2 Expanded Behavioral Patterns — Sales Performance Intelligence

**Problem:** V1.0 only covers comp-driven patterns (sandbagging, optimism). Real coaching value comes from broader sales performance patterns that help managers understand rep strengths, weaknesses, and habits.

**New detection types added to Detection_Rule**c.Detection_Type**c picklist:**

| Detection Type              | What It Detects                                                                                                  | Data Sources                                                                     | Output                                                                                                                                                |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Deal_Push_Pattern**       | Rep repeatedly pushes deals out of the current period. Not just one-time — systematic pattern across periods.    | Forecast_Change_Event\_\_c (Close_Date_Change + Crossed_Period_Boundary)         | "Rep X has pushed 6 deals out of the current period in the last 3 quarters. Average push: 28 days. 4 of 6 eventually closed in the following period." |
| **Forecast_Accuracy_Rep**   | Per-rep forecast accuracy (not just managers — reps who self-forecast).                                          | Forecast_Override\_\_c submitted values vs. actual close values                  | "Rep X's Commit accuracy is 42% (submitted $2.1M, closed $880K) over last 4 periods. Consistently over-forecasts by 58%."                             |
| **Product_Strength**        | Which products/categories a rep wins or loses disproportionately vs. team average.                               | Comp_Calculation\_\_c grouped by Transaction_Category + Opportunity product data | "Rep X closes 85% of Widget deals (team avg 62%) but only 23% of Service deals (team avg 55%). Consider pairing with SE for Service opportunities."   |
| **Product_Weakness**        | Inverse of above — where a rep significantly underperforms.                                                      | Same as Product_Strength                                                         | Same pattern, flagged for coaching.                                                                                                                   |
| **Deal_Velocity**           | How fast a rep moves deals through pipeline stages relative to deal size and team norms.                         | Opportunity stage history + amount                                               | "Rep X's average deal cycle for deals >$100K is 142 days (team avg 89 days). 3 current deals are already past the team average cycle time."           |
| **Win_Rate_By_Size**        | Rep's close rate segmented by deal size bands. Identifies whether rep struggles with large deals or small deals. | Opportunity (Won/Lost) grouped by amount bands                                   | "Rep X wins 71% of deals <$50K but only 28% of deals >$200K. Team avg for >$200K is 45%."                                                             |
| **Stage_Stall**             | Deals stuck in a stage beyond the team's average time-in-stage for that stage.                                   | Opportunity field history + current stage                                        | "3 deals in Negotiation stage for >30 days (team avg: 14 days for this stage)."                                                                       |
| **Quarter_End_Compression** | Disproportionate percentage of a rep's deals closing in the final 20% of the period.                             | Opportunity close dates relative to period boundaries                            | "72% of Rep X's closed deals in the last 4 periods closed in the final week. Team avg: 35%."                                                          |

**New default Detection_Rule\_\_c records (added to §3.2 library):**

| Rule                           | Type                    | Primary Threshold                          | Secondary             | Severity |
| ------------------------------ | ----------------------- | ------------------------------------------ | --------------------- | -------- |
| Deal Push — Systematic Pattern | Deal_Push_Pattern       | period_push_count ≥ 3 in last 4 periods    | —                     | Medium   |
| Rep Forecast Accuracy — Low    | Forecast_Accuracy_Rep   | commit_accuracy < 50% over 3+ periods      | —                     | Medium   |
| Product Weakness Identified    | Product_Weakness        | category_win_rate < (team_avg - 20%)       | sample_size ≥ 5 deals | Low      |
| Deal Velocity — Slow           | Deal_Velocity           | avg_cycle_days > (team_avg × 1.5)          | deal_count ≥ 3 active | Low      |
| Win Rate — Large Deal Weakness | Win_Rate_By_Size        | win_rate_large < (team_avg_large - 15%)    | sample_size ≥ 5       | Medium   |
| Stage Stall — Extended         | Stage_Stall             | days_in_stage > (team_avg_stage × 2)       | —                     | Low      |
| Quarter-End Compression        | Quarter_End_Compression | final_week_close_pct > 60% over 3+ periods | —                     | Medium   |

**Key design principle (per §6.11):** These patterns are coaching insights, not performance judgments. The language is always:

- "Rep X's pattern shows..." (not "Rep X is bad at...")
- "Consider pairing with..." (not "Rep X needs remediation")
- Flags include the team average for context — never just the individual number

---

### 10.3 AI Provider Configuration — Bring Your Own LLM

**Problem:** V1.0 assumed a single AI service (Claude API). Enterprise customers will want:

- Use their existing Azure OpenAI deployment (data residency, compliance)
- Use Anthropic Claude directly
- Use Salesforce Einstein GPT (if available)
- Use a self-hosted open-source model (Llama, Mistral)
- Use NO LLM at all — only deterministic Tier 1 features

**Solution:** AI Provider abstraction — same pattern as Signal Adapters.

#### AI_Provider_Config\_\_c (AI Provider Configuration — NEW)

| #   | Field API Name                 | Type        | Label                 | Notes                                                                                                                                 |
| --- | ------------------------------ | ----------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Name                           | Text(80)    | Provider Name         | e.g., "Azure OpenAI GPT-4", "Anthropic Claude", "Salesforce Einstein"                                                                 |
| 2   | `Provider_Type__c`             | Picklist    | Provider Type         | Anthropic_Claude, Azure_OpenAI, OpenAI_Direct, Salesforce_Einstein, Google_Gemini, AWS_Bedrock, Self_Hosted, None                     |
| 3   | `Named_Credential__c`          | Text(100)   | Named Credential      | Salesforce Named Credential for auth. Keeps API keys out of the object.                                                               |
| 4   | `Endpoint_URL__c`              | Text(500)   | API Endpoint          | For Azure/Self-Hosted: the specific endpoint URL. Null for managed services.                                                          |
| 5   | `Model_Id__c`                  | Text(100)   | Model ID              | e.g., "claude-sonnet-4-5-20250514", "gpt-4o", "gemini-1.5-pro"                                                                        |
| 6   | `Max_Tokens__c`                | Number(6,0) | Max Response Tokens   | Default: 2000                                                                                                                         |
| 7   | `Temperature__c`               | Number(3,2) | Temperature           | Default: 0.3 (low for deterministic-leaning outputs)                                                                                  |
| —   | **Feature Routing**            |             |                       |                                                                                                                                       |
| 8   | `Use_For_Coaching__c`          | Checkbox    | Coaching Nudges       | Use this provider for generating coaching narratives                                                                                  |
| 9   | `Use_For_Explanations__c`      | Checkbox    | Behavior Explanations | Use for Tier 3 narrative explanations on behavioral flags                                                                             |
| 10  | `Use_For_Dispute__c`           | Checkbox    | Dispute Assistant     | Use for generating commission dispute explanations                                                                                    |
| 11  | `Use_For_NL_Editing__c`        | Checkbox    | NL Forecast Editing   | Use for natural language forecast editing                                                                                             |
| 12  | `Use_For_Close_Probability__c` | Checkbox    | Close Probability     | Use for AI close probability (if LLM-based, not XGBoost)                                                                              |
| —   | **Trust & Compliance**         |             |                       |                                                                                                                                       |
| 13  | `Data_Residency__c`            | Picklist    | Data Residency        | US, EU, APAC, Customer_Managed, Unknown                                                                                               |
| 14  | `PII_Allowed__c`               | Checkbox    | PII Allowed           | Can rep names, account names, and deal details be sent to this provider? Default: false. If false, data is anonymized before sending. |
| 15  | `Audit_Logging__c`             | Checkbox    | Log All Requests      | If true, every API request/response is logged (AI_Request_Log\_\_c). For compliance.                                                  |
| —   | **Operational**                |             |                       |                                                                                                                                       |
| 16  | `Is_Active__c`                 | Checkbox    | Active                |                                                                                                                                       |
| 17  | `Is_Default__c`                | Checkbox    | Default Provider      | Fallback when no feature-specific routing matches                                                                                     |
| 18  | `Last_Tested_On__c`            | DateTime    | Last Connection Test  |                                                                                                                                       |
| 19  | `Test_Status__c`               | Picklist    | Test Status           | Not_Tested, Success, Failed                                                                                                           |
| 20  | `Rate_Limit_RPM__c`            | Number(5,0) | Rate Limit (req/min)  | Platform-side rate limiting to stay within provider quotas                                                                            |
| 21  | `Monthly_Cost_Estimate__c`     | Currency    | Est. Monthly Cost     | Based on usage patterns. Admin visibility.                                                                                            |

**Total: 21 fields.**

#### AI_Request_Log\_\_c (AI Audit Log — NEW, optional)

**Purpose:** When `Audit_Logging__c = true`, every AI request/response is logged for compliance. Enterprise customers in regulated industries (Financial Services, Healthcare) may require this.

| #   | Field API Name         | Type                | Label           | Notes                                                               |
| --- | ---------------------- | ------------------- | --------------- | ------------------------------------------------------------------- |
| 1   | `Provider__c`          | Lookup              | AI Provider     | → AI_Provider_Config\_\_c                                           |
| 2   | `Feature__c`           | Picklist            | Feature         | Coaching, Explanation, Dispute, NL_Editing, Close_Probability       |
| 3   | `Request_Prompt__c`    | LongTextArea(32000) | Request Prompt  | The full prompt sent to the LLM (may be anonymized per PII_Allowed) |
| 4   | `Response_Text__c`     | LongTextArea(32000) | Response        | The full LLM response                                               |
| 5   | `Model_Used__c`        | Text(100)           | Model           | Actual model that responded                                         |
| 6   | `Tokens_In__c`         | Number(6,0)         | Input Tokens    |                                                                     |
| 7   | `Tokens_Out__c`        | Number(6,0)         | Output Tokens   |                                                                     |
| 8   | `Latency_Ms__c`        | Number(6,0)         | Latency (ms)    | Response time                                                       |
| 9   | `Was_Anonymized__c`    | Checkbox            | Data Anonymized | True if PII was stripped before sending                             |
| 10  | `Related_Record_Id__c` | Text(18)            | Related Record  | Behavioral_Flag, Coaching_Nudge, Incentive_Dispute, etc.            |
| 11  | `Status__c`            | Picklist            | Status          | Success, Error, Timeout, Rate_Limited                               |
| 12  | `Error_Message__c`     | Text(500)           | Error           | If failed                                                           |
| 13  | `Created_On__c`        | DateTime            | Created         |                                                                     |

**Total: 13 fields.**

**Retention:** AI_Request_Log\_\_c records are purged per configurable retention (default: 90 days). Regulated orgs can extend.

#### Onboarding — AI Configuration (New Question)

**Question 6: AI / LLM Configuration**

> RevenueTrust uses AI for coaching nudges, behavior explanations, dispute assistance, and natural language editing. All AI features are optional — the platform works fully without them.
>
> How would you like to configure AI?
>
> - [ ] **Use RevenueTrust's AI** — We provide the AI service (Anthropic Claude). No setup needed. Data processed per our security policy.
> - [ ] **Bring Your Own — Azure OpenAI** — Use your organization's Azure OpenAI deployment. You provide: endpoint URL, API key (via Named Credential), model ID.
> - [ ] **Bring Your Own — OpenAI Direct** — Use your OpenAI API key. You provide: API key (via Named Credential).
> - [ ] **Bring Your Own — Google Gemini / Vertex AI** — You provide: project ID, service account.
> - [ ] **Bring Your Own — AWS Bedrock** — You provide: AWS credentials, model ARN.
> - [ ] **Salesforce Einstein GPT** — Use Salesforce's built-in AI (if enabled in your org).
> - [ ] **Self-Hosted Model** — You provide: endpoint URL, auth credentials, model details.
> - [ ] **No AI** — Disable all Tier 2 predictive and Tier 3 narrative features. Platform operates on Tier 1 deterministic features only.
>
> **Data Handling:**
>
> - [ ] **Allow PII in AI requests** — Rep names, account names, and deal details sent to AI provider (better quality results)
> - [ ] **Anonymize all data** — All identifying information stripped before sending to AI (reduced quality but maximum privacy)
> - [ ] **Log all AI requests** — Every AI interaction recorded for compliance audit (recommended for regulated industries)

**How the engine uses it:**

```
AI Feature Request Flow:
  1. Feature needs AI (e.g., coaching nudge generation)
  2. Check AI_Provider_Config__c where Use_For_Coaching = true AND Is_Active = true
  3. If no provider found → check Is_Default provider
  4. If no provider at all → skip AI. Generate from rule templates only (Tier 1).
  5. If provider found:
     a. Build prompt from structured data (Behavioral_Flag fields, Deal_Signal fields, etc.)
     b. If PII_Allowed = false → anonymize (replace names with "[Rep A]", "[Account X]")
     c. Call provider API via Named Credential
     d. If Audit_Logging = true → create AI_Request_Log__c
     e. Return response
     f. If error/timeout → fall back to rule-template output
  6. User always sees structured Tier 1 data alongside any AI narrative
```

**Key guarantee (from AI Trust Boundaries §9.2):** If AI is unavailable (no provider configured, API down, rate limited), ALL core features still work. AI is enhancement, never dependency.

---

### 10.4 Updated Detection_Rule**c.Detection_Type**c Values (Consolidated)

**Full picklist values after V1.1:**

Comp-driven patterns (original):
`Sandbagging`, `Optimism_Bias`, `Timing_Concentration`, `Period_Slip_Loop`, `Threshold_Approach`, `Category_Regression`, `Coverage_Gap`, `Staleness`

Sales performance patterns (V1.1 additions):
`Deal_Push_Pattern`, `Forecast_Accuracy_Rep`, `Product_Strength`, `Product_Weakness`, `Deal_Velocity`, `Win_Rate_By_Size`, `Stage_Stall`, `Quarter_End_Compression`

**Total: 16 detection types.**

---

### 10.5 Updated Object Count — V1.1

| Type                                    | Count                 | Objects                                                                        |
| --------------------------------------- | --------------------- | ------------------------------------------------------------------------------ |
| **Deal Health — Config**                | 3                     | Health_Score_Configuration**c, Health_Score_Component**c, Adjustment_Rule\_\_c |
| **Deal Health — Signal Infrastructure** | 1                     | Signal_Adapter_Config\_\_c                                                     |
| **Deal Health — Runtime**               | 2                     | Deal_Signal**c, Deal_Signal_History**c                                         |
| **Behavior Intel — Config**             | 2                     | Behavior_Detection_Config**c, Detection_Rule**c                                |
| **Behavior Intel — Runtime**            | 3                     | Behavioral_Flag**c, Manager_Accuracy**c, Coaching_Nudge\_\_c                   |
| **AI Infrastructure (NEW)**             | 2                     | **AI_Provider_Config\_\_c**, **AI_Request_Log\_\_c**                           |
| **Module Total**                        | **13 custom objects** |                                                                                |
| Cross-Module (shared)                   | 2                     | Governance_Event**c, Failed_Event**c                                           |

**Net change from V1.0:** +2 objects (AI_Provider_Config**c, AI_Request_Log**c), +4 fields on Deal_Signal\_\_c for competitors, 8 new detection types.

---

### 10.6 Updated Field Count

| Object                          | Fields    | Change                                                           |
| ------------------------------- | --------- | ---------------------------------------------------------------- |
| Health_Score_Configuration\_\_c | 18        | +2 (competitor object/lookup fields)                             |
| Deal_Signal\_\_c                | 45        | +3 (Competitor_Names JSON, Competitor_Count, Primary_Competitor) |
| AI_Provider_Config\_\_c         | 21        | NEW                                                              |
| AI_Request_Log\_\_c             | 13        | NEW                                                              |
| All other objects               | unchanged |                                                                  |
| **Module Total**                | **~216**  | +39 from V1.0                                                    |

**Updated Platform Total:**
| Module | Objects | Fields |
|---|---|---|
| Forecasting | 12 | 224 |
| Incentives | 27 | 353 |
| Deal Health + Behavior Intel | 13 | 216 |
| Cross-Module (shared) | 2 | 26 |
| **PLATFORM TOTAL** | **54** | **~819** |

---

---

## 11. V1.2 FINAL TIGHTENING — SPEC FREEZE PASS

### 11.1 Fix #1: Component Slot Binding Invariant

**Explicit rule (mirrors Forecasting §9.4 metric slot immutability):**

> `Health_Score_Component__c.Component_Code__c` must be permanently bound to a Deal_Signal\_\_c slot for a given configuration:
>
> - `CI` → `Component_1_Score__c`
> - `REL` → `Component_2_Score__c`
> - `ACT` → `Component_3_Score__c`
> - `ENG` → `Component_4_Score__c`
>
> **Once Deal_Signal_History\_\_c records exist for this configuration, rebinding a code to a different slot is blocked** (validation rule on Health_Score_Component\_\_c before-update).
>
> Labels and weights CAN change. Slot binding CANNOT. Adding a new component to slot 5 or 6 is always permitted.

---

### 11.2 Fix #2: Historical Signal Auditability Boundary

**Explicit statement:**

> **The platform guarantees auditability of score changes, not full historical reconstruction of every raw signal value.**
>
> - `Deal_Signal__c` stores the **current** canonical signal values. When signals update, old values are overwritten.
> - `Deal_Signal_History__c` stores **score-change deltas** with component-level breakdowns (`Component_Deltas__c` JSON). This preserves WHY a score changed, but not the full signal state at every past point in time.
> - For V1 this is sufficient: an auditor can trace "score went from 72 to 58 because Activity Recency dropped from 85 to 45 after 14 days of inactivity."
> - V2 consideration: if customers need full historical signal replay (e.g., "what was the exact stakeholder count on March 15?"), a `Deal_Signal_Snapshot__c` object would be needed. Not required for V1.

---

### 11.3 Fix #3: Detection Rule Operand Vocabulary

**Problem:** Generic `Threshold_1_Field__c` text field could reference arbitrary or undefined data points.

**Solution:** Define a controlled operand catalog.

**New object: Detection_Operand\_\_c (Reference Data — Custom Object)**

| #   | Field API Name    | Type      | Label        | Notes                                                                                                                                                 |
| --- | ----------------- | --------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Name              | Text(80)  | Operand Name | e.g., "Attainment %", "Health Score", "Days to Period End"                                                                                            |
| 2   | `Operand_Code__c` | Text(50)  | Operand Code | Machine-readable key: "attainment_pct", "health_score", "days_to_period_end", "deal_count_committed", etc.                                            |
| 3   | `Data_Source__c`  | Picklist  | Data Source  | Quota (attainment), Deal_Signal (health), Forecast_Override (categories), Forecast_Period (dates), Comp_Calculation (deals), CRM (opportunity fields) |
| 4   | `Data_Type__c`    | Picklist  | Data Type    | Percent, Number, Currency, Date, Boolean                                                                                                              |
| 5   | `Description__c`  | Text(255) | Description  | Plain-English: "The participant's current quota attainment as a percentage"                                                                           |
| 6   | `Is_Active__c`    | Checkbox  | Active       |                                                                                                                                                       |

**Detection_Rule\_\_c Threshold fields updated:**

`Threshold_1_Field__c` and `Threshold_2_Field__c` now reference `Detection_Operand__c.Operand_Code__c` values (validated by trigger) — not arbitrary field API names.

**Default operands shipped (seed data):**

| Operand Code              | Source                | Type    | Description                                            |
| ------------------------- | --------------------- | ------- | ------------------------------------------------------ |
| `attainment_pct`          | Quota                 | Percent | Current period quota attainment                        |
| `health_score`            | Deal_Signal           | Number  | Composite health score 0-100                           |
| `days_to_period_end`      | Forecast_Period       | Number  | Calendar days remaining in current period              |
| `deal_push_count`         | Forecast_Change_Event | Number  | Times a deal's close date was pushed out of period     |
| `committed_deal_count`    | Forecast_Override     | Number  | Number of deals in high-confidence categories          |
| `historical_win_rate`     | Comp_Calculation      | Percent | Rep's win rate on high-confidence deals over N periods |
| `no_activity_days`        | Deal_Signal           | Number  | Days since last mutual activity on a deal              |
| `consecutive_slips`       | Deal_Signal           | Number  | Consecutive period close-date slips                    |
| `coverage_ratio`          | Forecast_Snapshot     | Number  | Pipeline ÷ remaining quota                             |
| `stage_days`              | Deal_Signal           | Number  | Days in current stage                                  |
| `category_moved_backward` | Forecast_Change_Event | Boolean | Deal moved to a lower-confidence category              |
| `close_pct_final_week`    | Comp_Calculation      | Percent | % of rep's closed deals in final week of period        |
| `category_win_rate`       | Comp_Calculation      | Percent | Win rate for deals in a specific transaction category  |
| `avg_cycle_days`          | CRM                   | Number  | Average days from opportunity creation to close        |
| `team_avg_cycle_days`     | CRM                   | Number  | Team average cycle days (for comparison)               |

**Total: 6 fields on Detection_Operand\_\_c. 15 default operands shipped.**

---

### 11.4 Fix #4: Flag → Nudge Non-Recursion Rule

**Explicit invariant:**

> **Flags generate nudges. Nudges NEVER strengthen flags.**
>
> - A Behavioral_Flag**c record MAY trigger the creation of a Coaching_Nudge**c record.
> - A Coaching_Nudge**c record (whether actioned, dismissed, or ignored) MUST NOT be used as evidence for ANY Behavioral_Flag**c — including the flag that generated it.
> - Nudge action/dismissal data is tracked for nudge effectiveness analytics only, not for behavioral pattern detection.
> - The detection engine reads ONLY from: Forecast_Override**c, Forecast_Change_Event**c, Quota**c, Commission_Tier**c, Deal_Signal**c, and Comp_Calculation**c. It NEVER reads from Coaching_Nudge\_\_c.

---

### 11.5 Fix #5: Close Probability Routing Clarification

**Explicit statement on AI_Provider_Config**c.Use_For_Close_Probability**c:**

> This flag governs whether an **LLM-based probability service** is used for close probability estimation. It does NOT imply that all close probability must be LLM-generated.
>
> **Recommended architecture:**
>
> - **Primary:** Statistical/ML model (XGBoost/LightGBM) running as an external microservice. This is the default close probability engine. It does NOT use the AI Provider config — it has its own dedicated service endpoint.
> - **Optional LLM enrichment:** If `Use_For_Close_Probability__c = true`, the LLM generates a **narrative explanation** of the probability factors (Tier 3), not the probability number itself (Tier 2).
> - The probability NUMBER is always from the statistical model. The EXPLANATION may optionally be from the LLM.
>
> This prevents engineers from accidentally building LLM-dependent probability scoring, which would be slower, more expensive, and less reproducible than a statistical model.

---

### 11.6 Fix #6: Competitor Multi-Source Conflict Resolution

**Explicit merge rules for competitor data:**

| Field                                | Merge Rule                                                                                                                                                                                                           |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Competitor_Mentioned__c` (Checkbox) | **Union — any source triggers true.** If ANY source reports a competitor, this is true.                                                                                                                              |
| `Competitor_Names__c` (JSON array)   | **Union + dedupe by normalized name.** All sources contribute. Names normalized to title case, trimmed. Deduped by fuzzy match (e.g., "Clari" and "Clari Inc" → "Clari"). Each entry retains its source attribution. |
| `Competitor_Count__c` (Number)       | Count of unique deduped names in `Competitor_Names__c`.                                                                                                                                                              |
| `Primary_Competitor__c` (Text)       | **Most recent mention wins.** If two competitors mentioned same day, the one from the highest-priority source wins (CI adapter > custom object > custom field > standard competitor).                                |
| Adjustment rule trigger              | **Any source can trigger.** If the Competitor_Mentioned adjustment rule is active, it fires when `Competitor_Mentioned__c = true` regardless of which source set it.                                                 |

---

### 11.7 Fix #7: Freshness Display Rule

**Explicit UI rule:**

> `Deal_Signal__c.Signal_Freshness__c` (overall) uses **worst of all active adapters** — this is correct and conservative.
>
> **However, the UI MUST display both levels:**
>
> - **Overall freshness badge** on the health score (Green/Yellow/Red + freshness icon)
> - **Per-component freshness** in the score card breakdown panel — each component shows its adapter's individual freshness state
>
> This prevents user confusion: "The overall badge says STALE, but that's only because Gong sync failed. CRM signals are LIVE and Activity Recency is still current."

---

### 11.8 Fix #8: Rep Accuracy → Rename to Forecast_Accuracy\_\_c

**Problem:** `Manager_Accuracy__c` name implies manager-only. With `Forecast_Accuracy_Rep` detection type added, rep-level accuracy is also needed.

**Resolution:** Rename `Manager_Accuracy__c` → **`Forecast_Accuracy__c`** (general purpose). Add a field to distinguish:

| #   | Field API Name     | Type     | Label         | Notes                                                                                                                                              |
| --- | ------------------ | -------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 13  | `Accuracy_Type__c` | Picklist | Accuracy Type | Manager, Rep, Team. Determines whether this record tracks a manager's rollup accuracy, an individual rep's forecast accuracy, or a team aggregate. |

One record per User per Accuracy_Type. A manager would have TWO records: one for their Manager accuracy (rollup quality) and one for their Rep accuracy (their own deals if they carry a book).

---

### 11.9 Retention Policies (Missing from V1.0/V1.1)

**Deal_Signal_History\_\_c retention:**

> Records older than **2 completed fiscal years** are eligible for archival. Configurable via `Health_Score_Configuration__c.History_Retention_Years__c` (Number, default: 2).
>
> At 5,000 opps × daily recalc = ~1.8M records/year. 2-year retention = ~3.6M active records. Archival via Big Object or external export (same pattern as Forecasting Change Event retention §12.6).

**New field on Health_Score_Configuration\_\_c:**

| #   | Field API Name               | Type        | Label                     | Notes      |
| --- | ---------------------------- | ----------- | ------------------------- | ---------- |
| 19  | `History_Retention_Years__c` | Number(2,0) | History Retention (Years) | Default: 2 |

**Coaching_Nudge\_\_c retention:**

> Nudges with Status = Delivered/Dismissed/Expired older than **180 days** are eligible for archival. Configurable via `Behavior_Detection_Config__c.Nudge_Retention_Days__c` (Number, default: 180).
>
> Actioned nudges retained longer (365 days) for effectiveness analytics.

**New field on Behavior_Detection_Config\_\_c:**

| #   | Field API Name            | Type        | Label                  | Notes                               |
| --- | ------------------------- | ----------- | ---------------------- | ----------------------------------- |
| 12  | `Nudge_Retention_Days__c` | Number(4,0) | Nudge Retention (Days) | Default: 180. Actioned nudges: 365. |

---

### 11.10 Stale Section Supersession

| Section                                                 | Status         | Superseded By                                        |
| ------------------------------------------------------- | -------------- | ---------------------------------------------------- |
| **§2.1** Health_Score_Configuration\_\_c (16 fields)    | ~~SUPERSEDED~~ | §11.12 consolidated list (19 fields)                 |
| **§2.5** Deal_Signal\_\_c (42 fields)                   | ~~SUPERSEDED~~ | §11.12 consolidated list (45 fields)                 |
| **§3.3** Behavioral_Flag**c.Flag_Type**c (8 values)     | ~~SUPERSEDED~~ | §10.4 consolidated list (16 values)                  |
| **§3.2** Detection_Rule**c.Detection_Type**c (8 values) | ~~SUPERSEDED~~ | §10.4 consolidated list (16 values)                  |
| **§3.4** Manager_Accuracy\_\_c                          | ~~SUPERSEDED~~ | §11.8 — renamed to Forecast_Accuracy\_\_c (+1 field) |
| **§7** Object Count (11 objects)                        | ~~SUPERSEDED~~ | §11.11 (15 objects)                                  |
| **§8** Field Count (177 fields)                         | ~~SUPERSEDED~~ | §11.12 (~240 fields)                                 |
| **§8** Platform Total (52 objects, ~780 fields)         | ~~SUPERSEDED~~ | §11.12 (56 objects, ~843 fields)                     |

**Companion spec reference added:** REVENUETRUST_OBJECT_MODEL.md (for Governance_Event**c and Failed_Event**c cross-module definitions).

---

### 11.11 Final Object Count

| Type                                    | Count                 | Objects                                                                         |
| --------------------------------------- | --------------------- | ------------------------------------------------------------------------------- |
| **Deal Health — Config**                | 3                     | Health_Score_Configuration**c, Health_Score_Component**c, Adjustment_Rule\_\_c  |
| **Deal Health — Signal Infrastructure** | 1                     | Signal_Adapter_Config\_\_c                                                      |
| **Deal Health — Runtime**               | 2                     | Deal_Signal**c, Deal_Signal_History**c                                          |
| **Behavior Intel — Config**             | 2                     | Behavior_Detection_Config**c, Detection_Rule**c                                 |
| **Behavior Intel — Reference**          | 1                     | **Detection_Operand\_\_c** (NEW — controlled operand vocabulary)                |
| **Behavior Intel — Runtime**            | 3                     | Behavioral_Flag**c, \*\*Forecast_Accuracy**c\*\* (renamed), Coaching_Nudge\_\_c |
| **AI Infrastructure**                   | 2                     | AI_Provider_Config**c, AI_Request_Log**c                                        |
| **Module Total**                        | **15 custom objects** |                                                                                 |
| Cross-Module (shared)                   | 2                     | Governance_Event**c, Failed_Event**c                                            |

**Net change from V1.1:** +2 (Detection_Operand\_\_c, Manager_Accuracy renamed to Forecast_Accuracy with +1 field)

---

### 11.12 Consolidated Field Count (for AppExchange Security Review)

| Object                          | Fields   | Source                                                                         |
| ------------------------------- | -------- | ------------------------------------------------------------------------------ |
| Health_Score_Configuration\_\_c | 19       | §2.1 (16) + §10.1 (2: competitor object/lookup) + §11.9 (1: history retention) |
| Health_Score_Component\_\_c     | 10       | §2.2                                                                           |
| Adjustment_Rule\_\_c            | 10       | §2.3                                                                           |
| Signal_Adapter_Config\_\_c      | 16       | §2.4                                                                           |
| Deal_Signal\_\_c                | 45       | §2.5 (42) + §10.1 (3: competitor fields)                                       |
| Deal_Signal_History\_\_c        | 9        | §2.6                                                                           |
| Behavior_Detection_Config\_\_c  | 12       | §3.1 (11) + §11.9 (1: nudge retention)                                         |
| Detection_Rule\_\_c             | 14       | §3.2                                                                           |
| Detection_Operand\_\_c          | 6        | §11.3 (NEW)                                                                    |
| Behavioral_Flag\_\_c            | 23       | §3.3                                                                           |
| Forecast_Accuracy\_\_c          | 13       | §3.4 (12) + §11.8 (1: accuracy type)                                           |
| Coaching_Nudge\_\_c             | 14       | §3.5                                                                           |
| AI_Provider_Config\_\_c         | 21       | §10.3                                                                          |
| AI_Request_Log\_\_c             | 13       | §10.3                                                                          |
| **Module Total**                | **~225** |                                                                                |

**Updated Platform Total:**

| Module                       | Objects                 | Fields   |
| ---------------------------- | ----------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Forecasting                  | 12 (10 obj + 2 CMT)     | 224      |
| Incentives                   | 27 (26 obj + Territory) | 353      |
| Deal Health + Behavior Intel | 15                      | 225      |
| Cross-Module (shared)        | 2                       | 26       |
| **PLATFORM TOTAL**           | **56**                  | **~828** | _Note: This total reflects H&B V1.2 snapshot. Current platform total (after Incentives V2.0) is 66 objects, ~983 fields — see INCENTIVES_OBJECT_MODEL.md §18.4 for authoritative count._ |

---

_Deal Health & Behavior Intelligence Object Model V1.2 — Spec Frozen_  
_Slot binding invariant. Historical auditability boundary. Controlled detection operands._  
_Flag→Nudge non-recursion. Close probability routing clarified. Competitor merge rules._  
_Forecast_Accuracy\_\_c generalized. Retention policies defined. 15 objects, ~225 fields._
