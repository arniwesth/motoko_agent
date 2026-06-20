import { describe, expect, it } from "@jest/globals";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PythonKernel } from "./kernel-py.js";

// Well-formed 4x4 RGB PNG.
const PNG_4x4 =
  "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAP0lEQVR4nAE0AMv/AAAAABAgMCBAYDBgkABAgMBQoPBgwCBw4FAAgACAkCCwoEDgsGAQAMCAQNCgcODAoPDg0MHDFgGB5uiKAAAAAElFTkSuQmCC";

function workdir(): string {
  return mkdtempSync(join(tmpdir(), "motoko-py-kernel-"));
}

describe("PythonKernel image display capture", () => {
  it("treats data-URL img strings as image display bundles", async () => {
    const kernel = new PythonKernel({});
    try {
      const result = await kernel.run(0, {
        title: "data url image",
        cwd: workdir(),
        timeoutMs: 5000,
        code: `display('<img src="data:image/png;base64,${PNG_4x4}" />')`,
      });

      expect(result.exit_code).toBe(0);
      expect(result.displays).toHaveLength(1);
      expect(result.displays[0]).toMatchObject({ type: "image", mime: "image/png", data: PNG_4x4 });
    } finally {
      kernel.close();
    }
  });

  it("auto-emits open matplotlib figures so plt.show() renders in-session", async () => {
    const kernel = new PythonKernel({});
    try {
      const availability = await kernel.run(0, {
        title: "matplotlib available",
        cwd: workdir(),
        timeoutMs: 5000,
        code: "import importlib.util\nimportlib.util.find_spec('matplotlib') is not None",
      });
      if (availability.result?.type !== "json" || availability.result.data !== true) return;

      const result = await kernel.run(1, {
        title: "plot",
        cwd: workdir(),
        timeoutMs: 10000,
        code: [
          "import matplotlib",
          "matplotlib.use('Agg')",
          "import matplotlib.pyplot as plt",
          "plt.figure()",
          "plt.plot([0, 1, 2], [0, 1, 0])",
          "plt.show()",
        ].join("\n"),
      });

      expect(result.exit_code).toBe(0);
      expect(result.displays.some((d) => d.type === "image" && d.mime === "image/png" && typeof d.data === "string")).toBe(true);
    } finally {
      kernel.close();
    }
  });
});
