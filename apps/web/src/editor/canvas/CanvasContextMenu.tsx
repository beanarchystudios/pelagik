import type { ReactNode } from "react"
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuShortcut,
  ContextMenuSub,
  ContextMenuSubContent,
  ContextMenuSubTrigger,
  ContextMenuTrigger,
} from "@/components/ui/context-menu"
import {
  alignSelection,
  copySelection,
  deleteSelection,
  duplicateSelection,
  groupSelection,
  pasteClipboard,
  reorderSelection,
  selectAll,
  ungroupSelection,
} from "../state/commands"
import { useEditor } from "../state/store"
import { MOD_KEY, SHIFT_KEY } from "../platform"

export function CanvasContextMenu({ children }: { children: ReactNode }) {
  const hasSelection = useEditor((s) => s.selectedIds.length > 0)
  const hasNodes = useEditor((s) => s.doc.rootIds.length > 0)
  const hasClipboard = useEditor((s) => s.clipboard !== null)

  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>{children}</ContextMenuTrigger>
      <ContextMenuContent className="w-60">
        <ContextMenuItem disabled={!hasSelection} onSelect={() => copySelection()}>
          Copy
          <ContextMenuShortcut>{MOD_KEY} C</ContextMenuShortcut>
        </ContextMenuItem>
        <ContextMenuItem disabled={!hasClipboard} onSelect={() => pasteClipboard()}>
          Paste
          <ContextMenuShortcut>{MOD_KEY} V</ContextMenuShortcut>
        </ContextMenuItem>
        <ContextMenuItem disabled={!hasSelection} onSelect={() => duplicateSelection()}>
          Duplicate
          <ContextMenuShortcut>{MOD_KEY} D</ContextMenuShortcut>
        </ContextMenuItem>
        <ContextMenuItem disabled={!hasSelection} variant="destructive" onSelect={() => deleteSelection()}>
          Delete
          <ContextMenuShortcut>⌫</ContextMenuShortcut>
        </ContextMenuItem>
        <ContextMenuSeparator />
        <ContextMenuItem disabled={!hasSelection} onSelect={() => groupSelection()}>
          Group selection
          <ContextMenuShortcut>{MOD_KEY} G</ContextMenuShortcut>
        </ContextMenuItem>
        <ContextMenuItem disabled={!hasSelection} onSelect={() => ungroupSelection()}>
          Ungroup
          <ContextMenuShortcut>{SHIFT_KEY} {MOD_KEY} G</ContextMenuShortcut>
        </ContextMenuItem>
        <ContextMenuSeparator />
        <ContextMenuSub>
          <ContextMenuSubTrigger disabled={!hasSelection}>Arrange</ContextMenuSubTrigger>
          <ContextMenuSubContent className="w-56">
            <ContextMenuItem onSelect={() => reorderSelection("front")}>
              Bring to front
              <ContextMenuShortcut>{SHIFT_KEY} {MOD_KEY} ]</ContextMenuShortcut>
            </ContextMenuItem>
            <ContextMenuItem onSelect={() => reorderSelection("forward")}>
              Bring forward
              <ContextMenuShortcut>{MOD_KEY} ]</ContextMenuShortcut>
            </ContextMenuItem>
            <ContextMenuItem onSelect={() => reorderSelection("backward")}>
              Send backward
              <ContextMenuShortcut>{MOD_KEY} [</ContextMenuShortcut>
            </ContextMenuItem>
            <ContextMenuItem onSelect={() => reorderSelection("back")}>
              Send to back
              <ContextMenuShortcut>{SHIFT_KEY} {MOD_KEY} [</ContextMenuShortcut>
            </ContextMenuItem>
          </ContextMenuSubContent>
        </ContextMenuSub>
        <ContextMenuSub>
          <ContextMenuSubTrigger disabled={!hasSelection}>Align</ContextMenuSubTrigger>
          <ContextMenuSubContent className="w-56">
            <ContextMenuItem onSelect={() => alignSelection("left")}>Align left</ContextMenuItem>
            <ContextMenuItem onSelect={() => alignSelection("center")}>Align horizontal centers</ContextMenuItem>
            <ContextMenuItem onSelect={() => alignSelection("right")}>Align right</ContextMenuItem>
            <ContextMenuSeparator />
            <ContextMenuItem onSelect={() => alignSelection("top")}>Align top</ContextMenuItem>
            <ContextMenuItem onSelect={() => alignSelection("middle")}>Align vertical centers</ContextMenuItem>
            <ContextMenuItem onSelect={() => alignSelection("bottom")}>Align bottom</ContextMenuItem>
          </ContextMenuSubContent>
        </ContextMenuSub>
        <ContextMenuSeparator />
        <ContextMenuItem disabled={!hasNodes} onSelect={() => selectAll()}>
          Select all
          <ContextMenuShortcut>{MOD_KEY} A</ContextMenuShortcut>
        </ContextMenuItem>
      </ContextMenuContent>
    </ContextMenu>
  )
}
