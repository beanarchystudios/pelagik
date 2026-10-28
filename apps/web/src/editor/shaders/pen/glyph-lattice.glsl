precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @content */
uniform sampler2D u_content;

/**
 * @label Cells
 * @default 80
 * @range 16, 200
 */
uniform float u_cells;

/**
 * @label Black
 * @default 0.06
 * @range 0, 0.8
 */
uniform float u_black;

/**
 * @label White
 * @default 1
 * @range 0.2, 1
 */
uniform float u_white;

/**
 * @label Dither
 * @default 0.6
 * @range 0, 1
 */
uniform float u_dither;

/**
 * @label Edges
 * @default 0.5
 * @range 0, 1
 */
uniform float u_edges;

/**
 * @label Weight
 * @default 0.12
 * @range 0.04, 0.3
 */
uniform float u_weight;

/**
 * @label Floor
 * @default 0.35
 * @range 0, 1
 */
uniform float u_floor;

/**
 * @label Flicker
 * @default 0.2
 * @range 0, 1
 */
uniform float u_flicker;

/**
 * @label Ink
 * @color
 * @default #ededed
 */
uniform vec3 u_ink;

/**
 * @label Paper
 * @color
 * @default #00000000
 */
uniform vec4 u_paper;

float h12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float bayer2(vec2 a) {
  a = floor(a);
  return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
  return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float tap(vec2 px) {
  vec2 uv = px / u_resolution;
  vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
  vec3 c = texture2D(u_content, clamp(uv, 0.0, 1.0)).rgb;
  return dot(c, vec3(0.299, 0.587, 0.114)) * inside.x * inside.y;
}

float cellL(vec2 id, vec2 cs) {
  vec2 c = (id + 0.5) * cs;
  float s = tap(c + cs * vec2(-0.375, -0.125));
  s += tap(c + cs * vec2(0.125, -0.375));
  s += tap(c + cs * vec2(0.375, 0.125));
  s += tap(c + cs * vec2(-0.125, 0.375));
  return clamp((s * 0.25 - u_black) / max(u_white - u_black, 0.01), 0.0, 1.0);
}

vec3 sobel(float a00, float a10, float a20, float a01, float a11, float a21,
           float a02, float a12, float a22) {
  float gx = (a20 + 2.0 * a21 + a22) - (a00 + 2.0 * a01 + a02);
  float gy = (a02 + 2.0 * a12 + a22) - (a00 + 2.0 * a10 + a20);
  return vec3(gx, gy, a11);
}

float seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

float glyphD(float level, vec2 u) {
  float diag = min(abs(u.x - u.y), abs(u.x + u.y)) * 0.7071;
  float ring = abs(length(u) - 0.6);
  if (level < 0.5) return length(u) - 0.14;
  if (level < 1.5) return length(u) - 0.24;
  if (level < 2.5) return min(seg(u, vec2(-0.45), vec2(0.45)), seg(u, vec2(-0.45, 0.45), vec2(0.45, -0.45)));
  if (level < 3.5) return ring;
  if (level < 4.5) return diag;
  if (level < 5.5) return min(diag, ring);
  float box = abs(max(abs(u.x), abs(u.y)) - 0.8);
  return min(diag, box);
}

float edgeD(float dir, vec2 u) {
  if (dir < 0.5) return abs(u.x);
  if (dir < 1.5) return abs(u.y);
  if (dir < 2.5) return abs(u.x - u.y) * 0.7071;
  return abs(u.x + u.y) * 0.7071;
}

void main() {
  vec2 px = gl_FragCoord.xy;
  vec2 res = u_resolution;

  float cols = max(floor(u_cells + 0.5), 4.0);
  float rows = max(floor(res.y / (res.x / cols) + 0.5), 1.0);
  vec2 cs = res / vec2(cols, rows);
  vec2 cellId = floor(px / cs);

  vec2 bc = floor((floor(px * 0.5) * 2.0 + 0.5) / cs);
  float l00 = cellL(bc + vec2(-1.0, -1.0), cs);
  float l10 = cellL(bc + vec2(0.0, -1.0), cs);
  float l20 = cellL(bc + vec2(1.0, -1.0), cs);
  float l30 = cellL(bc + vec2(2.0, -1.0), cs);
  float l01 = cellL(bc + vec2(-1.0, 0.0), cs);
  float l11 = cellL(bc, cs);
  float l21 = cellL(bc + vec2(1.0, 0.0), cs);
  float l31 = cellL(bc + vec2(2.0, 0.0), cs);
  float l02 = cellL(bc + vec2(-1.0, 1.0), cs);
  float l12 = cellL(bc + vec2(0.0, 1.0), cs);
  float l22 = cellL(bc + vec2(1.0, 1.0), cs);
  float l32 = cellL(bc + vec2(2.0, 1.0), cs);
  float l03 = cellL(bc + vec2(-1.0, 2.0), cs);
  float l13 = cellL(bc + vec2(0.0, 2.0), cs);
  float l23 = cellL(bc + vec2(1.0, 2.0), cs);
  float l33 = cellL(bc + vec2(2.0, 2.0), cs);
  vec3 s00 = sobel(l00, l10, l20, l01, l11, l21, l02, l12, l22);
  vec3 s10 = sobel(l10, l20, l30, l11, l21, l31, l12, l22, l32);
  vec3 s01 = sobel(l01, l11, l21, l02, l12, l22, l03, l13, l23);
  vec3 s11 = sobel(l11, l21, l31, l12, l22, l32, l13, l23, l33);
  vec2 pick = clamp(cellId - bc, 0.0, 1.0);
  vec3 s = mix(mix(s00, s10, pick.x), mix(s01, s11, pick.x), pick.y);
  float lum = s.z;

  float level = floor(lum * 6.0 + 0.5 + (bayer4(cellId) - 0.47) * u_dither);
  level = clamp(level, 0.0, 6.0);

  float st = floor(u_time * 10.0);
  float fh = h12(cellId * 1.17 + vec2(st * 0.371, st * 1.913));
  float jump = step(fh, u_flicker * 0.12) * step(0.5, level);
  level = clamp(level + jump * (fh < u_flicker * 0.06 ? 1.0 : -1.0), 0.0, 6.0);

  float g = length(s.xy) * 0.25;
  float isEdge = step(0.5, level) * step(1.0 - u_edges * 0.85, g) * step(0.01, u_edges);
  float ang = atan(s.y, s.x) + 1.5708;
  float a = mod(ang + 0.3927, 3.1416);
  float dir = a < 0.7854 ? 1.0 : a < 1.5708 ? 2.0 : a < 2.3562 ? 0.0 : 3.0;

  float half_ = 0.5 * min(cs.x, cs.y);
  vec2 u = (px - (cellId + 0.5) * cs) / half_;
  float d = isEdge > 0.5 ? edgeD(dir, u) : glyphD(level, u);
  float hw = max(u_weight * half_, 0.45);
  float dotGlyph = step(level, 1.5) * (1.0 - isEdge);
  float cov = clamp(hw * (1.0 - dotGlyph) + 0.5 - d * half_, 0.0, 1.0);

  float tone = max(lum, isEdge * min(g, 1.0));
  float bright = mix(0.3, 1.0, pow(tone, 1.4)) * (0.9 + 0.2 * h12(cellId + 0.37));
  bright = level < 0.5 ? u_floor * 0.7 : bright;

  vec4 paper = vec4(u_paper.rgb * u_paper.a, u_paper.a);
  vec3 stroke = mix(paper.rgb, u_ink, clamp(bright, 0.0, 1.0));
  vec4 col = mix(paper, vec4(stroke, 1.0), cov);

  vec2 inNode = step(vec2(0.0), px) * step(px, res);
  gl_FragColor = col * inNode.x * inNode.y;
}
