import { apply, invert, multiply, rotate, rotationOf, translate } from "./matrix"
import { layoutFlexChildren } from "./flex"
import { frameAt } from "./hit-test"
import { snapNodePatchToPixels, snapNodeToPixels, snapPx, snapRectToPixels } from "./pixels"
import { BINDABLE_PROPERTIES } from "./variables"
import {
  boundsOf,
  boundsOfIds,
  boxCorners,
  childIdsOf,
  createId,
  createNode,
  eraseSubtree,
  isAncestor,
  localMatrix,
  nodeBounds,
  patchNode,
  placement,
  setChildIds,
  subtreeIds,
  topmostIds,
  worldCenter,
  worldMatrix,
  worldRotation,
} from "./document"
import type {
  AlignMode,
  Bounds,
  Document,
  Fragment,
  Handle,
  Point,
  Rect,
  SceneNode,
  StackOrder,
} from "./types"

export const MIN_SIZE = 1
const SAME_EPSILON = 1e-6

const HANDLE_AXES: Record<Handle, { x: -1 | 0 | 1; y: -1 | 0 | 1 }> = {
  nw: { x: -1, y: -1 },
  n: { x: 0, y: -1 },
  ne: { x: 1, y: -1 },
  e: { x: 1, y: 0 },
  se: { x: 1, y: 1 },
  s: { x: 0, y: 1 },
  sw: { x: -1, y: 1 },
  w: { x: -1, y: 0 },
}

/** Gives every unique parent a chance to refit its bounds and re-run its flex layout, innermost first. */
export function refreshFrom(doc: Document, parentId: string | null): Document {
  let next = doc
  let current = parentId
  while (current !== null && next.nodes[current]) {
    const node = next.nodes[current]
    if (node.type === "group") next = fitGroup(next, current)
    if (node.type === "frame") next = layoutFlexChildren(next, current)
    current = next.nodes[current]?.parentId ?? null
  }
  return next
}

/**
 * Keeps a group's box equal to the bounds of its children. Children are re-based
 * so the group origin sits at their minimum corner, and the group moves to match.
 */
function fitGroup(doc: Document, groupId: string): Document {
  const group = doc.nodes[groupId]
  if (group.childIds.length === 0) return doc

  const corners: Point[] = []
  for (const childId of group.childIds) {
    const child = doc.nodes[childId]
    corners.push(...boxCorners(child, localMatrix(child)))
  }
  const bounds = boundsOf(corners)
  const origin = { x: snapPx(bounds.minX), y: snapPx(bounds.minY) }
  const width = snapPx(bounds.maxX - bounds.minX)
  const height = snapPx(bounds.maxY - bounds.minY)

  const unchanged =
    Math.abs(origin.x) < SAME_EPSILON &&
    Math.abs(origin.y) < SAME_EPSILON &&
    Math.abs(width - group.width) < SAME_EPSILON &&
    Math.abs(height - group.height) < SAME_EPSILON
  if (unchanged) return doc

  const groupWorld = worldMatrix(doc, groupId)
  const center = apply(groupWorld, { x: origin.x + width / 2, y: origin.y + height / 2 })
  const frame = placement(doc, group.parentId, width, height, center, rotationOf(groupWorld))

  let next = doc
  for (const childId of group.childIds) {
    const child = doc.nodes[childId]
    next = patchNode(next, childId, { x: child.x - origin.x, y: child.y - origin.y })
  }
  return patchNode(next, groupId, { ...frame, width, height })
}

/** Scales the local geometry of every descendant, as if the parent frame had been stretched. */
function scaleContents(doc: Document, id: string, sx: number, sy: number): Document {
  let next = doc
  for (const childId of doc.nodes[id].childIds) {
    const child = doc.nodes[childId]
    next = patchNode(next, childId, {
      x: child.x * sx,
      y: child.y * sy,
      width: child.width * sx,
      height: child.height * sy,
    })
    next = scaleContents(next, childId, sx, sy)
    next = layoutFlexChildren(next, childId)
  }
  return next
}

