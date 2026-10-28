/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

#define u_fit 0.0

#define u_size 1.0

#define u_outside vec3(0.0000, 0.0000, 0.0000)

#define u_outsideOpacity 0.0

#define u_backdropColor vec3(0.8275, 0.8314, 0.8706)

#define u_backdropOpacity 0.0

#define u_backdropSize 0.84

#define u_backdropSoftness 0.37

/**
 * @label Distortion
 * @default 1.82
 * @range 0, 3
 */
uniform float u_refraction;

/**
 * @label Aberration
 * @default 0.79
 * @range 0, 1
 */
uniform float u_aberration;

/**
 * @label Ripple
 * @default 0.0
 * @range 0, 1
 */
uniform float u_ripple;

/**
 * @label Ripple Scale
 * @default 0.37
 * @range 0.3, 3
 */
uniform float u_rippleScale;

#define u_reflection 1.0

#define u_reflectionFalloff 1.0

#define u_fresnelColor vec3(0.0000, 0.0000, 0.0000)

/**
 * @label Fresnel
 * @default 1.16
 * @range 0, 2
 */
uniform float u_fresnel;

/**
 * @label Fresnel Width
 * @default 0.465
 * @range 0, 1
 */
uniform float u_fresnelWidth;

#define u_highlight 0.0

#define u_lightAngle 48.0

/**
 * @label Ball Lens
 * @default 0.11
 * @range 0, 1
 */
uniform float u_ballLens;

/**
 * @label Ball Tint
 * @default 2.0
 * @range 0, 2
 */
uniform float u_ballDensity;

#define u_ballHaze 0.45

#define u_studioDetail 0.55

/** @label Environment Map */
uniform sampler2D u_env;

#define u_envMix 1.0

#define u_envThrough 0.0

#define u_envRotation 0.0

/**
 * @label Depth Of Field
 * @default 0.225
 * @range 0, 1
 */
uniform float u_bokeh;

/**
 * @label Focus
 * @default 0.77
 * @range -1, 1
 */
uniform float u_focus;

/**
 * @label Back Blur
 * @default 0.22
 * @range 0, 4
 */
uniform float u_backBlur;

/**
 * @label Count
 * @default 24.0
 * @range 1, 32
 */
uniform float u_count;

/**
 * @label Ball Size
 * @default 1.0
 * @range 0.2, 2
 */
uniform float u_ballSize;

/**
 * @label Size Variation
 * @default 0.6
 * @range 0, 1
 */
uniform float u_sizeVariation;

/**
 * @label Layout Seed
 * @default 84.0
 * @range 0, 100
 */
uniform float u_layoutSeed;

/**
 * @label Speed
 * @default 1.0
 * @range 0, 3
 */
uniform float u_speed;

/**
 * @label Swirl
 * @default 0.6
 * @range 0, 2
 */
uniform float u_swirl;

/**
 * @label Vortex
 * @default 0.5
 * @range 0, 1
 */
uniform float u_vortex;

#define u_bob 0.4

/**
 * @label Turbulence
 * @default 0.7
 * @range 0, 1
 */
uniform float u_turbulence;

/**
 * @label Spread
 * @default 0.9400000000000001
 * @range 0.1, 1
 */
uniform float u_spread;

#define u_tumble 0.35

/**
 * @label Tilt
 * @default 25.0
 * @range -90, 90
 */
uniform float u_tilt;

/**
 * @label Harmony
 * @range 0, 5
 * @default 3.0
 */
uniform float u_harmony;

/**
 * @label Key Colour
 * @color
 * @default #9e2c2c
 */
uniform vec3 u_keyColor;

#define u_colorSeed 40.0

/**
 * @label Hue Spread
 * @default 1.0
 * @range 0, 1
 */
uniform float u_hueSpread;

/**
 * @label Saturation
 * @default 1.0
 * @range -1, 1
 */
uniform float u_saturation;

/**
 * @label Brightness
 * @default 0.9400000000000001
 * @range -1, 1
 */
uniform float u_brightness;

#define u_variation 1.0

#define u_bgHueMode 2.0

/**
 * @label Background Tint
 * @default 0.12
 * @range 0, 1
 */
uniform float u_bgTint;

/**
 * @label Background Brightness
 * @default 1.0
 * @range 0, 1
 */
uniform float u_bgBrightness;

const int MAX_BALLS = 32;
const int HALF_BALLS = 32;
const float TAU = 6.28318530718;
const float CAMERA_DIST = 5.0;

vec3 fresnelGlow(float facing, float scale) {
  float power = mix(6.0, 1.5, u_fresnelWidth);
  return pow(u_fresnelColor, vec3(2.2)) * u_fresnel * scale * pow(1.0 - facing, power);
}

vec3 toGamma(vec3 c) {
  return pow(clamp(c, 0.0, 1.0), vec3(1.0 / 2.2));
}

vec3 unoklab(vec3 lab) {
  const mat3 m1 = mat3(+1.000000000, +1.000000000, +1.000000000,
      +0.396337777, -0.105561346, -0.089484178,
      +0.215803757, -0.063854173, -1.291485548);
  const mat3 m2 = mat3(+4.076724529, -1.268143773, -0.004111989,
      -3.307216883, +2.609332323, -0.703476310,
      +0.230759054, -0.341134429, +1.706862569);
  vec3 lms = m1 * lab;
  return m2 * (lms * lms * lms);
}

