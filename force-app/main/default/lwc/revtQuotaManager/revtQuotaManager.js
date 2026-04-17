import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getQuotasWithParticipantsForGroup from "@salesforce/apex/QuotaManagerController.getQuotasWithParticipantsForGroup";
import saveBulkQuotasForGroup from "@salesforce/apex/QuotaManagerController.saveBulkQuotasForGroup";
import importCsvQuotas from "@salesforce/apex/QuotaManagerController.importCsvQuotas";
import distributeEvenly from "@salesforce/apex/QuotaManagerController.distributeEvenly";
import copyFromLastPeriod from "@salesforce/apex/QuotaManagerController.copyFromLastPeriod";
import getGroupsForActiveConfig from "@salesforce/apex/ForecastController.getGroupsForActiveConfig";

const GROUP_VALUE_CONFIG_WIDE = "__CONFIG_WIDE__";

export default class RevtQuotaManager extends LightningElement {
  @api periods = [];
  @track rows = [];
  @track selectedPeriodId;
  @track selectedGroupValue = GROUP_VALUE_CONFIG_WIDE; // Phase B
  @track groups = [];
  isLoading = false;

  @wire(getGroupsForActiveConfig)
  wiredGroups({ data, error }) {
    if (data) {
      this.groups = data;
    } else if (error) {
      this.groups = [];
    }
  }

  // Phase B: Group selector \u2014 includes "Config-wide" sentinel for null Forecast_Group__c
  get groupSelectorOptions() {
    const opts = [
      { label: "Config-wide (no group)", value: GROUP_VALUE_CONFIG_WIDE }
    ];
    for (const g of this.groups || []) {
      opts.push({ label: g.groupName, value: g.groupId });
    }
    return opts;
  }

  get showGroupSelector() {
    return (this.groups || []).length >= 1;
  }

  get isConfigWideQuotaMode() {
    return this.selectedGroupValue === GROUP_VALUE_CONFIG_WIDE;
  }

  get currentGroupId() {
    return this.isConfigWideQuotaMode ? null : this.selectedGroupValue;
  }

  handleGroupChange(event) {
    this.selectedGroupValue = event.detail.value;
    this.loadQuotas();
  }

  // Modals
  showImportModal = false;
  showDistributeModal = false;
  showCopyModal = false;
  csvContent = "";
  importErrors = null;
  distributeTotal = 0;
  distributeConflict = "OVERWRITE";
  copyConflict = "OVERWRITE";
  copyAdjustment = 0;

  // Dirty tracking
  dirtyMap = new Map();

