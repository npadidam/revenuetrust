# Onboarding Wizard V2 — Implementation Plan

## Context

The Onboarding Wizard (V1) is fully deployed and working — 11 steps, 5 LWC components, OnboardingController.activateConfiguration() with 14 flat params. After UAT walkthrough, the user identified ~25 improvements across all 9 wizard screens covering: data accuracy (user count excluding system users), missing context (record types, source objects), capability gaps (per-RT forecasting, line item metrics, custom categories with Final/Stretch totals), and UX polish (terminology clarity, runtime overrides for setup choices).

The headline capability of this release is **multi-object revenue sourcing** — admins can configure forecasts that pull amounts from `OpportunityLineItem`, `QuoteLineItem`, CPQ packaged objects (`SBQQ__QuoteLine__c`, `conga__QuoteLine__c`, `blng__InvoiceLine__c`), or arbitrary custom objects (e.g., a Huntress-style `Product_Bookings__c` with `Booking_Type_Classification__c`, `ACV__c`, `Customer_Amount__c`). This is not offered by most incumbent forecast tools and is the primary competitive differentiator for this release.

This plan addresses all feedback in **3 sequenced phases by screen group**, each shipping independently:

- **Phase A**: Screens 1, 2, 8 — Discovery accuracy, hierarchy clarity, currency UX
- **Phase B**: Screens 3, 4, 5 — Per-record-type and per-custom-field forecasting + multi-source-object metrics (largest phase, includes ForecastService refactor)
- **Phase C**: Screens 6, 7, 9 — Custom categories with Stretch number flag, forecast horizon (read-only multi-period), hierarchy level auto-derivation per-level

> **Dev-phase note:** RevenueTrust is in active development with no installed customers yet. **No data migration scripts are required.** When new fields/objects/uniqueness rules are deployed, simply wipe existing forecast configs (via Anonymous Apex) and re-run the Onboarding Wizard to seed fresh data. This keeps the codebase free of one-time backfill scripts and back-compat shims.

## Key Architectural Decisions

| Decision                            | Choice                                                                  | Rationale                                                                                                                                                                                                                                                               |
| ----------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Level labels (Screen 9)             | **Per-level auto-derive + override**                                    | Each level has its own `autoDerive` flag in `Level_Labels__c` JSON. Refresh button in admin console re-pulls only auto-derived levels.                                                                                                                                  |
| Per-RT forecasting (Screens 3, 4)   | **RT + Custom Field on Opp/child object**                               | Admin chooses grouping dimension: RecordType OR a custom field on Opportunity / OpportunityLineItem / packaged CPQ / custom child object.                                                                                                                               |
| Revenue source objects (Screen 5)   | **Multi-object architecture (competitive differentiator)**              | Opportunity is always the anchor. Metrics roll up from any _eligible_ child object (see eligibility tiers below).                                                                                                                                                       |
| Source object eligibility           | **3-tier system**                                                       | Tier 1 (Recommended): standard pipeline objects + detected CPQ packages. Tier 2 (Standard): other queryable child objects with currency/number fields. Tier 3 (Advanced): all others, hidden by default behind "Show Advanced" toggle. Denylist filters system objects. |
| Metric filters                      | **Structured filter builder, NOT freeform SOQL**                        | New child object `Forecast_Metric_Filter__c` with Field/Operator/Value/Logical Operator. Max 5 clauses per metric. No raw SOQL fragments stored.                                                                                                                        |
| Forecast Group scope                | **Narrow: membership + display + optional stage override**              | Group is ONLY about which opps belong and how they're labeled. Metrics live at config level and optionally reference groups. Stages are config-level by default; per-group override is optional.                                                                        |
| Group lifecycle                     | **Lookup with restrict-delete trigger**                                 | NOT master-detail. Groups persist when config archived. Trigger blocks delete if active overrides exist.                                                                                                                                                                |
| Override grain                      | **One override per (Opportunity + User + Period + Group)**              | Same opp in 2 groups = 2 separate override rows, each self-contained with bundled metric values. Matches existing row-oriented pattern.                                                                                                                                 |
| Dedup policy                        | **Per-group totals overlap by design; grand total uses unique opp set** | Detailed rules per grouping type (RT vs Opp field vs child field) — see Phase B Dedup Policy section.                                                                                                                                                                   |
| Forecast horizon (Screen 7)         | **Setup default + runtime toggle, but multi-period is READ-ONLY**       | Editing requires single-period mode. Switching to multi-period horizon → read-only mode, save/freeze hidden. Banner: "Switch to Current Period to edit."                                                                                                                |
| Quotas per group                    | **Add `Forecast_Group__c` to `Forecast_Quota__c` (nullable)**           | Unique constraint becomes User + Period + Group (Group nullable for config-wide). Resolution: group-specific quota wins; falls back to config-wide if no group quota.                                                                                                   |
| Custom categories (Screen 6)        | **Add/delete + reuse existing `Counts_Toward_Target__c` for Final**     | Existing field is canonical for Final number. New `Counts_Toward_Stretch__c` is independent. No deprecation needed.                                                                                                                                                     |
| Single-currency orgs (Screens 1, 8) | **Read-only display**                                                   | Step 8 shows "Single Currency: USD (org default)" as read-only info card. Educational context.                                                                                                                                                                          |
| Per-group stages (Step 4)           | **Optional override; default inherits config**                          | Most orgs don't need different terminal stages per group. Per-group stages only set when admin explicitly toggles "Override stages for this group."                                                                                                                     |

---

# Phase A: Discovery, Hierarchy & Currency (Screens 1, 2, 8)

## Goal

Fix data accuracy and add explicit terminology/context to early wizard steps.

## Backend Changes

### `OnboardingController.cls` — `discoverOrg()` enhancements

Update [OnboardingController.cls](force-app/main/default/classes/OnboardingController.cls) `discoverOrg()` and the `OrgDiscoveryResult` DTO:

1. **Active user count** — exclude system/integration users:
   ```apex
   Integer activeUserCount = [
     SELECT COUNT() FROM User
     WHERE IsActive = true
       AND UserType = 'Standard'
       AND Profile.Name NOT IN (
         'Chatter Free User', 'Chatter External User',
         'Analytics Cloud Integration User', 'Analytics Cloud Security User',
         'Customer Community User', 'Partner Community User'
       )
       AND Profile.UserLicense.Name NOT IN ('Chatter Free', 'Chatter External')
   ];
   ```
2. **Hierarchy source label** — add field `hierarchySourceLabel` to `OrgDiscoveryResult` (e.g., "Role Hierarchy", "Manager Field", "Territory")
3. **Fiscal year start month name** — add field `fiscalYearStartMonthName` (e.g., "January", "April") computed via `Datetime.newInstance(2000, month, 1).format('MMMM')`
4. **Corporate currency** — add field `corporateCurrency` from `[SELECT CurrencyIsoCode FROM Organization]`
5. **Stages by record type** — when org uses RecordTypes for Opportunity, group stages by RT:
   - Add `stagesByRecordType` to `OrgDiscoveryResult`: `Map<String, List<StageInfo>>` keyed by RT DeveloperName
   - Use `Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()` and `.getPicklistValues()` per RT
   - **Test against real RT-dependent picklist configs** — each RT may have a subset of stages, the full set, or a unique subset. Verify behavior when:
     - All RTs share the full picklist
     - RT-A has subset, RT-B has different subset
     - Newly-created RT with no picklist values assigned (should show empty stages, not error)

## LWC Changes

### `revtWizardDiscovery` — Step 1 "Org Discovery"

[revtWizardDiscovery.html](force-app/main/default/lwc/revtWizardDiscovery/revtWizardDiscovery.html):

- **Users card**: Show count from new filtered query. Add subtitle "Excluding integration, security, community, and Chatter-only users."
- **Hierarchy card**: Add explicit label "Source: Role Hierarchy" (from `hierarchySourceLabel`)
- **Currency card**:
  - Show `Fiscal year starts: January` (not "Month 1")
  - Show `Corporate Currency: USD`
  - If `!isMultiCurrency`: append banner "Multi-currency not enabled in this org"
