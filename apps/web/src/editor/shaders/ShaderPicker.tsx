import { useMemo, useRef, useState } from "react"
import { Search } from "lucide-react"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@pelagik/ui/components/dialog"
import type { ShaderId } from "@pelagik/design-core/types"
import { updateNodesProps } from "../state/commands"
import { useEditor } from "../state/store"
import { PEN_SHADER_FAMILIES, SHADERS, type PenShaderFamily, type ShaderPreset } from "./catalog"
import { ShaderPreview } from "./ShaderPreview"

const CAN_USE_SHADER = new Set(["frame", "rectangle", "ellipse"])
const BASIC_CATEGORIES = ["Image filters", "Effects"] as const

export function ShaderPicker() {
  const open = useEditor((state) => state.shaderPickerOpen)
  const setOpen = useEditor((state) => state.setShaderPickerOpen)
  const selectedIds = useEditor((state) => state.selectedIds)
  const doc = useEditor((state) => state.doc)
  const [search, setSearch] = useState("")
  const [expandedFamily, setExpandedFamily] = useState<string | null>(null)
  const searchInputRef = useRef<HTMLInputElement>(null)
  const nodes = selectedIds.map((id) => doc.nodes[id]).filter(Boolean)
  const canApply = nodes.length > 0 && nodes.every((node) => CAN_USE_SHADER.has(node.type))
  const currentShader = nodes.length > 0 && nodes.every((node) => node.shader === nodes[0].shader) ? nodes[0].shader : null
  const query = search.trim().toLocaleLowerCase()

  const basicShaders = useMemo(() => SHADERS.filter((shader) => {
    if (shader.category === "Pen shaders") return false
    return !query || `${shader.name} ${shader.description}`.toLocaleLowerCase().includes(query)
  }), [query])

  const penFamilies = useMemo(() => PEN_SHADER_FAMILIES.flatMap((family) => {
    const familyMatches = `${family.name} ${family.caption} ${family.credit}`.toLocaleLowerCase().includes(query)
    const matchingExamples = family.examples.filter((example) => {
      if (!query || familyMatches) return true
      return `${example.name} ${example.variantLabel} ${example.credit}`.toLocaleLowerCase().includes(query)
    })
    return matchingExamples.length > 0 ? [{ family, familyMatches, matchingExamples }] : []
  }), [query])

  const apply = (shader: ShaderId) => {
    if (!canApply || nodes.every((node) => node.shader === shader)) return
    updateNodesProps(nodes.map((node) => node.id), { shader }, `shader:${nodes.map((node) => node.id).join(",")}`)
    setOpen(false)
  }

  const applyBasic = (shader: ShaderPreset) => apply(shader.id)
  const onOpenChange = (nextOpen: boolean) => {
    setOpen(nextOpen)
    if (!nextOpen) {
      searchInputRef.current?.blur()
      setSearch("")
      setExpandedFamily(null)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="gap-0 overflow-hidden p-0 sm:max-w-5xl">
        <DialogHeader className="border-b px-5 py-4 pr-12">
          <DialogTitle>Shaders</DialogTitle>
          <DialogDescription>
            {canApply
              ? `Choose a shader for ${nodes.length === 1 ? "the selected layer" : `${nodes.length} selected layers`}.`
              : "Select a frame, rectangle, or ellipse to apply a shader."}
          </DialogDescription>
        </DialogHeader>
        <div className="border-b px-5 py-3">
          <label className="relative block">
            <span className="sr-only">Search shaders</span>
            <Search aria-hidden="true" className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
            <input
              ref={searchInputRef}
              type="search"
              aria-label="Search shaders"
              placeholder="Search shaders and variants"
              value={search}
              onChange={(event) => setSearch(event.currentTarget.value)}
              className="h-9 w-full rounded-md border border-input bg-background pr-3 pl-9 text-sm outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
            />
          </label>
        </div>
        <div className="max-h-[min(72vh,660px)] overflow-y-auto px-5 py-4">
          {BASIC_CATEGORIES.map((category) => {
            const shaders = basicShaders.filter((shader) => shader.category === category)
            if (!shaders.length) return null
            return (
              <section key={category} aria-label={category} className="pb-5">
                <h3 className="mb-3 text-xs font-medium text-muted-foreground">{category}</h3>
                <div className="grid grid-cols-2 gap-x-3 gap-y-4 sm:grid-cols-3 lg:grid-cols-4">
                  {shaders.map((shader) => (
                    <ShaderCard
                      key={shader.id}
                      shader={shader}
                      selected={currentShader === shader.id}
                      disabled={!canApply}
                      onApply={() => applyBasic(shader)}
                    />
                  ))}
                </div>
              </section>
            )
          })}

          {penFamilies.length > 0 && (
            <section aria-label="Pen shaders" className="border-t pt-4">
              <div className="mb-3 flex items-baseline justify-between gap-3">
                <h3 className="text-xs font-medium text-muted-foreground">Pen shader library</h3>
                <span className="text-xs text-muted-foreground">{PEN_SHADER_FAMILIES.length} families · {PEN_SHADER_FAMILIES.reduce((sum, family) => sum + family.examples.length, 0)} variants</span>
              </div>
              {penFamilies.map(({ family, familyMatches, matchingExamples }) => (
                <PenFamilyCard
                  key={family.id}
                  family={family}
                  examples={matchingExamples}
                  showAllVariants={familyMatches || !query}
                  expanded={expandedFamily === family.id || Boolean(query && !familyMatches)}
                  selectedId={currentShader}
                  disabled={!canApply}
                  onApply={apply}
                  onToggle={() => setExpandedFamily((current) => current === family.id ? null : family.id)}
                />
              ))}
            </section>
          )}

          {!basicShaders.length && !penFamilies.length && (
            <p className="py-10 text-center text-sm text-muted-foreground">No shaders match “{search}”.</p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}

function ShaderCard({
  shader,
  selected,
  disabled,
  onApply,
}: {
  shader: ShaderPreset
  selected: boolean
  disabled: boolean
  onApply: () => void
}) {
  return (
    <button
      type="button"
      aria-label={`Apply ${shader.name} shader`}
      aria-pressed={selected}
      title={shader.description}
      disabled={disabled}
      onClick={onApply}
      className="group min-w-0 rounded-md text-left outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-45"
    >
      <span className={`relative block aspect-[5/3] overflow-hidden rounded border bg-muted transition-[border-color,box-shadow] group-hover:border-foreground/50 group-focus-visible:border-ring ${selected ? "border-selection ring-2 ring-selection/60" : "border-border"}`}>
        <ShaderPreview shader={shader.id} color={shader.previewColor} width={240} height={144} className="size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]" />
        <span aria-hidden="true" className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/15 to-transparent opacity-0 transition-opacity group-hover:opacity-100" />
      </span>
      <span className="mt-1.5 block truncate text-xs text-foreground">{shader.name}</span>
    </button>
  )
}

function PenFamilyCard({
  family,
  examples,
  showAllVariants,
  expanded,
  selectedId,
  disabled,
  onApply,
  onToggle,
}: {
  family: PenShaderFamily
  examples: ShaderPreset[]
  showAllVariants: boolean
  expanded: boolean
  selectedId: ShaderId | null
  disabled: boolean
  onApply: (id: ShaderId) => void
  onToggle: () => void
}) {
  const defaultExample = family.defaultExample
  const variants = showAllVariants ? examples : examples.filter((example) => example.id === defaultExample.id)
  return (
    <div className="mb-4 rounded-lg border border-border/70 bg-card/30 p-3" data-shader-family={family.id}>
      <div className="flex items-start gap-3">
        <button
          type="button"
          aria-label={`Apply ${family.name} shader`}
          aria-pressed={selectedId === defaultExample.id}
          title={[family.caption, family.credit].filter(Boolean).join(" · ")}
          disabled={disabled}
          onClick={() => onApply(defaultExample.id)}
          className="group min-w-0 flex-1 rounded-md text-left outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-45"
        >
          <span className="flex items-center gap-3">
            <span className={`relative block aspect-[5/3] w-40 shrink-0 overflow-hidden rounded border bg-muted sm:w-48 ${selectedId === defaultExample.id ? "border-selection ring-2 ring-selection/60" : "border-border"}`}>
              <ShaderPreview shader={defaultExample.id} color={defaultExample.previewColor} width={240} height={144} className="size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]" />
            </span>
            <span className="min-w-0 self-center">
              <span className="block truncate text-sm font-medium text-foreground">{family.name}</span>
              <span className="mt-1 block truncate text-xs text-muted-foreground">{family.type} · {defaultExample.variantLabel}</span>
              <span className="mt-1 hidden truncate text-xs text-muted-foreground sm:block">{family.caption}</span>
              {family.credit && <span className="mt-1 hidden truncate text-[11px] text-muted-foreground/80 md:block">{family.credit}</span>}
            </span>
          </span>
        </button>
        <button
          type="button"
          aria-label={`${expanded ? "Hide" : "Show"} ${family.name} variants`}
          aria-expanded={expanded}
          onClick={onToggle}
          className="mt-1 shrink-0 rounded border border-border px-2 py-1 text-xs text-muted-foreground outline-none hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring"
        >
          {family.examples.length} variants
        </button>
      </div>
      {expanded && (
        <div className="mt-3 grid grid-cols-2 gap-x-3 gap-y-4 border-t border-border/70 pt-3 sm:grid-cols-3 lg:grid-cols-5">
          {variants.map((example) => (
            <button
              key={example.id}
              type="button"
              data-shader-variant={example.id}
              aria-label={`Apply ${family.name} · ${example.variantLabel} shader`}
              aria-pressed={selectedId === example.id}
              title={example.name}
              disabled={disabled}
              onClick={() => onApply(example.id)}
              className="group min-w-0 rounded-md text-left outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-45"
            >
              <span className={`relative block aspect-[5/3] overflow-hidden rounded border bg-muted transition-[border-color,box-shadow] group-hover:border-foreground/50 ${selectedId === example.id ? "border-selection ring-2 ring-selection/60" : "border-border"}`}>
                <ShaderPreview shader={example.id} color={example.previewColor} width={240} height={144} className="size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]" />
              </span>
              <span className="mt-1.5 block truncate text-xs text-foreground">{example.variantLabel}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
