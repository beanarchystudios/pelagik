import { describe, expect, it } from "vitest"
import { apply, invert, multiply, rotate } from "./matrix"
import {
  boundsOfIds,
  createNode,
  emptyDocument,
  nodeBounds,
  worldCenter,
  worldMatrix,
  worldRotation,
} from "./document"
import {
  addNodeAt,
  alignNodes,
  copyNodes,
  deleteNodes,
  duplicateNodes,
  groupNodes,
  insertFragment,
  moveNodes,
  reorderNodes,
  reparentForDrop,
  reparentNodes,
  resizeNodes,
  rotateNodes,
  ungroupNodes,
  updateNodes,
} from "./operations"
import { frameAt, hitTest, nodesInRect, selectionTarget } from "./hit-test"
import type { Document, Rect } from "./types"

function near(actual: number, expected: number, message?: string) {
  expect(Math.abs(actual - expected), message).toBeLessThan(1e-4)
}

/** Compares angles modulo 360, so -180 and 180 are equal. */
function nearAngle(actual: number, expected: number) {
  const diff = (((actual - expected) % 360) + 540) % 360 - 180
  expect(Math.abs(diff)).toBeLessThan(1e-4)
}

function add(doc: Document, type: "rectangle" | "frame" | "group" | "ellipse", id: string, box: Rect, parentId: string | null = null): Document {
  return addNodeAt(doc, createNode(doc, type, box, id), box, parentId)
}

describe("matrix", () => {
  it("inverts a rotation plus translation", () => {
    const m = multiply(rotate(37), rotate(12))
    const p = { x: 3, y: -8 }
    const back = apply(invert(m), apply(m, p))
    near(back.x, p.x)
    near(back.y, p.y)
  })
})

describe("placement", () => {
  it("keeps a child on the same page spot when its parent is rotated", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 100, y: 100, width: 200, height: 100 })
    doc = { ...doc, nodes: { ...doc.nodes, f: { ...doc.nodes.f, rotation: 30 } } }
    doc = add(doc, "rectangle", "r", { x: 10, y: 10, width: 20, height: 20 }, "f")

    const before = worldCenter(doc, "r")
    const moved = moveNodes(doc, ["r"], 0, 0)
    const after = worldCenter(moved, "r")
    near(after.x, before.x)
    near(after.y, before.y)
    // New children are placed upright on the page, so their local rotation compensates for the parent.
    near(worldRotation(doc, "r"), 0)
    expect(doc.nodes.r.rotation).toBeCloseTo(-30)
  })

  it("reports a rotated node's bounds", () => {
    let doc = add(emptyDocument(), "rectangle", "r", { x: 0, y: 0, width: 100, height: 10 })
    doc = rotateNodes(doc, ["r"], { x: 50, y: 5 }, 90)
    const b = nodeBounds(doc, "r")
    near(b.minX, 45)
    near(b.maxX, 55)
    near(b.minY, -45)
    near(b.maxY, 55)
  })
})

describe("move", () => {
  it("translates a top-level node by a page delta", () => {
    const doc = add(emptyDocument(), "rectangle", "r", { x: 10, y: 20, width: 30, height: 40 })
    const moved = moveNodes(doc, ["r"], 5, -7)
    expect(moved.nodes.r.x).toBeCloseTo(15)
    expect(moved.nodes.r.y).toBeCloseTo(13)
  })

  it("moves a group's children with it and leaves them relative to the group", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 40, y: 40, width: 10, height: 10 })
    const grouped = groupNodes(doc, ["a", "b"])
    expect(grouped).not.toBeNull()
    const groupId = grouped!.groupId
    const moved = moveNodes(grouped!.doc, [groupId], 100, 0)
    near(nodeBounds(moved, "a").minX, 100)
    near(nodeBounds(moved, "b").maxX, 150)
  })
})

