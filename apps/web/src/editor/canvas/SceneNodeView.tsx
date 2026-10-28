import { memo, useEffect, useLayoutEffect, useRef, type CSSProperties } from "react"
import { finishTextEdit, setNodeText, syncTextHeight } from "../state/commands"
import { useEditor } from "../state/store"
import { IconGlyphView } from "../icons/IconGlyphView"
import { ShaderPreview } from "../shaders/ShaderPreview"
import { isLiquidGlassShader } from "../shaders/catalog"

/**
 * Renders one layer. Children are nested inside their parent's element, so the
 * browser applies parent rotation and frame clipping for us.
 */
export const SceneNodeView = memo(function SceneNodeView({ id, showLabels = true }: { id: string; showLabels?: boolean }) {
  const node = useEditor((s) => s.doc.nodes[id])
  const editing = useEditor((s) => s.editingId === id)
  const sizerRef = useRef<HTMLDivElement>(null)
  const editorRef = useRef<HTMLTextAreaElement>(null)

  // Text boxes are as tall as their wrapped content. Measure it and store the result.
  const measureKey =
    node?.type === "text" ? [node.text, node.width, node.fontFamily, node.fontSize, node.fontWeight, node.textAlign].join("|") : ""
  useLayoutEffect(() => {
    if (!measureKey || !sizerRef.current) return
    syncTextHeight(id, sizerRef.current.offsetHeight)
  }, [id, measureKey])

  useEffect(() => {
    const el = editorRef.current
    if (!editing || !el) return
    el.focus()
    el.setSelectionRange(el.value.length, el.value.length)
  }, [editing])

  if (!node || node.hidden) return null

  const isFrame = node.type === "frame"
  const isGroup = node.type === "group"
  const isText = node.type === "text"
  const hasShape = node.type === "rectangle" || node.type === "ellipse" || isFrame
  const isIcon = node.type === "icon"
  const isLiquidGlass = isLiquidGlassShader(node.shader)

  const wrapperStyle: CSSProperties = {
    position: "absolute",
    left: node.x,
    top: node.y,
    width: node.width,
    height: isText ? undefined : node.height,
    transform: node.rotation === 0 ? undefined : `rotate(${node.rotation}deg)`,
    opacity: node.opacity,
    pointerEvents: "none",
  }

  const shapeStyle: CSSProperties = {
    border: node.stroke ? `${node.strokeWidth}px solid ${node.stroke}` : undefined,
    borderRadius: node.type === "ellipse" ? "50%" : node.radius,
    overflow: "hidden",
    boxSizing: "border-box",
    backdropFilter: isLiquidGlass ? "blur(18px) saturate(1.7)" : undefined,
    WebkitBackdropFilter: isLiquidGlass ? "blur(18px) saturate(1.7)" : undefined,
    backgroundColor: isLiquidGlass ? "rgba(255, 255, 255, 0.035)" : node.shader ? undefined : node.fill ?? undefined,
    boxShadow: isLiquidGlass
      ? "inset 0 1px 0 rgba(255,255,255,.86), inset 0 0 0 1px rgba(255,255,255,.36), inset 0 -1px 0 rgba(27,44,68,.14), 0 8px 24px rgba(20,35,55,.16)"
      : undefined,
  }

  const textStyle: CSSProperties = {
    width: "100%",
    margin: 0,
    padding: 0,
    border: 0,
    fontFamily: node.fontFamily,
    fontSize: node.fontSize,
    fontWeight: node.fontWeight,
    textAlign: node.textAlign,
    lineHeight: 1.25,
    whiteSpace: "pre-wrap",
    overflowWrap: "break-word",
    color: node.fill ?? "#000000",
  }

  return (
    <div style={wrapperStyle} data-node-id={id}>
      {hasShape && (
        <div className="absolute inset-0" style={shapeStyle}>
          {node.shader && <ShaderPreview shader={node.shader} color={node.fill ?? "#d9d9d9"} width={node.width} height={node.height} className="size-full" renderShader shapeType={isFrame ? "frame" : node.type === "ellipse" ? "ellipse" : "rectangle"} radius={node.radius} />}
        </div>
      )}

      {isIcon && node.icon && <IconGlyphView glyph={node.icon} color={node.fill ?? "#000000"} className="absolute inset-0 size-full" />}

      {isText && (
        <>
          <div
            ref={sizerRef}
            className="pointer-events-none"
            style={{ ...textStyle, color: editing ? "transparent" : textStyle.color }}
          >
            {node.text || " "}
          </div>
          {editing && (
            <textarea
              ref={editorRef}
              aria-label="Text content"
              spellCheck={false}
              className="absolute inset-0 h-full resize-none overflow-hidden bg-background outline-none"
              style={{ ...textStyle, pointerEvents: "auto", cursor: "text" }}
              value={node.text}
              onChange={(e) => setNodeText(id, e.target.value)}
              onBlur={() => finishTextEdit()}
              onKeyDown={(e) => {
                if (e.key === "Escape") e.currentTarget.blur()
              }}
              onPointerDown={(e) => e.stopPropagation()}
              onDoubleClick={(e) => e.stopPropagation()}
            />
          )}
        </>
      )}

      {(isFrame || isGroup) && (
        <div
          className="absolute inset-0"
          style={{ overflow: isFrame ? "hidden" : "visible", borderRadius: isFrame ? node.radius : 0 }}
        >
          {node.childIds.map((childId) => (
            <SceneNodeView key={childId} id={childId} showLabels={showLabels} />
          ))}
        </div>
      )}

      {isFrame && showLabels && (
        <>
          <div
            className="pointer-events-none absolute bottom-full left-0 mb-1 origin-bottom-left text-xs font-medium whitespace-nowrap text-muted-foreground"
            style={{ transform: "scale(calc(1 / var(--zoom)))" }}
          >
            {node.name}
          </div>
          {/* Dimensions sit under the artboard in mono, like a measurement readout. */}
          <div
            className="pointer-events-none absolute top-full left-0 mt-1 origin-top-left font-mono text-[11px] whitespace-nowrap text-muted-foreground"
            style={{ transform: "scale(calc(1 / var(--zoom)))" }}
          >
            {Math.round(node.width)} × {Math.round(node.height)}
          </div>
        </>
      )}
    </div>
  )
})
