# RevenueTrust — Forecasting Module Object Model

**Version:** 1.4 — Final (all feedback passes complete)  
**Date:** April 2, 2026  
**Status:** SPEC FROZEN — ready for implementation

---

## Design Decisions to Resolve First

Before defining objects, we need to answer foundational questions about how the product discovers and adapts to the subscriber's existing org structure.

---

## 1. ORG ONBOARDING & DISCOVERY

### 1.1 The Problem

Every Salesforce org is different. Some have:

- Role Hierarchy defined and actively used
- Territory Management (original or Enterprise Territory Management 2.0) enabled
- Custom hierarchy objects they built themselves
- A mix: Role Hierarchy for security, Territory Management for forecasting
- Nothing — flat org, manager field on User only

Our forecasting hierarchy **must adapt to what exists**, not force a parallel structure. Otherwise we create admin burden and data drift.

### 1.2 Onboarding Discovery Flow

When the package is installed, the admin runs a **Setup Wizard** (LWC flow) that discovers the org's existing structure and recommends a configuration. This is NOT optional — it runs before any forecast data is created.

#### Step 1: Org Structure Discovery (Automated)

The wizard queries the org and reports what it finds:

| Discovery Check              | Query                                                                                                             | What We Learn                                                          |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| **Role Hierarchy**           | `SELECT Id, Name, ParentRoleId FROM UserRole`                                                                     | Does a role hierarchy exist? How many levels? How many users assigned? |
| **Territory Management**     | `Schema.getGlobalDescribe().containsKey('Territory2')` or check `Organization.Territory2Enabled`                  | Is ETM 2.0 enabled?                                                    |
| **Territory Assignments**    | `SELECT Id, Territory2Id, UserId FROM UserTerritory2Association`                                                  | Are users assigned to territories?                                     |
| **Territory Model**          | `SELECT Id, Name FROM Territory2Model WHERE State = 'Active'`                                                     | Is there an active territory model?                                    |
| **Manager Field**            | `SELECT Id, ManagerId FROM User WHERE IsActive = true AND ManagerId != null`                                      | Is Manager populated? How complete? (% of active users with a manager) |
| **Custom Hierarchy**         | Check for common patterns: custom objects with self-referential lookups named "Territory", "Region", "Team", etc. | Did they build their own?                                              |
| **Existing Forecast Setup**  | `SELECT Id FROM ForecastingType` + check if Collaborative Forecasting is enabled                                  | Are they using Salesforce native forecasting?                          |
| **Opportunity Record Types** | `SELECT Id, Name FROM RecordType WHERE SObjectType = 'Opportunity'`                                               | What pipeline segmentation exists?                                     |
| **Fiscal Year Settings**     | `Organization.FiscalYearStartMonth`, `Organization.UsesStartDateAsFiscalYearName`                                 | Custom fiscal year? Which month starts?                                |
| **Currency Settings**        | `Organization.IsMultiCurrencyOrganization`, `Organization.DefaultCurrencyIsoCode`                                 | Multi-currency? What's the corporate currency?                         |
| **Dated Exchange Rates**     | Check if `DatedConversionRate` is queryable                                                                       | Are dated exchange rates enabled?                                      |

#### Step 2: Admin Questionnaire (Guided)

Based on discovery results, the wizard asks targeted questions:

**Question 1: Forecasting Hierarchy Source**

> We detected {Role Hierarchy with N levels / Territory Management with N territories / Manager chain / None}.
>
> How do you want to define your forecasting hierarchy?
>
> - [ ] **Mirror Role Hierarchy** — Your existing role hierarchy becomes the forecast hierarchy. Users forecast at their role level. (Recommended if your role hierarchy reflects your sales management chain)
> - [ ] **Mirror Territory Management** — Territory assignments become the forecast scope. Users forecast within their assigned territories. (Recommended if you use ETM for sales territory planning)
> - [ ] **Mirror Manager Chain** — The User.ManagerId chain becomes the hierarchy. (Simplest option — works if Manager is consistently populated)
> - [ ] **Custom Hierarchy** — Define your own hierarchy in RevenueTrust. (Most flexible, most setup work)
> - [ ] **Hybrid** — Use Role Hierarchy for levels, Territory Management for scope grouping. (Advanced)

**Question 2: What is the forecasting scope?**

> When a manager opens their forecast view, what defines which pipeline records they see?
>
> - [ ] **My team's opportunities** — Opportunities owned by users who report to me (directly or indirectly)
> - [ ] **My territory's opportunities** — Opportunities assigned to my territory (via Territory2 association or custom field)
> - [ ] **Both** — Team ownership OR territory assignment (union)
> - [ ] **Custom** — Define a custom scope rule (e.g., based on a custom field on Opportunity)

**Question 3: Pipeline Record Type**

> Which Salesforce object represents your pipeline records?
>
> - [ ] **Opportunity** (standard — most common)
> - [ ] **Opportunity with specific Record Type(s):** {show discovered record types as checkboxes}
> - [ ] **Custom Object** — specify API name (advanced — Phase 2)

**Question 4: Forecasting Metrics**

> What values do your managers forecast? (Select up to 6 — you can rename labels)
>
> - [ ] **Opportunity Amount** (maps to `Opportunity.Amount`)
> - [ ] **Custom Currency Field:** {admin picks from Opportunity currency fields}
> - [ ] **Opportunity Line Item rollup** (computed from Products)
> - [ ] **Custom Formula** (define later)
>
> For each selected metric, provide:
>
> - Display Label (e.g., "TCV", "ARR", "Premium Value", "Contract Value")
> - Trend Threshold (change amount that triggers a trend indicator)
> - Is this the primary metric? (used for attainment, coverage ratio)

**Question 5: Forecast Categories**

> What categories do managers assign to pipeline records?
>
> Default set (edit names, add, remove):
>
> - Commit — counts toward target
> - Best Case — counts toward target
> - Pipeline — does not count toward target
> - Closed Won — terminal (auto-set on close)
> - Lost — terminal (auto-set on close)
>
> For each category: Name | Color | Counts toward target? | Terminal? | Regression warning?

**Question 6: Periods & Fiscal Calendar**

> We detected your fiscal year starts in {month} {standard/custom FY}.
>
> - Forecast Period Type: Weekly / Monthly / **Quarterly** / Annual
> - Period Labels: auto-generated from fiscal calendar (editable)
> - How many future periods visible? (default: 4)
> - Lock past periods for editing? Yes / No

**Question 7: Currency Handling**

> {Multi-currency detected / Single currency detected}
>
> - [ ] **Single currency** — all forecasts in corporate currency ({code})
> - [ ] **Multi-currency with Dated Exchange Rates** — convert to corporate currency using dated rates (recommended)
> - [ ] **Multi-currency with static rates** — use a fixed rate per scope/territory
> - [ ] **Dual display** — show both local and corporate currency (requires local currency field per participant)

#### Step 3: Configuration Generation

Based on answers, the wizard creates:

1. `Forecast_Configuration__c` record with all settings
2. `Forecast_Metric__c` records for each configured metric (with immutable slot bindings per §9.4)
3. `Forecast_Category__c` records for each configured category (with picklist sync per §9.3)
4. `Hierarchy_Source__mdt` configuration mapping the chosen hierarchy to platform fields
5. `Forecast_Participant__c` records for all active forecast participants (auto-populated from hierarchy sync per §9.6)
6. `Forecast_Period__c` records for current + future periods (auto-generated from fiscal calendar)

---

## 2. HIERARCHY SOURCE ABSTRACTION

### 2.1 The Problem

The forecasting hierarchy must work regardless of source (Role, Territory, Manager, Custom). We need an abstraction layer so the forecast engine never queries Role Hierarchy or Territory Management directly — it always works through our own hierarchy representation.

### 2.2 Design: Hierarchy_Source**mdt + Forecast_Participant**c

**Hierarchy_Source\_\_mdt** (Custom Metadata Type — the abstraction config):

| #   | Field API Name             | Type               | Label                      | Notes                                                                                                                 |
| --- | -------------------------- | ------------------ | -------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 1   | `Source_Type__c`           | Picklist           | Hierarchy Source           | Values: RoleHierarchy, TerritoryManagement, ManagerChain, Custom                                                      |
| 2   | `Sync_Enabled__c`          | Checkbox           | Auto-Sync Enabled          | If true, changes in source hierarchy auto-update Forecast_Participant\_\_c                                            |
| 3   | `Sync_Frequency__c`        | Picklist           | Sync Frequency             | Realtime (trigger), Daily (batch), Manual                                                                             |
| 4   | `Role_to_Level_Mapping__c` | LongTextArea(5000) | Role-to-Level Mapping      | JSON: {"CEO": 5, "VP Sales": 4, "Director": 3, "Manager": 2, "Rep": 1} — only for RoleHierarchy source                |
| 5   | `Territory_Model_Id__c`    | Text(18)           | Territory Model ID         | Only for TerritoryManagement source — which ETM model to use                                                          |
| 6   | `Scope_Field_API_Name__c`  | Text(100)          | Scope Field on Opportunity | Which field determines territory/scope for pipeline records. Default: "Territory2Id" or "OwnerId" depending on source |
| 7   | `Level_Count__c`           | Number(2,0)        | Hierarchy Levels           | Total number of levels (auto-detected or manually configured)                                                         |
| 8   | `Level_Labels__c`          | LongTextArea(1000) | Level Labels               | JSON: ["Rep", "Manager", "Director", "VP", "CRO"]                                                                     |

**Sync behavior:**

| Source Type             | How Forecast_Participant\_\_c is populated                                                                                                                                            | How scope is determined                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **RoleHierarchy**       | Scheduled job reads `UserRole` hierarchy. Maps each role to a Forecast_Level via `Role_to_Level_Mapping__c`. Creates/updates `Forecast_Participant__c` with level + Reports_To chain. | Pipeline records scoped by `Opportunity.OwnerId` → User's role → manager chain          |
| **TerritoryManagement** | Scheduled job reads `UserTerritory2Association`. Maps territory levels to Forecast_Level. Creates `Forecast_Participant__c` with territory as scope.                                  | Pipeline records scoped by `ObjectTerritory2Association` (Opportunity ↔ Territory link) |
| **ManagerChain**        | Scheduled job reads `User.ManagerId` chain. Auto-assigns levels by depth (leaf = 1, their manager = 2, etc.).                                                                         | Pipeline records scoped by `Opportunity.OwnerId` → manager chain                        |
| **Custom**              | Admin manually creates/manages `Forecast_Participant__c` records. No auto-sync.                                                                                                       | Admin defines scope rules                                                               |
| **Hybrid**              | Combines: levels from RoleHierarchy, scope from TerritoryManagement.                                                                                                                  | Level from role, pipeline scope from territory assignment                               |

**Key principle:** `Forecast_Participant__c` is the **only** object the forecast engine reads for hierarchy. It doesn't care where the data came from. The sync job is the translation layer.

---

## 3. OBJECT DEFINITIONS — FORECASTING MODULE

### 3.1 Forecast_Configuration\_\_c (Forecast Template — Custom Object)

**Purpose:** Top-level configuration for a forecasting deployment. Defines the rules for how forecasting works in this org. Multiple configurations can coexist (e.g., one per business unit). Custom Object (not CMT) per DP-1 — enables proper lookups, standard UI management, and dynamic creation by Setup Wizard.

