/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/**
 * @label Key Color
 * @color
 * @default #1f6bff
 */
uniform vec3 u_key;

/**
 * @label Hue Lit
 * @default 0.25
 * @range -1, 1
 */
uniform float u_hueSpread;

/**
 * @label Hue Shadow
 * @default -0.15
 * @range -1, 1
 */
uniform float u_hueShadow;

#define u_highlightCap 0.9550000000000001

#define u_highlightSat 0.9500000000000001

/**
 * @label Thickness
 * @default 0.55
 * @range 0.1, 1.2
 */
uniform float u_thickness;

/**
 * @label Pos Y
 * @default 0
 * @range -1, 1
 */
uniform float u_posY;

/**
 * @label Tilt
 * @default 0
 * @range -1, 1
 */
uniform float u_tilt;

/**
 * @label Curve Amount
 * @default 0.4
 * @range 0, 1
 */
uniform float u_curveAmt;

/**
 * @label Curve Scale
 * @default 0.75
 * @range 0.25, 1.5
 */
uniform float u_curveScale;

/**
 * @label Curve Phase
 * @default 0
 * @range -1, 1
 */
uniform float u_curvePhase;

#define u_curveLean -0.73

#define u_curveSharp 0.0

#define u_curveDetail 0.0

#define u_detailScale 1.2

/**
 * @label Loop Duration
 * @default 10
 * @range 2, 30
 */
uniform float u_loopDur;

/**
 * @label Sweep Width
 * @default 0.6
 * @range 0.1, 1.5
 */
uniform float u_sweepWidth;

#define u_lightOffset 0.035

/**
 * @label Bloom
 * @default 0.75
 * @range 0, 1.5
 */
uniform float u_bloomAmt;

#define u_bodyLevel 0.105

#define u_rimIntensity 0.84

#define u_rimFlare 5.3500000000000005

#define u_rimFollow 0.85

#define u_rimLead 0.64

#define u_rimShadow 0.905

#define u_shadowFloor 1.17

#define u_shadowTint 0.885

#define u_rimWidth 0.915

#define u_motion 1.5

/**
 * @label Flex Amount
 * @default 0.3
 * @range 0, 1
 */
uniform float u_flexAmt;

#define u_travel 0.0

#define u_sway 0.0

/**
 * @label Focus X
 * @default 0
 * @range -1, 1
 */
uniform float u_focusX;

/**
 * @label Focus Y
 * @default 0
 * @range -1, 1
 */
uniform float u_focusY;

/**
 * @label Focus Size
 * @default 0.35
 * @range 0, 2
 */
uniform float u_focusSize;

#define u_focusFalloff 1.51

/**
 * @label Softness
 * @default 0.65
 * @range 0, 2
 */
uniform float u_softness;

#define u_dispersion 2.0

/**
 * @label Glow Spill
 * @default 0.5
 * @range 0, 1
 */
uniform float u_glowSpill;

#define u_voidLift 0.17500000000000002

vec3 toLinear(vec3 c) {
  return pow(c, vec3(2.2));
}

vec3 toGamma(vec3 c) {
  return pow(clamp(c, 0.0, 1.0), vec3(1.0 / 2.2));
}

vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 palette(float t, vec3 keyLin) {
  t = clamp(t, 0.0, 1.2);
  vec3 shadow = keyLin * 0.02;
  vec3 mid = keyLin;
  vec3 hi = mix(mix(keyLin, vec3(1.0), 0.55), clamp(keyLin * 2.2, 0.0, 1.0), u_highlightSat);
  vec3 peak = mix(mix(keyLin, vec3(1.0), 0.9), clamp(keyLin * 3.2, 0.0, 1.0), u_highlightSat);
  if (t < 0.5) return mix(shadow, mid, smoothstep(0.0, 0.5, t));
  if (t < 1.0) return mix(mid, hi, smoothstep(0.5, 1.0, t));
  return mix(hi, peak, smoothstep(1.0, 1.2, t));
}

vec3 shadeRGB(vec3 t, vec3 keyLin) {
  return vec3(
    palette(t.x, keyLin).r,
    palette(t.y, keyLin).g,
    palette(t.z, keyLin).b
  );
}

float softClip(float t, float ceil) {
  float x = t / ceil;
  return ceil * x / pow(1.0 + x * x * x, 1.0 / 3.0);
}

