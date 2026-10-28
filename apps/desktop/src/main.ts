import { app, BrowserWindow, Menu, dialog, ipcMain } from "electron"
import path from "node:path"
import { existsSync } from "node:fs"
import { readFile } from "node:fs/promises"
import { homedir } from "node:os"
import { execFile } from "node:child_process"
import { promisify } from "node:util"

const runFile = promisify(execFile)
const agentDirectory = process.env.PELAGIK_AGENT_DIR ?? path.join(process.env.XDG_STATE_HOME ?? path.join(homedir(), ".local/state"), "pelagik/agent")
let credentials: Promise<unknown> | undefined
async function agentCredentials() {
  let settings: { bun: string; cli: string; port: number }
  try { settings = JSON.parse(await readFile(path.join(agentDirectory, "setup.json"), "utf8")) }
  catch (error) { if ((error as NodeJS.ErrnoException).code === "ENOENT") return null; throw error }
  const { stdout } = await runFile(settings.bun, [settings.cli, "desktop-connect"], {
    timeout: 15000, maxBuffer: 16384,
    env: { ...process.env, PELAGIK_AGENT_DIR: agentDirectory, PELAGIK_AGENT_PORT: String(settings.port) },
  })
  return JSON.parse(stdout)
}

// Keep desktop autosave separate from browser profiles and stable across updates.
app.setName("pelagik")
// Reuse an existing desktop profile to preserve autosave after the rename.
const legacyProfile = path.join(app.getPath("appData"), "d3sign")
if (existsSync(legacyProfile)) app.setPath("userData", legacyProfile)

const developmentUrl = !app.isPackaged ? process.env.PELAGIK_DEV_URL : undefined
const headlessTestMode = process.env.PELAGIK_TEST_HEADLESS === "1"
if (developmentUrl && new URL(developmentUrl).origin !== "http://127.0.0.1:5174") {
  throw new Error("PELAGIK_DEV_URL must use the desktop development server")
}

async function createWindow() {
  const window = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 800,
    minHeight: 600,
    backgroundColor: "#171717",
    show: false,
    title: "pelagik",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      backgroundThrottling: !headlessTestMode,
    },
  })

  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }))
  window.webContents.on("will-navigate", (event) => event.preventDefault())
  window.webContents.session.setPermissionRequestHandler((contents, permission, callback) => {
    callback(contents === window.webContents && permission === "local-fonts")
  })
  window.webContents.session.setPermissionCheckHandler((contents, permission) => {
    return contents === window.webContents && permission === "local-fonts"
  })
  window.once("ready-to-show", () => {
    if (!headlessTestMode) window.show()
  })

  try {
    if (developmentUrl) await window.loadURL(developmentUrl)
    else await window.loadFile(path.join(__dirname, "renderer/index.html"))
  } catch (error) {
    dialog.showErrorBox("Unable to open pelagik", String(error))
    app.quit()
  }
}

function installMenu() {
  if (process.platform === "linux") {
    Menu.setApplicationMenu(null)
    return
  }

  Menu.setApplicationMenu(Menu.buildFromTemplate([
    ...(process.platform === "darwin" ? [{ role: "appMenu" as const }] : []),
    { role: "fileMenu" },
    {
      label: "View",
      submenu: [
        { role: "reload" },
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "togglefullscreen" },
      ],
    },
    { role: "windowMenu" },
  ]))
}

app.whenReady().then(async () => {
  ipcMain.handle("pelagik:agent-credentials", async event => {
    const window = BrowserWindow.fromWebContents(event.sender)
    if (!window || event.senderFrame !== event.sender.mainFrame) throw new Error("Only the editor can connect agents")
    if (!credentials) credentials = agentCredentials().finally(() => { credentials = undefined })
    return credentials
  })
  installMenu()
  await createWindow()
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) void createWindow()
  })
})

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit()
})
