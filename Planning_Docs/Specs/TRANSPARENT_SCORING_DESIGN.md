# Transparent Composite Health Score — Design Specification

**Platform:** Revenue Execution Platform  
**Feature:** Deal Health Score — Deterministic, Explainable, User-Configurable  
**Date:** 2026-04-01

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Score Architecture — Four Layers](#2-score-architecture--four-layers)
3. [Component Definitions](#3-component-definitions)
4. [Adjustment Rules](#4-adjustment-rules)
5. [Weight Configuration System](#5-weight-configuration-system)
6. [Missing Signal Handling](#6-missing-signal-handling)
7. [Score Card UI — Breakdown Panel](#7-score-card-ui--breakdown-panel)
8. [Weight Configuration UI](#8-weight-configuration-ui)
9. [Score Change Audit Trail](#9-score-change-audit-trail)
10. [Data Model](#10-data-model)
11. [Calculation Engine — Pseudocode](#11-calculation-engine--pseudocode)
12. [API Specification](#12-api-specification)

---

## 1. Design Philosophy

### Glass Box, Not Black Box

Most composite scoring systems in sales software are black boxes. A vendor gives you a number, and you either trust it or you don't. When reps and managers don't understand _why_ a deal is scored 43, they dismiss the score and go with gut instinct — which defeats the purpose entirely.

This platform takes the opposite approach:

| Principle              | What It Means                                                                                                                                                                    |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Deterministic**      | Given the same inputs, the score always produces the same output. No hidden ML adjustments, no drift, no surprise changes.                                                       |
| **Fully decomposable** | Every point in the score can be traced to a specific signal from a specific source at a specific time.                                                                           |
| **User-configurable**  | Weights are visible and adjustable. A manager who knows their team's deals are phone-heavy can up-weight call signals. A CS-led account team can up-weight relationship signals. |
| **Honest about gaps**  | When a signal source is not connected, the score says so explicitly and shows how the weights were redistributed — rather than silently producing a misleading number.           |
| **Auditable**          | Every score change is logged with the reason. You can replay the score history of any deal and see exactly what signal changed it.                                               |

### What Is Deterministic vs. What Is ML

The health score itself is **deterministic** — a pure formula. No model, no training data, no drift.

The **close probability** (a separate field) is ML-based. These are two different things shown side by side:

```
Deal: Barclays — Q2 Subscription — $1.2M

  Health Score:    67 / 100    [Deterministic — see breakdown]
  Close Probability:  71%      [AI model — based on historical patterns]
  Manager Category:   Forecast
```

This distinction matters for trust. Users understand a formula. They are suspicious of a model. Showing both — clearly labelled — gives them the model's prediction while grounding it in the deterministic signal they can verify.

---

## 2. Score Architecture — Four Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                  COMPOSITE HEALTH SCORE (0–100)                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
  │  LAYER 1      │ │   LAYER 2     │ │   LAYER 3     │
  │  Components   │ │  Adjustments  │ │   Weights     │
  │  (raw scores) │ │  (+/- points) │ │  (% per comp) │
  └───────────────┘ └───────────────┘ └───────────────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   LAYER 4       │
                  │  Redistribution │
                  │  (missing sigs) │
                  └─────────────────┘
```

### Layer 1: Components (Weighted Sub-Scores)

Four components, each scored 0–100, each with a configurable weight:

| Component              | Default Weight | Signal Source            | What It Measures                                            |
| ---------------------- | -------------- | ------------------------ | ----------------------------------------------------------- |
| **Vendor Score**       | 40%            | Gong / Zoom RA / Dialpad | AI-assessed deal health from conversation intelligence      |
| **Relationship Score** | 25%            | Momentum / Teams Graph   | Stakeholder engagement depth and relationship strength      |
| **Activity Recency**   | 20%            | All sources              | How recently the deal was touched by either party           |
| **Engagement Depth**   | 15%            | All sources              | Breadth of engagement — contacts, meetings, multi-threading |

### Layer 2: Adjustments (Flat Point Modifiers)

Applied after weighted calculation. Each adjustment is a signed integer with a reason code:

| Adjustment                    | Points | Trigger                                                      |
| ----------------------------- | ------ | ------------------------------------------------------------ |
| Competitor mentioned          | −15    | `competitor_mentioned = TRUE` in last 30 days                |
| Decision maker gone dark      | −20    | `dm_last_response_date > 21 days`                            |
| Multiple no-shows             | −10    | `meeting_no_show_count >= 2` in last 30 days                 |
| Next step confirmed           | +10    | `next_step_confirmed = TRUE` in last call                    |
| Decision maker on recent call | +8     | `decision_maker_on_call = TRUE` in last 14 days              |
| Multi-threaded (4+ contacts)  | +5     | `stakeholder_count >= 4`                                     |
| Champion re-engaged           | +7     | `champion_last_response_date` within 7 days after being dark |

Score is clamped to [0, 100] after adjustments.

### Layer 3: Weights

Configurable at four levels (detailed in Section 5).

### Layer 4: Missing Signal Redistribution

When a signal source is not connected, its weight does not silently contribute a neutral 50 — it is redistributed proportionally to the connected components (detailed in Section 6).

---

## 3. Component Definitions

### Component 1: Vendor Score (Default Weight: 40%)

Maps the primary conversation intelligence vendor's score to a 0–100 scale.

| Source                   | Raw Field                                               | Mapping                                                  |
| ------------------------ | ------------------------------------------------------- | -------------------------------------------------------- |
| Gong                     | `gong_risk_score` (0–100, where 100 = highest risk)     | `100 - gong_risk_score` (invert: high risk = low health) |
| Zoom Revenue Accelerator | `zoom_revenue_accel_score` (0–100, where 100 = healthy) | Direct: `zoom_revenue_accel_score`                       |
| Dialpad                  | `dialpad_call_score` (0–100, where 100 = best)          | Direct: `dialpad_call_score`                             |
| None connected           | —                                                       | Component marked as missing; weight redistributed        |

Only one vendor score is used per deal (the primary connected vendor). If multiple are connected, priority order: Gong → Zoom Revenue Accelerator → Dialpad.

**Why invert Gong?** Gong's risk score is a _risk_ score — high means bad. All platform components are health-oriented — high means good. Inversion makes the model consistent. This inversion is shown transparently in the breakdown panel.

---

### Component 2: Relationship Score (Default Weight: 25%)

Composite of stakeholder engagement signals.

```
relationship_component = weighted_avg([
    decision_maker_engagement_score  * 0.40,
    champion_relationship_score      * 0.35,
    overall_stakeholder_score        * 0.25
])

where:

decision_maker_engagement_score:
    dm_last_response_date within 7 days  → 100
    dm_last_response_date 7–14 days      → 75
    dm_last_response_date 14–21 days     → 45
    dm_last_response_date > 21 days      → 15
    dm never contacted                   → 0

champion_relationship_score:
    momentum_score (if Momentum connected) → direct (0–100)
    else: fallback based on email_response_time_hrs:
        < 2 hrs   → 90
        2–8 hrs   → 75
        8–24 hrs  → 55
        24–48 hrs → 35
        > 48 hrs  → 15
        no data   → 50 (neutral, flagged as estimated)

overall_stakeholder_score:
    stakeholder_count >= 5 → 100
    stakeholder_count = 4  → 80
    stakeholder_count = 3  → 60
    stakeholder_count = 2  → 40
    stakeholder_count = 1  → 20
    stakeholder_count = 0  → 0
```

---

### Component 3: Activity Recency (Default Weight: 20%)

```
activity_recency_score:
    days_since_last_activity = 0–3   → 100
    days_since_last_activity = 4–7   → 85
    days_since_last_activity = 8–14  → 65
    days_since_last_activity = 15–21 → 45
    days_since_last_activity = 22–30 → 25
    days_since_last_activity > 30    → 10
    no activity on record            → 0
```

**What counts as activity:** Outbound email, inbound email reply, phone call (connected), meeting attended by both parties, Slack/Teams message exchange (if integrated).

Activity must involve _both parties_ to count as an engagement signal. A rep sending an email with no response increments the rep's activity count but does not update `days_since_last_activity` (which tracks mutual activity).

---

### Component 4: Engagement Depth (Default Weight: 15%)

```
engagement_depth_score = weighted_avg([
    meeting_frequency_score    * 0.40,
    call_frequency_score       * 0.35,
    multi_channel_score        * 0.25
])

where:

meeting_frequency_score (meetings in last 30 days):
    >= 4 meetings → 100
    3 meetings    → 80
    2 meetings    → 60
    1 meeting     → 35
    0 meetings    → 0

call_frequency_score (connected calls in last 30 days):
    >= 5 calls → 100
    3–4 calls  → 80
    2 calls    → 60
    1 call     → 35
    0 calls    → 0

multi_channel_score (distinct channels used: email, call, meeting, Slack/Teams):
    4 channels → 100
    3 channels → 75
    2 channels → 50
    1 channel  → 25
    0 channels → 0
```

---

## 4. Adjustment Rules

Adjustments are applied after the weighted component score is calculated. Each adjustment:

- Has a name and reason code (shown in UI)
- Has a fixed point value (configurable by admin)
- Is directional (positive or negative)
- Is bounded: total adjustments cannot move the score below 0 or above 100

### Default Adjustment Table

| Adjustment Name                      | Code                 | Default Points | Trigger Condition                                          | Configurable?                    |
| ------------------------------------ | -------------------- | -------------- | ---------------------------------------------------------- | -------------------------------- |
| Competitor Mentioned                 | `competitor_flag`    | −15            | `competitor_mentioned = TRUE` in last 30 days              | ✅ Points only                   |
| DM Gone Dark                         | `dm_dark`            | −20            | `dm_last_response_date > 21 days` AND deal is not Won/Lost | ✅ Points + threshold            |
| Repeated No-Show                     | `no_show`            | −10            | `meeting_no_show_count >= 2` in last 30 days               | ✅ Points + count threshold      |
| Negative Sentiment Streak            | `neg_sentiment`      | −12            | Last 2+ consecutive calls have `call_sentiment = negative` | ✅ Points + streak length        |
| Next Step Confirmed                  | `next_step`          | +10            | `next_step_confirmed = TRUE` in last call                  | ✅ Points                        |
| DM on Recent Call                    | `dm_call`            | +8             | `decision_maker_on_call = TRUE` in last 14 days            | ✅ Points + recency              |
| Multi-Threaded                       | `multi_thread`       | +5             | `stakeholder_count >= 4`                                   | ✅ Points + threshold            |
| Champion Re-Engaged                  | `champion_reengaged` | +7             | Champion was dark > 14 days, now responded within 7 days   | ✅ Points                        |
| Proposal Opened                      | `proposal_open`      | +6             | Document tracking: proposal opened within 48 hrs           | ✅ Points (if DocSend connected) |
| Long Silence After Close-Plan Shared | `close_plan_silence` | −18            | Close plan/contract sent > 14 days ago, no response        | ✅ Points + threshold            |

### Adjustment Application Order

```
base_score = sum(component_score_i × weight_i) for all components
adjusted_score = base_score
for each applicable adjustment (ordered by priority, negative first):
    adjusted_score += adjustment.points
final_score = clamp(adjusted_score, 0, 100)
```

Negative adjustments applied before positive to prevent gaming (a deal with a competitor mention and a confirmed next step doesn't fully cancel out the risk).

---

## 5. Weight Configuration System

### Weight Hierarchy (Four Levels)

Weights can be set at four levels. Each level inherits from the level above unless explicitly overridden:

```
Platform Defaults  (set by product team, shipped with platform)
        │  inherits down unless overridden
        ▼
Tenant / Org Level (set by platform admin — applies to whole company)
        │  inherits down unless overridden
        ▼
Team Level         (set by manager — applies to their team's deals)
        │  inherits down unless overridden
        ▼
User Level         (set by individual rep/manager — applies to their own deal view only)
```

**Why allow team-level overrides?**

- A manager running a relationship-led enterprise sales motion knows that Gong call scores are less predictive for 12-month complex deals than relationship depth
- A manager running a transactional SMB motion knows call frequency is the best predictor
- Different motions need different weight profiles

**Why allow user-level overrides?**

- Gives reps agency and buy-in — they set the weights and then the score reflects their judgement, not just a platform default
- Reps who see their own deal ranked lower than they expect will investigate the signals rather than dismiss the score
- User-level overrides are visible to their manager — this creates a coaching conversation, not a hiding mechanism

### Weight Validation Rules

1. All four component weights must sum to exactly 100%
2. No single component weight can exceed 70% (prevents degenerate single-signal scores)
3. No single component weight can be set below 5% (all signals must contribute something)
4. Adjustment point values can be set to 0 (effectively disabling an adjustment) but cannot be inverted (a penalty cannot be made into a bonus)

### Weight Presets

Platform ships with named presets to make configuration accessible:

| Preset Name            | Vendor | Relationship | Recency | Depth | Best For                                   |
| ---------------------- | ------ | ------------ | ------- | ----- | ------------------------------------------ |
| **Balanced** (default) | 40%    | 25%          | 20%     | 15%   | General enterprise sales                   |
| **Conversation-Led**   | 55%    | 20%          | 15%     | 10%   | Transactional, high-call-volume teams      |
| **Relationship-Led**   | 20%    | 50%          | 20%     | 10%   | Strategic/enterprise, long cycle           |
| **Activity-First**     | 25%    | 20%          | 40%     | 15%   | High-velocity, volume-based sales          |
| **Multi-Stakeholder**  | 30%    | 25%          | 15%     | 30%   | Complex deals with large buying committees |

Admins can start from a preset and customise. Presets are labelled in the UI so everyone knows which profile is active for a given team.

---

## 6. Missing Signal Handling

When a signal source is not connected, the platform must not:

- Silently use a neutral value (misleading — looks like a signal when there is none)
- Collapse the score to 0 (punishes companies for not buying every integration)
- Hide the gap (users need to know what is missing)

**Rule: Redistribute, Declare, Highlight**

1. **Redistribute** the missing component's weight proportionally to the connected components
2. **Declare** in the score breakdown that the component is missing and weight was redistributed
3. **Highlight** the missing source with a "Connect [Source] for a more accurate score" prompt

### Redistribution Example

Scenario: Gong not connected (Vendor Score component missing).

Default weights: Vendor=40%, Relationship=25%, Recency=20%, Depth=15%

After redistribution (Vendor weight of 40% redistributed proportionally to remaining three):

```
total_connected_weight = 25 + 20 + 15 = 60

Relationship new weight = 25 + (40 × 25/60) = 25 + 16.7 = 41.7%
Recency new weight      = 20 + (40 × 20/60) = 20 + 13.3 = 33.3%
Depth new weight        = 15 + (40 × 15/60) = 15 + 10.0 = 25.0%

Total = 41.7 + 33.3 + 25.0 = 100% ✅
```

This is shown in the UI:

```
⚠️  Vendor Score (Gong/Zoom) not connected.
    Weight redistributed to connected signals.
    Connect Gong or Zoom for a more complete score.  [Connect →]
```

### Signal Freshness

Each signal has a `signal_updated` timestamp. If a signal is older than the configured staleness threshold, it is treated as degraded (not missing):

| Staleness   | Treatment                                                        |
| ----------- | ---------------------------------------------------------------- |
| < 24 hours  | Fresh — full weight                                              |
| 24–48 hours | Slightly stale — 90% weight, flagged in UI                       |
| 48–72 hours | Stale — 70% weight, warning in UI                                |
| > 72 hours  | Very stale — 50% weight, strong warning                          |
| > 7 days    | Treated as missing — weight redistributed, shown as disconnected |

---

## 7. Score Card UI — Breakdown Panel

### Trigger

Clicking the health badge (🟢/🟡/🔴) on any deal row in the forecast grid opens a **Score Card panel** (slide-in from right or inline expansion — user-configurable).

### Score Card Layout

```
╔══════════════════════════════════════════════════════════════╗
║  DEAL HEALTH SCORE                              ⚙ Adjust Weights
║                                                              ║
║   ╔════════╗   67 / 100   🟡 Watch                          ║
║   ║  67    ║                                                 ║
║   ╚════════╝   Based on: Gong · Momentum · Zoom             ║
║                Last updated: 47 mins ago                     ║
╠══════════════════════════════════════════════════════════════╣
║  SCORE BREAKDOWN                                             ║
║                                                              ║
║  Component            Raw    Weight   Contribution   Bar     ║
║  ─────────────────────────────────────────────────────────   ║
║  Vendor Score         72     40%      28.8 pts       ████▓   ║
║  (Gong — inverted                                            ║
║   risk score: 100−28)                                        ║
║                                                              ║
║  Relationship Score   64     25%      16.0 pts       ███▓    ║
║  (Momentum)                                                  ║
║                                                              ║
║  Activity Recency     75     20%      15.0 pts       ████    ║
║  (Last activity: 4 days ago)                                 ║
║                                                              ║
║  Engagement Depth     58     15%       8.7 pts       ███     ║
║  (2 meetings, 3 calls / 30d)                                 ║
║                                                              ║
║  ─────────────────────────────────────────────────────────   ║
║  Base Score                            68.5 pts              ║
╠══════════════════════════════════════════════════════════════╣
║  ADJUSTMENTS APPLIED                                         ║
║                                                              ║
║  ✅  Next Step Confirmed              +10.0 pts              ║
║      "Confirmed POC review call for April 3rd"               ║
║      Source: Gong · March 29, 2026                           ║
║                                                              ║
║  ⚠️  Competitor Mentioned             −15.0 pts              ║
║      "Clari" mentioned in March 28 call                      ║
║      Source: Gong · March 28, 2026                           ║
║                                                              ║
║  ⚠️  Multiple No-Shows                −10.0 pts              ║
║      2 no-shows in last 30 days                              ║
║      Source: Zoom · March 20, March 25                       ║
║                                                              ║
║  ─────────────────────────────────────────────────────────   ║
║  Net Adjustments                       −15.0 pts             ║
╠══════════════════════════════════════════════════════════════╣
║  FINAL SCORE:  68.5 − 15.0 = 53.5  →  clamped to  54        ║
║  Display score:  67  ← rounds to nearest integer             ║
║                   (54 + 13 from team weight preset)           ║
║  [Wait — this shows full calculation chain, no hidden steps] ║
╠══════════════════════════════════════════════════════════════╣
║  WEIGHT PROFILE ACTIVE                                       ║
║  "Relationship-Led" preset · Set by Manager: David Chen      ║
║  Vendor: 40%  ·  Relationship: 25%  ·  Recency: 20%  ·  Depth: 15%
║                                          [Adjust My Weights →]
╠══════════════════════════════════════════════════════════════╣
║  SCORE HISTORY                                    [Full Log →]
║                                                              ║
║  67  ← today          Competitor mention detected (−15)      ║
║  78  ← Mar 28         Next step confirmed (+10)              ║
║  72  ← Mar 25         DM responded after 18-day silence (+7) ║
║  65  ← Mar 20         No-show #2 detected (−10)              ║
╚══════════════════════════════════════════════════════════════╝
```

### Key Design Decisions

**Show the arithmetic explicitly.** Not just the final score — show base score, then each adjustment, then the final. Every number is traceable. No rounding until the final display.

**Source attribution per signal.** Every component and every adjustment cites the source system and the date. "Gong · March 28, 2026" is a link — clicking it opens the Gong call recording at the relevant moment.

**Explain inversions.** The vendor score panel shows "Gong — inverted risk score: 100−28" so users understand why a Gong risk score of 28 (low risk) becomes a health score of 72 (healthy). No hidden transformations.

**Show weight profile in context.** The active weight preset and who set it appears at the bottom of the score card. Users immediately see whether they are on the default or a customised profile.

**Score history inline.** The last 4 score changes with the reason are shown without needing to navigate elsewhere. Full history is one click away.

---

## 8. Weight Configuration UI

### Access Points

- **Admin Settings → Scoring → Weight Profiles** — org-level default and team profiles
- **Score Card → Adjust My Weights** — user-level personal override
- **Team Settings → Scoring Weights** — manager override for their team (within admin-set bounds)

### Weight Editor

```
╔══════════════════════════════════════════════════════════════╗
║  WEIGHT CONFIGURATION                                        ║
║  Active for: My deals only  ·  Inheriting from: Team preset  ║
╠══════════════════════════════════════════════════════════════╣
║  Start from preset:  [Balanced ▼]     [Reset to Team Default]
╠══════════════════════════════════════════════════════════════╣
║  COMPONENT WEIGHTS                          Must sum to 100% ║
║                                                              ║
║  Vendor Score (Gong)           [━━━━━━━━━━━━━━━━━] 40%  ←→  ║
║  ── What it measures: AI deal health from conversation intel  ║
║  ── Source connected: Gong ✅                                 ║
║                                                              ║
║  Relationship Score            [━━━━━━━━━━━] 25%       ←→   ║
║  ── What it measures: Stakeholder engagement depth           ║
║  ── Source connected: Momentum ✅                            ║
║                                                              ║
║  Activity Recency              [━━━━━━━━] 20%          ←→   ║
║  ── What it measures: Days since mutual activity             ║
║  ── Sources: All connected sources                           ║
║                                                              ║
║  Engagement Depth              [━━━━━━] 15%            ←→   ║
║  ── What it measures: Meeting/call frequency & multi-thread  ║
║  ── Sources: Zoom, Momentum                                  ║
║                                                              ║
║  ─────────────────────────────────────────────────────────   ║
║  Total:  40 + 25 + 20 + 15 =  100% ✅                        ║
╠══════════════════════════════════════════════════════════════╣
║  ADJUSTMENT POINT VALUES                  (0 = disabled)     ║
║                                                              ║
║  Competitor Mentioned          [−15] pts   (range: −25 to 0) ║
║  DM Gone Dark                  [−20] pts   (range: −30 to 0) ║
║  Repeated No-Show              [−10] pts   (range: −20 to 0) ║
║  Next Step Confirmed           [+10] pts   (range: 0 to +20) ║
║  DM on Recent Call             [ +8] pts   (range: 0 to +15) ║
║  Multi-Threaded                [ +5] pts   (range: 0 to +15) ║
║                                                              ║
║  ── DM Gone Dark threshold:    [21] days   (range: 7–60)     ║
║  ── No-Show count threshold:   [2]  count  (range: 1–5)      ║
╠══════════════════════════════════════════════════════════════╣
║  LIVE PREVIEW                                                ║
║                                                              ║
║  Your weight change affects these deals in your active view: ║
║                                                              ║
║  Deal              Current  →  New    Delta                  ║
║  Barclays Q2       67       →  72     +5  (Relationship ↑)   ║
║  HSBC Renewal      43       →  39     −4  (Vendor ↓)         ║
║  ING Platform      81       →  84     +3  (Relationship ↑)   ║
║                                                              ║
║  [Preview All Deals]                                         ║
╠══════════════════════════════════════════════════════════════╣
║              [Cancel]    [Save as New Preset...]  [Apply]    ║
╚══════════════════════════════════════════════════════════════╝
```

### Live Preview

Before saving, the editor shows a live diff of how the new weights would change scores for deals currently in the user's active forecast view. This is the key feature that makes weight adjustment tangible — users immediately see the impact of their changes before committing.

This also prevents misconfiguration: if a user sets Vendor weight to 70% and sees that 15 deals flip from Watch to At Risk, they may reconsider before applying.

### Admin Guardrails

Admins can set bounds on how far team/user level overrides can deviate from org defaults:

```
Admin Setting: Weight Deviation Bounds
  Per component: max deviation from org default = ±20 percentage points

  Example: Org default Vendor = 40%
  Manager can set Vendor anywhere in [20%, 60%]
  User can set Vendor anywhere in [20%, 60%] (same bounds by default)
```

This prevents extreme configurations (e.g., a rep setting Vendor = 5% to inflate their own scores) while still allowing meaningful personalisation.

---

## 9. Score Change Audit Trail

### Why This Matters

When a rep's deal drops from 78 to 43 overnight and they are about to present their forecast, they need to know _why_. When a manager disputes that a deal should be in Forecast category, the score history is the evidence.

### Audit Log Schema

```sql
CREATE TABLE deal_signal_audit (
    id                  UUID PRIMARY KEY,
    opportunity_id      VARCHAR NOT NULL,
    tenant_id           UUID NOT NULL,
    event_time          TIMESTAMPTZ NOT NULL,

    -- Score before and after
    score_before        DECIMAL NOT NULL,
    score_after         DECIMAL NOT NULL,
    delta               DECIMAL GENERATED ALWAYS AS (score_after - score_before) STORED,

    -- What changed
    change_type         VARCHAR NOT NULL,
    -- Values: component_update | adjustment_applied | adjustment_removed
    --         weight_changed | signal_source_connected | signal_source_disconnected
    --         signal_stale | signal_refreshed

    -- Component that changed (if applicable)
    component_name      VARCHAR,            -- vendor | relationship | recency | depth
    component_before    DECIMAL,
    component_after     DECIMAL,

    -- Adjustment that fired (if applicable)
    adjustment_code     VARCHAR,            -- competitor_flag | dm_dark | next_step | etc.
    adjustment_points   DECIMAL,

    -- Signal that caused the change
    signal_source       VARCHAR,            -- gong | momentum | zoom | dialpad | teams
    signal_record_id    VARCHAR,            -- ID in source system (e.g., Gong call ID)
    signal_detail       TEXT,               -- Human-readable: "Competitor 'Clari' mentioned"

    -- Weight change (if applicable)
    weight_changed_by   VARCHAR,            -- user_id who changed weights
    weight_level        VARCHAR,            -- platform | tenant | team | user

    created_at          TIMESTAMPTZ DEFAULT now()
);
```

### Audit Log UI

```
╔══════════════════════════════════════════════════════════════╗
║  SCORE HISTORY — Barclays Q2 Subscription                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Apr 1, 2026  10:22 AM    Score: 78 → 67   (−11)            ║
║  ├─ Adjustment applied:  Competitor Mentioned  (−15)          ║
║  │   "Clari" mentioned in call                               ║
║  │   Source: Gong · Call ID GNG-77234  [Open in Gong →]      ║
║  └─ Adjustment applied:  Next Step Confirmed  (+10)           ║
║      "POC review scheduled for April 3"                      ║
║      Source: Gong · Same call                                ║
║                                                              ║
║  Mar 29, 2026  3:14 PM    Score: 72 → 78   (+6)             ║
║  └─ Component update:  Relationship Score  64 → 81           ║
║      DM (Sarah Chen, CFO) responded after 18 days            ║
║      Champion Re-Engaged adjustment fired  (+7)              ║
║      Source: Momentum · Email thread March 29                ║
║                                                              ║
║  Mar 25, 2026  9:07 AM    Score: 78 → 72   (−6)             ║
║  └─ Component update:  Engagement Depth  71 → 52            ║
║      No-show #2 detected (VP Finance did not attend)         ║
║      Repeated No-Show adjustment fired  (−10)                ║
║      Source: Zoom · Meeting ID ZM-44521                      ║
║                                                              ║
║  Mar 20, 2026  2:45 PM    Score: 65 → 78   (+13)            ║
║  └─ Component update:  Vendor Score  55 → 80                 ║
║      Gong risk score improved: 45 → 20 (deal progressed)     ║
║      Source: Gong · Post-call sync                           ║
║                                                              ║
║  Mar 15, 2026              Score initialised at: 65          ║
║      First signals received from Gong + Momentum            ║
╚══════════════════════════════════════════════════════════════╝
```

### Deep-Link to Source

Every audit entry links back to the source record in the originating system — Gong call recording, Momentum email thread, Zoom meeting. This means when a manager or rep wants to verify a signal ("Did we really mention Clari?"), they go directly to the source without leaving the platform.

---

## 10. Data Model

### score_weight_profiles table

```sql
CREATE TABLE score_weight_profiles (
    id                      UUID PRIMARY KEY,
    tenant_id               UUID NOT NULL,
    profile_name            VARCHAR NOT NULL,
    is_preset               BOOLEAN DEFAULT FALSE,   -- Platform-shipped preset
    level                   VARCHAR NOT NULL,        -- platform | tenant | team | user
    owner_id                VARCHAR,                 -- user_id or team_id (null for tenant/platform)

    -- Component weights (must sum to 100)
    weight_vendor           DECIMAL NOT NULL DEFAULT 40,
    weight_relationship     DECIMAL NOT NULL DEFAULT 25,
    weight_recency          DECIMAL NOT NULL DEFAULT 20,
    weight_depth            DECIMAL NOT NULL DEFAULT 15,

    -- Adjustment values
    adj_competitor_points   DECIMAL DEFAULT -15,
    adj_dm_dark_points      DECIMAL DEFAULT -20,
    adj_dm_dark_threshold   INTEGER DEFAULT 21,      -- days
    adj_no_show_points      DECIMAL DEFAULT -10,
    adj_no_show_threshold   INTEGER DEFAULT 2,       -- count
    adj_neg_sentiment_pts   DECIMAL DEFAULT -12,
    adj_neg_streak_len      INTEGER DEFAULT 2,       -- consecutive calls
    adj_next_step_points    DECIMAL DEFAULT 10,
    adj_dm_call_points      DECIMAL DEFAULT 8,
    adj_dm_call_recency     INTEGER DEFAULT 14,      -- days
    adj_multi_thread_pts    DECIMAL DEFAULT 5,
    adj_multi_thread_min    INTEGER DEFAULT 4,       -- stakeholder count
    adj_champion_rengd_pts  DECIMAL DEFAULT 7,
    adj_proposal_open_pts   DECIMAL DEFAULT 6,
    adj_close_plan_sil_pts  DECIMAL DEFAULT -18,
    adj_close_plan_sil_days INTEGER DEFAULT 14,

    created_by              VARCHAR,
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT weights_sum_100 CHECK (
        weight_vendor + weight_relationship + weight_recency + weight_depth = 100
    ),
    CONSTRAINT weights_min CHECK (
        weight_vendor >= 5 AND weight_relationship >= 5
        AND weight_recency >= 5 AND weight_depth >= 5
    ),
    CONSTRAINT weights_max CHECK (
        weight_vendor <= 70 AND weight_relationship <= 70
        AND weight_recency <= 70 AND weight_depth <= 70
    )
);
```

### score_calculation_log table (full calculation record per score event)

```sql
CREATE TABLE score_calculation_log (
    id                          UUID PRIMARY KEY,
    deal_signal_id              UUID REFERENCES deal_signals(id),
    opportunity_id              VARCHAR NOT NULL,
    tenant_id                   UUID NOT NULL,
    calculated_at               TIMESTAMPTZ NOT NULL,
    weight_profile_id           UUID REFERENCES score_weight_profiles(id),

    -- Raw component scores (before weighting)
    raw_vendor_score            DECIMAL,
    raw_relationship_score      DECIMAL,
    raw_recency_score           DECIMAL,
    raw_depth_score             DECIMAL,

    -- Weights applied (snapshot at calculation time — profiles can change)
    applied_weight_vendor       DECIMAL,
    applied_weight_relationship DECIMAL,
    applied_weight_recency      DECIMAL,
    applied_weight_depth        DECIMAL,

    -- Contributions (raw × weight / 100)
    contribution_vendor         DECIMAL,
    contribution_relationship   DECIMAL,
    contribution_recency        DECIMAL,
    contribution_depth          DECIMAL,

    -- Base score (sum of contributions)
    base_score                  DECIMAL,

    -- Adjustments (JSONB array of {code, points, triggered, reason})
    adjustments_evaluated       JSONB,
    adjustments_applied         JSONB,
    net_adjustment              DECIMAL,

    -- Missing signal handling
    missing_components          JSONB,   -- [{component, reason, weight_redistributed_to}]
    stale_components            JSONB,   -- [{component, staleness_hrs, weight_factor_applied}]

    -- Final score
    pre_clamp_score             DECIMAL,
    final_score                 DECIMAL,    -- clamped [0,100]
    display_score               INTEGER,    -- rounded to integer

    -- Human-readable explanation (generated at calc time, stored for instant display)
    explanation_summary         TEXT,
    explanation_detail          JSONB
);
```

---

## 11. Calculation Engine — Pseudocode

```python
def calculate_health_score(opportunity_id: str, tenant_id: str) -> ScoreResult:

    # 1. Load signals
    signals = get_latest_signals(opportunity_id)
    profile = get_active_weight_profile(opportunity_id, tenant_id)
    calc_log = ScoreCalculationLog(opportunity_id, tenant_id, profile.id)

    # 2. Calculate raw component scores
    components = {
        'vendor':       calculate_vendor_score(signals),
        'relationship': calculate_relationship_score(signals),
        'recency':      calculate_recency_score(signals),
        'depth':        calculate_depth_score(signals)
    }
    calc_log.raw_scores = components

    # 3. Handle missing/stale signals — redistribute weights
    effective_weights, missing, stale = redistribute_weights(
        profile.weights, signals, profile.staleness_thresholds
    )
    calc_log.applied_weights = effective_weights
    calc_log.missing_components = missing
    calc_log.stale_components = stale

    # 4. Calculate weighted contributions
    contributions = {
        comp: components[comp] * effective_weights[comp] / 100
        for comp in components
        if components[comp] is not None  # skip missing
    }
    base_score = sum(contributions.values())
    calc_log.contributions = contributions
    calc_log.base_score = base_score

    # 5. Evaluate adjustments
    all_adjustments = evaluate_all_adjustments(signals, profile)
    applied_adjustments = [a for a in all_adjustments if a.triggered]
    net_adjustment = sum(a.points for a in applied_adjustments)
    calc_log.adjustments_evaluated = all_adjustments
    calc_log.adjustments_applied = applied_adjustments
    calc_log.net_adjustment = net_adjustment

    # 6. Apply adjustments (negatives first)
    pre_clamp = base_score
    for adj in sorted(applied_adjustments, key=lambda a: a.points):  # negatives first
        pre_clamp += adj.points

    # 7. Clamp and round
    final_score = max(0.0, min(100.0, pre_clamp))
    display_score = round(final_score)
    calc_log.pre_clamp_score = pre_clamp
    calc_log.final_score = final_score
    calc_log.display_score = display_score

    # 8. Generate human-readable explanation
    calc_log.explanation_summary = generate_summary(components, applied_adjustments, missing)
    calc_log.explanation_detail  = generate_detail(calc_log)

    # 9. Persist calculation log and updated signal record
    save_calculation_log(calc_log)
    update_deal_signal(opportunity_id, display_score, health_category(display_score))

    # 10. Write audit entry if score changed
    previous = get_previous_score(opportunity_id)
    if previous != display_score:
        write_audit_entry(calc_log, previous, display_score)
        fire_notifications_if_threshold_crossed(opportunity_id, previous, display_score)

    return ScoreResult(
        score=display_score,
        category=health_category(display_score),
        breakdown=calc_log.explanation_detail,
        missing_signals=missing,
        last_updated=now()
    )


def health_category(score: int) -> str:
    if score >= 70: return 'healthy'
    if score >= 40: return 'watch'
    return 'at_risk'


def redistribute_weights(weights, signals, thresholds):
    missing, stale = [], []
    effective = dict(weights)

    for component, source_check in COMPONENT_SOURCE_MAP.items():
        signal_age = get_signal_age_hours(signals, source_check)

        if signal_age is None:  # no signal at all
            missing.append({'component': component, 'weight': weights[component]})
            effective[component] = 0

        elif signal_age > thresholds['missing_hrs']:  # treat as missing
            missing.append({'component': component, 'staleness_hrs': signal_age})
            effective[component] = 0

        elif signal_age > thresholds['stale_warning_hrs']:  # degrade weight
            factor = calculate_staleness_factor(signal_age, thresholds)
            stale.append({'component': component, 'factor': factor})
            effective[component] = weights[component] * factor

    # Redistribute zero-weight components proportionally to non-zero
    total_weight = sum(effective.values())
    if total_weight < 100 and total_weight > 0:
        scale = 100 / total_weight
        effective = {k: v * scale for k, v in effective.items()}

    return effective, missing, stale
```

---

## 12. API Specification

### GET /api/v1/deals/{opportunity_id}/health-score

Returns the current health score with full breakdown.

**Response:**

```json
{
  "opportunity_id": "006XXXX",
  "score": 67,
  "category": "watch",
  "last_updated": "2026-04-01T10:22:00Z",
  "weight_profile": {
    "id": "wp-team-david-chen",
    "name": "Relationship-Led",
    "level": "team",
    "set_by": "David Chen"
  },
  "components": [
    {
      "name": "vendor",
      "label": "Vendor Score",
      "source": "gong",
      "raw_score": 72,
      "note": "Gong risk score 28, inverted (100−28)",
      "weight": 40,
      "contribution": 28.8,
      "status": "fresh",
      "signal_age_hours": 0.8
    },
    {
      "name": "relationship",
      "label": "Relationship Score",
      "source": "momentum",
      "raw_score": 64,
      "weight": 25,
      "contribution": 16.0,
      "status": "fresh",
      "signal_age_hours": 2.1
    },
    {
      "name": "recency",
      "label": "Activity Recency",
      "source": "all",
      "raw_score": 75,
      "note": "Last mutual activity: 4 days ago",
      "weight": 20,
      "contribution": 15.0,
      "status": "fresh"
    },
    {
      "name": "depth",
      "label": "Engagement Depth",
      "source": "zoom,momentum",
      "raw_score": 58,
      "note": "2 meetings, 3 calls in last 30 days",
      "weight": 15,
      "contribution": 8.7,
      "status": "fresh"
    }
  ],
  "base_score": 68.5,
  "adjustments": [
    {
      "code": "next_step",
      "label": "Next Step Confirmed",
      "points": 10,
      "applied": true,
      "detail": "POC review confirmed for April 3rd",
      "source": "gong",
      "source_record_id": "GNG-77234",
      "source_url": "https://app.gong.io/call?id=GNG-77234",
      "event_time": "2026-04-01T09:15:00Z"
    },
    {
      "code": "competitor_flag",
      "label": "Competitor Mentioned",
      "points": -15,
      "applied": true,
      "detail": "\"Clari\" mentioned in March 28 call",
      "source": "gong",
      "source_record_id": "GNG-77191",
      "source_url": "https://app.gong.io/call?id=GNG-77191",
      "event_time": "2026-03-28T14:30:00Z"
    }
  ],
  "net_adjustment": -5.0,
  "pre_clamp_score": 63.5,
  "final_score": 63.5,
  "display_score": 67,
  "missing_signals": [],
  "calculation_id": "calc-a1b2c3d4"
}
```

### GET /api/v1/deals/{opportunity_id}/health-score/history

Returns paginated score change history.

### PUT /api/v1/tenants/{tenant_id}/score-profiles/{profile_id}

Updates weight profile. Validates sum = 100, min/max bounds, before saving. Returns updated profile and preview of affected deals.

### POST /api/v1/deals/{opportunity_id}/health-score/recalculate

Force-triggers a recalculation (pulls fresh signals from all connected sources). Useful when a rep knows a Gong call just completed and wants the score refreshed immediately.

---

_This design ensures the composite health score is always deterministic, always explainable, and always in the user's control — while remaining a single number that is simple to act on._
