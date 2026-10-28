import { chmod, mkdir, readFile } from "node:fs/promises"
import { homedir } from "node:os"
import path from "node:path"
import { spawn } from "node:child_process"
import { fileURLToPath } from "node:url"

export const runtimeDir = process.env.PELAGIK_AGENT_DIR ?? path.join(process.env.XDG_STATE_HOME ?? path.join(homedir(), ".local/state"), "pelagik/agent")
export const port = Number(process.env.PELAGIK_AGENT_PORT ?? 48765)
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error("Invalid PELAGIK_AGENT_PORT")
export interface Discovery { url: string; token: string; pid: number }
export async function readDiscovery(): Promise<Discovery> {
  const data = JSON.parse(await readFile(path.join(runtimeDir, "broker.json"), "utf8")) as Discovery
  if (data.url !== `http://127.0.0.1:${port}` || typeof data.token !== "string") throw new Error("Invalid broker discovery file")
  return data
}
export async function brokerRequest(discovery: Discovery, route: string, body?: unknown, timeout = 35000): Promise<any> {
  const response = await fetch(discovery.url + route, {
    method: body === undefined ? "GET" : "POST",
    headers: { authorization: `Bearer ${discovery.token}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(timeout),
  })
  if (!response.ok) throw new Error(`Local broker request failed: HTTP ${response.status}`)
  return response.json()
}
export async function ensureBroker(): Promise<Discovery> {
  try {
    const discovery = await readDiscovery()
    const status = await brokerRequest(discovery, "/status", undefined, 1000)
    if (status.protocolVersion === 2) return discovery
    // Replace an older authenticated Pelagik broker after a repo upgrade.
    process.kill(discovery.pid, "SIGTERM")
  } catch { /* Start a broker if no authenticated broker is reachable. */ }
  await mkdir(runtimeDir, { recursive: true, mode: 0o700 })
  await chmod(runtimeDir, 0o700)
  const child = spawn(process.execPath, [fileURLToPath(new URL(import.meta.url.endsWith(".ts") ? "./broker.ts" : "./broker.js", import.meta.url))], {
    detached: true, stdio: "ignore", env: process.env,
  })
  let spawnError: Error | undefined
  child.on("error", error => { spawnError = error })
  child.unref()
  for (let attempt = 0; attempt < 50; attempt++) {
    if (spawnError) throw spawnError
    await new Promise(resolve => setTimeout(resolve, 100))
    try {
      const discovery = await readDiscovery()
      const status = await brokerRequest(discovery, "/status", undefined, 1000)
      if (status.protocolVersion === 2) return discovery
    } catch { /* Another client may be starting the same broker. */ }
  }
  throw new Error(`Cannot start Pelagik broker on port ${port}. Check for a conflicting process or set PELAGIK_AGENT_PORT.`)
}
