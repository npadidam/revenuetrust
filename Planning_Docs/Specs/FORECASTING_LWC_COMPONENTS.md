# RevenueTrust — Forecasting LWC Components Spec

**Version:** 1.2  
**Date:** April 14, 2026  
**Status:** LOCK CANDIDATE — V1.2 feedback incorporated  
**Companion specs:** FORECASTING_APEX_CONTROLLERS.md V1.1 (implemented), FORECASTING_OBJECT_MODEL.md V1.4 (frozen)  
**Ported from:** Temenos ORG — SL_OpportunityForecastCmp (Aura), SL_ForecastManagerView, SL_ForecastDirectorView, SL_OpportunityForecastFilterCmp, SL_OpportunityForecastSummaryTableCmp  
**Implementation week:** Week 2

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                           FORECASTING LWC LAYER                                  │
│                                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐                │
│  │              revtForecastApp (App Page / Tab)                │                │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │                │
│  │  │ Toolbar      │  │ Period/Scope │  │ Summary Panel     │  │                │
│  │  │ (actions)    │  │ Selectors    │  │ (attainment/tier) │  │                │
│  │  └─────────────┘  └──────────────┘  └───────────────────┘  │                │
│  │  ┌─────────────────────────────────────────────────────┐    │                │
│  │  │           revtForecastFilterBar                      │    │                │
│  │  │  search | category | stage | health | toggles | sort │    │                │
│  │  └─────────────────────────────────────────────────────┘    │                │
│  │  ┌─────────────────────────────────────────────────────┐    │                │
│  │  │           revtForecastGrid                           │    │                │
│  │  │  ┌────────────────────────────────────────────────┐  │    │                │
│  │  │  │ revtForecastRow (× N — one per pipeline record)│  │    │                │
│  │  │  │  inline-edit metrics, category, close date      │  │    │                │
│  │  │  │  health badge, trend arrows, governance flags   │  │    │                │
│  │  │  │  incentive estimate columns                     │  │    │                │
│  │  │  │  expandable: notes + comment thread             │  │    │                │
│  │  │  └────────────────────────────────────────────────┘  │    │                │
│  │  │  ┌────────────────────────────────────────────────┐  │    │                │
│  │  │  │ revtForecastTotalsRow (rollup footer)          │  │    │                │
│  │  │  └────────────────────────────────────────────────┘  │    │                │
│  │  │  pagination controls                                 │    │                │
│  │  └─────────────────────────────────────────────────────┘    │                │
│  └──────────────────────────────────────────────────────────────┘                │
│                                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐                │
│  │        revtOpportunityForecast (Record Page Component)       │                │
│  │  Single-record inline forecast for Opportunity FlexiPage     │                │
│  │  ┌─────────┐ ┌────────────┐ ┌──────────┐ ┌───────────────┐ │                │
│  │  │ Status  │ │ Metrics    │ │ Category │ │ Comment       │ │                │
│  │  │ badge   │ │ (editable) │ │ picker   │ │ + history     │ │                │
│  │  └─────────┘ └────────────┘ └──────────┘ └───────────────┘ │                │
│  │  health score | incentive estimate | trend indicators       │                │
│  └──────────────────────────────────────────────────────────────┘                │
│                                                                                  │
│  Shared:  revtForecastCommentThread  |  revtHealthBadge  |  revtTrendArrow      │
│           revtInlineEstimator        |  revtCategoryPill  |  revtMultiSelect     │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Component Inventory

| #   | Component                   | Type       | Placement                 | Purpose                                                                       |
| --- | --------------------------- | ---------- | ------------------------- | ----------------------------------------------------------------------------- |
| 1   | `revtForecastApp`           | Container  | App Page / Lightning Tab  | Full forecast grid experience                                                 |
| 2   | `revtForecastFilterBar`     | Child      | Inside App                | Multi-filter bar with search, category, stage, health, toggles                |
| 3   | `revtForecastGrid`          | Child      | Inside App                | Editable data grid with pagination                                            |
| 4   | `revtForecastRow`           | Child      | Inside Grid               | Single pipeline record row (editable)                                         |
| 5   | `revtForecastTotalsRow`     | Child      | Inside Grid               | Rollup footer with category totals                                            |
| 6   | `revtForecastSummaryPanel`  | Child      | Inside App                | Attainment, coverage, tier info                                               |
| 7   | `revtForecastCommentThread` | Shared     | Modal / Row expand        | Comment history + new comment form                                            |
| 8   | `revtOpportunityForecast`   | Standalone | **Opportunity FlexiPage** | Single-record inline forecast                                                 |
| 9   | `revtHealthBadge`           | Shared     | Row / Opp Page            | Color-coded health score badge                                                |
| 10  | `revtTrendArrow`            | Shared     | Row / Opp Page            | Trend indicator (-1, 0, +1)                                                   |
| 11  | `revtInlineEstimator`       | Shared     | Row / Opp Page            | Commission impact estimate                                                    |
| 12  | `revtCategoryPill`          | Shared     | Row / Opp Page            | Color-coded category display                                                  |
| 13  | `revtMultiSelect`           | Shared     | Filter bar                | Multi-select dropdown (ported from SL_MultiSelectUtility)                     |
| 14  | `revtConfirmationDialog`    | Shared     | Modals                    | Confirmation dialog for Save (partial/full), Submit, Freeze with warning text |

**Total: 14 components** (1 container, 4 grid children, 1 standalone record-page component, 7 shared primitives, 1 utility)

### Design Departures from Temenos (Intentional)

