"""The event-subject table (project 010, plan task 3.3; ADR-001 D5).

**This file transcribes `NOTE-q1-event-subject-pass.md`'s 30-row table. It does
not re-derive it.** The Q1 pass settled every row, including eight that needed
construction-site reads, and the standing rule is *emitter ≠ subject*: 26 of 28
variants are constructed in `session.ail` or projected in `phase_vocab.ail`, and
the construction site was used as evidence, never as the answer. If a row here
looks wrong, that is a finding against the NOTE, not a reason to edit the row.

**Naming, stated deliberately.** `src/core/dst_attribution_table.ail` already
exists and is a *different mechanism* — the site-to-hook table under 009/D4
clause 3, defining profile reachability. This is the **event-subject table**: it
attributes *events to subject modules*. The two are not kin and this paragraph
exists so no future reader assumes they are.

Rules produce **subject sets**, not modules — 15 of 30 rows are multi-subject,
typically ``{owning mechanism} ∪ {payload-named tool/ext module}``. `rule_kind`
records *how* the subject was derived so downstream views can weight or filter by
attribution quality without a fuzzy confidence number.

Pure stdlib: no chdb, no numpy. `build_activity.py` supplies the payloads.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass, field
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "data"

FIXED = "fixed"
PAYLOAD_ROUTED = "payload_routed"
CORRELATED = "correlated"
UNATTRIBUTED = "unattributed"

# The fail-open subject. ADR acceptance: "unattributed records render as
# unattributed, never dropped." It is a subject_id like any other so it survives
# every join and shows up in every count.
UNATTRIBUTED_SUBJECT = "unattributed"

# Subject slugs. The NOTE writes these as bare mechanism names ("model_phase");
# they are module slugs under src/core/ unless noted, and every one is checked
# against modules.csv at build time.
MODEL_PHASE = "src/core/model_phase"
TOOL_PHASE = "src/core/tool_phase"
TOOL_STREAM_PHASE = "src/core/tool_stream_phase"
COST_PHASE = "src/core/cost_phase"
COMPACTION = "src/core/compaction"
SESSION = "src/core/session"
PHASE_VOCAB = "src/core/phase_vocab"
ENV_CLIENT = "src/core/env_client"
PARSE = "src/core/parse"
EXT_RUNTIME = "src/core/ext/runtime"


@dataclass(frozen=True)
class Rule:
    """One row of the table.

    `fixed_subjects` are always emitted. `route_field` names the payload key
    whose value is looked up in the tool/ext/source map; `route_kind` says how to
    read it. `sole_subject_is_routed` marks the one row (ErrorEvent) whose
    subject is *entirely* payload-determined, so an unresolved value leaves the
    record with no subject but `unattributed`.
    """

    key: str
    rule_kind: str
    fixed_subjects: tuple[str, ...] = ()
    route_field: str | None = None
    route_kind: str | None = None  # "tool" | "tool_list" | "result_list" | "ext_id" | "error_source"
    sole_subject_is_routed: bool = False
    correlate_by: str | None = None
    # A subject the NOTE names but which cannot be resolved to a slug at v1.
    # Recorded rather than dropped or invented — see ExtSolverFeedback.
    unresolvable_subject: str | None = None
    note: str = ""


# ---------------------------------------------------------------------------
# The 30 rows, in the NOTE's order. Row numbers are the NOTE's.
# ---------------------------------------------------------------------------

RULES: tuple[Rule, ...] = (
    # --- WireRecord: 28 LOGICAL variants -----------------------------------
    Rule("WireRecord:ProviderCallPrepared", FIXED, (MODEL_PHASE,),
         note="1. Call assembly; payload digests are replay identity (009/D8)"),
    Rule("WireRecord:ScratchpadResult", FIXED, (TOOL_PHASE, ENV_CLIENT),
         note="2. env_client.exec_scratchpad_cell (env_client.ail:118) executes cells; "
              "always the scratchpad tool, so fixed rather than payload_routed. "
              "D6.4 GAP — never in a trace today; the row exists so closure needs no table change"),
    Rule("WireRecord:RunSummary", FIXED, (SESSION,),
         note="3. Terminal record, appended by c2_finalize"),
    Rule("WireRecord:NativeToolDenied", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="tool", route_kind="tool", note="4. Approval denial"),
    Rule("WireRecord:ToolPending", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="tool", route_kind="tool", note="5."),
    Rule("WireRecord:ExtToolHandled", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="tool", route_kind="tool",
         note="6. Which ext served is 009/D5 coverage evidence"),
    Rule("WireRecord:DelegatedToolDeferred", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="tool", route_kind="tool", note="7. Records a non-execution"),
    Rule("WireRecord:V2ToolDispatchStart", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="tool", route_kind="tool", note="8."),
    Rule("WireRecord:V2ToolDispatchComplete", CORRELATED, (TOOL_PHASE,),
         route_kind="tool", correlate_by="id",
         note="9. THE ONE CORRELATED ROW: no `tool` field; joins to its "
              "V2ToolDispatchStart by `id` within the same trace"),
    Rule("WireRecord:Dp7VerifierRejected", FIXED, (SESSION, EXT_RUNTIME),
         note="10. run_dp7_verifier (session.ail:1713, !{Process}) runs the verifier via "
              "ExtRuntime; the payload does not name the ext"),
    Rule("WireRecord:CostExhausted", FIXED, (COST_PHASE,), note="11."),
    Rule("WireRecord:CompactionExhausted", FIXED, (COMPACTION,),
         note="12. Terminal cause, not a stage outcome"),
    Rule("WireRecord:ThinkingStreamStart", FIXED, (MODEL_PHASE,), note="13. Stream bracket"),
    Rule("WireRecord:ThinkingStreamEnd", FIXED, (MODEL_PHASE,),
         note="14. `status` discriminates completed/errored"),
    Rule("WireRecord:StreamErrorRetry", FIXED, (MODEL_PHASE,), note="15."),
    Rule("WireRecord:ProviderResult", FIXED, (MODEL_PHASE,),
         note="16. The one variant constructed *in* its subject (model_phase.ail)"),
    Rule("WireRecord:ExtInterceptHandled", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="tool", route_kind="tool",
         note="17. Projection is lossy (no stream_id/id) — recorded in the vocabulary, harmless here"),
    Rule("WireRecord:HybridBashExtracted", FIXED, (SESSION, PARSE),
         note="18. parse.extract_bash (parse.ail:118) called from session's c2 loop"),
    Rule("WireRecord:DoneEvent", FIXED, (SESSION,),
         note="19. Append-before/project-after site (WI-A14 finding)"),
    Rule("WireRecord:EmptyStopFinalize", FIXED, (SESSION,), note="20. Terminal path"),
    Rule("WireRecord:ExtSolverFeedback", FIXED, (EXT_RUNTIME,),
         unresolvable_subject="solver extension (registry-resolved, absent from the payload)",
         note="21. dispatch_solver_candidate (ext/runtime.ail:453). The NOTE names a second "
              "subject — the concrete solver ext — which cannot be resolved at v1 because it "
              "is not in the payload. Recorded here rather than invented or dropped"),
    Rule("WireRecord:PersistNudge", FIXED, (SESSION,),
         note="22. should_inject_persist_nudge in session's loop; policy-driven, no hook_phase"),
    Rule("WireRecord:NativeToolCalls", PAYLOAD_ROUTED, (MODEL_PHASE,),
         route_field="tool_calls", route_kind="tool_list",
         note="23. Subject set includes a LIST of tools — the first set-valued payload"),
    Rule("WireRecord:NativeToolResults", PAYLOAD_ROUTED, (TOOL_PHASE,),
         route_field="results", route_kind="result_list", note="24. Set-valued"),
    Rule("WireRecord:SessionSuspend", FIXED, (SESSION,),
         note="25. Emitted at session.ail:3127; the supervisor is not implicated at the "
              "emission site. D6.4 GAP — never in a trace today"),
    Rule("WireRecord:ErrorEvent", PAYLOAD_ROUTED, (),
         route_field="source", route_kind="error_source", sole_subject_is_routed=True,
         note="26. Subject ENTIRELY payload-determined; needs the source->module map"),
    Rule("WireRecord:CheckpointTaken", FIXED, (PHASE_VOCAB,),
         note="27. Constructed inside phase_vocab.checkpoint (phase_vocab.ail:263). This "
              "CORRECTS the 'phase_vocab is projection-only' heuristic: it owns the checkpoint seam"),
    Rule("WireRecord:StreamDelta", FIXED, (TOOL_STREAM_PHASE,),
         note="28. Constructed there. Keyed on the VARIANT, so its two wire names "
              "(reasoning_delta / thinking_delta) are a non-issue by construction"),
    # --- non-wire record kinds: 2 additional rows ---------------------------
    Rule("CompactionStageRecord", PAYLOAD_ROUTED, (COMPACTION,),
         route_field="ext_id", route_kind="ext_id",
         note="29. The logical counterpart of the 3 DISPLAY-ONLY compaction events"),
    Rule("DecisionRecord", FIXED, (SESSION,),
         note="30. Appended by c2_append_decision (session.ail:582). The 7 decision values are "
              "useful as VIEW FILTERS, not for routing — one subject"),
)

RULES_BY_KEY: dict[str, Rule] = {r.key: r for r in RULES}

# The two D6.4 gaps. Their rules are written even though they cannot appear in a
# trace today, so 009's gap closure needs no table change (NOTE headline 6). The
# validator asserts their PRESENCE; a rule for any *other* unreachable variant is
# a finding.
GAP_KEYS = ("WireRecord:ScratchpadResult", "WireRecord:SessionSuspend")

NON_WIRE_KEYS = ("CompactionStageRecord", "DecisionRecord")


# ---------------------------------------------------------------------------
# auxiliary maps
# ---------------------------------------------------------------------------


def _read_seed(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(line for line in fh if not line.lstrip().startswith("#")))


def load_native_tool_modules(data_dir: Path = DATA_DIR) -> dict[str, str]:
    return {row["tool"]: row["module"] for row in _read_seed(data_dir / "native_tool_modules.csv")}


def load_error_sources(data_dir: Path = DATA_DIR) -> dict[str, str]:
    return {row["source"]: row["module"] for row in _read_seed(data_dir / "error_sources.csv")}


# Registry package name -> repo directory, where the mechanical rule fails.
# The registry names extensions `motoko_ext_<x>` and the repo directories are
# `motoko-ext-<x>` — except one. Rather than guess, every candidate spelling is
# checked against modules.csv and a name that matches none is REPORTED.
def ext_package_candidates(registry_name: str) -> list[str]:
    stem = registry_name.removeprefix("motoko_ext_")
    return [
        f"packages/motoko-ext-{stem.replace('_', '-')}",
        f"packages/motoko_ext_{stem}",
        f"packages/{registry_name}",
        f"packages/motoko_{stem}",  # motoko_ext_scratchpad -> packages/motoko_scratchpad
    ]


@dataclass
class ToolModuleMap:
    """The tool→module map every payload_routed rule depends on."""

    native: dict[str, str] = field(default_factory=dict)
    ext_packages: dict[str, str] = field(default_factory=dict)  # registry name -> package node
    unresolved_ext: list[str] = field(default_factory=list)
    rejected_native: list[str] = field(default_factory=list)

    def module_for_tool(self, tool: str) -> str | None:
        return self.native.get(tool)

    def module_for_ext(self, ext_id: str) -> str | None:
        if ext_id in self.ext_packages:
            return self.ext_packages[ext_id]
        # ext_id may arrive already normalised, or as a bare stem.
        for name, node in self.ext_packages.items():
            if name.removeprefix("motoko_ext_") == ext_id.removeprefix("motoko_ext_"):
                return node
        return None

    def rows(self) -> list[dict]:
        out = [{"key": t, "kind": "native_tool", "module": m} for t, m in sorted(self.native.items())]
        out += [{"key": e, "kind": "extension", "module": m} for e, m in sorted(self.ext_packages.items())]
        return out


def build_tool_module_map(
    registry_names: list[str],
    known_nodes: set[str],
    data_dir: Path = DATA_DIR,
) -> ToolModuleMap:
    """Curated native seed + mechanically-derived extension packages.

    `known_nodes` is every `layout.node_id` (so an extension resolves to its
    **package node**, an L1 layout row, not to one arbitrary module inside it —
    we know *which extension* served, not which of its files did). Anything that
    does not resolve is collected, never guessed.
    """
    result = ToolModuleMap()
    for tool, module in load_native_tool_modules(data_dir).items():
        if module in known_nodes:
            result.native[tool] = module
        else:
            result.rejected_native.append(f"{tool} -> {module} (no such node)")
    for name in sorted(set(registry_names)):
        node = next((c for c in ext_package_candidates(name) if c in known_nodes), None)
        if node is None:
            result.unresolved_ext.append(name)
        else:
            result.ext_packages[name] = node
    return result


# ---------------------------------------------------------------------------
# applying a rule
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Attribution:
    subject_id: str
    rule_kind: str


def _tool_names_from(value) -> list[str]:
    """`tool_calls[]` / `results[]` carry objects; take the tool name from
    whichever key the wire projection used."""
    if not isinstance(value, list):
        return []
    names = []
    for item in value:
        if isinstance(item, str):
            names.append(item)
        elif isinstance(item, dict):
            for key in ("tool", "name", "tool_name"):
                if isinstance(item.get(key), str):
                    names.append(item[key])
                    break
    return names


def attribute(
    record_key: str,
    payload: dict,
    tool_map: ToolModuleMap,
    error_sources: dict[str, str],
    correlation: dict[str, str] | None = None,
) -> tuple[list[Attribution], list[str]]:
    """Return (attributions, unresolved tokens) for one record.

    Fail-open by construction: an unknown tool, ext or error source yields an
    `unattributed` row and a token in the second element, so the caller can
    count growth. It never yields nothing.
    """
    rule = RULES_BY_KEY.get(record_key)
    if rule is None:
        return [Attribution(UNATTRIBUTED_SUBJECT, UNATTRIBUTED)], [f"no rule for {record_key}"]

    out = [Attribution(s, rule.rule_kind) for s in rule.fixed_subjects]
    unresolved: list[str] = []

    tokens: list[str] = []
    if rule.route_kind in ("tool", "ext_id", "error_source") and rule.route_field:
        value = payload.get(rule.route_field)
        if isinstance(value, str) and value:
            tokens = [value]
    elif rule.route_kind in ("tool_list", "result_list") and rule.route_field:
        tokens = _tool_names_from(payload.get(rule.route_field))
    elif rule.rule_kind == CORRELATED:
        # The Complete carries no `tool`; its Start does. A Complete with no
        # matching Start routes unattributed and is counted (fail-open).
        ident = payload.get(rule.correlate_by or "id")
        found = (correlation or {}).get(ident) if isinstance(ident, str) else None
        if found:
            tokens = [found]
        else:
            unresolved.append(f"{record_key}: no matching V2ToolDispatchStart for id={ident!r}")

    for token in tokens:
        if rule.route_kind == "error_source":
            module = error_sources.get(token)
        elif rule.route_kind == "ext_id":
            module = tool_map.module_for_ext(token)
        else:
            module = tool_map.module_for_tool(token)
        if module:
            out.append(Attribution(module, rule.rule_kind))
        else:
            unresolved.append(f"{record_key}: unmapped {rule.route_kind} {token!r}")

    if not out:
        # Only reachable for ErrorEvent (sole_subject_is_routed) and for a
        # correlated Complete with no Start. Never dropped.
        out.append(Attribution(UNATTRIBUTED_SUBJECT, UNATTRIBUTED))
    elif unresolved and not rule.sole_subject_is_routed:
        # The fixed part of the set is still real; the missing payload subject is
        # recorded as its own unattributed row so counts stay honest rather than
        # the whole record being thrown away or silently under-attributed.
        out.append(Attribution(UNATTRIBUTED_SUBJECT, UNATTRIBUTED))

    return out, unresolved


def rule_kind_tally() -> dict[str, int]:
    tally: dict[str, int] = {}
    for rule in RULES:
        tally[rule.rule_kind] = tally.get(rule.rule_kind, 0) + 1
    return tally


def multi_subject_keys() -> list[str]:
    """Rows whose subject set can exceed one member — the viewer renders
    subject-set glow for these (a P4 design choice, not a data problem)."""
    return [
        r.key for r in RULES
        if len(r.fixed_subjects) > 1 or r.route_kind is not None or r.unresolvable_subject
    ]
