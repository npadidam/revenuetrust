/**
 * @description Manages the hold lifecycle on Comp_Calculation__c records.
 *              Supports applying and releasing holds, with audit trail via
 *              IncentiveChangeEventService.
 */
public with sharing class CommissionHoldService {

    /**
     * @description Apply a hold to a set of Comp_Calculation__c records.
     * @param calcIds List of Comp_Calculation__c Ids to hold
     * @param holdReason The reason for the hold
     */
    public static void applyHold(List<Id> calcIds, String holdReason) {
        List<Comp_Calculation__c> calcs = [
            SELECT Id, Hold_Status__c, Hold_Reason__c
            FROM Comp_Calculation__c
            WHERE Id IN :calcIds
        ];
        for (Comp_Calculation__c c : calcs) {
            c.Hold_Status__c = 'Held';
            c.Hold_Reason__c = holdReason;
        }
        update calcs;
        for (Comp_Calculation__c c : calcs) {
            IncentiveChangeEventService.logEvent(
                'Calculation', c.Id, 'COMMISSION_HOLD_APPLIED',
                'Not_Held', 'Held', holdReason);
        }
    }

    /**
     * @description Release a hold on a set of Comp_Calculation__c records.
     * @param calcIds List of Comp_Calculation__c Ids to release
     */
    public static void releaseHold(List<Id> calcIds) {
        List<Comp_Calculation__c> calcs = [
            SELECT Id, Hold_Status__c
            FROM Comp_Calculation__c
            WHERE Id IN :calcIds
        ];
        for (Comp_Calculation__c c : calcs) {
            c.Hold_Status__c = 'Released';
        }
        update calcs;
        for (Comp_Calculation__c c : calcs) {
            IncentiveChangeEventService.logEvent(
                'Calculation', c.Id, 'COMMISSION_HOLD_RELEASED',
                'Held', 'Released', null);
        }
    }
}
