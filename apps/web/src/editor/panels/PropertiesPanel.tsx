import {
  AlignCenter,
  AlignCenterHorizontal,
  AlignCenterVertical,
  AlignEndHorizontal,
  AlignEndVertical,
  AlignLeft,
  AlignRight,
  AlignStartHorizontal,
  AlignStartVertical,
  type LucideIcon,
} from "lucide-react"
import { Button } from "@pelagik/ui/components/button"
import { Label } from "@pelagik/ui/components/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@pelagik/ui/components/select"
import { ToggleGroup, ToggleGroupItem } from "@pelagik/ui/components/toggle-group"
import { Tooltip, TooltipContent, TooltipTrigger } from "@pelagik/ui/components/tooltip"
import { DEFAULT_FLEX } from "@pelagik/design-core/flex"
import type {
  AlignMode,
  FlexCrossAlign,
  FlexDirection,
  FlexMainAlign,
  DesignVariable,
  SceneNode,
  TextAlign,
} from "@pelagik/design-core/types"
import { iconLibraryName, splitIconName } from "../icons/iconify"
import { alignSelection, bindSelection, updateNodesProps } from "../state/commands"
import { useEditor } from "../state/store"
import { FontFamilyField } from "./FontFamilyField"
import { shaderName } from "../shaders/catalog"
import { AddButton, ColorField, NumberField, RemoveButton, Section, VariableSelect } from "./fields"

const DEFAULT_STROKE = "#000000"
const FONT_WEIGHTS = [
  { value: 300, label: "Light" },
  { value: 400, label: "Regular" },
  { value: 500, label: "Medium" },
  { value: 600, label: "Semibold" },
  { value: 700, label: "Bold" },
]

const ALIGN_BUTTONS: { mode: AlignMode; label: string; icon: LucideIcon }[] = [
  { mode: "left", label: "Align left", icon: AlignStartVertical },
  { mode: "center", label: "Align horizontal centers", icon: AlignCenterVertical },
  { mode: "right", label: "Align right", icon: AlignEndVertical },
  { mode: "top", label: "Align top", icon: AlignStartHorizontal },
  { mode: "middle", label: "Align vertical centers", icon: AlignCenterHorizontal },
  { mode: "bottom", label: "Align bottom", icon: AlignEndHorizontal },
]

const MAIN_ALIGN_OPTIONS: { value: FlexMainAlign; label: string }[] = [
  { value: "start", label: "Start" },
  { value: "center", label: "Center" },
  { value: "end", label: "End" },
  { value: "space-between", label: "Space between" },
]

const CROSS_ALIGN_OPTIONS: { value: FlexCrossAlign; label: string }[] = [
  { value: "start", label: "Start" },
  { value: "center", label: "Center" },
  { value: "end", label: "End" },
]

export function PropertiesPanel() {
  const doc = useEditor((s) => s.doc)
  const selectedIds = useEditor((s) => s.selectedIds)
  const nodes = selectedIds.map((id) => doc.nodes[id]).filter((node): node is SceneNode => Boolean(node))

  // The editor only mounts this panel while something is selected. Null covers ids that were just deleted.
  if (nodes.length === 0) return null
  return <Inspector nodes={nodes} />
}

function variablesOfType(variables: Record<string, DesignVariable>, type: DesignVariable["type"]): DesignVariable[] {
  return Object.values(variables).filter((variable) => variable.type === type)
}

