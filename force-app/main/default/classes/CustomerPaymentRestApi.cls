/**
 * @description REST API for receiving customer payment data.
 *              POST /services/apexrest/revenuetrust/payments
 *              Triggers collection-based hold releases.
 */
@RestResource(urlMapping='/revenuetrust/payments')
global with sharing class CustomerPaymentRestApi {

    @HttpPost
    global static PaymentResponse postPayments() {
        RestRequest req = RestContext.request;
        PaymentResponse response = new PaymentResponse();

        try {
            String body = req.requestBody.toString();
            List<PaymentInput> inputs = (List<PaymentInput>) JSON.deserialize(body, List<PaymentInput>.class);

            String batchId = 'PAY-' + System.now().format('yyyyMMdd-HHmmss');
            List<Customer_Payment__c> payments = new List<Customer_Payment__c>();

            for (PaymentInput input : inputs) {
                Customer_Payment__c pmt = new Customer_Payment__c();
                pmt.Payment_Amount__c = input.Amount;
                pmt.Payment_Date__c = input.Payment_Date != null ? Date.valueOf(input.Payment_Date) : Date.today();
                pmt.Payment_Reference__c = input.Payment_Reference;
                pmt.Payment_Method__c = input.Payment_Method;
                pmt.Currency_Code__c = input.Currency_Code;
                pmt.Collection_Pct__c = input.Collection_Pct;
                pmt.Is_Full_Payment__c = input.Is_Full_Payment != null ? input.Is_Full_Payment : false;
                pmt.External_Id__c = input.External_Id;
                pmt.Source__c = 'API';
                pmt.Batch_Id__c = batchId;
                pmt.Processing_Status__c = 'Pending';

                // Match to Opportunity
                if (String.isNotBlank(input.Opportunity_Id)) {
                    try {
                        pmt.Opportunity__c = Id.valueOf(input.Opportunity_Id);
                    } catch (Exception e) {
                        // Invalid ID format
                    }
                }

                payments.add(pmt);
            }

            // Upsert by External_Id
            upsert payments External_Id__c;

            // Process hold releases
            Integer releasedCount = 0;
            for (Customer_Payment__c pmt : payments) {
                if (pmt.Opportunity__c != null && pmt.Collection_Pct__c != null) {
                    releasedCount += processHoldRelease(pmt);
                }
                pmt.Processing_Status__c = 'Processed';
            }
            update payments;

            response.success = true;
            response.totalPayments = payments.size();
            response.processed = payments.size();
            response.holdsReleased = releasedCount;
            response.batchId = batchId;

        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
        }

        return response;
    }

    /**
     * Check if payment triggers hold release on commission calculations.
     */
    private static Integer processHoldRelease(Customer_Payment__c payment) {
        Integer released = 0;

        // Find held calcs for this opportunity
        List<Comp_Calculation__c> heldCalcs = [
            SELECT Id, Hold_Status__c, Hold_Reason__c, Hold_Threshold__c
            FROM Comp_Calculation__c
            WHERE Opportunity__c = :payment.Opportunity__c
            AND Hold_Status__c = 'Held'
            AND Hold_Reason__c = 'Collection_Pending'
        ];

        if (heldCalcs.isEmpty()) return 0;

        // Check if collection % meets release threshold
        for (Comp_Calculation__c calc : heldCalcs) {
            Decimal threshold = calc.Hold_Threshold__c != null ? calc.Hold_Threshold__c : 100;
            if (payment.Collection_Pct__c >= threshold || payment.Is_Full_Payment__c) {
                calc.Hold_Status__c = 'Released';
                calc.Hold_Reason__c = 'None';
                released++;

                IncentiveChangeEventService.logEvent(
                    'Calculation', calc.Id, 'COMMISSION_HOLD_RELEASED',
                    'Held', 'Released',
                    'Released by customer payment: ' + payment.Payment_Reference__c +
                    ' (' + payment.Collection_Pct__c + '% collected)');
            }
        }

        if (released > 0) update heldCalcs;
        return released;
    }

    global class PaymentInput {
        public String Opportunity_Id;
        public Decimal Amount;
        public String Payment_Date;
        public String Payment_Reference;
        public String Payment_Method;
        public String Currency_Code;
        public Decimal Collection_Pct;
        public Boolean Is_Full_Payment;
        public String External_Id;
    }

    global class PaymentResponse {
        public Boolean success;
        public Integer totalPayments;
        public Integer processed;
        public Integer holdsReleased;
        public String batchId;
        public String errorMessage;
    }
}
