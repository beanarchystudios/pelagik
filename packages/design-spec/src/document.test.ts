import { expect, it } from "vitest"
import { emptyDocument } from "@pelagik/design-core/document"
import { designCatalog, getDesignCatalog, parseDesignSpec } from "./catalog"
import { canonicalDesign, documentToSpec, insertDesignSpec, specToDocument } from "./document"

const spec = {
  rootIds: ["card"], variables: { brand: { name: "Brand", value: "#0088cc" } },
  nodes: {
    card: { type: "frame", props: { width: 320, height: 240, flex: { direction: "vertical", gap: 12, padding: 20, mainAlign: "start", crossAlign: "start" } }, childIds: ["title", "button"] },
    title: { type: "text", props: { text: "Hello json-render", width: 260, height: 24 }, childIds: [] },
    button: { type: "rectangle", props: { width: 140, height: 40, radius: 8 }, childIds: [], bindings: { fill: "brand" } },
  },
}
it("uses the real json-render catalog for prompts, vocabulary and structural validation", () => {
  expect(designCatalog.validate(spec).success).toBe(true)
  expect(designCatalog.validate({ rootIds: [], nodes: { bad: { type: "iframe", props: {}, childIds: [] } } }).success).toBe(false)
  expect(getDesignCatalog().components).toEqual(["frame", "group", "rectangle", "ellipse", "text", "image", "icon"])
  expect(getDesignCatalog().prompt).toContain("parent-local")
})
it("compiles a spec into editable nodes with variables, flex and independent IDs", () => {
  const result = insertDesignSpec(emptyDocument(), spec)
  const frame = result.doc.nodes[result.ids.card]
  const title = result.doc.nodes[result.ids.title]
  const button = result.doc.nodes[result.ids.button]
  expect(result.ids.card).not.toBe("card")
  expect(frame.childIds).toEqual([title.id, button.id])
  expect([title.x, title.y, button.y]).toEqual([20, 20, 56])
  expect(button.fill).toBe("#0088cc")
  expect(button.bindings.fill).toBe(result.variableIds.brand)
  expect(insertDesignSpec(result.doc, spec).doc.rootIds).toHaveLength(2)
})
it("round-trips normalized document geometry, hierarchy, variables and bindings", () => {
  const first = insertDesignSpec(emptyDocument(), spec)
  const exported = documentToSpec(first.doc)
  const second = insertDesignSpec(emptyDocument(), exported)
  const again = documentToSpec(second.doc)
  expect(again.nodes[second.ids[first.ids.title]].props).toEqual(exported.nodes[first.ids.title].props)
  expect(again.nodes[second.ids[first.ids.button]].bindings?.fill).toBe(second.variableIds[first.variableIds.brand])
  expect(Object.values(again.variables!)[0]).toEqual({ name: "Brand", value: "#0088cc" })
})
it("round-trips built-in and licensed Pen shader presets on supported shape layers", () => {
  for (const shader of ["paper-texture", "ascii-echo", "auro-bevel", "auro-flow", "aurora", "liquid-glass", "pen-liquid-glass-g5DdN"]) {
    const input = {
      rootIds: ["surface"],
      nodes: { surface: { type: "rectangle", props: { width: 80, height: 60, shader }, childIds: [] } },
    }
    const doc = specToDocument(input)
    expect(doc.nodes.surface.shader).toBe(shader)
    expect(documentToSpec(doc).nodes.surface.props).toHaveProperty("shader", shader)
  }
  expect(() => parseDesignSpec({
    rootIds: ["label"],
    nodes: { label: { type: "text", props: { shader: "water" }, childIds: [] } },
  })).toThrow()
  expect(() => parseDesignSpec({
    rootIds: ["shape"],
    nodes: { shape: { type: "rectangle", props: { shader: "custom-fragment-source" }, childIds: [] } },
  })).toThrow()
})
it("rejects cycles, unreachable nodes, duplicate parents, dynamic expressions and type-incompatible props", () => {
  for (const invalid of [
    { rootIds: ["a"], nodes: { a: { type: "frame", props: {}, childIds: ["a"] } } },
    { rootIds: [], nodes: { a: { type: "text", props: {}, childIds: [] } } },
    { rootIds: ["a", "a"], nodes: { a: { type: "text", props: {}, childIds: [] } } },
    { rootIds: ["a"], nodes: { a: { type: "rectangle", props: { text: "No" }, childIds: [] } } },
    { rootIds: ["a"], nodes: { a: { type: "text", props: { text: { $state: "/secret" } }, childIds: [] } } },
    { rootIds: ["a"], nodes: { a: { type: "text", props: {}, childIds: [], on: { press: { action: "evil" } } } } },
  ]) expect(() => insertDesignSpec(emptyDocument(), invalid)).toThrow()
  expect(() => parseDesignSpec({ rootIds: [], nodes: {}, actions: {} })).toThrow()
})
it("preserves locked nodes and group geometry without inventing group styles", () => {
  const result = insertDesignSpec(emptyDocument(), {
    rootIds: ["g"], nodes: {
      g: { type: "group", props: { locked: true }, childIds: ["r"] },
      r: { type: "rectangle", props: { x: 10, y: 20, width: 40, height: 30 }, childIds: [] },
    },
  })
  expect(result.doc.nodes[result.ids.g].locked).toBe(true)
  expect(documentToSpec(result.doc).nodes[result.ids.g].props).not.toHaveProperty("fill")
})

