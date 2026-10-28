import { useRef, useState } from "react"
import { applyOperations } from "@pelagik/agent-api/edits"
import { operation } from "@pelagik/agent-api/schema"
import { topmostIds } from "@pelagik/design-core/document"
import { documentToSpec } from "@pelagik/design-spec/document"
import { Button } from "@pelagik/ui/components/button"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@pelagik/ui/components/dialog"
import { useEditor } from "../state/store"
import type { Document } from "@pelagik/design-core/types"

export function DesignJsonDialog() {
  const [open, setOpen] = useState(false)
  const [json, setJson] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const snapshot = useRef<Document | null>(null)
  const textarea = useRef<HTMLTextAreaElement>(null)
  function readDocument() {
    const s = useEditor.getState()
    snapshot.current = s.doc
    setError(null); setMessage(null)
    try { setJson(JSON.stringify(documentToSpec(s.doc, s.selectedIds.length ? topmostIds(s.doc, s.selectedIds) : s.doc.rootIds), null, 2)) }
    catch (cause) { setJson(""); setError(cause instanceof Error ? cause.message : "Cannot export this design") }
  }
  return (
    <Dialog open={open} onOpenChange={value => { if (value) readDocument(); setOpen(value) }}>
      <DialogTrigger asChild><Button variant="ghost" size="sm">Design JSON</Button></DialogTrigger>
      <DialogContent className="sm:max-w-3xl">
        <DialogHeader>
          <DialogTitle>Design JSON</DialogTitle>
          <DialogDescription>Edit a Pelagik json-render spec, then insert it as editable layers. Selected layers are exported when a selection exists. Existing layers stay in place.</DialogDescription>
        </DialogHeader>
        <textarea
          ref={textarea} aria-label="json-render design spec" spellCheck={false}
          className="h-[50vh] min-h-48 w-full resize-y rounded-md border bg-background p-3 font-mono text-xs"
          value={json} onChange={event => { setJson(event.target.value); setError(null); setMessage(null) }}
        />
        {error && <p role="alert" className="text-sm text-destructive">{error}</p>}
        {message && <p role="status" className="text-sm text-muted-foreground">{message}</p>}
        <div className="flex flex-wrap justify-end gap-2">
          <Button variant="outline" onClick={readDocument}>Read current design</Button>
          <Button variant="outline" onClick={() => { textarea.current?.focus(); textarea.current?.select(); setMessage("JSON selected. Use your copy shortcut to copy it.") }}>Select JSON</Button>
          <Button onClick={() => {
            setError(null); setMessage(null)
            try {
              const s = useEditor.getState()
              if (s.editingId || s.doc !== snapshot.current) throw new Error("The design changed while this dialog was open. Read the current design before inserting.")
              if (json.length > 1_048_576) throw new Error("Design JSON must be smaller than 1 MiB")
              const edit = operation.parse({ op: "insert_spec", spec: JSON.parse(json) })
              const result = applyOperations(s.doc, [edit])
              for (const node of Object.values(result.doc.nodes)) {
                for (const color of [node.fill, node.stroke]) if (color !== null && !CSS.supports("color", color)) throw new Error(`Invalid CSS color ${color}`)
              }
              for (const variable of Object.values(result.doc.variables)) if (!CSS.supports("color", variable.value)) throw new Error(`Invalid CSS color ${variable.value}`)
              s.commit(result.doc)
              s.setSelection(result.imports[0].rootIds)
              setOpen(false)
            } catch (cause) { setError(cause instanceof Error ? cause.message : "Invalid design spec") }
          }}>Insert as layers</Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
