import { ancestorsOf, childIdsOf, createId, createNode, isAncestor, patchNode, setChildIds, subtreeIds } from "@pelagik/design-core/document"
import { deleteNodes, duplicateNodes, groupNodes, reorderNodes, reparentNodes, ungroupNodes, updateNodes } from "@pelagik/design-core/operations"
import { addVariable, bindNodes, deleteVariable, renameVariable, setVariableValue } from "@pelagik/design-core/variables"
import type { Document, SceneNode } from "@pelagik/design-core/types"
import { insertDesignSpec } from "@pelagik/design-spec/document"
import { AgentError, operation, type Operation } from "./schema"

function fail(message: string): never { throw new AgentError("INVALID_EDIT", message) }
export function validateDocument(doc: Document) {
  if (Object.keys(doc.nodes).length > 10000 || Object.keys(doc.variables).length > 1000) fail("Document size limit exceeded")
  const seen = new Set<string>()
  function visit(id: string, parentId: string | null, depth: number) {
    const node = Object.hasOwn(doc.nodes, id) ? doc.nodes[id] : undefined
    if (!node || node.id !== id || node.parentId !== parentId || seen.has(id) || depth > 64) fail("Invalid document hierarchy or depth exceeds 64")
    seen.add(id)
    for (const value of [node.x, node.y, node.width, node.height, node.rotation, node.fontSize]) {
      if (!Number.isFinite(value) || Math.abs(value) > 2_000_000) fail("Invalid geometry")
    }
    if (node.width < 1 || node.height < 1) fail("Node dimensions must be positive")
    if (node.childIds.length && node.type !== "frame" && node.type !== "group") fail("Only frames and groups may have children")
    if (node.type === "icon" && !node.icon) fail("Icon layers need artwork")
    if (node.shader != null && !["frame", "rectangle", "ellipse"].includes(node.type)) fail("Shaders require a frame, rectangle, or ellipse")
    for (const [prop, variableId] of Object.entries(node.bindings)) {
      const variable = doc.variables[variableId!]
      if (!variable || node[prop as "fill" | "stroke"] !== variable.value) fail("Invalid variable binding")
    }
    for (const child of node.childIds) visit(child, id, depth + 1)
  }
  for (const id of doc.rootIds) visit(id, null, 0)
  if (seen.size !== Object.keys(doc.nodes).length) fail("Orphaned document nodes")
}

function validateProps(node: SceneNode, props: Partial<SceneNode>) {
  if (node.type !== "text" && ["text", "fontFamily", "fontSize", "fontWeight", "textAlign"].some(key => key in props)) fail("Text properties require a text node")
  if (node.type !== "frame" && "flex" in props) fail("Flex layout requires a frame")
  if (node.type === "group" && ["fill", "shader", "stroke", "strokeWidth", "radius"].some(key => key in props)) fail("Groups do not have shape styles")
  if (node.type !== "frame" && node.type !== "rectangle" && node.type !== "ellipse" && "shader" in props) fail("Shaders require a frame, rectangle, or ellipse")
  if (node.type === "icon" && props.fill === null) fail("Icons need a fill color")
}

