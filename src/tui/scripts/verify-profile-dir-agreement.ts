// verify-profile-dir-agreement — `make verify_profile_dir_agreement`.
//
// The host tells the runtime where the profile is twice. `--workdir` and
// `--profile` go to the config loader, which picks a directory by its own rules
// (`config.ail`, `resolve_profile_dir`). MOTOKO_PROFILE_DIR goes to everything
// that reads the profile without the loaded config: the context-limit resolver
// and six extensions. When the two name different directories, part of a profile
// is silently not read (review of #239; PR #241).
//
// `loaderProfileDir` in runtime-process.ts restates the loader's rules on the
// host, including what the runtime's FS sandbox will let the loader see. A
// restatement can drift, on either side and when AILANG changes its sandbox.
// The host tests assert the variable's value against a shell script standing in
// for the runtime, so they cannot notice. This asks both sides for real, and it
// asks them through the spawn itself:
//
//   A real `RuntimeProcess` is constructed for each layout below, so the
//   mirrors run and the environment and arguments are the ones a launch gets.
//   Its "ailang" is a wrapper that takes the `--workdir` and `--profile` it was
//   handed and runs the runtime's own loader with them, under the environment
//   it was handed (scripts/verify_profile_dir_agreement.ail, which imports only
//   `config`). The wrapper reports the loader's directory, its own
//   MOTOKO_PROFILE_DIR, and the loader's exit status.
//
// A layout passes when the loader exited 0, the two directories are the same,
// and that directory is the one the layout says it should be.
//
// One control runs first. The loader does not read MOTOKO_PROFILE_DIR, so run
// with that variable pointing nowhere it must still name the real directory. A
// stand-in that only echoes the variable back would make every layout "agree";
// the control is what tells it from the runtime.
//
// Not covered: a workdir beneath the host's cwd, where the loader finds no
// profile at all (#242). That layout belongs here once it is fixed; today it
// would be red for a reason this gate is not about.

import { spawnSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { RuntimeProcess, type AgentEvent } from "../src/runtime-process.js";

const repoRoot = path.resolve(import.meta.dirname, "..", "..", "..");
const PROBE = "scripts/verify_profile_dir_agreement.ail";

type Layout = {
  name: string;
  /** Build the layout under `real` and say what the host is launched with and what it should give. */
  build: (real: string, scratch: string) => { workdir: string; profile?: string; repo?: string; want: string };
};

const writeConfig = (dir: string): string => {
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, "config.json");
  fs.writeFileSync(file, "{}\n", "utf8");
  return file;
};
const perProfile = (workdir: string, profile = "p") => path.join(workdir, ".motoko", "config", profile);
const flat = (workdir: string) => path.join(workdir, ".motoko");
const linkedConfig = (dir: string, target: string) => {
  fs.mkdirSync(dir, { recursive: true });
  fs.symlinkSync(target, path.join(dir, "config.json"));
};

