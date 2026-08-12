import { RGBA } from "@opentui/core"
import type { ResolvedTheme, ResolvedThemeTokens } from "@opencode-ai/theme/tui"

function clearAlpha(color: RGBA) {
  return RGBA.fromValues(color.r, color.g, color.b, 0)
}

function clearView(view: ResolvedThemeTokens): ResolvedThemeTokens {
  return {
    ...view,
    background: {
      ...view.background,
      default: clearAlpha(view.background.default),
      surface: {
        offset: clearAlpha(view.background.surface.offset),
        overlay: clearAlpha(view.background.surface.overlay),
      },
    },
    diff: {
      ...view.diff,
      background: {
        added: clearAlpha(view.diff.background.added),
        removed: clearAlpha(view.diff.background.removed),
        context: clearAlpha(view.diff.background.context),
      },
      lineNumber: {
        ...view.diff.lineNumber,
        background: {
          added: clearAlpha(view.diff.lineNumber.background.added),
          removed: clearAlpha(view.diff.lineNumber.background.removed),
        },
      },
    },
    markdown: {
      ...view.markdown,
      codeBlock: clearAlpha(view.markdown.codeBlock),
    },
  }
}

/**
 * Transparent UI (ported from the fork's dev TUI patches):
 * - Root canvas, surface plates, and large content fills go fully clear so the
 *   terminal wallpaper shows through (prompt uses surface.offset, slash/autocomplete
 *   and dialog shells use surface.overlay).
 * - Elevated/overlay contextual views are cleared too: user message plates,
 *   tool blocks, and the vertical tab rail resolve from them.
 * - Content-sized overlays (dialog plate, toast, prompt plate) clear their own rect
 *   via overlayPlate instead — alpha-0 boxes do not paint, so glyphs would bleed.
 */
export function applyUiTransparency(theme: ResolvedTheme): ResolvedTheme {
  return {
    ...theme,
    ...clearView(theme),
    contextual: {
      elevated: clearView(theme.contextual.elevated),
      overlay: clearView(theme.contextual.overlay),
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
