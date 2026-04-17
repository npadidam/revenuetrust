/**
 * @description Query abstraction layer for the Forecasting module.
 *              Reads configuration, participants, overrides, and pipeline records.
 *              Uses PipelineObjectService for dynamic field resolution rather than
 *              hard-coding Opportunity queries.
 *
 *              Referenced by: ForecastService, ForecastController, batch jobs.
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 4
 */
public with sharing class ForecastDataService {
  // Cached active config for the transaction
  private static Forecast_Configuration__c cachedConfig;

  // Cached display fields to avoid duplicate queries (set by loadConfig, consumed by buildPipelineFieldList)
  private static List<Forecast_Display_Field__c> cachedDisplayFields;

  public static void setDisplayFieldCache(
    List<Forecast_Display_Field__c> fields
  ) {
    cachedDisplayFields = fields;
  }

  /**
   * @description Get pipeline records visible to a participant in a scope.
   *              Uses PipelineObjectService for dynamic field resolution.
   * @param participantId The Forecast_Participant__c record Id
   * @param scopeId The scope/territory identifier
   * @param periodId The Forecast_Period__c record Id
   * @return List of SObject pipeline records (Opportunity or custom object)
   */
  public static List<SObject> getPipelineRecordsForScope(
    Id participantId,
    String scopeId,
    Id periodId
  ) {
    // 1. Load participant to determine hierarchy source type and user
    Forecast_Participant__c participant = [
      SELECT
        Id,
        User__c,
        Hierarchy_Level__c,
        Scope_Id__c,
        Reports_To__c,
        Reports_To__r.User__c
      FROM Forecast_Participant__c
      WHERE Id = :participantId
      LIMIT 1
    ];

    if (participant == null) {
      return new List<SObject>();
    }

    // 2. Load config for record type filter and scope settings
    Forecast_Configuration__c config = getActiveConfig();
    String pipelineObj = PipelineObjectService.getPipelineObjectName();
    String ownerField = 'OwnerId';
    String fields = buildPipelineFieldList();

    // 3. Determine scope type and build query
    // Ownership scope: find all users in reporting chain, query by OwnerId
    Set<Id> userIds = getUsersInHierarchy(
      participant.User__c,
      participantId,
      periodId
    );
    String query =
      'SELECT ' +
      fields +
      ' FROM ' +
      pipelineObj +
      ' WHERE ' +
      ownerField +
      ' IN :userIds';

    // 4. Apply Record Type filter from config
    if (
      config != null && String.isNotBlank(config.Pipeline_Record_Type_Filter__c)
    ) {
      query +=
        ' AND RecordType.DeveloperName = \'' +
        String.escapeSingleQuotes(config.Pipeline_Record_Type_Filter__c) +
        '\'';
    }

    // 5. Apply date filter: close date within the period
    Forecast_Period__c period = [
      SELECT Id, Start_Date__c, End_Date__c
      FROM Forecast_Period__c
      WHERE Id = :periodId
      LIMIT 1
    ];
    if (
      period != null &&
      period.Start_Date__c != null &&
      period.End_Date__c != null
    ) {
      Date startDate = period.Start_Date__c;
      Date endDate = period.End_Date__c;
      query += ' AND CloseDate >= :startDate AND CloseDate <= :endDate';
    }

    query += ' ORDER BY CloseDate ASC';
    return Database.query(query);
  }

  /**
   * @description Get overrides for a set of pipeline record IDs.
   *              Returns map keyed by pipeline record ID. Records without
   *              overrides are NOT in the map (lazy materialization pattern).
   * @param recordIds Set of pipeline record IDs
   * @param periodId The forecast period
   * @param participantId The participant whose overrides to load
   * @return Map of pipeline record Id to Forecast_Override__c
   */
  public static Map<Id, Forecast_Override__c> getOverridesForRecords(
    Set<Id> recordIds,
    Id periodId,
    Id participantId
  ) {
    // Backward-compatible wrapper: queries the participant to resolve user ID
    return getOverridesForRecords(recordIds, periodId, participantId, null);
  }

  /**
   * @description Overload that accepts a pre-resolved participantUserId to avoid
   *              a duplicate Forecast_Participant__c query when the caller already
   *              has the user ID from a prior lookup.
   */
  public static Map<Id, Forecast_Override__c> getOverridesForRecords(
    Set<Id> recordIds,
    Id periodId,
    Id participantId,
    Id participantUserId
  ) {
    // Resolve the participant's user ID only if not provided
    Id resolvedUserId = participantUserId;
    if (resolvedUserId == null) {
      // Fallback: query if not provided
      Forecast_Participant__c participant = [
        SELECT User__c
        FROM Forecast_Participant__c
        WHERE Id = :participantId
        LIMIT 1
      ];
      resolvedUserId = participant != null ? participant.User__c : null;
    }

    Map<Id, Forecast_Override__c> resultMap = new Map<Id, Forecast_Override__c>();
    if (recordIds == null || recordIds.isEmpty() || resolvedUserId == null) {
      return resultMap;
    }

    List<Forecast_Override__c> overrides = [
      SELECT
        Id,
        Opportunity__c,
        Forecast_Period__c,
        User__c,
        Forecast_Participant__c,
        Hierarchy_Level__c,
        Forecast_Category__c,
        Metric_1_Value__c,
        Metric_2_Value__c,
        Metric_3_Value__c,
        Metric_4_Value__c,
        Metric_5_Value__c,
        Metric_6_Value__c,
        Close_Date_Override__c,
        Status__c,
        Comment__c,
        Saved_On__c,
        Submitted_On__c,
        Pending_Approval__c,
        CRM_Divergence__c,
        CRM_Divergence_Details__c,
        Previous_Level_Override__c,
        Previous_Period_Override__c,
        Exchange_Rate__c,
        Metric_1_Local__c,
        Metric_2_Local__c,
        LastModifiedDate
      FROM Forecast_Override__c
      WHERE
        Opportunity__c IN :recordIds
        AND Forecast_Period__c = :periodId
        AND User__c = :resolvedUserId
    ];

    for (Forecast_Override__c ov : overrides) {
      resultMap.put(ov.Opportunity__c, ov);
    }
    return resultMap;
  }

  /**
   * @description Get overrides from a previous hierarchy level.
   *              Used for "show me what my direct reports submitted."
   * @param recordIds Set of pipeline record IDs
   * @param periodId The forecast period
   * @param previousLevel The hierarchy level to query
   * @return Map of pipeline record Id to Forecast_Override__c
   */
  public static Map<Id, Forecast_Override__c> getPreviousLevelOverrides(
    Set<Id> recordIds,
    Id periodId,
    Integer previousLevel
  ) {
    Map<Id, Forecast_Override__c> resultMap = new Map<Id, Forecast_Override__c>();
    if (recordIds == null || recordIds.isEmpty()) {
      return resultMap;
    }

    List<Forecast_Override__c> overrides = [
      SELECT
        Id,
        Opportunity__c,
        Forecast_Period__c,
        User__c,
        User__r.Name,
        Hierarchy_Level__c,
        Forecast_Category__c,
        Metric_1_Value__c,
        Metric_2_Value__c,
        Metric_3_Value__c,
        Metric_4_Value__c,
        Metric_5_Value__c,
        Metric_6_Value__c,
        Close_Date_Override__c,
        Status__c
      FROM Forecast_Override__c
      WHERE
        Opportunity__c IN :recordIds
        AND Forecast_Period__c = :periodId
        AND Hierarchy_Level__c = :previousLevel
        AND Status__c = 'Submitted'
    ];

    for (Forecast_Override__c ov : overrides) {
      resultMap.put(ov.Opportunity__c, ov);
    }
    return resultMap;
  }

  /**
   * @description Get the active forecast configuration with child metrics
   *              and categories, ordered by Sort_Order__c.
   * @return The active Forecast_Configuration__c or null
   */
  public static Forecast_Configuration__c getActiveConfig() {
    if (cachedConfig != null) {
      return cachedConfig;
    }

    List<Forecast_Configuration__c> configs = [
      SELECT
        Id,
        Name,
        Is_Active__c,
        Period_Type__c,
        Future_Periods_Visible__c,
        Pipeline_Record_Type_Filter__c,
        Pagination_Size__c,
        Currency_Mode__c,
        Corporate_Currency__c,
        Attainment_Layout__c,
        Top_Level_Lock_Label__c,
        Hourly_Snapshot_Days__c,
        Hourly_Snapshot_Interval__c,
        Scope_Determination__c,
        Attainment_Source__c,
        Past_Periods_Visible__c,
        Default_Horizon__c,
        Custom_Horizon_Periods__c,
        Final_Forecast_Label__c,
        Stretch_Forecast_Label__c,
        Level_Labels__c,
        Forecast_Cadence__c,
        Submission_Deadline_Day__c,
        Cadence_Anchor_Date__c,
        Auto_Freeze_On_Deadline__c,
        Scope_Custom_Object__c,
        Scope_Custom_Field__c,
        Fiscal_Year_Start_Month__c,
        Summary_All_Metrics__c,
        (
          SELECT
            Id,
            Name,
            Metric_Label__c,
            Metric_Type__c,
            Display_Format__c,
            Is_Primary__c,
            Is_Required__c,
            Sort_Order__c,
            Is_Editable__c,
            Source_Field__c,
            Source_Object__c,
            Source_Lookup_Field__c,
            Aggregation__c,
            Forecast_Group__c
          FROM Forecast_Metrics__r
          ORDER BY Sort_Order__c ASC
        ),
        (
          SELECT
            Id,
            Name,
            Category_Label__c,
            Category_API_Name__c,
            Color_Hex__c,
            Counts_Toward_Target__c,
            Counts_Toward_Stretch__c,
            Is_Terminal__c,
            Is_High_Confidence__c,
            Regression_Warning__c,
            Sort_Order__c,
            Is_Active__c
          FROM Forecast_Categories__r
          ORDER BY Sort_Order__c ASC
        )
      FROM Forecast_Configuration__c
      WHERE Is_Active__c = TRUE
      LIMIT 1
    ];

    cachedConfig = configs.isEmpty() ? null : configs[0];
    return cachedConfig;
  }

  /**
   * @description Get forecast participant for a user + period + scope.
   * @param userId The User Id
   * @param periodId The Forecast_Period__c Id
   * @param scopeId The scope/territory identifier
   * @return The matching Forecast_Participant__c or null
   */
  public static Forecast_Participant__c getParticipant(
    Id userId,
    Id periodId,
    String scopeId
  ) {
    List<Forecast_Participant__c> participants = [
      SELECT
        Id,
        User__c,
        Forecast_Period__c,
        Scope_Id__c,
        Hierarchy_Level__c,
        Submission_Status__c,
        Reports_To__c,
        Is_Summary__c,
        Delegate__c,
        Delegate_Start__c,
        Delegate_End__c
      FROM Forecast_Participant__c
      WHERE
        User__c = :userId
        AND Forecast_Period__c = :periodId
        AND Scope_Id__c = :scopeId
      LIMIT 1
    ];
    return participants.isEmpty() ? null : participants[0];
  }

  /**
   * @description Get all participants in a scope for a period (used by freeze).
   * @param scopeId The scope/territory identifier
   * @param periodId The Forecast_Period__c Id
   * @return List of participants in scope
   */
  public static List<Forecast_Participant__c> getParticipantsInScope(
    String scopeId,
    Id periodId
  ) {
    return [
      SELECT
        Id,
        User__c,
        Forecast_Period__c,
        Scope_Id__c,
        Hierarchy_Level__c,
        Submission_Status__c,
        Reports_To__c,
        Is_Summary__c
      FROM Forecast_Participant__c
      WHERE Scope_Id__c = :scopeId AND Forecast_Period__c = :periodId
    ];
  }

  /**
   * @description Get the previous forecast period for copy-from-last operations.
   *              Finds the most recent period whose End_Date precedes the current
   *              period's Start_Date.
   * @param currentPeriodId The current Forecast_Period__c Id
   * @return The previous Forecast_Period__c or null
   */
  public static Forecast_Period__c getPreviousPeriod(Id currentPeriodId) {
    Forecast_Period__c currentPeriod = [
      SELECT Id, Start_Date__c
      FROM Forecast_Period__c
      WHERE Id = :currentPeriodId
      LIMIT 1
    ];
    if (currentPeriod == null || currentPeriod.Start_Date__c == null) {
      return null;
    }

    Date currentStart = currentPeriod.Start_Date__c;
    List<Forecast_Period__c> previousPeriods = [
      SELECT Id, Name, Start_Date__c, End_Date__c, Status__c
      FROM Forecast_Period__c
      WHERE End_Date__c < :currentStart
      ORDER BY End_Date__c DESC
      LIMIT 1
    ];
    return previousPeriods.isEmpty() ? null : previousPeriods[0];
  }

  /**
   * @description Get health scores for pipeline records from Deal_Signal__c.
   * @param recordIds Set of pipeline record IDs
   * @return Map of pipeline record Id to Deal_Signal__c
   */
  public static Map<Id, Deal_Signal__c> getHealthScores(Set<Id> recordIds) {
    Map<Id, Deal_Signal__c> resultMap = new Map<Id, Deal_Signal__c>();
    if (recordIds == null || recordIds.isEmpty()) {
      return resultMap;
    }

    for (Deal_Signal__c signal : [
      SELECT Id, Opportunity__c, Health_Score__c, Score_Band__c
      FROM Deal_Signal__c
      WHERE Opportunity__c IN :recordIds
    ]) {
      resultMap.put(signal.Opportunity__c, signal);
    }
    return resultMap;
  }

  /**
   * @description Get a Forecast_Quota__c record for a user and period.
   *              Used by ForecastService.loadAttainmentData() when
   *              Attainment_Source__c includes Forecast_Quota__c.
   * @param userId The User Id
   * @param periodId The Forecast_Period__c Id
   * @return The matching Forecast_Quota__c or null
   */
  public static Forecast_Quota__c getForecastQuota(Id userId, Id periodId) {
    return getForecastQuota(userId, periodId, null);
  }

  /**
   * @description Phase B: Group-aware quota resolution.
   *              Returns the most-specific quota matching (user, period, group):
   *              1. group-specific quota wins
   *              2. config-wide quota (Forecast_Group__c = null) is fallback
   *              3. null if neither exists
   *              When groupId is null, only config-wide quota is returned.
   */
  public static Forecast_Quota__c getForecastQuota(
    Id userId,
    Id periodId,
    Id groupId
  ) {
    // Try group-specific first
    if (groupId != null) {
      List<Forecast_Quota__c> groupQuotas = [
        SELECT
          Id,
          User__c,
          Forecast_Period__c,
          Forecast_Group__c,
          Target_Amount__c,
          Achieved_Amount__c,
          Attainment_Pct__c,
          Status__c
        FROM Forecast_Quota__c
        WHERE
          User__c = :userId
          AND Forecast_Period__c = :periodId
          AND Forecast_Group__c = :groupId
          AND Status__c = 'Active'
        LIMIT 1
      ];
      if (!groupQuotas.isEmpty()) {
        return groupQuotas[0];
      }
    }
    // Fall back to config-wide (Forecast_Group__c = null)
    List<Forecast_Quota__c> wideQuotas = [
      SELECT
        Id,
        User__c,
        Forecast_Period__c,
        Forecast_Group__c,
        Target_Amount__c,
        Achieved_Amount__c,
        Attainment_Pct__c,
        Status__c
      FROM Forecast_Quota__c
      WHERE
        User__c = :userId
        AND Forecast_Period__c = :periodId
        AND Forecast_Group__c = NULL
        AND Status__c = 'Active'
      LIMIT 1
    ];
    return wideQuotas.isEmpty() ? null : wideQuotas[0];
  }

  // ── Private helpers ────────────────────────────────────────────────

  /**
   * @description Public wrapper for getUsersInHierarchy. Allows callers
   *              (e.g. bulk horizon aggregation) to resolve the hierarchy
   *              without re-querying the participant.
   */
  public static Set<Id> getUsersInHierarchyPublic(
    Id userId,
    Id participantId,
    Id periodId
  ) {
    return getUsersInHierarchy(userId, participantId, periodId);
  }

  /**
   * @description Find all user IDs in the reporting hierarchy below a participant.
   *              Used for ownership-based scope to determine pipeline visibility.
   */
  private static Set<Id> getUsersInHierarchy(
    Id userId,
    Id participantId,
    Id periodId
  ) {
    Set<Id> userIds = new Set<Id>{ userId };

    // Find all participants who report to this participant (direct + indirect)
    Map<Id, Forecast_Participant__c> allParticipants = new Map<Id, Forecast_Participant__c>(
      [
        SELECT Id, User__c, Reports_To__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId
      ]
    );

    // Build set of subordinate user IDs by walking the Reports_To chain
    Set<Id> participantIds = new Set<Id>{ participantId };
    Boolean foundNew = true;
    while (foundNew) {
      foundNew = false;
      for (Forecast_Participant__c p : allParticipants.values()) {
        if (
          p.Reports_To__c != null &&
          participantIds.contains(p.Reports_To__c) &&
          !participantIds.contains(p.Id)
        ) {
          participantIds.add(p.Id);
          userIds.add(p.User__c);
          foundNew = true;
        }
      }
    }

    return userIds;
  }

  /**
   * @description Build the field list for pipeline queries using PipelineObjectService
   *              mappings plus standard Id field.
   */
  public static String buildPipelineFieldList() {
    // Leverage PipelineObjectService's field resolution
    Set<String> fields = new Set<String>{
      'Id',
      'Name',
      'OwnerId',
      'Owner.Name',
      'CloseDate',
      'Amount',
      'StageName',
      'IsClosed',
      'IsWon',
      'LastModifiedDate'
    };
    // Phase B: include RecordType + Type only if they exist on this org's Opportunity
    // (some test contexts and slim orgs don't have RT enabled).
    Map<String, Schema.SObjectField> oppFields = Opportunity.SObjectType.getDescribe()
      .fields.getMap();
    if (oppFields.containsKey('recordtypeid')) {
      fields.add('RecordTypeId');
      fields.add('RecordType.DeveloperName');
    }
    if (oppFields.containsKey('type')) {
      fields.add('Type');
    }
    // Phase D: Add configured display fields (use cache if available)
    List<Forecast_Display_Field__c> displayFields = cachedDisplayFields;
    if (displayFields == null) {
      Forecast_Configuration__c activeCfg = getActiveConfig();
      if (activeCfg != null) {
        displayFields = [
          SELECT Field_API_Name__c, Object_API_Name__c
          FROM Forecast_Display_Field__c
          WHERE
            Forecast_Configuration__c = :activeCfg.Id
            AND Is_Active__c = TRUE
        ];
      }
    }
    if (displayFields != null) {
      Map<String, Schema.SObjectField> oppFields2 = Opportunity.SObjectType.getDescribe()
        .fields.getMap();
      for (Forecast_Display_Field__c df : displayFields) {
        String srcObj = df.Object_API_Name__c;
        String field = df.Field_API_Name__c;
        if (String.isBlank(field)) {
          continue;
        }

        if (srcObj == 'Opportunity') {
          // Direct Opportunity field
          if (oppFields2.containsKey(field.toLowerCase())) {
            fields.add(field);
            Schema.DescribeFieldResult fieldDesc = oppFields2.get(
                field.toLowerCase()
              )
              .getDescribe();
            if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
              String relName = fieldDesc.getRelationshipName();
              if (relName != null) {
                fields.add(relName + '.Name');
              }
            }
          }
        } else {
          // Parent object field (e.g., Account.Industry, Campaign.Name)
          // Find the lookup field on Opportunity that points to this parent object
          for (Schema.SObjectField oppF : oppFields2.values()) {
            Schema.DescribeFieldResult fDesc = oppF.getDescribe();
            if (fDesc.getType() != Schema.DisplayType.REFERENCE) {
              continue;
            }
            List<Schema.SObjectType> refs = fDesc.getReferenceTo();
            if (!refs.isEmpty() && refs[0].getDescribe().getName() == srcObj) {
              String relName = fDesc.getRelationshipName();
              if (relName != null) {
                fields.add(relName + '.' + field);
              }
              break;
            }
          }
        }
      }
    }
    return String.join(new List<String>(fields), ', ');
  }

  /**
   * @description Reset cached config. Used in tests.
   */
  @TestVisible
  private static void resetCache() {
    cachedConfig = null;
    cachedDisplayFields = null;
  }

  /**
   * @description Public cache invalidation. Called by Admin Console and
   *              Onboarding Controller after config changes.
   */
  public static void clearConfigCache() {
    resetCache();
  }
}
