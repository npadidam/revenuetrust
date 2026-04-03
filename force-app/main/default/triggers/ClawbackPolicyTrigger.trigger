/**
 * @description Fires on Clawback_Policy__c changes to detect when clawback
 *              policies are inserted, updated, or deleted. Publishes
 *              CLAWBACK_POLICY_CHANGED platform events for downstream recalculation.
 */
trigger ClawbackPolicyTrigger on Clawback_Policy__c (after insert, after update, after delete) {
    ClawbackPolicyTriggerHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
