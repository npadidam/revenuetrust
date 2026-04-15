/**
 * @description Thin trigger handler for Forecast_Override__c.
 *              Delegates all logic to dedicated service classes per spec section 11.12.
 *              Does NOT contain business logic -- only routing.
 *
 *              Delegation map:
 *              - Before Insert  -> ForecastValidationService
 *              - Before Update  -> ForecastValidationService, ForecastDivergenceService
 *              - After Insert   -> ForecastChangeEventService, ForecastParticipantStatusService
 *              - After Update   -> ForecastChangeEventService, ForecastParticipantStatusService
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 5, section 11.12
 */
public with sharing class ForecastOverrideTriggerHandler {
  /**
   * @description Handle before insert: validate new overrides.
   * @param newList Trigger.new
   */
  public static void handleBeforeInsert(List<Forecast_Override__c> newList) {
    ForecastValidationService.validateOverrides(newList, null);
  }

  /**
   * @description Handle before update: validate changes and detect CRM divergence.
   * @param newList Trigger.new
   * @param oldMap Trigger.oldMap
   */
  public static void handleBeforeUpdate(
    List<Forecast_Override__c> newList,
    Map<Id, Forecast_Override__c> oldMap
  ) {
    ForecastValidationService.validateOverrides(newList, oldMap);
    ForecastDivergenceService.detectDivergence(newList, oldMap);
  }

  /**
   * @description Handle after insert: create change events and update participant status.
   * @param newList Trigger.new
   */
  public static void handleAfterInsert(List<Forecast_Override__c> newList) {
    ForecastChangeEventService.createEvents(newList, null);
    ForecastParticipantStatusService.updateStatus(newList);
  }

  /**
   * @description Handle after update: create change events and update participant status.
   * @param newList Trigger.new
   * @param oldMap Trigger.oldMap
   */
  public static void handleAfterUpdate(
    List<Forecast_Override__c> newList,
    Map<Id, Forecast_Override__c> oldMap
  ) {
    ForecastChangeEventService.createEvents(newList, oldMap);
    ForecastParticipantStatusService.updateStatus(newList);
    afterUpdateGovernanceEval(newList, oldMap);
  }

  /**
   * @description Publish Governance_Eval_Event__e asynchronously for override changes.
   *              Non-blocking: governance evaluation does not prevent the save.
   *              Per spec §11.6 and §11.12.
   * @param newList Trigger.new
   * @param oldMap Trigger.oldMap
   */
  private static void afterUpdateGovernanceEval(
    List<Forecast_Override__c> newList,
    Map<Id, Forecast_Override__c> oldMap
  ) {
    if (!TriggerControlService.isEnabled('GovernanceEvaluation')) {
      return;
    }

    List<Governance_Eval_Event__e> events = new List<Governance_Eval_Event__e>();
    for (Forecast_Override__c ov : newList) {
      Forecast_Override__c oldOv = oldMap.get(ov.Id);
      // Only publish if meaningful fields changed
      if (
        ov.Forecast_Category__c != oldOv.Forecast_Category__c ||
        ov.Metric_1_Value__c != oldOv.Metric_1_Value__c ||
        ov.Status__c != oldOv.Status__c
      ) {
        Governance_Eval_Event__e evt = new Governance_Eval_Event__e();
        evt.Override_Id__c = ov.Id;
        evt.Action_Type__c = 'FORECAST_OVERRIDE_CHANGED';
        events.add(evt);
      }
    }

    if (!events.isEmpty()) {
      try {
        EventBus.publish(events);
      } catch (Exception e) {
        System.debug(
          LoggingLevel.WARN,
          'ForecastOverrideTriggerHandler: Governance eval event publish failed: ' +
          e.getMessage()
        );
      }
    }
  }
}
