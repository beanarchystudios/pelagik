import type { Rect, SceneNode } from "./types"

/** Keeps document measurements on whole CSS pixels. */
export function snapPx(value: number): number {
  return Number.isFinite(value) ? Math.round(value) : 0
}

export function snapRectToPixels(rect: Rect): Rect {
  return {
    x: snapPx(rect.x),
    y: snapPx(rect.y),
    width: snapPx(rect.width),
    height: snapPx(rect.height),
  }
}

/** Node measurements use whole pixels; rotations use whole degrees. */
export function snapNodeToPixels(node: SceneNode): SceneNode {
  return {
    ...node,
    x: snapPx(node.x),
    y: snapPx(node.y),
    width: snapPx(node.width),
    height: snapPx(node.height),
    rotation: snapPx(node.rotation),
    strokeWidth: snapPx(node.strokeWidth),
    radius: snapPx(node.radius),
    fontSize: snapPx(node.fontSize),
  }
}

/** Normalizes just the measurement fields present in a partial node update. */
export function snapNodePatchToPixels(patch: Partial<SceneNode>): Partial<SceneNode> {
  return {
    ...patch,
    ...(patch.x === undefined ? {} : { x: snapPx(patch.x) }),
    ...(patch.y === undefined ? {} : { y: snapPx(patch.y) }),
    ...(patch.width === undefined ? {} : { width: snapPx(patch.width) }),
    ...(patch.height === undefined ? {} : { height: snapPx(patch.height) }),
    ...(patch.rotation === undefined ? {} : { rotation: snapPx(patch.rotation) }),
    ...(patch.strokeWidth === undefined ? {} : { strokeWidth: snapPx(patch.strokeWidth) }),
    ...(patch.radius === undefined ? {} : { radius: snapPx(patch.radius) }),
    ...(patch.fontSize === undefined ? {} : { fontSize: snapPx(patch.fontSize) }),
  }
}
