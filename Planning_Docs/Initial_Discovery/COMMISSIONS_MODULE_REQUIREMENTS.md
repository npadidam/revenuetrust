# Commissions Module — Requirements Document

**Source Org:** KONY ORG  
**Prepared:** 2026-04-01  
**Author:** Reverse-engineered from KONY ORG Salesforce metadata and Apex source

---

## 1. Overview

The Commissions Module automates the calculation, tracking, and payment of sales commissions within Salesforce. It covers the full lifecycle: identifying eligible recipients on a deal, applying the correct compensation plan rates (base, accelerators, Rev Rec), tracking draws/advances/paybacks, and surfacing dashboards for both individual reps and finance admins.

---

## 2. Business Context

- Commissions are processed per **Opportunity** at the time of deal closure (Probability = 100 or stage = Closed Won).
- Multiple roles on a deal can be eligible for commission simultaneously (AE/Owner, BDR, SE, PAM, CSM, DCP, CSA, Managers).
- Different deal types (Subscription, Renewal, Services, Training, AppVantage, End of Life) have distinct eligibility rules.
- Compensation plans are fiscal-year-scoped and can be **Individual**, **Regional**, or **Global**.
- Plans support both **booking-based** and **revenue-recognition (Rev Rec)-based** commission triggers.

---

## 3. Custom Objects

### 3.1 Comp_Plan\_\_c — Compensation Plan

Defines the commission structure for a rep for a given fiscal year.

