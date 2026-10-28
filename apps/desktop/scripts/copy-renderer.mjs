import { cp, rm } from "node:fs/promises"

const target = new URL("../dist/renderer/", import.meta.url)
await rm(target, { recursive: true, force: true })
await cp(new URL("../../web/dist/", import.meta.url), target, { recursive: true })
