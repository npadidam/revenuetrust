/**
 * @description Fires on Forecast_Period__c updates to detect period freeze
 *              and reopen transitions. Calls PeriodFreezeHandler directly on
 *              freeze, and publishes PERIOD_REOPENED platform events on unfreeze.
 */
trigger ForecastPeriodTrigger on Forecast_Period__c (after update) {
    ForecastPeriodTriggerHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
