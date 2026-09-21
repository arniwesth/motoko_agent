#!/usr/bin/env python3
"""031 PLAN-001 P1.2b: generate p12b_mutgate_spec.tsv (013 GATE-mutation-red-submission-precondition).
Generated rather than hand-typed so tabs, sed escapes and the ceiling rows (one per effect this part
added to an [effects].max) are exact. Every row's sed_expr is checked here to match its target
exactly once. Usage: p12b_mutgate_spec.py <tree_pass> <tree_bindings>  (run from the repo root)."""
import re, sys
E = ".agent/projects/031_system_one_decisions/evidence/P1.2b"
W = f"bash {E}/p12b_ws.sh"
ROOT = f"bash {E}/p12b_pkgroot.sh"
CORE = f"P11_RELAX=1 bash {E}/p12b_core_check.sh"
RG, TD, SP, EXA, CM = ("packages/motoko-ext-repetition-guard", "packages/motoko-ext-test-dummy",
                       "packages/motoko_scratchpad", "packages/motoko-ext-exa-search", "packages/motoko-ext-context-mode")
tree_pass, tree_bind = sys.argv[1], sys.argv[2]
rows = []  # (comment|None, fix, target, pattern, replacement, test_cmd, extra_sed)
def row(fix, target, pat, rep, cmd, extra=""):
    src = open(target).read()
    n = src.count(pat)
    assert n == 1, f"{fix}: pattern matches {n} times in {target}: {pat}"
    rows.append((fix, target, pat, rep, cmd, extra))
def comment(t): rows.append(("#", t))
def bre(s):  # a literal line fragment -> a sed BRE (and the Python regex used for the uniqueness check)
    return s
def esc_sed(s): return re.sub(r'([\[\]\.\*\^\$/])', r'\\\1', s)
def esc_rep(s): return s.replace('\\', '\\\\').replace('&', r'\&').replace('/', r'\/')

comment("--- the registration boundary: re-inline one payload per package -> the gate rejects -> red")
row("rg_inline", f"{RG}/register.ail", "      ToolPolicy(policy),", "      ToolPolicy(\\ctx call. policy(ctx, call)),", f"{W} gate repetition_guard")
row("td_inline", f"{TD}/register.ail", "      PromptShaper(dummy_prompt),", "      PromptShaper(\\ctx. dummy_prompt(ctx)),", f"{W} gate test_dummy")
row("sp_inline", f"{SP}/register.ail", "      DescribeTools(on_describe_tools),", "      DescribeTools(\\c. on_describe_tools(c)),", f"{W} gate scratchpad")
row("exa_inline", f"{EXA}/register.ail", "      PromptShaper(exa_prompt),", "      PromptShaper(\\ctx. exa_prompt(ctx)),", f"{W} gate exa_search")
row("cm_inline", f"{CM}/register.ail", "      SolverJudge(ctx_finalize)", "      SolverJudge(\\ctx c. ctx_finalize(ctx, c))", f"{W} gate context_mode")
comment(f"the tree reading at HEAD + these paths: shape pass {tree_pass} of 18, binding rejections {tree_bind}")
row("tree", f"{TD}/register.ail", "      BudgetShaper(dummy_budget),", "      BudgetShaper(\\ctx p. dummy_budget(ctx, p)),", f"{W} tree {tree_pass} {tree_bind}")

