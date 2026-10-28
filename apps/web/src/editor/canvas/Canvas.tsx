import { useEffect, useRef, type CSSProperties, type MouseEvent as ReactMouseEvent, type PointerEvent as ReactPointerEvent } from "react"
import { frameAt, hitTest, nodesInRect, selectionTarget } from "@pelagik/design-core/hit-test"
import { boundsOfIds, createNode, topmostIds, worldCenter } from "@pelagik/design-core/document"
import { addNodeAt, moveNodes, reparentForDrop, resizeNodes, rotateNodes } from "@pelagik/design-core/operations"
import type { Document, Handle, NodeType, Point, Rect, SceneNode, Tool, Viewport } from "@pelagik/design-core/types"
import { fitBounds, screenToWorld, zoomAround } from "@pelagik/design-core/viewport"
import { beginTextEdit } from "../state/commands"
import { useEditor } from "../state/store"
import { CanvasContextMenu } from "./CanvasContextMenu"
import { gridSpacing } from "./grid"
import { SceneNodeView } from "./SceneNodeView"
import { SelectionOverlay } from "./SelectionOverlay"

const SHAPE_TOOLS: Partial<Record<Tool, NodeType>> = {
  frame: "frame",
  rectangle: "rectangle",
  ellipse: "ellipse",
  text: "text",
}

const DEFAULT_SIZE: Record<NodeType, { width: number; height: number }> = {
  frame: { width: 100, height: 100 },
  group: { width: 100, height: 100 },
  rectangle: { width: 100, height: 100 },
  ellipse: { width: 100, height: 100 },
  text: { width: 200, height: 24 },
  icon: { width: 24, height: 24 },
}

/** Screen pixels a pointer must travel before a click becomes a drag. */
const DRAG_THRESHOLD = 3
const ROTATE_SNAP_DEGREES = 15

type Gesture =
  | { kind: "pan"; origin: Point; start: Viewport }
  | { kind: "marquee"; origin: Point; base: string[] }
  | { kind: "move"; origin: Point; screenOrigin: Point; startDoc: Document; ids: string[]; pickedId: string; dragged: boolean }
  | { kind: "resize"; handle: Handle; startDoc: Document; ids: string[] }
  | { kind: "rotate"; center: Point; startAngle: number; startDoc: Document; ids: string[] }
  | {
      kind: "create"
      origin: Point
      box: Rect
      startDoc: Document
      node: SceneNode
      parentId: string | null
      type: NodeType
    }

function localPoint(el: HTMLElement, e: { clientX: number; clientY: number }): Point {
  const rect = el.getBoundingClientRect()
  return { x: e.clientX - rect.left, y: e.clientY - rect.top }
}

function handleAt(target: EventTarget | null): string | null {
  if (!(target instanceof Element)) return null
  return target.closest("[data-handle]")?.getAttribute("data-handle") ?? null
}

function angleOf(center: Point, point: Point): number {
  return (Math.atan2(point.y - center.y, point.x - center.x) * 180) / Math.PI
}

function snapToPixel(point: Point): Point {
  return { x: Math.round(point.x), y: Math.round(point.y) }
}

function selectionCenter(doc: Document, ids: string[]): Point | null {
  const targets = topmostIds(doc, ids)
  if (targets.length === 1) return worldCenter(doc, targets[0])
  const bounds = boundsOfIds(doc, targets)
  if (!bounds) return null
  return { x: (bounds.minX + bounds.maxX) / 2, y: (bounds.minY + bounds.maxY) / 2 }
}