describe("resize", () => {
  it("keeps the opposite corner fixed when dragging the south-east handle", () => {
    const doc = add(emptyDocument(), "rectangle", "r", { x: 0, y: 0, width: 100, height: 100 })
    const resized = resizeNodes(doc, ["r"], "se", { x: 150, y: 120 }, false)
    expect(resized.nodes.r.x).toBeCloseTo(0)
    expect(resized.nodes.r.width).toBeCloseTo(150)
    expect(resized.nodes.r.height).toBeCloseTo(120)
  })

  it("moves the origin when dragging the north-west handle", () => {
    const doc = add(emptyDocument(), "rectangle", "r", { x: 0, y: 0, width: 100, height: 100 })
    const resized = resizeNodes(doc, ["r"], "nw", { x: -10, y: -20 }, false)
    near(resized.nodes.r.x, -10)
    near(resized.nodes.r.y, -20)
    near(resized.nodes.r.width, 110)
    near(resized.nodes.r.height, 120)
  })

  it("keeps the opposite edge in page space on a rotated node", () => {
    const base = add(emptyDocument(), "rectangle", "r", { x: 20, y: 30, width: 80, height: 40 })
    const doc = rotateNodes(base, ["r"], { x: 0, y: 0 }, 35)

    // Dragging the east handle must not move the west edge's midpoint.
    const resized = resizeNodes(doc, ["r"], "e", { x: 180, y: 90 }, false)
    expect(resized.nodes.r.width).toBeGreaterThan(0)
    const westBefore = apply(worldMatrix(doc, "r"), { x: 0, y: 20 })
    const westAfter = apply(worldMatrix(resized, "r"), { x: 0, y: 20 })
    // Positions are stored as whole pixels, so the anchor can move by up to half a pixel per axis.
    expect(Math.abs(westAfter.x - westBefore.x)).toBeLessThanOrEqual(0.5)
    expect(Math.abs(westAfter.y - westBefore.y)).toBeLessThanOrEqual(0.5)
  })

  it("scales children when a group is resized", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 50, height: 50 })
    doc = add(doc, "rectangle", "b", { x: 50, y: 50, width: 50, height: 50 })
    const grouped = groupNodes(doc, ["a", "b"])!
    const resized = resizeNodes(grouped.doc, [grouped.groupId], "se", { x: 200, y: 100 }, false)
    const bounds = boundsOfIds(resized, [grouped.groupId])!
    near(bounds.maxX - bounds.minX, 200)
    near(bounds.maxY - bounds.minY, 100)
    near(nodeBounds(resized, "b").minX, 100)
    near(nodeBounds(resized, "b").minY, 50)
  })

  it("scales a multi-selection about the opposite edge of its bounds", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 90, y: 90, width: 10, height: 10 })
    const resized = resizeNodes(doc, ["a", "b"], "se", { x: 200, y: 100 }, false)
    const bounds = boundsOfIds(resized, ["a", "b"])!
    near(bounds.minX, 0)
    near(bounds.maxX, 200)
    near(bounds.maxY, 100)
  })
})

describe("rotate", () => {
  it("rotates a multi-selection around the pivot", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 90, y: 0, width: 10, height: 10 })
    const rotated = rotateNodes(doc, ["a", "b"], { x: 50, y: 5 }, 180)
    near(worldCenter(rotated, "a").x, 95)
    near(worldCenter(rotated, "a").y, 5)
    nearAngle(worldRotation(rotated, "a"), 180)
  })
})

