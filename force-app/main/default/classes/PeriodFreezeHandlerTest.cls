/**
 * @description Tests for PeriodFreezeHandler.
 *              Verifies reclassification of unresolved Failed_Event__c alerts
 *              when a Forecast_Period__c is frozen. Tests the immutability
 *              principle (original alert is superseded, new one is created).
 */
@IsTest
private class PeriodFreezeHandlerTest {

    @TestSetup
    static void setupData() {
        Participant_Role__c role = RevenueTrustTestDataFactory.createParticipantRole();
        Incentive_Plan_Template__c tpl = RevenueTrustTestDataFactory.createPlanTemplate(
            'Freeze Test Plan'
        );
        Comp_Plan__c plan = RevenueTrustTestDataFactory.createCompPlan(
            UserInfo.getUserId(), tpl.Id, role.Id
        );
        Opportunity opp = RevenueTrustTestDataFactory.createClosedWonOpportunity(80000);

        // Create a Forecast Configuration and a period that will be frozen
        Forecast_Configuration__c fc = RevenueTrustTestDataFactory.createForecastConfiguration();
        Forecast_Period__c fp = RevenueTrustTestDataFactory.createForecastPeriod(fc.Id, 'Frozen');

        // Create a Comp_Calculation__c with Contract_Date2__c within the period
        RevenueTrustTestDataFactory.createCompCalculation(plan.Id, opp.Id, 'Validated');
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static Forecast_Period__c getFrozenPeriod() {
        return [SELECT Id, Start_Date__c, End_Date__c, Period_Label__c FROM Forecast_Period__c LIMIT 1];
    }

    private static Opportunity getOpportunity() {
        return [SELECT Id FROM Opportunity LIMIT 1];
    }

    // ── Positive: reclassifies CLAWBACK_EVALUATION_REQUIRED ─────────────

    @IsTest
    static void handlePeriodFreeze_reclassifiesClawbackAlert() {
        Forecast_Period__c fp = getFrozenPeriod();
        Opportunity opp = getOpportunity();

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id,
            'detail' => 'Test clawback'
        });
        RevenueTrustTestDataFactory.createFailedEvent(
            'CLAWBACK_EVALUATION_REQUIRED', payload, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        // Original alert should be superseded
        List<Failed_Event__c> superseded = [
            SELECT Status__c FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_EVALUATION_REQUIRED'
        ];
        System.assertEquals(1, superseded.size(), 'Original alert should exist');
        System.assertEquals('Superseded', superseded[0].Status__c,
            'Original alert status should be Superseded');

        // New reclassified alert should exist
        List<Failed_Event__c> reclassified = [
            SELECT Event_Type__c, Status__c, Payload__c, Error_Message__c
            FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_FROZEN_PERIOD'
        ];
        System.assertEquals(1, reclassified.size(),
            'Should create one reclassified frozen-period alert');
        System.assertEquals('Failed', reclassified[0].Status__c,
            'Reclassified alert should have Failed status');
        System.assert(reclassified[0].Error_Message__c.contains('Reclassified from'),
            'Error message should indicate reclassification');

        // Verify payload contains supersession metadata
        Map<String, Object> newPayload =
            (Map<String, Object>) JSON.deserializeUntyped(reclassified[0].Payload__c);
        System.assertNotEquals(null, newPayload.get('supersedes_event_id'),
            'Payload should reference the superseded event');
        System.assertEquals('CLAWBACK_EVALUATION_REQUIRED', newPayload.get('reclassified_from'),
            'Payload should record the original event type');
    }

    // ── Positive: reclassifies RETRO_RECALCULATION_REVIEW_REQUIRED ──────

