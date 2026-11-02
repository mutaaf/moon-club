#!/usr/bin/env node
// App Store Connect API helper for Moon Club. No dependencies: Node's crypto signs the ES256 JWT.
// Reads .env.testflight (TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH). Never prints the key.
//
//   node scripts/asc.mjs whoami            check the key works and list the apps it can see
//   node scripts/asc.mjs bundle            register com.mutaafaziz.moonclub (idempotent)
//   node scripts/asc.mjs ship <build>      wait for processing, set the release notes, hand the build to testers
//   node scripts/asc.mjs capabilities      enable the bundle id's capabilities (iCloud key-value storage)
//   node scripts/asc.mjs signing           create/install an Apple Distribution cert + App Store profile (no cloud signing)
//   node scripts/asc.mjs notes [version]   print the TestFlight notes that would be sent (lint)
//
// Testers: internal group "Moon Club Crew" (access to all builds, so new builds reach it automatically).
// BETA_EXTERNAL=1 also adds the build to the external group "Nephew Squad" and submits it for Beta App Review.
import { createSign, createPrivateKey } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BUNDLE = "com.mutaafaziz.moonclub";
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
  const text = readFileSync(f, "utf8")
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
  const r = await api("GET", `/v1/bundleIds?filter[identifier]=${BUNDLE}`);
  if (r.data.some((x) => x.attributes.identifier === BUNDLE)) return console.log(`✓ bundle id ${BUNDLE} already registered`);
  await api("POST", "/v1/bundleIds", { data: { type: "bundleIds", attributes: { identifier: BUNDLE, name: "Moon Club", platform: "IOS" } } });
  console.log(`✓ registered bundle id ${BUNDLE}`);
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
  const { writeFileSync, mkdirSync } = await import("node:fs");
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
  const bid = (await api("GET", `/v1/bundleIds?filter[identifier]=${BUNDLE}`)).data.find((x) => x.attributes.identifier === BUNDLE);
  await capabilities(bid.id); // before the profile, so the profile carries them
  const name = "Moon Club App Store";
  const profs = await api("GET", `/v1/profiles?filter[name]=${encodeURIComponent(name)}&limit=10`);
  for (const p of profs.data) await api("DELETE", `/v1/profiles/${p.id}`); // re-create so it always holds the current cert
  const prof = (await api("POST", "/v1/profiles", { data: { type: "profiles", attributes: { name, profileType: "IOS_APP_STORE" }, relationships: {
    bundleId: { data: { type: "bundleIds", id: bid.id } }, certificates: { data: [{ type: "certificates", id: cert.id }] } } } })).data;
  const pdir = join(process.env.HOME, "Library", "Developer", "Xcode", "UserData", "Provisioning Profiles");
  mkdirSync(pdir, { recursive: true });
  writeFileSync(join(pdir, `${prof.attributes.uuid}.mobileprovision`), Buffer.from(prof.attributes.profileContent, "base64"));
  console.log(`✓ installed profile “${name}” (${prof.attributes.uuid})`);
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

const [cmd, arg] = process.argv.slice(2);
const run = { whoami, bundle, signing, "beta-info": betaInfo, link, crew, capabilities: () => capabilities(), ship: () => ship(arg), notes: () => console.log(notesFor(arg)) }[cmd];
if (!run) { console.log("usage: asc.mjs whoami | bundle | ship <build> | notes [version]"); process.exit(2); }
Promise.resolve().then(run).catch((e) => { console.error("✗ " + e.message); process.exit(1); });
