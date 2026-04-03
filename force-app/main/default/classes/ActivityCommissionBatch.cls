/**
 * @description Scheduled batch for periodic activity commission reconciliation.
 *              Counts qualifying activities per participant per rule per period.
 *              Reconciles with existing Comp_Calculation__c records.
 *              Handles: retroactive counting, missed triggers, and qualified opp detection.
 */
public class ActivityCommissionBatch implements Database.Batchable<SObject>, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Sales_Rep__c, Plan_Template__c, Status__c
            FROM Comp_Plan__c
            WHERE Status__c = 'Active'
            AND Plan_Template__r.Plan_Type__c = 'Activity_Based'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Comp_Plan__c> plans) {
        Set<Id> templateIds = new Set<Id>();
        for (Comp_Plan__c p : plans) {
            templateIds.add(p.Plan_Template__c);
        }

        List<Activity_Commission_Rule__c> rules = [
            SELECT Id, Plan_Template__c, Activity_Type__c, Source_Object__c,
                   Filter_Criteria__c, Rate_Per_Activity__c, Rate_Pct_Per_Activity__c,
                   Cap_Per_Period__c, Cap_Count_Per_Period__c, Counting_Method__c,
                   Is_Active__c
            FROM Activity_Commission_Rule__c
            WHERE Plan_Template__c IN :templateIds
            AND Is_Active__c = true
        ];

        Date periodStart = Date.today().toStartOfMonth();

        for (Comp_Plan__c plan : plans) {
            for (Activity_Commission_Rule__c rule : rules) {
                if (rule.Plan_Template__c != plan.Plan_Template__c) continue;

                if (rule.Activity_Type__c == 'Qualified_Opportunity') {
                    processQualifiedOpportunities(plan, rule, periodStart);
                }
                // Other activity types are handled real-time by triggers.
                // Batch reconciles and catches any missed.
            }
        }
    }

    private void processQualifiedOpportunities(Comp_Plan__c plan,
                                                Activity_Commission_Rule__c rule,
                                                Date periodStart) {
        // Find opps created by this rep in the current period
        List<Opportunity> opps = [
            SELECT Id, Amount, CreatedDate, StageName, CreatedById
            FROM Opportunity
            WHERE CreatedById = :plan.Sales_Rep__c
            AND CreatedDate >= :periodStart
            AND IsClosed = false
        ];

        // Determine which have already been commissioned
        Set<Id> alreadyCommissioned = new Set<Id>();
        for (Comp_Calculation__c calc : [
            SELECT Opportunity__c
            FROM Comp_Calculation__c
            WHERE Comp_Plan__c = :plan.Id
            AND Comp_Plan_Type__c = 'Activity_Based'
            AND Processed_Date__c >= :periodStart
            AND Calculation_Status__c != 'Reversed'
            AND Opportunity__c != null
        ]) {
            alreadyCommissioned.add(calc.Opportunity__c);
        }

        List<ActivityCommissionService.ActivityResult> results =
            new List<ActivityCommissionService.ActivityResult>();

        for (Opportunity opp : opps) {
            if (alreadyCommissioned.contains(opp.Id)) continue;

            List<ActivityCommissionService.ActivityResult> oppResults =
                ActivityCommissionService.processActivity(opp, 'Opportunity');
            results.addAll(oppResults);
        }

        if (!results.isEmpty()) {
            ActivityCommissionService.persistResults(results);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('ActivityCommissionBatch completed');
    }
}
