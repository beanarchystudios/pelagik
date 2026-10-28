// Test-only Electron controller. It runs with a temporary app profile and is never packaged.
const { app, BrowserWindow } = require('electron')
const { mkdirSync } = require('node:fs')
const path = require('node:path')
const { createInterface } = require('node:readline')
mkdirSync(process.env.PELAGIK_TEST_PROFILE, { recursive: true })
app.setPath('appData', process.env.PELAGIK_TEST_PROFILE)
app.setPath('userData', path.join(process.env.PELAGIK_TEST_PROFILE, 'user-data'))
let window
const output = data => process.stdout.write('PELAGIK_E2E ' + JSON.stringify(data) + '\n')
app.on('browser-window-created', (_event, created) => {
  window = created
  window.webContents.once('did-finish-load', () => output({ ready: true }))
  window.webContents.on('render-process-gone', (_event, details) => { output({ fatal: details }); app.exit(1) })
})
createInterface({ input: process.stdin }).on('line', async line => {
  const message = JSON.parse(line)
  try {
    if (message.action === 'undo' || message.action === 'redo') {
      const modifiers = process.platform === 'darwin' ? ['meta'] : ['control']
      if (message.action === 'redo') modifiers.push('shift')
      window.webContents.focus()
      window.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'Z', modifiers })
      window.webContents.sendInputEvent({ type: 'keyUp', keyCode: 'Z', modifiers })
      output({ id: message.id, result: true })
    } else if (message.action === 'reload') {
      output({ id: message.id, result: true }); window.webContents.reload()
    } else if (message.action === 'quit') app.exit(0)
    else output({ id: message.id, result: await window.webContents.executeJavaScript(message.js, true) })
  } catch (error) { output({ id: message.id, error: String(error) }) }
})
require(process.env.PELAGIK_TEST_MAIN)
