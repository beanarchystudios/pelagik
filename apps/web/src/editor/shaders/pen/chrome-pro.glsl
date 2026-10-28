precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @sdf */
uniform sampler2D u_shape;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Bevel
 * @default 38
 * @range 2, 120
 */
uniform float u_bevel;

/**
 * @label Shine
 * @default 1
 * @range 0, 2
 */
uniform float u_shine;

/**
 * @label Speed
 * @default 0.07
 * @range 0, 0.5
 */
uniform float u_speed;

/**
 * @label Direction
 * @default 0
 * @range 0, 360
 */
uniform float u_direction;

/**
 * @label Top to Bottom
 * @default 1
 * @range -1, 1
 */
uniform float u_vertical;

/**
 * @label Room
 * @default 1
 * @range 0, 3
 */
uniform float u_room;

/**
 * @label Stripe Position
 * @default 0
 * @range -1, 1
 */
uniform float u_stripeY;

/**
 * @label Stripe Height
 * @default 1
 * @range 0.2, 5
 */
uniform float u_stripeH;

/**
 * @label Edge Flare
 * @default 1.8
 * @range 0, 6
 */
uniform float u_flare;

/**
 * @label Flare Reach
 * @default 35
 * @range 2, 200
 */
uniform float u_flareReach;

/**
 * @label Back and Forth
 * @default 0
 * @range 0, 1
 */
uniform float u_bounce;

/**
 * @label Dispersion
 * @default 1
 * @range 0, 2
 */
uniform float u_dispersion;

/**
 * @label Rim
 * @default 0.8
 * @range 0, 1
 */
uniform float u_rim;

/**
 * @label Backdrop
 * @default 0.85
 * @range 0, 1
 */
uniform float u_backdropMix;

/**
 * @label Refraction
 * @default 60
 * @range 0, 300
 */
uniform float u_refract;

/**
 * @label Tint
 * @color
 * @default #eceef2
 */
uniform vec3 u_tint;

/**
 * @label Iridescence
 * @default 1
 * @range 0, 2
 */
uniform float u_iris;

/**
 * @label Iris Spread
 * @default 0.1
 * @range 0, 0.4
 */
uniform float u_irisSpread;

/**
 * @label Iris Waves
 * @default 1.6
 * @range 0, 6
 */
uniform float u_irisWaves;

/**
 * @label Iris Warm
 * @color
 * @default #ff9650
 */
uniform vec3 u_irisWarm;

/**
 * @label Iris Cool
 * @color
 * @default #48b6ff
 */
uniform vec3 u_irisCool;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 travelDir() {
  float a = radians(u_direction);
  return vec2(cos(a), sin(a));
}

float studio(vec2 e, float sweep, float ws) {
  vec2 dir = travelDir();
  float along = dot(e, dir);
  float room = 0.05;

  float amt = abs(u_vertical);
  float fy = u_vertical < 0.0 ? -e.y : e.y;

  room += 0.55 * mix(0.35, smoothstep(0.0, -0.7, fy), amt);

  float v = room * min(u_room, 1.0) + max(u_room - 1.0, 0.0) * 0.28;

  float hy = (e.y - u_stripeY * 0.65 + u_vertical * (0.1 + 0.08 * e.x))
    / (ws * max(u_stripeH, 0.05));
  v += 0.6 * exp(-hy * hy * 260.0) + 0.12 * exp(-hy * hy * 18.0);

  float b = along - sweep;
  v += u_shine * (1.1 * exp(-b * b * 90.0) + 0.45 * exp(-b * b * 5.0));

  float k = along - sweep + 0.55;
  v += u_shine * 0.35 * exp(-k * k * 140.0);

  v *= mix(1.0, 0.25, smoothstep(0.0, 0.6, fy) * amt);
  return v;
}

