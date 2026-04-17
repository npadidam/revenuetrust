import { LightningElement, api } from "lwc";
import getPicklistFields from "@salesforce/apex/OnboardingController.getPicklistFields";
import getPicklistValues from "@salesforce/apex/OnboardingController.getPicklistValues";
import getGroupableFields from "@salesforce/apex/OnboardingController.getGroupableFields";

export default class RevtWizardDiscovery extends LightningElement {
  @api discovery;
  @api currentStep;
  @api wizardData;

  selectedRecordTypes = [];

  // Phase B: cached picklist fields per object + values per (object,field)
  picklistFieldsByObject = {};
  picklistValuesByKey = {};
  // Cache all accessible fields per object (for Step 2 scope field search)
  groupableFieldsByObject = {};
  // Toggle: show Tier 3 (Advanced) child objects in the grouping picker
  showAdvancedChildObjects = false;

  /**
   * Reactive field loader: when a step renders with a pre-selected object
   * but the field cache is empty, kick off the async load. This covers the
   * case where the user navigates back to a step with an already-chosen object.
   */
  renderedCallback() {
    // Step 2: scope field
    if (this.isStep2 && this.isCustomField) {
      const scopeObj = this.wizardData?.scopeCustomObject;
      if (scopeObj && !this.groupableFieldsByObject[scopeObj]) {
        this.loadGroupableFields(scopeObj);
      }
    }
    // Step 3: grouping field
    if (this.isStep3 && this.isGroupingByCustomField) {
      const grpObj = this.wizardData?.groupingSourceObject;
      if (grpObj && !this.groupableFieldsByObject[grpObj]) {
        this.loadGroupableFields(grpObj);
      }
    }
  }

  get isStep1() {
    return this.currentStep === 1;
  }
  get isStep2() {
    return this.currentStep === 2;
  }
  get isStep3() {
    return this.currentStep === 3;
  }

  // ── Step 1: Discovery cards ──

  get wonStageNames() {
    return this.discovery?.closedWonStages?.join(", ") || "None detected";
  }
  get lostStageNames() {
    return this.discovery?.closedLostStages?.join(", ") || "None detected";
  }
  get currencyLabel() {
    return this.discovery?.isMultiCurrency
      ? "Multi-Currency"
      : "Single Currency";
  }
  get hierarchyDetail() {
    const levels = this.discovery?.detectedLevels?.length || 0;
    const territory = this.discovery?.hasTerritoryManagement
      ? " | Territory Mgmt available"
      : "";
    return levels + " levels detected" + territory;
  }

  // Phase A: explicit hierarchy source label, fiscal year name, corporate currency
  get hierarchySourceLabel() {
    return this.discovery?.hierarchySourceLabel || "Role Hierarchy";
  }
  get fiscalYearStartName() {
    return this.discovery?.fiscalYearStartMonthName || "January";
  }
  get corporateCurrencyValue() {
    return this.discovery?.corporateCurrency || "USD";
  }

  // Phase A: per-RT stage breakdown table (only show when 2+ RTs)
  get hasMultipleRecordTypes() {
    return (this.discovery?.recordTypes?.length || 0) >= 2;
  }
  get recordTypeStageRows() {
    if (!this.discovery?.stagesByRecordType) return [];
    return (this.discovery.recordTypes || []).map((rt) => {
      const stages = this.discovery.stagesByRecordType[rt.developerName] || [];
      return {
        developerName: rt.developerName,
        name: rt.name,
        stageCount: stages.length
      };
    });
  }

  get stagesCardClass() {
    const count = this.discovery?.stages?.length || 0;
    return "disc-card " + (count > 0 ? "conf-high" : "conf-review");
  }
  get hierarchyCardClass() {
    const roles = this.discovery?.roleCount || 0;
    return "disc-card " + (roles > 0 ? "conf-high" : "conf-manual");
  }
  get currencyCardClass() {
    return (
      "disc-card " +
      (this.discovery?.isMultiCurrency ? "conf-review" : "conf-high")
    );
  }

  // ── Step 2: Hierarchy options ──

