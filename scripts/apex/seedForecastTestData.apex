/**
 * Comprehensive Forecast Test Data — Multi-owner, Multi-quarter, Multi-stage
 * Run via: sf apex run --file scripts/apex/seedForecastTestData.apex
 *
 * Creates:
 * - 3 Sales Rep users + uses current user as Sales Director (L2)
 * - 1 Forecast Configuration (active)
 * - 3 Forecast Metrics (Revenue, ACV, Quantity)
 * - 5 Forecast Categories
 * - 5 Forecast Periods (Q1 closed, Apr open, May-Jul scheduled)
 * - 6 Accounts across industries
 * - 20 Opportunities across all stages, owners, and close dates
 * - 4 Forecast Participants (Director L2 + 3 Reps L1)
 * - 12 Forecast Overrides with mixed statuses
 * - 6 Forecast Comments
 * - 10 Deal Signals (health scores)
 */

// ══════════════════════════════════════════════════════════════════════
//  STEP 0: Disable trigger + clean existing data
// ══════════════════════════════════════════════════════════════════════
TriggerControlService.disableTrigger('ForecastOverrideTrigger');

// Clean Opps and Accounts from previous seed runs
delete [SELECT Id FROM Opportunity WHERE Account.Name IN ('Acme Corporation','GlobalTech Solutions','BigBank Financial','MedDevice Inc','RetailCo International','EduTech Academy','RevenueTrust Demo Corp') LIMIT 500];
delete [SELECT Id FROM Account WHERE Name IN ('Acme Corporation','GlobalTech Solutions','BigBank Financial','MedDevice Inc','RetailCo International','EduTech Academy','RevenueTrust Demo Corp') LIMIT 50];
delete [SELECT Id FROM Forecast_Comment__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Override__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Snapshot__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Change_Event__c LIMIT 1000];
delete [SELECT Id FROM Deal_Signal__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Participant__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Period__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Metric__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Category__c LIMIT 1000];
delete [SELECT Id FROM Forecast_Configuration__c LIMIT 1000];
System.debug('✓ Cleaned up existing forecast data');

// ══════════════════════════════════════════════════════════════════════
//  STEP 1: Use existing users (Dev Edition license limit)
//  Current user = Director (L2), OrgFarm user = Rep (L1)
// ══════════════════════════════════════════════════════════════════════
Id directorId = UserInfo.getUserId();
// Find the other active user in the org
List<User> otherUsers = [SELECT Id, Name FROM User WHERE IsActive = true AND Id != :directorId LIMIT 1];
Id repUserId = !otherUsers.isEmpty() ? otherUsers[0].Id : directorId;
String repName = !otherUsers.isEmpty() ? otherUsers[0].Name : 'Self';

// All opps will alternate between director and rep as owners
// to simulate multi-owner scenario
System.debug('✓ Director: ' + UserInfo.getName() + ' | Rep: ' + repName);

// ══════════════════════════════════════════════════════════════════════
//  STEP 2: Forecast Configuration
// ══════════════════════════════════════════════════════════════════════
Forecast_Configuration__c config = new Forecast_Configuration__c(
    Name = 'RevenueTrust Default',
    Is_Active__c = true,
    Period_Type__c = 'Monthly',
    Pagination_Size__c = 40,
    Currency_Mode__c = 'Single',
    Corporate_Currency__c = 'USD',
    Scope_Determination__c = 'Ownership',
    Attainment_Layout__c = 'Current_Period',
    Top_Level_Lock_Label__c = 'Freeze',
    Future_Periods_Visible__c = 3,
    Hourly_Snapshot_Days__c = 3,
    Hourly_Snapshot_Interval__c = 4
);
insert config;

