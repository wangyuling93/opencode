import { describe, expect, test } from "bun:test"
import { copy } from "../../src/util/selection"

function mockRenderer(text: string | null) {
  let cleared = false
  return {
    renderer: {
      getSelection: () =>
        text === null
          ? null
          : {
              getSelectedText: () => text,
              selectedRenderables: [] as [],
            },
      clearSelection: () => {
        cleared = true
      },
      currentFocusedRenderable: null as null,
    },
    wasCleared: () => cleared,
  }
}

function mockToast() {
  return {
    show: () => {},
    error: () => {},
  }
}

function mockClipboard() {
  return {
    write: async () => {},
  }
}

describe("Selection.copy", () => {
  test("clears selection by default after copy", () => {
    const { renderer, wasCleared } = mockRenderer("hello")
    expect(copy(renderer, mockToast(), mockClipboard())).toBe(true)
    expect(wasCleared()).toBe(true)
  })

  test("keeps selection when keep is true (copy-on-select mouse-up)", () => {
    const { renderer, wasCleared } = mockRenderer("hello")
    expect(copy(renderer, mockToast(), mockClipboard(), { keep: true })).toBe(true)
    expect(wasCleared()).toBe(false)
  })

  test("returns false when nothing is selected", () => {
    const { renderer, wasCleared } = mockRenderer(null)
    expect(copy(renderer, mockToast(), mockClipboard(), { keep: true })).toBe(false)
    expect(wasCleared()).toBe(false)
  })
})
