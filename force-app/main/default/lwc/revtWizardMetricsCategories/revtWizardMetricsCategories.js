import { LightningElement, api } from "lwc";
import getNumericFields from "@salesforce/apex/OnboardingController.getNumericFields";
import getPicklistFields from "@salesforce/apex/OnboardingController.getPicklistFields";
import getPicklistValues from "@salesforce/apex/OnboardingController.getPicklistValues";

const FILTER_OPERATORS = [
  { label: "=", value: "EQUALS" },
  { label: "≠", value: "NOT_EQUALS" },
  { label: ">", value: "GREATER_THAN" },
  { label: "<", value: "LESS_THAN" },
  { label: "≥", value: "GREATER_OR_EQUAL" },
  { label: "≤", value: "LESS_OR_EQUAL" },
  { label: "IN", value: "IN" },
  { label: "NOT IN", value: "NOT_IN" },
  { label: "LIKE", value: "LIKE" },
  { label: "NOT LIKE", value: "NOT_LIKE" },
  { label: "INCLUDES", value: "INCLUDES" },
  { label: "EXCLUDES", value: "EXCLUDES" }
];

const LOGICAL_OPERATORS = [
  { label: "AND", value: "AND" },
  { label: "OR", value: "OR" }
];

const MAX_FILTER_CLAUSES = 5;

// Phase C category templates: Counts_Toward_Target__c stays canonical for Final;
// Counts_Toward_Stretch__c is independent (defaults: more inclusive than Final).
const CATEGORY_TEMPLATES = {
  standard: [
    {
      name: "Commit",
      label: "Commit",
      apiName: "Commit",
      color: "#04844B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 1
    },
    {
      name: "Best Case",
      label: "Best Case",
      apiName: "Best_Case",
      color: "#1589EE",
      countsTowardTarget: false,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: 2
    },
    {
      name: "Pipeline",
      label: "Pipeline",
      apiName: "Pipeline",
      color: "#F2CF00",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: 3
    },
    {
      name: "Closed Won",
      label: "Closed Won",
      apiName: "Closed_Won",
      color: "#706E6B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: true,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 4
    },
    {
      name: "Lost",
      label: "Lost",
      apiName: "Lost",
      color: "#EA001E",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: true,
      isHighConfidence: false,
      regressionWarning: true,
      sortOrder: 5
    }
  ],
  simple: [
    {
      name: "Commit",
      label: "Commit",
      apiName: "Commit",
      color: "#04844B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 1
    },
    {
      name: "Pipeline",
      label: "Pipeline",
      apiName: "Pipeline",
      color: "#F2CF00",
      countsTowardTarget: false,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: 2
    },
    {
      name: "Closed",
      label: "Closed",
      apiName: "Closed_Won",
      color: "#706E6B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: true,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 3
    },
    {
      name: "Lost",
      label: "Lost",
      apiName: "Lost",
      color: "#EA001E",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: true,
      isHighConfidence: false,
      regressionWarning: true,
      sortOrder: 4
    }
  ],
  enterprise: [
    {
      name: "Commit",
      label: "Commit",
      apiName: "Commit",
      color: "#04844B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 1
    },
    {
      name: "Upside",
      label: "Upside",
      apiName: "Upside",
      color: "#2E844A",
      countsTowardTarget: false,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: 2
    },
    {
      name: "Best Case",
      label: "Best Case",
      apiName: "Best_Case",
      color: "#1589EE",
      countsTowardTarget: false,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: 3
    },
    {
      name: "Pipeline",
      label: "Pipeline",
      apiName: "Pipeline",
      color: "#F2CF00",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: 4
    },
    {
      name: "Omitted",
      label: "Omitted",
      apiName: "Omitted",
      color: "#B0B0B0",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: true,
      sortOrder: 5
    },
    {
      name: "Closed Won",
      label: "Closed Won",
      apiName: "Closed_Won",
      color: "#706E6B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: true,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 6
    },
    {
      name: "Lost",
      label: "Lost",
      apiName: "Lost",
      color: "#EA001E",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: true,
      isHighConfidence: false,
      regressionWarning: true,
      sortOrder: 7
    }
  ],
  // Custom: starts as Standard. Admin then adds/removes categories freely.
  custom: [
    {
      name: "Commit",
      label: "Commit",
      apiName: "Commit",
      color: "#04844B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: false,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 1
    },
    {
      name: "Closed Won",
      label: "Closed Won",
      apiName: "Closed_Won",
      color: "#706E6B",
      countsTowardTarget: true,
      countsTowardStretch: true,
      isTerminal: true,
      isHighConfidence: true,
      regressionWarning: false,
      sortOrder: 2
    },
    {
      name: "Lost",
      label: "Lost",
      apiName: "Lost",
      color: "#EA001E",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: true,
      isHighConfidence: false,
      regressionWarning: true,
      sortOrder: 3
    }
  ]
};