  get hierarchyOptions() {
    const opts = [
      {
        label: "Role Hierarchy (most common)",
        value: "Ownership"
      },
      {
        label: "Manager Hierarchy",
        value: "ManagerChain"
      }
    ];
    if (this.discovery?.hasTerritoryManagement) {
      opts.push({
        label: "Territory Management",
        value: "Territory"
      });
    }
    opts.push({
      label: "Custom Field",
      value: "Custom_Field"
    });
    return opts;
  }

  // Phase A: per-option help text shown based on current selection
  get isOwnership() {
    return this.wizardData?.hierarchySource === "Ownership";
  }
  get isManagerChain() {
    return this.wizardData?.hierarchySource === "ManagerChain";
  }
  get isTerritory() {
    return this.wizardData?.hierarchySource === "Territory";
  }
  get isCustomField() {
    return this.wizardData?.hierarchySource === "Custom_Field";
  }

  // Phase A: scope custom object choices
  get scopeObjectOptions() {
    return [
      { label: "Opportunity", value: "Opportunity" },
      { label: "Account", value: "Account" },
      { label: "User", value: "User" }
    ];
  }

  /** Step 2: scope field options — loaded dynamically from selected object. */
  get scopeFieldOptions() {
    const obj = this.wizardData?.scopeCustomObject;
    if (!obj) return [];
    const fields = this.groupableFieldsByObject[obj] || [];
    return fields.map((f) => ({
      label: `${f.label} (${f.value})`,
      value: f.value
    }));
  }

  handleHierarchyChange(event) {
    this.fireChange("hierarchySource", event.detail.value);
  }

  async handleScopeObjectChange(event) {
    const newObj = event.detail.value;
    this.fireChange("scopeCustomObject", newObj);
    // Reset field when object changes
    this.fireChange("scopeCustomField", null);
    // Load fields for the new object
    await this.loadGroupableFields(newObj);
  }

  handleScopeFieldChange(event) {
    this.fireChange("scopeCustomField", event.detail.value);
  }

