/**
 * @description 7-step commission calculation engine.
 *  1. identifyParticipants   — find eligible reps for an opportunity
 *  2. resolveActivePlans     — resolve active Comp_Plan__c records for each participant
 *  3. computeCommissionableValue — derive the commissionable value from the opportunity
 *  4. applyRateStructure     — apply tiered rates based on attainment
 *  5. applyModifiers         — apply caps, holds, and category rate overrides
 *  6. persistCalculations    — insert immutable Comp_Calculation__c ledger records
 *  7. updateAttainment       — credit quota attainment
 *
 *  Entry point: processOpportunity(Id opportunityId)
 */
public with sharing class CommissionService {

    // ── Inner types ──────────────────────────────────────────────────────

    public class CalcResult {
        public Id compPlanId;
        public Id repId;
        public Id opportunityId;
        public Decimal commissionableValue;
        public Decimal eligibleCommission;
        public Decimal appliedPercentage;
        public Decimal quotaCreditAmount;
        public String rateTierApplied;
        public String calcType;
        public String calcStatus;
        public Decimal attainmentSnapshot;
        public String rateOverrideApplied;
        public String holdReason;
        public Decimal holdThresholdPct;
    }

    // ── Main entry point ─────────────────────────────────────────────────

    public static void processOpportunity(Id opportunityId) {
        Opportunity opp = queryOpportunity(opportunityId);
        if (opp == null) {
            return;
        }

        // Step 1
        List<Comp_Plan__c> participantPlans = identifyParticipants(opportunityId);
        if (participantPlans.isEmpty()) {
            return;
        }

        List<CalcResult> allResults = new List<CalcResult>();

        for (Comp_Plan__c plan : participantPlans) {
            // Step 2 — plan already resolved via query; verify active
            if (!isPlanActive(plan)) {
                continue;
            }

            // Step 3
            Decimal commissionableValue = computeCommissionableValue(opp, plan);
            if (commissionableValue == null || commissionableValue <= 0) {
                continue;
            }

            // Step 4
            Decimal currentAttainment = getCurrentAttainment(plan);
            CalcResult result = applyRateStructure(commissionableValue, plan, currentAttainment, opp.Id);

            // Step 5
            result = applyModifiers(result, plan);

            allResults.add(result);
        }

        if (!allResults.isEmpty()) {
            // Step 6
            persistCalculations(allResults);
            // Step 7
            updateAttainment(allResults);
        }
    }

    // ── Step 1: Identify Participants ────────────────────────────────────

    @TestVisible
    private static List<Comp_Plan__c> identifyParticipants(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, OwnerId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        return [
            SELECT Id, Sales_Rep__c, Plan_Template__c, OTE__c,
                   Variable_Compensation__c, Status__c,
                   Effective_Start__c, Effective_End__c,
                   Participant_Role__c, Participant_Role__r.Eligibility_Type__c,
                   Override_Base_Rate__c,
                   Plan_Template__r.Id
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :opp.OwnerId
              AND Status__c = 'Active'
              AND Effective_Start__c <= TODAY
              AND (Effective_End__c >= TODAY OR Effective_End__c = null)
        ];
    }

    // ── Step 2: Resolve Active Plans (filter check) ──────────────────────

    @TestVisible
    private static Boolean isPlanActive(Comp_Plan__c plan) {
        if (plan.Status__c != 'Active') {
            return false;
        }
        Date today = Date.today();
        if (plan.Effective_Start__c != null && plan.Effective_Start__c > today) {
            return false;
        }
        if (plan.Effective_End__c != null && plan.Effective_End__c < today) {
            return false;
        }
        return true;
    }

    // ── Step 3: Compute Commissionable Value ─────────────────────────────

    @TestVisible
    private static Decimal computeCommissionableValue(Opportunity opp, Comp_Plan__c plan) {
        // Default: use Opportunity Amount as commissionable value
        Decimal baseValue = opp.Amount != null ? opp.Amount : 0;

        // If the plan template has Commissionable_Value_Map__c records,
        // use the primary mapped field. For now, use Amount.
        if (plan.Plan_Template__c != null) {
            List<Commissionable_Value_Map__c> maps = [
                SELECT Id, Opportunity_Field__c, Is_Primary__c, Adjustment_Type__c
                FROM Commissionable_Value_Map__c
                WHERE Transaction_Category__r.Is_Active__c = true
                  AND Is_Primary__c = true
                LIMIT 1
            ];
            if (!maps.isEmpty()) {
                // Dynamic field resolution would go here in production;
                // for Week 1 we use Amount as the primary commissionable value
                baseValue = opp.Amount != null ? opp.Amount : 0;
            }
        }

        return baseValue;
    }

    // ── Step 4: Apply Rate Structure ─────────────────────────────────────

    @TestVisible
    private static CalcResult applyRateStructure(
        Decimal commissionableValue,
        Comp_Plan__c plan,
        Decimal currentAttainment,
        Id opportunityId
    ) {
        CalcResult result = new CalcResult();
        result.compPlanId = plan.Id;
        result.repId = plan.Sales_Rep__c;
        result.opportunityId = opportunityId;
        result.commissionableValue = commissionableValue;
        result.attainmentSnapshot = currentAttainment;
        result.calcType = 'Base';
        result.calcStatus = 'Projected';
        result.rateOverrideApplied = null;

        // Query commission tiers for this plan template, ordered by attainment
        List<Commission_Tier__c> tiers = [
            SELECT Id, Tier_Name__c, Min_Attainment_Pct__c, Max_Attainment_Pct__c,
                   Rate_Pct__c, Rate_Amount__c, Is_Retroactive__c, Is_Active__c
            FROM Commission_Tier__c
            WHERE Plan_Template__c = :plan.Plan_Template__c
              AND Is_Active__c = true
            ORDER BY Min_Attainment_Pct__c ASC
        ];

        if (tiers.isEmpty()) {
            // No tiers defined — use plan override rate or default 0
            Decimal rate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
            result.appliedPercentage = rate;
            result.eligibleCommission = commissionableValue * (rate / 100);
            result.rateTierApplied = 'Default';
            result.quotaCreditAmount = commissionableValue;
            return result;
        }

        // Find the tier matching current attainment percentage
        Decimal attainmentPct = currentAttainment;
        Commission_Tier__c matchedTier = null;

        for (Commission_Tier__c tier : tiers) {
            Decimal minPct = tier.Min_Attainment_Pct__c != null ? tier.Min_Attainment_Pct__c : 0;
            Decimal maxPct = tier.Max_Attainment_Pct__c != null ? tier.Max_Attainment_Pct__c : 999999;
            if (attainmentPct >= minPct && attainmentPct < maxPct) {
                matchedTier = tier;
                break;
            }
        }

        // Fallback to highest tier if attainment exceeds all defined ranges
        if (matchedTier == null && !tiers.isEmpty()) {
            matchedTier = tiers[tiers.size() - 1];
        }

        Decimal rate = matchedTier.Rate_Pct__c != null ? matchedTier.Rate_Pct__c : 0;
        result.appliedPercentage = rate;
        result.eligibleCommission = commissionableValue * (rate / 100);
        result.rateTierApplied = matchedTier.Tier_Name__c;
        result.quotaCreditAmount = commissionableValue;

        return result;
    }

    // ── Step 5: Apply Modifiers ──────────────────────────────────────────

    @TestVisible
    private static CalcResult applyModifiers(CalcResult result, Comp_Plan__c plan) {
        if (plan.Plan_Template__c == null) {
            return result;
        }

        // Apply category rate overrides
        result = applyCategoryOverrides(result, plan);

        // Apply caps
        result = applyCaps(result, plan);

        // Apply holds
        result = applyHolds(result, plan);

        return result;
    }

    private static CalcResult applyCategoryOverrides(CalcResult result, Comp_Plan__c plan) {
        List<Category_Rate_Override__c> overrides = [
            SELECT Id, Rate_Pct__c, Rate_Amount__c, Rate_Modifier__c,
                   Deal_Size_Min__c, Deal_Size_Max__c, Is_Active__c
            FROM Category_Rate_Override__c
            WHERE Plan_Template__c = :plan.Plan_Template__c
              AND Is_Active__c = true
            ORDER BY Sort_Order__c ASC
        ];

        for (Category_Rate_Override__c ovr : overrides) {
            // Check deal size bounds
            if (ovr.Deal_Size_Min__c != null && result.commissionableValue < ovr.Deal_Size_Min__c) {
                continue;
            }
            if (ovr.Deal_Size_Max__c != null && result.commissionableValue > ovr.Deal_Size_Max__c) {
                continue;
            }

            // Apply rate modifier
            if (ovr.Rate_Modifier__c == 'Absolute' && ovr.Rate_Pct__c != null) {
                result.appliedPercentage = ovr.Rate_Pct__c;
                result.eligibleCommission = result.commissionableValue * (ovr.Rate_Pct__c / 100);
            } else if (ovr.Rate_Modifier__c == 'Additive' && ovr.Rate_Pct__c != null) {
                result.appliedPercentage += ovr.Rate_Pct__c;
                result.eligibleCommission = result.commissionableValue * (result.appliedPercentage / 100);
            } else if (ovr.Rate_Modifier__c == 'Multiplier' && ovr.Rate_Pct__c != null) {
                result.appliedPercentage *= (ovr.Rate_Pct__c / 100);
                result.eligibleCommission = result.commissionableValue * (result.appliedPercentage / 100);
            }

            result.rateOverrideApplied = ovr.Id;
            break; // Apply first matching override only
        }

        return result;
    }

    private static CalcResult applyCaps(CalcResult result, Comp_Plan__c plan) {
        List<Plan_Cap__c> caps = [
            SELECT Id, Cap_Type__c, Cap_Amount__c, Cap_Pct__c,
                   Value_Cap_Amount__c, Value_Floor_Amount__c, Is_Active__c
            FROM Plan_Cap__c
            WHERE Plan_Template__c = :plan.Plan_Template__c
              AND Is_Active__c = true
            ORDER BY Sort_Order__c ASC
        ];

        for (Plan_Cap__c cap : caps) {
            if (cap.Cap_Type__c == 'Commissionable_Value_Cap' && cap.Value_Cap_Amount__c != null) {
                if (result.commissionableValue > cap.Value_Cap_Amount__c) {
                    result.commissionableValue = cap.Value_Cap_Amount__c;
                    result.eligibleCommission = result.commissionableValue * (result.appliedPercentage / 100);
                }
            } else if (cap.Cap_Type__c == 'Commissionable_Value_Floor' && cap.Value_Floor_Amount__c != null) {
                if (result.commissionableValue < cap.Value_Floor_Amount__c) {
                    result.commissionableValue = 0;
                    result.eligibleCommission = 0;
                }
            } else if (cap.Cap_Amount__c != null && result.eligibleCommission > cap.Cap_Amount__c) {
                result.eligibleCommission = cap.Cap_Amount__c;
            }
        }

        return result;
    }

    private static CalcResult applyHolds(CalcResult result, Comp_Plan__c plan) {
        List<Plan_Hold__c> holds = [
            SELECT Id, Hold_Type__c, Hold_Pct__c, Is_Active__c
            FROM Plan_Hold__c
            WHERE Plan_Template__c = :plan.Plan_Template__c
              AND Is_Active__c = true
            ORDER BY Sort_Order__c ASC
        ];

        for (Plan_Hold__c hold : holds) {
            if (hold.Hold_Pct__c != null && hold.Hold_Pct__c > 0) {
                result.holdReason = mapHoldTypeToReason(hold.Hold_Type__c);
                result.holdThresholdPct = hold.Hold_Pct__c;
                // Hold reduces eligible commission by hold percentage
                result.eligibleCommission = result.eligibleCommission * (1 - (hold.Hold_Pct__c / 100));
                break; // Apply first active hold
            }
        }

        return result;
    }

    // ── Step 6: Persist Calculations ─────────────────────────────────────

    @TestVisible
    private static void persistCalculations(List<CalcResult> results) {
        List<Comp_Calculation__c> calcs = new List<Comp_Calculation__c>();

        for (CalcResult r : results) {
            Comp_Calculation__c calc = new Comp_Calculation__c();
            calc.Comp_Plan__c = r.compPlanId;
            calc.Rep__c = r.repId;
            calc.Opportunity__c = r.opportunityId;
            calc.Commisionable_Value__c = r.commissionableValue;
            calc.Eligible_Commission__c = r.eligibleCommission;
            calc.Applied_Percentage__c = r.appliedPercentage;
            calc.Quota_Credit_Amount__c = r.quotaCreditAmount;
            calc.Rate_Tier_Applied__c = r.rateTierApplied;
            calc.Type__c = r.calcType;
            calc.Calculation_Status__c = 'Projected';
            calc.Attainment_Snapshot__c = r.attainmentSnapshot;
            calc.Rate_Override_Applied__c = r.rateOverrideApplied;
            calc.Hold_Reason__c = r.holdReason;
            calc.Processed_Date__c = Date.today();
            calc.Commisionable_Date__c = Date.today();
            calc.Processing_Run_Id__c = generateRunId();
            calcs.add(calc);
        }

        if (!calcs.isEmpty()) {
            insert calcs;
        }
    }

    // ── Step 7: Update Attainment ────────────────────────────────────────

    @TestVisible
    private static void updateAttainment(List<CalcResult> results) {
        Set<Id> planIds = new Set<Id>();
        Map<Id, Decimal> planCredits = new Map<Id, Decimal>();

        for (CalcResult r : results) {
            planIds.add(r.compPlanId);
            Decimal existing = planCredits.containsKey(r.compPlanId) ? planCredits.get(r.compPlanId) : 0;
            planCredits.put(r.compPlanId, existing + (r.quotaCreditAmount != null ? r.quotaCreditAmount : 0));
        }

        List<Quota__c> quotas = [
            SELECT Id, Comp_Plan__c, Achieved_Amount__c, Target_Amount__c
            FROM Quota__c
            WHERE Comp_Plan__c IN :planIds
              AND Status__c = 'Active'
        ];

        List<Quota__c> toUpdate = new List<Quota__c>();
        for (Quota__c q : quotas) {
            if (planCredits.containsKey(q.Comp_Plan__c)) {
                Decimal credit = planCredits.get(q.Comp_Plan__c);
                q.Achieved_Amount__c = (q.Achieved_Amount__c != null ? q.Achieved_Amount__c : 0) + credit;
                toUpdate.add(q);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static Opportunity queryOpportunity(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT Id, Amount, OwnerId, StageName, CloseDate, Type
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    private static Decimal getCurrentAttainment(Comp_Plan__c plan) {
        List<Quota__c> quotas = [
            SELECT Id, Target_Amount__c, Achieved_Amount__c
            FROM Quota__c
            WHERE Comp_Plan__c = :plan.Id
              AND Status__c = 'Active'
            LIMIT 1
        ];

        if (quotas.isEmpty() || quotas[0].Target_Amount__c == null || quotas[0].Target_Amount__c == 0) {
            return 0;
        }

        Decimal achieved = quotas[0].Achieved_Amount__c != null ? quotas[0].Achieved_Amount__c : 0;
        return (achieved / quotas[0].Target_Amount__c) * 100;
    }

    private static String generateRunId() {
        return 'RUN-' + String.valueOf(Datetime.now().getTime());
    }

    private static String mapHoldTypeToReason(String holdType) {
        if (holdType == 'Collection_Hold') return 'Collection_Pending';
        if (holdType == 'Milestone_Hold') return 'Milestone_Pending';
        if (holdType == 'Approval_Hold') return 'Approval_Pending';
        if (holdType == 'Time_Hold') return 'Time_Hold';
        if (holdType == 'Custom') return 'Custom_Hold';
        return 'None';
    }
}
