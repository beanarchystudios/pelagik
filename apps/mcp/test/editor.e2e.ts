import assert from "node:assert/strict"
import { spawn } from "node:child_process"
import { createRequire } from "node:module"
import { createInterface } from "node:readline"
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { Client } from "@modelcontextprotocol/client"
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio"

const automatic = process.env.PELAGIK_TEST_AUTO === "1"
const root = fileURLToPath(new URL("../../../", import.meta.url))
const directory = await mkdtemp(path.join(tmpdir(), "pelagik-editor-e2e-"))
const probe = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch: () => new Response() })
const port = probe.port!
probe.stop(true)
const env = Object.fromEntries(Object.entries({ ...process.env, PELAGIK_AGENT_DIR: directory, PELAGIK_AGENT_PORT: String(port) }).filter((entry): entry is [string, string] => typeof entry[1] === "string"))
const client = new Client({ name: "pelagik-editor-e2e", version: "1.0.0" }, { versionNegotiation: { mode: { pin: "2026-07-28" } } })
const second = new Client({ name: "pelagik-second-agent", version: "1.0.0" })
const transport = () => new StdioClientTransport({ command: process.execPath, args: [path.join(root, "apps/mcp/src/server.ts")], env })
let electron: ReturnType<typeof spawn> | undefined
let discovery: { url: string; token: string; pid: number } | undefined
let nextId = 0
const pending = new Map<number, { resolve: (value: any) => void; reject: (error: unknown) => void; timer: ReturnType<typeof setTimeout> }>()
async function command(message: Record<string, unknown>): Promise<any> {
  const id = ++nextId
  const result = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error("Electron test command timed out")) }, 15000)
    pending.set(id, { resolve, reject, timer })
  })
  electron!.stdin!.write(JSON.stringify({ id, ...message }) + "\n")
  return result
}
const evaluate = (js: string) => command({ js })
async function tool(name: string, args: Record<string, unknown>, useClient = client) {
  const result = await useClient.callTool({ name, arguments: args })
  if (result.isError) throw new Error(JSON.stringify(result.content))
  return (result.structuredContent as { data: any }).data
}
try {
  await client.connect(transport())
  await second.connect(transport())
  discovery = JSON.parse(await readFile(path.join(directory, "broker.json"), "utf8"))
  assert.equal((await client.listTools()).tools.length, 8)
  const pairing = await (await fetch(discovery!.url + "/pairing", { method: "POST", headers: { authorization: `Bearer ${discovery!.token}` } })).json() as any
  if (automatic) await writeFile(path.join(directory, "setup.json"), JSON.stringify({ version: 1, bun: process.execPath, cli: path.join(root, "apps/mcp/src/cli.ts"), port }), { mode: 0o600 })
  const executable = createRequire(path.join(root, "apps/desktop/package.json"))("electron") as string
  const electronEnv: NodeJS.ProcessEnv = { ...process.env, PELAGIK_AGENT_DIR: directory, PELAGIK_AGENT_PORT: String(port), PELAGIK_TEST_PROFILE: path.join(directory, "profile"), PELAGIK_TEST_MAIN: path.join(root, "apps/desktop/dist/main.js"), PELAGIK_TEST_HEADLESS: "1" }
  delete electronEnv.ELECTRON_RUN_AS_NODE
  electron = spawn(executable, [path.join(root, "apps/mcp/test/electron-harness.cjs")], { env: electronEnv, stdio: ["pipe", "pipe", "inherit"] })
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Electron did not load")), 15000)
    electron!.once("error", reject)
    electron!.once("exit", code => { if (code) reject(new Error(`Electron exited ${code}`)) })
    createInterface({ input: electron!.stdout! }).on("line", line => {
      if (!line.startsWith("PELAGIK_E2E ")) return
      const message = JSON.parse(line.slice(12))
      if (message.ready) { clearTimeout(timer); resolve() }
      if (message.fatal) reject(new Error(JSON.stringify(message.fatal)))
      const request = pending.get(message.id)
      if (request) {
        pending.delete(message.id); clearTimeout(request.timer)
        if (message.error) request.reject(new Error(message.error)); else request.resolve(message.result)
      }
    })
  })
  if (automatic) await evaluate(`(async () => {
    for (let i = 0; i < 100; i++) {
      if (document.querySelector('[aria-label="Agents"]')?.dataset.connection === 'connected') return true;
      await new Promise(r => setTimeout(r, 100));
    }
    throw new Error('Automatic desktop connection failed');
  })()`)
  else await evaluate(`(async () => {
    document.querySelector('[aria-label="Agents"]').click();
    await new Promise(r => setTimeout(r, 100));
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    const address = document.querySelector('[aria-label="Broker address"]');
    const code = document.querySelector('[aria-label="Pairing code"]');
    setter.call(address, ${JSON.stringify(pairing.url)}); address.dispatchEvent(new Event('input', { bubbles: true }));
    setter.call(code, ${JSON.stringify(pairing.code)}); code.dispatchEvent(new Event('input', { bubbles: true }));
    await new Promise(r => setTimeout(r, 100));
    document.querySelector('button[type="submit"]').click();
    for (let i = 0; i < 50; i++) {
      await new Promise(r => setTimeout(r, 100));
      if (document.querySelector('[aria-label="Agents"]')?.dataset.connection === 'connected') return true;
    }
    throw new Error('Pairing failed: ' + document.body.innerText);
  })()`)
  const sessions = await tool("list_sessions", {})
  assert.equal(sessions.sessions.length, 1)
  const sessionId = sessions.sessions[0].sessionId
  const initial = await tool("get_document", { sessionId })
  assert.equal(initial.nodeCount, 0)
  assert.equal(initial.format, "pelagik/json-render")
  const batch = {
    sessionId, expectedRevision: initial.revision, requestId: crypto.randomUUID(), operations: [
      { op: "create_variable", ref: "brand", name: "Brand", value: "#0088cc" },
      { op: "create", type: "frame", ref: "frame", props: { x: 20, y: 30, width: 400, height: 300, fill: "#ffffff", flex: { direction: "vertical", gap: 16, padding: 24, mainAlign: "start", crossAlign: "start" } } },
      { op: "create", type: "text", ref: "title", parentId: "$frame", props: { text: "Pelagik MCP", width: 300, fontSize: 28, fontWeight: 700 } },
      { op: "create", type: "rectangle", ref: "button", parentId: "$frame", props: { width: 180, height: 48, radius: 8 } },
      { op: "bind_variable", ids: ["$button"], property: "fill", variableId: "$brand" },
    ],
  }
  const edited = await tool("apply_edits", batch)
  assert.equal(edited.createdIds.length, 3)
  assert.equal(edited.persistenceStatus, "saved")
  const savedDesign = await evaluate("JSON.parse(localStorage.getItem('d3sign:file:v1'))")
  assert.equal(savedDesign.format, "pelagik/json-render")
  assert.equal(savedDesign.doc, undefined)
  assert.equal(savedDesign.spec.nodes[edited.refs.title].props.text, "Pelagik MCP")
  assert.deepEqual(await tool("apply_edits", batch), edited)
  const settled = await tool("get_document", { sessionId })
  assert.equal(settled.nodeCount, 3)
  assert.equal(Object.values(settled.spec.variables as Record<string, { name: string }>)[0].name, "Brand")
  const nodes = await tool("query_nodes", { sessionId, ids: [edited.refs.title, edited.refs.button] })
  assert.equal(nodes.nodes.length, 2)
  assert.equal(nodes.nodes.find((n: any) => n.id === edited.refs.button).fill, "#0088cc")
  const rendered = await client.callTool({ name: "render", arguments: { sessionId, ids: [edited.refs.frame] } })
  assert.ok(!rendered.isError, JSON.stringify(rendered.content))
  const image = rendered.content!.find((item: any) => item.type === "image") as { data: string }
  assert.ok(image)
  const png = Buffer.from(image.data, "base64")
  assert.equal(png.subarray(1, 4).toString(), "PNG")
  assert.equal(png.readUInt32BE(16), 400)
  assert.equal(png.readUInt32BE(20), 300)
  const pngFile = path.join(directory, "render.png")
  await Bun.write(pngFile, png)
  // Decode in Chromium and verify a real colored button pixel, not just a valid PNG header.
  const pixel = await evaluate(`(async () => {
    const image = new Image(); image.src = ${JSON.stringify("data:image/png;base64," + image.data)}; await image.decode();
    const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
    return [...context.getImageData(40, ${Math.round(nodes.nodes.find((n: any) => n.id === edited.refs.button).y + 20)}, 1, 1).data];
  })()`)
  assert.deepEqual(pixel, [0, 136, 204, 255])
  const before = await tool("get_document", { sessionId })
  await tool("apply_edits", { sessionId, expectedRevision: before.revision, requestId: crypto.randomUUID(), operations: [{ op: "update", ids: [edited.refs.title], props: { text: "Refined heading" } }] })
  const stale = await second.callTool({ name: "apply_edits", arguments: { sessionId, expectedRevision: before.revision, requestId: crypto.randomUUID(), operations: [{ op: "delete", ids: [edited.refs.frame] }] } })
  assert.equal(stale.isError, true)
  assert.match(JSON.stringify(stale.content), /REVISION_CONFLICT/)
  const current = await tool("get_document", { sessionId })
  const invalid = await client.callTool({ name: "apply_edits", arguments: { sessionId, expectedRevision: current.revision, requestId: crypto.randomUUID(), operations: [
    { op: "update", ids: [edited.refs.title], props: { text: "Must roll back" } },
    { op: "reparent", ids: [edited.refs.frame], parentId: edited.refs.frame },
  ] } })
  assert.equal(invalid.isError, true)
  assert.equal((await tool("query_nodes", { sessionId, ids: [edited.refs.title] })).nodes[0].text, "Refined heading")
  await tool("focus_nodes", { sessionId, ids: [edited.refs.frame] })
  assert.deepEqual((await tool("get_selection", { sessionId })).ids, [edited.refs.frame])
  await command({ action: "undo" })
  await Bun.sleep(100)
  assert.equal((await tool("query_nodes", { sessionId, ids: [edited.refs.title] })).nodes[0].text, "Pelagik MCP")
  await command({ action: "undo" })
  await Bun.sleep(100)
  assert.equal((await tool("get_document", { sessionId })).nodeCount, 0)
  await command({ action: "redo" })
  await Bun.sleep(100)
  assert.equal((await tool("get_document", { sessionId })).nodeCount, 3)
  const changes = await tool("get_changes", { sessionId, sinceRevision: initial.revision })
  assert.ok(changes.changes.length >= 5)
  // A live gesture blocks edits even when the expected revision is current.
  await evaluate("window.dispatchEvent(new PointerEvent('pointerdown'))")
  const busy = await client.callTool({ name: "apply_edits", arguments: { sessionId, expectedRevision: changes.revision, requestId: crypto.randomUUID(), operations: [{ op: "delete", ids: [edited.refs.frame] }] } })
  assert.equal(busy.isError, true)
  assert.match(JSON.stringify(busy.content), /EDITOR_BUSY/)
  await evaluate("window.dispatchEvent(new PointerEvent('pointerup'))")
  const catalogResource = await client.readResource({ uri: "pelagik://catalog" })
  const catalog = JSON.parse((catalogResource.contents[0] as { text: string }).text)
  assert.equal(catalog.library, "@json-render/core")
  assert.ok(catalog.components.includes("frame"))
  const jsonDesign = {
    rootIds: ["card"], variables: { accent: { name: "JSON accent", value: "#8844ff" } },
    nodes: {
      card: { type: "frame", props: { x: 600, y: 400, width: 280, height: 180, fill: "#ffffff" }, childIds: ["label"] },
      label: { type: "text", props: { x: 20, y: 20, width: 240, text: "Generated with json-render", fontSize: 20 }, childIds: [], bindings: { fill: "accent" } },
    },
  }
  const beforeSpec = await tool("get_document", { sessionId })
  const imported = await tool("apply_edits", { sessionId, expectedRevision: beforeSpec.revision, requestId: crypto.randomUUID(), operations: [{ op: "insert_spec", spec: jsonDesign, ref: "jsonCard" }] })
  assert.equal(imported.imports.length, 1)
  const exported = await tool("get_document", { sessionId, subtreeId: imported.refs.jsonCard, format: "json-render" })
  assert.equal(exported.format, "pelagik/json-render")
  assert.equal(exported.spec.nodes[imported.imports[0].ids.label].props.text, "Generated with json-render")
  assert.equal(exported.spec.nodes[imported.imports[0].ids.label].props.fill, "#8844ff")
  await tool("focus_nodes", { sessionId, ids: [imported.refs.jsonCard] })
  // Some builds omit the optional Design JSON dialog from the toolbar.
  if (await evaluate("[...document.querySelectorAll('button')].some(b => b.textContent === 'Design JSON')")) {
    const dialogSpec = await evaluate(`(async () => {
      [...document.querySelectorAll('button')].find(b => b.textContent === 'Design JSON').click();
      await new Promise(r => setTimeout(r, 100));
      return JSON.parse(document.querySelector('[aria-label="json-render design spec"]').value);
    })()`)
    assert.equal(dialogSpec.rootIds.length, 1)
    assert.equal(dialogSpec.nodes[imported.refs.jsonCard].type, "frame")
    // Import the exported JSON through the human-facing dialog and verify it becomes independent editable layers.
    await evaluate(`document.querySelectorAll('[role="dialog"] button'); [...document.querySelectorAll('button')].find(b => b.textContent === 'Insert as layers').click(); true`)
    await Bun.sleep(150)
    const copies = await tool("query_nodes", { sessionId, text: "Generated with json-render", type: "text" })
    assert.equal(copies.nodes.length, 2)
    await command({ action: "undo" }); await Bun.sleep(100)
    assert.equal((await tool("query_nodes", { sessionId, text: "Generated with json-render", type: "text" })).nodes.length, 1)
  }
  const beforeInvalidSpec = await tool("get_document", { sessionId })
  const invalidSpec = await client.callTool({ name: "apply_edits", arguments: { sessionId, expectedRevision: beforeInvalidSpec.revision, requestId: crypto.randomUUID(), operations: [{ op: "insert_spec", spec: { rootIds: ["cycle"], nodes: { cycle: { type: "frame", props: {}, childIds: ["cycle"] } } } }] } })
  assert.equal(invalidSpec.isError, true)
  assert.equal((await tool("get_document", { sessionId })).nodeCount, beforeInvalidSpec.nodeCount)
  const fixtureBase = await tool("get_document", { sessionId })
  const fixture = await tool("apply_edits", {
    sessionId, expectedRevision: fixtureBase.revision, requestId: crypto.randomUUID(), operations: [
      { op: "create", type: "frame", ref: "root", props: { x: 1000, y: 1000, width: 300, height: 300, fill: "#ffffff" } },
      { op: "create", type: "frame", ref: "clip", parentId: "$root", props: { x: 100, y: 100, width: 100, height: 100, rotation: 90, fill: "#ffffff" } },
      { op: "create", type: "rectangle", parentId: "$clip", props: { x: 70, y: 20, width: 80, height: 40, fill: "#ff0000", opacity: 0.5 } },
      { op: "create", type: "ellipse", ref: "shader", parentId: "$root", props: { x: 20, y: 20, width: 40, height: 40, fill: "#00ff00", shader: "water" } },
      { op: "create", type: "rectangle", ref: "penShader", parentId: "$root", props: { x: 210, y: 210, width: 64, height: 64, radius: 14, fill: "#d7e6f3", shader: "pen-liquid-glass-g5DdN" } },
    ],
  })
  await tool("get_document", { sessionId })
  assert.equal((await tool("query_nodes", { sessionId, ids: [fixture.refs.shader] })).nodes[0].shader, "water")
  assert.equal((await tool("query_nodes", { sessionId, ids: [fixture.refs.penShader] })).nodes[0].shader, "pen-liquid-glass-g5DdN")
  const shaderImages = await evaluate(`document.querySelectorAll('img[src^="data:image/png;base64,"]').length`)
  assert.ok(shaderImages > 1, "Built-in and Pen GLSL shaders should render to PNG previews")
  const penShaderImage = await evaluate(`document.querySelector('[data-node-id="${fixture.refs.penShader}"] img')?.getAttribute('src') ?? ''`)
  assert.ok(penShaderImage.startsWith("data:image/png;base64,"), `Pen GLSL should render from its bundled source, got ${penShaderImage.slice(0, 80)}`)
  await evaluate(`document.querySelector('button[aria-label="Shaders"]').click(); true`)
  await Bun.sleep(100)
  const shaderLibrary = await evaluate(`(async () => {
    const buttons = [...document.querySelectorAll('[role="dialog"] button[aria-label$="shader"]')];
    await Promise.all(buttons.map(button => button.querySelector('img')?.decode().catch(() => {})));
    return { title: document.querySelector('[role="dialog"] [data-slot="dialog-title"]')?.textContent, cards: buttons.length, renderedPreviews: buttons.filter(button => { const image = button.querySelector('img'); return image?.complete && image.naturalWidth > 0 }).length, families: document.querySelectorAll('[role="dialog"] [data-shader-family]').length, variants: document.querySelectorAll('[role="dialog"] [data-shader-variant]').length, penShaders: ['ASCII Echo', 'Aurō Bevel', 'Aurō Flow', 'Aurora', 'Liquid Glass'].map(name => buttons.some(button => button.getAttribute('aria-label') === 'Apply ' + name + ' shader')) };
  })()`)
  assert.deepEqual(shaderLibrary, { title: "Shaders", cards: 79, renderedPreviews: 79, families: 75, variants: 0, penShaders: [true, true, true, true, true] })
  await evaluate(`document.querySelector('button[aria-label="Show ASCII Echo variants"]').click(); true`)
  const asciiVariants = await evaluate(`document.querySelectorAll('[data-shader-family="ascii-echo"] [data-shader-variant]').length`)
  assert.equal(asciiVariants, 5, "Each Pen shader family should expose all five variants")
  await evaluate(`document.querySelector('[role="dialog"] [data-slot="dialog-close"]').click(); true`)
  const fixtureRender = await client.callTool({ name: "render", arguments: { sessionId, ids: [fixture.refs.root], scale: 1 } })
  assert.ok(!fixtureRender.isError, JSON.stringify(fixtureRender.content))
  const fixtureImage = fixtureRender.content!.find((item: any) => item.type === "image") as { data: string }
  const fixturePixels = await evaluate(`(async () => {
    const image = new Image(); image.src = ${JSON.stringify("data:image/png;base64," + fixtureImage.data)}; await image.decode();
    const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
    return [[160,180], [160,220], [40,40], [21,21]].map(([x,y]) => [...context.getImageData(x,y,1,1).data]);
  })()`)
  assert.deepEqual(fixturePixels.slice(0, 2), [[255,127,127,255], [255,255,255,255]])
  assert.ok(fixturePixels[2][2] > 0, `water shader should add blue light: ${JSON.stringify(fixturePixels[2])}`)
  assert.deepEqual(fixturePixels[3], [255,255,255,255])
  const scaled = await client.callTool({ name: "render", arguments: { sessionId, ids: [fixture.refs.root], scale: 0.333 } })
  assert.ok(!scaled.isError, JSON.stringify(scaled.content))
  const scaledImage = scaled.content!.find((item: any) => item.type === "image") as { data: string }
  const scaledPng = Buffer.from(scaledImage.data, "base64")
  assert.equal(scaledPng.readUInt32BE(16), 100)
  assert.equal((scaled.structuredContent as any).data.width, 100)
  // A reload gets a new session, reconnects automatically, and preserves the saved design.
  await command({ action: "reload" })
  await Bun.sleep(500)
  const closed = await client.callTool({ name: "get_document", arguments: { sessionId } })
  assert.equal(closed.isError, true)
  assert.match(JSON.stringify(closed.content), /EDITOR_UNAVAILABLE/)
  if (automatic) {
    let reconnected: any
    for (let i = 0; i < 100; i++) {
      const sessions = await tool("list_sessions", {})
      reconnected = sessions.sessions.find((s: any) => s.sessionId !== sessionId)
      if (reconnected) break
      await Bun.sleep(100)
    }
    assert.ok(reconnected, "Desktop reconnects after reload without a pairing code")
    const restored = await tool("get_document", { sessionId: reconnected.sessionId })
    assert.ok(restored.spec.nodes[fixture.refs.root], "Saved designs survive automatic reconnection")
    assert.equal(restored.spec.nodes[fixture.refs.shader].props.shader, "water", "Shader presets survive save and reload")
    // Existing MCP clients recover when the broker itself restarts.
    process.kill(discovery!.pid, "SIGTERM")
    await Bun.sleep(200)
    let recovered: any
    for (let i = 0; i < 100; i++) {
      const sessions = await tool("list_sessions", {})
      recovered = sessions.sessions.find((s: any) => s.sessionId !== reconnected.sessionId)
      if (recovered) break
      await Bun.sleep(100)
    }
    assert.ok(recovered, "Desktop and MCP recover after broker restart")
    discovery = JSON.parse(await readFile(path.join(directory, "broker.json"), "utf8"))
    assert.ok((await tool("get_document", { sessionId: recovered.sessionId })).spec.nodes[fixture.refs.root])
  }
  console.log("Editor MCP E2E passed: pairing, 8 tools, shader gallery/render/reload, pixels, json-render catalog/spec, rollback, retries, conflict, gesture, undo/redo.")
  if (process.env.PELAGIK_KEEP_TEST_ARTIFACTS) console.log(`Render fixture: ${pngFile}`)
} finally {
  electron?.kill()
  await client.close(); await second.close()
  if (discovery) { try { process.kill(discovery.pid, "SIGTERM") } catch {} }
  for (const request of pending.values()) clearTimeout(request.timer)
  if (!process.env.PELAGIK_KEEP_TEST_ARTIFACTS) await rm(directory, { recursive: true, force: true })
}
