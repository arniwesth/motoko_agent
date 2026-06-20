import { mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import type { ScratchpadCellResult, ScratchpadDisplayBundle } from "./frames.js";
import { renderBundle } from "./display.js";

const DEFAULT_LIMIT = 50 * 1024;

function imageExt(mime: string): string {
  if (mime === "image/jpeg") return "jpg";
  if (mime === "image/svg+xml") return "svg";
  if (mime === "image/webp") return "webp";
  return "png";
}

export function spillImages(
  workdir: string,
  sessionId: string,
  cellIndex: number,
  bundles: ScratchpadDisplayBundle[],
): Array<{ path: string; mime: string; width?: number; height?: number }> {
  const images: Array<{ path: string; mime: string; width?: number; height?: number }> = [];
  const dir = join(workdir, ".motoko", "artifacts", sessionId.replace(/[^A-Za-z0-9_.-]/g, "_"));
  mkdirSync(dir, { recursive: true });
  let imageNo = 0;
  for (const b of bundles) {
    if (b.type !== "image" || typeof b.data !== "string") continue;
    imageNo += 1;
    const mime = b.mime ?? "image/png";
    const rel = join(".motoko", "artifacts", sessionId.replace(/[^A-Za-z0-9_.-]/g, "_"), `cell${cellIndex}-${imageNo}.${imageExt(mime)}`);
    const abs = join(workdir, rel);
    const data = mime === "image/svg+xml" ? Buffer.from(b.data, "utf8") : Buffer.from(b.data, "base64");
    writeFileSync(abs, data);
    images.push({ path: rel, mime, width: b.width, height: b.height });
  }
  return images;
}

export function buildScratchpadTranscript(cells: ScratchpadCellResult[], images: Array<{ path: string; mime: string; width?: number; height?: number }>, limit = DEFAULT_LIMIT): string {
  const lines: string[] = [];
  let imageAt = 0;
  for (const cell of cells) {
    const header = cell.title ? cell.title : `${cell.language} cell ${cell.index + 1}`;
    lines.push(`== ${header} ==`);
    if (cell.stdout.trim() !== "") {
      lines.push("[stdout]");
      lines.push(cell.stdout.replace(/\s+$/g, ""));
    }
    if (cell.stderr.trim() !== "") {
      lines.push("[stderr]");
      lines.push(cell.stderr.replace(/\s+$/g, ""));
    }
    for (const d of cell.displays) {
      if (d.type === "image") {
        const img = images[imageAt++];
        const dims = img?.width && img?.height ? ` (${img.width}x${img.height} ${img.mime})` : ` (${img?.mime ?? d.mime ?? "image/*"})`;
        lines.push(`[image: ${img?.path ?? "<not-spilled>"}${dims}]`);
      } else {
        lines.push(`[display:${d.type}]`);
        lines.push(renderBundle(d));
      }
    }
    if (cell.result) {
      lines.push("[result]");
      lines.push(renderBundle(cell.result));
    }
    if (cell.error) {
      lines.push("[error]");
      lines.push(`${cell.error.ename}: ${cell.error.evalue}`);
      if (cell.error.traceback.length > 0) lines.push(cell.error.traceback.join("\n"));
    }
    lines.push(`[done: exit=${cell.exit_code} count=${cell.executionCount}${cell.cancelled ? " cancelled" : ""}]`);
    lines.push("");
  }
  const text = lines.join("\n").trimEnd();
  const b = Buffer.from(text, "utf8");
  if (b.byteLength <= limit) return text;
  return b.subarray(0, limit).toString("utf8") + "\n[truncated]";
}
