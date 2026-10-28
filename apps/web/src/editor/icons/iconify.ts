import type { IconGlyph } from "@pelagik/design-core/types"
import { convertIconifyArtwork, IconImportError, type IconifyArtwork } from "./convert"

/**
 * Icon search and artwork come from Iconify, which indexes these libraries under their prefixes.
 * Inserted icons keep their artwork in the document, so existing designs render without a network.
 */
const API = "https://api.iconify.design"
const SEARCH_LIMIT = 96
const NAME_PATTERN = /^[a-z0-9-]+:[a-z0-9-]+$/

export const ICON_LIBRARIES = [
  { prefix: "lucide", name: "Lucide" },
  { prefix: "hugeicons", name: "Hugeicons" },
  { prefix: "ph", name: "Phosphor" },
  { prefix: "tabler", name: "Tabler" },
  { prefix: "ri", name: "Remix" },
] as const

interface IconifyIconData {
  body?: unknown
  left?: number
  top?: number
  width?: number
  height?: number
  rotate?: number
  hFlip?: boolean
  vFlip?: boolean
}

interface IconifyAlias extends Omit<IconifyIconData, "body"> {
  parent?: unknown
}

interface IconifySetResponse extends Omit<IconifyIconData, "body"> {
  icons?: Record<string, IconifyIconData>
  aliases?: Record<string, IconifyAlias>
}

/** Glyphs already converted, keyed by `prefix:name`. Shared across searches so repeated results cost nothing. */
const glyphCache = new Map<string, IconGlyph>()
/** Icons Pelagik cannot import, so later searches skip them instead of fetching again. */
const unsupported = new Set<string>()
/** Collection names are small compared with icon artwork and are reused when reopening the picker. */
const collectionCache = new Map<string, string[]>()

export function iconLibraryName(prefix: string): string {
  return ICON_LIBRARIES.find((library) => library.prefix === prefix)?.name ?? prefix
}

export function splitIconName(name: string): { prefix: string; icon: string } {
  const [prefix = "", icon = ""] = name.split(":")
  return { prefix, icon }
}

/** Returns every icon name in an Iconify collection, including names in categories. */
export async function listCollectionIcons(prefix: string, signal?: AbortSignal): Promise<string[]> {
  const cached = collectionCache.get(prefix)
  if (cached) return cached

  const data = await request(`${API}/collection?prefix=${encodeURIComponent(prefix)}`, signal) as {
    uncategorized?: unknown
    categories?: Record<string, unknown>
  }
  const names = [
    ...(Array.isArray(data.uncategorized) ? data.uncategorized : []),
    ...Object.values(data.categories ?? {}).flatMap((icons) => Array.isArray(icons) ? icons : []),
  ].filter((name): name is string => typeof name === "string" && NAME_PATTERN.test(`${prefix}:${name}`))
  const uniqueNames = [...new Set(names.map((name) => `${prefix}:${name}`))]
  collectionCache.set(prefix, uniqueNames)
  return uniqueNames
}

/** Returns artwork already loaded by `loadIconGlyphs`, if any. */
export function getCachedIconGlyph(name: string): IconGlyph | undefined {
  return glyphCache.get(name)
}

/** Returns icon names (`prefix:name`) matching the query, limited to the given library prefixes when any are provided. */
export async function searchIcons(query: string, prefixes: readonly string[], signal?: AbortSignal): Promise<string[]> {
  const params = new URLSearchParams({ query, limit: String(SEARCH_LIMIT) })
  if (prefixes.length > 0) params.set("prefixes", prefixes.join(","))
  const data = await request(`${API}/search?${params}`, signal)
  const icons = (data as { icons?: unknown }).icons
  return Array.isArray(icons) ? icons.filter((name): name is string => typeof name === "string" && NAME_PATTERN.test(name)) : []
}

/**
 * Converts the named icons, fetching each library once. Icons that fail to load or use unsupported SVG
 * are left out of the result, so callers only receive glyphs they can insert.
 */
export async function loadIconGlyphs(names: readonly string[], signal?: AbortSignal): Promise<Map<string, IconGlyph>> {
  const missing = names.filter((name) => !glyphCache.has(name) && !unsupported.has(name))
  const byPrefix = new Map<string, string[]>()
  for (const name of missing) {
    const { prefix, icon } = splitIconName(name)
    byPrefix.set(prefix, [...(byPrefix.get(prefix) ?? []), icon])
  }

  await Promise.all([...byPrefix].map(async ([prefix, icons]) => {
    const query = icons.map(encodeURIComponent).join(",")
    const set = (await request(`${API}/${encodeURIComponent(prefix)}.json?icons=${query}`, signal)) as IconifySetResponse
    for (const icon of icons) {
      const name = `${prefix}:${icon}`
      const artwork = artworkFor(set, icon)
      if (!artwork) {
        unsupported.add(name)
        continue
      }
      try {
        glyphCache.set(name, convertIconifyArtwork(name, artwork))
      } catch (error) {
        if (!(error instanceof IconImportError)) throw error
        unsupported.add(name)
      }
    }
  }))

  return new Map(names.flatMap((name) => (glyphCache.has(name) ? [[name, glyphCache.get(name)!] as const] : [])))
}

/** Resolves an icon's artwork, following aliases and applying set-level size defaults. */
function artworkFor(set: IconifySetResponse, icon: string): IconifyArtwork | null {
  const alias = set.aliases?.[icon]
  const parentName = typeof alias?.parent === "string" ? alias.parent : icon
  const data = set.icons?.[parentName]
  if (!data || typeof data.body !== "string") return null
  // An alias applies its own rotation and flips on top of its parent's.
  const aliasTransform: Partial<IconifyAlias> = alias ?? {}
  return {
    body: data.body,
    left: data.left ?? set.left ?? 0,
    top: data.top ?? set.top ?? 0,
    width: data.width ?? set.width ?? 16,
    height: data.height ?? set.height ?? 16,
    rotate: (data.rotate ?? 0) + (aliasTransform.rotate ?? 0),
    hFlip: Boolean(data.hFlip) !== Boolean(aliasTransform.hFlip),
    vFlip: Boolean(data.vFlip) !== Boolean(aliasTransform.vFlip),
  }
}

async function request(url: string, signal?: AbortSignal): Promise<unknown> {
  let response: Response
  try {
    response = await fetch(url, { signal })
  } catch (error) {
    if (signal?.aborted) throw error
    throw new Error("Icon search needs an internet connection.")
  }
  if (!response.ok) throw new Error("Icon search is unavailable right now. Try again in a moment.")
  return response.json()
}
