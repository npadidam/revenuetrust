/**
 * @description Lightweight handler for the Opportunity trigger (AD-1).
 *              Detects commission-relevant changes and publishes Commission_Event__e.
 *              This is the ONLY code running in the subscriber's transaction context.
 *
 *              Covers Commission Event Routing Matrix V2.3:
 *              Family A — Stage & financial field changes
 *              Family B — Quota credit & currency changes
 *              Family C — Ownership, eligibility, territory & metadata changes
 *
 *              Safety mechanisms:
 *              1. Trigger_Control__mdt — admins can disable without code deploy
 *              2. Won/Lost stages from Incentive_Configuration__c — not hardcoded
 *              3. Watch-field lists from Incentive_Configuration__c — admin-configurable
 *              4. POST_CLOSE variants auto-detect when deal is in a won stage
 */
public with sharing class OpportunityCommissionTriggerHandler {

    private static final String TRIGGER_NAME = 'OpportunityCommissionTrigger';

    // Cached from Incentive_Configuration__c — loaded once per transaction
    private static Set<String> wonStages;
    private static Set<String> lostStages;
    private static List<String> eligibilityWatchFields;
    private static List<String> quotaCreditWatchFields;
    private static String territoryField;
    private static Boolean configLoaded = false;

    public static void handleAfterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        // 1. Check CMT kill switch
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        // 2. Load configurable stages and watch fields
        loadConfig();

        List<Commission_Event__e> events = new List<Commission_Event__e>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            Boolean currentlyWon = isWonStage(opp.StageName);
            Boolean previouslyWon = isWonStage(oldOpp.StageName);
            Boolean currentlyLost = isLostStage(opp.StageName);
            Boolean previouslyLost = isLostStage(oldOpp.StageName);
            Boolean currentlyClosed = currentlyWon || currentlyLost;
            Boolean previouslyClosed = previouslyWon || previouslyLost;

            // ================================================================
            // FAMILY A — Stage & Financial Field Changes
            // ================================================================

            // ── DEAL_CLOSED (stage moved TO a won stage) ──
            if (currentlyWon && !previouslyWon) {
                events.add(buildEvent(opp, 'DEAL_CLOSED', null,
                    oldOpp.StageName, opp.StageName));
            }

            // ── DEAL_LOST (stage moved TO a lost stage) ──
            if (currentlyLost && !previouslyLost) {
                events.add(buildEvent(opp, 'DEAL_LOST', null,
                    oldOpp.StageName, opp.StageName));
            }

            // ── DEAL_REOPENED (stage moved FROM won/lost TO open) ──
            if (previouslyClosed && !currentlyClosed) {
                events.add(buildEvent(opp, 'DEAL_REOPENED', null,
                    oldOpp.StageName, opp.StageName));
            }

            // ── STAGE_CHANGED (open-to-open stage transition) ──
            if (opp.StageName != oldOpp.StageName
                && !currentlyClosed && !previouslyClosed) {
                events.add(buildEvent(opp, 'STAGE_CHANGED', null,
                    oldOpp.StageName, opp.StageName));
            }

            // ── AMOUNT_CHANGED / AMOUNT_CHANGED_POST_CLOSE ──
            if (opp.Amount != oldOpp.Amount) {
                String eventType = currentlyWon
                    ? 'AMOUNT_CHANGED_POST_CLOSE'
                    : 'AMOUNT_CHANGED';
                events.add(buildEvent(opp, eventType, null,
                    String.valueOf(oldOpp.Amount), String.valueOf(opp.Amount)));
            }

            // ── CLOSE_DATE_CHANGED / CLOSE_DATE_CHANGED_POST_CLOSE ──
            if (opp.CloseDate != oldOpp.CloseDate) {
                String eventType = currentlyWon
                    ? 'CLOSE_DATE_CHANGED_POST_CLOSE'
                    : 'CLOSE_DATE_CHANGED';
                events.add(buildEvent(opp, eventType, null,
                    String.valueOf(oldOpp.CloseDate), String.valueOf(opp.CloseDate)));
            }

            // ================================================================
            // FAMILY B — Quota Credit & Currency Changes
            // ================================================================

            // ── QUOTA_CREDIT_CHANGED ──
            if (!quotaCreditWatchFields.isEmpty()) {
                for (String fieldName : quotaCreditWatchFields) {
                    Object newVal = opp.get(fieldName);
                    Object oldVal = oldOpp.get(fieldName);
                    if (newVal != oldVal) {
                        events.add(buildEvent(opp, 'QUOTA_CREDIT_CHANGED', fieldName,
                            String.valueOf(oldVal), String.valueOf(newVal)));
                        break; // One event per record; subtype carries the first changed field
                    }
                }
            }

            // ── CURRENCY_CHANGED (multi-currency orgs only) ──
            detectCurrencyChange(opp, oldOpp, events);

            // ================================================================
            // FAMILY C — Ownership, Eligibility, Territory & Metadata Changes
            // ================================================================

            // ── OWNER_CHANGED / OWNER_CHANGED_POST_CLOSE ──
            if (opp.OwnerId != oldOpp.OwnerId) {
                String eventType = currentlyWon
                    ? 'OWNER_CHANGED_POST_CLOSE'
                    : 'OWNER_CHANGED';
                events.add(buildEvent(opp, eventType, null,
                    String.valueOf(oldOpp.OwnerId), String.valueOf(opp.OwnerId)));
            }

            // ── RECORD_TYPE_CHANGED (fires for both open and closed deals) ──
            // Use dynamic access — RecordTypeId may not exist if org has no record types
            try {
                Object newRT = opp.get('RecordTypeId');
                Object oldRT = oldOpp.get('RecordTypeId');
                if (newRT != null && oldRT != null && newRT != oldRT) {
                    events.add(buildEvent(opp, 'RECORD_TYPE_CHANGED', null,
                        String.valueOf(oldRT), String.valueOf(newRT)));
                }
            } catch (SObjectException e) {
                // RecordTypeId not available — skip
            }

            // ── ELIGIBILITY_CHANGED / ELIGIBILITY_CHANGED_POST_CLOSE ──
            if (!eligibilityWatchFields.isEmpty()) {
                for (String fieldName : eligibilityWatchFields) {
                    Object newVal = opp.get(fieldName);
                    Object oldVal = oldOpp.get(fieldName);
                    if (newVal != oldVal) {
                        String eventType = currentlyWon
                            ? 'ELIGIBILITY_CHANGED_POST_CLOSE'
                            : 'ELIGIBILITY_CHANGED';
                        events.add(buildEvent(opp, eventType, fieldName,
                            String.valueOf(oldVal), String.valueOf(newVal)));
                        break; // One event per record; subtype carries the first changed field
                    }
                }
            }

            // ── PROBABILITY_CHANGED ──
            if (opp.Probability != oldOpp.Probability) {
                events.add(buildEvent(opp, 'PROBABILITY_CHANGED', null,
                    String.valueOf(oldOpp.Probability), String.valueOf(opp.Probability)));
            }

            // ── TERRITORY_CHANGED ──
            if (String.isNotBlank(territoryField)) {
                Object newVal = opp.get(territoryField);
                Object oldVal = oldOpp.get(territoryField);
                if (newVal != oldVal) {
                    events.add(buildEvent(opp, 'TERRITORY_CHANGED', territoryField,
                        String.valueOf(oldVal), String.valueOf(newVal)));
                }
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    // ── Currency change detection (safe for single-currency orgs) ───────

    private static void detectCurrencyChange(
        Opportunity opp, Opportunity oldOpp, List<Commission_Event__e> events
    ) {
        if (!UserInfo.isMultiCurrencyOrganization()) {
            return;
        }
        Object newCurrency = opp.get('CurrencyIsoCode');
        Object oldCurrency = oldOpp.get('CurrencyIsoCode');
        if (newCurrency != oldCurrency) {
            events.add(buildEvent(opp, 'CURRENCY_CHANGED', null,
                String.valueOf(oldCurrency), String.valueOf(newCurrency)));
        }
    }

    // ── Configuration loading ───────────────────────────────────────────

    private static void loadConfig() {
        if (configLoaded) {
            return;
        }
        configLoaded = true;

        // Defaults
        wonStages = new Set<String>{ 'Closed Won' };
        lostStages = new Set<String>{ 'Closed Lost' };
        eligibilityWatchFields = new List<String>();
        quotaCreditWatchFields = new List<String>();
        territoryField = null;

        List<Incentive_Configuration__c> configs = [
            SELECT Won_Stages__c,
                   Lost_Stages__c,
                   Eligibility_Watch_Fields__c,
                   Quota_Credit_Watch_Fields__c,
                   Territory_Field__c
            FROM Incentive_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if (!configs.isEmpty()) {
            Incentive_Configuration__c cfg = configs[0];
            if (String.isNotBlank(cfg.Won_Stages__c)) {
                wonStages = parseDelimitedSet(cfg.Won_Stages__c);
            }
            if (String.isNotBlank(cfg.Lost_Stages__c)) {
                lostStages = parseDelimitedSet(cfg.Lost_Stages__c);
            }
            if (String.isNotBlank(cfg.Eligibility_Watch_Fields__c)) {
                eligibilityWatchFields = parseDelimitedList(cfg.Eligibility_Watch_Fields__c);
            }
            if (String.isNotBlank(cfg.Quota_Credit_Watch_Fields__c)) {
                quotaCreditWatchFields = parseDelimitedList(cfg.Quota_Credit_Watch_Fields__c);
            }
            if (String.isNotBlank(cfg.Territory_Field__c)) {
                territoryField = cfg.Territory_Field__c.trim();
            }
        }
    }

    private static Set<String> parseDelimitedSet(String commaDelimited) {
        Set<String> result = new Set<String>();
        for (String s : commaDelimited.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }

    private static List<String> parseDelimitedList(String commaDelimited) {
        List<String> result = new List<String>();
        for (String s : commaDelimited.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }

    private static Boolean isWonStage(String stageName) {
        return wonStages != null && wonStages.contains(stageName);
    }

    private static Boolean isLostStage(String stageName) {
        return lostStages != null && lostStages.contains(stageName);
    }

    // ── Event builder ───────────────────────────────────────────────────

    private static Commission_Event__e buildEvent(
        Opportunity opp,
        String eventType,
        String changeSubtype,
        String previousValue,
        String newValue
    ) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = opp.Id;
        evt.Event_Type__c = eventType;
        evt.Previous_Value__c = previousValue;
        evt.New_Value__c = newValue;
        evt.User_Id__c = UserInfo.getUserId();
        if (String.isNotBlank(changeSubtype)) {
            evt.Change_Subtype__c = changeSubtype;
        }
        return evt;
    }

    // ── Test support ────────────────────────────────────────────────────

    @TestVisible
    private static void resetConfig() {
        configLoaded = false;
        wonStages = null;
        lostStages = null;
        eligibilityWatchFields = null;
        quotaCreditWatchFields = null;
        territoryField = null;
    }
}
