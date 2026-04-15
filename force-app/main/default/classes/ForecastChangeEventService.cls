/**
 * @description Creates consolidated Forecast_Change_Event__c records to provide
 *              a complete audit trail for all forecast override changes.
 *              One event per override per save (multiple field changes in one save
 *              produce one consolidated event, per spec section 12.5).
 *
 *              Detects: Category_Change, Metric_Change, Close_Date_Change,
 *              Submit, Freeze transitions.
 *
 *              Called by: ForecastOverrideTriggerHandler (after insert/update)
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 5, section 11.12
 */
public with sharing class ForecastChangeEventService {
  /**
   * @description Create change events for new or modified overrides.
   * @param newList The Trigger.new list
   * @param oldMap The Trigger.oldMap (null on insert)
   */
  public static void createEvents(
    List<Forecast_Override__c> newList,
    Map<Id, Forecast_Override__c> oldMap
  ) {
    if (newList == null || newList.isEmpty()) {
      return;
    }

    List<Forecast_Change_Event__c> eventsToInsert = new List<Forecast_Change_Event__c>();

    // Load period end dates for Days_To_Period_End calculation
    Set<Id> periodIds = new Set<Id>();
    for (Forecast_Override__c ov : newList) {
      if (ov.Forecast_Period__c != null) {
        periodIds.add(ov.Forecast_Period__c);
      }
    }
    Map<Id, Forecast_Period__c> periodMap = new Map<Id, Forecast_Period__c>(
      [
        SELECT Id, End_Date__c, Start_Date__c
        FROM Forecast_Period__c
        WHERE Id IN :periodIds
      ]
    );

    for (Forecast_Override__c ov : newList) {
      Forecast_Override__c oldOv = (oldMap != null && oldMap.containsKey(ov.Id))
        ? oldMap.get(ov.Id)
        : null;

      // On insert, always create an event
      // On update, only if something meaningful changed
      if (oldOv != null && !hasRelevantChanges(ov, oldOv)) {
        continue;
      }

      Forecast_Change_Event__c evt = new Forecast_Change_Event__c();
      evt.Forecast_Override__c = ov.Id;
      evt.Forecast_Period__c = ov.Forecast_Period__c;
      evt.Opportunity__c = ov.Opportunity__c;
      evt.Participant__c = ov.User__c;
      evt.Hierarchy_Level__c = ov.Hierarchy_Level__c;
      evt.Changed_By__c = UserInfo.getUserId();
      evt.Changed_On__c = Datetime.now();

      // Determine change type(s)
      List<String> changeTypes = new List<String>();

      if (oldOv == null) {
        // Insert: initial creation
        changeTypes.add('Override_Created');
      } else {
        // Status transitions
        if (ov.Status__c != oldOv.Status__c) {
          if (ov.Status__c == 'Submitted') {
            changeTypes.add('Submit');
          } else if (ov.Status__c == 'Frozen') {
            changeTypes.add('Freeze');
          }
        }

        // Category change
        if (ov.Forecast_Category__c != oldOv.Forecast_Category__c) {
          changeTypes.add('Category_Change');
        }

        // Close date change
        if (ov.Close_Date_Override__c != oldOv.Close_Date_Override__c) {
          changeTypes.add('Close_Date_Change');
        }

        // Metric changes
        if (hasMetricChanges(ov, oldOv)) {
          changeTypes.add('Metric_Change');
        }
      }

      evt.Change_Type__c = String.join(changeTypes, ';');

      // Days to period end
      if (
        ov.Forecast_Period__c != null &&
        periodMap.containsKey(ov.Forecast_Period__c)
      ) {
        Forecast_Period__c period = periodMap.get(ov.Forecast_Period__c);
        if (period.End_Date__c != null) {
          evt.Days_To_Period_End__c = Date.today()
            .daysBetween(period.End_Date__c);
        }
      }

      // Crossed period boundary: close date moved to a different period
      if (
        oldOv != null &&
        ov.Close_Date_Override__c != null &&
        oldOv.Close_Date_Override__c != null &&
        ov.Forecast_Period__c != null &&
        periodMap.containsKey(ov.Forecast_Period__c)
      ) {
        Forecast_Period__c period = periodMap.get(ov.Forecast_Period__c);
        Boolean oldInPeriod = isDateInPeriod(
          oldOv.Close_Date_Override__c,
          period
        );
        Boolean newInPeriod = isDateInPeriod(ov.Close_Date_Override__c, period);
        evt.Crossed_Period_Boundary__c = (oldInPeriod != newInPeriod);
      }

      // Negative movement: primary metric decreased
      if (
        oldOv != null &&
        ov.Metric_1_Value__c != null &&
        oldOv.Metric_1_Value__c != null
      ) {
        evt.Is_Negative_Movement__c = (ov.Metric_1_Value__c <
        oldOv.Metric_1_Value__c);
      }

      // Metric changes JSON: capture deltas for each metric that changed
      if (oldOv != null) {
        evt.Metric_Changes__c = buildMetricChangesJson(ov, oldOv);
      }

      // Old/new category
      if (oldOv != null) {
        evt.Old_Category__c = oldOv.Forecast_Category__c;
      }
      evt.New_Category__c = ov.Forecast_Category__c;

      eventsToInsert.add(evt);
    }

    if (!eventsToInsert.isEmpty()) {
      insert eventsToInsert;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────

  /**
   * @description Check if any relevant fields changed between old and new override.
   */
  private static Boolean hasRelevantChanges(
    Forecast_Override__c newOv,
    Forecast_Override__c oldOv
  ) {
    return newOv.Forecast_Category__c != oldOv.Forecast_Category__c ||
      newOv.Status__c != oldOv.Status__c ||
      newOv.Close_Date_Override__c != oldOv.Close_Date_Override__c ||
      newOv.Comment__c != oldOv.Comment__c ||
      hasMetricChanges(newOv, oldOv);
  }

  /**
   * @description Check if any metric values changed.
   */
  private static Boolean hasMetricChanges(
    Forecast_Override__c newOv,
    Forecast_Override__c oldOv
  ) {
    return newOv.Metric_1_Value__c != oldOv.Metric_1_Value__c ||
      newOv.Metric_2_Value__c != oldOv.Metric_2_Value__c ||
      newOv.Metric_3_Value__c != oldOv.Metric_3_Value__c ||
      newOv.Metric_4_Value__c != oldOv.Metric_4_Value__c ||
      newOv.Metric_5_Value__c != oldOv.Metric_5_Value__c ||
      newOv.Metric_6_Value__c != oldOv.Metric_6_Value__c;
  }

  /**
   * @description Build a JSON string with metric deltas.
   *              Example: {"Metric_1":{"old":100000,"new":120000},"Metric_3":{"old":50,"new":75}}
   */
  private static String buildMetricChangesJson(
    Forecast_Override__c newOv,
    Forecast_Override__c oldOv
  ) {
    Map<String, Map<String, Decimal>> changes = new Map<String, Map<String, Decimal>>();

    addMetricDelta(
      changes,
      'Metric_1',
      oldOv.Metric_1_Value__c,
      newOv.Metric_1_Value__c
    );
    addMetricDelta(
      changes,
      'Metric_2',
      oldOv.Metric_2_Value__c,
      newOv.Metric_2_Value__c
    );
    addMetricDelta(
      changes,
      'Metric_3',
      oldOv.Metric_3_Value__c,
      newOv.Metric_3_Value__c
    );
    addMetricDelta(
      changes,
      'Metric_4',
      oldOv.Metric_4_Value__c,
      newOv.Metric_4_Value__c
    );
    addMetricDelta(
      changes,
      'Metric_5',
      oldOv.Metric_5_Value__c,
      newOv.Metric_5_Value__c
    );
    addMetricDelta(
      changes,
      'Metric_6',
      oldOv.Metric_6_Value__c,
      newOv.Metric_6_Value__c
    );

    return changes.isEmpty() ? null : JSON.serialize(changes);
  }

  private static void addMetricDelta(
    Map<String, Map<String, Decimal>> changes,
    String metricName,
    Decimal oldVal,
    Decimal newVal
  ) {
    if (oldVal != newVal) {
      Map<String, Decimal> delta = new Map<String, Decimal>();
      delta.put('old', oldVal != null ? oldVal : 0);
      delta.put('new', newVal != null ? newVal : 0);
      changes.put(metricName, delta);
    }
  }

  private static Boolean isDateInPeriod(Date d, Forecast_Period__c period) {
    if (
      d == null ||
      period.Start_Date__c == null ||
      period.End_Date__c == null
    ) {
      return false;
    }
    return d >= period.Start_Date__c && d <= period.End_Date__c;
  }
}