/** Adds a detached node into `parentId`, placing it at a page-space box. */
export function addNodeAt(doc: Document, node: SceneNode, box: Rect, parentId: string | null): Document {
  const snappedBox = snapRectToPixels(box)
  const center = { x: snappedBox.x + snappedBox.width / 2, y: snappedBox.y + snappedBox.height / 2 }
  const local = placement(doc, parentId, snappedBox.width, snappedBox.height, center, 0)
  const placed: SceneNode = snapNodeToPixels({
    ...node,
    ...local,
    width: snappedBox.width,
    height: snappedBox.height,
    parentId,
  })
  let next: Document = { ...doc, nodes: { ...doc.nodes, [placed.id]: placed } }
  next = setChildIds(next, parentId, [...childIdsOf(next, parentId), placed.id])
  return refreshFrom(next, parentId)
}

export function moveNodes(doc: Document, ids: string[], dx: number, dy: number): Document {
  const targets = topmostIds(doc, ids)
  let next = doc
  for (const id of targets) {
    const node = doc.nodes[id]
    const center = worldCenter(doc, id)
    const local = placement(doc, node.parentId, node.width, node.height, { x: center.x + dx, y: center.y + dy }, worldRotation(doc, id))
    next = patchNode(next, id, local)
  }
  return refreshParents(next, doc, targets)
}

function refreshParents(next: Document, original: Document, ids: string[]): Document {
  let result = next
  for (const parentId of new Set(ids.map((id) => original.nodes[id]?.parentId ?? null))) {
    result = refreshFrom(result, parentId)
  }
  return result
}

/**
 * Resizes the selection from a handle. A single node keeps the opposite edge fixed in
 * its own rotated frame. Several nodes scale about the opposite side of their bounds.
 */
export function resizeNodes(doc: Document, ids: string[], handle: Handle, pointer: Point, keepRatio: boolean): Document {
  const targets = topmostIds(doc, ids)
  if (targets.length === 0) return doc
  if (targets.length === 1) return resizeSingle(doc, targets[0], handle, pointer, keepRatio)
  return resizeMany(doc, targets, handle, pointer, keepRatio)
}

function resizeSingle(doc: Document, id: string, handle: Handle, pointer: Point, keepRatio: boolean): Document {
  const node = doc.nodes[id]
  const { x: hx, y: hy } = HANDLE_AXES[handle]
  const matrix = worldMatrix(doc, id)
  const local = apply(invert(matrix), pointer)
  const w0 = node.width
  const h0 = node.height
  const isText = node.type === "text"

  let width = hx === 0 ? w0 : Math.max(MIN_SIZE, snapPx(hx > 0 ? local.x : w0 - local.x))
  let height = hy === 0 || isText ? h0 : Math.max(MIN_SIZE, snapPx(hy > 0 ? local.y : h0 - local.y))
  if (keepRatio && hx !== 0 && hy !== 0 && !isText && w0 > 0 && h0 > 0) {
    height = Math.max(MIN_SIZE, snapPx(width * (h0 / w0)))
  }

  // The anchor is the handle's opposite edge. It stays put in page space.
  const anchor = apply(matrix, { x: hx < 0 ? w0 : 0, y: hy < 0 ? h0 : 0 })
  const newAnchor = { x: hx < 0 ? width : 0, y: hy < 0 ? height : 0 }
  const next = multiply(translate(anchor.x, anchor.y), multiply({ ...matrix, e: 0, f: 0 }, translate(-newAnchor.x, -newAnchor.y)))
  const center = apply(next, { x: width / 2, y: height / 2 })
  const placed = placement(doc, node.parentId, width, height, center, rotationOf(next))

  let result = patchNode(doc, id, { ...placed, width, height })
  if (node.type === "group" && w0 > 0 && h0 > 0) {
    result = scaleContents(result, id, width / w0, height / h0)
  }
  result = layoutFlexChildren(result, id)
  return refreshFrom(result, node.parentId)
}

