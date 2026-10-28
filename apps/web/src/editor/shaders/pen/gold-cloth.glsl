precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Weave Size
 * @default 4
 * @range 2, 20
 */
uniform float u_scale;

/**
 * @label Weave Depth
 * @default 0.7
 * @range 0, 1
 */
uniform float u_relief;

/**
 * @label Gold Light
 * @color
 * @default #ecd29a
 */
uniform vec3 u_light;

/**
 * @label Gold Dark
 * @color
 * @default #3d2712
 */
uniform vec3 u_dark;

/**
 * @label Shine
 * @default 1
 * @range 0, 2
 */
uniform float u_shine;

/**
 * @label Scratches
 * @default 0.5
 * @range 0, 1
 */
uniform float u_scratches;

/**
 * @label Wear
 * @default 0.25
 * @range 0, 1
 */
uniform float u_wear;

/**
 * @label Edge Rough
 * @default 8
 * @range 0, 30
 */
uniform float u_edge;

/**
 * @label Light Angle
 * @default 135
 * @range 0, 360
 */
uniform float u_angle;

const float PI = 3.14159265;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
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
    p = p * 2.03 + vec2(17.1, 9.3);
    a *= 0.5;
  }
  return v;
}

float weave(vec2 p) {
  float s = max(u_scale, 1.0);
  vec2 q = p / s;

  q += (vec2(vnoise(q * 0.11), vnoise(q * 0.11 + 31.7)) - 0.5) * 1.1;
  q += (vec2(vnoise(q * 0.45 + 5.0), vnoise(q * 0.45 + 51.0)) - 0.5) * 0.3;
  vec2 c = floor(q);
  vec2 f = fract(q);
  float over = 1.0 - 2.0 * mod(c.x + c.y, 2.0);

  float wv = (0.55 + 0.3 * hash21(vec2(c.x, 3.1))) * (0.8 + 0.4 * vnoise(vec2(c.x * 3.0, q.y * 0.8)));
  float wh = (0.55 + 0.3 * hash21(vec2(9.7, c.y))) * (0.8 + 0.4 * vnoise(vec2(q.x * 0.8, c.y * 3.0)));
  float av = (f.x - 0.5) / (0.5 * wv);
  float ah = (f.y - 0.5) / (0.5 * wh);
  float pv = sqrt(max(1.0 - av * av, 0.0));
  float ph = sqrt(max(1.0 - ah * ah, 0.0));

  float hv = pv * (0.55 + 0.45 * over * sin(PI * f.y));
  float hh = ph * (0.55 - 0.45 * over * sin(PI * f.x));

  float fv = vnoise(vec2(p.x * 1.1, p.y * 0.12) + c.x * 13.0);
  float fh = vnoise(vec2(p.x * 0.12, p.y * 1.1) + c.y * 7.0);
  float h = max(hv * (0.65 + 0.35 * fv), hh * (0.65 + 0.35 * fh));
  return h;
}

float segDist(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * t);
}

float scratchLayer(vec2 p, float cs, float salt) {
  vec2 cell = floor(p / cs);
  float cov = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = cell + vec2(float(i), float(j));
      float r0 = hash21(id + salt);
      if (r0 > u_scratches * 0.8) continue;
      float r1 = hash21(id + salt + 1.3);
      float r2 = hash21(id + salt + 2.7);
      float r3 = hash21(id + salt + 4.1);
      vec2 ctr = (id + vec2(r1, r2)) * cs;

      float ang = r3 > 0.8 ? r3 * 2.0 * PI : (r3 - 0.4) * 0.5;
      float len = cs * (0.35 + 0.9 * hash21(id + salt + 5.9));
      vec2 dir = vec2(cos(ang), sin(ang)) * 0.5 * len;
      float w = 0.5 + 1.1 * hash21(id + salt + 7.3);
      float d = segDist(p, ctr - dir, ctr + dir);

      float t = clamp(dot(p - ctr, dir) / dot(dir, dir), -1.0, 1.0);
      w *= 1.0 - t * t;
      cov = max(cov, 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.8, d));
    }
  }
  return cov;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 p = gl_FragCoord.xy;
  float d = texture2D(u_shape, uv).r;

  float erode = 0.0;
  if (u_edge > 0.01) {
    float streak = fbm(p * vec2(0.012, 0.14));
    float grit = vnoise(p * 0.35);

    float chunk = smoothstep(0.6, 0.85, vnoise(p * vec2(0.03, 0.08) + 7.0));
    erode = u_edge * clamp(0.75 * streak + 0.3 * grit + 0.35 * chunk - 0.1, 0.0, 1.2);
  }
  float alpha = u_edge > 0.01 ? smoothstep(erode - 0.75, erode + 0.75, d) : 1.0;

  if (alpha <= 0.0) { gl_FragColor = vec4(0.0); return; }

  float e = 0.5;
  float h = weave(p);
  float hx = weave(p + vec2(e, 0.0));
  float hy = weave(p + vec2(0.0, e));
  float amp = u_relief * max(u_scale, 1.0) * 0.5;
  vec3 n = normalize(vec3(-(hx - h) / e * amp, -(hy - h) / e * amp, 1.0));

  float a = radians(u_angle);
  vec3 L = normalize(vec3(cos(a), sin(a), 0.9));
  vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
  float diff = max(dot(n, L), 0.0);
  float spec = pow(max(dot(n, H), 0.0), 28.0);

  float occl = mix(1.0, smoothstep(0.0, 0.55, h), u_relief);

  float tone = smoothstep(0.28, 0.72, fbm(p / (max(u_scale, 1.0) * 14.0) + 3.7));

  vec3 mid = mix(u_dark, u_light, 0.55) * vec3(1.08, 0.97, 0.78);
  float lum = clamp((0.25 + 0.85 * diff) * (0.5 + 0.8 * tone) * (0.55 + 0.45 * h), 0.0, 1.0);
  vec3 col = lum < 0.5 ? mix(u_dark, mid, lum * 2.0) : mix(mid, u_light, lum * 2.0 - 1.0);
  col *= mix(0.3, 1.0, occl);

  float flake = step(0.9, hash21(floor(p / 1.5) + 0.5));
  vec3 glint = mix(u_light, vec3(1.0, 0.97, 0.88), 0.55);
  col += glint * spec * u_shine * occl * (0.6 + 1.0 * tone + 1.5 * flake);

  float wn = fbm(p / (max(u_scale, 1.0) * 2.0) + 11.0) * 0.6 + vnoise(p * 0.5) * 0.4;
  float wearMask = smoothstep(0.7 - 0.36 * u_wear, 0.74 - 0.36 * u_wear, wn) * step(0.001, u_wear);
  col = mix(col, u_dark * 0.3, wearMask * 0.85);

  float sc = 0.0;
  if (u_scratches > 0.001) {
    sc = max(scratchLayer(p, 70.0, 0.0), scratchLayer(p, 26.0, 19.0) * 0.8);
  }
  col = mix(col, u_dark * 0.2, sc * 0.9);

  col *= mix(0.55, 1.0, smoothstep(erode, erode + 2.0 + u_edge * 0.8, d));

  col = clamp(col, 0.0, 1.0);
  gl_FragColor = vec4(col * alpha, alpha);
}
