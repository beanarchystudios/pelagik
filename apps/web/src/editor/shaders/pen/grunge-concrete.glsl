precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Paint
 * @color
 * @default #e8e6e0
 */
uniform vec3 u_paint;

/**
 * @label Concrete
 * @color
 * @default #87847d
 */
uniform vec3 u_concrete;

/**
 * @label Scale
 * @default 1
 * @range 0.3, 3
 */
uniform float u_scale;

/**
 * @label Cracks
 * @default 0.6
 * @range 0, 1
 */
uniform float u_cracks;

/**
 * @label Scratches
 * @default 0.5
 * @range 0, 1
 */
uniform float u_scratches;

/**
 * @label Peel
 * @default 0.3
 * @range 0, 1
 */
uniform float u_peel;

/**
 * @label Grime
 * @default 0.5
 * @range 0, 1
 */
uniform float u_grime;

/**
 * @label Edge Wear
 * @default 3
 * @range 0, 20
 */
uniform float u_edge;

/**
 * @label Seed
 * @default 0
 * @range 0, 20
 */
uniform float u_seed;

const float PI = 3.14159265;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float gnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(hash22(i) * 2.0 - 1.0, f);
  float b = dot(hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
  float c = dot(hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
  float d = dot(hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
  return clamp(0.5 + 0.9 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * vnoise(p);
    p = p * 2.07 + vec2(17.1, 9.3);
    a *= 0.5;
  }
  return v / 0.97;
}

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

vec2 crackLayer(vec2 p, float ang, float size, float width, float gate, float salt) {
  vec2 q = rot(ang) * p;
  q += (vec2(fbm(q / (size * 0.9) + salt), fbm(q / (size * 0.9) + salt + 5.2)) - 0.5) * size * 0.35;
  q += (vec2(vnoise(q / 7.0 + salt), vnoise(q / 7.0 + salt + 3.1)) - 0.5) * 2.6;
  q /= size;

  vec2 n = floor(q);
  vec2 f = fract(q);
  vec2 mg = vec2(0.0);
  vec2 mr = vec2(0.0);
  float md = 8.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 g = vec2(float(i), float(j));
      vec2 r = g + hash22(n + g + salt) - f;
      float dd = dot(r, r);
      if (dd < md) { md = dd; mr = r; mg = g; }
    }
  }
  float ed = 8.0;
  float open = 0.0;
  vec2 c0 = n + mg;
  for (int j = -2; j <= 2; j++) {
    for (int i = -2; i <= 2; i++) {
      vec2 g = mg + vec2(float(i), float(j));
      vec2 r = g + hash22(n + g + salt) - f;
      vec2 dr = r - mr;
      if (dot(dr, dr) > 0.00001) {
        float e = dot(0.5 * (mr + r), normalize(dr));
        if (e < ed) {
          ed = e;
          vec2 c1 = n + g;
          open = hash12(c0 + c1 + 0.37 * abs(c0 - c1) + salt);
        }
      }
    }
  }
  float dpx = ed * size;

  float on = smoothstep(0.0, 0.25, gate - open);
  float w = width * on * (0.55 + 0.9 * vnoise(p / (size * 0.25) + salt));

  float core = (1.0 - smoothstep(w * 0.5, w * 0.5 + 0.9, dpx)) * smoothstep(0.0, 0.8, w);
  float soak = (1.0 - smoothstep(0.0, w * 2.5 + 1.5, dpx)) * on;
  return vec2(core, soak);
}

float segDist(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * t);
}

