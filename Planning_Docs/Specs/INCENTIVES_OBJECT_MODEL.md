# RevenueTrust — Incentives Module Object Model

**Version:** 1.7 — Spec Frozen  
**Date:** April 2, 2026  
**Status:** SPEC FROZEN — ready for implementation  
**Companion:** FORECASTING_OBJECT_MODEL.md V1.4 (frozen)

---

## Design Philosophy

The KONY engine works — it has processed real commissions for 6+ years. But it was built for one SaaS company with hardcoded roles (AE, BDR, SE, CSM), hardcoded deal types (Subscription, Renewal, Services, Training), hardcoded period structure (Q1-Q4), and 112 fields mixing plan design with per-rep state.

RevenueTrust must handle:

- A SaaS startup with 5 AEs and a simple flat-rate plan
- An insurance company with 500 agents across 4 tiers and monthly residuals
- A manufacturing firm with territory-based team pools and margin-based commissions
- A financial services firm with AUM-based trail commissions and compliance holds

Same engine, different configuration.

---

## 1. ONBOARDING WIZARD — INCENTIVES MODULE

### 1.1 Discovery (Automated)

| Discovery Check                 | What We Learn                                                                                          |
| ------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Existing commission objects** | Does the org already have Comp_Plan**c, Commission**c, or similar custom objects? (migration scenario) |
| **Opportunity Record Types**    | What deal categories exist? (New Business, Renewal, Services, etc.)                                    |
| **Opportunity Products**        | Are OpportunityLineItems used? (needed for product-specific rates)                                     |
| **Sales Roles**                 | What User.Profile / User.Role values exist? (informs role-based plan templates)                        |
| **Currency**                    | Multi-currency? Dated Exchange Rates? (inherited from Forecasting discovery if already run)            |
| **Fiscal Year**                 | FY start month, period structure (inherited from Forecasting if configured)                            |
| **Existing Splits**             | Is OpportunitySplit / OpportunityTeamMember used? (future split support)                               |
| **Payroll cadence**             | Not discoverable — asked in questionnaire                                                              |

### 1.2 Admin Questionnaire

**Question 1: Industry**

> What industry best describes your business? This helps us recommend plan templates.
>
> - [ ] SaaS / Software (subscription-based)
> - [ ] Insurance (policy/premium-based)
> - [ ] Financial Services (AUM/fee-based)
> - [ ] Real Estate (transaction-based)
> - [ ] Manufacturing / Industrial (project/bid-based)
> - [ ] Telecommunications (recurring + activation)
> - [ ] Healthcare IT (contract-based)
> - [ ] Retail / Consumer Goods (volume-based)
> - [ ] Other / Custom

**Question 2: Primary Commission Trigger**

> When does a rep earn commission?
>
> - [ ] **On booking** — when the deal closes (most common in SaaS, Real Estate)
> - [ ] **On collection** — when payment is received (common in Insurance, Financial Services)
> - [ ] **On milestone** — when project milestones are achieved (Manufacturing, Healthcare IT)
> - [ ] **On revenue recognition** — when revenue is recognized per accounting rules (multi-year SaaS, Telecom)
> - [ ] **On renewal date** — when a subscription renews (Telecom, SaaS retention plans)
> - [ ] **Multiple** — different triggers for different plan types

**Question 3: Rate Structure**

> How are commission rates determined?
>
> - [ ] **Flat rate** — same % on every deal (simplest; common in startups, real estate)
> - [ ] **Tiered / Accelerated** — rate increases after hitting quota thresholds (most common in enterprise SaaS)
> - [ ] **Gross margin** — % of profit margin, not revenue (Manufacturing, Services)
> - [ ] **Recurring / Trail** — ongoing % as long as customer remains active (Insurance, Financial Services)
> - [ ] **Activity-based** — commission on activities like demos, meetings (BDR plans)
> - [ ] **Multiple** — different structures for different roles/plans

**Question 4: Compensation Roles**

> Which roles in your organization earn variable compensation? (Select all that apply)
>
> For each role, provide: Role Name | Typical OTE | Variable % of OTE | Primary plan type
>
> Starter suggestions based on industry:
>
> | Industry           | Suggested Roles                                                                         |
> | ------------------ | --------------------------------------------------------------------------------------- |
> | SaaS               | Account Executive, BDR/SDR, Solutions Engineer, Customer Success Manager, Sales Manager |
> | Insurance          | Agent, Broker, Underwriter, Agency Manager                                              |
> | Financial Services | Financial Advisor, Wealth Manager, Relationship Manager                                 |
> | Real Estate        | Agent, Broker, Team Lead                                                                |
> | Manufacturing      | Sales Engineer, Territory Manager, Channel Manager                                      |

**Question 5: Attainment Period**

> How do you measure quota attainment?
>
> - [ ] **Quarterly** — quota resets every quarter (most common in SaaS)
> - [ ] **Monthly** — quota resets every month (Insurance, Telecom)
> - [ ] **Semi-annually** — quota resets every 6 months
> - [ ] **Annually** — quota is full-year only (Financial Services, some Enterprise)
> - [ ] **Rolling** — trailing 12-month window (less common)

**Question 6: Payment Cadence**

> How often are commissions paid?
>
> - [ ] **Monthly** (most common)
> - [ ] **Semi-monthly** (1st and 15th)
> - [ ] **Bi-weekly**
> - [ ] **Quarterly**

**Question 7: Do you use draws / advances?**

> - [ ] **Yes — recoverable draw** (advance against future earnings, repaid from commissions)
> - [ ] **Yes — non-recoverable draw** (guaranteed minimum, not repaid)
> - [ ] **No draws**

**Question 8: Plan Year Rollover**

> What happens at the start of a new fiscal year?
>
> - [ ] **New plans from scratch** — every year is designed independently
> - [ ] **Clone and modify** — start from last year's plans, adjust rates/quotas (most common)
> - [ ] **Evergreen plans** — same plan continues, only quotas reset

### 1.3 Configuration Generation

Based on answers, the wizard creates:

1. **Incentive_Plan_Template\_\_c** records — pre-built from industry templates, customized by answers
2. **Commission_Tier\_\_c** records — rate tiers per template
3. **Quota_Template\_\_c** records — quota structures per template
4. **Participant_Role\_\_c** records — configured roles from Question 4
5. **Transaction_Category\_\_c** records — deal types from discovered Record Types
6. **Incentive_Configuration\_\_c** record — global incentives settings
7. **Plan_Year\_\_c** record — fiscal year container for annual plan lifecycle

---

## 2. INDUSTRY PLAN TEMPLATES

### 2.1 Why Templates Matter

A startup installing RevenueTrust should not face a blank configuration screen. They should see: "You selected SaaS. Here are 5 plan templates used by 80% of SaaS companies. Pick the ones that apply, customize the rates, and assign to your team."

### 2.2 Pre-Built Template Library

Templates are shipped as **seed data** in the managed package. Admin clones from library → customizes → activates.

#### SaaS / Software

| Template Name                  | Plan Type      | Trigger      | Rate Structure                                      | Typical Roles            |
| ------------------------------ | -------------- | ------------ | --------------------------------------------------- | ------------------------ |
| SaaS AE — Accelerated          | Accelerated    | Booking      | Base 8%, Tier 2 (100% quota) 12%, Tier 3 (150%) 15% | Account Executive        |
| SaaS BDR — Flat per Meeting    | Activity-Based | Activity     | $50/qualified meeting, $200/SQL                     | BDR/SDR                  |
| SaaS SE — Deal Support         | Flat           | Booking      | 1.5% of deals supported                             | Solutions Engineer       |
| SaaS CSM — Renewal Bonus       | Renewal        | Renewal Date | 3% of renewal value                                 | Customer Success Manager |
| SaaS Manager — Team Attainment | Team Override  | Booking      | 1% of team total when team >90% attainment          | Sales Manager            |

#### Insurance

| Template Name                       | Plan Type     | Trigger      | Rate Structure                                                | Typical Roles           |
| ----------------------------------- | ------------- | ------------ | ------------------------------------------------------------- | ----------------------- |
| Insurance Agent — New Policy        | Tiered        | Booking      | Tier 1: 10%, Tier 2 (>$500K premium): 12%, Tier 3 (>$1M): 15% | Agent                   |
| Insurance Agent — Renewal Trail     | Recurring     | Renewal Date | 2% of annual premium (ongoing)                                | Agent                   |
| Insurance Broker — Override         | Team Override | Booking      | 2% override on agency production                              | Broker / Agency Manager |
| Insurance Underwriter — Performance | Flat          | Milestone    | 0.5% of underwritten premium when loss ratio <65%             | Underwriter             |

#### Financial Services

| Template Name                      | Plan Type | Trigger    | Rate Structure                                 | Typical Roles        |
| ---------------------------------- | --------- | ---------- | ---------------------------------------------- | -------------------- |
| Advisor — AUM Trail                | Recurring | Monthly    | 0.25% of AUM quarterly (trail)                 | Financial Advisor    |
| Advisor — New Client               | Flat      | Booking    | 1% of initial investment (one-time)            | Financial Advisor    |
| Wealth Manager — Tiered AUM        | Tiered    | Monthly    | <$10M AUM: 0.20%, $10-50M: 0.25%, >$50M: 0.30% | Wealth Manager       |
| Relationship Manager — Fee Revenue | Flat      | Collection | 5% of fee revenue collected                    | Relationship Manager |

#### Real Estate

| Template Name         | Plan Type     | Trigger | Rate Structure                              | Typical Roles |
| --------------------- | ------------- | ------- | ------------------------------------------- | ------------- |
| Agent — Transaction   | Flat          | Booking | 3% of sale price (split with brokerage)     | Agent         |
| Broker — Override     | Team Override | Booking | 1% override on office production            | Broker        |
| Team Lead — Team Pool | Team Pool     | Booking | 15% of team GCI distributed by contribution | Team Lead     |

#### Manufacturing / Industrial

| Template Name                        | Plan Type    | Trigger | Rate Structure                      | Typical Roles     |
| ------------------------------------ | ------------ | ------- | ----------------------------------- | ----------------- |
| Sales Engineer — Gross Margin        | Gross Margin | Booking | 5% of gross margin on projects      | Sales Engineer    |
| Territory Manager — Quota Attainment | Accelerated  | Booking | Base 4%, >100% quota: 6%, >125%: 8% | Territory Manager |
| Channel Manager — Partner Sourced    | Flat         | Booking | 2% of partner-sourced deals         | Channel Manager   |

#### Telecommunications

| Template Name                          | Plan Type | Trigger           | Rate Structure                                          | Typical Roles        |
| -------------------------------------- | --------- | ----------------- | ------------------------------------------------------- | -------------------- |
| Account Exec — MRR Commission          | Recurring | Booking + Monthly | 10% of first-month MRR + 2% monthly trail for 12 months | Account Executive    |
| Retention Specialist — Save Commission | Flat      | Booking           | $500 per save + 3% of retained MRR                      | Retention Specialist |

### 2.3 Template Cloning & Year-Over-Year Management

**Clone from library:** Admin selects industry template → Clone → system creates editable copy as `Incentive_Plan_Template__c` with all tiers and quota structure.

**Clone from previous year:**

1. Admin opens "Plan Year Management" screen
2. Selects prior year (e.g., FY2026)
3. Clicks "Clone to FY2027"
4. System creates:
   - New `Plan_Year__c` record for FY2027
   - Cloned `Incentive_Plan_Template__c` records (linked to new Plan Year)
   - Cloned `Commission_Tier__c` children
   - Cloned `Quota_Template__c` records
   - Participants are NOT cloned (must be reassigned — org structure may have changed)
5. Admin reviews cloned templates, adjusts rates/quotas, activates
6. Admin assigns participants (or bulk-assigns from prior year with "Clone Assignments" option)

**Evergreen plans:** Template marked `Is_Evergreen__c = true`. On fiscal year rollover:

- Template carries forward automatically (no clone needed)
- New `Plan_Year__c` period created
- Quota\_\_c records generated for new periods
- Comp_Plan\_\_c assignments carry forward with new effective dates
- Attainment resets to 0 for new period

---

## 3. OBJECT DEFINITIONS — INCENTIVES MODULE

### 3.1 Incentive_Configuration\_\_c (Global Incentives Settings)

**Purpose:** Org-level configuration for the Incentives module. One record per org (like Forecast_Configuration\_\_c but for commissions). Created by onboarding wizard.

| #   | Field API Name                 | Type      | Label                     | Notes                                                                              |
| --- | ------------------------------ | --------- | ------------------------- | ---------------------------------------------------------------------------------- |
| 1   | Name                           | Text(80)  | Configuration Name        | "RevenueTrust Incentives Configuration"                                            |
| 2   | `Industry__c`                  | Picklist  | Industry                  | From onboarding Q1. Informs template recommendations.                              |
| 3   | `Default_Trigger_Type__c`      | Picklist  | Default Trigger           | Booking, Collection, Milestone, Revenue_Recognition, Renewal_Date                  |
| 4   | `Default_Attainment_Period__c` | Picklist  | Default Attainment Period | Monthly, Quarterly, Semi_Annual, Annual                                            |
| 5   | `Payment_Cadence__c`           | Picklist  | Payment Cadence           | Monthly, Semi_Monthly, Bi_Weekly, Quarterly                                        |
| 6   | `Draw_Policy__c`               | Picklist  | Draw Policy               | Recoverable, Non_Recoverable, None                                                 |
| 7   | `Plan_Rollover_Policy__c`      | Picklist  | Plan Rollover             | Clone_And_Modify, New_Each_Year, Evergreen                                         |
| 8   | `Commission_Currency__c`       | Text(5)   | Commission Currency       | Corporate currency for all commission calculations                                 |
| 9   | `Use_Dated_Exchange_Rates__c`  | Checkbox  | Use Dated Exchange Rates  |                                                                                    |
| 10  | `Calculation_Precision__c`     | Picklist  | Calculation Precision     | Round_To_Cent (2 decimal), Round_To_Dollar (0 decimal), Full_Precision (4 decimal) |
| 11  | `Pipeline_Object__c`           | Text(100) | Pipeline Object           | Default: "Opportunity". Shared with Forecasting config.                            |
| 12  | `Is_Active__c`                 | Checkbox  | Active                    |                                                                                    |

---

### 3.2 Plan_Year\_\_c (Plan Year — Fiscal Year Container)

**Purpose:** Groups all plan templates, assignments, and quotas for a fiscal year. Enables year-over-year cloning and management.

| #   | Field API Name               | Type         | Label          | Notes                                                     |
| --- | ---------------------------- | ------------ | -------------- | --------------------------------------------------------- |
| 1   | Name                         | Text(80)     | Plan Year Name | e.g., "FY2027", "CY2027"                                  |
| 2   | `Start_Date__c`              | Date         | Start Date     | Fiscal year start                                         |
| 3   | `End_Date__c`                | Date         | End Date       | Fiscal year end                                           |
| 4   | `Status__c`                  | Picklist     | Status         | Draft, Active, Closed, Archived                           |
| 5   | `Cloned_From__c`             | Lookup(self) | Cloned From    | → Plan_Year\_\_c. Tracks which year this was cloned from. |
| 6   | `Incentive_Configuration__c` | Lookup       | Configuration  | → Incentive_Configuration\_\_c                            |
| 7   | `Is_Current__c`              | Checkbox     | Current Year   | Only one Plan_Year can be current.                        |

---

### 3.3 Participant_Role\_\_c (Compensation Role Definition)

**Purpose:** Defines roles that earn variable compensation. Replaces KONY's hardcoded AE/BDR/SE/CSM/DCP/CSA matrix. Admin creates roles during onboarding; plan templates reference roles for eligibility.

| #   | Field API Name            | Type               | Label                      | Notes                                                                                                              |
| --- | ------------------------- | ------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 1   | Name                      | Text(80)           | Role Name                  | e.g., "Account Executive", "Insurance Agent", "Financial Advisor"                                                  |
| 2   | `Role_Code__c`            | Text(20)           | Role Code                  | Short code: "AE", "BDR", "AGT", "ADV". Unique. Used in plan eligibility rules.                                     |
| 3   | `Description__c`          | LongTextArea(2000) | Description                |                                                                                                                    |
| 4   | `Default_OTE__c`          | Currency           | Default OTE                | Typical on-target earnings for this role                                                                           |
| 5   | `Default_Variable_Pct__c` | Percent            | Default Variable %         | % of OTE that is variable (commission). e.g., 50% for AE, 20% for CSM                                              |
| 6   | `Default_Base_Pay__c`     | Currency           | Default Base Pay           | Formula candidate: OTE × (1 - Variable_Pct)                                                                        |
| 7   | `Is_Manager__c`           | Checkbox           | Is Manager Role            | Managers earn overrides on team production                                                                         |
| 8   | `Eligibility_Type__c`     | Picklist           | Eligibility Source         | Values: Opportunity_Owner, Opportunity_Role_Field, Team_Member, Custom_Query                                       |
| 9   | `Eligibility_Field__c`    | Text(100)          | Eligibility Field API Name | For Opportunity_Role_Field: which Opportunity field identifies this role (e.g., "Solutions_Engineer**c", "BDR**c") |
| 10  | `Is_Active__c`            | Checkbox           | Active                     |                                                                                                                    |
| 11  | `Sort_Order__c`           | Number(3,0)        | Display Order              |                                                                                                                    |
| 12  | `Industry__c`             | Picklist           | Industry                   | Which industry template this role came from (for filtering)                                                        |

**How this replaces KONY's hardcoded eligibility:**

| KONY (hardcoded)                                     | RevenueTrust (configurable)                                                                                    |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `theOpp.OwnerId` → always eligible                   | Participant_Role where Eligibility_Type = Opportunity_Owner                                                    |
| `theOpp.Outside_Sales_Rep__c` → eligible if non-null | Participant_Role where Eligibility_Type = Opportunity_Role_Field, Eligibility_Field = "Outside_Sales_Rep\_\_c" |
| `theOpp.Bus_Dev_Rep__c` → eligible if non-Renewal    | Participant_Role where Eligibility_Type = Opportunity_Role_Field + Transaction_Category exclusion rule         |
| Hardcoded role-to-recordtype matrix in Apex          | Declarative: Participant_Role × Transaction_Category eligibility matrix                                        |

---

### 3.4 Transaction_Category\_\_c (Transaction Category Definition)

**Purpose:** Defines what types of transactions can earn commissions. Replaces KONY's hardcoded Subscription/Renewal/Services/Training/AppVantage record type logic.

| #   | Field API Name                    | Type               | Label                 | Notes                                                                                             |
| --- | --------------------------------- | ------------------ | --------------------- | ------------------------------------------------------------------------------------------------- |
| 1   | Name                              | Text(80)           | Category Name         | e.g., "New Business", "Renewal", "Expansion", "Services", "Product Sale"                          |
| 2   | `Category_Code__c`                | Text(20)           | Category Code         | Short code: "NEW", "REN", "EXP", "SVC". Unique.                                                   |
| 3   | `Record_Type_Developer_Name__c`   | Text(100)          | CRM Record Type       | Maps to Opportunity RecordType.DeveloperName. Null = applies to all.                              |
| 4   | `Stage_Filter__c`                 | Text(200)          | Stage Filter          | Comma-separated stage names that qualify. Default: "Closed Won".                                  |
| 5   | `Probability_Threshold__c`        | Percent            | Probability Threshold | Minimum Opportunity.Probability to qualify. Default: null (any). KONY required 100% for Services. |
| 6   | `Commissionable_Value_Source__c`  | Picklist           | Value Source          | Full_Amount, Net_Amount, Gross_Margin, Line_Item_Rollup, Custom_Field, Formula                    |
| 7   | `Commissionable_Value_Field__c`   | Text(100)          | Value Field API Name  | For Custom_Field: which Opportunity field. e.g., "Gross_Commissionable_Value\_\_c"                |
| 8   | `Commissionable_Value_Formula__c` | LongTextArea(2000) | Value Formula         | For Formula type: expression. e.g., "Amount - COGS\_\_c" for gross margin.                        |
| 9   | `Is_Active__c`                    | Checkbox           | Active                |                                                                                                   |
| 10  | `Sort_Order__c`                   | Number(3,0)        | Display Order         |                                                                                                   |

**How the calculation engine uses this:**

```
For a closed Opportunity:
  1. Match Transaction_Category__c by Record_Type_Developer_Name (or all if null)
  2. Check Stage_Filter (default: Closed Won)
  3. Check Probability_Threshold (if set)
  4. Compute commissionable value using Commissionable_Value_Source:
     - Full_Amount → Opportunity.Amount
     - Net_Amount → Opportunity.Amount × (1 - Discount)
     - Gross_Margin → Amount - COGS (via formula or custom field)
     - Line_Item_Rollup → SUM(OpportunityLineItem.TotalPrice) with optional product filter
     - Custom_Field → Opportunity.{Commissionable_Value_Field}
     - Formula → evaluate expression
```

---

### 3.5 Incentive_Plan_Template\_\_c (Plan Template — The Blueprint)

**Purpose:** The blueprint for an incentive plan. Defines how commissions are calculated — rate structure, tiers, caps, triggers, eligibility. Admin creates templates (or clones from industry library), then assigns to participants.

**Updated from REVENUETRUST_OBJECT_MODEL.md V1.1 — refined with onboarding and industry context.**

| #   | Field API Name                       | Type                | Label                   | Notes                                                                                                                           |
| --- | ------------------------------------ | ------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| —   | **Identity**                         |                     |                         |                                                                                                                                 |
| 1   | Name                                 | Text(80)            | Template Name           | e.g., "Enterprise AE — Accelerated FY2027"                                                                                      |
| 2   | `Description__c`                     | LongTextArea(5000)  | Description             |                                                                                                                                 |
| 3   | `Plan_Year__c`                       | Lookup              | Plan Year               | → Plan_Year\_\_c                                                                                                                |
| 4   | `Industry__c`                        | Picklist            | Industry                | Which industry this template is designed for                                                                                    |
| 5   | `Is_Library_Template__c`             | Checkbox            | Library Template        | True = shipped with package as seed data. Read-only. Admin must clone.                                                          |
| 6   | `Cloned_From__c`                     | Lookup(self)        | Cloned From             | → Incentive_Plan_Template\_\_c. Tracks clone lineage for audit.                                                                 |
| —   | **Plan Type & Trigger**              |                     |                         |                                                                                                                                 |
| 7   | `Plan_Type__c`                       | Restricted Picklist | Plan Type               | Flat, Tiered, Accelerated, Gross_Margin, Recurring, Milestone, Activity_Based, Team_Pool, Team_Override                         |
| 8   | `Trigger_Type__c`                    | Restricted Picklist | Commission Trigger      | Booking, Collection, Milestone, Revenue_Recognition, Renewal_Date, Activity, Monthly_Recurring                                  |
| 9   | `Commissionable_Value_Override__c`   | Picklist            | Commissionable Value    | Null = use Transaction_Category default. Non-null overrides per template: Full_Amount, Net_Amount, Gross_Margin, Custom_Formula |
| —   | **Rate Structure**                   |                     |                         |                                                                                                                                 |
| 10  | `Base_Rate_Pct__c`                   | Percent             | Base Rate %             | Default rate for Tier 1. For Flat plans, this is the only rate.                                                                 |
| 11  | `Base_Rate_Amount__c`                | Currency            | Base Rate ($)           | Flat dollar amount alternative (for Activity-Based: $/meeting, $/SQL)                                                           |
| 12  | `Is_Retroactive__c`                  | Checkbox            | Retroactive Tiers       | If true, crossing a tier retroactively re-rates ALL prior transactions in the period at the new rate                            |
| —   | **Caps & Holds**                     |                     |                         |                                                                                                                                 |
| 13  | `Cap_Amount__c`                      | Currency            | Cap Amount              | Max payout per period                                                                                                           |
| 14  | `Cap_Pct_of_OTE__c`                  | Percent             | Cap % of OTE            | Max payout as % of participant's OTE                                                                                            |
| 15  | `Cap_Per_Transaction__c`             | Currency            | Cap Per Transaction     | Windfall protection                                                                                                             |
| 16  | `Hold_Pct__c`                        | Percent             | Default Hold %          | Percentage held back pending conditions (collection, customer go-live, etc.)                                                    |
| 17  | `Hold_Type__c`                       | Picklist            | Hold Type               | None, Base_Rate_Hold, Target_Hold, Collection_Hold, Custom                                                                      |
| 18  | `Hold_Release_Trigger__c`            | Picklist            | Hold Release Trigger    | Automatic_On_Collection, Automatic_On_Date, Manual_Admin, Automatic_On_Milestone                                                |
| —   | **Payment**                          |                     |                         |                                                                                                                                 |
| 19  | `Payment_Frequency__c`               | Picklist            | Payment Frequency       | Weekly, Bi_Weekly, Semi_Monthly, Monthly, Quarterly                                                                             |
| 20  | `Deferred_Payment__c`                | Checkbox            | Deferred Payment        | If true, payout is split over a vesting schedule                                                                                |
| 21  | `Vesting_Schedule__c`                | LongTextArea(500)   | Vesting Schedule        | JSON: [{"month": 0, "pct": 34}, {"month": 3, "pct": 33}, {"month": 6, "pct": 33}]                                               |
| —   | **Attainment**                       |                     |                         |                                                                                                                                 |
| 22  | `Attainment_Period__c`               | Picklist            | Attainment Period       | Monthly, Quarterly, Semi_Annual, Annual                                                                                         |
| 23  | `Attainment_Metric__c`               | Picklist            | Attainment Metric       | Primary, Secondary, Custom (which Forecast Metric to use for attainment)                                                        |
| —   | **Penalties & Modifiers**            |                     |                         |                                                                                                                                 |
| 24  | `Penalty_Pct__c`                     | Percent             | Short-Term Penalty %    | Applied to deals below minimum term                                                                                             |
| 25  | `Min_Term_Months__c`                 | Number(3,0)         | Min Term for Penalty    | In months                                                                                                                       |
| 26  | `Multi_Period_Bonus_Rate__c`         | Percent             | Multi-Period Bonus Rate | Extra rate for deals spanning multiple periods                                                                                  |
| 27  | `Multi_Period_Cap__c`                | Currency            | Multi-Period Cap        |                                                                                                                                 |
| —   | **Eligibility**                      |                     |                         |                                                                                                                                 |
| 28  | `Eligible_Roles__c`                  | LongTextArea(1000)  | Eligible Roles          | JSON array of Participant_Role**c.Role_Code**c values: ["AE", "SE", "MGR"]                                                      |
| 29  | `Eligible_Transaction_Categories__c` | LongTextArea(1000)  | Eligible Categories     | JSON array of Transaction_Category**c.Category_Code**c values: ["NEW", "REN"]                                                   |
| 30  | `Dependent_Template__c`              | Lookup(self)        | Dependent Template      | Gate: participant must hit threshold on dependent plan first                                                                    |
| 31  | `Dependent_Threshold_Pct__c`         | Percent             | Dependent Threshold     | Attainment % required on dependent plan before this plan pays                                                                   |
| —   | **Recurring / Trail**                |                     |                         |                                                                                                                                 |
| 32  | `Is_Recurring__c`                    | Checkbox            | Recurring Commission    | Trail/residual commission on active customers                                                                                   |
| 33  | `Recurring_Rate_Pct__c`              | Percent             | Recurring Rate %        | Monthly/quarterly trail rate                                                                                                    |
| 34  | `Recurring_Duration_Months__c`       | Number(3,0)         | Recurring Duration      | How many months the trail lasts. Null = indefinite (as long as customer active)                                                 |
| 35  | `Recurring_Cadence__c`               | Picklist            | Recurring Cadence       | Monthly, Quarterly, Annual                                                                                                      |
| —   | **Lifecycle**                        |                     |                         |                                                                                                                                 |
| 36  | `Status__c`                          | Restricted Picklist | Status                  | Draft, Active, Archived                                                                                                         |
| 37  | `Effective_Start__c`                 | Date                | Effective Start         |                                                                                                                                 |
| 38  | `Effective_End__c`                   | Date                | Effective End           |                                                                                                                                 |
| 39  | `Acceptance_Gate__c`                 | Picklist            | Acceptance Gate         | Hard, Soft, None (see §4.9 of main spec)                                                                                        |
| 40  | `Plan_Document_URL__c`               | Url                 | Plan Document           | PDF/doc for acceptance workflow                                                                                                 |
| 41  | `Is_Evergreen__c`                    | Checkbox            | Evergreen               | Auto-carries forward on FY rollover                                                                                             |

---

### 3.6 Commission_Tier\_\_c (Rate Tier — Child of Template)

**Purpose:** Defines rate bands/tiers for a plan template. Replaces KONY's hardcoded Q1-Q4 accelerator thresholds.