comment("--- every value moved into config (Amendment 3): read it from a module value instead of ext_config -> the channel probe -> red")
comment("    (each probe also runs the callback on an EMPTY config and requires the default, so a hard-wired value cannot pass)")
row("rg_calls", f"{RG}/register.ail", "decide_call_with_budget(ctx, call, call_budget_of(ctx.ext_config))", "decide_call_with_budget(ctx, call, 2)", f"{W} probe rg")
row("rg_answers", f"{RG}/register.ail", "candidate, answer_budget_of(ctx.ext_config))", "candidate, 1)", f"{W} probe rg")
row("td_marker", f"{TD}/register.ail", '    prompt_marker: string_or(cfg, "prompt_marker", ""),', '    prompt_marker: "P12B-MARK",', f"{W} probe td")
row("td_budget", f"{TD}/register.ail", '    budget_total: getInt(cfg, "budget_total")', '    budget_total: Some(17)', f"{W} probe td")
row("td_tool", f"{TD}/register.ail", '    tool_decision: string_or(cfg, "tool_decision", "noop"),', '    tool_decision: "deny",', f"{W} probe td")
row("td_finalize", f"{TD}/register.ail", '    finalize: string_or(cfg, "finalize", "noop"),', '    finalize: "accept",', f"{W} probe td")
row("sp_timeout", f"{SP}/register.ail", "on_tool_handle(ctx, call, timeout_secs_of(ctx.ext_config))", "on_tool_handle(ctx, call, 7)", f"{W} probe sp")
row("exa_prompt", f"{EXA}/register.ail", "on_build_system_prompt(cached_prompt_of(ctx.ext_config), ctx)", 'on_build_system_prompt("P12B-EXA-PROMPT\\n", ctx)', f"{W} probe exa")
row("exa_timeout", f"{EXA}/exa_search.ail", '    match getInt(cfg, "timeout_ms") { Some(n) => n, None => default_timeout_ms() },', '    7000,', f"{W} probe exa")
row("exa_maxchars", f"{EXA}/exa_search.ail", '    match getInt(cfg, "max_output_chars") { Some(n) => n, None => default_max_output_chars() })', '    600)', f"{W} probe exa")
row("cm_prompt", f"{CM}/register.ail", "on_build_system_prompt(cached_prompt_of(ctx.ext_config), ctx)", 'on_build_system_prompt("P12B-CM-PROMPT\\n", ctx)', f"{W} probe cm")
row("cm_bin", f"{CM}/types.ail", '    bin: match getString(j, "bin") { Some(v) => v, None => d.bin },', '    bin: "P12B-BIN",', f"{W} probe cm")
row("cm_timeout", f"{CM}/types.ail", '    timeout_ms: match getInt(j, "timeout_ms") { Some(n) => n, None => d.timeout_ms },', '    timeout_ms: 7000,', f"{W} probe cm")
row("cm_maxchars", f"{CM}/types.ail", '    max_output_chars: match getInt(j, "max_output_chars") { Some(n) => n, None => d.max_output_chars },', '    max_output_chars: 600,', f"{W} probe cm")
row("cm_prefix", f"{CM}/types.ail", '    snapshot_key_prefix: match getString(j, "snapshot_key_prefix") { Some(v) => v, None => d.snapshot_key_prefix }', '    snapshot_key_prefix: "p12b:pfx:"', f"{W} probe cm")
comment("the judge's own read of the shared record (the provider's is covered by the field rows above)")
row("cm_judge", f"{CM}/register.ail", "finalize_with_index(ctx_config_of(ctx.ext_config), ", 'finalize_with_index({ default_ctx_config() | bin: "P12B-BIN", timeout_ms: 7000 }, ', f"{W} probe cm")
comment("--- registration must disclose what it read; a credential never enters config")
row("rg_withheld", f"{RG}/register.ail", "    config: budget_config(calls, answers),", "    config: budget_config(call_budget(), answer_budget()),", f"{W} probe rg")
row("cm_withheld", f"{CM}/register.ail", "    config: ctx_config_json(cfg, cached_prompt),", "    config: ctx_config_json(default_ctx_config(), cached_prompt),", f"{W} probe cm")
row("exa_key_in_config", f"{EXA}/exa_search.ail", '    kv("cached_prompt", js(cached_prompt)),', '    kv("cached_prompt", js(cached_prompt)), kv("key", js("P12B-NOT-A-REAL-KEY")),', f"{W} probe exa")