function resizeMany(doc: Document, targets: string[], handle: Handle, pointer: Point, keepRatio: boolean): Document {
  const bounds = boundsOfIds(doc, targets)
  if (!bounds) return doc
  const { x: hx, y: hy } = HANDLE_AXES[handle]
  const width = bounds.maxX - bounds.minX
  const height = bounds.maxY - bounds.minY

  let newWidth = width
  let newHeight = height
  let anchorX = bounds.minX
  let anchorY = bounds.minY
  if (hx > 0) newWidth = Math.max(MIN_SIZE, pointer.x - bounds.minX)
  if (hx < 0) {
    newWidth = Math.max(MIN_SIZE, bounds.maxX - pointer.x)
    anchorX = bounds.maxX
  }
  if (hy > 0) newHeight = Math.max(MIN_SIZE, pointer.y - bounds.minY)
  if (hy < 0) {
    newHeight = Math.max(MIN_SIZE, bounds.maxY - pointer.y)
    anchorY = bounds.maxY
  }

  let sx = width > 0 ? newWidth / width : 1
  let sy = height > 0 ? newHeight / height : 1
  if (keepRatio && hx !== 0 && hy !== 0) {
    const s = Math.abs(sx - 1) >= Math.abs(sy - 1) ? sx : sy
    sx = s
    sy = s
  }

  let next = doc
  for (const id of targets) {
    const node = doc.nodes[id]
    const center = worldCenter(doc, id)
    const scaledCenter = {
      x: anchorX + (center.x - anchorX) * sx,
      y: anchorY + (center.y - anchorY) * sy,
    }
    const w = node.width * sx
    const h = node.type === "text" ? node.height : node.height * sy
    const local = placement(doc, node.parentId, w, h, scaledCenter, worldRotation(doc, id))
    next = patchNode(next, id, { ...local, width: w, height: h })
    if (node.type === "group") next = scaleContents(next, id, sx, sy)
    next = layoutFlexChildren(next, id)
  }
  return refreshParents(next, doc, targets)
}

/** Rotates the selection by `deltaDegrees` about `pivot`. A single node pivots on its own center. */
export function rotateNodes(doc: Document, ids: string[], pivot: Point, deltaDegrees: number): Document {
  deltaDegrees = snapPx(deltaDegrees)
  const targets = topmostIds(doc, ids)
  const spin = rotate(deltaDegrees)
  let next = doc
  for (const id of targets) {
    const node = doc.nodes[id]
    const center = worldCenter(doc, id)
    const offset = apply(spin, { x: center.x - pivot.x, y: center.y - pivot.y })
    const rotatedCenter = { x: pivot.x + offset.x, y: pivot.y + offset.y }
    const local = placement(doc, node.parentId, node.width, node.height, rotatedCenter, worldRotation(doc, id) + deltaDegrees)
    next = patchNode(next, id, local)
  }
  return refreshParents(next, doc, targets)
}

/**
 * Moves nodes under a new parent, keeping each one where it appears on the page.
 * `index` counts positions after the moved nodes have been removed from their old parent.
 */
export function reparentNodes(doc: Document, ids: string[], parentId: string | null, index: number | null): Document {
  const targets = topmostIds(doc, ids).filter(
    (id) => id !== parentId && !(parentId !== null && isAncestor(doc, id, parentId)),
  )
  if (targets.length === 0) return doc

  const worlds = targets.map((id) => ({ id, center: worldCenter(doc, id), rotation: worldRotation(doc, id) }))
  const oldParents = targets.map((id) => doc.nodes[id].parentId)

  let next = doc
  for (const id of targets) {
    const oldParent = doc.nodes[id].parentId
    next = setChildIds(next, oldParent, childIdsOf(next, oldParent).filter((childId) => childId !== id))
  }

  const list = childIdsOf(next, parentId)
  const at = index === null ? list.length : Math.max(0, Math.min(index, list.length))
  next = setChildIds(next, parentId, [...list.slice(0, at), ...targets, ...list.slice(at)])

  for (const { id, center, rotation } of worlds) {
    const node = doc.nodes[id]
    const local = placement(doc, parentId, node.width, node.height, center, rotation)
    next = patchNode(next, id, { ...local, parentId })
  }

  for (const oldParent of new Set(oldParents)) next = refreshFrom(next, oldParent)
  return refreshFrom(next, parentId)
}

