import { createElement, type CSSProperties } from "react"
import type { IconGlyph } from "@pelagik/design-core/types"

/**
 * Draws icon artwork as React elements. Artwork comes from documents and agents, so it is never
 * injected as markup. Shapes inherit `currentColor` from the `color` set here.
 */
export function IconGlyphView({ glyph, color, className, style }: { glyph: IconGlyph; color: string; className?: string; style?: CSSProperties }) {
  return (
    <svg
      viewBox={glyph.viewBox}
      fill="currentColor"
      className={className}
      style={{ color, overflow: "visible", ...style }}
      aria-hidden="true"
      focusable="false"
    >
      {glyph.elements.map((element, index) => createElement(element.tag, { key: index, ...toReactAttributes(element.attrs) }))}
    </svg>
  )
}

/** SVG attribute names are hyphenated; React expects camel case, such as `strokeWidth`. */
function toReactAttributes(attrs: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(attrs).map(([name, value]) => [name.replace(/-([a-z])/g, (_, letter: string) => letter.toUpperCase()), value]))
}
