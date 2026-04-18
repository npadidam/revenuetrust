What still needs cleanup before I would call it fully locked:

1. Auto-freeze timezone wording is still internally inconsistent.
   The policy table says “23:59:59 UTC on the deadline day,” then immediately says non-UTC orgs use the org default timezone via TimeZone.getTimeZone(UserInfo.getTimeZone().getID()). Those are not the same thing, and the implementation reference is also suspect because UserInfo.getTimeZone() is user-context oriented, not a clean expression of “org timezone.” Later in risk mitigations you say “runs at 23:59:59 in org TZ,” which is the correct business behavior.
   This should be rewritten to one deterministic rule:
   “Auto-freeze executes at 23:59:59 in the forecast configuration/org timezone on the deadline day.”
   Right now the section says two different things.
2. One date example appears wrong.
   In the bi-weekly anchor example, if anchor = 2026-04-16 and that is labeled Wednesday, that date is actually Thursday. Also the first matching Friday after April 16, 2026 should be April 17, not April 18.
   This is small, but it is exactly the kind of thing that causes confusion in specs. Fix the example.
3. Idempotency key for summaries vs snapshots should be separated explicitly.
   You define one unique key for Forecast_Snapshot**c-style batch behavior and another for Forecast_Summary_History**c, which is good, but the text could still be cleaner in naming. Right now “Unique key” appears in multiple places and can blur object boundaries.
   I would name them explicitly:
   Snapshot unique key,
   Summary history unique key.
4. History pruning rule conflicts slightly with retention wording.
   You cap history at 52 per summary, then say retention weekly = 1 year, bi-weekly = 2 years, monthly = 4+ years. That is mathematically true only because lower-frequency cadences generate fewer rows, but the text could sound like a policy by cadence instead of a consequence of the 52-row cap.
   Not a real flaw, just clarify that 52 is the universal cap and effective time coverage varies by cadence.
5. “Last write wins” is acceptable, but you may want one extra governance note.
   For manager override conflicts, last write wins is fine for v1, but it would help to say whether users receive a visible audit hint when someone else overwrites an existing override. Since you already store Override_By**c and Override_Date**c, this is easy to support later.
   This is optional, not blocking.
6. Child text aggregation default is practical but may surprise admins.
   “First non-null by CreatedDate ASC” is implementable, but for text/picklist child fields it can be semantically arbitrary. It is acceptable for Phase D because you explicitly label it as default-only and future-configurable. Still, I would add one sentence in admin help text saying child-object values may be aggregated.

NEW Issue A: Summary_All_Metrics**c field not in the field count (Medium — Spec Consistency)
Line 327 introduces a new config flag: Summary_All_Metrics**c (Checkbox, default false) on Forecast_Configuration**c to control whether non-primary metric summaries are persisted. But the field count update (lines 15, 468) says "24 → 28" accounting for only 4 fields (3 cadence + 1 anchor). With Summary_All_Metrics**c, the actual total should be 29.
Either add this to the count (24 → 29), or clarify that Summary_All_Metrics**c lives somewhere other than Forecast_Configuration**c.

Residual Clarifications (non-blocking, can resolve during build)
Clarification 1: Nightly snapshots and cadence coexistence. The frozen spec defines a Nightly snapshot type that runs every night. Phase D introduces the Cadence snapshot batch running daily. On a cadence day, both would fire — creating a Nightly snapshot AND a Cadence snapshot for the same date. This is technically fine (different Snapshot_Type**c values pass the idempotency check), but it's worth confirming that the nightly batch is still desired for cadence-enabled orgs. If the cadence batch subsumes the nightly's purpose, the nightly could be suppressed for orgs with Forecast_Cadence**c set — reducing snapshot storage volume.
Clarification 2: Forecast_Summary_History\_\_c unique key enforcement mechanism. Line 238 says "enforced via duplicate rule or before-insert trigger" — picking one during build is fine, but note that Salesforce duplicate rules don't support Master-Detail + Date + Picklist composite matching natively. A before-insert trigger checking for existing records is the more reliable path. Not a spec gap, just an implementation nudge.
