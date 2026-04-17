import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getGroupsForConfig from "@salesforce/apex/AdminConsoleController.getGroupsForConfig";
import saveGroup from "@salesforce/apex/AdminConsoleController.saveGroup";
import deactivateGroup from "@salesforce/apex/AdminConsoleController.deactivateGroup";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";
import getGroupableFields from "@salesforce/apex/OnboardingController.getGroupableFields";

export default class RevtAdminGroups extends LightningElement {
  @api configId;
  groups = [];
  isLoading = false;
  isSaving = false;

  // Discovery-driven options
  sourceObjectOptions = [{ label: "Opportunity", value: "Opportunity" }];
  stageOptions = [];
  groupableFieldsByObject = {};

  get groupTypeOptions() {
    return [
      { label: "All Opportunities", value: "All" },
      { label: "Record Type", value: "Record_Type" },
      { label: "Custom Field", value: "Custom_Field" }
    ];
  }

  async connectedCallback() {
    await this.loadDiscovery();
    await this.loadGroups();
    // Pre-load fields for source objects used by current groups
    const objects = new Set(
      this.groups.filter((g) => g._sourceObject).map((g) => g._sourceObject)
    );
    for (const obj of objects) {
      // eslint-disable-next-line no-await-in-loop
      await this.loadGroupableFields(obj);
    }
    // Re-attach field options now that caches are populated
    this.refreshFieldOptions();
  }

  refreshFieldOptions() {
    this.groups = this.groups.map((g) => ({
      ...g,
      _fieldOptions: this.getFieldOptionsForGroup(g._sourceObject)
    }));
  }

  async loadDiscovery() {
    try {
      const disc = await discoverOrg();
      // Source object options (Opportunity + child objects)
      const opts = [{ label: "Opportunity", value: "Opportunity" }];
      const children = [...(disc?.oppChildObjects || [])].sort((a, b) =>
        (a.objectLabel || "").localeCompare(b.objectLabel || "")
      );
      for (const c of children) {
        const tag = c.tier ? ` [${c.tier}]` : "";
        opts.push({
          label: `${c.objectLabel || c.objectApiName} (${c.objectApiName})${tag}`,
          value: c.objectApiName
        });
      }
      this.sourceObjectOptions = opts;
      // Stage options from discovery
      this.stageOptions = (disc?.stages || []).map((s) => ({
        label: s.label,
        value: s.value
      }));
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      // Fall back to defaults
    }
  }

  async loadGroupableFields(objectApiName) {
    if (!objectApiName || this.groupableFieldsByObject[objectApiName]) return;
    try {
      const fields = await getGroupableFields({ objectApiName });
      this.groupableFieldsByObject = {
        ...this.groupableFieldsByObject,
        [objectApiName]: (fields || []).map((f) => ({
          label: `${f.label} (${f.value})`,
          value: f.value
        }))
      };
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      this.groupableFieldsByObject = {
        ...this.groupableFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  getFieldOptionsForGroup(sourceObject) {
    return this.groupableFieldsByObject[sourceObject || "Opportunity"] || [];
  }

  _f(rec, field) {
    return rec["REVT__" + field] ?? rec[field];
  }

  async loadGroups() {
    this.isLoading = true;
    try {
      const raw = await getGroupsForConfig({ configId: this.configId });
      this.groups = (raw || []).map((g) => {
        const srcObj = this._f(g, "Group_Source_Object__c") || "";
        const groupField = this._f(g, "Group_Field__c") || "";
        // Parse comma-separated stages into arrays for multi-select
        const wonStr = this._f(g, "Closed_Won_Stages__c") || "";
        const lostStr = this._f(g, "Closed_Lost_Stages__c") || "";
        return {
          ...g,
          _name: g.Name || "",
          _groupType: this._f(g, "Group_Type__c") || "All",
          _sourceObject: srcObj,
          _groupField: groupField,
          _recordTypeNames: this._f(g, "Record_Type_Names__c") || "",
          _closedWonStages: wonStr
            ? wonStr.split(",").map((s) => s.trim())
            : [],
          _closedLostStages: lostStr
            ? lostStr.split(",").map((s) => s.trim())
            : [],
          _sortOrder: this._f(g, "Sort_Order__c") || 1,
          _isActive: this._f(g, "Is_Active__c") !== false,
          _activeIcon:
            this._f(g, "Is_Active__c") !== false
              ? "utility:check"
              : "utility:close",
          _isCustomField:
            (this._f(g, "Group_Type__c") || "All") === "Custom_Field",
          _isRecordType:
            (this._f(g, "Group_Type__c") || "All") === "Record_Type",
          _fieldOptions: this.getFieldOptionsForGroup(srcObj)
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
      await this.loadGroupableFields(value);
    }

    this.groups = this.groups.map((g) => {
      if (g.Id !== id) return g;
      const u = { ...g };
      if (field === "name") {
        u._name = value;
      }
      if (field === "groupType") {
        u._groupType = value;
        u._isCustomField = value === "Custom_Field";
        u._isRecordType = value === "Record_Type";
      }
      if (field === "sourceObject") {
        u._sourceObject = value;
        u._groupField = "";
        u._fieldOptions = this.getFieldOptionsForGroup(value);
      }
      if (field === "groupField") {
        u._groupField = value;
      }
      if (field === "recordTypeNames") {
        u._recordTypeNames = value;
      }
      if (field === "sortOrder") {
        u._sortOrder = parseInt(value, 10);
      }
      return u;
    });
  }

  handleStagesChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const values = event.detail?.selectedValues || event.detail?.value || [];
    this.groups = this.groups.map((g) => {
      if (g.Id !== id) return g;
      const u = { ...g };
      if (field === "closedWonStages") {
        u._closedWonStages = values;
      }
      if (field === "closedLostStages") {
        u._closedLostStages = values;
      }
      return u;
    });
  }

  async handleAddGroup() {
    this.isSaving = true;
    try {
      const nextOrder = this.groups.length + 1;

      await saveGroup({
        configId: this.configId,
        groupId: null,
        name: "Group " + nextOrder,
        groupType: "All",
        sortOrder: nextOrder,
        sourceObject: null,
        groupField: null,
        recordTypeNames: null,
        closedWonStages: null,
        closedLostStages: null
      });
      this.showToast("Success", "Group added", "success");
      this.loadGroups();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  async handleRemoveGroup(event) {
    const id = event.target.dataset.id || event.currentTarget.dataset.id;
    try {
      await deactivateGroup({ groupId: id });
      this.showToast("Success", "Group deactivated", "success");
      this.loadGroups();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async handleSaveAll() {
    this.isSaving = true;
    let saved = 0;
    try {
      for (const g of this.groups) {
        // eslint-disable-next-line no-await-in-loop
        await saveGroup({
          configId: this.configId,
          groupId: g.Id,
          name: g._name,
          groupType: g._groupType,
          sortOrder: g._sortOrder,
          sourceObject: g._sourceObject || null,
          groupField: g._groupField || null,
          recordTypeNames: g._recordTypeNames || null,
          closedWonStages: Array.isArray(g._closedWonStages)
            ? g._closedWonStages.join(",")
            : g._closedWonStages || null,
          closedLostStages: Array.isArray(g._closedLostStages)
            ? g._closedLostStages.join(",")
            : g._closedLostStages || null
        });
        saved++;
      }
      this.showToast("Success", saved + " groups saved", "success");
      this.loadGroups();
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
