# Editable designs with json-render

Pelagik uses `@json-render/core@0.21.3` to define a component catalog, generate an
agent prompt, and validate design specifications. The catalog supports frames,
groups, rectangles, ellipses, text, icons, and embedded raster images. Every design is stored as a json-render spec. Manual creation, property edits,
drag previews, agent edits, and undo/redo all use the same catalog validation.

Images carry PNG, JPEG, GIF, or WebP data URLs in their `image` property.

Icons carry their artwork in the spec as flat SVG shapes (`elements` with a `tag` and
allowlisted `attrs`), not as markup. Their `fill` is the icon color, and they cannot have
children or strokes. Agents add icons with `insert_spec`; `create` does not accept icons.
Artwork that needs SVG features outside the allowlist, such as `<use>`, masks, gradients,
or scripts, fails validation.
Undo history and local saves contain specs. The canvas geometry model is a derived
projection used for hit testing, layout operations, and rendering, not a second
saved design format.

This is a custom json-render schema for a design editor. It uses `rootIds`, a
flat `nodes` map, and optional color variables. It does not use the built-in React
`root/elements` schema. Pelagik supplies the custom renderer by compiling specs to
its document model and rendering them through the existing canvas components.
There is no second DOM preview with different layout behavior.

Frame, rectangle, and ellipse props may include one built-in shader preset using
the `shader` property. Shader source is bundled with the renderer; design specs
only select from catalogued presets. The gallery includes image filters and
effects, all 75 Pen shader families with five variants each, and Liquid Glass
styles suited to iOS screens. Shader previews and GLSL sources are local, so the
gallery and packaged desktop renderer work offline. Family credits and original
source notices are preserved with the shader catalog.

## In the editor

Click **Design JSON** to view the selected layers as a spec. With no selection,
the dialog exports the document. Paste or edit a spec and click **Insert as
layers** to add independent editable layers in one undo step. Existing layers
remain in place. Invalid specs report an error without changing the canvas.

Use **Read current design** after another agent or a human changes the document.
The dialog rejects insertion against a changed snapshot so it cannot silently act
on stale context. **Select JSON** selects the text for your normal copy shortcut.

Imports remap node and variable IDs. Reimporting the same spec creates a new copy.
This dialog is an insertion workflow; it does not replace the entire document.
Older saved documents load through the legacy reader and are written as json-render on the next save. Node IDs, geometry, variables, and bindings survive migration.

## With MCP

1. Read `pelagik://catalog`. It includes the component vocabulary, the catalog's
   generated prompt, the json-render schema, and the stricter domain JSON Schema.
2. Read the target session and revision with `get_document`.
3. Generate a complete spec and send it using `insert_spec` inside `apply_edits`.
4. Inspect or refine the created layers, and call `render` for a PNG.
5. Read a design back with `get_document`, which returns json-render by default.
   Use `format: "summary"` only for a paginated hierarchy inspection.

The existing eight tools remain available. json-render adds a declarative input
format to `apply_edits`; it does not bypass revision checks, locks, validation,
request replay handling, or single-step undo. Fine-grained changes still use
explicit update, reparent, variable, and other operations.

Example `insert_spec` operation:

```json
{
  "op": "insert_spec",
  "ref": "card",
  "parentId": null,
  "spec": {
    "rootIds": ["card"],
    "variables": { "accent": { "name": "Accent", "value": "#0088cc" } },
    "nodes": {
      "card": {
        "type": "frame",
        "props": {
          "name": "Welcome card", "width": 320, "height": 240,
          "flex": { "direction": "vertical", "gap": 16, "padding": 24,
            "mainAlign": "start", "crossAlign": "start" }
        },
        "childIds": ["heading", "button"]
      },
      "heading": {
        "type": "text",
        "props": { "text": "Hello Pelagik", "width": 272, "fontSize": 24 },
        "childIds": []
      },
      "button": {
        "type": "rectangle",
        "props": { "width": 160, "height": 44, "radius": 8 },
        "bindings": { "fill": "accent" },
        "childIds": []
      }
    }
  }
}
```

Send this operation with `sessionId`, `expectedRevision`, and a unique `requestId`
in the surrounding `apply_edits` arguments. A spec operation may define `ref` only
when it has one root, so later operations can refer to `$card`. Results include
`imports`, with root IDs plus the input-to-document node and variable ID mappings.

The spec's keys are temporary identifiers when importing. Exported specs use the
current document IDs as keys. Variables referenced by exported subtrees are
included; whole-document exports include unbound variables too.

Geometry is in parent-local CSS pixels, normalized to whole pixels; rotation is
clockwise in degrees. Imported roots use the coordinate space of `parentId`.
Reparent operations separately preserve page-space placement. Child order is
back-to-front, frames clip children, and groups fit their children. Text height is
measured in the browser, so request a settled read after insertion.

## Validation and limits

The json-render catalog validates the custom schema and component vocabulary.
Pelagik then validates each component against its exact props schema and enforces
hierarchy, limits, color bindings, and document invariants. This extra validation
is necessary because json-render's custom `propsOf` builder emits generic props
when more than one component is available.

Specs must be complete trees with no cycles, missing children, duplicate parents,
or orphaned nodes. Only frames and groups contain children. Groups cannot have
shape styles or color bindings. Unsupported properties, executable code, event
actions, HTML, state expressions, repeated elements, and incomplete streams are
rejected. The design format contains literal values and explicit color-variable
bindings, not json-render runtime state bindings.

A design contains at most 10000 nodes and 1000 variables, with hierarchy depth at most
64. Each spec insertion is limited to 1000 nodes. The editor's text input and broker
request bodies are limited to 1 MiB. Large exports should target smaller subtrees.
`get_document` in json-render mode returns a complete spec instead of a paginated
hierarchy; use its `subtreeId` option for a smaller design.

No model provider, API key, or server-side generation service is required. Your
MCP agent generates the spec using the published catalog. There is no separate
agent-generated panel system in this implementation.

## Code and checks

- `packages/design-spec/src/catalog.ts` defines the custom schema, catalog,
  generated prompt, and stricter spec validation.
- `packages/design-spec/src/document.ts` compiles specs and exports documents.
- `packages/agent-api/src/edits.ts` applies spec insertion atomically.
- `apps/web/src/editor/agent/DesignJsonDialog.tsx` provides the editor workflow.

```sh
bun run --cwd packages/design-spec test
bun run test:mcp:e2e
```

The Electron end-to-end test reads the actual MCP catalog resource, imports a spec,
reads it back, inserts a copy through Design JSON, verifies undo and rejection of
a cyclic spec, and checks rendered pixels for flex, nesting, rotated frame
clipping, ellipses, opacity, and fractional image scale.

See [research and primary sources](json-render-research.md) for the API review and
[MCP setup](mcp.md) for pairing and client configuration.
