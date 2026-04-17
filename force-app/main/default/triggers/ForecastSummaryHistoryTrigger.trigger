trigger ForecastSummaryHistoryTrigger on Forecast_Summary_History__c(
  before insert
) {
  ForecastSummaryHistoryTriggerHandler.preventDuplicates(Trigger.new);
}
