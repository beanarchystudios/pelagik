precision highp float;

/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/** @backdrop */
uniform sampler2D u_backdrop;

/**
 * @label Scale
 * @default 90
 * @range 20, 400
 */
uniform float u_scale;

/**
 * @label Roughness
 * @default 1
 * @range 0, 2
 */
uniform float u_rough;

/**
 * @label Cracks
 * @default 0.5
 * @range 0, 1
 */
uniform float u_cracks;

/**
 * @label Heat
 * @default 1.2
 * @range 0, 3
 */
uniform float u_heat;

/**
 * @label Pulse
 * @default 0.7
 * @range 0, 1
 */
uniform float u_pulse;

/**
 * @label Depth Angle
 * @default 320
 * @range 0, 360
 */
uniform float u_depthAngle;

/**
 * @label Face Split
 * @default 0.36
 * @range 0.05, 0.9
 */
uniform float u_split;

/**
 * @label Halo
 * @default 0.6
 * @range 0, 2
 */
uniform float u_halo;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
  float n = hash21(p);
  return vec2(n, hash21(p + n + 17.0));
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
             mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float s = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    s += a * noise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 3.1;
    a *= 0.5;
  }
  return s;
}

vec2 voronoi(vec2 x) {
  vec2 n = floor(x);
  vec2 f = fract(x);
  float f1 = 8.0;
  float f2 = 8.0;
  vec2 id = vec2(0.0);
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 g = vec2(float(i), float(j));
      vec2 o = hash22(n + g);
      float d = length(g + o - f);
      if (d < f1) { f2 = f1; f1 = d; id = n + g; }
      else if (d < f2) { f2 = d; }
    }
  }
  return vec2(f2 - f1, hash21(id));
}

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 back(vec2 px) { return texture2D(u_backdrop, px / u_resolution).rgb; }

vec3 lavaRamp(float v) {
  vec3 c = mix(vec3(0.12, 0.0, 0.0), vec3(0.9, 0.06, 0.02), smoothstep(0.0, 0.35, v));
  c = mix(c, vec3(1.0, 0.32, 0.08), smoothstep(0.35, 0.7, v));
  c = mix(c, vec3(1.0, 0.85, 0.55), smoothstep(0.75, 1.1, v));
  return c;
}

