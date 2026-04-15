/**
 * @description Thin @AuraEnabled controller for the Forecasting module.
 *              All business logic delegates to ForecastService.
 *              DTOs defined as inner classes with @AuraEnabled fields.
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md V1.1
 *              Sections: §11.1, §11.2, §11.7, §11.8, §11.11, §11.15
 */
public with sharing class ForecastController {
  // ══════════════════════════════════════════════════════════════════════
  //  §11.1 — Split init: cacheable config
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled(cacheable=true)
  public static ForecastConfigDTO getForecastConfig() {
    return ForecastService.loadConfig();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.1 — Split init: imperative mutable context
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static ForecastParticipantContextDTO getParticipantContext(
    Id periodId,
    String scopeId
  ) {
    return ForecastService.loadParticipantContext(
      UserInfo.getUserId(),
      periodId,
      scopeId
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.1 — Manager drill-in with security check
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static ForecastParticipantContextDTO getParticipantContextForUser(
    Id participantId,
    Id periodId,
    String scopeId
  ) {
    ForecastService.validateAccess(UserInfo.getUserId(), participantId);
    return ForecastService.loadParticipantContext(
      participantId,
      periodId,
      scopeId
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.2 — Paginated records with filters
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static ForecastRecordSet getForecastRecords(
    Id periodId,
    Id participantId,
    String scopeId,
    Integer pageNumber,
    Integer pageSize,
    String searchText,
    String sortField,
    String sortDirection,
    List<String> categoryFilter,
    List<String> stageFilter,
    List<String> healthBandFilter,
    Boolean pendingApprovalOnly,
    Boolean overriddenOnly,
    Boolean divergentOnly
  ) {
    try {
      ForecastQueryRequest request = new ForecastQueryRequest();
      request.periodId = periodId;
      request.participantId = participantId;
      request.scopeId = scopeId;
      request.pageNumber = pageNumber;
      request.pageSize = pageSize;
      request.searchText = searchText;
      request.sortField = sortField;
      request.sortDirection = sortDirection;
      request.categoryFilter = categoryFilter;
      request.stageFilter = stageFilter;
      request.healthBandFilter = healthBandFilter;
      request.pendingApprovalOnly = pendingApprovalOnly;
      request.overriddenOnly = overriddenOnly;
      request.divergentOnly = divergentOnly;
      return ForecastService.queryForecastRecords(request);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.3/§11.11 — Save
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static SaveResult saveForecastData(
    String overridesJson,
    Id periodId,
    Id participantId,
    Boolean isPartial
  ) {
    try {
      SaveForecastRequest request = new SaveForecastRequest();
      request.overrides = (List<ForecastOverrideSaveDTO>) JSON.deserialize(
        overridesJson,
        List<ForecastOverrideSaveDTO>.class
      );
      request.periodId = periodId;
      request.participantId = participantId;
      request.isPartial = isPartial;
      return ForecastService.saveOverrides(request);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.7/§11.11 — Submit
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static SubmitResult submitForecastData(
    String overridesJson,
    Id periodId,
    Id participantId,
    Boolean isPartial,
    Boolean validateCompleteness,
    Boolean freezeExchangeRates
  ) {
    try {
      SubmitForecastRequest request = new SubmitForecastRequest();
      request.overrides = String.isNotBlank(overridesJson)
        ? (List<ForecastOverrideSaveDTO>) JSON.deserialize(
            overridesJson,
            List<ForecastOverrideSaveDTO>.class
          )
        : new List<ForecastOverrideSaveDTO>();
      request.periodId = periodId;
      request.participantId = participantId;
      request.isPartial = isPartial;
      request.validateCompleteness = validateCompleteness;
      request.freezeExchangeRates = freezeExchangeRates;
      return ForecastService.submitOverrides(request);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.4 — Freeze
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static FreezeResult freezeForecastData(Id periodId, String scopeId) {
    return ForecastService.freezeScope(UserInfo.getUserId(), periodId, scopeId);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.15 — Copy from previous level
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static CopyResult copyFromPreviousLevel(
    Id periodId,
    Id participantId,
    String scopeId,
    String copyMode
  ) {
    return ForecastService.copyFromPreviousLevel(
      periodId,
      participantId,
      scopeId,
      copyMode
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  §11.15 — Copy from last forecast
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static CopyResult copyFromLastForecast(
    Id periodId,
    Id participantId,
    String scopeId,
    String copyMode
  ) {
    return ForecastService.copyFromLastForecast(
      periodId,
      participantId,
      scopeId,
      copyMode
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Comments
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled(cacheable=true)
  public static List<ForecastCommentDTO> getLastForecastComment(
    Id recordId,
    Id userId
  ) {
    return ForecastService.getComments(recordId, userId);
  }

  @AuraEnabled
  public static Id saveForecastComment(
    Id overrideId,
    Id periodId,
    Id recordId,
    String comment,
    String commentType
  ) {
    return ForecastService.saveComment(
      overrideId,
      periodId,
      recordId,
      comment,
      commentType
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Summary
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled(cacheable=true)
  public static ForecastSummaryDTO getForecastSummary(
    Id periodId,
    Id participantId,
    String scopeId
  ) {
    return ForecastService.computeSummary(periodId, participantId, scopeId);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  LWC V1.2 — Opportunity Record Page + Divergence + Export
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Single-record forecast load for Opportunity FlexiPage component.
   *              Returns the ForecastRecordDTO for this Opportunity + current user + period,
   *              or null if the Opportunity is not in the user's forecast scope.
   */
  @AuraEnabled
  public static ForecastRecordDTO getOpportunityForecast(
    Id opportunityId,
    Id periodId
  ) {
    return ForecastService.loadOpportunityForecast(
      opportunityId,
      periodId,
      UserInfo.getUserId()
    );
  }

  /**
   * @description Accept CRM divergence: preserves the override record for audit history,
   *              clears overridden metric/date fields, refreshes values from CRM pipeline
   *              record, resets CRM_Divergence__c and CRM_Divergence_Details__c.
   */
  @AuraEnabled
  public static SaveResult acceptCrmValues(Id overrideId) {
    return ForecastService.acceptCrmValues(overrideId);
  }

  /**
   * @description Server-side CSV export for large datasets (>500 records).
   *              Returns ExportResult with fileName, mimeType, and csvContent.
   */
  @AuraEnabled
  public static ExportResult exportForecastData(
    Id periodId,
    Id participantId,
    String scopeId
  ) {
    return ForecastService.exportForecastData(periodId, participantId, scopeId);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Drill-in: find subordinate's participant by owner userId
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Find a subordinate's participant record by their User Id.
   *              Used for manager drill-in: click owner name → load their forecast.
   *              Returns the participant Id, or null if not found.
   */
  @AuraEnabled
  public static Id getParticipantIdForUser(Id userId, Id periodId) {
    List<Forecast_Participant__c> participants = [
      SELECT Id
      FROM Forecast_Participant__c
      WHERE
        User__c = :userId
        AND Forecast_Period__c = :periodId
        AND Is_Summary__c = FALSE
      LIMIT 1
    ];
    return participants.isEmpty() ? null : participants[0].Id;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  DTOs — §7 and §11
  // ══════════════════════════════════════════════════════════════════════

  /**
   * @description Stable configuration DTO (cacheable).
   *              Metrics, categories, hierarchy labels, period type, currency,
   *              layout, pagination, lock label/type.
   */
  public class ForecastConfigDTO {
    @AuraEnabled
    public List<ForecastMetricDTO> metrics;
    @AuraEnabled
    public List<ForecastCategoryDTO> categories;
    @AuraEnabled
    public List<ForecastPeriodDTO> periods;
    @AuraEnabled
    public ForecastPeriodDTO currentPeriod;
    @AuraEnabled
    public String periodType;
    @AuraEnabled
    public String currencyMode;
    @AuraEnabled
    public String corporateCurrency;
    @AuraEnabled
    public String attainmentLayout;
    @AuraEnabled
    public String topLevelActionType;
    @AuraEnabled
    public String topLevelActionLabel;
    @AuraEnabled
    public Integer paginationSize;
    @AuraEnabled
    public String hierarchySource;
  }

  /**
   * @description Mutable participant state (imperative, not cached).
   *              Participant record, permissions, attainment, status,
   *              delegation, current period state, budget mode.
   */
  public class ForecastParticipantContextDTO {
    @AuraEnabled
    public ForecastParticipantDTO participant;
    @AuraEnabled
    public AttainmentDTO attainment;
    @AuraEnabled
    public List<ScopeDTO> availableScopes;
    @AuraEnabled
    public Integer hierarchyLevel;
    @AuraEnabled
    public String levelLabel;
    @AuraEnabled
    public Boolean canSubmit;
    @AuraEnabled
    public Boolean canFreeze;
    @AuraEnabled
    public Boolean canEdit;
    @AuraEnabled
    public Boolean isBudgetMode;
    @AuraEnabled
    public String submissionStatus;
    @AuraEnabled
    public Boolean isDelegatedAccess;
  }

  /**
   * @description Metric definition from Forecast_Metric__c.
   */
  public class ForecastMetricDTO {
    @AuraEnabled
    public Id metricId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String metricType;
    @AuraEnabled
    public String format;
    @AuraEnabled
    public Boolean isPrimary;
    @AuraEnabled
    public Boolean isRequired;
    @AuraEnabled
    public Boolean isEditable;
    @AuraEnabled
    public Integer sortOrder;
    @AuraEnabled
    public String fieldApiName;
  }

  /**
   * @description Category definition from Forecast_Category__c.
   */
  public class ForecastCategoryDTO {
    @AuraEnabled
    public Id categoryId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String apiName;
    @AuraEnabled
    public String color;
    @AuraEnabled
    public Boolean countsTowardTarget;
    @AuraEnabled
    public Boolean isTerminal;
    @AuraEnabled
    public Boolean isHighConfidence;
    @AuraEnabled
    public Boolean isRegression;
    @AuraEnabled
    public Integer sortOrder;
    @AuraEnabled
    public Boolean isActive;
  }

  /**
   * @description Forecast period info from Forecast_Period__c.
   */
  public class ForecastPeriodDTO {
    @AuraEnabled
    public Id periodId;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String periodType;
    @AuraEnabled
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Boolean isBudgetMode;
  }

  /**
   * @description Participant info from Forecast_Participant__c.
   */
  public class ForecastParticipantDTO {
    @AuraEnabled
    public Id participantId;
    @AuraEnabled
    public Id userId;
    @AuraEnabled
    public Integer level;
    @AuraEnabled
    public String levelLabel;
    @AuraEnabled
    public String scopeId;
    @AuraEnabled
    public String scopeName;
    @AuraEnabled
    public String status;
  }

  /**
   * @description Single pipeline record with override data merged.
   */
  public class ForecastRecordDTO {
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String recordName;
    @AuraEnabled
    public String ownerName;
    @AuraEnabled
    public String stage;
    @AuraEnabled
    public Date closeDate;
    @AuraEnabled
    public Decimal crmAmount;
    @AuraEnabled
    public Id overrideId;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public Map<String, Decimal> metricValues;
    @AuraEnabled
    public Map<String, Decimal> metricValuesLocal;
    @AuraEnabled
    public Date closeDateOverride;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String comment;
    @AuraEnabled
    public Integer hierarchyLevel;
    @AuraEnabled
    public Map<String, Decimal> previousLevelValues;
    @AuraEnabled
    public Map<String, Integer> trends;
    @AuraEnabled
    public Integer healthScore;
    @AuraEnabled
    public String healthBand;
    @AuraEnabled
    public List<String> governanceFlags;
    @AuraEnabled
    public Boolean pendingApproval;
    @AuraEnabled
    public Boolean crmDivergence;
    @AuraEnabled
    public String crmDivergenceDetails;
    @AuraEnabled
    public Decimal incentiveRate;
    @AuraEnabled
    public Decimal payoutEstimate;
    @AuraEnabled
    public Decimal thresholdProximity;
    @AuraEnabled
    public String tierImpact;
    @AuraEnabled
    public Map<String, Decimal> metricValuesPreDedup;
    @AuraEnabled
    public String dataVersion;
    @AuraEnabled
    public Datetime lastModifiedDate;
    @AuraEnabled
    public Id ownerId;
    @AuraEnabled
    public Boolean isClosed;
    @AuraEnabled
    public Boolean isWon;
    @AuraEnabled
    public String prevLevelCategory;
    @AuraEnabled
    public String prevLevelUserName;
    @AuraEnabled
    public Integer prevLevel;
  }

  /**
   * @description Paginated record set with summary.
   */
  public class ForecastRecordSet {
    @AuraEnabled
    public List<ForecastRecordDTO> records;
    @AuraEnabled
    public Integer totalCount;
    @AuraEnabled
    public Integer totalUnfilteredCount;
    @AuraEnabled
    public Integer pageNumber;
    @AuraEnabled
    public Integer pageSize;
    @AuraEnabled
    public ForecastSummaryDTO summary;
  }

  /**
   * @description Save payload for a single override record.
   */
  public class ForecastOverrideSaveDTO {
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public Id overrideId;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public Map<String, Decimal> metricValues;
    @AuraEnabled
    public Date closeDateOverride;
    @AuraEnabled
    public String comment;
    @AuraEnabled
    public Boolean forceOverwrite;
    @AuraEnabled
    public String dataVersion;
  }

  /**
   * @description Query request DTO with filters, sort, pagination (§11.2).
   */
  public class ForecastQueryRequest {
    @AuraEnabled
    public Id periodId;
    @AuraEnabled
    public Id participantId;
    @AuraEnabled
    public String scopeId;
    @AuraEnabled
    public Integer pageNumber;
    @AuraEnabled
    public Integer pageSize;
    @AuraEnabled
    public String searchText;
    @AuraEnabled
    public List<String> categoryFilter;
    @AuraEnabled
    public List<String> stageFilter;
    @AuraEnabled
    public List<String> healthBandFilter;
    @AuraEnabled
    public Boolean pendingApprovalOnly;
    @AuraEnabled
    public Boolean overriddenOnly;
    @AuraEnabled
    public Boolean divergentOnly;
    @AuraEnabled
    public String sortField;
    @AuraEnabled
    public String sortDirection;
  }

  /**
   * @description Save request DTO (§11.11).
   */
  public class SaveForecastRequest {
    @AuraEnabled
    public List<ForecastOverrideSaveDTO> overrides;
    @AuraEnabled
    public Id periodId;
    @AuraEnabled
    public Id participantId;
    @AuraEnabled
    public Boolean isPartial;
  }

  /**
   * @description Submit request DTO with submit-specific flags (§11.11).
   */
  public class SubmitForecastRequest {
    @AuraEnabled
    public List<ForecastOverrideSaveDTO> overrides;
    @AuraEnabled
    public Id periodId;
    @AuraEnabled
    public Id participantId;
    @AuraEnabled
    public Boolean isPartial;
    @AuraEnabled
    public Boolean validateCompleteness;
    @AuraEnabled
    public Boolean freezeExchangeRates;
  }

  /**
   * @description Summary panel data — category totals, attainment, coverage, tier info.
   */
  public class ForecastSummaryDTO {
    @AuraEnabled
    public Decimal target;
    @AuraEnabled
    public Decimal achieved;
    @AuraEnabled
    public Decimal remaining;
    @AuraEnabled
    public Decimal attainmentPct;
    @AuraEnabled
    public Map<String, Decimal> categoryTotals;
    @AuraEnabled
    public Map<String, Integer> categoryCounts;
    @AuraEnabled
    public Decimal coverageRatio;
    @AuraEnabled
    public String currentTier;
    @AuraEnabled
    public Decimal currentRate;
    @AuraEnabled
    public String nextTierName;
    @AuraEnabled
    public Decimal nextTierDistance;
    @AuraEnabled
    public Decimal aiPredicted;
    @AuraEnabled
    public Decimal managerAccuracy;
  }

  /**
   * @description Comment thread entry.
   */
  public class ForecastCommentDTO {
    @AuraEnabled
    public Id commentId;
    @AuraEnabled
    public String author;
    @AuraEnabled
    public Integer level;
    @AuraEnabled
    public Datetime commentDate;
    @AuraEnabled
    public String comment;
    @AuraEnabled
    public String commentType;
  }

  /**
   * @description Incentive attainment data.
   */
  public class AttainmentDTO {
    @AuraEnabled
    public Decimal target;
    @AuraEnabled
    public Decimal achieved;
    @AuraEnabled
    public Decimal attainmentPct;
    @AuraEnabled
    public String currentTier;
    @AuraEnabled
    public Decimal currentRate;
    @AuraEnabled
    public String nextTierName;
    @AuraEnabled
    public Decimal nextTierDistance;
  }

  /**
   * @description Territory/scope option for multi-scope users.
   */
  public class ScopeDTO {
    @AuraEnabled
    public String scopeId;
    @AuraEnabled
    public String scopeName;
    @AuraEnabled
    public String region;
    @AuraEnabled
    public String parentScope;
  }

  /**
   * @description Save response with per-record results.
   */
  public class SaveResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public List<String> errors;
    @AuraEnabled
    public List<Id> updatedOverrideIds;
  }

  /**
   * @description Submit response with snapshot reference.
   */
  public class SubmitResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public List<String> errors;
    @AuraEnabled
    public Id snapshotId;
    @AuraEnabled
    public Integer notificationsSent;
  }

  /**
   * @description Freeze response with counts.
   */
  public class FreezeResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public List<String> errors;
    @AuraEnabled
    public Integer frozenCount;
    @AuraEnabled
    public Integer expiredGovernanceCount;
  }

  /**
   * @description Copy response with copied/skipped counts.
   */
  public class CopyResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public List<String> errors;
    @AuraEnabled
    public Integer copiedCount;
    @AuraEnabled
    public Integer skippedCount;
    @AuraEnabled
    public Integer skippedEditedCount;
  }

  /**
   * @description Server-side CSV export response.
   */
  public class ExportResult {
    @AuraEnabled
    public String fileName;
    @AuraEnabled
    public String mimeType;
    @AuraEnabled
    public String csvContent;
  }
}
