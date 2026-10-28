import { expect, test } from "bun:test"
import { mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import { mergeClientConfig, serverConfig } from "../src/setup"

test("client setup preserves other settings, backs up existing config, and is repeatable", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "pelagik-setup-test-"))
  const file = path.join(dir, "mcp.json")
  try {
    const original = { other: true, mcpServers: { existing: { command: "existing" } } }
    await writeFile(file, JSON.stringify(original))
    await mergeClientConfig(file)
    const first = await readFile(file, "utf8")
    expect(JSON.parse(first)).toEqual({ ...original, mcpServers: { ...original.mcpServers, pelagik: serverConfig } })
    expect(JSON.parse(await readFile(file + ".pelagik-backup", "utf8"))).toEqual(original)
    expect((await stat(file)).mode & 0o777).toBe(0o600)
    expect((await stat(file + ".pelagik-backup")).mode & 0o777).toBe(0o600)
    await mergeClientConfig(file)
    expect(await readFile(file, "utf8")).toBe(first)
    await writeFile(file, "broken json")
    await expect(mergeClientConfig(file)).rejects.toThrow()
    expect(await readFile(file, "utf8")).toBe("broken json")
  } finally { await rm(dir, { recursive: true, force: true }) }
})

test("installed runtime starts its broker outside the checkout without repository dependencies", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "pelagik-installed-test-"))
  const probe = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch: () => new Response() })
  const port = probe.port!
  probe.stop(true)
  let pid: number | undefined
  try {
    const runtime = path.join(dir, "runtime")
    const build = await Bun.build({ entrypoints: ["broker", "cli", "server"].map(name => path.resolve(import.meta.dir, `../src/${name}.ts`)), target: "bun", outdir: runtime, naming: "[name].js" })
    expect(build.success).toBe(true)
    const child = Bun.spawn([process.execPath, path.join(runtime, "cli.js"), "status"], {
      cwd: tmpdir(), env: { ...process.env, PELAGIK_AGENT_DIR: dir, PELAGIK_AGENT_PORT: String(port) }, stdout: "pipe", stderr: "pipe",
    })
    const [code, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()])
    expect(stderr).toBe("")
    expect(code).toBe(0)
    expect(JSON.parse(stdout)).toEqual({ protocolVersion: 2, sessions: [] })
    const discovery = JSON.parse(await readFile(path.join(dir, "broker.json"), "utf8"))
    pid = discovery.pid
    expect((await stat(path.join(dir, "broker.json"))).mode & 0o777).toBe(0o600)
  } finally {
    if (pid) { try { process.kill(pid, "SIGTERM") } catch {} }
    await rm(dir, { recursive: true, force: true })
  }
})
