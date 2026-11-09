#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Moon Club's one Metal library (0.14). Swift wrappers live in Design/Shaders.swift (`FX`), and every
// effect goes through the graphics budget there (paused off screen / in the background, still frames under
// Reduce Motion, Low Power Mode or a hot device). Rules for every function here:
//  • pure ALU and tiny loops: no textures, no dynamic branches that diverge per pixel;
//  • time `t` is passed in, never accumulated, so a paused effect shows a stable still frame;
//  • colors are premultiplied on the way out (SwiftUI expects premultiplied alpha).
// Written for Moon Club; no third-party code.

// MARK: - Small helpers

static inline float hash21(float2 p) {
  p = fract(p * float2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

static inline float vnoise(float2 p) {
  float2 i = floor(p), f = fract(p);
  float2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i), b = hash21(i + float2(1, 0)), c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Four octaves of value noise, rotated each octave so it never looks gridded.
static inline float fbm(float2 p) {
  float v = 0.0, a = 0.5;
  const float2x2 r = float2x2(0.8, -0.6, 0.6, 0.8);
  for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = r * p * 2.03 + 17.0; a *= 0.5; }
  return v;
}

static inline half3 hueRamp(float h) {
  // A soft rainbow (cosine palette), for holographic sheen.
  float3 c = 0.55 + 0.45 * cos(6.28318 * (h + float3(0.0, 0.33, 0.67)));
  return half3(c);
}

// MARK: - Aurora (every tab's background)

// One soft, slowly drifting aurora field. Three colored light blobs on a base color, blended with
// smooth falloff and a faint grain so gradients never band.
[[ stitchable ]] half4 aurora(float2 pos, half4 color, float2 size, float t,
                              half4 c1, half4 c2, half4 c3, half4 base, float strength) {
  float2 uv = pos / max(size, float2(1.0));
  float aspect = size.x / max(size.y, 1.0);
  float2 p = float2(uv.x * aspect, uv.y);

  float2 a = float2(0.25 * aspect + 0.18 * sin(t * 0.11), 0.22 + 0.10 * cos(t * 0.13));
  float2 b = float2(0.80 * aspect + 0.15 * cos(t * 0.09), 0.38 + 0.12 * sin(t * 0.07 + 1.3));
  float2 c = float2(0.50 * aspect + 0.22 * sin(t * 0.05 + 2.1), 0.85 + 0.08 * cos(t * 0.10));

  float warp = 0.06 * sin(p.x * 5.0 + t * 0.35) + 0.04 * sin(p.y * 7.0 - t * 0.27);
  p.y += warp;

  float wa = exp(-dot(p - a, p - a) * 5.5);
  float wb = exp(-dot(p - b, p - b) * 4.5);
  float wc = exp(-dot(p - c, p - c) * 3.8);

  half3 col = base.rgb;
  col = mix(col, c1.rgb, half(wa * strength));
  col = mix(col, c2.rgb, half(wb * strength));
  col = mix(col, c3.rgb, half(wc * strength));

  float n = fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453);
  col += half((n - 0.5) * 0.012);
  return half4(col, 1.0);
}

// MARK: - Market World sea

