# Phase D: Forecast Cadence, Summaries & Field Customization (v3 — Final)

## Context

After Phases A–C shipped the onboarding wizard, admin console parity, multi-source metrics, and forecast groups, UAT feedback identified three remaining capability gaps:

1. **Forecast Cadence** — replace technical snapshot fields with a business-friendly cadence model
2. **Forecast Summaries** — per-category rollup records that can be overridden, with normalized history for trend visualization
3. **Field Mappings Customization** — admins choose which fields appear in the forecast grid (main view vs expanded detail)

This spec is the addendum to the V2 plan. v2 incorporates all 12 review feedback items + 4 minor observations.

### Changes to Frozen Spec §12.9

Forecast_Configuration\_\_c field count: **24 → 29** (3 cadence fields + 1 anchor date + 1 summary metrics flag). This supersedes the §12.9 line.

---

## 1. Forecast Cadence & Submission Deadlines

### CRM Data Freshness Model

**Critical architecture principle**: CRM data must be **live** when the user loads the forecast grid.

- **Before submission**: `ForecastService.queryForecastRecords()` always queries live Opportunity data. The grid shows current CRM values merged with user overrides.
- **After submission**: The submitted values are **frozen**. CRM refresh stops for that user+period. The `Forecast_Override__c.Status__c = 'Submitted'` flag is the gate.
- **Override precedence**: User overrides always win over CRM values. CRM values are the baseline.

No change needed to the query layer — already live via `ForecastDataService.getPipelineRecordsForScope()`.

### New Configuration Fields

| Field                        | Type     | Purpose                                                                                                                                          |
| ---------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Forecast_Cadence__c`        | Picklist | `Weekly` / `Bi_Weekly` / `Monthly` / `Quarterly`                                                                                                 |
| `Submission_Deadline_Day__c` | Text(20) | Day literal or number — see format table below                                                                                                   |
| `Auto_Freeze_On_Deadline__c` | Checkbox | If true, auto-freeze unsubmitted forecasts when deadline passes                                                                                  |
| `Cadence_Anchor_Date__c`     | Date     | Bi-weekly anchor: first cadence cycle starts on the first matching deadline day on or after this date. Set to config activation date by default. |

**Deprecate** (keep field, hide from UI): `Hourly_Snapshot_Days__c`, `Hourly_Snapshot_Interval__c`

### Submission Deadline Day — Format by Cadence

| Cadence   | Deadline Format             | Examples              | Validation Rule                                                                                         |
| --------- | --------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------- |
| Weekly    | Day-of-week literal         | `Fri`, `Thu`, `Sun`   | Must be one of: `Mon,Tue,Wed,Thu,Fri,Sat,Sun`                                                           |
| Bi-Weekly | Day-of-week literal         | `Fri`                 | Same as Weekly                                                                                          |
| Monthly   | Day-of-month                | `5`, `10`, `28`, `31` | Must be numeric 1–31. If month has fewer days, uses last day of month.                                  |
| Quarterly | Nth calendar day of quarter | `10`, `15`            | Must be numeric 1–90. Label: "Nth calendar day of quarter" (e.g., 10 = Jan 10, Apr 10, Jul 10, Oct 10). |

> **Review feedback #1 addressed**: Quarterly uses explicit "Nth calendar day of quarter" semantics with clear labeling, not an ambiguous "offset."

#### Day-of-Week Literals

Full set (supports Gulf/international work weeks):

```
Mon, Tue, Wed, Thu, Fri, Sat, Sun
```

Picker shows full names ("Monday", "Saturday", etc.) with values stored as 3-letter codes.

#### Bi-Weekly Anchor (Review feedback #2)

The `Cadence_Anchor_Date__c` field defines **when bi-weekly cycles start**. The deterministic rule:

> First cadence cycle starts on the first matching deadline day on or after `Cadence_Anchor_Date__c`. Subsequent cycles are every 14 days.

Example: If anchor = 2026-04-16 (Thursday) and deadline = `Fri`, the first cycle deadline is 2026-04-17 (Friday). The next is 2026-05-01 (14 days later).

For non-bi-weekly cadences, this field is informational only (ignored by the batch).

#### Server-Side Validation (Review feedback #5 — Submission_Deadline_Day\_\_c)

An Apex before-save trigger on `Forecast_Configuration__c` enforces format constraints:

```apex
// Validation pseudocode
if cadence IN ('Weekly', 'Bi_Weekly'):
    assert deadline IN ('Mon','Tue','Wed','Thu','Fri','Sat','Sun')
