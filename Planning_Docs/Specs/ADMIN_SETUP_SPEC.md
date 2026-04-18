# RevenueTrust — Admin Setup, Onboarding & Quota Management Spec

**Version:** 1.2  
**Date:** April 15, 2026  
**Status:** LOCK CANDIDATE — V1.2 feedback incorporated  
**Companion specs:** FORECASTING_OBJECT_MODEL.md V1.4, INCENTIVES_OBJECT_MODEL.md V2.0, FORECASTING_APEX_CONTROLLERS.md V1.1  
**Depends on:** All deployed Apex + LWC from Forecasting module

---

## 1. Overview

Three components, one unified admin experience:

```
┌──────────────────────────────────────────────────────────────────────┐
│                    REVENUETRUST ADMIN EXPERIENCE                     │
│                                                                      │
│  ┌────────────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
│  │  Onboarding Wizard │  │  Admin Console   │  │ Quota Manager   │ │
│  │  (First-time setup)│  │  (Ongoing config)│  │ (Targets/Goals) │ │
│  │                    │  │                  │  │                 │ │
│  │  Org discovery     │  │  Modify settings │  │  Simplified     │ │
│  │  Hierarchy source  │  │  Metrics/Cats    │  │  quota setup    │ │
│  │  Metrics/Categories│  │  Period mgmt     │  │  for Forecast-  │ │
│  │  Period generation │  │  Participant sync│  │  only customers │ │
│  │  Participant init  │  │  Attainment src  │  │                 │ │
│  └────────────────────┘  └──────────────────┘  └─────────────────┘ │
│         ↓                        ↓                      ↓           │
│     Runs ONCE              Runs ANYTIME           Runs PER PERIOD   │
│  (post-install)          (admin access)         (quota assignment)   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Onboarding Wizard (First-Time Setup)

### 2.1 Entry Point

- **When:** First launch of RevenueTrust app after package install
- **Who:** System Administrator or user with `RevenueTrust_Full_Access` permission set
- **How:** If no active `Forecast_Configuration__c` exists, the Forecast tab shows the wizard instead of the grid
- **Duration:** 5-10 minutes

### 2.2 Wizard Steps

#### Step 1: Org Discovery (Automated — no user input)

The wizard queries the org and displays what it finds:

| Discovery Check      | What We Query                                                                     | What We Learn                          |
| -------------------- | --------------------------------------------------------------------------------- | -------------------------------------- |
| Hierarchy source     | `UserRole`, Territory2, Manager field on User                                     | Which hierarchy model the org uses     |
| Opportunity stages   | `OpportunityStage` (via describe)                                                 | Available stages, which are closed/won |
| Record types         | `RecordType WHERE SObjectType = 'Opportunity'`                                    | Record type filtering needs            |
| Currency             | `Organization.IsMultiCurrencyOrganization`                                        | Single vs. multi-currency              |
| Fiscal year          | `Organization.FiscalYearStartMonth`, `Organization.UsesStartDateAsFiscalYearName` | Period generation alignment            |
| Existing forecasting | Standard Forecasting enabled?                                                     | Migration considerations               |
| User count           | Active Users with Opportunity access                                              | Participant volume                     |
| Opportunity volume   | `COUNT() FROM Opportunity WHERE IsClosed = false`                                 | Pipeline size for performance tuning   |

**Display:** Summary card showing discovered configuration with green/yellow/red indicators.

#### Step 2: Hierarchy Source Selection

> How is your sales team organized?

| Option                   | Source           | Description                                                        |
| ------------------------ | ---------------- | ------------------------------------------------------------------ |
| **Role Hierarchy**       | `UserRole`       | Standard Salesforce role hierarchy. Most common.                   |
| **Manager Hierarchy**    | `User.ManagerId` | Direct manager chain. Simpler orgs.                                |
| **Territory Management** | `Territory2`     | Enterprise territory model. Requires Territory Management enabled. |
| **Custom Field**         | Configurable     | Customer uses a custom field on Opportunity for scope assignment.  |

**Action:** Sets `Forecast_Configuration__c.Scope_Determination__c` and creates `Hierarchy_Source__mdt` record.

#### Step 3: Terminal Stage Configuration

> Which stages indicate a deal is Closed Won? Which indicate Closed Lost?

Auto-populated from `OpportunityStage.IsClosed` and `OpportunityStage.IsWon`. Admin can verify/override.

| Setting            | Auto-detected                                 | Admin Override |
| ------------------ | --------------------------------------------- | -------------- |
| Closed Won stages  | All where `IsWon = true`                      | Checkbox list  |
| Closed Lost stages | All where `IsClosed = true AND IsWon = false` | Checkbox list  |

#### Step 4: Forecast Metrics

> What values do your sales team forecast?

| Pre-selected | Metric Name       | Type         | Source Field        |
| ------------ | ----------------- | ------------ | ------------------- |
| ✅ (default) | Revenue           | Currency     | `Amount`            |
| ☐            | ACV               | Currency     | Custom field picker |
| ☐            | Quantity          | Number       | Custom field picker |
| ☐            | Custom Metric 1-3 | User-defined | Custom field picker |

**Max 6 metrics.** Each metric: label, type (Currency/Number/Percent), editable flag, source field mapping.

**Action:** Creates `Forecast_Metric__c` records linked to configuration.

#### Step 5: Forecast Categories

> How does your team classify deal confidence?

| Pre-built Template         | Categories                                                     |
| -------------------------- | -------------------------------------------------------------- |
| **Standard (recommended)** | Commit, Best Case, Pipeline, Closed Won, Lost                  |
| **Simple**                 | Commit, Pipeline, Closed, Lost                                 |
| **Enterprise**             | Commit, Upside, Best Case, Pipeline, Omitted, Closed Won, Lost |
| **Custom**                 | Admin defines 3-8 categories                                   |

Each category: label, API name, color (hex picker), counts toward target, is terminal, sort order, regression warning.

**Action:** Creates `Forecast_Category__c` records.

#### Step 6: Period Configuration

> How do you forecast?

| Question                         | Options                          |
| -------------------------------- | -------------------------------- |
| Period type                      | Monthly, Quarterly, Annual       |
| How many future periods visible? | 1-6 (default: 3)                 |
| Fiscal year start month          | Auto-detected from org, editable |
| Budget mode support?             | Yes / No                         |

**Action:** Sets config fields + generates initial periods via `ForecastPeriodGeneratorBatch`.

#### Step 7: Attainment Source

> How should attainment (achieved amount) be calculated?

| Option                 | Description                                | Best For                            |
| ---------------------- | ------------------------------------------ | ----------------------------------- |
| **Quota Record**       | Reads from `Quota__c` in Incentives module | Orgs using RevenueTrust Commissions |
| **Live from Forecast** | Computes from Closed Won overrides         | Forecasting-only customers          |
| **Hybrid**             | Quota if available, fallback to live       | Transitioning orgs                  |

#### Step 8: Participant Initialization

> Who should be included in this forecast period?

| Option                       | Description                                                                                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Auto-sync from hierarchy** | Discovers all users in the chosen hierarchy and creates `Forecast_Participant__c` records. Shows preview count: "Found 47 users across 4 levels." |
| **Manual selection**         | Admin picks users/roles to include.                                                                                                               |
| **Import from CSV**          | Upload user list with scope/level assignments.                                                                                                    |

**Action:** Runs `ForecastInitializationBatch` for the first open period.

#### Step 9: Review & Activate

Summary screen showing all choices with "Change" links for each section.

**Activate button:**

1. Creates `Forecast_Configuration__c` with `Is_Active__c = true`
2. Generates periods
3. Initializes participants
4. Shows success: "RevenueTrust Forecasting is ready! Open the Forecast tab to start."

### 2.3 Onboarding Wizard — Technical Design

| Aspect              | Approach                                                                               |
| ------------------- | -------------------------------------------------------------------------------------- |
| **LWC Component**   | `revtOnboardingWizard` — multi-step flow using `lightning-progress-indicator`          |
| **Placement**       | Replaces `revtForecastApp` content when no active config exists                        |
| **Apex Controller** | `OnboardingController.cls` — org discovery queries, config creation, period generation |
| **State**           | Wizard state stored in component JS (not persisted until Step 9 Activate)              |
| **Idempotent**      | Can be re-run — detects existing config and offers "Reconfigure" mode                  |

---

## 3. Admin Console (Ongoing Configuration)

### 3.1 Entry Point

- **Where:** Lightning Tab "RevenueTrust Admin" in the RevenueTrust app
- **Who:** Users with `RevenueTrust_Full_Access` permission set
- **When:** Anytime after onboarding

### 3.2 Admin Console Sections

#### 3.2.1 General Settings

| Setting                | Current Field                    | Editable?                                                     |
| ---------------------- | -------------------------------- | ------------------------------------------------------------- |
| Period Type            | `Period_Type__c`                 | Yes (warning: changing mid-year requires period regeneration) |
| Pagination Size        | `Pagination_Size__c`             | Yes                                                           |
| Currency Mode          | `Currency_Mode__c`               | Yes                                                           |
| Corporate Currency     | `Corporate_Currency__c`          | Yes                                                           |
| Attainment Source      | `Attainment_Source__c`           | Yes                                                           |
| Attainment Layout      | `Attainment_Layout__c`           | Yes                                                           |
| Top Level Action Label | `Top_Level_Lock_Label__c`        | Yes                                                           |
| Scope Determination    | `Scope_Determination__c`         | Yes (warning: changes hierarchy model)                        |
| Future Periods Visible | `Future_Periods_Visible__c`      | Yes                                                           |
| Hourly Snapshot Days   | `Hourly_Snapshot_Days__c`        | Yes                                                           |
| Record Type Filter     | `Pipeline_Record_Type_Filter__c` | Yes                                                           |

#### 3.2.2 Metrics Management

- **View:** Table of all `Forecast_Metric__c` records
- **Actions:** Add metric (up to 6), edit label/format/sort order, toggle editable, deactivate
- **Guard rails:** Cannot delete a metric that has override data. Can only deactivate.

#### 3.2.3 Categories Management

- **View:** Table of all `Forecast_Category__c` records with color swatches
- **Actions:** Add category, edit label/color/sort order, toggle active, set regression warning
- **Guard rails:** Cannot delete terminal categories (Closed Won, Lost). Cannot have fewer than 3 active categories.

#### 3.2.4 Period Management

- **View:** Timeline of all `Forecast_Period__c` records with status badges
- **Actions:**
  - Open a Scheduled period early
  - Close an Open period manually
  - Reopen a Frozen period (requires Platform_Admin)
  - Generate additional future periods
  - View period details (participant count, override count, snapshot count)

#### 3.2.5 Participant Management

- **View:** Table of `Forecast_Participant__c` for the current period
- **Group by:** Hierarchy level, scope, submission status
- **Actions:**
  - Re-sync from hierarchy source (add new users, remove departed)
  - Change hierarchy level for a participant
  - Set/remove delegate access
  - View submission status dashboard
  - Bulk status reset (for testing/re-forecast)

#### 3.2.6 Attainment Source Configuration

Same options as Onboarding Step 7, changeable anytime:

- Quota Record / Live from Forecast / Hybrid
- Preview: shows current attainment values under each mode before switching

### 3.3 Admin Console — Technical Design

| Aspect              | Approach                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------ |
| **LWC Component**   | `revtAdminConsole` — tabbed interface with sections                                        |
| **Placement**       | Lightning Tab "RevenueTrust Admin"                                                         |
| **Apex Controller** | `AdminConsoleController.cls` — CRUD for config, metrics, categories, periods, participants |
| **Permissions**     | `RevenueTrust_Full_Access` required. Field-level edits validated server-side.              |

---

## 4. Simplified Quota Manager (Forecasting-Only Customers)

### 4.1 Problem

The full Incentives module has sophisticated quota management:

- `Comp_Plan__c` → `Quota__c` → Commission tiers, rates, caps
- Plan templates, approval workflows, acceptance flows
- Territory-based distribution, mid-year adjustment workflows

**Forecasting-only customers don't need any of this.** They just need:

- "Jane has a $2M target for Q2 2026"
- "Bob has a $1.5M target for Q2 2026"
- Attainment shows as achieved / target

### 4.2 Design: Lightweight Quota Interface

#### Option A: Use existing `Quota__c` without `Comp_Plan__c`

Make `Comp_Plan__c` optional on `Quota__c`. Allow creating quotas directly for a user + period without a comp plan.

**Pros:** Reuses existing object. No new objects.  
**Cons:** `Quota__c` has many commission-specific fields (tier refs, calculation refs) that confuse forecasting-only admins.

#### Option B: New `Forecast_Quota__c` object (lightweight)

| #   | Field                     | Type                              | Description                |
| --- | ------------------------- | --------------------------------- | -------------------------- |
| 1   | `User__c`                 | Lookup(User)                      | The sales rep              |
| 2   | `Forecast_Period__c`      | Lookup(Forecast_Period\_\_c)      | Which period               |
| 3   | `Forecast_Participant__c` | Lookup(Forecast_Participant\_\_c) | Link to participant        |
| 4   | `Target_Amount__c`        | Currency                          | Quota target               |
| 5   | `Achieved_Amount__c`      | Currency                          | Auto-computed or manual    |
| 6   | `Attainment_Pct__c`       | Percent                           | Formula: Achieved / Target |
| 7   | `Status__c`               | Picklist                          | Draft, Active, Closed      |
| 8   | `Notes__c`                | TextArea                          | Admin notes                |

**Pros:** Clean, simple, purpose-built for forecasting. No commission baggage.  
**Cons:** Another object. Need to update `loadAttainmentData` to read from this OR `Quota__c`.

> **Recommendation: Option B** — forecasting-only customers should never see commission objects. The `Forecast_Quota__c` is 8 fields vs. Quota**c's 30+. The service layer already has the `Attainment_Source**c` config switch, so adding a third source is straightforward.

### 4.3 Quota Manager UI

#### 4.3.1 Entry Point

- Sub-tab within Admin Console: "Quotas"
- Also accessible from the Forecast tab as a "Set Quotas" button (visible to admins only)

#### 4.3.2 Layout

```
┌──────────────────────────────────────────────────────────────────┐
│ QUOTA MANAGER                                 Period: [Apr 2026 ▼]│
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌──────────┬────────────┬────────────┬──────────┬────────────┐  │
│  │ Name     │ Level      │ Target     │ Achieved │ Attainment │  │
│  ├──────────┼────────────┼────────────┼──────────┼────────────┤  │
│  │ Jane S.  │ L1 - Rep   │ [$1,500K ] │ $480K    │ 32% 🟡     │  │
│  │ Bob J.   │ L1 - Rep   │ [$1,200K ] │ $320K    │ 27% 🟡     │  │
│  │ Alice C. │ L1 - Rep   │ [$1,800K ] │ $550K    │ 31% 🟡     │  │
│  │ You      │ L2 - Mgr   │ [$5,000K ] │ $1,350K  │ 27% 🟡     │  │
│  └──────────┴────────────┴────────────┴──────────┴────────────┘  │
│                                                                    │
│  [Import CSV]  [Distribute Evenly]  [Copy from Last Period]       │
│                                                      [Save All]   │
└──────────────────────────────────────────────────────────────────┘
```

#### 4.3.3 Features

| Feature                   | Description                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| **Inline edit**           | Target is editable directly in the table                                                   |
| **Achieved**              | Auto-computed from Closed Won overrides when `Attainment_Source__c = 'Live_From_Forecast'` |
| **Attainment %**          | Formula: Achieved / Target × 100, with pace-aware coloring                                 |
| **Import CSV**            | Upload: User Email, Target Amount. System matches to participants.                         |
| **Distribute Evenly**     | Takes a team total and splits across reps equally or by weight.                            |
| **Copy from Last Period** | Copies previous period's targets to current period.                                        |
| **Period Picker**         | Switch between periods to set/view quotas.                                                 |
| **Bulk Edit**             | Select multiple rows, apply % increase/decrease.                                           |

### 4.4 Attainment Source Integration

When `Attainment_Source__c = 'Live_From_Forecast'`:

- `loadAttainmentData` reads from `Forecast_Quota__c` for target
- Computes achieved from Closed Won category overrides
- No `Comp_Plan__c` or `Quota__c` involvement

When `Attainment_Source__c = 'Quota_Record'`:

- `loadAttainmentData` reads from `Comp_Plan__c` → `Quota__c` (existing behavior)
- `Forecast_Quota__c` is ignored

When `Attainment_Source__c = 'Hybrid'`:

- Try `Quota__c` first → fall back to `Forecast_Quota__c` → fall back to live computation

---

## 5. Decision Points

### DP-ADMIN-1: Should the Onboarding Wizard be a separate LWC or integrated into the Forecast tab?

**Recommendation:** Integrated. When no active config exists, `revtForecastApp` shows the wizard instead of the grid. After activation, the wizard is replaced by the grid. The Admin Console is a separate tab.

### DP-ADMIN-2: Should `Forecast_Quota__c` be a new object or reuse `Quota__c`?

**Recommendation:** New object (Option B). Keep it simple for forecasting-only customers. 8 fields vs. 30+. The `Attainment_Source__c` config already supports multiple sources.

### DP-ADMIN-3: Should the Admin Console be a separate Lightning Tab or a Settings gear icon within the Forecast tab?

**Recommendation:** Both. Separate tab for full admin experience. Gear icon in the Forecast tab toolbar for quick access to settings.

### DP-ADMIN-4: Should quota targets be per-period or annual with period breakdown?

**Recommendation:** Per-period for simplicity. Annual with breakdown is the Incentives module's job. The simplified quota manager assigns one target per user per period.

---

## 6. Component Inventory

| #   | Component                    | Type | Purpose                               |
| --- | ---------------------------- | ---- | ------------------------------------- |
| 1   | `revtOnboardingWizard`       | LWC  | Multi-step onboarding flow (9 steps)  |
| 2   | `revtAdminConsole`           | LWC  | Tabbed admin interface                |
| 3   | `revtAdminGeneralSettings`   | LWC  | General config editor                 |
| 4   | `revtAdminMetrics`           | LWC  | Metric CRUD table                     |
| 5   | `revtAdminCategories`        | LWC  | Category CRUD table with color picker |
| 6   | `revtAdminPeriods`           | LWC  | Period timeline + actions             |
| 7   | `revtAdminParticipants`      | LWC  | Participant table + sync              |
| 8   | `revtQuotaManager`           | LWC  | Simplified quota assignment table     |
| 9   | `OnboardingController.cls`   | Apex | Org discovery + config creation       |
| 10  | `AdminConsoleController.cls` | Apex | Config/metric/category/period CRUD    |
| 11  | `QuotaManagerController.cls` | Apex | Forecast quota CRUD + CSV import      |

**New object:** `Forecast_Quota__c` (8 fields)

**Total: 8 LWC components + 3 Apex controllers + 1 new object**

---

## 7. Implementation Sequence

| Phase     | Components                                                            | Duration     | Dependencies        |
| --------- | --------------------------------------------------------------------- | ------------ | ------------------- |
| 1         | `Forecast_Quota__c` object + deploy                                   | 0.5 day      | None                |
| 2         | `OnboardingController.cls` (org discovery + config creation)          | 1.5 days     | Object deployed     |
| 3         | `revtOnboardingWizard` LWC (11-step flow)                             | 3 days       | Controller          |
| 4         | `AdminConsoleController.cls` (CRUD + audit)                           | 1 day        | None                |
| 5         | `revtAdminConsole` + sub-components (7 tabs incl. Field Mapping)      | 3 days       | Controller          |
| 6         | `QuotaManagerController.cls` + `revtQuotaManager`                     | 2 days       | Forecast_Quota\_\_c |
| 7         | Integration: Forecast tab wizard, gear icon, attainment source update | 1 day        | All above           |
| **Total** |                                                                       | **~12 days** |                     |

---

## 8. V1.1 — FEEDBACK FIXES

### 8.1 Fix #1: Configuration Change Impact Policy (GAP 1)

**Problem:** Changing config settings (hierarchy, categories, period type) after data exists can corrupt data.

**Fix:** Define explicit impact policy enforced by Admin Console before any change:

| Change                  | Impact      | System Action                                                                                                                                                                                                                                                          |
| ----------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hierarchy source        | **HIGH**    | Requires participant re-initialization. Admin sees warning: "This will reset all participant records for the current period. Existing overrides will be preserved but may need re-assignment." Confirmation required. Runs `ForecastInitializationBatch` after change. |
| Categories (add)        | **LOW**     | New category available immediately. No impact on existing data.                                                                                                                                                                                                        |
| Categories (deactivate) | **MEDIUM**  | Existing overrides with that category preserved, marked read-only. Category hidden from combobox in new edits. Warning: "N overrides use this category."                                                                                                               |
| Categories (delete)     | **BLOCKED** | Cannot delete a category that has override data. Must deactivate first.                                                                                                                                                                                                |
| Metrics (add)           | **LOW**     | New metric column appears in grid. Existing overrides have null for new metric.                                                                                                                                                                                        |
| Metrics (deactivate)    | **MEDIUM**  | Column hidden from grid. Data preserved. Warning: "N overrides have values for this metric."                                                                                                                                                                           |
| Metrics (delete)        | **BLOCKED** | Cannot delete a metric with override data.                                                                                                                                                                                                                             |
| Period type             | **HIGH**    | Requires period regeneration. Warning: "Changing period type will close all open periods and generate new ones. Existing overrides will be associated with the closest matching new period." Confirmation required.                                                    |
| Currency mode           | **MEDIUM**  | Triggers exchange rate refresh on all draft overrides. Warning displayed.                                                                                                                                                                                              |
| Scope determination     | **HIGH**    | Same as hierarchy source — requires re-initialization.                                                                                                                                                                                                                 |
| Pagination size         | **LOW**     | Immediate effect. No data impact.                                                                                                                                                                                                                                      |

### 8.2 Fix #2: Wizard Re-run Guard Rails (GAP 2)

**Problem:** Re-running wizard after data exists is dangerous without rules.

**Fix:** Wizard detects existing state and runs in one of two modes:

| Mode            | Condition                             | Behavior                                                                                                                                                                                                                                                                                                          |
| --------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **First-time**  | No `Forecast_Configuration__c` exists | Full wizard, all steps, no warnings.                                                                                                                                                                                                                                                                              |
| **Reconfigure** | Active config exists                  | Warning banner at top: "You are reconfiguring an existing forecast. Changes may affect existing data." Each step shows current value + proposed change. Destructive changes (hierarchy, period type) require typed confirmation ("I understand"). Non-destructive changes (pagination, labels) apply immediately. |

**Blocked in Reconfigure mode:**

- Cannot change hierarchy source if any period has Submitted/Frozen overrides
- Cannot change period type if current period has any overrides
- Can always change: pagination, labels, attainment source, future periods count

### 8.3 Fix #3: Participant Sync Strategy (GAP 3)

**Problem:** "Re-sync from hierarchy" edge cases undefined.

**Fix:** Explicit sync modes:

| Sync Action               | Behavior                                                                                                                                                                                   |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Add new users**         | Users found in hierarchy but not in `Forecast_Participant__c` → create new participant records with `Submission_Status__c = 'Not_Started'`.                                                |
| **Preserve existing**     | Participants with overrides are NEVER removed, even if user is no longer in hierarchy.                                                                                                     |
| **Mark inactive**         | Users removed from hierarchy → `Forecast_Participant__c.Is_Active__c = false` (new field, not hard delete). Their overrides remain for audit. Grid hides inactive participants by default. |
| **Role/level change**     | If user's role changed → update `Hierarchy_Level__c`. Warning: "3 participants changed levels." If Reports_To changed → update chain.                                                      |
| **Territory realignment** | If territory assignments changed → update `Scope_Id__c`. Overrides move with the participant.                                                                                              |

**Rule: NEVER hard-delete `Forecast_Participant__c` records.** Deactivate only.

### 8.4 Fix #4: Period Management Hard Rules (GAP 4)

| Action                          | Rule                                                                  | Effect on Data                                                                                                                                                                      |
| ------------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Open Scheduled period early** | Allowed. Sets Status = 'Open'.                                        | No overrides exist yet. Participants can start forecasting.                                                                                                                         |
| **Close Open period**           | Allowed. Sets Status = 'Closed'.                                      | All overrides become read-only. Status changes logged in `Forecast_Change_Event__c`.                                                                                                |
| **Reopen Frozen period**        | Requires `Platform_Admin` + typed confirmation. Sets Status = 'Open'. | All overrides remain as-is (status stays Frozen on individual overrides until explicitly unlocked). `Forecast_Change_Event__c` with type 'Unfreeze' created. Audit trail preserved. |
| **Reopen Closed period**        | Requires `Platform_Admin`. Sets Status = 'Open'.                      | Override statuses unchanged. Users can create new overrides or edit existing.                                                                                                       |

### 8.5 Fix #5: Quota Manager Validation Rules (GAP 5)

| Rule                            | Enforcement                                                                                                                             |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Target ≥ 0                      | Before-save validation. Negative targets rejected.                                                                                      |
| Target required                 | Cannot save with null target. Zero is allowed (for tracking participation without quota).                                               |
| User must be active participant | Before-save check: `Forecast_Participant__c` must exist for user + period. Error: "User is not a forecast participant for this period." |
| Unique per user per period      | Before-insert trigger: check for existing `Forecast_Quota__c` with same `User__c + Forecast_Period__c`. Reject duplicate.               |
| CSV import duplicates           | Rejected with row-level error: "Row 5: Duplicate — Jane Smith already has a quota for Apr 2026."                                        |
| Achieved ≤ Target not enforced  | Attainment can exceed 100% (above-target performance).                                                                                  |

### 8.6 Fix #6: Multi-Currency in Quota Manager (Medium)

| Aspect          | Rule                                                                                                                 |
| --------------- | -------------------------------------------------------------------------------------------------------------------- |
| Target currency | Always in corporate currency (`Forecast_Configuration__c.Corporate_Currency__c`).                                    |
| Display         | When `Currency_Mode__c` is multi-currency, show local equivalent in parentheses using period exchange rate.          |
| CSV import      | Accepts amounts in corporate currency only. Column header: "Target (USD)".                                           |
| FX conversion   | Not applied to quota targets — targets are set in corporate currency. Only override metric values get FX conversion. |

### 8.7 Fix #7: Audit Trail (Medium)

All admin actions logged to `Incentive_Change_Event__c` (existing audit log object):

| Action                     | Change_Type\_\_c        | Details                               |
| -------------------------- | ----------------------- | ------------------------------------- |
| Config setting changed     | `Config_Change`         | Field name + old value + new value    |
| Metric added/modified      | `Config_Change`         | Metric name + action                  |
| Category added/deactivated | `Config_Change`         | Category name + action                |
| Period status changed      | `Config_Change`         | Period name + old status + new status |
| Participant synced         | `Config_Change`         | Count added/deactivated               |
| Quota target set/changed   | `Quota_Adjustment`      | User + old target + new target        |
| Quota bulk import          | `Bulk_Quota_Adjustment` | Count imported                        |

### 8.8 Fix #8: Role-Based Access Granularity (Medium)

**Three permission sets instead of two:**

| Permission Set             | Access                                                                                                                                                                      |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RevenueTrust_Full_Access` | Everything: config, metrics, categories, periods, participants, quotas, all overrides. For System Admins.                                                                   |
| `RevenueTrust_Admin`       | **NEW.** Config read + edit, quota management, participant sync, period management. Cannot modify metrics/categories (structural changes). For Sales Ops / RevOps managers. |
| `RevenueTrust_User`        | Forecast grid, own overrides, comments. No admin access. For sales reps.                                                                                                    |

