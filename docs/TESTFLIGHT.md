# Shipping Moon Club to TestFlight

Ready in the repo:
- iPhone + iPad target (`TARGETED_DEVICE_FAMILY 1,2`), bundle id `com.mutaafaziz.moonclub`
- Luna app icon
- Privacy manifest: no tracking, no data collected
- `ITSAppUsesNonExemptEncryption = NO`
- Automatic signing with team **Z73865R687**
- One-command archive + upload

## One-time setup (about 5 minutes, in a browser)
1. **App record.** App Store Connect → Apps → **+** → New App. Choose iOS, name **Moon Club**, bundle ID `com.mutaafaziz.moonclub` (register it under developer.apple.com → Identifiers if it isn't listed), SKU `moonclub`. For the category, pick Education. Do *not* opt into the Kids Category yet (see COMPLIANCE.md).
2. **API key.** App Store Connect → Users and Access → Integrations → App Store Connect API → **Generate** with role **App Manager**. Save the `.p8` to `~/.appstoreconnect/private_keys/`.
3. Create `moon-club/.env.testflight` (gitignored):
   ```sh
   TEAM_ID=Z73865R687
   ASC_KEY_ID=XXXXXXXXXX
   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ASC_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
   ```

## Every release
```sh
make testflight
```
This checks `release-notes/<version>.md` exists (house style: `release-notes/README.md`: fun, family-friendly pop-culture nods, no links), registers the bundle ids (app + `.widgets` extension) if needed, runs `asc.mjs signing` (our own Apple Distribution certificate and one App Store profile per bundle id: the App Manager key can't use cloud signing), runs the rules and every test, then archives and exports with manual signing and uploads. Build numbers are UTC timestamps, so they always increase. After upload, `scripts/asc.mjs ship` waits for processing, then:
- sets the TestFlight "What to Test" text from the release notes
- makes sure the internal group **Moon Club Crew** exists (it gets every build automatically)
- cuts a GitHub pre-release with the same notes

The same notes appear in the app under For grown-ups → What's new.
`BETA_EXTERNAL=1 make testflight` also adds the build to the external group **Nephew Squad** (public link, capped at 25) and submits it for Beta App Review.
The first external submission needs the beta app description and review contact filled in once, under TestFlight → Test Information.
`node scripts/asc.mjs whoami` checks the key.

## Testers
- **Internal testers** (people on your App Store Connect team, up to 100) can install as soon as processing finishes. This is the fastest way to reach your own kids' devices: sign them in with a family Apple ID that is on the team, or use your own.
- **External testers** (nephews' parents) need one Beta App Review. Use a public link, or invite them by email.
  - Suggested "What to test": *Play Luna's Lemonade Stand, finish a Moon School lesson, guess a report card, start a pretend piggy bank.*
  - Demo mode for reviewers: everything works offline. Live data needs no account.
- Privacy questionnaire: **Data Not Collected**.
