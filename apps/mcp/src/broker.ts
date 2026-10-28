import { mkdirSync, writeFileSync, chmodSync, readFileSync, renameSync, existsSync } from "node:fs"
import path from "node:path"
import { randomBytes, randomUUID, timingSafeEqual, createHash } from "node:crypto"
import { z } from "zod"
import { toolSchemas, errorResult, AgentError, type ToolName } from "@pelagik/agent-api/schema"
import { port, runtimeDir } from "./local"
import type { ServerWebSocket } from "bun"

const secret = randomBytes(32).toString("hex")
const trustedPath = path.join(runtimeDir, "editors.json")
const trusted = new Set<string>(existsSync(trustedPath) ? JSON.parse(readFileSync(trustedPath, "utf8")) : [])
const hash = (token: string) => createHash("sha256").update(token).digest("hex")
function rememberEditor() {
  if (trusted.size >= 256) throw new Error("Too many remembered editors")
  const token = randomBytes(32).toString("hex")
  trusted.add(hash(token))
  const temp = `${trustedPath}.${process.pid}.tmp`
  writeFileSync(temp, JSON.stringify([...trusted]), { mode: 0o600 })
  renameSync(temp, trustedPath)
  return token
}

const originAllowlist = new Set([
  "http://localhost:5173", "http://127.0.0.1:5173", "http://localhost:5174", "http://127.0.0.1:5174",
  "null", "file://", ...(process.env.PELAGIK_AGENT_ORIGINS?.split(",") ?? []),
])
const statusSchema = z.object({ name: z.string().max(200), revision: z.string().max(100), busy: z.boolean() }).strict()
type Status = z.infer<typeof statusSchema>
type SocketData = { sessionId?: string; timer?: ReturnType<typeof setTimeout> }
const sessions = new Map<string, { socket: ServerWebSocket<SocketData>; status: Status }>()
const pairing = new Map<string, number>()
const pending = new Map<string, { sessionId: string; resolve: (value: unknown) => void; timer: ReturnType<typeof setTimeout> }>()
function error(code: string, message: string) { return { error: { code, message } } }
function authenticated(request: Request) {
  const value = request.headers.get("authorization") ?? ""
  const expected = `Bearer ${secret}`
  const supplied = Buffer.from(value)
  const required = Buffer.from(expected)
  return supplied.length === required.length && timingSafeEqual(supplied, required)
}
function settle(id: string, value: unknown) {
  const request = pending.get(id)
  if (request) { clearTimeout(request.timer); pending.delete(id); request.resolve(value) }
}