### 8.9 Fix #9: Missing Wizard Steps (Structural Issues 1, 2, 6)

**Three new steps added to the wizard:**

**Step 2.5 (new): Pipeline Object & Record Types**

> What pipeline object do you use?

| Option                    | Description                           |
| ------------------------- | ------------------------------------- |
| **Opportunity** (default) | Standard Salesforce Opportunity       |
| **Custom Object**         | Admin picks a custom object (Phase 2) |

> Which Record Types should be included in the forecast?

Auto-populated from `RecordType WHERE SObjectType = 'Opportunity'`. Admin checks/unchecks. Sets `Pipeline_Record_Type_Filter__c`.

**Step 6.5 (new): Currency Configuration**

> How should RevenueTrust handle currencies?

| Option                      | When                   | Description                                                        |
| --------------------------- | ---------------------- | ------------------------------------------------------------------ |
| **Single**                  | Org is single-currency | No conversion. All values in org currency.                         |
| **Multi with Dated Rates**  | Multi-currency org     | Exchange rates from `DatedConversionRate`. Rates frozen at submit. |
| **Multi with Static Rates** | Multi-currency org     | Exchange rates from `CurrencyType`. Fixed rates.                   |
| **Dual Display**            | Multi-currency org     | Show both corporate and local columns simultaneously.              |

