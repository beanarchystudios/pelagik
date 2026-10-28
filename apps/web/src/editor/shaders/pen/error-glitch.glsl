precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Glitch
 * @default 0.5
 * @range 0, 1
 */
uniform float u_glitch;

/**
 * @label Shift
 * @default 0.5
 * @range 0, 1
 */
uniform float u_shift;

/**
 * @label Smudge
 * @default 0.55
 * @range 0, 1
 */
uniform float u_smudge;

/**
 * @label Smudge Length
 * @default 0.4
 * @range 0.05, 1
 */
uniform float u_smudgeLength;

/**
 * @label Lines
 * @default 0.6
 * @range 0, 1
 */
uniform float u_lines;

/**
 * @label Blocks
 * @default 28
 * @range 8, 120
 */
uniform float u_blocks;

/**
 * @label Flow
 * @default 1
 * @range 0, 3
 */
uniform float u_flow;

/**
 * @label Static
 * @default 0.5
 * @range 0, 1
 */
uniform float u_static;

/**
 * @label Glow
 * @default 0.45
 * @range 0, 1.5
 */
uniform float u_glow;

/**
 * @label Speed
 * @default 1
 * @range 0, 3
 */
uniform float u_speed;

/**
 * @label Seed
 * @default 0
 * @range 0, 100
 */
uniform float u_seed;

/**
 * @label Phosphor
 * @color
 * @default #6fcf4f
 */
uniform vec3 u_phosphor;

float hash21(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float hash31(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.zyx + 31.32);
  return fract((p.x + p.y) * p.z);
}

float vnoise1(float x, float k) {
  float i = floor(x);
  float f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(hash21(vec2(i, k)), hash21(vec2(i + 1.0, k)), f);
}

vec3 back(vec2 px) {
  vec2 uv = px / u_resolution;
  float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
  return texture2D(u_backdrop, clamp(uv, 0.0, 1.0)).rgb * inside;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float zones(vec2 uv, float tf, float seed) {
  float z = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float T = 3.0 + 2.5 * hash21(vec2(fi, seed + 1.0));
    float ph = tf / T + hash21(vec2(fi, seed + 2.0)) + fi * 0.37;
    float id = floor(ph);
    float a = fract(ph);
    float h1 = hash31(vec3(fi, id, seed + 3.0));
    float h2 = hash31(vec3(fi, id, seed + 4.0));
    float h3 = hash31(vec3(fi, id, seed + 5.0));
    float a2 = h3 < 0.5 ? a : 1.0 - a;
    vec2 c = vec2(mix(-0.2, 1.2, a2), mix(0.25, 0.75, h1) + (h2 - 0.5) * 0.12 * a);
    vec2 r = vec2(0.16 + 0.18 * h2, 0.06 + 0.12 * h1);
    vec2 d = (uv - c) / r;
    z += sin(3.14159 * a) * exp(-dot(d, d));
  }
  return z;
}

