import { create } from "zustand"
import { errorResult, type ToolName } from "@pelagik/agent-api/schema"
import { createAgentService } from "./service"

export const useAgentConnection = create<{
  state: "disconnected" | "connecting" | "connected"; error: string | null; sessionId: string | null; lastActivity: string | null
}>(() => ({ state: "disconnected", error: null, sessionId: null, lastActivity: null }))
declare global {
  interface Window {
    pelagikAgents?: { credentials: () => Promise<{ code: string; url: string } | null> }
  }
}
const TRUST_KEY = "pelagik:agent-trust:v1"
const DISABLED_KEY = "pelagik:agents-disabled"
function storageGet(key: string) { try { return localStorage.getItem(key) } catch { return null } }
function storageSet(key: string, value?: string) { try { if (value === undefined) localStorage.removeItem(key); else localStorage.setItem(key, value) } catch { /* Browser storage may be disabled. */ } }
let socket: WebSocket | undefined
let dispose: (() => void) | undefined

function closeConnection() {
  const previous = socket
  socket = undefined
  dispose?.(); dispose = undefined
  previous?.close(1000, "Disconnected by user")
  useAgentConnection.setState({ state: "disconnected", sessionId: null, error: null })
}
export function disconnectAgent() {
  storageSet(DISABLED_KEY, "true")
  storageSet(TRUST_KEY)
  closeConnection()
}
export function resumeAutomaticAgentConnection() { storageSet(DISABLED_KEY) }
export function connectAgent(code: string, address: string, options: { token?: boolean; remember?: boolean } = {}) {
  closeConnection()
  storageSet(DISABLED_KEY)
  const url = new URL(address)
  if (url.protocol !== "ws:" || url.hostname !== "127.0.0.1" || url.pathname !== "/bridge" || url.username || url.password || url.search || url.hash) {
    throw new Error("Broker address must be ws://127.0.0.1:PORT/bridge")
  }
  if (!code.trim()) throw new Error("Enter a pairing code")
  const ws = new WebSocket(url)
  const service = createAgentService()
  socket = ws
  useAgentConnection.setState({ state: "connecting", error: null, lastActivity: null })
  let queue = Promise.resolve()
  let lastStatus = ""
  const timeout = setTimeout(() => { if (useAgentConnection.getState().state === "connecting") ws.close(1000, "Pairing timed out") }, 8000)
  const heartbeat = setInterval(() => {
    if (ws.readyState !== WebSocket.OPEN || !useAgentConnection.getState().sessionId) return
    const status = service.status()
    const serialized = JSON.stringify(status)
    if (serialized !== lastStatus) { ws.send(JSON.stringify({ type: "status", status })); lastStatus = serialized }
    else ws.send(JSON.stringify({ type: "ping" }))
  }, 1000)
  dispose = () => { clearTimeout(timeout); clearInterval(heartbeat); service.dispose() }
  ws.onopen = () => ws.send(JSON.stringify({ type: "hello", ...(options.token ? { token: code.trim() } : { code: code.trim() }), remember: options.remember ?? true, status: service.status() }))
  ws.onmessage = event => {
    if (socket !== ws) return
    try {
      const message = JSON.parse(event.data)
      if (message.type === "paired") {
        clearTimeout(timeout)
        if (message.token) storageSet(TRUST_KEY, JSON.stringify({ token: message.token, address }))
        useAgentConnection.setState({ state: "connected", sessionId: message.sessionId })
      } else if (message.type === "call") {
        queue = queue.then(async () => {
          if (socket !== ws || ws.readyState !== WebSocket.OPEN) return
          let result: unknown
          try {
            if (message.args?.sessionId !== useAgentConnection.getState().sessionId) throw new Error("Wrong editor session")
            result = await service.call(message.tool as ToolName, message.args, message.clientId)
            useAgentConnection.setState({ lastActivity: `${message.tool} · ${new Date().toLocaleTimeString()}` })
          } catch (cause) { result = { error: errorResult(cause) } }
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: "result", id: message.id, result }))
            ws.send(JSON.stringify({ type: "status", status: service.status() }))
          }
        }).catch(() => ws.close(1011, "Editor connection failed"))
      }
    } catch { ws.close(1008, "Invalid broker message") }
  }
  ws.onerror = () => {
    if (socket === ws) useAgentConnection.setState({ error: "Cannot reach the local broker. Run bun run agent:setup once. Reconnecting automatically." })
  }
  ws.onclose = event => {
    if (socket !== ws) return
    if (event.code === 1008 && options.token) storageSet(TRUST_KEY)
    const reason = event.reason || "Broker connection closed. Reconnecting automatically."
    dispose?.(); dispose = undefined; socket = undefined
    useAgentConnection.setState({ state: "disconnected", sessionId: null, error: reason })
  }
}

/** Desktop credentials come from the local setup; browsers remember their first pairing. */
export function startAgentAutoConnect() {
  let stopped = false
  let checking = false
  const check = async () => {
    if (stopped || checking || socket || storageGet(DISABLED_KEY)) return
    checking = true
    try {
      if (window.pelagikAgents) {
        const credentials = await window.pelagikAgents.credentials()
        if (!stopped && !socket && !storageGet(DISABLED_KEY) && credentials) connectAgent(credentials.code, credentials.url, { remember: false })
      }
      if (!socket && !stopped && !storageGet(DISABLED_KEY)) {
        const saved = storageGet(TRUST_KEY)
        if (saved) {
          const trust = JSON.parse(saved)
          connectAgent(trust.token, trust.address, { token: true })
        }
      }
    } catch (error) {
      if (!stopped) useAgentConnection.setState({ error: error instanceof Error ? error.message : "Automatic connection failed" })
    } finally { checking = false }
  }
  void check()
  const timer = setInterval(() => { void check() }, 3000)
  return () => { stopped = true; clearInterval(timer); closeConnection() }
}
