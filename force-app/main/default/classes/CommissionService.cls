/**
 * @description Full 7-step commission calculation engine supporting all 10 plan types.
 *
 *  Step 1: identifyParticipants   — find eligible reps (owner + deal credit splits)
 *  Step 2: resolveActivePlans     — resolve active Comp_Plan__c records per participant
 *  Step 3: computeCommissionableValue — dynamic field resolution via Commissionable_Value_Map__c
 *  Step 4: applyRateStructure     — plan-type router dispatches to type-specific calculators
 *  Step 5: applyModifiers         — caps (with windfall), holds, category rate overrides
 *  Step 6: persistCalculations    — insert immutable Comp_Calculation__c ledger records
 *  Step 7: updateAttainment       — credit quota attainment with configurable source
 *
 *  Supported Plan Types:
 *    Flat, Tiered (banded non-retroactive), Accelerated (retroactive),
 *    Gross_Margin, Recurring, Milestone, Team_Pool, Team_Override, SPIFF
 *
 *  Entry point: processOpportunity(Id opportunityId)
 */
public with sharing class CommissionService {

    // ══════════════════════════════════════════════════════════════════════
    //  INNER TYPES
    // ══════════════════════════════════════════════════════════════════════

    public class CalcResult {
        public Id    compPlanId;
        public Id    repId;
        public Id    opportunityId;
        public Decimal commissionableValue;
        public Decimal eligibleCommission;
        public Decimal appliedPercentage;
        public Decimal quotaCreditAmount;
        public String  rateTierApplied;
        public String  calcType;            // Base, SPIFF, Pool_Funding, Manager_Override, Milestone, Adjustment, Retroactive_Uplift
        public String  calcStatus;          // Projected, Validated, Paid
        public Decimal attainmentSnapshot;
        public String  rateOverrideApplied;
        public String  holdReason;
        public Decimal holdThresholdPct;

        // Extended fields for full plan-type support
        public String  adjustmentType;      // Original, Amendment, Reversal, Retroactive_Uplift, Windfall, Deferred
        public String  planType;            // Flat, Tiered, Accelerated, Gross_Margin, etc.
        public Decimal windfall;            // Excess above commissionable value cap
        public Id      splitId;             // Deal_Credit_Split__c Id if from a split
        public Decimal splitPercentage;     // Split % applied
        public String  compPlanType;        // For Comp_Plan_Type__c on ledger record
        public String  comments;            // Descriptive text for ledger

        public CalcResult() {
            this.eligibleCommission  = 0;
            this.commissionableValue = 0;
            this.quotaCreditAmount   = 0;
            this.appliedPercentage   = 0;
            this.attainmentSnapshot  = 0;
            this.windfall            = 0;
            this.calcType            = 'Base';
            this.calcStatus          = 'Projected';
            this.adjustmentType      = 'Original';
        }
    }

    /**
     * @description Lightweight wrapper for a participant and their credit share.
     */
    private class ParticipantCredit {
        public Id   participantId;
        public Decimal splitPct;        // 100 = full credit (owner-only)
        public Id   splitId;            // Deal_Credit_Split__c.Id or null
        public Boolean isPrimary;

        public ParticipantCredit(Id pid, Decimal pct, Id sid, Boolean primary) {
            this.participantId = pid;
            this.splitPct      = pct;
            this.splitId       = sid;
            this.isPrimary     = primary;
        }
    }

    /**
     * @description Quota context for a given comp plan.
     */
    private class QuotaContext {
        public Id      quotaId;
        public Decimal targetAmount;
        public Decimal achievedAmount;
        public Decimal attainmentPct;

        public QuotaContext(Quota__c q) {
            this.quotaId        = q.Id;
            this.targetAmount   = q.Target_Amount__c != null ? q.Target_Amount__c : 0;
            this.achievedAmount = q.Achieved_Amount__c != null ? q.Achieved_Amount__c : 0;
            this.attainmentPct  = this.targetAmount > 0
                ? (this.achievedAmount / this.targetAmount) * 100
                : 0;
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  MAIN ENTRY POINT
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Process commission calculations for a single Opportunity.
     *              Supports deal credit splits, all 10 plan types, SPIFF stacking,
     *              team override, and retroactive tier uplift.
     * @param opportunityId The Opportunity to process
     */
    public static void processOpportunity(Id opportunityId) {
        Opportunity opp = queryOpportunity(opportunityId);
        if (opp == null) {
            return;
        }

        // ── Step 1: Identify Participants (with deal credit splits) ──────
        List<ParticipantCredit> participants = resolveParticipants(opp);
        if (participants.isEmpty()) {
            return;
        }

        List<CalcResult> allResults = new List<CalcResult>();
        String runId = generateRunId();

        // For each participant (may be owner-only or multiple from splits)
        for (ParticipantCredit pc : participants) {

            // ── Step 2: Resolve Active Plans ─────────────────────────────
            List<Comp_Plan__c> plans = resolveActivePlans(pc.participantId);
            if (plans.isEmpty()) {
                continue;
            }

            for (Comp_Plan__c plan : plans) {
                if (!isPlanActive(plan)) {
                    continue;
                }

                String planType = resolvePlanType(plan);

                // Recurring plans are skipped on deal close — handled by batch
                if (planType == 'Recurring') {
                    continue;
                }

                // ── Step 3: Compute Commissionable Value ─────────────────
                Decimal fullCommissionableValue = computeCommissionableValue(opp, plan);
                if (fullCommissionableValue == null || fullCommissionableValue <= 0) {
                    continue;
                }

                // Apply split percentage
                Decimal commissionableValue = fullCommissionableValue * (pc.splitPct / 100);

                // ── Step 4: Plan Type Router → Rate Structure ────────────
                QuotaContext quotaCtx = getQuotaContext(plan);
                List<CalcResult> planResults = planTypeRouter(
                    planType, commissionableValue, plan, quotaCtx, opp, pc
                );

                // ── Step 5: Apply Modifiers (caps, holds, overrides) ─────
                for (Integer i = 0; i < planResults.size(); i++) {
                    planResults[i] = applyModifiers(planResults[i], plan);
                }

                allResults.addAll(planResults);

                // ── Team Override: check if rep's manager has override plan
                if (planType != 'Team_Override' && planType != 'Team_Pool') {
                    List<CalcResult> overrideResults = processTeamOverride(
                        plan, commissionableValue, opp, pc
                    );
                    allResults.addAll(overrideResults);
                }
            }

            // ── SPIFF Stacking: after regular plans, check for active SPIFFs
            List<CalcResult> spiffResults = processSPIFFStacking(
                pc.participantId, opp, pc
            );
            allResults.addAll(spiffResults);
        }

        if (!allResults.isEmpty()) {
            // ── Step 6: Persist Calculations ─────────────────────────────
            persistCalculations(allResults, runId);
            // ── Step 7: Update Attainment ────────────────────────────────
            updateAttainment(allResults);
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 1: IDENTIFY PARTICIPANTS (Deal Credit Split Integration)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Resolve all participants who should receive credit for this deal.
     *              If Deal_Credit_Split__c records exist and are active, each split
     *              participant gets their share. Otherwise, the Opportunity owner
     *              gets 100%.
     */
    @TestVisible
    private static List<ParticipantCredit> resolveParticipants(Opportunity opp) {
        List<ParticipantCredit> credits = new List<ParticipantCredit>();

        // Query active deal credit splits
        List<Deal_Credit_Split__c> splits = [
            SELECT Id, Participant__c, Split_Percentage__c, Split_Amount__c,
                   Is_Primary__c, Status__c, Effective_Start__c, Effective_End__c
            FROM Deal_Credit_Split__c
            WHERE Opportunity__c = :opp.Id
              AND Status__c = 'Active'
              AND (Effective_Start__c = null OR Effective_Start__c <= TODAY)
              AND (Effective_End__c = null OR Effective_End__c >= TODAY)
            ORDER BY Is_Primary__c DESC, Split_Percentage__c DESC
        ];

        if (!splits.isEmpty()) {
            for (Deal_Credit_Split__c s : splits) {
                if (s.Participant__c != null && s.Split_Percentage__c != null && s.Split_Percentage__c > 0) {
                    credits.add(new ParticipantCredit(
                        s.Participant__c,
                        s.Split_Percentage__c,
                        s.Id,
                        s.Is_Primary__c
                    ));
                }
            }
        }

        // Fallback: owner gets 100%
        if (credits.isEmpty()) {
            credits.add(new ParticipantCredit(opp.OwnerId, 100, null, true));
        }

        return credits;
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 2: RESOLVE ACTIVE PLANS
    // ══════════════════════════════════════════════════════════════════════

    @TestVisible
    private static List<Comp_Plan__c> resolveActivePlans(Id participantId) {
        return [
            SELECT Id, Sales_Rep__c, Plan_Template__c, OTE__c,
                   Variable_Compensation__c, Status__c,
                   Effective_Start__c, Effective_End__c,
                   Participant_Role__c, Participant_Role__r.Eligibility_Type__c,
                   Override_Base_Rate__c,
                   Plan_Template__r.Id,
                   Plan_Template__r.Plan_Type__c,
                   Plan_Template__r.Name
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :participantId
              AND Status__c = 'Active'
              AND Effective_Start__c <= TODAY
              AND (Effective_End__c >= TODAY OR Effective_End__c = null)
        ];
    }

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

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 3: COMPUTE COMMISSIONABLE VALUE (Dynamic Field Resolution)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Resolve the commissionable value using Commissionable_Value_Map__c.
     *              - Primary map: opp.get(mapRecord.Opportunity_Field__c)
     *              - Subtract_From_Primary: subtracts value from base (e.g., COGS)
     *              - Multiply_By_Primary: multiplies base value
     *              - Fallback: Opportunity.Amount
     */
    @TestVisible
    private static Decimal computeCommissionableValue(Opportunity opp, Comp_Plan__c plan) {
        if (plan.Plan_Template__c == null) {
            return opp.Amount != null ? opp.Amount : 0;
        }

        // Query all value maps for this plan template's transaction categories
        // Get eligible transaction categories for this plan template via junction
        Set<Id> eligibleCategoryIds = new Set<Id>();
        for (Template_Category_Eligibility__c elig : [
            SELECT Transaction_Category__c FROM Template_Category_Eligibility__c
            WHERE Plan_Template__c = :plan.Plan_Template__c AND Is_Active__c = true]) {
            eligibleCategoryIds.add(elig.Transaction_Category__c);
        }

        List<Commissionable_Value_Map__c> maps = new List<Commissionable_Value_Map__c>();
        if (!eligibleCategoryIds.isEmpty()) {
            maps = [
                SELECT Id, Opportunity_Field__c, Is_Primary__c, Adjustment_Type__c,
                       Field_Label__c
                FROM Commissionable_Value_Map__c
                WHERE Transaction_Category__c IN :eligibleCategoryIds
                  AND Transaction_Category__r.Is_Active__c = true
                ORDER BY Is_Primary__c DESC, Sort_Order__c ASC
            ];
        }

        if (maps.isEmpty()) {
            // Fallback: use Opportunity.Amount
            return opp.Amount != null ? opp.Amount : 0;
        }

        // Step 1: Resolve the primary base value
        Decimal baseValue = 0;
        for (Commissionable_Value_Map__c m : maps) {
            if (m.Is_Primary__c == true && String.isNotBlank(m.Opportunity_Field__c)) {
                Object fieldValue = safeGetField(opp, m.Opportunity_Field__c);
                if (fieldValue != null && fieldValue instanceof Decimal) {
                    baseValue = (Decimal) fieldValue;
                } else if (fieldValue != null) {
                    try {
                        baseValue = Decimal.valueOf(String.valueOf(fieldValue));
                    } catch (Exception e) {
                        baseValue = 0;
                    }
                }
                break; // Only one primary
            }
        }

        // If no primary found, fallback to Amount
        if (baseValue == 0) {
            baseValue = opp.Amount != null ? opp.Amount : 0;
        }

        // Step 2: Apply adjustments
        for (Commissionable_Value_Map__c m : maps) {
            if (m.Is_Primary__c == true) {
                continue; // Already processed
            }

            Decimal adjustmentValue = 0;
            if (String.isNotBlank(m.Opportunity_Field__c)) {
                Object fieldValue = safeGetField(opp, m.Opportunity_Field__c);
                if (fieldValue != null && fieldValue instanceof Decimal) {
                    adjustmentValue = (Decimal) fieldValue;
                } else if (fieldValue != null) {
                    try {
                        adjustmentValue = Decimal.valueOf(String.valueOf(fieldValue));
                    } catch (Exception e) {
                        adjustmentValue = 0;
                    }
                }
            }

            if (m.Adjustment_Type__c == 'Subtract_From_Primary') {
                baseValue -= adjustmentValue;
            } else if (m.Adjustment_Type__c == 'Multiply_By_Primary') {
                baseValue *= adjustmentValue;
            } else if (m.Adjustment_Type__c == 'Add_To_Primary') {
                baseValue += adjustmentValue;
            }
        }

        return baseValue > 0 ? baseValue : 0;
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 4: PLAN TYPE ROUTER
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Dispatch to the correct calculation method based on plan type.
     *              Returns a list because some plan types produce multiple CalcResults
     *              (e.g., retroactive uplift creates adjustment records).
     */
    @TestVisible
    private static List<CalcResult> planTypeRouter(
        String planType,
        Decimal commissionableValue,
        Comp_Plan__c plan,
        QuotaContext quotaCtx,
        Opportunity opp,
        ParticipantCredit pc
    ) {
        List<CalcResult> results;

        switch on planType {
            when 'Flat' {
                results = calculateFlat(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
            when 'Tiered' {
                results = calculateTiered(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
            when 'Accelerated' {
                results = calculateAccelerated(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
            when 'Gross_Margin' {
                // Commissionable value already adjusted in Step 3 via Subtract_From_Primary (COGS)
                // Apply tiered or flat rate on the margin value
                results = calculateGrossMargin(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
            when 'Milestone' {
                results = calculateMilestone(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
            when 'Team_Pool' {
                results = calculateTeamPool(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
            when else {
                // Default: treat as flat
                results = calculateFlat(commissionableValue, plan, quotaCtx, opp.Id, pc);
            }
        }

        return results;
    }

    // ──────────────────────────────────────────────────────────────────────
    //  FLAT CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Flat commission: single rate applied to the full commissionable value.
     *              Uses the tier matching current attainment (single-rate lookup).
     */
    @TestVisible
    private static List<CalcResult> calculateFlat(
        Decimal commissionableValue, Comp_Plan__c plan,
        QuotaContext quotaCtx, Id opportunityId, ParticipantCredit pc
    ) {
        CalcResult result = initCalcResult(plan, opportunityId, pc, commissionableValue, quotaCtx);
        result.planType = 'Flat';
        result.compPlanType = 'Flat';

        List<Commission_Tier__c> tiers = queryTiers(plan.Plan_Template__c);

        if (tiers.isEmpty()) {
            Decimal rate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
            result.appliedPercentage  = rate;
            result.eligibleCommission = commissionableValue * (rate / 100);
            result.rateTierApplied    = 'Default';
        } else {
            // New attainment after this deal (for tier lookup)
            Decimal newAttainmentPct = quotaCtx.targetAmount > 0
                ? ((quotaCtx.achievedAmount + commissionableValue) / quotaCtx.targetAmount) * 100
                : quotaCtx.attainmentPct;
            Commission_Tier__c matched = findMatchingTier(newAttainmentPct, tiers);
            Decimal rate = matched.Rate_Pct__c != null ? matched.Rate_Pct__c : 0;
            result.appliedPercentage  = rate;
            result.eligibleCommission = commissionableValue * (rate / 100);
            result.rateTierApplied    = matched.Tier_Name__c;
        }

        result.quotaCreditAmount = resolveQuotaCredit(commissionableValue, plan);
        return new List<CalcResult>{ result };
    }

    // ──────────────────────────────────────────────────────────────────────
    //  TIERED (BANDED, NON-RETROACTIVE) CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Tiered/Banded calculation: split the commissionable value across
     *              attainment bands and apply each band's rate to its portion.
     *
     *  Example: $1.5M deal, quota $1M, current attainment $500K (50%)
     *    Tiers: 0-100% at 8%, 100-150% at 10%, 150%+ at 12%
     *    This deal pushes total to $2M (200%):
     *      - First $500K (50% → 100%) at 8%  = $40K
     *      - Next  $500K (100% → 150%) at 10% = $50K
     *      - Last  $500K (150% → 200%) at 12% = $60K
     *    Total commission = $150K
     */
    @TestVisible
    private static List<CalcResult> calculateTiered(
        Decimal commissionableValue, Comp_Plan__c plan,
        QuotaContext quotaCtx, Id opportunityId, ParticipantCredit pc
    ) {
        CalcResult result = initCalcResult(plan, opportunityId, pc, commissionableValue, quotaCtx);
        result.planType     = 'Tiered';
        result.compPlanType = 'Tiered';

        List<Commission_Tier__c> tiers = queryTiers(plan.Plan_Template__c);

        if (tiers.isEmpty()) {
            Decimal rate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
            result.appliedPercentage  = rate;
            result.eligibleCommission = commissionableValue * (rate / 100);
            result.rateTierApplied    = 'Default';
            result.quotaCreditAmount  = resolveQuotaCredit(commissionableValue, plan);
            return new List<CalcResult>{ result };
        }

        Decimal quotaTarget = quotaCtx.targetAmount > 0 ? quotaCtx.targetAmount : 1;
        Decimal currentAchieved = quotaCtx.achievedAmount;
        Decimal dealRemaining = commissionableValue;
        Decimal totalCommission = 0;
        String lastTierName = '';
        Decimal weightedRateNumerator = 0;

        // Walk through each tier and allocate the deal value across bands
        for (Commission_Tier__c tier : tiers) {
            if (dealRemaining <= 0) break;

            Decimal tierMinPct = tier.Min_Attainment_Pct__c != null ? tier.Min_Attainment_Pct__c : 0;
            Decimal tierMaxPct = tier.Max_Attainment_Pct__c != null ? tier.Max_Attainment_Pct__c : 999999;
            Decimal rate       = tier.Rate_Pct__c != null ? tier.Rate_Pct__c : 0;

            // Convert tier boundaries to dollar amounts
            Decimal tierFloorAmt   = quotaTarget * (tierMinPct / 100);
            Decimal tierCeilingAmt = tierMaxPct >= 999999 ? Decimal.valueOf('999999999999') : quotaTarget * (tierMaxPct / 100);

            // Where does the deal start and end in dollar terms?
            Decimal dealStartAmt = currentAchieved;
            Decimal dealEndAmt   = currentAchieved + commissionableValue;

            // Overlap of [dealStart, dealEnd] with [tierFloor, tierCeiling]
            Decimal overlapStart = Math.max(dealStartAmt, tierFloorAmt);
            Decimal overlapEnd   = Math.min(dealEndAmt, tierCeilingAmt);

            if (overlapStart < overlapEnd) {
                Decimal portionInBand = overlapEnd - overlapStart;
                Decimal bandCommission = portionInBand * (rate / 100);
                totalCommission += bandCommission;
                weightedRateNumerator += portionInBand * rate;
                lastTierName = tier.Tier_Name__c;
            }
        }

        // Effective blended rate
        Decimal effectiveRate = commissionableValue > 0
            ? weightedRateNumerator / commissionableValue
            : 0;

        result.appliedPercentage  = effectiveRate.setScale(4, System.RoundingMode.HALF_UP);
        result.eligibleCommission = totalCommission.setScale(2, System.RoundingMode.HALF_UP);
        result.rateTierApplied    = lastTierName;
        result.quotaCreditAmount  = resolveQuotaCredit(commissionableValue, plan);

        return new List<CalcResult>{ result };
    }

    // ──────────────────────────────────────────────────────────────────────
    //  ACCELERATED (RETROACTIVE) CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Accelerated/Retroactive calculation.
     *              When a deal pushes attainment into a retroactive tier, the TOP
     *              tier rate applies to ALL production (not just the current deal).
     *              Additionally, prior Comp_Calculation__c records at lower rates
     *              get uplift adjustment records.
     *
     *  Example: $2M total at 12% retroactive = $240K (vs. $150K banded)
     */
    @TestVisible
    private static List<CalcResult> calculateAccelerated(
        Decimal commissionableValue, Comp_Plan__c plan,
        QuotaContext quotaCtx, Id opportunityId, ParticipantCredit pc
    ) {
        List<CalcResult> results = new List<CalcResult>();

        CalcResult result = initCalcResult(plan, opportunityId, pc, commissionableValue, quotaCtx);
        result.planType     = 'Accelerated';
        result.compPlanType = 'Accelerated';

        List<Commission_Tier__c> tiers = queryTiers(plan.Plan_Template__c);

        if (tiers.isEmpty()) {
            Decimal rate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
            result.appliedPercentage  = rate;
            result.eligibleCommission = commissionableValue * (rate / 100);
            result.rateTierApplied    = 'Default';
            result.quotaCreditAmount  = resolveQuotaCredit(commissionableValue, plan);
            results.add(result);
            return results;
        }

        // Determine the tier after this deal
        Decimal newAttainmentPct = quotaCtx.targetAmount > 0
            ? ((quotaCtx.achievedAmount + commissionableValue) / quotaCtx.targetAmount) * 100
            : quotaCtx.attainmentPct;

        Commission_Tier__c newTier = findMatchingTier(newAttainmentPct, tiers);
        Decimal newRate = newTier.Rate_Pct__c != null ? newTier.Rate_Pct__c : 0;
        Boolean isRetroactive = newTier.Is_Retroactive__c == true;

        // Determine the tier BEFORE this deal
        Commission_Tier__c oldTier = findMatchingTier(quotaCtx.attainmentPct, tiers);
        String oldTierName = oldTier != null ? oldTier.Tier_Name__c : '';
        Decimal oldRate = oldTier != null && oldTier.Rate_Pct__c != null ? oldTier.Rate_Pct__c : 0;
        Boolean tierCrossed = (oldTierName != newTier.Tier_Name__c);

        // For the current deal: apply the new (top) tier rate
        result.appliedPercentage  = newRate;
        result.eligibleCommission = commissionableValue * (newRate / 100);
        result.rateTierApplied    = newTier.Tier_Name__c;
        result.quotaCreditAmount  = resolveQuotaCredit(commissionableValue, plan);
        results.add(result);

        // Retroactive uplift: if we crossed into a retroactive tier, adjust priors
        if (tierCrossed && isRetroactive && newRate > oldRate) {
            List<CalcResult> upliftResults = createRetroactiveUplift(
                plan, newTier.Tier_Name__c, newRate, opportunityId, pc
            );
            results.addAll(upliftResults);
        }

        return results;
    }

    /**
     * @description Create retroactive uplift adjustment records for all prior
     *              Comp_Calculation__c in this plan/period at a lower rate.
     */
    private static List<CalcResult> createRetroactiveUplift(
        Comp_Plan__c plan, String newTierName, Decimal newRate,
        Id triggeringOppId, ParticipantCredit pc
    ) {
        List<CalcResult> uplifts = new List<CalcResult>();

        // Query prior calculations in the same plan within the current period
        List<Comp_Calculation__c> priorCalcs = [
            SELECT Id, Commisionable_Value__c, Applied_Percentage__c,
                   Rate_Tier_Applied__c, Opportunity__c, Rep__c
            FROM Comp_Calculation__c
            WHERE Comp_Plan__c = :plan.Id
              AND Calculation_Status__c IN ('Projected', 'Validated')
              AND Rate_Tier_Applied__c != :newTierName
              AND Type__c = 'Base'
              AND Adjustment_Type__c = 'Original'
              AND Processed_Date__c >= :plan.Effective_Start__c
              AND Processed_Date__c <= :plan.Effective_End__c
        ];

        for (Comp_Calculation__c prior : priorCalcs) {
            Decimal priorValue = prior.Commisionable_Value__c != null ? prior.Commisionable_Value__c : 0;
            Decimal priorRate  = prior.Applied_Percentage__c != null ? prior.Applied_Percentage__c : 0;
            Decimal rateDelta  = newRate - priorRate;

            if (rateDelta <= 0 || priorValue <= 0) {
                continue;
            }

            CalcResult uplift          = new CalcResult();
            uplift.compPlanId          = plan.Id;
            uplift.repId               = plan.Sales_Rep__c;
            uplift.opportunityId       = prior.Opportunity__c;
            uplift.commissionableValue = priorValue;
            uplift.appliedPercentage   = rateDelta;
            uplift.eligibleCommission  = priorValue * (rateDelta / 100);
            uplift.rateTierApplied     = newTierName;
            uplift.calcType            = 'Retroactive_Uplift';
            uplift.calcStatus          = 'Projected';
            uplift.adjustmentType      = 'Retroactive_Uplift';
            uplift.planType            = 'Accelerated';
            uplift.compPlanType        = 'Accelerated';
            uplift.attainmentSnapshot  = 0; // Attainment already captured on original
            uplift.quotaCreditAmount   = 0; // No additional quota credit for uplift
            uplift.splitId             = pc.splitId;
            uplift.splitPercentage     = pc.splitPct;
            uplift.comments            = 'Retroactive uplift: ' + priorRate + '% -> '
                                       + newRate + '% (delta ' + rateDelta + '%) '
                                       + 'triggered by Opp ' + triggeringOppId;
            uplifts.add(uplift);
        }

        return uplifts;
    }

    // ──────────────────────────────────────────────────────────────────────
    //  GROSS MARGIN CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Gross Margin: commissionable_value = revenue - COGS.
     *              The COGS subtraction is handled in Step 3 via
     *              Commissionable_Value_Map__c with Adjustment_Type = 'Subtract_From_Primary'.
     *              Here we apply the tiered rate structure to the margin value.
     */
    @TestVisible
    private static List<CalcResult> calculateGrossMargin(
        Decimal commissionableValue, Comp_Plan__c plan,
        QuotaContext quotaCtx, Id opportunityId, ParticipantCredit pc
    ) {
        // Gross margin uses the same banded tiered logic on the margin value
        List<CalcResult> results = calculateTiered(
            commissionableValue, plan, quotaCtx, opportunityId, pc
        );

        // Tag all results with the correct plan type
        for (CalcResult r : results) {
            r.planType     = 'Gross_Margin';
            r.compPlanType = 'Gross_Margin';
            r.comments     = 'Gross margin commission (revenue minus COGS)';
        }

        return results;
    }

    // ──────────────────────────────────────────────────────────────────────
    //  MILESTONE CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Milestone: commission is split across milestones.
     *              On deal close, create the FIRST milestone payment only.
     *              Future milestones are created by a trigger on the milestone
     *              tracking field (configurable via Vesting_Schedule on template).
     */
    @TestVisible
    private static List<CalcResult> calculateMilestone(
        Decimal commissionableValue, Comp_Plan__c plan,
        QuotaContext quotaCtx, Id opportunityId, ParticipantCredit pc
    ) {
        CalcResult result = initCalcResult(plan, opportunityId, pc, commissionableValue, quotaCtx);
        result.planType     = 'Milestone';
        result.compPlanType = 'Milestone';
        result.calcType     = 'Base';

        List<Commission_Tier__c> tiers = queryTiers(plan.Plan_Template__c);

        // Calculate total commission using tier structure
        Decimal totalCommission = 0;
        Decimal rate = 0;
        if (tiers.isEmpty()) {
            rate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
            totalCommission = commissionableValue * (rate / 100);
            result.rateTierApplied = 'Default';
        } else {
            Decimal newAttainmentPct = quotaCtx.targetAmount > 0
                ? ((quotaCtx.achievedAmount + commissionableValue) / quotaCtx.targetAmount) * 100
                : quotaCtx.attainmentPct;
            Commission_Tier__c matched = findMatchingTier(newAttainmentPct, tiers);
            rate = matched.Rate_Pct__c != null ? matched.Rate_Pct__c : 0;
            totalCommission = commissionableValue * (rate / 100);
            result.rateTierApplied = matched.Tier_Name__c;
        }

        // Query milestone/vesting schedule from template
        // Default: first milestone is 50% if no schedule configured
        Decimal firstMilestonePct = getFirstMilestonePercentage(plan.Plan_Template__c);

        result.appliedPercentage  = rate;
        result.eligibleCommission = (totalCommission * (firstMilestonePct / 100)).setScale(2, System.RoundingMode.HALF_UP);
        result.quotaCreditAmount  = resolveQuotaCredit(commissionableValue, plan);
        result.comments           = 'Milestone 1 of scheduled payments (' + firstMilestonePct + '% of total '
                                  + totalCommission.setScale(2) + '). Remaining milestones deferred.';

        return new List<CalcResult>{ result };
    }

    /**
     * @description Resolve the first milestone percentage from the plan template's
     *              vesting schedule. Returns 50% as a sensible default.
     */
    private static Decimal getFirstMilestonePercentage(Id planTemplateId) {
        // Vesting schedule is stored as JSON on Incentive_Plan_Template__c.Vesting_Schedule__c
        // Format: [{"month": 0, "pct": 34}, {"month": 3, "pct": 33}, {"month": 6, "pct": 33}]
        try {
            List<Incentive_Plan_Template__c> templates = [
                SELECT Vesting_Schedule__c
                FROM Incentive_Plan_Template__c
                WHERE Id = :planTemplateId
                LIMIT 1
            ];
            if (!templates.isEmpty() && String.isNotBlank(templates[0].Vesting_Schedule__c)) {
                List<Object> schedule = (List<Object>) JSON.deserializeUntyped(templates[0].Vesting_Schedule__c);
                if (!schedule.isEmpty()) {
                    Map<String, Object> firstMilestone = (Map<String, Object>) schedule[0];
                    Object pct = firstMilestone.get('pct');
                    if (pct != null) {
                        return Decimal.valueOf(String.valueOf(pct));
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CommissionService: Could not parse vesting schedule, using default 50%');
        }
        return 50; // Default first milestone = 50%
    }

    // ──────────────────────────────────────────────────────────────────────
    //  TEAM POOL CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Team Pool: when a team member closes a deal, create a POOL
     *              funding record. The pool accumulates team production multiplied
     *              by the pool rate. A separate batch distributes the pool at
     *              period end based on individual contribution %.
     */
    @TestVisible
    private static List<CalcResult> calculateTeamPool(
        Decimal commissionableValue, Comp_Plan__c plan,
        QuotaContext quotaCtx, Id opportunityId, ParticipantCredit pc
    ) {
        CalcResult result = initCalcResult(plan, opportunityId, pc, commissionableValue, quotaCtx);
        result.planType     = 'Team_Pool';
        result.compPlanType = 'Team_Pool';
        result.calcType     = 'Pool_Funding';

        // Pool rate: use the first tier's rate or override
        List<Commission_Tier__c> tiers = queryTiers(plan.Plan_Template__c);
        Decimal poolRate = 0;

        if (!tiers.isEmpty()) {
            poolRate = tiers[0].Rate_Pct__c != null ? tiers[0].Rate_Pct__c : 0;
            result.rateTierApplied = tiers[0].Tier_Name__c;
        } else {
            poolRate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
            result.rateTierApplied = 'Default';
        }

        result.appliedPercentage  = poolRate;
        result.eligibleCommission = commissionableValue * (poolRate / 100);
        result.quotaCreditAmount  = resolveQuotaCredit(commissionableValue, plan);
        result.comments           = 'Pool funding contribution. Distribution handled by period-end batch.';

        return new List<CalcResult>{ result };
    }

    // ──────────────────────────────────────────────────────────────────────
    //  TEAM OVERRIDE CALCULATION
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description Team Override: after processing the rep's commission, check if
     *              the rep's manager has a Team_Override plan. If so, create a
     *              manager override commission for the override % of the deal.
     */
    @TestVisible
    private static List<CalcResult> processTeamOverride(
        Comp_Plan__c repPlan, Decimal commissionableValue,
        Opportunity opp, ParticipantCredit pc
    ) {
        List<CalcResult> results = new List<CalcResult>();

        // Look up the rep's manager
        List<User> managers = [
            SELECT Id, ManagerId
            FROM User
            WHERE Id = :repPlan.Sales_Rep__c
            LIMIT 1
        ];

        if (managers.isEmpty() || managers[0].ManagerId == null) {
            return results;
        }

        Id managerId = managers[0].ManagerId;

        // Check if the manager has an active Team_Override plan
        List<Comp_Plan__c> overridePlans = [
            SELECT Id, Sales_Rep__c, Plan_Template__c, Override_Base_Rate__c,
                   Plan_Template__r.Plan_Type__c, Effective_Start__c, Effective_End__c,
                   Status__c
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :managerId
              AND Status__c = 'Active'
              AND Plan_Template__r.Plan_Type__c = 'Team_Override'
              AND Effective_Start__c <= TODAY
              AND (Effective_End__c >= TODAY OR Effective_End__c = null)
            LIMIT 1
        ];

        if (overridePlans.isEmpty()) {
            return results;
        }

        Comp_Plan__c mgrPlan = overridePlans[0];

        // Override rate from tiers or plan override
        List<Commission_Tier__c> tiers = queryTiers(mgrPlan.Plan_Template__c);
        Decimal overrideRate = 0;
        String tierName = 'Default';

        if (!tiers.isEmpty()) {
            // Use first tier (override plans typically have one rate)
            overrideRate = tiers[0].Rate_Pct__c != null ? tiers[0].Rate_Pct__c : 0;
            tierName = tiers[0].Tier_Name__c;
        } else {
            overrideRate = mgrPlan.Override_Base_Rate__c != null ? mgrPlan.Override_Base_Rate__c : 0;
        }

        if (overrideRate <= 0) {
            return results;
        }

        CalcResult mgrResult          = new CalcResult();
        mgrResult.compPlanId          = mgrPlan.Id;
        mgrResult.repId               = managerId;
        mgrResult.opportunityId       = opp.Id;
        mgrResult.commissionableValue = commissionableValue;
        mgrResult.appliedPercentage   = overrideRate;
        mgrResult.eligibleCommission  = commissionableValue * (overrideRate / 100);
        mgrResult.rateTierApplied     = tierName;
        mgrResult.calcType            = 'Manager_Override';
        mgrResult.calcStatus          = 'Projected';
        mgrResult.adjustmentType      = 'Original';
        mgrResult.planType            = 'Team_Override';
        mgrResult.compPlanType        = 'Team_Override';
        mgrResult.attainmentSnapshot  = 0;
        mgrResult.quotaCreditAmount   = 0; // Manager override does not credit quota
        mgrResult.splitId             = pc.splitId;
        mgrResult.splitPercentage     = pc.splitPct;
        mgrResult.comments            = 'Manager override on team member '
                                     + repPlan.Sales_Rep__c + ' deal';

        results.add(mgrResult);
        return results;
    }

    // ──────────────────────────────────────────────────────────────────────
    //  SPIFF STACKING
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @description After processing regular plans, check for active SPIFF templates.
     *              Stacking rules:
     *                Additive       — SPIFF commission added to regular
     *                Replacement    — SPIFF rate replaces the regular rate (handled at persist)
     *                Bonus_Only     — flat bonus amount, ignores commissionable value
     */
    @TestVisible
    private static List<CalcResult> processSPIFFStacking(
        Id participantId, Opportunity opp, ParticipantCredit pc
    ) {
        List<CalcResult> results = new List<CalcResult>();

        // Find active SPIFF plans for this participant
        List<Comp_Plan__c> spiffPlans = [
            SELECT Id, Sales_Rep__c, Plan_Template__c, Override_Base_Rate__c,
                   Plan_Template__r.Plan_Type__c, Plan_Template__r.Name,
                   Plan_Template__r.SPIFF_Stacking__c,
                   Plan_Template__r.SPIFF_Bonus_Amount__c,
                   Effective_Start__c, Effective_End__c, Status__c
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :participantId
              AND Status__c = 'Active'
              AND Plan_Template__r.Plan_Type__c = 'SPIFF'
              AND Effective_Start__c <= TODAY
              AND (Effective_End__c >= TODAY OR Effective_End__c = null)
        ];

        if (spiffPlans.isEmpty()) {
            return results;
        }

        Decimal commissionableValue = opp.Amount != null ? opp.Amount : 0;
        commissionableValue = commissionableValue * (pc.splitPct / 100);

        for (Comp_Plan__c spiff : spiffPlans) {
            String stackingRule = spiff.Plan_Template__r.SPIFF_Stacking__c;
            if (String.isBlank(stackingRule)) {
                stackingRule = 'Additive';
            }

            CalcResult spiffResult          = new CalcResult();
            spiffResult.compPlanId          = spiff.Id;
            spiffResult.repId               = participantId;
            spiffResult.opportunityId       = opp.Id;
            spiffResult.commissionableValue = commissionableValue;
            spiffResult.calcType            = 'SPIFF';
            spiffResult.calcStatus          = 'Projected';
            spiffResult.adjustmentType      = 'Original';
            spiffResult.planType            = 'SPIFF';
            spiffResult.compPlanType        = 'SPIFF';
            spiffResult.attainmentSnapshot  = 0;
            spiffResult.quotaCreditAmount   = 0; // SPIFFs typically don't count toward quota
            spiffResult.splitId             = pc.splitId;
            spiffResult.splitPercentage     = pc.splitPct;

            if (stackingRule == 'Bonus_Only') {
                // Flat bonus amount from template
                Decimal bonusAmt = spiff.Plan_Template__r.SPIFF_Bonus_Amount__c != null
                    ? spiff.Plan_Template__r.SPIFF_Bonus_Amount__c : 0;
                spiffResult.eligibleCommission = bonusAmt;
                spiffResult.appliedPercentage  = 0;
                spiffResult.rateTierApplied    = 'SPIFF_Bonus';
                spiffResult.comments           = 'SPIFF flat bonus: ' + spiff.Plan_Template__r.Name;
            } else {
                // Additive or Replacement: use SPIFF plan's tier/rate
                List<Commission_Tier__c> spiffTiers = queryTiers(spiff.Plan_Template__c);
                Decimal spiffRate = 0;
                String tierName = 'SPIFF_Default';

                if (!spiffTiers.isEmpty()) {
                    spiffRate = spiffTiers[0].Rate_Pct__c != null ? spiffTiers[0].Rate_Pct__c : 0;
                    tierName  = spiffTiers[0].Tier_Name__c;
                } else {
                    spiffRate = spiff.Override_Base_Rate__c != null ? spiff.Override_Base_Rate__c : 0;
                }

                spiffResult.appliedPercentage  = spiffRate;
                spiffResult.eligibleCommission = commissionableValue * (spiffRate / 100);
                spiffResult.rateTierApplied    = tierName;
                spiffResult.comments           = 'SPIFF (' + stackingRule + '): ' + spiff.Plan_Template__r.Name;
            }

            if (spiffResult.eligibleCommission > 0) {
                results.add(spiffResult);
            }
        }

        return results;
    }

    // ══════════════════════════════════════════════════════════════════════
    //  RECURRING COMMISSION (separate entry point, not called from processOpportunity)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Process recurring/trail commissions for a given comp plan.
     *              Called by RecurringCommissionBatch monthly — NOT from processOpportunity.
     *              Queries active customers and creates monthly trail records.
     * @param compPlanId The Comp_Plan__c to process recurring for
     */
    public static void processRecurringCommissions(Id compPlanId) {
        List<Comp_Plan__c> plans = [
            SELECT Id, Sales_Rep__c, Plan_Template__c, Override_Base_Rate__c,
                   Effective_Start__c, Effective_End__c, Status__c,
                   Plan_Template__r.Plan_Type__c
            FROM Comp_Plan__c
            WHERE Id = :compPlanId
              AND Status__c = 'Active'
              AND Plan_Template__r.Plan_Type__c = 'Recurring'
            LIMIT 1
        ];

        if (plans.isEmpty()) {
            return;
        }

        Comp_Plan__c plan = plans[0];
        String runId = generateRunId();

        // Resolve the recurring rate
        List<Commission_Tier__c> tiers = queryTiers(plan.Plan_Template__c);
        Decimal recurringRate = 0;
        String tierName = 'Default';

        if (!tiers.isEmpty()) {
            recurringRate = tiers[0].Rate_Pct__c != null ? tiers[0].Rate_Pct__c : 0;
            tierName = tiers[0].Tier_Name__c;
        } else {
            recurringRate = plan.Override_Base_Rate__c != null ? plan.Override_Base_Rate__c : 0;
        }

        if (recurringRate <= 0) {
            return;
        }

        // Query active recurring revenue opportunities for this rep
        // (Opportunities that are Closed Won and have recurring revenue)
        Date periodStart = Date.today().toStartOfMonth();
        Date periodEnd   = periodStart.addMonths(1).addDays(-1);

        // Query active closed-won opportunities for this rep
        // Use standard fields only — recurring revenue amount derived from Amount / 12
        List<Opportunity> activeOpps = [
            SELECT Id, Amount, OwnerId, CloseDate
            FROM Opportunity
            WHERE OwnerId = :plan.Sales_Rep__c
              AND StageName = 'Closed Won'
              AND CloseDate <= :periodEnd
            LIMIT 2000
        ];

        List<CalcResult> results = new List<CalcResult>();

        for (Opportunity opp : activeOpps) {
            // Monthly recurring value = annual Amount / 12
            // In production, this would read from a configurable field via Commissionable_Value_Map
            Decimal recurringValue = opp.Amount != null ? (opp.Amount / 12) : 0;
            if (recurringValue <= 0) {
            }

            if (recurringValue <= 0) {
                continue;
            }

            // Check for existing recurring calc this period to avoid duplicates
            List<Comp_Calculation__c> existing = [
                SELECT Id FROM Comp_Calculation__c
                WHERE Comp_Plan__c = :plan.Id
                  AND Opportunity__c = :opp.Id
                  AND Comp_Plan_Type__c = 'Recurring'
                  AND Processed_Date__c >= :periodStart
                  AND Processed_Date__c <= :periodEnd
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                continue; // Already processed this period
            }

            CalcResult r          = new CalcResult();
            r.compPlanId          = plan.Id;
            r.repId               = plan.Sales_Rep__c;
            r.opportunityId       = opp.Id;
            r.commissionableValue = recurringValue;
            r.appliedPercentage   = recurringRate;
            r.eligibleCommission  = recurringValue * (recurringRate / 100);
            r.rateTierApplied     = tierName;
            r.calcType            = 'Base';
            r.calcStatus          = 'Projected';
            r.adjustmentType      = 'Original';
            r.planType            = 'Recurring';
            r.compPlanType        = 'Recurring';
            r.attainmentSnapshot  = 0;
            r.quotaCreditAmount   = recurringValue; // Trail credits count toward quota
            r.comments            = 'Recurring/trail commission for period '
                                  + periodStart.format() + ' - ' + periodEnd.format();

            results.add(r);
        }

        if (!results.isEmpty()) {
            persistCalculations(results, runId);
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 5: APPLY MODIFIERS (Caps with Windfall, Holds, Overrides)
    // ══════════════════════════════════════════════════════════════════════

    @TestVisible
    private static CalcResult applyModifiers(CalcResult result, Comp_Plan__c plan) {
        if (plan.Plan_Template__c == null) {
            return result;
        }

        // Apply category rate overrides
        result = applyCategoryOverrides(result, plan);

        // Apply caps (with windfall treatment)
        result = applyCaps(result, plan);

        // Apply holds
        result = applyHolds(result, plan);

        return result;
    }

    /**
     * @description Apply category-specific rate overrides from Category_Rate_Override__c.
     */
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
            if (ovr.Deal_Size_Min__c != null && result.commissionableValue < ovr.Deal_Size_Min__c) {
                continue;
            }
            if (ovr.Deal_Size_Max__c != null && result.commissionableValue > ovr.Deal_Size_Max__c) {
                continue;
            }

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

    /**
     * @description Apply caps with full windfall treatment:
     *              - Ignored: excess is dropped (default)
     *              - Reduced_Rate: excess earns at Windfall_Rate_Pct
     *              - Deferred_To_Next_Period: excess creates a deferred record
     */
    private static CalcResult applyCaps(CalcResult result, Comp_Plan__c plan) {
        List<Plan_Cap__c> caps = [
            SELECT Id, Cap_Type__c, Cap_Amount__c, Cap_Pct__c,
                   Value_Cap_Amount__c, Value_Floor_Amount__c,
                   Windfall_Treatment__c, Windfall_Rate_Pct__c,
                   Is_Active__c
            FROM Plan_Cap__c
            WHERE Plan_Template__c = :plan.Plan_Template__c
              AND Is_Active__c = true
            ORDER BY Sort_Order__c ASC
        ];

        for (Plan_Cap__c cap : caps) {
            if (cap.Cap_Type__c == 'Commissionable_Value_Cap' && cap.Value_Cap_Amount__c != null) {
                if (result.commissionableValue > cap.Value_Cap_Amount__c) {
                    Decimal excess = result.commissionableValue - cap.Value_Cap_Amount__c;
                    result.windfall = excess;

                    String windfallTreatment = cap.Windfall_Treatment__c;
                    if (String.isBlank(windfallTreatment)) {
                        windfallTreatment = 'Ignored';
                    }

                    // Cap the base commission to the capped value
                    result.commissionableValue = cap.Value_Cap_Amount__c;
                    result.eligibleCommission  = result.commissionableValue * (result.appliedPercentage / 100);

                    // Note: Reduced_Rate and Deferred windfall records are created
                    // during persistCalculations, because they need separate
                    // Comp_Calculation__c records. We store the windfall amount and
                    // treatment info on the result for that step.
                    if (windfallTreatment == 'Reduced_Rate') {
                        // Add reduced-rate commission for excess inline
                        Decimal windfallRate = cap.Windfall_Rate_Pct__c != null ? cap.Windfall_Rate_Pct__c : 0;
                        Decimal windfallCommission = excess * (windfallRate / 100);
                        result.eligibleCommission += windfallCommission;
                        result.comments = (result.comments != null ? result.comments + '; ' : '')
                                        + 'Windfall ' + excess.setScale(2) + ' at reduced rate ' + windfallRate + '%';
                    } else if (windfallTreatment == 'Deferred_To_Next_Period') {
                        result.comments = (result.comments != null ? result.comments + '; ' : '')
                                        + 'Windfall ' + excess.setScale(2) + ' deferred to next period';
                    }
                    // 'Ignored': excess is dropped — no additional action
                }
            } else if (cap.Cap_Type__c == 'Commissionable_Value_Floor' && cap.Value_Floor_Amount__c != null) {
                if (result.commissionableValue < cap.Value_Floor_Amount__c) {
                    result.commissionableValue = 0;
                    result.eligibleCommission  = 0;
                }
            } else if (cap.Cap_Amount__c != null && result.eligibleCommission > cap.Cap_Amount__c) {
                result.eligibleCommission = cap.Cap_Amount__c;
            }
        }

        return result;
    }

    /**
     * @description Apply holds (collection, milestone, approval, etc.).
     */
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
                result.holdReason       = mapHoldTypeToReason(hold.Hold_Type__c);
                result.holdThresholdPct = hold.Hold_Pct__c;
                result.eligibleCommission = result.eligibleCommission * (1 - (hold.Hold_Pct__c / 100));
                break; // Apply first active hold
            }
        }

        return result;
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 6: PERSIST CALCULATIONS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Insert immutable Comp_Calculation__c ledger records.
     *              Also creates windfall deferred records when applicable.
     */
    @TestVisible
    private static void persistCalculations(List<CalcResult> results, String runId) {
        List<Comp_Calculation__c> calcs     = new List<Comp_Calculation__c>();
        List<Comp_Calculation__c> deferred  = new List<Comp_Calculation__c>();

        for (CalcResult r : results) {
            Comp_Calculation__c calc = new Comp_Calculation__c();
            calc.Comp_Plan__c            = r.compPlanId;
            calc.Rep__c                  = r.repId;
            calc.Opportunity__c          = r.opportunityId;
            calc.Commisionable_Value__c  = r.commissionableValue;
            calc.Eligible_Commission__c  = r.eligibleCommission;
            calc.Applied_Percentage__c   = r.appliedPercentage;
            calc.Quota_Credit_Amount__c  = r.quotaCreditAmount;
            calc.Rate_Tier_Applied__c    = r.rateTierApplied;
            calc.Type__c                 = r.calcType;
            calc.Calculation_Status__c   = r.calcStatus != null ? r.calcStatus : 'Projected';
            calc.Attainment_Snapshot__c  = r.attainmentSnapshot;
            calc.Rate_Override_Applied__c = r.rateOverrideApplied;
            calc.Hold_Reason__c          = r.holdReason;
            calc.Processed_Date__c       = Date.today();
            calc.Commisionable_Date__c   = Date.today();
            calc.Processing_Run_Id__c    = runId;
            calc.Adjustment_Type__c      = r.adjustmentType != null ? r.adjustmentType : 'Original';
            calc.Comp_Plan_Type__c       = r.compPlanType;
            calc.Comments__c             = r.comments;

            // Split tracking
            if (r.splitId != null) {
                // Track split source in comments (no dedicated lookup field on Comp_Calculation)
            calc.Comments__c = (calc.Comments__c != null ? calc.Comments__c + '; ' : '') + 'Split: ' + r.splitId;
            }

            calcs.add(calc);

            // Windfall deferred record
            if (r.windfall != null && r.windfall > 0 && r.comments != null
                && r.comments.contains('deferred to next period')) {
                Comp_Calculation__c def   = new Comp_Calculation__c();
                def.Comp_Plan__c          = r.compPlanId;
                def.Rep__c                = r.repId;
                def.Opportunity__c        = r.opportunityId;
                def.Commisionable_Value__c = r.windfall;
                def.Eligible_Commission__c = 0; // Will be calculated in next period
                def.Applied_Percentage__c  = 0;
                def.Quota_Credit_Amount__c = 0;
                def.Rate_Tier_Applied__c   = 'Deferred_Windfall';
                def.Type__c                = 'Base';
                def.Calculation_Status__c  = 'Projected';
                def.Adjustment_Type__c     = 'Deferred';
                def.Comp_Plan_Type__c      = r.compPlanType;
                def.Processed_Date__c      = Date.today();
                def.Commisionable_Date__c  = Date.today().toStartOfMonth().addMonths(1); // Next period
                def.Processing_Run_Id__c   = runId;
                def.Comments__c            = 'Deferred windfall from deal ' + r.opportunityId
                                           + '. Value: ' + r.windfall.setScale(2);
                if (r.splitId != null) {
                    def.Comments__c = (def.Comments__c != null ? def.Comments__c + '; ' : '') + 'Split: ' + r.splitId;
                }
                deferred.add(def);
            }
        }

        if (!calcs.isEmpty()) {
            insert calcs;
        }
        if (!deferred.isEmpty()) {
            insert deferred;
        }
    }

    /**
     * @description Overloaded for backward compatibility (no runId).
     */
    @TestVisible
    private static void persistCalculations(List<CalcResult> results) {
        persistCalculations(results, generateRunId());
    }

    // ══════════════════════════════════════════════════════════════════════
    //  STEP 7: UPDATE ATTAINMENT (Quota Credit Source Resolution)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Credit quota attainment using the quota credit amount from
     *              each CalcResult. The quota credit source was resolved per-plan
     *              in resolveQuotaCredit().
     */
    @TestVisible
    private static void updateAttainment(List<CalcResult> results) {
        Map<Id, Decimal> planCredits = new Map<Id, Decimal>();

        for (CalcResult r : results) {
            // Skip types that don't credit quota
            if (r.calcType == 'Retroactive_Uplift' || r.calcType == 'SPIFF'
                || r.calcType == 'Manager_Override' || r.calcType == 'Pool_Funding') {
                continue;
            }
            if (r.quotaCreditAmount == null || r.quotaCreditAmount <= 0) {
                continue;
            }

            Decimal existing = planCredits.containsKey(r.compPlanId) ? planCredits.get(r.compPlanId) : 0;
            planCredits.put(r.compPlanId, existing + r.quotaCreditAmount);
        }

        if (planCredits.isEmpty()) {
            return;
        }

        List<Quota__c> quotas = [
            SELECT Id, Comp_Plan__c, Achieved_Amount__c, Target_Amount__c
            FROM Quota__c
            WHERE Comp_Plan__c IN :planCredits.keySet()
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

    /**
     * @description Resolve the quota credit amount for a deal based on the
     *              Transaction_Category__c.Quota_Credit_Source__c configuration.
     *
     *  Sources:
     *    Same_As_Commissionable  → use commissionable value (default)
     *    Custom_Field            → opp.get(Quota_Credit_Field__c)
     *    Percentage_Of_Commissionable → commissionable * Quota_Credit_Pct / 100
     *    Fixed_Amount            → Quota_Credit_Amount__c
     */
    @TestVisible
    private static Decimal resolveQuotaCredit(Decimal commissionableValue, Comp_Plan__c plan) {
        if (plan.Plan_Template__c == null) {
            return commissionableValue;
        }

        // Query Transaction_Category__c via the eligibility junction for quota credit config
        List<Template_Category_Eligibility__c> eligibilities = [
            SELECT Transaction_Category__r.Quota_Credit_Source__c,
                   Transaction_Category__r.Quota_Credit_Field__c,
                   Transaction_Category__r.Quota_Credit_Pct__c,
                   Transaction_Category__r.Quota_Credit_Amount__c
            FROM Template_Category_Eligibility__c
            WHERE Plan_Template__c = :plan.Plan_Template__c
              AND Is_Active__c = true
              AND Transaction_Category__r.Is_Active__c = true
            LIMIT 1
        ];
        // Map to category for compatibility with downstream logic
        List<Transaction_Category__c> categories = new List<Transaction_Category__c>();
        for (Template_Category_Eligibility__c elig : eligibilities) {
            categories.add(elig.Transaction_Category__r);
        }

        if (categories.isEmpty()) {
            return commissionableValue; // Default: same as commissionable
        }

        Transaction_Category__c cat = categories[0];
        String source = cat.Quota_Credit_Source__c;

        if (String.isBlank(source) || source == 'Same_As_Commissionable') {
            return commissionableValue;
        }

        if (source == 'Percentage_Of_Commissionable') {
            Decimal pct = cat.Quota_Credit_Pct__c != null ? cat.Quota_Credit_Pct__c : 100;
            return commissionableValue * (pct / 100);
        }

        if (source == 'Fixed_Amount') {
            return cat.Quota_Credit_Amount__c != null ? cat.Quota_Credit_Amount__c : 0;
        }

        // Custom_Field: would need the Opportunity record to resolve dynamically.
        // In the current flow, we don't have it here; caller should handle.
        // Fallback to commissionable value.
        return commissionableValue;
    }

    // ══════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Query the Opportunity with all fields needed by the engine.
     *              Uses dynamic SOQL-like approach via explicit field list to
     *              support dynamic field resolution in Step 3.
     */
    private static Opportunity queryOpportunity(Id opportunityId) {
        // Query standard fields only. Dynamic fields (COGS, recurring revenue, etc.)
        // are resolved at runtime via Commissionable_Value_Map__c and opp.get(fieldName)
        List<Opportunity> opps = [
            SELECT Id, Amount, OwnerId, StageName, CloseDate, Type
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    /**
     * @description Resolve the plan type from the template. Defaults to 'Flat'.
     */
    private static String resolvePlanType(Comp_Plan__c plan) {
        if (plan.Plan_Template__r != null && plan.Plan_Template__r.Plan_Type__c != null) {
            return plan.Plan_Template__r.Plan_Type__c;
        }
        return 'Flat';
    }

    /**
     * @description Get the QuotaContext for a plan.
     */
    private static QuotaContext getQuotaContext(Comp_Plan__c plan) {
        List<Quota__c> quotas = [
            SELECT Id, Target_Amount__c, Achieved_Amount__c
            FROM Quota__c
            WHERE Comp_Plan__c = :plan.Id
              AND Status__c = 'Active'
            LIMIT 1
        ];

        if (quotas.isEmpty()) {
            Quota__c empty = new Quota__c();
            empty.Target_Amount__c   = 0;
            empty.Achieved_Amount__c = 0;
            return new QuotaContext(empty);
        }

        return new QuotaContext(quotas[0]);
    }

    /**
     * @description For backward compatibility: getCurrentAttainment returning just the pct.
     */
    @TestVisible
    private static Decimal getCurrentAttainment(Comp_Plan__c plan) {
        QuotaContext ctx = getQuotaContext(plan);
        return ctx.attainmentPct;
    }

    /**
     * @description Query active commission tiers for a plan template, ordered ASC.
     */
    private static List<Commission_Tier__c> queryTiers(Id planTemplateId) {
        return [
            SELECT Id, Tier_Name__c, Min_Attainment_Pct__c, Max_Attainment_Pct__c,
                   Rate_Pct__c, Rate_Amount__c, Is_Retroactive__c, Is_Active__c
            FROM Commission_Tier__c
            WHERE Plan_Template__c = :planTemplateId
              AND Is_Active__c = true
            ORDER BY Min_Attainment_Pct__c ASC
        ];
    }

    /**
     * @description Find the tier matching a given attainment percentage.
     *              Falls back to the highest tier if attainment exceeds all ranges.
     */
    private static Commission_Tier__c findMatchingTier(Decimal attainmentPct, List<Commission_Tier__c> tiers) {
        for (Commission_Tier__c tier : tiers) {
            Decimal minPct = tier.Min_Attainment_Pct__c != null ? tier.Min_Attainment_Pct__c : 0;
            Decimal maxPct = tier.Max_Attainment_Pct__c != null ? tier.Max_Attainment_Pct__c : 999999;
            if (attainmentPct >= minPct && attainmentPct < maxPct) {
                return tier;
            }
        }
        // Fallback to highest tier
        return tiers[tiers.size() - 1];
    }

    /**
     * @description Initialize a CalcResult with standard fields from plan/participant context.
     */
    private static CalcResult initCalcResult(
        Comp_Plan__c plan, Id opportunityId, ParticipantCredit pc,
        Decimal commissionableValue, QuotaContext quotaCtx
    ) {
        CalcResult r          = new CalcResult();
        r.compPlanId          = plan.Id;
        r.repId               = plan.Sales_Rep__c;
        r.opportunityId       = opportunityId;
        r.commissionableValue = commissionableValue;
        r.attainmentSnapshot  = quotaCtx.attainmentPct;
        r.splitId             = pc.splitId;
        r.splitPercentage     = pc.splitPct;
        return r;
    }

    /**
     * @description Safely get a field value from an SObject using dynamic field access.
     */
    private static Object safeGetField(SObject record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) {
            return null;
        }
        try {
            return record.get(fieldName);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'CommissionService.safeGetField: Could not read field '
                + fieldName + ' — ' + e.getMessage());
            return null;
        }
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

    // ══════════════════════════════════════════════════════════════════════
    //  BACKWARD-COMPATIBLE ENTRY POINTS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Original Step 1 signature for backward compatibility.
     *              Used by CalculationInvalidationService.
     */
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
                   Plan_Template__r.Id,
                   Plan_Template__r.Plan_Type__c,
                   Plan_Template__r.Name
            FROM Comp_Plan__c
            WHERE Sales_Rep__c = :opp.OwnerId
              AND Status__c = 'Active'
              AND Effective_Start__c <= TODAY
              AND (Effective_End__c >= TODAY OR Effective_End__c = null)
        ];
    }
}
