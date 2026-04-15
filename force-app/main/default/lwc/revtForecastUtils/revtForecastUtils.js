/**
 * @description Shared utility functions for the Forecasting LWC module.
 *              JS-only module — no HTML template. Import via c/revtForecastUtils.
 *              Spec: FORECASTING_LWC_COMPONENTS.md §17.2, §17.3, §17.12, §17.13
 */

/**
 * Debounce a function call. Returns a wrapper that delays invocation
 * until `delay` ms have passed since the last call.
 * @param {Function} fn - Function to debounce
 * @param {number} delay - Delay in milliseconds
 * @returns {Function} Debounced function
 */
export function debounce(fn, delay) {
  let timeoutId;
  return function (...args) {
    clearTimeout(timeoutId);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    timeoutId = setTimeout(() => fn.apply(this, args), delay);
  };
}

/**
 * Format a number as currency.
 * @param {number} value
 * @param {string} currencyCode - ISO 4217 code (e.g., 'USD')
 * @param {string} locale - BCP 47 locale (default 'en-US')
 * @returns {string} Formatted currency string
 */
export function formatCurrency(value, currencyCode = "USD", locale = "en-US") {
  if (value == null) return "";
  try {
    return new Intl.NumberFormat(locale, {
      style: "currency",
      currency: currencyCode,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    }).format(value);
  } catch {
    // ignored
    return String(value);
  }
}

/**
 * Format a number as percentage.
 * @param {number} value - Value as a whole number (e.g., 72 for 72%)
 * @returns {string} Formatted percentage string
 */
export function formatPercent(value) {
  if (value == null) return "";
  try {
    return new Intl.NumberFormat("en-US", {
      style: "percent",
      minimumFractionDigits: 1,
      maximumFractionDigits: 1
    }).format(value / 100);
  } catch {
    // ignored
    return value + "%";
  }
}

/**
 * Split an array into chunks of a given size.
 * Used for save batching at 50 records per chunk.
 * @param {Array} array
 * @param {number} size - Chunk size
 * @returns {Array<Array>} Array of chunks
 */
