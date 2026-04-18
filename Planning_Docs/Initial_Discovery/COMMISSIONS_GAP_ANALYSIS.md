# Commissions Module — Gap Analysis

**What Was Built (KONY ORG) vs. What Was Planned**

**Sources:**

- Built: KONY ORG Salesforce metadata + Apex code (`CommissionsProcessFY19`, `commissiondbController`, etc.)
- Planned: `Industry based Plan Details.docx` + `Sales Commissions.xlsx` (Processed, Sheet5, Industries tabs)

---

## 1. Executive Summary

The KONY ORG Commissions module is a **solid but narrowly scoped** implementation. It handles the specific commission plan types used by a SaaS company (Kony) well — quota-based attainment, accelerators, multi-role eligibility, draws, and rev rec. However, the planning documents describe a **general-purpose, multi-industry commission platform**, and by that measure approximately **60–65% of the planned feature set is missing or only partially implemented**.

---

## 2. Feature Coverage Matrix

### 2.1 Plan Types

| Plan Type                                | Planned | Built | Status      | Notes                                                                                      |
| ---------------------------------------- | ------- | ----- | ----------- | ------------------------------------------------------------------------------------------ |
| Revenue-Based (Booking/ARR)              | ✓       | ✓     | **Built**   | `Commissions_Based_On__c = Booking`                                                        |
| Revenue Recognition (Rev Rec)            | ✓       | ✓     | **Built**   | Separate constructor, Revenue-based plans                                                  |
| Renewal-Based                            | ✓       | ✓     | **Built**   | Renewal record type + `Eligible_Comp_Renewals__c`                                          |
| Quota-Based                              | ✓       | ✓     | **Built**   | FY/Quarterly targets + attainment tracking                                                 |
| Flat Rate (fixed %)                      | ✓       | ✓     | **Partial** | Base_Rate\_\_c exists, but no "flat rate ignoring quota" mode                              |
| Accelerated / Ramp-Up                    | ✓       | ✓     | **Built**   | Quarterly + Annual accelerators with thresholds                                            |
| Commission on Net / Gross Revenue        | ✓       | ✓     | **Partial** | `Commission_on_Net__c` + FX rate; no true gross margin engine                              |
| Upfront + Residual / Recurring           | ✓       | ✗     | **Missing** | Upfront pay exists; no recurring/trail commission on active subscriptions                  |
| Land-and-Expand / Upsell                 | ✓       | ✗     | **Missing** | No expansion revenue tracking or differentiated upsell rate                                |
| Product-Specific Rates                   | ✓       | ✓     | **Partial** | `Product_Classification__c` filter on plan; not a full per-SKU rate table                  |
| Tiered (multi-band rates on single deal) | ✓       | ✗     | **Missing** | Accelerators are attainment-threshold based; no band-by-band % on deal value               |
| Activity-Based / Multi-Metric            | ✓       | ✗     | **Missing** | No commissions on demos, meetings, calls — only on closed deals                            |
| Milestone-Based (staged payouts)         | ✓       | ✗     | **Missing** | Commissions fire only at deal close; no deal-stage milestone triggers                      |
| Territory-Based                          | ✓       | ✗     | **Missing** | Commission_Region\_\_c field exists but no territory management object or assignment logic |
| Team Sharing / Bonus Pool                | ✓       | ✗     | **Missing** | Multi-role eligibility exists but no configurable team pool or split percentage            |
| Split Commissions (configurable %)       | ✓       | ✗     | **Missing** | Roles share commissions but split % is hardcoded in Apex, not configurable                 |
| Deferred / Vesting                       | ✓       | ✗     | **Missing** | No payment deferral schedule (e.g., pay 33% at close, 33% at M3, 33% at M6)                |
| Hybrid Plans                             | ✓       | ✓     | **Partial** | Multi-plan setup possible; no declarative "combine plan types" configuration               |
| Gross Margin / Profit-Based              | ✓       | ✗     | **Missing** | `Commission_on_Net__c` is FX-based; no cost/margin calculation engine                      |
| Windfall Deal Handling                   | ✓       | ✓     | **Partial** | `Cap_on_Single_Deal__c` caps oversized deals; no windfall detection/approval workflow      |
| Multi-Year Bonus                         | ✓       | ✓     | **Built**   | `Multi_Year_Bonus_Rate__c`, min term, deal/plan caps                                       |
| Penalty for Short-Term Deals             | ✓       | ✓     | **Built**   | `Min_Term_in_Years_for_Penalty__c` + `Penalty__c`                                          |
| Recurring / Residual (trail)             | ✓       | ✗     | **Missing** | No monthly/quarterly residual on active subscriptions                                      |
| First-Year + Trail Commission            | ✓       | ✗     | **Missing** | No trail commission structure                                                              |
| Cost-Savings Commission                  | ✓       | ✗     | **Missing** | No mechanism to base commission on customer cost savings                                   |
| Performance-Based (CSAT/NPS)             | ✓       | ✗     | **Missing** | `KPS_NPS_Hold_Back__c` holds payment; no CSAT-driven calculation                           |
| New Client / New Product Incentive       | ✓       | ✓     | **Partial** | BDR SPIFF for new deals; no configurable "new client premium rate"                         |
| MRR/ARR Commission                       | ✓       | ✓     | **Partial** | ARR-style booking commissions exist; MRR monthly slicing not automated                     |

