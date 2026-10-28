import { useState } from "react"
import { Label } from "@pelagik/ui/components/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@pelagik/ui/components/select"

const BUNDLED_FONTS = ["DM Sans Variable", "Inter Variable", "system-ui", "serif", "monospace"]
let systemFonts: string[] | undefined
let pendingFonts: Promise<string[]> | undefined

async function loadSystemFonts() {
  if (systemFonts) return systemFonts
  const localWindow = window as Window & { queryLocalFonts?: () => Promise<{ family: string }[]> }
  if (!localWindow.queryLocalFonts) throw new Error("System fonts aren't available in this browser.")
  if (!pendingFonts) {
    pendingFonts = localWindow.queryLocalFonts().then((fonts) => {
      systemFonts = [...new Set(fonts.map((font) => font.family).filter(Boolean))].sort((a, b) => a.localeCompare(b))
      return systemFonts
    }).finally(() => { pendingFonts = undefined })
  }
  return pendingFonts
}

export function FontFamilyField({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  const [fonts, setFonts] = useState(systemFonts ?? [])
  const [error, setError] = useState<string | null>(null)
  const families = [...new Set([...BUNDLED_FONTS, ...fonts, value])]

  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center gap-2">
        <Label className="w-12 shrink-0 text-xs text-muted-foreground">Family</Label>
        <Select value={value} onValueChange={onChange} onOpenChange={(open) => {
          if (!open) return
          void loadSystemFonts().then((available) => {
            setFonts(available)
            setError(null)
          }).catch((cause) => {
            setError(cause instanceof DOMException && cause.name === "NotAllowedError"
              ? "Allow font access to see your installed fonts."
              : cause instanceof Error ? cause.message : "Could not load system fonts.")
          })
        }}>
          <SelectTrigger size="sm" className="h-7 w-full min-w-0 text-xs" aria-label="Font family">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {families.map((family) => (
              <SelectItem key={family} value={family}>
                <span style={{ fontFamily: family }}>{family.replace(/ Variable$/, "")}</span>
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      {error && <p role="status" className="text-xs text-muted-foreground">{error}</p>}
    </div>
  )
}
