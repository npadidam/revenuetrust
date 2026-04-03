/**
 * @description Fires on Plan_Cap__c changes to detect when commission cap
 *              rules are inserted, updated, or deleted. Publishes
 *              CAP_RULE_CHANGED platform events for downstream recalculation.
 */
trigger PlanCapTrigger on Plan_Cap__c (after insert, after update, after delete) {
    PlanCapTriggerHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
