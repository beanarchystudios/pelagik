import {
  addNodeAt,
  alignNodes,
  copyNodes,
  deleteNodes,
  duplicateNodes,
  groupNodes,
  insertFragment,
  moveNodes,
  refreshFrom,
  reorderNodes,
  reparentNodes,
  ungroupNodes,
  updateNodes,
} from "@pelagik/design-core/operations"
import { boundsOfIds, childIdsOf, createId, createNode, patchNode } from "@pelagik/design-core/document"
import { frameAt } from "@pelagik/design-core/hit-test"
import { fitBounds, screenToWorld, zoomAround } from "@pelagik/design-core/viewport"
import {
  addVariable,
  bindNodes,
  deleteVariable,
  renameVariable,
  setVariableValue,
} from "@pelagik/design-core/variables"
import type { AlignMode, BindableProperty, DesignVariable, Fragment, IconGlyph, SceneNode, StackOrder, Tool } from "@pelagik/design-core/types"
import { useEditor } from "./store"

const state = () => useEditor.getState()

const PASTE_OFFSET = 10
/** Icons insert at this size on their longer side, the usual default for icon libraries. */
const ICON_SIZE = 24

function shiftFragment(fragment: Fragment, dx: number, dy: number): Fragment {
  const nodes = { ...fragment.nodes }
  for (const id of fragment.rootIds) {
    nodes[id] = { ...nodes[id], x: nodes[id].x + dx, y: nodes[id].y + dy }
  }
  return { nodes, rootIds: fragment.rootIds }
}

export function setTool(tool: Tool) {
  state().setTool(tool)
}

export function deleteSelection() {
  const s = state()
  if (s.selectedIds.length === 0) return
  s.commit(deleteNodes(s.doc, s.selectedIds))
  s.setSelection([])
}

export function duplicateSelection() {
  const s = state()
  if (s.selectedIds.length === 0) return
  const result = duplicateNodes(s.doc, s.selectedIds, { x: PASTE_OFFSET, y: PASTE_OFFSET })
  s.commit(result.doc)
  s.setSelection(result.ids)
}

export function copySelection() {
  const s = state()
  if (s.selectedIds.length === 0) return
  s.setClipboard(copyNodes(s.doc, s.selectedIds))
}

export function pasteClipboard() {
  const s = state()
  const clipboard = s.clipboard
  if (!clipboard) return
  const result = insertFragment(s.doc, clipboard, null, null, { x: PASTE_OFFSET, y: PASTE_OFFSET })
  s.commit(result.doc)
  s.setSelection(result.ids)
  // Repeated pastes cascade instead of stacking on the same spot.
  s.setClipboard(shiftFragment(clipboard, PASTE_OFFSET, PASTE_OFFSET))
}

export function groupSelection() {
  const s = state()
  const result = groupNodes(s.doc, s.selectedIds)
  if (!result) return
  s.commit(result.doc)
  s.setSelection([result.groupId])
}

export function ungroupSelection() {
  const s = state()
  const result = ungroupNodes(s.doc, s.selectedIds)
  if (result.doc === s.doc) return
  s.commit(result.doc)
  s.setSelection(result.childIds)
}

export function reorderSelection(order: StackOrder) {
  const s = state()
  if (s.selectedIds.length === 0) return
  s.commit(reorderNodes(s.doc, s.selectedIds, order))
}

export function nudgeSelection(dx: number, dy: number) {
  const s = state()
  if (s.selectedIds.length === 0) return
  s.commit(moveNodes(s.doc, s.selectedIds, dx, dy), "nudge")
}

export function alignSelection(mode: AlignMode) {
  const s = state()
  if (s.selectedIds.length === 0) return
  s.commit(alignNodes(s.doc, s.selectedIds, mode))
}

export function updateNodesProps(ids: string[], patch: Partial<SceneNode>, coalesceKey?: string) {
  const s = state()
  const targets = ids.filter((id) => s.doc.nodes[id])
  if (targets.length === 0) return
  s.commit(updateNodes(s.doc, targets, patch), coalesceKey)
}

export function renameNode(id: string, name: string) {
  const trimmed = name.trim()
  if (!trimmed || state().doc.nodes[id]?.name === trimmed) return
  updateNodesProps([id], { name: trimmed }, `rename:${id}`)
}

export function toggleHidden(id: string) {
  const node = state().doc.nodes[id]
  if (node) updateNodesProps([id], { hidden: !node.hidden })
}

export function toggleLocked(id: string) {
  const node = state().doc.nodes[id]
  if (node) updateNodesProps([id], { locked: !node.locked })
}

export function selectAll() {
  const s = state()
  s.setSelection(s.doc.rootIds)
}

export function zoomToFit() {
  const s = state()
  const bounds = boundsOfIds(s.doc, s.doc.rootIds)
  if (!bounds) return
  s.setViewport(fitBounds(bounds, s.canvasSize))
}

