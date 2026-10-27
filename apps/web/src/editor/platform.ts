const isMac = typeof navigator !== "undefined" && /mac|iphone|ipad/i.test(navigator.platform)

/** Label for the primary modifier key in shortcut hints. */
export const MOD_KEY = isMac ? "⌘" : "Ctrl"
export const SHIFT_KEY = isMac ? "⇧" : "Shift"
