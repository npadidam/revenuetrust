import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getDisplayFields from "@salesforce/apex/AdminConsoleController.getDisplayFields";
import saveDisplayField from "@salesforce/apex/AdminConsoleController.saveDisplayField";
import deleteDisplayField from "@salesforce/apex/AdminConsoleController.deleteDisplayField";
import getEligibleDisplayFields from "@salesforce/apex/AdminConsoleController.getEligibleDisplayFields";
import discoverOrg from "@salesforce/apex/OnboardingController.discoverOrg";

export default class RevtAdminFieldMappings extends LightningElement {
  @api configId;
  fields = [];
  isLoading = false;
  isSaving = false;

  // Discovery for object picker
  sourceObjectOptions = [{ label: "Opportunity", value: "Opportunity" }];
  eligibleFieldsByObject = {};

  get locationOptions() {
    return [
      { label: "Main Grid", value: "Main_Grid" },
      { label: "Expanded Detail", value: "Expanded_Detail" },
      { label: "Both", value: "Both" }
    ];
  }

  get widthOptions() {
    return [
      { label: "Narrow (80px)", value: "Narrow" },
      { label: "Medium (120px)", value: "Medium" },
      { label: "Wide (200px)", value: "Wide" }
    ];
  }

  async connectedCallback() {
    await this.loadDiscovery();
    await this.loadFields();
  }

  async loadDiscovery() {
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
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      /* fallback */
    }
  }

  _f(rec, field) {
    return rec["REVT__" + field] ?? rec[field];
  }

  async loadFields() {
    this.isLoading = true;
    try {
      const raw = await getDisplayFields({ configId: this.configId });
      this.fields = (raw || []).map((f) => ({
        ...f,
        _label: this._f(f, "Field_Label__c") || f.Name || "",
        _objectApiName: this._f(f, "Object_API_Name__c") || "Opportunity",
        _fieldApiName: this._f(f, "Field_API_Name__c") || "",
        _fieldType: this._f(f, "Field_Type__c") || "",
        _displayLocation: this._f(f, "Display_Location__c") || "Main_Grid",
        _sortOrder: this._f(f, "Sort_Order__c") || 1,
        _columnWidth: this._f(f, "Column_Width__c") || "Medium",
        _isActive: this._f(f, "Is_Active__c") !== false,
        _isSystem: this._f(f, "Is_System__c") === true,
        _fieldOptions: this.getFieldOptionsFor(
          this._f(f, "Object_API_Name__c") || "Opportunity"
        ),
        _canDelete: this._f(f, "Is_System__c") !== true
      }));
      // Pre-load eligible fields for objects in use
      const objects = new Set(this.fields.map((f) => f._objectApiName));
      for (const obj of objects) {
        // eslint-disable-next-line no-await-in-loop
        await this.loadEligibleFields(obj);
      }
      this.refreshFieldOptions();
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
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

  refreshFieldOptions() {
    this.fields = this.fields.map((f) => ({
      ...f,
      _fieldOptions: this.getFieldOptionsFor(f._objectApiName)
    }));
  }

  async handleFieldChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.detail?.value ?? event.target.value;

    if (field === "objectApiName") {
      await this.loadEligibleFields(value);
    }

    this.fields = this.fields.map((f) => {
      if (f.Id !== id) return f;
      const u = { ...f };
      if (field === "label") {
        u._label = value;
      }
      if (field === "objectApiName") {
        u._objectApiName = value;
        u._fieldApiName = "";
        u._fieldOptions = this.getFieldOptionsFor(value);
      }
      if (field === "fieldApiName") {
        u._fieldApiName = value;
      }
      if (field === "displayLocation") {
        u._displayLocation = value;
      }
      if (field === "sortOrder") {
        u._sortOrder = parseInt(value, 10);
      }
      if (field === "columnWidth") {
        u._columnWidth = value;
      }
      return u;
    });
  }

  handleFieldCheckChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const checked = event.target.checked;
    this.fields = this.fields.map((f) => {
      if (f.Id !== id) return f;
      const u = { ...f };
      if (field === "isActive") {
        u._isActive = checked;
      }
      return u;
    });
  }

  async handleAddField() {
    this.isSaving = true;
    try {
      const nextOrder = this.fields.length + 1;

      await saveDisplayField({
        configId: this.configId,
        fieldId: null,
        fieldLabel: "New Field",
        objectApiName: "Opportunity",
        fieldApiName: "Name",
        fieldType: "Text",
        displayLocation: "Expanded_Detail",
        sortOrder: nextOrder,
        columnWidth: "Medium",
        isActive: true
      });
      this.showToast("Success", "Field added", "success");
      this.loadFields();
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  async handleDeleteField(event) {
    const id = event.target.dataset.id || event.currentTarget.dataset.id;
    try {
      await deleteDisplayField({ fieldId: id });
      this.showToast("Success", "Field removed", "success");
      this.loadFields();
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async handleSaveAll() {
    this.isSaving = true;
    let saved = 0;
    try {
      for (const f of this.fields) {
        // eslint-disable-next-line no-await-in-loop
        await saveDisplayField({
          configId: this.configId,
          fieldId: f.Id,
          fieldLabel: f._label,
          objectApiName: f._objectApiName,
          fieldApiName: f._fieldApiName,
          fieldType: f._fieldType,
          displayLocation: f._displayLocation,
          sortOrder: f._sortOrder,
          columnWidth: f._columnWidth,
          isActive: f._isActive
        });
        saved++;
      }
      this.showToast("Success", saved + " fields saved", "success");
      this.loadFields();
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
