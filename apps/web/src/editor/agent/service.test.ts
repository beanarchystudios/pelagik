import { canonicalDesign } from "@pelagik/design-spec/document"
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest"
import { emptyDocument } from "@pelagik/design-core/document"
import type { createAgentService as ServiceFactory } from "./service"
import type { useEditor as EditorStore } from "../state/store"

let createAgentService: typeof ServiceFactory
let useEditor: typeof EditorStore
let service: ReturnType<typeof ServiceFactory>
const client = crypto.randomUUID()
const sessionId = crypto.randomUUID()
const save = vi.fn()
beforeAll(async () => {
  const window = Object.assign(new EventTarget(), { localStorage: { getItem: () => null, setItem: save } })
  vi.stubGlobal("window", window)
  vi.stubGlobal("document", { activeElement: null, fonts: { ready: Promise.resolve() } })
  vi.stubGlobal("HTMLElement", class {})
  vi.stubGlobal("CSS", { supports: () => true })
  ;({ useEditor } = await import("../state/store"))
  ;({ createAgentService } = await import("./service"))
})
beforeEach(() => {
  save.mockReset()
  useEditor.setState({ ...canonicalDesign(emptyDocument()), name: "Test", past: [], future: [], selectedIds: [], editingId: null, lastEdit: null })
  service = createAgentService()
})
afterEach(() => service.dispose())
const create = () => ({ sessionId, requestId: crypto.randomUUID(), expectedRevision: service.status().revision,
  operations: [{ op: "create", type: "rectangle", props: { width: 100, height: 100 } }] })

describe("editor agent service", () => {
  it("commits one undo step, keeps selection, and supports idempotent retries", async () => {
    const input = create()
    const response = await service.call("apply_edits", input, client)
    expect(useEditor.getState().past).toHaveLength(1)
    expect(useEditor.getState().selectedIds).toEqual([])
    const revision = service.status().revision
    expect(await service.call("apply_edits", input, client)).toEqual(response)
    expect(service.status().revision).toBe(revision)
    expect(Object.keys(useEditor.getState().doc.nodes)).toHaveLength(1)
    await expect(service.call("apply_edits", { ...input, operations: [{ op: "create", type: "frame", props: {} }] }, client)).rejects.toMatchObject({ code: "REQUEST_ID_REUSED" })
    useEditor.getState().undo()
    expect(useEditor.getState().doc.rootIds).toHaveLength(0)
    useEditor.getState().redo()
    expect(useEditor.getState().doc.rootIds).toHaveLength(1)
  })
  it("rejects a stale agent after a human edit and logs undo/redo", async () => {
    const stale = create()
    const initial = service.status().revision
    await service.call("apply_edits", create(), client)
    useEditor.getState().setName("Human rename")
    await expect(service.call("apply_edits", stale, crypto.randomUUID())).rejects.toMatchObject({ code: "REVISION_CONFLICT" })
    useEditor.getState().undo()
    const response = await service.call("get_changes", { sessionId, sinceRevision: initial }, client) as { changes: unknown[] }
    expect(response.changes).toHaveLength(3)
    await expect(service.call("get_changes", { sessionId, sinceRevision: "old:0" }, client)).rejects.toMatchObject({ code: "SNAPSHOT_REQUIRED" })
  })
  it("rejects writes while a pointer gesture or inline edit is in progress", async () => {
    window.dispatchEvent(new Event("pointerdown"))
    await expect(service.call("apply_edits", create(), client)).rejects.toMatchObject({ code: "EDITOR_BUSY" })
    window.dispatchEvent(new Event("pointerup"))
    await service.call("apply_edits", create(), client)
    const id = useEditor.getState().doc.rootIds[0]
    useEditor.getState().startEditing(id, useEditor.getState().doc)
    await expect(service.call("apply_edits", create(), client)).rejects.toMatchObject({ code: "EDITOR_BUSY" })
    expect(useEditor.getState().past).toHaveLength(1)
  })
  it("does not publish failed batches and reports save failures separately", async () => {
    const invalid = { ...create(), operations: [
      { op: "create", type: "rectangle", ref: "r", props: {} },
      { op: "update", ids: ["$r"], props: { text: "Invalid" } },
    ] }
    await expect(service.call("apply_edits", invalid, client)).rejects.toThrow()
    expect(useEditor.getState().doc.rootIds).toEqual([])
    expect(useEditor.getState().past).toEqual([])
    save.mockImplementation(() => { throw new Error("Storage full") })
    const result = await service.call("apply_edits", create(), client) as { persistenceStatus: string }
    expect(result.persistenceStatus).toBe("failed")
    expect(useEditor.getState().doc.rootIds).toHaveLength(1)
  })
  it("paginates queries, reads bounded hierarchy, and focuses explicitly", async () => {
    await service.call("apply_edits", { ...create(), operations: [
      { op: "create", type: "frame", ref: "f", props: { name: "Frame" } },
      { op: "create", type: "text", parentId: "$f", props: { text: "Hello agent", name: "Heading" } },
    ] }, client)
    const hierarchy = await service.call("get_document", { sessionId, depth: 0, format: "summary" }, client) as { nodes: unknown[] }
    expect(hierarchy.nodes).toHaveLength(1)
    const query = await service.call("query_nodes", { sessionId, text: "AGENT", limit: 1 }, client) as { nodes: Array<{ id: string }> }
    expect(query.nodes).toHaveLength(1)
    await service.call("focus_nodes", { sessionId, ids: [query.nodes[0].id] }, client)
    expect(useEditor.getState().selectedIds).toEqual([query.nodes[0].id])
  })
})
