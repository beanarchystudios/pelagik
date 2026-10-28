precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Piece Size
 * @default 0.17
 * @range 0.06, 0.5
 */
uniform float u_size;

/**
 * @label Frost
 * @default 0.6
 * @range 0, 1
 */
uniform float u_frost;

/**
 * @label Blur
 * @default 0.8
 * @range 0, 1
 */
uniform float u_blur;

/**
 * @label Refraction
 * @default 0.9
 * @range 0, 1.5
 */
uniform float u_refract;

/**
 * @label Edges
 * @default 0.8
 * @range 0, 1
 */
uniform float u_edge;

/**
 * @label Layers
 * @default 0.4
 * @range 0, 1
 */
uniform float u_layers;

/**
 * @label Grain
 * @default 0.5
 * @range 0, 1
 */
uniform float u_grain;

/**
 * @label Motion
 * @default 0.3
 * @range 0, 1
 */
uniform float u_motion;

float aspect;

vec2 dC[25];
float dR[25];
float dZ[25];
vec4 dP[25];

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  return vec2(hash21(p), hash21(p + 19.19));
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

vec3 back(vec2 p) {
  return texture2D(u_backdrop, clamp(p / vec2(aspect, 1.0), 0.0, 1.0)).rgb;
}

float lum(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 icePos(vec2 pos) {
  vec2 c = pos / u_size;
  vec2 w = vec2(vnoise(c * 0.8 + 1.7), vnoise(c * 0.8 + 8.3)) - 0.5;
  vec2 r = vec2(vnoise(c * 10.0), vnoise(c * 10.0 + 5.2)) - 0.5;
  return c + w * 0.45 + r * 0.025;
}

float topAt(vec2 q) {
  float bz = -1e9;
  for (int m = 0; m < 25; m++) {
    if (length(q - dC[m]) < dR[m] && dZ[m] > bz) bz = dZ[m];
  }
  return bz;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  aspect = u_resolution.x / u_resolution.y;
  vec2 pos = uv * vec2(aspect, 1.0);
  float px = 1.0 / u_resolution.y;
  float cellPx = u_size / px;
  float t = u_time * u_motion;
  vec3 bgCol = back(vec2(0.004));

  vec2 q = icePos(pos);
  vec2 n = floor(q);
  for (int m = 0; m < 25; m++) {
    float fm = float(m);
    vec2 cell = n + vec2(mod(fm, 5.0), floor(fm / 5.0)) - 2.0;
    float ph0 = hash21(cell + 0.7);
    float per = mix(14.0, 26.0, hash21(cell + 2.3));
    float life = t / per + ph0;
    float cyc = floor(life);
    float ph = life - cyc;
    vec2 s = cell + cyc * 7.31;
    vec2 h = hash22(s);
    vec2 h2 = hash22(s + 4.1);
    float grow = smoothstep(0.0, 0.35, ph) * (1.0 - smoothstep(0.82, 1.0, ph));
    dC[m] = cell + 0.2 + 0.6 * h;
    dR[m] = mix(0.6, 1.15, h2.x) * grow;
    dZ[m] = (cyc - ph0) * per;
    dP[m] = vec4(h2.y, hash22(s + 9.7), hash21(s + 12.3));
  }

  float bz = -1e9;
  vec2 tc = q;
  float tr = 0.0;
  vec4 tp = vec4(0.0);
  for (int m = 0; m < 25; m++) {
    if (length(q - dC[m]) < dR[m] && dZ[m] > bz) {
      bz = dZ[m];
      tc = dC[m];
      tr = dR[m];
      tp = dP[m];
    }
  }
  float de = 1e3;
  vec2 edir = vec2(0.0);
  for (int m = 0; m < 25; m++) {
    if (dR[m] <= 0.0) continue;
    vec2 v = dC[m] - q;
    float d = max(length(v), 1e-4);
    float e;
    vec2 dir;
    if (dZ[m] == bz) {
      e = dR[m] - d;
      dir = -v / d;
    } else if (dZ[m] > bz) {
      e = d - dR[m];
      dir = v / d;
    } else {
      continue;
    }
    if (e < de) {
      de = e;
      edir = dir;
    }
  }
  float dePx = de * cellPx;
  bool inIce = bz > -1e8;

  float sIn = tr - length(q - tc);
  float T0 = inIce ? smoothstep(0.05, 0.95, tp.x + (u_frost - 0.5) * 1.4) : 0.0;
  float T = T0 * mix(0.7, 1.0, smoothstep(0.0, 0.3, sIn));

  float rough = 6.0 * px;
  vec2 off = vec2(0.0);
  if (inIce) {
    off += (tp.yz - 0.5) * 0.04 * u_refract;
    off += (pos - tc * u_size) * (tp.y - 0.5) * 0.3 * u_refract;
  }
  off += edir * pow(1.0 - smoothstep(0.0, 0.2, de), 3.0) * 0.02 * u_refract;
  off += (vec2(vnoise(pos / (5.0 * px)), vnoise(pos / (5.0 * px) + 7.7)) - 0.5) * rough * u_refract;

  float gseed = mod(floor(u_time * 12.0), 64.0) * step(0.001, u_motion);
  float rnd = hash21(gl_FragCoord.xy + gseed * 7.13);
  float rnd2 = hash21(gl_FragCoord.xy * 1.37 + gseed * 3.1 + 9.0);

  vec2 p0 = pos + off;
  float rad = T * T * u_blur * 0.055;
  float ang = tp.w * 6.2831853;
  vec2 ax = vec2(cos(ang), sin(ang));
  vec2 ay = vec2(-ax.y, ax.x);
  float st = mix(1.0, 1.6, tp.y);
  vec3 acc = back(p0) * 0.05;
  float wsum = 0.05;
  for (int i = 0; i < 14; i++) {
    float fi = (float(i) + rnd2) / 14.0;
    float a = float(i) * 2.3999632 + rnd * 6.2831853;
    vec2 o = vec2(cos(a), sin(a)) * fi * rad;
    o = ax * o.x * st + ay * o.y / st;
    float w = abs(topAt(icePos(pos + o)) - bz) < 1e-3 ? 1.0 : 0.0;
    acc += back(p0 + o) * w;
    wsum += w;
  }
  vec3 col = acc / wsum;

  float vis = smoothstep(0.03, 0.22, length(col - bgCol));

  col = mix(col, bgCol, T * 0.08);

  vec3 lineC = vec3(lum(col) > 0.5 ? 0.3 : 0.95);
  float breakUp = mix(0.35, 1.0, smoothstep(0.3, 0.6, vnoise(pos / (14.0 * px))));
  float edge = (1.0 - smoothstep(0.5, 1.4, dePx)) * vis * breakUp * u_edge;

  float sp = mix(0.22, 0.08, u_layers);
  float rf = sIn / sp;
  float ringPx = abs(rf - floor(rf + 0.5)) * sp * cellPx;
  float ring = inIce ? (1.0 - smoothstep(0.4, 1.2, ringPx)) * step(0.5, rf) * (1.0 - smoothstep(2.5, 3.5, rf)) : 0.0;
  ring *= vis * breakUp * u_layers * 0.5;

  float g = hash21(gl_FragCoord.xy * 0.91 + gseed * 5.7 + 31.0) - 0.5;
  col += g * u_grain * (0.04 + 0.6 * vis * (0.3 + T));

  col = mix(col, lineC, ring);
  col = mix(col, lineC, edge);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
