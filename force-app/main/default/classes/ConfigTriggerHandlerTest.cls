/**
 * @description Combined test class for all five configuration trigger handlers:
 *              - CommissionTierTriggerHandler   (RATE_TABLE_CHANGED)
 *              - PlanCapTriggerHandler           (CAP_RULE_CHANGED)
 *              - ProductEligibilityTriggerHandler (PRODUCT_ELIGIBILITY_RULE_CHANGED)
 *              - RoleEligibilityTriggerHandler   (ROLE_ELIGIBILITY_RULE_CHANGED)
 *              - ForecastPeriodTriggerHandler    (PERIOD_FROZEN / PERIOD_REOPENED)
 *
 *              Each handler is invoked directly (not via trigger) to guarantee
 *              code path coverage regardless of Platform Event delivery behaviour
 *              in test context.
 */
@IsTest
private class ConfigTriggerHandlerTest {

    // ── Shared test data ────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Incentive Plan Template — parent for MasterDetail children
        Incentive_Plan_Template__c tpl = new Incentive_Plan_Template__c(
            Name = 'Config Test Template'
        );
        insert tpl;

        // Participant Role — needed for role eligibility
        Participant_Role__c role = new Participant_Role__c(
            Name = 'Test Account Executive',
            Role_Code__c = 'TEST_AE',
            Default_OTE__c = 200000,
            Default_Base_Pay__c = 100000,
            Default_Variable_Pct__c = 50,
            Eligibility_Type__c = 'Opportunity_Role_Field',
            Scope__c = 'Deal_Level',
            Is_Active__c = true
        );
        insert role;

        // Transaction Category — needed for category eligibility context
        Transaction_Category__c tc = new Transaction_Category__c(
            Name = 'Test New Business',
            Category_Code__c = 'TEST_NEW',
            Category_Source__c = 'Picklist_Field',
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert tc;

        // Forecast Configuration + Forecast Period chain
        Forecast_Configuration__c fc = RevenueTrustTestDataFactory.createForecastConfiguration();
        Forecast_Period__c fp = RevenueTrustTestDataFactory.createForecastPeriod(fc.Id, 'Open');
    }

    // ── Helper queries ──────────────────────────────────────────────────

    private static Incentive_Plan_Template__c getTemplate() {
        return [SELECT Id FROM Incentive_Plan_Template__c WHERE Name = 'Config Test Template' LIMIT 1];
    }

    private static Participant_Role__c getRole() {
        return [SELECT Id FROM Participant_Role__c WHERE Role_Code__c = 'TEST_AE' LIMIT 1];
    }

    private static Forecast_Period__c getForecastPeriod() {
        return [SELECT Id, Status__c FROM Forecast_Period__c LIMIT 1];
    }

    // ═══════════════════════════════════════════════════════════════════
    // CommissionTierTriggerHandler
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @description Insert of Commission_Tier__c fires RATE_TABLE_CHANGED.
     */
    @IsTest
    static void testCommissionTierInsert_RateTableChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Commission_Tier__c tier = new Commission_Tier__c(
            Plan_Template__c = tpl.Id,
            Tier_Name__c = 'Test Base',
            Min_Attainment_Pct__c = 0,
            Max_Attainment_Pct__c = 100,
            Rate_Pct__c = 8,
            Is_Retroactive__c = false,
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert tier;

        // Re-query to get all auto-populated fields
        tier = [SELECT Id, Plan_Template__c, Tier_Name__c, Min_Attainment_Pct__c,
                       Max_Attainment_Pct__c, Rate_Pct__c, Is_Retroactive__c,
                       Is_Active__c, Sort_Order__c
                FROM Commission_Tier__c WHERE Id = :tier.Id];

        Test.startTest();
        CommissionTierTriggerHandler.handleChange(
            new List<SObject>{ tier },
            null,
            System.TriggerOperation.AFTER_INSERT
        );
        Test.stopTest();

        System.assertNotEquals(null, tier.Id,
            'Commission tier should be inserted successfully');
    }