comment("--- every effect added to an [effects].max (Amendment 2): drop it -> the own-root check -> red")
ADDED = {TD: ["Process"], SP: ["Rand", "Trace"],
         EXA: ["IO", "AI", "Net", "SharedMem", "Clock", "Stream", "Rand", "Trace"],
         CM: ["IO", "AI", "Net", "Stream", "Rand", "Trace"]}
for pkg, effs in ADDED.items():
    toml = f"{pkg}/ailang.toml"
    line = [l for l in open(toml).read().splitlines() if l.startswith("max = [")][0]
    items = re.findall(r'"([^"]+)"', line)
    skip = "P12B_ROOT_SKIP=ws_loopback.ail " if pkg == SP else ""
    short = {TD: "td", SP: "sp", EXA: "exa", CM: "cm"}[pkg]
    for e in effs:
        assert e in items, (pkg, e)
        new = "max = [" + ", ".join(f'"{x}"' for x in items if x != e) + "]"
        row(f"{short}_ceiling_{e}", toml, line, new, f"{skip}{ROOT} {pkg.split('/')[1]}")

comment("--- the manifest pin: back to 7.4 -> the package's own lock fails -> red")
row("rg_pin_8_0", f"{RG}/ailang.toml", 'version = "8.0" }', 'version = "7.4" }', f"{W} check motoko-ext-repetition-guard")
comment("--- the package's own tests discriminate on the migrated (PureCtx) helpers")
row("rg_own_tests", f"{RG}/repetition_guard.ail", "  { 5 }", "  { 6 }", f"{W} test {RG}/repetition_guard.ail")
comment("--- the masked file on 8.0 (committed-HEAD core workspace): the answer half accepts one emission late -> red")
row("masked_verify_rg", f"{RG}/repetition_guard.ail", "  else if prior_answers(ctx, candidate) >= budget then Accept", "  else if prior_answers(ctx, candidate) > budget then Accept", f"{CORE} run scripts/verify_repetition_guard.ail IO")
comment("--- ws_loopback's 8.0 row (core's dispatch carries Trace): drop it -> the core-workspace check -> red")
row("sp_loopback_trace", f"{SP}/ws_loopback.ail", "func dispatch_deferred_request(rt: ExtRuntime, ctx: ExtCtx, raw_req: string) -> string ! {AI, Clock, Env, FS, IO, Net, Process, SharedMem, Stream, Rand, Trace} {",
    "func dispatch_deferred_request(rt: ExtRuntime, ctx: ExtCtx, raw_req: string) -> string ! {AI, Clock, Env, FS, IO, Net, Process, SharedMem, Stream, Rand} {",
    f"{CORE} check deps/motoko_scratchpad/ws_loopback.ail")

out = ["# 031 PLAN-001 P1.2b mutgate spec (013 GATE-mutation-red-submission-precondition.md). GENERATED by",
       "# p12b_mutgate_spec.py -- edit that, not this. fix_id <TAB> target_file <TAB> sed_expr <TAB> test_cmd.",
       "# Run through p12b_mutgate.sh, never in a checkout anyone is using. Every test_cmd builds its own",
       "# workspace from the throwaway's files (p12b_ws.sh / p12b_pkgroot.sh / p12b_core_check.sh), so the",
       "# mutated file is what gets checked -- never the primary's through a tracked ailang.lock. No",
       "# `cmd | grep -q` anywhere (pipefail/SIGPIPE)."]
for r in rows:
    if r[0] == "#": out.append("# " + r[1]); continue
    fix, target, pat, rep, cmd, _ = r
    out.append("\t".join([fix, target, f"s/{esc_sed(pat)}/{esc_rep(rep)}/", cmd]))
open(f"{E}/p12b_mutgate_spec.tsv", "w").write("\n".join(out) + "\n")
print(f"{sum(1 for r in rows if r[0] != '#')} rows")
