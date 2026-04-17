/**
 * @description Trigger handler for Forecast_Metric_Filter__c.
 *              - Enforces max 5 clauses per metric
 *              - Validates Field_API_Name__c exists on the parent metric's Source_Object__c
 *              - Sets default Validation_Status to 'Valid' on insert
 */
public with sharing class ForecastMetricFilterTriggerHandler {
  private static final Integer MAX_CLAUSES_PER_METRIC = 5;

  public static void handleBeforeUpsert(
    List<Forecast_Metric_Filter__c> newList,
    Map<Id, Forecast_Metric_Filter__c> oldMap
  ) {
    if (newList == null || newList.isEmpty())
      return;

    // Group new clauses by parent metric
    Map<Id, List<Forecast_Metric_Filter__c>> newByMetric = new Map<Id, List<Forecast_Metric_Filter__c>>();
    Set<Id> metricIds = new Set<Id>();
    for (Forecast_Metric_Filter__c f : newList) {
      if (f.Forecast_Metric__c == null) {
        f.addError('Forecast Metric is required.');
        continue;
      }
      metricIds.add(f.Forecast_Metric__c);
      if (!newByMetric.containsKey(f.Forecast_Metric__c)) {
        newByMetric.put(
          f.Forecast_Metric__c,
          new List<Forecast_Metric_Filter__c>()
        );
      }
      newByMetric.get(f.Forecast_Metric__c).add(f);
    }
    if (metricIds.isEmpty())
      return;

    // Count existing clauses per metric (excluding the ones being updated in this batch)
    Set<Id> updatingIds = new Set<Id>();
    if (oldMap != null) {
      updatingIds.addAll(oldMap.keySet());
    }
    Map<Id, Integer> existingCountByMetric = new Map<Id, Integer>();
    for (AggregateResult ar : [
      SELECT Forecast_Metric__c metricId, COUNT(Id) cnt
      FROM Forecast_Metric_Filter__c
      WHERE Forecast_Metric__c IN :metricIds AND Id NOT IN :updatingIds
      GROUP BY Forecast_Metric__c
    ]) {
      existingCountByMetric.put(
        (Id) ar.get('metricId'),
        (Integer) ar.get('cnt')
      );
    }

    // Enforce max 5 clauses
    for (Id metricId : newByMetric.keySet()) {
      Integer existing = existingCountByMetric.containsKey(metricId)
        ? existingCountByMetric.get(metricId)
        : 0;
      Integer incoming = newByMetric.get(metricId).size();
      if (existing + incoming > MAX_CLAUSES_PER_METRIC) {
        for (Forecast_Metric_Filter__c f : newByMetric.get(metricId)) {
          f.addError(
            'Cannot exceed ' +
              MAX_CLAUSES_PER_METRIC +
              ' filter clauses per metric (existing: ' +
              existing +
              ', adding: ' +
              incoming +
              ').'
          );
        }
      }
    }

    // Load parent metrics to validate field names against Source_Object__c
    Map<Id, Forecast_Metric__c> metricsMap = new Map<Id, Forecast_Metric__c>(
      [
        SELECT Id, Source_Object__c
        FROM Forecast_Metric__c
        WHERE Id IN :metricIds
      ]
    );

    // Cache field describes per object to avoid repeated Schema calls
    Map<String, Map<String, Schema.SObjectField>> fieldMapByObject = new Map<String, Map<String, Schema.SObjectField>>();

    for (Forecast_Metric_Filter__c f : newList) {
      if (f.Forecast_Metric__c == null)
        continue;
      Forecast_Metric__c parent = metricsMap.get(f.Forecast_Metric__c);
      if (parent == null)
        continue;

      String sourceObj = String.isNotBlank(parent.Source_Object__c)
        ? parent.Source_Object__c
        : 'Opportunity';

      // Validate object is queryable
      Schema.SObjectType sot = Schema.getGlobalDescribe().get(sourceObj);
      if (sot == null) {
        f.addError('Source object "' + sourceObj + '" does not exist.');
        continue;
      }

      // Cache field map for this object
      if (!fieldMapByObject.containsKey(sourceObj)) {
        fieldMapByObject.put(sourceObj, sot.getDescribe().fields.getMap());
      }
      Map<String, Schema.SObjectField> fields = fieldMapByObject.get(sourceObj);

      if (String.isBlank(f.Field_API_Name__c)) {
        f.addError('Field API Name is required.');
      } else if (!fields.containsKey(f.Field_API_Name__c.toLowerCase())) {
        f.addError(
          'Field "' +
            f.Field_API_Name__c +
            '" does not exist on object "' +
            sourceObj +
            '".'
        );
      }

      // Default Validation_Status on insert
      if (
        (oldMap == null || !oldMap.containsKey(f.Id)) &&
        String.isBlank(f.Validation_Status__c)
      ) {
        f.Validation_Status__c = 'Valid';
      }
    }
  }
}
