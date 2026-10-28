import { useEffect } from "react"
import { Waves, X } from "lucide-react"
import { Button } from "@pelagik/ui/components/button"
import { activeAgentEdit, useEditor } from "../state/store"

/** The notice fades on its own so it doesn't linger after the agent is done. */
const AUTO_HIDE_MS = 8000

/** Floating notice after an agent edit. Undo steps back exactly one agent edit, the same as Cmd+Z. */
export function AgentActivity() {
  const edit = useEditor(activeAgentEdit)
  const editing = useEditor((s) => s.editingId !== null)
  const undo = useEditor((s) => s.undo)
  const dismiss = useEditor((s) => s.dismissAgentEdit)
  const editId = edit?.id

  useEffect(() => {
    if (editId === undefined) return
    const timer = window.setTimeout(dismiss, AUTO_HIDE_MS)
    return () => window.clearTimeout(timer)
  }, [editId, dismiss])

  if (!edit) return null
  const count = edit.ids.length

  return (
    <div
      role="status"
      className="absolute top-3 left-1/2 z-10 flex -translate-x-1/2 animate-in items-center gap-1.5 rounded-full border bg-sidebar py-1 pr-1 pl-3 text-xs shadow-md fade-in slide-in-from-top-2 duration-300"
    >
      <Waves className="size-3.5 shrink-0 text-selection" />
      <span className="whitespace-nowrap">
        Agent edited <span className="font-mono">{count}</span> {count === 1 ? "layer" : "layers"}
      </span>
      <Button variant="ghost" size="xs" className="rounded-full" disabled={editing} onClick={() => undo()}>
        Undo
      </Button>
      <Button variant="ghost" size="icon-xs" aria-label="Dismiss" className="rounded-full" onClick={() => dismiss()}>
        <X />
      </Button>
    </div>
  )
}
