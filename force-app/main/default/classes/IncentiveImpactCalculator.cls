/**
 * @description Real-time commission impact estimator.
 *              Computes current attainment, projected attainment after a deal,
 *              rate tier transitions, payout delta, and threshold proximity.
 *              Used by the inline estimator (LWC) and governance rules.
 */
public with sharing class IncentiveImpactCalculator {

    // ── Data types ───────────────────────────────────────────────────────

    public class IncentiveContext {
        @AuraEnabled public Id participantId;
        @AuraEnabled public String participantName;
        @AuraEnabled public Id compPlanId;
        @AuraEnabled public Id planTemplateId;
        @AuraEnabled public Decimal currentAttainmentAmount;
        @AuraEnabled public Decimal quotaTarget;
        @AuraEnabled public Decimal attainmentPct;
        @AuraEnabled public Decimal ote;
        @AuraEnabled public Decimal variableCompensation;
        @AuraEnabled public List<TierDefinition> tiers;
        @AuraEnabled public Date periodStart;
        @AuraEnabled public Date periodEnd;
    }

    public class TierDefinition {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal minAttainmentPct;
        @AuraEnabled public Decimal maxAttainmentPct;
        @AuraEnabled public Decimal ratePct;
        @AuraEnabled public Decimal rateAmount;
        @AuraEnabled public Boolean isRetroactive;
    }

    public class ImpactResult {
        @AuraEnabled public Decimal currentAttainmentPct;
        @AuraEnabled public Decimal proposedAttainmentPct;
        @AuraEnabled public TierDefinition currentTier;
        @AuraEnabled public TierDefinition projectedTier;
        @AuraEnabled public Boolean tierCrossing;
        @AuraEnabled public Decimal payoutOnDeal;
        @AuraEnabled public Decimal retroactiveDelta;
        @AuraEnabled public String tierImpactMessage;
        @AuraEnabled public List<ThresholdProximity> proximities;
    }

    public class ThresholdProximity {
        @AuraEnabled public String tierName;
        @AuraEnabled public Decimal distanceAmount;
        @AuraEnabled public Decimal distancePct;
        @AuraEnabled public Decimal ratePct;
    }

    // ── Public API ───────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static IncentiveContext getContext(Id participantId) {
        List<Comp_Plan__c> plans = [
            SELECT Id, Sales_Rep__c, Plan_Template__c, OTE__c,
                   Variable_Compensation__c, Status__c,
                   Effective_Start__c, Effective_End__c,
                   Sales_Rep__r.Name, Plan_Template__r.Id
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :participantId
              AND Status__c = 'Active'
              AND Effective_Start__c <= TODAY
              AND (Effective_End__c >= TODAY OR Effective_End__c = null)
            LIMIT 1
        ];

        if (plans.isEmpty()) {
            return null;
        }

        Comp_Plan__c plan = plans[0];
        IncentiveContext ctx = new IncentiveContext();
        ctx.participantId = participantId;
        ctx.participantName = plan.Sales_Rep__r.Name;
        ctx.compPlanId = plan.Id;
        ctx.planTemplateId = plan.Plan_Template__c;
        ctx.ote = plan.OTE__c;
        ctx.variableCompensation = plan.Variable_Compensation__c;
        ctx.periodStart = plan.Effective_Start__c;
        ctx.periodEnd = plan.Effective_End__c;

        // Load quota
        List<Quota__c> quotas = [
            SELECT Id, Target_Amount__c, Achieved_Amount__c
            FROM Quota__c
            WHERE Comp_Plan__c = :plan.Id
              AND Status__c = 'Active'
            LIMIT 1
        ];

        if (!quotas.isEmpty()) {
            Quota__c q = quotas[0];
            ctx.quotaTarget = q.Target_Amount__c != null ? q.Target_Amount__c : 0;
            ctx.currentAttainmentAmount = q.Achieved_Amount__c != null ? q.Achieved_Amount__c : 0;
            ctx.attainmentPct = ctx.quotaTarget > 0
                ? (ctx.currentAttainmentAmount / ctx.quotaTarget) * 100
                : 0;
        } else {
            ctx.quotaTarget = 0;
            ctx.currentAttainmentAmount = 0;
            ctx.attainmentPct = 0;
        }

        // Load tiers
        ctx.tiers = loadTiers(plan.Plan_Template__c);

        return ctx;
    }

    @AuraEnabled
    public static ImpactResult calculateImpact(Id opportunityId, Id participantId) {
        IncentiveContext ctx = getContext(participantId);
        if (ctx == null) {
            return null;
        }

        Opportunity opp = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Decimal dealValue = opp.Amount != null ? opp.Amount : 0;

        ImpactResult impact = new ImpactResult();
        impact.currentAttainmentPct = ctx.attainmentPct;

        // Projected attainment after this deal
        Decimal proposedAmount = ctx.currentAttainmentAmount + dealValue;
        impact.proposedAttainmentPct = ctx.quotaTarget > 0
            ? (proposedAmount / ctx.quotaTarget) * 100
            : 0;

        // Find current and projected tiers
        impact.currentTier = findTier(ctx.attainmentPct, ctx.tiers);
        impact.projectedTier = findTier(impact.proposedAttainmentPct, ctx.tiers);
        impact.tierCrossing = impact.currentTier != null && impact.projectedTier != null
            && impact.currentTier.name != impact.projectedTier.name;

        // Payout on this deal at projected tier rate
        Decimal rate = impact.projectedTier != null && impact.projectedTier.ratePct != null
            ? impact.projectedTier.ratePct : 0;
        impact.payoutOnDeal = dealValue * (rate / 100);

        // Retroactive delta — if new tier is retroactive, all prior attainment
        // gets the rate uplift
        impact.retroactiveDelta = 0;
        if (impact.tierCrossing && impact.projectedTier.isRetroactive) {
            Decimal currentRate = impact.currentTier != null && impact.currentTier.ratePct != null
                ? impact.currentTier.ratePct : 0;
            Decimal rateDiff = rate - currentRate;
            impact.retroactiveDelta = ctx.currentAttainmentAmount * (rateDiff / 100);
        }

        // Tier impact message
        if (impact.tierCrossing) {
            impact.tierImpactMessage = 'Crosses \u2192 ' + impact.projectedTier.name;
            if (impact.projectedTier.isRetroactive) {
                Decimal currentRate = impact.currentTier != null && impact.currentTier.ratePct != null
                    ? impact.currentTier.ratePct : 0;
                Decimal rateDiff = rate - currentRate;
                impact.tierImpactMessage += ' (+' + rateDiff.setScale(1) + '% retroactive on all prior)';
            }
        } else {
            impact.tierImpactMessage = 'No tier change';
        }

        // Threshold proximities — distance to each tier above current
        impact.proximities = new List<ThresholdProximity>();
        for (TierDefinition tier : ctx.tiers) {
            if (tier.minAttainmentPct != null && tier.minAttainmentPct > ctx.attainmentPct) {
                ThresholdProximity prox = new ThresholdProximity();
                prox.tierName = tier.name;
                prox.distancePct = tier.minAttainmentPct - ctx.attainmentPct;
                prox.distanceAmount = ctx.quotaTarget > 0
                    ? (prox.distancePct / 100) * ctx.quotaTarget
                    : 0;
                prox.ratePct = tier.ratePct;
                impact.proximities.add(prox);
            }
        }

        return impact;
    }

    // ── Private helpers ──────────────────────────────────────────────────

    private static List<TierDefinition> loadTiers(Id planTemplateId) {
        List<TierDefinition> defs = new List<TierDefinition>();
        if (planTemplateId == null) {
            return defs;
        }

        List<Commission_Tier__c> tiers = [
            SELECT Id, Tier_Name__c, Min_Attainment_Pct__c, Max_Attainment_Pct__c,
                   Rate_Pct__c, Rate_Amount__c, Is_Retroactive__c
            FROM Commission_Tier__c
            WHERE Plan_Template__c = :planTemplateId
              AND Is_Active__c = true
            ORDER BY Min_Attainment_Pct__c ASC
        ];

        for (Commission_Tier__c t : tiers) {
            TierDefinition def = new TierDefinition();
            def.name = t.Tier_Name__c;
            def.minAttainmentPct = t.Min_Attainment_Pct__c;
            def.maxAttainmentPct = t.Max_Attainment_Pct__c;
            def.ratePct = t.Rate_Pct__c;
            def.rateAmount = t.Rate_Amount__c;
            def.isRetroactive = t.Is_Retroactive__c;
            defs.add(def);
        }
        return defs;
    }

    private static TierDefinition findTier(Decimal attainmentPct, List<TierDefinition> tiers) {
        if (tiers == null || tiers.isEmpty()) {
            return null;
        }
        for (TierDefinition tier : tiers) {
            Decimal minPct = tier.minAttainmentPct != null ? tier.minAttainmentPct : 0;
            Decimal maxPct = tier.maxAttainmentPct != null ? tier.maxAttainmentPct : 999999;
            if (attainmentPct >= minPct && attainmentPct < maxPct) {
                return tier;
            }
        }
        // Return highest tier if above all ranges
        return tiers[tiers.size() - 1];
    }
}
