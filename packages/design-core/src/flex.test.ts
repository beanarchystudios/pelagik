import { describe, expect, it } from "vitest"
import { DEFAULT_FLEX } from "./flex"
import { createNode, emptyDocument } from "./document"
import { addNodeAt, deleteNodes, moveNodes, reorderNodes, resizeNodes, updateNodes } from "./operations"
import type { FlexLayout, Document, Rect } from "./types"

function add(doc: Document, type: "rectangle" | "frame", id: string, box: Rect, parentId: string | null = null): Document {
  return addNodeAt(doc, createNode(doc, type, box, id), box, parentId)
}

/** A 100x200 frame holding three children: 30x20, 30x40, and 30x20, added in that order. */
function column(): Document {
  let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 200 })
  doc = add(doc, "rectangle", "a", { x: 60, y: 90, width: 30, height: 20 }, "f")
  doc = add(doc, "rectangle", "b", { x: 0, y: 0, width: 30, height: 40 }, "f")
  doc = add(doc, "rectangle", "c", { x: 5, y: 150, width: 30, height: 20 }, "f")
  return doc
}

function withLayout(doc: Document, layout: Partial<FlexLayout>): Document {
  return updateNodes(doc, ["f"], { flex: { ...DEFAULT_FLEX, ...layout } })
}

function at(doc: Document, id: string): { x: number; y: number } {
  return { x: doc.nodes[id].x, y: doc.nodes[id].y }
}

describe("flex", () => {
  it("stacks children in a column with gap and padding", () => {
    const doc = withLayout(column(), { direction: "vertical", gap: 10, padding: 5 })
    expect(at(doc, "a")).toEqual({ x: 5, y: 5 })
    expect(at(doc, "b")).toEqual({ x: 5, y: 35 })
    expect(at(doc, "c")).toEqual({ x: 5, y: 85 })
  })

  it("lays children out in a row", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 200, height: 100 })
    doc = add(doc, "rectangle", "a", { x: 90, y: 90, width: 30, height: 20 }, "f")
    doc = add(doc, "rectangle", "b", { x: 90, y: 90, width: 40, height: 20 }, "f")
    doc = withLayout(doc, { direction: "horizontal", gap: 10, padding: 0 })
    expect(at(doc, "a")).toEqual({ x: 0, y: 0 })
    expect(at(doc, "b")).toEqual({ x: 40, y: 0 })
  })

  it("centers the stack along the direction", () => {
    const doc = withLayout(column(), { gap: 10, padding: 0, mainAlign: "center" })
    // The stack is 100px tall in a 200px frame, so it starts 50px down.
    expect(at(doc, "a").y).toBe(50)
    expect(at(doc, "c").y).toBe(130)
  })

  it("pushes the stack to the end along the direction", () => {
    const doc = withLayout(column(), { gap: 10, padding: 5, mainAlign: "end" })
    expect(at(doc, "a").y).toBe(95)
    // The last child's bottom edge sits one padding in from the frame edge.
    expect(at(doc, "c").y + 20).toBe(195)
  })

  it("spreads children evenly with space-between", () => {
    const doc = withLayout(column(), { gap: 10, padding: 0, mainAlign: "space-between" })
    expect(at(doc, "a").y).toBe(0)
    expect(at(doc, "b").y).toBe(80)
    expect(at(doc, "c").y).toBe(180)
  })

  it("never overlaps children with space-between when they overflow", () => {
    let doc = withLayout(column(), { gap: 0, padding: 0, mainAlign: "space-between" })
    doc = updateNodes(doc, ["f"], { height: 50 })
    expect(at(doc, "a").y).toBe(0)
    expect(at(doc, "b").y).toBe(20)
    expect(at(doc, "c").y).toBe(60)
  })

  it("aligns children across the stack", () => {
    const doc = withLayout(column(), { gap: 10, padding: 5, crossAlign: "center" })
    // Inner width is 90px, so a 30px child starts 30px in from the padding.
    expect(at(doc, "a").x).toBe(35)
    expect(at(doc, "b").x).toBe(35)
  })

  it("aligns to the end of a row's cross axis", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 200, height: 200 })
    doc = add(doc, "rectangle", "a", { x: 0, y: 0, width: 30, height: 20 }, "f")
    doc = add(doc, "rectangle", "b", { x: 0, y: 0, width: 30, height: 40 }, "f")
    doc = withLayout(doc, { direction: "horizontal", gap: 0, padding: 5, crossAlign: "end" })
    expect(at(doc, "a").y).toBe(175)
    expect(at(doc, "b").y).toBe(155)
  })

  it("re-lays out children when the frame is resized", () => {
    let doc = withLayout(column(), { gap: 0, padding: 0, mainAlign: "end" })
    expect(at(doc, "a").y).toBe(120)
    doc = updateNodes(doc, ["f"], { height: 300 })
    expect(at(doc, "a").y).toBe(220)
  })

  it("re-lays out children when the frame is resized with a handle", () => {
    let doc = withLayout(column(), { gap: 0, padding: 0, mainAlign: "end" })
    doc = resizeNodes(doc, ["f"], "s", { x: 50, y: 300 }, false)
    expect(doc.nodes.f.height).toBe(300)
    expect(at(doc, "a").y).toBe(220)
  })

  it("snaps a dragged child back into its slot", () => {
    const doc = withLayout(column(), { gap: 10, padding: 5 })
    const moved = moveNodes(doc, ["a"], 40, 60)
    expect(at(moved, "a")).toEqual({ x: 5, y: 5 })
  })

  it("reflows siblings when a child changes size", () => {
    let doc = withLayout(column(), { gap: 10, padding: 0 })
    doc = updateNodes(doc, ["a"], { height: 60 })
    expect(at(doc, "b").y).toBe(70)
  })

  it("reflows siblings when a child is deleted", () => {
    let doc = withLayout(column(), { gap: 10, padding: 5 })
    doc = deleteNodes(doc, ["a"])
    expect(at(doc, "b").y).toBe(5)
    expect(at(doc, "c").y).toBe(55)
  })

  it("reflows children when their order changes", () => {
    let doc = withLayout(column(), { gap: 10, padding: 5 })
    doc = reorderNodes(doc, ["a"], "front")
    expect(doc.nodes.f.childIds).toEqual(["b", "c", "a"])
    expect(at(doc, "b").y).toBe(5)
    expect(at(doc, "c").y).toBe(55)
    expect(at(doc, "a").y).toBe(85)
  })

  it("leaves children where they were when flex is removed", () => {
    const laidOut = withLayout(column(), { gap: 10, padding: 5 })
    const doc = updateNodes(laidOut, ["f"], { flex: null })
    expect(at(doc, "b")).toEqual(at(laidOut, "b"))
  })
})
