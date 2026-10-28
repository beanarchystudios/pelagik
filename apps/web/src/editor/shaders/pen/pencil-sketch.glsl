/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @content */
uniform sampler2D u_content;

/** @sdf */
uniform sampler2D u_sdf;

/**
 * @label Paper
 * @color
 * @default #F6F1E7
 */
uniform vec3 u_paper;

/**
 * @label Pencil
 * @color
 * @default #2B2B33
 */
uniform vec3 u_pencil;

/**
 * @label Color Pencil
 * @default 0.6
 * @range 0, 1
 */
uniform float u_tint;

/**
 * @label Line Width
 * @default 3
 * @range 0.5, 12
 */
uniform float u_lineWidth;

/**
 * @label Hatch Spacing
 * @default 11
 * @range 3, 60
 */
uniform float u_hatchSpacing;

/**
 * @label Wobble
 * @default 4
 * @range 0, 20
 */
uniform float u_wobble;

/**
 * @label Boil Speed
 * @default 5
 * @range 0, 24
 */
uniform float u_boil;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
  vec2 cell = floor(p);
  vec2 local = fract(p);
  vec2 blend = local * local * (3.0 - 2.0 * local);

  float bottom = mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x);
  float top = mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x);

  return mix(bottom, top, blend.y);
}

vec2 warp(vec2 p, float seed, float amount) {
  vec2 q = p / 85.0 + vec2(seed * 13.7, seed * 5.3);
  vec2 offset = vec2(valueNoise(q), valueNoise(q + vec2(31.4, 17.9))) - 0.5;

  return p + offset * 2.0 * amount;
}

float hatch(vec2 p, float angle, float spacing, float thickness) {
  float coord = p.x * cos(angle) + p.y * sin(angle);
  float lineDistance = abs(fract(coord / spacing) - 0.5) * spacing;

  return 1.0 - smoothstep(thickness * 0.5 - 0.7, thickness * 0.5 + 0.7, lineDistance);
}

void main() {
  vec2 p = gl_FragCoord.xy;
  float drawing = floor(u_time * u_boil);

  vec2 firstPass = warp(p, drawing, u_wobble);
  vec2 secondPass = warp(p, drawing + 41.0, u_wobble * 1.6);

  float firstDist = texture2D(u_sdf, firstPass / u_resolution).r;
  float secondDist = texture2D(u_sdf, secondPass / u_resolution).r;

  float halfWidth = u_lineWidth * 0.5;
  float outline = 1.0 - smoothstep(halfWidth - 0.8, halfWidth + 0.8, abs(firstDist));
  float ghost = 1.0 - smoothstep(halfWidth * 0.6 - 0.8, halfWidth * 0.6 + 0.8, abs(secondDist + 2.0));
  outline = max(outline, ghost * 0.55);

  vec4 content = texture2D(u_content, firstPass / u_resolution);
  vec3 color = content.rgb / max(content.a, 0.0001);
  float darkness = (1.0 - dot(color, vec3(0.299, 0.587, 0.114))) * content.a;

  vec2 hatchPos = warp(p, drawing + 7.0, u_wobble * 0.6);
  float spacing = max(u_hatchSpacing, 1.0);
  float thickness = u_lineWidth * 0.8;

  float shade = hatch(hatchPos, 0.785, spacing, thickness) * smoothstep(0.08, 0.3, darkness);
  shade = max(shade, hatch(hatchPos, -0.785, spacing * 1.15, thickness) * smoothstep(0.4, 0.6, darkness));
  shade = max(shade, hatch(hatchPos, 0.15, spacing * 0.8, thickness) * smoothstep(0.7, 0.9, darkness));

  float tooth = valueNoise(p / 1.7 + vec2(drawing * 3.1, 0.0));
  float graphite = clamp(max(outline, shade * 0.8) * (0.55 + 0.45 * tooth), 0.0, 1.0);

  vec3 lead = mix(u_pencil, color * 0.6, u_tint * content.a);
  float paperGrain = valueNoise(p / 2.3) * 0.5 + valueNoise(p / 37.0) * 0.5;
  vec3 paper = u_paper * (1.0 - 0.06 * paperGrain);

  gl_FragColor = vec4(mix(paper, lead, graphite), 1.0);
}
