/**
 * @description Business logic service for the Forecasting module.
 *              Handles save, submit, freeze, copy, override lifecycle,
 *              participant context, config loading, and summary computation.
 *
 *              All methods called by ForecastController (thin controller pattern).
 *              Uses ForecastDataService for query abstraction and PipelineObjectService
 *              for dynamic pipeline field resolution.
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md V1.1
 */
public with sharing class ForecastService {
  // Period statuses that allow edits
  private static final Set<String> EDITABLE_PERIOD_STATUSES = new Set<String>{
    'Open',
    'Prelock'
  };

  // Copy mode constants (§11.15)
  private static final String COPY_MODE_OVERWRITE = 'OVERWRITE';
  private static final String COPY_MODE_MERGE = 'MERGE';
  private static final String COPY_MODE_SKIP_EDITED = 'SKIP_EDITED';

  // Hierarchy level labels (positional)
  private static final Map<Integer, String> DEFAULT_LEVEL_LABELS = new Map<Integer, String>{
    1 => 'Rep',
    2 => 'Manager',
    3 => 'Director',
    4 => 'VP',
    5 => 'SVP'
  };

  // ══════════════════════════════════════════════════════════════════════
  //  CONFIG
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Load active Forecast_Configuration__c with child metrics and categories.
   *              Returns a cacheable ForecastConfigDTO.
   */
  public static ForecastController.ForecastConfigDTO loadConfig() {
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    ForecastController.ForecastConfigDTO dto = new ForecastController.ForecastConfigDTO();

    if (config == null) {
      dto.metrics = new List<ForecastController.ForecastMetricDTO>();
      dto.categories = new List<ForecastController.ForecastCategoryDTO>();
      dto.periods = new List<ForecastController.ForecastPeriodDTO>();
      dto.paginationSize = 40;
      return dto;
    }

    // Map metrics
    dto.metrics = new List<ForecastController.ForecastMetricDTO>();
    if (config.Forecast_Metrics__r != null) {
      for (Forecast_Metric__c m : config.Forecast_Metrics__r) {
        ForecastController.ForecastMetricDTO mDto = new ForecastController.ForecastMetricDTO();
        mDto.metricId = m.Id;
        mDto.name = m.Name;
        mDto.label = m.Metric_Label__c;
        mDto.metricType = m.Metric_Type__c;
        mDto.format = m.Display_Format__c;
        mDto.isPrimary = m.Is_Primary__c;
        mDto.isRequired = m.Is_Required__c;
        mDto.isEditable = m.Is_Editable__c;
        mDto.sortOrder = m.Sort_Order__c != null
          ? m.Sort_Order__c.intValue()
          : 0;
        mDto.fieldApiName = m.Source_Field__c;
        dto.metrics.add(mDto);
      }
    }

    // Map categories
    dto.categories = new List<ForecastController.ForecastCategoryDTO>();
    if (config.Forecast_Categories__r != null) {
      for (Forecast_Category__c c : config.Forecast_Categories__r) {
        ForecastController.ForecastCategoryDTO cDto = new ForecastController.ForecastCategoryDTO();
        cDto.categoryId = c.Id;
        cDto.name = c.Name;
        cDto.label = c.Category_Label__c;
        cDto.apiName = c.Category_API_Name__c;
        cDto.color = c.Color_Hex__c;
        cDto.countsTowardTarget = c.Counts_Toward_Target__c;
        cDto.isTerminal = c.Is_Terminal__c;
        cDto.isHighConfidence = c.Is_High_Confidence__c;
        cDto.isRegression = c.Regression_Warning__c;
        cDto.sortOrder = c.Sort_Order__c != null
          ? c.Sort_Order__c.intValue()
          : 0;
        cDto.isActive = c.Is_Active__c;
        dto.categories.add(cDto);
      }
    }

    // Load periods (Open + Scheduled)
    dto.periods = new List<ForecastController.ForecastPeriodDTO>();
    List<Forecast_Period__c> periods = [
      SELECT
        Id,
        Name,
        Start_Date__c,
        End_Date__c,
        Status__c,
        Period_Type__c,
        Budget_Mode__c
      FROM Forecast_Period__c
      WHERE Status__c IN ('Open', 'Scheduled')
      ORDER BY Start_Date__c ASC
    ];
    for (Forecast_Period__c p : periods) {
      dto.periods.add(mapPeriodDTO(p));
    }

    // Find current active period
    Date today = Date.today();
    for (Forecast_Period__c p : periods) {
      if (
        p.Status__c == 'Open' &&
        p.Start_Date__c <= today &&
        p.End_Date__c >= today
      ) {
        dto.currentPeriod = mapPeriodDTO(p);
        break;
      }
    }
    // Fallback: first open period
    if (dto.currentPeriod == null && !periods.isEmpty()) {
      for (Forecast_Period__c p : periods) {
        if (p.Status__c == 'Open') {
          dto.currentPeriod = mapPeriodDTO(p);
          break;
        }
      }
    }

    dto.periodType = config.Period_Type__c;
    dto.currencyMode = config.Currency_Mode__c;
    dto.corporateCurrency = config.Corporate_Currency__c;
    dto.attainmentLayout = config.Attainment_Layout__c;
    dto.topLevelActionType = config.Top_Level_Lock_Label__c;
    dto.topLevelActionLabel = config.Top_Level_Lock_Label__c;
    dto.paginationSize = config.Pagination_Size__c != null
      ? config.Pagination_Size__c.intValue()
      : 40;
    dto.hierarchySource = config.Scope_Determination__c;

    return dto;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PARTICIPANT CONTEXT
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Load mutable participant context for a user + period + scope.
   *              Includes permissions, attainment, available scopes, delegation.
   */
  public static ForecastController.ForecastParticipantContextDTO loadParticipantContext(
    Id userId,
    Id periodId,
    String scopeId
  ) {
    ForecastController.ForecastParticipantContextDTO ctx = new ForecastController.ForecastParticipantContextDTO();

    // Load participant record — if scopeId is null, find any non-summary participant
    Forecast_Participant__c participant;
    if (String.isNotBlank(scopeId)) {
      participant = ForecastDataService.getParticipant(
        userId,
        periodId,
        scopeId
      );
    } else {
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
          AND Is_Summary__c = FALSE
        LIMIT 1
      ];
      participant = participants.isEmpty() ? null : participants[0];
    }

    if (participant == null) {
      ctx.canEdit = false;
      ctx.canSubmit = false;
      ctx.canFreeze = false;
      ctx.hierarchyLevel = 0;
      ctx.availableScopes = new List<ForecastController.ScopeDTO>();
      return ctx;
    }

    // Map participant DTO
    ForecastController.ForecastParticipantDTO pDto = new ForecastController.ForecastParticipantDTO();
    pDto.participantId = participant.Id;
    pDto.userId = participant.User__c;
    pDto.level = participant.Hierarchy_Level__c != null
      ? participant.Hierarchy_Level__c.intValue()
      : 1;
    pDto.levelLabel = DEFAULT_LEVEL_LABELS.containsKey(pDto.level)
      ? DEFAULT_LEVEL_LABELS.get(pDto.level)
      : 'Level ' + pDto.level;
    pDto.scopeId = participant.Scope_Id__c;
    pDto.status = participant.Submission_Status__c;
    ctx.participant = pDto;

    ctx.hierarchyLevel = pDto.level;
    ctx.levelLabel = pDto.levelLabel;
    ctx.submissionStatus = participant.Submission_Status__c;

    // Derive permissions from hierarchy level
    ctx.canEdit = true;
    ctx.canSubmit = true;
    // Only top-level can freeze (determined by checking if anyone reports TO them)
    Integer maxLevel = getMaxHierarchyLevel(periodId);
    ctx.canFreeze = (pDto.level == maxLevel);

    // Check period status for edit permission
    Forecast_Period__c period = queryPeriod(periodId);
    if (period != null) {
      if (!EDITABLE_PERIOD_STATUSES.contains(period.Status__c)) {
        ctx.canEdit = false;
        ctx.canSubmit = false;
      }
      ctx.isBudgetMode = period.Budget_Mode__c;
    }

    // Delegation check: if the calling user is not the participant's user,
    // this is delegated access
    ctx.isDelegatedAccess = (userId != UserInfo.getUserId());

    // Load attainment from Quota__c
    ctx.attainment = loadAttainment(participant.User__c, periodId);

    // Load available scopes for multi-scope users
    ctx.availableScopes = loadAvailableScopes(userId, periodId);

    return ctx;
  }

  /**
   * @description Validate that the caller has access to view/edit the target participant.
   *              Checks hierarchy level, delegation, admin permission.
   * @throws System.NoAccessException if not authorized
   */
  public static void validateAccess(Id callerId, Id targetParticipantId) {
    // Load target participant
    Forecast_Participant__c target = [
      SELECT
        Id,
        User__c,
        Hierarchy_Level__c,
        Scope_Id__c,
        Forecast_Period__c,
        Reports_To__c,
        Delegate__c,
        Delegate_Start__c,
        Delegate_End__c
      FROM Forecast_Participant__c
      WHERE Id = :targetParticipantId
      LIMIT 1
    ];

    if (target == null) {
      throw new AuraHandledException('Participant record not found.');
    }

    // 1. Is caller the participant themselves?
    if (callerId == target.User__c) {
      return;
    }

    // 2. Is caller at a higher hierarchy level in the same scope chain?
    List<Forecast_Participant__c> callerParticipants = [
      SELECT Id, User__c, Hierarchy_Level__c, Scope_Id__c
      FROM Forecast_Participant__c
      WHERE
        User__c = :callerId
        AND Forecast_Period__c = :target.Forecast_Period__c
    ];

    for (Forecast_Participant__c callerP : callerParticipants) {
      if (callerP.Hierarchy_Level__c > target.Hierarchy_Level__c) {
        // Verify scope chain: walk Reports_To from target up to caller
        if (
          isInScopeChain(target.Id, callerP.User__c, target.Forecast_Period__c)
        ) {
          return;
        }
      }
    }

    // 3. Is caller a delegate?
    if (target.Delegate__c == callerId) {
      Date today = Date.today();
      if (
        (target.Delegate_Start__c == null ||
        target.Delegate_Start__c <= today) &&
        (target.Delegate_End__c == null ||
        target.Delegate_End__c >= today)
      ) {
        return;
      }
    }

    // 4. Platform_Admin permission set check
    List<PermissionSetAssignment> adminAssignments = [
      SELECT Id
      FROM PermissionSetAssignment
      WHERE AssigneeId = :callerId AND PermissionSet.Name = 'Platform_Admin'
      LIMIT 1
    ];
    if (!adminAssignments.isEmpty()) {
      return;
    }

    throw new AuraHandledException(
      'Insufficient permission to access this participant\'s forecast data.'
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  RECORDS (§11.2)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Query paginated forecast records with filters, sort, and search.
   *              Merges pipeline records with overrides and enriches with health scores
   *              and incentive estimates.
   */
  public static ForecastController.ForecastRecordSet queryForecastRecords(
    ForecastController.ForecastQueryRequest request
  ) {
    ForecastController.ForecastRecordSet result = new ForecastController.ForecastRecordSet();
    result.records = new List<ForecastController.ForecastRecordDTO>();

    // 1. Query pipeline records in scope via ForecastDataService
    List<SObject> pipelineRecords = ForecastDataService.getPipelineRecordsForScope(
      request.participantId,
      request.scopeId,
      request.periodId
    );

    if (pipelineRecords.isEmpty()) {
      result.totalCount = 0;
      result.totalUnfilteredCount = 0;
      result.pageNumber = 1;
      result.pageSize = request.pageSize != null ? request.pageSize : 40;
      return result;
    }

    result.totalUnfilteredCount = pipelineRecords.size();

    // 2. LEFT JOIN to Forecast_Override__c
    Set<Id> recordIds = new Set<Id>();
    for (SObject rec : pipelineRecords) {
      recordIds.add(rec.Id);
    }
    Map<Id, Forecast_Override__c> overrideMap = ForecastDataService.getOverridesForRecords(
      recordIds,
      request.periodId,
      request.participantId
    );

    // 3. LEFT JOIN to Deal_Signal__c for health scores
    Map<Id, Deal_Signal__c> healthMap = ForecastDataService.getHealthScores(
      recordIds
    );

    // 3b. Load active governance flags per pipeline record (§2.1)
    Map<Id, List<String>> governanceFlagsMap = new Map<Id, List<String>>();
    for (Governance_Event__c ge : [
      SELECT Id, Opportunity__c, Rule_Name__c
      FROM Governance_Event__c
      WHERE
        Opportunity__c IN :recordIds
        AND Status__c IN ('Pending', 'Under Review')
    ]) {
      if (!governanceFlagsMap.containsKey(ge.Opportunity__c)) {
        governanceFlagsMap.put(ge.Opportunity__c, new List<String>());
      }
      governanceFlagsMap.get(ge.Opportunity__c).add(ge.Id);
    }

    // 3c. Load Previous_Period_Override data for trend indicators (§2.1)
    Map<Id, Forecast_Override__c> prevPeriodOverrideMap = new Map<Id, Forecast_Override__c>();
    for (Forecast_Override__c ov : overrideMap.values()) {
      if (ov.Previous_Period_Override__c != null) {
        prevPeriodOverrideMap.put(ov.Id, null); // placeholder, bulk-query below
      }
    }
    if (!prevPeriodOverrideMap.isEmpty()) {
      Set<Id> prevPeriodOvIds = new Set<Id>();
      for (Forecast_Override__c ov : overrideMap.values()) {
        if (ov.Previous_Period_Override__c != null) {
          prevPeriodOvIds.add(ov.Previous_Period_Override__c);
        }
      }
      Map<Id, Forecast_Override__c> prevPeriodOvs = new Map<Id, Forecast_Override__c>(
        [
          SELECT
            Id,
            Metric_1_Value__c,
            Metric_2_Value__c,
            Metric_3_Value__c,
            Metric_4_Value__c,
            Metric_5_Value__c,
            Metric_6_Value__c
          FROM Forecast_Override__c
          WHERE Id IN :prevPeriodOvIds
        ]
      );
      // Re-key by current override's pipeline record Id
      for (Id pipelineRecId : overrideMap.keySet()) {
        Forecast_Override__c currentOv = overrideMap.get(pipelineRecId);
        if (
          currentOv.Previous_Period_Override__c != null &&
          prevPeriodOvs.containsKey(currentOv.Previous_Period_Override__c)
        ) {
          prevPeriodOverrideMap.put(
            pipelineRecId,
            prevPeriodOvs.get(currentOv.Previous_Period_Override__c)
          );
        }
      }
    }

    // 4. Build ForecastRecordDTO list (merged pipeline + override)
    // Load participant for hierarchy level context
    Forecast_Participant__c participant = [
      SELECT Id, User__c, Hierarchy_Level__c
      FROM Forecast_Participant__c
      WHERE Id = :request.participantId
      LIMIT 1
    ];
    Integer currentLevel = participant != null &&
      participant.Hierarchy_Level__c != null
      ? participant.Hierarchy_Level__c.intValue()
      : 1;

    // Load previous level overrides for comparison
    Map<Id, Forecast_Override__c> prevLevelMap = new Map<Id, Forecast_Override__c>();
    if (currentLevel > 1) {
      prevLevelMap = ForecastDataService.getPreviousLevelOverrides(
        recordIds,
        request.periodId,
        currentLevel - 1
      );
    }

    // 4b. Compute incentive estimates (if Incentives active)
    Map<Id, IncentiveImpactCalculator.ImpactResult> impactMap = new Map<Id, IncentiveImpactCalculator.ImpactResult>();
    try {
      if (participant != null) {
        IncentiveImpactCalculator.IncentiveContext incentiveCtx = IncentiveImpactCalculator.getContext(
          participant.User__c
        );
        if (incentiveCtx != null) {
          for (SObject rec : pipelineRecords) {
            try {
              IncentiveImpactCalculator.ImpactResult impact = IncentiveImpactCalculator.calculateImpact(
                rec.Id,
                participant.User__c
              );
              if (impact != null) {
                impactMap.put(rec.Id, impact);
              }
            } catch (Exception ex) {
              // Incentive calculation is optional; skip on error
            }
          }
        }
      }
    } catch (Exception ex) {
      // Incentives module may not be active; continue without estimates
    }

    // 4c. Deal-share dedup at top level (§11.5)
    // At the top hierarchy level, identify pipeline records appearing in multiple scopes
    // and apply deal contribution percentage before summing
    Integer maxLevel = getMaxHierarchyLevel(request.periodId);
    Boolean isTopLevel = (currentLevel == maxLevel);
    Map<Id, Decimal> dedupFactors = new Map<Id, Decimal>();
    if (isTopLevel) {
      dedupFactors = computeDedupFactors(recordIds, request.periodId);
    }

    // 5. Build record DTOs
    List<ForecastController.ForecastRecordDTO> allRecords = new List<ForecastController.ForecastRecordDTO>();

    for (SObject rec : pipelineRecords) {
      ForecastController.ForecastRecordDTO dto = new ForecastController.ForecastRecordDTO();
      dto.recordId = rec.Id;
      dto.recordName = (String) PipelineObjectService.getFieldValue(
        rec,
        'Pipeline.Name'
      );
      if (dto.recordName == null) {
        dto.recordName = String.valueOf(rec.get('Name'));
      }
      dto.stage = PipelineObjectService.getStage(rec);
      dto.closeDate = PipelineObjectService.getCloseDate(rec);
      dto.crmAmount = PipelineObjectService.getAmount(rec);

      // Owner name and Id
      try {
        dto.ownerName = (String) rec.getSObject('Owner')?.get('Name');
        dto.ownerId = PipelineObjectService.getOwnerId(rec);
      } catch (Exception ex) {
        dto.ownerName = '';
      }

      // Closed stage detection
      Boolean isClosed = false;
      Boolean isWon = false;
      try {
        isClosed = (Boolean) rec.get('IsClosed') == true;
        isWon = (Boolean) rec.get('IsWon') == true;
      } catch (Exception ex) {
        /* Fields may not be available */
      }
      dto.isClosed = isClosed;
      dto.isWon = isWon;

      // Override data (if exists)
      Forecast_Override__c ov = overrideMap.get(rec.Id);
      if (ov != null) {
        dto.overrideId = ov.Id;
        dto.category = ov.Forecast_Category__c;
        dto.metricValues = buildMetricValuesMap(ov);
        dto.metricValuesLocal = buildLocalMetricValuesMap(ov);
        dto.closeDateOverride = ov.Close_Date_Override__c;
        dto.status = ov.Status__c;
        dto.comment = ov.Comment__c;
        dto.hierarchyLevel = ov.Hierarchy_Level__c != null
          ? ov.Hierarchy_Level__c.intValue()
          : currentLevel;
        dto.pendingApproval = ov.Pending_Approval__c;
        dto.crmDivergence = ov.CRM_Divergence__c;
        dto.crmDivergenceDetails = ov.CRM_Divergence_Details__c;
        dto.lastModifiedDate = ov.LastModifiedDate;
        dto.dataVersion = computeDataVersion(ov.LastModifiedDate, rec);
      } else {
        // No override: show CRM defaults
        dto.status = 'New';
        dto.metricValues = new Map<String, Decimal>();
        dto.metricValuesLocal = new Map<String, Decimal>();
        dto.hierarchyLevel = currentLevel;
        dto.pendingApproval = false;
        dto.crmDivergence = false;
        dto.dataVersion = computeDataVersion(null, rec);

        // Auto-set category and metrics for closed deals
        if (isWon) {
          dto.category = 'Closed_Won';
          dto.metricValues.put('metric_1', dto.crmAmount);
        } else if (isClosed) {
          // Closed Lost — zero revenue, Lost category
          dto.category = 'Lost';
          dto.metricValues.put('metric_1', 0);
        } else {
          dto.metricValues.put('metric_1', dto.crmAmount);
        }
      }

      // Deal-share dedup adjustment at top level (§11.5)
      if (isTopLevel && dedupFactors.containsKey(rec.Id)) {
        Decimal factor = dedupFactors.get(rec.Id);
        dto.metricValuesPreDedup = new Map<String, Decimal>(dto.metricValues);
        for (String key : dto.metricValues.keySet()) {
          Decimal val = dto.metricValues.get(key);
          if (val != null) {
            dto.metricValues.put(key, (val * factor).setScale(2));
          }
        }
      }

      // Previous level values
      Forecast_Override__c prevOv = prevLevelMap.get(rec.Id);
      if (prevOv != null) {
        dto.previousLevelValues = buildMetricValuesMap(prevOv);
        dto.prevLevelCategory = prevOv.Forecast_Category__c;
        dto.prevLevel = prevOv.Hierarchy_Level__c != null
          ? prevOv.Hierarchy_Level__c.intValue()
          : null;
        try {
          dto.prevLevelUserName = prevOv.User__r != null
            ? (String) prevOv.User__r.get('Name')
            : null;
        } catch (Exception ex) {
          dto.prevLevelUserName = null;
        }
      }

      // Health scores
      Deal_Signal__c signal = healthMap.get(rec.Id);
      if (signal != null) {
        dto.healthScore = signal.Health_Score__c != null
          ? signal.Health_Score__c.intValue()
          : null;
        dto.healthBand = signal.Score_Band__c;
      }

      // Incentive estimates
      IncentiveImpactCalculator.ImpactResult impact = impactMap.get(rec.Id);
      if (impact != null) {
        dto.payoutEstimate = impact.payoutOnDeal;
        dto.incentiveRate = impact.projectedTier != null
          ? impact.projectedTier.ratePct
          : null;
        if (impact.proximities != null && !impact.proximities.isEmpty()) {
          dto.thresholdProximity = impact.proximities[0].distanceAmount;
        }
        dto.tierImpact = impact.tierImpactMessage;
      }

      // Governance flags (§2.1) — active governance event IDs for this record
      dto.governanceFlags = governanceFlagsMap.containsKey(rec.Id)
        ? governanceFlagsMap.get(rec.Id)
        : new List<String>();

      // Trend indicators (§2.1) — compare current metric values to previous period
      dto.trends = new Map<String, Integer>();
      if (ov != null) {
        Forecast_Override__c prevPeriodOv = prevPeriodOverrideMap.get(rec.Id);
        if (prevPeriodOv != null) {
          dto.trends.put(
            'metric_1',
            computeTrend(ov.Metric_1_Value__c, prevPeriodOv.Metric_1_Value__c)
          );
          dto.trends.put(
            'metric_2',
            computeTrend(ov.Metric_2_Value__c, prevPeriodOv.Metric_2_Value__c)
          );
          dto.trends.put(
            'metric_3',
            computeTrend(ov.Metric_3_Value__c, prevPeriodOv.Metric_3_Value__c)
          );
          dto.trends.put(
            'metric_4',
            computeTrend(ov.Metric_4_Value__c, prevPeriodOv.Metric_4_Value__c)
          );
          dto.trends.put(
            'metric_5',
            computeTrend(ov.Metric_5_Value__c, prevPeriodOv.Metric_5_Value__c)
          );
          dto.trends.put(
            'metric_6',
            computeTrend(ov.Metric_6_Value__c, prevPeriodOv.Metric_6_Value__c)
          );
        }
      }

      allRecords.add(dto);
    }

    // 5b. Apply filters from request
    List<ForecastController.ForecastRecordDTO> filteredRecords = applyFilters(
      allRecords,
      request
    );

    // 6. Apply sort
    filteredRecords = applySort(
      filteredRecords,
      request.sortField,
      request.sortDirection
    );

    // 7. Paginate
    Integer pageSize = request.pageSize != null ? request.pageSize : 40;
    Integer pageNumber = request.pageNumber != null ? request.pageNumber : 1;
    Integer startIndex = (pageNumber - 1) * pageSize;
    Integer endIndex = Math.min(startIndex + pageSize, filteredRecords.size());

    result.totalCount = filteredRecords.size();
    result.pageNumber = pageNumber;
    result.pageSize = pageSize;

    if (startIndex < filteredRecords.size()) {
      for (Integer i = startIndex; i < endIndex; i++) {
        result.records.add(filteredRecords[i]);
      }
    }

    // 8. Compute summary totals
    result.summary = computeSummaryFromRecords(
      allRecords,
      request.participantId,
      request.periodId
    );

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SAVE (§11.3, §11.11)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Save forecast overrides with lazy materialization.
   *              Resolves Previous_Level_Override and Previous_Period_Override
   *              on new override creation (§11.3).
   */
  public static ForecastController.SaveResult saveOverrides(
    ForecastController.SaveForecastRequest request
  ) {
    ForecastController.SaveResult result = new ForecastController.SaveResult();
    result.success = true;
    result.errors = new List<String>();
    result.updatedOverrideIds = new List<Id>();

    try {
      // 1. Validate period status
      Forecast_Period__c period = queryPeriod(request.periodId);
      if (period == null) {
        result.success = false;
        result.errors.add('Forecast period not found.');
        return result;
      }
      if (!EDITABLE_PERIOD_STATUSES.contains(period.Status__c)) {
        result.success = false;
        result.errors.add(
          'Period is ' + period.Status__c + ' and cannot be edited.'
        );
        return result;
      }

      // Load participant
      Forecast_Participant__c participant = [
        SELECT Id, User__c, Hierarchy_Level__c, Scope_Id__c
        FROM Forecast_Participant__c
        WHERE Id = :request.participantId
        LIMIT 1
      ];
      if (participant == null) {
        result.success = false;
        result.errors.add('Participant not found.');
        return result;
      }
      Integer currentLevel = participant.Hierarchy_Level__c != null
        ? participant.Hierarchy_Level__c.intValue()
        : 1;

      // Resolve previous period for Previous_Period_Override linkage (§11.3f)
      Forecast_Period__c previousPeriod = ForecastDataService.getPreviousPeriod(
        request.periodId
      );

      // 2. Process each override DTO
      List<Forecast_Override__c> toInsert = new List<Forecast_Override__c>();
      List<Forecast_Override__c> toUpdate = new List<Forecast_Override__c>();

      for (ForecastController.ForecastOverrideSaveDTO dto : request.overrides) {
        if (dto.overrideId == null) {
          // NEW override — lazy materialization (§11.3)
          Forecast_Override__c newOv = new Forecast_Override__c();
          newOv.Opportunity__c = dto.recordId;
          newOv.Forecast_Period__c = request.periodId;
          newOv.User__c = participant.User__c;
          newOv.Forecast_Participant__c = participant.Id;
          newOv.Hierarchy_Level__c = currentLevel;
          newOv.Status__c = 'Saved';
          newOv.Saved_On__c = Datetime.now();
          newOv.Forecast_Category__c = dto.category;
          newOv.Close_Date_Override__c = dto.closeDateOverride;
          newOv.Comment__c = dto.comment;
          setMetricValues(newOv, dto.metricValues);

          // §11.3e — Resolve Previous_Level_Override
          if (currentLevel > 1) {
            List<Forecast_Override__c> prevLevelOverrides = [
              SELECT Id
              FROM Forecast_Override__c
              WHERE
                Opportunity__c = :dto.recordId
                AND Forecast_Period__c = :request.periodId
                AND Hierarchy_Level__c = :(currentLevel - 1)
                AND Status__c IN ('Submitted', 'Frozen')
              LIMIT 1
            ];
            if (!prevLevelOverrides.isEmpty()) {
              newOv.Previous_Level_Override__c = prevLevelOverrides[0].Id;
            }
          }

          // §11.3f — Resolve Previous_Period_Override
          if (previousPeriod != null) {
            List<Forecast_Override__c> prevPeriodOverrides = [
              SELECT Id
              FROM Forecast_Override__c
              WHERE
                Opportunity__c = :dto.recordId
                AND Forecast_Period__c = :previousPeriod.Id
                AND User__c = :participant.User__c
              LIMIT 1
            ];
            if (!prevPeriodOverrides.isEmpty()) {
              newOv.Previous_Period_Override__c = prevPeriodOverrides[0].Id;
            }
          }

          // Exchange rate: live rate for draft (not frozen until submit)
          newOv.Exchange_Rate__c = getExchangeRate(dto.recordId);
          computeLocalCurrencyValues(newOv);

          toInsert.add(newOv);
        } else {
          // EXISTING override — update
          // Conflict detection (LWC V1.2): check dataVersion unless forceOverwrite
          if (
            dto.forceOverwrite != true && String.isNotBlank(dto.dataVersion)
          ) {
            Forecast_Override__c dbOv = [
              SELECT Id, LastModifiedDate, Opportunity__c
              FROM Forecast_Override__c
              WHERE Id = :dto.overrideId
              LIMIT 1
            ];
            if (dbOv != null) {
              SObject pipeRec = null;
              try {
                pipeRec = PipelineObjectService.queryRecord(
                  dbOv.Opportunity__c
                );
              } catch (Exception pEx) {
                /* ignore */
              }
              String currentVersion = computeDataVersion(
                dbOv.LastModifiedDate,
                pipeRec
              );
              if (currentVersion != dto.dataVersion) {
                result.errors.add(
                  'CONFLICT:' +
                    dto.recordId +
                    ':Record modified since you loaded this page. Refresh to see changes.'
                );
                continue;
              }
            }
          }

          Forecast_Override__c existingOv = new Forecast_Override__c();
          existingOv.Id = dto.overrideId;
          existingOv.Status__c = 'Saved';
          existingOv.Saved_On__c = Datetime.now();
          existingOv.Forecast_Category__c = dto.category;
          existingOv.Close_Date_Override__c = dto.closeDateOverride;
          existingOv.Comment__c = dto.comment;
          setMetricValues(existingOv, dto.metricValues);

          // Refresh exchange rate for draft saves
          existingOv.Exchange_Rate__c = getExchangeRate(dto.recordId);
          computeLocalCurrencyValues(existingOv);

          toUpdate.add(existingOv);
        }
      }

      // 3. DML
      if (!toInsert.isEmpty()) {
        insert toInsert;
        for (Forecast_Override__c ov : toInsert) {
          result.updatedOverrideIds.add(ov.Id);
        }
      }
      if (!toUpdate.isEmpty()) {
        update toUpdate;
        for (Forecast_Override__c ov : toUpdate) {
          result.updatedOverrideIds.add(ov.Id);
        }
      }

      // 4. Update participant status
      String newStatus = request.isPartial == true
        ? 'Partially_Saved'
        : 'Saved';
      participant.Submission_Status__c = newStatus;
      update participant;

      // Audit log
      IncentiveChangeEventService.logEvent(
        'Forecast_Override',
        request.participantId,
        'FORECAST_SAVED',
        null,
        'Saved ' + request.overrides.size() + ' override(s)',
        'Period: ' + request.periodId
      );
    } catch (Exception ex) {
      result.success = false;
      result.errors.add(ex.getMessage());
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SUBMIT (§11.7, §11.11)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Submit forecast overrides: save, set status, freeze exchange rates,
   *              create snapshot, update participant status.
   */
  public static ForecastController.SubmitResult submitOverrides(
    ForecastController.SubmitForecastRequest request
  ) {
    ForecastController.SubmitResult result = new ForecastController.SubmitResult();
    result.success = true;
    result.errors = new List<String>();
    result.notificationsSent = 0;

    try {
      // 0. Validate completeness if requested (§11.11)
      if (request.validateCompleteness == true) {
        Forecast_Participant__c subParticipant = [
          SELECT Id, User__c, Scope_Id__c
          FROM Forecast_Participant__c
          WHERE Id = :request.participantId
          LIMIT 1
        ];
        if (subParticipant != null) {
          List<SObject> pipelineInScope = ForecastDataService.getPipelineRecordsForScope(
            request.participantId,
            subParticipant.Scope_Id__c,
            request.periodId
          );
          Set<Id> pipelineIds = new Set<Id>();
          for (SObject rec : pipelineInScope) {
            pipelineIds.add(rec.Id);
          }
          Map<Id, Forecast_Override__c> existingOvs = ForecastDataService.getOverridesForRecords(
            pipelineIds,
            request.periodId,
            request.participantId
          );
          Integer uncovered =
            pipelineIds.size() -
            existingOvs.size() -
            request.overrides.size();
          if (uncovered > 0) {
            result.success = false;
            result.errors.add(
              uncovered +
                ' pipeline record(s) have no override. ' +
                'Review all records before submitting, or set validateCompleteness = false.'
            );
            return result;
          }
        }
      }

      // 1. Save first (reuses save logic)
      ForecastController.SaveForecastRequest saveReq = new ForecastController.SaveForecastRequest();
      saveReq.overrides = request.overrides;
      saveReq.periodId = request.periodId;
      saveReq.participantId = request.participantId;
      saveReq.isPartial = request.isPartial;

      ForecastController.SaveResult saveResult = saveOverrides(saveReq);
      if (!saveResult.success) {
        result.success = false;
        result.errors.addAll(saveResult.errors);
        return result;
      }

      // 2. Set Status = 'Submitted', Submitted_On = now, FREEZE exchange rate
      List<Id> savedIds = saveResult.updatedOverrideIds;
      if (!savedIds.isEmpty()) {
        List<Forecast_Override__c> overridesToSubmit = [
          SELECT
            Id,
            Status__c,
            Submitted_On__c,
            Exchange_Rate__c,
            Opportunity__c
          FROM Forecast_Override__c
          WHERE Id IN :savedIds
        ];

        for (Forecast_Override__c ov : overridesToSubmit) {
          ov.Status__c = 'Submitted';
          ov.Submitted_On__c = Datetime.now();
          // §12.6 — FREEZE exchange rate on submit
          if (request.freezeExchangeRates != false) {
            // Rate is already set from save; freezing means we don't update it again
            // The Exchange_Rate__c value at this point becomes the frozen rate
          }
        }
        update overridesToSubmit;
      }

      // 3. Create Forecast_Snapshot__c (Submit type) — §11.7
      Forecast_Snapshot__c snapshot = new Forecast_Snapshot__c();
      snapshot.Forecast_Period__c = request.periodId;
      snapshot.Forecast_Participant__c = request.participantId;
      snapshot.Snapshot_Type__c = 'Submit';
      snapshot.Snapshot_Date__c = Date.today();
      snapshot.Total_Records__c = savedIds.size();

      // Aggregate submitted values for snapshot
      AggregateResult[] aggs = [
        SELECT
          SUM(Metric_1_Value__c) sumM1,
          SUM(Metric_2_Value__c) sumM2,
          SUM(Metric_3_Value__c) sumM3
        FROM Forecast_Override__c
        WHERE Id IN :savedIds
      ];
      if (!aggs.isEmpty()) {
        snapshot.Commit_Total__c = (Decimal) aggs[0].get('sumM1');
        snapshot.Best_Case_Total__c = (Decimal) aggs[0].get('sumM2');
        snapshot.Pipeline_Total__c = (Decimal) aggs[0].get('sumM3');
      }

      insert snapshot;
      result.snapshotId = snapshot.Id;

      // 4. Update participant status to 'Submitted'
      Forecast_Participant__c participant = [
        SELECT
          Id,
          User__c,
          Hierarchy_Level__c,
          Reports_To__c,
          Reports_To__r.User__c,
          Forecast_Period__c
        FROM Forecast_Participant__c
        WHERE Id = :request.participantId
        LIMIT 1
      ];
      participant.Submission_Status__c = 'Submitted';
      update participant;

      // 5. Send notification to next-level reviewer (§2.2 step 7)
      if (
        participant.Reports_To__c != null &&
        participant.Reports_To__r.User__c != null
      ) {
        try {
          // Use custom notification type for forecast submissions
          CustomNotificationType notifType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Forecast_Submission'
            LIMIT 1
          ];
          Messaging.CustomNotification notification = new Messaging.CustomNotification();
          notification.setTitle('Forecast Submitted');
          notification.setBody(
            'A forecast has been submitted for your review (' +
              savedIds.size() +
              ' records).'
          );
          notification.setNotificationTypeId(notifType.Id);
          notification.setTargetId(request.periodId);
          notification.send(
            new Set<String>{ participant.Reports_To__r.User__c }
          );
          result.notificationsSent = 1;
        } catch (Exception notifEx) {
          // Notification failure should not block submission
          System.debug(
            LoggingLevel.WARN,
            'ForecastService: Submit notification failed: ' +
            notifEx.getMessage()
          );
        }
      }

      // Audit log
      IncentiveChangeEventService.logEvent(
        'Forecast_Override',
        request.participantId,
        'FORECAST_SUBMITTED',
        null,
        'Submitted ' +
          savedIds.size() +
          ' override(s). Snapshot: ' +
          snapshot.Id,
        'Period: ' + request.periodId
      );
    } catch (Exception ex) {
      result.success = false;
      result.errors.add(ex.getMessage());
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  FREEZE (§11.4)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Freeze the entire scope: set all overrides to Frozen,
   *              update period status, create freeze snapshot, expire governance.
   */
  public static ForecastController.FreezeResult freezeScope(
    Id userId,
    Id periodId,
    String scopeId
  ) {
    ForecastController.FreezeResult result = new ForecastController.FreezeResult();
    result.success = true;
    result.errors = new List<String>();
    result.frozenCount = 0;
    result.expiredGovernanceCount = 0;

    try {
      // 1. Validate caller is top-level for this scope
      Forecast_Participant__c callerParticipant = ForecastDataService.getParticipant(
        userId,
        periodId,
        scopeId
      );

      if (callerParticipant == null) {
        result.success = false;
        result.errors.add('Caller is not a participant in this scope.');
        return result;
      }

      Integer maxLevel = getMaxHierarchyLevel(periodId);
      if (callerParticipant.Hierarchy_Level__c != maxLevel) {
        result.success = false;
        result.errors.add('Only top-level participants can freeze a scope.');
        return result;
      }

      // 2. Set all overrides in scope to Frozen
      List<Forecast_Participant__c> participantsInScope = ForecastDataService.getParticipantsInScope(
        scopeId,
        periodId
      );

      Set<Id> participantUserIds = new Set<Id>();
      for (Forecast_Participant__c fp : participantsInScope) {
        participantUserIds.add(fp.User__c);
      }

      List<Forecast_Override__c> overridesToFreeze = [
        SELECT Id, Status__c
        FROM Forecast_Override__c
        WHERE Forecast_Period__c = :periodId AND User__c IN :participantUserIds
      ];

      for (Forecast_Override__c ov : overridesToFreeze) {
        ov.Status__c = 'Frozen';
      }
      if (!overridesToFreeze.isEmpty()) {
        update overridesToFreeze;
      }
      result.frozenCount = overridesToFreeze.size();

      // 3. Update Forecast_Period__c Status = 'Frozen'
      //    (triggers PERIOD_FROZEN downstream — see §11.4)
      Forecast_Period__c period = new Forecast_Period__c();
      period.Id = periodId;
      period.Status__c = 'Frozen';
      period.Frozen_By__c = userId;
      period.Frozen_On__c = Datetime.now();
      update period;

      // 4. Create Freeze snapshot
      Forecast_Snapshot__c snapshot = new Forecast_Snapshot__c();
      snapshot.Forecast_Period__c = periodId;
      snapshot.Forecast_Participant__c = callerParticipant.Id;
      snapshot.Snapshot_Type__c = 'Freeze';
      snapshot.Snapshot_Date__c = Date.today();
      snapshot.Total_Records__c = overridesToFreeze.size();
      insert snapshot;

      // 5. Update all participants in scope to Frozen status
      for (Forecast_Participant__c fp : participantsInScope) {
        fp.Submission_Status__c = 'Frozen';
      }
      if (!participantsInScope.isEmpty()) {
        update participantsInScope;
      }

      // 6. Auto-expire pending governance approvals (§7.3.6)
      List<Governance_Event__c> pendingEvents = [
        SELECT Id, Status__c
        FROM Governance_Event__c
        WHERE Forecast_Period__c = :periodId AND Status__c = 'Pending'
      ];
      for (Governance_Event__c ge : pendingEvents) {
        ge.Status__c = 'Expired';
      }
      if (!pendingEvents.isEmpty()) {
        update pendingEvents;
      }
      result.expiredGovernanceCount = pendingEvents.size();

      // Audit log
      IncentiveChangeEventService.logEvent(
        'Forecast_Period',
        periodId,
        'FORECAST_FROZEN',
        null,
        'Frozen scope ' +
          scopeId +
          '. ' +
          result.frozenCount +
          ' overrides frozen.',
        'Frozen by: ' + userId
      );
    } catch (Exception ex) {
      result.success = false;
      result.errors.add(ex.getMessage());
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  COPY (§11.15)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Copy values from the previous hierarchy level's overrides.
   *              Respects copy mode: OVERWRITE, MERGE, SKIP_EDITED.
   *              Handles deal-share dedup at top level.
   */
  public static ForecastController.CopyResult copyFromPreviousLevel(
    Id periodId,
    Id participantId,
    String scopeId,
    String copyMode
  ) {
    ForecastController.CopyResult result = new ForecastController.CopyResult();
    result.success = true;
    result.errors = new List<String>();
    result.copiedCount = 0;
    result.skippedCount = 0;
    result.skippedEditedCount = 0;

    try {
      // Load participant
      Forecast_Participant__c participant = [
        SELECT Id, User__c, Hierarchy_Level__c
        FROM Forecast_Participant__c
        WHERE Id = :participantId
        LIMIT 1
      ];

      if (
        participant == null ||
        participant.Hierarchy_Level__c == null ||
        participant.Hierarchy_Level__c <= 1
      ) {
        result.success = false;
        result.errors.add('No previous level available for this participant.');
        return result;
      }

      Integer currentLevel = participant.Hierarchy_Level__c.intValue();
      Integer previousLevel = currentLevel - 1;

      // Query previous level overrides (Submitted status)
      List<Forecast_Override__c> prevLevelOverrides = [
        SELECT
          Id,
          Opportunity__c,
          Forecast_Category__c,
          Metric_1_Value__c,
          Metric_2_Value__c,
          Metric_3_Value__c,
          Metric_4_Value__c,
          Metric_5_Value__c,
          Metric_6_Value__c,
          Close_Date_Override__c,
          Comment__c
        FROM Forecast_Override__c
        WHERE
          Forecast_Period__c = :periodId
          AND Hierarchy_Level__c = :previousLevel
          AND Status__c IN ('Submitted', 'Frozen')
      ];

      if (prevLevelOverrides.isEmpty()) {
        result.skippedCount = 0;
        return result;
      }

      // Get existing overrides at current level
      Set<Id> prevRecordIds = new Set<Id>();
      for (Forecast_Override__c ov : prevLevelOverrides) {
        prevRecordIds.add(ov.Opportunity__c);
      }

      Map<Id, Forecast_Override__c> existingMap = ForecastDataService.getOverridesForRecords(
        prevRecordIds,
        periodId,
        participantId
      );

      // Apply copy mode
      List<Forecast_Override__c> toInsert = new List<Forecast_Override__c>();
      List<Forecast_Override__c> toUpdate = new List<Forecast_Override__c>();

      for (Forecast_Override__c prevOv : prevLevelOverrides) {
        Forecast_Override__c existingOv = existingMap.get(
          prevOv.Opportunity__c
        );

        if (existingOv != null) {
          // Override exists at current level
          if (copyMode == COPY_MODE_MERGE) {
            // MERGE: skip existing
            result.skippedCount++;
            continue;
          } else if (copyMode == COPY_MODE_SKIP_EDITED || copyMode == null) {
            // SKIP_EDITED (default): skip if status is Saved/Submitted/Frozen
            if (existingOv.Status__c != 'New') {
              result.skippedEditedCount++;
              continue;
            }
          }
          // OVERWRITE or SKIP_EDITED with New status: update
          existingOv.Forecast_Category__c = prevOv.Forecast_Category__c;
          existingOv.Metric_1_Value__c = prevOv.Metric_1_Value__c;
          existingOv.Metric_2_Value__c = prevOv.Metric_2_Value__c;
          existingOv.Metric_3_Value__c = prevOv.Metric_3_Value__c;
          existingOv.Metric_4_Value__c = prevOv.Metric_4_Value__c;
          existingOv.Metric_5_Value__c = prevOv.Metric_5_Value__c;
          existingOv.Metric_6_Value__c = prevOv.Metric_6_Value__c;
          existingOv.Close_Date_Override__c = prevOv.Close_Date_Override__c;
          existingOv.Status__c = 'Saved';
          existingOv.Saved_On__c = Datetime.now();
          existingOv.Previous_Level_Override__c = prevOv.Id;
          toUpdate.add(existingOv);
          result.copiedCount++;
        } else {
          // No override at current level — create new (lazy materialization)
          Forecast_Override__c newOv = new Forecast_Override__c();
          newOv.Opportunity__c = prevOv.Opportunity__c;
          newOv.Forecast_Period__c = periodId;
          newOv.User__c = participant.User__c;
          newOv.Forecast_Participant__c = participantId;
          newOv.Hierarchy_Level__c = currentLevel;
          newOv.Forecast_Category__c = prevOv.Forecast_Category__c;
          newOv.Metric_1_Value__c = prevOv.Metric_1_Value__c;
          newOv.Metric_2_Value__c = prevOv.Metric_2_Value__c;
          newOv.Metric_3_Value__c = prevOv.Metric_3_Value__c;
          newOv.Metric_4_Value__c = prevOv.Metric_4_Value__c;
          newOv.Metric_5_Value__c = prevOv.Metric_5_Value__c;
          newOv.Metric_6_Value__c = prevOv.Metric_6_Value__c;
          newOv.Close_Date_Override__c = prevOv.Close_Date_Override__c;
          newOv.Status__c = 'Saved';
          newOv.Saved_On__c = Datetime.now();
          newOv.Previous_Level_Override__c = prevOv.Id;
          newOv.Exchange_Rate__c = getExchangeRate(prevOv.Opportunity__c);
          computeLocalCurrencyValues(newOv);
          toInsert.add(newOv);
          result.copiedCount++;
        }
      }

      if (!toInsert.isEmpty()) {
        insert toInsert;
      }
      if (!toUpdate.isEmpty()) {
        update toUpdate;
      }
    } catch (Exception ex) {
      result.success = false;
      result.errors.add(ex.getMessage());
    }

    return result;
  }

  /**
   * @description Copy overrides from the previous forecast period.
   *              Respects copy mode: OVERWRITE, MERGE, SKIP_EDITED.
   */
  public static ForecastController.CopyResult copyFromLastForecast(
    Id periodId,
    Id participantId,
    String scopeId,
    String copyMode
  ) {
    ForecastController.CopyResult result = new ForecastController.CopyResult();
    result.success = true;
    result.errors = new List<String>();
    result.copiedCount = 0;
    result.skippedCount = 0;
    result.skippedEditedCount = 0;

    try {
      // Find previous period
      Forecast_Period__c previousPeriod = ForecastDataService.getPreviousPeriod(
        periodId
      );
      if (previousPeriod == null) {
        result.errors.add('No previous forecast period found.');
        return result;
      }

      // Load participant
      Forecast_Participant__c participant = [
        SELECT Id, User__c, Hierarchy_Level__c
        FROM Forecast_Participant__c
        WHERE Id = :participantId
        LIMIT 1
      ];

      if (participant == null) {
        result.success = false;
        result.errors.add('Participant not found.');
        return result;
      }

      // Query overrides from previous period for this user
      List<Forecast_Override__c> prevPeriodOverrides = [
        SELECT
          Id,
          Opportunity__c,
          Forecast_Category__c,
          Metric_1_Value__c,
          Metric_2_Value__c,
          Metric_3_Value__c,
          Metric_4_Value__c,
          Metric_5_Value__c,
          Metric_6_Value__c,
          Close_Date_Override__c,
          Comment__c
        FROM Forecast_Override__c
        WHERE
          Forecast_Period__c = :previousPeriod.Id
          AND User__c = :participant.User__c
      ];

      if (prevPeriodOverrides.isEmpty()) {
        return result;
      }

      // Get existing overrides in current period
      Set<Id> prevRecordIds = new Set<Id>();
      for (Forecast_Override__c ov : prevPeriodOverrides) {
        prevRecordIds.add(ov.Opportunity__c);
      }

      Map<Id, Forecast_Override__c> existingMap = ForecastDataService.getOverridesForRecords(
        prevRecordIds,
        periodId,
        participantId
      );

      Integer currentLevel = participant.Hierarchy_Level__c != null
        ? participant.Hierarchy_Level__c.intValue()
        : 1;

      List<Forecast_Override__c> toInsert = new List<Forecast_Override__c>();
      List<Forecast_Override__c> toUpdate = new List<Forecast_Override__c>();

      for (Forecast_Override__c prevOv : prevPeriodOverrides) {
        Forecast_Override__c existingOv = existingMap.get(
          prevOv.Opportunity__c
        );

        if (existingOv != null) {
          if (copyMode == COPY_MODE_MERGE) {
            result.skippedCount++;
            continue;
          } else if (copyMode == COPY_MODE_SKIP_EDITED || copyMode == null) {
            if (existingOv.Status__c != 'New') {
              result.skippedEditedCount++;
              continue;
            }
          }
          // OVERWRITE or New status
          existingOv.Forecast_Category__c = prevOv.Forecast_Category__c;
          existingOv.Metric_1_Value__c = prevOv.Metric_1_Value__c;
          existingOv.Metric_2_Value__c = prevOv.Metric_2_Value__c;
          existingOv.Metric_3_Value__c = prevOv.Metric_3_Value__c;
          existingOv.Metric_4_Value__c = prevOv.Metric_4_Value__c;
          existingOv.Metric_5_Value__c = prevOv.Metric_5_Value__c;
          existingOv.Metric_6_Value__c = prevOv.Metric_6_Value__c;
          existingOv.Close_Date_Override__c = prevOv.Close_Date_Override__c;
          existingOv.Status__c = 'Saved';
          existingOv.Saved_On__c = Datetime.now();
          existingOv.Previous_Period_Override__c = prevOv.Id;
          toUpdate.add(existingOv);
          result.copiedCount++;
        } else {
          // Create new
          Forecast_Override__c newOv = new Forecast_Override__c();
          newOv.Opportunity__c = prevOv.Opportunity__c;
          newOv.Forecast_Period__c = periodId;
          newOv.User__c = participant.User__c;
          newOv.Forecast_Participant__c = participantId;
          newOv.Hierarchy_Level__c = currentLevel;
          newOv.Forecast_Category__c = prevOv.Forecast_Category__c;
          newOv.Metric_1_Value__c = prevOv.Metric_1_Value__c;
          newOv.Metric_2_Value__c = prevOv.Metric_2_Value__c;
          newOv.Metric_3_Value__c = prevOv.Metric_3_Value__c;
          newOv.Metric_4_Value__c = prevOv.Metric_4_Value__c;
          newOv.Metric_5_Value__c = prevOv.Metric_5_Value__c;
          newOv.Metric_6_Value__c = prevOv.Metric_6_Value__c;
          newOv.Close_Date_Override__c = prevOv.Close_Date_Override__c;
          newOv.Status__c = 'Saved';
          newOv.Saved_On__c = Datetime.now();
          newOv.Previous_Period_Override__c = prevOv.Id;
          newOv.Exchange_Rate__c = getExchangeRate(prevOv.Opportunity__c);
          computeLocalCurrencyValues(newOv);
          toInsert.add(newOv);
          result.copiedCount++;
        }
      }

      if (!toInsert.isEmpty()) {
        insert toInsert;
      }
      if (!toUpdate.isEmpty()) {
        update toUpdate;
      }
    } catch (Exception ex) {
      result.success = false;
      result.errors.add(ex.getMessage());
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  COMMENTS
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Get forecast comments for a pipeline record and user.
   */
  public static List<ForecastController.ForecastCommentDTO> getComments(
    Id recordId,
    Id userId
  ) {
    List<ForecastController.ForecastCommentDTO> results = new List<ForecastController.ForecastCommentDTO>();

    List<Forecast_Comment__c> comments = [
      SELECT
        Id,
        Comment__c,
        Comment_Type__c,
        CreatedDate,
        CreatedBy.Name,
        Hierarchy_Level__c
      FROM Forecast_Comment__c
      WHERE Opportunity__c = :recordId
      ORDER BY CreatedDate DESC
      LIMIT 50
    ];

    for (Forecast_Comment__c fc : comments) {
      ForecastController.ForecastCommentDTO dto = new ForecastController.ForecastCommentDTO();
      dto.commentId = fc.Id;
      dto.comment = fc.Comment__c;
      dto.commentType = fc.Comment_Type__c;
      dto.commentDate = fc.CreatedDate;
      dto.author = fc.CreatedBy.Name;
      dto.level = fc.Hierarchy_Level__c != null
        ? fc.Hierarchy_Level__c.intValue()
        : null;
      results.add(dto);
    }

    return results;
  }

  /**
   * @description Save a forecast comment.
   * @return The new Forecast_Comment__c Id.
   */
  public static Id saveComment(
    Id overrideId,
    Id periodId,
    Id recordId,
    String comment,
    String commentType
  ) {
    Forecast_Comment__c fc = new Forecast_Comment__c();
    fc.Forecast_Override__c = overrideId;
    fc.Forecast_Period__c = periodId;
    fc.Opportunity__c = recordId;
    fc.Comment__c = comment;
    fc.Comment_Type__c = commentType;

    // Set hierarchy level from the current user's participant
    List<Forecast_Participant__c> participants = [
      SELECT Hierarchy_Level__c
      FROM Forecast_Participant__c
      WHERE User__c = :UserInfo.getUserId() AND Forecast_Period__c = :periodId
      LIMIT 1
    ];
    if (!participants.isEmpty() && participants[0].Hierarchy_Level__c != null) {
      fc.Hierarchy_Level__c = participants[0].Hierarchy_Level__c;
    }

    insert fc;
    return fc.Id;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SUMMARY
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Compute forecast summary: category totals, attainment, coverage,
   *              tier info from Commission_Tier__c if Incentives active.
   */
  public static ForecastController.ForecastSummaryDTO computeSummary(
    Id periodId,
    Id participantId,
    String scopeId
  ) {
    ForecastController.ForecastSummaryDTO summary = new ForecastController.ForecastSummaryDTO();
    summary.categoryTotals = new Map<String, Decimal>();
    summary.categoryCounts = new Map<String, Integer>();

    try {
      // Load participant
      Forecast_Participant__c participant = [
        SELECT Id, User__c, Hierarchy_Level__c
        FROM Forecast_Participant__c
        WHERE Id = :participantId
        LIMIT 1
      ];

      if (participant == null) {
        return summary;
      }

      // Aggregate overrides by category
      List<AggregateResult> aggs = [
        SELECT
          Forecast_Category__c cat,
          SUM(Metric_1_Value__c) sumM1,
          COUNT(Id) cnt
        FROM Forecast_Override__c
        WHERE Forecast_Period__c = :periodId AND User__c = :participant.User__c
        GROUP BY Forecast_Category__c
      ];

      Decimal totalPipeline = 0;
      for (AggregateResult ag : aggs) {
        String cat = (String) ag.get('cat');
        Decimal total = (Decimal) ag.get('sumM1');
        Integer count = (Integer) ag.get('cnt');
        if (cat != null) {
          summary.categoryTotals.put(cat, total != null ? total : 0);
          summary.categoryCounts.put(cat, count);
          totalPipeline += (total != null ? total : 0);
        }
      }

      // Load attainment from Quota__c
      AttainmentData attData = loadAttainmentData(
        participant.User__c,
        periodId
      );
      summary.target = attData.target;
      summary.achieved = attData.achieved;
      summary.attainmentPct = attData.attainmentPct;
      summary.remaining = attData.target - attData.achieved;

      // Coverage ratio = Pipeline / Remaining
      if (summary.remaining != null && summary.remaining > 0) {
        summary.coverageRatio = totalPipeline / summary.remaining;
      } else {
        summary.coverageRatio = 0;
      }

      // Tier info from Commission_Tier__c (if Incentives active)
      try {
        IncentiveImpactCalculator.IncentiveContext incentiveCtx = IncentiveImpactCalculator.getContext(
          participant.User__c
        );
        if (
          incentiveCtx != null &&
          incentiveCtx.tiers != null &&
          !incentiveCtx.tiers.isEmpty()
        ) {
          // Find current tier
          for (
            IncentiveImpactCalculator.TierDefinition tier : incentiveCtx.tiers
          ) {
            if (
              summary.attainmentPct >= tier.minAttainmentPct &&
              (tier.maxAttainmentPct == null ||
              summary.attainmentPct < tier.maxAttainmentPct)
            ) {
              summary.currentTier = tier.name;
              summary.currentRate = tier.ratePct;
              break;
            }
          }

          // Find next tier
          for (
            IncentiveImpactCalculator.TierDefinition tier : incentiveCtx.tiers
          ) {
            if (tier.minAttainmentPct > summary.attainmentPct) {
              summary.nextTierName = tier.name;
              Decimal distancePct =
                tier.minAttainmentPct - summary.attainmentPct;
              summary.nextTierDistance = summary.target > 0
                ? (distancePct / 100) * summary.target
                : 0;
              break;
            }
          }
        }
      } catch (Exception ex) {
        // Incentives module may not be active; continue without tier info
      }
    } catch (Exception ex) {
      // Return partial summary on error
    }

    return summary;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  EXCHANGE RATE REFRESH (§11.10)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Refresh exchange rates on non-submitted overrides.
   *              Called by ForecastSnapshotBatch.finish().
   *              Skips Submitted/Frozen overrides (rates frozen at submit per §12.6).
   */
  public static void refreshDraftExchangeRates() {
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    if (config == null || config.Corporate_Currency__c == null) {
      return;
    }

    List<Forecast_Override__c> draftOverrides = [
      SELECT
        Id,
        Opportunity__c,
        Exchange_Rate__c,
        Metric_1_Value__c,
        Metric_2_Value__c,
        Metric_1_Local__c,
        Metric_2_Local__c
      FROM Forecast_Override__c
      WHERE Status__c IN ('New', 'Saved')
    ];

    if (draftOverrides.isEmpty()) {
      return;
    }

    for (Forecast_Override__c ov : draftOverrides) {
      Decimal newRate = getExchangeRate(ov.Opportunity__c);
      if (newRate != null && newRate != ov.Exchange_Rate__c) {
        ov.Exchange_Rate__c = newRate;
        computeLocalCurrencyValues(ov);
      }
    }

    if (!draftOverrides.isEmpty()) {
      update draftOverrides;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  OPPORTUNITY RECORD PAGE (LWC V1.2)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Load a single ForecastRecordDTO for an Opportunity + current user + period.
   *              Used by the revtOpportunityForecast record page component.
   *              Returns null if the Opportunity is not in the user's forecast scope.
   */
  public static ForecastController.ForecastRecordDTO loadOpportunityForecast(
    Id opportunityId,
    Id periodId,
    Id userId
  ) {
    if (opportunityId == null || periodId == null || userId == null) {
      return null;
    }

    // Find participant for this user + period
    List<Forecast_Participant__c> participants = [
      SELECT Id, User__c, Hierarchy_Level__c, Scope_Id__c
      FROM Forecast_Participant__c
      WHERE
        User__c = :userId
        AND Forecast_Period__c = :periodId
        AND Is_Summary__c = FALSE
      LIMIT 1
    ];
    if (participants.isEmpty()) {
      return null;
    }
    Forecast_Participant__c participant = participants[0];
    Integer currentLevel = participant.Hierarchy_Level__c != null
      ? participant.Hierarchy_Level__c.intValue()
      : 1;

    // Query pipeline record
    SObject pipelineRecord;
    try {
      pipelineRecord = PipelineObjectService.queryRecord(opportunityId);
    } catch (Exception ex) {
      return null;
    }
    if (pipelineRecord == null) {
      return null;
    }

    // Query override for this Opportunity + user + period
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
        Opportunity__c = :opportunityId
        AND Forecast_Period__c = :periodId
        AND User__c = :userId
      LIMIT 1
    ];

    Forecast_Override__c ov = overrides.isEmpty() ? null : overrides[0];

    // Build DTO
    ForecastController.ForecastRecordDTO dto = new ForecastController.ForecastRecordDTO();
    dto.recordId = opportunityId;
    dto.recordName = String.valueOf(pipelineRecord.get('Name'));
    dto.stage = PipelineObjectService.getStage(pipelineRecord);
    dto.closeDate = PipelineObjectService.getCloseDate(pipelineRecord);
    dto.crmAmount = PipelineObjectService.getAmount(pipelineRecord);
    try {
      dto.ownerName = (String) pipelineRecord.getSObject('Owner')?.get('Name');
      dto.ownerId = PipelineObjectService.getOwnerId(pipelineRecord);
    } catch (Exception ex) {
      dto.ownerName = '';
    }

    // Closed stage detection
    Boolean isClosed = false;
    Boolean isWon = false;
    try {
      isClosed = (Boolean) pipelineRecord.get('IsClosed') == true;
      isWon = (Boolean) pipelineRecord.get('IsWon') == true;
    } catch (Exception ex) {
      /* ignore */
    }
    dto.isClosed = isClosed;
    dto.isWon = isWon;

    if (ov != null) {
      dto.overrideId = ov.Id;
      dto.category = ov.Forecast_Category__c;
      dto.metricValues = buildMetricValuesMap(ov);
      dto.metricValuesLocal = buildLocalMetricValuesMap(ov);
      dto.closeDateOverride = ov.Close_Date_Override__c;
      dto.status = ov.Status__c;
      dto.comment = ov.Comment__c;
      dto.hierarchyLevel = ov.Hierarchy_Level__c != null
        ? ov.Hierarchy_Level__c.intValue()
        : currentLevel;
      dto.pendingApproval = ov.Pending_Approval__c;
      dto.crmDivergence = ov.CRM_Divergence__c;
      dto.crmDivergenceDetails = ov.CRM_Divergence_Details__c;
      dto.lastModifiedDate = ov.LastModifiedDate;
      dto.dataVersion = computeDataVersion(ov.LastModifiedDate, pipelineRecord);
    } else {
      dto.status = 'New';
      dto.metricValues = new Map<String, Decimal>();
      dto.metricValuesLocal = new Map<String, Decimal>();
      dto.hierarchyLevel = currentLevel;
      dto.pendingApproval = false;
      dto.crmDivergence = false;
      dto.dataVersion = computeDataVersion(null, pipelineRecord);

      if (isWon) {
        dto.category = 'Closed_Won';
        dto.metricValues.put('metric_1', dto.crmAmount);
      } else if (isClosed) {
        dto.category = 'Lost';
        dto.metricValues.put('metric_1', 0);
      } else {
        dto.metricValues.put('metric_1', dto.crmAmount);
      }
    }

    // Health score
    Map<Id, Deal_Signal__c> healthMap = ForecastDataService.getHealthScores(
      new Set<Id>{ opportunityId }
    );
    Deal_Signal__c signal = healthMap.get(opportunityId);
    if (signal != null) {
      dto.healthScore = signal.Health_Score__c != null
        ? signal.Health_Score__c.intValue()
        : null;
      dto.healthBand = signal.Score_Band__c;
    }

    // Incentive estimate
    try {
      IncentiveImpactCalculator.ImpactResult impact = IncentiveImpactCalculator.calculateImpact(
        opportunityId,
        participant.User__c
      );
      if (impact != null) {
        dto.payoutEstimate = impact.payoutOnDeal;
        dto.incentiveRate = impact.projectedTier != null
          ? impact.projectedTier.ratePct
          : null;
        if (impact.proximities != null && !impact.proximities.isEmpty()) {
          dto.thresholdProximity = impact.proximities[0].distanceAmount;
        }
        dto.tierImpact = impact.tierImpactMessage;
      }
    } catch (Exception ex) {
      // Incentives module may not be active
    }

    // Trends (from Previous_Period_Override)
    dto.trends = new Map<String, Integer>();
    if (ov != null && ov.Previous_Period_Override__c != null) {
      List<Forecast_Override__c> prevPeriodOvs = [
        SELECT
          Metric_1_Value__c,
          Metric_2_Value__c,
          Metric_3_Value__c,
          Metric_4_Value__c,
          Metric_5_Value__c,
          Metric_6_Value__c
        FROM Forecast_Override__c
        WHERE Id = :ov.Previous_Period_Override__c
        LIMIT 1
      ];
      if (!prevPeriodOvs.isEmpty()) {
        Forecast_Override__c prev = prevPeriodOvs[0];
        dto.trends.put(
          'metric_1',
          computeTrend(ov.Metric_1_Value__c, prev.Metric_1_Value__c)
        );
        dto.trends.put(
          'metric_2',
          computeTrend(ov.Metric_2_Value__c, prev.Metric_2_Value__c)
        );
        dto.trends.put(
          'metric_3',
          computeTrend(ov.Metric_3_Value__c, prev.Metric_3_Value__c)
        );
        dto.trends.put(
          'metric_4',
          computeTrend(ov.Metric_4_Value__c, prev.Metric_4_Value__c)
        );
        dto.trends.put(
          'metric_5',
          computeTrend(ov.Metric_5_Value__c, prev.Metric_5_Value__c)
        );
        dto.trends.put(
          'metric_6',
          computeTrend(ov.Metric_6_Value__c, prev.Metric_6_Value__c)
        );
      }
    }

    dto.governanceFlags = new List<String>();
    return dto;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  ACCEPT CRM VALUES (LWC V1.2)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Accept CRM divergence on an override. Preserves the override record
   *              for audit history. Clears overridden metric/date fields, refreshes
   *              values from CRM, resets divergence flags.
   */
  public static ForecastController.SaveResult acceptCrmValues(Id overrideId) {
    ForecastController.SaveResult result = new ForecastController.SaveResult();
    result.success = true;
    result.errors = new List<String>();
    result.updatedOverrideIds = new List<Id>();

    try {
      Forecast_Override__c ov = [
        SELECT Id, Opportunity__c, Forecast_Period__c, Status__c
        FROM Forecast_Override__c
        WHERE Id = :overrideId
        LIMIT 1
      ];

      // Validate period is editable
      Forecast_Period__c period = queryPeriod(ov.Forecast_Period__c);
      if (
        period != null && !EDITABLE_PERIOD_STATUSES.contains(period.Status__c)
      ) {
        result.success = false;
        result.errors.add(
          'Period is ' + period.Status__c + ' and cannot be edited.'
        );
        return result;
      }

      // Refresh from CRM
      SObject crmRecord = PipelineObjectService.queryRecord(ov.Opportunity__c);
      Decimal crmAmount = crmRecord != null
        ? PipelineObjectService.getAmount(crmRecord)
        : null;
      Date crmCloseDate = crmRecord != null
        ? PipelineObjectService.getCloseDate(crmRecord)
        : null;

      ov.Metric_1_Value__c = crmAmount;
      ov.Metric_2_Value__c = null;
      ov.Metric_3_Value__c = null;
      ov.Metric_4_Value__c = null;
      ov.Metric_5_Value__c = null;
      ov.Metric_6_Value__c = null;
      ov.Close_Date_Override__c = crmCloseDate;
      ov.CRM_Divergence__c = false;
      ov.CRM_Divergence_Details__c = null;
      ov.Saved_On__c = Datetime.now();

      // Recompute local currency
      ov.Exchange_Rate__c = getExchangeRate(ov.Opportunity__c);
      computeLocalCurrencyValues(ov);

      update ov;
      result.updatedOverrideIds.add(ov.Id);
    } catch (Exception ex) {
      result.success = false;
      result.errors.add(ex.getMessage());
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  EXPORT (LWC V1.2)
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Server-side CSV generation for large forecast datasets (>500 records).
   *              Returns ExportResult { fileName, mimeType, csvContent }.
   */
  public static ForecastController.ExportResult exportForecastData(
    Id periodId,
    Id participantId,
    String scopeId
  ) {
    ForecastController.ExportResult result = new ForecastController.ExportResult();
    result.mimeType = 'text/csv';

    // Load config for metric labels
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    List<String> metricLabels = new List<String>();
    if (config != null && config.Forecast_Metrics__r != null) {
      for (Forecast_Metric__c m : config.Forecast_Metrics__r) {
        metricLabels.add(
          m.Metric_Label__c != null ? m.Metric_Label__c : m.Name
        );
      }
    }

    // Build header
    List<String> headers = new List<String>{
      'Deal Name',
      'Owner',
      'Stage',
      'Close Date',
      'CRM Amount',
      'Category',
      'Status',
      'Override Close Date'
    };
    for (String label : metricLabels) {
      headers.add(label);
    }
    headers.addAll(
      new List<String>{ 'Health Score', 'Health Band', 'Comment' }
    );

    // Load all records (no pagination)
    ForecastController.ForecastQueryRequest request = new ForecastController.ForecastQueryRequest();
    request.periodId = periodId;
    request.participantId = participantId;
    request.scopeId = scopeId;
    request.pageSize = 10000;
    request.pageNumber = 1;

    ForecastController.ForecastRecordSet recordSet = queryForecastRecords(
      request
    );

    // Build CSV rows
    List<String> csvLines = new List<String>();
    csvLines.add(String.join(headers, ','));

    for (ForecastController.ForecastRecordDTO rec : recordSet.records) {
      List<String> cells = new List<String>();
      cells.add(escapeCsv(rec.recordName));
      cells.add(escapeCsv(rec.ownerName));
      cells.add(escapeCsv(rec.stage));
      cells.add(rec.closeDate != null ? String.valueOf(rec.closeDate) : '');
      cells.add(rec.crmAmount != null ? String.valueOf(rec.crmAmount) : '');
      cells.add(escapeCsv(rec.category));
      cells.add(escapeCsv(rec.status));
      cells.add(
        rec.closeDateOverride != null
          ? String.valueOf(rec.closeDateOverride)
          : ''
      );

      // Dynamic metric values
      for (Integer i = 1; i <= metricLabels.size(); i++) {
        String key = 'metric_' + i;
        Decimal val = rec.metricValues != null
          ? rec.metricValues.get(key)
          : null;
        cells.add(val != null ? String.valueOf(val) : '');
      }

      cells.add(rec.healthScore != null ? String.valueOf(rec.healthScore) : '');
      cells.add(escapeCsv(rec.healthBand));
      cells.add(escapeCsv(rec.comment));

      csvLines.add(String.join(cells, ','));
    }

    result.csvContent = String.join(csvLines, '\n');

    // Generate filename
    Forecast_Period__c period = queryPeriod(periodId);
    String periodLabel = period != null ? period.Name : 'forecast';
    result.fileName =
      'RevenueTrust_Forecast_' +
      periodLabel.replaceAll(' ', '_') +
      '_' +
      Date.today().format() +
      '.csv';

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Compute a composite data version hash from override + pipeline record.
   *              Used for conflict detection. Incorporates all timestamps that affect
   *              the assembled row state.
   */
  private static String computeDataVersion(
    Datetime overrideLastModified,
    SObject pipelineRecord
  ) {
    String versionInput = '';
    if (overrideLastModified != null) {
      versionInput += String.valueOf(overrideLastModified.getTime());
    }
    if (pipelineRecord != null) {
      try {
        Datetime pipelineModified = (Datetime) pipelineRecord.get(
          'LastModifiedDate'
        );
        if (pipelineModified != null) {
          versionInput += '_' + String.valueOf(pipelineModified.getTime());
        }
      } catch (Exception ex) {
        // Field not available
      }
    }
    if (String.isBlank(versionInput)) {
      return '0';
    }
    return EncodingUtil.convertToHex(
        Crypto.generateDigest('MD5', Blob.valueOf(versionInput))
      )
      .substring(0, 16);
  }

  /**
   * @description Escape a string for CSV output (handle commas, quotes, newlines).
   */
  private static String escapeCsv(String value) {
    if (String.isBlank(value)) {
      return '';
    }
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"' + value.replace('"', '""') + '"';
    }
    return value;
  }

  /**
   * @description Map a Forecast_Period__c record to a ForecastPeriodDTO.
   */
  private static ForecastController.ForecastPeriodDTO mapPeriodDTO(
    Forecast_Period__c p
  ) {
    ForecastController.ForecastPeriodDTO dto = new ForecastController.ForecastPeriodDTO();
    dto.periodId = p.Id;
    dto.label = p.Name;
    dto.periodType = p.Period_Type__c;
    dto.startDate = p.Start_Date__c;
    dto.endDate = p.End_Date__c;
    dto.status = p.Status__c;
    dto.isBudgetMode = p.Budget_Mode__c;
    return dto;
  }

  /**
   * @description Query a Forecast_Period__c by Id.
   */
  private static Forecast_Period__c queryPeriod(Id periodId) {
    List<Forecast_Period__c> periods = [
      SELECT
        Id,
        Name,
        Start_Date__c,
        End_Date__c,
        Status__c,
        Period_Type__c,
        Budget_Mode__c
      FROM Forecast_Period__c
      WHERE Id = :periodId
      LIMIT 1
    ];
    return periods.isEmpty() ? null : periods[0];
  }

  /**
   * @description Get the maximum hierarchy level for a period.
   */
  private static Integer getMaxHierarchyLevel(Id periodId) {
    AggregateResult[] aggs = [
      SELECT MAX(Hierarchy_Level__c) maxLevel
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId
    ];
    if (!aggs.isEmpty() && aggs[0].get('maxLevel') != null) {
      return ((Decimal) aggs[0].get('maxLevel')).intValue();
    }
    return 1;
  }

  /**
   * @description Check if a target participant is in the scope chain of a caller.
   *              Walks the Reports_To chain from target upward.
   */
  private static Boolean isInScopeChain(
    Id targetParticipantId,
    Id callerUserId,
    Id periodId
  ) {
    // Walk up the Reports_To chain from target
    Set<Id> visited = new Set<Id>();
    Id currentId = targetParticipantId;

    // Load all participants for this period for efficient traversal
    Map<Id, Forecast_Participant__c> allParticipants = new Map<Id, Forecast_Participant__c>(
      [
        SELECT Id, User__c, Reports_To__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId
      ]
    );

    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      Forecast_Participant__c current = allParticipants.get(currentId);
      if (current == null) {
        break;
      }
      if (current.Reports_To__c != null) {
        Forecast_Participant__c manager = allParticipants.get(
          current.Reports_To__c
        );
        if (manager != null && manager.User__c == callerUserId) {
          return true;
        }
        currentId = current.Reports_To__c;
      } else {
        break;
      }
    }
    return false;
  }

  /**
   * @description Load attainment data for a user from Quota__c.
   */
  private static ForecastController.AttainmentDTO loadAttainment(
    Id userId,
    Id periodId
  ) {
    ForecastController.AttainmentDTO att = new ForecastController.AttainmentDTO();
    AttainmentData data = loadAttainmentData(userId, periodId);
    att.target = data.target;
    att.achieved = data.achieved;
    att.attainmentPct = data.attainmentPct;
    return att;
  }

  /**
   * @description Internal attainment data container.
   */
  private class AttainmentData {
    Decimal target = 0;
    Decimal achieved = 0;
    Decimal attainmentPct = 0;
  }

  /**
   * @description Query Quota__c for attainment data.
   */
  private static AttainmentData loadAttainmentData(Id userId, Id periodId) {
    AttainmentData data = new AttainmentData();

    // Check config for attainment source
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    String source = config != null &&
      config.Attainment_Source__c != null
      ? config.Attainment_Source__c
      : 'Quota_Record';

    Boolean useQuota = (source == 'Quota_Record' || source == 'Hybrid');
    Boolean useLive = (source == 'Live_From_Forecast' || source == 'Hybrid');

    // Source 1: Quota record (from Incentives module)
    if (useQuota) {
      List<Comp_Plan__c> plans = [
        SELECT Id
        FROM Comp_Plan__c
        WHERE Sales_Rep__c = :userId AND Status__c = 'Active'
        LIMIT 1
      ];

      if (!plans.isEmpty()) {
        List<Quota__c> quotas = [
          SELECT Id, Target_Amount__c, Achieved_Amount__c
          FROM Quota__c
          WHERE Comp_Plan__c = :plans[0].Id AND Status__c = 'Active'
          LIMIT 1
        ];

        if (!quotas.isEmpty()) {
          Quota__c q = quotas[0];
          data.target = q.Target_Amount__c != null ? q.Target_Amount__c : 0;
          data.achieved = q.Achieved_Amount__c != null
            ? q.Achieved_Amount__c
            : 0;
        }
      }
    }

    // Source 2: Live from Closed Won overrides in this period
    if (useLive && (data.achieved == 0 || source == 'Live_From_Forecast')) {
      AggregateResult[] aggs = [
        SELECT SUM(Metric_1_Value__c) closedTotal
        FROM Forecast_Override__c
        WHERE
          Forecast_Period__c = :periodId
          AND User__c = :userId
          AND Forecast_Category__c = 'Closed_Won'
      ];
      if (!aggs.isEmpty() && aggs[0].get('closedTotal') != null) {
        Decimal liveAchieved = (Decimal) aggs[0].get('closedTotal');
        if (source == 'Live_From_Forecast') {
          data.achieved = liveAchieved;
        } else {
          // Hybrid: use live if quota achieved is 0
          data.achieved = liveAchieved;
        }
      }
    }

    // Compute attainment %
    data.attainmentPct = data.target > 0
      ? (data.achieved / data.target) * 100
      : 0;

    return data;
  }

  /**
   * @description Compute trend indicator: -1 (down), 0 (flat), +1 (up).
   */
  private static Integer computeTrend(Decimal current, Decimal previous) {
    if (current == null || previous == null) {
      return 0;
    }
    if (current > previous) {
      return 1;
    } else if (current < previous) {
      return -1;
    }
    return 0;
  }

  /**
   * @description Load available scopes for a user across periods.
   */
  private static List<ForecastController.ScopeDTO> loadAvailableScopes(
    Id userId,
    Id periodId
  ) {
    List<ForecastController.ScopeDTO> scopes = new List<ForecastController.ScopeDTO>();

    List<Forecast_Participant__c> participants = [
      SELECT Id, Scope_Id__c, Scope_Name__c
      FROM Forecast_Participant__c
      WHERE User__c = :userId AND Forecast_Period__c = :periodId
    ];

    for (Forecast_Participant__c p : participants) {
      ForecastController.ScopeDTO s = new ForecastController.ScopeDTO();
      s.scopeId = p.Scope_Id__c;
      s.scopeName = p.Scope_Name__c;
      scopes.add(s);
    }

    return scopes;
  }

  /**
   * @description Build metric values map from an override record.
   */
  private static Map<String, Decimal> buildMetricValuesMap(
    Forecast_Override__c ov
  ) {
    Map<String, Decimal> values = new Map<String, Decimal>();
    values.put('metric_1', ov.Metric_1_Value__c);
    values.put('metric_2', ov.Metric_2_Value__c);
    values.put('metric_3', ov.Metric_3_Value__c);
    values.put('metric_4', ov.Metric_4_Value__c);
    values.put('metric_5', ov.Metric_5_Value__c);
    values.put('metric_6', ov.Metric_6_Value__c);
    return values;
  }

  /**
   * @description Build local currency metric values map from an override record.
   */
  private static Map<String, Decimal> buildLocalMetricValuesMap(
    Forecast_Override__c ov
  ) {
    Map<String, Decimal> values = new Map<String, Decimal>();
    values.put('metric_1', ov.Metric_1_Local__c);
    values.put('metric_2', ov.Metric_2_Local__c);
    return values;
  }

  /**
   * @description Set metric values on an override from the DTO map.
   */
  private static void setMetricValues(
    Forecast_Override__c ov,
    Map<String, Decimal> values
  ) {
    if (values == null) {
      return;
    }
    if (values.containsKey('metric_1')) {
      ov.Metric_1_Value__c = values.get('metric_1');
    }
    if (values.containsKey('metric_2')) {
      ov.Metric_2_Value__c = values.get('metric_2');
    }
    if (values.containsKey('metric_3')) {
      ov.Metric_3_Value__c = values.get('metric_3');
    }
    if (values.containsKey('metric_4')) {
      ov.Metric_4_Value__c = values.get('metric_4');
    }
    if (values.containsKey('metric_5')) {
      ov.Metric_5_Value__c = values.get('metric_5');
    }
    if (values.containsKey('metric_6')) {
      ov.Metric_6_Value__c = values.get('metric_6');
    }
  }

  /**
   * @description Get exchange rate for a pipeline record.
   *              Uses CurrencyType or defaults to 1.0 for single-currency orgs.
   */
  private static Decimal getExchangeRate(Id recordId) {
    // Default to 1.0 (no conversion)
    if (recordId == null) {
      return 1.0;
    }

    try {
      // Query the pipeline record's currency
      SObject rec = PipelineObjectService.queryRecord(recordId);
      if (rec == null) {
        return 1.0;
      }

      // If multi-currency is enabled, get the record's CurrencyIsoCode
      String currencyCode;
      try {
        currencyCode = (String) rec.get('CurrencyIsoCode');
      } catch (Exception ex) {
        // Single-currency org
        return 1.0;
      }

      if (String.isBlank(currencyCode)) {
        return 1.0;
      }

      // Dynamic SOQL — CurrencyType only available in multi-currency orgs
      String q =
        'SELECT ConversionRate FROM CurrencyType WHERE IsoCode = \'' +
        String.escapeSingleQuotes(currencyCode) +
        '\' AND IsActive = true LIMIT 1';
      List<SObject> rates = Database.query(q);
      if (!rates.isEmpty()) {
        return (Decimal) rates[0].get('ConversionRate');
      }
    } catch (Exception ex) {
      // Fall through to default
    }

    return 1.0;
  }

  /**
   * @description Compute local currency values from corporate values and exchange rate.
   */
  private static void computeLocalCurrencyValues(Forecast_Override__c ov) {
    Decimal rate = ov.Exchange_Rate__c != null ? ov.Exchange_Rate__c : 1.0;
    if (rate == 0) {
      rate = 1.0;
    }
    ov.Metric_1_Local__c = ov.Metric_1_Value__c != null
      ? ov.Metric_1_Value__c * rate
      : null;
    ov.Metric_2_Local__c = ov.Metric_2_Value__c != null
      ? ov.Metric_2_Value__c * rate
      : null;
  }

  /**
   * @description Apply filters from ForecastQueryRequest to records.
   */
  private static List<ForecastController.ForecastRecordDTO> applyFilters(
    List<ForecastController.ForecastRecordDTO> records,
    ForecastController.ForecastQueryRequest request
  ) {
    List<ForecastController.ForecastRecordDTO> filtered = new List<ForecastController.ForecastRecordDTO>();

    for (ForecastController.ForecastRecordDTO rec : records) {
      // Search text filter
      if (String.isNotBlank(request.searchText)) {
        String searchLower = request.searchText.toLowerCase();
        Boolean matches = false;
        if (
          rec.recordName != null &&
          rec.recordName.toLowerCase().contains(searchLower)
        ) {
          matches = true;
        }
        if (
          rec.ownerName != null &&
          rec.ownerName.toLowerCase().contains(searchLower)
        ) {
          matches = true;
        }
        if (!matches) {
          continue;
        }
      }

      // Category filter
      if (request.categoryFilter != null && !request.categoryFilter.isEmpty()) {
        if (
          rec.category == null || !request.categoryFilter.contains(rec.category)
        ) {
          continue;
        }
      }

      // Stage filter
      if (request.stageFilter != null && !request.stageFilter.isEmpty()) {
        if (rec.stage == null || !request.stageFilter.contains(rec.stage)) {
          continue;
        }
      }

      // Health band filter
      if (
        request.healthBandFilter != null && !request.healthBandFilter.isEmpty()
      ) {
        if (
          rec.healthBand == null ||
          !request.healthBandFilter.contains(rec.healthBand)
        ) {
          continue;
        }
      }

      // Pending approval only
      if (request.pendingApprovalOnly == true && rec.pendingApproval != true) {
        continue;
      }

      // Overridden only
      if (request.overriddenOnly == true && rec.overrideId == null) {
        continue;
      }

      // Divergent only
      if (request.divergentOnly == true && rec.crmDivergence != true) {
        continue;
      }

      filtered.add(rec);
    }

    return filtered;
  }

  /**
   * @description Sort records by the specified field and direction.
   */
  private static List<ForecastController.ForecastRecordDTO> applySort(
    List<ForecastController.ForecastRecordDTO> records,
    String sortField,
    String sortDirection
  ) {
    if (String.isBlank(sortField) || records.isEmpty()) {
      return records;
    }

    // Use a wrapper for sorting
    List<SortableRecord> sortable = new List<SortableRecord>();
    for (ForecastController.ForecastRecordDTO rec : records) {
      sortable.add(new SortableRecord(rec, sortField, sortDirection));
    }
    sortable.sort();

    List<ForecastController.ForecastRecordDTO> sorted = new List<ForecastController.ForecastRecordDTO>();
    for (SortableRecord sr : sortable) {
      sorted.add(sr.record);
    }
    return sorted;
  }

  /**
   * @description Sortable wrapper for ForecastRecordDTO.
   */
  private class SortableRecord implements Comparable {
    public ForecastController.ForecastRecordDTO record;
    public String sortField;
    public Boolean isAsc;

    public SortableRecord(
      ForecastController.ForecastRecordDTO rec,
      String field,
      String direction
    ) {
      this.record = rec;
      this.sortField = field;
      this.isAsc = (direction == null || direction.equalsIgnoreCase('ASC'));
    }

    public Integer compareTo(Object compareTo) {
      SortableRecord other = (SortableRecord) compareTo;
      Integer result = 0;

      if (sortField == 'metricValue' || sortField == 'metric_1') {
        Decimal val1 = getSortMetric(this.record);
        Decimal val2 = getSortMetric(other.record);
        result = compareDecimals(val1, val2);
      } else if (sortField == 'category') {
        result = compareStrings(this.record.category, other.record.category);
      } else if (sortField == 'closeDate') {
        result = compareDates(this.record.closeDate, other.record.closeDate);
      } else if (sortField == 'ownerName') {
        result = compareStrings(this.record.ownerName, other.record.ownerName);
      } else if (sortField == 'healthScore') {
        result = compareIntegers(
          this.record.healthScore,
          other.record.healthScore
        );
      } else if (sortField == 'recordName') {
        result = compareStrings(
          this.record.recordName,
          other.record.recordName
        );
      }

      return isAsc ? result : -result;
    }

    private Decimal getSortMetric(ForecastController.ForecastRecordDTO rec) {
      if (
        rec.metricValues != null && rec.metricValues.containsKey('metric_1')
      ) {
        return rec.metricValues.get('metric_1');
      }
      return rec.crmAmount;
    }

    private Integer compareDecimals(Decimal a, Decimal b) {
      if (a == null && b == null)
        return 0;
      if (a == null)
        return -1;
      if (b == null)
        return 1;
      return a > b ? 1 : (a < b ? -1 : 0);
    }

    private Integer compareStrings(String a, String b) {
      if (a == null && b == null)
        return 0;
      if (a == null)
        return -1;
      if (b == null)
        return 1;
      return a.compareTo(b);
    }

    private Integer compareDates(Date a, Date b) {
      if (a == null && b == null)
        return 0;
      if (a == null)
        return -1;
      if (b == null)
        return 1;
      return a > b ? 1 : (a < b ? -1 : 0);
    }

    private Integer compareIntegers(Integer a, Integer b) {
      if (a == null && b == null)
        return 0;
      if (a == null)
        return -1;
      if (b == null)
        return 1;
      return a > b ? 1 : (a < b ? -1 : 0);
    }
  }

  /**
   * @description Compute summary from a list of ForecastRecordDTOs.
   */
  private static ForecastController.ForecastSummaryDTO computeSummaryFromRecords(
    List<ForecastController.ForecastRecordDTO> records,
    Id participantId,
    Id periodId
  ) {
    ForecastController.ForecastSummaryDTO summary = new ForecastController.ForecastSummaryDTO();
    summary.categoryTotals = new Map<String, Decimal>();
    summary.categoryCounts = new Map<String, Integer>();

    for (ForecastController.ForecastRecordDTO rec : records) {
      String cat = rec.category != null ? rec.category : 'Uncategorized';
      Decimal metricVal = 0;
      if (
        rec.metricValues != null && rec.metricValues.containsKey('metric_1')
      ) {
        metricVal = rec.metricValues.get('metric_1') != null
          ? rec.metricValues.get('metric_1')
          : 0;
      } else if (rec.crmAmount != null) {
        metricVal = rec.crmAmount;
      }

      if (summary.categoryTotals.containsKey(cat)) {
        summary.categoryTotals.put(
          cat,
          summary.categoryTotals.get(cat) + metricVal
        );
        summary.categoryCounts.put(cat, summary.categoryCounts.get(cat) + 1);
      } else {
        summary.categoryTotals.put(cat, metricVal);
        summary.categoryCounts.put(cat, 1);
      }
    }

    // Load attainment
    try {
      Forecast_Participant__c participant = [
        SELECT User__c
        FROM Forecast_Participant__c
        WHERE Id = :participantId
        LIMIT 1
      ];
      if (participant != null) {
        AttainmentData attData = loadAttainmentData(
          participant.User__c,
          periodId
        );
        summary.target = attData.target;
        summary.achieved = attData.achieved;
        summary.attainmentPct = attData.attainmentPct;
        summary.remaining = attData.target - attData.achieved;

        Decimal totalPipeline = 0;
        for (Decimal v : summary.categoryTotals.values()) {
          totalPipeline += (v != null ? v : 0);
        }
        if (summary.remaining != null && summary.remaining > 0) {
          summary.coverageRatio = totalPipeline / summary.remaining;
        }
      }
    } catch (Exception ex) {
      // Continue with partial summary
    }

    return summary;
  }

  /**
   * @description Compute deal-share deduplication factors for pipeline records
   *              that appear in multiple scopes (§11.5).
   *              At the top hierarchy level, identifies duplicates and returns
   *              a factor (0-1) per record. Records not duplicated are not in the map.
   * @param recordIds Set of pipeline record IDs in the current scope
   * @param periodId The forecast period
   * @return Map of record Id to dedup factor (e.g., 0.5 for equal 2-way split)
   */
  private static Map<Id, Decimal> computeDedupFactors(
    Set<Id> recordIds,
    Id periodId
  ) {
    Map<Id, Decimal> factors = new Map<Id, Decimal>();
    if (recordIds == null || recordIds.isEmpty()) {
      return factors;
    }

    // Count how many scopes each pipeline record appears in (via overrides)
    Map<Id, Integer> scopeCounts = new Map<Id, Integer>();
    Map<Id, Decimal> contributionPcts = new Map<Id, Decimal>();

    // Count distinct SCOPES (not participants) — hierarchy levels within the
    // same scope are NOT duplicates, only multi-territory deals are.
    for (AggregateResult ag : [
      SELECT
        Opportunity__c oppId,
        COUNT_DISTINCT(Forecast_Participant__r.Scope_Id__c) scopeCount
      FROM Forecast_Override__c
      WHERE Opportunity__c IN :recordIds AND Forecast_Period__c = :periodId
      GROUP BY Opportunity__c
      HAVING COUNT_DISTINCT(Forecast_Participant__r.Scope_Id__c) > 1
    ]) {
      Id oppId = (Id) ag.get('oppId');
      Integer count = (Integer) ag.get('scopeCount');
      scopeCounts.put(oppId, count);
    }

    // For each duplicate, try to get deal contribution % from Field_Mapping
    // If not mapped, default to equal split
    for (Id recId : scopeCounts.keySet()) {
      try {
        SObject rec = PipelineObjectService.queryRecord(recId);
        Decimal pct = (Decimal) PipelineObjectService.getFieldValue(
          rec,
          'Pipeline.DealContributionPct'
        );
        if (pct != null && pct > 0 && pct <= 100) {
          factors.put(recId, pct / 100);
        } else {
          // Default: equal split
          factors.put(recId, 1.0 / scopeCounts.get(recId));
        }
      } catch (Exception ex) {
        // Field not mapped — default to equal split
        factors.put(recId, 1.0 / scopeCounts.get(recId));
      }
    }

    return factors;
  }
}
