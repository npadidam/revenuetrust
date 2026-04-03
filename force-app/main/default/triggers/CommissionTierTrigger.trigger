/**
 * @description Fires on Commission_Tier__c changes to detect when commission
 *              rate tiers are inserted, updated, or deleted. Publishes
 *              RATE_TABLE_CHANGED platform events for downstream recalculation.
 */
trigger CommissionTierTrigger on Commission_Tier__c (after insert, after update, after delete) {
    CommissionTierTriggerHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