export function zoomToSelection() {
  const s = state()
  const bounds = boundsOfIds(s.doc, s.selectedIds)
  if (!bounds) return
  s.setViewport(fitBounds(bounds, s.canvasSize))
}

export function zoomTo(zoom: number) {
  const s = state()
  const center = { x: s.canvasSize.width / 2, y: s.canvasSize.height / 2 }
  s.setViewport(zoomAround(s.viewport, center, zoom))
}

export function zoomBy(factor: number) {
  zoomTo(state().viewport.zoom * factor)
}

export function beginTextEdit(id: string) {
  const s = state()
  if (s.doc.nodes[id]?.type !== "text") return
  s.startEditing(id, s.doc)
}

export function setNodeText(id: string, text: string) {
  const s = state()
  const node = s.doc.nodes[id]
  if (!node) return
  s.preview(patchNode(s.doc, id, { text }))
}

/** Measured text height is a layout fact, not a user edit, so it skips history. */
export function syncTextHeight(id: string, height: number) {
  const s = state()
  const node = s.doc.nodes[id]
  if (!node || Math.abs(node.height - height) < 0.5) return
  s.preview(refreshFrom(patchNode(s.doc, id, { height }), node.parentId))
}

export function finishTextEdit() {
  const s = state()
  const id = s.editingId
  if (!id) return
  const start = s.editStart
  const node = s.doc.nodes[id]
  s.stopEditing()

  if (node && node.text.trim() === "") {
    // Empty text nodes are discarded. If this edit created the node, the start snapshot never had it.
    if (start && !start.nodes[id]) {
      s.preview(start)
      return
    }
    s.preview(deleteNodes(s.doc, [id]))
  }
  if (start) s.endGesture(start)
}

export type DropZone = "above" | "below" | "inside"

/** Moves layers next to (above/below) or inside a target layer, as dropped in the layers panel. */
export function dropLayers(ids: string[], targetId: string, zone: DropZone) {
  const s = state()
  const target = s.doc.nodes[targetId]
  if (!target || ids.includes(targetId)) return

  let parentId: string | null
  let index: number | null
  if (zone === "inside" && (target.type === "frame" || target.type === "group")) {
    parentId = targetId
    index = null
  } else {
    parentId = target.parentId
    const siblings = childIdsOf(s.doc, parentId).filter((id) => !ids.includes(id))
    const position = siblings.indexOf(targetId)
    if (position < 0) return
    // Layers panel lists top-most first, so "above" means a higher index in the child list.
    index = zone === "above" ? position + 1 : position
  }

  const next = reparentNodes(s.doc, ids, parentId, index)
  if (next === s.doc) return
  s.commit(next)
  s.setSelection(ids)
}

const DEFAULT_COLOR = "#d9d9d9"

/** Adds a color token and returns its id. */
export function createVariable(): string {
  const s = state()
  const count = Object.values(s.doc.variables).length + 1
  const id = createId()
  const variable: DesignVariable = { id, name: `Color ${count}`, type: "color", value: DEFAULT_COLOR }
  s.commit(addVariable(s.doc, variable))
  return id
}

export function renameVariableCommand(id: string, name: string) {
  const s = state()
  const trimmed = name.trim()
  if (!trimmed || s.doc.variables[id]?.name === trimmed) return
  s.commit(renameVariable(s.doc, id, trimmed), `rename-var:${id}`)
}

/** Changes a variable's value. Bound properties on every node update with it. */
export function changeVariableValue(id: string, value: string, coalesceKey?: string) {
  const s = state()
  s.commit(setVariableValue(s.doc, id, value), coalesceKey)
}

export function removeVariable(id: string) {
  const s = state()
  s.commit(deleteVariable(s.doc, id))
}

/** Binds a property on the selected nodes to a variable, or detaches it when `variableId` is null. */
export function bindSelection(prop: BindableProperty, variableId: string | null) {
  const s = state()
  if (s.selectedIds.length === 0) return
  s.commit(bindNodes(s.doc, s.selectedIds, prop, variableId))
}

/** Adds an icon at the center of the view, inside the frame under that point, and selects it. */
export function insertIcon(glyph: IconGlyph) {
  const s = state()
  const center = screenToWorld(s.viewport, { x: s.canvasSize.width / 2, y: s.canvasSize.height / 2 })
  const size = iconSize(glyph.viewBox)
  const box = { x: center.x - size.width / 2, y: center.y - size.height / 2, ...size }
  const node: SceneNode = { ...createNode(s.doc, "icon", box), name: glyph.name.split(":")[1] ?? glyph.name, icon: glyph }
  s.commit(addNodeAt(s.doc, node, box, frameAt(s.doc, center)))
  s.setSelection([node.id])
  s.setTool("select")
}

function iconSize(viewBox: string): { width: number; height: number } {
  const [, , width, height] = viewBox.split(" ").map(Number)
  const scale = ICON_SIZE / Math.max(width, height)
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) }
}