Auto-detected from `Organization.IsMultiCurrencyOrganization`. Single-currency orgs skip this step.

**Step 2.7 (new): Hierarchy Level Labels**

> What do you call each level in your hierarchy?

Auto-populated from role hierarchy depth. Admin edits labels:

| Level | Auto-detected (from Role names) | Admin Edit          |
| ----- | ------------------------------- | ------------------- |
| 1     | Sales Rep                       | [Sales Rep ]        |
| 2     | Sales Manager                   | [Sales Manager ]    |
| 3     | Regional Director               | [Regional Director] |
| 4     | VP Sales                        | [VP Sales ]         |

Stores as JSON in `Forecast_Configuration__c.Level_Labels__c` (or a new `Hierarchy_Level_Labels__c` field).

**Updated wizard step count: 11 steps** (was 9).

### 8.10 Fix #10: Achieved Amount Source Precision (Structural Issue 3)

**Explicit rule:** When `Attainment_Source__c = 'Live_From_Forecast'`, achieved amount is computed as:

> **Sum of the primary metric** (`Forecast_Metric__c.Is_Primary__c = true`) across all `Forecast_Override__c` records in the period where `Forecast_Category__c` is a terminal Closed Won category (`Forecast_Category__c.Is_Terminal__c = true AND Forecast_Category__c.Counts_Toward_Target__c = true`).