/**
 * After a drag, moves the nodes into the frame under the pointer, or onto the page when the pointer
 * is outside every frame. Nodes that live inside a group stay put: groups move as a unit.
 */
export function reparentForDrop(doc: Document, ids: string[], pointer: Point): Document {
  const targets = topmostIds(doc, ids)
  if (targets.length === 0) return doc

  const parents = new Set(targets.map((id) => doc.nodes[id].parentId))
  for (const parentId of parents) {
    if (parentId !== null && doc.nodes[parentId].type === "group") return doc
  }

  const moving = new Set(targets.flatMap((id) => subtreeIds(doc, id)))
  const target = frameAt(doc, pointer, moving)
  if (parents.size === 1 && parents.has(target)) return doc
  return reparentNodes(doc, targets, target, null)
}

export function groupNodes(doc: Document, ids: string[]): { doc: Document; groupId: string } | null {
  const picked = topmostIds(doc, ids)
  if (picked.length === 0) return null
  const parentId = doc.nodes[picked[0]].parentId
  const targets = picked.filter((id) => doc.nodes[id].parentId === parentId)
  const targetSet = new Set(targets)

  const corners: Point[] = []
  for (const id of targets) {
    const node = doc.nodes[id]
    corners.push(...boxCorners(node, localMatrix(node)))
  }
  const bounds = boundsOf(corners)
  const groupId = createId()
  const list = childIdsOf(doc, parentId)
  const ordered = list.filter((id) => targetSet.has(id))

  let next = doc
  for (const id of ordered) {
    const node = doc.nodes[id]
    next = patchNode(next, id, { parentId: groupId, x: node.x - bounds.minX, y: node.y - bounds.minY })
  }

  const group = createNode(
    doc,
    "group",
    { x: bounds.minX, y: bounds.minY, width: bounds.maxX - bounds.minX, height: bounds.maxY - bounds.minY },
    groupId,
  )
  next = { ...next, nodes: { ...next.nodes, [groupId]: { ...group, parentId, childIds: ordered } } }

  const firstIndex = list.findIndex((id) => targetSet.has(id))
  const newList = list.filter((id) => !targetSet.has(id))
  newList.splice(firstIndex, 0, groupId)
  next = setChildIds(next, parentId, newList)
  return { doc: refreshFrom(next, parentId), groupId }
}

export function ungroupNodes(doc: Document, ids: string[]): { doc: Document; childIds: string[] } {
  const groups = topmostIds(doc, ids).filter((id) => doc.nodes[id]?.type === "group")
  let next = doc
  const childIds: string[] = []
  const parents = new Set<string | null>()

  for (const groupId of groups) {
    const group = next.nodes[groupId]
    if (!group) continue
    const parentId = group.parentId
    const kids = group.childIds
    parents.add(parentId)
    childIds.push(...kids)

    const worlds = kids.map((id) => ({ id, center: worldCenter(next, id), rotation: worldRotation(next, id) }))
    const parentList = childIdsOf(next, parentId)
    const at = parentList.indexOf(groupId)
    const newList = parentList.filter((id) => id !== groupId)
    newList.splice(at, 0, ...kids)
    next = setChildIds(next, parentId, newList)

    for (const { id, center, rotation } of worlds) {
      const node = next.nodes[id]
      const local = placement(next, parentId, node.width, node.height, center, rotation)
      next = patchNode(next, id, { ...local, parentId })
    }

    const nodes = { ...next.nodes }
    delete nodes[groupId]
    next = { ...next, nodes }
  }

  for (const parentId of parents) next = refreshFrom(next, parentId)
  return { doc: next, childIds }
}

