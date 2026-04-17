/**
 * @description Tests for QuotaManagerController: CRUD, CSV import,
 *              distribute evenly, copy from last period.
 */
@IsTest
private class QuotaManagerControllerTest {
  @TestSetup
  static void setupTestData() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'QM Test',
      Is_Active__c = true,
      Period_Type__c = 'Monthly',
      Scope_Determination__c = 'Ownership'
    );
    insert config;

    // Previous period (for copy-from-last testing)
    Forecast_Period__c prevPeriod = new Forecast_Period__c(
      Name = 'Mar 2026',
      Start_Date__c = Date.newInstance(2026, 3, 1),
      End_Date__c = Date.newInstance(2026, 3, 31),
      Status__c = 'Closed',
      Period_Type__c = 'Monthly',
      Forecast_Configuration__c = config.Id
    );
    insert prevPeriod;

    // Current period
    Forecast_Period__c period = new Forecast_Period__c(
      Name = 'Apr 2026',
      Start_Date__c = Date.newInstance(2026, 4, 1),
      End_Date__c = Date.newInstance(2026, 4, 30),
      Status__c = 'Open',
      Period_Type__c = 'Monthly',
      Forecast_Configuration__c = config.Id
    );
    insert period;

    // Participant for current user in both periods
    Forecast_Participant__c participant = new Forecast_Participant__c(
      User__c = UserInfo.getUserId(),
      Forecast_Period__c = period.Id,
      Scope_Id__c = 'DEFAULT',
      Hierarchy_Level__c = 2,
      Is_Summary__c = false,
      Submission_Status__c = 'Not_Started'
    );
    insert participant;

    Forecast_Participant__c prevParticipant = new Forecast_Participant__c(
      User__c = UserInfo.getUserId(),
      Forecast_Period__c = prevPeriod.Id,
      Scope_Id__c = 'DEFAULT',
      Hierarchy_Level__c = 2,
      Is_Summary__c = false,
      Submission_Status__c = 'Submitted'
    );
    insert prevParticipant;

    // Previous period quota (for copy test)
    insert new Forecast_Quota__c(
      User__c = UserInfo.getUserId(),
      Forecast_Period__c = prevPeriod.Id,
      Forecast_Participant__c = prevParticipant.Id,
      Target_Amount__c = 1000000,
      Status__c = 'Active'
    );
  }

  static Forecast_Period__c getCurrentPeriod() {
    return [SELECT Id FROM Forecast_Period__c WHERE Status__c = 'Open' LIMIT 1];
  }

  // ── CRUD ──

  @IsTest
  static void getQuotasWithParticipants_returnsMergedData() {
    Id periodId = getCurrentPeriod().Id;
    Test.startTest();
    List<QuotaManagerController.QuotaRow> rows = QuotaManagerController.getQuotasWithParticipants(
      periodId
    );
    Test.stopTest();

    System.assert(rows.size() >= 1, 'Should return at least 1 participant row');
    System.assertEquals(UserInfo.getUserId(), rows[0].userId);
    // No quota created yet for current period
    System.assertEquals(false, rows[0].hasQuota);
  }

  @IsTest
  static void saveQuota_createsNew() {
    Id periodId = getCurrentPeriod().Id;
    Forecast_Participant__c p = [
      SELECT Id, User__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];
    Test.startTest();
    Id quotaId = QuotaManagerController.saveQuota(
      null,
      p.User__c,
      periodId,
      p.Id,
      1500000,
      'Active',
      'Test'
    );
    Test.stopTest();

    System.assertNotEquals(null, quotaId);
    Forecast_Quota__c q = [
      SELECT Target_Amount__c
      FROM Forecast_Quota__c
      WHERE Id = :quotaId
    ];
    System.assertEquals(1500000, q.Target_Amount__c);
  }

  @IsTest
  static void saveBulkQuotas_upsertsList() {
    Id periodId = getCurrentPeriod().Id;
    Forecast_Participant__c p = [
      SELECT Id, User__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];

    QuotaManagerController.QuotaSaveInput input = new QuotaManagerController.QuotaSaveInput();
    input.userId = p.User__c;
    input.participantId = p.Id;
    input.targetAmount = 2000000;
    input.status = 'Active';

    Test.startTest();
    QuotaManagerController.saveBulkQuotas(
      JSON.serialize(new List<QuotaManagerController.QuotaSaveInput>{ input }),
      periodId
    );
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :periodId
      ]
    );
  }

  @IsTest
  static void deleteQuota_removesRecord() {
    Id periodId = getCurrentPeriod().Id;
    Forecast_Participant__c p = [
      SELECT Id, User__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];

    Forecast_Quota__c q = new Forecast_Quota__c(
      User__c = p.User__c,
      Forecast_Period__c = periodId,
      Forecast_Participant__c = p.Id,
      Target_Amount__c = 500000,
      Status__c = 'Draft'
    );
    insert q;

    Test.startTest();
    QuotaManagerController.deleteQuota(q.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Forecast_Quota__c WHERE Id = :q.Id]
    );
  }

  // ── CSV IMPORT ──

  @IsTest
  static void importCsv_success() {
    Id periodId = getCurrentPeriod().Id;
    String email = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()]
    .Email;
    String csv = 'Email,Target Amount\n' + email + ',1500000';

    Test.startTest();
    QuotaManagerController.ImportResult result = QuotaManagerController.importCsvQuotas(
      periodId,
      csv
    );
    Test.stopTest();

    System.assertEquals(1, result.successCount, 'Should import 1 quota');
    System.assertEquals(0, result.errorRows.size(), 'Should have no errors');
  }

  @IsTest
  static void importCsv_rejectsDuplicate() {
    Id periodId = getCurrentPeriod().Id;
    Forecast_Participant__c p = [
      SELECT Id, User__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];

    // Create existing quota first
    insert new Forecast_Quota__c(
      User__c = p.User__c,
      Forecast_Period__c = periodId,
      Forecast_Participant__c = p.Id,
      Target_Amount__c = 1000000,
      Status__c = 'Active'
    );

    String email = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()]
    .Email;
    String csv = 'Email,Target Amount\n' + email + ',2000000';

    Test.startTest();
    QuotaManagerController.ImportResult result = QuotaManagerController.importCsvQuotas(
      periodId,
      csv
    );
    Test.stopTest();

    System.assertEquals(0, result.successCount);
    System.assertEquals(1, result.errorRows.size());
    System.assert(result.errorRows[0].error.contains('Duplicate'));
  }

  @IsTest
  static void importCsv_rejectsInvalidEmail() {
    Id periodId = getCurrentPeriod().Id;
    String csv = 'Email,Target Amount\nfake@nowhere.com,1000000';

    Test.startTest();
    QuotaManagerController.ImportResult result = QuotaManagerController.importCsvQuotas(
      periodId,
      csv
    );
    Test.stopTest();

    System.assertEquals(0, result.successCount);
    System.assertEquals(1, result.errorRows.size());
    System.assert(result.errorRows[0].error.contains('not found'));
  }

  @IsTest
  static void importCsv_rejectsNegative() {
    Id periodId = getCurrentPeriod().Id;
    String email = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()]
    .Email;
    String csv = 'Email,Target Amount\n' + email + ',-500';

    Test.startTest();
    QuotaManagerController.ImportResult result = QuotaManagerController.importCsvQuotas(
      periodId,
      csv
    );
    Test.stopTest();

    System.assertEquals(0, result.successCount);
    System.assert(result.errorRows[0].error.contains('negative'));
  }

  // ── DISTRIBUTE EVENLY ──

  @IsTest
  static void distributeEvenly_overwrite() {
    Id periodId = getCurrentPeriod().Id;

    Test.startTest();
    QuotaManagerController.DistributeResult result = QuotaManagerController.distributeEvenly(
      periodId,
      5000000,
      'OVERWRITE'
    );
    Test.stopTest();

    System.assert(result.updatedCount >= 1);
    System.assertEquals(0, result.skippedCount);
  }

  @IsTest
  static void distributeEvenly_skipExisting() {
    Id periodId = getCurrentPeriod().Id;
    Forecast_Participant__c p = [
      SELECT Id, User__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];

    // Create existing quota
    insert new Forecast_Quota__c(
      User__c = p.User__c,
      Forecast_Period__c = periodId,
      Forecast_Participant__c = p.Id,
      Target_Amount__c = 999999,
      Status__c = 'Active'
    );

    Test.startTest();
    QuotaManagerController.DistributeResult result = QuotaManagerController.distributeEvenly(
      periodId,
      5000000,
      'SKIP_EXISTING'
    );
    Test.stopTest();

    System.assert(result.skippedCount >= 1, 'Should skip existing quotas');
  }

  // ── COPY FROM LAST PERIOD ──

  @IsTest
  static void copyFromLastPeriod_overwrite() {
    Id periodId = getCurrentPeriod().Id;

    Test.startTest();
    QuotaManagerController.CopyResult result = QuotaManagerController.copyFromLastPeriod(
      periodId,
      'OVERWRITE',
      null
    );
    Test.stopTest();

    System.assert(result.copiedCount >= 1);
    Forecast_Quota__c q = [
      SELECT Target_Amount__c
      FROM Forecast_Quota__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];
    System.assertEquals(
      1000000,
      q.Target_Amount__c,
      'Should copy exact amount'
    );
  }

  @IsTest
  static void copyFromLastPeriod_withAdjustment() {
    Id periodId = getCurrentPeriod().Id;

    Test.startTest();
    QuotaManagerController.CopyResult result = QuotaManagerController.copyFromLastPeriod(
      periodId,
      'OVERWRITE',
      10
    );
    Test.stopTest();

    System.assert(result.copiedCount >= 1);
    Forecast_Quota__c q = [
      SELECT Target_Amount__c
      FROM Forecast_Quota__c
      WHERE Forecast_Period__c = :periodId
      LIMIT 1
    ];
    System.assertEquals(
      1100000,
      q.Target_Amount__c,
      'Should apply +10% adjustment'
    );
  }
}
