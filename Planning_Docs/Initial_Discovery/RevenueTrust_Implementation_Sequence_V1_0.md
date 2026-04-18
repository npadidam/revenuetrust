# RevenueTrust — Implementation Sequence V1.0

## Week-by-Week Build Plan — Phase 1

**Timeline:** 10 weeks to pilot-ready (8 weeks core + 2 weeks adapters/polish)  
**Builder:** Solo founder + Claude Code  
**Platform:** Salesforce 2GP Managed Package (LWC + Apex)  
**Spec Reference:** UNIFIED_PLATFORM_SPEC.md V3.0  
**Date:** April 2, 2026

---

## Architectural Decision Record

Before the week-by-week sequence, these decisions are locked:

| ID       | Decision                                                                                                                                                                                                                                                           | Rationale                                                                                                                                                       |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AD-1** | All commission calculations triggered by customer-org events execute via Platform Events in isolated transaction contexts. Direct synchronous processing is used only for events on managed package objects.                                                       | Decouples from customer org automation chaos. Fresh governor limits per event context. Retry resilience on failure.                                             |
| **AD-2** | 2GP managed package (Second-Generation Packaging).                                                                                                                                                                                                                 | Better namespace isolation, scratch org development, CI/CD-friendly, required for modern AppExchange strategy.                                                  |
| **AD-3** | LWC only. Zero Aura, zero Visualforce for any new work.                                                                                                                                                                                                            | Salesforce's forward direction. Aura is deprecated. LWC ports cleanly to React in Phase 3.                                                                      |
| **AD-4** | Platform Event types defined in managed package namespace: `RevenueTrust__Commission_Event__e`, `RevenueTrust__Governance_Event__e`, `RevenueTrust__Signal_Event__e`.                                                                                              | Package-namespaced events don't pollute customer org event limits. Full control over schema.                                                                    |
| **AD-5** | Health Score Profile stored as Custom Metadata Type (`Deal_Health_Profile__mdt`), not custom object.                                                                                                                                                               | Custom Metadata Types are deployable, packageable, and don't count against customer org object limits. Configuration data belongs in metadata.                  |
| **AD-6** | Governance Rule Configuration stored as Custom Metadata Type (`Governance_Rule__mdt`).                                                                                                                                                                             | Same rationale as AD-5. Governance rules are configuration, not transactional data. Admins configure via metadata, not record CRUD.                             |
| **AD-7** | Signal Adapter interface defined as Apex virtual class with abstract methods. Built-in adapters extend it. Custom adapters extend it.                                                                                                                              | Extensible without code changes to scoring engine. Clean separation of signal acquisition from score calculation.                                               |
| **AD-8** | Inline Incentive Estimator calculations run client-side in LWC using cached plan data, NOT via Apex callout per keystroke. Plan data loaded once on page load, recalculated in JavaScript on every field change. Apex called only on Save to persist and validate. | Eliminates server round-trips for the <500ms estimator requirement. Plan data (rate tiers, attainment, thresholds) is small enough to cache in component state. |

---

## Pre-Work (Days 1-3, before Week 1 starts)

**Actions — do these before writing any code:**

- [ ] Register ISV Partner Program with Salesforce (starts AppExchange security review pipeline — 4-8 week external dependency)
- [ ] Create 2GP packaging org and Dev Hub setup
- [ ] Purchase `revenuetrust.ai` domain (check `.com` too)
- [ ] Create Salesforce scratch org definition file with all required features (Platform Events, Custom Metadata, LWC)
- [ ] Set up Git repository with 2GP project structure: `force-app/main/default/` standard layout
- [ ] Create Makefile for scratch org creation, push, test, package version creation
- [ ] Port existing Temenos Apex controllers into the repo (raw, before refactoring)
- [ ] Port existing Kony commission Apex classes into the repo (raw, before refactoring)

**Exit criteria:** Scratch org spins up, existing Apex compiles (even if not yet refactored), Git repo has CI pipeline stub.

---

## Week 1 — Foundation Layer: Data Model + Platform Events + Core Apex

**Goal:** All custom objects deployed. Platform Event infrastructure working. Commission calculation engine refactored and passing tests.

### Day 1-2: Custom Objects & Metadata Types

Deploy via Flyway-equivalent (Salesforce metadata API push) all Phase 1 objects:

**Forecasting objects (from Temenos — already exist, refactor field names to namespace):**

- `Forecast__c` (Forecast Period)
- `Forecast_Override__c` (with self-referential lookups: `Previous_Level_Forecast_Override__c`, `Previous_Forecast_Override__c`)
- `Forecast_User__c` (Forecast Participant)
- `Forecast_Comment__c` (Historical Notes)

**Incentive objects (from Kony — already exist, refactor field names to namespace):**

- `Comp_Plan__c` (Incentive Plan)
- `Comp_Calculation__c` (Incentive Calculation — the immutable ledger)
- `Commission_Draw__c` (Draw Record)
- `Payment_Detail__c` (Payment Record)
- `Commission_Tier__c` (Rate Tier — NEW, not in Kony original)
- `Commissionable_Pct__c` (Commissionable Percentage)
- `Additional_Eligibility__c` (Additional Participant Eligibility)

**Deal Health objects (NEW):**

- `Deal_Signal__c` (Pipeline Signal — canonical signal store)
- `Deal_Signal_History__c` (Signal Change History — audit trail)
- `Deal_Health_Profile__mdt` (Health Score Profile — Custom Metadata Type, AD-5)

**Cross-module objects (NEW):**

- `Governance_Event__c` (Governance Event — audit trail for CG-1 through CG-7)
- `Governance_Rule__mdt` (Governance Rule Configuration — Custom Metadata Type, AD-6)
- `Behavioral_Flag__c` (Behavioral Flag — sandbagging/optimism flags)
- `Manager_Accuracy__c` (Manager Accuracy — stats per manager)
- `Incentive_Dispute__c` (Dispute records)

