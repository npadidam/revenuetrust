// ============================================================================
// seedCalculationTemplates.apex
// Inserts 10 Calculation_Template__c library records per Incentives spec §11.12.
//
// Run via:  sf apex run --file scripts/apex/seedCalculationTemplates.apex
// Idempotent: deletes existing library templates before re-inserting.
// ============================================================================

// ----- Cleanup existing library calculation templates ------------------------
delete [SELECT Id FROM Calculation_Template__c
        WHERE Is_Library__c = true];

List<Calculation_Template__c> calcTemplates = new List<Calculation_Template__c>();

// =========================================================================
// 1. Flat Rate
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Flat Rate',
    Plan_Type__c          = 'Flat',
    Is_Library__c         = true,
    Industry__c           = 'SaaS',
    Description__c        = 'Simple flat-rate commission calculated as deal value multiplied by a fixed rate. No tiers, no attainment thresholds. Suitable for straightforward transactional roles.',
    Calculation_Steps__c  =
        '1. Identify the commissionable deal value (booking amount or collected revenue).\n' +
        '2. Look up the flat commission rate from the comp plan (e.g., 8%).\n' +
        '3. Calculate: commission = commissionable_value × rate.\n' +
        '4. Apply any caps or minimum thresholds if configured.\n' +
        '5. Record the commission event with the calculated amount.',
    Example_Scenario__c   =
        'Scenario: SE with 5% flat rate on supported deals.\n\n' +
        'Deal 1: $200K booking → commission = $200K × 5% = $10,000\n' +
        'Deal 2: $150K booking → commission = $150K × 5% = $7,500\n' +
        'Deal 3: $80K booking  → commission = $80K × 5%  = $4,000\n\n' +
        'Total period commission: $21,500\n' +
        'Each deal is independent — no attainment tracking required.'
));

// =========================================================================
// 2. Tiered (Banded)
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Tiered (Banded)',
    Plan_Type__c          = 'Tiered',
    Is_Library__c         = true,
    Industry__c           = 'Insurance',
    Description__c        = 'Banded tier commission where different rate bands apply to incremental value ranges. Each dollar is commissioned at the rate of the band it falls into, not retroactively.',
    Calculation_Steps__c  =
        '1. Determine cumulative commissionable value for the period.\n' +
        '2. Load tier definitions sorted by Min threshold ascending.\n' +
        '3. For each tier, calculate the portion of value falling within [Min, Max).\n' +
        '   portion = MIN(cumulative_value, tier_max) - tier_min (clamped to 0).\n' +
        '4. Multiply each portion by the tier rate: tier_commission = portion × tier_rate.\n' +
        '5. Sum all tier commissions: total = SUM(tier_commission).\n' +
        '6. Attribute the incremental commission from this deal vs. previous cumulative.',
    Example_Scenario__c   =
        'Scenario: Insurance agent with 3 tiers on annual premium volume.\n' +
        'Tier 1: $0–$500K at 10%\n' +
        'Tier 2: $500K–$1M at 12%\n' +
        'Tier 3: $1M+ at 15%\n\n' +
        'Agent writes $1.2M in annual premium:\n' +
        '  Tier 1: $500K × 10% = $50,000\n' +
        '  Tier 2: $500K × 12% = $60,000\n' +
        '  Tier 3: $200K × 15% = $30,000\n\n' +
        'Total commission: $140,000\n' +
        'Effective blended rate: 11.67%'
));

