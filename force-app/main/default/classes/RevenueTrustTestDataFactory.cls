/**
 * @description Test data factory for RevenueTrust custom objects.
 *              Creates fully wired test records with sensible defaults.
 *              All methods accept optional overrides via parameter maps.
 */
@IsTest
public class RevenueTrustTestDataFactory {

    // ── Plan Year ────────────────────────────────────────────────────────

    public static Plan_Year__c createPlanYear() {
        Plan_Year__c py = new Plan_Year__c(
            Name = 'FY' + Date.today().year()
        );
        insert py;
        return py;
    }

    // ── Participant Role ─────────────────────────────────────────────────

    public static Participant_Role__c createParticipantRole() {
        Participant_Role__c pr = new Participant_Role__c(
            Name = 'Account Executive',
            Role_Code__c = 'AE',
            Default_OTE__c = 200000,
            Default_Base_Pay__c = 100000,
            Default_Variable_Pct__c = 50,
            Eligibility_Type__c = 'Opportunity_Role_Field',
            Scope__c = 'Deal_Level',
            Is_Active__c = true
        );
        insert pr;
        return pr;
    }

    // ── Incentive Plan Template ──────────────────────────────────────────

    public static Incentive_Plan_Template__c createPlanTemplate() {
        return createPlanTemplate('Standard Commission Plan');
    }

    public static Incentive_Plan_Template__c createPlanTemplate(String name) {
        Incentive_Plan_Template__c tpl = new Incentive_Plan_Template__c(
            Name = name
        );
        insert tpl;
        return tpl;
    }

    // ── Commission Tiers ─────────────────────────────────────────────────

    public static List<Commission_Tier__c> createStandardTiers(Id planTemplateId) {
        List<Commission_Tier__c> tiers = new List<Commission_Tier__c>{
            new Commission_Tier__c(
                Plan_Template__c = planTemplateId,
                Tier_Name__c = 'Base',
                Min_Attainment_Pct__c = 0,
                Max_Attainment_Pct__c = 100,
                Rate_Pct__c = 8,
                Is_Retroactive__c = false,
                Is_Active__c = true,
                Sort_Order__c = 1
            ),
            new Commission_Tier__c(
                Plan_Template__c = planTemplateId,
                Tier_Name__c = 'Accelerator',
                Min_Attainment_Pct__c = 100,
                Max_Attainment_Pct__c = 150,
                Rate_Pct__c = 12,
                Is_Retroactive__c = false,
                Is_Active__c = true,
                Sort_Order__c = 2
            ),
            new Commission_Tier__c(
                Plan_Template__c = planTemplateId,
                Tier_Name__c = 'Super Accelerator',
                Min_Attainment_Pct__c = 150,
                Max_Attainment_Pct__c = null,
                Rate_Pct__c = 15,
                Is_Retroactive__c = true,
                Is_Active__c = true,
                Sort_Order__c = 3
            )
        };
        insert tiers;
        return tiers;
    }

    // ── Comp Plan ────────────────────────────────────────────────────────

    public static Comp_Plan__c createCompPlan(Id salesRepId, Id planTemplateId, Id participantRoleId) {
        Date yearStart = Date.newInstance(Date.today().year(), 1, 1);
        Comp_Plan__c cp = new Comp_Plan__c(
            Sales_Rep__c = salesRepId,
            Plan_Template__c = planTemplateId,
            Participant_Role__c = participantRoleId,
            OTE__c = 200000,
            Base_Pay__c = 100000,
            Variable_Compensation__c = 100000,
            Status__c = 'Active',
            Effective_Start__c = yearStart,
            Effective_End__c = yearStart.addYears(1).addDays(-1)
        );
        insert cp;
        return cp;
    }

    // ── Quota ────────────────────────────────────────────────────────────

