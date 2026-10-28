import type { ShaderId } from "@pelagik/design-core/types"
import type { LegacyShaderId } from "@pelagik/design-core/shader-ids"
import { getPenShaderVariant } from "./catalog"

const PEN_SHADER_SOURCES = import.meta.glob("./pen/*.glsl", { query: "?raw", import: "default", eager: true }) as Record<string, string>

const VERTEX_SOURCE = `
attribute vec2 a_position;
varying vec2 v_uv;
void main() {
  v_uv = (a_position + 1.0) * 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}`

const FRAGMENT_SOURCE = `
precision highp float;
varying vec2 v_uv;
uniform vec2 u_resolution;
uniform vec3 u_base;
uniform float u_alpha;
uniform float u_kind;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
             mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 5; i++) {
    value += amplitude * noise2(p);
    p = p * 2.03 + 11.7;
    amplitude *= 0.5;
  }
  return value;
}

float dotScreen(vec2 uv, float angle, float size, float ink) {
  float c = cos(angle);
  float s = sin(angle);
  vec2 point = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y) * size;
  float distanceToDot = length(fract(point) - 0.5);
  float radius = 0.08 + ink * 0.48;
  return 1.0 - smoothstep(radius - 0.035, radius + 0.035, distanceToDot);
}

vec3 heatColor(float t) {
  vec3 navy = vec3(0.01, 0.04, 0.26);
  vec3 blue = vec3(0.02, 0.48, 1.0);
  vec3 yellow = vec3(1.0, 0.91, 0.12);
  vec3 red = vec3(1.0, 0.08, 0.02);
  return t < 0.38 ? mix(navy, blue, t / 0.38)
    : t < 0.72 ? mix(blue, yellow, (t - 0.38) / 0.34)
    : mix(yellow, red, (t - 0.72) / 0.28);
}

void main() {
  vec2 uv = v_uv;
  vec2 aspectUv = (uv - 0.5) * vec2(u_resolution.x / max(u_resolution.y, 1.0), 1.0);
  float luminance = dot(u_base, vec3(0.2126, 0.7152, 0.0722));
  vec3 color = u_base;
  float opacity = 1.0;

  if (u_kind < 0.5) {
    float fibers = noise2(uv * u_resolution * vec2(0.035, 0.12));
    float grain = hash21(gl_FragCoord.xy) - 0.5;
    float tone = 0.88 + fibers * 0.16 + grain * 0.16;
    color = mix(u_base, vec3(1.0, 0.93, 0.77), 0.13) * tone;
  } else if (u_kind < 1.5) {
    float flute = sin(uv.x * 92.0 + sin(uv.y * 8.0) * 1.4);
    float highlight = pow(max(flute, 0.0), 8.0);
    float shade = 0.78 + 0.15 * flute + 0.45 * highlight;
    color = mix(u_base, vec3(0.78, 0.92, 0.98), 0.22) * shade;
  } else if (u_kind < 2.5) {
    float radius = length(aspectUv);
    float rings = sin(radius * 72.0 - fbm(uv * 7.0) * 7.0);
    float highlight = pow(max(rings, 0.0), 7.0);
    color = mix(u_base, vec3(0.58, 0.83, 0.96), 0.19 + highlight * 0.28);
    color += highlight * vec3(0.38, 0.48, 0.56);
  } else if (u_kind < 3.5) {
    float threshold = hash21(floor(gl_FragCoord.xy / 2.0));
    float level = floor(luminance * 5.0 + threshold) / 4.0;
    color = mix(vec3(0.025, 0.14, 0.12), vec3(0.75, 1.0, 0.55), clamp(level, 0.0, 1.0));
  } else if (u_kind < 4.5) {
    float screen = dotScreen(uv, 0.0, min(u_resolution.x, u_resolution.y) * 0.16, luminance);
    color = mix(u_base * 0.2, u_base * 1.1 + vec3(0.08), screen);
  } else if (u_kind < 5.5) {
    float c = dotScreen(uv, 0.26, min(u_resolution.x, u_resolution.y) * 0.18, 1.0 - u_base.r);
    float m = dotScreen(uv, 1.31, min(u_resolution.x, u_resolution.y) * 0.18, 1.0 - u_base.g);
    float y = dotScreen(uv, 0.79, min(u_resolution.x, u_resolution.y) * 0.18, 1.0 - u_base.b);
    float k = dotScreen(uv, 1.05, min(u_resolution.x, u_resolution.y) * 0.18, 1.0 - luminance);
    color = vec3(1.0) * (1.0 - c * vec3(0.0, 0.7, 0.9))
      * (1.0 - m * vec3(0.85, 0.0, 0.5)) * (1.0 - y * vec3(1.0, 0.75, 0.0)) * (1.0 - k * 0.8);
  } else if (u_kind < 6.5) {
    float radius = length(aspectUv);
    float fringe = smoothstep(0.08, 0.72, radius);
    float angle = atan(aspectUv.y, aspectUv.x);
    float spectral = 0.5 + 0.5 * sin(angle * 2.0 + radius * 15.0);
    vec3 prism = mix(vec3(0.1, 0.8, 1.0), vec3(1.0, 0.25, 0.48), spectral);
    float lens = exp(-radius * radius * 3.0);
    color = mix(u_base, prism, fringe * 0.56) + lens * vec3(0.26, 0.24, 0.18);
  } else if (u_kind < 7.5) {
    float field = fbm(uv * 5.0 + vec2(sin(uv.y * 5.0), cos(uv.x * 4.0)));
    color = mix(heatColor(field), u_base, 0.18);
  } else if (u_kind < 8.5) {
    float bands = sin(uv.y * 26.0 + sin(uv.x * 10.0) * 4.0 + fbm(uv * 5.0) * 8.0);
    float reflection = smoothstep(-0.15, 0.82, bands);
    vec3 chrome = mix(vec3(0.035), vec3(0.96), reflection);
    chrome = mix(chrome, vec3(0.28, 0.34, 0.48), 0.18 + fbm(uv * 12.0) * 0.18);
    color = mix(chrome, u_base, 0.34);
  } else if (u_kind < 9.5) {
    vec2 swirl = uv * 5.0 + vec2(fbm(uv * 4.0), fbm(uv * 4.0 + 9.0));
    float cloud = fbm(swirl * 2.0);
    float glint = pow(max(0.0, sin((uv.x + uv.y) * 22.0 + cloud * 9.0)), 8.0);
    vec3 smoke = mix(vec3(0.25, 0.07, 0.42), vec3(0.94, 0.72, 0.92), cloud);
    color = mix(smoke, u_base, 0.29) + glint * vec3(0.38, 0.48, 0.76);
  } else if (u_kind < 10.5) {
    float radius = length(aspectUv);
    float glow = exp(-radius * radius * 8.5);
    float haloOffset = radius - 0.3;
    float halo = exp(-haloOffset * haloOffset * 46.0);
    vec3 light = mix(vec3(0.03, 0.28, 0.92), vec3(0.08, 0.92, 1.0), uv.y);
    color = mix(u_base * 0.15, light, glow * 0.86) + halo * vec3(0.28, 0.72, 1.0);
  } else if (u_kind < 11.5) {
    vec2 glyph = floor(gl_FragCoord.xy / vec2(6.0, 9.0));
    vec2 glyphPixel = floor(mod(gl_FragCoord.xy, vec2(6.0, 9.0)));
    float ink = step(0.51, hash21(glyph * 7.1 + glyphPixel * 3.7));
    float shieldWidth = 0.68 - uv.y * 0.38;
    float shield = step(abs(uv.x - 0.5), shieldWidth * 0.5) * smoothstep(0.02, 0.98, uv.y);
    float scan = 0.86 + 0.14 * sin(gl_FragCoord.y * 2.2);
    float echo = step(0.91, hash21(glyph + vec2(12.0, 4.0))) * smoothstep(0.32, 0.9, uv.x);
    float brightness = clamp((0.08 + shield * 0.64 + luminance * 0.2) * ink + echo * 0.55, 0.0, 1.0) * scan;
    color = mix(vec3(0.008, 0.075, 0.04), vec3(0.14, 1.0, 0.45), brightness);
    color += vec3(0.02, 0.25, 0.09) * noise2(uv * u_resolution * 0.17);
  } else if (u_kind < 12.5) {
    float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float rim = 1.0 - smoothstep(0.015, 0.16, edge);
    float topLight = exp(-((uv.y - 0.13) * (uv.y - 0.13)) * 145.0);
    float lowerLight = exp(-((uv.y - 0.86) * (uv.y - 0.86)) * 82.0);
    float wave = 0.5 + 0.5 * sin(uv.x * 8.0 + sin(uv.y * 9.0) * 2.0);
    float crown = 1.0 - smoothstep(0.04, 0.47, uv.y + 0.12 * sin(uv.x * 4.0));
    vec3 bronze = mix(vec3(0.98, 0.39, 0.07), vec3(1.0, 0.84, 0.49), lowerLight + rim * 0.46);
    vec3 darkMetal = mix(vec3(0.035, 0.025, 0.025), vec3(0.20, 0.10, 0.06), wave * 0.38);
    color = mix(bronze, darkMetal, crown * 0.94);
    color += vec3(1.0, 0.63, 0.25) * (rim * 0.52 + topLight * 0.72);
    color = mix(color, u_base, 0.12);
  } else if (u_kind < 13.5) {
    vec2 flowUv = uv * 4.3;
    float warp = fbm(flowUv + vec2(0.0, 2.0));
    float flow = fbm(flowUv + vec2(warp * 1.7, sin(uv.y * 5.0) * 0.9));
    float ribbon = sin(uv.y * 15.0 + uv.x * 5.0 + flow * 9.0);
    float glint = exp(-(ribbon * ribbon) * 15.0);
    vec3 violet = vec3(0.34, 0.035, 0.58);
    vec3 pink = vec3(1.0, 0.14, 0.56);
    vec3 cyan = vec3(0.08, 0.91, 0.79);
    vec3 current = mix(violet, pink, smoothstep(0.12, 0.82, flow + uv.x * 0.12));
    current = mix(current, cyan, smoothstep(0.62, 0.95, flow + sin(uv.x * 7.0) * 0.11));
    color = current * (0.48 + flow * 0.65) + glint * vec3(0.72, 0.86, 1.0) * 0.46;
    color = mix(color, u_base, 0.17);
  } else if (u_kind < 14.5) {
    float field = fbm(uv * 3.2 + vec2(sin(uv.y * 4.0), cos(uv.x * 3.0)));
    float ribbonA = sin(uv.x * 7.0 + field * 8.0 + sin(uv.y * 4.0));
    float ribbonB = sin(uv.x * 4.2 - uv.y * 5.0 + field * 5.0 + 2.0);
    float aurora = exp(-(ribbonA * ribbonA) * 5.5) * 0.72 + exp(-(ribbonB * ribbonB) * 8.0) * 0.42;
    vec3 deep = vec3(0.025, 0.045, 0.10);
    vec3 green = vec3(0.18, 0.88, 0.55);
    vec3 lilac = vec3(0.55, 0.34, 0.95);
    vec3 sky = mix(green, lilac, smoothstep(0.28, 0.82, field + uv.x * 0.15));
    color = mix(deep, vec3(0.82, 0.87, 0.81), uv.y * 0.48 + field * 0.12);
    color = mix(color, sky, clamp(aurora, 0.0, 1.0) * 0.9);
    color += aurora * aurora * vec3(0.23, 0.31, 0.35);
    color = mix(color, u_base, 0.2);
  } else {
    float edge = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
    float rim = smoothstep(0.70, 0.99, edge);
    float insetRim = 1.0 - smoothstep(0.92, 1.0, edge);
    float wobble = sin(uv.x * 9.0 + sin(uv.y * 11.0) * 1.7);
    float upperDistance = (uv.y - 0.13 - wobble * 0.012) * 28.0;
    float lowerDistance = (uv.y - 0.89 + wobble * 0.008) * 36.0;
    float reflectionDistance = (uv.x - 0.2 - uv.y * 0.16) * 5.0;
    float upperGlint = exp(-upperDistance * upperDistance);
    float lowerGlint = exp(-lowerDistance * lowerDistance);
    float broadReflection = exp(-reflectionDistance * reflectionDistance) * 0.24;
    float refraction = fbm(uv * 7.0 + vec2(1.7, 3.1));
    vec3 tint = mix(u_base, vec3(0.78, 0.88, 1.0), 0.48);
    vec3 iridescence = mix(vec3(0.65, 0.84, 1.0), vec3(1.0, 0.74, 0.88), uv.x);
    color = mix(tint, vec3(1.0), upperGlint * 0.56 + lowerGlint * 0.24 + broadReflection);
    color += iridescence * (rim * 0.24 + refraction * 0.035);
    color += vec3(1.0) * (rim * 0.12 + upperGlint * 0.22 + lowerGlint * 0.09);
    opacity = clamp(0.10 + insetRim * 0.065 + rim * 0.18 + upperGlint * 0.12 + lowerGlint * 0.08 + broadReflection * 0.24, 0.08, 0.54);
  }

  gl_FragColor = vec4(clamp(color, 0.0, 1.0), clamp(opacity * u_alpha, 0.0, 1.0));
}`