const AGG_OPTIONS = [
  { label: "Sum", value: "Sum" },
  { label: "Average", value: "Average" },
  { label: "Count", value: "Count" },
  { label: "Max", value: "Max" },
  { label: "Min", value: "Min" }
];

export default class RevtWizardMetricsCategories extends LightningElement {
  @api discovery;
  @api currentStep;
  @api wizardData;

  // Cache numeric fields by source object to avoid repeated Apex calls
  numericFieldsByObject = {};
  // Phase B: Cache filterable fields per object + picklist values per (object, field)
  filterFieldsByObject = {};
  picklistValuesByKey = {};

  get isStep4() {
    return this.currentStep === 4;
  }
  get isStep5() {
    return this.currentStep === 5;
  }
  get isStep6() {
    return this.currentStep === 6;
  }

  connectedCallback() {
    // Pre-load Opportunity numeric fields so Step 5 Opp source field has a search-select
    this.loadNumericFields("Opportunity");
  }

  // ── Step 4: Stages ──

  get stageOptions() {
    return (this.discovery?.stages || []).map((s) => ({
      label: s.label,
      value: s.value
    }));
  }

  handleWonStagesChange(event) {
    this.fireChange("closedWonStages", event.detail.value);
  }

  handleLostStagesChange(event) {
    this.fireChange("closedLostStages", event.detail.value);
  }

  // Phase B: per-group terminal stage overrides

  get hasMultipleGroups() {
    return (this.wizardData?.groups?.length || 0) > 1;
  }

  get groupOverrideRows() {
    return (this.wizardData?.groups || []).map((g, idx) => ({
      ...g,
      _index: idx,
      _toggleLabel:
        'Override stages for "' + (g.name || "Group " + (idx + 1)) + '"'
    }));
  }

  _updateGroupAt(idx, mutator) {
    const groups = JSON.parse(JSON.stringify(this.wizardData.groups || []));
    if (groups[idx]) {
      mutator(groups[idx]);
      this.fireChange("groups", groups);
    }
  }

  handleGroupOverrideToggle(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const checked = event.target.checked;
    this._updateGroupAt(idx, (g) => {
      g.overrideStages = checked;
      if (!checked) {
        g.closedWonStages = [];
        g.closedLostStages = [];
      }
    });
  }

  handleGroupWonChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const value = event.detail.value || [];
    this._updateGroupAt(idx, (g) => {
      g.closedWonStages = value;
    });
  }

  handleGroupLostChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const value = event.detail.value || [];
    this._updateGroupAt(idx, (g) => {
      g.closedLostStages = value;
    });
  }

  // ── Step 5: Metrics ──

  get metricTypeOptions() {
    return [
      { label: "Currency", value: "Currency" },
      { label: "Number", value: "Number" },
      { label: "Percentage", value: "Percentage" }
    ];
  }

  /**
   * Source Object dropdown: Opportunity (always) + every discovered child object
   * grouped by tier (Recommended first, then Standard, then Advanced).
   */
  get sourceObjectOptions() {
    const opts = [{ label: "Opportunity (default)", value: "Opportunity" }];
    const children = this.discovery?.oppChildObjects || [];
    const order = { Recommended: 0, Standard: 1, Advanced: 2 };
    const sorted = [...children].sort((a, b) => {
      const oa = order[a.tier] ?? 9;
      const ob = order[b.tier] ?? 9;
      if (oa !== ob) return oa - ob;
      return (a.objectLabel || "").localeCompare(b.objectLabel || "");
    });
    for (const c of sorted) {
      const tierTag = c.tier ? ` [${c.tier}]` : "";
      opts.push({
        label: `${c.objectLabel || c.objectApiName} (${c.objectApiName})${tierTag}`,
        value: c.objectApiName
      });
    }
    const parents = this.discovery?.oppParentObjects || [];
    for (const p of parents) {
      opts.push({
        label: `${p.objectLabel || p.objectApiName} (${p.objectApiName}) [Parent]`,
        value: p.objectApiName
      });
    }
    return opts;
  }

  get aggregationOptions() {
    return AGG_OPTIONS;
  }

  /**
   * Per-row computed properties to support cascading dropdowns and visibility.
   * Phase B: also exposes filter clauses with option lists for the filter builder.
   */
  get metricRows() {
    const metrics = this.wizardData?.metrics || [];
    return metrics.map((m) => {
      const sourceObj = m.sourceObject || "Opportunity";
      const isOpp = sourceObj === "Opportunity";
      const numFields = this.numericFieldsByObject[sourceObj];
      // Filterable field options come from picklist + numeric + standard fields cache
      const filterFieldOpts = this.filterFieldsByObject[sourceObj] || [];
      const filters = (m.filters || []).map((f, fIdx) => {
        const valueOpts =
          this.picklistValuesByKey[`${sourceObj}|${f.fieldApiName}`] || [];
        return {
          ...f,
          _fIdx: fIdx,
          _valueOptions: valueOpts.map((v) => ({
            label: v.label,
            value: v.value
          })),
          _hasPicklistValues: valueOpts.length > 0
        };
      });
      const fieldOpts = numFields
        ? numFields.map((f) => ({
            label: `${f.label} (${f.value})`,
            value: f.value
          }))
        : [];
      return {
        ...m,
        _sourceObject: sourceObj,
        _isOpportunitySource: isOpp,
        _isChildSource: !isOpp,
        _fieldOptions: fieldOpts,
        _lookupFieldDisplay: m.sourceLookupField
          ? `Linked via: ${m.sourceLookupField}`
          : "",
        _filterFieldOptions: filterFieldOpts.map((f) => ({
          label: `${f.label} (${f.value})`,
          value: f.value
        })),
        _filters: filters,
        _canAddFilter: filters.length < MAX_FILTER_CLAUSES,
        _filterPreview: this._buildFilterPreview(filters)
      };
    });
  }

  get filterOperatorOptions() {
    return FILTER_OPERATORS;
  }

  get filterLogicalOperatorOptions() {
    return LOGICAL_OPERATORS;
  }

  _buildFilterPreview(filters) {
    if (!filters || filters.length === 0) return "";
    return filters
      .map((f, i) => {
        const op =
          (FILTER_OPERATORS.find((o) => o.value === f.operatorValue) || {})
            .label || f.operatorValue;
        const val = f.value || "?";
        const fld = f.fieldApiName || "?";
        const tail =
          i < filters.length - 1 ? ` ${f.logicalOperator || "AND"} ` : "";
        return `${fld} ${op} ${val}${tail}`;
      })
      .join("");
  }

  get canAddMetric() {
    return (this.wizardData?.metrics?.length || 0) < 6;
  }

  handleMetricFieldChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const field = event.target.dataset.field;
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (m) {
      m[field] = event.detail.value || event.target.value;
      if (field === "label") {
        m.name = m.label;
        m.displayFormat = m.metricType;
      }
    }
    this.fireChange("metrics", metrics);
  }

  /**
   * When source object changes, auto-detect the FK lookup field back to Opportunity
   * from discovery.oppChildObjects and load numeric fields for the dropdown.
   */
  async handleSourceObjectChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const newObj = event.detail.value;
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m) return;
    m.sourceObject = newObj;
    if (newObj === "Opportunity") {
      m.sourceLookupField = null;
      m.aggregation = null;
    } else {
      // Auto-detect lookup field from discovery
      const child = (this.discovery?.oppChildObjects || []).find(
        (c) => c.objectApiName === newObj
      );
      m.sourceLookupField = child ? child.lookupFieldApiName : null;
      m.aggregation = m.aggregation || "Sum";
      // Reset source field since it depends on the new object
      m.sourceField = null;
      // Pre-load numeric fields for this object so the dropdown can show options
      await this.loadNumericFields(newObj);
    }
    // Phase B: pre-load filter (picklist) fields for both Opportunity and child sources
    await this.loadFilterFields(newObj);
    this.fireChange("metrics", metrics);
  }

  async loadFilterFields(objectApiName) {
    if (!objectApiName || this.filterFieldsByObject[objectApiName]) return;
    try {
      const fields = await getPicklistFields({ objectApiName });
      this.filterFieldsByObject = {
        ...this.filterFieldsByObject,
        [objectApiName]: fields || []
      };
      // eslint-disable-next-line no-unused-vars
    } catch (err) {
      this.filterFieldsByObject = {
        ...this.filterFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  async loadFilterValues(objectApiName, fieldApiName) {
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

  // ── Filter Builder handlers (Phase B Gap 2) ──

  handleAddFilterClause(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m) return;
    if (!m.filters) m.filters = [];
    if (m.filters.length >= MAX_FILTER_CLAUSES) return;
    m.filters.push({
      fieldApiName: null,
      operatorValue: "EQUALS",
      value: null,
      logicalOperator: "AND",
      sortOrder: m.filters.length + 1
    });
    this.fireChange("metrics", metrics);
    // Pre-load filter fields for this metric's source object
    this.loadFilterFields(m.sourceObject || "Opportunity");
  }

  handleRemoveFilterClause(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const fIdx = parseInt(event.target.dataset.fidx, 10);
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m || !m.filters) return;
    m.filters.splice(fIdx, 1);
    m.filters.forEach((f, i) => {
      f.sortOrder = i + 1;
    });
    this.fireChange("metrics", metrics);
  }

  async handleFilterFieldChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const fIdx = parseInt(event.target.dataset.fidx, 10);
    const newField = event.detail.value;
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m || !m.filters || !m.filters[fIdx]) return;
    m.filters[fIdx].fieldApiName = newField;
    // Reset value when field changes
    m.filters[fIdx].value = null;
    this.fireChange("metrics", metrics);
    // Load picklist values for this (object, field) so the value picker is ready
    await this.loadFilterValues(m.sourceObject || "Opportunity", newField);
  }

  handleFilterOperatorChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const fIdx = parseInt(event.target.dataset.fidx, 10);
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m || !m.filters || !m.filters[fIdx]) return;
    m.filters[fIdx].operatorValue = event.detail.value;
    this.fireChange("metrics", metrics);
  }

  handleFilterValueChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const fIdx = parseInt(event.target.dataset.fidx, 10);
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m || !m.filters || !m.filters[fIdx]) return;
    // event.detail.value may be array (multi-picklist) or scalar string
    const newVal = event.detail.value;
    if (Array.isArray(newVal)) {
      m.filters[fIdx].value = JSON.stringify(newVal);
    } else {
      m.filters[fIdx].value = newVal;
    }
    this.fireChange("metrics", metrics);
  }

  handleFilterLogicalOpChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const fIdx = parseInt(event.target.dataset.fidx, 10);
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (!m || !m.filters || !m.filters[fIdx]) return;
    m.filters[fIdx].logicalOperator = event.detail.value;
    this.fireChange("metrics", metrics);
  }

  handleSourceFieldChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const newField = event.detail.value;
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (m) {
      m.sourceField = newField;
    }
    this.fireChange("metrics", metrics);
  }

  handleAggregationChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const newAgg = event.detail.value;
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (m) {
      m.aggregation = newAgg;
    }
    this.fireChange("metrics", metrics);
  }

  async loadNumericFields(objectApiName) {
    if (this.numericFieldsByObject[objectApiName]) return;
    try {
      const fields = await getNumericFields({ objectApiName });
      this.numericFieldsByObject = {
        ...this.numericFieldsByObject,
        [objectApiName]: fields || []
      };
      // eslint-disable-next-line no-unused-vars
    } catch (err) {
      // Surface failure as empty options; user can still type a field name later
      this.numericFieldsByObject = {
        ...this.numericFieldsByObject,
        [objectApiName]: []
      };
    }
  }

  handleMetricCheckChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const field = event.target.dataset.field;
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const m = metrics.find((mt) => mt.sortOrder === idx);
    if (m) {
      m[field] = event.target.checked;
      // Only one primary
      if (field === "isPrimary" && event.target.checked) {
        for (const other of metrics) {
          if (other.sortOrder !== idx) other.isPrimary = false;
        }
      }
    }
    this.fireChange("metrics", metrics);
  }

  handleAddMetric() {
    const metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    const nextOrder = metrics.length + 1;
    metrics.push({
      name: "Metric " + nextOrder,
      label: "Metric " + nextOrder,
      metricType: "Currency",
      displayFormat: "Currency",
      isPrimary: false,
      isRequired: false,
      isEditable: true,
      sortOrder: nextOrder,
      sourceField: null,
      sourceObject: "Opportunity",
      sourceLookupField: null,
      aggregation: null,
      filters: []
    });
    this.fireChange("metrics", metrics);
  }

  handleRemoveMetric(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    let metrics = JSON.parse(JSON.stringify(this.wizardData.metrics));
    metrics = metrics.filter((m) => m.sortOrder !== idx);
    // Re-number
    metrics.forEach((m, i) => {
      m.sortOrder = i + 1;
    });
    this.fireChange("metrics", metrics);
  }

  // ── Step 6: Categories ──

  get categoryTemplateOptions() {
    return [
      { label: "Standard (5)", value: "standard" },
      { label: "Simple (4)", value: "simple" },
      { label: "Enterprise (7)", value: "enterprise" },
      { label: "Custom (You build it)", value: "custom" }
    ];
  }

  /**
   * Computed category rows with delete-disabled flag.
   * Delete is disabled if removing the row would violate validation:
   *   - At least 1 won terminal category (isTerminal && countsTowardTarget) must remain
   *   - At least 1 non-terminal category must remain
   */
  get categoryRows() {
    const cats = this.wizardData?.categories || [];
    return cats.map((c) => {
      const hint = this._deleteDisabledReason(cats, c);
      return {
        ...c,
        _colorStyle:
          c._colorStyle || "background-color: " + (c.color || "#CCCCCC"),
        _deleteDisabled: !!hint,
        _deleteHint: hint || "Remove category"
      };
    });
  }

  _deleteDisabledReason(cats, target) {
    if ((cats || []).length <= 2) return "Must keep at least 2 categories.";
    // Won-terminal anchor remaining after removal
    const wonTerminalRemaining = cats.filter(
      (c) =>
        c.sortOrder !== target.sortOrder && c.isTerminal && c.countsTowardTarget
    ).length;
    if (
      target.isTerminal &&
      target.countsTowardTarget &&
      wonTerminalRemaining === 0
    ) {
      return "At least one Won/terminal category (Target) is required.";
    }
    // Non-terminal pipeline anchor remaining after removal
    const nonTerminalRemaining = cats.filter(
      (c) => c.sortOrder !== target.sortOrder && !c.isTerminal
    ).length;
    if (!target.isTerminal && nonTerminalRemaining === 0) {
      return "At least one non-terminal pipeline category is required.";
    }
    return null;
  }

  /** Live preview of Final and Stretch totals (placeholder amounts). */
  get finalPreviewParts() {
    const cats = this.wizardData?.categories || [];
    return cats
      .filter((c) => c.countsTowardTarget)
      .map((c) => c.label || c.name)
      .join(" + ");
  }

  get stretchPreviewParts() {
    const cats = this.wizardData?.categories || [];
    return cats
      .filter((c) => c.countsTowardStretch)
      .map((c) => c.label || c.name)
      .join(" + ");
  }

  get finalLabelDisplay() {
    return this.wizardData?.finalForecastLabel || "Final Forecast";
  }

  get stretchLabelDisplay() {
    return this.wizardData?.stretchForecastLabel || "Stretch Forecast";
  }

  handleCategoryTemplateChange(event) {
    const template = event.detail.value;
    this.fireChange("categoryTemplate", template);
    const cats = JSON.parse(
      JSON.stringify(
        CATEGORY_TEMPLATES[template] || CATEGORY_TEMPLATES.standard
      )
    );
    cats.forEach((c) => {
      c._colorStyle = "background-color: " + c.color;
    });
    this.fireChange("categories", cats);
  }

  handleCatFieldChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const field = event.target.dataset.field;
    const cats = JSON.parse(JSON.stringify(this.wizardData.categories));
    const c = cats.find((ct) => ct.sortOrder === idx);
    if (c) {
      c[field] = event.detail.value || event.target.value;
      if (field === "label") {
        c.name = c.label;
        c.apiName = c.label.replace(/\s+/g, "_");
      }
      if (field === "color") {
        c._colorStyle = "background-color: " + c.color;
      }
    }
    this.fireChange("categories", cats);
  }

  handleCatCheckChange(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const field = event.target.dataset.field;
    const cats = JSON.parse(JSON.stringify(this.wizardData.categories));
    const c = cats.find((ct) => ct.sortOrder === idx);
    if (c) {
      c[field] = event.target.checked;
    }
    this.fireChange("categories", cats);
  }

  handleAddCategory() {
    const cats = JSON.parse(JSON.stringify(this.wizardData?.categories || []));
    const nextOrder = cats.length + 1;
    const baseLabel = "New Category " + nextOrder;
    cats.push({
      name: baseLabel,
      label: baseLabel,
      apiName: "New_Category_" + nextOrder,
      color: "#9E9E9E",
      countsTowardTarget: false,
      countsTowardStretch: false,
      isTerminal: false,
      isHighConfidence: false,
      regressionWarning: false,
      sortOrder: nextOrder,
      _colorStyle: "background-color: #9E9E9E"
    });
    this.fireChange("categories", cats);
    // Switch template flag to custom so the user knows they're now editing freely
    if (this.wizardData?.categoryTemplate !== "custom") {
      this.fireChange("categoryTemplate", "custom");
    }
  }

  handleRemoveCategory(event) {
    const idx = parseInt(event.target.dataset.index, 10);
    const cats = this.wizardData?.categories || [];
    const target = cats.find((c) => c.sortOrder === idx);
    if (!target) return;
    const reason = this._deleteDisabledReason(cats, target);
    if (reason) {
      // Should be guarded by disabled button; defensive guard kept anyway.
      return;
    }
    let next = JSON.parse(JSON.stringify(cats)).filter(
      (c) => c.sortOrder !== idx
    );
    next.forEach((c, i) => {
      c.sortOrder = i + 1;
    });
    this.fireChange("categories", next);
    if (this.wizardData?.categoryTemplate !== "custom") {
      this.fireChange("categoryTemplate", "custom");
    }
  }

  handleFinalLabelChange(event) {
    this.fireChange("finalForecastLabel", event.detail.value);
  }

  handleStretchLabelChange(event) {
    this.fireChange("stretchForecastLabel", event.detail.value);
  }

  fireChange(field, value) {
    this.dispatchEvent(
      new CustomEvent("stepdatachange", { detail: { field, value } })
    );
  }
}
