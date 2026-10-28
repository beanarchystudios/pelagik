import { expect, it } from "vitest"
import { gridSpacing } from "./grid"

it("keeps dots between 12 and 48 screen pixels apart at any zoom", () => {
  for (const zoom of [0.01, 0.1, 0.25, 0.5, 1, 2, 3.3, 8, 50]) {
    const spacing = gridSpacing(zoom)
    expect(spacing).toBeGreaterThanOrEqual(12)
    expect(spacing).toBeLessThanOrEqual(48)
  }
})

it("uses the 24 unit grid at 100% zoom and falls back to it for invalid zoom", () => {
  expect(gridSpacing(1)).toBe(24)
  expect(gridSpacing(0)).toBe(24)
  expect(gridSpacing(Number.NaN)).toBe(24)
})
