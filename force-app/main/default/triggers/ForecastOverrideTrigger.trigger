/**
 * @description Trigger on Forecast_Override__c for before/after insert and update.
 *              Uses TriggerControlService to allow admin-disabling via
 *              Trigger_Control__mdt without code deployment.
 *              Delegates all logic to ForecastOverrideTriggerHandler.
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 5, section 11.12
 */
trigger ForecastOverrideTrigger on Forecast_Override__c(
  before insert,
  before update,
  after insert,
  after update
) {
  if (!TriggerControlService.isEnabled('ForecastOverrideTrigger')) {
    return;
  }

  if (Trigger.isBefore && Trigger.isInsert) {
    ForecastOverrideTriggerHandler.handleBeforeInsert(Trigger.new);
  } else if (Trigger.isBefore && Trigger.isUpdate) {
    ForecastOverrideTriggerHandler.handleBeforeUpdate(
      Trigger.new,
      Trigger.oldMap
    );
  } else if (Trigger.isAfter && Trigger.isInsert) {
    ForecastOverrideTriggerHandler.handleAfterInsert(Trigger.new);
  } else if (Trigger.isAfter && Trigger.isUpdate) {
    ForecastOverrideTriggerHandler.handleAfterUpdate(
      Trigger.new,
      Trigger.oldMap
    );
  }
}
