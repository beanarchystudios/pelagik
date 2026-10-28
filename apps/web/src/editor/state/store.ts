import { canonicalDesign, documentToSpec, specToDocument } from "@pelagik/design-spec/document"
import type { DesignSpec } from "@pelagik/design-spec/catalog"
import { create } from "zustand"
import { emptyDocument } from "@pelagik/design-core/document"
import type { Document, Fragment, Rect, Tool, Viewport } from "@pelagik/design-core/types"
import { loadSavedFile } from "./persistence"

const HISTORY_LIMIT = 200
/** Consecutive edits with the same key within this window merge into one undo step. */
const COALESCE_MS = 1000

export interface EditorState {
  /** Derived canvas projection. All writes pass through the json-render catalog. */
  doc: Document
  spec: DesignSpec
  name: string
  past: DesignSpec[]
  future: DesignSpec[]
  selectedIds: string[]
  hoveredId: string | null
  tool: Tool
  viewport: Viewport
  canvasSize: { width: number; height: number }
  spaceHeld: boolean
  /** Text node currently being edited inline. */
  editingId: string | null
  /** Document from before the edit began. Recorded to history when editing ends. */
  editStart: Document | null
  /** Marquee in page coordinates. */
  marquee: Rect | null
  clipboard: Fragment | null
  helpOpen: boolean
  iconPickerOpen: boolean
  shaderPickerOpen: boolean
  lastEdit: { key: string; at: number } | null
  /** Latest agent edit. Lives outside the document, so it never enters history or saves. See `activeAgentEdit`. */
  agentEdit: AgentEdit | null
}

export interface AgentEdit {
  /** Increments per agent edit. Used as a key so the glow replays for each new edit. */
  id: number
  ids: string[]
  /** The `past` array right after the edit. Any later commit or undo replaces `past`, which retires this edit. */
  past: DesignSpec[]
}

export interface EditorActions {
  /** Replaces the document and records the previous one as an undo step. */
  commit: (next: Document, coalesceKey?: string) => void
  /** Replaces the document without touching history. Used while a gesture is in progress. */
  preview: (next: Document) => void
  /** Records `start` as an undo step if the document changed since the gesture began. */
  endGesture: (start: Document) => void
  undo: () => void
  redo: () => void
  setName: (name: string) => void
  setSelection: (ids: string[]) => void
  toggleSelection: (id: string) => void
  setHovered: (id: string | null) => void
  setTool: (tool: Tool) => void
  setViewport: (viewport: Viewport) => void
  setCanvasSize: (size: { width: number; height: number }) => void
  setSpaceHeld: (held: boolean) => void
  setMarquee: (rect: Rect | null) => void
  setClipboard: (fragment: Fragment | null) => void
  setHelpOpen: (open: boolean) => void
  setIconPickerOpen: (open: boolean) => void
  setShaderPickerOpen: (open: boolean) => void
  startEditing: (id: string, start: Document) => void
  stopEditing: () => void
  /** Call right after an agent commit. Only the activity UI reads this; history is unchanged. */
  markAgentEdit: (ids: string[]) => void
  dismissAgentEdit: () => void
}

/** The agent edit that is still the latest history step, or null once the user has edited or undone past it. */
export function activeAgentEdit(state: Pick<EditorState, "agentEdit" | "past">): AgentEdit | null {
  return state.agentEdit && state.agentEdit.past === state.past ? state.agentEdit : null
}

function pushHistory(past: DesignSpec[], doc: Document): DesignSpec[] {
  return [...past, documentToSpec(doc)].slice(-HISTORY_LIMIT)
}

/** Keeps only ids that still exist. Returns the same array when nothing was removed, to avoid re-renders. */
function keepExisting(doc: Document, ids: string[]): string[] {
  return ids.every((id) => doc.nodes[id]) ? ids : ids.filter((id) => doc.nodes[id])
}

