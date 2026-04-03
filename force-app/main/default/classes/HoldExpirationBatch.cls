/**
 * @description Scheduled batch job that detects and expires commission holds
 *              that have exceeded their maximum hold duration. Reads the
 *              Release_Days__c from Plan_Hold__c configuration records and
 *              compares against the hold's CreatedDate.
 *
 *              Schedule example:
 *              System.schedule('Hold Expiration - Daily',
 *                  '0 0 2 * * ?', new HoldExpirationBatch());
 */
public class HoldExpirationBatch implements Database.Batchable<SObject>, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Hold_Status__c, Hold_Reason__c,
                   Comp_Plan__c, Comp_Plan__r.Plan_Template__c,
                   CreatedDate
            FROM Comp_Calculation__c
            WHERE Hold_Status__c = 'Held'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Comp_Calculation__c> scope) {
        // Collect all template IDs
        Set<Id> templateIds = new Set<Id>();
        for (Comp_Calculation__c calc : scope) {
            if (calc.Comp_Plan__r.Plan_Template__c != null) {
                templateIds.add(calc.Comp_Plan__r.Plan_Template__c);
            }
        }

        // Query Plan_Hold__c for release days
        Map<Id, Decimal> templateReleaseDays = new Map<Id, Decimal>();
        for (Plan_Hold__c ph : [
            SELECT Plan_Template__c, Release_Days__c
            FROM Plan_Hold__c
            WHERE Plan_Template__c IN :templateIds
            AND Release_Days__c != null
            AND Is_Active__c = true
        ]) {
            // Use the shortest release window for safety
            if (!templateReleaseDays.containsKey(ph.Plan_Template__c) ||
                ph.Release_Days__c < templateReleaseDays.get(ph.Plan_Template__c)) {
                templateReleaseDays.put(ph.Plan_Template__c, ph.Release_Days__c);
            }
        }

        // Check each calc for expiration
        List<Id> expiredCalcIds = new List<Id>();
        for (Comp_Calculation__c calc : scope) {
            Id templateId = calc.Comp_Plan__r.Plan_Template__c;
            if (templateId != null && templateReleaseDays.containsKey(templateId)) {
                Decimal maxDays = templateReleaseDays.get(templateId);
                Long daysSinceHold = calc.CreatedDate.date().daysBetween(Date.today());
                if (daysSinceHold > maxDays) {
                    expiredCalcIds.add(calc.Id);
                }
            }
        }

        // Expire the holds
        if (!expiredCalcIds.isEmpty()) {
            List<Comp_Calculation__c> toExpire = [
                SELECT Id, Hold_Status__c
                FROM Comp_Calculation__c
                WHERE Id IN :expiredCalcIds
            ];
            for (Comp_Calculation__c c : toExpire) {
                c.Hold_Status__c = 'Expired';
            }
            update toExpire;

            // Log each expiration
            for (Comp_Calculation__c c : toExpire) {
                IncentiveChangeEventService.logEvent(
                    'Calculation', c.Id, 'COMMISSION_HOLD_EXPIRED',
                    'Held', 'Expired',
                    'Hold expired after exceeding maximum hold duration');
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Could send notification summary here
    }
}
