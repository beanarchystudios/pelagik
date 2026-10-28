import { describe, expect, it } from "vitest"
import { createNode, emptyDocument } from "./document"
import { addNodeAt, updateNodes } from "./operations"
import { addVariable, bindNodes, deleteVariable, renameVariable, setVariableValue } from "./variables"
import type { DesignVariable, Document } from "./types"

const brand: DesignVariable = { id: "brand", name: "Brand", type: "color", value: "#112233" }

function withRect(doc: Document, id: string, type: "rectangle" | "group" | "text" = "rectangle"): Document {
  const box = { x: 0, y: 0, width: 40, height: 40 }
  return addNodeAt(doc, createNode(doc, type, box, id), box, null)
}

function setup(): Document {
  let doc = addVariable(emptyDocument(), brand)
  doc = withRect(doc, "a")
  doc = withRect(doc, "b")
  return doc
}

describe("variable bindings", () => {
  it("copies the variable's value into a bound property", () => {
    const bound = bindNodes(setup(), ["a"], "fill", "brand")
    expect(bound.nodes.a.fill).toBe("#112233")
    expect(bound.nodes.a.bindings.fill).toBe("brand")
    expect(bound.nodes.b.bindings.fill).toBeUndefined()
  })

  it("propagates a changed variable value only to nodes bound to it", () => {
    let doc = bindNodes(setup(), ["a"], "fill", "brand")
    doc = setVariableValue(doc, "brand", "#ff0000")
    expect(doc.variables.brand).toMatchObject({ value: "#ff0000" })
    expect(doc.nodes.a.fill).toBe("#ff0000")
    expect(doc.nodes.b.fill).toBe("#d9d9d9")
  })

  it("rejects a variable id that does not exist", () => {
    const doc = setup()
    expect(bindNodes(doc, ["a"], "fill", "missing")).toBe(doc)
  })

  it("keeps the last value when a variable is deleted", () => {
    let doc = bindNodes(setup(), ["a"], "fill", "brand")
    doc = setVariableValue(doc, "brand", "#ff0000")
    doc = deleteVariable(doc, "brand")
    expect(doc.variables.brand).toBeUndefined()
    expect(doc.nodes.a.fill).toBe("#ff0000")
    expect(doc.nodes.a.bindings.fill).toBeUndefined()
  })

  it("detaches a property when it is typed over directly", () => {
    const bound = bindNodes(setup(), ["a"], "fill", "brand")
    const edited = updateNodes(bound, ["a"], { fill: "#00ff00" })
    expect(edited.nodes.a.fill).toBe("#00ff00")
    expect(edited.nodes.a.bindings.fill).toBeUndefined()
  })

  it("detaches without changing the current value", () => {
    const bound = bindNodes(setup(), ["a"], "fill", "brand")
    const detached = bindNodes(bound, ["a"], "fill", null)
    expect(detached.nodes.a.fill).toBe("#112233")
    expect(detached.nodes.a.bindings.fill).toBeUndefined()
  })

  it("skips groups, which have no fill to bind", () => {
    let doc = setup()
    doc = withRect(doc, "g", "group")
    const bound = bindNodes(doc, ["g"], "fill", "brand")
    expect(bound.nodes.g.bindings.fill).toBeUndefined()
  })

  it("renames a variable without touching its value", () => {
    const renamed = renameVariable(setup(), "brand", "Primary")
    expect(renamed.variables.brand).toMatchObject({ name: "Primary", value: "#112233" })
  })
})
