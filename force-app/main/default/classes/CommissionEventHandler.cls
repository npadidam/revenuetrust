/**
 * @description Handler for Commission_Event__e Platform Events.
 *              Routes events by Event_Type__c to the CommissionService for processing.
 *              Failed events are logged for retry via error handling.
 */
public with sharing class CommissionEventHandler {

    public void handle(List<Commission_Event__e> events) {
        for (Commission_Event__e evt : events) {
            try {
                routeEvent(evt);
            } catch (Exception e) {
                logError(evt, e);
            }
        }
    }

    private void routeEvent(Commission_Event__e evt) {
        String eventType = evt.Event_Type__c;
        Id opportunityId = Id.valueOf(evt.Opportunity_Id__c);

        if (eventType == 'DEAL_CLOSED') {
            CommissionService.processOpportunity(opportunityId);
        } else if (eventType == 'AMOUNT_CHANGED') {
            CommissionService.processOpportunity(opportunityId);
        } else if (eventType == 'STAGE_CHANGED') {
            // Stage changes may affect projected calculations
            CommissionService.processOpportunity(opportunityId);
        } else if (eventType == 'CLOSE_DATE_CHANGED') {
            // Close date changes may affect period assignment
            CommissionService.processOpportunity(opportunityId);
        }
    }

    private void logError(Commission_Event__e evt, Exception e) {
        System.debug(LoggingLevel.ERROR,
            'CommissionEventHandler failed for Opportunity ' + evt.Opportunity_Id__c +
            ' Event_Type: ' + evt.Event_Type__c +
            ' Error: ' + e.getMessage() + ' ' + e.getStackTraceString()
        );
    }
}
