precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/**
 * @label Oval
 * @color
 * @default #E8862C
 */
uniform vec3 u_oval;

/**
 * @label Background
 * @color
 * @default #1E4E6E
 */
uniform vec3 u_bg;

/**
 * @label Columns
 * @default 14
 * @range 3, 48
 */
uniform float u_columns;

/**
 * @label Stretch
 * @default 1.35
 * @range 0.3, 3
 */
uniform float u_stretch;

/**
 * @label Wave X
 * @default 0.85
 * @range 0, 0.95
 */
uniform float u_waveX;

/**
 * @label Wave Y
 * @default 0.5
 * @range 0, 0.95
 */
uniform float u_waveY;

/**
 * @label Wavelength
 * @default 12
 * @range 2, 40
 */
uniform float u_wavelength;

/**
 * @label Stagger
 * @default 0
 * @range 0, 2
 */
uniform float u_stagger;

/**
 * @label Randomness
 * @default 0.3
 * @range 0, 1
 */
uniform float u_random;

/**
 * @label Speed
 * @default 0.6
 * @range 0, 3
 */
uniform float u_speed;

/**
 * @label Roundness
 * @default 2.1
 * @range 1.2, 6
 */
uniform float u_round;

/**
 * @label Size
 * @default 1
 * @range 0.5, 1.4
 */
uniform float u_size;

const float TAU = 6.2831853;

vec2 axisWarp(float a, float t, vec3 ph) {
  float k = TAU / u_wavelength;
  float k2 = k * 1.73;
  float k3 = k * 0.47;
  float k4 = k * 2.9;
  float p1 = k * a - t;
  float p2 = k2 * a + t * 0.71 + ph.x;
  float p3 = k3 * a - t * 1.37 + ph.y;
  float p4 = k4 * a + t * 0.53 + ph.z;
  vec2 w1 = vec2(sin(p1) / k, cos(p1));
  vec2 wr = 0.45 * vec2(sin(p2) / k2, cos(p2))
          + 0.35 * vec2(sin(p3) / k3, cos(p3))
          + 0.2 * vec2(sin(p4) / k4, cos(p4));
  return mix(w1, wr, u_random);
}

vec2 axisMap(float a, float amp, float t, vec3 ph) {
  vec2 w = axisWarp(a, t, ph);
  return vec2(a + amp * w.x, 1.0 + amp * w.y);
}

float solveEdge(float c, float bound, float amp, float t, vec3 ph) {
  if (amp == 0.0) return c;
  float lo = c - bound;
  float hi = c + bound;
  float a = c;
  for (int i = 0; i < 16; i++) {
    vec2 m = axisMap(a, amp, t, ph);
    float f = m.x - c;
    if (abs(f) <= 0.000001 * max(1.0, abs(a)) * m.y) return a;
    if (f > 0.0) hi = a; else lo = a;
    float an = a - f / m.y;
    a = (an >= lo && an <= hi) ? an : 0.5 * (lo + hi);
  }
  return a;
}

vec3 axisCell(float g, float amp, float t, vec3 ph) {
  float c = floor(axisMap(g, amp, t, ph).x);
  float bound = amp * (u_wavelength / TAU)
    * mix(1.0, 0.45 / 1.73 + 0.35 / 0.47 + 0.2 / 2.9, u_random);
  float a0 = solveEdge(c, bound, amp, t, ph);
  float a1 = solveEdge(c + 1.0, bound, amp, t, ph);
  return vec3(a0, a1, c);
}

void main() {
  vec2 cell = vec2(u_resolution.x / u_columns, u_resolution.x / u_columns * u_stretch);
  vec2 px = gl_FragCoord.xy - 0.5 * u_resolution;
  vec2 g = px / cell;
  float t = u_time * u_speed;
  float ax = min(u_waveX, 0.95);
  float ay = min(u_waveY, 0.95);

  vec3 cx = axisCell(g.x, ax, t, vec3(1.3, 4.1, 2.2));
  float ty = t * 0.83 + 1.7 - u_stagger * cx.z;
  vec3 cy = axisCell(g.y, ay, ty, vec3(5.2, 0.6, 3.7));

  vec2 lo = vec2(cx.x, cy.x) * cell;
  vec2 hi = vec2(cx.y, cy.y) * cell;
  vec2 size = max(hi - lo, vec2(1e-3));
  vec2 rad = 0.5 * size * u_size;
  vec2 q = (px - 0.5 * (lo + hi)) / rad;

  vec2 a = max(abs(q), 1e-4);
  float n = u_round;
  float s = pow(a.x, n) + pow(a.y, n);
  float r = pow(s, 1.0 / n);

  vec2 gs = pow(a, vec2(n - 1.0)) * pow(s, 1.0 / n - 1.0) / rad;
  float d = (1.0 - r) / max(length(gs), 1e-5);
  float cov = clamp(d + 0.5, 0.0, 1.0);

  float cellPx = min(size.x, size.y);
  float avg = clamp((1.0 - 0.43 / pow(n, 1.1)) * u_size * u_size, 0.0, 1.0);
  cov = mix(avg, cov, smoothstep(1.5, 4.0, cellPx));

  gl_FragColor = vec4(mix(u_bg, u_oval, cov), 1.0);
}
