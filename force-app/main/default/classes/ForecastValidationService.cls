/**
 * @description Validates Forecast_Override__c records before save.
 *              Checks period status, participant permissions, category validity,
 *              and pending approval locks.
 *
 *              Called by: ForecastOverrideTriggerHandler (before insert/update)
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 5, section 11.12
 */
public with sharing class ForecastValidationService {
  // Period statuses that block edits
  private static final Set<String> BLOCKED_PERIOD_STATUSES = new Set<String>{
    'Frozen',
    'Closed',
    'Scheduled'
  };

  /**
   * @description Validate a list of overrides before DML.
   *              Adds errors directly to SObject records to prevent save.
   * @param overrides The Trigger.new list
   * @param oldMap The Trigger.oldMap (null on insert)
   */
  public static void validateOverrides(
    List<Forecast_Override__c> overrides,
    Map<Id, Forecast_Override__c> oldMap
  ) {
    if (overrides == null || overrides.isEmpty()) {
      return;
    }

    // Collect period and participant IDs for bulk queries
    Set<Id> periodIds = new Set<Id>();
    Set<Id> participantIds = new Set<Id>();
    for (Forecast_Override__c ov : overrides) {
      if (ov.Forecast_Period__c != null) {
        periodIds.add(ov.Forecast_Period__c);
      }
      if (ov.Forecast_Participant__c != null) {
        participantIds.add(ov.Forecast_Participant__c);
      }
    }

    // 1. Load period statuses
    Map<Id, Forecast_Period__c> periodMap = new Map<Id, Forecast_Period__c>(
      [
        SELECT Id, Status__c, Name
        FROM Forecast_Period__c
        WHERE Id IN :periodIds
      ]
    );

    // 2. Load participant records for permission checks
    Map<Id, Forecast_Participant__c> participantMap = new Map<Id, Forecast_Participant__c>(
      [
        SELECT Id, User__c, Hierarchy_Level__c, Scope_Id__c
        FROM Forecast_Participant__c
        WHERE Id IN :participantIds
      ]
    );

    // 3. Load active forecast categories for validation + regression detection
    Set<String> activeCategories = new Set<String>();
    Set<String> regressionCategories = new Set<String>();
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    if (config != null && config.Forecast_Categories__r != null) {
      for (Forecast_Category__c cat : config.Forecast_Categories__r) {
        if (cat.Is_Active__c) {
          activeCategories.add(cat.Category_API_Name__c);
          if (cat.Regression_Warning__c == true) {
            regressionCategories.add(cat.Category_API_Name__c);
          }
        }
      }
    }

    // 4. Validate each override
    for (Forecast_Override__c ov : overrides) {
      // Check period status: must be Open or Prelock
      if (
        ov.Forecast_Period__c != null &&
        periodMap.containsKey(ov.Forecast_Period__c)
      ) {
        Forecast_Period__c period = periodMap.get(ov.Forecast_Period__c);
        if (BLOCKED_PERIOD_STATUSES.contains(period.Status__c)) {
          ov.addError(
            'Cannot modify overrides in a ' +
              period.Status__c +
              ' period (' +
              period.Name +
              ').'
          );
          continue;
        }
      }

      // Check participant has edit permission for this hierarchy level
      if (
        ov.Forecast_Participant__c != null &&
        participantMap.containsKey(ov.Forecast_Participant__c)
      ) {
        Forecast_Participant__c participant = participantMap.get(
          ov.Forecast_Participant__c
        );
        // Participant can only edit overrides at their own hierarchy level
        if (
          ov.Hierarchy_Level__c != null &&
          participant.Hierarchy_Level__c != null &&
          ov.Hierarchy_Level__c != participant.Hierarchy_Level__c
        ) {
          ov.addError(
            'You do not have permission to edit overrides at hierarchy level ' +
              ov.Hierarchy_Level__c +
              '.'
          );
          continue;
        }
      }

      // Validate category is an active Forecast_Category__c value
      if (
        String.isNotBlank(ov.Forecast_Category__c) &&
        !activeCategories.isEmpty() &&
        !activeCategories.contains(ov.Forecast_Category__c)
      ) {
        ov.addError(
          'Invalid forecast category: ' +
            ov.Forecast_Category__c +
            '. Must be one of: ' +
            String.join(new List<String>(activeCategories), ', ')
        );
        continue;
      }

      // Category regression warning (§5 item 3): log if category moves to a
      // regression-flagged category. Informational — does NOT block save.
      if (
        oldMap != null &&
        oldMap.containsKey(ov.Id) &&
        !regressionCategories.isEmpty()
      ) {
        Forecast_Override__c oldOv = oldMap.get(ov.Id);
        if (
          String.isNotBlank(ov.Forecast_Category__c) &&
          ov.Forecast_Category__c != oldOv.Forecast_Category__c &&
          regressionCategories.contains(ov.Forecast_Category__c)
        ) {
          System.debug(
            LoggingLevel.WARN,
            'ForecastValidation: Category regression detected on override ' +
              ov.Id +
              ': ' +
              oldOv.Forecast_Category__c +
              ' → ' +
              ov.Forecast_Category__c +
              ' (regression-flagged).'
          );
        }
      }

      // Check Pending_Approval__c: if true, only admin/reviewer can modify
      if (oldMap != null && oldMap.containsKey(ov.Id)) {
        Forecast_Override__c oldOv = oldMap.get(ov.Id);
        if (
          oldOv.Pending_Approval__c == true &&
          ov.Pending_Approval__c == true
        ) {
          // Record is pending approval -- block non-admin edits
          // Platform_Admin check: custom permission or profile
          if (!FeatureManagement.checkPermission('Platform_Admin')) {
            ov.addError(
              'This override is pending approval and cannot be modified.'
            );
          }
        }
      }
    }
  }
}
