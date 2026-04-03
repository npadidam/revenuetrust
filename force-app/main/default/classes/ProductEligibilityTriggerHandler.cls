/**
 * @description Handler for ProductEligibilityTrigger. Detects changes to
 *              template product eligibility rules and publishes
 *              PRODUCT_ELIGIBILITY_RULE_CHANGED platform events.
 */
public with sharing class ProductEligibilityTriggerHandler {

    private static final String EVENT_TYPE = 'PRODUCT_ELIGIBILITY_RULE_CHANGED';
    private static final String TRIGGER_NAME = 'ProductEligibilityTrigger';

    public static void handleChange(
        List<SObject> newList,
        List<SObject> oldList,
        System.TriggerOperation operationType
    ) {
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        List<Commission_Event__e> events = new List<Commission_Event__e>();

        if (operationType == System.TriggerOperation.AFTER_INSERT) {
            for (SObject rec : newList) {
                events.add(buildEvent(null, rec));
            }
        } else if (operationType == System.TriggerOperation.AFTER_UPDATE) {
            Map<Id, SObject> oldMap = new Map<Id, SObject>(oldList);
            for (SObject rec : newList) {
                SObject oldRec = oldMap.get(rec.Id);
                events.add(buildEvent(oldRec, rec));
            }
        } else if (operationType == System.TriggerOperation.AFTER_DELETE) {
            for (SObject rec : oldList) {
                events.add(buildEvent(rec, null));
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    private static Commission_Event__e buildEvent(SObject oldRec, SObject newRec) {
        return new Commission_Event__e(
            Event_Type__c = EVENT_TYPE,
            Opportunity_Id__c = null,
            Previous_Value__c = oldRec != null ? JSON.serialize(oldRec) : null,
            New_Value__c = newRec != null ? JSON.serialize(newRec) : null,
            User_Id__c = UserInfo.getUserId()
        );
    }
}