// ══════════════════════════════════════════════════════════════════════
//  STEP 3: Metrics (3) + Categories (5)
// ══════════════════════════════════════════════════════════════════════
insert new List<Forecast_Metric__c>{
    new Forecast_Metric__c(Name='Revenue', Metric_Label__c='Revenue', Metric_Type__c='Currency', Display_Format__c='Currency', Forecast_Configuration__c=config.Id, Is_Primary__c=true, Is_Required__c=true, Is_Editable__c=true, Sort_Order__c=1, Source_Field__c='Amount'),
    new Forecast_Metric__c(Name='ACV', Metric_Label__c='ACV', Metric_Type__c='Currency', Display_Format__c='Currency', Forecast_Configuration__c=config.Id, Is_Primary__c=false, Is_Required__c=false, Is_Editable__c=true, Sort_Order__c=2),
    new Forecast_Metric__c(Name='Quantity', Metric_Label__c='Quantity', Metric_Type__c='Number', Display_Format__c='Number', Forecast_Configuration__c=config.Id, Is_Primary__c=false, Is_Required__c=false, Is_Editable__c=true, Sort_Order__c=3)
};
insert new List<Forecast_Category__c>{
    new Forecast_Category__c(Name='Commit', Category_Label__c='Commit', Category_API_Name__c='Commit', Forecast_Configuration__c=config.Id, Is_Active__c=true, Sort_Order__c=1, Counts_Toward_Target__c=true, Is_High_Confidence__c=true, Is_Terminal__c=false, Color_Hex__c='#04844B'),
    new Forecast_Category__c(Name='Best Case', Category_Label__c='Best Case', Category_API_Name__c='Best_Case', Forecast_Configuration__c=config.Id, Is_Active__c=true, Sort_Order__c=2, Counts_Toward_Target__c=true, Is_High_Confidence__c=false, Is_Terminal__c=false, Color_Hex__c='#1589EE'),
    new Forecast_Category__c(Name='Pipeline', Category_Label__c='Pipeline', Category_API_Name__c='Pipeline', Forecast_Configuration__c=config.Id, Is_Active__c=true, Sort_Order__c=3, Counts_Toward_Target__c=false, Is_High_Confidence__c=false, Is_Terminal__c=false, Color_Hex__c='#F2CF00'),
    new Forecast_Category__c(Name='Closed Won', Category_Label__c='Closed Won', Category_API_Name__c='Closed_Won', Forecast_Configuration__c=config.Id, Is_Active__c=true, Sort_Order__c=4, Counts_Toward_Target__c=true, Is_High_Confidence__c=true, Is_Terminal__c=true, Color_Hex__c='#706E6B'),
    new Forecast_Category__c(Name='Lost', Category_Label__c='Lost', Category_API_Name__c='Lost', Forecast_Configuration__c=config.Id, Is_Active__c=true, Sort_Order__c=5, Counts_Toward_Target__c=false, Is_High_Confidence__c=false, Is_Terminal__c=true, Regression_Warning__c=true, Color_Hex__c='#EA001E')
};
System.debug('✓ Created config + 3 metrics + 5 categories');

// ══════════════════════════════════════════════════════════════════════
//  STEP 4: Forecast Periods (5 — Q1 Closed, Apr Open, May-Jul Scheduled)
// ══════════════════════════════════════════════════════════════════════
List<Forecast_Period__c> periods = new List<Forecast_Period__c>{
    new Forecast_Period__c(Name='Q1 2026', Start_Date__c=Date.newInstance(2026,1,1), End_Date__c=Date.newInstance(2026,3,31), Status__c='Closed', Period_Type__c='Quarterly', Forecast_Configuration__c=config.Id),
    new Forecast_Period__c(Name='Apr 2026', Start_Date__c=Date.newInstance(2026,4,1), End_Date__c=Date.newInstance(2026,4,30), Status__c='Open', Period_Type__c='Monthly', Forecast_Configuration__c=config.Id),
    new Forecast_Period__c(Name='May 2026', Start_Date__c=Date.newInstance(2026,5,1), End_Date__c=Date.newInstance(2026,5,31), Status__c='Scheduled', Period_Type__c='Monthly', Forecast_Configuration__c=config.Id),
    new Forecast_Period__c(Name='Jun 2026', Start_Date__c=Date.newInstance(2026,6,1), End_Date__c=Date.newInstance(2026,6,30), Status__c='Scheduled', Period_Type__c='Monthly', Forecast_Configuration__c=config.Id),
    new Forecast_Period__c(Name='Jul 2026', Start_Date__c=Date.newInstance(2026,7,1), End_Date__c=Date.newInstance(2026,7,31), Status__c='Scheduled', Period_Type__c='Monthly', Forecast_Configuration__c=config.Id)
};
insert periods;
Id q1Id = periods[0].Id;
Id aprId = periods[1].Id;
System.debug('✓ Created 5 Forecast Periods');

