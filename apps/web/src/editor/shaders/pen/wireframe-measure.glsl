precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @content */
uniform sampler2D u_content;

/** @sdf */
uniform sampler2D u_sdf;

/**
 * @label Progress
 * @default 1
 * @range 0, 1
 */
uniform float u_progress;

/**
 * @label Reveal
 * @default 0
 * @range 0, 1
 */
uniform float u_reveal;

/**
 * @label Loop
 * @default 0
 * @range 0, 20
 */
uniform float u_loop;

/**
 * @label Play once
 * @default 0
 * @range 0, 2
 */
uniform float u_once;

/**
 * @label Reveal delay
 * @default 0.5
 * @range 0, 10
 */
uniform float u_revealDelay;

/**
 * @label Reveal fade
 * @default 0.5
 * @range 0.05, 10
 */
uniform float u_revealFade;

/**
 * @label Pop
 * @default 1.5
 * @range 0, 3
 */
uniform float u_pop;

/**
 * @label Scatter
 * @default 0.35
 * @range 0, 1
 */
uniform float u_scatter;

/**
 * @label Margin
 * @default 0
 * @range 0, 200
 */
uniform float u_margin;

/**
 * @label Frame radius
 * @default 24
 * @range 0, 200
 */
uniform float u_radius;

/**
 * @label Handles
 * @default 10
 * @range 0, 24
 */
uniform float u_handles;

/**
 * @label Rulers
 * @default 0.6
 * @range 0, 1
 */
uniform float u_rulers;

/**
 * @label Dot pitch
 * @default 5
 * @range 3, 16
 */
uniform float u_pitch;

/**
 * @label Dot size
 * @default 2.4
 * @range 1, 8
 */
uniform float u_dot;

/**
 * @label Ink pitch
 * @default 8
 * @range 3, 24
 */
uniform float u_inkPitch;

/**
 * @label Thin limit
 * @default 6
 * @range 1, 20
 */
uniform float u_thin;

/**
 * @label Ink contrast
 * @default 0.12
 * @range 0.02, 1
 */
uniform float u_contrast;

/**
 * @label Grid
 * @default 16
 * @range 0, 64
 */
uniform float u_grid;

/**
 * @label Grid dot
 * @default 1.6
 * @range 0, 4
 */
uniform float u_gridDot;

/**
 * @label Font
 * @default 1.5
 * @range 0, 4
 */
uniform float u_font;

/**
 * @label Clock
 * @default 1
 * @range 0, 1
 */
uniform float u_clock;

/**
 * @label Ink
 * @color
 * @default #3A3A3A
 */
uniform vec3 u_ink;

/**
 * @label Grid colour
 * @color
 * @default #D6D6D6
 */
uniform vec3 u_gridColor;

/**
 * @label Paper
 * @color
 * @default #FCFCFCFF
 */
uniform vec4 u_paper;

const float TAU = 6.28318530718;

vec4 sdfAt(vec2 p) {
  return texture2D(u_sdf, p / u_resolution);
}

float paperLum() {
  return dot(u_paper.rgb, vec3(0.299, 0.587, 0.114));
}