- **Opportunity Stages card**: When `stagesByRecordType` is non-empty, expand card to show table:
  ```
  RECORD TYPE     | STAGE COUNT | TERMINAL
  Standard        | 8 stages    | Closed Won, Closed Lost
  Enterprise      | 6 stages    | Won, Lost
  ```

### `revtWizardDiscovery` — Step 2 "Hierarchy Source"

[revtWizardDiscovery.html](force-app/main/default/lwc/revtWizardDiscovery/revtWizardDiscovery.html):

- Add help text under each radio option (final wording — small additions over draft for clarity):
  - **Ownership (Role Hierarchy)** — "Subordinates determined by Salesforce Role Hierarchy. Managers see direct reports + their reports' reports recursively. Most common choice."
  - **Manager Hierarchy** — "Use the standard `User.ManagerId` field instead of Role Hierarchy. Best when your org maintains manager relationships but not Role Hierarchy."
  - **Territory** — "Use Salesforce Enterprise Territory Management (Territory2). Forecasts roll up by territory assignment."
  - **Custom Field** — "Group by a custom Object + Field combination. Specify the object and field below."
- When **Custom Field** is selected, render two new inputs:
  - `lightning-combobox` for Object (Opportunity / Account / User) — defaults to Opportunity
  - `lightning-input` for Field API Name (text)
- Add data captured: `scopeCustomObject`, `scopeCustomField`

### `revtWizardSettings` — Step 8 "Currency"

[revtWizardSettings.html](force-app/main/default/lwc/revtWizardSettings/revtWizardSettings.html):

- When `discovery.isMultiCurrency === false`:
  - Render **read-only card**: "Single Currency: {{corporateCurrency}} — Multi-currency is not enabled in this Salesforce org. To enable additional currencies, contact your Salesforce administrator."
  - Hide all `lightning-radio-group` and `corporateCurrency` input
  - Auto-set `wizardData.currencyMode = 'Single'`, `wizardData.corporateCurrency = discovery.corporateCurrency`
- Also hide currency step entirely from **Admin Console General Settings** ([revtAdminGeneralSettings.html](force-app/main/default/lwc/revtAdminGeneralSettings/revtAdminGeneralSettings.html)) when `currencyMode === 'Single'`

## New Field

- `Forecast_Configuration__c.Scope_Custom_Object__c` (Text 100) — paired with existing `Scope_Custom_Field__c`

## OnboardingController.activateConfiguration() Updates

- Add params: `scopeCustomObject`, `scopeCustomField`
- Set `config.Scope_Custom_Object__c` and `config.Scope_Custom_Field__c` when `hierarchySource == 'Custom_Field'`

## Verification (Phase A)

1. Run discovery in current org — verify user count drops from 8 to 1 (just Nagaraju as Standard System Admin)
2. Verify "Fiscal year starts: January" shows instead of "Month 1"
3. Verify Corporate Currency "USD" shows in Step 1 card
4. Set hierarchy source to "Custom Field" — verify Object + Field inputs appear and persist through to activation
5. Verify Step 8 is read-only in single-currency org
6. Check Admin Console "Currency Mode" / "Corporate Currency" fields are hidden when single-currency
7. RT-stage discovery edge cases: org with RT-specific picklists shows correct stage counts per RT; org with newly-created RT (no values) doesn't error

---

# Phase B: Pipeline, Stages & Metrics (Screens 3, 4, 5)

## Goal

Enable per-record-type and per-custom-field forecast grouping. Support metrics rolled up from any eligible child object of Opportunity (OpportunityLineItem, QuoteLineItem, SBQQ**QuoteLine**c, conga**QuoteLine**c, custom objects like Product_Bookings\_\_c).

## Architectural Principles

### Opportunity is Always the Anchor

- **Opportunity** holds the temporal + workflow data: `CloseDate`, `StageName`, `OwnerId`, `RecordTypeId`, `IsClosed`, `IsWon`. These drive period assignment, terminal stage detection, ownership/scope, and pipeline-record-type filtering.
- **Child objects** (any object with a lookup to Opportunity) hold the _quantitative_ breakdown: amounts, quantities, classifications. Revenue can be pulled from `Opportunity.Amount` (the simple case) OR rolled up from a child object's amount field, optionally filtered/grouped by a child object classification.

### Forecast Group is Narrow

A `Forecast_Group__c` represents **only** three things:

1. **Membership** — which opps belong to this group (via RecordType, Opportunity field value, or child object field value)
2. **Display** — name and sort order for the group's tab/section in the forecast UI
3. **Optional stage override** — if explicitly set, overrides the config-level terminal stages. Default is to inherit.

Groups do NOT define metric scoping by default. Metrics live at the config level. A metric can OPTIONALLY reference a specific group via `Forecast_Group__c` lookup, but the default is config-wide ("applies to all groups").

This narrowing avoids the trap of making groups a universal abstraction for every behavior.

## Auto-Discovery: Child Objects of Opportunity

`OnboardingController.discoverOrg()` adds:

```apex
List<ChildObjectInfo> oppChildObjects = new List<ChildObjectInfo>();
Schema.DescribeSObjectResult oppDesc = Opportunity.SObjectType.getDescribe();
for (Schema.ChildRelationship cr : oppDesc.getChildRelationships()) {
  String objName = cr.getChildSObject().getDescribe().getName();
  if (!isEligible(objName, cr)) { continue; }  // see eligibility rules below
  ChildObjectInfo info = new ChildObjectInfo();
  info.objectApiName = objName;
  info.objectLabel = cr.getChildSObject().getDescribe().getLabel();
  info.lookupFieldApiName = cr.getField().getDescribe().getName();
  info.tier = classifyTier(objName);  // 'Recommended' / 'Standard' / 'Advanced'
  info.numericFields = describeNumericFields(objName);  // Currency + Number fields
  info.picklistFields = describePicklistFields(objName);  // for grouping UIs
  oppChildObjects.add(info);
}
```

### Eligibility Rules (Issue #5)

A child object is **eligible** if ALL of:

- `Schema.sObjectType.X.isQueryable()` returns true
- Has at least one Currency or Number field (otherwise no metric value to roll up)
- NOT in the system denylist:
  ```
  FeedItem, FeedComment, FeedAttachment, ContentDocumentLink, ContentVersion,
  Attachment, Note, AttachedContentDocument, EmailMessage, EmailRelation,
  Task, Event, ProcessInstance, ProcessInstanceStep, ProcessInstanceWorkitem,
  TopicAssignment, EntitySubscription, OpportunityHistory, OpportunityFieldHistory,
  OpportunityShare, OpportunityFeed, ActivityHistory, OpenActivity, CombinedAttachment
  ```
- Junction objects with no own currency/number data are excluded automatically (caught by the "must have numeric field" rule)

### Tier Classification

- **Tier 1 (Recommended)** — shown by default in wizard pickers:
  - `OpportunityLineItem`, `QuoteLineItem`, `Quote`, `Order`, `Contract`
  - Detected CPQ packages: `SBQQ__QuoteLine__c`, `conga__QuoteLine__c`, `Apttus__QuoteLine__c`, `blng__InvoiceLine__c`
- **Tier 2 (Standard)** — shown by default in wizard pickers:
  - Other queryable child objects with currency/number fields and not in denylist
- **Tier 3 (Advanced)** — hidden behind "Show Advanced Objects" toggle:
  - All others. UI shows warning: "Advanced: confirm this object is appropriate for forecasting before use."

## New Object: `Forecast_Group__c`