// The sea under the islands. Drawn at the viewport's size behind the scrolling map; `scroll` is the map's
// content offset so the water moves with the islands. Layers:
//  • depth gradient (deep far lands at the top of the map, bright near the first coast);
//  • region color grading: the water near each land leans toward that land's color;
//  • gentle waves (a few sines) and caustics (three warped interference passes);
//  • the sun: hinge-driven on iPhone Duo (0 = moonlit night when closed … 1 = midday when flat), with a
//    glitter path; tilt nudges the caustics for parallax.
// `regions` packs [centerY, r, g, b] per land in map coordinates.
[[ stitchable ]] half4 sea(float2 pos, half4 color, float2 size, float t, float2 scroll, float mapH,
                           float sun, float2 tilt, device const float *regions, int count) {
  float2 m = pos + scroll;                         // map coordinates
  float depth = clamp(m.y / max(mapH, 1.0), 0.0, 1.0);
  half3 deep = half3(0.20, 0.33, 0.76), mid = half3(0.31, 0.62, 0.86), shallow = half3(0.53, 0.83, 0.91);
  half3 col = depth < 0.5 ? mix(deep, mid, half(depth * 2.0)) : mix(mid, shallow, half(depth * 2.0 - 1.0));

  // Region grading: weight each land by closeness in y (soft, so lands blend into each other).
  half3 tint = half3(0); float wsum = 0.0;
  int n = min(count / 4, 12);
  for (int i = 0; i < n; i++) {
    float cy = regions[i * 4];
    float w = exp(-pow((m.y - cy) / 520.0, 2.0));
    tint += half3(regions[i * 4 + 1], regions[i * 4 + 2], regions[i * 4 + 3]) * half(w);
    wsum += w;
  }
  if (wsum > 0.001) col = mix(col, mix(col, tint / half(wsum), half(0.55)), half(min(wsum, 1.0) * 0.32));

  // Waves: long soft swells.
  float2 q = m * 0.012 + tilt * 0.6;
  float swell = sin(q.x * 3.1 + t * 0.6 + sin(q.y * 1.7)) * 0.5 + sin(q.y * 4.3 - t * 0.45 + q.x) * 0.5;
  col += half(swell * 0.025);

  // Caustics: light focused by the moving surface. A warped grid of sines; the bright ridges are where
  // the product crosses zero (thin, wobbly lines like light on a pool floor). Always finite.
  float2 w = m * 0.022 + tilt * 0.8;
  for (int k = 0; k < 3; k++) {
    w += 0.55 * float2(sin(w.y * 1.3 + t * 0.35 + float(k) * 1.7), sin(w.x * 1.1 - t * 0.30 + float(k) * 2.3));
  }
  float v = sin(w.x) * sin(w.y);
  float caustic = pow(1.0 - abs(v), 7.0);
  col += half3(0.75, 0.92, 1.0) * half(caustic * (0.10 + 0.12 * sun));

  // Sun: day brightens, night cools; a glitter path down the middle of the view.
  half3 night = col * half3(0.55, 0.62, 0.95) + half3(0.02, 0.03, 0.08);
  col = mix(night, col * half3(1.04, 1.02, 0.98), half(0.35 + 0.65 * sun));
  float path = exp(-pow((pos.x / max(size.x, 1.0) - 0.5) * 3.2, 2.0));
  float glint = step(0.986, vnoise(m * 0.09 + float2(t * 0.6, -t * 0.3))) * path;
  col += half3(1.0, 0.95, 0.8) * half(glint * (0.15 + 0.5 * sun));
  // Moon glints at night: fewer, silver.
  col += half3(0.8, 0.85, 1.0) * half(step(0.993, vnoise(m * 0.07 + t * 0.2)) * (1.0 - sun) * 0.35);
  return half4(col, 1.0);
}

// MARK: - Fog over locked lands

// Volumetric-looking fog: domain-warped fbm in an elliptical mask, swirling slowly. `dissolve` 0 → 1 burns
// it away when a land is won (noise threshold with a glowing gold edge). `part` (iPhone Duo hinge, 0…0.35)
// opens a soft gap down the middle as the phone unfolds: a peek, never a clear view.
[[ stitchable ]] half4 fog(float2 pos, half4 color, float2 size, float t, float dissolve, float part, float seed) {
  float2 uv = pos / max(size, float2(1.0));
  float2 c = uv - 0.5;
  float mask = smoothstep(0.52, 0.30, length(c * float2(1.0, 1.08)));
  if (mask <= 0.001) return half4(0);

  float2 p = uv * 3.2 + seed;
  float2 w = float2(fbm(p + float2(t * 0.05, t * 0.03)), fbm(p + float2(5.2, 1.3) - t * 0.04));
  float d = fbm(p + 1.6 * w + float2(t * 0.02, 0));
  float dens = smoothstep(0.25, 0.75, d) * 0.55 + 0.5;

  // Hinge part: thin the fog in a vertical band through the middle.
  float gap = part * exp(-pow(c.x / 0.16, 2.0));
  dens *= (1.0 - gap * 1.6);

  // Burn away: noise threshold rising with `dissolve`, gold embers on the edge.
  float burn = fbm(uv * 6.0 + seed * 1.7);
  float edge = burn - (dissolve * 1.25 - 0.1);
  float keep = smoothstep(0.0, 0.06, edge);
  float rim = (1.0 - smoothstep(0.0, 0.10, abs(edge))) * step(0.001, dissolve);

  float a = clamp(dens * mask * keep, 0.0, 0.96);
  half3 fogCol = mix(half3(0.86, 0.90, 0.98), half3(1.0), half(d));
  half3 ember = half3(1.0, 0.78, 0.30);
  float ra = rim * mask * 0.95;
  half3 rgb = fogCol * half(a) + ember * half(ra);
  return half4(rgb, half(clamp(a + ra, 0.0, 1.0)));
}