describe("groups", () => {
  it("wraps children in a box that matches their union", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 10, y: 10, width: 20, height: 20 })
    doc = add(doc, "rectangle", "b", { x: 60, y: 40, width: 10, height: 30 })
    const grouped = groupNodes(doc, ["a", "b"])!
    const group = grouped.doc.nodes[grouped.groupId]
    expect(group.x).toBeCloseTo(10)
    expect(group.y).toBeCloseTo(10)
    expect(group.width).toBeCloseTo(60)
    expect(group.height).toBeCloseTo(60)
    expect(grouped.doc.rootIds).toEqual([grouped.groupId])
  })

  it("restores page positions when ungrouped", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 10, y: 10, width: 20, height: 20 })
    doc = add(doc, "rectangle", "b", { x: 60, y: 40, width: 10, height: 30 })
    const grouped = groupNodes(doc, ["a", "b"])!
    const ungrouped = ungroupNodes(grouped.doc, [grouped.groupId])
    expect(ungrouped.doc.rootIds.sort()).toEqual(["a", "b"].sort())
    near(nodeBounds(ungrouped.doc, "a").minX, 10)
    near(nodeBounds(ungrouped.doc, "b").minY, 40)
  })

  it("maps a click on a child to the outermost group", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 20, y: 0, width: 10, height: 10 })
    const grouped = groupNodes(doc, ["a", "b"])!
    expect(selectionTarget(grouped.doc, "a")).toBe(grouped.groupId)
  })

  it("refits a group after one child moves inside it", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 20, y: 0, width: 10, height: 10 })
    const grouped = groupNodes(doc, ["a", "b"])!
    const updated = updateNodes(grouped.doc, ["b"], { x: 50 })
    near(updated.nodes[grouped.groupId].width, 60)
    near(nodeBounds(updated, "a").minX, 0)
  })
})

describe("reparenting", () => {
  it("keeps the page position when a node moves into a frame", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 50, y: 50, width: 300, height: 300 })
    doc = add(doc, "rectangle", "r", { x: 200, y: 200, width: 20, height: 20 })
    const moved = reparentNodes(doc, ["r"], "f", null)
    expect(moved.nodes.r.parentId).toBe("f")
    near(moved.nodes.r.x, 150)
    near(moved.nodes.r.y, 150)
    near(worldCenter(moved, "r").x, 210)
    expect(moved.rootIds).toEqual(["f"])
  })
})

describe("drop to reparent", () => {
  it("moves a node into the frame under the pointer, keeping its page position", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "r", { x: 200, y: 200, width: 10, height: 10 })
    const dropped = reparentForDrop(doc, ["r"], { x: 50, y: 50 })
    expect(dropped.nodes.r.parentId).toBe("f")
    near(worldCenter(dropped, "r").x, 205)
    expect(dropped.rootIds).toEqual(["f"])
  })

  it("moves a node out of a frame when dropped outside every frame", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "r", { x: 10, y: 10, width: 10, height: 10 }, "f")
    const dropped = reparentForDrop(doc, ["r"], { x: 500, y: 500 })
    expect(dropped.nodes.r.parentId).toBeNull()
    near(nodeBounds(dropped, "r").minX, 10)
  })

  it("never moves a frame into itself", () => {
    const doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    expect(reparentForDrop(doc, ["f"], { x: 50, y: 50 })).toBe(doc)
  })
})

describe("clipboard and duplication", () => {
  it("duplicates a node directly above the original with a new id", () => {
    const doc = add(emptyDocument(), "rectangle", "r", { x: 0, y: 0, width: 10, height: 10 })
    const result = duplicateNodes(doc, ["r"], { x: 10, y: 10 })
    expect(result.ids).toHaveLength(1)
    expect(result.ids[0]).not.toBe("r")
    expect(result.doc.rootIds[1]).toBe(result.ids[0])
    near(nodeBounds(result.doc, result.ids[0]).minX, 10)
  })

  it("pastes a copied subtree into a new parent with fresh ids", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "r", { x: 10, y: 10, width: 20, height: 20 }, "f")
    const fragment = copyNodes(doc, ["r"])
    const pasted = insertFragment(doc, fragment, null, null, { x: 0, y: 0 })
    expect(pasted.ids).toHaveLength(1)
    expect(pasted.ids[0]).not.toBe("r")
    near(nodeBounds(pasted.doc, pasted.ids[0]).minX, 10)
  })
})

describe("deletion", () => {
  it("removes a subtree and dissolves a group that becomes empty", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 20, y: 0, width: 10, height: 10 })
    const grouped = groupNodes(doc, ["a", "b"])!
    const after = deleteNodes(grouped.doc, ["a", "b"])
    expect(after.rootIds).toEqual([])
    expect(Object.keys(after.nodes)).toEqual([])
  })

  it("deletes a frame and its children together", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "r", { x: 10, y: 10, width: 20, height: 20 }, "f")
    const after = deleteNodes(doc, ["f"])
    expect(after.rootIds).toEqual([])
    expect(after.nodes.r).toBeUndefined()
  })
})

