precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @sdf */
uniform sampler2D u_shape;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Bevel
 * @default 90
 * @range 4, 300
 */
uniform float u_bevel;

/**
 * @label Refraction
 * @default 1
 * @range 0, 3
 */
uniform float u_refract;

/**
 * @label IOR
 * @default 1.5
 * @range 1, 2.4
 */
uniform float u_ior;

/**
 * @label Dispersion
 * @default 1
 * @range 0, 3
 */
uniform float u_disp;

/**
 * @label Frost
 * @default 0
 * @range 0, 1
 */
uniform float u_frost;

/**
 * @label Highlight
 * @default 1
 * @range 0, 3
 */
uniform float u_highlight;

/**
 * @label Light Angle
 * @default 110
 * @range 0, 360
 */
uniform float u_lightAngle;

/**
 * @label Caustics
 * @default 0.8
 * @range 0, 3
 */
uniform float u_caustics;

/**
 * @label Fresnel
 * @default 0.6
 * @range 0, 2
 */
uniform float u_fresnel;

/**
 * @label Tint
 * @color
 * @default #ffffff
 */
uniform vec3 u_tint;

const int N = 10;

vec3 spectrum(float s) {
  return clamp(vec3(1.5 - abs(4.0 * s - 0.5),
                    1.5 - abs(4.0 * s - 2.0),
                    1.5 - abs(4.0 * s - 3.5)), 0.0, 1.0);
}

void main() {
  vec2 px = gl_FragCoord.xy;
  vec2 uv = px / u_resolution;

  vec4 field = texture2D(u_shape, uv);
  float d = max(field.r, 0.0);
  vec2 g = field.gb;
  float glen = length(g);

  vec2 inward = glen > 1e-5 ? g / glen : vec2(0.0);

  float bw = max(u_bevel, 1.0);
  float t = clamp(d / bw, 0.0, 1.0);
  float h = sqrt(max(1.0 - (1.0 - t) * (1.0 - t), 0.0));
  float slope = t < 1.0 ? (1.0 - t) / max(h, 0.06) : 0.0;
  vec3 n = normalize(vec3(-inward * slope, 1.0));
  vec3 view = vec3(0.0, 0.0, -1.0);

  float depth = bw * 1.2 * u_refract * (0.4 + 0.6 * h);

  float maxOff = bw * 1.1;
  float jit = fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
  vec3 acc = vec3(0.0);
  vec3 wsum = vec3(0.0);
  for (int i = 0; i < N; i++) {
    float s = (float(i) + 0.5) / float(N);
    float ior = max(u_ior + (s - 0.5) * 0.16 * u_disp, 1.0);
    vec3 rd = refract(view, n, 1.0 / ior);
    vec2 off = rd.xy / max(-rd.z, 0.15) * depth;
    float ol = length(off);
    if (ol > 1e-3) {
      float e2 = exp(-2.0 * ol / maxOff);
      off *= maxOff * (1.0 - e2) / (1.0 + e2) / ol;
    }

    float a = (float(i) + jit) * 2.39996;
    vec2 fr = vec2(cos(a), sin(a)) * sqrt((float(i) + jit) / float(N)) * u_frost * 24.0;
    vec3 w = spectrum(s);
    vec3 c = texture2D(u_backdrop, clamp((px + off + fr) / u_resolution, 0.0, 1.0)).rgb;
    acc += c * w;
    wsum += w;
  }
  vec3 col = acc / wsum;
  col *= u_tint;

  col += u_frost * 0.04;

  float la = radians(u_lightAngle);
  vec2 ld = vec2(cos(la), sin(la));
  vec2 outward = -inward;
  float facing = dot(outward, ld);
  float lw = 0.8 + bw * 0.025;
  float line = exp(-pow((d - lw * 2.2) / lw, 2.0));
  float halo = exp(-d / (bw * 0.18));
  float lit = pow(max(facing, 0.0), 1.5);

  float along = dot(px / u_resolution.y, vec2(-ld.y, ld.x));
  float sweep = 0.55 + 0.45 * sin(along * 3.0 + 0.8);
  col += vec3(line * 1.8 * sweep + halo * 0.25) * lit * u_highlight;

  float back = pow(max(-facing, 0.0), 1.5);
  float seg = smoothstep(0.1, 0.9, 0.5 + 0.5 * sin(along * 9.0 + 1.3) * sin(along * 3.7));
  vec3 glint = mix(spectrum(0.5 + 0.5 * sin(along * 4.0 + 0.6)), vec3(1.0), 0.2);
  float gl = exp(-pow((d - lw * 3.0) / (lw * 1.6), 2.0));
  col += glint * gl * seg * back * 1.6 * u_caustics;

  float f = pow(1.0 - n.z, 3.0);
  col += vec3(0.7, 0.85, 1.0) * f * 0.35 * u_fresnel;
  float hair = 1.0 - smoothstep(0.0, 1.6, d);
  col += vec3(0.85, 0.92, 1.0) * hair * 0.35 * u_fresnel;

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 1.5 * over);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
