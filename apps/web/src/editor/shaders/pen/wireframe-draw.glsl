precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @content */
uniform sampler2D u_content;

/**
 * @label Progress
 * @default 1
 * @range 0, 1
 */
uniform float u_progress;

/**
 * @label Auto Play
 * @default 0
 * @range 0, 1
 */
uniform float u_play;

/**
 * @label Duration
 * @default 3
 * @range 0.5, 20
 */
uniform float u_duration;

/**
 * @label Delay
 * @default 0
 * @range 0, 10
 */
uniform float u_delay;

/**
 * @label Hold
 * @default 1.5
 * @range 0, 10
 */
uniform float u_hold;

/**
 * @label Loop
 * @default 1
 * @range 0, 1
 */
uniform float u_loop;

/**
 * @label Scatter
 * @default 60
 * @range 0, 300
 */
uniform float u_scatter;

/**
 * @label Reveal
 * @default 0
 * @range 0, 1
 */
uniform float u_reveal;

/**
 * @label Paper
 * @color
 * @default #FFFFFFFF
 */
uniform vec4 u_paper;

/**
 * @label Ink
 * @color
 * @default #3C3C3C
 */
uniform vec3 u_ink;

/**
 * @label Grid Spacing
 * @default 24
 * @range 4, 120
 */
uniform float u_gridPitch;

/**
 * @label Grid Dot
 * @default 1.4
 * @range 0, 4
 */
uniform float u_gridSize;

/**
 * @label Grid Strength
 * @default 0.28
 * @range 0, 1
 */
uniform float u_gridAlpha;

/**
 * @label Dot Spacing
 * @default 6
 * @range 2, 16
 */
uniform float u_dotPitch;

/**
 * @label Dot Size
 * @default 1.8
 * @range 0.5, 6
 */
uniform float u_dotSize;

/**
 * @label Edge Threshold
 * @default 0.06
 * @range 0.02, 0.6
 */
uniform float u_edge;

/**
 * @label Text Dot
 * @default 2.6
 * @range 0, 6
 */
uniform float u_textDot;

/**
 * @label Text Threshold
 * @default 0.1
 * @range 0.02, 0.5
 */
uniform float u_textLevel;

/**
 * @label Text Density
 * @default 0.26
 * @range 0.05, 0.8
 */
uniform float u_density;

/**
 * @label Frame Outline
 * @default 1
 * @range 0, 1
 */
uniform float u_frame;

/**
 * @label Handle Size
 * @default 8
 * @range 0, 24
 */
uniform float u_handle;

/**
 * @label Label Pixel
 * @default 2
 * @range 1, 4
 */
uniform float u_labelScale;

/**
 * @label Label Opacity
 * @default 0.8
 * @range 0, 1
 */
uniform float u_labelAlpha;

/**
 * @label Shape Labels
 * @default 1
 * @range 0, 1
 */
uniform float u_labels;

/**
 * @label Show Timer
 * @default 1
 * @range 0, 1
 */
uniform float u_timer;

/**
 * @label Label Min Size
 * @default 24
 * @range 4, 300
 */
uniform float u_minLabel;

/**
 * @label Seed
 * @default 1
 * @range 0, 100
 */
uniform float u_seed;

float sat(float x) { return clamp(x, 0.0, 1.0); }

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21) + u_seed * 0.731);
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float lum(vec2 p) {
  vec4 t = texture2D(u_content, p / u_resolution);
  return dot(t.rgb, vec3(0.299, 0.587, 0.114)) + (1.0 - t.a);
}

float lumB(vec2 p) {
  vec2 q = floor(p);
  return 0.25 * (lum(q + vec2(-1.0, -1.0)) + lum(q + vec2(1.0, -1.0))
               + lum(q + vec2(-1.0, 1.0)) + lum(q + vec2(1.0, 1.0)));
}

vec4 edgeAt(vec2 c) {
  float l0 = lumB(c);
  float lx1 = lumB(c + vec2(3.0, 0.0));
  float lx0 = lumB(c - vec2(3.0, 0.0));
  float ly1 = lumB(c + vec2(0.0, 3.0));
  float ly0 = lumB(c - vec2(0.0, 3.0));
  vec2 g = vec2(lx1 - lx0, ly1 - ly0);
  float lnx = abs(l0 - 0.5 * (lx1 + lx0));
  float lny = abs(l0 - 0.5 * (ly1 + ly0));
  return vec4(g, max(length(g), 2.0 * max(lnx, lny)), lnx - lny);
}

