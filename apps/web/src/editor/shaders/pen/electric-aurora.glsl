precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/**
 * @label Size
 * @default 0.42
 * @range 0.1, 0.8
 */
uniform float u_size;

/**
 * @label Horizon
 * @default 0.5
 * @range 0.2, 0.8
 */
uniform float u_horizon;

/**
 * @label Energy
 * @default 0.6
 * @range 0, 1
 */
uniform float u_energy;

/**
 * @label Filaments
 * @default 0.6
 * @range 0, 1
 */
uniform float u_filaments;

/**
 * @label Crown
 * @default 0.6
 * @range 0, 1
 */
uniform float u_crown;

/**
 * @label Spectrum
 * @default 0.5
 * @range 0, 1
 */
uniform float u_spectrum;

/**
 * @label Reflection
 * @default 0.6
 * @range 0, 1
 */
uniform float u_reflection;

/**
 * @label Speed
 * @default 0.5
 * @range 0, 1
 */
uniform float u_speed;

/**
 * @label Tint
 * @color
 * @default #3d7ff0
 */
uniform vec3 u_tint;

float hash3(vec3 p) {
  p = fract(p * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yxz + 33.33);
  return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  vec3 u = f * f * (3.0 - 2.0 * f);
  float a = mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), u.x);
  float b = mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), u.x);
  float c = mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), u.x);
  float d = mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), u.x);
  return mix(mix(a, b, u.y), mix(c, d, u.y), u.z);
}

float fbm3(vec3 p) {
  float s = 0.0;
  float a = 0.5;
  for (int i = 0; i < 6; i++) {
    s += a * vnoise(p);
    p = p * 2.03 + vec3(1.7, 9.2, 3.1);
    a *= 0.5;
  }
  return s / 0.9375;
}

float emission(vec2 q, float t) {
  q.y = max(q.y, 0.0);
  vec2 e = q * vec2(1.1, 1.0);
  float r = length(e);
  float a = atan(e.x, max(e.y, 0.0));

  float side = smoothstep(1.62, 1.15, abs(a));

  float w = fbm3(vec3(a * 1.6, r * 1.4 - t * 0.35, t * 0.45));
  float aw = a + (w - 0.5) * 1.1 * r;

  float gate = smoothstep(0.45, 0.75, fbm3(vec3(aw * 2.2 + 3.0, r * 0.7 - t * 0.5, t * 0.4)));
  float filEnv = smoothstep(0.1, 0.32, r) * smoothstep(1.0, 0.2, r);
  float filaments = 0.0;
  if (filEnv > 0.0) {
    float n = fbm3(vec3(aw * 4.2, r * 0.9 - t * 0.6, t * 0.7));
    float sharp = mix(6.0, 22.0, u_filaments);
    float ridge = 1.0 - abs(2.0 * n - 1.0);
    float fil = pow(ridge, sharp) + 0.12 * pow(ridge, sharp * 0.25);
    float n2 = vnoise(vec3(aw * 7.0, r * 1.5 - t * 0.9, t * 1.1));
    fil += 0.5 * pow(1.0 - abs(2.0 * n2 - 1.0), sharp) * smoothstep(0.8, 0.1, r);
    filaments = fil * mix(gate, 1.0, 0.5 * exp(-r * 4.0)) * filEnv * mix(0.5, 2.6, u_filaments) * (1.0 + 0.5 * exp(-r * 3.0));
  }

  float haze = fbm3(vec3(aw * 3.0, r * 2.5 - t * 0.5, t * 0.3));

  float bodyN = fbm3(vec3(e * vec2(3.0, 4.0) + vec2(w, 0.0), t * 0.5 + 4.0));
  float body = (0.2 + 0.8 * bodyN * bodyN) * exp(-r * 3.6) * 2.6;
  float mist = haze * gate * exp(-r * 2.5) * 0.15;

  float pocketZone = smoothstep(0.12, 0.35, r) * smoothstep(0.95, 0.55, r);
  float cut = 0.0;
  float rim = 0.0;
  if (pocketZone > 0.0) {
    float m = fbm3(vec3(aw * 1.8 + 5.0, r * 2.2 - t * 0.25, t * 0.35 + 7.0));
    cut = smoothstep(0.55, 0.6, m) * pocketZone;
    rim = exp(-pow((m - 0.55) / 0.02, 2.0)) * pocketZone * (0.25 + gate) * exp(-r * 1.2);
  }

  float crown = 0.0;
  if (r > 0.2 && r < 1.6 && u_crown > 0.0) {
    float R = 0.9 + 0.1 * (fbm3(vec3(a * 2.2, 3.0, t * 0.3)) - 0.5) * 2.0;
    float ring = exp(-pow((r - R) / 0.12, 2.0));
    float b = fbm3(vec3(a * 4.0, r * 2.0 - t * 0.2, t * 0.5 + 11.0));
    float blob = smoothstep(0.5, 0.66, b) * ring;
    float blobRim = exp(-pow((b - 0.5) / 0.03, 2.0)) * ring;
    crown = (blob * 0.25 + blobRim * 0.9) * u_crown * smoothstep(1.5, 1.0, abs(a));
  }

  vec2 cq = q - vec2((vnoise(vec3(t * 0.7, 1.0, 2.0)) - 0.5) * 0.16, 0.07);
  float cr = length(cq * vec2(1.7, 3.8));
  float flare = exp(-length(q * vec2(1.6, 14.0)) * 3.0) * (0.3 + 0.7 * haze);
  float core = flare * 0.5;

  if (cr < 8.0) {
    float ct = fbm3(vec3(cq * vec2(7.0, 11.0) + vec2(w * 2.0, 0.0), t * 1.4));
    float speck = vnoise(vec3(cq * vec2(24.0, 32.0), t * 2.0));
    float tex = smoothstep(0.35, 0.75, ct) * (0.5 + speck);
    core += exp(-cr * 2.2) * (0.25 + 1.5 * tex) * 1.35;
  }

  float light = (body + filaments + mist) * (1.0 - cut * 0.9) + rim * 0.7 + crown;
  return light * side + core;
}

