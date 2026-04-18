# RevenueTrust — Complete Object Model Definition

**Version:** 1.0  
**Date:** April 2, 2026  
**Purpose:** Definitive reference for all custom objects, fields, and metadata types before code generation.  
**Spec Reference:** UNIFIED_PLATFORM_SPEC.md V5.0  
**Implementation Reference:** RevenueTrust_Implementation_Sequence_V1_0.md

---

## Naming Convention

- All objects use the managed package namespace prefix: `RevenueTrust__` (applied automatically by packaging)
- During development in a Developer Edition org, objects use standard `__c` / `__mdt` / `__e` suffixes without namespace
- Field API names are generic (no Kony/Temenos terminology)
- Labels are user-friendly and industry-agnostic

---

## Object Inventory

### Legend

| Column          | Meaning                                                                                                                                                  |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Source**      | `KONY` = ported from KONY ORG, `TEM` = ported from Temenos ORG, `NEW` = brand new                                                                        |
| **Port Action** | `As-Is` = field structure reused, `Rename` = API name changed to be generic, `Redesign` = logic kept but field structure rebuilt, `New` = no predecessor |

---

## 1. FORECASTING MODULE OBJECTS

### 1.1 Forecast\_\_c (Forecast Period)

Question: Should we have this as Forecast_Period**c?
**Source:** Temenos `Forecast**c`  
**Purpose:** Represents one forecast period/batch. Controls Budget Mode, status, and period boundaries.

| #   | Field API Name         | Type        | Label             | Source | Port Action | Notes                                               |
| --- | ---------------------- | ----------- | ----------------- | ------ | ----------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 1   | `Status__c`            | Picklist    | Status            | TEM    | As-Is       | Values: Open, Submitted, Frozen                     |
| 2   | `Budget_Mode__c`       | Checkbox    | Budget Mode       | TEM    | As-Is       | Switches template to budget categories              |
| 3   | `Start_Date__c`        | Date        | Start Date        | TEM    | Rename      | Was `Start_Quarter__c` — now generic                |
| 4   | `End_Date__c`          | Date        | End Date          | NEW    | New         | Explicit end date (was computed from quarter)       |
| 5   | `Period_Label__c`      | Text(50)    | Period Label      | NEW    | New         | e.g., "Q2 FY2027", "March 2027", "Week 14"          | Question: Shouldnt we populate this automatically based on som new general settings object? |
| 6   | `Period_Type__c`       | Picklist    | Period Type       | NEW    | New         | Values: Weekly, Monthly, Quarterly, Annual          |
| 7   | `Fiscal_Year__c`       | Text(10)    | Fiscal Year       | NEW    | New         | e.g., "FY2027"                                      |
| 8   | `Prelock_Days__c`      | Number(3,0) | Prelock Days      | TEM    | Rename      | Was `Prelock_Time_in_Days__c`                       |
| 9   | `Cutoff_Date__c`       | Date        | Cutoff Date       | TEM    | As-Is       |                                                     |
| 10  | `Forecast_Template__c` | Lookup      | Forecast Template | NEW    | New         | → Forecast_Template\_\_mdt (Phase 2: custom object) |
| 11  | `Notification_Sent__c` | Checkbox    | Notification Sent | TEM    | Rename      | Was `Send_Notification_Forecast_Is_Open__c`         |

---

### 1.2 Forecast_Override\_\_c (Forecast Override)

**Source:** Temenos `Forecast_Override__c`  
**Purpose:** Per-pipeline-record override per hierarchy level. The core IP of the forecasting module. Self-referential lookups for previous level and previous period.