const SHADER_INDEX: Record<LegacyShaderId, number> = {
  "paper-texture": 0,
  "fluted-glass": 1,
  water: 2,
  "image-dithering": 3,
  "halftone-dots": 4,
  "halftone-cmyk": 5,
  "lens-distortion": 6,
  heatmap: 7,
  "liquid-metal": 8,
  "gem-smoke": 9,
  "soft-glow": 10,
  "ascii-echo": 11,
  "auro-bevel": 12,
  "auro-flow": 13,
  aurora: 14,
  "liquid-glass": 15,
}

interface ShaderRenderer {
  canvas: HTMLCanvasElement
  gl: WebGLRenderingContext
  vertex: WebGLShader
  program: WebGLProgram
  buffer: WebGLBuffer
  position: number
  resolution: WebGLUniformLocation
  base: WebGLUniformLocation
  alpha: WebGLUniformLocation
  kind: WebGLUniformLocation
}

let renderer: ShaderRenderer | null | undefined
const imageCache = new Map<string, string>()
const colorCanvas = typeof document === "undefined" || typeof document.createElement !== "function" ? null : document.createElement("canvas")
const colorContext = colorCanvas?.getContext("2d", { willReadFrequently: true }) ?? null

function compileShader(gl: WebGLRenderingContext, type: number, source: string): WebGLShader | null {
  const shader = gl.createShader(type)
  if (!shader) return null
  gl.shaderSource(shader, source)
  gl.compileShader(shader)
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error("Shader compilation failed", gl.getShaderInfoLog(shader))
    gl.deleteShader(shader)
    return null
  }
  return shader
}

