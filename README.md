# pelagik

An open source design tool for the web and desktop, built as a Figma-style canvas editor. The first milestone covers Figma's core editing features.

## Stack

- React 19 + Vite 8 + TypeScript (`apps/web`)
- shadcn/ui (Radix, `vega` preset: neutral palette, Inter, Lucide icons) on Tailwind CSS 4
- Zustand for editor state
- json-render catalog and editable design specs (`@json-render/core`)
- Bun workspaces + Turborepo

## Getting started

```sh
bun install
bun run dev         # web editor
bun run dev:desktop # Electron editor with Vite hot reload
bun run typecheck
bun run test
bun run build
```

## Shared UI

Shared shadcn components and theme styles live in `packages/ui`. Import components
with paths such as `@pelagik/ui/components/button`. The web stylesheet imports
`@pelagik/ui/styles/globals.css`, which also registers the shared Tailwind sources.

Add components from the web workspace so shadcn uses its monorepo aliases:

```sh
bun x shadcn@latest add button --cwd apps/web
```

## Desktop app

The Electron app uses the same React editor as the website. Run these commands from the repository root:

```sh
bun run dev:desktop  # starts its own Vite server on 127.0.0.1:5174
bun run desktop      # builds and opens the local production app
bun run pack:desktop # builds an unpacked app for this operating system
bun run dist:desktop # builds an installer for this operating system
```

`bun run build` builds both the website and desktop app. Web output stays in
`apps/web/dist`; Electron bundles its own copy in `apps/desktop/dist/renderer`.
Desktop packages go into `apps/desktop/release`. Packaging targets are AppImage
on Linux, DMG on macOS, and NSIS on Windows. Build releases on each target OS.
Distribution signing and notarization need release credentials and are not configured.

The packaged app runs without a development server or internet connection.
Desktop autosave uses Electron's own browser profile, separate from your web
browser. Existing web documents are not automatically transferred. The rename
from d3sign preserves the original save keys and reuses an existing desktop profile. The desktop
renderer is sandboxed, has no Node access, and cannot open new windows or navigate
to other pages. A narrow preload API obtains local agent connection credentials after one-time setup.

Electron's install script is trusted in the root package manifest so `bun install`
can download its desktop runtime.

## Agent access

The MCP server lets agents inspect and edit the open web or desktop editor and
request PNG previews. Run `bunx pelagik setup` once to detect and configure
installed Codex, Claude Code, and Cursor clients. Desktop connects automatically
and reconnects after restarts. Web editors pair once with `bunx pelagik pair`.
Any agent can also use `bunx pelagik status` and `bunx pelagik call TOOL 'JSON'`
directly, without an MCP host.

See [MCP setup and tool reference](docs/mcp.md) for client configuration,
operations, conflict handling, and tests.

## Design JSON

All manual and agent edits use json-render as the canonical design format, including
live previews, undo history, and saves. Older saves migrate when next saved.

Click **Design JSON** to export selected layers or the document as a json-render
spec, or paste a spec and insert it as editable layers. MCP agents can read the
catalog at `pelagik://catalog`, insert specs through `apply_edits`, and read them
back with `get_document` in json-render format.

See [editable designs with json-render](docs/json-render.md) for the format,
examples, validation, and agent workflow.

## What works

- **Tools:** move, frame, rectangle, ellipse, text (inline editing), hand
- **Images:** insert PNG, JPEG, GIF, or WebP files with the toolbar or drag them onto the canvas. Images are embedded in the design.
- **Icons:** insert (`I`) from Lucide, Hugeicons, Phosphor, Tabler, Remix, or any Iconify set. Icons are editable vectors colored by fill. Searching needs an internet connection; icons already in a design keep their artwork offline.
- **Canvas:** pan (wheel, space-drag, hand tool), zoom (ctrl/cmd + wheel, pinch, zoom menu, fit, selection, 100%)
- **Selection:** click, shift-click, marquee, select-all, double-click to enter groups and edit text
- **Transforms:** move (shift constrains axis), resize from 8 handles (shift keeps aspect), rotate (shift snaps 15°), arrow-key nudging
- **Structure:** frames clip their children, nested frames, groups (with resize that stretches contents), drag a shape into a frame
- **Flex:** frames stack children in a row or column with gap, padding, and alignment, and reflow as children change
- **Layers panel:** tree view, rename, show/hide, lock, collapse, drag-and-drop reordering and reparenting
- **Design panel:** position, size, rotation, opacity, corner radius, fill, stroke, shader effects, text size/weight/alignment, alignment tools
- **Shaders:** browse effects and 75 shader families in the Library, with five variants each; sources and previews are bundled for offline use, including Liquid Glass styles for iOS screens
- **Editing:** undo/redo (coalesced per field), copy, paste, duplicate, delete, group/ungroup, bring forward/back, context menu
- **Persistence:** designs autosave to IndexedDB on this device and can be opened from the dashboard; existing local saves are imported once

## Not yet

- Flex sizing modes (hug and fill), components, and variants
- Vector pen and line tools
- Multiple pages
- Image fills and gradients, multiple fills/strokes
- Export (PNG, SVG)
- Smart guides and snapping
- File format import/export (including `.pen`)
- Multiplayer and a backend

## Layout

```
packages/ui/           shared shadcn components and theme styles
packages/design-core/  pure document model, geometry, operations, and tests
packages/design-spec/  json-render catalog and document compiler
packages/agent-api/    shared tool schemas and atomic edit validation
apps/mcp/             stdio MCP server, local broker, and pairing CLI
apps/desktop/         Electron main process, launcher, and packaging
apps/web/src/editor/
  agent/     browser bridge, document service, connection UI, PNG capture
  state/     zustand store, commands, autosave
  canvas/    canvas controller, node rendering, selection overlay, toolbar
  panels/    layers, design inspector, top bar, shortcuts dialog
```

The document is a flat node table plus a child list per frame or group. Each node stores its
position relative to its parent and a rotation. Transforms are composed as 2D matrices, so
nested frames rotate and clip correctly.