vec2 edgeNormal(vec4 e) {
  if (length(e.xy) > 0.5 * e.z) return normalize(e.xy);
  return e.w > 0.0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
}

float density(vec2 c) {
  float n = 0.0;
  for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 5; j++) {
      vec2 q = c + vec2(float(i) - 2.0, float(j) - 2.0) * 4.0;
      float l0 = lum(q);
      float g = abs(lum(q + vec2(1.5, 0.0)) - l0) + abs(lum(q + vec2(0.0, 1.5)) - l0);
      n += smoothstep(0.06, 0.16, g);
    }
  }
  return n / 25.0;
}

float lumWide(vec2 c) {
  float s = 0.0;
  float mx = 0.0;
  float mn = 1.0;
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      float l = lum(floor(c) + vec2(float(i) - 1.0, float(j) - 1.0) * 12.0);
      s += l;
      mx = max(mx, l);
      mn = min(mn, l);
    }
  }
  s /= 9.0;
  return (s - mn > mx - s) ? mx : mn;
}

float inkAt(vec2 q, float bg) {
  return sat((abs(lum(q) - bg) - 0.15) * 3.0);
}

float inkProfile(vec2 q, float bg) {
  float s = 0.0;
  for (int i = 0; i < 5; i++) {
    s += inkAt(q + vec2((float(i) - 2.0) * 6.0, 0.0), bg);
  }
  return s * 0.2;
}

float coverage(vec2 c, float d, float bg) {
  float s = 0.0;
  for (int j = 0; j < 7; j++) {
    float y = c.y + (float(j) - 3.0) * d * 0.5;
    for (int i = 0; i < 3; i++) {
      float x = c.x + (float(i) - 1.0) * d * 0.33;
      s += inkAt(vec2(x, y), bg);
    }
  }
  return s / 21.0;
}

float dotMask(vec2 p, vec2 c, float r) {
  return 1.0 - smoothstep(r - 0.6, r + 0.6, length(p - c));
}

float glyphBits(float g) {
  if (g < 0.5) return 31599.0;
  if (g < 1.5) return 11415.0;
  if (g < 2.5) return 29671.0;
  if (g < 3.5) return 29647.0;
  if (g < 4.5) return 23497.0;
  if (g < 5.5) return 31183.0;
  if (g < 6.5) return 31215.0;
  if (g < 7.5) return 29257.0;
  if (g < 8.5) return 31727.0;
  if (g < 9.5) return 31695.0;
  if (g < 10.5) return 2728.0;
  if (g < 11.5) return 2.0;
  if (g < 12.5) return 1488.0;
  if (g < 13.5) return 11921.0;
  if (g < 14.5) return 14478.0;
  return 0.0;
}

float fontPx(float g, float col, float row) {
  if (col < -0.5 || col > 2.5 || row < -0.5 || row > 4.5) return 0.0;
  float bit = (4.0 - row) * 3.0 + (2.0 - col);
  return mod(floor(glyphBits(g) / floor(exp2(bit) + 0.5)), 2.0);
}

float ndig(float v) {
  if (v >= 999.5) return 4.0;
  if (v >= 99.5) return 3.0;
  if (v >= 9.5) return 2.0;
  return 1.0;
}

float digitAt(float v, float i, float n) {
  float div = floor(pow(10.0, n - 1.0 - i) + 0.5);
  return floor(mod(floor(v + 0.5) / div + 0.0001, 10.0));
}

float labelChar(float i, float w, float h, float secs, float showT) {
  float nw = ndig(w);
  float nh = ndig(h);
  if (i < nw) return digitAt(w, i, nw);
  i -= nw;
  if (i < 1.0) return 15.0;
  i -= 1.0;
  if (i < 1.0) return 10.0;
  i -= 1.0;
  if (i < 1.0) return 15.0;
  i -= 1.0;
  if (i < nh) return digitAt(h, i, nh);
  i -= nh;
  if (showT < 0.5) return -1.0;
  if (i < 1.0) return 15.0;
  i -= 1.0;
  if (i < 1.0) return 13.0;
  i -= 1.0;
  if (i < 1.0) return 12.0;
  i -= 1.0;
  float ip = floor(secs);
  float fp = floor(fract(secs) * 100.0);
  float ni = ndig(ip);
  if (i < ni) return digitAt(ip, i, ni);
  i -= ni;
  if (i < 1.0) return 11.0;
  i -= 1.0;
  if (i < 2.0) return digitAt(fp, i, 2.0);
  i -= 2.0;
  if (i < 1.0) return 14.0;
  return -1.0;
}

