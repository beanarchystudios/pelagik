import { afterEach, beforeEach, expect, it, vi } from "vitest"
import { syncThemeWithSystem } from "./theme"

let systemDark = false
let listeners: Array<() => void> = []
let classes: Set<string>
let storage: Map<string, string>

beforeEach(() => {
  systemDark = false
  listeners = []
  classes = new Set()
  storage = new Map()
  vi.stubGlobal("window", {
    localStorage: {
      getItem: (key: string) => storage.get(key) ?? null,
    },
    matchMedia: () => ({
      get matches() { return systemDark },
      addEventListener: (_: string, listener: () => void) => listeners.push(listener),
      removeEventListener: (_: string, listener: () => void) => { listeners = listeners.filter((item) => item !== listener) },
    }),
  })
  vi.stubGlobal("document", {
    documentElement: {
      classList: {
        toggle: (name: string, force: boolean) => (force ? classes.add(name) : classes.delete(name)),
      },
    },
  })
})
afterEach(() => {
  vi.unstubAllGlobals()
})

it("follows the system setting when nothing is saved", () => {
  systemDark = true
  syncThemeWithSystem()
  expect(classes.has("dark")).toBe(true)

  systemDark = false
  syncThemeWithSystem()
  expect(classes.has("dark")).toBe(false)
})

it("lets a saved theme override the system setting", () => {
  systemDark = true
  storage.set("pelagik:theme", "light")
  syncThemeWithSystem()
  expect(classes.has("dark")).toBe(false)

  storage.set("pelagik:theme", "dark")
  systemDark = false
  syncThemeWithSystem()
  expect(classes.has("dark")).toBe(true)
})

it("re-applies when the system setting changes and stops after cleanup", () => {
  const cleanup = syncThemeWithSystem()
  expect(classes.has("dark")).toBe(false)

  systemDark = true
  listeners.forEach((listener) => listener())
  expect(classes.has("dark")).toBe(true)

  cleanup()
  expect(listeners).toHaveLength(0)
})
