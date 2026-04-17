import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getGroupsForConfig from "@salesforce/apex/AdminConsoleController.getGroupsForConfig";
import saveGroup from "@salesforce/apex/AdminConsoleController.saveGroup";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";

export default class RevtAdminTerminalStages extends LightningElement {
  @api configId;
  groups = [];
  stageOptions = [];
  isLoading = false;
  isSaving = false;

  // Config-level defaults (from the first group or "All" group)
  configWonStages = [];
  configLostStages = [];

  async connectedCallback() {
    await this.loadDiscovery();
    await this.loadGroups();
  }

  async loadDiscovery() {
    try {
      const disc = await discoverOrg();
      this.stageOptions = (disc?.stages || []).map((s) => ({
        label: s.label,
        value: s.value
      }));
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      /* fallback */
    }
  }

  _f(rec, field) {
    return rec["REVT__" + field] ?? rec[field];
  }

  async loadGroups() {
    this.isLoading = true;
    try {
      const raw = await getGroupsForConfig({ configId: this.configId });
      this.groups = (raw || []).map((g) => {
        const wonStr = this._f(g, "Closed_Won_Stages__c") || "";
        const lostStr = this._f(g, "Closed_Lost_Stages__c") || "";
        const isAll = (this._f(g, "Group_Type__c") || "All") === "All";
        return {
          ...g,
          _name: g.Name || "",
          _isAll: isAll,
          _closedWonStages: wonStr
            ? wonStr.split(",").map((s) => s.trim())
            : [],
          _closedLostStages: lostStr
            ? lostStr.split(",").map((s) => s.trim())
            : [],
          _hasOverride: wonStr.length > 0 || lostStr.length > 0
        };
      });
      // Extract config-level defaults from "All" type group
      const allGroup = this.groups.find((g) => g._isAll);
      if (allGroup) {
        this.configWonStages = allGroup._closedWonStages;
        this.configLostStages = allGroup._closedLostStages;
      }
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  get hasMultipleGroups() {
    return this.groups.length > 1;
  }

  get nonAllGroups() {
    return this.groups.filter((g) => !g._isAll);
  }

  handleConfigWonChange(event) {
    this.configWonStages = event.detail.selectedValues || [];
  }

  handleConfigLostChange(event) {
    this.configLostStages = event.detail.selectedValues || [];
  }

  handleGroupStagesChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const values = event.detail?.selectedValues || [];
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

  async handleSave() {
    this.isSaving = true;
    try {
      // Save config-level defaults to the "All" group
      const allGroup = this.groups.find((g) => g._isAll);
      if (allGroup) {
        await saveGroup({
          configId: this.configId,
          groupId: allGroup.Id,
          name: allGroup._name || allGroup.Name,
          groupType: "All",
          sortOrder: 1,
          sourceObject: null,
          groupField: null,
          recordTypeNames: null,
          closedWonStages: this.configWonStages.join(","),
          closedLostStages: this.configLostStages.join(",")
        });
      }
      // Save per-group overrides
      for (const g of this.nonAllGroups) {
        if (g._closedWonStages.length > 0 || g._closedLostStages.length > 0) {
          // eslint-disable-next-line no-await-in-loop
          await saveGroup({
            configId: this.configId,
            groupId: g.Id,
            name: g._name || g.Name,
            groupType: this._f(g, "Group_Type__c") || "Custom_Field",
            sortOrder: this._f(g, "Sort_Order__c") || 1,
            sourceObject: this._f(g, "Group_Source_Object__c") || null,
            groupField: this._f(g, "Group_Field__c") || null,
            recordTypeNames: this._f(g, "Record_Type_Names__c") || null,
            closedWonStages: g._closedWonStages.join(","),
            closedLostStages: g._closedLostStages.join(",")
          });
        }
      }
      this.showToast("Success", "Terminal stages saved", "success");
      this.loadGroups();
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
