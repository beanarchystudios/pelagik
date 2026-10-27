import { useEffect } from "react"
import { TooltipProvider } from "@/components/ui/tooltip"
import { Editor } from "./editor/Editor"
import { useKeyboardShortcuts } from "./editor/hooks/useKeyboardShortcuts"
import { startAutosave } from "./editor/state/autosave"

export default function App() {
  useKeyboardShortcuts()
  useEffect(() => startAutosave(), [])

  return (
    <TooltipProvider delayDuration={300}>
      <Editor />
    </TooltipProvider>
  )
}
