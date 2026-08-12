import { RGBA } from "@opentui/core"
import type { ResolvedTheme } from "@opencode-ai/theme/tui"

function clearAlpha(color: RGBA) {
  return RGBA.fromValues(color.r, color.g, color.b, 0)
}

/**
 * Transparent UI (ported from the fork's dev TUI patches):
 * - Root canvas, surface plates, and large content fills go fully clear so the
 *   terminal wallpaper shows through (prompt uses surface.offset, slash/autocomplete
 *   and dialog shells use surface.overlay).
 * - Content-sized overlays (dialog plate, toast, prompt plate) clear their own rect
 *   via overlayPlate instead — alpha-0 boxes do not paint, so glyphs would bleed.
 */
export function applyUiTransparency(theme: ResolvedTheme): ResolvedTheme {
  return {
    ...theme,
    background: {
      ...theme.background,
      default: clearAlpha(theme.background.default),
      surface: {
        offset: clearAlpha(theme.background.surface.offset),
        overlay: clearAlpha(theme.background.surface.overlay),
      },
    },
    diff: {
      ...theme.diff,
      background: {
        added: clearAlpha(theme.diff.background.added),
        removed: clearAlpha(theme.diff.background.removed),
        context: clearAlpha(theme.diff.background.context),
      },
      lineNumber: {
        ...theme.diff.lineNumber,
        background: {
          added: clearAlpha(theme.diff.lineNumber.background.added),
          removed: clearAlpha(theme.diff.lineNumber.background.removed),
        },
      },
    },
    markdown: {
      ...theme.markdown,
      codeBlock: clearAlpha(theme.markdown.codeBlock),
    },
  }
}

/**
 * Fill for content-sized overlays (modal, toast, prompt plate) under transparent UI.
 * Terminal-default paint clears glyphs in the box only; alpha-0 would leave
 * bleed-through. When not transparent, use the themed plate color as-is.
 */
export function overlayPlate(panel: RGBA, transparent: boolean) {
  return transparent ? RGBA.defaultBackground() : panel
}
