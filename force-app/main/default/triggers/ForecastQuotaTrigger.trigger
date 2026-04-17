/**
 * @description Trigger on Forecast_Quota__c — enforces User + Period uniqueness.
 *              Uses TriggerControlService for admin-disabling via Trigger_Control__mdt.
 */
trigger ForecastQuotaTrigger on Forecast_Quota__c(
  before insert,
  before update
) {
  if (!TriggerControlService.isEnabled('ForecastQuotaTrigger')) {
    return;
  }

  if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
    ForecastQuotaTriggerHandler.handleBeforeUpsert(Trigger.new, Trigger.oldMap);
  }
}
