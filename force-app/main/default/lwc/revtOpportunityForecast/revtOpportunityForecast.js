import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getForecastConfig from "@salesforce/apex/ForecastController.getForecastConfig";
import getOpportunityForecast from "@salesforce/apex/ForecastController.getOpportunityForecast";
import saveForecastData from "@salesforce/apex/ForecastController.saveForecastData";
import submitForecastData from "@salesforce/apex/ForecastController.submitForecastData";
import acceptCrmValues from "@salesforce/apex/ForecastController.acceptCrmValues";

export default class RevtOpportunityForecast extends LightningElement {
  @api recordId; // Opportunity Id — injected by record page
  @api showComments = false;
  @api showIncentiveEstimate = false;
  @api showHealthScore = false;

  config;
  record;
  isLoading = false;
  isSaving = false;
  isDirty = false;
  selectedPeriodId;
  divergenceDismissed = false;
  hasNoParticipant = false;
  notInScope = false;

  // Dirty values held locally until save
  _dirtyCategory;
  _dirtyMetrics = {};
  _dirtyCloseDate;

  @wire(getForecastConfig)
  wiredConfig({ data, error }) {
    if (data) {
      this.config = data;
      if (data.currentPeriod && !this.selectedPeriodId) {
        this.selectedPeriodId = data.currentPeriod.periodId;
        this.loadForecast();
      }
    } else if (error) {
      this.showToast(
        "error",
        "Error",
        "Failed to load forecast configuration."
      );
    }
  }

  get periodOptions() {
    if (!this.config || !this.config.periods) return [];
    return this.config.periods
      .filter((p) => p.status === "Open" || p.status === "Scheduled")
      .map((p) => ({ label: p.label, value: p.periodId }));
  }

  get showNotInScope() {
    return !this.isLoading && this.notInScope;
  }

  get showNoParticipant() {
    return !this.isLoading && this.hasNoParticipant;
  }

  get showForm() {
    return (
      !this.isLoading &&
      this.record &&
      !this.notInScope &&
      !this.hasNoParticipant
    );
  }

  get showActions() {
    return !this.isReadOnly;
  }

  get isReadOnly() {
    if (!this.record) return true;
    if (this.record.isClosed) return true;
    if (this.record.status === "Frozen") return true;
    if (this.record.pendingApproval) return true;
    return false;
  }

  get readOnlyReason() {
    if (!this.record) return null;
    if (this.record.isWon) return "Deal is Closed Won";
    if (this.record.isClosed) return "Deal is Closed Lost";
    if (this.record.status === "Frozen") return "Period is frozen";
    if (this.record.pendingApproval) return "Pending governance approval";
    return null;
  }

  get statusLabel() {
    if (this.isDirty) return "Edited";
    return this.record?.status || "New";
  }

  get statusBadgeClass() {
    const status = (this.statusLabel || "new")
      .toLowerCase()
      .replace(/\s+/g, "-");
    return "slds-badge status-badge status-" + status;
  }

  get isSaveDisabled() {
    return this.isReadOnly || this.isSaving || !this.isDirty;
  }

  get lastSavedDisplay() {
    if (!this.record?.lastModifiedDate) return null;
    try {
      return new Date(this.record.lastModifiedDate).toLocaleString("en-US", {
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit"
      });
    } catch {
      // ignored
      return null;
    }
  }

  get categoryOptions() {
    if (!this.config || !this.config.categories) return [];
    return this.config.categories
      .filter((c) => c.isActive)
      .map((c) => ({ label: c.label || c.name, value: c.apiName || c.name }));
  }

  get categoryColor() {
    if (!this.config || !this.record) return "#706E6B";
    const cat = this.config.categories.find(
      (c) => (c.apiName || c.name) === this.record.category
    );
    return cat ? cat.color : "#706E6B";
  }

  get editableMetrics() {
    if (!this.config || !this.config.metrics || !this.record) return [];
    return this.config.metrics
      .filter((m) => m.isEditable)
      .map((m, idx) => {
        const key = "metric_" + (idx + 1);
        return {
          key,
          label: m.label || m.name,
          value:
            this._dirtyMetrics[key] !== undefined
              ? this._dirtyMetrics[key]
              : this.record.metricValues
                ? this.record.metricValues[key]
                : null,
          trend: this.record.trends ? this.record.trends[key] : 0
        };
      });
  }