---

### 2.2 Core Data Model / Tables

| Component                              | Planned (Processed Sheet) | Built | Status      | Notes                                                                     |
| -------------------------------------- | ------------------------- | ----- | ----------- | ------------------------------------------------------------------------- |
| Plan Definition Table                  | ✓                         | ✓     | **Built**   | `Comp_Plan__c`                                                            |
| Characteristics of Plan (flat rate, %) | ✓                         | ✓     | **Built**   | Base_Rate**c, Accelerated_Rate**c, etc.                                   |
| Tier Table                             | ✓                         | ✓     | **Partial** | Accelerator thresholds exist; no generic multi-tier rate table            |
| Characteristics of Tier (hold, hold %) | ✓                         | ✓     | **Partial** | Hold flags exist; no configurable hold % for partial payments             |
| Draws Table                            | ✓                         | ✓     | **Built**   | `Commission_Draw__c`                                                      |
| Clawbacks Table                        | ✓                         | ✓     | **Built**   | `Commission_Draw__c` Type = Payback/Clawback                              |
| Calculated Commissions Table           | ✓                         | ✓     | **Built**   | `Comp_Calculation__c`                                                     |
| Hold Commissions Table                 | ✓                         | ✓     | **Partial** | Hold_Reason**c on Comp_Calculation**c; no dedicated hold release workflow |
| Payments Table                         | ✓                         | ✓     | **Built**   | `Payment_Detail__c`                                                       |
| User and Plan Association Table        | ✓                         | ✓     | **Built**   | Sales_Rep**c on Comp_Plan**c                                              |
| Child of Plan Table                    | ✓                         | ✓     | **Partial** | `Dependent_Plan__c` lookup; limited to single parent threshold            |
| Territory Object                       | ✓                         | ✗     | **Missing** | No Territory\_\_c object; only a text Region field                        |
| Team / Bonus Pool Table                | ✓                         | ✗     | **Missing** | No team grouping or pool object                                           |
| Customer Table (for retention-based)   | ✓                         | ✗     | **Missing** | Account exists in SF; no commission-specific customer retention metrics   |
| Pipeline Data for Forecasting          | ✓                         | ✗     | **Missing** | Opportunity pipeline exists; not connected to commission forecasting      |
| Deal Data Ingestion (Excel/API)        | ✓                         | ✗     | **Missing** | No bulk import mechanism; data must be entered via Salesforce UI          |

---

### 2.3 Process & Workflow Features

