/**
 * @description Handler for OpportunityLineItem trigger.
 *              Detects product mix changes and publishes Commission_Event__e
 *              with Event_Type__c = PRODUCT_MIX_CHANGED and a Change_Subtype__c
 *              indicating the nature of the line item change.
 *
 *              Subtypes:
 *              - LINE_ADDED: New OLI inserted
 *              - LINE_REMOVED: OLI deleted
 *              - LINE_REPLACED: Product2Id changed on existing OLI
 *              - LINE_REPRICED: TotalPrice or UnitPrice changed
 *              - QUANTITY_CHANGED: Quantity changed
 */
public with sharing class OpportunityLineItemHandler {

    private static final String TRIGGER_NAME = 'OpportunityLineItemTrigger';
    private static final String EVENT_TYPE = 'PRODUCT_MIX_CHANGED';

    public static void handleAfterChange(
        List<OpportunityLineItem> newList,
        List<OpportunityLineItem> oldList,
        System.TriggerOperation operationType
    ) {
        // 1. Check CMT kill switch
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        List<Commission_Event__e> events = new List<Commission_Event__e>();

        if (operationType == System.TriggerOperation.AFTER_INSERT) {
            for (OpportunityLineItem oli : newList) {
                events.add(buildEvent(oli.OpportunityId, 'LINE_ADDED',
                    null, String.valueOf(oli.Product2Id)));
            }
        } else if (operationType == System.TriggerOperation.AFTER_DELETE) {
            for (OpportunityLineItem oli : oldList) {
                events.add(buildEvent(oli.OpportunityId, 'LINE_REMOVED',
                    String.valueOf(oli.Product2Id), null));
            }
        } else if (operationType == System.TriggerOperation.AFTER_UPDATE) {
            Map<Id, OpportunityLineItem> oldMap = new Map<Id, OpportunityLineItem>(oldList);
            for (OpportunityLineItem oli : newList) {
                OpportunityLineItem oldOli = oldMap.get(oli.Id);
                String subtype = determineUpdateSubtype(oli, oldOli);
                if (subtype != null) {
                    String prevVal = buildPreviousValue(oldOli, subtype);
                    String newVal = buildNewValue(oli, subtype);
                    events.add(buildEvent(oli.OpportunityId, subtype, prevVal, newVal));
                }
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    /**
     * @description Determine the most significant change subtype for an OLI update.
     *              Priority: Product swap > Price change > Quantity change.
     */
    private static String determineUpdateSubtype(
        OpportunityLineItem oli, OpportunityLineItem oldOli
    ) {
        if (oli.Product2Id != oldOli.Product2Id) {
            return 'LINE_REPLACED';
        }
        if (oli.TotalPrice != oldOli.TotalPrice || oli.UnitPrice != oldOli.UnitPrice) {
            return 'LINE_REPRICED';
        }
        if (oli.Quantity != oldOli.Quantity) {
            return 'QUANTITY_CHANGED';
        }
        return null;
    }

    private static String buildPreviousValue(OpportunityLineItem oldOli, String subtype) {
        if (subtype == 'LINE_REPLACED') {
            return String.valueOf(oldOli.Product2Id);
        } else if (subtype == 'LINE_REPRICED') {
            return 'UnitPrice=' + oldOli.UnitPrice + ';TotalPrice=' + oldOli.TotalPrice;
        } else if (subtype == 'QUANTITY_CHANGED') {
            return String.valueOf(oldOli.Quantity);
        }
        return null;
    }

    private static String buildNewValue(OpportunityLineItem oli, String subtype) {
        if (subtype == 'LINE_REPLACED') {
            return String.valueOf(oli.Product2Id);
        } else if (subtype == 'LINE_REPRICED') {
            return 'UnitPrice=' + oli.UnitPrice + ';TotalPrice=' + oli.TotalPrice;
        } else if (subtype == 'QUANTITY_CHANGED') {
            return String.valueOf(oli.Quantity);
        }
        return null;
    }

    private static Commission_Event__e buildEvent(
        Id opportunityId,
        String changeSubtype,
        String previousValue,
        String newValue
    ) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = opportunityId;
        evt.Event_Type__c = EVENT_TYPE;
        evt.Change_Subtype__c = changeSubtype;
        evt.Previous_Value__c = previousValue;
        evt.New_Value__c = newValue;
        evt.User_Id__c = UserInfo.getUserId();
        return evt;
    }
}
