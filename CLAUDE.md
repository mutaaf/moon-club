# Moon Club: working notes

Native SwiftUI (iOS 17+, iPhone + iPad) kids app; the native twin of mutaafaziz.com/metaphases/kids. Read README.md and docs/ARCHITECTURE.md first. Same kids rules as metaphases AGENTS.md: pretend money only, nothing about the child leaves the device, no ads/analytics/SDKs, no links out except behind the parental gate (GrownUps.swift only — `scripts/check-rules.sh`), Luna = free kid-safe brain with no key, a grown-up voice key only ever speaks app copy or Luna's answer, reading grade ≤ 5, never advice.

## Commands
`make up` (idempotent: xcodegen + Metal toolchain check + rules + core tests + app tests + sims), `make test`, `make shots`, `make device`, `make testflight`, `make content`.

## Release notes
Every version needs `release-notes/<MARKETING_VERSION>.md` in the house style (`release-notes/README.md`): fun, at least 3 family-friendly pop-culture nods, never lyrics, no links, ≤ 4000 chars. It feeds TestFlight "What to Test", the GitHub release and the in-app What's new. `check-rules.sh` fails without it.

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
