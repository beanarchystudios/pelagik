import { spawn } from "node:child_process"
import { createServer } from "node:net"
import electron from "electron"

const cwd = new URL("../", import.meta.url)
const url = "http://127.0.0.1:5174"
// Refuse an occupied port rather than accidentally loading a different app.
await new Promise((resolve, reject) => {
  const probe = createServer()
  probe.once("error", reject)
  probe.listen(5174, "127.0.0.1", () => probe.close(resolve))
})

const server = spawn("bun", ["run", "--cwd", "../web", "dev", "--host", "127.0.0.1", "--port", "5174", "--strictPort"], {
  cwd, stdio: "inherit",
})
let desktop
let stopping = false
function stop(code = 0) {
  if (stopping) return
  stopping = true
  desktop?.kill()
  server.kill()
  process.exitCode = code
}
process.on("SIGINT", () => stop())
process.on("SIGTERM", () => stop())
server.on("error", (error) => { console.error(error); stop(1) })
server.on("exit", (code) => stop(code ?? 1))

try {
  const deadline = Date.now() + 30_000
  while (!stopping) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(1000) })
      if (response.ok) break
    } catch { /* Vite has not started yet. */ }
    if (Date.now() > deadline) throw new Error("Desktop development server did not start within 30 seconds")
    await new Promise((resolve) => setTimeout(resolve, 200))
  }
  if (!stopping) {
    desktop = spawn(electron, ["."], { cwd, stdio: "inherit", env: { ...process.env, PELAGIK_DEV_URL: url } })
    desktop.on("error", (error) => { console.error(error); stop(1) })
    desktop.on("exit", (code) => stop(code ?? 1))
  }
} catch (error) {
  console.error(error)
  stop(1)
}
