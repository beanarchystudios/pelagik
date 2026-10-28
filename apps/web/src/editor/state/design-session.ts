import { canonicalDesign } from "@pelagik/design-spec/document"
import { designsDb, readDesign, type DesignRecord } from "./designs"
import { useEditor } from "./store"

let active: DesignRecord | null = null
let timer: ReturnType<typeof setTimeout> | undefined
let pending = Promise.resolve()
let saveError: unknown

function enqueueSave() {
  if (!active) return pending
  const state = useEditor.getState()
  const record = { ...active, name: state.name, spec: state.spec, updatedAt: Date.now() }
  active = record
  pending = pending.catch(() => {}).then(() => designsDb.designs.put(record)).then(() => { saveError = undefined }, (error: unknown) => { saveError = error })
  return pending
}

export function startDesignAutosave() {
  const unsubscribe = useEditor.subscribe((state, previous) => {
    if (!active || (state.spec === previous.spec && state.name === previous.name)) return
    clearTimeout(timer)
    timer = setTimeout(() => { void enqueueSave() }, 300)
  })
  const onPageHide = () => { clearTimeout(timer); void enqueueSave() }
  window.addEventListener("pagehide", onPageHide)
  return () => { window.removeEventListener("pagehide", onPageHide); clearTimeout(timer); void enqueueSave(); unsubscribe() }
}

export async function flushDesign() {
  clearTimeout(timer)
  if (active) await enqueueSave()
  else await pending
  if (saveError) throw saveError
}

export function openDesign(record: DesignRecord) {
  const doc = readDesign(record)
  active = null
  useEditor.setState({
    ...canonicalDesign(doc), name: record.name, past: [], future: [], selectedIds: [], hoveredId: null,
    tool: "select", viewport: { x: 0, y: 0, zoom: 1 }, spaceHeld: false, editingId: null,
    editStart: null, marquee: null, clipboard: null, lastEdit: null, agentEdit: null,
    helpOpen: false, iconPickerOpen: false, shaderPickerOpen: false,
  })
  active = record
}

export async function closeDesign() {
  await flushDesign()
  active = null
}