This is independent of which user's overrides — it sums across the participant's entire scope.

### 8.11 Fix #11: Field Mapping Admin Section (Structural Issue 4)

**New Admin Console tab: "Field Mappings"**

| Column       | Value                                                           |
| ------------ | --------------------------------------------------------------- |
| Logical Name | `Pipeline.Amount`, `Pipeline.CloseDate`, `Pipeline.Stage`, etc. |
| Mapped Field | `Amount`, `CloseDate`, `StageName` (from Opportunity describe)  |
| Type         | Currency, Date, Picklist, etc.                                  |
| Action       | Edit (field picker)                                             |

**For V1:** Field mappings are managed via this Admin Console tab. The tab reads/writes `Field_Mapping__mdt` records using `Metadata.Operations.enqueueDeployment()` (async CMT deployment).

**Note:** CMT changes require async deployment, so the UI shows "Saving..." and polls for deployment status.

### 8.12 Fix #12: Hierarchy_Source\_\_mdt Creation Strategy (Structural Issue 7)

**Problem:** CMT records can't be created via standard DML.

**Fix:** Ship `Hierarchy_Source__mdt` as a **pre-installed default record** in the managed package with `Source_Type__c = 'Ownership'`. The onboarding wizard **updates** the existing record (via `Metadata.Operations.enqueueDeployment()`) rather than creating a new one.

