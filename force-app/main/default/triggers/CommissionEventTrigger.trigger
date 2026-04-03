/**
 * @description Trigger on Commission_Event__e — delegates to CommissionEventHandler.
 */
trigger CommissionEventTrigger on Commission_Event__e (after insert) {
    new CommissionEventHandler().handle(Trigger.new);
}
