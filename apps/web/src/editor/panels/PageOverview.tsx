import { boundsOfIds } from "@pelagik/design-core/document"
import { fitBounds } from "@pelagik/design-core/viewport"
import { Kbd } from "@pelagik/ui/components/kbd"
import { useEditor } from "../state/store"

/** Shown when nothing is selected. One row per top-level artboard. Clicking a row frames it on the canvas. */
export function PageOverview() {
  const rootIds = useEditor((s) => s.doc.rootIds)
  // Child lists run back-to-front. Reverse them so the topmost artboard comes first, as in the layers panel.
  const artboards = [...rootIds].reverse()

  if (artboards.length === 0) {
    return (
      <p className="px-3 py-6 text-center text-xs text-muted-foreground">
        An empty page. Press <Kbd>F</Kbd> to draw an artboard, or ask an agent to design one.
      </p>
    )
  }

  return (
    <ul className="flex flex-col gap-0.5 p-1.5">
      {artboards.map((id) => (
        <ArtboardRow key={id} id={id} />
      ))}
    </ul>
  )
}

function ArtboardRow({ id }: { id: string }) {
  const node = useEditor((s) => s.doc.nodes[id])
  if (!node) return null

  // The thumbnail keeps the artboard's proportions and is capped, so tall boards don't crowd the row.
  const scale = Math.min(48 / Math.max(node.width, 1), 36 / Math.max(node.height, 1))

  return (
    <li>
      <button
        type="button"
        onClick={() => focusArtboard(id)}
        className="flex w-full items-center gap-2.5 rounded-md px-2 py-1.5 text-left text-xs hover:bg-muted"
      >
        <span aria-hidden="true" className="flex size-12 shrink-0 items-center justify-center">
          <span
            className="rounded-[2px] border border-border"
            style={{ width: node.width * scale, height: node.height * scale, backgroundColor: node.fill ?? "transparent" }}
          />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate font-medium">{node.name}</span>
          <span className="block font-mono text-[11px] text-muted-foreground">
            {Math.round(node.width)} × {Math.round(node.height)}
          </span>
        </span>
      </button>
    </li>
  )
}

function focusArtboard(id: string) {
  const s = useEditor.getState()
  s.setSelection([id])
  const bounds = boundsOfIds(s.doc, [id])
  if (bounds) s.setViewport(fitBounds(bounds, s.canvasSize))
}
