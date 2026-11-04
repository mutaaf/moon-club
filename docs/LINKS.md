# Deep links, campaign credit and grown-up picks

Three things live here: links into the app, crediting where downloads come from without tracking anybody, and a parent-facing affiliate slot that ships empty.

## 1. Deep links

The same URL works three ways:

- **Moon Club is installed:** iOS opens the app at that place (universal link).
- **Moon Club isn't installed:** the URL is a real page on mutaafaziz.com/metaphases/kids. It shows the matching web content plus "Moon Club is on iPhone & iPad", which leads to /kids/app. There the download button sits behind the parental gate.
- **Inside the device:** `moonclub://…` does the same thing for widgets, Live Activities and `xcrun simctl openurl`.

### URL map

| Web (`https://mutaafaziz.com/metaphases/kids…`) | Scheme | App opens | Gate |
|---|---|---|---|
| (the front page) | `moonclub://home` | Story tab (Home). Not a universal link: the web front door stays the website. | no |
| `/school` | `moonclub://school` (`world`) | World map | no |
| `/school/<lesson-id>` | `moonclub://school/<id>` (`lesson/<id>`) | that lesson. If this build doesn't have it (or its pack is off), the World map. | no |
| `/guess` | `moonclub://guess` | Guess the Report Card | no |
| `/gamenight` | `moonclub://gamenight` | Guess tab + Game Night | no |
| `/piggy` | `moonclub://piggy` | Piggy Bank, pretend-coins side | no |
| `/garden` | `moonclub://garden` | Piggy Bank, Moon Garden side | no |
| `/ask` | `moonclub://ask` | Ask Luna | no |
| `/league/<MOON-code>` | `moonclub://league/<code>` | **parental gate**, then "X wants to join" with an *Add to our family league* button at the top of the grown-up corner | **yes** |
| `/pack/<pack-id>` | `moonclub://pack/<id>` | **parental gate**, then the pack with a *Turn on this pack* button. Bundled packs only. | **yes** |
| `moonclub://tab/<story\|guess\|piggy\|school\|luna>` | (widgets, since 0.7) | that tab | no |

Rules, all in MoonClubCore `DeepLink.swift` (pure, `DeepLinkTests`):

- **Anything unknown or malformed lands on Home.** That covers other hosts, `http`, ports, user info, unknown paths, bad ids (only `[a-z0-9-]`, ≤ 48 characters), bad league codes, extra segments, and URLs over 512 characters. `resolve(_:in:)` also checks the content: an unknown lesson opens the World map; an unknown pack or a league code that doesn't decode goes Home.
- **No link skips the gate.** `needsGrownUp` is true for `league` and `pack`. RootView opens the gate. Only after a pass does the grown-up corner open with the link's offer (`LinkOffer` in GrownUps.swift), and nothing changes until the grown-up taps the button. Cancelling the gate drops the link. No link can reach the grown-up corner's settings, reset, keys or sync directly.
- **Packs come only from the built-in, reviewed set** (`KidsContent.bundledPacks`). A link names a pack; it can never carry one. The remote pack channel stays off (`PackChannel.remoteEnabled = false`).
- `?ref=` and every other query parameter are ignored by the app.
- Following a kid link closes the grown-up corner, a quest or the locker, then switches tab. That only ever moves *out* of the gated area.

Code map:

| Where | What |
|---|---|
| `Packages/MoonClubCore/Sources/MoonClubCore/DeepLinks.swift` | `DeepLink` (parse, resolve, `webURL(ref:)`, `appURL`), `Campaign` slugs |
| `MoonClub/App/AppModel.swift` `open(_:)` | resolves, then sets `pendingLesson` / `pendingGameNight` / the Piggy side |
| `MoonClub/Features/Root.swift` `follow(_:)` | `.onOpenURL` + `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`; tab, or gate → grown-up corner |
| `MoonClub/Features/GrownUps.swift` | `LinkOffer`, `ShareLinks` (Share this lesson / Moon Club / each pack), league "Share as a link" |
| `project.yml` | `com.apple.developer.associated-domains: applinks:mutaafaziz.com` |
| `scripts/asc.mjs capabilities` | enables `ASSOCIATED_DOMAINS` (and `ICLOUD`) on the bundle id |
| mutaafaziz-site `public/.well-known/apple-app-site-association` (+ `_headers`) | the AASA file, scoped to the paths above. Worksheets (`*/print`) are excluded. |
| metaphases `shared/kidsLinks.ts` | the same map for the web (`KIDS_LINKS`), ref allow-list, campaign URLs |
| metaphases `src/pages/KidsLinks.tsx` | web pages for app-only links (Game Night, Garden, pack) and the league invite (gate first) |

