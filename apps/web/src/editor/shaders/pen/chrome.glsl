/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Depth
 * @default 32.0
 * @range 0.1, 80
 */
uniform float u_depth;

/**
 * @label Bevel Width
 * @default 74.0
 * @range 0.1, 200
 */
uniform float u_bevel;

/**
 * @label Profile
 * @default 0.0
 * @range 0, 1
 */
uniform float u_profile;

/**
 * @label Shoulder
 * @default 0.2
 * @range 0, 0.5
 */
uniform float u_shoulder;

/**
 * @label Tint
 * @color
 * @default #d0d0d0
 */
uniform vec3 u_tint;

#define u_rough 0.06

/**
 * @label Contrast
 * @default 0.96
 * @range 0.2, 2.5
 */
uniform float u_contrast;

#define u_fresnel 0.89

#define u_brush 0.0

#define u_brushScale 1.0

#define u_flow 0.0

#define u_flowRep 4.0

#define u_flowAngle 70.0

#define u_flowSpeed 0.3

#define u_flowContour 0.7

#define u_flowDistort 0.4

#define u_flowSoft 0.3

#define u_flowShift 0.2

/**
 * @label Light Angle
 * @default 202.0
 * @range 0, 360
 */
uniform float u_lightAngle;

/**
 * @label Horizon
 * @default 0.27
 * @range 0, 1
 */
uniform float u_horizon;

/**
 * @label Stripes
 * @default 1.0
 * @range 0, 16
 */
uniform float u_stripeFreq;

/**
 * @label White Stripes
 * @default 0.975
 * @range 0, 1
 */
uniform float u_stripeAmt;

/**
 * @label White Stripe Width
 * @default 0.24
 * @range 0.05, 0.9
 */
uniform float u_lightStripeWidth;

/**
 * @label Dark Stripes
 * @default 0.0
 * @range 0, 1
 */
uniform float u_darkStripeAmt;

/**
 * @label Dark Stripe Width
 * @default 0.32
 * @range 0.05, 0.9
 */
uniform float u_darkStripeWidth;

/**
 * @label Stripe Sharpness
 * @default 0.0
 * @range 0, 1
 */
uniform float u_stripeSharpness;

/**
 * @label Width Randomness
 * @default 0.0
 * @range 0, 1
 */
uniform float u_stripeWidthRandom;

/**
 * @label Sharpness Randomness
 * @default 0.0
 * @range 0, 1
 */
uniform float u_stripeSharpnessRandom;

/**
 * @label Gap Randomness
 * @default 0.0
 * @range 0, 1
 */
uniform float u_stripeGapRandom;

/**
 * @label Invert Environment
 * @range 0, 1
 * @default 0
 */
uniform float u_invertStudio;

float sampleEnvelope_u_envYGradient(float x) {
  x = clamp(x, 0.0, 1.0);
  if (x <= 0.0) return 0.5;
  if (x <= 1.0) return mix(0.5, 0.5, clamp((x - 0.0) / 1.0, 0.0, 1.0));
  return 0.5;
}

/**
 * @label View Tilt
 * @default 0.4
 * @range -1, 1
 */
uniform float u_tilt;

#define u_persp 0.35

/** @label Env Image */
uniform sampler2D u_env;

#define u_envMix 0.0

#define u_envZoom 1.24

#define u_envRotation 178.0

/**
 * @label Env Spin
 * @default 24.0
 * @range -90, 90
 */
uniform float u_sweep;

/**
 * @label Light Spin
 * @default 0.0
 * @range -90, 90
 */
uniform float u_lightSpin;

#define u_wobble 0.59

#define u_wobbleScale 0.5

#define u_wobbleSpeed 0.0

#define u_wobbleDir 0.0

float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float stripeHash(float cell, float seed) {
  return fract(sin(cell * 127.1 + seed * 311.7) * 43758.5453);
}

