/**
 * @description Controller for the Admin Console — ongoing configuration management.
 *              CRUD for config settings, metrics, categories, periods, participants.
 *              Audit logging to Forecast_Change_Event__c for all changes.
 *              Spec: ADMIN_SETUP_SPEC.md V1.2 §3
 */
public with sharing class AdminConsoleController {
  // ══════════════════════════════════════════════════════════════════════
  //  GENERAL SETTINGS
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Get the active forecast configuration with child metrics and categories.
   */
  @AuraEnabled
  public static Forecast_Configuration__c getConfig() {
    ForecastDataService.clearConfigCache();
    return ForecastDataService.getActiveConfig();
  }

  /**
   * @description Save general settings on the forecast configuration.
   *              Clears config cache and creates audit event.
   */
  @AuraEnabled
  public static void saveGeneralSettings(
    Id configId,
    String periodType,
    Integer paginationSize,
    String currencyMode,
    String corporateCurrency,
    String attainmentSource,
    String attainmentLayout,
    String topLevelLockLabel,
    String scopeDetermination,
    Integer futurePeriods,
    String pipelineRecordTypeFilter,
    Integer hourlySnapshotDays,
    Integer hourlySnapshotInterval,
    Integer fiscalYearStartMonth,
    Integer pastPeriodsVisible,
    String defaultHorizon,
    Integer customHorizonPeriods,
    String finalForecastLabel,
    String stretchForecastLabel,
    String forecastCadence,
    String submissionDeadlineDay,
    Boolean autoFreezeOnDeadline,
    Date cadenceAnchorDate,
    String scopeCustomObject,
    String scopeCustomField
  ) {
    try {
      Forecast_Configuration__c config = [
        SELECT
          Id,
          Period_Type__c,
          Pagination_Size__c,
          Currency_Mode__c,
          Corporate_Currency__c,
          Attainment_Source__c,
          Attainment_Layout__c,
          Top_Level_Lock_Label__c,
          Scope_Determination__c,
          Future_Periods_Visible__c,
          Pipeline_Record_Type_Filter__c,
          Hourly_Snapshot_Days__c,
          Hourly_Snapshot_Interval__c,
          Fiscal_Year_Start_Month__c,
          Past_Periods_Visible__c,
          Default_Horizon__c,
          Custom_Horizon_Periods__c,
          Final_Forecast_Label__c,
          Stretch_Forecast_Label__c,
          Forecast_Cadence__c,
          Submission_Deadline_Day__c,
          Auto_Freeze_On_Deadline__c,
          Cadence_Anchor_Date__c,
          Scope_Custom_Object__c,
          Scope_Custom_Field__c
        FROM Forecast_Configuration__c
        WHERE Id = :configId
      ];

      // Track ALL field changes for comprehensive audit (§8.7)
      Map<String, Object> oldValues = new Map<String, Object>();
      Map<String, Object> newValues = new Map<String, Object>();

      // Helper: track and apply each field change
      if (periodType != null && periodType != config.Period_Type__c) {
        oldValues.put('Period_Type__c', config.Period_Type__c);
        newValues.put('Period_Type__c', periodType);
        config.Period_Type__c = periodType;
      }
      if (
        paginationSize != null &&
        paginationSize != config.Pagination_Size__c
      ) {
        oldValues.put('Pagination_Size__c', config.Pagination_Size__c);
        newValues.put('Pagination_Size__c', paginationSize);
        config.Pagination_Size__c = paginationSize;
      }
      if (currencyMode != null && currencyMode != config.Currency_Mode__c) {
        oldValues.put('Currency_Mode__c', config.Currency_Mode__c);
        newValues.put('Currency_Mode__c', currencyMode);
        config.Currency_Mode__c = currencyMode;
      }
      if (
        corporateCurrency != null &&
        corporateCurrency != config.Corporate_Currency__c
      ) {
        oldValues.put('Corporate_Currency__c', config.Corporate_Currency__c);
        newValues.put('Corporate_Currency__c', corporateCurrency);
        config.Corporate_Currency__c = corporateCurrency;
      }
      if (
        attainmentSource != null &&
        attainmentSource != config.Attainment_Source__c
      ) {
        oldValues.put('Attainment_Source__c', config.Attainment_Source__c);
        newValues.put('Attainment_Source__c', attainmentSource);
        config.Attainment_Source__c = attainmentSource;
      }
      if (
        attainmentLayout != null &&
        attainmentLayout != config.Attainment_Layout__c
      ) {
        oldValues.put('Attainment_Layout__c', config.Attainment_Layout__c);
        newValues.put('Attainment_Layout__c', attainmentLayout);
        config.Attainment_Layout__c = attainmentLayout;
      }
      if (
        topLevelLockLabel != null &&
        topLevelLockLabel != config.Top_Level_Lock_Label__c
      ) {
        oldValues.put(
          'Top_Level_Lock_Label__c',
          config.Top_Level_Lock_Label__c
        );
        newValues.put('Top_Level_Lock_Label__c', topLevelLockLabel);
        config.Top_Level_Lock_Label__c = topLevelLockLabel;
      }
      if (
        scopeDetermination != null &&
        scopeDetermination != config.Scope_Determination__c
      ) {
        oldValues.put('Scope_Determination__c', config.Scope_Determination__c);
        newValues.put('Scope_Determination__c', scopeDetermination);
        config.Scope_Determination__c = scopeDetermination;
      }
      if (
        futurePeriods != null &&
        futurePeriods != config.Future_Periods_Visible__c
      ) {
        oldValues.put(
          'Future_Periods_Visible__c',
          config.Future_Periods_Visible__c
        );
        newValues.put('Future_Periods_Visible__c', futurePeriods);
        config.Future_Periods_Visible__c = futurePeriods;
      }
      if (
        pipelineRecordTypeFilter != null &&
        pipelineRecordTypeFilter != config.Pipeline_Record_Type_Filter__c
      ) {
        oldValues.put(
          'Pipeline_Record_Type_Filter__c',
          config.Pipeline_Record_Type_Filter__c
        );
        newValues.put(
          'Pipeline_Record_Type_Filter__c',
          pipelineRecordTypeFilter
        );
        config.Pipeline_Record_Type_Filter__c = pipelineRecordTypeFilter;
      }
      if (
        hourlySnapshotDays != null &&
        hourlySnapshotDays != config.Hourly_Snapshot_Days__c
      ) {
        oldValues.put(
          'Hourly_Snapshot_Days__c',
          config.Hourly_Snapshot_Days__c
        );
        newValues.put('Hourly_Snapshot_Days__c', hourlySnapshotDays);
        config.Hourly_Snapshot_Days__c = hourlySnapshotDays;
      }
      if (
        hourlySnapshotInterval != null &&
        hourlySnapshotInterval != config.Hourly_Snapshot_Interval__c
      ) {
        oldValues.put(
          'Hourly_Snapshot_Interval__c',
          config.Hourly_Snapshot_Interval__c
        );
        newValues.put('Hourly_Snapshot_Interval__c', hourlySnapshotInterval);
        config.Hourly_Snapshot_Interval__c = hourlySnapshotInterval;
      }
      if (
        fiscalYearStartMonth != null &&
        fiscalYearStartMonth != config.Fiscal_Year_Start_Month__c
      ) {
        oldValues.put(
          'Fiscal_Year_Start_Month__c',
          config.Fiscal_Year_Start_Month__c
        );
        newValues.put('Fiscal_Year_Start_Month__c', fiscalYearStartMonth);
        config.Fiscal_Year_Start_Month__c = fiscalYearStartMonth;
      }
      if (
        pastPeriodsVisible != null &&
        pastPeriodsVisible != config.Past_Periods_Visible__c
      ) {
        oldValues.put(
          'Past_Periods_Visible__c',
          config.Past_Periods_Visible__c
        );
        newValues.put('Past_Periods_Visible__c', pastPeriodsVisible);
        config.Past_Periods_Visible__c = pastPeriodsVisible;
      }
      if (
        defaultHorizon != null &&
        defaultHorizon != config.Default_Horizon__c
      ) {
        oldValues.put('Default_Horizon__c', config.Default_Horizon__c);
        newValues.put('Default_Horizon__c', defaultHorizon);
        config.Default_Horizon__c = defaultHorizon;
      }
      if (
        customHorizonPeriods != null &&
        customHorizonPeriods != config.Custom_Horizon_Periods__c
      ) {
        oldValues.put(
          'Custom_Horizon_Periods__c',
          config.Custom_Horizon_Periods__c
        );
        newValues.put('Custom_Horizon_Periods__c', customHorizonPeriods);
        config.Custom_Horizon_Periods__c = customHorizonPeriods;
      }
      if (
        finalForecastLabel != null &&
        finalForecastLabel != config.Final_Forecast_Label__c
      ) {
        oldValues.put(
          'Final_Forecast_Label__c',
          config.Final_Forecast_Label__c
        );
        newValues.put('Final_Forecast_Label__c', finalForecastLabel);
        config.Final_Forecast_Label__c = finalForecastLabel;
      }
      if (
        stretchForecastLabel != null &&
        stretchForecastLabel != config.Stretch_Forecast_Label__c
      ) {
        oldValues.put(
          'Stretch_Forecast_Label__c',
          config.Stretch_Forecast_Label__c
        );
        newValues.put('Stretch_Forecast_Label__c', stretchForecastLabel);
        config.Stretch_Forecast_Label__c = stretchForecastLabel;
      }
      // Phase D: Forecast Cadence
      if (
        forecastCadence != null &&
        forecastCadence != config.Forecast_Cadence__c
      ) {
        oldValues.put('Forecast_Cadence__c', config.Forecast_Cadence__c);
        newValues.put('Forecast_Cadence__c', forecastCadence);
        config.Forecast_Cadence__c = forecastCadence;
      }
      if (
        submissionDeadlineDay != null &&
        submissionDeadlineDay != config.Submission_Deadline_Day__c
      ) {
        oldValues.put(
          'Submission_Deadline_Day__c',
          config.Submission_Deadline_Day__c
        );
        newValues.put('Submission_Deadline_Day__c', submissionDeadlineDay);
        config.Submission_Deadline_Day__c = submissionDeadlineDay;
      }
      if (
        autoFreezeOnDeadline != null &&
        autoFreezeOnDeadline != config.Auto_Freeze_On_Deadline__c
      ) {
        oldValues.put(
          'Auto_Freeze_On_Deadline__c',
          config.Auto_Freeze_On_Deadline__c
        );
        newValues.put('Auto_Freeze_On_Deadline__c', autoFreezeOnDeadline);
        config.Auto_Freeze_On_Deadline__c = autoFreezeOnDeadline;
      }
      if (
        cadenceAnchorDate != null &&
        cadenceAnchorDate != config.Cadence_Anchor_Date__c
      ) {
        oldValues.put('Cadence_Anchor_Date__c', config.Cadence_Anchor_Date__c);
        newValues.put('Cadence_Anchor_Date__c', cadenceAnchorDate);
        config.Cadence_Anchor_Date__c = cadenceAnchorDate;
      }
      if (
        scopeCustomObject != null &&
        scopeCustomObject != config.Scope_Custom_Object__c
      ) {
        oldValues.put('Scope_Custom_Object__c', config.Scope_Custom_Object__c);
        newValues.put('Scope_Custom_Object__c', scopeCustomObject);
        config.Scope_Custom_Object__c = scopeCustomObject;
      }
      if (
        scopeCustomField != null &&
        scopeCustomField != config.Scope_Custom_Field__c
      ) {
        oldValues.put('Scope_Custom_Field__c', config.Scope_Custom_Field__c);
        newValues.put('Scope_Custom_Field__c', scopeCustomField);
        config.Scope_Custom_Field__c = scopeCustomField;
      }

      update config;
      ForecastDataService.clearConfigCache();

      // Audit log — ALL field changes tracked
      if (!oldValues.isEmpty()) {
        logConfigChange(
          'Config_Change',
          configId,
          JSON.serialize(
            new Map<String, Object>{ 'old' => oldValues, 'new' => newValues }
          )
        );
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  METRICS
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Forecast_Metric__c> getMetrics(Id configId) {
    return [
      SELECT
        Id,
        Name,
        Metric_Label__c,
        Metric_Type__c,
        Display_Format__c,
        Is_Primary__c,
        Is_Required__c,
        Is_Editable__c,
        Sort_Order__c,
        Source_Field__c,
        Source_Object__c,
        Source_Lookup_Field__c,
        Metric_API_Name__c,
        Aggregation__c,
        Forecast_Group__c,
        Forecast_Group__r.Name
      FROM Forecast_Metric__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Sort_Order__c ASC
    ];
  }

  @AuraEnabled
  public static Id saveMetric(
    Id configId,
    Id metricId,
    String name,
    String label,
    String metricType,
    String displayFormat,
    Boolean isPrimary,
    Boolean isRequired,
    Boolean isEditable,
    Integer sortOrder,
    String sourceField,
    String sourceObject,
    String aggregation,
    String sourceLookupField,
    Id forecastGroupId
  ) {
    try {
      Forecast_Metric__c m;
      if (metricId != null) {
        m = [SELECT Id FROM Forecast_Metric__c WHERE Id = :metricId];
      } else {
        // Guard: max 6 metrics
        Integer count = [
          SELECT COUNT()
          FROM Forecast_Metric__c
          WHERE Forecast_Configuration__c = :configId
        ];
        if (count >= 6) {
          throw new AuraHandledException('Maximum of 6 metrics allowed.');
        }
        m = new Forecast_Metric__c();
        m.Forecast_Configuration__c = configId;
      }
      m.Name = name;
      m.Metric_Label__c = label;
      m.Metric_Type__c = metricType;
      m.Display_Format__c = displayFormat;
      m.Is_Primary__c = isPrimary == true;
      m.Is_Required__c = isRequired == true;
      m.Is_Editable__c = isEditable == true;
      m.Sort_Order__c = sortOrder;
      m.Source_Field__c = sourceField;
      if (sourceObject != null) {
        m.Source_Object__c = sourceObject;
      }
      if (aggregation != null) {
        m.Aggregation__c = aggregation;
      }
      if (sourceLookupField != null) {
        m.Source_Lookup_Field__c = sourceLookupField;
      }
      if (forecastGroupId != null) {
        m.Forecast_Group__c = forecastGroupId;
      } else {
        m.Forecast_Group__c = null; // Config-wide
      }
      upsert m;

      ForecastDataService.clearConfigCache();
      return m.Id;
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Integer getMetricOverrideCount(Id metricId) {
    // Check which metric slot this is and which config it belongs to
    Forecast_Metric__c metric = [
      SELECT Sort_Order__c, Forecast_Configuration__c
      FROM Forecast_Metric__c
      WHERE Id = :metricId
    ];
    Integer slot = metric.Sort_Order__c != null
      ? metric.Sort_Order__c.intValue()
      : 1;
    String fieldName = 'Metric_' + slot + '_Value__c';
    Id configId = metric.Forecast_Configuration__c;
    // Count overrides for THIS config only where this metric slot has a non-null value
    String query =
      'SELECT COUNT() FROM Forecast_Override__c' +
      ' WHERE ' +
      fieldName +
      ' != null' +
      ' AND Forecast_Period__c IN (' +
      '   SELECT Id FROM Forecast_Period__c WHERE Forecast_Configuration__c = \'' +
      configId +
      '\'' +
      ' )';
    return Database.countQuery(query);
  }

  /**
   * @description Deactivate a metric — hides from grid, preserves data.
   * @return Warning message if overrides exist, null if clean deactivation
   */
  @AuraEnabled
  public static String deactivateMetric(Id metricId) {
    try {
      Integer overrideCount = getMetricOverrideCount(metricId);
      if (overrideCount == 0) {
        // No forecast data uses this metric — safe to hard delete
        delete [SELECT Id FROM Forecast_Metric__c WHERE Id = :metricId];
        ForecastDataService.clearConfigCache();
        return null;
      }
      // Has override data — soft-deactivate to preserve history
      Forecast_Metric__c m = new Forecast_Metric__c(
        Id = metricId,
        Is_Editable__c = false
      );
      update m;
      ForecastDataService.clearConfigCache();
      return overrideCount +
        ' overrides have values for this metric. ' +
        'Column is now hidden but data is preserved.';
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Forecast_Category__c> getCategories(Id configId) {
    return [
      SELECT
        Id,
        Name,
        Category_Label__c,
        Category_API_Name__c,
        Color_Hex__c,
        Is_Active__c,
        Counts_Toward_Target__c,
        Counts_Toward_Stretch__c,
        Is_Terminal__c,
        Is_High_Confidence__c,
        Regression_Warning__c,
        Sort_Order__c
      FROM Forecast_Category__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Sort_Order__c ASC
    ];
  }

  @AuraEnabled
  public static Id saveCategory(
    Id configId,
    Id categoryId,
    String name,
    String label,
    String apiName,
    String color,
    Boolean countsTowardTarget,
    Boolean countsTowardStretch,
    Boolean isTerminal,
    Boolean isHighConfidence,
    Boolean regressionWarning,
    Integer sortOrder
  ) {
    try {
      Forecast_Category__c c;
      if (categoryId != null) {
        c = [SELECT Id FROM Forecast_Category__c WHERE Id = :categoryId];
      } else {
        c = new Forecast_Category__c();
        c.Forecast_Configuration__c = configId;
        c.Is_Active__c = true;
      }
      c.Name = name;
      c.Category_Label__c = label;
      c.Category_API_Name__c = apiName;
      c.Color_Hex__c = color;
      c.Counts_Toward_Target__c = countsTowardTarget == true;
      if (countsTowardStretch != null) {
        c.Counts_Toward_Stretch__c = countsTowardStretch;
      }
      c.Is_Terminal__c = isTerminal == true;
      c.Is_High_Confidence__c = isHighConfidence == true;
      c.Regression_Warning__c = regressionWarning == true;
      c.Sort_Order__c = sortOrder;
      upsert c;

      ForecastDataService.clearConfigCache();
      return c.Id;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Integer getCategoryOverrideCount(Id categoryId) {
    Forecast_Category__c cat = [
      SELECT Category_API_Name__c
      FROM Forecast_Category__c
      WHERE Id = :categoryId
    ];
    return [
      SELECT COUNT()
      FROM Forecast_Override__c
      WHERE Forecast_Category__c = :cat.Category_API_Name__c
    ];
  }

  @AuraEnabled
  public static String deactivateCategory(Id categoryId) {
    try {
      Forecast_Category__c cat = [
        SELECT
          Id,
          Category_API_Name__c,
          Is_Terminal__c,
          Forecast_Configuration__c
        FROM Forecast_Category__c
        WHERE Id = :categoryId
      ];
      if (cat.Is_Terminal__c) {
        throw new AuraHandledException(
          'Cannot remove terminal categories (Closed Won, Lost).'
        );
      }
      // Guard: min 3 active categories
      Integer activeCount = [
        SELECT COUNT()
        FROM Forecast_Category__c
        WHERE
          Forecast_Configuration__c = :cat.Forecast_Configuration__c
          AND Is_Active__c = TRUE
      ];
      if (activeCount <= 3) {
        throw new AuraHandledException(
          'Must have at least 3 active categories.'
        );
      }
      // Check if any overrides reference this category
      String apiName = cat.Category_API_Name__c;
      Integer usageCount = 0;
      if (String.isNotBlank(apiName)) {
        usageCount = [
          SELECT COUNT()
          FROM Forecast_Override__c
          WHERE
            Forecast_Category__c = :apiName
            AND Forecast_Period__c IN (
              SELECT Id
              FROM Forecast_Period__c
              WHERE Forecast_Configuration__c = :cat.Forecast_Configuration__c
            )
        ];
      }
      if (usageCount == 0) {
        // No forecast data — hard delete
        delete cat;
      } else {
        // Has data — soft deactivate
        cat.Is_Active__c = false;
        update cat;
      }
      ForecastDataService.clearConfigCache();
      return usageCount > 0
        ? usageCount +
          ' overrides use this category. It has been hidden but data is preserved.'
        : null;
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PERIODS
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Forecast_Period__c> getPeriods(Id configId) {
    return [
      SELECT
        Id,
        Name,
        Start_Date__c,
        End_Date__c,
        Status__c,
        Period_Type__c,
        Budget_Mode__c,
        Frozen_By__c,
        Frozen_On__c
      FROM Forecast_Period__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Start_Date__c DESC
    ];
  }

  @AuraEnabled
  public static void updatePeriodStatus(Id periodId, String newStatus) {
    try {
      Forecast_Period__c period = [
        SELECT Id, Status__c, Name
        FROM Forecast_Period__c
        WHERE Id = :periodId
      ];
      String oldStatus = period.Status__c;

      // Validation rules per spec §8.4
      if (
        newStatus == 'Open' && (oldStatus == 'Frozen' || oldStatus == 'Closed')
      ) {
        // Reopen requires Platform_Admin — check permission
        if (!FeatureManagement.checkPermission('Platform_Admin')) {
          // Fallback: check Full Access permission set
          List<PermissionSetAssignment> psa = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE
              AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.Name = 'RevenueTrust_Full_Access'
            LIMIT 1
          ];
          if (psa.isEmpty()) {
            throw new AuraHandledException(
              'Reopening a ' +
                oldStatus +
                ' period requires Full Access permission.'
            );
          }
        }
      }

      period.Status__c = newStatus;
      if (newStatus == 'Frozen') {
        period.Frozen_By__c = UserInfo.getUserId();
        period.Frozen_On__c = Datetime.now();
      }
      update period;

      logConfigChange(
        'Config_Change',
        periodId,
        '{"period":"' +
          period.Name +
          '","oldStatus":"' +
          oldStatus +
          '","newStatus":"' +
          newStatus +
          '"}'
      );
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<Id> generateFuturePeriods(Id configId, Integer count) {
    try {
      Forecast_Configuration__c config = [
        SELECT Period_Type__c
        FROM Forecast_Configuration__c
        WHERE Id = :configId
      ];
      return ForecastPeriodService.createFuturePeriods(
        count,
        config.Period_Type__c,
        configId,
        null
      );
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  DISPLAY FIELDS (Phase D)
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Forecast_Display_Field__c> getDisplayFields(Id configId) {
    return [
      SELECT
        Id,
        Name,
        Field_Label__c,
        Object_API_Name__c,
        Field_API_Name__c,
        Field_Type__c,
        Display_Location__c,
        Sort_Order__c,
        Column_Width__c,
        Is_Active__c,
        Is_System__c
      FROM Forecast_Display_Field__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Sort_Order__c ASC
    ];
  }

  @AuraEnabled
  public static Id saveDisplayField(
    Id configId,
    Id fieldId,
    String fieldLabel,
    String objectApiName,
    String fieldApiName,
    String fieldType,
    String displayLocation,
    Integer sortOrder,
    String columnWidth,
    Boolean isActive
  ) {
    try {
      Forecast_Display_Field__c df;
      if (fieldId != null) {
        df = [
          SELECT Id, Is_System__c
          FROM Forecast_Display_Field__c
          WHERE Id = :fieldId
        ];
        // System fields cannot be deactivated
        if (df.Is_System__c && isActive == false) {
          throw new AuraHandledException('System fields cannot be hidden.');
        }
      } else {
        df = new Forecast_Display_Field__c();
        df.Forecast_Configuration__c = configId;
        df.Is_System__c = false;

        // Validate max limits
        Integer mainCount = [
          SELECT COUNT()
          FROM Forecast_Display_Field__c
          WHERE
            Forecast_Configuration__c = :configId
            AND Is_Active__c = TRUE
            AND (Display_Location__c = 'Main_Grid'
            OR Display_Location__c = 'Both')
            AND Is_System__c = FALSE
        ];
        Integer expandedCount = [
          SELECT COUNT()
          FROM Forecast_Display_Field__c
          WHERE
            Forecast_Configuration__c = :configId
            AND Is_Active__c = TRUE
            AND (Display_Location__c = 'Expanded_Detail'
            OR Display_Location__c = 'Both')
            AND Is_System__c = FALSE
        ];

        if (
          (displayLocation == 'Main_Grid' || displayLocation == 'Both') &&
          mainCount >= 8
        ) {
          throw new AuraHandledException(
            'Maximum 8 custom fields allowed in Main Grid.'
          );
        }
        if (
          (displayLocation == 'Expanded_Detail' || displayLocation == 'Both') &&
          expandedCount >= 15
        ) {
          throw new AuraHandledException(
            'Maximum 15 custom fields allowed in Expanded Detail.'
          );
        }
      }

      df.Name = fieldLabel;
      df.Field_Label__c = fieldLabel;
      df.Object_API_Name__c = objectApiName;
      df.Field_API_Name__c = fieldApiName;
      df.Field_Type__c = fieldType;
      df.Display_Location__c = displayLocation;
      df.Sort_Order__c = sortOrder;
      df.Column_Width__c = columnWidth;
      if (isActive != null) {
        df.Is_Active__c = isActive;
      }

      upsert df;
      ForecastDataService.clearConfigCache();
      return df.Id;
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void deleteDisplayField(Id fieldId) {
    try {
      Forecast_Display_Field__c df = [
        SELECT Id, Is_System__c
        FROM Forecast_Display_Field__c
        WHERE Id = :fieldId
      ];
      if (df.Is_System__c) {
        throw new AuraHandledException('System fields cannot be deleted.');
      }
      delete df;
      ForecastDataService.clearConfigCache();
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Returns fields eligible for display in the forecast grid.
   * Filters out Long Text, Rich Text, Encrypted, Geolocation, Multi-Select.
   */
  @AuraEnabled(cacheable=true)
  public static List<OnboardingController.StageInfo> getEligibleDisplayFields(
    String objectApiName
  ) {
    List<OnboardingController.StageInfo> fields = new List<OnboardingController.StageInfo>();
    Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
    if (sot == null) {
      return fields;
    }

    Set<Schema.DisplayType> EXCLUDED = new Set<Schema.DisplayType>{
      Schema.DisplayType.TEXTAREA, // LongTextArea
      Schema.DisplayType.ENCRYPTEDSTRING,
      Schema.DisplayType.LOCATION,
      Schema.DisplayType.MULTIPICKLIST,
      Schema.DisplayType.BASE64,
      Schema.DisplayType.DATACATEGORYGROUPREFERENCE,
      Schema.DisplayType.ADDRESS,
      Schema.DisplayType.ANYTYPE
    };

    Set<String> SKIP_NAMES = new Set<String>{
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

    for (Schema.SObjectField f : sot.getDescribe().fields.getMap().values()) {
      Schema.DescribeFieldResult dfr = f.getDescribe();
      if (!dfr.isAccessible()) {
        continue;
      }
      if (SKIP_NAMES.contains(dfr.getName())) {
        continue;
      }
      if (EXCLUDED.contains(dfr.getType())) {
        continue;
      }
      // Skip Rich Text (it's TEXTAREA with isHtmlFormatted)
      if (
        dfr.getType() == Schema.DisplayType.TEXTAREA && dfr.isHtmlFormatted()
      ) {
        continue;
      }
      // Allow regular TextArea (short) but not LongTextArea (length > 255)
      if (
        dfr.getType() == Schema.DisplayType.TEXTAREA &&
        dfr.getLength() > 255
      ) {
        continue;
      }

      String label = dfr.getLabel();
      // For reference fields, show related object
      if (dfr.getType() == Schema.DisplayType.REFERENCE) {
        List<Schema.SObjectType> refs = dfr.getReferenceTo();
        if (!refs.isEmpty()) {
          label += ' → ' + refs[0].getDescribe().getLabel();
        }
      }

      fields.add(new OnboardingController.StageInfo(label, dfr.getName()));
    }
    return fields;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  GROUPS
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Forecast_Group__c> getGroupsForConfig(Id configId) {
    return [
      SELECT
        Id,
        Name,
        Group_Type__c,
        Group_Source_Object__c,
        Group_Field__c,
        Group_Lookup_Field__c,
        Group_Field_Values__c,
        Record_Type_Names__c,
        Closed_Won_Stages__c,
        Closed_Lost_Stages__c,
        Sort_Order__c,
        Is_Active__c
      FROM Forecast_Group__c
      WHERE Forecast_Configuration__c = :configId
      ORDER BY Sort_Order__c ASC
    ];
  }

  @AuraEnabled
  public static Id saveGroup(
    Id configId,
    Id groupId,
    String name,
    String groupType,
    Integer sortOrder,
    String sourceObject,
    String groupField,
    String recordTypeNames,
    String closedWonStages,
    String closedLostStages
  ) {
    try {
      Forecast_Group__c g;
      if (groupId != null) {
        g = [SELECT Id FROM Forecast_Group__c WHERE Id = :groupId];
      } else {
        g = new Forecast_Group__c();
        g.Forecast_Configuration__c = configId;
        g.Is_Active__c = true;
      }
      if (name != null) {
        g.Name = name;
      }
      if (groupType != null) {
        g.Group_Type__c = groupType;
      }
      if (sortOrder != null) {
        g.Sort_Order__c = sortOrder;
      }
      g.Group_Source_Object__c = sourceObject;
      g.Group_Field__c = groupField;
      g.Record_Type_Names__c = recordTypeNames;
      g.Closed_Won_Stages__c = closedWonStages;
      g.Closed_Lost_Stages__c = closedLostStages;
      upsert g;
      ForecastDataService.clearConfigCache();
      return g.Id;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void deactivateGroup(Id groupId) {
    try {
      Forecast_Group__c g = [
        SELECT Id, Is_Active__c
        FROM Forecast_Group__c
        WHERE Id = :groupId
      ];
      g.Is_Active__c = false;
      update g;
      ForecastDataService.clearConfigCache();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PARTICIPANTS
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static ParticipantListResult getParticipants(
    Id periodId,
    Integer pageNumber,
    Integer pageSize
  ) {
    ParticipantListResult result = new ParticipantListResult();
    Integer offset =
      ((pageNumber != null ? pageNumber : 1) - 1) *
      (pageSize != null ? pageSize : 50);
    Integer limitSize = pageSize != null ? pageSize : 50;

    result.totalCount = [
      SELECT COUNT()
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId AND Is_Summary__c = FALSE
    ];
    result.participants = [
      SELECT
        Id,
        User__c,
        User__r.Name,
        User__r.Email,
        Scope_Id__c,
        Scope_Name__c,
        Hierarchy_Level__c,
        Submission_Status__c,
        Is_Summary__c,
        Reports_To__c,
        Reports_To__r.User__r.Name,
        Delegate__c,
        Delegate_Start__c,
        Delegate_End__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId AND Is_Summary__c = FALSE
      ORDER BY Hierarchy_Level__c ASC, User__r.Name ASC
      LIMIT :limitSize
      OFFSET :offset
    ];
    result.pageNumber = pageNumber != null ? pageNumber : 1;
    result.pageSize = limitSize;
    return result;
  }

  /**
   * @description Sync participants for a period: create Forecast_Participant__c
   *              records for eligible standard users who don't already have one,
   *              then kick off ForecastInitializationBatch for scope verification.
   */
  @AuraEnabled
  public static Id syncParticipants(Id periodId) {
    try {
      // Find the config for this period
      Forecast_Period__c period = [
        SELECT Id, Forecast_Configuration__c
        FROM Forecast_Period__c
        WHERE Id = :periodId
        LIMIT 1
      ];
      Id configId = period.Forecast_Configuration__c;

      // Find users who already have a participant record for this period
      Set<Id> existingUserIds = new Set<Id>();
      for (Forecast_Participant__c p : [
        SELECT User__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId
      ]) {
        existingUserIds.add(p.User__c);
      }

      // Query eligible users (standard, active, non-system)
      List<User> eligibleUsers = [
        SELECT Id, Name, UserRoleId, ManagerId, UserRole.Name
        FROM User
        WHERE
          IsActive = TRUE
          AND UserType = 'Standard'
          AND Id NOT IN :existingUserIds
          AND Profile.Name NOT IN (
            'Chatter Free User',
            'Chatter External User',
            'Analytics Cloud Integration User',
            'Analytics Cloud Security User'
          )
        LIMIT 1000
      ];

      // Create participant records
      List<Forecast_Participant__c> newParticipants = new List<Forecast_Participant__c>();
      for (User u : eligibleUsers) {
        Forecast_Participant__c p = new Forecast_Participant__c();
        p.Forecast_Period__c = periodId;
        p.User__c = u.Id;
        // Scope = Role name (or user name if no role assigned)
        p.Scope_Id__c = u.UserRoleId != null ? u.UserRoleId : u.Id;
        p.Scope_Name__c = u.UserRole?.Name != null ? u.UserRole.Name : u.Name;
        p.Hierarchy_Level__c = 1;
        p.Reports_To__c = u.ManagerId;
        p.Submission_Status__c = 'Not_Started';
        p.Is_Summary__c = false;
        newParticipants.add(p);
      }
      if (!newParticipants.isEmpty()) {
        insert newParticipants;
      }

      // Kick off batch for scope verification / summary participant creation
      Id batchId = Database.executeBatch(
        new ForecastInitializationBatch(periodId),
        200
      );
      logConfigChange(
        'Participant_Sync',
        periodId,
        '{"action":"sync_triggered","created":' +
          newParticipants.size() +
          ',"existing":' +
          existingUserIds.size() +
          ',"batchId":"' +
          batchId +
          '"}'
      );
      return batchId;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void updateParticipantLevel(
    Id participantId,
    Integer newLevel
  ) {
    try {
      Forecast_Participant__c p = new Forecast_Participant__c(
        Id = participantId,
        Hierarchy_Level__c = newLevel
      );
      update p;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void setDelegate(
    Id participantId,
    Id delegateUserId,
    Date startDate,
    Date endDate
  ) {
    try {
      Forecast_Participant__c p = new Forecast_Participant__c(
        Id = participantId,
        Delegate__c = delegateUserId,
        Delegate_Start__c = startDate,
        Delegate_End__c = endDate
      );
      update p;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  FIELD MAPPINGS (CMT — async deploy)
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Field_Mapping__mdt> getFieldMappings() {
    return [
      SELECT
        DeveloperName,
        MasterLabel,
        Logical_Name__c,
        Field_API_Name__c,
        Object_API_Name__c,
        Field_Type__c,
        Is_Required__c
      FROM Field_Mapping__mdt
      ORDER BY Logical_Name__c ASC
    ];
  }

  @AuraEnabled
  public static String saveFieldMapping(
    String developerName,
    String logicalName,
    String fieldApiName,
    String objectApiName
  ) {
    try {
      String fullName = 'Field_Mapping__mdt.' + developerName;
      String fieldValuesJson = JSON.serialize(
        new Map<String, Object>{
          'Logical_Name__c' => logicalName,
          'Field_API_Name__c' => fieldApiName,
          'Object_API_Name__c' => objectApiName
        }
      );
      return OnboardingController.deployCmtUpdate(fullName, fieldValuesJson);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Field mapping save failed: ' + e.getMessage()
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  FORECAST QUOTAS (lightweight)
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<Forecast_Quota__c> getQuotasForPeriod(Id periodId) {
    return [
      SELECT
        Id,
        User__c,
        User__r.Name,
        User__r.Email,
        Forecast_Period__c,
        Forecast_Participant__c,
        Target_Amount__c,
        Achieved_Amount__c,
        Attainment_Pct__c,
        Status__c,
        Notes__c
      FROM Forecast_Quota__c
      WHERE Forecast_Period__c = :periodId
      ORDER BY User__r.Name ASC
    ];
  }

  @AuraEnabled
  public static Id saveQuota(
    Id quotaId,
    Id userId,
    Id periodId,
    Decimal targetAmount,
    String status,
    String notes
  ) {
    try {
      Forecast_Quota__c q;
      if (quotaId != null) {
        q = new Forecast_Quota__c(Id = quotaId);
      } else {
        q = new Forecast_Quota__c();
        q.User__c = userId;
        q.Forecast_Period__c = periodId;
      }
      q.Target_Amount__c = targetAmount;
      q.Status__c = status;
      q.Notes__c = notes;
      upsert q;

      logConfigChange(
        'Quota_Set',
        q.Id,
        '{"user":"' + userId + '","target":' + targetAmount + '}'
      );
      return q.Id;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  AUDIT LOGGING
  // ══════════════════════════════════════════════════════════════════════

  private static void logConfigChange(
    String changeType,
    Id relatedId,
    String details
  ) {
    try {
      Forecast_Change_Event__c evt = new Forecast_Change_Event__c();
      evt.Change_Type__c = changeType;
      evt.Changed_By__c = UserInfo.getUserId();
      evt.Changed_On__c = Datetime.now();
      evt.Config_Change_Details__c = details;
      // Don't set Forecast_Override__c or Opportunity__c — these are config events
      insert evt;
    } catch (Exception e) {
      // Audit failure should not block the operation
      System.debug(LoggingLevel.WARN, 'Audit log failed: ' + e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PHASE C: Per-Level Auto-Derive Refresh
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Phase C: Refresh hierarchy level labels by re-running discovery.
   *              For each level entry in Level_Labels__c JSON:
   *                - if autoDerive == true, replace label with discovery's suggestedLabel
   *                - if autoDerive == false, preserve admin override
   *              Saves updated JSON back to the config.
   *
   * @param configId Forecast_Configuration__c Id whose labels should be refreshed
   * @return The updated Level_Labels__c JSON string
   */
  @AuraEnabled
  public static String refreshLevelLabels(Id configId) {
    try {
      Forecast_Configuration__c cfg = [
        SELECT Id, Level_Labels__c
        FROM Forecast_Configuration__c
        WHERE Id = :configId
        LIMIT 1
      ];

      // Re-run discovery to get latest auto-derived labels per level
      OnboardingController.OrgDiscoveryResult discovery = OnboardingController.discoverOrg();
      Map<Integer, String> autoDerivedByLevel = new Map<Integer, String>();
      if (discovery != null && discovery.detectedLevels != null) {
        for (OnboardingController.LevelInfo li : discovery.detectedLevels) {
          if (li.level != null) {
            autoDerivedByLevel.put(li.level, li.suggestedLabel);
          }
        }
      }

      // Parse existing Level_Labels__c JSON. Phase C structure: array of
      // { level: Integer, label: String, autoDerive: Boolean }
      // Legacy structure: { "1": "Sales Rep", "2": "Manager", ... } \u2014 treat all as autoDerive=true.
      List<Object> updated = new List<Object>();
      String existingJson = cfg.Level_Labels__c;
      Boolean isLegacyMap = false;

      if (String.isBlank(existingJson)) {
        // No existing labels \u2014 build from discovery, all autoDerive
        for (Integer level : autoDerivedByLevel.keySet()) {
          Map<String, Object> entry = new Map<String, Object>();
          entry.put('level', level);
          entry.put('label', autoDerivedByLevel.get(level));
          entry.put('autoDerive', true);
          updated.add(entry);
        }
      } else {
        Object parsed = JSON.deserializeUntyped(existingJson);
        if (parsed instanceof List<Object>) {
          // Phase C structure
          for (Object o : (List<Object>) parsed) {
            Map<String, Object> entry = (Map<String, Object>) o;
            Integer lvl = (Integer) entry.get('level');
            Boolean auto = entry.get('autoDerive') == true;
            if (auto && autoDerivedByLevel.containsKey(lvl)) {
              entry.put('label', autoDerivedByLevel.get(lvl));
            }
            updated.add(entry);
          }
        } else if (parsed instanceof Map<String, Object>) {
          isLegacyMap = true;
          // Legacy structure \u2014 migrate to Phase C, mark all autoDerive=true,
          // but preserve the existing labels (they may have been customized).
          Map<String, Object> legacy = (Map<String, Object>) parsed;
          Set<Integer> allLevels = new Set<Integer>();
          for (String k : legacy.keySet()) {
            try {
              allLevels.add(Integer.valueOf(k));
            } catch (Exception e) {
            }
          }
          allLevels.addAll(autoDerivedByLevel.keySet());
          List<Integer> sorted = new List<Integer>(allLevels);
          sorted.sort();
          for (Integer lvl : sorted) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('level', lvl);
            // Auto-derive overrides any legacy value (one-time refresh on migration)
            if (autoDerivedByLevel.containsKey(lvl)) {
              entry.put('label', autoDerivedByLevel.get(lvl));
            } else {
              entry.put('label', legacy.get(String.valueOf(lvl)));
            }
            entry.put('autoDerive', true);
            updated.add(entry);
          }
        }
      }

      cfg.Level_Labels__c = JSON.serialize(updated);
      update cfg;

      // Audit (best-effort)
      try {
        logConfigChange(
          'Config_Change',
          cfg.Id,
          JSON.serialize(
            new Map<String, Object>{
              'action' => 'refreshLevelLabels',
              'levelsUpdated' => updated.size(),
              'migratedFromLegacyMap' => isLegacyMap
            }
          )
        );
      } catch (Exception ex) {
        // Audit is non-critical
      }

      ForecastDataService.clearConfigCache();
      return cfg.Level_Labels__c;
    } catch (Exception e) {
      throw new AuraHandledException(
        'refreshLevelLabels failed: ' + e.getMessage()
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  RESULT DTOs
  // ══════════════════════════════════════════════════════════════════════

  public class ParticipantListResult {
    @AuraEnabled
    public List<Forecast_Participant__c> participants;
    @AuraEnabled
    public Integer totalCount;
    @AuraEnabled
    public Integer pageNumber;
    @AuraEnabled
    public Integer pageSize;
  }
}
