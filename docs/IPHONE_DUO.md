# Moon Club on iPhone Duo

iPhone Duo is the foldable iPhone (iOS 27.1). It has:
- a small **outer display** (the phone closed)
- a tall **inner display** with a center **fold**
- a **hinge** that reports its status and angle
- **vertical bars**: tab bars and toolbars move to the side

Moon Club uses every iPhone Duo developer feature in the 27.1 SDK (re-audited against the **27.2 SDK** in 0.14: it adds only `CustomStringConvertible` on `ReservedRegion` and `toolbarTitleAlignment`; there is still **no posture/tent API**, so tent mode is emulated from the hinge angle). Each use has to make the app better for a kid or a family. Where a feature doesn't fit, the table below says why.

**Two rules from Apple shape all of it:**
- **The hinge drives effects, never layout.** Layout comes from size classes and the fold's *reserved region*.
- **Never choose a layout by device.** Every Duo layout also works on iPad and in Split View, and falls back cleanly where there's no hinge.

**Sources:**
- Apple's HIG "Designing for iPhone Duo" and "Preparing your app for iPhone Duo".
- The tech talk "Leverage multiple displays and scenes on iPhone Duo".
- Xcode's `app-resizability` agent skill (`xcrun agent skills export`).
- The SDK's `SwiftUICore` / `SwiftUI` / `UIKit` interfaces.

## Feature → purpose → code