function getRenderer(): ShaderRenderer | null {
  if (renderer !== undefined) return renderer
  if (typeof document === "undefined" || typeof document.createElement !== "function") {
    renderer = null
    return renderer
  }

  const canvas = document.createElement("canvas")
  const gl = canvas.getContext("webgl", { alpha: true, antialias: false, preserveDrawingBuffer: true })
  if (!gl) {
    renderer = null
    return renderer
  }
  const vertex = compileShader(gl, gl.VERTEX_SHADER, VERTEX_SOURCE)
  const fragment = compileShader(gl, gl.FRAGMENT_SHADER, FRAGMENT_SOURCE)
  const program = gl.createProgram()
  if (!vertex || !fragment || !program) {
    renderer = null
    return renderer
  }
  gl.attachShader(program, vertex)
  gl.attachShader(program, fragment)
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    renderer = null
    return renderer
  }
  const buffer = gl.createBuffer()
  const position = gl.getAttribLocation(program, "a_position")
  const resolution = gl.getUniformLocation(program, "u_resolution")
  const base = gl.getUniformLocation(program, "u_base")
  const alpha = gl.getUniformLocation(program, "u_alpha")
  const kind = gl.getUniformLocation(program, "u_kind")
  if (!buffer || position < 0 || !resolution || !base || !alpha || !kind) {
    renderer = null
    return renderer
  }
  renderer = { canvas, gl, vertex, program, buffer, position, resolution, base, alpha, kind }
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)
  return renderer
}

