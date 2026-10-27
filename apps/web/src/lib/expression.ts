const NUMBER = /(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/iy

type Token = number | "+" | "-" | "*" | "/" | "(" | ")"

function tokenize(input: string): Token[] | null {
  const tokens: Token[] = []
  let i = 0
  while (i < input.length) {
    const ch = input[i]
    if (/\s/.test(ch)) {
      i++
    } else if ("+-*/()".includes(ch)) {
      tokens.push(ch as Token)
      i++
    } else {
      NUMBER.lastIndex = i
      const match = NUMBER.exec(input)
      if (!match) return null
      tokens.push(Number(match[0]))
      i += match[0].length
    }
  }
  return tokens
}

/**
 * Evaluates typed arithmetic such as "3*4" or "(100 + 20) / 2". Supports decimals, parentheses,
 * and unary signs. Returns null for anything else, including division by zero.
 */
export function evaluateExpression(input: string): number | null {
  const tokens = tokenize(input)
  if (!tokens) return null
  let pos = 0

  const unary = (): number => {
    const token = tokens[pos]
    if (token === "-" || token === "+") {
      pos++
      const value = unary()
      return token === "-" ? -value : value
    }
    return primary()
  }

  const primary = (): number => {
    const token = tokens[pos++]
    if (typeof token === "number") return token
    if (token !== "(") throw new SyntaxError("Expected a number")
    const value = sum()
    if (tokens[pos++] !== ")") throw new SyntaxError("Expected )")
    return value
  }

  const product = (): number => {
    let value = unary()
    while (tokens[pos] === "*" || tokens[pos] === "/") {
      const op = tokens[pos++]
      const rhs = unary()
      value = op === "*" ? value * rhs : value / rhs
    }
    return value
  }

  const sum = (): number => {
    let value = product()
    while (tokens[pos] === "+" || tokens[pos] === "-") {
      const op = tokens[pos++]
      const rhs = product()
      value = op === "+" ? value + rhs : value - rhs
    }
    return value
  }

  try {
    const value = sum()
    return pos === tokens.length && Number.isFinite(value) ? value : null
  } catch {
    return null
  }
}
