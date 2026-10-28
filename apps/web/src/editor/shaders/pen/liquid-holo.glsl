precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Puff
 * @default 16
 * @range 1, 80
 */
uniform float u_puff;

/**
 * @label Liquid
 * @default 1
 * @range 0, 3
 */
uniform float u_liquid;

/**
 * @label Wave Size
 * @default 120
 * @range 30, 600
 */
uniform float u_scale;

/**
 * @label Ribs
 * @default 0.6
 * @range 0, 1.5
 */
uniform float u_ribs;

/**
 * @label Speed
 * @default 0.35
 * @range 0, 2
 */
uniform float u_speed;

/**
 * @label Spectrum
 * @default 1.3
 * @range 0.2, 4
 */
uniform float u_spectrum;

/**
 * @label Hue
 * @default 0
 * @range 0, 1
 */
uniform float u_hue;

/**
 * @label Rim
 * @default 0.8
 * @range 0, 1
 */
uniform float u_rim;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
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
  float s = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    s += a * noise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.3;
    a *= 0.45;
  }
  return s;
}

float liquid(vec2 p, float t) {
  vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, -t * 0.8) + 1.7));
  vec2 w = p + 1.2 * q;
  float blob = fbm(w + vec2(t * 0.4, 0.0));
  float rib = sin(w.y * 1.8 + blob * 3.0 - t * 1.5) * 0.5 + 0.5;
  rib = rib * rib * (3.0 - 2.0 * rib);
  return blob + u_ribs * 0.35 * rib;
}

vec3 spectrum(float x) {
  vec3 c = 0.5 + 0.5 * cos(6.2831853 * (x + vec3(0.0, 0.33, 0.67)));

  return pow(c, vec3(1.25));
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);
  float t = u_time * u_speed;

  float tp = clamp(d / max(u_puff, 1.0), 0.0, 1.0);
  float h = sqrt(max(1.0 - (1.0 - tp) * (1.0 - tp), 0.0));
  float slope = tp < 1.0 ? (1.0 - tp) / max(h, 0.08) : 0.0;
  vec2 grad = gdir * slope * 1.1;

  vec2 p = gl_FragCoord.xy / u_scale;
  float e = 0.02;
  float l0 = liquid(p, t);
  float lx = liquid(p + vec2(e, 0.0), t);
  float ly = liquid(p + vec2(0.0, e), t);
  vec2 lgrad = vec2(lx - l0, ly - l0) / e;

  grad += lgrad * u_liquid * 0.95 * (0.35 + 0.65 * tp);

  vec3 n = normalize(vec3(-grad, 1.0));
  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
  float tilt = length(n.xy);

  float ka = 2.1 + 0.9 * sin(t * 0.7);
  vec3 key = normalize(vec3(cos(ka), sin(ka), 0.7));
  vec3 kick = normalize(vec3(-cos(ka) * 0.8, -0.6, 0.5));
  float kd = max(dot(r, key), 0.0);
  float kk = max(dot(r, kick), 0.0);
  float stripes = smoothstep(0.55, 0.95, sin(r.y * 7.0 + r.x * 2.0 + t * 0.6) * 0.5 + 0.5);
  float sky = smoothstep(-0.2, 0.8, r.y);
  float room = smoothstep(0.98, 0.55, r.z);

  float lum = 0.06;
  lum += room * (0.35 + 0.55 * sky) * (0.4 + 0.6 * stripes);
  lum += pow(kd, 3.0) * 1.0;
  lum += pow(kk, 6.0) * 0.5;

  lum *= mix(0.3, 1.0, smoothstep(0.05, 0.45, tilt));

  lum *= mix(0.3, 1.0, smoothstep(0.28, 0.58, l0));

  float film = u_spectrum * (tilt * 0.6 + l0 * 1.6 + r.x * 0.5) + u_hue + t * 0.05;
  vec3 iri = spectrum(film);

  vec3 col = mix(iri, vec3(1.0), 0.06) * lum * 1.9;

  col += vec3(1.0) * (pow(kd, 12.0) * 1.0 + pow(kk, 20.0) * 0.6);

  float rim = (1.0 - smoothstep(0.0, 6.0, d)) * u_rim;
  vec3 rimCol = spectrum(film + 0.25 + uv.y * 0.6) * 1.3 + 0.15;
  col = max(col, rimCol * rim);

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 1.5 * over);
  float peak = max(max(col.r, col.g), col.b);
  col = mix(col, vec3(1.0), smoothstep(0.95, 1.2, peak) * 0.6);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
