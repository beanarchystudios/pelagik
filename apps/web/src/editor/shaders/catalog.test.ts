import { expect, it } from "vitest"
import { PEN_SHADER_FAMILIES, SHADERS, getPenShaderVariant } from "./catalog"

const bundledSources = import.meta.glob("./pen/*.glsl", { query: "?raw", import: "default", eager: true })

it("bundles every licensed Pen shader family, variant, source, and offline preview", () => {
  expect(PEN_SHADER_FAMILIES).toHaveLength(75)
  expect(PEN_SHADER_FAMILIES.every((family) => family.examples.length === 5)).toBe(true)

  const examples = PEN_SHADER_FAMILIES.flatMap((family) => family.examples)
  expect(examples).toHaveLength(375)
  expect(new Set(examples.map((example) => example.id)).size).toBe(375)
  expect(new Set(examples.map((example) => example.source)).size).toBe(102)
  expect(Object.keys(bundledSources)).toHaveLength(102)
  expect(SHADERS).toHaveLength(386)

  for (const example of examples) {
    expect(example.preview).toBeTruthy()
    expect(example.preview).toMatch(/^shaders\/pen\/images\/[^/]+\.webp$/)
    expect(getPenShaderVariant(example.id)).toBe(example)
  }
})