**Implementation:**

1. Package ships with: `Hierarchy_Source__mdt.Default` record (Source_Type = Ownership)
2. Wizard Step 2 updates this record asynchronously
3. Wizard shows "Saving configuration..." spinner during deployment
4. Polls `DeployResult` until complete (typically <5 seconds)

### 8.13 Fix #13: Forecast_Quota\_\_c Unique Constraint (Structural Issue 8)

Added to §4 object definition:

**Unique constraint:** `User__c + Forecast_Period__c` — enforced by before-insert trigger. Error: "A quota already exists for this user in this period. Use the Quota Manager to edit the existing record."

### 8.14 Fix #14: Attainment Source Integration Work (Structural Issue 9)

**Added to implementation timeline:** Phase 7 expanded from 0.5 day to 1 day to include:

- Update `ForecastService.loadAttainmentData()` to support `Forecast_Quota__c` as third source
- Update `ForecastDataService` to include `Forecast_Quota__c` query method
- Test all three attainment source modes end-to-end

### 8.15 Fix #15: Quota Manager Bulk Operations (Structural Issue 5)

**Distribute Evenly:**

1. Admin enters team total in a text input at the top: `[$5,000,000]`
2. System divides by active participant count: `$5M / 4 = $1,250,000 each`
3. **Conflict policy** (same as Forecasting copy modes):
   - **Overwrite** — replace all existing targets
   - **Skip existing** — only fill participants with no target set
