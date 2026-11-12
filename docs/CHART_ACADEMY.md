# Chart Academy (0.19): Candle Academy + Line Lab

Two climbs behind the World map's purple **Arcade** chip (`ArcadeHub`), next to Moon Tower:

- **Candle Academy**: 15 chapters × 20 levels = **300 levels**, then an endless mix. It covers 39 candlestick patterns with 10 kinds of drill.
- **Line Lab**: 11 chapters × 20 levels = **220 levels**, then an endless mix. It covers trend lines, floors and ceilings, lanes (channels), breakouts, moving averages and crossovers, volume, and liquidity (order books, the gap between bid and ask, and slippage). It ends with "The Whole Picture".

Every level is generated from its number, so it's the same on every device, and every answer is checked by a rule with a unit test. The content came from two research briefs (2026-11-12), summarized below: a market technician (CMT-style) and a grade 3–6 teacher / learning designer.

## The technician's rules (MoonClubCore `CandlePatterns.swift`, `LineLab.swift`)

### Symbols and candle classes
- **Per candle:** `R = H−L`, `B = |C−O|`, `US = H − max(O,C)`, `LS = min(O,C) − L`.
- **Averages:** `avgR` and `avgB` are means over the 10 days before the pattern.
- **Long:** `B ≥ 0.6R` and `R ≥ 1.2·avgR`.
- **Doji:** `B ≤ 0.05R`.
- **Lead-in (slide or climb):** `C[s−1] ≤ C[s−6] − 1.5·avgR`, and at least 3 of the last 5 days went that way.

### Patterns
- **39 patterns:**
  - 13 single-candle
  - 12 two-candle
  - 12 three-candle
  - 2 five-candle (rising/falling three methods)
- **Exact ratios:** each pattern has the ratios in the brief; for example, a hammer has `0.1R ≤ B ≤ 0.3R`, `LS ≥ 2B`, `LS ≥ 0.6R`, `US ≤ 0.1R`, after a slide.
- **Bearish twins** are checked by mirroring the chart, so each bullish rule is written once.
- **Grey zones:** the generator keeps every value at least about 20% from a threshold, so a generated pattern never also reads as its look-alike.
- **Tests** (`CandlePatternTests`), across 120 seeds per pattern, check that:
  - every generated pattern passes its own rule;
  - it shows up only once in the chart;
  - its look-alike's rule fails on it.

### Outcomes
- **Days after a pattern** go the hinted way about 60% of the time (Bulkowski: candle patterns are a modest edge).
- **"What might happen?"** scores the *clue*, then shows what happened: "Charts give clues, not promises."

### Line Lab rules
- **Swing points:** the window is N = 2/3/4 by chart length. Swings alternate, and a swing is kept only if it differs from the last kept one by at least 5% of the span.
- **Trend line:** a pair of swing lows (highs) such that:
  - no close goes more than 0.5% of the span through it;
  - at most one wick pokes more than 1.5% past it;
  - at least 2 swing points touch it.
  - Score: `10·touches + 0.2·length − 3·pokes`.
- **Grading a drawn trend line:**
  - The error is measured at the ideal anchors, as a share of the visible span.
  - The tolerance by tier (0→5) is 8 / 6.5 / 5 / 4 / 3 / 2.5%.
  - Within half the tolerance is "spot on".
  - A different line can also pass: it covers at least 30% of the chart, stays under at least 90% of the wicks, no close crosses it, and 2 swings touch it.
- **Floors and ceilings:** swing points are clustered within 1.5% of the span. A level needs at least 2 points at least 5 days apart, and its price is the cluster's median.
- **Lanes (channels):** the second rail is the trend line shifted to the farthest high (low).
- **Breakouts:**
  - A breakout is the first close past the level by more than 1.5% of the span.
  - Half the generated breakouts hold and half slip back.
  - Breakouts that hold get 1.6–3× volume. About 1 in 5 holds on low volume, to teach that volume is a clue, not a rule.
