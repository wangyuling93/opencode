import { $ } from "bun"
import path from "node:path"
import { brotliCompressSync, constants } from "node:zlib"
import { collectFiles } from "./files"

export async function buildAppArchive(channel: string, options?: { skipBuild?: boolean }) {
  if (options?.skipBuild) return "{}"
  const root = path.resolve(import.meta.dirname, "../../app")
  const nodeOptions = process.env.NODE_OPTIONS ?? ""
  await $`bun run build -- --sourcemap false`.cwd(root).env({
    ...process.env,
    OPENCODE_CHANNEL: channel,
    VITE_OPENCODE_SERVER_MODE: "origin",
    // Production Vite of packages/app now transforms ~4.5k modules (Mermaid).
    // Default Node heap (~2GB) OOMs while rendering chunks; the archive
    // already drops .map files, so skip generating them.
    NODE_OPTIONS: /--max-old-space-size=/.test(nodeOptions)
      ? nodeOptions
      : [nodeOptions, "--max-old-space-size=8192"].filter(Boolean).join(" "),
  })
  return JSON.stringify(
    Object.fromEntries(
      await Promise.all(
        (await collectFiles(path.join(root, "dist")))
          .map((key) => key.replaceAll(path.sep, "/"))
          .filter((key) => !key.endsWith(".map"))
          .toSorted()
          .map(async (key) => {
            const source = path.join(root, "dist", key)
            const body = Buffer.from(await Bun.file(source).arrayBuffer())
            // Independent entries let the server materialize only assets the browser requests.
            return [key, compress(body)] as const
          }),
      ),
    ),
  )
}

function compress(body: Buffer) {
  return brotliCompressSync(body, {
    params: { [constants.BROTLI_PARAM_QUALITY]: 6 },
  }).toString("base64")
}