function parseColor(value: string): [number, number, number, number] {
  if (!colorContext || !colorCanvas) return [0.85, 0.85, 0.85, 1]
  colorCanvas.width = 1
  colorCanvas.height = 1
  colorContext.clearRect(0, 0, 1, 1)
  colorContext.fillStyle = "#d9d9d9"
  colorContext.fillStyle = value
  colorContext.fillRect(0, 0, 1, 1)
  const pixel = colorContext.getImageData(0, 0, 1, 1).data
  return [pixel[0] / 255, pixel[1] / 255, pixel[2] / 255, pixel[3] / 255]
}

interface ShaderRenderOptions {
  shapeType?: "frame" | "rectangle" | "ellipse"
  radius?: number
}

interface PenUniform {
  name: string
  type: string
  defaultValue?: string
  location: WebGLUniformLocation | null
}

interface PenProgram {
  program: WebGLProgram
  position: number
  uniforms: PenUniform[]
}

const penPrograms = new Map<string, PenProgram | null>()

function getPenProgram(target: ShaderRenderer, sourceName: string): PenProgram | null {
  const cached = penPrograms.get(sourceName)
  if (cached !== undefined) return cached
  const { gl } = target
  const source = PEN_SHADER_SOURCES[`./pen/${sourceName}`]
  if (!source) {
    console.error("Missing bundled Pen shader source", sourceName, Object.keys(PEN_SHADER_SOURCES).slice(0, 3))
    penPrograms.set(sourceName, null)
    return null
  }
  const fragmentSource = /precision\s+\w+\s+float\s*;/.test(source) ? source : `precision highp float;\n${source}`
  const fragment = compileShader(gl, gl.FRAGMENT_SHADER, fragmentSource)
  const program = gl.createProgram()
  if (!fragment || !program) {
    penPrograms.set(sourceName, null)
    return null
  }
  gl.attachShader(program, target.vertex)
  gl.attachShader(program, fragment)
  gl.linkProgram(program)
  gl.deleteShader(fragment)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error("Shader program link failed", sourceName, gl.getProgramInfoLog(program))
    gl.deleteProgram(program)
    penPrograms.set(sourceName, null)
    return null
  }
  const uniforms = [...source.matchAll(/uniform\s+(?:(?:lowp|mediump|highp)\s+)?(\w+)\s+(\w+)\s*;/g)].map((match) => {
    const [, type, name] = match
    const docs = source.slice(Math.max(0, (match.index ?? 0) - 450), match.index)
    const defaultValue = [...docs.matchAll(/@default\s+([^\r\n*]+)/g)].at(-1)?.[1].trim()
    return { name, type, defaultValue, location: gl.getUniformLocation(program, name) }
  })
  const compiled = { program, position: gl.getAttribLocation(program, "a_position"), uniforms }
  if (compiled.position < 0) {
    gl.deleteProgram(program)
    penPrograms.set(sourceName, null)
    return null
  }
  penPrograms.set(sourceName, compiled)
  return compiled
}

