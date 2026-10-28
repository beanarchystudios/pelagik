precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Angle
 * @default 57
 * @range 0, 180
 */
uniform float u_angle;

/**
 * @label Speed
 * @default 0.4
 * @range -1, 1
 */
uniform float u_speed;

/**
 * @label Core
 * @default 0.15
 * @range -1, 1
 */
uniform float u_core;

/**
 * @label Leak
 * @default 0.8
 * @range 0, 1
 */
uniform float u_leak;

/**
 * @label Reach
 * @default 0.5
 * @range 0, 1
 */
uniform float u_reach;

/**
 * @label Position
 * @default 0.2
 * @range -1, 1
 */
uniform float u_position;

/**
 * @label Cover
 * @default 0.8
 * @range 0, 1
 */
uniform float u_cover;

/**
 * @label Cover Size
 * @default 1
 * @range 0.5, 3
 */
uniform float u_coverSize;

/**
 * @label Bokeh
 * @default 0.5
 * @range 0, 1
 */
uniform float u_bokeh;

/**
 * @label Flare
 * @default 0.6
 * @range 0, 1
 */
uniform float u_flare;

float hash21(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 w = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

float layer(float s, float u, float fs, float len, float vel, float t, float seed) {
  return vnoise(vec2(s * fs + seed * 31.7, (u + vel * t) / len + seed * 7.3));
}

float sdHex(vec2 q, float r) {
  vec3 kh = vec3(-0.866025404, 0.5, 0.577350269);
  q = abs(q);
  q -= 2.0 * min(dot(kh.xy, q), 0.0) * kh.xy;
  q -= vec2(clamp(q.x, -kh.z * r, kh.z * r), r);
  return length(q) * sign(q.y);
}

float ghostShape(vec2 q, float r, float hex, float px) {
  float dd = mix(length(q) - r, sdHex(q, r), hex);
  float soft = 0.1 * r + 1.5 * px;
  float m = 1.0 - smoothstep(-soft, soft * 0.4, dd);
  float rim = smoothstep(-0.4 * r, 0.0, dd) * m;
  return m * (0.55 + 0.45 * rim);
}

vec3 ghost(vec2 q, float r, float hex, float px) {

  if (length(q) > 1.2 * r * 1.025 + px) return vec3(0.0);
  return vec3(ghostShape(q, r * 1.025, hex, px), ghostShape(q, r, hex, px), ghostShape(q, r * 0.975, hex, px));
}

vec3 warmRamp(float h) {
  vec3 c = vec3(0.050, 0.070, 0.220);
  c = mix(c, vec3(0.120, 0.220, 0.600), smoothstep(0.00, 0.16, h));
  c = mix(c, vec3(0.200, 0.360, 0.740), smoothstep(0.10, 0.28, h));
  c = mix(c, vec3(0.470, 0.360, 0.740), smoothstep(0.22, 0.42, h));
  c = mix(c, vec3(0.800, 0.400, 0.620), smoothstep(0.34, 0.54, h));
  c = mix(c, vec3(0.920, 0.330, 0.300), smoothstep(0.46, 0.64, h));
  c = mix(c, vec3(0.970, 0.500, 0.150), smoothstep(0.56, 0.74, h));
  c = mix(c, vec3(1.000, 0.720, 0.250), smoothstep(0.66, 0.84, h));
  c = mix(c, vec3(1.000, 0.900, 0.720), smoothstep(0.78, 0.94, h));
  c = mix(c, vec3(1.000, 0.985, 0.960), smoothstep(0.88, 1.00, h));
  return c;
}

float envelope(float s, float a, float sL, float ws, float reach) {
  float ds = (s - sL) / (ws * (1.0 + 0.8 * max(a, 0.0)));
  ds *= ds < 0.0 ? 0.8 : 1.15;
  return exp(-ds * ds) * exp(-max(a, 0.0) / reach);
}

float orb(vec2 q, float r) {
  float d = length(q) / r;
  float m = 1.0 - smoothstep(0.7, 1.0, d);
  return m * (0.7 + 0.3 * smoothstep(0.5, 0.95, d));
}

void main() {
  vec2 res = u_resolution;
  vec3 back = texture2D(u_backdrop, gl_FragCoord.xy / res).rgb;
  vec2 p = (gl_FragCoord.xy - 0.5 * res) / res.y;
  float t = mod(u_time, 2000.0);
  float v = u_speed * 1.2;
  float vl = v * 1.6;
  float ts = t * abs(u_speed) * 2.5;
  float px = 1.0 / res.y;

  float an = radians(u_angle);
  vec2 dir = vec2(cos(an), sin(an));
  vec2 nrm = vec2(dir.y, -dir.x);
  vec2 hs = 0.5 * vec2(res.x / res.y, 1.0);
  float sMax = abs(nrm.x) * hs.x + abs(nrm.y) * hs.y;
  float uMax = abs(dir.x) * hs.x + abs(dir.y) * hs.y;

  float u = dot(p, dir);
  float s = dot(p, nrm) + 0.08 * u * u;

  vec2 pc = -hs * sign(dir);
  float sL = dot(pc, nrm) + 0.08 * uMax * uMax + u_position * sMax + 0.03 * sin(ts * 0.17);
  float a = (u + uMax) / uMax;
  float reach = mix(0.3, 1.6, u_reach);
  float ws = mix(0.1, 0.36, u_reach);

  float c1 = layer(s, u, 3.0, 2.0, vl * 0.15, t, 21.0);
  float c2 = layer(s, u, 8.0, 1.2, vl * 0.3, t, 22.0);
  float beams = smoothstep(0.2, 0.85, layer(s, u, 11.0, 0.9, vl * 0.6, t, 23.0) * 0.7 + layer(s, u, 23.0, 0.6, vl * 0.75, t, 28.0) * 0.3);
  float fine = layer(s, u, 45.0, 0.45, vl * 0.9, t, 24.0) * 0.6 + layer(s, u, 110.0, 0.3, vl, t, 25.0) * 0.4;
  float sw = s + (c1 - 0.5) * 0.14 + (c2 - 0.5) * 0.05;
  float env = envelope(sw, a, sL, ws, reach);
  float pulse = 0.85 + 0.3 * layer(0.0, 0.0, 1.0, 1.0, 1.0, ts * 0.1, 27.0);

  float db = (sw - sL - 0.02) / (ws * 0.32 * (1.0 + 0.8 * max(a, 0.0)));
  float heat = (env * (0.3 + 0.85 * beams + 0.25 * (c2 - 0.5)) + 0.3 * exp(-db * db) * exp(-max(a, 0.0) / reach)) * pulse;
  heat = clamp(heat * mix(0.6, 1.0, u_leak), 0.0, 1.0);
  vec3 leak = warmRamp(mix(0.45, 0.95, heat)) * smoothstep(0.0, 0.3, heat) * (0.75 + 0.35 * heat);
  leak *= 1.0 + (fine - 0.5) * 0.3;

  float k = u_coverSize;
  float ka = a / k;
  float envC = envelope(sw, a, sL, ws * k, reach * k);
  float dbC = db / k;
  float heatC = (envC * (0.3 + 0.85 * beams + 0.25 * (c2 - 0.5)) + 0.3 * exp(-dbC * dbC) * exp(-max(ka, 0.0) / reach)) * pulse;
  heatC = clamp(heatC * mix(0.6, 1.0, u_leak), 0.0, 1.0);
  vec3 body = warmRamp(mix(0.5, 0.95, heatC)) * mix(0.82, 1.0, smoothstep(0.05, 0.6, heatC));
  body *= 1.0 + (fine - 0.5) * 0.3;

  float sc = sL - 1.5 * ws * (1.0 + 0.5 * max(a, 0.0));
  float dc = (s + (c2 - 0.5) * 0.04 - sc) / 0.024;
  float seg = smoothstep(0.5, 0.8, layer(0.0, u, 0.0, 0.35, vl * 0.7, t, 26.0));
  float cyan = exp(-dc * dc) * seg * exp(-max(a, 0.0) / reach);
  leak += vec3(0.500, 0.820, 0.950) * cyan * 0.55;
  leak *= u_leak * 1.2;
  body = mix(body, vec3(0.500, 0.820, 0.950), min(cyan, 1.0) * 0.8);

  float cov = smoothstep(0.03, mix(0.9, 0.25, u_cover), heatC) * min(u_cover * 1.3, 1.0);
  cov = max(cov, cyan * 0.7 * u_cover) * min(u_leak * 1.25, 1.0);

  vec3 bo = vec3(0.0);
  float aTop = 1.7 * reach + 0.2;
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float h1 = hash21(vec2(fi, 3.1));
    float h2 = hash21(vec2(fi, 7.7));
    float h3 = hash21(vec2(fi, 11.3));
    float h4 = hash21(vec2(fi, 17.9));
    float life = fract(h1 + t * abs(vl) * 0.06 * (0.7 + 0.6 * h2) / (aTop + 0.3));
    float lf = mix(life, 1.0 - life, step(u_speed, 0.0));
    float ai = mix(aTop, -0.3, lf);
    float ui = ai * uMax - uMax;
    float si = sL + (h3 - 0.45) * 2.4 * ws * (1.0 + 0.8 * max(ai, 0.0));
    vec2 pi = dir * ui + nrm * (si - 0.08 * ui * ui);
    float r = mix(0.035, 0.09, h4);
    if (length(p - pi) >= r) continue;
    float ei = envelope(si, ai, sL, ws, reach);
    vec3 ci = mix(warmRamp(clamp(ei * 0.8 + 0.25, 0.0, 1.0)), vec3(1.0, 0.92, 0.85), 0.25);
    bo += ci * orb(p - pi, r) * sin(3.14159 * life) * (0.15 + 0.85 * ei) * 0.3;
  }
  bo *= u_bokeh;

  float lb = dot(back, vec3(0.299, 0.587, 0.114));
  vec3 light = (leak * (1.0 - 0.65 * cov) + bo) * mix(1.0, 0.5, smoothstep(0.35, 0.9, lb));

  vec3 col = mix(back, body, cov);
  col = 1.0 - (1.0 - col) * (1.0 - min(light, 1.0));

  float c0 = u_core + 0.04 * sin(ts * 0.21);
  float us = 0.62 * uMax;
  vec2 sun = dir * us + nrm * (c0 * sMax - 0.08 * us * us);
  float fl = u_flare * (0.8 + 0.4 * layer(0.0, 0.0, 1.0, 1.0, 1.0, ts * 0.15, 13.0));
  vec3 fx = vec3(0.0);
  vec2 ax = -dir * us;
  mat2 ap = mat2(0.966, 0.259, -0.259, 0.966);
  fx += ghost(ap * (p - (sun + ax * 0.28)), 0.022, 1.0, px) * vec3(1.0, 0.78, 0.45) * 0.22;
  fx += ghost(ap * (p - (sun + ax * 0.55)), 0.048, 0.0, px) * vec3(0.45, 0.95, 0.85) * 0.09;
  fx += ghost(ap * (p - (sun + ax * 0.82)), 0.016, 1.0, px) * vec3(0.95, 0.55, 1.0) * 0.24;
  fx += ghost(ap * (p - (sun + ax * 1.18)), 0.072, 1.0, px) * vec3(0.75, 1.0, 0.55) * 0.07;
  fx += ghost(ap * (p - (sun + ax * 1.42)), 0.032, 0.0, px) * vec3(0.55, 0.75, 1.0) * 0.14;
  fx += ghost(ap * (p - (sun + ax * 1.78)), 0.105, 1.0, px) * vec3(0.8, 0.62, 1.0) * 0.055;
  fx += ghost(ap * (p - (sun + ax * 2.25)), 0.045, 1.0, px) * vec3(1.0, 0.72, 0.4) * 0.12;
  fx += ghost(ap * (p - (sun + ax * 2.75)), 0.15, 0.0, px) * vec3(0.6, 0.85, 1.0) * 0.035;

  float rs = length(p - sun);
  vec3 re = (rs - vec3(0.36, 0.35, 0.34)) / 0.018;
  vec3 ring = exp(-re * re);
  fx += ring * 0.05;

  float ang = atan(p.y - sun.y, p.x - sun.x);
  float rays = pow(abs(cos(ang * 3.0 + 0.26)), 400.0) + 0.45 * pow(abs(cos(ang * 3.0 + 1.31)), 800.0);
  fx += vec3(1.0, 0.95, 0.88) * (exp(-rs * 9.0) * 0.5 + rays * exp(-rs * 10.0) * 0.22);
  vec3 flare = min(fx * fl * 4.5, 1.0);
  col = 1.0 - (1.0 - col) * (1.0 - flare);

  float g = hash21(gl_FragCoord.xy + vec2(71.3, 19.7) + floor(t * 24.0) * vec2(5.3, 11.9)) - 0.5;
  col += g * 0.06 * min(dot(light + flare, vec3(0.333)) * 3.0 + cov, 1.0);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
