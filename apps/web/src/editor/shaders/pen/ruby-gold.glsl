precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Rim Width
 * @default 7
 * @range 2, 40
 */
uniform float u_rim;

/**
 * @label Depth
 * @default 1
 * @range 0, 2.5
 */
uniform float u_depth;

/**
 * @label Gold Light
 * @color
 * @default #ffd277
 */
uniform vec3 u_goldLight;

/**
 * @label Gold Dark
 * @color
 * @default #4a2205
 */
uniform vec3 u_goldDark;

/**
 * @label Ruby Light
 * @color
 * @default #ff2414
 */
uniform vec3 u_rubyLight;

/**
 * @label Ruby Dark
 * @color
 * @default #3a0006
 */
uniform vec3 u_rubyDark;

/**
 * @label Facets
 * @default 20
 * @range 0, 40
 */
uniform float u_facets;

/**
 * @label Top Light
 * @default 0.6
 * @range 0, 1
 */
uniform float u_topLight;

/**
 * @label Bottom Light
 * @default 0.5
 * @range 0, 1
 */
uniform float u_bottomLight;

/**
 * @label Sparkle
 * @default 0.6
 * @range 0, 1
 */
uniform float u_sparkle;

/**
 * @label Light Angle
 * @default 100
 * @range 0, 360
 */
uniform float u_angle;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  return vec2(hash21(p), hash21(p + 17.17));
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * vnoise(p);
    p = p * 2.07 + vec2(17.1, 9.3);
    a *= 0.5;
  }
  return v;
}

float profileSlope(float d, float w) {
  float t = d / w;
  if (t < 0.14) {

    float k = t / 0.14;
    return mix(2.6, 0.1, k * k);
  }
  if (t < 0.40) return 0.1;
  if (t < 1.0) return -0.95;
  if (t < 1.55) return 0.8;
  return 0.0;
}

vec3 goldRamp(float x) {
  vec3 c0 = u_goldDark * 0.35;
  vec3 c1 = u_goldDark;
  vec3 c2 = mix(u_goldDark, u_goldLight, 0.5) * vec3(1.12, 0.86, 0.48);
  vec3 c3 = u_goldLight;
  vec3 c4 = mix(u_goldLight, vec3(1.0, 0.97, 0.88), 0.7);
  x = clamp(x, 0.0, 1.0) * 4.0;
  if (x < 1.0) return mix(c0, c1, x);
  if (x < 2.0) return mix(c1, c2, x - 1.0);
  if (x < 3.0) return mix(c2, c3, x - 2.0);
  return mix(c3, c4, x - 3.0);
}

float studio(vec3 r, float y) {
  float v = y * 0.55 + r.y * 0.85 + 0.12;
  float box = smoothstep(0.55, 0.85, v);
  float band = 1.0 - smoothstep(0.08, 0.32, abs(v - 0.38));
  float floorB = smoothstep(0.2, -0.3, v) * (0.35 + 0.6 * u_bottomLight);
  float base = 0.42 + 0.25 * v;
  float side = 1.0 - 0.4 * r.x * r.x;
  return (base + 0.55 * box + floorB - 0.32 * band) * side;
}

