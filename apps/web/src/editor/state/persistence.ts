import type { Document } from "../model/types"
import { snapNodeToPixels } from "../model/pixels"

const STORAGE_KEY = "d3sign:file:v1"

export interface SavedFile {
  name: string
  doc: Document
}

export function loadSavedFile(): SavedFile | null {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as Partial<SavedFile>
    const doc = parsed.doc
    if (!doc || typeof doc !== "object" || !("nodes" in doc) || !Array.isArray(doc.rootIds)) return null
    return { name: typeof parsed.name === "string" ? parsed.name : "Untitled", doc: upgradeDocument(doc) }
  } catch {
    return null
  }
}

/** Fills in fields added after a file was saved and removes numeric variables from older files. */
function upgradeDocument(doc: Document): Document {
  const variables = Object.fromEntries(
    Object.entries(doc.variables ?? {}).filter(([, variable]) => variable.type === "color"),
  )
  const nodes = Object.fromEntries(Object.entries(doc.nodes).map(([id, node]) => {
    const bindings = node.bindings ?? {}
    const colorBindings = {
      ...(typeof bindings.fill === "string" && variables[bindings.fill] ? { fill: bindings.fill } : {}),
      ...(typeof bindings.stroke === "string" && variables[bindings.stroke] ? { stroke: bindings.stroke } : {}),
    }
    return [
      id,
      snapNodeToPixels({ ...node, bindings: colorBindings, flex: node.flex ?? null }),
    ]
  }))
  return { ...doc, nodes, variables }
}

export function saveFile(file: SavedFile): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(file))
  } catch {
    // Storage can be full or disabled. The in-memory document still works.
  }
}
