/**
 * @description Reusable utility for publishing RevenueTrust Platform Events.
 *              Supports Commission_Event__e, Governance_Eval_Event__e, and Signal_Event__e.
 *              Validates required fields before publish and returns SaveResult for callers to inspect.
 */
public with sharing class EventPublisherService {

    public static List<Database.SaveResult> publishCommissionEvents(List<Commission_Event__e> events) {
        if (events == null || events.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        for (Commission_Event__e evt : events) {
            validateCommissionEvent(evt);
        }
        return EventBus.publish(events);
    }

    public static List<Database.SaveResult> publishGovernanceEvents(List<Governance_Eval_Event__e> events) {
        if (events == null || events.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        for (Governance_Eval_Event__e evt : events) {
            validateGovernanceEvent(evt);
        }
        return EventBus.publish(events);
    }

    public static List<Database.SaveResult> publishSignalEvents(List<Signal_Event__e> events) {
        if (events == null || events.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        for (Signal_Event__e evt : events) {
            validateSignalEvent(evt);
        }
        return EventBus.publish(events);
    }

    public static Database.SaveResult publishCommissionEvent(Commission_Event__e evt) {
        List<Database.SaveResult> results = publishCommissionEvents(new List<Commission_Event__e>{ evt });
        return results[0];
    }

    public static Database.SaveResult publishGovernanceEvent(Governance_Eval_Event__e evt) {
        List<Database.SaveResult> results = publishGovernanceEvents(new List<Governance_Eval_Event__e>{ evt });
        return results[0];
    }

    public static Database.SaveResult publishSignalEvent(Signal_Event__e evt) {
        List<Database.SaveResult> results = publishSignalEvents(new List<Signal_Event__e>{ evt });
        return results[0];
    }

    private static void validateCommissionEvent(Commission_Event__e evt) {
        if (String.isBlank(evt.Opportunity_Id__c)) {
            throw new EventPublisherException('Commission_Event__e requires Opportunity_Id__c');
        }
        if (String.isBlank(evt.Event_Type__c)) {
            throw new EventPublisherException('Commission_Event__e requires Event_Type__c');
        }
    }

    private static void validateGovernanceEvent(Governance_Eval_Event__e evt) {
        if (String.isBlank(evt.Participant_Id__c)) {
            throw new EventPublisherException('Governance_Eval_Event__e requires Participant_Id__c');
        }
        if (String.isBlank(evt.Action_Type__c)) {
            throw new EventPublisherException('Governance_Eval_Event__e requires Action_Type__c');
        }
    }

    private static void validateSignalEvent(Signal_Event__e evt) {
        if (String.isBlank(evt.Opportunity_Id__c)) {
            throw new EventPublisherException('Signal_Event__e requires Opportunity_Id__c');
        }
        if (String.isBlank(evt.Signal_Source__c)) {
            throw new EventPublisherException('Signal_Event__e requires Signal_Source__c');
        }
    }

    public class EventPublisherException extends Exception {}
}
