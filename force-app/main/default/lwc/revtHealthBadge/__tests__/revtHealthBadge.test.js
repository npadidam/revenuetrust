import { createElement } from "lwc";
import RevtHealthBadge from "c/revtHealthBadge";

describe("c-revt-health-badge", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders green badge for high score", () => {
    const element = createElement("c-revt-health-badge", {
      is: RevtHealthBadge
    });
    element.healthScore = 85;
    element.healthBand = "Green";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector(".health-badge");
    expect(badge).not.toBeNull();
    expect(badge.classList.contains("band-green")).toBe(true);

    const score = element.shadowRoot.querySelector(".score-text");
    expect(score.textContent).toBe("85");
  });

  it("renders yellow badge for medium score", () => {
    const element = createElement("c-revt-health-badge", {
      is: RevtHealthBadge
    });
    element.healthScore = 55;
    element.healthBand = "Yellow";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector(".health-badge");
    expect(badge.classList.contains("band-yellow")).toBe(true);
  });

  it("renders red badge for low score", () => {
    const element = createElement("c-revt-health-badge", {
      is: RevtHealthBadge
    });
    element.healthScore = 20;
    element.healthBand = "Red";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector(".health-badge");
    expect(badge.classList.contains("band-red")).toBe(true);
  });

  it("renders default badge when no data", () => {
    const element = createElement("c-revt-health-badge", {
      is: RevtHealthBadge
    });
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector(".health-badge");
    expect(badge.classList.contains("band-none")).toBe(true);

    const score = element.shadowRoot.querySelector(".score-text");
    expect(score).toBeNull();
  });

  it("shows correct tooltip", () => {
    const element = createElement("c-revt-health-badge", {
      is: RevtHealthBadge
    });
    element.healthScore = 85;
    element.healthBand = "Green";
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector(".health-badge");
    expect(badge.title).toContain("85/100");
    expect(badge.title).toContain("Healthy");
  });
});
