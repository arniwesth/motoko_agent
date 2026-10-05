#!/usr/bin/env bash
# What structural compaction does to a skill body that was loaded as a tool
# result: when it is elided, and what is left of it. Calls the real
# `compact_for_pre_step`; no model, no network.
# Evidence for RESEARCH-skills-system.md §9 M3. Not a gate.
#
#   bash .agent/projects/037_skills_system/evidence/m3_compaction_probe.sh
#
# Cases A-G put the skill text in the tool message as-is, which isolates the
# compactor's behaviour. Cases H-J use the message the harness actually builds
# for an extension tool result, `result_env_model_content`: the JSON-encoded
# envelope, with a tool-call id of the length seen in real sessions (37 chars).
# H-J are the ones that say what a model would see.
#
# Must run from the repo root (it imports the in-tree packages). It writes one
# temporary module, tmp/skills_m3_probe.ail, and removes it on exit.
set -u

ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
P=tmp/skills_m3_probe.ail
mkdir -p tmp
trap 'rm -f "$P"' EXIT

cat > "$P" <<'EOF'
module tmp/skills_m3_probe

import std/io (println)
import std/fs (readFile)
import std/json (jo)
import std/string (length)
import pkg/sunholo/motoko_ext_abi/types (Msg, ToolCall, PureCtx, pure_ctx, PreStepDecision, PassThrough, PassThroughObserved, Compacted)
import pkg/sunholo/motoko_ext_compaction_structural/compaction_structural (compact_for_pre_step, estimate_tokens_messages)
import src/core/phase_vocab (result_env_model_content)

func doubled(s: string, n: int) -> string {
  if n <= 0 then s else doubled("${s}${s}", n - 1)
}

func call_msg(id: string, tool: string, args: string) -> Msg {
  { role: "assistant", content: "", tool_calls: [{ id: id, name: tool, arguments: args }], tool_call_id: "" }
}

func result_msg(id: string, content: string) -> Msg {
  { role: "tool", content: content, tool_calls: [], tool_call_id: id }
}

func later(n: int, i: int, body: string) -> [Msg] {
  if i > n then []
  else call_msg("c${show(i)}", "ReadFile", "{}") :: result_msg("c${show(i)}", body) :: later(n, i + 1, body)
}

-- system, user, Skill call, the skill result, then `n_after` further tool results.
func history(sid: string, skill_result: string, n_after: int, body: string) -> [Msg] {
  [
    { role: "system", content: "SYSTEM", tool_calls: [], tool_call_id: "" },
    { role: "user", content: "task", tool_calls: [], tool_call_id: "" },
    call_msg(sid, "Skill", "{\"name\":\"observer\"}"),
    result_msg(sid, skill_result)
  ] ++ later(n_after, 1, body)
}

func find_result(sid: string, msgs: [Msg]) -> string {
  match msgs {
    [] => "<missing>",
    m :: rest => if m.role == "tool" && m.tool_call_id == sid then m.content else find_result(sid, rest)
  }
}

func call_args(sid: string, calls: [ToolCall]) -> string {
  match calls {
    [] => "",
    c :: rest => if c.id == sid then "${c.name}(${c.arguments})" else call_args(sid, rest)
  }
}

-- The assistant message that made the Skill call, as it stands after compaction.
func find_call(sid: string, msgs: [Msg]) -> string {
  match msgs {
    [] => "<missing>",
    m :: rest => {
      let hit = if m.role == "assistant" then call_args(sid, m.tool_calls) else "";
      if hit == "" then find_call(sid, rest) else hit
    }
  }
}

func describe(sid: string, d: PreStepDecision, original: string) -> string {
  match d {
    PassThrough => "PassThrough; skill result intact",
    PassThroughObserved(code, _) => "PassThroughObserved(${code}); skill result intact",
    Compacted(msgs, note, _) => {
      let c = find_result(sid, msgs);
      let call = find_call(sid, msgs);
      if length(c) == length(original) then "Compacted[${note}]; skill result intact (${show(length(c))} chars)"
      else "Compacted[${note}]; skill result ${show(length(original))} -> ${show(length(c))} chars:\n    | ${c}\n    the call that loaded it still reads: ${call}"
    }
  }
}

-- `usage_pct` is what the window is made to measure: the limit is derived from it.
func run_case(label: string, sid: string, skill_result: string, n_after: int, body: string, usage_pct: int) -> () ! {IO} {
  let msgs = history(sid, skill_result, n_after, body);
  let est = estimate_tokens_messages(msgs);
  let limit = (est * 100) / usage_pct;
  let ctx = { pure_ctx(jo([])) | context_limit: limit };
  println("${label}\n    est=${show(est)} tok, limit=${show(limit)}, skill=${show((length(skill_result) + 3) / 4)} tok\n    ${describe(sid, compact_for_pre_step(ctx, msgs), skill_result)}")
}

-- The content the harness gives an extension tool result (tool_phase -> handled_tool_message).
func envelope(id: string, stdout: string) -> string {
  result_env_model_content({ tool_call_id: id, tool: "Skill", exit_code: 0, stdout: stdout, stderr: "", metadata: jo([]) })
}

export func main() -> () ! {IO, FS} {
  let raw = readFile(".claude/skills/observer/SKILL.md");
  let hinted = "[skill observer loaded]\n${raw}";
  let big = doubled("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", 6);
  let small = doubled("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", 2);
  let real_id = "call_0123456789abcdef0123456789abcdef";
  let _ = println("observer SKILL.md: ${show(length(raw))} chars; filler tool result: ${show(length(big))} chars (big), ${show(length(small))} (small)\n");
  let _ = println("== skill text as the whole tool message (isolates the compactor)");
  let _ = run_case("A. 50% usage, 20 later tool results", "s1", raw, 20, big, 50);
  let _ = run_case("B. 72% usage, 3 later tool results (skill is 4th newest)", "s1", raw, 3, big, 72);
  let _ = run_case("C. 72% usage, 9 later tool results (skill is 10th newest)", "s1", raw, 9, big, 72);
  let _ = run_case("D. 72% usage, 10 later tool results (skill is 11th newest)", "s1", raw, 10, big, 72);
  let _ = run_case("E. 72% usage, 20 later tool results", "s1", raw, 20, big, 72);
  let _ = run_case("F. as E, text starts with a marker line", "s1", hinted, 20, big, 72);
  let _ = run_case("G. 72% usage, 2 small later results: the skill alone is over 30% of the limit", "s1", raw, 2, small, 72);
  let _ = println("\n== the message the harness builds: JSON envelope, 37-char tool-call id");
  let _ = run_case("H. as E, envelope, stdout = SKILL.md", real_id, envelope(real_id, raw), 20, big, 72);
  let _ = run_case("I. as E, envelope, stdout starts with the marker line", real_id, envelope(real_id, hinted), 20, big, 72);
  let _ = run_case("J. as I, with a 6-char tool-call id", "call_1", envelope("call_1", hinted), 20, big, 72);
  ()
}
EOF

echo "ailang: $(ailang --version | head -1)"
AILANG_FS_SANDBOX="$ROOT" ailang run --caps IO,FS --entry main "$P" 2>&1 | grep -v '^→\|^✓'
