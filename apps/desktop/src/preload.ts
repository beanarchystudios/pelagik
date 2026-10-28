import { contextBridge, ipcRenderer } from "electron"

contextBridge.exposeInMainWorld("pelagikAgents", {
  credentials: () => ipcRenderer.invoke("pelagik:agent-credentials"),
})
