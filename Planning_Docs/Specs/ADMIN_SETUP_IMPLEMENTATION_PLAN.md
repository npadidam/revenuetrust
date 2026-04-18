# Implementation Plan: Admin Setup, Onboarding & Quota Management

## Context

The Forecasting LWC module is fully deployed (15 components, 16 Apex methods, 14 tests passing). Currently, the forecast configuration must be created manually via Anonymous Apex seed scripts. This plan builds the admin UI layer: an 11-step onboarding wizard for first-time setup, a tabbed admin console for ongoing configuration, and a simplified quota manager for forecasting-only customers. The spec is frozen at V1.2.

## Build Order (8 Phases)

### Phase 1: Foundation (1 day)

Deploy the new object, CMT record, permission set, trigger, and tab before any Apex/LWC work.

**New files:**

- `objects/Forecast_Quota__c/` — 8 fields: User, Period, Participant, Target_Amount, Achieved_Amount, Attainment_Pct (formula), Status, Notes
- `customMetadata/Hierarchy_Source.Default.md-meta.xml` — pre-installed default (Source_Type=Ownership)
- `permissionsets/RevenueTrust_Admin.permissionset-meta.xml` — config+quotas, no structural changes
- `triggers/ForecastQuotaTrigger.trigger` + `classes/ForecastQuotaTriggerHandler.cls` — User+Period uniqueness
- `customMetadata/Trigger_Control.ForecastQuotaTrigger.md-meta.xml`
- `tabs/REVT_Admin.tab-meta.xml`
- `objects/Forecast_Change_Event__c/fields/Config_Change_Details__c.field-meta.xml` — LongTextArea for admin audit

**Updates:**

- `applications/RevenueTrust.app-meta.xml` — add Admin tab
- `permissionsets/RevenueTrust_Full_Access.permissionset-meta.xml` — add Forecast_Quota\_\_c permissions

### Phase 2: OnboardingController + Period Service (1.5 days)

Org discovery and config activation Apex.

**New files:**

- `classes/OnboardingController.cls` — org discovery (Schema.describe for stages, record types, hierarchy, currency, fiscal year), CMT async deploy helper, config activation, reconfigure detection
- `classes/OnboardingControllerTest.cls`
- `classes/ForecastPeriodService.cls` — extracted period creation utility (shared by batch + wizard)

**Updates:**

- `classes/ForecastPeriodGeneratorBatch.cls` — delegate to ForecastPeriodService

**Key methods:**

- `discoverOrg()` — cacheable, returns OrgDiscoveryResult DTO
- `activateConfiguration(...)` — 14 flat params, creates config + metrics + categories + periods + participants
- `deployCmtUpdate(fullName, fieldValues)` — async Metadata.Operations
- `checkDeployStatus(jobId)` — polls deployment result
- `hasActiveConfig()` — cacheable, for wizard/grid detection

### Phase 3: AdminConsoleController (1 day)

CRUD for config, metrics, categories, periods, participants + audit logging.

**New files:**

- `classes/AdminConsoleController.cls` — ~25 @AuraEnabled methods (all flat params)
- `classes/AdminConsoleControllerTest.cls`

**Updates:**

- `classes/ForecastDataService.cls` — add `public static void clearConfigCache()` wrapper

**Key patterns:**

- Config save → `clearConfigCache()` + audit event
- Metric/category delete → blocked if override data exists (guard rail query)
- Period status change → validation per Phase 3 hard rules
- Participant sync → delegates to `ForecastInitializationBatch`

### Phase 4: QuotaManagerController (1 day)

Forecast_Quota\_\_c CRUD, CSV import, bulk operations.

**New files:**

- `classes/QuotaManagerController.cls` — getQuotas, save, importCsv, distributeEvenly, copyFromLastPeriod
- `classes/QuotaManagerControllerTest.cls`
- `classes/QuotaImportBatch.cls` — for CSV imports >200 rows

**Key patterns:**

- CSV parsing with row-level error reporting
- Distribute Evenly: enter total → preview → confirm (two-step)
- Copy from Last Period: conflict policy (OVERWRITE / SKIP*EXISTING / APPLY*% \_INCREASE)

### Phase 5: Onboarding Wizard LWC (3 days)

11-step flow with progress indicator.

**New files:**

- `lwc/revtOnboardingWizard/` — HTML + JS + CSS + meta.xml

**11 Steps:**