| #   | Field API Name          | Type         | Label            | Notes                                                                                                                                                 |
| --- | ----------------------- | ------------ | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`      | MasterDetail | Plan Template    | → Incentive_Plan_Template\_\_c                                                                                                                        |
| 2   | `Tier_Name__c`          | Text(50)     | Tier Name        | e.g., "Base", "Accelerator", "Super Accelerator", "President's Club"                                                                                  |
| 3   | `Min_Attainment_Pct__c` | Percent      | Min Attainment % | Lower bound (inclusive). 0% for base tier.                                                                                                            |
| 4   | `Max_Attainment_Pct__c` | Percent      | Max Attainment % | Upper bound (exclusive). Null = unlimited.                                                                                                            |
| 5   | `Rate_Pct__c`           | Percent      | Rate %           | Commission rate for this tier. For tiered (non-retroactive): applies only to value in this band. For accelerated (retroactive): applies to ALL value. |
| 6   | `Rate_Amount__c`        | Currency     | Rate ($)         | Flat dollar amount alternative                                                                                                                        |
| 7   | `Is_Retroactive__c`     | Checkbox     | Retroactive      | Inherited from template default; can override per tier                                                                                                |
| 8   | `Period_Scope__c`       | Picklist     | Period Scope     | Monthly, Quarterly, Annual, Cumulative. Which attainment period this tier evaluates against.                                                          |
| 9   | `Sort_Order__c`         | Number(3,0)  | Sort Order       | Ascending — Tier 1 (base) = lowest sort order                                                                                                         |
| 10  | `Is_Active__c`          | Checkbox     | Active           |                                                                                                                                                       |

**Tiered vs. Accelerated example:**

Tiered (non-retroactive): "First $1M at 8%, next $500K at 10%, above $1.5M at 12%"

```
Tier 1: Min 0%, Max 100%, Rate 8%, Retroactive = false
Tier 2: Min 100%, Max 150%, Rate 10%, Retroactive = false
Tier 3: Min 150%, Max null, Rate 12%, Retroactive = false
```

Accelerated (retroactive): "Below quota at 8%, above quota ALL deals at 12%"

```
Tier 1: Min 0%, Max 100%, Rate 8%, Retroactive = false
Tier 2: Min 100%, Max null, Rate 12%, Retroactive = true
```

---

### 3.7 Quota_Template\_\_c (Quota Blueprint)

**Unchanged from REVENUETRUST_OBJECT_MODEL.md V1.1 §2.6.** Adding Plan_Year\_\_c link and clone support.

| #   | Field API Name                                     | Type              | Label           | Notes                                     |
| --- | -------------------------------------------------- | ----------------- | --------------- | ----------------------------------------- |
| 1   | Name                                               | Text(80)          | Template Name   |                                           |
| 2   | `Plan_Template__c`                                 | Lookup            | Plan Template   | → Incentive_Plan_Template\_\_c (optional) |
| 3   | `Plan_Year__c`                                     | Lookup            | Plan Year       | → Plan_Year\_\_c                          |
| 4   | `Fiscal_Year__c`                                   | Text(10)          | Fiscal Year     |                                           |
| 5   | `Period_Type__c`                                   | Picklist          | Period Type     | Monthly, Quarterly, Semi_Annual, Annual   |
| 6   | `Metric__c`                                        | Picklist          | Metric          | Primary, Secondary, Custom_1–4            |
| 7   | `Annual_Target__c`                                 | Currency          | Annual Target   |                                           |
| 8   | `Period_1_Target__c` through `Period_12_Target__c` | Currency          | Period N Target | 12 period slots                           |
| 19  | `Distribution_Method__c`                           | Picklist          | Distribution    | Equal, Weighted, Custom                   |
| 20  | `Eligible_Roles__c`                                | LongTextArea(500) | Eligible Roles  | JSON role codes                           |
| 21  | `Territory__c`                                     | Lookup            | Territory       | → Territory\_\_c (optional)               |
| 22  | `Status__c`                                        | Picklist          | Status          | Draft, Active, Archived                   |
| 23  | `Cloned_From__c`                                   | Lookup(self)      | Cloned From     | Clone lineage                             |

---

### 3.8 Comp_Plan\_\_c (Incentive Plan Assignment — Per Participant)

**Purpose:** One record = one participant assigned to one plan template for one plan year. This is the **assignment**, not the design.

| #   | Field API Name              | Type                | Label                 | Notes                                               |
| --- | --------------------------- | ------------------- | --------------------- | --------------------------------------------------- |
| 1   | `Plan_Template__c`          | Lookup              | Plan Template         | → Incentive_Plan_Template\_\_c                      |
| 2   | `Plan_Year__c`              | Lookup              | Plan Year             | → Plan_Year\_\_c                                    |
| 3   | `Sales_Rep__c`              | Lookup              | Participant           | → User                                              |
| 4   | `Participant_Role__c`       | Lookup              | Participant Role      | → Participant_Role\_\_c                             |
| 5   | `Effective_Start__c`        | Date                | Effective Start       | May differ from template (mid-year hire)            |
| 6   | `Effective_End__c`          | Date                | Effective End         | May differ (termination)                            |
| 7   | `Territory__c`              | Lookup              | Territory             | → Territory\_\_c (optional)                         |
| 8   | `Entity__c`                 | Picklist            | Entity                | Legal entity for payroll                            |
| 9   | `OTE__c`                    | Currency            | On-Target Earnings    | Per-participant OTE (default from Role)             |
| 10  | `Base_Pay__c`               | Currency            | Base Pay              |                                                     |
| 11  | `Variable_Compensation__c`  | Currency            | Variable Compensation | OTE - Base_Pay                                      |
| 12  | `Wage_Currency__c`          | Picklist            | Wage Currency         |                                                     |
| 13  | `Fx_Rate__c`                | Number(18,6)        | FX Rate               |                                                     |
| 14  | `Override_Base_Rate__c`     | Percent             | Override Base Rate    | Per-participant rate override (null = use template) |
| 15  | `Status__c`                 | Restricted Picklist | Assignment Status     | Draft, Active, On_Hold, Terminated                  |
| 16  | `Plan_Acceptance_Status__c` | Picklist            | Acceptance Status     | Not_Published, Pending, Accepted, Declined          |
| 17  | `Plan_Accepted_Date__c`     | DateTime            | Accepted Date         |                                                     |
| 18  | `Plan_Accepted_Method__c`   | Picklist            | Acceptance Method     | Click_To_Accept, DocuSign, AdobeSign                |
| 19  | `Cloned_From__c`            | Lookup(self)        | Cloned From           | Prior year assignment this was cloned from          |
| 20  | `Notes__c`                  | LongTextArea(5000)  | Admin Notes           |                                                     |

---

### 3.9 Quota\_\_c (Quota Assignment — Per Participant Per Period)

**Unchanged from REVENUETRUST_OBJECT_MODEL.md V1.1 §2.7.** Adding Plan_Year\_\_c and Granularity/Parent from §5.4.3.

| #   | Field API Name         | Type         | Label             | Notes                                                             |
| --- | ---------------------- | ------------ | ----------------- | ----------------------------------------------------------------- |
| 1   | `Participant__c`       | Lookup       | Participant       | → User                                                            |
| 2   | `Quota_Template__c`    | Lookup       | Quota Template    | → Quota_Template\_\_c                                             |
| 3   | `Comp_Plan__c`         | Lookup       | Incentive Plan    | → Comp_Plan\_\_c                                                  |
| 4   | `Plan_Year__c`         | Lookup       | Plan Year         | → Plan_Year\_\_c                                                  |
| 5   | `Territory__c`         | Lookup       | Territory         | → Territory\_\_c (optional)                                       |
| 6   | `Period_Start__c`      | Date         | Period Start      |                                                                   |
| 7   | `Period_End__c`        | Date         | Period End        |                                                                   |
| 8   | `Period_Label__c`      | Text(50)     | Period Label      |                                                                   |
| 9   | `Period_Type__c`       | Picklist     | Period Type       | Monthly, Quarterly, Semi_Annual, Annual                           |
| 10  | `Granularity__c`       | Picklist     | Granularity       | Monthly, Quarterly, Semi_Annual, Annual (from Forecasting §5.4.3) |
| 11  | `Parent_Quota__c`      | Lookup(self) | Parent Quota      | Monthly → Quarterly → Annual hierarchy                            |
| 12  | `Metric__c`            | Picklist     | Metric            | Primary, Secondary, Custom_1–4                                    |
| 13  | `Target_Amount__c`     | Currency     | Target            |                                                                   |
| 14  | `Achieved_Amount__c`   | Currency     | Achieved          | Updated by calculation engine                                     |
| 15  | `Attainment__c`        | Percent      | Attainment %      | Formula: Achieved / Target                                        |
| 16  | `Adjustment_Amount__c` | Currency     | Adjustment        | Manual ± from target                                              |
| 17  | `Adjusted_Target__c`   | Currency     | Adjusted Target   | Formula: Target + Adjustment                                      |
| 18  | `Adjustment_Reason__c` | Text(255)    | Adjustment Reason |                                                                   |
| 19  | `Fiscal_Year__c`       | Text(10)     | Fiscal Year       |                                                                   |
| 20  | `Status__c`            | Picklist     | Status            | Draft, Active, Closed                                             |

---

### 3.10 Comp_Calculation\_\_c (Incentive Calculation — Immutable Ledger)

**The core calculation record. Append-only per §1.5.4.**

Unchanged from REVENUETRUST_OBJECT_MODEL.md V1.1 §2.2. Key fields:

| #   | Key Fields                    | Notes                                                                  |
| --- | ----------------------------- | ---------------------------------------------------------------------- |
| 1   | `Comp_Plan__c` (MasterDetail) | → Comp_Plan\_\_c                                                       |
| 2   | `Opportunity__c` (Lookup)     | → Opportunity                                                          |
| 3   | `Rep__c` (Lookup)             | → User                                                                 |
| 4   | `Commisionable_Value__c`      | The value the commission was calculated on                             |
| 5   | `Applied_Percentage__c`       | Rate that was applied                                                  |
| 6   | `Eligible_Commission__c`      | Resulting commission amount                                            |
| 7   | `Rate_Tier_Applied__c`        | Which Commission_Tier\_\_c tier name governed this calc                |
| 8   | `Quota_Category__c`           | Which Transaction_Category\_\_c this maps to                           |
| 9   | `Processing_Run_Id__c`        | Groups records from same processing run                                |
| 10  | `Adjustment_Type__c`          | Original, Amendment, Reversal, Clawback                                |
| 11  | `Attainment_Snapshot__c`      | Attainment % at moment of calculation                                  |
| 12  | `Type__c`                     | Base, Accelerator, Adjustment, Clawback, Reversal, Recurring, Override |

_(Full field list in REVENUETRUST_OBJECT_MODEL.md §2.2)_

---

### 3.11 Commission_Draw\_\_c (Draw/Advance Record)

Unchanged from REVENUETRUST_OBJECT_MODEL.md V1.1 §2.3. 8 fields.

---

### 3.12 Incentive_Dispute\_\_c (Dispute Record)

Unchanged from REVENUETRUST_OBJECT_MODEL.md V1.1 §2.8. 9 fields.

---

### 3.13 Payment_Schedule\_\_c (Deferred/Vesting Payment — NEW)

**Purpose:** For deferred payment plans, tracks individual vesting installments per Comp_Calculation\_\_c.

| #   | Field API Name          | Type        | Label                  | Notes                                      |
| --- | ----------------------- | ----------- | ---------------------- | ------------------------------------------ |
| 1   | `Comp_Calculation__c`   | Lookup      | Incentive Calculation  | → Comp_Calculation\_\_c                    |
| 2   | `Installment_Number__c` | Number(3,0) | Installment #          | 1, 2, 3...                                 |
| 3   | `Installment_Pct__c`    | Percent     | Installment %          | e.g., 34%, 33%, 33%                        |
| 4   | `Installment_Amount__c` | Currency    | Installment Amount     |                                            |
| 5   | `Scheduled_Date__c`     | Date        | Scheduled Payment Date |                                            |
| 6   | `Paid_Date__c`          | Date        | Actual Paid Date       |                                            |
| 7   | `Status__c`             | Picklist    | Status                 | Scheduled, Due, Paid, Cancelled, Forfeited |
| 8   | `Hold_Reason__c`        | Text(255)   | Hold Reason            | If held from payment                       |

---

### 3.14 Incentive_Change_Event\_\_c (Immutable History — NEW)

**Mirrors Forecast_Change_Event\_\_c pattern from Forecasting module.** Tracks changes to Comp_Plan**c, Quota**c, and processing events.

| #   | Field API Name      | Type                | Label       | Notes                                                                                                                                              |
| --- | ------------------- | ------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Record_Type__c`    | Picklist            | Record Type | Plan_Assignment, Quota, Calculation, Draw, Template                                                                                                |
| 2   | `Record_Id__c`      | Text(18)            | Record ID   | ID of the changed record                                                                                                                           |
| 3   | `Change_Type__c`    | Restricted Picklist | Change Type | Status_Change, Rate_Override, Quota_Adjustment, Calculation_Processed, Draw_Created, Template_Cloned, Plan_Accepted, Plan_Terminated, Reprocessing |
| 4   | `Old_Value__c`      | LongTextArea(2000)  | Old Values  | JSON of changed fields                                                                                                                             |
| 5   | `New_Value__c`      | LongTextArea(2000)  | New Values  | JSON of changed fields                                                                                                                             |
| 6   | `Changed_By__c`     | Lookup              | Changed By  | → User                                                                                                                                             |
| 7   | `Changed_On__c`     | DateTime            | Changed On  |                                                                                                                                                    |
| 8   | `Change_Context__c` | LongTextArea(1000)  | Context     | Processing run ID, reprocessing reason, etc.                                                                                                       |

---

## 4. CALCULATION ENGINE — FLOW (GENERIC)

This replaces KONY's hardcoded `CommissionsProcessFY19.process()` with a configurable 7-step engine.

```
STEP 1: IDENTIFY TRANSACTION
  → Pipeline record closed (or milestone/collection/renewal trigger met)
  → Match to Transaction_Category__c by Record Type + Stage + Probability
  → Compute commissionable value per category's Value Source

STEP 2: IDENTIFY ELIGIBLE PARTICIPANTS
  → For each Participant_Role__c:
     → Evaluate Eligibility_Type:
        Opportunity_Owner → rep = Opportunity.OwnerId
        Opportunity_Role_Field → rep = Opportunity.{Eligibility_Field}
        Team_Member → reps from OpportunityTeamMember
        Custom_Query → admin-defined
     → Collect all eligible User IDs

STEP 3: RESOLVE PLANS
  → For each eligible participant:
     → Find active Comp_Plan__c assignments where:
        Status = Active
        Effective dates cover transaction date
        Template's Eligible_Roles includes participant's role code
        Template's Eligible_Transaction_Categories includes this category code
     → If Dependent_Template gate exists: check dependent plan attainment ≥ threshold

STEP 4: DETERMINE RATE
  → Load Commission_Tier__c children from the plan's template
  → Load current Quota__c attainment for this participant + period
  → Match attainment to tier:
     If tiered (non-retroactive): apply each tier's rate only to value within that band
     If accelerated (retroactive): apply top qualifying tier's rate to ALL value
  → Apply Override_Base_Rate from Comp_Plan__c if non-null
  → Apply caps (per-transaction, per-period, per-OTE%)

STEP 5: CALCULATE
  → commission = commissionable_value × rate
  → Apply modifiers: penalty (short term), multi-period bonus, hold %
  → Create Comp_Calculation__c record (immutable ledger entry):
     Processing_Run_Id, Adjustment_Type = Original
     Attainment_Snapshot = current attainment at calculation time
     Rate_Tier_Applied = tier name

STEP 6: UPDATE ATTAINMENT
  → Increment Quota__c.Achieved_Amount__c
  → This triggers Forecasting module attainment cache refresh (Platform Event)

STEP 7: CREATE PAYMENT
  → If Deferred: create Payment_Schedule__c installment records from vesting schedule
  → If Immediate: create payable entry
  → If Draw balance exists: offset against draw
  → Create Incentive_Change_Event__c for audit trail
```

---

## 5. DECISION POINTS

### DP-I1: Should Participant_Role\_\_c be a Custom Object or Custom Metadata?

**Custom Object (recommended):** Admin creates roles via standard UI during onboarding. Roles can reference Territory\_\_c, industry templates, etc. Wizard creates them dynamically.

### DP-I2: Should Transaction_Category\_\_c be a Custom Object or Custom Metadata?

**Custom Object (recommended):** Same rationale. Discovery wizard auto-creates from Opportunity Record Types.

### DP-I3: Does the Incentives module need its own Snapshot object?

**Not for V1.** The Forecasting module's Forecast_Snapshot**c captures attainment at snapshot time. Commission-specific analytics (payout trends, tier distribution) can be derived from the Comp_Calculation**c ledger directly since it's append-only. If needed later, add `Incentive_Snapshot__c`.

### DP-I4: How does reprocessing work?

When a deal needs reprocessing (amount changed, new eligible participant discovered):

1. System creates **Reversal** Comp_Calculation\_\_c records for all original entries (negative amounts)
2. System runs the full calculation engine again, creating new **Original** entries
3. Net effect: original + reversal + new original. Full audit trail preserved.
4. Never delete or update existing Comp_Calculation\_\_c records.

---

## 6. ENTITY RELATIONSHIP DIAGRAM

```
Plan_Year__c (fiscal year container)
  ├── Incentive_Plan_Template__c     (N — plan blueprints)
  │     ├── Commission_Tier__c       (N — rate tiers)
  │     ├── Quota_Template__c        (N — quota blueprints)
  │     │     └── Quota__c           (N — per participant per period)
  │     └── Comp_Plan__c             (N — per participant assignments)
  │           ├── Comp_Calculation__c (N — immutable ledger)
  │           │     └── Payment_Schedule__c (N — vesting installments)
  │           └── Commission_Draw__c (N — draws/advances/paybacks)
  │
  └── (cloned from prior Plan_Year__c via Cloned_From__c)

Incentive_Configuration__c           (1 — global settings)
Participant_Role__c                  (N — role definitions)
Transaction_Category__c              (N — deal type definitions)
Incentive_Dispute__c                 (N — linked to Comp_Calculation__c)
Incentive_Change_Event__c            (N — immutable audit trail)

External:
  User                               — Comp_Plan__c.Sales_Rep__c
  Opportunity                        — Comp_Calculation__c.Opportunity__c
  Territory__c                       — shared with Forecasting module
  Forecast_Participant__c            — attainment cache reads from Quota__c
```

---

## 7. OBJECT COUNT — INCENTIVES MODULE

| Type                        | Count                 | Objects                                                                                 |
| --------------------------- | --------------------- | --------------------------------------------------------------------------------------- |
| Config objects              | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c  |
| Template objects            | 3                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template\_\_c                     |
| Assignment objects          | 2                     | Comp_Plan**c, Quota**c                                                                  |
| Runtime/Ledger objects      | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c |
| Dispute                     | 1                     | Incentive_Dispute\_\_c                                                                  |
| **Incentives Module Total** | **14 custom objects** |                                                                                         |
| Shared with Forecasting     | 1                     | Territory\_\_c                                                                          |

---

## 8. CROSS-MODULE DATA FLOW

```
INCENTIVES → FORECASTING (via Platform Event on Quota__c.Achieved_Amount__c change):
  Quota attainment updates → Forecast_Participant__c cache refresh
  Rate tier position → Inline Estimator in forecast grid
  Threshold proximity → Governance rules CG-1 through CG-4

FORECASTING → INCENTIVES (read-only):
  Forecast_Override__c pipeline data → Payout Forecasting ("what will I earn?")
  AI Close Probability → Projected attainment

INCENTIVES → BEHAVIOR INTELLIGENCE (read-only):
  Comp_Calculation__c ledger → Threshold clustering, timing concentration analysis
  Quota__c attainment → Sandbagging detection proximity
  Commission_Tier__c thresholds → CG-2/CG-3/CG-4 evaluation
```

---

---

## 9. V1.1 REFINEMENTS — FEEDBACK INCORPORATION

### 9.1 Discovery Enhancements

**Problem:** V1.0 discovery was too narrow. Orgs may not use Record Types (FlexiPages instead), may have custom currency fields, and fiscal year should be auto-detected.

**Updated Discovery Table (replaces §1.1):**

| Discovery Check                   | Query / Method                                                                                              | What We Learn                                                                                                                                                            |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Fiscal Year**                   | `Organization.FiscalYearStartMonth`, `Organization.UsesStartDateAsFiscalYearName`                           | Auto-derive fiscal year. No need to ask — read from org settings.                                                                                                        |
| **Opportunity Record Types**      | `SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'Opportunity' AND IsActive = true`      | Are Record Types used at all? How many?                                                                                                                                  |
| **Opportunity Custom Fields**     | `Schema.SObjectType.Opportunity.fields.getMap()` — filter for Currency fields                               | Discover ALL currency fields: Amount, TCV**c, ACV**c, NBV**c, Incremental_ACV**c, MRR**c, Gross_Margin**c, etc. Present these to admin for commissionable value mapping. |
| **Opportunity Picklist Fields**   | Same schema describe — filter for Picklist fields                                                           | If no Record Types, discover which picklist fields might categorize deals (Type, Deal_Category**c, Product_Line**c, etc.)                                                |
| **Activity Objects**              | Check if Task/Event objects have custom fields for call tracking. Check for Activity Metrics, Call objects. | For BDR/SDR activity-based commission discovery.                                                                                                                         |
| **OpportunityContactRole / Team** | `SELECT Count() FROM OpportunityTeamMember`                                                                 | Are teams used? How extensively?                                                                                                                                         |
| **Existing commission objects**   | Check for Comp_Plan**c, Commission**c, etc.                                                                 | Migration scenario detection                                                                                                                                             |
| **Sales Roles**                   | User.Profile, UserRole                                                                                      | Role-based template recommendations                                                                                                                                      |
| **Currency**                      | Multi-currency, Dated Exchange Rates                                                                        | Inherited from Forecasting if already configured                                                                                                                         |
| **Existing Splits**               | OpportunitySplit presence                                                                                   | Future split support                                                                                                                                                     |

**New Onboarding Question (replaces part of Q1 flow):**

**Question 1B: Deal Categorization**

> We detected {N Record Types / No Record Types} on Opportunity.
>
> How do you categorize deals for commission purposes?
>
> - [ ] **By Record Type** — {show discovered record types as checkboxes}
> - [ ] **By Picklist Field** — which field? {show discovered picklist fields: Type, Category\_\_c, etc.}
> - [ ] **By Custom Field** — specify the field API name
> - [ ] **All deals treated the same** — no categorization needed

This answer drives how `Transaction_Category__c.Category_Source__c` is configured.

**New Onboarding Question:**

**Question 4B: Activity-Based Commissions**

> Do any roles earn commissions based on activities (not deal closures)?
>
> - [ ] **Yes** — specify activity types:
>   - [ ] Qualified meetings booked (from Events)
>   - [ ] Qualified opportunities created (from Opportunity)
>   - [ ] Calls logged (from Tasks where Type = 'Call')
>   - [ ] Custom activity: {specify object + filter criteria}
> - [ ] **No** — all commissions are deal-based

**New Onboarding Question:**

**Question 9: Clawback Policy**

> What happens when a customer churns or a deal is reversed?
>
> - [ ] **Full clawback** — 100% of commission is recovered regardless of timing
> - [ ] **Time-decayed clawback** — recovery % decreases over time (e.g., 100% in month 1-3, 50% in month 4-6, 0% after 6 months)
> - [ ] **Partial clawback** — fixed % recovered (e.g., always 50%)
> - [ ] **No clawback** — commissions are earned permanently on close
> - [ ] **Configurable per plan** — different policies for different plan types

---

### 9.2 Transaction_Category\_\_c — Updated for Non-Record-Type Orgs

**New field added to Transaction_Category\_\_c:**

| #   | Field API Name             | Type      | Label                 | Notes                                                                                         |
| --- | -------------------------- | --------- | --------------------- | --------------------------------------------------------------------------------------------- |
| 11  | `Category_Source__c`       | Picklist  | Category Source       | How this category matches deals. Values: Record_Type, Picklist_Field, Custom_Field, All_Deals |
| 12  | `Category_Source_Field__c` | Text(100) | Source Field API Name | For Picklist_Field/Custom_Field: which Opportunity field. e.g., "Type", "Deal_Category\_\_c"  |
| 13  | `Category_Source_Value__c` | Text(200) | Source Field Value(s) | Comma-separated values that match this category. e.g., "New Business,Expansion"               |

**Updated matching logic:**

```
For a closed Opportunity:
  1. Match Transaction_Category__c by Category_Source:
     - Record_Type → match RecordType.DeveloperName = Record_Type_Developer_Name
     - Picklist_Field → match Opportunity.{Category_Source_Field} IN (Category_Source_Values)
     - Custom_Field → match Opportunity.{Category_Source_Field} IN (Category_Source_Values)
     - All_Deals → always matches (no filter)
  2. Check Stage_Filter
  3. Check Probability_Threshold
  4. Compute commissionable value per Value Source
```

---

### 9.3 Commissionable Value Discovery — Currency Field Mapping

The discovery wizard presents ALL currency fields found on Opportunity and lets the admin map them:

**New object: Commissionable_Value_Map**c (child of Transaction_Category**c)**

| #   | Field API Name            | Type         | Label                        | Notes                                                                                          |
| --- | ------------------------- | ------------ | ---------------------------- | ---------------------------------------------------------------------------------------------- |
| 1   | `Transaction_Category__c` | MasterDetail | Transaction Category         | → Transaction_Category\_\_c                                                                    |
| 2   | `Opportunity_Field__c`    | Text(100)    | Opportunity Field            | API name of the currency field: "Amount", "TCV**c", "ACV**c", "NBV**c", "Gross_Margin**c"      |
| 3   | `Field_Label__c`          | Text(100)    | Display Label                | What the admin sees: "Total Contract Value", "Annual Contract Value"                           |
| 4   | `Is_Primary__c`           | Checkbox     | Primary Commissionable Value | The main field used for commission calculation                                                 |
| 5   | `Is_Attainment_Value__c`  | Checkbox     | Counts Toward Attainment     | Whether this field value increments quota attainment                                           |
| 6   | `Adjustment_Type__c`      | Picklist     | Adjustment                   | None, Subtract_From_Primary (for COGS/discount fields), Multiply_By_Primary (for ratio fields) |
| 7   | `Sort_Order__c`           | Number(3,0)  | Display Order                |                                                                                                |

**Example for a SaaS company:**

| Category     | Field               | Primary? | Attainment? | Notes                                                 |
| ------------ | ------------------- | -------- | ----------- | ----------------------------------------------------- |
| New Business | TCV\_\_c            | Yes      | No          | Commission calculated on TCV                          |
| New Business | ACV\_\_c            | No       | Yes         | Quota attainment measured on ACV                      |
| Renewal      | Renewal_Amount\_\_c | Yes      | Yes         | Commission and attainment on same field               |
| Services     | Amount              | Yes      | No          | Services commissions on full amount                   |
| Services     | COGS\_\_c           | No       | No          | Adjustment = Subtract_From_Primary (for gross margin) |

This replaces the single `Commissionable_Value_Source__c` / `Commissionable_Value_Field__c` fields on Transaction_Category\_\_c, which were too simplistic for orgs with multiple currency fields.

---

### 9.4 Activity_Commission_Rule\_\_c — Activity-Based Commissions (NEW)

**Purpose:** For BDR/SDR roles where commissions are based on activities (calls, meetings, qualified opportunities) rather than deal closures.

| #   | Field API Name             | Type               | Label                     | Notes                                                                                                                                                          |
| --- | -------------------------- | ------------------ | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`         | MasterDetail       | Plan Template             | → Incentive_Plan_Template\_\_c (only for Activity_Based plan types)                                                                                            |
| 2   | `Activity_Type__c`         | Picklist           | Activity Type             | Qualified_Meeting, Qualified_Opportunity, Call_Logged, Demo_Completed, Custom                                                                                  |
| 3   | `Source_Object__c`         | Text(100)          | Source Object             | "Event", "Task", "Opportunity", custom object API name                                                                                                         |
| 4   | `Filter_Criteria__c`       | LongTextArea(2000) | Filter Criteria           | JSON: qualifying conditions. e.g., `{"Type": "Demo", "Status": "Completed"}` for events, `{"StageName": "Qualified", "CreatedById": "{participant}"}` for opps |
| 5   | `Rate_Per_Activity__c`     | Currency           | Rate Per Activity         | Flat dollar amount per qualifying activity. e.g., $50/qualified meeting                                                                                        |
| 6   | `Rate_Pct_Per_Activity__c` | Percent            | Rate % Per Activity       | Percentage of activity value (for opportunity-based: % of Amount)                                                                                              |
| 7   | `Cap_Per_Period__c`        | Currency           | Cap Per Period            | Max payout from this activity type per attainment period                                                                                                       |
| 8   | `Cap_Count_Per_Period__c`  | Number(5,0)        | Max Activities Per Period | Max qualifying activities counted per period                                                                                                                   |
| 9   | `Counting_Method__c`       | Picklist           | Counting Method           | Count (# of activities), Sum_Value (total value), Both                                                                                                         |
| 10  | `Is_Active__c`             | Checkbox           | Active                    |                                                                                                                                                                |

**Example configurations:**

| Role | Activity              | Object      | Filter                               | Rate         | Cap            |
| ---- | --------------------- | ----------- | ------------------------------------ | ------------ | -------------- |
| BDR  | Qualified Meeting     | Event       | Type=Demo, Status=Completed          | $50/meeting  | $2,000/quarter |
| BDR  | SQL Created           | Opportunity | StageName=Qualified, CreatedById=BDR | $200/opp     | $5,000/quarter |
| BDR  | Calls Logged          | Task        | Type=Call, Status=Completed          | $5/call      | $500/month     |
| SDR  | Qualified Opportunity | Opportunity | StageName=Discovery, CreatedById=SDR | 2% of Amount | $3,000/quarter |

---

### 9.5 Clawback_Policy\_\_c (Clawback Treatment — NEW)

**Purpose:** Defines clawback rules per plan template. Separate child object because clawback policies can be complex (time-decayed, partial, conditional).

| #   | Field API Name                    | Type         | Label                          | Notes                                                                                                                                            |
| --- | --------------------------------- | ------------ | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `Plan_Template__c`                | MasterDetail | Plan Template                  | → Incentive_Plan_Template\_\_c                                                                                                                   |
| 2   | `Clawback_Type__c`                | Picklist     | Clawback Type                  | Full, Time_Decayed, Partial_Fixed, None                                                                                                          |
| 3   | `Trigger_Event__c`                | Picklist     | Trigger Event                  | Customer_Churn, Deal_Reversal, Contract_Cancellation, Revenue_Shortfall, Custom                                                                  |
| 4   | `Trigger_Source_Field__c`         | Text(100)    | Trigger Source                 | Which field/event triggers the clawback. e.g., "Opportunity.StageName" changing to "Closed Lost" post-close, or a custom "Churn_Date\_\_c" field |
| 5   | `Full_Recovery_Window_Days__c`    | Number(4,0)  | Full Recovery Window (Days)    | For Time_Decayed: 100% clawback within this window. e.g., 90 days                                                                                |
| 6   | `Partial_Recovery_Window_Days__c` | Number(4,0)  | Partial Recovery Window (Days) | For Time_Decayed: reduced % clawback within this window. e.g., 180 days                                                                          |
| 7   | `Partial_Recovery_Pct__c`         | Percent      | Partial Recovery %             | For Time_Decayed: what % is recovered in the partial window. e.g., 50%                                                                           |
| 8   | `Fixed_Recovery_Pct__c`           | Percent      | Fixed Recovery %               | For Partial_Fixed: always recover this %. e.g., 50%                                                                                              |
| 9   | `Grace_Period_Days__c`            | Number(4,0)  | Grace Period (Days)            | Days after close before clawback policy becomes active. e.g., 30 days (no clawback if churn in first month = trial period)                       |
| 10  | `Affects_Attainment__c`           | Checkbox     | Affects Attainment             | If true, clawback also reverses quota attainment. If false, only commission is recovered.                                                        |
| 11  | `Is_Active__c`                    | Checkbox     | Active                         |                                                                                                                                                  |

**Clawback calculation flow:**

```
TRIGGER: Customer churn / deal reversal detected
  1. Find all Comp_Calculation__c records for this transaction
  2. Determine days since original commission date
  3. Apply Clawback_Policy__c rules:
     - If within Full_Recovery_Window: recover 100%
     - If within Partial_Recovery_Window: recover Partial_Recovery_Pct
     - If beyond all windows: no recovery (commission is vested)
     - If within Grace_Period: no clawback at all
  4. Create Comp_Calculation__c record with Adjustment_Type = 'Clawback'
     Amount = negative (recovery amount)
  5. If Affects_Attainment: decrement Quota__c.Achieved_Amount__c
  6. Create Incentive_Change_Event__c for audit
  7. Notify participant: "Clawback processed: {amount} on {deal name} — {reason}"
