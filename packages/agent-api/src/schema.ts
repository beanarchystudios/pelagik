import { z } from "zod"

import { nodeType, color, patch } from "@pelagik/design-spec/properties"
export { nodeType, color, flex, patch } from "@pelagik/design-spec/properties"
import { designSpecSchema } from "@pelagik/design-spec/catalog"
const id = z.string().min(1).max(128)
const ids = z.array(id).min(1).max(100)
const coordinate = z.number().finite().min(-1_000_000).max(1_000_000)
const ref = z.string().regex(/^[a-zA-Z][a-zA-Z\d_-]{0,63}$/).optional()
export const operation = z.discriminatedUnion("op", [
  z.object({ op: z.literal("insert_spec"), spec: designSpecSchema, ref, parentId: id.nullable().default(null) }).strict(),
  z.object({ op: z.literal("create"), type: nodeType.exclude(["group", "icon"]), ref, parentId: id.nullable().default(null), props: patch }).strict(),
  z.object({ op: z.literal("update"), ids, props: patch }).strict(),
  z.object({ op: z.literal("delete"), ids }).strict(),
  z.object({ op: z.literal("duplicate"), ids, dx: coordinate.default(10), dy: coordinate.default(10) }).strict(),
  z.object({ op: z.literal("group"), ids, ref }).strict(),
  z.object({ op: z.literal("ungroup"), ids }).strict(),
  z.object({ op: z.literal("reparent"), ids, parentId: id.nullable(), index: z.number().int().min(0).max(10000).nullable().default(null) }).strict(),
  z.object({ op: z.literal("reorder"), ids, order: z.enum(["front", "forward", "backward", "back"]) }).strict(),
  z.object({ op: z.literal("lock"), ids, locked: z.boolean() }).strict(),
  z.object({ op: z.literal("create_variable"), ref, name: z.string().trim().min(1).max(200), value: color }).strict(),
  z.object({ op: z.literal("update_variable"), id, name: z.string().trim().min(1).max(200).optional(), value: color.optional() }).strict(),
  z.object({ op: z.literal("delete_variable"), id }).strict(),
  z.object({ op: z.literal("bind_variable"), ids, property: z.enum(["fill", "stroke"]), variableId: id.nullable() }).strict(),
])
const session = { sessionId: z.string().uuid() }
export const toolSchemas = {
  list_sessions: z.object({}).strict(),
  get_document: z.object({ ...session, subtreeId: id.optional(), depth: z.number().int().min(0).max(20).default(3), format: z.enum(["summary", "json-render"]).default("json-render"), offset: z.number().int().min(0).default(0), limit: z.number().int().min(1).max(500).default(200) }).strict(),
  query_nodes: z.object({ ...session, ids: ids.optional(), subtreeId: id.optional(), type: nodeType.optional(), name: z.string().max(200).optional(), text: z.string().max(200).optional(), offset: z.number().int().min(0).default(0), limit: z.number().int().min(1).max(500).default(100) }).strict(),
  get_selection: z.object(session).strict(),
  apply_edits: z.object({ ...session, expectedRevision: z.string().max(100), requestId: z.string().min(1).max(128), operations: z.array(operation).min(1).max(100) }).strict(),
  get_changes: z.object({ ...session, sinceRevision: z.string().max(100) }).strict(),
  render: z.object({ ...session, ids: ids.optional(), viewport: z.boolean().default(false), scale: z.number().min(0.1).max(4).default(1) }).strict(),
  focus_nodes: z.object({ ...session, ids }).strict(),
}
export type ToolName = keyof typeof toolSchemas
export type ToolArgs<K extends ToolName> = z.output<(typeof toolSchemas)[K]>
export type Operation = z.output<typeof operation>
export const toolDescriptions: Record<ToolName, string> = {
  list_sessions: "List explicitly paired open Pelagik editors, revisions, names, and busy state. Choose a sessionId before using other tools.",
  get_document: "Read a bounded layer hierarchy and color variables at a settled revision. Set format=json-render for a complete editable design spec with at most 1000 nodes, and read pelagik://catalog for the json-render component vocabulary. Coordinates are parent-local CSS pixels; childIds are back-to-front. Paginate with offset/limit.",
  query_nodes: "Find layers by IDs, subtree, type, or case-insensitive name/text substring. Returns complete properties and page-space bounds. Paginate with offset/limit.",
  get_selection: "Read the user's selection, viewport, canvas size, revision, and busy state without changing them.",
  apply_edits: "Atomically apply up to 100 explicit operations as one undo step. Requires expectedRevision and a unique requestId. insert_spec compiles a complete json-render spec into editable nodes; its ref requires one root. Create/group/create_variable/insert_spec may define ref; later IDs use $ref. Create props use parent-local coordinates, default size 100x100. Icons and groups cannot be created directly; insert icons with insert_spec. Use explicit lock operations. Stale revisions fail; reread and replan. Preserve selection and viewport.",
  get_changes: "Read the bounded change log since a revision, including human edits, undo/redo, and text measurements. SNAPSHOT_REQUIRED means reread the document.",
  render: "Return a settled PNG crop of requested node bounds, the viewport, or all document roots. Includes revision, page bounds, and scale. Maximum 4096 pixels per side and 16 million total pixels.",
  focus_nodes: "Explicitly select layers and fit them into the user's viewport. Changes the user's editor view; use only when useful to show your work.",
}
export class AgentError extends Error {
  code: string
  constructor(code: string, message: string) { super(message); this.code = code }
}
export function errorResult(error: unknown) {
  return { code: error instanceof AgentError ? error.code : "INVALID_REQUEST", message: error instanceof Error ? error.message : "Invalid request" }
}
