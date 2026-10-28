/** @resolution */
uniform vec2 u_resolution;

/** @backdrop */
uniform sampler2D u_backdrop;

/** @sdf */
uniform sampler2D u_sdf;

/**
 * @label Tint
 * @color
 * @default #00000000
 */
uniform vec4 u_tint;

const float MARGIN = 0.5333;
const float BLUR_SIGMA = 1.2;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float sdf(vec2 uv) {
  return texture2D(u_sdf, uv).r;
}

float bias(float u, float amount) {
  return amount * u / max(amount * u + (1.0 - amount) * (1.0 - u), 1e-5);
}

float lobe(float cosAngle, float spread) {
  float cs = cos(spread);
  return clamp((cosAngle - cs) / (1.0 - cs), 0.0, 1.0);
}

float rimLight(vec2 normal, float depth, float angle, float spread) {
  float c = dot(normal, vec2(sin(angle), cos(angle)));
  float bevel = clamp(1.0 - 0.75 * depth, 0.0, 1.0);
  float key = depth < 1.0 ? bias(bevel * lobe(c, spread), 0.5) : 0.0;
  float diffuse = clamp(1.0 - depth / 8.0, 0.0, 1.0);
  return key + bias(diffuse * lobe(c, spread * 0.65), 0.075);
}

vec3 applyTint(vec3 c, vec4 tint) {
  vec3 t = tint.rgb;
  float hi = max(t.r, max(t.g, t.b));
  float lo = min(t.r, min(t.g, t.b));
  vec3 tinted;
  if (hi - lo < 1e-4) {
    float mid = hi * (1.0 - hi);
    tinted = (0.3125 - 0.0156 * mid) * c + (1.1875 * hi - 0.25 - 0.017 * mid);
  } else {
    float l = 0.5 * (hi + lo);
    float chroma = l <= 0.5
      ? 57.0 / 85.0
      : min(87.0 * l - 15.0, 105.0 - 57.0 * l) / (85.0 * (1.0 - l));
    vec3 dark = clamp(
      45.0 / 85.0 * l + chroma * (t - l),
      -15.0 / 85.0 * t,
      1.0 + 15.0 / 85.0 * (1.0 - t));
    tinted = dark + (t - dark) * dot(c, LUMA);
  }

  return mix(c, clamp(tinted, 0.0, 1.0832), tint.a);
}

void main() {
  vec2 px = 1.0 / u_resolution;
  vec2 uv = gl_FragCoord.xy * px;

  vec2 h = 0.5 * px;
  vec2 grad = vec2(
    sdf(uv + vec2(h.x, 0.0)) - sdf(uv - vec2(h.x, 0.0)),
    sdf(uv + vec2(0.0, h.y)) - sdf(uv - vec2(0.0, h.y)));
  vec2 inward = normalize(grad + 1e-6);
  vec2 normal = -inward;

  float d = sdf(uv);
  if (d < 1.0) {
    d = sdf(uv + inward * px) - 1.0;
  }

  vec3 back = texture2D(u_backdrop, uv).rgb;
  float edge = bias(lobe(abs(normal.x), radians(75.0)), 0.4);
  vec3 margin = applyTint(mix(back, back * (0.1 + 0.6 * back), edge), u_tint);

  float g = max(d - MARGIN, 0.0);
  float m = min(u_resolution.x, u_resolution.y) - 2.0 * MARGIN;

  float amount = min(60.0, 0.65 * m);
  float height = min(20.0, 0.36 * m);
  float t = clamp(1.0 - g / height, 0.0, 1.0);
  float offset = amount * (1.0 - sqrt(1.0 - t * t));
  vec2 suv = uv + inward * offset * px;

  vec3 c = vec3(0.0);
  float total = 0.0;
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float r = sqrt((fi + 0.5) / 16.0) * 2.5 * BLUR_SIGMA;
    float a = fi * 2.39996;
    vec2 o = vec2(cos(a), sin(a)) * r;
    float wgt = exp(-dot(o, o) / (2.0 * BLUR_SIGMA * BLUR_SIGMA));
    c += wgt * texture2D(u_backdrop, suv + o * px).rgb;
    total += wgt;
  }
  c /= total;

  float luma = dot(c, LUMA);
  c = clamp(0.125 + 0.955 * luma + 1.06 * (c - luma), 0.0, 1.0);

  c = applyTint(c, u_tint);

  float spread = radians(80.0 + 10.0 * clamp((m - 96.0) / 96.0, 0.0, 1.0));
  float light = rimLight(normal, g, 0.0, spread) + rimLight(normal, g, 3.1415927, spread);

  vec3 gain = min(0.375 * (c + 0.58), 1.08 - c);
  c = clamp(c + light * gain, 0.0, 1.0);

  float inside = clamp((d - 0.5 * MARGIN) / MARGIN, 0.0, 1.0);
  gl_FragColor = vec4(mix(margin, c, inside), 1.0);
}
