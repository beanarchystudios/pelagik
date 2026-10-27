import { Circle, Frame, Hand, MousePointer2, Square, Type, type LucideIcon } from "lucide-react"
import { Kbd } from "@/components/ui/kbd"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import type { Tool } from "../model/types"
import { setTool } from "../state/commands"
import { useEditor } from "../state/store"

const TOOLS: { value: Tool; label: string; key: string; icon: LucideIcon }[] = [
  { value: "select", label: "Move", key: "V", icon: MousePointer2 },
  { value: "frame", label: "Frame", key: "F", icon: Frame },
  { value: "rectangle", label: "Rectangle", key: "R", icon: Square },
  { value: "ellipse", label: "Ellipse", key: "O", icon: Circle },
  { value: "text", label: "Text", key: "T", icon: Type },
  { value: "hand", label: "Hand", key: "H", icon: Hand },
]

export function Toolbar() {
  const tool = useEditor((s) => s.tool)

  return (
    <div className="absolute top-1/2 left-3 z-10 -translate-y-1/2">
      <ToggleGroup
        type="single"
        variant="ghost"
        orientation="vertical"
        value={tool}
        onValueChange={(value) => {
          if (value) setTool(value as Tool)
        }}
        className="rounded-lg bg-sidebar p-1 shadow-sm"
      >
        {TOOLS.map(({ value, label, key, icon: Icon }) => (
          <Tooltip key={value}>
            <TooltipTrigger asChild>
              <ToggleGroupItem
                value={value}
                aria-label={label}
                className="size-8 p-0 aria-pressed:bg-muted aria-pressed:text-foreground data-[state=on]:bg-muted data-[state=on]:text-foreground"
              >
                <Icon />
              </ToggleGroupItem>
            </TooltipTrigger>
            <TooltipContent side="right" className="flex items-center gap-2">
              {label} <Kbd>{key}</Kbd>
            </TooltipContent>
          </Tooltip>
        ))}
      </ToggleGroup>
    </div>
  )
}
