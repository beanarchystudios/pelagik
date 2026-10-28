precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Rows
 * @default 90
 * @range 30, 240
 */
uniform float u_rows;

/**
 * @label Speed
 * @default 1
 * @range 0, 3
 */
uniform float u_speed;

/**
 * @label Density
 * @default 0.6
 * @range 0, 1
 */
uniform float u_density;

/**
 * @label Edges
 * @default 0.75
 * @range 0, 1
 */
uniform float u_edges;

/**
 * @label Echo
 * @default 0.5
 * @range 0, 1
 */
uniform float u_echo;

/**
 * @label Floor
 * @default 0.4
 * @range 0, 1
 */
uniform float u_floor;

/**
 * @label Glow
 * @default 0.5
 * @range 0, 1.5
 */
uniform float u_glow;

/**
 * @label Tolerance
 * @default 0.08
 * @range 0, 0.6
 */
uniform float u_tol;

/**
 * @label Key
 * @color
 * @default #000000
 */
uniform vec3 u_key;

/**
 * @label Red
 * @color
 * @default #e8303f
 */
uniform vec3 u_red;

/**
 * @label Blue
 * @color
 * @default #2f8ad8
 */
uniform vec3 u_blue;

/**
 * @label Lilac
 * @color
 * @default #c7b0f0
 */
uniform vec3 u_lilac;

/**
 * @label Violet
 * @color
 * @default #9a78cc
 */
uniform vec3 u_violet;

float h12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = h12(i);
  float b = h12(i + vec2(1.0, 0.0));
  float c = h12(i + vec2(0.0, 1.0));
  float d = h12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 tap(vec2 px) {
  vec2 uv = px / u_resolution;
  vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
  vec3 c = texture2D(u_backdrop, clamp(uv, 0.0, 1.0)).rgb;
  return mix(u_key, c, inside.x * inside.y);
}

vec2 keyLum(vec3 c) {
  float k = smoothstep(u_tol, u_tol + 0.12, length(c - u_key));
  return vec2(k, dot(c, vec3(0.299, 0.587, 0.114)));
}

vec2 cellKL(vec2 id, float cs) {
  vec2 c = (id + 0.5) * cs;
  vec3 s = tap(c + cs * vec2(-0.375, -0.125));
  s += tap(c + cs * vec2(0.125, -0.375));
  s += tap(c + cs * vec2(0.375, 0.125));
  s += tap(c + cs * vec2(-0.125, 0.375));
  return keyLum(s * 0.25);
}

float ringK(vec2 id, float cs) {
  vec2 c = (id + 0.5) * cs;
  float r = 5.0 * cs;
  float s = 0.0;
  for (int i = 0; i < 6; i++) {
    float a = float(i) * 1.0472 + 0.3;
    s += keyLum(tap(c + vec2(cos(a), sin(a)) * r)).x;
  }
  return s / 6.0;
}

vec4 cellInfo(vec2 c, vec2 l, vec2 r, vec2 d, vec2 u, float ring) {
  vec2 gL = vec2(r.y - l.y, u.y - d.y) * 0.5;
  float lap = c.y - 0.25 * (l.y + r.y + d.y + u.y);
  vec2 gK = vec2(r.x - l.x, u.x - d.x) * 0.5;
  float inner = max(max(c.x, l.x), max(max(r.x, d.x), u.x));
  float eL = (length(gL) * 5.0 + abs(lap) * 6.0) * inner;
  float eK = length(gK) * 1.6;

  float rim = c.x * (1.0 - smoothstep(0.55, 0.97, ring));
  float edge = clamp(max(max(eL, eK), rim), 0.0, 1.0);
  float sil = max(c.x, smoothstep(0.45, 0.65, ring));
  return vec4(edge, c.x, c.y, sil);
}

vec2 letterRows(float id) {
  if (id < 0.5) return vec2(1032734.0, 16927.0);
  if (id < 1.5) return vec2(575285.0, 20017.0);
  if (id < 2.5) return vec2(585397.0, 17969.0);
  return vec2(476695.0, 17967.0);
}

float pow2(float n) {
  return floor(exp2(n) + 0.5);
}

float bitAt(vec2 rows, vec2 b) {
  if (b.x < 0.0 || b.x > 4.0 || b.y < 0.0 || b.y > 6.0) return 0.0;
  float row = b.y < 3.5
    ? mod(floor(rows.x / pow2(5.0 * (3.0 - b.y))), 32.0)
    : mod(floor(rows.y / pow2(5.0 * (6.0 - b.y))), 32.0);
  return mod(floor(row / pow2(4.0 - b.x)), 2.0);
}

