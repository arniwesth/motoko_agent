#!/usr/bin/env python3
"""037 P4 mutation check: apply one source mutation at a time to register.ail,
then run what should notice it, and record whether it did. Restores the file
after every mutant.

Two detectors:
  tests   `ailang test --no-color register.ail` in the package directory; a
          mutant is killed when the run exits non-zero.
  probe   the discovery probe over the fixture workdirs (run_probe.sh); a
          mutant is killed when its output differs from the reference output
          of the unmutated file.

Run from the root of a tree where the skills package is wired into the root
manifest (the probe imports the package and src/core):

  python3 mutate_p4.py <out.tsv> <fixture base> <run_probe.sh> <probe .ail> <reference probe output> [ids...]
"""
import os, re, subprocess, sys

PKG = "packages/motoko-ext-skills"
OUT, FIX, RUNNER, PROBE, REF = sys.argv[1:6]
ROW = "{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Rand, Trace}"

M = [
 # (id and what it breaks, old, new, detector)
 ("r01 tool name misspelled in errors and the schema", '  { "Skill" }', '  { "Skills" }', "tests"),
 ("r02 every name counts as indexed", "foldl(\\seen n. seen || n == wanted, false, names)", "foldl(\\seen n. true, false, names)", "tests"),
 ("r03 no name counts as indexed", "foldl(\\seen n. seen || n == wanted, false, names)", "foldl(\\seen n. false, false, names)", "tests"),
 ("r04 config always records the sandbox as set", '    kv("sandbox_set", jb(sandbox_set))', '    kv("sandbox_set", jb(true))', "tests"),
 ("r05 refusal key written when there is no refusal", 'if refusal == "" then [] else [kv(registration_refusal_key(), js(refusal))]', "[kv(registration_refusal_key(), js(refusal))]", "tests"),
 ("r06 refusal never written to config", 'if refusal == "" then [] else [kv(registration_refusal_key(), js(refusal))]', "[]", "tests"),
 ("r07 a missing sandbox flag reads as set", "    Some(JBool(b)) => b,\n    _ => false", "    Some(JBool(b)) => b,\n    _ => true", "tests"),
 ("r08 a non-string refusal reads as none", "    Some(_) => malformed_refusal()", '    Some(_) => ""', "tests"),
 ("r09 index entry needs no description", "        Some(JString(d)) => [{ name: n, description: d }],\n        _ => []", '        Some(JString(d)) => [{ name: n, description: d }],\n        _ => [{ name: n, description: "" }]', "tests"),
 ("r10 refused catalogue uses the ordinary description", 'if config_refusal(cfg) != "" then refused_description()\n  else skill_tool_description(config_skills(cfg))', "skill_tool_description(config_skills(cfg))", "tests"),
 ("r11 refused catalogue keeps the enum", 'if config_refusal(cfg) != "" then [] else config_skills(cfg)', "config_skills(cfg)", "tests"),
 ("r12 enum dropped", '      kv("description", js("The name of the skill to load, exactly as listed.")),\n      kv("enum", ja(map(js, names)))', '      kv("description", js("The name of the skill to load, exactly as listed."))', "tests"),
 ("r13 name not required", '    kv("required", ja([js("name")]))', '    kv("required", ja([]))', "tests"),
 ("r14 unknown-name error does not list the names", '_ => concat(["Unknown skill \'", wanted, "\'. Valid names: ", join(", ", names), "."])', '_ => concat(["Unknown skill \'", wanted, "\'."])', "tests"),
 ("r15 tool errors exit 0", 'exit_code: 1, stdout: "", stderr: message', 'exit_code: 0, stdout: "", stderr: message', "tests"),
 ("r16 tool errors go to stdout", 'exit_code: 1, stdout: "", stderr: message', 'exit_code: 1, stdout: message, stderr: ""', "tests"),
 ("r17 unsandboxed launch check off", 'if config_sandbox_set(cfg) then false else workdir != "."', "false", "tests"),
 ("r18 launch check ignores the sandbox flag", 'if config_sandbox_set(cfg) then false else workdir != "."', 'workdir != "."', "tests"),
 ("r19 launch check passes any workdir but the empty one", 'if config_sandbox_set(cfg) then false else workdir != "."', 'if config_sandbox_set(cfg) then false else workdir == ""', "tests"),
 ("r20 launch check runs ahead of the refusal", '  if config_refusal(cfg) != "" then Answer(config_refusal(cfg))\n  else if launched_elsewhere(cfg, workdir) then Answer(unsandboxed_error(workdir))', '  if launched_elsewhere(cfg, workdir) then Answer(unsandboxed_error(workdir))\n  else if config_refusal(cfg) != "" then Answer(config_refusal(cfg))', "tests"),
 ("r21 a recorded refusal does not stop a call", '  if config_refusal(cfg) != "" then Answer(config_refusal(cfg))\n  else if launched_elsewhere', '  if false then Answer(config_refusal(cfg))\n  else if launched_elsewhere', "tests"),
 ("r22 name not checked against the index", "else if lists_name(skill_names(config_skills(cfg)), requested_name(arguments)) then ReadSkill(requested_name(arguments))", "else if true then ReadSkill(requested_name(arguments))", "tests"),
 ("r23 an absent file is validated as an empty one", "if not present then tool_error(call_id, gone_error(skill))\n  else match", "if false then tool_error(call_id, gone_error(skill))\n  else match", "tests"),
 ("r24 handler returns the world it was given", "        next_state: read.next_state\n", "        next_state: ctx.world\n", "tests"),
 ("r25 handler reads the directory, not SKILL.md", "let read = ctx.ports.file_read(ctx.world, skill_md_path(skill));", "let read = ctx.ports.file_read(ctx.world, skill_dir(skill));", "tests"),
 ("r26 size check never sees the context limit", "skill_answer(call.id, skill, read.present, read.content, ctx.context_limit)", "skill_answer(call.id, skill, read.present, read.content, 0)", "tests"),
 ("r27 result carries no call id", "skill_answer(call.id, skill, read.present, read.content, ctx.context_limit)", 'skill_answer("", skill, read.present, read.content, ctx.context_limit)', "tests"),
 ("r28 error path returns a changed world", "Answer(message) => { decision: Handled(tool_error(call.id, message)), next_state: ctx.world },", 'Answer(message) => { decision: Handled(tool_error(call.id, message)), next_state: { token: jo([]) } },', "tests"),
 ("r29 error path is Delegate, not a tool error", "Answer(message) => { decision: Handled(tool_error(call.id, message)), next_state: ctx.world },", "Answer(message) => { decision: Delegate, next_state: ctx.world },", "tests"),
 ("r30 a non-string name argument is used as text", "    Some(JString(s)) => s,\n    _ => \"\"\n  }\n}\n\n-- What a call is answered with", "    Some(JString(s)) => s,\n    _ => \"observer\"\n  }\n}\n\n-- What a call is answered with", "tests"),
 ("r31 root entry name misspelled", 'pure func skills_entry() -> string { "skills" }', 'pure func skills_entry() -> string { "skill" }', "tests"),
 # discovery and registration: the probe is the detector
 ("d01 SKILL.md found by reading, not by the listing", "(if has_skill_md(listDir(path)) then", "(if true then", "probe"),
 ("d02 a regular file in the root is an 'other' entry", "else if isFile(path) then RegularFile(entry)", "else if false then RegularFile(entry)", "probe"),
 ("d03 an entry that is neither is ignored (V2)", "  else OtherEntry(entry)\n", "  else RegularFile(entry)\n", "probe"),
 ("d04 an unreadable SKILL.md is read as missing (V3 as V1)", "        Err(why) => DirUnreadableSkillMd(entry, why)", "        Err(why) => DirWithoutSkillMd(entry)", "probe"),
 ("d05 a root that is a file is read as no root (R1)", "  else if isFile(skills_root()) then RootIsFile", "  else if isFile(skills_root()) then RootAbsent", "probe"),
 ("d06 a root that is neither is read as no root (R1)", "  else if root_is_listed() then RootIsNeither", "  else if false then RootIsNeither", "probe"),
 ("d07 the parent's listing is not consulted", "if isDir(skills_parent()) then lists_name(listDir(skills_parent()), skills_entry()) else false", "false", "probe"),
 ("d08 the first entry of the root is skipped", "    n :: rest => read_entry(n) :: read_entries(rest)", "    n :: rest => read_entries(rest)", "probe"),
 ("d09 sandbox flag inverted", 'let sandbox_set = getEnvOr(sandbox_variable(), "") != "";', 'let sandbox_set = getEnvOr(sandbox_variable(), "") == "";', "probe"),
 ("d10 sandbox variable misnamed", 'pure func sandbox_variable() -> string { "AILANG_FS_SANDBOX" }', 'pure func sandbox_variable() -> string { "AILANG_SANDBOX" }', "probe"),
 ("d11 registered tool name differs from the schema's", '      ToolProvider(["Skill"], skills_handle)', '      ToolProvider(["Skills"], skills_handle)', "probe"),
 ("d12 registration always records the sandbox as set", "    config: skills_config(found, sandbox_set),", "    config: skills_config(found, true),", "probe"),
 ("d13 root read from a different path", "  if isDir(skills_root()) then RootEntries(read_entries(listDir(skills_root())))", '  if isDir(".claude/skills") then RootEntries(read_entries(listDir(".claude/skills")))', "probe"),
 ("d14 an entry's kind is read from the root, not from the entry", "  if isDir(path) then", "  if isDir(skills_root()) then", "probe"),
]

