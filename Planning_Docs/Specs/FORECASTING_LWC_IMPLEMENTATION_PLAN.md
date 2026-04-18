# RevenueTrust — Forecasting LWC Implementation Plan

**Version:** 1.0  
**Date:** April 14, 2026  
**Status:** Approved  
**Companion specs:** FORECASTING_LWC_COMPONENTS.md V1.2 (frozen), FORECASTING_APEX_CONTROLLERS.md V1.1 (implemented)  
**Estimated duration:** ~12.5 days (1 dev) / ~9 days (2 devs)

---

## 1. Summary

Build 14 LWC components + 1 JS utility module + 3 new Apex methods from the frozen LWC spec. The Apex backend (12 @AuraEnabled methods, 20 DTOs) is fully deployed. The LWC directory is empty and ready.

---

## 2. Build Phases

### Phase 0: Apex Prerequisites (1.5 days)

**Must complete before any LWC work begins.**

#### 0.1 DTO Additions to ForecastController.cls

| DTO                       | New Field                            | Type       | Purpose                               |
| ------------------------- | ------------------------------------ | ---------- | ------------------------------------- |
| `ForecastRecordDTO`       | `dataVersion`                        | String     | Composite hash for conflict detection |
| `ForecastRecordDTO`       | `lastModifiedDate`                   | Datetime   | Display only ("Last saved: ...")      |
| `ForecastOverrideSaveDTO` | `forceOverwrite`                     | Boolean    | Bypass conflict check on "Keep Mine"  |
| New class: `ExportResult` | `fileName`, `mimeType`, `csvContent` | String × 3 | Server-side CSV export response       |

#### 0.2 New Apex Methods

| Method                   | Signature                                                        | Effort   |
| ------------------------ | ---------------------------------------------------------------- | -------- |
| `getOpportunityForecast` | `(Id opportunityId, Id periodId) → ForecastRecordDTO`            | 0.5 day  |
| `acceptCrmValues`        | `(Id overrideId) → SaveResult`                                   | 0.25 day |
| `exportForecastData`     | `(Id periodId, Id participantId, String scopeId) → ExportResult` | 0.25 day |

#### 0.3 Conflict Detection

Modify `ForecastService.saveOverrides()`:

- Compute `dataVersion` hash from override.LastModifiedDate + pipeline.LastModifiedDate + health signal timestamp
- When `forceOverwrite != true` and sent `dataVersion` != current: return `CONFLICT:{recordId}:details`

#### 0.4 Apex Tests (14 test methods)

Per spec §18.4: `getOpportunityForecast` (4 scenarios), `acceptCrmValues` (2), `exportForecastData` (2), conflict detection (2), access rejection (2), server-side filter/sort (2).

#### 0.5 Files to Modify

- `force-app/main/default/classes/ForecastController.cls`
- `force-app/main/default/classes/ForecastService.cls`
- New: `force-app/main/default/classes/ForecastControllerTest.cls`

#### 0.6 Deploy & Validate

Deploy to REVT org. Run all Apex tests. Confirm 75%+ coverage on new methods.

---

### Phase 1: Shared Primitives + Utils Module (2 days)

**No Apex calls. Pure presentation. All buildable in parallel.**

| #   | Component                | Lines | Key Detail                                                                                                                                                                                                                 |
| --- | ------------------------ | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `revtForecastUtils`      | ~150  | JS-only module (no HTML). Exports: `debounce`, `formatCurrency`, `formatPercent`, `chunkArray`, `generateCsvBlob`, `parseErrorPrefix`, `sessionStorageGet/Set`, `computeTierImpact`, `STATUS_COLORS`, `HEALTH_BAND_CONFIG` |
| 2   | `revtHealthBadge`        | ~40   | Props: `healthScore`, `healthBand`. Color-coded utility icon (like/warning/ban). `aria-label`.                                                                                                                             |
| 3   | `revtTrendArrow`         | ~30   | Props: `trend` (-1/0/+1). utility:arrowup/arrowdown/dash with CSS classes.                                                                                                                                                 |
| 4   | `revtCategoryPill`       | ~30   | Props: `label`, `color` (hex), `isTerminal`. Dynamic background-color. Strikethrough when terminal.                                                                                                                        |
| 5   | `revtInlineEstimator`    | ~100  | Props: `payoutEstimate`, `incentiveRate`, `thresholdProximity`, `tierImpact`. Formatted display. Highlight on tier-crossing.                                                                                               |
| 6   | `revtMultiSelect`        | ~200  | Props: `label`, `options`, `selectedValues`, `placeholder`. Search filter, Select All/Clear All, pills below. Click-outside via `focusout` (Locker-safe). Dispatches `change` event.                                       |
| 7   | `revtConfirmationDialog` | ~100  | Props: `title`, `message`, `confirmLabel`, `variant`. Dispatches `confirm`/`cancel` events.                                                                                                                                |

