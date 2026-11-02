# Compliance: deferred until after the family prototype

The user's call (2026-11-02): ship a working prototype to their own kids and beta nephews first, then work through COPPA, regulation and App Store compliance. This file lists what's deferred and what's already true by design.

## Already true by design
- **No personal data collected.** There are no accounts, names, emails or analytics, and no third-party SDKs. Progress lives in one file in Application Support, with file protection on.
- **No ads, no in-app purchases, nothing to buy.** Money is pretend; there's no broker and no buy button.
- **No links out of the app** except in the Grown-up corner, behind a multiplication parental gate (enforced by `scripts/check-rules.sh`).
- **Network use is limited to:**
  - read-only market data from mutaafaziz.com/metaphases
  - Luna questions sent to the free kid-safe model: no key, capped at 200 characters, and the UI asks kids not to type personal details
  - an optional voice provider on a grown-up's own key, which only ever speaks app text or Luna's answers
- **Privacy manifest:** no tracking, and no collected data types.

## Deferred (do before an App Store / Kids Category release)
- [ ] **COPPA review of Luna.** Kid-typed questions do reach the Workers AI model through our worker. Decide whether that counts as collecting personal information from children, and what notice and consent it needs. Options: keep it with a verifiable parental-consent step, restrict it to tap-to-ask chips only, or keep free text behind the grown-up gate.
- [ ] Privacy policy URL (required by App Store Connect, and for the Kids Category).
- [ ] **Kids Category opt-in (age 6–8 or 9–11).** Requirements:
  - parental gates for links, purchases and settings (gate already exists)
  - no third-party analytics or ads (already true)
  - review the human-review notes
- [ ] Age rating questionnaire.
- [ ] App Store screenshots and marketing copy (`make shots` produces the raw frames).
- [ ] **Grown-up voice keys.** Confirm the third-party TTS terms allow children's content; document the data flow in the privacy policy.
- [ ] Accessibility audit with VoiceOver on device.
- [ ] Legal review of "pretend money / not investment advice" copy.
