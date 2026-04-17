import { LightningElement, api } from "lwc";

export default class RevtForecastRow extends LightningElement {
  @api record; // ForecastRecordDTO
  @api config; // ForecastConfigDTO
  @api context; // ForecastParticipantContextDTO
  @api isLocked = false;
  @api isExpanded = false;
  @api isDirty = false;
  @api rowError;
  @api showHealthBadge;
  @api showInlineEstimator;
  @api periodId;

  get recordUrl() {
    return "/" + this.record.recordId;
  }

  get ownerAriaLabel() {
    return "View forecast for " + (this.record.ownerName || "owner");
  }

  get expandTooltip() {
    return this.isExpanded ? "Collapse comments" : "Expand comments";
  }

  get expandIcon() {
    return this.isExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get isEditable() {
    return this.context && this.context.canEdit;
  }

  get isDisabled() {
    if (this.isLocked) return true;
    if (!this.context || !this.context.canEdit) return true;
    if (this.record.status === "Frozen") return true;
    if (this.record.pendingApproval) return true;
    if (this.record.isClosed) return true;
    return false;
  }

  get displayStatus() {
    if (this.isDirty) return "Edited";
    return this.record.status || "New";
  }

  get rowClass() {
    let cls = "forecast-row";
    if (this.rowError) {
      cls += " error-row";
    } else if (this.isDirty) {
      cls += " dirty-row";
    } else if (this.record.isClosed) {
      cls += " closed-row";
    } else if (this.record.status === "Frozen") {
      cls += " frozen-row";
    } else if (this.record.status === "Submitted") {
      cls += " submitted-row";
    } else if (this.record.status === "Saved") {
      cls += " saved-row";
    }
    // Subtle health band tint
    if (this.record.healthBand) {
      cls += " health-" + this.record.healthBand.toLowerCase();
    }
    return cls;
  }

  get statusBadgeClass() {
    const status = this.isDirty ? "Dirty" : this.record.status || "New";
    return (
      "slds-badge status-badge status-" +
      status.toLowerCase().replace(/\s+/g, "-")
    );
  }

  // Dynamic metric columns from config
  get showPrevLevel() {
    return this.hasPreviousLevelValues && !this.record.isClosed;
  }

  get prevLevelLabel() {
    const level = this.record.prevLevel;
    return level != null ? "L" + level : "L1";
  }

  get prevLevelInfoTooltip() {
    const name = this.record.prevLevelUserName || "Previous level";
    const level = this.record.prevLevel;
    return name + (level != null ? " (Level " + level + ")" : "");
  }

  get editableMetrics() {
    if (!this.config || !this.config.metrics) return [];
    const prevValues = this.record.previousLevelValues || {};
    const showPrev = this.showPrevLevel;
    return this.config.metrics
      .map((m, idx) => {
        const key = "metric_" + (idx + 1);
        const value = this.record.metricValues
          ? this.record.metricValues[key]
          : null;
        const trend = this.record.trends ? this.record.trends[key] : null;
        const prevValue =
          showPrev && prevValues[key] != null ? prevValues[key] : null;
        return {
          key,
          label: m.label,
          value,
          trend: trend || 0,
          prevValue,
          prevTooltip: prevValue != null ? "L1 submitted: " + prevValue : "",
          formatter: m.format === "Currency" ? "currency" : null,
          formatStyle:
            m.format === "Currency"
              ? "currency"
              : m.format === "Percent"
                ? "percent"
                : "decimal",
          isEditable: m.isEditable
        };
      })
      .filter((m) => m.isEditable);
  }

  get mainGridDisplayFields() {
    if (!this.config?.displayFields || !this.record?.displayFieldValues)
      return [];
    const dfv = this.record.displayFieldValues || {};
    return this.config.displayFields
      .filter(
        (f) =>
          f.isActive &&
          (f.displayLocation === "Main_Grid" || f.displayLocation === "Both")
      )
      .sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0))
      .map((f) => {
        // Key matches Apex: Opportunity fields use fieldApiName, parent fields use objectApiName.fieldApiName
        const displayKey =
          f.objectApiName === "Opportunity"
            ? f.fieldApiName
            : f.objectApiName + "." + f.fieldApiName;
        const val = dfv[displayKey];
        const formatted = val != null ? String(val) : "";
        return {
          key: "df_" + displayKey,
          value: formatted,
          widthStyle:
            f.columnWidth === "Narrow"
              ? "width:80px"
              : f.columnWidth === "Wide"
                ? "width:200px"
                : "width:120px"
        };
      });
  }

  get expandedDetailFields() {
    if (!this.config?.displayFields || !this.record?.displayFieldValues)
      return [];
    return this.config.displayFields
      .filter(
        (f) =>
          f.isActive &&
          (f.displayLocation === "Expanded_Detail" ||
            f.displayLocation === "Both")
      )
      .sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0))
      .map((f) => {
        const val = this.record.displayFieldValues[f.fieldApiName];
        return {
          key: "df_" + f.fieldApiName,
          label: f.fieldLabel,
          value: val != null ? String(val) : ""
        };
      });
  }

  get prevLevelCategory() {
    if (this.record.isClosed) return null;
    const apiName = this.record.prevLevelCategory;
    if (!apiName) return null;
    if (this.config?.categories) {
      const cat = this.config.categories.find(
        (c) => (c.apiName || c.name) === apiName
      );
      if (cat) return cat.label || cat.name;
    }
    return apiName;
  }

  // Category combobox options from config
  get categoryOptions() {
    if (!this.config || !this.config.categories) return [];
    return this.config.categories
      .filter((c) => c.isActive)
      .map((c) => ({ label: c.label || c.name, value: c.apiName || c.name }));
  }

  get categoryColor() {
    if (!this.config || !this.config.categories || !this.record.category)
      return "#706E6B";
    const cat = this.config.categories.find(
      (c) => (c.apiName || c.name) === this.record.category
    );
    return cat ? cat.color : "#706E6B";
  }

  get isCategoryTerminal() {
    if (!this.config || !this.config.categories || !this.record.category)
      return false;
    const cat = this.config.categories.find(
      (c) => (c.apiName || c.name) === this.record.category
    );
    return cat ? cat.isTerminal : false;
  }

  get hasGovernanceFlags() {
    return (
      this.record.governanceFlags && this.record.governanceFlags.length > 0
    );
  }

  get governanceFlagTooltip() {
    if (!this.hasGovernanceFlags) return "";
    return this.record.governanceFlags.length + " active governance flag(s)";
  }

  get hasPreviousLevelValues() {
    return (
      this.record.previousLevelValues &&
      Object.keys(this.record.previousLevelValues).length > 0
    );
  }

  get previousLevelDisplay() {
    if (!this.hasPreviousLevelValues || !this.config || !this.config.metrics)
      return [];
    return this.config.metrics
      .map((m, idx) => {
        const key = "metric_" + (idx + 1);
        return {
          key,
          label: m.label,
          value: this.record.previousLevelValues[key]
        };
      })
      .filter((pv) => pv.value != null);
  }

  get detailColspan() {
    // Count total visible columns minus the expand column
    let count = 6; // name, owner, stage, date, amount, status + flags + divergence
    if (this.showHealthBadge) count++;
    if (this.editableMetrics) count += this.editableMetrics.length;
    count += 3; // category, override date, flags/divergence
    if (this.showInlineEstimator) count++;
    return String(count);
  }

  // ── Event handlers ──

  handleToggleExpand() {
    this.dispatchEvent(
      new CustomEvent("toggleexpand", {
        detail: { recordId: this.record.recordId },
        bubbles: true,
        composed: true
      })
    );
  }

  handleOwnerClick() {
    this.dispatchEvent(
      new CustomEvent("ownerclick", {
        detail: {
          recordId: this.record.recordId,
          ownerName: this.record.ownerName,
          ownerId: this.record.ownerId
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleMetricChange(event) {
    const metricKey = event.target.dataset.metricKey;
    const value =
      event.detail.value != null ? Number(event.detail.value) : null;
    console.log("Row: metricChange", metricKey, value, this.record.recordId);
    this.dispatchEvent(
      new CustomEvent("rowchange", {
        detail: {
          recordId: this.record.recordId,
          field: metricKey,
          value
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleCategoryChange(event) {
    console.log(
      "Row: categoryChange",
      event.detail.value,
      this.record.recordId
    );
    this.dispatchEvent(
      new CustomEvent("rowchange", {
        detail: {
          recordId: this.record.recordId,
          field: "category",
          value: event.detail.value
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleCloseDateChange(event) {
    this.dispatchEvent(
      new CustomEvent("rowchange", {
        detail: {
          recordId: this.record.recordId,
          field: "closeDateOverride",
          value: event.detail.value
        },
        bubbles: true,
        composed: true
      })
    );
  }
}