export function deleteNodes(doc: Document, ids: string[]): Document {
  const targets = topmostIds(doc, ids)
  let next = doc
  const parents = new Set<string | null>()

  for (const id of targets) {
    const node = next.nodes[id]
    if (!node) continue
    parents.add(node.parentId)
    next = setChildIds(next, node.parentId, childIdsOf(next, node.parentId).filter((childId) => childId !== id))
    next = eraseSubtree(next, id)
  }

  for (const parentId of parents) next = pruneEmptyGroups(next, parentId)
  return next
}

/** Removes groups left with no children, then refits remaining groups and re-lays out frames. */
function pruneEmptyGroups(doc: Document, parentId: string | null): Document {
  let next = doc
  let current = parentId
  while (current !== null && next.nodes[current]) {
    const node = next.nodes[current]
    if (node.type === "group" && node.childIds.length === 0) {
      const grandParent = node.parentId
      next = setChildIds(next, grandParent, childIdsOf(next, grandParent).filter((id) => id !== current))
      next = eraseSubtree(next, current)
      current = grandParent
      continue
    }
    if (node.type === "group") next = fitGroup(next, current)
    if (node.type === "frame") next = layoutFlexChildren(next, current)
    current = next.nodes[current]?.parentId ?? null
  }
  return next
}

/** Copies the selection. Root entries store page-space placement so they can be pasted anywhere. */
export function copyNodes(doc: Document, ids: string[]): Fragment {
  const targets = topmostIds(doc, ids)
  const nodes: Record<string, SceneNode> = {}
  for (const id of targets) {
    for (const nodeId of subtreeIds(doc, id)) nodes[nodeId] = snapNodeToPixels(doc.nodes[nodeId])
    const node = doc.nodes[id]
    const center = worldCenter(doc, id)
    nodes[id] = snapNodeToPixels({
      ...node,
      parentId: null,
      x: center.x - node.width / 2,
      y: center.y - node.height / 2,
      rotation: worldRotation(doc, id),
    })
  }
  return { nodes, rootIds: targets }
}

export function insertFragment(
  doc: Document,
  fragment: Fragment,
  parentId: string | null,
  index: number | null,
  offset: Point,
): { doc: Document; ids: string[] } {
  const idMap: Record<string, string> = {}
  for (const oldId of Object.keys(fragment.nodes)) idMap[oldId] = createId()

  const clones: Record<string, SceneNode> = {}
  for (const [oldId, node] of Object.entries(fragment.nodes)) {
    const id = idMap[oldId]
    clones[id] = snapNodeToPixels({
      ...node,
      id,
      parentId: node.parentId === null ? null : idMap[node.parentId] ?? null,
      childIds: node.childIds.map((childId) => idMap[childId]),
    })
  }

  const rootIds = fragment.rootIds.map((oldId) => idMap[oldId])
  for (const id of rootIds) {
    const node = clones[id]
    const center = { x: node.x + node.width / 2 + offset.x, y: node.y + node.height / 2 + offset.y }
    const local = placement(doc, parentId, node.width, node.height, center, node.rotation)
    clones[id] = snapNodeToPixels({ ...node, ...local, parentId })
  }

  let next: Document = { ...doc, nodes: { ...doc.nodes, ...clones } }
  const list = childIdsOf(next, parentId)
  const at = index === null ? list.length : index
  next = setChildIds(next, parentId, [...list.slice(0, at), ...rootIds, ...list.slice(at)])
  return { doc: refreshFrom(next, parentId), ids: rootIds }
}

/** Duplicates each selected top-level node right above the original, in the same parent. */
export function duplicateNodes(doc: Document, ids: string[], offset: Point): { doc: Document; ids: string[] } {
  let next = doc
  const created: string[] = []
  for (const id of topmostIds(doc, ids)) {
    const node = next.nodes[id]
    if (!node) continue
    const fragment = copyNodes(next, [id])
    const index = childIdsOf(next, node.parentId).indexOf(id) + 1
    const result = insertFragment(next, fragment, node.parentId, index, offset)
    next = result.doc
    created.push(...result.ids)
  }
  return { doc: next, ids: created }
}

