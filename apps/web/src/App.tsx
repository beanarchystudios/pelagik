import { useEffect, useState } from "react"
import { TooltipProvider } from "@pelagik/ui/components/tooltip"
import { startAgentAutoConnect } from "./editor/agent/connection"
import { Dashboard } from "./editor/Dashboard"
import { Editor } from "./editor/Editor"
import { useKeyboardShortcuts } from "./editor/hooks/useKeyboardShortcuts"
import { closeDesign, openDesign, startDesignAutosave } from "./editor/state/design-session"
import type { DesignRecord } from "./editor/state/designs"

function EditorScreen({ onBack }: { onBack: () => void }) {
  useKeyboardShortcuts()
  useEffect(() => startAgentAutoConnect(), [])
  return <Editor onBack={onBack} />
}

export default function App() {
  const [editing, setEditing] = useState(false)
  const [error, setError] = useState("")
  useEffect(() => startDesignAutosave(), [])

  function open(record: DesignRecord) {
    openDesign(record)
    setError("")
    setEditing(true)
  }

  async function back() {
    try { await closeDesign(); setEditing(false); setError("") }
    catch { setError("Could not save this design. Check your browser storage and try again.") }
  }

  return (
    <TooltipProvider delayDuration={300}>
      {editing ? <><EditorScreen onBack={() => void back()} />{error && <div role="alert" className="fixed bottom-4 left-1/2 z-50 -translate-x-1/2 rounded-md border bg-background p-3 text-sm text-destructive shadow-lg">{error}</div>}</> : <Dashboard onOpen={open} />}
    </TooltipProvider>
  )
}
