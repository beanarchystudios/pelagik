import { describe, expect, it } from "vitest"
import { emptyDocument } from "@pelagik/design-core/document"
import { applyOperations, validateDocument } from "./edits"
import { operation } from "./schema"

const ops = (inputs: unknown[]) => inputs.map(input => operation.parse(input))
function scene() {
  return applyOperations(emptyDocument(), ops([
    { op: "create", type: "frame", ref: "frame", props: { x: 100, width: 400, height: 400, flex: { direction: "vertical", gap: 10, padding: 20, mainAlign: "start", crossAlign: "start" } } },
    { op: "create", type: "text", ref: "heading", parentId: "$frame", props: { text: "Hello", width: 200, height: 24 } },
    { op: "create", type: "rectangle", ref: "button", parentId: "$frame", props: { width: 120, height: 40 } },
  ]))
}
describe("agent transactions", () => {
  it("resolves references, uses local coordinates, and reflows flex", () => {
    const result = scene()
    const frame = result.doc.nodes[result.refs.frame]
    const heading = result.doc.nodes[result.refs.heading]
    const button = result.doc.nodes[result.refs.button]
    expect(frame.x).toBe(100)
    expect(heading.parentId).toBe(frame.id)
    expect([heading.x, heading.y, button.y]).toEqual([20, 20, 54])
    expect(result.createdIds).toHaveLength(3)
    validateDocument(result.doc)
  })
  it("does not mutate the original when a later operation fails", () => {
    const { doc, refs } = scene()
    const original = JSON.stringify(doc)
    expect(() => applyOperations(doc, ops([
      { op: "update", ids: [refs.heading], props: { text: "Changed" } },
      { op: "reparent", ids: [refs.frame], parentId: refs.heading },
    ]))).toThrow()
    expect(JSON.stringify(doc)).toBe(original)
  })
  it("rejects cycles and unknown references", () => {
    const { doc, refs } = scene()
    expect(() => applyOperations(doc, ops([{ op: "reparent", ids: [refs.frame], parentId: refs.frame }]))).toThrow(/cycle/)
    expect(() => applyOperations(doc, ops([{ op: "update", ids: ["$missing"], props: { name: "x" } }]))).toThrow(/Unknown batch/)
  })
  it("requires explicit unlocks, including for descendants and bound variables", () => {
    const { doc, refs } = scene()
    const locked = applyOperations(doc, ops([{ op: "lock", ids: [refs.heading], locked: true }])).doc
    expect(() => applyOperations(locked, ops([{ op: "delete", ids: [refs.frame] }]))).toThrow(/locked/)
    const updated = applyOperations(locked, ops([
      { op: "lock", ids: [refs.heading], locked: false },
      { op: "update", ids: [refs.heading], props: { text: "Unlocked" } },
    ]))
    expect(updated.doc.nodes[refs.heading].text).toBe("Unlocked")
  })
  it("propagates variables and preserves the last value on deletion", () => {
    const { doc, refs } = scene()
    const result = applyOperations(doc, ops([
      { op: "create_variable", ref: "brand", name: "Brand", value: "#00aaff" },
      { op: "bind_variable", ids: [refs.button], property: "fill", variableId: "$brand" },
      { op: "update_variable", id: "$brand", name: "Accent", value: "#0033ff" },
      { op: "delete_variable", id: "$brand" },
    ]))
    expect(result.doc.nodes[refs.button].fill).toBe("#0033ff")
    expect(result.doc.nodes[refs.button].bindings).toEqual({})
    expect(result.doc.variables).toEqual({})
  })
  it("applies only catalogued shaders to supported shape layers", () => {
    const { doc, refs } = scene()
    const updated = applyOperations(doc, ops([
      { op: "update", ids: [refs.button], props: { shader: "pen-liquid-glass-g5DdN" } },
    ]))
    expect(updated.doc.nodes[refs.button].shader).toBe("pen-liquid-glass-g5DdN")
    validateDocument(updated.doc)
    expect(() => applyOperations(doc, ops([
      { op: "update", ids: [refs.heading], props: { shader: "water" } },
    ]))).toThrow(/Shaders require/)
    expect(() => operation.parse({ op: "update", ids: [refs.button], props: { shader: "void main()" } })).toThrow()
  })
  it("supports grouping, duplication, reparenting, ordering, and ungrouping", () => {
    const created = applyOperations(emptyDocument(), ops([
      { op: "create", type: "rectangle", ref: "a", props: { x: 10, width: 40, height: 40 } },
      { op: "create", type: "ellipse", ref: "b", props: { x: 70, width: 40, height: 40 } },
      { op: "group", ids: ["$a", "$b"], ref: "g" },
      { op: "duplicate", ids: ["$g"] },
      { op: "reorder", ids: ["$g"], order: "front" },
      { op: "ungroup", ids: ["$g"] },
      { op: "create", type: "frame", ref: "f", props: { width: 400, height: 400 } },
      { op: "reparent", ids: ["$a"], parentId: "$f", index: 0 },
    ]))
    validateDocument(created.doc)
    expect(created.doc.nodes[created.refs.a].parentId).toBe(created.refs.f)
    expect(Object.values(created.doc.nodes).filter(n => n.type === "group")).toHaveLength(1)
  })
  it("rejects structural patches, irrelevant properties, duplicate refs and prototype keys", () => {
    expect(() => operation.parse({ op: "update", ids: ["a"], props: { id: "b" } })).toThrow()
    expect(() => operation.parse({ op: "update", ids: ["a"], props: { fill: "url(https://evil.test)" } })).toThrow()
    const { doc, refs } = scene()
    expect(() => applyOperations(doc, ops([{ op: "update", ids: [refs.button], props: { text: "Invalid" } }]))).toThrow(/Text properties/)
    expect(() => applyOperations(doc, ops([{ op: "delete", ids: ["__proto__"] }]))).toThrow(/Unknown node/)
    expect(() => applyOperations(doc, ops([
      { op: "create", type: "frame", ref: "a", props: {} },
      { op: "create", type: "frame", ref: "a", props: {} },
    ]))).toThrow(/Duplicate reference/)
  })
  it("inserts icons only through specs and keeps their artwork and color", () => {
    expect(() => operation.parse({ op: "create", type: "icon", props: {} })).toThrow()
    const icon = { name: "tabler:home", viewBox: "0 0 24 24", elements: [{ tag: "path", attrs: { d: "M3 12l9-9l9 9" } }] }
    const result = applyOperations(emptyDocument(), ops([
      { op: "insert_spec", ref: "home", spec: { rootIds: ["home"], nodes: { home: { type: "icon", props: { width: 24, height: 24, fill: "#112233", icon }, childIds: [] } } } },
    ]))
    const node = result.doc.nodes[result.refs.home]
    expect(node.type).toBe("icon")
    expect(node.icon).toEqual(icon)
    validateDocument(result.doc)
    expect(() => applyOperations(result.doc, ops([{ op: "update", ids: [result.refs.home], props: { fill: null } }]))).toThrow(/fill color/)
  })
})