/** Pure transaction. Never publishes partially applied operations. */
export function applyOperations(original: Document, inputs: Operation[]) {
  validateDocument(original)
  let doc = original
  const refs: Record<string, string> = Object.create(null)
  const createdIds: string[] = []
  const imports: Array<{ rootIds: string[]; ids: Record<string, string>; variableIds: Record<string, string> }> = []
  const resolve = (id: string) => id.startsWith("$") ? refs[id.slice(1)] ?? fail(`Unknown batch reference ${id}`) : id
  const node = (id: string) => (Object.hasOwn(doc.nodes, id) ? doc.nodes[id] : undefined) ?? fail(`Unknown node ${id}`)
  const writable = (id: string) => {
    node(id)
    if ([id, ...ancestorsOf(doc, id)].some(id => node(id).locked)) fail(`Node ${id} or its ancestor is locked`)
  }
  const subtreeWritable = (id: string) => { for (const child of subtreeIds(doc, id)) writable(child) }
  const parent = (id: string | null) => {
    if (id === null) return null
    const resolved = resolve(id)
    writable(resolved)
    if (!["frame", "group"].includes(node(resolved).type)) fail("Parent must be a frame or group")
    return resolved
  }
  const register = (ref: string | undefined, id: string) => {
    if (ref) { if (Object.hasOwn(refs, ref)) fail(`Duplicate reference ${ref}`); refs[ref] = id }
  }
  for (const input of inputs) {
    const op = operation.parse(input)
    if ("ids" in op) {
      const targets = op.ids.map(resolve)
      if (new Set(targets).size !== targets.length) fail("Duplicate target IDs")
      for (const id of targets) {
        node(id)
        // Unlocking a node is explicit, but must not bypass a locked ancestor.
        if (op.op === "lock") {
          if (ancestorsOf(doc, id).some(id => node(id).locked)) fail("Ancestor is locked")
        } else subtreeWritable(id)
      }
      switch (op.op) {
        case "update":
          for (const id of targets) validateProps(node(id), op.props)
          doc = updateNodes(doc, targets, op.props); break
        case "delete": doc = deleteNodes(doc, targets); break
        case "duplicate": {
          const result = duplicateNodes(doc, targets, { x: op.dx, y: op.dy }); doc = result.doc
          createdIds.push(...Object.keys(doc.nodes).filter(id => !Object.hasOwn(original.nodes, id) && !createdIds.includes(id)))
          break
        }
        case "group": {
          if (new Set(targets.map(id => node(id).parentId)).size !== 1) fail("Grouped nodes must have the same parent")
          const result = groupNodes(doc, targets)
          if (!result) fail("Unable to group nodes")
          doc = result!.doc; createdIds.push(result!.groupId); register(op.ref, result!.groupId); break
        }
        case "ungroup":
          if (targets.some(id => node(id).type !== "group")) fail("Ungroup requires groups")
          doc = ungroupNodes(doc, targets).doc; break
        case "reparent": {
          const parentId = parent(op.parentId)
          if (parentId && targets.some(id => id === parentId || isAncestor(doc, id, parentId))) fail("Reparent would create a cycle")
          doc = reparentNodes(doc, targets, parentId, op.index); break
        }
        case "reorder": doc = reorderNodes(doc, targets, op.order); break
        case "lock": for (const id of targets) doc = patchNode(doc, id, { locked: op.locked }); break
        case "bind_variable": {
          const variableId = op.variableId === null ? null : resolve(op.variableId)
          if (variableId && !Object.hasOwn(doc.variables, variableId)) fail("Unknown variable")
          if (targets.some(id => node(id).type === "group")) fail("Groups cannot bind variables")
          doc = bindNodes(doc, targets, op.property, variableId); break
        }
      }
    } else if (op.op === "insert_spec") {
      const parentId = parent(op.parentId)
      if (op.ref && op.spec.rootIds.length !== 1) fail("A spec with ref must have exactly one root")
      const result = insertDesignSpec(doc, op.spec, parentId)
      doc = result.doc
      createdIds.push(...Object.values(result.ids))
      imports.push({ rootIds: result.rootIds, ids: result.ids, variableIds: result.variableIds })
      if (op.ref) register(op.ref, result.rootIds[0])
    } else if (op.op === "create") {
      const parentId = parent(op.parentId)
      const created = createNode(doc, op.type, { x: 0, y: 0, width: 100, height: 100 })
      validateProps(created, op.props)
      doc = { ...doc, nodes: { ...doc.nodes, [created.id]: { ...created, parentId } } }
      doc = setChildIds(doc, parentId, [...childIdsOf(doc, parentId), created.id])
      doc = updateNodes(doc, [created.id], op.props)
      createdIds.push(created.id); register(op.ref, created.id)
    } else if (op.op === "create_variable") {
      const id = createId()
      doc = addVariable(doc, { id, name: op.name, value: op.value, type: "color" })
      register(op.ref, id)
    } else if (op.op === "update_variable" || op.op === "delete_variable") {
      const id = resolve(op.id)
      if (!Object.hasOwn(doc.variables, id)) fail(`Unknown variable ${id}`)
      for (const n of Object.values(doc.nodes)) if (Object.values(n.bindings).includes(id)) writable(n.id)
      if (op.op === "delete_variable") doc = deleteVariable(doc, id)
      else {
        if (op.name !== undefined) doc = renameVariable(doc, id, op.name)
        if (op.value !== undefined) doc = setVariableValue(doc, id, op.value)
      }
    }
    // Limits are enforced between operations, before recursive model operations can grow unbounded.
    validateDocument(doc)
  }
  // Refit from changed roots is already handled by model operations; preserve their result.
  const changedIds = Object.keys(doc.nodes).filter(id => doc.nodes[id] !== original.nodes[id])
  const deletedIds = Object.keys(original.nodes).filter(id => !Object.hasOwn(doc.nodes, id))
  return { doc, refs, imports, createdIds: createdIds.filter(id => Object.hasOwn(doc.nodes, id)), changedIds, deletedIds }
}
