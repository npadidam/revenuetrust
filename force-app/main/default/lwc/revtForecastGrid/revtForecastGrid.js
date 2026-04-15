import { LightningElement, api } from "lwc";

export default class RevtForecastGrid extends LightningElement {
  @api records = [];
  @api config;
  @api context;
  @api summary;
  @api currentPage = 1;
  @api totalCount = 0;
  @api pageSize = 40;
  @api isLocked = false;
  @api showHealthBadge;
  @api showInlineEstimator;
  @api periodId;
  @api dirtyRecordIds = [];
  @api rowErrorMap = {};
  @api expandedRowId;

  sortField = "recordName";
  sortDirection = "ASC";

  // ── Dynamic column headers ──

  get metricHeaders() {
    if (!this.config || !this.config.metrics) return [];
    return this.config.metrics
      .filter((m) => m.isEditable)
      .map((m, idx) => ({
        key: "metric_" + (idx + 1),
        label: m.label || m.name
      }));
  }

  // ── Sorting ──

  get sortIcon() {
    return this.sortDirection === "ASC"
      ? "utility:arrowup"
      : "utility:arrowdown";
  }

  get isSortedByName() {
    return this.sortField === "recordName";
  }
  get isSortedByOwner() {
    return this.sortField === "ownerName";
  }
  get isSortedByCloseDate() {
    return this.sortField === "closeDate";
  }

  get getAriaSort_recordName() {
    return this.isSortedByName
      ? this.sortDirection.toLowerCase() + "ending"
      : "none";
  }
  get getAriaSort_ownerName() {
    return this.isSortedByOwner
      ? this.sortDirection.toLowerCase() + "ending"
      : "none";
  }
  get getAriaSort_closeDate() {
    return this.isSortedByCloseDate
      ? this.sortDirection.toLowerCase() + "ending"
      : "none";
  }

  handleSortName() {
    this.toggleSort("recordName");
  }
  handleSortOwner() {
    this.toggleSort("ownerName");
  }
  handleSortCloseDate() {
    this.toggleSort("closeDate");
  }
  handleSortHealth() {
    this.toggleSort("healthScore");
  }
  handleSortCategory() {
    this.toggleSort("category");
  }

  handleSortMetric(event) {
    const field = event.currentTarget.dataset.sortField;
    this.toggleSort(field || "metricValue");
  }

  toggleSort(field) {
    if (this.sortField === field) {
      this.sortDirection = this.sortDirection === "ASC" ? "DESC" : "ASC";
    } else {
      this.sortField = field;
      this.sortDirection = "ASC";
    }
    this.dispatchEvent(
      new CustomEvent("sort", {
        detail: { sortField: this.sortField, sortDirection: this.sortDirection }
      })
    );
  }

  // ── Pagination ──

  get totalPages() {
    return Math.max(1, Math.ceil(this.totalCount / this.pageSize));
  }

  get showingFrom() {
    if (this.totalCount === 0) return 0;
    return (this.currentPage - 1) * this.pageSize + 1;
  }

  get showingTo() {
    return Math.min(this.currentPage * this.pageSize, this.totalCount);
  }

  get pageLabel() {
    return "Page " + this.currentPage + " of " + this.totalPages;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1 || this.isLocked;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages || this.isLocked;
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: this.currentPage - 1 }
        })
      );
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.dispatchEvent(
        new CustomEvent("pagechange", {
          detail: { pageNumber: this.currentPage + 1 }
        })
      );
    }
  }

  // ── Keyboard navigation (§17.7) ──

  handleKeyDown(event) {
    const target = event.target;
    const rowId = target.closest("[data-row-id]")?.dataset.rowId;
    const colId = target.closest("[data-column-id]")?.dataset.columnId;

    if (!rowId || !colId) return;

    switch (event.key) {
      case "Tab":
        // Default browser tab behavior handles cell-to-cell
        break;
      case "Enter":
        // Move to same column in next row
        event.preventDefault();
        this.moveFocus(rowId, colId, "down");
        break;
      case "Escape":
        // Revert to last saved value — dispatch event for parent to handle
        this.dispatchEvent(
          new CustomEvent("cellrevert", {
            detail: { recordId: rowId, field: colId }
          })
        );
        break;
      case "ArrowUp":
        if (event.altKey) {
          event.preventDefault();
          this.moveFocus(rowId, colId, "up");
        }
        break;
      case "ArrowDown":
        if (event.altKey) {
          event.preventDefault();
          this.moveFocus(rowId, colId, "down");
        }
        break;
      default:
        break;
    }
  }

  moveFocus(currentRowId, columnId, direction) {
    const rows = this.template.querySelectorAll("c-revt-forecast-row");
    const rowArray = Array.from(rows);
    const currentIndex = rowArray.findIndex(
      (r) => r.record && r.record.recordId === currentRowId
    );
    const targetIndex =
      direction === "down" ? currentIndex + 1 : currentIndex - 1;

    if (targetIndex >= 0 && targetIndex < rowArray.length) {
      const targetRow = rowArray[targetIndex];
      const targetCell = targetRow.querySelector(
        `[data-column-id="${columnId}"] input, [data-column-id="${columnId}"] select`
      );
      if (targetCell) {
        targetCell.focus();
      }
    }
  }
}
