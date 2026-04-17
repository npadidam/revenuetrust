import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMetrics from "@salesforce/apex/AdminConsoleController.getMetrics";
import saveMetric from "@salesforce/apex/AdminConsoleController.saveMetric";
import deactivateMetric from "@salesforce/apex/AdminConsoleController.deactivateMetric";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";
import getNumericFields from "@salesforce/apex/OnboardingController.getNumericFields";
import getGroupsForActiveConfig from "@salesforce/apex/ForecastController.getGroupsForActiveConfig";

export default class RevtAdminMetrics extends LightningElement {
  @api configId;
  metrics = [];
  isLoading = false;
  isSaving = false;

  // Discovery-driven options
  sourceObjectOptions = [
    { label: "Opportunity (default)", value: "Opportunity" }
  ];
  groupOptions = [{ label: "All Groups", value: "" }];
  numericFieldsByObject = {};

  get metricTypeOptions() {
    return [
      { label: "Currency", value: "Currency" },
      { label: "Number", value: "Number" },
      { label: "Percentage", value: "Percentage" }
    ];
  }

  get aggregationOptions() {
    return [
      { label: "Sum", value: "Sum" },
      { label: "Average", value: "Average" },
      { label: "Count", value: "Count" },
      { label: "Max", value: "Max" },
      { label: "Min", value: "Min" },
      { label: "(None)", value: "" }
    ];
  }

  async connectedCallback() {
    await this.loadDiscovery();
    try {
      const groups = await getGroupsForActiveConfig();
      this.groupOptions = [{ label: "All Groups", value: "" }];
      for (const g of groups || []) {
        this.groupOptions.push({ label: g.groupName, value: g.groupId });
      }
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      /* keep default */
    }
    await this.loadMetrics();
    // Pre-load numeric fields for each source object used by current metrics
    const objects = new Set(
      this.metrics.map((m) => m._sourceObject || "Opportunity")
    );
    for (const obj of objects) {
      // eslint-disable-next-line no-await-in-loop
      await this.loadNumericFields(obj);
    }
    // Re-attach field options now that caches are populated
    this.refreshFieldOptions();
  }

  refreshFieldOptions() {
    this.metrics = this.metrics.map((m) => ({
      ...m,
      _fieldOptions: this.getFieldOptionsForMetric(m._sourceObject)
    }));
  }

  async loadDiscovery() {
    try {
      const disc = await discoverOrg();
      const opts = [{ label: "Opportunity (default)", value: "Opportunity" }];
      const order = { Recommended: 0, Standard: 1, Advanced: 2 };
      const children = [...(disc?.oppChildObjects || [])].sort((a, b) => {
        const oa = order[a.tier] ?? 9;
        const ob = order[b.tier] ?? 9;
        return oa !== ob
          ? oa - ob
          : (a.objectLabel || "").localeCompare(b.objectLabel || "");
      });
      for (const c of children) {
        const tag = c.tier ? ` [${c.tier}]` : "";
        opts.push({
          label: `${c.objectLabel || c.objectApiName} (${c.objectApiName})${tag}`,
          value: c.objectApiName
        });
      }
      for (const p of disc?.oppParentObjects || []) {
        opts.push({
          label: `${p.objectLabel || p.objectApiName} (${p.objectApiName}) [Parent]`,
          value: p.objectApiName
        });
      }
      this.sourceObjectOptions = opts;
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      // Fall back to just Opportunity
    }
  }