  // ── Data loading ──

  async loadForecast() {
    if (!this.recordId || !this.selectedPeriodId) return;
    this.isLoading = true;
    this.notInScope = false;
    this.hasNoParticipant = false;

    try {
      const result = await getOpportunityForecast({
        opportunityId: this.recordId,
        periodId: this.selectedPeriodId
      });

      if (result) {
        this.record = { ...result };
        this.isDirty = false;
        this._dirtyCategory = undefined;
        this._dirtyMetrics = {};
        this._dirtyCloseDate = undefined;
        this.divergenceDismissed = false;
      } else {
        this.record = null;
        this.notInScope = true;
      }
    } catch (error) {
      const msg = error.body?.message || error.message || "";
      if (
        msg.includes("not a participant") ||
        msg.includes("Participant record not found")
      ) {
        this.hasNoParticipant = true;
      } else {
        this.notInScope = true;
      }
      this.record = null;
    } finally {
      this.isLoading = false;
    }
  }

  // ── Handlers ──

  handlePeriodChange(event) {
    this.selectedPeriodId = event.detail.value;
    this.loadForecast();
  }

  handleCategoryChange(event) {
    this._dirtyCategory = event.detail.value;
    this.record = { ...this.record, category: this._dirtyCategory };
    this.isDirty = true;
  }

  handleMetricChange(event) {
    const key = event.target.dataset.metricKey;
    const value =
      event.detail.value != null ? Number(event.detail.value) : null;
    this._dirtyMetrics[key] = value;
    const updatedValues = { ...this.record.metricValues, [key]: value };
    this.record = { ...this.record, metricValues: updatedValues };
    this.isDirty = true;
  }

  handleCloseDateChange(event) {
    this._dirtyCloseDate = event.detail.value;
    this.record = { ...this.record, closeDateOverride: this._dirtyCloseDate };
    this.isDirty = true;
  }

  async handleAcceptCrm() {
    if (!this.record?.overrideId) return;
    this.isSaving = true;
    try {
      const result = await acceptCrmValues({
        overrideId: this.record.overrideId
      });
      if (result.success) {
        this.showToast("success", "Updated", "Override reset to CRM values.");
        await this.loadForecast();
      } else {
        this.showToast("error", "Error", result.errors.join("; "));
      }
    } catch (error) {
      this.showToast("error", "Error", error.body?.message || error.message);
    } finally {
      this.isSaving = false;
    }
  }

  handleDismissDivergence() {
    this.divergenceDismissed = true;
    this.record = { ...this.record, crmDivergence: false };
  }

  async handleSave() {
    if (!this.isDirty || !this.record) return;
    this.isSaving = true;

    try {
      const override = {
        recordId: this.record.recordId,
        overrideId: this.record.overrideId,
        category: this.record.category,
        metricValues: this.record.metricValues,
        closeDateOverride: this.record.closeDateOverride,
        comment: this.record.comment,
        dataVersion: this.record.dataVersion,
        forceOverwrite: false
      };

      const result = await saveForecastData({
        overridesJson: JSON.stringify([override]),
        periodId: this.selectedPeriodId,
        participantId: null,
        isPartial: false
      });

      if (result.success) {
        this.showToast("success", "Saved", "Forecast override saved.");
        await this.loadForecast();
      } else {
        this.showToast("error", "Save Failed", result.errors.join("; "));
      }
    } catch (error) {
      this.showToast("error", "Error", error.body?.message || error.message);
    } finally {
      this.isSaving = false;
    }
  }

  async handleSubmit() {
    this.isSaving = true;
    try {
      // Save first if dirty
      if (this.isDirty) {
        await this.handleSave();
      }

      const result = await submitForecastData({
        overridesJson: "[]",
        periodId: this.selectedPeriodId,
        participantId: null,
        isPartial: false,
        validateCompleteness: false,
        freezeExchangeRates: true
      });

      if (result.success) {
        this.showToast(
          "success",
          "Submitted",
          "Forecast submitted for review."
        );
        await this.loadForecast();
      } else {
        this.showToast("error", "Submit Failed", result.errors.join("; "));
      }
    } catch (error) {
      this.showToast("error", "Error", error.body?.message || error.message);
    } finally {
      this.isSaving = false;
    }
  }

  showToast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