const saved = loadSavedFile()
const initialDesign = canonicalDesign(saved?.doc ?? emptyDocument())

export const useEditor = create<EditorState & EditorActions>()((set, get) => ({
  ...initialDesign,
  name: saved?.name ?? "Untitled",
  past: [],
  future: [],
  selectedIds: [],
  hoveredId: null,
  tool: "select",
  viewport: { x: 0, y: 0, zoom: 1 },
  canvasSize: { width: 0, height: 0 },
  spaceHeld: false,
  editingId: null,
  editStart: null,
  marquee: null,
  clipboard: null,
  helpOpen: false,
  iconPickerOpen: false,
  shaderPickerOpen: false,
  lastEdit: null,
  agentEdit: null,

  commit(next, coalesceKey) {
    const { doc, past, lastEdit, selectedIds } = get()
    if (next === doc) return
    const now = Date.now()
    const coalesce = coalesceKey !== undefined && lastEdit?.key === coalesceKey && now - lastEdit.at < COALESCE_MS
    set({
      ...canonicalDesign(next),
      past: coalesce ? past : pushHistory(past, doc),
      future: [],
      selectedIds: keepExisting(next, selectedIds),
      lastEdit: coalesceKey === undefined ? null : { key: coalesceKey, at: now },
    })
  },

  preview(next) {
    const { doc, selectedIds } = get()
    if (next === doc) return
    set({ ...canonicalDesign(next), selectedIds: keepExisting(next, selectedIds) })
  },

  endGesture(start) {
    const { doc, past } = get()
    if (doc === start) return
    set({ past: pushHistory(past, start), future: [], lastEdit: null })
  },

  undo() {
    const { doc, past, future, selectedIds } = get()
    const previousSpec = past[past.length - 1]
    if (!previousSpec) return
    const previous = specToDocument(previousSpec)
    set({
      doc: previous,
      spec: previousSpec,
      past: past.slice(0, -1),
      future: [documentToSpec(doc), ...future],
      selectedIds: keepExisting(previous, selectedIds),
      lastEdit: null,
    })
  },

  redo() {
    const { doc, past, future, selectedIds } = get()
    const [nextSpec, ...rest] = future
    if (!nextSpec) return
    const next = specToDocument(nextSpec)
    set({
      ...canonicalDesign(next),
      past: pushHistory(past, doc),
      future: rest,
      selectedIds: keepExisting(next, selectedIds),
      lastEdit: null,
    })
  },

  setName: (name) => set({ name }),
  setSelection: (ids) => set({ selectedIds: keepExisting(get().doc, [...new Set(ids)]) }),
  toggleSelection: (id) => {
    const { selectedIds } = get()
    const next = selectedIds.includes(id) ? selectedIds.filter((existing) => existing !== id) : [...selectedIds, id]
    set({ selectedIds: keepExisting(get().doc, next) })
  },
  setHovered: (hoveredId) => set({ hoveredId }),
  setTool: (tool) => set({ tool }),
  setViewport: (viewport) => set({ viewport }),
  setCanvasSize: (canvasSize) => set({ canvasSize }),
  setSpaceHeld: (spaceHeld) => set({ spaceHeld }),
  setMarquee: (marquee) => set({ marquee }),
  setClipboard: (clipboard) => set({ clipboard }),
  setHelpOpen: (helpOpen) => set({ helpOpen }),
  setIconPickerOpen: (iconPickerOpen) => set({ iconPickerOpen }),
  setShaderPickerOpen: (shaderPickerOpen) => set({ shaderPickerOpen }),
  startEditing: (id, start) => set({ editingId: id, editStart: start, selectedIds: [id] }),
  stopEditing: () => set({ editingId: null, editStart: null }),
  markAgentEdit: (ids) => set({ agentEdit: { id: (get().agentEdit?.id ?? 0) + 1, ids, past: get().past } }),
  dismissAgentEdit: () => set({ agentEdit: null }),
}))
