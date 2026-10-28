/** @resolution */
uniform vec2 u_resolution;

/** @backdrop @mipmap */
uniform sampler2D u_backdrop;

/** @sdf */
uniform sampler2D u_sdf;

/**
 * @label Index of Refraction
 * @default 1.2
 * @range 1.0, 2.0
 */
uniform float u_ior;

/**
 * @label Chromatic Aberration
 * @default 0.02
 * @range 0.0, 0.2
 */
uniform float u_chromatic;

/**
 * @label Edge Width
 * @default 24
 * @range 1, 200
 */
uniform float u_edgeWidth;

/**
 * @label Specular Power
 * @default 32.0
 * @range 1.0, 128.0
 */
uniform float u_specPower;

/**
 * @label Specular Intensity
 * @default 0.6
 * @range 0.0, 2.0
 */
uniform float u_specIntensity;

/**
 * @label Fresnel Intensity
 * @default 0.3
 * @range 0.0, 2.0
 */
uniform float u_fresnelIntensity;

/**
 * @label Blur
 * @default 0.0
 * @range 0.0, 5.0
 */
uniform float u_blur;

/**
 * @label Chromatic Split
 * @default 0.0
 * @range 0.0, 1.0
 */
uniform float u_split;

/**
 * @label Split Angle
 * @default 0.0
 * @range 0.0, 360.0
 */
uniform float u_splitAngle;

/**
 * @label Effect Falloff
 * @default 60.0
 * @range 0.0, 300.0
 */
uniform float u_falloff;

/**
 * @label Frost
 * @default 0.0
 * @range 0.0, 40.0
 */
uniform float u_frost;

/**
 * @label Frost Grain
 * @default 0.0
 * @range 0.0, 1.0
 */
uniform float u_frostGrain;

/**
 * @label Frost Size
 * @default 2.0
 * @range 1.0, 40.0
 */
uniform float u_frostSize;

/**
 * @label Background Opacity
 * @default 0.0
 * @range 0.0, 1.0
 */
uniform float u_bgOpacity;

/**
 * @label Background Shade
 * @default 0.0
 * @range 0.0, 1.0
 */
uniform float u_bgShade;

/**
 * @mouse
 * @label Light Position
 */
uniform vec2 u_mouse;

vec2 g_invRes;
vec3 g_light;
float g_inset;
float g_blur;
float g_split;

const int BLUR_TAPS = 16;
const int FROST_TAPS = 32;

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  vec2 n = mix(mix(hash22(i), hash22(i + vec2(1.0, 0.0)), u.x),
               mix(hash22(i + vec2(0.0, 1.0)), hash22(i + vec2(1.0, 1.0)), u.x), u.y);
  return n * 2.0 - 1.0;
}

float surfaceHeight(float t) {
  float s = 1.0 - t;
  float s4 = s * s * s * s;
  return pow(1.0 - s4, 0.25);
}

float refractDisp(float sinI, float slope, float n) {
  float sinR = clamp(sinI / n, -0.9999, 0.9999);
  return sinR * inversesqrt(1.0 - sinR * sinR) - slope;
}

vec3 sampleBg(vec2 coord) {
  return texture2D(u_backdrop, coord * g_invRes).rgb;
}

vec3 refractedAt(vec2 coord, vec2 dir, float dispR, float dispG, float dispB) {
  if (u_chromatic == 0.0) {
    return sampleBg(coord + dir * dispG);
  }
  return vec3(
    sampleBg(coord + dir * dispR).r,
    sampleBg(coord + dir * dispG).g,
    sampleBg(coord + dir * dispB).b
  );
}