vec2 shapedSin(float th, float lean, float sharp) {
  float t2 = th - lean * sin(th);
  float dt2 = 1.0 - lean * cos(th);
  float s = sin(t2);
  float den = 1.0 + sharp * abs(s);
  float v = s * (1.0 + sharp) / den;
  float dv = cos(t2) * (1.0 + sharp) / (den * den) * dt2;
  return vec2(v, dv);
}

vec2 centerline(float nx, float flex) {
  float w1 = 3.1415927 * u_curveScale;
  float w2 = u_detailScale * w1;
  float a1 = u_curveAmt * 0.35;
  float a2 = u_curveDetail * a1 * 0.6;
  float lean = u_curveLean * 0.8;
  float sharp = u_curveSharp * 3.0;
  float m = u_motion;
  float phBase = u_curvePhase * 3.1415927;

  float mixT = clamp(u_travel * m, 0.0, 1.0);

  vec2 h1s = shapedSin(w1 * nx + phBase + m * u_flexAmt * 0.8 * sin(flex), lean, sharp);
  vec2 h1t = shapedSin(w1 * nx + phBase - flex, lean, sharp);
  vec2 h1 = mix(h1s, h1t, mixT);

  float th2s = w2 * nx + 1.7 - m * u_flexAmt * 1.1 * sin(flex + 1.3);
  float th2t = w2 * nx + 1.7 - flex;
  vec2 h2 = mix(vec2(sin(th2s), cos(th2s)), vec2(sin(th2t), cos(th2t)), mixT);

  float sway = m * u_sway * 0.12 * sin(flex);

  float tiltSlope = u_tilt * (0.35 + 0.9 * abs(u_tilt));
  float y = u_posY * 0.5 + tiltSlope * nx + a1 * h1.x + a2 * h2.x + sway;
  float dy = tiltSlope + a1 * w1 * h1.y + a2 * w2 * h2.y;
  return vec2(y, dy);
}

float shadeT(float q, float L, float Lrim, float beta, float foot) {
  float aq = abs(q);
  float z = sqrt(max(1.0 - q * q, 0.0));

  float haloReach = 0.10 + 0.35 * u_glowSpill + 0.45 * beta;
  float halo = exp(-max(aq - 1.0, 0.0) / max(haloReach, 1.0e-3));
  float tVoid = u_voidLift * 0.10 + halo * (0.25 + 0.75 * L) * u_glowSpill * (0.35 + 0.4 * u_bodyLevel + 0.5 * u_bloomAmt);

  float px = 1.0 / (max(u_thickness, 0.02) * 0.5 * u_resolution.y);
  float bw = 1.5 * px + 0.45 * beta + 0.8 * foot;
  float alpha = 1.0 - smoothstep(1.0 - bw * 0.4, 1.0 + bw, aq);

  if (alpha <= 0.0) return tVoid;

  float body = u_bodyLevel * (0.30 + 0.45 * z);
  float bloom = u_bloomAmt * L * (0.55 + 0.45 * z);

  float sweepMul = mix(1.0, 0.12 + 1.75 * L, max(u_rimFollow, 0.0))
                 * (1.0 - max(-u_rimFollow, 0.0) * 0.9 * L);
  float rimLevel = u_rimIntensity * sweepMul + u_rimFlare * Lrim;
  float melt = 1.0 + 1.2 * u_bloomAmt * L;
  float rimP = mix(14.0, 3.5, u_rimWidth) / melt;

  float zHalf = 1.0 - pow(0.5, 1.0 / rimP);
  float w0 = max(0.5 * zHalf * zHalf, 1.0e-3);
  float sigB = 0.55 * beta;
  float sigE = sqrt(w0 * w0 + sigB * sigB);
  float dq1 = aq - 1.0;

  float ridge = exp(-dq1 * dq1 / (2.0 * sigE * sigE)) * sqrt(w0 / sigE);
  float xfade = (sigB * sigB) / (sigE * sigE);
  float rimShape = mix(pow(1.0 - z, rimP), ridge, xfade);
  float rim = rimShape * rimLevel / (1.0 + 0.8 * u_bloomAmt * L);

  float tTube = body + bloom + rim;

  float dm = clamp(mix(1.0 - z, aq, clamp(0.5 + 1.5 * beta, 0.0, 1.0)), 0.0, 1.0);
  float darkMask = dm * sqrt(dm);

  float tFloor = (0.12 + 0.3 * body) * u_shadowFloor;
  tTube = mix(tTube, min(tTube, tFloor), min(u_rimShadow * L * darkMask * 1.4, 1.0));

  return mix(tVoid, tTube, alpha);
}

