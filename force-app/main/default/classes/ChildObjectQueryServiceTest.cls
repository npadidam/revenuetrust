/**
 * @description Tests for ChildObjectQueryService \u2014 sanitization, FLS, chunking, and
 *              the actual aggregate against OpportunityLineItem (a standard child
 *              object guaranteed to exist in any org).
 *              Phase B.
 */
@IsTest
private class ChildObjectQueryServiceTest {
  @IsTest
  static void emptyOppIds_returnsEmpty() {
    Test.startTest();
    Map<Id, Decimal> result = ChildObjectQueryService.aggregate(
      'OpportunityLineItem',
      'OpportunityId',
      'TotalPrice',
      'Sum',
      new Set<Id>(),
      null
    );
    Test.stopTest();
    System.assertEquals(
      0,
      result.size(),
      'Empty input should return empty map'
    );
  }

  @IsTest
  static void invalidObject_throws() {
    Set<Id> oppIds = new Set<Id>{ UserInfo.getUserId() }; // any 18-char Id
    Test.startTest();
    try {
      ChildObjectQueryService.aggregate(
        'NonexistentObject__c',
        'OpportunityId',
        'Amount',
        'Sum',
        oppIds,
        null
      );
      System.assert(false, 'Should have thrown');
    } catch (ChildObjectQueryService.QueryException e) {
      System.assert(
        e.getMessage().contains('does not exist'),
        'Error should mention object missing: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void invalidLookupField_throws() {
    Account a = new Account(Name = 'Agg Test');
    insert a;
    Opportunity opp = new Opportunity(
      Name = 'Agg Test Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Test.startTest();
    try {
      ChildObjectQueryService.aggregate(
        'OpportunityLineItem',
        'NoSuchField__c',
        'TotalPrice',
        'Sum',
        new Set<Id>{ opp.Id },
        null
      );
      System.assert(false, 'Should have thrown');
    } catch (ChildObjectQueryService.QueryException e) {
      System.assert(
        e.getMessage().contains('Lookup field'),
        'Error should mention bad lookup field: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void invalidAmountField_throws() {
    Account a = new Account(Name = 'Agg Test');
    insert a;
    Opportunity opp = new Opportunity(
      Name = 'Agg Test Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Test.startTest();
    try {
      ChildObjectQueryService.aggregate(
        'OpportunityLineItem',
        'OpportunityId',
        'NoSuchField__c',
        'Sum',
        new Set<Id>{ opp.Id },
        null
      );
      System.assert(false, 'Should have thrown');
    } catch (ChildObjectQueryService.QueryException e) {
      System.assert(
        e.getMessage().contains('Amount field'),
        'Error should mention bad amount field: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void unknownAggregation_throws() {
    Account a = new Account(Name = 'Agg Test');
    insert a;
    Opportunity opp = new Opportunity(
      Name = 'Agg Test Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Test.startTest();
    try {
      ChildObjectQueryService.aggregate(
        'OpportunityLineItem',
        'OpportunityId',
        'TotalPrice',
        'NotAValidAgg',
        new Set<Id>{ opp.Id },
        null
      );
      System.assert(false, 'Should have thrown');
    } catch (ChildObjectQueryService.QueryException e) {
      System.assert(
        e.getMessage().contains('aggregation'),
        'Error should mention aggregation: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void aggregateOpportunityLineItem_sumsCorrectly() {
    // OpportunityLineItem requires PricebookEntry on a standard pricebook
    // which requires a Product. Set up minimal test data.
    Account a = new Account(Name = 'OLI Test Acct');
    insert a;
    Opportunity opp = new Opportunity(
      Name = 'OLI Test Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Pricebook2 pb = new Pricebook2(
      Id = Test.getStandardPricebookId(),
      IsActive = true
    );
    update pb;

    Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prod.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert pbe;

    opp.Pricebook2Id = Test.getStandardPricebookId();
    update opp;

    OpportunityLineItem oli1 = new OpportunityLineItem(
      OpportunityId = opp.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 2,
      UnitPrice = 100
    );
    OpportunityLineItem oli2 = new OpportunityLineItem(
      OpportunityId = opp.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 3,
      UnitPrice = 100
    );
    insert new List<OpportunityLineItem>{ oli1, oli2 };

    Test.startTest();
    Map<Id, Decimal> result = ChildObjectQueryService.aggregate(
      'OpportunityLineItem',
      'OpportunityId',
      'TotalPrice',
      'Sum',
      new Set<Id>{ opp.Id },
      null
    );
    Test.stopTest();

    System.assert(result.containsKey(opp.Id), 'Should have aggregate for opp');
    // 2 * 100 + 3 * 100 = 500
    System.assertEquals(
      500,
      result.get(opp.Id),
      'SUM of TotalPrice should be 500, got: ' + result.get(opp.Id)
    );
  }

  @IsTest
  static void findOpportunitiesByChildField_returnsMatchingOppIds() {
    // Test with Opportunity as both anchor and child (Description text field
    // is present on every Opportunity). Validates the SOQL build path with
    // a real picklist-style filter against text values.
    Account a = new Account(Name = 'Lookup Test Acct');
    insert a;
    Opportunity opp1 = new Opportunity(
      Name = 'Opp 1',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Type = 'New Customer'
    );
    Opportunity opp2 = new Opportunity(
      Name = 'Opp 2',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Type = 'Existing Customer - Upgrade'
    );
    insert new List<Opportunity>{ opp1, opp2 };

    Test.startTest();
    // Use Opportunity itself as both source object AND lookup back to Opportunity (Id)
    // grouping by the Type picklist value
    Set<Id> matching = ChildObjectQueryService.findOpportunitiesByChildField(
      'Opportunity',
      'Id',
      'Type',
      new List<String>{ 'New Customer' }
    );
    Test.stopTest();

    System.assert(matching.contains(opp1.Id), 'Should include Opp 1');
    System.assert(!matching.contains(opp2.Id), 'Should NOT include Opp 2');
  }
}