**Territory (NEW):**

- `Territory__c` (Territory/Scope)

### Day 2-3: Platform Events

Define and deploy three Platform Event types (AD-4):

```
RevenueTrust__Commission_Event__e
  - Opportunity_Id__c (Text)
  - Event_Type__c (Text: DEAL_CLOSED, AMOUNT_CHANGED, STAGE_CHANGED, CATEGORY_CHANGED)
  - Previous_Value__c (Text — JSON of prior state)
  - New_Value__c (Text — JSON of new state)
  - User_Id__c (Text)
  - Timestamp__c (DateTime)

RevenueTrust__Governance_Event__e
  - Forecast_Override_Id__c (Text)
  - Rule_Id__c (Text: CG-1, CG-2, etc.)
  - Participant_Id__c (Text)
  - Compensation_Context__c (LongTextArea — JSON: attainment, tier, threshold, payout delta)
  - Action_Type__c (Text: REQUIRE_JUSTIFICATION, REQUIRE_APPROVAL, ESCALATE, ALERT, WARN, BADGE)

RevenueTrust__Signal_Event__e
  - Opportunity_Id__c (Text)
  - Signal_Source__c (Text: CRM, GONG, MOMENTUM, etc.)
  - Signal_Data__c (LongTextArea — JSON of normalized signals)
```

Build the Platform Event publisher utility class (reusable across all modules).
Build the three Platform Event trigger handlers (stubs — implementation filled in later weeks).

### Day 3-5: Commission Calculation Engine Refactor

Port the Kony `CommissionsProcessFY19.cls` (~1,200 lines) into a refactored, namespaced structure:

```
RevenueTrust__CommissionService.cls
  ├── identifyParticipants(opportunityId) → List<ParticipantEligibility>
  ├── resolveActivePlans(participantId, transactionDate) → List<CompPlan>
  ├── computeCommissionableValue(opportunity, plan) → Decimal
  ├── applyRateStructure(commissionableValue, plan, currentAttainment) → List<CalcResult>
  ├── applyModifiers(calcResults, plan) → List<CalcResult>
  └── persistCalculations(calcResults) → void

RevenueTrust__CommissionEventHandler.cls (Platform Event trigger handler)
  └── onCommissionEvent(List<RevenueTrust__Commission_Event__e>) → void
       → calls CommissionService for each event in isolated context

RevenueTrust__IncentiveImpactCalculator.cls
  └── calculateImpact(opportunityId, participantId) → ImpactResult
       → real-time estimator: current attainment, proposed attainment, rate tier, payout delta, threshold proximity
       → this is the engine behind the inline estimator (§3.3.5) and governance rules (§7.3.4)
```

Write Apex tests targeting 90%+ coverage on CommissionService. Claude Code generates test data factories and assertion scaffolding.

### Day 5: Opportunity Trigger → Platform Event Publisher

Lightweight trigger on Opportunity that publishes `RevenueTrust__Commission_Event__e`:

```apex
trigger RevenueTrust_OpportunityTrigger on Opportunity (after update) {
    List<RevenueTrust__Commission_Event__e> events = new List<>();
    for (Opportunity opp : Trigger.new) {
        Opportunity old = Trigger.oldMap.get(opp.Id);
        if (opp.StageName != old.StageName && opp.StageName == 'Closed Won') {
            events.add(new RevenueTrust__Commission_Event__e(
                Opportunity_Id__c = opp.Id,
                Event_Type__c = 'DEAL_CLOSED',
                // ... other fields
            ));
        }
        // Similar for amount change, stage change, close date change
    }
    if (!events.isEmpty()) {
        EventBus.publish(events);
    }
}
```

This is the ONLY code that runs in the customer's transaction context (AD-1). Everything else fires asynchronously.

**Week 1 Exit Criteria:**

- All custom objects deployed to scratch org
- Platform Events defined and publishing
- Commission calculation engine compiles, passes 90%+ test coverage
- Single deal close → Platform Event → commission calculated → Comp_Calculation\_\_c records created (end-to-end verified)

---

## Week 2 — Forecasting Module: Apex Controllers + LWC Manager View

**Goal:** Forecasting grid renders with real data. Save/Submit/Freeze work. Manager View functional.

### Day 1-2: Forecast Apex Controllers (port from Temenos)

Port `SL_OpportunityForecastCtrl.cls` into namespaced, refactored structure:

```
RevenueTrust__ForecastController.cls (@AuraEnabled methods)
  ├── getFilteredForecast(userId) → ForecastContext (periods, territories, user level)
  ├── getForecastRecords(forecastId, territoryId) → List<ForecastOverrideDTO>
  ├── saveForecastData(overrides, isPartial) → SaveResult
  ├── submitForecastData(overrides, isPartial) → SubmitResult
  ├── freezeForecastData(forecastId, territoryId) → FreezeResult
  ├── copyFromPreviousLevel(forecastId, territoryId) → CopyResult
  ├── copyFromLastForecast(forecastId, territoryId) → CopyResult
  └── getLastForecastComment(opportunityId, userId) → List<String>
```

Key refactoring from Temenos original:

- Replace hardcoded 4-level hierarchy with `Forecast_User__c.Forecast_Level__c` integer (1-N)
- Replace hardcoded NBV/ACV with configurable metric fields from Forecast Template (or for v1, keep 2 metrics but make field references configurable via Custom Metadata)
- Replace hardcoded categories with Custom Metadata-driven picklist values
- Keep the deal-share deduplication logic at top level (this is production-proven IP)

### Day 2-4: LWC Manager View

Build the primary forecast grid as LWC:

