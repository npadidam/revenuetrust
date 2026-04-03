/**
 * @description Lightweight trigger on Opportunity (AD-1).
 *              Publishes Commission_Event__e on deal close, amount change,
 *              stage change, and close date change.
 */
trigger OpportunityCommissionTrigger on Opportunity (after update) {
    OpportunityCommissionTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}