// MARK: - Luna

// Luna as a shaded little moon: a sphere normal, a few craters (normal-mapped rims and dimples), Lambert
// light from `light` (radians; the hinge swings it on iPhone Duo), a cool rim light and a soft warm core.
// `glow` brightens the lit side a touch (kept for tuning).
// The face (eyes, mouth, cheeks) is drawn on top in SwiftUI, so blinking and moods stay vector-crisp.
[[ stitchable ]] half4 luna(float2 pos, half4 color, float2 size, float light, float glow) {
  float2 c = (pos - size * 0.5) / (min(size.x, size.y) * 0.5);
  float r2 = dot(c, c);
  // Outside the disc: transparent (the soft glow is SwiftUI's shadow, which isn't clipped to the frame).
  if (r2 > 1.0) return half4(0);
  float3 n = float3(c.x, c.y, sqrt(1.0 - r2));

  // Craters: (center, radius). Each pushes the normal outward at its rim and inward in its bowl.
  const float3 craters[5] = { float3(0.42, -0.50, 0.17), float3(-0.55, 0.48, 0.13), float3(0.55, 0.30, 0.09),
                              float3(-0.20, -0.62, 0.08), float3(-0.66, -0.12, 0.07) };
  float shade = 0.0;
  for (int i = 0; i < 5; i++) {
    float2 d = c - craters[i].xy;
    float rr = length(d) / craters[i].z;
    if (rr < 1.35) {
      float2 dir = d / max(length(d), 1e-4);
      float bowl = smoothstep(1.0, 0.0, rr);
      float rim = exp(-pow((rr - 1.0) * 5.0, 2.0));
      n.xy += dir * (rim * 0.35 - bowl * 0.45);
      shade += bowl * 0.10;
    }
  }
  n = normalize(n);
  float3 L = normalize(float3(cos(light), sin(light), 0.85));
  float lambert = max(dot(n, L), 0.0);
  float rim = pow(1.0 - n.z, 3.0);

  half3 albedo = mix(half3(1.0, 0.96, 0.80), half3(0.95, 0.80, 0.42), half(shade * 3.0 + r2 * 0.25));
  half3 col = albedo * half(0.42 + (0.62 + 0.1 * glow) * lambert);
  col += half3(0.55, 0.70, 1.0) * half(rim * 0.35);                          // cool rim light
  col += half3(1.0, 0.95, 0.75) * half(pow(lambert, 18.0) * 0.25);            // soft highlight
  float edge = smoothstep(1.0, 0.96, sqrt(r2));                              // anti-aliased edge
  return half4(col * half(edge), half(edge));
}

// MARK: - Candles: bloom, time machine

// A soft bloom: the layer plus a blurred, brightened copy (12 taps on two rings). Used on the chart when
// you get a candle right; `amount` fades it in and out.
[[ stitchable ]] half4 bloom(float2 pos, SwiftUI::Layer layer, float radius, float amount) {
  half4 base = layer.sample(pos);
  if (amount <= 0.001) return base;
  half4 acc = half4(0);
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 0.5236;
    float r = (i % 2 == 0) ? radius : radius * 0.5;
    acc += layer.sample(pos + float2(cos(a), sin(a)) * r);
  }
  acc /= 12.0;
  half3 glow = acc.rgb * half(1.6);
  return half4(base.rgb + glow * half(amount * 0.55), max(base.a, acc.a * half(amount * 0.6)));
}

// The Chart Time Machine: a chromatic sweep (red/blue split in a band that crosses the chart) plus film
// grain and a faint sepia flicker. `progress` 0 → 1 over the trip forward in time.
[[ stitchable ]] half4 timeWarp(float2 pos, SwiftUI::Layer layer, float2 size, float progress, float t) {
  float band = size.x * 0.28;
  float x0 = progress * (size.x + band * 2.0) - band;
  float k = exp(-pow((pos.x - x0) / (band * 0.5), 2.0));
  float strength = sin(progress * 3.14159);
  float off = 9.0 * k * strength;
  half4 g = layer.sample(pos);
  half r = layer.sample(pos + float2(off, 0)).r;
  half b = layer.sample(pos - float2(off, 0)).b;
  half4 col = half4(r, g.g, b, g.a);
  float grain = (hash21(pos + fract(t * 13.0) * 100.0) - 0.5) * 0.16 * strength;
  half lum = dot(col.rgb, half3(0.3, 0.59, 0.11));
  half3 sepia = half3(lum * 1.07, lum * 0.95, lum * 0.78);
  col.rgb = mix(col.rgb, sepia, half(0.35 * strength * (0.8 + 0.2 * sin(t * 40.0))));
  col.rgb += half(grain) * col.a;
  col.rgb += half3(0.6, 0.8, 1.0) * half(k * strength * 0.18) * col.a;
  return col;
}