float drawLabel(vec2 p, vec2 topLeft, float s, float w, float h, float secs, float showT) {
  float fx = (p.x - topLeft.x) / s;
  float fy = (topLeft.y - p.y) / s;
  if (fx < 0.0 || fy < 0.0 || fy >= 5.0) return 0.0;
  float slot = floor(fx / 4.0);
  float col = floor(fx) - slot * 4.0;
  if (col > 2.5) return 0.0;
  float g = labelChar(slot, w, h, secs, showT);
  if (g < -0.5) return 0.0;
  return fontPx(g, col, floor(fy));
}

float edgeRun(float x, float ye) {
  return abs(lum(vec2(x, ye + 1.5)) - lum(vec2(x, ye - 1.5)));
}

float vEdge(float x, float y) {
  return abs(lum(vec2(x + 1.5, y)) - lum(vec2(x - 1.5, y)));
}

float vEdgeWide(float x, float y) {
  return abs(lum(vec2(x + 3.0, y)) - lum(vec2(x - 3.0, y)));
}

float findLeft(float xs, float y) {
  for (int i = 0; i < 17; i++) {
    float x = xs - 2.0 * float(i);
    if (vEdge(x, y) > u_edge) {
      float b = vEdge(x, y);
      float xb = x;
      for (int j = 1; j < 4; j++) {
        float v = vEdge(x - float(j), y);
        if (v > b) { b = v; xb = x - float(j); }
      }
      return xb;
    }
  }
  return -1.0;
}

float findRight(float xs, float y) {
  for (int i = 0; i < 17; i++) {
    float x = xs + 2.0 * float(i);
    if (vEdge(x, y) > u_edge) {
      float b = vEdge(x, y);
      float xb = x;
      for (int j = 1; j < 4; j++) {
        float v = vEdge(x + float(j), y);
        if (v > b) { b = v; xb = x + float(j); }
      }
      return xb;
    }
  }
  return -1.0;
}

float hEdge(float x, float y) {
  return abs(lum(vec2(x, y + 1.5)) - lum(vec2(x, y - 1.5)));
}

float frameDots(float along, float across, float s0, float pitch, float r, float sweep, float per, float edgeId) {
  if (abs(across) > r + 1.0) return 0.0;
  float k = floor(along / pitch);
  float ac = (k + 0.5) * pitch;
  float sc = s0 + ac - hash21(vec2(k, edgeId)) * u_scatter * 2.0;
  float vis = sat((sweep * per - sc) / (pitch * 2.0));
  return dotMask(vec2(along, across), vec2(ac, 0.0), r) * vis;
}

