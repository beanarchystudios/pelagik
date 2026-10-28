precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Rise
 * @default 0.38
 * @range 0, 1
 */
uniform float u_up;

/**
 * @label Drip
 * @default 0.4
 * @range 0, 1
 */
uniform float u_down;

/**
 * @label Eat
 * @default 0.5
 * @range 0, 1
 */
uniform float u_eat;

/**
 * @label Length
 * @default 0.5
 * @range 0, 1
 */
uniform float u_length;

/**
 * @label Tail
 * @default 0.55
 * @range 0, 1
 */
uniform float u_tail;

/**
 * @label Spread
 * @default 0.4
 * @range 0, 1
 */
uniform float u_width;

/**
 * @label Lick
 * @default 0.5
 * @range 0, 1
 */
uniform float u_turb;

/**
 * @label Flicker
 * @default 0.5
 * @range 0, 1
 */
uniform float u_flicker;

/**
 * @label Tilt
 * @default 0
 * @range -90, 90
 */
uniform float u_tilt;

/**
 * @label Seed
 * @default 13
 * @range 0, 100
 */
uniform float u_seed;

/**
 * @label Fringe
 * @default 7
 * @range 0, 30
 */
uniform float u_fringe;

/**
 * @label Grain
 * @default 0.5
 * @range 0, 1
 */
uniform float u_grain;

/**
 * @label Speed
 * @default 0.5
 * @range 0, 1
 */
uniform float u_motion;

/**
 * @label Haze
 * @color
 * @default #4a1fc4
 */
uniform vec3 u_haze;

/**
 * @label Blue
 * @color
 * @default #2f8cff
 */
uniform vec3 u_blue;

/**
 * @label Red
 * @color
 * @default #ff2a5c
 */
uniform vec3 u_red;

/**
 * @label Flame
 * @color
 * @default #ff8a1f
 */
uniform vec3 u_flame;

/**
 * @label Core
 * @color
 * @default #fff0d2
 */
uniform vec3 u_core;

float aspect;
float tm;
float flameL;
float eatD;
float gapD;
vec2 gAx;
vec3 bgCol;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.03 + 5.1) + 0.15 * vnoise(p * 4.1 + 9.7);
}

