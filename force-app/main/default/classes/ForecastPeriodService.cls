/**
 * @description Shared period management service. Extracted from ForecastPeriodGeneratorBatch
 *              so both the batch job and the OnboardingController can reuse period creation
 *              and closure logic.
 */
public with sharing class ForecastPeriodService {
  private static final List<String> MONTH_LABELS = new List<String>{
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

  /**
   * @description Create future forecast periods starting after the latest existing period.
   * @param count Number of periods to create
   * @param periodType Monthly, Quarterly, or Annual
   * @param configId The Forecast_Configuration__c Id to link
   * @param startFromDate Optional: override start date (null = auto-detect from latest period)
   * @return List of created period Ids
   */
  public static List<Id> createFuturePeriods(
    Integer count,
    String periodType,
    Id configId,
    Date startFromDate
  ) {
    Date nextStart = startFromDate;

    if (nextStart == null) {
      // Find the latest existing period FOR THIS CONFIG to determine where to start
      List<Forecast_Period__c> latestPeriods = [
        SELECT Id, End_Date__c
        FROM Forecast_Period__c
        WHERE Forecast_Configuration__c = :configId
        ORDER BY End_Date__c DESC
        LIMIT 1
      ];

      if (!latestPeriods.isEmpty() && latestPeriods[0].End_Date__c != null) {
        nextStart = latestPeriods[0].End_Date__c.addDays(1);
      } else {
        nextStart = Date.today().toStartOfMonth().addMonths(1);
      }
    }

    List<Forecast_Period__c> newPeriods = new List<Forecast_Period__c>();

    for (Integer i = 0; i < count; i++) {
      Date periodStart = nextStart;
      Date periodEnd;
      String label;

      if (periodType == 'Quarterly') {
        periodEnd = periodStart.addMonths(3).addDays(-1);
        Integer quarter = ((periodStart.month() - 1) / 3) + 1;
        label = 'Q' + quarter + ' ' + periodStart.year();
      } else if (periodType == 'Annual') {
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
    }

    List<Id> ids = new List<Id>();
    for (Forecast_Period__c p : newPeriods) {
      ids.add(p.Id);
    }
    return ids;
  }

  /**
   * @description Create the first open period for onboarding (starts from current month).
   * @param periodType Monthly, Quarterly, or Annual
   * @param configId The Forecast_Configuration__c Id
   * @return The created period Id
   */
  public static Id createCurrentPeriod(String periodType, Id configId) {
    Date periodStart = Date.today().toStartOfMonth();
    Date periodEnd;
    String label;

    if (periodType == 'Quarterly') {
      Integer qMonth = ((periodStart.month() - 1) / 3) * 3 + 1;
      periodStart = Date.newInstance(periodStart.year(), qMonth, 1);
      periodEnd = periodStart.addMonths(3).addDays(-1);
      Integer quarter = ((periodStart.month() - 1) / 3) + 1;
      label = 'Q' + quarter + ' ' + periodStart.year();
    } else if (periodType == 'Annual') {
      periodStart = Date.newInstance(periodStart.year(), 1, 1);
      periodEnd = Date.newInstance(periodStart.year(), 12, 31);
      label = 'FY' + periodStart.year();
    } else {
      periodEnd = periodStart.addMonths(1).addDays(-1);
      label = getMonthLabel(periodStart.month()) + ' ' + periodStart.year();
    }

    Forecast_Period__c period = new Forecast_Period__c();
    period.Name = label;
    period.Start_Date__c = periodStart;
    period.End_Date__c = periodEnd;
    period.Status__c = 'Open';
    period.Period_Type__c = periodType;
    period.Forecast_Configuration__c = configId;
    insert period;
    return period.Id;
  }

  /**
   * @description Close past periods whose End_Date has passed and Status is still Open.
   * @return Number of periods closed
   */
  public static Integer closePastPeriods() {
    List<Forecast_Period__c> pastPeriods = [
      SELECT Id, Status__c
      FROM Forecast_Period__c
      WHERE End_Date__c < :Date.today() AND Status__c = 'Open'
    ];

    for (Forecast_Period__c p : pastPeriods) {
      p.Status__c = 'Closed';
    }

    if (!pastPeriods.isEmpty()) {
      update pastPeriods;
    }
    return pastPeriods.size();
  }

  /**
   * @description Get a short month label from a month number.
   */
  public static String getMonthLabel(Integer month) {
    return (month >= 1 && month <= 12) ? MONTH_LABELS[month - 1] : 'Unknown';
  }
}
