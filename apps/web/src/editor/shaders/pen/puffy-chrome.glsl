precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Puff
 * @default 5
 * @range 1, 60
 */
uniform float u_puff;

/**
 * @label Height
 * @default 1.4
 * @range 0.2, 4
 */
uniform float u_height;

/**
 * @label Light Angle
 * @default 125
 * @range 0, 360
 */
uniform float u_lightAngle;

/**
 * @label Swing
 * @default 70
 * @range 0, 180
 */
uniform float u_swing;

/**
 * @label Speed
 * @default 0.12
 * @range 0, 1
 */
uniform float u_speed;

/**
 * @label Shine
 * @default 1
 * @range 0, 2
 */
uniform float u_shine;

/**
 * @label Grain
 * @default 0.35
 * @range 0, 1
 */
uniform float u_grain;

/**
 * @label Rim
 * @default 0.6
 * @range 0, 1
 */
uniform float u_rim;

/**
 * @label Tint
 * @color
 * @default #e9ebee
 */
uniform vec3 u_tint;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec3 lightDir(float deg, float elevation) {
  float a = radians(deg);
  return normalize(vec3(cos(a), sin(a), elevation));
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);

  float t = clamp(d / max(u_puff, 1.0), 0.0, 1.0);
  float h = sqrt(max(1.0 - (1.0 - t) * (1.0 - t), 0.0));
  float slope = t < 1.0 ? (1.0 - t) / max(h, 0.06) : 0.0;
  vec3 n = normalize(vec3(-gdir * slope * u_height, 1.0));
  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);

  float swing = u_swing * sin(u_time * u_speed * 6.2831853);
  vec3 key = lightDir(u_lightAngle + swing, 0.55);
  vec3 fill = lightDir(u_lightAngle + swing + 180.0, 0.35);

  float body = 0.6 + 0.18 * r.y;

  float away = smoothstep(-0.05, -0.75, r.z);
  body = mix(body, 0.08, away * 0.9);

  float kd = max(dot(r, key), 0.0);
  float fd = max(dot(r, fill), 0.0);

  float spec = pow(kd, 22.0) * 1.0 + pow(kd, 3.5) * 0.45;
  float spec2 = pow(fd, 8.0) * 0.45;
  float diffuse = 0.18 * max(dot(n, key), 0.0);

  float lum = body + diffuse + u_shine * (spec + spec2);

  float rim = (1.0 - smoothstep(0.0, 0.8, d)) * u_rim;
  lum = mix(lum, 1.0, rim * 0.85);

  float gr = hash21(floor(gl_FragCoord.xy)) - 0.5;
  float gr2 = hash21(floor(gl_FragCoord.xy * 0.5) + 17.0) - 0.5;
  lum += (gr * 0.7 + gr2 * 0.3) * u_grain * 0.16 * (0.4 + lum);

  vec3 col = u_tint * lum;

  vec3 over = max(col - 0.82, 0.0);
  col = min(col, vec3(0.82)) + over / (1.0 + 2.0 * over);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
