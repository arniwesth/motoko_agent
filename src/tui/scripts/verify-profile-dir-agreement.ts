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
// for the runtime, so they cannot notice. This asks both sides for real:
//
//   host     the MOTOKO_PROFILE_DIR in the environment `buildChildEnv` builds
//   runtime  the directory the loader settles on, from
//            scripts/verify_profile_dir_agreement.ail, run under that same
//            environment with the `--workdir` the host would pass
//
// for each layout below, and fails unless they are the same directory and the
// one the layout says it should be. The runtime half imports only `config`, so
// a run takes well under a second.
//
// Not covered: a workdir beneath the host's cwd, where the loader finds no
// profile at all (#242). That layout belongs here once it is fixed; today it
// would be red for a reason this gate is not about.

import { spawnSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { buildChildEnv, supervisorWorkdirArg } from "../src/runtime-process.js";

const repoRoot = path.resolve(import.meta.dirname, "..", "..", "..");
const PROFILE = "p";
const PROBE = "scripts/verify_profile_dir_agreement.ail";

type Want = "per-profile" | "flat";
type Layout = {
  name: string;
  want: Want;
  /** Build the layout under `real`; return the path the host is given as WORKDIR. */
  build: (real: string, scratch: string) => string;
};

const writeConfig = (dir: string): string => {
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, "config.json");
  fs.writeFileSync(file, "{}\n", "utf8");
  return file;
};
const perProfile = (workdir: string) => path.join(workdir, ".motoko", "config", PROFILE);
const flat = (workdir: string) => path.join(workdir, ".motoko");

const layouts: Layout[] = [
  { name: "a per-profile config", want: "per-profile",
    build: (w) => { writeConfig(perProfile(w)); return w; } },
  { name: "a flat config", want: "flat",
    build: (w) => { writeConfig(flat(w)); return w; } },
  { name: "both", want: "per-profile",
    build: (w) => { writeConfig(perProfile(w)); writeConfig(flat(w)); return w; } },
  { name: "neither", want: "per-profile",
    build: (w) => w },
  { name: "a flat config, and a per-profile config.json that is a symlink to a file outside the workdir", want: "flat",
    build: (w, scratch) => {
      writeConfig(flat(w));
      fs.mkdirSync(perProfile(w), { recursive: true });
      fs.symlinkSync(writeConfig(path.join(scratch, "outside")), path.join(perProfile(w), "config.json"));
      return w;
    } },
  { name: "a flat config, and a per-profile config.json that is a symlink to a file inside the workdir", want: "flat",
    build: (w) => {
      writeConfig(flat(w));
      fs.mkdirSync(perProfile(w), { recursive: true });
      fs.symlinkSync(writeConfig(path.join(w, "elsewhere")), path.join(perProfile(w), "config.json"));
      return w;
    } },
  { name: "a flat config, and a per-profile directory that is a symlink", want: "flat",
    build: (w) => {
      writeConfig(flat(w));
      writeConfig(path.join(w, "elsewhere"));
      fs.mkdirSync(path.dirname(perProfile(w)), { recursive: true });
      fs.symlinkSync(path.join(w, "elsewhere"), perProfile(w));
      return w;
    } },
  { name: "a per-profile config.json that is a symlink, and no flat config", want: "per-profile",
    build: (w) => {
      fs.mkdirSync(perProfile(w), { recursive: true });
      fs.symlinkSync(writeConfig(path.join(w, "elsewhere")), path.join(perProfile(w), "config.json"));
      return w;
    } },
  { name: "a flat config, in a workdir that is itself a symlink", want: "flat",
    build: (w, scratch) => {
      writeConfig(flat(w));
      const link = path.join(scratch, "workdir-link");
      fs.symlinkSync(w, link);
      return link;
    } },
];

/** The directory the runtime's loader settles on, as an absolute path, or an error line. */
function runtimeProfileDir(workdir: string, env: NodeJS.ProcessEnv): { dir: string } | { error: string } {
  const bin = (process.env.AILANG_BIN ?? "").trim() || "ailang";
  const run = spawnSync(
    bin,
    ["run", "--caps", "IO,Env,FS", "--entry", "main", PROBE, "--", supervisorWorkdirArg(workdir), PROFILE],
    { cwd: repoRoot, env: { ...env, AILANG_RELAX_MODULES: "1" }, encoding: "utf8", timeout: 120_000 },
  );
  if (run.error) return { error: `could not run ${bin}: ${run.error.message}` };
  const line = (run.stdout ?? "").split("\n").find((l) => l.startsWith("PROFILE_DIR "));
  if (line === undefined) {
    const tail = `${run.stdout ?? ""}${run.stderr ?? ""}`.trim().split("\n").slice(-3).join(" / ");
    return { error: `the runtime printed no PROFILE_DIR line (exit ${run.status}): ${tail}` };
  }
  // Under AILANG_FS_SANDBOX a relative path is relative to the sandbox, which is the workdir.
  return { dir: path.resolve(workdir, line.slice("PROFILE_DIR ".length).trim()) };
}

function main(): number {
  // The host runs from the repo root (scripts/run-agent.sh), and `supervisorWorkdirArg` is
  // relative to the cwd. MOTOKO_REPO is the loader's third place; these layouts are about the
  // first two, so an ambient one is taken out.
  process.chdir(repoRoot);
  delete process.env.MOTOKO_REPO;

  let failed = 0;
  for (const layout of layouts) {
    const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "profile-dir-agreement-"));
    try {
      const real = path.join(scratch, "workdir");
      fs.mkdirSync(real);
      const workdir = layout.build(real, scratch);
      const wanted = path.resolve(layout.want === "flat" ? flat(workdir) : perProfile(workdir));
      const env = buildChildEnv(workdir, PROFILE, "", "");
      const host = path.resolve(env.MOTOKO_PROFILE_DIR ?? "");
      const runtime = runtimeProfileDir(workdir, env);
      const shown = (dir: string) => path.relative(workdir, dir) || ".";
      if ("error" in runtime) {
        failed += 1;
        console.log(`FAIL ${layout.name}: ${runtime.error}`);
      } else if (host !== runtime.dir) {
        failed += 1;
        console.log(`FAIL ${layout.name}: the host exports ${shown(host)}, the runtime's loader reads ${shown(runtime.dir)}`);
      } else if (host !== wanted) {
        failed += 1;
        console.log(`FAIL ${layout.name}: host and runtime agree on ${shown(host)}, and this layout should give ${shown(wanted)}`);
      } else {
        console.log(`OK ${layout.name}: ${shown(host)}`);
      }
    } finally {
      fs.rmSync(scratch, { recursive: true, force: true });
    }
  }
  if (failed > 0) {
    console.log(`verify_profile_dir_agreement: ${failed} of ${layouts.length} layouts disagree; MOTOKO_PROFILE_DIR would name a directory the loader does not read`);
    return 1;
  }
  console.log(`verify_profile_dir_agreement: host and runtime agree on all ${layouts.length} layouts`);
  return 0;
}

process.exit(main());
