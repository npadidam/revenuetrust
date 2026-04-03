/**
 * @description Lightweight handler for the Opportunity trigger (AD-1).
 *              Detects commission-relevant changes and publishes Commission_Event__e.
 *              This is the ONLY code running in the subscriber's transaction context.
 *
 *              Three safety mechanisms:
 *              1. Trigger_Control__mdt — admins can disable without code deploy
 *              2. Won/Lost stages from Incentive_Configuration__c — not hardcoded "Closed Won"
 *              3. Closed deal change detection — publishes REPROCESSING_REQUIRED if
 *                 amount/close date changes on an already-closed deal with existing commissions
 */
public with sharing class OpportunityCommissionTriggerHandler {

    private static final String TRIGGER_NAME = 'OpportunityCommissionTrigger';

    // Cached from Incentive_Configuration__c — loaded once per transaction
    private static Set<String> wonStages;
    private static Set<String> lostStages;
    private static Boolean configLoaded = false;

    public static void handleAfterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        // 1. Check CMT kill switch
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        // 2. Load configurable stages
        loadStageConfig();

        List<Commission_Event__e> events = new List<Commission_Event__e>();

        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            // ── DEAL CLOSED (stage moved TO a won stage) ──
            if (isWonStage(opp.StageName) && !isWonStage(oldOpp.StageName)) {
                events.add(buildEvent(opp, 'DEAL_CLOSED',
                    oldOpp.StageName, opp.StageName));
            }

            // ── DEAL LOST (stage moved TO a lost stage — triggers clawback evaluation) ──
            if (isLostStage(opp.StageName) && !isLostStage(oldOpp.StageName)) {
                events.add(buildEvent(opp, 'DEAL_LOST',
                    oldOpp.StageName, opp.StageName));
            }

            // ── DEAL REOPENED (stage moved FROM won/lost to an open stage) ──
            if ((isWonStage(oldOpp.StageName) || isLostStage(oldOpp.StageName))
                && !isWonStage(opp.StageName) && !isLostStage(opp.StageName)) {
                events.add(buildEvent(opp, 'DEAL_REOPENED',
                    oldOpp.StageName, opp.StageName));
            }

            // ── AMOUNT CHANGED ──
            if (opp.Amount != oldOpp.Amount) {
                String eventType = isWonStage(opp.StageName)
                    ? 'AMOUNT_CHANGED_POST_CLOSE'  // Already closed — may need reprocessing
                    : 'AMOUNT_CHANGED';
                events.add(buildEvent(opp, eventType,
                    String.valueOf(oldOpp.Amount), String.valueOf(opp.Amount)));
            }

            // ── CLOSE DATE CHANGED ──
            if (opp.CloseDate != oldOpp.CloseDate) {
                String eventType = isWonStage(opp.StageName)
                    ? 'CLOSE_DATE_CHANGED_POST_CLOSE'  // Already closed — may affect fiscal period, attainment
                    : 'CLOSE_DATE_CHANGED';
                events.add(buildEvent(opp, eventType,
                    String.valueOf(oldOpp.CloseDate), String.valueOf(opp.CloseDate)));
            }

            // ── STAGE CHANGED (any non-close/non-lost transition) ──
            if (opp.StageName != oldOpp.StageName
                && !isWonStage(opp.StageName)
                && !isLostStage(opp.StageName)
                && !isWonStage(oldOpp.StageName)
                && !isLostStage(oldOpp.StageName)) {
                events.add(buildEvent(opp, 'STAGE_CHANGED',
                    oldOpp.StageName, opp.StageName));
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }
    }

    // ── Stage configuration ─────────────────────────────────────────────

    private static void loadStageConfig() {
        if (configLoaded) {
            return;
        }
        configLoaded = true;

        // Default stages if no configuration exists
        wonStages = new Set<String>{ 'Closed Won' };
        lostStages = new Set<String>{ 'Closed Lost' };

        // Load from Incentive_Configuration__c (active config)
        List<Incentive_Configuration__c> configs = [
            SELECT Won_Stages__c, Lost_Stages__c
            FROM Incentive_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if (!configs.isEmpty()) {
            Incentive_Configuration__c config = configs[0];
            if (String.isNotBlank(config.Won_Stages__c)) {
                wonStages = parseStages(config.Won_Stages__c);
            }
            if (String.isNotBlank(config.Lost_Stages__c)) {
                lostStages = parseStages(config.Lost_Stages__c);
            }
        }
    }

    private static Set<String> parseStages(String commaDelimited) {
        Set<String> stages = new Set<String>();
        for (String s : commaDelimited.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                stages.add(trimmed);
            }
        }
        return stages;
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
        String previousValue,
        String newValue
    ) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = opp.Id;
        evt.Event_Type__c = eventType;
        evt.Previous_Value__c = previousValue;
        evt.New_Value__c = newValue;
        evt.User_Id__c = UserInfo.getUserId();
        return evt;
    }

    // ── Test support ────────────────────────────────────────────────────

    @TestVisible
    private static void resetConfig() {
        configLoaded = false;
        wonStages = null;
        lostStages = null;
    }
}
