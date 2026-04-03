/**
 * @description Extension trigger for OpportunitySplit (requires Team Selling).
 *              NOT part of the RevenueTrust managed package — deployed separately
 *              in subscriber orgs that have Team Selling enabled.
 *              Calls the packaged handler via namespace reference.
 */
trigger OpportunitySplitTrigger on OpportunitySplit (after insert, after update, after delete) {
    REVT.OpportunitySplitHandler.handleChange(Trigger.new, Trigger.old, Trigger.operationType);
}
