precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Melt Line
 * @default 0.69
 * @range 0, 1
 */
uniform float u_line;

/**
 * @label Center
 * @default 0.54
 * @range 0, 1
 */
uniform float u_center;

/**
 * @label Angle
 * @default 0
 * @range -180, 180
 */
uniform float u_angle;

/**
 * @label Drag
 * @default 0.75
 * @range 0, 1
 */
uniform float u_drag;

/**
 * @label Spread
 * @default 0.5
 * @range 0, 1
 */
uniform float u_spread;

/**
 * @label Swing
 * @default 0.35
 * @range 0, 1
 */
uniform float u_swing;

/**
 * @label Turns
 * @default 0
 * @range 0, 6
 */
uniform float u_turns;

/**
 * @label Blur
 * @default 0.5
 * @range 0, 1
 */
uniform float u_blur;

/**
 * @label Heat
 * @default 1
 * @range 0, 1
 */
uniform float u_heat;

/**
 * @label Cold
 * @default 0
 * @range 0, 1
 */
uniform float u_cold;

/**
 * @label Grain
 * @default 0.5
 * @range 0, 1
 */
uniform float u_grain;

/**
 * @label Speed
 * @default 0.3
 * @range 0, 1
 */
uniform float u_motion;

/**
 * @label Flow
 * @default 0.4
 * @range 0, 1
 */
uniform float u_flow;

/**
 * @label Sway
 * @default 0.3
 * @range 0, 1
 */
uniform float u_sway;

/**
 * @label Glow
 * @color
 * @default #ff5a1e
 */
uniform vec3 u_glow;

/**
 * @label Ribbon
 * @color
 * @default #e0162a
 */
uniform vec3 u_ribbon;

/**
 * @label Ice
 * @color
 * @default #52c8ff
 */
uniform vec3 u_ice;

/**
 * @label Cold Ribbon
 * @color
 * @default #1f4dff
 */
uniform vec3 u_chill;

/**
 * @label Deep
 * @color
 * @default #1e2238
 */
uniform vec3 u_deep;

float aspect;
float lineY;
float cx;
float dragL;
float tm;
vec2 pivot;
vec2 rotC;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
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