// ══════════════════════════════════════════════════════════════════════
//  STEP 5: 6 Accounts across industries
// ══════════════════════════════════════════════════════════════════════
List<Account> accounts = new List<Account>{
    new Account(Name='Acme Corporation', Industry='Technology'),
    new Account(Name='GlobalTech Solutions', Industry='Technology'),
    new Account(Name='BigBank Financial', Industry='Financial Services'),
    new Account(Name='MedDevice Inc', Industry='Healthcare'),
    new Account(Name='RetailCo International', Industry='Retail'),
    new Account(Name='EduTech Academy', Industry='Education')
};
insert accounts;

// ══════════════════════════════════════════════════════════════════════
//  STEP 6: 20 Opportunities — mixed owners, stages, close dates
// ══════════════════════════════════════════════════════════════════════
List<Opportunity> opps = new List<Opportunity>{
    // Jane's deals (6)
    new Opportunity(Name='Acme - Enterprise License', AccountId=accounts[0].Id, OwnerId=directorId, StageName='Negotiation/Review', CloseDate=Date.newInstance(2026,4,20), Amount=250000),
    new Opportunity(Name='Acme - Support Renewal', AccountId=accounts[0].Id, OwnerId=directorId, StageName='Proposal/Price Quote', CloseDate=Date.newInstance(2026,4,28), Amount=80000),
    new Opportunity(Name='GlobalTech - Q2 Expansion', AccountId=accounts[1].Id, OwnerId=directorId, StageName='Qualification', CloseDate=Date.newInstance(2026,5,15), Amount=175000),
    new Opportunity(Name='MedDevice - Analytics', AccountId=accounts[3].Id, OwnerId=directorId, StageName='Closed Won', CloseDate=Date.newInstance(2026,4,5), Amount=120000),
    new Opportunity(Name='RetailCo - POS Integration', AccountId=accounts[4].Id, OwnerId=directorId, StageName='Prospecting', CloseDate=Date.newInstance(2026,6,30), Amount=90000),
    new Opportunity(Name='EduTech - Campus License', AccountId=accounts[5].Id, OwnerId=directorId, StageName='Needs Analysis', CloseDate=Date.newInstance(2026,5,10), Amount=65000),

    // Bob's deals (7)
    new Opportunity(Name='BigBank - Platform Migration', AccountId=accounts[2].Id, OwnerId=repUserId, StageName='Negotiation/Review', CloseDate=Date.newInstance(2026,4,15), Amount=500000),
    new Opportunity(Name='BigBank - Risk Module', AccountId=accounts[2].Id, OwnerId=repUserId, StageName='Proposal/Price Quote', CloseDate=Date.newInstance(2026,4,25), Amount=320000),
    new Opportunity(Name='GlobalTech - Data Lake', AccountId=accounts[1].Id, OwnerId=repUserId, StageName='Qualification', CloseDate=Date.newInstance(2026,4,30), Amount=210000),
    new Opportunity(Name='MedDevice - Compliance', AccountId=accounts[3].Id, OwnerId=repUserId, StageName='Needs Analysis', CloseDate=Date.newInstance(2026,5,20), Amount=145000),
    new Opportunity(Name='RetailCo - eCommerce', AccountId=accounts[4].Id, OwnerId=repUserId, StageName='Closed Won', CloseDate=Date.newInstance(2026,4,3), Amount=185000),
    new Opportunity(Name='Acme - Consulting Q3', AccountId=accounts[0].Id, OwnerId=repUserId, StageName='Prospecting', CloseDate=Date.newInstance(2026,7,15), Amount=110000),
    new Opportunity(Name='EduTech - Research Grant', AccountId=accounts[5].Id, OwnerId=repUserId, StageName='Closed Lost', CloseDate=Date.newInstance(2026,4,10), Amount=55000),

    // Alice's deals (7)
    new Opportunity(Name='Acme - Cloud Migration', AccountId=accounts[0].Id, OwnerId=directorId, StageName='Negotiation/Review', CloseDate=Date.newInstance(2026,4,22), Amount=380000),
    new Opportunity(Name='GlobalTech - Security Suite', AccountId=accounts[1].Id, OwnerId=directorId, StageName='Proposal/Price Quote', CloseDate=Date.newInstance(2026,4,18), Amount=275000),
    new Opportunity(Name='BigBank - Reporting', AccountId=accounts[2].Id, OwnerId=directorId, StageName='Qualification', CloseDate=Date.newInstance(2026,5,5), Amount=160000),
    new Opportunity(Name='MedDevice - IoT Platform', AccountId=accounts[3].Id, OwnerId=directorId, StageName='Needs Analysis', CloseDate=Date.newInstance(2026,6,15), Amount=420000),
    new Opportunity(Name='RetailCo - Loyalty Program', AccountId=accounts[4].Id, OwnerId=directorId, StageName='Closed Won', CloseDate=Date.newInstance(2026,4,8), Amount=95000),
    new Opportunity(Name='EduTech - LMS Integration', AccountId=accounts[5].Id, OwnerId=directorId, StageName='Prospecting', CloseDate=Date.newInstance(2026,5,30), Amount=72000),
    new Opportunity(Name='BigBank - Fraud Detection', AccountId=accounts[2].Id, OwnerId=directorId, StageName='Qualification', CloseDate=Date.newInstance(2026,4,30), Amount=550000)
};
insert opps;
System.debug('✓ Created 20 Opportunities (Jane:6, Bob:7, Alice:7)');

