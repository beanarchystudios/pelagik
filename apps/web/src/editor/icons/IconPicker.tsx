import { useEffect, useMemo, useRef, useState } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@pelagik/ui/components/dialog"
import { Input } from "@pelagik/ui/components/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@pelagik/ui/components/select"
import { insertIcon } from "../state/commands"
import { useEditor } from "../state/store"
import { IconGlyphView } from "./IconGlyphView"
import { getCachedIconGlyph, ICON_LIBRARIES, iconLibraryName, listCollectionIcons, loadIconGlyphs, searchIcons, splitIconName } from "./iconify"

const ALL_LIBRARIES = "all"
const SEARCH_DELAY_MS = 250
const GRID_COLUMNS = 8
const GRID_ROW_HEIGHT = 40
const GRID_ROW_GAP = 4
const GRID_ROW_PITCH = GRID_ROW_HEIGHT + GRID_ROW_GAP
const VIEWPORT_HEIGHT = 320
const ROW_OVERSCAN = 2

export function IconPicker() {
  const open = useEditor((s) => s.iconPickerOpen)
  const setOpen = useEditor((s) => s.setIconPickerOpen)
  const [query, setQuery] = useState("")
  const [library, setLibrary] = useState(ALL_LIBRARIES)
  const [names, setNames] = useState<string[]>([])
  const [loading, setLoading] = useState(false)
  const [loadingArtwork, setLoadingArtwork] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [scrollTop, setScrollTop] = useState(0)
  const [, setGlyphVersion] = useState(0)
  const viewportRef = useRef<HTMLDivElement>(null)
  const trimmed = query.trim()

  // The empty query browses every icon in the selected collection(s). Search stays debounced.
  useEffect(() => {
    if (!open) return
    const controller = new AbortController()
    setNames([])
    setError(null)
    setLoading(true)
    setLoadingArtwork(false)
    setScrollTop(0)
    if (viewportRef.current) viewportRef.current.scrollTop = 0

    const prefixes = library === ALL_LIBRARIES ? ICON_LIBRARIES.map(({ prefix }) => prefix) : [library]
    const loadNames = () => trimmed === ""
      ? Promise.all(prefixes.map((prefix) => listCollectionIcons(prefix, controller.signal))).then((collections) => collections.flat())
      : searchIcons(trimmed, prefixes, controller.signal)

    const timer = window.setTimeout(() => {
      loadNames()
        .then((nextNames) => {
          if (controller.signal.aborted) return
          setNames([...new Set(nextNames)])
          setLoading(false)
        })
        .catch((cause: unknown) => {
          if (controller.signal.aborted) return
          setNames([])
          setLoading(false)
          setError(cause instanceof Error ? cause.message : "Icon search failed.")
        })
    }, trimmed === "" ? 0 : SEARCH_DELAY_MS)

    return () => {
      window.clearTimeout(timer)
      controller.abort()
    }
  }, [open, trimmed, library])

  const totalRows = Math.ceil(names.length / GRID_COLUMNS)
  const firstRow = Math.max(0, Math.floor(scrollTop / GRID_ROW_PITCH) - ROW_OVERSCAN)
  const visibleRowCount = Math.ceil(VIEWPORT_HEIGHT / GRID_ROW_PITCH) + ROW_OVERSCAN * 2
  const endRow = Math.min(totalRows, firstRow + visibleRowCount)
  const visibleNames = useMemo(
    () => names.slice(firstRow * GRID_COLUMNS, endRow * GRID_COLUMNS),
    [names, firstRow, endRow],
  )

  // Fetch artwork only for the visible rows. The catalog has tens of thousands of icons.
  useEffect(() => {
    if (!open || visibleNames.length === 0) return
    const controller = new AbortController()
    const missing = visibleNames.filter((name) => !getCachedIconGlyph(name))
    if (missing.length === 0) {
      setLoadingArtwork(false)
      return
    }

    setLoadingArtwork(true)
    loadIconGlyphs(missing, controller.signal)
      .then(() => {
        if (controller.signal.aborted) return
        setGlyphVersion((version) => version + 1)
        setLoadingArtwork(false)
      })
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return
        setLoadingArtwork(false)
        setError(cause instanceof Error ? cause.message : "Icon artwork could not be loaded.")
      })
    return () => controller.abort()
  }, [open, visibleNames])

  const insert = (name: string) => {
    const glyph = getCachedIconGlyph(name)
    if (!glyph) return
    insertIcon(glyph)
    setOpen(false)
  }

  const status = error
    ?? (loading ? (trimmed === "" ? "Loading icon libraries…" : "Searching icons…")
      : loadingArtwork ? "Loading icons…"
        : names.length === 0
          ? trimmed === "" ? "No icons are available." : `No icons match “${trimmed}”.`
          : trimmed === ""
            ? `${names.length.toLocaleString()} icons available. Type to filter.`
            : `${names.length.toLocaleString()} icons found.`)

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Insert icon</DialogTitle>
        </DialogHeader>
        <div className="flex gap-2">
          <Input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search icons"
            aria-label="Search icons"
          />
          <Select value={library} onValueChange={setLibrary}>
            <SelectTrigger aria-label="Icon library" className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL_LIBRARIES}>All libraries</SelectItem>
              {ICON_LIBRARIES.map(({ prefix, name }) => (
                <SelectItem key={prefix} value={prefix}>
                  {name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div
          ref={viewportRef}
          className="h-80 overflow-y-auto rounded-md"
          aria-label="Icon results"
          onScroll={(event) => setScrollTop(event.currentTarget.scrollTop)}
        >
          <div className="relative px-1" style={{ height: totalRows * GRID_ROW_PITCH }}>
            {Array.from({ length: endRow - firstRow }, (_, rowOffset) => {
              const row = firstRow + rowOffset
              return (
                <div
                  key={row}
                  className="absolute left-1 right-1 grid grid-cols-8 gap-1"
                  style={{ top: row * GRID_ROW_PITCH, height: GRID_ROW_HEIGHT }}
                >
                  {names.slice(row * GRID_COLUMNS, (row + 1) * GRID_COLUMNS).map((name) => {
                    const glyph = getCachedIconGlyph(name)
                    const { prefix, icon } = splitIconName(name)
                    return (
                      <button
                        key={name}
                        type="button"
                        title={name}
                        aria-label={`Insert ${icon} from ${iconLibraryName(prefix)}`}
                        disabled={!glyph}
                        onClick={() => insert(name)}
                        className="flex h-10 w-full items-center justify-center rounded-md text-foreground outline-none hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-default"
                      >
                        {glyph && <IconGlyphView glyph={glyph} color="currentColor" className="size-5" />}
                      </button>
                    )
                  })}
                </div>
              )
            })}
          </div>
        </div>
        <p role="status" className={error ? "text-xs text-destructive" : "text-xs text-muted-foreground"}>
          {status}
        </p>
      </DialogContent>
    </Dialog>
  )
}