**Change all three together:** `DeepLink.swift`, `kidsLinks.ts` and the AASA file.

### Testing

- Unit: `swift test --filter DeepLinkTests` (every route on both forms, the widget forms, 30 malformed inputs, resolve, gate flags, round-trips), and `WidgetShareTests.testDeepLinks` (AppModel side effects; a pack link never turns a pack on by itself).
- Simulator: `xcrun simctl openurl <sim> https://mutaafaziz.com/metaphases/kids/<path>` opens the app straight there. That has worked since Apple's CDN picked up the AASA on 2026-11-04 (`https://app-site-association.cdn-apple.com/a/v1/mutaafaziz.com`). `moonclub://` URLs raise a system "Open in Moon Club?" alert that `simctl` can't tap. The debug `-demo -link <url>` launch arg runs the same `follow(_:)`.
- Live AASA: `curl -sI https://mutaafaziz.com/.well-known/apple-app-site-association` → 200, `application/json`, no redirect.

## 2. Campaign credit without tracking

Apple's **App Store Connect campaign links** credit downloads to a campaign in **App Analytics**, in aggregate. Only users who agreed to share with developers are counted, and Apple hides small numbers. There's no SDK, cookie, device id or anything about a child, and the app does nothing at all.

How it's wired:

1. Every Moon Club share link carries an allow-listed `?ref=` slug:
   - `share`: Share this lesson / Share Moon Club
   - `league`: a family league link
   - `pack-<id>`: a creator pack's link
   - `parent`: the web's "Share with another parent"
   - plus channel slugs for posts: `instagram`, `tiktok`, `youtube`, `x`, `facebook`, `reddit`, `newsletter`, `qr`, `worksheet`, `school`

   The list is `REFS` in metaphases `shared/kidsLinks.ts`; anything else is dropped. A slug names a channel, never a person.
2. On the web, the ref rides from the page to /kids/app (`AppNudge`). There, `appLink(ref)` turns the App Store URL into `https://apps.apple.com/us/app/<slug>/id6829860949?pt=<provider token>&ct=<ref>&mt=8`. With no valid ref it uses `ct=kids-web`. `isAppleAppLink` accepts exactly that shape: digits for pt, a ≤ 40-character slug for ct, `mt=8`, in that order, and nothing else.
3. TestFlight links can't carry campaigns. Credit starts once the App Store link is set.

**What the user does (one time, free):**

1. When 1.0 is live, open App Store Connect → **Apps → Moon Club → App Analytics → Acquisition → Campaigns** and click **Generate a Campaign Link**. Copy the number after `pt=`: that's the team's provider token.
2. In metaphases `shared/kidsApp.ts`, set:
   - `appStore: "https://apps.apple.com/us/app/moon-club/id6829860949"` (copy the slug from the live listing);
   - `providerToken: "<that number>"`.

   Merge, and every download button now carries `ct=`.
