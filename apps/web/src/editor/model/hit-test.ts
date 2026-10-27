import { apply, IDENTITY, invert, multiply, type Matrix } from "./matrix"
import { localMatrix, nodeBounds } from "./document"
import type { Bounds, Document, Point, SceneNode } from "./types"

function containsLocal(node: SceneNode, local: Point): boolean {
  const { width: w, height: h } = node
  if (local.x < 0 || local.y < 0 || local.x > w || local.y > h) return false
  if (node.type !== "ellipse") return true
  const rx = w / 2
  const ry = h / 2
  if (rx <= 0 || ry <= 0) return false
  const dx = (local.x - rx) / rx
  const dy = (local.y - ry) / ry
  return dx * dx + dy * dy <= 1
}

/** Topmost visible, unlocked node under the point. Frames clip their children. */
export function hitTest(doc: Document, point: Point): string | null {
  return hitIn(doc, doc.rootIds, IDENTITY, point)
}

function hitIn(doc: Document, ids: string[], parent: Matrix, point: Point): string | null {
  for (let i = ids.length - 1; i >= 0; i--) {
    const node = doc.nodes[ids[i]]
    if (!node || node.hidden || node.locked) continue

    const matrix = multiply(parent, localMatrix(node))
    const inside = containsLocal(node, apply(invert(matrix), point))

    if (node.type === "group") {
      const child = hitIn(doc, node.childIds, matrix, point)
      if (child) return child
      continue
    }
    if (node.type === "frame") {
      if (!inside) continue
      return hitIn(doc, node.childIds, matrix, point) ?? node.id
    }
    if (inside) return node.id
  }
  return null
}

/**
 * The node a click should select. Groups select as a unit, so a click on a child
 * selects the outermost group below the nearest frame. Frames and other nodes select directly.
 */
export function selectionTarget(doc: Document, id: string): string {
  let target = id
  let parentId = doc.nodes[id]?.parentId ?? null
  while (parentId !== null && doc.nodes[parentId]?.type === "group") {
    target = parentId
    parentId = doc.nodes[parentId].parentId
  }
  return target
}

/**
 * Deepest visible, unlocked frame that contains the point. Used to choose where new shapes land
 * and where dropped nodes get reparented. Ids in `exclude` and their subtrees are skipped.
 */
export function frameAt(doc: Document, point: Point, exclude: ReadonlySet<string> = new Set()): string | null {
  return frameIn(doc, doc.rootIds, IDENTITY, point, exclude)
}

function frameIn(doc: Document, ids: string[], parent: Matrix, point: Point, exclude: ReadonlySet<string>): string | null {
  for (let i = ids.length - 1; i >= 0; i--) {
    const node = doc.nodes[ids[i]]
    if (!node || node.hidden || node.locked || exclude.has(node.id)) continue

    const matrix = multiply(parent, localMatrix(node))
    if (node.type === "group") {
      const found = frameIn(doc, node.childIds, matrix, point, exclude)
      if (found) return found
      continue
    }
    if (node.type === "frame" && containsLocal(node, apply(invert(matrix), point))) {
      return frameIn(doc, node.childIds, matrix, point, exclude) ?? node.id
    }
  }
  return null
}

/** Visible nodes whose page bounds touch the rectangle. Children of groups are reached through their group. */
export function nodesInRect(doc: Document, rect: Bounds): string[] {
  const out: string[] = []
  const visit = (ids: string[]) => {
    for (const id of ids) {
      const node = doc.nodes[id]
      if (!node || node.hidden || node.locked) continue
      const b = nodeBounds(doc, id)
      const touches = b.minX <= rect.maxX && b.maxX >= rect.minX && b.minY <= rect.maxY && b.maxY >= rect.minY
      if (touches) out.push(id)
      if (node.type === "frame") visit(node.childIds)
    }
  }
  visit(doc.rootIds)
  return out
}
