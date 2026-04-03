/**
 * @description Handler for CompPlanTrigger. Detects changes to Comp_Plan__c
 *              records — specifically plan reassignment (Plan_Template__c change)
 *              and status transitions (e.g., termination). Publishes
 *              PLAN_ASSIGNMENT_CHANGED platform events for downstream processing.
 */
public with sharing class CompPlanTriggerHandler {

    private static final String TRIGGER_NAME = 'CompPlanTrigger';
    private static final String EVENT_TYPE_ASSIGNMENT = 'PLAN_ASSIGNMENT_CHANGED';
    private static final String EVENT_TYPE_TERMINATED = 'PLAN_TERMINATED';

    public static void handleAfterUpdate(
        List<Comp_Plan__c> newList,
        Map<Id, Comp_Plan__c> oldMap
    ) {
        // 1. Check CMT kill switch
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        List<Commission_Event__e> events = new List<Commission_Event__e>();

        for (Comp_Plan__c plan : newList) {
            Comp_Plan__c oldPlan = oldMap.get(plan.Id);

            // ── Plan Template reassignment ──
            if (plan.Plan_Template__c != oldPlan.Plan_Template__c) {
                Map<String, Object> prevMap = new Map<String, Object>{
                    'Plan_Template__c' => oldPlan.Plan_Template__c,
                    'Status__c' => oldPlan.Status__c
                };
                Map<String, Object> newMap = new Map<String, Object>{
                    'Plan_Template__c' => plan.Plan_Template__c,
                    'Status__c' => plan.Status__c
                };
                events.add(buildEvent(
                    EVENT_TYPE_ASSIGNMENT,
                    JSON.serialize(prevMap),
                    JSON.serialize(newMap)
                ));
            }

            // ── Status changed to Terminated ──
            if (plan.Status__c != oldPlan.Status__c && plan.Status__c == 'Terminated') {
                Map<String, Object> prevMap = new Map<String, Object>{
                    'Plan_Template__c' => oldPlan.Plan_Template__c,
                    'Status__c' => oldPlan.Status__c
                };
                Map<String, Object> newMap = new Map<String, Object>{
                    'Plan_Template__c' => plan.Plan_Template__c,
                    'Status__c' => plan.Status__c
                };
                events.add(buildEvent(
                    EVENT_TYPE_TERMINATED,
                    JSON.serialize(prevMap),
                    JSON.serialize(newMap)
                ));
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    // ── Event builder ───────────────────────────────────────────────────

    private static Commission_Event__e buildEvent(
        String eventType,
        String previousValue,
        String newValue
    ) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = null;
        evt.Event_Type__c = eventType;
        evt.Previous_Value__c = previousValue;
        evt.New_Value__c = newValue;
        evt.User_Id__c = UserInfo.getUserId();
        return evt;
    }
}