  async loadGroupableFields(objectApiName) {
    if (!objectApiName || this.groupableFieldsByObject[objectApiName]) return;
    try {
      const fields = await getGroupableFields({ objectApiName });
      this.groupableFieldsByObject = {
        ...this.groupableFieldsByObject,
        [objectApiName]: fields || []
      };
      // eslint-disable-next-line no-unused-vars
    } catch (err) {
      this.groupableFieldsByObject = {
        ...this.groupableFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  // ── Step 3: Pipeline & Grouping (Phase B) ──

  get hasRecordTypes() {
    return this.discovery?.recordTypes?.length > 0;
  }

  get recordTypeOptions() {
    return (this.discovery?.recordTypes || []).map((rt) => ({
      label: rt.name,
      value: rt.developerName
    }));
  }

  handleRecordTypeChange(event) {
    this.selectedRecordTypes = event.detail.value;
    const filter =
      this.selectedRecordTypes.length > 0
        ? this.selectedRecordTypes.join(",")
        : null;
    this.fireChange("pipelineRecordTypeFilter", filter);
  }

  // Grouping mode radio — disable RT option when org has no Opp record types
  get groupingModeOptions() {
    const noRTs = !this.hasRecordTypes;
    return [
      {
        label: "Single forecast (all opportunities together)",
        value: "Single"
      },
      {
        label: noRTs
          ? "Separate forecasts by Record Type (no Record Types found)"
          : "Separate forecasts by Record Type",
        value: "RecordType",
        disabled: noRTs
      },
      {
        label: "Separate forecasts by Custom Field on Opportunity",
        value: "OppCustomField"
      },
      {
        label: "Separate forecasts by Custom Field on a Child Object",
        value: "ChildCustomField"
      }
    ];
  }

  get groupingMode() {
    return this.wizardData?.groupingMode || "Single";
  }
  get isGroupingSingle() {
    return this.groupingMode === "Single";
  }
  get isGroupingByRecordType() {
    return this.groupingMode === "RecordType";
  }
  get isGroupingByOppField() {
    return this.groupingMode === "OppCustomField";
  }
  get isGroupingByChildField() {
    return this.groupingMode === "ChildCustomField";
  }
  get isGroupingByCustomField() {
    return this.isGroupingByOppField || this.isGroupingByChildField;
  }

  /**
   * Child object dropdown options. Filtered by tier unless "Show Advanced" is toggled on.
   */
  get childObjectOptions() {
    const children = this.discovery?.oppChildObjects || [];
    const order = { Recommended: 0, Standard: 1, Advanced: 2 };
    const filtered = children.filter(
      (c) => this.showAdvancedChildObjects || c.tier !== "Advanced"
    );
    return filtered
      .sort((a, b) => {
        const oa = order[a.tier] ?? 9;
        const ob = order[b.tier] ?? 9;
        if (oa !== ob) return oa - ob;
        return (a.objectLabel || "").localeCompare(b.objectLabel || "");
      })
      .map((c) => ({
        label: `${c.objectLabel || c.objectApiName} (${c.objectApiName}) [${c.tier}]`,
        value: c.objectApiName
      }));
  }

  get groupingObjectOptions() {
    if (this.isGroupingByOppField) {
      return [{ label: "Opportunity", value: "Opportunity" }];
    }
    return this.childObjectOptions;
  }

  /**
   * All accessible fields on the chosen grouping object (loaded async).
   * Uses getGroupableFields rather than getPicklistFields because many
   * child objects (e.g., OpportunityLineItem) have no picklist fields
   * but do have text/reference fields usable as grouping dimensions.
   */
  get groupingFieldOptions() {
    const obj = this.wizardData?.groupingSourceObject;
    if (!obj) return [];
    const fields = this.groupableFieldsByObject[obj] || [];
    return fields.map((f) => ({
      label: `${f.label} (${f.value})`,
      value: f.value
    }));
  }

  /**
   * Picklist values on (groupingSourceObject, groupingField), used to build
   * the "assign value to group" UI.
   */
  get groupingFieldValues() {
    const key = `${this.wizardData?.groupingSourceObject}|${this.wizardData?.groupingField}`;
    return this.picklistValuesByKey[key] || [];
  }

  get groups() {
    return (this.wizardData?.groups || []).map((g, idx) => {
      const isRT = this.isGroupingByRecordType;
      const isCF = this.isGroupingByCustomField;
      const recordTypeOptions = (this.discovery?.recordTypes || []).map(
        (rt) => ({
          label: rt.name,
          value: rt.developerName
        })
      );
      const fieldValueOptions = this.groupingFieldValues.map((v) => ({
        label: v.label,
        value: v.value
      }));
      return {
        ...g,
        _index: idx,
        _isRT: isRT,
        _isCF: isCF,
        _recordTypeOptions: recordTypeOptions,
        _fieldValueOptions: fieldValueOptions
      };
    });
  }

  get canAddGroup() {
    return this.isGroupingByRecordType || this.isGroupingByCustomField;
  }

  get groupCount() {
    return (this.wizardData?.groups || []).length;
  }

  get groupingPreview() {
    const n = this.groupCount;
    if (this.isGroupingSingle || n <= 1) {
      return "1 forecast group will be created.";
    }
    return `${n} forecast groups will be created. Each will have its own pipeline section in the forecast view.`;
  }

  async handleGroupingModeChange(event) {
    const newMode = event.detail.value;
    // Reset groups to defaults appropriate for the new mode
    let newGroups;
    if (newMode === "Single") {
      newGroups = [
        {
          name: "All Opportunities",
          type: "All",
          recordTypeNames: [],
          values: [],
          sortOrder: 1,
          overrideStages: false,
          closedWonStages: [],
          closedLostStages: []
        }
      ];
    } else {
      newGroups = [
        this._newEmptyGroup(
          1,
          newMode === "RecordType" ? "Record_Type" : "Custom_Field"
        ),
        this._newEmptyGroup(
          2,
          newMode === "RecordType" ? "Record_Type" : "Custom_Field"
        )
      ];
    }
    // Fire all related state changes — wizardData updates atomically via parent
    this.fireChange("groupingMode", newMode);
    this.fireChange("groups", newGroups);
    if (newMode === "Single") {
      this.fireChange("groupingSourceObject", null);
      this.fireChange("groupingLookupField", null);
      this.fireChange("groupingField", null);
    } else if (newMode === "OppCustomField") {
      this.fireChange("groupingSourceObject", "Opportunity");
      this.fireChange("groupingLookupField", "Id");
      this.fireChange("groupingField", null);
      await this.loadGroupableFields("Opportunity");
    } else if (newMode === "ChildCustomField") {
      this.fireChange("groupingSourceObject", null);
      this.fireChange("groupingLookupField", null);
      this.fireChange("groupingField", null);
    }
  }

  async handleGroupingObjectChange(event) {
    const obj = event.detail.value;
    this.fireChange("groupingSourceObject", obj);
    // Auto-detect lookup field back to Opportunity from discovery
    if (this.isGroupingByChildField) {
      const child = (this.discovery?.oppChildObjects || []).find(
        (c) => c.objectApiName === obj
      );
      this.fireChange(
        "groupingLookupField",
        child ? child.lookupFieldApiName : null
      );
    } else {
      // Opportunity is its own anchor — Id is the lookup
      this.fireChange("groupingLookupField", "Id");
    }
    this.fireChange("groupingField", null);
    await this.loadGroupableFields(obj);
  }

  async handleGroupingFieldChange(event) {
    const field = event.detail.value;
    this.fireChange("groupingField", field);
    await this._loadPicklistValues(
      this.wizardData?.groupingSourceObject,
      field
    );
  }

  handleShowAdvancedToggle(event) {
    this.showAdvancedChildObjects = event.target.checked;
  }

  handleGroupNameChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const groups = JSON.parse(JSON.stringify(this.wizardData.groups || []));
    if (groups[idx]) {
      groups[idx].name = event.detail.value;
    }
    this.fireChange("groups", groups);
  }

  handleGroupRecordTypesChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const groups = JSON.parse(JSON.stringify(this.wizardData.groups || []));
    if (groups[idx]) {
      groups[idx].recordTypeNames = event.detail.value || [];
    }
    this.fireChange("groups", groups);
  }

  handleGroupValuesChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const groups = JSON.parse(JSON.stringify(this.wizardData.groups || []));
    if (groups[idx]) {
      groups[idx].values = event.detail.value || [];
    }
    this.fireChange("groups", groups);
  }