float blurShadeT(float q, float L, float Lrim, float beta) {
  float rad = 1.2 * beta;
  if (rad < 1.0e-3) return shadeT(q, L, Lrim, beta, 0.0);
  const int TAPS = 13;
  float foot = 0.1667 * rad;
  float sum = 0.0;
  float wsum = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float oi = float(i) - 6.0;
    float gw = exp(-oi * oi * 0.0666);
    sum += shadeT(q + oi * foot, L, Lrim, beta, foot) * gw;
    wsum += gw;
  }
  return sum / wsum;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  float aspect = u_resolution.x / u_resolution.y;

  vec2 p = uv - 0.5;
  p.x *= aspect;

  float nx = 2.0 * uv.x - 1.0;

  float phase = fract(u_time / max(u_loopDur, 0.1));
  float flex = phase * 6.2831853;

  vec2 cl = centerline(nx, flex);

  float slopeP = cl.y * 2.0 / aspect;
  float halfT = max(u_thickness, 0.02) * 0.5;
  float q = (p.y - cl.x) / sqrt(1.0 + slopeP * slopeP) / halfT;

  vec2 focusC = vec2(u_focusX * 0.5 * aspect, u_focusY * 0.5);
  float fd = length(p - focusC);
  float beta = u_softness * smoothstep(u_focusSize * 0.5, u_focusSize * 0.5 + max(u_focusFalloff, 0.05) * 0.5, fd);

  float sigma = 0.25 + 0.9 * u_sweepWidth;
  float P = 2.4 + 5.0 * sigma;
  float xh = (fract(phase + u_lightOffset) - 0.5) * P;
  float dw = (fract((nx - xh) / P + 0.5) - 0.5) * P;
  float L = exp(-dw * dw / (2.0 * sigma * sigma));

  float dwA = (fract((nx - u_rimLead - xh) / P + 0.5) - 0.5) * P;
  float dwB = (fract((nx + u_rimLead - xh) / P + 0.5) - 0.5) * P;
  float Lrim = max(
    exp(-dwA * dwA / (2.0 * sigma * sigma)),
    exp(-dwB * dwB / (2.0 * sigma * sigma))
  );

  float dsp = u_dispersion * beta * 0.09;

  vec3 tRGB;
  if (dsp > 1.0e-4) {
    tRGB = vec3(
      blurShadeT(q * (1.0 + dsp), L, Lrim, beta),
      blurShadeT(q, L, Lrim, beta),
      blurShadeT(q * (1.0 - dsp), L, Lrim, beta)
    );
  } else {
    tRGB = vec3(blurShadeT(q, L, Lrim, beta));
  }

  float tCeil = mix(0.6, 1.2, u_highlightCap);
  tRGB = vec3(softClip(tRGB.x, tCeil), softClip(tRGB.y, tCeil), softClip(tRGB.z, tCeil));

  vec3 keyLin = toLinear(u_key);
  vec3 col = shadeRGB(tRGB, keyLin);

  float aq = abs(q);
  float z = sqrt(max(1.0 - q * q, 0.0));
  float haloReach = 0.10 + 0.35 * u_glowSpill + 0.45 * beta;
  float halo = exp(-max(aq - 1.0, 0.0) / max(haloReach, 1.0e-3));
  float px = 1.0 / (halfT * u_resolution.y);
  float bw = 1.5 * px + 0.9 * beta;
  float alpha = 1.0 - smoothstep(1.0 - bw * 0.4, 1.0 + bw, aq);
  float lit = alpha * (0.5 * L + 0.3 * z) + (1.0 - alpha) * 0.3 * halo * L;
  float litN = smoothstep(0.35, 0.85, lit);
  float darkN = smoothstep(0.35, 0.05, lit);
  vec3 hsv = rgb2hsv(col);
  hsv.x = fract(hsv.x + 0.06 * (u_hueSpread * litN + u_hueShadow * darkN) + 1.0);
  col = hsv2rgb(hsv);

  float dmM = clamp(mix(1.0 - z, aq, 0.5), 0.0, 1.0);
  float wShadow = min(u_rimShadow * L * dmM * sqrt(dmM) * 1.4, 1.0) * alpha;
  vec3 kHsv = rgb2hsv(u_key);
  vec3 shadowDye = toLinear(hsv2rgb(vec3(kHsv.x, sqrt(kHsv.y), mix(0.1, 0.5, u_shadowFloor))));
  col = mix(col, shadowDye, wShadow * u_shadowTint);

  col = toGamma(col);

  col += (hash21(gl_FragCoord.xy) - 0.5) / 255.0;

  gl_FragColor = vec4(col, 1.0);
}