**Also create mock data files:**

- `__tests__/mockData/mockConfig.json`
- `__tests__/mockData/mockContext.json`
- `__tests__/mockData/mockRecordSet.json`
- `__tests__/mockData/mockComments.json`

**Deploy:** Batch deploy all 7 items. Smoke test each primitive on a temp harness page.

---

### Phase 2: Grid Layer (3 days)

**Depends on Phase 1.**

| #   | Component                   | Lines | Key Detail                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| --- | --------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 8   | `revtForecastCommentThread` | ~150  | Calls `getLastForecastComment` (wire) + `saveForecastComment` (imperative). Scrollable list + textarea + type selector. Dispatches `commentadded`.                                                                                                                                                                                                                                                                                                                                                                                   |
| 9   | `revtForecastRow`           | ~300  | **Most complex child.** Dynamic metric columns from `config.metrics[]`. Inline edit: `lightning-input type="number"` (metrics), `lightning-combobox` (category), `lightning-input type="date"` (close date override). Status left-border coloring. Disabled when Frozen/pendingApproval/!canEdit/isLocked. Dispatches `rowchange` + `toggleexpand`. Sub-components: HealthBadge, TrendArrow × N metrics, CategoryPill, InlineEstimator. Governance warning icon, divergence alert icon. `data-row-id`/`data-column-id` for keyboard. |
| 10  | `revtForecastTotalsRow`     | ~80   | Rollup footer from `summary.categoryTotals`. CategoryPill per category. `<tfoot>` semantics.                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 11  | `revtForecastGrid`          | ~350  | Custom HTML `<table role="grid">`. Dynamic column headers from `config.metrics[]` + fixed columns. Sort click on `<th>` → dispatches `sort` event. Pagination controls → dispatches `pagechange`. Keyboard handler: Tab/Enter/Escape/Arrow per spec §17.7. Iterates `revtForecastRow` + `revtForecastTotalsRow`.                                                                                                                                                                                                                     |
| 12  | `revtForecastFilterBar`     | ~220  | Search (300ms debounce), category/stage/health via `revtMultiSelect`, 3 checkboxes (overridden/divergent/pending), Clear All. All changes debounced 250ms. sessionStorage under `revt_forecast_filters_{periodId}_{scopeId}_{participantId}`. Budget mode: swap category labels. Dispatches `filterchange`.                                                                                                                                                                                                                          |

**Deploy:** Batch deploy all 5. Test with mock data on temp app page.

---

### Phase 3: Container Components (2.5 days)

**Depends on Phase 0 + 1 + 2. First full end-to-end test.**

| #   | Component                  | Lines | Key Detail                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --- | -------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 13  | `revtForecastSummaryPanel` | ~220  | SVG attainment ring (template-driven, Locker-safe — computed `stroke-dasharray`). Category totals table. Coverage ratio. Tier info. Budget mode: hide attainment/tier, header = "Budget".                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 14  | `revtForecastApp`          | ~450  | **State management hub.** Wire `getForecastConfig`, imperative `getParticipantContext` + `getForecastRecords`. State: `config`, `context`, `recordSet`, `allRecords`, `dirtyOverrides` (Map), `rowDataVersionMap` (Map), `rowErrorMap` (Map), `isLoading`, `isSaving`, `isLocked`, drill-in breadcrumbs. **Toolbar:** period picker, scope picker, currency toggle (client-side column swap), Save (chunk at 50 + confirmation dialog), Submit (save-first then single call), Freeze (single server call + warning dialog), Copy dropdown (level/period × overwrite/merge/skip), CSV (client ≤500 / server >500). **Routing:** `filterchange` → client JS or server call. `rowchange` → update dirtyOverrides. `sort`/`pagechange` → client or server. **Drill-in:** owner click → push breadcrumb, `getParticipantContextForUser`. **Errors:** `parseErrorPrefix` → conflict dialog, row error, permission toast, generic toast. **UI lock:** `isLocked = true` during all async mutations. |