function sdfDistance(x: number, y: number, width: number, height: number, shapeType: ShaderRenderOptions["shapeType"], radius: number): number {
  if (shapeType === "ellipse") {
    const rx = Math.max(width * 0.5, 1)
    const ry = Math.max(height * 0.5, 1)
    const k0 = Math.hypot(x / rx, y / ry)
    const k1 = Math.hypot(x / (rx * rx), y / (ry * ry))
    const signedOutside = k1 > 1e-6 ? (k0 * (k0 - 1)) / k1 : -Math.min(rx, ry)
    return -signedOutside
  }
  const rounded = Math.max(0, Math.min(radius, width * 0.5, height * 0.5))
  const qx = Math.abs(x) - (width * 0.5 - rounded)
  const qy = Math.abs(y) - (height * 0.5 - rounded)
  const signedOutside = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - rounded
  return -signedOutside
}

function makeSdfData(width: number, height: number, options: ShaderRenderOptions): Float32Array {
  const data = new Float32Array(width * height * 4)
  const distance = (x: number, y: number) => sdfDistance(x - width * 0.5, y - height * 0.5, width, height, options.shapeType, options.radius ?? 0)
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const signed = distance(x + 0.5, y + 0.5)
      const dx = distance(x + 1.5, y + 0.5) - distance(x - 0.5, y + 0.5)
      const dy = distance(x + 0.5, y + 1.5) - distance(x + 0.5, y - 0.5)
      const length = Math.hypot(dx, dy) || 1
      const index = (y * width + x) * 4
      data[index] = signed
      data[index + 1] = dx / length
      data[index + 2] = dy / length
      data[index + 3] = signed > 0 ? 1 : 0
    }
  }
  return data
}

function pathShape(ctx: CanvasRenderingContext2D, width: number, height: number, options: ShaderRenderOptions) {
  if (options.shapeType === "ellipse") {
    ctx.ellipse(width * 0.5, height * 0.5, width * 0.5, height * 0.5, 0, 0, Math.PI * 2)
    return
  }
  const radius = Math.max(0, Math.min(options.radius ?? 0, width * 0.5, height * 0.5))
  ctx.moveTo(radius, 0)
  ctx.lineTo(width - radius, 0)
  ctx.arcTo(width, 0, width, radius, radius)
  ctx.lineTo(width, height - radius)
  ctx.arcTo(width, height, width - radius, height, radius)
  ctx.lineTo(radius, height)
  ctx.arcTo(0, height, 0, height - radius, radius)
  ctx.lineTo(0, radius)
  ctx.arcTo(0, 0, radius, 0, radius)
  ctx.closePath()
}

