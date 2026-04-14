/**
 * @description Generic trigger handler for commissioning on ANY SObject.
 *              Subscriber creates a trigger on their custom object that calls this handler.
 *
 *              Example subscriber trigger for Order:
 *              trigger OrderCommissionTrigger on Order (after update) {
 *                  REVT.GenericCommissionTriggerHandler.handleAfterUpdate(
 *                      Trigger.new, Trigger.oldMap, 'Order');
 *              }
 *
 *              Example for custom Policy__c:
 *              trigger PolicyCommissionTrigger on Policy__c (after update) {
 *                  REVT.GenericCommissionTriggerHandler.handleAfterUpdate(
 *                      Trigger.new, Trigger.oldMap, 'Policy__c');
 *              }
 */
public with sharing class GenericCommissionTriggerHandler {

    public static void handleAfterUpdate(List<SObject> newList, Map<Id, SObject> oldMap, String objectName) {
        if (!TriggerControlService.isEnabled('GenericCommissionTrigger_' + objectName)) {
            return;
        }

        // Load stage/amount/date field names from PipelineObjectService
        List<Commission_Event__e> events = new List<Commission_Event__e>();

        // Load won/lost stages from config
        Set<String> wonStages = loadWonStages();
        Set<String> lostStages = loadLostStages();

        for (SObject record : newList) {
            SObject oldRecord = oldMap.get(record.Id);

            String newStage = String.valueOf(PipelineObjectService.getFieldValue(record, 'Pipeline.Stage'));
            String oldStage = String.valueOf(PipelineObjectService.getFieldValue(oldRecord, 'Pipeline.Stage'));

            // Deal closed
            if (wonStages.contains(newStage) && !wonStages.contains(oldStage)) {
                events.add(buildEvent(record.Id, 'DEAL_CLOSED', oldStage, newStage));
            }

            // Deal lost
            if (lostStages.contains(newStage) && !lostStages.contains(oldStage)) {
                events.add(buildEvent(record.Id, 'DEAL_LOST', oldStage, newStage));
            }

            // Deal reopened
            if ((wonStages.contains(oldStage) || lostStages.contains(oldStage))
                && !wonStages.contains(newStage) && !lostStages.contains(newStage)) {
                events.add(buildEvent(record.Id, 'DEAL_REOPENED', oldStage, newStage));
            }

            // Amount changed
            Decimal newAmt = PipelineObjectService.getAmount(record);
            Decimal oldAmt = PipelineObjectService.getAmount(oldRecord);
            if (newAmt != oldAmt) {
                String eventType = wonStages.contains(newStage) ?
                    'AMOUNT_CHANGED_POST_CLOSE' : 'AMOUNT_CHANGED';
                events.add(buildEvent(record.Id, eventType,
                    String.valueOf(oldAmt), String.valueOf(newAmt)));
            }

            // Close date changed
            Date newDate = PipelineObjectService.getCloseDate(record);
            Date oldDate = PipelineObjectService.getCloseDate(oldRecord);
            if (newDate != oldDate) {
                String eventType = wonStages.contains(newStage) ?
                    'CLOSE_DATE_CHANGED_POST_CLOSE' : 'CLOSE_DATE_CHANGED';
                events.add(buildEvent(record.Id, eventType,
                    String.valueOf(oldDate), String.valueOf(newDate)));
            }

            // Owner changed
            Id newOwner = PipelineObjectService.getOwnerId(record);
            Id oldOwner = PipelineObjectService.getOwnerId(oldRecord);
            if (newOwner != oldOwner) {
                String eventType = wonStages.contains(newStage) ?
                    'OWNER_CHANGED_POST_CLOSE' : 'OWNER_CHANGED';
                events.add(buildEvent(record.Id, eventType,
                    String.valueOf(oldOwner), String.valueOf(newOwner)));
            }

            // Stage changed (non-terminal)
            if (newStage != oldStage && !wonStages.contains(newStage) && !lostStages.contains(newStage)
                && !wonStages.contains(oldStage) && !lostStages.contains(oldStage)) {
                events.add(buildEvent(record.Id, 'STAGE_CHANGED', oldStage, newStage));
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    private static Commission_Event__e buildEvent(Id recordId, String eventType, String oldVal, String newVal) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = recordId; // Field name is "Opportunity_Id" but holds any record ID
        evt.Event_Type__c = eventType;
        evt.Previous_Value__c = oldVal;
        evt.New_Value__c = newVal;
        evt.User_Id__c = UserInfo.getUserId();
        return evt;
    }

    private static Set<String> loadWonStages() {
        Set<String> stages = new Set<String>{ 'Closed Won' };
        List<Incentive_Configuration__c> configs = [
            SELECT Won_Stages__c FROM Incentive_Configuration__c
            WHERE Is_Active__c = true LIMIT 1
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

    private static Set<String> loadLostStages() {
        Set<String> stages = new Set<String>{ 'Closed Lost' };
        List<Incentive_Configuration__c> configs = [
            SELECT Lost_Stages__c FROM Incentive_Configuration__c
            WHERE Is_Active__c = true LIMIT 1
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
}