describe("stacking and alignment", () => {
  it("brings a node to the front", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "c", { x: 0, y: 0, width: 10, height: 10 })
    expect(reorderNodes(doc, ["a"], "front").rootIds).toEqual(["b", "c", "a"])
    expect(reorderNodes(doc, ["c"], "back").rootIds).toEqual(["c", "a", "b"])
  })

  it("aligns several nodes to the left edge of their combined bounds", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 10, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 50, y: 0, width: 20, height: 10 })
    const aligned = alignNodes(doc, ["a", "b"], "left")
    near(nodeBounds(aligned, "a").minX, 10)
    near(nodeBounds(aligned, "b").minX, 10)
  })
})

describe("hit testing", () => {
  it("finds the topmost node under the pointer", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "b", { x: 0, y: 0, width: 50, height: 50 })
    expect(hitTest(doc, { x: 10, y: 10 })).toBe("b")
    expect(hitTest(doc, { x: 80, y: 80 })).toBe("a")
    expect(hitTest(doc, { x: 200, y: 200 })).toBeNull()
  })

  it("clips children to the frame", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "r", { x: 80, y: 80, width: 50, height: 50 }, "f")
    expect(hitTest(doc, { x: 120, y: 120 })).toBeNull()
    expect(hitTest(doc, { x: 90, y: 90 })).toBe("r")
    expect(hitTest(doc, { x: 10, y: 10 })).toBe("f")
  })

  it("respects rotation when hit testing", () => {
    let doc = add(emptyDocument(), "rectangle", "r", { x: 0, y: 0, width: 100, height: 10 })
    doc = rotateNodes(doc, ["r"], { x: 50, y: 5 }, 90)
    expect(hitTest(doc, { x: 50, y: -30 })).toBe("r")
    expect(hitTest(doc, { x: 90, y: 5 })).toBeNull()
  })

  it("ignores locked and hidden nodes", () => {
    let doc = add(emptyDocument(), "rectangle", "r", { x: 0, y: 0, width: 100, height: 100 })
    doc = updateNodes(doc, ["r"], { locked: true })
    expect(hitTest(doc, { x: 10, y: 10 })).toBeNull()
    doc = updateNodes(doc, ["r"], { locked: false, hidden: true })
    expect(hitTest(doc, { x: 10, y: 10 })).toBeNull()
  })

  it("finds the deepest frame under the pointer for new shapes", () => {
    let doc = add(emptyDocument(), "frame", "outer", { x: 0, y: 0, width: 300, height: 300 })
    doc = add(doc, "frame", "inner", { x: 10, y: 10, width: 100, height: 100 }, "outer")
    expect(frameAt(doc, { x: 20, y: 20 })).toBe("inner")
    expect(frameAt(doc, { x: 200, y: 200 })).toBe("outer")
    expect(frameAt(doc, { x: 400, y: 400 })).toBeNull()
  })

  it("finds nodes intersecting a marquee", () => {
    let doc = add(emptyDocument(), "rectangle", "a", { x: 0, y: 0, width: 10, height: 10 })
    doc = add(doc, "rectangle", "b", { x: 100, y: 100, width: 10, height: 10 })
    expect(nodesInRect(doc, { minX: -5, minY: -5, maxX: 20, maxY: 20 })).toEqual(["a"])
  })
})

describe("deletion keeps the document valid", () => {
  it("never leaves a dangling id in a parent's child list", () => {
    let doc = add(emptyDocument(), "frame", "f", { x: 0, y: 0, width: 100, height: 100 })
    doc = add(doc, "rectangle", "r", { x: 10, y: 10, width: 20, height: 20 }, "f")
    doc = add(doc, "rectangle", "s", { x: 40, y: 10, width: 20, height: 20 }, "f")
    doc = deleteNodes(doc, ["r"])
    expect(doc.nodes.f.childIds).toEqual(["s"])
    expect(doc.nodes.r).toBeUndefined()
  })
})
