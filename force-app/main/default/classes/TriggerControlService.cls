/**
 * @description Reads Trigger_Control__mdt to determine if a trigger is enabled.
 *              Caches results for the transaction to avoid repeated CMT queries.
 *              Admins disable triggers via Setup > Custom Metadata > Trigger Control
 *              without code deployment.
 */
public with sharing class TriggerControlService {
  // Cache: trigger name → enabled flag. Populated once per transaction.
  private static Map<String, Boolean> triggerStateCache;

  /**
   * @description Check if a trigger is enabled.
   * @param triggerName The DeveloperName / Trigger_Name__c value
   * @return true if enabled or if no CMT record exists (default = enabled)
   */
  public static Boolean isEnabled(String triggerName) {
    if (triggerStateCache == null) {
      loadCache();
    }
    // Default to enabled if no record found — fail-open so missing config
    // doesn't silently disable functionality
    if (!triggerStateCache.containsKey(triggerName)) {
      return true;
    }
    return triggerStateCache.get(triggerName);
  }

  /**
   * @description Bulk load all Trigger_Control__mdt records into cache.
   *              CMT queries don't count against SOQL limits.
   */
  private static void loadCache() {
    triggerStateCache = new Map<String, Boolean>();
    for (Trigger_Control__mdt tc : Trigger_Control__mdt.getAll().values()) {
      triggerStateCache.put(tc.Trigger_Name__c, tc.Is_Enabled__c);
    }
  }

  /**
   * @description Force cache reload. Used in tests.
   */
  @TestVisible
  private static void clearCache() {
    triggerStateCache = null;
  }

  /**
   * @description Disable a specific trigger in the cache. Used in tests and
   *              seed scripts to prevent trigger execution during data setup.
   */
  public static void disableTrigger(String triggerName) {
    if (triggerStateCache == null) {
      triggerStateCache = new Map<String, Boolean>();
    }
    triggerStateCache.put(triggerName, false);
  }
}
