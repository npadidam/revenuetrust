/**
 * @description Trigger handler for Forecast_Quota__c.
 *              Enforces uniqueness: one quota per User + Period + Group (Group nullable).
 *              Phase B: a user can have one config-wide quota (Group = null) AND
 *              group-specific quotas simultaneously.
 *              Validates: Target >= 0, User must be active participant.
 */
public with sharing class ForecastQuotaTriggerHandler {
  /**
   * @description Build a 3-part key from User + Period + Group (Group can be null).
   */
  private static String buildKey(Id userId, Id periodId, Id groupId) {
    return String.valueOf(userId) +
      '_' +
      String.valueOf(periodId) +
      '_' +
      (groupId == null ? 'NULL' : String.valueOf(groupId));
  }

  /**
   * @description Before insert/update: validate uniqueness and business rules.
   */
  public static void handleBeforeUpsert(
    List<Forecast_Quota__c> newList,
    Map<Id, Forecast_Quota__c> oldMap
  ) {
    if (newList == null || newList.isEmpty())
      return;

    // Collect User + Period + Group keys for duplicate check
    Set<String> newKeys = new Set<String>();
    Set<Id> userIds = new Set<Id>();
    Set<Id> periodIds = new Set<Id>();

    for (Forecast_Quota__c fq : newList) {
      if (fq.User__c != null && fq.Forecast_Period__c != null) {
        String key = buildKey(
          fq.User__c,
          fq.Forecast_Period__c,
          fq.Forecast_Group__c
        );

        // Check for duplicates within the batch
        if (newKeys.contains(key)) {
          fq.addError(
            'Duplicate quota: another record in this batch has the same User + Period + Group.'
          );
          continue;
        }
        newKeys.add(key);

        userIds.add(fq.User__c);
        periodIds.add(fq.Forecast_Period__c);
      }

      // Validate target >= 0
      if (fq.Target_Amount__c != null && fq.Target_Amount__c < 0) {
        fq.addError('Target amount cannot be negative.');
      }
    }

    // Validate user is an active participant for the period (§8.5)
    if (!userIds.isEmpty() && !periodIds.isEmpty()) {
      Set<String> participantKeys = new Set<String>();
      for (Forecast_Participant__c fp : [
        SELECT User__c, Forecast_Period__c
        FROM Forecast_Participant__c
        WHERE
          User__c IN :userIds
          AND Forecast_Period__c IN :periodIds
          AND Is_Summary__c = FALSE
      ]) {
        participantKeys.add(
          String.valueOf(fp.User__c) +
            '_' +
            String.valueOf(fp.Forecast_Period__c)
        );
      }
      for (Forecast_Quota__c fq : newList) {
        if (fq.User__c == null || fq.Forecast_Period__c == null)
          continue;
        String key =
          String.valueOf(fq.User__c) +
          '_' +
          String.valueOf(fq.Forecast_Period__c);
        if (!participantKeys.contains(key)) {
          fq.addError('User is not a forecast participant for this period.');
        }
      }
    }

    // Check for existing records with same User + Period + Group (for inserts)
    if (!userIds.isEmpty()) {
      Map<String, Id> existingKeys = new Map<String, Id>();
      for (Forecast_Quota__c existing : [
        SELECT Id, User__c, Forecast_Period__c, Forecast_Group__c
        FROM Forecast_Quota__c
        WHERE User__c IN :userIds AND Forecast_Period__c IN :periodIds
      ]) {
        String key = buildKey(
          existing.User__c,
          existing.Forecast_Period__c,
          existing.Forecast_Group__c
        );
        existingKeys.put(key, existing.Id);
      }

      for (Forecast_Quota__c fq : newList) {
        if (fq.User__c == null || fq.Forecast_Period__c == null)
          continue;
        String key = buildKey(
          fq.User__c,
          fq.Forecast_Period__c,
          fq.Forecast_Group__c
        );
        Id existingId = existingKeys.get(key);

        // Allow update of the same record, block duplicate inserts
        if (existingId != null && existingId != fq.Id) {
          String groupContext = fq.Forecast_Group__c == null
            ? 'config-wide'
            : 'this group';
          fq.addError(
            'A quota already exists for this user in this period (' +
              groupContext +
              '). ' +
              'Use the Quota Manager to edit the existing record.'
          );
        }
      }
    }

    // Auto-compute attainment percentage
    for (Forecast_Quota__c fq : newList) {
      if (
        fq.Target_Amount__c != null &&
        fq.Target_Amount__c > 0 &&
        fq.Achieved_Amount__c != null
      ) {
        fq.Attainment_Pct__c =
          (fq.Achieved_Amount__c / fq.Target_Amount__c) * 100;
      } else {
        fq.Attainment_Pct__c = 0;
      }
    }
  }
}
