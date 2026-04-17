import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import saveGeneralSettings from "@salesforce/apex/AdminConsoleController.saveGeneralSettings";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";
import getGroupableFields from "@salesforce/apex/OnboardingController.getGroupableFields";

export default class RevtAdminGeneralSettings extends LightningElement {
  @api
  get config() {
    return this._config;
  }
  set config(value) {
    this._config = value;
    if (value) {
      const mapped = this._mapFromConfig(value);

      console.log(
        "GeneralSettings: config received, mapped:",
        JSON.stringify(mapped)
      );
      Object.assign(this, mapped);
    }
  }
  _config;

  periodType = "Monthly";
  paginationSize = 25;
  currencyMode = "Single";
  corporateCurrency = "USD";
  attainmentSource = "Quota_Record";
  attainmentLayout = "Current_Period";
  topLevelLockLabel = "";
  scopeDetermination = "Ownership";
  futurePeriods = 3;
  pipelineRecordTypeFilter = "";
  selectedRecordTypes = [];
  recordTypeOptions = [];
  hourlySnapshotDays = 7;
  hourlySnapshotInterval = 4;
  fiscalYearStartMonth = 1;
  pastPeriodsVisible = 2;
  defaultHorizon = "Current_Period";
  customHorizonPeriods = 3;
  finalForecastLabel = "Final Forecast";
  stretchForecastLabel = "Stretch Forecast";
  forecastCadence = null;
  submissionDeadlineDay = null;
  autoFreezeOnDeadline = false;
  cadenceAnchorDate = null;
  scopeCustomObject = null;
  scopeCustomField = null;
  scopeObjectOptions = [
    { label: "Opportunity", value: "Opportunity" },
    { label: "Account", value: "Account" },
    { label: "User", value: "User" }
  ];
  scopeFieldCache = {};
  isSaving = false;

  get periodTypeOptions() {
    return [
      { label: "Monthly", value: "Monthly" },
      { label: "Quarterly", value: "Quarterly" },
      { label: "Annual", value: "Annual" }
    ];
  }
  get currencyModeOptions() {
    return [
      { label: "Single", value: "Single" },
      { label: "Multi With Dated Rates", value: "MultiWithDatedRates" },
      { label: "Multi With Static Rates", value: "MultiWithStaticRates" },
      { label: "Dual Display", value: "DualDisplay" }
    ];
  }
  get attainmentSourceOptions() {
    return [
      { label: "Incentives Quota Record", value: "Quota_Record" },
      {
        label: "Forecast Quota + Live Achieved",
        value: "Forecast_Quota_With_Live"
      },
      {
        label: "Incentives Quota + Live Achieved",
        value: "Incentives_Quota_With_Live"
      }
    ];
  }
  get attainmentLayoutOptions() {
    return [
      { label: "Current Period", value: "Current_Period" },
      { label: "Period And YTD", value: "Period_And_YTD" },
      { label: "Expanded Multi Period", value: "Expanded_Multi_Period" },
      { label: "None", value: "None" }
    ];
  }
  // Phase A: hide currency fields when org is single-currency.
  // Currency Mode is captured at onboarding; if it ended up "Single",
  // we know multi-currency isn't relevant and we hide the fields.
  get isMultiCurrencyMode() {
    return this.currencyMode && this.currencyMode !== "Single";
  }

  get monthOptions() {
    return [
      { label: "January", value: "1" },
      { label: "February", value: "2" },
      { label: "March", value: "3" },
      { label: "April", value: "4" },
      { label: "May", value: "5" },
      { label: "June", value: "6" },
      { label: "July", value: "7" },
      { label: "August", value: "8" },
      { label: "September", value: "9" },
      { label: "October", value: "10" },
      { label: "November", value: "11" },
      { label: "December", value: "12" }
    ];
  }
  get horizonOptions() {
    return [
      { label: "Current Period", value: "Current_Period" },
      { label: "Current + Next", value: "Current_Plus_Next" },
      { label: "Quarter", value: "Quarter" },
      { label: "Quarter + Next", value: "Quarter_Plus_Next" },
      { label: "Fiscal Year", value: "Fiscal_Year" },
      { label: "Custom", value: "Custom" }
    ];
  }
  get isCustomHorizon() {
    return this.defaultHorizon === "Custom";
  }

  // ── Phase D: Forecast Cadence ──

  get cadenceOptions() {
    return [
      { label: "Weekly — submit every week", value: "Weekly" },
      { label: "Bi-weekly — submit every two weeks", value: "Bi_Weekly" },
      { label: "Monthly — submit once per month", value: "Monthly" },
      { label: "Quarterly — submit once per quarter", value: "Quarterly" }
    ];
  }