4. Preview shown before applying: "4 participants × $1,250,000 = $5,000,000"

**Copy from Last Period:**

1. Finds previous period's `Forecast_Quota__c` records
2. Copies `Target_Amount__c` to current period for matching users
3. **Conflict policy:**
   - **Overwrite** — replace current targets with previous
   - **Skip existing** — only copy for participants without targets
   - **Apply % increase** — copy with adjustment: `[+10%]` → previous × 1.10
4. Preview: "Found 4 quotas from Mar 2026. 3 will be copied, 1 skipped (already set)."

### 8.16 Fix #16: Incentives Module Wizard Note (Structural Issue 10)

> **Scope note:** This wizard covers **Forecasting module setup only**. The Incentives module has its own onboarding wizard (documented in INCENTIVES_OBJECT_MODEL.md §1) covering plan templates, compensation roles, transaction categories, and commission structures. When an org installs RevenueTrust with both modules, they run two separate wizards:
>
> 1. **Forecasting Wizard** (this spec) — hierarchy, metrics, categories, periods, participants
> 2. **Incentives Wizard** (INCENTIVES_OBJECT_MODEL.md §1) — plan templates, roles, rate structures
>
> A **unified cross-module onboarding wizard** that combines both flows is a Phase 2 enhancement.

### 8.17 Fix #17: UX Enhancements (Minor Issues 9, 10)

