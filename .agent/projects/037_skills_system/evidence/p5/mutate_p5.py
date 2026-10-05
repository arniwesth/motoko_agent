#!/usr/bin/env python3
"""037 P5 mutation check: is `make verify_skills_refusal` able to fail?

One source change at a time is applied to a tracked file, the fixture suite is
run, the rows that FAIL are recorded, and the file is restored byte for byte.
A mutant is killed when the suite exits non-zero. The last column of the table
says which rows were expected to notice, so a mutant killed by the wrong rows
shows.

Run from the worktree root, on a clean tree, with nothing else running in it
(the mutants change files other runs would read):

  python3 .agent/projects/037_skills_system/evidence/p5/mutate_p5.py <out.tsv> [ids...]
"""
import re, subprocess, sys

OUT = sys.argv[1]
ONLY = set(sys.argv[2:])
HOST = "src/core/ext/registry_normalize.ail"
GEN = "src/core/ext/registry_generated.ail"
REG = "packages/motoko-ext-skills/register.ail"
PROFILE = ".motoko/config/skills/config.json"

EVENT = '''              let _ = println(encode(jo([
                kv("type", js("error")),
                kv("message", js("extension registry rejected: ${rejection_message(e)}"))])));
              let _ = exit(2);'''

M = [
 # (id, file, what it breaks, old, new, the rows expected to fail)
 ("h01", HOST, "the host reads another key: a host that ignores the refusal",
  '  tests [((), "registration_refusal")]\n  { "registration_refusal" }',
  '  tests [((), "registration_refusal")]\n  { "registration_refusal_x" }',
  "every refused row (startup continued)"),
 ("h02", GEN, "the rejection exits 3",
  EVENT, EVENT.replace("exit(2)", "exit(3)"),
  "every refused row (exit 3, expected 2)"),
 ("h03", GEN, "the rejection is printed twice",
  EVENT, EVENT.replace("              let _ = exit(2);", '''              let _ = println(encode(jo([
                kv("type", js("error")),
                kv("message", js("extension registry rejected: ${rejection_message(e)}"))])));
              let _ = exit(2);'''),
  "every refused row (2 error events)"),
 ("h04", GEN, "the rejection is a bare line, not a JSONL event",
  EVENT, '''              let _ = println("extension registry rejected: ${rejection_message(e)}");
              let _ = exit(2);''',
  "every refused row (0 error events)"),
 ("e01", REG, "the extension never writes the refusal",
  'if refusal == "" then [] else [kv(registration_refusal_key(), js(refusal))]', "[]",
  "every refused row (startup continued)"),
 ("e02", REG, "a root that is a symlink out reads as no root (the v0.1 behaviour)",
  "  else if root_is_listed() then RootIsNeither", "  else if root_is_listed() then RootAbsent",
  "the three R1 symlink rows"),
 ("e03", REG, "an entry that is neither file nor directory is ignored",
  "  else OtherEntry(entry)\n", "  else RegularFile(entry)\n",
  "the V2 row"),
 ("e04", REG, "SKILL.md is found by reading it, not in the listing",
  "(if has_skill_md(listDir(path)) then", "(if true then",
  "the two V1 rows"),
 ("e05", REG, "the enum is dropped",
  '      kv("description", js("The name of the skill to load, exactly as listed.")),\n      kv("enum", ja(map(js, names)))',
  '      kv("description", js("The name of the skill to load, exactly as listed."))',
  "the A1 enum row"),
 ("e06", REG, "the index is not in config: the catalogue is rendered from an empty list",
  '    kv("skills", ja(map(skill_json, scanned_skills(result)))),', '    kv("skills", ja([])),',
  "the three A1 rows of the valid set, and A2's rows where the digest must move"),
 ("c01", HOST, "the config digest does not cover config",
  'jo([kv("config", config), kv("atoms", ja(atoms_data(caps)))])', 'jo([kv("atoms", ja(atoms_data(caps)))])',
  "A2's four rows where the digest must move"),
 ("p01", PROFILE, "the committed profile `skills` does not name skills",
  '"compaction_structural", "skills"]', '"compaction_structural"]',
  "the two rows of the committed profile"),
]

def run_suite():
    p = subprocess.run(["bash", "scripts/verify_skills_refusal.sh"], capture_output=True, text=True)
    lines = p.stdout.splitlines()
    fails = [re.sub(r"^FAIL\s+", "", l) for l in lines if l.startswith("FAIL")]
    oks = sum(1 for l in lines if l.startswith("OK"))
    return p.returncode, oks, fails

def short(f):
    # the row's label, without the reasons after the first colon that follows it
    f = re.sub(r"^(refused|started|A2)\s+", r"\1 ", f.strip())
    if f.startswith("A1: "):
        return "A1: " + f[4:].split(":")[0][:70]
    return f.split(": ")[0][:70]

rows = []
for mid, path, what, old, new, expect in M:
    if ONLY and mid not in ONLY:
        continue
    orig = open(path, encoding="utf-8").read()
    if orig.count(old) != 1:
        rows.append((mid, path, what, "NOT APPLIED", "", "", "old text occurs %d times" % orig.count(old), expect))
        continue
    try:
        open(path, "w", encoding="utf-8").write(orig.replace(old, new))
        rc, oks, fails = run_suite()
    finally:
        open(path, "w", encoding="utf-8").write(orig)
    clean = subprocess.run(["git", "diff", "--quiet", "--", path]).returncode == 0
    killed = "killed" if rc != 0 else "SURVIVED"
    why = "; ".join(short(f) for f in fails[:4]) + (" ... (%d in all)" % len(fails) if len(fails) > 4 else "")
    rows.append((mid, path, what, killed if clean else killed + " (FILE NOT RESTORED)", str(rc), "%d ok, %d fail" % (oks, len(fails)), why, expect))
    print(rows[-1], flush=True)

with open(OUT, "w", encoding="utf-8") as f:
    f.write("id\tfile\tmutation\tresult\tsuite_exit\trows\tfailing_rows\texpected_to_notice\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
print("mutants: %d, killed: %d" % (len(rows), sum(1 for r in rows if r[3] == "killed")))