| #   | Field API Name                   | Type               | Label                       | Notes                                                                              |
| --- | -------------------------------- | ------------------ | --------------------------- | ---------------------------------------------------------------------------------- |
| 1   | Name                             | Text(80)           | Configuration Name          | Standard Name field. e.g., "Enterprise Sales Forecast", "SMB Pipeline Review"      |
| 2   | `Is_Active__c`                   | Checkbox           | Active                      |                                                                                    |
| 3   | `Is_Default__c`                  | Checkbox           | Default                     | Used when no config specified                                                      |
| 4   | `Hierarchy_Levels__c`            | Number(2,0)        | Hierarchy Levels            | 2-10, auto-populated from discovery                                                |
| 5   | `Level_Labels__c`                | LongTextArea(1000) | Level Labels JSON           | `["Rep","Manager","Director","VP","CRO"]`                                          |
| 6   | `Period_Type__c`                 | Picklist           | Period Type                 | Weekly, Monthly, Quarterly, Annual                                                 |
| 7   | `Fiscal_Year_Start_Month__c`     | Number(2,0)        | FY Start Month              | 1-12. Auto-populated from Org fiscal year settings                                 |
| 8   | `Future_Periods_Visible__c`      | Number(2,0)        | Future Periods Visible      | How many periods ahead to show. Default: 4                                         |
| 9   | `Lock_Past_Periods__c`           | Checkbox           | Lock Past Periods           | Auto-freeze past periods for editing                                               |
| 10  | `Top_Level_Lock_Label__c`        | Text(30)           | Lock Action Label           | "Freeze", "Lock", "Approve", "Finalize"                                            |
| 11  | `Pipeline_Object__c`             | Text(100)          | Pipeline Object API Name    | Default: "Opportunity". Future: custom objects                                     |
| 12  | `Pipeline_Record_Type_Filter__c` | Text(500)          | Record Type Filter          | Comma-separated Record Type Developer Names. Blank = all                           |
| 13  | `Scope_Determination__c`         | Picklist           | Scope Determination         | Values: Ownership (OwnerId chain), Territory (Territory2 assignment), Custom Field |
| 14  | `Scope_Custom_Field__c`          | Text(100)          | Scope Custom Field API Name | Only used when Scope_Determination = Custom Field                                  |
| 15  | `Currency_Mode__c`               | Picklist           | Currency Mode               | Single, MultiWithDatedRates, MultiWithStaticRates, DualDisplay                     |
| 16  | `Corporate_Currency__c`          | Text(5)            | Corporate Currency ISO      | Auto-populated from Org default currency                                           |
| 17  | `Budget_Mode_Enabled__c`         | Checkbox           | Budget Mode Available       | Whether this config supports budget mode toggle                                    |
| 18  | `Prelock_Days__c`                | Number(3,0)        | Default Prelock Days        | Days before period end to start prelock                                            |
| 19  | `Pagination_Size__c`             | Number(3,0)        | Pagination Size             | Default: 40                                                                        |

---

### 3.2 Forecast_Metric\_\_c (Forecast Metric Definition — Custom Object)

**Purpose:** Defines each metric that participants override in the forecast grid. One configuration can have 1-6 metrics. This replaces the hardcoded NBV/ACV fields. Custom Object per DP-1 — child of Forecast_Configuration\_\_c with a proper Lookup.

| #   | Field API Name              | Type         | Label                 | Notes                                                                                         |
| --- | --------------------------- | ------------ | --------------------- | --------------------------------------------------------------------------------------------- |
| 1   | `Forecast_Configuration__c` | Lookup       | Parent Configuration  | → Forecast_Configuration\_\_c                                                                 |
| 2   | `Metric_Label__c`           | Text(50)     | Display Label         | What the user sees: "TCV", "ARR", "Premium Value", "Units", "Contract Value"                  |
| 3   | `Metric_API_Name__c`        | Text(50)     | Metric API Name       | Internal reference: "metric_1", "metric_2", etc.                                              |
| 4   | `Source_Field__c`           | Text(100)    | Source Field API Name | Opportunity field this metric reads from. e.g., "Amount", "Total_Contract_Value**c", "ACV**c" |
| 5   | `Metric_Type__c`            | Picklist     | Metric Type           | Currency, Number, Percentage                                                                  |
| 6   | `Aggregation__c`            | Picklist     | Aggregation Method    | Sum, Average, Count, Max, Min                                                                 |
| 7   | `Trend_Threshold__c`        | Number(18,2) | Trend Threshold       | Absolute change that triggers a trend indicator                                               |
| 8   | `Trend_Direction__c`        | Picklist     | Trend Direction       | Higher_Is_Better, Lower_Is_Better                                                             |
| 9   | `Display_Format__c`         | Text(20)     | Display Format        | "$M", "$K", "#", "%", etc.                                                                    |
| 10  | `Is_Primary__c`             | Checkbox     | Primary Metric        | Used for coverage ratio, attainment, governance threshold calculations                        |
| 11  | `Is_Required__c`            | Checkbox     | Required              | Must be filled to submit                                                                      |
| 12  | `Sort_Order__c`             | Number(2,0)  | Display Order         | Column order in forecast grid                                                                 |
| 13  | `Is_Editable__c`            | Checkbox     | Editable              | False = read-only display column (e.g., showing CRM value for reference)                      |
| 14  | `Local_Currency_Enabled__c` | Checkbox     | Show Local Currency   | Display a parallel local-currency column for this metric                                      |

**How it replaces hardcoded fields:**

| Old (Temenos)                             | New (RevenueTrust)                                                                                                          |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `Forecast_Override__c.NBV__c`             | Override record stores value in Metric_1_Value**c; Forecast_Metric**c defines label "NBV", source "Amount", primary=true    |
| `Forecast_Override__c.Incremental_ACV__c` | Override record stores value in Metric_2_Value**c; Forecast_Metric**c defines label "ACV", source "ACV\_\_c", primary=false |
| Hardcoded 2 metrics                       | 1-6 metrics via metadata records                                                                                            |
| Column headers hardcoded in LWC           | LWC reads Forecast_Metric\_\_mdt at load time, dynamically renders columns                                                  |

---

### 3.3 Forecast_Category\_\_c (Forecast Category Definition — Custom Object)

**Purpose:** Defines the ordered set of forecast categories with behavior rules. Each record corresponds to a picklist value on Forecast_Override**c.Forecast_Category**c (Restricted Picklist per DP-3). Custom Object per DP-1 — child of Forecast_Configuration\_\_c.

| #   | Field API Name              | Type        | Label                  | Notes                                                                                                |
| --- | --------------------------- | ----------- | ---------------------- | ---------------------------------------------------------------------------------------------------- |
| 1   | `Forecast_Configuration__c` | Lookup      | Parent Configuration   | → Forecast_Configuration\_\_c                                                                        |
| 2   | `Category_Label__c`         | Text(50)    | Category Name          | "Commit", "Best Case", "Pipeline", "Closed Won", "Lost"                                              |
| 3   | `Category_API_Name__c`      | Text(50)    | Category API Name      | Internal reference: "commit", "best_case", etc.                                                      |
| 4   | `Color_Hex__c`              | Text(7)     | Color                  | Hex color for UI: "#2ECC71"                                                                          |
| 5   | `Counts_Toward_Target__c`   | Checkbox    | Counts Toward Target   | Included in coverage ratio calculation                                                               |
| 6   | `Is_Terminal__c`            | Checkbox    | Terminal               | Once set, no further changes allowed (Closed Won, Lost)                                              |
| 7   | `Regression_Warning__c`     | Checkbox    | Regression Warning     | Moving TO this category from a higher one triggers a warning                                         |
| 8   | `Is_High_Confidence__c`     | Checkbox    | High Confidence        | Used by governance rules — CG-1/CG-2 trigger when moving TO a high-confidence category               |
| 9   | `Budget_Equivalent__c`      | Text(50)    | Budget Mode Equivalent | Category API name to use when template runs in budget mode                                           |
| 10  | `Auto_Set_On_Stage__c`      | Text(100)   | Auto-Set on CRM Stage  | CRM stage value(s) that auto-set this category. e.g., "Closed Won" → auto-sets "closed_won" category |
| 11  | `Sort_Order__c`             | Number(2,0) | Sort Order             | Display and confidence ranking order (1 = highest confidence)                                        |

---

### 3.4 Forecast_Period\_\_c (Forecast Period — Custom Object)

**Renamed from:** `Forecast__c`  
**Why rename:** Your question was right — `Forecast__c` is ambiguous. `Forecast_Period__c` clearly communicates "this is a time period container."

**Purpose:** Represents one forecast period. Auto-generated by the setup wizard and the period auto-generation batch job.

| #   | Field API Name                 | Type     | Label                     | Notes                                                                                         |
| --- | ------------------------------ | -------- | ------------------------- | --------------------------------------------------------------------------------------------- |
| 1   | `Forecast_Configuration__c`    | Lookup   | Configuration             | → Forecast_Configuration\_\_c (proper Lookup — resolved per DP-1)                             |
| 2   | `Period_Label__c`              | Text(50) | Period Label              | **Auto-generated** from fiscal calendar + period type. e.g., "Q2 FY2027". Admin can override. |
| 3   | `Period_Type__c`               | Picklist | Period Type               | Weekly, Monthly, Quarterly, Annual — inherited from config                                    |
| 4   | `Start_Date__c`                | Date     | Start Date                |                                                                                               |
| 5   | `End_Date__c`                  | Date     | End Date                  |                                                                                               |
| 6   | `Fiscal_Year__c`               | Text(10) | Fiscal Year               | Auto-populated: "FY2027"                                                                      |
| 7   | `Status__c`                    | Picklist | Status                    | Values: Scheduled, Open, Prelock, Frozen, Closed                                              |
| 8   | `Budget_Mode__c`               | Checkbox | Budget Mode               | Switches categories to budget equivalents                                                     |
| 9   | `Prelock_Date__c`              | Date     | Prelock Date              | Auto-calculated: End_Date - Prelock_Days from config                                          |
| 10  | `Frozen_By__c`                 | Lookup   | Frozen By                 | → User who executed freeze                                                                    |
| 11  | `Frozen_On__c`                 | DateTime | Frozen On                 |                                                                                               |
| 12  | `Opened_On__c`                 | DateTime | Opened On                 | When status changed to Open                                                                   |
| 13  | `Notification_Sent__c`         | Checkbox | Open Notification Sent    |                                                                                               |
| 14  | `Prelock_Notification_Sent__c` | Checkbox | Prelock Notification Sent | NEW — warn users period is about to lock                                                      |

**Period auto-generation:** A scheduled batch job runs monthly. It checks how many future periods exist vs. `Future_Periods_Visible__c` config, and creates new `Forecast_Period__c` records as needed. Period labels are generated from the fiscal calendar rules.

**Status lifecycle:**

```
Scheduled → Open → Prelock → Frozen → Closed
                                         │
                              (optional: Reopened → Open)
```

- **Scheduled:** Future period. Visible in multi-period timeline but not editable.
- **Open:** Active for forecasting. Overrides can be created/edited.
- **Prelock:** Warning state. Edits still allowed but "period closing soon" banner shown. Auto-set N days before End_Date.
- **Frozen:** Top-level user executed freeze. All overrides immutable. Governance pending items auto-expired.
- **Closed:** Archival state after fiscal year close. Read-only.

---

### 3.5 Forecast_Participant\_\_c (Forecast Participant — Custom Object)

**Renamed from:** `Forecast_User__c`  
**Why rename:** "Participant" is the generic term used throughout the spec. Consistent naming.

**Purpose:** Assigns a user to a scope within a forecast period. Defines their hierarchy level and submission status. **This is the platform's own hierarchy representation** — populated by the sync job from whichever source was chosen during onboarding (§2.2).

| #   | Field API Name             | Type         | Label                   | Notes                                                                                          |
| --- | -------------------------- | ------------ | ----------------------- | ---------------------------------------------------------------------------------------------- |
| 1   | `Forecast_Period__c`       | Lookup       | Forecast Period         | → Forecast_Period\_\_c                                                                         |
| 2   | `User__c`                  | Lookup       | Participant             | → User                                                                                         |
| 3   | `Reports_To__c`            | Lookup(self) | Reports To              | → Forecast_Participant\_\_c. **This is the forecast hierarchy chain.** Populated by sync job.  |
| 4   | `Hierarchy_Level__c`       | Number(2,0)  | Hierarchy Level         | Integer 1-N. 1 = lowest (rep), N = highest (CRO/COO).                                          |
| 5   | `Level_Label__c`           | Text(50)     | Level Label             | Auto-populated from config's `Level_Labels__c` JSON based on level number                      |
| 6   | `Scope_Id__c`              | Text(50)     | Scope ID                | Territory ID, Role ID, or custom scope key — depends on hierarchy source                       |
| 7   | `Scope_Name__c`            | Text(100)    | Scope Name              | Display name of the scope/territory                                                            |
| 8   | `Scope_Parent_Id__c`       | Text(50)     | Parent Scope ID         | For nested scope hierarchies                                                                   |
| 9   | `Region__c`                | Text(100)    | Region                  | Top-level scope grouping                                                                       |
| 10  | `Sub_Region__c`            | Text(100)    | Sub-Region              | Mid-level scope grouping                                                                       |
| 11  | `Submission_Status__c`     | Picklist     | Submission Status       | Not Started, Saved, Submitted, Frozen                                                          |
| 12  | `Saved_On__c`              | DateTime     | Saved On                |                                                                                                |
| 13  | `Submitted_On__c`          | DateTime     | Submitted On            |                                                                                                |
| 14  | `Frozen_On__c`             | DateTime     | Frozen On               |                                                                                                |
| 15  | `Local_Currency__c`        | Text(5)      | Local Currency          | ISO currency code. Auto-populated from territory currency or user locale                       |
| 16  | `Email_Recipients__c`      | Text(255)    | Notification Recipients | Override notification targets for this participant                                             |
| 17  | `Delegate__c`              | Lookup       | Approval Delegate       | → User                                                                                         |
| 18  | `Delegate_Start__c`        | Date         | Delegate Start          |                                                                                                |
| 19  | `Delegate_End__c`          | Date         | Delegate End            |                                                                                                |
| 20  | `Hierarchy_Source_Id__c`   | Text(18)     | Source Record ID        | The UserRole ID, Territory2 ID, or User ID that this record was synced from. For traceability. |
| 21  | `Hierarchy_Source_Type__c` | Text(30)     | Source Type             | RoleHierarchy, TerritoryManagement, ManagerChain, Manual                                       |
| 22  | `Last_Synced__c`           | DateTime     | Last Synced             | When the sync job last updated this record                                                     |