function Inspector({ nodes }: { nodes: SceneNode[] }) {
  const variables = useEditor((s) => s.doc.variables)
  const ids = nodes.map((node) => node.id)
  const primary = nodes[0]
  const single = nodes.length === 1 ? primary : null
  // A parent with flex places its children, so their position fields are read-only.
  const inFlex = useEditor((s) => (single?.parentId ? s.doc.nodes[single.parentId]?.flex != null : false))
  const hasFill = nodes.some((node) => node.type !== "group")
  const hasRadius = nodes.some((node) => node.type === "rectangle" || node.type === "frame")
  const hasText = nodes.some((node) => node.type === "text")
  // Icons draw in their fill color only. A stroke would be dropped by the design spec, so the control is hidden.
  const hasStroke = nodes.every((node) => node.type !== "icon")
  const canRemoveFill = primary.type !== "icon"
  const canHaveShader = nodes.every((node) => ["frame", "rectangle", "ellipse"].includes(node.type))
  const setShaderPickerOpen = useEditor((s) => s.setShaderPickerOpen)
  const colors = variablesOfType(variables, "color")

  const patch = (values: Partial<SceneNode>, field: string) => updateNodesProps(ids, values, `${field}:${ids.join(",")}`)

  return (
    <div className="flex flex-col gap-4 p-3">
      <div className="flex items-center justify-between gap-1">
        {ALIGN_BUTTONS.map(({ mode, label, icon: Icon }) => (
          <Tooltip key={mode}>
            <TooltipTrigger asChild>
              <Button variant="ghost" size="icon-sm" aria-label={label} onClick={() => alignSelection(mode)}>
                <Icon />
              </Button>
            </TooltipTrigger>
            <TooltipContent>{label}</TooltipContent>
          </Tooltip>
        ))}
      </div>

      <Section title={single ? "Layout" : `${nodes.length} layers`}>
        {single && (
          <div className="grid grid-cols-2 gap-x-3 gap-y-2">
            <NumberField labelWidth="w-3" label="X" value={single.x} disabled={inFlex} onCommit={(v) => patch({ x: v }, "x")} />
            <NumberField labelWidth="w-3" label="Y" value={single.y} disabled={inFlex} onCommit={(v) => patch({ y: v }, "y")} />
            <NumberField labelWidth="w-3" label="W" value={single.width} min={1} onCommit={(v) => patch({ width: v }, "w")} />
            <NumberField labelWidth="w-3" label="H" value={single.height} min={1} disabled={single.type === "text"} onCommit={(v) => patch({ height: v }, "h")} />
            <NumberField labelWidth="w-3" label="R" value={single.rotation} onCommit={(v) => patch({ rotation: v }, "rotation")} />
          </div>
        )}
      </Section>

      {single?.type === "frame" && <FlexSection node={single} patch={patch} />}

      <Section title="Appearance">
        <div className="flex flex-col gap-2">
          <div className="grid grid-cols-2 gap-x-3 gap-y-2">
            <NumberField
              label="Opacity"
              suffix="%"
              value={Math.round(primary.opacity * 100)}
              min={0}
              max={100}
              onCommit={(v) => patch({ opacity: v / 100 }, "opacity")}
            />
            {hasRadius && (
              <NumberField label="Radius" value={primary.radius} min={0} onCommit={(v) => patch({ radius: v }, "radius")} />
            )}
          </div>
        </div>
      </Section>

      {single?.type === "icon" && single.icon && (
        <Section title="Icon">
          <p className="text-xs text-muted-foreground">
            {iconLibraryName(splitIconName(single.icon.name).prefix)} · {splitIconName(single.icon.name).icon}
          </p>
        </Section>
      )}

      {hasFill && (
        <Section
          title="Fill"
          action={
            primary.fill === null ? (
              <AddButton label="Add fill" onClick={() => patch({ fill: "#d9d9d9" }, "fill-add")} />
            ) : canRemoveFill ? (
              <RemoveButton label="Remove fill" onClick={() => patch({ fill: null }, "fill-remove")} />
            ) : null
          }
        >
          {primary.fill !== null && (
            <div className="flex flex-col gap-2">
              <ColorField
                value={primary.fill}
                onChange={(v, key) => patch({ fill: v }, key)}
                field="fill"
                trailingAction={
                  <VariableSelect
                    variables={colors}
                    value={primary.bindings.fill}
                    onChange={(id) => bindSelection("fill", id)}
                    label="Fill variable"
                    compact
                  />
                }
              />
            </div>
          )}
        </Section>
      )}

      {canHaveShader && (
        <Section
          title="Shader"
          action={(
            <Button variant="outline" size="xs" onClick={() => setShaderPickerOpen(true)}>
              Browse
            </Button>
          )}
        >
          {single?.shader ? (
            <div className="flex items-center justify-between rounded-md border bg-muted/30 px-2 py-1">
              <span className="truncate text-xs text-muted-foreground">{shaderName(single.shader)}</span>
              <RemoveButton label="Remove shader" onClick={() => patch({ shader: null }, "shader-remove")} />
            </div>
          ) : (
            <p className="text-xs text-muted-foreground">Add a visual shader to this layer.</p>
          )}
        </Section>
      )}

      {hasStroke && (
        <Section
          title="Stroke"
          action={
            primary.stroke === null ? (
              <AddButton label="Add stroke" onClick={() => patch({ stroke: DEFAULT_STROKE, strokeWidth: 1 }, "stroke-add")} />
            ) : (
              <RemoveButton label="Remove stroke" onClick={() => patch({ stroke: null }, "stroke-remove")} />
            )
          }
        >
          {primary.stroke !== null && (
            <div className="flex flex-col gap-2">
              <ColorField
                value={primary.stroke}
                onChange={(v, key) => patch({ stroke: v }, key)}
                field="stroke"
                trailingAction={
                  <VariableSelect
                    variables={colors}
                    value={primary.bindings.stroke}
                    onChange={(id) => bindSelection("stroke", id)}
                    label="Stroke variable"
                    compact
                  />
                }
              />
              <NumberField label="Weight" value={primary.strokeWidth} min={0} onCommit={(v) => patch({ strokeWidth: v }, "strokeWidth")} />
            </div>
          )}
        </Section>
      )}

      {hasText && single?.type === "text" && (
        <Section title="Text">
          <div className="flex flex-col gap-2">
            <FontFamilyField value={single.fontFamily} onChange={(value) => patch({ fontFamily: value }, "fontFamily")} />
            <NumberField label="Size" value={single.fontSize} min={1} onCommit={(v) => patch({ fontSize: v }, "fontSize")} />
            <div className="flex items-center gap-2">
              <Label className="w-12 shrink-0 text-xs text-muted-foreground">Weight</Label>
              <Select value={String(single.fontWeight)} onValueChange={(v) => patch({ fontWeight: Number(v) }, "fontWeight")}>
                <SelectTrigger size="sm" className="h-7 w-full text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {FONT_WEIGHTS.map((weight) => (
                    <SelectItem key={weight.value} value={String(weight.value)}>
                      {weight.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <Label className="w-12 shrink-0 text-xs text-muted-foreground">Align</Label>
              <ToggleGroup
                type="single"
                variant="outline"
                size="sm"
                value={single.textAlign}
                onValueChange={(v) => {
                  if (v) patch({ textAlign: v as TextAlign }, "textAlign")
                }}
              >
                <ToggleGroupItem value="left" aria-label="Align text left">
                  <AlignLeft />
                </ToggleGroupItem>
                <ToggleGroupItem value="center" aria-label="Align text center">
                  <AlignCenter />
                </ToggleGroupItem>
                <ToggleGroupItem value="right" aria-label="Align text right">
                  <AlignRight />
                </ToggleGroupItem>
              </ToggleGroup>
            </div>
          </div>
        </Section>
      )}
    </div>
  )
}

function FlexSection({ node, patch }: { node: SceneNode; patch: (values: Partial<SceneNode>, field: string) => void }) {
  const layout = node.flex
  return (
    <Section
      title="Flex"
      action={
        layout === null ? (
          <AddButton label="Add flex" onClick={() => patch({ flex: DEFAULT_FLEX }, "flex-add")} />
        ) : (
          <RemoveButton label="Remove flex" onClick={() => patch({ flex: null }, "flex-remove")} />
        )
      }
    >
      {layout && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <Label className="w-16 shrink-0 text-xs font-normal text-muted-foreground">Direction</Label>
            <ToggleGroup
              type="single"
              variant="outline"
              size="sm"
              value={layout.direction}
              onValueChange={(v) => {
                if (v) patch({ flex: { ...layout, direction: v as FlexDirection } }, "flex-direction")
              }}
            >
              <ToggleGroupItem value="horizontal">Row</ToggleGroupItem>
              <ToggleGroupItem value="vertical">Column</ToggleGroupItem>
            </ToggleGroup>
          </div>
          <NumberField
            labelWidth="w-16"
            label="Gap"
            value={layout.gap}
            min={0}
            onCommit={(v) => patch({ flex: { ...layout, gap: v } }, "flex-gap")}
          />
          <NumberField
            labelWidth="w-16"
            label="Padding"
            value={layout.padding}
            min={0}
            onCommit={(v) => patch({ flex: { ...layout, padding: v } }, "flex-padding")}
          />
          <OptionSelect
            label="Justify"
            value={layout.mainAlign}
            options={MAIN_ALIGN_OPTIONS}
            onChange={(mainAlign) => patch({ flex: { ...layout, mainAlign } }, "flex-justify")}
          />
          <OptionSelect
            label="Align"
            value={layout.crossAlign}
            options={CROSS_ALIGN_OPTIONS}
            onChange={(crossAlign) => patch({ flex: { ...layout, crossAlign } }, "flex-align")}
          />
        </div>
      )}
    </Section>
  )
}

function OptionSelect<T extends string>({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: T
  options: { value: T; label: string }[]
  onChange: (value: T) => void
}) {
  return (
    <div className="flex items-center gap-2">
      <Label className="w-16 shrink-0 text-xs font-normal text-muted-foreground">{label}</Label>
      <Select value={value} onValueChange={(next) => onChange(next as T)}>
        <SelectTrigger size="sm" className="h-7 w-full text-xs">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}
