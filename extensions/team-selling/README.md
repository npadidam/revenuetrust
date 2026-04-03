# RevenueTrust — Team Selling Extension

**Purpose:** Optional triggers for orgs with Team Selling / Opportunity Splits enabled.

## Prerequisites

- RevenueTrust managed package installed
- **Team Selling** enabled in Setup → Opportunity Settings
- **Opportunity Splits** configured (if using split-based commission tracking)

## What This Adds

| Trigger | Object | Events Published |
|---|---|---|
| `OpportunitySplitTrigger` | OpportunitySplit | SPLIT_CHANGED, SPLIT_CHANGED_POST_CLOSE |
| `OpportunityTeamMemberTrigger` | OpportunityTeamMember | TEAM_MEMBER_CHANGED, TEAM_MEMBER_CHANGED_POST_CLOSE |

These triggers call handler classes that are ALREADY included in the RevenueTrust managed package (`REVT.OpportunitySplitHandler` and `REVT.OpportunityTeamMemberHandler`). You're only deploying the trigger shells that connect the standard objects to the packaged handlers.

## Installation

### Option A: Deploy via SFDX CLI

```bash
sf project deploy start --source-dir extensions/team-selling --target-org <your-org-alias>
```

### Option B: Manual Creation

Create these triggers directly in your org via Setup → Apex Triggers:

**OpportunitySplitTrigger:**
```apex
trigger OpportunitySplitTrigger on OpportunitySplit (after insert, after update, after delete) {
    REVT.OpportunitySplitHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
```

**OpportunityTeamMemberTrigger:**
```apex
trigger OpportunityTeamMemberTrigger on OpportunityTeamMember (after insert, after update, after delete) {
    REVT.OpportunityTeamMemberHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
```

## Disabling

Use Trigger_Control__mdt (Custom Metadata) to disable these triggers without removing them:
- Set `REVT__Is_Enabled__c = false` on the `OpportunitySplitTrigger` or `OpportunityTeamMemberTrigger` record

## What Happens Without This Extension

If Team Selling is not enabled or this extension is not deployed:
- The RevenueTrust package works fully for all other event types (45 event types total)
- SPLIT_CHANGED and TEAM_MEMBER_CHANGED events simply don't fire
- Commission calculations based on deal ownership (OWNER_CHANGED) still work
- The `PARTICIPANT_SET_CHANGED` canonical handler still processes owner and territory changes
- No errors, no missing functionality — just fewer detection triggers
