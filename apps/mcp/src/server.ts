import { McpServer, type CallToolResult } from "@modelcontextprotocol/server"
import { serveStdio } from "@modelcontextprotocol/server/stdio"
import { getDesignCatalog } from "@pelagik/design-spec/catalog"
import { randomUUID } from "node:crypto"
import { z } from "zod"
import { toolDescriptions, toolSchemas, errorResult, type ToolName } from "@pelagik/agent-api/schema"
import { brokerRequest, ensureBroker } from "./local"

await ensureBroker()
const clientId = randomUUID()
const outputSchema = z.object({ data: z.unknown() }).strict()
serveStdio(() => {
  const server = new McpServer({ name: "pelagik", version: "0.1.0" })
  for (const name of Object.keys(toolSchemas) as ToolName[]) {
    server.registerTool(name, {
      description: toolDescriptions[name], inputSchema: toolSchemas[name], outputSchema,
      annotations: {
        readOnlyHint: !["apply_edits", "focus_nodes"].includes(name),
        destructiveHint: name === "apply_edits", openWorldHint: false,
        idempotentHint: name !== "apply_edits",
      },
    }, async (args: unknown): Promise<CallToolResult> => {
      try {
        const result = await brokerRequest(await ensureBroker(), "/call", { tool: name, args, clientId })
        if (result.error) return { isError: true, content: [{ type: "text", text: JSON.stringify(result.error) }] }
        const { png, ...data } = result
        return {
          structuredContent: { data },
          content: [
            { type: "text", text: JSON.stringify({ data }) },
            ...(png ? [{ type: "image" as const, mimeType: "image/png", data: png as string }] : []),
          ],
        }
      } catch (cause) {
        return { isError: true, content: [{ type: "text", text: JSON.stringify({ ...errorResult(cause), code: "BROKER_UNAVAILABLE", message: "Local broker is unavailable or timed out. Inspect before retrying a mutation; open Pelagik and retry after it reconnects." }) }] }
      }
    })
  }
  server.registerResource("sessions", "pelagik://sessions", { description: "Paired local editors", mimeType: "application/json" }, async (uri) => ({
    contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify(await brokerRequest(await ensureBroker(), "/status")) }],
  }))
  server.registerResource("catalog", "pelagik://catalog", { description: "Pelagik json-render design catalog, generated prompt, and schema", mimeType: "application/json" }, async uri => ({
    contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify(getDesignCatalog()) }],
  }))
  server.registerResource("guide", "pelagik://guide", { description: "Editing contract and operation schemas", mimeType: "application/json" }, async (uri) => ({
    contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify({
      designFormat: "Read pelagik://catalog. Generate a complete json-render design spec and submit insert_spec in apply_edits. Read back with get_document format=json-render. Imported IDs are remapped and returned in imports.",
      workflow: "list_sessions -> get_document/query_nodes -> apply_edits -> render -> refine. Run bun run agent:setup once from the monorepo. Desktop editors connect automatically; web editors pair once with bun run agent:pair.",
      coordinates: "Parent-local CSS pixels, integer geometry, clockwise degrees. Children are ordered back-to-front. Reparent preserves page-space placement. Flex positions are derived.",
      references: "Define ref on create/group/create_variable and use $ref in later operations in the same batch.",
      concurrency: "Read a revision, submit expectedRevision and a unique requestId. On REVISION_CONFLICT reread and replan. On OUTCOME_UNKNOWN inspect before retrying. Replay cache is scoped to this MCP client process and paired editor session, bounded to 10 minutes and 1000 writes.",
      limits: "100 operations per batch, 100 target IDs, 10000 nodes, 1000 variables, 64 hierarchy levels. get_changes retains 500 entries. Render maximum 4096 pixels per side, 16 million pixels, 16 MiB PNG.",
      edits: z.toJSONSchema(toolSchemas.apply_edits),
    }) }],
  }))
  return server
}, { onerror: error => console.error(error.message) })
