import type { ReactNode } from "react"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Kbd, KbdGroup } from "@/components/ui/kbd"
import { MOD_KEY, SHIFT_KEY } from "../platform"
import { useEditor } from "../state/store"

const SECTIONS: { title: string; rows: { label: string; keys: string[] }[] }[] = [
  {
    title: "Tools",
    rows: [
      { label: "Move", keys: ["V"] },
      { label: "Frame", keys: ["F"] },
      { label: "Rectangle", keys: ["R"] },
      { label: "Ellipse", keys: ["O"] },
      { label: "Text", keys: ["T"] },
      { label: "Hand (pan)", keys: ["H"] },
      { label: "Pan while held", keys: ["Space", "drag"] },
    ],
  },
  {
    title: "Edit",
    rows: [
      { label: "Undo", keys: [MOD_KEY, "Z"] },
      { label: "Redo", keys: [SHIFT_KEY, MOD_KEY, "Z"] },
      { label: "Copy / Paste", keys: [MOD_KEY, "C / V"] },
      { label: "Duplicate", keys: [MOD_KEY, "D"] },
      { label: "Delete", keys: ["Backspace", "Del"] },
      { label: "Select all", keys: [MOD_KEY, "A"] },
      { label: "Nudge", keys: ["Arrow"] },
      { label: "Nudge 10px", keys: [SHIFT_KEY, "Arrow"] },
      { label: "Edit text", keys: ["Double-click"] },
    ],
  },
  {
    title: "Arrange",
    rows: [
      { label: "Group", keys: [MOD_KEY, "G"] },
      { label: "Ungroup", keys: [SHIFT_KEY, MOD_KEY, "G"] },
      { label: "Bring forward", keys: [MOD_KEY, "]"] },
      { label: "Send backward", keys: [MOD_KEY, "["] },
      { label: "Bring to front", keys: [SHIFT_KEY, MOD_KEY, "]"] },
      { label: "Send to back", keys: [SHIFT_KEY, MOD_KEY, "["] },
    ],
  },
  {
    title: "View",
    rows: [
      { label: "Zoom in / out", keys: [MOD_KEY, "+ / −"] },
      { label: "Zoom to fit", keys: [SHIFT_KEY, "1"] },
      { label: "Zoom to selection", keys: [SHIFT_KEY, "2"] },
      { label: "Zoom to 100%", keys: [SHIFT_KEY, "0"] },
      { label: "Zoom with wheel", keys: [MOD_KEY, "Wheel"] },
    ],
  },
]

export function ShortcutsDialog() {
  const open = useEditor((s) => s.helpOpen)
  const setOpen = useEditor((s) => s.setHelpOpen)

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Keyboard shortcuts</DialogTitle>
          <DialogDescription>Press ? at any time to open this list.</DialogDescription>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-x-8 gap-y-6">
          {SECTIONS.map((section) => (
            <div key={section.title} className="flex flex-col gap-2">
              <h3 className="text-xs font-medium text-muted-foreground uppercase">{section.title}</h3>
              {section.rows.map((row) => (
                <ShortcutRow key={row.label} label={row.label}>
                  <KbdGroup>
                    {row.keys.map((key) => (
                      <Kbd key={key}>{key}</Kbd>
                    ))}
                  </KbdGroup>
                </ShortcutRow>
              ))}
            </div>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}

function ShortcutRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 text-sm">
      <span>{label}</span>
      {children}
    </div>
  )
}