const server = Bun.serve<SocketData>({
  hostname: "127.0.0.1", port, maxRequestBodySize: 1_048_576,
  async fetch(request, server) {
    const url = new URL(request.url)
    if (request.headers.get("host") !== `127.0.0.1:${port}`) return new Response("Invalid host", { status: 403 })
    const origin = request.headers.get("origin")
    if (url.pathname === "/bridge") {
      if (!origin || !originAllowlist.has(origin)) return new Response("Invalid origin", { status: 403 })
      if (sessions.size >= 32 || server.pendingWebSockets >= 64) return new Response("Too many editors", { status: 429 })
      return server.upgrade(request, { data: {} }) ? undefined : new Response("WebSocket required", { status: 400 })
    }
    // Only local authenticated processes use the control API. Browsers pair over the socket.
    if (origin || !authenticated(request)) return new Response("Unauthorized", { status: 403 })
    if (request.method === "GET" && url.pathname === "/status") {
      return Response.json({ protocolVersion: 2, sessions: [...sessions].map(([sessionId, { status }]) => ({ sessionId, ...status })) })
    }
    if (request.method !== "POST") return new Response("Not found", { status: 404 })
    try {
      if (url.pathname === "/pairing") {
        for (const [code, expires] of pairing) if (expires < Date.now()) pairing.delete(code)
        if (pairing.size >= 20) return new Response("Too many unused pairing codes", { status: 429 })
        const code = randomBytes(18).toString("base64url")
        const expiresAt = Date.now() + 120_000
        pairing.set(code, expiresAt)
        return Response.json({ code, expiresAt, url: `ws://127.0.0.1:${port}/bridge` })
      }
      if (url.pathname === "/call") {
        const input = z.object({ tool: z.enum(Object.keys(toolSchemas) as [ToolName, ...ToolName[]]), args: z.unknown(), clientId: z.string().uuid() }).strict().parse(await request.json())
        const args = toolSchemas[input.tool].parse(input.args)
        if (input.tool === "list_sessions") return Response.json({ sessions: [...sessions].map(([sessionId, { status }]) => ({ sessionId, ...status })) })
        if (!("sessionId" in args)) throw new AgentError("INVALID_REQUEST", "Session required")
        const session = sessions.get(args.sessionId)
        if (!session) return Response.json(error("EDITOR_UNAVAILABLE", "The paired editor is disconnected. Open Pelagik and wait for it to reconnect."))
        if (pending.size >= 64) return Response.json(error("SERVER_BUSY", "Too many pending calls"))
        const id = randomUUID()
        const result = new Promise(resolve => {
          const timer = setTimeout(() => settle(id, error("OUTCOME_UNKNOWN", "Editor did not respond within 30 seconds. Inspect the document before retrying a mutation.")), 30000)
          pending.set(id, { sessionId: args.sessionId, resolve, timer })
        })
        session.socket.send(JSON.stringify({ type: "call", id, tool: input.tool, args, clientId: input.clientId }))
        return Response.json(await result)
      }
      return new Response("Not found", { status: 404 })
    } catch (cause) { return Response.json({ error: errorResult(cause) }) }
  },
  websocket: {
    maxPayloadLength: 24 * 1024 * 1024,
    idleTimeout: 60,
    open(socket) {
      socket.data.timer = setTimeout(() => socket.close(1008, "Pairing timed out"), 5000)
    },
    message(socket, raw) {
      try {
        const message = JSON.parse(String(raw))
        if (!socket.data.sessionId) {
          const hello = z.object({ type: z.literal("hello"), code: z.string().max(100).optional(), token: z.string().max(100).optional(), remember: z.boolean().default(true), status: statusSchema }).strict().parse(message)
          let token: string | undefined
          if (hello.token && !hello.code) {
            if (!trusted.has(hash(hello.token))) { socket.close(1008, "Editor trust was revoked. Pair once to reconnect."); return }
          } else if (hello.code && !hello.token) {
            const expires = pairing.get(hello.code)
            if (!expires || expires < Date.now()) { socket.close(1008, "Invalid or expired pairing code"); return }
            pairing.delete(hello.code)
            if (hello.remember) token = rememberEditor()
          } else { socket.close(1008, "Editor credential required"); return }
          clearTimeout(socket.data.timer)
          const sessionId = randomUUID()
          socket.data.sessionId = sessionId
          sessions.set(sessionId, { socket, status: hello.status })
          socket.send(JSON.stringify({ type: "paired", sessionId, ...(token ? { token } : {}) }))
        } else if (message.type === "status") {
          const status = statusSchema.parse(message.status)
          sessions.get(socket.data.sessionId)!.status = status
        } else if (message.type === "result") {
          const request = pending.get(message.id)
          if (request?.sessionId === socket.data.sessionId) settle(message.id, message.result)
        } else if (message.type !== "ping") socket.close(1008, "Invalid message")
      } catch { socket.close(1008, "Invalid message") }
    },
    close(socket) {
      clearTimeout(socket.data.timer)
      const sessionId = socket.data.sessionId
      if (!sessionId) return
      sessions.delete(sessionId)
      for (const [id, request] of pending) if (request.sessionId === sessionId) settle(id, error("OUTCOME_UNKNOWN", "Editor disconnected. Inspect the document before retrying mutations."))
    },
  },
})
mkdirSync(runtimeDir, { recursive: true, mode: 0o700 })
chmodSync(runtimeDir, 0o700)
writeFileSync(path.join(runtimeDir, "broker.json"), JSON.stringify({ url: `http://127.0.0.1:${port}`, token: secret, pid: process.pid }), { mode: 0o600 })
chmodSync(path.join(runtimeDir, "broker.json"), 0o600)
process.on("SIGTERM", () => { server.stop(true); process.exit(0) })