**Estimated time:** Step 1 (Org Discovery) shows: "Estimated setup time: 5–10 minutes" below the header.

**Discovery confidence indicators:**

| Indicator                  | Meaning                        | Example                                                 |
| -------------------------- | ------------------------------ | ------------------------------------------------------- |
| ✅ **High confidence**     | Auto-detected, standard config | "Role Hierarchy: 4 levels detected"                     |
| 🔍 **Needs review**        | Detected but ambiguous         | "3 Record Types found — please select which to include" |
| ⚠️ **Manual input needed** | Cannot auto-detect             | "Custom field for scope — please select"                |

---

## 9. Updated Component Inventory

| #   | Component                    | Type | Purpose                                                |
| --- | ---------------------------- | ---- | ------------------------------------------------------ |
| 1   | `revtOnboardingWizard`       | LWC  | Multi-step onboarding flow (11 steps)                  |
| 2   | `revtAdminConsole`           | LWC  | Tabbed admin interface                                 |
| 3   | `revtAdminGeneralSettings`   | LWC  | General config editor with impact warnings             |
| 4   | `revtAdminMetrics`           | LWC  | Metric CRUD table                                      |
| 5   | `revtAdminCategories`        | LWC  | Category CRUD table with color picker                  |
| 6   | `revtAdminPeriods`           | LWC  | Period timeline + actions + rules                      |
| 7   | `revtAdminParticipants`      | LWC  | Participant table + sync + deactivation                |
| 8   | `revtAdminFieldMappings`     | LWC  | Field mapping editor (CMT async deploy)                |
| 9   | `revtQuotaManager`           | LWC  | Simplified quota assignment + bulk ops                 |
| 10  | `OnboardingController.cls`   | Apex | Org discovery + config creation + CMT deploy           |
| 11  | `AdminConsoleController.cls` | Apex | Config/metric/category/period/participant CRUD + audit |
| 12  | `QuotaManagerController.cls` | Apex | Forecast quota CRUD + CSV import + validation          |

**New objects:** `Forecast_Quota__c` (8 fields + unique constraint trigger)

