import { readFile } from "node:fs/promises"
import { brokerRequest, ensureBroker } from "./local"
import { serverConfig, setupAgents, setupPath } from "./setup"

const command = process.argv[2]
if (command === "setup") {
  const dry = process.argv.includes("--dry-run")
  const results = await setupAgents(dry)
  for (const result of results) console.log(result)
  if (!results.length) console.log("No supported clients detected. MCP configuration:\n" + JSON.stringify({ mcpServers: { pelagik: serverConfig } }, null, 2))
  if (!dry) {
    await ensureBroker()
    console.log("Pelagik desktop will connect automatically. Restart agent clients once to load MCP tools. Any agent can also use: bun run agent call TOOL 'JSON'")
  }
  if (results.some(r => r.startsWith("Failed"))) process.exitCode = 1
} else if (command === "desktop-connect") {
  await readFile(setupPath, "utf8")
  console.log(JSON.stringify(await brokerRequest(await ensureBroker(), "/pairing", {})))
} else if (command === "pair") {
  const pairing = await brokerRequest(await ensureBroker(), "/pairing", {})
  console.log(`For a web editor, open Agents and paste this code once:\n\n${pairing.code}\n\nBroker: ${pairing.url}\n\nThis browser will reconnect automatically afterward.`)
} else if (command === "status") {
  console.log(JSON.stringify(await brokerRequest(await ensureBroker(), "/status"), null, 2))
} else if (command === "call") {
  const tool = process.argv[3]
  if (!tool) throw new Error("Usage: bun run agent call TOOL 'JSON'")
  const result = await brokerRequest(await ensureBroker(), "/call", { tool, args: JSON.parse(process.argv[4] ?? "{}"), clientId: "00000000-0000-4000-8000-000000000001" })
  console.log(JSON.stringify(result, null, 2))
  if (result.error) process.exitCode = 1
} else {
  console.log("Usage: bun run agent setup [--dry-run] | status | call TOOL 'JSON' | pair")
  if (command) process.exitCode = 1
}
