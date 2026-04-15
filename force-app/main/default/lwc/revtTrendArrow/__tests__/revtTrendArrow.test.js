import { createElement } from "lwc";
import RevtTrendArrow from "c/revtTrendArrow";

describe("c-revt-trend-arrow", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders up arrow for positive trend", () => {
    const element = createElement("c-revt-trend-arrow", { is: RevtTrendArrow });
    element.trend = 1;
    document.body.appendChild(element);

    const span = element.shadowRoot.querySelector(".trend-arrow");
    expect(span.classList.contains("trend-up")).toBe(true);
    expect(span.title).toContain("Up");
  });

  it("renders down arrow for negative trend", () => {
    const element = createElement("c-revt-trend-arrow", { is: RevtTrendArrow });
    element.trend = -1;
    document.body.appendChild(element);

    const span = element.shadowRoot.querySelector(".trend-arrow");
    expect(span.classList.contains("trend-down")).toBe(true);
    expect(span.title).toContain("Down");
  });

  it("renders dash for flat trend", () => {
    const element = createElement("c-revt-trend-arrow", { is: RevtTrendArrow });
    element.trend = 0;
    document.body.appendChild(element);

    const span = element.shadowRoot.querySelector(".trend-arrow");
    expect(span.classList.contains("trend-flat")).toBe(true);
    expect(span.title).toContain("No change");
  });

  it("includes label in tooltip when provided", () => {
    const element = createElement("c-revt-trend-arrow", { is: RevtTrendArrow });
    element.trend = 1;
    element.label = "Revenue";
    document.body.appendChild(element);

    const span = element.shadowRoot.querySelector(".trend-arrow");
    expect(span.title).toContain("Revenue");
  });

  it("handles string trend values", () => {
    const element = createElement("c-revt-trend-arrow", { is: RevtTrendArrow });
    element.trend = "1";
    document.body.appendChild(element);

    const span = element.shadowRoot.querySelector(".trend-arrow");
    expect(span.classList.contains("trend-up")).toBe(true);
  });
});
