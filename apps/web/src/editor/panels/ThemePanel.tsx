import { Plus, Search, Trash2 } from "lucide-react"
import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { ScrollArea } from "@/components/ui/scroll-area"
import { cn } from "cn"
import type { DesignVariable } from "../model/types"
import { changeVariableValue, createVariable, removeVariable, renameVariableCommand } from "../state/commands"
import { useEditor } from "../state/store"
import { ColorField, normalizeHex } from "./fields"

const GROUPS = [{ type: "color", title: "Colors" }] as const

export function ThemePanel() {
  const variables = useEditor((s) => s.doc.variables)
  const [searching, setSearching] = useState(false)
  const [query, setQuery] = useState("")
  const [openId, setOpenId] = useState<string | null>(null)

  const all = Object.values(variables)
  const needle = query.trim().toLowerCase()
  const visible = all.filter((variable) => variable.name.toLowerCase().includes(needle))

  const closeSearch = () => {
    setSearching(false)
    setQuery("")
  }

  const add = () => {
    // A new token is shown even when a search is active, so the search is cleared first.
    closeSearch()
    setOpenId(createVariable())
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex h-9 shrink-0 items-center justify-between border-b px-3">
        <span className="text-xs text-muted-foreground">
          {all.length} {all.length === 1 ? "token" : "tokens"}
        </span>
        <div className="flex items-center gap-0.5">
          <Button
            variant="ghost"
            size="icon-xs"
            aria-label="Search tokens"
            aria-pressed={searching}
            onClick={() => (searching ? closeSearch() : setSearching(true))}
          >
            <Search />
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-xs" aria-label="Add token">
                <Plus />
              </Button>
            </DropdownMenuTrigger>
            {/* Focus goes to the new token's popover, not back to the + button, which would dismiss it. */}
            <DropdownMenuContent align="end" onCloseAutoFocus={(e) => e.preventDefault()}>
              <DropdownMenuItem onSelect={add}>Color token</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {searching && (
        <div className="shrink-0 border-b p-2">
          <Input
            autoFocus
            aria-label="Filter tokens"
            placeholder="Search tokens"
            value={query}
            className="h-7 text-xs"
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Escape") closeSearch()
            }}
          />
        </div>
      )}

      <ScrollArea className="min-h-0 flex-1">
        <div className="flex flex-col py-1">
          {GROUPS.map(({ type, title }) => {
            const items = visible.filter((variable) => variable.type === type)
            // A group only appears while it has tokens to show.
            if (items.length === 0) return null
            return (
              <section key={type} className="flex flex-col">
                <h3 className="px-3 pt-2 pb-1 text-xs text-muted-foreground">{title}</h3>
                {items.map((variable) => (
                  <VariableItem
                    key={variable.id}
                    variable={variable}
                    open={openId === variable.id}
                    onOpenChange={(next) => setOpenId(next ? variable.id : null)}
                  />
                ))}
              </section>
            )
          })}
          {all.length === 0 && (
            <p className="px-3 py-6 text-center text-xs text-muted-foreground">No tokens yet. Use + to add one.</p>
          )}
          {all.length > 0 && visible.length === 0 && (
            <p className="px-3 py-6 text-center text-xs text-muted-foreground">No tokens match "{query}".</p>
          )}
        </div>
      </ScrollArea>
    </div>
  )
}

function displayValue(variable: DesignVariable): string {
  return (normalizeHex(variable.value) ?? variable.value).toUpperCase()
}

/** One token row, 28px tall like the layers list. Clicking it opens the editor in a popover to its right. */
function VariableItem({
  variable,
  open,
  onOpenChange,
}: {
  variable: DesignVariable
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  return (
    <Popover open={open} onOpenChange={onOpenChange}>
      <PopoverTrigger asChild>
        <button
          type="button"
          className={cn(
            "flex h-7 w-full items-center gap-2 px-3 text-left text-xs hover:bg-muted",
            open && "bg-accent text-accent-foreground",
          )}
        >
          <span
            className="size-3.5 shrink-0 rounded-sm border"
            style={{ backgroundColor: normalizeHex(variable.value) ?? undefined }}
          />
          <span className="min-w-0 flex-1 truncate">{variable.name}</span>
          <span className="shrink-0 font-mono text-[11px] text-muted-foreground">{displayValue(variable)}</span>
        </button>
      </PopoverTrigger>
      <PopoverContent side="right" align="center" sideOffset={8} bordered={false} className="w-64 p-3">
        <VariableEditor variable={variable} />
      </PopoverContent>
    </Popover>
  )
}

function VariableEditor({ variable }: { variable: DesignVariable }) {
  const [name, setName] = useState(variable.name)
  useEffect(() => setName(variable.name), [variable.name])

  const commitName = () => {
    const trimmed = name.trim()
    // An empty name is discarded, so the field goes back to the saved name.
    if (trimmed) renameVariableCommand(variable.id, trimmed)
    else setName(variable.name)
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center gap-1">
        <Input
          aria-label="Token name"
          value={name}
          className="h-7 min-w-0 flex-1 text-xs"
          onChange={(e) => setName(e.target.value)}
          onBlur={commitName}
          onKeyDown={(e) => {
            if (e.key === "Enter") e.currentTarget.blur()
          }}
        />
        <Button variant="ghost" size="icon-xs" aria-label={`Delete ${variable.name}`} onClick={() => removeVariable(variable.id)}>
          <Trash2 />
        </Button>
      </div>
      <ColorField
        value={variable.value}
        field={`token-${variable.id}`}
        onChange={(hex, key) => changeVariableValue(variable.id, hex, key)}
      />
    </div>
  )
}
