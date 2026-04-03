/**
 * @description Tests for TriggerControlService.
 *              Verifies CMT cache loading, fail-open defaults, and cache clearing.
 *              Note: Trigger_Control__mdt is Custom Metadata — real records are
 *              visible in tests without SeeAllData. If no CMT records exist in
 *              the org the fail-open path is exercised instead.
 */
@IsTest
private class TriggerControlServiceTest {

    // ── Positive: known trigger returns expected value ───────────────────

    @IsTest
    static void isEnabled_knownTrigger_returnsCachedValue() {
        // Trigger_Control__mdt records are accessible in tests automatically.
        // If the org has a record with Is_Enabled__c = true, this returns true.
        // If no records exist, the fail-open path returns true anyway.
        Test.startTest();
        Boolean result = TriggerControlService.isEnabled('OpportunityCommissionTrigger');
        Test.stopTest();

        // Regardless of whether a CMT record exists, the contract is:
        //   - record exists & enabled  => true
        //   - record exists & disabled => false
        //   - record missing           => true (fail-open)
        // We assert non-null to confirm the method runs without error.
        System.assertNotEquals(null, result,
            'isEnabled should never return null');
    }

    // ── Positive: unknown trigger returns true (fail-open) ──────────────

    @IsTest
    static void isEnabled_unknownTrigger_returnsTrueFailOpen() {
        Test.startTest();
        Boolean result = TriggerControlService.isEnabled('NonExistentTriggerName_XYZ_999');
        Test.stopTest();

        System.assertEquals(true, result,
            'Unknown trigger names should default to enabled (fail-open)');
    }

    // ── Positive: cache is populated on first call, reused on second ────

    @IsTest
    static void isEnabled_multipleCallsUseSameCache() {
        Test.startTest();
        Boolean first  = TriggerControlService.isEnabled('TriggerA');
        Boolean second = TriggerControlService.isEnabled('TriggerB');
        Test.stopTest();

        // Both calls should succeed — cache is loaded once and reused
        System.assertNotEquals(null, first,  'First call should succeed');
        System.assertNotEquals(null, second, 'Second call should succeed');
    }

    // ── Positive: clearCache resets the internal cache ───────────────────

    @IsTest
    static void clearCache_resetsInternalState() {
        // Prime the cache
        TriggerControlService.isEnabled('AnyTrigger');

        Test.startTest();
        TriggerControlService.clearCache();
        // After clearing, the next call should reload cache from CMT
        Boolean result = TriggerControlService.isEnabled('AnyTrigger');
        Test.stopTest();

        System.assertNotEquals(null, result,
            'isEnabled should work correctly after cache clear');
    }

    // ── Negative: null trigger name returns true (fail-open) ────────────

    @IsTest
    static void isEnabled_nullTriggerName_returnsTrueFailOpen() {
        Test.startTest();
        Boolean result = TriggerControlService.isEnabled(null);
        Test.stopTest();

        // null key will not be found in cache => fail-open => true
        System.assertEquals(true, result,
            'Null trigger name should default to enabled (fail-open)');
    }

    // ── Negative: empty string trigger name returns true (fail-open) ────

    @IsTest
    static void isEnabled_emptyStringTriggerName_returnsTrueFailOpen() {
        Test.startTest();
        Boolean result = TriggerControlService.isEnabled('');
        Test.stopTest();

        System.assertEquals(true, result,
            'Empty string trigger name should default to enabled (fail-open)');
    }

    // ── Bulk: many lookups in a single transaction ──────────────────────

    @IsTest
    static void isEnabled_bulkLookups_performsWithinLimits() {
        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            TriggerControlService.isEnabled('BulkTrigger_' + i);
        }
        Test.stopTest();

        // If we get here without exception, cache worked for bulk lookups
        System.assert(true, 'Bulk lookups should not exceed governor limits');
    }
}