3. **Reading results:** App Analytics → **Acquisition** (or **Sources**) → **Campaigns**. Each row is a `ct` value (`kids-web`, `share`, `pack-guest-coach-nova`…) with impressions, product page views, first-time downloads and sessions. Filter by date; compare `share` against `kids-web` to see whether parent-to-parent sharing works, and `pack-<id>` to credit a creator. Expect a day or two of delay, and blanks for small numbers (Apple's privacy threshold).

## 3. Grown-up picks (affiliate slot): off, ships EMPTY

A config-driven place for parent-facing partner links, such as a kids' money book or a learning/custodial account.

| Where | Shown |
|---|---|
| App: MoonClubCore `Partners.list` (empty) → `PartnerPicks` in the grown-up corner (behind the gate), under `Partners.disclosure` | only if the list has valid entries |
| Web: metaphases `shared/kidsPartners.ts` `KIDS_PARTNERS` (empty) → `GrownUpPicks` in /kids/grownups (behind the gate) | only if the list has valid entries; links carry `rel="sponsored noopener noreferrer"` and `target="_blank"` |

Guardrails (tested on both sides):

- **https only.** A pick is a plain link, with no SDK, pixel or script, and no parameter about the family.
- **No hype words** ("guaranteed", "get rich", "buy now"…) and no URLs in the copy.
- **The disclosure always shows:** "Grown-ups only. These are partner links: we may earn a fee if you sign up or buy. Nothing here is investment advice, and your child never sees this section."
- **Never in kid screens.** `check-rules.sh` rule 7 fails if `Partners.list`/`shown` or `PartnerPicks` appears outside GrownUps.swift. The web's kids e2e tests fail on any external link outside the gated corner.

### Filling it is the owner's call (money changes hands)

Steps when you decide to:

1. **Pick programs.**
   - **Books:** Amazon Associates (affiliate-program.amazon.com) or Bookshop.org's affiliate program.
     - Amazon's Operating Agreement has historically barred Associates from sites "directed toward children under 13". Moon Club is child-directed even though the picks sit in the grown-up corner, so **ask Amazon or read the current agreement first**. Bookshop.org or a publisher's own program may fit better.
   - **Kids' cards and custodial/learning accounts:** these programs usually run through networks such as Impact, CJ or Partnerize. They're financial products, so read each program's rules on where its links may appear (many forbid child-directed placements), and keep Moon Club's "never advice" stance: describe, don't recommend.
2. **Add entries** to `Partners.list` (Swift) and `KIDS_PARTNERS` (TS): `id`, `title`, one-sentence `blurb`, `url` with the program's tag. Run `make test` and `npm run check`. The tests that assert "ships empty" must be updated in the same PR, deliberately.
3. **App Store:**
   - **Guideline 1.3 (Kids Category):** Moon Club isn't in the Kids Category (APPSTORE.md). If it ever opts in, links out for commerce must be behind a parental gate (they are) and the app may not include third-party advertising. Affiliate links are likely to be read as advertising there.
   - **Guideline 5.1.1 / 5.1.4:** nothing about the child is collected or sent. The link only opens Safari.
   - **Age rating:** `asc.mjs store-rating` answers `advertising: false`. With partner links live, reconsider that answer and the review notes, and mention the grown-up-only picks in the App Review notes.
4. **COPPA:** the app collects nothing, and the affiliate tag identifies *us*, not the family. The partner's site is outside the app, and a grown-up opens it. Keep it behind the gate, keep the disclosure, and add a line to the privacy policy (metaphases `/kids/privacy`): "the grown-up corner may show partner links; we may earn a fee; we share nothing about you or your child."
5. **FTC:** the disclosure sits above the links, in plain words, every time. Don't add endorsements you haven't used.

## App Privacy impact (nutrition label stays "Data Not Collected")

- **Universal links:** iOS (Apple's CDN) fetches the AASA file from our site. The app sends nothing, and the router only reads the URL it was handed.
- **Share links:** user-initiated through the iOS share sheet. The URL names a lesson, a pack or a league code (companies, dates and guesses only, as before); nothing is uploaded.
- **Campaign credit:** Apple's own App Store analytics, measured on the App Store side, aggregate and opt-in. There's no SDK and no identifier in the app, so it isn't "data collected" by the app.
- **Partner slot:** empty, so nothing changes. Even filled, it's a plain link to Safari with no data from the app.
- `PrivacyInfo.xcprivacy` is unchanged: no tracking, no collected data types, no new required-reason APIs.
