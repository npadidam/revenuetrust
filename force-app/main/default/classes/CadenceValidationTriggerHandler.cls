public with sharing class CadenceValidationTriggerHandler {
  private static final Set<String> VALID_DAY_NAMES = new Set<String>{
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  };

  public static void validate(List<Forecast_Configuration__c> records) {
    for (Forecast_Configuration__c cfg : records) {
      if (String.isBlank(cfg.Forecast_Cadence__c)) {
        continue;
      }
      String cadence = cfg.Forecast_Cadence__c;
      String deadline = cfg.Submission_Deadline_Day__c;

      if (String.isBlank(deadline)) {
        continue;
      } // Deadline is optional

      if (cadence == 'Weekly' || cadence == 'Bi_Weekly') {
        if (!VALID_DAY_NAMES.contains(deadline)) {
          cfg.Submission_Deadline_Day__c.addError(
            'For ' +
              cadence.replace('_', '-') +
              ' cadence, deadline must be a day name: Mon, Tue, Wed, Thu, Fri, Sat, Sun'
          );
        }
      } else if (cadence == 'Monthly') {
        if (!deadline.isNumeric()) {
          cfg.Submission_Deadline_Day__c.addError(
            'For Monthly cadence, deadline must be a day number (1-31)'
          );
        } else {
          Integer day = Integer.valueOf(deadline);
          if (day < 1 || day > 31) {
            cfg.Submission_Deadline_Day__c.addError(
              'Monthly deadline day must be between 1 and 31'
            );
          }
        }
      } else if (cadence == 'Quarterly') {
        if (!deadline.isNumeric()) {
          cfg.Submission_Deadline_Day__c.addError(
            'For Quarterly cadence, deadline must be a day number (1-90)'
          );
        } else {
          Integer day = Integer.valueOf(deadline);
          if (day < 1 || day > 90) {
            cfg.Submission_Deadline_Day__c.addError(
              'Quarterly deadline day must be between 1 and 90'
            );
          }
        }
      }
    }
  }
}