```

---

### 9.6 Incentive_Plan_Template\_\_c — Restructured (Caps, Holds, Rate Structure as Child Objects)

**Problem:** V1.0 had caps, holds, and rate fields directly on the template. This limits flexibility — a plan might need multiple cap rules (per-transaction cap AND per-period cap AND per-OTE% cap) or multiple hold conditions.

**Solution:** Move caps and holds to child objects. Keep only the plan-level defaults on the template.

#### 9.6.1 Plan_Cap\_\_c (Cap Rule — Child of Template) — NEW

| #   | Field API Name     | Type         | Label            | Notes                                                              |
| --- | ------------------ | ------------ | ---------------- | ------------------------------------------------------------------ |
| 1   | `Plan_Template__c` | MasterDetail | Plan Template    | → Incentive_Plan_Template\_\_c                                     |
| 2   | `Cap_Type__c`      | Picklist     | Cap Type         | Per_Transaction, Per_Period, Per_Year, Pct_Of_OTE, Lifetime        |
| 3   | `Cap_Amount__c`    | Currency     | Cap Amount       | Dollar amount cap                                                  |
| 4   | `Cap_Pct__c`       | Percent      | Cap %            | Percentage cap (for Pct_Of_OTE)                                    |
| 5   | `Period_Scope__c`  | Picklist     | Period Scope     | Monthly, Quarterly, Annual (for Per_Period type)                   |
| 6   | `Description__c`   | Text(255)    | Description      | e.g., "No single deal can pay more than $50K"                      |
| 7   | `Is_Active__c`     | Checkbox     | Active           |                                                                    |
| 8   | `Sort_Order__c`    | Number(3,0)  | Evaluation Order | Caps evaluated in order; first cap that triggers limits the payout |

#### 9.6.2 Plan_Hold\_\_c (Hold Rule — Child of Template) — NEW

| #   | Field API Name       | Type         | Label                 | Notes                                                                              |
| --- | -------------------- | ------------ | --------------------- | ---------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`   | MasterDetail | Plan Template         | → Incentive_Plan_Template\_\_c                                                     |
| 2   | `Hold_Type__c`       | Picklist     | Hold Type             | Collection_Hold, Milestone_Hold, Time_Hold, Approval_Hold, Custom                  |
| 3   | `Hold_Pct__c`        | Percent      | Hold %                | Percentage of commission held. 100% = full hold.                                   |
| 4   | `Release_Trigger__c` | Picklist     | Release Trigger       | Automatic_On_Collection, Automatic_On_Date, Automatic_On_Milestone, Manual_Admin   |
| 5   | `Release_Days__c`    | Number(4,0)  | Release After (Days)  | For Time_Hold: release after N days                                                |
| 6   | `Release_Field__c`   | Text(100)    | Release Trigger Field | For Automatic triggers: which field to monitor. e.g., "Payment_Received_Date\_\_c" |
| 7   | `Description__c`     | Text(255)    | Description           | e.g., "Hold 30% until customer payment received"                                   |
| 8   | `Is_Active__c`       | Checkbox     | Active                |                                                                                    |
| 9   | `Sort_Order__c`      | Number(3,0)  | Evaluation Order      |                                                                                    |

#### 9.6.3 Updated Incentive_Plan_Template\_\_c (Fields Removed)

Remove from template (moved to child objects):

- ~~`Cap_Amount__c`~~ → Plan_Cap\_\_c
- ~~`Cap_Pct_of_OTE__c`~~ → Plan_Cap\_\_c
- ~~`Cap_Per_Transaction__c`~~ → Plan_Cap\_\_c
- ~~`Hold_Pct__c`~~ → Plan_Hold\_\_c
- ~~`Hold_Type__c`~~ → Plan_Hold\_\_c
- ~~`Hold_Release_Trigger__c`~~ → Plan_Hold\_\_c
- ~~`Base_Rate_Pct__c`~~ → keep as default, but Commission_Tier**c is the authoritative rate source. For Flat plans, a single Commission_Tier**c with Min=0%, Max=null handles it.
- ~~`Base_Rate_Amount__c`~~ → same, move to Commission_Tier\_\_c

**Remaining on template after restructuring:**

| #     | Field API Name         | Type         | Notes                                                                    |
| ----- | ---------------------- | ------------ | ------------------------------------------------------------------------ |
| 1-6   | Identity fields        |              | Unchanged (Name, Description, Plan_Year, Industry, Library, Cloned_From) |
| 7-9   | Plan Type & Trigger    |              | Unchanged (Plan_Type, Trigger_Type, Commissionable_Value_Override)       |
| 10    | `Is_Retroactive__c`    | Checkbox     | Default retroactivity for tiers                                          |
| 11-12 | Payment fields         |              | Unchanged (Payment_Frequency, Deferred_Payment)                          |
| 13    | `Vesting_Schedule__c`  | LongTextArea | Kept on template (vesting is plan-level, not per-cap/hold)               |
| 14-15 | Attainment fields      |              | Unchanged (Attainment_Period, Attainment_Metric)                         |
| 16-19 | Penalty & Multi-Period |              | Unchanged                                                                |
| 20-21 | Eligibility            |              | **Changed from JSON to Multi-Select Picklist (see below)**               |
| 22-23 | Dependent Template     |              | Unchanged                                                                |
| 24-29 | Recurring              |              | Unchanged                                                                |
| 30-35 | Lifecycle              |              | Unchanged                                                                |

#### 9.6.4 Eligibility Fields — JSON → Multi-Select Picklist

**Problem:** JSON arrays for Eligible_Roles and Eligible_Transaction_Categories are bad UX. Admin has to type JSON. No validation.

**Solution:** Multi-Select Picklist. Values are the role codes and category codes.

| Old                                                    | New                                                                                                           |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `Eligible_Roles__c` LongTextArea JSON                  | `Eligible_Roles__c` MultiselectPicklist. Values populated from Participant_Role**c.Role_Code**c.              |
| `Eligible_Transaction_Categories__c` LongTextArea JSON | `Eligible_Categories__c` MultiselectPicklist. Values populated from Transaction_Category**c.Category_Code**c. |

**Sync requirement (same pattern as Forecast_Category picklist sync):**

- When a new Participant_Role**c is created, its Role_Code is added to the Eligible_Roles**c picklist values
- When a new Transaction_Category**c is created, its Category_Code is added to the Eligible_Categories**c picklist values
- Uses Metadata API async (same CategorySyncService pattern from Forecasting §9.3)

---

### 9.7 SaaS Template Enhancement — Global Roles

**Added to SaaS template library:**

| Template Name                       | Plan Type     | Trigger | Rate Structure                                    | Typical Roles                         |
| ----------------------------------- | ------------- | ------- | ------------------------------------------------- | ------------------------------------- |
| SaaS Global Engineer — Deal Support | Flat          | Booking | 0.5% of all deals globally                        | Global Engineer / Solutions Architect |
| SaaS RevOps VP — Global Override    | Team Override | Booking | 0.25% of total org bookings when org > 90% target | VP RevOps / VP Sales Ops              |
| SaaS Channel Partner — Sourced Deal | Flat          | Booking | 5% of partner-sourced deals                       | Channel Partner (external)            |

**New Participant_Role\_\_c field to support global roles:**