it("preserves canonical IDs, geometry and unchanged layer identities across edits", () => {
  const first = canonicalDesign(insertDesignSpec(emptyDocument(), spec).doc)
  expect(specToDocument(first.spec)).toEqual(first.doc)
  const id = first.doc.rootIds[0]
  const title = first.doc.nodes[id].childIds[0]
  const next = canonicalDesign({ ...first.doc, nodes: { ...first.doc.nodes, [title]: { ...first.doc.nodes[title], text: "Changed" } } })
  expect(next.doc.nodes[id]).toBe(first.doc.nodes[id])
  expect(next.doc.nodes[title]).not.toBe(first.doc.nodes[title])
  expect(next.spec.nodes[title].props).toHaveProperty("text", "Changed")
  expect(canonicalDesign(first.doc)).toBe(first)
})

const house = {
  name: "lucide:house", viewBox: "0 0 24 24",
  elements: [{ tag: "path", attrs: { d: "M3 10l9-7 9 7v9H3z", fill: "currentColor" } }],
}
const iconSpec = (icon: unknown, props: Record<string, unknown> = {}) => ({
  rootIds: ["house"], nodes: { house: { type: "icon", props: { width: 24, height: 24, fill: "#112233", icon, ...props }, childIds: [] } },
})
it("keeps icons as flat artwork colored by fill and round-trips them", () => {
  const result = insertDesignSpec(emptyDocument(), iconSpec(house))
  const node = result.doc.nodes[result.ids.house]
  expect(node.type).toBe("icon")
  expect(node.icon).toEqual(house)
  expect(node.fill).toBe("#112233")
  const props = documentToSpec(result.doc).nodes[result.ids.house].props
  expect(props).toHaveProperty("icon", house)
  expect(props).not.toHaveProperty("stroke")
  expect(props).not.toHaveProperty("radius")
  const again = insertDesignSpec(emptyDocument(), documentToSpec(result.doc))
  expect(again.doc.nodes[again.rootIds[0]].icon).toEqual(house)
})
it("rejects icon artwork that could carry markup, scripts, URLs, or unsupported styling", () => {
  for (const elements of [
    [{ tag: "script", attrs: {} }],
    [{ tag: "use", attrs: {} }],
    [{ tag: "path", attrs: { d: "M0 0", onload: "alert(1)" } }],
    [{ tag: "path", attrs: { d: "M0 0", href: "https://example.com/a.svg" } }],
    [{ tag: "path", attrs: { d: "M0 0", style: "fill:red" } }],
    [{ tag: "path", attrs: { d: "M0 0", fill: "url(https://example.com/a)" } }],
    [{ tag: "path", attrs: { d: "<img src=x>" } }],
    [{ tag: "path", attrs: { d: "M0 0", fill: "red;" } }],
  ]) {
    expect(() => insertDesignSpec(emptyDocument(), iconSpec({ ...house, elements }))).toThrow()
  }
  expect(() => insertDesignSpec(emptyDocument(), iconSpec({ ...house, viewBox: "0 0 0 24" }))).toThrow()
  expect(() => insertDesignSpec(emptyDocument(), iconSpec(house, { stroke: "#000000" }))).toThrow()
  expect(() => insertDesignSpec(emptyDocument(), iconSpec(house, { fill: null }))).toThrow()
  expect(() => parseDesignSpec({ rootIds: ["a"], nodes: { a: { type: "rectangle", props: { icon: house }, childIds: [] } } })).toThrow()
})
it("keeps icons leaf nodes that cannot bind strokes", () => {
  const colored = { fill: "#112233", icon: house }
  expect(() => insertDesignSpec(emptyDocument(), {
    rootIds: ["house"],
    nodes: { house: { type: "icon", props: colored, childIds: ["child"] }, child: { type: "rectangle", props: {}, childIds: [] } },
  })).toThrow()
  expect(() => insertDesignSpec(emptyDocument(), {
    rootIds: ["house"],
    nodes: { house: { type: "icon", props: colored, childIds: [], bindings: { fill: "brand" } } },
    variables: { brand: { name: "Brand", value: "#0088cc" } },
  })).not.toThrow()
  expect(() => insertDesignSpec(emptyDocument(), {
    rootIds: ["house"],
    nodes: { house: { type: "icon", props: colored, childIds: [], bindings: { stroke: "brand" } } },
    variables: { brand: { name: "Brand", value: "#0088cc" } },
  })).toThrow()
})
it("preserves text font families through saved specs and defaults older text nodes", () => {
  const doc = specToDocument(spec)
  expect(doc.nodes.title.fontFamily).toBe("DM Sans Variable")
  const changed = canonicalDesign({
    ...doc,
    nodes: { ...doc.nodes, title: { ...doc.nodes.title, fontFamily: "Georgia" } },
  })
  expect(specToDocument(changed.spec).nodes.title.fontFamily).toBe("Georgia")
  expect(changed.spec.nodes.card.props).not.toHaveProperty("fontFamily")
  expect(() => parseDesignSpec({
    rootIds: ["shape"],
    nodes: { shape: { type: "rectangle", props: { fontFamily: "Georgia" }, childIds: [] } },
  })).toThrow()
})


it("round-trips embedded images and rejects external image URLs", () => {
  const image = "data:image/png;base64,aGVsbG8="
  const spec = { rootIds: ["photo"], nodes: { photo: { type: "image", props: { image, width: 40, height: 30 }, childIds: [] } } }
  const result = insertDesignSpec(emptyDocument(), spec)
  const exported = documentToSpec(result.doc)
  expect(exported.nodes[result.rootIds[0]].props).toHaveProperty("image", image)
  expect(() => insertDesignSpec(emptyDocument(), { ...spec, nodes: { photo: { ...spec.nodes.photo, props: { ...spec.nodes.photo.props, image: "https://example.com/image.png" } } } })).toThrow()
})