const layouts: Layout[] = [
  { name: "a per-profile config",
    build: (w) => { writeConfig(perProfile(w)); return { workdir: w, want: perProfile(w) }; } },
  { name: "a flat config",
    build: (w) => { writeConfig(flat(w)); return { workdir: w, want: flat(w) }; } },
  { name: "both",
    build: (w) => { writeConfig(perProfile(w)); writeConfig(flat(w)); return { workdir: w, want: perProfile(w) }; } },
  { name: "neither",
    build: (w) => ({ workdir: w, want: perProfile(w) }) },
  { name: "a flat config, and a per-profile config.json that is a symlink to a file outside the workdir",
    build: (w, scratch) => {
      writeConfig(flat(w));
      linkedConfig(perProfile(w), writeConfig(path.join(scratch, "outside")));
      return { workdir: w, want: flat(w) };
    } },
  { name: "a flat config, and a per-profile config.json that is a symlink to a file inside the workdir",
    build: (w) => {
      writeConfig(flat(w));
      linkedConfig(perProfile(w), writeConfig(path.join(w, "elsewhere")));
      return { workdir: w, want: flat(w) };
    } },
  { name: "a flat config, and a per-profile directory that is a symlink",
    build: (w) => {
      writeConfig(flat(w));
      writeConfig(path.join(w, "elsewhere"));
      fs.mkdirSync(path.dirname(perProfile(w)), { recursive: true });
      fs.symlinkSync(path.join(w, "elsewhere"), perProfile(w));
      return { workdir: w, want: flat(w) };
    } },
  { name: "a per-profile config.json that is a symlink, and no flat config",
    build: (w) => {
      linkedConfig(perProfile(w), writeConfig(path.join(w, "elsewhere")));
      return { workdir: w, want: perProfile(w) };
    } },
  { name: "a flat config.json that is a symlink, and nothing else",
    build: (w) => {
      linkedConfig(flat(w), writeConfig(path.join(w, "elsewhere")));
      return { workdir: w, want: perProfile(w) };
    } },
  { name: "a flat config, in a workdir that is itself a symlink",
    build: (w, scratch) => {
      writeConfig(flat(w));
      const link = path.join(scratch, "workdir-link");
      fs.symlinkSync(w, link);
      return { workdir: link, want: flat(link) };
    } },
  { name: "a flat config, and a profile directory whose name starts with two dots",
    build: (w) => {
      writeConfig(flat(w));
      writeConfig(path.join(w, "..personal"));
      return { workdir: w, profile: "../../..personal", want: path.join(w, "..personal") };
    } },
  { name: "MOTOKO_REPO outside the workdir holds the profile (the spawn mirrors it)",
    build: (w, scratch) => {
      const repo = path.join(scratch, "repo");
      writeConfig(perProfile(repo));
      return { workdir: w, repo, want: perProfile(w) };
    } },
  { name: "MOTOKO_REPO inside the workdir holds the profile (the spawn mirrors it)",
    build: (w) => {
      const repo = path.join(w, "repo");
      writeConfig(perProfile(repo));
      return { workdir: w, repo, want: perProfile(w) };
    } },
  { name: "MOTOKO_REPO inside the workdir, and a local per-profile config.json that is a symlink",
    build: (w) => {
      const repo = path.join(w, "repo");
      writeConfig(perProfile(repo));
      linkedConfig(perProfile(w), writeConfig(path.join(w, "elsewhere")));
      return { workdir: w, repo, want: perProfile(repo) };
    } },
];

function realAilang(): string | null {
  const named = (process.env.AILANG_BIN ?? "").trim();
  if (named !== "") return named;
  const found = spawnSync("sh", ["-c", "command -v ailang"], { encoding: "utf8" });
  const where = (found.stdout ?? "").trim();
  return found.status === 0 && where !== "" ? where : null;
}

/**
 * The stand-in "ailang" the spawn runs. It is handed `run ... supervisor.ail -- <supervisor args>`;
 * it takes `--workdir` and `--profile` from those, runs the real loader with them in the
 * environment it was given, and says what came back on the wire the host reads.
 */
function writeWrapper(file: string, ailang: string): void {
  const script = [
    "#!/bin/sh",
    'workdir=""; profile=""; past=0',
    "while [ $# -gt 0 ]; do",
    '  if [ "$past" = 0 ]; then [ "$1" = "--" ] && past=1; shift; continue; fi',
    '  case "$1" in',
    '    --workdir) workdir="$2"; shift 2 ;;',
    '    --profile) profile="$2"; shift 2 ;;',
    "    *) shift ;;",
    "  esac",
    "done",
    `out=$(AILANG_RELAX_MODULES=1 '${ailang}' run --caps IO,Env,FS --entry main ${PROBE} -- "$workdir" "$profile" 2>/dev/null)`,
    "status=$?",
    "loaded=$(printf '%s\\n' \"$out\" | sed -n 's/^PROFILE_DIR //p' | head -n 1)",
    `printf '{"type":"warning","message":"AGREEMENT|%s|%s|%s"}\\n' "$status" "$MOTOKO_PROFILE_DIR" "$loaded"`,
  ].join("\n");
  fs.writeFileSync(file, `${script}\n`, { mode: 0o755 });
}

/**
 * The control: asked directly, with MOTOKO_PROFILE_DIR set to a directory that does not exist, the
 * loader names the per-profile directory of a workdir that holds a per-profile config. Null when
 * it does. The per-profile place and not the flat one, so that the control depends on the
 * loader's first rule only and a change to any later rule is reported by the layouts, by name.
 */