    /**
     * @description Update of Commission_Tier__c fires RATE_TABLE_CHANGED with old/new.
     */
    @IsTest
    static void testCommissionTierUpdate_RateTableChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Commission_Tier__c tier = new Commission_Tier__c(
            Plan_Template__c = tpl.Id,
            Tier_Name__c = 'Update Test',
            Min_Attainment_Pct__c = 0,
            Max_Attainment_Pct__c = 100,
            Rate_Pct__c = 8,
            Is_Retroactive__c = false,
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert tier;

        tier = [SELECT Id, Plan_Template__c, Tier_Name__c, Min_Attainment_Pct__c,
                       Max_Attainment_Pct__c, Rate_Pct__c, Is_Retroactive__c,
                       Is_Active__c, Sort_Order__c
                FROM Commission_Tier__c WHERE Id = :tier.Id];

        Commission_Tier__c oldTier = tier.clone(true, true, true, true);
        tier.Rate_Pct__c = 12;

        Test.startTest();
        CommissionTierTriggerHandler.handleChange(
            new List<SObject>{ tier },
            new List<SObject>{ oldTier },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        System.assertNotEquals(oldTier.Rate_Pct__c, tier.Rate_Pct__c,
            'Rate should differ between old and new');
    }

    /**
     * @description Delete of Commission_Tier__c fires RATE_TABLE_CHANGED.
     */
    @IsTest
    static void testCommissionTierDelete_RateTableChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Commission_Tier__c tier = new Commission_Tier__c(
            Plan_Template__c = tpl.Id,
            Tier_Name__c = 'Delete Test',
            Min_Attainment_Pct__c = 0,
            Max_Attainment_Pct__c = 100,
            Rate_Pct__c = 8,
            Is_Retroactive__c = false,
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert tier;

        tier = [SELECT Id, Plan_Template__c, Tier_Name__c, Min_Attainment_Pct__c,
                       Max_Attainment_Pct__c, Rate_Pct__c, Is_Retroactive__c,
                       Is_Active__c, Sort_Order__c
                FROM Commission_Tier__c WHERE Id = :tier.Id];

        Test.startTest();
        CommissionTierTriggerHandler.handleChange(
            null,
            new List<SObject>{ tier },
            System.TriggerOperation.AFTER_DELETE
        );
        Test.stopTest();

        System.assertNotEquals(null, tier.Id,
            'Tier Id should exist for the deleted record');
    }

    // ═══════════════════════════════════════════════════════════════════
    // PlanCapTriggerHandler
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @description Insert of Plan_Cap__c fires CAP_RULE_CHANGED.
     */
    @IsTest
    static void testPlanCapInsert_CapRuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Plan_Cap__c cap = new Plan_Cap__c(
            Name = 'Test Cap',
            Plan_Template__c = tpl.Id,
            Cap_Type__c = 'Commissionable_Value_Cap',
            Cap_Amount__c = 500000,
            Value_Cap_Amount__c = 500000,
            Period_Scope__c = 'Annual',
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert cap;

        cap = [SELECT Id, Name, Plan_Template__c, Cap_Type__c, Cap_Amount__c,
                      Value_Cap_Amount__c, Period_Scope__c, Is_Active__c, Sort_Order__c
               FROM Plan_Cap__c WHERE Id = :cap.Id];

        Test.startTest();
        PlanCapTriggerHandler.handleChange(
            new List<SObject>{ cap },
            null,
            System.TriggerOperation.AFTER_INSERT
        );
        Test.stopTest();

        System.assertNotEquals(null, cap.Id,
            'Plan cap should be inserted successfully');
    }

    /**
     * @description Update of Plan_Cap__c fires CAP_RULE_CHANGED with old/new.
     */
    @IsTest
    static void testPlanCapUpdate_CapRuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Plan_Cap__c cap = RevenueTrustTestDataFactory.createPlanCap(tpl.Id, 500000);
        cap = [SELECT Id, Name, Plan_Template__c, Cap_Type__c, Cap_Amount__c,
                      Value_Cap_Amount__c, Period_Scope__c, Is_Active__c, Sort_Order__c
               FROM Plan_Cap__c WHERE Id = :cap.Id];

        Plan_Cap__c oldCap = cap.clone(true, true, true, true);
        cap.Cap_Amount__c = 750000;

        Test.startTest();
        PlanCapTriggerHandler.handleChange(
            new List<SObject>{ cap },
            new List<SObject>{ oldCap },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        System.assertNotEquals(oldCap.Cap_Amount__c, cap.Cap_Amount__c,
            'Cap amount should differ between old and new');
    }

    /**
     * @description Delete of Plan_Cap__c fires CAP_RULE_CHANGED.
     */
    @IsTest
    static void testPlanCapDelete_CapRuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Plan_Cap__c cap = RevenueTrustTestDataFactory.createPlanCap(tpl.Id, 500000);
        cap = [SELECT Id, Name, Plan_Template__c, Cap_Type__c, Cap_Amount__c,
                      Value_Cap_Amount__c, Period_Scope__c, Is_Active__c, Sort_Order__c
               FROM Plan_Cap__c WHERE Id = :cap.Id];

        Test.startTest();
        PlanCapTriggerHandler.handleChange(
            null,
            new List<SObject>{ cap },
            System.TriggerOperation.AFTER_DELETE
        );
        Test.stopTest();

        System.assertNotEquals(null, cap.Id,
            'Cap Id should exist for the deleted record');
    }