**Deduplication:** Unique constraint on `Forecast_Period__c` + `User__c` + `Scope_Id__c` — a user can appear multiple times in one period if they have multiple scopes (e.g., manages two territories), but only once per scope.

---

### 3.6 Forecast_Override\_\_c (Forecast Override — Custom Object)

**Purpose:** One record = one pipeline record's values as overridden by one hierarchy level in one forecast period. This is the core forecasting IP.

| #   | Field API Name                       | Type                | Label                       | Notes                                                                                                                                                                                                                                                                       |
| --- | ------------------------------------ | ------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| —   | **Relationships**                    |                     |                             |                                                                                                                                                                                                                                                                             |
| 1   | `Forecast_Period__c`                 | Lookup              | Forecast Period             | → Forecast_Period\_\_c                                                                                                                                                                                                                                                      |
| 2   | `Opportunity__c`                     | Lookup              | Pipeline Record             | → Opportunity (subscriber object). Field API name configurable via Field_Mapping\_\_mdt for future custom object support.                                                                                                                                                   |
| 3   | `Forecast_Participant__c`            | Lookup              | Forecast Participant        | → Forecast_Participant\_\_c (the user + scope + period combo)                                                                                                                                                                                                               |
| 4   | `User__c`                            | Lookup              | Participant                 | → User (denormalized for query performance)                                                                                                                                                                                                                                 |
| 5   | `Previous_Level_Override__c`         | Lookup(self)        | Previous Level Override     | The override for this same record by the level below. Enables "show me what my manager submitted"                                                                                                                                                                           |
| 6   | `Previous_Period_Override__c`        | Lookup(self)        | Previous Period Override    | The override for this same record in the prior period. Enables trend calculation.                                                                                                                                                                                           |
| —   | **Category & Status**                |                     |                             |                                                                                                                                                                                                                                                                             |
| 7   | `Forecast_Category__c`               | Restricted Picklist | Forecast Category           | Default values: Commit, Best Case, Pipeline, Closed Won, Lost. Restricted picklist — values managed by admin and synced with Forecast_Category\_\_c records. Enables native reporting, dashboards, and list view filtering.                                                 |
| 8   | `Status__c`                          | Picklist            | Override Status             | New, Saved, Submitted, Frozen                                                                                                                                                                                                                                               |
| 9   | `Hierarchy_Level__c`                 | Number(2,0)         | Hierarchy Level             | Which level created this override (denormalized from Forecast_Participant\_\_c)                                                                                                                                                                                             |
| —   | **Metric Values (generic slots)**    |                     |                             |                                                                                                                                                                                                                                                                             |
| 10  | `Metric_1_Value__c`                  | Number(18,2)        | Metric 1 Value              | Generic slot. Label comes from Forecast_Metric\_\_mdt. Stores the override value in corporate currency.                                                                                                                                                                     |
| 11  | `Metric_2_Value__c`                  | Number(18,2)        | Metric 2 Value              |                                                                                                                                                                                                                                                                             |
| 12  | `Metric_3_Value__c`                  | Number(18,2)        | Metric 3 Value              |                                                                                                                                                                                                                                                                             |
| 13  | `Metric_4_Value__c`                  | Number(18,2)        | Metric 4 Value              |                                                                                                                                                                                                                                                                             |
| 14  | `Metric_5_Value__c`                  | Number(18,2)        | Metric 5 Value              |                                                                                                                                                                                                                                                                             |
| 15  | `Metric_6_Value__c`                  | Number(18,2)        | Metric 6 Value              |                                                                                                                                                                                                                                                                             |
| 16  | `Metric_1_Local__c`                  | Number(18,2)        | Metric 1 Local Currency     |                                                                                                                                                                                                                                                                             |
| 17  | `Metric_2_Local__c`                  | Number(18,2)        | Metric 2 Local Currency     |                                                                                                                                                                                                                                                                             |
| 18  | `Metric_3_Local__c`                  | Number(18,2)        | Metric 3 Local Currency     |                                                                                                                                                                                                                                                                             |
| 19  | `Metric_4_Local__c`                  | Number(18,2)        | Metric 4 Local Currency     |                                                                                                                                                                                                                                                                             |
| 20  | `Metric_5_Local__c`                  | Number(18,2)        | Metric 5 Local Currency     |                                                                                                                                                                                                                                                                             |
| 21  | `Metric_6_Local__c`                  | Number(18,2)        | Metric 6 Local Currency     |                                                                                                                                                                                                                                                                             |
| —   | **Close Date**                       |                     |                             |                                                                                                                                                                                                                                                                             |
| 22  | `Close_Date_Override__c`             | Date                | Close Date Override         | Manager can override the CRM close date in the forecast                                                                                                                                                                                                                     |
| —   | **Currency**                         |                     |                             |                                                                                                                                                                                                                                                                             |
| 23  | `Currency_Code__c`                   | Text(5)             | Currency Code               | The corporate currency this override is stored in                                                                                                                                                                                                                           |
| 24  | `Local_Currency_Code__c`             | Text(5)             | Local Currency Code         | The participant's local currency                                                                                                                                                                                                                                            |
| 25  | `Exchange_Rate__c`                   | Number(18,6)        | Exchange Rate               | Corporate → local rate used at time of save. **Source:** If Dated Exchange Rates enabled, pulled from `DatedConversionRate` for the period end date. Otherwise, from `CurrencyType.ConversionRate`. Stored at save time for audit — the rate at time of override is frozen. |
| —   | **Timestamps**                       |                     |                             |                                                                                                                                                                                                                                                                             |
| 26  | `Saved_On__c`                        | DateTime            | Saved On                    |                                                                                                                                                                                                                                                                             |
| 27  | `Submitted_On__c`                    | DateTime            | Submitted On                |                                                                                                                                                                                                                                                                             |
| —   | **Notes**                            |                     |                             |                                                                                                                                                                                                                                                                             |
| 28  | `Comment__c`                         | TextArea(500)       | Inline Comment              | Short comment visible in the grid row                                                                                                                                                                                                                                       |
| 29  | `Notes__c`                           | LongTextArea(32000) | Extended Notes              | Detailed notes visible in the expand panel                                                                                                                                                                                                                                  |
| —   | **Governance**                       |                     |                             |                                                                                                                                                                                                                                                                             |
| 30  | `Pending_Approval__c`                | Checkbox            | Pending Governance Approval | CG-3 hard block. Excluded from rollups until approved.                                                                                                                                                                                                                      |
| —   | **AI**                               |                     |                             |                                                                                                                                                                                                                                                                             |
| 31  | `Close_Probability__c`               | Percent             | AI Close Probability        | Tier 2 advisory output (§9.2.1)                                                                                                                                                                                                                                             |
| 32  | `Close_Probability_Factors__c`       | LongTextArea(5000)  | Probability Factors         | JSON: top contributing factors. Answers your question: "how did we arrive at this?"                                                                                                                                                                                         |
| 33  | `Close_Probability_Confidence__c`    | Picklist            | Probability Confidence      | High (50+ historical records), Medium (20-49), Low (<20)                                                                                                                                                                                                                    |
| 34  | `Close_Probability_Model_Version__c` | Text(20)            | Model Version               | Which AI model version produced this prediction                                                                                                                                                                                                                             |
| —   | **Integrity**                        |                     |                             |                                                                                                                                                                                                                                                                             |
| 35  | `Valid__c`                           | Checkbox            | Valid                       | False if the source Opportunity no longer qualifies for this forecast                                                                                                                                                                                                       |
| 36  | `Source_Record_Deleted__c`           | Checkbox            | Source Record Deleted       | CRM record was deleted (§1.5.2)                                                                                                                                                                                                                                             |
| 37  | `External_Id__c`                     | Text(50)            | External ID                 | Unique, External ID. For data integration.                                                                                                                                                                                                                                  |
| 38  | `CRM_Divergence__c`                  | Checkbox            | CRM Divergence              | True if CRM base fields changed after this override was submitted (§1.5.2)                                                                                                                                                                                                  |
| 39  | `CRM_Divergence_Details__c`          | Text(500)           | Divergence Details          | Which fields changed. e.g., "Amount: $400K→$350K, CloseDate: Apr→Jun"                                                                                                                                                                                                       |

**What's NOT on this object (moved elsewhere):**

- Formula fields for Opportunity data (Owner, Stage, Close Date) → These are read at runtime from the Opportunity via the CRM abstraction layer, not stored as formula fields. Formulas create hard dependencies on subscriber field names. Instead, the LWC reads Opportunity fields at page load using the Field_Mapping\_\_mdt configuration.
- Territory ID / Subregion → These are on Forecast_Participant\_\_c (scope is a property of the participant assignment, not the override)

---

### 3.7 Forecast_Comment\_\_c (Forecast Comment — Custom Object)

**Purpose:** Historical threaded notes per pipeline record per period. Separate from the inline override comment — these are full discussion entries.

| #   | Field API Name                | Type                | Label             | Notes                                                                                 |
| --- | ----------------------------- | ------------------- | ----------------- | ------------------------------------------------------------------------------------- |
| 1   | `Forecast_Override__c`        | Lookup              | Forecast Override | → Forecast_Override\_\_c (the specific override being discussed)                      |
| 2   | `Forecast_Period__c`          | Lookup              | Forecast Period   | → Forecast_Period\_\_c (for period-level queries)                                     |
| 3   | `Opportunity__c`              | Lookup              | Pipeline Record   | → Opportunity (denormalized for querying by deal)                                     |
| 4   | `Author__c`                   | Lookup              | Author            | → User                                                                                |
| 5   | `Comment__c`                  | LongTextArea(32000) | Comment           |                                                                                       |
| 6   | `Comment_Type__c`             | Picklist            | Type              | Note, Governance_Justification, Override_Reason, Category_Change_Reason, System_Event |
| 7   | `Hierarchy_Level__c`          | Number(2,0)         | Author Level      | Denormalized — which level the author was at when they wrote this                     |
| 8   | `Is_System__c`                | Checkbox            | System Generated  | True for auto-generated comments (category changes, governance events)                |
| 9   | `Related_Governance_Event__c` | Lookup              | Governance Event  | → Governance_Event\_\_c (links justification to the governance action)                |

---

### 3.8 Field_Mapping\_\_mdt (CRM Field Mapping — Custom Metadata)

**Purpose:** Maps logical platform field names to subscriber org field API names. This is how the platform reads Opportunity data without hardcoding field names (§14.4).

