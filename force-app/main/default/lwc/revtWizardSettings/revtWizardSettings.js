import { LightningElement, api } from "lwc";

const HORIZON_OPTIONS = [
  { label: "Current Period Only", value: "Current_Period" },
  { label: "Current + Next Period", value: "Current_Plus_Next" },
  { label: "Current Quarter (3 months)", value: "Quarter" },
  { label: "Current + Next Quarter (6 months)", value: "Quarter_Plus_Next" },
  { label: "Fiscal Year (12 months)", value: "Fiscal_Year" },
  { label: "Custom (N periods)", value: "Custom" }
];

export default class RevtWizardSettings extends LightningElement {
  @api discovery;
  @api currentStep;
  @api wizardData;

  get isStep7() {
    return this.currentStep === 7;
  }
  get isStep8() {
    return this.currentStep === 8;
  }
  get isStep9() {
    return this.currentStep === 9;
  }

  // ── Step 7: Period options ──

  get periodTypeOptions() {
    return [
      { label: "Monthly", value: "Monthly" },
      { label: "Quarterly", value: "Quarterly" },
      { label: "Annual", value: "Annual" }
    ];
  }

  get monthOptions() {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return months.map((m, i) => ({ label: m, value: String(i + 1) }));
  }

  get fiscalMonthValue() {
    return String(this.wizardData?.fiscalYearStartMonth || 1);
  }

  get horizonOptions() {
    return HORIZON_OPTIONS;
  }

  get isCustomHorizon() {
    return this.wizardData?.defaultHorizon === "Custom";
  }

  handlePeriodTypeChange(event) {
    this.fireChange("periodType", event.detail.value);
  }

  handleFuturePeriodsChange(event) {
    this.fireChange("futurePeriods", parseInt(event.detail.value, 10));
  }

  handleFiscalMonthChange(event) {
    this.fireChange("fiscalYearStartMonth", parseInt(event.detail.value, 10));
  }

  handlePastPeriodsChange(event) {
    this.fireChange("pastPeriodsVisible", parseInt(event.detail.value, 10));
  }

  handleDefaultHorizonChange(event) {
    this.fireChange("defaultHorizon", event.detail.value);
  }

  handleCustomHorizonPeriodsChange(event) {
    this.fireChange("customHorizonPeriods", parseInt(event.detail.value, 10));
  }

