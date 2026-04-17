/**
 * @description Batch Apex for large CSV quota imports (>50 rows).
 *              Processes quota creation in batches to avoid governor limits.
 *              Called by QuotaManagerController when row count exceeds threshold.
 *              Spec: ADMIN_SETUP_SPEC.md §10.5
 */
public class QuotaImportBatch implements Database.Batchable<QuotaImportBatch.QuotaImportRow>, Database.Stateful {
  private List<QuotaImportRow> rows;
  private Id periodId;
  public Integer successCount = 0;
  public Integer errorCount = 0;

  public QuotaImportBatch(List<QuotaImportRow> rows, Id periodId) {
    this.rows = rows;
    this.periodId = periodId;
  }

  public Iterable<QuotaImportRow> start(Database.BatchableContext bc) {
    return rows;
  }

  public void execute(
    Database.BatchableContext bc,
    List<QuotaImportRow> scope
  ) {
    List<Forecast_Quota__c> toInsert = new List<Forecast_Quota__c>();
    for (QuotaImportRow row : scope) {
      Forecast_Quota__c q = new Forecast_Quota__c();
      q.User__c = row.userId;
      q.Forecast_Period__c = periodId;
      q.Forecast_Participant__c = row.participantId;
      q.Target_Amount__c = row.targetAmount;
      q.Status__c = 'Active';
      toInsert.add(q);
    }

    List<Database.SaveResult> results = Database.insert(toInsert, false);
    for (Database.SaveResult sr : results) {
      if (sr.isSuccess()) {
        successCount++;
      } else {
        errorCount++;
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      'QuotaImportBatch complete: ' +
        successCount +
        ' succeeded, ' +
        errorCount +
        ' failed.'
    );
  }

  public class QuotaImportRow {
    public Id userId;
    public Id participantId;
    public Decimal targetAmount;

    public QuotaImportRow(Id userId, Id participantId, Decimal targetAmount) {
      this.userId = userId;
      this.participantId = participantId;
      this.targetAmount = targetAmount;
    }
  }
}
