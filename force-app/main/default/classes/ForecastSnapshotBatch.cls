/**
 * @description Scheduled batch job that creates periodic Forecast_Snapshot__c
 *              records for trend tracking. Runs nightly by default, with automatic
 *              hourly mode activation during the final N days of a period (per
 *              spec section 11.9).
 *
 *              For each active participant + open period:
 *              - Aggregates Forecast_Override__c by category
 *              - Computes totals, coverage ratio, attainment
 *              - Creates Forecast_Snapshot__c with type = Nightly/Weekly/Hourly
 *
 *              Schedule example:
 *              System.schedule('Forecast Snapshot - Nightly',
 *                  '0 0 2 * * ?', new ForecastSnapshotBatch());
 *              System.schedule('Forecast Snapshot - Hourly',
 *                  '0 0 0/4 * * ?', new ForecastSnapshotBatch('Hourly'));
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 6.3, section 11.9
 */
public class ForecastSnapshotBatch implements Database.Batchable<SObject>, Schedulable {
  private String snapshotType = 'Nightly';

  /**
   * @description Default constructor: Nightly snapshot type.
   */
  public ForecastSnapshotBatch() {
  }

  /**
   * @description Constructor with explicit snapshot type.
   * @param type The snapshot type: Nightly, Weekly, Hourly, Submit, Freeze
   */
  public ForecastSnapshotBatch(String type) {
    this.snapshotType = type;
  }

  /**
   * @description Schedulable entry point: execute the batch.
   * @param sc The SchedulableContext
   */
  public void execute(SchedulableContext sc) {
    Database.executeBatch(this, 50);
  }

