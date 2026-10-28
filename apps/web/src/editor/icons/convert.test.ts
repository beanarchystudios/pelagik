import { describe, expect, it } from "vitest"
import { iconGlyph } from "@pelagik/design-spec/properties"
import { convertIconifyArtwork, IconImportError, type IconifyArtwork } from "./convert"
import lucide from "./fixtures/lucide.json"
import tabler from "./fixtures/tabler.json"
import phosphor from "./fixtures/ph.json"
import hugeicons from "./fixtures/hugeicons.json"
import remix from "./fixtures/ri.json"

function artwork(body: string, overrides: Partial<IconifyArtwork> = {}): IconifyArtwork {
  return { body, left: 0, top: 0, width: 24, height: 24, rotate: 0, hFlip: false, vFlip: false, ...overrides }
}

describe("converting Iconify artwork", () => {
  it("flattens group presentation attributes onto each shape, as Lucide and Tabler use them", () => {
    const glyph = convertIconifyArtwork("lucide:house", artwork(lucide.icons.house.body))
    expect(glyph.viewBox).toBe("0 0 24 24")
    expect(glyph.elements.length).toBeGreaterThan(1)
    for (const element of glyph.elements) {
      expect(element.attrs).toMatchObject({ fill: "none", stroke: "currentColor", "stroke-width": "2", "stroke-linecap": "round" })
    }
    expect(iconGlyph.safeParse(glyph).success).toBe(true)
  })

  it("lets a shape's own attributes override its group's, and keeps Tabler's stroke styling", () => {
    const override = convertIconifyArtwork("test:override", artwork('<g fill="none" stroke="currentColor"><path d="M0 0" fill="#f00"/><path d="M1 1"/></g>'))
    expect(override.elements[0].attrs).toMatchObject({ fill: "#f00", stroke: "currentColor" })
    expect(override.elements[1].attrs).toMatchObject({ fill: "none", stroke: "currentColor" })
    const glyph = convertIconifyArtwork("tabler:home", artwork(tabler.icons.home.body))
    expect(glyph.elements.every((element) => element.attrs.stroke === "currentColor")).toBe(true)
    expect(iconGlyph.safeParse(glyph).success).toBe(true)
  })

  it("converts fill-based and fill-plus-stroke icons from every library the picker offers", () => {
    const sets = [
      { prefix: "ph", data: phosphor, name: "house" },
      { prefix: "hugeicons", data: hugeicons, name: "home-01" },
      { prefix: "ri", data: remix, name: "home-line" },
    ]
    for (const { prefix, data, name } of sets) {
      const icon = data.icons[name as keyof typeof data.icons] as { body: string }
      const glyph = convertIconifyArtwork(`${prefix}:${name}`, artwork(icon.body))
      expect(glyph.elements.length).toBeGreaterThan(0)
      expect(iconGlyph.safeParse(glyph).success).toBe(true)
    }
  })

  it("composes nested group transforms and multiplies group opacity", () => {
    const glyph = convertIconifyArtwork("test:nested", artwork(
      '<g transform="translate(2 2)" opacity="0.5"><g transform="scale(2)"><path d="M0 0h1" transform="rotate(90)" opacity="0.5"/></g></g>',
    ))
    expect(glyph.elements[0].attrs.transform).toBe("translate(2 2) scale(2) rotate(90)")
    expect(glyph.elements[0].attrs.opacity).toBe("0.25")
  })

  it("drops comments and attributes that are not allowed, such as class, id, and style", () => {
    const glyph = convertIconifyArtwork("test:clean", artwork('<!-- note --><path d="M0 0" class="x" id="y" style="fill:red"/>'))
    expect(glyph.elements).toEqual([{ tag: "path", attrs: { d: "M0 0" } }])
  })

  it("applies rotation and flips around the viewBox center, including offset viewBoxes", () => {
    const glyph = convertIconifyArtwork("test:turned", artwork('<path d="M0 0h1"/>', { left: -1, top: -1, width: 26, height: 26, rotate: 1, hFlip: true }))
    expect(glyph.viewBox).toBe("-1 -1 26 26")
    expect(glyph.elements[0].attrs.transform).toBe("rotate(90 12 12) translate(12 0) scale(-1 1) translate(-12 0)")
  })

  it("rejects SVG features it cannot represent instead of dropping them silently", () => {
    for (const body of [
      '<use href="#shape"/>',
      '<defs><path d="M0 0"/></defs><path d="M0 0"/>',
      '<mask id="m"><path d="M0 0"/></mask><path d="M0 0"/>',
      '<path d="M0 0" fill="url(#gradient)" /><linearGradient id="gradient"/>',
      '<g><g><path d="M0 0"/></g></g><path d="M0 0" fill="url(https://example.com/a)"/>',
    ]) {
      expect(() => convertIconifyArtwork("test:unsupported", artwork(body))).toThrow(IconImportError)
    }
  })

  it("rejects empty artwork and unbalanced groups", () => {
    expect(() => convertIconifyArtwork("test:empty", artwork("<g></g>"))).toThrow(IconImportError)
    expect(() => convertIconifyArtwork("test:open", artwork('<g fill="none"><path d="M0 0"/>'))).toThrow(IconImportError)
  })
})
