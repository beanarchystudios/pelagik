import { createId, createNode, emptyDocument, childIdsOf, patchNode, setChildIds, subtreeIds } from "@pelagik/design-core/document"
import { refreshFrom } from "@pelagik/design-core/operations"
import { addVariable, bindNodes } from "@pelagik/design-core/variables"
import type { Document, SceneNode } from "@pelagik/design-core/types"
import { parseDesignSpec, type DesignSpec } from "./catalog"

export function documentToSpec(doc: Document, roots = doc.rootIds): DesignSpec {
  const ids = new Set(roots.flatMap(id => subtreeIds(doc, id)))
  if (ids.size > 10000) throw new Error("Designs are limited to 10000 nodes")
  const nodes: DesignSpec["nodes"] = Object.create(null)
  const variables: NonNullable<DesignSpec["variables"]> = Object.create(null)
  for (const id of ids) {
    const node = doc.nodes[id]
    const { id: _id, type, parentId: _parentId, childIds, bindings, flex, text, fontFamily, fontSize, fontWeight, textAlign, fill, shader, stroke, strokeWidth, radius, icon, ...common } = node
    const shapeProps = type === "group" ? {} : type === "icon" ? { fill, icon } : type === "text" ? { fill, stroke, strokeWidth, radius } : { fill, ...(shader ? { shader } : {}), stroke, strokeWidth, radius }
    const props = {
      ...common,
      ...shapeProps,
      ...(type === "frame" ? { flex } : {}),
      ...(type === "text" ? { text, fontFamily, fontSize, fontWeight, textAlign } : {}),
    }
    // Narrowing is checked by the catalog at the external boundary.
    nodes[id] = { type, props, childIds, bindings } as DesignSpec["nodes"][string]
    for (const variableId of Object.values(bindings)) {
      const variable = doc.variables[variableId!]
      if (variable) variables[variable.id] = { name: variable.name, value: variable.value }
    }
  }
  // Whole-document exports preserve unbound variables as well.
  if (roots === doc.rootIds) for (const v of Object.values(doc.variables)) variables[v.id] = { name: v.name, value: v.value }
  return parseDesignSpec({ rootIds: roots, nodes, variables })
}

/** Compile a complete json-render design into the editable model, remapping IDs on insertion. */
export function insertDesignSpec(original: Document, input: unknown, parentId: string | null = null) {
  const spec = parseDesignSpec(input)
  const { seen, parents } = validateHierarchy(spec)
  if (!seen.size) throw new Error("Spec must contain at least one node")
  if (seen.size > 1000) throw new Error("Imports are limited to 1000 nodes")
  if (parentId !== null) {
    const parent = original.nodes[parentId]
    if (!parent || !["frame", "group"].includes(parent.type)) throw new Error("Parent must be a frame or group")
  }
  const ids: Record<string, string> = Object.create(null)
  const variableIds: Record<string, string> = Object.create(null)
  for (const id of seen) ids[id] = createId()
  for (const id of Object.keys(spec.variables ?? {})) variableIds[id] = createId()
  let doc: Document = { ...original, nodes: { ...original.nodes } }
  for (const [id, variable] of Object.entries(spec.variables ?? {})) doc = addVariable(doc, { ...variable, id: variableIds[id], type: "color" })
  for (const id of seen) {
    const source = spec.nodes[id]
    const parent = parents.get(id)!
    const node: SceneNode = {
      ...createNode(doc, source.type, { x: 0, y: 0, width: 100, height: 100 }, ids[id]),
      parentId: parent === null ? parentId : ids[parent], childIds: source.childIds.map(id => ids[id]),
    }
    doc.nodes[node.id] = node
    doc = patchNode(doc, node.id, source.props)
    for (const prop of ["fill", "stroke"] as const) {
      const variable = source.bindings?.[prop]
      if (variable) doc = bindNodes(doc, [node.id], prop, variableIds[variable])
    }
  }
  const rootIds = spec.rootIds.map(id => ids[id])
  doc = setChildIds(doc, parentId, [...childIdsOf(doc, parentId), ...rootIds])
  // Children are inserted parent-first; reflow in reverse order so nested groups fit before ancestors.
  for (const id of [...seen].reverse()) doc = refreshFrom(doc, ids[id])
  return { doc, rootIds, ids, variableIds }
}

/** Validate topology independently of the editable geometry projection. */
function validateHierarchy(spec: DesignSpec) {
  const seen = new Set<string>()
  const parents = new Map<string, string | null>()
  function check(id: string, parent: string | null, depth: number) {
    if (!Object.hasOwn(spec.nodes, id) || seen.has(id) || depth > 64) throw new Error("Invalid spec hierarchy, duplicate node, cycle, or depth exceeds 64")
    seen.add(id); parents.set(id, parent)
    const node = spec.nodes[id]
    if (node.childIds.length && node.type !== "frame" && node.type !== "group") throw new Error("Only frames and groups can contain children")
    if (node.type === "group" && Object.keys(node.bindings ?? {}).length) throw new Error("Groups cannot bind colors")
    if (node.type === "icon" && node.bindings?.stroke) throw new Error("Icons cannot bind strokes")
    for (const variable of Object.values(node.bindings ?? {})) if (!Object.hasOwn(spec.variables ?? {}, variable!)) throw new Error("Unknown spec variable")
    for (const child of node.childIds) check(child, id, depth + 1)
  }
  for (const root of spec.rootIds) check(root, null, 0)
  if (seen.size !== Object.keys(spec.nodes).length) throw new Error("Spec contains orphan nodes")
  return { seen, parents }
}

/** Derive the canvas model from the canonical json-render design, preserving IDs and geometry. */
export function specToDocument(input: unknown): Document {
  const spec = parseDesignSpec(input)
  const { seen, parents } = validateHierarchy(spec)
  const doc: Document = { nodes: Object.create(null), rootIds: [...spec.rootIds], variables: Object.create(null) }
  for (const [id, variable] of Object.entries(spec.variables ?? {})) {
    doc.variables[id] = { id, type: "color", ...variable }
  }
  for (const id of seen) {
    const source = spec.nodes[id]
    const node: SceneNode = {
      ...createNode(emptyDocument(), source.type, { x: 0, y: 0, width: 100, height: 100 }, id),
      ...source.props,
      parentId: parents.get(id)!, childIds: [...source.childIds], bindings: { ...source.bindings },
    }
    for (const prop of ["fill", "stroke"] as const) {
      const variable = node.bindings[prop]
      if (variable) node[prop] = doc.variables[variable].value
    }
    doc.nodes[id] = node
  }
  return doc
}

/** Every editing path crosses this boundary before the canvas or history sees a design. */
const canonicalCache = new WeakMap<Document, { spec: DesignSpec; doc: Document }>()
const projectedNodes = new WeakMap<SceneNode, SceneNode>()
export function canonicalDesign(doc: Document) {
  const cached = canonicalCache.get(doc)
  if (cached) return cached
  const spec = documentToSpec(doc)
  const projected = specToDocument(spec)
  // Preserve unchanged layer identities for rendering and agent change tracking.
  for (const [id, source] of Object.entries(doc.nodes)) {
    const existing = projectedNodes.get(source)
    if (existing && existing.fill === projected.nodes[id].fill && existing.stroke === projected.nodes[id].stroke && existing.shader === projected.nodes[id].shader) projected.nodes[id] = existing
    projectedNodes.set(source, projected.nodes[id])
    projectedNodes.set(projected.nodes[id], projected.nodes[id])
  }
  const result = { spec, doc: projected }
  canonicalCache.set(doc, result)
  canonicalCache.set(result.doc, result)
  return result
}
