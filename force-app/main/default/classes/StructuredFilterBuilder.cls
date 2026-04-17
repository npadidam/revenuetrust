/**
 * @description Converts Forecast_Metric_Filter__c records into safe SOQL WHERE clauses.
 *              Phase B: Replaces freeform filter text. NO raw user input ever concatenates
 *              into SOQL. All field names validated against Schema.describe.
 *
 *              Value__c serialization contract (from spec):
 *              - Scalar operators (=, !=, >, <, >=, <=, LIKE, NOT LIKE):
 *                  stored as stringified API value (e.g., "Active", "100000", "true")
 *              - Multi-value operators (IN, NOT IN, INCLUDES, EXCLUDES):
 *                  stored as JSON array of API values
 *              - Date literals: stored as canonical tokens (TODAY, LAST_N_DAYS:30, etc.)
 *              - Picklist values: API names, never labels
 *              - Booleans: "true" / "false" (lowercase)
 *              - Numbers: plain string numerics
 */
public with sharing class StructuredFilterBuilder {
  // Date literal tokens that SOQL accepts unquoted (subset, expanded as needed)
  private static final Set<String> DATE_LITERALS = new Set<String>{
    'YESTERDAY',
    'TODAY',
    'TOMORROW',
    'LAST_WEEK',
    'THIS_WEEK',
    'NEXT_WEEK',
    'LAST_MONTH',
    'THIS_MONTH',
    'NEXT_MONTH',
    'LAST_90_DAYS',
    'NEXT_90_DAYS',
    'THIS_QUARTER',
    'LAST_QUARTER',
    'NEXT_QUARTER',
    'THIS_YEAR',
    'LAST_YEAR',
    'NEXT_YEAR',
    'THIS_FISCAL_QUARTER',
    'LAST_FISCAL_QUARTER',
    'NEXT_FISCAL_QUARTER',
    'THIS_FISCAL_YEAR',
    'LAST_FISCAL_YEAR',
    'NEXT_FISCAL_YEAR'
  };
  // Parameterized date literals (token followed by :N)
  private static final Set<String> PARAMETERIZED_DATE_LITERALS = new Set<String>{
    'LAST_N_DAYS',
    'NEXT_N_DAYS',
    'NEXT_N_WEEKS',
    'LAST_N_WEEKS',
    'NEXT_N_MONTHS',
    'LAST_N_MONTHS',
    'NEXT_N_QUARTERS',
    'LAST_N_QUARTERS',
    'NEXT_N_YEARS',
    'LAST_N_YEARS',
    'NEXT_N_FISCAL_QUARTERS',
    'LAST_N_FISCAL_QUARTERS',
    'NEXT_N_FISCAL_YEARS',
    'LAST_N_FISCAL_YEARS'
  };

  /**
   * @description Build a sanitized SOQL WHERE clause fragment from a list of
   *              Forecast_Metric_Filter__c records. Returns null if list is empty.
   *              Caller is responsible for prepending " AND " or " WHERE " as needed.
   *
   * @param sourceObject The API name of the object the filter applies to (validated)
   * @param filters Filter records sorted by Sort_Order__c
   * @return SOQL fragment like "(Status__c = 'Active' AND Region__c IN ('US','EU'))"
   *         or null when filters list is empty.
   */
  public static String build(
    String sourceObject,
    List<Forecast_Metric_Filter__c> filters
  ) {
    if (filters == null || filters.isEmpty()) {
      return null;
    }

    // Validate object exists
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(sourceObject);
    if (sot == null) {
      throw new FilterException(
        'Source object "' + sourceObject + '" does not exist.'
      );
    }
    Map<String, Schema.SObjectField> fieldsMap = sot.getDescribe()
      .fields.getMap();

    List<String> fragments = new List<String>();
    for (Integer i = 0; i < filters.size(); i++) {
      Forecast_Metric_Filter__c f = filters[i];
      // Skip clauses flagged invalid by validator batch
      if (
        f.Validation_Status__c == 'Invalid_Field' ||
        f.Validation_Status__c == 'Invalid_Value'
      ) {
        continue;
      }
      String clause = buildClause(fieldsMap, f);
      if (String.isBlank(clause)) {
        continue;
      }
      fragments.add(clause);
      // Append logical operator unless this is the last clause
      if (i < filters.size() - 1) {
        String logical = String.isNotBlank(f.Logical_Operator__c)
          ? f.Logical_Operator__c
          : 'AND';
        fragments.add(logical);
      }
    }

    if (fragments.isEmpty()) {
      return null;
    }
    return '(' + String.join(fragments, ' ') + ')';
  }

  /**
   * @description Build a single clause: "FieldName Operator Value".
   */
  private static String buildClause(
    Map<String, Schema.SObjectField> fieldsMap,
    Forecast_Metric_Filter__c f
  ) {
    if (String.isBlank(f.Field_API_Name__c) || String.isBlank(f.Operator__c)) {
      return null;
    }
    String fieldKey = f.Field_API_Name__c.toLowerCase();
    Schema.SObjectField fieldDesc = fieldsMap.get(fieldKey);
    if (fieldDesc == null) {
      throw new FilterException(
        'Field "' + f.Field_API_Name__c + '" does not exist.'
      );
    }
    // Use the field's actual case-sensitive API name
    String fieldName = fieldDesc.getDescribe().getName();
    Schema.DisplayType type = fieldDesc.getDescribe().getType();

    String op = mapOperatorToSoql(f.Operator__c);
    if (op == null) {
      throw new FilterException('Unknown operator: ' + f.Operator__c);
    }

    String valueExpr = buildValueExpression(
      f.Operator__c,
      type,
      f.Value__c,
      fieldName
    );
    return fieldName + ' ' + op + ' ' + valueExpr;
  }

  /**
   * @description Convert internal operator picklist values to SOQL operators.
   */
  private static String mapOperatorToSoql(String op) {
    if (op == 'EQUALS')
      return '=';
    if (op == 'NOT_EQUALS')
      return '!=';
    if (op == 'GREATER_THAN')
      return '>';
    if (op == 'LESS_THAN')
      return '<';
    if (op == 'GREATER_OR_EQUAL')
      return '>=';
    if (op == 'LESS_OR_EQUAL')
      return '<=';
    if (op == 'IN')
      return 'IN';
    if (op == 'NOT_IN')
      return 'NOT IN';
    if (op == 'LIKE')
      return 'LIKE';
    if (op == 'NOT_LIKE')
      return 'NOT LIKE';
    if (op == 'INCLUDES')
      return 'INCLUDES';
    if (op == 'EXCLUDES')
      return 'EXCLUDES';
    return null;
  }

  /**
   * @description Build the value expression for a SOQL clause based on operator and field type.
   *              Handles JSON array deserialization for multi-value operators, date literals,
   *              and proper quoting/escaping for scalar values.
   */
  private static String buildValueExpression(
    String op,
    Schema.DisplayType type,
    String rawValue,
    String fieldName
  ) {
    if (rawValue == null) {
      rawValue = '';
    }

    Boolean isMultiValue = (op == 'IN' ||
    op == 'NOT_IN' ||
    op == 'INCLUDES' ||
    op == 'EXCLUDES');

    if (isMultiValue) {
      List<String> values;
      try {
        values = (List<String>) JSON.deserialize(rawValue, List<String>.class);
      } catch (Exception ex) {
        throw new FilterException(
          'Multi-value operator requires JSON array in Value field: ' + rawValue
        );
      }
      if (values == null || values.isEmpty()) {
        throw new FilterException(
          'Multi-value operator value cannot be empty.'
        );
      }
      List<String> escaped = new List<String>();
      for (String v : values) {
        escaped.add(formatScalarValue(type, v));
      }
      return '(' + String.join(escaped, ', ') + ')';
    }

    // Scalar
    return formatScalarValue(type, rawValue);
  }

  /**
   * @description Format a single value per its field type.
   *              - Strings/Picklists/References/IDs: single-quoted with escapeSingleQuotes
   *              - Numbers: plain (no quotes)
   *              - Booleans: TRUE/FALSE (no quotes)
   *              - Dates/DateTimes: date literal token (no quotes) OR ISO 8601 (no quotes)
   */
  private static String formatScalarValue(
    Schema.DisplayType type,
    String rawValue
  ) {
    if (rawValue == null) {
      return 'null';
    }

    if (type == Schema.DisplayType.BOOLEAN) {
      return rawValue.toLowerCase() == 'true' ? 'TRUE' : 'FALSE';
    }
    if (
      type == Schema.DisplayType.INTEGER ||
      type == Schema.DisplayType.LONG ||
      type == Schema.DisplayType.DOUBLE ||
      type == Schema.DisplayType.CURRENCY ||
      type == Schema.DisplayType.PERCENT
    ) {
      // Validate numeric — strict
      try {
        Decimal d = Decimal.valueOf(rawValue.trim());
        return String.valueOf(d);
      } catch (Exception ex) {
        throw new FilterException('Invalid numeric value: ' + rawValue);
      }
    }
    if (
      type == Schema.DisplayType.DATE ||
      type == Schema.DisplayType.DATETIME
    ) {
      String trimmed = rawValue.trim().toUpperCase();
      // Check date literal tokens
      if (DATE_LITERALS.contains(trimmed)) {
        return trimmed;
      }
      // Check parameterized literal token (e.g., LAST_N_DAYS:30)
      if (trimmed.contains(':')) {
        String tokenPart = trimmed.substringBefore(':');
        String numPart = trimmed.substringAfter(':');
        if (
          PARAMETERIZED_DATE_LITERALS.contains(tokenPart) && numPart.isNumeric()
        ) {
          return tokenPart + ':' + numPart;
        }
      }
      // ISO 8601 date/datetime — passes through unquoted in SOQL
      // Validate format (basic: YYYY-MM-DD or full ISO)
      if (
        Pattern.matches(
          '^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}:\\d{2}(\\.\\d{3})?Z?)?$',
          rawValue.trim()
        )
      ) {
        return rawValue.trim();
      }
      throw new FilterException('Invalid date value: ' + rawValue);
    }

    // Default: string-like (Text, Picklist, MultiPicklist, Email, Phone, URL, ID, Reference)
    return '\'' + String.escapeSingleQuotes(rawValue) + '\'';
  }

  public class FilterException extends Exception {
  }
}
