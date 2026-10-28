import { z } from "zod"
import { SHADER_IDS } from "@pelagik/design-core/types"

export const nodeType = z.enum(["frame", "rectangle", "ellipse", "text", "group", "icon", "image"])
export const shader = z.enum(SHADER_IDS)
const coordinate = z.number().finite().min(-1_000_000).max(1_000_000)
const size = z.number().finite().min(1).max(100_000)
// Solid CSS colors only. URLs, gradients, and expressions are deliberately excluded.
export const color = z.string().max(100).regex(/^(#[\da-f]{3,8}|[a-z]+|(?:rgb|hsl)a?\([\d\s.,%+\-/]+\))$/i)

// Icon artwork is flat SVG shapes with allowlisted presentation attributes. Nothing here can carry
// markup, scripts, URLs, or external references, so icons are rendered as React elements, not HTML.
export const iconTags = ["path", "circle", "ellipse", "rect", "line", "polyline", "polygon"] as const
export const iconAttributes = [
  "d", "cx", "cy", "r", "rx", "ry", "x", "y", "x1", "y1", "x2", "y2", "width", "height", "points", "transform",
  "fill", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "stroke-width", "stroke-linecap",
  "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "clip-rule", "opacity",
] as const
/** Plain SVG attribute syntax: letters, numbers, separators, and color functions. No `<`, `&`, `:`, or `;`. */
export const iconValue = /^[\w\s#%.,()+\-/]*$/
const iconAttributeNames: readonly string[] = iconAttributes
const iconElement = z.object({
  tag: z.enum(iconTags),
  attrs: z.record(z.string().max(40), z.string().max(20_000).regex(iconValue))
    .refine(attrs => Object.keys(attrs).every(name => iconAttributeNames.includes(name)), "Unsupported icon attribute"),
}).strict()
export const iconGlyph = z.object({
  name: z.string().trim().min(1).max(200),
  viewBox: z.string().regex(/^-?\d+(\.\d+)? -?\d+(\.\d+)? \d+(\.\d+)? \d+(\.\d+)?$/)
    .refine(viewBox => { const [, , width, height] = viewBox.split(" ").map(Number); return width > 0 && height > 0 }, "Icon viewBox must have a positive size"),
  elements: z.array(iconElement).min(1).max(1000),
}).strict()
export const flex = z.object({
  direction: z.enum(["horizontal", "vertical"]), gap: z.number().finite().min(0).max(100_000),
  padding: z.number().finite().min(0).max(100_000),
  mainAlign: z.enum(["start", "center", "end", "space-between"]), crossAlign: z.enum(["start", "center", "end"]),
}).strict()
export const patch = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  x: coordinate.optional(), y: coordinate.optional(), width: size.optional(), height: size.optional(),
  rotation: z.number().finite().min(-36000).max(36000).optional(), opacity: z.number().min(0).max(1).optional(),
  hidden: z.boolean().optional(), fill: color.nullable().optional(), stroke: color.nullable().optional(),
  shader: shader.nullable().optional(),
  strokeWidth: z.number().min(0).max(10000).optional(), radius: z.number().min(0).max(100000).optional(),
  text: z.string().max(10000).optional(), fontFamily: z.string().trim().min(1).max(200).optional(), fontSize: z.number().min(1).max(1000).optional(),
  fontWeight: z.number().int().min(100).max(900).optional(), textAlign: z.enum(["left", "center", "right"]).optional(),
  flex: flex.nullable().optional(),
}).strict()
