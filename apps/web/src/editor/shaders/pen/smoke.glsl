precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Letter
 * @default 0.3
 * @range 0, 1
 */
uniform float u_letter;

/**
 * @label Smoke
 * @default 0.7
 * @range 0, 1
 */
uniform float u_smoke;

/**
 * @label Rise
 * @default 0.5
 * @range 0, 1
 */
uniform float u_rise;

/**
 * @label Swirl
 * @default 0.55
 * @range 0, 1
 */
uniform float u_swirl;

/**
 * @label Dust
 * @default 0.6
 * @range 0, 1
 */
uniform float u_dust;

/**
 * @label Carried dust
 * @default 0.5
 * @range 0, 1
 */
uniform float u_carried;

/**
 * @label Fall
 * @default 0.55
 * @range 0, 1
 */
uniform float u_fall;

/**
 * @label Speed
 * @default 0.5
 * @range 0, 1
 */
uniform float u_speed;

/**
 * @label Grain
 * @default 0.5
 * @range 0, 1
 */
uniform float u_grain;

/**
 * @label Tint
 * @color
 * @default #e9ecef
 */
uniform vec3 u_tint;

/**
 * @label Source colour
 * @default 1
 * @range 0, 1
 */
uniform float u_sourceColour;

float aspect;
vec3 bgCol;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
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

float fbm(vec2 p) {
  float s = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    s += a * vnoise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.31;
    a *= 0.5;
  }
  return s / 0.9375;
}

vec4 sourceSample(vec2 p) {
  vec2 uv = p / vec2(aspect, 1.0);
  vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
  vec3 c = texture2D(u_backdrop, clamp(uv, 0.0, 1.0)).rgb;
  float coverage = smoothstep(0.06, 0.55, distance(c, bgCol)) * inside.x * inside.y;
  return vec4(c, coverage);
}

float cov(vec2 p) { return sourceSample(p).a; }

vec3 inheritedTint(vec3 sum, float weight) {
  vec3 source = weight > 0.00001 ? sum / max(weight, 0.00001) : u_tint;
  return mix(u_tint, source, u_sourceColour);
}