vec4 lensColor(vec2 coord) {
  vec4 sdf = texture2D(u_sdf, coord * g_invRes);

  float sd = sdf.r - g_inset;

  float edge = smoothstep(-1.0, 1.0, sd);
  float ew = max(u_edgeWidth, 1.0);
  float t = clamp(sd / ew, 0.0, 1.0);

  vec2 borderDir = -normalize(sdf.gb + 1e-6);

  float delta = 0.001;
  float h1 = surfaceHeight(clamp(t - delta, 0.0, 1.0));
  float h2 = surfaceHeight(clamp(t + delta, 0.0, 1.0));
  float slope = (h2 - h1) * (0.5 / delta);

  float sinI = slope * inversesqrt(1.0 + slope * slope);

  float dispG = refractDisp(sinI, slope, u_ior) * ew;

  float dispR = dispG;
  float dispB = dispG;
  if (u_chromatic != 0.0) {
    dispR = refractDisp(sinI, slope, u_ior - u_chromatic) * ew;
    dispB = refractDisp(sinI, slope, u_ior + u_chromatic) * ew;
  }

  vec3 refracted;

  if (u_frost <= 0.0) {
    refracted = refractedAt(coord, borderDir, dispR, dispG, dispB);
  } else {

    vec2 fp = coord / max(u_frostSize, 1.0);
    vec2 grain = (noise2(fp) + 0.5 * noise2(mat2(0.8, 0.6, -0.6, 0.8) * fp * 2.03 + 7.1)) * u_frostGrain * u_frost;

    refracted = vec3(0.0);
    for (int k = 0; k < FROST_TAPS; k++) {
      float fk = float(k) + 0.5;
      float a = fk * 2.39996323;
      vec2 tap = grain + vec2(cos(a), sin(a)) * sqrt(fk / float(FROST_TAPS)) * u_frost;
      refracted += refractedAt(coord + tap, borderDir, dispR, dispG, dispB);
    }
    refracted /= float(FROST_TAPS);
  }

  refracted = mix(refracted, vec3(1.0 - u_bgShade), u_bgOpacity);

  vec3 N = normalize(vec3(-slope * borderDir, 1.0));
  vec3 R = reflect(-g_light, N);
  float spec = pow(max(R.z, 0.0), u_specPower);
  float fresnel = pow(1.0 - N.z, 3.0);

  vec3 col = refracted + vec3(spec * u_specIntensity + fresnel * u_fresnelIntensity);

  return vec4(col * edge, edge);
}

vec4 lensBlurred(vec2 coord) {

  if (u_blur <= 0.0) {
    return lensColor(coord);
  }
  vec4 sum = lensColor(coord);
  for (int i = 0; i < BLUR_TAPS; i++) {
    float fi = float(i) + 0.5;
    float a = fi * 2.39996323;
    float r = sqrt(fi / float(BLUR_TAPS)) * g_blur;
    sum += lensColor(coord + vec2(cos(a), sin(a)) * r);
  }
  return sum / (float(BLUR_TAPS) + 1.0);
}

void main() {
  g_invRes = 1.0 / u_resolution;

  vec2 d = u_resolution * 0.5 - u_mouse;
  d.y -= 0.1;
  d = normalize(d) * max(length(d), 1.0);
  g_light = normalize(vec3(d, length(d)));

  float splitPx = u_blur * u_split;
  g_inset = u_blur + splitPx;

  vec2 coord = gl_FragCoord.xy;

  float amount = 1.0 - clamp(
    (texture2D(u_sdf, coord * g_invRes).r - g_inset) / max(u_falloff, 1e-3),
    0.0, 1.0);
  g_blur = u_blur * amount;
  g_split = splitPx * amount;

  if (splitPx <= 0.0) {
    gl_FragColor = lensBlurred(coord);
    return;
  }

  float sa = radians(u_splitAngle);
  vec2 off = vec2(cos(sa), sin(sa)) * g_split;

  vec4 lr = lensBlurred(coord + off);
  vec4 lg = lensBlurred(coord);
  vec4 lb = lensBlurred(coord - off);

  gl_FragColor = vec4(lr.r, lg.g, lb.b, max(max(lr.a, lg.a), lb.a));
}
