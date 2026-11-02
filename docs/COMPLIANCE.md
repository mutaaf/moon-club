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
- [ ] **BYOK = kid text to a third party.** With a grown-up's own key, a child's free-text questions go to that AI company. Before public release: confirm each provider's terms allow under-13 content through a parent's account (several require users to be 18+ or exclude children's data); decide whether the in-app toggle counts as verifiable parental consent under COPPA, or whether BYOK must be limited to tap-to-ask questions; and name each provider in the privacy policy. On-device Apple Intelligence sends nothing, so it is the recommended default.
- [ ] **Grown-up voice keys.** Confirm the third-party TTS terms allow children's content; document the data flow in the privacy policy.
- [ ] Accessibility audit with VoiceOver on device.
- [ ] Legal review of "pretend money / not investment advice" copy.
