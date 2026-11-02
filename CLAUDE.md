# Moon Club: working notes

Native SwiftUI (iOS 17+, iPhone + iPad) kids app; the native twin of mutaafaziz.com/metaphases/kids. Read README.md and docs/ARCHITECTURE.md first. Same kids rules as metaphases AGENTS.md: pretend money only, nothing about the child leaves the device, no ads/analytics/SDKs, no links out except behind the parental gate (GrownUps.swift only — `scripts/check-rules.sh`), Luna = one of three brains picked by a grown-up behind the gate (on-device Apple Intelligence by default when available; free kid-safe brain with no key; or the grown-up's own key, ONLY after per-provider consent, see `Brain.swift`), the same kid-safe prompt plus `LunaGuard` on every answer, a grown-up voice key only ever speaks app copy or Luna's answer, reading grade ≤ 5, never advice.

## Commands
`make up` (idempotent: xcodegen + Metal toolchain check + rules + core tests + app tests + sims), `make test`, `make shots`, `make device`, `make testflight`, `make content`.

## Release notes
Every version needs `release-notes/<MARKETING_VERSION>.md` in the house style (`release-notes/README.md`): fun, at least 3 family-friendly pop-culture nods, never lyrics, no links, ≤ 4000 chars. It feeds TestFlight "What to Test", the GitHub release and the in-app What's new. `check-rules.sh` fails without it.

## iPhone Duo
Made for iPhone Duo. `docs/IPHONE_DUO.md` covers every feature → purpose → code.
- The hinge drives effects only: Luna's moon, the piggy lid, tuck-in.
- Layout comes from the fold's reserved region (`Storybook` / `TwoPage` / `FoldColumns` in `Design/Duo.swift`) and size classes. Never branch on device.
- Pose logic is pure and tested in `MoonClubCore/Duo.swift`.

## Environment nuances (found the hard way)
- **XcodeGen** generates `MoonClub.xcodeproj` (gitignored); edit `project.yml`, never the project.
- **Xcode 27.1 ships without the Metal toolchain**: the first build fails with "cannot execute tool 'metal' due to missing Metal Toolchain". `xcodebuild -downloadComponent MetalToolchain` (≈840 MB, once). `make gen` does it. **Every Xcode update needs its own toolchain build** (Xcode 27A9275 → 27B52 mid-session flipped `xcodebuild -showComponent MetalToolchain` back to "uninstalled"): rerun the download.
- **Simulators**: this Mac's iOS 17/18 runtimes have iPhone 15 / iPad M4 names, but the Xcode 27.1 SDK only targets iOS 26.5+ sims (iPhone 17, iPad Pro 11-inch (M5)…). Names are duplicated across runtimes, so scripts accept `PHONE_ID`/`PAD_ID`.
- **A fresh iOS 27.1 iPad image can hang on `simctl launch`** (install took 50 s, launch never returned). The iOS 27.0 iPad Pro 11-inch (M5) works; `scripts/shots.sh` wraps every simctl call in a timeout.
- Core package is Swift 6 tools with Swift 5 language mode; use `lock.withLock {}` (plain `lock()` is an error from async contexts in Swift 6 mode).
- `ProcessInfo` launch args drive demo mode for screenshots (`-demo -tab … -quest … -lesson …`).
- The kids content JSON must also be copied into `Packages/MoonClubCore/Tests/MoonClubCoreTests/Resources/` (sync-content does both).
- Device signing: paid team Z73865R687 ("Apple Development: Mutaaf Aziz"). User's phone UDID 00008130-001614883021401C.
- **App Store Connect API**: `scripts/asc.mjs`, with zero deps (Node crypto ES256 JWT). Apps can't be created through the API: the "Moon Club" app record must be made once in the web UI. Xcode has no Apple ID signed in on this Mac, so archive/upload signing goes through the API key (`-allowProvisioningUpdates -authenticationKey*`).
- Debug-only launch arg `-demo -grownups` opens the grown-ups corner without the gate, for screenshots. `#if DEBUG`, so release builds always use the gate.
- **Physical UDIDs are 8-16 hex** (`00008130-001614883021401C`), not the 8-4-4-4-12 simulator form; `device.sh` once matched only the latter and found no phone. Once paired over a cable, the phone shows as `available (paired)` over Wi-Fi too (CoreDevice `*.coredevice.local` over Bonjour): it needs the same network, and the phone unlocked or recently used. `transportType` in `devicectl device info details --json-output` says `wired` or `localNetwork`.
- **TestFlight signing:** the team API key (C3BA4X5S97, App Manager) gets "Cloud signing permission error" at export. `asc.mjs signing` creates our own Apple Distribution cert (CSR and key in `~/.appstoreconnect/signing/`) plus the "Moon Club App Store" profile, and the export plist signs manually.
- **TestFlight `whatsNew` rejects emoji** (409 "invalid characters"). `notesFor()` strips them; the in-app What's new keeps them.
- Agent worktrees live in `.claude/worktrees/` and are gitignored. Never `git add -A` before that's ignored.
- **Luna brains**: `MoonClubCore/Brain.swift` (pure: router, prompt, guard, BYOK request builders) + `MoonClub/Live/Brains.swift` (live brains, FoundationModels behind `#if canImport(FoundationModels)` + `#available(iOS 26, *)`; the deployment target stays 17). Keep `LunaPrompts.kidsSystem` in sync with metaphases `worker/ai/prompts.ts` `KIDS_SYSTEM`. BYOK calls providers directly, NOT through the worker, because the web's `kids` task is FREE_ONLY and ignores keys. Demo: `-demo -grownups -brain byok` presets the picker for screenshots (DEBUG only).
- **Apple Intelligence in the Simulator** follows the host Mac's Apple Intelligence state: it shows `available` only if the Mac has it on and its model downloaded. On-device answers are unverified until run on an eligible device (iPhone 15 Pro+ / M-series iPad).
- **Sync** (`docs/ARCHITECTURE.md`, "Sync across devices"):
  - `KidsState.merged(with:)` must stay a join; `SyncTests` property-checks it. Never filter or cap inside the merge: filtering "me" out of the league there broke associativity, so `leaguePlayers` filters at read time and `Sync.payload` caps at write time.
  - New `KidsState` fields must be optional or have a merge rule, or old saves fail to decode and progress resets (`resetEpoch` is `Int?` for this reason).
- **iCloud capability:** `asc.mjs capabilities` enables ICLOUD on the bundle id; `asc.mjs signing` runs it before making the App Store profile. The entitlement is in `project.yml` (generated to `MoonClub/MoonClub.entitlements`). `GET /v1/bundleIds/{id}/bundleIdCapabilities` rejects `limit=`.
- **Web transfer codes** (`MOONP1-`) come from metaphases `shared/kidsTransfer.ts`; the app's `Transfer.swift` is checked against the `transfer` vectors. Change both together and re-run `make content`.
- Debug screenshot args: `-demo -grownups -syncOn -scrollSync` shows the "Your devices" section.

- **iPhone Duo simulator**: device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, iOS 27.1 runtime only. `scripts/shots.sh` creates "Moon Club Duo".
  - Displays: outer is `--display=primary` (1398×2034), inner is `--display=primary-1` (2007×2853).
  - It boots **closed**, and `onHingeChange` really reports `.closed`.
  - **`simctl` has no hinge control.** Folding happens in Device Hub's window. UI scripting and screen capture of Device Hub aren't permitted on this Mac (Accessibility / Screen Recording off), so automation can't fold it, and powering off a display with `simctl io screenConfig` doesn't open it.
  - Debug builds take `-pose closed|book|tabletop|flat [-hinge deg]` (pins a reading and synthesizes a center fold on wide sims) and `-gamenight`.
  - The TV output (`external-0`) times out on screenshot until a display is attached in Device Hub.
- Layout that measures itself (the fold probe) must lay out at the **proposed** width (`PageSplit` Layout), never at fixed measured widths. Fixed widths fed back into the measured frame and cut the right page off when the iPad sidebar appeared.
- **Widgets / Live Activities**: the `MoonClubWidgets` extension (bundle `com.mutaafaziz.moonclub.widgets`) shares `Shared/` + `MoonClub/Design/Theme.swift` with the app. App ↔ widget data goes through a **shared keychain group** (`$(AppIdentifierPrefix)com.mutaafaziz.moonclub.shared`, Info.plist key `MoonKeychainGroup`), NOT an App Group. Reasons:
  - the App Store Connect API has no App Groups endpoint (`/v1/appGroups` → 404);
  - Xcode's automatic provisioning with our App Manager API key fails ("Authentication failed … bearer token");
  - the wildcard "iOS Team Provisioning Profile: *" has no App Groups;
  - but every team profile, wildcard and App Store, already grants `Z73865R687.*` keychain groups.
  Keychain items survive app deletion (still on-device only; "Reset all progress" clears them).
- `asc.mjs signing` makes one App Store profile per bundle id (`TARGETS`: app + widgets) and deletes stale local copies of each profile name; `testflight.sh` maps both in the export plist. `asc.mjs call <METHOD> <path> [json]` is a debug passthrough.
- `scripts/provision.sh` (Xcode automatic provisioning via the API key) currently fails with "Authentication failed" for the App Manager key. Kept for an Admin key.
- **Widget design review**: `make widgets` (`scripts/widget-shots.sh`) renders every widget family and Live Activity view with `ImageRenderer` to `build/widget-shots/` (light + dark).
  - The widget view files also compile into `MoonClubTests` with the `WIDGET_RENDER_TESTS` condition, which adds `@testable import MoonClub`.
  - Views take a `forced:` family so they render outside WidgetKit.
  - `ProgressView` renders as a placeholder in ImageRenderer, hence the drawn `MoonBar`.
  - `Text(timerInterval:)` counts against the real clock even in ImageRenderer, so render fixtures use `Date()`.
- **The first `xcodebuild` after `xcodegen generate` sometimes fails** with "the following command failed with exit code 0 but produced no further output". Rerunning it succeeds.
