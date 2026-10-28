precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Pixel
 * @default 4
 * @range 2, 16
 */
uniform float u_pitch;

/**
 * @label Speed
 * @default 0.22
 * @range 0, 1.5
 */
uniform float u_speed;

/**
 * @label Life
 * @default 2
 * @range 0.1, 4
 */
uniform float u_life;

/**
 * @label Density
 * @default 0.8
 * @range 0, 1
 */
uniform float u_density;

/**
 * @label Blur
 * @default 8
 * @range 0, 40
 */
uniform float u_blur;

/**
 * @label Floor
 * @default 0.1
 * @range 0, 0.8
 */
uniform float u_floor;

/**
 * @label Softness
 * @default 0.6
 * @range 0, 1
 */
uniform float u_soft;

/**
 * @label Dropout
 * @default 0.6
 * @range 0, 1
 */
uniform float u_drop;

/**
 * @label Haze
 * @default 0.4
 * @range 0, 1.5
 */
uniform float u_haze;

/**
 * @label Glitch
 * @default 0.35
 * @range 0, 1
 */
uniform float u_glitch;

/**
 * @label Brightness
 * @default 1.5
 * @range 0.3, 3
 */
uniform float u_bright;

/**
 * @label Tint
 * @color
 * @default #5ec8c6
 */
uniform vec3 u_tint;

float h12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = h12(i);
  float b = h12(i + vec2(1.0, 0.0));
  float c = h12(i + vec2(0.0, 1.0));
  float d = h12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float lumAt(vec2 px) {
  vec2 uv = px / u_resolution;
  vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
  vec3 c = texture2D(u_backdrop, clamp(uv, 0.0, 1.0)).rgb;
  return dot(c, vec3(0.299, 0.587, 0.114)) * inside.x * inside.y;
}

float blurLum(vec2 px, float r) {
  float s = lumAt(px);
  float w = 1.0;
  for (int i = 0; i < 20; i++) {
    float fi = float(i);
    float a = fi * 2.39996;
    float d = sqrt((fi + 0.5) / 20.0) * r;
    s += lumAt(px + vec2(cos(a), sin(a)) * d);
    w += 1.0;
  }
  return s / w;
}

float streaks(vec2 px, float pitch, float vel, float seed, float dens) {
  float c0 = floor(px.x / pitch);
  float sum = 0.0;
  for (int j = -1; j <= 1; j++) {
    float ci = c0 + float(j);
    vec2 hc = h22(vec2(ci, seed));
    float v = vel * (0.55 + 0.9 * hc.x);
    float cellLen = pitch * mix(10.0, 30.0, hc.y);
    float s = px.y + v * u_time + hc.x * 1931.0;
    float k = floor(s / cellLen);
    float u = fract(s / cellLen);

    vec2 hk = h22(vec2(ci * 1.37 + seed, k));
    float ph = u_time * u_life * (0.6 + 0.8 * hk.x) + hk.y;
    float cyc = floor(ph);
    float age = fract(ph);

    vec2 ha = h22(vec2(k + cyc * 17.13, ci + seed * 3.7));
    vec2 hb = h22(vec2(ci - cyc * 5.31, k + seed));
    vec2 hw = h22(vec2(k * 3.17 + cyc * 7.71, ci * 0.73 + seed * 1.9));
    vec2 hx = h22(vec2(ci * 2.11 + cyc * 0.37, k * 1.3 + seed));

    float wr = mix(0.06, 0.32, hw.x) + 0.5 * pow(hx.x, 6.0);
    float half_w = pitch * wr;
    float sig = pitch * mix(0.18, 1.0, u_soft) * mix(0.25, 1.6, pow(hw.y, 1.3));
    float cx = (ci + 0.5 + (hx.y - 0.5) * 0.5) * pitch;
    float dx = abs(px.x - cx);
    float wx = 1.0 - smoothstep(half_w - sig, half_w + sig, dx);

    float on = step(ha.x, dens);
    float len = mix(0.1, 0.95, sqrt(hb.x));
    float off = ha.y * (1.0 - len);
    float a = (u - off) / len;
    float vs = sig / (cellLen * len);
    float body = smoothstep(-0.04 - 2.0 * vs, 0.02 + vs, a) * (1.0 - smoothstep(0.7 - vs, 1.0 + vs, a));
    float profile = mix(1.0, 0.45, clamp(a, 0.0, 1.0));
    float env = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.5, 1.0, age));
    float lvl = 0.45 + 0.55 * hb.y * hb.y;

    float focus = mix(1.0, 0.55, smoothstep(0.3, 1.4, sig / pitch));
    sum += on * env * body * profile * wx * lvl * focus;
  }
  return sum;
}

