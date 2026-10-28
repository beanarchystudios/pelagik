precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @content */
uniform sampler2D u_content;

/** @label Text Map */
uniform sampler2D u_text;

/** @label Glyph Atlas */
uniform sampler2D u_atlas;

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
 * @default 6
 * @range 0.5, 60
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
 * @default 2
 * @range 0, 20
 */
uniform float u_hold;

/**
 * @label Loop
 * @default 1
 * @range 0, 1
 */
uniform float u_loop;

/**
 * @label Fade
 * @default 0.01
 * @range 0, 0.1
 */
uniform float u_fade;

/**
 * @label Scale
 * @default 1
 * @range 0.5, 3
 */
uniform float u_scale;

/**
 * @label Line Height
 * @default 20
 * @range 12, 32
 */
uniform float u_lineH;

/**
 * @label Padding
 * @default 12
 * @range 0, 120
 */
uniform float u_padding;

/**
 * @label Cursor
 * @default 1
 * @range 0, 1
 */
uniform float u_cursor;

/**
 * @label Bar Time
 * @default 0.12
 * @range 0.01, 0.5
 */
uniform float u_barTime;

/**
 * @label Land At
 * @default 1.0
 * @range 0.3, 1
 */
uniform float u_land;

/**
 * @label Seed
 * @default 1
 * @range 0, 100
 */
uniform float u_seed;

/**
 * @label Jitter
 * @default 0.02
 * @range 0, 0.2
 */
uniform float u_jitter;

/**
 * @label Paper
 * @color
 * @default #FFFFFF00
 */
uniform vec4 u_paper;

/**
 * @label Ink
 * @color
 * @default #2B2B2B
 */
uniform vec3 u_ink;

/**
 * @label Dim
 * @color
 * @default #A0A0A0
 */
uniform vec3 u_dim;

/**
 * @label Keyword
 * @color
 * @default #1F1F1F
 */
uniform vec3 u_key;

/**
 * @label String
 * @color
 * @default #8A6D3B
 */
uniform vec3 u_str;

/**
 * @label Number
 * @color
 * @default #7A7A7A
 */
uniform vec3 u_num;

/**
 * @label Accent
 * @color
 * @default #2B7A4B
 */
uniform vec3 u_acc;

/**
 * @label Bad
 * @color
 * @default #C0392B
 */
uniform vec3 u_bad;

/**
 * @label Header
 * @color
 * @default #2B2B2B
 */
uniform vec3 u_head;

const float ROWS = 734.0;
const float COLS = 96.0;
const float HEADER = 2.0;
const float TIER1 = 226.0;
const float TIER2 = 467.0;
const float WIDE1 = 60.0;
const float WIDE2 = 90.0;
const float MAP_W = 1920.0;

float sat(float x) { return clamp(x, 0.0, 1.0); }

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float bitAt(float col, float row, float b) {
  vec2 uv = vec2((col * 20.0 + b + 0.5) / MAP_W, 1.0 - (row + 0.5) / ROWS);
  return step(0.5, texture2D(u_text, uv).r);
}

vec4 cellAt(float col, float row) {
  float code = 0.0;
  float cls = 0.0;
  float t = 0.0;
  for (int b = 0; b < 7; b++) {
    code += bitAt(col, row, float(b)) * floor(exp2(float(b)) + 0.5);
  }
  for (int b = 0; b < 4; b++) {
    cls += bitAt(col, row, 7.0 + float(b)) * floor(exp2(float(b)) + 0.5);
  }
  for (int b = 0; b < 8; b++) {
    t += bitAt(col, row, 12.0 + float(b)) * floor(exp2(float(b)) + 0.5);
  }
  return vec4(code, cls, t / 255.0, bitAt(col, row, 11.0));
}

float timeAt(float g) {
  float row = floor(g / COLS);
  float col = g - row * COLS;
  float t = 0.0;
  for (int b = 0; b < 8; b++) {
    t += bitAt(col, row, 12.0 + float(b)) * floor(exp2(float(b)) + 0.5);
  }
  return t / 255.0;
}

float rowSpan(float r, float cols) {
  if (cols >= COLS) return 1.0;
  vec4 last = cellAt(COLS - 1.0, r);
  float len = (last.y > 11.5 && last.y < 12.5) ? last.x : COLS;
  return max(ceil(len / cols), 1.0);
}

float glyphTap(vec2 a) {
  return texture2D(u_atlas, vec2(a.x / 256.0, 1.0 - a.y / 288.0)).r;
}

