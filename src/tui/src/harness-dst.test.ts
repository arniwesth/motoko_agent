import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { systemPromptForWorkspace, materializeSystemPromptArg } from "./system-prompt.js";
import { buildChildEnv, buildSupervisorArgs, loaderProfileDir, RuntimeProcess, type AgentEvent } from "./runtime-process.js";

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

// PLAN-003 P3 Part 5: `--resume` reaches the child, before the task, and the workdir the header
// records reaches it too.
describe("resume.supervisor_args_and_workdir", () => {
  it("emits --resume and --resume-force before the task, which stays last", () => {
    const args = buildSupervisorArgs("p", "m", workdir, 1, "", "", { journalPath: "/s/journal.jsonl", force: true });
    const i = args.indexOf("--resume");
    expect(i).toBeGreaterThanOrEqual(0);
    expect(args[i + 1]).toBe("/s/journal.jsonl");
    expect(args[i + 2]).toBe("--resume-force");
    expect(args[args.length - 1]).toBe("");
    const unforced = buildSupervisorArgs("p", "m", workdir, 1, "", "", { journalPath: "/s/journal.jsonl" });
    expect(unforced.indexOf("--resume-force")).toBe(-1);
    const fresh = buildSupervisorArgs("p", "m", workdir, 1, "", "do a task");
    expect(fresh.indexOf("--resume")).toBe(-1);
    expect(fresh[fresh.length - 1]).toBe("do a task");
  });

  it("forwards the header's workdir string as MOTOKO_JOURNAL_WORKDIR, and leaves MOTOKO_WORKDIR alone", () => {
    const env = buildChildEnv(workdir, "p", "", "");
    expect(env.MOTOKO_JOURNAL_WORKDIR).toBe(workdir);
    // Extensions read MOTOKO_WORKDIR with "." as the default and compare what they derive from
    // it against the relative `--workdir`; setting it absolute refused every herdr Delegate.
    expect(env.MOTOKO_WORKDIR).toBeUndefined();
  });
});

