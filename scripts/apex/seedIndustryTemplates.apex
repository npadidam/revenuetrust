// ============================================================================
// seedIndustryTemplates.apex
// Inserts 23 Incentive_Plan_Template__c library records + 3 Commission_Tier__c
// children for the SaaS AE Accelerated template.
//
// Run via:  sf apex run --file scripts/apex/seedIndustryTemplates.apex
// Idempotent: deletes existing library templates before re-inserting.
// ============================================================================

// ----- Cleanup existing library templates seeded by this script -------------
// Use Name LIKE pattern instead of Is_Library_Template__c to avoid namespace cache issues
delete [SELECT Id FROM Commission_Tier__c
        WHERE Plan_Template__r.Name LIKE 'SaaS%' OR Plan_Template__r.Name LIKE 'Insurance%'
        OR Plan_Template__r.Name LIKE 'Advisor%' OR Plan_Template__r.Name LIKE 'Wealth%'
        OR Plan_Template__r.Name LIKE 'Relationship%' OR Plan_Template__r.Name LIKE 'Agent%'
        OR Plan_Template__r.Name LIKE 'Broker%' OR Plan_Template__r.Name LIKE 'Team Lead%'
        OR Plan_Template__r.Name LIKE 'Sales Engineer%' OR Plan_Template__r.Name LIKE 'Territory Manager%'
        OR Plan_Template__r.Name LIKE 'Channel Manager%' OR Plan_Template__r.Name LIKE 'Account Exec%'
        OR Plan_Template__r.Name LIKE 'Retention%'];
delete [SELECT Id FROM Incentive_Plan_Template__c
        WHERE Name LIKE 'SaaS%' OR Name LIKE 'Insurance%' OR Name LIKE 'Advisor%'
        OR Name LIKE 'Wealth%' OR Name LIKE 'Relationship%' OR Name LIKE 'Agent%'
        OR Name LIKE 'Broker%' OR Name LIKE 'Team Lead%' OR Name LIKE 'Sales Engineer%'
        OR Name LIKE 'Territory Manager%' OR Name LIKE 'Channel Manager%'
        OR Name LIKE 'Account Exec%' OR Name LIKE 'Retention%'];

// ----- Helper list -----------------------------------------------------------
List<Incentive_Plan_Template__c> templates = new List<Incentive_Plan_Template__c>();

// =========================================================================
// SaaS (5 + 2 global = 7)
// =========================================================================

// 1. SaaS AE — Accelerated
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS AE — Accelerated',
    Plan_Type__c              = 'Accelerated',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Standard SaaS Account Executive plan with accelerators that kick in above quota. Base rate applies up to 100% attainment; higher rates apply retroactively once threshold is crossed.'
));

// 2. SaaS BDR — Flat per Meeting
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS BDR — Flat per Meeting',
    Plan_Type__c              = 'Activity_Based',
    Trigger_Type__c           = 'Activity',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Pays a flat bonus for each qualified meeting or demo set by BDRs. Activity count is validated against minimum qualification criteria before payout.'
));

// 3. SaaS SE — Deal Support
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS SE — Deal Support',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Flat-rate commission for Solutions Engineers credited on deals they supported during the pre-sales cycle. Commission is based on deal booking value.'
));

// 4. SaaS CSM — Renewal Bonus
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS CSM — Renewal Bonus',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Renewal_Date',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Customer Success Managers receive a flat bonus on each successful renewal. Triggered on the renewal execution date to incentivize proactive retention.'
));

// 5. SaaS Manager — Team Attainment
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS Manager — Team Attainment',
    Plan_Type__c              = 'Team_Override',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Sales manager override plan that pays a percentage of each direct report\'s closed bookings. Encourages coaching and team-wide quota attainment.'
));

// =========================================================================
// Insurance (4)
// =========================================================================

// 6. Insurance Agent — New Policy
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Insurance Agent — New Policy',
    Plan_Type__c              = 'Tiered',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Insurance',
    Status__c                 = 'Draft',
    Description__c            = 'Tiered new-policy commission for insurance agents. Higher premium volumes unlock higher commission tiers, rewarding production consistency.'
));

