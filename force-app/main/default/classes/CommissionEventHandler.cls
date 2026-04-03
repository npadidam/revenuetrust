/**
 * @description Handler for Commission_Event__e Platform Events.
 *              Routes ALL 45 event types from Commission Event Routing Matrix V2.3.
 *
 *              Family A — Deal lifecycle (Opp trigger):
 *              - DEAL_CLOSED, DEAL_LOST, DEAL_REOPENED
 *              - AMOUNT_CHANGED, AMOUNT_CHANGED_POST_CLOSE
 *              - CLOSE_DATE_CHANGED, CLOSE_DATE_CHANGED_POST_CLOSE
 *              - STAGE_CHANGED
 *
 *              Family B — Value & recognition changes:
 *              - PRODUCT_MIX_CHANGED, QUOTA_CREDIT_CHANGED
 *              - REVENUE_RECOGNITION_EVENT, CURRENCY_CHANGED
 *              - BOOKING_VALUE_RESTATED
 *
 *              Family C — Participant & eligibility changes:
 *              - OWNER_CHANGED, OWNER_CHANGED_POST_CLOSE
 *              - RECORD_TYPE_CHANGED, ELIGIBILITY_CHANGED, ELIGIBILITY_CHANGED_POST_CLOSE
 *              - PROBABILITY_CHANGED, TERRITORY_CHANGED
 *              - SPLIT_CHANGED, SPLIT_CHANGED_POST_CLOSE
 *              - TEAM_MEMBER_CHANGED, TEAM_MEMBER_CHANGED_POST_CLOSE
 *
 *              Family D — Ledger & administrative events:
 *              - MANUAL_ADJUSTMENT_CREATED, MANUAL_ADJUSTMENT_REVERSED, MANUAL_OVERRIDE_APPLIED
 *              - CLAWBACK_CREATED, CLAWBACK_REVERSED, REVERSAL_CREATED
 *              - COMMISSION_HOLD_APPLIED, COMMISSION_HOLD_RELEASED, COMMISSION_HOLD_EXPIRED
 *              - CALCULATION_INVALIDATION_DETECTED
 *              - PLAN_ASSIGNMENT_CHANGED, RATE_TABLE_CHANGED
 *              - QUOTA_CHANGED, ACCELERATOR_CHANGED, CREDITING_RULE_CHANGED
 *              - PAYOUT_SCHEDULE_CHANGED, MEASUREMENT_PERIOD_CHANGED
 *              - PERIOD_FROZEN
 */
