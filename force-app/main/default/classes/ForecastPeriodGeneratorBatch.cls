/**
 * @description Scheduled job that auto-generates future Forecast_Period__c records
 *              based on the active configuration's period type and
 *              Future_Periods_Visible__c setting. Also closes past periods whose
 *              End_Date has passed and Status is still Open.
 *
 *              Schedule example:
 *              System.schedule('Forecast Period Generator - Monthly',
 *                  '0 0 1 1 * ?', new ForecastPeriodGeneratorBatch());
 *
 *              Spec: FORECASTING_APEX_CONTROLLERS.md section 6.1
 */
public class ForecastPeriodGeneratorBatch implements Schedulable {
  /**
   * @description Schedulable entry point.
   * @param sc The SchedulableContext
   */
  public void execute(SchedulableContext sc) {
    // 1. Load active config
    Forecast_Configuration__c config = ForecastDataService.getActiveConfig();
    if (config == null) {
      System.debug(
        LoggingLevel.WARN,
        'ForecastPeriodGeneratorBatch: No active Forecast_Configuration__c found.'
      );
      return;
    }

    Integer futurePeriods = config.Future_Periods_Visible__c != null
      ? config.Future_Periods_Visible__c.intValue()
      : 3;
    String periodType = config.Period_Type__c != null
      ? config.Period_Type__c
      : 'Monthly';

    // 2. Close past periods: End_Date < today and Status = 'Open' -> 'Closed'
    closePastPeriods();

    // 3. Count future periods (Status = 'Scheduled')
    Integer existingFutureCount = [
      SELECT COUNT()
      FROM Forecast_Period__c
      WHERE Status__c = 'Scheduled' AND Start_Date__c > :Date.today()
    ];

    // 4. Create new periods if needed
    if (existingFutureCount < futurePeriods) {
      Integer toCreate = futurePeriods - existingFutureCount;
      createFuturePeriods(toCreate, periodType, config.Id);
    }
  }

  /**
   * @description Close periods whose End_Date has passed and are still Open.
   */
  private void closePastPeriods() {
    List<Forecast_Period__c> pastPeriods = [
      SELECT Id, Status__c
      FROM Forecast_Period__c
      WHERE End_Date__c < :Date.today() AND Status__c = 'Open'
    ];

    if (!pastPeriods.isEmpty()) {
      for (Forecast_Period__c p : pastPeriods) {
        p.Status__c = 'Closed';
      }
      update pastPeriods;
      System.debug(
        'ForecastPeriodGeneratorBatch: Closed ' +
          pastPeriods.size() +
          ' past period(s).'
      );
    }
  }

  /**
   * @description Create future Forecast_Period__c records with auto-generated labels
   *              from the fiscal calendar.
   * @param count Number of periods to create
   * @param periodType Monthly, Quarterly, or Annual
   * @param configId The Forecast_Configuration__c Id to link
   */
  private void createFuturePeriods(
    Integer count,
    String periodType,
    Id configId
  ) {
    // Find the latest existing period to determine where to start generating
    List<Forecast_Period__c> latestPeriods = [
      SELECT Id, End_Date__c, Start_Date__c, Period_Type__c
      FROM Forecast_Period__c
      ORDER BY End_Date__c DESC
      LIMIT 1
    ];

    Date nextStart;
    if (!latestPeriods.isEmpty() && latestPeriods[0].End_Date__c != null) {
      nextStart = latestPeriods[0].End_Date__c.addDays(1);
    } else {
      // No existing periods -- start from beginning of next month
      nextStart = Date.today().toStartOfMonth().addMonths(1);
    }

    List<Forecast_Period__c> newPeriods = new List<Forecast_Period__c>();

    for (Integer i = 0; i < count; i++) {
      Date periodStart = nextStart;
      Date periodEnd;
      String label;

      if (periodType == 'Quarterly') {
        // Quarter: 3 months
        periodEnd = periodStart.addMonths(3).addDays(-1);
        Integer quarter = ((periodStart.month() - 1) / 3) + 1;
        label = 'Q' + quarter + ' ' + periodStart.year();
      } else if (periodType == 'Annual') {
        // Annual: 12 months
        periodEnd = periodStart.addMonths(12).addDays(-1);
        label = 'FY' + periodStart.year();
      } else {
        // Monthly (default)
        periodEnd = periodStart.addMonths(1).addDays(-1);
        label = getMonthLabel(periodStart.month()) + ' ' + periodStart.year();
      }

      Forecast_Period__c newPeriod = new Forecast_Period__c();
      newPeriod.Name = label;
      newPeriod.Start_Date__c = periodStart;
      newPeriod.End_Date__c = periodEnd;
      newPeriod.Status__c = 'Scheduled';
      newPeriod.Period_Type__c = periodType;
      newPeriod.Forecast_Configuration__c = configId;

      newPeriods.add(newPeriod);
      nextStart = periodEnd.addDays(1);
    }

    if (!newPeriods.isEmpty()) {
      insert newPeriods;
      System.debug(
        'ForecastPeriodGeneratorBatch: Created ' +
          newPeriods.size() +
          ' future period(s).'
      );
    }
  }

  /**
   * @description Get a short month label from a month number.
   */
  private String getMonthLabel(Integer month) {
    List<String> months = new List<String>{
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    };
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Unknown';
  }
}
