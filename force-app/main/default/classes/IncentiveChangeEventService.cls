/**
 * @description Creates Incentive_Change_Event__c records to provide a complete
 *              audit trail for all commission-related changes.
 */
public with sharing class IncentiveChangeEventService {

    /**
     * @description Log a change event to the Incentive_Change_Event__c audit trail.
     * @param recordType The SObject type of the changed record (e.g., 'Opportunity', 'Comp_Calculation')
     * @param recordId The Id of the changed record
     * @param changeType The event type (e.g., 'MANUAL_ADJUSTMENT_CREATED')
     * @param oldValue The previous value (serialized if complex)
     * @param newValue The new value (serialized if complex)
     * @param context Additional context about the change
     */
    public static void logEvent(String recordType, Id recordId, String changeType,
                                String oldValue, String newValue, String context) {
        Incentive_Change_Event__c evt = new Incentive_Change_Event__c();
        evt.Record_Type_Field__c = recordType;
        evt.Record_Id__c = recordId;
        evt.Change_Type__c = changeType;
        evt.Old_Value__c = oldValue;
        evt.New_Value__c = newValue;
        evt.Changed_By__c = UserInfo.getUserId();
        evt.Changed_On__c = Datetime.now();
        evt.Change_Context__c = context;
        insert evt;
    }
}
