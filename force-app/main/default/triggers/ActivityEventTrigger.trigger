trigger ActivityEventTrigger on Event (after insert) {
    ActivityTriggerHandler.handleEventAfterInsert(Trigger.new);
}
