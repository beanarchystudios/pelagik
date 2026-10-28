import { useLayoutEffect, useRef, useState } from "react"
import { Circle, Frame, Hand, Image, MousePointer2, Shapes, Sparkles, Square, Type, type LucideIcon } from "lucide-react"
import { Button } from "@pelagik/ui/components/button"
import { Kbd } from "@pelagik/ui/components/kbd"
import { ToggleGroup, ToggleGroupItem } from "@pelagik/ui/components/toggle-group"
import { Tooltip, TooltipContent, TooltipTrigger } from "@pelagik/ui/components/tooltip"
import type { Tool } from "@pelagik/design-core/types"
import { insertImages } from "../state/images"
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
  const setIconPickerOpen = useEditor((s) => s.setIconPickerOpen)
  const setShaderPickerOpen = useEditor((s) => s.setShaderPickerOpen)
  const imageInputRef = useRef<HTMLInputElement>(null)
  const groupRef = useRef<HTMLDivElement>(null)
  // Where the sliding highlight sits behind the active tool, measured from the group's top edge.
  const [highlight, setHighlight] = useState<{ top: number; height: number } | null>(null)

  // Measure after layout so the highlight lands on the active tool before paint. Keyboard shortcuts change `tool` too.
  useLayoutEffect(() => {
    const group = groupRef.current
    // aria-checked, not data-state: the tooltip trigger overwrites data-state on each item.
    const active = group?.querySelector<HTMLElement>('[aria-checked="true"]')
    if (!group || !active) return
    const origin = group.getBoundingClientRect().top
    const rect = active.getBoundingClientRect()
    setHighlight({ top: rect.top - origin, height: rect.height })
  }, [tool])

  return (
    <div className="absolute top-1/2 left-3 z-10 flex -translate-y-1/2 flex-col gap-1 rounded-xl border bg-sidebar p-1 shadow-[inset_0_1px_0_var(--tactile-highlight),0_2px_0_var(--tactile-lip),0_8px_20px_rgba(0,0,0,0.18)]">
      <div ref={groupRef} className="relative flex flex-col gap-0.5">
        {/* One highlight slides between tools instead of each tool owning its own pressed state. */}
        {highlight && (
          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-x-0 rounded-lg bg-[var(--tactile-pressed)] shadow-[inset_0_1px_3px_var(--tactile-inset)] transition-[top,height] duration-200 ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none"
            style={{ top: highlight.top, height: highlight.height }}
          />
        )}
        <ToggleGroup
          type="single"
          variant="ghost"
          orientation="vertical"
          value={tool}
          onValueChange={(value) => {
            if (value) setTool(value as Tool)
          }}
        >
          {TOOLS.map(({ value, label, key, icon: Icon }) => (
            <Tooltip key={value}>
              <TooltipTrigger asChild>
                <ToggleGroupItem
                  value={value}
                  aria-label={label}
                  className="relative z-10 size-8 p-0 text-muted-foreground aria-checked:translate-y-0 aria-checked:bg-transparent aria-checked:text-selection aria-checked:shadow-none"
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
        <input ref={imageInputRef} type="file" accept="image/png,image/jpeg,image/gif,image/webp" multiple className="hidden" onChange={(e) => { void insertImages(Array.from(e.target.files ?? [])); e.target.value = "" }} />
        <Tooltip>
          <TooltipTrigger asChild><Button variant="ghost" size="icon" aria-label="Insert image" className="size-8 text-muted-foreground" onClick={() => imageInputRef.current?.click()}><Image /></Button></TooltipTrigger>
          <TooltipContent side="right">Insert image</TooltipContent>
        </Tooltip>
        {/* An action rather than a tool: it opens the picker and never joins the tool highlight. */}
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon" aria-label="Insert icon" className="size-8 text-muted-foreground" onClick={() => setIconPickerOpen(true)}>
              <Shapes />
            </Button>
          </TooltipTrigger>
          <TooltipContent side="right" className="flex items-center gap-2">
            Insert icon <Kbd>I</Kbd>
          </TooltipContent>
        </Tooltip>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon" aria-label="Shaders" className="size-8 text-muted-foreground" onClick={() => setShaderPickerOpen(true)}>
              <Sparkles />
            </Button>
          </TooltipTrigger>
          <TooltipContent side="right">Shaders</TooltipContent>
        </Tooltip>
      </div>
    </div>
  )
}
