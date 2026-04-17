import { LightningElement, api, track } from "lwc";
import getEligibleDisplayFields from "@salesforce/apex/AdminConsoleController.getEligibleDisplayFields";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";

export default class RevtWizardActivate extends LightningElement {
  @api discovery;
  @api currentStep;
  @api wizardData;

  // Step 10: Display field picker state
  @track displayFields = [];
  sourceObjectOptions = [{ label: "Opportunity", value: "Opportunity" }];
  eligibleFieldsByObject = {};

  get isStep10() {
    return this.currentStep === 10;
  }
  get isStep11() {
    return this.currentStep === 11;
  }
  get isStep12() {
    return this.currentStep === 12;
  }

  get locationOptions() {
    return [
      { label: "Main Grid", value: "Main_Grid" },
      { label: "Expanded Detail", value: "Expanded_Detail" },
      { label: "Both", value: "Both" }
    ];
  }

  // System fields (always shown, non-removable)
  get systemFields() {
    return [
      {
        label: "Amount",
        objectApiName: "Opportunity",
        fieldApiName: "Amount",
        fieldType: "Currency"
      },
      {
        label: "Close Date",
        objectApiName: "Opportunity",
        fieldApiName: "CloseDate",
        fieldType: "Date"
      },
      {
        label: "Owner",
        objectApiName: "Opportunity",
        fieldApiName: "OwnerId",
        fieldType: "Lookup"
      },
      {
        label: "Stage",
        objectApiName: "Opportunity",
        fieldApiName: "StageName",
        fieldType: "Picklist"
      }
    ];
  }

  async connectedCallback() {
    try {
      const disc = await discoverOrg();
      const opts = [{ label: "Opportunity", value: "Opportunity" }];
      for (const c of disc?.oppChildObjects || []) {
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
      await this.loadEligibleFields("Opportunity");
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      // Non-critical
    }
    // Initialize from wizardData if already has display fields
    if (this.wizardData?.displayFields?.length > 0) {
      this.displayFields = [...this.wizardData.displayFields];
    }
  }

  async loadEligibleFields(objectApiName) {
    if (!objectApiName || this.eligibleFieldsByObject[objectApiName]) return;
    try {
      const fields = await getEligibleDisplayFields({ objectApiName });
      this.eligibleFieldsByObject = {
        ...this.eligibleFieldsByObject,
        [objectApiName]: (fields || []).map((f) => ({
          label: `${f.label} (${f.value})`,
          value: f.value
        }))
      };
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      this.eligibleFieldsByObject = {
        ...this.eligibleFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  getFieldOptionsFor(objectApiName) {
    return this.eligibleFieldsByObject[objectApiName || "Opportunity"] || [];
  }

  get displayFieldRows() {
    return this.displayFields.map((f, idx) => ({
      ...f,
      _idx: idx,
      _fieldOptions: this.getFieldOptionsFor(f.objectApiName)
    }));
  }

  async handleDisplayFieldChange(event) {
    const idx = parseInt(event.target.dataset.idx, 10);
    const field = event.target.dataset.field;
    const value = event.detail?.value ?? event.target.value;

    if (field === "objectApiName") {
      await this.loadEligibleFields(value);
    }

    const updated = [...this.displayFields];
    if (updated[idx]) {
      if (field === "objectApiName") {
        updated[idx] = {
          ...updated[idx],
          objectApiName: value,
          fieldApiName: ""
        };
      } else if (field === "fieldApiName") {
        updated[idx] = { ...updated[idx], fieldApiName: value };
        // Auto-set label from field label
        const opts = this.getFieldOptionsFor(updated[idx].objectApiName);
        const match = opts.find((o) => o.value === value);
        if (match) {
          updated[idx].fieldLabel = match.label.split(" (")[0]; // "Amount (Amount)" → "Amount"
        }
      } else if (field === "displayLocation") {
        updated[idx] = { ...updated[idx], displayLocation: value };
      } else if (field === "fieldLabel") {
        updated[idx] = { ...updated[idx], fieldLabel: value };
      }
    }
    this.displayFields = updated;
    this.fireChange("displayFields", this.displayFields);
  }

  handleAddDisplayField() {
    this.displayFields = [
      ...this.displayFields,
      {
        fieldLabel: "New Field",
        objectApiName: "Opportunity",
        fieldApiName: "",
        displayLocation: "Expanded_Detail",
        sortOrder: this.displayFields.length + 5 // after system fields (1-4)
      }
    ];
    this.fireChange("displayFields", this.displayFields);
  }

  handleRemoveDisplayField(event) {
    const idx = parseInt(
      event.target.dataset.idx || event.currentTarget.dataset.idx,
      10
    );
    this.displayFields = this.displayFields.filter((_, i) => i !== idx);
    this.fireChange("displayFields", this.displayFields);
  }

  // ── Step 11: Attainment ──

  get attainmentOptions() {
    return [
      {
        label: "Forecast Quota + Live Achieved (Recommended)",
        value: "Forecast_Quota_With_Live",
        description:
          "Target from Forecast_Quota records you set in Admin; achieved computed live from Closed Won deals."
      },
      {
        label: "Incentives Quota Record",
        value: "Quota_Record",
        description:
          "Both target and achieved from Incentives Quota__c. Best if using RevenueTrust Commissions."
      },
      {
        label: "Incentives Quota + Live Achieved",
        value: "Incentives_Quota_With_Live",
        description:
          "Target from Incentives Quota; achieved computed live from Closed Won deals."
      }
    ];
  }

  handleAttainmentChange(event) {
    this.fireChange("attainmentSource", event.detail.value);
  }

  // ── Step 12: Review ──

  get attainmentLabel() {
    const map = {
      Forecast_Quota_With_Live: "Forecast Quota target + Live achieved",
      Quota_Record: "From Incentives Quota records",
      Incentives_Quota_With_Live: "Incentives Quota target + Live achieved"
    };
    return (
      map[this.wizardData?.attainmentSource] ||
      this.wizardData?.attainmentSource
    );
  }

  get metricsCount() {
    return this.wizardData?.metrics?.length || 0;
  }

  get metricsSummary() {
    return (this.wizardData?.metrics || []).map((m) => ({
      key: String(m.sortOrder),
      text:
        m.label + " (" + m.metricType + ")" + (m.isPrimary ? " ★ Primary" : "")
    }));
  }

  get categoriesCount() {
    return this.wizardData?.categories?.length || 0;
  }

  get displayFieldsCount() {
    return 4 + (this.displayFields?.length || 0);
  }

  get participantPreview() {
    const users = this.discovery?.activeUserCount || 0;
    const levels = this.discovery?.detectedLevels?.length || 0;
    return (
      users +
      " active users across " +
      levels +
      " hierarchy levels will be initialized"
    );
  }

  handleConfigNameChange(event) {
    this.fireChange("configName", event.detail.value);
  }

  fireChange(field, value) {
    this.dispatchEvent(
      new CustomEvent("stepdatachange", { detail: { field, value } })
    );
  }
}