**New permission set:** `RevenueTrust_Admin` (ops managers — config + quotas, no structural changes)

**Total: 9 LWC components + 3 Apex controllers + 1 new object + 1 new permission set**

---

## 10. V1.2 — FINAL POLISH FIXES

### 10.1 Fix #1: Audit Object Standardization

**Problem:** Audit events split across `Incentive_Change_Event__c` (commission audit) and `Forecast_Change_Event__c` (forecast audit). Admin changes logged to Incentive object which is confusing.

**Fix:** Use each module's own audit object:

| Module      | Audit Object                | Purpose                                                        |
| ----------- | --------------------------- | -------------------------------------------------------------- |
| Forecasting | `Forecast_Change_Event__c`  | Override changes, period status, config changes, quota changes |
| Incentives  | `Incentive_Change_Event__c` | Commission calculations, plan changes, payment events          |

Admin config changes (metrics, categories, periods, participants, quotas) are **Forecasting** operations → logged to `Forecast_Change_Event__c`. The `Change_Type__c` picklist on this object already has `System_Auto_Set` and `Scope_Transfer` — add new values:

- `Config_Change` — general config setting modification
- `Quota_Set` — quota target assigned or changed
- `Participant_Sync` — participant records added/deactivated

### 10.2 Fix #2: CMT Deployment Timeout Handling

**Problem:** `Metadata.Operations.enqueueDeployment()` is async — wizard needs timeout and failure handling.

**Fix:**

```
1. Enqueue CMT deployment
2. Show spinner: "Saving configuration..."
3. Poll DeployResult every 2 seconds (max 5 polls = 10s)
4. If SUCCESS → proceed to next step
5. If FAILED → show error: "Configuration save failed: [details]. [Retry] [Skip and configure manually]"
6. If TIMEOUT (10s) → show warning: "Save is taking longer than expected. It may still complete. [Continue Anyway] [Retry]"
7. "Continue Anyway" proceeds with a note: "Hierarchy source will be updated in the background."
```

### 10.3 Fix #3: Hybrid Attainment Priority

**Problem:** When both `Quota__c` and `Forecast_Quota__c` exist in Hybrid mode, which wins?

**Fix:** Explicit priority chain:

```
Hybrid mode resolution order:
1. Quota__c (from Incentives module) — ALWAYS authoritative if exists
   → uses Quota__c.Target_Amount__c and Quota__c.Achieved_Amount__c
2. Forecast_Quota__c (lightweight) — used only if no Quota__c found
   → uses Forecast_Quota__c.Target_Amount__c
   → achieved computed live from Closed Won overrides
3. Live computation — fallback if neither quota object has data
   → target = 0 (no attainment display)
   → achieved = sum of Closed Won primary metric
```

**Rule:** `Quota__c` always overrides `Forecast_Quota__c`. No timestamp comparison. The Incentives module is the source of truth when active.

### 10.4 Fix #4: CSV Import Error UX

**Problem:** CSV import errors need enterprise-grade error handling.

**Fix:**

| Scenario            | UX                                                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **All rows valid**  | Success toast: "4 quotas imported successfully."                                                                         |
| **Some rows fail**  | Warning toast: "2 of 4 imported. 2 errors." + inline error table showing row number, user email, error reason.           |
| **All rows fail**   | Error toast: "Import failed. 0 of 4 imported." + error table.                                                            |
| **Download errors** | "Download Error Report" button → CSV with columns: Row, Email, Target, Error. Pre-filled so admin can fix and re-import. |

Error table displayed inline below the import area:

```
┌─────┬──────────────────┬──────────┬─────────────────────────────────────┐
│ Row │ Email            │ Target   │ Error                               │
├─────┼──────────────────┼──────────┼─────────────────────────────────────┤
│ 3   │ jane@acme.com    │ $1,500K  │ User is not a participant for Apr   │
│ 5   │ bob@acme.com     │ $1,200K  │ Duplicate — quota already exists    │
└─────┴──────────────────┴──────────┴─────────────────────────────────────┘
[Download Error Report]
```

### 10.5 Fix #5: Performance — Batch Apex for Large Operations

**Rule:** All operations that may process >200 records run via Batch Apex, not synchronous DML.

| Operation                     | Threshold      | Implementation                              |
| ----------------------------- | -------------- | ------------------------------------------- |
| Participant sync              | Always batch   | `ForecastInitializationBatch` (existing)    |
| Quota bulk import             | >50 rows       | `QuotaImportBatch` (new)                    |
| Period regeneration           | Always batch   | `ForecastPeriodGeneratorBatch` (existing)   |
| Org discovery queries         | Synchronous OK | Read-only SOQL, no DML                      |
| Config change (single record) | Synchronous OK | Single `Forecast_Configuration__c` update   |
| Exchange rate refresh         | Always batch   | `ForecastSnapshotBatch.finish()` (existing) |

---

_Admin Setup, Onboarding & Quota Management Spec V1.2 — April 15, 2026_  
_V1.2 fixes: audit object standardization, CMT timeout handling, hybrid attainment priority chain, CSV import error UX with downloadable error report, batch Apex for large operations._  
_3 experiences: Onboarding Wizard (11 steps) + Admin Console (7 sections) + Quota Manager._  
_9 LWC components + 3 Apex controllers + 1 new object + 1 new permission set._
