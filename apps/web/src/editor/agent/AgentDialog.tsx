import { useState } from "react"
import { Bot } from "lucide-react"
import { Tooltip, TooltipContent, TooltipTrigger } from "@pelagik/ui/components/tooltip"
import { Button } from "@pelagik/ui/components/button"
import { Input } from "@pelagik/ui/components/input"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@pelagik/ui/components/dialog"
import { connectAgent, disconnectAgent, resumeAutomaticAgentConnection, useAgentConnection } from "./connection"

export function AgentDialog() {
  const connection = useAgentConnection()
  const [code, setCode] = useState("")
  const [address, setAddress] = useState("ws://127.0.0.1:48765/bridge")
  const [error, setError] = useState<string | null>(null)
  const [open, setOpen] = useState(false)
  const status = connection.state === "connected" ? "Connected" : connection.state === "connecting" ? "Connecting" : "Disconnected"
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Tooltip>
        <TooltipTrigger asChild>
          <DialogTrigger asChild>
            <Button
              variant="ghost" size="icon-sm" aria-label="Agents"
              data-connection={connection.state}
              className="relative rounded-md text-muted-foreground hover:text-foreground"
            >
              <Bot aria-hidden="true" className="size-[18px]" strokeWidth={1.75} />
              {connection.state !== "disconnected" || connection.error ? (
                <span aria-hidden="true" className={`absolute right-1 top-1 size-1.5 rounded-full ring-2 ring-sidebar ${connection.state === "connected" ? "bg-emerald-500" : connection.state === "connecting" ? "bg-amber-400 motion-safe:animate-pulse" : "bg-amber-500"}`} />
              ) : null}
              <span className="sr-only">{status}</span>
            </Button>
          </DialogTrigger>
        </TooltipTrigger>
        <TooltipContent sideOffset={8}>Agents · {status.toLowerCase()}</TooltipContent>
      </Tooltip>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Connect agents</DialogTitle>
          <DialogDescription>Connected local agents can read and edit this document. Each edit batch is one undo step.</DialogDescription>
        </DialogHeader>
        {connection.state === "connected" ? (
          <>
            <p role="status">This editor is connected.</p>
            <p className="break-all text-xs text-muted-foreground">Session {connection.sessionId}</p>
            {connection.lastActivity && <p className="text-xs text-muted-foreground">Last activity: {connection.lastActivity}</p>}
            <Button variant="outline" onClick={disconnectAgent}>Disconnect agents</Button>
          </>
        ) : (
          <form className="grid gap-3" onSubmit={event => {
            event.preventDefault(); setError(null)
            try { connectAgent(code, address); setCode(""); setOpen(false) }
            catch (cause) { setError(cause instanceof Error ? cause.message : "Connection failed") }
          }}>
            <p className="text-xs text-muted-foreground">Run <code>bun run agent:setup</code> once in the Pelagik project. Desktop connects automatically. For a web editor, run <code>bun run agent:pair</code> and paste the code once.</p>
            {window.pelagikAgents && <Button variant="outline" type="button" onClick={resumeAutomaticAgentConnection}>Enable automatic connection</Button>}
            <label className="grid gap-1">Broker address<Input aria-label="Broker address" value={address} onChange={event => setAddress(event.target.value)} disabled={connection.state === "connecting"} /></label>
            <label className="grid gap-1">Pairing code<Input aria-label="Pairing code" type="password" autoComplete="off" value={code} onChange={event => setCode(event.target.value)} disabled={connection.state === "connecting"} /></label>
            {(error || connection.error) && <p role="alert" className="text-sm text-destructive">{error || connection.error}</p>}
            <Button type="submit" disabled={connection.state === "connecting" || !code.trim()}>{connection.state === "connecting" ? "Connecting…" : "Connect"}</Button>
            {connection.state === "connecting" && <Button variant="outline" type="button" onClick={disconnectAgent}>Cancel</Button>}
          </form>
        )}
      </DialogContent>
    </Dialog>
  )
}
