/**
 * Seed data for Admin Console + Quota Manager testing.
 * Run after Onboarding Wizard activation or manually to create
 * Forecast_Quota__c records and verify admin workflows.
 *
 * Prerequisites: Active Forecast_Configuration__c with periods and participants.
 */

// 1. Find active config, current period, and participants
Forecast_Configuration__c config = [
  SELECT Id, Name
  FROM Forecast_Configuration__c
  WHERE Is_Active__c = TRUE
  LIMIT 1
];
System.assert(config != null, 'No active forecast config. Run Onboarding Wizard first.');

Forecast_Period__c currentPeriod = [
  SELECT Id, Name, Start_Date__c, End_Date__c
  FROM Forecast_Period__c
  WHERE Status__c = 'Open'
  ORDER BY Start_Date__c ASC
  LIMIT 1
];
System.assert(currentPeriod != null, 'No open period found.');

List<Forecast_Participant__c> participants = [
  SELECT Id, User__c, User__r.Name, Hierarchy_Level__c, Scope_Id__c
  FROM Forecast_Participant__c
  WHERE Forecast_Period__c = :currentPeriod.Id
  ORDER BY Hierarchy_Level__c ASC
];
System.debug('Found ' + participants.size() + ' participants for period: ' + currentPeriod.Name);

// 2. Create Forecast_Quota__c records for each participant
List<Forecast_Quota__c> quotas = new List<Forecast_Quota__c>();
Decimal[] targets = new Decimal[]{ 500000, 400000, 350000, 300000, 250000, 200000, 150000, 100000 };

for (Integer i = 0; i < participants.size(); i++) {
  Forecast_Participant__c p = participants[i];
  Decimal target = i < targets.size() ? targets[i] : 200000;

  // Simulate some achieved amount (30-70% of target)
  Decimal achievedPct = 30 + (Math.random() * 40);
  Decimal achieved = (target * achievedPct / 100).setScale(2);

  quotas.add(new Forecast_Quota__c(
    User__c = p.User__c,
    Forecast_Period__c = currentPeriod.Id,
    Forecast_Participant__c = p.Id,
    Target_Amount__c = target,
    Achieved_Amount__c = achieved,
    Status__c = 'Active',
    Notes__c = 'Seed data for ' + p.User__r.Name + ' - Level ' + p.Hierarchy_Level__c
  ));
}

// Delete existing quotas for this period first (avoid duplicates)
List<Forecast_Quota__c> existing = [
  SELECT Id FROM Forecast_Quota__c
  WHERE Forecast_Period__c = :currentPeriod.Id
];
if (!existing.isEmpty()) {
  delete existing;
  System.debug('Deleted ' + existing.size() + ' existing quotas.');
}

insert quotas;
System.debug('Created ' + quotas.size() + ' Forecast_Quota__c records.');

// 3. Log a config change event for audit trail
Forecast_Change_Event__c auditEvent = new Forecast_Change_Event__c(
  Change_Type__c = 'Quota_Set',
  Changed_By__c = UserInfo.getUserId(),
  Change_Timestamp__c = Datetime.now(),
  Config_Change_Details__c = '{"action":"seed_quotas","period":"' + currentPeriod.Name + '","count":' + quotas.size() + '}'
);
insert auditEvent;

// 4. Summary
System.debug('=== Admin Test Data Seeded ===');
System.debug('Config: ' + config.Name);
System.debug('Period: ' + currentPeriod.Name + ' (' + currentPeriod.Start_Date__c + ' to ' + currentPeriod.End_Date__c + ')');
System.debug('Quotas created: ' + quotas.size());
for (Forecast_Quota__c q : quotas) {
  System.debug('  User: ' + q.User__c + ' | Target: $' + q.Target_Amount__c + ' | Achieved: $' + q.Achieved_Amount__c);
}