**Also create:**

- Lightning App Page FlexiPage XML
- Lightning Tab metadata

**Deploy + first real end-to-end test with live Apex data.**

---

### Phase 4: Opportunity Record Page (1.5 days)

**Can run in parallel with Phase 3.** Only depends on Phase 0 + Phase 1 + `revtForecastCommentThread` from Phase 2.

| #   | Component                 | Lines | Key Detail                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| --- | ------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 15  | `revtOpportunityForecast` | ~350  | **`lightning__RecordPage` target, Opportunity only.** `@api recordId`. Calls `getOpportunityForecast` (dedicated single-record method). Period selector combobox. Inline edit: category, metrics, close date override. CRM values section (read-only). Divergence alert: "Accept CRM Values" (`acceptCrmValues`) / "Keep Override". Save/Submit single-item. Read-only when: Frozen, no participant, pendingApproval, out of scope. Design params: `showComments`, `showIncentiveEstimate`, `showHealthScore`. |

**Deploy separately + test by adding to Opportunity FlexiPage via App Builder.**

---

### Phase 5: Polish & Validation (2 days)

| Task                              | Duration | Detail                                                                                                                                     |
| --------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Integration tests                 | 0.5 day  | 60-row save chunking, conflict detection, drill-in + filter isolation, budget mode toggle, currency toggle persistence                     |
| Accessibility audit               | 0.25 day | aria-label, role="grid", aria-sort, keyboard nav (full grid traverse), color contrast (WCAG AA)                                            |
| Managed package compliance        | 0.25 day | No `document.querySelector`. Namespace-safe imports (`@salesforce/apex/ForecastController.*`). `sf package version create --validate-only` |
| Performance validation            | 0.5 day  | <2s initial load, <100ms client filter, <3s save 50 records, test 500-record boundary (client→server switch)                               |
| Jest test finalization            | 0.25 day | Ensure all mock data files complete. Run `npx sfdx-lwc-jest --coverage`.                                                                   |
| Final deploy + package validation | 0.25 day | Full source deploy. All Apex tests pass. `sf package version create` beta validation.                                                      |

---

## 3. Dependency Graph

```
Phase 0 (Apex)
    │
    ├──→ Phase 1 (Shared Primitives)
    │        │
    │        └──→ Phase 2 (Grid Layer)
    │                 │
    │                 ├──→ Phase 3 (Containers) ──→ Phase 5 (Polish)
    │                 │
    │                 └──→ Phase 4 (Opp Record Page) ──→ Phase 5
    │
    └──→ Phase 4 (needs getOpportunityForecast method)
```

**Critical path (serial):** Phase 0 → 1 → 2 → 3 → 5 = 11 days  
**With 2 devs:** Phase 4 overlaps Phase 3. Shared primitives split across 2 devs. = ~9 days

---

## 4. Parallel Developer Split

| Day  | Dev A                                                                               | Dev B                                                |
| ---- | ----------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 1-2  | Phase 0: Apex methods + DTOs + tests                                                | Phase 0: Conflict detection + test data factory      |
| 2-3  | Phase 1: HealthBadge, TrendArrow, CategoryPill, InlineEstimator, ConfirmationDialog | Phase 1: MultiSelect, ForecastUtils, mock data files |
| 4    | Phase 2: ForecastRow                                                                | Phase 2: CommentThread, FilterBar                    |
| 5-6  | Phase 2: ForecastGrid, TotalsRow                                                    | Phase 2: FilterBar (cont.), jest tests               |
| 6-7  | Phase 3: ForecastApp (toolbar, state)                                               | Phase 3: SummaryPanel                                |
| 7-8  | Phase 3: ForecastApp (save/submit/freeze, drill-in, errors)                         | Phase 4: OpportunityForecast                         |
| 8-9  | Phase 3: ForecastApp (filter routing, CSV), FlexiPage                               | Phase 4: OpportunityForecast (divergence, tests)     |
| 9-10 | Phase 5: Integration tests, performance                                             | Phase 5: Accessibility, package compliance           |

---

## 5. Key Technical Decisions

