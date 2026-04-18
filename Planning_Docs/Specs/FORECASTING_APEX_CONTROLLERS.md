# RevenueTrust — Forecasting Apex Controllers Spec

**Version:** 1.1  
**Date:** April 14, 2026  
**Status:** DRAFT — feedback incorporated, pending review  
**Companion specs:** FORECASTING_OBJECT_MODEL.md V1.4 (frozen), INCENTIVES_OBJECT_MODEL.md V1.7 (implementation through V2.0)  
**Implementation sequence:** Week 2  
**Ported from:** Temenos ORG — SL_OpportunityForecastCtrl.cls, SL_OpportunityForecastHelper.cls, ForecastHandler.cls, ForecastInitialization.cls

---

## 1. Architecture Overview

The Forecasting module's Apex layer has four distinct responsibilities:

```
┌──────────────────────────────────────────────────────────────────────┐
│                     FORECASTING APEX LAYER                           │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ ForecastController│  │ ForecastService  │  │ ForecastBatch    │  │
│  │ (@AuraEnabled)    │  │ (business logic) │  │ (scheduled jobs) │  │
│  │                   │  │                  │  │                  │  │
│  │ UI ← → Apex      │  │ CRUD + Rules     │  │ Period gen,      │  │
│  │ LWC calls these   │  │ Hierarchy sync   │  │ Snapshot,        │  │
│  │ methods           │  │ Override engine   │  │ Initialization   │  │
│  └────────┬──────────┘  └────────┬─────────┘  └────────┬─────────┘  │
│           │                      │                      │            │
│  ┌────────┴──────────────────────┴──────────────────────┴─────────┐  │
│  │                    ForecastDataService                          │  │
│  │  (query abstraction — reads from objects + PipelineObjectService)│  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

| Layer               | Class                                                                                              | Purpose                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Controller**      | `ForecastController.cls`                                                                           | @AuraEnabled methods called by LWC. Thin — delegates to Service.                          |
| **Service**         | `ForecastService.cls`                                                                              | Business logic: save, submit, freeze, copy, override lifecycle                            |
| **Data**            | `ForecastDataService.cls`                                                                          | Query abstraction: loads config, participants, overrides, pipeline records                |
| **Batch**           | `ForecastPeriodGeneratorBatch.cls`, `ForecastInitializationBatch.cls`, `ForecastSnapshotBatch.cls` | Scheduled jobs for period auto-generation, override initialization, and snapshot creation |
| **Trigger Handler** | `ForecastOverrideTriggerHandler.cls`                                                               | Before-save: governance rule evaluation, change event creation, divergence detection      |

**Key architectural decisions:**

- **Controller is thin.** All business logic in Service. Controller only handles @AuraEnabled method signatures, error wrapping, and DTO conversion.
- **No hardcoded hierarchy levels, metrics, categories, or periods.** Everything reads from Forecast_Configuration**c, Forecast_Metric**c, Forecast_Category\_\_c.
- **Pipeline records read via PipelineObjectService** (already built) — not hardcoded Opportunity queries.
- **Lazy materialization of overrides** (per spec §9.1): override rows created on first edit, NOT materialized for every visible record.

---

## 2. ForecastController.cls — @AuraEnabled API Surface

> **NOTE:** Method signatures in §2 are the V1.0 draft. Several have been superseded by §11 fixes:
>
> - `getFilteredForecast(Id userId)` → **SUPERSEDED by §11.1** — split into `getForecastConfig()` (cacheable) + `getParticipantContext(periodId, scopeId)` (imperative, uses UserInfo)
> - `getForecastRecords(periodId, participantId, scopeId, pageNumber)` → **SUPERSEDED by §11.2** — replaced with `ForecastQueryRequest` DTO including filters/sort/search
> - `saveForecastData(...)` → **Updated by §11.3** (Previous_Level/Period linkage) and **§11.11** (separate Save vs Submit request DTOs)
> - `copyFromPreviousLevel/LastForecast(...)` → **Updated by §11.15** — added `copyMode` parameter (OVERWRITE/MERGE/SKIP_EDITED)
>
> **For implementation, use the §11 versions.**

### 2.1 Initialization Methods

#### `getFilteredForecast(Id userId)`

**Called:** On page load. Returns everything the LWC needs to render the forecast view.

```java
@AuraEnabled(cacheable=true)
public static ForecastContext getFilteredForecast(Id userId) → ForecastContext
```

**Returns: ForecastContext** (wrapper class)

| Field               | Type                        | Source                              | Description                                                                |
| ------------------- | --------------------------- | ----------------------------------- | -------------------------------------------------------------------------- |
| `participant`       | ForecastParticipantDTO      | Forecast_Participant\_\_c           | Current user's participant record (level, scope, status, delegation)       |
| `config`            | ForecastConfigDTO           | Forecast_Configuration\_\_c         | Active config (metrics, categories, hierarchy levels, period type, layout) |
| `metrics`           | List\<ForecastMetricDTO\>   | Forecast_Metric\_\_c                | Ordered list of metrics with labels, formats, editability                  |
| `categories`        | List\<ForecastCategoryDTO\> | Forecast_Category\_\_c              | Ordered list of categories with colors, behaviors                          |
| `periods`           | List\<ForecastPeriodDTO\>   | Forecast_Period\_\_c                | Open + future periods for the period picker                                |
| `currentPeriod`     | ForecastPeriodDTO           | Forecast_Period\_\_c                | The currently active period                                                |
| `scopes`            | List\<ScopeDTO\>            | Forecast_Participant\_\_c hierarchy | Available scopes/territories for multi-scope users                         |
| `hierarchyLevel`    | Integer                     | Forecast_Participant\_\_c           | User's level (1 = rep, N = top)                                            |
| `levelLabel`        | String                      | Config Level_Labels\_\_c            | Display label: "Manager", "Director", etc.                                 |
| `topLevelLockLabel` | String                      | Config                              | "Freeze", "Lock", "Approve" — configurable                                 |
| `paginationSize`    | Integer                     | Config                              | Default 40                                                                 |
| `attainmentLayout`  | String                      | Config                              | Current_Period, Period_And_YTD, Expanded_Multi_Period, None                |
| `currencyMode`      | String                      | Config                              | Single, MultiWithDatedRates, DualDisplay                                   |
| `corporateCurrency` | String                      | Config                              | ISO currency code                                                          |
| `canSubmit`         | Boolean                     | Derived                             | Based on level permissions                                                 |
| `canFreeze`         | Boolean                     | Derived                             | True only for top-level user                                               |
| `isBudgetMode`      | Boolean                     | Forecast_Period\_\_c                | Whether current period is in budget mode                                   |
| `attainment`        | AttainmentDTO               | Quota\_\_c (cached)                 | Target, achieved, attainment %, tier info (if Incentives module active)    |

**Logic:**

1. Query Forecast_Participant**c for userId + current active Forecast_Period**c
2. If no participant record → return empty context with `canEdit = false`
3. Load Forecast_Configuration\_\_c + child Metric and Category records
4. Load available scopes (for multi-scope users, include summary scope)
5. Load attainment data from Forecast_Participant\_\_c cached fields (from Incentives module)
6. Derive permissions based on hierarchy level

---

#### `getForecastRecords(Id periodId, Id participantId, String scopeId, Integer pageNumber)`

**Called:** On page load (after getFilteredForecast), and on pagination/filter changes.

```java
@AuraEnabled
public static ForecastRecordSet getForecastRecords(
    Id periodId, Id participantId, String scopeId, Integer pageNumber) → ForecastRecordSet
