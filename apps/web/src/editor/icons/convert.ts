import { iconAttributes, iconTags, iconValue } from "@pelagik/design-spec/properties"
import type { IconElement, IconGlyph, IconTag } from "@pelagik/design-core/types"

/** Icon artwork from an icon library, with set-level size and defaults already applied. */
export interface IconifyArtwork {
  body: string
  left: number
  top: number
  width: number
  height: number
  rotate: number
  hFlip: boolean
  vFlip: boolean
}

/** The icon uses SVG features Pelagik does not import, such as <use>, masks, or gradients. */
export class IconImportError extends Error {}

const MAX_ELEMENTS = 1000
const MAX_VALUE_LENGTH = 20_000
const SKIPPED_TAGS = new Set(["title", "desc", "metadata"])
const ALLOWED_TAGS: ReadonlySet<string> = new Set(iconTags)
const ALLOWED_ATTRIBUTES: ReadonlySet<string> = new Set(iconAttributes)
/** Presentation attributes that children inherit from their group, so flattening must copy them down. */
const INHERITED = new Set([
  "fill", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "stroke-width", "stroke-linecap",
  "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "clip-rule",
])
const TAG_PATTERN = /<(\/?)([a-zA-Z][\w:-]*)((?:\s+[\w:-]+\s*=\s*"[^"]*")*)\s*(\/?)>/g
const ATTRIBUTE_PATTERN = /([\w:-]+)\s*=\s*"([^"]*)"/g

/** Attributes accumulated from enclosing groups, with the transform and opacity they contribute. */
interface Frame {
  attrs: Record<string, string>
  transform: string
  opacity: number
}

/**
 * Converts an Iconify body into flat SVG shapes. Groups are flattened by copying their inherited
 * presentation attributes and transforms onto each shape, so the stored artwork has one level of elements.
 * Unknown attributes such as `class` and `style` are dropped; unsupported elements throw.
 */
export function convertIconifyArtwork(name: string, artwork: IconifyArtwork): IconGlyph {
  const body = artwork.body.replace(/<!--[\s\S]*?-->/g, "")
  const stack: Frame[] = [{ attrs: {}, transform: transformFor(artwork), opacity: 1 }]
  const elements: IconElement[] = []

  for (const match of body.matchAll(TAG_PATTERN)) {
    const [, closing, tag, rawAttrs, selfClosing] = match
    if (closing) {
      if (tag === "g" && stack.length > 1) stack.pop()
      continue
    }
    if (tag === "g") {
      if (!selfClosing) stack.push(enterGroup(stack[stack.length - 1], parseAttributes(rawAttrs)))
      continue
    }
    if (SKIPPED_TAGS.has(tag)) continue
    if (!ALLOWED_TAGS.has(tag)) throw new IconImportError(`This icon uses <${tag}>, which Pelagik cannot import yet.`)
    elements.push(toElement(tag as IconTag, parseAttributes(rawAttrs), stack[stack.length - 1]))
    if (elements.length > MAX_ELEMENTS) throw new IconImportError("This icon has too many shapes to import.")
  }

  if (stack.length !== 1) throw new IconImportError("This icon has unbalanced groups.")
  if (elements.length === 0) throw new IconImportError("This icon has no drawable shapes.")
  return {
    name,
    viewBox: `${num(artwork.left)} ${num(artwork.top)} ${num(artwork.width)} ${num(artwork.height)}`,
    elements,
  }
}

function parseAttributes(raw: string): Record<string, string> {
  const attrs: Record<string, string> = {}
  for (const [, name, value] of raw.matchAll(ATTRIBUTE_PATTERN)) {
    if (!ALLOWED_ATTRIBUTES.has(name)) continue
    if (value.length > MAX_VALUE_LENGTH || !iconValue.test(value)) throw new IconImportError(`This icon has an unsupported ${name} value.`)
    attrs[name] = value
  }
  return attrs
}

function enterGroup(parent: Frame, attrs: Record<string, string>): Frame {
  const inherited = { ...parent.attrs }
  for (const name of INHERITED) if (attrs[name] !== undefined) inherited[name] = attrs[name]
  const opacity = attrs.opacity === undefined ? 1 : Number(attrs.opacity)
  return {
    attrs: inherited,
    transform: joinTransforms(parent.transform, attrs.transform),
    opacity: parent.opacity * (Number.isFinite(opacity) ? opacity : 1),
  }
}

function toElement(tag: IconTag, attrs: Record<string, string>, frame: Frame): IconElement {
  const out: Record<string, string> = {}
  for (const [name, value] of Object.entries(attrs)) {
    if (name !== "transform" && name !== "opacity") out[name] = value
  }
  for (const name of INHERITED) {
    if (out[name] === undefined && frame.attrs[name] !== undefined) out[name] = frame.attrs[name]
  }
  const transform = joinTransforms(frame.transform, attrs.transform)
  if (transform) out.transform = transform
  const opacity = frame.opacity * (attrs.opacity === undefined ? 1 : Number(attrs.opacity))
  if (Number.isFinite(opacity) && opacity < 1) out.opacity = num(opacity)
  return { tag, attrs: out }
}

/** Iconify stores rotation and flips separately. They pivot around the viewBox center. */
function transformFor({ left, top, width, height, rotate, hFlip, vFlip }: IconifyArtwork): string {
  const cx = left + width / 2
  const cy = top + height / 2
  const parts: string[] = []
  const quarterTurns = ((rotate % 4) + 4) % 4
  if (quarterTurns) parts.push(`rotate(${num(quarterTurns * 90)} ${num(cx)} ${num(cy)})`)
  if (hFlip) parts.push(`translate(${num(cx)} 0) scale(-1 1) translate(${num(-cx)} 0)`)
  if (vFlip) parts.push(`translate(0 ${num(cy)}) scale(1 -1) translate(0 ${num(-cy)})`)
  return parts.join(" ")
}

/** Outer transforms come first, so a child's own transform applies in its group's coordinate space. */
function joinTransforms(outer: string, inner: string | undefined): string {
  return [outer, inner].filter(Boolean).join(" ")
}

function num(value: number): string {
  return String(Math.round(value * 1000) / 1000)
}