    public static Quota__c createQuota(Id compPlanId, Id participantId, Decimal target) {
        Date yearStart = Date.newInstance(Date.today().year(), 1, 1);
        Quota__c q = new Quota__c(
            Comp_Plan__c = compPlanId,
            Participant__c = participantId,
            Target_Amount__c = target,
            Achieved_Amount__c = 0,
            Period_Type__c = 'Annual',
            Status__c = 'Active',
            Period_Start__c = yearStart,
            Period_End__c = yearStart.addYears(1).addDays(-1),
            Metric__c = 'Primary'
        );
        insert q;
        return q;
    }

    // ── Transaction Category ─────────────────────────────────────────────

    public static Transaction_Category__c createTransactionCategory() {
        Transaction_Category__c tc = new Transaction_Category__c(
            Name = 'New Business',
            Category_Code__c = 'NB',
            Category_Source__c = 'Picklist_Field',
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert tc;
        return tc;
    }

    // ── Commissionable Value Map ─────────────────────────────────────────

    public static Commissionable_Value_Map__c createValueMap(Id transactionCategoryId) {
        Commissionable_Value_Map__c cvm = new Commissionable_Value_Map__c(
            Name = 'Amount Map',
            Transaction_Category__c = transactionCategoryId,
            Opportunity_Field__c = 'Amount',
            Field_Label__c = 'Deal Amount',
            Is_Primary__c = true,
            Is_Attainment_Value__c = true,
            Sort_Order__c = 1
        );
        insert cvm;
        return cvm;
    }

    // ── Plan Cap ─────────────────────────────────────────────────────────

    public static Plan_Cap__c createPlanCap(Id planTemplateId, Decimal capAmount) {
        Plan_Cap__c pc = new Plan_Cap__c(
            Name = 'Per-Deal Cap',
            Plan_Template__c = planTemplateId,
            Cap_Type__c = 'Commissionable_Value_Cap',
            Cap_Amount__c = capAmount,
            Value_Cap_Amount__c = capAmount,
            Period_Scope__c = 'Annual',
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert pc;
        return pc;
    }

    // ── Plan Hold ────────────────────────────────────────────────────────

    public static Plan_Hold__c createPlanHold(Id planTemplateId, Decimal holdPct) {
        Plan_Hold__c ph = new Plan_Hold__c(
            Name = 'Collection Hold',
            Plan_Template__c = planTemplateId,
            Hold_Type__c = 'Collection_Hold',
            Hold_Pct__c = holdPct,
            Release_Trigger__c = 'Automatic_On_Collection',
            Release_Mode__c = 'Binary_At_Threshold',
            Release_Days__c = 90,
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert ph;
        return ph;
    }

    // ── Category Rate Override ───────────────────────────────────────────

    public static Category_Rate_Override__c createCategoryOverride(
        Id planTemplateId, Id transactionCategoryId, Decimal ratePct, String modifier
    ) {
        Category_Rate_Override__c cro = new Category_Rate_Override__c(
            Name = 'Override Rate',
            Plan_Template__c = planTemplateId,
            Transaction_Category__c = transactionCategoryId,
            Rate_Pct__c = ratePct,
            Rate_Modifier__c = modifier,
            Override_Type__c = 'Product',
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert cro;
        return cro;
    }

    // ── Opportunity ──────────────────────────────────────────────────────

    public static Opportunity createOpportunity(Decimal amount, String stage) {
        Opportunity opp = new Opportunity(
            Name = 'Test Deal',
            Amount = amount,
            StageName = stage,
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }

    public static Opportunity createClosedWonOpportunity(Decimal amount) {
        return createOpportunity(amount, 'Closed Won');
    }

    // ── Full Test Scenario ───────────────────────────────────────────────

    /**
     * @description Creates a complete commission scenario:
     *  Plan Template → Tiers → Comp Plan → Quota → Opportunity
     *  Returns a map of created record Ids keyed by type name.
     */
    public static Map<String, Id> createFullCommissionScenario(Decimal dealAmount, Decimal quotaTarget) {
        Participant_Role__c role = createParticipantRole();
        Incentive_Plan_Template__c tpl = createPlanTemplate();
        List<Commission_Tier__c> tiers = createStandardTiers(tpl.Id);
        Comp_Plan__c plan = createCompPlan(UserInfo.getUserId(), tpl.Id, role.Id);
        Quota__c quota = createQuota(plan.Id, UserInfo.getUserId(), quotaTarget);
        Opportunity opp = createOpportunity(dealAmount, 'Prospecting');

        Map<String, Id> result = new Map<String, Id>();
        result.put('ParticipantRole', role.Id);
        result.put('PlanTemplate', tpl.Id);
        result.put('CompPlan', plan.Id);
        result.put('Quota', quota.Id);
        result.put('Opportunity', opp.Id);
        return result;
    }

    // ── Comp Calculation ────────────────────────────────────────────────

    public static Comp_Calculation__c createCompCalculation(Id compPlanId, Id opportunityId, String status) {
        Comp_Calculation__c calc = new Comp_Calculation__c(
            Comp_Plan__c = compPlanId,
            Opportunity__c = opportunityId,
            Calculation_Status__c = status,
            Eligible_Commission__c = 5000,
            Commisionable_Value__c = 50000,
            Applied_Percentage__c = 10,
            Contract_Date2__c = Date.today(),
            Hold_Status__c = 'Not_Held'
        );
        insert calc;
        return calc;
    }

    public static List<Comp_Calculation__c> createCompCalculations(
        Id compPlanId, Id opportunityId, String status, Integer count
    ) {
        List<Comp_Calculation__c> calcs = new List<Comp_Calculation__c>();
        for (Integer i = 0; i < count; i++) {
            calcs.add(new Comp_Calculation__c(
                Comp_Plan__c = compPlanId,
                Opportunity__c = opportunityId,
                Calculation_Status__c = status,
                Eligible_Commission__c = 5000,
                Commisionable_Value__c = 50000,
                Applied_Percentage__c = 10,
                Contract_Date2__c = Date.today(),
                Hold_Status__c = 'Not_Held'
            ));
        }
        insert calcs;
        return calcs;
    }

    // ── Forecast Configuration ──────────────────────────────────────────

    public static Forecast_Configuration__c createForecastConfiguration() {
        Forecast_Configuration__c fc = new Forecast_Configuration__c(
            Name = 'Default Config',
            Is_Active__c = true,
            Is_Default__c = true,
            Period_Type__c = 'Monthly',
            Fiscal_Year_Start_Month__c = 1
        );
        insert fc;
        return fc;
    }

    // ── Forecast Period ─────────────────────────────────────────────────

    public static Forecast_Period__c createForecastPeriod(Id forecastConfigId, String status) {
        Date periodStart = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        Date periodEnd = periodStart.addMonths(1).addDays(-1);
        Forecast_Period__c fp = new Forecast_Period__c(
            Name = 'FP-' + Date.today().month(),
            Forecast_Configuration__c = forecastConfigId,
            Period_Label__c = 'Q' + ((Date.today().month() - 1) / 3 + 1) + ' ' + Date.today().year(),
            Period_Type__c = 'Monthly',
            Start_Date__c = periodStart,
            End_Date__c = periodEnd,
            Status__c = status
        );
        insert fp;
        return fp;
    }

    // ── Failed Event ────────────────────────────────────────────────────

    public static Failed_Event__c createFailedEvent(String eventType, String payload, String status) {
        Failed_Event__c fe = new Failed_Event__c(
            Event_Type__c = eventType,
            Payload__c = payload,
            Error_Message__c = 'Test alert for ' + eventType,
            Retry_Count__c = 0,
            Status__c = status,
            Original_Event_Time__c = Datetime.now()
        );
        insert fe;
        return fe;
    }
}
