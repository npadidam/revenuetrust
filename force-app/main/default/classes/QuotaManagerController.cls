/**
 * @description Controller for the Quota Manager — simplified quota assignment
 *              for forecasting-only customers. Handles CSV import, distribute evenly,
 *              copy from last period, and bulk operations.
 *              Spec: ADMIN_SETUP_SPEC.md V1.2 §4
 */
public with sharing class QuotaManagerController {
  // ══════════════════════════════════════════════════════════════════════
  //  CRUD
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static List<QuotaRow> getQuotasWithParticipants(Id periodId) {
    return getQuotasWithParticipantsForGroup(periodId, null);
  }

  /**
   * @description Phase B: Group-aware variant. groupId == null returns config-wide
   *              quotas (Forecast_Group__c = null on the quota record).
   */
  @AuraEnabled
  public static List<QuotaRow> getQuotasWithParticipantsForGroup(
    Id periodId,
    Id groupId
  ) {
    // Get all participants for this period (non-summary)
    List<Forecast_Participant__c> participants = [
      SELECT
        Id,
        User__c,
        User__r.Name,
        User__r.Email,
        Hierarchy_Level__c,
        Scope_Id__c
      FROM Forecast_Participant__c
      WHERE Forecast_Period__c = :periodId AND Is_Summary__c = FALSE
      ORDER BY Hierarchy_Level__c ASC, User__r.Name ASC
    ];

    // Get existing quotas for this period + group context
    Map<Id, Forecast_Quota__c> quotasByUser = new Map<Id, Forecast_Quota__c>();
    List<Forecast_Quota__c> quotaList;
    if (groupId == null) {
      quotaList = [
        SELECT
          Id,
          User__c,
          Target_Amount__c,
          Achieved_Amount__c,
          Attainment_Pct__c,
          Status__c,
          Notes__c,
          Forecast_Group__c
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :periodId AND Forecast_Group__c = NULL
      ];
    } else {
      quotaList = [
        SELECT
          Id,
          User__c,
          Target_Amount__c,
          Achieved_Amount__c,
          Attainment_Pct__c,
          Status__c,
          Notes__c,
          Forecast_Group__c
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :periodId AND Forecast_Group__c = :groupId
      ];
    }
    for (Forecast_Quota__c q : quotaList) {
      quotasByUser.put(q.User__c, q);
    }

    // Merge: show all participants with their quota (if exists)
    List<QuotaRow> rows = new List<QuotaRow>();
    for (Forecast_Participant__c p : participants) {
      QuotaRow row = new QuotaRow();
      row.participantId = p.Id;
      row.userId = p.User__c;
      row.userName = p.User__r.Name;
      row.userEmail = p.User__r.Email;
      row.level = p.Hierarchy_Level__c != null
        ? p.Hierarchy_Level__c.intValue()
        : 1;
      row.scopeId = p.Scope_Id__c;

      Forecast_Quota__c q = quotasByUser.get(p.User__c);
      if (q != null) {
        row.quotaId = q.Id;
        row.targetAmount = q.Target_Amount__c;
        row.achievedAmount = q.Achieved_Amount__c;
        row.attainmentPct = q.Attainment_Pct__c;
        row.status = q.Status__c;
        row.notes = q.Notes__c;
        row.hasQuota = true;
      } else {
        row.hasQuota = false;
      }
      rows.add(row);
    }
    return rows;
  }

  @AuraEnabled
  public static Id saveQuota(
    Id quotaId,
    Id userId,
    Id periodId,
    Id participantId,
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
        q.Forecast_Participant__c = participantId;
      }
      q.Target_Amount__c = targetAmount;
      q.Status__c = status != null ? status : 'Active';
      q.Notes__c = notes;
      upsert q;
      return q.Id;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void saveBulkQuotas(String quotasJson, Id periodId) {
    saveBulkQuotasForGroup(quotasJson, periodId, null);
  }

  /**
   * @description Phase B: Group-aware bulk save. groupId == null saves config-wide
   *              quotas (Forecast_Group__c remains null).
   */
  @AuraEnabled
  public static void saveBulkQuotasForGroup(
    String quotasJson,
    Id periodId,
    Id groupId
  ) {
    try {
      List<QuotaSaveInput> inputs = (List<QuotaSaveInput>) JSON.deserialize(
        quotasJson,
        List<QuotaSaveInput>.class
      );

      List<Forecast_Quota__c> toUpsert = new List<Forecast_Quota__c>();
      for (QuotaSaveInput input : inputs) {
        Forecast_Quota__c q;
        if (input.quotaId != null) {
          q = new Forecast_Quota__c(Id = input.quotaId);
        } else {
          q = new Forecast_Quota__c();
          q.User__c = input.userId;
          q.Forecast_Period__c = periodId;
          q.Forecast_Participant__c = input.participantId;
          q.Forecast_Group__c = groupId; // Phase B: bind to group on insert
        }
        q.Target_Amount__c = input.targetAmount;
        q.Status__c = input.status != null ? input.status : 'Active';
        q.Notes__c = input.notes;
        toUpsert.add(q);
      }
      if (!toUpsert.isEmpty()) {
        upsert toUpsert;
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CSV IMPORT
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static ImportResult importCsvQuotas(Id periodId, String csvContent) {
    ImportResult result = new ImportResult();
    result.successCount = 0;
    result.errorRows = new List<ImportErrorRow>();

    if (String.isBlank(csvContent)) {
      result.errorRows.add(new ImportErrorRow(0, '', 'CSV content is empty'));
      return result;
    }

    try {
      // Parse CSV lines
      List<String> lines = csvContent.split('\n');
      if (lines.size() < 2) {
        result.errorRows.add(
          new ImportErrorRow(
            0,
            '',
            'CSV must have a header row and at least one data row'
          )
        );
        return result;
      }

      // Parse header
      String header = lines[0].trim().toLowerCase();
      Integer emailCol = -1;
      Integer targetCol = -1;
      List<String> headerCells = header.split(',');
      for (Integer i = 0; i < headerCells.size(); i++) {
        String h = headerCells[i].trim().replace('"', '');
        if (h == 'email' || h == 'user email' || h == 'useremail') {
          emailCol = i;
        } else if (
          h == 'target' ||
          h == 'target amount' ||
          h == 'targetamount' ||
          h == 'target_amount'
        ) {
          targetCol = i;
        }
      }

      if (emailCol < 0 || targetCol < 0) {
        result.errorRows.add(
          new ImportErrorRow(
            0,
            '',
            'CSV header must include "Email" and "Target Amount" columns'
          )
        );
        return result;
      }

      // Lookup all users by email
      Set<String> emails = new Set<String>();
      for (Integer i = 1; i < lines.size(); i++) {
        String line = lines[i].trim();
        if (String.isBlank(line))
          continue;
        List<String> cells = parseCsvLine(line);
        if (cells.size() > emailCol) {
          emails.add(cells[emailCol].trim().toLowerCase());
        }
      }

      Map<String, User> usersByEmail = new Map<String, User>();
      for (User u : [
        SELECT Id, Email
        FROM User
        WHERE Email IN :emails AND IsActive = TRUE
      ]) {
        usersByEmail.put(u.Email.toLowerCase(), u);
      }

      // Lookup participants for this period
      Map<Id, Forecast_Participant__c> participantsByUser = new Map<Id, Forecast_Participant__c>();
      for (Forecast_Participant__c p : [
        SELECT Id, User__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId AND Is_Summary__c = FALSE
      ]) {
        participantsByUser.put(p.User__c, p);
      }

      // Lookup existing quotas
      Map<Id, Forecast_Quota__c> existingQuotasByUser = new Map<Id, Forecast_Quota__c>();
      for (Forecast_Quota__c q : [
        SELECT Id, User__c
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :periodId
      ]) {
        existingQuotasByUser.put(q.User__c, q);
      }

      // Process rows
      List<Forecast_Quota__c> toInsert = new List<Forecast_Quota__c>();
      Set<String> processedEmails = new Set<String>();

      for (Integer i = 1; i < lines.size(); i++) {
        String line = lines[i].trim();
        if (String.isBlank(line))
          continue;
        List<String> cells = parseCsvLine(line);

        if (cells.size() <= Math.max(emailCol, targetCol)) {
          result.errorRows.add(
            new ImportErrorRow(i, '', 'Row has insufficient columns')
          );
          continue;
        }

        String email = cells[emailCol].trim().toLowerCase();
        String targetStr = cells[targetCol]
          .trim()
          .replace('"', '')
          .replace(',', '')
          .replace('$', '');

        // Duplicate email in CSV check
        if (processedEmails.contains(email)) {
          result.errorRows.add(
            new ImportErrorRow(
              i,
              email,
              'Duplicate — this email appears earlier in the CSV'
            )
          );
          continue;
        }
        processedEmails.add(email);

        // Find user
        User u = usersByEmail.get(email);
        if (u == null) {
          result.errorRows.add(
            new ImportErrorRow(i, email, 'User not found or inactive')
          );
          continue;
        }

        // Check participant
        Forecast_Participant__c p = participantsByUser.get(u.Id);
        if (p == null) {
          result.errorRows.add(
            new ImportErrorRow(
              i,
              email,
              'User is not a forecast participant for this period'
            )
          );
          continue;
        }

        // Check existing quota
        if (existingQuotasByUser.containsKey(u.Id)) {
          result.errorRows.add(
            new ImportErrorRow(
              i,
              email,
              'Duplicate — quota already exists for this period'
            )
          );
          continue;
        }

        // Parse target
        Decimal target;
        try {
          target = Decimal.valueOf(targetStr);
        } catch (Exception ex) {
          result.errorRows.add(
            new ImportErrorRow(i, email, 'Invalid target amount: ' + targetStr)
          );
          continue;
        }
        if (target < 0) {
          result.errorRows.add(
            new ImportErrorRow(i, email, 'Target amount cannot be negative')
          );
          continue;
        }

        // Create quota
        Forecast_Quota__c q = new Forecast_Quota__c();
        q.User__c = u.Id;
        q.Forecast_Period__c = periodId;
        q.Forecast_Participant__c = p.Id;
        q.Target_Amount__c = target;
        q.Status__c = 'Active';
        toInsert.add(q);
      }

      // Insert quotas — use batch for >50 rows (§10.5)
      if (!toInsert.isEmpty()) {
        if (toInsert.size() > 50) {
          // Large import: use batch Apex
          List<QuotaImportBatch.QuotaImportRow> batchRows = new List<QuotaImportBatch.QuotaImportRow>();
          for (Forecast_Quota__c q : toInsert) {
            batchRows.add(
              new QuotaImportBatch.QuotaImportRow(
                q.User__c,
                q.Forecast_Participant__c,
                q.Target_Amount__c
              )
            );
          }
          Database.executeBatch(new QuotaImportBatch(batchRows, periodId), 50);
          result.successCount = toInsert.size();
          // Note: actual success/failure tracked by batch, reported async
        } else {
          // Small import: synchronous DML with row-level results
          List<Database.SaveResult> saveResults = Database.insert(
            toInsert,
            false
          );
          for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
              result.successCount++;
            } else {
              result.errorRows.add(
                new ImportErrorRow(
                  i + 1,
                  '',
                  saveResults[i].getErrors()[0].getMessage()
                )
              );
            }
          }
        }
      }
    } catch (Exception e) {
      result.errorRows.add(
        new ImportErrorRow(0, '', 'Import failed: ' + e.getMessage())
      );
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  DISTRIBUTE EVENLY
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static DistributeResult distributeEvenly(
    Id periodId,
    Decimal teamTotal,
    String conflictPolicy
  ) {
    DistributeResult result = new DistributeResult();
    result.updatedCount = 0;
    result.skippedCount = 0;

    try {
      // Get active participants
      List<Forecast_Participant__c> participants = [
        SELECT Id, User__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId AND Is_Summary__c = FALSE
        ORDER BY User__r.Name ASC
      ];

      if (participants.isEmpty()) {
        throw new AuraHandledException(
          'No participants found for this period.'
        );
      }

      Decimal perPerson = (teamTotal / participants.size()).setScale(2);
      result.perPersonAmount = perPerson;

      // Get existing quotas
      Map<Id, Forecast_Quota__c> existingByUser = new Map<Id, Forecast_Quota__c>();
      for (Forecast_Quota__c q : [
        SELECT Id, User__c
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :periodId
      ]) {
        existingByUser.put(q.User__c, q);
      }

      List<Forecast_Quota__c> toUpsert = new List<Forecast_Quota__c>();
      for (Forecast_Participant__c p : participants) {
        Forecast_Quota__c existing = existingByUser.get(p.User__c);

        if (existing != null && conflictPolicy == 'SKIP_EXISTING') {
          result.skippedCount++;
          continue;
        }

        Forecast_Quota__c q;
        if (existing != null) {
          // OVERWRITE
          q = new Forecast_Quota__c(Id = existing.Id);
        } else {
          q = new Forecast_Quota__c();
          q.User__c = p.User__c;
          q.Forecast_Period__c = periodId;
          q.Forecast_Participant__c = p.Id;
        }
        q.Target_Amount__c = perPerson;
        q.Status__c = 'Active';
        toUpsert.add(q);
        result.updatedCount++;
      }

      if (!toUpsert.isEmpty()) {
        upsert toUpsert;
      }
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  COPY FROM LAST PERIOD
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static CopyResult copyFromLastPeriod(
    Id periodId,
    String conflictPolicy,
    Decimal adjustmentPct
  ) {
    CopyResult result = new CopyResult();
    result.copiedCount = 0;
    result.skippedCount = 0;

    try {
      // Find previous period
      Forecast_Period__c currentPeriod = [
        SELECT Start_Date__c
        FROM Forecast_Period__c
        WHERE Id = :periodId
      ];
      List<Forecast_Period__c> prevPeriods = [
        SELECT Id
        FROM Forecast_Period__c
        WHERE End_Date__c < :currentPeriod.Start_Date__c
        ORDER BY End_Date__c DESC
        LIMIT 1
      ];

      if (prevPeriods.isEmpty()) {
        throw new AuraHandledException('No previous period found.');
      }
      Id prevPeriodId = prevPeriods[0].Id;

      // Get previous period quotas
      Map<Id, Forecast_Quota__c> prevQuotasByUser = new Map<Id, Forecast_Quota__c>();
      for (Forecast_Quota__c q : [
        SELECT User__c, Target_Amount__c
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :prevPeriodId
      ]) {
        prevQuotasByUser.put(q.User__c, q);
      }

      if (prevQuotasByUser.isEmpty()) {
        throw new AuraHandledException(
          'No quotas found in the previous period.'
        );
      }

      // Get current period participants + existing quotas
      Map<Id, Forecast_Participant__c> currentParticipants = new Map<Id, Forecast_Participant__c>();
      for (Forecast_Participant__c p : [
        SELECT Id, User__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId AND Is_Summary__c = FALSE
      ]) {
        currentParticipants.put(p.User__c, p);
      }

      Map<Id, Forecast_Quota__c> existingByUser = new Map<Id, Forecast_Quota__c>();
      for (Forecast_Quota__c q : [
        SELECT Id, User__c
        FROM Forecast_Quota__c
        WHERE Forecast_Period__c = :periodId
      ]) {
        existingByUser.put(q.User__c, q);
      }

      // Apply adjustment factor
      Decimal factor = 1.0;
      if (adjustmentPct != null && adjustmentPct != 0) {
        factor = 1.0 + (adjustmentPct / 100);
      }

      List<Forecast_Quota__c> toUpsert = new List<Forecast_Quota__c>();
      for (Id userId : prevQuotasByUser.keySet()) {
        // User must be a participant in current period
        Forecast_Participant__c currentP = currentParticipants.get(userId);
        if (currentP == null)
          continue;

        Forecast_Quota__c existing = existingByUser.get(userId);

        if (existing != null && conflictPolicy == 'SKIP_EXISTING') {
          result.skippedCount++;
          continue;
        }

        Decimal prevTarget = prevQuotasByUser.get(userId).Target_Amount__c;
        Decimal newTarget = (prevTarget * factor).setScale(2);

        Forecast_Quota__c q;
        if (existing != null) {
          q = new Forecast_Quota__c(Id = existing.Id);
        } else {
          q = new Forecast_Quota__c();
          q.User__c = userId;
          q.Forecast_Period__c = periodId;
          q.Forecast_Participant__c = currentP.Id;
        }
        q.Target_Amount__c = newTarget;
        q.Status__c = 'Active';
        toUpsert.add(q);
        result.copiedCount++;
      }

      if (!toUpsert.isEmpty()) {
        upsert toUpsert;
      }
    } catch (AuraHandledException ae) {
      throw ae;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  DELETE
  // ══════════════════════════════════════════════════════════════════════

  @AuraEnabled
  public static void deleteQuota(Id quotaId) {
    try {
      delete new Forecast_Quota__c(Id = quotaId);
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════

  private static List<String> parseCsvLine(String line) {
    List<String> cells = new List<String>();
    Boolean inQuotes = false;
    String currentCell = '';

    for (Integer i = 0; i < line.length(); i++) {
      String ch = line.substring(i, i + 1);
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        cells.add(currentCell.trim());
        currentCell = '';
      } else {
        currentCell += ch;
      }
    }
    cells.add(currentCell.trim());
    return cells;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  DTOs
  // ══════════════════════════════════════════════════════════════════════

  public class QuotaRow {
    @AuraEnabled
    public Id participantId;
    @AuraEnabled
    public Id userId;
    @AuraEnabled
    public String userName;
    @AuraEnabled
    public String userEmail;
    @AuraEnabled
    public Integer level;
    @AuraEnabled
    public String scopeId;
    @AuraEnabled
    public Id quotaId;
    @AuraEnabled
    public Decimal targetAmount;
    @AuraEnabled
    public Decimal achievedAmount;
    @AuraEnabled
    public Decimal attainmentPct;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String notes;
    @AuraEnabled
    public Boolean hasQuota;
  }

  public class QuotaSaveInput {
    public Id quotaId;
    public Id userId;
    public Id participantId;
    public Decimal targetAmount;
    public String status;
    public String notes;
  }

  public class ImportResult {
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public List<ImportErrorRow> errorRows;
  }

  public class ImportErrorRow {
    @AuraEnabled
    public Integer rowNumber;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String error;
    public ImportErrorRow(Integer row, String email, String error) {
      this.rowNumber = row;
      this.email = email;
      this.error = error;
    }
  }

  public class DistributeResult {
    @AuraEnabled
    public Integer updatedCount;
    @AuraEnabled
    public Integer skippedCount;
    @AuraEnabled
    public Decimal perPersonAmount;
  }

  public class CopyResult {
    @AuraEnabled
    public Integer copiedCount;
    @AuraEnabled
    public Integer skippedCount;
  }
}
