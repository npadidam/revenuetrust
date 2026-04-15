/**
 * @description Updates Forecast_Participant__c.Submission_Status__c based on
 *              the aggregate status of all overrides belonging to that participant.
 *
 *              Status logic:
 *              - All overrides Frozen     -> 'Frozen'
 *              - All overrides Submitted  -> 'Submitted'
 *              - All overrides Saved      -> 'Saved'
 *              - Mix of Submitted + other -> 'Partially_Submitted'
 *              - Mix of Saved + other     -> 'Partially_Saved'
 *
 *              Called by: ForecastOverrideTriggerHandler (after insert/update)
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 5, section 11.12
 */
public with sharing class ForecastParticipantStatusService {
  /**
   * @description Determine and update the submission status for each participant
   *              that owns the given overrides.
   * @param overrides The Trigger.new list of changed overrides
   */
  public static void updateStatus(List<Forecast_Override__c> overrides) {
    if (overrides == null || overrides.isEmpty()) {
      return;
    }

    // Collect participant IDs from the changed overrides
    Set<Id> participantIds = new Set<Id>();
    for (Forecast_Override__c ov : overrides) {
      if (ov.Forecast_Participant__c != null) {
        participantIds.add(ov.Forecast_Participant__c);
      }
    }

    if (participantIds.isEmpty()) {
      return;
    }

    // Query ALL overrides for each affected participant (not just the changed ones)
    Map<Id, List<Forecast_Override__c>> participantOverrides = new Map<Id, List<Forecast_Override__c>>();

    for (Forecast_Override__c ov : [
      SELECT Id, Forecast_Participant__c, Status__c
      FROM Forecast_Override__c
      WHERE Forecast_Participant__c IN :participantIds
    ]) {
      if (!participantOverrides.containsKey(ov.Forecast_Participant__c)) {
        participantOverrides.put(
          ov.Forecast_Participant__c,
          new List<Forecast_Override__c>()
        );
      }
      participantOverrides.get(ov.Forecast_Participant__c).add(ov);
    }

    // Determine aggregate status for each participant
    List<Forecast_Participant__c> participantsToUpdate = new List<Forecast_Participant__c>();

    for (Id participantId : participantIds) {
      List<Forecast_Override__c> allOverrides = participantOverrides.get(
        participantId
      );
      if (allOverrides == null || allOverrides.isEmpty()) {
        continue;
      }

      String aggregateStatus = computeAggregateStatus(allOverrides);

      participantsToUpdate.add(
        new Forecast_Participant__c(
          Id = participantId,
          Submission_Status__c = aggregateStatus
        )
      );
    }

    if (!participantsToUpdate.isEmpty()) {
      update participantsToUpdate;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────

  /**
   * @description Compute the aggregate submission status from a list of overrides.
   */
  private static String computeAggregateStatus(
    List<Forecast_Override__c> allOverrides
  ) {
    Set<String> statuses = new Set<String>();
    for (Forecast_Override__c ov : allOverrides) {
      if (String.isNotBlank(ov.Status__c)) {
        statuses.add(ov.Status__c);
      }
    }

    if (statuses.isEmpty()) {
      return 'New';
    }

    // Single status -- all overrides have the same status
    if (statuses.size() == 1) {
      String singleStatus = new List<String>(statuses)[0];
      if (singleStatus == 'Frozen') {
        return 'Frozen';
      } else if (singleStatus == 'Submitted') {
        return 'Submitted';
      } else if (singleStatus == 'Saved') {
        return 'Saved';
      }
      return singleStatus;
    }

    // Mixed statuses
    if (statuses.contains('Frozen')) {
      return 'Frozen';
    }
    if (statuses.contains('Submitted')) {
      return 'Partially_Submitted';
    }
    if (statuses.contains('Saved')) {
      return 'Partially_Saved';
    }

    return 'In Progress';
  }
}