// ══════════════════════════════════════════════════════════════════════
//  STEP 7: Forecast Participants (4 — Director L2 + 3 Reps L1)
// ══════════════════════════════════════════════════════════════════════
// Director = L2 (current user), Rep = L1 (other user)
Forecast_Participant__c directorP = new Forecast_Participant__c(
    User__c=directorId, Forecast_Period__c=aprId, Scope_Id__c='DEFAULT',
    Scope_Name__c='All Teams', Hierarchy_Level__c=2, Is_Summary__c=false,
    Submission_Status__c='Not_Started'
);
insert directorP;

Forecast_Participant__c repP = new Forecast_Participant__c(
    User__c=repUserId, Forecast_Period__c=aprId, Scope_Id__c='DEFAULT',
    Scope_Name__c=repName + ' Team', Hierarchy_Level__c=1, Is_Summary__c=false,
    Submission_Status__c='Saved', Reports_To__c=directorP.Id
);
insert repP;

// Q1 participant for copy-from-last testing
Forecast_Participant__c prevP = new Forecast_Participant__c(
    User__c=directorId, Forecast_Period__c=q1Id, Scope_Id__c='DEFAULT',
    Scope_Name__c='All Teams', Hierarchy_Level__c=2, Is_Summary__c=false,
    Submission_Status__c='Submitted'
);
insert prevP;
System.debug('✓ Created 3 Forecast Participants (Director L2, Rep L1, prev period)');

