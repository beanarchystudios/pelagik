# json-render integration research

Checked 2026-10-27 against official docs, npm metadata, published declarations, and official source. Firecrawl was attempted: `firecrawl --status` reported zero credits and `firecrawl scrape https://json-render.dev/docs/catalog` failed with “Insufficient credits”. Used direct official HTTP sources instead. Some official Markdown pages omit imports and JSX lines, so examples below follow the published declarations and source rather than copying those incomplete snippets.

## Implementation decision

The user chose editable canvas designs and the MCP design format. The implemented
integration uses the custom-schema option below: a json-render catalog validates
complete design specs, then Pelagik compiles them into its existing editable model.
The existing canvas renderer remains authoritative. See [usage and design](json-render.md).
The separate-panel recommendation below records the initial research option; it
was not the selected product direction.

## Initial recommendation

Use json-render for a separate agent-generated proposal or assistant panel. Keep Pelagik's `Document`, canvas renderer, transaction service, and persistence authoritative. A useful first integration is a constrained proposal card with a summary and an “Apply” action that submits an existing atomic edit batch. json-render adds a UI vocabulary and rendering; it does not replace the editing protocol or supply design-editor behavior. [1][2][3]

For actual design generation, the existing MCP workflow already fits: inspect document, submit atomic operations, render PNG, refine. If a declarative design catalog later proves useful, compile it to those same operations. Do not replace `SceneNodeView` with json-render's React renderer or embed arbitrary generated DOM as editable canvas nodes.

## Current packages and APIs

| Package | npm `latest` | Relevant API and requirements |
| --- | --- | --- |
| `@json-render/core` | `0.21.3`, published Oct 24 | `defineSchema`, `defineCatalog`, `catalog.prompt()`, `catalog.jsonSchema()`, `catalog.validate()`, `catalog.zodSchema()`; peer Zod `^4.0.0`, dependency `^4.3.6` |
| `@json-render/react` | `0.21.3`, published Oct 24 | `defineRegistry`, `Renderer`, `JSONUIProvider`, state/action hooks, optional streaming hooks; exact core dependency `0.21.3`, React peer `^19.2.3` |

These are the current non-prerelease `latest` versions, still pre-1.0. Pin both to `0.21.3` for evaluation and use Zod 4. Pelagik's React `^19.3.1` satisfies the published React peer range. No Next.js or AI SDK package is required for rendering in Vite. The built-in React schema is a **separate import**, `@json-render/react/schema`. No prebuilt component package is needed for a custom registry. [4][5][6]

## Concrete React catalog and renderer

Illustrative integration sketch, not app code. `applyValidatedProposal` is an application-owned bridge to Pelagik's existing transaction service. A proposal ID resolves to a trusted staged batch and its original revision; the generated UI does not choose arbitrary executable code.

```tsx
import { z } from "zod";
import { defineCatalog, type Spec } from "@json-render/core";
import { schema } from "@json-render/react/schema";
import { defineRegistry, JSONUIProvider, Renderer } from "@json-render/react";

const applyParams = z.object({ proposalId: z.string() });
const catalog = defineCatalog(schema, {
  components: {
    Proposal: {
      props: z.object({ summary: z.string() }),
      slots: ["default"],
      description: "Summarize a proposed canvas edit",
    },
    ApplyButton: {
      props: z.object({ label: z.string() }),
      events: ["press"],
    },
  },
  actions: {
    apply_proposal: { params: applyParams, description: "Apply a staged edit batch" },
  },
});

const { registry } = defineRegistry(catalog, {
  components: {
    Proposal: ({ props, children }) => <section><p>{props.summary}</p>{children}</section>,
    ApplyButton: ({ props, emit }) =>
      <button onClick={() => emit("press")}>{props.label}</button>,
  },
});

const spec: Spec = {
  root: "proposal",
  elements: {
    proposal: {
      type: "Proposal", props: { summary: "Add a nested frame and heading" },
      children: ["apply"],
    },
    apply: {
      type: "ApplyButton", props: { label: "Apply" }, children: [],
      on: { press: { action: "apply_proposal", params: { proposalId: "p1" } } },
    },
  },
};

// Validate untrusted incoming specs before passing them to the renderer.
const checked = catalog.validate(spec);
if (!checked.success) throw checked.error;

function ProposalUI() {
  return (
    <JSONUIProvider registry={registry} initialState={{}} handlers={{
      apply_proposal: async (raw) => {
        const { proposalId } = applyParams.parse(raw);
        await applyValidatedProposal(proposalId);
      },
    }}>
      <Renderer spec={spec} registry={registry} />
    </JSONUIProvider>
  );
}
```