function makeInputCanvas(width: number, height: number, color: string, kind: "content" | "backdrop" | "environment" | "text" | "atlas", options: ShaderRenderOptions): HTMLCanvasElement {
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext("2d")
  if (!ctx) return canvas
  ctx.clearRect(0, 0, width, height)
  if (kind === "content") {
    const gradient = ctx.createLinearGradient(0, 0, width, height)
    gradient.addColorStop(0, color)
    gradient.addColorStop(1, "rgba(255,255,255,.32)")
    ctx.beginPath()
    pathShape(ctx, width, height, options)
    ctx.fillStyle = gradient
    ctx.fill()
    ctx.save()
    ctx.globalCompositeOperation = "source-atop"
    ctx.fillStyle = "rgba(255,255,255,.24)"
    ctx.beginPath()
    ctx.ellipse(width * 0.3, height * 0.2, width * 0.46, height * 0.2, -0.18, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()
  } else if (kind === "environment") {
    const gradient = ctx.createLinearGradient(0, 0, 0, height)
    gradient.addColorStop(0, "#f9fbff")
    gradient.addColorStop(0.24, "#8395b1")
    gradient.addColorStop(0.48, "#172238")
    gradient.addColorStop(0.68, "#eef5ff")
    gradient.addColorStop(0.78, "#69798e")
    gradient.addColorStop(1, "#121923")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, width, height)
    ctx.fillStyle = "rgba(255,255,255,.88)"
    ctx.fillRect(width * 0.18, 0, width * 0.09, height)
    ctx.fillRect(width * 0.69, 0, width * 0.04, height)
    ctx.fillStyle = "rgba(20,28,48,.8)"
    ctx.fillRect(width * 0.42, 0, width * 0.12, height)
  } else if (kind === "text") {
    ctx.fillStyle = "#081119"
    ctx.fillRect(0, 0, width, height)
    ctx.fillStyle = "#dff4ee"
    ctx.font = `600 ${Math.max(9, Math.round(height * 0.07))}px monospace`
    for (let row = 0; row < 7; row++) {
      ctx.fillText(["const app = () => {", "  return <GlassCard />", "  await render(canvas)", "  setTheme(\"ocean\")", "  if (ready) ship()", "  exportDesign()", "}"].at(row) ?? "", width * 0.06, height * (0.16 + row * 0.11), width * 0.88)
    }
  } else if (kind === "atlas") {
    ctx.fillStyle = "#000"
    ctx.fillRect(0, 0, width, height)
    ctx.fillStyle = "#fff"
    const cellWidth = width / 8
    const cellHeight = height / 8
    for (let row = 0; row < 8; row++) {
      for (let column = 0; column < 8; column++) {
        const x = column * cellWidth
        const y = row * cellHeight
        if ((row + column) % 3 === 0) ctx.fillRect(x + cellWidth * 0.24, y + cellHeight * 0.18, cellWidth * 0.52, cellHeight * 0.64)
        else {
          ctx.fillRect(x + cellWidth * 0.18, y + cellHeight * 0.2, cellWidth * 0.64, cellHeight * 0.12)
          ctx.fillRect(x + cellWidth * 0.18, y + cellHeight * 0.68, cellWidth * 0.64, cellHeight * 0.12)
        }
      }
    }
  } else {
    const [r, g, b] = parseColor(color)
    const accent = `rgb(${Math.min(255, Math.round((1 - r) * 110 + 75))}, ${Math.min(255, Math.round(g * 125 + 95))}, ${Math.min(255, Math.round(b * 130 + 115))})`
    const gradient = ctx.createLinearGradient(0, 0, width, height)
    gradient.addColorStop(0, color)
    gradient.addColorStop(0.48, accent)
    gradient.addColorStop(1, "#111c31")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, width, height)
    const circles = [
      [0.12, 0.18, 0.24, "rgba(255,255,255,.46)"],
      [0.79, 0.21, 0.28, "rgba(251,190,152,.42)"],
      [0.77, 0.82, 0.34, "rgba(100,220,220,.42)"],
      [0.25, 0.78, 0.2, "rgba(159,153,255,.36)"],
    ] as const
    for (const [x, y, radius, fill] of circles) {
      const radial = ctx.createRadialGradient(width * x, height * y, 0, width * x, height * y, Math.min(width, height) * radius)
      radial.addColorStop(0, fill)
      radial.addColorStop(1, "rgba(255,255,255,0)")
      ctx.fillStyle = radial
      ctx.fillRect(0, 0, width, height)
    }
    ctx.fillStyle = "rgba(255,255,255,.26)"
    ctx.fillRect(0, height * 0.47, width, Math.max(1, height * 0.018))
  }
  return canvas
}

