/**
 * @description Tests for StructuredFilterBuilder \u2014 the converter from
 *              Forecast_Metric_Filter__c records to safe SOQL fragments.
 *              Phase B.
 */
@IsTest
private class StructuredFilterBuilderTest {
  @IsTest
  static void emptyList_returnsNull() {
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>()
    );
    Test.stopTest();
    System.assertEquals(null, result, 'Empty list should return null');
  }

  @IsTest
  static void scalarStringEquals_quotesAndEscapes() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'StageName',
      Operator__c = 'EQUALS',
      Value__c = 'Won O\'Brien', // single quote inside single-quoted string
      Sort_Order__c = 1
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ f }
    );
    Test.stopTest();
    // Resulting SOQL fragment: StageName = 'Won O\'Brien'
    System.assert(
      result.contains('StageName = \'Won O\\\'Brien\''),
      'Should escape single quotes: ' + result
    );
  }

  @IsTest
  static void multiValueIN_buildsParenList() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'StageName',
      Operator__c = 'IN',
      Value__c = '["Prospecting","Qualification"]',
      Sort_Order__c = 1
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ f }
    );
    Test.stopTest();
    System.assert(
      result.contains('StageName IN (\'Prospecting\', \'Qualification\')'),
      'Should build IN clause: ' + result
    );
  }

  @IsTest
  static void numericGreaterThan_noQuotes() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'Amount',
      Operator__c = 'GREATER_THAN',
      Value__c = '100000',
      Sort_Order__c = 1
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ f }
    );
    Test.stopTest();
    System.assert(
      result.contains('Amount > 100000'),
      'Numeric value should not be quoted: ' + result
    );
  }

  @IsTest
  static void dateLiteralToken_noQuotes() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'CloseDate',
      Operator__c = 'EQUALS',
      Value__c = 'TODAY',
      Sort_Order__c = 1
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ f }
    );
    Test.stopTest();
    System.assert(
      result.contains('CloseDate = TODAY'),
      'Date literal should be unquoted: ' + result
    );
  }

  @IsTest
  static void parameterizedDateLiteral_passes() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'CloseDate',
      Operator__c = 'EQUALS',
      Value__c = 'LAST_N_DAYS:30',
      Sort_Order__c = 1
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ f }
    );
    Test.stopTest();
    System.assert(
      result.contains('LAST_N_DAYS:30'),
      'Parameterized date literal should pass: ' + result
    );
  }

  @IsTest
  static void invalidNumeric_throws() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'Amount',
      Operator__c = 'GREATER_THAN',
      Value__c = 'not-a-number',
      Sort_Order__c = 1
    );
    Test.startTest();
    try {
      StructuredFilterBuilder.build(
        'Opportunity',
        new List<Forecast_Metric_Filter__c>{ f }
      );
      System.assert(false, 'Should have thrown');
    } catch (StructuredFilterBuilder.FilterException e) {
      System.assert(
        e.getMessage().contains('Invalid numeric'),
        'Error should mention invalid numeric: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void invalidObject_throws() {
    Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'Foo',
      Operator__c = 'EQUALS',
      Value__c = 'X',
      Sort_Order__c = 1
    );
    Test.startTest();
    try {
      StructuredFilterBuilder.build(
        'TotallyFakeObject__c',
        new List<Forecast_Metric_Filter__c>{ f }
      );
      System.assert(false, 'Should have thrown');
    } catch (StructuredFilterBuilder.FilterException e) {
      System.assert(
        e.getMessage().contains('does not exist'),
        'Error should mention object missing: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void invalidValidationStatus_skipsClause() {
    Forecast_Metric_Filter__c valid = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'Amount',
      Operator__c = 'GREATER_THAN',
      Value__c = '100',
      Validation_Status__c = 'Valid',
      Sort_Order__c = 1
    );
    Forecast_Metric_Filter__c invalid = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'StageName',
      Operator__c = 'EQUALS',
      Value__c = 'Won',
      Validation_Status__c = 'Invalid_Field',
      Logical_Operator__c = 'AND',
      Sort_Order__c = 2
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ valid, invalid }
    );
    Test.stopTest();
    System.assert(
      result.contains('Amount > 100'),
      'Valid clause should be present: ' + result
    );
    System.assert(
      !result.contains('StageName'),
      'Invalid_Field clause should be skipped: ' + result
    );
  }

  @IsTest
  static void andOrChain_buildsCorrectly() {
    Forecast_Metric_Filter__c c1 = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'Amount',
      Operator__c = 'GREATER_THAN',
      Value__c = '100',
      Logical_Operator__c = 'AND',
      Sort_Order__c = 1
    );
    Forecast_Metric_Filter__c c2 = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'StageName',
      Operator__c = 'EQUALS',
      Value__c = 'Won',
      Logical_Operator__c = 'OR',
      Sort_Order__c = 2
    );
    Forecast_Metric_Filter__c c3 = new Forecast_Metric_Filter__c(
      Field_API_Name__c = 'StageName',
      Operator__c = 'EQUALS',
      Value__c = 'Closed Won',
      Sort_Order__c = 3
    );
    Test.startTest();
    String result = StructuredFilterBuilder.build(
      'Opportunity',
      new List<Forecast_Metric_Filter__c>{ c1, c2, c3 }
    );
    Test.stopTest();
    System.assert(
      result.contains('Amount > 100 AND'),
      'First chain operator AND should appear: ' + result
    );
    System.assert(
      result.contains('StageName = \'Won\' OR'),
      'Second chain operator OR should appear: ' + result
    );
  }
}
