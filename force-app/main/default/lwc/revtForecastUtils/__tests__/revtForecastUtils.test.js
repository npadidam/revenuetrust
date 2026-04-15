import {
  debounce,
  formatCurrency,
  formatPercent,
  chunkArray,
  parseErrorPrefix,
  computeTierImpact,
  STATUS_COLORS,
  HEALTH_BAND_CONFIG
} from "c/revtForecastUtils";

describe("revtForecastUtils", () => {
  // ── debounce ──

  describe("debounce", () => {
    beforeEach(() => jest.useFakeTimers());
    afterEach(() => jest.useRealTimers());

    it("delays function execution", () => {
      const fn = jest.fn();
      const debounced = debounce(fn, 250);
      debounced();
      expect(fn).not.toHaveBeenCalled();
      jest.advanceTimersByTime(250);
      expect(fn).toHaveBeenCalledTimes(1);
    });

    it("resets timer on subsequent calls", () => {
      const fn = jest.fn();
      const debounced = debounce(fn, 250);
      debounced();
      jest.advanceTimersByTime(100);
      debounced();
      jest.advanceTimersByTime(200);
      expect(fn).not.toHaveBeenCalled();
      jest.advanceTimersByTime(50);
      expect(fn).toHaveBeenCalledTimes(1);
    });
  });

  // ── formatCurrency ──

  describe("formatCurrency", () => {
    it("formats USD currency", () => {
      const result = formatCurrency(250000, "USD");
      expect(result).toContain("250,000");
    });

    it("returns empty string for null", () => {
      expect(formatCurrency(null)).toBe("");
    });

    it("returns empty string for undefined", () => {
      expect(formatCurrency(undefined)).toBe("");
    });
  });

  // ── formatPercent ──

  describe("formatPercent", () => {
    it("formats percentage from whole number", () => {
      const result = formatPercent(72);
      expect(result).toContain("72");
      expect(result).toContain("%");
    });

    it("returns empty string for null", () => {
      expect(formatPercent(null)).toBe("");
    });
  });

  // ── chunkArray ──

  describe("chunkArray", () => {
    it("splits array into chunks of given size", () => {
      const arr = [1, 2, 3, 4, 5, 6, 7];
      const result = chunkArray(arr, 3);
      expect(result).toEqual([[1, 2, 3], [4, 5, 6], [7]]);
    });

    it("returns single chunk for small array", () => {
      expect(chunkArray([1, 2], 5)).toEqual([[1, 2]]);
    });

    it("returns empty array for null input", () => {
      expect(chunkArray(null, 5)).toEqual([]);
    });

    it("returns empty array for empty input", () => {
      expect(chunkArray([], 5)).toEqual([]);
    });
  });

  // ── parseErrorPrefix ──

  describe("parseErrorPrefix", () => {
    it("parses CONFLICT error", () => {
      const result = parseErrorPrefix("CONFLICT:006ABC:Record modified");
      expect(result.category).toBe("CONFLICT");
      expect(result.recordId).toBe("006ABC");
      expect(result.details).toBe("Record modified");
    });

    it("parses VALIDATION error", () => {
      const result = parseErrorPrefix("VALIDATION:006ABC:Invalid category");
      expect(result.category).toBe("VALIDATION");
      expect(result.recordId).toBe("006ABC");
    });

    it("parses PERMISSION error", () => {
      const result = parseErrorPrefix("PERMISSION:Insufficient access");
      expect(result.category).toBe("PERMISSION");
    });

    it("detects NETWORK errors", () => {
      const result = parseErrorPrefix("Failed to fetch");
      expect(result.category).toBe("NETWORK");
    });

    it("defaults to EXCEPTION for unknown errors", () => {
      const result = parseErrorPrefix("Something went wrong");
      expect(result.category).toBe("EXCEPTION");
    });

    it("handles null input", () => {
      const result = parseErrorPrefix(null);
      expect(result.category).toBe("EXCEPTION");
    });
  });

  // ── computeTierImpact ──

  describe("computeTierImpact", () => {
    const tiers = [
      { name: "Tier 1", minAttainmentPct: 0, maxAttainmentPct: 80, ratePct: 5 },
      {
        name: "Tier 2",
        minAttainmentPct: 80,
        maxAttainmentPct: 100,
        ratePct: 8
      },
      {
        name: "Tier 3",
        minAttainmentPct: 100,
        maxAttainmentPct: null,
        ratePct: 12
      }
    ];

    it("calculates tier crossing", () => {
      const attainment = {
        target: 1000000,
        achieved: 780000,
        currentTier: "Tier 1",
        currentRate: 5
      };
      const result = computeTierImpact(attainment, 50000, tiers);
      expect(result.projectedTier).toBe("Tier 2");
      expect(result.tierImpact).toContain("Crosses");
      expect(result.tierImpact).toContain("Tier 2");
    });

    it("reports no tier change", () => {
      const attainment = {
        target: 1000000,
        achieved: 850000,
        currentTier: "Tier 2",
        currentRate: 8
      };
      const result = computeTierImpact(attainment, 50000, tiers);
      expect(result.projectedTier).toBe("Tier 2");
      expect(result.tierImpact).toBe("No tier change");
    });

    it("handles missing attainment data", () => {
      const result = computeTierImpact(null, 50000, tiers);
      expect(result.tierImpact).toBe("No tier data");
    });

    it("handles empty tiers", () => {
      const attainment = {
        target: 1000000,
        achieved: 500000,
        currentTier: null,
        currentRate: 0
      };
      const result = computeTierImpact(attainment, 50000, []);
      expect(result.tierImpact).toBe("No tier data");
    });
  });

  // ── Constants ──

  describe("constants", () => {
    it("STATUS_COLORS has expected keys", () => {
      expect(STATUS_COLORS.New).toBeDefined();
      expect(STATUS_COLORS.Saved).toBeDefined();
      expect(STATUS_COLORS.Submitted).toBeDefined();
      expect(STATUS_COLORS.Frozen).toBeDefined();
      expect(STATUS_COLORS.Dirty).toBeDefined();
    });

    it("HEALTH_BAND_CONFIG has Green/Yellow/Red", () => {
      expect(HEALTH_BAND_CONFIG.Green).toBeDefined();
      expect(HEALTH_BAND_CONFIG.Green.icon).toBe("utility:like");
      expect(HEALTH_BAND_CONFIG.Yellow.icon).toBe("utility:warning");
      expect(HEALTH_BAND_CONFIG.Red.icon).toBe("utility:ban");
    });
  });
});