| Feature                          | Planned | Built | Status      | Notes                                                                      |
| -------------------------------- | ------- | ----- | ----------- | -------------------------------------------------------------------------- |
| Commission Calculation Engine    | ✓       | ✓     | **Built**   | `CommissionsProcessFY19.process()`                                         |
| Calculation Approval Workflow    | ✓       | ✗     | **Missing** | No approval before commissions are committed                               |
| Plan Definition Workflow         | ✓       | ✗     | **Missing** | No workflow for plan creation/review/publishing cycle                      |
| Plan Acceptance / eSignature     | ✓       | ✗     | **Missing** | No DocuSign/AdobeSign integration; reps cannot formally accept their plans |
| Executive Approval on Tiers      | ✓       | ✗     | **Missing** | No approval step for accelerator or tier changes                           |
| Plan Rollout Process             | ✓       | ✗     | **Missing** | No structured rollout/activation workflow                                  |
| Payment Processing               | ✓       | ✓     | **Partial** | Payment_Detail\_\_c records created; no payroll export/integration         |
| Automated Email Notifications    | ✓       | ✗     | **Missing** | No emails to reps when commissions are processed or paid                   |
| Reprocessing (new eligible reps) | ✓       | ✓     | **Built**   | BSSALES-59 implemented                                                     |
| Hold Release Workflow            | ✓       | ✗     | **Missing** | No automated or approval-based release of held commissions                 |
| Dispute / Adjustment Process     | ✓       | ✗     | **Missing** | No formal commission dispute or manual adjustment workflow                 |

---

### 2.4 Integrations

| Integration                       | Planned | Built | Status      | Notes                                          |
| --------------------------------- | ------- | ----- | ----------- | ---------------------------------------------- |
| CRM (Salesforce)                  | ✓       | ✓     | **Built**   | Native Salesforce app                          |
| Payroll System                    | ✓       | ✗     | **Missing** | No payroll export; payments tracked in SF only |
| ERP                               | ✓       | ✗     | **Missing** | No ERP integration                             |
| eSignature (DocuSign / AdobeSign) | ✓       | ✗     | **Missing** | No plan acceptance signature                   |
| Excel Data Import                 | ✓       | ✗     | **Missing** | No bulk import for deal or plan data           |
| External API for Data Ingestion   | ✓       | ✗     | **Missing** | No REST/SOAP API layer for external data       |

---

### 2.5 Dashboards & Reporting

| Feature                                      | Planned | Built | Status      | Notes                                                    |
| -------------------------------------------- | ------- | ----- | ----------- | -------------------------------------------------------- |
| Rep Commission Dashboard                     | ✓       | ✓     | **Built**   | `commissiondb` VF page with gauges, paid/unpaid/upcoming |
| Admin Commission Dashboard                   | ✓       | ✓     | **Built**   | `CommissionsAdminDashBoard` with FY/rep/opp/type filters |
| Excel Export                                 | ✓       | ✓     | **Built**   | `CommissionsAdminDashBoardExport`                        |
| Standard SF Reports                          | ✓       | ✓     | **Built**   | 8 commission report types                                |
| Potential / Estimated Commissions (pipeline) | ✓       | ✗     | **Missing** | No "what-if" earnings estimate based on open pipeline    |
| Commission Forecasting                       | ✓       | ✗     | **Missing** | No forecasting against quota trajectory                  |
| Planning & Regression Analysis               | ✓       | ✗     | **Missing** | No quota planning tools or historical trend analysis     |
| Real-Time Leaderboards / Gamification        | ✓       | ✗     | **Missing** | No leaderboard, peer comparison, or achievement tracking |
| Mobile App / Mobile-Responsive UI            | ✓       | ✗     | **Missing** | VF pages are not mobile-optimized                        |
| AI-Driven Forecasting / Recommendations      | ✓       | ✗     | **Missing** | No ML/AI layer                                           |

---

### 2.6 Multi-Industry Support

The planning documents specifically document plan structures across 7 industries. The KONY ORG implementation is exclusively designed for **SaaS/Technology**. All other verticals are unsupported.

| Industry                       | Supported Plans Documented                                           | Built for This Industry |
| ------------------------------ | -------------------------------------------------------------------- | ----------------------- |
| Software & Technology (SaaS)   | MRR/ARR, Quota, Accelerators, Net Revenue, Renewal, Upsell           | ✓ Majority built        |
| Healthcare & Pharmaceuticals   | Milestone, Activity-Based, Deferred, Team-Based, Recurring           | ✗ None                  |
| Financial Services & Insurance | Trail Commission, Persistency/Retention, Deferred/Vesting, Fee-Based | ✗ None                  |
| Real Estate                    | Split, Graduated, Referral, 100% Commission                          | ✗ None                  |
| Manufacturing & Industrial     | Territory, Gross Margin, Cost-Savings, New Client Incentive          | ✗ None                  |
| Telecommunications             | MRR Recurring, Residual/Retention, Performance Milestone             | ✗ None                  |
| Retail & Consumer Goods        | Volume-Based, Category-Based, Seasonal, Clawback on Returns          | ✗ None                  |