| #   | Field API Name       | Type      | Label                    | Notes                                                                                                                                              |
| --- | -------------------- | --------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Logical_Name__c`    | Text(100) | Logical Field Name       | Platform's internal reference: "Pipeline.Amount", "Pipeline.CloseDate", "Pipeline.Stage", "Pipeline.Owner", "Pipeline.Name", "Pipeline.RecordType" |
| 2   | `Object_API_Name__c` | Text(100) | Object API Name          | Default: "Opportunity"                                                                                                                             |
| 3   | `Field_API_Name__c`  | Text(100) | Field API Name           | Subscriber's field: "Amount", "Total_Contract_Value\_\_c", "CloseDate", "StageName", etc.                                                          |
| 4   | `Field_Type__c`      | Picklist  | Field Data Type          | Currency, Date, Text, Number, Picklist, Lookup                                                                                                     |
| 5   | `Is_Required__c`     | Checkbox  | Required                 | Platform won't function without this mapping                                                                                                       |
| 6   | `Default_Value__c`   | Text(100) | Default Salesforce Field | Pre-populated standard mapping (admin can override)                                                                                                |

**Required mappings (auto-populated during onboarding, admin can change):**

| Logical Name           | Default Mapping                     | Required?                      |
| ---------------------- | ----------------------------------- | ------------------------------ |
| `Pipeline.Amount`      | `Opportunity.Amount`                | Yes                            |
| `Pipeline.CloseDate`   | `Opportunity.CloseDate`             | Yes                            |
| `Pipeline.Stage`       | `Opportunity.StageName`             | Yes                            |
| `Pipeline.Owner`       | `Opportunity.OwnerId`               | Yes                            |
| `Pipeline.Name`        | `Opportunity.Name`                  | Yes                            |
| `Pipeline.RecordType`  | `Opportunity.RecordTypeId`          | No                             |
| `Pipeline.AccountName` | `Opportunity.Account.Name`          | No                             |
| `Pipeline.Probability` | `Opportunity.Probability`           | No                             |
| `Pipeline.Number`      | `Opportunity.Opportunity_Number__c` | No — may not exist in all orgs |
| `Pipeline.Territory`   | `Opportunity.Territory2Id`          | No — only if ETM enabled       |

---

## 4. DECISION POINTS — RESOLVED

| DP       | Decision                                                  | Rationale                                                                                                                                                                                                                                                                                                                       |
| -------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DP-1** | **Custom Object** for Forecast_Configuration\_\_c         | Proper lookups from Forecast_Period\_\_c. Setup Wizard creates records dynamically. Standard UI for admin management. Metric and Category definitions also as Custom Objects (not CMT) since the wizard needs to create them.                                                                                                   |
| **DP-2** | **6 fixed metric slots** on Forecast_Override\_\_c        | Simple, fast queries, no joins. 2-3 metrics is the norm. Can add Metric_7–10 in future release without breaking data.                                                                                                                                                                                                           |
| **DP-3** | **Restricted Picklist** for Forecast_Category\_\_c        | Reporting is the key. Users need native picklist grouping in reports, list view filtering, and dashboard charts. Adding a category requires a picklist value deployment — acceptable trade-off since categories change rarely. Setup Wizard creates initial picklist values; admin adds new ones via standard field management. |
| **DP-4** | **Summary Participant** record with `Scope_Id__c = 'ALL'` | Multi-scope users (e.g., manages EMEA + APAC) get individual scope records + one summary record. Summary is read-only, auto-computed from scope submissions. Provides the "combined view" without complicating the per-scope submission workflow.                                                                               |
| **DP-5** | **Owner-only** for V1                                     | Deal appears only in the owner's forecast. Simplest. V2 adds split support via `OpportunitySplit` standard object.                                                                                                                                                                                                              |

### DP-1 Impact: All Configuration Objects are Custom Objects

Since DP-1 resolved to Custom Object, the following changes apply:

- `Forecast_Configuration__mdt` → **`Forecast_Configuration__c`** (custom object)
- `Forecast_Metric__mdt` → **`Forecast_Metric__c`** (custom object, child of Forecast_Configuration\_\_c)
- `Forecast_Category__mdt` → **`Forecast_Category__c`** (custom object, child of Forecast_Configuration\_\_c)
- `Hierarchy_Source__mdt` stays as CMT (singleton config, truly static, set once during onboarding)
- `Field_Mapping__mdt` stays as CMT (deployment-level config, not org data)

This means:

- Setup Wizard can use standard DML to create all config records
- Forecast_Period**c has a real Lookup to Forecast_Configuration**c
- Metrics and Categories are proper children — no fragile developer name string references
- Admins manage configuration through standard Salesforce record pages (not Setup menu)
- We ship Starter Templates as pre-seeded records in the package (see §11.7 Configuration Layering)

### DP-3 Impact: Restricted Picklist on Forecast_Override\_\_c

`Forecast_Category__c` on Forecast_Override\_\_c is now a **Restricted Picklist**. Implications:

- Default picklist values shipped with the package: Commit, Best Case, Pipeline, Closed Won, Lost
- Forecast_Category\_\_c (the custom object) still exists — it stores behavior metadata (color, counts toward target, terminal, regression warning, etc.)
- The picklist field values and the Forecast_Category**c records must stay in sync. The admin UI for adding a category does BOTH: adds the picklist value + creates the Forecast_Category**c record.
- Reports, dashboards, and list views can natively group by Forecast_Category\_\_c
- Validation rule ensures the picklist value matches a record in Forecast_Category\_\_c (defense against orphaned picklist values)

### DP-4 Impact: Summary Participant on Forecast_Participant\_\_c

Added to Forecast_Participant\_\_c:

| #   | Field API Name          | Type               | Label                  | Notes                                                               |
| --- | ----------------------- | ------------------ | ---------------------- | ------------------------------------------------------------------- |
| 23  | `Is_Summary__c`         | Checkbox           | Summary Record         | True = auto-computed rollup across all scopes for this user         |
| 24  | `Summary_Source_Ids__c` | LongTextArea(1000) | Source Participant IDs | JSON array of Forecast_Participant\_\_c IDs this summary aggregates |

**Behavior:**

- When the hierarchy sync creates multiple scope records for one user, it also creates a Summary Participant with `Scope_Id__c = 'ALL'`, `Is_Summary__c = true`
- Summary record's submission status = the LOWEST status among its source records (if any scope is "Not Started", summary shows "Not Started")
- Summary record is read-only — user cannot directly edit overrides on the summary. They must go to individual scope views.
- Manager Decision Cockpit shows the summary view by default for multi-scope users, with a scope picker to drill into individual scopes

---

## 5. CROSS-MODULE: QUOTA & ATTAINMENT IN FORECASTING

### 5.1 The Problem

Forecasting and Commissions are separate modules, but they share a critical data point: **the target/quota and how much has been achieved**. A forecast view without attainment context is incomplete — managers need to know:

- "My team has $3.8M committed against a $4.2M target" → **Coverage ratio**
- "Rep A is at 87% attainment with $420K in pipeline" → **Can they hit quota?**
- "Rep B is $42K from the accelerator threshold" → **Comp-aware governance context**

These numbers come from the Commissions module's `Quota__c` object. The Forecasting module must **read** them but never **write** them.

### 5.2 How Forecasting Reads Quota Data

The Forecasting module reads from Quota\_\_c (owned by Sales Incentives module) at two levels:

**Participant-level:** Each Forecast_Participant\_\_c record links to the participant's quota for the matching period.

| Data Point      | Source                                                                                                                      | Used In                                                  |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| Target Amount   | `Quota__c.Adjusted_Target__c` where Participant + Period overlap                                                            | Forecast Summary panel, Coverage Ratio                   |
| Achieved Amount | `Quota__c.Achieved_Amount__c`                                                                                               | Forecast Summary panel, Attainment %                     |
| Attainment %    | `Quota__c.Attainment__c`                                                                                                    | Inline Estimator threshold proximity, Governance rules   |
| Rate Tier       | Derived: `Quota__c.Attainment__c` matched against `Commission_Tier__c` on the participant's `Comp_Plan__c.Plan_Template__c` | Inline Estimator rate display, CG-2/CG-3/CG-4 evaluation |

**Pipeline-record-level (Inline Estimator):** For each deal in the forecast grid, the estimator calculates:

```
If this deal closes at {override metric value}:
  New attainment = current achieved + deal value
  Current tier = tier for current attainment
  New tier = tier for new attainment
  Payout on this deal = deal value × current tier rate
  Retroactive uplift = (new tier rate - current tier rate) × prior achieved (if tier is retroactive)
  Distance to next tier = next tier threshold - new attainment
```

All of this reads from Quota**c + Commission_Tier**c + Comp_Plan\_\_c. **The Forecasting module never writes to any of these objects** (§1.6.1 Module Isolation Rules).

### 5.3 Attainment Fields on Forecast_Participant\_\_c

To avoid querying Quota**c on every page load, we cache key attainment data on the Forecast_Participant**c record. A scheduled job (or Platform Event listener on Quota\_\_c changes) keeps these in sync.

**Additional fields on Forecast_Participant\_\_c:**

| #   | Field API Name              | Type     | Label                  | Notes                                                                            |
| --- | --------------------------- | -------- | ---------------------- | -------------------------------------------------------------------------------- |
| 25  | `Quota_Target__c`           | Currency | Quota Target           | Cached from Quota**c.Adjusted_Target**c for the matching period + primary metric |
| 26  | `Quota_Achieved__c`         | Currency | Quota Achieved         | Cached from Quota**c.Achieved_Amount**c                                          |
| 27  | `Attainment_Pct__c`         | Percent  | Attainment %           | Formula: Quota_Achieved**c / Quota_Target**c (or computed if target = 0)         |
| 28  | `Current_Rate_Tier__c`      | Text(50) | Current Rate Tier      | Cached tier name from Commission_Tier\_\_c matching current attainment           |
| 29  | `Current_Rate_Pct__c`       | Percent  | Current Rate %         | Cached rate from current tier                                                    |
| 30  | `Next_Tier_Name__c`         | Text(50) | Next Tier              | Name of the next tier above current                                              |
| 31  | `Next_Tier_Distance__c`     | Currency | Distance to Next Tier  | Threshold amount - Achieved amount                                               |
| 32  | `Quota_Id__c`               | Lookup   | Quota                  | → Quota\_\_c (direct link for drill-through)                                     |
| 33  | `Comp_Plan_Id__c`           | Lookup   | Incentive Plan         | → Comp_Plan\_\_c (direct link for drill-through)                                 |
| 34  | `Attainment_Last_Synced__c` | DateTime | Attainment Last Synced | When these cached fields were last updated                                       |

**Cache invalidation:** These fields are refreshed:

1. When a `Quota__c.Achieved_Amount__c` changes (Platform Event from Incentive module)
2. On forecast page load if `Attainment_Last_Synced__c` is older than 1 hour (lazy refresh)
3. On nightly batch job (guaranteed daily freshness)

### 5.4 Forecast Summary Panel — Attainment Context

The attainment display is **configurable during onboarding** — the org chooses how they want to see progress against targets.

#### 5.4.1 Onboarding Wizard — Summary Layout Question

Added to the Setup Wizard (after Question 6 — Periods & Fiscal Calendar):

**Question 8: Attainment Summary Layout**

> How do you want to see attainment in the Forecast Summary?
>
> - [ ] **Current Period Only** — Show target/achieved/remaining for the selected period only (simplest)
> - [ ] **Period + Year-to-Date** — Show current period AND cumulative YTD side by side
> - [ ] **Expanded Multi-Period** — Show Month | Quarter | Year all in one layout (most comprehensive)
> - [ ] **None** — Don't show attainment (Forecasting standalone, no Incentives module)

This is stored as `Attainment_Layout__c` on Forecast_Configuration\_\_c.

**New field on Forecast_Configuration\_\_c:**

| #   | Field API Name         | Type     | Label             | Notes                                                               |
| --- | ---------------------- | -------- | ----------------- | ------------------------------------------------------------------- |
| 20  | `Attainment_Layout__c` | Picklist | Attainment Layout | Values: Current_Period, Period_And_YTD, Expanded_Multi_Period, None |

#### 5.4.2 Summary Layouts

**Layout A: Current Period Only** (`Attainment_Layout__c = 'Current_Period'`)

```
FORECAST SUMMARY — {Scope} — {Period Label}
─────────────────────────────────────────────
Target:      $1,050,000        Committed:   $980,000
Achieved:    $810,000          Best Case:   $1,280,000
Remaining:   $240,000          Pipeline:    $2,100,000
Attainment:  77.1%             Coverage:    2.0×

Current Tier: Base (8%)
Next Tier:    Accelerator (12%) — $242,000 away
```

**Layout B: Period + Year-to-Date** (`Attainment_Layout__c = 'Period_And_YTD'`)

```
FORECAST SUMMARY — {Scope} — {Period Label}
──────────────────────────────────────────────────────────────
                       Q2 FY2027           YTD (FY2027)
                    ─────────────       ─────────────────
Target:             $1,050,000           $4,200,000
Achieved:           $810,000             $3,100,000
Remaining:          $240,000             $1,100,000
Attainment:         77.1%                73.8%

Committed:          $980,000             $3,800,000
Best Case:          $1,280,000           $5,100,000
Pipeline:           $2,100,000           $8,600,000
Coverage:           2.0×                 1.5×

Current Tier: Base (8%) — quarterly
Annual Tier:  Base (8%) — $242,000 from Accelerator (12%)
```

**Layout C: Expanded Multi-Period** (`Attainment_Layout__c = 'Expanded_Multi_Period'`)

```
FORECAST SUMMARY — {Scope} — FY2027
────────────────────────────────────────────────────────────────────────────────
                  Apr      May      Jun     Q2 FY27    Q1 FY27    YTD FY27
                ───────  ───────  ───────  ─────────  ─────────  ──────────
