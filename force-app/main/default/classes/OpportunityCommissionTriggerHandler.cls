/**
 * @description Lightweight handler for the Opportunity trigger (AD-1).
 *              Detects commission-relevant changes and publishes Commission_Event__e.
 *              This is the ONLY code running in the subscriber's transaction context.
 */
public with sharing class OpportunityCommissionTriggerHandler {

    public static void handleAfterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        List<Commission_Event__e> events = new List<Commission_Event__e>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            // Deal closed (stage changed to Closed Won)
            if (opp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won') {
                events.add(buildEvent(opp, 'DEAL_CLOSED',
                    oldOpp.StageName, opp.StageName));
            }

            // Amount changed
            if (opp.Amount != oldOpp.Amount) {
                events.add(buildEvent(opp, 'AMOUNT_CHANGED',
                    String.valueOf(oldOpp.Amount), String.valueOf(opp.Amount)));
            }

            // Stage changed (any stage transition, excluding the DEAL_CLOSED already captured)
            if (opp.StageName != oldOpp.StageName
                && !(opp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won')) {
                events.add(buildEvent(opp, 'STAGE_CHANGED',
                    oldOpp.StageName, opp.StageName));
            }

            // Close date changed
            if (opp.CloseDate != oldOpp.CloseDate) {
                events.add(buildEvent(opp, 'CLOSE_DATE_CHANGED',
                    String.valueOf(oldOpp.CloseDate), String.valueOf(opp.CloseDate)));
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    private static Commission_Event__e buildEvent(
        Opportunity opp,
        String eventType,
        String previousValue,
        String newValue
    ) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = opp.Id;
        evt.Event_Type__c = eventType;
        evt.Previous_Value__c = previousValue;
        evt.New_Value__c = newValue;
        evt.User_Id__c = opp.OwnerId;
        return evt;
    }
}
