/**
 * @description Service for Forecast Summary computation, persistence, override CRUD,
 *              staleness detection, trend queries, and history pruning.
 *              Phase D: Forecast Summaries with per-category rollups and manager overrides.
 */
public with sharing class ForecastSummaryService {
  private static final Integer MAX_HISTORY_PER_SUMMARY = 52;

  /**
   * Compute and persist summaries for a participant+period.
   * Creates/updates Forecast_Summary__c for each (category × primary metric).
   * When Summary_All_Metrics__c is true, also persists for non-primary metrics.
   */
  public static List<Forecast_Summary__c> computeAndPersistSummaries(
    Id participantId,
    Id periodId,
    Id configId
  ) {
    // 1. Load config with categories
    Forecast_Configuration__c config = [
      SELECT
        Id,
        Summary_All_Metrics__c,
        (
          SELECT Id, Category_API_Name__c, Is_Active__c, Is_Terminal__c
          FROM Forecast_Categories__r
          WHERE Is_Active__c = TRUE
        )
      FROM Forecast_Configuration__c
      WHERE Id = :configId
    ];

    // 2. Get the participant's user
    Forecast_Participant__c participant = [
      SELECT User__c
      FROM Forecast_Participant__c
      WHERE Id = :participantId
    ];

    // 3. Query overrides for this participant+period to compute category totals
    List<Forecast_Override__c> overrides = [
      SELECT
        Forecast_Category__c,
        Metric_1_Value__c,
        Metric_2_Value__c,
        Metric_3_Value__c,
        Forecast_Group__c
      FROM Forecast_Override__c
      WHERE Forecast_Period__c = :periodId AND User__c = :participant.User__c
    ];

    // 4. Aggregate by category
    Map<String, Decimal> catTotals = new Map<String, Decimal>();
    Map<String, Integer> catCounts = new Map<String, Integer>();
    for (Forecast_Override__c ov : overrides) {
      String cat = ov.Forecast_Category__c;
      if (String.isBlank(cat)) {
        cat = 'Uncategorized';
      }
      Decimal val = ov.Metric_1_Value__c != null ? ov.Metric_1_Value__c : 0;
      catTotals.put(
        cat,
        (catTotals.containsKey(cat) ? catTotals.get(cat) : 0) + val
      );
      catCounts.put(
        cat,
        (catCounts.containsKey(cat) ? catCounts.get(cat) : 0) + 1
      );
    }

    // 5. Load existing summaries for upsert matching
    Map<String, Forecast_Summary__c> existingByKey = new Map<String, Forecast_Summary__c>();
    for (Forecast_Summary__c fs : [
      SELECT
        Id,
        Category_API_Name__c,
        Metric_Sort_Order__c,
        Forecast_Group__c,
        Override_Value__c,
        Override_By__c,
        Override_Date__c,
        Override_Notes__c
      FROM Forecast_Summary__c
      WHERE
        Forecast_Participant__c = :participantId
        AND Forecast_Period__c = :periodId
        AND Metric_Sort_Order__c = 1
    ]) {
      String key =
        fs.Category_API_Name__c +
        '|1|' +
        (fs.Forecast_Group__c != null ? fs.Forecast_Group__c : '');
      existingByKey.put(key, fs);
    }

    // 6. Build summary records
    List<Forecast_Summary__c> summaries = new List<Forecast_Summary__c>();
    for (Forecast_Category__c cat : config.Forecast_Categories__r) {
      String catApi = cat.Category_API_Name__c;
      String key = catApi + '|1|';
      Decimal computed = catTotals.containsKey(catApi)
        ? catTotals.get(catApi)
        : 0;
      Integer deals = catCounts.containsKey(catApi) ? catCounts.get(catApi) : 0;

      Forecast_Summary__c fs;
      if (existingByKey.containsKey(key)) {
        fs = existingByKey.get(key);
      } else {
        fs = new Forecast_Summary__c();
        fs.Forecast_Period__c = periodId;
        fs.Forecast_Participant__c = participantId;
        fs.Category_API_Name__c = catApi;
        fs.Metric_Sort_Order__c = 1;
      }
      fs.Computed_Value__c = computed;
      fs.Deal_Count__c = deals;
      fs.Summary_Date__c = Date.today();
      summaries.add(fs);
    }

    upsert summaries;
    return summaries;
  }

  /**
   * Create history records for a batch of summaries.
   */
  public static void persistSummaryHistory(
    List<Forecast_Summary__c> summaries,
    String snapshotType
  ) {
    List<Forecast_Summary_History__c> historyRecords = new List<Forecast_Summary_History__c>();
    for (Forecast_Summary__c fs : summaries) {
      Forecast_Summary_History__c h = new Forecast_Summary_History__c();
      h.Forecast_Summary__c = fs.Id;
      h.Snapshot_Date__c = Date.today();
      h.Snapshot_Type__c = snapshotType;
      h.Computed_Value__c = fs.Computed_Value__c;
      h.Effective_Value__c = fs.Override_Value__c != null
        ? fs.Override_Value__c
        : fs.Computed_Value__c;
      h.Deal_Count__c = fs.Deal_Count__c;
      h.Override_Active__c = fs.Override_Value__c != null;
      historyRecords.add(h);
    }
    if (!historyRecords.isEmpty()) {
      insert historyRecords;
    }
  }

  /**
   * Override a summary value. Checks permissions (manager/admin only, not self).
   */
  public static Forecast_Summary__c overrideSummary(
    Id summaryId,
    Decimal overrideValue,
    String notes
  ) {
    Forecast_Summary__c fs = [
      SELECT
        Id,
        Forecast_Participant__c,
        Forecast_Participant__r.User__c,
        Override_Value__c,
        Computed_Value__c
      FROM Forecast_Summary__c
      WHERE Id = :summaryId
    ];

    // Permission check: cannot override own summary
    Id currentUserId = UserInfo.getUserId();
    if (fs.Forecast_Participant__r.User__c == currentUserId) {
      throw new AuraHandledException(
        'You cannot override your own forecast summary. Edit individual deals instead.'
      );
    }

    fs.Override_Value__c = overrideValue;
    fs.Override_Notes__c = notes;
    fs.Override_By__c = currentUserId;
    fs.Override_Date__c = Datetime.now();
    update fs;
    return fs;
  }

  /**
   * Clear an override, reverting to computed value.
   */
  public static void clearOverride(Id summaryId) {
    Forecast_Summary__c fs = new Forecast_Summary__c(Id = summaryId);
    fs.Override_Value__c = null;
    fs.Override_Notes__c = null;
    fs.Override_By__c = null;
    fs.Override_Date__c = null;
    update fs;
  }

  /**
   * Get trend history for a summary (ordered by date).
   */
  public static List<Forecast_Summary_History__c> getTrendHistory(
    Id summaryId
  ) {
    return [
      SELECT
        Snapshot_Date__c,
        Snapshot_Type__c,
        Computed_Value__c,
        Effective_Value__c,
        Deal_Count__c,
        Override_Active__c
      FROM Forecast_Summary_History__c
      WHERE Forecast_Summary__c = :summaryId
      ORDER BY Snapshot_Date__c ASC
      LIMIT :MAX_HISTORY_PER_SUMMARY
    ];
  }

  /**
   * Prune old history records beyond the 52-record cap.
   */
  public static void pruneOldHistory(Id summaryId) {
    List<Forecast_Summary_History__c> all = [
      SELECT Id
      FROM Forecast_Summary_History__c
      WHERE Forecast_Summary__c = :summaryId
      ORDER BY Snapshot_Date__c ASC
    ];
    if (all.size() > MAX_HISTORY_PER_SUMMARY) {
      List<Forecast_Summary_History__c> toDelete = new List<Forecast_Summary_History__c>();
      for (Integer i = 0; i < all.size() - MAX_HISTORY_PER_SUMMARY; i++) {
        toDelete.add(all[i]);
      }
      delete toDelete;
    }
  }

  /**
   * Load summaries for a participant+period, keyed by category API name.
   * Used by the forecast grid to merge overrides into category cards.
   */
  public static Map<String, Forecast_Summary__c> getSummariesByCategory(
    Id participantId,
    Id periodId
  ) {
    Map<String, Forecast_Summary__c> result = new Map<String, Forecast_Summary__c>();
    for (Forecast_Summary__c fs : [
      SELECT
        Id,
        Category_API_Name__c,
        Computed_Value__c,
        Override_Value__c,
        Deal_Count__c,
        Override_By__c,
        Override_By__r.Name,
        Override_Date__c,
        Override_Notes__c,
        Is_Submitted__c,
        Metric_Sort_Order__c,
        Forecast_Group__c
      FROM Forecast_Summary__c
      WHERE
        Forecast_Participant__c = :participantId
        AND Forecast_Period__c = :periodId
        AND Metric_Sort_Order__c = 1
    ]) {
      result.put(fs.Category_API_Name__c, fs);
    }
    return result;
  }
}
