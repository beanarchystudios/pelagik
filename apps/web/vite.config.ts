/// <reference types="vitest/config" />
import { fileURLToPath } from "node:url"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    // Set TUNNEL=1 to serve the dev server through a Cloudflare quick tunnel.
    allowedHosts: process.env.TUNNEL ? [".trycloudflare.com"] : [],
  },
  test: {
    environment: "node",
  },
})
