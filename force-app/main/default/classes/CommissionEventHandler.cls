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
                CommissionService.processOpportunity(opportunityId);
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
    private void handleDealLost(Id opportunityId, Commission_Event__e evt) {
        String previousStage = evt.Previous_Value__c;

        // Check if the deal was previously in a Won stage (evt carries old stage as Previous_Value)
        Set<String> wonStages = getWonStages();
        Boolean wasWon = wonStages.contains(previousStage);

        if (wasWon) {
            // Won → Lost: this is a churn/cancellation. Check for Validated/Paid commissions.
            Integer lockedCalcCount = [
                SELECT COUNT()
                FROM Comp_Calculation__c
                WHERE Opportunity__c = :opportunityId
                AND Calculation_Status__c IN ('Validated', 'Paid')
                AND Adjustment_Type__c = 'Original'
                LIMIT 1
            ];

            if (lockedCalcCount > 0) {
                // Validated/Paid commissions exist — clawback evaluation required
                createReprocessingAlert(opportunityId, 'CLAWBACK_EVALUATION_REQUIRED', evt);
            } else {
                // Only Projected — delete them
                deleteProjectedCalculations(opportunityId);
            }
        } else {
            // Open → Lost: deal never closed. Just clean up any projected commissions.
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
     *              Flag for admin review — commissions may need to be held or reversed.
     */
    private void handleDealReopened(Id opportunityId, Commission_Event__e evt) {
        createReprocessingAlert(opportunityId, 'DEAL_REOPENED_REVIEW_REQUIRED', evt);
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
        if (alertType == 'CLAWBACK_EVALUATION_REQUIRED') {
            return 'Deal ' + opportunityId + ' moved to a Lost stage after commissions were processed. Clawback evaluation required.';
        } else if (alertType == 'DEAL_REOPENED_REVIEW_REQUIRED') {
            return 'Deal ' + opportunityId + ' was reopened after being closed. Existing commissions may need to be held or reversed. Admin review required.';
        } else {
            return 'Deal ' + opportunityId + ' was modified after commissions were validated/paid. Manual reprocessing required (event: ' + alertType + ').';
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