| Field                                        | Purpose                                                      |
| -------------------------------------------- | ------------------------------------------------------------ |
| Sales_Rep\_\_c                               | The rep this plan belongs to                                 |
| Comp_Plan_Type\_\_c                          | Plan category (e.g., New Subscription, Renewal, Services)    |
| Rep_Category\_\_c                            | Rep role category (AE, BDR, SE, CSM, etc.)                   |
| Base_Rate\_\_c                               | Standard commission percentage                               |
| Accelerated_Rate\_\_c                        | Accelerated commission percentage                            |
| Annual_Accelerators\_\_c                     | Annual accelerator rate                                      |
| Quarterly_Accelerators\_\_c                  | Quarterly accelerator rate                                   |
| Annual_Accelerator_Threshold\_\_c            | Attainment % required to unlock annual accelerators          |
| Quarterly_Accelerator_Threshold\_\_c         | Attainment % required to unlock quarterly accelerators       |
| Quarterly_Accelerators_Eligible\_\_c         | Flag: quarterly accelerators enabled                         |
| Annual_Accelerators_Eligible\_\_c            | Flag: annual accelerators enabled                            |
| FY_Target_Amount\_\_c                        | Full-year quota target                                       |
| Q1–Q4_Target_Amount\_\_c                     | Per-quarter quota targets                                    |
| Cumulative_Q1–Q4_Target\_\_c                 | Cumulative quota targets                                     |
| FY_Achieved_Quota\_\_c                       | Full-year attainment                                         |
| Q1–Q4_Achieved_Quota\_\_c                    | Per-quarter attainment                                       |
| Cumulative_Q1–Q4_Achieved_Quota\_\_c         | Cumulative attainment                                        |
| FY_Attainment\_\_c                           | FY attainment percentage                                     |
| YTD_Attainment\_\_c                          | YTD attainment percentage                                    |
| Cap_Percentage\_\_c                          | Commission cap as % of target                                |
| Cap_Amount\_\_c                              | Commission cap as dollar amount                              |
| Cap_on_Single_Deal\_\_c                      | Max commission on a single deal                              |
| Commission_on_Net\_\_c                       | Whether commissions are on net amount                        |
| Commissions_Based_On\_\_c                    | "Booking" or "Revenue"                                       |
| Commissions_Region**c / Commission_Region**c | Region scoping for the plan                                  |
| Global\_\_c                                  | Whether this is a global plan                                |
| Sub_Region\_\_c                              | Sub-region scoping                                           |
| Vertical_Split\_\_c                          | Vertical split percentage                                    |
| Dependent_Plan\_\_c                          | Linked plan required to meet threshold before this plan pays |
| Dependent_Plan_Threshold\_\_c                | Threshold on dependent plan                                  |
| Multi_Year_Bonus_Rate\_\_c                   | Bonus rate for multi-year deals                              |
| Multi_Year_Min_Term_in_Years\_\_c            | Minimum term to qualify for multi-year bonus                 |
| Multi_Year_Deal_Cap\_\_c                     | Cap on multi-year bonus per deal                             |
| Multi_Year_Plan_Cap\_\_c                     | Cap on multi-year bonus per plan                             |
| Min_Term_in_Years_for_Penalty\_\_c           | Minimum term; below this a penalty applies                   |
| Penalty\_\_c                                 | Penalty reduction percentage for short-term deals            |
| Hold_Type\_\_c                               | Type of hold on the plan                                     |
| Target_Hold\_\_c                             | Target is on hold                                            |
| Base_Rate_Hold\_\_c                          | Base rate payments are on hold                               |
| KPS_SPIFF_Approval_Required\_\_c             | SPIFF requires approval                                      |
| KPS_NPS_Hold_Back\_\_c                       | Hold back based on NPS                                       |
| KPS_Renewal_Hold\_\_c                        | Hold back on renewals                                        |
| Services_Rate\_\_c                           | Services-specific commission rate                            |
| Services_Opportunity_Type1\_\_c              | Services opportunity type filter                             |
| Opportunity_Source\_\_c                      | Opportunity source filter                                    |
| Opportunity_Type\_\_c                        | Opportunity type filter                                      |
| Partner_Role\_\_c                            | Partner role filter                                          |
| Renewal_Type\_\_c                            | Renewal type filter                                          |
| Sales_Rep_Commission_Manager\_\_c            | Commissions manager for this rep                             |
| Upfront_Pay_on_FY_Achievement\_\_c           | Upfront payment when FY achievement reached                  |
| Upfront_Rate\_\_c                            | Rate for upfront payment                                     |
| Total_Commissions_Earned\_\_c                | Total commissions earned on this plan                        |
| Payout_Table_Record_Count\_\_c               | Count of payout table records                                |
| New_Subscription_Commissions\_\_c            | New subscription commissions summary                         |
| Renewal_Commissions\_\_c                     | Renewal commissions summary                                  |
| Base_Commissions\_\_c                        | Base commissions summary                                     |

### 3.2 Comp_Calculation\_\_c — Compensation Calculation

One record per Opportunity × Rep × Plan × Rate Tier. This is the ledger of commission calculations.

| Field                                        | Purpose                                                                 |
| -------------------------------------------- | ----------------------------------------------------------------------- |
| Opportunity\_\_c                             | Linked opportunity                                                      |
| Rep\_\_c                                     | Rep being compensated                                                   |
| Comp_Plan\_\_c                               | Linked compensation plan                                                |
| Quota_Category\_\_c                          | Category grouping (New Opportunity, Renewal, etc.)                      |
| Comp_Plan_Type\_\_c                          | Plan type                                                               |
| Commisionable_Value\_\_c                     | Value used to calculate commission                                      |
| Applied_Percentage\_\_c                      | Actual rate applied                                                     |
| Eligible_Commission\_\_c                     | Calculated commission amount                                            |
| Plan_Rate\_\_c                               | Rate tier: "Base Rate", "Quarterly Accelerators", "Annual Accelerators" |
| Accelerators_Eligible\_\_c                   | Whether accelerators applied                                            |
| Accrued_Accelerators\_\_c                    | Accrued accelerator amount                                              |
| Hold_Reason\_\_c                             | Reason commission is on hold                                            |
| No_Quota_Retirement\_\_c                     | Commission paid but quota not retired                                   |
| Contract_Date2\_\_c                          | Contract date used for FY bucketing                                     |
| Processed_Date\_\_c                          | Date commissions were processed                                         |
| Commission_Paid_Date\_\_c                    | Date commission was paid                                                |
| Revenue_Recognition\_\_c                     | Rev Rec record link                                                     |
| Fx_Rate\_\_c                                 | FX rate for currency conversion                                         |
| Commissions_Region\_\_c                      | Region for this calculation                                             |
| Rep_Category\_\_c                            | Rep role category                                                       |
| Pool\_\_c                                    | Commission pool reference                                               |
| Type\_\_c                                    | Commission type                                                         |
| Payment_Frequency\_\_c                       | Monthly / Quarterly                                                     |
| Payment_Month\_\_c                           | Month of payment                                                        |
| Force_Comp_Attmt_and_Earned_Commissions\_\_c | Force attainment and earned                                             |
| PS_Commission_Person\_\_c                    | PS commission person reference                                          |
| OLI_ID\_\_c                                  | Opportunity line item reference                                         |