// =========================================================================
// 3. Accelerated (Retroactive)
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Accelerated (Retroactive)',
    Plan_Type__c          = 'Accelerated',
    Is_Library__c         = true,
    Industry__c           = 'SaaS',
    Description__c        = 'Accelerated commission with retroactive uplift. Below quota, a base rate applies. Once the rep crosses the attainment threshold, the higher rate applies retroactively to ALL prior deals in the period.',
    Calculation_Steps__c  =
        '1. Track cumulative attainment % = (cumulative_bookings / quota) × 100.\n' +
        '2. For each new deal, recalculate cumulative attainment.\n' +
        '3. If attainment < threshold (e.g., 100%), apply base rate to this deal.\n' +
        '4. If attainment >= threshold:\n' +
        '   a. Apply accelerated rate to the current deal.\n' +
        '   b. Calculate retroactive uplift on ALL prior deals in period:\n' +
        '      uplift = prior_cumulative_value × (accelerated_rate - base_rate).\n' +
        '   c. Record the uplift as a separate commission adjustment.\n' +
        '5. For subsequent deals above threshold, apply accelerated rate directly.\n' +
        '6. If multiple accelerator tiers exist, repeat step 4 at each new threshold.',
    Example_Scenario__c   =
        'Scenario: AE with $1M annual quota, 8% base rate, 12% accelerator at 100%+\n\n' +
        'Q1: Closes $300K → attainment 30% → 8% → commission $24K\n' +
        'Q2: Closes $400K → attainment 70% → 8% → commission $32K\n' +
        'Q3: Closes $350K → attainment 105% → CROSSES THRESHOLD\n' +
        '     → This deal at 12% = $42K\n' +
        '     → Retroactive uplift on Q1+Q2: ($300K+$400K) × (12%-8%) = $28K\n' +
        '     → Total Q3 = $42K + $28K = $70K\n\n' +
        'Total: $24K + $32K + $70K = $126K\n' +
        'vs. without retroactive: $24K + $32K + $42K = $98K\n' +
        'Retroactive bonus: $28K'
));

// =========================================================================
// 4. Gross Margin
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Gross Margin',
    Plan_Type__c          = 'Gross_Margin',
    Is_Library__c         = true,
    Industry__c           = 'Manufacturing',
    Description__c        = 'Commission based on gross margin (revenue minus cost of goods sold) rather than top-line revenue. Incentivizes profitable deal structuring and discourages excessive discounting.',
    Calculation_Steps__c  =
        '1. Retrieve deal revenue and COGS from the opportunity or order.\n' +
        '2. Calculate gross margin: margin = revenue - COGS.\n' +
        '3. If margin <= 0, commission = 0 (no payout on negative-margin deals).\n' +
        '4. Apply the gross margin commission rate: commission = margin × rate.\n' +
        '5. Optionally apply a margin floor: if margin % < minimum (e.g., 20%),\n' +
        '   reduce rate or apply penalty multiplier.\n' +
        '6. Record commission with both revenue and margin for audit trail.',
    Example_Scenario__c   =
        'Scenario: Sales engineer with 15% commission on gross margin.\n\n' +
        'Deal 1: Revenue $500K, COGS $300K → margin $200K → commission = $200K × 15% = $30,000\n' +
        'Deal 2: Revenue $300K, COGS $100K → margin $200K → commission = $200K × 15% = $30,000\n' +
        'Deal 3: Revenue $400K, COGS $350K → margin $50K  → commission = $50K × 15%  = $7,500\n\n' +
        'Total commission: $67,500\n' +
        'Note: Deal 1 and Deal 2 have the same margin despite different revenue —\n' +
        'the rep is rewarded equally for both. Deal 3 shows how heavy discounting\n' +
        'reduces the commission significantly.'
));

// =========================================================================
// 5. Recurring / Trail
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Recurring / Trail',
    Plan_Type__c          = 'Recurring',
    Is_Library__c         = true,
    Industry__c           = 'Financial_Services',
    Description__c        = 'Ongoing trail commission paid periodically on active recurring value (e.g., AUM, MRR, or policy premium). Commission stops automatically upon churn or cancellation.',
    Calculation_Steps__c  =
        '1. At each cadence interval (monthly, quarterly, annually), snapshot active value.\n' +
        '2. Verify the account/contract is still active (not churned or cancelled).\n' +
        '3. If active: monthly_commission = active_value × trail_rate.\n' +
        '4. If churned: stop future commission accruals from the churn effective date.\n' +
        '5. If duration-limited (e.g., 12 months), check elapsed months since booking.\n' +
        '   Stop accruals after duration expires.\n' +
        '6. Record each periodic commission as a separate calculation event.',
    Example_Scenario__c   =
        'Scenario: Financial advisor with 0.25% quarterly trail on AUM.\n\n' +
        'Client portfolio: $2M AUM\n' +
        'Q1: Active → $2M × 0.25% = $5,000\n' +
        'Q2: AUM grows to $2.2M → $2.2M × 0.25% = $5,500\n' +
        'Q3: AUM drops to $1.8M → $1.8M × 0.25% = $4,500\n' +
        'Q4: Client churns mid-quarter → prorated: $1.8M × 0.25% × (2/3) = $3,000\n\n' +
        'Annual trail commission: $5,000 + $5,500 + $4,500 + $3,000 = $18,000\n' +
        'No further payments after churn.'
));

