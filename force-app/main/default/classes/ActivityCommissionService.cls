/**
 * @description Evaluates Activity_Commission_Rule__c rules against Tasks/Events
 *              and qualified Opportunity creation. Creates Comp_Calculation__c
 *              records for qualifying activities.
 *
 *              Supports:
 *              - Qualified meetings (Events with configured criteria)
 *              - Qualified opportunities (Opportunities created by BDR meeting criteria)
 *              - Calls logged (Tasks with Type = Call)
 *              - Demos completed (Events with configured criteria)
 *              - Custom activities (configurable source object + filter)
 *
 *              Called from:
 *              - ActivityTriggerHandler (real-time on Task/Event create)
 *              - ActivityCommissionBatch (periodic counting/reconciliation)
 */
public with sharing class ActivityCommissionService {

    public class ActivityResult {
        public Id participantId;
        public Id compPlanId;
        public Id activityRuleId;
        public Id activityRecordId;
        public String activityType;
        public Decimal commissionAmount;
        public String description;
    }

    /**
     * Process a single activity (Task or Event) for commission eligibility.
     * Called from the trigger handler.
     */
    public static List<ActivityResult> processActivity(SObject activity, String objectType) {
        List<ActivityResult> results = new List<ActivityResult>();

        // 1. Determine the participant (who gets credit)
        Id participantId = (Id) activity.get('OwnerId');
        if (objectType == 'Opportunity') {
            participantId = (Id) activity.get('CreatedById');
        }
        if (participantId == null) return results;

        // 2. Find active Comp_Plan__c for this participant with Activity_Based plan type
        List<Comp_Plan__c> plans = [
            SELECT Id, Plan_Template__c, Sales_Rep__c, Status__c,
                   Plan_Template__r.Plan_Type__c
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :participantId
            AND Status__c = 'Active'
            AND Plan_Template__r.Plan_Type__c = 'Activity_Based'
            LIMIT 10
        ];

        if (plans.isEmpty()) return results;

        // 3. For each plan, check Activity_Commission_Rule__c
        Set<Id> templateIds = new Set<Id>();
        Map<Id, Comp_Plan__c> templateToPlan = new Map<Id, Comp_Plan__c>();
        for (Comp_Plan__c p : plans) {
            templateIds.add(p.Plan_Template__c);
            templateToPlan.put(p.Plan_Template__c, p);
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

        for (Activity_Commission_Rule__c rule : rules) {
            // 4. Check if this activity matches the rule
            if (matchesRule(activity, objectType, rule)) {
                Comp_Plan__c plan = templateToPlan.get(rule.Plan_Template__c);

                // 5. Check caps (period count and amount)
                if (isWithinCaps(plan.Id, rule)) {
                    // 6. Calculate commission
                    Decimal amount = calculateActivityCommission(activity, rule);

                    if (amount > 0) {
                        ActivityResult result = new ActivityResult();
                        result.participantId = plan.Sales_Rep__c;
                        result.compPlanId = plan.Id;
                        result.activityRuleId = rule.Id;
                        result.activityRecordId = activity.Id;
                        result.activityType = rule.Activity_Type__c;
                        result.commissionAmount = amount;
                        result.description = rule.Activity_Type__c + ' - ' + objectType + ' ' + activity.Id;
                        results.add(result);
                    }
                }
            }
        }

        return results;
    }

    /**
     * Persist activity commission results as Comp_Calculation__c records.
     */
    public static void persistResults(List<ActivityResult> results) {
        if (results.isEmpty()) return;

        List<Comp_Calculation__c> calcs = new List<Comp_Calculation__c>();
        for (ActivityResult r : results) {
            Comp_Calculation__c calc = new Comp_Calculation__c();
            calc.Comp_Plan__c = r.compPlanId;
            calc.Rep__c = r.participantId;
            calc.Eligible_Commission__c = r.commissionAmount;
            calc.Commisionable_Value__c = r.commissionAmount;
            calc.Applied_Percentage__c = 100;
            calc.Type__c = 'Base';
            calc.Comp_Plan_Type__c = 'Activity_Based';
            calc.Calculation_Status__c = 'Projected';
            calc.Adjustment_Type__c = 'Original';
            calc.Processed_Date__c = Date.today();
            calc.Contract_Date2__c = Date.today();
            calc.Comments__c = r.description;
            calc.Rate_Tier_Applied__c = 'Activity: ' + r.activityType;
            calc.Processing_Run_Id__c = 'ACT-' + String.valueOf(Datetime.now().getTime());
            calcs.add(calc);
        }

        insert calcs;

        // Audit trail
        for (Integer i = 0; i < results.size(); i++) {
            IncentiveChangeEventService.logEvent(
                'Calculation', calcs[i].Id, 'Calculation_Processed',
                null, String.valueOf(results[i].commissionAmount),
                'Activity commission: ' + results[i].activityType);
        }
    }

    /**
     * Check if an activity matches a rule's criteria.
     */
    @TestVisible
    private static Boolean matchesRule(SObject activity, String objectType, Activity_Commission_Rule__c rule) {
        // Check source object match
        if (rule.Source_Object__c != null && rule.Source_Object__c != objectType) {
            return false;
        }

        // Check activity type mapping
        String activityType = rule.Activity_Type__c;

        if (activityType == 'Qualified_Meeting' && objectType == 'Event') {
            String eventType = (String) activity.get('Type');
            if (eventType == null) return false;
            return matchesFilterCriteria(activity, rule.Filter_Criteria__c);
        }
        else if (activityType == 'Call_Logged' && objectType == 'Task') {
            String taskType = (String) activity.get('Type');
            return taskType != null && taskType.equalsIgnoreCase('Call');
        }
        else if (activityType == 'Demo_Completed' && objectType == 'Event') {
            return matchesFilterCriteria(activity, rule.Filter_Criteria__c);
        }
        else if (activityType == 'Qualified_Opportunity' && objectType == 'Opportunity') {
            return matchesFilterCriteria(activity, rule.Filter_Criteria__c);
        }
        else if (activityType == 'Custom') {
            return matchesFilterCriteria(activity, rule.Filter_Criteria__c);
        }

        return false;
    }

    /**
     * Evaluate JSON filter criteria against an SObject.
     * Format: {"Type": "Demo", "Status": "Completed"}
     * All conditions must match (AND logic).
     */
    @TestVisible
    private static Boolean matchesFilterCriteria(SObject record, String filterJson) {
        if (String.isBlank(filterJson)) return true;

        try {
            Map<String, Object> criteria = (Map<String, Object>) JSON.deserializeUntyped(filterJson);
            for (String fieldName : criteria.keySet()) {
                Object expectedValue = criteria.get(fieldName);
                Object actualValue = record.get(fieldName);
                if (actualValue == null || !String.valueOf(actualValue).equalsIgnoreCase(String.valueOf(expectedValue))) {
                    return false;
                }
            }
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'ActivityCommissionService: Invalid filter criteria JSON: ' + filterJson);
            return false;
        }
    }

    /**
     * Check if the participant is within activity caps for the current period.
     */
    @TestVisible
    private static Boolean isWithinCaps(Id compPlanId, Activity_Commission_Rule__c rule) {
        Date periodStart = Date.today().toStartOfMonth();

        List<AggregateResult> existing = [
            SELECT COUNT(Id) cnt, SUM(Eligible_Commission__c) totalAmt
            FROM Comp_Calculation__c
            WHERE Comp_Plan__c = :compPlanId
            AND Comp_Plan_Type__c = 'Activity_Based'
            AND Rate_Tier_Applied__c LIKE :('Activity: ' + rule.Activity_Type__c + '%')
            AND Processed_Date__c >= :periodStart
            AND Calculation_Status__c != 'Reversed'
        ];

        Integer currentCount = (Integer) existing[0].get('cnt');
        Decimal currentAmount = existing[0].get('totalAmt') != null
            ? (Decimal) existing[0].get('totalAmt') : 0;

        // Check count cap
        if (rule.Cap_Count_Per_Period__c != null && currentCount >= rule.Cap_Count_Per_Period__c) {
            return false;
        }

        // Check amount cap
        if (rule.Cap_Per_Period__c != null && currentAmount >= rule.Cap_Per_Period__c) {
            return false;
        }

        return true;
    }

    /**
     * Calculate the commission amount for a qualifying activity.
     */
    @TestVisible
    private static Decimal calculateActivityCommission(SObject activity, Activity_Commission_Rule__c rule) {
        if (rule.Rate_Per_Activity__c != null && rule.Rate_Per_Activity__c > 0) {
            return rule.Rate_Per_Activity__c;
        }
        else if (rule.Rate_Pct_Per_Activity__c != null && rule.Rate_Pct_Per_Activity__c > 0) {
            Decimal activityValue = 0;
            try {
                activityValue = (Decimal) activity.get('Amount');
            } catch (Exception e) {
                activityValue = 0;
            }
            return activityValue != null ? activityValue * (rule.Rate_Pct_Per_Activity__c / 100) : 0;
        }

        return 0;
    }
}