Target:         $350K    $350K    $350K    $1,050K    $1,050K    $4,200K
Achieved:       $380K    $310K    $120K    $810K      $1,180K    $3,100K
Remaining:      —        $40K     $230K    $240K      —          $1,100K
Attainment:     108.6%   88.6%    34.3%    77.1%      112.4%     73.8%

Committed:      —        —        $180K    $980K      —          $3,800K
Best Case:      —        —        $320K    $1,280K    —          $5,100K
Pipeline:       —        —        $680K    $2,100K    —          $8,600K

                                          ┌─ Current Q ─┐  ┌── Full Year ──┐
Rate Tier:                                  Base (8%)       Base (8%)
Next Tier:                                  Accel (12%)     Accel (12%)
Distance:                                   $242K away      $242K away
```

**Layout C behavior:**

- Shows monthly columns for the **current quarter** only (past months show achieved, current month shows achieved + in-progress)
- Past quarters show as single rolled-up columns (Q1 = done, just the totals)
- YTD column always present on the right
- Monthly columns for past months: Achieved is final, Remaining/Committed/Pipeline are blank (period closed)
- Rate tier section shows both period-level tier (if quarterly accelerators) and annual tier
- Admin can configure which periods are expanded (default: current quarter months + past quarters + YTD)

#### 5.4.3 Data Sources for Multi-Period Display

| Column Type                      | Data Source                                                                                        | Notes                                                                                                      |
| -------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Monthly target                   | `Quota__c` where `Period_Type__c = 'Monthly'` for the matching month                               | Requires monthly Quota\_\_c records. If org only has quarterly quotas, monthly is derived as quarterly ÷ 3 |
| Monthly achieved                 | `Quota__c.Achieved_Amount__c` for the matching month                                               | Updated by Incentive calculation engine when deals close                                                   |
| Quarterly target                 | `Quota__c` where `Period_Type__c = 'Quarterly'`                                                    | Or sum of 3 monthly quotas                                                                                 |
| Quarterly achieved               | Sum of monthly achieved for the quarter, OR `Quota__c.Achieved_Amount__c` for the quarterly record |                                                                                                            |
| YTD target                       | Sum of all quarterly targets for the fiscal year, OR `Quota__c` where `Period_Type__c = 'Annual'`  |                                                                                                            |
| YTD achieved                     | Sum of all quarterly achieved                                                                      |                                                                                                            |
| Committed / Best Case / Pipeline | Sum of `Forecast_Override__c.Metric_1_Value__c` grouped by `Forecast_Category__c` for the period   | Only for current/future periods — past periods show achieved only                                          |
| Coverage                         | Pipeline ÷ Remaining                                                                               | Only meaningful for current/future periods                                                                 |

**Key implication for Quota\_\_c design:** The expanded multi-period layout needs quota records at **multiple granularities** (monthly + quarterly + annual) for the same participant. The Quota_Template**c's `Distribution_Method**c` (Equal/Weighted/Custom) determines how annual targets break down to quarters and months. When admin creates quotas from a template, the system should generate records at ALL granularity levels:

- 1 Annual Quota\_\_c
- 4 Quarterly Quota\_\_c (or 2 semi-annual, depending on config)
- 12 Monthly Quota\_\_c (if expanded layout is selected)

This means we need to add a field to Quota\_\_c:

| #   | Field API Name    | Type         | Label        | Notes                                                                                                        |
| --- | ----------------- | ------------ | ------------ | ------------------------------------------------------------------------------------------------------------ |
| 18  | `Granularity__c`  | Picklist     | Granularity  | Monthly, Quarterly, Semi_Annual, Annual. Distinguishes rollup level.                                         |
| 19  | `Parent_Quota__c` | Lookup(self) | Parent Quota | → Quota\_\_c. Monthly → points to Quarterly parent. Quarterly → points to Annual parent. Enables drill-down. |

And on Forecast_Configuration\_\_c, one more field:

| #   | Field API Name                | Type      | Label                 | Notes                                                                                                                       |
| --- | ----------------------------- | --------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| 21  | `Summary_Expanded_Periods__c` | Text(200) | Expanded Period Types | JSON: which period types to show as expanded columns in Layout C. Default: `["Monthly"]` (expand current quarter to months) |

### 5.5 What Happens When Commissions Module is Not Installed?

The Forecasting module must work independently. If no Quota\_\_c records exist:

- Attainment fields on Forecast_Participant\_\_c remain null
- Coverage ratio shows "Target not set" instead of a number
- Inline Estimator columns are hidden (no plan data to calculate against)
- Governance rules CG-1 through CG-4 (comp-aware) are disabled — only non-comp governance rules fire
- Forecast Summary shows Committed/Best Case/Pipeline but not Target/Achieved/Attainment

This ensures the Forecasting module is fully functional standalone, with the Incentive module as an enrichment layer — not a dependency.

---

## 6. ~~ENTITY RELATIONSHIP DIAGRAM — FORECASTING MODULE~~ → SUPERSEDED BY §11

```
Forecast_Configuration__c (custom object)
  ├── Forecast_Metric__c           (N — metric definitions, child)
  ├── Forecast_Category__c         (N — category definitions, child)
  └── Forecast_Period__c           (N — one per time period)
        ├── Forecast_Participant__c (N — one per user per scope + summary records)
        │     ├── Forecast_Override__c (N — one per pipeline record per level)
        │     │     └── Forecast_Comment__c (N — threaded discussion)
        │     ├── ── cached ──► Quota__c (read-only, from Incentives module)
        │     └── ── cached ──► Comp_Plan__c (read-only, from Incentives module)
        └── (linked via Forecast_Participant__c.Reports_To__c = hierarchy chain)

Hierarchy_Source__mdt              (1 — singleton config: where hierarchy comes from)
Field_Mapping__mdt                 (N — CRM field mappings)

