import { Grid2X2, Minus, Plus } from "lucide-react"
import { useEffect, useState, type ReactNode } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { evaluateExpression } from "@/lib/expression"
import type { DesignVariable } from "../model/types"

export function Section({ title, action, children }: { title: string; action?: ReactNode; children?: ReactNode }) {
  return (
    <section className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <h3 className="text-xs font-medium text-foreground">{title}</h3>
        {action}
      </div>
      {children}
    </section>
  )
}

export function AddButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <Button variant="ghost" size="icon-xs" aria-label={label} onClick={onClick}>
      <Plus />
    </Button>
  )
}

export function RemoveButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <Button variant="ghost" size="icon-xs" aria-label={label} onClick={onClick}>
      <Minus />
    </Button>
  )
}

function formatNumber(value: number): string {
  return String(Math.round(value))
}

interface NumberFieldProps {
  label: string
  /** Tailwind width class for the label. Single letters use a narrow column. */
  labelWidth?: string
  value: number
  suffix?: string
  min?: number
  max?: number
  disabled?: boolean
  onCommit: (value: number) => void
}

/**
 * Commits on blur or Enter, so typing a value creates one undo step instead of one per keystroke.
 * Accepts arithmetic such as "3*4"; the result rounds to a whole number.
 */
export function NumberField({ label, labelWidth = "w-12", value, suffix, min, max, disabled, onCommit }: NumberFieldProps) {
  const [draft, setDraft] = useState(formatNumber(value))
  const [focused, setFocused] = useState(false)

  useEffect(() => {
    if (!focused) setDraft(formatNumber(value))
  }, [value, focused])

  const clamp = (n: number) => Math.min(max ?? Infinity, Math.max(min ?? -Infinity, n))

  const commit = () => {
    const parsed = evaluateExpression(draft)
    if (parsed === null) {
      setDraft(formatNumber(value))
      return
    }
    const clamped = clamp(Math.round(parsed))
    if (clamped !== value) onCommit(clamped)
    setDraft(formatNumber(clamped))
  }

  return (
    <div className="flex items-center gap-2">
      <Label className={`${labelWidth} shrink-0 text-xs font-normal text-muted-foreground`}>{label}</Label>
      <div className="relative min-w-0 flex-1">
        <Input
          aria-label={label}
          value={draft}
          disabled={disabled}
          className="h-7 px-2 text-xs tabular-nums"
          onFocus={() => setFocused(true)}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={() => {
            setFocused(false)
            commit()
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter") e.currentTarget.blur()
            // Up and down step the value by one, as a native number input did before this became text.
            if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return
            e.preventDefault()
            const base = Math.round(evaluateExpression(draft) ?? value)
            setDraft(formatNumber(clamp(base + (e.key === "ArrowUp" ? 1 : -1))))
          }}
        />
        {suffix && (
          <span className="pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 text-xs text-muted-foreground">
            {suffix}
          </span>
        )}
      </div>
    </div>
  )
}

const HEX_PATTERN = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i

export function normalizeHex(value: string): string | null {
  const match = HEX_PATTERN.exec(value.trim())
  if (!match) return null
  const body = match[1].length === 3 ? [...match[1]].map((c) => c + c).join("") : match[1]
  return `#${body.toLowerCase()}`
}

export function ColorField({
  value,
  field,
  onChange,
  trailingAction,
}: {
  value: string
  field: string
  onChange: (value: string, key: string) => void
  trailingAction?: ReactNode
}) {
  const [draft, setDraft] = useState(normalizeHex(value)?.slice(1).toUpperCase() ?? value)
  useEffect(() => setDraft(normalizeHex(value)?.slice(1).toUpperCase() ?? value), [value])

  const swatch = normalizeHex(value) ?? "#000000"
  const coalesce = `${field}-color`

  return (
    <div className="flex h-7 min-w-0 items-center gap-2 rounded-md border border-input bg-input/30 px-1.5 transition-colors focus-within:border-ring focus-within:ring-2 focus-within:ring-ring/30 dark:hover:bg-input/50">
      <label className="relative size-3.5 shrink-0 cursor-pointer overflow-hidden rounded-[2px] border border-foreground/20" style={{ backgroundColor: swatch }}>
        <input
          type="color"
          aria-label={`${field} color`}
          value={swatch}
          onChange={(e) => onChange(e.target.value, coalesce)}
          className="absolute inset-0 size-full cursor-pointer opacity-0"
        />
      </label>
      <Input
        aria-label={`${field} hex`}
        value={draft}
        className="h-full min-w-0 flex-1 rounded-none border-0 bg-transparent px-0 py-0 font-mono text-xs uppercase shadow-none focus-visible:border-0 focus-visible:ring-0 dark:bg-transparent"
        onChange={(e) => setDraft(e.target.value)}
        onBlur={() => {
          const hex = normalizeHex(draft)
          if (hex && hex !== swatch) onChange(hex, `${field}-hex`)
          setDraft((hex ?? swatch).slice(1).toUpperCase())
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter") e.currentTarget.blur()
        }}
      />
      <span aria-hidden="true" className="shrink-0 text-[11px] text-muted-foreground">100%</span>
      {trailingAction}
    </div>
  )
}

const NO_VARIABLE = "none"

/**
 * Picks the variable a property is linked to. Renders nothing when there are no variables of
 * the right type, so the design panel stays uncluttered until variables exist.
 */
export function VariableSelect({
  variables,
  value,
  onChange,
  label = "Variable",
  compact = false,
}: {
  variables: DesignVariable[]
  value: string | undefined
  onChange: (id: string | null) => void
  label?: string
  compact?: boolean
}) {
  if (variables.length === 0) return null
  if (compact) {
    return (
      <Select value={value ?? NO_VARIABLE} onValueChange={(next) => onChange(next === NO_VARIABLE ? null : next)}>
        <SelectTrigger
          size="sm"
          className="size-5 shrink-0 border-0 bg-transparent p-0 text-foreground shadow-none hover:bg-muted focus-visible:ring-0 [&>svg:last-child]:hidden"
          aria-label={`${label} binding`}
          title={label}
        >
          <span className="sr-only"><SelectValue /></span>
          <Grid2X2 className="size-3.5" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value={NO_VARIABLE}>None</SelectItem>
          {variables.map((variable) => (
            <SelectItem key={variable.id} value={variable.id}>
              {variable.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    )
  }
  return (
    <div className="flex items-center gap-2">
      <Label className="w-12 shrink-0 text-xs font-normal text-muted-foreground">{label}</Label>
      <Select value={value ?? NO_VARIABLE} onValueChange={(next) => onChange(next === NO_VARIABLE ? null : next)}>
        <SelectTrigger size="sm" className="h-7 w-full text-xs" aria-label={`${label} binding`}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value={NO_VARIABLE}>None</SelectItem>
          {variables.map((variable) => (
            <SelectItem key={variable.id} value={variable.id}>
              {variable.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}