float star(vec2 q, float s) {
  float r2 = dot(q, q);
  float core = exp(-r2 / (s * s * 0.012)) + 0.45 * exp(-r2 / (s * s * 0.09));
  float sx = exp(-abs(q.y) / (s * 0.03)) * pow(max(1.0 - abs(q.x) / s, 0.0), 1.5);
  float sy = exp(-abs(q.x) / (s * 0.03)) * pow(max(1.0 - abs(q.y) / (s * 0.6), 0.0), 1.5);
  return core + sx + 0.7 * sy;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 p = gl_FragCoord.xy;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0, -1.0);
  vec2 tang = vec2(-gdir.y, gdir.x);

  float w = max(u_rim, 2.0);
  float t = d / w;

  float slope = 0.5 * (profileSlope(d - 0.5, w) + profileSlope(d + 0.5, w)) * u_depth;

  float a = radians(u_angle);
  vec3 L = normalize(vec3(cos(a), sin(a), 0.8));
  vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));

  float vert = smoothstep(0.0, 1.0, uv.y);
  float fall = mix(1.0 - 0.6 * u_topLight, 1.0 + 0.2 * u_topLight, vert);
  float low = smoothstep(0.55, 0.0, uv.y);

  float goldMask = 1.0 - smoothstep(w - 0.6, w + 0.6, d);

  vec3 gold = vec3(0.0);
  if (goldMask > 0.0) {
    vec3 ng = normalize(vec3(-gdir * slope, 1.0));
    vec3 rg = reflect(vec3(0.0, 0.0, -1.0), ng);
    float env = studio(rg, uv.y);
    float gdiff = max(dot(ng, L), 0.0);
    float gnh = max(dot(ng, H), 0.0);

    float brush = vnoise(vec2(d * 1.1, dot(p, tang) * 0.015)) * 0.7
                + vnoise(vec2(d * 3.0, dot(p, tang) * 0.05)) * 0.3;
    float gi = env * (0.6 + 0.5 * gdiff) * fall;
    gi *= 0.88 + 0.24 * brush;

    gi *= 0.85 + 0.3 * fbm(p / 160.0 + 2.3);
    gold = goldRamp(gi * 0.98);
    gold += mix(u_goldLight, vec3(1.0, 0.97, 0.9), 0.6) * (pow(gnh, 70.0) * 1.3 + pow(gnh, 10.0) * 0.12) * fall;

    float lip = 1.0 - smoothstep(0.0, 0.16, t);
    float upFacing = max(dot(-gdir, normalize(L.xy + 1e-4)), 0.0);
    gold += u_goldLight * lip * (0.15 + 0.85 * upFacing) * 0.6 * fall;

    float downFacing = max(dot(gdir, normalize(L.xy + 1e-4)), 0.0);
    gold += vec3(1.0, 0.62, 0.25) * lip * downFacing * u_bottomLight * low * 0.9;

    gold += vec3(1.0, 0.55, 0.18) * u_bottomLight * low * max(-ng.y, 0.0) * 0.9;

    float brk = 1.0 - smoothstep(0.0, 0.7, abs(d - 0.4 * w));
    gold *= 1.0 - 0.25 * brk;
  }

  vec3 ruby = vec3(0.0);
  if (goldMask < 1.0) {

    vec2 tilt = vec2(0.0);
    float edge = 1.0;
    float cellRnd = 0.5;
    if (u_facets > 0.5) {
      vec2 q = p / u_facets;
      vec2 ci = floor(q);
      float d1 = 8.0;
      float d2 = 8.0;
      vec2 best = vec2(0.0);
      for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
          vec2 id = ci + vec2(float(i), float(j));
          vec2 c = id + 0.15 + 0.7 * hash22(id);
          float dd = length(q - c);
          if (dd < d1) { d2 = d1; d1 = dd; best = id; }
          else if (dd < d2) { d2 = dd; }
        }
      }
      vec2 rr = hash22(best + 3.7);
      tilt = (rr - 0.5) * 0.3;
      cellRnd = hash21(best + 9.1);
      edge = smoothstep(0.0, 0.08, d2 - d1);
    }
    float face = smoothstep(w * 1.4, w * 1.8, d);
    vec3 nr = normalize(vec3(-gdir * slope + tilt * face, 1.0));
    float rdiff = max(dot(nr, L), 0.0);
    float rnh = max(dot(nr, H), 0.0);

    float inner = smoothstep(w, w * 2.6, d);
    float cloud = fbm(p / 55.0 + 8.4);
    float ri = (0.25 + 0.8 * rdiff) * mix(0.45, 1.0, inner);
    ri *= 0.75 + 0.5 * cloud;
    ri *= mix(0.95, 1.04, cellRnd * face + (1.0 - face) * 0.5);
    ri *= fall;
    ruby = mix(u_rubyDark, u_rubyLight, clamp(ri, 0.0, 1.0));

    ruby += u_rubyLight * vec3(0.5, 0.2, 0.08) * smoothstep(0.7, 1.1, ri);

    ruby *= mix(0.94, 1.0, mix(1.0, edge, face));

    ruby += vec3(1.0, 0.6, 0.55) * (pow(rnh, 14.0) * 0.12 + pow(rnh, 160.0) * 0.6 * face) * fall;
    ruby += vec3(1.0, 0.25, 0.08) * u_bottomLight * low * max(-nr.y, 0.0) * 0.6;
  }

  vec3 col = mix(ruby, gold, goldMask);

  float crease = 1.0 - smoothstep(0.0, 1.0, abs(d - w));
  col *= 1.0 - 0.75 * crease;

  if (u_sparkle > 0.001) {
    float cs = 55.0;
    vec2 cell = floor(p / cs);
    float glint = 0.0;
    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        vec2 id = cell + vec2(float(i), float(j));
        if (hash21(id + 0.7) > u_sparkle * 0.55) continue;
        vec2 c = (id + hash22(id + 1.9)) * cs;
        vec4 f = texture2D(u_shape, c / u_resolution);
        if (f.r < -w * 2.0 || f.r > w * 3.0) continue;
        vec2 fg = length(f.gb) > 1e-5 ? normalize(f.gb) : vec2(0.0);

        c -= fg * (f.r - w * 0.12);
        float facing = dot(-fg, normalize(L.xy + 1e-4));
        if (facing < 0.6) continue;
        float hy = c.y / u_resolution.y;
        float s = (22.0 + 40.0 * hash21(id + 5.1)) * (0.5 + 0.6 * u_sparkle) * (0.5 + 0.6 * hy);
        glint = max(glint, star(p - c, s) * facing * (0.4 + 0.8 * hy));
      }
    }
    col += vec3(1.0, 0.86, 0.6) * glint * (0.5 + u_sparkle) * 1.3;
  }

  vec3 over = max(col - 0.8, 0.0);
  col = min(col, vec3(0.8)) + over / (1.0 + 2.2 * over);
  col += (hash21(p) - 0.5) * 0.012;

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
