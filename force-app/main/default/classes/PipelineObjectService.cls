/**
 * @description Abstracts access to the commissionable pipeline record.
 *              Reads Field_Mapping__mdt to know which fields to query on which object.
 *              All commission engine code calls this service instead of querying
 *              Opportunity directly.
 *
 *              Supports: Opportunity, Order, Contract, Quote, or any custom object
 *              configured in Incentive_Configuration__c.Pipeline_Object__c
 */
public with sharing class PipelineObjectService {

    // Cached config
    private static String pipelineObjectName;
    private static Map<String, String> fieldMappings; // logical → physical
    private static Boolean configLoaded = false;

    /**
     * Get the configured pipeline object API name.
     * Default: 'Opportunity' if not configured.
     */
    public static String getPipelineObjectName() {
        loadConfig();
        return pipelineObjectName;
    }

    /**
     * Query a single pipeline record with all mapped fields.
     * Returns an SObject (could be Opportunity, Order, or any custom object).
     */
    public static SObject queryRecord(Id recordId) {
        loadConfig();
        String fields = buildFieldList();
        String query = 'SELECT ' + fields + ' FROM ' + pipelineObjectName
                      + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> results = Database.query(query);
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Query multiple pipeline records by IDs.
     */
    public static List<SObject> queryRecords(Set<Id> recordIds) {
        loadConfig();
        String fields = buildFieldList();
        String query = 'SELECT ' + fields + ' FROM ' + pipelineObjectName
                      + ' WHERE Id IN :recordIds';
        return Database.query(query);
    }

    /**
     * Query pipeline records by owner (for participant identification).
     */
    public static List<SObject> queryByOwner(Id ownerId) {
        loadConfig();
        String fields = buildFieldList();
        String ownerField = getPhysicalField('Pipeline.Owner');
        String query = 'SELECT ' + fields + ' FROM ' + pipelineObjectName
                      + ' WHERE ' + ownerField + ' = :ownerId';
        return Database.query(query);
    }

    /**
     * Get a logical field value from a pipeline record.
     * Example: getFieldValue(record, 'Pipeline.Amount') returns the value
     * of whatever field is mapped as the Amount field.
     */
    public static Object getFieldValue(SObject record, String logicalName) {
        loadConfig();
        String physicalField = getPhysicalField(logicalName);
        if (physicalField == null) {
            return null;
        }
        try {
            return record.get(physicalField);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Get the amount value from a pipeline record.
     * Convenience method for the most common lookup.
     */
    public static Decimal getAmount(SObject record) {
        Object val = getFieldValue(record, 'Pipeline.Amount');
        if (val instanceof Decimal) {
            return (Decimal) val;
        }
        if (val != null) {
            try {
                return Decimal.valueOf(String.valueOf(val));
            } catch (Exception e) {
                return 0;
            }
        }
        return 0;
    }

    /**
     * Get the owner ID from a pipeline record.
     */
    public static Id getOwnerId(SObject record) {
        Object val = getFieldValue(record, 'Pipeline.Owner');
        return val instanceof Id ? (Id) val : null;
    }

    /**
     * Get the stage/status from a pipeline record.
     */
    public static String getStage(SObject record) {
        Object val = getFieldValue(record, 'Pipeline.Stage');
        return val != null ? String.valueOf(val) : null;
    }

    /**
     * Get the close date from a pipeline record.
     */
    public static Date getCloseDate(SObject record) {
        Object val = getFieldValue(record, 'Pipeline.CloseDate');
        if (val instanceof Date) {
            return (Date) val;
        }
        if (val instanceof Datetime) {
            return ((Datetime) val).date();
        }
        return null;
    }

    /**
     * Get a custom/dynamic field value by physical API name.
     * Used by Commissionable_Value_Map__c resolution.
     */
    public static Object getDynamicField(SObject record, String fieldApiName) {
        try {
            return record.get(fieldApiName);
        } catch (Exception e) {
            return null;
        }
    }

    // ── Config loading ──────────────────────────────────────────────────

    private static void loadConfig() {
        if (configLoaded) {
            return;
        }
        configLoaded = true;

        // Default
        pipelineObjectName = 'Opportunity';
        fieldMappings = new Map<String, String>();

        // Load from Incentive_Configuration__c
        List<Incentive_Configuration__c> configs = [
            SELECT Pipeline_Object__c FROM Incentive_Configuration__c
            WHERE Is_Active__c = true LIMIT 1
        ];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Pipeline_Object__c)) {
            pipelineObjectName = configs[0].Pipeline_Object__c;
        }

        // Load field mappings
        for (Field_Mapping__mdt mapping : Field_Mapping__mdt.getAll().values()) {
            if (mapping.Object_API_Name__c == pipelineObjectName ||
                mapping.Logical_Name__c.startsWith('Pipeline.')) {
                fieldMappings.put(mapping.Logical_Name__c, mapping.Field_API_Name__c);
            }
        }

        // Default mappings for Opportunity if no custom mappings exist
        if (fieldMappings.isEmpty() && pipelineObjectName == 'Opportunity') {
            fieldMappings.put('Pipeline.Amount', 'Amount');
            fieldMappings.put('Pipeline.CloseDate', 'CloseDate');
            fieldMappings.put('Pipeline.Stage', 'StageName');
            fieldMappings.put('Pipeline.Owner', 'OwnerId');
            fieldMappings.put('Pipeline.Name', 'Name');
            fieldMappings.put('Pipeline.Type', 'Type');
        }
    }

    private static String getPhysicalField(String logicalName) {
        return fieldMappings.containsKey(logicalName) ? fieldMappings.get(logicalName) : null;
    }

    private static String buildFieldList() {
        Set<String> fields = new Set<String>{'Id'};
        fields.addAll(fieldMappings.values());
        return String.join(new List<String>(fields), ', ');
    }

    @TestVisible
    private static void resetConfig() {
        configLoaded = false;
        pipelineObjectName = null;
        fieldMappings = null;
    }
}
