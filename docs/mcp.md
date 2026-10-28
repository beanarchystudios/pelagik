# Pelagik MCP server

Pelagik exposes eight tools over stdio using MCP revision `2026-07-28` and
`@modelcontextprotocol/server@2.4.0`. The SDK's stdio entry also supports legacy
clients. Agents connect to an explicitly paired, open web or Electron editor.

## Connect

Run once:

```sh
bunx pelagik setup
```

Setup detects Codex, Claude Code, and Cursor through executables and existing
configuration directories. It configures installed clients at user scope,
preserves their other settings, and backs up changed configuration files with a
`.pelagik-backup` suffix. `bunx pelagik setup --dry-run` lists detections without
changing anything. Detection of a config directory without an available Codex CLI
reports a failure rather than guessing at TOML edits.

Setup installs a bundled runtime under
`${XDG_STATE_HOME:-~/.local/state}/pelagik/agent/runtime`, so client configuration
continues working if the checkout moves. Bun must remain installed. Rerun setup
to update the installed runtime. Restart agent clients once
to load their new MCP configuration. Codex registration uses its supported
[`codex mcp add` command](https://developers.openai.com/codex/mcp/).

Open the updated Pelagik desktop app. It connects automatically after setup,
including after reload, app restart, or broker restart. Each window has its own
session. The broker starts on demand, so no daemon installation or login service
is needed. MCP clients rediscover the broker before each call.

A web browser cannot read local setup files. For a web editor, run
`bunx pelagik pair`, open **Agents**, and paste the code once. The browser remembers
its trust and reconnects afterward, including after broker restarts. Initial codes
expire after two minutes; remembered trust has no time-based expiry.

**Disconnect agents** stops reconnection for that editor profile and forgets its
browser credential. In desktop, **Enable automatic connection** enables it again.
Closing or reloading a window invalidates its session ID. Agents must rediscover
sessions rather than reuse IDs from closed windows. An editor must be open to edit.

For another MCP host, setup prints a generic config if no supported client is
found. The server command is Bun plus the installed `runtime/server.js` path.
Do not configure the browser bridge URL as an MCP HTTP endpoint.

### Direct CLI access

Any local agent can also call the same tools without configuring an MCP host:

```sh
bunx pelagik status
bunx pelagik call list_sessions '{}'
bunx pelagik call get_document '{"sessionId":"<session ID>"}'
bunx pelagik call apply_edits '{"sessionId":"<session ID>","expectedRevision":"<revision>","requestId":"<unique ID>","operations":[{"op":"update","ids":["<layer ID>"],"props":{"fill":"#0088cc"}}]}'
```

CLI calls return JSON, and tool errors produce a nonzero exit status. Direct calls
share a CLI replay identity, so use unique request IDs for unrelated edits. Agents
can edit every layer in the document, including layers outside the selection.
Locked nodes can be explicitly unlocked before editing. The same atomic edits,
revision checks, and undo behavior apply to MCP, CLI, and manual edits.

## Tools

| Tool | Use |
| --- | --- |
| `list_sessions` | Discover paired editor sessions and their revisions. |
| `get_document` | Read the canonical json-render spec by default, or a bounded hierarchy using `format: "summary"`. |
| `query_nodes` | Query IDs, subtrees, types, or name/text substrings and inspect full properties and page bounds. |
| `get_selection` | Read selection, viewport, canvas size, revision, and busy state. |
| `apply_edits` | Submit an atomic batch against an expected revision. |
| `get_changes` | Read the bounded revision log. |
| `render` | Get a PNG crop of node bounds, the viewport, or the whole document. |
| `focus_nodes` | Explicitly select and reveal nodes. |

Success results use `structuredContent.data`, with the same data serialized in a
text content block. Render results also contain an MCP `image` block; the PNG is
not duplicated inside JSON. Errors set `isError` and return a text JSON object
with `code` and `message`.

Resources `pelagik://sessions`, `pelagik://guide`, and `pelagik://catalog` provide
paired sessions, the editing contract, and the json-render component catalog with
a generated prompt and schemas. See [json-render designs](json-render.md). Change notifications
and hosted Streamable HTTP are not implemented. Use `get_changes` for updates.

## Editing

Read a settled revision before writing. `apply_edits` requires `sessionId`,
`expectedRevision`, `requestId`, and `operations`. Example arguments:

```json
{
  "sessionId": "<session returned by list_sessions>",
  "expectedRevision": "<revision returned by get_document>",
  "requestId": "layout-001",
  "operations": [
    {
      "op": "create", "type": "frame", "ref": "card",
      "props": { "name": "Card", "width": 320, "height": 240,
        "flex": { "direction": "vertical", "gap": 16, "padding": 24,
          "mainAlign": "start", "crossAlign": "start" } }
    },
    {
      "op": "create", "type": "text", "ref": "title", "parentId": "$card",
      "props": { "text": "Hello Pelagik", "width": 272, "fontSize": 24 }
    }
  ]
}
```

Supported operations are `insert_spec`, `create`, `update`, `delete`, `duplicate`, `group`,
`ungroup`, `reparent`, `reorder`, `lock`, `create_variable`, `update_variable`,
`delete_variable`, and `bind_variable`. Use `lock` with `locked: false` before
editing locked nodes. Generic updates cannot change IDs or hierarchy fields.
`ref` is available on create, group, variable creation, and single-root spec insertion; later operations use
`$ref`. Created node IDs and the reference mapping are returned.

Coordinates are local to the parent in CSS pixels; geometry rounds to whole
pixels. Rotation is clockwise in degrees. Children are back-to-front. Creation
defaults to 100 by 100 pixels. Reparenting preserves page placement. Frame flex
layout derives child positions. Solid CSS colors are supported.

A batch validates before committing and creates one undo step. It does not
change selection or viewport. Human undo and redo remain available. Writes are
rejected during pointer gestures, inline text editing, or focused text fields.

Text height comes from browser measurement. Edits return `layoutPending` when
text was changed; use a subsequent read or render to wait for layout. All document
changes, including measurement, undo, and redo, advance revisions. A read or PNG
reports the revision it represents; rendering fails if the document changes during
capture. The PNG uses the existing scene renderer, excludes editor labels and
selection overlays, and crops the requested page region against white.

`persistenceStatus: saved` means the returned committed snapshot was written to
local storage. Measurement can produce a later autosaved revision. A storage
failure reports `failed` even though the live edit succeeded.

### Conflicts and retries

- `REVISION_CONFLICT`: reread, then replan against the current revision.
- `EDITOR_BUSY`: let the human finish their edit before trying again.
- `SNAPSHOT_REQUIRED`: the requested revision is outside the change log or from
  another session. Read a fresh snapshot.
- `EDITOR_UNAVAILABLE`: the target session disconnected. Discover its replacement with `list_sessions` after reconnection.
- `OUTCOME_UNKNOWN` or `BROKER_UNAVAILABLE`: inspect before resubmitting a mutation.
  An edit may already have completed.

Identical request-ID replays return the original write result. Reusing the ID with
a different payload fails. The replay cache lasts up to ten minutes and 1000 writes
per paired editor, scoped to each MCP client process. A new process or editor
session has a new identity. Never assume retries remain deduplicated forever.

Limits are 100 operations per batch, 100 target IDs, 10000 nodes, 1000 variables,
and 64 hierarchy levels. Queries return at most 500 nodes per page. The change log
retains 500 entries. PNGs are limited to 4096 pixels per side, 16 million pixels,
and 16 MiB. Fonts and layout have bounded waits; image capture times out after ten
seconds, and broker calls time out after thirty seconds.

## Local connection

The broker binds to `127.0.0.1:48765`. Its control API requires a random credential
stored in a user-only `broker.json` inside
`${XDG_STATE_HOME:-~/.local/state}/pelagik/agent`. The directory uses mode 0700 and
the descriptor uses 0600. Stdout is reserved for MCP messages; diagnostics use
stderr. Pairing credentials are sent in the first WebSocket message and consumed
once, rather than placed in URLs. Browser trust credentials are persisted as hashes
in a user-only `editors.json`; the browser keeps its credential in local storage.
Desktop requests fresh one-use credentials through its narrow preload bridge,
using the installed runtime recorded by setup. Credentials are never exposed in
stdout during setup.

The default allowed browser origins are localhost and 127.0.0.1 on ports 5173 and
5174, plus Electron file origins. The broker validates Origin and Host before
accepting connections. Its authenticated process endpoints reject browser Origins.

Optional environment variables, set consistently for pairing and MCP clients:

- `PELAGIK_AGENT_PORT`: another loopback port, from 1024 to 65535.
- `PELAGIK_AGENT_DIR`: another private runtime directory.
- `PELAGIK_AGENT_ORIGINS`: comma-separated exact additional editor Origins.

For other web dev ports, add the exact origin before starting the broker. Hosted
HTTPS-to-localhost browser policies vary; this release targets locally served web
editors and Electron. There is no remote access or browser-closed editing.

## Checks

```sh
bun run typecheck
bun run build
bun run --cwd packages/design-spec test
bun run --cwd packages/agent-api test
bun run --cwd apps/web test
bun run --cwd apps/mcp test
bun run test:mcp:e2e
```

The last command launches Electron with a temporary profile and tests the actual
stdio client, pairing dialog, editable canvas, PNG pixels, two clients, conflicts,
retry handling, undo/redo, and reload. The editor window stays hidden while the
test runs. Set
`PELAGIK_KEEP_TEST_ARTIFACTS=1` to retain its temporary fixture files. Broker tests
exercise both the current protocol and the legacy handshake.