void main() {
  vec2 res = u_resolution;
  vec2 p = (gl_FragCoord.xy - 0.5 * res) / res.y;
  float horizon = 0.5 - u_horizon;
  float size = u_size;
  float t = u_time * u_speed * 1.6;

  vec2 q = (p - vec2(0.0, horizon)) / size;

  float flick = 0.85 + 0.3 * vnoise(vec3(t * 2.3, 0.0, 0.0));
  float energy = mix(0.2, 1.5, u_energy) * flick;

  vec3 field;
  if (q.y >= 0.0) {

    float ca = 0.06 * u_spectrum;
    if (u_spectrum == 0.0) {
      field = vec3(emission(q, t));
    } else {
      field.r = emission(q * (1.0 - ca), t);
      field.g = emission(q, t);
      field.b = emission(q * (1.0 + ca), t);
    }
  } else {

    float d = -q.y;
    float rip = (vnoise(vec3(q.x * 1.5, d * 4.0 - t * 0.8, t * 0.4)) - 0.5) * 0.14 * d;
    vec2 m = vec2(q.x * (1.0 + d * 0.25) + rip, d * 1.15);
    float s = 0.0;
    float jit = hash3(vec3(gl_FragCoord.xy, 3.0));
    if (u_reflection != 0.0) {
      for (int i = 0; i < 6; i++) {
        float fi = float(i) + jit;
        s += emission(m + vec2(0.0, fi * 0.05 * (0.3 + d)), t);
      }
    }
    s /= 6.0;
    float streak = 0.55 + 0.45 * vnoise(vec3(q.x * 22.0, d * 1.5, t * 0.6));
    float fade = exp(-d * 1.6);
    field = vec3(s * streak * fade * u_reflection * 1.0);

    float seam = smoothstep(0.0, 0.07, d);
    if (seam < 1.0) {
      vec2 mq = vec2(q.x, d * 1.15);
      float ca = 0.06 * u_spectrum;
      vec3 direct;
      if (u_spectrum == 0.0) direct = vec3(emission(mq, t));
      else direct = vec3(emission(mq * (1.0 - ca), t), emission(mq, t), emission(mq * (1.0 + ca), t));
      field = mix(direct, field, seam);
    }
  }

  vec3 x = field * energy;

  vec3 tint = max(u_tint, vec3(0.02));
  vec3 col = 1.0 - exp(-(x * tint * 1.5 + x * x * vec3(0.45, 0.55, 0.6)));

  vec3 bg = vec3(0.002, 0.006, 0.014);
  bg += vec3(0.006, 0.015, 0.035) * exp(-length(p - vec2(0.0, horizon)) * 3.0);
  col = bg + col * (1.0 - bg);

  float g = hash3(vec3(gl_FragCoord.xy, floor(t * 24.0))) - 0.5;
  col += g * 0.012;

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