| Decision                    | Choice                                                  | Rationale                                                                                        |
| --------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Table implementation        | Custom HTML `<table>`                                   | `lightning-datatable` doesn't support inline comboboxes, expandable rows, or color-coded borders |
| Apex import path            | `@salesforce/apex/ForecastController.getForecastConfig` | In 1GP, namespace prefix is implicit — no `REVT.` prefix needed                                  |
| SVG attainment ring         | Template-driven with computed `stroke-dasharray`        | `lwc:dom="manual"` not allowed in managed packages                                               |
| Click-outside (MultiSelect) | `focusout` + `relatedTarget` check                      | `document.addEventListener('click')` blocked by Locker Service                                   |
| sessionStorage              | try/catch wrappers                                      | Locker Service wraps sessionStorage but access can fail in embedded contexts                     |
| API version                 | 62.0                                                    | Per `sfdx-project.json`                                                                          |

---

## 6. Risk Mitigations

| Risk                                    | Mitigation                                                                                                                                                                                                          |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Namespace resolution for Apex imports   | Test first wire adapter import in Phase 1 with throwaway component before building 14 components                                                                                                                    |
| Custom table accessibility compliance   | Use `role="grid"`, `role="row"`, `role="gridcell"` from day one — do not retrofit                                                                                                                                   |
| Save governor limits on large edits     | Chunking at 50 enforced in LWC. Progress indicator during multi-batch saves.                                                                                                                                        |
| sessionStorage in Locker Service        | Utility wrappers with graceful degradation (filters work without persistence)                                                                                                                                       |
| SVG in managed package                  | Avoid `lwc:dom="manual"` — use template expressions for all dynamic SVG attributes                                                                                                                                  |
| revtForecastRow complexity (~300 lines) | Split into sub-sections: editable section, readonly section, expand section. Each section is a template `if:true` block, not a separate component (avoids event bubbling overhead for 40+ rows × 3 sub-components). |

---

## 7. Component File Structure

```
force-app/main/default/lwc/
├── revtForecastUtils/           (Phase 1 — JS only, no HTML)
├── revtHealthBadge/             (Phase 1)
├── revtTrendArrow/              (Phase 1)
├── revtCategoryPill/            (Phase 1)
├── revtInlineEstimator/         (Phase 1)
├── revtMultiSelect/             (Phase 1)
├── revtConfirmationDialog/      (Phase 1)
├── revtForecastCommentThread/   (Phase 2)
├── revtForecastRow/             (Phase 2)
├── revtForecastTotalsRow/       (Phase 2)
├── revtForecastGrid/            (Phase 2)
├── revtForecastFilterBar/       (Phase 2)
├── revtForecastSummaryPanel/    (Phase 3)
├── revtForecastApp/             (Phase 3)
├── revtOpportunityForecast/     (Phase 4)
└── __tests__/
    └── mockData/                (Phase 1)
        ├── mockConfig.json
        ├── mockContext.json
        ├── mockRecordSet.json
        └── mockComments.json
```

---

## 8. Verification Checkpoints

| Phase | Verification                                                                                                                                                            |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0     | `sf project deploy start` — zero errors. All 14 Apex tests pass. 75%+ coverage on new methods.                                                                          |
| 1     | `sf project deploy start --source-dir force-app/main/default/lwc` — zero errors. `npx sfdx-lwc-jest` — all tests pass. Smoke test: each primitive renders on temp page. |
| 2     | Deploy + jest pass. Grid renders with mock data. Editable cells accept input. Filters dispatch events.                                                                  |
| 3     | **First end-to-end test.** App loads config + context + records from live Apex. Save/submit work. Filter routing (client vs server) works. Drill-in navigates.          |
| 4     | Component renders on Opportunity page. Single-record load works. Save/submit work. Divergence alert appears for modified CRM records.                                   |
| 5     | `sf package version create --validate-only` passes. Performance targets met. Accessibility scanner clean.                                                               |

---

_Forecasting LWC Implementation Plan V1.0 — April 14, 2026_  
_5 phases. 14 LWC components + 1 utils module + 3 Apex methods. ~2,620 lines of LWC._  
_Phase 0 (Apex) → Phase 1 (Primitives) → Phase 2 (Grid) → Phase 3 (Containers) → Phase 4 (Opp Page) → Phase 5 (Polish)._