---

## 3. Consolidated Gap List (Priority Ordered)

### Critical Gaps — Core Platform Functionality

| #   | Gap                                          | Impact                                                                                                     |
| --- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| 1   | **Deferred / Vesting Payment Schedules**     | Cannot pay commissions in installments over time; entire commission is paid at once                        |
| 2   | **Tiered Rate Bands on Deal Value**          | Cannot define "5% on first $50K, 7% on next $50K, 10% above $100K" within a single deal                    |
| 3   | **Team Sharing / Bonus Pool**                | Cannot define a pool, fund it, and distribute to a team; multi-role is hardcoded in Apex                   |
| 4   | **Configurable Commission Split %**          | Role contribution percentages are not configurable; can't say "AE gets 70%, CSM gets 30%"                  |
| 5   | **Territory Management**                     | No territory object; no ability to assign accounts/opportunities to territories and commission accordingly |
| 6   | **Recurring / Residual (Trail) Commissions** | No automated monthly/quarterly commission on active subscription renewals                                  |
| 7   | **Activity-Based Commission Triggers**       | No way to pay commissions on demos, calls, meetings, or sales activities                                   |
| 8   | **Milestone-Based Commission Triggers**      | No way to pay partial commissions at deal stages (e.g., 30% at proposal, 70% at close)                     |
| 9   | **Plan Acceptance / eSignature Workflow**    | Reps cannot formally accept/sign their compensation plans                                                  |
| 10  | **Hold Release Workflow**                    | Held commissions have no automated or approval-based release process                                       |

### High Priority Gaps — Operational Completeness

| #   | Gap                                         | Impact                                                                                |
| --- | ------------------------------------------- | ------------------------------------------------------------------------------------- |
| 11  | **Payroll Integration / Export**            | Payment amounts tracked in Salesforce but cannot be exported to ADP, Workday, etc.    |
| 12  | **Partial Hold %**                          | A commission can be fully held but not partially held (e.g., pay 50% now, hold 50%)   |
| 13  | **Automated Email Notifications**           | Reps receive no system notification when commissions are processed, approved, or paid |
| 14  | **Commission Dispute / Adjustment Process** | No formal dispute workflow; adjustments require direct record edits                   |
| 15  | **Potential Commission Estimator**          | Reps cannot see projected earnings based on pipeline opportunities                    |
| 16  | **Gross Margin Commission Engine**          | No cost/COGS tracking; cannot compute commission on true profit margin                |
| 17  | **Data Ingestion via Excel / API**          | No bulk import; every comp plan and deal must be managed through Salesforce UI        |
| 18  | **Land-and-Expand / Upsell Commission**     | No mechanism to identify expansion ARR vs. initial ARR and apply different rates      |
| 19  | **Windfall Deal Approval Workflow**         | Large deals are capped but no approval workflow or notification for windfall deals    |
| 20  | **First-Year + Trail Commission Structure** | Cannot define a high Year 1 rate with a lower ongoing trail rate declaratively        |

### Medium Priority Gaps — Reporting & Intelligence

| #   | Gap                                         | Impact                                                           |
| --- | ------------------------------------------- | ---------------------------------------------------------------- |
| 21  | **Commission Forecasting**                  | Finance cannot forecast commission expense against open pipeline |
| 22  | **Quota Planning Tools**                    | No tools to model and assign quotas; done outside Salesforce     |
| 23  | **Performance Trend / Regression Analysis** | No historical attainment analysis to benchmark plans             |
| 24  | **Real-Time Leaderboards / Gamification**   | No competitive visibility for reps; reduces motivation           |
| 25  | **Mobile-Optimized Interface**              | Visualforce pages not usable on mobile devices                   |
| 26  | **ERP Integration**                         | No connection to financial systems for revenue and cost data     |