float hashS(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise1(float x) {
  return vnoise(vec2(x, 0.37));
}

vec2 toFrame(vec2 p) {
  vec2 d = p - pivot;
  return pivot + vec2(d.x * rotC.x + d.y * rotC.y, -d.x * rotC.y + d.y * rotC.x);
}

vec2 toMelt(vec2 p) {
  vec2 d = p - pivot;
  return pivot + vec2(d.x * rotC.x - d.y * rotC.y, d.x * rotC.y + d.y * rotC.x);
}

vec3 back(vec2 p) {
  p = toFrame(p);
  vec2 uv = vec2(p.x / aspect, 1.0 - p.y);
  return texture2D(u_backdrop, clamp(uv, 0.0, 1.0)).rgb;
}

float lum(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float swingAt(float h) {

  float sw = u_swing * (3.0 * h * h + 0.35 * h)
    + u_swing * 0.25 * h * (vnoise1(h * 5.0 - tm * 0.3) - 0.5);

  float wl = 0.4 / max(u_turns, 0.01);
  sw += wl * 0.13 * (0.5 + u_swing) * smoothstep(0.0, 0.15, h) * step(0.01, u_turns)
    * sin(h * 6.2831853 / wl - tm * 2.5 * (0.2 + u_flow));

  sw += u_sway * h * (0.7 * sin(tm * 1.7) + 0.25 * sin(tm * 2.9 + h * 6.0));
  return sw;
}

float fanK(float dx) {
  return u_spread * 14.0 * (dx > 0.0 ? 2.2 : 0.8);
}

vec2 melt(vec2 p) {
  float h = max(p.y - lineY, 0.0);
  float ramp = smoothstep(0.0, 0.08, h);
  float sy = p.y > lineY ? lineY + dragL * (1.0 - exp(-h / dragL)) : p.y;

  sy -= dragL * 0.6 * u_flow * ramp * (0.5 + 0.5 * sin(h * 22.0 - tm * 6.0));

  float dx = p.x - cx - swingAt(h);
  float sx = cx + dx / (1.0 + fanK(dx) * h);

  sx += (vnoise1(sx * 90.0) - 0.5) * 0.004 * smoothstep(0.0, 0.1, h);
  return vec2(sx, sy);
}

vec3 ramp(float ink, vec3 bg, vec3 glow, vec3 ribbon, vec3 black) {
  vec3 c = bg;
  c = mix(c, mix(bg, glow, 0.55), smoothstep(0.0, 0.2, ink));
  c = mix(c, glow, smoothstep(0.15, 0.38, ink));
  c = mix(c, ribbon, smoothstep(0.35, 0.55, ink));
  c = mix(c, u_deep, smoothstep(0.55, 0.8, ink));
  return mix(c, black, smoothstep(0.8, 1.0, ink));
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  aspect = u_resolution.x / u_resolution.y;
  tm = u_time * u_motion;
  lineY = u_line;
  cx = u_center * aspect;
  pivot = vec2(cx, lineY);
  float ang = radians(u_angle);
  rotC = vec2(cos(ang), sin(ang));
  dragL = mix(0.06, 0.008, u_drag) * (1.0 + 0.08 * sin(tm * 0.7));
  vec2 pos = toMelt(vec2(uv.x * aspect, 1.0 - uv.y));

  vec3 bgCol = texture2D(u_backdrop, vec2(0.004)).rgb;
  float bgL = max(lum(bgCol), 0.05);
  float h = max(pos.y - lineY, 0.0);
  float m = smoothstep(0.0, 0.06, h);

  float gseed = mod(floor(u_time * 12.0), 64.0) * step(0.001, u_motion);
  float rnd = hash21(gl_FragCoord.xy + gseed * 7.13);
  float rnd2 = hash21(gl_FragCoord.xy * 1.37 + gseed * 3.1 + 9.0);

  float warm = smoothstep(-0.2, 0.08, pos.x - cx + (vnoise(pos * 2.5 + tm * 0.05) - 0.5) * 0.25);

  float sw0 = swingAt(h);
  float dsw = (swingAt(h + 0.002) - sw0) / 0.002;
  float dx0 = pos.x - cx - sw0;
  float fk = fanK(dx0);
  vec2 along = normalize(vec2(dsw + dx0 * fk / (1.0 + fk * h), 1.0));
  vec2 across = vec2(along.y, -along.x);

  float rad = u_blur * (0.0025 + 0.26 * h * (1.0 + 1.2 * (1.0 - warm)));

  float acrossW = mix(1.25, 0.7, smoothstep(0.0, 3.0, u_turns));
  vec3 acc = vec3(0.0);
  for (int i = 0; i < 16; i++) {
    float fi = (float(i) + rnd2) / 16.0;
    float a = float(i) * 2.3999632 + rnd * 6.2831853;
    vec2 o = (across * cos(a) * acrossW + along * sin(a) * 1.6) * sqrt(fi) * rad;
    acc += back(melt(pos + o));
  }
  vec3 col = acc / 16.0;

  float hrad = u_blur * 0.03 + 0.25 * h;
  float haze = 0.0;
  for (int i = 0; i < 10; i++) {
    float fi = (float(i) + rnd) / 10.0;
    float a = float(i) * 2.3999632 + rnd2 * 6.2831853;
    vec2 o = vec2(cos(a) * 1.4, sin(a) * 0.8) * sqrt(fi) * hrad;
    haze += 1.0 - lum(back(melt(pos + o))) / bgL;
  }
  haze = clamp(haze / 10.0, 0.0, 1.0);

  float ink = clamp(1.0 - lum(col) / bgL, 0.0, 1.0);
  float dither = (hash21(gl_FragCoord.xy * 0.73 + gseed * 2.9 + 41.0) - 0.5) * u_grain * 0.22;
  float inkD = clamp(ink + dither * smoothstep(0.02, 0.2, ink) * (1.0 - ink * 0.6), 0.0, 1.0);

  vec3 black = mix(u_deep, vec3(0.0), 0.6);
  vec3 hot = ramp(inkD, bgCol, u_glow, u_ribbon, black);
  vec3 icy = ramp(inkD, bgCol, u_ice, u_chill, black);
  vec3 grey = bgCol;
  grey = mix(grey, mix(bgCol, u_deep, 0.45), smoothstep(0.0, 0.45, inkD));
  grey = mix(grey, u_deep, smoothstep(0.4, 0.8, inkD));
  grey = mix(grey, black, smoothstep(0.8, 1.0, inkD));
  vec3 cool = mix(grey, icy, u_cold);
  vec3 mapped = mix(cool, hot, warm);

  float glow = smoothstep(0.03, 0.35, haze) * (1.0 - smoothstep(0.1, 0.4, ink));
  vec3 hotGlow = mix(bgCol, mix(u_glow, vec3(1.0, 0.85, 0.75), 0.35), 0.9);
  vec3 coldGlow = mix(bgCol, mix(u_ice, vec3(0.8, 0.92, 1.0), 0.35), 0.9);
  mapped = mix(mapped, hotGlow, glow * warm * 0.85);
  mapped = mix(mapped, coldGlow, glow * (1.0 - warm) * u_cold * 0.85);

  float strength = mix(max(u_heat, u_cold), u_heat, warm);
  col = mix(col, mapped, m * strength);

  float g = hash21(gl_FragCoord.xy * 0.91 + gseed * 5.7 + 31.0) - 0.5;
  col += g * u_grain * (0.03 + 0.1 * m * smoothstep(0.03, 0.3, ink));

  col *= 1.0 + (vnoise(uv * 3.0) + vnoise(uv * 9.0 + 4.1) - 1.0) * 0.03 * u_grain;
  vec2 cell = floor(gl_FragCoord.xy / 3.0);
  float speck = step(0.9988, hashS(vec2(hash21(cell), hash21(cell.yx + 3.1)) * 97.0)) * step(0.45, vnoise(uv * 5.0 + 2.3));
  col = mix(col, col * 0.35, speck * u_grain);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
