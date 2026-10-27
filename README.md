# d3sign

An open source design tool, built as a Figma-style canvas editor. The first milestone covers Figma's core editing features.

## Stack

- React 19 + Vite 8 + TypeScript (`apps/web`)
- shadcn/ui (Radix, `vega` preset: neutral palette, Inter, Lucide icons) on Tailwind CSS 4
- Zustand for editor state
- Bun workspaces + Turborepo

## Getting started

```sh
bun install
bun run dev         # or: cd apps/web && bun run dev
bun run typecheck
bun run test
bun run build
```

## What works

- **Tools:** move, frame, rectangle, ellipse, text (inline editing), hand
- **Canvas:** pan (wheel, space-drag, hand tool), zoom (ctrl/cmd + wheel, pinch, zoom menu, fit, selection, 100%)
- **Selection:** click, shift-click, marquee, select-all, double-click to enter groups and edit text
- **Transforms:** move (shift constrains axis), resize from 8 handles (shift keeps aspect), rotate (shift snaps 15°), arrow-key nudging
- **Structure:** frames clip their children, nested frames, groups (with resize that stretches contents), drag a shape into a frame
- **Flex:** frames stack children in a row or column with gap, padding, and alignment, and reflow as children change
- **Layers panel:** tree view, rename, show/hide, lock, collapse, drag-and-drop reordering and reparenting
- **Design panel:** position, size, rotation, opacity, corner radius, fill, stroke, text size/weight/alignment, alignment tools
- **Editing:** undo/redo (coalesced per field), copy, paste, duplicate, delete, group/ungroup, bring forward/back, context menu
- **Persistence:** the document autosaves to local storage

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
apps/web/src/editor/
  model/     pure document model: geometry, operations, hit testing, viewport (unit tested)
  state/     zustand store, commands, autosave
  canvas/    canvas controller, node rendering, selection overlay, toolbar
  panels/    layers, design inspector, top bar, shortcuts dialog
```

The document is a flat node table plus a child list per frame or group. Each node stores its
position relative to its parent and a rotation. Transforms are composed as 2D matrices, so
nested frames rotate and clip correctly.
