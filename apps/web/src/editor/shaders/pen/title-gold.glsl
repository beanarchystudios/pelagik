precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Bevel
 * @default 4
 * @range 1, 30
 */
uniform float u_bevel;

/**
 * @label Highlight
 * @default 1
 * @range 0, 2
 */
uniform float u_highlight;

/**
 * @label Top Colour
 * @color
 * @default #573420
 */
uniform vec3 u_top;

/**
 * @label Bottom Colour
 * @color
 * @default #dca06a
 */
uniform vec3 u_bottom;

/**
 * @label Ramp Start
 * @default 0.18
 * @range 0, 1
 */
uniform float u_rampStart;

/**
 * @label Ramp End
 * @default 0.76
 * @range 0, 1
 */
uniform float u_rampEnd;

/**
 * @label Smoke
 * @default 0.6
 * @range 0, 1
 */
uniform float u_smoke;

/**
 * @label Glow
 * @default 0.4
 * @range 0, 1.5
 */
uniform float u_glow;

/**
 * @label Light Angle
 * @default 115
 * @range 0, 360
 */
uniform float u_angle;

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
  for (int i = 0; i < 5; i++) {
    v += a * vnoise(p);
    p = p * 2.03 + vec2(17.1, 9.3);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 p = gl_FragCoord.xy;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);

  float bev = max(u_bevel, 1.0);
  float a = radians(u_angle);
  vec2 L2 = vec2(cos(a), sin(a));

  float fromTop = 1.0 - uv.y;

  float smoke = fbm(p / vec2(260.0, 120.0) + 4.2) * 0.7 + fbm(p / vec2(70.0, 34.0) + 11.7) * 0.3;
  smoke = smoothstep(0.25, 0.8, smoke);

  float grain = vnoise(p / vec2(3.0, 14.0) + 3.0) * 0.5 + vnoise(p / vec2(9.0, 30.0) + 7.0) * 0.5;

  float rs = min(u_rampStart, u_rampEnd - 0.01);
  float t = smoothstep(rs, u_rampEnd, fromTop + (smoke - 0.5) * 0.15 * u_smoke);
  vec3 face = mix(u_top, u_bottom, t);
  face *= mix(1.0, 0.62 + 0.7 * smoke, u_smoke);
  face *= 0.95 + 0.1 * grain;

  float lb = dot(u_bottom, vec3(0.3, 0.59, 0.11));
  vec3 champagne = mix(u_bottom, vec3(lb), 0.55) * 1.12 + 0.03;
  float pale = smoothstep(u_rampEnd - 0.2, u_rampEnd + 0.04, fromTop);
  face = mix(face, champagne * (0.9 + 0.2 * smoke), 0.62 * pale);

  face += vec3(0.3, 0.24, 0.18) * pow(smoke, 3.0) * t * u_smoke;

  float inside = smoothstep(bev, bev * 5.0, d);
  float low = smoothstep(0.35, 1.0, fromTop);
  face += vec3(0.5, 0.33, 0.2) * u_glow * 0.2 * inside * low * (0.5 + 0.8 * smoke);

  float facing = dot(-gdir, L2);
  float up = max(facing, 0.0);
  vec3 white = vec3(0.98, 0.95, 0.91);
  float across = clamp(d / bev, 0.0, 1.0);
  float env = smoothstep(-0.35, 0.25, facing);
  vec3 litCut = mix(face * 1.15, white, clamp(pow(up, 1.8) * u_highlight, 0.0, 1.0));
  vec3 bevelCol = mix(face * 0.4, litCut, env);

  bevelCol *= 0.88 + 0.24 * (1.0 - across);

  vec3 col = mix(face, bevelCol, 1.0 - smoothstep(bev - 0.6, bev + 0.6, d));

  float rimLine = 1.0 - smoothstep(0.4, 1.4, d);
  float rimW = 0.1 + 0.9 * smoothstep(-0.2, 0.9, facing) + 0.4 * smoothstep(0.5, 1.0, -facing);
  col = mix(col, white, rimLine * clamp(rimW * u_highlight, 0.0, 1.0));

  float groove = 1.0 - smoothstep(0.0, 1.1, abs(d - bev));
  col *= 1.0 - 0.35 * groove;

  vec3 over = max(col - 0.8, 0.0);
  col = min(col, vec3(0.8)) + over / (1.0 + 2.0 * over);
  col += (hash21(p) - 0.5) * 0.012;

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