- **Moving averages:**
  - SMA 5, 10 and 20.
  - Above/below uses a ±0.2% band.
  - Crossovers use a whipsaw filter.
  - "Make the average" passes within 2% of the span.
- **Liquidity:**
  - Order books have 5 price steps a side.
  - A deep book has a 0.03–0.1% gap and 600–5000 shares a step; a thin one has a 1.2–3% gap and 10–120 shares.
  - The fill price walks up the sellers' prices: `avgFill = Σ price·qty / Q`.

## The teacher's design (MoonClubCore `Academy.swift`)
- **Mastery pacing:** each chapter teaches its new patterns or tool in its first 3 levels, as watch → finish → alone (`scaffold` 2/1/0):
  - Level 1: Luna's tip shows.
  - Level 2: the tip is behind a button.
  - Level 3: on your own.
- **Interleaving:** a round's pattern is 60% from this chapter, 25% from the chapter before and 15% from older ones.
- **Levels in a chapter:**
  - Every 5th level is a **review** (older chapters).
  - Level 10 is a **mini boss** (this chapter's drills mixed).
  - Level 20 is the **chapter boss** (everything so far; 2 hearts from tier 2).
- **Never punitive:**
  - A wrong answer explains itself.
  - Out of hearts is still "fuel".
  - Finishing always earns a star.
  - 3 in 5 right earns 2 stars, and 85% earns 3 (`Academy.starsFor`).
- **Touch targets:**
  - Drag handles are 30 pt dots in 60 pt targets.
  - A grabbed handle doesn't jump to the finger (it keeps its offset).
  - A magnet pulls a handle onto a wick tip. Its radius by tier is 44 / 36 / 28 / 20 / 12 / 0 pt, so it's off at the top.
  - After each try, the ideal line draws in gold next to the kid's.
- **Classic games behind the drills:**
  - Spot it: a hidden-picture puzzle.
  - Odd one out: "which one doesn't belong?"
  - Catch it: Snap.
  - Who won?: tug-of-war.
  - Build it / Fix it: puzzles.
  - Trend line / lane: connect-the-dots.
- **Words:**
  - Buyers and sellers are two teams in a tug-of-war.
  - Always "might" / "a clue".
  - Never "buy", "sell", "will" or "should" (tests check every pattern and drill line).

## Pixel-correct on every screen
`PlotMap` (MoonClubCore) is the only mapping between days/prices and points. `LabChart` draws with it, and `LabCanvas` hands the same map to every handle and tap, so the finger and the picture can't disagree. Grading is in days and prices, never in points.

`AcademyTests.testPlotMapRoundTripsOnEveryScreen` checks that tapping anywhere in a day's column picks that day, and that a price survives the round trip, at 8 sizes (SE, 17, Pro Max, Duo outer, Duo inner, iPad portrait/landscape, a half page). It also checks that one pixel of finger movement is under a tenth of the strictest tolerance.

## iPhone Duo
- **`DrillStage`:**
  - Wide rooms (the open Duo held wide, iPad landscape) put the chart on the leading 62% and the question and answers beside it.
  - Tabletop puts the chart on the top half and the controls on the bottom half (`TabletopStage`).
  - The closed outer display and phones stack.
- **The hinge is a knob (`hingeKnob`):** while the Duo is partly open, the hinge angle moves the picked handle:
  - a trend line's dot (tilting the line);
  - a floor or ceiling;
  - a lane's rail;
  - the average dot;
  - a candle's start, end, high or low.
  It counts `DuoUse.hinge`.

## Debug
`-demo -tab school -arcade` opens the Arcade. `-academy candles|lines` opens a track, `-academyAt N` gives stars on 1…N−1, `-academyPlay N` plays level N, and `-academyCard N` shows its card.

For example: `-demo -tab school -academy lines -academyAt 30 -academyPlay 30`.
