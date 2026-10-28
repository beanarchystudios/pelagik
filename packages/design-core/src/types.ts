import type { ShaderId } from "./shader-ids"

export { SHADER_IDS } from "./shader-ids"
export type { ShaderId } from "./shader-ids"

export type NodeType = "frame" | "group" | "rectangle" | "ellipse" | "text" | "icon" | "image"

export type TextAlign = "left" | "center" | "right"

export type IconTag = "path" | "circle" | "ellipse" | "rect" | "line" | "polyline" | "polygon"

/** One SVG shape from an icon library. Attributes are limited to a safe, presentational subset. */
export interface IconElement {
  tag: IconTag
  attrs: Record<string, string>
}

/** Vector artwork for an icon layer. `name` is the library identifier, such as `lucide:house`. */
export interface IconGlyph {
  name: string
  viewBox: string
  elements: IconElement[]
}

export type FlexDirection = "horizontal" | "vertical"

export type FlexMainAlign = "start" | "center" | "end" | "space-between"

export type FlexCrossAlign = "start" | "center" | "end"

/** Flex-style layout for a frame. Its children stack along one axis and keep their own sizes. */
export interface FlexLayout {
  direction: FlexDirection
  gap: number
  padding: number
  /** Alignment along the direction of the stack. */
  mainAlign: FlexMainAlign
  /** Alignment across the stack. */
  crossAlign: FlexCrossAlign
}

/**
 * A layer on the page. `x`/`y` are the top-left corner of the un-rotated box in
 * the coordinate space of the parent (the page root for top-level nodes). The
 * box rotates around its center, and children inherit their parent's transform.
 */
/** Geometry and pixel-valued styles use whole CSS pixels; rotations use whole degrees. */
export interface SceneNode {
  id: string
  type: NodeType
  name: string
  parentId: string | null
  /** Back-to-front. Only frames and groups have children. */
  childIds: string[]
  /** Frames only. When set, the frame positions its children, so their x/y are derived. */
  flex: FlexLayout | null
  x: number
  y: number
  width: number
  height: number
  /** Degrees, clockwise, relative to the parent. */
  rotation: number
  opacity: number
  hidden: boolean
  locked: boolean
  fill: string | null
  /** A built-in procedural shader applied to shape layers. */
  shader: ShaderId | null
  stroke: string | null
  strokeWidth: number
  radius: number
  text: string
  fontFamily: string
  fontSize: number
  fontWeight: number
  textAlign: TextAlign
  /** Icon layers only. Their `fill` sets the icon color. */
  icon: IconGlyph | null
  image: string | null
  /**
   * Properties linked to a design variable. A bound property always holds the variable's current
   * value, so renderers and the design panel read the property directly.
   */
  bindings: Partial<Record<BindableProperty, string>>
}

export type ColorProperty = "fill" | "stroke"

export type BindableProperty = ColorProperty

/** A named design token that properties can be bound to. */
export interface DesignVariable {
  id: string
  name: string
  type: "color"
  value: string
}

export interface Document {
  nodes: Record<string, SceneNode>
  /** Top-level nodes, back-to-front. */
  rootIds: string[]
  variables: Record<string, DesignVariable>
}

/** Copied nodes. Root entries hold page-space placement; children are local to their parent. */
export interface Fragment {
  nodes: Record<string, SceneNode>
  rootIds: string[]
}

export type Tool = "select" | "hand" | "frame" | "rectangle" | "ellipse" | "text"

export type Handle = "nw" | "n" | "ne" | "e" | "se" | "s" | "sw" | "w"

export type AlignMode = "left" | "center" | "right" | "top" | "middle" | "bottom"

export type StackOrder = "front" | "forward" | "backward" | "back"

export interface Point {
  x: number
  y: number
}

export interface Rect {
  x: number
  y: number
  width: number
  height: number
}

export interface Bounds {
  minX: number
  minY: number
  maxX: number
  maxY: number
}

export interface Viewport {
  /** Screen-space offset of the page origin. */
  x: number
  y: number
  zoom: number
}
