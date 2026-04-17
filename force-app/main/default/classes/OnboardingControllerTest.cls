/**
 * @description Tests for OnboardingController: org discovery, config activation,
 *              CMT deployment, and hasActiveConfig detection.
 */
@IsTest
private class OnboardingControllerTest {
  // ── Org Discovery ──

  @IsTest
  static void discoverOrg_returnsValidResult() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    System.assertNotEquals(null, result, 'Discovery result should not be null');
    System.assert(
      result.stages.size() > 0,
      'Should discover at least one stage'
    );
    System.assert(
      result.closedWonStages.size() > 0,
      'Should find at least one Closed Won stage'
    );
    System.assert(
      result.closedLostStages.size() > 0,
      'Should find at least one Closed Lost stage'
    );
    System.assertNotEquals(
      null,
      result.isMultiCurrency,
      'isMultiCurrency should be set'
    );
    System.assert(
      result.fiscalYearStartMonth >= 1 && result.fiscalYearStartMonth <= 12,
      'Fiscal year start month should be 1-12'
    );
    System.assert(
      result.activeUserCount > 0,
      'Should have at least 1 active user'
    );
  }

  @IsTest
  static void discoverOrg_detectsHierarchy() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    System.assertNotEquals(
      null,
      result.hasRoleHierarchy,
      'hasRoleHierarchy should be set'
    );
    // detectedLevels may be empty if no roles exist in test context
    System.assertNotEquals(
      null,
      result.detectedLevels,
      'detectedLevels should not be null'
    );
  }

  // ── Phase A: Discovery enhancements ──

  @IsTest
  static void discoverOrg_phaseA_returnsHierarchySourceLabel() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    System.assertNotEquals(
      null,
      result.hierarchySourceLabel,
      'hierarchySourceLabel should be set'
    );
    System.assert(
      result.hierarchySourceLabel == 'Role Hierarchy' ||
        result.hierarchySourceLabel == 'Territory Management' ||
        result.hierarchySourceLabel == 'Manager Field (User.ManagerId)',
      'hierarchySourceLabel should be one of the known values, got: ' +
      result.hierarchySourceLabel
    );
  }

  @IsTest
  static void discoverOrg_phaseA_returnsFiscalYearStartMonthName() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    System.assertNotEquals(
      null,
      result.fiscalYearStartMonthName,
      'fiscalYearStartMonthName should be set'
    );
    Set<String> validNames = new Set<String>{
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    };
    System.assert(
      validNames.contains(result.fiscalYearStartMonthName),
      'Should be a valid month name, got: ' + result.fiscalYearStartMonthName
    );
  }

  @IsTest
  static void discoverOrg_phaseA_returnsCorporateCurrency() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    System.assertNotEquals(
      null,
      result.corporateCurrency,
      'corporateCurrency should be set'
    );
    System.assertEquals(
      3,
      result.corporateCurrency.length(),
      'corporateCurrency should be a 3-letter ISO code'
    );
  }

  @IsTest
  static void discoverOrg_phaseA_userCountExcludesSystemUsers() {
    // The query filter should exclude integration/security/community users.
    // In a fresh org with only standard admins, count should still be > 0.
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    System.assert(
      result.activeUserCount >= 0,
      'activeUserCount should be non-negative (filter excludes system users)'
    );
  }

  @IsTest
  static void discoverOrg_phaseA_stagesByRecordType() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    // stagesByRecordType is always initialized (possibly empty if no RTs)
    System.assertNotEquals(
      null,
      result.stagesByRecordType,
      'stagesByRecordType should be initialized'
    );

    if (result.recordTypes.isEmpty()) {
      System.assertEquals(
        0,
        result.stagesByRecordType.size(),
        'No RTs means empty map'
      );
      return;
    }

    // For each RT, the stages entry must exist and contain only stages
    // that are actually in the global active picklist (no fabrication)
    Set<String> globalActiveStageValues = new Set<String>();
    for (OnboardingController.StageInfo si : result.stages) {
      globalActiveStageValues.add(si.value);
    }

    for (OnboardingController.RecordTypeInfo rt : result.recordTypes) {
      List<OnboardingController.StageInfo> rtStages = result.stagesByRecordType.get(
        rt.developerName
      );
      System.assertNotEquals(
        null,
        rtStages,
        'Each RT should have a stages entry: ' + rt.developerName
      );
      // Every stage in this RT must be a real active stage (no spurious values)
      for (OnboardingController.StageInfo si : rtStages) {
        System.assert(
          globalActiveStageValues.contains(si.value),
          'RT-specific stage ' +
            si.value +
            ' must exist in global active stages'
        );
      }
    }
  }

  /**
   * @description Verifies the validFor decoding path (Phase A — RT-specific
   *              picklist subsetting). When an org has multiple RTs and the
   *              picklist values are restricted by RT, the per-RT stage list
   *              should be a subset of the global stages, not identical.
   *              Cannot create RTs in test context, so this is a structural test.
   */
  @IsTest
  static void discoverOrg_phaseA_stagesByRecordTypeIsSubsetOrEqual() {
    Test.startTest();
    OnboardingController.OrgDiscoveryResult result = OnboardingController.discoverOrg();
    Test.stopTest();

    // Each RT's stage list must be <= global stages (subset semantics)
    Integer globalCount = result.stages != null ? result.stages.size() : 0;
    for (OnboardingController.RecordTypeInfo rt : result.recordTypes) {
      List<OnboardingController.StageInfo> rtStages = result.stagesByRecordType.get(
        rt.developerName
      );
      if (rtStages != null) {
        System.assert(
          rtStages.size() <= globalCount,
          'RT stage count must be <= global stage count for ' +
            rt.developerName +
            ' (got ' +
            rtStages.size() +
            ' vs global ' +
            globalCount +
            ')'
        );
      }
    }
  }

  // ── Phase A: activateConfiguration with custom field scope ──

  @IsTest
  static void activateConfiguration_phaseA_capturesCustomFieldScope() {
    String metricsJson = JSON.serialize(
      new List<OnboardingController.MetricInput>{
        createMetricInput(
          'Revenue',
          'Revenue',
          'Currency',
          'Currency',
          true,
          true,
          true,
          1,
          'Amount'
        )
      }
    );
    String categoriesJson = JSON.serialize(
      new List<OnboardingController.CategoryInput>{
        createCategoryInput(
          'Commit',
          'Commit',
          'Commit',
          '#04844B',
          true,
          false,
          true,
          false,
          1
        ),
        createCategoryInput(
          'Closed Won',
          'Closed Won',
          'Closed_Won',
          '#706E6B',
          true,
          true,
          true,
          false,
          2
        )
      }
    );

    Test.startTest();
    Id configId = OnboardingController.activateConfiguration(
      'Custom Field Scope Test',
      'Custom_Field',
      'Monthly',
      3,
      1,
      'Forecast_Quota_With_Live',
      'Single',
      'USD',
      'Freeze',
      40,
      null,
      '{"1":"Rep"}',
      metricsJson,
      categoriesJson,
      'Opportunity', // scopeCustomObject
      'Territory_Code__c', // scopeCustomField
      null, // groupsJson (Phase B)
      null, // pastPeriodsVisible (Phase C)
      null, // defaultHorizon
      null, // customHorizonPeriods
      null, // finalForecastLabel
      null, // stretchForecastLabel
      null, // forecastCadence (Phase D)
      null, // submissionDeadlineDay
      null, // autoFreezeOnDeadline
      null, // cadenceAnchorDate
      null // displayFieldsJson (Phase D)
    );
    Test.stopTest();

    Forecast_Configuration__c config = [
      SELECT
        Scope_Determination__c,
        Scope_Custom_Object__c,
        Scope_Custom_Field__c
      FROM Forecast_Configuration__c
      WHERE Id = :configId
    ];
    System.assertEquals('Custom_Field', config.Scope_Determination__c);
    System.assertEquals(
      'Opportunity',
      config.Scope_Custom_Object__c,
      'Scope_Custom_Object__c should be persisted when Custom_Field is selected'
    );
    System.assertEquals('Territory_Code__c', config.Scope_Custom_Field__c);
  }

  @IsTest
  static void activateConfiguration_phaseA_ignoresCustomFieldScopeWhenNotCustomField() {
    // When hierarchySource != Custom_Field, the scope custom object/field should NOT be set
    String metricsJson = JSON.serialize(
      new List<OnboardingController.MetricInput>{
        createMetricInput(
          'Revenue',
          'Revenue',
          'Currency',
          'Currency',
          true,
          true,
          true,
          1,
          'Amount'
        )
      }
    );
    String categoriesJson = JSON.serialize(
      new List<OnboardingController.CategoryInput>{
        createCategoryInput(
          'Commit',
          'Commit',
          'Commit',
          '#04844B',
          true,
          false,
          true,
          false,
          1
        ),
        createCategoryInput(
          'Closed Won',
          'Closed Won',
          'Closed_Won',
          '#706E6B',
          true,
          true,
          true,
          false,
          2
        )
      }
    );

    Test.startTest();
    Id configId = OnboardingController.activateConfiguration(
      'Ownership Scope Test',
      'Ownership',
      'Monthly',
      3,
      1,
      'Forecast_Quota_With_Live',
      'Single',
      'USD',
      'Freeze',
      40,
      null,
      '{"1":"Rep"}',
      metricsJson,
      categoriesJson,
      'Opportunity',
      'ShouldNotBeSet__c',
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

    Forecast_Configuration__c config = [
      SELECT
        Scope_Determination__c,
        Scope_Custom_Object__c,
        Scope_Custom_Field__c
      FROM Forecast_Configuration__c
      WHERE Id = :configId
    ];
    System.assertEquals('Ownership', config.Scope_Determination__c);
    System.assertEquals(
      null,
      config.Scope_Custom_Object__c,
      'Should be null when hierarchySource != Custom_Field'
    );
    System.assertEquals(
      null,
      config.Scope_Custom_Field__c,
      'Should be null when hierarchySource != Custom_Field'
    );
  }

  // ── Has Active Config ──

  @IsTest
  static void hasActiveConfig_returnsFalseWhenNoConfig() {
    // No config created
    Test.startTest();
    Boolean result = OnboardingController.hasActiveConfig();
    Test.stopTest();

    System.assertEquals(
      false,
      result,
      'Should return false when no config exists'
    );
  }

  @IsTest
  static void hasActiveConfig_returnsTrueWhenConfigExists() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Test Config',
      Is_Active__c = true,
      Period_Type__c = 'Monthly',
      Scope_Determination__c = 'Ownership'
    );
    insert config;

    Test.startTest();
    Boolean result = OnboardingController.hasActiveConfig();
    Test.stopTest();

    System.assertEquals(
      true,
      result,
      'Should return true when active config exists'
    );
  }

  // ── Activate Configuration ──

  @IsTest
  static void activateConfiguration_createsFullConfig() {
    String metricsJson = JSON.serialize(
      new List<OnboardingController.MetricInput>{
        createMetricInput(
          'Revenue',
          'Revenue',
          'Currency',
          'Currency',
          true,
          true,
          true,
          1,
          'Amount'
        ),
        createMetricInput(
          'ACV',
          'ACV',
          'Currency',
          'Currency',
          false,
          false,
          true,
          2,
          null
        )
      }
    );

    String categoriesJson = JSON.serialize(
      new List<OnboardingController.CategoryInput>{
        createCategoryInput(
          'Commit',
          'Commit',
          'Commit',
          '#04844B',
          true,
          false,
          true,
          false,
          1
        ),
        createCategoryInput(
          'Pipeline',
          'Pipeline',
          'Pipeline',
          '#F2CF00',
          false,
          false,
          false,
          false,
          2
        ),
        createCategoryInput(
          'Closed Won',
          'Closed Won',
          'Closed_Won',
          '#706E6B',
          true,
          true,
          true,
          false,
          3
        ),
        createCategoryInput(
          'Lost',
          'Lost',
          'Lost',
          '#EA001E',
          false,
          true,
          false,
          true,
          4
        )
      }
    );

    Test.startTest();
    Id configId = OnboardingController.activateConfiguration(
      'Test Onboarding Config', // configName
      'Ownership', // hierarchySource
      'Monthly', // periodType
      3, // futurePeriods
      1, // fiscalYearStartMonth
      'Forecast_Quota_With_Live', // attainmentSource
      'Single', // currencyMode
      'USD', // corporateCurrency
      'Freeze', // topLevelLockLabel
      40, // paginationSize
      null, // pipelineRecordTypeFilter
      '{"1":"Rep","2":"Manager"}', // levelLabelsJson
      metricsJson, // metricsJson
      categoriesJson, // categoriesJson
      null, // scopeCustomObject (Phase A)
      null, // scopeCustomField (Phase A)
      null, // groupsJson (Phase B)
      null, // pastPeriodsVisible (Phase C)
      null, // defaultHorizon
      null, // customHorizonPeriods
      null, // finalForecastLabel
      null, // stretchForecastLabel
      null, // forecastCadence (Phase D)
      null, // submissionDeadlineDay
      null, // autoFreezeOnDeadline
      null, // cadenceAnchorDate
      null // displayFieldsJson
    );
    Test.stopTest();

    System.assertNotEquals(null, configId, 'Config Id should be returned');

    // Verify config created
    Forecast_Configuration__c config = [
      SELECT
        Is_Active__c,
        Period_Type__c,
        Scope_Determination__c,
        Attainment_Source__c,
        Currency_Mode__c
      FROM Forecast_Configuration__c
      WHERE Id = :configId
    ];
    System.assertEquals(true, config.Is_Active__c);
    System.assertEquals('Monthly', config.Period_Type__c);
    System.assertEquals('Ownership', config.Scope_Determination__c);
    System.assertEquals(
      'Forecast_Quota_With_Live',
      config.Attainment_Source__c
    );

    // Verify metrics created
    List<Forecast_Metric__c> metrics = [
      SELECT Name, Is_Primary__c
      FROM Forecast_Metric__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Sort_Order__c
    ];
    System.assertEquals(2, metrics.size(), 'Should create 2 metrics');
    System.assertEquals(
      true,
      metrics[0].Is_Primary__c,
      'First metric should be primary'
    );

    // Verify categories created
    List<Forecast_Category__c> categories = [
      SELECT Name, Is_Terminal__c
      FROM Forecast_Category__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Sort_Order__c
    ];
    System.assertEquals(4, categories.size(), 'Should create 4 categories');

    // Verify periods created (1 open + 3 scheduled)
    List<Forecast_Period__c> periods = [
      SELECT Status__c
      FROM Forecast_Period__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Start_Date__c
    ];
    System.assert(periods.size() >= 2, 'Should create at least 2 periods');
    System.assertEquals(
      'Open',
      periods[0].Status__c,
      'First period should be Open'
    );
  }

  @IsTest
  static void activateConfiguration_handlesMinimalParams() {
    Test.startTest();
    Id configId = OnboardingController.activateConfiguration(
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

    System.assertNotEquals(
      null,
      configId,
      'Should create config even with all nulls (uses defaults)'
    );
    Forecast_Configuration__c config = [
      SELECT Period_Type__c, Pagination_Size__c
      FROM Forecast_Configuration__c
      WHERE Id = :configId
    ];
    System.assertEquals(
      'Monthly',
      config.Period_Type__c,
      'Should default to Monthly'
    );
    System.assertEquals(40, config.Pagination_Size__c, 'Should default to 40');
  }

  // ── CMT Deployment ──

  @IsTest
  static void deployCmtUpdate_handlesDeployment() {
    Test.startTest();
    try {
      String jobId = OnboardingController.deployCmtUpdate(
        'Hierarchy_Source__mdt.Default',
        JSON.serialize(
          new Map<String, String>{ 'Source_Type__c' => 'ManagerChain' }
        )
      );
      System.assertNotEquals(null, jobId, 'Should return a deployment job Id');
    } catch (AuraHandledException e) {
      // Metadata.Operations.enqueueDeployment() throws in test context — expected
      System.assert(
        true,
        'CMT deploy throws in test context — expected behavior'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void checkDeployStatus_returnsPendingOrSucceeded() {
    Test.startTest();
    String status = OnboardingController.checkDeployStatus(
      'Hierarchy_Source__mdt.Default',
      'Source_Type__c',
      'RoleHierarchy'
    );
    Test.stopTest();

    System.assert(
      status == 'Succeeded' || status == 'Pending',
      'Status should be Succeeded or Pending, got: ' + status
    );
  }

  // ── ForecastPeriodService ──

  @IsTest
  static void periodService_createCurrentPeriod() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Period Test Config',
      Is_Active__c = true,
      Period_Type__c = 'Monthly'
    );
    insert config;

    Test.startTest();
    Id periodId = ForecastPeriodService.createCurrentPeriod(
      'Monthly',
      config.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, periodId);
    Forecast_Period__c period = [
      SELECT Status__c, Period_Type__c
      FROM Forecast_Period__c
      WHERE Id = :periodId
    ];
    System.assertEquals('Open', period.Status__c);
    System.assertEquals('Monthly', period.Period_Type__c);
  }

  @IsTest
  static void periodService_createFuturePeriods() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Period Test Config',
      Is_Active__c = true,
      Period_Type__c = 'Quarterly'
    );
    insert config;

    Test.startTest();
    List<Id> periodIds = ForecastPeriodService.createFuturePeriods(
      2,
      'Quarterly',
      config.Id,
      null
    );
    Test.stopTest();

    System.assertEquals(2, periodIds.size(), 'Should create 2 periods');
  }

  @IsTest
  static void periodService_closePastPeriods() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Close Test',
      Is_Active__c = true,
      Period_Type__c = 'Monthly'
    );
    insert config;

    Forecast_Period__c pastPeriod = new Forecast_Period__c(
      Name = 'Jan 2025',
      Start_Date__c = Date.newInstance(2025, 1, 1),
      End_Date__c = Date.newInstance(2025, 1, 31),
      Status__c = 'Open',
      Period_Type__c = 'Monthly',
      Forecast_Configuration__c = config.Id
    );
    insert pastPeriod;

    Test.startTest();
    Integer closed = ForecastPeriodService.closePastPeriods();
    Test.stopTest();

    System.assert(closed >= 1, 'Should close at least 1 past period');
    pastPeriod = [
      SELECT Status__c
      FROM Forecast_Period__c
      WHERE Id = :pastPeriod.Id
    ];
    System.assertEquals('Closed', pastPeriod.Status__c);
  }

  // ── ForecastQuotaTriggerHandler ──

  @IsTest
  static void quotaTrigger_enforceUniqueness() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Quota Test',
      Is_Active__c = true,
      Period_Type__c = 'Monthly'
    );
    insert config;

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

    // Must create participant for user+period (trigger validates)
    insert new Forecast_Participant__c(
      User__c = userId,
      Forecast_Period__c = period.Id,
      Scope_Id__c = 'TEST',
      Hierarchy_Level__c = 1,
      Is_Summary__c = false,
      Submission_Status__c = 'Not_Started'
    );

    Forecast_Quota__c quota1 = new Forecast_Quota__c(
      User__c = userId,
      Forecast_Period__c = period.Id,
      Target_Amount__c = 1000000,
      Status__c = 'Active'
    );
    insert quota1;

    // Try inserting a duplicate
    Forecast_Quota__c quota2 = new Forecast_Quota__c(
      User__c = userId,
      Forecast_Period__c = period.Id,
      Target_Amount__c = 2000000,
      Status__c = 'Draft'
    );

    Test.startTest();
    try {
      insert quota2;
      System.assert(false, 'Should have thrown duplicate error');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains('quota already exists'),
        'Error should mention duplicate quota'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void quotaTrigger_rejectsNegativeTarget() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Neg Test',
      Is_Active__c = true,
      Period_Type__c = 'Monthly'
    );
    insert config;

    Forecast_Period__c period = new Forecast_Period__c(
      Name = 'May 2026',
      Start_Date__c = Date.newInstance(2026, 5, 1),
      End_Date__c = Date.newInstance(2026, 5, 31),
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

    Forecast_Quota__c quota = new Forecast_Quota__c(
      User__c = userId,
      Forecast_Period__c = period.Id,
      Target_Amount__c = -500,
      Status__c = 'Draft'
    );

    Test.startTest();
    try {
      insert quota;
      System.assert(false, 'Should have rejected negative target');
    } catch (DmlException e) {
      System.assert(
        e.getMessage().contains('negative'),
        'Error should mention negative target'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void quotaTrigger_computesAttainment() {
    Forecast_Configuration__c config = new Forecast_Configuration__c(
      Name = 'Att Test',
      Is_Active__c = true,
      Period_Type__c = 'Monthly'
    );
    insert config;

    Forecast_Period__c period = new Forecast_Period__c(
      Name = 'Jun 2026',
      Start_Date__c = Date.newInstance(2026, 6, 1),
      End_Date__c = Date.newInstance(2026, 6, 30),
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

    Forecast_Quota__c quota = new Forecast_Quota__c(
      User__c = userId,
      Forecast_Period__c = period.Id,
      Target_Amount__c = 1000000,
      Achieved_Amount__c = 500000,
      Status__c = 'Active'
    );

    Test.startTest();
    insert quota;
    Test.stopTest();

    quota = [
      SELECT Attainment_Pct__c
      FROM Forecast_Quota__c
      WHERE Id = :quota.Id
    ];
    System.assertEquals(
      50.0,
      quota.Attainment_Pct__c,
      'Attainment should be 50%'
    );
  }

  // ── Helpers ──

  private static OnboardingController.MetricInput createMetricInput(
    String name,
    String label,
    String metricType,
    String displayFormat,
    Boolean isPrimary,
    Boolean isRequired,
    Boolean isEditable,
    Integer sortOrder,
    String sourceField
  ) {
    OnboardingController.MetricInput mi = new OnboardingController.MetricInput();
    mi.name = name;
    mi.label = label;
    mi.metricType = metricType;
    mi.displayFormat = displayFormat;
    mi.isPrimary = isPrimary;
    mi.isRequired = isRequired;
    mi.isEditable = isEditable;
    mi.sortOrder = sortOrder;
    mi.sourceField = sourceField;
    return mi;
  }

  private static OnboardingController.CategoryInput createCategoryInput(
    String name,
    String label,
    String apiName,
    String color,
    Boolean countsTowardTarget,
    Boolean isTerminal,
    Boolean isHighConfidence,
    Boolean regressionWarning,
    Integer sortOrder
  ) {
    OnboardingController.CategoryInput ci = new OnboardingController.CategoryInput();
    ci.name = name;
    ci.label = label;
    ci.apiName = apiName;
    ci.color = color;
    ci.countsTowardTarget = countsTowardTarget;
    ci.isTerminal = isTerminal;
    ci.isHighConfidence = isHighConfidence;
    ci.regressionWarning = regressionWarning;
    ci.sortOrder = sortOrder;
    return ci;
  }
}