```
revenueTrustForecastApp (container)
  ├── revenueTrustFilterPanel (multi-select filters, search, session persistence)
  ├── revenueTrustSummaryTable (quarterly rollup by category)
  ├── revenueTrustManagerView (deal table with edit, pagination, trend indicators)
  │     ├── revenueTrustDealRow (single row: read-only context + editable fields + trend arrows)
  │     │     └── revenueTrustInlineEstimator (incentive columns — Week 3 integration)
  │     └── revenueTrustNotesPanel (expandable notes per deal)
  └── revenueTrustActionBar (Save, Submit, Freeze, Copy buttons with confirmation dialogs)
```

SLDS styling throughout. Pagination at 40 records. Row color-coding (Red/Yellow/Blue/Green/DarkGrey) per status. Filter persistence in sessionStorage.

Claude Code generates LWC component scaffolding from the spec wireframes. Significant AI leverage on SLDS layout, data table rendering, and event handling boilerplate.

### Day 4-5: LWC Director View

Build as variant of Manager View with additional columns:

- Previous Level values (from `Previous_Level_Forecast_Override__c` lookup)
- Manager Notes read-only display
- Deal-share deduplication at top level

Director View is a configuration variant of Manager View, not a separate component — same `revenueTrustManagerView` component with `viewMode="director"` attribute that controls column visibility and edit permissions.

**Week 2 Exit Criteria:**

- Forecast grid renders with real Opportunity data from scratch org
- Filter panel works (client-side filtering, no server calls)
- Summary table shows quarterly rollup by category
- Save → records turn Blue, Submit → records turn Green, Freeze → records turn Dark Grey
- Copy from Previous Level works for Director+ views
- Historical notes modal opens and shows prior period comments
- 40-record pagination with "Showing X-Y of Z"

---

## Week 3 — Sales Incentives UI + Inline Estimator + Cross-Module Integration

**Goal:** Rep portal shows earnings. Admin dashboard shows all calculations. Inline Incentive Estimator appears in forecast grid. The "demo that wins" starts to take shape.

### Day 1-2: Rep Self-Service Portal (LWC)

```
revenueTrustRepPortal
  ├── revenueTrustEarningsSummary (period-to-date: earned, paid, upcoming, draw balance)
  ├── revenueTrustAttainmentGauge (visual gauge per plan per period — SVG donut chart)
  ├── revenueTrustByPlan (per-plan breakdown: quota, achieved, rate tier, earned)
  ├── revenueTrustByTransaction (per-deal earnings with calculation breakdown)
  │     └── revenueTrustCalcTrace (shows: plan name, rate tier, commissionable value, rate %, amount)
  ├── revenueTrustHeldCommissions (held calculations with hold reason and release condition)
  └── revenueTrustDisputePanel (view disputes, raise new dispute on specific calculation)
```

The `revenueTrustCalcTrace` component is critical — it's the transparency feature that directly addresses the #2 pain point across all competitor reviews ("reps can't trace why they got paid what they got paid"). Every Comp_Calculation\_\_c record has the full audit trail from Step 6 of the calculation engine.

### Day 2-3: Admin Incentive Dashboard (LWC)

```
revenueTrustAdminDashboard
  ├── revenueTrustAdminFilters (period, transaction, participant, role, category, plan, status)
  ├── revenueTrustAdminTable (configurable columns: transaction, participant, plan, rate, earnings, payment status)
  ├── revenueTrustDisputeQueue (pending disputes with one-click resolution)
  ├── revenueTrustPayrollExport (generate flat file with configurable column mapping)
  └── revenueTrustProcessingPanel (trigger monthly processing batch, view progress)
```

Monthly bulk processing runs as Batch Apex: `RevenueTrust__MonthlyProcessingBatch.cls`. Admin clicks "Process" → confirmation dialog → Batch Apex job queued → progress bar updates → completion notification.

### Day 3-4: Inline Incentive Estimator (THE KEY DIFFERENTIATOR)

Wire the `revenueTrustInlineEstimator` component into each `revenueTrustDealRow` in the forecast grid.

**Architecture (AD-8):** On forecast page load, a single Apex call loads the current user's (or viewed participant's) active plan data: rate tiers, current attainment, quota, threshold boundaries. This data is cached in the parent LWC component's state (~2-5 KB per participant).

When the manager edits a deal's metric value or category, the `revenueTrustInlineEstimator` recalculates entirely in JavaScript:

```javascript
// Client-side calculation — no server round-trip
calculateEstimate(dealValue, currentAttainment, planData) {
    const projectedAttainment = currentAttainment + dealValue;
    const currentTier = this.findTier(currentAttainment, planData.tiers);
    const projectedTier = this.findTier(projectedAttainment, planData.tiers);
    const payoutEstimate = dealValue * currentTier.rate;
    const thresholdProximity = planData.tiers
        .filter(t => t.min > currentAttainment)
        .map(t => ({ name: t.name, distance: t.min - currentAttainment, rate: t.rate }));
    const tierImpact = (projectedTier.name !== currentTier.name)
        ? `Crosses → ${projectedTier.name} (+${projectedTier.rate - currentTier.rate}% on all)`
        : 'No tier change';

    return { payoutEstimate, thresholdProximity, tierImpact, currentTier, projectedTier };
}
```

Columns displayed: Incentive Rate | Payout Estimate | Threshold Proximity | Tier Impact | Governance Flag.
Recalculates on every keystroke (debounced 200ms). Zero server calls. <500ms guaranteed.

Tooltip on Payout Estimate hover shows full trace: plan name, rate tier, commissionable value formula, attainment context.

### Day 5: What-If Simulator (Rep Portal)

Add a "What If" tab to the rep portal. Rep enters a hypothetical deal (amount, category, close date). System calculates: if this deal closes, what's my new attainment? What tier do I land in? What do I earn on this deal? What's the retroactive impact on all prior deals this period?

Uses the same client-side `calculateEstimate` logic as the inline estimator, but with a user-provided hypothetical input instead of a real deal row.

