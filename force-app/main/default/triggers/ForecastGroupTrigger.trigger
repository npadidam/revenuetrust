/**
 * @description Trigger on Forecast_Group__c.
 *              Phase B: Blocks hard delete when active overrides reference the group.
 *              Soft-delete via Is_Active__c = false is preferred.
 */
trigger ForecastGroupTrigger on Forecast_Group__c(before delete) {
  if (!TriggerControlService.isEnabled('ForecastGroupTrigger')) {
    return;
  }

  if (Trigger.isBefore && Trigger.isDelete) {
    ForecastGroupTriggerHandler.handleBeforeDelete(Trigger.old);
  }
}