| #   | Field API Name                | Type                | Label                       | Source | Port Action | Notes                                                                               |
| --- | ----------------------------- | ------------------- | --------------------------- | ------ | ----------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 1   | `Forecast__c`                 | Lookup              | Forecast Period             | TEM    | As-Is       | → Forecast\_\_c                                                                     |
| 2   | `Opportunity__c`              | Lookup              | Pipeline Record             | TEM    | As-Is       | → Opportunity (subscriber's pipeline object)                                        |
| 3   | `User__c`                     | Lookup              | Participant                 | TEM    | As-Is       | → User                                                                              |
| 4   | `Forecast_User__c`            | Lookup              | Forecast Participant        | TEM    | As-Is       | → Forecast_User\_\_c                                                                |
| 5   | `User_Manager__c`             | Lookup              | Participant Manager         | TEM    | Rename      | Was `User_s_Manager__c`                                                             |
| 6   | `Previous_Level_Override__c`  | Lookup(self)        | Previous Level Override     | TEM    | Rename      | Was `Previous_Level_Forecast_Override__c`                                           |
| 7   | `Previous_Period_Override__c` | Lookup(self)        | Previous Period Override    | TEM    | Rename      | Was `Previous_Forecast_Override__c`                                                 |
| 8   | `Forecast_Category__c`        | Picklist            | Forecast Category           | TEM    | As-Is       | Values configured per template (default: Commit/Best Case/Pipeline/Closed Won/Lost) |
| 9   | `Status__c`                   | Picklist            | Status                      | TEM    | As-Is       | Values: New, Saved, Submitted, Frozen                                               |
| 10  | `Metric_1__c`                 | Currency            | Primary Metric              | TEM    | Redesign    | Was `NBV__c` — now generic                                                          | Question: Will we have some kind of Label mapping in Custom Metadata?                                     |
| 11  | `Metric_2__c`                 | Currency            | Secondary Metric            | TEM    | Redesign    | Was `Incremental_ACV__c` — now generic                                              | Question: Will we have some kind of Label mapping in Custom Metadata?                                     |
| 12  | `Metric_1_Local__c`           | Currency            | Primary Metric (Local)      | TEM    | Redesign    | Was `NBV_Local__c`                                                                  | Question: Will we have some kind of Label mapping in Custom Metadata?                                     |
| 13  | `Metric_2_Local__c`           | Currency            | Secondary Metric (Local)    | TEM    | Redesign    | Was `ACV_Local__c`                                                                  | Question: Will we have some kind of Label mapping in Custom Metadata?                                     |
| 14  | `Close_Date_Override__c`      | Date                | Close Date Override         | TEM    | As-Is       |                                                                                     |
| 15  | `Currency_Exchange_Rate__c`   | Number(18,6)        | Currency Exchange Rate      | TEM    | As-Is       |                                                                                     | Question: Are we going to get this from Dated Exchange Rates?                                             |
| 16  | `Local_Currency_Rate__c`      | Number(18,6)        | Local Currency Rate         | TEM    | Rename      | Was `Local_Currency_Exchange_Rate__c`                                               | Question: What is the difference between Currency_Exchange_Rate\_\_c and this?                            |
| 17  | `Hierarchy_Level__c`          | Number(2,0)         | Hierarchy Level             | TEM    | Redesign    | Was picklist `Type__c` (Manager/Sub-Director/Director/COO) — now integer 1-N        |
| 18  | `Territory_Id__c`             | Text(50)            | Territory ID                | TEM    | As-Is       | Scope grouping key                                                                  | Question: Whre are we managing Territories? What if the Org has already implemented Territory Management? |
| 19  | `Subregion__c`                | Text(100)           | Scope Sub-Group             | TEM    | Rename      | Was territory-specific — now generic                                                | Question: Whre are we managing Territories? What if the Org has already implemented Territory Management? |
| 20  | `Valid__c`                    | Checkbox            | Valid                       | TEM    | As-Is       |                                                                                     |
| 21  | `Frozen__c`                   | Checkbox            | Frozen                      | TEM    | As-Is       |                                                                                     |
| 22  | `Saved_On__c`                 | DateTime            | Saved On                    | TEM    | As-Is       |                                                                                     |
| 23  | `Submitted_On__c`             | DateTime            | Submitted On                | TEM    | As-Is       |                                                                                     |
| 24  | `Comment__c`                  | TextArea(500)       | Comment                     | TEM    | As-Is       | Inline comment                                                                      |
| 25  | `Notes__c`                    | LongTextArea(32000) | Notes                       | TEM    | As-Is       | Extended notes                                                                      |
| 26  | `External_Id__c`              | Text(50)            | External ID                 | TEM    | As-Is       | Unique, External ID                                                                 |
| 27  | `Pending_Approval__c`         | Checkbox            | Pending Governance Approval | NEW    | New         | CG-3 hard block flag (§7.3.6)                                                       |
| 28  | `Close_Probability__c`        | Percent             | AI Close Probability        | NEW    | New         | Tier 2 AI output (§9.2.1)                                                           | Question: Shouldnt we also have field explaining how we arrived at the probability?                       |
| 29  | `Source_Record_Deleted__c`    | Checkbox            | Source Record Deleted       | NEW    | New         | §1.5.2 CRM deletion handling                                                        |

**Formula Fields (computed, not stored):**

| #   | Field API Name      | Type            | Label                  | Source | Notes                                       |
| --- | ------------------- | --------------- | ---------------------- | ------ | ------------------------------------------- | ------------------------------------------------------------------------- |
| F1  | `Metric_1_Trend__c` | Number(Formula) | Primary Metric Trend   | TEM    | Compares to previous period value           |
| F2  | `Metric_2_Trend__c` | Number(Formula) | Secondary Metric Trend | TEM    | Compares to previous period value           |
| F3  | `Category_Trend__c` | Number(Formula) | Category Trend         | TEM    | Numeric representation of category movement |
| F4  | `Opp_Owner_Name__c` | Text(Formula)   | Record Owner           | TEM    | From Opportunity.Owner.Name                 |
| F5  | `Opp_Stage__c`      | Text(Formula)   | Record Stage           | TEM    | From Opportunity.StageName                  |
| F6  | `Opp_Close_Date__c` | Date(Formula)   | Record Close Date      | TEM    | From Opportunity.CloseDate                  |
| F7  | `Opp_Number__c`     | Text(Formula)   | Record Number          | TEM    | From Opportunity auto-number                | Question: This may exist in some orgs and in other Orgs it may not exist. |

---

### 1.3 Forecast_User\_\_c (Forecast Participant)

**Source:** Temenos `Forecast_User__c`  
**Purpose:** Assigns a user to a territory/scope within a forecast period. Defines their hierarchy level and submission status.

| #   | Field API Name        | Type         | Label               | Source | Port Action | Notes                                                         |
| --- | --------------------- | ------------ | ------------------- | ------ | ----------- | ------------------------------------------------------------- |
| 1   | `Forecast__c`         | Lookup       | Forecast Period     | TEM    | As-Is       | → Forecast\_\_c                                               |
| 2   | `User__c`             | Lookup       | Participant         | NEW    | New         | Standard Name field links to User via Forecast_Manager\_\_c   |
| 3   | `Forecast_Manager__c` | Lookup       | Forecast Manager    | TEM    | As-Is       | → User (the manager of this participant)                      |
| 4   | `Reports_To__c`       | Lookup(self) | Reports To          | TEM    | As-Is       | → Forecast_User\_\_c (hierarchy chain)                        |
| 5   | `Forecast_Level__c`   | Number(2,0)  | Hierarchy Level     | TEM    | Redesign    | Was Picklist (Manager/Sub-Dir/Director/COO) — now integer 1-N |
| 6   | `Forecast_Status__c`  | Picklist     | Submission Status   | TEM    | As-Is       | Values: Not Started, Saved, Submitted, Frozen                 |
| 7   | `Territory_Id__c`     | Text(50)     | Territory ID        | TEM    | As-Is       |                                                               |
| 8   | `Territory_Name__c`   | Text(100)    | Territory Name      | TEM    | As-Is       |                                                               |
| 9   | `Region__c`           | Text(100)    | Scope Group         | TEM    | Redesign    | Was Picklist — now Text for configurability                   |
| 10  | `Sub_Region__c`       | Text(100)    | Scope Sub-Group     | TEM    | Redesign    | Was Picklist — now Text                                       |
| 11  | `Local_Currency__c`   | Text(5)      | Local Currency      | TEM    | As-Is       | ISO currency code                                             |
| 12  | `Saved_On__c`         | DateTime     | Saved On            | TEM    | As-Is       |                                                               |
| 13  | `Submitted_On__c`     | DateTime     | Submitted On        | TEM    | As-Is       |                                                               |
| 14  | `Frozen_On__c`        | DateTime     | Frozen On           | TEM    | As-Is       |                                                               |
| 15  | `Email_Recipients__c` | Text(255)    | Email Recipients    | TEM    | As-Is       | Notification targets                                          |
| 16  | `Delegate__c`         | Lookup       | Approval Delegate   | NEW    | New         | → User. For governance approval delegation (§7.3.6)           |
| 17  | `Delegate_Start__c`   | Date         | Delegate Start Date | NEW    | New         |                                                               |
| 18  | `Delegate_End__c`     | Date         | Delegate End Date   | NEW    | New         |                                                               |

---

### 1.4 Forecast_Comment\_\_c (Forecast Comment)

**Source:** Temenos `Forecast_Comment__c`  
**Purpose:** Historical notes per pipeline record per forecast period.

| #   | Field API Name    | Type                | Label           | Source | Port Action | Notes                                                            |
| --- | ----------------- | ------------------- | --------------- | ------ | ----------- | ---------------------------------------------------------------- |
| 1   | `Opportunity__c`  | Lookup              | Pipeline Record | TEM    | As-Is       | → Opportunity                                                    |
| 2   | `Comment__c`      | LongTextArea(32000) | Comment         | TEM    | As-Is       |                                                                  |
| 3   | `Forecast__c`     | Lookup              | Forecast Period | NEW    | New         | → Forecast\_\_c (missing in Temenos — needed for period scoping) |
| 4   | `User__c`         | Lookup              | Author          | NEW    | New         | → User                                                           |
| 5   | `Comment_Type__c` | Picklist            | Comment Type    | NEW    | New         | Values: Note, Governance Justification, Override Reason, System  |

---

## 2. SALES INCENTIVES MODULE OBJECTS

### 2.1 Comp_Plan\_\_c (Incentive Plan Assignment)

**Source:** KONY `Comp_Plan__c`  
**Purpose:** One record = one participant assigned to one plan template for one fiscal year. This is the **assignment** (instance), not the design (template). Created when admin assigns an Incentive_Plan_Template**c to a participant. Rate tiers are read from the template; attainment is tracked via linked Quota**c records.

**Port Strategy:** The KONY object had 112 fields mixing plan design + per-rep assignment + hardcoded Q1-Q4 targets. Plan design fields moved to Incentive_Plan_Template**c. Quota fields moved to Quota**c. What remains is the participant-specific assignment and runtime state.

**Fields (assignment-level — plan design fields are on the template):**

| #   | Field API Name                   | Type               | Label                       | Source | Port Action | Notes                                                                          |
| --- | -------------------------------- | ------------------ | --------------------------- | ------ | ----------- | ------------------------------------------------------------------------------ |
| 1   | `Plan_Template__c`               | Lookup             | Plan Template               | NEW    | New         | → Incentive_Plan_Template\_\_c. Links this assignment to its design blueprint. |
| 2   | `Sales_Rep__c`                   | Lookup             | Participant                 | KONY   | As-Is       | → User                                                                         |
| 3   | `Fiscal_Year__c`                 | Text(10)           | Fiscal Year                 | KONY   | As-Is       |                                                                                |
| 4   | `Plan_Effective_Date__c`         | Date               | Plan Effective Date         | KONY   | As-Is       |                                                                                |
| 5   | `FY_End_Date__c`                 | Date               | Plan End Date               | KONY   | Rename      | Was FY-specific                                                                |
| 6   | `Rep_Category__c`                | Picklist           | Participant Role            | KONY   | Rename      | Generic role label                                                             |
| 7   | `Region__c`                      | Text(100)          | Territory/Scope             | KONY   | Redesign    |                                                                                |
| 8   | `Entity__c`                      | Picklist           | Entity                      | KONY   | As-Is       |                                                                                |
| 9   | `On_Target_Earnings__c`          | Currency           | On Target Earnings          | KONY   | As-Is       | Per-participant OTE (may differ from template default)                         |
| 10  | `Base_Pay__c`                    | Currency           | Base Pay                    | KONY   | As-Is       |                                                                                |
| 11  | `Total_Variable_Compensation__c` | Currency           | Total Variable Compensation | KONY   | As-Is       |                                                                                |
| 12  | `Fx_Rate__c`                     | Number(18,6)       | FX Rate                     | KONY   | As-Is       |                                                                                |
| 13  | `Wage_Currency__c`               | Picklist           | Wage Currency               | KONY   | As-Is       |                                                                                |
| 14  | `Status__c`                      | Picklist           | Assignment Status           | NEW    | New         | Values: Draft, Active, On Hold, Terminated                                     |
| 15  | `Rep_Status__c`                  | Text(50)           | Participant Status          | KONY   | As-Is       | Active/Termed                                                                  |
| 16  | `Rep_Term_Date__c`               | Date               | Participant Term Date       | KONY   | As-Is       |                                                                                |
| 17  | `Plan_Acceptance_Status__c`      | Picklist           | Plan Acceptance Status      | NEW    | New         | Values: Not Published, Pending, Accepted, Declined                             |
| 18  | `Plan_Accepted_Date__c`          | DateTime           | Plan Accepted Date          | NEW    | New         |                                                                                |
| 19  | `Plan_Accepted_Method__c`        | Picklist           | Acceptance Method           | NEW    | New         | Values: Click-to-Accept, DocuSign, AdobeSign                                   |
| 20  | `Override_Base_Rate__c`          | Percent            | Override Base Rate %        | NEW    | New         | Per-participant override (null = use template default)                         |
| 21  | `Override_OTE__c`                | Currency           | Override OTE                | NEW    | New         | Per-participant override (null = use template default)                         |
| 22  | `Notes__c`                       | LongTextArea(5000) | Notes                       | NEW    | New         | Admin notes on this assignment                                                 |

**Inheritance rule:** At calculation time, the engine reads plan design fields (plan type, trigger type, caps, hold %, tiers) from the linked `Incentive_Plan_Template__c`. Per-participant overrides on Comp_Plan\_\_c (Override_Base_Rate, Override_OTE) take precedence when non-null. This means changing a template rate instantly affects all participants assigned to it — no need to update 200 individual plan records.

**Fields MOVED to Incentive_Plan_Template\_\_c:** All plan design fields — rate structures, caps, hold %, triggers, commission-on-net, payment frequency, penalty, multi-period bonus, dependent plan logic, eligibility rules. See §2.4.

**Fields MOVED to Quota**c / Quota_Template**c:** All target/achieved/attainment fields (Q1-Q4, FY, cumulative, YTD). See §2.6–2.7.

**Fields DROPPED (Kony-specific):**

- KPS-specific fields, H1/H2 fields, migration artifacts (`Old_SFDC_ID__c`, `Comp_Plan_ID_18_Digit__c`)
- Rollup summary fields (computed by Apex, not formula/rollup)
- Various Kony-specific: `Vertical_Split__c`, `Opportunity_Source__c`, `Partner_Role__c`, `Product_Classification__c`, `Rep_is_Owner__c`, `Sales_Rep_Category__c`, `Sales_Rep_Commission_Manager__c`, `Sub_Region__c`, `Renewal_Type__c`, `Services_Opportunity_Type1__c`, etc.

---

### 2.2 Comp_Calculation\_\_c (Incentive Calculation — Immutable Ledger)

**Source:** KONY `Comp_Calculation__c`  
**Purpose:** Each record is one calculated incentive entry: one transaction × one participant × one rate tier × one processing run. **Append-only** (§1.5.4).

| #   | Field API Name             | Type          | Label                    | Source | Port Action | Notes                                                     |
| --- | -------------------------- | ------------- | ------------------------ | ------ | ----------- | --------------------------------------------------------- |
| 1   | `Comp_Plan__c`             | MasterDetail  | Incentive Plan           | KONY   | As-Is       | → Comp_Plan\_\_c                                          |
| 2   | `Opportunity__c`           | Lookup        | Transaction              | KONY   | As-Is       | → Opportunity                                             |
| 3   | `Rep__c`                   | Lookup        | Participant              | KONY   | As-Is       | → User                                                    |
| 4   | `Commisionable_Value__c`   | Currency      | Commissionable Value     | KONY   | As-Is       |                                                           |
| 5   | `Eligible_Commission__c`   | Currency      | Eligible Commission      | KONY   | As-Is       |                                                           |
| 6   | `Applied_Percentage__c`    | Percent       | Applied Rate %           | KONY   | As-Is       |                                                           |
| 7   | `Eligible_Rate_Ratio__c`   | Percent       | Eligible Rate Ratio      | KONY   | As-Is       |                                                           |
| 8   | `Quota_Category__c`        | Picklist      | Transaction Category     | KONY   | Rename      | Generic: not "Subscription/Renewal"                       |
| 9   | `Comp_Plan_Type__c`        | Picklist      | Plan Type                | KONY   | As-Is       |                                                           |
| 10  | `Type__c`                  | Picklist      | Calculation Type         | KONY   | As-Is       | Values: Base, Accelerator, Adjustment, Clawback, Reversal |
| 11  | `Contract_Date2__c`        | Date          | Transaction Date         | KONY   | Rename      | Was contract-specific                                     |
| 12  | `Commisionable_Date__c`    | Date          | Commissionable Date      | KONY   | As-Is       |                                                           |
| 13  | `Applicable_Date__c`       | Date          | Applicable Date          | KONY   | As-Is       |                                                           |
| 14  | `Processed_Date__c`        | Date          | Processed Date           | KONY   | As-Is       |                                                           |
| 15  | `Commission_Paid_Date__c`  | Date          | Payment Date             | KONY   | Rename      |                                                           |
| 16  | `Region__c`                | Picklist      | Territory                | KONY   | Rename      |                                                           |
| 17  | `Rep_Name__c`              | Text(100)     | Participant Name         | KONY   | Rename      | Denormalized for reporting                                |
| 18  | `Rep_Category__c`          | Text(50)      | Participant Role         | KONY   | Rename      |                                                           |
| 19  | `Rep_Active__c`            | Checkbox      | Participant Active       | KONY   | Rename      |                                                           |
| 20  | `Hold_Reason__c`           | Picklist      | Hold Reason              | KONY   | As-Is       |                                                           |
| 21  | `Hold_Threshold__c`        | Percent       | Hold Threshold           | KONY   | As-Is       |                                                           |
| 22  | `Accelerators_Eligible__c` | Checkbox      | Release Payment          | KONY   | As-Is       |                                                           |
| 23  | `Accrued_Accelerators__c`  | Currency      | Accrued Accelerators     | KONY   | As-Is       |                                                           |
| 24  | `PCR__c`                   | Percent       | Collection %             | KONY   | Rename      | Was `PCR` (Payment Collection Ratio)                      |
| 25  | `Fx_Rate__c`               | Number(18,6)  | FX Rate                  | KONY   | As-Is       |                                                           |
| 26  | `Comments__c`              | TextArea(500) | Internal Comments        | KONY   | As-Is       |                                                           |
| 27  | `No_Quota_Retirement__c`   | Checkbox      | No Quota Retirement      | KONY   | As-Is       |                                                           |
| 28  | `Additional_Info__c`       | Picklist      | Additional Info          | KONY   | As-Is       |                                                           |
| 29  | `Payment_Frequency__c`     | Text(50)      | Payment Frequency        | KONY   | As-Is       |                                                           |
| 30  | `Processing_Run_Id__c`     | Text(50)      | Processing Run ID        | NEW    | New         | Groups records from the same processing run               |
| 31  | `Adjustment_Type__c`       | Picklist      | Adjustment Type          | NEW    | New         | Values: Original, Amendment, Reversal, Clawback (§1.5.4)  |
| 32  | `Attainment_Snapshot__c`   | Percent       | Attainment at Processing | NEW    | New         | Frozen attainment at time of calc (§1.5.1)                |
| 33  | `Rate_Tier_Applied__c`     | Text(50)      | Rate Tier Applied        | NEW    | New         | Name of the tier that governed this calc                  |
| 34  | `Force_Recalc__c`          | Checkbox      | Force Recalculation      | KONY   | Rename      | Was `Force_Comp_Attmt_and_Earned_Commissions__c`          |

---

### 2.3 Commission_Draw\_\_c (Draw Record)

**Source:** KONY `Commission_Draw__c`  
**Port Strategy:** Port mostly as-is. Drop KONY migration artifacts.

| #   | Field API Name         | Type                | Label             | Source | Port Action | Notes                                    |
| --- | ---------------------- | ------------------- | ----------------- | ------ | ----------- | ---------------------------------------- |
| 1   | `Rep__c`               | Lookup              | Participant       | KONY   | As-Is       | → User                                   |
| 2   | `Opportunity__c`       | Lookup              | Transaction       | KONY   | As-Is       | → Opportunity                            |
| 3   | `Amount__c`            | Currency            | Amount            | KONY   | As-Is       |                                          |
| 4   | `Beginning_Balance__c` | Currency            | Beginning Balance | KONY   | As-Is       |                                          |
| 5   | `Ending_Balance__c`    | Currency            | Ending Balance    | KONY   | As-Is       |                                          |
| 6   | `Type__c`              | Picklist            | Type              | KONY   | As-Is       | Values: Draw, Advance, Payback, Clawback |
| 7   | `Transaction_Date__c`  | Date                | Transaction Date  | KONY   | As-Is       |                                          |
| 8   | `Notes__c`             | LongTextArea(32000) | Notes             | KONY   | As-Is       |                                          |

---

### 2.4 Incentive_Plan_Template\_\_c (Incentive Plan Template) — NEW

**Source:** NEW  
**Purpose:** The blueprint/design for an incentive plan. Defines rate structure, tiers, caps, triggers, and eligibility rules. Admins create templates once, then assign them to participants — spawning Comp_Plan\_\_c (assignment) records. This eliminates the KONY antipattern of cloning plans manually for each rep every year.

| #   | Field API Name                       | Type                | Label                           | Notes                                                                                    |
| --- | ------------------------------------ | ------------------- | ------------------------------- | ---------------------------------------------------------------------------------------- |
| 1   | `Template_Name__c`                   | Text(100)           | Template Name                   | e.g., "Enterprise AE Accelerated FY2027"                                                 |
| 2   | `Description__c`                     | LongTextArea(5000)  | Description                     |                                                                                          |
| 3   | `Plan_Type__c`                       | Picklist            | Plan Type                       | Flat, Tiered, Accelerated, Gross Margin, Recurring, Milestone, Activity-Based, Team Pool |
| 4   | `Trigger_Type__c`                    | Picklist            | Trigger Type                    | Booking, Collection, Milestone, Rev Rec, Signature, Delivery, Renewal Date               |
| 5   | `Commissionable_Value_Formula__c`    | Picklist            | Commissionable Value            | Full Booking, Net Booking, Gross Margin, MRR, ARR, Weighted Amount, Custom Formula       |
| 6   | `Base_Rate_Percent__c`               | Percent             | Base Rate %                     | Default rate for Tier 1                                                                  |
| 7   | `Base_Rate_Amount__c`                | Currency            | Base Rate ($)                   | Flat rate alternative                                                                    |
| 8   | `Commission_on_Net__c`               | Checkbox            | Commission on Net               |                                                                                          |
| 9   | `Cap_Amount__c`                      | Currency            | Cap Amount                      | Max payout per period                                                                    |
| 10  | `Cap_Percentage__c`                  | Percent             | Cap Percentage                  | Max payout as % of OTE                                                                   |
| 11  | `Cap_Per_Transaction__c`             | Currency            | Cap Per Transaction             |                                                                                          |
| 12  | `Hold_Percent__c`                    | Percent             | Hold %                          | Default hold-back                                                                        |
| 13  | `Hold_Type__c`                       | Picklist            | Hold Type                       |                                                                                          |
| 14  | `Payment_Frequency__c`               | Picklist            | Payment Frequency               | Weekly, Bi-weekly, Semi-monthly, Monthly, Quarterly                                      |
| 15  | `Period_Type__c`                     | Picklist            | Attainment Period               | Monthly, Quarterly, Semi-Annual, Annual                                                  |
| 16  | `Penalty_Percent__c`                 | Percent             | Penalty %                       | Short-term deal penalty                                                                  |
| 17  | `Min_Term_for_Penalty__c`            | Number(3,0)         | Min Term for Penalty            | In months                                                                                |
| 18  | `Multi_Period_Bonus_Rate__c`         | Percent             | Multi-Period Bonus Rate         |                                                                                          |
| 19  | `Multi_Period_Cap__c`                | Currency            | Multi-Period Cap                |                                                                                          |
| 20  | `Eligible_Roles__c`                  | MultiselectPicklist | Eligible Roles                  | Which participant roles can be assigned this template                                    |
| 21  | `Eligible_Transaction_Categories__c` | MultiselectPicklist | Eligible Transaction Categories | Which transaction types earn on this plan                                                |
| 22  | `Dependent_Template__c`              | Lookup(self)        | Dependent Template              | Gate: participant must hit threshold on this plan first                                  |
| 23  | `Dependent_Threshold__c`             | Percent             | Dependent Threshold             | Attainment % required on dependent plan                                                  |
| 24  | `Fiscal_Year__c`                     | Text(10)            | Fiscal Year                     | e.g., "FY2027"                                                                           |
| 25  | `Effective_Start__c`                 | Date                | Effective Start Date            |                                                                                          |
| 26  | `Effective_End__c`                   | Date                | Effective End Date              |                                                                                          |
| 27  | `Status__c`                          | Picklist            | Status                          | Draft, Active, Archived                                                                  |
| 28  | `Plan_Document_URL__c`               | Url                 | Plan Document URL               | Link to PDF/doc for acceptance workflow                                                  |
| 29  | `Acceptance_Gate__c`                 | Picklist            | Acceptance Gate                 | Hard (blocks processing), Soft (notify only), None                                       |

**Admin workflow:** Create template → Define tiers (Commission_Tier**c children) → Define quota template (Quota_Template**c) → Activate → Assign to participants (bulk or individual) → System creates Comp_Plan**c + Quota**c records per participant.

---

### 2.5 Commission_Tier\_\_c (Rate Tier) — NEW

**Source:** NEW (replaces hardcoded accelerator thresholds)  
**Purpose:** Defines rate tiers/bands for a plan template. Child of Incentive_Plan_Template\_\_c. When a template is assigned to a participant, tiers are referenced from the template (not copied to the assignment).

| #   | Field API Name      | Type         | Label            | Notes                                                                                        |
| --- | ------------------- | ------------ | ---------------- | -------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`  | MasterDetail | Plan Template    | → Incentive_Plan_Template\_\_c                                                               |
| 2   | `Tier_Name__c`      | Text(50)     | Tier Name        | e.g., "Base", "Accelerator", "Super Accelerator"                                             |
| 3   | `Min_Attainment__c` | Percent      | Min Attainment % | Lower bound (inclusive)                                                                      |
| 4   | `Max_Attainment__c` | Percent      | Max Attainment % | Upper bound (exclusive). Null = unlimited                                                    |
| 5   | `Rate_Percent__c`   | Percent      | Rate %           | Commission rate for this tier                                                                |
| 6   | `Rate_Amount__c`    | Currency     | Rate ($)         | Flat rate alternative                                                                        |
| 7   | `Is_Retroactive__c` | Checkbox     | Retroactive      | If true, crossing into this tier retroactively re-rates all prior transactions in the period |
| 8   | `Sort_Order__c`     | Number(3,0)  | Sort Order       | Evaluation order (ascending)                                                                 |
| 9   | `Period_Type__c`    | Picklist     | Period Scope     | Monthly, Quarterly, Annual, Cumulative                                                       |

---

### 2.6 Quota_Template\_\_c (Quota Template) — NEW

**Source:** NEW  
**Purpose:** Blueprint for quota assignments. Defines target amounts by period. Linked to an Incentive Plan Template (optional — quotas can exist for forecasting coverage without a comp plan). Admin assigns template to participants → system spawns Quota\_\_c records.

| #   | Field API Name           | Type                | Label                   | Notes                                                                            |
| --- | ------------------------ | ------------------- | ----------------------- | -------------------------------------------------------------------------------- |
| 1   | `Template_Name__c`       | Text(100)           | Template Name           | e.g., "Enterprise AE Q1-Q4 FY2027"                                               |
| 2   | `Description__c`         | LongTextArea(2000)  | Description             |                                                                                  |
| 3   | `Plan_Template__c`       | Lookup              | Incentive Plan Template | → Incentive_Plan_Template\_\_c (optional)                                        |
| 4   | `Fiscal_Year__c`         | Text(10)            | Fiscal Year             |                                                                                  |
| 5   | `Period_Type__c`         | Picklist            | Period Type             | Monthly, Quarterly, Semi-Annual, Annual                                          |
| 6   | `Metric__c`              | Picklist            | Metric                  | Primary, Secondary, Custom 1–4                                                   |
| 7   | `Annual_Target__c`       | Currency            | Annual Target           | Full-year target amount                                                          |
| 8   | `Period_1_Target__c`     | Currency            | Period 1 Target         | e.g., Q1 or Jan                                                                  |
| 9   | `Period_2_Target__c`     | Currency            | Period 2 Target         |                                                                                  |
| 10  | `Period_3_Target__c`     | Currency            | Period 3 Target         |                                                                                  |
| 11  | `Period_4_Target__c`     | Currency            | Period 4 Target         |                                                                                  |
| 12  | `Period_5_Target__c`     | Currency            | Period 5 Target         | For monthly (5-12 as needed)                                                     |
| 13  | `Period_6_Target__c`     | Currency            | Period 6 Target         |                                                                                  |
| 14  | `Period_7_Target__c`     | Currency            | Period 7 Target         |                                                                                  |
| 15  | `Period_8_Target__c`     | Currency            | Period 8 Target         |                                                                                  |
| 16  | `Period_9_Target__c`     | Currency            | Period 9 Target         |                                                                                  |
| 17  | `Period_10_Target__c`    | Currency            | Period 10 Target        |                                                                                  |
| 18  | `Period_11_Target__c`    | Currency            | Period 11 Target        |                                                                                  |
| 19  | `Period_12_Target__c`    | Currency            | Period 12 Target        |                                                                                  |
| 20  | `Distribution_Method__c` | Picklist            | Distribution Method     | Equal (annual ÷ periods), Weighted (use period fields), Custom (admin sets each) |
| 21  | `Status__c`              | Picklist            | Status                  | Draft, Active, Archived                                                          |
| 22  | `Eligible_Roles__c`      | MultiselectPicklist | Eligible Roles          | Which participant roles this quota applies to                                    |
| 23  | `Territory__c`           | Lookup              | Territory               | → Territory\_\_c (optional — for territory-scoped quota templates)               |

**Distribution logic:** When `Distribution_Method__c` = Equal, the system divides `Annual_Target__c` by the number of periods and populates Quota**c records accordingly. When Weighted, it uses the Period_N fields directly. When Custom, admin edits individual Quota**c records after spawning.

---

### 2.7 Quota\_\_c (Quota Assignment) — NEW

**Source:** NEW  
**Purpose:** One record = one participant's target for one period for one metric. Spawned from Quota_Template\_\_c when admin assigns. Tracks achieved amount and attainment.

| #   | Field API Name         | Type              | Label             | Notes                                                                |
| --- | ---------------------- | ----------------- | ----------------- | -------------------------------------------------------------------- |
| 1   | `Participant__c`       | Lookup            | Participant       | → User                                                               |
| 2   | `Quota_Template__c`    | Lookup            | Quota Template    | → Quota_Template\_\_c (tracks source template)                       |
| 3   | `Comp_Plan__c`         | Lookup            | Incentive Plan    | → Comp_Plan\_\_c (optional — links to participant's plan assignment) |
| 4   | `Territory__c`         | Lookup            | Territory         | → Territory\_\_c (optional)                                          |
| 5   | `Period_Start__c`      | Date              | Period Start      |                                                                      |
| 6   | `Period_End__c`        | Date              | Period End        |                                                                      |
| 7   | `Period_Label__c`      | Text(50)          | Period Label      | e.g., "Q2 FY2027", "March 2027"                                      |
| 8   | `Period_Type__c`       | Picklist          | Period Type       | Monthly, Quarterly, Semi-Annual, Annual                              |
| 9   | `Metric__c`            | Picklist          | Metric            | Primary, Secondary, Custom 1–4                                       |
| 10  | `Target_Amount__c`     | Currency          | Target Amount     | The quota                                                            |
| 11  | `Achieved_Amount__c`   | Currency          | Achieved Amount   | Updated on each incentive calculation run                            |
| 12  | `Attainment__c`        | Percent(Formula)  | Attainment %      | `Achieved_Amount__c / Target_Amount__c`                              |
| 13  | `Fiscal_Year__c`       | Text(10)          | Fiscal Year       |                                                                      |
| 14  | `Status__c`            | Picklist          | Status            | Draft, Active, Closed                                                |
| 15  | `Adjustment_Amount__c` | Currency          | Adjustment        | Manual quota adjustment (± from original target)                     |
| 16  | `Adjusted_Target__c`   | Currency(Formula) | Adjusted Target   | `Target_Amount__c + Adjustment_Amount__c`                            |
| 17  | `Adjustment_Reason__c` | Text(255)         | Adjustment Reason | Required when Adjustment_Amount != 0                                 |

**Cross-module usage:**

- **Incentive calculation engine:** Reads `Attainment__c` to determine which Commission_Tier rate applies
- **Forecasting coverage ratio:** `Pipeline Value ÷ Adjusted_Target__c` = coverage multiplier shown in forecast summary
- **Governance rules:** Threshold proximity = `Adjusted_Target__c × Tier.Min_Attainment__c − Achieved_Amount__c`
- **Inline estimator:** "You are $X from the next tier" = reads from Quota**c + Commission_Tier**c
- **Payout forecasting:** Projected attainment = `(Achieved + pipeline × close_probability) / Adjusted_Target`

---

### 2.8 Incentive_Dispute\_\_c (Incentive Dispute) — NEW (unchanged from V1.0)

| #   | Field API Name              | Type               | Label                  | Notes                                                                       |
| --- | --------------------------- | ------------------ | ---------------------- | --------------------------------------------------------------------------- |
| 1   | `Comp_Calculation__c`       | Lookup             | Incentive Calculation  | → Comp_Calculation\_\_c                                                     |
| 2   | `Participant__c`            | Lookup             | Participant            | → User                                                                      |
| 3   | `Status__c`                 | Picklist           | Status                 | Values: Open, Under Review, Resolved — Upheld, Resolved — Corrected, Closed |
| 4   | `Dispute_Reason__c`         | LongTextArea(5000) | Dispute Reason         | Rep's description                                                           |
| 5   | `Expected_Amount__c`        | Currency           | Expected Amount        | What the rep thinks they should earn                                        |
| 6   | `Resolution_Notes__c`       | LongTextArea(5000) | Resolution Notes       | Admin's response                                                            |
| 7   | `Resolution_Date__c`        | DateTime           | Resolution Date        |                                                                             |
| 8   | `Resolved_By__c`            | Lookup             | Resolved By            | → User                                                                      |
| 9   | `Adjustment_Calculation__c` | Lookup             | Adjustment Calculation | → Comp_Calculation\_\_c (if correction created)                             |

---

### 2.9 Territory\_\_c (Territory / Scope) — NEW

| #   | Field API Name        | Type         | Label            | Notes                        |
| --- | --------------------- | ------------ | ---------------- | ---------------------------- |
| 1   | `Territory_Name__c`   | Text(100)    | Territory Name   |                              |
| 2   | `Parent_Territory__c` | Lookup(self) | Parent Territory | → Territory\_\_c (hierarchy) |
| 3   | `Region__c`           | Text(100)    | Region           |                              |
| 4   | `Active__c`           | Checkbox     | Active           |                              |

---

## 3. DEAL HEALTH MODULE OBJECTS — ALL NEW

### 3.1 Deal_Signal\_\_c (Pipeline Signal)

**Purpose:** Canonical signal store. One record per pipeline record. Normalized signals from all connected adapters.

| #   | Field API Name                       | Type               | Label                         | Notes                                                 |
| --- | ------------------------------------ | ------------------ | ----------------------------- | ----------------------------------------------------- |
| 1   | `Opportunity__c`                     | Lookup             | Pipeline Record               | → Opportunity (unique per record)                     |
| 2   | `Health_Score__c`                    | Number(3,0)        | Health Score                  | Composite 0-100                                       |
| 3   | `Conversation_Intelligence_Score__c` | Number(3,0)        | Conv. Intelligence Score      | Component 0-100                                       |
| 4   | `Relationship_Score__c`              | Number(3,0)        | Relationship Score            | Component 0-100                                       |
| 5   | `Activity_Recency_Score__c`          | Number(3,0)        | Activity Recency Score        | Component 0-100                                       |
| 6   | `Engagement_Depth_Score__c`          | Number(3,0)        | Engagement Depth Score        | Component 0-100                                       |
| 7   | `CI_Weight__c`                       | Percent            | CI Weight (Applied)           | After redistribution                                  |
| 8   | `Relationship_Weight__c`             | Percent            | Relationship Weight (Applied) | After redistribution                                  |
| 9   | `Activity_Weight__c`                 | Percent            | Activity Weight (Applied)     | After redistribution                                  |
| 10  | `Engagement_Weight__c`               | Percent            | Engagement Weight (Applied)   | After redistribution                                  |
| 11  | `Adjustment_Points__c`               | Number(5,1)        | Adjustment Points             | Net adjustments applied                               |
| 12  | `Adjustment_Details__c`              | LongTextArea(5000) | Adjustment Details            | JSON: which adjustments fired                         |
| 13  | `CI_Adapter__c`                      | Text(50)           | CI Adapter Name               | e.g., "Gong", "Zoom RA", "None"                       |
| 14  | `Relationship_Adapter__c`            | Text(50)           | Relationship Adapter          | e.g., "Momentum", "CRM Proxy"                         |
| 15  | `Last_CI_Sync__c`                    | DateTime           | Last CI Sync                  |                                                       |
| 16  | `Last_Relationship_Sync__c`          | DateTime           | Last Relationship Sync        |                                                       |
| 17  | `Last_Activity_Date__c`              | DateTime           | Last Mutual Activity          |                                                       |
| 18  | `Stakeholder_Count__c`               | Number(3,0)        | Stakeholder Count             |                                                       |
| 19  | `Competitor_Mentioned__c`            | Checkbox           | Competitor Mentioned          |                                                       |
| 20  | `Next_Step_Confirmed__c`             | Checkbox           | Next Step Confirmed           |                                                       |
| 21  | `DM_Last_Response__c`                | DateTime           | Decision Maker Last Response  |                                                       |
| 22  | `Stage_Progression__c`               | Picklist           | Stage Progression             | Values: Forward, Stalled, Regressed                   |
| 23  | `Slip_Count__c`                      | Number(3,0)        | Slip Count                    | Close date movement count                             |
| 24  | `Signal_Freshness__c`                | Picklist           | Signal Freshness              | Values: LIVE, RECENT, STALE, EXPIRED, MISSING (§5.10) |
| 25  | `Score_Smoothed__c`                  | Number(3,0)        | Smoothed Score                | 7-day rolling average                                 |

---

### 3.2 Deal_Signal_History\_\_c (Signal Change History)

**Purpose:** Audit trail of health score changes.

| #   | Field API Name         | Type               | Label             | Notes                            |
| --- | ---------------------- | ------------------ | ----------------- | -------------------------------- |
| 1   | `Deal_Signal__c`       | MasterDetail       | Pipeline Signal   | → Deal_Signal\_\_c               |
| 2   | `Previous_Score__c`    | Number(3,0)        | Previous Score    |                                  |
| 3   | `New_Score__c`         | Number(3,0)        | New Score         |                                  |
| 4   | `Delta__c`             | Number(5,1)        | Delta             |                                  |
| 5   | `Component_Changed__c` | Text(100)          | Component Changed | Which component drove the change |
| 6   | `Signal_Source__c`     | Text(50)           | Signal Source     | Adapter that triggered           |
| 7   | `Change_Details__c`    | LongTextArea(5000) | Change Details    | JSON: component-level deltas     |

---

## 4. CROSS-MODULE OBJECTS — ALL NEW

### 4.1 Governance_Event\_\_c (Governance Event)

**Purpose:** Audit trail for comp-aware governance rules. Immutable after creation (§7.3.5).

| #   | Field API Name             | Type                | Label                 | Notes                                                                         |
| --- | -------------------------- | ------------------- | --------------------- | ----------------------------------------------------------------------------- |
| 1   | `Forecast_Override__c`     | Lookup              | Forecast Override     | → Forecast_Override\_\_c                                                      |
| 2   | `Participant__c`           | Lookup              | Participant           | → User                                                                        |
| 3   | `Opportunity__c`           | Lookup              | Pipeline Record       | → Opportunity                                                                 |
| 4   | `Forecast__c`              | Lookup              | Forecast Period       | → Forecast\_\_c                                                               |
| 5   | `Rule_Id__c`               | Text(10)            | Rule ID               | e.g., "CG-1", "CG-2"                                                          |
| 6   | `Rule_Name__c`             | Text(100)           | Rule Name             |                                                                               |
| 7   | `Severity__c`              | Picklist            | Severity              | Values: High, Medium, Low, Informational                                      |
| 8   | `Action_Type__c`           | Picklist            | Action Type           | Values: Require Justification, Require Approval, Escalate, Alert, Warn, Badge |
| 9   | `Status__c`                | Picklist            | Status                | Values: Triggered, Pending, Approved, Denied, Expired, Superseded, Skipped    |
| 10  | `Compensation_Context__c`  | LongTextArea(10000) | Compensation Context  | JSON: attainment, tier, threshold, payout delta                               |
| 11  | `Attainment_At_Trigger__c` | Percent             | Attainment at Trigger | Snapshot                                                                      |
| 12  | `Tier_At_Trigger__c`       | Text(50)            | Tier at Trigger       | Snapshot                                                                      |
| 13  | `Threshold_Proximity__c`   | Currency            | Threshold Proximity   | Distance to next tier                                                         |
| 14  | `Payout_Delta__c`          | Currency            | Payout Delta          | Incentive impact of the action                                                |
| 15  | `Justification__c`         | LongTextArea(5000)  | Justification         | Participant's note                                                            |
| 16  | `Reviewer__c`              | Lookup              | Reviewer              | → User                                                                        |
| 17  | `Resolution_Date__c`       | DateTime            | Resolution Date       |                                                                               |
| 18  | `Resolution_Notes__c`      | LongTextArea(5000)  | Resolution Notes      |                                                                               |
| 19  | `Expires_At__c`            | DateTime            | Expires At            | Pending approval timeout                                                      |
| 20  | `Stale_Basis__c`           | Checkbox            | Stale Basis           | CRM changed after trigger (§1.5.2)                                            |

---

### 4.2 Behavioral_Flag\_\_c (Behavioral Flag)

**Purpose:** Sandbagging, optimism, threshold approach, and timing flags from Behavior Intelligence module.

| #   | Field API Name        | Type                | Label                  | Notes                                                                                          |
| --- | --------------------- | ------------------- | ---------------------- | ---------------------------------------------------------------------------------------------- |
| 1   | `Participant__c`      | Lookup              | Participant            | → User                                                                                         |
| 2   | `Opportunity__c`      | Lookup              | Pipeline Record        | → Opportunity (optional — some flags are participant-level)                                    |
| 3   | `Forecast__c`         | Lookup              | Forecast Period        | → Forecast\_\_c                                                                                |
| 4   | `Flag_Type__c`        | Picklist            | Flag Type              | Values: Sandbagging, Optimism Bias, Threshold Approach, Timing Concentration, Period Slip Loop |
| 5   | `Confidence__c`       | Picklist            | Signal Strength        | Values: High, Medium, Low (§6.11.2)                                                            |
| 6   | `Evidence__c`         | LongTextArea(10000) | Evidence               | JSON: corroborating signals                                                                    |
| 7   | `Explanation__c`      | LongTextArea(32000) | Structured Explanation | Full §6.10 structured explanation                                                              |
| 8   | `Narrative__c`        | LongTextArea(32000) | AI Narrative           | Tier 3 LLM-generated narrative (optional)                                                      |
| 9   | `Status__c`           | Picklist            | Status                 | Values: Active, Dismissed, Resolved, Superseded                                                |
| 10  | `Dismissed_By__c`     | Lookup              | Dismissed By           | → User                                                                                         |
| 11  | `Dismissal_Reason__c` | LongTextArea(5000)  | Dismissal Reason       | Required on dismiss                                                                            |
| 12  | `Dismissed_Date__c`   | DateTime            | Dismissed Date         |                                                                                                |

---

### 4.3 Manager_Accuracy\_\_c (Manager Accuracy)

**Purpose:** Rolling accuracy statistics per manager. Refreshed weekly.

| #   | Field API Name         | Type                | Label             | Notes                                                     |
| --- | ---------------------- | ------------------- | ----------------- | --------------------------------------------------------- |
| 1   | `User__c`              | Lookup              | Manager           | → User (unique per user)                                  |
| 2   | `Hit_Rate__c`          | Percent             | Hit Rate          | When submitted as high-confidence, % that actually closed |
| 3   | `Avg_Value_Delta__c`   | Percent             | Avg Value Delta   | Average over/under-commit %                               |
| 4   | `Slip_Rate__c`         | Number(3,1)         | Avg Slip Rate     | Average periods a deal slips from submission              |
| 5   | `Accuracy_Score__c`    | Number(3,0)         | Accuracy Score    | Composite 0-100                                           |
| 6   | `Periods_Evaluated__c` | Number(3,0)         | Periods Evaluated | How many periods in the sample                            |
| 7   | `Last_Calculated__c`   | DateTime            | Last Calculated   |                                                           |
| 8   | `Trend__c`             | Picklist            | Trend             | Values: Improving, Stable, Declining                      |
| 9   | `Category_Matrix__c`   | LongTextArea(10000) | Category Matrix   | JSON: confusion matrix across categories → outcomes       |

---

### 4.4 Failed_Event\_\_c (Failed Event — Dead Letter Queue)

**Purpose:** Dead-letter queue for Platform Event processing failures (§14.4).

| #   | Field API Name           | Type                | Label               | Notes                                                       |
| --- | ------------------------ | ------------------- | ------------------- | ----------------------------------------------------------- |
| 1   | `Event_Type__c`          | Text(100)           | Event Type          | Commission_Event**e, Governance_Event**e, Signal_Event\_\_e |
| 2   | `Payload__c`             | LongTextArea(32000) | Payload             | JSON snapshot of the failed event                           |
| 3   | `Error_Message__c`       | LongTextArea(5000)  | Error Message       |                                                             |
| 4   | `Retry_Count__c`         | Number(2,0)         | Retry Count         |                                                             |
| 5   | `Status__c`              | Picklist            | Status              | Values: Failed, Retrying, Resolved, Abandoned               |
| 6   | `Original_Event_Time__c` | DateTime            | Original Event Time |                                                             |

---

## 5. PLATFORM EVENTS

### 5.1 Commission_Event\_\_e

| #   | Field API Name      | Type               | Label          | Notes                                                                            |
| --- | ------------------- | ------------------ | -------------- | -------------------------------------------------------------------------------- |
| 1   | `Opportunity_Id__c` | Text(18)           | Opportunity ID |                                                                                  |
| 2   | `Event_Type__c`     | Text(50)           | Event Type     | DEAL_CLOSED, AMOUNT_CHANGED, STAGE_CHANGED, CLOSE_DATE_CHANGED, CATEGORY_CHANGED |
| 3   | `Previous_Value__c` | LongTextArea(5000) | Previous Value | JSON                                                                             |
| 4   | `New_Value__c`      | LongTextArea(5000) | New Value      | JSON                                                                             |
| 5   | `User_Id__c`        | Text(18)           | User ID        |                                                                                  |

### 5.2 Governance_Eval_Event\_\_e

| #   | Field API Name            | Type                | Label                | Notes |
| --- | ------------------------- | ------------------- | -------------------- | ----- |
| 1   | `Override_Id__c`          | Text(18)            | Forecast Override ID |       |
| 2   | `Rule_Id__c`              | Text(10)            | Rule ID              |       |
| 3   | `Participant_Id__c`       | Text(18)            | Participant ID       |       |
| 4   | `Compensation_Context__c` | LongTextArea(10000) | Compensation Context | JSON  |
| 5   | `Action_Type__c`          | Text(50)            | Action Type          |       |

### 5.3 Signal_Event\_\_e

| #   | Field API Name      | Type                | Label          | Notes                      |
| --- | ------------------- | ------------------- | -------------- | -------------------------- |
| 1   | `Opportunity_Id__c` | Text(18)            | Opportunity ID |                            |
| 2   | `Signal_Source__c`  | Text(50)            | Signal Source  | CRM, GONG, MOMENTUM, etc.  |
| 3   | `Signal_Data__c`    | LongTextArea(10000) | Signal Data    | JSON of normalized signals |

---

## 6. CUSTOM METADATA TYPES

### 6.1 Forecast_Configuration\_\_mdt (Forecast Template)

**Source:** Temenos `Forecast_Configuration__mdt` (enhanced)

| #   | Field API Name                | Type               | Label                    | Notes                                                                  |
| --- | ----------------------------- | ------------------ | ------------------------ | ---------------------------------------------------------------------- |
| 1   | `Hierarchy_Levels__c`         | Number(2,0)        | Hierarchy Levels         | 2-10                                                                   |
| 2   | `Level_Labels__c`             | LongTextArea(1000) | Level Labels             | JSON: ["Rep","Manager","Director","CRO"]                               |
| 3   | `Metric_1_Label__c`           | Text(50)           | Primary Metric Label     | e.g., "TCV", "Premium Value"                                           |
| 4   | `Metric_2_Label__c`           | Text(50)           | Secondary Metric Label   | e.g., "ARR", "Policy Count"                                            |
| 5   | `Category_Config__c`          | LongTextArea(2000) | Category Configuration   | JSON: [{name, color, countsTowardTarget, terminal, regressionWarning}] |
| 6   | `Period_Type__c`              | Text(20)           | Period Type              | Weekly, Monthly, Quarterly, Annual                                     |
| 7   | `Fiscal_Year_Start_Month__c`  | Number(2,0)        | FY Start Month           | 1-12                                                                   |
| 8   | `Trend_Threshold_Metric_1__c` | Currency           | Metric 1 Trend Threshold |                                                                        |
| 9   | `Trend_Threshold_Metric_2__c` | Currency           | Metric 2 Trend Threshold |                                                                        |
| 10  | `Top_Level_Lock_Label__c`     | Text(20)           | Lock Action Label        | "Freeze", "Lock", "Approve"                                            |
| 11  | `Is_Active__c`                | Checkbox           | Active                   |                                                                        |

### 6.2 Governance_Rule\_\_mdt (Governance Rule Configuration)

| #   | Field API Name                | Type               | Label                      | Notes                            |
| --- | ----------------------------- | ------------------ | -------------------------- | -------------------------------- |
| 1   | `Rule_Id__c`                  | Text(10)           | Rule ID                    | CG-1 through CG-7+               |
| 2   | `Rule_Name__c`                | Text(100)          | Rule Name                  |                                  |
| 3   | `Trigger_Description__c`      | LongTextArea(1000) | Trigger Description        |                                  |
| 4   | `Action_Type__c`              | Text(50)           | Action Type                |                                  |
| 5   | `Severity__c`                 | Text(20)           | Severity                   | High, Medium, Low, Informational |
| 6   | `Payout_Delta_Threshold__c`   | Number(5,2)        | Payout Delta Threshold %   | For CG-1                         |
| 7   | `Tier_Proximity_Threshold__c` | Number(5,2)        | Tier Proximity Threshold % | For CG-2                         |
| 8   | `Approval_Timeout_Hours__c`   | Number(5,0)        | Approval Timeout (Hours)   | For CG-3                         |
| 9   | `Is_Enabled__c`               | Checkbox           | Enabled                    |                                  |
| 10  | `Is_Blocking__c`              | Checkbox           | Blocking                   |                                  |

### 6.3 Deal_Health_Profile\_\_mdt (Health Score Profile)

| #   | Field API Name           | Type               | Label                 | Notes                           |
| --- | ------------------------ | ------------------ | --------------------- | ------------------------------- |
| 1   | `Profile_Name__c`        | Text(100)          | Profile Name          |                                 |
| 2   | `CI_Weight__c`           | Number(5,2)        | CI Weight %           | Default 40                      |
| 3   | `Relationship_Weight__c` | Number(5,2)        | Relationship Weight % | Default 25                      |
| 4   | `Activity_Weight__c`     | Number(5,2)        | Activity Weight %     | Default 20                      |
| 5   | `Engagement_Weight__c`   | Number(5,2)        | Engagement Weight %   | Default 15                      |
| 6   | `Adjustment_Config__c`   | LongTextArea(5000) | Adjustment Rules      | JSON config                     |
| 7   | `Freshness_SLA_Hours__c` | Number(5,0)        | Freshness SLA (Hours) |                                 |
| 8   | `Hard_Expire_Hours__c`   | Number(5,0)        | Hard Expire (Hours)   |                                 |
| 9   | `Scope__c`               | Text(20)           | Scope                 | Platform, Org, Role, Individual |
| 10  | `Is_Default__c`          | Checkbox           | Default Profile       |                                 |

### 6.4 Field_Mapping\_\_mdt (Subscriber Field Mapping)

**Purpose:** Maps logical platform field names to subscriber org field API names (§14.4).

| #   | Field API Name        | Type      | Label                     | Notes                                         |
| --- | --------------------- | --------- | ------------------------- | --------------------------------------------- |
| 1   | `Logical_Field__c`    | Text(100) | Logical Field             | e.g., "Pipeline.Amount", "Pipeline.CloseDate" |
| 2   | `Salesforce_Field__c` | Text(100) | Salesforce Field API Name | e.g., "Amount", "Total_Contract_Value\_\_c"   |
| 3   | `Object_Name__c`      | Text(100) | Object API Name           | e.g., "Opportunity"                           |
| 4   | `Field_Type__c`       | Text(20)  | Field Type                | Currency, Date, Text, Number, Picklist        |

### 6.5 Batch_Config\_\_mdt (Batch Configuration)

| #   | Field API Name     | Type        | Label         | Notes                                     |
| --- | ------------------ | ----------- | ------------- | ----------------------------------------- |
| 1   | `Batch_Name__c`    | Text(100)   | Batch Name    | e.g., "HealthScoreBatch", "AccuracyBatch" |
| 2   | `Scope_Size__c`    | Number(4,0) | Scope Size    | Default 50                                |
| 3   | `Schedule_Cron__c` | Text(100)   | Schedule CRON |                                           |
| 4   | `Is_Enabled__c`    | Checkbox    | Enabled       |                                           |

---

## OBJECT COUNT SUMMARY

| Category                                | Objects                                                                 | Field Count (approx) |
| --------------------------------------- | ----------------------------------------------------------------------- | -------------------- |
| Forecasting (ported from Temenos)       | 4 objects                                                               | ~85 fields           |
| Incentives — Templates (new)            | 2 objects (Incentive_Plan_Template**c, Quota_Template**c)               | ~52 fields           |
| Incentives — Assignments (ported + new) | 3 objects (Comp_Plan**c, Quota**c, Commission_Tier\_\_c)                | ~50 fields           |
| Incentives — Runtime (ported)           | 2 objects (Comp_Calculation**c, Commission_Draw**c)                     | ~42 fields           |
| Deal Health (all new)                   | 2 objects                                                               | ~28 fields           |
| Cross-Module (all new)                  | 4 objects (Governance, Behavioral Flag, Manager Accuracy, Failed Event) | ~40 fields           |
| Supporting (ported + new)               | 2 objects (Incentive_Dispute**c, Territory**c)                          | ~15 fields           |
| Platform Events                         | 3 events                                                                | ~13 fields           |
| Custom Metadata Types                   | 5 types                                                                 | ~40 fields           |
| **TOTAL**                               | **19 objects + 3 events + 5 metadata types**                            | **~365 fields**      |

---

## ENTITY RELATIONSHIP DIAGRAM

```
Incentive_Plan_Template__c (plan design blueprint)
  ├── Commission_Tier__c          (N — rate tiers for this template)
  ├── Quota_Template__c           (N — quota blueprints for this template)
  │     └── Quota__c              (N — one per participant per period, spawned from template)
  └── Comp_Plan__c                (N — one per participant assignment)
        ├── Comp_Calculation__c    (N — immutable ledger entries)
        └── Commission_Draw__c    (N — draw/advance/payback records)

Forecast__c (forecast period)
  ├── Forecast_User__c            (N — participant assignments for this period)
  └── Forecast_Override__c        (N — one per pipeline record per level)
        ├── Forecast_Comment__c   (N — historical notes)
        └── Governance_Event__c   (N — governance audit trail)

Opportunity (subscriber's pipeline record — CRM-owned)
  ├── Forecast_Override__c        (N — overrides for this record)
  ├── Comp_Calculation__c         (N — incentive calculations)
  ├── Deal_Signal__c              (1 — canonical signal store)
  │     └── Deal_Signal_History__c (N — score change audit)
  └── Behavioral_Flag__c          (N — behavior patterns flagged)

User (participant)
  ├── Comp_Plan__c                (N — plan assignments)
  ├── Quota__c                    (N — quota assignments)
  ├── Forecast_User__c            (N — forecast participation)
  └── Manager_Accuracy__c         (1 — rolling accuracy stats)

Territory__c                      (self-referential hierarchy)
  ├── Quota__c                    (N — territory-scoped quotas)
  └── Quota_Template__c           (N — territory-scoped templates)
```

---

## DEPLOYMENT ORDER

Objects must be deployed in dependency order:

1. **Wave 1 (no dependencies):** Territory**c, Failed_Event**c, Manager_Accuracy\_\_c, all Custom Metadata Types
2. **Wave 2 (depends on Wave 1):** Forecast**c, Incentive_Plan_Template**c, Deal_Signal\_\_c
3. **Wave 3 (depends on Wave 2):** Forecast_User**c, Commission_Tier**c, Quota_Template**c, Comp_Plan**c, Deal_Signal_History\_\_c
4. **Wave 4 (depends on Wave 3):** Forecast_Override**c, Forecast_Comment**c, Comp_Calculation**c, Commission_Draw**c, Quota**c, Incentive_Dispute**c
5. **Wave 5 (depends on Wave 4):** Governance_Event**c, Behavioral_Flag**c
6. **Wave 6 (no object dependencies):** Platform Events (Commission_Event**e, Governance_Eval_Event**e, Signal_Event\_\_e)

---

## ADMIN WORKFLOW: TEMPLATE-BASED ASSIGNMENT

The template architecture enables rapid onboarding of new participants:

```
1. PLAN DESIGN (once per fiscal year per role)
   Admin creates Incentive_Plan_Template__c
     → Defines plan type, trigger, rates, caps, hold %
     → Creates Commission_Tier__c children (rate bands)
     → Creates Quota_Template__c with period targets
     → Sets eligible roles and transaction categories
     → Activates template

2. PARTICIPANT ASSIGNMENT (per participant — bulk supported)
   Admin selects template → selects participants (or role-based bulk)
     → System creates one Comp_Plan__c per participant (linked to template)
     → System creates Quota__c records per participant per period
       (target amounts from Quota_Template__c distribution method)
     → System sends plan acceptance notification (if acceptance gate configured)

3. MID-YEAR ADJUSTMENTS
   Template rate change → instantly affects all assigned participants
   Individual quota adjustment → admin edits Quota__c.Adjustment_Amount__c
   Individual rate override → admin sets Comp_Plan__c.Override_Base_Rate__c
   New hire → assign existing active template → auto-creates plan + quotas
   Termination → set Comp_Plan__c.Status__c = Terminated → future calcs stop
```

---

_Object Model Definition V1.1 — April 2, 2026_
_Spec Reference: UNIFIED_PLATFORM_SPEC.md V5.0_
