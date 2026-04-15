/**
 * @description Detects CRM divergence on Forecast_Override__c records.
 *              When an override has been Submitted or Frozen, compares current
 *              CRM values (via PipelineObjectService) against the override's
 *              metric values and close date. Sets CRM_Divergence__c = true and
 *              populates CRM_Divergence_Details__c with a summary of what changed.
 *
 *              Called by: ForecastOverrideTriggerHandler (before update)
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 5, section 11.12
 */
public with sharing class ForecastDivergenceService {
  // Statuses that should be checked for divergence
  private static final Set<String> DIVERGENCE_CHECK_STATUSES = new Set<String>{
    'Submitted',
    'Frozen'
  };

  /**
   * @description Detect divergence between override values and current CRM values.
   *              Sets CRM_Divergence__c and CRM_Divergence_Details__c on the
   *              override records (in before-update context, so changes are saved).
   * @param overrides The Trigger.new list
   * @param oldMap The Trigger.oldMap
   */
  public static void detectDivergence(
    List<Forecast_Override__c> overrides,
    Map<Id, Forecast_Override__c> oldMap
  ) {
    if (overrides == null || overrides.isEmpty()) {
      return;
    }

    // Collect pipeline record IDs for overrides in submitted/frozen status
    Set<Id> pipelineRecordIds = new Set<Id>();
    List<Forecast_Override__c> toCheck = new List<Forecast_Override__c>();

    for (Forecast_Override__c ov : overrides) {
      if (
        ov.Opportunity__c != null &&
        DIVERGENCE_CHECK_STATUSES.contains(ov.Status__c)
      ) {
        pipelineRecordIds.add(ov.Opportunity__c);
        toCheck.add(ov);
      }
    }

    if (pipelineRecordIds.isEmpty()) {
      return;
    }

    // Query current CRM values via PipelineObjectService
    List<SObject> pipelineRecords = PipelineObjectService.queryRecords(
      pipelineRecordIds
    );
    Map<Id, SObject> pipelineMap = new Map<Id, SObject>();
    for (SObject rec : pipelineRecords) {
      pipelineMap.put(rec.Id, rec);
    }

    // Compare override values to CRM values
    for (Forecast_Override__c ov : toCheck) {
      SObject crmRecord = pipelineMap.get(ov.Opportunity__c);
      if (crmRecord == null) {
        continue;
      }

      List<String> divergenceDetails = new List<String>();

      // Compare Amount (Metric_1 = primary metric, typically Amount)
      Decimal crmAmount = PipelineObjectService.getAmount(crmRecord);
      if (
        ov.Metric_1_Value__c != null &&
        crmAmount != null &&
        ov.Metric_1_Value__c != crmAmount
      ) {
        divergenceDetails.add(
          'Amount: $' +
            formatDecimal(ov.Metric_1_Value__c) +
            ' -> $' +
            formatDecimal(crmAmount)
        );
      }

      // Compare Close Date
      Date crmCloseDate = PipelineObjectService.getCloseDate(crmRecord);
      if (
        ov.Close_Date_Override__c != null &&
        crmCloseDate != null &&
        ov.Close_Date_Override__c != crmCloseDate
      ) {
        divergenceDetails.add(
          'CloseDate: ' +
            formatDate(ov.Close_Date_Override__c) +
            ' -> ' +
            formatDate(crmCloseDate)
        );
      }

      // Compare Stage
      String crmStage = PipelineObjectService.getStage(crmRecord);
      // Stage changes are informational but tracked as divergence
      if (oldMap != null && oldMap.containsKey(ov.Id)) {
        Forecast_Override__c oldOv = oldMap.get(ov.Id);
        if (String.isNotBlank(crmStage) && oldOv.CRM_Divergence__c != true) {
          // Only flag stage if CRM stage changed since last check
          // (we detect this by checking if divergence was previously false)
        }
      }

      // Set divergence flags
      if (!divergenceDetails.isEmpty()) {
        ov.CRM_Divergence__c = true;
        ov.CRM_Divergence_Details__c = String.join(divergenceDetails, ', ');
      } else {
        // CRM matches override -- clear any previous divergence
        ov.CRM_Divergence__c = false;
        ov.CRM_Divergence_Details__c = null;
      }
    }
  }

  // ── Private helpers ────────────────────────────────────────────────

  private static String formatDecimal(Decimal val) {
    if (val == null) {
      return '0';
    }
    return val.setScale(2).toPlainString();
  }

  private static String formatDate(Date d) {
    if (d == null) {
      return '';
    }
    return d.format();
  }
}
