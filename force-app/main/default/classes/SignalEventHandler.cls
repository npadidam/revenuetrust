/**
 * @description Handler for Signal_Event__e Platform Events.
 *              Processes incoming signal data from adapters (CRM, Gong, Momentum, etc.).
 *              Stub implementation — full signal processing built in later weeks.
 */
public with sharing class SignalEventHandler {

    public void handle(List<Signal_Event__e> events) {
        if (!TriggerControlService.isEnabled('SignalEventTrigger')) {
            return;
        }
        for (Signal_Event__e evt : events) {
            try {
                routeEvent(evt);
            } catch (Exception e) {
                logError(evt, e);
            }
        }
    }

    private void routeEvent(Signal_Event__e evt) {
        // Stub: signal processing engine will be implemented in Week 7+
        System.debug(LoggingLevel.INFO,
            'SignalEventHandler received event — Opportunity: ' + evt.Opportunity_Id__c +
            ' Source: ' + evt.Signal_Source__c
        );
    }

    private void logError(Signal_Event__e evt, Exception e) {
        System.debug(LoggingLevel.ERROR,
            'SignalEventHandler failed for Opportunity ' + evt.Opportunity_Id__c +
            ' Error: ' + e.getMessage() + ' ' + e.getStackTraceString()
        );
    }
}
