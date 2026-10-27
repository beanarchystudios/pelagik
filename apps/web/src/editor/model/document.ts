import { apply, IDENTITY, invert, multiply, normalizeAngle, rotate, rotationOf, translate, type Matrix } from "./matrix"
import { snapNodePatchToPixels, snapNodeToPixels, snapRectToPixels } from "./pixels"
import type { Bounds, Document, NodeType, Point, Rect, SceneNode } from "./types"

let idCounter = 0

export function createId(): string {
  idCounter += 1
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}${idCounter.toString(36)}`
}

export function emptyDocument(): Document {
  return { nodes: {}, rootIds: [], variables: {} }
}

const LABELS: Record<NodeType, string> = {
  frame: "Frame",
  group: "Group",
  rectangle: "Rectangle",
  ellipse: "Ellipse",
  text: "Text",
}

const STYLE_DEFAULTS: Record<NodeType, Pick<SceneNode, "fill" | "stroke" | "strokeWidth" | "radius" | "text" | "fontSize" | "fontWeight" | "textAlign">> = {
  frame: { fill: "#ffffff", stroke: null, strokeWidth: 1, radius: 0, text: "", fontSize: 14, fontWeight: 400, textAlign: "left" },
  group: { fill: null, stroke: null, strokeWidth: 1, radius: 0, text: "", fontSize: 14, fontWeight: 400, textAlign: "left" },
  rectangle: { fill: "#d9d9d9", stroke: null, strokeWidth: 1, radius: 0, text: "", fontSize: 14, fontWeight: 400, textAlign: "left" },
  ellipse: { fill: "#d9d9d9", stroke: null, strokeWidth: 1, radius: 0, text: "", fontSize: 14, fontWeight: 400, textAlign: "left" },
  text: { fill: "#000000", stroke: null, strokeWidth: 1, radius: 0, text: "", fontSize: 16, fontWeight: 400, textAlign: "left" },
}

/** Creates a detached node (no parent) with the next default name for its type. */
export function createNode(doc: Document, type: NodeType, box: Rect, id: string = createId()): SceneNode {
  const count = Object.values(doc.nodes).filter((node) => node.type === type).length
  return snapNodeToPixels({
    id,
    type,
    name: `${LABELS[type]} ${count + 1}`,
    parentId: null,
    childIds: [],
    flex: null,
    x: box.x,
    y: box.y,
    width: box.width,
    height: box.height,
    rotation: 0,
    opacity: 1,
    hidden: false,
    locked: false,
    bindings: {},
    ...STYLE_DEFAULTS[type],
    ...snapRectToPixels(box),
  })
}

export function childIdsOf(doc: Document, parentId: string | null): string[] {
  return parentId === null ? doc.rootIds : doc.nodes[parentId]?.childIds ?? []
}

export function setChildIds(doc: Document, parentId: string | null, childIds: string[]): Document {
  if (parentId === null) return { ...doc, rootIds: childIds }
  return patchNode(doc, parentId, { childIds })
}

export function patchNode(doc: Document, id: string, patch: Partial<SceneNode>): Document {
  const node = doc.nodes[id]
  if (!node) return doc
  return { ...doc, nodes: { ...doc.nodes, [id]: { ...node, ...snapNodePatchToPixels(patch) } } }
}

/** Removes a node and all of its descendants from the node table. Callers fix up parent lists. */
export function eraseSubtree(doc: Document, id: string): Document {
  const nodes = { ...doc.nodes }
  const stack = [id]
  while (stack.length > 0) {
    const current = stack.pop()
    if (current === undefined) break
    const node = nodes[current]
    if (!node) continue
    stack.push(...node.childIds)
    delete nodes[current]
  }
  return { ...doc, nodes }
}

export function subtreeIds(doc: Document, id: string): string[] {
  const out: string[] = []
  const stack = [id]
  while (stack.length > 0) {
    const current = stack.pop()
    if (current === undefined) break
    out.push(current)
    stack.push(...(doc.nodes[current]?.childIds ?? []))
  }
  return out
}

export function ancestorsOf(doc: Document, id: string): string[] {
  const out: string[] = []
  let parentId = doc.nodes[id]?.parentId ?? null
  while (parentId !== null && doc.nodes[parentId]) {
    out.push(parentId)
    parentId = doc.nodes[parentId].parentId
  }
  return out
}

/** Drops ids whose ancestor is also selected, so transforms apply once per subtree. */
export function topmostIds(doc: Document, ids: string[]): string[] {
  const known = new Set(ids.filter((id) => doc.nodes[id]))
  return [...known].filter((id) => !ancestorsOf(doc, id).some((ancestor) => known.has(ancestor)))
}

export function localMatrix(node: SceneNode): Matrix {
  // Center the box at its pivot, rotate, then move the center to (x, y) + half-size.
  return multiply(
    translate(node.x + node.width / 2, node.y + node.height / 2),
    multiply(rotate(node.rotation), translate(-node.width / 2, -node.height / 2)),
  )
}

export function parentMatrix(doc: Document, parentId: string | null): Matrix {
  return parentId === null ? IDENTITY : worldMatrix(doc, parentId)
}

/** Maps the node's own box coordinates (origin at top-left, unrotated) to page space. */
export function worldMatrix(doc: Document, id: string): Matrix {
  const node = doc.nodes[id]
  return multiply(parentMatrix(doc, node.parentId), localMatrix(node))
}

export function worldCenter(doc: Document, id: string): Point {
  const node = doc.nodes[id]
  return apply(worldMatrix(doc, id), { x: node.width / 2, y: node.height / 2 })
}

export function worldRotation(doc: Document, id: string): number {
  return rotationOf(worldMatrix(doc, id))
}

export function boxCorners(node: SceneNode, matrix: Matrix): Point[] {
  const { width: w, height: h } = node
  return [
    { x: 0, y: 0 },
    { x: w, y: 0 },
    { x: w, y: h },
    { x: 0, y: h },
  ].map((corner) => apply(matrix, corner))
}

export function boundsOf(points: Point[]): Bounds {
  const xs = points.map((p) => p.x)
  const ys = points.map((p) => p.y)
  return { minX: Math.min(...xs), minY: Math.min(...ys), maxX: Math.max(...xs), maxY: Math.max(...ys) }
}

export function unionBounds(list: Bounds[]): Bounds | null {
  if (list.length === 0) return null
  return {
    minX: Math.min(...list.map((b) => b.minX)),
    minY: Math.min(...list.map((b) => b.minY)),
    maxX: Math.max(...list.map((b) => b.maxX)),
    maxY: Math.max(...list.map((b) => b.maxY)),
  }
}

/** Page-space axis-aligned bounds of a node, including rotation. */
export function nodeBounds(doc: Document, id: string): Bounds {
  return boundsOf(boxCorners(doc.nodes[id], worldMatrix(doc, id)))
}

export function boundsOfIds(doc: Document, ids: string[]): Bounds | null {
  return unionBounds(ids.map((id) => nodeBounds(doc, id)))
}

/**
 * Local position and rotation for a node that should sit at a page-space center and rotation
 * when it is placed under `parentId`.
 */
export function placement(
  doc: Document,
  parentId: string | null,
  width: number,
  height: number,
  center: Point,
  worldRotationDeg: number,
): { x: number; y: number; rotation: number } {
  const parent = parentMatrix(doc, parentId)
  const local = apply(invert(parent), center)
  return {
    x: local.x - width / 2,
    y: local.y - height / 2,
    rotation: normalizeAngle(worldRotationDeg - rotationOf(parent)),
  }
}

export function isAncestor(doc: Document, ancestorId: string, id: string): boolean {
  return ancestorsOf(doc, id).includes(ancestorId)
}
