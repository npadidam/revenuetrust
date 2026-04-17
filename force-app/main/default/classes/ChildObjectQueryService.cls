/**
 * @description Builds and executes safe aggregate SOQL against arbitrary child objects of
 *              Opportunity. Phase B: rolls up amounts from OpportunityLineItem, QuoteLineItem,
 *              CPQ packaged objects (SBQQ__QuoteLine__c), or custom objects (Product_Bookings__c).
 *
 *              Single point of dynamic SOQL injection prevention. All object/field names
 *              validated against Schema.describe; structured filters built via
 *              StructuredFilterBuilder. Chunks at 500 oppIds to avoid SOQL limits.
 */
public with sharing class ChildObjectQueryService {
  /** Max parent IDs per child query before chunking. */
  @TestVisible
  private static final Integer CHUNK_SIZE = 500;

  /**
   * @description Aggregate a numeric field on a child object grouped by parent Opportunity.
   *
   * @param sourceObject Child object API name (e.g., 'OpportunityLineItem', 'Product_Bookings__c')
   * @param lookupField Field on child that points to Opportunity (e.g., 'OpportunityId')
   * @param amountField Numeric field to aggregate (e.g., 'TotalPrice', 'ACV__c')
   * @param aggregation One of: 'Sum', 'Average', 'Count', 'Max', 'Min'
   * @param oppIds Parent Opportunity IDs
   * @param filters Optional structured filter clauses (Forecast_Metric_Filter__c records)
   * @return Map<OppId, aggregated Decimal>. Empty map if no data, or all-null map if FLS denied.
   * @throws QueryException for unrecoverable validation errors (object/field doesn't exist).
   */
  public static Map<Id, Decimal> aggregate(
    String sourceObject,
    String lookupField,
    String amountField,
    String aggregation,
    Set<Id> oppIds,
    List<Forecast_Metric_Filter__c> filters
  ) {
    Map<Id, Decimal> result = new Map<Id, Decimal>();
    if (oppIds == null || oppIds.isEmpty()) {
      return result;
    }

    // Validate object exists and is queryable
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(sourceObject);
    if (sot == null) {
      throw new QueryException(
        'Source object "' + sourceObject + '" does not exist.'
      );
    }
    Schema.DescribeSObjectResult objDesc = sot.getDescribe();
    if (!objDesc.isQueryable()) {
      throw new QueryException(
        'Source object "' + sourceObject + '" is not queryable.'
      );
    }

    Map<String, Schema.SObjectField> fieldsMap = objDesc.fields.getMap();

    // Validate fields exist
    Schema.SObjectField lookupDesc = fieldsMap.get(lookupField.toLowerCase());
    if (lookupDesc == null) {
      throw new QueryException(
        'Lookup field "' +
          lookupField +
          '" does not exist on ' +
          sourceObject +
          '.'
      );
    }
    Schema.SObjectField amountDesc = fieldsMap.get(amountField.toLowerCase());
    if (amountDesc == null) {
      throw new QueryException(
        'Amount field "' +
          amountField +
          '" does not exist on ' +
          sourceObject +
          '.'
      );
    }

    // FLS: check that current user can read both fields. Return empty map (caller shows N/A).
    if (
      !lookupDesc.getDescribe().isAccessible() ||
      !amountDesc.getDescribe().isAccessible()
    ) {
      return result;
    }

    // Use canonical case-sensitive names from describe
    String safeLookupField = lookupDesc.getDescribe().getName();
    String safeAmountField = amountDesc.getDescribe().getName();

    // Validate aggregation
    String safeAgg = sanitizeAggregation(aggregation);
    if (safeAgg == null) {
      throw new QueryException('Unknown aggregation: ' + aggregation);
    }

    // Build optional WHERE clause from structured filters
    String filterClause = null;
    try {
      filterClause = StructuredFilterBuilder.build(sourceObject, filters);
    } catch (StructuredFilterBuilder.FilterException ex) {
      // If filters are invalid, log and fall through with no filter
      System.debug(
        LoggingLevel.WARN,
        'Filter build failed (skipping filter): ' + ex.getMessage()
      );
      filterClause = null;
    }

    // Chunk parent IDs to avoid SOQL limits when there are many opps
    List<Id> oppIdList = new List<Id>(oppIds);
    Integer total = oppIdList.size();
    for (Integer chunkStart = 0; chunkStart < total; chunkStart += CHUNK_SIZE) {
      Integer chunkEnd = Math.min(chunkStart + CHUNK_SIZE, total);
      // Slice: build a typed Set for binding
      Set<Id> chunkIds = new Set<Id>();
      for (Integer i = chunkStart; i < chunkEnd; i++) {
        chunkIds.add(oppIdList[i]);
      }

      String soql = buildAggregateSoql(
        sourceObject,
        safeLookupField,
        safeAmountField,
        safeAgg,
        filterClause
      );

      for (AggregateResult ar : Database.query(soql)) {
        Id parentId = (Id) ar.get('parentId');
        Object val = ar.get('aggValue');
        if (parentId != null && val != null) {
          result.put(parentId, (Decimal) val);
        }
      }
    }

    return result;
  }

  /**
   * @description Build the parameterized SOQL string. The :chunkIds bind variable
   *              is referenced from the calling scope.
   */
  private static String buildAggregateSoql(
    String sourceObject,
    String lookupField,
    String amountField,
    String aggregation,
    String filterClause
  ) {
    String soql =
      'SELECT ' +
      lookupField +
      ' parentId, ' +
      aggregation +
      '(' +
      amountField +
      ') aggValue ' +
      'FROM ' +
      sourceObject +
      ' ' +
      'WHERE ' +
      lookupField +
      ' IN :chunkIds';
    if (String.isNotBlank(filterClause)) {
      soql += ' AND ' + filterClause;
    }
    soql += ' GROUP BY ' + lookupField;
    return soql;
  }

  /**
   * @description Validate aggregation against allow-list. Returns canonical SOQL function name.
   */
  private static String sanitizeAggregation(String agg) {
    if (String.isBlank(agg)) {
      return 'SUM';
    }
    String normalized = agg.toUpperCase();
    if (normalized == 'SUM' || normalized == 'SUM')
      return 'SUM';
    if (normalized == 'AVERAGE' || normalized == 'AVG')
      return 'AVG';
    if (normalized == 'COUNT')
      return 'COUNT';
    if (normalized == 'MAX')
      return 'MAX';
    if (normalized == 'MIN')
      return 'MIN';
    return null;
  }

  /**
   * @description Discover Opportunity IDs for a custom-field-on-child-object grouping.
   *              Used by ForecastService when a Forecast_Group__c filters by a child object field.
   *
   * @param sourceObject Child object API name
   * @param lookupField Field on child that points to Opportunity
   * @param groupField Field on child to filter by (e.g., 'Booking_Type__c')
   * @param values Comma-separated picklist values for this group
   * @return Set of distinct Opportunity IDs that match
   */
  public static Set<Id> findOpportunitiesByChildField(
    String sourceObject,
    String lookupField,
    String groupField,
    List<String> values
  ) {
    Set<Id> result = new Set<Id>();
    if (values == null || values.isEmpty()) {
      return result;
    }

    Schema.SObjectType sot = Schema.getGlobalDescribe().get(sourceObject);
    if (sot == null) {
      throw new QueryException(
        'Source object "' + sourceObject + '" does not exist.'
      );
    }
    Map<String, Schema.SObjectField> fieldsMap = sot.getDescribe()
      .fields.getMap();

    Schema.SObjectField lookupDesc = fieldsMap.get(lookupField.toLowerCase());
    Schema.SObjectField groupDesc = fieldsMap.get(groupField.toLowerCase());
    if (lookupDesc == null || groupDesc == null) {
      throw new QueryException(
        'Lookup or group field does not exist on ' + sourceObject
      );
    }
    if (
      !lookupDesc.getDescribe().isAccessible() ||
      !groupDesc.getDescribe().isAccessible()
    ) {
      return result;
    }

    String safeLookup = lookupDesc.getDescribe().getName();
    String safeGroup = groupDesc.getDescribe().getName();

    // Bind values list directly. Field aliases only allowed in aggregate
    // queries; this is a row-level query so use the field name directly.
    List<String> safeValues = values;
    String soql =
      'SELECT ' +
      safeLookup +
      ' ' +
      'FROM ' +
      sourceObject +
      ' ' +
      'WHERE ' +
      safeGroup +
      ' IN :safeValues';

    for (SObject so : Database.query(soql)) {
      Object parentId = so.get(safeLookup);
      if (parentId != null) {
        result.add((Id) parentId);
      }
    }
    return result;
  }

  public class QueryException extends Exception {
  }
}
