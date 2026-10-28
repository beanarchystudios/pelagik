import { afterEach, describe, expect, it, vi } from "vitest"
import { iconGlyph } from "@pelagik/design-spec/properties"
import { iconLibraryName, listCollectionIcons, loadIconGlyphs, searchIcons, splitIconName } from "./iconify"
import lucide from "./fixtures/lucide.json"

function jsonResponse(data: unknown): Response {
  return new Response(JSON.stringify(data), { headers: { "content-type": "application/json" } })
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("Iconify client", () => {
  it("lists every icon in a collection, including categorized names", async () => {
    const fetchMock = vi.fn(async (_url: string) => jsonResponse({
      uncategorized: ["house", "house"],
      categories: { Common: ["heart", "house"] },
    }))
    vi.stubGlobal("fetch", fetchMock)

    expect(await listCollectionIcons("test-icons")).toEqual(["test-icons:house", "test-icons:heart"])
    expect(await listCollectionIcons("test-icons")).toEqual(["test-icons:house", "test-icons:heart"])
    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(String(fetchMock.mock.calls[0][0])).toContain("/collection?prefix=test-icons")
  })

  it("searches only the chosen libraries and ignores malformed names", async () => {
    const fetchMock = vi.fn(async (_url: string) => jsonResponse({ icons: ["lucide:house", "../evil", 42, "ph:house"] }))
    vi.stubGlobal("fetch", fetchMock)
    expect(await searchIcons("house", ["lucide", "ph"])).toEqual(["lucide:house", "ph:house"])
    const url = String(fetchMock.mock.calls[0][0])
    expect(url.startsWith("https://api.iconify.design/search?")).toBe(true)
    expect(url).toContain("query=house")
    expect(url).toContain("prefixes=lucide%2Cph")
  })

  it("loads each library once, converts icons, and leaves out icons it cannot import", async () => {
    const fetchMock = vi.fn(async () =>
      jsonResponse({ prefix: "lucide", width: 24, height: 24, icons: { house: lucide.icons.house, broken: { body: '<use href="#a"/>' } } }),
    )
    vi.stubGlobal("fetch", fetchMock)
    const glyphs = await loadIconGlyphs(["lucide:house", "lucide:broken"])
    expect([...glyphs.keys()]).toEqual(["lucide:house"])
    expect(iconGlyph.safeParse(glyphs.get("lucide:house")).success).toBe(true)
    await loadIconGlyphs(["lucide:house", "lucide:broken"])
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it("follows aliases and applies the alias's own flips", async () => {
    vi.stubGlobal("fetch", vi.fn(async () =>
      jsonResponse({ prefix: "ph", width: 24, height: 24, icons: { house: lucide.icons.house }, aliases: { "home-alias": { parent: "house", hFlip: true } } }),
    ))
    const glyphs = await loadIconGlyphs(["ph:home-alias"])
    expect(glyphs.get("ph:home-alias")?.elements[0].attrs.transform).toContain("scale(-1 1)")
  })

  it("explains when the search cannot reach Iconify", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => {
      throw new TypeError("Failed to fetch")
    }))
    await expect(searchIcons("house", [])).rejects.toThrow("internet connection")
  })

  it("splits names and labels libraries", () => {
    expect(splitIconName("hugeicons:home-01")).toEqual({ prefix: "hugeicons", icon: "home-01" })
    expect(iconLibraryName("ph")).toBe("Phosphor")
    expect(iconLibraryName("mdi")).toBe("mdi")
  })
})