float studioStripe(float phase, float offset, float seed, float baseWidth) {
  float shifted = phase + offset;
  float cell = floor(shifted);

  float widthNoise = stripeHash(cell, seed);
  float widthTarget = mix(0.45, 1.65, widthNoise);
  float widthScale = clamp(
    mix(1.0, widthTarget, u_stripeWidthRandom * 3.0),
    0.12,
    3.0
  );
  float halfWidth = clamp(baseWidth * widthScale * 0.5, 0.025, 0.475);

  float sharpNoise = stripeHash(cell, seed + 19.37);
  float sharpness = clamp(
    u_stripeSharpness + (sharpNoise - 0.5) * 6.0 * u_stripeSharpnessRandom,
    0.0,
    1.0
  );
  float feather = min(
    mix(0.14, 0.004, sharpness * sharpness),
    max(halfWidth * 0.9, 0.004)
  );

  float gapNoise = stripeHash(cell, seed + 43.91);
  float maxOffset = max(0.0, 0.48 - halfWidth - feather);
  float gapOffset = (gapNoise - 0.5) * 6.0 * maxOffset * u_stripeGapRandom;
  float center = 0.5 + clamp(gapOffset, -maxOffset, maxOffset);
  float localPos = abs(fract(shifted) - center);

  return 1.0 - smoothstep(
    max(0.001, halfWidth - feather),
    min(0.499, halfWidth + feather),
    localPos
  );
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

float chromeRamp(float t, float blur) {
  float c = mix(0.95, 0.08, smoothstep(0.10, 0.10 + blur, t));
  c = mix(c, 0.75, smoothstep(0.16, 0.16 + blur, t));
  c = mix(c, 0.12, smoothstep(0.22, 0.22 + blur, t));
  c = mix(c, mix(0.12, 0.95, smoothstep(0.28, 1.0, t)), smoothstep(0.28, 0.28 + blur, t));
  return c;
}

void wobble(vec2 p, out float w, out vec2 grad) {
  float t = u_time * u_wobbleSpeed;

  float wa = radians(u_wobbleDir);
  float wc = cos(wa);
  float ws = sin(wa);
  vec2 pr = vec2(wc * p.x + ws * p.y, -ws * p.x + wc * p.y);
  vec2 q = pr * u_wobbleScale;
  float inner1 = q.y * 2.3 - t * 1.3;
  float inner2 = q.x * 1.9 + t * 0.8;
  float A = q.x * 3.1 + t * 1.7 + sin(inner1);
  float B = q.y * 2.7 - t + sin(inner2);
  w = (sin(A) + sin(B)) * 0.25;
  vec2 gq = 0.25 * (cos(A) * vec2(3.1, 2.3 * cos(inner1)) + cos(B) * vec2(1.9 * cos(inner2), 2.7));
  vec2 gpr = gq * u_wobbleScale;
  grad = vec2(wc * gpr.x - ws * gpr.y, ws * gpr.x + wc * gpr.y);
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);

  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);

  float aspect = u_resolution.x / u_resolution.y;
  vec2 p = (uv - 0.5) * vec2(aspect, 1.0);

  float bevel = max(u_bevel, 0.1);
  float t01 = clamp(d / bevel, 0.0, 1.0);
  float dome = sqrt(max(1.0 - (1.0 - t01) * (1.0 - t01), 0.0));
  float domeD = (1.0 - t01) / max(dome, 0.02);
  float hD = mix(1.0, domeD, u_profile);

  float dtdd = t01 < 1.0 ? 1.0 / bevel : 0.0;

  float h01 = mix(t01, dome, u_profile);
  float un = 1.0 - h01;
  if (u_shoulder > 0.001 && un < u_shoulder) hD *= un / u_shoulder;

  float w;
  vec2 wgradP;
  wobble(p, w, wgradP);
  vec2 wgradPx = wgradP / u_resolution.y;

  vec2 gradH = u_depth *
    ((hD + 0.35 * u_wobble * w) * dtdd * gdir + 0.35 * u_wobble * t01 * wgradPx);
  vec3 n = normalize(vec3(-gradH, 1.0));

  vec2 vxy = p * u_persp;
  vec3 v = normalize(vec3(-vxy, 1.0));
  vec3 r = 2.0 * dot(n, v) * n - v;

  float lightAng = u_lightAngle + u_time * u_lightSpin;
  float envUp = radians(lightAng - 90.0);
  float cu = cos(envUp);
  float su = sin(envUp);
  vec2 rr = vec2(cu * r.x + su * r.y, -su * r.x + cu * r.y);

  float rot = radians(u_envRotation) + u_time * radians(u_sweep);
  float azim = atan(rr.x, r.z + 1e-4) + rot;
  float elev = rr.y + u_tilt;

  float rough = clamp(u_rough, 0.0, 1.0);
  float soft = mix(0.5, 0.035, u_horizon);
  soft = max(soft, rough * 0.45);
  float horizon = smoothstep(-soft, soft, elev);
  float sky = mix(0.85, 0.5, clamp(elev, 0.0, 1.0));
  float ground = mix(0.04, 0.28, clamp(-elev, 0.0, 1.0));
  float envL = mix(ground, sky, horizon);
  float envY = clamp(elev * 0.5 + 0.5, 0.0, 1.0);
  float yGradient = sampleEnvelope_u_envYGradient(envY);
  envL += (yGradient - 0.5) * 1.4;

  envL = mix(envL, 0.42, rough * 0.6);
  if (u_invertStudio > 0.5) envL = 1.0 - clamp(envL, 0.0, 1.0);

  float stripePhase = azim * u_stripeFreq * 0.15915494309;
  float stripesEnabled = step(0.001, u_stripeFreq);
  float whiteStripe = studioStripe(stripePhase, 0.0, 11.0, u_lightStripeWidth);
  float darkStripe = studioStripe(stripePhase, 0.5, 37.0, u_darkStripeWidth);
  float stripeMask = horizon * stripesEnabled * 0.9;
  envL += u_stripeAmt * whiteStripe * stripeMask;
  envL -= u_darkStripeAmt * darkStripe * stripeMask;

  float back = clamp(-r.z, 0.0, 1.0);
  envL = mix(envL, 0.15, back * back * 0.85);

  float topMask = smoothstep(0.85, 0.98, n.z);
  float la = radians(lightAng);
  vec2 dir = vec2(cos(la), sin(la));
  vec2 perp = vec2(-dir.y, dir.x);
  vec2 sp = gl_FragCoord.xy;
  float streak = vnoise(vec2(dot(sp, perp) * u_brushScale * 0.01, dot(sp, dir) * 0.002));
  envL *= 1.0 + u_brush * topMask * (streak - 0.5) * 0.8;

  envL = clamp(0.45 + (envL - 0.45) * u_contrast, 0.0, 1.6);

  vec3 envC = vec3(envL);
  if (u_envMix > 0.001) {

    vec2 rxy = rr / max(u_envZoom, 0.05);
    float m = 2.0 * sqrt(rxy.x * rxy.x + rxy.y * rxy.y + (r.z + 1.0) * (r.z + 1.0));
    vec2 suv = rxy / max(m, 1e-4) + 0.5;
    suv.x = fract(suv.x + rot * 0.15915494);
    vec3 img = texture2D(u_env, suv).rgb;
    envC = mix(envC, img * (0.4 + 0.8 * envL), u_envMix);
  }

  if (u_flow > 0.001) {
    float fa = radians(u_flowAngle);
    vec2 fdir = vec2(cos(fa), sin(fa));
    vec2 fp = (uv - 0.5) * vec2(aspect, 1.0);
    float dNorm = d / u_resolution.y;
    float phase = mix(dot(fp, fdir), -dNorm * 2.0, u_flowContour) * u_flowRep;
    float nz = vnoise(fp * 3.0 + vec2(u_time * 0.15, -u_time * 0.1));
    phase += u_flowDistort * (nz - 0.5);
    phase -= u_time * u_flowSpeed;
    float fblur = 0.04 + 0.3 * u_flowSoft;
    float shift = u_flowShift * 0.06;
    vec3 flowC = vec3(
      chromeRamp(fract(phase + shift), fblur),
      chromeRamp(fract(phase), fblur),
      chromeRamp(fract(phase - shift), fblur)
    );

    envC = mix(envC, flowC * (0.35 + 0.9 * envL), u_flow);
  }

  float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 5.0) * u_fresnel * 0.7;
  vec3 col = u_tint * envC + u_tint * rim * (0.35 + 0.65 * horizon);

  vec3 hi = max(col - 0.75, 0.0);
  col = clamp(min(col, vec3(0.75)) + hi / (1.0 + 2.0 * hi), 0.0, 1.0);

  col += (hash21(gl_FragCoord.xy) - 0.5) * 0.008;
  col = clamp(col, 0.0, 1.0);

  gl_FragColor = vec4(col, 1.0);
}