// MARK: - Celebrations

// Shockwave on a boss defeat: a ring expands from `center`, pushing pixels outward as it passes.
[[ stitchable ]] float2 shockwave(float2 pos, float2 center, float t, float2 size) {
  float maxR = length(size) * 0.75;
  float radius = t * maxR;
  float2 d = pos - center;
  float dist = length(d);
  float w = 60.0;
  float x = (dist - radius) / w;
  float amt = exp(-x * x * 2.0) * 22.0 * (1.0 - t);
  return pos - (d / max(dist, 1e-3)) * amt;
}

// A shimmer for badges and rare shop items: a bright band sweeps across, plus a holographic rainbow that
// follows the device tilt (CoreMotion). Keeps the item's own alpha.
[[ stitchable ]] half4 shimmer(float2 pos, half4 color, float2 size, float t, float2 tilt, float holo) {
  if (color.a <= 0.001) return color;
  float2 uv = pos / max(size, float2(1.0));
  float s = uv.x + uv.y * 0.6 + tilt.x * 0.5;
  float sweep = fract(t * 0.35) * 2.6 - 0.8;
  float band = exp(-pow((s - sweep) / 0.09, 2.0));
  half3 rainbow = hueRamp(s * 1.3 + tilt.y * 0.8 + t * 0.05);
  half3 rgb = color.rgb + half3(1.0) * half(band * 0.45) * color.a;
  rgb = mix(rgb, rgb * half(0.7) + rainbow * half(0.45) * color.a, half(holo * 0.35));
  return half4(rgb, color.a);
}

// The fold seam on iPhone Duo: a soft shadow in the crease with a thin light line either side. `depth`
// follows the hinge (deep when half open, faint when flat).
[[ stitchable ]] half4 foldSeam(float2 pos, half4 color, float2 size, float depth) {
  float x = (pos.x / max(size.x, 1.0) - 0.5) * 2.0;       // -1 … 1 across the seam
  float shadow = exp(-x * x * 5.0) * depth;
  float lightLine = exp(-pow((abs(x) - 0.62) / 0.08, 2.0)) * depth * 0.35;
  half3 rgb = half3(1.0, 0.98, 0.92) * half(lightLine);
  return half4(rgb, half(shadow * 0.55 + lightLine));
}

// MARK: - GPU particles (MTKView, instanced quads)

// Each particle is computed from its launch values and the time: no per-frame CPU work or buffer writes.
struct Particle {
  float2 origin;   // pt
  float2 vel;      // pt/s
  float4 color;    // straight alpha
  float delay;     // s
  float life;      // s
  float size;      // pt
  float spin;      // rad/s
  float gravity;   // pt/s²
  float shape;     // 0 paper, 1 star, 2 spark (additive glow)
  float sway;      // pt of side-to-side flutter
  float drag;      // 1/s
};

struct ParticleUniforms {
  float2 viewSize; // pt
  float t;         // s since launch
  float pad;
};

struct ParticleOut {
  float4 position [[position]];
  float2 uv;
  float4 color;
  float shape;
};

vertex ParticleOut particleVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                                  const device Particle *ps [[buffer(0)]],
                                  constant ParticleUniforms &u [[buffer(1)]]) {
  Particle p = ps[iid];
  ParticleOut o;
  float tt = u.t - p.delay;
  const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
  float2 corner = corners[vid];
  o.uv = corner;
  o.shape = p.shape;
  if (tt < 0.0 || tt > p.life) { o.position = float4(-4, -4, 0, 1); o.color = float4(0); return o; }

  // Drag-damped flight + gravity + flutter.
  float k = p.drag > 0.0 ? (1.0 - exp(-p.drag * tt)) / p.drag : tt;
  float2 pos = p.origin + p.vel * k + float2(0, 0.5 * p.gravity * tt * tt);
  pos.x += sin(tt * 3.0 + float(iid)) * p.sway;

  float ang = p.spin * tt;
  float flip = p.shape < 0.5 ? abs(cos(tt * (3.0 + fmod(float(iid), 5.0)))) * 0.8 + 0.2 : 1.0; // paper turning over
  float2 q = corner * float2(p.size * 0.5, p.size * 0.5 * (p.shape < 0.5 ? 0.6 * flip : 1.0));
  float2 r = float2(q.x * cos(ang) - q.y * sin(ang), q.x * sin(ang) + q.y * cos(ang));
  float2 world = pos + r;
  float2 ndc = float2(world.x / u.viewSize.x * 2.0 - 1.0, 1.0 - world.y / u.viewSize.y * 2.0);
  o.position = float4(ndc, 0, 1);

  float fadeIn = smoothstep(0.0, 0.06, tt);
  float fadeOut = 1.0 - smoothstep(p.life * 0.65, p.life, tt);
  o.color = float4(p.color.rgb, p.color.a * fadeIn * fadeOut);
  return o;
}

