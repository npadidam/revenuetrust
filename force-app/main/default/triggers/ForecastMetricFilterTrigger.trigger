/**
 * @description Trigger on Forecast_Metric_Filter__c.
 *              Phase B: Enforces max 5 clauses per metric and validates Field_API_Name__c
 *              against Schema describe at save time.
 */
trigger ForecastMetricFilterTrigger on Forecast_Metric_Filter__c(
  before insert,
  before update
) {
  if (!TriggerControlService.isEnabled('ForecastMetricFilterTrigger')) {
    return;
  }

  if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
    ForecastMetricFilterTriggerHandler.handleBeforeUpsert(
      Trigger.new,
      Trigger.oldMap
    );
  }
}
