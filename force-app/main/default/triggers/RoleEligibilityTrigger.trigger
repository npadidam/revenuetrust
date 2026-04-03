/**
 * @description Fires on Template_Role_Eligibility__c changes to detect when
 *              role eligibility rules are inserted, updated, or deleted.
 *              Publishes ROLE_ELIGIBILITY_RULE_CHANGED platform events.
 */
trigger RoleEligibilityTrigger on Template_Role_Eligibility__c (after insert, after update, after delete) {
    RoleEligibilityTriggerHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
