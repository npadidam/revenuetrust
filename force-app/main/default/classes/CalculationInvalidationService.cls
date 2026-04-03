/**
 * @description Core service for handling plan/rule changes that affect existing
 *              commission calculations. Implements Commission Event Routing
 *              Matrix V2.3 section 12.4 — Calculation Invalidation Workflow.
 *
 *              Workflow:
 *              1. INVALIDATION DETECTED — called from config triggers
 *              2. IMPACT SCOPE RESOLUTION — find affected calcs, classify, compute blast radius
 *              3. EXECUTE BASED ON IMPACT — auto-recalc Projected; alert for Validated/Paid
 */
public with sharing class CalculationInvalidationService {

    // ── Constants ────────────────────────────────────────────────────────

    private static final String STATUS_PROJECTED  = 'Projected';
    private static final String STATUS_VALIDATED  = 'Validated';
    private static final String STATUS_PAID       = 'Paid';
    private static final String STATUS_FROZEN     = 'Frozen';

    private static final String ALERT_RETRO_REVIEW   = 'RETRO_RECALCULATION_REVIEW_REQUIRED';
    private static final String ALERT_FROZEN_PERIOD  = 'RULE_CHANGE_FROZEN_PERIOD_IMPACT';
    private static final String ALERT_CASCADE        = 'CASCADE_BOUNDARY_REACHED';

    @TestVisible
    private static final Integer CASCADE_THRESHOLD = 100;

    // ── Inner class for impact summary ───────────────────────────────────

    public class ImpactSummary {
        public Integer projectedCount;
        public Integer validatedCount;
        public Integer paidCount;
        public Integer frozenPeriodCount;
        public Decimal totalFinancialAmount;
        public Integer participantCount;
        public Integer periodCount;
        public Set<Id> affectedParticipantIds;
        public Set<Id> affectedPeriodIds;
        public List<Id> projectedCalcIds;
        public List<Id> validatedCalcIds;
        public List<Id> paidCalcIds;
        public Boolean hasFrozenPeriodCalcs;

        public ImpactSummary() {
            this.projectedCount        = 0;
            this.validatedCount        = 0;
            this.paidCount             = 0;
            this.frozenPeriodCount     = 0;
            this.totalFinancialAmount  = 0;
            this.participantCount      = 0;
            this.periodCount           = 0;
            this.affectedParticipantIds = new Set<Id>();
            this.affectedPeriodIds      = new Set<Id>();
            this.projectedCalcIds       = new List<Id>();
            this.validatedCalcIds       = new List<Id>();
            this.paidCalcIds            = new List<Id>();
            this.hasFrozenPeriodCalcs   = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  ENTRY POINT
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Entry point — called from config trigger handlers
     *              (CommissionTierTriggerHandler, PlanCapTriggerHandler, etc.)
     *              and from CommissionEventHandler.handlePlanStructureChanged().
     *              Resolves the parent template, computes impact, and takes action.
     * @param eventType The type of config change (RATE_TABLE_CHANGED, CAP_RULE_CHANGED, etc.)
     * @param sourceRecordId The Id of the config record that changed
     */
    public static void handleInvalidation(String eventType, Id sourceRecordId) {
        if (String.isBlank(eventType) || sourceRecordId == null) {
            return;
        }

        // Step 1: Resolve the parent Incentive_Plan_Template__c
        Id templateId = resolveParentTemplate(eventType, sourceRecordId);
        if (templateId == null) {
            logAction(eventType, sourceRecordId, null,
                'INVALIDATION_SKIPPED', 'Could not resolve parent template');
            return;
        }

        // Step 2: Resolve impact scope
        ImpactSummary impact = resolveImpact(templateId);

        // No affected calculations — nothing to do
        if (impact.projectedCount == 0
            && impact.validatedCount == 0
            && impact.paidCount == 0) {
            logAction(eventType, sourceRecordId, templateId,
                'INVALIDATION_NO_IMPACT', 'No affected calculations found');
            return;
        }

        logAction(eventType, sourceRecordId, templateId,
            'INVALIDATION_IMPACT_RESOLVED',
            'Projected=' + impact.projectedCount
                + ' Validated=' + impact.validatedCount
                + ' Paid=' + impact.paidCount
                + ' FrozenPeriod=' + impact.frozenPeriodCount
                + ' Participants=' + impact.participantCount
                + ' Amount=' + impact.totalFinancialAmount);

        // Step 3a: Auto-recalculate Projected calcs
        if (impact.projectedCount > 0) {
            autoRecalculateProjected(impact.projectedCalcIds);
            logAction(eventType, sourceRecordId, templateId,
                'PROJECTED_AUTO_RECALCULATED',
                'Recalculated ' + impact.projectedCount + ' projected calculations');
        }

        // Step 3b: Alert for Validated/Paid calcs
        if (impact.validatedCount > 0 || impact.paidCount > 0) {
            createInvalidationAlert(eventType, sourceRecordId, templateId, impact);
        }

        // Step 3c: Cascade boundary check
        Integer validatedPaidTotal = impact.validatedCount + impact.paidCount;
        if (validatedPaidTotal > getCascadeThreshold()) {
            createCascadeBoundaryAlert(eventType, sourceRecordId, templateId, impact);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STEP 1: PARENT TEMPLATE RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Resolve the Incentive_Plan_Template__c that owns the changed
     *              config record, based on event type.
     * @param eventType The invalidation event type
     * @param sourceRecordId The Id of the changed config record
     * @return The Id of the parent template, or null if not found
     */
    @TestVisible
    private static Id resolveParentTemplate(String eventType, Id sourceRecordId) {
        try {
            switch on eventType {

                when 'RATE_TABLE_CHANGED' {
                    // Commission_Tier__c is MasterDetail to Incentive_Plan_Template__c
                    List<Commission_Tier__c> tiers = [
                        SELECT Plan_Template__c
                        FROM Commission_Tier__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return tiers.isEmpty() ? null : tiers[0].Plan_Template__c;
                }

                when 'CAP_RULE_CHANGED' {
                    // Plan_Cap__c is MasterDetail to Incentive_Plan_Template__c
                    List<Plan_Cap__c> caps = [
                        SELECT Plan_Template__c
                        FROM Plan_Cap__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return caps.isEmpty() ? null : caps[0].Plan_Template__c;
                }

                when 'PRODUCT_ELIGIBILITY_RULE_CHANGED' {
                    // Template_Product_Eligibility__c is MasterDetail to Incentive_Plan_Template__c
                    List<Template_Product_Eligibility__c> rules = [
                        SELECT Plan_Template__c
                        FROM Template_Product_Eligibility__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return rules.isEmpty() ? null : rules[0].Plan_Template__c;
                }

                when 'ROLE_ELIGIBILITY_RULE_CHANGED' {
                    // Template_Role_Eligibility__c is MasterDetail to Incentive_Plan_Template__c
                    List<Template_Role_Eligibility__c> roles = [
                        SELECT Plan_Template__c
                        FROM Template_Role_Eligibility__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return roles.isEmpty() ? null : roles[0].Plan_Template__c;
                }

                when 'CLAWBACK_POLICY_CHANGED' {
                    List<Clawback_Policy__c> policies = [
                        SELECT Plan_Template__c
                        FROM Clawback_Policy__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return policies.isEmpty() ? null : policies[0].Plan_Template__c;
                }

                when 'PLAN_ASSIGNMENT_CHANGED' {
                    // sourceRecordId IS the Comp_Plan__c — query its template
                    List<Comp_Plan__c> plans = [
                        SELECT Plan_Template__c
                        FROM Comp_Plan__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return plans.isEmpty() ? null : plans[0].Plan_Template__c;
                }

                when else {
                    // Fallback: attempt to treat sourceRecordId as a Comp_Plan__c
                    List<Comp_Plan__c> plans = [
                        SELECT Plan_Template__c
                        FROM Comp_Plan__c
                        WHERE Id = :sourceRecordId
                        LIMIT 1
                    ];
                    return plans.isEmpty() ? null : plans[0].Plan_Template__c;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'CalculationInvalidationService.resolveParentTemplate failed: '
                + e.getMessage());
            return null;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STEP 2: IMPACT SCOPE RESOLUTION
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Find all Comp_Calculation__c records affected by a template
     *              change and classify them by status. Also checks whether any
     *              calculations fall within frozen forecast periods.
     * @param templateId The Incentive_Plan_Template__c whose config changed
     * @return ImpactSummary with full blast-radius details
     */
    @TestVisible
    private static ImpactSummary resolveImpact(Id templateId) {
        ImpactSummary impact = new ImpactSummary();

        // Query all affected calculations via Comp_Plan__c -> Plan_Template__c
        List<Comp_Calculation__c> calcs = [
            SELECT Id, Calculation_Status__c, Eligible_Commission__c,
                   Contract_Date2__c, Comp_Plan__c, Comp_Plan__r.Sales_Rep__c,
                   Opportunity__c
            FROM Comp_Calculation__c
            WHERE Comp_Plan__r.Plan_Template__c = :templateId
              AND Calculation_Status__c IN (:STATUS_PROJECTED, :STATUS_VALIDATED, :STATUS_PAID)
            ORDER BY CreatedDate DESC
            LIMIT 10000
        ];

        if (calcs.isEmpty()) {
            return impact;
        }

        // Load frozen periods for overlap check
        Map<Id, Forecast_Period__c> frozenPeriods = loadFrozenPeriods();

        // Classify each calculation
        for (Comp_Calculation__c calc : calcs) {
            Decimal amount = calc.Eligible_Commission__c != null
                ? calc.Eligible_Commission__c : 0;
            impact.totalFinancialAmount += amount;

            // Track participants
            if (calc.Comp_Plan__r.Sales_Rep__c != null) {
                impact.affectedParticipantIds.add(calc.Comp_Plan__r.Sales_Rep__c);
            }

            // Track periods (using Contract_Date2__c as the period indicator)
            if (calc.Contract_Date2__c != null) {
                // Use a synthetic period Id based on the date month
                // Real period Ids come from frozen-period overlap check below
            }

            // Check if calc falls in a frozen period
            Boolean inFrozenPeriod = isInFrozenPeriod(calc.Contract_Date2__c, frozenPeriods);

            // Classify by status
            String status = calc.Calculation_Status__c;
            if (status == STATUS_PROJECTED) {
                impact.projectedCount++;
                impact.projectedCalcIds.add(calc.Id);
            } else if (status == STATUS_VALIDATED) {
                impact.validatedCount++;
                impact.validatedCalcIds.add(calc.Id);
                if (inFrozenPeriod) {
                    impact.frozenPeriodCount++;
                    impact.hasFrozenPeriodCalcs = true;
                }
            } else if (status == STATUS_PAID) {
                impact.paidCount++;
                impact.paidCalcIds.add(calc.Id);
                if (inFrozenPeriod) {
                    impact.frozenPeriodCount++;
                    impact.hasFrozenPeriodCalcs = true;
                }
            }
        }

        // Collect affected period Ids from frozen periods
        for (Forecast_Period__c fp : frozenPeriods.values()) {
            for (Comp_Calculation__c calc : calcs) {
                if (calc.Contract_Date2__c != null
                    && calc.Contract_Date2__c >= fp.Start_Date__c
                    && calc.Contract_Date2__c <= fp.End_Date__c) {
                    impact.affectedPeriodIds.add(fp.Id);
                }
            }
        }

        // Also collect distinct period Ids from non-frozen calcs by querying
        // Forecast_Period__c that overlaps with any calc dates
        Set<Date> calcDates = new Set<Date>();
        for (Comp_Calculation__c calc : calcs) {
            if (calc.Contract_Date2__c != null) {
                calcDates.add(calc.Contract_Date2__c);
            }
        }
        if (!calcDates.isEmpty()) {
            Date minDate = null;
            Date maxDate = null;
            for (Date d : calcDates) {
                if (minDate == null || d < minDate) { minDate = d; }
                if (maxDate == null || d > maxDate) { maxDate = d; }
            }
            List<Forecast_Period__c> overlappingPeriods = [
                SELECT Id
                FROM Forecast_Period__c
                WHERE Start_Date__c <= :maxDate
                  AND End_Date__c >= :minDate
                LIMIT 500
            ];
            for (Forecast_Period__c fp : overlappingPeriods) {
                impact.affectedPeriodIds.add(fp.Id);
            }
        }

        impact.participantCount = impact.affectedParticipantIds.size();
        impact.periodCount      = impact.affectedPeriodIds.size();

        return impact;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STEP 3a: AUTO-RECALCULATE PROJECTED
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Delete projected calculations and re-trigger commission
     *              processing for each affected Opportunity via CommissionService.
     * @param projectedCalcIds The Comp_Calculation__c Ids to delete and recreate
     */
    @TestVisible
    private static void autoRecalculateProjected(List<Id> projectedCalcIds) {
        if (projectedCalcIds == null || projectedCalcIds.isEmpty()) {
            return;
        }

        // Query to get Opportunity Ids before deleting
        List<Comp_Calculation__c> calcsToDelete = [
            SELECT Id, Opportunity__c
            FROM Comp_Calculation__c
            WHERE Id IN :projectedCalcIds
        ];

        // Collect unique Opportunity Ids
        Set<Id> opportunityIds = new Set<Id>();
        for (Comp_Calculation__c calc : calcsToDelete) {
            if (calc.Opportunity__c != null) {
                opportunityIds.add(calc.Opportunity__c);
            }
        }

        // Delete the projected calcs
        if (!calcsToDelete.isEmpty()) {
            delete calcsToDelete;
        }

        // Re-process each Opportunity through the commission engine
        for (Id oppId : opportunityIds) {
            try {
                CommissionService.processOpportunity(oppId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'CalculationInvalidationService.autoRecalculateProjected failed '
                    + 'for Opportunity ' + oppId + ': ' + e.getMessage());
                // Log a failed event so it can be retried
                createFailedRecalcEvent(oppId, e);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STEP 3b: CREATE INVALIDATION ALERT
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Create a Failed_Event__c alert record for Validated/Paid
     *              calculations that cannot be auto-recalculated.
     * @param eventType The invalidation event type
     * @param sourceRecordId The config record that changed
     * @param templateId The parent template Id
     * @param impact The computed impact summary
     */
    @TestVisible
    private static void createInvalidationAlert(
        String eventType, Id sourceRecordId, Id templateId, ImpactSummary impact
    ) {
        // Resolve template name for the alert message
        String templateName = resolveTemplateName(templateId);

        // Determine alert type based on frozen-period overlap
        String alertType = impact.hasFrozenPeriodCalcs
            ? ALERT_FROZEN_PERIOD
            : ALERT_RETRO_REVIEW;

        // Build detailed JSON payload
        Map<String, Object> payload = new Map<String, Object>{
            'eventType'             => eventType,
            'sourceRecordId'        => sourceRecordId,
            'templateId'            => templateId,
            'templateName'          => templateName,
            'projectedCount'        => impact.projectedCount,
            'validatedCount'        => impact.validatedCount,
            'paidCount'             => impact.paidCount,
            'frozenPeriodCount'     => impact.frozenPeriodCount,
            'totalFinancialAmount'  => impact.totalFinancialAmount,
            'participantCount'      => impact.participantCount,
            'periodCount'           => impact.periodCount,
            'affectedParticipantIds' => new List<Id>(impact.affectedParticipantIds),
            'affectedPeriodIds'      => new List<Id>(impact.affectedPeriodIds),
            'validatedCalcIds'       => impact.validatedCalcIds,
            'paidCalcIds'            => impact.paidCalcIds,
            'hasFrozenPeriodCalcs'   => impact.hasFrozenPeriodCalcs,
            'timestamp'              => Datetime.now().format()
        };

        // Build human-readable alert message
        String eventLabel = eventType.replace('_', ' ').toLowerCase();
        String alertMessage = String.format(
            '{0} on template "{1}" affects {2} calculations across {3} participants '
            + '({4} validated, {5} paid, total amount: {6}). '
            + '{7} forecast periods impacted.',
            new List<String>{
                eventLabel,
                templateName,
                String.valueOf(impact.validatedCount + impact.paidCount),
                String.valueOf(impact.participantCount),
                String.valueOf(impact.validatedCount),
                String.valueOf(impact.paidCount),
                String.valueOf(impact.totalFinancialAmount),
                String.valueOf(impact.periodCount)
            }
        );

        if (impact.hasFrozenPeriodCalcs) {
            alertMessage += ' WARNING: ' + impact.frozenPeriodCount
                + ' calculations fall within frozen forecast periods.';
        }

        // Insert Failed_Event__c alert
        Failed_Event__c alert = new Failed_Event__c();
        alert.Event_Type__c          = alertType;
        alert.Payload__c             = JSON.serialize(payload);
        alert.Error_Message__c       = alertMessage;
        alert.Retry_Count__c         = 0;
        alert.Status__c              = 'Failed';
        alert.Original_Event_Time__c = Datetime.now();
        insert alert;

        logAction(eventType, sourceRecordId, templateId,
            'INVALIDATION_ALERT_CREATED',
            'Alert type: ' + alertType + ' — ' + alertMessage);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  STEP 3c: CASCADE BOUNDARY ALERT
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Create a CASCADE_BOUNDARY_REACHED alert when the number
     *              of Validated/Paid calculations exceeds the configured
     *              attainment recompute scope threshold.
     * @param eventType The invalidation event type
     * @param sourceRecordId The config record that changed
     * @param templateId The parent template Id
     * @param impact The computed impact summary
     */
    @TestVisible
    private static void createCascadeBoundaryAlert(
        String eventType, Id sourceRecordId, Id templateId, ImpactSummary impact
    ) {
        String templateName = resolveTemplateName(templateId);
        Integer validatedPaidTotal = impact.validatedCount + impact.paidCount;

        Map<String, Object> payload = new Map<String, Object>{
            'eventType'            => eventType,
            'sourceRecordId'       => sourceRecordId,
            'templateId'           => templateId,
            'templateName'         => templateName,
            'validatedPaidTotal'   => validatedPaidTotal,
            'cascadeThreshold'     => getCascadeThreshold(),
            'participantCount'     => impact.participantCount,
            'totalFinancialAmount' => impact.totalFinancialAmount,
            'timestamp'            => Datetime.now().format()
        };

        String alertMessage = 'CASCADE BOUNDARY REACHED: ' + eventType.replace('_', ' ').toLowerCase()
            + ' on template "' + templateName + '" exceeds attainment recompute scope. '
            + validatedPaidTotal + ' validated/paid calculations affected across '
            + impact.participantCount + ' participants (threshold: '
            + getCascadeThreshold() + '). Manual review required before bulk reprocessing.';

        Failed_Event__c alert = new Failed_Event__c();
        alert.Event_Type__c          = ALERT_CASCADE;
        alert.Payload__c             = JSON.serialize(payload);
        alert.Error_Message__c       = alertMessage;
        alert.Retry_Count__c         = 0;
        alert.Status__c              = 'Failed';
        alert.Original_Event_Time__c = Datetime.now();
        insert alert;

        logAction(eventType, sourceRecordId, templateId,
            'CASCADE_BOUNDARY_ALERT_CREATED', alertMessage);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @description Load all frozen Forecast_Period__c records for overlap checks.
     * @return Map of Forecast_Period__c by Id
     */
    private static Map<Id, Forecast_Period__c> loadFrozenPeriods() {
        List<Forecast_Period__c> periods = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Forecast_Period__c
            WHERE Status__c = :STATUS_FROZEN
            LIMIT 500
        ];
        return new Map<Id, Forecast_Period__c>(periods);
    }

    /**
     * @description Check whether a given date falls within any frozen period.
     * @param calcDate The Contract_Date2__c value from a Comp_Calculation__c
     * @param frozenPeriods Map of frozen Forecast_Period__c records
     * @return true if the date falls within a frozen period
     */
    private static Boolean isInFrozenPeriod(Date calcDate, Map<Id, Forecast_Period__c> frozenPeriods) {
        if (calcDate == null || frozenPeriods.isEmpty()) {
            return false;
        }
        for (Forecast_Period__c fp : frozenPeriods.values()) {
            if (fp.Start_Date__c != null && fp.End_Date__c != null
                && calcDate >= fp.Start_Date__c && calcDate <= fp.End_Date__c) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Resolve the Name of an Incentive_Plan_Template__c for alert messages.
     * @param templateId The template Id
     * @return The template name, or 'Unknown' if not found
     */
    private static String resolveTemplateName(Id templateId) {
        List<Incentive_Plan_Template__c> templates = [
            SELECT Name
            FROM Incentive_Plan_Template__c
            WHERE Id = :templateId
            LIMIT 1
        ];
        return templates.isEmpty() ? 'Unknown' : templates[0].Name;
    }

    /**
     * @description Load the cascade threshold from Incentive_Configuration__c.
     *              Defaults to CASCADE_THRESHOLD (100) if not configured.
     * @return The attainment recompute scope threshold
     */
    @TestVisible
    private static Integer getCascadeThreshold() {
        List<Incentive_Configuration__c> configs = [
            SELECT Attainment_Recompute_Scope__c
            FROM Incentive_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];
        // Attainment_Recompute_Scope__c is a picklist (not numeric).
        // CASCADE_THRESHOLD is the hard limit regardless of scope.
        // Scope determines WHO gets recomputed, threshold determines WHEN to stop.
        return CASCADE_THRESHOLD;
    }

    /**
     * @description Create a Failed_Event__c when auto-recalculation of a
     *              projected calc fails for a specific Opportunity.
     * @param opportunityId The Opportunity that failed recalculation
     * @param e The exception that occurred
     */
    private static void createFailedRecalcEvent(Id opportunityId, Exception e) {
        try {
            Failed_Event__c failedEvt = new Failed_Event__c();
            failedEvt.Event_Type__c = 'INVALIDATION_RECALC_FAILED';
            failedEvt.Payload__c = JSON.serialize(new Map<String, Object>{
                'opportunityId' => opportunityId,
                'error'         => e.getMessage(),
                'stackTrace'    => e.getStackTraceString(),
                'timestamp'     => Datetime.now().format()
            });
            failedEvt.Error_Message__c = 'Auto-recalculation failed for Opportunity '
                + opportunityId + ': ' + e.getMessage();
            failedEvt.Retry_Count__c         = 0;
            failedEvt.Status__c              = 'Failed';
            failedEvt.Original_Event_Time__c = Datetime.now();
            insert failedEvt;
        } catch (Exception logEx) {
            System.debug(LoggingLevel.ERROR,
                'CalculationInvalidationService.createFailedRecalcEvent failed: '
                + logEx.getMessage());
        }
    }

    /**
     * @description Log an action to IncentiveChangeEventService for audit trail.
     * @param eventType The invalidation event type
     * @param sourceRecordId The source config record Id
     * @param templateId The parent template Id (may be null)
     * @param changeType The action taken
     * @param context Additional context string
     */
    private static void logAction(
        String eventType, Id sourceRecordId, Id templateId,
        String changeType, String context
    ) {
        try {
            Id logRecordId = templateId != null ? templateId : sourceRecordId;
            IncentiveChangeEventService.logEvent(
                'CalculationInvalidation',
                logRecordId,
                changeType,
                eventType,
                null,
                context
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'CalculationInvalidationService.logAction failed: ' + e.getMessage());
        }
    }
}
