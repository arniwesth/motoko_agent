"""The event-subject table and its coverage validator (010, tasks 3.3–3.6).

Two-sided throughout. The table is transcribed from `NOTE-q1-event-subject-pass.md`,
so these tests assert the transcription is faithful (the counts the NOTE settled)
and that the fail-open path genuinely fails *open* — the ADR acceptance criterion
is "unattributed records render as unattributed, never dropped", and a rule
engine that silently returns nothing would satisfy every equality check while
losing data.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "overlay"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "query"))

import event_subjects as es  # noqa: E402
import validate_overlay as vo  # noqa: E402

TOOL_MAP = es.ToolModuleMap(
    native={"ReadFile": "src/core/tool_runtime"},
    ext_packages={"motoko_ext_mcp": "packages/motoko-ext-mcp"},
)
ERROR_SOURCES = {"system_prompt": "src/core/session"}


def _subjects(attributions):
    return [a.subject_id for a in attributions]


# --------------------------------------------------------------------------
# faithful transcription of the NOTE
# --------------------------------------------------------------------------


def test_table_has_the_thirty_settled_rows() -> None:
    assert len(es.RULES) == 30
    assert len(es.RULES_BY_KEY) == 30, "duplicate record_key in the table"


def test_rule_kind_tally_matches_the_note() -> None:
    assert es.rule_kind_tally() == {"fixed": 19, "payload_routed": 10, "correlated": 1}


def test_fifteen_rows_are_multi_subject() -> None:
    assert len(es.multi_subject_keys()) == 15


def test_exactly_one_correlated_row_and_it_is_the_expected_one() -> None:
    correlated = [r.key for r in es.RULES if r.rule_kind == es.CORRELATED]
    assert correlated == ["WireRecord:V2ToolDispatchComplete"]
    assert es.RULES_BY_KEY[correlated[0]].correlate_by == "id"


def test_the_two_named_gap_rows_are_present() -> None:
    for key in es.GAP_KEYS:
        assert key in es.RULES_BY_KEY
    assert set(es.GAP_KEYS) == {"WireRecord:ScratchpadResult", "WireRecord:SessionSuspend"}


def test_error_event_is_the_only_row_with_no_fixed_subject() -> None:
    sole = [r.key for r in es.RULES if r.sole_subject_is_routed]
    assert sole == ["WireRecord:ErrorEvent"]
    assert es.RULES_BY_KEY["WireRecord:ErrorEvent"].fixed_subjects == ()


def test_checkpoint_taken_subject_is_phase_vocab_not_session() -> None:
    # The NOTE's recorded heuristic correction: phase_vocab is not
    # projection-only, it owns the checkpoint seam. Emitter != subject cuts both
    # ways, and this row is where it bit.
    assert es.RULES_BY_KEY["WireRecord:CheckpointTaken"].fixed_subjects == (es.PHASE_VOCAB,)


def test_stream_delta_is_keyed_on_the_variant_not_a_wire_name() -> None:
    assert "WireRecord:StreamDelta" in es.RULES_BY_KEY
    assert not any(k in es.RULES_BY_KEY for k in ("reasoning_delta", "thinking_delta"))


# --------------------------------------------------------------------------
# attribution behaviour — the fail-open direction
# --------------------------------------------------------------------------


def test_fixed_rule_emits_its_subjects() -> None:
    got, unresolved = es.attribute("WireRecord:RunSummary", {}, TOOL_MAP, ERROR_SOURCES)
    assert _subjects(got) == [es.SESSION]
    assert unresolved == []


def test_multi_subject_rule_fans_out() -> None:
    got, _ = es.attribute("WireRecord:HybridBashExtracted", {}, TOOL_MAP, ERROR_SOURCES)
    assert set(_subjects(got)) == {es.SESSION, es.PARSE}


def test_payload_routed_rule_adds_the_named_tool() -> None:
    got, unresolved = es.attribute("WireRecord:ToolPending", {"tool": "ReadFile"}, TOOL_MAP, ERROR_SOURCES)
    assert set(_subjects(got)) == {es.TOOL_PHASE, "src/core/tool_runtime"}
    assert unresolved == []


def test_unknown_tool_keeps_the_fixed_subject_and_is_counted() -> None:
    got, unresolved = es.attribute("WireRecord:ToolPending", {"tool": "NoSuchTool"}, TOOL_MAP, ERROR_SOURCES)
    assert es.TOOL_PHASE in _subjects(got), "the fixed half of the set is still real"
    assert es.UNATTRIBUTED_SUBJECT in _subjects(got), "the missing half must be visible, not silent"
    assert len(unresolved) == 1 and "NoSuchTool" in unresolved[0]


def test_error_event_with_unknown_source_is_wholly_unattributed() -> None:
    got, unresolved = es.attribute("WireRecord:ErrorEvent", {"source": "brand_new"}, TOOL_MAP, ERROR_SOURCES)
    assert _subjects(got) == [es.UNATTRIBUTED_SUBJECT]
    assert unresolved and "brand_new" in unresolved[0]


def test_error_event_with_known_source_routes_to_its_module() -> None:
    got, _ = es.attribute("WireRecord:ErrorEvent", {"source": "system_prompt"}, TOOL_MAP, ERROR_SOURCES)
    assert _subjects(got) == [es.SESSION]


def test_set_valued_payload_produces_one_subject_per_tool() -> None:
    payload = {"tool_calls": [{"name": "ReadFile"}, {"name": "ReadFile"}]}
    got, _ = es.attribute("WireRecord:NativeToolCalls", payload, TOOL_MAP, ERROR_SOURCES)
    assert _subjects(got).count("src/core/tool_runtime") == 2
    assert es.MODEL_PHASE in _subjects(got)


def test_correlated_rule_resolves_through_its_start() -> None:
    got, unresolved = es.attribute("WireRecord:V2ToolDispatchComplete", {"id": "tc-1"},
                                   TOOL_MAP, ERROR_SOURCES, correlation={"tc-1": "ReadFile"})
    assert set(_subjects(got)) == {es.TOOL_PHASE, "src/core/tool_runtime"}
    assert unresolved == []


def test_correlated_rule_without_a_start_fails_open_and_is_counted() -> None:
    got, unresolved = es.attribute("WireRecord:V2ToolDispatchComplete", {"id": "orphan"},
                                   TOOL_MAP, ERROR_SOURCES, correlation={})
    assert es.UNATTRIBUTED_SUBJECT in _subjects(got)
    assert unresolved and "orphan" in unresolved[0]


def test_an_unknown_record_key_never_returns_nothing() -> None:
    got, unresolved = es.attribute("WireRecord:FromTheFuture", {}, TOOL_MAP, ERROR_SOURCES)
    assert _subjects(got) == [es.UNATTRIBUTED_SUBJECT]
    assert unresolved


def test_extension_id_routes_to_the_package_node() -> None:
    got, _ = es.attribute("CompactionStageRecord", {"ext_id": "motoko_ext_mcp"}, TOOL_MAP, ERROR_SOURCES)
    assert set(_subjects(got)) == {es.COMPACTION, "packages/motoko-ext-mcp"}


def test_extension_candidates_cover_the_non_mechanical_spelling() -> None:
    # The registry says motoko_ext_scratchpad; the directory is motoko_scratchpad.
    # The mechanical rule alone would miss it, so candidates are checked against
    # real nodes rather than guessed.
    assert "packages/motoko_scratchpad" in es.ext_package_candidates("motoko_ext_scratchpad")
    assert "packages/motoko-ext-mcp" in es.ext_package_candidates("motoko_ext_mcp")


def test_unresolvable_extensions_are_reported_not_invented() -> None:
    result = es.build_tool_module_map(["motoko_ext_nonexistent"], known_nodes=set())
    assert result.ext_packages == {}
    assert result.unresolved_ext == ["motoko_ext_nonexistent"]


# --------------------------------------------------------------------------
# the coverage validator's forbidden direction
# --------------------------------------------------------------------------


def _vocab(rows: list[dict]) -> dict:
    return {"rows": rows}


REAL_ROW = {"variant": "RunSummary", "classification": "logical", "reaches_trace_today": True}
DISPLAY_ROW = {"variant": "SessionStart", "classification": "display_only", "reaches_trace_today": False}


def test_coverage_validator_is_green_on_the_real_vocabulary(tmp_path) -> None:
    import json

    vocab_path = Path("tools/code-graph/.out/vocabulary.json")
    if not vocab_path.exists():
        return  # the export is generated, not committed
    findings: list = []
    vo.check_rule_coverage(json.loads(vocab_path.read_text()), findings)
    assert findings == []


def test_coverage_validator_catches_a_missing_rule() -> None:
    findings: list = []
    vo.check_rule_coverage(_vocab([REAL_ROW, {"variant": "BrandNewLogicalEvent",
                                              "classification": "logical",
                                              "reaches_trace_today": True}]), findings)
    assert any("BrandNewLogicalEvent" in f.detail for f in findings)


def test_coverage_validator_catches_a_rule_for_a_display_only_variant() -> None:
    findings: list = []
    # SessionStart is DISPLAY-ONLY; pretend someone added a rule for it.
    patched = dict(es.RULES_BY_KEY)
    patched["WireRecord:SessionStart"] = es.Rule("WireRecord:SessionStart", es.FIXED, (es.SESSION,))
    original = es.RULES_BY_KEY
    try:
        es.RULES_BY_KEY = patched
        vo.check_rule_coverage(_vocab([REAL_ROW, DISPLAY_ROW]), findings)
    finally:
        es.RULES_BY_KEY = original
    assert any("DISPLAY-ONLY" in f.detail and "SessionStart" in f.detail for f in findings)


def test_coverage_validator_catches_a_rule_matching_no_vocabulary_row() -> None:
    findings: list = []
    patched = dict(es.RULES_BY_KEY)
    patched["WireRecord:Invented"] = es.Rule("WireRecord:Invented", es.FIXED, (es.SESSION,))
    original = es.RULES_BY_KEY
    try:
        es.RULES_BY_KEY = patched
        vo.check_rule_coverage(_vocab([REAL_ROW]), findings)
    finally:
        es.RULES_BY_KEY = original
    assert any("matches no vocabulary row" in f.detail for f in findings)
