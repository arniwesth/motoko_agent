import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { systemPromptForWorkspace, materializeSystemPromptArg } from "./system-prompt.js";
import { buildChildEnv, buildSupervisorArgs } from "./runtime-process.js";

let workdir: string;
let savedEnv: string | undefined;
let savedArgv: string[];

beforeEach(() => {
  workdir = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-"));
  savedEnv = process.env.SYSTEM_MD; // ADR-003 harness discipline
  savedArgv = process.argv;
});

afterEach(() => {
  if (savedEnv === undefined) delete process.env.SYSTEM_MD;
  else process.env.SYSTEM_MD = savedEnv;
  process.argv = savedArgv;
  fs.rmSync(workdir, { recursive: true, force: true });
});

// Scenario 4 — crit 3: prompt reaches the child by reference; SYSTEM_MD never
// rides the child env; the sandbox is the workdir.
describe("harness.child_env_sandbox_and_prompt_by_reference", () => {
  it("sets AILANG_FS_SANDBOX to workdir, omits SYSTEM_MD, and carries prompt by reference", () => {
    // Sentinel proves the parent's SYSTEM_MD is NOT forwarded, not merely unset.
    process.env.SYSTEM_MD = "/tmp/leak-sentinel.md";

    const childEnv = buildChildEnv(workdir, "someprofile", "", "");
    expect(childEnv.AILANG_FS_SANDBOX).toBe(workdir);
    expect("SYSTEM_MD" in childEnv).toBe(false);

    const args = buildSupervisorArgs(
      "someprofile",
      "some/model",
      workdir,
      12345,
      "prompt.md",
      "do a task",
    );
    const idx = args.indexOf("--system-prompt");
    expect(idx).toBeGreaterThanOrEqual(0);
    expect(args[idx + 1]).toBe("prompt.md");

    const argsEmpty = buildSupervisorArgs(
      "someprofile",
      "some/model",
      workdir,
      12345,
      "",
      "do a task",
    );
    expect(argsEmpty.indexOf("--system-prompt")).toBe(-1);
  });
});

// Scenario 1 — crit 2: the shipped #76 fix IS materialization.
describe("harness.external_system_md_materialized", () => {
  it("materializes an out-of-workspace source into workdir with byte-equal content", () => {
    const extDir = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-ext-"));
    const srcPath = path.join(extDir, "external.md");
    const content = "line one\nline two\n";
    fs.writeFileSync(srcPath, content, "utf8"); // absolute source path (trap: resolve vs cwd)

    const dest = materializeSystemPromptArg(srcPath, workdir);

    expect(dest).not.toBeNull();
    const destAbs = path.resolve(workdir, ".motoko-system-prompt.md");
    expect(dest).toBe(destAbs);
    expect(fs.readFileSync(dest!, "utf8")).toBe(content); // contract: byte-equality
    // dest inside workdir
    const rel = path.relative(path.resolve(workdir), dest!);
    expect(rel.startsWith("..")).toBe(false);
    expect(path.isAbsolute(rel)).toBe(false);
    // source genuinely outside workdir yet still captured (contract)
    expect(path.relative(workdir, srcPath).startsWith("..")).toBe(true);

    fs.rmSync(extDir, { recursive: true, force: true });
  });
});

// Scenario 2 — an in-workspace prompt is delivered by reference, not rewritten.
describe("harness.workspace_system_md_not_rewritten", () => {
  it("returns the in-workspace SYSTEM_MD path unchanged and writes no managed file", () => {
    const inFile = path.join(workdir, "prompt.md");
    fs.writeFileSync(inFile, "workspace prompt\n", "utf8");
    process.env.SYSTEM_MD = "prompt.md"; // workdir-relative; no --system-prompt in argv
    const result = systemPromptForWorkspace(workdir, workdir);
    expect(result).toBe("prompt.md");
    expect(fs.existsSync(path.join(workdir, ".motoko-system-prompt.md"))).toBe(false);
  });

  it("returns '.' when SYSTEM_MD resolves to the workdir directory itself", () => {
    process.env.SYSTEM_MD = path.resolve(workdir); // absolute == workdir
    const result = systemPromptForWorkspace(workdir, workdir);
    expect(result).toBe("."); // the one non-obvious return (rel === "")
  });
});

// Scenario 3 — crit 4: host resolves to empty / null on missing / escaping input.
// ADR-003 Finding 5: the LOUD rejection lives in-core and is ABSENT in headless
// mode; this Layer-2 scenario is the operative guard there.
describe("harness.out_of_sandbox_or_missing_system_md_yields_empty", () => {
  it("returns '' for a missing in-workdir SYSTEM_MD", () => {
    process.env.SYSTEM_MD = path.join(workdir, "does-not-exist.md");
    const result = systemPromptForWorkspace(workdir, workdir);
    expect(result).toBe("");
  });

  it("returns '' for an existing out-of-sandbox SYSTEM_MD (sandbox escape)", () => {
    // The escaping file MUST exist — else the missing branch fires first and the
    // escape branch is never exercised (both return "", test passes for wrong reason).
    const escapeDir = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-escape-"));
    const escapeFile = path.join(escapeDir, "escape.md");
    fs.writeFileSync(escapeFile, "escaping content\n", "utf8");
    process.env.SYSTEM_MD = escapeFile; // absolute, outside workdir
    const result = systemPromptForWorkspace(workdir, workdir);
    expect(result).toBe("");
    fs.rmSync(escapeDir, { recursive: true, force: true });
  });

  it("returns null for an unreadable materialization source", () => {
    const missing = path.join(workdir, "nope.md");
    const result = materializeSystemPromptArg(missing, workdir);
    expect(result).toBeNull();
  });
});