float hashS(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 back(vec2 p) {
  vec2 uv = vec2(p.x / aspect, 1.0 - p.y);
  return texture2D(u_backdrop, clamp(uv, 0.0, 1.0)).rgb;
}

float inFrame(vec2 p) {
  vec2 uv = vec2(p.x / aspect, p.y);
  return step(0.002, uv.x) * step(uv.x, 0.998) * step(0.002, uv.y) * step(uv.y, 0.998);
}

float cover(vec3 c, vec2 p) {
  return smoothstep(0.08, 0.7, distance(c, bgCol)) * inFrame(p);
}

float art(vec2 p) {
  return cover(back(p), p);
}

float burnN(float q) {
  float n = 0.65 * vnoise(vec2(q * 13.0 + u_seed * 3.17, tm * 0.05 + u_seed))
    + 0.35 * vnoise(vec2(q * 31.0 - u_seed * 1.3, tm * 0.08));
  return clamp((n - 0.5) * 1.8 + 0.5, 0.0, 1.0);
}

float lineCov(vec2 p) {
  vec2 w = gAx * 0.0067;
  return (art(p - 3.0 * w) + art(p - w) + art(p + w) + art(p + 3.0 * w)) * 0.25;
}

float hit(vec2 p) {
  return step(0.2, lineCov(p));
}

vec2 edgeDepth(vec2 B, vec2 dir) {
  float stepE = eatD / 8.0;
  float sf = 1e3;
  float sPrev = 0.0;
  float lastS = 0.0;
  float foundF = 0.0;
  for (int k = 0; k <= 8; k++) {
    float sk = stepE * float(k);
    float h = step(0.5, art(B - dir * sk)) * (1.0 - foundF);
    sf = mix(sf, sk, h);
    sPrev = mix(sPrev, lastS, h);
    foundF = max(foundF, h);
    lastS = sk;
    if (foundF > 0.5) break;
  }
  if (foundF < 0.5) return vec2(0.0);
  float lo = sPrev;
  float hi = min(sf, eatD);
  for (int k = 0; k < 4; k++) {
    float mid = 0.5 * (lo + hi);
    float h = step(0.5, art(B - dir * mid));
    hi = mix(hi, mid, h);
    lo = mix(mid, lo, h);
  }
  float own = foundF * (1.0 - smoothstep(0.35 * eatD, 0.7 * eatD, hi));
  return vec2(hi * own, own);
}

vec2 burnAt(vec2 P, vec2 dlt, vec2 dir, vec2 ax, float side, out vec3 warp) {
  float s0 = dot(P, dir);
  float q = dot(P, ax);

  float fl = vnoise(vec2(q * 11.0 + side * 17.0 + u_seed, tm * 1.7 + side * 3.0));
  float lk = flameL * (1.0 - 0.45 * u_flicker + 0.9 * u_flicker * fl);
  float tailS = 0.06 + 0.5 * u_tail;
  float tongue = 1.7 * lk;
  float reach = tongue + 1.5 * tailS;

  float wn = fbm(vec2(q * 5.0 + side * 3.0, s0 * 3.2 - tm * 2.4)) - 0.5;
  float bend = wn * u_turb * 0.9;

  float thr = side > 0.0 ? 1.0 - u_up : u_down;
  float n = burnN(q);
  float burn = side > 0.0 ? smoothstep(thr - 0.1, thr + 0.1, n) : smoothstep(thr + 0.1, thr - 0.1, n);
  float lit = smoothstep(0.15, 0.7, burn);

  float here = hit(P);
  float zone = 0.0;
  float edgeA = 0.0;
  if (here > 0.5) {
    float stepF = (eatD + gapD) / 14.0;
    float farIn = 0.0;
    float beyond = 1e3;
    float firstClear = 1e3;
    for (int k = 1; k <= 14; k++) {
      float sk = stepF * float(k);
      float h = hit(P + dir * sk);
      float inD = step(sk, eatD);
      firstClear = min(firstClear, mix(sk, 1e3, h));
      farIn = max(farIn, mix(-1.0, sk, h * inD));
      beyond = min(beyond, mix(1e3, sk, h * (1.0 - inD)));

      if (h > 0.5 && (inD < 0.5 || firstClear < 1e3)) break;
    }
    if (farIn + 0.5 * stepF <= firstClear) {
      float lo = farIn;
      float hi = lo + stepF;
      for (int k = 0; k < 4; k++) {
        float mid = 0.5 * (lo + hi);
        float h = hit(P + dir * mid);
        lo = mix(lo, mid, h);
        hi = mix(mid, hi, h);
      }
      edgeA = 0.5 * (lo + hi);
      zone = smoothstep(0.8 * gapD, gapD, beyond - edgeA);
    }
  }

  vec2 EB = P;
  float hi2 = 0.0;
  float outer = 0.0;
  if (zone <= 0.5) {
    if (zone <= 0.0 && (here > 0.5 || lit <= 0.0)) { warp = back(P + dlt); return vec2(0.0); }

    float step1 = tongue / 16.0;
    float step2 = step1 * ceil((reach - tongue) / 8.0 / step1);
    float d0 = mod(s0, step1);
    float dHit = 1e3;
    float dPrev = 0.0;
    float lastD = 0.0;
    float found = 0.0;
    for (int k = 0; k < 24; k++) {
      float fk = float(k);
      float d = k < 16 ? d0 + step1 * fk : d0 + step1 * 16.0 + step2 * (fk - 16.0);

      float h = hit(P - dir * d);
      if (k < 16) h = max(h, hit(P - dir * (d + 0.5 * step1)));
      dHit = mix(dHit, d, h);
      dPrev = mix(dPrev, lastD, h);
      found = h;
      lastD = d;
      if (h > 0.5) break;
    }
    if (found < 0.5 && zone <= 0.0) { warp = back(P + dlt); return vec2(0.0); }
    float lo2 = dPrev;
    hi2 = min(dHit, reach);
    for (int k = 0; k < 5; k++) {
      float mid = 0.5 * (lo2 + hi2);
      float h = hit(P - dir * mid);
      hi2 = mix(hi2, mid, h);
      lo2 = mix(mid, lo2, h);
    }
    EB = P - dir * hi2;
    if (here < 0.5) {

      if (hit(EB + dir * 0.006) > 0.5) { warp = back(P + dlt); return vec2(0.0); }

      float blk = 0.0;

      for (int k = 1; k <= 9; k++) {
        float d = gapD * float(k) / 10.0;
        float w = smoothstep(hi2 - 0.004, hi2 + 0.004, d) * (1.0 - smoothstep(0.8 * gapD, gapD, d));
        if (w > 0.0) blk = max(blk, lineCov(EB + dir * d) * w);
        if (blk >= 0.25) { warp = back(P + dlt); return vec2(0.0); }
      }
      outer = 1.0 - smoothstep(0.03, 0.25, blk);
    }
  }

  vec2 B = zone > 0.5 ? P + dir * edgeA : EB;
  float y0 = zone > 0.5 ? -edgeA : hi2;

  vec2 ed = (edgeDepth(B - ax * 0.003, dir) + edgeDepth(B, dir) + edgeDepth(B + ax * 0.003, dir)) / 3.0;
  float hi4 = ed.x;

  float y = y0 + hi4;
  vec2 E = B - dir * hi4;

  float de = max(eatD * lit, 1e-4);
  float rowD = 0.2 * de;
  float sqL = de - rowD;
  float u = max(y + de, 0.0);

  float ex = exp(-2.0 * u / sqL);
  float yp = y < -de ? y : -de + sqL * (1.0 - ex) / (1.0 + ex);
  float m = smoothstep(0.0, de, u);

  vec2 R = E + dir * yp + ax * (bend * max(y, 0.0));

  float out1 = max(y, 0.0);

  vec2 Rl = (zone > 0.5 ? mix(P, R, lit) : R) + dlt;
  R += dlt;
  float r = (0.001 + 0.009 * m * m) * mix(0.3, 1.0, lit) + u_width * 0.25 * out1;

  float alongK = mix(1.5, 0.6, smoothstep(0.0, 0.03, out1));
  vec3 bc = vec3(0.0);
  float c = 0.0;

  for (int i = 0; i < 16; i++) {
    float fi = (float(i) + 0.5) / 16.0;
    float a = float(i) * 2.3999632 + 0.6;
    vec2 pt = Rl + (ax * cos(a) + dir * (alongK * sin(a))) * (sqrt(fi) * r);
    vec3 b = back(pt);
    bc += b;
    c += cover(b, pt);
  }
  bc /= 16.0;
  c /= 16.0;

  float rw = 0.012 + 3.0 * r;
  float cw = (art(R - ax * rw) + 2.0 * art(R - ax * rw * 0.5) + 2.0 * art(R)
    + 2.0 * art(R + ax * rw * 0.5) + art(R + ax * rw)) / 8.0;

  float span = lk * (0.2 + 0.8 * sqrt(c));
  float x = 0.3 * m + out1 / (span * max(burn, 0.05));
  float fall = max(exp(-0.7 * x * x), 0.3 * u_tail * burn * exp(-out1 / tailS));

  float body = mix(1.0, smoothstep(0.1, 0.3, c), step(out1, 0.0));

  float fadeIn = mix(smoothstep(0.0, 0.025, out1), 1.0, ed.y);
  float outerS = outer * fadeIn;
  float heat = max(zone, outerS) * max(c, 0.3 * cw * smoothstep(0.0, 0.03, out1)) * body * fall * smoothstep(0.0, 0.25, lit);
  float eaten = zone * m * lit;

  warp = mix(back(P + dlt), bc, step(0.5, zone));
  return vec2(heat, eaten);
}

vec3 thermal(float h, vec3 base) {
  vec3 c = base;
  c = mix(c, u_haze, 0.85 * smoothstep(0.01, 0.16, h));
  c = mix(c, u_blue, smoothstep(0.11, 0.29, h));
  c = mix(c, mix(u_blue, vec3(1.0), 0.35), smoothstep(0.26, 0.38, h) * 0.6);
  c = mix(c, u_red, smoothstep(0.34, 0.47, h));
  c = mix(c, u_flame, smoothstep(0.42, 0.6, h));
  c = mix(c, u_core, smoothstep(0.6, 0.8, h));
  return mix(c, vec3(1.0), smoothstep(0.84, 0.98, h));
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  aspect = u_resolution.x / u_resolution.y;
  tm = u_time * u_motion * 1.4;
  flameL = 0.03 + 0.32 * u_length;
  vec2 P = vec2(uv.x * aspect, 1.0 - uv.y);
  float px = 1.0 / u_resolution.y;

  bgCol = texture2D(u_backdrop, vec2(0.004)).rgb;
  float bgL = dot(bgCol, vec3(0.299, 0.587, 0.114));

  float gseed = mod(floor(u_time * 12.0), 64.0) * step(0.001, u_motion);
  eatD = 0.01 + 0.1 * u_eat;
  gapD = 0.045 + 0.5 * eatD;

  float ang = radians(u_tilt);
  vec2 up = vec2(-sin(ang), -cos(ang));
  vec2 ax = vec2(-up.y, up.x);
  gAx = ax;

  vec3 wu;
  vec3 wd;

  vec2 fq = floor(gl_FragCoord.xy * 0.5) * 2.0 + 0.5;
  vec2 Pq = vec2(fq.x / u_resolution.y, 1.0 - fq.y / u_resolution.y);
  vec2 dlt = P - Pq;
  vec2 bu = burnAt(Pq, dlt, up, ax, 1.0, wu);
  vec2 bd = burnAt(Pq, dlt, -up, ax, -1.0, wd);
  float h = max(bu.x, bd.x);
  float eaten = max(bu.y, bd.y);
  float s = dot(P, bu.x > bd.x ? up : -up);
  float q = dot(P, ax);

  float lick = fbm(vec2(q * 14.0, s * 7.0 - tm * 5.0)) - 0.5;
  h *= 1.0 + u_turb * 1.1 * lick * (1.0 - smoothstep(0.6, 0.95, h));

  float streak = vnoise(vec2(q * 240.0, s * 1.6 - tm * 1.2));
  h *= mix(1.0, 0.6 + 0.8 * streak, u_grain * (1.0 - smoothstep(0.2, 0.5, h)));
  h = clamp(h, 0.0, 1.0);

  vec3 warp = bu.y >= bd.y ? wu : wd;
  float aw = smoothstep(0.08, 0.7, distance(warp, bgCol));

  float aP = art(P);
  vec3 col = thermal(h, mix(back(P), bgCol, clamp(aP + eaten, 0.0, 1.0)));

  float jit = 1.0 + 0.2 * u_flicker * (vnoise(vec2(tm * 3.0, 1.7)) - 0.5);
  vec2 fo = (ax * 0.35 + up) * u_fringe * px * jit;
  float keep = 1.0 - smoothstep(0.0, 0.3, eaten);

  float a0 = aw * (1.0 - eaten) * smoothstep(0.0, 0.3, aP + eaten);

  float ab = (art(P + fo * 0.8) + art(P + fo) + art(P + fo * 1.2)) / 3.0 * keep;
  float ar = (art(P + fo * 0.35) + art(P + fo * 0.5) + art(P + fo * 0.65)) / 3.0 * keep;
  col = mix(col, mix(u_blue, vec3(1.0), 0.15), clamp(ab - a0, 0.0, 1.0));
  col = mix(col, mix(u_red, u_flame, 0.3), clamp(ar - a0, 0.0, 1.0));
  col = mix(col, warp, a0);

  float g = hash21(gl_FragCoord.xy * 0.91 + gseed * 5.7 + 31.0) - 0.5;
  col += g * u_grain * (0.04 + 0.08 * smoothstep(0.02, 0.4, h) * (1.0 - a0));

  col *= 1.0 + (vnoise(uv * 3.0) + vnoise(uv * 9.0 + 4.1) - 1.0) * 0.05 * u_grain;
  vec2 cell = floor(gl_FragCoord.xy / 3.0);
  float speck = step(0.9985, hashS(vec2(hash21(cell), hash21(cell.yx + 3.1)) * 97.0))
    * step(0.4, vnoise(uv * 5.0 + 2.3));
  vec3 speckCol = bgL < 0.5 ? col + vec3(0.3) : col * 0.35;
  col = mix(col, speckCol, speck * u_grain * (1.0 - a0));

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
