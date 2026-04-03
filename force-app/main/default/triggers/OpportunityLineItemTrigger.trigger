trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert, after update, after delete) {
    OpportunityLineItemHandler.handleAfterChange(Trigger.new, Trigger.old, Trigger.operationType);
}
