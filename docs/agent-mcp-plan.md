# Agent access to pelagik

Status: implemented for local stdio clients, paired web/Electron editors, and json-render design specs. See [MCP setup](mcp.md) and [json-render designs](json-render.md). The sections below preserve the original architecture plan; hosted transport and change notifications remain future work.

## Recommendation

Add a local MCP server that connects agents to an explicitly paired browser editor session. The browser remains the document owner for the first release. Agents inspect structured design data, submit typed edit batches, and inspect rendered results. Human and agent changes share history and autosave.

Target MCP revision `2026-07-28` and the stable split TypeScript SDK, currently `@modelcontextprotocol/server@2.4.0`, verified on 2026-10-27. Recheck versions when implementation starts. Pin the SDK version in the lockfile and use its supported discovery and version metadata. Current protocol research and primary sources live in [mcp-research.md](mcp-research.md). Do not equate the newest SDK prerelease with the latest stable protocol.

Assumption: the first users run their agents and pelagik on the same machine. Hosted agents and unattended editing are later deployments of the same document API.

## What exists today

- `apps/web/src/editor/model/` contains pure document operations, geometry, flex layout, and color variables. Reuse these operations.
- `state/store.ts` owns the active document, selection, viewport, and snapshot undo history. `commit` adds history; `preview` changes the document during gestures and text measurement.
- `state/commands.ts` mostly operates on the current selection. Agent edits need explicit IDs so a user's selection cannot redirect a command.
- `state/persistence.ts` saves one document to browser local storage. There is no backend, stable file identity, revision number, or agent interface.
- `canvas/SceneNodeView.tsx` uses DOM elements and browser text measurement. Rendering is not an HTML canvas screenshot API. Text measurement currently changes the document outside undo history.

## Connection and ownership

Agent MCP client -> local pelagik MCP process -> authenticated browser bridge -> editor document service -> existing model operations and store.

Start with stdio for the MCP connection. Clients launch a small `pelagik-mcp` executable. Keep stdout exclusively for MCP messages and send logs to stderr. The executable connects to one local broker that owns the browser bridge, so multiple agent clients do not compete to bind the same port. Define discovery and broker startup as part of the CLI, including cleanup of stale discovery records.

The broker binds only to loopback. The browser initiates a WebSocket connection and pairs using a short-lived one-use credential. Validate browser Origin and Host, authenticate bridge connections, and store broker discovery credentials in a user-only runtime file. Do not rely on CORS or a guessed localhost port as authentication. Show connected agents and a disconnect control in the editor. Local stdio does not need an OAuth deployment.

Each browser tab registers a unique application session ID and document ID. These are pelagik routing identifiers, not MCP protocol sessions; the current MCP revision removed protocol sessions. Tool calls always include a session ID. Never silently choose the most recently active tab. An editor reload invalidates its session and revision epoch, including outstanding requests. Opening the same persisted document in two tabs produces separate sessions in this release; they are not synchronized replicas.

If the editor is closed, return `EDITOR_UNAVAILABLE`. Do not create a separate server-side document copy and pretend the browser has received edits.

Add Streamable HTTP for remote clients when there is an actual hosted use case. Reuse the document service and tool schemas. Implement the specification's HTTP authorization and origin protections at that point. Use current discovery and request metadata, without assuming the older `initialize`, `Mcp-Session-Id`, or standalone GET stream behavior. Do not start a new integration on legacy HTTP+SSE.

## Document service

Create a transport-independent service with explicit operations such as `inspect`, `query`, `applyBatch`, `getChanges`, and `render`. The browser adapter owns access to Zustand. MCP handlers validate requests and forward them; they do not import the browser store or mutate local storage.

Suggested boundaries:

- `packages/design-core`: existing pure document model and operations, moved with existing tests and no browser globals.
- `packages/agent-api`: runtime schemas, typed operations, validation, results, and document-service contracts.
- `apps/web/src/editor/agent`: service adapter, bridge client, connection UI, render integration, revision tracking.
- `apps/mcp`: executable, broker lifecycle, MCP tools/resources, routing, authentication, and bounded request handling.

Extract model code first without changing its behavior. Keep React, Zustand, and persistence out of the shared model. Move selection-based UI commands toward the same explicit-ID service as needed, without rewriting the editor all at once.

## Initial tools

| Tool | Purpose |
| --- | --- |
| `list_sessions` | List paired editors, document names, capabilities, busy state, and revisions. |
| `get_document` | Return document summary, bounded hierarchy, supported node properties, variables, and revision. |
| `query_nodes` | Find nodes by IDs, subtree, type, name, or text with pagination and bounded results. |
| `get_selection` | Read the user's selection and viewport as context. |
| `apply_edits` | Validate and atomically apply an ordered batch against an expected revision. |
| `get_changes` | Return changes since a revision, or require a fresh snapshot if the bounded log expired. |
| `render` | Return a PNG of a requested frame, node set, or viewport at a stated revision. |
| `focus_nodes` | Explicitly select and reveal nodes when requested. |

Expose document summaries and node schemas as resources too, but keep read tools available for clients that use tools more reliably than resources. Resources are read-only. Return structured tool results with output schemas and a serialized JSON text fallback. Mark read-only and destructive tools with accurate MCP annotations; annotations do not enforce permissions.

Avoid arbitrary JavaScript execution, DOM access, filesystem writes, and raw document replacement. Add dedicated operations only when the model supports them. Do not advertise components, image fills, multiple pages, or exports that do not exist yet.