  get periodOptions() {
    return (this.periods || []).map((p) => ({
      label: p.Name + " (" + p.REVT__Status__c + ")",
      value: p.Id
    }));
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get conflictOptions() {
    return [
      { label: "Overwrite existing quotas", value: "OVERWRITE" },
      { label: "Skip if quota exists", value: "SKIP_EXISTING" }
    ];
  }

  connectedCallback() {
    if (this.periods?.length > 0) {
      // Default to first Open period
      const openPeriod = this.periods.find((p) => p.REVT__Status__c === "Open");
      this.selectedPeriodId = openPeriod ? openPeriod.Id : this.periods[0].Id;
      this.loadQuotas();
    }
  }

  async loadQuotas() {
    if (!this.selectedPeriodId) return;
    this.isLoading = true;
    try {
      const result = await getQuotasWithParticipantsForGroup({
        periodId: this.selectedPeriodId,
        groupId: this.currentGroupId
      });
      this.rows = result || [];
      this.dirtyMap.clear();
    } catch (err) {
      this.toast("error", "Error", err.body?.message || err.message);
    } finally {
      this.isLoading = false;
    }
  }

  handlePeriodChange(event) {
    this.selectedPeriodId = event.detail.value;
    this.loadQuotas();
  }

  handleTargetChange(event) {
    const userId = event.target.dataset.userId;
    const value = event.detail.value ? Number(event.detail.value) : null;
    this._setDirty(userId, "targetAmount", value);
  }

  handleNotesChange(event) {
    const userId = event.target.dataset.userId;
    this._setDirty(userId, "notes", event.detail.value);
  }

  _setDirty(userId, field, value) {
    if (!this.dirtyMap.has(userId)) {
      const row = this.rows.find((r) => r.userId === userId);
      this.dirtyMap.set(userId, {
        quotaId: row?.quotaId || null,
        userId,
        participantId: row?.participantId,
        targetAmount: row?.targetAmount,
        status: "Active",
        notes: row?.notes || ""
      });
    }
    this.dirtyMap.get(userId)[field] = value;
  }

  async handleSaveAll() {
    if (this.dirtyMap.size === 0) {
      this.toast("info", "No Changes", "No quotas have been modified.");
      return;
    }
    this.isLoading = true;
    try {
      const inputs = Array.from(this.dirtyMap.values());
      await saveBulkQuotasForGroup({
        quotasJson: JSON.stringify(inputs),
        periodId: this.selectedPeriodId,
        groupId: this.currentGroupId
      });
      this.toast("success", "Saved", inputs.length + " quota(s) saved.");
      await this.loadQuotas();
    } catch (err) {
      this.toast("error", "Save Failed", err.body?.message || err.message);
    } finally {
      this.isLoading = false;
    }
  }

  // ── Import CSV ──

  handleImportClick() {
    this.showImportModal = true;
    this.csvContent = "";
    this.importErrors = null;
  }
  closeImportModal() {
    this.showImportModal = false;
  }
  handleCsvChange(event) {
    this.csvContent = event.detail.value;
  }
  async handleImport() {
    if (!this.csvContent) return;
    this.isLoading = true;
    try {
      const result = await importCsvQuotas({
        periodId: this.selectedPeriodId,
        csvContent: this.csvContent
      });
      if (result.errorRows?.length > 0) {
        this.importErrors = result.errorRows;
        this.toast(
          "warning",
          "Partial Import",
          result.successCount +
            " imported, " +
            result.errorRows.length +
            " errors."
        );
      } else {
        this.toast(
          "success",
          "Imported",
          result.successCount + " quota(s) imported."
        );
        this.closeImportModal();
        await this.loadQuotas();
      }
    } catch (err) {
      this.toast("error", "Import Failed", err.body?.message || err.message);
    } finally {
      this.isLoading = false;
    }
  }

  // ── Distribute Evenly ──

  handleDistributeClick() {
    this.showDistributeModal = true;
  }
  closeDistributeModal() {
    this.showDistributeModal = false;
  }
  handleDistributeTotalChange(event) {
    this.distributeTotal = Number(event.detail.value);
  }
  handleDistributeConflictChange(event) {
    this.distributeConflict = event.detail.value;
  }
  async handleDistribute() {
    if (!this.distributeTotal || this.distributeTotal <= 0) {
      this.toast("error", "Error", "Enter a team total greater than 0.");
      return;
    }
    this.isLoading = true;
    try {
      const result = await distributeEvenly({
        periodId: this.selectedPeriodId,
        teamTotal: this.distributeTotal,
        conflictPolicy: this.distributeConflict
      });
      this.toast(
        "success",
        "Distributed",
        result.updatedCount +
          " updated, " +
          result.skippedCount +
          " skipped. " +
          "$" +
          Math.round(result.perPersonAmount).toLocaleString() +
          " per person."
      );
      this.closeDistributeModal();
      await this.loadQuotas();
    } catch (err) {
      this.toast("error", "Failed", err.body?.message || err.message);
    } finally {
      this.isLoading = false;
    }
  }

  // ── Copy from Last ──

  handleCopyClick() {
    this.showCopyModal = true;
  }
  closeCopyModal() {
    this.showCopyModal = false;
  }
  handleCopyConflictChange(event) {
    this.copyConflict = event.detail.value;
  }
  handleCopyAdjustmentChange(event) {
    this.copyAdjustment = Number(event.detail.value);
  }
  async handleCopy() {
    this.isLoading = true;
    try {
      const result = await copyFromLastPeriod({
        periodId: this.selectedPeriodId,
        conflictPolicy: this.copyConflict,
        adjustmentPct: this.copyAdjustment || null
      });
      const adj = this.copyAdjustment
        ? " (+" + this.copyAdjustment + "% adjustment)"
        : "";
      this.toast(
        "success",
        "Copied",
        result.copiedCount +
          " copied, " +
          result.skippedCount +
          " skipped." +
          adj
      );
      this.closeCopyModal();
      await this.loadQuotas();
    } catch (err) {
      this.toast("error", "Failed", err.body?.message || err.message);
    } finally {
      this.isLoading = false;
    }
  }

  toast(variant, title, message) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