```

**Returns: ForecastRecordSet** (wrapper)

| Field        | Type                      | Description                                     |
| ------------ | ------------------------- | ----------------------------------------------- |
| `records`    | List\<ForecastRecordDTO\> | Paginated pipeline records with override data   |
| `totalCount` | Integer                   | Total matching records (for "Showing X-Y of Z") |
| `pageNumber` | Integer                   | Current page                                    |
| `pageSize`   | Integer                   | Records per page                                |
| `summary`    | ForecastSummaryDTO        | Category totals, coverage ratio, attainment     |

**ForecastRecordDTO:**

| Field                  | Type                   | Source                            | Description                                                        |
| ---------------------- | ---------------------- | --------------------------------- | ------------------------------------------------------------------ |
| `recordId`             | Id                     | Pipeline record                   | Opportunity (or custom object) Id                                  |
| `recordName`           | String                 | PipelineObjectService             | Deal name                                                          |
| `ownerName`            | String                 | PipelineObjectService             | Deal owner                                                         |
| `stage`                | String                 | PipelineObjectService             | Current CRM stage                                                  |
| `closeDate`            | Date                   | PipelineObjectService             | CRM close date                                                     |
| `crmAmount`            | Decimal                | PipelineObjectService             | CRM amount (read-only reference)                                   |
| `overrideId`           | Id                     | Forecast_Override\_\_c            | Null if no override exists (lazy materialization)                  |
| `category`             | String                 | Override or default               | Forecast category (from override if exists, else default from CRM) |
| `metricValues`         | Map\<String, Decimal\> | Override or CRM                   | metric_1 through metric_6 values                                   |
| `metricValuesLocal`    | Map\<String, Decimal\> | Override                          | Local currency values                                              |
| `closeDateOverride`    | Date                   | Override                          | Manager's overridden close date                                    |
| `status`               | String                 | Override                          | New, Saved, Submitted, Frozen                                      |
| `comment`              | String                 | Override                          | Inline comment                                                     |
| `hierarchyLevel`       | Integer                | Override                          | Which level authored this override                                 |
| `previousLevelValues`  | Map\<String, Decimal\> | Previous_Level_Override           | What the level below submitted                                     |
| `trends`               | Map\<String, Integer\> | Previous_Period_Override          | Trend indicators (-1, 0, +1) per metric                            |
| `healthScore`          | Integer                | Deal_Signal\_\_c                  | 0-100 if Deal Health module active. Null otherwise.                |
| `healthBand`           | String                 | Deal_Signal\_\_c                  | Green, Yellow, Red                                                 |
| `governanceFlags`      | List\<String\>         | Governance_Event\_\_c             | Active governance flag IDs for this record                         |
| `pendingApproval`      | Boolean                | Override                          | CG-3 hard block flag                                               |
| `crmDivergence`        | Boolean                | Override                          | CRM changed after submission                                       |
| `crmDivergenceDetails` | String                 | Override                          | What changed                                                       |
| `incentiveRate`        | Decimal                | Comp_Plan**c / Commission_Tier**c | Current applicable rate % (if Incentives active)                   |
| `payoutEstimate`       | Decimal                | IncentiveImpactCalculator         | Estimated payout if this record closes (if Incentives active)      |
| `thresholdProximity`   | Decimal                | IncentiveImpactCalculator         | Distance to next rate tier                                         |
| `tierImpact`           | String                 | IncentiveImpactCalculator         | "Crosses → Tier 2 (+4% on all)" or "No tier change"                |

**Logic:**

1. Query Forecast_Participant\_\_c for the participant + scope
2. Determine pipeline record visibility: query pipeline records in scope (owner chain for ownership-based, territory for territory-based)
3. LEFT JOIN to Forecast_Override\_\_c for any existing overrides at this level for this period
4. For records WITHOUT override: show CRM values as read-only defaults
5. For records WITH override: show override values, status, trends
6. Load Deal_Signal\_\_c health scores (if available)
7. Load IncentiveImpactCalculator estimates (if Incentives module active)
8. Paginate: apply pagination to the merged result set
9. Compute ForecastSummaryDTO: sum by category for committed/best case/pipeline totals

---

### 2.2 CRUD Methods

#### `saveForecastData(List<ForecastOverrideSaveDTO> overrides, Id periodId, Id participantId, Boolean isPartial)`

**Called:** When user clicks "Save" in the forecast grid.

```java
@AuraEnabled
public static SaveResult saveForecastData(
    List<ForecastOverrideSaveDTO> overrides, Id periodId,
    Id participantId, Boolean isPartial) → SaveResult
