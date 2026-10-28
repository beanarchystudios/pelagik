import { useEffect, useState } from "react"
import { FilePlus2, FileText, Trash2, Waves } from "lucide-react"
import { emptyDocument } from "@pelagik/design-core/document"
import { documentToSpec } from "@pelagik/design-spec/document"
import { Button } from "@pelagik/ui/components/button"
import { designsDb, migrateLegacyDesign, type DesignRecord } from "./state/designs"
import { syncThemeWithSystem } from "./theme"

export function Dashboard({ onOpen }: { onOpen: (record: DesignRecord) => void }) {
  const [designs, setDesigns] = useState<DesignRecord[] | null>(null)
  const [error, setError] = useState("")
  const [busy, setBusy] = useState(false)

  async function refresh() {
    setDesigns(await designsDb.designs.orderBy("updatedAt").reverse().toArray())
  }
  useEffect(() => {
    const stopTheme = syncThemeWithSystem()
    void migrateLegacyDesign().then(refresh).catch(() => setError("Could not open local storage. Check your browser storage settings and try again."))
    return stopTheme
  }, [])

  async function createDesign() {
    setBusy(true)
    try {
      const now = Date.now()
      const record = { id: crypto.randomUUID(), name: "Untitled", spec: documentToSpec(emptyDocument()), createdAt: now, updatedAt: now }
      await designsDb.designs.add(record)
      onOpen(record)
    } catch { setError("Could not create the design. Check your browser storage and try again.") }
    finally { setBusy(false) }
  }

  async function removeDesign(record: DesignRecord) {
    if (!window.confirm(`Delete “${record.name || "Untitled"}”? This cannot be undone.`)) return
    try { await designsDb.designs.delete(record.id); await refresh() }
    catch { setError("Could not delete the design. Please try again.") }
  }

  return (
    <div className="min-h-dvh bg-background text-foreground">
      <header className="border-b bg-sidebar">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-2 px-6">
          <Waves className="size-5 text-selection" />
          <span className="text-sm font-semibold">Pelagik</span>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-6 py-12">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div><h1 className="text-2xl font-semibold tracking-tight">Your designs</h1><p className="mt-2 text-sm text-muted-foreground">Saved locally on this device.</p></div>
          <Button onClick={() => void createDesign()} disabled={busy || designs === null}><FilePlus2 /> New design</Button>
        </div>
        {error && <p role="alert" className="mt-6 text-sm text-destructive">{error}</p>}
        {designs === null ? <p className="mt-12 text-sm text-muted-foreground">Loading designs…</p> : designs.length === 0 ? (
          <div className="mt-10 rounded-lg border border-dashed p-12 text-center"><FileText className="mx-auto size-8 text-muted-foreground" /><p className="mt-4 font-medium">No designs yet</p><p className="mt-1 text-sm text-muted-foreground">Create a design to get started.</p></div>
        ) : (
          <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {designs.map((design) => <div key={design.id} className="group overflow-hidden rounded-lg border bg-card text-card-foreground">
              <button type="button" onClick={() => { try { onOpen(design) } catch { setError("This design could not be opened.") } }} className="flex w-full flex-col text-left focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-ring">
                <div className="flex h-36 w-full items-center justify-center bg-muted/50"><FileText className="size-8 text-muted-foreground/60" /></div>
                <div className="w-full px-4 pt-4"><p className="truncate text-sm font-medium">{design.name || "Untitled"}</p><p className="mt-1 text-xs text-muted-foreground">Edited {new Date(design.updatedAt).toLocaleString()}</p></div>
              </button>
              <div className="flex justify-end px-2 pb-2"><Button variant="ghost" size="icon" aria-label={`Delete ${design.name || "Untitled"}`} onClick={() => void removeDesign(design)}><Trash2 /></Button></div>
            </div>)}
          </div>
        )}
      </main>
    </div>
  )
}
