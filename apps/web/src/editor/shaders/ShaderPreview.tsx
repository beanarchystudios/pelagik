import { useLayoutEffect, useState } from "react"
import type { CSSProperties } from "react"
import type { ShaderId } from "@pelagik/design-core/types"
import { getPenShaderVariant } from "./catalog"
import { renderShaderImage } from "./renderer"

export function ShaderPreview({
  shader,
  color,
  width,
  height,
  className,
  style,
  renderShader = false,
  shapeType,
  radius = 0,
}: {
  shader: ShaderId
  color: string
  width: number
  height: number
  className?: string
  style?: CSSProperties
  renderShader?: boolean
  shapeType?: "frame" | "rectangle" | "ellipse"
  radius?: number
}) {
  const [src, setSrc] = useState<string | null>(null)
  const penVariant = getPenShaderVariant(shader)
  useLayoutEffect(() => {
    const rendered = renderShader ? renderShaderImage(shader, color, width, height, { shapeType, radius }) : null
    const preview = penVariant?.preview ? `${import.meta.env.BASE_URL}${penVariant.preview}` : null
    setSrc(rendered ?? preview ?? renderShaderImage(shader, color, width, height, { shapeType, radius }))
  }, [shader, color, width, height, renderShader, shapeType, radius, penVariant])

  return src
    ? <img src={src} alt="" aria-hidden="true" draggable={false} className={className} style={style} />
    : <div aria-hidden="true" className={className} style={{ background: `radial-gradient(circle at 70% 30%, white 0, ${color} 46%, #17212b 130%)`, ...style }} />
}