```

**ForecastOverrideSaveDTO:**

| Field               | Type                   | Description                                                     |
| ------------------- | ---------------------- | --------------------------------------------------------------- |
| `recordId`          | Id                     | Pipeline record ID                                              |
| `overrideId`        | Id                     | Existing override ID (null = create new — lazy materialization) |
| `category`          | String                 | Selected forecast category                                      |
| `metricValues`      | Map\<String, Decimal\> | Metric 1-6 values                                               |
| `closeDateOverride` | Date                   | Overridden close date (null = use CRM date)                     |
| `comment`           | String                 | Inline comment                                                  |

**Logic:**

1. Validate period status (must be Open or Prelock — not Frozen/Closed)
2. For each DTO:
   a. If overrideId is null → create new Forecast_Override**c (lazy materialization)
   b. If overrideId exists → update existing
   c. Set Status**c = 'Saved'
   d. Set Saved_On\_\_c = now
   e. Compute exchange rate: freeze current rate (or live rate for draft per spec §12.6)
   f. Compute local currency values = corporate × exchange rate
3. Create Forecast_Change_Event\_\_c for each change (auto by trigger)
4. Update Forecast_Participant**c.Submission_Status**c = 'Saved' (or 'Partially Saved' if isPartial)
5. Return SaveResult with success/failure per record

---

#### `submitForecastData(List<ForecastOverrideSaveDTO> overrides, Id periodId, Id participantId, Boolean isPartial)`

**Called:** When user clicks "Submit" to flow numbers to next level.

```java
@AuraEnabled
public static SubmitResult submitForecastData(
    List<ForecastOverrideSaveDTO> overrides, Id periodId,
    Id participantId, Boolean isPartial) → SubmitResult
```

**Logic:**

1. Save first (same as saveForecastData)
2. Set Status\_\_c = 'Submitted' on all overrides
3. Set Submitted_On\_\_c = now
4. Freeze exchange rate on submit (per spec §12.6)
5. Update Forecast_Participant**c.Submission_Status**c = 'Submitted'
6. Create Forecast_Snapshot\_\_c with Snapshot_Type = 'Submit'
7. Send notification to next-level reviewer
8. Return SubmitResult

---

#### `freezeForecastData(Id periodId, String scopeId)`

**Called:** By top-level user to freeze the entire scope.

```java
@AuraEnabled
public static FreezeResult freezeForecastData(Id periodId, String scopeId) → FreezeResult
```

**Logic:**

1. Validate caller is the top-level participant for this scope
2. Set all Forecast_Override\_\_c for this period + scope to Frozen = true, Status = 'Frozen'
3. Update Forecast_Period\_\_c.Status = 'Frozen', Frozen_By = current user, Frozen_On = now
4. Update all Forecast_Participant\_\_c in scope to Submission_Status = 'Frozen'
5. Create Forecast_Snapshot\_\_c with Snapshot_Type = 'Freeze'
6. Auto-expire pending governance approvals (per spec §7.3.6)
7. Send notification to all participants in scope
8. Return FreezeResult

---

#### `copyFromPreviousLevel(Id periodId, Id participantId, String scopeId)`

**Called:** By Director+ users to copy values from the level below.

```java
@AuraEnabled
public static CopyResult copyFromPreviousLevel(
    Id periodId, Id participantId, String scopeId) → CopyResult
```

**Logic:**

1. Query all Forecast_Override**c where Previous_Level_Override**c is not null for this period + scope
2. For each: copy the Previous_Level values (category, metrics, close date) into this level's override
3. Handle deal-share deduplication at the top level (production-proven IP from Temenos)
4. Create/update overrides (lazy materialization)
5. Return count of copied records

---

#### `copyFromLastForecast(Id periodId, Id participantId, String scopeId)`

**Called:** To copy values from the previous forecast period.

```java
@AuraEnabled
public static CopyResult copyFromLastForecast(
    Id periodId, Id participantId, String scopeId) → CopyResult
```

**Logic:**

1. Find the previous Forecast_Period\_\_c (by date ordering)
2. Query Forecast_Override\_\_c from previous period for same participant + scope
3. Copy values into current period overrides (lazy materialization)
4. Return count of copied records

---

### 2.3 Comment Methods

#### `getLastForecastComment(Id recordId, Id userId)`

```java
@AuraEnabled(cacheable=true)
public static List<ForecastCommentDTO> getLastForecastComment(
    Id recordId, Id userId) → List<ForecastCommentDTO>
```

**Returns:** List of historical comments for this pipeline record, ordered by date descending. Includes: author, level, date, comment text, type.

---

#### `saveForecastComment(Id overrideId, Id periodId, Id recordId, String comment, String commentType)`

```java
@AuraEnabled
public static Id saveForecastComment(
    Id overrideId, Id periodId, Id recordId,
    String comment, String commentType) → Id
```

**Creates** a Forecast_Comment\_\_c record. Returns the new record ID.

---

### 2.4 Summary / Attainment Methods

#### `getForecastSummary(Id periodId, Id participantId, String scopeId)`

```java
@AuraEnabled(cacheable=true)
public static ForecastSummaryDTO getForecastSummary(
    Id periodId, Id participantId, String scopeId) → ForecastSummaryDTO
```

**Returns: ForecastSummaryDTO**

| Field              | Type                   | Description                                       |
| ------------------ | ---------------------- | ------------------------------------------------- |
| `target`           | Decimal                | From Quota\_\_c (if Incentives active)            |
| `achieved`         | Decimal                | From Quota\_\_c                                   |
| `remaining`        | Decimal                | Target - Achieved                                 |
| `attainmentPct`    | Decimal                | Achieved / Target × 100                           |
| `categoryTotals`   | Map\<String, Decimal\> | Sum of primary metric per category                |
| `categoryCounts`   | Map\<String, Integer\> | Count of records per category                     |
| `coverageRatio`    | Decimal                | Pipeline / Remaining                              |
| `currentTier`      | String                 | Rate tier name (if Incentives active)             |
| `currentRate`      | Decimal                | Current rate %                                    |
| `nextTierName`     | String                 | Next tier name                                    |
| `nextTierDistance` | Decimal                | Distance to next tier                             |
| `aiPredicted`      | Decimal                | AI-predicted total (if AI active)                 |
| `managerAccuracy`  | Decimal                | Manager accuracy score (if Behavior Intel active) |

**Logic:**

- For single-period layout: query from latest Forecast_Snapshot\_\_c or compute live
- For Period_And_YTD: query two snapshots (current period + YTD)
- For Expanded_Multi_Period: query monthly + quarterly + annual snapshots per spec §5.4

---

## 3. ForecastService.cls — Business Logic

### 3.1 Override Lifecycle

```
CREATE (lazy materialization):
  Pipeline record visible in grid → NO override row exists
  User edits any field → ForecastService.createOverride() → new Forecast_Override__c