    @IsTest
    static void handlePeriodFreeze_reclassifiesRetroReviewAlert() {
        Forecast_Period__c fp = getFrozenPeriod();
        Opportunity opp = getOpportunity();

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id,
            'templateName' => 'Freeze Test Plan'
        });
        RevenueTrustTestDataFactory.createFailedEvent(
            'RETRO_RECALCULATION_REVIEW_REQUIRED', payload, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        List<Failed_Event__c> reclassified = [
            SELECT Event_Type__c
            FROM Failed_Event__c
            WHERE Event_Type__c = 'RULE_CHANGE_FROZEN_PERIOD_IMPACT'
        ];
        System.assertEquals(1, reclassified.size(),
            'RETRO_RECALCULATION should be reclassified to RULE_CHANGE_FROZEN_PERIOD_IMPACT');
    }

    // ── Positive: reclassifies DEAL_REOPENED_REVIEW_REQUIRED ────────────

    @IsTest
    static void handlePeriodFreeze_reclassifiesDealReopenedAlert() {
        Forecast_Period__c fp = getFrozenPeriod();
        Opportunity opp = getOpportunity();

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id
        });
        RevenueTrustTestDataFactory.createFailedEvent(
            'DEAL_REOPENED_REVIEW_REQUIRED', payload, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        List<Failed_Event__c> reclassified = [
            SELECT Event_Type__c
            FROM Failed_Event__c
            WHERE Event_Type__c = 'DEAL_REOPENED_FROZEN_PERIOD'
        ];
        System.assertEquals(1, reclassified.size(),
            'DEAL_REOPENED should be reclassified to DEAL_REOPENED_FROZEN_PERIOD');
    }

    // ── Positive: multiple alerts reclassified in one call ──────────────

    @IsTest
    static void handlePeriodFreeze_multipleAlertsReclassified() {
        Forecast_Period__c fp = getFrozenPeriod();
        Opportunity opp = getOpportunity();

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id
        });

        RevenueTrustTestDataFactory.createFailedEvent(
            'CLAWBACK_EVALUATION_REQUIRED', payload, 'Failed'
        );
        RevenueTrustTestDataFactory.createFailedEvent(
            'CREDIT_REALLOCATION_REQUIRED', payload, 'Failed'
        );
        RevenueTrustTestDataFactory.createFailedEvent(
            'RECLOSE_DELTA_REPROCESSING', payload, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        Integer supersededCount = [
            SELECT COUNT() FROM Failed_Event__c WHERE Status__c = 'Superseded'
        ];
        System.assertEquals(3, supersededCount,
            'All 3 original alerts should be superseded');

        Integer reclassifiedCount = [
            SELECT COUNT() FROM Failed_Event__c
            WHERE Event_Type__c IN (
                'CLAWBACK_FROZEN_PERIOD',
                'CREDIT_REALLOCATION_FROZEN_PERIOD',
                'RECLOSE_FROZEN_PERIOD_ADJUSTMENT'
            )
            AND Status__c = 'Failed'
        ];
        System.assertEquals(3, reclassifiedCount,
            'All 3 alerts should be reclassified to frozen variants');

        // Verify audit log event was created
        List<Incentive_Change_Event__c> events = [
            SELECT Change_Type__c
            FROM Incentive_Change_Event__c
            WHERE Change_Type__c = 'PERIOD_FREEZE_RECLASSIFICATION'
        ];
        System.assertEquals(1, events.size(),
            'Should create one audit event for the reclassification batch');
    }

    // ── Negative: no unresolved alerts — no-op ──────────────────────────

    @IsTest
    static void handlePeriodFreeze_noUnresolvedAlerts_noOp() {
        Forecast_Period__c fp = getFrozenPeriod();

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        Integer alertCount = [SELECT COUNT() FROM Failed_Event__c];
        System.assertEquals(0, alertCount,
            'No alerts should be created when there are no unresolved alerts');
    }

    // ── Negative: invalid forecast period Id — early return ─────────────

    @IsTest
    static void handlePeriodFreeze_invalidPeriodId_earlyReturn() {
        // Use a fabricated Id that does not match any real record
        Id fakePeriodId = Forecast_Period__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fakePeriodId);
        Test.stopTest();

        // Should not throw — just returns early
        Integer alertCount = [SELECT COUNT() FROM Failed_Event__c];
        System.assertEquals(0, alertCount,
            'No alerts should be created for invalid period Id');
    }

    // ── Negative: alert type not in reclassification map — skipped ──────

    @IsTest
    static void handlePeriodFreeze_nonReclassifiableAlertType_skipped() {
        Forecast_Period__c fp = getFrozenPeriod();
        Opportunity opp = getOpportunity();

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id
        });
        // CASCADE_BOUNDARY_REACHED is not in the reclassification map
        RevenueTrustTestDataFactory.createFailedEvent(
            'CASCADE_BOUNDARY_REACHED', payload, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        // Original should remain unchanged
        List<Failed_Event__c> originals = [
            SELECT Status__c FROM Failed_Event__c
            WHERE Event_Type__c = 'CASCADE_BOUNDARY_REACHED'
        ];
        System.assertEquals(1, originals.size(), 'Original alert should still exist');
        System.assertEquals('Failed', originals[0].Status__c,
            'Non-reclassifiable alert should remain in Failed status');
    }

    // ── Negative: alert with no opportunityId in payload — skipped ──────

    @IsTest
    static void handlePeriodFreeze_noOpportunityIdInPayload_skipped() {
        Forecast_Period__c fp = getFrozenPeriod();

        String payloadNoOppId = JSON.serialize(new Map<String, Object>{
            'detail' => 'Missing opportunity reference'
        });
        RevenueTrustTestDataFactory.createFailedEvent(
            'CLAWBACK_EVALUATION_REQUIRED', payloadNoOppId, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        // Alert should not be reclassified because opportunityId is missing
        List<Failed_Event__c> originals = [
            SELECT Status__c FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_EVALUATION_REQUIRED'
        ];
        System.assertEquals(1, originals.size(), 'Original alert should still exist');
        System.assertEquals('Failed', originals[0].Status__c,
            'Alert with no opportunityId should remain in Failed status');
    }

    // ── Negative: alert with invalid JSON payload — skipped ─────────────

    @IsTest
    static void handlePeriodFreeze_invalidJsonPayload_skipped() {
        Forecast_Period__c fp = getFrozenPeriod();

        RevenueTrustTestDataFactory.createFailedEvent(
            'CLAWBACK_EVALUATION_REQUIRED', 'not valid json {{', 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        // Should not throw — just skips this alert
        List<Failed_Event__c> originals = [
            SELECT Status__c FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_EVALUATION_REQUIRED'
        ];
        System.assertEquals('Failed', originals[0].Status__c,
            'Alert with invalid payload should remain in Failed status');
    }

    // ── Negative: alert with blank payload — skipped ────────────────────

    @IsTest
    static void handlePeriodFreeze_blankPayload_skipped() {
        Forecast_Period__c fp = getFrozenPeriod();

        RevenueTrustTestDataFactory.createFailedEvent(
            'CLAWBACK_EVALUATION_REQUIRED', '', 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        List<Failed_Event__c> originals = [
            SELECT Status__c FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_EVALUATION_REQUIRED'
        ];
        System.assertEquals('Failed', originals[0].Status__c,
            'Alert with blank payload should remain in Failed status');
    }

    // ── Positive: opp with no calc in frozen period — alert not reclassified

    @IsTest
    static void handlePeriodFreeze_oppWithNoCalcInPeriod_notReclassified() {
        Forecast_Period__c fp = getFrozenPeriod();

        // Create a separate Opportunity with no Comp_Calculation__c in the period
        Opportunity opp2 = RevenueTrustTestDataFactory.createOpportunity(20000, 'Prospecting');

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp2.Id
        });
        RevenueTrustTestDataFactory.createFailedEvent(
            'CLAWBACK_EVALUATION_REQUIRED', payload, 'Failed'
        );

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        // Alert should NOT be reclassified because opp2 has no calcs in frozen period
        List<Failed_Event__c> originals = [
            SELECT Status__c FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_EVALUATION_REQUIRED'
        ];
        System.assertEquals('Failed', originals[0].Status__c,
            'Alert for opp without calcs in frozen period should remain Failed');

        Integer frozenAlerts = [
            SELECT COUNT() FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_FROZEN_PERIOD'
        ];
        System.assertEquals(0, frozenAlerts,
            'No frozen variant should be created');
    }

    // ── Bulk: many alerts processed at once ─────────────────────────────

    @IsTest
    static void handlePeriodFreeze_bulkAlerts() {
        Forecast_Period__c fp = getFrozenPeriod();
        Opportunity opp = getOpportunity();

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id
        });

        List<Failed_Event__c> bulkAlerts = new List<Failed_Event__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkAlerts.add(new Failed_Event__c(
                Event_Type__c = 'CLAWBACK_EVALUATION_REQUIRED',
                Payload__c = payload,
                Error_Message__c = 'Bulk alert ' + i,
                Retry_Count__c = 0,
                Status__c = 'Failed',
                Original_Event_Time__c = Datetime.now()
            ));
        }
        insert bulkAlerts;

        Test.startTest();
        PeriodFreezeHandler.handlePeriodFreeze(fp.Id);
        Test.stopTest();

        Integer supersededCount = [
            SELECT COUNT() FROM Failed_Event__c WHERE Status__c = 'Superseded'
        ];
        System.assertEquals(50, supersededCount,
            'All 50 original alerts should be superseded');

        Integer reclassifiedCount = [
            SELECT COUNT() FROM Failed_Event__c
            WHERE Event_Type__c = 'CLAWBACK_FROZEN_PERIOD'
            AND Status__c = 'Failed'
        ];
        System.assertEquals(50, reclassifiedCount,
            'All 50 alerts should be reclassified to frozen variants');
    }

    // ── Positive: extractOpportunityId handles valid payload ────────────

    @IsTest
    static void extractOpportunityId_validPayload() {
        Opportunity opp = getOpportunity();
        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id,
            'other' => 'data'
        });

        Test.startTest();
        Id result = PeriodFreezeHandler.extractOpportunityId(payload);
        Test.stopTest();

        System.assertEquals(opp.Id, result,
            'Should extract the correct Opportunity Id from valid JSON');
    }

    // ── Negative: extractOpportunityId handles null ─────────────────────

    @IsTest
    static void extractOpportunityId_nullPayload_returnsNull() {
        Test.startTest();
        Id result = PeriodFreezeHandler.extractOpportunityId(null);
        Test.stopTest();

        System.assertEquals(null, result,
            'Should return null for null payload');
    }

    // ── Negative: extractOpportunityId handles missing key ──────────────

    @IsTest
    static void extractOpportunityId_missingKey_returnsNull() {
        String payload = JSON.serialize(new Map<String, Object>{
            'someOtherField' => 'value'
        });

        Test.startTest();
        Id result = PeriodFreezeHandler.extractOpportunityId(payload);
        Test.stopTest();

        System.assertEquals(null, result,
            'Should return null when opportunityId key is missing');
    }
}
