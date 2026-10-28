precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @sdf */
uniform sampler2D u_shape;

/**
 * @label Bevel
 * @default 6
 * @range 1, 40
 */
uniform float u_bevel;

/**
 * @label Curve
 * @default 0.6
 * @range 0, 2
 */
uniform float u_curve;

/**
 * @label Rim
 * @default 1
 * @range 0, 2
 */
uniform float u_rim;

/**
 * @label Inner Rim
 * @default 0.7
 * @range 0, 2
 */
uniform float u_innerRim;

/**
 * @label Colour
 * @default 1
 * @range 0, 2
 */
uniform float u_colour;

/**
 * @label Hue
 * @default 0
 * @range 0, 1
 */
uniform float u_hue;

/**
 * @label Glints
 * @default 0.6
 * @range 0, 1.5
 */
uniform float u_glints;

/**
 * @label Speed
 * @default 0.25
 * @range 0, 2
 */
uniform float u_speed;

/**
 * @label Light
 * @default 0
 * @range 0, 1
 */
uniform float u_light;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
             mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 spectrum(float x) {
  return 0.5 + 0.5 * cos(6.2831853 * (x + vec3(0.0, 0.33, 0.67)));
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec4 field = texture2D(u_shape, uv);

  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);

  vec2 gdir = glen > 1e-5 ? g / glen : vec2(0.0);
  float t = u_time * u_speed;

  float bev = max(u_bevel, 1.0);
  float tb = clamp(d / bev, 0.0, 1.0);
  float hb = sqrt(max(1.0 - (1.0 - tb) * (1.0 - tb), 0.0));
  float slopeB = tb < 1.0 ? (1.0 - tb) / max(hb, 0.08) : 0.0;
  float tf = clamp(d / (bev * 3.0), 0.0, 1.0);
  float slopeF = u_curve * (1.0 - tf);
  vec3 n = normalize(vec3(-gdir * (slopeB * 1.6 + slopeF), 1.0));
  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
  float fres = pow(1.0 - n.z, 1.5);

  float a = 0.8 + t;
  vec3 La = normalize(vec3(cos(a), sin(a), 0.45));
  vec3 Lb = normalize(vec3(cos(a + 2.6), sin(a + 2.6), 0.35));
  vec2 rimDir = vec2(cos(a + 1.3), sin(a + 1.3));

  float hue = u_hue + 0.04 * sin(t * 0.7);

  vec3 colA = spectrum(0.48 + hue + 0.12 * r.x - 0.08 * r.y);
  vec3 colB = spectrum(0.72 + hue + 0.1 * r.y);

  float sa = max(dot(r, La), 0.0);
  float sb = max(dot(r, Lb), 0.0);

  float shA = (pow(sa, 3.0) * 0.7 + pow(sa, 18.0) * 1.0) * u_colour;
  float shB = (pow(sb, 4.0) * 0.5 + pow(sb, 24.0) * 0.8) * u_colour;
  vec3 col = vec3(0.012, 0.012, 0.02);
  col += colA * shA + colB * shB;

  vec2 sp = gl_FragCoord.xy / u_resolution.y;
  float sw1 = dot(sp, vec2(cos(0.5), sin(0.5))) - mod(t * 0.35, 3.0) + 0.6;
  float sw2 = dot(sp, vec2(cos(2.3), sin(2.3))) + mod(t * 0.27 + 1.4, 3.0) - 1.6;
  float b1 = exp(-sw1 * sw1 / 0.06);
  float b2 = exp(-sw2 * sw2 / 0.04);
  float tiltLit = 0.45 + 0.55 * smoothstep(-0.6, 0.6, dot(n.xy, vec2(0.7, 0.7)) * 4.0);
  vec3 sweepA = spectrum(0.5 + hue + sp.y * 0.35 + sw1 * 0.6);
  vec3 sweepB = spectrum(0.68 + hue + sp.x * 0.25 + sw2 * 0.5);
  col += (sweepA * b1 * 1.0 + sweepB * b2 * 0.7) * tiltLit * u_colour;

  col += vec3(0.6) * pow(b1, 4.0) * fres * u_colour;

  col += vec3(0.05, 0.06, 0.08) * smoothstep(-0.2, 0.9, r.y) * (0.3 + fres);

  float gn = noise(r.xy * 4.0 + vec2(t * 0.6, -t * 0.4) + uv * 3.0);
  float glint = smoothstep(0.72, 0.9, gn) * (0.3 + 0.7 * fres);
  col += vec3(1.0, 0.25, 0.18) * glint * u_glints * 0.7;

  float face = dot(-gdir, rimDir);
  float outer = exp(-d / 1.3);
  float outerLit = 0.35 + 0.65 * smoothstep(-0.3, 0.8, face);
  vec3 rimTint = mix(vec3(1.0), spectrum(hue + 0.55 + face * 0.3), 0.18);
  col += rimTint * outer * outerLit * u_rim * 1.9;

  float gap = smoothstep(1.2, 2.5, d) * (1.0 - smoothstep(bev * 0.6, bev, d));
  col *= 1.0 - 0.5 * gap * (1.0 - fres * 0.5);
  float inner = exp(-pow((d - bev) / 0.9, 2.0));
  float innerLit = smoothstep(-0.1, 0.9, -face);
  col += mix(vec3(1.0), colA, 0.35) * inner * innerLit * u_innerRim;

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 1.5 * over);

  vec3 lc = vec3(0.8, 0.81, 0.84);

  lc *= 1.0 - 0.35 * (1.0 - smoothstep(-0.4, 0.8, r.y)) * (0.4 + fres);
  lc *= mix(vec3(1.0), colA, clamp(shA * 0.9, 0.0, 0.85));
  lc *= mix(vec3(1.0), colB, clamp(shB * 0.9, 0.0, 0.85));
  lc *= mix(vec3(1.0), sweepA, clamp(b1 * tiltLit * u_colour * 0.9, 0.0, 0.85));
  lc *= mix(vec3(1.0), sweepB, clamp(b2 * tiltLit * u_colour * 0.7, 0.0, 0.85));

  lc += vec3(0.35) * (pow(sa, 18.0) + pow(b1, 4.0) * fres) * u_colour;
  lc = mix(lc, vec3(1.0, 0.45, 0.3), clamp(glint * u_glints * 0.55, 0.0, 1.0));
  lc *= 1.0 - 0.3 * gap;
  lc = mix(lc, vec3(1.0), clamp(inner * innerLit * u_innerRim, 0.0, 1.0));

  float ink = outer * (1.0 - 0.5 * outerLit) * u_rim * 0.75;
  lc *= 1.0 - clamp(ink, 0.0, 0.9);

  col = mix(col, lc, clamp(u_light, 0.0, 1.0));

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