vec3 backdropBlur(vec2 uv, float r) {
  vec2 px = r / u_resolution;
  vec3 c = texture2D(u_backdrop, uv).rgb * 0.4;
  c += texture2D(u_backdrop, uv + vec2(px.x, 0.0)).rgb * 0.15;
  c += texture2D(u_backdrop, uv - vec2(px.x, 0.0)).rgb * 0.15;
  c += texture2D(u_backdrop, uv + vec2(0.0, px.y)).rgb * 0.15;
  c += texture2D(u_backdrop, uv - vec2(0.0, px.y)).rgb * 0.15;
  return c;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;

  vec2 p = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;

  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);

  float flare = 1.0 + u_flare * exp(-d / max(u_flareReach, 1.0));
  vec2 g = field.gb;
  float glen = length(g);
  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);

  float t = clamp(d / max(u_bevel, 1.0), 0.0, 1.0);
  float h = sqrt(max(1.0 - (1.0 - t) * (1.0 - t), 0.0));
  float slope = t < 1.0 ? (1.0 - t) / max(h, 0.08) : 0.0;
  vec3 n = normalize(vec3(-gdir * slope, 1.0));
  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);

  float cyc = u_time * u_speed;
  float sweep = u_bounce > 0.5
    ? 1.15 * sin(cyc * 6.2831853)
    : 2.2 * (2.0 * fract(cyc + 0.5) - 1.0);
  vec2 dir = travelDir();
  float pAlong = dot(p, dir);

  vec2 base = p * vec2(0.7, 1.3);
  float k = 0.07 * u_dispersion;
  vec3 env = vec3(
    studio(base + r.xy * 1.25 * (1.0 - k), sweep, flare),
    studio(base + r.xy * 1.25, sweep, flare),
    studio(base + r.xy * 1.25 * (1.0 + k), sweep, flare));

  vec2 look = base + r.xy * 1.25;
  vec2 o = vec2(0.45, 1.0) * u_irisSpread * flare;
  float split = studio(look + o, sweep, flare) - studio(look - o, sweep, flare);
  vec3 warm = u_irisWarm - dot(u_irisWarm, LUMA) * 0.85;
  vec3 cool = u_irisCool - dot(u_irisCool, LUMA) * 0.85;
  vec3 iris = warm * max(split, 0.0) + cool * max(-split, 0.0);

  float lum0 = env.g;
  float phase = pAlong * u_irisWaves + lum0 * 0.8 - sweep * 0.35;
  float w = 0.5 + 0.5 * sin(phase * 6.2831853);
  vec3 film = mix(cool, warm, w) * smoothstep(0.08, 0.6, lum0) * step(0.001, u_irisWaves);

  float onFace = mix(0.5, 1.0, t);
  env = max(env + (iris * 1.1 + film * 0.3) * u_iris * onFace, 0.0);

  float away = smoothstep(0.1, -0.7, r.z);
  env *= 1.0 - away * 0.45;

  float edge = 1.0 - smoothstep(0.0, max(u_bevel * 0.08, 1.2), d);
  edge = max(edge, 0.45 * exp(-d / max(u_bevel * 0.3, 1.0)));
  float near = 0.55 + 0.45 * exp(-pow((pAlong - sweep * 0.8) * 1.6, 2.0));
  env = mix(env, vec3(1.0), edge * u_rim * near);

  float bw = max(u_bevel, 1.0);
  float lit = 0.25 + 0.75 * exp(-pow((pAlong - sweep * 0.8) * 1.4, 2.0));
  env += vec3(0.35 * exp(-d / (bw * 0.45))) * lit;
  vec3 ring = vec3(
    exp(-pow((d - bw * 0.7) / (bw * 0.12), 2.0)),
    exp(-pow((d - bw * 0.8) / (bw * 0.12), 2.0)),
    exp(-pow((d - bw * 0.92) / (bw * 0.12), 2.0)));
  env += (ring - dot(ring, vec3(0.333))) * 0.3 * u_dispersion * lit * lit;

  vec2 bend = -n.xy * u_refract / u_resolution;
  vec3 bd = backdropBlur(uv + bend, 6.0 + u_bevel * 0.2);
  float bl = dot(bd, LUMA);
  float target = 0.15 + 0.75 * sqrt(clamp(bl / 0.75, 0.0, 1.2));
  vec3 hue = clamp(bd / max(bl, 0.02) * target, 0.0, 2.2);
  float has = smoothstep(0.0, 0.04, bl);
  vec3 metal = mix(u_tint, hue, u_backdropMix * has);

  vec3 col = metal * env;

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 2.5 * over);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