  get dayOfWeekOptions() {
    return [
      { label: "Monday", value: "Mon" },
      { label: "Tuesday", value: "Tue" },
      { label: "Wednesday", value: "Wed" },
      { label: "Thursday", value: "Thu" },
      { label: "Friday", value: "Fri" },
      { label: "Saturday", value: "Sat" },
      { label: "Sunday", value: "Sun" }
    ];
  }

  get isWeeklyOrBiWeekly() {
    const c = this.forecastCadence;
    return c === "Weekly" || c === "Bi_Weekly";
  }

  get isMonthlyOrQuarterly() {
    const c = this.forecastCadence;
    return c === "Monthly" || c === "Quarterly";
  }

  get deadlineMaxDay() {
    return this.forecastCadence === "Quarterly" ? 90 : 31;
  }

  get isBiWeekly() {
    return this.forecastCadence === "Bi_Weekly";
  }

  handleCadenceChange(event) {
    this.forecastCadence = event.detail.value;
    // Reset deadline when cadence changes
    this.submissionDeadlineDay = null;
  }

  handleDeadlineDayChange(event) {
    this.submissionDeadlineDay = event.detail.value;
  }

  handleDeadlineNumberChange(event) {
    this.submissionDeadlineDay = String(event.detail.value);
  }

  handleAutoFreezeChange(event) {
    this.autoFreezeOnDeadline = event.target.checked;
  }

  handleAnchorDateChange(event) {
    this.cadenceAnchorDate = event.detail.value;
  }

  get scopeOptions() {
    return [
      { label: "Ownership", value: "Ownership" },
      { label: "Territory", value: "Territory" },
      { label: "Custom Field", value: "Custom_Field" }
    ];
  }

  get isCustomFieldScope() {
    return this.scopeDetermination === "Custom_Field";
  }

  get hasCadence() {
    return !!this.forecastCadence;
  }

  get scopeFieldOptions() {
    const obj = this.scopeCustomObject;
    if (!obj) return [];
    return this.scopeFieldCache[obj] || [];
  }

  handleScopeDeterminationChange(event) {
    this.scopeDetermination = event.detail.value;
  }

  async handleScopeObjectChange(event) {
    this.scopeCustomObject = event.detail.value;
    this.scopeCustomField = null;
    await this.loadScopeFields(this.scopeCustomObject);
  }

  handleScopeFieldChange(event) {
    this.scopeCustomField = event.detail.value;
  }

  async loadScopeFields(objectApiName) {
    if (!objectApiName || this.scopeFieldCache[objectApiName]) return;
    try {
      const fields = await getGroupableFields({ objectApiName });
      this.scopeFieldCache = {
        ...this.scopeFieldCache,
        [objectApiName]: (fields || []).map((f) => ({
          label: `${f.label} (${f.value})`,
          value: f.value
        }))
      };
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      this.scopeFieldCache = { ...this.scopeFieldCache, [objectApiName]: [] };
    }
  }

  renderedCallback() {
    // Pre-load scope fields when custom field is selected
    if (
      this.isCustomFieldScope &&
      this.scopeCustomObject &&
      !this.scopeFieldCache[this.scopeCustomObject]
    ) {
      this.loadScopeFields(this.scopeCustomObject);
    }
  }

  get hasRecordTypes() {
    return this.recordTypeOptions.length > 0;
  }

  async connectedCallback() {
    try {
      const disc = await discoverOrg();
      if (disc?.recordTypes?.length > 0) {
        this.recordTypeOptions = disc.recordTypes.map((rt) => ({
          label: rt.name,
          value: rt.developerName
        }));
      }
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      // Non-critical — RT filter stays as-is
    }
    // Parse existing comma-separated RT filter into array for multi-select
    if (this.pipelineRecordTypeFilter) {
      this.selectedRecordTypes = this.pipelineRecordTypeFilter
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
    }
  }

  handleRecordTypeFilterChange(event) {
    this.selectedRecordTypes = event.detail.selectedValues || [];
    this.pipelineRecordTypeFilter = this.selectedRecordTypes.join(",");
  }

  _collectFormValues() {
    const vals = {};
    const elements = [
      ...this.template.querySelectorAll("lightning-combobox"),
      ...this.template.querySelectorAll("lightning-input")
    ];
    for (const el of elements) {
      if (el.name) {
        vals[el.name] = el.value;
      }
    }
    return vals;
  }

