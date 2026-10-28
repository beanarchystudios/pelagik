/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/**
 * @label Time
 * @default 0
 * @range 0, 10
 */
uniform float u_timeOverride;

float animTime() {
  return u_timeOverride > 0.0 ? u_timeOverride : u_time;
}

/**
 * @label Backdrop
 * @backdrop
 */
uniform sampler2D u_backdrop;

/**
 * @label Index of Refraction
 * @default 1.33
 * @range 1, 2
 */
uniform float u_ior;

/**
 * @label Depth
 * @default 0.4
 * @range 0, 1.5
 */
uniform float u_depth;

/**
 * @label Amplitude
 * @default 0.05
 * @range 0, 0.2
 */
uniform float u_amplitude;

/**
 * @label Wave Scale
 * @default 3.0
 * @range 0.5, 8
 */
uniform float u_scale;

/**
 * @label Speed
 * @default 0.5
 * @range 0, 2
 */
uniform float u_speed;

/**
 * @label Turbulence
 * @default 0.6
 * @range 0, 1
 */
uniform float u_turbulence;

/**
 * @label Highlights
 * @default 0.35
 * @range 0, 1
 */
uniform float u_highlights;

/**
 * @label Chromatic Aberration
 * @default 0.0
 * @range 0, 1
 */
uniform float u_dispersion;

const float REF_PX = 450.0;

float hash11(float n) {
  return fract(sin(n * 12.9898) * 43758.5453123);
}

float surfaceHG(vec2 p, float time, out vec2 grad) {

  float t = time * u_speed;
  float wk = 0.12 * (0.6 + u_turbulence);
  float ax = p.y * 1.3 - t * 0.35;
  float bx = p.x * 0.7 + t * 0.24;
  float ay = p.x * 1.1 + t * 0.29;
  float by = p.y * 0.6 - t * 0.21;
  vec2 q = p + vec2(sin(ax) + sin(bx), sin(ay) + sin(by)) * wk;

  float jxx = 1.0 + wk * 0.7 * cos(bx);
  float jxy = wk * 1.3 * cos(ax);
  float jyx = wk * 1.1 * cos(ay);
  float jyy = 1.0 + wk * 0.6 * cos(by);

  float chop = 1.0 + u_turbulence * 2.5;
  float h = 0.0;
  vec2 g = vec2(0.0);
  float norm = 0.0;
  float freq = 1.1;
  const int N = 14;
  for (int i = 0; i < N; i++) {
    float fi = float(i);
    float ang = fi * 2.39996323 + hash11(fi + 1.0) * 1.2;
    vec2 d = vec2(cos(ang), sin(ang));
    float jf = freq * (0.8 + 0.4 * hash11(fi + 7.0));
    float omega = sqrt(jf) * (2.4 * u_speed);
    float ph = hash11(fi + 3.0) * 6.2831853;
    float amp = 1.0 / jf;
    float x = dot(q, d) * jf - time * omega + ph;
    float s = sin(x) * 0.5 + 0.5;
    float sp1 = pow(max(s, 1e-4), chop - 1.0);
    h += amp * (sp1 * s - 0.5) * 2.0;
    g += (amp * chop * sp1 * cos(x) * jf) * d;
    norm += amp;
    freq *= 1.18;
  }
  grad = vec2(g.x * jxx + g.y * jyx, g.x * jxy + g.y * jyy) / norm;
  return h / norm;
}

vec2 refractUV(vec3 N, vec2 uv, float eta) {
  vec3 T = refract(vec3(0.0, 0.0, -1.0), N, eta);
  float descend = max(-T.z, 1e-4);
  vec2 dispPx = (T.xy / descend) * u_depth * REF_PX;
  return uv + dispPx / u_resolution;
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 suv = gl_FragCoord.xy / REF_PX;

  float time = animTime();
  float scale = 2.5 + u_scale * 1.4;
  vec2 grad;
  float h = surfaceHG(suv * scale, time, grad);

  vec2 dH = grad * scale * u_amplitude;
  vec3 N = normalize(vec3(-dH, 1.0));

  float d = u_dispersion * 0.08;
  float etaR = 1.0 / max(u_ior - d, 1.0);
  float etaG = 1.0 / max(u_ior, 1.0);
  float etaB = 1.0 / max(u_ior + d, 1.0);

  vec4 col = texture2D(u_backdrop, refractUV(N, uv, etaG));
  if (u_dispersion > 0.001) {
    col.r = texture2D(u_backdrop, refractUV(N, uv, etaR)).r;
    col.b = texture2D(u_backdrop, refractUV(N, uv, etaB)).b;
  }

  vec3 lightDir = normalize(vec3(0.35, 0.6, 0.7));
  float spec = pow(max(dot(N, lightDir), 0.0), 24.0);
  float crest = smoothstep(0.0, 0.6, h);
  col.rgb += spec * crest * u_highlights;

  gl_FragColor = col;
}
