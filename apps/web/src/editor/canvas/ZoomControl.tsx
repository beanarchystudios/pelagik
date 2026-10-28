import { ChevronDown } from "lucide-react"
import { Button } from "@pelagik/ui/components/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuTrigger,
} from "@pelagik/ui/components/dropdown-menu"
import { MOD_KEY, SHIFT_KEY } from "../platform"
import { zoomBy, zoomTo, zoomToFit, zoomToSelection } from "../state/commands"
import { useEditor } from "../state/store"

const ZOOM_STEP = 1.25

export function ZoomControl() {
  const zoom = useEditor((s) => s.viewport.zoom)

  return (
    <div role="group" aria-label="Canvas zoom">
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="sm" className="h-7 gap-1 rounded-md px-2 text-xs tabular-nums text-muted-foreground hover:text-foreground" aria-label="Zoom level">
            {Math.round(zoom * 100)}%
            <ChevronDown aria-hidden="true" className="size-3 opacity-60" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-64 bg-sidebar">
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
    </div>
  )
}
