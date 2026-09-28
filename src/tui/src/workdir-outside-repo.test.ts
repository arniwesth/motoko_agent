// #195 / #196: a WORKDIR outside the repo (an eval workspace) must still see
// the repo's profile and model catalogue.

import { afterEach, describe, expect, it } from "@jest/globals";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import path from "path";
import { resolveProfileConfigPath } from "./profiles.js";
import { mirrorModelCatalogFromRepo } from "./runtime-process.js";

const dirs: string[] = [];
function tmp(prefix: string): string {
  const d = mkdtempSync(path.join(tmpdir(), prefix));
  dirs.push(d);
  return d;
}
function write(file: string, content: string): void {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, content);
}

afterEach(() => {
  while (dirs.length > 0) rmSync(dirs.pop()!, { recursive: true, force: true });
});

describe("resolveProfileConfigPath (#195)", () => {
  it("prefers the workdir's profile", () => {
    const repo = tmp("repo-");
    const workdir = tmp("wd-");
    write(path.join(repo, ".motoko/config/eval/config.json"), "{}");
    write(path.join(workdir, ".motoko/config/eval/config.json"), "{}");
    expect(resolveProfileConfigPath(workdir, "eval", repo))
      .toBe(path.join(workdir, ".motoko/config/eval/config.json"));
  });

  it("falls back to MOTOKO_REPO when the workdir has none", () => {
    const repo = tmp("repo-");
    const workdir = tmp("wd-");
    write(path.join(repo, ".motoko/config/eval/config.json"), "{}");
    expect(resolveProfileConfigPath(workdir, "eval", repo))
      .toBe(path.join(repo, ".motoko/config/eval/config.json"));
  });

  it("returns null when neither has it, or MOTOKO_REPO is unset", () => {
    const repo = tmp("repo-");
    const workdir = tmp("wd-");
    expect(resolveProfileConfigPath(workdir, "eval", repo)).toBeNull();
    expect(resolveProfileConfigPath(workdir, "eval", "")).toBeNull();
  });

  it("uses an absolute profile as-is", () => {
    const abs = tmp("profile-");
    write(path.join(abs, "config.json"), "{}");
    expect(resolveProfileConfigPath(tmp("wd-"), abs, "")).toBe(path.join(abs, "config.json"));
  });
});

describe("mirrorModelCatalogFromRepo (#196)", () => {
  it("copies the repo catalogue into a workdir that has none", () => {
    const repo = tmp("repo-");
    const workdir = tmp("wd-");
    write(path.join(repo, ".motoko/model-catalog.json"), '{"context_limits":{"m":71}}');
    mirrorModelCatalogFromRepo(workdir, repo);
    expect(readFileSync(path.join(workdir, ".motoko/model-catalog.json"), "utf8"))
      .toBe('{"context_limits":{"m":71}}');
  });

  it("never overwrites the workdir's own catalogue", () => {
    const repo = tmp("repo-");
    const workdir = tmp("wd-");
    write(path.join(repo, ".motoko/model-catalog.json"), "repo");
    write(path.join(workdir, ".motoko/model-catalog.json"), "own");
    mirrorModelCatalogFromRepo(workdir, repo);
    expect(readFileSync(path.join(workdir, ".motoko/model-catalog.json"), "utf8")).toBe("own");
  });

  it("is a no-op without MOTOKO_REPO, without a repo catalogue, or when workdir is the repo", () => {
    const repo = tmp("repo-");
    const workdir = tmp("wd-");
    mirrorModelCatalogFromRepo(workdir, "");
    mirrorModelCatalogFromRepo(workdir, repo);
    expect(existsSync(path.join(workdir, ".motoko"))).toBe(false);
    mirrorModelCatalogFromRepo(repo, repo);
    expect(existsSync(path.join(repo, ".motoko"))).toBe(false);
  });
});