  /**
   * @description Query active Forecast_Participant__c records for open periods.
   * @param bc The BatchableContext
   * @return QueryLocator for active participants in open periods
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          User__c,
          Scope_Id__c,
          Hierarchy_Level__c,
          Forecast_Period__c,
          Forecast_Period__r.Start_Date__c,
          Forecast_Period__r.End_Date__c,
          Is_Summary__c,
          Submission_Status__c
        FROM Forecast_Participant__c
        WHERE
          Forecast_Period__r.Status__c IN ('Open', 'Prelock')
          AND Is_Summary__c = FALSE
      ]
    );
  }

  /**
   * @description For each participant, aggregate overrides by category and
   *              create a Forecast_Snapshot__c record.
   * @param bc The BatchableContext
   * @param participants Batch of Forecast_Participant__c records
   */
  public void execute(
    Database.BatchableContext bc,
    List<Forecast_Participant__c> participants
  ) {
    if (participants.isEmpty()) {
      return;
    }

    // Collect participant IDs and period IDs
    Set<Id> participantIds = new Set<Id>();
    Set<Id> periodIds = new Set<Id>();
    for (Forecast_Participant__c p : participants) {
      participantIds.add(p.Id);
      if (p.Forecast_Period__c != null) {
        periodIds.add(p.Forecast_Period__c);
      }
    }

    // Query all overrides for these participants
    Map<Id, List<Forecast_Override__c>> participantOverrides = new Map<Id, List<Forecast_Override__c>>();

    for (Forecast_Override__c ov : [
      SELECT
        Id,
        Forecast_Participant__c,
        Forecast_Category__c,
        Status__c,
        Metric_1_Value__c,
        Metric_2_Value__c,
        Metric_3_Value__c,
        Metric_4_Value__c,
        Metric_5_Value__c,
        Metric_6_Value__c,
        Forecast_Period__c
      FROM Forecast_Override__c
      WHERE Forecast_Participant__c IN :participantIds
    ]) {
      if (!participantOverrides.containsKey(ov.Forecast_Participant__c)) {
        participantOverrides.put(
          ov.Forecast_Participant__c,
          new List<Forecast_Override__c>()
        );
      }
      participantOverrides.get(ov.Forecast_Participant__c).add(ov);
    }

    // Load quota data for attainment (if available)
    Map<Id, Decimal> participantTargets = new Map<Id, Decimal>();
    Map<Id, Decimal> participantAchieved = new Map<Id, Decimal>();
    // Quota integration point -- load from Quota__c if Incentives module is active
    // For now, targets and achieved are optional

    // Query previous snapshots of the same type for delta computation (§6.3)
    Map<Id, Forecast_Snapshot__c> previousSnapshotMap = new Map<Id, Forecast_Snapshot__c>();
    for (Forecast_Snapshot__c prevSnap : [
      SELECT
        Id,
        Forecast_Participant__c,
        Pipeline_Total__c,
        Commit_Total__c,
        Coverage_Ratio__c
      FROM Forecast_Snapshot__c
      WHERE
        Forecast_Participant__c IN :participantIds
        AND Snapshot_Type__c = :snapshotType
        AND Snapshot_Date__c < :Date.today()
      ORDER BY Snapshot_Date__c DESC
    ]) {
      // Keep only the most recent per participant
      if (!previousSnapshotMap.containsKey(prevSnap.Forecast_Participant__c)) {
        previousSnapshotMap.put(prevSnap.Forecast_Participant__c, prevSnap);
      }
    }

    // Create snapshots
    List<Forecast_Snapshot__c> snapshots = new List<Forecast_Snapshot__c>();

    for (Forecast_Participant__c p : participants) {
      List<Forecast_Override__c> overrides = participantOverrides.get(p.Id);
      if (overrides == null || overrides.isEmpty()) {
        continue;
      }

      // Aggregate by category
      Map<String, Decimal> categoryTotals = new Map<String, Decimal>();
      Map<String, Integer> categoryCounts = new Map<String, Integer>();
      Decimal totalPipeline = 0;
      Integer totalRecords = 0;

      for (Forecast_Override__c ov : overrides) {
        String category = ov.Forecast_Category__c != null
          ? ov.Forecast_Category__c
          : 'Uncategorized';
        Decimal amount = ov.Metric_1_Value__c != null
          ? ov.Metric_1_Value__c
          : 0;

        if (!categoryTotals.containsKey(category)) {
          categoryTotals.put(category, 0);
          categoryCounts.put(category, 0);
        }
        categoryTotals.put(category, categoryTotals.get(category) + amount);
        categoryCounts.put(category, categoryCounts.get(category) + 1);

        totalPipeline += amount;
        totalRecords++;
      }

      // Compute coverage ratio
      Decimal target = participantTargets.get(p.Id);
      Decimal achieved = participantAchieved.get(p.Id);
      Decimal remaining = (target != null &&
        achieved != null)
        ? target - achieved
        : null;
      Decimal coverageRatio = (remaining != null &&
        remaining > 0)
        ? totalPipeline / remaining
        : null;
      Decimal attainmentPct = (target != null &&
        target > 0 &&
        achieved != null)
        ? (achieved / target * 100).setScale(2)
        : null;

      Forecast_Snapshot__c snapshot = new Forecast_Snapshot__c();
      snapshot.Forecast_Participant__c = p.Id;
      snapshot.Forecast_Period__c = p.Forecast_Period__c;
      snapshot.Snapshot_Type__c = snapshotType;
      snapshot.Snapshot_Date__c = Date.today();
      snapshot.Pipeline_Total__c = totalPipeline;
      snapshot.Total_Records__c = totalRecords;
      // Store commit category total (highest confidence) as currency
      Decimal commitTotal = categoryTotals.containsKey('Commit')
        ? categoryTotals.get('Commit')
        : 0;
      snapshot.Commit_Total__c = commitTotal;
      snapshot.Commit_Count__c = categoryCounts.containsKey('Commit')
        ? categoryCounts.get('Commit')
        : 0;
      // Store full category breakdown as JSON in long text field
      snapshot.Category_Slot_Map__c = JSON.serialize(categoryTotals);
      snapshot.Coverage_Ratio__c = coverageRatio;
      snapshot.Attainment_At_Snapshot__c = attainmentPct;
      snapshot.Target_At_Snapshot__c = target;
      snapshot.Achieved_At_Snapshot__c = achieved;

      // Compute deltas vs. previous snapshot of same type (§6.3)
      Forecast_Snapshot__c prevSnap = previousSnapshotMap.get(p.Id);
      if (prevSnap != null) {
        snapshot.Pipeline_Delta__c =
          totalPipeline -
          (prevSnap.Pipeline_Total__c != null ? prevSnap.Pipeline_Total__c : 0);
        snapshot.Commit_Delta__c =
          commitTotal -
          (prevSnap.Commit_Total__c != null ? prevSnap.Commit_Total__c : 0);
        snapshot.Coverage_Delta__c =
          (coverageRatio != null ? coverageRatio : 0) -
          (prevSnap.Coverage_Ratio__c != null ? prevSnap.Coverage_Ratio__c : 0);
      }

      snapshots.add(snapshot);
    }

    if (!snapshots.isEmpty()) {
      insert snapshots;
      System.debug(
        'ForecastSnapshotBatch: Created ' +
          snapshots.size() +
          ' snapshot(s) of type ' +
          snapshotType
      );
    }
  }

