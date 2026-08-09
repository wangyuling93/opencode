import { expect, test } from "bun:test"
import { mkdir, writeFile } from "node:fs/promises"
import path from "node:path"
import { RGBA, type TerminalColors } from "@opentui/core"
import {
  DEFAULT_THEMES,
  addTheme,
  allThemes,
  applyUiTransparency,
  hasTheme,
  overlayPlate,
  resolveTheme,
  selectedForeground,
  terminalMode,
} from "../src/theme"
import { discoverThemes } from "../src/context/theme"
import { tmpdir } from "./fixture/fixture"

test("addTheme writes into module theme store", () => {
  const name = `plugin-theme-${Date.now()}`
  expect(addTheme(name, DEFAULT_THEMES.opencode)).toBe(true)
  expect(allThemes()[name]).toBeDefined()
})

test("addTheme keeps first theme for duplicate names", () => {
  const name = `plugin-theme-keep-${Date.now()}`
  const one = structuredClone(DEFAULT_THEMES.opencode)
  const two = structuredClone(DEFAULT_THEMES.opencode)
  one.theme.primary = "#101010"
  two.theme.primary = "#fefefe"

  expect(addTheme(name, one)).toBe(true)
  expect(addTheme(name, two)).toBe(false)
  expect(allThemes()[name]!.theme.primary).toBe("#101010")
})

test("addTheme ignores entries without a theme object", () => {
  const name = `plugin-theme-invalid-${Date.now()}`
  expect(addTheme(name, { defs: { a: "#ffffff" } })).toBe(false)
  expect(allThemes()[name]).toBeUndefined()
})

test("hasTheme checks theme presence", () => {
  const name = `plugin-theme-has-${Date.now()}`
  expect(hasTheme(name)).toBe(false)
  expect(addTheme(name, DEFAULT_THEMES.opencode)).toBe(true)
  expect(hasTheme(name)).toBe(true)
})

test("resolveTheme rejects circular color refs", () => {
  const item = structuredClone(DEFAULT_THEMES.opencode)
  item.defs = { ...item.defs, one: "two", two: "one" }
  item.theme.primary = "one"
  expect(() => resolveTheme(item, "dark")).toThrow("Circular color reference")
})

test("applyUiTransparency clears root fills, prompt, slash menu, and dialog plates", () => {
  const base = resolveTheme(DEFAULT_THEMES.opencode, "dark")
  expect(base.background.a).toBeGreaterThan(0)
  expect(base.backgroundPanel.a).toBeGreaterThan(0)
  expect(base.backgroundElement.a).toBeGreaterThan(0)
  expect(base.backgroundMenu.a).toBeGreaterThan(0)
  expect(base.dialogBackdrop.a).toBeGreaterThan(0)
  expect(base.overlayScrim.a).toBeGreaterThan(0)

  const next = applyUiTransparency(base)
  expect(next.background.a).toBe(0)
  // Prompt, slash/autocomplete, and dialog/status plates all clear for wallpaper.
  expect(next.backgroundElement.a).toBe(0)
  expect(next.backgroundMenu.a).toBe(0)
  expect(next.backgroundPanel.a).toBe(0)
  expect(next.markdownCodeBlock.a).toBe(0)
  expect(next.diffAddedBg.a).toBe(0)
  expect(next.text.a).toBe(base.text.a)
  expect(next.primary.a).toBe(base.primary.a)
  expect(next.text.r).toBe(base.text.r)
  expect(next.selectedListItemText.a).toBeGreaterThan(0)
  // Full-screen dimmers stay clear so main UI outside the modal remains visible.
  // Modal plate clear is content-sized in Dialog (defaultBackground), not here.
  expect(next.dialogBackdrop.a).toBe(0)
  expect(next.overlayScrim.a).toBe(0)
})

test("overlayPlate uses themed panel unless transparent, then terminal default clear", () => {
  const panel = RGBA.fromInts(32, 32, 40, 255)
  expect(overlayPlate(panel, false)).toBe(panel)
  const clear = overlayPlate(panel, true)
  expect(clear.equals(RGBA.defaultBackground())).toBe(true)
})

test("applyUiTransparency repairs explicit transparent selectedListItemText", () => {
  const item = structuredClone(DEFAULT_THEMES.opencode)
  item.theme.selectedListItemText = "transparent"
  const base = resolveTheme(item, "dark")
  expect(base.selectedListItemText.a).toBe(0)
  expect(base._hasSelectedListItemText).toBe(true)

  const next = applyUiTransparency(base)
  expect(next.selectedListItemText.a).toBeGreaterThan(0)
  expect(selectedForeground(next).a).toBe(next.selectedListItemText.a)
  expect(selectedForeground(next).r).toBe(next.selectedListItemText.r)
})

test("selectedForeground contrasts against provided surfaces under transparency", () => {
  const next = applyUiTransparency(resolveTheme(DEFAULT_THEMES.opencode, "dark"))
  const darkSurface = RGBA.fromInts(20, 20, 20)
  const lightSurface = RGBA.fromInts(240, 240, 240)

  const onDark = selectedForeground(next, darkSurface)
  const onLight = selectedForeground(next, lightSurface)
  // Light text on dark surface, dark text on light surface.
  expect(onDark.r + onDark.g + onDark.b).toBeGreaterThan(onLight.r + onLight.g + onLight.b)
  expect(onDark.a).toBeGreaterThan(0)
  expect(onLight.a).toBeGreaterThan(0)
})

function terminalColors(defaultBackground: string | null, palette: Array<string | null> = []): TerminalColors {
  return {
    palette,
    defaultForeground: null,
    defaultBackground,
    cursorColor: null,
    mouseForeground: null,
    mouseBackground: null,
    tekForeground: null,
    tekBackground: null,
    highlightBackground: null,
    highlightForeground: null,
  }
}

test("terminalMode derives mode from refreshed background", () => {
  expect(terminalMode(terminalColors("#fbf1c7"))).toBe("light")
  expect(terminalMode(terminalColors("#1a1b26"))).toBe("dark")
})

test("terminalMode does not derive mode from ANSI slot zero", () => {
  expect(terminalMode(terminalColors(null, ["#000000"]))).toBeUndefined()
})

test("custom theme precedence follows directory order", async () => {
  await using tmp = await tmpdir()
  const global = path.join(tmp.path, "global")
  const project = path.join(tmp.path, "project")
  await mkdir(path.join(global, "themes"), { recursive: true })
  await mkdir(path.join(project, "themes"), { recursive: true })
  await writeFile(path.join(global, "themes", "custom.json"), JSON.stringify({ source: "global" }))
  await writeFile(path.join(project, "themes", "custom.json"), JSON.stringify({ source: "project" }))

  await expect(discoverThemes([global, project])).resolves.toEqual({ custom: { source: "project" } })
})
