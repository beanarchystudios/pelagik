import { describe, expect, it } from "vitest"
import { evaluateExpression } from "./expression"

describe("evaluateExpression", () => {
  it("evaluates a plain product", () => {
    expect(evaluateExpression("3*4")).toBe(12)
  })

  it("ignores whitespace", () => {
    expect(evaluateExpression(" 3 * 4 ")).toBe(12)
  })

  it("applies multiplication and division before addition and subtraction", () => {
    expect(evaluateExpression("2+3*4")).toBe(14)
    expect(evaluateExpression("10-6/3")).toBe(8)
  })

  it("honors parentheses", () => {
    expect(evaluateExpression("(2+3)*4")).toBe(20)
  })

  it("handles unary signs", () => {
    expect(evaluateExpression("-3*-2")).toBe(6)
    expect(evaluateExpression("2--3")).toBe(5)
  })

  it("accepts decimals and exponents", () => {
    expect(evaluateExpression("1.5*2")).toBe(3)
    expect(evaluateExpression(".5+1")).toBe(1.5)
    expect(evaluateExpression("1e3")).toBe(1000)
  })

  it("rejects empty, incomplete, and malformed input", () => {
    expect(evaluateExpression("")).toBeNull()
    expect(evaluateExpression("   ")).toBeNull()
    expect(evaluateExpression("3*")).toBeNull()
    expect(evaluateExpression("(3+4")).toBeNull()
    expect(evaluateExpression("3+4)")).toBeNull()
    expect(evaluateExpression("3 4")).toBeNull()
    expect(evaluateExpression("2**3")).toBeNull()
    expect(evaluateExpression("3e")).toBeNull()
    expect(evaluateExpression("abc")).toBeNull()
  })

  it("rejects results that are not finite", () => {
    expect(evaluateExpression("1/0")).toBeNull()
  })
})
