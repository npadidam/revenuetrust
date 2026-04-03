/**
 * @description Handler for Commission_Event__e Platform Events.
 *              Routes events by Event_Type__c to the CommissionService for processing.
 *              Handles post-close changes (reprocessing) and deal-lost (clawback evaluation).
 *              Failed events are logged to Failed_Event__c for retry.
 *
 *              Event Types:
 *              - DEAL_CLOSED               → full commission calculation
 *              - DEAL_LOST                 → clawback evaluation on existing commissions
 *              - DEAL_REOPENED             → flag existing commissions for review
 *              - AMOUNT_CHANGED            → recalculate projected commissions
 *              - AMOUNT_CHANGED_POST_CLOSE → reprocessing: deal already closed, commissions may exist
 *              - CLOSE_DATE_CHANGED        → update period assignment for projected
 *              - CLOSE_DATE_CHANGED_POST_CLOSE → reprocessing: may affect fiscal period, attainment
 *              - STAGE_CHANGED             → may affect projected calculations
 */
public with sharing class CommissionEventHandler {

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

    private void routeEvent(Commission_Event__e evt) {
        String eventType = evt.Event_Type__c;
        Id opportunityId = Id.valueOf(evt.Opportunity_Id__c);

        switch on eventType {
            // ── Standard commission processing ──
            when 'DEAL_CLOSED' {
                handleDealClosed(opportunityId, evt);
            }

            // ── Post-close changes: check if commissions exist, then reprocess ──
            when 'AMOUNT_CHANGED_POST_CLOSE', 'CLOSE_DATE_CHANGED_POST_CLOSE' {
                handlePostCloseChange(opportunityId, eventType, evt);
            }

            // ── Deal lost after commissions were paid → clawback evaluation ──
            when 'DEAL_LOST' {
                handleDealLost(opportunityId, evt);
            }

            // ── Deal reopened after close → flag for admin review ──
            when 'DEAL_REOPENED' {
                handleDealReopened(opportunityId, evt);
            }

            // ── Pre-close changes: recalculate projected only ──
            when 'AMOUNT_CHANGED', 'CLOSE_DATE_CHANGED', 'STAGE_CHANGED' {
                handlePreCloseChange(opportunityId, eventType);
            }
        }
    }

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
        // Query ALL existing commission records for this deal (any status, any type)
        List<Comp_Calculation__c> existingCalcs = [
            SELECT Id, Calculation_Status__c, Adjustment_Type__c,
                   Commisionable_Value__c, Contract_Date2__c, Comp_Plan__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];

        if (existingCalcs.isEmpty()) {
            // ── SCENARIO 1: First-time close — standard processing ──
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
                priorCommissionableTotal += (calc.Commisionable_Value__c != null ? calc.Commisionable_Value__c : 0);
                if (priorCloseDate == null && calc.Contract_Date2__c != null) {
                    priorCloseDate = calc.Contract_Date2__c;
                }
            }
        }

        if (hasClawbacks) {
            // ── SCENARIO 5: Re-close after clawback (Won→Lost→Reopened→Won) ──
            // Clawback needs to be reversed, then commissions recalculated.
            // This is complex — flag for admin with clear context.
            createReprocessingAlert(opportunityId, 'RECLOSE_AFTER_CLAWBACK', evt);
            return;
        }

        if (hasProjectedOnly) {
            // Only Projected from a prior cycle — delete and recalculate fresh
            deleteProjectedCalculations(opportunityId);
            CommissionService.processOpportunity(opportunityId);
            return;
        }

        // ── Has Validated/Paid originals — this is a re-close ──
        // Check if the close date falls in a frozen period
        Boolean priorInFrozenPeriod = false;
        if (priorCloseDate != null) {
            Integer frozenCount = [
                SELECT COUNT()
                FROM Forecast_Period__c
                WHERE Status__c = 'Frozen'
                AND Start_Date__c <= :priorCloseDate
                AND End_Date__c >= :priorCloseDate
                LIMIT 1
            ];
            priorInFrozenPeriod = (frozenCount > 0);
        }

        // Get current opportunity amount for comparison
        Opportunity opp = [
            SELECT Amount, CloseDate
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opp == null) {
            return;
        }

        // Compare: has the amount or period changed?
        Boolean amountChanged = (opp.Amount != priorCommissionableTotal);
        Boolean periodChanged = (priorCloseDate != null && opp.CloseDate != priorCloseDate);

        if (!amountChanged && !periodChanged) {
            // ── SCENARIO 2: Re-close, same amount, same period ──
            // Originals are still valid. No new commissions needed.
            // Log for audit but take no action.
            System.debug(LoggingLevel.INFO,
                'DEAL_CLOSED (re-close): Opp ' + opportunityId +
                ' re-closed with same amount and period. No commission action needed.');
            return;
        }

        if (priorInFrozenPeriod) {
            // ── SCENARIO 4: Re-close but original commissions in frozen period ──
            // Cannot modify frozen entries. Alert admin to create adjustments in current period.
            createReprocessingAlert(opportunityId, 'RECLOSE_FROZEN_PERIOD_ADJUSTMENT', evt);
        } else {
            // ── SCENARIO 3: Re-close, amount or period changed, period not frozen ──
            // Admin needs to review and trigger reprocessing (reversal + new calculation).
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
        // Check if any Validated or Paid calculations exist
        Integer lockedCalcCount = [
            SELECT COUNT()
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Calculation_Status__c IN ('Validated', 'Paid')
            LIMIT 1
        ];

        if (lockedCalcCount > 0) {
            // Validated/Paid commissions exist — cannot silently reprocess.
            // Create a Failed_Event__c flagging this for admin review.
            // The admin must trigger manual reprocessing (which creates reversals).
            createReprocessingAlert(opportunityId, eventType, evt);
        } else {
            // Only Projected commissions — safe to delete and recalculate
            deleteProjectedCalculations(opportunityId);
            CommissionService.processOpportunity(opportunityId);
        }
    }

    /**
     * @description Handle deal moved to a Lost stage.
     *              Action depends on WHERE it came from:
     *              - Won → Lost (previous stage was a won stage): clawback evaluation
     *              - Open → Lost (never closed): delete projected commissions, no clawback
     */
    /**
     * @description Handle deal moved to a Lost stage.
     *              IMPORTANT: Don't rely solely on previous stage — check commission HISTORY.
     *              The path Won→Reopened→Lost has an Open stage as previousStage,
     *              but Validated/Paid commissions from the original close still exist.
     *
     *              Decision tree:
     *              1. Check if Validated/Paid original commissions exist (regardless of previous stage)
     *                 → Yes: clawback evaluation (was Won at some point, commissions were earned)
     *                        If original calcs in frozen period → clawback as adjustment in current period
     *                 → No:  check for Projected
     *              2. Check if Projected commissions exist
     *                 → Yes: delete them (deal is lost, no payout)
     *                 → No:  nothing to do
     */
    private void handleDealLost(Id opportunityId, Commission_Event__e evt) {
        // Always query commission history — previous stage alone is insufficient
        // for paths like Won→Reopened→Lost where previousStage is an open stage
        List<Comp_Calculation__c> existingCalcs = [
            SELECT Id, Calculation_Status__c, Adjustment_Type__c, Contract_Date2__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :opportunityId
            AND Adjustment_Type__c IN ('Original', 'Amendment')
            AND Calculation_Status__c IN ('Projected', 'Validated', 'Paid')
            LIMIT 200
        ];

        if (existingCalcs.isEmpty()) {
            // No commissions ever existed — nothing to do
            return;
        }

        // Separate by status
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
            // Commissions were earned at some point (direct Won→Lost OR Won→Reopened→Lost).
            // Clawback evaluation required.

            // Check if original commissions are in a frozen period
            Boolean inFrozenPeriod = false;
            if (earliestCalcDate != null) {
                Integer frozenCount = [
                    SELECT COUNT()
                    FROM Forecast_Period__c
                    WHERE Status__c = 'Frozen'
                    AND Start_Date__c <= :earliestCalcDate
                    AND End_Date__c >= :earliestCalcDate
                    LIMIT 1
                ];
                inFrozenPeriod = (frozenCount > 0);
            }

            String alertType = inFrozenPeriod
                ? 'CLAWBACK_FROZEN_PERIOD'
                : 'CLAWBACK_EVALUATION_REQUIRED';
            createReprocessingAlert(opportunityId, alertType, evt);
        }

        // Always clean up Projected records — deal is lost, projections are void
        if (hasProjected) {
            deleteProjectedCalculations(opportunityId);
        }
    }

    /**
     * @description Load won stages from Incentive_Configuration__c.
     *              Mirrors the logic in OpportunityCommissionTriggerHandler.
     */
    private Set<String> getWonStages() {
        Set<String> stages = new Set<String>{ 'Closed Won' }; // default
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
     * @description Handle deal reopened (moved from Won/Lost back to open stage).
     *              Two cases:
     *              1. Won → Reopened: commissions may exist (Validated/Paid). Flag for admin.
     *                 If original close date is in a frozen forecast period, adjustments must
     *                 be created in the current period (frozen entries are immutable).
     *              2. Lost → Reopened: deal is alive again.
     *                 - If Lost→Reopened was preceded by Won→Lost with clawback: may need
     *                   to reverse the clawback (flag for admin).
     *                 - If it was Open→Lost→Reopened (never closed): no commission action.
     */
    private void handleDealReopened(Id opportunityId, Commission_Event__e evt) {
        String previousStage = evt.Previous_Value__c;

        Set<String> wonStages = getWonStages();
        Set<String> lostStages = getLostStages();

        if (wonStages.contains(previousStage)) {
            // ── Won → Reopened ──
            // Check for existing commissions
            List<Comp_Calculation__c> existingCalcs = [
                SELECT Id, Calculation_Status__c, Contract_Date2__c, Adjustment_Type__c
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Adjustment_Type__c = 'Original'
                AND Calculation_Status__c IN ('Projected', 'Validated', 'Paid')
                LIMIT 200
            ];

            if (existingCalcs.isEmpty()) {
                // No commissions — nothing to do
                return;
            }

            // Check if any commissions are in a frozen period
            Boolean hasFrozenPeriodCalcs = false;
            Date today = Date.today();
            List<Forecast_Period__c> frozenPeriods = [
                SELECT Id, Start_Date__c, End_Date__c
                FROM Forecast_Period__c
                WHERE Status__c = 'Frozen'
                AND End_Date__c < :today
            ];

            if (!frozenPeriods.isEmpty()) {
                Set<Date> frozenEndDates = new Set<Date>();
                for (Forecast_Period__c fp : frozenPeriods) {
                    frozenEndDates.add(fp.End_Date__c);
                }
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
                    if (hasFrozenPeriodCalcs) break;
                }
            }

            // Separate Projected from Validated/Paid
            Boolean hasLockedCalcs = false;
            for (Comp_Calculation__c calc : existingCalcs) {
                if (calc.Calculation_Status__c == 'Validated' || calc.Calculation_Status__c == 'Paid') {
                    hasLockedCalcs = true;
                    break;
                }
            }

            if (hasLockedCalcs) {
                // Validated/Paid exist — always flag for admin.
                // Include frozen period context so admin knows adjustment entries are needed.
                String alertType = hasFrozenPeriodCalcs
                    ? 'DEAL_REOPENED_FROZEN_PERIOD'
                    : 'DEAL_REOPENED_REVIEW_REQUIRED';
                createReprocessingAlert(opportunityId, alertType, evt);
            } else {
                // Only Projected — safe to delete
                deleteProjectedCalculations(opportunityId);
            }

        } else if (lostStages.contains(previousStage)) {
            // ── Lost → Reopened ──
            // Check if there were any clawback entries (meaning it was Won→Lost→Reopened)
            Integer clawbackCount = [
                SELECT COUNT()
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Adjustment_Type__c = 'Clawback'
                LIMIT 1
            ];

            if (clawbackCount > 0) {
                // Was Won→Lost (clawback happened) → now Reopened
                // The clawback may need to be reversed. Flag for admin.
                createReprocessingAlert(opportunityId, 'CLAWBACK_REVERSAL_REVIEW', evt);
            }
            // If no clawbacks, it was Open→Lost→Reopened — no commission action needed.
            // Just clean up any remaining Projected entries from the open phase.
            deleteProjectedCalculations(opportunityId);
        }
    }

    /**
     * @description Load lost stages from Incentive_Configuration__c.
     */
    private Set<String> getLostStages() {
        Set<String> stages = new Set<String>{ 'Closed Lost' }; // default
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
     * @description Handle pre-close changes. Only affects projected commissions.
     *              Safe to delete and recalculate without reversal pattern.
     */
    private void handlePreCloseChange(Id opportunityId, String eventType) {
        // For pre-close changes, recalculate projected commissions if any exist
        deleteProjectedCalculations(opportunityId);
        // Only process if the deal is in a stage that warrants projected commissions
        // (future enhancement: configurable projected commission stages)
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
     *              requiring manual intervention (reprocessing, clawback evaluation, etc.)
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

    private String getAlertMessage(String alertType, Id opportunityId) {
        switch on alertType {
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
            // Last resort — can't even log. Debug only.
            System.debug(LoggingLevel.ERROR,
                'CommissionEventHandler: Failed to log error for Opp ' + evt.Opportunity_Id__c +
                '. Original error: ' + e.getMessage() +
                '. Logging error: ' + logEx.getMessage());
        }
    }
}