export function chunkArray(array, size) {
  if (!array || !array.length) return [];
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

/**
 * Generate a CSV Blob from column headers and row data.
 * Used for client-side export when ≤500 records.
 * @param {Array<string>} columns - Header labels
 * @param {Array<Array<string>>} rows - Row data (each row is array of cell values)
 * @returns {Blob} CSV blob for download
 */
export function generateCsvBlob(columns, rows) {
  const escapeCsv = (val) => {
    if (val == null) return "";
    const str = String(val);
    if (str.includes(",") || str.includes('"') || str.includes("\n")) {
      return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
  };

  const lines = [];
  lines.push(columns.map(escapeCsv).join(","));
  for (const row of rows) {
    lines.push(row.map(escapeCsv).join(","));
  }
  return new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8;" });
}

/**
 * Trigger a browser download from a Blob or CSV content string.
 * @param {Blob|string} content - Blob or raw CSV string
 * @param {string} fileName - Download filename
 * @param {string} mimeType - MIME type (default 'text/csv')
 */
export function downloadFile(content, fileName, mimeType = "text/csv") {
  let blob;
  if (content instanceof Blob) {
    blob = content;
  } else {
    blob = new Blob([content], { type: mimeType });
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  a.click();
  URL.revokeObjectURL(url);
}

/**
 * Parse Apex error message prefix to determine error category.
 * Returns one of: 'CONFLICT', 'VALIDATION', 'PERMISSION', 'GOVERNOR', 'NETWORK', 'EXCEPTION'
 * @param {string} errorMessage
 * @returns {{ category: string, recordId: string|null, details: string }}
 */
export function parseErrorPrefix(errorMessage) {
  if (!errorMessage)
    return { category: "EXCEPTION", recordId: null, details: "" };

  const prefixes = ["CONFLICT", "VALIDATION", "PERMISSION", "GOVERNOR"];
  for (const prefix of prefixes) {
    if (errorMessage.startsWith(prefix + ":")) {
      const parts = errorMessage.split(":");
      return {
        category: prefix,
        recordId: parts.length > 1 ? parts[1] : null,
        details: parts.length > 2 ? parts.slice(2).join(":") : ""
      };
    }
  }

  if (
    errorMessage.includes("network") ||
    errorMessage.includes("Failed to fetch")
  ) {
    return { category: "NETWORK", recordId: null, details: errorMessage };
  }

  return { category: "EXCEPTION", recordId: null, details: errorMessage };
}

/**
 * Safe sessionStorage get. Returns null if storage is unavailable (Locker Service).
 * @param {string} key
 * @returns {*} Parsed value or null
 */
export function sessionStorageGet(key) {
  try {
    const raw = sessionStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    // ignored
    return null;
  }
}

/**
 * Safe sessionStorage set. Silently fails if storage is unavailable.
 * @param {string} key
 * @param {*} value - Will be JSON.stringify'd
 */
export function sessionStorageSet(key, value) {
  try {
    sessionStorage.setItem(key, JSON.stringify(value));
  } catch {
    // ignored
    // Locker Service or storage quota — degrade gracefully
  }
}

/**
 * Safe sessionStorage remove.
 * @param {string} key
 */
export function sessionStorageRemove(key) {
  try {
    sessionStorage.removeItem(key);
  } catch {
    // ignored
    // ignore
  }
}

/**
 * Client-side tier impact calculation for the inline estimator.
 * Uses cached attainment + tier data — no server call.
 * @param {object} attainment - { target, achieved, currentTier, currentRate }
 * @param {number} editedMetricSum - Sum of edited metric values
 * @param {Array} tiers - Array of { name, minAttainmentPct, maxAttainmentPct, ratePct }
 * @returns {{ payoutEstimate: number, projectedTier: string, projectedRate: number, tierImpact: string }}
 */
export function computeTierImpact(attainment, editedMetricSum, tiers) {
  if (
    !attainment ||
    !attainment.target ||
    attainment.target === 0 ||
    !tiers ||
    !tiers.length
  ) {
    return {
      payoutEstimate: 0,
      projectedTier: null,
      projectedRate: 0,
      tierImpact: "No tier data"
    };
  }

  const newProjected = (attainment.achieved || 0) + (editedMetricSum || 0);
  const newAttainmentPct = (newProjected / attainment.target) * 100;

  let projectedTier = null;
  for (const tier of tiers) {
    if (
      newAttainmentPct >= tier.minAttainmentPct &&
      (tier.maxAttainmentPct == null ||
        newAttainmentPct < tier.maxAttainmentPct)
    ) {
      projectedTier = tier;
      break;
    }
  }

  if (!projectedTier) {
    return {
      payoutEstimate: 0,
      projectedTier: null,
      projectedRate: 0,
      tierImpact: "Below threshold"
    };
  }

  const payoutEstimate = editedMetricSum * (projectedTier.ratePct / 100);
  const currentTierName = attainment.currentTier || "";
  const tierCrossed = projectedTier.name !== currentTierName;

  let tierImpact;
  if (tierCrossed) {
    const rateDelta = projectedTier.ratePct - (attainment.currentRate || 0);
    const sign = rateDelta >= 0 ? "+" : "";
    tierImpact = `Crosses → ${projectedTier.name} (${sign}${rateDelta.toFixed(1)}%)`;
  } else {
    tierImpact = "No tier change";
  }

  return {
    payoutEstimate,
    projectedTier: projectedTier.name,
    projectedRate: projectedTier.ratePct,
    tierImpact
  };
}

/**
 * Status color map — left border colors for forecast row status.
 * Maps to CSS custom properties: --revt-status-{name} (§9)
 */
export const STATUS_COLORS = {
  New: "#B0B0B0", // --revt-status-new
  Saved: "#1589EE", // --revt-status-saved
  Submitted: "#04844B", // --revt-status-submitted
  Frozen: "#7B64FF", // --revt-status-frozen
  Dirty: "#F2CF00", // --revt-status-dirty
  Not_Started: "#B0B0B0" // --revt-status-new
};

/**
 * Health band configuration — color and icon per band.
 * Maps to CSS custom properties: --revt-health-{band} (§9)
 */
export const HEALTH_BAND_CONFIG = {
  Green: { color: "#04844B", icon: "utility:like", label: "Healthy" }, // --revt-health-green
  Yellow: { color: "#F2CF00", icon: "utility:warning", label: "At Risk" }, // --revt-health-yellow
  Red: { color: "#EA001E", icon: "utility:ban", label: "Critical" } // --revt-health-red
};

/**
 * Default fallback for health badge when no data.
 */
export const HEALTH_BAND_DEFAULT = {
  color: "#706E6B",
  icon: "utility:dash",
  label: "No Data"
};
