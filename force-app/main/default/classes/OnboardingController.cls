/**
 * @description Controller for the Onboarding Wizard and org discovery.
 *              Provides org discovery (stages, record types, hierarchy, currency),
 *              configuration activation, and CMT async deployment.
 *              Spec: ADMIN_SETUP_SPEC.md V1.2 §2
 */
public with sharing class OnboardingController {
  // ══════════════════════════════════════════════════════════════════════
  //  ORG DISCOVERY
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Discover the org's Salesforce configuration for onboarding.
   *              Returns stages, record types, hierarchy info, currency, fiscal year,
   *              user count, and pipeline volume.
   */
  @AuraEnabled(cacheable=true)
  public static OrgDiscoveryResult discoverOrg() {
    OrgDiscoveryResult result = new OrgDiscoveryResult();

    // 1. Opportunity stages (global picklist)
    result.stages = new List<StageInfo>();
    Schema.DescribeFieldResult stageField = Opportunity.StageName.getDescribe();
    for (Schema.PicklistEntry pe : stageField.getPicklistValues()) {
      if (pe.isActive()) {
        result.stages.add(new StageInfo(pe.getLabel(), pe.getValue()));
      }
    }

    // Determine closed stages from OpportunityStage SObject
    result.closedWonStages = new List<String>();
    result.closedLostStages = new List<String>();
    for (OpportunityStage os : [
      SELECT MasterLabel, ApiName, IsClosed, IsWon, IsActive
      FROM OpportunityStage
      WHERE IsActive = TRUE
    ]) {
      if (os.IsWon) {
        result.closedWonStages.add(os.ApiName);
      } else if (os.IsClosed) {
        result.closedLostStages.add(os.ApiName);
      }
    }

    // 2. Opportunity Record Types
    result.recordTypes = new List<RecordTypeInfo>();
    for (
      Schema.RecordTypeInfo rti : Opportunity.SObjectType.getDescribe()
        .getRecordTypeInfos()
    ) {
      if (rti.isAvailable() && !rti.isMaster()) {
        result.recordTypes.add(
          new RecordTypeInfo(
            rti.getRecordTypeId(),
            rti.getName(),
            rti.getDeveloperName()
          )
        );
      }
    }

    // 2b. Stages per Record Type (Phase A — true RT-aware stage discovery)
    // Uses the validFor decoding pattern: each PicklistEntry has a Base64-encoded
    // bitmap indicating which RTs it applies to. This gives accurate RT→stages mapping.
    result.stagesByRecordType = buildStagesByRecordType(stageField);

    // 3. Hierarchy detection
    result.hasRoleHierarchy = Schema.SObjectType.UserRole.isAccessible();
    try {
      Integer roleCount = [
        SELECT COUNT()
        FROM UserRole
        WHERE PortalType = 'None'
      ];
      result.roleCount = roleCount;
    } catch (Exception ex) {
      result.roleCount = 0;
    }

    // Check Territory Management
    result.hasTerritoryManagement = false;
    try {
      Schema.getGlobalDescribe().get('Territory2');
      result.hasTerritoryManagement = true;
    } catch (Exception ex) {
      // Territory2 not available
    }

    // 3b. Hierarchy source label (Phase A — explicit terminology)
    // Default for newly-discovered orgs is Role Hierarchy when available
    if (result.hasRoleHierarchy && result.roleCount > 0) {
      result.hierarchySourceLabel = 'Role Hierarchy';
    } else if (result.hasTerritoryManagement) {
      result.hierarchySourceLabel = 'Territory Management';
    } else {
      result.hierarchySourceLabel = 'Manager Field (User.ManagerId)';
    }

    // 4. Currency
    result.isMultiCurrency = UserInfo.isMultiCurrencyOrganization();
    try {
      Organization org = [
        SELECT
          FiscalYearStartMonth,
          UsesStartDateAsFiscalYearName,
          DefaultLocaleSidKey
        FROM Organization
        LIMIT 1
      ];
      result.fiscalYearStartMonth = org.FiscalYearStartMonth;
      result.usesFiscalYearStartAsName = org.UsesStartDateAsFiscalYearName;
      result.defaultLocale = org.DefaultLocaleSidKey;
    } catch (Exception ex) {
      result.fiscalYearStartMonth = 1;
      result.usesFiscalYearStartAsName = false;
      result.defaultLocale = 'en_US';
    }
    // UserInfo.getDefaultCurrency() works for both single- and multi-currency orgs
    try {
      String currencyCode = UserInfo.getDefaultCurrency();
      result.corporateCurrency = String.isNotBlank(currencyCode)
        ? currencyCode
        : 'USD';
    } catch (Exception ex) {
      result.corporateCurrency = 'USD';
    }

    // 4b. Fiscal year start month name (Phase A — show "January" not "Month 1")
    result.fiscalYearStartMonthName = monthName(result.fiscalYearStartMonth);

    // 5. User count — Phase A: exclude integration/system/community/Chatter users
    result.activeUserCount = [
      SELECT COUNT()
      FROM User
      WHERE
        IsActive = TRUE
        AND UserType = 'Standard'
        AND Profile.Name NOT IN (
          'Chatter Free User',
          'Chatter External User',
          'Analytics Cloud Integration User',
          'Analytics Cloud Security User',
          'Customer Community User',
          'Partner Community User'
        )
        AND Profile.UserLicense.Name NOT IN ('Chatter Free', 'Chatter External')
    ];

    // 6. Pipeline volume
    result.openPipelineCount = [
      SELECT COUNT()
      FROM Opportunity
      WHERE IsClosed = FALSE
    ];

    // 6b. Phase B: Child objects of Opportunity (for grouping + multi-source metrics)
    result.oppChildObjects = discoverOpportunityChildObjects();

    // 6c. Parent objects of Opportunity (for display fields — Account, Campaign, etc.)
    result.oppParentObjects = discoverOpportunityParentObjects();

    // 7. Hierarchy levels detection (from Role Hierarchy depth)
    result.detectedLevels = new List<LevelInfo>();
    if (result.roleCount > 0) {
      // Walk role hierarchy to detect levels
      Map<Id, UserRole> roleMap = new Map<Id, UserRole>(
        [SELECT Id, Name, ParentRoleId FROM UserRole WHERE PortalType = 'None']
      );
      Map<Integer, String> levelNames = new Map<Integer, String>();
      for (UserRole role : roleMap.values()) {
        Integer depth = 1;
        Id parentId = role.ParentRoleId;
        while (parentId != null && depth < 10) {
          depth++;
          UserRole parent = roleMap.get(parentId);
          if (parent != null) {
            parentId = parent.ParentRoleId;
          } else {
            break;
          }
        }
        if (!levelNames.containsKey(depth) || levelNames.get(depth) == null) {
          levelNames.put(depth, role.Name);
        }
      }
      Integer maxLevel = 0;
      for (Integer lvl : levelNames.keySet()) {
        if (lvl > maxLevel)
          maxLevel = lvl;
      }
      // Invert: deepest = L1 (Rep), root = L(max)
      for (Integer lvl = 1; lvl <= maxLevel; lvl++) {
        String suggestedLabel = 'Level ' + lvl;
        if (lvl == 1)
          suggestedLabel = 'Sales Rep';
        else if (lvl == 2)
          suggestedLabel = 'Manager';
        else if (lvl == 3)
          suggestedLabel = 'Director';
        else if (lvl == 4)
          suggestedLabel = 'VP';
        else if (lvl == 5)
          suggestedLabel = 'SVP / CRO';
        result.detectedLevels.add(new LevelInfo(lvl, suggestedLabel));
      }
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CONFIGURATION ACTIVATION
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Check if an active forecast configuration exists.
   *              Used by revtForecastApp to decide: show wizard or show grid.
   */
  @AuraEnabled(cacheable=true)
  public static Boolean hasActiveConfig() {
    return ForecastDataService.getActiveConfig() != null;
  }

  /**
   * @description Activate the forecast configuration from the onboarding wizard.
   *              Creates config, metrics, categories, periods, and initial participants.
   * @return The new Forecast_Configuration__c Id
   */
  @AuraEnabled
  public static Id activateConfiguration(
    String configName,
    String hierarchySource,
    String periodType,
    Integer futurePeriods,
    Integer fiscalYearStartMonth,
    String attainmentSource,
    String currencyMode,
    String corporateCurrency,
    String topLevelLockLabel,
    Integer paginationSize,
    String pipelineRecordTypeFilter,
    String levelLabelsJson,
    String metricsJson,
    String categoriesJson,
    String scopeCustomObject,
    String scopeCustomField,
    String groupsJson,
    Integer pastPeriodsVisible,
    String defaultHorizon,
    Integer customHorizonPeriods,
    String finalForecastLabel,
    String stretchForecastLabel,
    String forecastCadence,
    String submissionDeadlineDay,
    Boolean autoFreezeOnDeadline,
    Date cadenceAnchorDate,
    String displayFieldsJson
  ) {
    try {
      // 0. Reconfigure: deactivate any existing active config and all its
      //    children. Historical data (overrides, snapshots, attainment)
      //    remains linked to the old config for audit/reporting.
      List<Forecast_Configuration__c> existing = [
        SELECT Id
        FROM Forecast_Configuration__c
        WHERE Is_Active__c = TRUE
        LIMIT 1
      ];
      if (!existing.isEmpty()) {
        Id oldId = existing[0].Id;
        // Deactivate children — preserve for historical reference
        List<Forecast_Category__c> oldCats = [
          SELECT Id, Is_Active__c
          FROM Forecast_Category__c
          WHERE Forecast_Configuration__c = :oldId AND Is_Active__c = TRUE
        ];
        for (Forecast_Category__c c : oldCats) {
          c.Is_Active__c = false;
        }
        if (!oldCats.isEmpty()) {
          update oldCats;
        }

        List<Forecast_Group__c> oldGroups = [
          SELECT Id, Is_Active__c
          FROM Forecast_Group__c
          WHERE Forecast_Configuration__c = :oldId AND Is_Active__c = TRUE
        ];
        for (Forecast_Group__c g : oldGroups) {
          g.Is_Active__c = false;
        }
        if (!oldGroups.isEmpty()) {
          update oldGroups;
        }

        // Mark old config inactive
        existing[0].Is_Active__c = false;
        update existing[0];
      }

      // 1. Create configuration
      Forecast_Configuration__c config = new Forecast_Configuration__c();
      config.Name = String.isNotBlank(configName)
        ? configName
        : 'Default Configuration';
      config.Is_Active__c = true;
      config.Period_Type__c = periodType != null ? periodType : 'Monthly';
      config.Future_Periods_Visible__c = futurePeriods != null
        ? futurePeriods
        : 3;
      config.Fiscal_Year_Start_Month__c = fiscalYearStartMonth != null
        ? fiscalYearStartMonth
        : 1;
      config.Attainment_Source__c = attainmentSource != null
        ? attainmentSource
        : 'Forecast_Quota_With_Live';
      config.Currency_Mode__c = currencyMode != null ? currencyMode : 'Single';
      config.Corporate_Currency__c = corporateCurrency != null
        ? corporateCurrency
        : 'USD';
      config.Top_Level_Lock_Label__c = topLevelLockLabel != null
        ? topLevelLockLabel
        : 'Freeze';
      config.Pagination_Size__c = paginationSize != null ? paginationSize : 40;
      config.Scope_Determination__c = hierarchySource != null
        ? hierarchySource
        : 'Ownership';
      config.Pipeline_Record_Type_Filter__c = pipelineRecordTypeFilter;
      config.Level_Labels__c = levelLabelsJson;
      config.Hourly_Snapshot_Days__c = 3;
      config.Hourly_Snapshot_Interval__c = 4;
      // Phase A: capture custom field scope when hierarchy source is Custom_Field
      if (hierarchySource == 'Custom_Field') {
        config.Scope_Custom_Object__c = scopeCustomObject;
        config.Scope_Custom_Field__c = scopeCustomField;
      }
      // Phase C: past periods + horizon + Final/Stretch labels
      config.Past_Periods_Visible__c = pastPeriodsVisible != null
        ? pastPeriodsVisible
        : 2;
      config.Default_Horizon__c = String.isNotBlank(defaultHorizon)
        ? defaultHorizon
        : 'Current_Period';
      if (customHorizonPeriods != null) {
        config.Custom_Horizon_Periods__c = customHorizonPeriods;
      }
      config.Final_Forecast_Label__c = String.isNotBlank(finalForecastLabel)
        ? finalForecastLabel
        : 'Final Forecast';
      config.Stretch_Forecast_Label__c = String.isNotBlank(stretchForecastLabel)
        ? stretchForecastLabel
        : 'Stretch Forecast';
      // Phase D: Forecast Cadence
      if (String.isNotBlank(forecastCadence)) {
        config.Forecast_Cadence__c = forecastCadence;
      }
      if (String.isNotBlank(submissionDeadlineDay)) {
        config.Submission_Deadline_Day__c = submissionDeadlineDay;
      }
      config.Auto_Freeze_On_Deadline__c = autoFreezeOnDeadline == true;
      config.Cadence_Anchor_Date__c = cadenceAnchorDate != null
        ? cadenceAnchorDate
        : Date.today();
      insert config;

      // Phase D: Create system display fields (core grid columns)
      List<Forecast_Display_Field__c> systemFields = new List<Forecast_Display_Field__c>();
      systemFields.add(
        createSystemField(
          config.Id,
          'Amount',
          'Opportunity',
          'Amount',
          'Currency',
          1
        )
      );
      systemFields.add(
        createSystemField(
          config.Id,
          'Close Date',
          'Opportunity',
          'CloseDate',
          'Date',
          2
        )
      );
      systemFields.add(
        createSystemField(
          config.Id,
          'Owner',
          'Opportunity',
          'OwnerId',
          'Lookup',
          3
        )
      );
      systemFields.add(
        createSystemField(
          config.Id,
          'Stage',
          'Opportunity',
          'StageName',
          'Picklist',
          4
        )
      );
      insert systemFields;

      // Phase D: Create custom display fields from wizard
      if (String.isNotBlank(displayFieldsJson)) {
        List<Map<String, Object>> dfInputs = (List<Map<String, Object>>) JSON.deserializeUntyped(
          displayFieldsJson
        );
        List<Forecast_Display_Field__c> customFields = new List<Forecast_Display_Field__c>();
        Integer nextOrder = 5; // after 4 system fields
        for (Map<String, Object> dfi : dfInputs) {
          Forecast_Display_Field__c df = new Forecast_Display_Field__c();
          df.Forecast_Configuration__c = config.Id;
          df.Name = (String) dfi.get('fieldLabel');
          df.Field_Label__c = (String) dfi.get('fieldLabel');
          df.Object_API_Name__c = (String) dfi.get('objectApiName');
          df.Field_API_Name__c = (String) dfi.get('fieldApiName');
          df.Display_Location__c = (String) dfi.get('displayLocation');
          df.Sort_Order__c = nextOrder++;
          df.Column_Width__c = 'Medium';
          df.Is_Active__c = true;
          df.Is_System__c = false;
          customFields.add(df);
        }
        if (!customFields.isEmpty()) {
          insert customFields;
        }
      }

      // 2a. Phase B: Create groups FIRST (so metrics can link to them).
      // Always create at least the auto "All Opportunities" group.
      Map<String, Id> groupIdByName = createGroups(config.Id, groupsJson);

      // 2b. Create metrics (from JSON array). Link to group when groupName is specified.
      if (String.isNotBlank(metricsJson)) {
        List<MetricInput> metricInputs = (List<MetricInput>) JSON.deserialize(
          metricsJson,
          List<MetricInput>.class
        );
        List<Forecast_Metric__c> metrics = new List<Forecast_Metric__c>();
        for (MetricInput mi : metricInputs) {
          Forecast_Metric__c m = new Forecast_Metric__c();
          m.Forecast_Configuration__c = config.Id;
          m.Name = mi.name;
          m.Metric_Label__c = mi.label;
          m.Metric_Type__c = mi.metricType;
          m.Display_Format__c = mi.displayFormat;
          m.Is_Primary__c = mi.isPrimary;
          m.Is_Required__c = mi.isRequired;
          m.Is_Editable__c = mi.isEditable;
          m.Sort_Order__c = mi.sortOrder;
          m.Source_Field__c = mi.sourceField;
          // Phase B: multi-source object support
          m.Source_Object__c = String.isNotBlank(mi.sourceObject)
            ? mi.sourceObject
            : 'Opportunity';
          m.Source_Lookup_Field__c = mi.sourceLookupField;
          m.Aggregation__c = mi.aggregation;
          // Phase B: link to group (null = config-wide / applies to all groups)
          if (
            String.isNotBlank(mi.groupName) &&
            groupIdByName.containsKey(mi.groupName)
          ) {
            m.Forecast_Group__c = groupIdByName.get(mi.groupName);
          }
          metrics.add(m);
        }
        if (!metrics.isEmpty()) {
          insert metrics;
          // Phase B: insert structured filter clauses for each metric
          insertMetricFilters(metrics, metricInputs);
        }
      }

      // 3. Create categories (from JSON array)
      if (String.isNotBlank(categoriesJson)) {
        List<CategoryInput> categoryInputs = (List<CategoryInput>) JSON.deserialize(
          categoriesJson,
          List<CategoryInput>.class
        );
        List<Forecast_Category__c> categories = new List<Forecast_Category__c>();
        for (CategoryInput ci : categoryInputs) {
          Forecast_Category__c c = new Forecast_Category__c();
          c.Forecast_Configuration__c = config.Id;
          c.Name = ci.name;
          c.Category_Label__c = ci.label;
          c.Category_API_Name__c = ci.apiName;
          c.Color_Hex__c = ci.color;
          c.Is_Active__c = true;
          c.Counts_Toward_Target__c = ci.countsTowardTarget;
          // Phase C: independent Stretch flag
          c.Counts_Toward_Stretch__c = ci.countsTowardStretch == true;
          c.Is_Terminal__c = ci.isTerminal;
          c.Is_High_Confidence__c = ci.isHighConfidence;
          c.Regression_Warning__c = ci.regressionWarning;
          c.Sort_Order__c = ci.sortOrder;
          categories.add(c);
        }
        if (!categories.isEmpty()) {
          insert categories;
        }
      }

      // 4. Create current open period + future scheduled periods
      Id currentPeriodId = ForecastPeriodService.createCurrentPeriod(
        config.Period_Type__c,
        config.Id
      );

      Integer futureCount = config.Future_Periods_Visible__c != null
        ? config.Future_Periods_Visible__c.intValue()
        : 3;
      ForecastPeriodService.createFuturePeriods(
        futureCount,
        config.Period_Type__c,
        config.Id,
        null
      );

      // 5. Initialize participants for the current period
      Database.executeBatch(
        new ForecastInitializationBatch(currentPeriodId),
        200
      );

      // 6. Clear config cache so the forecast tab picks up the new config
      ForecastDataService.clearConfigCache();

      return config.Id;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CMT DEPLOYMENT (async)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Deploy a Custom Metadata Type record update asynchronously.
   *              Supports multiple fields via JSON map.
   *              Used for Hierarchy_Source__mdt and Field_Mapping__mdt updates.
   * @param cmtFullName Full name e.g. 'Hierarchy_Source__mdt.Default'
   * @param fieldValuesJson JSON map of field name to value e.g. '{"Source_Type__c":"ManagerChain","Level_Count__c":"5"}'
   * @return The deployment job Id for polling
   */
  @AuraEnabled
  public static String deployCmtUpdate(
    String cmtFullName,
    String fieldValuesJson
  ) {
    try {
      Metadata.CustomMetadata cmRecord = new Metadata.CustomMetadata();
      cmRecord.fullName = cmtFullName;
      cmRecord.label = cmtFullName.substringAfter('.');

      Map<String, Object> fieldValues = (Map<String, Object>) JSON.deserializeUntyped(
        fieldValuesJson
      );
      for (String fieldName : fieldValues.keySet()) {
        Metadata.CustomMetadataValue cmValue = new Metadata.CustomMetadataValue();
        cmValue.field = fieldName;
        cmValue.value = fieldValues.get(fieldName);
        cmRecord.values.add(cmValue);
      }

      Metadata.DeployContainer container = new Metadata.DeployContainer();
      container.addMetadata(cmRecord);

      Id deployId = Metadata.Operations.enqueueDeployment(container, null);
      return String.valueOf(deployId);
    } catch (Exception e) {
      throw new AuraHandledException(
        'CMT deployment failed: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Check the status of a CMT deployment by re-reading the CMT record.
   *              Since DeployRequest is not queryable in all contexts, we verify
   *              by checking if the CMT value was actually updated.
   * @return 'Succeeded' if CMT reflects expected value, 'Pending' otherwise
   */
  @AuraEnabled
  public static String checkDeployStatus(
    String cmtFullName,
    String fieldName,
    String expectedValue
  ) {
    try {
      // Re-read the CMT to see if the value updated
      String typeName = cmtFullName.substringBefore('.');
      String recordName = cmtFullName.substringAfter('.');
      String query =
        'SELECT ' +
        String.escapeSingleQuotes(fieldName) +
        ' FROM ' +
        String.escapeSingleQuotes(typeName) +
        ' WHERE DeveloperName = \'' +
        String.escapeSingleQuotes(recordName) +
        '\'' +
        ' LIMIT 1';
      List<SObject> records = Database.query(query);
      if (!records.isEmpty()) {
        Object currentValue = records[0].get(fieldName);
        if (String.valueOf(currentValue) == expectedValue) {
          return 'Succeeded';
        }
      }
      return 'Pending';
    } catch (Exception e) {
      return 'Pending';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  INPUT DTOs (for JSON deserialization)
  // ══════════════════════════════════════════════════════════════════════

  public class MetricInput {
    public String name;
    public String label;
    public String metricType;
    public String displayFormat;
    public Boolean isPrimary;
    public Boolean isRequired;
    public Boolean isEditable;
    public Integer sortOrder;
    public String sourceField;
    // Phase B additions:
    public String sourceObject; // 'Opportunity' (default) | 'OpportunityLineItem' | etc.
    public String sourceLookupField; // FK to Opportunity (when sourceObject != Opportunity)
    public String aggregation; // Sum / Average / Count / Max / Min
    public String groupName; // Optional: links to GroupInput.name; null = config-wide
    public List<FilterInput> filters; // Optional structured filter clauses
  }

  /**
   * @description Phase B: Forecast_Group__c input for activateConfiguration.
   */
  public class GroupInput {
    public String name;
    public String groupType; // 'All' | 'Record_Type' | 'Custom_Field'
    public String recordTypeNames; // Comma-separated RT DeveloperNames
    public String groupSourceObject; // For Custom_Field: object holding the group field
    public String groupLookupField; // For Custom_Field: FK back to Opportunity
    public String groupField; // For Custom_Field: field to filter by
    public String groupFieldValues; // Comma-separated picklist values
    public Boolean overrideStages;
    public String closedWonStages;
    public String closedLostStages;
    public Integer sortOrder;
  }

  /**
   * @description Phase B: Filter clause input nested inside MetricInput.
   */
  public class FilterInput {
    public String fieldApiName;
    public String operatorValue; // Picklist API name: EQUALS, IN, etc.
    public String value; // Per Value__c serialization contract
    public String logicalOperator; // AND / OR (last clause's value ignored)
    public Integer sortOrder;
  }

  public class CategoryInput {
    public String name;
    public String label;
    public String apiName;
    public String color;
    public Boolean countsTowardTarget;
    // Phase C: independent Stretch flag (Counts_Toward_Target__c remains canonical for Final)
    public Boolean countsTowardStretch;
    public Boolean isTerminal;
    public Boolean isHighConfidence;
    public Boolean regressionWarning;
    public Integer sortOrder;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  RESULT DTOs (for org discovery)
  // ══════════════════════════════════════════════════════════════════════

  public class OrgDiscoveryResult {
    @AuraEnabled
    public List<StageInfo> stages;
    @AuraEnabled
    public List<String> closedWonStages;
    @AuraEnabled
    public List<String> closedLostStages;
    @AuraEnabled
    public List<RecordTypeInfo> recordTypes;
    @AuraEnabled
    public Map<String, List<StageInfo>> stagesByRecordType;
    @AuraEnabled
    public Boolean hasRoleHierarchy;
    @AuraEnabled
    public Integer roleCount;
    @AuraEnabled
    public Boolean hasTerritoryManagement;
    @AuraEnabled
    public String hierarchySourceLabel;
    @AuraEnabled
    public Boolean isMultiCurrency;
    @AuraEnabled
    public Integer fiscalYearStartMonth;
    @AuraEnabled
    public String fiscalYearStartMonthName;
    @AuraEnabled
    public String corporateCurrency;
    @AuraEnabled
    public Boolean usesFiscalYearStartAsName;
    @AuraEnabled
    public String defaultLocale;
    @AuraEnabled
    public Integer activeUserCount;
    @AuraEnabled
    public Integer openPipelineCount;
    @AuraEnabled
    public List<LevelInfo> detectedLevels;
    @AuraEnabled
    public List<ChildObjectInfo> oppChildObjects;
    @AuraEnabled
    public List<ChildObjectInfo> oppParentObjects;
  }

  /**
   * @description Phase B: child object of Opportunity, surfaced in wizard for grouping
   *              and multi-source metrics. Tier classifies recommended/standard/advanced.
   */
  public class ChildObjectInfo {
    @AuraEnabled
    public String objectApiName;
    @AuraEnabled
    public String objectLabel;
    @AuraEnabled
    public String lookupFieldApiName; // FK back to Opportunity
    @AuraEnabled
    public String tier; // 'Recommended' | 'Standard' | 'Advanced'
  }

  /**
   * @description Convert month number (1-12) to month name (e.g., 1 → "January").
   */
  private static String monthName(Integer month) {
    if (month == null || month < 1 || month > 12) {
      return 'January';
    }
    List<String> names = new List<String>{
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
    return names[month - 1];
  }

  // ══════════════════════════════════════════════════════════════════════
  //  RT-AWARE STAGE DISCOVERY (Phase A)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Wrapper used to deserialize Schema.PicklistEntry and access
   *              the validFor field, which is not exposed via the standard
   *              Apex Schema describe API.
   */
  private class PicklistEntryWrapper {
    public String label;
    public String value;
    public Boolean active;
    public Boolean defaultValue;
    public String validFor; // Base64-encoded bitmap; bits map to non-master RTs in describe order
  }

  /**
   * @description Build a map of RecordType DeveloperName → list of StageInfo,
   *              honoring per-RT picklist value restrictions. Uses the validFor
   *              bitmap that Salesforce embeds in serialized PicklistEntry objects.
   *
   *              Each picklist entry has a Base64-encoded validFor bitmap. Each bit
   *              corresponds to a non-master RecordTypeInfo in the order returned by
   *              getRecordTypeInfos(). If the bit is set, the entry applies to that RT.
   *              If validFor is blank, the entry applies to all RTs (no restriction).
   */
  private static Map<String, List<StageInfo>> buildStagesByRecordType(
    Schema.DescribeFieldResult stageField
  ) {
    Map<String, List<StageInfo>> mapByRT = new Map<String, List<StageInfo>>();
    Schema.DescribeSObjectResult oppDesc = Opportunity.SObjectType.getDescribe();

    // Ordered list of non-master RT infos — order matches validFor bit indexes
    List<Schema.RecordTypeInfo> orderedRTs = new List<Schema.RecordTypeInfo>();
    for (Schema.RecordTypeInfo rti : oppDesc.getRecordTypeInfos()) {
      if (!rti.isMaster()) {
        orderedRTs.add(rti);
        mapByRT.put(rti.getDeveloperName(), new List<StageInfo>());
      }
    }
    if (orderedRTs.isEmpty()) {
      return mapByRT;
    }

    // Decode each entry's validFor and assign to matching RTs
    for (Schema.PicklistEntry pe : stageField.getPicklistValues()) {
      if (!pe.isActive()) {
        continue;
      }

      PicklistEntryWrapper wrapped;
      try {
        wrapped = (PicklistEntryWrapper) JSON.deserialize(
          JSON.serialize(pe),
          PicklistEntryWrapper.class
        );
      } catch (Exception ex) {
        // If serialization fails for any reason, fall back to including in all RTs
        for (Schema.RecordTypeInfo rti : orderedRTs) {
          mapByRT.get(rti.getDeveloperName())
            .add(new StageInfo(pe.getLabel(), pe.getValue()));
        }
        continue;
      }

      if (String.isBlank(wrapped.validFor)) {
        // No RT restrictions — applies to all RTs
        for (Schema.RecordTypeInfo rti : orderedRTs) {
          mapByRT.get(rti.getDeveloperName())
            .add(new StageInfo(pe.getLabel(), pe.getValue()));
        }
        continue;
      }

      // Decode validFor Base64 → hex → check bit per RT index (MSB order within each byte)
      String hex = EncodingUtil.convertToHex(
        EncodingUtil.base64Decode(wrapped.validFor)
      );
      for (Integer rtIdx = 0; rtIdx < orderedRTs.size(); rtIdx++) {
        Integer byteIdx = rtIdx / 8;
        Integer bitIdx = 7 - Math.mod(rtIdx, 8);
        if ((byteIdx * 2 + 1) >= hex.length()) {
          continue;
        }
        Integer byteVal = hexByteToInt(
          hex.substring(byteIdx * 2, byteIdx * 2 + 2)
        );
        if ((byteVal & (1 << bitIdx)) != 0) {
          Schema.RecordTypeInfo rti = orderedRTs[rtIdx];
          mapByRT.get(rti.getDeveloperName())
            .add(new StageInfo(pe.getLabel(), pe.getValue()));
        }
      }
    }

    return mapByRT;
  }

  /**
   * @description Convert a 2-character hex string (e.g., "1f") to its integer value (0-255).
   *              Apex's Integer.valueOf does not accept a radix, so we parse manually.
   */
  private static Integer hexByteToInt(String hex) {
    if (String.isBlank(hex) || hex.length() != 2) {
      return 0;
    }
    return hexCharToInt(hex.substring(0, 1)) * 16 +
      hexCharToInt(hex.substring(1, 2));
  }

  // ══════════════════════════════════════════════════════════════════════
  //  GROUP + FILTER CREATION (Phase B)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Create Forecast_Group__c records for the new config.
   *              Always creates at least the auto "All Opportunities" group so every
   *              override can reference a concrete group.
   *
   * @return Map of group name → group Id, used to link metrics to their groups.
   */
  private static Map<String, Id> createGroups(Id configId, String groupsJson) {
    Map<String, Id> idByName = new Map<String, Id>();
    List<Forecast_Group__c> toInsert = new List<Forecast_Group__c>();

    // Parse groupsJson if provided
    List<GroupInput> inputs = new List<GroupInput>();
    if (String.isNotBlank(groupsJson)) {
      try {
        inputs = (List<GroupInput>) JSON.deserialize(
          groupsJson,
          List<GroupInput>.class
        );
      } catch (Exception ex) {
        throw new AuraHandledException(
          'Invalid groupsJson: ' + ex.getMessage()
        );
      }
    }

    // Always ensure at least one default "All Opportunities" group exists
    if (inputs == null || inputs.isEmpty()) {
      GroupInput defaultGroup = new GroupInput();
      defaultGroup.name = 'All Opportunities';
      defaultGroup.groupType = 'All';
      defaultGroup.sortOrder = 1;
      defaultGroup.overrideStages = false;
      inputs = new List<GroupInput>{ defaultGroup };
    }

    for (GroupInput g : inputs) {
      Forecast_Group__c grp = new Forecast_Group__c();
      grp.Forecast_Configuration__c = configId;
      grp.Name = String.isNotBlank(g.name) ? g.name : 'All Opportunities';
      grp.Group_Type__c = String.isNotBlank(g.groupType) ? g.groupType : 'All';
      grp.Record_Type_Names__c = g.recordTypeNames;
      grp.Group_Source_Object__c = g.groupSourceObject;
      grp.Group_Lookup_Field__c = g.groupLookupField;
      grp.Group_Field__c = g.groupField;
      grp.Group_Field_Values__c = g.groupFieldValues;
      grp.Override_Stages__c = g.overrideStages == true;
      grp.Closed_Won_Stages__c = g.closedWonStages;
      grp.Closed_Lost_Stages__c = g.closedLostStages;
      grp.Sort_Order__c = g.sortOrder != null ? g.sortOrder : 1;
      grp.Is_Active__c = true;
      toInsert.add(grp);
    }
    if (!toInsert.isEmpty()) {
      insert toInsert;
    }
    for (Forecast_Group__c grp : toInsert) {
      idByName.put(grp.Name, grp.Id);
    }
    return idByName;
  }

  /**
   * @description Insert Forecast_Metric_Filter__c records for each metric that
   *              has filters. Called after metrics insert so we have metric Ids.
   */
  private static void insertMetricFilters(
    List<Forecast_Metric__c> metrics,
    List<MetricInput> metricInputs
  ) {
    if (metrics == null || metrics.isEmpty()) {
      return;
    }
    List<Forecast_Metric_Filter__c> toInsert = new List<Forecast_Metric_Filter__c>();
    for (Integer i = 0; i < metrics.size(); i++) {
      Forecast_Metric__c m = metrics[i];
      MetricInput mi = i < metricInputs.size() ? metricInputs[i] : null;
      if (mi == null || mi.filters == null || mi.filters.isEmpty()) {
        continue;
      }
      for (FilterInput fi : mi.filters) {
        Forecast_Metric_Filter__c f = new Forecast_Metric_Filter__c();
        f.Forecast_Metric__c = m.Id;
        f.Field_API_Name__c = fi.fieldApiName;
        f.Operator__c = fi.operatorValue;
        f.Value__c = fi.value;
        f.Logical_Operator__c = String.isNotBlank(fi.logicalOperator)
          ? fi.logicalOperator
          : 'AND';
        f.Sort_Order__c = fi.sortOrder != null ? fi.sortOrder : 1;
        toInsert.add(f);
      }
    }
    if (!toInsert.isEmpty()) {
      insert toInsert;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CHILD OBJECT DISCOVERY (Phase B)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description System objects that are NEVER surfaced as forecast source objects,
   *              regardless of having a lookup to Opportunity. Drawn from the spec's denylist.
   */
  private static final Set<String> SYSTEM_DENYLIST = new Set<String>{
    'FeedItem',
    'FeedComment',
    'FeedAttachment',
    'ContentDocumentLink',
    'ContentVersion',
    'Attachment',
    'Note',
    'AttachedContentDocument',
    'EmailMessage',
    'EmailRelation',
    'Task',
    'Event',
    'ProcessInstance',
    'ProcessInstanceStep',
    'ProcessInstanceWorkitem',
    'TopicAssignment',
    'EntitySubscription',
    'OpportunityHistory',
    'OpportunityFieldHistory',
    'OpportunityShare',
    'OpportunityFeed',
    'ActivityHistory',
    'OpenActivity',
    'CombinedAttachment',
    'OpportunityChangeEvent'
  };

  /** Namespace prefix for our managed package — exclude from child object discovery. */
  private static final String REVT_PREFIX = 'REVT__';

  /** Standard audit / system fields excluded from all field pickers. */
  private static final Set<String> AUDIT_FIELD_SKIP = new Set<String>{
    'Id',
    'IsDeleted',
    'SystemModstamp',
    'CreatedById',
    'CreatedDate',
    'LastModifiedById',
    'LastModifiedDate',
    'LastActivityDate',
    'LastViewedDate',
    'LastReferencedDate'
  };

  /**
   * @description Tier 1 (Recommended): standard pipeline + detected CPQ packages.
   */
  private static final Set<String> TIER_RECOMMENDED = new Set<String>{
    'OpportunityLineItem',
    'QuoteLineItem',
    'Quote',
    'Order',
    'Contract',
    'SBQQ__QuoteLine__c',
    'conga__QuoteLine__c',
    'Apttus__QuoteLine__c',
    'blng__InvoiceLine__c'
  };

  /**
   * @description Discover all child objects of Opportunity (objects with a lookup
   *              or master-detail to Opportunity), classified by tier with the
   *              FK back to Opportunity auto-detected. Respects denylist.
   */
  private static List<ChildObjectInfo> discoverOpportunityChildObjects() {
    List<ChildObjectInfo> result = new List<ChildObjectInfo>();
    Schema.DescribeSObjectResult oppDesc = Opportunity.SObjectType.getDescribe();
    Set<String> seen = new Set<String>();

    for (Schema.ChildRelationship cr : oppDesc.getChildRelationships()) {
      Schema.SObjectType childType = cr.getChildSObject();
      if (childType == null) {
        continue;
      }
      Schema.DescribeSObjectResult childDesc;
      try {
        childDesc = childType.getDescribe();
      } catch (Exception ex) {
        continue;
      }
      String objName = childDesc.getName();
      if (seen.contains(objName)) {
        continue;
      }
      seen.add(objName);

      if (SYSTEM_DENYLIST.contains(objName)) {
        continue;
      }
      // Exclude our own managed package objects — they are internal, not business data
      if (objName.startsWith(REVT_PREFIX)) {
        continue;
      }
      if (!childDesc.isQueryable() || !childDesc.isAccessible()) {
        continue;
      }
      if (!hasNumericField(childDesc)) {
        continue;
      }

      Schema.SObjectField fkField = cr.getField();
      if (fkField == null) {
        continue;
      }

      ChildObjectInfo info = new ChildObjectInfo();
      info.objectApiName = objName;
      info.objectLabel = childDesc.getLabel();
      info.lookupFieldApiName = fkField.getDescribe().getName();
      info.tier = classifyTier(objName);
      result.add(info);
    }
    return result;
  }

  /**
   * @description Discover parent objects of Opportunity by scanning Reference (Lookup/MD) fields.
   *              Returns objects like Account, Campaign, Contact, PriceBook2, etc.
   *              Used by Display Fields to let admins add parent object fields to the grid.
   */
  private static List<ChildObjectInfo> discoverOpportunityParentObjects() {
    List<ChildObjectInfo> result = new List<ChildObjectInfo>();
    Set<String> seen = new Set<String>();

    // Skip system/internal objects and Opportunity itself
    Set<String> SKIP_OBJECTS = new Set<String>{
      'Opportunity',
      'RecordType',
      'BusinessProcess',
      'Profile',
      'UserRole',
      'Organization',
      'Group'
    };

    Schema.DescribeSObjectResult oppDesc = Opportunity.SObjectType.getDescribe();
    for (Schema.SObjectField f : oppDesc.fields.getMap().values()) {
      Schema.DescribeFieldResult dfr = f.getDescribe();
      if (dfr.getType() != Schema.DisplayType.REFERENCE) {
        continue;
      }
      if (!dfr.isAccessible()) {
        continue;
      }

      List<Schema.SObjectType> refs = dfr.getReferenceTo();
      if (refs.isEmpty()) {
        continue;
      }

      Schema.DescribeSObjectResult refDesc;
      try {
        refDesc = refs[0].getDescribe();
      } catch (Exception ex) {
        continue;
      }

      String objName = refDesc.getName();
      if (seen.contains(objName)) {
        continue;
      }
      if (SKIP_OBJECTS.contains(objName)) {
        continue;
      }
      if (objName.startsWith(REVT_PREFIX)) {
        continue;
      }
      if (!refDesc.isQueryable() || !refDesc.isAccessible()) {
        continue;
      }

      seen.add(objName);

      ChildObjectInfo info = new ChildObjectInfo();
      info.objectApiName = objName;
      info.objectLabel = refDesc.getLabel();
      info.lookupFieldApiName = dfr.getName(); // e.g., AccountId
      info.tier = 'Parent';
      result.add(info);
    }
    return result;
  }

  /**
   * @description True if the object has at least one Currency or Number field
   *              (otherwise no quantitative metric value to roll up).
   */
  private static Boolean hasNumericField(
    Schema.DescribeSObjectResult childDesc
  ) {
    for (Schema.SObjectField f : childDesc.fields.getMap().values()) {
      Schema.DisplayType t = f.getDescribe().getType();
      if (
        t == Schema.DisplayType.CURRENCY ||
        t == Schema.DisplayType.DOUBLE ||
        t == Schema.DisplayType.INTEGER ||
        t == Schema.DisplayType.LONG ||
        t == Schema.DisplayType.PERCENT
      ) {
        return true;
      }
    }
    return false;
  }

  /**
   * @description Classify a child object into Recommended / Standard / Advanced tier.
   *              - Recommended: standard pipeline + detected CPQ packages (TIER_RECOMMENDED)
   *              - Standard: standard objects with Opp lookup (no __c suffix)
   *              - Advanced: custom objects (suffix __c)
   */
  private static String classifyTier(String objName) {
    if (TIER_RECOMMENDED.contains(objName)) {
      return 'Recommended';
    }
    if (objName.endsWithIgnoreCase('__c')) {
      return 'Advanced';
    }
    return 'Standard';
  }

  // ══════════════════════════════════════════════════════════════════════
  //  WIZARD HELPERS — surfaced to LWC for cascading dropdowns (Phase B)
  // ══════════════════════════════════════════════════════════════════════

  /**
    /**
     * @description Return available values for a field — works for both picklist
     *              and reference (lookup/MD) fields.
     *              - Picklist: returns active picklist entries { label, value }
     *              - Reference: queries the related object for distinct records,
     *                returning { label=Name, value=Id } so the UI shows human-
     *                readable names while storing IDs internally.
     *              - String/Text: queries distinct values (up to 200) from the
     *                source object so the admin can pick from existing data.
     */
  @AuraEnabled(cacheable=true)
  public static List<StageInfo> getPicklistValues(
    String objectApiName,
    String fieldApiName
  ) {
    List<StageInfo> values = new List<StageInfo>();
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
    if (sot == null) {
      return values;
    }
    Map<String, Schema.SObjectField> fieldsMap = sot.getDescribe()
      .fields.getMap();
    Schema.SObjectField f = fieldsMap.get(fieldApiName.toLowerCase());
    if (f == null) {
      return values;
    }
    Schema.DescribeFieldResult dfr = f.getDescribe();
    Schema.DisplayType fieldType = dfr.getType();

    // ── Picklist / Multi-picklist ──
    if (
      fieldType == Schema.DisplayType.PICKLIST ||
      fieldType == Schema.DisplayType.MULTIPICKLIST
    ) {
      for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
        if (pe.isActive()) {
          values.add(new StageInfo(pe.getLabel(), pe.getValue()));
        }
      }
      return values;
    }

    // ── Reference (Lookup / Master-Detail) ──
    if (fieldType == Schema.DisplayType.REFERENCE) {
      List<Schema.SObjectType> refs = dfr.getReferenceTo();
      if (refs.isEmpty()) {
        return values;
      }
      Schema.DescribeSObjectResult refDesc = refs[0].getDescribe();
      if (!refDesc.isQueryable() || !refDesc.isAccessible()) {
        return values;
      }

      // Determine the name field (standard Name or calculated)
      String nameField = 'Name';
      Map<String, Schema.SObjectField> refFields = refDesc.fields.getMap();
      if (!refFields.containsKey('name')) {
        // Some objects use different name fields (e.g., Case uses CaseNumber)
        for (Schema.SObjectField rf : refFields.values()) {
          if (rf.getDescribe().isNameField()) {
            nameField = rf.getDescribe().getName();
            break;
          }
        }
      }

      String soql =
        'SELECT Id, ' +
        String.escapeSingleQuotes(nameField) +
        ' FROM ' +
        String.escapeSingleQuotes(refDesc.getName()) +
        ' ORDER BY ' +
        String.escapeSingleQuotes(nameField) +
        ' LIMIT 200';
      for (SObject rec : Database.query(soql)) {
        String recName = (String) rec.get(nameField);
        if (String.isNotBlank(recName)) {
          values.add(new StageInfo(recName, (String) rec.get('Id')));
        }
      }
      return values;
    }

    // ── String / Text: query distinct values from existing data ──
    if (fieldType == Schema.DisplayType.STRING) {
      String soql =
        'SELECT ' +
        String.escapeSingleQuotes(fieldApiName) +
        ' FROM ' +
        String.escapeSingleQuotes(objectApiName) +
        ' WHERE ' +
        String.escapeSingleQuotes(fieldApiName) +
        ' != null' +
        ' GROUP BY ' +
        String.escapeSingleQuotes(fieldApiName) +
        ' ORDER BY ' +
        String.escapeSingleQuotes(fieldApiName) +
        ' LIMIT 200';
      for (AggregateResult ar : Database.query(soql)) {
        String val = (String) ar.get(fieldApiName);
        if (String.isNotBlank(val)) {
          values.add(new StageInfo(val, val));
        }
      }
      return values;
    }

    return values;
  }

  /**
   * @description Return all Currency/Number/Percent fields on a given object.
   *              Used by wizard Step 5 (Source Field dropdown for metrics).
   */
  @AuraEnabled(cacheable=true)
  public static List<StageInfo> getNumericFields(String objectApiName) {
    List<StageInfo> fields = new List<StageInfo>();
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
    if (sot == null) {
      return fields;
    }
    for (Schema.SObjectField f : sot.getDescribe().fields.getMap().values()) {
      Schema.DescribeFieldResult dfr = f.getDescribe();
      if (!dfr.isAccessible()) {
        continue;
      }
      if (AUDIT_FIELD_SKIP.contains(dfr.getName())) {
        continue;
      }
      Schema.DisplayType t = dfr.getType();
      if (
        t == Schema.DisplayType.CURRENCY ||
        t == Schema.DisplayType.DOUBLE ||
        t == Schema.DisplayType.INTEGER ||
        t == Schema.DisplayType.LONG ||
        t == Schema.DisplayType.PERCENT
      ) {
        fields.add(new StageInfo(dfr.getLabel(), dfr.getName()));
      }
    }
    return fields;
  }

  /**
   * @description Return all picklist fields on a given object (for grouping dimension picker).
   */
  @AuraEnabled(cacheable=true)
  public static List<StageInfo> getPicklistFields(String objectApiName) {
    List<StageInfo> fields = new List<StageInfo>();
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
    if (sot == null) {
      return fields;
    }
    for (Schema.SObjectField f : sot.getDescribe().fields.getMap().values()) {
      Schema.DescribeFieldResult dfr = f.getDescribe();
      if (!dfr.isAccessible()) {
        continue;
      }
      if (AUDIT_FIELD_SKIP.contains(dfr.getName())) {
        continue;
      }
      Schema.DisplayType t = dfr.getType();
      if (
        t == Schema.DisplayType.PICKLIST ||
        t == Schema.DisplayType.MULTIPICKLIST
      ) {
        fields.add(new StageInfo(dfr.getLabel(), dfr.getName()));
      }
    }
    return fields;
  }

  /**
   * @description Return all accessible custom + common standard fields on an object.
   *              Used by Step 2 (hierarchy scope field) to give a searchable picker
   *              instead of requiring the admin to type the API name.
   */
  /**
   * @description Return fields suitable as grouping / scope dimensions:
   *              Picklist, Multi-picklist, Reference (Lookup/MD), String, Boolean.
   *              Excludes numeric, date, currency, formula, and system fields
   *              that don't make sense as grouping keys.
   *              Used by Step 2 (hierarchy scope field) and Step 3 (grouping field).
   */
  @AuraEnabled(cacheable=true)
  public static List<StageInfo> getGroupableFields(String objectApiName) {
    List<StageInfo> fields = new List<StageInfo>();
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
    if (sot == null) {
      return fields;
    }

    for (Schema.SObjectField f : sot.getDescribe().fields.getMap().values()) {
      Schema.DescribeFieldResult dfr = f.getDescribe();
      if (!dfr.isAccessible()) {
        continue;
      }
      if (AUDIT_FIELD_SKIP.contains(dfr.getName())) {
        continue;
      }

      Schema.DisplayType t = dfr.getType();
      Boolean isGroupable =
        t == Schema.DisplayType.PICKLIST ||
        t == Schema.DisplayType.MULTIPICKLIST ||
        t == Schema.DisplayType.REFERENCE ||
        t == Schema.DisplayType.STRING ||
        t == Schema.DisplayType.BOOLEAN ||
        t == Schema.DisplayType.ID;

      if (!isGroupable) {
        continue;
      }

      // For reference fields, show the related object in the label
      String label = dfr.getLabel();
      if (t == Schema.DisplayType.REFERENCE) {
        List<Schema.SObjectType> refs = dfr.getReferenceTo();
        if (!refs.isEmpty()) {
          label += ' → ' + refs[0].getDescribe().getLabel();
        }
      }

      fields.add(new StageInfo(label, dfr.getName()));
    }
    return fields;
  }

  private static Integer hexCharToInt(String c) {
    String h = c.toLowerCase();
    if (h == '0')
      return 0;
    if (h == '1')
      return 1;
    if (h == '2')
      return 2;
    if (h == '3')
      return 3;
    if (h == '4')
      return 4;
    if (h == '5')
      return 5;
    if (h == '6')
      return 6;
    if (h == '7')
      return 7;
    if (h == '8')
      return 8;
    if (h == '9')
      return 9;
    if (h == 'a')
      return 10;
    if (h == 'b')
      return 11;
    if (h == 'c')
      return 12;
    if (h == 'd')
      return 13;
    if (h == 'e')
      return 14;
    if (h == 'f')
      return 15;
    return 0;
  }

  public class StageInfo {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    public StageInfo(String label, String value) {
      this.label = label;
      this.value = value;
    }
  }

  public class RecordTypeInfo {
    @AuraEnabled
    public String recordTypeId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String developerName;
    public RecordTypeInfo(String id, String name, String devName) {
      this.recordTypeId = id;
      this.name = name;
      this.developerName = devName;
    }
  }

  public class LevelInfo {
    @AuraEnabled
    public Integer level;
    @AuraEnabled
    public String suggestedLabel;
    public LevelInfo(Integer level, String label) {
      this.level = level;
      this.suggestedLabel = label;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PHASE D HELPERS
  // ══════════════════════════════════════════════════════════════════════

  private static Forecast_Display_Field__c createSystemField(
    Id configId,
    String label,
    String objectName,
    String fieldName,
    String fieldType,
    Integer sortOrder
  ) {
    Forecast_Display_Field__c df = new Forecast_Display_Field__c();
    df.Forecast_Configuration__c = configId;
    df.Name = label;
    df.Field_Label__c = label;
    df.Object_API_Name__c = objectName;
    df.Field_API_Name__c = fieldName;
    df.Field_Type__c = fieldType;
    df.Display_Location__c = 'Main_Grid';
    df.Sort_Order__c = sortOrder;
    df.Column_Width__c = 'Medium';
    df.Is_Active__c = true;
    df.Is_System__c = true;
    return df;
  }
}
