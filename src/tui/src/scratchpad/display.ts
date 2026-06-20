import type { ScratchpadDisplayBundle } from "./frames.js";

export function bundleFromValue(value: unknown): ScratchpadDisplayBundle {
  if (value && typeof value === "object") {
    const rec = value as Record<string, unknown>;
    if (typeof rec.markdown === "string") {
      return { type: "markdown", mime: "text/markdown", data: rec.markdown };
    }
    if (typeof rec.status === "string") {
      return { type: "status", mime: "text/plain", data: rec.status };
    }
    if (typeof rec.mime === "string" && typeof rec.data === "string" && rec.mime.startsWith("image/")) {
      return {
        type: "image",
        mime: rec.mime,
        data: rec.data,
        width: typeof rec.width === "number" ? rec.width : undefined,
        height: typeof rec.height === "number" ? rec.height : undefined,
      };
    }
  }
  if (typeof value === "string") return { type: "text", mime: "text/plain", data: value };
  return { type: "json", mime: "application/json", data: value };
}

export function normalizeBundle(raw: unknown): ScratchpadDisplayBundle {
  if (raw && typeof raw === "object") {
    const rec = raw as Record<string, unknown>;
    const type = String(rec.type ?? "");
    if (type === "json" || type === "image" || type === "markdown" || type === "status" || type === "text") {
      return {
        type,
        mime: typeof rec.mime === "string" ? rec.mime : undefined,
        data: rec.data,
        width: typeof rec.width === "number" ? rec.width : undefined,
        height: typeof rec.height === "number" ? rec.height : undefined,
      };
    }
  }
  return bundleFromValue(raw);
}

export function renderBundle(bundle: ScratchpadDisplayBundle): string {
  if (bundle.type === "json") return JSON.stringify(bundle.data, null, 2);
  if (bundle.type === "markdown" || bundle.type === "status" || bundle.type === "text") return String(bundle.data ?? "");
  if (bundle.type === "image") {
    const dims = bundle.width && bundle.height ? ` ${bundle.width}x${bundle.height}` : "";
    return `[image ${bundle.mime ?? "image/*"}${dims}]`;
  }
  return String(bundle.data ?? "");
}