export function reorderNodes(doc: Document, ids: string[], order: StackOrder): Document {
  const parents = new Set(ids.filter((id) => doc.nodes[id]).map((id) => doc.nodes[id].parentId))
  let next = doc
  for (const parentId of parents) {
    const selected = new Set(ids.filter((id) => doc.nodes[id]?.parentId === parentId))
    const ordered = reorderList(childIdsOf(next, parentId), selected, order)
    next = refreshFrom(setChildIds(next, parentId, ordered), parentId)
  }
  return next
}

function reorderList(list: string[], selected: Set<string>, order: StackOrder): string[] {
  if (order === "front") return [...list.filter((id) => !selected.has(id)), ...list.filter((id) => selected.has(id))]
  if (order === "back") return [...list.filter((id) => selected.has(id)), ...list.filter((id) => !selected.has(id))]

  const out = [...list]
  if (order === "forward") {
    for (let i = out.length - 2; i >= 0; i--) {
      if (selected.has(out[i]) && !selected.has(out[i + 1])) swap(out, i, i + 1)
    }
  } else {
    for (let i = 1; i < out.length; i++) {
      if (selected.has(out[i]) && !selected.has(out[i - 1])) swap(out, i, i - 1)
    }
  }
  return out
}

function swap(list: string[], i: number, j: number) {
  const tmp = list[i]
  list[i] = list[j]
  list[j] = tmp
}

/** Aligns a multi-selection to its combined bounds, or a single node to its parent. */
export function alignNodes(doc: Document, ids: string[], mode: AlignMode): Document {
  const targets = topmostIds(doc, ids)
  if (targets.length === 0) return doc

  let frame: Bounds | null
  if (targets.length > 1) {
    frame = boundsOfIds(doc, targets)
  } else {
    const parentId = doc.nodes[targets[0]].parentId
    if (parentId === null) return doc
    frame = nodeBounds(doc, parentId)
  }
  if (!frame) return doc

  let next = doc
  for (const id of targets) {
    const b = nodeBounds(doc, id)
    let dx = 0
    let dy = 0
    switch (mode) {
      case "left":
        dx = frame.minX - b.minX
        break
      case "right":
        dx = frame.maxX - b.maxX
        break
      case "center":
        dx = (frame.minX + frame.maxX) / 2 - (b.minX + b.maxX) / 2
        break
      case "top":
        dy = frame.minY - b.minY
        break
      case "bottom":
        dy = frame.maxY - b.maxY
        break
      case "middle":
        dy = (frame.minY + frame.maxY) / 2 - (b.minY + b.maxY) / 2
        break
    }
    if (dx !== 0 || dy !== 0) next = moveNodes(next, [id], dx, dy)
  }
  return next
}

/** Applies property changes to nodes. Resizing a group stretches its contents. */
export function updateNodes(doc: Document, ids: string[], patch: Partial<SceneNode>): Document {
  const snappedPatch = snapNodePatchToPixels(patch)
  let next = doc
  for (const id of ids) {
    const node = next.nodes[id]
    if (!node) continue
    const nextWidth = snappedPatch.width ?? node.width
    const nextHeight = snappedPatch.height ?? node.height
    if (node.type === "group" && node.width > 0 && node.height > 0 && (nextWidth !== node.width || nextHeight !== node.height)) {
      next = scaleContents(next, id, nextWidth / node.width, nextHeight / node.height)
    }
    next = patchNode(next, id, withDetachedBindings(node, snappedPatch))
  }
  for (const id of ids) next = layoutFlexChildren(next, id)
  return refreshParents(next, doc, ids)
}

/** Typing a value into a bound property overrides the link, so the property detaches from its variable. */
function withDetachedBindings(node: SceneNode, patch: Partial<SceneNode>): Partial<SceneNode> {
  if (patch.bindings) return patch
  const overridden = BINDABLE_PROPERTIES.filter((prop) => prop in patch && node.bindings[prop] !== undefined)
  if (overridden.length === 0) return patch
  const bindings = { ...node.bindings }
  for (const prop of overridden) delete bindings[prop]
  return { ...patch, bindings }
}
