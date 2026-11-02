#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// One soft, slowly drifting aurora field. Three colored light blobs on a base color, blended with
// smooth falloff and a faint grain so gradients never band. Pure ALU: no textures, no branches,
// a handful of sin/exp per pixel — cheap enough to run as one full-screen layer at 30 fps.
[[ stitchable ]] half4 aurora(float2 pos, half4 color, float2 size, float t,
                              half4 c1, half4 c2, half4 c3, half4 base, float strength) {
  float2 uv = pos / max(size, float2(1.0));
  float aspect = size.x / max(size.y, 1.0);
  float2 p = float2(uv.x * aspect, uv.y);

  float2 a = float2(0.25 * aspect + 0.18 * sin(t * 0.11), 0.22 + 0.10 * cos(t * 0.13));
  float2 b = float2(0.80 * aspect + 0.15 * cos(t * 0.09), 0.38 + 0.12 * sin(t * 0.07 + 1.3));
  float2 c = float2(0.50 * aspect + 0.22 * sin(t * 0.05 + 2.1), 0.85 + 0.08 * cos(t * 0.10));

  // Ribbon warp: makes the blobs feel like light curtains, not circles.
  float warp = 0.06 * sin(p.x * 5.0 + t * 0.35) + 0.04 * sin(p.y * 7.0 - t * 0.27);
  p.y += warp;

  float wa = exp(-dot(p - a, p - a) * 5.5);
  float wb = exp(-dot(p - b, p - b) * 4.5);
  float wc = exp(-dot(p - c, p - c) * 3.8);

  half3 col = base.rgb;
  col = mix(col, c1.rgb, half(wa * strength));
  col = mix(col, c2.rgb, half(wb * strength));
  col = mix(col, c3.rgb, half(wc * strength));

  // Grain (hash), ±0.6% — kills banding on wide gradients.
  float n = fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453);
  col += half((n - 0.5) * 0.012);
  return half4(col, 1.0);
}