// 7. Insurance Agent — Renewal Trail
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Insurance Agent — Renewal Trail',
    Plan_Type__c              = 'Recurring',
    Trigger_Type__c           = 'Renewal_Date',
    Is_Library_Template__c    = true,
    Industry__c               = 'Insurance',
    Status__c                 = 'Draft',
    Is_Recurring__c           = true,
    Recurring_Rate_Pct__c     = 2,
    Recurring_Cadence__c      = 'Annual',
    Description__c            = 'Ongoing trail commission paid annually on renewing policies at 2% of premium. Incentivizes long-term book-of-business retention.'
));

// 8. Insurance Broker — Override
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Insurance Broker — Override',
    Plan_Type__c              = 'Team_Override',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Insurance',
    Status__c                 = 'Draft',
    Description__c            = 'Broker override on policies written by downline agents. Pays a percentage of the agent\'s commission as an override to the managing broker.'
));

// 9. Insurance Underwriter — Performance
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Insurance Underwriter — Performance',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Milestone',
    Is_Library_Template__c    = true,
    Industry__c               = 'Insurance',
    Status__c                 = 'Draft',
    Description__c            = 'Flat performance bonus for underwriters tied to loss-ratio milestones. Paid when portfolio loss ratio stays below target threshold at quarter end.'
));

// =========================================================================
// Financial Services (4)
// =========================================================================

// 10. Advisor — AUM Trail
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Advisor — AUM Trail',
    Plan_Type__c              = 'Recurring',
    Trigger_Type__c           = 'Monthly_Recurring',
    Is_Library_Template__c    = true,
    Industry__c               = 'Financial_Services',
    Status__c                 = 'Draft',
    Is_Recurring__c           = true,
    Recurring_Rate_Pct__c     = 0.25,
    Recurring_Cadence__c      = 'Quarterly',
    Description__c            = 'Quarterly trail commission at 0.25% of assets under management. Encourages advisors to grow and retain client portfolios over time.'
));

// 11. Advisor — New Client
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Advisor — New Client',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Financial_Services',
    Status__c                 = 'Draft',
    Description__c            = 'One-time flat commission paid when a new client relationship is established and initial assets are deposited. Rewards client acquisition efforts.'
));

// 12. Wealth Manager — Tiered AUM
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Wealth Manager — Tiered AUM',
    Plan_Type__c              = 'Tiered',
    Trigger_Type__c           = 'Monthly_Recurring',
    Is_Library_Template__c    = true,
    Industry__c               = 'Financial_Services',
    Status__c                 = 'Draft',
    Description__c            = 'Tiered management fee split based on total AUM bands. Higher AUM tiers yield progressively better payout ratios for the wealth manager.'
));

// 13. Relationship Manager — Fee Revenue
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Relationship Manager — Fee Revenue',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Collection',
    Is_Library_Template__c    = true,
    Industry__c               = 'Financial_Services',
    Status__c                 = 'Draft',
    Description__c            = 'Flat-rate commission on collected fee revenue from banking products. Triggered on cash collection to align incentives with realized revenue.'
));

// =========================================================================
// Real Estate (3)
// =========================================================================

// 14. Agent — Transaction
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Agent — Transaction',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Real_Estate',
    Status__c                 = 'Draft',
    Description__c            = 'Standard real estate transaction commission. Flat percentage of the sale price paid to the listing or buyer agent at closing.'
));

// 15. Broker — Override
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Broker — Override',
    Plan_Type__c              = 'Team_Override',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Real_Estate',
    Status__c                 = 'Draft',
    Description__c            = 'Brokerage override on agent transactions. The managing broker receives a split of each agent\'s commission based on the desk-fee or split arrangement.'
));

// 16. Team Lead — Team Pool
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Team Lead — Team Pool',
    Plan_Type__c              = 'Team_Pool',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Real_Estate',
    Status__c                 = 'Draft',
    Description__c            = 'Team pool commission where total team production generates a shared bonus pool. The team lead distributes the pool pro-rata based on contribution.'
));

// =========================================================================
// Manufacturing (3)
// =========================================================================

// 17. Sales Engineer — Gross Margin
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Sales Engineer — Gross Margin',
    Plan_Type__c              = 'Gross_Margin',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Manufacturing',
    Status__c                 = 'Draft',
    Description__c            = 'Commission based on gross margin (revenue minus COGS) rather than top-line revenue. Incentivizes profitable deal structuring and discourages deep discounting.'
));

