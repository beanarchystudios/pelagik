precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/**
 * @label Angle
 * @default 57
 * @range 0, 180
 */
uniform float u_angle;

/**
 * @label Speed
 * @default 0.4
 * @range -1, 1
 */
uniform float u_speed;

/**
 * @label Core
 * @default 0.15
 * @range -1, 1
 */
uniform float u_core;

/**
 * @label Glow
 * @default 0.6
 * @range 0, 1
 */
uniform float u_glow;

/**
 * @label Spread
 * @default 0.5
 * @range 0, 1
 */
uniform float u_spread;

/**
 * @label Streaks
 * @default 0.6
 * @range 0, 1
 */
uniform float u_streaks;

/**
 * @label Grain
 * @default 0.3
 * @range 0, 1
 */
uniform float u_grain;

float hash21(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 w = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

float layer(float s, float u, float fs, float len, float vel, float t, float seed) {
  return vnoise(vec2(s * fs + seed * 31.7, (u + vel * t) / len + seed * 7.3));
}

vec3 warmRamp(float h) {
  vec3 c = vec3(0.050, 0.070, 0.220);
  c = mix(c, vec3(0.120, 0.220, 0.600), smoothstep(0.00, 0.16, h));
  c = mix(c, vec3(0.200, 0.360, 0.740), smoothstep(0.10, 0.28, h));
  c = mix(c, vec3(0.470, 0.360, 0.740), smoothstep(0.22, 0.42, h));
  c = mix(c, vec3(0.800, 0.400, 0.620), smoothstep(0.34, 0.54, h));
  c = mix(c, vec3(0.920, 0.330, 0.300), smoothstep(0.46, 0.64, h));
  c = mix(c, vec3(0.970, 0.500, 0.150), smoothstep(0.56, 0.74, h));
  c = mix(c, vec3(1.000, 0.720, 0.250), smoothstep(0.66, 0.84, h));
  c = mix(c, vec3(1.000, 0.900, 0.720), smoothstep(0.78, 0.94, h));
  c = mix(c, vec3(1.000, 0.985, 0.960), smoothstep(0.88, 1.00, h));
  return c;
}

vec3 coolRamp(float h) {
  vec3 c = vec3(0.060, 0.080, 0.240);
  c = mix(c, vec3(0.200, 0.320, 0.760), smoothstep(0.00, 0.18, h));
  c = mix(c, vec3(0.880, 0.360, 0.450), smoothstep(0.10, 0.34, h));
  c = mix(c, vec3(0.940, 0.580, 0.720), smoothstep(0.24, 0.46, h));
  c = mix(c, vec3(0.600, 0.790, 0.970), smoothstep(0.34, 0.58, h));
  c = mix(c, vec3(0.950, 0.760, 0.860), smoothstep(0.48, 0.72, h));
  c = mix(c, vec3(1.000, 0.930, 0.800), smoothstep(0.62, 0.88, h));
  c = mix(c, vec3(1.000, 0.985, 0.970), smoothstep(0.78, 1.00, h));
  return c;
}

void main() {
  vec2 res = u_resolution;
  vec2 p = (gl_FragCoord.xy - 0.5 * res) / res.y;
  float t = mod(u_time, 2000.0);
  float v = u_speed * 1.2;
  float ts = t * abs(u_speed) * 2.5;
  float k = u_streaks;

  float a = radians(u_angle);
  vec2 dir = vec2(cos(a), sin(a));
  vec2 nrm = vec2(dir.y, -dir.x);
  vec2 hs = 0.5 * vec2(res.x / res.y, 1.0);
  float sMax = abs(nrm.x) * hs.x + abs(nrm.y) * hs.y;
  float uMax = abs(dir.x) * hs.x + abs(dir.y) * hs.y;

  float u = dot(p, dir);
  float s = dot(p, nrm);

  s += 0.08 * u * u;
  float sN = s / sMax;
  float uN = u / uMax;
  float low = smoothstep(0.1, -0.9, uN);

  float cl = layer(s, u, 1.6, 3.0, v * 0.12, t, 1.0) * 0.6
           + layer(s, u, 4.0, 2.0, v * 0.2, t, 2.0) * 0.4;
  float cw = layer(s, u, 7.0, 1.2, v * 0.3, t, 6.0);

  float f1 = layer(s, u, 90.0, 0.45, v * 0.8, t, 3.0);
  float f2 = layer(s, u, 260.0, 0.25, v, t, 4.0);
  float f3 = layer(s, u, 560.0, 0.16, v * 1.25, t, 5.0);
  float fine = f1 * 0.25 + f2 * 0.4 + f3 * 0.35;

  float c0 = u_core + 0.04 * sin(ts * 0.21);
  float d = sN - c0 + (cl - 0.5) * 0.4 + (fine - 0.5) * 0.05 * k;
  float w = mix(0.4, 1.4, u_spread);
  float side = smoothstep(-0.15, 0.35, d);
  float dw = d / (w * mix(1.0, 1.35, side));
  float beam = exp(-dw * dw * 1.6);
  float lift = mix(0.68, 1.04, smoothstep(-1.0, 0.8, uN));
  float heat = beam * lift * mix(0.75, 1.12, u_glow);

  float lightc = layer(s, u, 2.6, 2.2, v * 0.18, t, 11.0) * 0.6 + cw * 0.4;
  heat *= mix(0.86, 1.1, smoothstep(0.15, 0.85, lightc));
  heat += (cw - 0.5) * 0.06;
  heat = clamp(heat, 0.0, 1.0);

  vec3 col = mix(warmRamp(heat), coolRamp(heat), side);

  float cy = smoothstep(0.55, 0.85, layer(s, u, 3.0, 2.4, v * 0.15, t, 9.0));
  col = mix(col, vec3(0.500, 0.820, 0.950), cy * low * smoothstep(0.14, 0.32, heat) * smoothstep(0.55, 0.38, heat) * 0.8);

  col *= 1.0 + (fine - 0.5) * 0.3 * k * (1.0 - 0.75 * smoothstep(0.8, 1.0, heat));

  float g1 = layer(s, u, 300.0, 0.5, v * 1.1, t, 7.0);
  float g2 = layer(s, u, 140.0, 0.8, v * 0.9, t, 8.0);
  float clump = smoothstep(0.45, 0.85, layer(s, u, 5.0, 1.0, v * 0.5, t, 12.0));
  float str = (pow(g1, 22.0) + 0.4 * pow(g2, 24.0)) * clump;
  vec3 sc = min(col * 1.25 + 0.3, 1.0);
  col = 1.0 - (1.0 - col) * (1.0 - sc * min(str, 1.0) * k * 0.85);

  float dh = (sN - c0 + (cl - 0.5) * 0.3) / (w * 1.6);
  float haze = exp(-dh * dh * 2.5) * pow(lift, 6.0) * u_glow;
  col = mix(col, vec3(1.0, 0.96, 0.92), haze * 0.3);

  float burn = smoothstep(0.76, 1.04, heat) * u_glow;
  col = mix(col, vec3(1.0, 0.985, 0.965), burn);

  float g = hash21(gl_FragCoord.xy + floor(t * 24.0) * vec2(13.1, 7.7)) - 0.5;
  col += g * 0.09 * u_grain;

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
