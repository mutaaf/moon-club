#!/usr/bin/env node
// Moon Club app icon, drawn in code so it's reproducible: `node scripts/brand/icon.mjs` (also `make icon`).
//
// Writes
//   MoonClub/AppIcon.icon/            Icon Composer bundle (iOS 26+ Liquid Glass): background fill + 3 layer groups,
//                                      with default, dark and tinted/clear appearances
//   scripts/brand/luna-icon.svg       the same art flattened onto a square (source of the PNG below)
//   MoonClub/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//                                      opaque 1024 fallback for iOS 17-25 (no alpha, no rounded corners)
//   [previews] with --preview <dir>: every .icon appearance via Icon Composer's ictool + small-size checks
//
// No dependencies: macOS `sips` renders the SVG with CoreSVG (the renderer Icon Composer uses). Art: Luna (the club's moon, with cheeks and a smile) in a
// night sky, a few sparkles, and a tiny rocket in orbit. Same colours as MoonClub/Design/Theme.swift.
import { writeFileSync, readFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { toRGB } from "./png.mjs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const S = 1024;
const C = { moon: "#FFF3C4", moonHi: "#FFF9E0", moonShade: "#ECD88F", moonDeep: "#D9BE6A", ink: "#16152B", blush: "#FF8FA6", star: "#FFF6D6" };

// Luna: centred a little low and left, so the rocket has sky to fly in.
const L = { x: 492, y: 548, r: 292 };
const svg = (body, defs = "") => `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">${defs ? `<defs>${defs}</defs>` : ""}${body}</svg>\n`;
const sparkle = (x, y, r, fill = C.star, o = 1) =>
  `<path d="M${x} ${y - r} C${x + r * 0.16} ${y - r * 0.16} ${x + r * 0.16} ${y - r * 0.16} ${x + r} ${y} C${x + r * 0.16} ${y + r * 0.16} ${x + r * 0.16} ${y + r * 0.16} ${x} ${y + r} C${x - r * 0.16} ${y + r * 0.16} ${x - r * 0.16} ${y + r * 0.16} ${x - r} ${y} C${x - r * 0.16} ${y - r * 0.16} ${x - r * 0.16} ${y - r * 0.16} ${x} ${y - r}Z" fill="${fill}" opacity="${o}"/>`;
const dot = (x, y, r, o = 1) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${C.star}" opacity="${o}"/>`;

// ── layers ───────────────────────────────────────────────────────────────────────────────────────────
// Back: the sky's sparkles. Few and big enough to survive 29 pt (tiny dots vanish anyway, so only a couple).
const stars = svg([
  sparkle(178, 214, 58), sparkle(842, 646, 40), sparkle(214, 842, 34, C.star, 0.9),
  dot(330, 128, 12, 0.85), dot(118, 520, 10, 0.75), dot(884, 870, 13, 0.8), dot(640, 120, 9, 0.7),
].join(""));

// Warm halo behind Luna (hidden in tinted/clear: it would read as a grey smudge).
const halo = svg(`<circle cx="${L.x}" cy="${L.y}" r="${L.r * 1.42}" fill="url(#h)"/>`,
  `<radialGradient id="h" cx="0.5" cy="0.5" r="0.5"><stop offset="0.6" stop-color="#FFE7A3" stop-opacity="0.38"/><stop offset="1" stop-color="#FFE7A3" stop-opacity="0"/></radialGradient>`);

// Middle: Luna's disc with a lit side, a soft terminator crescent on the left and two craters.
const { x, y, r } = L;
const moon = svg(
  `<circle cx="${x}" cy="${y}" r="${r}" fill="url(#m)"/>` +
  // terminator: a crescent between the disc's left edge and a wider arc (CoreSVG ignores clip-path, so no clipping)
  `<path d="M${x} ${y - r} A ${r} ${r} 0 0 0 ${x} ${y + r} A ${r * 1.08} ${r * 1.08} 0 0 1 ${x} ${y - r}Z" fill="${C.moonShade}" opacity="0.6"/>` +
  `<circle cx="${x + r * 0.46}" cy="${y - r * 0.52}" r="${r * 0.15}" fill="${C.moonShade}" opacity="0.75"/>` +
  `<circle cx="${x + r * 0.62}" cy="${y + r * 0.42}" r="${r * 0.09}" fill="${C.moonShade}" opacity="0.6"/>` +
  `<circle cx="${x - r * 0.5}" cy="${y + r * 0.6}" r="${r * 0.1}" fill="${C.moonDeep}" opacity="0.4"/>`,
  `<radialGradient id="m" cx="0.4" cy="0.34" r="0.7"><stop offset="0" stop-color="${C.moonHi}"/><stop offset="0.55" stop-color="${C.moon}"/><stop offset="1" stop-color="${C.moonShade}"/></radialGradient>`);

// Luna's face: shiny eyes, rosy cheeks, a big smile. Separate layer so the glass lifts it off the disc.
const ex = r * 0.3, ey = y - r * 0.1;
const face = svg(
  [-1, 1].map((s) =>
    `<ellipse cx="${x + s * ex}" cy="${ey}" rx="${r * 0.095}" ry="${r * 0.125}" fill="${C.ink}"/>` +
    `<circle cx="${x + s * ex + r * 0.03}" cy="${ey - r * 0.045}" r="${r * 0.034}" fill="#FFFFFF"/>` +
    `<ellipse cx="${x + s * r * 0.5}" cy="${y + r * 0.16}" rx="${r * 0.13}" ry="${r * 0.095}" fill="${C.blush}" opacity="0.85"/>`).join("") +
  `<path d="M${x - r * 0.22} ${y + r * 0.13} Q ${x} ${y + r * 0.42} ${x + r * 0.22} ${y + r * 0.13}" fill="none" stroke="${C.ink}" stroke-width="${r * 0.085}" stroke-linecap="round"/>`);

// Front: a tiny rocket orbiting top-right, with a short dashed trail curving round the moon.
const rocket = svg(
  `<path d="M 600 236 Q 700 170 780 196" fill="none" stroke="${C.star}" stroke-width="16" stroke-linecap="round" stroke-dasharray="2 30" opacity="0.9"/>` +
  `<g transform="translate(838 214) rotate(52)">` +
  `<path d="M -22 58 Q 0 120 22 58 Z" fill="#FFB547"/><path d="M -11 58 Q 0 96 11 58 Z" fill="#FFE27A"/>` + // flame
  `<path d="M -34 30 L -58 66 L -24 58 Z M 34 30 L 58 66 L 24 58 Z" fill="#FF6F7D"/>` + // fins
  `<path d="M 0 -78 C 38 -44 40 18 30 60 L -30 60 C -40 18 -38 -44 0 -78 Z" fill="#F4F1FF"/>` + // body
  `<path d="M 0 -78 C 18 -62 28 -46 32 -32 L -32 -32 C -28 -46 -18 -62 0 -78 Z" fill="#FF6F7D"/>` + // nose
  `<circle cx="0" cy="2" r="17" fill="#5B7CFA"/><circle cx="0" cy="2" r="17" fill="none" stroke="#C9D4FF" stroke-width="6"/>` +
  `</g>`);

// ── background fills (Icon Composer) and the flat fallback ───────────────────────────────────────────
const SKY = { top: "#1D2470", bottom: "#4A4FC4" }; // twilight blue: brighter than the old flat navy
const SKY_DARK = { top: "#07081C", bottom: "#191A47" };
const ext = (hex, a = 1) => { const n = parseInt(hex.slice(1), 16); return `extended-srgb:${[(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => (v / 255).toFixed(5)).join(",")},${a.toFixed(5)}`; };
const fill = (g) => ({ "linear-gradient": [ext(g.top), ext(g.bottom)], orientation: { start: { x: 0.5, y: 0 }, stop: { x: 0.5, y: 1 } } });

const iconJson = {
  "fill-specializations": [{ value: fill(SKY) }, { appearance: "dark", value: fill(SKY_DARK) }],
  groups: [
    { name: "Rocket", layers: [{ "image-name": "rocket.svg", name: "rocket", glass: true }],
      shadow: { kind: "neutral", opacity: 0.5 }, translucency: { enabled: true, value: 0.2 }, specular: true },
    { name: "Luna", layers: [
        { "image-name": "face.svg", name: "face", glass: false },
        { "image-name": "moon.svg", name: "moon", glass: true },
      ],
      shadow: { kind: "layer-color", opacity: 0.55 }, translucency: { enabled: true, value: 0.15 }, specular: true },
    { name: "Sky", layers: [
        { "image-name": "stars.svg", name: "stars", glass: true },
        { "image-name": "halo.svg", name: "halo", glass: false, "hidden-specializations": [{ appearance: "tinted", value: true }] },
      ],
      shadow: { kind: "none", opacity: 0.5 }, translucency: { enabled: true, value: 0.4 }, specular: false },
  ],
  "supported-platforms": { squares: ["iOS"] },
};

const flat = svg(
  `<rect width="${S}" height="${S}" fill="url(#sky)"/>` +
  [halo, stars, moon, face, rocket].map((s) => s.replace(/^<svg[^>]*>|<\/svg>\n$/g, "")).join("")
    .replace(/<defs>/g, "").replace(/<\/defs>/g, ""),
  `<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${SKY.top}"/><stop offset="1" stop-color="${SKY.bottom}"/></linearGradient>`);

// ── write ─────────────────────────────────────────────────────────────────────────────────────────────
const ICON = join(ROOT, "MoonClub", "AppIcon.icon");
rmSync(ICON, { recursive: true, force: true });
mkdirSync(join(ICON, "Assets"), { recursive: true });
for (const [n, s] of Object.entries({ stars, halo, moon, face, rocket })) writeFileSync(join(ICON, "Assets", `${n}.svg`), s);
writeFileSync(join(ICON, "icon.json"), JSON.stringify(iconJson, null, 2) + "\n");
writeFileSync(join(ROOT, "scripts", "brand", "luna-icon.svg"), flat);

const png = join(ROOT, "MoonClub/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png");
const tmp = png + ".tmp.png";
execFileSync("sips", ["-s", "format", "png", "-z", "1024", "1024", join(ROOT, "scripts/brand/luna-icon.svg"), "--out", tmp], { stdio: "ignore" });
// App Store icons must have no alpha channel at all: re-encode the RGBA PNG as RGB, losslessly.
writeFileSync(png, toRGB(readFileSync(tmp)));
rmSync(tmp);
const alpha = execFileSync("sips", ["-g", "hasAlpha", png]).toString();
if (!/hasAlpha: no/.test(alpha)) throw new Error("icon-1024.png still has an alpha channel");
console.log("✓ MoonClub/AppIcon.icon, scripts/brand/luna-icon.svg, AppIcon.appiconset/icon-1024.png (opaque)");

// ── previews ──────────────────────────────────────────────────────────────────────────────────────────
const pi = process.argv.indexOf("--preview");
if (pi > 0) {
  const out = process.argv[pi + 1]; mkdirSync(out, { recursive: true });
  const IC = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool";
  if (!existsSync(IC)) throw new Error("Icon Composer's ictool not found (Xcode 26+)");
  for (const rd of ["Default", "Dark", "TintedLight", "TintedDark", "ClearLight", "ClearDark"]) {
    const extra = rd.startsWith("Tinted") ? ["--tint-color", "0.6", "--tint-strength", "0.8"] : [];
    execFileSync(IC, [ICON, "--export-image", "--output-file", join(out, `icon-${rd}.png`), "--platform", "iOS", "--rendition", rd, "--width", "1024", "--height", "1024", "--scale", "1", ...extra], { stdio: "ignore" });
    for (const pt of [60, 29]) execFileSync(IC, [ICON, "--export-image", "--output-file", join(out, `icon-${rd}-${pt}pt@3x.png`), "--platform", "iOS", "--rendition", rd, "--width", String(pt), "--height", String(pt), "--scale", "3", ...extra], { stdio: "ignore" });
  }
  for (const pt of [180, 87]) execFileSync("sips", ["-z", String(pt), String(pt), png, "--out", join(out, `flat-${pt}px.png`)], { stdio: "ignore" });
  execFileSync("cp", [png, join(out, "flat-1024.png")]);
  console.log(`✓ previews in ${out}`);
}