void main() {
  vec2 px = gl_FragCoord.xy;
  float t = u_time;
  vec3 src = back(px);
  float L = lum(src);

  float obj = smoothstep(0.03, 0.08, max(max(src.r, src.g), src.b));

  float side = smoothstep(u_split - 0.03, u_split + 0.03, L);
  float under = (1.0 - smoothstep(0.12, 0.2, L)) * obj;
  float front = (1.0 - side) * (1.0 - under);

  float glowPulse = 0.85 + 0.15 * sin(t * 1.3) * u_pulse;
  vec3 col = vec3(0.0);

  if (obj > 0.0) {

    float e = 2.0;
    float gx = lum(back(px + vec2(e, 0.0))) - lum(back(px - vec2(e, 0.0)));
    float gy = lum(back(px + vec2(0.0, e))) - lum(back(px - vec2(0.0, e)));
    float faceEdge = smoothstep(0.04, 0.14, length(vec2(gx, gy))) * obj;

    float a = radians(u_depthAngle);
    vec2 dir = vec2(cos(a), sin(a));
    vec2 perp = vec2(-dir.y, dir.x);
    vec2 pf = px / u_scale;
    vec2 ps = vec2(dot(px, perp) / u_scale, dot(px, dir) / (u_scale * 3.0)) + vec2(13.7, 4.2);
    float isFront = step(0.5, front);
    vec2 p = mix(ps, pf, isFront);

    float h = fbm(p * 1.3);
    float hx = fbm((p + vec2(0.01, 0.0)) * 1.3);
    float hy = fbm((p + vec2(0.0, 0.01)) * 1.3);
    vec2 hg = vec2(hx - h, hy - h) / 0.01;

    vec2 pc = p * 5.0;
    float r1 = 1.0 - abs(2.0 * noise(pc) - 1.0);
    float r1x = 1.0 - abs(2.0 * noise(pc + vec2(0.05, 0.0)) - 1.0);
    float r1y = 1.0 - abs(2.0 * noise(pc + vec2(0.0, 0.05)) - 1.0);
    hg += vec2(r1x - r1, r1y - r1) / 0.05 * 0.35;
    float lit = dot(hg, normalize(vec2(-0.6, 0.8))) * 0.3 * u_rough;
    float bump = clamp(1.0 + lit, 0.25, 2.0);

    float crest = pow(max(lit, 0.0), 2.0) * 0.6;
    float grain = noise(px * 0.8) * 0.6 + noise(px * 0.3) * 0.4;
    float pits = smoothstep(0.58, 0.45, fbm(p * 11.0 + 7.0));
    vec3 albedo = mix(vec3(0.09, 0.085, 0.09), vec3(0.3, 0.29, 0.3), grain);
    albedo *= mix(0.6, 1.0, pits);
    albedo *= 0.9 + 0.2 * h;

    float shade = L * mix(1.0, 1.25, isFront) * 2.2;
    vec3 stone = albedo * shade * bump + vec3(crest) * shade * 0.5;

    vec2 w = p * 1.1 + 0.35 * vec2(fbm(p * 2.0), fbm(p * 2.0 + 5.0));
    vec2 vo = voronoi(w);
    float width = 0.05 + 0.07 * noise(p * 3.0);
    float crack = 1.0 - smoothstep(0.0, width, vo.x);
    float core = 1.0 - smoothstep(0.0, width * 0.35, vo.x);
    float spill = exp(-vo.x * 7.0);

    float region = fbm(p * 0.45 + vec2(t * 0.03, -t * 0.02));
    float open = smoothstep(0.75 - u_cracks * 0.45, 0.8 - u_cracks * 0.45, region);

    float cellPulse = 0.5 + 0.5 * sin(t * (1.2 + 2.6 * vo.y) + vo.y * 40.0);
    cellPulse = pow(cellPulse, 2.0);
    float flare = smoothstep(0.55, 0.85, noise(p * 1.7 + vec2(t * 0.5, t * 0.35)));
    float flicker = 0.9 + 0.1 * noise(vec2(t * 9.0, vo.y * 50.0));
    float throb = mix(1.0, 0.35 + 0.9 * cellPulse + 0.7 * flare, u_pulse) * flicker;

    float heat = (crack * 0.55 + core * 0.35 + spill * 0.15) * open * throb;

    heat += faceEdge * smoothstep(0.5, 0.75, noise(p * 2.5 + 9.0)) * 0.35 * throb * (0.3 + open);
    heat *= obj * u_heat;

    col = stone * obj;
    col = mix(col, col * vec3(2.2, 0.7, 0.5) + vec3(0.22, 0.02, 0.0) * glowPulse * u_heat, under);

    col += vec3(0.9, 0.12, 0.03) * spill * open * throb * 0.35 * obj * u_heat;
    col += lavaRamp(heat) * smoothstep(0.02, 0.4, heat) * heat * 1.2;

    float rim = 0.0;
    for (int i = 0; i < 8; i++) {
      float an = float(i) * 0.7854;
      rim += smoothstep(0.03, 0.08, lum(back(px + vec2(cos(an), sin(an)) * 3.0)) * 1.4);
    }
    rim = obj * (1.0 - rim / 8.0);
    col += vec3(1.0, 0.18, 0.04) * rim * 0.6 * u_heat * glowPulse;
  }

  float halo = 0.0;
  if (obj < 1.0 && u_halo > 0.0) {
    float spin = 6.2831853 * fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
    for (int i = 0; i < 24; i++) {
      float fi = float(i);
      float r = 8.0 + sqrt((fi + 0.5) / 24.0) * 70.0;
      float an = fi * 2.39996 + spin;
      halo += smoothstep(0.03, 0.08, lum(back(px + vec2(cos(an), sin(an)) * r)) * 1.4);
    }
    halo /= 24.0;
    halo *= halo;
  }

  vec3 bg = src * (1.0 - obj);
  col += bg;
  col += vec3(0.55, 0.06, 0.01) * halo * (1.0 - obj) * u_halo * glowPulse * 0.7;

  vec3 over = max(col - 0.85, 0.0);
  col = min(col, vec3(0.85)) + over / (1.0 + 1.5 * over);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
