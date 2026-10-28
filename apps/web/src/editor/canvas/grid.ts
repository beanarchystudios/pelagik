/** Dot spacing in world units at 100% zoom. */
const BASE_SPACING = 24
/** Screen-pixel limits for dot spacing. Closer than this the dots blur together; farther and the grid stops reading as a grid. */
const MIN_SCREEN_SPACING = 12
const MAX_SCREEN_SPACING = 48

/**
 * Dot spacing in screen pixels. The world grid doubles or halves until the dots land inside the limits,
 * so the grid stays readable at any zoom. Every step keeps the world origin on a dot.
 */
export function gridSpacing(zoom: number): number {
  if (!Number.isFinite(zoom) || zoom <= 0) return BASE_SPACING
  let world = BASE_SPACING
  while (world * zoom < MIN_SCREEN_SPACING) world *= 2
  while (world * zoom > MAX_SCREEN_SPACING) world /= 2
  return world * zoom
}
