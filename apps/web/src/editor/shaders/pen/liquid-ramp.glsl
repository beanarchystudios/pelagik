precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @content */
uniform sampler2D u_content;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Waves
 * @default 1.1
 * @range 0.3, 6
 */
uniform float u_waves;

/**
 * @label Warp
 * @default 1
 * @range 0, 2.5
 */
uniform float u_warp;

/**
 * @label Bands
 * @default 1
 * @range 0.3, 4
 */
uniform float u_bands;

/**
 * @label Flow
 * @default 1
 * @range 0, 5
 */
uniform float u_flow;

/**
 * @label Loop
 * @default 10.5
 * @range 2, 40
 */
uniform float u_loop;

/**
 * @label Bevel
 * @default 3.6
 * @range 0, 12
 */
uniform float u_bevel;

/**
 * @label Depth
 * @default 2
 * @range 0, 5
 */
uniform float u_depth;

/**
 * @label Seed
 * @default 0
 * @range 0, 10
 */
uniform float u_seed;

/**
 * @label Ramp Loop
 * @default 0
 * @range 0, 1
 */
uniform float u_rampLoop;

/**
 * @label Color 1
 * @color
 * @default #000208
 */
uniform vec3 u_c0;

/**
 * @label Color 2
 * @color
 * @default #001a66
 */
uniform vec3 u_c1;

/**
 * @label Color 3
 * @color
 * @default #0050e0
 */
uniform vec3 u_c2;

/**
 * @label Color 4
 * @color
 * @default #2a9af4
 */
uniform vec3 u_c3;

/**
 * @label Color 5
 * @color
 * @default #b0e0fc
 */
uniform vec3 u_c4;

/**
 * @label Color 6
 * @color
 * @default #c4eafe
 */
uniform vec3 u_c5;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 grad2(vec2 i) {
  float a = 6.2831853 * hash21(i);
  return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(grad2(i), f);
  float b = dot(grad2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(grad2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(grad2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  return 0.6 * gnoise(p) + 0.24 * gnoise(mat2(1.6, 1.2, -1.2, 1.6) * p + 3.1);
}

float liquid(vec2 p, float ang) {
  float r = u_flow * 0.044;
  p += r * 1.3 * vec2(cos(ang + 0.7), sin(ang + 0.7));
  vec2 o1 = r * 0.6 * vec2(cos(ang), sin(ang));
  vec2 o2 = r * 0.4 * vec2(cos(2.0 * ang + 1.3), sin(2.0 * ang + 1.3));
  vec2 o3 = r * 0.5 * vec2(sin(ang + 2.1), cos(ang + 2.1));
  vec2 q = vec2(gnoise(p + o1), gnoise(p + vec2(5.2, 1.3) - o1.yx));
  vec2 w = p + u_warp * 1.6 * q;
  vec2 s = vec2(gnoise(w + vec2(1.7, 9.2) + o2), gnoise(w + vec2(8.3, 2.8) - o2));
  return fbm(p + u_warp * 1.6 * s + o3);
}

float fold(float x) {
  return u_rampLoop > 0.5 ? fract(x) : 1.0 - abs(fract(x * 0.5) * 2.0 - 1.0);
}

vec3 ramp(float t) {
  float k = t * (u_rampLoop > 0.5 ? 6.0 : 5.0);
  vec3 c = u_c0;
  c = mix(c, u_c1, clamp(k, 0.0, 1.0));
  c = mix(c, u_c2, clamp(k - 1.0, 0.0, 1.0));
  c = mix(c, u_c3, clamp(k - 2.0, 0.0, 1.0));
  c = mix(c, u_c4, clamp(k - 3.0, 0.0, 1.0));
  c = mix(c, u_c5, clamp(k - 4.0, 0.0, 1.0));
  c = mix(c, u_c0, clamp(k - 5.0, 0.0, 1.0));
  return c;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 texel = 1.0 / u_resolution;
  float cover = texture2D(u_content, uv).a;
  float d = texture2D(u_shape, uv).r;

  float side = min(u_resolution.x, u_resolution.y);

  vec4 e1 = texture2D(u_shape, uv + vec2(1.5, 0.0) * texel);
  vec4 e2 = texture2D(u_shape, uv - vec2(1.5, 0.0) * texel);
  vec4 e3 = texture2D(u_shape, uv + vec2(0.0, 1.5) * texel);
  vec4 e4 = texture2D(u_shape, uv - vec2(0.0, 1.5) * texel);
  float ds = max((4.0 * d + e1.r + e2.r + e3.r + e4.r) / 8.0, 0.0);
  vec2 g = e1.gb + e2.gb + e3.gb + e4.gb;
  float gl = length(g);
  vec2 inward = gl > 1e-5 ? g / gl : vec2(0.0);

  float bevel = u_bevel * 0.01 * side;
  float s = bevel > 0.0 ? clamp(ds / bevel, 0.0, 1.0) : 1.0;
  float slope = 3.0 * (1.0 - s) * (1.0 - s);
  vec2 at = gl_FragCoord.xy - inward * (u_depth * bevel * slope);

  float ang = 6.2831853 * fract(u_time / max(u_loop, 0.1));
  vec2 p = (at - 0.5 * u_resolution) / side;

  p = p * u_waves * vec2(1.0, 0.65) + u_seed * vec2(3.7, 5.3);
  float body = 0.5 + 4.2 * liquid(p, ang) * u_bands;

  float w = 1.0 - (1.0 - s) * (1.0 - s);
  float t = fold(fold(body) - 0.3 * sin(3.1415927 * w));
  vec3 col = ramp(t);

  gl_FragColor = vec4(col * cover, cover);
}
