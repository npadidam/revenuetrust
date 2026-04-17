/**
 * @description Daily batch that validates Forecast_Metric_Filter__c records:
 *              - Field still exists on the parent metric's Source_Object__c
 *              - For picklist operators, value still exists in the current picklist
 *
 *              Sets Validation_Status__c and Validation_Message__c. Admin sees status
 *              indicators on filter rows in admin UI; ChildObjectQueryService skips
 *              clauses flagged Invalid_Field or Invalid_Value at runtime.
 *
 *              Schedule with: System.schedule('REVT Filter Validator', '0 0 2 * * ?',
 *                                              new ForecastMetricFilterValidator());
 */
public with sharing class ForecastMetricFilterValidator implements Database.Batchable<sObject>, Schedulable {
  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Field_API_Name__c,
          Operator__c,
          Value__c,
          Validation_Status__c,
          Validation_Message__c,
          Forecast_Metric__r.Source_Object__c
        FROM Forecast_Metric_Filter__c
      ]
    );
  }

  public void execute(
    Database.BatchableContext bc,
    List<Forecast_Metric_Filter__c> scope
  ) {
    // Cache field maps per object to avoid repeated describes
    Map<String, Map<String, Schema.SObjectField>> fieldMapByObject = new Map<String, Map<String, Schema.SObjectField>>();

    List<Forecast_Metric_Filter__c> toUpdate = new List<Forecast_Metric_Filter__c>();

    for (Forecast_Metric_Filter__c f : scope) {
      String sourceObj = f.Forecast_Metric__r != null
        ? f.Forecast_Metric__r.Source_Object__c
        : null;
      if (String.isBlank(sourceObj)) {
        sourceObj = 'Opportunity';
      }

      String prevStatus = f.Validation_Status__c;
      String prevMessage = f.Validation_Message__c;
      String newStatus = 'Valid';
      String newMessage = null;

      // Validate object exists
      Schema.SObjectType sot = Schema.getGlobalDescribe().get(sourceObj);
      if (sot == null) {
        newStatus = 'Invalid_Field';
        newMessage = 'Source object "' + sourceObj + '" no longer exists.';
      } else {
        // Cache field map
        if (!fieldMapByObject.containsKey(sourceObj)) {
          fieldMapByObject.put(sourceObj, sot.getDescribe().fields.getMap());
        }
        Map<String, Schema.SObjectField> fields = fieldMapByObject.get(
          sourceObj
        );

        if (
          String.isBlank(f.Field_API_Name__c) ||
          !fields.containsKey(f.Field_API_Name__c.toLowerCase())
        ) {
          newStatus = 'Invalid_Field';
          newMessage =
            'Field "' +
            f.Field_API_Name__c +
            '" no longer exists on ' +
            sourceObj +
            '.';
        } else {
          // Check picklist values for picklist operators
          Schema.SObjectField fieldDesc = fields.get(
            f.Field_API_Name__c.toLowerCase()
          );
          Schema.DescribeFieldResult dfr = fieldDesc.getDescribe();
          Boolean isPicklist = (dfr.getType() == Schema.DisplayType.PICKLIST ||
          dfr.getType() == Schema.DisplayType.MULTIPICKLIST);

          if (isPicklist && needsPicklistValidation(f.Operator__c)) {
            Set<String> activeValues = new Set<String>();
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
              if (pe.isActive()) {
                activeValues.add(pe.getValue());
              }
            }
            List<String> badValues = findInvalidPicklistValues(
              f.Value__c,
              f.Operator__c,
              activeValues
            );
            if (!badValues.isEmpty()) {
              newStatus = 'Invalid_Value';
              newMessage =
                'Picklist value(s) no longer exist on ' +
                f.Field_API_Name__c +
                ': ' +
                String.join(badValues, ', ');
            }
          }
        }
      }

      // Only update if status or message actually changed
      if (newStatus != prevStatus || newMessage != prevMessage) {
        f.Validation_Status__c = newStatus;
        f.Validation_Message__c = newMessage != null
          ? newMessage.left(255)
          : null;
        toUpdate.add(f);
      }
    }

    if (!toUpdate.isEmpty()) {
      // Use database.update with allOrNone=false to tolerate edge cases
      Database.update(toUpdate, false);
    }
  }

  public void finish(Database.BatchableContext bc) {
    // No-op. Could send admin email digest of invalid filters in future.
  }

  /**
   * @description Schedulable entry point. Re-launch the batch.
   */
  public void execute(SchedulableContext sc) {
    Database.executeBatch(new ForecastMetricFilterValidator(), 200);
  }

  private static Boolean needsPicklistValidation(String op) {
    return op == 'EQUALS' ||
      op == 'NOT_EQUALS' ||
      op == 'IN' ||
      op == 'NOT_IN' ||
      op == 'INCLUDES' ||
      op == 'EXCLUDES';
  }

  /**
   * @description Return any picklist values in the filter that no longer exist on the field.
   */
  private static List<String> findInvalidPicklistValues(
    String rawValue,
    String op,
    Set<String> activeValues
  ) {
    List<String> bad = new List<String>();
    if (String.isBlank(rawValue)) {
      return bad;
    }
    Boolean isMultiValue = (op == 'IN' ||
    op == 'NOT_IN' ||
    op == 'INCLUDES' ||
    op == 'EXCLUDES');
    if (isMultiValue) {
      try {
        List<String> values = (List<String>) JSON.deserialize(
          rawValue,
          List<String>.class
        );
        for (String v : values) {
          if (!activeValues.contains(v)) {
            bad.add(v);
          }
        }
      } catch (Exception ex) {
        bad.add('(invalid JSON)');
      }
    } else {
      if (!activeValues.contains(rawValue)) {
        bad.add(rawValue);
      }
    }
    return bad;
  }
}
