const THEME_STORAGE_KEY = "pelagik:theme"
const DARK_QUERY = "(prefers-color-scheme: dark)"

/**
 * Applies the dark class from the system setting. A saved "light" or "dark" value overrides the system.
 * Re-applies when the system setting changes. Returns a cleanup for the listener.
 */
export function syncThemeWithSystem(): () => void {
  const media = window.matchMedia(DARK_QUERY)
  const apply = () => {
    const saved = window.localStorage.getItem(THEME_STORAGE_KEY)
    const dark = saved === "dark" || (saved !== "light" && media.matches)
    document.documentElement.classList.toggle("dark", dark)
  }
  apply()
  media.addEventListener("change", apply)
  return () => media.removeEventListener("change", apply)
}