### 3.3 Commission_Draw\_\_c — Commission Draw / Advance

Tracks draws, advances, and paybacks against a rep's draw balance.

| Field                  | Purpose                         |
| ---------------------- | ------------------------------- |
| Rep\_\_c               | Rep who received the draw       |
| Opportunity\_\_c       | Linked opportunity (optional)   |
| Amount\_\_c            | Draw/advance/payback amount     |
| Type\_\_c              | "Draw", "Advance", or "Payback" |
| Beginning_Balance\_\_c | Draw balance before this record |
| Ending_Balance\_\_c    | Draw balance after this record  |

### 3.4 Commission\_\_c — Commission (Summary)

Parent-level commission record. Sharing controlled by parent.

### 3.5 CommissionablePercentage\_\_c — Custom Setting

Protected list custom setting. Stores commissionable percentage configuration entries.

### 3.6 PS_Commission_People\_\_c — PS Commission People

Tracks Professional Services staff eligible for commissions on deals.

---

## 4. Eligible Commission Recipients by Opportunity Type

| Role                                               | Subscription          | Renewal / EoL | Services | Training | AppVantage |
| -------------------------------------------------- | --------------------- | ------------- | -------- | -------- | ---------- |
| Opportunity Owner (AE/AGM)                         | ✓                     | ✓             | ✓        | ✓        | ✓          |
| Outside Sales Rep                                  | ✓                     | ✓             | ✓        | ✓        | ✓          |
| BDR (Bus Dev Rep)                                  | ✓                     | —             | ✓        | ✓        | ✓          |
| Partner Rep (PAM)                                  | ✓                     | ✓             | ✓        | ✓        | ✓          |
| Solutions Engineer (SE)                            | ✓                     | ✓             | ✓        | ✓        | ✓          |
| CSM (Account-level)                                | ✓ (Existing Customer) | ✓             | —        | —        | ✓          |
| Digital Client Partner (DCP)                       | ✓                     | —             | —        | —        | ✓          |
| Customer Success Architect (CSA)                   | ✓                     | —             | —        | —        | ✓          |
| Issued Renewal Users (Eligible_Comp_Renewals\_\_c) | —                     | ✓             | —        | —        | —          |
| Manager hierarchy                                  | ✓                     | ✓             | ✓        | ✓        | ✓          |

**Notes:**

- Services commissions are only processed when `Probability = 100`.
- BDR is excluded from Renewal-type opportunities.
- Manager hierarchy is added via `addCommissionsManagers()` — both individual managers and group managers.

---

## 5. Compensation Plan Hierarchy

Plans are resolved in three tiers:

1. **Individual Plans** — Plans explicitly tied to a specific rep (`Sales_Rep__c = userId`)
2. **Regional Plans** — Plans tied to the Opportunity's `Account.Region__c`
3. **Global Plans** — Plans where `Global__c = true`

For **Revenue-based plans**, all three tiers are processed when Rev Rec events fire. For booking-based plans, the standard process runs on opportunity close.