void main() {
  vec2 px = gl_FragCoord.xy;
  vec2 res = u_resolution;
  float t = u_time;
  float fr = floor(t * 12.0);

  float band = floor(px.y / 24.0);
  float slot = floor(t * 7.0);
  vec2 hg = h22(vec2(band, slot));
  float tear = step(hg.x, u_glitch * 0.12) * (hg.y - 0.5) * u_glitch * 140.0;
  vec2 p = px + vec2(tear, 0.0);

  vec2 wq = p / 300.0 + vec2(0.0, t * 0.25);
  vec2 warp = vec2(vnoise(wq), vnoise(wq + 7.3)) - 0.5;
  vec2 sp = p + warp * (u_blur * 0.6 + 3.0);

  float D = smoothstep(u_floor, u_floor + 0.55, blurLum(sp, u_blur + 1.0));
  D *= sqrt(D);
  float G = smoothstep(u_floor - 0.05, u_floor + 0.5, blurLum(sp, u_blur * 2.5 + 30.0));

  float vel = u_speed * res.y;

  vec2 dq = vec2(p.x / 170.0, (p.y + t * vel * 0.35) / 120.0);
  float m = 0.5 * mix(vnoise(dq), vnoise(dq + 31.7), 0.5 + 0.5 * sin(t * 0.9));
  m += 0.3 * mix(vnoise(dq * 2.3 + 9.1), vnoise(dq * 2.3 + 54.2), 0.5 + 0.5 * sin(t * 1.7 + 1.3));
  m += 0.2 * vnoise(vec2(p.x / 40.0, (p.y + t * vel * 0.6) / 90.0));
  float keep = mix(1.0, smoothstep(0.4, 0.62, m), u_drop);
  D *= 0.08 + 0.92 * keep;

  float sA = streaks(p, u_pitch, vel, 0.0, u_density * D);
  float sB = streaks(p + vec2(u_pitch * 0.5, 0.0), u_pitch * 0.75, vel * 0.7, 11.0, u_density * D * 0.8);
  float sC = streaks(p + vec2(0.0, 77.0), u_pitch * 0.5, vel * 0.5, 37.0, u_density * D * D);
  float rain = (sA + 0.7 * sB + 0.55 * sC) * (0.4 + 0.6 * D);

  float g = h12(px + fr * 37.0);
  float dc = floor(p.x / 2.0);
  float dv = vel * (0.4 + 0.8 * h12(vec2(dc, 5.0)));
  float dash = h12(vec2(dc, floor((p.y + t * dv) / 7.0)));
  dash = dash * dash * dash;
  float haze = u_haze * (0.4 * D + 0.6 * G) * (0.3 + 0.5 * g + 0.9 * dash);

  float dense = G * (0.25 + 0.75 * keep);
  float glow = u_haze * dense * dense;

  float dust = streaks(p + vec2(0.0, 401.0), u_pitch, vel * 1.1, 23.0, 0.035) * (0.25 + 0.5 * D);

  float I = (rain * 1.7 + haze * 0.2 + glow * 0.35 + dust * 0.7) * u_bright;

  float scan = 1.0 - u_glitch * 0.25 * (0.5 + 0.5 * sin(px.y * 2.094));
  float flick = 1.0 + u_glitch * 0.12 * (h12(vec2(fr, 3.0)) - 0.5);
  I *= scan * flick;

  float v = 1.0 - exp(-1.6 * I);
  vec3 c = u_tint * v * 0.85 + vec3(0.6) * smoothstep(0.75, 1.0, v) * v * 0.35;
  c += vec3(0.032, 0.03, 0.04) * (0.45 + 0.9 * g) * (0.7 + 0.3 * dash);
  gl_FragColor = vec4(c, 1.0);
}