Cross-Module (read-only from Forecasting's perspective):
  Quota__c                         — target + achieved for attainment context
  Comp_Plan__c                     — plan assignment for rate tier context
  Commission_Tier__c               — rate bands for inline estimator
  Governance_Event__c              — governance flags shown in Cockpit queue

External (Salesforce standard):
  User                             — linked via Forecast_Participant__c.User__c
  UserRole                         — read by hierarchy sync if source = RoleHierarchy
  Territory2                       — read by hierarchy sync if source = TerritoryManagement
  Opportunity                      — pipeline records read via Field_Mapping__mdt
```

---

## 7. ~~OBJECT COUNT — FORECASTING MODULE~~ → SUPERSEDED BY §10

| Type                           | Count                         | Objects                                                                                |
| ------------------------------ | ----------------------------- | -------------------------------------------------------------------------------------- |
| Custom Objects — Config        | 3                             | Forecast_Configuration**c, Forecast_Metric**c, Forecast_Category\_\_c                  |
| Custom Objects — Runtime       | 4                             | Forecast_Period**c, Forecast_Participant**c, Forecast_Override**c, Forecast_Comment**c |
| Custom Metadata Types          | 2                             | Hierarchy_Source**mdt, Field_Mapping**mdt                                              |
| **Forecasting Module Total**   | **7 custom objects + 2 CMTs** |                                                                                        |
| Cross-Module reads (not owned) | 3                             | Quota**c, Comp_Plan**c, Commission_Tier\_\_c                                           |

---

## 8. STARTER TEMPLATE — DEFAULT VALUES

When the Setup Wizard runs for the first time, it creates these default records (Layer 1 configuration per §11.7):

**Forecast_Configuration\_\_c:**
| Field | Default Value |
|---|---|
| Name | "Standard Quarterly Forecast" |
| Hierarchy_Levels | (auto-detected from org) |
| Period_Type | Quarterly |
| FY Start Month | (auto-detected from org) |
| Future Periods Visible | 4 |
| Lock Past Periods | true |
| Top Level Lock Label | "Freeze" |
| Pipeline Object | "Opportunity" |
| Currency Mode | (auto-detected: Single or MultiWithDatedRates) |
| Budget Mode Enabled | true |

**Forecast_Metric\_\_c (2 records):**
| Metric | Label | Source Field | Primary? | Order |
|---|---|---|---|---|
| Metric 1 | "Amount" | Opportunity.Amount | Yes | 1 |
| Metric 2 | "Expected Revenue" | Opportunity.ExpectedRevenue | No | 2 |

**Forecast_Category\_\_c (5 records):**
| Category | Color | Counts Toward Target | Terminal | High Confidence | Sort |
|---|---|---|---|---|---|
| Commit | #27AE60 (green) | Yes | No | Yes | 1 |
| Best Case | #2980B9 (blue) | Yes | No | No | 2 |
| Pipeline | #F39C12 (orange) | No | No | No | 3 |
| Closed Won | #1ABC9C (teal) | Yes | Yes | Yes | 4 |
| Lost | #E74C3C (red) | No | Yes | No | 5 |

Admin can immediately use this default or modify via the Configuration record page.

---

---

## 9. HARDENING PASS — FEEDBACK FIXES

**Score: 8.6/10 → targeting 9.5/10.** This section addresses all 7 critical items + 3 minor items from the architecture review. Sections below **supersede** the corresponding §3.x definitions where conflicts exist.

### 9.1 Fix #1 + #7: Three-Layer Runtime Model (Override Cardinality Fix)

**Problem:** The V1.2 model uses Forecast_Override\_\_c as current state, audit log, trend history, behavioral telemetry, and rollup source. At scale (12K opps × 4 levels × 4 periods = 192K records/quarter), this becomes the hottest table and semantically overloaded.

**Solution:** Three distinct runtime layers.

#### Layer 1: Forecast_Override\_\_c — Current Authored State Only

**Persist a row ONLY when a participant explicitly authors or a system action requires it:**

| Creates a row                                                  | Does NOT create a row                                                                |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Participant edits category, metric value, close date, or notes | Manager can merely _see_ a deal in their scope (visibility is computed at read time) |
| Participant submits (submission state persisted)               | Deal inherited from lower level with no changes                                      |
| Period freezes (frozen state persisted)                        | Rollup/summary numbers (those live in Snapshot)                                      |
| Governance rule flags the record (Pending_Approval)            | Historical prior-version states (those live in Change Event)                         |

**Impact:** For an org with 12K opps, 4 levels, 4 periods — instead of ~192K override records per quarter, we expect ~15-30K (only deals actually touched by managers). 5-10× reduction.

**How manager visibility works without materialized rows:**

1. LWC loads the participant's scope definition from Forecast_Participant\_\_c
2. Single bulk SOQL query fetches all Opportunities matching the scope (via CRM abstraction layer + Field_Mapping\_\_mdt)
3. LEFT JOIN to Forecast_Override\_\_c for any existing overrides by this participant or levels below
4. Pipeline records without override rows display CRM values as read-only defaults
5. When manager edits any field → override row created on first edit (lazy materialization)

#### Layer 2: Forecast_Change_Event\_\_c — Immutable History Ledger (NEW OBJECT)

One row per meaningful change event. Append-only — never updated or deleted.

| #   | Field API Name               | Type                | Label                   | Notes                                                                                                                                                                                 |
| --- | ---------------------------- | ------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Forecast_Override__c`       | Lookup              | Forecast Override       | → Forecast_Override\_\_c (the override that changed)                                                                                                                                  |
| 2   | `Opportunity__c`             | Lookup              | Pipeline Record         | → Opportunity (denormalized for query performance)                                                                                                                                    |
| 3   | `Forecast_Period__c`         | Lookup              | Forecast Period         | → Forecast_Period\_\_c                                                                                                                                                                |
| 4   | `Participant__c`             | Lookup              | Participant             | → User                                                                                                                                                                                |
| 5   | `Hierarchy_Level__c`         | Number(2,0)         | Hierarchy Level         |                                                                                                                                                                                       |
| 6   | `Change_Type__c`             | Restricted Picklist | Change Type             | Values: Category_Change, Metric_Change, Close_Date_Change, Submit, Freeze, Unfreeze, Governance_Flag, Governance_Resolve, AI_Probability_Refresh, System_Auto_Set, **Scope_Transfer** |
| 7   | `Old_Category__c`            | Text(50)            | Old Category            |                                                                                                                                                                                       |
| 8   | `New_Category__c`            | Text(50)            | New Category            |                                                                                                                                                                                       |
| 9   | `Old_Close_Date__c`          | Date                | Old Close Date          |                                                                                                                                                                                       |
| 10  | `New_Close_Date__c`          | Date                | New Close Date          |                                                                                                                                                                                       |
| 11  | ~~`Old_Metric_1__c`~~        | ~~Number~~          | ~~Old Metric 1~~        | **SUPERSEDED by §12.1** → replaced by `Metric_Changes__c` JSON + `Primary_Metric_Old__c` / `Primary_Metric_New__c`                                                                    |
| 12  | ~~`New_Metric_1__c`~~        | ~~Number~~          | ~~New Metric 1~~        | **SUPERSEDED by §12.1**                                                                                                                                                               |
| 13  | ~~`Old_Metric_2__c`~~        | ~~Number~~          | ~~Old Metric 2~~        | **SUPERSEDED by §12.1**                                                                                                                                                               |
| 14  | ~~`New_Metric_2__c`~~        | ~~Number~~          | ~~New Metric 2~~        | **SUPERSEDED by §12.1**                                                                                                                                                               |
| 15  | `Changed_By__c`              | Lookup              | Changed By              | → User                                                                                                                                                                                |
| 16  | `Changed_On__c`              | DateTime            | Changed On              |                                                                                                                                                                                       |
| 17  | `Days_To_Period_End__c`      | Number(4,0)         | Days to Period End      | Auto-computed at write time. Critical for behavioral analysis ("change happened 3 days before quarter end")                                                                           |
| 18  | `Crossed_Period_Boundary__c` | Checkbox            | Crossed Period Boundary | True if close date moved across a period boundary                                                                                                                                     |
| 19  | `Is_Negative_Movement__c`    | Checkbox            | Negative Movement       | True if category regression, metric decrease, or close date push-out                                                                                                                  |
| 20  | `Change_Context__c`          | LongTextArea(2000)  | Change Context          | JSON: governance rule ID if governance-triggered, AI model version if AI-triggered, etc.                                                                                              |

**What this enables that Override alone cannot:**

- "Which deals were pushed in the last week of the quarter?" → `Change_Type__c = 'Close_Date_Change' AND Crossed_Period_Boundary__c = true AND Days_To_Period_End__c <= 7`
- "How often does Rep X downgrade from Commit?" → `Change_Type__c = 'Category_Change' AND Old_Category__c = 'Commit' AND Is_Negative_Movement__c = true`
- "What changed since my last review?" → `Changed_On__c > {lastReviewDate} AND Participant__c IN {myTeam}`
- Full undo/replay capability for debugging

**Write trigger:** Created automatically by a before-save trigger on Forecast_Override\_\_c that compares old vs. new values. Zero additional effort for the LWC — the UI just saves overrides normally.

#### Layer 3: Forecast_Snapshot\_\_c — Point-in-Time Aggregates (NEW OBJECT)

Precomputed rollups taken at regular intervals. This is the **read model** that the UI consumes for summaries, trends, and dashboards.

| #   | Field API Name                        | Type        | Label            | Notes                                                      |
| --- | ------------------------------------- | ----------- | ---------------- | ---------------------------------------------------------- |
| 1   | `Forecast_Period__c`                  | Lookup      | Forecast Period  | → Forecast_Period\_\_c                                     |
| 2   | `Forecast_Participant__c`             | Lookup      | Participant      | → Forecast_Participant\_\_c                                |
| 3   | `Snapshot_Date__c`                    | Date        | Snapshot Date    | When this snapshot was taken                               |
| 4   | `Snapshot_Type__c`                    | Picklist    | Snapshot Type    | Values: Nightly, Submit, Freeze, Weekly, Manual            |
| 5   | `Scope_Id__c`                         | Text(50)    | Scope ID         | Denormalized for scope-level queries                       |
| —   | **Category Totals (primary metric)**  |             |                  |                                                            |
| 6   | `Commit_Total__c`                     | Currency    | Commit Total     | Sum of Metric_1 where category = high-confidence committed |
| 7   | `Best_Case_Total__c`                  | Currency    | Best Case Total  |                                                            |
| 8   | `Pipeline_Total__c`                   | Currency    | Pipeline Total   |                                                            |
| 9   | `Closed_Won_Total__c`                 | Currency    | Closed Won Total |                                                            |
| 10  | `Lost_Total__c`                       | Currency    | Lost Total       |                                                            |
| —   | **Counts**                            |             |                  |                                                            |
| 11  | `Commit_Count__c`                     | Number(5,0) | Commit Count     | Number of records in each category                         |
| 12  | `Best_Case_Count__c`                  | Number(5,0) | Best Case Count  |                                                            |
| 13  | `Pipeline_Count__c`                   | Number(5,0) | Pipeline Count   |                                                            |
| 14  | `Total_Records__c`                    | Number(5,0) | Total Records    |                                                            |
| —   | **Derived Metrics**                   |             |                  |                                                            |
| 15  | `Coverage_Ratio__c`                   | Number(5,2) | Coverage Ratio   | Pipeline ÷ Remaining quota                                 |
| 16  | `Attainment_At_Snapshot__c`           | Percent     | Attainment %     | From Quota\_\_c at snapshot time                           |
| 17  | `Target_At_Snapshot__c`               | Currency    | Target           | From Quota\_\_c at snapshot time                           |
| 18  | `Achieved_At_Snapshot__c`             | Currency    | Achieved         | From Quota\_\_c at snapshot time                           |
| —   | **Trend Deltas (vs. prior snapshot)** |             |                  |                                                            |
| 19  | `Commit_Delta__c`                     | Currency    | Commit Change    | vs. previous snapshot of same type                         |
| 20  | `Pipeline_Delta__c`                   | Currency    | Pipeline Change  |                                                            |
| 21  | `Coverage_Delta__c`                   | Number(5,2) | Coverage Change  |                                                            |
| 22  | `Records_Added__c`                    | Number(5,0) | Records Added    | New pipeline records since prior snapshot                  |
| 23  | `Records_Removed__c`                  | Number(5,0) | Records Removed  | Deals that left scope since prior snapshot                 |

**When snapshots are taken:**

| Trigger                   | Snapshot_Type | Frequency                                                                          |
| ------------------------- | ------------- | ---------------------------------------------------------------------------------- |
| Scheduled nightly job     | Nightly       | Every night at configurable time                                                   |
| Participant clicks Submit | Submit        | On each submission                                                                 |
| Top-level freeze          | Freeze        | Once per period per scope                                                          |
| Scheduled weekly job      | Weekly        | Every Monday (configurable)                                                        |
| Final week of period      | Nightly       | Increases to hourly snapshots in final N days (configurable, default: last 3 days) |
| Admin manual trigger      | Manual        | On demand                                                                          |

**How the UI uses snapshots:**

- **Forecast Summary panel:** Reads the latest Nightly snapshot for current totals (not re-derived from overrides)
- **Trend lines ("commit eroded $500K this week"):** Compares Weekly snapshots
- **Submit comparison ("what changed since last submit"):** Compares current Nightly to last Submit snapshot
- **Quarter-over-quarter trends:** Compares Freeze snapshots across periods

#### 3-Layer Summary

```
WRITE PATH (user actions):
  User edits override → Forecast_Override__c (current state)
                       → Forecast_Change_Event__c (immutable history, auto-created by trigger)

READ PATH (UI consumption):
  Forecast Summary panel → Forecast_Snapshot__c (precomputed, fast)
  Pipeline grid → Forecast_Override__c + live CRM query (hybrid)
  Trend charts → Forecast_Snapshot__c (series of snapshots over time)
  Behavior analytics → Forecast_Change_Event__c (pattern detection)
  Governance rules → Forecast_Override__c (current state for real-time eval)
```

---

### 9.2 Fix #2: Forecast_Participant Structural vs. Period-State Boundaries

**Problem:** Forecast_Participant\_\_c mixes identity (user, scope, hierarchy, sync provenance) with period-specific state (submission status, timestamps, quota cache). Every new period copies all structural data unnecessarily.

**Solution for V1:** Keep one object but explicitly mark field ownership. A future V2 can split to Forecast_Assignment**c + Forecast_Participant**c if scale demands.

**Forecast_Participant\_\_c field ownership categories:**

| Category                    | Fields                                                                                                                                                                                                    | Copied per period?                                            | Source              |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------- |
| **Structural (identity)**   | User**c, Hierarchy_Level**c, Level_Label**c, Scope_Id**c, Scope_Name**c, Scope_Parent_Id**c, Region**c, Sub_Region**c, Reports_To**c, Local_Currency**c, Hierarchy_Source_Id**c, Hierarchy_Source_Type**c | Yes — but only from sync job, not editable by period workflow | Hierarchy sync job  |
| **Period State (workflow)** | Forecast_Period**c, Submission_Status**c, Saved_On**c, Submitted_On**c, Frozen_On\_\_c                                                                                                                    | Unique per period                                             | Forecast workflow   |
| **Delegation**              | Delegate**c, Delegate_Start**c, Delegate_End\_\_c                                                                                                                                                         | Copied from structural if active                              | Admin config        |
| **Cache (cross-module)**    | Quota_Target**c, Quota_Achieved**c, Attainment_Pct**c, Current_Rate_Tier**c, Current_Rate_Pct**c, Next_Tier_Name**c, Next_Tier_Distance**c, Quota_Id**c, Comp_Plan_Id**c, Attainment_Last_Synced**c       | Unique per period — re-derived from Quota\_\_c                | Attainment sync job |
| **Summary (DP-4)**          | Is_Summary**c, Summary_Source_Ids**c                                                                                                                                                                      | Derived per period                                            | Auto-generated      |
| **Notifications**           | Email_Recipients\_\_c                                                                                                                                                                                     | Copied from structural                                        | Admin override      |

**Period generation rule:** When a new Forecast_Period\_\_c is created, the period generation batch:

1. Reads the latest Forecast_Participant\_\_c records from the most recent period (or from the sync source if no prior period)
2. Creates new Forecast_Participant\_\_c records for the new period
3. Copies ONLY structural fields from source
4. Period-state fields initialized to defaults (Submission_Status = Not Started)
5. Cache fields left null — populated on first access or by attainment sync job

**Explicit invariant:** Period workflow code NEVER modifies structural fields. Hierarchy sync code NEVER modifies period-state fields. Violation is a bug.

---

### 9.3 Fix #3: Category Sync Service

**Problem:** Restricted picklist values on Forecast_Override**c.Forecast_Category**c must stay in sync with Forecast_Category\_\_c records. A half-failed sync creates orphans.

**Solution:** A `CategorySyncService` Apex class with explicit lifecycle rules.

**Category Lifecycle:**

```
ADDING A CATEGORY:
  1. Admin creates Forecast_Category__c record (standard UI)
  2. Before-insert trigger calls CategorySyncService.addPicklistValue()
     → Uses Metadata API (async) to add the restricted picklist value
     → Sets Forecast_Category__c.Sync_Status__c = 'Pending'
  3. Metadata deploy callback updates Sync_Status__c = 'Active'
  4. If metadata deploy fails → Sync_Status__c = 'Failed', error logged
     → Category record exists but picklist value doesn't
     → Category is NOT usable until sync succeeds
     → Admin sees "Sync Failed — Retry" button

RENAMING A CATEGORY:
  1. Admin edits Category_Label__c on Forecast_Category__c
  2. Before-update trigger calls CategorySyncService.renamePicklistValue()
  3. Picklist label updated via Metadata API (API name unchanged — label only)
  4. Historical overrides unaffected (they store API name, not label)

DEACTIVATING A CATEGORY:
  1. Admin sets Is_Active__c = false on Forecast_Category__c
  2. Picklist value is NOT removed (historical data references it)
  3. UI hides inactive categories from the dropdown
  4. Validation rule prevents new overrides from using inactive categories
  5. Existing overrides with the inactive category are NOT modified (historical accuracy)

DELETING A CATEGORY:
  1. BLOCKED if any Forecast_Override__c record references this category
  2. Admin must first reassign all overrides to a different category
  3. Only then can the record be deleted + picklist value removed
```

**New field on Forecast_Category\_\_c:**

| #   | Field API Name         | Type                             | Label             | Notes                                                                                                                                                                                                    |
| --- | ---------------------- | -------------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 12  | `Sync_Status__c`       | Picklist                         | Sync Status       | Pending, Active, Failed                                                                                                                                                                                  |
| 13  | `Is_Active__c`         | Checkbox                         | Active            | Default true. False = hidden from UI, not deletable                                                                                                                                                      |
| —   | `Category_API_Name__c` | _(existing field #3 — see §3.3)_ | Category API Name | **Now immutable after creation.** This is what gets stored on Forecast_Override\_\_c and in the restricted picklist. Label can change, API name cannot. Not a new field — immutability constraint added. |

**Post-deploy verification:** A scheduled daily job (`CategorySyncVerifier`) checks:

- Every active Forecast_Category\_\_c record has a matching picklist value → fix if missing
- Every picklist value has a matching Forecast_Category\_\_c record → create stub record if orphaned
- Results logged; admin alerted on mismatch

---

### 9.4 Fix #4: Metric Slot Immutability Rules

**Problem:** If an admin changes "Metric 1" from "Amount" to "ARR" after override data exists, historical data becomes semantically corrupted.

**Explicit invariants on Forecast_Metric\_\_c:**

| Rule                                                                                                                  | Enforcement                                                                                                                                                            | When                                                              |
| --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `Metric_API_Name__c` → slot binding is **immutable** after first Forecast_Override\_\_c record exists for this config | Validation rule on Forecast_Metric\_\_c before-update                                                                                                                  | Always                                                            |
| `Metric_Label__c` CAN change                                                                                          | No restriction                                                                                                                                                         | Labels are display-only                                           |
| `Display_Format__c` CAN change                                                                                        | No restriction                                                                                                                                                         | Formatting is display-only                                        |
| `Source_Field__c` CAN change **with warning**                                                                         | Before-update trigger shows warning: "Changing source field will affect how future overrides are populated from CRM. Historical overrides retain their stored values." | Only if override data exists                                      |
| `Metric_Type__c` (Currency/Number/Percentage) **CANNOT change** if data exists                                        | Validation rule blocks                                                                                                                                                 | Prevents type mismatch with stored Number fields                  |
| `Is_Primary__c` CAN change (re-designating which metric is primary)                                                   | Allowed but logged as Forecast_Change_Event\_\_c                                                                                                                       | Affects coverage ratio and attainment calculations going forward  |
| Slot deletion BLOCKED if data exists                                                                                  | Before-delete trigger                                                                                                                                                  | Admin must create new Forecast_Configuration\_\_c version instead |

**Admin-facing message on attempted slot change:**

> "This metric has been used in {N} forecast overrides across {M} periods. The metric name and slot binding cannot be changed. To use a different metric, add it as a new slot (Metric 3-6) or create a new Forecast Configuration version."

---

### 9.5 Fix #5: Clean All CMT/Custom Object Ambiguity

**Final, locked layer assignments — no hedging:**

| Layer                                                                        | Type                 | Objects                                                                                                                                            |
| ---------------------------------------------------------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Platform wiring** (set once, rarely changes, package-deployable)           | Custom Metadata Type | `Hierarchy_Source__mdt`, `Field_Mapping__mdt`                                                                                                      |
| **Business configuration** (customer-owned, admin-managed, wizard-created)   | Custom Object        | `Forecast_Configuration__c`, `Forecast_Metric__c`, `Forecast_Category__c`                                                                          |
| **Runtime data** (created by users and system during forecasting operations) | Custom Object        | `Forecast_Period__c`, `Forecast_Participant__c`, `Forecast_Override__c`, `Forecast_Comment__c`, `Forecast_Change_Event__c`, `Forecast_Snapshot__c` |

**Residual fix:** Forecast_Period**c field #1 (`Forecast_Config**c`) is now a proper **Lookup → Forecast_Configuration\_\_c**. The old inline note about CMT developer name reference is removed.

---

### 9.6 Fix #6: Hierarchy Sync Survivorship + Mid-Period Transfer Policy

**Explicit sync policy by period status:**

| Period Status                 | Sync Behavior                                                                                                                                                         | Rationale                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **Scheduled** (future)        | **Full re-sync.** Delete and recreate all Forecast_Participant\_\_c for this period from current hierarchy source. No user data at risk.                              | Future periods should always reflect current org structure.                             |
| **Open** (active forecasting) | **Additive + controlled reassignment.** New participants added. Existing participants updated for structural field changes. Removed participants flagged (see below). | Active forecasting data exists — can't silently delete participants who have overrides. |
| **Prelock / Frozen / Closed** | **Immutable.** Zero sync changes. The participant snapshot at freeze time is the historical truth.                                                                    | Changing frozen hierarchy would corrupt historical forecast accuracy data.              |

**Mid-period structural change handling (Open periods):**

| Scenario                            | Behavior                                                                                                                                                                                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Rep changes manager**             | Rep's Forecast_Participant**c.Reports_To**c updated to new manager's participant record. Rep's existing overrides stay with them (they authored them). New manager sees them in their scope. Old manager no longer sees them.                                  |
| **Rep moves to new territory**      | New Forecast_Participant**c created for new scope. Old participant record flagged `Scope_Transfer**c = true`, `Transfer_Date\_\_c = today`. Old overrides remain under old participant record (historical accuracy). Manager sees "transferred out" indicator. |
| **Rep becomes inactive**            | Forecast_Participant**c.Is_Active**c set to false. Overrides preserved. Manager sees "(inactive)" badge. Participant excluded from rollups for future submissions but included in historical snapshots.                                                        |
| **Role renamed**                    | Level_Label\_\_c updated. No data impact.                                                                                                                                                                                                                      |
| **Territory model swap**            | Treated as full re-sync for Scheduled periods. Open periods: admin prompted to confirm scope reassignment for affected participants.                                                                                                                           |
| **Circular manager chain detected** | Sync job logs error in `Hierarchy_Sync_Log__c`. Affected branch excluded from sync. Admin notified: "Circular reporting chain detected: User A → User B → User A. Please fix in source hierarchy."                                                             |
| **User gets second territory**      | New Forecast_Participant\_\_c created for second scope. Summary participant (Is_Summary = true) auto-created/updated if not exists.                                                                                                                            |

**New objects for sync health:**

**Hierarchy_Sync_Log\_\_c (Sync Log — NEW)**

| #   | Field API Name                | Type               | Label          | Notes                                    |
| --- | ----------------------------- | ------------------ | -------------- | ---------------------------------------- |
| 1   | `Sync_Date__c`                | DateTime           | Sync Date      |                                          |
| 2   | `Source_Type__c`              | Text(30)           | Source Type    | RoleHierarchy, TerritoryManagement, etc. |
| 3   | `Periods_Synced__c`           | Number(3,0)        | Periods Synced | How many periods were updated            |
| 4   | `Participants_Created__c`     | Number(5,0)        | Created        |                                          |
| 5   | `Participants_Updated__c`     | Number(5,0)        | Updated        |                                          |
| 6   | `Participants_Deactivated__c` | Number(5,0)        | Deactivated    |                                          |
| 7   | `Errors__c`                   | LongTextArea(5000) | Errors         | Circular chains, missing managers, etc.  |
| 8   | `Status__c`                   | Picklist           | Status         | Success, Partial, Failed                 |

**New fields on Forecast_Participant\_\_c:**

| #   | Field API Name           | Type     | Label             | Notes                                                         |
| --- | ------------------------ | -------- | ----------------- | ------------------------------------------------------------- |
| 35  | `Is_Active__c`           | Checkbox | Active            | False if user deactivated mid-period                          |
| 36  | `Scope_Transfer__c`      | Checkbox | Scope Transferred | True if participant was moved to a different scope mid-period |
| 37  | `Transfer_Date__c`       | Date     | Transfer Date     |                                                               |
| 38  | `Transfer_From_Scope__c` | Text(50) | Transferred From  | Previous scope ID for audit                                   |

---

### 9.7 Minor Fix: Comment Threading

**Added to Forecast_Comment\_\_c:**

| #   | Field API Name      | Type         | Label          | Notes                                                                                                                 |
| --- | ------------------- | ------------ | -------------- | --------------------------------------------------------------------------------------------------------------------- |
| 10  | `Parent_Comment__c` | Lookup(self) | Parent Comment | → Forecast_Comment\_\_c. Null = top-level comment. Non-null = reply to parent. Enables threaded discussions per deal. |

---

### 9.8 Minor Fix: Pagination Spec

**How forecast grid pagination works:**

- Default page size: `Forecast_Configuration__c.Pagination_Size__c` (default 40)
- Pagination method: **Keyset pagination** (not OFFSET) — uses `Forecast_Override__c.Id` or `Opportunity.Id` as cursor
- Sort: Client-side sorting within loaded page. Server sort on initial load by configurable default (e.g., Metric_1 descending)
- "Load More" button (not page numbers) — progressive loading for better UX
- Total count shown: "Showing 1-40 of 287 records"
- Filters applied server-side before pagination (reduces total set)

---

### 9.9 Minor Fix: Related Documents

| Section Reference                                                       | Document                              |
| ----------------------------------------------------------------------- | ------------------------------------- |
| §1.5.2 (CRM conflict resolution)                                        | UNIFIED_PLATFORM_SPEC.md V5.0, §1.5.2 |
| §1.6.1 (Module isolation rules)                                         | UNIFIED_PLATFORM_SPEC.md V5.0, §1.6   |
| §7.3.6 (Governance runtime semantics)                                   | UNIFIED_PLATFORM_SPEC.md V5.0, §7.3.6 |
| §9.2.1 (AI Trust Tiers)                                                 | UNIFIED_PLATFORM_SPEC.md V5.0, §9.2   |
| §11.7 (Configuration Layering)                                          | UNIFIED_PLATFORM_SPEC.md V5.0, §11.7  |
| §14.4 (Managed Package Constraints)                                     | UNIFIED_PLATFORM_SPEC.md V5.0, §14.4  |
| Incentive module objects (Quota**c, Comp_Plan**c, Commission_Tier\_\_c) | REVENUETRUST_OBJECT_MODEL.md V1.1     |

---

## 10. FINAL OBJECT COUNT — FORECASTING MODULE

| Type                           | Count                          | Objects                                                                                                                                                        |
| ------------------------------ | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Config objects**             | 3                              | Forecast_Configuration**c, Forecast_Metric**c, Forecast_Category\_\_c                                                                                          |
| **Runtime objects**            | 6                              | Forecast_Period**c, Forecast_Participant**c, Forecast_Override**c, Forecast_Comment**c, **Forecast_Change_Event\_\_c** (NEW), **Forecast_Snapshot\_\_c** (NEW) |
| **Operational objects**        | 1                              | **Hierarchy_Sync_Log\_\_c** (NEW)                                                                                                                              |
| **Custom Metadata Types**      | 2                              | Hierarchy_Source**mdt, Field_Mapping**mdt                                                                                                                      |
| **Forecasting Module Total**   | **10 custom objects + 2 CMTs** |                                                                                                                                                                |
| Cross-Module reads (not owned) | 3                              | Quota**c, Comp_Plan**c, Commission_Tier\_\_c                                                                                                                   |

**Net change from V1.2:** +3 objects (Forecast_Change_Event**c, Forecast_Snapshot**c, Hierarchy_Sync_Log\_\_c)

---

## 11. FINAL ENTITY RELATIONSHIP DIAGRAM

```
Forecast_Configuration__c
  ├── Forecast_Metric__c             (N — metric definitions, child)
  ├── Forecast_Category__c           (N — category definitions, child. Sync_Status tracks picklist alignment)
  └── Forecast_Period__c             (N — one per time period. Proper Lookup to config.)
        ├── Forecast_Participant__c   (N — one per user per scope + summary records)
        │     ├── Forecast_Override__c (N — ONLY authored/frozen/flagged rows. Lazy materialization.)
        │     │     ├── Forecast_Comment__c    (N — threaded: Parent_Comment__c self-lookup)
        │     │     └── Forecast_Change_Event__c (N — immutable history, auto-created by trigger)
        │     └── Forecast_Snapshot__c (N — periodic aggregates: nightly/submit/freeze/weekly)
        │
        │  ── cached from Incentives module (read-only) ──
        │     Quota__c, Comp_Plan__c, Commission_Tier__c
        │
        └── (hierarchy chain via Forecast_Participant__c.Reports_To__c)

Hierarchy_Source__mdt              (singleton — hierarchy source config)
Field_Mapping__mdt                 (N — CRM field mapping abstraction)
Hierarchy_Sync_Log__c              (N — sync job audit trail)

WRITE PATH:    User action → Override → Change Event (auto)
READ PATH:     Summary panel → Snapshot (precomputed)
               Pipeline grid → Override + live CRM query (hybrid)
               Trend charts → Snapshot series
               Behavior intel → Change Event patterns
               Governance → Override current state (real-time)
```

---

---

## 12. V1.4 TIGHTENING PASS — REMAINING ISSUES

### 12.1 Change Event: Metric 3–6 Gap

**Problem:** `Forecast_Change_Event__c` only has Old/New fields for Metric 1 and Metric 2. Changes to Metrics 3–6 are silently lost.

**Fix:** Replace individual metric old/new fields with a JSON payload. The event object is an audit/history layer, not the main reporting surface — JSON is appropriate here. **This replacement supersedes fields 11–14 listed in §9.1.**

**Changes to Forecast_Change_Event\_\_c:**

- **Remove:** `Old_Metric_1__c`, `New_Metric_1__c`, `Old_Metric_2__c`, `New_Metric_2__c` (fields 11-14)
- **Replace with:**

| #   | Field API Name          | Type               | Label              | Notes                                                                                                                                            |
| --- | ----------------------- | ------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 11  | `Metric_Changes__c`     | LongTextArea(5000) | Metric Changes     | JSON: `{"metric_1": {"old": 400000, "new": 350000}, "metric_3": {"old": 12, "new": 15}}`. Only changed slots included — unchanged slots omitted. |
| 12  | `Primary_Metric_Old__c` | Number(18,2)       | Primary Metric Old | Denormalized for fast query on primary metric changes without JSON parsing.                                                                      |
| 13  | `Primary_Metric_New__c` | Number(18,2)       | Primary Metric New |                                                                                                                                                  |

**Rationale:** Keep denormalized old/new for the primary metric only (most queries filter on primary metric changes). All 6 slots tracked in JSON for full audit coverage.

---

### 12.2 Snapshot: Secondary Metrics + Category Reserve Slots

**Problem 1:** Snapshot category totals are hardcoded to 5 named fields. Orgs adding "Upside" or "Stretch" as a 6th+ category have no snapshot field.

**Problem 2:** Snapshot only stores primary metric totals. No trend lines possible for secondary metrics like ARR or Units.

**Fix — Categories:** Add 3 reserve category slots + a JSON overflow field.

**Additional fields on Forecast_Snapshot\_\_c:**

| #   | Field API Name         | Type               | Label                 | Notes                                                                                                                                            |
| --- | ---------------------- | ------------------ | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 24  | `Category_6_Total__c`  | Currency           | Category 6 Total      | Reserve slot                                                                                                                                     |
| 25  | `Category_6_Count__c`  | Number(5,0)        | Category 6 Count      |                                                                                                                                                  |
| 26  | `Category_7_Total__c`  | Currency           | Category 7 Total      | Reserve slot                                                                                                                                     |
| 27  | `Category_7_Count__c`  | Number(5,0)        | Category 7 Count      |                                                                                                                                                  |
| 28  | `Category_8_Total__c`  | Currency           | Category 8 Total      | Reserve slot                                                                                                                                     |
| 29  | `Category_8_Count__c`  | Number(5,0)        | Category 8 Count      |                                                                                                                                                  |
| 30  | `Category_Slot_Map__c` | LongTextArea(1000) | Category Slot Mapping | JSON: `{"commit": 1, "best_case": 2, "pipeline": 3, "closed_won": 4, "lost": 5, "upside": 6}`. Maps category API names to snapshot slot numbers. |

**Design decision (same trade-off as DP-2):** 8 fixed category slots (5 default + 3 reserve). Covers 99% of use cases. If an org needs 9+ categories, they have a configuration problem, not a platform limitation.

**Fix — Secondary Metrics:**

| #   | Field API Name     | Type               | Label                     | Notes                                                                                                                                                                      |
| --- | ------------------ | ------------------ | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 31  | `Metric_Totals__c` | LongTextArea(5000) | Metric Totals by Category | JSON: `{"metric_2": {"commit": 120000, "best_case": 280000, "pipeline": 450000}, "metric_3": {"commit": 14, "pipeline": 38}}`. All non-primary metric rollups by category. |

**Rationale:** Primary metric stays in named fields for fast reporting/dashboards. Secondary metrics in JSON for flexibility. The snapshot job computes both in the same pass — zero additional query cost.

---

### 12.3 Category Sync: Non-Active Exclusion Lock

**Explicit rule (strengthening §9.3):**

> Categories with `Sync_Status__c != 'Active'` OR `Is_Active__c = false` MUST be:
>
> 1. **Excluded from the override category dropdown** — the LWC picklist renderer filters them out at load time
> 2. **Excluded from governance rule evaluation** — governance engine skips rules that reference non-active categories
> 3. **Excluded from snapshot rollup calculations** — overrides with deactivated categories are not included in category totals (but are preserved for historical queries on past snapshots)
> 4. **Visible in reports only when explicitly filtered** — reports show a "Show Inactive Categories" toggle, default OFF

This was implied in §9.3 but is now locked as an explicit invariant.

---

### 12.4 Mid-Period Transfer: Rollup Truth Rule

**One-sentence truth rule for implementation:**

> **Current live views follow current scope ownership. Historical snapshots preserve original snapshot-time ownership. Change events record the transfer so analysis can explain the discontinuity.**

**Expanded:**

| View                                   | What it shows after Rep X transfers from Manager A → Manager B mid-period                                                                                      |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Manager B's live forecast view**     | All of Rep X's current deals (current live scope ownership)                                                                                                    |
| **Manager A's live forecast view**     | Rep X's deals are gone (no longer in scope)                                                                                                                    |
| **Manager A's past snapshots**         | Rep X's deals included at snapshot-time values (historical truth preserved)                                                                                    |
| **Manager B's past snapshots**         | Rep X NOT included in snapshots taken before transfer date                                                                                                     |
| **Forecast_Change_Event\_\_c**         | Transfer event recorded: `Change_Type__c = 'Scope_Transfer'`, old scope = Manager A, new scope = Manager B, transfer date                                      |
| **Forecast Summary panel (Manager B)** | Totals include Rep X's current deals. If summary shows "since period start", a footnote: "Includes transfers: Rep X joined scope on {date}"                    |
| **Manager accuracy (end of period)**   | Rep X's deals count toward Manager B's accuracy for the period (they submitted the final forecast). Manager A's accuracy unaffected by post-transfer outcomes. |

---

### 12.5 Write Frequency Guardrails

**Consolidated change events:**

> Multiple field changes in a single save (e.g., manager changes category AND metric value AND close date simultaneously) create **one** consolidated `Forecast_Change_Event__c` record, not three. The single record captures all changed fields in the same row.

**AI refresh rate limiting:**

> `Close_Probability__c` refreshes via AI are batched nightly. On-demand refresh (user opens deal detail) is rate-limited to once per deal per hour. Each AI refresh creates a change event with `Change_Type__c = 'AI_Probability_Refresh'` — these are excluded from behavioral pattern detection (they're system events, not user actions).

**Hourly snapshot configuration:**

> Hourly snapshot mode (final N days of period) is configurable per Forecast_Configuration\_\_c, not global:

| #   | Field API Name                | Type        | Label                | Notes                                                                                                               |
| --- | ----------------------------- | ----------- | -------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 22  | `Hourly_Snapshot_Days__c`     | Number(2,0) | Hourly Snapshot Days | Number of days before period end to activate hourly snapshots. Default: 3. Set to 0 to disable.                     |
| 23  | `Hourly_Snapshot_Interval__c` | Number(2,0) | Hourly Interval      | Hours between snapshots in final-days mode. Default: 4 (not truly hourly — 4-hour intervals during business hours). |

---

### 12.6 Operational Notes

**Field_Mapping\_\_mdt caching:**

> `Field_Mapping__mdt` is queried **once at LWC component initialization** and cached in the component's JavaScript state for the entire session. The cached mapping is used to construct dynamic SOQL for pipeline record queries. The pipeline grid issues a single bulk SOQL query per page load (not per row), with the dynamic field list assembled from the cached mapping. Typical query: `SELECT {mapped fields} FROM Opportunity WHERE OwnerId IN :scopeUserIds AND IsClosed = false`.

**Draft override exchange rates:**

> For overrides in **Saved (draft) status**, the LWC displays the **live exchange rate** (from DatedConversionRate or CurrencyType) in the grid. The stored `Exchange_Rate__c` on the override record is updated on each save. The rate is **frozen only on Submit** — at that point, the stored rate becomes the audit-locked rate. A nightly job refreshes `Exchange_Rate__c` on all non-submitted overrides to prevent stale-rate confusion in multi-currency orgs.

**Change Event retention policy:**

> `Forecast_Change_Event__c` records older than **3 completed fiscal years** are eligible for archival. Archival options:
>
> 1. **Big Object migration** (Salesforce Big Objects — queryable archive for long-term analytics)
> 2. **External storage export** (CSV/Parquet export to cloud storage before deletion)
> 3. **Deletion with summary preservation** (delete events but retain Forecast_Snapshot\_\_c records which capture the aggregate state)
>
> Retention period is configurable via `Forecast_Configuration__c.Event_Retention_Years__c` (Number, default: 3).

New field on Forecast_Configuration\_\_c:

| #   | Field API Name             | Type        | Label                   | Notes                                                                                            |
| --- | -------------------------- | ----------- | ----------------------- | ------------------------------------------------------------------------------------------------ |
| 24  | `Event_Retention_Years__c` | Number(2,0) | Event Retention (Years) | Change events older than this many completed fiscal years are eligible for archival. Default: 3. |

---

### 12.7 Participant Split Trigger (V2 Decision Point)

**When to split Forecast_Participant**c into Forecast_Assignment**c + Forecast_Participant\_\_c:**

> Evaluate the split if ANY of the following thresholds are reached:
>
> - `Forecast_Participant__c` exceeds **200K records per active period** (indicates high structural duplication)
> - Forecast grid page load latency exceeds **3 seconds** with warm cache (measured via LWC performance logging)
> - Hierarchy sync job exceeds **5 minutes** for open periods (indicates excessive record creation/update)
> - Customer reports confusion about "which fields changed because of org structure vs. which changed because of forecast workflow"
>
> Until these thresholds are hit, the current single-object model with explicit field ownership categories (§9.2) is sufficient.

---

### 12.8 Stale Section Cleanup

**§6 (prior ERD):** Superseded by §11. See §11 for the current entity relationship diagram including Forecast_Change_Event**c, Forecast_Snapshot**c, and Hierarchy_Sync_Log\_\_c.

**§7 (prior Object Count):** Superseded by §10. Current count: 10 custom objects + 2 CMTs.

---

### 12.9 Consolidated Field Count (for AppExchange Security Review)

| Object                      | Custom Fields | Notes                                                                                                                       |
| --------------------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Forecast_Configuration\_\_c | 24            | §3.1 (19) + §5.4.1 (1) + §5.4.3 (1) + §12.5 (2) + §12.6 (1)                                                                 |
| Forecast_Metric\_\_c        | 14            | §3.2                                                                                                                        |
| Forecast_Category\_\_c      | 13            | §3.3 (11) + §9.3 (2 new: Sync_Status, Is_Active). Immutability on Category_API_Name is a constraint, not a new field.       |
| Forecast_Period\_\_c        | 14            | §3.4                                                                                                                        |
| Forecast_Participant\_\_c   | 38            | §3.5 (22) + §DP-4 (2) + §5.3 (10) + §9.6 (4)                                                                                |
| Forecast_Override\_\_c      | 39            | §3.6                                                                                                                        |
| Forecast_Comment\_\_c       | 10            | §3.7 (9) + §9.7 (1: Parent_Comment)                                                                                         |
| Forecast_Change_Event\_\_c  | 19            | §9.1 (20 base) − §12.1 (4 removed: old/new metric 1-2) + §12.1 (3 added: Metric_Changes JSON + Primary_Metric_Old/New) = 19 |
| Forecast_Snapshot\_\_c      | 31            | §9.1 (23) + §12.2 (8: reserve category slots + metric JSON + slot map)                                                      |
| Hierarchy_Sync_Log\_\_c     | 8             | §9.6                                                                                                                        |
| Hierarchy_Source\_\_mdt     | 8             | §2.2                                                                                                                        |
| Field_Mapping\_\_mdt        | 6             | §3.8                                                                                                                        |
| **TOTAL**                   | **224**       | Well within Salesforce per-object limit (500). Reasonable for ISV security review.                                          |

---

_Forecasting Object Model V1.4 — Spec Frozen_  
_All feedback passes complete. All consistency issues resolved._  
_DP-1: Custom Object ✅ | DP-2: 6 Slots ✅ | DP-3: Restricted Picklist ✅ | DP-4: Summary Participant ✅ | DP-5: Owner-only V1 ✅_
