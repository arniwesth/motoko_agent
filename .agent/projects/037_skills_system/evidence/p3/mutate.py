#!/usr/bin/env python3
"""037 P3 mutation check: apply one source mutation at a time to the skills
package, run its inline tests, and record whether a test failed. Restores the
file after every mutant. Run from the worktree root."""
import os, re, subprocess, sys, time

PKG = "packages/motoko-ext-skills"
OUT = sys.argv[1]

M = [
 # (id, file, old, new, which test files to run)
 ("m01 V7 limit is >= instead of >", "skills.ail", "if n > envelope_max_chars() then", "if n >= envelope_max_chars() then", ["skills.ail"]),
 ("m02 V7 limit 60000 -> 60001", "skills.ail", "export pure func envelope_max_chars() -> int { 60000 }", "export pure func envelope_max_chars() -> int { 60001 }", ["skills.ail"]),
 ("m03 V8 budget is >= instead of >", "skills.ail", "if n > index_budget_chars() then", "if n >= index_budget_chars() then", ["skills.ail"]),
 ("m04 size check is > 25 instead of >= 25", "skills.ail", "else if tokens * 100 / declared_limit >= size_check_pct() then", "else if tokens * 100 / declared_limit > size_check_pct() then", ["skills.ail"]),
 ("m05 size check at 30 instead of 25", "skills.ail", "export pure func size_check_pct() -> int { 25 }", "export pure func size_check_pct() -> int { 30 }", ["skills.ail"]),
 ("m06 unknown limit (0) no longer loads", "skills.ail", "if declared_limit <= 0 then SizeFits", "if declared_limit < 0 then SizeFits", ["skills.ail"]),
 ("m07 tokens rounded down", "skills.ail", "{ (char_count + 3) / 4 }", "{ char_count / 4 }", ["skills.ail"]),
 ("m08 byte-order mark not ignored", "skills.ail", 'if startsWith(text, "\\u{FEFF}") then substring(text, 1, length(text)) else text', "text", ["skills.ail"]),
 ("m09 delimiter does not tolerate CR", "skills.ail", 'line == "---" || line == "---\\r"', 'line == "---"', ["skills.ail"]),
 ("m10 block ends at the LAST delimiter", "skills.ail", "else if w.opened && w.stop < 0 && is_delimiter(line) then", "else if w.opened && is_delimiter(line) then", ["skills.ail"]),
 ("m11 name limit is >= 64", "skills.ail", "{ broken: n > name_max_chars(), text: concat", "{ broken: n >= name_max_chars(), text: concat", ["skills.ail"]),
 ("m12 name admits upper case", "skills.ail", "(code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code == 45", "(code >= 97 && code <= 122) || (code >= 65 && code <= 90) || (code >= 48 && code <= 57) || code == 45", ["skills.ail"]),
 ("m13 name need not match the directory", "skills.ail", "{ broken: s != dir_name, text: concat", "{ broken: false, text: concat", ["skills.ail"]),
 ("m14 leading hyphen allowed", "skills.ail", '{ broken: startsWith(skill_name, "-"), text: "starts with a hyphen" }', '{ broken: false, text: "starts with a hyphen" }', ["skills.ail"]),
 ("m15 trailing hyphen allowed", "skills.ail", '{ broken: n > 1 && endsWith(skill_name, "-"), text: "ends with a hyphen" }', '{ broken: false, text: "ends with a hyphen" }', ["skills.ail"]),
 ("m16 doubled hyphen allowed", "skills.ail", '{ broken: contains(skill_name, "--"), text: "has a doubled hyphen" }', '{ broken: false, text: "has a doubled hyphen" }', ["skills.ail"]),
 ("m17 empty name allowed", "skills.ail", '{ broken: n == 0, text: "is empty" }', '{ broken: false, text: "is empty" }', ["skills.ail"]),
 ("m18 non-string name accepted", "skills.ail", 'Some(other) => [violation(V5, path, concat(["`name` is not a string: it decodes as ", json_kind(other)]))]', "Some(other) => []", ["skills.ail"]),
 ("m19 digits-only (number) name accepted", "skills.ail", 'Some(JNumber(_)) => [violation(V5, path, "`name` is not a string: it decodes as a number, so a name made only of digits has to be quoted")]', "Some(JNumber(_)) => []", ["skills.ail"]),
 ("m20 description limit is >= 1024", "skills.ail", "else if length(s) > description_max_chars() then", "else if length(s) >= description_max_chars() then", ["skills.ail"]),
 ("m21 blank description accepted unless empty", "skills.ail", 'if trim(s) == "" then [violation(V6', 'if s == "" then [violation(V6', ["skills.ail"]),
 ("m22 non-string description accepted", "skills.ail", 'Some(other) => [violation(V6, path, concat(["`description` is not a string: it decodes as ", json_kind(other)]))]', "Some(other) => []", ["skills.ail"]),
 ("m23 missing description accepted", "skills.ail", 'None => [violation(V6, path, "`description` is missing")]', "None => []", ["skills.ail"]),
 ("m24 missing name accepted", "skills.ail", 'None => [violation(V5, path, "`name` is missing")]', "None => []", ["skills.ail"]),
 ("m25 non-mapping block accepted", "skills.ail", '_ => Err(concat(["the frontmatter block decodes to ", json_kind(j), ", not a mapping"]))', "_ => Ok(j)", ["skills.ail"]),
 ("m26 SKILL.md matched without exact case", "skills.ail", "seen || child == skill_md_name()", 'seen || child == skill_md_name() || child == "skill.md"', ["skills.ail"]),
 ("m27 V8 not checked at scan", "skills.ail", "let found = flatMap(outcome_violations, outcomes) ++ index_violations(skills);", "let found = flatMap(outcome_violations, outcomes);", ["skills.ail"]),
 ("m28 index not sorted", "skills.ail", "sortBy(compare_skill_names, skills)", "skills", ["skills.ail"]),
 ("m29 whitespace trimmed, not collapsed", "skills.ail", '{ join(" ", words(s)) }', "{ trim(s) }", ["skills.ail"]),
 ("m30 envelope field order changed", "skills.ail", '    kv("tool_call_id", js(env.tool_call_id)),\n    kv("tool", js(env.tool)),', '    kv("tool", js(env.tool)),\n    kv("tool_call_id", js(env.tool_call_id)),', ["skills.ail"]),
 ("m31 metadata not sanitized", "skills.ail", "JObject(fields) => JObject(filter(model_keeps_field, fields)),", "JObject(fields) => JObject(fields),", ["skills.ail"]),
 ("m32 V7 dropped when V4 fires", "skills.ail", "Err(detail) => Err(violation(V4, path, detail) :: size),", "Err(detail) => Err([violation(V4, path, detail)]),", ["skills.ail"]),
 ("m33 refusal numbering starts at 0", "skills.ail", "foldl(number_violation, { next: 1, text: \"\" }, found).text", "foldl(number_violation, { next: 0, text: \"\" }, found).text", ["skills.ail"]),
 ("m34 name order admits equal neighbours", "skills.ail", "compare(w.last, next) < 0", "compare(w.last, next) <= 0", ["skills.ail"]),
 ("m35 load skips the size check", "skills.ail", "SizeTooLarge(tokens, limit) => Err(size_error(dir_name, tokens, limit))", "SizeTooLarge(tokens, limit) => Ok(env)", ["skills.ail", "a6b_test.ail"]),
 ("m36 R1 (neither) read as no root", "skills.ail", 'RootIsNeither => Refused([violation(R1, skills_root(), "is neither a directory nor a regular file: a symlink that leaves the workdir, or has an absolute target, reads this way under the sandbox")]),', "RootIsNeither => Accepted([]),", ["skills.ail"]),
 ("m37 R1 (file) read as no root", "skills.ail", 'RootIsFile => Refused([violation(R1, skills_root(), "is a regular file, not a directory")]),', "RootIsFile => Accepted([]),", ["skills.ail"]),
 ("m38 V2 entry ignored", "skills.ail", 'OtherEntry(n) => { skills: [], violations: [violation(V2, skill_dir(n), "is neither a regular file nor a directory (under the sandbox a symlink that leaves the workdir, or has an absolute target, reads this way)")] },', "OtherEntry(n) => { skills: [], violations: [] },", ["skills.ail"]),
 ("m39 V1 directory ignored", "skills.ail", 'DirWithoutSkillMd(n) => { skills: [], violations: [violation(V1, skill_dir(n), concat(["the directory has no ", skill_md_name(), " (exact case)"]))] },', "DirWithoutSkillMd(n) => { skills: [], violations: [] },", ["skills.ail"]),
 ("m40 V3 unreadable file ignored", "skills.ail", 'DirUnreadableSkillMd(n, why) => { skills: [], violations: [violation(V3, skill_md_path(n), concat(["cannot be read: ", why]))] },', "DirUnreadableSkillMd(n, why) => { skills: [], violations: [] },", ["skills.ail"]),
 ("m41 directory line dropped from the result", "skills.ail", 'concat([skill_dir(dir_name), "\\n", text])\n}', "text\n}", ["skills.ail", "a6b_test.ail"]),
 ("m42 regular root file refused", "skills.ail", "RegularFile(_) => { skills: [], violations: [] },", 'RegularFile(n) => { skills: [], violations: [violation(V2, skill_dir(n), "x")] },', ["skills.ail"]),
 ("m43 refusal key misspelled", "skills.ail", '{ "registration_refusal" }', '{ "registration_refused" }', ["skills.ail"]),
 ("m44 unterminated block read as a block", "skills.ail", "else if w.stop < 0 then Unterminated", "else if w.stop < 0 then Block(substring(body, w.start, length(body)))", ["skills.ail"]),
 ("m45 refusal message keeps newlines", "skills.ail", 'concat([rule_id(v.rule), ": ", v.path, ": ", collapse_whitespace(v.detail)])', 'concat([rule_id(v.rule), ": ", v.path, ": ", v.detail])', ["skills.ail"]),
 ("m46 a6b: working limit allowance off by one", "a6b_test.ail", "let effective = if declared <= 65536 then 0 else declared - 65536;", "let effective = if declared <= 65536 then 0 else declared - 65535;", ["a6b_test.ail"]),
 ("m47 a6b: working limit ignores the pinned prefix", "a6b_test.ail", "if effective <= pinned then 0 else effective - pinned", "effective", ["a6b_test.ail"]),
 ("m48 load returns the nominal id, not the call's", "skills.ail", "      let env = skill_result_envelope(call_id, dir_name, text);", "      let env = skill_result_envelope(nominal_call_id(), dir_name, text);", ["skills.ail", "a6b_test.ail"]),
 ("m49 undecodable block read as an empty mapping", "skills.ail", 'Err(why) => Err(concat(["the frontmatter block does not decode as YAML: ", why])),', "Err(why) => Ok(jo([])),", ["skills.ail"]),
 ("m50 a file with no block is decoded whole", "skills.ail", "if not w.opened then NoFrontmatter", "if not w.opened then Block(body)", ["skills.ail"]),
 ("m51 index line marker changed", "skills.ail", 'concat(["- ", s.name, ": ", collapse_whitespace(s.description)])', 'concat(["* ", s.name, ": ", collapse_whitespace(s.description)])', ["skills.ail"]),
 ("m52 no-skills description not used", "skills.ail", "    [] => no_skills_description(),\n", "    [] => skill_tool_instruction(),\n", ["skills.ail"]),
 ("m53 absent root refused", "skills.ail", "RootAbsent => Accepted([]),", 'RootAbsent => Refused([violation(R1, skills_root(), "absent")]),', ["skills.ail"]),
 ("m54 name excludes digits", "skills.ail", "(code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code == 45", "(code >= 97 && code <= 122) || code == 45", ["skills.ail"]),
 ("m55 V7 measured without the directory line's file text escaping (raw length)", "skills.ail", "  let n = envelope_message_chars(skill_result_envelope(nominal_call_id(), dir_name, text));", "  let n = length(text);", ["skills.ail"]),
]

