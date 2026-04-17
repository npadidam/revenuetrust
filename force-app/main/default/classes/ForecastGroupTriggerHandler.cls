/**
 * @description Trigger handler for Forecast_Group__c.
 *              Restrict delete: blocks hard delete when active overrides reference the group.
 *              Admins should soft-delete via Is_Active__c = false instead.
 */
public with sharing class ForecastGroupTriggerHandler {
  /**
   * @description Block delete when active Forecast_Override__c records reference this group.
   */
  public static void handleBeforeDelete(List<Forecast_Group__c> oldList) {
    if (oldList == null || oldList.isEmpty())
      return;

    Set<Id> groupIds = new Set<Id>();
    for (Forecast_Group__c g : oldList) {
      groupIds.add(g.Id);
    }

    // Count overrides per group in one query
    Map<Id, Integer> overrideCountByGroup = new Map<Id, Integer>();
    for (AggregateResult ar : [
      SELECT Forecast_Group__c grpId, COUNT(Id) cnt
      FROM Forecast_Override__c
      WHERE Forecast_Group__c IN :groupIds
      GROUP BY Forecast_Group__c
    ]) {
      overrideCountByGroup.put((Id) ar.get('grpId'), (Integer) ar.get('cnt'));
    }

    for (Forecast_Group__c g : oldList) {
      Integer cnt = overrideCountByGroup.get(g.Id);
      if (cnt != null && cnt > 0) {
        g.addError(
          'Cannot delete this group: ' +
            cnt +
            ' override record(s) reference it. ' +
            'Set Is_Active = false to soft-delete (overrides preserved), or reassign/delete the overrides first.'
        );
      }
    }
  }
}