SAVE:
  Override exists → ForecastService.saveOverrides() → Status = 'Saved'
  Change event auto-created by trigger

SUBMIT:
  ForecastService.submitOverrides() → Status = 'Submitted'
  Values flow to next level via Previous_Level_Override__c linkage
  Snapshot created

FREEZE:
  ForecastService.freezeScope() → Status = 'Frozen', period locked
  All pending governance events auto-expired
```

### 3.2 Deal-Share Deduplication (Temenos IP)

When an Opportunity appears in multiple territories (deal contribution/deal share), the top-level rollup must not double-count. Logic:

1. At the top hierarchy level, identify pipeline records that appear in multiple scopes
2. For each duplicate, use the deal contribution percentage (`TEM_Deal_Contribution_Per__c` in Temenos, configurable field in RevenueTrust)
3. Apply the percentage to the override values before summing for the scope rollup
4. Track the original vs. adjusted values for audit

---

## 4. ForecastDataService.cls — Query Abstraction

### 4.1 Pipeline Record Query (using PipelineObjectService)

```java
public static List<SObject> getPipelineRecordsForScope(
    Id participantId, String scopeId, Id periodId) → List<SObject>
```

**Logic:**

1. Determine scope type from Hierarchy_Source\_\_mdt (Ownership, Territory, Custom_Field)
2. If Ownership: find all users reporting to this participant → query pipeline records by OwnerId
3. If Territory: find territory assignments → query pipeline records by territory field
4. If Custom_Field: query pipeline records by the configured scope field
5. Apply Record Type filter from Forecast_Configuration\_\_c
6. Apply stage filter (exclude terminal stages unless they have overrides)
7. Use PipelineObjectService for dynamic field resolution

### 4.2 Override Query (LEFT JOIN pattern from spec §9.1)

```java
public static Map<Id, Forecast_Override__c> getOverridesForRecords(
    Set<Id> recordIds, Id periodId, Id participantId) → Map<Id, Forecast_Override__c>