| iPhone Duo feature (API) | What Moon Club does with it | Where |
|---|---|---|
| **Hinge** (`onHingeChange`, `DeviceHinge`, `DeviceHingeContext`) | One listener per scene feeds a tiny `@Observable` `DuoModel`. It splits into `phase` / `illumination` / `lid` so only the views that read them redraw. The handler does value math only, so there's no main-thread work and touch stays instant. | `Design/Duo.swift` `DuoModel`, `TracksHinge` |
| Hinge → **Luna's moon phase** | While the phone is partly open, the hero art on every tab becomes a moon that waxes with the angle: new when closed, half at 90°, full when flat. That's the Metaphases moon-phase mark made physical. It gives a selection haptic at each of the 5 phases, and VoiceOver says "Half moon". | `HingeHeroArt`, `MoonDisc`; logic in `MoonClubCore/Duo.swift` `HingeMoon` (unit-tested) |
| Hinge → **piggy-bank lid** | On the Piggy Bank, the pig's coin hatch lifts as you open the phone and coins pop out (smoothstep 15°…125°). It shuts again when flat or closed, so it only plays while you're opening. | `PiggyArt`; `PiggyLid` (tested) |
| Hinge → **tuck Luna in** | Close the phone on a finished lesson and Luna falls asleep: a sleepy Luna, "Goodnight, Luna!" and a soft haptic. It's waiting on the outer display. | `LessonPlayer` (`closedTick`), `SleepyLuna`; `HingeMoment` (tested) |
| **Reserved regions** — division (the fold) (`GeometryProxy.reservedRegions(kind: .division, options: [.includeInactive])`) | Every two-page layout puts its gutter exactly on the fold, active (book pose) or inactive (flat), margins included. Nothing ever sits across the crease. | `FoldProbe`, `FoldInfo.split`; `Fold.spread` (tested) |
| Fold → **storybook spreads** | **Moon School lessons**: the story on the left page (the big picture, or "Luna said…" facing a quiz), the play on the right. **Quests**: chapter, progress and Luna's narration on the left, the stage on the right. **Story**: two cards per spread, with a "That's today's story!" end page. **Piggy Bank**: money and its line on one page, holdings and basket on the other. | `Storybook`/`TwoPage` in `School.swift`, `Quest.swift`, `Story.swift`, `Piggy.swift` |
| Fold → **even columns** | The badge grid always has an even number of columns when the fold crosses it, and the middle gap widens to the fold's width. | `FoldColumns`; `Fold.columns` (tested) |
| Reserved regions — occlusion (cameras) | Handled by the system bars. Our own full-bleed layer is the aurora background, which is decorative and fine under a camera. | — |
| **Split arrangement** (`ArrangementView` + `.split`) | **Game Night** (new): two players, one phone, one half each. Side by side in book pose, stacked when closed or on tabletop. The system keeps each half off the fold. Rounds are past report cards, so the reveal is instant. Picks stay hidden until both are in. Nothing is saved. | `Features/GameNight.swift`; `GameNight` reducer (tested) |
| **Vertical bars** (`toolbarVerticalEdge`, `.topBarPinnedTrailing`, `visibilityPriority`, `toolbarVerticalCompressionBehavior`) | In a vertical bar the grown-ups gate turns into its 🔒 symbol, and it's **pinned** so it never overflows. The level pill shrinks to its moon. Lessons, quests and Game Night are task screens, so they keep their toolbar actions (`.prefersToolbarItems`); the tabs stay navigation-first. Every item has a title and a symbol. | `Root.swift` `GrownUpsButton`, `LevelPill`; `TaskToolbar` |
| **Size classes, not devices** | Compact (closed) → tab bar, which goes vertical on Duo. Regular (open) → `NavigationSplitView`, whose columns the system keeps clear of the fold. No `UIScreen.main`, orientation or idiom checks anywhere (Apple's resizability audit is clean). | `Root.swift` |
| **All poses / orientations** | iPhone now allows portrait and both landscapes, so the outer and inner displays work in every pose. The layouts above re-measure on every size change. | `project.yml` |
| **Multiple scenes** (`UIApplicationSupportsMultipleScenes`, `openWindow`) | **Luna's Word Book** opens in its own window next to a quest or lesson (Split View on Duo or iPad), on the word the kid was reading. The button hides where new windows aren't possible, including Duo's outer display. | `Words.swift` `WordBookView`, `MoonClubApp.swift` |
| **External display accessory** (`sceneAccessory` + `ExternalNonInteractiveAccessory`, iOS 27.0) | **Game Night on the TV.** When a TV is connected (AirPlay or cable), the system may show a big, non-interactive scoreboard there, while the players keep their halves of the phone. The game says "📺 The scoreboard is on the TV too!" when the TV is available. | `GameNightOnTV`, `TVBoard` |
| Fold → **Market World** | Opened wide, the map takes one page and the selected stop's preview (stars, Play) takes the other; closed, the preview is a sheet. | `WorldMap.swift` (`PageSplit` + `FoldInfo.split`) |
| Hinge → **game control** (0.12) | **Build the Candle**: while the phone is partly open, the hinge angle is a dial. 30°…170° sweeps the picked handle (High by default; tap a handle to pick it) from $0 to $12. Dragging still works. Each candle built this way counts toward the **Hinge Hero** trophy. | `BuildCandleRound` (`hingeLive`, `.onChange(of: duo.reading.degrees)`); `HingeDial` (tested) |
| Hinge → **open wide to launch** (0.12) | A ready **mission chest** opens when the phone opens flat, and a **new rank** waits behind "Open me wide!" until it does (a tap always works too). | `TodaysMissions` (chest), `OpenWideReveal` in `RankCeremony`; `HingeLaunch` (tested) |
| Fold (horizontal, active) → **tabletop mode** (0.12) | **Chart Time Machine** bosses: set the phone down like a laptop and the chart stands up on the top half while the clues become a game pad on the flat half, nothing on the crease. Luna says so, and finishing a boss this way counts toward **Tabletop Trader**. | `TabletopStage` (`Design/Duo.swift`, `reservedRegions(kind: .division)` with a wide region), `TimeMachineBoss` |
| Fold → **badge cabinet spread** (0.12) | Opened like a book, the Moon Locker's Badges tab puts the trophy shelf on one page and the sticker book on the other. | `MoonLocker` (`Storybook`) |
| Split arrangement **ratio + axis** (`splitArrangementLayoutRatio`, `splitArrangementAxis`, 0.12) | Game Night's halves are always even (ratio 0.5). When the halves stack (vertical axis) and the phone lies flat, the first player's half turns 180° so the two players sit face to face across the table. A finished Game Night counts toward Tabletop Trader. | `GameNight.swift` `FaceToFace` |
| **Calling it out** (0.12) | A "Made for iPhone Duo" glass tag shows wherever a Duo-only feature is on (storybook lesson, tabletop boss, hinge candle, Game Night, open-wide reveals). A first-open coach ("Fold me like a book!") shows the three poses once. The What's New reel has a Duo card, shown only on a device with a hinge. Three Duo-only trophies (Storybook Reader, Tabletop Trader, Hinge Hero) and a Duo-only shop item (Storybook frame). On other devices none of this appears (no nagging); the grown-ups corner mentions it once. | `DuoCallout`, `DuoCoach`, `WhatsNewModal.isDuo`, `Trophies.visible(hinge:)`, `Shop.visible(hinge:)`, `DuoUse` + `KidsState.duo` (max-merge) |
| **Celebrations across the fold** (0.12) | On an open Duo, large celebrations launch fireworks from one page that burst over the other. | `PartyOverlay` (`crossFold`), `Fireworks` in `Design/Celebrate.swift` |
| Hinge → **light** (0.14) | The hinge angle is a live shader input. **Market World's sun rises** as the phone opens (moonlit sea when closed, midday when flat); **Luna's light swings** round her shaded moon; the **fold casts a soft seam** that deepens as the phone closes; the **fog over locked lands parts** a little as it unfolds (a peek, never a clear view). Values are rounded to 2% steps so shaders redraw only on visible changes. | `DuoModel.sun/lunaLight/seam/fogPart`; `SeaLayer`, `FogFX` (`WorldFX.swift`), `LunaSphere` (`Components.swift`), `FoldSeam` (`Shaders.swift`); math in `HingeLight` (tested) |
| Fold (vertical) → **World atlas** (0.14) | Opened like a book, the World is an atlas spread: the left page tells the land's story (lore + Luna's fact, grade ≤ 5), the right page is the island. Swipe the page, or **flick the fold** (a quick ≥ 25° dip and back), to turn to the next land; the map flies there. Counts toward **Atlas Explorer**. | `AtlasPage` (`WorldFX.swift`), `WorldView` (`PageSplit` when the fold is vertical); `Atlas`, `PageFlick` (tested) |
| **Tent** (emulated, 0.14) | **Luna's puppet show**: stand the phone up half open and one page becomes a theater facing the family, where Luna tells today's market story; the other page is the kid's controls (next line, Luna's mood, read aloud). **The 27.1/27.2 SDK has no posture API**, so a tent is a half-open hinge between 30° and 100° with a vertical (or no) fold, held steady for 1.2 s. A Story-tab button opens it anywhere. Counts toward **Puppet Master**. | `PuppetShow` (`DuoStage.swift`), `DuoModel.isTent`; `Stance` (tested) |
| Fold (flat) → **Market Race** (Game Night 2.0, 0.14) | A two-player board game for a phone lying flat: each player answers real-candle questions on their own half (the far half turns 180° to face its player), and both rockets race along a track that sits on the fold line; the first right answer gets a boost. Counts toward **Market Racer**. | `MarketRaceView`, `RaceTrack` (`MarketRace.swift`); `MarketRace` (tested) |
| **Outer display while closed** (0.14) | **Luna's pocket**: when the phone closes outside of play, the outer display shows a glanceable card: today's missions (ring) and the Moon Garden's value (up/down shape-coded). Luna naps until the phone is **picked up** (device motion: `CMDeviceMotion.userAcceleration`, no permission prompt, nothing stored) or tapped. Opening the phone returns to the app. | `LunaPocket` (`DuoStage.swift`), `MotionTilt.jolt`; `PocketGlance`, `PocketWake` (tested) |
| Hinge → **fold to save** (0.14) | In the Moon Garden's plant sheet, the seed pot's lid follows the hinge as the phone closes; **closing it plants** (the fold is the confirmation, instead of the dialog) with a lid-shut sparkle. Counts toward **Fold Saver**. | `PlantSheet` + `SeedPot` (`Garden.swift`); `FoldSave` (tested) |
| External display accessory → **Story and Market Race on TV** (0.14) | Besides Game Night's scoreboard, the **puppet show** and the **Market Race track** appear on a connected TV, with the phone halves as the controllers. | `OnTV` (`DuoStage.swift`), `PuppetTV`, `RaceTVBoard` |
| **Duo tour** (0.14) | The first-open coach and a "Take the iPhone Duo tour" button on What's New's Duo card teach all six poses (closed, book, tent, tabletop, flat, the hinge itself), each with an animated phone drawn in-app. | `DuoCoach`, `PoseArt` (`Party.swift`), `WhatsNewModal` |
| Duo-only **rewards** (0.14) | Four new trophies (Puppet Master, Market Racer, Atlas Explorer, Fold Saver), a **Twin Moon** rocket (needs Market Racer) and a **Twin moon halo** for Luna (needs Puppet Master). Hidden without a hinge (unless already earned); the Duo rocket is never a legacy chest prize (`Skins.duo`, outside `Skins.all`). Duo items shimmer with a holographic tilt. | `Trophies`, `Shop.duoOnly`, `Skins.duo`, `DuoUse.puppet/race/atlas/fold` |
| `UIHingeInteraction` (UIKit) | **Not used directly**: it is UIKit's face of the same hinge data SwiftUI gives through `onHingeChange`, and the app is all SwiftUI with one listener per scene. A second listener would duplicate work on every hinge tick. | — |
| **Overlay arrangement** (`.overlay`, `overlayArrangementEdge`) | **Deliberately not used.** It's for a panel floating over a full-bleed canvas (a map, a photo). No Moon Club screen has that shape, and a floating panel over a kid's lesson would hide the words. Split arrangements and spreads fit our content. | — |
| **Camera capture accessory** (`CameraCaptureAccessory`) | **Deliberately not used.** It needs an active camera session. Moon Club never uses the camera: kids-app privacy rules (nothing about the child is collected or captured) and the future Kids Category review. | — |
| Inner front camera region | Not applicable (no camera). | — |

