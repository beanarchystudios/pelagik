import { saveFile } from "./persistence"
import { useEditor } from "./store"

const SAVE_DELAY_MS = 300

/** Saves the document to local storage after edits settle. Returns a cleanup function. */
export function startAutosave(): () => void {
  let timer: number | undefined

  const unsubscribe = useEditor.subscribe((state, previous) => {
    if (state.doc === previous.doc && state.name === previous.name) return
    window.clearTimeout(timer)
    timer = window.setTimeout(() => {
      const { doc, name } = useEditor.getState()
      saveFile({ name, doc })
    }, SAVE_DELAY_MS)
  })

  return () => {
    window.clearTimeout(timer)
    unsubscribe()
  }
}
