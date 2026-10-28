import "fake-indexeddb/auto"
import { afterAll, beforeAll, beforeEach, expect, it, vi } from "vitest"
import { createNode, emptyDocument } from "@pelagik/design-core/document"
import { documentToSpec } from "@pelagik/design-spec/document"
import type { DesignRecord } from "./designs"

const storage = new Map<string, string>()
let db: typeof import("./designs").designsDb
let migrate: typeof import("./designs").migrateLegacyDesign
let session: typeof import("./design-session")
let useEditor: typeof import("./store").useEditor

beforeAll(async () => {
  vi.stubGlobal("window", { addEventListener: () => {}, removeEventListener: () => {}, localStorage: { getItem: (key: string) => storage.get(key) ?? null, setItem: (key: string, value: string) => storage.set(key, value) } })
  ;({ designsDb: db, migrateLegacyDesign: migrate } = await import("./designs"))
  session = await import("./design-session")
  ;({ useEditor } = await import("./store"))
})
beforeEach(async () => { storage.clear(); await db.designs.clear(); await db.metadata.clear() })
afterAll(async () => { db.close(); vi.unstubAllGlobals() })

it("imports the legacy design once and keeps the original save", async () => {
  const node = createNode(emptyDocument(), "rectangle", { x: 12, y: 34, width: 50, height: 60 }, "shape")
  const original = JSON.stringify({ name: "Old design", doc: { nodes: { shape: node }, rootIds: ["shape"], variables: {} } })
  storage.set("d3sign:file:v1", original)
  await migrate()
  await migrate()
  const records = await db.designs.toArray()
  expect(records).toHaveLength(1)
  expect(records[0].name).toBe("Old design")
  expect(records[0].spec.nodes.shape.props.x).toBe(12)
  expect(storage.get("d3sign:file:v1")).toBe(original)
  await db.designs.clear()
  await migrate()
  expect(await db.designs.count()).toBe(0)
})

it("saves separate designs and clears history when switching", async () => {
  const record = (id: string): DesignRecord => ({ id, name: id, spec: documentToSpec(emptyDocument()), createdAt: 1, updatedAt: 1 })
  const first = record("first"), second = record("second")
  await db.designs.bulkAdd([first, second])
  const stop = session.startDesignAutosave()
  session.openDesign(first)
  const node = createNode(emptyDocument(), "rectangle", { x: 0, y: 0, width: 50, height: 60 }, "shape")
  useEditor.getState().commit({ nodes: { shape: node }, rootIds: ["shape"], variables: {} })
  useEditor.getState().setName("Renamed")
  await session.closeDesign()
  session.openDesign(second)
  expect(useEditor.getState().past).toEqual([])
  expect(useEditor.getState().doc.rootIds).toEqual([])
  expect((await db.designs.get("first"))?.name).toBe("Renamed")
  expect((await db.designs.get("first"))?.spec.rootIds).toEqual(["shape"])
  expect((await db.designs.get("second"))?.spec.rootIds).toEqual([])
  await session.closeDesign()
  stop()
})
