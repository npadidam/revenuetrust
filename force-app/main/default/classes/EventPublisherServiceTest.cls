@IsTest
private class EventPublisherServiceTest {

    @IsTest
    static void testPublishCommissionEvent_valid() {
        Commission_Event__e evt = new Commission_Event__e(
            Opportunity_Id__c = '006000000000001',
            Event_Type__c = 'DEAL_CLOSED',
            User_Id__c = UserInfo.getUserId(),
            Previous_Value__c = 'Negotiation',
            New_Value__c = 'Closed Won'
        );

        Test.startTest();
        Database.SaveResult sr = EventPublisherService.publishCommissionEvent(evt);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(), 'Commission event should publish successfully');
    }

    @IsTest
    static void testPublishCommissionEvents_bulk() {
        List<Commission_Event__e> events = new List<Commission_Event__e>();
        for (Integer i = 0; i < 200; i++) {
            events.add(new Commission_Event__e(
                Opportunity_Id__c = '006000000000001',
                Event_Type__c = 'AMOUNT_CHANGED',
                User_Id__c = UserInfo.getUserId(),
                Previous_Value__c = '100000',
                New_Value__c = '150000'
            ));
        }

        Test.startTest();
        List<Database.SaveResult> results = EventPublisherService.publishCommissionEvents(events);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Should return 200 save results');
        for (Database.SaveResult sr : results) {
            System.assertEquals(true, sr.isSuccess(), 'Each event should publish successfully');
        }
    }

    @IsTest
    static void testPublishCommissionEvent_missingOpportunityId() {
        Commission_Event__e evt = new Commission_Event__e(
            Event_Type__c = 'DEAL_CLOSED'
        );

        try {
            EventPublisherService.publishCommissionEvent(evt);
            System.assert(false, 'Should have thrown EventPublisherException');
        } catch (EventPublisherService.EventPublisherException e) {
            System.assert(e.getMessage().contains('Opportunity_Id__c'),
                'Error should mention missing field');
        }
    }

    @IsTest
    static void testPublishCommissionEvent_missingEventType() {
        Commission_Event__e evt = new Commission_Event__e(
            Opportunity_Id__c = '006000000000001'
        );

        try {
            EventPublisherService.publishCommissionEvent(evt);
            System.assert(false, 'Should have thrown EventPublisherException');
        } catch (EventPublisherService.EventPublisherException e) {
            System.assert(e.getMessage().contains('Event_Type__c'),
                'Error should mention missing field');
        }
    }

    @IsTest
    static void testPublishCommissionEvents_emptyList() {
        List<Database.SaveResult> results = EventPublisherService.publishCommissionEvents(
            new List<Commission_Event__e>()
        );
        System.assertEquals(0, results.size(), 'Empty list should return empty results');
    }

    @IsTest
    static void testPublishCommissionEvents_null() {
        List<Database.SaveResult> results = EventPublisherService.publishCommissionEvents(null);
        System.assertEquals(0, results.size(), 'Null should return empty results');
    }

    @IsTest
    static void testPublishGovernanceEvent_valid() {
        Governance_Eval_Event__e evt = new Governance_Eval_Event__e(
            Participant_Id__c = UserInfo.getUserId(),
            Action_Type__c = 'REQUIRE_JUSTIFICATION',
            Rule_Id__c = 'CG-1',
            Override_Id__c = 'a0B000000000001',
            Compensation_Context__c = '{"attainment":95}'
        );

        Test.startTest();
        Database.SaveResult sr = EventPublisherService.publishGovernanceEvent(evt);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(), 'Governance event should publish successfully');
    }

    @IsTest
    static void testPublishGovernanceEvent_missingParticipant() {
        Governance_Eval_Event__e evt = new Governance_Eval_Event__e(
            Action_Type__c = 'ESCALATE'
        );

        try {
            EventPublisherService.publishGovernanceEvent(evt);
            System.assert(false, 'Should have thrown EventPublisherException');
        } catch (EventPublisherService.EventPublisherException e) {
            System.assert(e.getMessage().contains('Participant_Id__c'),
                'Error should mention missing field');
        }
    }

    @IsTest
    static void testPublishGovernanceEvent_missingActionType() {
        Governance_Eval_Event__e evt = new Governance_Eval_Event__e(
            Participant_Id__c = UserInfo.getUserId()
        );

        try {
            EventPublisherService.publishGovernanceEvent(evt);
            System.assert(false, 'Should have thrown EventPublisherException');
        } catch (EventPublisherService.EventPublisherException e) {
            System.assert(e.getMessage().contains('Action_Type__c'),
                'Error should mention missing field');
        }
    }

    @IsTest
    static void testPublishGovernanceEvents_emptyAndNull() {
        System.assertEquals(0,
            EventPublisherService.publishGovernanceEvents(new List<Governance_Eval_Event__e>()).size());
        System.assertEquals(0,
            EventPublisherService.publishGovernanceEvents(null).size());
    }

    @IsTest
    static void testPublishSignalEvent_valid() {
        Signal_Event__e evt = new Signal_Event__e(
            Opportunity_Id__c = '006000000000001',
            Signal_Source__c = 'CRM',
            Signal_Data__c = '{"health":85}'
        );

        Test.startTest();
        Database.SaveResult sr = EventPublisherService.publishSignalEvent(evt);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(), 'Signal event should publish successfully');
    }

    @IsTest
    static void testPublishSignalEvent_missingOpportunityId() {
        Signal_Event__e evt = new Signal_Event__e(
            Signal_Source__c = 'GONG'
        );

        try {
            EventPublisherService.publishSignalEvent(evt);
            System.assert(false, 'Should have thrown EventPublisherException');
        } catch (EventPublisherService.EventPublisherException e) {
            System.assert(e.getMessage().contains('Opportunity_Id__c'),
                'Error should mention missing field');
        }
    }

    @IsTest
    static void testPublishSignalEvent_missingSource() {
        Signal_Event__e evt = new Signal_Event__e(
            Opportunity_Id__c = '006000000000001'
        );

        try {
            EventPublisherService.publishSignalEvent(evt);
            System.assert(false, 'Should have thrown EventPublisherException');
        } catch (EventPublisherService.EventPublisherException e) {
            System.assert(e.getMessage().contains('Signal_Source__c'),
                'Error should mention missing field');
        }
    }

    @IsTest
    static void testPublishSignalEvents_emptyAndNull() {
        System.assertEquals(0,
            EventPublisherService.publishSignalEvents(new List<Signal_Event__e>()).size());
        System.assertEquals(0,
            EventPublisherService.publishSignalEvents(null).size());
    }
}
