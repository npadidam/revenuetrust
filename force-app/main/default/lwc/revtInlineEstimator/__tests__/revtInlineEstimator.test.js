import { createElement } from "lwc";
import RevtInlineEstimator from "c/revtInlineEstimator";

describe("c-revt-inline-estimator", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders payout and rate when data present", () => {
    const element = createElement("c-revt-inline-estimator", {
      is: RevtInlineEstimator
    });
    element.payoutEstimate = 24000;
    element.incentiveRate = 8;
    element.tierImpact = "No tier change";
    document.body.appendChild(element);

    const payout = element.shadowRoot.querySelector(".estimator-payout");
    expect(payout).not.toBeNull();

    const rate = element.shadowRoot.querySelector(".estimator-rate");
    expect(rate).not.toBeNull();
  });

  it("shows no-data dash when empty", () => {
    const element = createElement("c-revt-inline-estimator", {
      is: RevtInlineEstimator
    });
    document.body.appendChild(element);

    const noData = element.shadowRoot.querySelector(".no-data");
    expect(noData).not.toBeNull();
  });

  it("highlights tier crossing", () => {
    const element = createElement("c-revt-inline-estimator", {
      is: RevtInlineEstimator
    });
    element.payoutEstimate = 50000;
    element.incentiveRate = 12;
    element.tierImpact = "Crosses → Tier 3 (+4.0%)";
    document.body.appendChild(element);

    const crossing = element.shadowRoot.querySelector(".tier-crossing");
    expect(crossing).not.toBeNull();
    expect(crossing.textContent).toContain("Crosses");

    const container = element.shadowRoot.querySelector(".inline-estimator");
    expect(container.classList.contains("has-crossing")).toBe(true);
  });

  it("builds tooltip with all fields", () => {
    const element = createElement("c-revt-inline-estimator", {
      is: RevtInlineEstimator
    });
    element.payoutEstimate = 24000;
    element.incentiveRate = 8;
    element.thresholdProximity = 80000;
    element.tierImpact = "No tier change";
    document.body.appendChild(element);

    const container = element.shadowRoot.querySelector(".inline-estimator");
    expect(container.title).toContain("Estimated payout");
    expect(container.title).toContain("Current rate");
    expect(container.title).toContain("Distance to next tier");
  });
});