```

Returns a map keyed by pipeline record ID. Records with no override are NOT in the map — the LWC shows CRM defaults for those.

### 4.3 Configuration Cache

```java
// Loaded once per request, cached for the transaction
public static ForecastConfigCache getConfig() → ForecastConfigCache
```

Loads: Forecast_Configuration**c, child Forecast_Metric**c (ordered), child Forecast_Category**c (ordered), Hierarchy_Source**mdt, Field_Mapping\_\_mdt for the pipeline object.

---

## 5. ForecastOverrideTriggerHandler.cls

**Trigger:** Before insert, before update, after insert, after update on Forecast_Override\_\_c.

### Before Save Logic:

1. **Governance rule evaluation:** Call GovernanceEngine.evaluate() for each override save (comp-aware rules CG-1 through CG-7)
2. **CRM divergence detection:** Compare override values to current CRM values; if CRM changed after submission, set CRM_Divergence = true
3. **Category regression warning:** If category moves to a regression-flagged category, log warning
4. **Validation:** Ensure period is not Frozen, participant has edit permission for this level

### After Save Logic:

1. **Create Forecast_Change_Event\_\_c:** One consolidated event per save (per spec §12.5 — multiple field changes in one save = one event)
2. **Update Forecast_Participant\_\_c status:** If any override changed, update Submission_Status

---

## 6. Batch Jobs

### 6.1 ForecastPeriodGeneratorBatch.cls (Schedulable)

**Purpose:** Auto-generates future Forecast_Period**c records based on the config's period type and Future_Periods_Visible**c setting.

**Schedule:** Monthly (or configurable)

**Logic:**

1. Load active Forecast_Configuration\_\_c
2. Count existing future periods (Status = 'Scheduled')
3. If count < Future_Periods_Visible → create new periods with auto-generated labels
4. Also advance past periods: if a period's End_Date has passed and Status = 'Open' → set to 'Closed'

### 6.2 ForecastInitializationBatch.cls (Database.Batchable)

**Purpose:** When a new Forecast_Period**c is created (or status changes to Open), initialize Forecast_Participant**c records and optionally pre-populate overrides.

**Ported from:** Temenos ForecastInitialization.cls

**Logic:**

1. Run hierarchy sync (create/update Forecast_Participant\_\_c for the new period)
2. For each participant + scope, query pipeline records in scope
3. Do NOT create Forecast_Override\_\_c records (lazy materialization — per spec §9.1)
4. Create Summary Participants (Is_Summary = true) for multi-scope users

### 6.3 ForecastSnapshotBatch.cls (Schedulable + Database.Batchable)

**Purpose:** Creates periodic Forecast_Snapshot\_\_c records for trend tracking.

**Schedule:** Nightly (default), hourly in final N days (configurable per spec §12.5)

**Logic:**

1. For each active participant + period:
2. Aggregate Forecast_Override\_\_c by category → compute totals
3. Load Quota\_\_c attainment for attainment snapshot
4. Compute coverage ratio
5. Create Forecast_Snapshot\_\_c with Snapshot_Type = 'Nightly' (or 'Weekly')
6. Compute deltas vs. previous snapshot of same type

---

## 7. DTO / Wrapper Classes

All DTOs are inner classes of ForecastController with `@AuraEnabled` fields for LWC serialization.

| Class                           | Purpose                                | Key Fields                                                                                                                              |
| ------------------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| ~~`ForecastContext`~~           | ~~Page initialization payload~~        | **SUPERSEDED by §11.1:** Split into `ForecastConfigDTO` (cacheable config) + `ForecastParticipantContextDTO` (imperative mutable state) |
| `ForecastConfigDTO`             | Stable config (cacheable)              | metrics, categories, hierarchy levels, period type, currency mode, layout, lock label/type, pagination                                  |
| `ForecastParticipantContextDTO` | Mutable participant state (imperative) | participant record, permissions, attainment, submission status, delegation, period state, budget mode                                   |
| ~~`ForecastConfigDTO`~~         | ~~Configuration summary~~              | **Duplicate — see updated entry above**                                                                                                 |
| `ForecastMetricDTO`             | Metric definition                      | label, type, format, isPrimary, isRequired, sortOrder                                                                                   |
| `ForecastCategoryDTO`           | Category definition                    | label, apiName, color, countsTowardTarget, isTerminal, isHighConfidence                                                                 |
| `ForecastPeriodDTO`             | Period info                            | id, label, type, startDate, endDate, status, isBudgetMode                                                                               |
| `ForecastParticipantDTO`        | Participant info                       | id, userId, level, levelLabel, scopeId, scopeName, status                                                                               |
| `ForecastRecordDTO`             | Single pipeline record                 | all fields from §2.1 getForecastRecords                                                                                                 |
| `ForecastRecordSet`             | Paginated record set                   | records, totalCount, pageNumber, pageSize, summary                                                                                      |
| `ForecastOverrideSaveDTO`       | Save payload per record                | recordId, overrideId, category, metricValues, closeDateOverride, comment                                                                |
| `ForecastSummaryDTO`            | Summary panel data                     | target, achieved, categoryTotals, coverage, tier info                                                                                   |
| `ForecastCommentDTO`            | Comment thread entry                   | author, level, date, comment, type                                                                                                      |
| `AttainmentDTO`                 | Incentive attainment                   | target, achieved, pct, currentTier, currentRate, nextTier, distance                                                                     |
| `ScopeDTO`                      | Territory/scope option                 | scopeId, scopeName, region, parentScope                                                                                                 |
| `SaveResult`                    | Save response                          | success, errors per record, updatedOverrideIds                                                                                          |
| `SubmitResult`                  | Submit response                        | success, snapshotId, notificationsSent                                                                                                  |
| `FreezeResult`                  | Freeze response                        | success, frozenCount, expiredGovernanceCount                                                                                            |
| `CopyResult`                    | Copy response                          | copiedCount, skippedCount                                                                                                               |

---

## 8. Cross-Module Integration Points

| Integration                        | Module              | How Controller Uses It                                  |
| ---------------------------------- | ------------------- | ------------------------------------------------------- |
| **PipelineObjectService**          | Incentives (shared) | Dynamic field resolution for pipeline records           |
| **IncentiveImpactCalculator**      | Incentives          | Real-time payout estimates for inline estimator columns |
| **Quota\_\_c attainment cache**    | Incentives          | Forecast_Participant\_\_c cached attainment fields      |
| **Deal_Signal\_\_c health scores** | Deal Health         | Health badge in forecast grid rows                      |
| **Governance_Event\_\_c**          | Cross-Module        | Governance flags displayed per record                   |
| **GovernanceEngine**               | Cross-Module        | Rule evaluation on override save (via trigger)          |
| **Forecast_Change_Event\_\_c**     | Forecasting         | Auto-created by trigger on override changes             |
| **Forecast_Snapshot\_\_c**         | Forecasting         | Created on submit/freeze + nightly batch                |

---

## 9. Decision Points

### DP-F1: Should getForecastRecords return pipeline records WITHOUT overrides?

**Yes (current design).** Per lazy materialization (spec §9.1), override rows don't exist until the user edits. The LWC needs to show ALL pipeline records in scope — those with overrides show override data, those without show CRM values as read-only defaults. The controller queries pipeline records via PipelineObjectService and LEFT JOINs to overrides.

### DP-F2: How does pagination work with lazy materialization?

Pipeline records are the primary pagination source (not overrides). The total count comes from the pipeline query, paginated at the config's pagination size. Overrides are loaded as a second query keyed by the pipeline record IDs in the current page.

### DP-F3: Should the Summary panel read from Snapshot or compute live?

**Hybrid:** For the first load, compute live from overrides + CRM data. Cache the result for the session. Use Forecast_Snapshot\_\_c for trend comparisons ("vs. last week", "vs. last submit").

### DP-F4: How does the Inline Estimator get plan data?

On page load, `getParticipantContext()` (§11.1) returns `attainment` in the ForecastParticipantContextDTO. This gives the LWC: current attainment, target, current tier, rate, and next tier info. The LWC's JavaScript calculates estimates client-side using this cached data (AD-8 from implementation sequence). No per-row server calls.

---

## 10. ~~Class Inventory~~ → SUPERSEDED BY §11.17

| Class                                | Type                    | Methods                    | Status   |
| ------------------------------------ | ----------------------- | -------------------------- | -------- |
| `ForecastController.cls`             | @AuraEnabled controller | 8 public methods           | To build |
| `ForecastService.cls`                | Business logic service  | ~15 methods                | To build |
| `ForecastDataService.cls`            | Query abstraction       | ~8 methods                 | To build |
| `ForecastOverrideTriggerHandler.cls` | Trigger handler         | before/after save          | To build |
| `ForecastPeriodGeneratorBatch.cls`   | Schedulable batch       | start/execute/finish       | To build |
| `ForecastInitializationBatch.cls`    | Database.Batchable      | start/execute/finish       | To build |
| `ForecastSnapshotBatch.cls`          | Schedulable batch       | start/execute/finish       | To build |
| `ForecastOverrideTrigger`            | Trigger                 | before/after insert/update | To build |
| **Total**                            |                         | **~40 methods**            |          |

---

---

## 11. V1.1 — FEEDBACK FIXES

### 11.1 Fix #1: Split getFilteredForecast into config + context

**Problem:** `getFilteredForecast(Id userId)` mixed stable config with mutable state and took an arbitrary userId (security risk).

**Fix:** Split into two methods:

```java
@AuraEnabled(cacheable=true)
public static ForecastConfigDTO getForecastConfig() → ForecastConfigDTO
```

Returns STABLE config: metrics, categories, hierarchy level labels, period type, currency mode, layout, pagination size, lock label. This is cacheable — config rarely changes.

```java
@AuraEnabled
public static ForecastParticipantContextDTO getParticipantContext(
    Id periodId, String scopeId) → ForecastParticipantContextDTO
