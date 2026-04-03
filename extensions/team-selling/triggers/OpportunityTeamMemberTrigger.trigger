/**
 * @description Extension trigger for OpportunityTeamMember (requires Team Selling).
 *              NOT part of the RevenueTrust managed package — deployed separately
 *              in subscriber orgs that have Team Selling enabled.
 *              Calls the packaged handler via namespace reference.
 */
trigger OpportunityTeamMemberTrigger on OpportunityTeamMember (after insert, after update, after delete) {
    REVT.OpportunityTeamMemberHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
