import { ScrollArea } from "@pelagik/ui/components/scroll-area"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@pelagik/ui/components/tabs"
import { AgentActivity } from "./agent/AgentActivity"
import { Canvas } from "./canvas/Canvas"
import { Toolbar } from "./canvas/Toolbar"
import { IconPicker } from "./icons/IconPicker"
import { ShaderPicker } from "./shaders/ShaderPicker"
import { LayersPanel } from "./panels/LayersPanel"
import { PageOverview } from "./panels/PageOverview"
import { PropertiesPanel } from "./panels/PropertiesPanel"
import { LeftSidebarHeader, RightSidebarHeader } from "./panels/SidebarHeaders"
import { ShortcutsDialog } from "./panels/ShortcutsDialog"
import { ThemePanel } from "./panels/ThemePanel"
import { useEditor } from "./state/store"

function PanelHeader({ children }: { children: string }) {
  return (
    <div className="flex h-9 shrink-0 items-center border-b px-3 text-xs font-medium text-muted-foreground">
      <span className="min-w-0 truncate" title={children}>
        {children}
      </span>
    </div>
  )
}

export function Editor() {
  const hasSelection = useEditor((s) => s.selectedIds.length > 0)
  const selectionLabel = useEditor((s) => {
    if (s.selectedIds.length !== 1) return `${s.selectedIds.length} layers`
    return s.doc.nodes[s.selectedIds[0]]?.name ?? "Design"
  })

  return (
    <div className="grid h-dvh min-h-0 grid-cols-[240px_minmax(0,1fr)_260px] overflow-hidden bg-background text-foreground">
      <aside className="flex min-h-0 flex-col border-r bg-sidebar">
        <LeftSidebarHeader />
        <Tabs defaultValue="layers" className="flex min-h-0 flex-1 flex-col gap-0">
          <TabsList variant="line" className="h-9 w-full shrink-0 justify-start rounded-none border-b bg-sidebar px-2">
            <TabsTrigger value="layers" className="rounded-none">Layers</TabsTrigger>
            <TabsTrigger value="theme" className="rounded-none">Theme</TabsTrigger>
          </TabsList>
          <TabsContent value="layers" className="flex min-h-0 flex-1 flex-col">
            <LayersPanel />
          </TabsContent>
          <TabsContent value="theme" className="flex min-h-0 flex-1 flex-col">
            <ThemePanel />
          </TabsContent>
        </Tabs>
      </aside>
      <main className="relative min-h-0 min-w-0">
        <Canvas />
        <Toolbar />
        <AgentActivity />
      </main>
      <aside className="flex min-h-0 flex-col border-l bg-sidebar">
        <RightSidebarHeader />
        <PanelHeader>{hasSelection ? selectionLabel : "Page"}</PanelHeader>
        <ScrollArea className="min-h-0 flex-1">
          {hasSelection ? <PropertiesPanel /> : <PageOverview />}
        </ScrollArea>
      </aside>
      <ShortcutsDialog />
      <IconPicker />
      <ShaderPicker />
    </div>
  )
}
