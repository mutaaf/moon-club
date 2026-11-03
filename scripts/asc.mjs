#!/usr/bin/env node
// App Store Connect API helper for Moon Club. No dependencies: Node's crypto signs the ES256 JWT.
// Reads .env.testflight (TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH). Never prints the key.
//
//   node scripts/asc.mjs whoami            check the key works and list the apps it can see
//   node scripts/asc.mjs bundle            register com.mutaafaziz.moonclub (idempotent)
//   node scripts/asc.mjs ship <build>      wait for processing, set the release notes, hand the build to testers
//   node scripts/asc.mjs capabilities      enable the bundle id's capabilities (iCloud key-value storage)
//   node scripts/asc.mjs signing           create/install an Apple Distribution cert + one App Store profile per bundle id (no cloud signing)
//   node scripts/asc.mjs notes [version]   print the TestFlight notes that would be sent (lint)
//
// App Store (docs/APPSTORE.md;  runs the idempotent ones):
//   node scripts/asc.mjs store-check       readiness report: every blocker and how to fix it (exit 1 if blocked)
//   node scripts/asc.mjs store-meta        version (from MARKETING_VERSION), listing, name/subtitle, privacy URL, categories,
//                                          content rights, review contact + notes, free in all territories, attach the App Store build
//   node scripts/asc.mjs store-rating      age rating questionnaire
//   node scripts/asc.mjs store-shots [dir] upload build/store-shots/{iphone-69,ipad-13}/*.png (replaces a changed set)
//   node scripts/asc.mjs submit --yes      send the version to App Review (the only public step; never run by scripts)
//
// Testers: internal group "Moon Club Crew" (access to all builds, so new builds reach it automatically).
// BETA_EXTERNAL=1 also adds the build to the external group "Nephew Squad" and submits it for Beta App Review.
import { createSign, createPrivateKey } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BUNDLE = "com.mutaafaziz.moonclub";
/** Everything we sign: the app and its widget/Live Activity extension, each with its own App Store profile. */
const TARGETS = [
  { id: BUNDLE, name: "Moon Club", profile: "Moon Club App Store" },
  { id: `${BUNDLE}.widgets`, name: "Moon Club Widgets", profile: "Moon Club Widgets App Store" },
];
const INTERNAL = "Moon Club Crew";
const EXTERNAL = "Nephew Squad";
const API = "https://api.appstoreconnect.apple.com";

function env() {
  const f = join(ROOT, ".env.testflight");
  const out = { ...process.env };
  if (existsSync(f)) for (const line of readFileSync(f, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z_]+)=(.*)$/);
    if (m) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, "").replace(/^\$HOME|^~/, process.env.HOME);
  }
  for (const k of ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"]) if (!out[k]) throw new Error(`Missing ${k} in .env.testflight — see docs/TESTFLIGHT.md`);
  return out;
}

