/**
 * @description Handler for Governance_Eval_Event__e Platform Events.
 *              Evaluates governance rules against compensation context.
 *              Stub implementation — full governance engine built in later weeks.
 */
public with sharing class GovernanceEventHandler {

    public void handle(List<Governance_Eval_Event__e> events) {
        for (Governance_Eval_Event__e evt : events) {
            try {
                routeEvent(evt);
            } catch (Exception e) {
                logError(evt, e);
            }
        }
    }

    private void routeEvent(Governance_Eval_Event__e evt) {
        // Stub: governance evaluation engine will be implemented in Week 4+
        System.debug(LoggingLevel.INFO,
            'GovernanceEventHandler received event — Participant: ' + evt.Participant_Id__c +
            ' Action: ' + evt.Action_Type__c +
            ' Rule: ' + evt.Rule_Id__c
        );
    }

    private void logError(Governance_Eval_Event__e evt, Exception e) {
        System.debug(LoggingLevel.ERROR,
            'GovernanceEventHandler failed for Participant ' + evt.Participant_Id__c +
            ' Error: ' + e.getMessage() + ' ' + e.getStackTraceString()
        );
    }
}
