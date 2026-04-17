/**
 * @description Tests for ForecastGroupTrigger / Handler.
 *              Phase B: restrict-delete when active overrides reference the group.
 */
@IsTest
private class ForecastGroupTriggerTest {
  @TestSetup
  static void setup() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Group Trigger Test',
      Is_Active__c = true,
      Period_Type__c = 'Monthly'
    );
    insert config;

    Forecast_Group__c grp = new Forecast_Group__c(
      Forecast_Configuration__c = config.Id,
      Name = 'All Opportunities',
      Group_Type__c = 'All',
      Sort_Order__c = 1,
      Is_Active__c = true
    );
    insert grp;
  }

  @IsTest
  static void deleteEmptyGroup_succeeds() {
    Forecast_Group__c grp = [SELECT Id FROM Forecast_Group__c LIMIT 1];

    Test.startTest();
    delete grp;
    Test.stopTest();

    // Should be deleted
    List<Forecast_Group__c> remaining = [
      SELECT Id
      FROM Forecast_Group__c
      WHERE Id = :grp.Id
    ];
    System.assertEquals(
      0,
      remaining.size(),
      'Group with no overrides should hard-delete'
    );
  }

  @IsTest
  static void deleteGroup_blockedByExistingOverride() {
    Forecast_Configuration__c config = [
      SELECT Id
      FROM Forecast_Configuration__c
      LIMIT 1
    ];
    Forecast_Group__c grp = [SELECT Id FROM Forecast_Group__c LIMIT 1];

    // Need a Period + User + Participant + Override to test delete restriction
    Forecast_Period__c period = new Forecast_Period__c(
      Name = 'Apr 2026',
      Start_Date__c = Date.newInstance(2026, 4, 1),
      End_Date__c = Date.newInstance(2026, 4, 30),
      Status__c = 'Open',
      Period_Type__c = 'Monthly',
      Forecast_Configuration__c = config.Id
    );
    insert period;

    Id userId = UserInfo.getUserId();
    insert new Forecast_Participant__c(
      User__c = userId,
      Forecast_Period__c = period.Id,
      Scope_Id__c = 'TEST',
      Hierarchy_Level__c = 1,
      Is_Summary__c = false,
      Submission_Status__c = 'Not_Started'
    );

    // Create an Opportunity to reference
    Account a = new Account(Name = 'Test Acct');
    insert a;
    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      AccountId = a.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert opp;

    Forecast_Override__c ov = new Forecast_Override__c(
      Opportunity__c = opp.Id,
      Forecast_Period__c = period.Id,
      User__c = userId,
      Hierarchy_Level__c = 1,
      Status__c = 'Saved',
      Forecast_Group__c = grp.Id
    );
    insert ov;

    Test.startTest();
    try {
      delete grp;
      System.assert(false, 'Delete should have been blocked');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains('Cannot delete this group'),
        'Error should explain the restriction: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }
}
