import type { Bounds, Point, Viewport } from "./types"

export const MIN_ZOOM = 0.02
export const MAX_ZOOM = 256

export function clampZoom(zoom: number): number {
  return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, zoom))
}

export function screenToWorld(viewport: Viewport, point: Point): Point {
  return { x: (point.x - viewport.x) / viewport.zoom, y: (point.y - viewport.y) / viewport.zoom }
}

export function worldToScreen(viewport: Viewport, point: Point): Point {
  return { x: point.x * viewport.zoom + viewport.x, y: point.y * viewport.zoom + viewport.y }
}

/** Changes zoom while keeping the page point under `screenPoint` fixed on screen. */
export function zoomAround(viewport: Viewport, screenPoint: Point, zoom: number): Viewport {
  const nextZoom = clampZoom(zoom)
  const world = screenToWorld(viewport, screenPoint)
  return {
    zoom: nextZoom,
    x: screenPoint.x - world.x * nextZoom,
    y: screenPoint.y - world.y * nextZoom,
  }
}

export function fitBounds(bounds: Bounds, size: { width: number; height: number }, padding = 80): Viewport {
  const width = Math.max(1, bounds.maxX - bounds.minX)
  const height = Math.max(1, bounds.maxY - bounds.minY)
  const availableWidth = Math.max(1, size.width - padding * 2)
  const availableHeight = Math.max(1, size.height - padding * 2)
  const zoom = clampZoom(Math.min(availableWidth / width, availableHeight / height))
  return {
    zoom,
    x: (size.width - width * zoom) / 2 - bounds.minX * zoom,
    y: (size.height - height * zoom) / 2 - bounds.minY * zoom,
  }
}