// =========================================================================
// 6. Activity Count
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Activity Count',
    Plan_Type__c          = 'Activity_Based',
    Is_Library__c         = true,
    Industry__c           = 'SaaS',
    Description__c        = 'Commission based on the count of qualifying activities (meetings, demos, calls) multiplied by a fixed rate per activity. Subject to caps and minimum qualification criteria.',
    Calculation_Steps__c  =
        '1. Query qualifying activities for the period matching criteria\n' +
        '   (e.g., meeting held, demo completed, minimum duration met).\n' +
        '2. Filter out disqualified activities (cancelled, no-show, duplicate).\n' +
        '3. Count qualifying activities.\n' +
        '4. Calculate: commission = qualifying_count × rate_per_activity.\n' +
        '5. Apply period cap if configured: commission = MIN(commission, cap_amount).\n' +
        '6. Record each qualifying activity ID for audit linkage.',
    Example_Scenario__c   =
        'Scenario: BDR with $150 per qualified meeting, capped at $6,000/month.\n\n' +
        'Month 1: 35 meetings set, 30 qualified → 30 × $150 = $4,500\n' +
        'Month 2: 50 meetings set, 45 qualified → 45 × $150 = $6,750 → CAPPED at $6,000\n' +
        'Month 3: 20 meetings set, 18 qualified → 18 × $150 = $2,700\n\n' +
        'Quarterly total: $4,500 + $6,000 + $2,700 = $13,200\n' +
        'Note: Month 2 hit the cap — 5 qualified meetings produced no additional payout.'
));

// =========================================================================
// 7. Team Override
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Team Override',
    Plan_Type__c          = 'Team_Override',
    Is_Library__c         = true,
    Industry__c           = 'SaaS',
    Description__c        = 'Manager override commission calculated as a percentage of total team production. Only pays if team attainment exceeds a configurable threshold, ensuring managers are rewarded for team-level success.',
    Calculation_Steps__c  =
        '1. Aggregate total commissionable value across all team members for the period.\n' +
        '2. Calculate team attainment: team_attainment = team_total / team_quota.\n' +
        '3. Check if team_attainment >= threshold (e.g., 80%).\n' +
        '4. If below threshold: commission = 0 (override does not pay).\n' +
        '5. If above threshold: commission = team_total × override_rate.\n' +
        '6. Optionally apply accelerators if team exceeds higher thresholds.',
    Example_Scenario__c   =
        'Scenario: Sales manager with 3% override, 80% team attainment threshold.\n' +
        'Team quota: $5M, 6 reps.\n\n' +
        'Q1: Team closes $3.5M → attainment 70% → below 80% threshold → $0\n' +
        'Q2: Team closes $4.5M → attainment 90% → above threshold → $4.5M × 3% = $135,000\n' +
        'Q3: Team closes $5.5M → attainment 110% → $5.5M × 3% = $165,000\n' +
        'Q4: Team closes $4.2M → attainment 84% → $4.2M × 3% = $126,000\n\n' +
        'Annual override: $0 + $135K + $165K + $126K = $426,000\n' +
        'Q1 miss cost the manager $105K in potential override.'
));

// =========================================================================
// 8. Team Pool
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Team Pool',
    Plan_Type__c          = 'Team_Pool',
    Is_Library__c         = true,
    Industry__c           = 'Real_Estate',
    Description__c        = 'Shared bonus pool generated from total team production. The pool amount is calculated at a set rate, then distributed pro-rata among team members based on individual contribution.',
    Calculation_Steps__c  =
        '1. Aggregate total team production (bookings) for the period.\n' +
        '2. Calculate pool amount: pool = team_production × pool_rate.\n' +
        '3. For each team member, calculate their contribution percentage:\n' +
        '   member_pct = member_production / team_production.\n' +
        '4. Distribute pool pro-rata: member_share = pool × member_pct.\n' +
        '5. Optionally apply minimum/maximum individual share limits.\n' +
        '6. Record each member\'s pool share as a commission event.',
    Example_Scenario__c   =
        'Scenario: Real estate team with 2% pool rate on team production.\n\n' +
        'Team production: $10M in closed transactions.\n' +
        'Pool = $10M × 2% = $200,000\n\n' +
        'Distribution:\n' +
        '  Agent A: $4M production (40%) → $200K × 40% = $80,000\n' +
        '  Agent B: $3M production (30%) → $200K × 30% = $60,000\n' +
        '  Agent C: $2M production (20%) → $200K × 20% = $40,000\n' +
        '  Agent D: $1M production (10%) → $200K × 10% = $20,000\n\n' +
        'Total distributed: $200,000\n' +
        'This is in addition to each agent\'s individual transaction commission.'
));