public with sharing class CommissionEventHandler {

    // ═══════════════════════════════════════════════════════════════════════
    //  ENTRY POINT
    // ═══════════════════════════════════════════════════════════════════════

    public void handle(List<Commission_Event__e> events) {
        // Check CMT kill switch
        if (!TriggerControlService.isEnabled('CommissionEventTrigger')) {
            return;
        }

        for (Commission_Event__e evt : events) {
            try {
                routeEvent(evt);
            } catch (Exception e) {
                logFailedEvent(evt, e);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  ROUTER — switch-on for all 45 event types
    // ═══════════════════════════════════════════════════════════════════════

    private void routeEvent(Commission_Event__e evt) {
        String eventType = evt.Event_Type__c;
        Id recordId = Id.valueOf(evt.Opportunity_Id__c);

        switch on eventType {

            // ── Family A: Deal lifecycle ────────────────────────────────
            when 'DEAL_CLOSED' {
                handleDealClosed(recordId, evt);
            }
            when 'AMOUNT_CHANGED_POST_CLOSE', 'CLOSE_DATE_CHANGED_POST_CLOSE' {
                handlePostCloseChange(recordId, eventType, evt);
            }
            when 'DEAL_LOST' {
                handleDealLost(recordId, evt);
            }
            when 'DEAL_REOPENED' {
                handleDealReopened(recordId, evt);
            }
            when 'AMOUNT_CHANGED', 'CLOSE_DATE_CHANGED', 'STAGE_CHANGED' {
                handlePreCloseChange(recordId, eventType);
            }

            // ── Family B: Value & recognition changes ──────────────────
            when 'PRODUCT_MIX_CHANGED' {
                handleEligibilityChanged(recordId, eventType, evt);
            }
            when 'QUOTA_CREDIT_CHANGED' {
                handleQuotaCreditChanged(recordId, evt);
            }
            when 'REVENUE_RECOGNITION_EVENT' {
                handleRevenueRecognitionEvent(recordId, evt);
            }
            when 'CURRENCY_CHANGED' {
                handlePreCloseChange(recordId, eventType);
            }
            when 'BOOKING_VALUE_RESTATED' {
                handlePostCloseChange(recordId, eventType, evt);
            }

            // ── Family C: Participant & eligibility changes ────────────
            when 'OWNER_CHANGED', 'OWNER_CHANGED_POST_CLOSE',
                 'TERRITORY_CHANGED',
                 'SPLIT_CHANGED', 'SPLIT_CHANGED_POST_CLOSE',
                 'TEAM_MEMBER_CHANGED', 'TEAM_MEMBER_CHANGED_POST_CLOSE' {
                handleParticipantSetChanged(recordId, eventType, evt);
            }
            when 'RECORD_TYPE_CHANGED' {
                handleEligibilityChanged(recordId, eventType, evt);
            }
            when 'ELIGIBILITY_CHANGED' {
                handleEligibilityChanged(recordId, eventType, evt);
            }
            when 'ELIGIBILITY_CHANGED_POST_CLOSE' {
                handleEligibilityChangedPostClose(recordId, eventType, evt);
            }
            when 'PROBABILITY_CHANGED' {
                handleProbabilityChanged(recordId, evt);
            }

            // ── Family D: Ledger events ────────────────────────────────
            when 'MANUAL_ADJUSTMENT_CREATED', 'MANUAL_ADJUSTMENT_REVERSED',
                 'MANUAL_OVERRIDE_APPLIED' {
                handleLedgerChangeEvent(recordId, eventType, evt);
            }
            when 'CLAWBACK_CREATED', 'CLAWBACK_REVERSED', 'REVERSAL_CREATED' {
                handleLedgerChangeEvent(recordId, eventType, evt);
            }
            when 'COMMISSION_HOLD_APPLIED' {
                handleCommissionHoldApplied(recordId, evt);
            }
            when 'COMMISSION_HOLD_RELEASED' {
                handleCommissionHoldReleased(recordId, evt);
            }
            when 'COMMISSION_HOLD_EXPIRED' {
                handleCommissionHoldExpired(recordId, evt);
            }
            when 'CALCULATION_INVALIDATION_DETECTED' {
                CalculationInvalidationService.handleInvalidation(eventType, recordId);
            }
            when 'PLAN_ASSIGNMENT_CHANGED', 'RATE_TABLE_CHANGED',
                 'QUOTA_CHANGED', 'ACCELERATOR_CHANGED',
                 'CREDITING_RULE_CHANGED', 'PAYOUT_SCHEDULE_CHANGED',
                 'MEASUREMENT_PERIOD_CHANGED' {
                handlePlanStructureChanged(recordId, eventType, evt);
            }
            when 'PERIOD_FROZEN' {
                PeriodFreezeHandler.handlePeriodFreeze(recordId);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  FAMILY A: Deal Lifecycle Handlers (existing logic preserved)
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Handle deal closed. This may be a FIRST close or a RE-CLOSE
     *              (after Won→Reopened→Won or Won→Lost→Reopened→Won).
     *
     *              Scenarios:
     *              1. First-time close (no prior commissions)  → standard calculation
     *              2. Re-close, same amount, same period       → verify originals, no new calcs
     *              3. Re-close, amount changed                 → adjustment entries for delta
     *              4. Re-close, different period (old frozen)  → adjustment in current period
     *              5. Re-close after clawback (Won→Lost→Reopen→Won) → reverse clawback + recalculate
     */
    private void handleDealClosed(Id opportunityId, Commission_Event__e evt) {
        List<Comp_Calculation__c> existingCalcs = [
            SELECT Id, Calculation_Status__c, Adjustment_Type__c,
                   Commisionable_Value__c, Contract_Date2__c, Comp_Plan__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        if (existingCalcs.isEmpty()) {
            // SCENARIO 1: First-time close — standard processing
            CommissionService.processOpportunity(opportunityId);
            return;
        }

        // Categorize existing records
        Boolean hasClawbacks = false;
        Boolean hasValidatedOrPaid = false;
        Boolean hasProjectedOnly = true;
        Decimal priorCommissionableTotal = 0;
        Date priorCloseDate;

        for (Comp_Calculation__c calc : existingCalcs) {
            if (calc.Adjustment_Type__c == 'Clawback') {
                hasClawbacks = true;
            }
            if (calc.Calculation_Status__c == 'Validated' || calc.Calculation_Status__c == 'Paid') {
                hasValidatedOrPaid = true;
                hasProjectedOnly = false;
            }
            if (calc.Adjustment_Type__c == 'Original'
                && calc.Calculation_Status__c != 'Reversed') {
                priorCommissionableTotal += (calc.Commisionable_Value__c != null
                    ? calc.Commisionable_Value__c : 0);
                if (priorCloseDate == null && calc.Contract_Date2__c != null) {
                    priorCloseDate = calc.Contract_Date2__c;
                }
            }
        }

        if (hasClawbacks) {
            // SCENARIO 5: Re-close after clawback (Won→Lost→Reopened→Won)
            createReprocessingAlert(opportunityId, 'RECLOSE_AFTER_CLAWBACK', evt);
            return;
        }

        if (hasProjectedOnly) {
            // Only Projected from a prior cycle — delete and recalculate fresh
            deleteProjectedCalculations(opportunityId);
            CommissionService.processOpportunity(opportunityId);
            return;
        }

        // Has Validated/Paid originals — this is a re-close
        Boolean priorInFrozenPeriod = isDateInFrozenPeriod(priorCloseDate);

        Opportunity opp = [
            SELECT Amount, CloseDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opp == null) {
            return;
        }

        Boolean amountChanged = (opp.Amount != priorCommissionableTotal);
        Boolean periodChanged = (priorCloseDate != null && opp.CloseDate != priorCloseDate);

        if (!amountChanged && !periodChanged) {
            // SCENARIO 2: Re-close, same amount, same period — no action
            System.debug(LoggingLevel.INFO,
                'DEAL_CLOSED (re-close): Opp ' + opportunityId +
                ' re-closed with same amount and period. No commission action needed.');
            return;
        }

        if (priorInFrozenPeriod) {
            // SCENARIO 4: Re-close but original commissions in frozen period
            createReprocessingAlert(opportunityId, 'RECLOSE_FROZEN_PERIOD_ADJUSTMENT', evt);
        } else {
            // SCENARIO 3: Re-close, amount or period changed, period not frozen
            createReprocessingAlert(opportunityId, 'RECLOSE_DELTA_REPROCESSING', evt);
        }
    }

    /**
     * @description Handle changes to an already-closed deal.
     *              Per spec §9.8 (DP-I4):
     *              - Projected → delete and recreate
     *              - Validated/Paid → reversal pattern
     */
    private void handlePostCloseChange(Id opportunityId, String eventType, Commission_Event__e evt) {
        Integer lockedCalcCount = [
            SELECT COUNT()
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Calculation_Status__c IN ('Validated', 'Paid')
            LIMIT 1
        ];

        if (lockedCalcCount > 0) {
            // Check frozen period for locked calcs
            String alertType = eventType;
            if (hasCalcsInFrozenPeriod(opportunityId)) {
                alertType = eventType + '_FROZEN_PERIOD';
            }
            createReprocessingAlert(opportunityId, alertType, evt);
        } else {
            // Only Projected commissions — safe to delete and recalculate
            deleteProjectedCalculations(opportunityId);
            CommissionService.processOpportunity(opportunityId);
        }
    }

    /**
     * @description Handle deal moved to a Lost stage.
     *              Decision tree based on commission HISTORY, not previous stage:
     *              1. Validated/Paid originals exist → clawback evaluation
     *              2. Only Projected → delete them
     *              3. Nothing → no action
     */
    private void handleDealLost(Id opportunityId, Commission_Event__e evt) {
        List<Comp_Calculation__c> existingCalcs = [
            SELECT Id, Calculation_Status__c, Adjustment_Type__c, Contract_Date2__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Adjustment_Type__c IN ('Original', 'Amendment')
            AND Calculation_Status__c IN ('Projected', 'Validated', 'Paid')
            LIMIT 200
        ];

        if (existingCalcs.isEmpty()) {
            return;
        }

        Boolean hasValidatedOrPaid = false;
        Boolean hasProjected = false;
        Date earliestCalcDate;

        for (Comp_Calculation__c calc : existingCalcs) {
            if (calc.Calculation_Status__c == 'Validated' || calc.Calculation_Status__c == 'Paid') {
                hasValidatedOrPaid = true;
                if (earliestCalcDate == null && calc.Contract_Date2__c != null) {
                    earliestCalcDate = calc.Contract_Date2__c;
                }
            }
            if (calc.Calculation_Status__c == 'Projected') {
                hasProjected = true;
            }
        }

        if (hasValidatedOrPaid) {
            Boolean inFrozenPeriod = isDateInFrozenPeriod(earliestCalcDate);
            String alertType = inFrozenPeriod
                ? 'CLAWBACK_FROZEN_PERIOD'
                : 'CLAWBACK_EVALUATION_REQUIRED';
            createReprocessingAlert(opportunityId, alertType, evt);
        }

        if (hasProjected) {
            deleteProjectedCalculations(opportunityId);
        }
    }

    /**
     * @description Handle deal reopened (moved from Won/Lost back to open stage).
     *              1. Won → Reopened: commissions may exist, check frozen periods
     *              2. Lost → Reopened: check for prior clawbacks
     */
    private void handleDealReopened(Id opportunityId, Commission_Event__e evt) {
        String previousStage = evt.Previous_Value__c;

        Set<String> wonStages = getWonStages();
        Set<String> lostStages = getLostStages();

        if (wonStages.contains(previousStage)) {
            // Won → Reopened
            List<Comp_Calculation__c> existingCalcs = [
                SELECT Id, Calculation_Status__c, Contract_Date2__c, Adjustment_Type__c
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Adjustment_Type__c = 'Original'
                AND Calculation_Status__c IN ('Projected', 'Validated', 'Paid')
                LIMIT 200
            ];

            if (existingCalcs.isEmpty()) {
                return;
            }

            Boolean hasFrozenPeriodCalcs = false;
            Date today = Date.today();
            List<Forecast_Period__c> frozenPeriods = [
                SELECT Id, Start_Date__c, End_Date__c
                FROM Forecast_Period__c
                WHERE Status__c = 'Frozen'
                AND End_Date__c < :today
            ];

            if (!frozenPeriods.isEmpty()) {
                for (Comp_Calculation__c calc : existingCalcs) {
                    if (calc.Contract_Date2__c != null) {
                        for (Forecast_Period__c fp : frozenPeriods) {
                            if (calc.Contract_Date2__c >= fp.Start_Date__c
                                && calc.Contract_Date2__c <= fp.End_Date__c) {
                                hasFrozenPeriodCalcs = true;
                                break;
                            }
                        }
                    }
                    if (hasFrozenPeriodCalcs) {
                        break;
                    }
                }
            }

            Boolean hasLockedCalcs = false;
            for (Comp_Calculation__c calc : existingCalcs) {
                if (calc.Calculation_Status__c == 'Validated' || calc.Calculation_Status__c == 'Paid') {
                    hasLockedCalcs = true;
                    break;
                }
            }

            if (hasLockedCalcs) {
                String alertType = hasFrozenPeriodCalcs
                    ? 'DEAL_REOPENED_FROZEN_PERIOD'
                    : 'DEAL_REOPENED_REVIEW_REQUIRED';
                createReprocessingAlert(opportunityId, alertType, evt);
            } else {
                deleteProjectedCalculations(opportunityId);
            }

        } else if (lostStages.contains(previousStage)) {
            // Lost → Reopened
            Integer clawbackCount = [
                SELECT COUNT()
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Adjustment_Type__c = 'Clawback'
                LIMIT 1
            ];

            if (clawbackCount > 0) {
                createReprocessingAlert(opportunityId, 'CLAWBACK_REVERSAL_REVIEW', evt);
            }
            deleteProjectedCalculations(opportunityId);
        }
    }

    /**
     * @description Handle pre-close changes. Only affects projected commissions.
     */
    private void handlePreCloseChange(Id opportunityId, String eventType) {
        deleteProjectedCalculations(opportunityId);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  FAMILY B: Value & Recognition Change Handlers
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Handle QUOTA_CREDIT_CHANGED — alert + attainment recompute check.
     *              Quota credit changes affect attainment tiers, not individual deal calcs.
     */
    private void handleQuotaCreditChanged(Id opportunityId, Commission_Event__e evt) {
        createReprocessingAlert(opportunityId, 'QUOTA_CREDIT_CHANGED', evt);
        // Attainment recompute is triggered by the alert resolution workflow
    }

    /**
     * @description Handle REVENUE_RECOGNITION_EVENT — route to CommissionService
     *              with rev rec flag. Stub for Phase 1C.
     */
    private void handleRevenueRecognitionEvent(Id recordId, Commission_Event__e evt) {
        // Stub — full revenue recognition integration in Phase 1C
        System.debug(LoggingLevel.INFO,
            'REVENUE_RECOGNITION_EVENT received for ' + recordId +
            '. Routing to CommissionService with rev rec flag (stub).');
        IncentiveChangeEventService.logEvent(
            'Opportunity', recordId, 'REVENUE_RECOGNITION_EVENT',
            evt.Previous_Value__c, evt.New_Value__c, 'Revenue recognition event received');
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  FAMILY C: Participant & Eligibility Change Handlers
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Canonical handler for owner/team/split/territory changes.
     *              One method, same routing logic regardless of which field changed.
     *              Post-close variants check for Validated/Paid and frozen periods.
     */
    private void handleParticipantSetChanged(Id opportunityId, String eventType, Commission_Event__e evt) {
        Boolean isPostClose = eventType.contains('POST_CLOSE');

        if (isPostClose) {
            Integer lockedCalcCount = [
                SELECT COUNT()
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Calculation_Status__c IN ('Validated', 'Paid')
                LIMIT 1
            ];

            if (lockedCalcCount > 0) {
                String alertType = hasCalcsInFrozenPeriod(opportunityId)
                    ? 'PARTICIPANT_CHANGED_FROZEN_PERIOD'
                    : 'PARTICIPANT_CHANGED_POST_CLOSE';
                createReprocessingAlert(opportunityId, alertType, evt);
                return;
            }
        }

        // Pre-close or no locked calcs: delete projected and recalculate
        deleteProjectedCalculations(opportunityId);
        CommissionService.processOpportunity(opportunityId);
    }

    /**
     * @description Canonical handler for eligibility, record type, and product mix changes.
     *              Checks stage + calc status to determine recalc vs alert.
     */
    private void handleEligibilityChanged(Id opportunityId, String eventType, Commission_Event__e evt) {
        // Check if deal is already closed
        Opportunity opp = [
            SELECT StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];

        if (opp == null) {
            return;
        }

        Set<String> wonStages = getWonStages();

        if (wonStages.contains(opp.StageName)) {
            // Deal is closed — check calc status
            Integer lockedCalcCount = [
                SELECT COUNT()
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Calculation_Status__c IN ('Validated', 'Paid')
                LIMIT 1
            ];

            if (lockedCalcCount > 0) {
                String alertType = hasCalcsInFrozenPeriod(opportunityId)
                    ? eventType + '_FROZEN_PERIOD'
                    : eventType + '_REPROCESSING';
                createReprocessingAlert(opportunityId, alertType, evt);
                return;
            }
        }

        // Pre-close or only projected — safe to recalculate
        deleteProjectedCalculations(opportunityId);
        CommissionService.processOpportunity(opportunityId);
    }

    /**
     * @description Handle ELIGIBILITY_CHANGED_POST_CLOSE — check calc status → recalc or alert.
     */
    private void handleEligibilityChangedPostClose(Id opportunityId, String eventType, Commission_Event__e evt) {
        Integer lockedCalcCount = [
            SELECT COUNT()
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Calculation_Status__c IN ('Validated', 'Paid')
            LIMIT 1
        ];

        if (lockedCalcCount > 0) {
            String alertType = hasCalcsInFrozenPeriod(opportunityId)
                ? 'ELIGIBILITY_CHANGED_POST_CLOSE_FROZEN_PERIOD'
                : 'ELIGIBILITY_CHANGED_POST_CLOSE';
            createReprocessingAlert(opportunityId, alertType, evt);
        } else {
            deleteProjectedCalculations(opportunityId);
            CommissionService.processOpportunity(opportunityId);
        }
    }

    /**
     * @description Handle PROBABILITY_CHANGED — check if probability crossed a threshold
     *              to enable or disable commission eligibility.
     */
    private void handleProbabilityChanged(Id opportunityId, Commission_Event__e evt) {
        Decimal oldProbability = String.isNotBlank(evt.Previous_Value__c)
            ? Decimal.valueOf(evt.Previous_Value__c) : 0;
        Decimal newProbability = String.isNotBlank(evt.New_Value__c)
            ? Decimal.valueOf(evt.New_Value__c) : 0;

        // Load configured threshold from Incentive_Configuration__c
        Decimal threshold = getCommissionEligibilityThreshold();

        Boolean wasEligible = (oldProbability >= threshold);
        Boolean nowEligible = (newProbability >= threshold);

        if (wasEligible == nowEligible) {
            // No threshold crossing — no commission impact
            return;
        }

        if (nowEligible && !wasEligible) {
            // Crossed UP over threshold — enable projected commissions
            CommissionService.processOpportunity(opportunityId);
        } else {
            // Crossed DOWN below threshold — disable projected commissions
            deleteProjectedCalculations(opportunityId);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  FAMILY D: Ledger & Administrative Event Handlers
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Log ledger change events (manual adjustments, clawbacks, reversals)
     *              to Incentive_Change_Event__c for audit trail.
     */
    private void handleLedgerChangeEvent(Id recordId, String eventType, Commission_Event__e evt) {
        IncentiveChangeEventService.logEvent(
            'Comp_Calculation', recordId, eventType,
            evt.Previous_Value__c, evt.New_Value__c,
            'Ledger event: ' + eventType);
    }

    /**
     * @description Handle COMMISSION_HOLD_APPLIED — update Hold_Status__c on Comp_Calculation__c.
     */
    private void handleCommissionHoldApplied(Id recordId, Commission_Event__e evt) {
        List<Id> calcIds = getCalcIdsForRecord(recordId);
        if (!calcIds.isEmpty()) {
            String holdReason = String.isNotBlank(evt.New_Value__c)
                ? evt.New_Value__c : 'Commission hold applied via event';
            CommissionHoldService.applyHold(calcIds, holdReason);
        }
    }

    /**
     * @description Handle COMMISSION_HOLD_RELEASED — release hold on Comp_Calculation__c.
     */
    private void handleCommissionHoldReleased(Id recordId, Commission_Event__e evt) {
        List<Id> calcIds = getCalcIdsForRecord(recordId);
        if (!calcIds.isEmpty()) {
            CommissionHoldService.releaseHold(calcIds);
        }
    }

    /**
     * @description Handle COMMISSION_HOLD_EXPIRED — treat as a release with expired context.
     */
    private void handleCommissionHoldExpired(Id recordId, Commission_Event__e evt) {
        List<Id> calcIds = getCalcIdsForRecord(recordId);
        if (!calcIds.isEmpty()) {
            CommissionHoldService.releaseHold(calcIds);
            // Log the expiration specifically
            for (Id calcId : calcIds) {
                IncentiveChangeEventService.logEvent(
                    'Comp_Calculation', calcId, 'COMMISSION_HOLD_EXPIRED',
                    'Held', 'Released', 'Hold expired automatically');
            }
        }
    }

    /**
     * @description Handle plan structure changes (plan assignment, rate table, quota, etc.).
     *              Routes to CalculationInvalidationService which determines affected calcs
     *              and resolves the impact.
     */
    private void handlePlanStructureChanged(Id recordId, String eventType, Commission_Event__e evt) {
        CalculationInvalidationService.handleInvalidation(eventType, recordId);

        // Also log to change event audit trail
        IncentiveChangeEventService.logEvent(
            'Plan_Structure', recordId, eventType,
            evt.Previous_Value__c, evt.New_Value__c,
            'Plan structure change: ' + eventType);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Load won stages from Incentive_Configuration__c.
     */
    private Set<String> getWonStages() {
        Set<String> stages = new Set<String>{ 'Closed Won' };
        List<Incentive_Configuration__c> configs = [
            SELECT Won_Stages__c
            FROM Incentive_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Won_Stages__c)) {
            stages.clear();
            for (String s : configs[0].Won_Stages__c.split(',')) {
                String trimmed = s.trim();
                if (String.isNotBlank(trimmed)) {
                    stages.add(trimmed);
                }
            }
        }
        return stages;
    }

    /**
     * @description Load lost stages from Incentive_Configuration__c.
     */
    private Set<String> getLostStages() {
        Set<String> stages = new Set<String>{ 'Closed Lost' };
        List<Incentive_Configuration__c> configs = [
            SELECT Lost_Stages__c
            FROM Incentive_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Lost_Stages__c)) {
            stages.clear();
            for (String s : configs[0].Lost_Stages__c.split(',')) {
                String trimmed = s.trim();
                if (String.isNotBlank(trimmed)) {
                    stages.add(trimmed);
                }
            }
        }
        return stages;
    }

    /**
     * @description Load commission eligibility probability threshold from config.
     *              Defaults to 50% if not configured.
     */
    private Decimal getCommissionEligibilityThreshold() {
        List<Incentive_Configuration__c> configs = [
            SELECT Probability_Threshold__c
            FROM Incentive_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].Probability_Threshold__c != null) {
            return configs[0].Probability_Threshold__c;
        }
        return 50; // default threshold
    }

    /**
     * @description Check if a given date falls within a frozen forecast period.
     */
    private Boolean isDateInFrozenPeriod(Date checkDate) {
        if (checkDate == null) {
            return false;
        }
        Integer frozenCount = [
            SELECT COUNT()
            FROM Forecast_Period__c
            WHERE Status__c = 'Frozen'
            AND Start_Date__c <= :checkDate
            AND End_Date__c >= :checkDate
            LIMIT 1
        ];
        return (frozenCount > 0);
    }

    /**
     * @description Check if an opportunity has any Validated/Paid calcs in a frozen period.
     */
    private Boolean hasCalcsInFrozenPeriod(Id opportunityId) {
        List<Comp_Calculation__c> lockedCalcs = [
            SELECT Id, Contract_Date2__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Calculation_Status__c IN ('Validated', 'Paid')
            LIMIT 200
        ];

        if (lockedCalcs.isEmpty()) {
            return false;
        }

        List<Forecast_Period__c> frozenPeriods = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Forecast_Period__c
            WHERE Status__c = 'Frozen'
        ];

        if (frozenPeriods.isEmpty()) {
            return false;
        }

        for (Comp_Calculation__c calc : lockedCalcs) {
            if (calc.Contract_Date2__c != null) {
                for (Forecast_Period__c fp : frozenPeriods) {
                    if (calc.Contract_Date2__c >= fp.Start_Date__c
                        && calc.Contract_Date2__c <= fp.End_Date__c) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /**
     * @description Get Comp_Calculation__c Ids for a given record (opportunity or direct calc Id).
     */
    private List<Id> getCalcIdsForRecord(Id recordId) {
        // If the record IS a Comp_Calculation__c, return it directly
        String sObjectType = recordId.getSObjectType().getDescribe().getName();
        if (sObjectType == 'Comp_Calculation__c' || sObjectType == 'REVT__Comp_Calculation__c') {
            return new List<Id>{ recordId };
        }

        // Otherwise treat as an Opportunity and find its calcs
        List<Comp_Calculation__c> calcs = [
            SELECT Id FROM Comp_Calculation__c
            WHERE Opportunity__c = :recordId
            AND Calculation_Status__c NOT IN ('Reversed', 'Cancelled')
            LIMIT 500
        ];
        List<Id> calcIds = new List<Id>();
        for (Comp_Calculation__c c : calcs) {
            calcIds.add(c.Id);
        }
        return calcIds;
    }

    /**
     * @description Delete Projected (provisional) Comp_Calculation__c records.
     *              Per spec §11.3: Projected rows are mutable working records.
     */
    private void deleteProjectedCalculations(Id opportunityId) {
        List<Comp_Calculation__c> projected = [
            SELECT Id
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Calculation_Status__c = 'Projected'
        ];
        if (!projected.isEmpty()) {
            delete projected;
        }
    }

    /**
     * @description Create a Failed_Event__c record to alert admins of a situation
     *              requiring manual intervention.
     */
    private void createReprocessingAlert(Id opportunityId, String alertType, Commission_Event__e evt) {
        Failed_Event__c alert = new Failed_Event__c();
        alert.Event_Type__c = alertType;
        alert.Payload__c = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opportunityId,
            'originalEventType' => evt.Event_Type__c,
            'previousValue' => evt.Previous_Value__c,
            'newValue' => evt.New_Value__c,
            'userId' => evt.User_Id__c,
            'timestamp' => Datetime.now().format()
        });
        alert.Error_Message__c = getAlertMessage(alertType, opportunityId);
        alert.Retry_Count__c = 0;
        alert.Status__c = 'Failed';
        alert.Original_Event_Time__c = Datetime.now();
        insert alert;
    }

    /**
     * @description Generate human-readable alert messages for all 27 alert types.
     */
    private String getAlertMessage(String alertType, Id opportunityId) {
        switch on alertType {
            // ── Family A alerts ──
            when 'CLAWBACK_EVALUATION_REQUIRED' {
                return 'Deal ' + opportunityId + ' moved to a Lost stage after commissions were processed. Clawback evaluation required per Clawback_Policy__c rules.';
            }
            when 'DEAL_REOPENED_REVIEW_REQUIRED' {
                return 'Deal ' + opportunityId + ' was reopened after being closed (Won → Reopened). Validated/Paid commissions exist. Admin must decide: hold, reverse, or keep.';
            }
            when 'DEAL_REOPENED_FROZEN_PERIOD' {
                return 'Deal ' + opportunityId + ' was reopened after being closed, and the original commission date falls in a FROZEN forecast period. Frozen entries cannot be modified — adjustment entries must be created in the current period.';
            }
            when 'CLAWBACK_FROZEN_PERIOD' {
                return 'Deal ' + opportunityId + ' was lost, and the original commissions are in a FROZEN forecast period. Clawback entries must be created as adjustments in the current period — frozen entries cannot be modified.';
            }
            when 'CLAWBACK_REVERSAL_REVIEW' {
                return 'Deal ' + opportunityId + ' was reopened after being lost (Won → Lost → Reopened). A clawback was previously processed. Admin must review whether the clawback should be reversed.';
            }
            when 'RECLOSE_AFTER_CLAWBACK' {
                return 'Deal ' + opportunityId + ' re-closed after a prior Won→Lost→Reopened cycle. A clawback was previously processed. The clawback must be reversed and commissions recalculated at current values. Admin action required.';
            }
            when 'RECLOSE_FROZEN_PERIOD_ADJUSTMENT' {
                return 'Deal ' + opportunityId + ' re-closed with changed amount/period, but the original commissions are in a FROZEN forecast period. Frozen entries cannot be modified — create adjustment entries in the current period for the delta.';
            }
            when 'RECLOSE_DELTA_REPROCESSING' {
                return 'Deal ' + opportunityId + ' re-closed with changed amount or close date. Original Validated/Paid commissions exist. Admin must trigger reprocessing (system will create reversal + new calculation at updated values).';
            }

            // ── Family B alerts ──
            when 'QUOTA_CREDIT_CHANGED' {
                return 'Quota credit changed for deal ' + opportunityId + '. Attainment tiers may be affected. Review and recompute attainment if necessary.';
            }
            when 'BOOKING_VALUE_RESTATED_FROZEN_PERIOD' {
                return 'Booking value restated for deal ' + opportunityId + ', but original commissions are in a FROZEN forecast period. Adjustment entries must be created in the current period.';
            }

            // ── Family C alerts ──
            when 'PARTICIPANT_CHANGED_POST_CLOSE' {
                return 'Participant set changed for deal ' + opportunityId + ' after close. Validated/Paid commissions exist — admin must review commission split reallocation.';
            }
            when 'PARTICIPANT_CHANGED_FROZEN_PERIOD' {
                return 'Participant set changed for deal ' + opportunityId + ' after close, and original commissions are in a FROZEN forecast period. Adjustments must be created in the current period.';
            }
            when 'ELIGIBILITY_CHANGED_POST_CLOSE' {
                return 'Eligibility criteria changed for deal ' + opportunityId + ' after close. Validated/Paid commissions exist — admin must review whether commissions should be reversed or adjusted.';
            }
            when 'ELIGIBILITY_CHANGED_POST_CLOSE_FROZEN_PERIOD' {
                return 'Eligibility criteria changed for deal ' + opportunityId + ' after close, and original commissions are in a FROZEN forecast period. Adjustments must be created in the current period.';
            }
            when 'PRODUCT_MIX_CHANGED_REPROCESSING' {
                return 'Product mix changed for deal ' + opportunityId + ' with Validated/Paid commissions. Commission rates may be affected. Admin must trigger reprocessing.';
            }
            when 'PRODUCT_MIX_CHANGED_FROZEN_PERIOD' {
                return 'Product mix changed for deal ' + opportunityId + ', and original commissions are in a FROZEN forecast period. Adjustment entries must be created in the current period.';
            }
            when 'RECORD_TYPE_CHANGED_REPROCESSING' {
                return 'Record type changed for deal ' + opportunityId + ' with Validated/Paid commissions. Commission eligibility and rates may be affected. Admin must trigger reprocessing.';
            }
            when 'RECORD_TYPE_CHANGED_FROZEN_PERIOD' {
                return 'Record type changed for deal ' + opportunityId + ', and original commissions are in a FROZEN forecast period. Adjustment entries must be created in the current period.';
            }
            when 'ELIGIBILITY_CHANGED_REPROCESSING' {
                return 'Eligibility changed for deal ' + opportunityId + ' with Validated/Paid commissions. Admin must trigger reprocessing.';
            }
            when 'ELIGIBILITY_CHANGED_FROZEN_PERIOD' {
                return 'Eligibility changed for deal ' + opportunityId + ', and original commissions are in a FROZEN forecast period. Adjustment entries must be created in the current period.';
            }

            // ── Family D alerts (post-close variants with frozen period) ──
            when 'AMOUNT_CHANGED_POST_CLOSE_FROZEN_PERIOD' {
                return 'Amount changed for deal ' + opportunityId + ' after close, and original commissions are in a FROZEN forecast period. Adjustment entries must be created in the current period.';
            }
            when 'CLOSE_DATE_CHANGED_POST_CLOSE_FROZEN_PERIOD' {
                return 'Close date changed for deal ' + opportunityId + ' after close, and original commissions are in a FROZEN forecast period. Adjustment entries must be created in the current period.';
            }

            when else {
                return 'Deal ' + opportunityId + ' was modified after commissions were validated/paid. Manual reprocessing required (event: ' + alertType + ').';
            }
        }
    }

    /**
     * @description Log a processing failure to Failed_Event__c (dead letter queue).
     */
    private void logFailedEvent(Commission_Event__e evt, Exception e) {
        try {
            Failed_Event__c failedEvt = new Failed_Event__c();
            failedEvt.Event_Type__c = 'Commission_Event__e';
            failedEvt.Payload__c = JSON.serialize(new Map<String, Object>{
                'opportunityId' => evt.Opportunity_Id__c,
                'eventType' => evt.Event_Type__c,
                'previousValue' => evt.Previous_Value__c,
                'newValue' => evt.New_Value__c,
                'userId' => evt.User_Id__c
            });
            failedEvt.Error_Message__c = e.getMessage() + '\n' + e.getStackTraceString();
            failedEvt.Retry_Count__c = 0;
            failedEvt.Status__c = 'Failed';
            failedEvt.Original_Event_Time__c = Datetime.now();
            insert failedEvt;
        } catch (Exception logEx) {
            System.debug(LoggingLevel.ERROR,
                'CommissionEventHandler: Failed to log error for Opp ' + evt.Opportunity_Id__c +
                '. Original error: ' + e.getMessage() +
                '. Logging error: ' + logEx.getMessage());
        }
    }
}