> **DD-1: Unified grid replaces tabbed category layout.** Temenos FR-MGR-01/UX-05 organized deals in tabbed sections by deal category (Incremental, Renewal). RevenueTrust uses a single unified grid with Category as a filter dimension, not a tab selector. **Rationale:** Unified view enables cross-category sorting, total visibility without switching tabs, simpler state management, and works with any number of configurable categories (not hardcoded to Temenos's 4).

> **DD-2: Summary panel replaces quarterly matrix table.** Temenos FR-SUMM-01 through FR-SUMM-07 defined a Q1/Q2/Q3/Q4/Total matrix with sub-tables (Total, New, Existing, Re-Licensing, Renewal). RevenueTrust uses a single-period attainment ring + category totals panel. **Rationale:** RevenueTrust supports configurable period types (Monthly, Quarterly, Annual) — a hardcoded Q1-Q4 matrix doesn't generalize. The quarterly breakdown is available via period picker + Forecast_Snapshot\_\_c trend comparison.

> **DD-3: New status = Gray, not Red.** Temenos used Red border for unedited (New) records. RevenueTrust uses Gray (#B0B0B0). **Rationale:** Red implies error/danger in SLDS conventions. Gray correctly conveys "not yet touched" without false urgency.

---

## 2. Data Flow

### 2.1 Page Bootstrap Sequence

```
   LWC connectedCallback()
          │
          ├──(1) wire: getForecastConfig()          ← cacheable, stable config
          │         Returns: metrics[], categories[], periods[], currentPeriod,
          │                  currencyMode, paginationSize, topLevelActionType/Label
          │
          ├──(2) imperative: getParticipantContext()  ← mutable, user-specific
          │         Returns: participant, attainment, availableScopes,
          │                  canSubmit, canFreeze, canEdit, isBudgetMode
          │
          └──(3) imperative: getForecastRecords()     ← paginated records
                    Returns: records[], totalCount, totalUnfilteredCount,
                             pageNumber, pageSize, summary
```

### 2.2 Filtering Strategy (§11.2)

| Scope Size                   | Strategy        | How                                                                                          |
| ---------------------------- | --------------- | -------------------------------------------------------------------------------------------- |
| `totalUnfilteredCount` ≤ 500 | **Client-side** | Load all records on first call. LWC filters in JS. No server round-trips for filter changes. |
| `totalUnfilteredCount` > 500 | **Server-side** | Pass ForecastQueryRequest with filters. New server call on each filter change.               |

The first `getForecastRecords()` response includes `totalUnfilteredCount`. The component stores this and sets `isClientSideFiltering = (totalUnfilteredCount <= 500)`.

### 2.3 Save / Submit / Freeze Flow

```
User edits cells → dirty tracking in JS
                         │
    ┌────────────────────┼──────────────────────┐
    │ Save               │ Submit                │ Freeze
    │                    │                       │
    ▼                    ▼                       ▼
saveForecastData()    submitForecastData()    freezeForecastData()
    │                    │                       │
    ▼                    ▼                       ▼
SaveResult            SubmitResult             FreezeResult
(updatedOverrideIds)  (snapshotId,             (frozenCount,
                       notificationsSent)       expiredGovernanceCount)
    │                    │                       │
    └────────────────────┴──────────────────────┘
                         │
                    Refresh grid
                    (merge new overrideIds into existing records
                     OR full reload if submit/freeze)
```

---

## 3. revtForecastApp — Main Container

### 3.1 Interface

```
flexipage:availableForAllPageTypes
```

Exposed as a Lightning App Page component. Admin adds it to a tab in the Lightning app.

### 3.2 Design Parameters (target config)

| Parameter             | Type    | Default    | Description                                     |
| --------------------- | ------- | ---------- | ----------------------------------------------- |
| `title`               | String  | `Forecast` | Card title                                      |
| `showInlineEstimator` | Boolean | `true`     | Show commission estimate columns                |
| `showHealthBadge`     | Boolean | `true`     | Show deal health badge                          |
| `compactMode`         | Boolean | `false`    | Reduce column width, hide non-essential columns |

### 3.3 State Management

All state lives in the container and flows down via properties. Children communicate up via `CustomEvent`.

```javascript
// Core state
config = {}; // ForecastConfigDTO (wired, cached)
context = {}; // ForecastParticipantContextDTO (imperative)
recordSet = {}; // ForecastRecordSet (imperative)
allRecords = []; // Full record list (if client-side filtering)

// UI state
selectedPeriodId = null;
selectedScopeId = null;
currentPage = 1;
isClientSideFiltering = false;
dirtyOverrides = new Map(); // recordId → { category, metricValues, closeDateOverride, comment }
rowDataVersionMap = new Map(); // recordId → dataVersion hash (composite conflict detection — GAP 1 fix)
rowErrorMap = new Map(); // recordId → errorMessage (partial failure tracking — GAP 5 fix)
isLoading = false;
isSaving = false;
isLocked = false; // UI lock flag — true during save/submit/freeze (GAP 4 fix)
expandedRowId = null;

// Drill-in state (manager viewing subordinate)
isDrillIn = false;
drillInParticipantId = null;
drillInBreadcrumbs = [];
```

### 3.4 Toolbar Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [Period Picker ▼]  [Scope Picker ▼]  │  Status: Saved  │  [Copy ▼] [Save] [Submit] [Freeze*]  [CSV ↓] │
└─────────────────────────────────────────────────────────────────────────────┘
                                                                    * Freeze only visible to top-level
```

| Element         | Source                      | Behavior                                                                                                                                                                                                                                                                   |
| --------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Period Picker   | `config.periods[]`          | Combobox. Changing reloads context + records.                                                                                                                                                                                                                              |
| Scope Picker    | `context.availableScopes[]` | Combobox. Only visible if scopes.length > 1. Changing reloads records.                                                                                                                                                                                                     |
| Currency Toggle | `config.currencyMode`       | Only visible when `currencyMode !== 'Single'`. Toggle button: "Corporate" / "Local". Switches which metric columns are primary vs. parenthetical. Does not trigger server call — purely client-side column swap.                                                           |
| Status Badge    | `context.submissionStatus`  | Color-coded: New (gray), Saved (blue), Submitted (green), Frozen (purple)                                                                                                                                                                                                  |
| Copy            | `context.hierarchyLevel`    | Dropdown: "Copy from Previous Level" (level > 1) / "Copy from Last Forecast" (always). Shows copy mode sub-menu (Overwrite, Merge, Skip Edited).                                                                                                                           |
| Save            | `context.canEdit`           | Disabled when `!canEdit`, no dirty rows, or `isLocked`. Opens `revtConfirmationDialog` with Partial Save / Full Save choice (FR-SAVE-02). Calls `saveForecastData`.                                                                                                        |
| Submit          | `context.canSubmit`         | Disabled when `!canSubmit` or `isLocked`. Opens `revtConfirmationDialog` with "Submit N overrides to [next level label]?" + partial/full choice (FR-SUBMIT-03). Calls `submitForecastData`.                                                                                |
| Freeze          | `context.canFreeze`         | Only rendered if `canFreeze === true`. Button label from `config.topLevelActionLabel`. Opens `revtConfirmationDialog` with freeze warning: "This will freeze all overrides in scope [scopeName]. This action cannot be undone without admin intervention." (FR-FREEZE-02). |
| CSV Export      | Always                      | Dual path: ≤500 records → client-side Blob generation from visible data. >500 records → calls `exportForecastData()` Apex method for server-side generation, returns downloadable content.                                                                                 |

### 3.5 Drill-In (Manager → Rep View)

When a manager clicks a subordinate's name in the Owner column:

1. Push current state to `drillInBreadcrumbs[]`
2. Call `getParticipantContextForUser(participantId, periodId, scopeId)`
3. Call `getForecastRecords()` for the subordinate's participant
4. Render breadcrumb trail: `My Forecast > Jane Smith > Bob Jones`
5. Clicking a breadcrumb pops back to that level

**Security:** The Apex `validateAccess()` enforces hierarchy checks. The LWC doesn't need to duplicate this — if the call fails, show the error toast.

---

## 4. revtForecastFilterBar

### 4.1 Layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [🔍 Search deals...]  [Category ▼]  [Stage ▼]  [Health ▼]  ☐ Overridden  ☐ Divergent  ☐ Pending  [Clear All] │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Filter Definitions

| Filter           | Type              | Source                       | Multi-select? | Behavior                                           |
| ---------------- | ----------------- | ---------------------------- | ------------- | -------------------------------------------------- |
| Search           | Text input        | Free text                    | N/A           | Matches on deal name, owner name. Debounced 300ms. |
| Category         | `revtMultiSelect` | `config.categories[]`        | Yes           | Filter by forecast category. Pills show selected.  |
| Stage            | `revtMultiSelect` | Distinct stages from records | Yes           | CRM stages.                                        |
| Health Band      | `revtMultiSelect` | Green, Yellow, Red           | Yes           | Deal health score band.                            |
| Overridden Only  | Checkbox          | N/A                          | N/A           | Show only records with existing override           |
| Divergent Only   | Checkbox          | N/A                          | N/A           | Show only CRM-diverged records                     |
| Pending Approval | Checkbox          | N/A                          | N/A           | Show only governance-blocked records               |
| Clear All        | Button            | N/A                          | N/A           | Reset all filters                                  |

### 4.3 Debouncing & Persistence

**All filter changes are debounced at 250ms** — including category, stage, health multi-selects, checkboxes, and search (search debounced at 300ms). This prevents rapid Apex calls during multi-click filter changes.

**Filter persistence:** Filter state is saved to `sessionStorage` under key `revt_forecast_filters_{periodId}_{scopeId}_{participantId}` on every filter change. The `participantId` segment ensures drill-in contexts (manager → Jane → Bob) each get their own filter state. On page load, filters are restored from `sessionStorage` if a matching key exists. Cleared on period/scope change. When navigating back up the drill-in breadcrumb, the parent's filters are restored from their own key.

### 4.4 Budget Mode

When `context.isBudgetMode === true`:

- Category combobox shows **budget categories** from config (categories where `Budget_Equivalent__c` is populated)
- Filter bar header shows "Budget Mode" label with distinct styling

### 4.5 Events

Dispatches `filterchange` CustomEvent with payload matching `ForecastQueryRequest` filter fields.

**Client-side mode:** Parent applies filters in JS against `allRecords[]`.  
**Server-side mode:** Parent calls `getForecastRecords(request)` with updated filters.

---

## 5. revtForecastGrid

### 5.1 Column Definitions

Columns are **dynamic**, driven by `config.metrics[]` and `config.categories[]`. The grid does not hardcode column names.

#### Fixed Columns (always present)

| #   | Column       | Width | Source                       | Editable  | Notes                                                            |
| --- | ------------ | ----- | ---------------------------- | --------- | ---------------------------------------------------------------- |
| 1   | Expand (+/−) | 32px  | UI                           | Click     | Toggles notes/comment row                                        |
| 2   | Deal Name    | 200px | `recordName`                 | Link      | Opens Opportunity record. Tooltip: account, close date, segment. |
| 3   | Owner        | 120px | `ownerName`                  | Link      | Click drills into subordinate (if manager).                      |
| 4   | Stage        | 100px | `stage`                      | Read-only | CRM stage.                                                       |
| 5   | Close Date   | 100px | `closeDate`                  | Read-only | CRM close date. Gray text if override exists.                    |
| 6   | CRM Amount   | 100px | `crmAmount`                  | Read-only | Pipeline record amount from CRM.                                 |
| 7   | Health       | 48px  | `healthScore` + `healthBand` | Read-only | `revtHealthBadge` component. Hidden if `showHealthBadge=false`.  |

#### Dynamic Metric Columns (from `config.metrics[]`)

For each metric in `config.metrics` where `metric.isEditable`:

| Column                   | Width | Source                              | Editable  | Notes                                                                                    |
| ------------------------ | ----- | ----------------------------------- | --------- | ---------------------------------------------------------------------------------------- |
| `{metric.label}`         | 110px | `metricValues['metric_{n}']`        | **Yes**   | `lightning-input type="number"`. Format per `metric.format` (Currency, Percent, Number). |
| `{metric.label} (Local)` | 100px | `metricValuesLocal['metric_{n}']`   | Read-only | Only shown when `config.currencyMode !== 'Single'`.                                      |
| `{metric.label} (Prev)`  | 90px  | `previousLevelValues['metric_{n}']` | Read-only | Only shown when `hierarchyLevel > 1`. Gray text.                                         |
| Trend                    | 32px  | `trends['metric_{n}']`              | Read-only | `revtTrendArrow` component.                                                              |

#### Category Column

| Column   | Width | Source     | Editable | Notes                                                                                        |
| -------- | ----- | ---------- | -------- | -------------------------------------------------------------------------------------------- |
| Category | 130px | `category` | **Yes**  | Combobox populated from `config.categories[]`. Shows `revtCategoryPill` with category color. |

#### Close Date Override Column

| Column         | Width | Source              | Editable | Notes                                               |
| -------------- | ----- | ------------------- | -------- | --------------------------------------------------- |
| Override Close | 110px | `closeDateOverride` | **Yes**  | `lightning-input type="date"`. Null = use CRM date. |

#### Override Status Column

| Column | Width | Source   | Editable  | Notes                                                                            |
| ------ | ----- | -------- | --------- | -------------------------------------------------------------------------------- |
| Status | 80px  | `status` | Read-only | Color-coded badge: New (gray), Saved (blue), Submitted (green), Frozen (purple). |

#### Governance / Divergence Columns

| Column     | Width | Source                   | Editable  | Notes                                                                                |
| ---------- | ----- | ------------------------ | --------- | ------------------------------------------------------------------------------------ |
| Flags      | 32px  | `governanceFlags.length` | Read-only | Warning icon if flags > 0. Tooltip shows flag details. Click opens governance panel. |
| Divergence | 32px  | `crmDivergence`          | Read-only | Alert icon if true. Tooltip shows `crmDivergenceDetails`.                            |
| Approval   | 32px  | `pendingApproval`        | Read-only | Lock icon if true. Row is non-editable while pending.                                |

#### Incentive Estimate Columns (optional — `showInlineEstimator`)

| Column      | Width | Source           | Editable  | Notes                                                                      |
| ----------- | ----- | ---------------- | --------- | -------------------------------------------------------------------------- |
| Est. Payout | 100px | `payoutEstimate` | Read-only | Formatted currency.                                                        |
| Rate        | 60px  | `incentiveRate`  | Read-only | Percent.                                                                   |
| Tier Impact | 150px | `tierImpact`     | Read-only | Text: "Crosses → Tier 2 (+4%)" or "No tier change". Highlight if crossing. |

#### Dedup Column (top-level only)

| Column   | Width | Source                         | Editable  | Notes                                                                                                       |
| -------- | ----- | ------------------------------ | --------- | ----------------------------------------------------------------------------------------------------------- |
| Adjusted | 32px  | `metricValuesPreDedup != null` | Read-only | Info icon. Tooltip: "Adjusted from $1M → $500K (50% deal contribution)". Only present when dedup is active. |

### 5.2 Row Behavior

**Row coloring (status indicator):**
| Status | Left border color | Background |
|---|---|---|
| New | Gray (#B0B0B0) | None |
| Saved (dirty) | Yellow (#F2CF00) | Light yellow tint |
| Saved (clean) | Blue (#1589EE) | None |
| Submitted | Green (#04844B) | None |
| Frozen | Purple (#7B64FF) | Light gray (non-editable) |

_Intentional departure from Temenos (see DD-3): Temenos used Red for New. RevenueTrust uses Gray — Red implies error in SLDS conventions._

**Editable cells:**

- Disabled when: `status === 'Frozen'` OR `pendingApproval === true` OR `!context.canEdit`
- On edit: mark row dirty in `dirtyOverrides` Map, update cell value locally
- Visual: dirty cells get a subtle left-border marker

**Expandable row:**
When the user clicks the +/− toggle, an inline expansion row appears below:

```
┌──────────────────────────────────────────────────────────────────┐
│ [Comment textarea]                    │ [Comment Thread]         │
│ "Add a note about this deal..."       │  Apr 12 — Jane: "..."   │
│                                       │  Apr 10 — Bob: "..."    │
│                                       │  [View all comments →]  │
│                                       │                         │
│ Previous Level: Commit @ $250K        │ Previous Period: $200K  │
│ Dedup: 50% contribution ($500K orig)  │                         │
└──────────────────────────────────────────────────────────────────┘
```

### 5.3 Pagination

```
Showing 1-40 of 127 records                              [◀ Prev]  Page 1 of 4  [Next ▶]
```

- Default page size from `config.paginationSize` (typically 40)
- In client-side mode: paginate the filtered JS array
- In server-side mode: pass `pageNumber` in the request

### 5.4 Sorting

Clicking a column header sorts. Supported sort fields:

- `recordName`, `ownerName`, `category`, `closeDate`, `metricValue` (primary metric), `healthScore`
- Toggle ASC ↔ DESC on repeat click
- Visual: sort arrow icon in column header
- Client-side mode: sort in JS
- Server-side mode: pass `sortField` + `sortDirection` in request

---

## 6. revtForecastSummaryPanel

### 6.1 Layout

```
┌────────────────────────────────────────────────────────────────┐
│ ATTAINMENT                 │  CATEGORY TOTALS                  │
│ ┌────────────────────────┐ │  ┌───────────┬──────────┬──────┐ │
│ │ ●●●●●●●○○○  72%       │ │  │ Commit    │ $2.1M    │  14  │ │
│ │ $7.2M / $10M target    │ │  │ Best Case │ $1.5M    │   9  │ │
│ │ Remaining: $2.8M       │ │  │ Pipeline  │ $4.2M    │  23  │ │
│ │ Coverage: 2.8x         │ │  │ Closed    │ $1.8M    │   7  │ │
│ └────────────────────────┘ │  └───────────┴──────────┴──────┘ │
│                            │                                   │
│ TIER (if Incentives active)│  COVERAGE                         │
│ Current: Tier 2 @ 8%      │  Pipeline / Remaining = 2.8x      │
│ Next: Tier 3 @ 12%        │  (Healthy: > 3x recommended)      │
│ Distance: $800K            │                                   │
└────────────────────────────────────────────────────────────────┘
```

### 6.2 Data Sources

| Panel Section   | Source                                                              | Refresh                   |
| --------------- | ------------------------------------------------------------------- | ------------------------- |
| Attainment ring | `context.attainment`                                                | On context load           |
| Category totals | `recordSet.summary.categoryTotals` / `categoryCounts`               | On every grid load/filter |
| Coverage ratio  | `recordSet.summary.coverageRatio`                                   | On every grid load/filter |
| Tier info       | `recordSet.summary.currentTier`, `nextTierName`, `nextTierDistance` | On context load           |

### 6.3 Budget Mode

When `context.isBudgetMode === true`:

- Panel header shows "Budget" instead of "Forecast"
- Category totals use budget category labels (from `Budget_Equivalent__c`)
- Attainment section is hidden (budget mode doesn't track attainment)
- Coverage ratio label changes to "Budget Coverage"

### 6.4 Attainment Ring

SVG-based circular progress indicator. Color changes by attainment:
| Range | Color | Label |
|---|---|---|
| 0–49% | Red (#EA001E) | Below Target |
| 50–89% | Yellow (#F2CF00) | On Track |
| 90–100% | Green (#04844B) | Near Target |
| 100%+ | Blue (#1589EE) | Above Target |

---

## 7. revtOpportunityForecast — Record Page Component

### 7.1 Purpose

A self-contained LWC that organizations place on the **Opportunity Lightning Record Page** (FlexiPage). Allows reps and managers to forecast a single deal without navigating to the full forecast grid.

### 7.2 Interface

```javascript
// meta.xml targets
<targets>
    <target>lightning__RecordPage</target>
</targets>
<targetConfigs>
    <targetConfig targets="lightning__RecordPage">
        <objects>
            <object>Opportunity</object>
        </objects>
        <property name="showComments" type="Boolean" default="true"
                  label="Show Comment Thread" />
        <property name="showIncentiveEstimate" type="Boolean" default="true"
                  label="Show Commission Estimate" />
        <property name="showHealthScore" type="Boolean" default="true"
                  label="Show Deal Health Score" />
    </targetConfig>
</targetConfigs>
```

### 7.3 Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ Forecast Override                                    [Status Badge] │
│─────────────────────────────────────────────────────────────────────│
│                                                                     │
│ Period: [Q2 2026 ▼]                                                │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Category      [Commit          ▼]    🟢                      │   │
│ ├──────────────────────────────────────────────────────────────┤   │
│ │ Revenue       [$  325,000      ]    ↑ vs prev period         │   │
│ │ ACV           [$  120,000      ]    — flat                   │   │
│ │ Quantity      [    12          ]    ↓ from 15                │   │
│ ├──────────────────────────────────────────────────────────────┤   │
│ │ Close Date Override  [2026-06-15]                             │   │
│ ├──────────────────────────────────────────────────────────────┤   │
│ │ CRM Values (read-only)                                       │   │
│ │ Amount: $300,000  │  Stage: Negotiation  │  Close: 2026-06-30│   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ 💬 Comments (2)                                              │   │
│ │ Apr 12 — Jane Smith (Manager): "Pushed to June, customer..."│   │
│ │ Apr 10 — Bob Jones (Rep): "Contract review in progress"      │   │
│ │ [Add comment...]                                              │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ 🏥 Health: 78/100 (Yellow)    │  📊 Est. Payout: $26,000    │   │
│ │ ⚠ CRM Divergence: Amount      │  Rate: 8% (Tier 2)          │   │
│ │   changed $300K → $280K       │  Tier Impact: No change      │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ [Save]  [Submit]                          Last saved: Apr 14, 2:30p │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.4 Data Loading

The Opportunity page component uses a **dedicated single-record Apex method** — it does NOT call `getForecastRecords()` (which is scope-based and would return the wrong record with pagination).

```javascript
// Uses @api recordId from the record page context
@api recordId;    // Opportunity Id

connectedCallback() {
    1. wire: getForecastConfig()
       — Provides: metrics, categories, periods, currentPeriod, currencyMode
    2. imperative: getOpportunityForecast(this.recordId, currentPeriodId)
       — Dedicated method: queries single override + pipeline record + health + incentive
       — Returns: ForecastRecordDTO for this Opportunity, or null if not in scope
    3. If result is null:
       — Show info card: "This opportunity is not in your current forecast scope."
       — Show read-only CRM values from @wire getRecord
    4. imperative: getLastForecastComment(this.recordId, userId)
       — Load comment thread
}
```

**New Apex method (required):**

```java
@AuraEnabled
public static ForecastRecordDTO getOpportunityForecast(Id opportunityId, Id periodId)
```

Queries the single override for Opportunity + current user (`UserInfo.getUserId()`) + period. Merges with pipeline data via `PipelineObjectService`, loads health score from `Deal_Signal__c`, computes incentive estimate. Returns `null` if the Opportunity is not in the user's forecast scope (no participant record or Opportunity not owned by user/reports).

### 7.5 Save Behavior

- Save button calls `saveForecastData` with a single-item override list
- Submit button calls `submitForecastData` with the single override
- After save: refresh the status badge, update `lastSaved` timestamp
- After submit: show success toast with snapshot info
- If period is Frozen/Closed: all fields read-only, Save/Submit hidden
- If user has no participant record for this period: show read-only CRM values with message "You are not a forecast participant for this period."

### 7.6 Period Selector

Shows available Open periods in a combobox. Defaults to the current active period (the one where today falls between Start_Date and End_Date). Changing the period reloads the override data for that period.

### 7.7 Divergence Alert

If `crmDivergence === true`, show an inline alert:

```
⚠ CRM values changed after your last submission.
  Amount: $325,000 → $280,000 | Close Date: Jun 15 → Jul 1
  [Accept CRM Values]  [Keep Override]
```

- **Accept CRM Values:** Clears the override metric values and resets to CRM defaults
- **Keep Override:** Dismisses the alert (sets a local flag, divergence remains tracked)

### 7.8 Read-Only Scenarios

The component is fully read-only (no edit, no save/submit) when:

- Period status is Frozen or Closed
- User has no `Forecast_Participant__c` for this period
- `pendingApproval === true` (governance lock)
- Opportunity is not in the user's forecast scope (e.g., not owned by them or their reports)

In read-only mode, show the current override values (if any) with a "Read Only" badge and the reason.

---

## 8. Shared Components

### 8.1 revtHealthBadge

Small badge showing deal health score from Deal_Signal\_\_c.

```
Props: healthScore (Integer 0-100), healthBand (String: Green/Yellow/Red)
Render: Colored circle + score number
```

| Band           | Color   | Icon            |
| -------------- | ------- | --------------- |
| Green (70-100) | #04844B | utility:like    |
| Yellow (40-69) | #F2CF00 | utility:warning |
| Red (0-39)     | #EA001E | utility:ban     |
| null           | Gray    | utility:dash    |

### 8.2 revtTrendArrow

Trend indicator for metric comparison to previous period.

```
Props: trend (Integer: -1, 0, +1), label (String, optional)
```

| Value | Icon              | Color | CSS Class  |
| ----- | ----------------- | ----- | ---------- |
| +1    | utility:arrowup   | Green | `fcbetter` |
| 0     | utility:dash      | Gray  | —          |
| -1    | utility:arrowdown | Red   | `fcworse`  |

### 8.3 revtCategoryPill

Color-coded category display using colors from `Forecast_Category__c.Color_Hex__c`.

```
Props: label (String), color (String hex), isTerminal (Boolean)
Render: Pill with background color, white text. Strikethrough if isTerminal.
```

### 8.4 revtInlineEstimator

Commission impact estimate for a single deal. Client-side calculation using cached tier data from `context.attainment`.

```
Props: payoutEstimate (Decimal), incentiveRate (Decimal),
       thresholdProximity (Decimal), tierImpact (String)
```

**Client-side tier calculation (AD-8 from implementation sequence):**

On page load, `context.attainment` provides: `target`, `achieved`, `currentTier`, `currentRate`, `nextTierName`, `nextTierDistance`. When the user changes a metric value in the grid, the estimator recalculates:

```javascript
// Pseudo-code — runs in JS, no server call
const newProjected = context.attainment.achieved + sumOfEditedMetrics;
const newAttainmentPct = (newProjected / context.attainment.target) * 100;

// Walk tiers to find projected tier
for (const tier of cachedTiers) {
  if (newAttainmentPct >= tier.min && newAttainmentPct < tier.max) {
    projectedTier = tier;
    break;
  }
}

payoutEstimate = dealAmount * projectedTier.rate;
tierImpact =
  projectedTier !== currentTier
    ? `Crosses → ${projectedTier.name} (+${projectedTier.rate - currentRate}%)`
    : "No tier change";
```

### 8.5 revtMultiSelect

Reusable multi-select dropdown. Ported from Temenos `SL_MultiSelectUtility`.

```
Props: label (String), options (Array<{label, value}>), selectedValues (Array<String>),
       placeholder (String)
Events: change → { detail: { selectedValues: [...] } }
```

Features:

- Search/filter within options
- "Select All" / "Clear All"
- Selected items shown as pills below the dropdown
- Dropdown closes on outside click

### 8.6 revtForecastCommentThread

Comment display and input for a single pipeline record.

```
Props: recordId (Id), overrideId (Id), periodId (Id), comments (Array<ForecastCommentDTO>)
Events: commentadded → { detail: { commentId } }
```

Layout:

- Scrollable list of comments (newest first)
- Each comment: author, level label, date, text
- New comment textarea at bottom with "Post" button
- Comment type selector: Note, Escalation, Question

---

## 9. CSS Design Tokens

Consistent with SLDS. Custom tokens for forecast-specific styling:

```css
:host {
  --revt-status-new: #b0b0b0;
  --revt-status-saved: #1589ee;
  --revt-status-submitted: #04844b;
  --revt-status-frozen: #7b64ff;
  --revt-status-dirty: #f2cf00;

  --revt-trend-up: #04844b;
  --revt-trend-down: #ea001e;
  --revt-trend-flat: #706e6b;

  --revt-health-green: #04844b;
  --revt-health-yellow: #f2cf00;
  --revt-health-red: #ea001e;

  --revt-row-frozen-bg: #f3f3f3;
  --revt-cell-dirty-border: #f2cf00;
  --revt-dedup-info: #0176d3;
}
```

---

## 10. Accessibility

| Requirement         | Implementation                                                                                                         |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Keyboard navigation | Tab through editable cells. Enter to expand row. Escape to close modals.                                               |
| Screen reader       | `aria-label` on all interactive elements. `role="grid"` on data table. `aria-sort` on sorted columns.                  |
| Focus management    | After save/submit, focus returns to the first dirty row. After drill-in, focus on breadcrumb.                          |
| Color contrast      | All status colors meet WCAG AA 4.5:1 ratio. Never convey information by color alone — always paired with icon or text. |
| Reduced motion      | Trend arrows use icons, not animations. Loading spinner respects `prefers-reduced-motion`.                             |

---

## 11. Error Handling

| Scenario                   | Behavior                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------- |
| Config load fails          | Show full-page error: "Forecast configuration not found. Contact your admin."                           |
| No participant record      | Show info card: "You are not a forecast participant for this period." Read-only CRM data still visible. |
| Save fails (period frozen) | Toast error with period name. Refresh grid to show frozen state.                                        |
| Save partial failure       | Toast warning: "3 of 5 overrides saved. 2 failed: [reason]." Mark failed rows with error icon.          |
| Governance block           | Inline error on the row: "Pending governance approval. Edits blocked."                                  |
| Network timeout            | Toast error with retry button. Dirty changes preserved locally.                                         |
| Access denied (drill-in)   | Toast error: "You do not have permission to view this participant's forecast." Pop breadcrumb.          |

---

## 12. Performance Targets

| Metric                                       | Target      | How                                                                 |
| -------------------------------------------- | ----------- | ------------------------------------------------------------------- |
| Initial load (config + context + first page) | < 2 seconds | Config is cached (`cacheable=true`). Context + records in parallel. |
| Filter change (client-side)                  | < 100ms     | JS array filter, no server call for ≤ 500 records.                  |
| Filter change (server-side)                  | < 1 second  | Single Apex call with filter parameters.                            |
| Save (up to 50 overrides)                    | < 3 seconds | Batch DML in single transaction.                                    |
| Page navigation                              | < 500ms     | Client-side: array slice. Server-side: single Apex call.            |
| Inline estimator recalc                      | < 50ms      | Pure JS, no server call.                                            |
| CSV export (500 records)                     | < 1 second  | Client-side generation using Blob API.                              |

---

## 13. Decision Points

### DP-LWC-1: Add `getOpportunityForecast()` Apex method?

**Context:** The `revtOpportunityForecast` record page component needs data for a single Opportunity. Loading the entire scope via `getForecastRecords` and filtering client-side is wasteful.

**Recommendation:** Yes — add a targeted method that queries the single override + pipeline record + health score + incentive estimate for one Opportunity. Keeps the record page load fast (<1s).

### DP-LWC-2: Use `lightning-datatable` or custom HTML table?

**Context:** `lightning-datatable` provides built-in sorting, column resize, infinite scroll but has limited inline edit support for custom cell types (category picker, trend arrows, health badges).

**Recommendation:** Custom HTML table. The Temenos source uses custom `<table>` with full control over cell rendering. The forecast grid needs: (a) inline-editable comboboxes in cells, (b) custom components in cells (health badge, trend arrow, category pill), (c) expandable rows with comment thread, (d) colored row borders by status. None of these are well-supported by `lightning-datatable`'s cell customization model.

### DP-LWC-3: Dirty tracking granularity?

**Context:** Should dirty tracking be per-cell or per-row?

**Recommendation:** Per-row. When any cell in a row changes, the entire row is saved. This matches the `ForecastOverrideSaveDTO` structure (one DTO per pipeline record, not per field). Simpler state management, and the save payload is already row-oriented.

### DP-LWC-4: Opportunity page component — same namespace or App Builder configurable?

**Context:** The `revtOpportunityForecast` component lives in the managed package. Customers add it to their Opportunity FlexiPage via App Builder.

**Recommendation:** Ship as a managed component with `lightning__RecordPage` target, restricted to `Opportunity` object. Expose `showComments`, `showIncentiveEstimate`, `showHealthScore` as design attributes so admins can toggle features. No custom objects or fields required on the subscriber's Opportunity — the component reads via the deployed Forecast_Override\_\_c + PipelineObjectService.

---

## 14. File Structure

```
force-app/main/default/lwc/
├── revtForecastApp/
│   ├── revtForecastApp.html
│   ├── revtForecastApp.js
│   ├── revtForecastApp.css
│   └── revtForecastApp.js-meta.xml
├── revtForecastFilterBar/
│   ├── revtForecastFilterBar.html
│   ├── revtForecastFilterBar.js
│   ├── revtForecastFilterBar.css
│   └── revtForecastFilterBar.js-meta.xml
├── revtForecastGrid/
│   ├── revtForecastGrid.html
│   ├── revtForecastGrid.js
│   ├── revtForecastGrid.css
│   └── revtForecastGrid.js-meta.xml
├── revtForecastRow/
│   ├── revtForecastRow.html
│   ├── revtForecastRow.js
│   ├── revtForecastRow.css
│   └── revtForecastRow.js-meta.xml
├── revtForecastTotalsRow/
│   ├── revtForecastTotalsRow.html
│   ├── revtForecastTotalsRow.js
│   └── revtForecastTotalsRow.js-meta.xml
├── revtForecastSummaryPanel/
│   ├── revtForecastSummaryPanel.html
│   ├── revtForecastSummaryPanel.js
│   ├── revtForecastSummaryPanel.css
│   └── revtForecastSummaryPanel.js-meta.xml
├── revtOpportunityForecast/
│   ├── revtOpportunityForecast.html
│   ├── revtOpportunityForecast.js
│   ├── revtOpportunityForecast.css
│   └── revtOpportunityForecast.js-meta.xml
├── revtForecastCommentThread/
│   ├── revtForecastCommentThread.html
│   ├── revtForecastCommentThread.js
│   └── revtForecastCommentThread.js-meta.xml
├── revtHealthBadge/
│   ├── revtHealthBadge.html
│   ├── revtHealthBadge.js
│   ├── revtHealthBadge.css
│   └── revtHealthBadge.js-meta.xml
├── revtTrendArrow/
│   ├── revtTrendArrow.html
│   ├── revtTrendArrow.js
│   └── revtTrendArrow.js-meta.xml
├── revtInlineEstimator/
│   ├── revtInlineEstimator.html
│   ├── revtInlineEstimator.js
│   └── revtInlineEstimator.js-meta.xml
├── revtCategoryPill/
│   ├── revtCategoryPill.html
│   ├── revtCategoryPill.js
│   ├── revtCategoryPill.css
│   └── revtCategoryPill.js-meta.xml
├── revtMultiSelect/
│   ├── revtMultiSelect.html
│   ├── revtMultiSelect.js
│   ├── revtMultiSelect.css
│   └── revtMultiSelect.js-meta.xml
└── revtConfirmationDialog/
    ├── revtConfirmationDialog.html
    ├── revtConfirmationDialog.js
    └── revtConfirmationDialog.js-meta.xml
```

---

## 15. Apex API Additions Required

| Method                                                              | Controller           | Purpose                                                                                                                                                                                                                                                                       | New?    |
| ------------------------------------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `getOpportunityForecast(Id opportunityId, Id periodId)`             | `ForecastController` | Single-record load for Opp page component                                                                                                                                                                                                                                     | **NEW** |
| `acceptCrmValues(Id overrideId)`                                    | `ForecastController` | Accept CRM divergence: preserves the override record for audit history, clears overridden metric/date fields, refreshes values from current CRM pipeline record, resets `CRM_Divergence__c = false` and clears `CRM_Divergence_Details__c`. Does NOT delete the override row. | **NEW** |
| `exportForecastData(Id periodId, Id participantId, String scopeId)` | `ForecastController` | Server-side CSV generation for large datasets (>500 records). Returns `ExportResult { String fileName, String mimeType, String csvContent }`. LWC creates Blob from `csvContent` and triggers browser download with `fileName`.                                               | **NEW** |

### 15.2 DTO Additions

| Field              | DTO                       | Type       | Purpose                                                                                                                                                                                           |
| ------------------ | ------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dataVersion`      | `ForecastRecordDTO`       | `String`   | Composite hash of override.LastModifiedDate + pipeline.LastModifiedDate + healthSignal.LastModifiedDate. Used for conflict detection — represents the assembled row state, not just the override. |
| `forceOverwrite`   | `ForecastOverrideSaveDTO` | `Boolean`  | When `true`, bypasses version conflict check. Set by UI after user chooses "Keep Mine" in conflict dialog. Default: `false`.                                                                      |
| `lastModifiedDate` | `ForecastRecordDTO`       | `Datetime` | Override's `LastModifiedDate` (or `null` if no override exists). Used by LWC for display only (e.g., "Last saved: Apr 14, 2:30p"). Conflict detection uses `dataVersion`, not this field.         |

### 15.3 Conflict Resolution API Contract

**Normal save:** `forceOverwrite = false` (default). Apex checks `dataVersion` against current assembled state. If mismatch → returns error prefixed `CONFLICT:{recordId}:{details}`.

**Force save (after conflict review):** User reviews diff, picks "Keep Mine" → LWC re-sends the same save with `forceOverwrite = true`. Apex skips version check and writes the user's values.

**Accept Theirs:** User picks "Accept Theirs" → LWC discards local edits for that row, reloads the row from server. No save call needed.

---

## 16. Component Inventory Summary

| #   | Component                   | Lines (est.) | Complexity | Dependencies                                                                                      |
| --- | --------------------------- | ------------ | ---------- | ------------------------------------------------------------------------------------------------- |
| 1   | revtForecastApp             | ~450         | High       | All children                                                                                      |
| 2   | revtForecastFilterBar       | ~220         | Medium     | revtMultiSelect                                                                                   |
| 3   | revtForecastGrid            | ~350         | High       | revtForecastRow, revtForecastTotalsRow                                                            |
| 4   | revtForecastRow             | ~300         | High       | All shared components                                                                             |
| 5   | revtForecastTotalsRow       | ~80          | Low        | revtCategoryPill                                                                                  |
| 6   | revtForecastSummaryPanel    | ~220         | Medium     | —                                                                                                 |
| 7   | revtForecastCommentThread   | ~150         | Medium     | —                                                                                                 |
| 8   | **revtOpportunityForecast** | ~350         | **High**   | revtHealthBadge, revtTrendArrow, revtInlineEstimator, revtCategoryPill, revtForecastCommentThread |
| 9   | revtHealthBadge             | ~40          | Low        | —                                                                                                 |
| 10  | revtTrendArrow              | ~30          | Low        | —                                                                                                 |
| 11  | revtInlineEstimator         | ~100         | Medium     | —                                                                                                 |
| 12  | revtCategoryPill            | ~30          | Low        | —                                                                                                 |
| 13  | revtMultiSelect             | ~200         | Medium     | —                                                                                                 |
| 14  | revtConfirmationDialog      | ~100         | Low        | —                                                                                                 |
|     | **Total**                   | **~2,620**   |            | **14 components**                                                                                 |

---

## 17. V1.1 / V1.2 — FEEDBACK FIXES

### 17.1 Fix #1: State Reconciliation / Conflict Detection (GAP 1)

**Problem:** No conflict resolution when server data changes while user is editing.

**Fix:** Optimistic concurrency using composite `dataVersion` hash (defined in §15.2).

The `dataVersion` field on `ForecastRecordDTO` is a server-computed hash representing the assembled row state — not just the override row. It incorporates: override `LastModifiedDate`, pipeline source `LastModifiedDate`, health signal timestamp, and governance state. This ensures that any meaningful server-side change (CRM update, health recalc, governance flag, dedup change) is detected, not just override edits.

```javascript
// On record load, capture version
for (const rec of recordSet.records) {
  this.rowDataVersionMap.set(rec.recordId, rec.dataVersion);
}

// On save, send dataVersion per row in the DTO
// Apex recomputes dataVersion from current DB state
// If sent dataVersion !== current dataVersion → CONFLICT error
```

**Apex contract:** `ForecastService.saveOverrides()` checks `dataVersion` for each row when `forceOverwrite !== true`. If mismatch → returns `CONFLICT:{recordId}:Record modified since you loaded this page.` The `lastModifiedDate` field is retained on the DTO for display purposes (e.g., "Last saved: Apr 14, 2:30p") but is not the conflict detection mechanism.

**UI behavior on conflict:**

1. Toast warning: "1 record was modified by another user since you loaded this page."
2. Conflicting row highlighted with orange border
3. Inline action: "Review Changes" opens a side-by-side diff showing user's values vs. server values
4. User picks: "Keep Mine" (re-sends with `forceOverwrite = true` per §15.3) or "Accept Theirs" (discard local edits, reload row from server)

### 17.2 Fix #2: Bulk Save Chunking (GAP 2)

**Problem:** No enforcement of save batch size. User edits 200 rows → single DML → governor failure.

**Fix:** LWC chunks dirty overrides into batches of 50 before calling Apex.

```javascript
async handleSave() {
    const allDirty = Array.from(this.dirtyOverrides.values());
    const CHUNK_SIZE = 50;
    const chunks = [];
    for (let i = 0; i < allDirty.length; i += CHUNK_SIZE) {
        chunks.push(allDirty.slice(i, i + CHUNK_SIZE));
    }

    let totalSaved = 0;
    let allErrors = [];
    for (const chunk of chunks) {
        const result = await saveForecastData({
            request: { overrides: chunk, periodId, participantId, isPartial: true }
        });
        if (result.success) {
            totalSaved += result.updatedOverrideIds.length;
        } else {
            allErrors.push(...result.errors);
        }
    }
    // Show aggregated result
}
```

Progress indicator: "Saving batch 2 of 4..." with progress bar.

### 17.3 Fix #3: Filter Debouncing (GAP 3)

**Problem:** Multi-select filter changes (category, stage, health) not debounced. Rapid clicks → multiple Apex calls.

**Fix:** All filter change handlers use a shared debounce at 250ms:

```javascript
handleFilterChange = debounce((filterPayload) => {
  if (this.isClientSideFiltering) {
    this.applyClientSideFilters(filterPayload);
  } else {
    this.loadRecordsFromServer(filterPayload);
  }
}, 250);
```

Search input debounce remains at 300ms (longer because of keystroke frequency).

### 17.4 Fix #4: UI Lock Coordination (GAP 4)

**Problem:** No rules for what happens when save is triggered during load, or filter changes during save.

**Fix:** `isLocked` flag blocks all mutating UI interactions during async operations.

| Action                   | During Load? | During Save? | During Submit/Freeze? |
| ------------------------ | ------------ | ------------ | --------------------- |
| Edit cells               | Blocked      | Blocked      | Blocked               |
| Change filters           | Allowed      | Blocked      | Blocked               |
| Change page              | Allowed      | Blocked      | Blocked               |
| Change period/scope      | Blocked      | Blocked      | Blocked               |
| Click Save/Submit/Freeze | Blocked      | Blocked      | Blocked               |
| Expand row               | Allowed      | Blocked      | Blocked               |
| CSV Export               | Allowed      | Blocked      | Blocked               |
| Scroll                   | Allowed      | Allowed      | Allowed               |
| Dismiss toast            | Allowed      | Allowed      | Allowed               |

**Rationale for blocking expand/CSV during save:** Expanding rows during save can expose stale comment data or mixed local/server state. CSV export during save would capture an inconsistent snapshot. Both are allowed during normal load since the data is stable.

Implementation: Set `isLocked = true` before async call, `isLocked = false` in finally block. All action buttons check `isLocked` in their disabled condition. Editable cells check `isLocked` in their `disabled` attribute.

### 17.5 Fix #5: Row-Level Error Recovery (GAP 5)

**Problem:** Partial save failure handling is weak. No row-level retry or persistent error display.

**Fix:** `rowErrorMap` tracks per-row errors that persist until the row is successfully saved or the user dismisses the error.

```javascript
// After save, if partial failure:
for (const error of result.errors) {
  if (error.startsWith("ROW:")) {
    const [_, recordId, message] = error.split(":");
    this.rowErrorMap.set(recordId, message);
  }
}
```

**Row error display:**

- Red error icon on the row's status column
- Tooltip shows the error message
- "Retry" button on the error icon — re-saves just that row
- Error clears automatically when the row is successfully saved

### 17.6 Fix #6: Virtual Scrolling Plan (GAP 6)

**Not GA blocker.** Document for Phase 2:

> When the forecast grid handles >100 visible rows (after client-side filtering), consider implementing virtual scrolling to keep DOM node count under 200 rows. Use IntersectionObserver to render only visible rows + buffer. Phase 2 enhancement — not required for V1 with 40-row pagination.

### 17.7 Fix #7: Keyboard Editing Model (GAP 7)

**Power user keyboard navigation for the editable grid:**

| Key           | Context          | Behavior                                                                                   |
| ------------- | ---------------- | ------------------------------------------------------------------------------------------ |
| Tab           | In editable cell | Move to next editable cell in row. At end of row, move to first editable cell of next row. |
| Shift+Tab     | In editable cell | Move to previous editable cell.                                                            |
| Enter         | In editable cell | Commit current value, move down to same column in next row.                                |
| Escape        | In editable cell | Revert to last saved value, exit edit mode.                                                |
| Arrow Up/Down | In editable cell | Move to same column in adjacent row.                                                       |
| Space         | On expand toggle | Toggle row expansion.                                                                      |

Implementation: `onkeydown` handler on the grid container, delegating based on `event.target` data attributes (`data-row-id`, `data-column-id`).

### 17.8 Fix #8: CSV Export Dual Path (GAP 8)

Already addressed in §3.4 toolbar update:

- ≤500 records (client-side filtering active): Generate CSV from JS array using Blob API
- > 500 records (server-side filtering): Call `exportForecastData()` Apex method

### 17.9 Fix #9: Offline / Retry Model (GAP 9)

**Not GA blocker.** Document for Phase 2:

> On network failure during save: preserve dirty overrides in `sessionStorage` under key `revt_unsaved_{periodId}_{userId}`. On next page load, detect unsaved changes and show recovery banner: "You have unsaved forecast changes from your last session. [Restore] [Discard]". Restore loads the dirty values back into the grid for re-save.

### 17.10 Fix #10: Submit/Freeze Chunking & Dirty Row Rules (V1.1 feedback #6)

**Save:** Chunked in LWC at 50 rows per batch (§17.2). Each batch is a separate `saveForecastData()` call.

**Submit:** Submit always saves-first then submits. Explicit rules:

| Scenario                        | Behavior                                                                                                                |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| All rows clean (already saved)  | Submit sends override IDs only. No re-save.                                                                             |
| Some rows dirty (unsaved edits) | LWC saves dirty rows first (chunked at 50), then submits all. Single `submitForecastData` call with full override list. |
| Submit on zero overrides        | Rejected client-side: "No overrides to submit."                                                                         |

Submit itself is **not chunked** — the Apex method handles all eligible overrides in one transaction (they're already persisted by the save step). The submit call sets Status = 'Submitted', freezes exchange rates, and creates the snapshot in a single DML batch.

**Freeze:** Always a server-side scope action. **Never driven by LWC row batches.** The LWC calls `freezeForecastData(periodId, scopeId)` once — Apex queries all overrides in scope internally and processes them. No client-side chunking needed or permitted.

### 17.11 Fix #11: Budget Mode Behavioral Overrides (V1.1 feedback #7)

When `context.isBudgetMode === true`, the following behavioral overrides apply across all components:

| Aspect                   | Normal Mode                                            | Budget Mode                                                                                                                     |
| ------------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| **Categories**           | From `config.categories[]` where `Is_Active__c = true` | Only categories where `Budget_Equivalent__c` is populated. Display `Budget_Equivalent__c` label instead of `Category_Label__c`. |
| **Editable metrics**     | All metrics where `isEditable = true`                  | Same — all editable metrics remain editable. Budget values are entered in the same metric slots.                                |
| **Inline estimator**     | Visible (shows commission impact)                      | **Hidden.** Budget mode is planning, not commission-linked.                                                                     |
| **Attainment panel**     | Shows target/achieved/attainment% ring                 | **Hidden.** Budget mode has no attainment concept.                                                                              |
| **Coverage ratio**       | Pipeline / Remaining                                   | **Budget Coverage:** Budget total / Annual plan target. Different label, same formula structure.                                |
| **Submit button label**  | "Submit"                                               | "Submit Budget"                                                                                                                 |
| **Freeze button label**  | From `config.topLevelActionLabel`                      | "Lock Budget"                                                                                                                   |
| **Status labels**        | Saved, Submitted, Frozen                               | Same labels — no change.                                                                                                        |
| **CSV export columns**   | Includes incentive estimate columns                    | **Excludes** incentive columns (since estimator is hidden).                                                                     |
| **Summary panel header** | "Forecast"                                             | "Budget"                                                                                                                        |

### 17.12 Fix #12: Currency Toggle Rules (V1.1 feedback #8)

**Canonical rule:** All editable values are always stored in **corporate currency**. Local currency values are **display-only projections**.

| Rule                      | Detail                                                                                                                                                                  |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Edit target**           | Users always edit in corporate currency. The editable input fields bind to `metricValues['metric_N']` which is corporate.                                               |
| **Local display**         | Local values (`metricValuesLocal`) are read-only, computed server-side as `corporate × Exchange_Rate__c`.                                                               |
| **Toggle behavior**       | The corporate/local toggle swaps which value is shown as primary (large font) vs. secondary (small gray parenthetical). It does **not** change which value is editable. |
| **Entering local values** | Not permitted. Local fields are never editable. If a customer needs local-currency entry, that's a V2 feature requiring reverse FX conversion on save.                  |
| **FX rate date**          | Rate frozen at submit (§12.6). Draft overrides use live rate. Rate source: `Exchange_Rate__c` on the override, populated by `ForecastService.getExchangeRate()`.        |
| **Rounding**              | Local values rounded to 2 decimal places (`.setScale(2)`).                                                                                                              |
| **Toggle persistence**    | Toggle state saved to `sessionStorage` under `revt_currency_toggle_{userId}`. Persists across page loads.                                                               |
| **CSV export**            | When multi-currency is enabled, export includes **both** corporate and local columns regardless of toggle state.                                                        |

### 17.13 Fix #13: Error Classification (V1.1 feedback #9)

Errors returned from Apex are classified by prefix for differentiated UI handling:

| Error Prefix                      | Category                  | User Message                           | Retry?               | UI Behavior                                                                                                                                                                                                                                                                                                                 |
| --------------------------------- | ------------------------- | -------------------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CONFLICT:{recordId}:{details}`   | Version conflict          | "Record modified by another user"      | Via diff dialog      | Orange border. "Review Changes" action.                                                                                                                                                                                                                                                                                     |
| `VALIDATION:{recordId}:{details}` | Field/rule validation     | Specific validation message            | After user edits     | Red error icon on row. Tooltip shows message.                                                                                                                                                                                                                                                                               |
| `PERMISSION:{details}`            | Access denied             | "Insufficient permissions"             | No                   | Toast error. Disable action button.                                                                                                                                                                                                                                                                                         |
| `GOVERNOR:{details}`              | Salesforce governor limit | "Too many records. Try smaller batch." | After reducing scope | Toast error with guidance.                                                                                                                                                                                                                                                                                                  |
| `NETWORK`                         | Transient failure         | "Connection lost. Retrying..."         | Auto-retry (3×)      | Toast with spinner. Auto-retry with exponential backoff (1s, 2s, 4s). Safe because `saveForecastData()` is idempotent for the same override payload and record identifiers — retry does not create duplicate override rows (upsert by `overrideId` for existing, upsert by `Opportunity__c + User__c + Period__c` for new). |
| `EXCEPTION:{details}`             | Unhandled server error    | "An unexpected error occurred"         | Manual retry         | Toast error with "Retry" button.                                                                                                                                                                                                                                                                                            |

**LWC error handler:**

```javascript
handleSaveError(error) {
    const msg = error.body?.message || error.message || '';
    if (msg.startsWith('CONFLICT:')) {
        this.handleConflict(msg);
    } else if (msg.startsWith('VALIDATION:')) {
        this.handleRowValidation(msg);
    } else if (msg.startsWith('PERMISSION:')) {
        this.showPermissionError(msg);
    } else {
        this.showGenericError(msg);
    }
}
```

---

## 18. Testing Strategy

### 18.1 Jest Tests (Recommended for AppExchange)

| Test Level            | Components                                                                                     | Coverage                                                                                                       |
| --------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Unit tests**        | revtHealthBadge, revtTrendArrow, revtCategoryPill, revtInlineEstimator, revtConfirmationDialog | Props → rendered output. Edge cases (null values, boundary scores).                                            |
| **Integration tests** | revtForecastApp, revtForecastGrid, revtOpportunityForecast                                     | Mock wire adapters (`@salesforce/apex`). Verify: load sequence, filter application, save flow, error handling. |
| **Interaction tests** | revtForecastRow, revtForecastFilterBar, revtMultiSelect                                        | User events: edit cell → dirty tracking, filter change → event dispatch, keyboard navigation.                  |

### 18.2 Mock Data

Create `__tests__/mockData/` with:

- `mockConfig.json` — ForecastConfigDTO with 3 metrics, 5 categories
- `mockContext.json` — ForecastParticipantContextDTO for level 2 manager
- `mockRecordSet.json` — ForecastRecordSet with 10 records (mix of New, Saved, Submitted, with health scores and incentive data)
- `mockComments.json` — 3 ForecastCommentDTOs

### 18.3 Wire Adapter Mocks

```javascript
import { registerApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import getForecastConfig from "@salesforce/apex/ForecastController.getForecastConfig";
const getForecastConfigAdapter = registerApexTestWireAdapter(getForecastConfig);
```

### 18.4 Apex Test Obligations (New Methods)

This spec introduces 3 new Apex methods and new save semantics. The following Apex tests are **required** before deployment:

| Test                                     | Method Under Test        | Scenarios                                                                                   |
| ---------------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------- |
| `getOpportunityForecast_positive`        | `getOpportunityForecast` | User has participant record, Opp is in scope, override exists → returns full DTO            |
| `getOpportunityForecast_noOverride`      | `getOpportunityForecast` | Opp in scope but no override → returns DTO with CRM defaults, null overrideId               |
| `getOpportunityForecast_outOfScope`      | `getOpportunityForecast` | Opp not owned by user or reports → returns null                                             |
| `getOpportunityForecast_noParticipant`   | `getOpportunityForecast` | User has no participant for period → returns null                                           |
| `acceptCrmValues_positive`               | `acceptCrmValues`        | Override exists, CRM values differ → resets metric values to CRM, clears divergence flags   |
| `acceptCrmValues_frozenPeriod`           | `acceptCrmValues`        | Period is Frozen → throws error                                                             |
| `exportForecastData_positive`            | `exportForecastData`     | Valid scope with 100 records → returns CSV string with correct headers and row count        |
| `exportForecastData_empty`               | `exportForecastData`     | No records in scope → returns CSV with headers only                                         |
| `saveOverrides_conflictDetection`        | `saveOverrides`          | Override modified by another user after load → returns CONFLICT error                       |
| `saveOverrides_forceOverwrite`           | `saveOverrides`          | `forceOverwrite = true` → saves despite version mismatch                                    |
| `validateAccess_hierarchyDenied`         | `validateAccess`         | Caller is lower level than target → throws AuraHandledException                             |
| `validateAccess_delegateExpired`         | `validateAccess`         | Delegate_End\_\_c < today → throws AuraHandledException                                     |
| `queryForecastRecords_serverSideFilters` | `queryForecastRecords`   | Request with categoryFilter + stageFilter + searchText → returns correctly filtered results |
| `queryForecastRecords_sortDirection`     | `queryForecastRecords`   | Request with sortField=metricValue, sortDirection=DESC → returns correctly sorted results   |

---

## 19. Updated File Structure

```
force-app/main/default/lwc/
├── revtForecastApp/
├── revtForecastFilterBar/
├── revtForecastGrid/
├── revtForecastRow/
├── revtForecastTotalsRow/
├── revtForecastSummaryPanel/
├── revtOpportunityForecast/
├── revtForecastCommentThread/
├── revtHealthBadge/
├── revtTrendArrow/
├── revtInlineEstimator/
├── revtCategoryPill/
├── revtMultiSelect/
├── revtConfirmationDialog/
└── __tests__/
    └── mockData/
        ├── mockConfig.json
        ├── mockContext.json
        ├── mockRecordSet.json
        └── mockComments.json
```

---

_Forecasting LWC Components Spec V1.2_  
_14 components. 1 full-page app + 1 Opportunity record page component + 7 shared primitives._  
_V1.1 fixes: conflict detection, bulk chunking, filter debouncing, UI lock coordination, row-level errors, keyboard editing, CSV dual path, budget mode, currency toggle, confirmation dialogs, filter persistence, Jest test strategy._  
_V1.2 fixes: force-overwrite API contract, composite dataVersion hash, drill-in filter scoping, tightened action lock matrix, submit/freeze chunking rules, budget mode behavioral matrix, currency edit rules, error classification taxonomy, Apex test obligations._  
_3 intentional design departures from Temenos documented (DD-1 through DD-3)._  
_3 new Apex methods + 3 DTO field additions. 14 required Apex tests._
