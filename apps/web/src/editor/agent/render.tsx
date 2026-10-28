import { createRoot } from "react-dom/client"
import { flushSync } from "react-dom"
import { toPng } from "html-to-image"
import { AgentError } from "@pelagik/agent-api/schema"
import type { Bounds } from "@pelagik/design-core/types"
import { SceneNodeView } from "../canvas/SceneNodeView"
import { useEditor } from "../state/store"

export async function renderDocument(bounds: Bounds, scale: number) {
  const width = Math.max(1, Math.ceil(bounds.maxX - bounds.minX))
  const height = Math.max(1, Math.ceil(bounds.maxY - bounds.minY))
  const pixelWidth = Math.ceil(width * scale)
  const pixelHeight = Math.ceil(height * scale)
  if (pixelWidth > 4096 || pixelHeight > 4096 || pixelWidth * pixelHeight > 16_000_000) {
    throw new AgentError("RENDER_TOO_LARGE", "Reduce the crop or scale. Maximum 4096 pixels per side and 16 million pixels.")
  }
  const host = document.createElement("div")
  host.style.cssText = "position:fixed;left:-100000px;top:0;pointer-events:none;"
  host.setAttribute("aria-hidden", "true")
  document.body.append(host)
  const root = createRoot(host)
  try {
    flushSync(() => root.render(
      <div style={{ position: "relative", width, height, overflow: "hidden", background: "white", fontFamily: "var(--font-sans)" }}>
        <div style={{ position: "absolute", left: -bounds.minX, top: -bounds.minY }}>
          {useEditor.getState().doc.rootIds.map(id => <SceneNodeView key={id} id={id} showLabels={false} />)}
        </div>
      </div>,
    ))
    let timeout: ReturnType<typeof setTimeout> | undefined
    let dataUrl: string
    try {
      dataUrl = await Promise.race([
        (async () => {
          await document.fonts.ready
          return toPng(host.firstElementChild as HTMLElement, { pixelRatio: 1, canvasWidth: pixelWidth, canvasHeight: pixelHeight, width, height, cacheBust: false, skipAutoScale: true })
        })(),
        new Promise<never>((_, reject) => { timeout = setTimeout(() => reject(new AgentError("RENDER_TIMEOUT", "PNG capture exceeded 10 seconds")), 10000) }),
      ])
    } finally { clearTimeout(timeout) }
    const png = dataUrl.slice(dataUrl.indexOf(",") + 1)
    if (png.length > 22_369_624) throw new AgentError("RENDER_TOO_LARGE", "PNG exceeds 16 MiB")
    return { png, mimeType: "image/png", width: pixelWidth, height: pixelHeight, bounds, scale }
  } finally { root.unmount(); host.remove() }
}
