import type { CSSProperties } from "react"
import { boundsOfIds, topmostIds, worldMatrix } from "@pelagik/design-core/document"
import { apply, rotationOf } from "@pelagik/design-core/matrix"
import type { Document, Handle, Viewport } from "@pelagik/design-core/types"
import { worldToScreen } from "@pelagik/design-core/viewport"
import { activeAgentEdit, useEditor } from "../state/store"

/** Theme token, so selection matches the rest of the chrome in both themes. */
const ACCENT = "var(--selection)"

interface ScreenBox {
  left: number
  top: number
  width: number
  height: number
  rotation: number
  /** Text height follows content, so only horizontal resize applies. */
  textBox: boolean
}

const HANDLES: { handle: Handle; x: number; y: number; cursor: string; vertical: boolean }[] = [
  { handle: "nw", x: 0, y: 0, cursor: "nwse-resize", vertical: true },
  { handle: "n", x: 0.5, y: 0, cursor: "ns-resize", vertical: true },
  { handle: "ne", x: 1, y: 0, cursor: "nesw-resize", vertical: true },
  { handle: "e", x: 1, y: 0.5, cursor: "ew-resize", vertical: false },
  { handle: "se", x: 1, y: 1, cursor: "nwse-resize", vertical: true },
  { handle: "s", x: 0.5, y: 1, cursor: "ns-resize", vertical: true },
  { handle: "sw", x: 0, y: 1, cursor: "nesw-resize", vertical: true },
  { handle: "w", x: 0, y: 0.5, cursor: "ew-resize", vertical: false },
]

/** Screen-space box for one node (rotated with it) or for a multi-selection's bounds. */
function boxFor(doc: Document, ids: string[], viewport: Viewport): ScreenBox | null {
  if (ids.length === 1) {
    const node = doc.nodes[ids[0]]
    if (!node) return null
    const matrix = worldMatrix(doc, ids[0])
    const center = worldToScreen(viewport, apply(matrix, { x: node.width / 2, y: node.height / 2 }))
    const width = node.width * viewport.zoom
    const height = node.height * viewport.zoom
    return {
      left: center.x - width / 2,
      top: center.y - height / 2,
      width,
      height,
      rotation: rotationOf(matrix),
      textBox: node.type === "text",
    }
  }
  const bounds = boundsOfIds(doc, ids)
  if (!bounds) return null
  const min = worldToScreen(viewport, { x: bounds.minX, y: bounds.minY })
  const max = worldToScreen(viewport, { x: bounds.maxX, y: bounds.maxY })
  return { left: min.x, top: min.y, width: max.x - min.x, height: max.y - min.y, rotation: 0, textBox: false }
}

export function SelectionOverlay() {
  const doc = useEditor((s) => s.doc)
  const selectedIds = useEditor((s) => s.selectedIds)
  const hoveredId = useEditor((s) => s.hoveredId)
  const viewport = useEditor((s) => s.viewport)
  const editingId = useEditor((s) => s.editingId)
  const marquee = useEditor((s) => s.marquee)
  const tool = useEditor((s) => s.tool)
  const agentEdit = useEditor(activeAgentEdit)

  const targets = topmostIds(doc, selectedIds)
  const selection = editingId || targets.length === 0 ? null : boxFor(doc, targets, viewport)
  const hover =
    hoveredId && !selectedIds.includes(hoveredId) && !editingId && tool === "select"
      ? boxFor(doc, [hoveredId], viewport)
      : null

  const marqueeStart = marquee ? worldToScreen(viewport, { x: marquee.x, y: marquee.y }) : null
  const marqueeEnd = marquee ? worldToScreen(viewport, { x: marquee.x + marquee.width, y: marquee.y + marquee.height }) : null

  return (
    <div className="pointer-events-none absolute inset-0">
      {hover && (
        <div
          className="absolute border"
          style={{ ...boxStyle(hover), borderColor: ACCENT, borderWidth: 1 }}
        />
      )}
      {marqueeStart && marqueeEnd && (
        <div
          className="absolute border"
          style={{
            left: Math.min(marqueeStart.x, marqueeEnd.x),
            top: Math.min(marqueeStart.y, marqueeEnd.y),
            width: Math.abs(marqueeEnd.x - marqueeStart.x),
            height: Math.abs(marqueeEnd.y - marqueeStart.y),
            borderColor: ACCENT,
            backgroundColor: "color-mix(in oklab, var(--selection) 10%, transparent)",
          }}
        />
      )}
      {agentEdit?.ids.map((id) => {
        const box = boxFor(doc, [id], viewport)
        if (!box) return null
        // Keyed by edit, so every new agent edit replays the glow from the start.
        return (
          <div
            key={`${agentEdit.id}:${id}`}
            className="absolute animate-agent-flash border"
            style={{
              ...boxStyle(box),
              borderColor: ACCENT,
              borderWidth: 1.5,
              backgroundColor: "color-mix(in oklab, var(--selection) 14%, transparent)",
              boxShadow: "0 0 18px color-mix(in oklab, var(--selection) 55%, transparent)",
            }}
          />
        )
      })}
      {selection && <SelectionBox box={selection} rotatable={targets.length === 1} />}
    </div>
  )
}

function boxStyle(box: ScreenBox): CSSProperties {
  return {
    left: box.left,
    top: box.top,
    width: box.width,
    height: box.height,
    transform: box.rotation === 0 ? undefined : `rotate(${box.rotation}deg)`,
  }
}

function SelectionBox({ box, rotatable }: { box: ScreenBox; rotatable: boolean }) {
  return (
    <div className="absolute border" style={{ ...boxStyle(box), borderColor: ACCENT, borderWidth: 1 }}>
      {HANDLES.filter((h) => h.vertical || !box.textBox).map((h) => (
        <div
          key={h.handle}
          data-handle={h.handle}
          className="pointer-events-auto absolute size-2 rounded-[2px] border bg-white"
          style={{
            left: h.x * box.width - 4,
            top: h.y * box.height - 4,
            borderColor: ACCENT,
            cursor: h.cursor,
          }}
        />
      ))}
      {rotatable && (
        <>
          <div className="absolute top-[-24px] left-1/2 h-6 w-px -translate-x-1/2" style={{ backgroundColor: ACCENT }} />
          <div
            data-handle="rotate"
            className="pointer-events-auto absolute top-[-32px] left-1/2 size-3 -translate-x-1/2 rounded-full border bg-white"
            style={{ borderColor: ACCENT, cursor: "grab" }}
          />
        </>
      )}
    </div>
  )
}