**Week 3 Exit Criteria:**

- Rep portal shows earnings with full per-deal calculation trace
- Admin dashboard shows all calculations with filtering and CSV export
- Monthly batch processing works end-to-end
- Inline Incentive Estimator columns visible in forecast grid: rate, payout estimate, threshold proximity, tier impact
- Manager changes a deal value → estimator columns update in <500ms with no page refresh
- What-if simulator in rep portal returns projected earnings for hypothetical deal
- Dispute workflow: rep raises dispute → admin sees in queue → admin resolves → rep notified

---

## Week 4 — Governance Engine + Deal Health Score

**Goal:** Comp-aware governance rules fire in real time. Deal health scores calculated from CRM data. Conflict alerts working. This is the week the product becomes something no competitor can match.

### Day 1-3: Governance Trigger Engine (§7.3)

Build `RevenueTrust__GovernanceEngine.cls`:

```apex
public class RevenueTrust__GovernanceEngine {

    // Called synchronously on Forecast_Override__c save (our object — safe to run in trigger)
    public static List<GovernanceEvent> evaluate(
        Forecast_Override__c override,
        Forecast_Override__c previousVersion
    ) {
        List<GovernanceEvent> events = new List<GovernanceEvent>();

        // Load participant's compensation context (cached per page session)
        IncentiveContext ctx = IncentiveImpactCalculator.getContext(override.User__c);
        ImpactResult impact = IncentiveImpactCalculator.calculateImpact(
            override.Opportunity__c, override.User__c
        );

        // Load active governance rules from Custom Metadata
        List<Governance_Rule__mdt> rules = GovernanceRuleLoader.getActiveRules();

        for (Governance_Rule__mdt rule : rules) {
            GovernanceEvent event = evaluateRule(rule, override, previousVersion, ctx, impact);
            if (event != null) events.add(event);
        }

        return events;
    }
}
```

Implement rules CG-1 through CG-7 (each as a method in the engine):

**CG-1:** Category moved to high-confidence AND payout increase > threshold% → Require justification note
**CG-2:** Category moved to high-confidence AND participant within threshold% of rate tier → Escalate to reviewer
**CG-3:** Close date pulled to current period AND crossing tier threshold → Require reviewer approval
**CG-4:** Close date pushed to next period AND above quota AND health ≥ threshold → Flag sandbagging
**CG-5:** Scope-level submitted forecast × rates exceeds budget threshold → Warn reviewer
**CG-6:** ≥3 participants on same plan make high-confidence moves within window near same tier → Alert Sales Ops
**CG-7:** Override value differs from previous level by > threshold% AND incentive on delta exceeds amount → Attach incentive impact badge

Wire the governance engine to the `Forecast_Override__c` before-save trigger. Since `Forecast_Override__c` is YOUR managed package object, synchronous execution is safe (AD-1).

For CG-3 (require reviewer approval — hard block), implement a `Pending_Approval__c` checkbox on Forecast_Override**c. When CG-3 fires, the override is saved with `Pending_Approval**c = true` and the field change is not committed until the reviewer approves via the Governance Queue.

### Day 3-4: Deal Health Score — CRM-Only Calculation

Build `RevenueTrust__HealthScoreCalculator.cls`:

For v1, calculate health score from CRM data only (no external adapters):

```
Activity Recency (40% weight in CRM-only mode — redistributed from missing Conversation Intelligence):
  → days since last Activity on the Opportunity (Task/Event query)
  → 0-3 days: 100 | 4-7: 85 | 8-14: 65 | 15-21: 45 | 22-30: 25 | >30: 10

Stage Progression (30% weight — replaces Relationship Score in CRM-only mode):
  → is the stage moving forward, stalled, or regressing?
  → Forward movement in last 14 days: 90 | Stalled 14-30 days: 50 | Regressed: 20 | Stalled >30: 10

Deal Momentum (30% weight — replaces Engagement Depth in CRM-only mode):
  → close date stability (has it slipped?)
  → slipped 0 times: 100 | 1 slip: 70 | 2 slips: 40 | 3+: 15
  → deal age vs. stage benchmark (is this deal moving at normal speed?)
```

Adjustment rules (CRM-only set):

- Close date in past but not Closed Won: −20
- No activities in 30+ days: −15
- Stage regressed: −10
- Amount increased >20% in last 14 days: +5

Score persisted on `Deal_Signal__c` linked to Opportunity. Score card displays with full component breakdown.

Build `revenueTrustHealthBadge` LWC component: 🟢 (≥70) · 🟡 (40-69) · 🔴 (<40). Clickable to expand score card panel.

### Day 4-5: Conflict Alert + Score Badge in Forecast Grid

Wire health badge into the forecast grid `revenueTrustDealRow`:

- Health score column shows badge
- When manager selects high-confidence category (Commit/Best Case) AND health score < 40: show inline conflict alert banner

Build `revenueTrustConflictAlert` LWC component:

> **Signal Conflict:** This record is scored 34 (At Risk). Manager has categorized as Commit. Consider moving to Pipeline.

Alert is dismissible per deal per period. Dismissal reason logged in `Governance_Event__c`.

**Week 4 Exit Criteria:**

- Governance rules CG-1 through CG-7 fire correctly on forecast override actions
- CG-2 demo: Manager moves deal to Commit while participant is near accelerator threshold → escalation appears in governance queue with full compensation context
- CG-4 demo: Manager pushes healthy deal to next period while above quota → sandbagging flag in reviewer view
- Deal health scores calculated from CRM data for all active opportunities
- Health badges visible in forecast grid
- Conflict alert fires when high-confidence category + low health score
- Governance events logged in `Governance_Event__c` with full audit trail

---

## Week 5 — Manager Decision Cockpit

**Goal:** The one-screen view that eliminates tool-switching. This is the "demo that wins" feature.