if cadence == 'Monthly':
    assert deadline is numeric AND 1 <= value <= 31
if cadence == 'Quarterly':
    assert deadline is numeric AND 1 <= value <= 90
```

### Auto-Freeze Policy (Review feedback #3)

When `Auto_Freeze_On_Deadline__c = true`:

| Aspect                | Policy                                                                                                                                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Timestamp**         | 23:59:59 in the **org default timezone** on the deadline day. Determined via `[SELECT TimeZoneSidKey FROM Organization].TimeZoneSidKey`.                                                                                 |
| **Scope**             | Each participant-period is frozen independently. A manager's submission status doesn't affect subordinates.                                                                                                              |
| **In-progress edits** | Unsaved changes are **not persisted** — the freeze applies to the last saved state. A warning banner appears 24 hours before deadline: "Forecast due tomorrow — unsaved changes will not be included if you don't save." |
| **Partial edits**     | Participants who saved but didn't submit get their saved overrides frozen with `Status__c = 'Frozen'` (not 'Submitted').                                                                                                 |
| **Already submitted** | No action — already frozen.                                                                                                                                                                                              |

### Cross-Month Week Handling

When a period ends mid-week, the period picker shows both the current and upcoming period during the final week:

```
Period picker:
  Apr 2026 (Open — closes Wed Apr 30) ← current, editable, submittable
  May 2026 (Scheduled — starts Thu May 1) ← visible, editable as DRAFT only
```

**Final week** defined as: `periodEndDate - 6 days`.

#### Early Submission Policy (Review feedback #11)

> The upcoming period is visible and editable during the final week, but **submission is disabled until the period's official start date** unless the config explicitly allows early submission.

New field: **not added** — this is enforced by the existing period `Status__c`. The upcoming period stays `Scheduled` until its start date, when the `ForecastPeriodGeneratorBatch` transitions it to `Open`. The submit button checks `period.Status__c == 'Open'`.

Users can edit and save drafts for the upcoming period, but cannot submit until it becomes `Open`.

#### Weekly Cadence — Final Week Suppression (Minor observation)

For Weekly cadence, the entire period IS the final week (7 days). The cross-month overlap behavior is **suppressed for Weekly cadence** since there's no meaningful "upcoming period" concept — the next period is always immediately adjacent.

### Cadence Snapshot Generation

**New class: `ForecastCadenceSnapshotBatch`** (separate from `ForecastPeriodGeneratorBatch` — different responsibility per minor observation).

Runs on a **daily schedule**. On each run:

1. Load active config with cadence settings
2. Determine if today is a cadence cycle day:
   - Weekly: is today the deadline day-of-week?
   - Bi-Weekly: is today the deadline day-of-week AND is it an even-numbered week from anchor?
   - Monthly: is today the deadline day-of-month (or last day if month < deadline)?
   - Quarterly: is today the Nth calendar day of the current quarter?
3. If yes: create `Forecast_Snapshot__c` with `Snapshot_Type__c = 'Cadence'` + create/update `Forecast_Summary__c` records + append to `Forecast_Summary_History__c`
4. If no: exit

#### Idempotency (Review feedback #12)

**Snapshot unique key**: `(Forecast_Participant__c, Forecast_Period__c, Snapshot_Date__c, Snapshot_Type__c)` on `Forecast_Snapshot__c`.

If a record with this key already exists, skip (don't duplicate). This handles:

- Batch re-runs after failure
- Timezone edge cases where the batch triggers twice
- Config changes mid-period

**Backfill behavior**: If the batch missed a day (failure, late deployment), it does NOT backfill historical snapshots. The next successful run creates a snapshot for today only. Backfill is a manual admin action (future: admin button "Generate missing snapshots").

**Nightly batch coexistence**: The frozen spec defines a `Nightly` snapshot type. For orgs with `Forecast_Cadence__c` set, the nightly batch is **suppressed** — the cadence batch subsumes its purpose (capturing pipeline state at defined intervals). This reduces snapshot storage volume. The nightly batch only runs for orgs without a cadence configured (backward compat).

#### Snapshot_Type\_\_c Picklist Update (Review feedback — Issue 2)

Add `Cadence` to the existing `Snapshot_Type__c` picklist values. The existing `Weekly` value is **retained for backward compatibility** but superseded by `Cadence` for orgs using the new cadence model.

Migration: Existing orgs with `Weekly` snapshots keep them. New cadence-driven snapshots use `Cadence`. The trend UI queries both types: `WHERE Snapshot_Type__c IN ('Cadence', 'Weekly', 'Submit')`.

### Onboarding Wizard Integration

Integrated into **Step 7** (Period Configuration), not a separate step:

```
──── Forecast Cadence ────

