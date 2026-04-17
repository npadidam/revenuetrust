/**
 * @description Tests for AdminConsoleController: config CRUD, metrics, categories,
 *              periods, participants, quotas, and audit logging.
 */
@IsTest
private class AdminConsoleControllerTest {
  @TestSetup
  static void setupTestData() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Admin Test Config',
      Is_Active__c = true,
      Period_Type__c = 'Monthly',
      Pagination_Size__c = 40,
      Currency_Mode__c = 'Single',
      Corporate_Currency__c = 'USD',
      Scope_Determination__c = 'Ownership',
      Top_Level_Lock_Label__c = 'Freeze',
      Attainment_Source__c = 'Forecast_Quota_With_Live'
    );
    insert config;

    insert new List<Forecast_Metric__c>{
      new Forecast_Metric__c(
        Name = 'Revenue',
        Metric_Label__c = 'Revenue',
        Metric_Type__c = 'Currency',
        Display_Format__c = 'Currency',
        Forecast_Configuration__c = config.Id,
        Is_Primary__c = true,
        Is_Editable__c = true,
        Sort_Order__c = 1,
        Source_Field__c = 'Amount'
      ),
      new Forecast_Metric__c(
        Name = 'ACV',
        Metric_Label__c = 'ACV',
        Metric_Type__c = 'Currency',
        Display_Format__c = 'Currency',
        Forecast_Configuration__c = config.Id,
        Is_Primary__c = false,
        Is_Editable__c = true,
        Sort_Order__c = 2
      )
    };

    insert new List<Forecast_Category__c>{
      new Forecast_Category__c(
        Name = 'Commit',
        Category_Label__c = 'Commit',
        Category_API_Name__c = 'Commit',
        Forecast_Configuration__c = config.Id,
        Is_Active__c = true,
        Sort_Order__c = 1,
        Counts_Toward_Target__c = true,
        Color_Hex__c = '#04844B'
      ),
      new Forecast_Category__c(
        Name = 'Pipeline',
        Category_Label__c = 'Pipeline',
        Category_API_Name__c = 'Pipeline',
        Forecast_Configuration__c = config.Id,
        Is_Active__c = true,
        Sort_Order__c = 2,
        Color_Hex__c = '#F2CF00'
      ),
      new Forecast_Category__c(
        Name = 'Closed Won',
        Category_Label__c = 'Closed Won',
        Category_API_Name__c = 'Closed_Won',
        Forecast_Configuration__c = config.Id,
        Is_Active__c = true,
        Sort_Order__c = 3,
        Is_Terminal__c = true,
        Counts_Toward_Target__c = true,
        Color_Hex__c = '#706E6B'
      ),
      new Forecast_Category__c(
        Name = 'Lost',
        Category_Label__c = 'Lost',
        Category_API_Name__c = 'Lost',
        Forecast_Configuration__c = config.Id,
        Is_Active__c = true,
        Sort_Order__c = 4,
        Is_Terminal__c = true,
        Color_Hex__c = '#EA001E'
      )
    };

    Forecast_Period__c period = new Forecast_Period__c(
      Name = 'Apr 2026',
      Start_Date__c = Date.newInstance(2026, 4, 1),
      End_Date__c = Date.newInstance(2026, 4, 30),
      Status__c = 'Open',
      Period_Type__c = 'Monthly',
      Forecast_Configuration__c = config.Id
    );
    insert period;

    Forecast_Participant__c participant = new Forecast_Participant__c(
      User__c = UserInfo.getUserId(),
      Forecast_Period__c = period.Id,
      Scope_Id__c = 'DEFAULT',
      Hierarchy_Level__c = 2,
      Is_Summary__c = false,
      Submission_Status__c = 'Not_Started'
    );
    insert participant;
  }

  static Forecast_Configuration__c getConfig() {
    return [
      SELECT Id
      FROM Forecast_Configuration__c
      WHERE Is_Active__c = TRUE
      LIMIT 1
    ];
  }
  static Forecast_Period__c getPeriod() {
    return [SELECT Id FROM Forecast_Period__c WHERE Status__c = 'Open' LIMIT 1];
  }

  // ── General Settings ──

  @IsTest
  static void getConfig_returnsActiveConfig() {
    Test.startTest();
    Forecast_Configuration__c config = AdminConsoleController.getConfig();
    Test.stopTest();
    System.assertNotEquals(null, config);
    System.assertEquals(true, config.Is_Active__c);
  }

  @IsTest
  static void saveGeneralSettings_updatesConfig() {
    Id configId = getConfig().Id;
    Test.startTest();
    AdminConsoleController.saveGeneralSettings(
      configId,
      'Quarterly',
      50,
      'Single',
      'USD',
      'Incentives_Quota_With_Live',
      'Current_Period',
      'Lock',
      'Ownership',
      4,
      null,
      5,
      6,
      1,
      2,
      'Current_Period',
      3,
      'Final Forecast',
      'Stretch Forecast',
      'Monthly',
      '5',
      false,
      null,
      null,
      null
    );
    Test.stopTest();

    Forecast_Configuration__c updated = [
      SELECT Period_Type__c, Pagination_Size__c
      FROM Forecast_Configuration__c
      WHERE Id = :configId
    ];
    System.assertEquals('Quarterly', updated.Period_Type__c);
    System.assertEquals(50, updated.Pagination_Size__c);
  }

  // ── Metrics ──

  @IsTest
  static void getMetrics_returnsList() {
    Id configId = getConfig().Id;
    Test.startTest();
    List<Forecast_Metric__c> metrics = AdminConsoleController.getMetrics(
      configId
    );
    Test.stopTest();
    System.assertEquals(2, metrics.size());
  }

  @IsTest
  static void saveMetric_createsNew() {
    Id configId = getConfig().Id;
    Test.startTest();
    Id metricId = AdminConsoleController.saveMetric(
      configId,
      null,
      'Quantity',
      'Qty',
      'Number',
      'Number',
      false,
      false,
      true,
      3,
      null,
      'Opportunity',
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertNotEquals(null, metricId);
    System.assertEquals(
      3,
      [
        SELECT COUNT()
        FROM Forecast_Metric__c
        WHERE Forecast_Configuration__c = :configId
      ]
    );
  }

  @IsTest
  static void saveMetric_updatesExisting() {
    Id configId = getConfig().Id;
    Forecast_Metric__c existing = [
      SELECT Id
      FROM Forecast_Metric__c
      WHERE Forecast_Configuration__c = :configId
      LIMIT 1
    ];
    Test.startTest();
    AdminConsoleController.saveMetric(
      configId,
      existing.Id,
      'Revenue Updated',
      'Rev',
      'Currency',
      'Currency',
      true,
      true,
      true,
      1,
      'Amount',
      'Opportunity',
      null,
      null,
      null
    );
    Test.stopTest();
    Forecast_Metric__c updated = [
      SELECT Name
      FROM Forecast_Metric__c
      WHERE Id = :existing.Id
    ];
    System.assertEquals('Revenue Updated', updated.Name);
  }

  // ── Categories ──

  @IsTest
  static void getCategories_returnsList() {
    Id configId = getConfig().Id;
    Test.startTest();
    List<Forecast_Category__c> cats = AdminConsoleController.getCategories(
      configId
    );
    Test.stopTest();
    System.assertEquals(4, cats.size());
  }

  @IsTest
  static void saveCategory_createsNew() {
    Id configId = getConfig().Id;
    Test.startTest();
    Id catId = AdminConsoleController.saveCategory(
      configId,
      null,
      'Best Case',
      'Best Case',
      'Best_Case',
      '#1589EE',
      true,
      true,
      false,
      false,
      false,
      5
    );
    Test.stopTest();
    System.assertNotEquals(null, catId);
  }

  @IsTest
  static void deactivateCategory_blocksTerminal() {
    Forecast_Category__c terminal = [
      SELECT Id
      FROM Forecast_Category__c
      WHERE Is_Terminal__c = TRUE
      LIMIT 1
    ];
    Boolean threw = false;
    Test.startTest();
    try {
      AdminConsoleController.deactivateCategory(terminal.Id);
    } catch (Exception e) {
      threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'Should throw when deactivating terminal category');
  }

  // ── Periods ──

  @IsTest
  static void getPeriods_returnsList() {
    Id configId = getConfig().Id;
    Test.startTest();
    List<Forecast_Period__c> periods = AdminConsoleController.getPeriods(
      configId
    );
    Test.stopTest();
    System.assert(periods.size() >= 1);
  }

  @IsTest
  static void updatePeriodStatus_closesOpenPeriod() {
    Id periodId = getPeriod().Id;
    Test.startTest();
    AdminConsoleController.updatePeriodStatus(periodId, 'Closed');
    Test.stopTest();
    Forecast_Period__c updated = [
      SELECT Status__c
      FROM Forecast_Period__c
      WHERE Id = :periodId
    ];
    System.assertEquals('Closed', updated.Status__c);
  }

  @IsTest
  static void generateFuturePeriods_createsPeriods() {
    Id configId = getConfig().Id;
    Test.startTest();
    List<Id> ids = AdminConsoleController.generateFuturePeriods(configId, 2);
    Test.stopTest();
    System.assertEquals(2, ids.size());
  }

  // ── Participants ──

  @IsTest
  static void getParticipants_returnsList() {
    Id periodId = getPeriod().Id;
    Test.startTest();
    AdminConsoleController.ParticipantListResult result = AdminConsoleController.getParticipants(
      periodId,
      1,
      50
    );
    Test.stopTest();
    System.assert(result.totalCount >= 1);
    System.assert(result.participants.size() >= 1);
  }

  @IsTest
  static void updateParticipantLevel_changesLevel() {
    Forecast_Participant__c p = [
      SELECT Id
      FROM Forecast_Participant__c
      LIMIT 1
    ];
    Test.startTest();
    AdminConsoleController.updateParticipantLevel(p.Id, 3);
    Test.stopTest();
    p = [
      SELECT Hierarchy_Level__c
      FROM Forecast_Participant__c
      WHERE Id = :p.Id
    ];
    System.assertEquals(3, p.Hierarchy_Level__c);
  }

  @IsTest
  static void setDelegate_setsFields() {
    Forecast_Participant__c p = [
      SELECT Id
      FROM Forecast_Participant__c
      LIMIT 1
    ];
    Test.startTest();
    AdminConsoleController.setDelegate(
      p.Id,
      UserInfo.getUserId(),
      Date.today(),
      Date.today().addDays(30)
    );
    Test.stopTest();
    p = [
      SELECT Delegate__c, Delegate_Start__c
      FROM Forecast_Participant__c
      WHERE Id = :p.Id
    ];
    System.assertEquals(UserInfo.getUserId(), p.Delegate__c);
  }

  // ── Quotas ──

  @IsTest
  static void saveAndGetQuota_works() {
    Id periodId = getPeriod().Id;
    Test.startTest();
    Id quotaId = AdminConsoleController.saveQuota(
      null,
      UserInfo.getUserId(),
      periodId,
      1500000,
      'Active',
      'Test quota'
    );
    List<Forecast_Quota__c> quotas = AdminConsoleController.getQuotasForPeriod(
      periodId
    );
    Test.stopTest();
    System.assertNotEquals(null, quotaId);
    System.assertEquals(1, quotas.size());
    System.assertEquals(1500000, quotas[0].Target_Amount__c);
  }

  // ── Audit ──

  @IsTest
  static void saveGeneralSettings_createsAuditEvent() {
    Id configId = getConfig().Id;
    Test.startTest();
    AdminConsoleController.saveGeneralSettings(
      configId,
      'Quarterly',
      null,
      null,
      null,
      null,
      null,
      null,
      'Territory',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    List<Forecast_Change_Event__c> events = [
      SELECT Change_Type__c, Config_Change_Details__c
      FROM Forecast_Change_Event__c
      WHERE Change_Type__c = 'Config_Change'
    ];
    System.assert(
      events.size() >= 1,
      'Should create audit event for config change'
    );
  }
}
