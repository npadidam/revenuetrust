/**
 * @description Trigger on Signal_Event__e — delegates to SignalEventHandler.
 */
trigger SignalEventTrigger on Signal_Event__e (after insert) {
    new SignalEventHandler().handle(Trigger.new);
}
