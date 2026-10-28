import { useEffect } from "react"
import { useEditor } from "../state/store"
import * as cmd from "../state/commands"
import type { StackOrder, Tool } from "@pelagik/design-core/types"

const TOOL_KEYS: Record<string, Tool> = {
  v: "select",
  h: "hand",
  f: "frame",
  r: "rectangle",
  o: "ellipse",
  t: "text",
}

const ARROW_STEPS: Record<string, [number, number]> = {
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
}

const ZOOM_STEP = 1.25

/** Shift + digit view shortcuts, keyed by physical key so they work on any layout. */
const VIEW_KEYS: Record<string, () => void> = {
  Digit1: () => cmd.zoomToFit(),
  Digit2: () => cmd.zoomToSelection(),
  Digit0: () => cmd.zoomTo(1),
}

/** Keys typed into fields, or into an open menu or dialog, belong to that control, not the canvas. */
function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false
  if (target.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName)) return true
  return target.closest("[role=listbox], [role=menu], [role=dialog]") !== null
}

/** Editor-wide keyboard shortcuts. Ignored while typing in a field. */
export function useKeyboardShortcuts() {
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (isEditableTarget(e.target)) return
      const s = useEditor.getState()

      if (e.code === "Space") {
        if (!e.repeat) s.setSpaceHeld(true)
        e.preventDefault()
        return
      }

      const mod = e.metaKey || e.ctrlKey
      if (mod) {
        const key = e.key.toLowerCase()
        const handled = runModifierShortcut(e, key)
        if (handled) e.preventDefault()
        return
      }

      if (e.altKey) return

      if (e.shiftKey && VIEW_KEYS[e.code]) {
        e.preventDefault()
        VIEW_KEYS[e.code]()
        return
      }

      const key = e.key.toLowerCase()
      if (!e.shiftKey && TOOL_KEYS[key]) {
        s.setTool(TOOL_KEYS[key])
        return
      }
      if (!e.shiftKey && key === "i") {
        s.setIconPickerOpen(true)
        return
      }

      switch (e.key) {
        case "Escape":
          if (s.tool !== "select") s.setTool("select")
          else s.setSelection([])
          return
        case "Backspace":
        case "Delete":
          e.preventDefault()
          cmd.deleteSelection()
          return
        case "Enter": {
          const ids = s.selectedIds
          if (ids.length === 1 && s.doc.nodes[ids[0]]?.type === "text") {
            e.preventDefault()
            cmd.beginTextEdit(ids[0])
          }
          return
        }
        case "?":
          s.setHelpOpen(!s.helpOpen)
          return
      }

      const step = ARROW_STEPS[e.key]
      if (step) {
        e.preventDefault()
        const amount = e.shiftKey ? 10 : 1
        cmd.nudgeSelection(step[0] * amount, step[1] * amount)
      }
    }

    const onKeyUp = (e: KeyboardEvent) => {
      if (e.code === "Space") useEditor.getState().setSpaceHeld(false)
    }

    const onBlur = () => useEditor.getState().setSpaceHeld(false)

    window.addEventListener("keydown", onKeyDown)
    window.addEventListener("keyup", onKeyUp)
    window.addEventListener("blur", onBlur)
    return () => {
      window.removeEventListener("keydown", onKeyDown)
      window.removeEventListener("keyup", onKeyUp)
      window.removeEventListener("blur", onBlur)
    }
  }, [])
}

/** Returns true when the key combination was handled. */
function runModifierShortcut(e: KeyboardEvent, key: string): boolean {
  if (e.code === "BracketRight" || e.code === "BracketLeft") {
    const order: StackOrder = e.code === "BracketRight" ? (e.shiftKey ? "front" : "forward") : e.shiftKey ? "back" : "backward"
    cmd.reorderSelection(order)
    return true
  }
  if (e.code === "Equal" || e.code === "NumpadAdd") {
    cmd.zoomBy(ZOOM_STEP)
    return true
  }
  if (e.code === "Minus" || e.code === "NumpadSubtract") {
    cmd.zoomBy(1 / ZOOM_STEP)
    return true
  }

  switch (key) {
    case "z":
      if (e.shiftKey) useEditor.getState().redo()
      else useEditor.getState().undo()
      return true
    case "y":
      useEditor.getState().redo()
      return true
    case "c":
      cmd.copySelection()
      return true
    case "v":
      cmd.pasteClipboard()
      return true
    case "d":
      cmd.duplicateSelection()
      return true
    case "a":
      cmd.selectAll()
      return true
    case "g":
      if (e.shiftKey) cmd.ungroupSelection()
      else cmd.groupSelection()
      return true
    default:
      return false
  }
}
