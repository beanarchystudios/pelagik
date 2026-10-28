import { documentToSpec, specToDocument } from "@pelagik/design-spec/document"
import type { Document } from "@pelagik/design-core/types"
import { snapNodeToPixels } from "@pelagik/design-core/pixels"

// Keep the original key so existing documents survive the app rename.
const STORAGE_KEY = "d3sign:file:v1"

export interface SavedFile {
  name: string
  doc: Document
}

export function loadSavedFile(): SavedFile | null {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw)
    if (parsed.format === "pelagik/json-render" && parsed.version === 1) {
      return { name: typeof parsed.name === "string" ? parsed.name : "Untitled", doc: specToDocument(parsed.spec) }
    }
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
      snapNodeToPixels({ ...node, fontFamily: node.fontFamily ?? "DM Sans Variable", bindings: colorBindings, flex: node.flex ?? null, shader: node.shader ?? null }),
    ]
  }))
  return { ...doc, nodes, variables }
}

export function saveFile(file: SavedFile): boolean {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ format: "pelagik/json-render", version: 1, name: file.name, spec: documentToSpec(file.doc) }))
    return true
  } catch {
    // Storage can be full or disabled. The in-memory document still works.
    return false
  }
}
