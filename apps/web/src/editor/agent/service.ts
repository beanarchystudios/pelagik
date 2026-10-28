import { documentToSpec } from "@pelagik/design-spec/document"
import { applyOperations } from "@pelagik/agent-api/edits"
import { AgentError, toolSchemas, type ToolName } from "@pelagik/agent-api/schema"
import { boundsOfIds, nodeBounds, subtreeIds } from "@pelagik/design-core/document"
import { fitBounds } from "@pelagik/design-core/viewport"
import type { Document } from "@pelagik/design-core/types"
import { useEditor } from "../state/store"
import { saveFile } from "../state/persistence"
import { renderDocument } from "./render"

interface Change { revision: string; previousRevision: string; changedIds: string[]; deletedIds: string[]; name: string }
export function createAgentService() {
  const epoch = crypto.randomUUID()
  let counter = 0
  let revision = `${epoch}:0`
  let pointerDown = false
  let changedAt = Date.now()
  const changes: Change[] = []
  const cache = new Map<string, { digest: string; result: unknown; at: number }>()
  const down = () => { pointerDown = true }
  const up = () => { pointerDown = false }
  window.addEventListener("pointerdown", down, true)
  window.addEventListener("pointerup", up, true)
  window.addEventListener("pointercancel", up, true)
  window.addEventListener("blur", up)
  const unsubscribe = useEditor.subscribe((next, previous) => {
    if (next.doc === previous.doc && next.name === previous.name) return
    const previousRevision = revision
    revision = `${epoch}:${++counter}`
    changedAt = Date.now()
    changes.push({
      revision, previousRevision, name: next.name,
      changedIds: Object.keys(next.doc.nodes).filter(id => next.doc.nodes[id] !== previous.doc.nodes[id]),
      deletedIds: Object.keys(previous.doc.nodes).filter(id => !Object.hasOwn(next.doc.nodes, id)),
    })
    if (changes.length > 500) changes.shift()
  })
  const busy = () => pointerDown || Boolean(useEditor.getState().editingId) ||
    (document.activeElement instanceof HTMLElement && document.activeElement.matches("input,textarea,[contenteditable=true]"))
  const status = () => ({ name: useEditor.getState().name.slice(0, 200), revision, busy: busy() })
  const requireIdle = () => { if (busy()) throw new AgentError("EDITOR_BUSY", "Finish the current pointer gesture or text edit before applying agent changes") }
  async function settle() {
    const started = Date.now()
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      await Promise.race([
        document.fonts.ready,
        new Promise((_, reject) => { timer = setTimeout(() => reject(new AgentError("LAYOUT_TIMEOUT", "Fonts did not settle")), 5000) }),
      ])
    } finally { clearTimeout(timer) }
    while (Date.now() - started < 5000) {
      await new Promise(resolve => setTimeout(resolve, 50))
      if (Date.now() - changedAt >= 100) return
    }
    throw new AgentError("LAYOUT_TIMEOUT", "Document layout is still changing")
  }
  function known(doc: Document, id: string) {
    if (!Object.hasOwn(doc.nodes, id)) throw new AgentError("NODE_NOT_FOUND", `Unknown node ${id}`)
    return doc.nodes[id]
  }
  async function call(name: ToolName, input: unknown, clientId: string): Promise<unknown> {
    const args = toolSchemas[name].parse(input)
    if (name !== "apply_edits" && name !== "get_changes" && name !== "get_selection") await settle()
    const s = useEditor.getState()
    const doc = s.doc
    const base = () => ({ revision, busy: busy() })
    switch (name) {
      case "get_document": {
        const a = toolSchemas.get_document.parse(args)
        const roots = a.subtreeId ? [known(doc, a.subtreeId).id] : doc.rootIds
        if (a.format === "json-render") return { ...base(), name: s.name, format: "pelagik/json-render", catalogUri: "pelagik://catalog", nodeCount: Object.keys(doc.nodes).length, spec: a.subtreeId ? documentToSpec(doc, roots) : s.spec }
        const nodes: Array<{ id: string; name: string; type: string; parentId: string | null; childIds: string[]; depth: number }> = []
        const walk = (id: string, depth: number) => {
          const n = known(doc, id)
          nodes.push({ id, name: n.name, type: n.type, parentId: n.parentId, childIds: n.childIds, depth })
          if (depth < a.depth) for (const child of n.childIds) walk(child, depth + 1)
        }
        for (const root of roots) walk(root, 0)
        return { ...base(), name: s.name, rootIds: roots, nodeCount: Object.keys(doc.nodes).length,
          nodes: nodes.slice(a.offset, a.offset + a.limit), total: nodes.length,
          nextOffset: a.offset + a.limit < nodes.length ? a.offset + a.limit : null,
          variables: Object.values(doc.variables), capabilities: { nodeTypes: ["frame", "rectangle", "ellipse", "text", "group", "icon"], variables: ["color"], atomicEdits: true, render: "png", designFormat: "pelagik/json-render", catalogUri: "pelagik://catalog" } }
      }
      case "query_nodes": {
        const a = toolSchemas.query_nodes.parse(args)
        if (a.ids) for (const id of a.ids) known(doc, id)
        const subtree = a.subtreeId ? new Set(subtreeIds(doc, known(doc, a.subtreeId).id)) : undefined
        const nodes = Object.values(doc.nodes).filter(n =>
          (!a.ids || a.ids.includes(n.id)) && (!subtree || subtree.has(n.id)) && (!a.type || n.type === a.type) &&
          (a.name === undefined || n.name.toLowerCase().includes(a.name.toLowerCase())) &&
          (a.text === undefined || n.text.toLowerCase().includes(a.text.toLowerCase())))
        return { ...base(), nodes: nodes.slice(a.offset, a.offset + a.limit).map(n => ({ ...n, bounds: nodeBounds(doc, n.id) })), total: nodes.length, nextOffset: a.offset + a.limit < nodes.length ? a.offset + a.limit : null }
      }
      case "get_selection": return { ...base(), ids: s.selectedIds, viewport: s.viewport, canvasSize: s.canvasSize }
      case "get_changes": {
        const a = toolSchemas.get_changes.parse(args)
        if (a.sinceRevision === revision) return { ...base(), changes: [] }
        const index = changes.findIndex(c => c.previousRevision === a.sinceRevision)
        if (index < 0) throw new AgentError("SNAPSHOT_REQUIRED", "Revision is from another session or the change log expired. Read a fresh document snapshot.")
        return { ...base(), changes: changes.slice(index) }
      }
      case "apply_edits": {
        const a = toolSchemas.apply_edits.parse(args)
        const key = `${clientId}:${a.requestId}`
        const digest = JSON.stringify(a)
        const now = Date.now()
        for (const [key, entry] of cache) if (now - entry.at > 600000) cache.delete(key)
        const previous = cache.get(key)
        if (previous) {
          if (previous.digest !== digest) throw new AgentError("REQUEST_ID_REUSED", "requestId was already used with different input")
          return previous.result
        }
        requireIdle()
        if (a.expectedRevision !== revision) throw new AgentError("REVISION_CONFLICT", `Expected ${a.expectedRevision}, current revision is ${revision}. Reread and replan.`)
        const result = applyOperations(doc, a.operations)
        for (const node of Object.values(result.doc.nodes)) {
          for (const value of [node.fill, node.stroke]) if (value !== null && !CSS.supports("color", value)) throw new AgentError("INVALID_EDIT", `Invalid CSS color ${value}`)
        }
        for (const variable of Object.values(result.doc.variables)) if (!CSS.supports("color", variable.value)) throw new AgentError("INVALID_EDIT", "Invalid variable color")
        s.commit(result.doc)
        const touched = [...new Set([...result.createdIds, ...result.changedIds])]
        if (touched.length > 0) s.markAgentEdit(touched)
        const response = { ...base(), refs: result.refs, imports: result.imports, createdIds: result.createdIds, changedIds: result.changedIds, deletedIds: result.deletedIds,
          layoutPending: Object.values(result.doc.nodes).some(n => n.type === "text" && result.changedIds.includes(n.id)),
          persistenceStatus: saveFile({ name: s.name, doc: result.doc }) ? "saved" : "failed" }
        cache.set(key, { digest, result: response, at: now })
        if (cache.size > 1000) cache.delete(cache.keys().next().value!)
        return response
      }
      case "focus_nodes": {
        requireIdle()
        const a = toolSchemas.focus_nodes.parse(args)
        for (const id of a.ids) known(doc, id)
        s.setSelection(a.ids)
        const bounds = boundsOfIds(doc, a.ids)
        if (bounds) s.setViewport(fitBounds(bounds, s.canvasSize))
        return { ...base(), ids: a.ids }
      }
      case "render": {
        requireIdle()
        const a = toolSchemas.render.parse(args)
        if (a.ids && a.viewport) throw new AgentError("INVALID_REQUEST", "Choose ids or viewport, not both")
        const ids = a.ids ?? doc.rootIds
        for (const id of ids) known(doc, id)
        const bounds = a.viewport ? {
          minX: -s.viewport.x / s.viewport.zoom, minY: -s.viewport.y / s.viewport.zoom,
          maxX: (s.canvasSize.width - s.viewport.x) / s.viewport.zoom, maxY: (s.canvasSize.height - s.viewport.y) / s.viewport.zoom,
        } : boundsOfIds(doc, ids)
        if (!bounds) throw new AgentError("EMPTY_DOCUMENT", "Create nodes before rendering")
        const startRevision = revision
        const image = await renderDocument(bounds, a.scale)
        if (startRevision !== revision) throw new AgentError("REVISION_CONFLICT", "The document changed while rendering. Read and render again.")
        return { ...base(), ...image }
      }
      default: throw new AgentError("INVALID_REQUEST", "Tool is handled by the local broker")
    }
  }
  return { status, call, dispose() {
    unsubscribe(); window.removeEventListener("pointerdown", down, true); window.removeEventListener("pointerup", up, true)
    window.removeEventListener("pointercancel", up, true); window.removeEventListener("blur", up)
  } }
}
