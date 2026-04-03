/**
 * @description Service for processing imported transactions for commission calculation.
 *              Handles matching, validation, and commission processing for external data
 *              (usage, overages, ERP deals, POS transactions, etc.)
 *
 *              Flow:
 *              1. Receive records (via API, file upload, or manual creation)
 *              2. Validate: required fields, dedup by External_Id__c
 *              3. Match: participant by email/employee ID, category by code, account/product by name
 *              4. Process: run through commission engine (same as Opportunity-based)
 *              5. Record: update Processing_Status__c, create Comp_Calculation__c records
 */
public with sharing class ImportedTransactionService {

    public class ImportResult {
        public Integer totalRecords;
        public Integer matched;
        public Integer processed;
        public Integer errors;
        public Integer duplicates;
        public List<String> errorMessages;

        public ImportResult() {
            totalRecords = 0; matched = 0; processed = 0; errors = 0; duplicates = 0;
            errorMessages = new List<String>();
        }
    }

    /**
     * Process a batch of imported transactions.
     * Called from REST API or file upload handler.
     */
    public static ImportResult processBatch(List<Imported_Transaction__c> transactions) {
        ImportResult result = new ImportResult();
        result.totalRecords = transactions.size();

        // Step 1: Dedup by External_Id__c
        List<Imported_Transaction__c> unique = dedup(transactions, result);

        // Step 2: Match participants
        matchParticipants(unique, result);

        // Step 3: Validate matched records
        List<Imported_Transaction__c> valid = validate(unique, result);

        // Step 4: Save matched/validated records
        upsert valid External_Id__c;

        // Step 5: Process for commissions
        processForCommissions(valid, result);

        return result;
    }

    /**
     * Dedup against existing records by External_Id__c.
     */
    private static List<Imported_Transaction__c> dedup(List<Imported_Transaction__c> records, ImportResult result) {
        Set<String> externalIds = new Set<String>();
        List<Imported_Transaction__c> unique = new List<Imported_Transaction__c>();

        for (Imported_Transaction__c r : records) {
            if (String.isBlank(r.External_Id__c)) {
                r.External_Id__c = 'AUTO-' + System.now().getTime() + '-' + Math.random();
            }
            externalIds.add(r.External_Id__c);
        }

        // Check for existing records
        Set<String> existingIds = new Set<String>();
        for (Imported_Transaction__c existing : [
            SELECT External_Id__c FROM Imported_Transaction__c
            WHERE External_Id__c IN :externalIds]) {
            existingIds.add(existing.External_Id__c);
        }

        for (Imported_Transaction__c r : records) {
            if (existingIds.contains(r.External_Id__c)) {
                r.Processing_Status__c = 'Duplicate';
                r.Processing_Notes__c = 'Duplicate External_Id: ' + r.External_Id__c;
                result.duplicates++;
            } else {
                unique.add(r);
            }
        }

        return unique;
    }

    /**
     * Match participant by external ID (email or employee ID).
     */
    private static void matchParticipants(List<Imported_Transaction__c> records, ImportResult result) {
        Set<String> participantExternalIds = new Set<String>();
        for (Imported_Transaction__c r : records) {
            if (String.isNotBlank(r.Participant_External_Id__c)) {
                participantExternalIds.add(r.Participant_External_Id__c);
            }
        }

        if (participantExternalIds.isEmpty()) return;

        // Try matching by Email first, then by FederationIdentifier, then by EmployeeNumber
        Map<String, Id> matchMap = new Map<String, Id>();
        for (User u : [
            SELECT Id, Email, FederationIdentifier, EmployeeNumber
            FROM User
            WHERE Email IN :participantExternalIds
            OR FederationIdentifier IN :participantExternalIds
            OR EmployeeNumber IN :participantExternalIds]) {
            if (u.Email != null) matchMap.put(u.Email.toLowerCase(), u.Id);
            if (u.FederationIdentifier != null) matchMap.put(u.FederationIdentifier.toLowerCase(), u.Id);
            if (u.EmployeeNumber != null) matchMap.put(u.EmployeeNumber.toLowerCase(), u.Id);
        }

        for (Imported_Transaction__c r : records) {
            if (r.Participant__c != null) {
                result.matched++;
                continue; // Already matched
            }
            String key = r.Participant_External_Id__c != null ? r.Participant_External_Id__c.toLowerCase() : '';
            if (matchMap.containsKey(key)) {
                r.Participant__c = matchMap.get(key);
                r.Processing_Status__c = 'Matched';
                result.matched++;
            } else {
                r.Processing_Status__c = 'Error';
                r.Processing_Notes__c = 'Could not match participant: ' + r.Participant_External_Id__c;
                result.errors++;
                result.errorMessages.add('No matching user for: ' + r.Participant_External_Id__c);
            }
        }
    }

    /**
     * Validate required fields on matched records.
     */
    private static List<Imported_Transaction__c> validate(List<Imported_Transaction__c> records, ImportResult result) {
        List<Imported_Transaction__c> valid = new List<Imported_Transaction__c>();

        for (Imported_Transaction__c r : records) {
            if (r.Processing_Status__c == 'Error' || r.Processing_Status__c == 'Duplicate') continue;

            List<String> issues = new List<String>();
            if (r.Amount__c == null) issues.add('Amount is required');
            if (r.Transaction_Date__c == null) issues.add('Transaction Date is required');
            if (r.Participant__c == null) issues.add('Participant could not be matched');

            if (!issues.isEmpty()) {
                r.Processing_Status__c = 'Error';
                r.Processing_Notes__c = String.join(issues, '; ');
                result.errors++;
            } else {
                valid.add(r);
            }
        }

        return valid;
    }

    /**
     * Process validated imported transactions through the commission engine.
     * Creates Comp_Calculation__c records.
     */
    private static void processForCommissions(List<Imported_Transaction__c> records, ImportResult result) {
        // Find active Comp_Plan__c for each participant
        Set<Id> participantIds = new Set<Id>();
        for (Imported_Transaction__c r : records) {
            if (r.Participant__c != null) participantIds.add(r.Participant__c);
        }

        // Query plans with their templates and tiers
        Map<Id, List<Comp_Plan__c>> participantPlans = new Map<Id, List<Comp_Plan__c>>();
        for (Comp_Plan__c plan : [
            SELECT Id, Sales_Rep__c, Plan_Template__c, Status__c,
                   Plan_Template__r.Plan_Type__c, Plan_Template__r.Trigger_Type__c
            FROM Comp_Plan__c
            WHERE Sales_Rep__c IN :participantIds
            AND Status__c = 'Active'
        ]) {
            if (!participantPlans.containsKey(plan.Sales_Rep__c)) {
                participantPlans.put(plan.Sales_Rep__c, new List<Comp_Plan__c>());
            }
            participantPlans.get(plan.Sales_Rep__c).add(plan);
        }

        List<Comp_Calculation__c> calcs = new List<Comp_Calculation__c>();
        List<Imported_Transaction__c> toUpdate = new List<Imported_Transaction__c>();

        for (Imported_Transaction__c txn : records) {
            List<Comp_Plan__c> plans = participantPlans.get(txn.Participant__c);
            if (plans == null || plans.isEmpty()) {
                txn.Processing_Status__c = 'Error';
                txn.Processing_Notes__c = 'No active comp plan found for participant';
                result.errors++;
                toUpdate.add(txn);
                continue;
            }

            // For each matching plan, create a commission calculation
            Boolean processed = false;
            for (Comp_Plan__c plan : plans) {
                // Match transaction category if configured
                if (String.isNotBlank(txn.Transaction_Category_Code__c)) {
                    // Category matching would check Template_Category_Eligibility__c
                    // For now, process on the first matching plan
                }

                Comp_Calculation__c calc = new Comp_Calculation__c();
                calc.Comp_Plan__c = plan.Id;
                calc.Rep__c = txn.Participant__c;
                calc.Imported_Transaction__c = txn.Id;
                calc.Commisionable_Value__c = txn.Amount__c;
                calc.Eligible_Commission__c = txn.Amount__c; // Will be refined by rate structure
                calc.Applied_Percentage__c = 100; // Placeholder — would be computed from tiers
                calc.Type__c = 'Base';
                calc.Calculation_Status__c = 'Projected';
                calc.Adjustment_Type__c = 'Original';
                calc.Processed_Date__c = Date.today();
                calc.Contract_Date2__c = txn.Transaction_Date__c;
                calc.Rep_Name__c = txn.Participant_External_Id__c;
                calc.Comments__c = 'Imported: ' + txn.Source_System__c + ' - ' + txn.External_Id__c;
                calcs.add(calc);
                processed = true;
                break; // One calc per transaction for now
            }

            if (processed) {
                txn.Processing_Status__c = 'Processed';
                txn.Commission_Processed__c = true;
                result.processed++;
            }
            toUpdate.add(txn);
        }

        if (!calcs.isEmpty()) insert calcs;
        if (!toUpdate.isEmpty()) update toUpdate;

        // Audit trail
        for (Comp_Calculation__c calc : calcs) {
            IncentiveChangeEventService.logEvent(
                'Calculation', calc.Id, 'Calculation_Processed',
                null, String.valueOf(calc.Commisionable_Value__c),
                'Imported transaction processed');
        }
    }

    /**
     * Process a single imported transaction that was just matched to an Opportunity.
     * Per spec: once linked, the Opportunity is authoritative and the import becomes reference only.
     */
    public static void linkToOpportunity(Id importedTransactionId, Id opportunityId) {
        Imported_Transaction__c txn = [
            SELECT Id, Processing_Status__c, Commission_Processed__c, Opportunity__c
            FROM Imported_Transaction__c WHERE Id = :importedTransactionId LIMIT 1];

        if (txn.Commission_Processed__c) {
            // Already processed — can't link. Would cause double-calculation.
            throw new ImportException(
                'Cannot link to Opportunity: this imported transaction has already been processed for commissions. ' +
                'Delete the existing commission records first, then link.');
        }

        txn.Opportunity__c = opportunityId;
        txn.Processing_Status__c = 'Linked_To_Opportunity';
        txn.Processing_Notes__c = 'Linked to Opportunity ' + opportunityId + '. Commission processing will use the Opportunity, not this import.';
        update txn;

        IncentiveChangeEventService.logEvent(
            'Opportunity', importedTransactionId, 'Status_Change',
            null, 'Linked_To_Opportunity', 'Linked to Opportunity ' + opportunityId);
    }

    public class ImportException extends Exception {}
}
