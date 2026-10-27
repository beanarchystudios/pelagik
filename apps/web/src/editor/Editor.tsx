import { ScrollArea } from "@/components/ui/scroll-area"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { cn } from "cn"
import { Canvas } from "./canvas/Canvas"
import { Toolbar } from "./canvas/Toolbar"
import { LayersPanel } from "./panels/LayersPanel"
import { PropertiesPanel } from "./panels/PropertiesPanel"
import { ShortcutsDialog } from "./panels/ShortcutsDialog"
import { ThemePanel } from "./panels/ThemePanel"
import { TopBar } from "./panels/TopBar"
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
  // The design panel only appears while something is selected, so the canvas gets the space otherwise.
  const hasSelection = useEditor((s) => s.selectedIds.length > 0)
  const selectionLabel = useEditor((s) => {
    if (s.selectedIds.length !== 1) return `${s.selectedIds.length} layers`
    return s.doc.nodes[s.selectedIds[0]]?.name ?? "Design"
  })

  return (
    <div className="grid h-dvh grid-rows-[auto_minmax(0,1fr)] overflow-hidden bg-background text-foreground">
      <TopBar />
      <div
        className={cn(
          "grid min-h-0",
          hasSelection ? "grid-cols-[240px_minmax(0,1fr)_260px]" : "grid-cols-[240px_minmax(0,1fr)]",
        )}
      >
        <aside className="flex min-h-0 flex-col border-r bg-sidebar">
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
        </main>
        {hasSelection && (
          <aside className="flex min-h-0 flex-col border-l bg-sidebar">
            <PanelHeader>{selectionLabel}</PanelHeader>
            <ScrollArea className="min-h-0 flex-1">
              <PropertiesPanel />
            </ScrollArea>
          </aside>
        )}
      </div>
      <ShortcutsDialog />
    </div>
  )
}