## Fallbacks

Everything is behind `#available(iOS 27.1, *)` (the TV accessory is iOS 27.0), and the deployment target stays iOS 17.
- **No hinge** (a nil context): no hinge effects, and spreads only where the window is wide.
- **Before 27.1**: `Game Night` uses `ViewThatFits` instead of `ArrangementView`.

## Testing

- **Unit tests**: `MoonClubCoreTests/DuoTests.swift` covers pose, moon phase, lid, moments, spreads, even columns and Game Night. `PartyTests.swift` covers the hinge dial, open-wide launch, Duo-only trophies/shop item and the max-merge of Duo counts.
- **Capability, never model:** `DuoModel.hasHinge` (a hinge reading exists, or a debug pose is pinned) is the only test for Duo features.
- **Simulator**: an `iPhone Duo` device on iOS 27.1. `scripts/shots.sh` creates one ("Moon Club Duo") and captures the outer display at App Store size, 1398×2034.
  - The simulator **boots closed** and **`simctl` has no hinge control**. Unfold it by hand in Device Hub to capture the inner display (2007×2853) and see the real fold region.
  - Debug builds accept `-pose closed|book|tabletop|flat` and `-hinge <degrees>`, which pin a hinge reading. That shows the moon, lid and Game Night hints anywhere, and synthesizes a 40 pt center fold on wide simulators (e.g. iPad mini) so spreads can be screenshot.
  - `-gamenight` opens Game Night (`-race` opens it on the Market Race).
  - 0.14: `-pose tent` pins a 75° tent (the puppet show opens on the Story tab); `-pocket` shows Luna's pocket (`-pocketWake` wakes her after 2 s); `-pose book -plant -foldsave` closes the hinge slowly for the fold-to-save recording.