### Day 1-2: Cockpit Layout (§11.5)

Build `revenueTrustCockpit` as the primary LWC container:

```
revenueTrustCockpit
  ├── revenueTrustCockpitSummary (left panel: target, committed, best case, pipeline, coverage, AI predicted row stub)
  ├── revenueTrustGovernanceQueue (right panel: active governance events for this scope/period)
  │     └── revenueTrustGovernanceCard (per-event: rule ID, participant, deal, compensation context, action buttons)
  ├── revenueTrustCockpitPipeline (main panel: pipeline records table with all columns)
  │     └── revenueTrustDealRow (reused from Week 2 — with inline estimator from Week 3 + health badge from Week 4)
  └── revenueTrustCockpitDetail (bottom panel: expands on row click)
        ├── revenueTrustHealthScoreCard (§5.5 breakdown — from Week 4)
        ├── revenueTrustIncentiveTrace (plan, rate, attainment, threshold, projection)
        ├── revenueTrustOverrideAudit (chronological: who changed what, when, why)
        └── revenueTrustSignalTrail (chronological: signal events from CRM — adapter events later)
```

### Day 2-3: Governance Queue Interaction

The Governance Queue panel shows active `Governance_Event__c` records for the current scope/period. Each card shows:

- Rule ID and severity icon (⚠ High, ℹ Info)
- Participant name + deal name
- One-line compensation context ("$42K from Accelerator tier")
- Action buttons: Approve | Deny | Dismiss with Note

Clicking a governance card highlights the corresponding deal row in the pipeline table and expands the detail panel. This is the critical UX flow — the reviewer sees the flag, clicks it, sees the full incentive trace + health score + override history for that deal, and makes an informed governance decision without leaving the screen.

Approve/Deny/Dismiss actions update the `Governance_Event__c` record and refresh the queue. For CG-3 (hard block), Approve releases the `Pending_Approval__c` flag on the Forecast_Override\_\_c.

### Day 3-4: Incentive Trace Panel

Build `revenueTrustIncentiveTrace` showing:

- Active plan name and fiscal period
- Current rate tier and rate %
- Current attainment (absolute and %)
- Distance to next tier threshold (absolute and %)
- "If this deal closes" projection: new attainment, new tier (if crossing), payout on this deal, retroactive payout delta on prior deals
- Link to full calculation history in rep portal

This reuses the `IncentiveImpactCalculator` from Week 3, formatted for the detail panel layout.

### Day 4-5: Override Audit Trail Panel + Signal Trail Panel

**Override Audit Trail:** Query `Forecast_Override__c` history + `Forecast_Comment__c` records for the selected deal. Display chronologically: L1 override $400K (Apr 2) → L2 override $420K (Apr 3) → Category: Pipeline→Commit changed Apr 2 by J.Smith → Note: "Legal signed Apr 1".

**Signal Trail:** Query `Deal_Signal_History__c` records for the selected deal. Display chronologically: Health score 68→82 (Apr 1) — Stage advanced. Activity logged (Mar 30) — Call with VP. Close date stable for 14 days.

Both panels are read-only displays. Data is already being written by earlier weeks' implementations.

**Week 5 Exit Criteria:**

- Full Manager Decision Cockpit renders: Summary + Governance Queue + Pipeline + Detail
- Clicking a governance card → deal row highlighted → detail panel expands with health score + incentive trace + override audit
- Governance actions (Approve/Deny/Dismiss) work end-to-end
- The full demo flow works: Manager changes deal category → governance rule fires → flag appears in reviewer's cockpit → reviewer clicks flag → sees full compensation context + health signals + history → makes informed decision
- This is the first internal demo milestone. Record a video.

---

## Week 6 — Notifications + Plan Acceptance + Dispute Workflow + Polish

**Goal:** Close the operational loops. Notifications drive action. Plans are signed. Disputes are resolved.

### Day 1-2: Notification Framework

Build `RevenueTrust__NotificationService.cls`:

```apex
public class RevenueTrust__NotificationService {
  public static void notify(
    NotificationType type,
    Id recipientId,
    Map<String, String> context
  ) {
    // Route to appropriate channel based on type + user preference
    sendInApp(type, recipientId, context); // Always
    if (isSlackEnabled())
      sendSlack(type, recipientId, context); // If configured
  }
}
```

Implement notifications for (in-app first, Slack in Week 8):

- Forecast period opens → all participants
- Level N submits → Level N+1 reviewer
- Freeze → all participants in scope
- Commission calculated → participant
- Commission paid → participant
- Dispute created → admin
- Dispute resolved → participant
- Governance rule triggered → reviewer
- Governance approval required → reviewer (urgent)
- Forecast category changed → manager of deal owner
- Close date moved → manager + reviewer

In-app notifications use Salesforce Custom Notifications (Lightning-compatible, mobile-friendly, bell icon).

### Day 2-3: Plan Acceptance Workflow

Build `revenueTrustPlanAcceptance` LWC:

- Admin publishes plan → system identifies all assigned participants
- Notification sent to each participant
- Participant opens plan details in rep portal
- Click-to-accept with audit log (timestamp, IP, user ID)
- Acceptance status visible in admin dashboard per participant
- Soft gate (default): processing proceeds but admin sees unsigned plans flagged
- Hard gate (configurable): processing blocked until signed

For v1, use click-to-accept (in-platform). eSignature integration (DocuSign/AdobeSign) is a post-pilot addition.

### Day 3-4: Dispute Workflow Completion

Enhance the dispute flow from Week 3:

- Rep flags specific `Comp_Calculation__c` record → provides reason + expected amount
- System creates `Incentive_Dispute__c` linked to the calculation
- Admin notification (in-app + email)
- Admin reviews in Dispute Queue: sees calculation inputs, audit trail, plan rules
- Admin responds: explanation only OR correction (creates adjustment Comp_Calculation\_\_c)
- Resolution stored on dispute record; rep notified
- Dispute rate tracked per plan as quality metric (shown in admin dashboard)

