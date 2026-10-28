precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Bevel
 * @default 4
 * @range 0.5, 40
 */
uniform float u_bevel;

/**
 * @label Depth
 * @default 2.5
 * @range 0, 8
 */
uniform float u_depth;

/**
 * @label Sky
 * @color
 * @default #9aa6b4
 */
uniform vec3 u_sky;

/**
 * @label Ground
 * @color
 * @default #2b2b30
 */
uniform vec3 u_ground;

/**
 * @label Horizon
 * @default 0.48
 * @range 0, 1
 */
uniform float u_horizon;

/**
 * @label Sweep Speed
 * @default 0.3
 * @range 0, 2
 */
uniform float u_speed;

/**
 * @label Sweep Angle
 * @default 20
 * @range -90, 90
 */
uniform float u_angle;

/**
 * @label Band Width
 * @default 0.18
 * @range 0.03, 0.6
 */
uniform float u_band;

/**
 * @label Highlight
 * @default 1
 * @range 0, 2
 */
uniform float u_highlight;

/**
 * @label Shadow
 * @default 0.55
 * @range 0, 1
 */
uniform float u_shadow;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);

  float b = max(u_bevel, 0.5);
  float t = clamp(d / b, 0.0, 1.0);
  float h = sqrt(max(1.0 - (1.0 - t) * (1.0 - t), 0.0));
  float slope = t < 1.0 ? (1.0 - t) / max(h, 0.08) : 0.0;
  vec3 n = normalize(vec3(-gdir * slope * u_depth, 1.0));
  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);

  float aspect = u_resolution.x / u_resolution.y;
  vec2 p = (uv - 0.5) * vec2(aspect, 1.0);

  float cyc = fract(u_time * u_speed);
  float a = radians(u_angle);
  vec2 sdir = vec2(cos(a), sin(a));
  float trail = u_band * 2.2;
  float span = 0.5 * (aspect * abs(sdir.x) + abs(sdir.y)) + u_band * 2.0 + trail;

  float c = mix(-span, span + trail, clamp(cyc / 0.7, 0.0, 1.0));
  float breathe = 0.035 * sin(cyc * 6.2831853);

  float y = uv.y + r.y * 0.55;
  float above = y - (u_horizon + breathe);
  vec3 skyC = mix(vec3(0.97), u_sky, smoothstep(0.0, 0.55, above));
  vec3 groundC = mix(u_ground, u_ground + vec3(0.34), smoothstep(0.0, 0.42, -above));
  vec3 env = mix(groundC, skyC, smoothstep(-0.012, 0.012, above));

  env *= 1.0 - 0.35 * r.x * r.x;
  env = mix(env, vec3(0.06), pow(1.0 - n.z, 3.0) * 0.6);

  float x = dot(p, sdir) + dot(r.xy, sdir) * 0.18;
  float hi = exp(-pow((x - c) / u_band, 2.0));
  float sh = exp(-pow((x - (c - trail)) / (u_band * 1.5), 2.0));
  float edge = 1.0 - n.z;
  vec3 col = env * (1.0 - u_shadow * sh * 0.85);

  col *= 1.0 + 0.3 * u_highlight * hi;
  col += u_highlight * hi * (0.06 + 0.5 * edge) * vec3(1.0, 0.99, 0.97);

  vec3 over = max(col - 0.8, 0.0);
  col = min(col, vec3(0.8)) + over / (1.0 + 2.5 * over);
  col += (hash21(gl_FragCoord.xy) - 0.5) * 0.008;

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