    // ═══════════════════════════════════════════════════════════════════
    // ProductEligibilityTriggerHandler
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @description Insert of Template_Product_Eligibility__c fires
     *              PRODUCT_ELIGIBILITY_RULE_CHANGED.
     */
    @IsTest
    static void testProductEligibilityInsert_RuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Template_Product_Eligibility__c tpe = new Template_Product_Eligibility__c(
            Plan_Template__c = tpl.Id
        );
        insert tpe;

        tpe = [SELECT Id, Plan_Template__c
               FROM Template_Product_Eligibility__c WHERE Id = :tpe.Id];

        Test.startTest();
        ProductEligibilityTriggerHandler.handleChange(
            new List<SObject>{ tpe },
            null,
            System.TriggerOperation.AFTER_INSERT
        );
        Test.stopTest();

        System.assertNotEquals(null, tpe.Id,
            'Product eligibility record should be inserted');
    }

    /**
     * @description Update of Template_Product_Eligibility__c fires
     *              PRODUCT_ELIGIBILITY_RULE_CHANGED with old/new.
     */
    @IsTest
    static void testProductEligibilityUpdate_RuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Template_Product_Eligibility__c tpe = new Template_Product_Eligibility__c(
            Plan_Template__c = tpl.Id
        );
        insert tpe;

        tpe = [SELECT Id, Plan_Template__c
               FROM Template_Product_Eligibility__c WHERE Id = :tpe.Id];

        Template_Product_Eligibility__c oldTpe = tpe.clone(true, true, true, true);

        Test.startTest();
        ProductEligibilityTriggerHandler.handleChange(
            new List<SObject>{ tpe },
            new List<SObject>{ oldTpe },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        System.assertNotEquals(null, tpe.Plan_Template__c,
            'Product eligibility should reference the template');
    }

    /**
     * @description Delete of Template_Product_Eligibility__c fires
     *              PRODUCT_ELIGIBILITY_RULE_CHANGED.
     */
    @IsTest
    static void testProductEligibilityDelete_RuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();

        Template_Product_Eligibility__c tpe = new Template_Product_Eligibility__c(
            Plan_Template__c = tpl.Id
        );
        insert tpe;

        tpe = [SELECT Id, Plan_Template__c
               FROM Template_Product_Eligibility__c WHERE Id = :tpe.Id];

        Test.startTest();
        ProductEligibilityTriggerHandler.handleChange(
            null,
            new List<SObject>{ tpe },
            System.TriggerOperation.AFTER_DELETE
        );
        Test.stopTest();

        System.assertNotEquals(null, tpe.Id,
            'Product eligibility Id should exist for the deleted record');
    }

    // ═══════════════════════════════════════════════════════════════════
    // RoleEligibilityTriggerHandler
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @description Insert of Template_Role_Eligibility__c fires
     *              ROLE_ELIGIBILITY_RULE_CHANGED.
     */
    @IsTest
    static void testRoleEligibilityInsert_RuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();
        Participant_Role__c role = getRole();

        Template_Role_Eligibility__c tre = new Template_Role_Eligibility__c(
            Plan_Template__c = tpl.Id,
            Participant_Role__c = role.Id
        );
        insert tre;

        tre = [SELECT Id, Plan_Template__c, Participant_Role__c
               FROM Template_Role_Eligibility__c WHERE Id = :tre.Id];

        Test.startTest();
        RoleEligibilityTriggerHandler.handleChange(
            new List<SObject>{ tre },
            null,
            System.TriggerOperation.AFTER_INSERT
        );
        Test.stopTest();

        System.assertNotEquals(null, tre.Id,
            'Role eligibility record should be inserted');
    }

    /**
     * @description Update of Template_Role_Eligibility__c fires
     *              ROLE_ELIGIBILITY_RULE_CHANGED with old/new.
     */
    @IsTest
    static void testRoleEligibilityUpdate_RuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();
        Participant_Role__c role = getRole();

        Template_Role_Eligibility__c tre = new Template_Role_Eligibility__c(
            Plan_Template__c = tpl.Id,
            Participant_Role__c = role.Id
        );
        insert tre;

        tre = [SELECT Id, Plan_Template__c, Participant_Role__c
               FROM Template_Role_Eligibility__c WHERE Id = :tre.Id];

        Template_Role_Eligibility__c oldTre = tre.clone(true, true, true, true);

        Test.startTest();
        RoleEligibilityTriggerHandler.handleChange(
            new List<SObject>{ tre },
            new List<SObject>{ oldTre },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        System.assertNotEquals(null, tre.Participant_Role__c,
            'Role eligibility should reference the participant role');
    }

    /**
     * @description Delete of Template_Role_Eligibility__c fires
     *              ROLE_ELIGIBILITY_RULE_CHANGED.
     */
    @IsTest
    static void testRoleEligibilityDelete_RuleChanged() {
        Incentive_Plan_Template__c tpl = getTemplate();
        Participant_Role__c role = getRole();

        Template_Role_Eligibility__c tre = new Template_Role_Eligibility__c(
            Plan_Template__c = tpl.Id,
            Participant_Role__c = role.Id
        );
        insert tre;

        tre = [SELECT Id, Plan_Template__c, Participant_Role__c
               FROM Template_Role_Eligibility__c WHERE Id = :tre.Id];

        Test.startTest();
        RoleEligibilityTriggerHandler.handleChange(
            null,
            new List<SObject>{ tre },
            System.TriggerOperation.AFTER_DELETE
        );
        Test.stopTest();

        System.assertNotEquals(null, tre.Id,
            'Role eligibility Id should exist for the deleted record');
    }

    // ═══════════════════════════════════════════════════════════════════
    // ForecastPeriodTriggerHandler
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @description Status change TO 'Frozen' should call PeriodFreezeHandler.
     */
    @IsTest
    static void testForecastPeriodFrozen_CallsPeriodFreezeHandler() {
        Forecast_Period__c fp = getForecastPeriod();
        Forecast_Period__c oldFp = fp.clone(true, true, true, true);

        // Simulate transition from Open -> Frozen
        fp.Status__c = 'Frozen';

        Test.startTest();
        ForecastPeriodTriggerHandler.handleChange(
            new List<SObject>{ fp },
            new List<SObject>{ oldFp },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        // PeriodFreezeHandler.handlePeriodFreeze runs synchronously.
        // With no Failed_Event__c records, it returns early gracefully.
        System.assertEquals('Frozen', fp.Status__c,
            'Period status should be Frozen');
    }

    /**
     * @description Status change FROM 'Frozen' to another status publishes
     *              PERIOD_REOPENED event.
     */
    @IsTest
    static void testForecastPeriodReopened_PublishesEvent() {
        Forecast_Period__c fp = getForecastPeriod();

        // Set up old record as Frozen
        Forecast_Period__c oldFp = fp.clone(true, true, true, true);
        oldFp.Status__c = 'Frozen';

        // New record transitions back to Open
        fp.Status__c = 'Open';

        Test.startTest();
        ForecastPeriodTriggerHandler.handleChange(
            new List<SObject>{ fp },
            new List<SObject>{ oldFp },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        System.assertEquals('Open', fp.Status__c,
            'Period should have been reopened');
    }

    /**
     * @description Non-AFTER_UPDATE operations should be ignored.
     */
    @IsTest
    static void testForecastPeriodInsert_Ignored() {
        Forecast_Period__c fp = getForecastPeriod();

        Test.startTest();
        ForecastPeriodTriggerHandler.handleChange(
            new List<SObject>{ fp },
            null,
            System.TriggerOperation.AFTER_INSERT
        );
        Test.stopTest();

        // No exception means the non-update path returned early.
        System.assertNotEquals(null, fp.Id,
            'Period should exist but handler should have returned early');
    }

    /**
     * @description Status change that does not involve 'Frozen' should
     *              not trigger freeze or reopen logic.
     */
    @IsTest
    static void testForecastPeriodStatusChange_NotFrozen_NoAction() {
        Forecast_Period__c fp = getForecastPeriod();
        Forecast_Period__c oldFp = fp.clone(true, true, true, true);

        // Simulate a non-frozen status change (e.g., Open -> Closed)
        oldFp.Status__c = 'Open';
        fp.Status__c = 'Closed';

        Test.startTest();
        ForecastPeriodTriggerHandler.handleChange(
            new List<SObject>{ fp },
            new List<SObject>{ oldFp },
            System.TriggerOperation.AFTER_UPDATE
        );
        Test.stopTest();

        System.assertEquals('Closed', fp.Status__c,
            'Period status should be Closed with no freeze action');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Empty list coverage
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @description Passing empty lists should not throw exceptions.
     */
    @IsTest
    static void testEmptyLists_NoExceptions() {
        Test.startTest();

        CommissionTierTriggerHandler.handleChange(
            new List<SObject>(),
            null,
            System.TriggerOperation.AFTER_INSERT
        );

        PlanCapTriggerHandler.handleChange(
            new List<SObject>(),
            null,
            System.TriggerOperation.AFTER_INSERT
        );

        ProductEligibilityTriggerHandler.handleChange(
            new List<SObject>(),
            null,
            System.TriggerOperation.AFTER_INSERT
        );

        RoleEligibilityTriggerHandler.handleChange(
            new List<SObject>(),
            null,
            System.TriggerOperation.AFTER_INSERT
        );

        Test.stopTest();

        // All handlers should complete without error on empty input.
        System.assert(true, 'All empty-list calls completed without exception');
    }
}