### Day 4-5: UI Polish Pass

- Ensure all confirmation dialogs work consistently (Save, Submit, Freeze, Copy, Process)
- Toast notifications (green success, red error) on all actions
- Loading spinners on all async operations
- Keyboard navigation basics in cockpit (Tab through deals, Enter to expand)
- Export buttons on all tables (CSV)
- Responsive layout check (cockpit should work on 1440px+ screens)

**Week 6 Exit Criteria:**

- Notifications fire for all configured events (in-app)
- Plan acceptance flow works end-to-end
- Dispute workflow complete: raise → review → resolve → notify
- All UI interactions polished with proper loading states, confirmations, and error handling
- Second demo milestone. Record updated video showing full operational flow.

---

## Week 7 — Signal Adapter Architecture + CRM Adapter + Health Score Enrichment

**Goal:** Signal Adapter interface built. CRM adapter providing enriched health scores. Gong adapter stubbed. Architecture ready for any future adapter.

### Day 1-2: Signal Adapter Interface (AD-7)

Build the abstract adapter class:

```apex
public abstract class RevenueTrust__SignalAdapter {
  public abstract String getAdapterName();
  public abstract SignalResult getHealthSignal(Id opportunityId);
  public abstract RelationshipSignals getRelationshipSignals(Id opportunityId);
  public abstract ActivitySignals getActivitySignals(Id opportunityId);
  public abstract EngagementSignals getEngagementSignals(Id opportunityId);
  public abstract AdjustmentSignals getAdjustmentSignals(Id opportunityId);
  public abstract SyncStatus getSyncStatus();
}
```

Build `RevenueTrust__SignalAdapterRegistry.cls` — a registry that manages active adapters per org. Adapters register via Custom Metadata (`Signal_Adapter_Registration__mdt`).

Build `RevenueTrust__SignalOrchestrator.cls` — queries all active adapters for an opportunity, normalizes results into canonical `Deal_Signal__c` fields, applies priority ordering when multiple adapters provide the same signal type.

### Day 2-3: CRM Adapter (Built-in, always active)

Build `RevenueTrust__CrmSignalAdapter.cls extends SignalAdapter`:

This adapter queries standard Salesforce data to produce health signals:

```
Activity signals: Task/Event records linked to Opportunity → last_mutual_activity_date, interaction_count_30d
Stage signals: Opportunity.StageName history → stage_progression_direction, days_in_current_stage
Close date signals: Opportunity.CloseDate change tracking → slip_count, days_since_last_slip
Amount signals: Opportunity.Amount history → amount_trend_direction, amount_change_pct
Contact signals: OpportunityContactRole count → stakeholder_count, has_decision_maker_role
```

This replaces the basic CRM-only calculation from Week 4 with a proper adapter-based architecture. The health score engine now calls `SignalOrchestrator.getSignals(opportunityId)` which routes to all active adapters — currently just CRM, but architecturally ready for Gong/Momentum/etc.

### Day 3-4: Enhanced Health Score Calculation

Refactor `RevenueTrust__HealthScoreCalculator.cls` to use the Signal Adapter output:

```
Four components (weights redistributed when adapters missing):
  Conversation Intelligence: 40% → MISSING (no CI adapter) → redistributed
  Relationship Score:        25% → CRM proxy: contact role diversity + response patterns
  Activity Recency:          20% → CRM: Task/Event recency
  Engagement Depth:          15% → CRM: meeting count + multi-threading

Effective weights (CRM-only mode):
  Relationship: 25/60 × 100 = 41.7%
  Activity:     20/60 × 100 = 33.3%
  Engagement:   15/60 × 100 = 25.0%

Score card explicitly shows: "Conversation Intelligence not connected — weights redistributed"
```

Implement missing signal redistribution (§5.4) properly. Score card shows which components are live vs. estimated.

### Day 4-5: Gong Adapter Stub + Webhook Receiver

Build `RevenueTrust__GongSignalAdapter.cls extends SignalAdapter`:

- Stub implementation that returns null (adapter registered but not connected)
- When connected (org provides Gong API key via Named Credential):
  - Scheduled batch: daily full sync of deal risk scores for active opportunities
  - Webhook receiver: Apex REST endpoint that receives Gong post-call events
  - Maps Gong risk score (inverted: 100 − gong_risk = health), engagement score, call sentiment, competitor mentions, next step confirmed

Do NOT spend time on full Gong integration testing this week. Build the adapter, write unit tests with mocked responses, and move on. Live Gong testing happens in Week 9 with a real customer sandbox.

**Week 7 Exit Criteria:**

- Signal Adapter interface and registry working
- CRM adapter producing enriched health signals from Salesforce data
- Health scores recalculated through adapter architecture (same results, better architecture)
- Gong adapter compiles and passes unit tests with mocked data
- Score card shows "Conversation Intelligence not connected" with proper weight redistribution
- Architecture verified: adding a new adapter requires only implementing the interface + registering in metadata

---

## Week 8 — Slack Integration + Batch Jobs + Testing + First Demo Package

**Goal:** Slack notifications working. Nightly batch jobs running. Full test suite passing. First installable package version created.

### Day 1-2: Slack Integration

Build `RevenueTrust__SlackService.cls`:

- Org configures Slack webhook URL via Custom Setting (or Named Credential for Bolt API)
- Notifications routed to Slack based on type-to-channel mapping:
  - #revenue-ops-alerts: governance events, coverage gaps, anomaly alerts
  - DMs: commission notifications, forecast submission reminders, deal risk alerts
- Message formatting using Slack Block Kit JSON (interactive buttons for governance approvals)

Implement Slack delivery for the highest-value notification types:

