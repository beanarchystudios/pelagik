import Dexie, { type Table } from "dexie"
import { documentToSpec, specToDocument } from "@pelagik/design-spec/document"
import type { DesignSpec } from "@pelagik/design-spec/catalog"
import { loadSavedFile } from "./persistence"

export interface DesignRecord {
  id: string
  name: string
  spec: DesignSpec
  createdAt: number
  updatedAt: number
}

export class DesignsDatabase extends Dexie {
  designs!: Table<DesignRecord, string>
  metadata!: Table<{ key: string }, string>

  constructor(name = "pelagik-designs") {
    super(name)
    this.version(1).stores({ designs: "id, updatedAt", metadata: "key" })
  }
}

export const designsDb = new DesignsDatabase()

/** Import the original save once, without removing the original key. */
export async function migrateLegacyDesign(db = designsDb) {
  await db.transaction("rw", db.designs, db.metadata, async () => {
    if (await db.metadata.get("legacy-imported")) return
    const legacy = loadSavedFile()
    if (legacy) {
      const now = Date.now()
      await db.designs.add({ id: crypto.randomUUID(), name: legacy.name, spec: documentToSpec(legacy.doc), createdAt: now, updatedAt: now })
    }
    await db.metadata.put({ key: "legacy-imported" })
  })
}

export function readDesign(record: DesignRecord) {
  return specToDocument(record.spec)
}
