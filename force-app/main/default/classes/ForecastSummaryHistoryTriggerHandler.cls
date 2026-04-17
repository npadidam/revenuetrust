public with sharing class ForecastSummaryHistoryTriggerHandler {
  /**
   * Enforces unique key: (Forecast_Summary__c, Snapshot_Date__c, Snapshot_Type__c).
   * Prevents duplicate cadence/submit snapshots on the same day.
   */
  public static void preventDuplicates(
    List<Forecast_Summary_History__c> newRecords
  ) {
    // Collect keys from incoming records
    Set<String> incomingKeys = new Set<String>();
    Map<String, Forecast_Summary_History__c> keyToRecord = new Map<String, Forecast_Summary_History__c>();
    Set<Id> summaryIds = new Set<Id>();

    for (Forecast_Summary_History__c h : newRecords) {
      if (
        h.Forecast_Summary__c == null ||
        h.Snapshot_Date__c == null ||
        h.Snapshot_Type__c == null
      ) {
        continue;
      }
      String key =
        h.Forecast_Summary__c +
        '|' +
        String.valueOf(h.Snapshot_Date__c) +
        '|' +
        h.Snapshot_Type__c;
      incomingKeys.add(key);
      keyToRecord.put(key, h);
      summaryIds.add(h.Forecast_Summary__c);
    }

    if (incomingKeys.isEmpty()) {
      return;
    }

    // Check for existing records with same keys
    for (Forecast_Summary_History__c existing : [
      SELECT Forecast_Summary__c, Snapshot_Date__c, Snapshot_Type__c
      FROM Forecast_Summary_History__c
      WHERE Forecast_Summary__c IN :summaryIds
    ]) {
      String existingKey =
        existing.Forecast_Summary__c +
        '|' +
        String.valueOf(existing.Snapshot_Date__c) +
        '|' +
        existing.Snapshot_Type__c;
      if (keyToRecord.containsKey(existingKey)) {
        keyToRecord.get(existingKey)
          .addError(
            'A summary history record already exists for this summary, date, and type.'
          );
      }
    }
  }
}
