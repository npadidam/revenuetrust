trigger ForecastConfigCadenceTrigger on Forecast_Configuration__c(
  before insert,
  before update
) {
  CadenceValidationTriggerHandler.validate(Trigger.new);
}
