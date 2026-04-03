/**
 * @description Handler for ForecastPeriodTrigger. Detects two transitions:
 *              1. Status__c changing TO 'Frozen' — calls PeriodFreezeHandler
 *                 directly (synchronous, not via platform event).
 *              2. Status__c changing FROM 'Frozen' — publishes PERIOD_REOPENED
 *                 Commission_Event__e for downstream consumers.
 */
public with sharing class ForecastPeriodTriggerHandler {

    private static final String TRIGGER_NAME = 'ForecastPeriodTrigger';
    private static final String FROZEN_STATUS = 'Frozen';
    private static final String PERIOD_REOPENED_TYPE = 'PERIOD_REOPENED';

    public static void handleChange(
        List<SObject> newList,
        List<SObject> oldList,
        System.TriggerOperation operationType
    ) {
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        if (operationType != System.TriggerOperation.AFTER_UPDATE) {
            return;
        }

        Map<Id, SObject> oldMap = new Map<Id, SObject>(oldList);
        List<Commission_Event__e> reopenedEvents = new List<Commission_Event__e>();

        for (SObject rec : newList) {
            Forecast_Period__c newPeriod = (Forecast_Period__c) rec;
            Forecast_Period__c oldPeriod = (Forecast_Period__c) oldMap.get(rec.Id);

            String newStatus = newPeriod.Status__c;
            String oldStatus = oldPeriod.Status__c;

            // Detect transition TO Frozen
            if (newStatus == FROZEN_STATUS && oldStatus != FROZEN_STATUS) {
                PeriodFreezeHandler.handlePeriodFreeze(newPeriod.Id);
            }

            // Detect transition FROM Frozen (period reopened)
            if (oldStatus == FROZEN_STATUS && newStatus != FROZEN_STATUS) {
                reopenedEvents.add(new Commission_Event__e(
                    Event_Type__c = PERIOD_REOPENED_TYPE,
                    Opportunity_Id__c = null,
                    Previous_Value__c = JSON.serialize(oldPeriod),
                    New_Value__c = JSON.serialize(newPeriod),
                    User_Id__c = UserInfo.getUserId()
                ));
            }
        }

        if (!reopenedEvents.isEmpty()) {
            EventPublisherService.publishCommissionEvents(reopenedEvents);
        }
    }
}
