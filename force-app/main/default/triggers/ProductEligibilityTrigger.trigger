/**
 * @description Fires on Template_Product_Eligibility__c changes to detect when
 *              product eligibility rules are inserted, updated, or deleted.
 *              Publishes PRODUCT_ELIGIBILITY_RULE_CHANGED platform events.
 */
trigger ProductEligibilityTrigger on Template_Product_Eligibility__c (after insert, after update, after delete) {
    ProductEligibilityTriggerHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
