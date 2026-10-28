import { useEffect } from "react"
import { ArrowLeft } from "lucide-react"
import { Input } from "@pelagik/ui/components/input"
import { AgentDialog } from "../agent/AgentDialog"
import { ZoomControl } from "../canvas/ZoomControl"
import { useEditor } from "../state/store"
import { syncThemeWithSystem } from "../theme"

export function LeftSidebarHeader({ onBack }: { onBack: () => void }) {
  const name = useEditor((s) => s.name)
  const setName = useEditor((s) => s.setName)

  return (
    <header className="flex h-9 shrink-0 items-center gap-1 border-b border-border/70 bg-sidebar px-2.5">
      <button type="button" onClick={onBack} aria-label="Back to designs" className="flex size-6 shrink-0 items-center justify-center rounded text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring">
        <ArrowLeft className="size-4" />
      </button>
      <Input
        aria-label="File name"
        value={name}
        onChange={(event) => setName(event.target.value)}
        className="h-7 min-w-0 flex-1 truncate border-transparent bg-transparent px-2 text-xs font-medium shadow-none hover:border-border/60 hover:bg-muted/40 focus-visible:border-input focus-visible:ring-0 dark:bg-transparent"
      />
    </header>
  )
}

export function RightSidebarHeader() {
  useEffect(() => syncThemeWithSystem(), [])

  return (
    <header className="flex h-9 shrink-0 items-center justify-end gap-0.5 border-b border-border/70 bg-sidebar px-2">
      <ZoomControl />
      <AgentDialog />
    </header>
  )
}
