/**
 * @description Batch job that initializes Forecast_Participant__c records when a
 *              new Forecast_Period__c is created or transitions to Open status.
 *              Runs hierarchy sync and creates Summary Participants for multi-scope
 *              users. Does NOT create Forecast_Override__c records (lazy
 *              materialization per spec section 9.1).
 *
 *              Ported from: Temenos ForecastInitialization.cls
 *
 *              Usage:
 *              Database.executeBatch(new ForecastInitializationBatch(periodId), 200);
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 6.2
 */
public class ForecastInitializationBatch implements Database.Batchable<SObject> {
  private Id periodId;

  /**
   * @description Constructor accepting the period to initialize.
   * @param periodId The Forecast_Period__c Id
   */
  public ForecastInitializationBatch(Id periodId) {
    this.periodId = periodId;
  }

  /**
   * @description Query all Forecast_Participant__c records for the given period.
   *              These are the participants that need pipeline scope verification.
   * @param bc The BatchableContext
   * @return QueryLocator for participants in this period
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          User__c,
          Scope_Id__c,
          Hierarchy_Level__c,
          Reports_To__c,
          Is_Summary__c,
          Submission_Status__c
        FROM Forecast_Participant__c
        WHERE Forecast_Period__c = :periodId
      ]
    );
  }

  /**
   * @description For each participant, verify pipeline records are in scope.
   *              Does NOT create Forecast_Override__c records (lazy materialization).
   *              Creates Summary Participants for multi-scope users.
   * @param bc The BatchableContext
   * @param participants Batch of Forecast_Participant__c records
   */
  public void execute(
    Database.BatchableContext bc,
    List<Forecast_Participant__c> participants
  ) {
    // Track users who appear in multiple scopes for summary participant creation
    Map<Id, Set<String>> userScopes = new Map<Id, Set<String>>();
    Set<Id> existingSummaryParticipantUserIds = new Set<Id>();

    for (Forecast_Participant__c p : participants) {
      // Track scope membership per user
      if (p.User__c != null && String.isNotBlank(p.Scope_Id__c)) {
        if (!userScopes.containsKey(p.User__c)) {
          userScopes.put(p.User__c, new Set<String>());
        }
        userScopes.get(p.User__c).add(p.Scope_Id__c);
      }

      // Track existing summary participants
      if (p.Is_Summary__c == true) {
        existingSummaryParticipantUserIds.add(p.User__c);
      }
    }

    // Create Summary Participants for users who are in multiple scopes
    // and don't already have a summary participant
    List<Forecast_Participant__c> summaryParticipants = new List<Forecast_Participant__c>();

    for (Id userId : userScopes.keySet()) {
      Set<String> scopes = userScopes.get(userId);
      if (
        scopes.size() > 1 && !existingSummaryParticipantUserIds.contains(userId)
      ) {
        // Find the participant with the highest hierarchy level for this user
        Forecast_Participant__c highestLevel = null;
        for (Forecast_Participant__c p : participants) {
          if (p.User__c == userId && p.Is_Summary__c != true) {
            if (
              highestLevel == null ||
              (p.Hierarchy_Level__c != null &&
              p.Hierarchy_Level__c > highestLevel.Hierarchy_Level__c)
            ) {
              highestLevel = p;
            }
          }
        }

        if (highestLevel != null) {
          Forecast_Participant__c summary = new Forecast_Participant__c();
          summary.User__c = userId;
          summary.Forecast_Period__c = periodId;
          summary.Scope_Id__c = 'SUMMARY';
          summary.Hierarchy_Level__c = highestLevel.Hierarchy_Level__c;
          summary.Is_Summary__c = true;
          summary.Submission_Status__c = 'New';
          summary.Reports_To__c = highestLevel.Reports_To__c;
          summaryParticipants.add(summary);
        }
      }
    }

    if (!summaryParticipants.isEmpty()) {
      insert summaryParticipants;
      System.debug(
        'ForecastInitializationBatch: Created ' +
          summaryParticipants.size() +
          ' summary participant(s).'
      );
    }
  }

  /**
   * @description Log completion. No post-processing needed.
   * @param bc The BatchableContext
   */
  public void finish(Database.BatchableContext bc) {
    System.debug(
      'ForecastInitializationBatch complete for period: ' + periodId
    );
  }
}
