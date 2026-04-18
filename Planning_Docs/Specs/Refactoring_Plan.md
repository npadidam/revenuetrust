Refactoring Plan: ForecastService SOQL Optimization & Architecture Hardening
Context
Phases A-D are deployed but the forecast grid fails to load due to SOQL governor limit violations. Root cause analysis identified:

101+ SOQL queries per grid load when horizon = "Quarter" (recursive aggregateAdditionalPeriodsIntoSummary calls queryForecastRecords per additional period)
38 SELECT statements in ForecastService.cls, many redundant
N+1 queries in loops at lines 989, 1006, 1031 (saveOverrides) and line 538 (display fields)
6 Phase C config fields missing FLS → getActiveConfig() silently failed → cascading retries
Group filtering via child object (OLI Product2Id) not joining correctly
The grid currently works ONLY with horizon = "Current_Period" (28 SOQL queries). Any multi-period horizon exceeds 100 queries.

Critical Fix: Immediate (before refactoring)
Group "Diesel" shows 0 records — The child object group filter (filterPipelineByGroup) likely doesn't match because it queries OLI Product2Id but the pipeline query returns Opportunities without OLI join. Need to verify and fix the group filtering path.
Refactoring Scope
R-1: Eliminate Horizon Recursion (~2 days)
Problem: aggregateAdditionalPeriodsIntoSummary() (line 3152) calls queryForecastRecords() recursively for each additional period. Quarter = 3× full query chain = 90+ queries.

Solution: Replace recursion with a single bulk query:

1. Load ALL periods in the horizon range upfront (1 SOQL)
2. Query pipeline for ALL periods in one SOQL with CloseDate range spanning the entire horizon
3. Group results in-memory by period
4. Compute per-period summaries without re-querying
   Files: ForecastService.cls — replace aggregateAdditionalPeriodsIntoSummary with bulkAggregateHorizonPeriods

R-2: Pre-load Supplementary Data with Maps (~2 days)
Problem: Inside queryForecastRecords, supplementary data (overrides, health scores, governance flags, previous level overrides, previous period overrides) is loaded via separate queries. The dedup, incentive, and child metric calls add more. Total: ~15 queries per page load.

Solution: Load ALL supplementary data in bulk BEFORE the record-building loop:

Map<Id, Forecast_Override**c> overridesByOppId // 1 query
Map<Id, Deal_Signal**c> healthByOppId // 1 query  
Map<Id, Governance_Event**c> govByOppId // 1 query
Map<Id, Forecast_Override**c> prevLevelByOppId // 1 query
Map<Id, Forecast_Override\_\_c> prevPeriodByOppId // 1 query
Map<Id, Decimal> dedupFactorsByOppId // 1 query
Then use O(1) map lookups inside the loop instead of per-record queries.

Files: ForecastService.cls, ForecastDataService.cls

R-3: Fix Save N+1 Queries (~1 day)
Problem: saveOverrides() (line 970 loop) makes 3 queries PER override being saved (lines 989, 1006, 1031):

Previous level override check
Previous period override link
Conflict detection
Solution: Pre-load all three datasets BEFORE the save loop:

Map<String, Id> prevLevelMap = [bulk query all relevant prev level overrides]
Map<String, Id> prevPeriodMap = [bulk query previous period overrides for all opps]
Map<Id, Override> existingMap = [bulk query for conflict detection]
Files: ForecastService.cls — refactor saveOverrides loop

R-4: Cache Display Field Configuration (~0.5 day)
Problem: buildPipelineFieldList() queries Forecast_Display_Field\_\_c every time it's called. loadConfig() also queries it separately. Two redundant SOQL calls.

Solution:

Cache display fields in the static cachedConfig subquery (add as a child relationship on Forecast_Configuration\_\_c)
OR load once in loadConfig() and pass through via parameter instead of re-querying
Files: ForecastDataService.cls, ForecastService.cls

R-5: Fix Group Filtering for Child Object Groups (~1 day)
Problem: Groups typed "Custom_Field" with Group_Source_Object\_\_c = 'OpportunityLineItem' need to filter opportunities by joining to the child object. Current filterPipelineByGroup may not handle this correctly.

Solution: For child object groups, use ChildObjectQueryService.findOpportunitiesByChildField() to get matching Opportunity IDs, then filter the pipeline result set.

Files: ForecastService.cls — filterPipelineByGroup method

R-6: Comprehensive FLS Audit (~0.5 day)
Problem: 6+ Phase C/D fields were missing FLS entries in permission sets, causing silent getActiveConfig() failures.

Solution:

Script to compare all field-meta.xml files against permission set entries
Add missing entries
Add a deployment validation test that checks FLS coverage
Files: All 3 permission sets, new test class FLSCoverageTest.cls

Target Query Budget
Operation Current Target
getForecastConfig (wire, cached) 1 1
getParticipantContext 8-12 5-6
getForecastRecords (Current Period) 25-50 12-15
getForecastRecords (Quarter horizon) 75-150 18-22
saveOverrides (10 records) 30+ 8-10
Build Order
R-5 (group filtering fix) — unblocks the user's immediate testing
R-1 (horizon recursion) — unblocks multi-period horizons
R-2 (supplementary data maps) — reduces base query count
R-3 (save N+1) — fixes save performance
R-4 (display field cache) — minor optimization
R-6 (FLS audit) — prevents silent failures
Estimated Effort: ~7 days
Verification
getForecastRecords with Current_Period: ≤15 SOQL
getForecastRecords with Quarter horizon: ≤25 SOQL
saveOverrides with 10 records: ≤12 SOQL
All 69+ existing Apex tests pass
Grid loads with "Diesel" group showing matching records
All config fields accessible (no silent FLS failures)
