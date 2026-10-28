import { ChevronRight, Circle, Eye, EyeOff, Frame, Group, Lock, LockOpen, Shapes, Square, Type, type LucideIcon } from "lucide-react"
import { useEffect, useMemo, useRef, useState, type DragEvent, type MouseEvent } from "react"
import { ScrollArea } from "@pelagik/ui/components/scroll-area"
import { cn } from "cn"
import type { NodeType } from "@pelagik/design-core/types"
import { dropLayers, renameNode, toggleHidden, toggleLocked, type DropZone } from "../state/commands"
import { activeAgentEdit, useEditor } from "../state/store"

const ICONS: Record<NodeType, LucideIcon> = {
  frame: Frame,
  group: Group,
  rectangle: Square,
  ellipse: Circle,
  text: Type,
  icon: Shapes,
}

interface Row {
  id: string
  depth: number
}

export function LayersPanel() {
  const doc = useEditor((s) => s.doc)
  const selectedIds = useEditor((s) => s.selectedIds)
  const [collapsed, setCollapsed] = useState<Set<string>>(() => new Set())
  const [draggingId, setDraggingId] = useState<string | null>(null)
  const [dropTarget, setDropTarget] = useState<{ id: string; zone: DropZone } | null>(null)

  const rows = useMemo(() => {
    const out: Row[] = []
    const walk = (ids: string[], depth: number) => {
      for (const id of [...ids].reverse()) {
        const node = doc.nodes[id]
        if (!node) continue
        out.push({ id, depth })
        if (node.childIds.length > 0 && !collapsed.has(id)) walk(node.childIds, depth + 1)
      }
    }
    walk(doc.rootIds, 0)
    return out
  }, [doc, collapsed])

  const toggleCollapsed = (id: string) => {
    setCollapsed((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const finishDrag = () => {
    setDraggingId(null)
    setDropTarget(null)
  }

  return (
    <ScrollArea className="min-h-0 flex-1">
      <div role="tree" onDragEnd={finishDrag}>
        {rows.map(({ id, depth }) => (
          <LayerRow
            key={id}
            id={id}
            depth={depth}
            selected={selectedIds.includes(id)}
            collapsed={collapsed.has(id)}
            dropZone={dropTarget?.id === id ? dropTarget.zone : null}
            onToggleCollapsed={toggleCollapsed}
            onDragStart={() => setDraggingId(id)}
            onDragOver={(zone) => {
              if (draggingId === null || draggingId === id) return
              // dragover fires continuously, so skip the state update when nothing changed.
              setDropTarget((current) => (current?.id === id && current.zone === zone ? current : { id, zone }))
            }}
            onDrop={(zone) => {
              if (draggingId !== null) {
                const dragged = selectedIds.includes(draggingId) ? selectedIds : [draggingId]
                dropLayers(dragged, id, zone)
              }
              finishDrag()
            }}
          />
        ))}
        {rows.length === 0 && (
          <p className="px-3 py-6 text-center text-xs text-muted-foreground">
            No layers yet. Pick a tool and draw on the canvas.
          </p>
        )}
      </div>
    </ScrollArea>
  )
}

interface LayerRowProps {
  id: string
  depth: number
  selected: boolean
  collapsed: boolean
  dropZone: DropZone | null
  onToggleCollapsed: (id: string) => void
  onDragStart: () => void
  onDragOver: (zone: DropZone) => void
  onDrop: (zone: DropZone) => void
}

function LayerRow({ id, depth, selected, collapsed, dropZone, onToggleCollapsed, onDragStart, onDragOver, onDrop }: LayerRowProps) {
  const node = useEditor((s) => s.doc.nodes[id])
  const setHovered = useEditor((s) => s.setHovered)
  const setSelection = useEditor((s) => s.setSelection)
  const toggleSelection = useEditor((s) => s.toggleSelection)
  const [renaming, setRenaming] = useState(false)
  const cancelRename = useRef(false)
  const nameRef = useRef<HTMLSpanElement>(null)
  // Non-zero while an agent edit touched this row. Keying the flash by it replays the animation per edit.
  const flashId = useEditor((s) => {
    const edit = activeAgentEdit(s)
    return edit?.ids.includes(id) ? edit.id : 0
  })

  useEffect(() => {
    if (!renaming || !nameRef.current) return
    const label = nameRef.current
    label.focus()
    const range = document.createRange()
    range.selectNodeContents(label)
    const selection = window.getSelection()
    selection?.removeAllRanges()
    selection?.addRange(range)
  }, [renaming])

  if (!node) return null

  const Icon = ICONS[node.type]
  const isContainer = node.type === "frame" || node.type === "group"

  const zoneFor = (e: DragEvent<HTMLDivElement>): DropZone => {
    const rect = e.currentTarget.getBoundingClientRect()
    const ratio = (e.clientY - rect.top) / rect.height
    if (ratio < 0.25) return "above"
    if (ratio > 0.75) return "below"
    if (isContainer) return "inside"
    return ratio < 0.5 ? "above" : "below"
  }

  const handleClick = (e: MouseEvent<HTMLDivElement>) => {
    if (e.shiftKey) toggleSelection(id)
    else setSelection([id])
  }

  return (
    <div
      role="treeitem"
      aria-selected={selected}
      aria-expanded={isContainer && node.childIds.length > 0 ? !collapsed : undefined}
      draggable={!renaming}
      onDragStart={(e) => {
        e.dataTransfer.effectAllowed = "move"
        e.dataTransfer.setData("text/plain", id)
        onDragStart()
      }}
      onDragOver={(e) => {
        e.preventDefault()
        e.dataTransfer.dropEffect = "move"
        onDragOver(zoneFor(e))
      }}
      onDrop={(e) => {
        e.preventDefault()
        onDrop(zoneFor(e))
      }}
      onClick={handleClick}
      onDoubleClick={() => setRenaming(true)}
      onPointerEnter={() => setHovered(id)}
      onPointerLeave={() => setHovered(null)}
      className={cn(
        "group relative flex h-7 cursor-default items-center gap-1 pr-1 text-xs",
        selected ? "bg-accent text-accent-foreground" : "hover:bg-muted",
        node.hidden && "text-muted-foreground",
      )}
      style={{ paddingLeft: 4 + depth * 14 }}
    >
      {dropZone === "above" && <div className="absolute inset-x-0 top-0 h-0.5 bg-primary" />}
      {dropZone === "below" && <div className="absolute inset-x-0 bottom-0 h-0.5 bg-primary" />}
      {dropZone === "inside" && <div className="absolute inset-0 ring-1 ring-primary" />}
      {flashId !== 0 && <span key={flashId} aria-hidden="true" className="pointer-events-none absolute inset-0 animate-agent-flash" style={{ backgroundColor: "color-mix(in oklab, var(--selection) 25%, transparent)" }} />}

      <button
        type="button"
        aria-label={collapsed ? "Expand" : "Collapse"}
        className={cn(
          "flex size-4 shrink-0 items-center justify-center text-muted-foreground transition-colors active:scale-90 hover:text-foreground",
          (!isContainer || node.childIds.length === 0) && "invisible",
        )}
        onClick={(e) => {
          e.stopPropagation()
          onToggleCollapsed(id)
        }}
      >
        <ChevronRight className={cn("size-3 transition-transform duration-150", !collapsed && "rotate-90")} />
      </button>

      <Icon className="size-3.5 shrink-0 text-muted-foreground" />

      <span
        ref={nameRef}
        contentEditable={renaming ? "plaintext-only" : false}
        suppressContentEditableWarning
        aria-label={renaming ? "Layer name" : undefined}
        role={renaming ? "textbox" : undefined}
        className="min-w-0 flex-1 truncate outline-none"
        onClick={(e) => {
          if (renaming) e.stopPropagation()
        }}
        onDoubleClick={(e) => {
          if (renaming) e.stopPropagation()
        }}
        onKeyDown={(e) => {
          if (!renaming) return
          e.stopPropagation()
          if (e.nativeEvent.isComposing) return
          if (e.key === "Escape") {
            e.preventDefault()
            cancelRename.current = true
            e.currentTarget.blur()
          } else if (e.key === "Enter") {
            e.preventDefault()
            e.currentTarget.blur()
          }
        }}
        onBlur={(e) => {
          if (!renaming) return
          if (!cancelRename.current) renameNode(id, e.currentTarget.textContent ?? "")
          e.currentTarget.textContent = useEditor.getState().doc.nodes[id]?.name ?? node.name
          cancelRename.current = false
          setRenaming(false)
        }}
      >
        {node.name}
      </span>

      <button
        type="button"
        aria-label={node.hidden ? "Show layer" : "Hide layer"}
        className={cn("flex size-5 shrink-0 items-center justify-center transition-transform hover:bg-background active:scale-90", !node.hidden && "invisible group-hover:visible")}
        onClick={(e) => {
          e.stopPropagation()
          toggleHidden(id)
        }}
      >
        {node.hidden ? <EyeOff className="size-3" /> : <Eye className="size-3" />}
      </button>
      <button
        type="button"
        aria-label={node.locked ? "Unlock layer" : "Lock layer"}
        className={cn("flex size-5 shrink-0 items-center justify-center transition-transform hover:bg-background active:scale-90", !node.locked && "invisible group-hover:visible")}
        onClick={(e) => {
          e.stopPropagation()
          toggleLocked(id)
        }}
      >
        {node.locked ? <Lock className="size-3" /> : <LockOpen className="size-3" />}
      </button>
    </div>
  )
}
