import { startAgentAutoConnect } from "./editor/agent/connection"
import { useEffect } from "react"
import { TooltipProvider } from "@pelagik/ui/components/tooltip"
import { Editor } from "./editor/Editor"
import { useKeyboardShortcuts } from "./editor/hooks/useKeyboardShortcuts"
import { startAutosave } from "./editor/state/autosave"

export default function App() {
  useKeyboardShortcuts()
  useEffect(() => startAutosave(), [])
  useEffect(() => startAgentAutoConnect(), [])

  return (
    <TooltipProvider delayDuration={300}>
      <Editor />
    </TooltipProvider>
  )
}