// 18. Territory Manager — Quota Attainment
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Territory Manager — Quota Attainment',
    Plan_Type__c              = 'Accelerated',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Manufacturing',
    Status__c                 = 'Draft',
    Description__c            = 'Accelerated commission plan for territory managers. Base rate up to quota with accelerators that reward above-quota performance in the territory.'
));

// 19. Channel Manager — Partner Sourced
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Channel Manager — Partner Sourced',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Manufacturing',
    Status__c                 = 'Draft',
    Description__c            = 'Flat commission on partner-sourced deals managed by the channel manager. Rewards enablement and partner relationship development.'
));

// =========================================================================
// Telecommunications (2)
// =========================================================================

// 20. Account Exec — MRR Commission
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Account Exec — MRR Commission',
    Plan_Type__c              = 'Recurring',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Telecommunications',
    Status__c                 = 'Draft',
    Is_Recurring__c           = true,
    Recurring_Rate_Pct__c     = 2,
    Recurring_Duration_Months__c = 12,
    Description__c            = 'Recurring MRR-based commission for telecom account executives. Pays 2% of monthly recurring revenue for 12 months after contract booking.'
));

// 21. Retention Specialist — Save Commission
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'Retention Specialist — Save Commission',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'Telecommunications',
    Status__c                 = 'Draft',
    Description__c            = 'Flat commission paid when a retention specialist successfully saves a customer from churning. Triggered on the renewed or re-signed contract booking.'
));

// =========================================================================
// SaaS Global additions (spec §9.7) (2)
// =========================================================================

// 22. SaaS Global Engineer — Deal Support
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS Global Engineer — Deal Support',
    Plan_Type__c              = 'Flat',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Global SE plan for cross-region deal support. Flat commission on bookings where the SE contributed technical expertise regardless of deal geography.'
));

// 23. SaaS RevOps VP — Global Override
templates.add(new Incentive_Plan_Template__c(
    Name                            = 'SaaS RevOps VP — Global Override',
    Plan_Type__c              = 'Team_Override',
    Trigger_Type__c           = 'Booking',
    Is_Library_Template__c    = true,
    Industry__c               = 'SaaS',
    Status__c                 = 'Draft',
    Description__c            = 'Global override for RevOps VP spanning all regions. Pays an override percentage on total organization bookings to reward global revenue leadership.'
));

// ----- Insert all templates --------------------------------------------------
insert templates;
System.debug('Inserted ' + templates.size() + ' Incentive_Plan_Template__c records.');

// =========================================================================
// Commission Tiers for "SaaS AE — Accelerated"
// =========================================================================

// Find the template we just inserted
Incentive_Plan_Template__c saasAE = [
    SELECT Id FROM Incentive_Plan_Template__c
    WHERE Name = 'SaaS AE — Accelerated'
      AND Is_Library_Template__c = true
    LIMIT 1
];

List<Commission_Tier__c> tiers = new List<Commission_Tier__c>();

// Tier 1: Base
tiers.add(new Commission_Tier__c(
    Plan_Template__c      = saasAE.Id,
    Tier_Name__c          = 'Base',
    Min_Attainment_Pct__c = 0,
    Max_Attainment_Pct__c = 100,
    Rate_Pct__c           = 8,
    Is_Retroactive__c     = false,
    Is_Active__c          = true,
    Sort_Order__c         = 1
));

// Tier 2: Accelerator
tiers.add(new Commission_Tier__c(
    Plan_Template__c      = saasAE.Id,
    Tier_Name__c          = 'Accelerator',
    Min_Attainment_Pct__c = 100,
    Max_Attainment_Pct__c = 150,
    Rate_Pct__c           = 12,
    Is_Retroactive__c     = true,
    Is_Active__c          = true,
    Sort_Order__c         = 2
));

// Tier 3: Super Accelerator
tiers.add(new Commission_Tier__c(
    Plan_Template__c      = saasAE.Id,
    Tier_Name__c          = 'Super Accelerator',
    Min_Attainment_Pct__c = 150,
    Max_Attainment_Pct__c = null,
    Rate_Pct__c           = 15,
    Is_Retroactive__c     = true,
    Is_Active__c          = true,
    Sort_Order__c         = 3
));

insert tiers;
System.debug('Inserted ' + tiers.size() + ' Commission_Tier__c records for SaaS AE — Accelerated.');
System.debug('seedIndustryTemplates.apex completed successfully.');