export function Canvas() {
  const containerRef = useRef<HTMLDivElement>(null)
  const gestureRef = useRef<Gesture | null>(null)
  const fittedRef = useRef(false)

  const rootIds = useEditor((s) => s.doc.rootIds)
  const viewport = useEditor((s) => s.viewport)
  const tool = useEditor((s) => s.tool)
  const spaceHeld = useEditor((s) => s.spaceHeld)

  // Track the canvas size and fit the opening document once on first layout.
  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    const observer = new ResizeObserver(([entry]) => {
      const { width, height } = entry.contentRect
      if (width <= 0 || height <= 0) return
      const s = useEditor.getState()
      s.setCanvasSize({ width, height })
      if (!fittedRef.current) {
        fittedRef.current = true
        if (s.doc.rootIds.length > 0) {
          useEditor.getState().setViewport(fitToNodes(s.doc, { width, height }))
        }
      }
    })
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  // Wheel pans; ctrl/cmd + wheel (and trackpad pinch) zooms around the pointer.
  // Listening natively lets us call preventDefault, which React's passive listeners do not allow.
  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      const s = useEditor.getState()
      const point = localPoint(el, e)
      if (e.ctrlKey || e.metaKey) {
        const zoomFactor = e.deltaY < 0 ? 1.1 : e.deltaY > 0 ? 0.9 : 1
        s.setViewport(zoomAround(s.viewport, point, s.viewport.zoom * zoomFactor))
        return
      }
      const horizontal = e.shiftKey && e.deltaX === 0
      const dx = horizontal ? e.deltaY : e.deltaX
      const dy = horizontal ? 0 : e.deltaY
      s.setViewport({ ...s.viewport, x: s.viewport.x - dx, y: s.viewport.y - dy })
    }
    el.addEventListener("wheel", onWheel, { passive: false })
    return () => el.removeEventListener("wheel", onWheel)
  }, [])

  const handlePointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    const el = containerRef.current
    if (!el) return
    const screen = localPoint(el, e)
    const s = useEditor.getState()
    const world = screenToWorld(s.viewport, screen)
    const handle = handleAt(e.target)

    if (e.button === 2) {
      // Right-click selects what is under the pointer, so the context menu acts on it.
      if (!handle) {
        const hit = hitTest(s.doc, world)
        if (hit) {
          const target = selectionTarget(s.doc, hit)
          if (!s.selectedIds.includes(target)) s.setSelection([target])
        }
      }
      return
    }
    if (e.button !== 0 && e.button !== 1) return

    el.setPointerCapture(e.pointerId)

    if (e.button === 1 || s.spaceHeld || s.tool === "hand") {
      gestureRef.current = { kind: "pan", origin: screen, start: s.viewport }
      return
    }

    if (handle === "rotate") {
      const center = selectionCenter(s.doc, s.selectedIds)
      if (center) {
        gestureRef.current = { kind: "rotate", center, startAngle: angleOf(center, world), startDoc: s.doc, ids: s.selectedIds }
      }
      return
    }

    if (handle) {
      gestureRef.current = { kind: "resize", handle: handle as Handle, startDoc: s.doc, ids: s.selectedIds }
      return
    }

    const shapeType = SHAPE_TOOLS[s.tool]
    if (shapeType) {
      const origin = snapToPixel(world)
      const box = { x: origin.x, y: origin.y, width: 0, height: 0 }
      const node = createNode(s.doc, shapeType, box)
      const parentId = frameAt(s.doc, world)
      gestureRef.current = { kind: "create", origin, box, startDoc: s.doc, node, parentId, type: shapeType }
      s.preview(addNodeAt(s.doc, node, box, parentId))
      return
    }

    const hit = hitTest(s.doc, world)
    if (!hit) {
      if (!e.shiftKey) s.setSelection([])
      gestureRef.current = { kind: "marquee", origin: world, base: e.shiftKey ? s.selectedIds : [] }
      return
    }

    const target = selectionTarget(s.doc, hit)
    const isSelected = s.selectedIds.includes(target)
    if (e.shiftKey) {
      s.toggleSelection(target)
      if (isSelected) return
    } else if (!isSelected) {
      s.setSelection([target])
    }

    const current = useEditor.getState()
    gestureRef.current = {
      kind: "move",
      origin: world,
      screenOrigin: screen,
      startDoc: current.doc,
      ids: current.selectedIds,
      pickedId: target,
      dragged: false,
    }
  }

  const handlePointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    const el = containerRef.current
    if (!el) return
    const screen = localPoint(el, e)
    const s = useEditor.getState()
    const world = screenToWorld(s.viewport, screen)
    const gesture = gestureRef.current

    if (!gesture) {
      if (s.tool === "select") {
        const hit = hitTest(s.doc, world)
        const next = hit ? selectionTarget(s.doc, hit) : null
        if (next !== s.hoveredId) s.setHovered(next)
      }
      return
    }

    switch (gesture.kind) {
      case "pan":
        s.setViewport({
          x: gesture.start.x + screen.x - gesture.origin.x,
          y: gesture.start.y + screen.y - gesture.origin.y,
          zoom: gesture.start.zoom,
        })
        return

      case "marquee": {
        const rect = {
          minX: Math.min(gesture.origin.x, world.x),
          minY: Math.min(gesture.origin.y, world.y),
          maxX: Math.max(gesture.origin.x, world.x),
          maxY: Math.max(gesture.origin.y, world.y),
        }
        s.setMarquee({ x: rect.minX, y: rect.minY, width: rect.maxX - rect.minX, height: rect.maxY - rect.minY })
        s.setSelection([...gesture.base, ...nodesInRect(s.doc, rect)])
        return
      }

      case "move": {
        if (!gesture.dragged) {
          const travel = Math.hypot(screen.x - gesture.screenOrigin.x, screen.y - gesture.screenOrigin.y)
          if (travel < DRAG_THRESHOLD) return
          gesture.dragged = true
        }
        let dx = world.x - gesture.origin.x
        let dy = world.y - gesture.origin.y
        if (e.shiftKey) {
          if (Math.abs(dx) > Math.abs(dy)) dy = 0
          else dx = 0
        }
        s.preview(moveNodes(gesture.startDoc, gesture.ids, Math.round(dx), Math.round(dy)))
        return
      }

      case "resize":
        s.preview(resizeNodes(gesture.startDoc, gesture.ids, gesture.handle, snapToPixel(world), e.shiftKey))
        return

      case "rotate": {
        let delta = angleOf(gesture.center, world) - gesture.startAngle
        if (e.shiftKey) delta = Math.round(delta / ROTATE_SNAP_DEGREES) * ROTATE_SNAP_DEGREES
        s.preview(rotateNodes(gesture.startDoc, gesture.ids, gesture.center, delta))
        return
      }

      case "create": {
        const pixel = snapToPixel(world)
        let x = Math.min(gesture.origin.x, pixel.x)
        let y = Math.min(gesture.origin.y, pixel.y)
        let width = Math.abs(pixel.x - gesture.origin.x)
        let height = Math.abs(pixel.y - gesture.origin.y)
        if (e.shiftKey) {
          const size = Math.max(width, height)
          width = size
          height = size
          x = pixel.x < gesture.origin.x ? gesture.origin.x - size : gesture.origin.x
          y = pixel.y < gesture.origin.y ? gesture.origin.y - size : gesture.origin.y
        }
        gesture.box = { x, y, width, height }
        s.preview(addNodeAt(gesture.startDoc, gesture.node, gesture.box, gesture.parentId))
        return
      }
    }
  }

  const finishGesture = (e: ReactPointerEvent<HTMLDivElement>) => {
    const gesture = gestureRef.current
    gestureRef.current = null
    const el = containerRef.current
    if (el?.hasPointerCapture(e.pointerId)) el.releasePointerCapture(e.pointerId)
    if (!gesture) return

    const s = useEditor.getState()
    switch (gesture.kind) {
      case "pan":
        return

      case "marquee":
        s.setMarquee(null)
        return

      case "move":
        if (gesture.dragged) {
          if (el) s.preview(reparentForDrop(s.doc, gesture.ids, screenToWorld(s.viewport, localPoint(el, e))))
          s.endGesture(gesture.startDoc)
        } else if (!e.shiftKey && s.selectedIds.length > 1 && s.selectedIds.includes(gesture.pickedId)) {
          // A plain click inside a multi-selection narrows it to the clicked node.
          s.setSelection([gesture.pickedId])
        }
        return

      case "resize":
      case "rotate":
        s.endGesture(gesture.startDoc)
        return

      case "create": {
        const tiny = gesture.box.width < 2 && gesture.box.height < 2
        const size = DEFAULT_SIZE[gesture.type]
        const box = tiny ? { x: gesture.origin.x, y: gesture.origin.y, ...size } : gesture.box
        s.preview(addNodeAt(gesture.startDoc, gesture.node, box, gesture.parentId))
        s.setTool("select")
        if (gesture.type === "text") {
          // Text starts editing right away. Its undo step is recorded when editing ends.
          s.startEditing(gesture.node.id, gesture.startDoc)
        } else {
          s.endGesture(gesture.startDoc)
          s.setSelection([gesture.node.id])
        }
        return
      }
    }
  }

  const handleDoubleClick = (e: ReactMouseEvent<HTMLDivElement>) => {
    const el = containerRef.current
    if (!el) return
    const s = useEditor.getState()
    const world = screenToWorld(s.viewport, localPoint(el, e))
    const hit = hitTest(s.doc, world)
    if (!hit) return
    if (s.doc.nodes[hit]?.type === "text") {
      beginTextEdit(hit)
      return
    }
    // Double-clicking a group steps into it and selects the child under the pointer.
    if (selectionTarget(s.doc, hit) !== hit) s.setSelection([hit])
  }

  const cursor: CSSProperties["cursor"] =
    spaceHeld || tool === "hand" ? "grab" : tool === "select" ? "default" : tool === "text" ? "text" : "crosshair"

  // The dot grid is painted on the viewport and follows pan and zoom. Each tile is centered on the world origin, so dots sit on world grid points.
  const spacing = gridSpacing(viewport.zoom)
  const gridStyle: CSSProperties = {
    backgroundImage: "radial-gradient(circle, var(--grid-dot) 1px, transparent 1.25px)",
    backgroundSize: `${spacing}px ${spacing}px`,
    backgroundPosition: `${viewport.x - spacing / 2}px ${viewport.y - spacing / 2}px`,
  }

  return (
    <CanvasContextMenu>
      <div
        ref={containerRef}
        className="relative h-full w-full touch-none overflow-hidden bg-canvas select-none"
        style={{ cursor, ...gridStyle }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={finishGesture}
        onPointerCancel={finishGesture}
        onDoubleClick={handleDoubleClick}
      >
        <div
          className="absolute top-0 left-0 h-0 w-0"
          style={
            {
              transform: `translate(${viewport.x}px, ${viewport.y}px) scale(${viewport.zoom})`,
              transformOrigin: "0 0",
              "--zoom": viewport.zoom,
            } as CSSProperties
          }
        >
          {rootIds.map((id) => (
            <SceneNodeView key={id} id={id} />
          ))}
        </div>
        <SelectionOverlay />
      </div>
    </CanvasContextMenu>
  )
}

function fitToNodes(doc: Document, size: { width: number; height: number }): Viewport {
  const bounds = boundsOfIds(doc, doc.rootIds)
  if (!bounds) return { x: 0, y: 0, zoom: 1 }
  return fitBounds(bounds, size)
}