| #   | Field API Name | Type     | Label      | Notes                                                                                                                                                      |
| --- | -------------- | -------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 13  | `Scope__c`     | Picklist | Role Scope | Values: Deal_Level (earns on specific deals they're on), Team_Level (earns override on team production), Global (earns on all org deals matching category) |

Global scope means the eligibility engine includes this role on EVERY qualifying transaction, not just ones where they're referenced on the Opportunity.

---

### 9.8 Reprocessing — Updated (DP-I4 Resolved)

**Policy (per your feedback):**

> Projected commissions created at Opportunity close are **deleted and recreated** during reprocessing. Only **validated/finalized** calculations follow the reversal pattern.

**Calculation lifecycle states:**

| State         | Meaning                                                                         | On Reprocessing                                                                                                      |
| ------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Projected** | Created automatically when deal closes. Not yet validated by admin.             | **Deleted** and recalculated from scratch. No reversal records needed.                                               |
| **Validated** | Admin has reviewed and confirmed the calculation. May have been partially paid. | **Reversal** Comp_Calculation\_\_c created (negative amount), then new Original created. Full audit trail preserved. |
| **Paid**      | Payment has been issued to participant.                                         | **Reversal** with clawback/adjustment processing. May trigger draw balance update.                                   |

**New field on Comp_Calculation\_\_c:**

| #   | Field API Name          | Type                | Label              | Notes                                                  |
| --- | ----------------------- | ------------------- | ------------------ | ------------------------------------------------------ |
| 35  | `Calculation_Status__c` | Restricted Picklist | Calculation Status | Values: Projected, Validated, Paid, Reversed, Clawback |

**Reprocessing flow:**

```
1. Admin triggers reprocessing for a transaction (or system detects change)
2. System checks Comp_Calculation__c records for this transaction:
   - If ALL are Projected → DELETE all, recalculate from scratch
   - If ANY are Validated or Paid → create Reversal records, then recalculate
3. New Comp_Calculation__c records created with Calculation_Status = Projected
4. Admin validates → Status changes to Validated
5. Monthly payout batch only processes Validated records
```

---

### 9.9 Decision Points — Resolved

| DP        | Decision                                                              |
| --------- | --------------------------------------------------------------------- |
| **DP-I1** | **Custom Object** for Participant_Role\_\_c                           |
| **DP-I2** | **Custom Object** for Transaction_Category\_\_c                       |
| **DP-I3** | **Not for V1** — no Incentive_Snapshot\_\_c                           |
| **DP-I4** | **Projected = delete & recreate. Validated/Paid = reversal pattern.** |

---

### 9.10 Updated Object Count — Incentives Module (V1.1)

| Type                        | Count                 | Objects                                                                                                                                            |
| --------------------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Config objects              | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c                                                             |
| Template objects            | 6                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template**c, \*\*Plan_Cap**c** (NEW), **Plan_Hold**c** (NEW), **Clawback_Policy**c\*\* (NEW) |
| Value Mapping               | 1                     | **Commissionable_Value_Map\_\_c** (NEW)                                                                                                            |
| Activity Rules              | 1                     | **Activity_Commission_Rule\_\_c** (NEW)                                                                                                            |
| Assignment objects          | 2                     | Comp_Plan**c, Quota**c                                                                                                                             |
| Runtime/Ledger objects      | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c                                                            |
| Dispute                     | 1                     | Incentive_Dispute\_\_c                                                                                                                             |
| **Incentives Module Total** | **19 custom objects** |                                                                                                                                                    |
| Shared with Forecasting     | 1                     | Territory\_\_c                                                                                                                                     |

**Net change from V1.0:** +5 objects (Plan_Cap**c, Plan_Hold**c, Clawback_Policy**c, Commissionable_Value_Map**c, Activity_Commission_Rule\_\_c)

---

### 9.11 Updated Entity Relationship Diagram (V1.1)

```
Plan_Year__c
  └── Incentive_Plan_Template__c         (N — plan blueprints)
        ├── Commission_Tier__c           (N — rate tiers/bands)
        ├── Plan_Cap__c                  (N — cap rules: per-deal, per-period, per-OTE%)
        ├── Plan_Hold__c                 (N — hold rules: collection, milestone, time, approval)
        ├── Clawback_Policy__c           (N — clawback rules: full, time-decayed, partial)
        ├── Activity_Commission_Rule__c  (N — activity-based commission rules for BDR/SDR)
        ├── Quota_Template__c            (N — quota blueprints)
        │     └── Quota__c              (N — per participant per period)
        └── Comp_Plan__c                (N — per participant assignments)
              ├── Comp_Calculation__c    (N — immutable ledger; Status: Projected→Validated→Paid)
              │     └── Payment_Schedule__c (N — vesting installments)
              └── Commission_Draw__c    (N — draws/advances/paybacks)

Transaction_Category__c
  └── Commissionable_Value_Map__c        (N — maps Opp currency fields to commission value)

Incentive_Configuration__c               (1 — global settings)
Participant_Role__c                      (N — role definitions)
Incentive_Dispute__c                     (N — linked to Comp_Calculation__c)
Incentive_Change_Event__c                (N — immutable audit trail)
Territory__c                             (shared with Forecasting)
```

---

---

## 10. PLAN LIFECYCLE & ACCEPTANCE WORKFLOW

### 10.1 The Full Plan Lifecycle

A compensation plan goes through a multi-stage lifecycle before a single commission dollar is calculated. The V1.0/V1.1 model treated this as a simple Status picklist — it's actually a governance workflow involving multiple actors with different permissions.

```
PLAN DESIGN                    PLAN GOVERNANCE                PARTICIPANT ACCEPTANCE          RUNTIME
─────────────                  ─────────────────              ────────────────────────        ─────────

Comp Admin                     VP Sales / CFO /               Participant (Rep)               System
creates template               Exec Approvers
    │                              │                              │                             │
    ▼                              ▼                              ▼                             ▼
┌──────────┐   Submit for    ┌──────────┐    Approve      ┌──────────┐   Accept        ┌──────────────┐
│  DRAFT   │──────────────►  │  IN      │──────────────►  │ PUBLISHED│─────────────►   │   ACTIVE     │
│          │   Review        │  REVIEW  │                 │          │                  │ (calculating)│
└──────────┘                 └──────────┘                 └──────────┘                  └──────────────┘
    │                            │   │                        │   │                         │
    │ Edit                       │   │ Reject                 │   │ Dispute                 │ Close
    ▼                            │   ▼                        │   ▼                         ▼
┌──────────┐                     │ ┌──────────┐              │ ┌──────────┐           ┌──────────────┐
│  DRAFT   │◄────────────────────┘ │ REJECTED │              │ │ DISPUTED │           │   CLOSED     │
│ (revised)│                       │          │              │ │          │           │ (year-end)   │
└──────────┘                       └──────────┘              │ └──────────┘           └──────────────┘
                                                             │      │
                                                             │      │ Resolve
                                                             │      ▼
                                                             │ ┌──────────┐
                                                             └►│ PUBLISHED│ (re-send for acceptance)
                                                               │ (revised)│
                                                               └──────────┘
```

### 10.2 Lifecycle States

| State         | Who Acts                             | What Happens                                                                                                                                                           | Blocking?                                                                                      |
| ------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Draft**     | Comp Admin                           | Template being designed. Tiers, caps, holds, clawback rules being configured. Not visible to anyone outside admin team.                                                | Cannot assign to participants.                                                                 |
| **In Review** | Exec Approvers (VP Sales, CFO, HR)   | Template submitted for executive review. Approvers can view full plan details, run simulations, add comments. Multiple approvers can be required (serial or parallel). | Cannot assign. Cannot edit (locked for review).                                                |
| **Rejected**  | Exec Approvers → Comp Admin          | Approver rejects with reason. Plan returns to Draft for revision. Rejection reason and approver visible in audit trail.                                                | Returns to Draft.                                                                              |
| **Approved**  | System (auto on final approval)      | All required approvals received. Template locked from structural changes. Ready for publishing.                                                                        | Cannot edit tiers, rates, caps. Can still edit: effective dates, document URL, eligible roles. |
| **Published** | Comp Admin                           | Plan sent to participants for review and acceptance. Notification delivered per participant. Plan document (PDF or inline) accessible in participant portal.           | Commission processing gated by acceptance (if gate = Hard).                                    |
| **Disputed**  | Participant → Comp Admin             | Participant raises a plan dispute (disagrees with terms, quota, rate, territory). Dispute record created with reason. Admin reviews and resolves.                      | Acceptance blocked until dispute resolved.                                                     |
| **Active**    | System                               | All assigned participants have accepted (or acceptance gate = None/Soft). Commission calculation engine processes transactions against this plan.                      | Full runtime.                                                                                  |
| **Closed**    | Comp Admin / System (auto at FY end) | Plan year ended. No new calculations. Historical data preserved.                                                                                                       | Read-only.                                                                                     |

### 10.3 Plan_Approval\_\_c (Plan Approval Record — NEW)

**Purpose:** Tracks executive review and approval of plan templates before they can be published to participants.

| #   | Field API Name       | Type               | Label           | Notes                                                                                                   |
| --- | -------------------- | ------------------ | --------------- | ------------------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`   | Lookup             | Plan Template   | → Incentive_Plan_Template\_\_c                                                                          |
| 2   | `Approver__c`        | Lookup             | Approver        | → User                                                                                                  |
| 3   | `Approval_Order__c`  | Number(2,0)        | Approval Order  | For serial approval: 1 = first approver, 2 = second, etc. Null = parallel approval.                     |
| 4   | `Status__c`          | Picklist           | Status          | Pending, Approved, Rejected, Recalled                                                                   |
| 5   | `Submitted_By__c`    | Lookup             | Submitted By    | → User (Comp Admin who submitted for review)                                                            |
| 6   | `Submitted_On__c`    | DateTime           | Submitted On    |                                                                                                         |
| 7   | `Decided_On__c`      | DateTime           | Decided On      |                                                                                                         |
| 8   | `Comments__c`        | LongTextArea(5000) | Comments        | Approver's comments (required on rejection)                                                             |
| 9   | `Approval_Type__c`   | Picklist           | Approval Type   | Serial (must approve in order), Parallel (all approve independently), Any_One (first approval suffices) |
| 10  | `Reminder_Sent__c`   | Checkbox           | Reminder Sent   |                                                                                                         |
| 11  | `Escalation_Date__c` | DateTime           | Escalation Date | If not acted on by this date, escalate to next level                                                    |

**Approval flow:**

```
1. Comp Admin clicks "Submit for Review" on template
   → Template.Status changes from Draft → In_Review
   → Template becomes locked (no structural edits)
   → Plan_Approval__c records created for each configured approver

2. If Approval_Type = Serial:
   → Only Approval_Order = 1 is notified first
   → After #1 approves → #2 notified
   → Any rejection → entire chain stops, template returns to Draft

3. If Approval_Type = Parallel:
   → All approvers notified simultaneously
   → All must approve for plan to advance
   → Any rejection → template returns to Draft

4. If Approval_Type = Any_One:
   → All approvers notified
   → First approval advances the plan
   → Remaining approvals auto-cancelled

5. Escalation: if approver hasn't acted within N days (configurable),
   reminder notification sent. If still no action after escalation date,
   auto-escalate to approver's manager.
```

### 10.4 Plan_Acceptance\_\_c (Participant Acceptance Record — NEW)

**Purpose:** Tracks each participant's review and acceptance of their assigned compensation plan. One record per Comp_Plan\_\_c (plan assignment).

| #   | Field API Name                      | Type                | Label                  | Notes                                                                                                                                                                                                          |
| --- | ----------------------------------- | ------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Comp_Plan__c`                      | MasterDetail        | Plan Assignment        | → Comp_Plan\_\_c                                                                                                                                                                                               |
| 2   | `Participant__c`                    | Lookup              | Participant            | → User                                                                                                                                                                                                         |
| 3   | `Status__c`                         | Picklist            | Status                 | Pending_Review, Reviewed, Accepted, Declined, Disputed, Expired                                                                                                                                                |
| 4   | `Sent_On__c`                        | DateTime            | Sent On                | When the plan was published/sent to participant                                                                                                                                                                |
| 5   | `First_Viewed_On__c`                | DateTime            | First Viewed           | When participant first opened the plan document                                                                                                                                                                |
| 6   | `Accepted_On__c`                    | DateTime            | Accepted On            |                                                                                                                                                                                                                |
| 7   | `Acceptance_Method__c`              | Picklist            | Acceptance Method      | In_Platform_Click, In_Platform_Signature, DocuSign, AdobeSign, HelloSign, Other_External                                                                                                                       |
| —   | **In-Platform Acceptance Evidence** |                     |                        |                                                                                                                                                                                                                |
| 8   | `Acceptor_IP_Address__c`            | Text(50)            | IP Address             | Captured at time of acceptance click. For legal audit.                                                                                                                                                         |
| 9   | `Acceptor_User_Agent__c`            | Text(500)           | User Agent             | Browser/device info at acceptance.                                                                                                                                                                             |
| 10  | `Acceptor_Geolocation__c`           | Text(100)           | Geolocation            | Approximate location if available (optional, consent-based).                                                                                                                                                   |
| 11  | `Acceptance_Statement__c`           | LongTextArea(2000)  | Acceptance Statement   | The exact legal text the participant agreed to. Frozen at acceptance time — cannot change retroactively. e.g., "I acknowledge and accept the terms of the Enterprise AE Accelerated Plan FY2027 as presented." |
| 12  | `Signature_Data__c`                 | LongTextArea(32000) | Signature Data         | For In_Platform_Signature: base64-encoded signature image captured via canvas. Null for click-to-accept.                                                                                                       |
| —   | **eSignature Integration**          |                     |                        |                                                                                                                                                                                                                |
| 13  | `External_Envelope_Id__c`           | Text(100)           | eSignature Envelope ID | DocuSign/AdobeSign envelope ID for tracking                                                                                                                                                                    |
| 14  | `External_Signing_URL__c`           | Url                 | Signing URL            | Deep link to the external signing ceremony                                                                                                                                                                     |
| 15  | `External_Signed_Document_URL__c`   | Url                 | Signed Document URL    | Link to the completed signed document stored externally                                                                                                                                                        |
| 16  | `External_Provider__c`              | Picklist            | eSignature Provider    | DocuSign, AdobeSign, HelloSign, PandaDoc, None                                                                                                                                                                 |
| —   | **Dispute**                         |                     |                        |                                                                                                                                                                                                                |
| 17  | `Dispute_Reason__c`                 | LongTextArea(5000)  | Dispute Reason         | If participant declines/disputes: their stated reason                                                                                                                                                          |
| 18  | `Dispute_Resolved_On__c`            | DateTime            | Dispute Resolved       |                                                                                                                                                                                                                |
| 19  | `Dispute_Resolution__c`             | LongTextArea(5000)  | Resolution Notes       | Admin's response to the dispute                                                                                                                                                                                |
| 20  | `Dispute_Resolved_By__c`            | Lookup              | Resolved By            | → User                                                                                                                                                                                                         |
| —   | **Expiration**                      |                     |                        |                                                                                                                                                                                                                |
| 21  | `Expires_On__c`                     | DateTime            | Acceptance Deadline    | If participant doesn't accept by this date, status → Expired. Admin notified.                                                                                                                                  |
| 22  | `Reminder_Count__c`                 | Number(2,0)         | Reminders Sent         | How many reminder notifications have been sent                                                                                                                                                                 |
| 23  | `Last_Reminder_On__c`               | DateTime            | Last Reminder Sent     |                                                                                                                                                                                                                |

### 10.5 Acceptance Workflow Detail

```
PUBLISH:
  Comp Admin clicks "Publish Plan" on approved template
  → For each Comp_Plan__c assignment linked to this template:
     → Create Plan_Acceptance__c record (Status = Pending_Review)
     → Send notification to participant (in-app + email)
     → Set Expires_On based on config (default: 14 days)

PARTICIPANT REVIEW:
  Participant opens "My Plans" in the self-service portal
  → Sees plan details: template name, rate structure, tiers, quota, territory, OTE
  → Plan document (PDF) viewable inline or downloadable
  → First_Viewed_On timestamped on first open
  → Options: [Accept Plan] [Decline / Dispute] [Download PDF]

ACCEPTANCE (In-Platform):
  Option A — Click-to-Accept:
    Participant clicks [Accept Plan]
    → Confirmation dialog shows acceptance statement text
    → Participant checks "I agree" checkbox and clicks [Confirm]
    → System captures: IP address, user agent, timestamp, acceptance statement text
    → Plan_Acceptance__c.Status → Accepted
    → Comp_Plan__c.Plan_Acceptance_Status__c → Accepted
    → Notification to admin

  Option B — In-Platform Signature:
    Participant clicks [Sign Plan]
    → Canvas-based signature pad appears
    → Participant draws signature + clicks [Submit Signature]
    → System captures: signature data (base64), IP, user agent, timestamp, statement
    → Same status flow as Option A

ACCEPTANCE (External eSignature):
  Comp Admin configures eSignature integration (DocuSign/AdobeSign/HelloSign)
  → On publish, system calls eSignature API:
     → Create envelope with plan document
     → Send to participant's email
     → Store External_Envelope_Id__c and External_Signing_URL__c
  → Participant receives email from eSignature provider
  → Signs in DocuSign/AdobeSign native UX
  → Webhook callback notifies platform:
     → Plan_Acceptance__c.Status → Accepted
     → External_Signed_Document_URL__c populated
     → Comp_Plan__c.Plan_Acceptance_Status__c → Accepted

DECLINE / DISPUTE:
  Participant clicks [Decline / Dispute]
  → Must provide Dispute_Reason (required text field)
  → Plan_Acceptance__c.Status → Disputed
  → Comp_Plan__c.Plan_Acceptance_Status__c → Disputed
  → Notification to admin: "Participant X has disputed their plan. Reason: {text}"
  → Admin reviews in Dispute Queue:
     → Can: modify plan terms (creates revised template version) + re-publish
     → Can: respond with explanation (resolution notes)
     → Can: override acceptance (admin-accept on behalf, with audit note)
  → On resolution: Plan_Acceptance__c.Status → Pending_Review (re-sent) or Accepted (admin override)

EXPIRATION:
  If Expires_On passes without acceptance:
  → Plan_Acceptance__c.Status → Expired
  → Notification to admin: "Participant X has not accepted plan. Deadline expired."
  → Admin can: extend deadline, re-send, or escalate

REMINDERS:
  Scheduled job checks Plan_Acceptance__c where:
    Status = Pending_Review
    AND days since Sent_On > reminder_interval (configurable, default: 3 days)
  → Send reminder notification
  → Increment Reminder_Count
  → Default cadence: Day 3, Day 7, Day 11, then daily until expiration
```

### 10.6 Acceptance Gate Enforcement

The gate is configured on the template (`Acceptance_Gate__c`):

| Gate     | Commission Processing                                                 | Admin Visibility                                                                    | Participant Experience                                         |
| -------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Hard** | Blocked until participant accepts. No Projected calculations created. | Dashboard shows "Awaiting acceptance: 12 participants" with names and days pending. | "You must accept your plan before commissions are calculated." |
| **Soft** | Processing proceeds normally. Admin notified of unsigned plans.       | Dashboard shows "Unsigned plans: 5" with warning badge.                             | "Please review and accept your plan." (non-blocking)           |
| **None** | Processing proceeds. No acceptance tracked.                           | No acceptance workflow — plan goes directly to Active on publish.                   | No acceptance required.                                        |

### 10.7 eSignature Configuration — Onboarding Discovery

**New Onboarding Question (added to §1.2):**

**Question 10: Plan Acceptance Method**

> How should participants accept their compensation plans?
>
> - [ ] **In-platform click-to-accept** — Participant clicks "I Accept" in RevenueTrust (simplest, no external integration needed)
> - [ ] **In-platform digital signature** — Participant draws a signature on a pad within RevenueTrust (better legal evidence)
> - [ ] **DocuSign** — Plans sent via DocuSign for signing (requires DocuSign account)
> - [ ] **AdobeSign** — Plans sent via Adobe Acrobat Sign (requires Adobe account)
> - [ ] **HelloSign** — Plans sent via HelloSign / Dropbox Sign
> - [ ] **Other provider** — we'll integrate via webhook (provide API details later)
> - [ ] **No acceptance required** — Plans are informational only; no signature needed

### 10.8 eSignature_Provider\_\_c (eSignature Configuration — NEW if external provider selected)

**Purpose:** Stores integration credentials and configuration for the selected eSignature provider. One record per configured provider.

| #   | Field API Name           | Type        | Label                 | Notes                                                                           |
| --- | ------------------------ | ----------- | --------------------- | ------------------------------------------------------------------------------- |
| 1   | Name                     | Text(80)    | Provider Name         | "DocuSign Production", "AdobeSign"                                              |
| 2   | `Provider_Type__c`       | Picklist    | Provider              | DocuSign, AdobeSign, HelloSign, PandaDoc, Custom_Webhook                        |
| 3   | `Named_Credential__c`    | Text(100)   | Named Credential      | Salesforce Named Credential API name for auth. Keeps secrets out of the object. |
| 4   | `Callback_URL__c`        | Text(500)   | Webhook Callback URL  | Platform-generated URL that the provider calls on signature completion          |
| 5   | `Template_Id__c`         | Text(100)   | Provider Template ID  | If the provider has a pre-configured envelope template                          |
| 6   | `Default_Expiry_Days__c` | Number(3,0) | Default Expiry (Days) | How long the signing request is valid. Default: 14.                             |
| 7   | `Reminder_Days__c`       | Text(50)    | Reminder Schedule     | Comma-separated days for provider-side reminders. e.g., "3,7,11"                |
| 8   | `Is_Active__c`           | Checkbox    | Active                |                                                                                 |
| 9   | `Last_Tested_On__c`      | DateTime    | Last Connection Test  | Admin can test the integration; timestamp stored.                               |
| 10  | `Test_Status__c`         | Picklist    | Test Status           | Not_Tested, Success, Failed                                                     |

### 10.9 Updated Template Status Field

The `Incentive_Plan_Template__c.Status__c` restricted picklist needs expanded values:

**Old:** Draft, Active, Archived  
**New:** Draft, In_Review, Rejected, Approved, Published, Active, Closed, Archived

### 10.10 Updated Comp_Plan\_\_c Acceptance Fields

The existing `Plan_Acceptance_Status__c` on Comp_Plan**c (§3.8 field 16) is now a **summary/cache** of the linked Plan_Acceptance**c record status. It's updated by trigger whenever Plan_Acceptance**c.Status changes. The Plan_Acceptance**c record is the source of truth for acceptance details.

Remove from Comp_Plan**c (moved to Plan_Acceptance**c):

- ~~`Plan_Accepted_Date__c`~~ → now on Plan_Acceptance**c.Accepted_On**c
- ~~`Plan_Accepted_Method__c`~~ → now on Plan_Acceptance**c.Acceptance_Method**c

Keep on Comp_Plan\_\_c as cache:

- `Plan_Acceptance_Status__c` — cached from Plan_Acceptance\_\_c.Status (for list view filtering and reports without joins)

---

### 10.11 Updated Object Count — Incentives Module (V1.2)

| Type                        | Count                 | Objects                                                                                                          |
| --------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Config objects              | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c                           |
| Template objects            | 6                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template**c, Plan_Cap**c, Plan_Hold**c, Clawback_Policy**c |
| Value Mapping               | 1                     | Commissionable_Value_Map\_\_c                                                                                    |
| Activity Rules              | 1                     | Activity_Commission_Rule\_\_c                                                                                    |
| Assignment objects          | 2                     | Comp_Plan**c, Quota**c                                                                                           |
| **Plan Governance (NEW)**   | **3**                 | **Plan_Approval**c, Plan_Acceptance**c, eSignature_Provider\_\_c**                                               |
| Runtime/Ledger objects      | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c                          |
| Dispute                     | 1                     | Incentive_Dispute\_\_c                                                                                           |
| **Incentives Module Total** | **22 custom objects** |                                                                                                                  |
| Shared with Forecasting     | 1                     | Territory\_\_c                                                                                                   |

**Net change from V1.1:** +3 objects (Plan_Approval**c, Plan_Acceptance**c, eSignature_Provider\_\_c)

---

### 10.12 Updated Entity Relationship Diagram (V1.2)

```
Plan_Year__c
  └── Incentive_Plan_Template__c
        │   Status: Draft → In_Review → Rejected/Approved → Published → Active → Closed
        │
        ├── Commission_Tier__c           (N — rate tiers)
        ├── Plan_Cap__c                  (N — cap rules)
        ├── Plan_Hold__c                 (N — hold rules)
        ├── Clawback_Policy__c           (N — clawback rules)
        ├── Activity_Commission_Rule__c  (N — activity-based rules)
        ├── Quota_Template__c            (N — quota blueprints)
        │     └── Quota__c              (N — per participant per period)
        │
        ├── Plan_Approval__c             (N — exec approval records)  ◄── NEW
        │
        └── Comp_Plan__c                (N — per participant assignments)
              │
              ├── Plan_Acceptance__c     (1 — participant acceptance record)  ◄── NEW
              │     └── {IP, User Agent, Signature, eSignature Envelope}
              │
              ├── Comp_Calculation__c    (N — immutable ledger)
              │     └── Payment_Schedule__c (N — vesting installments)
              └── Commission_Draw__c    (N — draws/advances/paybacks)

Transaction_Category__c
  └── Commissionable_Value_Map__c        (N — currency field mappings)

eSignature_Provider__c                   (0-1 — external signing integration)  ◄── NEW

Incentive_Configuration__c               (1 — global settings)
Participant_Role__c                      (N — role definitions)
Incentive_Dispute__c                     (N — linked to Comp_Calculation__c)
Incentive_Change_Event__c                (N — immutable audit trail)
Territory__c                             (shared with Forecasting)
```

---

---

## 11. V1.3 HARDENING PASS — ALL FEEDBACK + NEW REQUIREMENTS

### 11.1 Critical Fix #1: Transaction_Category\_\_c — Clean Supersession

**Problem:** §3.4 still has `Commissionable_Value_Source__c`, `Commissionable_Value_Field__c`, `Commissionable_Value_Formula__c` — but §9.3 replaces them with `Commissionable_Value_Map__c`. Two competing value-resolution paths.

**Resolution:** §3.4 fields 6-8 are **SUPERSEDED by §9.3**. Authoritative Transaction_Category\_\_c field list:

| #   | Field API Name                        | Type        | Label                 | Notes                                                           |
| --- | ------------------------------------- | ----------- | --------------------- | --------------------------------------------------------------- |
| 1   | Name                                  | Text(80)    | Category Name         |                                                                 |
| 2   | `Category_Code__c`                    | Text(20)    | Category Code         | Unique. Immutable after data exists.                            |
| 3   | ~~`Record_Type_Developer_Name__c`~~   | —           | —                     | **SUPERSEDED by Category_Source fields (§9.2)**                 |
| 4   | `Stage_Filter__c`                     | Text(200)   | Stage Filter          | Default: "Closed Won"                                           |
| 5   | `Probability_Threshold__c`            | Percent     | Probability Threshold |                                                                 |
| 6   | ~~`Commissionable_Value_Source__c`~~  | —           | —                     | **SUPERSEDED by Commissionable_Value_Map\_\_c (§9.3)**          |
| 7   | ~~`Commissionable_Value_Field__c`~~   | —           | —                     | **SUPERSEDED**                                                  |
| 8   | ~~`Commissionable_Value_Formula__c`~~ | —           | —                     | **SUPERSEDED**                                                  |
| 9   | `Is_Active__c`                        | Checkbox    | Active                |                                                                 |
| 10  | `Sort_Order__c`                       | Number(3,0) | Display Order         |                                                                 |
| 11  | `Category_Source__c`                  | Picklist    | Category Source       | From §9.2: Record_Type, Picklist_Field, Custom_Field, All_Deals |
| 12  | `Category_Source_Field__c`            | Text(100)   | Source Field API Name |                                                                 |
| 13  | `Category_Source_Value__c`            | Text(200)   | Source Field Value(s) | Comma-separated                                                 |

**Net: 10 active fields** (3 removed, 3 added from §9.2).

---

### 11.2 Critical Fix #2: Incentive_Plan_Template\_\_c — Consolidated Field List

**Problem:** Fields scattered across §3.5 (41 fields), §9.6.3 (8 removed), §10.9 (status expanded). No single authoritative list.

**Authoritative Incentive_Plan_Template\_\_c field list (post all modifications):**

| #   | Field API Name                                             | Type                | Label                   | Notes                                                                                                   |
| --- | ---------------------------------------------------------- | ------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------- |
| —   | **Identity**                                               |                     |                         |                                                                                                         |
| 1   | Name                                                       | Text(80)            | Template Name           |                                                                                                         |
| 2   | `Description__c`                                           | LongTextArea(5000)  | Description             |                                                                                                         |
| 3   | `Plan_Year__c`                                             | Lookup              | Plan Year               | → Plan_Year\_\_c                                                                                        |
| 4   | `Industry__c`                                              | Picklist            | Industry                |                                                                                                         |
| 5   | `Is_Library_Template__c`                                   | Checkbox            | Library Template        | Read-only seed data. Admin clones.                                                                      |
| 6   | `Cloned_From__c`                                           | Lookup(self)        | Cloned From             |                                                                                                         |
| —   | **Plan Type & Trigger**                                    |                     |                         |                                                                                                         |
| 7   | `Plan_Type__c`                                             | Restricted Picklist | Plan Type               | Flat, Tiered, Accelerated, Gross_Margin, Recurring, Milestone, Activity_Based, Team_Pool, Team_Override |
| 8   | `Trigger_Type__c`                                          | Restricted Picklist | Commission Trigger      | Booking, Collection, Milestone, Revenue_Recognition, Renewal_Date, Activity, Monthly_Recurring          |
| 9   | `Commissionable_Value_Override__c`                         | Picklist            | Value Override          | Null = use Transaction_Category's Commissionable_Value_Map. Non-null overrides.                         |
| 10  | `Is_Retroactive__c`                                        | Checkbox            | Retroactive Tiers       | Default for child Commission_Tier\_\_c records                                                          |
| —   | **Payment**                                                |                     |                         |                                                                                                         |
| 11  | `Payment_Frequency__c`                                     | Picklist            | Payment Frequency       |                                                                                                         |
| 12  | `Deferred_Payment__c`                                      | Checkbox            | Deferred Payment        |                                                                                                         |
| 13  | `Vesting_Schedule__c`                                      | LongTextArea(500)   | Vesting Schedule        | JSON vesting installments                                                                               |
| —   | **Attainment**                                             |                     |                         |                                                                                                         |
| 14  | `Attainment_Period__c`                                     | Picklist            | Attainment Period       | Monthly, Quarterly, Semi_Annual, Annual                                                                 |
| 15  | `Attainment_Metric__c`                                     | Picklist            | Attainment Metric       | Primary, Secondary, Custom                                                                              |
| —   | **Penalties & Modifiers**                                  |                     |                         |                                                                                                         |
| 16  | `Penalty_Pct__c`                                           | Percent             | Short-Term Penalty %    |                                                                                                         |
| 17  | `Min_Term_Months__c`                                       | Number(3,0)         | Min Term for Penalty    |                                                                                                         |
| 18  | `Multi_Period_Bonus_Rate__c`                               | Percent             | Multi-Period Bonus Rate |                                                                                                         |
| 19  | `Multi_Period_Cap__c`                                      | Currency            | Multi-Period Cap        |                                                                                                         |
| —   | **Eligibility** _(see §11.5 for junction object redesign)_ |                     |                         |                                                                                                         |
| 20  | `Dependent_Template__c`                                    | Lookup(self)        | Dependent Template      |                                                                                                         |
| 21  | `Dependent_Threshold_Pct__c`                               | Percent             | Dependent Threshold     |                                                                                                         |
| —   | **Recurring / Trail**                                      |                     |                         |                                                                                                         |
| 22  | `Is_Recurring__c`                                          | Checkbox            | Recurring Commission    |                                                                                                         |
| 23  | `Recurring_Rate_Pct__c`                                    | Percent             | Recurring Rate %        |                                                                                                         |
| 24  | `Recurring_Duration_Months__c`                             | Number(3,0)         | Recurring Duration      |                                                                                                         |
| 25  | `Recurring_Cadence__c`                                     | Picklist            | Recurring Cadence       |                                                                                                         |
| —   | **Lifecycle**                                              |                     |                         |                                                                                                         |
| 26  | `Status__c`                                                | Restricted Picklist | Status                  | **Draft, In_Review, Rejected, Approved, Published, Active, Closed, Archived** (expanded per §10.9)      |
| 27  | `Effective_Start__c`                                       | Date                | Effective Start         |                                                                                                         |
| 28  | `Effective_End__c`                                         | Date                | Effective End           |                                                                                                         |
| 29  | `Acceptance_Gate__c`                                       | Picklist            | Acceptance Gate         | Hard, Soft, None                                                                                        |
| 30  | `Plan_Document_URL__c`                                     | Url                 | Plan Document           |                                                                                                         |
| 31  | `Is_Evergreen__c`                                          | Checkbox            | Evergreen               |                                                                                                         |

**Total: 31 fields.** (41 original − 8 removed to child objects − 2 eligibility picklists moved to junction objects = 31)

**Fields REMOVED (to child objects):**

- ~~Base_Rate_Pct**c, Base_Rate_Amount**c~~ → Commission_Tier\_\_c (base tier has Sort_Order=1)
- ~~Cap_Amount**c, Cap_Pct_of_OTE**c, Cap_Per_Transaction\_\_c~~ → Plan_Cap\_\_c
- ~~Hold_Pct**c, Hold_Type**c, Hold_Release_Trigger\_\_c~~ → Plan_Hold\_\_c
- ~~Eligible_Roles**c, Eligible_Categories**c~~ → Junction objects (see §11.5)

---

### 11.3 Critical Fix #3: Ledger Mutability Invariant

**Explicit rule (elevating what was implied):**

> **Comp_Calculation\_\_c mutability rules:**
>
> | Calculation_Status | Mutable?                               | Operations Allowed                                                                                                                                             |
> | ------------------ | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
> | **Projected**      | **Yes — provisional working records.** | May be deleted and recreated during reprocessing. May have Status changed to Validated. NOT included in payout runs. NOT included in audit/compliance reports. |
> | **Validated**      | **Immutable.**                         | Status may advance to Paid. No field changes allowed. Corrections create new Reversal records.                                                                 |
> | **Paid**           | **Immutable.**                         | No changes. Corrections create Reversal + new records.                                                                                                         |
> | **Reversed**       | **Immutable.**                         | Created by system as negative-amount counterpart. Cannot be modified.                                                                                          |
> | **Clawback**       | **Immutable.**                         | Created by Clawback_Policy processing. Cannot be modified.                                                                                                     |
>
> **The term "append-only immutable ledger" applies to Validated, Paid, Reversed, and Clawback records. Projected records are explicitly provisional and do not carry audit guarantees.**

---

### 11.4 Critical Fix #4: Picklist Value Governance

**Explicit invariants for all Multi-Select Picklists referencing code-based values:**

> 1. `Role_Code__c` and `Category_Code__c` are **immutable identifiers** once created. Labels may change. Codes cannot.
> 2. Inactive roles/categories are **hidden from selection** but retained in historical records. A Comp_Plan\_\_c with Eligible_Roles containing "SE" remains valid even if the SE role is deactivated — the plan just won't match new transactions.
> 3. **Shared PicklistSyncService** handles both Forecasting (category picklist) and Incentives (role/category picklists). Single Apex service, shared async Metadata API pattern from Forecasting §9.3.
> 4. 500-value Salesforce platform limit is not a concern for roles (unlikely >50) but noted for awareness on categories.

---

### 11.5 Eligibility: Multi-Select Picklist → Junction Objects

**Brainstorm resolution:** Your question is right — Multi-Select Picklists for eligibility have metadata sync complexity and are not the cleanest model. Junction objects are better for both modules.

**New: Template_Role_Eligibility\_\_c (Junction Object)**

| #   | Field API Name        | Type         | Label            | Notes                          |
| --- | --------------------- | ------------ | ---------------- | ------------------------------ |
| 1   | `Plan_Template__c`    | MasterDetail | Plan Template    | → Incentive_Plan_Template\_\_c |
| 2   | `Participant_Role__c` | MasterDetail | Participant Role | → Participant_Role\_\_c        |
| 3   | `Is_Active__c`        | Checkbox     | Active           | Default true                   |

**New: Template_Category_Eligibility\_\_c (Junction Object)**

| #   | Field API Name            | Type         | Label                | Notes                          |
| --- | ------------------------- | ------------ | -------------------- | ------------------------------ |
| 1   | `Plan_Template__c`        | MasterDetail | Plan Template        | → Incentive_Plan_Template\_\_c |
| 2   | `Transaction_Category__c` | MasterDetail | Transaction Category | → Transaction_Category\_\_c    |
| 3   | `Is_Active__c`            | Checkbox     | Active               | Default true                   |

**Benefits over Multi-Select Picklist:**

- No Metadata API sync needed — standard DML to add/remove eligibility
- Native related lists on both template and role/category records
- Admin can see "which templates is this role eligible for?" from the Participant_Role\_\_c record page
- Reports can join directly — no semi-join on multi-select values
- No 500-value limit
- Deactivation is a checkbox, not a picklist value removal

**Impact:** Remove `Eligible_Roles__c` and `Eligible_Categories__c` multi-select picklist fields from Incentive_Plan_Template\_\_c (already removed in §11.2). Also remove the PicklistSyncService requirement for these two fields (still needed for Forecast_Category picklist in Forecasting module).

**Forecasting module equivalent:** The Forecasting module should adopt the same pattern for any future role-based filtering. For V1, Forecasting doesn't have role-based eligibility on forecast templates, so no junction object needed there yet.

---

### 11.6 Critical Fix #5: Cross-Module Boundary Lock

**Explicit invariant (strengthening §1.6 from the main spec):**

> **Forecasting → Incentives (read-only enrichment):**
>
> - Forecasting MAY read: Quota**c (attainment), Comp_Plan**c (plan assignment), Commission_Tier\_\_c (rate tiers)
> - Forecasting MAY NOT write to any Incentives object
>
> **Incentives → Forecasting (advisory only):**
>
> - Incentives MAY read: Forecast_Override**c (pipeline projections), Close_Probability**c (AI probability)
> - Incentives MAY use forecast data for **advisory projections only** (payout forecasting, "what-if" scenarios)
> - Incentives MUST NOT use forecast AI probability or projected pipeline values as inputs to **actual commission calculations**. Commission triggers fire only on real events (deal close, collection received, milestone achieved) — never on forecasted probability.
>
> **The boundary:** Forecast data informs "what might happen." Commission data records "what did happen." These never mix in the calculation ledger.

---

### 11.7 Fix #6: Dispute Boundary Clarification

**Two distinct dispute objects, two distinct queues:**

| Object                                    | Dispute Type                                                                                                          | When It Occurs                                           | Who Raises  | Queue                            |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ----------- | -------------------------------- |
| **Plan_Acceptance\_\_c** (dispute fields) | **Plan-term dispute** — participant disagrees with plan design, quota, rate, territory assignment                     | Before plan is accepted. During the acceptance workflow. | Participant | Plan Acceptance Queue (admin)    |
| **Incentive_Dispute\_\_c**                | **Calculation/payment dispute** — participant disagrees with a specific commission calculation after it was processed | After commission is calculated and visible in portal.    | Participant | Commission Dispute Queue (admin) |

> These are different queues. A plan dispute is about "I don't agree with my plan terms." A calculation dispute is about "I was paid wrong on this specific deal." They should never be mixed in the same queue or workflow.

---

### 11.8 Fix #7: Territory\_\_c Definition

**Territory\_\_c is a RevenueTrust platform-owned abstraction object.** It is NOT a reference to the standard Territory2 object. It exists because:

- Not all orgs have Enterprise Territory Management enabled
- The platform needs its own territory hierarchy for scope grouping (Forecasting) and plan scoping (Incentives)
- The Hierarchy Sync job from Forecasting (§2.2) can populate it from ETM Territory2, but it can also be manually managed

**Territory\_\_c — Authoritative Field Definition:**

| #   | Field API Name            | Type         | Label                | Notes                                                                  |
| --- | ------------------------- | ------------ | -------------------- | ---------------------------------------------------------------------- |
| 1   | Name                      | Text(80)     | Territory Name       |                                                                        |
| 2   | `Territory_Code__c`       | Text(20)     | Territory Code       | Unique. Short code for matching.                                       |
| 3   | `Parent_Territory__c`     | Lookup(self) | Parent Territory     | Hierarchical nesting                                                   |
| 4   | `Region__c`               | Text(100)    | Region               | Top-level grouping                                                     |
| 5   | `Active__c`               | Checkbox     | Active               |                                                                        |
| 6   | `Source_Territory2_Id__c` | Text(18)     | Source Territory2 ID | If synced from ETM, tracks the original Territory2.Id for traceability |
| 7   | `Source_Type__c`          | Picklist     | Source               | ETM_Sync, Manual, Imported                                             |
| 8   | `Currency__c`             | Text(5)      | Local Currency       | ISO currency code for this territory                                   |
| 9   | `Description__c`          | Text(255)    | Description          |                                                                        |

**Optional:** Territory**c is only needed if the org uses territory-scoped plans or territory-based forecasting. Flat orgs with single-scope forecasting and role-based commission plans can skip it entirely. The platform works without any Territory**c records.

---

### 11.9 Mid-Year Role Switching

**Problem:** A participant changes roles mid-year. e.g., BDR promoted to AE in June. They need a different plan, different quota, different rate structure — but their YTD earnings and attainment history must be preserved.

**Policy:**

```
ROLE SWITCH: Participant moves from Role A → Role B mid-year

1. CLOSE OLD PLAN ASSIGNMENT
   → Comp_Plan__c (old).Status → Terminated
   → Comp_Plan__c (old).Effective_End → transfer date
   → All Projected Comp_Calculation__c on old plan: keep (earned before transfer)
   → Quota__c (old plan, future periods): Status → Closed (no longer active)
   → Quota__c (old plan, current period): leave active until period end
     (attainment earned before transfer counts)

2. CREATE NEW PLAN ASSIGNMENT
   → New Comp_Plan__c created from new role's active template
   → Effective_Start = transfer date
   → New Quota__c records generated for remaining periods
   → Attainment starts at 0 for new plan (clean slate)
   → OR: admin configures "carry forward attainment" (rare, but some orgs prorate)

3. PRORATION (configurable per Incentive_Configuration__c)
   → Quota proration: remaining periods × (days remaining / total period days)
   → Example: AE promoted June 15 in a quarterly plan.
     Q3 quota = full Q3 target × (77 days remaining / 92 total) = 83.7%
   → Admin can override proration manually

4. AUDIT TRAIL
   → Incentive_Change_Event__c: Change_Type = Role_Switch
   → Old_Value: {role: "BDR", plan: "BDR Flat FY2027"}
   → New_Value: {role: "AE", plan: "Enterprise AE Accelerated FY2027"}
   → Both old and new Comp_Plan__c records remain for historical reporting
```

**New field on Comp_Plan\_\_c:**

| #   | Field API Name        | Type         | Label            | Notes                                                                         |
| --- | --------------------- | ------------ | ---------------- | ----------------------------------------------------------------------------- |
| 21  | `Transferred_From__c` | Lookup(self) | Transferred From | → Comp_Plan\_\_c. Links new assignment to the old one it replaced. For audit. |
| 22  | `Proration_Pct__c`    | Percent      | Proration %      | If quota was prorated on role switch. Null = full quota.                      |

**New field on Incentive_Configuration\_\_c:**

| #   | Field API Name          | Type     | Label                    | Notes                                                                                                                     |
| --- | ----------------------- | -------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| 13  | `Role_Switch_Policy__c` | Picklist | Role Switch Quota Policy | Clean_Slate (new plan starts at 0), Carry_Forward (YTD attainment transfers), Prorated (quota adjusted by remaining time) |

---

### 11.10 Mid-Year Quota Adjustments

**Problem:** Company adjusts quotas mid-year due to external factors (COVID, recession, war, market shift). Could be org-wide, team-wide, or individual.

**Already supported by the model — but the workflow needs to be explicit:**

**Individual adjustment:** Admin edits `Quota__c.Adjustment_Amount__c` and provides `Adjustment_Reason__c`. This changes `Adjusted_Target__c` (formula). Immediate effect on attainment calculations.

**Bulk adjustment (org-wide or team-wide):**

```
BULK QUOTA ADJUSTMENT WORKFLOW:

1. Admin opens "Quota Adjustment" screen
2. Selects scope: Entire Org | Specific Territory | Specific Role | Individual
3. Selects periods affected: Current Period Only | Remaining Periods | All Periods in FY
4. Enters adjustment: Flat amount (+/- $X) OR Percentage (+/- X%) OR New target amount
5. Enters reason (required): "COVID-19 target reduction — Board approved March 15"
6. Preview: system shows before/after for all affected Quota__c records
7. Admin confirms → system updates all matching Quota__c.Adjustment_Amount__c records
8. Incentive_Change_Event__c created for each modified Quota__c:
   Change_Type = Quota_Adjustment
   Change_Context = {scope, reason, approved_by, bulk_adjustment_id}
9. Notification sent to affected participants:
   "Your Q3 FY2027 quota has been adjusted from $1,050,000 to $840,000. Reason: {text}"
10. Forecasting module cache refresh triggered (attainment % changes)
```

**New object: Quota_Adjustment_Batch\_\_c (Bulk Adjustment Tracker)**

| #   | Field API Name        | Type               | Label            | Notes                                                    |
| --- | --------------------- | ------------------ | ---------------- | -------------------------------------------------------- |
| 1   | Name                  | Auto-Number        | Adjustment ID    | QA-00001, QA-00002...                                    |
| 2   | `Scope__c`            | Picklist           | Scope            | Entire_Org, Territory, Role, Individual                  |
| 3   | `Scope_Filter__c`     | Text(255)          | Scope Filter     | Territory name, Role code, or User ID depending on scope |
| 4   | `Periods_Affected__c` | Picklist           | Periods Affected | Current_Period, Remaining_Periods, All_FY_Periods        |
| 5   | `Adjustment_Type__c`  | Picklist           | Adjustment Type  | Flat_Amount, Percentage, New_Target                      |
| 6   | `Adjustment_Value__c` | Number(18,2)       | Adjustment Value | +/- amount or %                                          |
| 7   | `Reason__c`           | LongTextArea(2000) | Reason           | Required                                                 |
| 8   | `Approved_By__c`      | Lookup             | Approved By      | → User                                                   |
| 9   | `Executed_On__c`      | DateTime           | Executed On      |                                                          |
| 10  | `Records_Affected__c` | Number(5,0)        | Quotas Affected  | Count of Quota\_\_c records modified                     |
| 11  | `Status__c`           | Picklist           | Status           | Pending_Approval, Executed, Rolled_Back                  |

---

### 11.11 Participant Exit Handling — Final Payment

**Problem:** When a participant leaves the organization, what happens to their unpaid commissions, projected commissions, draws, and future vesting installments?

**Exit Payment Policy (configurable per Incentive_Configuration\_\_c):**

```
PARTICIPANT EXIT WORKFLOW:

1. TRIGGER: Comp_Plan__c.Status set to Terminated (manual by admin or auto from HR integration)

2. IMMEDIATE ACTIONS:
   a. Lock all Comp_Plan__c assignments for this participant (no new calculations)
   b. Snapshot current state:
      - Total earned (Validated + Paid Comp_Calculation__c)
      - Total unpaid (Validated but not yet Paid)
      - Total projected (Projected Comp_Calculation__c — not yet validated)
      - Draw balance (outstanding draws to recover)
      - Vesting balance (scheduled but unpaid Payment_Schedule__c installments)

3. PROJECTED COMMISSIONS (deals not yet closed):
   Policy options (configurable):
   a. Forfeit — delete all Projected records. Rep earns nothing on open pipeline.
   b. Pay_Through_Close — if deal closes within N days of exit (configurable, default: 90),
      process normally. After N days, forfeit remaining.
   c. Pay_All — honor all projected commissions regardless of timing (rare, for senior exits)

4. VALIDATED UNPAID COMMISSIONS:
   Always paid. These are earned. Included in final payment.

5. DRAW BALANCE RECOVERY:
   If Draw_Policy = Recoverable:
     → Outstanding draw balance deducted from final payment
     → If final payment < draw balance: remaining balance written off OR sent to collections
       (configurable: Write_Off or Collections)
   If Draw_Policy = Non_Recoverable:
     → No recovery. Draw is the participant's to keep.

6. VESTING INSTALLMENTS:
   Policy options (configurable):
   a. Forfeit_Unvested — cancel all future Payment_Schedule__c installments.
      Only already-due installments are paid.
   b. Accelerate — pay all remaining installments in the final payment.
   c. Continue_Per_Schedule — continue paying on schedule even after exit
      (rare, for exec separation agreements).

7. FINAL PAYMENT GENERATION:
   System generates a Final_Payment_Summary:
   → Earned and validated: $X
   → Projected (per policy): $Y
   → Draw recovery: -$Z
   → Vesting (per policy): $W
   → Net final payment: $X + $Y - $Z + $W
   → Admin reviews and approves before processing
   → Payment_Detail__c or payroll export generated

8. AUDIT:
   → Incentive_Change_Event__c: Change_Type = Participant_Exit
   → All policy decisions recorded
   → Comp_Plan__c.Exit_Date__c and Exit_Policy_Applied__c populated
```

**New fields on Comp_Plan\_\_c:**

| #   | Field API Name              | Type        | Label                  | Notes                                                                        |
| --- | --------------------------- | ----------- | ---------------------- | ---------------------------------------------------------------------------- |
| 23  | `Exit_Date__c`              | Date        | Exit Date              | Date participant left (may differ from Effective_End for grace period deals) |
| 24  | `Exit_Policy__c`            | Picklist    | Exit Projected Policy  | Forfeit, Pay_Through_Close, Pay_All                                          |
| 25  | `Exit_Grace_Period_Days__c` | Number(3,0) | Exit Grace Period      | Days after exit that pipeline deals still qualify                            |
| 26  | `Exit_Vesting_Policy__c`    | Picklist    | Exit Vesting Policy    | Forfeit_Unvested, Accelerate, Continue_Per_Schedule                          |
| 27  | `Exit_Draw_Policy__c`       | Picklist    | Exit Draw Recovery     | Write_Off, Deduct_From_Final, Collections                                    |
| 28  | `Final_Payment_Approved__c` | Checkbox    | Final Payment Approved | Admin confirmation before final payout                                       |
| 29  | `Final_Payment_Amount__c`   | Currency    | Final Payment Amount   | Computed net amount                                                          |

**New fields on Incentive_Configuration\_\_c (defaults):**

| #   | Field API Name                     | Type        | Label                         | Notes                                     |
| --- | ---------------------------------- | ----------- | ----------------------------- | ----------------------------------------- |
| 14  | `Default_Exit_Projected_Policy__c` | Picklist    | Default Exit Projected Policy | Forfeit, Pay_Through_Close, Pay_All       |
| 15  | `Default_Exit_Grace_Days__c`       | Number(3,0) | Default Exit Grace Period     | Default: 90                               |
| 16  | `Default_Exit_Vesting_Policy__c`   | Picklist    | Default Exit Vesting Policy   | Forfeit_Unvested, Accelerate, Continue    |
| 17  | `Default_Exit_Draw_Recovery__c`    | Picklist    | Default Exit Draw Recovery    | Write_Off, Deduct_From_Final, Collections |

---

### 11.12 Pre-Built Calculation Templates

**Your brainstorming question:** Should we have pre-built calculation templates alongside industry plan templates?

**Yes.** The industry templates (§2.2) define the _business design_ of a plan (rate structure, tiers, eligibility). Calculation templates define the _computational pattern_ — how the engine processes a specific plan type. This helps customers understand "what will the system actually do?"

**Calculation_Template\_\_c (Pre-Built Calculation Pattern — NEW)**

| #   | Field API Name         | Type                | Label             | Notes                                                |
| --- | ---------------------- | ------------------- | ----------------- | ---------------------------------------------------- |
| 1   | Name                   | Text(80)            | Calculation Name  | e.g., "Standard Accelerated with Retroactive Uplift" |
| 2   | `Description__c`       | LongTextArea(5000)  | Description       | Plain-English explanation of the calculation         |
| 3   | `Plan_Type__c`         | Picklist            | Plan Type         | Which plan type this applies to                      |
| 4   | `Calculation_Steps__c` | LongTextArea(10000) | Calculation Steps | JSON or structured text: the step-by-step algorithm  |
| 5   | `Example_Scenario__c`  | LongTextArea(10000) | Example Scenario  | Worked example with numbers showing input → output   |
| 6   | `Industry__c`          | Picklist            | Industry          |                                                      |
| 7   | `Is_Library__c`        | Checkbox            | Library Template  | Shipped with package                                 |

**Pre-built calculation patterns shipped:**

| Pattern Name                  | Plan Type      | Algorithm Summary                                                                                                                                             |
| ----------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Flat Rate**                 | Flat           | `commission = commissionable_value × rate`. No tiers, no attainment.                                                                                          |
| **Tiered (Banded)**           | Tiered         | First $X at rate A, next $Y at rate B, remainder at rate C. Each band applied independently.                                                                  |
| **Accelerated (Retroactive)** | Accelerated    | Below quota: rate A on all deals. Cross quota: rate B retroactively applied to ALL deals in period. Crossing tier = retroactive uplift on prior transactions. |
| **Gross Margin**              | Gross_Margin   | `commission = (revenue - COGS) × rate`. Requires COGS/cost field mapping.                                                                                     |
| **Recurring / Trail**         | Recurring      | `monthly_commission = active_customer_value × trail_rate`. Runs monthly. Stops on churn or after duration.                                                    |
| **Activity Count**            | Activity_Based | `commission = qualifying_activity_count × rate_per_activity`. Capped at N activities per period.                                                              |
| **Team Override**             | Team_Override  | `commission = team_total_production × override_rate`. Only pays if team attainment > threshold.                                                               |
| **Team Pool**                 | Team_Pool      | `pool = team_production × pool_rate`. Distributed pro-rata by individual contribution %.                                                                      |
| **Milestone Staged**          | Milestone      | Payout split across milestones: X% at contract, Y% at go-live, Z% at 90-day retention.                                                                        |
| **Revenue Recognition**       | Rev_Rec        | Commission triggered by rev rec events, not booking. Spread across fiscal years per recognition schedule.                                                     |

Each template includes a **worked example** (Example_Scenario\_\_c) showing a real scenario with numbers — so an admin setting up their first plan can see exactly what the engine will do before going live.

---

### 11.13 Editorial Fixes

**§3.8 Comp_Plan\_\_c fields 17-18:** Marked as **SUPERSEDED by §10.10**. `Plan_Accepted_Date__c` and `Plan_Accepted_Method__c` removed from Comp_Plan**c; now on Plan_Acceptance**c.

**§3.8 Comp_Plan**c.Plan_Acceptance_Status**c (field 16):** Picklist values updated to match Plan_Acceptance**c.Status: **Not_Published, Pending_Review, Accepted, Disputed, Expired**. Cached from Plan_Acceptance**c by trigger.

**§3.10 Comp_Calculation\_\_c:** Header changed from "unchanged" to "**updated** — Calculation_Status\_\_c added per §9.8."

**§3.7 Quota_Template\_\_c field numbering:** Fields 8-19 are actually 12 individual Period_N_Target fields. Corrected numbering: Distribution_Method = field **20**, Status = **23**, Cloned_From = **24**. Total: 24 fields.

**§6 and §7 (stale ERD and object count):** Marked as **SUPERSEDED by §10.12** and **§11.14** respectively.

**Incentive_Change_Event\_\_c Change_Type values — expanded:**
Values: Status_Change, Rate_Override, Quota_Adjustment, Calculation_Processed, Draw_Created, Template_Cloned, Plan_Accepted, Plan_Terminated, Reprocessing, **Role_Switch**, **Participant_Exit**, **Bulk_Quota_Adjustment**

---

### 11.14 Final Object Count — Incentives Module (V1.3)

| Type                        | Count                 | Objects                                                                                                                                               |
| --------------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Config objects              | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c                                                                |
| Template objects            | 7                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template**c, Plan_Cap**c, Plan_Hold**c, Clawback_Policy**c, **Calculation_Template\_\_c** (NEW) |
| Eligibility junctions       | 2                     | **Template_Role_Eligibility\_\_c** (NEW), **Template_Category_Eligibility\_\_c** (NEW)                                                                |
| Value Mapping               | 1                     | Commissionable_Value_Map\_\_c                                                                                                                         |
| Activity Rules              | 1                     | Activity_Commission_Rule\_\_c                                                                                                                         |
| Assignment objects          | 2                     | Comp_Plan**c, Quota**c                                                                                                                                |
| Plan Governance             | 3                     | Plan_Approval**c, Plan_Acceptance**c, eSignature_Provider\_\_c                                                                                        |
| Bulk Operations             | 1                     | **Quota_Adjustment_Batch\_\_c** (NEW)                                                                                                                 |
| Runtime/Ledger objects      | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c                                                               |
| Dispute                     | 1                     | Incentive_Dispute\_\_c                                                                                                                                |
| **Incentives Module Total** | **26 custom objects** |                                                                                                                                                       |
| Shared                      | 1                     | Territory\_\_c (defined in §11.8)                                                                                                                     |

**Net change from V1.2:** +4 objects (Calculation_Template**c, Template_Role_Eligibility**c, Template_Category_Eligibility**c, Quota_Adjustment_Batch**c)

---

### 11.15 Final Entity Relationship Diagram (V1.3)

```
Plan_Year__c
  └── Incentive_Plan_Template__c
        │   Status: Draft → In_Review → Approved → Published → Active → Closed
        │
        ├── Commission_Tier__c              (N — rate tiers)
        ├── Plan_Cap__c                     (N — cap rules)
        ├── Plan_Hold__c                    (N — hold rules)
        ├── Clawback_Policy__c              (N — clawback rules)
        ├── Activity_Commission_Rule__c     (N — activity-based rules)
        ├── Template_Role_Eligibility__c    (N — junction: which roles eligible)  ◄── NEW
        │     └── Participant_Role__c
        ├── Template_Category_Eligibility__c (N — junction: which categories eligible)  ◄── NEW
        │     └── Transaction_Category__c
        │           └── Commissionable_Value_Map__c (N — currency field mappings)
        ├── Quota_Template__c               (N — quota blueprints)
        │     └── Quota__c                  (N — per participant per period)
        ├── Plan_Approval__c                (N — exec approval records)
        └── Comp_Plan__c                    (N — per participant assignments)
              ├── Plan_Acceptance__c         (1 — acceptance evidence + eSignature)
              ├── Comp_Calculation__c        (N — ledger: Projected→Validated→Paid)
              │     └── Payment_Schedule__c  (N — vesting installments)
              └── Commission_Draw__c        (N — draws/advances/paybacks)

Calculation_Template__c                    (N — pre-built calculation patterns)  ◄── NEW
Quota_Adjustment_Batch__c                  (N — bulk quota adjustment tracker)  ◄── NEW
eSignature_Provider__c                     (0-1 — external signing config)
Incentive_Configuration__c                 (1 — global settings + exit policies)
Incentive_Dispute__c                       (N — calculation/payment disputes)
Incentive_Change_Event__c                  (N — immutable audit trail)
Territory__c                               (shared — defined in §11.8)
```

---

---

## 12. V1.4 FINAL TIGHTENING — SPEC FREEZE PASS

### 12.1 Stale Section Supersession Labels

| Section                                            | Status         | Superseded By                                                                    |
| -------------------------------------------------- | -------------- | -------------------------------------------------------------------------------- |
| **§3.4** Transaction_Category\_\_c                 | ~~SUPERSEDED~~ | §11.1 (authoritative field list) + §9.2 (category source) + §9.3 (value mapping) |
| **§3.5** Incentive_Plan_Template\_\_c              | ~~SUPERSEDED~~ | §11.2 (authoritative 31-field list)                                              |
| **§3.7** Quota_Template\_\_c                       | ~~SUPERSEDED~~ | §12.3 (authoritative field list below)                                           |
| **§3.8** Comp_Plan\_\_c                            | ~~SUPERSEDED~~ | §12.2 (authoritative field list below)                                           |
| **§3.10** Comp_Calculation\_\_c "unchanged" header | ~~SUPERSEDED~~ | §9.8 adds Calculation_Status\_\_c. §11.3 defines mutability rules.               |
| **§6** ERD (V1.0)                                  | ~~SUPERSEDED~~ | §11.15 (final ERD)                                                               |
| **§7** Object Count (V1.0, 14 objects)             | ~~SUPERSEDED~~ | §11.14 (final count, 26 objects)                                                 |
| **§9.10** Object Count (V1.1, 19 objects)          | ~~SUPERSEDED~~ | §11.14                                                                           |
| **§9.11** ERD (V1.1)                               | ~~SUPERSEDED~~ | §11.15                                                                           |
| **§10.11** Object Count (V1.2, 22 objects)         | ~~SUPERSEDED~~ | §11.14                                                                           |
| **§10.12** ERD (V1.2)                              | ~~SUPERSEDED~~ | §11.15                                                                           |

---

### 12.2 Comp_Plan\_\_c — Authoritative Field List (Final)

| #   | Field API Name              | Type                | Label                  | Notes                                                                                         |
| --- | --------------------------- | ------------------- | ---------------------- | --------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`          | Lookup              | Plan Template          | → Incentive_Plan_Template\_\_c                                                                |
| 2   | `Plan_Year__c`              | Lookup              | Plan Year              | → Plan_Year\_\_c                                                                              |
| 3   | `Sales_Rep__c`              | Lookup              | Participant            | → User                                                                                        |
| 4   | `Participant_Role__c`       | Lookup              | Participant Role       | → Participant_Role\_\_c                                                                       |
| 5   | `Effective_Start__c`        | Date                | Effective Start        |                                                                                               |
| 6   | `Effective_End__c`          | Date                | Effective End          |                                                                                               |
| 7   | `Territory__c`              | Lookup              | Territory              | → Territory\_\_c (optional)                                                                   |
| 8   | `Entity__c`                 | Picklist            | Entity                 | Legal entity                                                                                  |
| 9   | `OTE__c`                    | Currency            | On-Target Earnings     | Per-participant (default from Role)                                                           |
| 10  | `Base_Pay__c`               | Currency            | Base Pay               |                                                                                               |
| 11  | `Variable_Compensation__c`  | Currency            | Variable Compensation  |                                                                                               |
| 12  | `Wage_Currency__c`          | Picklist            | Wage Currency          |                                                                                               |
| 13  | `Fx_Rate__c`                | Number(18,6)        | FX Rate                |                                                                                               |
| 14  | `Override_Base_Rate__c`     | Percent             | Override Base Rate     | Null = use template tier                                                                      |
| 15  | `Status__c`                 | Restricted Picklist | Assignment Status      | Draft, Active, On_Hold, Terminated                                                            |
| 16  | `Plan_Acceptance_Status__c` | Picklist            | Acceptance Status      | Not_Published, Pending_Review, Accepted, Disputed, Expired. Cached from Plan_Acceptance\_\_c. |
| 17  | `Cloned_From__c`            | Lookup(self)        | Cloned From            | Prior year assignment                                                                         |
| 18  | `Notes__c`                  | LongTextArea(5000)  | Admin Notes            |                                                                                               |
| 19  | `Transferred_From__c`       | Lookup(self)        | Transferred From       | Links new assignment to old on role switch (§11.9)                                            |
| 20  | `Proration_Pct__c`          | Percent             | Proration %            | Quota proration on role switch                                                                |
| 21  | `Exit_Date__c`              | Date                | Exit Date              | (§11.11)                                                                                      |
| 22  | `Exit_Policy__c`            | Picklist            | Exit Projected Policy  | Forfeit, Pay_Through_Close, Pay_All                                                           |
| 23  | `Exit_Grace_Period_Days__c` | Number(3,0)         | Exit Grace Period      |                                                                                               |
| 24  | `Exit_Vesting_Policy__c`    | Picklist            | Exit Vesting Policy    | Forfeit_Unvested, Accelerate, Continue_Per_Schedule                                           |
| 25  | `Exit_Draw_Policy__c`       | Picklist            | Exit Draw Recovery     | Write_Off, Deduct_From_Final, Collections                                                     |
| 26  | `Final_Payment_Approved__c` | Checkbox            | Final Payment Approved |                                                                                               |
| 27  | `Final_Payment_Amount__c`   | Currency            | Final Payment Amount   |                                                                                               |

**Total: 27 fields.** (Original 20 − 2 removed to Plan_Acceptance + 9 added for transfer/exit)

---

### 12.3 Quota_Template\_\_c — Authoritative Field List (Final)

| #    | Field API Name                                     | Type         | Label           | Notes                                                                                                  |
| ---- | -------------------------------------------------- | ------------ | --------------- | ------------------------------------------------------------------------------------------------------ |
| 1    | Name                                               | Text(80)     | Template Name   |                                                                                                        |
| 2    | `Plan_Template__c`                                 | Lookup       | Plan Template   | → Incentive_Plan_Template\_\_c (optional)                                                              |
| 3    | `Plan_Year__c`                                     | Lookup       | Plan Year       | → Plan_Year\_\_c                                                                                       |
| 4    | `Fiscal_Year__c`                                   | Text(10)     | Fiscal Year     |                                                                                                        |
| 5    | `Period_Type__c`                                   | Picklist     | Period Type     | Monthly, Quarterly, Semi_Annual, Annual                                                                |
| 6    | `Metric__c`                                        | Picklist     | Metric          | Primary, Secondary, Custom_1–4                                                                         |
| 7    | `Annual_Target__c`                                 | Currency     | Annual Target   |                                                                                                        |
| 8-19 | `Period_1_Target__c` through `Period_12_Target__c` | Currency     | Period N Target | 12 individual fields for period-level targets                                                          |
| 20   | `Distribution_Method__c`                           | Picklist     | Distribution    | Equal, Weighted, Custom                                                                                |
| 21   | `Territory__c`                                     | Lookup       | Territory       | → Territory\_\_c (optional)                                                                            |
| 22   | `Status__c`                                        | Picklist     | Status          | Draft, Active, Archived                                                                                |
| 23   | `Cloned_From__c`                                   | Lookup(self) | Cloned From     |                                                                                                        |
| 24   | `Eligible_Roles__c`                                | Text(500)    | Eligible Roles  | Comma-separated role codes (lightweight — not junction, since this is just filtering, not enforcement) |

**Total: 24 fields** (12 of which are Period_N_Target slots).

**Multi-granularity behavior:** When admin creates quotas from this template, the system generates Quota\_\_c records at ALL granularity levels per Forecasting §5.4.3:

- 1 Annual + 4 Quarterly + 12 Monthly = 17 Quota\_\_c records per participant (for expanded attainment layout)
- Monthly targets derived from Quarterly if Distribution_Method = Equal
- `Quota__c.Granularity__c` and `Quota__c.Parent_Quota__c` enable drill-down

---

### 12.4 PicklistSyncService — Updated Scope

**Correction:** §11.4 referenced a shared PicklistSyncService for both modules. Since §11.5 moved Incentives eligibility to junction objects, the service scope is now:

> **PicklistSyncService handles:**
>
> - **Forecasting module:** Forecast_Override**c.Forecast_Category**c restricted picklist ↔ Forecast_Category\_\_c records
> - **Incentives module:** Incentive_Plan_Template**c.Status**c restricted picklist values (shipped with package, expanded in V1.2)
>
> **No longer needed for Incentives:**
>
> - ~~Eligible_Roles\_\_c~~ → replaced by Template_Role_Eligibility\_\_c junction
> - ~~Eligible_Categories\_\_c~~ → replaced by Template_Category_Eligibility\_\_c junction

---

### 12.5 Calculation_Template**c → Incentive_Plan_Template**c Link

**Added:** Lookup from Incentive_Plan_Template**c to Calculation_Template**c so admins can navigate from "my plan" to "how it calculates."

**New field on Incentive_Plan_Template\_\_c (added to §11.2 authoritative list):**

| #   | Field API Name            | Type   | Label                | Notes                                                                                                                                                                 |
| --- | ------------------------- | ------ | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 32  | `Calculation_Template__c` | Lookup | Calculation Template | → Calculation_Template\_\_c. Links to the pre-built calculation pattern that describes this plan type's algorithm. Auto-populated when cloning from library template. |

**Updated Incentive_Plan_Template\_\_c field count: 32 fields** (31 from §11.2 + 1 new).

---

### 12.6 Consolidated Field Count (for AppExchange Security Review)

| Object                             | Fields   | Source Sections                                   |
| ---------------------------------- | -------- | ------------------------------------------------- |
| Incentive_Configuration\_\_c       | 17       | §3.1 (12) + §11.9 (1) + §11.11 (4)                |
| Plan_Year\_\_c                     | 7        | §3.2                                              |
| Participant_Role\_\_c              | 13       | §3.3 (12) + §9.7 (1: Scope)                       |
| Transaction_Category\_\_c          | 10       | §11.1 (authoritative)                             |
| Incentive_Plan_Template\_\_c       | 32       | §11.2 (31) + §12.5 (1: Calculation_Template link) |
| Commission_Tier\_\_c               | 10       | §3.6                                              |
| Quota_Template\_\_c                | 24       | §12.3 (authoritative)                             |
| Plan_Cap\_\_c                      | 8        | §9.6.1                                            |
| Plan_Hold\_\_c                     | 9        | §9.6.2                                            |
| Clawback_Policy\_\_c               | 11       | §9.5                                              |
| Activity_Commission_Rule\_\_c      | 10       | §9.4                                              |
| Template_Role_Eligibility\_\_c     | 3        | §11.5                                             |
| Template_Category_Eligibility\_\_c | 3        | §11.5                                             |
| Commissionable_Value_Map\_\_c      | 7        | §9.3                                              |
| Comp_Plan\_\_c                     | 27       | §12.2 (authoritative)                             |
| Quota\_\_c                         | 20       | §3.9                                              |
| Plan_Approval\_\_c                 | 11       | §10.3                                             |
| Plan_Acceptance\_\_c               | 23       | §10.4                                             |
| eSignature_Provider\_\_c           | 10       | §10.8                                             |
| Comp_Calculation\_\_c              | 35       | §3.10 (34) + §9.8 (1: Calculation_Status)         |
| Commission_Draw\_\_c               | 8        | §3.11                                             |
| Payment_Schedule\_\_c              | 8        | §3.13                                             |
| Incentive_Change_Event\_\_c        | 8        | §3.14                                             |
| Incentive_Dispute\_\_c             | 9        | §3.12                                             |
| Calculation_Template\_\_c          | 7        | §11.12                                            |
| Quota_Adjustment_Batch\_\_c        | 11       | §11.10                                            |
| Territory\_\_c                     | 9        | §11.8                                             |
| **TOTAL**                          | **~353** | 27 objects (26 Incentives + Territory shared)     |

**Combined with Forecasting module (224 fields across 12 objects): ~577 total custom fields across 39 objects.**
Well within Salesforce limits. Reasonable for ISV security review.

---

---

## 13. V1.5 — SPIFFs + Product/Category-Specific Rates

### 13.1 SPIFFs — Short-Run Incentive Programs

**What makes SPIFFs different from regular plans:**

| Dimension | Regular Plan                       | SPIFF                                                                                                                                              |
| --------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Duration  | Full fiscal year                   | Days to weeks (e.g., "March only", "Q4 last 2 weeks")                                                                                              |
| Overlaps  | One plan per role per year         | Multiple SPIFFs can stack on top of existing plans simultaneously                                                                                  |
| Target    | Broad (all qualifying deals)       | Narrow (specific products, deal types, deal sizes, regions)                                                                                        |
| Approval  | Annual exec review cycle           | Fast-track — VP/Director can launch within days                                                                                                    |
| Examples  | "Enterprise AE Accelerated FY2027" | "Double rate on Cloud Platform deals in March", "$500 bonus per Enterprise BDR-sourced deal this week", "3x rate on deals >$500K closed by Q4 end" |

**SPIFFs are modeled as a variant of Incentive_Plan_Template\_\_c** — not a separate object. This keeps the calculation engine unified. A SPIFF is a plan template with:

- `Plan_Type__c = 'SPIFF'`
- Short `Effective_Start__c` / `Effective_End__c` window
- Narrow eligibility (specific roles, categories, products)
- Stacks on top of existing plans (participant can have regular plan + N active SPIFFs)

#### 13.1.1 SPIFF-Specific Fields on Incentive_Plan_Template\_\_c

| #   | Field API Name           | Type     | Label            | Notes                                                                                                                                                                                             |
| --- | ------------------------ | -------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 33  | `Is_SPIFF__c`            | Checkbox | Is SPIFF         | True = short-run incentive program. Changes UI behavior and approval routing.                                                                                                                     |
| 34  | `SPIFF_Stacking__c`      | Picklist | SPIFF Stacking   | Values: Additive (SPIFF commission added on top of regular plan), Replacement (SPIFF rate replaces regular plan rate for qualifying deals), Bonus_Only (flat bonus per deal, no rate calculation) |
| 35  | `SPIFF_Budget__c`        | Currency | SPIFF Budget     | Total budget allocated for this SPIFF. When exhausted, SPIFF auto-deactivates. Null = unlimited.                                                                                                  |
| 36  | `SPIFF_Budget_Used__c`   | Currency | Budget Used      | Running total of commissions paid under this SPIFF. Rollup or trigger-maintained.                                                                                                                 |
| 37  | `SPIFF_Bonus_Amount__c`  | Currency | Bonus Per Deal   | For Bonus_Only stacking: flat dollar amount per qualifying deal. e.g., $500 per deal.                                                                                                             |
| 38  | `SPIFF_Approval_Type__c` | Picklist | Approval Routing | Fast_Track (VP can approve directly, skip exec chain), Standard (same as regular plan approval)                                                                                                   |

**Updated Incentive_Plan_Template**c.Plan_Type**c picklist:**
Add value: `SPIFF`

**Updated Incentive_Plan_Template\_\_c total: 38 fields** (32 from §11.2 + 6 SPIFF fields)

#### 13.1.2 SPIFF Calculation Logic

```
When a deal qualifies for commission processing:

1. Regular plan(s) process normally (existing flow — Steps 1-7 from §4)

2. ADDITIONALLY: check for active SPIFFs where:
   - Is_SPIFF = true AND Status = Active
   - Effective_Start ≤ transaction date ≤ Effective_End
   - Eligible roles include this participant's role
   - Eligible categories include this transaction's category
   - Product filter matches (if configured — see §13.2 Category_Rate_Override__c)
   - Budget not exhausted (SPIFF_Budget_Used < SPIFF_Budget, or budget is null)

3. For each qualifying SPIFF:
   IF SPIFF_Stacking = Additive:
     → Calculate SPIFF commission separately (using SPIFF's tiers/rate)
     → Create additional Comp_Calculation__c record with the SPIFF's Comp_Plan__c
     → Both regular and SPIFF commissions are paid

   IF SPIFF_Stacking = Replacement:
     → Use SPIFF's rate INSTEAD of regular plan rate for this deal
     → Only ONE Comp_Calculation__c created (at SPIFF rate)
     → Regular plan commission on this deal = $0 (replaced)

   IF SPIFF_Stacking = Bonus_Only:
     → Create Comp_Calculation__c with fixed SPIFF_Bonus_Amount (not rate-based)
     → Regular plan commission also pays normally
     → Bonus does NOT count toward quota attainment

4. Update SPIFF_Budget_Used__c
5. If SPIFF_Budget_Used >= SPIFF_Budget → auto-set SPIFF Status = Closed
```

#### 13.1.3 SPIFF Examples

| SPIFF Name               | Duration            | Stacking    | Target                            | Rate/Bonus                                                |
| ------------------------ | ------------------- | ----------- | --------------------------------- | --------------------------------------------------------- |
| "March Cloud Push"       | Mar 1-31            | Additive    | AEs only, Cloud Platform category | 2× the regular rate (additional tier at 2× base)          |
| "Q4 BDR Blitz"           | Dec 15-31           | Bonus_Only  | BDRs only, New Business           | $500 per qualified deal                                   |
| "Enterprise Accelerator" | Nov 1-Dec 31        | Replacement | AEs, deals >$500K                 | 15% flat (replaces normal tiered structure for big deals) |
| "Renewal Save"           | All Q3              | Additive    | CSMs, Renewal category            | +3% on top of regular renewal rate                        |
| "New Product Launch"     | 60 days from launch | Additive    | All roles, "Widget Pro" product   | 5% on Widget Pro deals (normally 0% for this product)     |

---

### 13.2 Category_Rate_Override\_\_c — Product/Deal-Type Specific Rates (NEW)

**Problem:** Commission_Tier\_\_c only varies by attainment level. In reality, the same AE plan might pay:

- 10% on Software
- 5% on Services
- 8% on Renewals
- 12% on New Business > $100K
- 0% on Internal Transfers

These are **rate overrides by transaction category or product** — independent of attainment.

**Why not just create separate plan templates per category?**
Because attainment is shared across all categories. An AE's quota attainment includes Software + Services + Renewals. The rate that applies depends on what they sold, but the tier they're in depends on total attainment. Separate plans would fragment attainment tracking.

**Solution: Category_Rate_Override**c (Child of Incentive_Plan_Template**c)**

| #   | Field API Name                | Type         | Label                    | Notes                                                                                                                                                 |
| --- | ----------------------------- | ------------ | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`            | MasterDetail | Plan Template            | → Incentive_Plan_Template\_\_c                                                                                                                        |
| 2   | `Override_Type__c`            | Picklist     | Override Type            | Transaction_Category, Product_Family, Product, Deal_Size, Custom_Field                                                                                |
| 3   | `Transaction_Category__c`     | Lookup       | Transaction Category     | → Transaction_Category\_\_c. For Override_Type = Transaction_Category.                                                                                |
| 4   | `Product_Family__c`           | Text(100)    | Product Family           | For Override_Type = Product_Family. Matches Product2.Family.                                                                                          |
| 5   | `Product_Id__c`               | Lookup       | Product                  | → Product2. For Override_Type = Product. Specific product SKU.                                                                                        |
| 6   | `Deal_Size_Min__c`            | Currency     | Min Deal Size            | For Override_Type = Deal_Size. Lower bound.                                                                                                           |
| 7   | `Deal_Size_Max__c`            | Currency     | Max Deal Size            | Upper bound. Null = unlimited.                                                                                                                        |
| 8   | `Custom_Field__c`             | Text(100)    | Custom Field API Name    | For Override_Type = Custom_Field. e.g., "Region\_\_c"                                                                                                 |
| 9   | `Custom_Field_Value__c`       | Text(200)    | Custom Field Value(s)    | Comma-separated matching values                                                                                                                       |
| 10  | `Rate_Pct__c`                 | Percent      | Override Rate %          | The rate for this category/product/size. Replaces the tier rate for qualifying deals.                                                                 |
| 11  | `Rate_Amount__c`              | Currency     | Override Rate ($)        | Flat amount alternative.                                                                                                                              |
| 12  | `Rate_Modifier__c`            | Picklist     | Rate Modifier            | Absolute (this rate replaces tier rate), Additive (added to tier rate), Multiplier (multiply tier rate by this value)                                 |
| 13  | `Counts_Toward_Attainment__c` | Checkbox     | Counts Toward Attainment | Whether deals matching this override count toward quota attainment. Default: true. False for things like "Internal Transfers pay 0% and don't count." |
| 14  | `Is_Active__c`                | Checkbox     | Active                   |                                                                                                                                                       |
| 15  | `Sort_Order__c`               | Number(3,0)  | Priority                 | When multiple overrides match the same deal, highest priority (lowest sort) wins.                                                                     |
| 16  | `Description__c`              | Text(255)    | Description              | Admin notes: "Services deals pay 5% flat regardless of attainment tier"                                                                               |

**Total: 16 fields.**

#### 13.2.1 How Category/Product Rate Overrides Work in the Calculation Engine

```
UPDATED Step 4 from §4 (Apply Rate Structure):

For each qualifying (Participant × Plan × Transaction):

  4a. Determine BASE rate from Commission_Tier__c:
      → Look up current attainment on Quota__c
      → Find matching tier (Min_Attainment ≤ attainment < Max_Attainment)
      → base_rate = tier.Rate_Pct

  4b. Check for Category_Rate_Override__c matches:
      → Query active overrides for this plan template
      → For each override, check if transaction matches:
         - Transaction_Category match?
         - Product_Family match? (from OpportunityLineItem.Product2.Family)
         - Product match? (from OpportunityLineItem.Product2Id)
         - Deal_Size match? (Amount between Min and Max)
         - Custom_Field match? (Opportunity.{field} IN values)
      → If match found (use highest priority if multiple):

         IF Rate_Modifier = Absolute:
           effective_rate = override.Rate_Pct  (tier rate ignored)
         IF Rate_Modifier = Additive:
           effective_rate = base_rate + override.Rate_Pct
         IF Rate_Modifier = Multiplier:
           effective_rate = base_rate × override.Rate_Pct

      → If no override matches:
           effective_rate = base_rate (normal tier rate)

  4c. Apply effective_rate to commissionable value
  4d. Record which override was applied (if any) in Comp_Calculation__c.Rate_Override_Applied__c
```

**New field on Comp_Calculation\_\_c:**

| #   | Field API Name             | Type      | Label                 | Notes                                                                                                                                                                     |
| --- | -------------------------- | --------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 36  | `Rate_Override_Applied__c` | Text(100) | Rate Override Applied | Name/description of the Category_Rate_Override\_\_c that modified the rate. Null if no override. For audit: "Services: 5% flat" or "Product Family 'Cloud': +2% additive" |

#### 13.2.2 Examples

**SaaS Company — AE Plan with category-specific rates:**

| Override                             | Type                 | Match             | Rate | Modifier                 | Attainment? |
| ------------------------------------ | -------------------- | ----------------- | ---- | ------------------------ | ----------- |
| "New Software at tier rate"          | Transaction_Category | New Business      | —    | (no override — use tier) | Yes         |
| "Services at 5% flat"                | Transaction_Category | Services          | 5%   | Absolute                 | Yes         |
| "Training at 2% flat"                | Transaction_Category | Training          | 2%   | Absolute                 | No          |
| "Internal Transfer — no commission"  | Transaction_Category | Internal Transfer | 0%   | Absolute                 | No          |
| "Cloud Platform premium"             | Product_Family       | Cloud             | +2%  | Additive                 | Yes         |
| "Enterprise deals >$500K bonus rate" | Deal_Size            | Min $500K         | +3%  | Additive                 | Yes         |

**Result:** An AE at Tier 2 (12% base) who closes:

- $200K New Business Software deal → 12% (tier rate, no override)
- $200K New Business Cloud deal → 14% (12% + 2% Cloud premium)
- $100K Services deal → 5% (absolute override, tier doesn't matter)
- $50K Training deal → 2% (absolute override, doesn't count toward attainment)
- $600K Enterprise Cloud deal → 17% (12% tier + 2% Cloud + 3% Enterprise size)

---

### 13.3 Updated Object Count — V1.5

| Type                        | Count                 | Objects                                                                                                                                     |
| --------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Config objects              | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c                                                      |
| Template objects            | 7                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template**c, Plan_Cap**c, Plan_Hold**c, Clawback_Policy**c, Calculation_Template\_\_c |
| **Rate Overrides (NEW)**    | **1**                 | **Category_Rate_Override\_\_c**                                                                                                             |
| Eligibility junctions       | 2                     | Template_Role_Eligibility**c, Template_Category_Eligibility**c                                                                              |
| Value Mapping               | 1                     | Commissionable_Value_Map\_\_c                                                                                                               |
| Activity Rules              | 1                     | Activity_Commission_Rule\_\_c                                                                                                               |
| Assignment objects          | 2                     | Comp_Plan**c, Quota**c                                                                                                                      |
| Plan Governance             | 3                     | Plan_Approval**c, Plan_Acceptance**c, eSignature_Provider\_\_c                                                                              |
| Bulk Operations             | 1                     | Quota_Adjustment_Batch\_\_c                                                                                                                 |
| Runtime/Ledger objects      | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c                                                     |
| Dispute                     | 1                     | Incentive_Dispute\_\_c                                                                                                                      |
| **Incentives Module Total** | **27 custom objects** |                                                                                                                                             |
| Shared                      | 1                     | Territory\_\_c                                                                                                                              |

**Net change from V1.4:** +1 object (Category_Rate_Override**c), +6 fields on Incentive_Plan_Template**c (SPIFF), +1 field on Comp_Calculation\_\_c (Rate_Override_Applied)

### 13.4 Updated Field Count

| Object                       | Fields    | Change from V1.4           |
| ---------------------------- | --------- | -------------------------- |
| Incentive_Plan_Template\_\_c | 38        | +6 (SPIFF fields)          |
| Category_Rate_Override\_\_c  | 16        | NEW                        |
| Comp_Calculation\_\_c        | 36        | +1 (Rate_Override_Applied) |
| All other objects            | unchanged |                            |
| **Incentives Module Total**  | **~376**  | +23 from V1.4              |

**Updated Platform Total:**

| Module                       | Objects             | Fields   |
| ---------------------------- | ------------------- | -------- |
| Forecasting                  | 12                  | 224      |
| Incentives                   | 28 (27 + Territory) | 376      |
| Deal Health + Behavior Intel | 15                  | 225      |
| Cross-Module (shared)        | 2                   | 26       |
| **PLATFORM TOTAL**           | **57**              | **~851** |

---

---

## 14. V1.6 — OPERATIONAL COMPLETENESS

### 14.1 Product-Based Commission Plans

**Problem:** Current model supports product-specific RATES within a plan (Category_Rate_Override\_\_c), but not standalone product-scoped plans. Example: "Pay 8% on Widget Pro to anyone who touches the deal — regardless of role, territory, or category."

**Solution:** Add a product eligibility dimension to the plan template. The `Template_Category_Eligibility__c` junction handles category eligibility. We need an equivalent for products.

#### Template_Product_Eligibility\_\_c (Junction — NEW)

| #   | Field API Name      | Type         | Label          | Notes                                                                                                             |
| --- | ------------------- | ------------ | -------------- | ----------------------------------------------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`  | MasterDetail | Plan Template  | → Incentive_Plan_Template\_\_c                                                                                    |
| 2   | `Product__c`        | Lookup       | Product        | → Product2. Specific product SKU.                                                                                 |
| 3   | `Product_Family__c` | Text(100)    | Product Family | Alternative to specific product — matches Product2.Family. One of Product or Family required, not both.           |
| 4   | `Is_Active__c`      | Checkbox     | Active         |                                                                                                                   |
| 5   | `Is_Required__c`    | Checkbox     | Required       | If true, deal MUST contain this product to qualify. If false, deal qualifies if it contains ANY eligible product. |

**How product eligibility works in the calculation engine:**

```
Updated Step 2 (Resolve Active Plans):

For each participant × plan template:
  a. Check role eligibility (Template_Role_Eligibility__c) ✓
  b. Check category eligibility (Template_Category_Eligibility__c) ✓
  c. NEW: Check product eligibility (Template_Product_Eligibility__c):
     - If NO product eligibility records exist → plan applies to all products (current behavior)
     - If product eligibility records exist:
       → Query OpportunityLineItems on the transaction
       → If ANY OLI.Product2Id or OLI.Product2.Family matches an active eligibility record → plan qualifies
       → If Is_Required = true on any eligibility record, that specific product MUST be present
  d. All three checks must pass for the plan to apply
```

**Product-only plan example:** "Widget Pro Commission — All Roles"

- Template_Role_Eligibility: ALL roles (or specific roles)
- Template_Category_Eligibility: ALL categories
- Template_Product_Eligibility: Product = "Widget Pro", Is_Required = true
- Result: plan only pays on deals containing Widget Pro, regardless of deal type

---

### 14.2 Windfall Deals — Commissionable Value Caps

**Problem:** Plan_Cap\_\_c caps the PAYOUT amount. But some orgs need to cap the COMMISSIONABLE VALUE before the rate is applied. "If deal > $3M, only count $3M toward commission."

**Solution:** Add commissionable value cap fields to Plan_Cap\_\_c.

**New Plan_Cap**c.Cap_Type**c values:**

| Cap Type                             | What It Caps                       | Example                                  |
| ------------------------------------ | ---------------------------------- | ---------------------------------------- |
| Per_Transaction (existing)           | Commission PAYOUT on a single deal | "No deal pays more than $50K commission" |
| Per_Period (existing)                | Total payout in a period           | "Max $200K commission per quarter"       |
| Per_Year (existing)                  | Total payout in fiscal year        |                                          |
| Pct_Of_OTE (existing)                | Total payout as % of OTE           | "Max 300% of variable"                   |
| **Commissionable_Value_Cap** (NEW)   | The VALUE before rate is applied   | "Only count first $3M of any deal"       |
| **Commissionable_Value_Floor** (NEW) | Minimum value to qualify           | "Deals under $10K don't earn commission" |

**New fields on Plan_Cap\_\_c:**

| #   | Field API Name          | Type     | Label                      | Notes                                                                                                                                                    |
| --- | ----------------------- | -------- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 9   | `Value_Cap_Amount__c`   | Currency | Commissionable Value Cap   | For Commissionable_Value_Cap: max value before rate applied. e.g., $3,000,000.                                                                           |
| 10  | `Value_Floor_Amount__c` | Currency | Commissionable Value Floor | For Commissionable_Value_Floor: deals below this don't qualify.                                                                                          |
| 11  | `Windfall_Treatment__c` | Picklist | Windfall Treatment         | What happens to the amount ABOVE the cap: Ignored (lost), Deferred_To_Next_Period (counts next period), Reduced_Rate (apply a lower rate to the excess). |
| 12  | `Windfall_Rate_Pct__c`  | Percent  | Windfall Reduced Rate      | For Reduced_Rate treatment: the rate on the excess amount above the cap.                                                                                 |

**Updated calculation engine Step 3 (Compute Commissionable Value):**

```
3a. Compute raw commissionable value (existing logic)
3b. NEW: Apply Commissionable_Value_Cap:
    IF raw_value > Value_Cap_Amount:
      commissionable_value = Value_Cap_Amount
      windfall_amount = raw_value - Value_Cap_Amount
      IF Windfall_Treatment = Deferred_To_Next_Period:
        → create deferred Comp_Calculation__c for next period
      IF Windfall_Treatment = Reduced_Rate:
        → create additional Comp_Calculation__c at Windfall_Rate_Pct on windfall_amount
      IF Windfall_Treatment = Ignored:
        → windfall_amount is not commissioned (logged for audit)
3c. NEW: Apply Commissionable_Value_Floor:
    IF raw_value < Value_Floor_Amount:
      → skip commission entirely for this deal
      → log as "Below commissionable floor" in Change Event
```

---

### 14.3 Quota Retirement Amount ≠ Commissionable Amount

**Problem:** Currently `Quota__c.Achieved_Amount__c` is incremented by the commissionable value. But in many orgs:

- Commission is calculated on full booking (TCV), but quota is measured on ACV
- Commission is on gross revenue, but quota credits net revenue
- Commission is on the deal amount, but quota credits a weighted value

**Solution:** Add a quota credit configuration to Category_Rate_Override**c and Transaction_Category**c.

**New fields on Transaction_Category\_\_c (added to §11.1 authoritative list):**

| #   | Field API Name           | Type      | Label               | Notes                                                                                                                            |
| --- | ------------------------ | --------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 14  | `Quota_Credit_Source__c` | Picklist  | Quota Credit Source | Same_As_Commissionable (default — quota and commission use same value), Custom_Field, Percentage_Of_Commissionable, Fixed_Amount |
| 15  | `Quota_Credit_Field__c`  | Text(100) | Quota Credit Field  | For Custom_Field: which Opportunity field. e.g., "ACV\_\_c" when commission is on TCV but quota credits ACV.                     |
| 16  | `Quota_Credit_Pct__c`    | Percent   | Quota Credit %      | For Percentage_Of_Commissionable: e.g., 80% means $100K commissionable deal credits $80K toward quota.                           |
| 17  | `Quota_Credit_Amount__c` | Currency  | Quota Credit Amount | For Fixed_Amount: flat amount credited regardless of deal size. Rare — used for activity-based quotas.                           |

**New fields on Comp_Calculation\_\_c:**

| #   | Field API Name           | Type     | Label               | Notes                                                                                                                 |
| --- | ------------------------ | -------- | ------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 37  | `Quota_Credit_Amount__c` | Currency | Quota Credit        | The amount credited toward quota for this calculation. May differ from Commisionable_Value\_\_c.                      |
| 38  | `Quota_Credit_Source__c` | Text(50) | Quota Credit Source | How quota credit was determined: "Same as commissionable", "ACV\_\_c field", "80% of commissionable", etc. For audit. |

**Updated calculation engine Step 6 (Update Attainment):**

```
6a. Determine quota credit:
    IF Transaction_Category.Quota_Credit_Source = Same_As_Commissionable:
      quota_credit = commissionable_value
    IF Quota_Credit_Source = Custom_Field:
      quota_credit = Opportunity.{Quota_Credit_Field}
    IF Quota_Credit_Source = Percentage_Of_Commissionable:
      quota_credit = commissionable_value × Quota_Credit_Pct
    IF Quota_Credit_Source = Fixed_Amount:
      quota_credit = Quota_Credit_Amount

6b. Also check Category_Rate_Override.Counts_Toward_Attainment (§13.2):
    IF override.Counts_Toward_Attainment = false:
      quota_credit = 0

6c. Store quota_credit on Comp_Calculation__c.Quota_Credit_Amount__c
6d. Increment Quota__c.Achieved_Amount__c by quota_credit (not commissionable_value)
```

**Example:** AE closes $500K TCV deal. Commission calculated on $500K (full TCV). But only $120K ACV credits toward quarterly quota.

- `Comp_Calculation__c.Commisionable_Value__c` = $500,000
- `Comp_Calculation__c.Quota_Credit_Amount__c` = $120,000
- `Quota__c.Achieved_Amount__c` incremented by $120,000

---

### 14.4 Calculation Trace for UI — Step-by-Step Display

**Purpose:** The rep portal and admin dashboard must show exactly HOW a commission was calculated — every step, every input, every rate decision. This is the #1 competitor pain point ("reps can't trace why they got paid").

**New object: Calculation_Trace**c (Child of Comp_Calculation**c)**

| #   | Field API Name               | Type         | Label          | Notes                                                                                                                                                                        |
| --- | ---------------------------- | ------------ | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `Comp_Calculation__c`        | MasterDetail | Calculation    | → Comp_Calculation\_\_c                                                                                                                                                      |
| 2   | `Step_Number__c`             | Number(2,0)  | Step           | 1 through N                                                                                                                                                                  |
| 3   | `Step_Name__c`               | Text(100)    | Step Name      | "Identify Transaction", "Compute Commissionable Value", "Apply Rate Tier", "Apply Override", "Apply Cap", "Apply Hold", "Net Commission"                                     |
| 4   | `Input_Description__c`       | Text(500)    | Input          | Human-readable: "Deal Amount: $500,000. Transaction Category: New Business. Commissionable Value Source: Full Amount."                                                       |
| 5   | `Calculation_Description__c` | Text(500)    | Calculation    | "Commissionable Value ($500,000) × Rate Tier 'Accelerator' (12%) = $60,000"                                                                                                  |
| 6   | `Output_Amount__c`           | Currency     | Output Amount  | The amount after this step                                                                                                                                                   |
| 7   | `Rule_Applied__c`            | Text(200)    | Rule Applied   | Which config record governed this step. e.g., "Commission Tier: Accelerator (100-150%, 12%)", "Plan Cap: Per-Transaction $50,000", "Category Override: Services 5% Absolute" |
| 8   | `Before_Amount__c`           | Currency     | Amount Before  | Amount entering this step                                                                                                                                                    |
| 9   | `After_Amount__c`            | Currency     | Amount After   | Amount leaving this step                                                                                                                                                     |
| 10  | `Is_Reduction__c`            | Checkbox     | Reduces Amount | True if this step reduced the commission (cap, hold, penalty)                                                                                                                |

**Example trace for a single Comp_Calculation\_\_c:**

| Step | Name                   | Input                                                                     | Calculation                                              | Before   | After    | Rule                                          |
| ---- | ---------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------- | -------- | -------- | --------------------------------------------- |
| 1    | Transaction Identified | Deal: Acme Corp. Category: New Business. Close Date: Apr 15.              | Record Type matched. Stage = Closed Won.                 | —        | —        | Transaction_Category: New Business            |
| 2    | Commissionable Value   | Deal Amount: $500K. Value Source: Full Amount.                            | Full booking value used.                                 | —        | $500,000 | Commissionable_Value_Map: Amount field        |
| 3    | Value Cap Applied      | Commissionable cap: $3M. Deal: $500K.                                     | Below cap — no adjustment.                               | $500,000 | $500,000 | Plan_Cap: Commissionable_Value_Cap ($3M)      |
| 4    | Rate Tier Applied      | Attainment: 108%. Tier: Accelerator (100%+). Rate: 12%. Retroactive: Yes. | $500,000 × 12% = $60,000                                 | $500,000 | $60,000  | Commission_Tier: Accelerator (12%)            |
| 5    | Category Override      | Product Family: Cloud. Override: +2% Additive.                            | $500,000 × 2% = $10,000 additional                       | $60,000  | $70,000  | Category_Rate_Override: Cloud +2%             |
| 6    | Transaction Cap        | Per-transaction cap: $50,000. Commission: $70,000.                        | Capped at $50,000.                                       | $70,000  | $50,000  | Plan_Cap: Per_Transaction ($50K)              |
| 7    | Hold Applied           | Collection hold: 30%.                                                     | $50,000 × 30% = $15,000 held. Payable now: $35,000.      | $50,000  | $35,000  | Plan_Hold: Collection 30%                     |
| 8    | Quota Credit           | Quota source: ACV field. ACV: $120K.                                      | Quota credited: $120,000 (not the $500K commissionable). | —        | $120,000 | Transaction_Category: Quota_Credit = ACV\_\_c |
| 9    | Net Commission         | Final payable this cycle: $35,000. Held: $15,000. Total earned: $50,000.  | —                                                        | —        | $35,000  | —                                             |

**UI display:** The rep portal shows this as an expandable "How was this calculated?" panel per Comp_Calculation\_\_c record. Each step is a row with before/after amounts and the rule that was applied. Green for additions, red for reductions.

---

### 14.5 Incentive Dashboard Data Model Verification

**Does the current model support showing: Paid, Upcoming, Held, Clawbacks, Projected?**

| Dashboard Section                      | Data Source                                                                                           | Query Pattern                                                             |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| **Total Earned (YTD)**                 | `Comp_Calculation__c` WHERE Calculation_Status IN (Validated, Paid) AND Adjustment_Type = 'Original'  | SUM(Eligible_Commission\_\_c) − SUM of Reversal/Clawback records          |
| **Paid**                               | `Comp_Calculation__c` WHERE Calculation_Status = 'Paid'                                               | SUM(Eligible_Commission\_\_c) for Paid records                            |
| **Upcoming (validated, not yet paid)** | `Comp_Calculation__c` WHERE Calculation_Status = 'Validated' AND Commission_Paid_Date\_\_c = null     | Next payout cycle amount                                                  |
| **Held**                               | `Comp_Calculation__c` WHERE Hold_Reason\_\_c != null AND Calculation_Status IN (Projected, Validated) | SUM of held amounts. Each shows hold reason and release trigger.          |
| **Projected (not yet validated)**      | `Comp_Calculation__c` WHERE Calculation_Status = 'Projected'                                          | "If all projected deals close, you'll earn $X"                            |
| **Clawbacks**                          | `Comp_Calculation__c` WHERE Adjustment_Type = 'Clawback'                                              | Negative amounts. Shows original deal, clawback reason, time since close. |
| **Draws Outstanding**                  | `Commission_Draw__c` WHERE Rep = current user                                                         | Current draw balance. Upcoming payback schedule.                          |
| **Vesting Schedule**                   | `Payment_Schedule__c` WHERE Status IN (Scheduled, Due)                                                | Upcoming installments with dates and amounts.                             |
| **Next Month Projection**              | `Comp_Calculation__c` (Validated not Paid) + `Payment_Schedule__c` (Due next month) − Draw recovery   | Net expected next payout.                                                 |
| **Payout History**                     | `Comp_Calculation__c` WHERE Calculation_Status = 'Paid' GROUP BY payment month                        | Monthly/quarterly payout trend chart.                                     |

**Verdict:** The current model supports ALL dashboard sections. No new objects needed. The key fields are:

- `Calculation_Status__c` (Projected/Validated/Paid/Reversed/Clawback)
- `Hold_Reason__c` + Plan_Hold\_\_c for held amounts
- `Adjustment_Type__c` (Original/Amendment/Reversal/Clawback) for separating earned from adjusted
- `Commission_Paid_Date__c` for paid vs. unpaid
- `Payment_Schedule__c` for vesting/deferred installments

---

### 14.6 Payment Integration — Inbound (Customer Payments)

**Purpose:** Receive customer payment data to trigger collection-based commission holds, releases, and Rev Rec processing. Data arrives via API or file upload.

#### Customer_Payment\_\_c (Inbound Payment Record — NEW)

| #   | Field API Name         | Type      | Label             | Notes                                                                            |
| --- | ---------------------- | --------- | ----------------- | -------------------------------------------------------------------------------- |
| 1   | `Opportunity__c`       | Lookup    | Pipeline Record   | → Opportunity. Which deal this payment is for.                                   |
| 2   | `Account__c`           | Lookup    | Account           | → Account.                                                                       |
| 3   | `Payment_Amount__c`    | Currency  | Payment Amount    |                                                                                  |
| 4   | `Payment_Date__c`      | Date      | Payment Date      |                                                                                  |
| 5   | `Payment_Reference__c` | Text(100) | Payment Reference | Invoice number, check number, wire reference                                     |
| 6   | `Payment_Method__c`    | Picklist  | Payment Method    | Wire, Check, ACH, Credit_Card, Other                                             |
| 7   | `Currency_Code__c`     | Text(5)   | Currency          | ISO code                                                                         |
| 8   | `Collection_Pct__c`    | Percent   | Collection %      | Percentage of deal collected so far (cumulative). Used to trigger hold releases. |
| 9   | `Is_Full_Payment__c`   | Checkbox  | Full Payment      | True if this payment completes the deal (100% collected).                        |
| 10  | `Source__c`            | Picklist  | Data Source       | API, File_Upload, Manual, ERP_Integration                                        |
| 11  | `External_Id__c`       | Text(100) | External ID       | Unique ID from source system for deduplication.                                  |
| 12  | `Processing_Status__c` | Picklist  | Processing Status | Pending, Processed, Error, Duplicate                                             |
| 13  | `Processing_Notes__c`  | Text(500) | Processing Notes  | Error details if processing failed.                                              |
| 14  | `Batch_Id__c`          | Text(50)  | Batch ID          | Groups payments from same file upload or API batch.                              |

**Inbound flow:**

```
API endpoint: POST /services/apexrest/revenuetrust/payments
File upload: Admin uploads CSV/Excel via "Import Payments" LWC screen

For each Customer_Payment__c record:
  1. Match to Opportunity (by Opportunity__c lookup or External_Id mapping)
  2. Update cumulative Collection_Pct on related Comp_Calculation__c records
  3. Evaluate Plan_Hold__c rules:
     IF Hold_Type = Collection_Hold AND Collection_Pct >= Hold release threshold:
       → Release held commission amount
       → Update Comp_Calculation__c.Hold_Reason__c = null
       → Create Incentive_Change_Event__c (Change_Type = Hold_Released)
  4. For Rev Rec trigger plans: check if payment triggers revenue recognition
  5. Processing_Status → Processed (or Error with notes)
```

**File upload format (CSV):**

```
Opportunity_Id,Payment_Amount,Payment_Date,Payment_Reference,Payment_Method,Currency,External_Id
006xxxxxxxxxxxxx,50000.00,2027-04-15,INV-2027-0042,Wire,USD,PAY-2027-0042
```

Admin uploads → system validates → preview showing matches/unmatched → confirm → process.

---

### 14.7 Payment Integration — Outbound (Payroll Export)

**Purpose:** Generate payment files for payroll systems. Download as CSV/Excel or retrieve via API.

#### Payroll_Export\_\_c (Outbound Payment Batch — NEW)

| #   | Field API Name      | Type               | Label          | Notes                                                                                                                                         |
| --- | ------------------- | ------------------ | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Name                | Auto-Number        | Export ID      | PE-00001, PE-00002...                                                                                                                         |
| 2   | `Export_Date__c`    | Date               | Export Date    |                                                                                                                                               |
| 3   | `Period_Start__c`   | Date               | Period Start   | Payment period covered                                                                                                                        |
| 4   | `Period_End__c`     | Date               | Period End     |                                                                                                                                               |
| 5   | `Total_Amount__c`   | Currency           | Total Amount   | Sum of all line items                                                                                                                         |
| 6   | `Record_Count__c`   | Number(5,0)        | Record Count   | Number of participants in this export                                                                                                         |
| 7   | `Status__c`         | Picklist           | Status         | Draft, Approved, Exported, Confirmed, Error                                                                                                   |
| 8   | `Export_Format__c`  | Picklist           | Format         | CSV, Excel, JSON, ADP_Format, Workday_Format, Custom                                                                                          |
| 9   | `Approved_By__c`    | Lookup             | Approved By    | → User. Admin who approved the export.                                                                                                        |
| 10  | `Approved_On__c`    | DateTime           | Approved On    |                                                                                                                                               |
| 11  | `Exported_On__c`    | DateTime           | Exported On    | When the file was generated/downloaded                                                                                                        |
| 12  | `File_URL__c`       | Text(500)          | File URL       | Link to the generated file (ContentDocument or external storage)                                                                              |
| 13  | `Column_Mapping__c` | LongTextArea(5000) | Column Mapping | JSON: maps platform fields to payroll system's expected columns. e.g., {"Rep_Name": "Employee Name", "Eligible_Commission": "Payment Amount"} |
| 14  | `Notes__c`          | LongTextArea(2000) | Notes          |                                                                                                                                               |

#### Payroll_Export_Line\_\_c (Line Item per Participant — NEW)

| #   | Field API Name        | Type               | Label               | Notes                                                                          |
| --- | --------------------- | ------------------ | ------------------- | ------------------------------------------------------------------------------ |
| 1   | `Payroll_Export__c`   | MasterDetail       | Export Batch        | → Payroll_Export\_\_c                                                          |
| 2   | `Participant__c`      | Lookup             | Participant         | → User                                                                         |
| 3   | `Comp_Plan__c`        | Lookup             | Plan Assignment     | → Comp_Plan\_\_c                                                               |
| 4   | `Gross_Commission__c` | Currency           | Gross Commission    | Total earned this period                                                       |
| 5   | `Draw_Recovery__c`    | Currency           | Draw Recovery       | Amount deducted for draw payback                                               |
| 6   | `Hold_Amount__c`      | Currency           | Held Amount         | Amount held back per plan holds                                                |
| 7   | `Clawback_Amount__c`  | Currency           | Clawback Amount     | Clawback deductions this period                                                |
| 8   | `Net_Payable__c`      | Currency           | Net Payable         | Gross - Draw Recovery - Hold + Released Holds - Clawbacks                      |
| 9   | `Currency_Code__c`    | Text(5)            | Currency            |                                                                                |
| 10  | `Calculation_Ids__c`  | LongTextArea(5000) | Source Calculations | JSON array of Comp_Calculation\_\_c IDs included in this line. For drill-back. |
| 11  | `Employee_Id__c`      | Text(50)           | Employee ID         | From User or custom field — for payroll system matching                        |
| 12  | `Status__c`           | Picklist           | Status              | Included, Excluded, Adjusted                                                   |
| 13  | `Adjustment_Notes__c` | Text(500)          | Adjustment Notes    | If admin manually adjusted the line                                            |

**Outbound flow:**

```
Admin opens "Generate Payroll Export" screen:
  1. Select period (month/quarter)
  2. Select scope (all participants, specific territory, specific role)
  3. Select format (CSV, ADP, Workday, custom mapping)
  4. System queries all Comp_Calculation__c WHERE:
     Calculation_Status = 'Validated'
     AND Commission_Paid_Date__c = null
     AND within selected period
  5. Groups by participant
  6. For each participant:
     - Gross = SUM(Eligible_Commission__c) for Original/Amendment records
     - Draw recovery = MIN(gross, outstanding draw balance)
     - Holds = SUM of held amounts
     - Clawbacks = SUM of clawback records
     - Net = Gross - Draw - Holds - Clawbacks
  7. Creates Payroll_Export__c + Payroll_Export_Line__c records
  8. Admin reviews → Approves → Downloads file
  9. On download: Comp_Calculation__c records marked as Paid
     (Commission_Paid_Date = export date, Calculation_Status = Paid)
  10. Payroll_Export__c.Status → Exported

API endpoint: GET /services/apexrest/revenuetrust/payroll?period=2027-04&format=json
  → Returns same data as file export, for system-to-system integration
```

---

### 14.8 External Transaction Import

**Purpose:** For orgs where commissionable transactions don't live in Salesforce Opportunities (usage-based billing, external ERP, POS systems), provide a way to import transaction data for commission processing.

#### Imported_Transaction\_\_c (External Transaction — NEW)

| #   | Field API Name                 | Type         | Label                   | Notes                                                                      |
| --- | ------------------------------ | ------------ | ----------------------- | -------------------------------------------------------------------------- |
| 1   | Name                           | Auto-Number  | Transaction ID          | IT-00001, IT-00002...                                                      |
| 2   | `External_Id__c`               | Text(100)    | External ID             | Unique ID from source system. For dedup.                                   |
| 3   | `Transaction_Date__c`          | Date         | Transaction Date        |                                                                            |
| 4   | `Amount__c`                    | Currency     | Amount                  | Primary transaction value                                                  |
| 5   | `Currency_Code__c`             | Text(5)      | Currency                |                                                                            |
| 6   | `Transaction_Category_Code__c` | Text(20)     | Category Code           | Maps to Transaction_Category**c.Category_Code**c                           |
| 7   | `Participant_External_Id__c`   | Text(100)    | Participant External ID | Employee ID or email to match to User                                      |
| 8   | `Participant__c`               | Lookup       | Participant             | → User. Populated by matching logic.                                       |
| 9   | `Account_Name__c`              | Text(200)    | Customer/Account        |                                                                            |
| 10  | `Account__c`                   | Lookup       | Account                 | → Account. Optional match to SF Account.                                   |
| 11  | `Product_Name__c`              | Text(200)    | Product                 | For product-based commission matching                                      |
| 12  | `Product__c`                   | Lookup       | Product                 | → Product2. Optional match.                                                |
| 13  | `Quantity__c`                  | Number(10,2) | Quantity                | For volume-based commissions                                               |
| 14  | `Custom_Field_1__c`            | Text(500)    | Custom Field 1          | Flexible field for additional data from source system                      |
| 15  | `Custom_Field_2__c`            | Text(500)    | Custom Field 2          |                                                                            |
| 16  | `Custom_Field_3__c`            | Text(500)    | Custom Field 3          |                                                                            |
| 17  | `Source_System__c`             | Picklist     | Source System           | ERP, Billing, POS, Manual, API, File_Upload                                |
| 18  | `Batch_Id__c`                  | Text(50)     | Import Batch            | Groups records from same file/API call                                     |
| 19  | `Processing_Status__c`         | Picklist     | Processing Status       | Pending, Matched, Processed, Error, Duplicate                              |
| 20  | `Processing_Notes__c`          | Text(500)    | Processing Notes        | Match details, errors                                                      |
| 21  | `Opportunity__c`               | Lookup       | Linked Opportunity      | If this external transaction was matched/linked to an existing Opportunity |
| 22  | `Commission_Processed__c`      | Checkbox     | Commission Processed    | True after commission engine has processed this record                     |

**Import flow:**

```
API endpoint: POST /services/apexrest/revenuetrust/transactions
File upload: Admin uploads CSV/Excel via "Import Transactions" LWC screen

For each Imported_Transaction__c:
  1. Dedup by External_Id__c (skip duplicates)
  2. Match participant by Participant_External_Id__c → User (by Employee_Id, Email, or Federation_Id)
  3. Match category by Transaction_Category_Code__c → Transaction_Category__c
  4. Optionally match to existing Opportunity (if linked)
  5. If all matches succeed: Processing_Status → Matched
  6. Commission engine processes the record same as an Opportunity close:
     - Steps 1-7 of calculation engine
     - Imported_Transaction__c acts as the "pipeline record" instead of Opportunity
     - Comp_Calculation__c.Opportunity__c = null, but a new field links to the import:

New field on Comp_Calculation__c:
  39. Imported_Transaction__c (Lookup) — links to source imported transaction when commission is from external data
```

**File upload format (CSV):**

```
External_Id,Transaction_Date,Amount,Currency,Category_Code,Participant_Email,Account_Name,Product_Name,Quantity
ERP-2027-0042,2027-04-15,50000.00,USD,NEW,jsmith@acme.com,BigCo Inc,Widget Pro,100
```

---

### 14.9 Updated Object Count — V1.6

| Type                          | Count                 | Objects                                                                                                                                     |
| ----------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Config objects                | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c                                                      |
| Template objects              | 7                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template**c, Plan_Cap**c, Plan_Hold**c, Clawback_Policy**c, Calculation_Template\_\_c |
| Rate Overrides                | 1                     | Category_Rate_Override\_\_c                                                                                                                 |
| Eligibility junctions         | 3                     | Template_Role_Eligibility**c, Template_Category_Eligibility**c, **Template_Product_Eligibility\_\_c** (NEW)                                 |
| Value Mapping                 | 1                     | Commissionable_Value_Map\_\_c                                                                                                               |
| Activity Rules                | 1                     | Activity_Commission_Rule\_\_c                                                                                                               |
| Assignment objects            | 2                     | Comp_Plan**c, Quota**c                                                                                                                      |
| Plan Governance               | 3                     | Plan_Approval**c, Plan_Acceptance**c, eSignature_Provider\_\_c                                                                              |
| Bulk Operations               | 1                     | Quota_Adjustment_Batch\_\_c                                                                                                                 |
| Runtime/Ledger                | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c                                                     |
| **Calculation Audit (NEW)**   | **1**                 | **Calculation_Trace\_\_c**                                                                                                                  |
| Dispute                       | 1                     | Incentive_Dispute\_\_c                                                                                                                      |
| **Payment Integration (NEW)** | **4**                 | **Customer_Payment**c, Payroll_Export**c, Payroll_Export_Line**c, Imported_Transaction**c**                                                 |
| **Incentives Module Total**   | **33 custom objects** |                                                                                                                                             |
| Shared                        | 1                     | Territory\_\_c                                                                                                                              |

**Net change from V1.5:** +6 objects (Template_Product_Eligibility, Calculation_Trace, Customer_Payment, Payroll_Export, Payroll_Export_Line, Imported_Transaction)

### 14.10 Updated Field Count

| Object                            | Fields   | Change                                                              |
| --------------------------------- | -------- | ------------------------------------------------------------------- |
| Incentive_Plan_Template\_\_c      | 38       | unchanged (SPIFF fields from V1.5)                                  |
| Plan_Cap\_\_c                     | 12       | +4 (value cap, floor, windfall treatment, windfall rate)            |
| Transaction_Category\_\_c         | 17       | +4 (quota credit source, field, pct, amount) from §11.1 base 13     |
| Comp_Calculation\_\_c             | 39       | +3 (Quota_Credit_Amount, Quota_Credit_Source, Imported_Transaction) |
| Template_Product_Eligibility\_\_c | 5        | NEW                                                                 |
| Calculation_Trace\_\_c            | 10       | NEW                                                                 |
| Customer_Payment\_\_c             | 14       | NEW                                                                 |
| Payroll_Export\_\_c               | 14       | NEW                                                                 |
| Payroll_Export_Line\_\_c          | 13       | NEW                                                                 |
| Imported_Transaction\_\_c         | 22       | NEW                                                                 |
| **Incentives Module Total**       | **~457** | +81 from V1.5                                                       |

**Updated Platform Total:**

| Module                       | Objects             | Fields   |
| ---------------------------- | ------------------- | -------- |
| Forecasting                  | 12                  | 224      |
| Incentives                   | 34 (33 + Territory) | 457      |
| Deal Health + Behavior Intel | 15                  | 225      |
| Cross-Module (shared)        | 2                   | 26       |
| **PLATFORM TOTAL**           | **63**              | **~932** |

---

---

## 15. V1.7 FINAL HARDENING — SPEC FREEZE

### 15.1 Fix #1: Comp_Calculation\_\_c Responsibility Boundary

**Explicit invariant:**

> **Comp_Calculation\_\_c is the financial ledger record.** It stores only financially material data.
>
> - `Calculation_Trace__c` is the **explanation layer** — how the number was reached.
> - `Payroll_Export_Line__c` is the **payment/export layer** — when and how it was paid.
> - `Customer_Payment__c` is the **collection layer** — what the customer paid.
>
> **No additional operational state should be pushed into Comp_Calculation\_\_c unless it directly affects the financial amount or its auditability.** Reporting fields, UX convenience fields, and integration state belong on the appropriate companion object.

---

### 15.1.1 Comp_Calculation\_\_c — Authoritative Field List (Final)

The immutable financial ledger. Fields gathered from §3.10, §9.8, §13.2, §14.3, and §14.8.

| #   | Field API Name             | Type                | Label                    | Source | Notes                                                                  |
| --- | -------------------------- | ------------------- | ------------------------ | ------ | ---------------------------------------------------------------------- |
| 1   | `Comp_Plan__c`             | MasterDetail        | Incentive Plan           | §3.10  | → Comp_Plan\_\_c                                                       |
| 2   | `Opportunity__c`           | Lookup              | Transaction              | §3.10  | → Opportunity. Null if from imported transaction.                      |
| 3   | `Rep__c`                   | Lookup              | Participant              | §3.10  | → User                                                                 |
| 4   | `Commisionable_Value__c`   | Currency            | Commissionable Value     | §3.10  | Value the rate was applied to                                          |
| 5   | `Eligible_Commission__c`   | Currency            | Eligible Commission      | §3.10  | Resulting commission amount                                            |
| 6   | `Applied_Percentage__c`    | Percent             | Applied Rate %           | §3.10  |                                                                        |
| 7   | `Eligible_Rate_Ratio__c`   | Percent             | Eligible Rate Ratio      | §3.10  |                                                                        |
| 8   | `Quota_Category__c`        | Picklist            | Transaction Category     | §3.10  |                                                                        |
| 9   | `Comp_Plan_Type__c`        | Picklist            | Plan Type                | §3.10  |                                                                        |
| 10  | `Type__c`                  | Picklist            | Calculation Type         | §3.10  | Base, Accelerator, Adjustment, Clawback, Reversal, Recurring, Override |
| 11  | `Contract_Date2__c`        | Date                | Transaction Date         | §3.10  |                                                                        |
| 12  | `Commisionable_Date__c`    | Date                | Commissionable Date      | §3.10  |                                                                        |
| 13  | `Applicable_Date__c`       | Date                | Applicable Date          | §3.10  |                                                                        |
| 14  | `Processed_Date__c`        | Date                | Processed Date           | §3.10  |                                                                        |
| 15  | `Commission_Paid_Date__c`  | Date                | Payment Date             | §3.10  | Set only on Confirmed_Paid from payroll (§15.4)                        |
| 16  | `Region__c`                | Picklist            | Territory                | §3.10  |                                                                        |
| 17  | `Rep_Name__c`              | Text(100)           | Participant Name         | §3.10  | Denormalized for reporting                                             |
| 18  | `Rep_Category__c`          | Text(50)            | Participant Role         | §3.10  |                                                                        |
| 19  | `Rep_Active__c`            | Checkbox            | Participant Active       | §3.10  |                                                                        |
| 20  | `Hold_Reason__c`           | Picklist            | Hold Reason              | §3.10  |                                                                        |
| 21  | `Hold_Threshold__c`        | Percent             | Hold Threshold           | §3.10  |                                                                        |
| 22  | `Accelerators_Eligible__c` | Checkbox            | Release Payment          | §3.10  |                                                                        |
| 23  | `Accrued_Accelerators__c`  | Currency            | Accrued Accelerators     | §3.10  |                                                                        |
| 24  | `PCR__c`                   | Percent             | Collection %             | §3.10  |                                                                        |
| 25  | `Fx_Rate__c`               | Number(18,6)        | FX Rate                  | §3.10  |                                                                        |
| 26  | `Comments__c`              | TextArea(500)       | Internal Comments        | §3.10  |                                                                        |
| 27  | `No_Quota_Retirement__c`   | Checkbox            | No Quota Retirement      | §3.10  |                                                                        |
| 28  | `Additional_Info__c`       | Picklist            | Additional Info          | §3.10  |                                                                        |
| 29  | `Payment_Frequency__c`     | Text(50)            | Payment Frequency        | §3.10  |                                                                        |
| 30  | `Processing_Run_Id__c`     | Text(50)            | Processing Run ID        | §3.10  | Groups records from same run                                           |
| 31  | `Adjustment_Type__c`       | Picklist            | Adjustment Type          | §3.10  | Original, Amendment, Reversal, Clawback                                |
| 32  | `Attainment_Snapshot__c`   | Percent             | Attainment at Processing | §3.10  | Frozen at calculation time                                             |
| 33  | `Rate_Tier_Applied__c`     | Text(50)            | Rate Tier Applied        | §3.10  | Tier name                                                              |
| 34  | `Force_Recalc__c`          | Checkbox            | Force Recalculation      | §3.10  |                                                                        |
| 35  | `Calculation_Status__c`    | Restricted Picklist | Calculation Status       | §9.8   | Projected, Validated, Paid, Reversed, Clawback                         |
| 36  | `Rate_Override_Applied__c` | Text(100)           | Rate Override Applied    | §13.2  | Which Category_Rate_Override modified the rate                         |
| 37  | `Quota_Credit_Amount__c`   | Currency            | Quota Credit             | §14.3  | Amount credited to quota (may ≠ commissionable)                        |
| 38  | `Quota_Credit_Source__c`   | Text(50)            | Quota Credit Source      | §14.3  | How quota credit was determined                                        |
| 39  | `Imported_Transaction__c`  | Lookup              | Imported Transaction     | §14.8  | → Imported_Transaction\_\_c. Null if Opportunity-driven.               |

**Total: 39 fields.** Mutability rules per §11.3: Projected = mutable. Validated/Paid/Reversed/Clawback = immutable.

---

### 15.2 Fix #2: Eligibility + Rate Override Precedence Rules

**Evaluation order for a single transaction:**

```
STEP A: ELIGIBILITY EVALUATION (gate — all must pass)
  1. Category eligibility: Template_Category_Eligibility__c
     → Does this transaction's category match? If no → plan does not apply. STOP.

  2. Product eligibility: Template_Product_Eligibility__c
     → If NO product eligibility records exist → all products qualify (pass).
     → If records exist with Is_Required = true: ALL required products must be present on the deal.
     → If records exist with Is_Required = false: ANY one matching product suffices.
     → If required product missing → plan does not apply. STOP.

  3. Role eligibility: Template_Role_Eligibility__c
     → Does the participant's role match? If no → plan does not apply. STOP.

STEP B: COMMISSION SCOPE (which line items are commissionable)
  V1 rule: DEAL-LEVEL. Commission is calculated on the deal's total commissionable value,
  not split by line item. Product eligibility gates the DEAL, not individual line items.

  V2 consideration: Add Line_Item_Level option where each OLI is commissioned independently
  at its product-specific rate. Not V1 scope.

STEP C: RATE RESOLUTION (after eligibility passes)
  1. Base rate from Commission_Tier__c (attainment-based)
  2. Check Category_Rate_Override__c (sorted by Sort_Order — lowest first):
     → First matching override wins (highest priority)
     → Override applied per Rate_Modifier (Absolute, Additive, Multiplier)
  3. If no override matches → base tier rate applies
```

**Edge case from feedback:** Deal has Widget Pro + 3 other products, plan requires Widget Pro, rate override for "Cloud" family:

- Step A: Widget Pro present → eligibility passes ✓
- Step B: Deal-level — entire deal is commissionable
- Step C: Cloud family override found → applied to entire deal (deal-level, not per-product)

---

### 15.3 Fix #3: External Transaction Source-of-Truth Rule

**Explicit invariant:**

> **Comp_Calculation\_\_c must be sourced from exactly ONE transaction origin.** A commission is either:
>
> - **Opportunity-driven** (`Comp_Calculation__c.Opportunity__c` is populated, `Imported_Transaction__c` is null), OR
> - **Imported-transaction-driven** (`Comp_Calculation__c.Imported_Transaction__c` is populated, `Opportunity__c` is null)
> - **NEVER both.**
>
> **When an Imported_Transaction\_\_c is linked to an Opportunity:**
>
> - `Imported_Transaction__c.Opportunity__c` is populated (for reference/navigation)
> - `Imported_Transaction__c.Processing_Status__c` must be set to `Linked_To_Opportunity`
> - The commission engine processes the **Opportunity** (not the imported transaction)
> - The imported transaction becomes a reference record only — it does NOT generate its own commission
> - Validation rule on Comp_Calculation**c: if both Opportunity**c and Imported_Transaction\_\_c are non-null, reject the save
>
> **Dedup at import time:** When an imported transaction is matched to an Opportunity that already has Comp_Calculation\_\_c records, the system warns: "This transaction maps to Opportunity {name} which already has commission records. Processing skipped to prevent double-calculation."

---

### 15.4 Fix #4: Payroll Payment Status — 3-Stage Lifecycle

**Problem:** "Mark paid on download" is too aggressive. Downloading ≠ payroll processed.

**Updated Payroll_Export**c.Status**c picklist:**

| Old Values                                  | New Values                                                                                                                                                                                 |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Draft, Approved, Exported, Confirmed, Error | Draft, Approved, **Exported** (file generated/downloaded), **Sent_To_Payroll** (transmitted to payroll system), **Confirmed_Paid** (payroll confirmed success), Error, Partially_Confirmed |

**Updated flow:**

```
1. Admin generates export → Status = Draft
2. Admin reviews + approves → Status = Approved
3. Admin downloads file OR API retrieves data → Status = Exported
   → Comp_Calculation__c records: NO STATUS CHANGE (still Validated)
4. Admin confirms sent to payroll system → Status = Sent_To_Payroll
   → Comp_Calculation__c records: still Validated (not yet confirmed paid)
5. PAYMENT CONFIRMATION (one of three methods):
   a. Payroll provider sends confirmation via API callback
   b. Admin uploads confirmation file (CSV with employee IDs + amounts + confirmation)
   c. Admin clicks "Confirm Batch Paid" in UI
   → Status = Confirmed_Paid
   → NOW Comp_Calculation__c records marked Calculation_Status = Paid
   → Commission_Paid_Date set
```

**New object: Payroll_Confirmation\_\_c (Payment Confirmation — NEW)**

| #   | Field API Name           | Type               | Label             | Notes                                           |
| --- | ------------------------ | ------------------ | ----------------- | ----------------------------------------------- |
| 1   | `Payroll_Export__c`      | Lookup             | Payroll Export    | → Payroll_Export\_\_c being confirmed           |
| 2   | `Confirmation_Source__c` | Picklist           | Source            | API_Callback, File_Upload, Manual_Confirm       |
| 3   | `Confirmed_On__c`        | DateTime           | Confirmed On      |                                                 |
| 4   | `Confirmed_By__c`        | Lookup             | Confirmed By      | → User (for manual) or system (for API)         |
| 5   | `Total_Confirmed__c`     | Currency           | Total Confirmed   |                                                 |
| 6   | `Records_Confirmed__c`   | Number(5,0)        | Records Confirmed |                                                 |
| 7   | `Records_Failed__c`      | Number(5,0)        | Records Failed    | If payroll rejected some payments               |
| 8   | `Failure_Details__c`     | LongTextArea(5000) | Failure Details   | JSON: which participants/amounts failed and why |
| 9   | `Confirmation_File__c`   | Text(500)          | Confirmation File | ContentDocument link if file-uploaded           |
| 10  | `External_Batch_Id__c`   | Text(100)          | Payroll Batch ID  | Payroll system's batch reference                |

**API endpoints for payment confirmation:**

```
POST /services/apexrest/revenuetrust/payroll/confirm
Body: {
  "export_id": "PE-00042",
  "confirmed_records": [
    {"employee_id": "EMP001", "amount": 8400.00, "status": "paid"},
    {"employee_id": "EMP002", "amount": 5200.00, "status": "paid"},
    {"employee_id": "EMP003", "amount": 3100.00, "status": "failed", "reason": "invalid bank account"}
  ]
}

→ Creates Payroll_Confirmation__c record
→ For "paid" records: Comp_Calculation__c.Calculation_Status → Paid
→ For "failed" records: Comp_Calculation__c remains Validated, flagged for admin review
→ Payroll_Export__c.Status → Confirmed_Paid (or Partially_Confirmed if failures)
```

---

### 15.5 Fix #5: Hold Release — Partial Payment Semantics

**New field on Plan_Hold\_\_c:**

| #   | Field API Name             | Type     | Label               | Notes                                                                           |
| --- | -------------------------- | -------- | ------------------- | ------------------------------------------------------------------------------- |
| 10  | `Release_Mode__c`          | Picklist | Release Mode        | Binary_At_Threshold, Proportional, Milestone_Only                               |
| 11  | `Release_Threshold_Pct__c` | Percent  | Release Threshold % | For Binary: release 100% of hold when collection reaches this %. Default: 100%. |

**Release logic by mode:**

| Mode                    | Behavior                                                                                                                     | Example                                                                                                                           |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Binary_At_Threshold** | Hold is fully released (100%) when cumulative collection ≥ threshold. No partial release.                                    | 30% hold. Threshold = 100%. Customer pays 50% → hold stays. Customer pays remaining 50% (100% total) → full hold released ($15K). |
| **Proportional**        | Hold releases proportionally to collection percentage.                                                                       | 30% hold = $15K held. Customer pays 50% → $7.5K released ($15K × 50%). Customer pays remaining 50% → remaining $7.5K released.    |
| **Milestone_Only**      | Hold released only by admin or automatic milestone trigger (not by payment). Collection is tracked but doesn't auto-release. | 30% hold. Admin manually releases after customer go-live confirmation (regardless of payment status).                             |

---

### 15.6 Fix #6: Product Eligibility Match_Mode

**New field on Template_Product_Eligibility\_\_c:**

| #   | Field API Name  | Type     | Label      | Notes                                                                                                                                                                         |
| --- | --------------- | -------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 6   | `Match_Mode__c` | Picklist | Match Mode | Any (deal qualifies if it contains any one of the eligible products), All (deal must contain ALL listed products), Exclude (deal is disqualified if it contains this product) |

**Updated eligibility logic:**

```
For product eligibility rows with Match_Mode = Any:
  → at least ONE matching product must be on the deal
For rows with Match_Mode = All:
  → ALL listed products must be on the deal
For rows with Match_Mode = Exclude:
  → if this product is on the deal, plan does NOT apply (blacklist)
```

---

### 15.7 Fix #7: Retention Policies for New Objects

| Object                                         | Retention                                                                                                                                         | Configurable?                                                                |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `Calculation_Trace__c`                         | 2 fiscal years. After that, trace data archived (Big Object or external). The parent Comp_Calculation\_\_c ledger record is retained permanently. | Yes — via Incentive_Configuration**c.Trace_Retention_Years**c (default: 2)   |
| `Payroll_Export__c` + `Payroll_Export_Line__c` | 5 fiscal years (payroll audit requirements).                                                                                                      | Yes — via Incentive_Configuration**c.Payroll_Retention_Years**c (default: 5) |
| `Customer_Payment__c`                          | 5 fiscal years.                                                                                                                                   | Same as payroll.                                                             |
| `Payroll_Confirmation__c`                      | 5 fiscal years.                                                                                                                                   | Same as payroll.                                                             |
| `Imported_Transaction__c`                      | 3 fiscal years after commission processed. Unprocessed imports retained until manually archived.                                                  | Yes — via Incentive_Configuration**c.Import_Retention_Years**c (default: 3)  |

**New fields on Incentive_Configuration\_\_c:**

| #   | Field API Name               | Type        | Label                     | Notes      |
| --- | ---------------------------- | ----------- | ------------------------- | ---------- |
| 18  | `Trace_Retention_Years__c`   | Number(2,0) | Trace Retention (Years)   | Default: 2 |
| 19  | `Payroll_Retention_Years__c` | Number(2,0) | Payroll Retention (Years) | Default: 5 |
| 20  | `Import_Retention_Years__c`  | Number(2,0) | Import Retention (Years)  | Default: 3 |

---

### 15.8 Onboarding Wizard — Updated for V1.7

With all V1.5–V1.7 additions, the onboarding wizard needs new questions:

**Question 11: Payment Integration**

> How do you receive confirmation that customer payments have been made?
>
> - [ ] **We track payments in Salesforce** — we have a payment/collection object or field on Opportunity
> - [ ] **Payments come from an external billing/ERP system** — we'll upload payment data via CSV or API
> - [ ] **We don't track customer payments** — commission holds (if any) will be released manually
>
> If external: What system? {text field}. We'll configure the import API endpoint.

**Question 12: Payroll Integration**

> How do you send commission payments to your payroll system?
>
> - [ ] **Manual download** — we'll generate a CSV/Excel file and upload to payroll manually
> - [ ] **API integration** — our payroll system can pull data via API (specify: ADP, Workday, SAP, Gusto, other)
> - [ ] **Direct push** — we want RevenueTrust to push payment data to payroll automatically (requires integration setup)
>
> How do you confirm payments were processed?
>
> - [ ] **Payroll sends confirmation back via API** (preferred — fully automated)
> - [ ] **We upload a confirmation file** after payroll processes
> - [ ] **Admin manually confirms** each batch

**Question 13: External Transaction Data**

> Are all your commissionable transactions tracked as Salesforce Opportunities?
>
> - [ ] **Yes** — all commission-eligible deals are Opportunities (most common)
> - [ ] **Partially** — some transactions come from external systems (ERP, billing, POS) and need to be imported
> - [ ] **No** — most commissionable data lives outside Salesforce; we'll import via API or file upload
>
> If external: What system(s)? {text field}. What format? {CSV, JSON, API}

**Question 14: Product-Specific Commissions**

> Do commission rates vary by product or product family?
>
> - [ ] **No** — same rate regardless of what was sold
> - [ ] **Yes — by product family** (e.g., Software at 10%, Services at 5%)
> - [ ] **Yes — by specific product** (e.g., Widget Pro at 12%, Widget Standard at 8%)
> - [ ] **Yes — by deal size** (e.g., deals >$500K get a premium rate)

---

### 15.9 Stale Section Supersession — Complete Table

| Section                           | Original Content                       | Superseded By                                    |
| --------------------------------- | -------------------------------------- | ------------------------------------------------ |
| §3.4 Transaction_Category\_\_c    | Old value-source fields                | §11.1 + §14.3 (quota credit fields)              |
| §3.5 Incentive_Plan_Template\_\_c | 41 fields with caps/holds/rates inline | §11.2 (31 fields) + §13.1 (38 fields with SPIFF) |
| §3.7 Quota_Template\_\_c          | "unchanged" claim                      | §12.3 (authoritative 24 fields)                  |
| §3.8 Comp_Plan\_\_c               | 20 fields with acceptance fields       | §12.2 (authoritative 27 fields)                  |
| §3.10 Comp_Calculation\_\_c       | "unchanged" claim                      | §9.8 + §13.2 + §14.3 + §14.8 (39 fields total)   |
| §6 ERD (V1.0)                     | 14 objects                             | §15.11 (final ERD)                               |
| §7 Object Count (V1.0)            | 14 objects                             | §15.10 (35 objects)                              |
| §9.10 Object Count (V1.1)         | 19 objects                             | §15.10                                           |
| §9.11 ERD (V1.1)                  | 19 objects                             | §15.11                                           |
| §10.11 Object Count (V1.2)        | 22 objects                             | §15.10                                           |
| §10.12 ERD (V1.2)                 | 22 objects                             | §15.11                                           |
| §11.14 Object Count (V1.3)        | 26 objects                             | §15.10                                           |
| §11.15 ERD (V1.3)                 | 26 objects                             | §15.11                                           |
| §12.6 Field Count (V1.4)          | ~353 fields, 27 objects                | §15.10                                           |
| §13.3 Object Count (V1.5)         | 27 objects                             | §15.10                                           |
| §14.9 Object Count (V1.6)         | 33 objects, ~457 fields                | §15.10                                           |

---

### 15.10 FINAL AUTHORITATIVE OBJECT COUNT — Incentives Module (V1.7)

| Type                                | Count                 | Objects                                                                                                                                     |
| ----------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Config**                          | 4                     | Incentive_Configuration**c, Participant_Role**c, Transaction_Category**c, Plan_Year**c                                                      |
| **Template**                        | 7                     | Incentive_Plan_Template**c, Commission_Tier**c, Quota_Template**c, Plan_Cap**c, Plan_Hold**c, Clawback_Policy**c, Calculation_Template\_\_c |
| **Rate Overrides**                  | 1                     | Category_Rate_Override\_\_c                                                                                                                 |
| **Eligibility Junctions**           | 3                     | Template_Role_Eligibility**c, Template_Category_Eligibility**c, Template_Product_Eligibility\_\_c                                           |
| **Value Mapping**                   | 1                     | Commissionable_Value_Map\_\_c                                                                                                               |
| **Activity Rules**                  | 1                     | Activity_Commission_Rule\_\_c                                                                                                               |
| **Assignment**                      | 2                     | Comp_Plan**c, Quota**c                                                                                                                      |
| **Plan Governance**                 | 3                     | Plan_Approval**c, Plan_Acceptance**c, eSignature_Provider\_\_c                                                                              |
| **Bulk Operations**                 | 1                     | Quota_Adjustment_Batch\_\_c                                                                                                                 |
| **Runtime/Ledger**                  | 4                     | Comp_Calculation**c, Commission_Draw**c, Payment_Schedule**c, Incentive_Change_Event**c                                                     |
| **Calculation Audit**               | 1                     | Calculation_Trace\_\_c                                                                                                                      |
| **Dispute**                         | 1                     | Incentive_Dispute\_\_c                                                                                                                      |
| **Payment Inbound**                 | 1                     | Customer_Payment\_\_c                                                                                                                       |
| **Payment Outbound**                | 3                     | Payroll_Export**c, Payroll_Export_Line**c, **Payroll_Confirmation\_\_c** (NEW)                                                              |
| **External Import**                 | 1                     | Imported_Transaction\_\_c                                                                                                                   |
| **Incentives Module Total (owned)** | **34 custom objects** |                                                                                                                                             |
| **+ Shared**                        | **1**                 | Territory\_\_c                                                                                                                              |
| **Incentives Module Grand Total**   | **35 objects**        | Consistent with §15.10.1 field count scope                                                                                                  |
| Shared                              | 1                     | Territory\_\_c                                                                                                                              |

### 15.10.1 FINAL AUTHORITATIVE FIELD COUNT

| Object                             | Fields   | Notes                                                           |
| ---------------------------------- | -------- | --------------------------------------------------------------- |
| Incentive_Configuration\_\_c       | 20       | +3 retention fields (§15.7)                                     |
| Plan_Year\_\_c                     | 7        |                                                                 |
| Participant_Role\_\_c              | 13       |                                                                 |
| Transaction_Category\_\_c          | 17       | Including quota credit fields (§14.3)                           |
| Incentive_Plan_Template\_\_c       | 38       | Including SPIFF fields (§13.1)                                  |
| Commission_Tier\_\_c               | 10       |                                                                 |
| Quota_Template\_\_c                | 24       |                                                                 |
| Plan_Cap\_\_c                      | 12       | Including value cap/floor/windfall (§14.2)                      |
| Plan_Hold\_\_c                     | 11       | Including Release_Mode, Release_Threshold (§15.5)               |
| Clawback_Policy\_\_c               | 11       |                                                                 |
| Calculation_Template\_\_c          | 7        |                                                                 |
| Category_Rate_Override\_\_c        | 16       |                                                                 |
| Template_Role_Eligibility\_\_c     | 3        |                                                                 |
| Template_Category_Eligibility\_\_c | 3        |                                                                 |
| Template_Product_Eligibility\_\_c  | 6        | Including Match_Mode (§15.6)                                    |
| Commissionable_Value_Map\_\_c      | 7        |                                                                 |
| Activity_Commission_Rule\_\_c      | 10       |                                                                 |
| Comp_Plan\_\_c                     | 27       |                                                                 |
| Quota\_\_c                         | 20       |                                                                 |
| Plan_Approval\_\_c                 | 11       |                                                                 |
| Plan_Acceptance\_\_c               | 23       |                                                                 |
| eSignature_Provider\_\_c           | 10       |                                                                 |
| Quota_Adjustment_Batch\_\_c        | 11       |                                                                 |
| Comp_Calculation\_\_c              | 39       | Financial ledger. Explanation in Trace, payment in Export Line. |
| Commission_Draw\_\_c               | 8        |                                                                 |
| Payment_Schedule\_\_c              | 8        |                                                                 |
| Incentive_Change_Event\_\_c        | 8        |                                                                 |
| Calculation_Trace\_\_c             | 10       |                                                                 |
| Incentive_Dispute\_\_c             | 9        |                                                                 |
| Customer_Payment\_\_c              | 14       |                                                                 |
| Payroll_Export\_\_c                | 14       |                                                                 |
| Payroll_Export_Line\_\_c           | 13       |                                                                 |
| Payroll_Confirmation\_\_c          | 10       | NEW (§15.4)                                                     |
| Imported_Transaction\_\_c          | 22       |                                                                 |
| Territory\_\_c                     | 9        | Shared with Forecasting                                         |
| **TOTAL**                          | **~474** | 35 objects (34 + Territory)                                     |

### 15.10.2 FINAL PLATFORM TOTAL

| Module                       | Objects                 | Fields   | Status                                  |
| ---------------------------- | ----------------------- | -------- | --------------------------------------- |
| Forecasting                  | 12 (10 obj + 2 CMT)     | 224      | Frozen V1.4                             |
| Incentives                   | 35 (34 obj + Territory) | 474      | Frozen V1.7                             |
| Deal Health + Behavior Intel | 15                      | 225      | Frozen V1.2                             |
| Cross-Module (shared)        | 2                       | 26       | Defined in REVENUETRUST_OBJECT_MODEL.md |
| **PLATFORM TOTAL**           | **64**                  | **~949** |                                         |

---

### 15.11 FINAL ENTITY RELATIONSHIP DIAGRAM

```
Plan_Year__c
  └── Incentive_Plan_Template__c
        │   Status: Draft → In_Review → Approved → Published → Active → Closed
        │   Is_SPIFF for short-run programs
        │
        ├── Commission_Tier__c              (N — rate tiers)
        ├── Plan_Cap__c                     (N — caps incl. commissionable value caps + windfall)
        ├── Plan_Hold__c                    (N — holds with release mode: binary/proportional/milestone)
        ├── Clawback_Policy__c              (N — clawback rules)
        ├── Activity_Commission_Rule__c     (N — BDR/SDR activity-based)
        ├── Category_Rate_Override__c        (N — product/category/size-specific rate overrides)
        ├── Template_Role_Eligibility__c    (N — junction → Participant_Role__c)
        ├── Template_Category_Eligibility__c (N — junction → Transaction_Category__c)
        ├── Template_Product_Eligibility__c  (N — junction → Product2)
        ├── Calculation_Template__c          (link — pre-built algorithm description)
        ├── Quota_Template__c               (N — quota blueprints)
        │     └── Quota__c                  (N — per participant per period)
        ├── Plan_Approval__c                (N — exec approval records)
        └── Comp_Plan__c                    (N — per participant assignments)
              ├── Plan_Acceptance__c         (1 — acceptance with eSignature/IP evidence)
              ├── Comp_Calculation__c        (N — FINANCIAL LEDGER: Projected→Validated→Paid)
              │     └── Calculation_Trace__c (N — step-by-step explanation)
              └── Commission_Draw__c        (N — draws/advances/paybacks)

Payment_Schedule__c                        (N — deferred/vesting installments → Comp_Calculation__c)

PAYMENT INTEGRATION:
  Customer_Payment__c                      (inbound — triggers hold releases)
  Payroll_Export__c                         (outbound — Draft→Approved→Exported→Sent→Confirmed)
    ├── Payroll_Export_Line__c              (N — per participant per batch)
    └── Payroll_Confirmation__c            (1 — payroll system confirmation)

Imported_Transaction__c                    (external data — standalone OR linked to Opportunity, never both)

Transaction_Category__c
  └── Commissionable_Value_Map__c          (N — currency field mappings + quota credit config)

eSignature_Provider__c                     (0-1 — DocuSign/AdobeSign/HelloSign config)
Incentive_Configuration__c                 (1 — global settings + exit policies + retention)
Participant_Role__c                        (N — role definitions)
Incentive_Dispute__c                       (N — calculation disputes, separate from plan disputes)
Incentive_Change_Event__c                  (N — immutable audit trail)
Quota_Adjustment_Batch__c                  (N — bulk quota adjustment tracker)
Territory__c                               (shared with Forecasting)
```

---

---

## 16. V1.8 — DEAL CREDIT SPLIT (Own Split Management)

### 16.1 Deal_Credit_Split\_\_c (NEW)

**Purpose:** RevenueTrust-owned credit split management. Replaces Salesforce OpportunitySplit for orgs without Team Selling AND provides richer commission-aware splitting for orgs that do have it. Allows comp admins, deal owners, and managers to allocate commission credit across multiple participants with role-specific splits, approval workflow, and audit trail.

**Why not just use OpportunitySplit?**

| Dimension                       | OpportunitySplit            | Deal_Credit_Split\_\_c                                                                    |
| ------------------------------- | --------------------------- | ----------------------------------------------------------------------------------------- |
| Requires Team Selling           | Yes                         | No — works in any org                                                                     |
| Split types                     | Basic (split type picklist) | 7 types: Primary, Overlay, Referral, Team_Pool, Manager_Override, Channel_Partner, Custom |
| Approval workflow               | None                        | Draft → Pending_Approval → Approved → Active                                              |
| Quota credit ≠ commission split | No                          | Yes — split 50% commission but 100% quota credit                                          |
| Effective dates                 | No                          | Start/end dates for time-bound splits                                                     |
| Plan linkage                    | No                          | Direct lookup to Comp_Plan\_\_c                                                           |
| Role context                    | No                          | Lookup to Participant_Role\_\_c                                                           |
| Audit trail                     | Field History only          | Full IncentiveChangeEvent + Platform Event logging                                        |

**Deployment options per org:**

| Org Configuration                                        | Recommended Approach                                                                                                                                                                                         |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **No Team Selling**                                      | Use Deal_Credit_Split\_\_c exclusively. All split management in RevenueTrust.                                                                                                                                |
| **Team Selling enabled, wants RevenueTrust splits**      | Use Deal_Credit_Split\_\_c. Ignore OpportunitySplit for commission purposes.                                                                                                                                 |
| **Team Selling enabled, wants to keep OpportunitySplit** | Deploy Team Selling Extension Pack. OpportunitySplit changes fire SPLIT_CHANGED events. Optionally sync to Deal_Credit_Split**c via External_Split_Id**c.                                                    |
| **Team Selling enabled, wants both**                     | Use OpportunitySplit for basic allocation + Deal_Credit_Split**c for overlays, referrals, and complex splits. Source-of-truth rule: Deal_Credit_Split**c wins if both exist for the same participant × deal. |

#### Field List (22 fields)

| #   | Field API Name                      | Type                | Label               | Notes                                                                            |
| --- | ----------------------------------- | ------------------- | ------------------- | -------------------------------------------------------------------------------- |
| —   | **Relationships**                   |                     |                     |                                                                                  |
| 1   | `Opportunity__c`                    | Lookup              | Deal                | → Opportunity                                                                    |
| 2   | `Participant__c`                    | Lookup              | Participant         | → User                                                                           |
| 3   | `Participant_Role__c`               | Lookup              | Role                | → Participant_Role\_\_c                                                          |
| 4   | `Comp_Plan__c`                      | Lookup              | Plan Assignment     | → Comp_Plan\_\_c                                                                 |
| 5   | `Created_By_User__c`                | Lookup              | Created By          | → User                                                                           |
| —   | **Split Allocation**                |                     |                     |                                                                                  |
| 6   | `Split_Percentage__c`               | Percent             | Split %             | 0-100%. All active splits on a deal should sum to 100%.                          |
| 7   | `Split_Amount__c`                   | Currency            | Split Amount        | Fixed $ override. If populated, takes precedence over %.                         |
| 8   | `Effective_Commissionable_Value__c` | Currency            | Effective Value     | Computed: deal value × split %. Used by commission engine.                       |
| —   | **Quota Control**                   |                     |                     |                                                                                  |
| 9   | `Counts_Toward_Quota__c`            | Checkbox            | Counts Toward Quota | False for overlay credit that pays but doesn't credit quota.                     |
| 10  | `Quota_Credit_Percentage__c`        | Percent             | Quota Credit %      | If different from Split %. Null = same as split %.                               |
| —   | **Split Type**                      |                     |                     |                                                                                  |
| 11  | `Split_Type__c`                     | Restricted Picklist | Split Type          | Primary, Overlay, Referral, Team_Pool, Manager_Override, Channel_Partner, Custom |
| 12  | `Is_Primary__c`                     | Checkbox            | Primary             | Only one per deal. Enforced by trigger.                                          |
| —   | **Approval**                        |                     |                     |                                                                                  |
| 13  | `Status__c`                         | Restricted Picklist | Status              | Draft, Pending_Approval, Approved, Rejected, Active, Expired, Cancelled          |
| 14  | `Approved_By__c`                    | Lookup              | Approved By         | → User                                                                           |
| 15  | `Approved_On__c`                    | DateTime            | Approved On         |                                                                                  |
| 16  | `Approval_Notes__c`                 | LongTextArea(2000)  | Approval Notes      |                                                                                  |
| 17  | `Rejection_Reason__c`               | LongTextArea(2000)  | Rejection Reason    |                                                                                  |
| —   | **Effective Dates**                 |                     |                     |                                                                                  |
| 18  | `Effective_Start__c`                | Date                | Effective Start     | Null = immediate on approval                                                     |
| 19  | `Effective_End__c`                  | Date                | Effective End       | Null = no expiration                                                             |
| —   | **Audit**                           |                     |                     |                                                                                  |
| 20  | `Source__c`                         | Restricted Picklist | Source              | Manual, Imported, Rule_Based, Cloned, System                                     |
| 21  | `External_Split_Id__c`              | Text(100)           | External Split ID   | Unique, ExternalId. For OpportunitySplit sync.                                   |
| 22  | `Notes__c`                          | LongTextArea(5000)  | Notes               |                                                                                  |

#### Trigger: DealCreditSplitTrigger

- Before: validates split totals (100% for active splits), single primary per deal, % range
- After: publishes SPLIT_CHANGED / SPLIT_CHANGED_POST_CLOSE events with subtypes: SPLIT_ADDED, SPLIT_REMOVED, SPLIT_ACTIVATED, SPLIT_DEACTIVATED, SPLIT_MODIFIED
- Only Active/Approved splits fire events (Draft/Pending don't affect calcs)
- Audit trail via IncentiveChangeEventService

#### Commission Engine Integration

The commission engine's Step 1 (Identify Participants) checks for Deal_Credit_Split\_\_c records:

1. Query active splits for the Opportunity
2. If splits exist: each participant gets their split % of the commissionable value
3. If no splits exist: fall back to owner-only (current V1 behavior)
4. The `Effective_Commissionable_Value__c` on each split feeds into Step 3 (Compute Commissionable Value)

---

### 16.2 Updated Object Count — V1.8

| Category                            | Change                     |
| ----------------------------------- | -------------------------- |
| **Credit Splits (NEW)**             | +1: Deal_Credit_Split\_\_c |
| **Incentives Module Total (owned)** | 35 custom objects (was 34) |
| **+ Shared**                        | 1: Territory\_\_c          |
| **Incentives Module Grand Total**   | **36 objects**             |

### 16.3 Updated Field Count — V1.8

| Object                       | Fields              |
| ---------------------------- | ------------------- |
| Deal_Credit_Split\_\_c       | 22 (NEW)            |
| **Updated Incentives Total** | **~496** (was ~474) |

### 16.4 Updated Platform Total — V1.8

| Module                       | Objects             | Fields   |
| ---------------------------- | ------------------- | -------- |
| Forecasting                  | 12                  | 224      |
| Incentives                   | 36 (35 + Territory) | 496      |
| Deal Health + Behavior Intel | 15                  | 225      |
| Cross-Module (shared)        | 2                   | 26       |
| **PLATFORM TOTAL**           | **65**              | **~971** |

### 16.5 Updated ERD (addition to §15.11)

```
Opportunity
  └── Deal_Credit_Split__c           (N — one per participant per deal)
        ├── → Participant (User)
        ├── → Participant_Role__c
        ├── → Comp_Plan__c
        └── Status: Draft → Pending_Approval → Approved → Active
```

---

---

## 17. V1.9 — IMPLEMENTATION STATUS (Activity Commissions + External Import + REST APIs)

### 17.1 Activity-Based Commission Engine (Implemented)

**Covers spec §9.4 (Activity_Commission_Rule\_\_c) and §4 Step 1 for activity-based plans.**

| Component                       | Type    | What It Does                                                                                                                                                                                                                                                                                               |
| ------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ActivityCommissionService.cls` | Service | Evaluates Activity_Commission_Rule**c against Tasks/Events/Opps. Supports 5 activity types: Qualified_Meeting, Call_Logged, Demo_Completed, Qualified_Opportunity, Custom. JSON filter criteria. Cap enforcement (count + amount per period). Creates Comp_Calculation**c with Plan_Type = Activity_Based. |
| `ActivityTriggerHandler.cls`    | Handler | Delegates Task/Event trigger context to service. TriggerControlService kill switch.                                                                                                                                                                                                                        |
| `ActivityTaskTrigger`           | Trigger | Fires on Task insert → evaluates call-based rules                                                                                                                                                                                                                                                          |
| `ActivityEventTrigger`          | Trigger | Fires on Event insert → evaluates meeting/demo rules                                                                                                                                                                                                                                                       |
| `ActivityCommissionBatch.cls`   | Batch   | Scheduled reconciliation for qualified opp counting. Catches BDR-sourced opps missed by real-time triggers.                                                                                                                                                                                                |

**Example configurations:**

| Rule                       | Activity Type         | Rate                    | Cap                     | Use Case                |
| -------------------------- | --------------------- | ----------------------- | ----------------------- | ----------------------- |
| $50/qualified meeting      | Qualified_Meeting     | Rate_Per_Activity = 50  | Cap_Count = 20/month    | BDR meeting incentive   |
| $200/SQL created           | Qualified_Opportunity | Rate_Per_Activity = 200 | Cap_Per_Period = $5,000 | BDR pipeline generation |
| $5/call logged             | Call_Logged           | Rate_Per_Activity = 5   | Cap_Count = 100/month   | SDR call volume         |
| 2% of qualified opp Amount | Qualified_Opportunity | Rate_Pct = 2            | Cap_Per_Period = $3,000 | BDR value-based         |
| Demo completed bonus       | Demo_Completed        | Rate_Per_Activity = 100 | None                    | SE demo incentive       |

### 17.2 External Transaction Import Engine (Implemented)

**Covers spec §14.8 (Imported_Transaction**c) and §14.6 (Customer_Payment**c).**

| Component                        | Type     | Endpoint                                                     | What It Does                                                                                                                                                                                |
| -------------------------------- | -------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ImportedTransactionService.cls` | Service  | —                                                            | Full pipeline: dedup by External_Id → match participant (email/employee ID/federation ID) → validate → process commissions. Source-of-truth enforcement: import OR opportunity, never both. |
| `ImportTransactionRestApi.cls`   | REST API | `POST /services/apexrest/revenuetrust/transactions`          | Accepts JSON array of external transactions (usage, overages, ERP deals, POS). Returns matched/processed/error/duplicate counts + batch ID.                                                 |
| `CustomerPaymentRestApi.cls`     | REST API | `POST /services/apexrest/revenuetrust/payments`              | Accepts customer payment data. Triggers collection-based hold releases when collection % meets threshold.                                                                                   |
| `PayrollRestApi.cls`             | REST API | `GET /services/apexrest/revenuetrust/payroll?period=YYYY-MM` | Returns validated unpaid commissions grouped by participant for payroll export.                                                                                                             |
| `PayrollRestApi.cls`             | REST API | `POST /services/apexrest/revenuetrust/payroll/confirm`       | Receives payroll confirmation from provider. Creates Payroll_Confirmation**c. Marks Comp_Calculation**c as Paid.                                                                            |

**API Request/Response examples:**

Import transactions:

```json
POST /services/apexrest/revenuetrust/transactions
[
  {"External_Id": "ERP-001", "Transaction_Date": "2027-04-15",
   "Amount": 50000, "Currency_Code": "USD", "Category_Code": "NEW",
   "Participant_Email": "jsmith@acme.com", "Account_Name": "BigCo",
   "Product_Name": "Widget Pro", "Quantity": 100, "Source_System": "ERP"}
]

Response:
{"success": true, "totalRecords": 1, "matched": 1, "processed": 1,
 "errors": 0, "duplicates": 0, "batchId": "API-20270415-143022"}
```

Customer payments:

```json
POST /services/apexrest/revenuetrust/payments
[
  {"Opportunity_Id": "006xxx", "Amount": 50000, "Payment_Date": "2027-04-15",
   "Payment_Reference": "INV-2027-042", "Payment_Method": "Wire",
   "Collection_Pct": 100, "Is_Full_Payment": true, "External_Id": "PAY-042"}
]

Response:
{"success": true, "totalPayments": 1, "processed": 1, "holdsReleased": 2}
```

Payroll confirmation:

```json
POST /services/apexrest/revenuetrust/payroll/confirm
{"export_id": "PE-00042",
 "confirmed_records": [
   {"employee_id": "EMP001", "amount": 8400, "status": "paid"},
   {"employee_id": "EMP002", "amount": 3100, "status": "failed", "reason": "invalid bank account"}
 ]}

Response:
{"success": true, "confirmed": 1, "failed": 1}
```

### 17.3 Updated Implementation Inventory

| Category                           | Count | Items                                                                                                                                                                                                    |
| ---------------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Custom Objects (platform-wide)** | 65    | Per §17.4 authoritative table. Includes all 4 modules + cross-module shared objects.                                                                                                                     |
| **Platform Events**                | 3     | Commission_Event**e, Governance_Eval_Event**e, Signal_Event\_\_e                                                                                                                                         |
| **Apex Classes**                   | 38    | 24 production + 1 factory + 13 test classes                                                                                                                                                              |
| **Apex Triggers (deployed)**       | 14    | Opp, OLI, Task, Event, 5 config objects, Deal_Credit_Split, Comp_Plan, Clawback_Policy, 3 Platform Event triggers. Note: ForecastPeriodTrigger (#15 in routing doc §12.3) belongs to Forecasting module. |
| **REST API Endpoints**             | 4     | /transactions, /payments, /payroll (GET), /payroll/confirm (POST)                                                                                                                                        |
| **Scheduled Batches**              | 2     | HoldExpirationBatch, ActivityCommissionBatch                                                                                                                                                             |
| **CMT Seed Records**               | 16    | Trigger_Control per trigger (all enabled)                                                                                                                                                                |
| **Tests**                          | 126   | 100% pass rate                                                                                                                                                                                           |

### 17.4 Updated Platform Total — V1.9

| Module                       | Objects             | Fields   | Status                              |
| ---------------------------- | ------------------- | -------- | ----------------------------------- |
| Forecasting                  | 12                  | 224      | Frozen V1.4                         |
| Incentives                   | 36 (35 + Territory) | 496      | V1.9 (Deal_Credit_Split added V1.8) |
| Deal Health + Behavior Intel | 15                  | 225      | Frozen V1.2                         |
| Cross-Module (shared)        | 2                   | 26       |                                     |
| **PLATFORM TOTAL**           | **65**              | **~971** |                                     |

### 17.5 Spec Requirements vs. Implementation Cross-Reference

| Spec Requirement                          | Section           | Implemented?                                        |
| ----------------------------------------- | ----------------- | --------------------------------------------------- |
| Commission Calculation Engine (7-step)    | §4                | ✅ CommissionService.cls                            |
| Activity-Based Commissions (BDR/SDR)      | §9.4              | ✅ ActivityCommissionService.cls + triggers         |
| External Transaction Import               | §14.8             | ✅ ImportedTransactionService.cls + REST API        |
| Customer Payment Inbound                  | §14.6             | ✅ CustomerPaymentRestApi.cls                       |
| Payroll Export Outbound                   | §14.7             | ✅ PayrollRestApi.cls (GET + confirm)               |
| Deal Credit Splits (own split management) | §16.1             | ✅ Deal_Credit_Split\_\_c + trigger + handler       |
| Commission Event Routing (45 types)       | Routing Doc V2.4  | ✅ All 45 types routed                              |
| Calculation Invalidation                  | Routing Doc §12.4 | ✅ CalculationInvalidationService.cls               |
| Period Freeze Handling                    | Routing Doc §D.3  | ✅ PeriodFreezeHandler.cls                          |
| Commission Hold/Release                   | Routing Doc §12.7 | ✅ CommissionHoldService.cls + HoldExpirationBatch  |
| Trigger Control (CMT kill switch)         | §14.4             | ✅ TriggerControlService.cls + 16 CMT records       |
| Configurable Won/Lost Stages              | Onboarding        | ✅ Incentive_Configuration\_\_c fields              |
| Immutable Ledger (append-only)            | §1.5.4            | ✅ Comp_Calculation\_\_c lifecycle states           |
| Plan/Rule Change Invalidation             | Routing Doc D.2   | ✅ Config triggers + CalculationInvalidationService |
| Revenue Recognition Routing               | Routing Doc B.3   | ✅ 3 subtypes in CommissionEventHandler             |
| Attainment Ripple Boundaries              | Routing Doc §12.5 | ✅ Attainment_Recompute_Scope\_\_c config           |
| Audit Trail                               | §1.5.4            | ✅ IncentiveChangeEventService.cls                  |

---

---

## 18. V2.0 — PIPELINE OBJECT ABSTRACTION + CUSTOM FORMULA ENGINE

### 18.1 Pipeline Object Abstraction (Any SObject Commissioning)

**Problem solved:** The commission engine was hardcoded to Opportunity. Many industries commission on Order, Contract, Quote, Policy**c, Subscription**c, or custom objects.

**Solution:** Two new Apex classes that abstract all pipeline record access.

#### PipelineObjectService.cls

| Method                             | What It Does                                                        |
| ---------------------------------- | ------------------------------------------------------------------- |
| `getPipelineObjectName()`          | Returns configured pipeline object API name (default: Opportunity)  |
| `queryRecord(Id)`                  | Queries a single record with all mapped fields via dynamic SOQL     |
| `queryRecords(Set<Id>)`            | Bulk query by IDs                                                   |
| `queryByOwner(Id)`                 | Query records by owner                                              |
| `getAmount(SObject)`               | Get amount via logical field mapping                                |
| `getOwnerId(SObject)`              | Get owner via logical field mapping                                 |
| `getStage(SObject)`                | Get stage/status via logical field mapping                          |
| `getCloseDate(SObject)`            | Get close date via logical field mapping                            |
| `getDynamicField(SObject, String)` | Get any field by API name (for Commissionable_Value_Map resolution) |

**Configuration:** Reads `Incentive_Configuration__c.Pipeline_Object__c` + `Field_Mapping__mdt` records. Default Opportunity mappings auto-apply when no custom mappings exist.

#### GenericCommissionTriggerHandler.cls

Generic trigger handler that subscriber orgs call from their custom object triggers:

```apex
// Subscriber creates this 3-line trigger on their custom object:
trigger PolicyCommissionTrigger on Policy__c(after update) {
  REVT.GenericCommissionTriggerHandler.handleAfterUpdate(
    Trigger.new,
    Trigger.oldMap,
    'Policy__c'
  );
}
```

Detects ALL lifecycle events (close, lost, reopen, amount/date/owner/stage changes) using PipelineObjectService for field resolution. Same event types, same routing, same governance — on any object.

**How to enable commissions on a custom object:**

| Step | Action              | Where                                                                                                                  |
| ---- | ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| 1    | Set pipeline object | `Incentive_Configuration__c.Pipeline_Object__c = 'Policy__c'`                                                          |
| 2    | Map fields          | Create `Field_Mapping__mdt` records: Pipeline.Amount → Premium_Value**c, Pipeline.Stage → Underwriting_Status**c, etc. |
| 3    | Configure stages    | Set `Won_Stages__c = 'Issued,Bound'` and `Lost_Stages__c = 'Declined,Withdrawn'`                                       |
| 4    | Create trigger      | 3-line unmanaged trigger calling GenericCommissionTriggerHandler                                                       |
| 5    | Done                | All 45 event types, all alert types, full calculation engine — on the custom object                                    |

---

### 18.2 Custom Formula Engine (User-Defined Calculations)

**Problem solved:** The 10 built-in plan types cover most scenarios, but some orgs have unique calculation logic that doesn't fit any standard pattern: "pay 5% on software minus returns if deal term > 12 months AND not a partner deal."

**Solution:** A new Commission_Formula\_\_c object + FormulaEvaluator.cls — a safe, declarative formula language that admins can configure without code.

#### Commission_Formula\_\_c (NEW object — 12 fields)

MasterDetail child of Incentive_Plan_Template\_\_c. Stores custom formulas with variable bindings, conditions, and error handling.

| #   | Field                   | Type                | Purpose                                                                       |
| --- | ----------------------- | ------------------- | ----------------------------------------------------------------------------- |
| 1   | `Plan_Template__c`      | MasterDetail        | → Incentive_Plan_Template\_\_c                                                |
| 2   | `Formula_Name__c`       | Text(100)           | Human-readable name                                                           |
| 3   | `Description__c`        | LongTextArea(2000)  | Explanation of the formula                                                    |
| 4   | `Formula_Expression__c` | LongTextArea(5000)  | The formula: `(Amount - COGS) * IF(Term > 12, 0.08, 0.05)`                    |
| 5   | `Variables__c`          | LongTextArea(2000)  | JSON: `[{"name": "Amount", "source": "Pipeline.Amount", "type": "currency"}]` |
| 6   | `Conditions__c`         | LongTextArea(2000)  | JSON: `[{"field": "Type", "operator": "equals", "value": "Software"}]`        |
| 7   | `Sort_Order__c`         | Number(3,0)         | Evaluation order (first matching wins)                                        |
| 8   | `Is_Active__c`          | Checkbox            |                                                                               |
| 9   | `Result_Type__c`        | Restricted Picklist | Commission_Amount, Commission_Rate, Commissionable_Value                      |
| 10  | `Fallback_Rate__c`      | Percent             | If formula fails, use this rate                                               |
| 11  | `Error_Handling__c`     | Restricted Picklist | Use_Fallback, Skip, Alert_Admin                                               |
| 12  | `Test_Input__c`         | LongTextArea(2000)  | JSON test data for admin validation                                           |

#### FormulaEvaluator.cls — Safe Expression Evaluator

**Intentionally limited to numeric operations.** Not a general Apex evaluator.

| Supported        | Examples                                                                       |
| ---------------- | ------------------------------------------------------------------------------ |
| Arithmetic       | `Amount * 0.05`, `(Revenue - COGS) * Rate`                                     |
| Comparisons      | `Amount > 100000`, `Term >= 12`                                                |
| IF/THEN/ELSE     | `IF(Amount > 100000, Amount * 0.08, Amount * 0.05)`                            |
| Nested IF        | `IF(Att > 150, Amt * 0.15, IF(Att > 100, Amt * 0.12, Amt * 0.08))`             |
| Functions        | `MIN(Amount * 0.10, 50000)`, `MAX(Base, Floor)`, `ABS(Delta)`, `ROUND(Amt, 2)` |
| Variable binding | Variables defined in JSON, resolved from pipeline record fields                |
| Conditions       | JSON condition array — all must pass for formula to apply                      |

**Safety guarantees:**

- Blocks DML, SOQL, system calls, HTTP, type reflection
- No string manipulation (numeric-only)
- No access to system resources
- Sandboxed evaluation — cannot affect org state

**Example formulas an admin can create:**

| Business Rule            | Formula                                                                      | Conditions                                                         |
| ------------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| 5% flat on software      | `Amount * 0.05`                                                              | `[{"field": "Type", "operator": "equals", "value": "Software"}]`   |
| 8% on large, 5% on small | `IF(Amount > 100000, Amount * 0.08, Amount * 0.05)`                          | None                                                               |
| Gross margin commission  | `(Amount - COGS) * 0.05`                                                     | `[{"field": "Amount", "operator": "greaterThan", "value": 10000}]` |
| Capped at $50K           | `MIN(Amount * 0.10, 50000)`                                                  | None                                                               |
| Long-term deal premium   | `Amount * IF(Term > 12, 0.08, 0.05)`                                         | None                                                               |
| Partner discount         | `Amount * IF(Is_Partner > 0, 0.03, 0.06)`                                    | None                                                               |
| Complex multi-factor     | `(Amount - COGS) * IF(Term > 12, 0.08, 0.05) * IF(Is_Partner > 0, 0.5, 1.0)` | `[{"field": "Type", "operator": "equals", "value": "Software"}]`   |

---

### 18.3 Updated Implementation Inventory — V2.0

| Category                      | Count             | Change                                                                        |
| ----------------------------- | ----------------- | ----------------------------------------------------------------------------- |
| **Custom Objects**            | 69                | +1 (Commission_Formula\_\_c)                                                  |
| **Apex Classes (production)** | 41                | +3 (PipelineObjectService, GenericCommissionTriggerHandler, FormulaEvaluator) |
| **Apex Triggers**             | 15                | No change (GenericCommissionTriggerHandler is subscriber-deployed)            |
| **REST API Endpoints**        | 4                 | No change                                                                     |
| **Scheduled Batches**         | 2                 | No change                                                                     |
| **Tests**                     | 126 (124 passing) | 2 pre-existing test-expectation mismatches                                    |

### 18.4 Updated Platform Total — V2.0

| Module                       | Objects             | Fields   | Status                               |
| ---------------------------- | ------------------- | -------- | ------------------------------------ |
| Forecasting                  | 12                  | 224      | Frozen V1.4                          |
| Incentives                   | 37 (36 + Territory) | ~508     | V2.0 (+Commission_Formula 12 fields) |
| Deal Health + Behavior Intel | 15                  | 225      | Frozen V1.2                          |
| Cross-Module (shared)        | 2                   | 26       |                                      |
| **PLATFORM TOTAL**           | **66**              | **~983** |                                      |

---

_Incentives Object Model V2.0_  
_Pipeline Object Abstraction: commission on any SObject via Field_Mapping + 3-line subscriber trigger._  
_Custom Formula Engine: safe declarative formulas with IF/MIN/MAX + JSON variable binding + conditions._  
_37 Incentives objects + Territory. 41 Apex classes. 15 triggers. 4 REST endpoints._  
_Platform total: 66 objects, ~983 fields._