### Low Priority Gaps — Advanced / Future State

| #   | Gap                                          | Impact                                                                                  |
| --- | -------------------------------------------- | --------------------------------------------------------------------------------------- |
| 27  | **AI-Driven Commission Forecasting**         | No ML recommendations for plan optimization                                             |
| 28  | **Customer Retention Metrics in Commission** | CSAT/NPS/churn rate cannot drive commission adjustments                                 |
| 29  | **Multi-Industry Plan Templates**            | Cannot onboard a healthcare, financial services, or telecom company without custom Apex |
| 30  | **Cost-Savings Commission Model**            | Cannot base commission on value delivered / client cost reduction                       |

---

## 4. What Was Built Well

These areas of the KONY implementation are **solid and production-grade**:

| Area                                  | Strength                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------- |
| Quota-based attainment + accelerators | Full Q1–Q4 + YTD + FY tracking with quarterly and annual accelerator tiers            |
| Multi-role eligibility                | 8+ roles (AE, BDR, SE, CSM, DCP, CSA, PAM, Managers) with deal-type-specific rules    |
| Manager hierarchy commissions         | Automatic inclusion of commission managers via `addCommissionsManagers()`             |
| Rev Rec-based commissions             | Separate processing path for revenue-recognition-triggered plans                      |
| Draw / Advance / Payback cycle        | Full draw balance tracking with Before trigger on insert/update/delete                |
| Multi-year bonus + short-term penalty | Configurable per plan with caps                                                       |
| Reprocessing for newly eligible reps  | BSSALES-59: detects delta, prompts user, adds new records without destroying existing |
| Dependent plan thresholds             | Plan B only pays if Plan A meets threshold                                            |
| FX / Commission on Net                | Exchange rate capture and net commission calculation                                  |
| Admin dashboard + Excel export        | Filterable by FY, Opp, Rep, Record Type; chunked Excel export                         |
| FY bucketing by contract date         | Uses `Contract_Date2__c` not close date, preventing fiscal year misalignment          |

---

## 5. Gap Count Summary

| Category               | Total Features Planned | Built / Partial | Missing      |
| ---------------------- | ---------------------- | --------------- | ------------ |
| Plan Types             | 26                     | 14 (54%)        | 12 (46%)     |
| Data Model / Tables    | 15                     | 9 (60%)         | 6 (40%)      |
| Process & Workflow     | 11                     | 5 (45%)         | 6 (55%)      |
| Integrations           | 6                      | 1 (17%)         | 5 (83%)      |
| Dashboards & Reporting | 10                     | 5 (50%)         | 5 (50%)      |
| Multi-Industry Support | 7 industries           | 1 (14%)         | 6 (86%)      |
| **Total**              | **75**                 | **35 (47%)**    | **40 (53%)** |

---

## 6. Recommended Build Order for Missing Features

If building toward the full planned platform, this sequencing minimizes rework:

**Phase 1 — Data Model Foundations (enables everything else)**

- Territory object + assignment
- Team / Bonus Pool object
- Tiered Rate Band table (child of Plan)
- Partial Hold % on Comp_Calculation\_\_c

**Phase 2 — Commission Calculation Engine Gaps**

- Tiered band-by-band rate calculation
- Configurable commission split %
- Milestone-based triggers (Opportunity stage → commission events)
- Recurring/residual trail commission scheduler
- Deferred/vesting payment schedule

**Phase 3 — Workflow & Operations**

- Plan acceptance with eSignature integration
- Automated email notifications (commission processed, paid, disputed)
- Dispute and manual adjustment workflow
- Hold release workflow with approval

**Phase 4 — Integrations**

- Payroll export (flat file / API)
- Excel / API data ingestion for bulk plan + deal data
- ERP integration for cost/margin data

**Phase 5 — Rep Intelligence**

- Potential commission estimator (pipeline × rate)
- Commission forecasting dashboard
- Leaderboards / gamification

**Phase 6 — Advanced**

- Multi-industry plan templates
- AI/ML forecasting layer
- Mobile-optimized LWC rebuild
