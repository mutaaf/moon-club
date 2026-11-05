# Shipping Moon Club to the App Store

TestFlight is covered in `docs/TESTFLIGHT.md`. This page covers the public App Store release. Most of it is scripted. Everything except `submit` only edits the draft version, which is private and reversible.

## The short version
```sh
make appstore-validate   # optional: archive the App Store build and let App Store Connect validate it (no upload)
make appstore-build      # upload an App Store build (STORE_BUILD, numbered <timestamp>.1) and attach it to the draft
make appstore            # screenshots + listing + age rating + price + review notes, then the readiness report
#   … do the browser-only steps below (App Privacy label, agreements) …
node scripts/asc.mjs store-check         # "Ready" means zero blockers
node scripts/asc.mjs submit --yes        # sends it to App Review; only after a human says go
```
After a version is approved it releases automatically (`releaseType: AFTER_APPROVAL`). For the next version, bump `MARKETING_VERSION` and write the release notes as usual, then run the same steps: `store-meta` moves the draft to the new version number and fills "What's New" from `release-notes/<version>.md`. The first release has no "What's New".

## What each command does
| Command | What it sets (idempotent) |
|---|---|
| `asc.mjs store-meta` | App Store version = `MARKETING_VERSION`. en-US listing: description, keywords, promotional text, support URL, marketing URL, What's New (2nd release on). Name "Moon Club", subtitle, privacy policy URL. Categories: Education (primary), Games › Family + Trivia (secondary; Apple has no "Games › Educational"). Copyright. Content rights. App Review contact (from `BETA_CONTACT_*` in `.env.testflight`, never printed) and review notes. Free price, available in all territories including new ones. Attaches the newest processed App Store build. The copy lives in `STORE` in `scripts/asc.mjs`. |
| `asc.mjs store-rating` | The age rating questionnaire (`RATING` in `scripts/asc.mjs`). Result: **4+**. |
| `make store-shots` | `scripts/store-shots.sh` takes 8 screenshots on "Store 69" (iPhone 17 Pro Max, 1320×2868) and "Store iPad 13" (iPad Pro 13-inch (M5), 2064×2752), plus iPhone Duo on "Store Duo". Order: Market World map, boss quiz, candle game, Story missions, Moon Shop, Ask Luna, Piggy Bank, badges. |
| `asc.mjs store-shots` | Uploads `build/store-shots/{iphone-69,ipad-13,iphone-duo}`: reserve, PUT the parts, commit with an MD5. A set whose checksums already match is left alone; a changed set is replaced. |
| `asc.mjs store-check` | Readiness report: every blocker with its fix. Exits 1 while anything blocks. |
| `asc.mjs submit --yes` | Creates (or reuses) a review submission with the draft version, then submits it. Without `--yes` it only prints what it would do. |

Screenshot display types come from the API's own enum: 6.9" iPhone shots go in `APP_IPHONE_67` (there's no `APP_IPHONE_69`; that set takes 1320×2868), 13" iPad in `APP_IPAD_PRO_3GEN_129`, and iPhone Duo in `APP_IPHONE_DUO`.

## iPhone Duo badge
App Store Connect shows "Made for iPhone Duo" on the product page when the build uses the iOS 27.1 SDK or later and the version has iPhone Duo screenshots. Our archives use Xcode 27.2 (the iOS 27.2 SDK), and `store-shots` fills `APP_IPHONE_DUO`. The Duo simulator boots closed and `simctl` can't open the hinge, so automation captures the outer display only (1398×2034). To add inner-display shots (2007×2853), unfold "Store Duo" in Device Hub, then rerun `make store-shots`. Blank inner frames are dropped.

## App Store builds vs TestFlight family builds
`make appstore-build` (`STORE=1 scripts/testflight.sh`) compiles with `STORE_BUILD` (`MoonClub/App/Distribution.swift`):
- No "Your own key" Luna brain. An old BYOK setting falls back to on-device or Free Luna, and the saved key is never read.
- No third-party voice key (device voice only).
- The grown-ups "Our promises" copy says questions never go to any other company.

The build number ends in `.1`. That suffix is how `store-meta` and `store-check` tell an App Store build from a family build, and `store-check` blocks a family build. Plain `make testflight` still makes family builds with every feature for the Crew/Nephew Squad. `scripts/check-rules.sh` rule 6 keeps every own-key entry point gated.

## Kids Category: decision and why
**Decision: don't opt into the Kids Category for 1.0. List under Education with a 4+ rating, and ship App Store builds without own-key AI.**

The options:
- **(a) Kids Category with BYOK compiled out.** Reviewers apply Guidelines 1.3 and 5.1.4: no third-party analytics or ads, parental gates, and no transmitting personal or device data to third parties. Even with BYOK gone, Ask Luna's free brain still sends a child's free text to a server: ours, which uses Cloudflare Workers AI as a processor. Kids Category review is much stricter about open text from children, and this is the most likely rejection reason. Apple also expects Kids Category apps to keep meeting those rules in every update. Opting in later is one setting; getting out of the Kids Category once approved isn't really an option.
- **(b) Education, not Kids Category (chosen).** The age rating, gate, privacy policy and "no data collected" stay just as true. Review is the standard one. It's the most likely to pass now, and it keeps the Kids Category open for later.