float lumAt(vec2 p) {
  vec4 c = texture2D(u_content, p / u_resolution);
  return dot(c.rgb, vec3(0.299, 0.587, 0.114)) + (1.0 - c.a) * paperLum();
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float disc(vec2 p, vec2 c, float r) {
  return clamp(r - length(p - c) + 0.5, 0.0, 1.0);
}

float box(vec2 p, vec2 c, vec2 hf) {
  vec2 d = abs(p - c) - hf;
  return clamp(0.5 - max(d.x, d.y), 0.0, 1.0);
}

float rrect(vec2 p, vec2 c, vec2 hf, float r) {
  vec2 d = abs(p - c) - (hf - r);
  return -(length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r);
}

vec4 over(vec4 dst, vec3 col, float a) {
  return dst * (1.0 - a) + vec4(col * a, a);
}

vec2 glyphRows(float id) {
  if (id < 0.5) return vec2(476721.0, 17966.0);
  if (id < 1.5) return vec2(143492.0, 4238.0);
  if (id < 2.5) return vec2(476194.0, 4383.0);
  if (id < 3.5) return vec2(476198.0, 1582.0);
  if (id < 4.5) return vec2(72018.0, 31810.0);
  if (id < 5.5) return vec2(1033153.0, 1582.0);
  if (id < 6.5) return vec2(475678.0, 17966.0);
  if (id < 7.5) return vec2(1016900.0, 8456.0);
  if (id < 8.5) return vec2(476718.0, 17966.0);
  if (id < 9.5) return vec2(476719.0, 1070.0);
  if (id < 10.5) return vec2(17732.0, 10784.0);
  if (id < 11.5) return vec2(4255.0, 4224.0);
  if (id < 12.5) return vec2(0.0, 396.0);
  if (id < 13.5) return vec2(136132.0, 4258.0);
  return vec2(15886.0, 1984.0);
}

float pow2(float n) {
  return floor(exp2(n) + 0.5);
}

float bitAt(vec2 rows, vec2 b) {
  if (b.x < -0.5 || b.x > 4.5 || b.y < -0.5 || b.y > 6.5) return 0.0;
  float row = b.y < 3.5
    ? mod(floor(rows.x / pow2(5.0 * (3.0 - b.y))), 32.0)
    : mod(floor(rows.y / pow2(5.0 * (6.0 - b.y))), 32.0);
  return mod(floor(row / pow2(4.0 - b.x)), 2.0);
}

float digitOf(float n, float place) {
  float d = place < 0.5 ? 1.0 : place < 1.5 ? 10.0 : place < 2.5 ? 100.0 : 1000.0;
  return mod(floor(n / d + 1e-4), 10.0);
}

float nDigits(float n) {
  return n >= 999.5 ? 4.0 : n >= 99.5 ? 3.0 : n >= 9.5 ? 2.0 : 1.0;
}

float glyphAt(float i, float W, float H, float T, float clock) {
  float nW = nDigits(W);
  float nH = nDigits(H);
  if (i < nW) return digitOf(W, nW - 1.0 - i);
  i -= nW;
  if (i < 1.0) return -1.0;
  if (i < 2.0) return 10.0;
  if (i < 3.0) return -1.0;
  i -= 3.0;
  if (i < nH) return digitOf(H, nH - 1.0 - i);
  i -= nH;
  if (clock < 0.5) return -1.0;
  if (i < 1.0) return -1.0;
  if (i < 2.0) return 13.0;
  if (i < 3.0) return 11.0;
  i -= 3.0;
  float S = floor(T);
  float nS = nDigits(S);
  if (i < nS) return digitOf(S, nS - 1.0 - i);
  i -= nS;
  if (i < 1.0) return 12.0;
  float C = floor(fract(T) * 100.0);
  if (i < 2.0) return digitOf(C, 1.0);
  if (i < 3.0) return digitOf(C, 0.0);
  if (i < 4.0) return 14.0;
  return -1.0;
}

float labelSlots(float W, float H, float T, float clock) {
  float n = nDigits(W) + 3.0 + nDigits(H);
  if (clock > 0.5) n += 3.0 + nDigits(floor(T)) + 4.0;
  return n;
}

float glyphCov(vec2 local, float W, float H, float T, float clock) {
  float f = max(u_font, 0.25);
  vec2 q = local / f;
  float h = 0.5 / f;
  vec2 lo = q - h;
  vec2 hi = q + h;
  float cov = 0.0;
  for (int j = 0; j < 2; j++) {
    for (int i = 0; i < 2; i++) {
      vec2 b = floor(lo) + vec2(float(i), float(j));
      vec2 o = max(min(hi, b + 1.0) - max(lo, b), 0.0);
      float area = o.x * o.y / (4.0 * h * h);
      float slot = floor(b.x / 6.0);
      float col = b.x - slot * 6.0;
      float row = 6.0 - b.y;
      float id = glyphAt(slot, W, H, T, clock);
      float bit = (id < 0.0 || b.x < -0.5 || col > 4.5 || row < -0.5 || row > 6.5) ? 0.0 : bitAt(glyphRows(id), vec2(col, row));
      cov += area * bit;
    }
  }
  return min(cov, 1.0);
}

float traceDir(vec2 p, vec2 dir, float s0) {
  vec2 res = u_resolution;
  float tMax = dir.x > 0.5 ? res.x - p.x : dir.x < -0.5 ? p.x : dir.y > 0.5 ? res.y - p.y : p.y;
  float a = 0.0;
  float sa = s0;
  float b = -1.0;
  for (int i = 0; i < 40; i++) {
    float t = a + max(sa, 1.0);
    if (t >= tMax - 0.5) return tMax;
    float st = sdfAt(p + dir * t).r;
    if (st > 0.25) {
      a = t;
      sa = st;
    } else {
      b = t;
      break;
    }
  }
  if (b < 0.0) return -1.0;
  for (int i = 0; i < 9; i++) {
    if (b - a < 1.0) break;
    float m = 0.5 * (a + b);
    float sm = sdfAt(p + dir * m).r;
    if (sm > 0.25) a = m; else b = m;
  }
  vec2 q = p + dir * 0.5 * (a + b);
  vec2 qs = floor(q) + 0.5;
  return dot(qs - p, dir) + sdfAt(qs).r;
}

vec2 appear(float x, float a) {
  float d = x - a;
  return vec2(1.0 + u_pop * (1.0 - smoothstep(0.0, 0.08, d)), smoothstep(0.0, 0.025, d));
}

float cellContour(vec2 cell, vec2 p, float cs, float x, float sweepY) {
  vec2 q = (cell + 0.5) * cs;
  vec4 t = sdfAt(q);
  float s = t.r;
  float gl = length(t.gb);
  vec2 n = t.gb / max(gl, 1e-4);
  vec2 e = q - s * n;
  float near = step(abs(s), cs * 0.75);
  vec2 inC = step(abs(e - q), vec2(cs * 0.5));
  vec2 inB = step(vec2(1.5), e) * step(e, u_resolution - 1.5);

  if (near * inC.x * inC.y * inB.x * inB.y < 0.5) return 0.0;
  float s2 = sdfAt(e + n * u_thin).r;
  float thick = smoothstep(0.3, 0.6, s2 / u_thin);
  float gOk = smoothstep(0.3, 0.6, gl);
  float on = thick * gOk;
  float a = mix((sweepY - e.y) / sweepY, hash(cell + 0.37), u_scatter) * 0.92;
  vec2 ap = appear(x, a);
  return on * ap.y * disc(p, e, 0.5 * u_dot * ap.x);
}

vec2 cellInk(vec2 cell, float cs) {
  vec2 q = (cell + 0.5) * cs;
  vec4 t = sdfAt(q);
  float s = t.r;
  float gl = length(t.gb);
  vec2 n = t.gb / max(gl, 1e-4);
  vec2 e = q - s * n;
  float s2 = sdfAt(e + n * u_thin).r;
  float thick = smoothstep(0.3, 0.6, s2 / u_thin);
  float near = step(abs(s), cs * 0.75);
  float h = cs * 0.5;
  float l0 = lumAt(q);
  float c = abs(lumAt(q + vec2(h, 0.0)) - l0);
  c = max(c, abs(lumAt(q - vec2(h, 0.0)) - l0));
  c = max(c, abs(lumAt(q + vec2(0.0, h)) - l0));
  c = max(c, abs(lumAt(q - vec2(0.0, h)) - l0));
  float contrast = smoothstep(u_contrast, u_contrast + 0.3, c);
  float thinInk = (1.0 - thick) * smoothstep(-cs * 0.5, 0.0, s);
  float ink = max(contrast, thinInk) * (1.0 - thick * near);
  return vec2(ink, thick * near);
}

void main() {
  vec2 p = gl_FragCoord.xy;
  vec2 res = u_resolution;
  vec2 uv = p / res;

  float prog = u_progress;
  float rev = u_reveal;
  float elapsed = prog * 2.0;
  if (u_loop > 0.0) {
    float ph = u_time / u_loop + u_progress;
    float d = max(u_revealDelay, 0.0) / u_loop;
    float f = max(u_revealFade, 0.02) / u_loop;
    if (u_once > 0.5) {
      ph = min(ph, max(1.0, 0.5 + d + f));
      prog = smoothstep(0.0, 0.5, ph);
      rev = u_once > 1.5 ? 0.0 : smoothstep(0.5 + d, 0.5 + d + f, ph);
    } else {
      ph = fract(ph);
      float a = min(0.5 + d, 0.84);
      float b = min(a + f, 0.86);
      prog = smoothstep(0.0, 0.5, ph) * (1.0 - smoothstep(0.94, 1.0, ph));
      rev = smoothstep(a, b, ph) * (1.0 - smoothstep(0.88, 0.94, ph));
    }
    elapsed = ph * u_loop;
  }
  float gridA = smoothstep(0.0, 0.12, prog);
  float frameA = smoothstep(0.04, 0.1, prog);
  float head = smoothstep(0.06, 0.42, prog) * 1.08;
  float x = clamp((prog - 0.34) / 0.62, 0.0, 1.0);

  float hd = 0.5 * u_dot;
  float m = u_margin;
  vec2 fl = vec2(m + hd, m + hd);
  vec2 fh = vec2(res.x - m - hd, res.y - m - hd);
  vec2 fc = 0.5 * (fl + fh);
  vec2 fhalf = 0.5 * (fh - fl);
  float fr = min(u_radius, min(fhalf.x, fhalf.y));
  float a0 = atan(fhalf.y, -fhalf.x);

  vec4 layer = vec4(u_paper.rgb * u_paper.a, u_paper.a);

  if (u_grid > 0.5) {
    vec2 g0 = vec2(fl.x, fh.y);
    vec2 gp = g0 + floor((p - g0) / u_grid + 0.5) * u_grid;
    float gc = disc(p, gp, 0.5 * u_gridDot) * gridA;
    layer = over(layer, u_gridColor, gc);
  }

  if (u_rulers > 0.0 && m > 1.0) {
    float outsideX = step(fh.x + 1.0, p.x) + step(p.x, fl.x - 1.0);
    float outsideY = step(fh.y + 1.0, p.y) + step(p.y, fl.y - 1.0);
    float onV = (1.0 - smoothstep(0.4, 0.8, min(abs(p.x - fl.x), abs(p.x - fh.x)))) * step(0.5, outsideY);
    float onH = (1.0 - smoothstep(0.4, 0.8, min(abs(p.y - fl.y), abs(p.y - fh.y)))) * step(0.5, outsideX);
    float dashV = disc(vec2(0.0, p.y), vec2(0.0, floor(p.y / 4.0 + 0.5) * 4.0), 0.5);
    float dashH = disc(vec2(p.x, 0.0), vec2(floor(p.x / 4.0 + 0.5) * 4.0, 0.0), 0.5);
    float rc = max(onV * dashV, onH * dashH) * u_rulers * frameA;
    layer = over(layer, u_ink, rc);
  }

  float cs = max(u_pitch, 2.0);
  vec2 pc = floor(p / cs);
  float frameCov = 0.0;

  if (abs(rrect(p, fc, fhalf, fr)) < hd * (1.0 + max(u_pop, 0.0)) + 1.5 * cs + 1.0)
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 q = (pc + vec2(float(i), float(j)) + 0.5) * cs;
      float s = rrect(q, fc, fhalf, fr);
      vec2 g = vec2(rrect(q + vec2(0.5, 0.0), fc, fhalf, fr) - rrect(q - vec2(0.5, 0.0), fc, fhalf, fr),
                    rrect(q + vec2(0.0, 0.5), fc, fhalf, fr) - rrect(q - vec2(0.0, 0.5), fc, fhalf, fr));
      vec2 n = g / max(length(g), 1e-4);
      vec2 e = q - s * n;
      vec2 inC = step(abs(e - q), vec2(cs * 0.5));
      float on = step(abs(s), cs * 0.75) * inC.x * inC.y;
      float param = fract((a0 - atan(e.y - fc.y, e.x - fc.x)) / TAU);
      float d = head - param;
      float sz = 1.0 + u_pop * (1.0 - smoothstep(0.0, 0.05, d));
      frameCov = max(frameCov, on * smoothstep(0.0, 0.004, d) * disc(p, e, hd * sz));
    }
  }
  layer = over(layer, u_ink, frameCov);

  vec2 bo = floor(p * 0.5) * 2.0;
  vec2 ca = floor((bo + 0.5) / cs);
  float wireCov = 0.0;
  for (int j = -1; j <= 2; j++) {
    for (int i = -1; i <= 2; i++) {
      wireCov = max(wireCov, cellContour(ca + vec2(float(i), float(j)), p, cs, x, res.y));
    }
  }

  float ks = max(u_inkPitch, 2.0);
  vec2 ka = floor((bo + 0.5) / ks);
  vec2 kb = floor((bo + 1.5) / ks);
  vec2 i00 = cellInk(ka, ks);
  vec2 i10 = cellInk(vec2(kb.x, ka.y), ks);
  vec2 i01 = cellInk(vec2(ka.x, kb.y), ks);
  vec2 i11 = cellInk(kb, ks);
  vec2 own = floor(p / ks);
  vec2 ink = own.x < ka.x + 0.5 ? (own.y < ka.y + 0.5 ? i00 : i01) : (own.y < ka.y + 0.5 ? i10 : i11);
  vec2 oq = (own + 0.5) * ks;
  float aInk = mix((res.y - oq.y) / res.y, hash(own + 0.71), u_scatter) * 0.92;
  vec2 apInk = appear(x, aInk);
  float inkR = min(0.5 * u_dot * (0.6 + 0.6 * ink.x) * apInk.x, ks * 0.5);
  float inkCov = ink.x * apInk.y * disc(p, oq, inkR);
  wireCov = max(wireCov, inkCov);
  layer = over(layer, u_ink, wireCov);

  if (u_handles > 0.5) {
    float hs = 0.5 * u_handles;
    float hb = 0.0;
    float hr = 0.0;
    for (int k = 0; k < 4; k++) {
      vec2 c = vec2(k == 0 || k == 3 ? fl.x : fh.x, k < 2 ? fh.y : fl.y);
      float outer = box(p, c, vec2(hs));
      float inner = box(p, c, vec2(hs - 1.0));
      hb = max(hb, outer);
      hr = max(hr, outer - inner);
    }
    layer = over(layer, u_paper.rgb, hb * frameA);
    layer = over(layer, u_ink, hr * frameA);
  }

  if (u_font > 0.0) {
    float f = u_font;
    float W = floor(res.x - 2.0 * m + 0.5);
    float H = floor(res.y - 2.0 * m + 0.5);
    float hs = 0.5 * u_handles;
    float lw = labelSlots(W, H, elapsed, u_clock) * 6.0 * f - f;
    vec2 org = m > 7.0 * f + hs + 6.0
      ? vec2(fh.x - hs - 2.0 - lw, fh.y + hs + 3.0)
      : vec2(fh.x - hs - 4.0 - lw, fh.y - hs - 4.0 - 7.0 * f);
    float lc = glyphCov(p - org, W, H, elapsed, u_clock);
    layer = over(layer, u_ink, lc * frameA);
  }

  float s0 = sdfAt(p).r;
  if (u_font > 0.0 && s0 > 0.5) {
    float f = u_font;
    float U = traceDir(p, vec2(0.0, 1.0), s0);
    float L = U > 0.0 && U < 7.0 * f + 10.0 ? traceDir(p, vec2(-1.0, 0.0), s0) : -1.0;
    if (U > 0.0 && L > 0.0 && U < 7.0 * f + 10.0 && L < 72.0 * f + 10.0) {
      vec2 pd = vec2(p.x + 16.0, p.y);
      float sd = sdfAt(pd).r;
      float Ud = traceDir(pd, vec2(0.0, 1.0), sd);
      float D = traceDir(pd, vec2(0.0, -1.0), sd);
      if (sd > 0.5 && Ud > 0.0 && D > 0.0) {
        vec2 c = vec2(pd.x, pd.y + 0.5 * (Ud - D));
        float sc = sdfAt(c).r;
        float Lc = traceDir(c, vec2(-1.0, 0.0), sc);
        float Rc = traceDir(c, vec2(1.0, 0.0), sc);
        if (sc > 0.5 && Lc > 0.0 && Rc > 0.0) {
          float W = Lc + Rc;
          float left = c.x - Lc;
          vec2 c2 = vec2(left + 0.5 * W, c.y);
          float sc2 = sdfAt(c2).r;
          float Uc = traceDir(c2, vec2(0.0, 1.0), sc2);
          float Dc = traceDir(c2, vec2(0.0, -1.0), sc2);
          if (sc2 > 0.5 && Uc > 0.0 && Dc > 0.0) {
            float H = Uc + Dc;
            float top = c2.y + Uc;
            vec2 pt = vec2(p.x, top - 5.5);
            float st = sdfAt(pt).r;
            float Lt = traceDir(pt, vec2(-1.0, 0.0), max(st, 0.6));
            float inset = clamp(p.x - Lt - left, 0.0, 0.5 * W);
            float Wr = floor(W + 0.5);
            float Hr = floor(H + 0.5);
            float slots = labelSlots(Wr, Hr, 0.0, 0.0);
            float fits = step(slots * 6.0 * f + 12.0 + 2.0 * inset, W) * step(7.0 * f + 10.0, H);
            fits *= 1.0 - step(left, 2.0) * step(res.y - 2.0, top);
            vec2 org = vec2(left + inset + 6.0, top - 5.0 - 7.0 * f);
            float aBox = (res.y - top) / res.y * 0.92;
            float la = smoothstep(0.0, 0.05, x - aBox - 0.06);
            float lc = glyphCov(p - org, Wr, Hr, 0.0, 0.0);
            layer = over(layer, u_ink, lc * fits * la);
          }
        }
      }
    }
  }

  vec4 content = texture2D(u_content, uv);
  gl_FragColor = mix(layer, content, rev);
}