1. Org Discovery (auto, green/yellow/red cards)
2. Hierarchy Source (radio group)
3. Pipeline Object & Record Types (checkbox list)
4. Terminal Stages (dual checkbox)
5. Forecast Metrics (editable table, max 6)
6. Forecast Categories (template picker + custom)
7. Period Configuration (combobox + inputs)
8. Currency Configuration (radio, auto-skip if single)
9. Hierarchy Level Labels (editable list)
10. Attainment Source (radio, 3 options)
11. Review & Activate (summary + one-click)

**State:** All in JS until Step 11 Activate. Reconfigure mode shows warnings + typed confirmation.

### Phase 6: Admin Console LWC + Sub-Components (3 days)

Tabbed interface with 7 sections.

**New files (7 sub-components):**

- `lwc/revtAdminConsole/` — parent with `lightning-tabset`
- `lwc/revtAdminGeneralSettings/` — config field editors with impact warnings
- `lwc/revtAdminMetrics/` — `lightning-datatable` with inline edit, max-6 guard
- `lwc/revtAdminCategories/` — datatable + color picker + template selector
- `lwc/revtAdminPeriods/` — timeline view, status actions, generate button
- `lwc/revtAdminParticipants/` — paginated datatable, sync button, delegate management
- `lwc/revtAdminFieldMappings/` — CMT editor with async deploy polling

**New FlexiPage:**

- `flexipages/REVT_Admin.flexipage-meta.xml`

### Phase 7: Quota Manager LWC (1.5 days)

Embedded as the "Quotas" tab in Admin Console.

**New files:**

- `lwc/revtQuotaManager/` — inline-edit table, CSV import modal, distribute/copy modals with preview

### Phase 8: Integration (1.5 days)

Wire wizard into Forecast tab, update attainment source, seed data.

**Updates:**

- `lwc/revtForecastApp/revtForecastApp.js` — add `hasActiveConfig()` check, `showWizard` flag, gear icon for admin nav
- `lwc/revtForecastApp/revtForecastApp.html` — conditional wizard vs grid rendering
- `classes/ForecastService.cls` — add `Forecast_Quota__c` as third attainment source in `loadAttainmentData()`
- `classes/ForecastDataService.cls` — add `getForecastQuota(userId, periodId)` query method

**New files:**

- `scripts/apex/seedAdminTestData.apex` — admin demo data

## Key Technical Decisions

| Decision                  | Choice                                                     | Rationale                                                            |
| ------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------- |
| CMT deployment            | `Metadata.Operations.enqueueDeployment()` with polling     | Only way to update CMT from Apex. Poll every 2s, timeout at 10s.     |
| Period creation reuse     | Extract to `ForecastPeriodService.cls`                     | Batch has private methods, wizard + admin both need it.              |
| Config cache invalidation | New `clearConfigCache()` public method                     | `resetCache()` is @TestVisible private — add public wrapper.         |
| Flat Apex params          | All @AuraEnabled use primitives                            | Inner class DTOs fail in namespaced orgs (learned from forecasting). |
| Audit events              | `Forecast_Change_Event__c` with `Config_Change_Details__c` | New LongTextArea field for JSON old/new values.                      |
| Quota uniqueness          | Before-insert trigger                                      | Composite lookup uniqueness can't be declared in metadata.           |

## Verification

| Phase | Verification                                                                                                     |
| ----- | ---------------------------------------------------------------------------------------------------------------- |
| 1     | `sf project deploy` — object, CMT, perm set, trigger deploy. Zero errors.                                        |
| 2     | Apex tests pass. `discoverOrg()` returns valid data from anonymous Apex.                                         |
| 3     | Apex tests pass. Config CRUD works, cache clears, audit events created.                                          |
| 4     | Apex tests pass. CSV import creates quotas, duplicates rejected.                                                 |
| 5     | Wizard renders when no config. 11 steps navigate. Activate creates config.                                       |
| 6     | Admin Console loads all tabs. Edit settings, save, audit logged.                                                 |
| 7     | Quotas table loads. Inline edit, import CSV, distribute evenly work.                                             |
| 8     | Forecast tab shows wizard on clean org. Gear icon navigates to admin. Attainment reads from Forecast_Quota\_\_c. |

## Estimated Total: ~13.5 days

### File Count

- **New Apex:** 7 classes (3 controllers + 3 test classes + 1 service)
- **New LWC:** 9 components
- **New Object:** Forecast_Quota\_\_c (8 fields + trigger + handler)
- **New Metadata:** 1 CMT record, 1 permission set, 1 tab, 1 FlexiPage, 1 field
- **Updates:** 6 existing files (ForecastService, ForecastDataService, ForecastPeriodGeneratorBatch, revtForecastApp, RevenueTrust app, Full Access permset)