How often does your team forecast?
  ○ Weekly — submit every week
  ○ Bi-weekly — submit every two weeks
  ○ Monthly — submit once per month
  ○ Quarterly — submit once per quarter

When is the forecast due?
  Weekly/Bi-Weekly: [Monday ▾] [Tuesday ▾] ... [Sunday ▾]
  Monthly: [Day picker 1-31]
  Quarterly: [Day picker 1-90] — "Nth calendar day of quarter"

☐ Auto-freeze forecasts that aren't submitted by the deadline
```

### Admin Console Integration

General Settings tab — new "Forecast Cadence" section replaces Hourly Snapshot fields:

- **Forecast Cadence** combobox
- **Submission Deadline** — conditional picker (day-of-week literals for weekly/bi-weekly, number for monthly/quarterly)
- **Auto-Freeze on Deadline** checkbox
- **Cadence Anchor Date** — date input (only shown for Bi-Weekly)

---

## 2. Forecast Summaries (Per-Category Rollups with Override + Trend)

### Architecture: Two Objects, Not One (Review feedback #4)

The original spec stored trend history as JSON in `Snapshot_History__c` on `Forecast_Summary__c`. This is too denormalized for analytics, reporting, and audit.

**Revised design:**

| Object                        | Purpose                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `Forecast_Summary__c`         | Current/latest effective summary per (participant × period × category × group × metric). Always reflects the most recent state. |
| `Forecast_Summary_History__c` | Append-only child records for each cadence/submit/freeze event. One record per snapshot point.                                  |

This gives:

- Clean SOQL reporting on history (`SELECT ... FROM Forecast_Summary_History__c WHERE ...`)
- No JSON parsing for sparklines
- Proper audit trail
- No text field growth/pruning logic
- Better governor limit behavior (query child records vs deserialize JSON)

### New Object: `Forecast_Summary__c`

| Field                     | Type               | Purpose                                                                                              |
| ------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------- |
| `Forecast_Period__c`      | Lookup             | Which period                                                                                         |
| `Forecast_Participant__c` | Lookup             | Whose forecast                                                                                       |
| `Forecast_Group__c`       | Lookup             | Which group (null = config-wide)                                                                     |
| `Category_API_Name__c`    | Text(50)           | Which category                                                                                       |
| `Metric_Sort_Order__c`    | Number             | Which metric (1 = primary)                                                                           |
| `Computed_Value__c`       | Currency           | Auto-calculated sum from pipeline                                                                    |
| `Override_Value__c`       | Currency           | Manager-entered override (null = use computed). Note: `0` is a valid override (manager believes $0). |
| `Effective_Value__c`      | Formula(Currency)  | `IF(Override_Value__c != null, Override_Value__c, Computed_Value__c)`                                |
| `Override_Notes__c`       | LongTextArea(2000) | Why the override was made                                                                            |
| `Override_By__c`          | Lookup(User)       | Who overrode it                                                                                      |
| `Override_Date__c`        | DateTime           | When override was last changed                                                                       |
| `Deal_Count__c`           | Number             | Number of deals in this category                                                                     |
| `Summary_Date__c`         | Date               | Date this summary was last computed/updated                                                          |
| `Is_Submitted__c`         | Checkbox           | Whether this summary has been submitted                                                              |

**No** `Snapshot_History__c` JSON field — history lives in child records.

### New Object: `Forecast_Summary_History__c`

| Field                 | Type          | Purpose                                    |
| --------------------- | ------------- | ------------------------------------------ |
| `Forecast_Summary__c` | Master-Detail | Parent summary                             |
| `Snapshot_Date__c`    | Date          | When this snapshot was taken               |
| `Snapshot_Type__c`    | Picklist      | `Cadence` / `Submit` / `Freeze` / `Manual` |
| `Computed_Value__c`   | Currency      | Pipeline-computed total at this point      |
| `Effective_Value__c`  | Currency      | Value including any override at this point |
| `Deal_Count__c`       | Number        | Deal count at this point                   |
| `Override_Active__c`  | Checkbox      | Whether an override was in effect          |
| `Notes__c`            | Text(500)     | Snapshot-time note (optional)              |

**Summary history unique key** (enforced via before-insert trigger — Salesforce duplicate rules don't support MD + Date + Picklist composite matching natively): `(Forecast_Summary__c, Snapshot_Date__c, Snapshot_Type__c)` — prevents duplicate history entries.

### Data Flow: Snapshot vs Summary (Review feedback — Issue 3)

```
ForecastCadenceSnapshotBatch runs on cadence day:
  │
  ├─► Creates/updates Forecast_Summary__c (current state)
  │     • Computed_Value__c = live pipeline rollup
  │     • Override_Value__c = preserved from previous
  │     • Effective_Value__c = formula resolves
  │
  ├─► Creates Forecast_Summary_History__c (append-only)
  │     • Type = 'Cadence'
  │     • Captures computed + effective at this point
  │
  └─► Creates Forecast_Snapshot__c (whole-forecast snapshot)
        • Type = 'Cadence'
        • Captures aggregate totals across ALL categories
        • Category totals on snapshot reflect PIPELINE-COMPUTED values
        • Summary overrides are NOT reflected in Forecast_Snapshot__c
        •   (Snapshot = "what did the pipeline say?")
        •   (Summary = "what did the manager call?")

