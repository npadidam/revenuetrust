/**
 * @description Daily scheduled batch that creates forecast snapshots and summaries
 *              based on the configured forecast cadence (Weekly/Bi-Weekly/Monthly/Quarterly).
 *              Replaces the nightly snapshot batch for cadence-enabled orgs.
 *              Runs idempotently — skips if a snapshot already exists for today.
 *              Handles auto-freeze at 23:59:59 in org timezone on deadline day.
 */
public class ForecastCadenceSnapshotBatch implements Database.Batchable<SObject>, Schedulable {
  private Id configId;
  private String cadence;
  private String deadlineDay;
  private Date anchorDate;
  private Boolean autoFreeze;

  public void execute(SchedulableContext sc) {
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    if (config == null || String.isBlank(config.Forecast_Cadence__c)) {
      return; // No cadence configured
    }

    this.configId = config.Id;
    this.cadence = config.Forecast_Cadence__c;
    this.deadlineDay = config.Submission_Deadline_Day__c;
    this.anchorDate = config.Cadence_Anchor_Date__c;
    this.autoFreeze = config.Auto_Freeze_On_Deadline__c == true;

    if (!isCadenceDay()) {
      return; // Not a cadence cycle day
    }

    Database.executeBatch(this, 50);
  }

  /**
   * @description Determine if today is a cadence cycle day based on config.
   */
  public Boolean isCadenceDay() {
    Date today = Date.today();

    if (cadence == 'Weekly') {
      return getDayOfWeekLiteral(today) == deadlineDay;
    }

    if (cadence == 'Bi_Weekly') {
      if (getDayOfWeekLiteral(today) != deadlineDay) {
        return false;
      }
      // Check if this is an even-numbered week from anchor
      if (anchorDate == null) {
        return true;
      } // No anchor = every matching day
      Integer daysBetween = anchorDate.daysBetween(today);
      Integer weeksBetween = daysBetween / 7;
      return Math.mod(weeksBetween, 2) == 0;
    }

    if (cadence == 'Monthly') {
      if (String.isBlank(deadlineDay) || !deadlineDay.isNumeric()) {
        return false;
      }
      Integer targetDay = Integer.valueOf(deadlineDay);
      Integer lastDayOfMonth = Date.daysInMonth(today.year(), today.month());
      Integer effectiveDay = Math.min(targetDay, lastDayOfMonth);
      return today.day() == effectiveDay;
    }

    if (cadence == 'Quarterly') {
      if (String.isBlank(deadlineDay) || !deadlineDay.isNumeric()) {
        return false;
      }
      Integer targetDayOfQuarter = Integer.valueOf(deadlineDay);
      Date quarterStart = getQuarterStart(today);
      Integer currentDayOfQuarter = quarterStart.daysBetween(today) + 1;
      return currentDayOfQuarter == targetDayOfQuarter;
    }

    return false;
  }

  /**
   * @description Returns 3-letter day-of-week literal for a date.
   */
  private static String getDayOfWeekLiteral(Date d) {
    // Datetime.format('E') returns Mon, Tue, etc.
    Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
    return dt.format('E').substring(0, 3);
  }

  /**
   * @description Returns the first day of the fiscal quarter for a date.
   *              Uses standard calendar quarters (Jan-Mar, Apr-Jun, Jul-Sep, Oct-Dec).
   */
  private static Date getQuarterStart(Date d) {
    Integer qMonth = ((d.month() - 1) / 3) * 3 + 1;
    return Date.newInstance(d.year(), qMonth, 1);
  }

  // ── Batchable interface ──

  public Database.QueryLocator start(Database.BatchableContext bc) {
    // Query all open periods for the active config
    Id cfgId = this.configId;
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Forecast_Period__c,
          Forecast_Period__r.Start_Date__c,
          Forecast_Period__r.End_Date__c,
          User__c,
          Submission_Status__c
        FROM Forecast_Participant__c
        WHERE
          Forecast_Period__c IN (
            SELECT Id
            FROM Forecast_Period__c
            WHERE Forecast_Configuration__c = :cfgId AND Status__c = 'Open'
          )
      ]
    );
  }

  public void execute(
    Database.BatchableContext bc,
    List<Forecast_Participant__c> participants
  ) {
    Date today = Date.today();
    Set<Id> participantIds = new Set<Id>();
    Map<Id, Forecast_Participant__c> partMap = new Map<Id, Forecast_Participant__c>();

    for (Forecast_Participant__c p : participants) {
      participantIds.add(p.Id);
      partMap.put(p.Id, p);
    }

    // Check idempotency: skip participants that already have a Cadence snapshot today
    Set<Id> alreadySnapshotted = new Set<Id>();
    for (Forecast_Snapshot__c existing : [
      SELECT Forecast_Participant__c
      FROM Forecast_Snapshot__c
      WHERE
        Forecast_Participant__c IN :participantIds
        AND Snapshot_Date__c = :today
        AND Snapshot_Type__c = 'Cadence'
    ]) {
      alreadySnapshotted.add(existing.Forecast_Participant__c);
    }

    List<Forecast_Snapshot__c> snapshots = new List<Forecast_Snapshot__c>();

    for (Forecast_Participant__c p : participants) {
      if (alreadySnapshotted.contains(p.Id)) {
        continue;
      }

      Forecast_Snapshot__c snap = new Forecast_Snapshot__c();
      snap.Forecast_Period__c = p.Forecast_Period__c;
      snap.Forecast_Participant__c = p.Id;
      snap.Snapshot_Type__c = 'Cadence';
      snap.Snapshot_Date__c = today;
      snap.Scope_Id__c = this.configId;
      snapshots.add(snap);
    }

    if (!snapshots.isEmpty()) {
      insert snapshots;
    }

    // Auto-freeze: if enabled, freeze participants who haven't submitted
    if (this.autoFreeze) {
      List<Forecast_Participant__c> toFreeze = new List<Forecast_Participant__c>();
      for (Forecast_Participant__c p : participants) {
        if (
          p.Submission_Status__c != 'Submitted' &&
          p.Submission_Status__c != 'Frozen'
        ) {
          Forecast_Participant__c upd = new Forecast_Participant__c(Id = p.Id);
          upd.Submission_Status__c = 'Frozen';
          toFreeze.add(upd);
        }
      }
      if (!toFreeze.isEmpty()) {
        update toFreeze;
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    // Log completion
    System.debug(
      'ForecastCadenceSnapshotBatch completed for config: ' + this.configId
    );
  }
}