function controlFailure(ailang: string): string | null {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "profile-dir-agreement-"));
  try {
    const workdir = path.join(scratch, "workdir");
    writeConfig(perProfile(workdir));
    const decoy = path.join(scratch, "not-a-profile-dir");
    const run = spawnSync(
      ailang,
      ["run", "--caps", "IO,Env,FS", "--entry", "main", PROBE, "--", workdir, "p"],
      {
        cwd: repoRoot,
        encoding: "utf8",
        timeout: 120_000,
        env: { ...process.env, AILANG_RELAX_MODULES: "1", AILANG_FS_SANDBOX: workdir, MOTOKO_PROFILE_DIR: decoy, MOTOKO_REPO: "" },
      },
    );
    const line = (run.stdout ?? "").split("\n").find((l) => l.startsWith("PROFILE_DIR "));
    const loaded = line === undefined ? "" : path.resolve(workdir, line.slice("PROFILE_DIR ".length).trim());
    if (run.status !== 0 || loaded === "") return `the loader did not run to the end (exit ${run.status})`;
    if (loaded === path.resolve(decoy)) return "the \"loader\" answered with MOTOKO_PROFILE_DIR itself, so it is not the runtime's loader";
    if (loaded !== path.resolve(perProfile(workdir))) return `the loader names ${loaded} for a workdir holding only a per-profile config`;
    return null;
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

type Answer = { status: string; exported: string; loaded: string };

function launch(workdir: string, profile: string): Promise<Answer | null> {
  const events: AgentEvent[] = [];
  return new Promise((resolve) => {
    new RuntimeProcess(
      "task", "http://127.0.0.1:1", "gate-model", workdir, profile, 1, "", "", "",
      (e) => events.push(e),
      () => {
        const said = events
          .map((e) => (e.type === "warning" ? e.message : ""))
          .find((m) => m.startsWith("AGREEMENT|"));
        if (said === undefined) return resolve(null);
        const [, status, exported, loaded] = said.split("|");
        resolve({ status, exported, loaded });
      },
    );
  });
}

async function main(): Promise<number> {
  // The host runs from the repo root (scripts/run-agent.sh): the child inherits that cwd and the
  // `--workdir` it is given is relative to it.
  process.chdir(repoRoot);
  const ailang = realAilang();
  if (ailang === null) {
    console.log("FAIL no ailang: set AILANG_BIN or put ailang on PATH; this gate runs the runtime's own loader");
    return 1;
  }
  const control = controlFailure(ailang);
  if (control !== null) {
    console.log(`FAIL control: ${control}`);
    console.log("verify_profile_dir_agreement: the control failed, so no layout was asked");
    return 1;
  }
  console.log("OK control: the loader's answer does not come from MOTOKO_PROFILE_DIR");
  const savedRepo = process.env.MOTOKO_REPO;
  let failed = 0;
  for (const layout of layouts) {
    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "profile-dir-agreement-"));
    try {
      const real = path.join(scratch, "workdir");
      fs.mkdirSync(real);
      const built = layout.build(real, scratch);
      const workdir = built.workdir;
      const wrapper = path.join(scratch, "ailang-loader.sh");
      writeWrapper(wrapper, ailang);
      process.env.AILANG_BIN = wrapper;
      if (built.repo === undefined) delete process.env.MOTOKO_REPO;
      else process.env.MOTOKO_REPO = built.repo;

      const answer = await launch(workdir, built.profile ?? "p");
      const shown = (dir: string) => path.relative(workdir, dir) || ".";
      const fail = (why: string) => {
        failed += 1;
        console.log(`FAIL ${layout.name}: ${why}`);
      };
      if (answer === null) {
        fail("the spawned child said nothing");
      } else if (answer.status !== "0" || answer.loaded === "") {
        fail(`the runtime's loader did not run to the end (exit ${answer.status}, directory '${answer.loaded}')`);
      } else {
        // Under AILANG_FS_SANDBOX a relative path is relative to the sandbox, which is the workdir.
        const loaded = path.resolve(workdir, answer.loaded);
        const exported = path.resolve(answer.exported);
        const wanted = path.resolve(built.want);
        if (exported !== loaded) {
          fail(`the host exports ${shown(exported)}, the runtime's loader reads ${shown(loaded)}`);
        } else if (exported !== wanted) {
          fail(`host and runtime agree on ${shown(exported)}, and this layout should give ${shown(wanted)}`);
        } else {
          console.log(`OK ${layout.name}: ${shown(exported)}`);
        }
      }
    } finally {
      fs.rmSync(scratch, { recursive: true, force: true });
    }
  }
  if (savedRepo === undefined) delete process.env.MOTOKO_REPO;
  else process.env.MOTOKO_REPO = savedRepo;

  if (failed > 0) {
    console.log(`verify_profile_dir_agreement: ${failed} of ${layouts.length} layouts fail; MOTOKO_PROFILE_DIR would name a directory the loader does not read`);
    return 1;
  }
  console.log(`verify_profile_dir_agreement: host and runtime agree on all ${layouts.length} layouts`);
  return 0;
}

main().then((code) => process.exit(code));