The App Store build also drops BYOK under (b). Outside the Kids Category, 5.1.4 and COPPA still apply to an app children use, and most AI providers' terms exclude under-13 users. Sending a child's text to OpenAI, Anthropic, Google or xAI is the riskiest flow in the app and the hardest to defend in review.

**To move to the Kids Category later:**
1. Restrict Ask Luna to tap-to-ask chips (no free text), or get a COPPA review of the free brain (see `docs/COMPLIANCE.md`).
2. Set `kidsAgeBand` (e.g. `NINE_TO_ELEVEN`) in `RATING` and run `store-rating`.

## Browser-only steps (the API can't do these)
### 1. App Privacy ("nutrition label")
App Store Connect → Moon Club → **App Privacy** → **Get Started** (or Edit).
1. Privacy Policy URL: `https://mutaafaziz.com/metaphases/kids/privacy` (already set by `store-meta`; confirm it's shown).
2. "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.** → Save.
3. Click **Publish** (top right). The label then reads **Data Not Collected**.

Why "not collected", checked against the code. Apple counts data as collected when it's sent off the device and kept longer than it takes to serve the request in real time.
- Progress lives on the device. Optional sync goes to the family's own iCloud key-value storage, which we can't read.
- Market data requests (`/api/kids/*`) carry nothing about the child.
- Free Luna sends the question (≤ 200 characters, no name, account or device id) to our Worker. The Worker answers in real time through Cloudflare Workers AI. Nothing is stored or logged (`metaphases/worker/ai/index.ts`).
- On-device Luna sends nothing.
- No analytics, ads, SDKs or tracking. The privacy manifests declare none.
- App Store builds have no BYOK or voice keys, so nothing goes to a third-party AI.

Two things to know:
- The Worker rate-limits with an 8-byte SHA-256 hash of the IP in the edge cache for an hour. That's anti-abuse only and not one of Apple's data types.
- `observability` is on in metaphases' `wrangler.jsonc`, so Cloudflare keeps invocation metadata (URL, status, coarse request info), but not bodies.

If you'd rather leave no doubt, turn off observability for `/api/ai/*`. Neither changes the answer.

### 2. Agreements
**Business** (Agreements, Tax and Banking): the Account Holder must accept the current **Free Apps** agreement (it's usually already active). A paid agreement isn't needed: Moon Club is free with no in-app purchases. The App Manager API key can't see this page.

### 3. Things worth a glance before `submit`
- **Content rights:** `store-meta` declares **"uses third-party content"**, because the app shows real company names and market prices. Submitting confirms you have the rights to show that data (it comes through mutaafaziz.com/metaphases from Finnhub/Yahoo/Nasdaq). Change `STORE.contentRights` if you see it differently.
- **App Store icon:** App Store Connect shows the icon from the attached build. The app list shows a placeholder until a version with a build is attached; the next App Store build carries the new Luna icon.

## Age rating answers (`RATING`)
Every content descriptor is **None**: no violence, fear, mature themes, profanity, drugs, sexual content, or medical info.

| Question | Answer | Why |
|---|---|---|
| Gambling / simulated gambling / loot boxes / contests | No / None | Chart games are guess-and-learn with earned points. Nothing is wagered, bought or won. |
| Unrestricted web access | No | The only links sit behind the grown-up gate and go to fixed pages. |
| User-generated content | No | Nothing a kid types is shown to anyone else. |
| Messaging and chat | No | Ask Luna is an AI helper, not person-to-person chat. Its answers follow the kid-safe prompt plus the on-device `LunaGuard`, so they stay inside these descriptors. |
| Advertising | No | No ads. |
| Parental controls | **Yes** | A multiplication gate guards settings, sync, Luna's brain and every link. |
| Age assurance | No | We don't verify age. |
| Health or wellness, social media | No | |
| Kids Category (`kidsAgeBand`) | not set | See the decision above. |

## Pre-flight checks done in the repo
- `PrivacyInfo.xcprivacy` in the app (UserDefaults CA92.1, file timestamps C617.1, system boot time 35F9.1 for `CACurrentMediaTime` frame timing) and in the widget extension (C617.1, because MoonClubCore's cache links in). No tracking, nothing collected.
- `ITSAppUsesNonExemptEncryption = NO` (app and widget).
- iPhone + iPad. The iPad supports all four orientations and doesn't require full screen, so multitasking works. The launch screen is generated. Minimum OS is iOS 17.0.
- The app icon is an Icon Composer bundle (`MoonClub/AppIcon.icon`, Liquid Glass with default/dark/tinted/clear appearances) plus an opaque 1024 PNG (`AppIcon.appiconset`). Both are generated by `make icon` (`scripts/brand/icon.mjs`).

## Rejection log
- **2026-11-04, 0.13.0, Guideline 1.5 (Developer Information):** the Support URL pointed at the marketing page (`/kids/app`), which has no way to ask a question. The Support URL is now `/kids/support`: FAQ plus a contact form whose messages are stored in Workers KV and read with `npm run support:inbox` in metaphases. Support and Marketing URLs must stay different pages, and the support page must always have a working contact method.
