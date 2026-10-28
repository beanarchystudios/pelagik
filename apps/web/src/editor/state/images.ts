import { createNode } from "@pelagik/design-core/document"
import { frameAt } from "@pelagik/design-core/hit-test"
import { addNodeAt } from "@pelagik/design-core/operations"
import type { Point } from "@pelagik/design-core/types"
import { screenToWorld } from "@pelagik/design-core/viewport"
import { useEditor } from "./store"

const supported = new Set(["image/png", "image/jpeg", "image/gif", "image/webp"])

async function readImage(file: File): Promise<{ src: string; width: number; height: number }> {
  const src = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
  const image = new Image()
  image.src = src
  await image.decode()
  return { src, width: image.naturalWidth, height: image.naturalHeight }
}

export async function insertImages(files: File[], point?: Point) {
  const images = await Promise.all(files.filter(file => supported.has(file.type) && file.size <= 15_000_000).map(async file => {
    try { return { file, ...await readImage(file) } } catch { return null }
  }))
  const s = useEditor.getState()
  const center = point ?? screenToWorld(s.viewport, { x: s.canvasSize.width / 2, y: s.canvasSize.height / 2 })
  let doc = s.doc
  const ids: string[] = []
  for (const image of images) {
    if (!image || !image.width || !image.height) continue
    const scale = Math.min(1, 1000 / Math.max(image.width, image.height))
    const width = Math.max(1, Math.round(image.width * scale))
    const height = Math.max(1, Math.round(image.height * scale))
    const offset = ids.length * 20
    const box = { x: center.x - width / 2 + offset, y: center.y - height / 2 + offset, width, height }
    const node = { ...createNode(doc, "image", box), name: image.file.name, image: image.src }
    doc = addNodeAt(doc, node, box, frameAt(doc, center))
    ids.push(node.id)
  }
  if (ids.length) {
    s.commit(doc)
    s.setSelection(ids)
    s.setTool("select")
  }
}
