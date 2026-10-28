import { beforeAll, beforeEach, expect, it, vi } from "vitest"
import { createNode, emptyDocument, patchNode } from "@pelagik/design-core/document"
import { canonicalDesign, specToDocument } from "@pelagik/design-spec/document"
import type { useEditor as Store } from "./store"
import type * as Persistence from "./persistence"

let useEditor: typeof Store
let persistence: typeof Persistence
const storage = new Map<string, string>()
beforeAll(async () => {
  vi.stubGlobal("window", { localStorage: {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
  } })
  ;({ useEditor } = await import("./store"))
  persistence = await import("./persistence")
})
beforeEach(() => {
  storage.clear()
  useEditor.setState({ ...canonicalDesign(emptyDocument()), past: [], future: [], selectedIds: [], lastEdit: null })
})

it("keeps manual creation, property edits, gestures and history in json-render", () => {
  const node = createNode(emptyDocument(), "rectangle", { x: 10, y: 20, width: 100, height: 80 }, "shape")
  useEditor.getState().commit({ nodes: { shape: node }, rootIds: ["shape"], variables: {} })
  expect(useEditor.getState().spec.nodes.shape.props.x).toBe(10)
  const start = useEditor.getState().doc
  useEditor.getState().preview(patchNode(start, "shape", { x: 45 }))
  expect(useEditor.getState().spec.nodes.shape.props.x).toBe(45)
  useEditor.getState().endGesture(start)
  expect(useEditor.getState().past[1].nodes.shape.props.x).toBe(10)
  useEditor.getState().undo()
  expect(useEditor.getState().spec.nodes.shape.props.x).toBe(10)
  useEditor.getState().redo()
  expect(useEditor.getState().spec.nodes.shape.props.x).toBe(45)
  expect(specToDocument(useEditor.getState().spec)).toEqual(useEditor.getState().doc)
})

it("keeps shader effects through selection, undo, redo, and save reload", () => {
  const node = createNode(emptyDocument(), "rectangle", { x: 0, y: 0, width: 120, height: 80 }, "surface")
  const start = { nodes: { surface: node }, rootIds: ["surface"], variables: {} }
  useEditor.getState().commit(start)
  useEditor.getState().setSelection(["surface"])
  useEditor.getState().commit(patchNode(start, "surface", { shader: "water" }))

  expect(useEditor.getState().selectedIds).toEqual(["surface"])
  expect(useEditor.getState().doc.nodes.surface.shader).toBe("water")
  useEditor.getState().undo()
  expect(useEditor.getState().doc.nodes.surface.shader).toBeNull()
  useEditor.getState().redo()
  expect(useEditor.getState().doc.nodes.surface.shader).toBe("water")

  expect(persistence.saveFile({ name: "Shader", doc: useEditor.getState().doc })).toBe(true)
  expect(persistence.loadSavedFile()?.doc.nodes.surface.shader).toBe("water")
})

it("rejects unsupported edits before changing the live design or history", () => {
  const before = useEditor.getState()
  const node = createNode(before.doc, "text", { x: 0, y: 0, width: 100, height: 30 }, "text")
  expect(() => before.commit({ nodes: { text: { ...node, fontSize: -10 } }, rootIds: ["text"], variables: {} })).toThrow()
  expect(useEditor.getState()).toBe(before)
})

it("migrates legacy saves and persists only json-render, preserving IDs and geometry", () => {
  const node = createNode(emptyDocument(), "text", { x: 12, y: 30, width: 240, height: 38 }, "heading")
  const doc = { nodes: { heading: { ...node, text: "Saved design", rotation: 27 } }, rootIds: ["heading"], variables: {} }
  storage.set("d3sign:file:v1", JSON.stringify({ name: "Legacy", doc }))
  const migrated = persistence.loadSavedFile()!
  expect(migrated.doc).toEqual(doc)
  expect(persistence.saveFile(migrated)).toBe(true)
  const saved = JSON.parse(storage.get("d3sign:file:v1")!)
  expect(saved.format).toBe("pelagik/json-render")
  expect(saved.doc).toBeUndefined()
  expect(saved.spec.nodes.heading.props.rotation).toBe(27)
  expect(persistence.loadSavedFile()).toEqual(migrated)
})

it("inserts an icon at the view center as one selected, undoable step", async () => {
  const { insertIcon } = await import("./commands")
  useEditor.setState({ canvasSize: { width: 800, height: 600 }, viewport: { x: 0, y: 0, zoom: 1 } })
  insertIcon({ name: "lucide:house", viewBox: "0 0 24 24", elements: [{ tag: "path", attrs: { d: "M0 0h24v24H0z" } }] })
  const { doc, selectedIds, past } = useEditor.getState()
  const node = doc.nodes[selectedIds[0]]
  expect(node.type).toBe("icon")
  expect(node.name).toBe("house")
  expect([node.x, node.y, node.width, node.height]).toEqual([388, 288, 24, 24])
  expect(node.icon?.name).toBe("lucide:house")
  expect(past).toHaveLength(1)
  useEditor.getState().undo()
  expect(useEditor.getState().doc.rootIds).toEqual([])
})