  async handleSave() {
    this.isSaving = true;
    try {
      const v = this._collectFormValues();
      const toInt = (val) =>
        val !== "" && val != null ? parseInt(val, 10) : null;
      const params = {
        configId: this._config?.Id,
        periodType: v.periodType || null,
        paginationSize: toInt(v.paginationSize),
        currencyMode: v.currencyMode || null,
        corporateCurrency: v.corporateCurrency || null,
        attainmentSource: v.attainmentSource || null,
        attainmentLayout: v.attainmentLayout || null,
        topLevelLockLabel: v.topLevelLockLabel || null,
        scopeDetermination: v.scopeDetermination || null,
        futurePeriods: toInt(v.futurePeriods),
        pipelineRecordTypeFilter: this.pipelineRecordTypeFilter || null,
        hourlySnapshotDays: toInt(v.hourlySnapshotDays),
        hourlySnapshotInterval: toInt(v.hourlySnapshotInterval),
        fiscalYearStartMonth: toInt(v.fiscalYearStartMonth),
        pastPeriodsVisible: toInt(v.pastPeriodsVisible),
        defaultHorizon: v.defaultHorizon || null,
        customHorizonPeriods: toInt(v.customHorizonPeriods),
        finalForecastLabel: v.finalForecastLabel || null,
        stretchForecastLabel: v.stretchForecastLabel || null,
        forecastCadence: this.forecastCadence || null,
        submissionDeadlineDay: this.submissionDeadlineDay || null,
        autoFreezeOnDeadline: this.autoFreezeOnDeadline === true,
        cadenceAnchorDate: this.cadenceAnchorDate || null,
        scopeCustomObject: this.scopeCustomObject || null,
        scopeCustomField: this.scopeCustomField || null
      };

      console.log(
        "RevtAdminGeneralSettings: saving params",
        JSON.stringify(params)
      );

      await saveGeneralSettings(params);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Settings saved",
          variant: "success"
        })
      );
      this.dispatchEvent(new CustomEvent("save"));
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || error.message,
          variant: "error"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  _f(cfg, field) {
    // SObject serialization includes REVT__ namespace prefix
    return cfg["REVT__" + field] ?? cfg[field];
  }

  _mapFromConfig(cfg) {
    return {
      periodType: this._f(cfg, "Period_Type__c") || "Monthly",
      paginationSize: this._f(cfg, "Pagination_Size__c") || 25,
      currencyMode: this._f(cfg, "Currency_Mode__c") || "Single",
      corporateCurrency: this._f(cfg, "Corporate_Currency__c") || "USD",
      attainmentSource: this._f(cfg, "Attainment_Source__c") || "Quota_Record",
      attainmentLayout:
        this._f(cfg, "Attainment_Layout__c") || "Current_Period",
      topLevelLockLabel: this._f(cfg, "Top_Level_Lock_Label__c") || "",
      scopeDetermination: this._f(cfg, "Scope_Determination__c") || "Ownership",
      futurePeriods: this._f(cfg, "Future_Periods_Visible__c") || 3,
      pipelineRecordTypeFilter:
        this._f(cfg, "Pipeline_Record_Type_Filter__c") || "",
      hourlySnapshotDays: this._f(cfg, "Hourly_Snapshot_Days__c") || 7,
      hourlySnapshotInterval: this._f(cfg, "Hourly_Snapshot_Interval__c") || 4,
      fiscalYearStartMonth: String(
        this._f(cfg, "Fiscal_Year_Start_Month__c") || 1
      ),
      pastPeriodsVisible: this._f(cfg, "Past_Periods_Visible__c") ?? 2,
      defaultHorizon: this._f(cfg, "Default_Horizon__c") || "Current_Period",
      customHorizonPeriods: this._f(cfg, "Custom_Horizon_Periods__c") ?? 3,
      finalForecastLabel:
        this._f(cfg, "Final_Forecast_Label__c") || "Final Forecast",
      stretchForecastLabel:
        this._f(cfg, "Stretch_Forecast_Label__c") || "Stretch Forecast",
      forecastCadence: this._f(cfg, "Forecast_Cadence__c") || null,
      submissionDeadlineDay: this._f(cfg, "Submission_Deadline_Day__c") || null,
      autoFreezeOnDeadline: this._f(cfg, "Auto_Freeze_On_Deadline__c") === true,
      cadenceAnchorDate: this._f(cfg, "Cadence_Anchor_Date__c") || null,
      scopeCustomObject: this._f(cfg, "Scope_Custom_Object__c") || null,
      scopeCustomField: this._f(cfg, "Scope_Custom_Field__c") || null
    };
  }
}
