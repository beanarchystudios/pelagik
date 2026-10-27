import type { BindableProperty, DesignVariable, Document, SceneNode } from "./types"

export const BINDABLE_PROPERTIES: BindableProperty[] = ["fill", "stroke"]

export function addVariable(doc: Document, variable: DesignVariable): Document {
  return {
    ...doc,
    variables: {
      ...doc.variables,
      [variable.id]: variable,
    },
  }
}

export function renameVariable(doc: Document, id: string, name: string): Document {
  const variable = doc.variables[id]
  if (!variable) return doc
  return { ...doc, variables: { ...doc.variables, [id]: { ...variable, name } } }
}

/** Changes a variable's value and copies it into every property bound to it. */
export function setVariableValue(doc: Document, id: string, value: string): Document {
  const variable = doc.variables[id]
  if (!variable) return doc

  const nodes = { ...doc.nodes }
  for (const [nodeId, node] of Object.entries(doc.nodes)) {
    if (Object.values(node.bindings).includes(id)) nodes[nodeId] = withBoundValue(node, id, value)
  }
  const updated: DesignVariable = { ...variable, value }
  return { ...doc, nodes, variables: { ...doc.variables, [id]: updated } }
}

/** Deleting a variable detaches it. Bound properties keep their last value, so nothing visibly changes. */
export function deleteVariable(doc: Document, id: string): Document {
  if (!doc.variables[id]) return doc

  const nodes = { ...doc.nodes }
  for (const [nodeId, node] of Object.entries(doc.nodes)) {
    if (!Object.values(node.bindings).includes(id)) continue
    const bindings = { ...node.bindings }
    for (const prop of BINDABLE_PROPERTIES) {
      if (bindings[prop] === id) delete bindings[prop]
    }
    nodes[nodeId] = { ...node, bindings }
  }
  const variables = { ...doc.variables }
  delete variables[id]
  return { ...doc, nodes, variables }
}

/**
 * Links a property on each node to a variable, copying the variable's value in. Passing null
 * detaches the property and leaves its current value in place.
 */
export function bindNodes(doc: Document, ids: string[], prop: BindableProperty, variableId: string | null): Document {
  const variable = variableId === null ? null : doc.variables[variableId]
  if (variableId !== null && !variable) return doc

  let next = doc
  for (const id of ids) {
    const node = next.nodes[id]
    if (!node) continue
    // Groups have no fill or stroke of their own, so there is nothing to bind.
    if (node.type === "group") continue

    const bindings = { ...node.bindings }
    if (variable) bindings[prop] = variable.id
    else delete bindings[prop]

    const updated: SceneNode = { ...node, bindings }
    if (variable) {
      Object.assign(updated, { [prop]: variable.value })
    }
    next = { ...next, nodes: { ...next.nodes, [id]: updated } }
  }
  return next
}

function withBoundValue(node: SceneNode, variableId: string, value: string): SceneNode {
  const updated = { ...node }
  for (const prop of BINDABLE_PROPERTIES) {
    if (node.bindings[prop] === variableId) {
      Object.assign(updated, { [prop]: value })
    }
  }
  return updated
}
