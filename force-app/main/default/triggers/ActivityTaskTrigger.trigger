trigger ActivityTaskTrigger on Task (after insert) {
    ActivityTriggerHandler.handleTaskAfterInsert(Trigger.new);
}