  /**
   * @description Post-processing: refresh draft exchange rates and check
   *              if hourly snapshot mode should be activated.
   * @param bc The BatchableContext
   */
  public void finish(Database.BatchableContext bc) {
    // Refresh draft exchange rates (per spec section 11.10)
    if (snapshotType == 'Nightly') {
      try {
        ForecastService.refreshDraftExchangeRates();
      } catch (Exception e) {
        System.debug(
          LoggingLevel.WARN,
          'ForecastSnapshotBatch: Exchange rate refresh failed: ' +
          e.getMessage()
        );
      }
    }

    // Check if hourly mode should be activated (per spec section 11.9)
    if (snapshotType == 'Nightly') {
      checkHourlyModeActivation();
    }
  }

  /**
   * @description Check if any open periods are within the hourly snapshot window.
   *              If so, schedule the hourly snapshot job (self-terminating when
   *              period freezes or days remaining > threshold).
   */
  private void checkHourlyModeActivation() {
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    if (config == null || config.Hourly_Snapshot_Days__c == null) {
      return;
    }

    Integer hourlyDays = config.Hourly_Snapshot_Days__c.intValue();
    Integer hourlyInterval = config.Hourly_Snapshot_Interval__c != null
      ? config.Hourly_Snapshot_Interval__c.intValue()
      : 4;

    // Check if any open period is within the hourly window
    List<Forecast_Period__c> openPeriods = [
      SELECT Id, End_Date__c
      FROM Forecast_Period__c
      WHERE Status__c = 'Open' AND End_Date__c != NULL
    ];

    Boolean needsHourly = false;
    for (Forecast_Period__c p : openPeriods) {
      Integer daysToEnd = Date.today().daysBetween(p.End_Date__c);
      if (daysToEnd <= hourlyDays && daysToEnd >= 0) {
        needsHourly = true;
        break;
      }
    }

    if (needsHourly) {
      // Check if hourly job is already scheduled
      List<CronTrigger> existingJobs = [
        SELECT Id
        FROM CronTrigger
        WHERE
          CronJobDetail.Name = 'ForecastSnapshotBatch_Hourly'
          AND State != 'DELETED'
        LIMIT 1
      ];

      if (existingJobs.isEmpty()) {
        // Schedule hourly job: every N hours during business hours
        String cronExpr = '0 0 0/' + hourlyInterval + ' * * ?';
        try {
          System.schedule(
            'ForecastSnapshotBatch_Hourly',
            cronExpr,
            new ForecastSnapshotBatch('Hourly')
          );
          System.debug(
            'ForecastSnapshotBatch: Activated hourly mode with interval ' +
              hourlyInterval +
              ' hours.'
          );
        } catch (Exception e) {
          System.debug(
            LoggingLevel.WARN,
            'ForecastSnapshotBatch: Could not schedule hourly job: ' +
            e.getMessage()
          );
        }
      }
    }
  }
}