---

## 6. Commission Calculation Logic

### 6.1 Commissionable Value

- Derived from opportunity fields: `Gross_Commissionable_Value__c`, `Total_Opportunity_Sales_Price__c`, line item values, or rev rec amount.
- Multi-year deals split by year: Year 1–5 prices from Opportunity Line Items.
- `OppCommRatio` adjusts commissionable value when gross commissionable ≠ total sales price.
- Vertical splits apply a split percentage.

### 6.2 Rate Application

| Plan Rate Tier         | When Applied                                                                |
| ---------------------- | --------------------------------------------------------------------------- |
| Base Rate              | Always (when accelerators not triggered)                                    |
| Quarterly Accelerators | When quarterly cumulative attainment ≥ `Quarterly_Accelerator_Threshold__c` |
| Annual Accelerators    | When annual attainment ≥ `Annual_Accelerator_Threshold__c`                  |

- Multiple Comp_Calculation\_\_c records are created per rate tier per rep per plan.
- The highest applied percentage is tracked in the `Applied_Percentage__c` field.

### 6.3 Accelerator Eligibility

- `Accelerators_Eligible__c = true` on Comp_Calculation\_\_c indicates accelerators were triggered.
- Historical accelerators can be applied via `Historical_Accelerators_Applied__c`.
- Quarterly and annual accelerators are mutually exclusive per tier but both can exist on a single opportunity.

### 6.4 Multi-Year Credits

- If deal term ≥ `Multi_Year_Min_Term_in_Years__c`, a bonus commission (`Multi_Year_Bonus_Rate__c`) is added.
- Capped by `Multi_Year_Deal_Cap__c` per deal and `Multi_Year_Plan_Cap__c` per plan.

### 6.5 Penalty

- If deal term < `Min_Term_in_Years_for_Penalty__c`, commission is reduced by `Penalty__c` percentage.
- Formula: `commission = commission * (100 - penalty) / 100`

### 6.6 Commission on Net (FX)

- When `Commission_on_Net__c = true`, commissions are computed on net amount after FX conversion.
- `Fx_Rate__c` on Comp_Calculation\_\_c stores the applied exchange rate.

### 6.7 Percent Collected Adjustment

- For non-revenue plans where `New_Percent_Collected__c < 100%`, commission due is reduced proportionally:  
  `compDue = (baseRate + qtrAcc + annualAcc) × percentCollected / 100`

### 6.8 Rev Rec (Revenue Recognition) Based Commissions

- A separate constructor `CommissionsProcessFY19(ID, Decimal, Date, String)` handles Rev Rec events.
- Only plans with `Commissions_Based_On__c = 'Revenue'` are processed.
- Rev Rec value and date are passed in; prior commissions on non-Revenue plans are zeroed out to avoid double payment.

---

## 7. Reprocessing Logic (BSSALES-59)

When an opportunity's commissions have already been processed:

1. System checks if any newly eligible reps exist that were not part of the original calculation.
2. If new reps are found, `askForReprocess = true` is set and displayed to the user.
3. User can trigger reprocess; only the new/delta records are added to existing Comp_Calculation records.
4. Existing records are preserved; new ones are added alongside.

---

## 8. Draws, Advances & Paybacks

### 8.1 Commission_Draw\_\_c Types

| Type    | Effect on Balance                   |
| ------- | ----------------------------------- |
| Draw    | Increases `draw_balance__c` on User |
| Advance | Increases `draw_balance__c` on User |
| Payback | Decreases `draw_balance__c` on User |

### 8.2 Trigger Behavior (CommissionDrawTrigger)

- **Before Insert:** Sets Beginning_Balance and Ending_Balance; updates User.draw_balance\_\_c
- **Before Update:** Adjusts balance by delta (new amount − old amount)
- **Before Delete:** Reverses the draw/advance/payback from User.draw_balance\_\_c
- Balance floor is 0 (never goes negative).

