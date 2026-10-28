import { beforeAll, beforeEach, expect, it, vi } from "vitest"
import { createNode, emptyDocument, patchNode } from "@pelagik/design-core/document"
import { canonicalDesign } from "@pelagik/design-spec/document"
import type { activeAgentEdit as ActiveAgentEdit, useEditor as Store } from "./store"

let useEditor: typeof Store
let activeAgentEdit: typeof ActiveAgentEdit
const storage = new Map<string, string>()
beforeAll(async () => {
  vi.stubGlobal("window", { localStorage: {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
  } })
  ;({ useEditor, activeAgentEdit } = await import("./store"))
})
beforeEach(() => {
  storage.clear()
  useEditor.setState({ ...canonicalDesign(emptyDocument()), past: [], future: [], selectedIds: [], lastEdit: null, agentEdit: null })
})

function boxDocument() {
  const box = createNode(emptyDocument(), "rectangle", { x: 0, y: 0, width: 10, height: 10 }, "box")
  return { nodes: { box }, rootIds: ["box"], variables: {} }
}

it("marks agent edits without adding to history", () => {
  useEditor.getState().commit(boxDocument())
  const historyLength = useEditor.getState().past.length

  useEditor.getState().markAgentEdit(["box"])
  expect(useEditor.getState().past.length).toBe(historyLength)
  expect(activeAgentEdit(useEditor.getState())?.ids).toEqual(["box"])
})

it("keeps the agent edit active through selection changes", () => {
  useEditor.getState().commit(boxDocument())
  useEditor.getState().markAgentEdit(["box"])

  useEditor.getState().setSelection(["box"])
  expect(activeAgentEdit(useEditor.getState())).not.toBeNull()
})

it("retires the agent edit once the user makes a later edit", () => {
  useEditor.getState().commit(boxDocument())
  useEditor.getState().markAgentEdit(["box"])

  useEditor.getState().commit(patchNode(useEditor.getState().doc, "box", { x: 5 }))
  expect(activeAgentEdit(useEditor.getState())).toBeNull()
})

it("retires the agent edit when undo removes its history step", () => {
  useEditor.getState().commit(boxDocument())
  useEditor.getState().markAgentEdit(["box"])

  useEditor.getState().undo()
  expect(activeAgentEdit(useEditor.getState())).toBeNull()
})