const b64u = (b) => Buffer.from(b).toString("base64url");
let cached;
function token() {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.jwt;
  const e = env();
  const head = b64u(JSON.stringify({ alg: "ES256", kid: e.ASC_KEY_ID, typ: "JWT" }));
  const body = b64u(JSON.stringify({ iss: e.ASC_ISSUER_ID, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" }));
  const sig = createSign("SHA256").update(`${head}.${body}`).sign({ key: createPrivateKey(readFileSync(e.ASC_KEY_PATH)), dsaEncoding: "ieee-p1363" });
  cached = { jwt: `${head}.${body}.${b64u(sig)}`, exp: now + 1200 };
  return cached.jwt;
}

async function api(method, path, body) {
  const r = await fetch(API + path, {
    method, headers: { authorization: `Bearer ${token()}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  const json = text ? JSON.parse(text) : {};
  if (!r.ok) {
    const why = (json.errors ?? []).map((x) => `${x.title}: ${x.detail}`).join("; ") || text;
    const err = new Error(`${method} ${path} → ${r.status} ${why}`);
    err.status = r.status; err.body = json;
    throw err;
  }
  return json;
}

async function app() {
  const r = await api("GET", `/v1/apps?filter[bundleId]=${BUNDLE}&limit=1`);
  if (!r.data.length) throw new Error(`No App Store Connect app for ${BUNDLE} yet. Create it once: Apps → + → New App (see docs/TESTFLIGHT.md).`);
  return r.data[0];
}

function version() {
  return readFileSync(join(ROOT, "project.yml"), "utf8").match(/MARKETING_VERSION:\s*"([^"]+)"/)[1];
}

/** release-notes/<version>.md → TestFlight "What to Test" text: markdown stripped, ≤ 4000 characters. */
export function notesFor(v = version()) {
  const f = join(ROOT, "release-notes", `${v}.md`);
  if (!existsSync(f)) throw new Error(`No release notes for ${v}. Write release-notes/${v}.md first (style: release-notes/README.md).`);
  const raw = readFileSync(f, "utf8");
  const kid = raw.match(/^## Luna's news\n([\s\S]*?)(?=^## |(?![\s\S]))/m);
  const kidLines = kid ? kid[1].split("\n").filter((l) => /^- \[[a-z0-9.]+\] \S/.test(l)) : [];
  if (kidLines.length < 1 || kidLines.length > 4) throw new Error(`release-notes/${v}.md needs a "## Luna's news" section with 1–4 "- [sf.symbol] kid line" items (shown in the in-app update reel).`);
  const long = kidLines.find((l) => l.replace(/^- \[[^\]]+\] /, "").length > 90);
  if (long) throw new Error(`release-notes/${v}.md: Luna's news lines must be ≤ 90 characters: ${long}`);
  const text = raw
    .replace(/^## Luna's news\n[\s\S]*?(?=^## |(?![\s\S]))/m, "") // kid reel lives in the app; TestFlight gets the grown-up notes
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/^#{1,6}\s*/gm, "")
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/\*([^*\n]+)\*/g, "$1")
    .replace(/(^|\s)_(.+?)_(?=\s|$)/g, "$1$2")
    .replace(/^\s*[-*]\s+/gm, "• ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  // TestFlight rejects emoji in whatsNew ("invalid characters"); keep them in the file / in-app, strip them here.
  const plain = text.replace(/[\p{Extended_Pictographic}\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}]/gu, "").replace(/[ \t]+$/gm, "").replace(/ {2,}/g, " ");
  if (plain.length > 4000) throw new Error(`release-notes/${v}.md is ${plain.length} characters; TestFlight allows 4000.`);
  if (/https?:\/\//.test(text)) throw new Error(`release-notes/${v}.md has a link; keep notes link-free (kids rules).`);
  return plain;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function group(appId, name, internal) {
  const r = await api("GET", `/v1/betaGroups?filter[app]=${appId}&filter[name]=${encodeURIComponent(name)}`);
  if (r.data.length) return r.data[0];
  const attributes = internal ? { name, isInternalGroup: true, hasAccessToAllBuilds: true } : { name, publicLinkEnabled: true, publicLinkLimitEnabled: true, publicLinkLimit: 25, feedbackEnabled: true };
  const c = await api("POST", "/v1/betaGroups", { data: { type: "betaGroups", attributes, relationships: { app: { data: { type: "apps", id: appId } } } } });
  console.log(`✓ created ${internal ? "internal" : "external"} group “${name}”`);
  return c.data;
}

async function ship(buildNumber) {
  if (!buildNumber) throw new Error("usage: asc.mjs ship <build number>");
  const notes = notesFor();
  const a = await app();
  let b;
  for (let i = 0; i < 60; i++) { // up to ~30 minutes: uploads take a while to appear and process
    const r = await api("GET", `/v1/builds?filter[app]=${a.id}&filter[version]=${buildNumber}&limit=1`);
    b = r.data[0];
    const state = b?.attributes.processingState;
    if (state === "VALID") break;
    if (state === "FAILED" || state === "INVALID") throw new Error(`Build ${buildNumber} processing ${state}`);
    process.stdout.write(i ? "." : `… waiting for build ${buildNumber} to finish processing `);
    await sleep(30000);
  }
  if (b?.attributes.processingState !== "VALID") throw new Error(`Build ${buildNumber} still processing; rerun: node scripts/asc.mjs ship ${buildNumber}`);
  console.log(`\n✓ build ${buildNumber} processed`);

  const locs = await api("GET", `/v1/builds/${b.id}/betaBuildLocalizations`);
  const en = locs.data.find((l) => l.attributes.locale === "en-US");
  if (en) await api("PATCH", `/v1/betaBuildLocalizations/${en.id}`, { data: { type: "betaBuildLocalizations", id: en.id, attributes: { whatsNew: notes } } });
  else await api("POST", "/v1/betaBuildLocalizations", { data: { type: "betaBuildLocalizations", attributes: { locale: "en-US", whatsNew: notes }, relationships: { build: { data: { type: "builds", id: b.id } } } } });
  console.log("✓ release notes set (What to Test)");

  await group(a.id, INTERNAL, true);
  await crew();

  if (process.env.BETA_EXTERNAL === "1") {
    const g = await group(a.id, EXTERNAL, false);
    await api("POST", `/v1/betaGroups/${g.id}/relationships/builds`, { data: [{ type: "builds", id: b.id }] });
    try {
      await api("POST", "/v1/betaAppReviewSubmissions", { data: { type: "betaAppReviewSubmissions", relationships: { build: { data: { type: "builds", id: b.id } } } } });
      console.log(`✓ submitted for Beta App Review; “${EXTERNAL}” gets it once approved`);
    } catch (e) {
      if (e.status === 409) console.log(`• Beta App Review: ${e.message.split("→")[1].trim()}`);
      else throw e;
    }
  }
}

async function bundle() {
  for (const t of TARGETS) await bundleId(t);
}
/** Find or register one bundle id (idempotent). */
async function bundleId(t) {
  const r = await api("GET", `/v1/bundleIds?filter[identifier]=${t.id}`);
  const hit = r.data.find((x) => x.attributes.identifier === t.id);
  if (hit) { console.log(`✓ bundle id ${t.id} already registered`); return hit; }
  const c = (await api("POST", "/v1/bundleIds", { data: { type: "bundleIds", attributes: { identifier: t.id, name: t.name, platform: "IOS" } } })).data;
  console.log(`✓ registered bundle id ${t.id}`);
  return c;
}

async function whoami() {
  const r = await api("GET", "/v1/apps?limit=50&fields[apps]=name,bundleId");
  console.log(`✓ key works — ${r.data.length} app(s) visible`);
  for (const x of r.data) console.log(`  ${x.attributes.bundleId}  ${x.attributes.name}`);
}

/** Distribution signing without Xcode cloud signing (App Manager keys can't use it):
 *  an Apple Distribution certificate from our own CSR, plus an App Store profile, both installed locally. */
async function signing() {
  const { execFileSync } = await import("node:child_process");
  const { writeFileSync, mkdirSync, readdirSync, unlinkSync } = await import("node:fs");
  const dir = join(process.env.HOME, ".appstoreconnect", "signing");
  const certs = await api("GET", "/v1/certificates?filter[certificateType]=DISTRIBUTION,IOS_DISTRIBUTION&limit=50");
  const keyPath = join(dir, "dist.key");
  const mine = existsSync(join(dir, "dist.cer.id")) && certs.data.find((c) => c.id === readFileSync(join(dir, "dist.cer.id"), "utf8").trim());
  let cert = mine;
  if (!cert) {
    const csr = readFileSync(join(dir, "dist.csr"), "utf8");
    cert = (await api("POST", "/v1/certificates", { data: { type: "certificates", attributes: { certificateType: "DISTRIBUTION", csrContent: csr } } })).data;
    writeFileSync(join(dir, "dist.cer.id"), cert.id);
    console.log("✓ created Apple Distribution certificate");
  }
  const der = Buffer.from(cert.attributes.certificateContent, "base64");
  writeFileSync(join(dir, "dist.cer"), der);
  execFileSync("sh", ["-c", `openssl x509 -inform der -in "${dir}/dist.cer" -out "${dir}/dist.pem" && openssl pkcs12 -export -legacy -inkey "${keyPath}" -in "${dir}/dist.pem" -out "${dir}/dist.p12" -passout pass:moonclub 2>/dev/null || openssl pkcs12 -export -inkey "${keyPath}" -in "${dir}/dist.pem" -out "${dir}/dist.p12" -passout pass:moonclub; security import "${dir}/dist.p12" -k ~/Library/Keychains/login.keychain-db -P moonclub -T /usr/bin/codesign >/dev/null 2>&1 || true`]);
  console.log("✓ distribution identity in the login keychain");
  const pdir = join(process.env.HOME, "Library", "Developer", "Xcode", "UserData", "Provisioning Profiles");
  mkdirSync(pdir, { recursive: true });
  for (const t of TARGETS) {
    const bid = await bundleId(t);
    if (t.id === BUNDLE) await capabilities(bid.id); // before the profile, so the profile carries them (iCloud KVS)
    const profs = await api("GET", `/v1/profiles?filter[name]=${encodeURIComponent(t.profile)}&limit=10`);
    for (const p of profs.data) await api("DELETE", `/v1/profiles/${p.id}`); // re-create so it always holds the current cert
    // Drop stale local copies of this profile name, so the export can only pick the fresh one.
    for (const f of readdirSync(pdir).filter((f) => f.endsWith(".mobileprovision"))) {
      try {
        const xml = execFileSync("security", ["cms", "-D", "-i", join(pdir, f)], { stdio: ["ignore", "pipe", "ignore"] }).toString();
        if (xml.match(/<key>Name<\/key>\s*<string>([^<]*)<\/string>/)?.[1] === t.profile) unlinkSync(join(pdir, f));
      } catch {}
    }
    const prof = (await api("POST", "/v1/profiles", { data: { type: "profiles", attributes: { name: t.profile, profileType: "IOS_APP_STORE" }, relationships: {
      bundleId: { data: { type: "bundleIds", id: bid.id } }, certificates: { data: [{ type: "certificates", id: cert.id }] } } } })).data;
    writeFileSync(join(pdir, `${prof.attributes.uuid}.mobileprovision`), Buffer.from(prof.attributes.profileContent, "base64"));
    console.log(`✓ installed profile “${t.profile}” (${prof.attributes.uuid})`);
  }
}

/** Put every App Store Connect team member into the internal group (internal testers must be team users). */
async function crew() {
  const a = await app();
  const g = await group(a.id, INTERNAL, true);
  const users = (await api("GET", "/v1/users?limit=100")).data;
  const have = new Set((await api("GET", `/v1/betaGroups/${g.id}/betaTesters?limit=200`)).data.map((t) => (t.attributes.email || "").toLowerCase()));
  let added = 0;
  for (const u of users) {
    const email = (u.attributes.username || "").toLowerCase();
    if (!email || have.has(email)) continue;
    try {
      await api("POST", "/v1/betaTesters", { data: { type: "betaTesters", attributes: { email, firstName: u.attributes.firstName, lastName: u.attributes.lastName },
        relationships: { betaGroups: { data: [{ type: "betaGroups", id: g.id }] } } } });
      added++;
    } catch (e) { if (e.status !== 409) throw e; }
  }
  console.log(`✓ “${INTERNAL}”: ${have.size + added} tester(s) (${added} added); each gets a TestFlight invite email`);
}

/** Capabilities the app's entitlements need, enabled on the bundle id (idempotent).
 *  ICLOUD: key-value storage for opt-in progress sync (com.apple.developer.ubiquity-kvstore-identifier). */
async function capabilities(bundleIdId) {
  const id = bundleIdId ?? (await api("GET", `/v1/bundleIds?filter[identifier]=${BUNDLE}`)).data.find((x) => x.attributes.identifier === BUNDLE).id;
  const have = new Set((await api("GET", `/v1/bundleIds/${id}/bundleIdCapabilities`)).data.map((c) => c.attributes.capabilityType));
  for (const capabilityType of ["ICLOUD"]) {
    if (have.has(capabilityType)) continue;
    await api("POST", "/v1/bundleIdCapabilities", { data: { type: "bundleIdCapabilities",
      attributes: { capabilityType, settings: [{ key: "ICLOUD_VERSION", options: [{ key: "XCODE_6" }] }] },
      relationships: { bundleId: { data: { type: "bundleIds", id } } } } });
    console.log(`✓ enabled ${capabilityType} on ${BUNDLE}`);
  }
  console.log(`✓ capabilities: ${[...new Set([...have, "ICLOUD"])].join(", ")}`);
}

/** TestFlight "Test Information" + Beta App Review contact, needed once before the first external review.
 *  Contact details come from .env.testflight (BETA_CONTACT_*), never from the repo. */
async function betaInfo() {
  const e = env();
  for (const k of ["BETA_CONTACT_FIRST", "BETA_CONTACT_LAST", "BETA_CONTACT_EMAIL", "BETA_CONTACT_PHONE"]) if (!e[k]) throw new Error(`Missing ${k} in .env.testflight`);
  const a = await app();
  const attrs = {
    description: "Moon Club teaches kids aged 8 to 12 how money works by playing: Luna's Lemonade Stand quest, one-minute Moon School lessons, a pretend piggy bank that follows real prices, and Guess the Report Card. Pretend money only. No accounts, no ads, no tracking.",
    feedbackEmail: e.BETA_CONTACT_EMAIL,
    marketingUrl: "https://mutaafaziz.com/metaphases/kids/app",
    privacyPolicyUrl: "https://mutaafaziz.com/metaphases/kids/privacy",
  };
  const locs = await api("GET", `/v1/apps/${a.id}/betaAppLocalizations`);
  const en = locs.data.find((l) => l.attributes.locale === "en-US");
  if (en) await api("PATCH", `/v1/betaAppLocalizations/${en.id}`, { data: { type: "betaAppLocalizations", id: en.id, attributes: attrs } });
  else await api("POST", "/v1/betaAppLocalizations", { data: { type: "betaAppLocalizations", attributes: { locale: "en-US", ...attrs }, relationships: { app: { data: { type: "apps", id: a.id } } } } });
  console.log("✓ beta app description, feedback email, privacy policy");
  const d = await api("GET", `/v1/apps/${a.id}/betaAppReviewDetail`);
  await api("PATCH", `/v1/betaAppReviewDetails/${d.data.id}`, { data: { type: "betaAppReviewDetails", id: d.data.id, attributes: {
    contactFirstName: e.BETA_CONTACT_FIRST, contactLastName: e.BETA_CONTACT_LAST, contactEmail: e.BETA_CONTACT_EMAIL, contactPhone: e.BETA_CONTACT_PHONE,
    demoAccountRequired: false,
    notes: "No sign-in needed. Everything works offline with pretend money. Ask Luna (the AI helper) uses Apple Intelligence on device when available, or our free kid-safe server model. For grown-ups (behind a multiplication gate) holds settings.",
  } } });
  console.log("✓ beta review contact");
}

/** The external group's public TestFlight link and whether testers can join yet. */
async function link() {
  const a = await app();
  const g = (await api("GET", `/v1/betaGroups?filter[app]=${a.id}&filter[name]=${encodeURIComponent(EXTERNAL)}`)).data[0];
  if (!g) return console.log("No external group yet: BETA_EXTERNAL=1 node scripts/asc.mjs ship <build>");
  const subs = await api("GET", `/v1/betaAppReviewSubmissions?filter[build]=${(await api("GET", `/v1/betaGroups/${g.id}/builds?limit=1`)).data[0]?.id ?? "none"}`).catch(() => ({ data: [] }));
  console.log(`${g.attributes.publicLink ?? "(no public link)"}  review: ${subs.data[0]?.attributes.betaReviewState ?? "not submitted"}`);
}

/** Debug passthrough: node scripts/asc.mjs call GET "/v1/bundleIds?limit=5" ['<json body>'] (prints JSON; never the key). */
async function call(method, path, body) { console.log(JSON.stringify(await api(method, path, body ? JSON.parse(body) : undefined), null, 2)); }

// ── App Store submission (docs/APPSTORE.md) ─────────────────────────────────────────────────────────────
// Everything below only edits the draft App Store version (reversible, nothing public) except `submit`,
// which sends the version to App Review and needs `--yes`.

/** The listing. Kid-safe, fun but clear, never financial advice. Limits: name/subtitle 30, promo 170, keywords 100. */
export const STORE = {
  name: "Moon Club",
  subtitle: "Money games for curious kids",
  promotionalText: "New: the Moon Shop! Earn Moon points in chart games, quizzes and lessons, then dress up Luna and your rocket. Pretend money only, always.",
  keywords: "kids,money,saving,piggy bank,learn,charts,candles,quiz,math,allowance,budget,moon,education,games",
  description: `Learn how money and markets work by playing, with Luna the moon as your guide. Made for kids about 8 to 12 and the grown-ups who learn with them.

EXPLORE MARKET WORLD
Sail from Lemonade Coast to Report Card Castle. Every stop is a quick lesson, a chart game or a boss quiz. Build a candle, spot a trend, find the floor, and race the Chart Time Machine through real price history.

STORY MISSIONS
Help Luna run her lemonade stand, decide whether to save or grow, and find out how a slice of a company can pay you. Short daily missions and a treasure chest keep the adventure going.

A PRETEND PIGGY BANK
Pick a few favorite companies and watch a pretend piggy bank follow real prices. It is pretend money only: nothing can be bought, sold or paid for.

GUESS THE REPORT CARD
Companies share a report card a few times a year. Guess whether it beats or misses, then see what happened.

ASK LUNA
Curious what a dividend is? Ask Luna. She uses simple words, sticks to money topics, never gives advice, and every answer is checked on the device first. On devices with Apple Intelligence she thinks right on the device.

THE MOON LOCKER
Earn Moon points by playing, collect badges, climb from New Moon to Supermoon, and spend points in the Moon Shop on hats, rocket skins and trails for Luna.

MADE FOR FAMILIES
- No ads, no accounts, no in-app purchases, no tracking
- Settings and links sit behind a grown-up gate
- Optional sync across your family's devices through your own iCloud
- Widgets and Live Activities for streaks and missions
- Works on iPhone and iPad

Moon Club teaches how markets work. It is for learning and fun, not investment advice.`,
  supportUrl: "https://mutaafaziz.com/metaphases/kids/app",
  marketingUrl: "https://mutaafaziz.com/metaphases/kids",
  privacyPolicyUrl: "https://mutaafaziz.com/metaphases/kids/privacy",
  copyright: `${new Date().getUTCFullYear()} Mutaaf Aziz`,
  primaryCategory: "EDUCATION",
  secondaryCategory: "GAMES",
  secondarySubcategories: ["GAMES_FAMILY", "GAMES_TRIVIA"], // Apple has no Games › Educational subcategory (GET /v1/appCategories/GAMES/subcategories)
  // Market prices and company names come from public market data (via mutaafaziz.com/metaphases).
  contentRights: "USES_THIRD_PARTY_CONTENT",
  reviewNotes: `Moon Club teaches kids (about 8 to 12) how money and markets work. No sign-in, no accounts, no ads, no analytics, no in-app purchases. Everything works offline; when online it refreshes read-only market prices from our own server (mutaafaziz.com).

GROWN-UP GATE: "For grown-ups" (the lock button at the top right, or in the More/sidebar menu) asks a multiplication question before showing settings. The only links out of the app are inside that gated area.

PRETEND MONEY: the Piggy Bank follows real prices with pretend dollars. Moon points are earned only by playing and can only be spent in the in-app Moon Shop on cosmetic items (hats, rocket skins). Nothing is for sale and nothing can be bought or traded. Nothing in the app is financial advice.

ICLOUD SYNC: optional and off by default. A grown-up turns it on behind the gate; progress then syncs through the family's own iCloud key-value storage. We never receive it.

ASK LUNA (AI helper): on devices with Apple Intelligence, answers are generated on the device with Apple's Foundation Models framework and nothing leaves the device. Otherwise the question (max 200 characters, no name, account or device identifier) goes to our own free kid-safe model on mutaafaziz.com, which answers in real time and does not store it. Every answer uses the same kid-safe instructions plus an on-device check; Luna only discusses money topics, never gives advice and asks kids not to type personal details. This App Store build contains no third-party AI provider, API key or voice service.

To try everything quickly: World tab (map) > tap a glowing stop; Story tab > today's missions; Ask Luna tab > tap a suggested question.`,
};

/** Required screenshot sets: display type → [width, height] (portrait) and the folder `make store-shots` fills. */
// Display types come from the API's own enum (POST a bogus type and it lists them): there is no APP_IPHONE_69,
// 6.9" (1320×2868) goes in APP_IPHONE_67. APP_IPHONE_DUO earns the "Made for iPhone Duo" badge (27.1 SDK builds).
const SHOT_SETS = [
  { types: ["APP_IPHONE_67"], sizes: [[1320, 2868]], dir: "iphone-69", label: '6.9" iPhone', required: true },
  { types: ["APP_IPAD_PRO_3GEN_129"], sizes: [[2064, 2752]], dir: "ipad-13", label: '13" iPad', required: true },
  { types: ["APP_IPHONE_DUO"], sizes: [[1398, 2034], [2007, 2853]], dir: "iphone-duo", label: "iPhone Duo (outer/inner)", required: false },
];
const STORE_BUILD_SUFFIX = ".1"; // App Store builds are numbered <UTC timestamp>.1 (scripts/testflight.sh STORE=1)
const EDITABLE = new Set(["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"]);

async function appInfo(appId) {
  const r = await api("GET", `/v1/apps/${appId}/appInfos`);
  return r.data.find((i) => i.attributes.appStoreState !== "READY_FOR_SALE" && i.attributes.state !== "READY_FOR_DISTRIBUTION") ?? r.data[0];
}
/** The editable App Store version (created from MARKETING_VERSION if there is none). */
async function storeVersion(appId, create = false) {
  const v = version();
  const all = (await api("GET", `/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&limit=20`)).data;
  let sv = all.find((x) => EDITABLE.has(x.attributes.appStoreState));
  if (!sv && create) {
    sv = (await api("POST", "/v1/appStoreVersions", { data: { type: "appStoreVersions", attributes: { platform: "IOS", versionString: v }, relationships: { app: { data: { type: "apps", id: appId } } } } })).data;
    console.log(`✓ created App Store version ${v}`);
  }
  return { sv, shipped: all.some((x) => x.attributes.appStoreState === "READY_FOR_SALE") };
}
async function upsert(listPath, type, createRel, match, attributes) {
  const hit = (await api("GET", listPath)).data.find(match);
  if (hit) { const { locale, ...rest } = attributes; return (await api("PATCH", `/v1/${type}/${hit.id}`, { data: { type, id: hit.id, attributes: rest } })).data; }
  return (await api("POST", `/v1/${type}`, { data: { type, attributes, relationships: createRel } })).data;
}
/** Newest processed App Store build (<timestamp>.1) for this version. */
async function storeBuild(appId, v = version()) {
  const pre = (await api("GET", `/v1/preReleaseVersions?filter[app]=${appId}&filter[version]=${v}&filter[platform]=IOS`)).data[0];
  if (!pre) return { build: null, any: null };
  const builds = (await api("GET", `/v1/builds?filter[preReleaseVersion]=${pre.id}&filter[processingState]=VALID&sort=-uploadedDate&limit=50`)).data.filter((b) => !b.attributes.expired);
  return { build: builds.find((b) => b.attributes.version.endsWith(STORE_BUILD_SUFFIX)) ?? null, any: builds[0] ?? null };
}

async function storeMeta() {
  const e = env();
  const a = await app();
  const { sv, shipped } = await storeVersion(a.id, true);
  const v = version();
  if (sv.attributes.versionString !== v) {
    await api("PATCH", `/v1/appStoreVersions/${sv.id}`, { data: { type: "appStoreVersions", id: sv.id, attributes: { versionString: v } } });
    console.log(`✓ App Store version ${sv.attributes.versionString} → ${v} (matches MARKETING_VERSION)`);
  }
  await api("PATCH", `/v1/appStoreVersions/${sv.id}`, { data: { type: "appStoreVersions", id: sv.id, attributes: { copyright: STORE.copyright, releaseType: "AFTER_APPROVAL" } } });

  // Version localization (description, keywords, URLs; What's New only exists after the first release).
  const loc = { description: STORE.description, keywords: STORE.keywords, promotionalText: STORE.promotionalText, supportUrl: STORE.supportUrl, marketingUrl: STORE.marketingUrl };
  if (shipped) loc.whatsNew = notesFor(v);
  for (const [k, max] of [["keywords", 100], ["promotionalText", 170], ["description", 4000]]) if (loc[k].length > max) throw new Error(`${k} is ${loc[k].length} chars (max ${max})`);
  await upsert(`/v1/appStoreVersions/${sv.id}/appStoreVersionLocalizations`, "appStoreVersionLocalizations",
    { appStoreVersion: { data: { type: "appStoreVersions", id: sv.id } } }, (l) => l.attributes.locale === "en-US", { locale: "en-US", ...loc });
  console.log(`✓ en-US listing: description, keywords, promotional text, support + marketing URLs${shipped ? ", What's New" : " (What's New starts with the 2nd release)"}`);

  // App info: name, subtitle, privacy policy, categories.
  const info = await appInfo(a.id);
  try {
    await upsert(`/v1/appInfos/${info.id}/appInfoLocalizations`, "appInfoLocalizations", { appInfo: { data: { type: "appInfos", id: info.id } } },
      (l) => l.attributes.locale === "en-US", { locale: "en-US", name: STORE.name, subtitle: STORE.subtitle, privacyPolicyUrl: STORE.privacyPolicyUrl });
    console.log(`✓ name “${STORE.name}”, subtitle, privacy policy URL`);
  } catch (err) {
    if (/name/i.test(err.message) && err.status === 409) console.log(`✗ the name “${STORE.name}” is not available: ${err.message}`);
    else throw err;
  }
  const rel = (id, type = "appCategories") => ({ data: id ? { type, id } : null });
  try {
    await api("PATCH", `/v1/appInfos/${info.id}`, { data: { type: "appInfos", id: info.id, relationships: {
      primaryCategory: rel(STORE.primaryCategory), secondaryCategory: rel(STORE.secondaryCategory),
      secondarySubcategoryOne: rel(STORE.secondarySubcategories[0]), secondarySubcategoryTwo: rel(STORE.secondarySubcategories[1]) } } });
    console.log(`✓ categories: Education; Games › Family, Trivia`);
  } catch (err) {
    await api("PATCH", `/v1/appInfos/${info.id}`, { data: { type: "appInfos", id: info.id, relationships: { primaryCategory: rel(STORE.primaryCategory), secondaryCategory: rel(STORE.secondaryCategory) } } });
    console.log(`✓ categories: Education; Games (subcategories refused: ${err.message.split("→")[1]?.trim()})`);
  }

  await api("PATCH", `/v1/apps/${a.id}`, { data: { type: "apps", id: a.id, attributes: { contentRightsDeclaration: STORE.contentRights } } });
  console.log(`✓ content rights: ${STORE.contentRights}`);

  // App Review contact + notes (contact from .env.testflight; never printed).
  for (const k of ["BETA_CONTACT_FIRST", "BETA_CONTACT_LAST", "BETA_CONTACT_EMAIL", "BETA_CONTACT_PHONE"]) if (!e[k]) throw new Error(`Missing ${k} in .env.testflight`);
  const review = { contactFirstName: e.BETA_CONTACT_FIRST, contactLastName: e.BETA_CONTACT_LAST, contactEmail: e.BETA_CONTACT_EMAIL, contactPhone: e.BETA_CONTACT_PHONE,
    demoAccountRequired: false, notes: STORE.reviewNotes };
  const rd = await api("GET", `/v1/appStoreVersions/${sv.id}/appStoreReviewDetail`).catch((err) => (err.status === 404 ? { data: null } : Promise.reject(err)));
  if (rd.data) await api("PATCH", `/v1/appStoreReviewDetails/${rd.data.id}`, { data: { type: "appStoreReviewDetails", id: rd.data.id, attributes: review } });
  else await api("POST", "/v1/appStoreReviewDetails", { data: { type: "appStoreReviewDetails", attributes: review, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: sv.id } } } } });
  console.log("✓ App Review contact and notes");

  await storePricing(a.id);
  await storeAttach(a.id, sv);
}

/** Free in every territory, including new ones. */
async function storePricing(appId) {
  const have = await api("GET", `/v1/apps/${appId}/appPriceSchedule?include=manualPrices`).catch(() => null);
  const prices = have?.included?.filter((x) => x.type === "appPrices") ?? [];
  let free = false;
  if (prices.length) {
    const pp = await api("GET", `/v1/appPriceSchedules/${have.data.id}/manualPrices?include=appPricePoint&limit=5`).catch(() => null);
    free = (pp?.included ?? []).every((p) => Number(p.attributes.customerPrice) === 0) && (pp?.included ?? []).length > 0;
  }
  if (!free) {
    const points = await api("GET", `/v1/apps/${appId}/appPricePoints?filter[territory]=USA&limit=200`);
    const zero = points.data.find((p) => Number(p.attributes.customerPrice) === 0);
    if (!zero) throw new Error("No free price point for USA");
    await api("POST", "/v1/appPriceSchedules", {
      data: { type: "appPriceSchedules", relationships: { app: { data: { type: "apps", id: appId } }, baseTerritory: { data: { type: "territories", id: "USA" } },
        manualPrices: { data: [{ type: "appPrices", id: "${free}" }] } } },
      included: [{ type: "appPrices", id: "${free}", attributes: { startDate: null }, relationships: { appPricePoint: { data: { type: "appPricePoints", id: zero.id } } } }],
    });
  }
  console.log("✓ price: free");
  // Availability: every territory, and new ones automatically.
  const avail = await api("GET", `/v1/apps/${appId}/appAvailabilityV2`).catch((err) => (err.status === 404 ? null : Promise.reject(err)));
  const territories = [];
  for (let next = "/v1/territories?limit=200"; next; ) {
    const r = await api("GET", next.replace(API, ""));
    territories.push(...r.data.map((t) => t.id));
    next = r.links?.next;
  }
  if (avail?.data) {
    const ta = [];
    for (let next = `/v2/appAvailabilities/${avail.data.id}/territoryAvailabilities?limit=200&include=territory`; next; ) {
      const r = await api("GET", next.replace(API, ""));
      ta.push(...r.data);
      next = r.links?.next;
    }
    const off = ta.filter((t) => !t.attributes.available);
    for (const t of off) await api("PATCH", `/v1/territoryAvailabilities/${t.id}`, { data: { type: "territoryAvailabilities", id: t.id, attributes: { available: true } } }).catch((err) => console.log(`• ${t.id}: ${err.message.split("→")[1]?.trim()}`));
    console.log(`✓ available in ${ta.length} territories${off.length ? ` (${off.length} switched on)` : ""}`);
    return;
  }
  await api("POST", "/v2/appAvailabilities", {
    data: { type: "appAvailabilities", attributes: { availableInNewTerritories: true }, relationships: { app: { data: { type: "apps", id: appId } },
      territoryAvailabilities: { data: territories.map((t) => ({ type: "territoryAvailabilities", id: `\${${t}}` })) } } },
    included: territories.map((t) => ({ type: "territoryAvailabilities", id: `\${${t}}`, attributes: { available: true, releaseDate: null, preOrderEnabled: false }, relationships: { territory: { data: { type: "territories", id: t } } } })),
  });
  console.log(`✓ available in all ${territories.length} territories (and new ones)`);
}

/** Attach the newest App Store build (<timestamp>.1) of this version, if one has processed. */
async function storeAttach(appId, sv) {
  const { build, any } = await storeBuild(appId);
  if (!build) {
    console.log(`• no App Store build for ${version()} yet${any ? ` (newest is ${any.attributes.version}, a TestFlight family build with own-key features)` : ""}: run \`make appstore-build\`, then \`node scripts/asc.mjs store-meta\` again`);
    return;
  }
  await api("PATCH", `/v1/appStoreVersions/${sv.id}/relationships/build`, { data: { type: "builds", id: build.id } });
  console.log(`✓ build ${build.attributes.version} attached`);
}

/** Age rating, answered truthfully (docs/APPSTORE.md explains each answer). */
export const RATING = {
  alcoholTobaccoOrDrugUseOrReferences: "NONE", contests: "NONE", gamblingSimulated: "NONE", gunsOrOtherWeapons: "NONE",
  medicalOrTreatmentInformation: "NONE", profanityOrCrudeHumor: "NONE", sexualContentGraphicAndNudity: "NONE", sexualContentOrNudity: "NONE",
  horrorOrFearThemes: "NONE", matureOrSuggestiveThemes: "NONE", violenceCartoonOrFantasy: "NONE", violenceRealistic: "NONE",
  violenceRealisticProlongedGraphicOrSadistic: "NONE",
  gambling: false, lootBox: false, unrestrictedWebAccess: false, userGeneratedContent: false, messagingAndChat: false,
  advertising: false, healthOrWellnessTopics: false, ageAssurance: false, socialMedia: false, socialMediaAgeRestricted: false,
  parentalControls: true, // the multiplication gate guards settings, sync, Luna's brain and every link
};
async function storeRating() {
  const a = await app();
  const info = await appInfo(a.id);
  const d = await api("GET", `/v1/appInfos/${info.id}/ageRatingDeclaration`);
  const known = new Set(Object.keys(d.data.attributes));
  const attrs = Object.fromEntries(Object.entries(RATING).filter(([k]) => known.has(k)));
  const skipped = Object.keys(RATING).filter((k) => !known.has(k));
  try {
    await api("PATCH", `/v1/ageRatingDeclarations/${d.data.id}`, { data: { type: "ageRatingDeclarations", id: d.data.id, attributes: attrs } });
  } catch (err) {
    // An attribute this API version rejects: drop it and say so, rather than guessing.
    const bad = Object.keys(attrs).filter((k) => err.message.includes(k));
    if (!bad.length) throw err;
    for (const k of bad) delete attrs[k];
    skipped.push(...bad);
    await api("PATCH", `/v1/ageRatingDeclarations/${d.data.id}`, { data: { type: "ageRatingDeclarations", id: d.data.id, attributes: attrs } });
  }
  const after = (await api("GET", `/v1/appInfos/${info.id}`)).data.attributes;
  const unanswered = Object.entries((await api("GET", `/v1/appInfos/${info.id}/ageRatingDeclaration`)).data.attributes).filter(([k, v]) => v === null && !/kidsAgeBand|Url|Number|brazil|korea/i.test(k)).map(([k]) => k);
  console.log(`✓ age rating questionnaire: ${Object.keys(attrs).length} answers → ${after.appStoreAgeRating ?? "(rating computed on submit)"}`);
  if (skipped.length) console.log(`• not set (not in this API version): ${skipped.join(", ")}`);
  if (unanswered.length) console.log(`• still unanswered: ${unanswered.join(", ")} — answer in App Store Connect → App Information → Age Rating`);
}

/** Upload build/store-shots/<set>/*.png to the en-US screenshot sets. Idempotent: an identical set is left alone. */
async function storeShots(dir = join(ROOT, "build", "store-shots")) {
  const { createHash } = await import("node:crypto");
  const { readdirSync, statSync } = await import("node:fs");
  const a = await app();
  const { sv } = await storeVersion(a.id, true);
  const loc = (await api("GET", `/v1/appStoreVersions/${sv.id}/appStoreVersionLocalizations`)).data.find((l) => l.attributes.locale === "en-US");
  if (!loc) throw new Error("No en-US listing yet: run node scripts/asc.mjs store-meta first");
  const sets = (await api("GET", `/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?limit=50`)).data;
  for (const s of SHOT_SETS) {
    const folder = join(dir, s.dir);
    const files = existsSync(folder) ? readdirSync(folder).filter((f) => f.endsWith(".png")).sort() : [];
    if (!files.length) { console.log(`${s.required ? "✗" : "•"} ${s.label}: no PNGs in ${folder} (make store-shots)`); continue; }
    if (files.length > 10) throw new Error(`${s.label}: ${files.length} screenshots (max 10)`);
    const local = files.map((f) => {
      const buf = readFileSync(join(folder, f));
      const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
      if (!s.sizes.some(([sw, sh]) => sw === w && sh === h)) throw new Error(`${f} is ${w}×${h}; ${s.label} needs ${s.sizes.map((x) => x.join("×")).join(" or ")}`);
      return { f, buf, md5: createHash("md5").update(buf).digest("hex") };
    });
    // Find (or create) the set; the newest display type first, falling back if this API doesn't know it.
    let set = sets.find((x) => s.types.includes(x.attributes.screenshotDisplayType));
    for (const t of s.types) {
      if (set) break;
      try {
        set = (await api("POST", "/v1/appScreenshotSets", { data: { type: "appScreenshotSets", attributes: { screenshotDisplayType: t },
          relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc.id } } } } })).data;
      } catch (err) { if (t === s.types.at(-1)) throw err; }
    }
    const remote = (await api("GET", `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=10`)).data;
    // Same files in the same order = nothing to do. Apple fills sourceFileChecksum only after processing, so a
    // just-uploaded set matches on name + size until then; a FAILED one is always replaced.
    const same = (r, l) => r.attributes.fileName === l.f && r.attributes.fileSize === l.buf.length && r.attributes.assetDeliveryState?.state !== "FAILED"
      && (r.attributes.sourceFileChecksum == null || r.attributes.sourceFileChecksum === l.md5);
    if (remote.length === local.length && remote.every((r, i) => same(r, local[i]))) {
      console.log(`✓ ${s.label} (${set.attributes.screenshotDisplayType}): ${local.length} screenshots already up to date`);
      continue;
    }
    for (const r of remote) await api("DELETE", `/v1/appScreenshots/${r.id}`);
    const ids = [];
    for (const l of local) {
      const shot = (await api("POST", "/v1/appScreenshots", { data: { type: "appScreenshots", attributes: { fileName: l.f, fileSize: l.buf.length },
        relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set.id } } } } })).data;
      for (const op of shot.attributes.uploadOperations) {
        const r = await fetch(op.url, { method: op.method, headers: Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value])), body: l.buf.subarray(op.offset, op.offset + op.length) });
        if (!r.ok) throw new Error(`upload ${l.f} part @${op.offset} → ${r.status}`);
      }
      await api("PATCH", `/v1/appScreenshots/${shot.id}`, { data: { type: "appScreenshots", id: shot.id, attributes: { uploaded: true, sourceFileChecksum: l.md5 } } });
      ids.push(shot.id);
    }
    await api("PATCH", `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, { data: ids.map((id) => ({ type: "appScreenshots", id })) });
    // Wait for Apple to finish processing so a failure shows up here, not at submission.
    let st = [];
    for (let i = 0; i < 100; i++) { // up to ~5 minutes
      st = (await api("GET", `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=10`)).data.map((x) => x.attributes.assetDeliveryState?.state);
      if (st.every((x) => x === "COMPLETE")) break;
      const failed = st.filter((x) => x === "FAILED").length;
      if (failed) throw new Error(`${s.label}: ${failed} screenshot(s) failed processing`);
      await sleep(3000);
    }
    const pending = st.filter((x) => x !== "COMPLETE").length;
    console.log(`✓ ${s.label} (${set.attributes.screenshotDisplayType}): uploaded ${ids.length} screenshots${pending ? ` (${pending} still processing at Apple; store-check counts only finished ones)` : ""}`);
  }
}

/** Readiness report: every blocker, with how to fix it. Exit code 1 if anything blocks submission. */
async function storeCheck() {
  const out = [];
  const ok = (m) => out.push(["ok", m]);
  const bad = (m, fix) => out.push(["block", m, fix]);
  const warn = (m, fix) => out.push(["warn", m, fix]);
  const a = await app();
  const v = version();
  const { sv, shipped } = await storeVersion(a.id);
  if (!sv) bad("No editable App Store version", "node scripts/asc.mjs store-meta");
  else if (sv.attributes.versionString !== v) bad(`App Store version is ${sv.attributes.versionString}, MARKETING_VERSION is ${v}`, "node scripts/asc.mjs store-meta");
  else ok(`App Store version ${v} (${sv.attributes.appStoreState})`);

  if (sv) {
    const b = (await api("GET", `/v1/appStoreVersions/${sv.id}/build`).catch(() => ({ data: null }))).data;
    if (!b) bad("No build attached", "make appstore-build (an App Store build, numbered <timestamp>.1), then node scripts/asc.mjs store-meta");
    else if (!b.attributes.version.endsWith(STORE_BUILD_SUFFIX)) bad(`Attached build ${b.attributes.version} is a TestFlight family build (own-key AI features compiled in)`, "make appstore-build, then node scripts/asc.mjs store-meta");
    else ok(`Build ${b.attributes.version} attached${b.attributes.usesNonExemptEncryption === false ? " (no non-exempt encryption)" : ""}`);

    const loc = (await api("GET", `/v1/appStoreVersions/${sv.id}/appStoreVersionLocalizations`)).data.find((l) => l.attributes.locale === "en-US");
    const missing = loc ? ["description", "keywords", "supportUrl"].filter((k) => !loc.attributes[k]) : ["en-US listing"];
    if (shipped && loc && !loc.attributes.whatsNew) missing.push("whatsNew");
    if (missing.length) bad(`Listing incomplete: ${missing.join(", ")}`, "node scripts/asc.mjs store-meta");
    else ok("Listing: description, keywords, promotional text, support/marketing URLs");
    if (!sv.attributes.copyright) bad("No copyright", "node scripts/asc.mjs store-meta"); else ok(`Copyright: ${sv.attributes.copyright}`);

    if (loc) {
      const sets = (await api("GET", `/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?include=appScreenshots&limit=50`));
      for (const s of SHOT_SETS) {
        const set = sets.data.find((x) => s.types.includes(x.attributes.screenshotDisplayType));
        const n = set ? (await api("GET", `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=10`)).data.filter((x) => x.attributes.assetDeliveryState?.state === "COMPLETE").length : 0;
        if (!n && s.required) bad(`No ${s.label} screenshots`, "make store-shots && node scripts/asc.mjs store-shots");
        else if (!n) warn(`No ${s.label} screenshots (optional: they earn the Made for iPhone Duo badge)`, "make store-shots && node scripts/asc.mjs store-shots");
        else ok(`${s.label} screenshots: ${n}`);
      }
    }
    const rd = await api("GET", `/v1/appStoreVersions/${sv.id}/appStoreReviewDetail`).catch(() => ({ data: null }));
    const r = rd.data?.attributes;
    if (!r?.contactEmail || !r?.contactPhone || !r?.contactFirstName) bad("App Review contact missing", "node scripts/asc.mjs store-meta (BETA_CONTACT_* in .env.testflight)");
    else if (!r.notes) bad("App Review notes missing", "node scripts/asc.mjs store-meta");
    else ok("App Review contact and notes");
  }

  const info = await appInfo(a.id);
  const il = (await api("GET", `/v1/appInfos/${info.id}/appInfoLocalizations`)).data.find((l) => l.attributes.locale === "en-US")?.attributes;
  if (!il?.name) bad("No app name", "node scripts/asc.mjs store-meta"); else ok(`Name: ${il.name}${il.subtitle ? ` — ${il.subtitle}` : ""}`);
  if (!il?.privacyPolicyUrl) bad("No privacy policy URL", "node scripts/asc.mjs store-meta");
  else {
    const page = await fetch(il.privacyPolicyUrl).then((r) => (r.ok ? r.text() : "")).catch(() => "");
    // The site is a SPA: a 200 alone proves nothing, so look for the policy's own words in the served HTML or its title.
    if (!page) bad(`Privacy policy URL doesn't load: ${il.privacyPolicyUrl}`, "publish the page (metaphases /kids/privacy)");
    else if (!/privacy/i.test(page.match(/<title>([^<]*)<\/title>/i)?.[1] ?? "")) bad(`Privacy policy URL loads, but it isn't a privacy page (title doesn't mention privacy; the SPA falls back to the kids home)`, "publish metaphases /kids/privacy with a PAGES share entry");
    else ok(`Privacy policy: ${il.privacyPolicyUrl}`);
  }
  const cat = (await api("GET", `/v1/appInfos/${info.id}/primaryCategory`).catch(() => ({ data: null }))).data;
  if (!cat) bad("No primary category", "node scripts/asc.mjs store-meta"); else ok(`Primary category: ${cat.id}`);

  const ard = (await api("GET", `/v1/appInfos/${info.id}/ageRatingDeclaration`)).data.attributes;
  const nulls = Object.entries(ard).filter(([k, x]) => x === null && !/kidsAgeBand|Url|Number|brazil|korea/i.test(k)).map(([k]) => k);
  if (nulls.length) bad(`Age rating unanswered: ${nulls.join(", ")}`, "node scripts/asc.mjs store-rating");
  else ok(`Age rating answered${info.attributes.appStoreAgeRating ? ` (${info.attributes.appStoreAgeRating})` : ""}; Kids Category: ${ard.kidsAgeBand ?? "not selected"}`);

  const apps = (await api("GET", `/v1/apps/${a.id}`)).data.attributes;
  if (!apps.contentRightsDeclaration) bad("Content rights not declared", "node scripts/asc.mjs store-meta"); else ok(`Content rights: ${apps.contentRightsDeclaration}`);

  const ps = await api("GET", `/v1/apps/${a.id}/appPriceSchedule`).catch(() => null);
  if (!ps?.data) bad("No price set", "node scripts/asc.mjs store-meta"); else ok("Price schedule set (free)");
  const av = await api("GET", `/v1/apps/${a.id}/appAvailabilityV2`).catch(() => null);
  if (!av?.data) bad("Availability not set", "node scripts/asc.mjs store-meta"); else ok(`Availability set${av.data.attributes.availableInNewTerritories ? " (incl. new territories)" : ""}`);

  // Things the API can't see: say so every time, so nobody assumes they're done.
  warn("App Privacy (nutrition label) can't be read or set through the API", "App Store Connect → App Privacy: answers in docs/APPSTORE.md, then Publish");
  warn("Agreements, tax and banking aren't visible to an App Manager key (a free app needs only the Free Apps agreement, accepted by the Account Holder)", "App Store Connect → Business");
  const encOk = /INFOPLIST_KEY_ITSAppUsesNonExemptEncryption:\s*NO/.test(readFileSync(join(ROOT, "project.yml"), "utf8"));
  if (encOk) ok("Export compliance: ITSAppUsesNonExemptEncryption = NO in project.yml"); else bad("Export compliance key missing from project.yml", "add INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO");

  const icon = { ok: "✓", warn: "•", block: "✗" };
  for (const [k, m, fix] of out) console.log(`${icon[k]} ${m}${fix ? `\n    → ${fix}` : ""}`);
  const blockers = out.filter((x) => x[0] === "block").length;
  console.log(blockers ? `\n${blockers} blocker(s) before \`node scripts/asc.mjs submit --yes\`.` : "\nReady: once the App Privacy label is published, `node scripts/asc.mjs submit --yes` sends it to App Review.");
  if (blockers) process.exitCode = 1;
}

