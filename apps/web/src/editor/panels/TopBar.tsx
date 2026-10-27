import { useEffect, useState } from "react"
import { Keyboard, Moon, Redo2, Sun, Undo2 } from "lucide-react"
import { PaintbrushIcon } from "@hugeicons/core-free-icons"
import { HugeiconsIcon } from "@hugeicons/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Separator } from "@/components/ui/separator"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { MOD_KEY, SHIFT_KEY } from "../platform"
import { useEditor } from "../state/store"

const THEME_STORAGE_KEY = "d3sign:theme"

export function TopBar() {
  const [darkMode, setDarkMode] = useState(() => window.localStorage.getItem(THEME_STORAGE_KEY) === "dark")
  const name = useEditor((s) => s.name)
  const setName = useEditor((s) => s.setName)
  const canUndo = useEditor((s) => s.past.length > 0)
  const canRedo = useEditor((s) => s.future.length > 0)
  const undo = useEditor((s) => s.undo)
  const redo = useEditor((s) => s.redo)
  const setHelpOpen = useEditor((s) => s.setHelpOpen)

  useEffect(() => {
    document.documentElement.classList.toggle("dark", darkMode)
    window.localStorage.setItem(THEME_STORAGE_KEY, darkMode ? "dark" : "light")
  }, [darkMode])

  return (
    <header className="flex h-9 items-center gap-1 border-b bg-sidebar px-3">
      <div aria-hidden="true" className="flex size-5 items-center justify-center text-chart-2">
        <HugeiconsIcon icon={PaintbrushIcon} size={18} strokeWidth={1.75} />
      </div>
      <Input
        aria-label="File name"
        value={name}
        onChange={(e) => setName(e.target.value)}
        className="h-7 w-56 border-transparent bg-transparent px-1 text-sm shadow-none hover:border-input focus-visible:border-input focus-visible:ring-0 dark:bg-transparent"
      />

      <div className="ml-auto flex items-center gap-1">
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label="Undo" disabled={!canUndo} onClick={() => undo()}>
              <Undo2 />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            Undo <span className="ml-1 opacity-70">{MOD_KEY} Z</span>
          </TooltipContent>
        </Tooltip>
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label="Redo" disabled={!canRedo} onClick={() => redo()}>
              <Redo2 />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            Redo <span className="ml-1 opacity-70">{SHIFT_KEY} {MOD_KEY} Z</span>
          </TooltipContent>
        </Tooltip>
        <Separator orientation="vertical" className="h-5 self-center!" />
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label="Keyboard shortcuts" onClick={() => setHelpOpen(true)}>
              <Keyboard />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            Keyboard shortcuts <span className="ml-1 opacity-70">?</span>
          </TooltipContent>
        </Tooltip>
        <Separator orientation="vertical" className="h-5 self-center!" />
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={darkMode ? "Switch to light mode" : "Switch to dark mode"}
              aria-pressed={darkMode}
              onClick={() => setDarkMode((current) => !current)}
            >
              {darkMode ? <Sun /> : <Moon />}
            </Button>
          </TooltipTrigger>
          <TooltipContent>{darkMode ? "Switch to light mode" : "Switch to dark mode"}</TooltipContent>
        </Tooltip>
      </div>
    </header>
  )
}