vec3 toLinear(vec3 c) {
  return pow(c, vec3(2.2));
}

vec3 oklab(vec3 lin) {
  const mat3 im1 = mat3(0.4121656120, 0.2118591070, 0.0883097947,
      0.5362752080, 0.6807189584, 0.2818474174,
      0.0514575653, 0.1074065790, 0.6302613616);
  const mat3 im2 = mat3(+0.2104542553, +1.9779984951, +0.0259040371,
      +0.7936177850, -2.4285922050, +0.7827717662,
      -0.0040720468, +0.4505937099, -0.8086757660);
  vec3 lms = im1 * lin;
  return im2 * (sign(lms) * pow(abs(lms), vec3(1.0 / 3.0)));
}

vec3 keyLch() {
  vec3 lab = oklab(toLinear(u_keyColor));
  return vec3(lab.x, length(lab.yz), degrees(atan(lab.z, lab.y)));
}

bool inGamut(vec3 lin) {
  return max(max(lin.r, lin.g), lin.b) <= 1.0 && min(min(lin.r, lin.g), lin.b) >= 0.0;
}

vec3 fitGamut(vec3 lab) {
  vec3 lin = unoklab(lab);
  if (inGamut(lin)) {
    return lin;
  }
  lab.x = clamp(lab.x, 0.0, 1.0);
  float lo = 0.0;
  float hi = 1.0;
  for (int i = 0; i < 6; i++) {
    float mid = 0.5 * (lo + hi);
    if (inGamut(unoklab(vec3(lab.x, lab.yz * mid)))) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return clamp(unoklab(vec3(lab.x, lab.yz * lo)), 0.0, 1.0);
}

vec3 oklch(float l, float c, float hueDeg) {
  float h = radians(hueDeg);
  return fitGamut(vec3(l, c * cos(h), c * sin(h)));
}

vec3 oklchFast(float l, float c, float hueDeg) {
  float h = radians(hueDeg);
  vec2 ab = c * vec2(cos(h), sin(h));
  vec3 lin = unoklab(vec3(l, ab));
  if (!inGamut(lin)) {
    lin = unoklab(vec3(l, ab * 0.6));
  }
  return clamp(lin, 0.0, 1.0);
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 hash4(vec2 p) {
  vec4 q = vec4(p.x * 127.1 + p.y * 311.7) + vec4(0.0, 1553.5, 5697.2, 9843.9);
  return fract(sin(q) * 43758.5453);
}

float harmonyOffset(float slot, float fan) {
  if (u_harmony < 0.5) {
    return (slot - 1.5) * fan;
  }
  if (u_harmony < 1.5) {
    return slot < 2.0 ? 0.0 : 180.0;
  }
  if (u_harmony < 2.5) {
    return slot < 1.0 ? 0.0 : (slot < 2.0 ? 150.0 : (slot < 3.0 ? 210.0 : 0.0));
  }
  if (u_harmony < 3.5) {
    return slot < 1.0 ? 0.0 : (slot < 2.0 ? 120.0 : (slot < 3.0 ? 240.0 : 0.0));
  }
  if (u_harmony < 4.5) {
    return slot * 90.0;
  }
  return 0.0;
}

float harmonySlots() {
  if (u_harmony < 0.5) {
    return 4.0;
  }
  if (u_harmony < 1.5) {
    return 2.0;
  }
  if (u_harmony < 2.5) {
    return 3.0;
  }
  if (u_harmony < 3.5) {
    return 3.0;
  }
  if (u_harmony < 4.5) {
    return 4.0;
  }
  return 1.0;
}

vec3 ballColor(float fi, vec3 key) {
  vec2 seed = vec2(fi * 3.17 + 11.0, u_colorSeed * 1.73 + 5.0);
  float hSlot = hash(seed);
  float hJit = hash(seed + 17.0);
  float hLum = hash(seed + 29.0);
  float hChr = hash(seed + 43.0);

  float fan = mix(10.0, 60.0, u_hueSpread);
  float slot = floor(hSlot * harmonySlots());
  float hue = key.z + harmonyOffset(slot, fan) + (hJit - 0.5) * fan * 0.5;

  float l = key.x + u_brightness * 0.35 + (hLum - 0.5) * 0.3 * u_variation;
  float c = key.y * (1.0 + u_saturation) * (1.0 + (hChr - 0.5) * 0.8 * u_variation);
  return oklchFast(clamp(l, 0.05, 0.98), max(c, 0.0), hue);
}

float backgroundHue(vec3 key) {
  float keyHue = key.z;
  if (u_bgHueMode < 0.5) {
    return keyHue;
  }
  if (u_bgHueMode < 1.5) {
    return keyHue + 180.0;
  }
  float slot = floor(hash(vec2(u_colorSeed * 0.37 + 3.0, 9.0)) * harmonySlots());
  return keyHue + harmonyOffset(slot, mix(10.0, 60.0, u_hueSpread));
}

mat3 rotX(float a) {
  float c = cos(a);
  float sn = sin(a);
  return mat3(1.0, 0.0, 0.0, 0.0, c, sn, 0.0, -sn, c);
}

mat3 rotY(float a) {
  float c = cos(a);
  float sn = sin(a);
  return mat3(c, 0.0, -sn, 0.0, 1.0, 0.0, sn, 0.0, c);
}

mat3 orientation(float t) {
  float nod = u_tumble * 0.6 * sin(t * 0.23);
  float precess = u_tumble * 0.18 * t;
  return rotY(precess) * rotX(radians(u_tilt) + nod);
}

const vec3 RING_CENTER = vec3(0.0, 0.0, 0.18);
const vec3 RING_TOP = vec3(0.0, 0.66, 0.16);
const vec3 RING_BOTTOM = vec3(0.0, -0.66, 0.16);
const vec3 RING_UPPER = vec3(0.42, 0.38, 0.17);
const vec3 RING_LOWER = vec3(0.42, -0.38, 0.17);
const vec3 RING_EQUATOR = vec3(0.45, 0.0, 0.19);
const vec3 RING_OUTER_UPPER = vec3(0.76, 0.2, 0.15);
const vec3 RING_OUTER_LOWER = vec3(0.76, -0.2, 0.15);
const float RING_SLOTS = 6.0;

vec4 ballSlot(float fi) {
  if (fi < 1.0) {
    return vec4(RING_CENTER, 0.0);
  }
  if (fi < 2.0) {
    return vec4(RING_TOP, 0.0);
  }
  if (fi < 3.0) {
    return vec4(RING_BOTTOM, 0.0);
  }
  float j = fi - 3.0;
  float ring = mod(j, 5.0);
  float k = floor(j / 5.0);
  if (ring < 0.5) {
    return vec4(RING_EQUATOR, k);
  }
  if (ring < 1.5) {
    return vec4(RING_UPPER, k);
  }
  if (ring < 2.5) {
    return vec4(RING_OUTER_UPPER, k);
  }
  if (ring < 3.5) {
    return vec4(RING_LOWER, k);
  }
  return vec4(RING_OUTER_LOWER, k);
}

float defocus(float z, float bigRadius) {
  float d = z - u_focus * bigRadius;
  float amount = d < 0.0 ? -d * u_backBlur : d;
  return u_bokeh * 0.18 * amount;
}

float softness(vec4 b, float bigRadius) {
  float blur = defocus(b.z, bigRadius);
  return clamp(1.5 * blur / max(b.w - blur, 1e-4), 0.0, 1.0);
}

vec3 capsuleAxis() {
  return u_resolution.x >= u_resolution.y ? vec3(1.0,0.0,0.0) : vec3(0.0,1.0,0.0);
}
float capsuleHalf(float r) {
  return (max(u_resolution.x,u_resolution.y) / min(u_resolution.x,u_resolution.y) - 1.0) * r;
}
float pillSdf(vec3 p, float r) {
  vec3 a = capsuleAxis();
  vec2 q = p.xy-a.xy*clamp(dot(p,a),-capsuleHalf(r),capsuleHalf(r));
  float bevel = 0.12*r;
  vec2 d = vec2(length(q)-r+bevel,abs(p.z)-0.78*r+bevel);
  return length(max(d,0.0))+min(max(d.x,d.y),0.0)-bevel;
}
vec3 capsuleNormal(vec3 p, float r) {
  vec2 e=vec2(0.0002*r,0.0);
  return normalize(vec3(pillSdf(p+e.xyy,r)-pillSdf(p-e.xyy,r),pillSdf(p+e.yxy,r)-pillSdf(p-e.yxy,r),pillSdf(p+e.yyx,r)-pillSdf(p-e.yyx,r)));
}
float cylinderHitUnused(vec3 ro, vec3 rd, float r) {
  vec3 a = capsuleAxis();
  float h = capsuleHalf(r);
  float ox = dot(ro,a), dx = dot(rd,a);
  vec3 op = ro-a*ox, dp = rd-a*dx;
  float aa = dot(dp,dp), bb = dot(op,dp);
  float disc = bb*bb-aa*(dot(op,op)-r*r);
  float best = 1e9;
  if (disc >= 0.0 && aa > 0.000001) {
    float root = sqrt(disc);
    float t0 = (-bb-root)/aa, t1 = (-bb+root)/aa;
    if (t0 > 0.00001 && abs(ox+t0*dx) <= h) best = min(best,t0);
    if (t1 > 0.00001 && abs(ox+t1*dx) <= h) best = min(best,t1);
  }
  for (int k=0;k<2;k++) {
    float s = k==0 ? -1.0 : 1.0;
    vec3 oc = ro-a*h*s;
    float b = dot(oc,rd);
    float d = b*b-dot(oc,oc)+r*r;
    if (d >= 0.0) {
      float root = sqrt(d);
      float t0 = -b-root, t1 = -b+root;
      if (t0 > 0.00001 && s*(ox+t0*dx) >= h) best = min(best,t0);
      if (t1 > 0.00001 && s*(ox+t1*dx) >= h) best = min(best,t1);
    }
  }
  return best < 1e8 ? best : -1.0;
}

float capsuleHit(vec3 ro, vec3 rd, float r) {
  float t=0.0005*r;
  for (int i=0;i<80;i++) {
    float d=abs(pillSdf(ro+rd*t,r));
    if (d < 0.00015*r) return t;
    t+=max(d*0.85,0.0001*r);
    if (t>20.0*r) break;
  }
  return -1.0;
}

vec4 ball(float fi, float t, float bigRadius, mat3 tilt) {
  vec4 h = hash4(vec2(fi * 7.31 + 3.0, u_layoutSeed * 2.11 + 1.0));
  vec4 g = fract(h.wzyx * 7.31 + h.yxwz * 3.17 + 0.37);

  vec4 slot = ballSlot(fi);
  float rho = slot.x;
  float room = slot.z;

  float ringSeed = hash(vec2(rho * 13.0 + slot.y * 7.0, u_layoutSeed * 0.53 + 2.0));
  float rate = u_swirl * mix(1.0, 1.6 - rho, u_vortex) * (slot.y < 0.0 ? 0.8 : 1.0);

  float w = 0.12 + 0.18 * ringSeed;
  float breathe = t - (0.4 / w) * cos(w * t + ringSeed * TAU);
  float ang = ringSeed * TAU + slot.w * TAU / RING_SLOTS + rate * breathe;
  vec3 pos = vec3(rho * cos(ang), slot.y, rho * sin(ang));

  float axisShrink = rho < 0.01 ? 0.72 : 1.0;
  float radius = room * axisShrink * u_ballSize * mix(1.0, mix(0.45, 1.0, h.w), u_sizeVariation);

  float tempo = rho < 0.01 ? 2.0 : 1.0;
  vec3 drift = sin(t * tempo * (vec3(0.25, 0.2, 0.3) + vec3(0.4, 0.35, 0.4) * h.xyz) + g.xyz * TAU);

  vec3 jitter = 0.35 * (1.0 - 2.0 * drift * drift);
  vec3 wander = u_turbulence * (drift + jitter);
  wander.y += u_bob * sin(t * (0.6 + g.w) + h.z * TAU);
  wander /= max(1.0, length(wander));
  pos += wander * max(room - radius, 0.0) * 0.95;

  float scale = bigRadius * u_spread;
  pos = tilt * (pos * scale);
  vec3 a = capsuleAxis();
  pos += a * capsuleHalf(bigRadius) * sin(fi * 2.399963 + u_layoutSeed * 0.13 + t * 0.17);
  float ballRadius = min(radius * scale, bigRadius * 0.8);
  vec3 axisPoint = a * clamp(dot(pos,a), -capsuleHalf(bigRadius), capsuleHalf(bigRadius));
  vec3 radial = pos-axisPoint;
  pos = axisPoint + radial * min(1.0, (bigRadius-ballRadius-0.015)/max(length(radial),0.0001));
  pos.z = clamp(pos.z, -max(0.76*bigRadius-ballRadius,0.0), max(0.76*bigRadius-ballRadius,0.0));
  float depth = clamp((0.76*bigRadius-pos.z)/(1.52*bigRadius),0.0,1.0);
  float magnification = 1.15 + u_refraction * (0.2 + 2.2*depth*depth);
  ballRadius *= magnification;

  pos.z = min(pos.z, 0.70*bigRadius-ballRadius);
  return vec4(pos, ballRadius);
}

float sphereHit(vec3 ro, vec3 rd, vec3 c, float r) {
  vec3 oc = ro - c;
  float b = dot(oc, rd);
  float cc = dot(oc, oc) - r * r;
  float disc = b * b - cc;
  if (disc < 0.0) {
    return -1.0;
  }
  float th = -b - sqrt(disc);
  return th > 0.0 ? th : -1.0;
}

struct Hit {
  float t;
  float index;
  vec4 ball;
};

vec3 lightDir() {
  float a = radians(u_lightAngle);
  return normalize(vec3(cos(a), sin(a), 0.9));
}

float softbox(vec2 azEl, vec2 centre, vec2 halfSize) {
  vec2 d = abs(azEl - centre);
  d.x = min(d.x, 360.0 - d.x);
  vec2 inside = 1.0 - smoothstep(halfSize * 0.7, halfSize, d);
  return inside.x * inside.y;
}

float softboxes(vec3 dir) {
  vec2 azEl = vec2(degrees(atan(dir.x, -dir.z)), degrees(asin(clamp(dir.y, -1.0, 1.0))));
  float keyAz = u_lightAngle - 90.0;
  float w = softbox(azEl, vec2(keyAz, 30.0), vec2(22.0, 28.0));
  w += 0.7 * softbox(azEl, vec2(keyAz + 110.0, 10.0), vec2(14.0, 40.0));
  w += 0.5 * softbox(azEl, vec2(keyAz - 130.0, -5.0), vec2(30.0, 12.0));
  return w;
}

vec3 envImage(vec3 dir) {
  float az = atan(dir.x, -dir.z) + radians(u_envRotation);
  vec2 uv = vec2(fract(az / TAU + 0.5), 0.5 + asin(clamp(dir.y, -1.0, 1.0)) / 3.14159265);
  return texture2D(u_env, uv).rgb;
}

vec3 studioPlain(vec3 dir, vec3 bgLo) {
  float sky = smoothstep(-0.6, 0.8, dir.y);
  vec3 c = mix(bgLo * 0.75, vec3(1.0), sky);
  float spot = pow(max(dot(dir, lightDir()), 0.0), 20.0);
  return c + spot * 0.9;
}

vec3 studioEnv(vec3 dir, vec3 bgLo) {
  return studioPlain(dir, bgLo) + softboxes(dir) * u_studioDetail * 0.8;
}

vec3 studioEnvImage(vec3 dir, vec3 bgLo) {
  vec3 c = studioEnv(dir, bgLo);
  if (u_envMix > 0.001) {
    c = mix(c, envImage(dir) * 1.15, u_envMix);
  }
  return c;
}

vec3 bgEnv(vec3 dir, vec3 bgHi, vec3 bgLo, float detail) {
  float v = smoothstep(-0.9, 0.9, dir.y);
  vec3 c = mix(bgLo, bgHi, v);
  float glow = pow(max(dot(dir, lightDir()), 0.0), 3.0);
  c += glow * 0.18 * bgHi;
  c *= 1.0 - detail * 0.3 + softboxes(dir) * detail * 0.45;
  if (u_envThrough > 0.001) {
    c = mix(c, envImage(dir) * mix(vec3(1.0), bgHi, 0.35), u_envThrough);
  }
  return c;
}

vec3 exitEnv(vec3 ro, vec3 rd, float ior, float bigRadius, vec3 bgHi, vec3 bgLo, float detail) {
  float th = max(capsuleHit(ro, rd, bigRadius), 0.0);
  vec3 p = ro + rd * th;
  vec3 n = capsuleNormal(p, bigRadius);
  vec3 outDir = refract(rd, -n, ior);
  if (dot(outDir, outDir) < 0.5) {
    outDir = reflect(rd, -n);
  }
  float thickness = clamp(th / (2.0 * bigRadius), 0.0, 1.0);
  return bgEnv(outDir, bgHi, bgLo, detail) * mix(0.93, 1.0, thickness);
}

struct Lens {
  vec3 n;
  float chord;
  vec3 e;
  vec3 rdOut;
};

Lens lensThrough(vec3 ro, vec3 rd, vec4 b, float th, float lensScale) {
  Lens l;
  vec3 q = ro + rd * th;
  l.n = (q - b.xyz) / b.w;
  float opticalDepth = clamp((0.7-b.z)/1.5,0.0,1.0);
  float ballIor = 1.0 + u_ballLens * (0.5+1.4*opticalDepth) * lensScale;
  vec3 rdIn = refract(rd, l.n, 1.0 / ballIor);
  if (dot(rdIn, rdIn) < 0.5) {
    rdIn = rd;
  }
  l.chord = 2.0 * b.w * max(dot(-rdIn, l.n), 0.0);
  l.e = q + rdIn * l.chord;
  vec3 ne = (l.e - b.xyz) / b.w;
  l.rdOut = refract(rdIn, -ne, ballIor);
  if (dot(l.rdOut, l.rdOut) < 0.5) {
    l.rdOut = rdIn;
  }
  return l;
}

vec3 ballSurface(vec3 ro, vec3 rd, Lens l, vec4 b, float bigRadius, vec3 col, vec3 behind,
    vec3 bgLo, float tintScale) {

  float path = clamp(l.chord / (2.0 * b.w), 0.0, 1.0);
  vec3 transmit = pow(max(col, vec3(0.02)), vec3(u_ballDensity * 1.5 * path * tintScale));
  vec3 result = behind * transmit + col * (1.0 - transmit) * 0.4 * u_ballHaze;

  float blur = max(defocus(b.z, bigRadius), 1e-4);
  float trueR = b.w - blur;
  float soft = softness(b, bigRadius);

  float facing = max(dot(-rd, l.n), 0.0);
  float fres = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
  result = mix(result, studioPlain(reflect(rd, l.n), bgLo), fres * u_reflection * 0.55 * (1.0 - 0.7 * soft));
  result += fresnelGlow(facing, 0.5 * (1.0 - 0.7 * soft));

  vec3 oc = ro - b.xyz;
  float along = dot(oc, rd);
  float dist = sqrt(max(dot(oc, oc) - along * along, 0.0));
  float cover = 1.0 - smoothstep(trueR - blur, trueR + blur, dist);

  vec3 h = normalize(lightDir() - rd);
  float sharpness = 90.0 / (1.0 + 8.0 * blur / max(trueR, 1e-4));
  float spec = pow(max(dot(l.n, h), 0.0), sharpness) * (sharpness / 90.0);
  result += spec * u_highlight * 0.8;
  return mix(behind, result, cover);
}

vec3 shadeBallFar(vec4 b, vec3 col, vec3 ro, vec3 rd, float th, float ior, float bigRadius,
    vec3 bgHi, vec3 bgLo, float detail) {
  Lens l = lensThrough(ro, rd, b, th, 1.0 - 0.7 * softness(b, bigRadius));
  vec3 behind = exitEnv(l.e, l.rdOut, ior, bigRadius, bgHi, bgLo, detail);
  return ballSurface(ro, rd, l, b, bigRadius, col, behind, bgLo, 0.6);
}

vec3 traceChannel(vec3 p1, vec3 n1, vec3 rd, float ior, float bigRadius, vec3 bgHi, vec3 bgLo,
    float detail, Hit near, vec3 nearCol, Hit far, vec3 farCol) {
  vec3 rdIn = refract(rd, n1, 1.0 / ior);
  if (dot(rdIn, rdIn) < 0.5) {
    rdIn = rd;
  }
  vec3 ro = p1 + rdIn * 1e-4;
  if (near.index < 0.0) {
    return exitEnv(ro, rdIn, ior, bigRadius, bgHi, bgLo, detail);
  }
  float th = sphereHit(ro, rdIn, near.ball.xyz, near.ball.w);
  if (th < 0.0) {
    return exitEnv(ro, rdIn, ior, bigRadius, bgHi, bgLo, detail);
  }
  Lens l = lensThrough(ro, rdIn, near.ball, th, 1.0 - 0.7 * softness(near.ball, bigRadius));
  vec3 behind;
  float thFar = far.index < 0.0 ? -1.0 : sphereHit(l.e, l.rdOut, far.ball.xyz, far.ball.w);
  if (thFar > 0.0) {
    behind = shadeBallFar(far.ball, farCol, l.e, l.rdOut, thFar, ior, bigRadius, bgHi, bgLo, detail);
  } else {
    behind = exitEnv(l.e, l.rdOut, ior, bigRadius, bgHi, bgLo, detail);
  }
  return ballSurface(ro, rdIn, l, near.ball, bigRadius, nearCol, behind, bgLo, 1.0);
}

float channelCover(vec3 p1, vec3 n1, vec3 rd, float ior, float bigRadius, Hit near) {
  vec3 rdIn = refract(rd, n1, 1.0 / ior);
  if (dot(rdIn, rdIn) < 0.5) {
    rdIn = rd;
  }
  vec3 ro = p1 + rdIn * 1e-4;
  vec3 oc = ro - near.ball.xyz;
  float along = dot(oc, rdIn);
  if (along > 0.0) {
    return 0.0;
  }
  float dist = sqrt(max(dot(oc, oc) - along * along, 0.0));
  float blur = max(defocus(near.ball.z, bigRadius), 1e-4);
  float trueR = near.ball.w - blur;
  return 1.0 - smoothstep(trueR - blur, trueR + blur, dist);
}

vec3 channelBackground(vec3 p1, vec3 n1, vec3 rd, float ior, float bigRadius, vec3 bgHi, vec3 bgLo,
    float detail) {
  vec3 rdIn = refract(rd, n1, 1.0 / ior);
  if (dot(rdIn, rdIn) < 0.5) {
    rdIn = rd;
  }
  return exitEnv(p1 + rdIn * 1e-4, rdIn, ior, bigRadius, bgHi, bgLo, detail);
}

void separate(inout vec4 a, inout vec4 b, float gap) {
  vec3 delta=b.xyz-a.xyz;
  float distance=length(delta);
  float required=a.w+b.w+gap;
  if (distance < required) {
    vec3 direction=distance>0.00001 ? delta/distance : normalize(vec3(1.0,0.31,0.17));
    vec3 correction=direction*max(required-distance,0.0)*0.5;
    a.xyz-=correction;
    b.xyz+=correction;
  }
}

void confine(inout vec4 b, float bigRadius) {
  vec3 a=capsuleAxis();
  vec3 centre=b.xyz;
  vec3 axisPoint=a*clamp(dot(centre,a),-capsuleHalf(bigRadius),capsuleHalf(bigRadius));
  vec2 radial=centre.xy-axisPoint.xy;
  float available=max(bigRadius-b.w-0.015*bigRadius,0.02*bigRadius);
  centre.xy=axisPoint.xy+radial*min(1.0,available/max(length(radial),0.00001));
  centre.z=clamp(centre.z,-2.5*bigRadius+b.w,0.70*bigRadius-b.w);
  b.xyz=centre;
}

void spacing(vec4 a, vec4 b, float bigRadius, inout float sa, inout float sb) {
  float s=max(length(a.xyz-b.xyz)-0.015*bigRadius,0.0)/max(a.w+b.w,0.00001);
  sa=min(sa,s);
  sb=min(sb,s);
}

vec4 ballAt(float fi, float t, float bigRadius, mat3 tilt) {
  if (fi >= u_count) {
    return vec4(0.0, 0.0, 0.0, -1.0);
  }
  vec4 b = ball(fi, t, bigRadius, tilt);
  b.w += defocus(b.z, bigRadius);
  return b;
}

Hit searchBalls(vec4 balls[HALF_BALLS], vec3 ro, vec3 rd, float skip, float t, float bigRadius,
    mat3 tilt) {
  Hit h;
  h.t = 1e9;
  h.index = -1.0;
  h.ball = vec4(0.0);
  for (int i = 0; i < HALF_BALLS; i++) {
    float fi = float(i);
    if (fi < u_count && fi != skip) {
      float th = sphereHit(ro, rd, balls[i].xyz, balls[i].w);
      if (th > 0.0 && th < h.t) {
        h.t = th;
        h.index = fi;
        h.ball = balls[i];
      }
    }
  }
  if (u_count > float(HALF_BALLS)) {

    float t2 = t + min(h.t, 0.0);
    for (int i = HALF_BALLS; i < MAX_BALLS; i++) {
      float fi = float(i);
      if (fi < u_count && fi != skip) {
        vec4 b = ballAt(fi, t2, bigRadius, tilt);
        float th = sphereHit(ro, rd, b.xyz, b.w);
        if (th > 0.0 && th < h.t) {
          h.t = th;
          h.index = fi;
          h.ball = b;
        }
      }
    }
  }
  return h;
}

void main() {
  vec2 res = u_resolution;
  float shortSide = min(res.x, res.y);

  vec2 p = u_fit > 0.5
      ? (gl_FragCoord.xy - 0.5 * res) / (0.5 * res)
      : (gl_FragCoord.xy - 0.5 * res) / (0.5 * shortSide);
  float t = u_time * u_speed;
  float bigRadius = u_size;

  float screenRadius = bigRadius * CAMERA_DIST / sqrt(CAMERA_DIST * CAMERA_DIST - bigRadius * bigRadius);
  vec2 capsuleP = (gl_FragCoord.xy - 0.5 * res) / (0.5 * shortSide);
  vec2 axis = max(res / shortSide - 1.0, vec2(0.0));
  vec2 capDelta = capsuleP - clamp(capsuleP, -axis, axis);
  float edgePx = (length(capDelta) - 1.0) * 0.5 * shortSide;
  p = capsuleP * bigRadius;
  float cover = 1.0 - smoothstep(-0.75, 0.75, edgePx);
  if (cover <= 0.0) {
    gl_FragColor = vec4(u_outside, u_outsideOpacity);
    return;
  }

  vec3 key = keyLch();
  float bgHue = backgroundHue(key);
  float bgL = mix(0.25, 0.97, u_bgBrightness);
  float bgC = u_bgTint * 0.11;
  vec3 bgHi = oklch(bgL, bgC, bgHue);
  vec3 bgLo = oklch(max(bgL - 0.16, 0.05), bgC * 1.7, bgHue);

  vec2 onAxis = clamp(capsuleP, -axis, axis);
  vec2 delta = capsuleP-onAxis;
  vec2 pc = (onAxis + delta * min(1.0, 0.9999/max(length(delta),0.00001))) * bigRadius;
  vec3 ro = vec3(pc, CAMERA_DIST);
  vec3 rd = vec3(0.0,0.0,-1.0);
  float bevel = 0.12 * bigRadius;
  float d2 = length(pc-clamp(pc,-axis*bigRadius,axis*bigRadius))-bigRadius;
  float bevelX = max(d2+bevel,0.0);
  float frontZ = 0.78*bigRadius-bevel+sqrt(max(bevel*bevel-bevelX*bevelX,0.0));
  vec3 p1 = vec3(pc,frontZ);
  vec3 n1 = capsuleNormal(p1, bigRadius);

  if (u_ripple > 0.0) {
    vec3 q = p1 * (u_rippleScale * 5.0 / bigRadius);
    vec3 wobble = vec3(
        sin(q.y * 1.3 + t * 0.8 + q.z),
        sin(q.x * 1.1 - t * 0.6 + q.z * 0.7),
        sin(q.x * 0.9 + q.y * 0.8 + t * 0.5));
    float bevelMask = 1.0-smoothstep(0.85,0.999,abs(n1.z));
    n1 = normalize(n1 + wobble * u_ripple * mix(0.055,0.35,bevelMask));
  }

  mat3 tilt = orientation(t);
  float ior = 1.0 + u_refraction * 0.6;
  float spread = u_aberration * 0.08 * (0.4 + u_refraction);

  float facing = max(dot(-rd, n1), 0.0);
  float rimMask = mix(1.0, pow(1.0 - facing, 2.5), u_reflectionFalloff);
  float detail = u_studioDetail * rimMask;

  vec3 rdG = refract(rd, n1, 1.0 / ior);
  if (dot(rdG, rdG) < 0.5) {
    rdG = rd;
  }
  vec3 roG = p1 + rdG * 1e-4;
  vec4 balls[HALF_BALLS];
  for (int i = 0; i < HALF_BALLS; i++) {
    balls[i] = ballAt(float(i), t, bigRadius, tilt);
  }

  float gap=0.025*bigRadius;
  for (int pass=0; pass<16; pass++) {
    for (int i=0; i<HALF_BALLS; i+=4) {
      float n=u_count-float(i);
      if (n<=0.0) break;
      vec4 b0=balls[i];
      vec4 b1=balls[i+1];
      vec4 b2=balls[i+2];
      vec4 b3=balls[i+3];
      if (n>1.0) { separate(b0,b1,gap); }
      if (n>2.0) { separate(b0,b2,gap); separate(b1,b2,gap); }
      if (n>3.0) { separate(b0,b3,gap); separate(b1,b3,gap); separate(b2,b3,gap); }
      for (int j=4; j<HALF_BALLS; j++) {
        if (i+j>=HALF_BALLS || float(i+j)>=u_count) break;
        vec4 bj=balls[i+j];
        separate(b0,bj,gap); separate(b1,bj,gap); separate(b2,bj,gap); separate(b3,bj,gap);
        balls[i+j]=bj;
      }
      confine(b0,bigRadius);
      if (n>1.0) confine(b1,bigRadius);
      if (n>2.0) confine(b2,bigRadius);
      if (n>3.0) confine(b3,bigRadius);
      balls[i]=b0;
      balls[i+1]=b1;
      balls[i+2]=b2;
      balls[i+3]=b3;
    }
  }

  float safety[HALF_BALLS];
  for (int i=0; i<HALF_BALLS; i++) safety[i]=1.0;
  for (int i=0; i<HALF_BALLS; i+=4) {
    float n=u_count-float(i);
    if (n<=0.0) break;
    vec4 b0=balls[i];
    vec4 b1=balls[i+1];
    vec4 b2=balls[i+2];
    vec4 b3=balls[i+3];
    float s0=safety[i];
    float s1=safety[i+1];
    float s2=safety[i+2];
    float s3=safety[i+3];
    if (n>1.0) spacing(b0,b1,bigRadius,s0,s1);
    if (n>2.0) { spacing(b0,b2,bigRadius,s0,s2); spacing(b1,b2,bigRadius,s1,s2); }
    if (n>3.0) { spacing(b0,b3,bigRadius,s0,s3); spacing(b1,b3,bigRadius,s1,s3); spacing(b2,b3,bigRadius,s2,s3); }
    for (int j=4; j<HALF_BALLS; j++) {
      if (i+j>=HALF_BALLS || float(i+j)>=u_count) break;
      vec4 bj=balls[i+j];
      float sj=safety[i+j];
      spacing(b0,bj,bigRadius,s0,sj); spacing(b1,bj,bigRadius,s1,sj); spacing(b2,bj,bigRadius,s2,sj); spacing(b3,bj,bigRadius,s3,sj);
      safety[i+j]=sj;
    }
    safety[i]=s0;
    safety[i+1]=s1;
    safety[i+2]=s2;
    safety[i+3]=s3;
  }
  for (int i=0; i<HALF_BALLS; i++) {
    if (float(i)<u_count) balls[i].w*=safety[i];
  }
  Hit near = searchBalls(balls, roG, rdG, -1.0, t, bigRadius, tilt);
  Hit far;
  far.t = 1e9;
  far.index = -1.0;
  far.ball = vec4(0.0);
  vec3 farCol = vec3(0.0);
  if (near.index >= 0.0) {

    Lens lg = lensThrough(roG, rdG, near.ball, near.t, 1.0 - 0.7 * softness(near.ball, bigRadius));

    far = searchBalls(balls, lg.e, lg.rdOut, near.index, t + min(near.t, 0.0), bigRadius, tilt);
    if (far.index >= 0.0) {
      farCol = ballColor(far.index, key);
    }
  }
  vec3 nearCol = near.index >= 0.0 ? ballColor(near.index, key) : vec3(0.0);

  vec3 interior = traceChannel(p1, n1, rd, ior, bigRadius, bgHi, bgLo, detail, near, nearCol, far, farCol);
  if (spread > 0.0001) {
    vec3 bgR = channelBackground(p1, n1, rd, ior - spread, bigRadius, bgHi, bgLo, detail);
    vec3 bgB = channelBackground(p1, n1, rd, ior + spread, bigRadius, bgHi, bgLo, detail);
    if (near.index >= 0.0) {
      float coverR = channelCover(p1, n1, rd, ior - spread, bigRadius, near);
      float coverB = channelCover(p1, n1, rd, ior + spread, bigRadius, near);

      float coverG = channelCover(p1, n1, rd, ior, bigRadius, near);
      vec3 ballOnly = coverG > 0.001 ? interior : nearCol;
      interior.r = mix(bgR.r, ballOnly.r, coverR);
      interior.b = mix(bgB.b, ballOnly.b, coverB);
    } else {
      interior.r = bgR.r;
      interior.b = bgB.b;
    }
  }

  float f0 = (ior - 1.0) / (ior + 1.0);
  f0 *= f0;
  float fres = f0 + (1.0 - f0) * pow(1.0 - facing, 5.0);
  vec3 color = mix(interior, studioEnvImage(reflect(rd, n1), bgLo), fres * u_reflection * rimMask);

  vec3 h = normalize(lightDir() - rd);
  float ndh = max(dot(n1, h), 0.0);
  color += (pow(ndh, 400.0) * 1.2 + pow(ndh, 30.0) * 0.12) * u_highlight * rimMask;

  color += fresnelGlow(facing, 1.0);

  float grazing = pow(1.0 - facing, 3.0);
  float rimLine = smoothstep(0.75, 1.0, grazing);
  color *= 1.0 - grazing * 0.35 * u_reflection;
  color += rimLine * 0.6 * u_reflection * studioEnv(n1, bgLo);

  color = toGamma(color);

  float backdropR = length(p) / max(screenRadius * u_backdropSize, 1e-4);
  float backdrop = 1.0 - smoothstep(1.0 - u_backdropSoftness, 1.0, backdropR);
  color = mix(color, u_backdropColor, backdrop * u_backdropOpacity);

  gl_FragColor = vec4(mix(u_outside, color, cover), mix(u_outsideOpacity, 1.0, cover));
}
