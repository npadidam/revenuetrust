/**
 * @description Handler for Task and Event triggers.
 *              Evaluates activity-based commission rules for BDR/SDR plans.
 *              Also handles qualified Opportunity creation (BDR-sourced opps).
 */
public with sharing class ActivityTriggerHandler {

    public static void handleTaskAfterInsert(List<Task> tasks) {
        if (!TriggerControlService.isEnabled('ActivityTaskTrigger')) return;
        processActivities(tasks, 'Task');
    }

    public static void handleEventAfterInsert(List<Event> events) {
        if (!TriggerControlService.isEnabled('ActivityEventTrigger')) return;
        processActivities(events, 'Event');
    }

    public static void handleOpportunityCreated(List<Opportunity> opps) {
        if (!TriggerControlService.isEnabled('ActivityOpportunityTrigger')) return;
        processActivities(opps, 'Opportunity');
    }

    private static void processActivities(List<SObject> records, String objectType) {
        List<ActivityCommissionService.ActivityResult> allResults =
            new List<ActivityCommissionService.ActivityResult>();

        for (SObject record : records) {
            List<ActivityCommissionService.ActivityResult> results =
                ActivityCommissionService.processActivity(record, objectType);
            allResults.addAll(results);
        }

        if (!allResults.isEmpty()) {
            ActivityCommissionService.persistResults(allResults);
        }
    }
}
