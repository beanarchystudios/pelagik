precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Dot Size
 * @default 8
 * @range 3, 30
 */
uniform float u_cell;

/**
 * @label Dot Gap
 * @default 0.35
 * @range 0, 0.8
 */
uniform float u_gap;

/**
 * @label Roundness
 * @default 0.35
 * @range 0, 1
 */
uniform float u_round;

/**
 * @label Defocus
 * @default 5
 * @range 0, 20
 */
uniform float u_defocus;

/**
 * @label Glow
 * @default 0.8
 * @range 0, 2
 */
uniform float u_glow;

/**
 * @label Fringe
 * @default 1
 * @range 0, 8
 */
uniform float u_fringe;

/**
 * @label Flicker
 * @default 0.5
 * @range 0, 1
 */
uniform float u_flicker;

/**
 * @label Glass
 * @default 0.5
 * @range 0, 1
 */
uniform float u_glass;

/**
 * @label Signal
 * @default 0.4
 * @range 0, 1
 */
uniform float u_signal;

/**
 * @label Brightness
 * @default 1.3
 * @range 0.5, 3
 */
uniform float u_bright;

/**
 * @label Screen
 * @color
 * @default #03111d
 */
uniform vec3 u_screen;

float hash11(float x) {
  return fract(sin(x * 127.1) * 43758.5453);
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 bulge(vec2 uv) {
  vec2 c = uv - 0.5;
  return 0.5 + c * (1.0 - 0.06 * u_glass * dot(c, c) * 4.0);
}

float lineShift(float y, float t) {
  float wob = sin(y * 38.0 + t * 5.0) * 0.8 + sin(y * 6.0 - t * 1.9) * 1.6;
  float seg = floor(t * 1.3);
  float on = step(0.8, hash11(seg));
  float gy = hash11(seg + 3.1);
  float gh = 0.02 + 0.07 * hash11(seg + 7.7);
  float inBand = smoothstep(gy - gh, gy - gh + 0.01, y) - smoothstep(gy + gh - 0.01, gy + gh, y);
  float tear = on * inBand * (hash11(seg + 1.3) - 0.5) * 70.0 * (0.6 + 0.4 * sin(t * 37.0));
  return (wob * 1.5 + tear) * u_signal;
}

vec3 tap(vec2 px, float fr) {
  vec2 uv = bulge(px / u_resolution);
  vec2 o = vec2(fr, 0.0) / u_resolution;
  return vec3(texture2D(u_backdrop, uv + o).r,
              texture2D(u_backdrop, uv).g,
              texture2D(u_backdrop, uv - o).b);
}

float dotAt(vec2 l) {

  float hs = 0.5 - u_gap * 0.5;
  float rad = clamp(u_round, 0.0, 1.0) * hs;
  vec2 q = abs(l) - (hs - rad);
  float dd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
  return 1.0 - smoothstep(-0.06, 0.08, dd);
}

void main() {
  vec2 px = gl_FragCoord.xy;
  vec2 uv = px / u_resolution;
  float t = u_time;

  float cs = max(u_cell, 2.0);
  vec2 cid = floor(px / cs);
  vec2 cc = (cid + 0.5) * cs;
  vec2 local = (px - cc) / cs;

  vec2 v = uv - 0.5;
  vec2 gs = u_glass * 0.4 * (v * 2.0 + vec2(0.3, 0.15));
  vec3 dotMask = vec3(dotAt(local - gs), dotAt(local), dotAt(local + gs));

  float slipSeg = floor(t * 3.0);
  float slip = step(0.93, hash11(slipSeg + 11.0)) * u_signal * cs * 1.5 * hash11(slipSeg + 5.0);
  vec2 sig = vec2(lineShift(cc.y / u_resolution.y, t), slip);
  vec2 sigPx = vec2(lineShift(uv.y, t), slip);

  float rDef = u_defocus * (1.0 + 0.08 * u_flicker * sin(t * 1.7));
  vec3 sharp = vec3(0.0);
  float wsum = 0.0;
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float r = sqrt((fi + 0.5) / 16.0) * rDef;
    float a = fi * 2.39996;
    float w = 1.0 - 0.5 * (fi / 16.0);
    sharp += tap(cc + sig + vec2(cos(a), sin(a)) * r, u_fringe) * w;
    wsum += w;
  }
  sharp /= wsum;

  sharp += tap(cc + sig - vec2(cs * 2.2, 0.0), u_fringe) * 0.14 * u_signal;

  vec3 bloom = vec3(0.0);
  float rGlow = cs * 2.5 + u_defocus * 3.0;

  float spin = 6.2831853 * fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
  for (int i = 0; i < 32; i++) {
    float fi = float(i);
    float r = sqrt((fi + 0.5) / 32.0) * rGlow;
    float a = fi * 2.39996 + spin;
    vec3 c = tap(px + sigPx + vec2(cos(a), sin(a)) * r, u_fringe);
    bloom += c * c;
  }
  bloom /= 32.0;

  float band = fract(uv.y + t * 0.08);
  float roll = exp(-pow((band - 0.5) / 0.06, 2.0));
  float flick = 1.0 + u_flicker * (0.05 * (hash11(floor(t * 24.0)) - 0.5) + 0.12 * roll);

  float fr = floor(t * 24.0);
  float sn = hash21(cid + vec2(fr * 17.0, fr * 31.0));
  flick *= 1.0 + (sn - 0.5) * 0.25 * u_signal;
  vec3 snow = vec3(step(0.996, sn) * 0.18 * u_signal);

  vec3 col = u_screen * (0.7 + 0.5 * dotMask) + snow * dotMask;
  col += sharp * dotMask * u_bright * flick;

  col += sharp * (1.0 - dotMask) * 0.2 * u_bright;
  col += bloom * u_glow * 0.9 * flick;

  col *= 1.0 - 0.35 * dot(v, v) * 2.0;

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 1.5 * over);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