def run_tests():
    p = subprocess.run(["ailang", "test", "--no-color", "register.ail"], cwd=PKG, capture_output=True, text=True, timeout=600)
    out = p.stdout + p.stderr
    m = re.search(r"(\d+) tests: (\d+) passed, (\d+) failed, (\d+) skipped", out)
    failed = [l.strip().split(" ")[1] for l in out.splitlines() if l.strip().startswith("✗ ") and "_test_" in l]
    if m:
        return p.returncode != 0, "tests exit %d: %s%s" % (p.returncode, m.group(0), (" [" + ", ".join(failed[:6]) + ("" if len(failed) <= 6 else ", +%d more" % (len(failed) - 6)) + "]") if failed else "")
    tail = " | ".join(l for l in out.splitlines()[-4:] if "content changed" not in l and "ailang lock" not in l)
    return p.returncode != 0, "tests exit %d: NO SUMMARY (does not compile or run): %s" % (p.returncode, tail[:300])

def run_probe():
    p = subprocess.run(["bash", RUNNER, FIX, PROBE], capture_output=True, text=True, timeout=900)
    got = (p.stdout + p.stderr).splitlines()
    ref = open(REF, encoding="utf-8").read().splitlines()
    if got == ref:
        return False, "probe output identical to the reference"
    cases, cur = [], None
    refcases, k = {}, None
    for l in ref:
        if l.startswith("CASE "): k = l; refcases[k] = []
        elif k: refcases[k].append(l)
    gotcases, k = {}, None
    for l in got:
        if l.startswith("CASE "): k = l; gotcases.setdefault(k + "#%d" % sum(1 for x in gotcases if x.startswith(k)), [])
    # count differing lines; name the first few cases that differ
    import difflib
    changed = [l for l in difflib.unified_diff(ref, got, lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
    first = next((l for l in changed if l.startswith("+")), changed[0] if changed else "")
    return True, "probe output differs from the reference in %d line(s); first: %s" % (len(changed), first[:260])

rows = []
only = sys.argv[6:]
path = os.path.join(PKG, "register.ail")
for mid, old, new, how in M:
    if only and mid.split(" ")[0] not in only:
        continue
    src = open(path, encoding="utf-8").read()
    n = src.count(old)
    if n != 1:
        rows.append((mid, "NOT APPLIED (pattern occurs %d times)" % n, "")); print(rows[-1], flush=True); continue
    try:
        open(path, "w", encoding="utf-8").write(src.replace(old, new))
        killed, detail = run_tests() if how == "tests" else run_probe()
    finally:
        open(path, "w", encoding="utf-8").write(src)
    rows.append((mid, "KILLED" if killed else "SURVIVED", detail)); print(rows[-1], flush=True)

with open(OUT, "a", encoding="utf-8") as fh:
    for r in rows:
        fh.write("%s\t%s\t%s\n" % r)
print("done: %d mutants, %d killed, %d survived, %d not applied" % (len(rows), sum(r[1] == "KILLED" for r in rows), sum(r[1] == "SURVIVED" for r in rows), sum(r[1].startswith("NOT") for r in rows)))
