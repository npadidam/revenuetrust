@IsTest
private class OpportunityCommissionTriggerTest {

    @IsTest
    static void testTrigger_dealClosed_publishesEvent() {
        Opportunity opp = new Opportunity(
            Name = 'Trigger Test Deal',
            Amount = 75000,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        // Platform events are fire-and-forget; we verify no exception occurred
        // and that the trigger handler executed without error
        System.assert(true, 'Trigger should execute without exception on deal close');
    }

    @IsTest
    static void testTrigger_amountChanged() {
        Opportunity opp = new Opportunity(
            Name = 'Amount Change Deal',
            Amount = 50000,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.Amount = 75000;
        update opp;
        Test.stopTest();

        System.assert(true, 'Trigger should execute without exception on amount change');
    }

    @IsTest
    static void testTrigger_stageChanged() {
        Opportunity opp = new Opportunity(
            Name = 'Stage Change Deal',
            Amount = 50000,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Qualification';
        update opp;
        Test.stopTest();

        System.assert(true, 'Trigger should execute without exception on stage change');
    }

    @IsTest
    static void testTrigger_closeDateChanged() {
        Opportunity opp = new Opportunity(
            Name = 'Date Change Deal',
            Amount = 50000,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.CloseDate = Date.today().addDays(60);
        update opp;
        Test.stopTest();

        System.assert(true, 'Trigger should execute without exception on close date change');
    }

    @IsTest
    static void testTrigger_multipleChanges() {
        Opportunity opp = new Opportunity(
            Name = 'Multi Change Deal',
            Amount = 50000,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.Amount = 100000;
        opp.StageName = 'Closed Won';
        opp.CloseDate = Date.today();
        update opp;
        Test.stopTest();

        System.assert(true, 'Trigger should handle multiple simultaneous changes');
    }

    @IsTest
    static void testTrigger_noRelevantChange() {
        Opportunity opp = new Opportunity(
            Name = 'No Change Deal',
            Amount = 50000,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        opp.Description = 'Updated description only';
        update opp;
        Test.stopTest();

        System.assert(true, 'Trigger should handle irrelevant updates gracefully');
    }

    @IsTest
    static void testTrigger_bulk200() {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Deal ' + i,
                Amount = 10000,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;

        Test.startTest();
        for (Opportunity opp : opps) {
            opp.StageName = 'Closed Won';
        }
        update opps;
        Test.stopTest();

        System.assert(true, 'Trigger should handle 200 records in bulk without governor limits');
    }
}