void main() {
  vec2 px = gl_FragCoord.xy;
  vec2 res = u_resolution;
  float t = u_time;
  float cs = res.y / max(u_rows, 4.0);
  vec2 cellId = floor(px / cs);

  vec2 bc = floor((floor(px * 0.5) * 2.0 + 0.5) / cs);
  vec2 n0 = cellKL(bc + vec2(0.0, -1.0), cs);
  vec2 n1 = cellKL(bc + vec2(1.0, -1.0), cs);
  vec2 n2 = cellKL(bc + vec2(-1.0, 0.0), cs);
  vec2 n3 = cellKL(bc, cs);
  vec2 n4 = cellKL(bc + vec2(1.0, 0.0), cs);
  vec2 n5 = cellKL(bc + vec2(2.0, 0.0), cs);
  vec2 n6 = cellKL(bc + vec2(-1.0, 1.0), cs);
  vec2 n7 = cellKL(bc + vec2(0.0, 1.0), cs);
  vec2 n8 = cellKL(bc + vec2(1.0, 1.0), cs);
  vec2 n9 = cellKL(bc + vec2(2.0, 1.0), cs);
  vec2 n10 = cellKL(bc + vec2(0.0, 2.0), cs);
  vec2 n11 = cellKL(bc + vec2(1.0, 2.0), cs);
  vec4 i00 = cellInfo(n3, n2, n4, n0, n7, ringK(bc, cs));
  vec4 i10 = cellInfo(n4, n3, n5, n1, n8, ringK(bc + vec2(1.0, 0.0), cs));
  vec4 i01 = cellInfo(n7, n6, n8, n3, n10, ringK(bc + vec2(0.0, 1.0), cs));
  vec4 i11 = cellInfo(n8, n7, n9, n4, n11, ringK(bc + vec2(1.0, 1.0), cs));
  vec2 pick = clamp(cellId - bc, 0.0, 1.0);
  vec4 info = mix(mix(i00, i10, pick.x), mix(i01, i11, pick.x), pick.y);
  float edge = info.x;
  float subj = info.y;
  float lum = info.z;
  float sil = info.w;

  vec2 hc = h22(vec2(cellId.x, 7.0));
  float runLen = floor(mix(3.0, 15.0, hc.y));
  float s = cellId.y + t * u_speed * mix(1.5, 6.0, hc.x) + hc.x * 913.0;
  float k = floor(s / runLen);
  float ru = fract(s / runLen);
  vec2 hr = h22(vec2(cellId.x * 1.37, k));
  float run = step(hr.x, 0.55) * pow(1.0 - ru, 1.3);

  float fill = subj * (0.1 + 0.5 * lum);
  float energy = mix(fill, edge, u_edges);
  energy *= mix(1.0, 0.35 + 1.4 * run, u_echo);

  vec2 hl = h22(cellId + 0.37);
  float ph = t * u_speed * mix(0.6, 1.4, hl.x) + hl.y;
  float cyc = floor(ph);
  float age = fract(ph);
  float thr = h12(cellId * 1.13 + cyc * 17.7);
  float lit = step(thr, energy * u_density * 2.0);
  float env = smoothstep(0.0, 0.04, age) * mix(1.0, 0.45, smoothstep(0.7, 0.8, age)) * (1.0 - smoothstep(0.92, 1.0, age));

  float hot = vnoise(cellId / max(u_rows, 4.0) * vec2(8.1, 6.3) + vec2(t * 0.05 * u_speed, t * 0.12 * u_speed));
  float pG = 0.06 + 0.7 * smoothstep(0.5, 0.8, hot) * (0.3 + 0.7 * edge);
  float letter = hr.y < pG ? 3.0 : floor(h12(vec2(cellId.x * 0.71, k + 3.1)) * 2.999);
  vec3 ink = letter < 0.5 ? u_lilac : letter < 1.5 ? u_blue : letter < 2.5 ? u_violet : u_red;

  vec2 bs = cs * vec2(0.12, 0.11);
  vec2 f = px - cellId * cs;
  vec2 q = vec2((f.x - 0.2 * cs) / bs.x, 7.0 - (f.y - 0.115 * cs) / bs.y);
  vec2 h = 0.5 / bs;
  vec2 hw = h + 1.2;
  float e = 0.12;
  vec2 rows = letterRows(letter);
  vec2 qb = floor(q);
  float cov = 0.0;
  float halo = 0.0;
  float vis = lit * env;

  if (vis > 0.0) {
    for (int j = -2; j <= 2; j++) {
      for (int i = -2; i <= 2; i++) {
        vec2 bb = qb + vec2(float(i), float(j));
        float on = bitAt(rows, bb);
        vec2 o = clamp(min(q + h, bb + 1.0 + e) - max(q - h, bb - e), 0.0, 2.0 * h.x);
        o.y = clamp(min(q.y + h.y, bb.y + 1.0 + e) - max(q.y - h.y, bb.y - e), 0.0, 2.0 * h.y);
        cov += on * o.x * o.y;
        vec2 ow = clamp(min(q + hw, bb + 1.0) - max(q - hw, bb), 0.0, 1.0);
        halo += on * ow.x * ow.y;
      }
    }
    cov = clamp(cov / (4.0 * h.x * h.y), 0.0, 1.0);
    halo /= 4.0 * hw.x * hw.y;
  }

  vec2 dq = q - vec2(2.0, 2.0);
  vec2 od = min(dq + h, vec2(1.0, 3.0)) - max(dq - h, vec2(0.0));
  od = clamp(od, vec2(0.0), 2.0 * h);
  float dash = clamp(od.x * od.y / (4.0 * h.x * h.y), 0.0, 1.0);

  float bright = 0.85 + 0.25 * run + 0.15 * (hl.x - 0.5);
  vec3 col = ink * cov * vis * bright;
  col += ink * halo * vis * u_glow * (letter > 2.5 ? 0.9 : 0.55);
  col += u_red * 1.2 * u_floor * (0.55 + 0.45 * lum) * dash * sil * (1.0 - lit);
  gl_FragColor = vec4(col, 1.0);
}