function makeCanvasTexture(gl: WebGLRenderingContext, source: HTMLCanvasElement): WebGLTexture | null {
  const texture = gl.createTexture()
  if (!texture) return null
  gl.bindTexture(gl.TEXTURE_2D, texture)
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, source)
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 0)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  return texture
}

function makeSdfTexture(gl: WebGLRenderingContext, width: number, height: number, options: ShaderRenderOptions): WebGLTexture | null {
  const texture = gl.createTexture()
  if (!texture) return null
  const extension = gl.getExtension("OES_texture_float")
  const data = makeSdfData(width, height, options)
  gl.bindTexture(gl.TEXTURE_2D, texture)
  if (extension) {
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.FLOAT, data)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.getExtension("OES_texture_float_linear") ? gl.LINEAR : gl.NEAREST)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.getExtension("OES_texture_float_linear") ? gl.LINEAR : gl.NEAREST)
  } else {
    const encoded = new Uint8Array(data.length)
    const range = Math.max(width, height)
    for (let index = 0; index < data.length; index += 4) {
      encoded[index] = Math.round(Math.max(0, Math.min(1, 0.5 + data[index] / (2 * range))) * 255)
      encoded[index + 1] = Math.round((data[index + 1] * 0.5 + 0.5) * 255)
      encoded[index + 2] = Math.round((data[index + 2] * 0.5 + 0.5) * 255)
      encoded[index + 3] = Math.round(data[index + 3] * 255)
    }
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, encoded)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  }
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  return texture
}

function uniformValues(uniform: PenUniform, preset: NonNullable<ReturnType<typeof getPenShaderVariant>>, width: number, height: number): number[] {
  if (uniform.name === "u_resolution") return [width, height]
  if (uniform.name === "u_time") return [1.35]
  if (uniform.name === "u_mouse") return [width * 0.5, height * 0.5]
  const value = preset.uniforms?.[uniform.name] ?? uniform.defaultValue
  if (typeof value === "string" && value.startsWith("#")) return parseColor(value)
  if (typeof value === "string") {
    const parts = value.match(/-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/gi)?.map(Number) ?? []
    if (parts.length) return parts
  }
  if (typeof value === "number") return [value]
  if (Array.isArray(value)) return value.map(Number)
  if (uniform.type === "vec2") return [0.5, 0.5]
  if (uniform.type === "vec3") return [0.8, 0.8, 0.8]
  if (uniform.type === "vec4") return [0.8, 0.8, 0.8, 1]
  return [0]
}

function bindUniform(gl: WebGLRenderingContext, uniform: PenUniform, preset: NonNullable<ReturnType<typeof getPenShaderVariant>>, width: number, height: number) {
  const location = uniform.location
  if (!location || uniform.type === "sampler2D") return
  const values = uniformValues(uniform, preset, width, height)
  if (uniform.type === "float") gl.uniform1f(location, values[0] ?? 0)
  else if (uniform.type === "int" || uniform.type === "bool") gl.uniform1i(location, Math.round(values[0] ?? 0))
  else if (uniform.type === "vec2") gl.uniform2f(location, values[0] ?? 0, values[1] ?? values[0] ?? 0)
  else if (uniform.type === "vec3") gl.uniform3f(location, values[0] ?? 0, values[1] ?? values[0] ?? 0, values[2] ?? values[0] ?? 0)
  else if (uniform.type === "vec4") gl.uniform4f(location, values[0] ?? 0, values[1] ?? values[0] ?? 0, values[2] ?? values[0] ?? 0, values[3] ?? 1)
}

function penTextureKind(name: string): "sdf" | "content" | "backdrop" | "environment" | "text" | "atlas" {
  if (name === "u_shape" || name === "u_sdf") return "sdf"
  if (name === "u_content") return "content"
  if (name === "u_text") return "text"
  if (name === "u_atlas") return "atlas"
  if (name === "u_env" || name === "u_environment") return "environment"
  return "backdrop"
}