  async loadNumericFields(objectApiName) {
    if (!objectApiName || this.numericFieldsByObject[objectApiName]) return;
    try {
      const fields = await getNumericFields({ objectApiName });
      this.numericFieldsByObject = {
        ...this.numericFieldsByObject,
        [objectApiName]: (fields || []).map((f) => ({
          label: `${f.label} (${f.value})`,
          value: f.value
        }))
      };
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      this.numericFieldsByObject = {
        ...this.numericFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  getFieldOptionsForMetric(sourceObject) {
    return this.numericFieldsByObject[sourceObject || "Opportunity"] || [];
  }

  _f(rec, field) {
    return rec["REVT__" + field] ?? rec[field];
  }

  async loadMetrics() {
    this.isLoading = true;
    try {
      const raw = await getMetrics({ configId: this.configId });
      this.metrics = (raw || []).map((m) => {
        const srcObj = this._f(m, "Source_Object__c") || "Opportunity";
        return {
          ...m,
          _name: m.Name || "",
          _label: this._f(m, "Metric_Label__c") || m.Name || "",
          _type: this._f(m, "Metric_Type__c") || "Currency",
          _sourceObject: srcObj,
          _sourceField: this._f(m, "Source_Field__c") || "",
          _aggregation: this._f(m, "Aggregation__c") || "",
          _sortOrder: this._f(m, "Sort_Order__c") || 1,
          _isPrimary: this._f(m, "Is_Primary__c") === true,
          _isEditable: this._f(m, "Is_Editable__c") !== false,
          _groupId: this._f(m, "Forecast_Group__c") || "",
          _groupName:
            m.REVT__Forecast_Group__r?.Name ||
            m.Forecast_Group__r?.Name ||
            "All Groups",
          _fieldOptions: this.getFieldOptionsForMetric(srcObj)
        };
      });
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  async handleFieldChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.detail?.value ?? event.target.value;

    if (field === "sourceObject") {
      // Load numeric fields for the new object, then update metric

      await this.loadNumericFields(value);
    }

    this.metrics = this.metrics.map((m) => {
      if (m.Id !== id) return m;
      const u = { ...m };
      if (field === "name") {
        u._name = value;
        u._label = value;
      }
      if (field === "type") {
        u._type = value;
      }
      if (field === "sourceObject") {
        u._sourceObject = value;
        u._sourceField = ""; // Reset field when object changes
        u._fieldOptions = this.getFieldOptionsForMetric(value);
      }
      if (field === "sourceField") {
        u._sourceField = value;
      }
      if (field === "aggregation") {
        u._aggregation = value;
      }
      if (field === "sortOrder") {
        u._sortOrder = parseInt(value, 10);
      }
      if (field === "groupId") {
        u._groupId = value;
        u._groupName =
          this.groupOptions.find((o) => o.value === value)?.label ||
          "All Groups";
      }
      return u;
    });
  }

  handleCheckChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const checked = event.target.checked;
    this.metrics = this.metrics.map((m) => {
      if (m.Id !== id) return m;
      const u = { ...m };
      if (field === "isPrimary") {
        // Only one primary at a time
        u._isPrimary = checked;
        if (checked) {
          this.metrics.forEach((other) => {
            if (other.Id !== id) other._isPrimary = false;
          });
        }
      }
      if (field === "isEditable") {
        u._isEditable = checked;
      }
      return u;
    });
  }

  async handleAddMetric() {
    this.isSaving = true;
    try {
      const nextOrder = this.metrics.length + 1;

      await saveMetric({
        configId: this.configId,
        metricId: null,
        name: "Metric " + nextOrder,
        label: "Metric " + nextOrder,
        metricType: "Currency",
        displayFormat: "Currency",
        isPrimary: false,
        isRequired: false,
        isEditable: true,
        sortOrder: nextOrder,
        sourceField: "Amount",
        sourceObject: "Opportunity",
        aggregation: null,
        sourceLookupField: null,
        forecastGroupId: null
      });
      this.showToast("Success", "Metric added", "success");
      this.loadMetrics();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  async handleRemoveMetric(event) {
    const id = event.target.dataset.id || event.currentTarget.dataset.id;
    try {
      const result = await deactivateMetric({ metricId: id });
      if (result && result.includes("overrides")) {
        this.showToast("Warning", result, "warning");
      } else {
        this.showToast("Success", "Metric deleted", "success");
      }
      this.loadMetrics();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async handleSaveAll() {
    this.isSaving = true;
    let saved = 0;
    try {
      for (const m of this.metrics) {
        // eslint-disable-next-line no-await-in-loop
        await saveMetric({
          configId: this.configId,
          metricId: m.Id,
          name: m._name,
          label: m._label,
          metricType: m._type,
          displayFormat: m._type,
          isPrimary: m._isPrimary,
          isRequired: false,
          isEditable: m._isEditable,
          sortOrder: m._sortOrder,
          sourceField: m._sourceField,
          sourceObject: m._sourceObject,
          aggregation: m._aggregation || null,
          sourceLookupField: null,
          forecastGroupId: m._groupId || null
        });
        saved++;
      }
      this.showToast("Success", saved + " metrics saved", "success");
      this.loadMetrics();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