| Field                       | Type                                             | Purpose                                                                                                                                                            |
| --------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Forecast_Configuration__c` | **Lookup** (NOT master-detail) — Restrict Delete | Parent config                                                                                                                                                      |
| `Name`                      | Standard                                         | "New Business", "Renewals", etc.                                                                                                                                   |
| `Group_Type__c`             | Picklist                                         | `All` / `Record_Type` / `Custom_Field`                                                                                                                             |
| `Record_Type_Names__c`      | LongTextArea(2000)                               | Comma-separated RT DeveloperNames (when type=Record_Type)                                                                                                          |
| `Group_Source_Object__c`    | Text(100)                                        | API name of object holding the grouping field — `Opportunity` / `OpportunityLineItem` / `SBQQ__QuoteLine__c` / `Product_Bookings__c` etc. (when type=Custom_Field) |
| `Group_Lookup_Field__c`     | Text(100)                                        | The field on `Group_Source_Object__c` that points to Opportunity (e.g., `OpportunityId` for OppLineItem, `Opportunity__c` for custom)                              |
| `Group_Field__c`            | Text(100)                                        | API name of grouping field on `Group_Source_Object__c`                                                                                                             |
| `Group_Field_Values__c`     | LongTextArea(2000)                               | Comma-separated picklist values for this group                                                                                                                     |
| `Override_Stages__c`        | Checkbox                                         | When false, group inherits config-level stages. When true, uses fields below. Default false.                                                                       |
| `Closed_Won_Stages__c`      | LongTextArea(2000)                               | Used only when `Override_Stages__c = true`                                                                                                                         |
| `Closed_Lost_Stages__c`     | LongTextArea(2000)                               | Used only when `Override_Stages__c = true`                                                                                                                         |
| `Sort_Order__c`             | Number                                           | Display order                                                                                                                                                      |
| `Is_Active__c`              | Checkbox                                         | Default true                                                                                                                                                       |

### Group Lifecycle (Issue #1)

- **Lookup, not Master-Detail** — Groups persist independently. Deactivating a config does NOT cascade-delete groups or their associated metrics/overrides.
- **Restrict-delete trigger** — Blocks deletion of `Forecast_Group__c` if any `Forecast_Override__c` records reference it. Admin must reassign or delete overrides first.
- **Soft-delete via `Is_Active__c = false`** — Preferred path. Group becomes hidden in UI but historical overrides remain queryable.

## New Fields on `Forecast_Metric__c`

| Field                    | Type                        | Purpose                                                                                                                                                   |
| ------------------------ | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Forecast_Group__c`      | Lookup(Forecast_Group\_\_c) | If null, metric applies to all groups (config-wide). If set, metric is group-specific.                                                                    |
| `Source_Object__c`       | Text(100)                   | API name of object holding the metric's source value. `Opportunity` (default) / `OpportunityLineItem` / `SBQQ__QuoteLine__c` / `Product_Bookings__c` etc. |
| `Source_Lookup_Field__c` | Text(100)                   | When `Source_Object__c != Opportunity`: the field linking child → parent (`OpportunityId`, `Opportunity__c`, `SBQQ__Opportunity__c`, etc.)                |
| `Source_Field__c`        | Text(100)                   | The numeric field on `Source_Object__c` to roll up (`Amount`, `ACV__c`, `Customer_Amount__c`, etc.)                                                       |
| `Source_Aggregation__c`  | Picklist                    | When source != Opportunity: SUM / AVG / MAX / MIN / COUNT.                                                                                                |

### NEW Object: `Forecast_Metric_Filter__c` (replaces freeform `Source_Filter__c`)

Per Issue #4 and Issue #2 (literal value risk), filters are structured, not freeform SOQL.