function renderPenShaderImage(
  target: ShaderRenderer,
  shader: ShaderId,
  color: string,
  width: number,
  height: number,
  options: ShaderRenderOptions,
): string | null {
  const preset = getPenShaderVariant(shader)
  if (!preset?.source) return null
  const compiled = getPenProgram(target, preset.source)
  if (!compiled) return null
  const { canvas, gl } = target
  canvas.width = width
  canvas.height = height
  gl.viewport(0, 0, width, height)
  gl.clearColor(0, 0, 0, 0)
  gl.clear(gl.COLOR_BUFFER_BIT)
  gl.useProgram(compiled.program)
  gl.bindBuffer(gl.ARRAY_BUFFER, target.buffer)
  gl.enableVertexAttribArray(compiled.position)
  gl.vertexAttribPointer(compiled.position, 2, gl.FLOAT, false, 0, 0)

  const textures: WebGLTexture[] = []
  const sdf = makeSdfTexture(gl, width, height, options)
  const textureCache = new Map<string, WebGLTexture | null>()
  if (!sdf) return null
  textures.push(sdf)
  let textureUnit = 0
  for (const uniform of compiled.uniforms) {
    if (!uniform.location) continue
    if (uniform.type === "sampler2D") {
      const kind = penTextureKind(uniform.name)
      let texture = kind === "sdf" ? sdf : textureCache.get(kind)
      if (kind !== "sdf" && texture === undefined) {
        texture = makeCanvasTexture(gl, makeInputCanvas(width, height, color, kind, options))
        textureCache.set(kind, texture)
        if (texture) textures.push(texture)
      }
      if (!texture) continue
      gl.activeTexture(gl.TEXTURE0 + textureUnit)
      gl.bindTexture(gl.TEXTURE_2D, texture)
      gl.uniform1i(uniform.location, textureUnit)
      textureUnit += 1
    } else {
      bindUniform(gl, uniform, preset, width, height)
    }
  }
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
  const dataUrl = canvas.toDataURL("image/png")
  for (const texture of textures) gl.deleteTexture(texture)
  gl.activeTexture(gl.TEXTURE0)
  return dataUrl
}

/** Renders a catalogued shader to a cached image; specs select IDs and never contain source. */
export function renderShaderImage(
  shader: ShaderId,
  color: string,
  width: number,
  height: number,
  options: ShaderRenderOptions = {},
): string | null {
  const scale = Math.min(2, 1024 / Math.max(width, height, 1))
  const pixelWidth = Math.max(1, Math.round(width * scale))
  const pixelHeight = Math.max(1, Math.round(height * scale))
  const key = `${shader}:${color}:${pixelWidth}x${pixelHeight}:${options.shapeType ?? "rectangle"}:${options.radius ?? 0}`
  const cached = imageCache.get(key)
  if (cached) return cached

  const target = getRenderer()
  if (!target) return null
  const penShader = getPenShaderVariant(shader)
  let dataUrl: string | null
  if (penShader) {
    const pixelOptions = { ...options, radius: (options.radius ?? 0) * scale }
    dataUrl = renderPenShaderImage(target, shader, color, pixelWidth, pixelHeight, pixelOptions)
  } else {
    const kind = SHADER_INDEX[shader as keyof typeof SHADER_INDEX]
    if (kind === undefined) return null
    const { canvas, gl } = target
    canvas.width = pixelWidth
    canvas.height = pixelHeight
    gl.viewport(0, 0, pixelWidth, pixelHeight)
    gl.useProgram(target.program)
    gl.bindBuffer(gl.ARRAY_BUFFER, target.buffer)
    gl.enableVertexAttribArray(target.position)
    gl.vertexAttribPointer(target.position, 2, gl.FLOAT, false, 0, 0)
    gl.uniform2f(target.resolution, pixelWidth, pixelHeight)
    const [red, green, blue, alpha] = parseColor(color)
    gl.uniform3f(target.base, red, green, blue)
    gl.uniform1f(target.alpha, alpha)
    gl.uniform1f(target.kind, kind)
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    dataUrl = canvas.toDataURL("image/png")
  }
  if (!dataUrl) return null
  imageCache.set(key, dataUrl)
  if (imageCache.size > 100) imageCache.delete(imageCache.keys().next().value!)
  return dataUrl
}
