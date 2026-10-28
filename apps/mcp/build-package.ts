import { mkdir, rm, writeFile } from "node:fs/promises"
import path from "node:path"

const output = path.resolve(import.meta.dir, "dist/npm")
await rm(output, { recursive: true, force: true })
await mkdir(path.join(output, "runtime"), { recursive: true })
const build = await Bun.build({
  entrypoints: ["server", "broker", "cli"].map(name => path.join(import.meta.dir, `src/${name}.ts`)),
  target: "bun", outdir: path.join(output, "runtime"), naming: "[name].js",
})
if (!build.success) throw new Error(`Cannot build npm package: ${build.logs.join("\n")}`)
await writeFile(path.join(output, "package.json"), JSON.stringify({
  name: "pelagik",
  version: "0.1.0",
  description: "Connect AI agents to the Pelagik design editor",
  type: "module",
  bin: { pelagik: "bin.js" },
  files: ["bin.js", "runtime", "README.md"],
  license: "UNLICENSED",
}, null, 2) + "\n")
await writeFile(path.join(output, "bin.js"), "#!/usr/bin/env bun\nimport './runtime/cli.js'\n", { mode: 0o755 })
await writeFile(path.join(output, "README.md"), "# Pelagik\n\nConnect agents with `bunx pelagik setup`, then pair a web editor with `bunx pelagik pair`. Bun is required.\n")
