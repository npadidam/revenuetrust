@IsTest
private class IncentiveImpactCalculatorTest {

    @TestSetup
    static void setupTestData() {
        Participant_Role__c role = RevenueTrustTestDataFactory.createParticipantRole();
        Incentive_Plan_Template__c tpl = RevenueTrustTestDataFactory.createPlanTemplate();
        List<Commission_Tier__c> tiers = RevenueTrustTestDataFactory.createStandardTiers(tpl.Id);
        Comp_Plan__c plan = RevenueTrustTestDataFactory.createCompPlan(
            UserInfo.getUserId(), tpl.Id, role.Id
        );
        Quota__c quota = RevenueTrustTestDataFactory.createQuota(
            plan.Id, UserInfo.getUserId(), 500000
        );
    }

    @IsTest
    static void testGetContext_activeParticipant() {
        Test.startTest();
        IncentiveImpactCalculator.IncentiveContext ctx =
            IncentiveImpactCalculator.getContext(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, ctx, 'Context should not be null');
        System.assertEquals(UserInfo.getUserId(), ctx.participantId);
        System.assertEquals(200000, ctx.ote, 'OTE should be 200000');
        System.assertEquals(500000, ctx.quotaTarget, 'Quota target should be 500000');
        System.assertEquals(0, ctx.attainmentPct, 'Initial attainment should be 0%');
        System.assertEquals(3, ctx.tiers.size(), 'Should have 3 tiers');
    }

    @IsTest
    static void testGetContext_noActivePlan() {
        // Deactivate the plan
        Comp_Plan__c plan = [SELECT Id FROM Comp_Plan__c LIMIT 1];
        plan.Status__c = 'Draft';
        update plan;

        Test.startTest();
        IncentiveImpactCalculator.IncentiveContext ctx =
            IncentiveImpactCalculator.getContext(UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(null, ctx, 'Context should be null for inactive plan');
    }

    @IsTest
    static void testCalculateImpact_noTierCrossing() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(50000, 'Prospecting');

        Test.startTest();
        IncentiveImpactCalculator.ImpactResult impact =
            IncentiveImpactCalculator.calculateImpact(opp.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, impact, 'Impact should not be null');
        System.assertEquals(0, impact.currentAttainmentPct, 'Current attainment starts at 0');
        System.assertEquals(10, impact.proposedAttainmentPct, '50k/500k = 10%');
        System.assertEquals(false, impact.tierCrossing, 'Should not cross tier');
        System.assertEquals('Base', impact.currentTier.name);
        System.assertEquals('Base', impact.projectedTier.name);
        System.assertEquals(4000, impact.payoutOnDeal, '50000 * 8% = 4000');
        System.assertEquals(0, impact.retroactiveDelta, 'No retroactive delta');
        System.assertEquals('No tier change', impact.tierImpactMessage);
    }

    @IsTest
    static void testCalculateImpact_tierCrossing_nonRetroactive() {
        // Set attainment to 95% (475k of 500k)
        Quota__c quota = [SELECT Id FROM Quota__c LIMIT 1];
        quota.Achieved_Amount__c = 475000;
        update quota;

        // Deal of 50k pushes to 105%
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(50000, 'Negotiation');

        Test.startTest();
        IncentiveImpactCalculator.ImpactResult impact =
            IncentiveImpactCalculator.calculateImpact(opp.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(95, impact.currentAttainmentPct);
        System.assertEquals(105, impact.proposedAttainmentPct);
        System.assertEquals(true, impact.tierCrossing, 'Should cross from Base to Accelerator');
        System.assertEquals('Base', impact.currentTier.name);
        System.assertEquals('Accelerator', impact.projectedTier.name);
        // Non-retroactive: 50000 * 12% = 6000
        System.assertEquals(6000, impact.payoutOnDeal);
        System.assertEquals(0, impact.retroactiveDelta, 'Accelerator is not retroactive');
        System.assert(impact.tierImpactMessage.contains('Accelerator'),
            'Message should mention Accelerator');
    }

    @IsTest
    static void testCalculateImpact_tierCrossing_retroactive() {
        // Set attainment to 145% (725k of 500k)
        Quota__c quota = [SELECT Id FROM Quota__c LIMIT 1];
        quota.Achieved_Amount__c = 725000;
        update quota;

        // Deal of 50k pushes to 155% → Super Accelerator (retroactive)
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(50000, 'Negotiation');

        Test.startTest();
        IncentiveImpactCalculator.ImpactResult impact =
            IncentiveImpactCalculator.calculateImpact(opp.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(145, impact.currentAttainmentPct);
        System.assertEquals(155, impact.proposedAttainmentPct);
        System.assertEquals(true, impact.tierCrossing);
        System.assertEquals('Accelerator', impact.currentTier.name);
        System.assertEquals('Super Accelerator', impact.projectedTier.name);
        // 50000 * 15% = 7500
        System.assertEquals(7500, impact.payoutOnDeal);
        // Retroactive delta: 725000 * (15 - 12)/100 = 725000 * 0.03 = 21750
        System.assertEquals(21750, impact.retroactiveDelta,
            'Retroactive uplift on prior attainment');
        System.assert(impact.tierImpactMessage.contains('retroactive'),
            'Message should mention retroactive');
    }

    @IsTest
    static void testCalculateImpact_thresholdProximities() {
        // At 0% attainment, should see proximities to Accelerator and Super tiers
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(10000, 'Prospecting');

        Test.startTest();
        IncentiveImpactCalculator.ImpactResult impact =
            IncentiveImpactCalculator.calculateImpact(opp.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(2, impact.proximities.size(),
            'Should see 2 thresholds above current (Accelerator, Super)');
        System.assertEquals('Accelerator', impact.proximities[0].tierName);
        System.assertEquals(100, impact.proximities[0].distancePct, 'Distance to Accelerator');
        System.assertEquals(500000, impact.proximities[0].distanceAmount, 'Amount to Accelerator');
    }

    @IsTest
    static void testCalculateImpact_zeroAmountDeal() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(0, 'Prospecting');

        Test.startTest();
        IncentiveImpactCalculator.ImpactResult impact =
            IncentiveImpactCalculator.calculateImpact(opp.Id, UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, impact);
        System.assertEquals(0, impact.payoutOnDeal, 'Zero deal = zero payout');
        System.assertEquals(false, impact.tierCrossing);
    }
}