- Governance rule triggered (CG-2 escalation, CG-4 sandbagging flag)
- Commission calculated (deal close → rep DM)
- Forecast submission reminder (deadline approaching)
- Conflict alert (high-confidence category + low health score)

### Day 2-3: Scheduled Batch Jobs

Build three scheduled Apex jobs:

**Nightly Health Score Batch:**
`RevenueTrust__HealthScoreBatch.cls implements Database.Batchable<SObject>`

- Queries all Opportunities in active forecast periods
- Runs SignalOrchestrator.getSignals() for each
- Recalculates health scores
- Creates Deal_Signal_History\_\_c records for any score changes
- Scope size: 50 records per batch chunk

**Weekly Manager Accuracy Batch:**
`RevenueTrust__ManagerAccuracyBatch.cls`

- For each manager, compares submitted forecast overrides to actual close outcomes
- Updates Manager_Accuracy\_\_c records: hit rate by category, average value accuracy, slip rate
- This is the foundation for Phase 2 manager accuracy badges

**Monthly Commission Reconciliation Batch:**
Already built in Week 3 (`RevenueTrust__MonthlyProcessingBatch.cls`). Verify it handles: hold releases, collection adjustments, cap enforcement, draw balance updates.

### Day 3-4: Test Suite Completion

Target: 90%+ Apex code coverage across all classes. Claude Code generates:

- Test data factories for all custom objects
- Positive path tests for all controller methods
- Negative path tests (validation failures, permission errors)
- Bulk tests (200+ records to verify governor limit safety)
- Platform Event tests (verify async processing)
- Governance rule tests (one test per CG rule verifying trigger conditions and generated events)

### Day 5: First Package Version

Create the first 2GP managed package version:

- `sfdx force:package:version:create` with all components
- Install in a fresh scratch org to verify clean deployment
- Run all tests in the fresh org (verifies no org-dependent assumptions)
- Document any manual post-install steps (permission set assignment, Custom Metadata seeding)

**Week 8 Exit Criteria:**

- Slack notifications fire for governance events, commission calculations, and forecast reminders
- Nightly health score batch runs successfully across 500+ opportunities
- Weekly manager accuracy batch produces correct accuracy stats
- 90%+ Apex code coverage
- First 2GP package version installs cleanly in a fresh scratch org
- All tests pass in clean org
- **This is the demoable product milestone.** Full end-to-end flow works: deal close → commission calculated → rep sees earnings → manager opens cockpit → sees deal health + incentive impact + governance flags → makes informed forecast decision → submits → reviewer sees submission with accuracy context → freezes.

---

## Week 9 — External Signal Adapters + Teams Integration

**Goal:** Gong live integration tested. Momentum adapter built. Teams notifications working. Remaining adapters stubbed.

### Day 1-2: Gong Adapter — Live Testing

Using a design partner's Gong sandbox (or Gong's developer program):

- Configure Named Credential with Gong API key
- Test daily batch sync: pull deal risk scores for all active opportunities
- Test webhook receiver: simulate post-call event → score updates in real time
- Verify score card shows Gong data: "Conversation Intelligence: 72/100 (Gong — inverted risk score: 100−28)"
- Verify weight redistribution disappears when Gong is connected (Conversation Intelligence gets its 40%)

### Day 2-3: Momentum Adapter

Build `RevenueTrust__MomentumSignalAdapter.cls`:

- Daily batch: pull relationship scores, email response times, stakeholder maps, deal velocity
- Maps to canonical signals: dm_last_response_date, champion_strength, stakeholder_count, email_response_time_hrs
- Write unit tests with mocked responses

### Day 3-4: Remaining Adapter Stubs

Build stub implementations for:

- `RevenueTrust__ZoomRASignalAdapter.cls` (Zoom Revenue Accelerator)
- `RevenueTrust__DialpadSignalAdapter.cls`
- `RevenueTrust__EmailSignalAdapter.cls` (Gmail/Outlook metadata)
- `RevenueTrust__CustomHttpSignalAdapter.cls` (generic REST adapter)

Each stub: compiles, registers in metadata, returns null when not configured, returns mock data in test context. Live integration testing deferred until customers request specific adapters.

### Day 4-5: Microsoft Teams Integration

Build `RevenueTrust__TeamsService.cls`:

- Adaptive Card formatting for notifications (richer than Slack for enterprise customers)
- Webhook-based delivery to configured Teams channels
- Same notification types as Slack
- Commission notification Adaptive Card example:
  ```json
  {
    "type": "AdaptiveCard",
    "body": [
      {
        "type": "TextBlock",
        "text": "Commission Calculated",
        "weight": "Bolder"
      },
      {
        "type": "FactSet",
        "facts": [
          { "title": "Deal", "value": "Acme Corp — Q2" },
          { "title": "Amount", "value": "$8,400" },
          { "title": "Rate", "value": "Tier 2 Accelerator (12%)" }
        ]
      }
    ]
  }
  ```

**Week 9 Exit Criteria:**

- Gong adapter tested with real (or realistic sandbox) data
- Momentum adapter built and unit-tested
- 4 additional adapters stubbed and registered
- Teams notifications working for all configured event types
- Health scores with Gong data show proper 4-component scoring (no redistribution needed)

---

## Week 10 — Hardening + Pilot Preparation + Package Finalization

**Goal:** Production-quality package. Design partner pilot kit ready. AppExchange submission in progress.

### Day 1-2: Stress Testing

- Load 500+ opportunities into scratch org with realistic data distribution
- Run full forecasting cycle: L1 save/submit → L2 review/override/submit → L3 freeze
- Verify: page load ≤5s, filter ≤1s, save ≤8s, governance evaluation ≤500ms per action
- Run commission processing for 100+ participants with diverse plans
- Verify: single deal commission <2s (Platform Event latency), monthly batch <5 minutes
- Bulk operations: Submit 200 records → verify Platform Event governance evaluation completes within 30s for all records
- Health score batch: 1000 opportunities → completes within 10 minutes

