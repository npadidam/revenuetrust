/**
 * @description Tests for IncentiveChangeEventService.
 *              Verifies that logEvent creates Incentive_Change_Event__c records
 *              with correct field values for various change types.
 */
@IsTest
private class IncentiveChangeEventServiceTest {

    // -- Positive: logEvent creates a record with all fields populated --

    @IsTest
    static void logEvent_createsRecordWithCorrectFields() {
        Opportunity opp = RevenueTrustTestDataFactory.createClosedWonOpportunity(50000);

        Test.startTest();
        IncentiveChangeEventService.logEvent(
            'Opportunity', opp.Id, 'MANUAL_ADJUSTMENT_CREATED',
            '0', '5000', 'Manual override by admin'
        );
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Record_Type_Field__c, Record_Id__c, Change_Type__c,
                   Old_Value__c, New_Value__c, Changed_By__c, Changed_On__c,
                   Change_Context__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'MANUAL_ADJUSTMENT_CREATED'
        ];
        System.assertEquals(1, events.size(), 'Exactly one event should be created');

        Incentive_Change_Event__c evt = events[0];
        System.assertEquals('Opportunity', evt.Record_Type_Field__c,
            'Record_Type_Field__c should match');
        System.assertEquals(String.valueOf(opp.Id), evt.Record_Id__c,
            'Record_Id__c should match the opportunity Id');
        System.assertEquals('MANUAL_ADJUSTMENT_CREATED', evt.Change_Type__c,
            'Change_Type__c should match');
        System.assertEquals('0', evt.Old_Value__c,
            'Old_Value__c should match');
        System.assertEquals('5000', evt.New_Value__c,
            'New_Value__c should match');
        System.assertEquals(UserInfo.getUserId(), evt.Changed_By__c,
            'Changed_By__c should be the running user');
        System.assertNotEquals(null, evt.Changed_On__c,
            'Changed_On__c should be populated');
        System.assertEquals('Manual override by admin', evt.Change_Context__c,
            'Change_Context__c should match');
    }

    // -- Positive: logEvent with COMMISSION_HOLD_APPLIED --

    @IsTest
    static void logEvent_commissionHoldApplied() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(25000, 'Prospecting');

        Test.startTest();
        IncentiveChangeEventService.logEvent(
            'Calculation', opp.Id, 'COMMISSION_HOLD_APPLIED',
            'Not_Held', 'Held', 'Collection pending 90 days'
        );
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Change_Type__c, Old_Value__c, New_Value__c, Change_Context__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'COMMISSION_HOLD_APPLIED'
        ];
        System.assertEquals(1, events.size(), 'Should create hold event');
        System.assertEquals('Not_Held', events[0].Old_Value__c, 'Old value should be Not_Held');
        System.assertEquals('Held', events[0].New_Value__c, 'New value should be Held');
    }

    // -- Positive: logEvent with COMMISSION_HOLD_RELEASED --

    @IsTest
    static void logEvent_commissionHoldReleased() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(30000, 'Closed Won');

        Test.startTest();
        IncentiveChangeEventService.logEvent(
            'Calculation', opp.Id, 'COMMISSION_HOLD_RELEASED',
            'Held', 'Released', null
        );
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Change_Type__c, Old_Value__c, New_Value__c, Change_Context__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'COMMISSION_HOLD_RELEASED'
        ];
        System.assertEquals(1, events.size(), 'Should create release event');
        System.assertEquals(null, events[0].Change_Context__c,
            'Context should be null for release');
    }

    // -- Positive: logEvent with null old/new values --

    @IsTest
    static void logEvent_nullOldAndNewValues() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(10000, 'Prospecting');

        Test.startTest();
        IncentiveChangeEventService.logEvent(
            'Comp_Plan', opp.Id, 'Plan_Accepted',
            null, null, 'Initial activation'
        );
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Old_Value__c, New_Value__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'Plan_Accepted'
        ];
        System.assertEquals(1, events.size(), 'Should create event with null values');
        System.assertEquals(null, events[0].Old_Value__c, 'Old value should be null');
        System.assertEquals(null, events[0].New_Value__c, 'New value should be null');
    }

    // -- Positive: logEvent with various record types --

    @IsTest
    static void logEvent_variousRecordTypes() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(75000, 'Negotiation');

        Test.startTest();
        IncentiveChangeEventService.logEvent(
            'CalculationInvalidation', opp.Id, 'INVALIDATION_IMPACT_RESOLVED',
            'RATE_TABLE_CHANGED', null, 'Projected=3 Validated=1'
        );
        Test.stopTest();

        List<Incentive_Change_Event__c> events = [
            SELECT Record_Type_Field__c, Change_Type__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'INVALIDATION_IMPACT_RESOLVED'
        ];
        System.assertEquals(1, events.size(), 'Should create invalidation event');
        System.assertEquals('CalculationInvalidation', events[0].Record_Type_Field__c,
            'Record type should match');
    }

    // -- Bulk: multiple events in a single transaction --

    @IsTest
    static void logEvent_bulkCreation() {
        Opportunity opp = RevenueTrustTestDataFactory.createOpportunity(60000, 'Prospecting');

        Test.startTest();
        for (Integer i = 0; i < 50; i++) {
            IncentiveChangeEventService.logEvent(
                'Calculation', opp.Id, 'Calculation_Processed',
                'old_' + i, 'new_' + i, 'Bulk event ' + i
            );
        }
        Test.stopTest();

        Integer eventCount = [
            SELECT COUNT()
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'Calculation_Processed'
        ];
        System.assertEquals(50, eventCount,
            'Should create all 50 events in bulk');
    }
}