/** Send the draft version to App Review. Needs --yes: this is the one public, not-easily-undone step. */
async function submit() {
  if (!process.argv.includes("--yes")) {
    console.log("This sends Moon Club to App Review. Check first: node scripts/asc.mjs store-check\nThen: node scripts/asc.mjs submit --yes");
    process.exitCode = 2; return;
  }
  const a = await app();
  const { sv } = await storeVersion(a.id);
  if (!sv) throw new Error("No editable App Store version");
  // Reuse an open (unsubmitted) review submission, or start one.
  const open = (await api("GET", `/v1/reviewSubmissions?filter[app]=${a.id}&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW&limit=5`)).data[0];
  const subm = open ?? (await api("POST", "/v1/reviewSubmissions", { data: { type: "reviewSubmissions", attributes: { platform: "IOS" }, relationships: { app: { data: { type: "apps", id: a.id } } } } })).data;
  const items = (await api("GET", `/v1/reviewSubmissions/${subm.id}/items?include=appStoreVersion`)).data;
  if (!items.some((i) => i.relationships?.appStoreVersion?.data?.id === sv.id))
    await api("POST", "/v1/reviewSubmissionItems", { data: { type: "reviewSubmissionItems", relationships: { reviewSubmission: { data: { type: "reviewSubmissions", id: subm.id } }, appStoreVersion: { data: { type: "appStoreVersions", id: sv.id } } } } });
  await api("PATCH", `/v1/reviewSubmissions/${subm.id}`, { data: { type: "reviewSubmissions", id: subm.id, attributes: { submitted: true } } });
  console.log(`✓ Moon Club ${sv.attributes.versionString} submitted for App Review (submission ${subm.id}). It releases automatically once approved.`);
}

const [cmd, arg] = process.argv.slice(2);
const run = { whoami, bundle, signing, "beta-info": betaInfo, link, crew, capabilities: () => capabilities(), call: () => call(arg, process.argv[4], process.argv[5]),
  "store-check": storeCheck, "store-meta": storeMeta, "store-rating": storeRating, "store-shots": () => storeShots(arg), submit, ship: () => ship(arg), notes: () => console.log(notesFor(arg)) }[cmd];
if (!run) { console.log("usage: asc.mjs whoami | bundle | ship <build> | notes [version] | store-check | store-meta | store-rating | store-shots [dir] | submit --yes"); process.exit(2); }
Promise.resolve().then(run).catch((e) => { console.error("✗ " + e.message); process.exit(1); });