| Field                   | Type                                           | Purpose                                                                                                |
| ----------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Forecast_Metric__c`    | Lookup(Forecast_Metric\_\_c) — Restrict Delete | Parent metric                                                                                          |
| `Field_API_Name__c`     | Text(100)                                      | Field on `Forecast_Metric__c.Source_Object__c` to filter by                                            |
| `Operator__c`           | Picklist                                       | `=` / `!=` / `>` / `<` / `>=` / `<=` / `IN` / `NOT IN` / `LIKE` / `NOT LIKE` / `INCLUDES` / `EXCLUDES` |
| `Value__c`              | LongTextArea(1000)                             | Serialized per the contract below.                                                                     |
| `Logical_Operator__c`   | Picklist                                       | `AND` / `OR` — how this clause joins to the next. Last clause's value ignored.                         |
| `Sort_Order__c`         | Number                                         | Clause evaluation order                                                                                |
| `Validation_Status__c`  | Picklist                                       | `Valid` / `Invalid_Field` / `Invalid_Value` — set by daily batch (see below)                           |
| `Validation_Message__c` | Text(255)                                      | Human-readable status                                                                                  |

**`Value__c` Serialization Contract** (locked — applies across UI, controller, and service layers):

| Operator(s)                                         | Storage Format                         | Example Value Stored                                                  |
| --------------------------------------------------- | -------------------------------------- | --------------------------------------------------------------------- |
| `=`, `!=`, `>`, `<`, `>=`, `<=`, `LIKE`, `NOT LIKE` | Single scalar as stringified API value | `"Active"`, `"100000"`, `"true"`, `"2026-04-15"`                      |
| `IN`, `NOT IN`, `INCLUDES`, `EXCLUDES`              | JSON array of stringified API values   | `["Net New", "Upsell"]`, `["US", "EU", "APAC"]`                       |
| Date operators with literals                        | Canonical token string                 | `"TODAY"`, `"YESTERDAY"`, `"LAST_N_DAYS:30"`, `"THIS_FISCAL_QUARTER"` |

**Type-specific normalization rules:**

- **Picklist values**: Always store API names, never labels (e.g., store `"Closed_Won"` not `"Closed Won"`)
- **Booleans**: Store as `"true"` or `"false"` strings (lowercase)
- **Numbers**: Store as plain string numerics, no thousands separators (e.g., `"100000"` not `"100,000"`)
- **Dates**: Store as ISO 8601 (`"2026-04-15"`) OR as canonical date literal token (see table above) — never local-format strings
- **Datetimes**: Store as ISO 8601 with offset (`"2026-04-15T17:00:00.000Z"`)
- **IDs**: Store as 18-character Salesforce IDs (case-safe form)

**`StructuredFilterBuilder.cls` is responsible for:**

1. Parsing `Value__c` per operator type (scalar vs JSON array vs date token)
2. Wrapping string/picklist values in single quotes for SOQL
3. Resolving date tokens to SOQL date literals (no quotes)
4. Validating the parsed value matches the field's data type (rejects type mismatches at save time)

**Constraints:**

- Max 5 clauses per metric (enforced by `before insert` trigger)
- Apex builds sanitized SOQL from these structured records — no raw user input ever concatenates into SOQL
- All Field_API_Name\_\_c values validated against Schema.describe at save time
- Picklist values for `Value__c` are validated against current picklist values (Issue #2 - literal value drift)

**Picklist Drift Detection (Issue #2 second sub-point):**

- Daily batch `ForecastMetricFilterValidator` re-checks all `Forecast_Metric_Filter__c` records:
  - Field still exists on object → `Valid` else `Invalid_Field`
  - For picklist operators (=, !=, IN, NOT IN), value still exists in current picklist → `Valid` else `Invalid_Value`
- Admin sees status indicator on filter rows in admin UI
- Forecast UI shows warning when computing metric using invalid filter

## ForecastService Refactor (the major work in Phase B)

[ForecastService.cls](force-app/main/default/classes/ForecastService.cls) — `queryForecastRecords()` and downstream.

### Override Model (Issue #2 — locked)

**Uniqueness grain:** `(Opportunity__c, User__c, Forecast_Period__c, Forecast_Group__c)` — composite unique constraint.

- Same opp can appear in multiple groups → **separate override row per group**
- Each override row bundles all metric values (matches existing row-oriented pattern)
- Category override is **per (opp + group)** — same opp can have different categories in different groups (rare but valid: opp split into Net New + Upsell line items, each may classify differently)
- Close date override is **per (opp + group)** — usually identical, but the data model permits divergence
- Edit conflict resolution: dataVersion checking unchanged from V1, but version per-(opp+group) tuple

**`Forecast_Override__c` schema additions:**

- New field: `Forecast_Group__c` (Lookup, required after deploy — wipe and re-seed configs in dev)
- Update unique constraint trigger to include Group dimension

### Dedup Policy (Issue #3 + Issue #4 from second batch — locked)

The cross-scope dedup logic from §11.5 of the existing Apex spec applies **within each group**, unchanged. The new question is how grand totals work across groups.

**Grand total dedup is computed independently per metric based on that metric's source grain:**

- For Opportunity-sourced metrics → dedup key is `Opportunity.Id` (each opp counted once across all groups)
- For child-sourced metrics (OpportunityLineItem, custom child object, etc.) → dedup key is the child record `Id` (each child row counted once across all groups)

This means a single opp can have its `Opportunity.Amount` deduplicated at the opp level for the "Revenue" metric, AND simultaneously have its child records deduplicated at the line item level for the "ACV" metric — both within the same forecast view. Each metric resolves dedup using its own grain.

**Rules by grouping type:**

| Grouping Type                          | Per-Group Total                                                                     | Grand Total                                                                                                                               |
| -------------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `All` (single group)                   | Same as today                                                                       | Same as per-group                                                                                                                         |
| `Record_Type`                          | Each opp in exactly one group (RT is single-valued)                                 | Sum of per-group totals — no overlap possible                                                                                             |
| `Custom_Field` on Opportunity          | Each opp in exactly one group (assuming non-multipicklist)                          | Sum of per-group totals — no overlap possible                                                                                             |
| `Custom_Field` on Opp (multi-picklist) | Opp can appear in multiple groups                                                   | **Grand total uses unique opp set** with full Amount counted once                                                                         |
| `Custom_Field` on child object         | Opp can appear in multiple groups (different line items belong to different groups) | **Grand total computed from union of child rows across groups, deduplicated by line item ID** — no double-counting at the line item level |

**Worked example (Huntress pattern):**

- Opp X has 3 `Product_Booking__c` records: Booking A (Net New, ACV=50K), Booking B (Upsell, ACV=30K), Booking C (Net New, ACV=20K)
- Groups defined by `Booking_Type__c`: "Net New", "Upsell"
- Net New group total for ACV metric on Opp X: 50K + 20K = 70K
- Upsell group total for ACV metric on Opp X: 30K
- Grand total for ACV metric on Opp X: 70K + 30K = 100K (sum of all bookings, no double count)

**For Opportunity-sourced metrics with multi-group membership:**

- Opp X is in both "New Business" and "Amendments" groups (admin assigned overlapping RTs)
- Opp X.Amount = $100K
- Each group counts $100K (intentional overlap for per-group display)
- Grand total counts $100K once (unique opp set)

This is documented in the user-facing summary card with tooltip: "Per-group totals may overlap when an opportunity belongs to multiple groups. Grand total counts each opportunity once."

### Query Logic

1. **Anchor query (Opportunity)** — always query Opportunity first for the period/scope/RT/group filter. This produces the canonical row set with CloseDate, Stage, OwnerId, IsClosed, IsWon.

2. **Per-group filtering**:
   - `Group_Type__c == 'All'`: include all opps in scope
   - `Group_Type__c == 'Record_Type'`: filter by `Opportunity.RecordType.DeveloperName IN (...)`
   - `Group_Type__c == 'Custom_Field'`:
     - If `Group_Source_Object__c == 'Opportunity'`: filter `Opportunity.[Field] IN (values)`
     - Else: query child object first → get distinct `Opportunity` IDs where `[Group_Field__c] IN (values)` → use as `Id IN :oppIds` filter on Opportunity anchor

3. **Metric rollup from child object via `ChildObjectQueryService`**:

   ```apex
   // Inside ChildObjectQueryService.aggregate()
   String childObj = sanitizeObjectName(metric.Source_Object__c);  // validates against Schema describe
   String fkField = sanitizeFieldName(childObj, metric.Source_Lookup_Field__c);
   String amtField = sanitizeFieldName(childObj, metric.Source_Field__c);
   String agg = sanitizeAggregation(metric.Source_Aggregation__c);
   String whereClause = buildSanitizedWhere(metric.filters);  // from Forecast_Metric_Filter__c records
   String soql = 'SELECT ' + fkField + ' oppId, ' + agg + '(' + amtField + ') val ' +
                 'FROM ' + childObj + ' ' +
                 'WHERE ' + fkField + ' IN :oppIds' +
                 (whereClause != null ? ' AND ' + whereClause : '') + ' ' +
                 'GROUP BY ' + fkField;
   for (AggregateResult ar : Database.query(soql)) { ... }
   ```

   - **Bulkify**: one aggregate query per (childObject + amountField + aggregation) combination, regardless of metric count
   - **Chunk** if `oppIds.size() > 500`

4. **Update affected methods**:
   - `loadForecastRecords()` — add `groupId` context, run anchor query + per-metric child rollups
   - `saveOverrides()` — overrides keyed by (opp + user + period + group); `Forecast_Override__c.Forecast_Group__c` populated
   - `computeSummary()` — totals per group AND grand total per dedup policy above
   - `computeDedupFactors()` — refactored per group dedup rules
   - `loadAttainmentData()` — attainment per group, resolved against quotas (see Quotas section below)

5. **Cross-object security**: Each child object queried checks FLS (`Schema.sObjectType.X.fields.Y.isAccessible()`) before SELECT. If user lacks access, metric returns null with UI warning indicator (not error).

## Quotas Per Group (Issue #8 + Issue #5 from second batch — locked)

`Forecast_Quota__c` schema addition:

- New field: `Forecast_Group__c` (Lookup, nullable)
- Update unique constraint trigger to: `(User__c, Forecast_Period__c, Forecast_Group__c)` — Group nullable counts as a distinct value (so user can have one config-wide quota AND group-specific quotas simultaneously)

**Important convention asymmetry — documented intentionally:**

- **Overrides always reference a concrete `Forecast_Group__c` record** (the auto-created "All Opportunities" group is used when there's only one group). Override `Forecast_Group__c` is never null.
- **Quotas may be config-wide (`Forecast_Group__c = null`) OR group-specific.** This is by design — admins often want to set one organizational quota per user without having to duplicate it across every group.

**Resolution rule** (computed in `loadAttainmentData()`):

1. If group-specific quota exists for `(user, period, group)` → use it
2. Else if config-wide quota exists for `(user, period, null)` → use it for all groups (informational, not split)
3. Else target = 0 for that group

**Quota Manager UI updates:**

- Add Group selector in the quota grid header — admin can manage quotas per group OR config-wide
- Default view shows "Config-Wide Quotas" matching V1 behavior
- "Manage by Group" toggle exposes per-group quota grids

## LWC Changes

### `revtWizardDiscovery` — Step 3 "Pipeline & Record Types"

Rebuild [revtWizardDiscovery.html](force-app/main/default/lwc/revtWizardDiscovery/revtWizardDiscovery.html) Step 3:

- Add new question first: **"How do you want to organize your forecasts?"**
  - Radio options:
    - **Single forecast (all opportunities together)** — default
    - **Separate forecasts by Record Type**
    - **Separate forecasts by Custom Field on Opportunity**
    - **Separate forecasts by Custom Field on a Child Object** (CPQ Quote Line, Product Booking, etc.)
- If **Record Type**:
  - Show all RTs as multi-select checkboxes (with stage counts from Phase A discovery)
  - Add **"Group RecordTypes"** UI: a grouping table where admin assigns RTs to named groups (e.g., "New Business + Amendments" group contains RTs `New_Business`, `Amendment`; "Renewals" group contains `Renewal`)
- If **Custom Field on Opportunity**:
  - `lightning-combobox` for Field — populated from Opportunity picklist field discovery
  - Auto-fetch picklist values
  - Show grouping UI to assign values to named groups
- If **Custom Field on a Child Object**:
  - `lightning-combobox` for Child Object — populated from `discovery.oppChildObjects` filtered by Tier (default Recommended + Standard, "Show Advanced" toggle reveals Tier 3) with category badges: `[Recommended]` `[Standard]` `[Advanced]`
  - When Object selected, auto-detect lookup field back to Opportunity (use `Group_Lookup_Field__c`)
  - `lightning-combobox` for Field on that object — populated via `OnboardingController.getPicklistValues(object, field)`
  - Show grouping UI to assign values to named groups
- Always include **"Include all opportunities"** option (no filter)
- Show preview at bottom: "{{N}} groups will be created. Each group will have its own forecast tab."

### `revtWizardMetricsCategories` — Step 4 "Terminal Stages"

[revtWizardMetricsCategories.html](force-app/main/default/lwc/revtWizardMetricsCategories/revtWizardMetricsCategories.html) Step 4:

- Always show config-level terminal stage selector (won/lost) at top — this is the default for all groups
- If multiple groups defined, show collapsible per-group section below:
  ```
  ┌─ Per-Group Stage Overrides (Optional) ────────────┐
  │ Most groups inherit the stages above.              │
  │ Override only if a group needs different stages.   │
  │                                                     │
  │ ☐ Override stages for "New Business"               │
  │ ☐ Override stages for "Renewals"                   │
  └─────────────────────────────────────────────────────┘
  ```
- When admin checks a group's override toggle, expand to show won/lost picker for that group
- Default: all groups inherit (Override_Stages\_\_c = false)

### `revtWizardMetricsCategories` — Step 5 "Forecast Metrics"

For each metric row, render an expandable row with these fields:

**Required:**

- `lightning-input` for **Metric Label** (e.g., "Revenue", "ACV", "Customer Amount")
- `lightning-combobox` for **Source Object** — populated from `discovery.oppChildObjects` plus `Opportunity` itself. Filtered by Tier (Recommended + Standard by default; "Show Advanced" reveals Tier 3). Default: `Opportunity`.
- `lightning-combobox` for **Source Field** — dynamically populated based on selected Source Object. Filters to numeric/currency fields only. Pre-fills helpful examples per object.

**When Source Object != Opportunity:**

- `lightning-combobox` for **Aggregation** — SUM (default) / AVG / MAX / MIN / COUNT
- Auto-detected: **Lookup Field** back to Opportunity (read-only display)

**Filters (structured builder, replaces freeform):**

- "+ Add Filter Clause" button — adds row of (Field, Operator, Value, AND/OR)
- Field dropdown populated from Source Object's filterable fields
- Operator dropdown adapts to field type (text → LIKE/=, picklist → IN/=, date → date literals)
- Value input adapts: text input for text fields, picklist multi-select for picklists, date picker for dates
- Max 5 clauses
- Live preview at bottom: "Filter: Status**c = 'Active' AND Region**c IN ('US', 'EU')"

**Per-group binding:**

- `lightning-checkbox-group` for **Applies To Group** — multi-select, options from groups defined in Step 3 plus "All Groups"
- Default: All Groups (metric is config-wide)

**Pre-seeded for first metric:**

- Label: "Revenue", Source Object: `Opportunity`, Source Field: `Amount`, `Is_Primary` checked
- Help text: "From Opportunity.Amount — the standard pipeline amount."

**Validation:**

- At least one metric must be `Is_Primary` per config (if no group bindings) OR per group (if any metric is group-specific)
- Source Field must exist on Source Object (validated server-side at activation)
- If Source Object is custom and user lacks read access → block save with helpful error
- Max 5 filter clauses per metric

**Live preview at bottom of step:**

> "Sample: For an Opportunity with 3 Product_Bookings**c records (ACV**c = 50K, 30K, 20K), the metric 'ACV' will show 100,000."

## OnboardingController.activateConfiguration() Updates

- Add params: `groupsJson`, `metricFiltersJson` (one JSON array of structured filters per metric)
- After config insert: deserialize groupsJson, insert `Forecast_Group__c` records
- After metric insert: deserialize each metric's filters, insert `Forecast_Metric_Filter__c` records linked to metric

## Reconfigure Mode Precedence (Issue #10 — locked)

When wizard is re-run on existing config:

| Change Type                                                                        | Policy                                                                                                                                                                                                                                                                                                                                                     |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Adding a metric                                                                    | Append, no impact to existing                                                                                                                                                                                                                                                                                                                              |
| Removing a metric                                                                  | **Deactivate only** (`Is_Active__c = false`). Hidden from UI; historical overrides + audit data preserved. Hard delete is NOT supported via wizard.                                                                                                                                                                                                        |
| Renaming category                                                                  | Allowed; existing overrides keep new label automatically (relationship by Id)                                                                                                                                                                                                                                                                              |
| Removing category                                                                  | **Deactivate only** (`Is_Active__c = false`). Hidden from picker; historical overrides + audit data preserved. Hard delete is NOT supported via wizard.                                                                                                                                                                                                    |
| Adding a group                                                                     | Append, no impact                                                                                                                                                                                                                                                                                                                                          |
| Removing a group                                                                   | **Deactivate only** (`Is_Active__c = false`). Hidden from UI; historical overrides remain queryable. Hard delete blocked by restrict-delete trigger.                                                                                                                                                                                                       |
| **Switching grouping strategy entirely** (e.g., RT → custom field on child object) | **BLOCK by default**. Show banner: "This will deactivate all existing groups and create new ones. Type 'REPLACE GROUPS' to confirm." Existing overrides remain pointing to the now-deactivated groups (preserves audit trail). New overrides created under the new group structure. Admins can re-activate old groups in Admin Console if rollback needed. |
| Changing terminal stages                                                           | Update only future submissions. Historical overrides preserved as-is.                                                                                                                                                                                                                                                                                      |
| Custom level overrides                                                             | Preserved across re-runs unless admin explicitly resets via "Reset to Auto-Derived" button                                                                                                                                                                                                                                                                 |

## Verification (Phase B)

**Discovery:**

1. Run discovery — verify `oppChildObjects` includes `OpportunityLineItem`, `QuoteLineItem`, with proper tier classification
2. Create custom object `Product_Booking__c` with lookup to Opportunity + custom fields `Booking_Type__c` (picklist), `ACV__c` (currency), `Customer_Amount__c` (currency). Re-run discovery — verify it appears under "Standard" tier (or "Advanced" if no currency fields detected as eligible)
3. Verify denylist filters out FeedItem, Task, Event, ContentDocumentLink, OpportunityHistory, etc.
4. Verify "Show Advanced" toggle reveals additional objects

**Grouping:** 5. **Single forecast, no RTs**: Activate with "Single forecast" — confirm 1 group "All Opportunities" created with `Group_Type__c = All` 6. **RT grouping**: Create 2 groups (New Business + Amendments together, Renewals separate) — confirm 2 `Forecast_Group__c` records, terminal stages inherited from config (no override) 7. **Per-group stage override**: For "Renewals" group, check "Override stages" and set won=`Renewed`, lost=`Churned` — confirm stored on group, used at runtime 8. **Opp custom field grouping**: Group by `Opportunity.Type` picklist, 2 groups (New Business / Existing Customer) — confirm filter applies on forecast load 9. **Child object grouping**: Set grouping by `Product_Booking__c.Booking_Type__c`, define 3 groups (Net New, Upsell, Renewal) — confirm Forecast_Group**c records have correct `Group_Source_Object**c`, `Group_Lookup_Field\_\_c`

**Metrics:** 10. **Opportunity-sourced metric**: Standard "Revenue" from `Opportunity.Amount` — verify shows raw opp amount in grid 11. **OppLineItem-sourced metric**: Add "ARR" from `OpportunityLineItem.TotalPrice` (SUM) — verify summed across line items per opp 12. **Custom object metric (Huntress pattern)**: Add "ACV" from `Product_Booking__c.ACV__c` (SUM) — verify summed correctly. Add "Customer Amount" from `Product_Booking__c.Customer_Amount__c` (SUM) as second metric — verify both columns populate independently 13. **CPQ-style metric** (if SBQQ**QuoteLine**c exists): metric from `SBQQ__QuoteLine__c.SBQQ__NetTotal__c` — verify works with namespace prefix 14. **Structured filter**: Add "Active ACV" from `Product_Booking__c.ACV__c` with filter clauses `Status__c = 'Active'` AND `Region__c IN ('US', 'EU')` — verify only matching bookings counted

**Filter Validation:** 15. Set a filter using picklist value "Net New". Manually rename the picklist value to "Net_New_Business" in Setup. Run `ForecastMetricFilterValidator` batch — verify filter status changes to `Invalid_Value` with helpful message.

**Override Model:** 16. **Override save (single group)**: Edit "ACV" override on a row in single-group config — verify `Forecast_Override__c.Forecast_Group__c` references the auto-created "All Opportunities" group 17. **Override save (multi-group)**: Same opp shown in 2 groups; edit category in each group differently — verify 2 separate `Forecast_Override__c` rows, each with correct `Forecast_Group__c` 18. **Conflict detection**: Open same row in 2 browser tabs (same group), edit both — verify dataVersion conflict triggers correctly per (opp+group)

**Dedup:** 19. **RT grouping (mutually exclusive)**: Verify per-group totals sum exactly to grand total 20. **Child object grouping (Huntress example)**: Verify per-group totals sum to grand total at line item level (no double count) 21. **Multi-group opp via Opportunity multi-picklist**: Opp X has multi-picklist value of "Type1;Type2", appears in both groups — verify per-group totals each show full Amount, grand total shows once 22. **Verify summary tooltip**: Grand total card shows "Per-group totals may overlap..." tooltip

**Quotas Per Group:** 23. **Config-wide quota only**: Set quota for user U in period P (Group=null) — verify all groups for U show same target/attainment 24. **Group-specific quota**: Add quota for U + P + Group "Renewals" — verify Renewals group uses specific quota, other groups still use config-wide 25. **Both exist**: Both config-wide and group-specific quotas present — verify group-specific wins

**Lifecycle:** 26. **Group restrict-delete**: Create group with overrides; try to hard-delete via SOQL — verify trigger blocks 27. **Group soft-delete**: Set `Is_Active__c = false` — verify hidden in UI but overrides remain queryable 28. **Config deactivation**: Set config `Is_Active__c = false` — verify groups remain (NOT cascade-deleted)

**Reconfigure:** 29. Re-run wizard, switch grouping strategy from RT to custom field — verify block message appears, requires "REPLACE GROUPS" confirmation 30. Re-run wizard, add a new group — verify appended with no impact to existing 31. Re-run wizard, try to remove group with overrides — verify blocked

**Security & Limits:** 32. Test with a user who lacks FLS on `Product_Booking__c.ACV__c` — verify metric shows N/A with warning, not error 33. Test with 2,000 opps × 5 line items each = 10K line items — verify queries stay under SOQL limits via aggregate queries + chunking at 500 oppIds 34. **All Apex tests pass**: `ForecastControllerTest`, `ForecastServiceTest`, new `ForecastGroupTest`, new `ForecastMetricFilterTest`, new `ChildObjectQueryServiceTest`, `OnboardingControllerTest`

---

# Phase C: Categories, Periods, Levels & Attainment (Screens 6, 7, 9)

## Goal

- Custom categories with add/delete + Stretch number flag (Final reuses existing Counts_Toward_Target\_\_c)
- Forecast horizon (current Q / +Next / Full Year / Custom) — setup default + runtime toggle, **multi-period is read-only**
- Past periods visibility
- Hierarchy level labels auto-derived per-level with override + refresh

## New Field on `Forecast_Category__c`

| Field                      | Type     | Purpose                             |
| -------------------------- | -------- | ----------------------------------- |
| `Counts_Toward_Stretch__c` | Checkbox | Include in "Stretch Forecast" total |

**Note (Issue #8 from second batch):** `Counts_Toward_Target__c` (existing field) IS the canonical "Final Forecast" flag — no rename, no deprecation, no alias. Just reuse it. The "Final" label in UI maps to this field. Categories that count toward Final remain checked here. New `Counts_Toward_Stretch__c` is independent.

## New Fields on `Forecast_Configuration__c`

| Field                       | Type     | Purpose                                                                                                                      |
| --------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `Past_Periods_Visible__c`   | Number   | Number of past periods to show in period picker (default 2)                                                                  |
| `Default_Horizon__c`        | Picklist | `Current_Period` / `Current_Plus_Next` / `Quarter` / `Fiscal_Year` / `Custom`                                                |
| `Custom_Horizon_Periods__c` | Number   | When Default_Horizon = Custom, how many periods to show                                                                      |
| `Final_Forecast_Label__c`   | Text(50) | Label for the Final number (default "Final Forecast") — drives the column header that maps to `Counts_Toward_Target__c` flag |
| `Stretch_Forecast_Label__c` | Text(50) | Label for the Stretch number (default "Stretch Forecast")                                                                    |

## Per-Level Auto-Derive (Issue #7 from second batch — locked)

The config-level `Auto_Derive_Level_Labels__c` checkbox is REMOVED. Auto-derive is per-level in `Level_Labels__c` JSON:

```json
[
  { "level": 1, "label": "Sales Rep", "autoDerive": true },
  { "level": 2, "label": "Sales Manager", "autoDerive": true },
  { "level": 3, "label": "Regional VP", "autoDerive": false },
  { "level": 4, "label": "Sr. Director", "autoDerive": true }
]
```

- Each level has its own `autoDerive` flag
- `OnboardingController.discoverOrg()` populates labels for `autoDerive: true` entries on each call
- Admin can set any subset of levels to manual override
- "Refresh from Hierarchy" button re-runs discovery and updates labels for `autoDerive: true` levels only, preserving overrides

## Multi-Period Horizon = Read-Only Mode (Issue #7 — locked)

**Decision:** Editing requires single-period mode. Multi-period horizons are summary/read-only.

**Behavior when horizon != Current_Period:**

- Forecast grid shows ONE aggregated row per opp across the horizon
- Save button hidden (or disabled with tooltip)
- Submit button hidden
- Freeze button hidden
- Banner at top: "Multi-period horizon — read-only summary mode. Switch to 'Current Period' to edit."
- Inline editing on rows disabled
- Comments still visible (read-only)
- Filters still work (client-side or server-side based on count)

**State management on horizon change (Issue #6 from second batch — locked):**

1. If dirty changes exist → prompt: "You have unsaved changes. Save before switching horizon?"
   - Save → save, then change horizon
   - Discard → discard, then change horizon
   - Cancel → revert horizon picker
2. Reset pagination to page 1
3. Preserve filters (search, category, stage, etc.)
4. Reload from server
5. Update isClientSideFiltering based on new total count
6. Sticky horizon choice via sessionStorage keyed by participantId

## LWC Changes

### `revtWizardMetricsCategories` — Step 6 "Forecast Categories"

- Keep existing template options (Standard / Simple / Enterprise) + add **Custom** option
- Add **+ Add Category** button — adds row with editable label, color picker, flags
- Add **trash icon** per row — deletes (validation rule: must retain at least one terminal won category AND at least one non-terminal active pipeline category; trash icon disables on rows whose deletion would violate this)
- Per row, two checkboxes:
  - ☑ **Counts toward Final Forecast** (maps to existing `Counts_Toward_Target__c`; default true for Commit + Closed Won)
  - ☐ **Counts toward Stretch Forecast** (maps to new `Counts_Toward_Stretch__c`; default true for Commit + Best Case + Closed Won in Standard; Commit + Upside + Best Case + Closed Won in Enterprise)
- Add input fields above table for **Final Forecast Label** and **Stretch Forecast Label**
- Live preview at bottom: "Final Forecast = Commit + Closed Won = $XXX (preview based on current period)"

### `revtWizardSettings` — Step 7 "Period Configuration"

- Add new fields:
  - `lightning-input` for **Past Periods Visible** (number, 0-12, default 2)
  - `lightning-combobox` for **Default Forecast Horizon**:
    - Current Period Only
    - Current + Next Period
    - Current Quarter (3 months)
    - Current + Next Quarter (6 months)
    - Fiscal Year (12 months)
    - Custom (N periods)
  - When Custom: `lightning-input` for **Custom Periods Count**
- Add help text: "Multi-period horizons are read-only summary views. Editing requires Current Period mode."

### `revtWizardSettings` — Step 9 "Hierarchy Level Labels"

- **Header**: "Source: {{discovery.hierarchySourceLabel}}" (e.g., "Role Hierarchy")
- Render rows per level with per-level controls:
  ```
  Level | Auto-derived (preview)        | Manual Override (input)              | Auto?
  L1    | Sales Rep (from VP role tree) | [empty by default — pre-fills above] | ☑
  L2    | Sales Manager                 | [empty]                              | ☑
  L3    | Sales Director                | "Regional VP"                        | ☐
  L4    | VP                            | [empty]                              | ☑
  ```
- "Auto?" checkbox per level: when checked, label auto-derives from hierarchy on each load
- When unchecked (manual mode), the override value is canonical
- For Custom hierarchy: add **+ Add Level** and **trash icon** to delete levels
- Note at bottom: "Levels marked Auto refresh automatically as your hierarchy changes. Manual overrides persist until you change them."

### Forecast Tab — Runtime Horizon Toggle

[revtForecastApp.html](force-app/main/default/lwc/revtForecastApp/revtForecastApp.html):

- Add `lightning-combobox` to toolbar (between period picker and scope picker):
  - Same options as Default_Horizon picklist
  - Default value from `config.Default_Horizon__c`
  - Persist user override to `sessionStorage` keyed by participantId
- When horizon != Current_Period:
  - Show banner: "Multi-period view — read-only summary mode."
  - Hide Save / Submit / Freeze buttons
  - Disable inline editing on grid rows

[revtForecastApp.js](force-app/main/default/lwc/revtForecastApp/revtForecastApp.js):

- `loadRecords()` — pass `horizon` to Apex
- When horizon != Current_Period, fetch records across multiple periods and aggregate per opp
- On horizon change: dirty check, reset pagination, preserve filters, reload (per state management section above)

### Admin Console — Refresh Levels Button

[revtAdminParticipants.js](force-app/main/default/lwc/revtAdminParticipants/revtAdminParticipants.js):

- Add **"Refresh from Hierarchy"** button next to "Sync Participants"
- Calls new Apex `AdminConsoleController.refreshLevelLabels(configId)`:
  - Re-runs `OnboardingController.discoverOrg()` for hierarchy
  - For each level in `Level_Labels__c` JSON: if `autoDerive == true`, replace label with discovered value. If false, preserve admin override.
  - Saves updated JSON back to config

## ForecastService Updates

- `loadForecastRecords()` — accept `horizon` param, query multiple periods if needed, aggregate when multi-period
- `computeSummary()` — compute Final and Stretch totals based on category flags (`Counts_Toward_Target__c` for Final, `Counts_Toward_Stretch__c` for Stretch)
- Return `summary.finalForecast`, `summary.stretchForecast`, `summary.finalLabel`, `summary.stretchLabel`
- When horizon != Current_Period, mark response as `readOnly: true`

## Verification (Phase C)

1. **Custom categories**: In wizard, choose Custom template; add 2 new categories; attempt various deletes — verify the validation rule fires correctly. The rule: **must retain at least one terminal won category AND at least one non-terminal active pipeline category**. Specifically:
   - Try deleting the only "Closed Won" category → fail (no terminal won remains)
   - Try deleting the only "Pipeline" / "Best Case" / non-terminal category → fail (no active pipeline category remains)
   - Try deleting a redundant category when other won + pipeline categories exist → succeed
   - After successful activation, verify Forecast_Category\_\_c records reflect changes
2. **Final/Stretch numbers**: On forecast tab, verify two summary tiles "Final Forecast" and "Stretch Forecast" with correct sums based on category flags
3. **Past periods**: Set Past_Periods_Visible = 4; verify period picker shows 4 closed periods + current + future
4. **Horizon at setup**: Set default to "Current Quarter"; verify forecast loads 3 months of records by default in read-only mode
5. **Horizon at runtime**: Change horizon picker to "Fiscal Year" — verify reload, refresh page, verify sticky via sessionStorage
6. **Horizon dirty check**: Edit a row, then try to change horizon — verify save/discard/cancel prompt appears
7. **Multi-period read-only**: Verify Save/Submit/Freeze buttons hidden, banner displayed, inline edit disabled
8. **Auto-derived labels (per-level)**: Mark L1, L2, L4 as Auto; L3 as Manual with "Regional VP". Click "Refresh from Hierarchy" → verify L1, L2, L4 update from discovery, L3 preserved
9. **Manual override persistence**: Change L2 override to "Regional Manager" with autoDerive=false; refresh page; verify persists
10. **Mixed Auto/Manual**: Verify JSON structure stores autoDerive per level correctly

---

## Cross-Cutting Updates

### Reconfigure Mode Policy

See "Reconfigure Mode Precedence" table in Phase B above. Applies to wizard re-runs across all phases.

### Tests

- `OnboardingControllerTest` — add tests for filtered user count, custom field source, child object eligibility tiers, getPicklistValues helper, getNumericFields helper, refreshLevelLabels with per-level autoDerive
- `ForecastServiceTest` — add tests for per-group queries (RT, Opp field, child field), child object metric rollup (Opp / OppLineItem / custom), structured filters, dedup policies (4 cases from table), horizon expansion, Final/Stretch totals, multi-period read-only enforcement
- `ForecastGroupTest` — group lifecycle (lookup not master-detail, restrict-delete trigger, soft-delete preferred path)
- `ForecastMetricFilterTest` — structured filter to SOQL conversion, max 5 clauses, picklist drift validation
- `ChildObjectQueryServiceTest` — sanitization, namespace handling, FLS checks, chunking
- `AdminConsoleControllerTest` — refreshLevelLabels test, per-group quota CRUD, group active/inactive UI

---

## Critical Files

### Phase A

- `classes/OnboardingController.cls` — discoverOrg(), activateConfiguration() params
- `lwc/revtWizardDiscovery/` — Steps 1, 2, 3 (UI only — actual Step 3 logic deferred to Phase B)
- `lwc/revtWizardSettings/` — Step 8 (currency display)
- `lwc/revtAdminGeneralSettings/` — hide currency when single
- `objects/Forecast_Configuration__c/fields/Scope_Custom_Object__c.field-meta.xml` — new field

### Phase B

- `objects/Forecast_Group__c/` — new object with Lookup parent + restrict-delete trigger
- `triggers/ForecastGroupTrigger.trigger` + handler — restrict delete when overrides reference
- `objects/Forecast_Metric__c/fields/Forecast_Group__c.field-meta.xml` — new lookup
- `objects/Forecast_Metric__c/fields/Source_Object__c.field-meta.xml`
- `objects/Forecast_Metric__c/fields/Source_Lookup_Field__c.field-meta.xml`
- `objects/Forecast_Metric__c/fields/Source_Aggregation__c.field-meta.xml`
- `objects/Forecast_Metric_Filter__c/` — NEW object replacing freeform Source_Filter\_\_c
- `triggers/ForecastMetricFilterTrigger.trigger` — max 5 clauses validation
- `objects/Forecast_Override__c/fields/Forecast_Group__c.field-meta.xml` — new lookup
- `objects/Forecast_Quota__c/fields/Forecast_Group__c.field-meta.xml` — new lookup, updated unique constraint
- `classes/ForecastService.cls` — queryForecastRecords(), saveOverrides(), computeSummary(), computeDedupFactors() (per-group rules), loadAttainmentData() (per-group quota resolution)
- `classes/ChildObjectQueryService.cls` — NEW service with sanitization, FLS, chunking
- `classes/StructuredFilterBuilder.cls` — NEW utility that converts Forecast_Metric_Filter\_\_c records to safe SOQL
- `classes/ForecastMetricFilterValidator.cls` — NEW daily batch for picklist drift detection
- `classes/OnboardingController.cls` — discoverOrg() with eligibility tiers + denylist; getPicklistValues + getNumericFields helpers; activateConfiguration accepts groupsJson + metricFiltersJson
- `lwc/revtWizardDiscovery/` — Step 3 grouping UI with child object picker, tier filter, "Show Advanced" toggle
- `lwc/revtWizardMetricsCategories/` — Steps 4 (config + optional per-group stages), 5 (multi-source metrics + structured filter builder)
- `lwc/revtForecastApp/` — multi-group rendering with per-group + grand total cards
- `lwc/revtQuotaManager/` — per-group quota management UI

### Phase C

- `objects/Forecast_Category__c/fields/Counts_Toward_Stretch__c.field-meta.xml` — new (existing Counts_Toward_Target\_\_c reused for Final)
- `objects/Forecast_Configuration__c/fields/Past_Periods_Visible__c.field-meta.xml`
- `objects/Forecast_Configuration__c/fields/Default_Horizon__c.field-meta.xml`
- `objects/Forecast_Configuration__c/fields/Custom_Horizon_Periods__c.field-meta.xml`
- `objects/Forecast_Configuration__c/fields/Final_Forecast_Label__c.field-meta.xml`
- `objects/Forecast_Configuration__c/fields/Stretch_Forecast_Label__c.field-meta.xml`
- `classes/ForecastService.cls` — Final/Stretch computation, horizon expansion with read-only flag
- `classes/AdminConsoleController.cls` — refreshLevelLabels() with per-level autoDerive logic
- `lwc/revtWizardMetricsCategories/` — Step 6 with custom + flags + Final/Stretch labels
- `lwc/revtWizardSettings/` — Steps 7 (horizon, past periods), 9 (per-level auto-derive)
- `lwc/revtForecastApp/` — runtime horizon picker with read-only mode + dirty check state management
- `lwc/revtAdminParticipants/` — Refresh from Hierarchy button (per-level)

---

## Estimated Effort

- **Phase A**: ~3 days (low risk, cosmetic + 1 new field, user count fix, currency UX)
- **Phase B**: ~20 days (highest risk — Forecast_Group**c + Forecast_Metric_Filter**c objects, ForecastService refactor, ChildObjectQueryService + StructuredFilterBuilder + Validator services, group-aware overrides + quotas, eligibility tiers, multi-group dedup policy, restrict-delete triggers, cascading dropdowns in wizard, picklist drift detection, comprehensive test expansion). Original estimate of 14 days revised per Issue #6 — this is closer to the breadth required.
- **Phase C**: ~6 days (medium — UI heavy, multiple new fields, Final/Stretch summary recompute, runtime horizon picker with read-only state management, per-level auto-derive)
- **Total**: ~29 days

## Risk Mitigations

- **Phase B namespace serialization**: Use flat params + JSON strings (lesson from earlier work)
- **Phase B query limits**: Child object aggregate queries are bulk; one query per (object + field + aggregation) combination regardless of metric count. Chunks at `oppIds.size() > 500`.
- **Phase B SOQL injection**: NO freeform SOQL accepted from user. Filters are structured records (`Forecast_Metric_Filter__c`). `ChildObjectQueryService` validates object + field names against `Schema.describe`. `StructuredFilterBuilder` converts structured records to safe parameterized SOQL.
- **Phase B FLS**: Each child object query checks `Schema.sObjectType.X.fields.Y.isAccessible()` before SELECT; metric returns null with UI warning indicator if user lacks access.
- **Phase B namespace fields**: Child objects in packaged orgs (CPQ) use namespace prefixes — store `Source_Object__c` and `Source_Field__c` with prefix as detected by Schema describe. Test against `SBQQ__QuoteLine__c.SBQQ__NetTotal__c`.
- **Phase B picklist drift**: Daily `ForecastMetricFilterValidator` batch detects renamed picklist values used in filters; admin sees status indicator in UI.
- **Phase B group lifecycle**: Lookup (not master-detail) prevents cascade-delete surprises. Restrict-delete trigger blocks hard delete when overrides exist. Soft-delete via `Is_Active__c = false` preferred.
- **Phase B dedup**: Documented per-grouping-type dedup rules with worked examples. UI tooltip explains overlap behavior.
- **Phase B quotas**: New `Forecast_Quota__c.Forecast_Group__c` field is nullable. Resolution rule documented (group-specific wins; falls back to config-wide).
- **Phase C horizon**: Multi-period is READ-ONLY. Removes ambiguity around save grain, close-date overrides, status badges across mixed rows. Editing requires single-period mode.
- **Phase C horizon state management**: Documented dirty check + reset pagination + preserve filters + reload sequence on horizon change.
- **Phase C category fields**: Reuse existing `Counts_Toward_Target__c` (canonical for Final); add new independent `Counts_Toward_Stretch__c`.
- **Phase C per-level auto-derive**: Stored in JSON structure per level, not config-level boolean. Allows mixed Auto/Manual configurations.
- **Reconfigure mode**: Documented precedence rules. Switching grouping strategy requires explicit "REPLACE GROUPS" confirmation.
- **Competitive differentiator**: Multi-source-object metrics is the headline capability. Demo flow with custom Product_Booking\_\_c object that mimics Huntress pattern.

## Phase B Shipped Scope (Build Tracking)

- ✅ **B-1 Foundation**: `Forecast_Group__c` (12 fields) + `Forecast_Metric_Filter__c` (8 fields), new fields on `Forecast_Metric__c` / `Forecast_Override__c` / `Forecast_Quota__c`, two new triggers + handlers, Trigger_Control CMTs, all 3 perm sets
- ✅ **B-2 Services**: `StructuredFilterBuilder`, `ChildObjectQueryService`, `ForecastMetricFilterValidator` (daily Schedulable batch)
- ✅ **B-3 Service refactor**: `OnboardingController.discoverOrg()` adds child-object discovery + tier classification + denylist + 3 helper methods (`getNumericFields`, `getPicklistFields`, `getPicklistValues`); `activateConfiguration()` accepts `groupsJson` and auto-creates "All Opportunities" group + persists structured filters; `ForecastService.queryForecastRecords` injects child-object metric rollups via `ChildObjectQueryService`; `saveOverrides` defaults `Forecast_Group__c`; new `getDefaultGroupId()` helper; `loadAttainmentData` group-aware quota resolution; `ForecastDataService.getForecastQuota(userId, periodId, groupId)` overload
- ✅ **B-4a Wizard Step 5 multi-source metrics**: Cascading dropdowns (Source Object → Source Field → Aggregation) with tier-grouped picker (Recommended/Standard/Advanced) and auto-detected lookup field display
- ⏳ **B-4b Wizard Step 3 grouping UI** — radio for "Single forecast / RT / Custom Field on Opp / Custom Field on Child Object", grouping table to assign RTs or picklist values to named groups, child object picker with tier filter + "Show Advanced" toggle. Builds the `groupsJson` payload that `activateConfiguration` already accepts.
- ⏳ **B-4c Wizard Step 4 per-group terminal stage overrides** — collapsible per-group section with `Override_Stages__c` toggle; default inherits config-level stages.
- ⏳ **B-4d Forecast App multi-group rendering** — group selector in toolbar, per-group totals + grand total cards with overlap tooltip, dedup policy display per the table in Phase B Dedup Policy section.
- ⏳ **B-4e Quota Manager per-group UI** — Group selector in quota grid header; "Manage by Group" toggle exposes per-group quota grids; default view continues to show config-wide quotas.
- ✅ **B-5 Tests**: 4 new test classes (25 tests) — `ForecastGroupTriggerTest`, `ForecastMetricFilterTest`, `StructuredFilterBuilderTest`, `ChildObjectQueryServiceTest`. Full suite: 216/218 passing (2 pre-existing CommissionService failures unrelated to Phase B).

## Open Items (Defer to V3 if needed)

- **Per-group attainment splitting**: When config-wide quota exists but no group quota, the resolution treats config-wide quota as informational across all groups. A future enhancement could split proportionally based on per-group pipeline weight.
- **Filter expression v2**: Parenthesis grouping `(A AND B) OR C` not supported in V2 structured builder. All clauses are flat with AND/OR. Add nested grouping in V3 if needed.
- **Custom object detection refinement**: V2 surfaces all eligible custom objects. V3 could add admin-managed allow-list per org to declutter the picker.