  handleAddGroup() {
    const groups = JSON.parse(JSON.stringify(this.wizardData.groups || []));
    const isRT = this.isGroupingByRecordType;
    const next = this._newEmptyGroup(
      groups.length + 1,
      isRT ? "Record_Type" : "Custom_Field"
    );
    groups.push(next);
    this.fireChange("groups", groups);
  }

  handleRemoveGroup(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    let groups = JSON.parse(JSON.stringify(this.wizardData.groups || []));
    groups = groups.filter((_, i) => i !== idx);
    groups.forEach((g, i) => {
      g.sortOrder = i + 1;
    });
    this.fireChange("groups", groups);
  }

  _newEmptyGroup(sortOrder, type) {
    return {
      name: "Group " + sortOrder,
      type: type,
      recordTypeNames: [],
      values: [],
      sortOrder,
      overrideStages: false,
      closedWonStages: [],
      closedLostStages: []
    };
  }

  async _loadPicklistFields(objectApiName) {
    if (!objectApiName || this.picklistFieldsByObject[objectApiName]) return;
    try {
      const fields = await getPicklistFields({ objectApiName });
      this.picklistFieldsByObject = {
        ...this.picklistFieldsByObject,
        [objectApiName]: fields || []
      };
      // eslint-disable-next-line no-unused-vars
    } catch (err) {
      this.picklistFieldsByObject = {
        ...this.picklistFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  async _loadPicklistValues(objectApiName, fieldApiName) {
    if (!objectApiName || !fieldApiName) return;
    const key = `${objectApiName}|${fieldApiName}`;
    if (this.picklistValuesByKey[key]) return;
    try {
      const values = await getPicklistValues({ objectApiName, fieldApiName });
      this.picklistValuesByKey = {
        ...this.picklistValuesByKey,
        [key]: values || []
      };
      // eslint-disable-next-line no-unused-vars
    } catch (err) {
      this.picklistValuesByKey = {
        ...this.picklistValuesByKey,
        [key]: []
      };
    }
  }

  // ── Event dispatch ──

  fireChange(field, value) {
    this.dispatchEvent(
      new CustomEvent("stepdatachange", { detail: { field, value } })
    );
  }
}