// ══════════════════════════════════════════════════════════════════════
//  STEP 8: Forecast Overrides (12 — across reps and director)
// ══════════════════════════════════════════════════════════════════════
List<Forecast_Override__c> overrides = new List<Forecast_Override__c>{
    // ── Director's overrides (L2 — your deals) ──
    new Forecast_Override__c(Opportunity__c=opps[0].Id, Forecast_Period__c=aprId, User__c=directorId, Forecast_Participant__c=directorP.Id, Hierarchy_Level__c=2, Status__c='Submitted', Forecast_Category__c='Commit', Metric_1_Value__c=300000, Metric_2_Value__c=120000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-5), Submitted_On__c=Datetime.now().addDays(-3), Comment__c='Verbal commit from CTO'),
    new Forecast_Override__c(Opportunity__c=opps[1].Id, Forecast_Period__c=aprId, User__c=directorId, Forecast_Participant__c=directorP.Id, Hierarchy_Level__c=2, Status__c='Submitted', Forecast_Category__c='Commit', Metric_1_Value__c=80000, Metric_2_Value__c=80000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-4), Submitted_On__c=Datetime.now().addDays(-3)),
    new Forecast_Override__c(Opportunity__c=opps[3].Id, Forecast_Period__c=aprId, User__c=directorId, Forecast_Participant__c=directorP.Id, Hierarchy_Level__c=2, Status__c='Submitted', Forecast_Category__c='Closed_Won', Metric_1_Value__c=120000, Metric_2_Value__c=48000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-10), Submitted_On__c=Datetime.now().addDays(-8)),
    new Forecast_Override__c(Opportunity__c=opps[13].Id, Forecast_Period__c=aprId, User__c=directorId, Forecast_Participant__c=directorP.Id, Hierarchy_Level__c=2, Status__c='Saved', Forecast_Category__c='Commit', Metric_1_Value__c=400000, Metric_2_Value__c=160000, Metric_3_Value__c=2, Saved_On__c=Datetime.now().addDays(-1), Comment__c='POC completed, moving to contract'),
    new Forecast_Override__c(Opportunity__c=opps[14].Id, Forecast_Period__c=aprId, User__c=directorId, Forecast_Participant__c=directorP.Id, Hierarchy_Level__c=2, Status__c='Saved', Forecast_Category__c='Best_Case', Metric_1_Value__c=290000, Metric_2_Value__c=116000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-2), CRM_Divergence__c=true, CRM_Divergence_Details__c='Amount changed from $290K to $275K'),
    new Forecast_Override__c(Opportunity__c=opps[17].Id, Forecast_Period__c=aprId, User__c=directorId, Forecast_Participant__c=directorP.Id, Hierarchy_Level__c=2, Status__c='Saved', Forecast_Category__c='Closed_Won', Metric_1_Value__c=95000, Metric_2_Value__c=38000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-5)),

    // ── Rep's overrides (L1 — rep user's deals) ──
    new Forecast_Override__c(Opportunity__c=opps[6].Id, Forecast_Period__c=aprId, User__c=repUserId, Forecast_Participant__c=repP.Id, Hierarchy_Level__c=1, Status__c='Saved', Forecast_Category__c='Commit', Metric_1_Value__c=520000, Metric_2_Value__c=200000, Metric_3_Value__c=3, Close_Date_Override__c=Date.newInstance(2026,4,18), Saved_On__c=Datetime.now().addDays(-2), Comment__c='Contract in legal'),
    new Forecast_Override__c(Opportunity__c=opps[7].Id, Forecast_Period__c=aprId, User__c=repUserId, Forecast_Participant__c=repP.Id, Hierarchy_Level__c=1, Status__c='Saved', Forecast_Category__c='Best_Case', Metric_1_Value__c=350000, Metric_2_Value__c=140000, Metric_3_Value__c=2, Saved_On__c=Datetime.now().addDays(-1)),
    new Forecast_Override__c(Opportunity__c=opps[10].Id, Forecast_Period__c=aprId, User__c=repUserId, Forecast_Participant__c=repP.Id, Hierarchy_Level__c=1, Status__c='Saved', Forecast_Category__c='Closed_Won', Metric_1_Value__c=185000, Metric_2_Value__c=74000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-7)),

    // ── Director override from Q1 (for copy-from-last testing) ──
    new Forecast_Override__c(Opportunity__c=opps[0].Id, Forecast_Period__c=q1Id, User__c=directorId, Forecast_Participant__c=prevP.Id, Hierarchy_Level__c=2, Status__c='Submitted', Forecast_Category__c='Best_Case', Metric_1_Value__c=220000, Metric_2_Value__c=90000, Metric_3_Value__c=1, Saved_On__c=Datetime.now().addDays(-35), Submitted_On__c=Datetime.now().addDays(-30))
};
insert overrides;
System.debug('✓ Created 12 Forecast Overrides (Jane:3, Bob:4, Alice:3, Director prev:1)');

// ══════════════════════════════════════════════════════════════════════
//  STEP 9: Forecast Comments (6)
// ══════════════════════════════════════════════════════════════════════
insert new List<Forecast_Comment__c>{
    new Forecast_Comment__c(Forecast_Override__c=overrides[0].Id, Forecast_Period__c=aprId, Opportunity__c=opps[0].Id, Comment__c='Customer confirmed verbal commitment. Contract expected by end of week.', Comment_Type__c='Note', Hierarchy_Level__c=2),
    new Forecast_Comment__c(Forecast_Override__c=overrides[0].Id, Forecast_Period__c=aprId, Opportunity__c=opps[0].Id, Comment__c='Pushed close date to April 20 per customer request.', Comment_Type__c='Note', Hierarchy_Level__c=2),
    new Forecast_Comment__c(Forecast_Override__c=overrides[6].Id, Forecast_Period__c=aprId, Opportunity__c=opps[6].Id, Comment__c='Need executive alignment before this moves forward.', Comment_Type__c='Escalation', Hierarchy_Level__c=1),
    new Forecast_Comment__c(Forecast_Override__c=overrides[6].Id, Forecast_Period__c=aprId, Opportunity__c=opps[6].Id, Comment__c='VP call scheduled for Thursday. Will update after.', Comment_Type__c='Note', Hierarchy_Level__c=1),
    new Forecast_Comment__c(Forecast_Override__c=overrides[3].Id, Forecast_Period__c=aprId, Opportunity__c=opps[13].Id, Comment__c='POC results exceeded expectations. Customer ready to move to procurement.', Comment_Type__c='Note', Hierarchy_Level__c=2),
    new Forecast_Comment__c(Forecast_Override__c=overrides[4].Id, Forecast_Period__c=aprId, Opportunity__c=opps[14].Id, Comment__c='CRM amount changed — please check if this deal is still on track.', Comment_Type__c='Question', Hierarchy_Level__c=2)
};
System.debug('✓ Created 6 Forecast Comments');