  // ── Forecast Cadence (Phase D) ──

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
    const c = this.wizardData?.forecastCadence;
    return c === "Weekly" || c === "Bi_Weekly";
  }

  get isMonthlyOrQuarterly() {
    const c = this.wizardData?.forecastCadence;
    return c === "Monthly" || c === "Quarterly";
  }

  get deadlineMaxDay() {
    return this.wizardData?.forecastCadence === "Quarterly" ? 90 : 31;
  }

  get deadlineHelpText() {
    const c = this.wizardData?.forecastCadence;
    if (c === "Monthly")
      return "Day of month (1-31). If month has fewer days, uses last day.";
    if (c === "Quarterly")
      return "Nth calendar day of quarter (e.g., 10 = Jan 10, Apr 10, Jul 10, Oct 10).";
    return "Day of week when forecast is due.";
  }

  handleCadenceChange(event) {
    this.fireChange("forecastCadence", event.detail.value);
    // Reset deadline when cadence changes
    this.fireChange("submissionDeadlineDay", null);
  }

  handleDeadlineDayChange(event) {
    this.fireChange("submissionDeadlineDay", event.detail.value);
  }

  handleDeadlineNumberChange(event) {
    this.fireChange("submissionDeadlineDay", String(event.detail.value));
  }

  handleAutoFreezeChange(event) {
    this.fireChange("autoFreezeOnDeadline", event.target.checked);
  }

  // ── Step 8: Currency ──

  get isSingleCurrencyOrg() {
    return !this.discovery?.isMultiCurrency;
  }

  get currencyDisplayValue() {
    return (
      this.discovery?.corporateCurrency ||
      this.wizardData?.corporateCurrency ||
      "USD"
    );
  }

  get currencyModeOptions() {
    return [
      {
        label: "Single Currency",
        value: "Single",
        description: "All values in one currency"
      },
      {
        label: "Multi with Dated Rates",
        value: "MultiWithDatedRates",
        description:
          "Exchange rates from DatedConversionRate. Rates frozen at submit."
      },
      {
        label: "Multi with Static Rates",
        value: "MultiWithStaticRates",
        description: "Exchange rates from CurrencyType. Fixed rates."
      },
      {
        label: "Dual Display",
        value: "DualDisplay",
        description: "Show both corporate and local columns simultaneously."
      }
    ];
  }

  handleCurrencyModeChange(event) {
    this.fireChange("currencyMode", event.detail.value);
  }

  handleCorporateCurrencyChange(event) {
    this.fireChange("corporateCurrency", event.detail.value);
  }

  // ── Step 9: Level labels (Phase C: per-level array with autoDerive) ──

  get hierarchySourceLabel() {
    return (
      this.discovery?.hierarchySourceLabel ||
      this.wizardData?.hierarchySource ||
      "Hierarchy"
    );
  }

  /**
   * Phase C: levelLabels is an array of { level, label, autoDerive }.
   * Falls back to detection from discovery if wizardData.levelLabels is empty.
   */
  get levelRows() {
    let labels = this.wizardData?.levelLabels;
    // If still empty (no discovery yet), build a placeholder shape from detected count
    if (!Array.isArray(labels) || labels.length === 0) {
      const detected = this.discovery?.detectedLevels || [];
      labels = detected.map((lvl) => ({
        level: lvl.level,
        label: lvl.suggestedLabel,
        autoDerive: true
      }));
      if (labels.length === 0) {
        labels = [
          { level: 1, label: "Level 1", autoDerive: true },
          { level: 2, label: "Level 2", autoDerive: true },
          { level: 3, label: "Level 3", autoDerive: true },
          { level: 4, label: "Level 4", autoDerive: true }
        ];
      }
    }
    return labels.map((row, idx) => {
      const detected = (this.discovery?.detectedLevels || []).find(
        (d) => d.level === row.level
      );
      const suggested = detected?.suggestedLabel || row.label;
      return {
        ...row,
        _idx: idx,
        _autoDerive: row.autoDerive !== false,
        _suggestedDisplay: row.autoDerive !== false ? "Auto: " + suggested : "",
        _overrideDisabled: row.autoDerive !== false,
        _badge: "Level " + row.level
      };
    });
  }

  handleLevelAutoToggle(event) {
    const idx = parseInt(event.target.dataset.idx, 10);
    const checked = event.target.checked;
    const labels = JSON.parse(JSON.stringify(this._levelLabelsArray()));
    if (!labels[idx]) return;
    labels[idx].autoDerive = checked;
    if (checked) {
      // Snap label back to discovered/suggested value
      const detected = (this.discovery?.detectedLevels || []).find(
        (d) => d.level === labels[idx].level
      );
      if (detected?.suggestedLabel) {
        labels[idx].label = detected.suggestedLabel;
      }
    }
    this.fireChange("levelLabels", labels);
  }

  handleLevelLabelChange(event) {
    const idx = parseInt(event.target.dataset.idx, 10);
    const labels = JSON.parse(JSON.stringify(this._levelLabelsArray()));
    if (!labels[idx]) return;
    labels[idx].label = event.detail.value;
    // Editing implies override → ensure autoDerive=false so refresh doesn't clobber
    labels[idx].autoDerive = false;
    this.fireChange("levelLabels", labels);
  }

  /**
   * Returns the current array form, building it from discovery if wizardData is empty.
   */
  _levelLabelsArray() {
    let labels = this.wizardData?.levelLabels;
    if (Array.isArray(labels) && labels.length > 0) return labels;
    const detected = this.discovery?.detectedLevels || [];
    return detected.map((lvl) => ({
      level: lvl.level,
      label: lvl.suggestedLabel,
      autoDerive: true
    }));
  }

  fireChange(field, value) {
    this.dispatchEvent(
      new CustomEvent("stepdatachange", { detail: { field, value } })
    );
  }
}
