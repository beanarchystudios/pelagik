import type { Point } from "./types"

/** Affine transform in the CSS `matrix(a, b, c, d, e, f)` convention. Only rotations and translations are produced. */
export interface Matrix {
  a: number
  b: number
  c: number
  d: number
  e: number
  f: number
}

export const IDENTITY: Matrix = { a: 1, b: 0, c: 0, d: 1, e: 0, f: 0 }

export function translate(x: number, y: number): Matrix {
  return { a: 1, b: 0, c: 0, d: 1, e: x, f: y }
}

/** Clockwise for positive degrees, matching CSS `rotate()` on a y-down canvas. */
export function rotate(degrees: number): Matrix {
  const radians = (degrees * Math.PI) / 180
  const cos = Math.cos(radians)
  const sin = Math.sin(radians)
  return { a: cos, b: sin, c: -sin, d: cos, e: 0, f: 0 }
}

/** `multiply(m, n)` applies `n` first, then `m`. */
export function multiply(m: Matrix, n: Matrix): Matrix {
  return {
    a: m.a * n.a + m.c * n.b,
    b: m.b * n.a + m.d * n.b,
    c: m.a * n.c + m.c * n.d,
    d: m.b * n.c + m.d * n.d,
    e: m.a * n.e + m.c * n.f + m.e,
    f: m.b * n.e + m.d * n.f + m.f,
  }
}

export function invert(m: Matrix): Matrix {
  // Rotations and translations have a unit determinant, so no zero check is needed.
  const det = m.a * m.d - m.b * m.c
  const a = m.d / det
  const b = -m.b / det
  const c = -m.c / det
  const d = m.a / det
  return { a, b, c, d, e: -(a * m.e + c * m.f), f: -(b * m.e + d * m.f) }
}

export function apply(m: Matrix, p: Point): Point {
  return { x: m.a * p.x + m.c * p.y + m.e, y: m.b * p.x + m.d * p.y + m.f }
}

/** Rotation encoded in the matrix, in degrees. */
export function rotationOf(m: Matrix): number {
  return (Math.atan2(m.b, m.a) * 180) / Math.PI
}

/** Maps any angle into (-180, 180]. */
export function normalizeAngle(degrees: number): number {
  return ((((degrees + 180) % 360) + 360) % 360) - 180
}
