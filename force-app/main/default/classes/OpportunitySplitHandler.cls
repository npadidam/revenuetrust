/**
 * @description Handler for OpportunitySplit trigger.
 *              Publishes SPLIT_CHANGED / SPLIT_CHANGED_POST_CLOSE events.
 *
 *              NOTE: OpportunitySplit requires Team Selling to be enabled.
 *              The trigger is NOT included in the package — must be created
 *              post-install in subscriber orgs that have Team Selling.
 *              This handler uses dynamic SObject so it compiles in any org.
 *
 *              Post-install trigger for subscriber:
 *              trigger OpportunitySplitTrigger on OpportunitySplit (after insert, after update, after delete) {
 *                  REVT.OpportunitySplitHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
 *              }
 */
public with sharing class OpportunitySplitHandler {

    public static void handleChange(List<SObject> newList, List<SObject> oldList, System.TriggerOperation operationType) {
        if (!TriggerControlService.isEnabled('OpportunitySplitTrigger')) {
            return;
        }

        List<Commission_Event__e> events = new List<Commission_Event__e>();
        Set<Id> oppIds = new Set<Id>();
        List<SObject> workingList = (newList != null) ? newList : oldList;

        for (SObject s : workingList) {
            Id oppId = (Id) s.get('OpportunityId');
            if (oppId != null) oppIds.add(oppId);
        }
        if (oppIds.isEmpty()) return;

        Set<String> wonStages = loadWonStages();
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]);

        if (operationType == System.TriggerOperation.AFTER_INSERT) {
            for (SObject s : newList) {
                Id oppId = (Id) s.get('OpportunityId');
                Boolean isPost = isPostClose(oppMap.get(oppId), wonStages);
                events.add(buildEvent(oppId, isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                    null, String.valueOf(s.get('SplitPercentage'))));
            }
        } else if (operationType == System.TriggerOperation.AFTER_DELETE) {
            for (SObject s : oldList) {
                Id oppId = (Id) s.get('OpportunityId');
                Boolean isPost = isPostClose(oppMap.get(oppId), wonStages);
                events.add(buildEvent(oppId, isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                    String.valueOf(s.get('SplitPercentage')), null));
            }
        } else if (operationType == System.TriggerOperation.AFTER_UPDATE) {
            Map<Id, SObject> oldMap = new Map<Id, SObject>();
            for (SObject s : oldList) oldMap.put(s.Id, s);
            for (SObject s : newList) {
                SObject oldS = oldMap.get(s.Id);
                if (s.get('SplitPercentage') != oldS.get('SplitPercentage') ||
                    s.get('SplitOwnerId') != oldS.get('SplitOwnerId')) {
                    Id oppId = (Id) s.get('OpportunityId');
                    Boolean isPost = isPostClose(oppMap.get(oppId), wonStages);
                    events.add(buildEvent(oppId, isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                        String.valueOf(oldS.get('SplitPercentage')), String.valueOf(s.get('SplitPercentage'))));
                }
            }
        }

        if (!events.isEmpty()) EventPublisherService.publishCommissionEvents(events);
    }

    private static Boolean isPostClose(Opportunity opp, Set<String> wonStages) {
        return opp != null && wonStages.contains(opp.StageName);
    }

    private static Commission_Event__e buildEvent(Id oppId, String eventType, String oldVal, String newVal) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = oppId;
        evt.Event_Type__c = eventType;
        evt.Previous_Value__c = oldVal;
        evt.New_Value__c = newVal;
        evt.User_Id__c = UserInfo.getUserId();
        return evt;
    }

    private static Set<String> loadWonStages() {
        Set<String> stages = new Set<String>{ 'Closed Won' };
        List<Incentive_Configuration__c> configs = [
            SELECT Won_Stages__c FROM Incentive_Configuration__c WHERE Is_Active__c = true LIMIT 1];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Won_Stages__c)) {
            stages.clear();
            for (String s : configs[0].Won_Stages__c.split(',')) {
                String trimmed = s.trim();
                if (String.isNotBlank(trimmed)) stages.add(trimmed);
            }
        }
        return stages;
    }
}
