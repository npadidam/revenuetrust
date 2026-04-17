import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCategories from "@salesforce/apex/AdminConsoleController.getCategories";
import saveCategory from "@salesforce/apex/AdminConsoleController.saveCategory";
import deactivateCategory from "@salesforce/apex/AdminConsoleController.deactivateCategory";

export default class RevtAdminCategories extends LightningElement {
  @api configId;
  categories = [];
  isLoading = false;
  isSaving = false;

  connectedCallback() {
    this.loadCategories();
  }

  async loadCategories() {
    this.isLoading = true;
    try {
      const raw = await getCategories({ configId: this.configId });
      this.categories = (raw || []).map((c) => this._mapCategory(c));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isLoading = false;
    }
  }

  _f(rec, field) {
    return rec["REVT__" + field] ?? rec[field];
  }

  _mapCategory(c) {
    const color = this._f(c, "Color_Hex__c") || "#3498db";
    const isActive = this._f(c, "Is_Active__c") !== false;
    return {
      ...c,
      _label: this._f(c, "Category_Label__c") || c.Name || "",
      _apiName: this._f(c, "Category_API_Name__c") || "",
      _color: color,
      _colorStyle: "background-color: " + color,
      _countsTowardTarget: this._f(c, "Counts_Toward_Target__c") === true,
      _countsTowardStretch: this._f(c, "Counts_Toward_Stretch__c") === true,
      _isTerminal: this._f(c, "Is_Terminal__c") === true,
      _sortOrder: this._f(c, "Sort_Order__c") || 1,
      _isActive: isActive,
      _activeIcon: isActive ? "utility:check" : "utility:close",
      _activeLabel: isActive ? "Active" : "Inactive"
    };
  }

  handleCatFieldChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.detail?.value ?? event.target.value;
    this.categories = this.categories.map((c) => {
      if (c.Id !== id) return c;
      const updated = { ...c };
      if (field === "label") {
        updated._label = value;
      }
      if (field === "apiName") {
        updated._apiName = value;
      }
      if (field === "color") {
        updated._color = value;
        updated._colorStyle = "background-color: " + value;
      }
      if (field === "sortOrder") {
        updated._sortOrder = parseInt(value, 10);
      }
      return updated;
    });
  }

  handleCatCheckChange(event) {
    const id = event.target.dataset.id;
    const field = event.target.dataset.field;
    const checked = event.target.checked;
    this.categories = this.categories.map((c) => {
      if (c.Id !== id) return c;
      const updated = { ...c };
      if (field === "countsTowardTarget") {
        updated._countsTowardTarget = checked;
      }
      if (field === "countsTowardStretch") {
        updated._countsTowardStretch = checked;
      }
      if (field === "isTerminal") {
        updated._isTerminal = checked;
      }
      return updated;
    });
  }

  async handleAddCategory() {
    this.isSaving = true;
    try {
      const nextOrder = this.categories.length + 1;

      await saveCategory({
        configId: this.configId,
        categoryId: null,
        name: "New Category",
        label: "New Category",
        apiName: "New_Category_" + nextOrder,
        color: "#9E9E9E",
        countsTowardTarget: false,
        countsTowardStretch: false,
        isTerminal: false,
        isHighConfidence: false,
        regressionWarning: false,
        sortOrder: nextOrder
      });
      this.showToast("Success", "Category added", "success");
      this.loadCategories();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  async handleRemoveCategory(event) {
    const id = event.target.dataset.id || event.currentTarget.dataset.id;
    try {
      const result = await deactivateCategory({ categoryId: id });
      if (result && result.includes("overrides")) {
        this.showToast("Warning", result, "warning");
      } else {
        this.showToast("Success", "Category deleted", "success");
      }
      this.loadCategories();
      this.dispatchEvent(new CustomEvent("reload"));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async handleSaveAll() {
    this.isSaving = true;
    let savedCount = 0;
    try {
      for (const c of this.categories) {
        // eslint-disable-next-line no-await-in-loop
        await saveCategory({
          configId: this.configId,
          categoryId: c.Id,
          name: c._label,
          label: c._label,
          apiName: c._apiName,
          color: c._color,
          countsTowardTarget: c._countsTowardTarget,
          countsTowardStretch: c._countsTowardStretch,
          isTerminal: c._isTerminal,
          isHighConfidence: false,
          regressionWarning: false,
          sortOrder: c._sortOrder
        });
        savedCount++;
      }
      this.showToast("Success", savedCount + " categories saved", "success");
      this.loadCategories();
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