float glyph(float code, vec2 g, float sc) {
  if (g.x < 0.0 || g.x >= 8.0 || g.y < 0.0 || g.y >= 18.0) return 0.0;
  float cx = mod(code, 16.0);
  float cy = floor(code / 16.0);
  vec2 a = vec2(cx * 16.0 + g.x * 2.0, cy * 36.0 + g.y * 2.0);
  float o = max(0.5 / sc - 0.5, 0.0);
  if (o < 0.05) return glyphTap(a);
  return 0.25 * (glyphTap(a + vec2(-o, -o)) + glyphTap(a + vec2(o, -o)) + glyphTap(a + vec2(-o, o)) + glyphTap(a + vec2(o, o)));
}

vec3 classColor(float cls) {
  if (cls < 0.5) return u_ink;
  if (cls < 1.5) return u_dim;
  if (cls < 2.5) return u_key;
  if (cls < 3.5) return u_str;
  if (cls < 4.5) return u_num;
  if (cls < 5.5) return u_acc;
  if (cls < 6.5) return u_bad;
  return u_head;
}

float digitCode(float n, float place) {
  float d = floor(mod(floor(n / place + 0.0001), 10.0));
  return 48.0 + d;
}

void main() {
  vec2 p = gl_FragCoord.xy;
  float W = u_resolution.x;
  float H = u_resolution.y;

  float prog = u_progress;
  float run = 0.0;
  if (u_play > 0.5) {
    float tt = max(u_time - u_delay, 0.0);
    float cyc = u_duration + u_hold;
    if (u_loop > 0.5) { run = floor(tt / cyc); tt = mod(tt, cyc); }
    prog = sat(tt / u_duration);
  }
  float seed = u_seed + run * 7.0;
  float secs = prog * u_duration;

  float pad = u_padding;
  float sc = max(u_scale, 0.25);
  float cw = 8.0 * sc;
  float cols = max(floor(max(W - 2.0 * pad, 8.0) / cw), 4.0);
  float lhRaw = max(u_lineH, 10.0) * sc;
  float visRows = max(floor((H - 2.0 * pad) / lhRaw), HEADER + 1.0);
  float lh = (H - 2.0 * pad) / visRows;
  float bodyDisp = visRows - HEADER;

  float tierStart = cols >= WIDE2 ? TIER2 : (cols >= WIDE1 ? TIER1 : 0.0);
  float tierEnd = cols >= WIDE2 ? ROWS : (cols >= WIDE1 ? TIER2 : TIER1);
  float bodyStart = tierStart + HEADER;
  float maxStart = max(tierEnd - bodyDisp, bodyStart);
  float r0 = bodyStart + floor(hash21(vec2(seed, 3.1)) * (maxStart - bodyStart + 0.999));
  r0 = min(r0, maxStart);
  float rb = -1.0;
  for (int i = 0; i < 16; i++) {
    float cand = r0 + float(i);
    if (cand > maxStart) break;
    if (bitAt(0.0, cand, 11.0) > 0.5) { rb = cand; break; }
  }
  if (rb < 0.0) {
    for (int i = 1; i < 24; i++) {
      float cand = r0 - float(i);
      if (cand < bodyStart) break;
      if (bitAt(0.0, cand, 11.0) > 0.5) { rb = cand; break; }
    }
  }
  if (rb >= 0.0) r0 = rb;

  float x = p.x - pad;
  float yT = (H - pad) - p.y;
  float dRow = floor(yT / lh);
  float dCol = floor(x / cw);

  float rEnd = r0;
  float pixRow = -1.0;
  float pixSeg = 0.0;
  float acc = 0.0;
  float nLast = 1.0;
  for (int i = 0; i < 160; i++) {
    float r = r0 + float(i);
    if (r >= tierEnd || acc >= bodyDisp) break;
    float n = rowSpan(r, cols);
    if (dRow >= HEADER && pixRow < 0.0 && dRow - HEADER >= acc && dRow - HEADER < acc + n) {
      pixRow = r;
      pixSeg = dRow - HEADER - acc;
    }
    rEnd = r;
    nLast = n;
    acc += n;
  }

  float gStart = r0 * COLS;
  float gEnd = rEnd * COLS + COLS - 1.0;
  float tStart = timeAt(gStart);
  float tEnd = timeAt(gEnd);
  float pe = tStart + (prog / max(u_land, 0.3)) * (tEnd - tStart) + (prog >= 1.0 ? 0.01 : 0.0);

  float lo = gStart;
  float hi = gEnd;
  for (int i = 0; i < 14; i++) {
    if (hi <= lo) break;
    float mid = floor((lo + hi + 1.0) * 0.5);
    if (timeAt(mid) <= pe) lo = mid; else hi = mid - 1.0;
  }
  float curRow = floor(lo / COLS);
  float curCol = lo - curRow * COLS;
  vec4 curCell = cellAt(curCol, curRow);
  if (curCell.y > 11.5 && curCell.y < 12.5) curCol = curCell.x; else curCol = min(curCol + 1.0, COLS - 1.0);
  if (prog <= 0.0) { curRow = r0; curCol = 0.0; }
  float revealed = pe >= tEnd ? (rEnd - r0 + 1.0) : (curRow - r0 + 1.0);

  float curDisp = HEADER;
  if (curRow >= rEnd) {

    curDisp = HEADER + acc - nLast + floor(curCol / cols);
  } else {
    acc = 0.0;
    for (int i = 0; i < 160; i++) {
      float r = r0 + float(i);
      if (r > curRow || r >= tierEnd) break;
      if (r == curRow) { curDisp = HEADER + acc + floor(curCol / cols); break; }
      acc += rowSpan(r, cols);
    }
  }
  float curDispCol = curCol - floor(curCol / cols) * cols;

  vec4 base = texture2D(u_content, p / u_resolution);
  vec4 paper = vec4(u_paper.rgb * u_paper.a, u_paper.a);
  base = paper + base * (1.0 - paper.a);

  float inkA = 0.0;
  vec3 inkC = u_ink;
  if (x >= 0.0 && yT >= 0.0 && x < W - 2.0 * pad && yT < H - 2.0 * pad && dCol < cols) {
    float r = dRow;
    float row = r < HEADER ? tierStart + r : pixRow;
    float c = r < HEADER ? dCol : pixSeg * cols + dCol;
    if (row >= 0.0 && row < ROWS && c < COLS) {
      vec4 cell = cellAt(c, row);
      float code = cell.x;
      float cls = cell.y;
      float t = cell.z;
      if (r >= HEADER) t += (hash21(vec2(row, seed + 1.7)) - 0.5) * u_jitter * (tEnd - tStart);
      if (r < HEADER) t = 0.0;
      vec2 g = vec2((x - dCol * cw) / sc, (yT - r * lh) / sc);
      float a = smoothstep(t, t + max(u_fade, 0.0005) * (tEnd - tStart), pe);
      if (cls > 11.5 && cls < 12.5) a = 0.0;
      if (cls > 8.5 && cls < 9.5) {
        float fill = (pe - t) / max(u_barTime * (tEnd - tStart), 0.001);
        if (fill >= 1.3) {
          code = code < 1.5 ? 32.0 : (code < 2.5 ? 111.0 : (code < 3.5 ? 107.0 : 32.0));
          inkC = u_acc;
        } else {
          code = code < fill * 6.0 ? 35.0 : 46.0;
          inkC = code > 40.0 ? u_dim : u_ink;
        }
      } else if (cls > 9.5 && cls < 10.5) {
        float shown = rEnd - r0 + 1.0;
        if (code < 1.5) code = digitCode(revealed, 10.0);
        else if (code < 2.5) code = digitCode(revealed, 1.0);
        else if (code < 3.5) code = digitCode(shown, 10.0);
        else if (code < 4.5) code = digitCode(shown, 1.0);
        else if (code < 5.5) code = digitCode(secs, 10.0);
        else code = digitCode(secs, 1.0);
        inkC = u_head;
      } else if (cls > 10.5 && cls < 11.5) {
        code = 48.0 + floor(hash21(vec2(c + row * 0.37, seed + 9.2)) * 9.999);
        inkC = u_num;
      } else if (cls > 12.5 && cls < 13.5) {
        float v = floor(hash21(vec2(c * 1.3 + row * 0.11, seed + 5.6)) * 15.999);
        code = v < 9.5 ? 48.0 + v : 87.0 + v;
        inkC = u_dim;
      } else {
        inkC = classColor(cls);
      }
      inkA = glyph(code, g, sc) * a;
    }
    if (u_cursor > 0.5 && prog > 0.0) {
      float typing = (prog < 1.0) ? 1.0 : step(fract(u_time * 1.4), 0.55);
      if (dRow == curDisp && dCol == curDispCol && typing > 0.5) {
        float gy = (yT - dRow * lh) / sc;
        if (gy >= 1.0 && gy < 17.0) {
          inkA = max(inkA, 0.75);
          inkC = u_ink;
        }
      }
    }
  }

  vec3 rgb = base.rgb * (1.0 - inkA) + inkC * inkA;
  float alpha = base.a + inkA * (1.0 - base.a);
  gl_FragColor = vec4(rgb, alpha);
}