void main() {
  vec2 p = gl_FragCoord.xy;
  float W = u_resolution.x;
  float H = u_resolution.y;

  float prog = u_progress;
  if (u_play > 0.5) {
    float tt = max(u_time - u_delay, 0.0);
    if (u_loop > 0.5) tt = mod(tt, u_duration + u_hold);
    prog = sat(tt / u_duration);
  }
  float tGrid = sat(prog / 0.12);
  float tOuter = sat((prog - 0.04) / 0.30);
  tOuter = 1.0 - (1.0 - tOuter) * (1.0 - tOuter);
  float tHand = sat((prog - 0.30) / 0.06);
  float tInner = sat((prog - 0.26) / 0.66);
  float tRev = sat((prog - 0.92) / 0.08) * u_reveal;
  float secs = prog * u_duration;

  float ink = 0.0;

  vec2 gn = floor(p / u_gridPitch + 0.5) * u_gridPitch;
  float gvis = sat((tGrid - hash21(gn * 0.37)) * 4.0);
  ink = max(ink, dotMask(p, gn, u_gridSize * 0.5) * u_gridAlpha * gvis);

  float d = max(2.0, floor(u_dotPitch * 0.5 + 0.01) * 2.0);
  vec2 c = (floor(p / d) + 0.5) * d;
  float yF = (H + u_scatter + 4.0) - tInner * (H + 2.0 * u_scatter + 8.0);
  float jit = hash21(c) * u_scatter;
  float cvis = sat((c.y + jit - yF) / 8.0);

  if (cvis > 0.001) {
    vec4 e = edgeAt(c);
    float dens = density(c);
    float textW = smoothstep(u_density - 0.06, u_density + 0.04, dens);
    float lineFound = 0.0;
    float centre = 99.0;
    float bg = 0.0;
    float p0 = 0.0;
    if (dens > 0.1) {
      bg = lumWide(c);
      p0 = inkProfile(c, bg);
      if (p0 > 0.08) {
        float top = 0.0;
        float bot = 0.0;
        bool up = true;
        bool dn = true;
        for (int j = 1; j <= 12; j++) {
          if (!up && !dn) break;
          float dy = float(j) * 2.0;
          if (up) { if (inkProfile(c + vec2(0.0, dy), bg) > 0.08) top = dy; else up = false; }
          if (dn) { if (inkProfile(c - vec2(0.0, dy), bg) > 0.08) bot = dy; else dn = false; }
        }
        if (top < 23.0 && bot < 23.0) {
          lineFound = 1.0;
          centre = (top - bot) * 0.5;
        }
      }
    }
    float shapeAmt = 0.0;
    if (e.z > u_edge * 0.7 && textW < 0.999 && lineFound < 0.5) {
      vec2 n = edgeNormal(e);
      vec2 t = vec2(-n.y, n.x);

      if (e.z >= edgeAt(c + n * d).z && e.z > edgeAt(c - n * d).z) {
        vec4 t1 = edgeAt(c + t * d);
        vec4 t2 = edgeAt(c - t * d);
        float a1 = abs(dot(edgeNormal(t1), n));
        float a2 = abs(dot(edgeNormal(t2), n));
        float c1 = smoothstep(u_edge * 0.4, u_edge * 0.7, t1.z) * smoothstep(0.5, 0.75, a1);
        float c2 = smoothstep(u_edge * 0.4, u_edge * 0.7, t2.z) * smoothstep(0.5, 0.75, a2);
        float cons = max(min(c1, c2), 0.6 * max(c1, c2));
        shapeAmt = smoothstep(u_edge * 0.7, u_edge * 1.4, e.z) * cons * (1.0 - textW);
      }
    }
    float textAmt = 0.0;
    float textR = 0.0;
    if (textW > 0.001 && u_textDot > 0.01 && lineFound > 0.5 && centre > -d * 0.5 && centre <= d * 0.5) {
      float cv = coverage(c, d, bg);
      textAmt = smoothstep(u_textLevel * 0.3, u_textLevel, max(cv, p0 * 0.5)) * textW;
      textR = u_textDot * 0.5 * (0.45 + 0.55 * sat(cv / 0.4));
    }
    float inner = max(dotMask(p, c, u_dotSize * 0.5) * shapeAmt, dotMask(p, c, textR) * textAmt);
    ink = max(ink, inner * cvis);
  }

  if (u_labels > 0.5 && tInner > 0.001) {
    float s = max(1.0, floor(u_labelScale + 0.5));
    float cx0 = floor(p.x / 8.0) * 8.0 + 4.0;
    float cx = cx0;
    float best = 0.0;
    float kb = 99.0;
    for (int i = 0; i < 10; i++) {
      float x = cx0 - 8.0 * float(i);
      if (x < 0.0) break;
      float lP2 = lum(vec2(x, p.y - 2.0));
      float lP1 = lum(vec2(x, p.y - 3.0));
      float b = 0.0;
      float kk = 0.0;

      float kc = min(kb, 3.0 + 5.0 * s);
      for (int k = 4; k < 20; k++) {
        if (float(k) > kc && b <= u_edge) break;
        float lk = lum(vec2(x, p.y - float(k)));
        float dk = abs(lk - lP2);
        if (dk > b) { b = dk; kk = float(k) - 1.0; }
        lP2 = lP1;
        lP1 = lk;
      }
      if (b > u_edge && kk < kb) { best = b; kb = kk; cx = x; }
      if (kb < 3.5) break;
    }
    float ye = p.y - kb;
    float row = (p.y - ye - 3.0) / s;
    if (best > u_edge && row >= 0.0 && row < 5.0 && edgeRun(cx, ye) > u_edge) {
      float xl = cx;
      for (int i = 1; i < 14; i++) {
        float x = cx - 8.0 * float(i);
        if (edgeRun(x, ye) < u_edge) break;
        xl = x;
      }
      float xr = cx;
      for (int i = 1; i < 60; i++) {
        float x = cx + 8.0 * float(i);
        if (edgeRun(x, ye) < u_edge) break;
        xr = x;
      }
      float yv = ye - 20.0;
      float x0 = findLeft(xl + 2.0, yv);
      float x1 = findRight(xr - 2.0, yv);
      float ok = (x0 >= 0.0 && x1 >= 0.0 && x1 > x0 + 4.0) ? 1.0 : 0.0;
      float yEnd = ye;
      if (ok > 0.5) {
        for (int i = 3; i < 64; i++) {
          float y = ye - 8.0 * float(i);
          if (vEdgeWide(x0, y) < u_edge) break;
          yEnd = y;
        }
      }
      float xp = x0 + min(40.0, (x1 - x0) * 0.4);
      float yb = yEnd;
      float bh = 0.0;
      for (int i = 0; i < 22; i++) {
        float y = yEnd + 2.0 - 2.0 * float(i);
        float v = hEdge(xp, y);
        if (v > u_edge) { bh = v; yb = y; break; }
      }
      if (ok > 0.5 && bh > u_edge) {
        for (int j = 1; j < 3; j++) {
          float v = hEdge(xp, yb - float(j));
          if (v > bh) { bh = v; yb = yb - float(j); }
        }
      }
      float hei = ye - yb;
      if (ok > 0.5 && bh > u_edge && hei >= 8.0) {
        float ym = ye - hei * 0.5;
        float x0m = findLeft(x0 + 2.0, ym);
        float x1m = findRight(x1 - 2.0, ym);
        if (x0m >= 0.0) x0 = x0m;
        if (x1m >= 0.0) x1 = x1m;
        float wid = x1 - x0;
        float xq = x1 - min(40.0, wid * 0.4);
        float closed = (hEdge(xq, yb) > u_edge * 0.8 && hEdge(xq, ye) > u_edge * 0.8) ? 1.0 : 0.0;
        if (closed > 0.5 && wid >= u_minLabel && hei >= u_minLabel) {
          float lvis = sat((ye - yF) / 10.0);
          float lab = drawLabel(p, vec2(xl - 3.0, ye + 3.0 + 5.0 * s), s, wid, hei, 0.0, 0.0);
          ink = max(ink, lab * u_labelAlpha * lvis);
        }
      }
    }
  }

  float r = u_dotSize * 0.5;
  float inset = max(r + 0.5, 1.0);
  if (u_frame > 0.5) {
    float per = 2.0 * (W + H);
    float fd = frameDots(p.x, p.y - (H - inset), 0.0, d, r, tOuter, per, 1.0);
    fd = max(fd, frameDots(H - p.y, p.x - (W - inset), W, d, r, tOuter, per, 2.0));
    fd = max(fd, frameDots(W - p.x, p.y - inset, W + H, d, r, tOuter, per, 3.0));
    fd = max(fd, frameDots(p.y, p.x - inset, 2.0 * W + H, d, r, tOuter, per, 4.0));
    ink = max(ink, fd);
  }

  float hs = u_handle;
  if (hs > 0.5 && tHand > 0.001) {
    float hh = hs * 0.5 * (0.6 + 0.4 * tHand);
    float ci = hs * 0.5 + 1.0;
    vec2 q = min(p, u_resolution - p);
    q = abs(q - vec2(ci));
    float m = max(q.x, q.y);
    float box = 1.0 - smoothstep(hh - 0.5, hh + 0.5, m);
    float ring = box * smoothstep(hh - 1.6, hh - 0.6, m);
    ink = max(ink * (1.0 - box * tHand), ring * tHand);
  }
  {
    float s = max(1.0, floor(u_labelScale + 0.5));
    float lab = drawLabel(p, vec2(hs + 8.0, H - 5.0), s, W, H, secs, u_timer);
    ink = max(ink, lab * u_labelAlpha * tHand);
  }

  vec4 content = texture2D(u_content, p / u_resolution);
  vec4 base = vec4(u_paper.rgb * u_paper.a, u_paper.a);
  vec4 contentOverPaper = content + base * (1.0 - content.a);
  base = mix(base, contentOverPaper, tRev);
  vec3 rgb = base.rgb * (1.0 - ink) + u_ink * ink;
  float a = base.a + ink * (1.0 - base.a);
  gl_FragColor = vec4(rgb, a);
}