User submits forecast:
  │
  ├─► Updates Forecast_Summary__c.Is_Submitted__c = true
  ├─► Creates Forecast_Summary_History__c (Type = 'Submit')
  └─► Creates Forecast_Snapshot__c (Type = 'Submit')
        • Snapshot category totals = EFFECTIVE values (including overrides)
        •   (On submit, snapshot reflects the manager's final call)
```

**Which object does the UI read?**

| UI Element                      | Data Source (Post-Phase D)                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| Category cards (live view)      | Computed on-the-fly from live pipeline + `Forecast_Summary__c.Override_Value__c` |
| Category cards (submitted view) | `Forecast_Summary__c` (frozen effective values)                                  |
| Trend sparkline                 | `Forecast_Summary_History__c` ordered by `Snapshot_Date__c`                      |
| Summary Panel (historical)      | `Forecast_Snapshot__c` (whole-forecast aggregates)                               |

### Summary Override Permissions (Review feedback #5)

| Who                                  | Can Override?                          | Scope                        |
| ------------------------------------ | -------------------------------------- | ---------------------------- |
| **Forecast Admin** (perm set)        | Yes                                    | Any participant's summary    |
| **Direct manager** (Reports_To\_\_c) | Yes                                    | Subordinates' summaries only |
| **Delegated approver**               | Yes, during delegation window          | Delegator's subordinates     |
| **Participant (self)**               | **No** — edit individual deals instead | N/A                          |
| **Parent manager** (skip-level)      | Yes                                    | All subordinates recursively |

**Conflict resolution**: Last write wins. Each override records `Override_By__c` and `Override_Date__c` for audit. If a parent manager and a direct manager both override, the most recent `Override_Date__c` is the effective value.

**Audit hint (v1 scope)**: When a user views a summary that was overridden by someone else, the UI shows: "Adjusted by [Override_By name] on [Override_Date]". This leverages the existing stored fields — no additional data model needed.

### Override Precedence Matrix (Review feedback #6)

```
LAYER 1: CRM (live Opportunity data)
  ↓ overridden by
LAYER 2: Deal-level overrides (Forecast_Override__c per opportunity)
  ↓ rolled up into
LAYER 3: Summary computed value (sum of Layer 2 effective values per category)
  ↓ overridden by
LAYER 4: Summary override (Forecast_Summary__c.Override_Value__c)
```

**Staleness rule**: When ANY deal in a category changes (Layer 1 or Layer 2) after a summary override was set (Layer 4), the summary is marked **stale**:

- `Computed_Value__c` is re-computed on next grid load
- If `Computed_Value__c` diverges from the value at the time of override, a visual indicator appears: "Pipeline changed since manager adjustment — computed: $X, override: $Y"
- The override is NOT auto-cleared — the manager must explicitly clear or update it

**Submission precedence**: On submit, the `Effective_Value__c` (which includes the override) is what gets frozen. The snapshot captures this final state.

### Summary Volume Guardrails (Review feedback #7)

Dimensions: participant × period × category × group × metric.

| Dimension                      | Typical Max | Notes                                        |
| ------------------------------ | ----------- | -------------------------------------------- |
| Participants                   | 200         | Per period                                   |
| Categories                     | 7           | Enterprise template max                      |
| Groups                         | 5           | Practical limit                              |
| Metrics                        | 6           | Configured max                               |
| **Total summaries per period** | **42,000**  | Worst case. Typical: 200 × 5 × 1 × 1 = 1,000 |

**Guardrails:**

- `Forecast_Group__c = null` (config-wide) summary is **always stored** for the primary metric. This is the canonical "what's your Commit?" number.
- Per-group summaries are **only persisted when group mode is enabled** (config has 2+ active groups).
- Non-primary metric summaries are **only persisted for the primary metric by default**. A config flag `Summary_All_Metrics__c` (Checkbox, default false) enables summaries for secondary metrics.
- Max groups warning: if a config has >10 active groups, the admin UI shows: "Many groups may slow summary computation. Consider consolidating."
- History records: universal cap of **52 `Forecast_Summary_History__c` records per summary**. Oldest pruned by batch. Effective time coverage varies by cadence: Weekly ≈ 1 year, Bi-Weekly ≈ 2 years, Monthly ≈ 4 years, Quarterly ≈ 13 years. The cap is constant; coverage is a consequence of frequency.

---

## 3. Field Mappings Customization

### Concept: Display Field Configuration

Display fields are scoped to the **configuration**, not per-group (Review feedback — Issue 6). This is a known limitation for v1. Per-group field customization is a future enhancement — noted explicitly here.

> **Known limitation**: Display fields apply to all groups within a configuration. Different groups cannot have different grid columns in Phase D.

### New Object: `Forecast_Display_Field__c`

| Field                       | Type      | Purpose                                             |
| --------------------------- | --------- | --------------------------------------------------- |
| `Forecast_Configuration__c` | Lookup    | Parent config                                       |
| `Name`                      | Standard  | Display label                                       |
| `Field_Label__c`            | Text(100) | Column header in the grid                           |
| `Object_API_Name__c`        | Text(100) | Source object                                       |
| `Field_API_Name__c`         | Text(100) | Field API name                                      |
| `Field_Type__c`             | Text(50)  | Detected type for formatting                        |
| `Display_Location__c`       | Picklist  | `Main_Grid` / `Expanded_Detail` / `Both`            |
| `Sort_Order__c`             | Number    | Column position                                     |
| `Column_Width__c`           | Picklist  | `Narrow` (80px) / `Medium` (120px) / `Wide` (200px) |
| `Is_Active__c`              | Checkbox  | Show/hide without deleting                          |
| `Is_System__c`              | Checkbox  | True for default 4 fields — non-deletable           |

### Field Eligibility Rules (Review feedback #9)

Not every field type makes sense in a forecast grid. Eligibility:

| Field Type                   | Allowed?         | Location Restriction  |
| ---------------------------- | ---------------- | --------------------- |
| Currency, Number, Percent    | Yes              | Main Grid or Expanded |
| Text (≤255 chars)            | Yes              | Any                   |
| Date, DateTime               | Yes              | Any                   |
| Picklist                     | Yes              | Any                   |
| Boolean (Checkbox)           | Yes              | Any                   |
| Lookup/Reference             | Yes, shows Name  | Any                   |
| **Long Text Area**           | **No**           | —                     |
| **Rich Text**                | **No**           | —                     |
| **Encrypted**                | **No**           | —                     |
| **Geolocation**              | **No**           | —                     |
| **Multi-Select Picklist**    | **No** (Phase D) | Future consideration  |
| **Formula (returns text)**   | Yes              | Expanded only         |
| **Formula (returns number)** | Yes              | Any                   |

**Max active fields per section:**

- Main Grid: max **8** custom fields (beyond the 4 system fields). More clutters the grid.
- Expanded Detail: max **15** custom fields. More room in the expanded row.

The Apex `getEligibleDisplayFields(objectApiName)` method filters against this table before presenting options to the admin.

### Child Object Field Aggregation (Review feedback #8)

When a display field comes from a child object (e.g., `OpportunityLineItem.Product_Family__c`), there may be multiple child records per Opportunity. The spec must define which value appears:

| Field Type              | Aggregation                                                    | Example                          |
| ----------------------- | -------------------------------------------------------------- | -------------------------------- |
| Currency/Number/Percent | **SUM**                                                        | Sum of all line item amounts     |
| Text/Picklist           | **First non-null** (ordered by child object's CreatedDate ASC) | First product name               |
| Date                    | **Earliest**                                                   | Earliest line item date          |
| Boolean                 | **ANY true** (logical OR)                                      | True if any child record is true |
| Lookup                  | **First non-null**                                             | First related record             |

This is the **default** aggregation. Future: admin can configure per-field aggregation (SUM/FIRST/LAST/CONCAT). Phase D uses defaults only.

**Admin help text**: When an admin adds a child-object display field, the field picker shows: "Child object fields are aggregated automatically: numbers are summed, text shows the first value, dates show the earliest. Custom aggregation is a future enhancement."

### System Field Behavior (Review feedback #10)

The 4 system fields (Amount, CloseDate, OwnerId, StageName) are:

- **Non-deletable** (`Is_System__c = true`)
- **Display order editable** (admin can reorder them)
- **Location editable** — can be moved to Expanded Detail (e.g., admin might hide Stage from main grid if they use categories instead)
- **NOT hideable** — `Is_Active__c` cannot be set to false for system fields. At least the 4 core fields must always be visible somewhere.

### Onboarding Wizard Integration

Integrated into **Step 10** (before Activate), as a new substep:

```
Which fields should appear in the forecast grid?

DEFAULT FIELDS (required, reorderable):
  ✓ Amount — Main Grid
  ✓ Close Date — Main Grid
  ✓ Owner — Main Grid
  ✓ Stage — Main Grid

ADDITIONAL FIELDS: [+ Add Field]
  Source Object: [Search... 🔍]  Field: [Search... 🔍]
  Display: ○ Main Grid  ○ Expanded Detail  ○ Both
```

### Admin Console Integration

Field Mappings tab — enhanced with full CRUD:

- System fields shown but non-deletable
- **+ Add Field**: Source Object/Field search-selects (using `getEligibleDisplayFields`), Display Location radio, Width picker
- **Save All** persists changes
- Sort order via number input

---

## 4. Consolidated Wizard Step Sequence (Review feedback — Issue 4)

| Step | Label      | What                                                                   |
| ---- | ---------- | ---------------------------------------------------------------------- |
| 1    | Discovery  | Org discovery results                                                  |
| 2    | Hierarchy  | Hierarchy source + custom field                                        |
| 3    | Pipeline   | Record types + grouping mode + groups                                  |
| 4    | Stages     | Terminal stages (per-group if applicable)                              |
| 5    | Metrics    | Forecast metrics with source object/field                              |
| 6    | Categories | Category template + Final/Stretch flags                                |
| 7    | Periods    | Period type, fiscal month, past/future periods, **cadence + deadline** |
| 8    | Currency   | Currency mode (read-only for single-currency)                          |
| 9    | Levels     | Hierarchy level labels (auto-derive + override)                        |
| 10   | Fields     | **Display field picker** (main vs expanded)                            |
| 11   | Attainment | Attainment source + layout                                             |
| 12   | Activate   | Review + activate                                                      |

Steps 10-12 renumbered (was 10-11). "Fields" inserted as new Step 10, pushing Attainment to 11 and Activate to 12.

---

## 5. Implementation Plan

### New Objects

| Object                        | Fields | Purpose                                      |
| ----------------------------- | ------ | -------------------------------------------- |
| `Forecast_Summary__c`         | 14     | Per-category rollup with override capability |
| `Forecast_Summary_History__c` | 8      | Append-only trend history per summary        |
| `Forecast_Display_Field__c`   | 11     | Custom grid column configuration             |

### Modified Objects

| Object                      | Changes                                                                                                                                                                                                                                           |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Forecast_Configuration__c` | +5 fields: `Forecast_Cadence__c`, `Submission_Deadline_Day__c`, `Auto_Freeze_On_Deadline__c`, `Cadence_Anchor_Date__c`, `Summary_All_Metrics__c`. Total: **24 → 29**. Deprecate (hide): `Hourly_Snapshot_Days__c`, `Hourly_Snapshot_Interval__c`. |
| `Forecast_Snapshot__c`      | Add `Cadence` to `Snapshot_Type__c` picklist. Coexists with existing `Weekly` for backward compat.                                                                                                                                                |

### New Apex

| Class                          | Purpose                                                                   |
| ------------------------------ | ------------------------------------------------------------------------- |
| `ForecastCadenceSnapshotBatch` | Daily scheduled batch — checks cadence, creates snapshots + summaries     |
| `ForecastSummaryService`       | Compute summaries, persist, override CRUD, trend query                    |
| `CadenceValidationTrigger`     | Before-save validation on `Forecast_Configuration__c` for deadline format |

### Modified Apex

| Class                        | Changes                                                                                         |
| ---------------------------- | ----------------------------------------------------------------------------------------------- |
| `ForecastService.cls`        | `computeSummaries()`, display field dynamic SELECT, merge summary overrides into category cards |
| `ForecastController.cls`     | Summary override endpoints, display field config DTO, eligible field query                      |
| `AdminConsoleController.cls` | CRUD for display fields, cadence settings                                                       |
| `OnboardingController.cls`   | Accept cadence + deadline + anchor + display fields on activation                               |

### Build Order

1. **D-1: Data foundation** (~2 days) — Create 3 new objects + 5 config fields. Validation trigger. Snapshot_Type picklist update.
2. **D-2: Cadence** (~5 days) — Cadence picker in wizard + admin. `ForecastCadenceSnapshotBatch` with idempotency. Cross-month period handling. Auto-freeze policy with timezone handling.
3. **D-3: Summaries** (~6 days) — `ForecastSummaryService`. Override CRUD with permission checks. Staleness detection. Category card enrichment with override delta + trend sparkline from `Forecast_Summary_History__c`.
4. **D-4: Display Fields** (~5 days) — `getEligibleDisplayFields` with type filtering. Wizard step 10. Admin tab CRUD. Dynamic column rendering in grid. Child object aggregation defaults.
5. **D-5: Tests + deploy** (~2 days) — All test classes. Volume test with 200 participants × 5 categories × 5 groups to verify governor limits.

- **Total**: ~20 days

### Risk Mitigations

- **Summary volume**: Guardrails per §2 — config-wide always stored, per-group only when enabled, non-primary metrics opt-in.
- **History record growth**: 52-record universal cap per summary; effective time coverage varies by cadence (Weekly ≈ 1yr, Bi-Weekly ≈ 2yr, Monthly ≈ 4yr). Oldest pruned by batch.
- **Cadence batch idempotency**: Unique key `(participant, period, snapshot_date, snapshot_type)`. Skip if exists. No backfill by default.
- **Auto-freeze timezone**: Single deterministic rule — 23:59:59 in org default timezone (from `Organization.TimeZoneSidKey`). Each participant-period frozen independently.
- **Dynamic SELECT injection**: `Object_API_Name__c` and `Field_API_Name__c` validated against Schema.describe before query (same as `ChildObjectQueryService`).
- **Display field eligibility**: Server-side filter excludes Long Text, Rich Text, Encrypted, Geolocation fields. Max 8 main-grid + 15 expanded.
- **Backward compatibility**: `Hourly_Snapshot_*` fields kept but hidden. `Weekly` snapshot type coexists with `Cadence`. Existing orgs unaffected until they adopt cadence model.
- **Override_Value\_\_c = 0**: Formula `IF(Override_Value__c != null, ...)` correctly treats $0 as a legitimate override distinct from "no override" (null). Test case included.
