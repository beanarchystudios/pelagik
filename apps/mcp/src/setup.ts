import { access, copyFile, mkdir, readFile, rename, writeFile, chmod } from "node:fs/promises"
import { homedir } from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { runtimeDir, port } from "./local"

export const root = fileURLToPath(new URL("../../../", import.meta.url))
const installedDir = path.join(runtimeDir, "runtime")
export const cliPath = path.join(installedDir, "cli.js")
export const serverConfig = {
  command: process.execPath, args: [path.join(installedDir, "server.js")],
  env: { PELAGIK_AGENT_DIR: runtimeDir, PELAGIK_AGENT_PORT: String(port), ...(process.env.PELAGIK_AGENT_ORIGINS ? { PELAGIK_AGENT_ORIGINS: process.env.PELAGIK_AGENT_ORIGINS } : {}) },
}
export const setupPath = path.join(runtimeDir, "setup.json")

async function exists(file: string) { try { await access(file); return true } catch { return false } }
export async function writePrivate(file: string, value: unknown) {
  await mkdir(path.dirname(file), { recursive: true, mode: 0o700 })
  const temp = `${file}.${process.pid}.tmp`
  await writeFile(temp, JSON.stringify(value, null, 2) + "\n", { mode: 0o600 })
  await chmod(temp, 0o600)
  await rename(temp, file)
}
export async function mergeClientConfig(file: string) {
  const present = await exists(file)
  const data = present ? JSON.parse(await readFile(file, "utf8")) : {}
  if (!data || typeof data !== "object" || Array.isArray(data) || (data.mcpServers && (typeof data.mcpServers !== "object" || Array.isArray(data.mcpServers)))) throw new Error(`Invalid MCP configuration: ${file}`)
  if (JSON.stringify(data.mcpServers?.pelagik) === JSON.stringify(serverConfig)) return
  if (present) { await copyFile(file, `${file}.pelagik-backup`); await chmod(`${file}.pelagik-backup`, 0o600) }
  await writePrivate(file, { ...data, mcpServers: { ...data.mcpServers, pelagik: serverConfig } })
}
export async function setupAgents(dryRun = false) {
  if (!dryRun) {
    await mkdir(installedDir, { recursive: true, mode: 0o700 })
    if (import.meta.url.endsWith(".ts")) {
      const build = await Bun.build({
        entrypoints: ["server", "broker", "cli"].map(name => path.join(root, `apps/mcp/src/${name}.ts`)),
        target: "bun", outdir: installedDir, naming: "[name].js",
      })
      if (!build.success) throw new Error(`Cannot install agent runtime: ${build.logs.join("\n")}`)
    } else {
      const sourceDir = path.dirname(fileURLToPath(import.meta.url))
      if (sourceDir !== installedDir) {
        await Promise.all(["server", "broker", "cli"].map(name => copyFile(path.join(sourceDir, `${name}.js`), path.join(installedDir, `${name}.js`))))
      }
    }
  }
  const home = homedir()
  const clients = [
    { name: "Codex", installed: !!Bun.which("codex") || await exists(path.join(home, ".codex")) },
    { name: "Claude Code", installed: !!Bun.which("claude") || await exists(path.join(home, ".claude")) || await exists(path.join(home, ".claude.json")) },
    { name: "Cursor", installed: !!Bun.which("cursor") || await exists(path.join(home, ".cursor")) },
  ]
  const results: string[] = []
  for (const client of clients.filter(c => c.installed)) {
    if (dryRun) { results.push(`Detected ${client.name}`); continue }
    try {
      if (client.name === "Codex") {
        const executable = Bun.which("codex")
        if (!executable) throw new Error("Codex config exists, but its CLI is unavailable on PATH")
        const config = path.join(process.env.CODEX_HOME ?? path.join(home, ".codex"), "config.toml")
        if (await exists(config)) { await copyFile(config, `${config}.pelagik-backup`); await chmod(`${config}.pelagik-backup`, 0o600) }
        const child = Bun.spawn([executable, "mcp", "add", "pelagik", ...Object.entries(serverConfig.env).flatMap(([key, value]) => ["--env", `${key}=${value}`]), "--", serverConfig.command, ...serverConfig.args], { stdout: "pipe", stderr: "pipe" })
        const [code, stderr] = await Promise.all([child.exited, new Response(child.stderr).text(), new Response(child.stdout).text()])
        if (code !== 0) throw new Error(stderr || `Codex exited ${code}`)
      } else {
        const file = client.name === "Cursor" ? path.join(home, ".cursor/mcp.json") : path.join(process.env.CLAUDE_CONFIG_DIR ?? home, ".claude.json")
        await mergeClientConfig(file)
      }
      results.push(`Configured ${client.name}`)
    } catch (error) { results.push(`Failed ${client.name}: ${error instanceof Error ? error.message : error}`) }
  }
  if (!dryRun) await writePrivate(setupPath, { version: 1, bun: process.execPath, cli: cliPath, port: Number(process.env.PELAGIK_AGENT_PORT ?? 48765) })
  return results
}
