# Working on Pelagik

Pelagik is a web and Electron design editor. Both apps share the React editor in
`apps/web`; keep editing behavior consistent across them.

## Read before changing

- Read `README.md` for setup, current capabilities, and workspace layout.
- For design schema, import/export, or persistence changes, read
  `docs/json-render.md`.
- For agent tools, pairing, broker, or connection changes, read `docs/mcp.md`.
  Research and plan documents under `docs/` provide background; check current
  implementation and API docs before treating a proposal as shipped behavior.

## Development

Use Bun and the checked-in `bun.lock`. Run commands from the repository root
unless a command specifies a workspace. Root and workspace `package.json` files
are the source of truth for scripts.

```sh
bun install
bun run dev             # web editor
bun run dev:desktop     # Electron with its own Vite server on 127.0.0.1:5174
bun run typecheck
bun run test
bun run build
```

For a focused test run, use `bun run --cwd <workspace> test`. Web and shared
packages use Vitest; `apps/mcp` uses Bun's test runner. Use workspace scripts
rather than running `bun test` across the monorepo.

`bun run lint` currently has no workspace lint scripts to execute. It is not a
substitute for typechecking or tests.

## Code boundaries

- `packages/design-core` owns the pure document model, geometry, flex layout,
  variables, hit testing, and immutable operations. Keep React, browser APIs,
  Electron, and transport code out of it.
- `packages/design-spec` owns the json-render catalog, validation, and conversion
  between specs and the canvas model.
- `packages/ui` owns shared shadcn components and theme styles.
- `packages/agent-api` owns shared tool schemas and atomic edit validation.
- `apps/web/src/editor/state` owns Zustand state, commands, history, and autosave.
  Canvas and panel components call these editing paths.
- `apps/web/src/editor/agent` adapts the editor to agent requests and PNG capture.
  `apps/mcp` owns the stdio server, local broker, CLI, and client setup.
- `apps/desktop` owns Electron lifecycle, preload, and packaging. Reuse the web
  editor instead of implementing desktop-only editing logic.

Import shared code through `@pelagik/<package>/<module>`, as existing callers do.
Keep dependency direction toward the shared packages.

## Editing invariants

- json-render specs are the canonical design format. `Document` is a derived
  canvas projection. Route document writes through `canonicalDesign` and the
  store's editing actions so canvas, history, and saves agree.
- Use `commit` for completed edits. During a gesture, use `preview`, then
  `endGesture` with the starting document to create one undo step. Preserve
  coalescing for repeated field edits and nudges.
- Treat existing documents as immutable. Preserve unchanged object identities
  where possible; rendering and change tracking depend on them.
- Positions are relative to the parent. Use shared matrix and geometry helpers
  for page coordinates, rotated parents, hit testing, and reparenting. Child lists
  run back-to-front, while the layers panel displays topmost first.
- Keep hierarchy, flex reflow, group bounds, color bindings, and pixel rounding
  consistent through shared operations. A new editable property may need changes
  in core types/defaults, the spec catalog/converters, agent schemas, and the UI.
- Preserve legacy saves and the original `d3sign:file:v1` storage key. Preserve
  Electron's legacy profile migration. Format changes need migration coverage.

## UI and integration

Match nearby TypeScript style: two spaces, double quotes, no semicolons, and
explicit type-only imports. Reuse components in `packages/ui/src/components` and
theme tokens in `packages/ui/src/styles/globals.css`. Check shared control changes in light
and dark themes, including hover, pressed, selected, disabled, and keyboard focus
states. Keep icon controls accessible by name.

Keep the Electron renderer sandboxed with context isolation and no Node access.
Expose only narrow preload APIs. Keep the packaged renderer usable offline.

For agent edits, preserve atomic rollback, revision conflicts, request replay,
locks, busy-gesture handling, and single-step undo. Reserve MCP stdout for protocol
messages and send diagnostics to stderr. Use isolated agent directories and
temporary profiles in tests; setup commands modify real client configuration.

## Verification

For code changes, run relevant workspace tests and `bun run typecheck`. Run
`bun run build` when changing bundling, dependencies, or desktop integration.
Add regression coverage for changed model behavior, serialization, migrations,
or edit validation in the existing adjacent test suites.

For changes spanning the MCP server and editor, also run
`bun run test:mcp:e2e`. It builds and launches Electron with a temporary profile
and requires a graphical environment. See `docs/mcp.md` for test options.

For canvas interactions, manually check the affected gesture, selection, undo/redo,
and save/reload behavior. Report which checks ran and any environment limits.