```

Returns MUTABLE state for the CURRENT user (derived from `UserInfo.getUserId()`, NOT passed as parameter): participant record, permissions, attainment, submission status, delegation, current period state, budget mode. Imperative — not cached.

**For manager drill-in / delegated access:**

```java
@AuraEnabled
public static ForecastParticipantContextDTO getParticipantContextForUser(
    Id participantId, Id periodId, String scopeId) → ForecastParticipantContextDTO
```

Separate method with explicit security check: caller must be at hierarchy level N+1 or above, or be a configured delegate.

**Delegation mechanism:** Stored on `Forecast_Participant__c` (frozen object model §3.5 fields 17-19):

- `Delegate__c` (Lookup → User) — the delegated user
- `Delegate_Start__c` (Date) — delegation start date
- `Delegate_End__c` (Date) — delegation end date

Access check logic:

```
1. Is caller the participant themselves? → allow
2. Is caller at hierarchy level > participant's level
   AND in the same scope chain (Reports_To path)? → allow
3. Is caller listed as Delegate__c on the participant's record
   AND today is between Delegate_Start and Delegate_End? → allow
4. Does caller have Platform_Admin permission set? → allow
5. Otherwise → deny with AccessDeniedException
```

---

### 11.2 Fix #2: getForecastRecords — request DTO with filters

**Problem:** Method signature too thin — no filter/sort/search parameters.

**Fix:** Replace parameter list with ForecastQueryRequest DTO:

```java
@AuraEnabled
public static ForecastRecordSet getForecastRecords(
    ForecastQueryRequest request) → ForecastRecordSet
