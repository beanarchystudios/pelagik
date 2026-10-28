import { LEGACY_SHADER_IDS } from "@pelagik/design-core/shader-ids"
import type { ShaderId } from "@pelagik/design-core/types"
import { PEN_SHADER_FAMILIES as GENERATED_PEN_FAMILIES } from "./penCatalog.generated"

export type ShaderCategory = "Image filters" | "Effects" | "Pen shaders"

export interface ShaderPreset {
  id: ShaderId
  name: string
  category: ShaderCategory
  description: string
  previewColor: string
  familyId?: string
  familyName?: string
  familyType?: "Fill" | "Effect" | "Backdrop" | "Stroke"
  variantLabel?: string
  preview?: string
  source?: string
  uniforms?: Readonly<Record<string, number | string>>
  placement?: number
  credit?: string
}

export interface PenShaderFamily {
  id: string
  name: string
  type: "Fill" | "Effect" | "Backdrop" | "Stroke"
  caption: string
  credit: string
  examples: ShaderPreset[]
  defaultExample: ShaderPreset
}

const LEGACY_SHADERS: ShaderPreset[] = [
  { id: "paper-texture", name: "Paper Texture", category: "Image filters", description: "Warm paper grain and fibers", previewColor: "#dfb86b" },
  { id: "fluted-glass", name: "Fluted Glass", category: "Image filters", description: "Vertical glass refraction", previewColor: "#83abc2" },
  { id: "water", name: "Water", category: "Image filters", description: "Rippling highlights", previewColor: "#e5a73f" },
  { id: "image-dithering", name: "Image Dithering", category: "Image filters", description: "Quantized green halftone", previewColor: "#72d79a" },
  { id: "halftone-dots", name: "Halftone Dots", category: "Image filters", description: "Monochrome printed dots", previewColor: "#ded7be" },
  { id: "halftone-cmyk", name: "Halftone CMYK", category: "Image filters", description: "Offset four-color print", previewColor: "#e9c35e" },
  { id: "lens-distortion", name: "Lens Distortion", category: "Image filters", description: "Prismatic lens refraction", previewColor: "#efa67c" },
  { id: "heatmap", name: "Heatmap", category: "Effects", description: "Color-mapped energy field", previewColor: "#268aff" },
  { id: "liquid-metal", name: "Liquid Metal", category: "Effects", description: "Polished reflective waves", previewColor: "#b7b5bd" },
  { id: "gem-smoke", name: "Gem Smoke", category: "Effects", description: "Iridescent smoke and light", previewColor: "#e1d7d2" },
  { id: "soft-glow", name: "Soft Glow", category: "Effects", description: "A soft luminous bloom", previewColor: "#20d7f3" },
  { id: "ascii-echo", name: "ASCII Echo", category: "Pen shaders", description: "Phosphor characters with a trailing digital echo", previewColor: "#086b37" },
  { id: "auro-bevel", name: "Aurō Bevel", category: "Pen shaders", description: "Warm metallic bevel lighting", previewColor: "#e89435" },
  { id: "auro-flow", name: "Aurō Flow", category: "Pen shaders", description: "Fluid neon ribbons in magenta, violet, and teal", previewColor: "#b947d7" },
  { id: "aurora", name: "Aurora", category: "Pen shaders", description: "Soft flowing aurora bands with prismatic color", previewColor: "#8bc9a7" },
  { id: "liquid-glass", name: "Liquid Glass", category: "Effects", description: "Translucent glass with rim light", previewColor: "#d5e5fa" },
]

const LEGACY_PEN_ALIASES = new Set(["ascii-echo", "auro-bevel", "auro-flow", "aurora", "liquid-glass"])

function previewColor(uniforms: Readonly<Record<string, number | string>>): string {
  const color = Object.values(uniforms).find((value) => typeof value === "string" && /^#[\da-f]{3,8}$/i.test(value))
  return typeof color === "string" ? color : "#d9d9d9"
}

export const PEN_SHADER_FAMILIES: PenShaderFamily[] = GENERATED_PEN_FAMILIES.map((family) => {
  const caption = family.caption.replace(/^In use\s*\/\s*/, "")
  const examples = family.examples.map((example) => {
    const uniforms = example.uniforms as Readonly<Record<string, number | string>>
    return {
      id: `pen-${example.id}` as ShaderId,
      name: example.name,
      category: "Pen shaders" as const,
      description: `${caption}${family.credit ? ` · ${family.credit}` : ""}`,
      previewColor: previewColor(uniforms),
      familyId: family.id,
      familyName: family.name,
      familyType: family.type,
      variantLabel: example.label === "In use" ? "Showcase" : example.label,
      preview: example.preview,
      source: example.source,
      uniforms,
      placement: example.placement,
      credit: family.credit,
    }
  })
  const defaultExample = examples.find((example) => example.variantLabel === "Shader only") ?? examples[0]
  return { id: family.id, name: family.name, type: family.type, caption, credit: family.credit, examples, defaultExample }
})

const visibleLegacyShaders = LEGACY_SHADERS.filter((shader) => !LEGACY_PEN_ALIASES.has(shader.id))
export const SHADERS: ShaderPreset[] = [...visibleLegacyShaders, ...PEN_SHADER_FAMILIES.flatMap((family) => family.examples)]

const SHADERS_BY_ID = new Map(SHADERS.map((shader) => [shader.id, shader]))
const LEGACY_SHADERS_BY_ID = new Map(LEGACY_SHADERS.map((shader) => [shader.id, shader]))
const FAMILY_BY_ID = new Map(PEN_SHADER_FAMILIES.map((family) => [family.id, family]))
const FAMILY_BY_LEGACY_ALIAS = new Map([
  ["ascii-echo", "ascii-echo"],
  ["auro-bevel", "auro-bevel"],
  ["auro-flow", "auro-flow"],
  ["aurora", "aurora"],
  ["liquid-glass", "liquid-glass"],
])

export function getShaderPreset(id: ShaderId): ShaderPreset | undefined {
  return SHADERS_BY_ID.get(id) ?? LEGACY_SHADERS_BY_ID.get(id)
}

export function getPenShaderFamily(id: string): PenShaderFamily | undefined {
  return FAMILY_BY_ID.get(id)
}

export function getPenShaderVariant(id: ShaderId): ShaderPreset | undefined {
  return SHADERS_BY_ID.get(id)?.source ? SHADERS_BY_ID.get(id) : undefined
}

export function getPenShaderDefault(family: PenShaderFamily): ShaderPreset {
  return family.defaultExample
}

export function isPenShader(id: ShaderId | null): boolean {
  return id ? Boolean(getPenShaderVariant(id)) : false
}

export function isLiquidGlassShader(id: ShaderId | null): boolean {
  if (!id) return false
  const preset = getShaderPreset(id)
  if (preset?.familyId === "liquid-glass") return true
  return preset?.id === "liquid-glass"
}

export function shaderName(id: ShaderId | null): string | null {
  if (!id) return null
  const preset = getShaderPreset(id)
  if (preset) return preset.familyName && preset.variantLabel !== "Shader only"
    ? `${preset.familyName} · ${preset.variantLabel}`
    : preset.familyName ?? preset.name
  const alias = FAMILY_BY_LEGACY_ALIAS.get(id)
  return alias ? FAMILY_BY_ID.get(alias)?.name ?? null : null
}

export function isLegacyShaderId(id: ShaderId): id is (typeof LEGACY_SHADER_IDS)[number] {
  return (LEGACY_SHADER_IDS as readonly string[]).includes(id)
}