### Day 2-3: Security & Permission Hardening

- Verify all permission sets (§12.1) work correctly: Forecasting_Manager, Forecasting_Director, Forecasting_COO, Commission_Rep_Portal, Commission_Admin, Deal_Health_Viewer, Platform_Admin
- Verify data isolation: Manager cannot see other territory's deals, Rep cannot see other reps' commissions, Manager Accuracy visible only to N+2 and above
- Verify all Apex methods use `WITH SECURITY_ENFORCED` or `stripInaccessible`
- Run Salesforce Security Scanner (part of AppExchange review prep)

### Day 3-4: Pilot Kit Preparation

- Create installation guide (step-by-step for Salesforce admin)
- Create configuration guide (how to set up Forecast Template, Incentive Plans, Health Score Profile)
- Create data mapping worksheet (customer fills in their field mappings)
- Create demo script (the exact click-through flow for design partner meetings)
- Create 5-minute product video (screen recording of the full demo flow)
- Prepare sample data set that can be loaded into any Salesforce org for demo purposes

### Day 5: Final Package Version + AppExchange Submission

- Create final 2GP package version with all Week 9-10 changes
- Install in 3 separate scratch orgs to verify clean deployment
- Run full test suite in each org
- Submit to AppExchange security review (if ISV enrollment from Pre-Work is complete)
- Create unlisted package link for design partner distribution (doesn't require AppExchange approval)

**Week 10 Exit Criteria:**

- Performance targets met under realistic data volumes
- Permission sets and data isolation verified
- Package installs cleanly in fresh scratch orgs
- Pilot kit complete: installation guide, configuration guide, data mapping worksheet, demo script, video
- AppExchange security review submitted (or unlisted package link ready for design partners)
- **PILOT READY.** First design partner installation can begin Week 11.

---

## Post-Week 10: Pilot Phase (Weeks 11-14)

Not part of the build sequence, but outlined for planning:

- **Week 11:** Install in first design partner sandbox. Configure with their data. Joint walkthrough.
- **Week 12:** Design partner uses for one forecast cycle. Collect feedback daily.
- **Week 13:** Iterate on feedback. Fix bugs. Polish UX issues. Second design partner installation.
- **Week 14:** Second forecast cycle with first partner. First partner provides testimonial/case study commitment.

---

## Build Sequence Summary

| Week | Focus                     | Key Deliverable                                          | Demo Value                                               |
| ---- | ------------------------- | -------------------------------------------------------- | -------------------------------------------------------- |
| Pre  | Setup                     | Repo, scratch org, raw code ported                       | —                                                        |
| 1    | Foundation                | Data model, Platform Events, commission engine           | Commission calculates on deal close                      |
| 2    | Forecasting               | Apex controllers, LWC Manager/Director views             | Forecast grid works with real data                       |
| 3    | Incentives UI + Estimator | Rep portal, admin dashboard, inline estimator            | **Manager sees payout impact per deal in forecast grid** |
| 4    | Governance + Health       | CG-1 through CG-7, CRM health scores, conflict alerts    | **Governance flags fire with compensation context**      |
| 5    | Cockpit                   | Full Manager Decision Cockpit                            | **"Demo that wins" — one screen, no tool-switching**     |
| 6    | Operations                | Notifications, plan acceptance, dispute workflow, polish | Operational loops closed                                 |
| 7    | Adapter Architecture      | Signal interface, CRM adapter, Gong stub                 | Architecture ready for any signal source                 |
| 8    | Integration + Package     | Slack, batch jobs, test suite, first package             | **Demoable product milestone**                           |
| 9    | External Adapters         | Gong live, Momentum, Teams, remaining stubs              | Full signal integration working                          |
| 10   | Hardening                 | Stress test, security, pilot kit, final package          | **Pilot ready**                                          |

---

## Critical Path Items (Non-Parallelizable)

These items have dependencies and cannot be reordered:

1. Custom objects (Week 1) → everything else depends on data model
2. Commission engine (Week 1) → inline estimator (Week 3) → governance rules (Week 4) → cockpit (Week 5)
3. Health score calculation (Week 4) → conflict alerts (Week 4) → cockpit health panel (Week 5)
4. Signal adapter interface (Week 7) → Gong adapter (Week 9) → live testing (Week 9)
5. ISV enrollment (Pre-Work) → security review (Week 10) → AppExchange listing (post-pilot)

---

## Risk Register

| Risk                                                      | Likelihood                                     | Impact                                            | Mitigation                                                                                                                  |
| --------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Gong API sandbox access delayed                           | Medium                                         | Low — only affects Week 9, not core product       | Use mocked responses for development; defer live testing to pilot phase with design partner's Gong instance                 |
| AppExchange security review takes >8 weeks                | Medium                                         | Medium — delays AppExchange listing but not pilot | Distribute as unlisted managed package to design partners; submit review in Pre-Work to start the clock early               |
| Design partner has no Gong/Momentum                       | Medium                                         | Low                                               | CRM-only health scores work without any external adapter; this is a feature, not a limitation                               |
| Governor limits on bulk Submit with governance evaluation | Low (mitigated by Platform Event architecture) | Medium                                            | Platform Events provide isolated execution context; worst case, governance evaluation is asynchronous with 2-3 second delay |
| Customer org has conflicting trigger on Opportunity       | Low (mitigated by AD-1)                        | Low                                               | Only one lightweight trigger in customer context (publishes Platform Event); all processing in isolated context             |

---

_Implementation Sequence V1.0 — April 2, 2026_
_Spec Reference: UNIFIED_PLATFORM_SPEC.md V3.0_
_Architecture Decisions: AD-1 through AD-8_
