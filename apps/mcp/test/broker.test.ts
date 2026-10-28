import { afterAll, beforeAll, expect, test } from "bun:test"
import { mkdtemp, readFile, rm, stat } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { Client } from "@modelcontextprotocol/client"
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio"

let broker: ReturnType<typeof Bun.spawn>
let directory: string
let discovery: { url: string; token: string }
let port: number
const clients: Client[] = []
const sockets: WebSocket[] = []
const root = fileURLToPath(new URL("../../../", import.meta.url))
async function request(route: string, body?: unknown) {
  const response = await fetch(discovery.url + route, {
    method: body === undefined ? "GET" : "POST", headers: { authorization: `Bearer ${discovery.token}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  expect(response.status).toBe(200)
  return response.json() as Promise<any>
}
async function pair() {
  const pairing = await request("/pairing", {})
  const socket = new WebSocket(pairing.url, { headers: { Origin: "http://localhost:5173" } })
  sockets.push(socket)
  let token: string | undefined
  const sessionId = await new Promise<string>((resolve, reject) => {
    socket.onopen = () => socket.send(JSON.stringify({ type: "hello", code: pairing.code, status: { name: "Test editor", revision: "test:0", busy: false } }))
    socket.onerror = reject
    socket.onmessage = event => {
      const message = JSON.parse(String(event.data))
      if (message.type === "paired") { token = message.token; resolve(message.sessionId) }
    }
  })
  return { socket, sessionId, pairing, token }
}
beforeAll(async () => {
  directory = await mkdtemp(path.join(tmpdir(), "pelagik-broker-test-"))
  const probe = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response() })
  port = probe.port!
  probe.stop(true)
  broker = Bun.spawn([process.execPath, path.join(root, "apps/mcp/src/broker.ts")], {
    env: { ...process.env, PELAGIK_AGENT_DIR: directory, PELAGIK_AGENT_PORT: String(port) }, stdout: "ignore", stderr: "inherit",
  })
  for (let attempt = 0; attempt < 100; attempt++) {
    try { discovery = JSON.parse(await readFile(path.join(directory, "broker.json"), "utf8")); break } catch { await Bun.sleep(20) }
  }
  if (!discovery) throw new Error("Broker did not start")
})
afterAll(async () => {
  for (const client of clients) await client.close()
  for (const socket of sockets) socket.close()
  broker?.kill(); await broker?.exited
  await rm(directory, { recursive: true, force: true })
})
test("discovery credentials are private; control API rejects unauthorized requests and browser Origins", async () => {
  expect((await stat(path.join(directory, "broker.json"))).mode & 0o777).toBe(0o600)
  expect((await fetch(discovery.url + "/status")).status).toBe(403)
  expect((await fetch(discovery.url + "/status", { headers: { authorization: `Bearer ${discovery.token}`, Origin: "https://evil.test" } })).status).toBe(403)
  expect((await fetch(discovery.url + "/bridge", { headers: { Origin: "https://evil.test" } })).status).toBe(403)
})
test("pairing codes are one-use and only explicitly paired editors are listed", async () => {
  const { socket, sessionId, pairing } = await pair()
  expect((await request("/status")).sessions.some((s: any) => s.sessionId === sessionId)).toBe(true)
  const replay = new WebSocket(pairing.url, { headers: { Origin: "http://localhost:5173" } })
  replay.onopen = () => replay.send(JSON.stringify({ type: "hello", code: pairing.code, status: { name: "replay", revision: "0", busy: false } }))
  const closed = await new Promise<CloseEvent>(resolve => { replay.onclose = resolve })
  expect(closed.code).toBe(1008)
  socket.close()
})
test("real MCP stdio client discovers eight tools, reads resources, routes calls and receives PNG content", async () => {
  const { socket, sessionId } = await pair()
  socket.onmessage = event => {
    const message = JSON.parse(String(event.data))
    if (message.type === "call") {
      const result = message.tool === "render"
        ? { revision: "test:0", png: "iVBORw0KGgo=", width: 1, height: 1 }
        : { revision: "test:0", ids: ["selected"] }
      socket.send(JSON.stringify({ type: "result", id: message.id, result }))
    }
  }
  const client = new Client({ name: "pelagik-test", version: "1.0.0" })
  clients.push(client)
  await client.connect(new StdioClientTransport({ command: process.execPath, args: [path.join(root, "apps/mcp/src/server.ts")], env: { ...process.env as Record<string, string>, PELAGIK_AGENT_DIR: directory, PELAGIK_AGENT_PORT: String(port) } }))
  const tools = await client.listTools()
  expect(tools.tools.map(tool => tool.name).sort()).toEqual(["apply_edits", "focus_nodes", "get_changes", "get_document", "get_selection", "list_sessions", "query_nodes", "render"])
  const resource = await client.readResource({ uri: "pelagik://sessions" })
  expect(resource.contents).toHaveLength(1)
  const selection = await client.callTool({ name: "get_selection", arguments: { sessionId } })
  expect(selection.isError).not.toBe(true)
  expect(selection.structuredContent).toEqual({ data: { revision: "test:0", ids: ["selected"] } })
  const rendered = await client.callTool({ name: "render", arguments: { sessionId } })
  expect(rendered.content?.some((item: any) => item.type === "image")).toBe(true)
  expect(JSON.stringify(rendered.structuredContent)).not.toContain("iVBOR")
  const unavailable = await client.callTool({ name: "get_document", arguments: { sessionId: crypto.randomUUID() } })
  expect(unavailable.isError).toBe(true)
  expect(JSON.stringify(unavailable.content)).toContain("EDITOR_UNAVAILABLE")
})
test("current 2026-07-28 discovery and metadata work without a legacy handshake", async () => {
  const client = new Client({ name: "modern-pelagik-test", version: "1.0.0" }, { versionNegotiation: { mode: { pin: "2026-07-28" } } })
  clients.push(client)
  await client.connect(new StdioClientTransport({ command: process.execPath, args: [path.join(root, "apps/mcp/src/server.ts")], env: { ...process.env as Record<string, string>, PELAGIK_AGENT_DIR: directory, PELAGIK_AGENT_PORT: String(port) } }))
  expect((await client.listTools()).tools).toHaveLength(8)
  const result = await client.callTool({ name: "list_sessions", arguments: {} })
  expect(result.isError).not.toBe(true)
  expect(result.structuredContent).toHaveProperty("data.sessions")
})

test("a trusted editor reconnects after broker restart without another pairing code", async () => {
  const paired = await pair()
  expect(paired.token).toBeString()
  expect((await stat(path.join(directory, "editors.json"))).mode & 0o777).toBe(0o600)
  expect(await readFile(path.join(directory, "editors.json"), "utf8")).not.toContain(paired.token!)
  const oldToken = discovery.token
  broker.kill(); await broker.exited
  broker = Bun.spawn([process.execPath, path.join(root, "apps/mcp/src/broker.ts")], {
    env: { ...process.env, PELAGIK_AGENT_DIR: directory, PELAGIK_AGENT_PORT: String(port) }, stdout: "ignore", stderr: "inherit",
  })
  for (let i = 0; i < 100; i++) {
    discovery = JSON.parse(await readFile(path.join(directory, "broker.json"), "utf8"))
    if (discovery.token !== oldToken) break
    await Bun.sleep(20)
  }
  expect(discovery.token).not.toBe(oldToken)
  const socket = new WebSocket(`ws://127.0.0.1:${port}/bridge`, { headers: { Origin: "http://localhost:5173" } })
  sockets.push(socket)
  const newSession = await new Promise<string>((resolve, reject) => {
    socket.onopen = () => socket.send(JSON.stringify({ type: "hello", token: paired.token, status: { name: "Trusted", revision: "new:0", busy: false } }))
    socket.onerror = reject
    socket.onmessage = event => resolve(JSON.parse(String(event.data)).sessionId)
  })
  expect(newSession).toBeString()
  expect(newSession).not.toBe(paired.sessionId)
  expect((await request("/status")).sessions.some((s: any) => s.sessionId === newSession)).toBe(true)
})
