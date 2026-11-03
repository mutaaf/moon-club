# Compliance: deferred until after the family prototype

The user's call (2026-11-02): ship a working prototype to their own kids and beta nephews first, then work through COPPA, regulation and App Store compliance. This file lists what's deferred and what's already true by design.

## Already true by design
- **No personal data collected.** There are no accounts, names, emails or analytics, and no third-party SDKs. Progress lives in one file in Application Support, with file protection on.
- **No ads, no in-app purchases, nothing to buy.** Money is pretend; there's no broker and no buy button.
- **No links out of the app** except in the Grown-up corner, behind a multiplication parental gate (enforced by `scripts/check-rules.sh`).
- **Network use is limited to:**
  - read-only market data from mutaafaziz.com/metaphases
  - Luna questions: by default answered **on the device** with Apple Intelligence (nothing sent) when the device supports it; otherwise sent to the free kid-safe model with no key, capped at 200 characters. The UI asks kids not to type personal details.
  - **Only if a grown-up adds their own key and turns on the disclosure** ("your child's questions will be sent to <provider> using your key") are kid-typed questions and the chat's recent turns sent directly to that third party (Anthropic, OpenAI, Google or xAI) under the grown-up's own account and that company's terms. Consent is per provider and resets when the provider changes.
  - an optional voice provider on a grown-up's own key, which only ever speaks app text or Luna's answers
- **Sync across devices stays in the family's iCloud.** Opt-in per device behind the gate. Progress goes to the family's own iCloud key-value storage; Apple holds it in their account, and we never receive it (there's no server of ours). An own AI key moves only if a grown-up turns on "Use on my other devices", and only through iCloud Keychain, which is end-to-end encrypted. Under the privacy manifest this is still "data not collected", since the developer never gets it.
- **Web → app transfer is a code a grown-up copies.** It holds only lesson ids, days, picks and pretend-money numbers. There's no upload, no camera and no account.
- **Privacy manifest:** no tracking, and no collected data types.

## App Store 1.0 (2026-11-03)
Decided in `docs/APPSTORE.md`: listed under Education with a 4+ rating, **not** in the Kids Category. App Store builds compile with `STORE_BUILD` (no grown-up own-key AI or voice), so a child's text never reaches a third-party AI company in the App Store app. Privacy policy: https://mutaafaziz.com/metaphases/kids/privacy. App Privacy label: Data Not Collected. Items below still apply to a Kids Category opt-in and to the TestFlight family builds.

## Deferred (do before an App Store / Kids Category release)
- [ ] **COPPA review of Luna.** Kid-typed questions do reach the Workers AI model through our worker. Decide whether that counts as collecting personal information from children, and what notice and consent it needs. Options: keep it with a verifiable parental-consent step, restrict it to tap-to-ask chips only, or keep free text behind the grown-up gate.
- [x] Privacy policy URL: https://mutaafaziz.com/metaphases/kids/privacy (metaphases `/kids/privacy`).
- [ ] **Kids Category opt-in (age 6–8 or 9–11).** Requirements:
  - parental gates for links, purchases and settings (gate already exists)
  - no third-party analytics or ads (already true)
  - review the human-review notes
- [x] Age rating questionnaire: `asc.mjs store-rating` (4+; answers in docs/APPSTORE.md).
- [x] App Store screenshots and marketing copy: `make appstore` (`scripts/store-shots.sh`, `STORE` in `scripts/asc.mjs`).
- [ ] **BYOK = kid text to a third party.** With a grown-up's own key, a child's free-text questions go to that AI company. Before public release: confirm each provider's terms allow under-13 content through a parent's account (several require users to be 18+ or exclude children's data); decide whether the in-app toggle counts as verifiable parental consent under COPPA, or whether BYOK must be limited to tap-to-ask questions; and name each provider in the privacy policy. On-device Apple Intelligence sends nothing, so it is the recommended default.
- [ ] **Grown-up voice keys.** Confirm the third-party TTS terms allow children's content; document the data flow in the privacy policy.
- [ ] **iCloud sync note in the privacy policy.** Say that progress can sync through the family's iCloud account if a grown-up turns it on, and that we never receive it.
- [ ] Accessibility audit with VoiceOver on device.
- [ ] Legal review of "pretend money / not investment advice" copy.

## Widgets and Live Activities (0.7.0)
- Widgets read a tiny snapshot the app writes to a shared keychain group on this device: app content (company nicknames, lesson titles), small numbers and dates. They hold no free text, no names and nothing a kid typed (enforced by a unit test's key allowlist). No network from the widget extension.
- Live Activities update locally only: no push token is ever requested (`check-rules.sh`).
- Keychain items are `AfterFirstUnlockThisDeviceOnly`: never synced to iCloud, readable by Lock Screen widgets after the first unlock. They survive deleting the app (an iOS keychain behavior), still only on this device. "Reset all progress" in the grown-up corner clears them. Before a public release, consider moving to an App Group container, which is deleted with the app. That needs a one-time developer-portal setup.