- **0.14 verification** (simulators; the Duo sim can't fold by script):
  - Outer display (Duo sim, `--display=primary`, pinned poses): Luna's pocket (`-pose closed -pocket -pocketWake`), the six-pose Duo tour (`-duocoach`), and the World at night with the sun down (`-pose closed`). The inner display (`--display=primary-1`) is black while the sim is closed.
  - Spreads with a synthesized center fold (iPad 13 sim, wide enough for `FoldProbe`/`FoldSeam`): the World atlas (`-pose book`), the puppet show (`-pose tent`), the Market Race (`-pose flat -gamenight -race`) and fold to save (`-pose book -plant -foldsave`, recorded).
  - Unit tests: `DuoPlayTests` (hinge light, tent, flick, fold-to-save, pocket, race, atlas, budget, Duo rewards); `CardFitTests.testDuoScreensFitWithoutScrolling`.
- **Needs real hardware or a manual unfold**:
  - the tent detector's feel (30°–100° held 1.2 s) and the fold-flick thresholds (25° dip and back within 1.2 s)
  - device-motion wake on the outer display and the parallax tilt (the simulator has no motion)
  - the live hinge feel
  - the active fold region in book and tabletop poses
  - `ArrangementView` placement around a real fold
  - the TV accessory: the simulator's TV output isn't attached without Device Hub
  - opening a second window on the inner display

## App Store

- "Made for iPhone Duo" badge: upload iPhone Duo screenshots in App Store Connect:
  - outer display: 1398×2034 or 2034×1398
  - inner display: 2007×2853 or 2853×2007
- Under **Helpful Details**, mark the app as optimized for iPhone Duo, with support for all device poses.
- Screenshots become **required in April 2027** for apps built with the iOS 27.1 SDK or later.
