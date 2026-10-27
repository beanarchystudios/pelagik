import { ChevronDown, ChevronRight, Circle, Eye, EyeOff, Frame, Group, Lock, LockOpen, Square, Type, type LucideIcon } from "lucide-react"
import { useMemo, useRef, useState, type DragEvent, type MouseEvent } from "react"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "cn"
import type { NodeType } from "../model/types"
import { dropLayers, renameNode, toggleHidden, toggleLocked, type DropZone } from "../state/commands"
import { useEditor } from "../state/store"

const ICONS: Record<NodeType, LucideIcon> = {
  frame: Frame,
  group: Group,
  rectangle: Square,
  ellipse: Circle,
  text: Type,
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

      <button
        type="button"
        aria-label={collapsed ? "Expand" : "Collapse"}
        className={cn("flex size-4 shrink-0 items-center justify-center", !isContainer || node.childIds.length === 0 ? "invisible" : "hover:bg-background")}
        onClick={(e) => {
          e.stopPropagation()
          onToggleCollapsed(id)
        }}
      >
        {collapsed ? <ChevronRight className="size-3" /> : <ChevronDown className="size-3" />}
      </button>

      <Icon className="size-3.5 shrink-0 text-muted-foreground" />

      {renaming ? (
        <Input
          autoFocus
          defaultValue={node.name}
          aria-label="Layer name"
          className="h-5 min-w-0 flex-1 px-1 text-xs"
          onFocus={(e) => e.currentTarget.select()}
          onClick={(e) => e.stopPropagation()}
          onDoubleClick={(e) => e.stopPropagation()}
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              cancelRename.current = true
              e.currentTarget.blur()
            } else if (e.key === "Enter") {
              e.currentTarget.blur()
            }
          }}
          onBlur={(e) => {
            if (!cancelRename.current) renameNode(id, e.currentTarget.value)
            cancelRename.current = false
            setRenaming(false)
          }}
        />
      ) : (
        <span className="min-w-0 flex-1 truncate">{node.name}</span>
      )}

      <button
        type="button"
        aria-label={node.hidden ? "Show layer" : "Hide layer"}
        className={cn("flex size-5 shrink-0 items-center justify-center hover:bg-background", !node.hidden && "invisible group-hover:visible")}
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
        className={cn("flex size-5 shrink-0 items-center justify-center hover:bg-background", !node.locked && "invisible group-hover:visible")}
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
