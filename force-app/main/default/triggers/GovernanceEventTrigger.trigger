/**
 * @description Trigger on Governance_Eval_Event__e — delegates to GovernanceEventHandler.
 */
trigger GovernanceEventTrigger on Governance_Eval_Event__e (after insert) {
    new GovernanceEventHandler().handle(Trigger.new);
}