// =========================================================================
// 9. Milestone Staged
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Milestone Staged',
    Plan_Type__c          = 'Milestone',
    Is_Library__c         = true,
    Industry__c           = 'Insurance',
    Description__c        = 'Commission payout split across multiple project or deal milestones. Specified percentages are released at each milestone event (e.g., contract signing, go-live, retention period completion).',
    Calculation_Steps__c  =
        '1. Calculate total potential commission: total = deal_value × rate.\n' +
        '2. Define milestone payout splits (must sum to 100%):\n' +
        '   e.g., 40% at contract, 40% at go-live, 20% at 90-day retention.\n' +
        '3. When a milestone event fires:\n' +
        '   a. Verify milestone completion criteria are met.\n' +
        '   b. Calculate milestone payout: payout = total × milestone_pct.\n' +
        '   c. Record the partial commission event.\n' +
        '4. Track remaining unpaid milestones for the deal.\n' +
        '5. If deal is cancelled before all milestones, remaining payouts are forfeited.\n' +
        '6. Optionally trigger clawback on already-paid milestones if cancellation occurs.',
    Example_Scenario__c   =
        'Scenario: Implementation deal with 10% commission, staged 40/40/20.\n' +
        'Deal value: $500K → total commission potential: $50,000\n\n' +
        'Milestone 1 — Contract signed (Jan 15):\n' +
        '  Payout: $50K × 40% = $20,000 ✓ Paid\n\n' +
        'Milestone 2 — Go-live (Mar 1):\n' +
        '  Payout: $50K × 40% = $20,000 ✓ Paid\n\n' +
        'Milestone 3 — 90-day retention (Jun 1):\n' +
        '  Payout: $50K × 20% = $10,000 ✓ Paid\n\n' +
        'Total paid: $50,000 across 5 months.\n' +
        'If client churned before go-live, only $20K would have been paid\n' +
        'and the remaining $30K would be forfeited.'
));

// =========================================================================
// 10. Revenue Recognition
// =========================================================================
calcTemplates.add(new Calculation_Template__c(
    Name                        = 'Revenue Recognition',
    Plan_Type__c          = 'Flat',
    Is_Library__c         = true,
    Industry__c           = 'Financial_Services',
    Description__c        = 'Commission triggered by revenue recognition events rather than bookings. Payouts are spread across fiscal periods aligned with ASC 606 / IFRS 15 recognition schedules.',
    Calculation_Steps__c  =
        '1. When a rev rec event fires, retrieve the recognized revenue amount\n' +
        '   and the associated deal/contract.\n' +
        '2. Look up the commission rate for the deal\'s comp plan.\n' +
        '3. Calculate: commission = recognized_amount × rate.\n' +
        '4. Map the commission to the fiscal period in which recognition occurred.\n' +
        '5. If the deal spans multiple fiscal years, each recognition event\n' +
        '   triggers a separate commission calculation in its respective period.\n' +
        '6. Track total recognized vs. total deal value to ensure\n' +
        '   cumulative commission does not exceed deal-level cap.',
    Example_Scenario__c   =
        'Scenario: 3-year $600K contract, recognized ratably, 5% commission rate.\n' +
        'Annual recognition: $200K/year → monthly recognition: ~$16,667\n\n' +
        'FY2026:\n' +
        '  12 months × $16,667 × 5% = $10,000 commission\n\n' +
        'FY2027:\n' +
        '  12 months × $16,667 × 5% = $10,000 commission\n\n' +
        'FY2028:\n' +
        '  12 months × $16,667 × 5% = $10,000 commission\n\n' +
        'Total over contract life: $30,000\n' +
        'Same as booking-based ($600K × 5% = $30K) but spread across 3 fiscal years.\n' +
        'If client cancels after Year 1, only $10K is paid — no clawback needed\n' +
        'since commission was tied to recognized (earned) revenue.'
));

// ----- Insert all calculation templates --------------------------------------
insert calcTemplates;
System.debug('Inserted ' + calcTemplates.size() + ' Calculation_Template__c records.');
System.debug('seedCalculationTemplates.apex completed successfully.');
