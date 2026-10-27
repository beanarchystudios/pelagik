import { Minus, Plus } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { MOD_KEY, SHIFT_KEY } from "../platform"
import { zoomBy, zoomTo, zoomToFit, zoomToSelection } from "../state/commands"
import { useEditor } from "../state/store"

const ZOOM_STEP = 1.25

export function ZoomControl() {
  const zoom = useEditor((s) => s.viewport.zoom)

  return (
    <div className="absolute bottom-3 left-3 z-10 flex items-center gap-0.5 rounded-md border bg-background p-0.5 shadow-sm">
      <Button variant="ghost" size="icon-sm" aria-label="Zoom out" onClick={() => zoomBy(1 / ZOOM_STEP)}>
        <Minus />
      </Button>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="sm" className="w-16 tabular-nums" aria-label="Zoom level">
            {Math.round(zoom * 100)}%
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="w-64">
          <DropdownMenuItem onSelect={() => zoomBy(ZOOM_STEP)}>
            Zoom in
            <DropdownMenuShortcut>{MOD_KEY} +</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => zoomBy(1 / ZOOM_STEP)}>
            Zoom out
            <DropdownMenuShortcut>{MOD_KEY} −</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem onSelect={() => zoomToFit()}>
            Zoom to fit
            <DropdownMenuShortcut>{SHIFT_KEY} 1</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => zoomToSelection()}>
            Zoom to selection
            <DropdownMenuShortcut>{SHIFT_KEY} 2</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem onSelect={() => zoomTo(0.5)}>Zoom to 50%</DropdownMenuItem>
          <DropdownMenuItem onSelect={() => zoomTo(1)}>
            Zoom to 100%
            <DropdownMenuShortcut>{SHIFT_KEY} 0</DropdownMenuShortcut>
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => zoomTo(2)}>Zoom to 200%</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
      <Button variant="ghost" size="icon-sm" aria-label="Zoom in" onClick={() => zoomBy(ZOOM_STEP)}>
        <Plus />
      </Button>
    </div>
  )
}