### 8.3 Admin Dashboard — Draw Tracking

- Draws are grouped per Opportunity + Rep (not per quota category).
- Delta = `compDue − compPaid − clawback + draws`

---

## 9. Dashboards & UI

### 9.1 Admin Commission Dashboard (`CommissionsAdminDashBoard`)

**Controller:** `CommissionsAdminDashboardController`

**Filters:**

- Fiscal Year (current FY and 3 prior)
- Opportunity (lookup)
- Rep (all Salesforce-licensed users)
- Record Type (All, Subscription, Renewal, Services, Training)

**Data Displayed per Row (grouped by Opportunity + Rep + Quota Category):**
| Column | Description |
|---|---|
| Opportunity | Name and close date |
| Record Type | Subscription, Renewal, Services, etc. |
| Rep Name | Sales rep |
| Rep Category | AE, BDR, SE, CSM, etc. |
| Plan Type | Comp plan type |
| Plan Category | Quota category |
| Commissionable Value | Sum of commissionable value |
| Rate | Highest applied base rate |
| Base Commission | Sum of base rate commissions |
| Qtr Accelerator Rate | Highest quarterly accelerator rate |
| Qtr Accelerator | Sum of quarterly accelerator commissions |
| Annual Accelerator Rate | Highest annual accelerator rate |
| Annual Accelerator | Sum of annual accelerator commissions |
| Y1 Commissionable Amount | Year 1 fully commissionable amount |
| % Collected | New % collected on opportunity |
| Comp Due | Total commission owed |
| Comp Paid | Total commission paid (from Payment_Detail**c) |
| Clawback | Clawback amount (from Commission_Draw**c) |
| Draws | Draw/advance amount |
| Delta | Comp Due − Comp Paid − Clawback + Draws |

**Export:** Excel export via `CommissionsAdminDashBoardExport` page (chunked into 1,000-record sets).

### 9.2 Rep Commission Dashboard (`commissiondb` / `commissiondb2`)

**Controller:** `commissiondbController` / `commissiondbController2`

**Personal view showing:**

- Current FY and prior FY date ranges
- Quarterly gauge charts (Q1–Q4, YTD, FY attainment)
- Per-plan summary: attainment, attainment rate, draw balance
- Paid commissions list (current month / filtered)
- Upcoming commissions (this month and next month)
- Unpaid commissions breakdown
- Commission breakdown by opportunity
- Draw balance

### 9.3 Process Commissions Page (`Process_Commissions_FY19`)

- Launched from an Opportunity record.
- Displays all Comp Calculation results before committing.
- Allows add/remove of reps and comp plans.
- Shows base rate, quarterly accelerator, annual accelerator per rep/plan.
- Commit button saves all Comp_Calculation\_\_c records.
- Reprocess prompt shown when new eligible reps are detected.

---

## 10. Report Types

| Report Type                               | Description                                  |
| ----------------------------------------- | -------------------------------------------- |
| Commission_Draws                          | Commission Draw records                      |
| Commissions_with_Opportunities            | Commission records joined with Opportunities |
| Comp_Plans_with_Commissions               | Comp Plans with linked Comp Calculations     |
| Opportunities_with_or_without_Commissions | All opps with/without commission records     |
| Opps_with_Commission_Draws                | Opportunities joined with Commission Draws   |
| Processed_Commissions                     | Fully processed commission records           |
| Opps_with_Comp_Calculations               | Opportunities joined with Comp Calculations  |
| Users_and_Comp_Plans                      | Users with their Comp Plans                  |

---

## 11. Permission Sets

| Permission Set            | Access Granted                           |
| ------------------------- | ---------------------------------------- |
| Access_to_Commissions_Tab | Access to the Commissions tab in the app |

---

## 12. Integration Points