def run_tests(files):
    killed_by = []
    for f in files:
        p = subprocess.run(["ailang", "test", "--no-color", f], cwd=PKG, capture_output=True, text=True, timeout=600)
        out = p.stdout + p.stderr
        m = re.search(r"(\d+) tests: (\d+) passed, (\d+) failed, (\d+) skipped", out)
        failed = [l.strip().split(" ")[1] for l in out.splitlines() if l.strip().startswith("✗ test_") or (l.strip().startswith("✗ ") and "_test_" in l)]
        if m:
            killed_by.append((f, p.returncode, m.group(0), failed))
        else:
            tail = " | ".join(l for l in out.splitlines()[-4:] if "content changed" not in l and "ailang lock" not in l)
            killed_by.append((f, p.returncode, "NO SUMMARY (does not compile or run): " + tail[:300], failed))
    return killed_by

rows = []
only = sys.argv[2:]  # optional ids
for mid, fname, old, new, files in M:
    if only and mid.split(" ")[0] not in only:
        continue
    path = os.path.join(PKG, fname)
    src = open(path, encoding="utf-8").read()
    n = src.count(old)
    if n != 1:
        rows.append((mid, "NOT APPLIED (pattern occurs %d times)" % n, ""))
        print(rows[-1], flush=True)
        continue
    try:
        open(path, "w", encoding="utf-8").write(src.replace(old, new))
        res = run_tests(files)
    finally:
        open(path, "w", encoding="utf-8").write(src)
    killed = any(rc != 0 for _, rc, _, _ in res)
    detail = "; ".join("%s exit %d: %s%s" % (f, rc, summ, (" [" + ", ".join(fl[:6]) + ("" if len(fl) <= 6 else ", +%d more" % (len(fl) - 6)) + "]") if fl else "") for f, rc, summ, fl in res)
    rows.append((mid, "KILLED" if killed else "SURVIVED", detail))
    print(rows[-1], flush=True)

with open(OUT, "a", encoding="utf-8") as fh:
    for mid, verdict, detail in rows:
        fh.write("%s\t%s\t%s\n" % (mid, verdict, detail))
print("done: %d mutants, %d killed, %d survived, %d not applied" % (len(rows), sum(r[1] == "KILLED" for r in rows), sum(r[1] == "SURVIVED" for r in rows), sum(r[1].startswith("NOT") for r in rows)))