// The child reads the profile through MOTOKO_PROFILE_DIR in places the loaded config does not
// reach: `context_usage.ail` for `agent.context_limit`, and six extensions for their own JSON. So
// the variable has to name the directory `config.ail`'s `resolve_profile_dir` loads: the
// per-profile directory when it holds a config.json, else the legacy flat .motoko/, else the
// per-profile path. It used to be the per-profile path always, and a flat config's
// `agent.context_limit` was loaded and never took effect (review of #239).
describe("profile_dir.child_env_names_the_directory_the_loader_reads", () => {
  let savedRepo: string | undefined;
  let savedBin: string | undefined;
  const extra: string[] = [];

  beforeEach(() => {
    savedRepo = process.env.MOTOKO_REPO;
    savedBin = process.env.AILANG_BIN;
    delete process.env.MOTOKO_REPO;
  });

  afterEach(() => {
    if (savedRepo === undefined) delete process.env.MOTOKO_REPO;
    else process.env.MOTOKO_REPO = savedRepo;
    if (savedBin === undefined) delete process.env.AILANG_BIN;
    else process.env.AILANG_BIN = savedBin;
    for (const dir of extra.splice(0)) fs.rmSync(dir, { recursive: true, force: true });
  });

  const writeConfig = (dir: string) => {
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, "config.json"), "{}\n", "utf8");
  };
  const perProfile = (profile: string) => path.resolve(workdir, ".motoko", "config", profile);
  const flat = () => path.resolve(workdir, ".motoko");

  it("is the per-profile directory when that holds a config.json, with or without a flat one", () => {
    writeConfig(perProfile("p"));
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(perProfile("p"));
    writeConfig(flat());
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(perProfile("p"));
  });

  it("is the flat .motoko directory when only the flat config exists", () => {
    writeConfig(flat());
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(flat());
    expect(loaderProfileDir(workdir, "p")).toBe(flat());
  });

  it("is the per-profile path when neither exists, as it was", () => {
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(perProfile("p"));
  });

  // The child's reads are pinned to the workdir, and the runtime refuses a path that goes through
  // any symlink below it, wherever the link points (its sandbox log says "escapes sandbox" for all
  // three shapes here). So for the loader such a per-profile config.json does not exist and the
  // flat one is taken. Seen on real launches: the host, following the link, exported the
  // per-profile directory, and the limit resolved `unknown`.
  const outsideFile = () => {
    const outside = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-outside-"));
    extra.push(outside);
    writeConfig(outside);
    return path.join(outside, "config.json");
  };
  const insideFile = () => {
    writeConfig(path.join(workdir, "elsewhere"));
    return path.join(workdir, "elsewhere", "config.json");
  };
  const flatThenNot = () => {
    // Without a flat config there is nothing else to name, so the per-profile path stands.
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(perProfile("p"));
    writeConfig(flat());
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(flat());
  };

  it("does not count a config.json that is a symlink to a file outside the workdir", () => {
    fs.mkdirSync(perProfile("p"), { recursive: true });
    fs.symlinkSync(outsideFile(), path.join(perProfile("p"), "config.json"));
    flatThenNot();
  });

  it("does not count a config.json that is a symlink to a file inside the workdir", () => {
    fs.mkdirSync(perProfile("p"), { recursive: true });
    fs.symlinkSync(insideFile(), path.join(perProfile("p"), "config.json"));
    flatThenNot();
  });

  it("does not count a regular config.json in a per-profile directory that is a symlink", () => {
    fs.mkdirSync(path.dirname(perProfile("p")), { recursive: true });
    fs.symlinkSync(path.dirname(insideFile()), perProfile("p"));
    flatThenNot();
  });

  // The same rule holds for the flat config: a link there does not exist for the loader either,
  // and with nothing else to name the per-profile path stands. The three shapes above all put the
  // link in the per-profile place, so a rule applied to that place alone passed them.
  it("does not count a flat config.json that is a symlink", () => {
    fs.mkdirSync(flat(), { recursive: true });
    fs.symlinkSync(insideFile(), path.join(flat(), "config.json"));
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(perProfile("p"));
  });

  // "Outside the workdir" is a first path component of exactly "..". A profile given as
  // "../../..personal" resolves to <workdir>/..personal, which is inside it and is what the
  // loader reads; a test on the prefix alone sent it to the flat config.
  it("counts a profile directory whose name merely starts with two dots", () => {
    writeConfig(path.join(workdir, "..personal"));
    writeConfig(flat());
    expect(buildChildEnv(workdir, "../../..personal", "", "").MOTOKO_PROFILE_DIR).toBe(path.resolve(workdir, "..personal"));
  });

  // The loader's third place. It is usually outside the workdir and unreadable, but a MOTOKO_REPO
  // inside the workdir is not, and then the loader takes its profile when nothing nearer is
  // readable. Nearer still wins, and a repo outside the workdir is not counted.
  it("is MOTOKO_REPO's profile when that is inside the workdir and nothing nearer is readable", () => {
    const repo = path.join(workdir, "repo");
    const fromRepo = path.resolve(repo, ".motoko", "config", "p");
    writeConfig(fromRepo);
    expect(loaderProfileDir(workdir, "p", repo)).toBe(fromRepo);
    expect(loaderProfileDir(workdir, "p", "repo")).toBe(fromRepo);
    expect(loaderProfileDir(workdir, "p", "")).toBe(perProfile("p"));
    writeConfig(flat());
    expect(loaderProfileDir(workdir, "p", repo)).toBe(flat());
  });

  it("does not count MOTOKO_REPO's profile when the repo is outside the workdir", () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-repo-"));
    extra.push(repo);
    writeConfig(path.join(repo, ".motoko", "config", "p"));
    expect(loaderProfileDir(workdir, "p", repo)).toBe(perProfile("p"));
  });

  // The sandbox is about what lies below the workdir: a workdir that is itself reached through a
  // symlink reads its files normally (checked on the runtime). The flat config is the one asked
  // about because the per-profile path is also the fallback, and a test that expected it would
  // pass with this rule broken.
  it("counts a config reached through a workdir that is itself a symlink", () => {
    const link = path.join(os.tmpdir(), `harness-dst-link-${process.pid}`);
    fs.symlinkSync(workdir, link);
    try {
      writeConfig(path.join(link, ".motoko"));
      expect(loaderProfileDir(link, "p")).toBe(path.resolve(link, ".motoko"));
    } finally {
      fs.rmSync(link, { force: true });
    }
  });

  /**
   * What a spawned child is actually given: its MOTOKO_PROFILE_DIR, and the `--profile` among its
   * arguments. A shell script stands in for the runtime and prints both.
   */
  function spawned(profile: string): Promise<{ dir: string; profileArg: string }> {
    const bin = path.join(workdir, "fake-ailang.sh");
    const script = [
      "#!/bin/sh",
      'profile=""',
      'while [ $# -gt 0 ]; do if [ "$1" = "--profile" ]; then profile="$2"; fi; shift; done',
      `printf '{"type":"warning","message":"%s|%s"}\\n' "$MOTOKO_PROFILE_DIR" "$profile"`,
    ].join("\n");
    fs.writeFileSync(bin, `${script}\n`, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    const events: AgentEvent[] = [];
    return new Promise((resolve) => {
      new RuntimeProcess(
        "task", "http://127.0.0.1:1", "test-model", workdir, profile, 1, "", "", "",
        (e) => events.push(e),
        () => {
          const said = (events.find((e) => e.type === "warning") as { message: string } | undefined)?.message ?? "|";
          const [dir, profileArg] = said.split("|");
          resolve({ dir, profileArg });
        },
      );
    });
  }
  const spawnedProfileDir = async (profile: string) => (await spawned(profile)).dir;

  it("reaches the spawned child as the flat directory", async () => {
    writeConfig(flat());
    expect(await spawnedProfileDir("p")).toBe(flat());
  });

  // The spawn mirrors MOTOKO_REPO's profile into the workdir first, and the loader prefers the
  // per-profile directory that mirror creates. The variable is asked for again after the mirrors;
  // taken before them it would still say "flat" here.
  it("is the mirrored per-profile directory once the spawn has mirrored the repo's profile", async () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-repo-"));
    extra.push(repo);
    writeConfig(path.join(repo, ".motoko", "config", "p"));
    writeConfig(flat());
    process.env.MOTOKO_REPO = repo;
    expect(buildChildEnv(workdir, "p", "", "").MOTOKO_PROFILE_DIR).toBe(flat());
    expect(await spawnedProfileDir("p")).toBe(perProfile("p"));
  });

  // The directory and the `--profile` the loader is given are two statements of one thing: the
  // loader builds its per-profile path from the argument. A constructor that exported the right
  // directory and passed some other profile name would have the loader read somewhere else.
  it("is the mirror of an absolute profile, under its basename, and the --profile says the same", async () => {
    const outside = fs.mkdtempSync(path.join(os.tmpdir(), "harness-dst-abs-"));
    extra.push(outside);
    const absolute = path.join(outside, "personal");
    writeConfig(absolute);
    const child = await spawned(absolute);
    expect(child.dir).toBe(perProfile("personal"));
    expect(child.profileArg).toBe("personal");
  });

  it("passes the profile it was given as --profile when nothing is mirrored", async () => {
    writeConfig(perProfile("p"));
    const child = await spawned("p");
    expect(child.dir).toBe(perProfile("p"));
    expect(child.profileArg).toBe("p");
  });

  // The mirror asks `fs.existsSync`, which follows a link, so it does not run when the workdir's
  // own per-profile config is a symlink. The loader cannot follow that link and, with no flat
  // config, takes the profile of a MOTOKO_REPO it can read.
  it("reaches the spawned child as MOTOKO_REPO's profile when the local config is an unreadable symlink", async () => {
    const repo = path.join(workdir, "repo");
    writeConfig(path.join(repo, ".motoko", "config", "p"));
    fs.mkdirSync(perProfile("p"), { recursive: true });
    fs.symlinkSync(insideFile(), path.join(perProfile("p"), "config.json"));
    process.env.MOTOKO_REPO = repo;
    expect(await spawnedProfileDir("p")).toBe(path.resolve(repo, ".motoko", "config", "p"));
  });
});
