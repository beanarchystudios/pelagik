import { defineCatalog, defineSchema } from "@json-render/core"
import { z } from "zod"
import { color, iconGlyph, patch } from "./properties"

const { text: _text, fontFamily: _family, fontSize: _size, fontWeight: _weight, textAlign: _align, flex: _flex, ...shape } = patch.shape
const { fill: _fill, stroke: _stroke, strokeWidth: _strokeWidth, radius: _radius, shader: _shader, ...geometry } = shape
const { shader: _textShader, ...textShape } = shape
const lock = { locked: z.boolean().optional() }
export const componentProps = {
  frame: z.object({ ...shape, ...lock, flex: patch.shape.flex }).strict(),
  group: z.object({ ...geometry, ...lock }).strict(),
  rectangle: z.object({ ...shape, ...lock }).strict(),
  ellipse: z.object({ ...shape, ...lock }).strict(),
  text: z.object({ ...textShape, ...lock, text: patch.shape.text, fontFamily: patch.shape.fontFamily, fontSize: patch.shape.fontSize, fontWeight: patch.shape.fontWeight, textAlign: patch.shape.textAlign }).strict(),
  icon: z.object({ ...geometry, ...lock, fill: color, icon: iconGlyph }).strict(),
}

const schema = defineSchema(s => ({
  spec: s.object({
    rootIds: s.array(s.string()),
    nodes: s.record(s.object({
      type: s.ref("catalog.components"), props: s.propsOf("catalog.components"),
      childIds: s.array(s.string()), bindings: { ...s.record(s.string()), ...s.optional() },
    })),
    variables: { ...s.record(s.object({ name: s.string(), value: s.string() })), ...s.optional() },
  }),
  catalog: s.object({ components: s.map({ props: s.zod(), description: s.string() }) }),
}), {
  promptTemplate: ({ catalog, formatZodType }) => {
    const components = (catalog as { components: Record<string, { props: z.ZodType; description: string }> }).components
    return [
      "Generate a complete Pelagik json-render design spec as JSON. Use rootIds and a flat nodes map; each node has type, props, and childIds.",
    "Optional variables is a map of {name,value} solid color tokens. Node bindings maps fill/stroke to variable keys. Shape layers may use a built-in shader preset. All references must exist, each node has one parent, and cycles/orphans are forbidden.",
      "Use parent-local CSS pixels and clockwise degrees. A frame clips children. Its flex layout derives child positions. Child order is back-to-front. Groups fit their children.",
      "No JavaScript, HTML, actions, external assets, state expressions, repeats, or streamed partial specs. All literal props must satisfy the catalog. Pelagik supplies the renderer and editing behavior.",
      ...Object.entries(components).map(([name, c]) => `${name}: ${c.description}\nProps: ${formatZodType(c.props)}`),
      "Submit complete specs with the insert_spec operation inside apply_edits, using an expected revision and unique request ID. Read json-render specs using get_document with format=json-render.",
    ].join("\n\n")
  },
})
export const designCatalog = defineCatalog(schema, {
  components: {
    frame: { props: componentProps.frame, description: "A clipping container, optionally using horizontal or vertical flex layout and a shader effect." },
    group: { props: componentProps.group, description: "A group whose bounds fit its children. It has no fill or stroke." },
    rectangle: { props: componentProps.rectangle, description: "A rectangle, optionally with rounded corners and a shader effect." },
    ellipse: { props: componentProps.ellipse, description: "An ellipse or circle, optionally with a shader effect." },
    text: { props: componentProps.text, description: "Editable text. Browser font measurement determines its height." },
    icon: { props: componentProps.icon, description: "A vector icon from an icon library. Its fill sets the icon color. Icons cannot have children or strokes." },
  },
})

const key = z.string().min(1).max(128).refine(s => !["__proto__", "constructor", "prototype"].includes(s), "Reserved key")
const children = z.array(key).max(10000).default([])
const bindings = z.object({ fill: key.optional(), stroke: key.optional() }).strict().optional()
// json-render's custom propsOf schema is generic when multiple components exist.
// Validate each type against its own catalog props as a separate domain boundary.
export const designSpecSchema = z.object({
  rootIds: z.array(key).max(10000),
  nodes: z.record(key, z.discriminatedUnion("type", [
    z.object({ type: z.literal("frame"), props: componentProps.frame, childIds: children, bindings }).strict(),
    z.object({ type: z.literal("group"), props: componentProps.group, childIds: children, bindings }).strict(),
    z.object({ type: z.literal("rectangle"), props: componentProps.rectangle, childIds: children, bindings }).strict(),
    z.object({ type: z.literal("ellipse"), props: componentProps.ellipse, childIds: children, bindings }).strict(),
    z.object({ type: z.literal("text"), props: componentProps.text, childIds: children, bindings }).strict(),
    z.object({ type: z.literal("icon"), props: componentProps.icon, childIds: children, bindings }).strict(),
  ])).refine(nodes => Object.keys(nodes).length <= 10000, "Designs are limited to 10000 nodes"),
  variables: z.record(key, z.object({ name: z.string().trim().min(1).max(200), value: color }).strict()).refine(vars => Object.keys(vars).length <= 1000).optional(),
}).strict()
export type DesignSpec = z.output<typeof designSpecSchema>
export function parseDesignSpec(input: unknown): DesignSpec {
  const checked = designCatalog.validate(input)
  if (!checked.success) throw checked.error
  // Parse the original to reject unknown fields rather than silently stripping them.
  return designSpecSchema.parse(input)
}
export function getDesignCatalog() {
  return {
    format: "pelagik/json-render", library: "@json-render/core", version: "0.21.3",
    components: designCatalog.componentNames,
    prompt: designCatalog.prompt(), jsonSchema: z.toJSONSchema(designSpecSchema),
    catalogSchema: designCatalog.jsonSchema(),
  }
}
