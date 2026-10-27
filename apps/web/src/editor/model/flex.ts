import { patchNode } from "./document"
import { snapPx } from "./pixels"
import type { FlexLayout, FlexCrossAlign, Document, SceneNode } from "./types"

export const DEFAULT_FLEX: FlexLayout = {
  direction: "vertical",
  gap: 8,
  padding: 8,
  mainAlign: "start",
  crossAlign: "start",
}

/** Fraction of the leftover cross-axis space placed before a child. */
const CROSS_FACTOR: Record<FlexCrossAlign, number> = { start: 0, center: 0.5, end: 1 }

/**
 * Positions a frame's children along its flex axis. Children keep their own sizes, and
 * children that do not fit overflow the frame, which clips them. The frame's size is never changed.
 */
export function layoutFlexChildren(doc: Document, frameId: string): Document {
  const frame = doc.nodes[frameId]
  const layout = frame?.flex
  if (!frame || !layout || frame.childIds.length === 0) return doc

  const horizontal = layout.direction === "horizontal"
  const along = (node: SceneNode) => (horizontal ? node.width : node.height)
  const across = (node: SceneNode) => (horizontal ? node.height : node.width)
  const children = frame.childIds.map((id) => doc.nodes[id])
  const innerAlong = (horizontal ? frame.width : frame.height) - 2 * layout.padding
  const innerAcross = (horizontal ? frame.height : frame.width) - 2 * layout.padding

  const count = children.length
  const used = children.reduce((sum, node) => sum + along(node), 0)
  const spread = layout.mainAlign === "space-between" && count > 1
  // Space-between fills the leftover length with gaps, never negative ones that would overlap.
  const gap = spread ? Math.max(0, (innerAlong - used) / (count - 1)) : layout.gap
  const span = used + gap * (count - 1)

  let cursor = layout.padding
  if (!spread && layout.mainAlign === "center") cursor += (innerAlong - span) / 2
  if (!spread && layout.mainAlign === "end") cursor += innerAlong - span

  let next = doc
  for (const child of children) {
    const offset = layout.padding + (innerAcross - across(child)) * CROSS_FACTOR[layout.crossAlign]
    const x = snapPx(horizontal ? cursor : offset)
    const y = snapPx(horizontal ? offset : cursor)
    if (x !== child.x || y !== child.y) next = patchNode(next, child.id, { x, y })
    cursor += along(child) + gap
  }
  return next
}