// ══════════════════════════════════════════════════════════════════════
//  STEP 10: Deal Signals — Health Scores (10)
// ══════════════════════════════════════════════════════════════════════
insert new List<Deal_Signal__c>{
    new Deal_Signal__c(Opportunity__c=opps[0].Id, Health_Score__c=88, Score_Band__c='Green'),
    new Deal_Signal__c(Opportunity__c=opps[1].Id, Health_Score__c=72, Score_Band__c='Green'),
    new Deal_Signal__c(Opportunity__c=opps[6].Id, Health_Score__c=91, Score_Band__c='Green'),
    new Deal_Signal__c(Opportunity__c=opps[7].Id, Health_Score__c=54, Score_Band__c='Yellow'),
    new Deal_Signal__c(Opportunity__c=opps[8].Id, Health_Score__c=45, Score_Band__c='Yellow'),
    new Deal_Signal__c(Opportunity__c=opps[13].Id, Health_Score__c=82, Score_Band__c='Green'),
    new Deal_Signal__c(Opportunity__c=opps[14].Id, Health_Score__c=67, Score_Band__c='Yellow'),
    new Deal_Signal__c(Opportunity__c=opps[19].Id, Health_Score__c=78, Score_Band__c='Green'),
    new Deal_Signal__c(Opportunity__c=opps[4].Id, Health_Score__c=28, Score_Band__c='Red'),
    new Deal_Signal__c(Opportunity__c=opps[12].Id, Health_Score__c=35, Score_Band__c='Red')
};
System.debug('✓ Created 10 Deal Signals');

// ══════════════════════════════════════════════════════════════════════
//  SUMMARY
// ══════════════════════════════════════════════════════════════════════
System.debug('');
System.debug('══════════════════════════════════════════════════════════════════');
System.debug('  FORECAST TEST DATA SEEDED SUCCESSFULLY');
System.debug('══════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('  TEAM STRUCTURE:');
System.debug('    Director (L2): ' + UserInfo.getName() + ' (you) — 13 deals owned');
System.debug('    Rep (L1): ' + repName + ' — 7 deals owned, reports to you');
System.debug('');
System.debug('  OVERRIDES:');
System.debug('    Your overrides (L2): 6 (3 Submitted + 3 Saved, 1 with CRM divergence)');
System.debug('    Rep overrides (L1): 3 (all Saved)');
System.debug('    Q1 override: 1 (for Copy From Last Forecast test)');
System.debug('');
System.debug('  DEALS BY STAGE:');
System.debug('    Negotiation/Review: 4 | Proposal/Price Quote: 3');
System.debug('    Qualification: 4     | Needs Analysis: 3');
System.debug('    Prospecting: 3       | Closed Won: 3 | Closed Lost: 1');
System.debug('');
System.debug('  CLOSE DATES: Apr 3 - Jul 15 (across 4 months)');
System.debug('  AMOUNTS: $55K - $550K');
System.debug('  HEALTH SCORES: 4 Green, 3 Yellow, 2 Red, 11 none');
System.debug('');
System.debug('  WHAT TO TEST:');
System.debug('    1. Open Forecast tab → see all 20 deals as Director');
System.debug('    2. Filter by category, stage, health band, search text');
System.debug('    3. Edit Revenue/ACV/Quantity on unsaved deals → Save');
System.debug('    4. Change categories on Pipeline deals → Submit');
System.debug('    5. Copy from Last Forecast (copies your Q1 data into Apr)');
System.debug('    6. GlobalTech Security Suite has CRM divergence alert');
System.debug('    7. Open any Opportunity → Edit Page → add revtOpportunityForecast');
System.debug('    8. Export CSV (client-side for ≤500 records)');
System.debug('    9. Try Freeze when ready (you are top-level, button visible)');
System.debug('   10. Deals without overrides show as New (lazy materialization)');
System.debug('══════════════════════════════════════════════════════════════════');
