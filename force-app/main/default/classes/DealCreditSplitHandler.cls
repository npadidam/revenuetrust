/**
 * @description Handler for Deal_Credit_Split__c trigger.
 *              Manages the full credit split lifecycle:
 *              - Before: validates split totals (100% per deal for primary splits)
 *              - After: publishes SPLIT_CHANGED events for commission recalculation
 *              - Approval workflow: only Active splits feed into commission engine
 *
 *              This replaces Salesforce's OpportunitySplit for orgs that don't have
 *              Team Selling enabled, and provides richer commission-aware splitting
 *              for orgs that do.
 */
public with sharing class DealCreditSplitHandler {

    private static final String TRIGGER_NAME = 'DealCreditSplitTrigger';

    public static void handleTrigger(List<Deal_Credit_Split__c> newList,
                                      List<Deal_Credit_Split__c> oldList,
                                      System.TriggerOperation operationType) {
        if (!TriggerControlService.isEnabled(TRIGGER_NAME)) {
            return;
        }

        // Before triggers: validation
        if (operationType == System.TriggerOperation.BEFORE_INSERT ||
            operationType == System.TriggerOperation.BEFORE_UPDATE) {
            validateSplits(newList, operationType);
        }

        // After triggers: events + audit
        if (operationType == System.TriggerOperation.AFTER_INSERT ||
            operationType == System.TriggerOperation.AFTER_UPDATE ||
            operationType == System.TriggerOperation.AFTER_DELETE) {
            publishSplitEvents(newList, oldList, operationType);
        }
    }

    // ── BEFORE: Validation ──────────────────────────────────────────────

    private static void validateSplits(List<Deal_Credit_Split__c> splits,
                                        System.TriggerOperation operationType) {
        // Collect opportunity IDs to validate totals
        Set<Id> oppIds = new Set<Id>();
        for (Deal_Credit_Split__c s : splits) {
            if (s.Opportunity__c != null) {
                oppIds.add(s.Opportunity__c);
            }

            // Auto-compute Effective_Commissionable_Value if not set
            // (will be properly computed by the commission engine using deal amount × split %)
            // For now, just ensure Split_Percentage or Split_Amount is provided
            if (s.Split_Percentage__c == null && s.Split_Amount__c == null) {
                s.addError('Either Split Percentage or Split Amount must be specified.');
            }

            // Validate Split_Percentage range
            if (s.Split_Percentage__c != null &&
                (s.Split_Percentage__c < 0 || s.Split_Percentage__c > 100)) {
                s.addError('Split Percentage must be between 0% and 100%.');
            }

            // Only one primary per deal
            if (s.Is_Primary__c == true) {
                oppIds.add(s.Opportunity__c);
            }
        }

        if (oppIds.isEmpty()) {
            return;
        }

        // Check for duplicate primaries
        Set<Id> newPrimaryOppIds = new Set<Id>();
        for (Deal_Credit_Split__c s : splits) {
            if (s.Is_Primary__c == true) {
                newPrimaryOppIds.add(s.Opportunity__c);
            }
        }

        if (!newPrimaryOppIds.isEmpty()) {
            // Query existing primaries on these deals
            List<Deal_Credit_Split__c> existingPrimaries = [
                SELECT Id, Opportunity__c
                FROM Deal_Credit_Split__c
                WHERE Opportunity__c IN :newPrimaryOppIds
                AND Is_Primary__c = true
                AND Id NOT IN :splits
            ];

            Set<Id> oppsWithPrimary = new Set<Id>();
            for (Deal_Credit_Split__c ep : existingPrimaries) {
                oppsWithPrimary.add(ep.Opportunity__c);
            }

            for (Deal_Credit_Split__c s : splits) {
                if (s.Is_Primary__c == true && oppsWithPrimary.contains(s.Opportunity__c)) {
                    s.addError('This deal already has a primary credit holder. ' +
                        'Only one primary split is allowed per deal.');
                }
            }
        }

        // Validate total split percentage per deal (Active + this batch)
        // Only validate for Active/Approved splits — Draft/Pending don't count
        Map<Id, Decimal> existingTotals = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Opportunity__c, SUM(Split_Percentage__c) totalPct
            FROM Deal_Credit_Split__c
            WHERE Opportunity__c IN :oppIds
            AND Status__c IN ('Active', 'Approved')
            AND Id NOT IN :splits
            AND Split_Percentage__c != null
            GROUP BY Opportunity__c
        ]) {
            existingTotals.put((Id) ar.get('Opportunity__c'), (Decimal) ar.get('totalPct'));
        }

        for (Deal_Credit_Split__c s : splits) {
            if (s.Status__c == 'Active' || s.Status__c == 'Approved') {
                if (s.Split_Percentage__c != null && s.Opportunity__c != null) {
                    Decimal existing = existingTotals.containsKey(s.Opportunity__c)
                        ? existingTotals.get(s.Opportunity__c) : 0;
                    Decimal newTotal = existing + s.Split_Percentage__c;
                    if (newTotal > 100.01) { // Small tolerance for rounding
                        s.addError('Total split percentage for this deal would be ' +
                            newTotal.setScale(2) + '%, which exceeds 100%. ' +
                            'Current allocated: ' + existing.setScale(2) + '%.');
                    }
                }
            }
        }
    }

    // ── AFTER: Event Publishing ──────────────────────────────────────────

    private static void publishSplitEvents(List<Deal_Credit_Split__c> newList,
                                            List<Deal_Credit_Split__c> oldList,
                                            System.TriggerOperation operationType) {
        List<Commission_Event__e> events = new List<Commission_Event__e>();

        // Only publish events for Active splits — Draft/Pending changes
        // don't affect commission calculations
        Set<String> activeStatuses = new Set<String>{ 'Active', 'Approved' };

        // Load won stages for post-close detection
        Set<String> wonStages = loadWonStages();
        Set<Id> oppIds = new Set<Id>();

        List<SObject> workingList = (newList != null) ? newList : oldList;
        for (SObject s : workingList) {
            Id oppId = (Id) s.get('Opportunity__c');
            if (oppId != null) oppIds.add(oppId);
        }

        Map<Id, Opportunity> oppMap = oppIds.isEmpty()
            ? new Map<Id, Opportunity>()
            : new Map<Id, Opportunity>(
                [SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]);

        if (operationType == System.TriggerOperation.AFTER_INSERT) {
            for (Deal_Credit_Split__c s : newList) {
                if (activeStatuses.contains(s.Status__c)) {
                    Boolean isPost = isPostClose(oppMap.get(s.Opportunity__c), wonStages);
                    events.add(buildEvent(s.Opportunity__c,
                        isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                        'SPLIT_ADDED', null,
                        s.Participant__c + ':' + s.Split_Percentage__c + '%'));
                }
            }
        } else if (operationType == System.TriggerOperation.AFTER_DELETE) {
            for (Deal_Credit_Split__c s : oldList) {
                if (activeStatuses.contains(s.Status__c)) {
                    Boolean isPost = isPostClose(oppMap.get(s.Opportunity__c), wonStages);
                    events.add(buildEvent(s.Opportunity__c,
                        isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                        'SPLIT_REMOVED',
                        s.Participant__c + ':' + s.Split_Percentage__c + '%', null));
                }
            }
        } else if (operationType == System.TriggerOperation.AFTER_UPDATE) {
            Map<Id, Deal_Credit_Split__c> oldMap = new Map<Id, Deal_Credit_Split__c>();
            for (Deal_Credit_Split__c s : oldList) oldMap.put(s.Id, s);

            for (Deal_Credit_Split__c s : newList) {
                Deal_Credit_Split__c oldS = oldMap.get(s.Id);

                // Status change to Active = new split activated
                if (activeStatuses.contains(s.Status__c) && !activeStatuses.contains(oldS.Status__c)) {
                    Boolean isPost = isPostClose(oppMap.get(s.Opportunity__c), wonStages);
                    events.add(buildEvent(s.Opportunity__c,
                        isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                        'SPLIT_ACTIVATED', null,
                        s.Participant__c + ':' + s.Split_Percentage__c + '%'));
                }
                // Status change FROM Active = split deactivated
                else if (!activeStatuses.contains(s.Status__c) && activeStatuses.contains(oldS.Status__c)) {
                    Boolean isPost = isPostClose(oppMap.get(s.Opportunity__c), wonStages);
                    events.add(buildEvent(s.Opportunity__c,
                        isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                        'SPLIT_DEACTIVATED',
                        s.Participant__c + ':' + oldS.Split_Percentage__c + '%', null));
                }
                // Active split modified (percentage, participant, or role changed)
                else if (activeStatuses.contains(s.Status__c) && activeStatuses.contains(oldS.Status__c)) {
                    if (s.Split_Percentage__c != oldS.Split_Percentage__c ||
                        s.Participant__c != oldS.Participant__c ||
                        s.Participant_Role__c != oldS.Participant_Role__c) {
                        Boolean isPost = isPostClose(oppMap.get(s.Opportunity__c), wonStages);
                        events.add(buildEvent(s.Opportunity__c,
                            isPost ? 'SPLIT_CHANGED_POST_CLOSE' : 'SPLIT_CHANGED',
                            'SPLIT_MODIFIED',
                            oldS.Participant__c + ':' + oldS.Split_Percentage__c + '%',
                            s.Participant__c + ':' + s.Split_Percentage__c + '%'));
                    }
                }
            }
        }

        if (!events.isEmpty()) {
            EventPublisherService.publishCommissionEvents(events);
        }

        // Audit trail
        if (operationType == System.TriggerOperation.AFTER_INSERT ||
            operationType == System.TriggerOperation.AFTER_UPDATE) {
            for (Deal_Credit_Split__c s : newList) {
                if (activeStatuses.contains(s.Status__c)) {
                    IncentiveChangeEventService.logEvent(
                        'Commission', s.Id, 'Status_Change',
                        null, s.Status__c,
                        'Deal credit split ' + operationType.name() +
                        ' for Opp ' + s.Opportunity__c);
                }
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static Boolean isPostClose(Opportunity opp, Set<String> wonStages) {
        return opp != null && wonStages.contains(opp.StageName);
    }

    private static Commission_Event__e buildEvent(Id oppId, String eventType,
                                                    String subtype, String oldVal, String newVal) {
        Commission_Event__e evt = new Commission_Event__e();
        evt.Opportunity_Id__c = oppId;
        evt.Event_Type__c = eventType;
        evt.Change_Subtype__c = subtype;
        evt.Previous_Value__c = oldVal;
        evt.New_Value__c = newVal;
        evt.User_Id__c = UserInfo.getUserId();
        return evt;
    }

    private static Set<String> loadWonStages() {
        Set<String> stages = new Set<String>{ 'Closed Won' };
        List<Incentive_Configuration__c> configs = [
            SELECT Won_Stages__c FROM Incentive_Configuration__c
            WHERE Is_Active__c = true LIMIT 1];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Won_Stages__c)) {
            stages.clear();
            for (String s : configs[0].Won_Stages__c.split(',')) {
                String trimmed = s.trim();
                if (String.isNotBlank(trimmed)) stages.add(trimmed);
            }
        }
        return stages;
    }
}