### Edit contract

`apply_edits` accepts `sessionId`, `expectedRevision`, `requestId`, and `operations`. Operations initially cover create, update allowed properties, delete, duplicate, reparent/reorder, group/ungroup, flex configuration, and color variable creation/update/binding. Creation accepts batch-local references so children can reference a frame created earlier in the same batch.

Validate every operation and the final document before publishing. Check IDs, parent types, cycles, finite dimensions, pixel normalization, valid property combinations, bindings, and limits on batch size and tree depth. Use property allowlists per node type. Never accept `id`, `parentId`, or `childIds` through a generic property patch. Define edits to locked nodes as errors unless an explicit unlock operation precedes them.

Apply the batch to an isolated candidate document using existing operations, resolve flex layout, and commit once. An invalid operation rolls back the whole batch. A successful batch is one undo step and does not steal selection or move the viewport. Return created IDs, changed IDs, deleted IDs, final revision, layout status, and persistence status.

Use an opaque epoch plus monotonic counter for revisions. Serialize writes per session and check the expected revision in the browser immediately before application. Reject stale writes with `REVISION_CONFLICT`. Concurrent agents reread and replan. Do not automatically retry an old edit against new content.

Track all document changes, including undo, redo, and browser-derived text measurements. Reject writes with `EDITOR_BUSY` during pointer gestures and inline editing so an agent cannot replace a user's in-progress document. Reads can return a busy marker. Never treat an MCP session ID as document authorization.

Cache request results by authenticated client, session epoch, and request ID, with a payload digest and bounded retention. Replays return the original result; reuse with different content fails. After disconnection or cache expiry, report that the outcome is unknown and require inspection rather than blindly resubmitting a creation batch.

Text measurements need an explicit settling contract. Return the initial commit revision with `layoutPending` when browser measurement is outstanding. `render` and subsequent settled reads wait for font loading, React rendering, and bounded layout completion, then report the actual revision. Later measurement updates advance revisions and must stay part of the same logical undo unit. Set a timeout and return a clear layout error instead of waiting indefinitely.

Autosave currently swallows storage failures. Make save results observable before claiming durable success. A successful edit means it changed the live document; `persistenceStatus` separately reports pending, saved, or failed.

### Example workflow

1. Agent lists sessions and chooses the explicit target.
2. Agent reads a frame and its variables at revision R.
3. Agent submits a batch creating a vertical frame, heading, and button with references between those creations, using R and a unique request ID.
4. Browser validates, commits one undo step, and reports IDs plus layout status.
5. Agent requests a settled render and inspects the image and measured geometry.
6. Agent rereads if necessary and submits a refinement against the resulting revision. The user can undo each batch.

## Visual feedback

Build frame PNG capture as a real deliverable, because agents need to see their work. Start with the existing DOM renderer and validate a DOM-to-image implementation against clipping, nested rotation, fonts, text wrapping, opacity, and flex layout. Wait for fonts and layout, enforce maximum dimensions and pixel count, and include revision, bounds, and scale in the result. Return MCP image content plus structured metadata.

If DOM capture cannot meet those fixtures, implement an export renderer backed by the model. Do not claim screenshot support until the fixtures pass. SVG export and full file export can follow separately.

## Multiple agents and events

Use optimistic revisions and serialized batches first. This handles multiple agent connections without introducing multiplayer or a CRDT. Include client identity, request ID, changed node IDs, and revision in an in-memory activity log. Show agent activity in the editor.

Offer bounded `get_changes` as the portable baseline. Add `subscriptions/listen` resource subscriptions and update notifications for clients that support the current revision. Do not implement the older `resources/subscribe` flow as the current default. Notifications are hints to reread, not guaranteed delivery or permission to act. Bound queues and disconnect slow clients. Avoid making the first release depend on experimental tasks, sampling, or unsolicited server requests.

## Delivery sequence

1. Extract the model and add schemas, document validation, explicit-ID batch execution, revisions, busy handling, deduplication, and one-step undo. Verify invalid batches leave the document unchanged and concurrent stale writes fail.
2. Add broker discovery, pairing UI, session routing, bridge lifecycle, and read-only stdio tools. Verify two tabs, two clients, reload, browser closure, invalid origins, and unauthorized connections.
3. Enable writes and color variables through `apply_edits`. Verify create/update/delete/group/reparent/flex operations, reference resolution, locked nodes, replay handling, user gestures, undo/redo, and persistence failure reporting.
4. Add settled reads and PNG rendering. Verify actual browser text measurement, font loading, rendering fixtures, bounded output, and layout timeouts.
5. Publish the executable and document client configuration for a tested stdio MCP client. Run an end-to-end create/inspect/render/refine/undo workflow with two agent clients and a human edit conflict.
6. Add hosted Streamable HTTP only when remote agent access is needed, along with durable storage, user identity, and document authorization.

First release is complete when an agent can connect to an explicitly paired editor, inspect a document, create and refine a small layout, see a PNG, recover from a revision conflict, and let the user undo each edit batch. Disconnects and retries must not create duplicate nodes.

## Decisions to revisit

The local-first assumption, which agent clients to certify, and whether agents must edit with the browser closed affect deployment. They do not block the shared API design. Unattended editing requires moving document ownership, text layout, persistence, and rendering into a service; it is a separate milestone rather than an invisible extension of the browser bridge.