float scratchLayer(vec2 p, float cs, float S, float salt) {
  vec2 cell = floor(p / cs);
  float cov = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = cell + vec2(float(i), float(j));

      float hg = hash12(id + salt);
      if (hg > u_scratches * 1.4) continue;
      vec2 ctr = (id + vec2(hash12(id + salt + 1.3), hash12(id + salt + 2.7))) * cs;
      float len = cs * (0.5 + 1.6 * hash12(id + salt + 5.9));
      if (length(p - ctr) > 0.5 * len + 1.5) continue;
      float cluster = smoothstep(0.35, 0.7, fbm(id * cs / (320.0 * S) + salt));
      if (hg > u_scratches * cluster * 1.4) continue;

      float ang = fbm(id * cs / (500.0 * S) + salt + 9.0) * 2.0 * PI * 1.6
                + (hash12(id + salt + 4.1) - 0.5) * 0.9;
      vec2 dir = vec2(cos(ang), sin(ang)) * 0.5 * len;
      float w = 0.35 + 0.8 * hash12(id + salt + 7.3);
      float t = clamp(dot(p - ctr, dir) / dot(dir, dir), -1.0, 1.0);
      w *= 1.0 - t * t;
      float d = segDist(p, ctr - dir, ctr + dir);
      float a = 0.45 + 0.55 * hash12(id + salt + 8.8);
      cov = max(cov, a * (1.0 - smoothstep(w * 0.5, w * 0.5 + 0.7, d)));
    }
  }
  return cov;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  float d = texture2D(u_shape, uv).r;
  float S = max(u_scale, 0.05);
  vec2 p = gl_FragCoord.xy + u_seed * vec2(97.3, 61.1) * S;

  float dent = fbm(p / (40.0 * S));
  float chip = smoothstep(0.62, 0.8, vnoise(p / (9.0 * S) + 3.0));
  float grit = vnoise(p / (1.6 * S));
  float erode = u_edge * clamp(0.6 * dent + 0.8 * chip + 0.35 * grit - 0.25, 0.0, 1.5);
  float alpha = smoothstep(erode - 0.7, erode + 0.7, d);
  float inside = d - erode;

  float grain = gnoise(p / (0.9 * S)) * 0.6 + gnoise(p / (3.0 * S)) * 0.4;
  float drift = fbm(p / (180.0 * S) + 2.3);
  vec3 paint = u_paint * (0.93 + 0.1 * grain) * (0.94 + 0.1 * drift);

  float cm = fbm(p / (14.0 * S) + 8.1);
  float agg = smoothstep(0.6, 0.8, gnoise(p / (2.2 * S) + 4.4));
  vec3 conc = u_concrete * (0.7 + 0.55 * cm) * (1.0 - 0.25 * agg);

  float pn = fbm(p / (70.0 * S) + 21.0) * 0.7 + fbm(p / (12.0 * S) + 6.0) * 0.3;
  pn += 0.035 * (1.0 - smoothstep(0.0, 10.0 * S, inside));
  float pt = 0.74 - 0.38 * u_peel;
  float wear = smoothstep(pt - 0.08, pt + 0.1, pn) * step(0.001, u_peel);
  float fine = gnoise(p / (1.7 * S) + 2.0) * 0.55 + gnoise(p / (6.0 * S) + 9.0) * 0.45;
  float bare = smoothstep(-0.06, 0.06, wear - fine);
  vec3 col = mix(paint, mix(paint, conc, 0.25), smoothstep(0.0, 0.5, wear));
  col = mix(col, conc, bare);

  float runs = fbm(p / vec2(26.0 * S, 260.0 * S) + 13.0);
  float stain = fbm(p / (120.0 * S) + 31.0);
  float grime = smoothstep(0.45, 0.85, runs) * 0.6 + smoothstep(0.5, 0.8, stain) * 0.5;
  col *= 1.0 - 0.32 * u_grime * grime;
  float pore = smoothstep(0.74, 0.86, gnoise(p / (1.3 * S) + 17.0)) * smoothstep(0.4, 0.7, stain + 0.2);
  col = mix(col, conc * 0.45, pore * u_grime * 0.8);
  col *= mix(1.0 - 0.1 * u_grime, 1.0, smoothstep(0.0, 5.0 * S, inside));

  float sc = 0.0;
  if (u_scratches > 0.001) {
    sc = max(scratchLayer(p, 48.0 * S, S, 0.0), scratchLayer(p, 19.0 * S, S, 23.0) * 0.8);
  }
  col = mix(col, conc * 0.8, sc * 0.6);

  float ck = 0.0;
  float halo = 0.0;
  if (u_cracks > 0.001) {
    float g1 = u_cracks * (0.2 + 0.9 * fbm(p / (380.0 * S) + 41.0));
    float g2 = u_cracks * (0.08 + 0.9 * fbm(p / (380.0 * S) + 77.0));
    float g3 = u_cracks * (0.8 * fbm(p / (200.0 * S) + 5.0) - 0.1);
    vec2 c1 = crackLayer(p, -0.3, 150.0 * S, 1.6 * S, g1, 1.0);
    vec2 c2 = crackLayer(p, 0.7, 210.0 * S, 1.4 * S, g2, 7.0);
    vec2 c3 = crackLayer(p, 1.3, 60.0 * S, 0.9 * S, g3, 13.0) * 0.75;
    ck = max(max(c1.x, c2.x), c3.x);
    halo = max(max(c1.y, c2.y), c3.y * 0.5);
  }
  col *= 1.0 - 0.12 * halo;
  col = mix(col, conc * 0.18, ck * 0.92);

  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col * alpha, alpha);
}
