precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Rows
 * @default 48
 * @range 16, 140
 */
uniform float u_rows;

/**
 * @label Key
 * @default 1
 * @range 0, 1
 */
uniform float u_key;

/**
 * @label Gain
 * @default 1.3
 * @range 0, 4
 */
uniform float u_gain;

/**
 * @label Shimmer
 * @default 0.5
 * @range 0, 1
 */
uniform float u_shimmer;

/**
 * @label Stars
 * @default 0.5
 * @range 0, 1
 */
uniform float u_stars;

/**
 * @label Echo
 * @default 0.6
 * @range 0, 1
 */
uniform float u_echo;

/**
 * @label Speed
 * @default 1
 * @range 0, 3
 */
uniform float u_speed;

/**
 * @label Ink
 * @color
 * @default #e8e8e8
 */
uniform vec3 u_ink;

/**
 * @label Paper
 * @color
 * @default #000000
 */
uniform vec3 u_paper;

/**
 * @label Use paper colour
 * @default 1
 * @range 0, 1
 */
uniform float u_paperOpacity;

/**
 * @label Source colour
 * @default 1
 * @range 0, 1
 */
uniform float u_sourceColour;

const float TAU = 6.2831853;

float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec4 hash42(vec2 p) {
  vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

vec3 g_bg;
float g_bgNorm;

vec2 inkAt(vec2 pos, out vec3 c) {
  c = texture2D(u_backdrop, pos / u_resolution).rgb;
  float lum = dot(c, vec3(0.299, 0.587, 0.114));
  float mask = smoothstep(0.006, 0.05, length(c - g_bg) / g_bgNorm);
  float shade = pow(lum, 1.6);
  return mix(vec2(shade), vec2(mask * mix(0.04, 1.0, shade), mask), u_key);
}

void quadInk(vec2 base, vec2 cs, vec2 centre, float scale, float turn, out vec4 ink, out vec4 mask, out vec3 inkRGB, out vec3 maskRGB) {
  mat2 rot = mat2(cos(turn), -sin(turn), sin(turn), cos(turn)) / scale;
  vec3 ca, cb, cc, cd;
  vec2 a = inkAt(centre + rot * (base + cs * vec2(0.25, 0.75) - centre), ca);
  vec2 b = inkAt(centre + rot * (base + cs * vec2(0.75, 0.75) - centre), cb);
  vec2 c = inkAt(centre + rot * (base + cs * vec2(0.25, 0.25) - centre), cc);
  vec2 d = inkAt(centre + rot * (base + cs * vec2(0.75, 0.25) - centre), cd);
  inkRGB = ca * a.x + cb * b.x + cc * c.x + cd * d.x;
  maskRGB = ca * a.y + cb * b.y + cc * c.y + cd * d.y;
  ink = vec4(a.x, b.x, c.x, d.x);
  mask = vec4(a.y, b.y, c.y, d.y);
}

float tent(float x) {
  return clamp(1.0 - abs(x), 0.0, 1.0);
}

float segCover(vec2 q, vec2 a, vec2 b, float w, vec2 hs) {
  vec2 ab = b - a;
  float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
  vec2 d = q - (a + ab * t);
  float len = length(d);
  d *= max(len - w, 0.0) / max(len, 1e-4);
  return tent(d.x / hs.x) * tent(d.y / hs.y);
}

vec4 starInk(vec2 base, vec2 cs, vec2 centre, float tw) {
  float h = u_resolution.y;
  const float NA = 96.0;
  const float NR = 5.0;
  vec2 rel = base + 0.5 * cs - centre;
  float u = atan(rel.y, rel.x) / TAU * NA;
  float v = log(max(length(rel), 1.0) / h) * NR - tw;
  vec2 halfQ = cs * 0.38;
  vec2 qa = base + cs * vec2(0.25, 0.75);
  vec2 qb = base + cs * vec2(0.75, 0.75);
  vec2 qc = base + cs * vec2(0.25, 0.25);
  vec2 qd = base + cs * vec2(0.75, 0.25);
  float trail = clamp(0.03 + 0.12 * u_speed, 0.0, 0.5);
  vec4 acc = vec4(0.0);
  for (int i = -1; i <= 1; i++) {
    for (int j = -1; j <= 1; j++) {
      vec2 id = vec2(floor(u) + float(i), floor(v) + float(j));
      vec4 r = hash42(vec2(mod(id.x, NA), id.y) + 17.0);
      float on = step(r.x, u_stars * 0.5);
      if (on == 0.0) continue;
      float ang = (id.x + 0.15 + 0.7 * r.y) / NA * TAU;
      float vv = id.y + r.z;
      float rh = h * exp((vv + tw) / NR);
      float rt = rh * exp(-trail / NR);
      vec2 dir = vec2(cos(ang), sin(ang));
      vec2 pa = centre + dir * rt;
      vec2 pb = centre + dir * rh;
      float big = step(0.975, r.w) * cs.x * (0.3 + 1.4 * fract(r.w * 13.7));
      float bright = on * smoothstep(0.04 * h, 0.22 * h, rh)
        * mix(0.3, 0.75, fract(r.y * 7.3)) * mix(0.6, 1.1, smoothstep(0.1 * h, 0.7 * h, rh));
      acc += bright * vec4(
        segCover(qa, pa, pb, big, halfQ),
        segCover(qb, pa, pb, big, halfQ),
        segCover(qc, pa, pb, big, halfQ),
        segCover(qd, pa, pb, big, halfQ));
    }
  }
  return acc;
}

vec4 g_q;
float g_best;
vec3 g_bits;
float g_idx;
float g_jit;
float g_seed;

void G(float a, float b, float c, float d, float b0, float b1, float b2) {
  vec4 e = g_q - vec4(a, b, c, d);
  float s = dot(e, e) + g_jit * hash11(g_seed + g_idx * 1.618);
  if (s < g_best) {
    g_best = s;
    g_bits = vec3(b0, b1, b2);
  }
  g_idx += 1.0;
}

void matchGlyph() {
  G(0.000, 0.000, 0.000, 0.000, 0.0, 0.0, 0.0);
  G(0.222, 0.222, 0.167, 0.167, 1065216.0, 16644.0, 4.0);
  G(0.333, 0.333, 0.000, 0.000, 2663040.0, 0.0, 0.0);
  G(0.500, 0.500, 0.611, 0.611, 8167424.0, 8168074.0, 10.0);
  G(0.722, 0.611, 0.500, 0.722, 1333124.0, 5326094.0, 271.0);
  G(0.222, 0.444, 0.333, 0.333, 2696192.0, 4800776.0, 2.0);
  G(0.333, 0.556, 0.556, 0.444, 4793088.0, 4624780.0, 46.0);
  G(0.167, 0.167, 0.000, 0.000, 1065216.0, 0.0, 0.0);
  G(0.389, 0.278, 0.389, 0.278, 532760.0, 532610.0, 1540.0);
  G(0.167, 0.500, 0.167, 0.500, 4260358.0, 4260880.0, 392.0);
  G(0.167, 0.278, 0.444, 0.556, 4718592.0, 4771788.0, 0.0);
  G(0.111, 0.111, 0.389, 0.389, 1048576.0, 1066948.0, 0.0);
  G(0.000, 0.000, 0.222, 0.111, 0.0, 1048576.0, 132.0);
  G(0.000, 0.000, 0.278, 0.278, 0.0, 1984.0, 0.0);
  G(0.000, 0.000, 0.056, 0.056, 0.0, 0.0, 4.0);
  G(0.056, 0.500, 0.500, 0.056, 2130960.0, 532740.0, 65.0);
  G(0.556, 0.667, 0.611, 0.500, 6624128.0, 4527317.0, 14.0);
  G(0.333, 0.222, 0.333, 0.333, 1073408.0, 1065220.0, 14.0);
  G(0.278, 0.500, 0.667, 0.444, 4264832.0, 267152.0, 31.0);
  G(0.333, 0.556, 0.278, 0.500, 4264832.0, 4523020.0, 14.0);
  G(0.444, 0.222, 0.389, 0.611, 2363456.0, 2224713.0, 8.0);
  G(0.778, 0.444, 0.278, 0.500, 268224.0, 4260879.0, 15.0);
  G(0.667, 0.333, 0.500, 0.500, 267136.0, 4527183.0, 14.0);
  G(0.389, 0.611, 0.222, 0.222, 4265920.0, 1065224.0, 4.0);
  G(0.556, 0.556, 0.500, 0.500, 4526976.0, 4527182.0, 14.0);
  G(0.500, 0.500, 0.333, 0.667, 4526976.0, 4261777.0, 14.0);
  G(0.056, 0.056, 0.056, 0.056, 0.0, 4.0, 4.0);
  G(0.056, 0.056, 0.222, 0.111, 0.0, 1048580.0, 132.0);
  G(0.167, 0.278, 0.167, 0.278, 1082368.0, 2113666.0, 16.0);
  G(0.278, 0.278, 0.278, 0.278, 0.0, 127007.0, 0.0);
  G(0.167, 0.278, 0.167, 0.278, 2113664.0, 1082384.0, 2.0);
  G(0.278, 0.500, 0.167, 0.167, 4264832.0, 16648.0, 4.0);
  G(0.556, 0.667, 0.611, 0.833, 4526976.0, 382813.0, 30.0);
  G(0.500, 0.500, 0.611, 0.611, 4526976.0, 4528081.0, 17.0);
  G(0.778, 0.556, 0.611, 0.500, 4527040.0, 4527183.0, 15.0);
  G(0.500, 0.278, 0.500, 0.278, 268160.0, 266305.0, 30.0);
  G(0.611, 0.500, 0.611, 0.500, 4527040.0, 4527185.0, 15.0);
  G(0.667, 0.444, 0.500, 0.278, 268160.0, 266319.0, 30.0);
  G(0.667, 0.444, 0.444, 0.000, 268160.0, 266319.0, 1.0);
  G(0.556, 0.556, 0.500, 0.611, 268160.0, 4527197.0, 30.0);
  G(0.611, 0.611, 0.444, 0.444, 4527168.0, 4527199.0, 17.0);
  G(0.333, 0.333, 0.333, 0.333, 1065856.0, 1065220.0, 14.0);
  G(0.333, 0.333, 0.389, 0.167, 1065856.0, 1065220.0, 3.0);
  G(0.611, 0.389, 0.444, 0.444, 2430016.0, 4526663.0, 17.0);
  G(0.444, 0.000, 0.500, 0.278, 266304.0, 266305.0, 30.0);
  G(0.778, 0.778, 0.444, 0.444, 8238144.0, 4527189.0, 17.0);
  G(0.722, 0.500, 0.500, 0.722, 5059648.0, 6657365.0, 17.0);
  G(0.500, 0.500, 0.500, 0.500, 4526976.0, 4527185.0, 14.0);
  G(0.611, 0.500, 0.611, 0.167, 4527040.0, 267217.0, 1.0);
  G(0.500, 0.500, 0.500, 0.722, 4526976.0, 4527185.0, 1550.0);
  G(0.611, 0.500, 0.611, 0.500, 4527040.0, 4527057.0, 17.0);
  G(0.556, 0.444, 0.278, 0.500, 268160.0, 4260878.0, 15.0);
  G(0.444, 0.444, 0.222, 0.222, 1066944.0, 1065220.0, 4.0);
  G(0.444, 0.444, 0.500, 0.611, 4527168.0, 4527185.0, 30.0);
  G(0.444, 0.444, 0.556, 0.556, 4527168.0, 3740753.0, 14.0);
  G(0.444, 0.444, 0.778, 0.778, 4527168.0, 7206225.0, 17.0);
  G(0.389, 0.389, 0.444, 0.444, 2692160.0, 4526724.0, 17.0);
  G(0.444, 0.444, 0.444, 0.667, 4527168.0, 4261777.0, 15.0);
  G(0.333, 0.556, 0.611, 0.278, 2164672.0, 266372.0, 31.0);
  G(0.611, 0.278, 0.611, 0.278, 532638.0, 532610.0, 1922.0);
  G(0.500, 0.056, 0.056, 0.500, 532545.0, 2130180.0, 1040.0);
  G(0.167, 0.722, 0.167, 0.722, 4260894.0, 4260880.0, 1936.0);
  G(0.278, 0.278, 0.000, 0.000, 4497664.0, 0.0, 0.0);
  G(0.000, 0.000, 0.278, 0.278, 0.0, 0.0, 1984.0);
  G(0.167, 0.167, 0.000, 0.000, 2113664.0, 0.0, 0.0);
  G(0.167, 0.278, 0.556, 0.778, 3670016.0, 4528016.0, 30.0);
  G(0.611, 0.278, 0.611, 0.500, 3936320.0, 4527185.0, 15.0);
  G(0.278, 0.278, 0.500, 0.278, 7864320.0, 266305.0, 30.0);
  G(0.278, 0.611, 0.500, 0.611, 7930880.0, 4527185.0, 30.0);
  G(0.278, 0.389, 0.667, 0.667, 7864320.0, 390225.0, 30.0);
  G(0.556, 0.444, 0.444, 0.000, 534272.0, 532623.0, 2.0);
  G(0.278, 0.389, 0.778, 0.778, 7864320.0, 4527185.0, 62478.0);
  G(0.611, 0.278, 0.444, 0.444, 3936320.0, 4527185.0, 17.0);
  G(0.278, 0.167, 0.222, 0.333, 1573120.0, 1065220.0, 12.0);
  G(0.000, 0.333, 0.167, 0.500, 2097664.0, 2130440.0, 392.0);
  G(0.500, 0.167, 0.611, 0.278, 2363456.0, 2379973.0, 17.0);
  G(0.444, 0.000, 0.389, 0.167, 532608.0, 532610.0, 12.0);
  G(0.444, 0.333, 0.556, 0.556, 3932160.0, 4543829.0, 17.0);
  G(0.389, 0.278, 0.444, 0.444, 3932160.0, 4527185.0, 17.0);
  G(0.278, 0.278, 0.500, 0.500, 3670016.0, 4527185.0, 14.0);
  G(0.389, 0.278, 0.944, 0.500, 3932160.0, 4527185.0, 266319.0);
  G(0.278, 0.389, 0.500, 0.944, 7864320.0, 4527185.0, 4260894.0);
  G(0.278, 0.389, 0.444, 0.000, 7864320.0, 266321.0, 1.0);
  G(0.278, 0.278, 0.444, 0.556, 7864320.0, 4260737.0, 15.0);
  G(0.611, 0.056, 0.389, 0.167, 1843328.0, 532610.0, 12.0);
  G(0.222, 0.222, 0.500, 0.611, 4456448.0, 4527185.0, 30.0);
  G(0.222, 0.222, 0.389, 0.389, 4456448.0, 2692177.0, 4.0);
  G(0.222, 0.222, 0.778, 0.778, 4456448.0, 7206225.0, 17.0);
  G(0.222, 0.222, 0.556, 0.556, 4456448.0, 4514705.0, 17.0);
  G(0.222, 0.222, 0.778, 1.000, 4456448.0, 4527185.0, 3998750.0);
  G(0.278, 0.389, 0.444, 0.444, 8126464.0, 541200.0, 31.0);
  G(0.389, 0.389, 0.389, 0.389, 1065240.0, 1065155.0, 1540.0);
  G(0.278, 0.278, 0.278, 0.278, 1065220.0, 1065220.0, 260.0);
  G(0.167, 0.500, 0.167, 0.500, 2130438.0, 2133040.0, 392.0);
  G(0.000, 0.000, 0.278, 0.278, 0.0, 54400.0, 0.0);
}

float bitAt(vec3 bits, float col, float row) {
  if (col < 0.0 || col > 5.0 || row < 0.0 || row > 11.0) {
    return 0.0;
  }
  float k = floor(row / 4.0);
  float f = k < 0.5 ? bits.x : (k < 1.5 ? bits.y : bits.z);
  float d = floor(exp2(mod(row, 4.0) * 6.0 + col) + 0.5);
  float v = floor((f + 0.5) / d);
  return v - 2.0 * floor(v * 0.5 + 0.25);
}

void main() {
  vec2 res = u_resolution;
  float cellH = max(2.0, 2.0 * floor(res.y / max(u_rows, 4.0) * 0.5 + 0.5));
  float px = cellH / 12.0;
  float cellW = max(2.0, 2.0 * floor(px * 3.0 + 0.5));
  vec2 cs = vec2(cellW, cellH);
  vec2 count = floor(res / cs);
  vec2 origin = 2.0 * floor((res - count * cs) * 0.25);
  vec2 p = gl_FragCoord.xy - origin;
  vec2 cell = floor(p / cs);
  vec2 local = p - cell * cs;
  vec2 base = origin + cell * cs;
  vec2 centre = res * 0.5;

  float frame = floor(u_time * 14.0);
  float t = frame / 14.0;

  g_bg = 0.25 * (
    texture2D(u_backdrop, vec2(0.01, 0.01)).rgb +
    texture2D(u_backdrop, vec2(0.99, 0.01)).rgb +
    texture2D(u_backdrop, vec2(0.01, 0.99)).rgb +
    texture2D(u_backdrop, vec2(0.99, 0.99)).rgb);
  g_bgNorm = max(length(max(g_bg, 1.0 - g_bg)), 0.5);

  vec4 q;
  vec4 m;
  vec3 colourSum, maskRGB;
  quadInk(base, cs, centre, 1.0, 0.0, q, m, colourSum, maskRGB);
  colourSum *= u_gain;
  q *= u_gain;

  for (int e = 0; e < 3; e++) {
    float ph = fract(t * 0.16 * u_speed + float(e) / 3.0);
    vec4 ei;
    vec3 echoRGB, echoMaskRGB;
    quadInk(base, cs, centre, exp(ph * 1.1), ph * 0.45, ei, m, echoRGB, echoMaskRGB);
    float edge = max(max(m.x, m.y), max(m.z, m.w)) - min(min(m.x, m.y), min(m.z, m.w));
    float fade = smoothstep(0.02, 0.15, ph) * (1.0 - ph) * (1.0 - ph);
    float keep = step(hash11(dot(cell, vec2(1.0, 157.0)) + frame * 0.71 + float(e) * 3.1), 0.45);
    float echoWeight = edge * fade * keep * u_echo * 0.9;
    q += m * echoWeight;
    colourSum += echoMaskRGB * echoWeight;
  }

  if (u_stars > 0.0) {
    vec4 stars = starInk(base, cs, centre, t * u_speed * 3.0);
    q += stars;
    colourSum += u_ink * dot(stars, vec4(1.0));
  }

  float colourWeight = dot(q, vec4(1.0));
  vec3 sourceInk = colourWeight > 0.00001 ? colourSum / max(colourWeight, 0.00001) : u_ink;
  vec3 glyphInk = mix(u_ink, sourceInk, u_sourceColour);

  q = 0.68 * (1.0 - exp(-2.4 * q));
  vec4 n = hash42(cell + frame * vec2(37.1, 11.7));
  q = clamp(q * (1.0 + (n - 0.5) * u_shimmer * 0.7), 0.0, 1.0);

  g_q = q;
  g_best = 1e9;
  g_bits = vec3(0.0);
  g_idx = 0.0;
  g_jit = u_shimmer * 0.03 * smoothstep(0.08, 0.35, max(max(q.x, q.y), max(q.z, q.w)));
  g_seed = floor(hash11(dot(cell, vec2(1.0, 157.0)) + frame * 0.37) * 1000.0);
  matchGlyph();

  float inside = step(0.0, cell.x) * step(cell.x, count.x - 1.0)
    * step(0.0, cell.y) * step(cell.y, count.y - 1.0);

  vec2 gp = local - vec2(0.5 * (cellW - 6.0 * px), 0.0);
  float cover = 0.0;
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < 2; j++) {
      vec2 s = gp + (vec2(float(i), float(j)) - 0.5) * 0.5;
      cover += bitAt(g_bits, floor(s.x / px), 11.0 - floor(s.y / px));
    }
  }
  cover *= 0.25 * inside;

  vec3 paper = mix(g_bg, u_paper, clamp(u_paperOpacity, 0.0, 1.0));
  gl_FragColor = vec4(mix(paper, glyphInk, cover), 1.0);
}

/*
 * Spleen font licence, covering the glyph bitmaps in matchGlyph():
 *
 * Copyright (c) 2018-2024, Frederic Cambus
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