void main() {
  vec2 res = u_resolution;
  aspect = res.x / res.y;
  vec2 p = gl_FragCoord.xy / res.y;
  float px = 1.0 / res.y;
  float t = u_time * (0.15 + 1.7 * u_speed) * step(0.001, u_speed);

  bgCol = texture2D(u_backdrop, vec2(0.004)).rgb;

  float rise = 0.12 + 0.6 * u_rise;
  float vr = 0.06;
  vec2 q = vec2(p.x, p.y - vr * t);
  float swirl = u_swirl;

  vec2 r = q * vec2(2.2, 1.9);
  vec2 w1 = vec2(fbm(r + vec2(0.0, 0.11 * t)), fbm(r + vec2(5.2, 1.3) - vec2(0.0, 0.08 * t))) - 0.5;
  vec2 r2 = q * vec2(4.6, 3.9);
  vec2 w2 = vec2(fbm(r2 + 2.0 * w1 + vec2(1.7, 9.2) + 0.13 * t),
                 fbm(r2 + 2.0 * w1 + vec2(8.3, 2.8) - 0.10 * t)) - 0.5;
  vec2 r3 = q * vec2(9.0, 7.5) + 5.0 * swirl * w2;
  float bil = fbm(r3 + vec2(0.0, 0.05 * t));
  float rid = 1.0 - abs(2.0 * fbm(r3 * 1.6 + vec2(3.3, 0.1 * t)) - 1.0);

  vec2 fl = vec2(fbm(q * 16.0 + 2.5 * w2 + vec2(0.0, 0.2 * t)), fbm(q * 16.0 + 2.5 * w2 + vec2(4.1, 7.7 - 0.2 * t))) - 0.5;
  fl += 0.5 * (vec2(vnoise(q * 50.0 + 3.0 * fl + vec2(0.0, 0.5 * t)), vnoise(q * 50.0 + 3.0 * fl + vec2(3.3, -0.5 * t))) - 0.5);

  float ph = 6.2832 * (w1.x + 0.5);

  float fr = floor(u_time * 12.0) * step(0.001, u_speed);
  vec2 blk = floor(gl_FragCoord.xy * 0.5);
  float jn = hash12(blk + fr * 17.31);
  float jr = hash12(blk.yx + fr * 9.13 + 41.0);
  float dens = 0.0;
  float densNear = 0.0;
  float ageSum = 0.0;
  vec3 plumeRGB = vec3(0.0);
  vec3 nearRGB = vec3(0.0);
  const int NS = 64;
  for (int k = 0; k < NS; k++) {
    float f = (float(k) + 0.5) / float(NS);
    float jit = fract(jn + 0.618034 * float(k));
    float f2 = (float(k) + jit) / float(NS);
    float a = pow(f2, 1.5) * rise;
    float an = a / rise;
    float dx = swirl * a * (0.25 * sin(ph + a * 9.0) + 1.8 * w2.x + 1.4 * w1.y);
    float ga = 6.2832 * (0.618034 * float(k) + jr);
    vec2 spread = vec2(cos(ga), 0.7 * sin(ga)) * (0.002 + 0.2 * a) * sqrt(fract(jr + 0.7548 * float(k)));
    vec2 s = p - vec2(dx, a) + spread - (0.022 + 0.08 * smoothstep(0.0, 0.08, a)) * (0.3 + swirl) * (fl + 0.6 * w2);
    float da = 1.5 * sqrt(f) * rise / float(NS);
    float w = exp(-4.0 * an) * da;
    vec4 sampleColour = sourceSample(s);
    float c = sampleColour.a;
    plumeRGB += sampleColour.rgb * c * w;
    nearRGB += sampleColour.rgb * c * exp(-a / 0.03) * da;
    dens += c * w;
    densNear += c * exp(-a / 0.03) * da;
    ageSum += c * w * an;
  }
  float stroke = 0.045;
  float age = ageSum / max(dens, 1e-5);

  vec2 lw = vec2(fbm(p * 26.0 + vec2(0.0, -0.4 * t)), fbm(p * 26.0 + vec2(5.2, -0.4 * t))) - 0.5;
  float base = 0.0;
  vec3 baseRGB = vec3(0.0);
  for (int i = 0; i < 4; i++) {
    float an = 6.2832 * (jr + 0.25 * float(i));
    float rad = 0.0045 * sqrt(fract(jn + 0.618034 * float(i)));
    vec4 sampleColour = sourceSample(p + lw * 0.012 - 0.02 * (0.3 + swirl) * fl + rad * vec2(cos(an), sin(an)));
    base += 0.25 * sampleColour.a;
    baseRGB += 0.25 * sampleColour.rgb * sampleColour.a;
  }
  float eat = smoothstep(0.25, 0.7, fbm(p * vec2(34.0, 24.0) + 1.5 * w2 + vec2(0.0, -0.5 * t)));
  float lcloud = 0.6 + 0.6 * smoothstep(0.25, 0.75, bil);
  float letter = base * u_letter * mix(0.5, 1.0, eat) * lcloud;

  float halo = 0.0;
  vec3 haloRGB = vec3(0.0);
  const int NH = 28;
  for (int k = 0; k < NH; k++) {

    float ga = 6.2832 * (0.618034 * float(k) + 1.5 * fl.x + w2.y);
    float rad = 0.048 * sqrt((float(k) + 0.5) / float(NH));
    vec2 s = p + rad * vec2(cos(ga), 0.85 * sin(ga)) - 0.04 * (0.3 + swirl) * (fl + 0.6 * w2)
           + vec2(0.0, 0.02 * (0.6 + fl.y));
    vec4 sampleColour = sourceSample(s);
    halo += sampleColour.a / float(NH);
    haloRGB += sampleColour.rgb * sampleColour.a / float(NH);
  }

  float core = 0.5 * densNear / 0.03 + 1.2 * halo + 0.5 * base;
  float plume = dens / stroke;
  vec3 coreRGB = 0.5 * nearRGB / 0.03 + 1.2 * haloRGB + 0.5 * baseRGB;
  vec3 cloudTint = inheritedTint(coreRGB, core);
  vec3 plumeTint = inheritedTint(plumeRGB, dens);
  vec3 letterTint = inheritedTint(baseRGB, base);
  float body = smoothstep(0.36, 0.74, bil);

  float cn = (bil - 0.55) * 0.9 + (rid - 0.65) * 0.45;
  float cloud = smoothstep(0.3, 0.95, 0.75 * core + cn) * smoothstep(0.05, 0.3, core);

  float silk = 1.0 - abs(2.0 * fbm(r3 * 3.0 + 2.0 * w2 + vec2(1.3, 0.25 * t)) - 1.0);
  float shade = 0.18 + 0.45 * body + 0.3 * pow(rid, 4.0) + 0.3 * pow(silk, 3.0);
  float texPlume = min(mix(0.55 + 0.6 * body, 1.4 * body * body * (0.7 + 0.5 * rid), smoothstep(0.05, 0.45, age)), 1.0);
  float pl = 1.3 * plume * texPlume;
  pl = pl / (1.0 + 0.4 * pl);
  float cloudAmount = clamp(cloud * shade * 0.85 * u_smoke / 0.7, 0.0, 1.0);
  float plumeAmount = 1.0 - exp(-pl * 1.2 * u_smoke);
  vec3 smokeRGB = cloudTint * cloudAmount + plumeTint * plumeAmount * (1.0 - cloudAmount);
  float smokeWeight = cloudAmount + plumeAmount * (1.0 - cloudAmount);
  float smoke = 1.0 - (1.0 - cloud * shade * 0.85 * u_smoke / 0.7) * exp(-pl * 1.2 * u_smoke);
  smoke = clamp(smoke, 0.0, 1.0);
  float prox = 1.0 - exp(-2.0 * core);

  float tendril = pow(rid, 6.0) * smoothstep(0.3, 0.6, bil) * prox;
  float tendrilAmount = clamp(tendril * 0.6 * u_smoke, 0.0, 1.0);
  smokeRGB += cloudTint * tendrilAmount * (1.0 - smokeWeight);
  smokeWeight += tendrilAmount * (1.0 - smokeWeight);
  vec3 smokeTint = smokeWeight > 0.00001 ? smokeRGB / max(smokeWeight, 0.00001) : cloudTint;
  smoke = 1.0 - (1.0 - smoke) * (1.0 - tendril * 0.6 * u_smoke);
  float fine = fbm(q * vec2(34.0, 26.0) + 1.5 * w2 + vec2(0.0, 0.3 * t));
  smoke *= mix(1.0, 0.7 + 0.6 * fine, u_grain);

  float fall = 0.12 + 0.6 * u_fall;
  float cell = 0.07;
  float ci = floor(p.x / cell);
  vec3 hs = hash32(vec2(ci, 3.7));
  float xc = (ci + 0.35 + 0.3 * hs.x) * cell;
  float sw = mix(0.006, 0.018, hs.y);

  vec3 streamRGB = u_tint;
  float ySrc = 9.0;
  float yFeed = 9.0;
  float yTop = 0.0;
  float cPrev = cov(vec2(xc, 0.0));
  const int NY = 80;
  for (int j = 1; j <= NY; j++) {
    float yj = float(j) / float(NY);
    vec4 sampleColour = sourceSample(vec2(xc, yj));
    float c = sampleColour.a;
    float edge = step(cPrev, 0.5) * step(0.5, c);
    float ye = yj - (c - 0.5) / max(c - cPrev, 1e-3) / float(NY);
    float candidate = mix(9.0, ye, edge * step(p.y, ye));
    streamRGB = mix(streamRGB, sampleColour.rgb, 1.0 - step(ySrc, candidate));
    ySrc = min(ySrc, candidate);
    yFeed = min(yFeed, mix(9.0, ye, edge));
    yTop = max(yTop, yj * step(0.5, c));
    cPrev = c;
  }
  float d = ySrc - p.y;
  float has = step(ySrc, 2.0);

  float g = 0.22;
  float d0 = 0.002;
  float dd = max(d, 0.0) + d0;
  float tau = t - sqrt(2.0 * dd / g);
  float vel = sqrt(2.0 * g * dd);
  float fan = 1.0 + 3.0 * d;
  float X = (p.x - xc) / fan;

  float dust = 0.0;

  if (has * step(0.0, d) * step(0.001, u_dust) > 0.0) {
  for (int L = 0; L < 2; L++) {
    float lf = float(L);
    float cw = mix(0.0025, 0.005, lf);
    float dt = mix(0.07, 0.2, lf);
    float col = floor(X / cw);
    for (int di = -1; di <= 1; di++) {
      float li = col + float(di);
      vec3 hc = hash32(vec2(li + ci * 57.0, 17.0 + lf * 31.0));
      float jt = floor(tau / dt + hc.x);
      for (int dj = -1; dj <= 1; dj++) {
        float j = jt + float(dj);
        vec3 hp = hash32(vec2(li * 1.37 + j * 0.071 + ci * 7.3, j + lf * 53.0));
        vec3 hq = hash32(vec2(j * 3.11 + lf, li * 0.93 + ci * 3.1 + 11.0));
        float te = (j + hp.x - hc.x) * dt;
        float y = (tau - te) * vel;
        float xl = (li + 0.2 + 0.6 * hp.y) * cw;
        float x = (X - xl) * fan;
        float rr = px * mix(0.7, 1.9, hq.x * hq.x) * (1.0 + 0.5 * lf);
        float r2 = (x * x + y * y) / (rr * rr);
        if (r2 > 40.0) continue;
        float e = exp(-r2);

        float pour = smoothstep(0.42, 0.7, vnoise(vec2(ci * 7.1 + 3.0, te * 0.3)));
        float lane = exp(-(xl * xl) / (sw * sw));
        float amt = pour * lane * mix(1.0, 0.45, lf) * (0.3 + 0.9 * u_dust);
        float on = clamp((amt - hp.z) / 0.1, 0.0, 1.0);
        float tw = 0.6 + 0.4 * sin(6.2832 * (hq.z * 7.0 + t * (0.7 + 1.5 * hq.z)));
        dust += e * on * mix(0.6, 1.6, hq.z) * tw;
      }
    }
  }
  }
  dust *= has * step(0.0, d) * exp(-d / (0.45 * fall)) * smoothstep(0.0, 0.006, d) * step(0.001, u_dust);

  vec3 dustRGB = dust * mix(u_tint, streamRGB, u_sourceColour);
  float carried = 0.0;
  vec3 carriedRGB = vec3(0.0);
  float feedValid = step(yFeed, 2.0);
  float sourceHeight = max(yTop - yFeed, 0.02);
  float material = smoothstep(0.015, 0.14, core + plume);
  float feedReach = 1.0 - smoothstep(0.015, 0.06, abs(p.y - yFeed));
  for (int k = 0; k < 64; k++) {
    float fk = float(k);
    vec3 h = hash32(vec2(ci * 13.7 + fk * 2.31, fk + 419.0));
    vec3 h2 = hash32(vec2(ci * 5.3 + fk, fk * 3.19 + 83.0));
    float startX = (ci + mix(0.12, 0.88, h.y)) * cell;
    float startY = yFeed + sourceHeight * mix(0.08, 0.9, h2.x);
    vec4 startColour = sourceSample(vec2(startX, startY));

    float amount = smoothstep(h2.y * 0.92, h2.y * 0.92 + 0.08, u_carried);
    if (amount <= 0.0) continue;
    float life = mix(22.0, 32.0, h.z);
    float ageP = mod(t + h.x * life, life);
    float releaseAt = life - 2.0;
    float collectAt = life * 0.32;
    float settleAt = releaseAt - 2.0;
    float gather = smoothstep(collectAt, settleAt, ageP);
    float liftTime = min(ageP, collectAt);
    float lift = mix(0.012, 0.022, h2.y) * liftTime;
    float sway = 0.0035 * swirl * (sin(ageP * 0.75 + h2.z * 6.2832) - sin(h2.z * 6.2832));
    float outletX = xc + (h.y - 0.5) * sw * 0.8;
    float pocket = 0.003 * (1.0 - smoothstep(settleAt, releaseAt, ageP));
    float xp = mix(startX + sway, outletX, gather);
    float yp = mix(startY + lift, yFeed + pocket, gather);
    float fallingAge = max(ageP - releaseAt, 0.0);
    yp -= 0.5 * g * fallingAge * fallingAge;
    xp += (h.y - 0.5) * sw * fallingAge * 0.25;
    vec2 delta = p - vec2(xp, yp);
    float radius = px * mix(0.65, 1.55, h2.z * h2.z);
    float r2 = dot(delta, delta) / (radius * radius);
    if (r2 > 40.0) continue;
    float grain = exp(-r2);
    float fade = smoothstep(0.0, 1.5, ageP) * (1.0 - smoothstep(life - 0.7, life, ageP));
    float support = max(material, max(feedReach * gather, step(releaseAt, ageP)));
    float contribution = grain * amount * fade * support * mix(0.22, 0.65, h2.z);
    vec3 grainTint = inheritedTint(startColour.rgb * startColour.a, startColour.a);
    carriedRGB += grainTint * contribution;
    carried += contribution;
  }
  carried *= feedValid;
  dustRGB += carriedRGB * feedValid;
  dust += carried;
  vec3 dustTint = dust > 0.00001 ? dustRGB / max(dust, 0.00001) : u_tint;

  float light = 1.0 - (1.0 - smoke) * (1.0 - letter);
  light = 1.0 - (1.0 - clamp(light, 0.0, 1.0)) * (1.0 - clamp(dust, 0.0, 1.5) * 0.9);

  float gn = hash12(gl_FragCoord.xy + fr * 37.0) - 0.5;

  light *= 1.0 + gn * u_grain * 0.06;

  float sa = clamp(smoke, 0.0, 1.0);
  float la = clamp(letter, 0.0, 1.0);
  float da = clamp(dust * 0.9, 0.0, 1.0);
  vec3 materialRGB = smokeTint * sa + letterTint * la * (1.0 - sa);
  float materialWeight = sa + la * (1.0 - sa);
  materialRGB = materialRGB * (1.0 - da) + dustTint * da;
  materialWeight = materialWeight * (1.0 - da) + da;
  vec3 tint = materialWeight > 0.00001 ? materialRGB / max(materialWeight, 0.00001) : u_tint;
  vec3 colr = bgCol + (tint - bgCol) * clamp(light, 0.0, 1.0);
  gl_FragColor = vec4(colr, 1.0);
}
