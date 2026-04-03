/**
 * @description Tests for CommissionHoldService.
 *              Verifies hold application, release, audit events, and bulk scenarios.
 */
@IsTest
private class CommissionHoldServiceTest {

    @TestSetup
    static void setupData() {
        Participant_Role__c role = RevenueTrustTestDataFactory.createParticipantRole();
        Incentive_Plan_Template__c tpl = RevenueTrustTestDataFactory.createPlanTemplate('Hold Test Plan');
        Comp_Plan__c plan = RevenueTrustTestDataFactory.createCompPlan(
            UserInfo.getUserId(), tpl.Id, role.Id
        );
        Opportunity opp = RevenueTrustTestDataFactory.createClosedWonOpportunity(100000);

        // Create several calculations for bulk tests
        RevenueTrustTestDataFactory.createCompCalculations(plan.Id, opp.Id, 'Projected', 5);
    }

    // -- Helper --

    private static List<Comp_Calculation__c> queryCalcs() {
        return [
            SELECT Id, Hold_Status__c, Hold_Reason__c
            FROM Comp_Calculation__c
            ORDER BY CreatedDate
        ];
    }

    // -- Positive: applyHold sets status and reason --

    @IsTest
    static void applyHold_setsHeldStatusAndReason() {
        List<Comp_Calculation__c> calcs = queryCalcs();
        List<Id> calcIds = new List<Id>();
        for (Comp_Calculation__c c : calcs) {
            calcIds.add(c.Id);
        }

        Test.startTest();
        CommissionHoldService.applyHold(calcIds, 'Collection_Pending');
        Test.stopTest();

        List<Comp_Calculation__c> updated = queryCalcs();
        for (Comp_Calculation__c c : updated) {
            System.assertEquals('Held', c.Hold_Status__c,
                'Hold_Status__c should be Held after applyHold');
            System.assertEquals('Collection_Pending', c.Hold_Reason__c,
                'Hold_Reason__c should match the provided reason');
        }
    }

    // -- Positive: applyHold creates audit events --

    @IsTest
    static void applyHold_createsIncentiveChangeEvents() {
        List<Comp_Calculation__c> calcs = queryCalcs();
        List<Id> calcIds = new List<Id>();
        for (Comp_Calculation__c c : calcs) {
            calcIds.add(c.Id);
        }

        Test.startTest();
        CommissionHoldService.applyHold(calcIds, 'Approval_Pending');
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Id, Change_Type__c, Old_Value__c, New_Value__c, Change_Context__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'COMMISSION_HOLD_APPLIED'
        ];
        System.assertEquals(calcIds.size(), events.size(),
            'Should create one audit event per calculation');
        for (Incentive_Change_Event__c evt : events) {
            System.assertEquals('Not_Held', evt.Old_Value__c,
                'Old value should be Not_Held');
            System.assertEquals('Held', evt.New_Value__c,
                'New value should be Held');
            System.assertEquals('Approval_Pending', evt.Change_Context__c,
                'Context should match the hold reason');
        }
    }

    // -- Positive: releaseHold sets status to Released --

    @IsTest
    static void releaseHold_setsReleasedStatus() {
        List<Comp_Calculation__c> calcs = queryCalcs();
        List<Id> calcIds = new List<Id>();
        for (Comp_Calculation__c c : calcs) {
            calcIds.add(c.Id);
        }

        // First apply hold, then release
        CommissionHoldService.applyHold(calcIds, 'Time_Hold');

        Test.startTest();
        CommissionHoldService.releaseHold(calcIds);
        Test.stopTest();

        List<Comp_Calculation__c> updated = queryCalcs();
        for (Comp_Calculation__c c : updated) {
            System.assertEquals('Released', c.Hold_Status__c,
                'Hold_Status__c should be Released after releaseHold');
        }
    }

    // -- Positive: releaseHold creates audit events --

    @IsTest
    static void releaseHold_createsIncentiveChangeEvents() {
        List<Comp_Calculation__c> calcs = queryCalcs();
        List<Id> calcIds = new List<Id>();
        for (Comp_Calculation__c c : calcs) {
            calcIds.add(c.Id);
        }

        CommissionHoldService.applyHold(calcIds, 'Milestone_Pending');

        Test.startTest();
        CommissionHoldService.releaseHold(calcIds);
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Id, Change_Type__c, Old_Value__c, New_Value__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'COMMISSION_HOLD_RELEASED'
        ];
        System.assertEquals(calcIds.size(), events.size(),
            'Should create one release audit event per calculation');
        for (Incentive_Change_Event__c evt : events) {
            System.assertEquals('Held', evt.Old_Value__c,
                'Old value should be Held');
            System.assertEquals('Released', evt.New_Value__c,
                'New value should be Released');
        }
    }

    // -- Negative: applyHold with empty list does nothing --

    @IsTest
    static void applyHold_emptyList_noError() {
        Test.startTest();
        CommissionHoldService.applyHold(new List<Id>(), 'None');
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Id FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'COMMISSION_HOLD_APPLIED'
        ];
        System.assertEquals(0, events.size(),
            'No events should be created for empty list');
    }

    // -- Negative: releaseHold with empty list does nothing --

    @IsTest
    static void releaseHold_emptyList_noError() {
        Test.startTest();
        CommissionHoldService.releaseHold(new List<Id>());
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Id FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'COMMISSION_HOLD_RELEASED'
        ];
        System.assertEquals(0, events.size(),
            'No events should be created for empty list');
    }

    // -- Bulk: hold and release 200 records --

    @IsTest
    static void applyAndReleaseHold_bulkRecords() {
        // Create additional records for bulk
        Comp_Plan__c plan = [SELECT Id FROM Comp_Plan__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Comp_Calculation__c> bulkCalcs = new List<Comp_Calculation__c>();
        for (Integer i = 0; i < 45; i++) {
            bulkCalcs.add(new Comp_Calculation__c(
                Comp_Plan__c = plan.Id,
                Opportunity__c = opp.Id,
                Calculation_Status__c = 'Projected',
                Eligible_Commission__c = 1000,
                Contract_Date2__c = Date.today(),
                Hold_Status__c = 'Not_Held'
            ));
        }
        insert bulkCalcs;

        List<Comp_Calculation__c> allCalcs = [SELECT Id FROM Comp_Calculation__c];
        List<Id> allIds = new List<Id>();
        for (Comp_Calculation__c c : allCalcs) {
            allIds.add(c.Id);
        }
        System.assert(allIds.size() >= 50,
            'Should have at least 50 records for bulk test');

        Test.startTest();
        CommissionHoldService.applyHold(allIds, 'Custom_Hold');
        CommissionHoldService.releaseHold(allIds);
        Test.stopTest();

        List<Comp_Calculation__c> finalCalcs = [
            SELECT Id, Hold_Status__c FROM Comp_Calculation__c
        ];
        for (Comp_Calculation__c c : finalCalcs) {
            System.assertEquals('Released', c.Hold_Status__c,
                'All records should be Released after bulk hold + release');
        }
    }
}
