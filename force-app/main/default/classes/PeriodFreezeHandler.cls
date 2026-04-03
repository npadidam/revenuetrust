/**
 * @description Handles the PERIOD_FROZEN event by reclassifying unresolved
 *              Failed_Event__c alerts when a Forecast_Period__c status changes
 *              to 'Frozen'.
 *
 *              Per Commission Event Routing Matrix V2.3 sections D.3 and 12.8:
 *              1. Queries all unresolved Failed_Event__c records (Status = 'Failed')
 *              2. Checks if the affected Opportunity's commission date falls within
 *                 the now-frozen period
 *              3. Reclassifies alert types to their _FROZEN_PERIOD variants
 *              4. Creates a NEW Failed_Event__c linked to the original (immutability
 *                 principle -- the original record is never mutated)
 *              5. Sets original's Status to 'Superseded'
 *              6. Notifies admin of the reclassification count via audit log
 */
public with sharing class PeriodFreezeHandler {

    // Map of standard alert types to their frozen-period variants
    private static final Map<String, String> FROZEN_RECLASSIFICATION = new Map<String, String>{
        'CLAWBACK_EVALUATION_REQUIRED'                      => 'CLAWBACK_FROZEN_PERIOD',
        'DEAL_REOPENED_REVIEW_REQUIRED'                     => 'DEAL_REOPENED_FROZEN_PERIOD',
        'RECLOSE_DELTA_REPROCESSING'                        => 'RECLOSE_FROZEN_PERIOD_ADJUSTMENT',
        'CREDIT_REALLOCATION_REQUIRED'                      => 'CREDIT_REALLOCATION_FROZEN_PERIOD',
        'COMMISSION_ELIGIBILITY_CHANGED_POST_CLOSE'         => 'COMMISSION_ELIGIBILITY_FROZEN_PERIOD',
        'PRODUCT_ELIGIBILITY_CHANGED_POST_CLOSE'            => 'PRODUCT_ELIGIBILITY_FROZEN_PERIOD',
        'TRANSACTION_CLASSIFICATION_CHANGED_POST_CLOSE'     => 'TRANSACTION_CLASSIFICATION_FROZEN_PERIOD',
        'RETRO_RECALCULATION_REVIEW_REQUIRED'               => 'RULE_CHANGE_FROZEN_PERIOD_IMPACT'
    };

    /**
     * @description Handle a period freeze event.
     *              Reclassifies unresolved alerts whose commissions fall within
     *              the frozen period to use _FROZEN_PERIOD alert variants.
     * @param forecastPeriodId The Id of the Forecast_Period__c that was frozen
     */
    public static void handlePeriodFreeze(Id forecastPeriodId) {
        // 1. Load the frozen period's date range
        List<Forecast_Period__c> periods = [
            SELECT Id, Start_Date__c, End_Date__c, Period_Label__c
            FROM Forecast_Period__c
            WHERE Id = :forecastPeriodId
            LIMIT 1
        ];

        if (periods.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'PeriodFreezeHandler: No Forecast_Period__c found for Id ' + forecastPeriodId);
            return;
        }

        Forecast_Period__c frozenPeriod = periods[0];

        // 2. Find all unresolved Failed_Event__c with Status = 'Failed'
        List<Failed_Event__c> unresolvedAlerts = [
            SELECT Id, Event_Type__c, Payload__c, Error_Message__c, Status__c,
                   Retry_Count__c, Original_Event_Time__c
            FROM Failed_Event__c
            WHERE Status__c = 'Failed'
            LIMIT 500
        ];

        if (unresolvedAlerts.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                'PeriodFreezeHandler: No unresolved alerts to reclassify for period ' +
                frozenPeriod.Period_Label__c);
            return;
        }

        // 3. Extract opportunity Ids from each alert's Payload__c JSON
        //    and determine which alerts are eligible for reclassification
        Map<Id, Failed_Event__c> alertsByOriginalId = new Map<Id, Failed_Event__c>();
        Map<Id, Id> alertToOpportunityMap = new Map<Id, Id>();

        for (Failed_Event__c alert : unresolvedAlerts) {
            // Only reclassify if the alert type has a frozen variant
            if (!FROZEN_RECLASSIFICATION.containsKey(alert.Event_Type__c)) {
                continue;
            }

            // Parse Payload__c JSON to extract opportunityId
            Id opportunityId = extractOpportunityId(alert.Payload__c);
            if (opportunityId == null) {
                continue;
            }

            alertsByOriginalId.put(alert.Id, alert);
            alertToOpportunityMap.put(alert.Id, opportunityId);
        }

        if (alertsByOriginalId.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                'PeriodFreezeHandler: No reclassifiable alerts found for period ' +
                frozenPeriod.Period_Label__c);
            return;
        }

        // 4. Collect all unique opportunity Ids and query Comp_Calculation__c
        //    to check if any commission date falls within the frozen period
        Set<Id> opportunityIds = new Set<Id>(alertToOpportunityMap.values());

        // Query for calcs whose Contract_Date2__c is within the frozen period
        Map<Id, Boolean> oppHasCalcInPeriod = new Map<Id, Boolean>();
        for (Id oppId : opportunityIds) {
            oppHasCalcInPeriod.put(oppId, false);
        }

        List<Comp_Calculation__c> calcsInPeriod = [
            SELECT Id, Opportunity__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c IN :opportunityIds
              AND Contract_Date2__c >= :frozenPeriod.Start_Date__c
              AND Contract_Date2__c <= :frozenPeriod.End_Date__c
            LIMIT 2000
        ];

        for (Comp_Calculation__c calc : calcsInPeriod) {
            oppHasCalcInPeriod.put(calc.Opportunity__c, true);
        }

        // 5. Build reclassified alerts and mark originals as Superseded
        List<Failed_Event__c> newAlerts = new List<Failed_Event__c>();
        List<Failed_Event__c> alertsToSupersede = new List<Failed_Event__c>();
        Integer reclassifiedCount = 0;
        List<Id> reclassifiedAlertIds = new List<Id>();

        for (Id originalAlertId : alertsByOriginalId.keySet()) {
            Failed_Event__c originalAlert = alertsByOriginalId.get(originalAlertId);
            Id opportunityId = alertToOpportunityMap.get(originalAlertId);

            // Only reclassify if the opportunity has calcs in the frozen period
            if (!oppHasCalcInPeriod.containsKey(opportunityId)
                || !oppHasCalcInPeriod.get(opportunityId)) {
                continue;
            }

            String originalType = originalAlert.Event_Type__c;
            String frozenVariant = FROZEN_RECLASSIFICATION.get(originalType);

            // Build new Payload__c JSON with reference to the superseded event
            Map<String, Object> newPayload = new Map<String, Object>();
            if (String.isNotBlank(originalAlert.Payload__c)) {
                try {
                    newPayload = (Map<String, Object>) JSON.deserializeUntyped(originalAlert.Payload__c);
                } catch (Exception e) {
                    // If payload is not valid JSON, start fresh with the opportunityId
                    newPayload.put('opportunityId', opportunityId);
                }
            }
            newPayload.put('supersedes_event_id', originalAlertId);
            newPayload.put('reclassified_from', originalType);
            newPayload.put('frozen_period_id', forecastPeriodId);
            newPayload.put('frozen_period_label', frozenPeriod.Period_Label__c);

            // Create the new reclassified Failed_Event__c
            Failed_Event__c newAlert = new Failed_Event__c();
            newAlert.Event_Type__c = frozenVariant;
            newAlert.Payload__c = JSON.serialize(newPayload);
            newAlert.Error_Message__c = 'Reclassified from ' + originalType +
                ' due to period freeze: ' + frozenPeriod.Period_Label__c;
            newAlert.Status__c = 'Failed';
            newAlert.Retry_Count__c = 0;
            newAlert.Original_Event_Time__c = originalAlert.Original_Event_Time__c != null
                ? originalAlert.Original_Event_Time__c
                : Datetime.now();
            newAlerts.add(newAlert);

            // Mark original as Superseded (do not mutate any other fields)
            Failed_Event__c toSupersede = new Failed_Event__c(
                Id = originalAlertId,
                Status__c = 'Superseded'
            );
            alertsToSupersede.add(toSupersede);

            reclassifiedCount++;
            reclassifiedAlertIds.add(originalAlertId);
        }

        // 6. Persist: insert new alerts, update originals to Superseded
        if (!newAlerts.isEmpty()) {
            insert newAlerts;
        }
        if (!alertsToSupersede.isEmpty()) {
            update alertsToSupersede;
        }

        // 7. Log each reclassification via IncentiveChangeEventService
        //    and notify admin of the reclassification count
        if (reclassifiedCount > 0) {
            IncentiveChangeEventService.logEvent(
                'Forecast_Period',
                forecastPeriodId,
                'PERIOD_FREEZE_RECLASSIFICATION',
                String.valueOf(reclassifiedCount) + ' alerts reclassified',
                null,
                'Period ' + frozenPeriod.Period_Label__c + ' frozen. ' +
                reclassifiedCount + ' unresolved alert(s) reclassified to frozen-period variants.'
            );

            System.debug(LoggingLevel.INFO,
                'PeriodFreezeHandler: Reclassified ' + reclassifiedCount +
                ' alert(s) for frozen period ' + frozenPeriod.Period_Label__c);
        }

        // Create REMEDIATION_PATH_CHANGED summary alert if any reclassifications occurred
        if (reclassifiedCount > 0) {
            Failed_Event__c summaryAlert = new Failed_Event__c();
            summaryAlert.Event_Type__c = 'REMEDIATION_PATH_CHANGED_DUE_TO_PERIOD_STATUS';
            summaryAlert.Error_Message__c = reclassifiedCount + ' unresolved commission alert(s) were reclassified ' +
                'because forecast period "' + frozenPeriod.Period_Label__c + '" was frozen. ' +
                'Remediation now requires adjustment entries in the current period instead of direct modifications.';
            summaryAlert.Payload__c = JSON.serialize(new Map<String, Object>{
                'forecastPeriodId' => forecastPeriodId,
                'periodLabel' => frozenPeriod.Period_Label__c,
                'reclassifiedCount' => reclassifiedCount,
                'reclassifiedAlertIds' => reclassifiedAlertIds
            });
            summaryAlert.Status__c = 'Failed';
            summaryAlert.Retry_Count__c = 0;
            summaryAlert.Original_Event_Time__c = Datetime.now();
            insert summaryAlert;
        }
    }

    /**
     * @description Extract the opportunityId from a Failed_Event__c Payload__c JSON string.
     * @param payloadJson The raw JSON payload
     * @return The Opportunity Id, or null if not found or not parseable
     */
    @TestVisible
    private static Id extractOpportunityId(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            return null;
        }

        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            Object oppIdObj = payload.get('opportunityId');
            if (oppIdObj != null) {
                String oppIdStr = String.valueOf(oppIdObj);
                if (String.isNotBlank(oppIdStr) && oppIdStr instanceof Id) {
                    return Id.valueOf(oppIdStr);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'PeriodFreezeHandler: Failed to parse Payload__c JSON: ' + e.getMessage());
        }

        return null;
    }
}