void main() {
  vec2 fc = gl_FragCoord.xy;
  float S = u_resolution.y / 1080.0;
  float seed = u_seed * 17.31;
  float t = u_time * u_speed;
  float tf = t * u_flow;

  vec2 bc = floor(fc * 0.5) * 2.0 + 1.0;
  vec2 buv = bc / u_resolution;

  float Z = (0.22 + 1.1 * zones(buv, tf, seed)) * u_glitch * 2.0;
  float Zc = clamp(Z, 0.0, 1.5);

  float unit = 2.0 * max(1.0, floor(S + 0.5));
  float r2 = floor(bc.y / unit);
  float grp = floor(r2 / 5.0);
  float k = 1.0 + floor(hash21(vec2(grp, seed + 9.0)) * 5.0);
  float strip = grp * 8.0 + floor(mod(r2, 5.0) / k);
  float sh = hash21(vec2(strip, seed + 10.0));

  float hs = hash31(vec3(strip, floor(t * 0.5 + sh * 2.0), seed + 13.0)) * 2.0 - 1.0;
  float baseOff = sign(hs) * pow(abs(hs), 1.6);
  float glide = (vnoise1(t * 0.9 + sh * 40.0, strip + seed) - 0.5) * 2.0;
  float jump = (hash31(vec3(strip, floor(t * 5.0 + sh), seed + 11.0)) - 0.5) * 2.0;
  float off = (baseOff * 18.0 * (0.6 + 0.4 * min(Zc, 1.0)) + (0.55 * glide + 0.45 * jump) * min(Zc, 1.2) * 14.0) * u_shift * 2.0 * S;
  off = floor(off * 0.5 + 0.5) * 2.0;
  vec2 q = vec2(fc.x + off, fc.y);

  float B = max(4.0, 2.0 * floor(u_blocks * S * 0.5 + 0.5));
  float brow = floor(bc.y / B);
  float bwk = 1.0 + floor(hash21(vec2(brow, seed + 20.0)) * 4.0);
  float bw = B * bwk;
  float boff = floor(hash21(vec2(brow, seed + 21.0)) * bwk) * B;
  float bcol = floor((bc.x + boff) / bw);
  vec2 bOrigin = vec2(bcol * bw - boff, brow * B);
  vec2 bCentre = bOrigin + vec2(bw, B) * 0.5;
  float Zb = clamp((0.22 + 1.1 * zones(bCentre / u_resolution, tf, seed)) * u_glitch * 2.0, 0.0, 1.5);
  float bEp = floor(t * 3.0);
  float bOn = step(1.0 - 0.22 * smoothstep(0.45, 1.3, Zb), hash31(vec3(bcol, brow, bEp + seed + 22.0)));
  float bKind = hash31(vec3(bcol, brow, bEp + seed + 23.0));
  float bJump = floor((hash31(vec3(bcol, brow, bEp + seed + 24.0)) - 0.5) * 2.0 * B * u_shift * 1.5 * 0.5) * 2.0;
  float cs = max(2.0, 2.0 * floor(B * 0.125 + 0.5));
  vec2 cellC = (floor(bc / cs) + 0.5) * cs;
  vec2 qCoarse = cellC + vec2(off, 0.0);
  float isJump = bOn * step(bKind, 0.45);
  float isCoarse = bOn * step(0.45, bKind) * step(bKind, 0.75);
  float isDark = bOn * step(0.75, bKind);
  q.x += bJump * isJump;
  q = mix(q, qCoarse, isCoarse);

  vec3 col = back(q);

  float sDir = hash31(vec3(strip, floor(t * 0.6 + sh * 4.0), seed + 32.0)) < 0.5 ? 1.0 : -1.0;
  float sl = u_smudgeLength * 110.0 * S * (0.15 + 0.85 * pow(hash31(vec3(strip, floor(t * 0.6 + sh * 4.0), seed + 30.0)), 1.5));
  float hsm = hash31(vec3(strip, floor(t * 1.2 + sh), seed + 31.0));
  float sAmt = u_smudge * step(0.45, hsm) * (0.3 + 0.7 * hsm) * (0.6 + 0.4 * min(Zc, 1.0));
  vec3 smear = vec3(0.0);
  float sw = 0.0;
  for (int i = 0; i < 20; i++) {
    float f = (float(i) + 0.5) / 20.0;
    float w = exp(-2.2 * f);
    smear += back(q - vec2(sDir * f * sl, 0.0)) * w;
    sw += w;
  }
  smear /= sw;
  col = mix(col, smear * 1.1, clamp(sAmt * 0.8, 0.0, 1.0));

  float bandG = floor(bc.y / (40.0 * S));
  float bandH = (8.0 + 2.0 * floor(hash21(vec2(bandG, seed + 70.0)) * 14.0)) * S;
  float band = floor(bc.y / bandH) + floor(bandH) * 97.0;
  float bPh = t * (0.2 + 0.3 * hash21(vec2(band, seed + 71.0))) + hash21(vec2(band, seed + 72.0));
  float bAge = fract(bPh);
  float bFire = step(1.0 - 0.28 * u_smudge * (0.6 + 0.6 * min(Zc, 1.0)), hash31(vec3(band, floor(bPh), seed + 73.0)));
  float bEnv = bFire * smoothstep(0.0, 0.06, bAge) * (1.0 - bAge);
  float bDir = hash31(vec3(band, floor(bPh), seed + 74.0)) < 0.5 ? 1.0 : -1.0;
  float bLen = u_smudgeLength * u_resolution.x * 0.4 * (0.3 + 0.7 * hash31(vec3(band, floor(bPh), seed + 75.0))) * (0.5 + bAge);
  vec3 bSm = vec3(0.0);
  float bw0 = 0.0;
  for (int i = 0; i < 20; i++) {
    float f = (float(i) + 0.5) / 20.0;
    float w = exp(-2.5 * f);
    bSm += back(q - vec2(bDir * f * bLen, 0.0)) * w;
    bw0 += w;
  }
  bSm /= bw0;
  col = mix(col, max(col * 0.75, bSm * 1.6), bEnv * 0.85);

  float scr = step(1.0 - 0.3 * min(Zc, 1.0), hash31(vec3(strip, floor(t * 0.9 + sh * 5.0), seed + 40.0)));
  float segLen = (14.0 + 50.0 * sh) * S;
  float seg = step(0.5, vnoise1(bc.x / segLen + t * 0.6 * (sh - 0.5), strip * 3.1 + seed));
  col *= 1.0 - 0.6 * scr * seg;
  col *= 1.0 - 0.65 * isDark;

  col *= 0.78 + 0.27 * vnoise1(t * 0.8 + sh * 20.0, strip * 1.7 + seed + 41.0);

  col = mix(col, col * col * (3.0 - 2.0 * col), 0.6);

  float row = floor(bc.y / (2.0 * unit));
  float rPh = t * (0.22 + 0.3 * hash21(vec2(row, seed + 50.0))) + hash21(vec2(row, seed + 51.0));
  float rEp = floor(rPh);
  float age = fract(rPh);
  float fires = step(1.0 - u_lines * 0.4 * (0.6 + 0.6 * min(Zc, 1.0)), hash31(vec3(row, rEp, seed + 52.0)));
  float env = fires * smoothstep(0.0, 0.04, age) * (1.0 - age) * (1.0 - age);
  float dir = hash31(vec3(row, rEp, seed + 53.0)) < 0.5 ? 1.0 : -1.0;
  float len = u_smudgeLength * 0.9 * u_resolution.x * (0.25 + 0.75 * hash31(vec3(row, rEp, seed + 54.0))) * (0.45 + 0.9 * age);
  vec3 line = vec3(0.0);
  for (int i = 0; i < 28; i++) {
    float f = (float(i) + 1.0) / 28.0;
    float w = (1.0 - f) * (1.0 - f);
    line = max(line, back(vec2(q.x - dir * f * len, (row + 0.5) * 2.0 * unit)) * w);
  }
  float dash = step(0.18 + 0.5 * age, hash21(vec2(floor(bc.x / (6.0 * S * (1.0 + floor(age * 4.0)))), row + rEp * 13.0 + seed)));
  line *= env * mix(1.0, dash, 0.75);
  col = max(col, line);

  float pw = 6.0 + floor(hash21(vec2(floor(bc.y / (24.0 * S)), seed + 60.0)) * 14.0);
  vec2 pcell = floor(bc / (vec2(pw, 4.0) * 6.0 * S));
  float pA = hash31(vec3(pcell, floor(t * 0.3) + seed + 61.0));
  float dens = smoothstep(0.3, 0.9, hash21(floor(bc / (vec2(240.0, 90.0) * S)) + seed + 62.0));
  vec3 grey = vec3(luma(u_phosphor)) * 0.7;
  vec3 stat = mix(u_phosphor, grey, 0.8) * step(0.95 - 0.07 * dens, pA) * (0.3 + 0.7 * hash21(pcell + seed)) * 0.05;
  vec2 gcell = floor(bc / (vec2(3.0, 1.0) * 10.0 * S));
  float gA = hash31(vec3(gcell, floor(t * 0.8 + hash21(gcell) * 4.0) + seed + 63.0));
  stat += u_phosphor * step(0.9975, gA) * 0.22;

  float dRow = floor(bc.y / (2.0 * unit));
  float dPh = t * 0.35 * (0.5 + hash21(vec2(dRow, seed + 65.0))) + hash21(vec2(dRow, seed + 66.0));
  float dEp = floor(dPh);
  float dAge = fract(dPh);
  float dOn = step(0.975, hash31(vec3(dRow, dEp, seed + 67.0)));
  float dX0 = hash31(vec3(dRow, dEp, seed + 68.0));
  float dLen = 0.06 + 0.22 * hash31(vec3(dRow, dEp, seed + 69.0));
  float dU = (buv.x - dX0) / dLen;
  float dIn = step(0.0, dU) * step(dU, 1.0);
  float dHead = smoothstep(0.0, 0.03, dU) * (1.0 - smoothstep(0.12, 0.3, dU));
  float dTail = (1.0 - dU) * step(0.35, hash21(vec2(floor(bc.x / (4.0 * S)), dRow + dEp)));
  stat += (u_phosphor * 0.55 * dHead + grey * 0.12 * dTail) * dIn * dOn * (1.0 - dAge);

  stat *= u_static * 2.0;
  col += stat * (1.0 - clamp(luma(col) * 3.0, 0.0, 1.0));

  vec3 glow = vec3(0.0);
  float gw0 = 0.0;
  for (int i = 0; i < 24; i++) {
    float fi = float(i) + 0.5;
    float a = fi * 2.39996;
    float r = sqrt(fi / 24.0) * 36.0 * S;
    float w = exp(-2.0 * fi / 24.0);
    glow += back(fc + vec2(cos(a) * 1.8, sin(a)) * r) * w;
    gw0 += w;
  }
  glow /= gw0;
  vec3 haze = vec3(0.0);
  float hw = 0.0;
  for (int i = 0; i < 16; i++) {
    float f = (float(i) + 0.5) / 16.0;
    float w = exp(-3.0 * f);
    float d = f * 160.0 * S;
    haze += (back(fc + vec2(d, 0.0)) + back(fc - vec2(d, 0.0))) * w;
    hw += 2.0 * w;
  }
  haze /= hw;
  vec3 halo = clamp((glow * 0.35 + haze * 0.35) * u_glow, 0.0, 1.0);
  col = 1.0 - (1.0 - col) * (1.0 - halo);

  vec2 uv = fc / u_resolution;
  col *= 1.0 - 0.2 * pow(length((uv - 0.5) * vec2(1.0, 0.8)) * 1.3, 2.5);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