The imports, event binding, registry component context, and combined provider match the current APIs. `emit("press")` triggers `element.on.press`; an `action` string prop alone does not wire a click. Catalog declarations do not implement actions. [2][3][5][7]

There are two handler forms. Direct `JSONUIProvider.handlers` receive params. `defineRegistry` can also accept typed `actions`, whose handlers receive `(params, setState, state)` and return `Promise<void>`. Its returned `handlers` is a **factory**, `handlers(getSetState, getState)`, not a handler map to pass unchanged. For a stateless bridge, direct provider handlers are simpler. Validate action params again at the boundary; the published registry wrapper calls the action function directly without parsing its params. [3][5][7]

`JSONUIProvider` combines state, visibility, actions, and validation contexts. Alternatively compose their individual providers. `StateProvider` and `JSONUIProvider` support an external `StateStore`; supplying `store` ignores `initialState` and `onStateChange`. Keep this state local to assistant forms. Built-in `setState`, `pushState`, and `removeState` mutate UI state and should not gain a path into Pelagik's document or bypass history. [5][7][8]

## Custom schema option

`defineSchema` describes the output format and the catalog contract; `defineCatalog` supplies concrete Zod props. This reduced example uses the current builder API and shows how to preserve multiple roots. It is not a complete Pelagik schema. [8][9]

```ts
import { defineSchema, defineCatalog } from "@json-render/core";
import { z } from "zod";

const designSchema = defineSchema((s) => ({
  spec: s.object({
    rootIds: s.array(s.string()),
    nodes: s.record(s.object({
      type: s.ref("catalog.components"),
      props: s.propsOf("catalog.components"),
      childIds: s.array(s.string()),
    })),
  }),
  catalog: s.object({
    components: s.map({ props: s.zod(), description: s.string() }),
  }),
}));
const designCatalog = defineCatalog(designSchema, {
  components: {
    rectangle: {
      props: z.object({
        x: z.number(), y: z.number(), width: z.number().positive(),
        height: z.number().positive(), fill: z.string().nullable(),
      }),
      description: "Rectangle in parent-local CSS pixels",
    },
  },
});
const prompt = designCatalog.prompt();
const result = designCatalog.validate(candidate); // candidate is untrusted JSON
```

A custom schema does **not** make `@json-render/react`'s `Renderer` understand `nodes/rootIds`. That renderer still consumes its built-in flat UI tree. The application must provide its own interpreter, compiler, or renderer. Here, compile validated design proposals into Pelagik operations and keep rendering with `SceneNodeView`. Additional validation must enforce hierarchy and domain invariants. `catalog.jsonSchema({ strict: true })` cannot represent dynamic-key records faithfully; published declarations say they become empty fixed-key objects. Avoid assuming a strict structured-output schema fully describes a `nodes` or `elements` map. [8][9]

## Model mismatch and preservation requirements

The built-in Spec has `{ root: string, elements: Record<string, UIElement>, state? }`. Elements contain `type`, `props`, child keys and optional events, visibility, repeat, and slots. Pelagik has multiple `rootIds`, nodes with explicit `id/parentId/childIds`, parent-local geometry, rotations, locks, flex settings, and document-level color variables. Similar flat maps do not make these interchangeable. A synthetic UI root could represent multiple roots for a preview, but supplies none of the missing editing semantics. [5][7][10]

The minimal useful integration should:

1. Keep proposal UI outside the editable canvas. Keep proposals transient initially; continue saving the existing `{ name, doc }` under `d3sign:file:v1`. No document migration is needed.
2. Stage a bounded operation batch against a captured revision. On Apply, use the existing service's idle check, revision check, request ID replay protection, schema checks, `applyOperations`, single `commit`, and persistence reporting. On conflict, reread and replan. Disable duplicate submissions and report failures.
3. Preserve stable IDs and use batch refs for new nodes. Send create/update/reparent/group operations instead of replacing the entire document. Keep child ordering, parent-local coordinates, rotation, frame clipping and flex derivation in design-core. Reparenting must use its transform-aware operation, not assign a new parent ID directly.
4. Preserve variable IDs and bindings through variable/bind operations. json-render `$state` expressions are runtime UI bindings, not Pelagik color-variable bindings.
5. Keep incomplete streamed specs and patches out of the live document. Validate and compile a complete proposal, validate the resulting transaction, then publish once. A json-render JSON Patch stream is not an `apply_edits` operation batch.
6. Continue using existing PNG rendering for agent feedback. `renderDocument` mounts the same `SceneNodeView` used by the canvas, waits for fonts, and captures it. Text measurement remains part of the existing settle/revision workflow. Adding another renderer would introduce visual and geometry drift.

These requirements follow the existing model and service, rather than capabilities supplied by json-render. Local sources: [types](../packages/design-core/src/types.ts), [operations](../packages/design-core/src/operations.ts), [batch validation](../packages/agent-api/src/edits.ts), [tool schemas](../packages/agent-api/src/schema.ts), [service](../apps/web/src/editor/agent/service.ts), [history](../apps/web/src/editor/state/store.ts), [persistence](../apps/web/src/editor/state/persistence.ts), [canvas rendering](../apps/web/src/editor/canvas/SceneNodeView.tsx), [PNG rendering](../apps/web/src/editor/agent/render.tsx).

No app code was changed or dependencies installed. API examples were checked against published declarations and official source; they were not compiled in the app.

## Primary sources

1. [Introduction](https://json-render.dev/docs.md) and [renderers](https://json-render.dev/docs/renderers).
2. [Catalog](https://json-render.dev/docs/catalog.md).
3. [Registry and action handlers](https://json-render.dev/docs/registry.md).
4. npm metadata: [core latest](https://registry.npmjs.org/@json-render/core/latest), [React latest](https://registry.npmjs.org/@json-render/react/latest); full [core release metadata](https://registry.npmjs.org/@json-render/core) and [React release metadata](https://registry.npmjs.org/@json-render/react) include dist-tags and publication timestamps.
5. Published `0.21.3` declarations and exports, inspected from the registry tarballs: [core tarball](https://registry.npmjs.org/@json-render/core/-/core-0.21.3.tgz), [React tarball](https://registry.npmjs.org/@json-render/react/-/react-0.21.3.tgz). Relevant files are `dist/index.d.ts`, core `dist/store-utils-vyT_VWJ6.d.ts`, React `dist/schema.d.ts`, and `package.json`.
6. [Installation](https://json-render.dev/docs/installation.md).
7. Official source pinned at inspected main commit `c6f73d7d5f69acb80fc89faefd12c0865c8603d1`: [React schema](https://github.com/vercel-labs/json-render/blob/c6f73d7d5f69acb80fc89faefd12c0865c8603d1/packages/react/src/schema.ts), [React renderer and registry](https://github.com/vercel-labs/json-render/blob/c6f73d7d5f69acb80fc89faefd12c0865c8603d1/packages/react/src/renderer.tsx). Main may differ from the published package; package declarations determined the examples above.
8. [Core API and schema builder](https://json-render.dev/docs/api/core.md), [React API and providers](https://json-render.dev/docs/api/react.md).
9. [Custom schema and renderer guide](https://json-render.dev/docs/custom-schema.md), [core schema implementation](https://github.com/vercel-labs/json-render/blob/c6f73d7d5f69acb80fc89faefd12c0865c8603d1/packages/core/src/schema.ts).
10. [Specs](https://json-render.dev/docs/specs.md), [schemas](https://json-render.dev/docs/schemas.md).