| Integration                 | Description                                                                                       |
| --------------------------- | ------------------------------------------------------------------------------------------------- |
| Collections\_\_c            | BDR payment details created via Collections trigger (not CommissionsProcessFY19 as of BSSALES-56) |
| Payment_Detail\_\_c         | Payment records tracked per Opportunity + Rep + Quota Category; used to calculate Comp Paid       |
| Eligible_Comp_Renewals\_\_c | Specifies additional reps eligible for commission on Renewal opportunities                        |
| Revenue_Recognition\_\_c    | Triggers Rev Rec-based commission processing                                                      |
| VF_Dates\_\_c               | Custom setting driving fiscal year date boundaries on the rep dashboard                           |
| User.draw_balance\_\_c      | Maintained by CommissionDrawTrigger                                                               |

---

## 13. Key Business Rules

1. **Single Process per Deal (Non-Subscription):** For non-Subscription record types, commissions can only be processed once. For Subscription, they can be reprocessed if the opportunity is still at New Opportunity stage.
2. **Probability Gate for Services:** Services commissions are only calculated when `Probability = 100`.
3. **Accelerator Cap:** Commissions are capped per plan via Cap_Percentage**c or Cap_Amount**c; single-deal cap via Cap_on_Single_Deal\_\_c.
4. **Null-safe balance:** User draw balance never drops below 0.
5. **FY Bucketing:** Comp Calculations are bucketed by `Contract_Date2__c` into fiscal years, not close date.
6. **Prior Year Commissions:** If a rep previously had commissions on a deal under a non-Revenue plan and is now being processed under a Revenue plan, the eligible commission is set to 0 with `Additional_Info__c = 'Prior Year Commissions'`.
7. **Manager Hierarchy:** Both direct and indirect managers in the commission hierarchy receive comp calculations when eligible plans exist.
8. **Hold Logic:** Plans with `Hold_Type__c`, `Target_Hold__c`, or `Base_Rate_Hold__c` flags delay payment without suppressing calculation.

---

## 14. Known Technical Issues / Historical Fixes

| Story      | Date         | Description                                                                                                             |
| ---------- | ------------ | ----------------------------------------------------------------------------------------------------------------------- |
| BSSALES-56 | Jan 2019     | BDR payment detail creation moved from commissions process to Collections trigger                                       |
| BSSALES-59 | Mar 2019     | Reprocess commissions when new people become newly eligible                                                             |
| BSSALES-64 | May 2019     | FY20 Software commission enhancements                                                                                   |
| BSSALES-66 | May–Jun 2019 | Rev Rec handling; Services Rev Rec; Global & Regional plans for Revenue-based plans; DCP/CSA moved to Opportunity-level |
| BSSALES-81 | Aug 2019     | Fix hold payment & draw balance issue                                                                                   |
| BSSALES-83 | Aug 2019     | Fix: Individual plan absence no longer blocks Global/Regional Revenue-based plans                                       |

---

## 15. Glossary

| Term             | Definition                                                                    |
| ---------------- | ----------------------------------------------------------------------------- |
| AE               | Account Executive (Opportunity Owner)                                         |
| AGM              | Area General Manager                                                          |
| BDR              | Business Development Representative                                           |
| SE               | Solutions Engineer                                                            |
| CSM              | Customer Success Manager                                                      |
| CSD              | Customer Success Director                                                     |
| DCP              | Digital Client Partner                                                        |
| CSA              | Customer Success Architect                                                    |
| PAM              | Partner Account Manager                                                       |
| FY               | Fiscal Year (Kony fiscal year, not calendar year)                             |
| Comp Plan        | Compensation Plan — defines quota, rates, accelerators for a rep              |
| Comp Calculation | A calculated commission record per deal/rep/rate-tier                         |
| Draw             | An advance against future earned commissions                                  |
| Clawback         | Recovery of previously paid commission                                        |
| Rev Rec          | Revenue Recognition — a separate trigger for commission on recognized revenue |
| NQR              | No Quota Retirement — commission paid but quota not counted toward attainment |
| KPS              | Kony Professional Services                                                    |
