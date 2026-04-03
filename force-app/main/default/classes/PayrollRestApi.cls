/**
 * @description REST API for payroll data retrieval and payment confirmation.
 *              GET /services/apexrest/revenuetrust/payroll?period=2027-04&format=json
 *              POST /services/apexrest/revenuetrust/payroll/confirm
 */
@RestResource(urlMapping='/revenuetrust/payroll/*')
global with sharing class PayrollRestApi {

    @HttpGet
    global static PayrollDataResponse getPayrollData() {
        RestRequest req = RestContext.request;
        PayrollDataResponse response = new PayrollDataResponse();

        try {
            String period = req.params.get('period'); // 2027-04
            if (String.isBlank(period)) {
                response.success = false;
                response.errorMessage = 'period parameter required (format: YYYY-MM)';
                return response;
            }

            // Parse period to date range
            String[] parts = period.split('-');
            Integer year = Integer.valueOf(parts[0]);
            Integer month = Integer.valueOf(parts[1]);
            Date periodStart = Date.newInstance(year, month, 1);
            Date periodEnd = periodStart.addMonths(1).addDays(-1);

            // Query validated unpaid calculations
            List<Comp_Calculation__c> calcs = [
                SELECT Id, Comp_Plan__c, Comp_Plan__r.Sales_Rep__c,
                       Comp_Plan__r.Sales_Rep__r.Name,
                       Eligible_Commission__c, Commisionable_Value__c,
                       Applied_Percentage__c, Type__c, Contract_Date2__c,
                       Rep_Name__c
                FROM Comp_Calculation__c
                WHERE Calculation_Status__c = 'Validated'
                AND Commission_Paid_Date__c = null
                AND Contract_Date2__c >= :periodStart
                AND Contract_Date2__c <= :periodEnd
                LIMIT 10000
            ];

            // Group by participant
            Map<Id, PayrollLine> lineMap = new Map<Id, PayrollLine>();
            for (Comp_Calculation__c calc : calcs) {
                Id repId = calc.Comp_Plan__r.Sales_Rep__c;
                if (!lineMap.containsKey(repId)) {
                    PayrollLine line = new PayrollLine();
                    line.participantId = repId;
                    line.participantName = calc.Rep_Name__c;
                    line.grossCommission = 0;
                    line.calculationIds = new List<String>();
                    lineMap.put(repId, line);
                }
                PayrollLine line = lineMap.get(repId);
                line.grossCommission += calc.Eligible_Commission__c != null ? calc.Eligible_Commission__c : 0;
                line.calculationIds.add(calc.Id);
            }

            response.success = true;
            response.period = period;
            response.lines = lineMap.values();
            response.totalAmount = 0;
            for (PayrollLine line : response.lines) {
                response.totalAmount += line.grossCommission;
            }

        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
        }

        return response;
    }

    @HttpPost
    global static ConfirmResponse confirmPayments() {
        RestRequest req = RestContext.request;
        ConfirmResponse response = new ConfirmResponse();

        try {
            // Check if this is a confirm action
            String path = req.requestURI;
            if (!path.contains('/confirm')) {
                response.success = false;
                response.errorMessage = 'Use POST /revenuetrust/payroll/confirm for payment confirmation';
                return response;
            }

            String body = req.requestBody.toString();
            ConfirmInput input = (ConfirmInput) JSON.deserialize(body, ConfirmInput.class);

            // Create confirmation record
            Payroll_Confirmation__c confirmation = new Payroll_Confirmation__c();
            confirmation.Confirmation_Source__c = 'API_Callback';
            confirmation.Confirmed_On__c = Datetime.now();
            confirmation.External_Batch_Id__c = input.export_id;
            confirmation.Total_Confirmed__c = 0;
            confirmation.Records_Confirmed__c = 0;
            confirmation.Records_Failed__c = 0;

            // Find the payroll export
            List<Payroll_Export__c> exports = [
                SELECT Id FROM Payroll_Export__c WHERE Name = :input.export_id LIMIT 1];
            if (!exports.isEmpty()) {
                confirmation.Payroll_Export__c = exports[0].Id;
            }

            // Process confirmations
            List<String> failedDetails = new List<String>();

            for (ConfirmedRecord rec : input.confirmed_records) {
                if (rec.status == 'paid') {
                    // Find calcs for this employee and mark paid
                    // This is simplified — production would use Payroll_Export_Line__c
                    confirmation.Records_Confirmed__c++;
                    confirmation.Total_Confirmed__c += rec.amount;
                } else {
                    confirmation.Records_Failed__c++;
                    failedDetails.add(rec.employee_id + ': ' + rec.reason);
                }
            }

            if (!failedDetails.isEmpty()) {
                confirmation.Failure_Details__c = JSON.serialize(failedDetails);
            }

            insert confirmation;

            response.success = true;
            response.confirmed = Integer.valueOf(confirmation.Records_Confirmed__c);
            response.failed = Integer.valueOf(confirmation.Records_Failed__c);

        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
        }

        return response;
    }

    global class PayrollDataResponse {
        public Boolean success;
        public String period;
        public Decimal totalAmount;
        public List<PayrollLine> lines;
        public String errorMessage;
    }

    global class PayrollLine {
        public Id participantId;
        public String participantName;
        public Decimal grossCommission;
        public List<String> calculationIds;
    }

    global class ConfirmInput {
        public String export_id;
        public List<ConfirmedRecord> confirmed_records;
    }

    global class ConfirmedRecord {
        public String employee_id;
        public Decimal amount;
        public String status;
        public String reason;
    }

    global class ConfirmResponse {
        public Boolean success;
        public Integer confirmed;
        public Integer failed;
        public String errorMessage;
    }
}
