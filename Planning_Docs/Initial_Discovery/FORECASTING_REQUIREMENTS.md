# Forecasting Aura Application — Business & Functional Requirements

**Project:** Temenos ORG – Salesforce Forecasting Module  
**Technology:** Salesforce Lightning (Aura Components)  
**Reviewed On:** 2026-04-01

---

## Table of Contents

1. [Overview](#1-overview)
2. [Roles & Personas](#2-roles--personas)
3. [Functional Requirements](#3-functional-requirements)
   - 3.1 [Forecast Initialization & Setup](#31-forecast-initialization--setup)
   - 3.2 [Filter Panel](#32-filter-panel)
   - 3.3 [Manager View](#33-manager-view)
   - 3.4 [Director View](#34-director-view)
   - 3.5 [Summary Table](#35-summary-table)
   - 3.6 [Save Forecast](#36-save-forecast)
   - 3.7 [Submit Forecast](#37-submit-forecast)
   - 3.8 [Freeze Forecast](#38-freeze-forecast)
   - 3.9 [Copy Forecast](#39-copy-forecast)
   - 3.10 [Historical Notes / Last Comments](#310-historical-notes--last-comments)
4. [Data Model Requirements](#4-data-model-requirements)
5. [Business Rules](#5-business-rules)
6. [Status Lifecycle](#6-status-lifecycle)
7. [UI / UX Requirements](#7-ui--ux-requirements)
8. [Performance Requirements](#8-performance-requirements)
9. [Security & Permission Requirements](#9-security--permission-requirements)
10. [Integration Requirements](#10-integration-requirements)
11. [Non-Functional Requirements](#11-non-functional-requirements)
12. [Component Inventory](#12-component-inventory)

---

## 1. Overview

The Forecasting application is a multi-level, hierarchical revenue forecasting tool built on Salesforce Lightning (Aura). It enables Sales Managers, Sub-Directors, Directors, and the COO to manage, review, and approve quarterly deal forecasts (NBV and ACV) across territories and regions.

**Core Business Goals:**

- Provide a structured bottom-up forecasting process from Manager → Sub-Director → Director → COO
- Allow override of individual deal values (NBV, ACV, Forecast Category, Close Quarter) at each hierarchy level
- Track changes across levels with full audit trail and trend indicators
- Support both standard forecasting and budget planning modes
- Enable freeze of finalized regional forecasts at COO level

---

## 2. Roles & Personas

| Role         | Level   | Capabilities                                                               |
| ------------ | ------- | -------------------------------------------------------------------------- |
| Manager      | Level 1 | Edit own deals, save, submit, copy from last forecast                      |
| Sub-Director | Level 2 | View manager submissions, edit own overrides, save, submit                 |
| Director     | Level 3 | View sub-director submissions, edit own overrides, save, submit            |
| COO          | Level 4 | View all submitted forecasts, edit overrides, submit, freeze entire region |

**Access Constraints:**

- Each user can only see deals within their assigned territory/region
- Past (closed) forecasts are read-only for all roles
- Locked/Frozen deals cannot be edited

---

## 3. Functional Requirements

### 3.1 Forecast Initialization & Setup

**FR-INIT-01:** On page load, the system SHALL call `getFilteredForecast()` to retrieve available forecast periods and territories for the logged-in user.

**FR-INIT-02:** The system SHALL populate a Forecast Date dropdown with all available `Forecast__c` records the user is authorized to access.

**FR-INIT-03:** The system SHALL populate a Territory dropdown with all territories linked to the user's `Forecast_User__c` assignments.

**FR-INIT-04:** After territory and forecast selection, the system SHALL call `getForecastRecords()` to load all `Forecast_Override__c` records for the selected territory and forecast.

**FR-INIT-05:** The system SHALL determine the user's forecast level (Manager / Sub-Director / Director / COO) from `Forecast_User__c.Forecast_Level__c` and render the appropriate view (Manager View or Director View tabs).

**FR-INIT-06:** When `Forecast__c.Budget_Mode__c` = true, the system SHALL operate in budget mode:

- Filter panel SHALL display budget categories instead of standard forecast categories
- Summary table header SHALL use budget-specific styling

**FR-INIT-07:** The system SHALL display the current forecast status (New / Saved / Partially Saved / Submitted / Partially Submitted / Frozen / Locked) with color-coded indicator.

**FR-INIT-08:** The system SHALL support a local-currency vs USD toggle per territory, reading currency mapping from `Forecasting_Region_Currency__mdt`.

---

### 3.2 Filter Panel

**FR-FILTER-01:** The filter panel SHALL provide multi-select dropdowns for:

- Region
- Sub-Region
- Platform
- Deal Type
- Main Product
- Stage
- Forecast Category
- Forecast Quarter

**FR-FILTER-02:** The filter panel SHALL provide a free-text search box that searches across: Opportunity Name, Account Name, Opportunity Number, and Owner Name.

**FR-FILTER-03:** All filters SHALL default to "All" (no restriction) on initial load.

**FR-FILTER-04:** The filter panel SHALL include a Refresh button to apply all currently selected filters.

**FR-FILTER-05:** The filter panel SHALL include a "Clear All Filters" button that resets all filters to "All".

**FR-FILTER-06:** Filter selections SHALL be persisted in `sessionStorage` so they survive page refreshes within the same browser session.

**FR-FILTER-07:** When filters are changed, the parent container SHALL receive a filter event and re-apply filtering to the in-memory dataset (no additional server calls required for filtering).

**FR-FILTER-08:** The Forecast Category options SHALL differ based on mode:

- Standard mode: All, Forecast, Cover, Pipeline, Closed
- Budget mode: All, Budget, Cover, Pipeline, Closed

**FR-FILTER-09:** Filter options (Region, Sub-Region, Platform, etc.) SHALL be dynamically derived from the actual deals loaded — not from a static master list.

---

### 3.3 Manager View

**FR-MGR-01:** The Manager View SHALL display all deals assigned to the Manager within the selected territory and forecast period, organized into tabbed sections by deal category (e.g., Incremental, Renewal).

**FR-MGR-02:** Each deal row SHALL display the following read-only fields:

- Region, Sub-Region
- Opportunity Number (with tooltip: Account Name, Close Date, Segment, TAS Reviewer, NBV)
- Opportunity Name
- Owner
- Deal Type, Deal Score (with tooltip: Signature Date, Legal Docs Status, Commercials Status)
- Platform, Main Product, Stage
- Renewal ACV
- Previous Level: Quarter, NBV, Category, ACV (if data exists from a prior submission)

**FR-MGR-03:** Each deal row SHALL provide the following editable fields:

- Forecast Quarter (picklist — only future quarters selectable; past quarters SHALL be blocked with a validation message)
- NBV (numeric input, currency format)
- Forecast Category (picklist: Closed, Forecast, Cover, Pipeline, Lost)
- ACV (numeric input, currency format)

**FR-MGR-04:** When a user edits any of the editable fields (NBV, ACV, Category, Quarter), the record status SHALL immediately change to "Dirty" and the row SHALL be highlighted in yellow.

**FR-MGR-05:** Each deal row SHALL show trend indicators for NBV and ACV changes:

- NBV change >= +100k → green up-arrow border
- NBV change <= -100k → red down-arrow border
- ACV change >= +50k → green up-arrow border
- ACV change <= -50k → red down-arrow border

**FR-MGR-06:** Category change SHALL trigger a `Category_Trend__c` indicator when the category changes between: Closed, Forecast, Cover, Pipeline, Lost.

**FR-MGR-07:** Each deal row SHALL have an expandable Notes section (toggled by + / - icon) containing:

- Manager Notes textarea (editable by Manager only; read-only for higher levels)
- A "Last Comments" button to view historical notes from prior forecasts

**FR-MGR-08:** Deals SHALL be color-coded by status:

- Red — New (never edited)
- Yellow — Dirty (edited but not saved)
- Blue — Saved
- Green — Submitted or Locked/Frozen

**FR-MGR-09:** The view SHALL support pagination with 40 records per page, with Previous and Next navigation buttons displaying current page range (e.g., "1–40 of 120").

**FR-MGR-10:** A rollup summary row SHALL be displayed at the bottom (or top) of each tab showing aggregated totals per quarter for: NBV, ACV, Renewal, and Incremental values.

---

### 3.4 Director View

**FR-DIR-01:** The Director View SHALL be used for Sub-Director, Director, and COO levels and SHALL display all deals within the selected territory, including deal shares.

**FR-DIR-02:** The Director View SHALL display read-only notes from all previous hierarchy levels (Manager Notes, Sub-Director Notes) in the expanded row, in addition to the current level's editable notes.

**FR-DIR-03:** The Director View SHALL display a "Previous Level" column group showing the last submitted Quarter, NBV, Category, and ACV from the immediately lower hierarchy level (`Previous_Level_Forecast_Override__r`).

**FR-DIR-04:** At COO level, if `ignoreForecastViewSubregion` is true, the system SHALL use `TEM_Sub_Region__c` for grouping instead of `Forecast_View_Sub_Region__c`.

**FR-DIR-05:** At COO level, deal shares that belong to the same region as the parent deal SHALL be excluded from COO rollup calculations to avoid double-counting.

**FR-DIR-06:** The rollup summary SHALL include `totalManagerNBV` — the sum of all manager-submitted NBVs — as a separate reference line.

**FR-DIR-07:** All other functional requirements from Manager View (FR-MGR-02 through FR-MGR-10) apply to Director View unless explicitly overridden above.

---

### 3.5 Summary Table

**FR-SUMM-01:** The Summary Table component SHALL display a quarterly breakdown of aggregated NBV and ACV by forecast category.

**FR-SUMM-02:** The Summary Table SHALL support the following sub-table views selectable by dropdown:

- Total (all categories combined)
- New (new business)
- Existing (existing customers)
- Re-Licensing
- Renewal

**FR-SUMM-03:** Summary rows SHALL show columns: Category Name, Q1(k), Q2(k), Q3(k), Q4(k), Total(k) — values displayed in thousands.

**FR-SUMM-04:** A toggle control SHALL switch between NBV-only view and ACV mode. In ACV mode, the table SHALL display both NBV and Renewal ACV side-by-side for each quarter.

**FR-SUMM-05:** The Summary Table SHALL recalculate automatically whenever the filter panel fires a new filter event.

**FR-SUMM-06:** In Budget mode, the Summary Table header SHALL use a distinct color/style to visually differentiate from standard forecast mode.

**FR-SUMM-07:** The Summary Table SHALL display the active forecast year as a heading.

---

### 3.6 Save Forecast

**FR-SAVE-01:** A "Save" button SHALL be available on the main forecasting screen for all roles.

**FR-SAVE-02:** Clicking Save SHALL display a confirmation dialog before proceeding, with options:

- Save only the currently filtered/visible deals (Partial Save)
- Save all deals regardless of filters (Full Save)

**FR-SAVE-03:** On confirmation, the system SHALL call `saveForecastData()` with the list of Dirty records and the full/partial flag.

**FR-SAVE-04:** Saved records SHALL have their `Status__c` updated to "Saved" and `Forecast_User__c.Forecast_Status__c` updated to "Saved" or "Partially Saved" accordingly.

**FR-SAVE-05:** `Forecast_User__c.Saved_On__c` SHALL be stamped with the current timestamp on save.

**FR-SAVE-06:** After a successful save, the UI SHALL refresh row colors (Dirty rows turn Blue) and update the status indicator.

**FR-SAVE-07:** If the save operation fails (Apex exception), the system SHALL display an error toast notification and leave affected rows in Dirty state.

---

### 3.7 Submit Forecast

**FR-SUBMIT-01:** A "Submit" button SHALL be available on the main forecasting screen for all roles.

**FR-SUBMIT-02:** Submission SHALL be blocked if the forecast is in "Frozen" or "Locked" status.

**FR-SUBMIT-03:** Clicking Submit SHALL display a confirmation dialog before proceeding, with options:

- Submit only currently filtered/visible deals (Partial Submit)
- Submit all deals (Full Submit)

**FR-SUBMIT-04:** On confirmation, the system SHALL call `submitForecastData()` with the list of records and the full/partial flag.

**FR-SUBMIT-05:** Submitted records SHALL have their `Status__c` updated to "Submitted" and `Forecast_User__c.Forecast_Status__c` updated to "Submitted" or "Partially Submitted".

**FR-SUBMIT-06:** `Forecast_User__c.Submitted_On__c` SHALL be stamped with the current timestamp.

**FR-SUBMIT-07:** After submission, submitted rows SHALL turn Green and become read-only in the current user's view.

**FR-SUBMIT-08:** The submitted forecast data SHALL be visible as "Previous Level" data in the next hierarchy level's view.

---

### 3.8 Freeze Forecast

**FR-FREEZE-01:** The Freeze button SHALL only be visible and accessible to users with the COO role/level.

**FR-FREEZE-02:** Clicking Freeze SHALL display a confirmation dialog warning that this action cannot be undone.

**FR-FREEZE-03:** On confirmation, the system SHALL call `freezeForecastData()` which:

- Sets `Forecast_Override__c.Frozen__c` = true for all records in the selected region
- Updates `Forecast_User__c.Forecast_Status__c` to "Frozen"
- Stamps `Forecast_User__c.Frozen_On__c` with the current timestamp

**FR-FREEZE-04:** Once frozen, ALL records in the region SHALL become read-only for all users including COO.

**FR-FREEZE-05:** The status indicator SHALL change to "Frozen" with appropriate visual styling.

---

### 3.9 Copy Forecast

**FR-COPY-01:** The application SHALL support two types of copy operations:

**FR-COPY-02 — Copy from Previous Level:**

- Available for Sub-Director, Director, and COO roles
- Copies NBV, ACV, Category, and Quarter values from the immediately lower hierarchy level's submitted overrides
- Calls `copyForecastPrevLevel()` with the current territory/forecast context

**FR-COPY-03 — Copy from Last Forecast (Manager only):**

- Available only for Manager role
- Copies the Manager's own submitted values from the previous forecast period
- Calls `copyFromLastForecast()` with current context

**FR-COPY-04:** Before executing a copy, the system SHALL display a confirmation dialog explaining the source of the copy.

**FR-COPY-05:** After a successful copy, copied records SHALL be in "Dirty" state (yellow), requiring explicit Save or Submit to persist.

**FR-COPY-06:** Copy SHALL only operate on records that have not yet been Saved or Submitted in the current forecast period.

---

### 3.10 Historical Notes / Last Comments

**FR-NOTES-01:** Each deal row SHALL provide a "Last Comments" button (visible in the expanded notes section).

**FR-NOTES-02:** Clicking "Last Comments" SHALL fire `SL_GetForecastCommentEvent` with the Opportunity ID.

**FR-NOTES-03:** The parent container SHALL call `getLastForecastComment(oppId, userId)` and receive a list of historical note strings from prior forecasts.

**FR-NOTES-04:** Historical notes SHALL be displayed in a modal popup, sorted chronologically (most recent first).

**FR-NOTES-05:** The modal SHALL be dismissible via a Close button.

**FR-NOTES-06:** If no historical notes exist for the deal, the modal SHALL display a "No previous comments found" message.

---

## 4. Data Model Requirements

### 4.1 Core Objects

| Object                 | Purpose                            | Key Fields                                                                                                                                            |
| ---------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Forecast__c`          | Forecast period/batch              | `Status__c`, `Budget_Mode__c`, `Start_Quarter__c`, `Forecast_Status__c`, `Saved_On__c`, `Submitted_On__c`, `Frozen_On__c`                             |
| `Forecast_Override__c` | Per-deal forecast record           | `NBV__c`, `ACV__c`, `NBV_Local__c`, `ACV_Local__c`, `Status__c`, `Type__c`, `Close_Date_Override__c`, `Forecast_Category__c`, `Notes__c`, `Frozen__c` |
| `Forecast_User__c`     | User-Territory-Forecast assignment | `Forecast_Level__c`, `Forecast__c`, `Territory_ID__c`, `User__c`, `Local_Currency__c`, `Forecast_Status__c`, `Forecast_Manager__c`                    |
| `Forecast_Comment__c`  | Historical notes storage           | Links to Opportunity and User                                                                                                                         |

### 4.2 Lookup Relationships

- `Forecast_Override__c` → `Opportunity__c` (Lookup)
- `Forecast_Override__c` → `Forecast__c` (Lookup)
- `Forecast_Override__c` → `User__c` (Lookup)
- `Forecast_Override__c.Previous_Level_Forecast_Override__c` → `Forecast_Override__c` (self-lookup to previous hierarchy record)
- `Forecast_Override__c.Previous_Forecast_Override__c` → `Forecast_Override__c` (self-lookup to same-level previous period record)
- `Forecast_User__c` → `Forecast__c` (Lookup)

### 4.3 Custom Metadata

| Metadata Object                    | Purpose                          |
| ---------------------------------- | -------------------------------- |
| `Forecasting_Region_Currency__mdt` | Maps regions to local currencies |
| `ACV_Category__mdt`                | ACV categorization rules         |

### 4.4 Forecast_Override\_\_c Status Values

| Value     | Meaning                            |
| --------- | ---------------------------------- |
| New       | Record created, no edits by user   |
| Dirty     | User has made edits, not yet saved |
| Saved     | User has saved (not submitted)     |
| Submitted | User has submitted to next level   |
| Locked    | System-locked (e.g., deal closed)  |

### 4.5 Forecast_User**c Forecast_Status**c Values

| Value               | Meaning                   |
| ------------------- | ------------------------- |
| New                 | No saves or submits yet   |
| Partially Saved     | Some deals saved          |
| Saved               | All deals saved           |
| Partially Submitted | Some deals submitted      |
| Submitted           | All deals submitted       |
| Frozen              | COO has frozen the region |
| Locked              | System-locked             |

---

## 5. Business Rules

**BR-01 — Quarter Validation:** Users SHALL NOT be able to select a past quarter as the Forecast Quarter for any deal. An attempt to select a past quarter SHALL be blocked with a validation message.

**BR-02 — Hierarchy Read-Only:** Once a deal is submitted, it SHALL be read-only for the submitting user. Higher-level reviewers can still edit their own override values for the same deal.

**BR-03 — Frozen Immutability:** Once a COO freezes a forecast, NO edits SHALL be allowed by anyone for any record in that frozen region/forecast combination.

**BR-04 — Deal Share Double-Count Prevention:** At COO level, deal shares that belong to the same region as the originating opportunity SHALL be excluded from rollup totals to prevent double-counting cross-regional contributions.

**BR-05 — Budget Mode Restriction:** Budget mode SHALL only be accessible when `Forecast__c.Budget_Mode__c` = true. Budget mode changes the category options and summary table styling.

**BR-06 — Copy Eligibility:** Copy from Previous Level SHALL only apply to records where the previous level has a submitted `Forecast_Override__c` record. If no previous-level submission exists for a deal, that deal SHALL be skipped during copy.

**BR-07 — Trend Thresholds:**

- NBV trend indicator triggers at ±100,000 absolute change from `Previous_Forecast_Override__c.NBV__c`
- ACV trend indicator triggers at ±50,000 absolute change from `Previous_Forecast_Override__c.ACV__c`

**BR-08 — Notes Hierarchy:** Notes SHALL be visible to all higher-level reviewers but only editable by the level that owns them. Manager notes are read-only to Sub-Director and above.

**BR-09 — Currency Display:** Values SHALL be displayed in the territory's local currency OR in USD based on the user's toggle selection. Currency conversion rates are sourced from `Forecasting_Region_Currency__mdt`.

**BR-10 — Partial vs Full Operations:** Both Save and Submit SHALL support partial (filtered deals only) and full (all deals) modes. The `Forecast_User__c.Forecast_Status__c` SHALL reflect "Partially" saved/submitted if only a subset has been actioned.

---

## 6. Status Lifecycle

```
Forecast_Override__c (Deal Level):
  New → [User edits] → Dirty → [Save] → Saved → [Submit] → Submitted
                                                           → [Freeze] → Locked

Forecast_User__c (User-Territory Level):
  New
  → Partially Saved (some deals saved)
  → Saved (all deals saved)
  → Partially Submitted (some deals submitted)
  → Submitted (all deals submitted)
  → Frozen (COO freeze action)
  → Locked (system lock)

Forecast__c (Period Level):
  Active → Submitted → Frozen → Locked (past period)
```

---

## 7. UI / UX Requirements

**UX-01:** The layout SHALL be two-column: left panel = Filter Panel, right area = Summary Table + deal tabs.

**UX-02:** A loading spinner SHALL be displayed during all asynchronous server operations (data load, save, submit, freeze, copy).

**UX-03:** All destructive or irreversible actions (Submit, Freeze, Copy) SHALL display a confirmation dialog before execution.

**UX-04:** Success and error feedback SHALL be delivered via Salesforce Toast notifications (success = green, error = red, warning = orange).

**UX-05:** Deals SHALL be displayed in tabbed sections organized by deal category (e.g., Incremental, Renewal), with visible tab labels.

**UX-06:** Row colors SHALL reflect deal status to provide immediate visual feedback:

- Red → New
- Yellow → Dirty (unsaved changes)
- Blue → Saved
- Green → Submitted / Locked / Frozen

**UX-07:** Trend arrows SHALL be displayed on the NBV and ACV fields when values change beyond the defined thresholds (see BR-07).

**UX-08:** Tooltips SHALL be available on Opportunity Name (showing: Account, Close Date, Segment, TAS Reviewer, NBV) and Deal Score (showing: Signature Date, Legal Docs, Commercials).

**UX-09:** The Summary Table SHALL be displayed above the deal tabs and SHALL auto-refresh when filters are applied.

**UX-10:** Pagination controls SHALL display the current range and total (e.g., "Showing 1–40 of 120") with Previous / Next buttons.

**UX-11:** The forecast status indicator in the header SHALL be color-coded:

- Grey → New
- Blue → Saved / Partially Saved
- Orange → Submitted / Partially Submitted
- Red → Frozen
- Dark → Locked

**UX-12:** Action buttons (Save, Submit, Freeze, Copy) SHALL be disabled/hidden based on current forecast status and user role.

---

## 8. Performance Requirements

**PERF-01:** Initial page load (data fetch + render) SHALL complete within 5 seconds for up to 500 deals.

**PERF-02:** Filter operations SHALL execute client-side (no server round-trip) and complete within 1 second.

**PERF-03:** Pagination SHALL limit deal display to 40 records per page to maintain rendering performance.

**PERF-04:** Save and Submit operations SHALL use batch DML patterns to avoid hitting Salesforce governor limits for large datasets (100+ deals).

**PERF-05:** Apex methods used for repeated read operations (e.g., `getFilteredForecast`) SHOULD be marked `@AuraEnabled(cacheable=true)` where data is not user-mutation-specific.

---

## 9. Security & Permission Requirements

**SEC-01:** The Forecasting application SHALL be accessible only to users with the appropriate permission set assigned (e.g., `Budget_and_Forecast_screen_Access`, `Forecast_Category_Allow_to_Edit`).

**SEC-02:** `Forecast_Override__c` records SHALL be governed by Salesforce object-level and field-level security. The Apex controller SHALL use `WITH SECURITY_ENFORCED` or equivalent.

**SEC-03:** Users SHALL only see `Forecast_Override__c` records within their assigned territory hierarchy. Cross-territory data access SHALL be blocked at the Apex layer.

**SEC-04:** The Freeze action SHALL be restricted to users with COO-level `Forecast_User__c.Forecast_Level__c`. Attempts by non-COO users to call `freezeForecastData()` SHALL return an error.

**SEC-05:** Past/locked forecasts SHALL be read-only for all users. Any write attempt on locked records SHALL be rejected.

---

## 10. Integration Requirements

**INT-01:** The forecasting module receives Opportunity data from the core CRM (`Opportunity`, `OpportunityLineItem`, `Product2`) — no direct integration required but data consistency must be maintained.

**INT-02:** `Forecast_Override__c` records are linked to `Opportunity__c` and SHALL reflect current opportunity attributes (Stage, Close Date, Platform, Product) at the time of forecast load. They are NOT auto-synced — values are frozen at override creation.

**INT-03:** Currency conversion data SHALL be read from `Forecasting_Region_Currency__mdt` custom metadata — no external currency API integration required.

**INT-04:** The application does NOT require external system integrations; all data resides within Salesforce.

---

## 11. Non-Functional Requirements

**NFR-01 — Maintainability:** Each hierarchy view (Manager / Director) SHALL be implemented as a separate reusable Aura component to support independent updates.

**NFR-02 — Testability:** All Apex controller methods SHALL have corresponding test classes with minimum 75% code coverage (Salesforce deployment requirement). Business logic methods SHALL target 90%+ coverage.

**NFR-03 — Accessibility:** UI components SHOULD follow Salesforce Lightning Design System (SLDS) accessibility guidelines including ARIA labels and keyboard navigation.

**NFR-04 — Browser Compatibility:** The application SHALL support the browsers supported by Salesforce Lightning: Chrome (latest), Firefox (latest), Safari (latest), Edge (latest).

**NFR-05 — Auditability:** All save, submit, and freeze actions SHALL be timestamped (`Saved_On__c`, `Submitted_On__c`, `Frozen_On__c`) and attributed to the acting user.

**NFR-06 — Scalability:** The data model and Apex logic SHALL support up to 1,000 deals per territory-forecast combination without hitting Salesforce SOQL row limits (use pagination/chunking where necessary).

---

## 12. Component Inventory

| Component Name                          | Type               | Purpose                                                        |
| --------------------------------------- | ------------------ | -------------------------------------------------------------- |
| `SL_OpportunityForecastCmp`             | Aura App/Container | Main container — orchestrates data flow, action buttons, modal |
| `SL_ForecastManagerView`                | Aura Component     | Deal table for Manager-level forecasting with edit/pagination  |
| `SL_ForecastDirectorView`               | Aura Component     | Deal table for Director/COO-level with hierarchical notes      |
| `SL_OpportunityForecastFilterCmp`       | Aura Component     | Multi-select filter panel, search, session persistence         |
| `SL_OpportunityForecastSummaryTableCmp` | Aura Component     | Quarterly NBV/ACV rollup summary table                         |
| `SL_MultiSelectUtility`                 | Aura Component     | Reusable multi-select dropdown widget                          |
| `SL_OpportunityForecastFilterCmpEvnt`   | Aura Event         | Carries selected filter state from filter panel to container   |
| `SL_GetForecastCommentEvent`            | Aura Event         | Triggers historical note fetch for a specific opportunity      |
| `SL_OpportunityForecastCtrl`            | Apex Class         | Main controller — all `@AuraEnabled` server-side methods       |

---

_Document generated by review of the custom-built Temenos ORG Forecasting Aura application source code._