```

**ForecastQueryRequest:**

| Field                 | Type           | Description                                                                 |
| --------------------- | -------------- | --------------------------------------------------------------------------- |
| `periodId`            | Id             | Forecast period                                                             |
| `participantId`       | Id             | Current participant (or drilled-into participant)                           |
| `scopeId`             | String         | Territory/scope                                                             |
| `pageNumber`          | Integer        | Pagination                                                                  |
| `pageSize`            | Integer        | Override default from config                                                |
| `searchText`          | String         | Free-text search across record name, owner                                  |
| `categoryFilter`      | List\<String\> | Filter by forecast category (multi-select)                                  |
| `stageFilter`         | List\<String\> | Filter by CRM stage (multi-select)                                          |
| `healthBandFilter`    | List\<String\> | Filter by health score band (Green/Yellow/Red)                              |
| `pendingApprovalOnly` | Boolean        | Show only records with pending governance approval                          |
| `overriddenOnly`      | Boolean        | Show only records that have an override (hide untouched CRM records)        |
| `divergentOnly`       | Boolean        | Show only records where CRM diverged after submission                       |
| `sortField`           | String         | Field to sort by (metricValue, category, closeDate, ownerName, healthScore) |
| `sortDirection`       | String         | ASC or DESC                                                                 |

**Filtering strategy:**

| Scope Size                 | Strategy                                                | Rationale                                      |
| -------------------------- | ------------------------------------------------------- | ---------------------------------------------- |
| **≤ 500 pipeline records** | Load ALL records on first call, LWC filters client-side | Fast, no server round-trips for filter changes |
| **> 500 pipeline records** | Server-side filtering + pagination                      | Can't load all into LWC memory                 |

The first call includes `totalUnfilteredCount` in the response so the LWC knows which strategy to use.

---

### 11.3 Fix #3: Save must set Previous_Level_Override and Previous_Period_Override

**Updated save logic (replaces §2.2 step 2):**

```
For each ForecastOverrideSaveDTO where overrideId is null (new override — lazy materialization):
  a. Create new Forecast_Override__c
  b. Set Status__c = 'Saved', Saved_On__c = now
  c. Set Hierarchy_Level__c from participant
  d. Set Forecast_Period__c, Opportunity__c (or pipeline record), User__c, Forecast_Participant__c
  e. RESOLVE Previous_Level_Override__c:
     → Query: SELECT Id FROM Forecast_Override__c
       WHERE Opportunity__c = :recordId
       AND Forecast_Period__c = :periodId
       AND Hierarchy_Level__c = :currentLevel - 1
       AND Status__c IN ('Submitted', 'Frozen')
       LIMIT 1
     → If found: set Previous_Level_Override__c = that record's Id
  f. RESOLVE Previous_Period_Override__c:
     → Find previous Forecast_Period__c (by End_Date < current period's Start_Date, ORDER BY End_Date DESC)
     → Query: SELECT Id FROM Forecast_Override__c
       WHERE Opportunity__c = :recordId
       AND Forecast_Period__c = :previousPeriodId
       AND User__c = :currentUserId
       LIMIT 1
     → If found: set Previous_Period_Override__c = that record's Id
  g. Compute exchange rate (live for draft, freeze on submit per §12.6)
  h. Compute local currency values
```

---

### 11.4 Fix #4: Freeze downstream side-effects documented

**Added note to freezeForecastData:**

> **Downstream commission side-effect:** When this method updates `Forecast_Period__c.Status__c = 'Frozen'`, the `ForecastPeriodTrigger` fires → publishes `PERIOD_FROZEN` event → `PeriodFreezeHandler` reclassifies unresolved commission alerts whose calculations fall in the frozen period. This is intentional and documented in Commission Event Routing V2.6 §11.4 event #41. Implementers should be aware that freezing a forecast period has commission implications.

---

### 11.5 Fix #5: Deal-share deduplication — explicit config

**Deal contribution percentage field mapping:**

Add to `Field_Mapping__mdt`:

- Logical name: `Pipeline.DealContributionPct`
- Default Salesforce field: none (org-specific)
- Purpose: Percentage of deal value attributed to this territory/scope when a deal appears in multiple scopes

**Deduplication rules (explicit):**

1. Deduplication applies ONLY at the top hierarchy level (level N). Intermediate levels see full deal values.
2. At level N, query all pipeline records that appear in multiple scopes (have overrides in multiple Forecast_Participant\_\_c scopes)
3. For each duplicate: multiply metric values by `Pipeline.DealContributionPct` before summing in the rollup
4. If `Pipeline.DealContributionPct` is not mapped or is null on the record, default to equal split (100% / number of scopes the record appears in)
5. Track original vs. adjusted values: the ForecastRecordDTO includes both `metricValues` (adjusted) and `metricValuesPreDedup` (original) so the UI can show "Value: $500K (adjusted from $1M — 50% contribution)"

---

### 11.6 Fix #6: Governance engine null-safe check

**Updated ForecastOverrideTriggerHandler before-save:**

```java
// Governance evaluation — null-safe for stub phase
if (TriggerControlService.isEnabled('GovernanceEvaluation')) {
    try {
        GovernanceEventHandler handler = new GovernanceEventHandler();
        // Only evaluate if governance engine is fully implemented
        // (check if the handler has real logic, not just a stub)
        // For now: publish governance evaluation event, let async handler decide
        // Do NOT block save on governance evaluation in before-save context
    } catch (Exception e) {
        System.debug(LoggingLevel.WARN, 'Governance evaluation skipped: ' + e.getMessage());
    }
}
```

**Key rule:** Governance evaluation publishes an async event (Governance_Eval_Event**e) — it does NOT block the save synchronously. The governance queue shows pending reviews, but the save completes. Only CG-3 (Require Approval) blocks by setting `Pending_Approval**c = true`, which excludes the record from rollups but doesn't prevent the DML.

---

### 11.7 Fix #7: Snapshot creation in Service, not Controller

**Moved from submitForecastData controller method to ForecastService.submitOverrides():**

All business logic steps (save overrides → set status → freeze exchange rate → create snapshot → send notification → update participant status) are in ForecastService. The controller method is now:

```java
@AuraEnabled
public static SubmitResult submitForecastData(SubmitForecastRequest request) → SubmitResult {
    return ForecastService.submitOverrides(
        request.overrides, request.periodId, request.participantId, request.isPartial);
}
```

---

### 11.8 Fix #8: reopenPeriod noted as future

**Added to §2.2:**

> **Intentionally omitted from V1:** `reopenPeriod(Id periodId)` — the ability to unfreeze a frozen period. This is a rare admin action. When implemented, it will update `Forecast_Period__c.Status__c = 'Open'`, which triggers the `ForecastPeriodTrigger` → publishes `PERIOD_REOPENED` event (Commission Event Routing event #43). This method will require Platform_Admin permission and create a Forecast_Change_Event\_\_c with type `Unfreeze`. **Not in V1 controller scope.**

---

### 11.9 Fix #9: Snapshot batch hourly mode mechanism

**Updated §6.3 ForecastSnapshotBatch:**

**Scheduling mechanism for hourly mode:**

Two scheduled jobs, not one:

| Job                             | Schedule                                                         | Purpose                                     |
| ------------------------------- | ---------------------------------------------------------------- | ------------------------------------------- |
| `ForecastSnapshotBatch_Nightly` | Nightly at 2 AM (configurable)                                   | Standard nightly snapshot                   |
| `ForecastSnapshotBatch_Hourly`  | Every 4 hours during business hours, active only in final N days | Increased frequency for period-end accuracy |

**Hourly mode activation:**

- The nightly job checks: `days until period end ≤ Hourly_Snapshot_Days__c`
- If true AND no hourly job is currently scheduled: `System.schedule()` the hourly job with a CRON for every `Hourly_Snapshot_Interval__c` hours
- The hourly job checks the same condition on each run. When the period freezes or days remaining > threshold: the hourly job does NOT reschedule itself (self-terminating)

---

### 11.10 Fix #10: Exchange rate refresh job

**Added to §6 Batch Jobs:**

### 6.4 Exchange Rate Refresh (service method invoked by ForecastSnapshotBatch)

**Purpose:** Refreshes `Exchange_Rate__c` on all non-submitted Forecast_Override\_\_c records to prevent stale rates.

**NOT a separate batch class.** This is a service method `ForecastService.refreshDraftExchangeRates()` called as the final step of the nightly `ForecastSnapshotBatch.finish()` method. No standalone class needed.

**Logic:**

1. Query all Forecast_Override**c where Status**c IN ('New', 'Saved') AND Currency != corporate currency
2. For each: get current exchange rate (from DatedConversionRate or CurrencyType)
3. Update Exchange_Rate\_\_c and recompute local currency values
4. Skip Submitted/Frozen overrides (rates are frozen at submit per spec §12.6)

---

### 11.11 Fix: Save vs Submit request separation

**New request DTOs (replacing shared ForecastOverrideSaveDTO for both):**

```java
public class SaveForecastRequest {
    public List<ForecastOverrideSaveDTO> overrides;
    public Id periodId;
    public Id participantId;
    public Boolean isPartial;
}

public class SubmitForecastRequest {
    public List<ForecastOverrideSaveDTO> overrides;
    public Id periodId;
    public Id participantId;
    public Boolean isPartial;
    // Submit-specific:
    public Boolean validateCompleteness; // Ensure all in-scope records have overrides
    public Boolean freezeExchangeRates;  // Explicit intent to freeze rates (default true)
}
```

---

### 11.12 Fix: Trigger handler — thin delegation to services

**Updated §5 ForecastOverrideTriggerHandler — thin pattern:**

| Trigger Phase | Handler Method                    | Delegates To                                               |
| ------------- | --------------------------------- | ---------------------------------------------------------- |
| Before Insert | `beforeInsertValidate()`          | `ForecastValidationService.validateOverrides()`            |
| Before Update | `beforeUpdateValidate()`          | `ForecastValidationService.validateOverrides()`            |
| Before Update | `beforeUpdateDetectDivergence()`  | `ForecastDivergenceService.detectDivergence()`             |
| After Insert  | `afterInsertPublishChangeEvent()` | `ForecastChangeEventService.createEvents()`                |
| After Update  | `afterUpdatePublishChangeEvent()` | `ForecastChangeEventService.createEvents()`                |
| After Update  | `afterUpdateParticipantStatus()`  | `ForecastParticipantStatusService.updateStatus()`          |
| After Update  | `afterUpdateGovernanceEval()`     | Publishes `Governance_Eval_Event__e` (async, non-blocking) |

**New service classes (added to inventory):**

- `ForecastValidationService.cls` — validates period status, participant permissions, category validity
- `ForecastDivergenceService.cls` — detects CRM changes after submission
- `ForecastChangeEventService.cls` — creates consolidated Forecast_Change_Event\_\_c
- `ForecastParticipantStatusService.cls` — updates Forecast_Participant**c.Submission_Status**c

---

### 11.13 Fix: Top-level action — separate type from label

**Updated ForecastConfigDTO:**

| Field                 | Type   | Description                                                           |
| --------------------- | ------ | --------------------------------------------------------------------- |
| `topLevelActionType`  | String | Canonical action: FREEZE, APPROVE, LOCK                               |
| `topLevelActionLabel` | String | Display label (configurable): "Freeze", "Lock", "Approve", "Finalize" |

The controller uses `topLevelActionType` for logic routing. The LWC uses `topLevelActionLabel` for the button text.

---

### 11.14 Fix: Companion spec version corrected

Header updated: `INCENTIVES_OBJECT_MODEL.md V1.7 (implementation through V2.0)`

---

### 11.15 Fix: Copy conflict policy

**Added to copyFromPreviousLevel and copyFromLastForecast:**

**Copy mode** parameter (default: `SKIP_EDITED`):

| Mode          | Behavior                                                                  |
| ------------- | ------------------------------------------------------------------------- |
| `OVERWRITE`   | Replace ALL current overrides with copied values                          |
| `MERGE`       | Copy only for records that have NO current override (skip existing)       |
| `SKIP_EDITED` | Copy for records where Status = 'New'. Skip 'Saved'/'Submitted'/'Frozen'. |

**Updated method signatures:**

```java
@AuraEnabled
public static CopyResult copyFromPreviousLevel(
    Id periodId, Id participantId, String scopeId, String copyMode) → CopyResult

@AuraEnabled
public static CopyResult copyFromLastForecast(
    Id periodId, Id participantId, String scopeId, String copyMode) → CopyResult
```

CopyResult includes: `copiedCount`, `skippedCount`, `skippedEditedCount` (so user knows what was skipped and why).

---

### 11.16 Fix: Summary data source table

| Summary Field     | Source of Truth                                                  | Refresh Timing                                                                     | Consistency                               |
| ----------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------- |
| `target`          | Quota**c.Adjusted_Target**c                                      | Cached on Forecast_Participant\_\_c, refreshed on Quota change (PE) or hourly lazy | Eventually consistent (< 1 hour)          |
| `achieved`        | Quota**c.Achieved_Amount**c                                      | Same as target                                                                     | Eventually consistent                     |
| `attainmentPct`   | Computed: achieved / target                                      | On demand                                                                          | Derived — always fresh from cached source |
| `categoryTotals`  | Live from Forecast_Override\_\_c aggregation                     | On each page load                                                                  | Live — always current                     |
| `categoryCounts`  | Live from Forecast_Override\_\_c + pipeline query                | On each page load                                                                  | Live                                      |
| `coverageRatio`   | Computed: pipeline / remaining                                   | On demand                                                                          | Derived                                   |
| `currentTier`     | Commission_Tier\_\_c via Quota attainment                        | Cached, refreshed on attainment change                                             | Eventually consistent                     |
| `aiPredicted`     | Forecast_Override**c.Close_Probability**c × metric value, summed | Nightly batch refresh                                                              | Eventually consistent (up to 24h)         |
| `managerAccuracy` | Forecast_Accuracy**c.Accuracy_Score**c                           | Weekly batch refresh                                                               | Eventually consistent (up to 7 days)      |

---

### 11.17 Updated Class Inventory — V1.1

| Class                                  | Type                       | Methods                            | Status          |
| -------------------------------------- | -------------------------- | ---------------------------------- | --------------- |
| `ForecastController.cls`               | @AuraEnabled controller    | 10 public methods                  | To build        |
| `ForecastService.cls`                  | Business logic service     | ~15 methods                        | To build        |
| `ForecastDataService.cls`              | Query abstraction          | ~8 methods                         | To build        |
| `ForecastValidationService.cls`        | Override validation        | ~4 methods                         | To build        |
| `ForecastDivergenceService.cls`        | CRM divergence detection   | ~3 methods                         | To build        |
| `ForecastChangeEventService.cls`       | Change event creation      | ~3 methods                         | To build        |
| `ForecastParticipantStatusService.cls` | Participant status updates | ~3 methods                         | To build        |
| `ForecastOverrideTriggerHandler.cls`   | Thin trigger handler       | 6 handler methods                  | To build        |
| `ForecastOverrideTrigger`              | Trigger                    | before/after insert/update         | To build        |
| `ForecastPeriodGeneratorBatch.cls`     | Schedulable batch          | 3 methods                          | To build        |
| `ForecastInitializationBatch.cls`      | Database.Batchable         | 3 methods                          | To build        |
| `ForecastSnapshotBatch.cls`            | Schedulable batch          | 3 methods + hourly self-scheduling | To build        |
| **Total**                              |                            | **~11 classes + 1 trigger**        | **~60 methods** |

> Exchange rate refresh is a service method on `ForecastService.refreshDraftExchangeRates()`, called from `ForecastSnapshotBatch.finish()` — not a separate class.

---

_Forecasting Apex Controllers Spec V1.1_  
_10 @AuraEnabled methods. 11 classes + 1 trigger. ~60 methods total._  
_Split init into config (cacheable) + context (imperative). Request DTO with filters/sort/search._  
_Previous_Level/Period override linkage on lazy materialization. Copy conflict policies._  
_Thin trigger → delegated services. Summary data source table. Hourly snapshot self-scheduling._  
_§2 method signatures superseded by §11 — use §11 versions for implementation._
