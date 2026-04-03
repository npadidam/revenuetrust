/**
 * @description Trigger on Deal_Credit_Split__c — RevenueTrust's own split object.
 *              Detects split changes and publishes events for commission recalculation.
 *              Also validates split totals (must sum to 100% per deal).
 */
trigger DealCreditSplitTrigger on Deal_Credit_Split__c (before insert, before update, after insert, after update, after delete) {
    DealCreditSplitHandler.handleTrigger(Trigger.new, Trigger.old, Trigger.operationType);
}
