precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Center X
 * @default 0.5
 * @range 0, 1
 */
uniform float u_centerX;

/**
 * @label Center Y
 * @default 0.5
 * @range 0, 1
 */
uniform float u_centerY;

/**
 * @label Waves
 * @default 2
 * @range 1, 8
 */
uniform float u_waves;

/**
 * @label Width
 * @default 150
 * @range 10, 600
 */
uniform float u_width;

/**
 * @label Speed
 * @default 0.35
 * @range 0, 2
 */
uniform float u_speed;

/**
 * @label Easing
 * @default 1
 * @range -1, 1
 */
uniform float u_ease;

/**
 * @label Ease Power
 * @default 2
 * @range 1, 12
 */
uniform float u_easePow;

/**
 * @label Distortion
 * @default 70
 * @range 0, 300
 */
uniform float u_distortion;

/**
 * @label Rainbow
 * @default 1
 * @range 0, 2
 */
uniform float u_rainbow;

/**
 * @label Glow
 * @default 0.6
 * @range 0, 2
 */
uniform float u_glow;

/**
 * @label Reveal
 * @default 0.25
 * @range 0, 1
 */
uniform float u_reveal;

/**
 * @label Shape
 * @default 0.6
 * @range 0, 1
 */
uniform float u_shape;

/**
 * @label Jaggedness
 * @default 35
 * @range 0, 300
 */
uniform float u_jag;

/**
 * @label Jag Fineness
 * @default 14
 * @range 1, 120
 */
uniform float u_jagFine;

/**
 * @label Jag Detail
 * @default 0.5
 * @range 0, 1
 */
uniform float u_jagDetail;

const int MAX_WAVES = 8;

float shapeExp() { return mix(2.0, 5.0, u_shape); }

vec2 shapeScale() {
  return vec2(mix(1.0, u_resolution.x / u_resolution.y, u_shape), 1.0);
}

float metric(vec2 q) {
  float n = shapeExp();
  vec2 a = abs(q / shapeScale()) + 1e-4;
  return pow(pow(a.x, n) + pow(a.y, n), 1.0 / n);
}

vec2 outward(vec2 q) {
  float n = shapeExp();
  vec2 s = shapeScale();
  vec2 a = abs(q / s) + 1e-4;
  vec2 g = sign(q) * pow(a, vec2(n - 1.0)) / s;
  return normalize(g + 1e-6);
}

vec3 prism(float x) {
  vec3 warm = vec3(1.0, 0.55, 0.18);
  vec3 cyan = vec3(0.25, 0.85, 1.0);
  vec3 blue = vec3(0.3, 0.4, 1.0);
  vec3 c = mix(warm, cyan, smoothstep(-0.7, 0.2, x));
  c = mix(c, blue, smoothstep(0.3, 1.1, x));
  return c - dot(c, vec3(0.2126, 0.7152, 0.0722));
}

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

float fbm(vec2 p, float gain) {
  float v = 0.0;
  float a = 0.5;
  float norm = 0.0;
  for (int o = 0; o < 5; o++) {
    v += a * (vnoise(p) * 2.0 - 1.0);
    norm += a;
    p = p * 2.07 + vec2(13.1, 7.7);
    a *= gain;
  }
  return v / norm;
}

vec3 sampleBack(vec2 px) {
  return texture2D(u_backdrop, clamp(px / u_resolution, 0.0, 1.0)).rgb;
}

void main() {
  vec2 px = gl_FragCoord.xy;

  vec2 c = vec2(u_centerX, 1.0 - u_centerY) * u_resolution;
  vec2 q = px - c;
  float d = metric(q);
  vec2 dir = outward(q);

  float reach = max(max(metric(-c), metric(u_resolution - c)),
                    max(metric(vec2(u_resolution.x, 0.0) - c),
                        metric(vec2(0.0, u_resolution.y) - c)));
  reach += u_width * 1.5;
  float w = max(u_width, 1.0);

  float disp = 0.0;
  float band = 0.0;
  float crest = 0.0;
  float behind = 0.0;
  float hueAt = 0.0;
  float fringe = 0.0;

  float count = floor(clamp(u_waves, 1.0, float(MAX_WAVES)));

  vec2 around = normalize(q / shapeScale() + 1e-4) * (u_jagFine / 3.0);
  float gain = mix(0.25, 0.8, u_jagDetail);
  for (int i = 0; i < MAX_WAVES; i++) {
    if (float(i) >= count) break;
    float ph = fract(u_time * u_speed + float(i) / count);

    float pw = max(u_easePow, 1.0);
    float curve = u_ease > 0.0 ? 1.0 - pow(1.0 - ph, pw) : pow(ph, pw);
    float e = mix(ph, curve, abs(u_ease));
    float r = reach * e;

    float amp = smoothstep(0.0, 0.06, e) * (1.0 - smoothstep(0.7, 1.0, e));

    float launch = floor(u_time * u_speed + float(i) / count);
    vec2 seed = vec2(float(i) * 17.3 + launch * 5.71, launch * 3.19);

    float jag = abs(d - r) > 4.0 * w + abs(u_jag) ? 0.0 : fbm(around + seed + vec2(ph * 1.3, -ph * 0.9), gain);

    float rr = r + jag * u_jag * smoothstep(0.0, 0.25, ph);
    float x = (d - rr) / w;

    disp += -x * exp(-x * x * 2.0) * 2.3 * amp;
    float env = exp(-x * x * 1.6) * amp;
    if (env > band) { band = env; hueAt = x; }
    fringe += exp(-x * x * 0.9) * amp;
    crest += exp(-pow((x - 0.35) * 2.6, 2.0)) * amp;

    behind = max(behind, smoothstep(0.6, -1.5, x) * amp * (1.0 - ph * 0.6));
  }

  float split = u_rainbow * (0.25 * abs(disp) + 0.6 * fringe) * (6.0 + u_distortion * 0.18);
  vec2 base = px - dir * disp * u_distortion;
  vec3 col = vec3(0.0);
  float smear = band * u_distortion * 0.25;
  for (int j = 0; j < 4; j++) {
    float o = (float(j) - 1.5) * smear * 0.33;
    vec2 s = base + dir * o;
    col.r += sampleBack(s - dir * split).r;
    col.g += sampleBack(s).g;
    col.b += sampleBack(s + dir * split).b;
  }
  col *= 0.25;

  float lift = behind * u_reveal;
  col = col + (1.0 - col) * lift * 0.45 + col * lift * 0.5;

  float ring = exp(-hueAt * hueAt * 2.2) * band;
  col += prism(hueAt) * ring * 0.45 * u_rainbow;
  col += vec3(crest * u_glow * 0.35);

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 2.0 * over);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