fragment half4 particleFragment(ParticleOut in [[stage_in]]) {
  float2 uv = in.uv;
  float a;
  if (in.shape < 0.5) {
    // Paper: a rounded rectangle.
    float2 d = abs(uv) - float2(0.8, 0.8);
    float sd = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - 0.2;
    a = 1.0 - smoothstep(-0.05, 0.05, sd);
  } else if (in.shape < 1.5) {
    // Star: five points from a polar wave.
    float ang = atan2(uv.y, uv.x);
    float rr = length(uv);
    float edge = 0.55 + 0.4 * pow(abs(cos(ang * 2.5)), 3.0);
    a = 1.0 - smoothstep(edge - 0.08, edge + 0.04, rr);
  } else {
    // Spark: a hot core with a glow. Low alpha = it adds light (premultiplied "additive").
    float rr = length(uv);
    float core = exp(-rr * rr * 10.0);
    float halo = exp(-rr * rr * 2.5) * 0.6;
    float3 rgb = in.color.rgb * (core + halo) + float3(core * 0.6);
    float alpha = in.color.a;
    return half4(half3(rgb * alpha), half(core * alpha * 0.4));
  }
  float alpha = a * in.color.a;
  return half4(half3(in.color.rgb * alpha), half(alpha));
}

// MARK: - Lesson scenes (Moon School cards)

// A little night window with aurora curtains: three ribbons of light in the unit's colors, each a wavy line
// with a sharp lower edge and soft rays fading upward, over a deep sky with a few twinkling stars. Pure ALU,
// three loop passes. `glow` dims a not-started card; `t` comes from the shared SceneClock (a still frame when
// it rests). Drawn small (a 60 pt tile) at ~20 fps, or once as a still frame.
[[ stitchable ]] half4 ribbons(float2 pos, half4 color, float2 size, float t,
                               half4 c1, half4 c2, half4 c3, half4 base, float glow) {
  float2 uv = pos / max(size, float2(1.0));
  float aspect = size.x / max(size.y, 1.0);
  float x = uv.x * aspect;
  half3 col = base.rgb;
  // A touch of horizon light at the bottom.
  col += half3(0.05, 0.06, 0.12) * half(uv.y * uv.y);

  // Stars: one per 11 pt cell at most, brighter near the top, twinkling slowly.
  float2 cell = floor(pos / 11.0);
  float h = hash21(cell);
  float2 f = fract(pos / 11.0) - 0.5 - (float2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5) * 0.6;
  float star = step(0.84, h) * smoothstep(0.11, 0.0, length(f)) * (0.55 + 0.45 * sin(t * 1.7 + h * 40.0)) * (1.0 - uv.y);
  col += half(star * 0.85);

  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    half3 c = i == 0 ? c1.rgb : (i == 1 ? c2.rgb : c3.rgb);
    float y0 = 0.30 + 0.17 * fi + 0.08 * sin(x * 2.4 + t * 0.42 + fi * 2.1) + 0.035 * sin(x * 6.3 - t * 0.77 + fi * 1.3);
    float d = uv.y - y0;
    // Below the line the light ends fast; above it, rays fade up into the sky.
    float curtain = d > 0.0 ? exp(-d * d * 420.0) : exp(d * 5.0);
    float core = exp(-d * d * 2600.0) * 0.55;
    float rays = 0.66 + 0.34 * sin(x * 19.0 + 2.5 * sin(x * 3.7 + t * 0.55) + fi * 5.0);
    float shimmer = 0.78 + 0.22 * sin(t * 1.1 + x * 2.6 + fi * 1.9);
    float a = (curtain * rays + core) * shimmer * glow * (0.9 - 0.18 * fi);
    col += c * half(a);
  }
  float n = fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453);
  col += half((n - 0.5) * 0.014);
  return half4(min(col, half3(1.0)), 1.0);
}
