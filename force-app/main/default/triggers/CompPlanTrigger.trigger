/**
 * @description Fires on Comp_Plan__c updates to detect plan reassignment or
 *              status changes. Publishes PLAN_ASSIGNMENT_CHANGED platform events
 *              for downstream processing.
 */
trigger CompPlanTrigger on Comp_Plan__c (after update) {
    CompPlanTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}
