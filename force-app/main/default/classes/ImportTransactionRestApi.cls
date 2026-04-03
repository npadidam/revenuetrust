/**
 * @description REST API for receiving external transaction data.
 *              POST /services/apexrest/revenuetrust/transactions
 *              Accepts JSON array of transactions.
 *
 *              Request body:
 *              [
 *                {"External_Id": "ERP-001", "Transaction_Date": "2027-04-15",
 *                 "Amount": 50000, "Currency": "USD", "Category_Code": "NEW",
 *                 "Participant_Email": "jsmith@acme.com", "Account_Name": "BigCo",
 *                 "Product_Name": "Widget Pro", "Quantity": 100, "Source_System": "ERP"}
 *              ]
 *
 *              Response:
 *              {"success": true, "totalRecords": 5, "matched": 4, "processed": 4,
 *               "errors": 1, "duplicates": 0, "errorMessages": ["No matching user for: unknown@test.com"]}
 */
@RestResource(urlMapping='/revenuetrust/transactions')
global with sharing class ImportTransactionRestApi {

    @HttpPost
    global static ImportResponse postTransactions() {
        RestRequest req = RestContext.request;
        ImportResponse response = new ImportResponse();

        try {
            String body = req.requestBody.toString();
            List<TransactionInput> inputs = (List<TransactionInput>) JSON.deserialize(body, List<TransactionInput>.class);

            // Convert to Imported_Transaction__c records
            List<Imported_Transaction__c> records = new List<Imported_Transaction__c>();
            String batchId = 'API-' + System.now().format('yyyyMMdd-HHmmss');

            for (TransactionInput input : inputs) {
                Imported_Transaction__c txn = new Imported_Transaction__c();
                txn.External_Id__c = input.External_Id;
                txn.Transaction_Date__c = input.Transaction_Date != null ? Date.valueOf(input.Transaction_Date) : null;
                txn.Amount__c = input.Amount;
                txn.Currency_Code__c = input.Currency_Code;
                txn.Transaction_Category_Code__c = input.Category_Code;
                txn.Participant_External_Id__c = input.Participant_Email;
                txn.Account_Name__c = input.Account_Name;
                txn.Product_Name__c = input.Product_Name;
                txn.Quantity__c = input.Quantity;
                txn.Source_System__c = input.Source_System != null ? input.Source_System : 'API';
                txn.Batch_Id__c = batchId;
                txn.Processing_Status__c = 'Pending';
                records.add(txn);
            }

            // Process
            ImportedTransactionService.ImportResult result = ImportedTransactionService.processBatch(records);

            response.success = true;
            response.totalRecords = result.totalRecords;
            response.matched = result.matched;
            response.processed = result.processed;
            response.errors = result.errors;
            response.duplicates = result.duplicates;
            response.errorMessages = result.errorMessages;
            response.batchId = batchId;

        } catch (Exception e) {
            response.success = false;
            response.errorMessages = new List<String>{ e.getMessage() };
        }

        return response;
    }

    global class TransactionInput {
        public String External_Id;
        public String Transaction_Date;
        public Decimal Amount;
        public String Currency_Code;
        public String Category_Code;
        public String Participant_Email;
        public String Account_Name;
        public String Product_Name;
        public Decimal Quantity;
        public String Source_System;
    }

    global class ImportResponse {
        public Boolean success;
        public Integer totalRecords;
        public Integer matched;
        public Integer processed;
        public Integer errors;
        public Integer duplicates;
        public List<String> errorMessages;
        public String batchId;
    }
}
