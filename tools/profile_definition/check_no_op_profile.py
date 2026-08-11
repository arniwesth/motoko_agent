#!/usr/bin/env python3
"""WI-D14's anti-transcription guard for the SECOND profile.

`check_fixtures.py` guards `driver_only`, whose install list is empty; almost
nothing it checks quantifies over an installed extension because there are none.
This script is the same discipline applied to a profile that installs four, and
every check here is one that could not have existed before there was something
installed to ask it about.

WHAT IT READS, AND WHY NOT THE SOURCE. It takes the OUTPUT of
`scripts/dst/driver_plus_no_ops_dst.ail` and not `src/core/dst_driver_plus_no_ops.ail`.
The profile is a computed value — the classification entries are built by
folding `all_hook_slots()`, so the source text does not contain them — and a
regex over the source would be checking the constructor rather than the record.
The script prints one canonical line per entry, per installed package, per
omission and per disclosure; this reads those and compares each against a
producer that is independent of the profile.

THE SIX CHECKS, and the fourth and fifth are the ones with teeth:

  1. installed set == the ZERO-BARRIER set, re-derived. The profile may install
     exactly the extensions WI-D13's per-(extension, slot) derivation clears,
     and no others. Fewer is a silent decline; more is coverage claimed over a
     standing barrier.
  2. installed + omitted == every extension in `ailang.toml`'s `[extensions]
     packages`. An extension in neither is a decision inherited rather than
     taken.
  3. each installed package's recorded version matches the resolved one.
  4. each CLASSIFICATION line's criterion matches the ABI: a slot with a
     non-empty effect row may not be `effect_free` (criterion 1 fails on the
     declared row), and a rowless slot may not be `world_mediated` on a measured
     basis it does not need. The rowed/rowless split lives in
     `packages/motoko-ext-abi/types.ail` and is re-derived here, so the day a
     row narrows the profile's classification is RED rather than quietly
     over-claiming.
  5. each `vacuously` / `substantively` clause status matches classifier 3 and
     the ABI outcome type. This is what makes the vacuity a MEASUREMENT in the
     record rather than an assertion in it.
  6. the three CLAIM lines rows 4, 5 and 7 rest on, each re-derived from its own
     producer.

Per plan rule S16, the enumeration for each new scan is in the function that
performs it, written BEFORE the unit was chosen, and every unenumerated shape
reads as FAIL rather than as absent.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ABI_TYPES = REPO / "packages/motoko-ext-abi/types.ail"
AILANG_TOML = REPO / "ailang.toml"
COVERAGE = REPO / "src/core/dst_profile_coverage.ail"

# The four slots the barrier derivation reasons about plus the four it does not.
# Not a list of "which are rowed" — that is derived below. This is only the set
# of ABI hook fields, and it is read from the coverage artifact's own id list so
# that a ninth slot arrives here too.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_fixtures import (  # noqa: E402
    ambient_inventory,
    installable_extension_dirs,
    outcome_returns_world,
)


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


# ---------------------------------------------------------------------------
# The script's output, parsed
# ---------------------------------------------------------------------------


def parse_output(path):
    """The canonical lines the acceptance script prints.

    S16 enumeration — the ways a line could reach this parser malformed:
      (a) absent entirely, because the scenario did not run. Every count is
          asserted non-zero below, so an absent block is a FAIL and not a
          vacuous pass. This is the failure this whole file exists to catch.
      (b) present with the wrong arity, because a field was added to the record
          and the print was not updated. Arity is checked per line.
      (c) present twice, because a scenario ran twice. Duplicate (ext, hook)
          keys are a FAIL.
      (d) present with an unknown token in a status position. Every token is
          checked against a closed set.
    """
    text = Path(path).read_text()
    out = {"classification": {}, "installed": {}, "omitted": set(),
           "disclosure": set(), "claim": {}, "statement": ""}

    for line in text.splitlines():
        parts = line.split()
        if not parts:
            continue
        tag = parts[0]
        if tag == "CLASSIFICATION":
            if len(parts) != 9:
                fail(f"a CLASSIFICATION line has {len(parts)} fields, expected 9: {line!r}.\n"
                     "      The entry record gained or lost a field and the print did not move with it.")
            _, ext, hook, kind, producer, basis_kind, c1, c2, c3 = parts
            key = (ext, hook)
            if key in out["classification"]:
                fail(f"CLASSIFICATION {ext}/{hook} appears twice; a duplicate entry would make "
                     "the counts below agree with a record that has two answers for one hook")
            for tok in (c1, c2, c3):
                if tok not in ("substantively", "vacuously", "not_applicable"):
                    fail(f"unknown clause status {tok!r} on {ext}/{hook}")
            if kind not in ("effect_free", "world_mediated", "explicitly_excluded"):
                fail(f"unknown classification {kind!r} on {ext}/{hook}")
            out["classification"][key] = (kind, producer, basis_kind, c1, c2, c3)
        elif tag == "INSTALLED":
            if len(parts) != 5:
                fail(f"an INSTALLED line has {len(parts)} fields, expected 5: {line!r}")
            out["installed"][parts[1]] = (parts[2], parts[3], parts[4])
        elif tag == "OMITTED":
            out["omitted"].add(parts[1])
        elif tag == "DISCLOSURE":
            out["disclosure"].add(parts[1])
        elif tag == "CLAIM":
            out["claim"][parts[1]] = " ".join(parts[2:])
        elif tag == "STATEMENT":
            out["statement"] = line[len("STATEMENT "):]

    if not out["classification"] or not out["installed"]:
        fail("the acceptance script printed no CLASSIFICATION or INSTALLED lines. A guard with "
             "nothing to check cannot be told from one that passes — re-run "
             "`make driver_plus_no_ops`.")
    return out


# ---------------------------------------------------------------------------
# The producers, each independent of the profile
# ---------------------------------------------------------------------------


def abi_slots():
    """slot id -> (declared row, outcome type, returns world state).

    S16 enumeration — the ways a slot's declaration can present in the ABI:
      (a) `name: (args) -> Type` on one line, no row;
      (b) `name: (args) -> Type ! {E, ...}` on one line;
      (c) the arrow wrapped onto the next line, with or without the row. TWO of
          the eight are this shape, and a line-anchored pattern reads them as
          rowless — the exact fail-open `check_fixtures` documents. `\\s*` spans
          newlines here for the same reason;
      (d) a row written with a type variable or an open row. None exists in this
          ABI; the capture would keep the raw text and a non-empty capture reads
          as ROWED, which is the fail-closed direction;
      (e) a LIST return type — `on_describe_tools` returns `[ToolSchema]`, so a
          bare `\\w+` capture reads that slot as unfindable. It is one of the
          eight and a `continue` here would have skipped it silently; the
          bracketed form is matched instead and a slot the pattern cannot find
          at all is a FAIL, never a skip.
    """
    abi = ABI_TYPES.read_text()
    # The slot ids come from A6's `hook_slot_id`, whose arms read
    # `OnDescribeTools => "on_describe_tools"`. Read from the coverage artifact
    # rather than written here, so a ninth slot arrives at this guard too.
    slot_ids = sorted(set(re.findall(r'=>\s*"(on_[a-z_]+)"', COVERAGE.read_text())))
    if len(slot_ids) != 8:
        fail(f"read {len(slot_ids)} hook slot ids from {COVERAGE.relative_to(REPO)}, expected 8: "
             f"{slot_ids}. The ABI gained or lost a slot and this guard's per-slot checks would "
             "silently skip it.")

    slots = {}
    for slot in slot_ids:
        m = re.search(re.escape(slot) + r":\s*\([^)]*\)\s*->\s*(\[?\s*\w+\s*\]?)\s*(!\s*\{([^}]*)\})?",
                      abi, re.M)
        if not m:
            fail(f"could not read `{slot}`'s declaration in {ABI_TYPES.relative_to(REPO)}; the "
                 "criterion each covered hook rests on cannot be re-derived")
        row = (m.group(3) or "").strip()
        slots[slot] = (row, m.group(1), outcome_returns_world(abi, m.group(1)))
    return slots


def resolved_extensions():
    """extension id -> version, from `[extensions] packages`."""
    toml = AILANG_TOML.read_text()
    block = re.search(r"\[extensions\](.*?)(?:\n\[|\Z)", toml, re.S)
    if not block:
        fail("ailang.toml has no [extensions] block")
    found = re.findall(r'"sunholo/motoko_ext_([a-z0-9_]+)@([^"]+)"', block.group(1))
    if not found:
        fail("ailang.toml's [extensions] block resolved to ZERO packages; an empty resolved set "
             "would make every partition check below pass over nothing")
    return dict(found)


def zero_barrier_set(inv, slots):
    """WI-D13's per-(extension, slot) derivation, re-run here.

    Deliberately RE-DERIVED rather than imported from `check_fixtures`: that
    function prints and triggers for `driver_only`, and calling it would couple
    the second profile's install list to the first profile's guard. The rule is
    the same and is stated once in `check_fixtures.check_barrier_count`'s
    docstring — an extension clears a barrier slot when classifier 3 reports it
    PORT-MEDIATED, reports zero `ExtPorts` field calls (so clause 2 is vacuous
    rather than undischarged), and the slot's outcome type returns explicit
    world state.
    """
    barriers = [s for s, (row, _t, _w) in slots.items() if row and is_unconditional(s)]
    if not barriers:
        fail("no slot is both unconditionally dispatched and rowed, so the barrier set is EMPTY "
             "and every extension trivially clears it. That is WI-C5's trigger and must be "
             "decided, not inherited — see check_fixtures.check_barrier_count.")
    zero = set()
    for ext_id in installable_extension_dirs().values():
        e = inv["extensions"].get(ext_id)
        if e is None:
            fail(f"classifier 3 has no verdict for installable extension '{ext_id}'; fail-closed, "
                 "its barrier count is unknown rather than zero")
        ok = (e["verdict"] == "PORT-MEDIATED" and e["ext_ports_calls"] == 0
              and all(slots[s][2] for s in barriers))
        if ok:
            zero.add(ext_id)
    return zero, barriers


def is_unconditional(slot):
    camel = "On" + "".join(p.capitalize() for p in slot.removeprefix("on_").split("_"))
    return re.search(camel + r"\s*=>\s*Unconditional", COVERAGE.read_text()) is not None


# ---------------------------------------------------------------------------
# The checks
# ---------------------------------------------------------------------------


def check_install_set(out, inv, slots):
    installed = set(out["installed"])
    zero, barriers = zero_barrier_set(inv, slots)

    if installed != zero:
        missing, extra = sorted(zero - installed), sorted(installed - zero)
        fail("the profile's install list is not the zero-barrier set.\n"
             f"      at zero barriers and NOT installed: {missing}\n"
             f"      installed and NOT at zero barriers: {extra}\n"
             "      The second list is the dangerous one: it is coverage claimed for an\n"
             "      extension a barrier still stands for. The first is a decline, which is\n"
             "      legitimate — but it must be taken in `omitted_extensions` with a reason,\n"
             "      not by leaving the extension out of both lists.")
    print(f"  ✓ install list == the re-derived ZERO-BARRIER set ({len(installed)} of "
          f"{len(installable_extension_dirs())} installable), over {len(barriers)} barrier slot(s): "
          f"{sorted(installed)}")

    resolved = resolved_extensions()
    accounted = installed | out["omitted"]
    unaccounted = sorted(set(resolved) - accounted)
    if unaccounted:
        fail(f"extension(s) {unaccounted} are in ailang.toml's resolved install set and this\n"
             "      profile neither installs nor omits them by name. An extension in neither list\n"
             "      is a decision INHERITED rather than taken.")
    phantom = sorted(accounted - set(resolved))
    if phantom:
        fail(f"the profile names extension(s) {phantom} that ailang.toml does not resolve; a\n"
             "      profile claiming a decision about an extension this tree does not have reads\n"
             "      as evidence of a choice nobody could make.")
    print(f"  ✓ installed ({len(installed)}) + omitted ({len(out['omitted'])}) == every resolved "
          f"extension ({len(resolved)}), with no phantom and no unaccounted")

    for ext_id, (_pkg, version, path) in sorted(out["installed"].items()):
        if resolved[ext_id] != version:
            fail(f"the profile records '{ext_id}' at version {version} and ailang.toml resolves "
                 f"{resolved[ext_id]}; a manifest that pins the wrong version pins nothing")
        if not (REPO / path).exists():
            fail(f"'{ext_id}' records source path '{path}', which does not exist")
    print(f"  ✓ every installed package's version and source path matches the resolved lock graph")

    if set(out["disclosure"]) != installed:
        fail(f"the disclosed set {sorted(out['disclosure'])} is not the installed set "
             f"{sorted(installed)}")


def check_classifications(out, inv, slots):
    """Check 4 and check 5, over every (extension, hook) entry.

    This is where the vacuity stops being an assertion. For each entry the guard
    knows, from producers the profile does not control:

      * whether the slot's ABI row is empty, which decides whether criterion 1
        is available at all;
      * whether the extension is PORT-MEDIATED with zero `ExtPorts` calls, which
        decides whether criterion 2's first two clauses hold VACUOUSLY or must
        be discharged some other way;
      * whether the slot's outcome type carries `next_state`, which decides
        clause 3.

    A record that disagrees with any of the three is red.
    """
    installed = set(out["installed"])
    expected = {(e, s) for e in installed for s in slots}
    got = set(out["classification"])
    if got != expected:
        missing, extra = sorted(expected - got), sorted(got - expected)
        fail(f"the classification entries are not one per (installed extension, ABI slot).\n"
             f"      missing: {missing}\n      unexpected: {extra}")

    n_c1 = n_c2 = 0
    for (ext, hook), (kind, producer, basis_kind, c1, c2, c3) in sorted(out["classification"].items()):
        row, outcome, returns_world = slots[hook]
        e = inv["extensions"][ext]
        port_mediated = e["verdict"] == "PORT-MEDIATED"
        nothing_to_tag = e["ext_ports_calls"] == 0

        if row and kind == "effect_free":
            fail(f"{ext}/{hook} is classified effect_free and the ABI declares ! {{{row}}} on that\n"
                 "      slot. Criterion 1's basis in this tree is the DECLARED ROW (ADR:1415) and a\n"
                 "      named binding cannot declare narrower than a closed ABI slot, so criterion 1\n"
                 "      FAILS for it — this classification claims a criterion it cannot have.")
        if not row and kind == "world_mediated":
            fail(f"{ext}/{hook} is classified world_mediated and the ABI declares NO row on that\n"
                 "      slot, where criterion 1 is available and is the weaker claim. Recording the\n"
                 "      stronger one hides that the slot needs no measurement at all.")
        if kind == "world_mediated":
            n_c2 += 1
            if basis_kind != "measured":
                fail(f"{ext}/{hook} rests on criterion 2 with an {basis_kind} basis "
                     f"('{producer}'); Amendment A's default admits only a MEASURED one (ADR:1548)")
            want_1 = "vacuously" if nothing_to_tag else "substantively"
            want_2 = "vacuously" if nothing_to_tag else "substantively"
            want_3 = "substantively" if returns_world else "not_applicable"
            if not port_mediated:
                fail(f"{ext}/{hook} rests on criterion 2 and classifier 3 reports the extension "
                     f"{e['verdict']} with {len(e['ambient'])} ambient source(s); clause 1 fails")
            if (c1, c2, c3) != (want_1, want_2, want_3):
                fail(f"{ext}/{hook} records criterion-2 clauses ({c1}, {c2}, {c3}) and the\n"
                     f"      producers derive ({want_1}, {want_2}, {want_3}).\n"
                     f"      classifier 3: verdict={e['verdict']} ext_ports_calls={e['ext_ports_calls']}\n"
                     f"      ABI: {hook} returns {outcome}, carries next_state: {returns_world}\n"
                     "      A vacuity recorded where a measurement says substantive — or the reverse —\n"
                     "      is the record claiming more or less than the tree supports.")
        elif kind == "effect_free":
            n_c1 += 1
            if (c1, c2, c3) != ("not_applicable",) * 3:
                fail(f"{ext}/{hook} is criterion 1 and carries criterion-2 clause evidence")
        else:
            fail(f"{ext}/{hook} is classified {kind}; this profile excludes nothing, and an "
                 "exclusion appearing here is a coverage change that must be decided")

    print(f"  ✓ every one of the {len(got)} classification entries agrees with its producers: "
          f"{n_c1} criterion 1 (rowless slot, declared_row/assumed), {n_c2} criterion 2 "
          f"(rowed slot, classifier 3/measured)")
    print(f"  ✓ every criterion-2 entry's VACUITY is a measurement: classifier 3 reports 0 ExtPorts "
          f"field calls in all {len(installed)} installed closures, so clauses 1 and 2 hold over an "
          f"empty set and only clause 3 is substantive")


def check_claims(out, inv):
    """The three CLAIM lines rows 4, 5 and 7 rest on."""
    installed = sorted(out["installed"])

    for claim, key, want in (("row3c", "ext_ports_calls", 0),
                             ("row4", "ext_ports_calls", 0),
                             ("row5", "ambient", 0)):
        if claim not in out["claim"]:
            fail(f"the acceptance script printed no CLAIM {claim} line; the row it supports is "
                 "unearned rather than earned quietly")
        for ext in installed:
            e = inv["extensions"][ext]
            got = e[key] if key == "ext_ports_calls" else len(e[key])
            if got != want:
                fail(f"CLAIM {claim} says {key}={want} for every installed closure and classifier 3 "
                     f"reports {got} for '{ext}'")
    print(f"  ✓ CLAIM row3c/row4 re-derived: 0 ExtPorts field calls across all {len(installed)} "
          "installed closures, so no installed hook can issue extension_effect_fault's world request")
    print(f"  ✓ CLAIM row5 re-derived: 0 ambient sources across all {len(installed)} installed "
          "closures, so no installed extension reads a clock and row 5's transferability is a "
          "measurement rather than a consequence of emptiness")

    if "row7" not in out["claim"]:
        fail("the acceptance script printed no CLAIM row7 line")
    check_row_7(out)


def check_row_7(out):
    """Row 7's two facts, each re-derived from the extension's own source.

    S16 enumeration — how an extension can reach the `ScratchpadResult` path,
    written before the scan unit was chosen. The variant is emitted only when a
    tool named `scratchpad` is served by an `on_tool_handle` returning `Handled`
    with a `cells` key, and the dispatch gate is
    `contains_tool(h.provided_tools, name)` (src/core/ext/runtime.ail:356). So
    an extension reaches it only if BOTH:

      (a) `provided_tools` is non-empty. Ways it can be:
            1. an inline list literal — the shape all four use;
            2. a named identifier or function call — CANNOT be decided by this
               scan, so it FAILS rather than passing;
            3. built from config inside `register_with_config` — same, FAILS.
      (b) `on_tool_handle` can return `Handled`. Ways it can be bound:
            1. an inline `func`/lambda whose body names the constructor — the
               shape all four use;
            2. a reference to a named top-level function — CANNOT be decided
               without following it, so it FAILS;
            3. a value threaded from elsewhere — FAILS.

    Only shape 1 of each is admitted. Every other shape is a FAIL, which is the
    fail-closed direction: this scan can refuse an extension that in fact never
    emits, and cannot bless one that does.
    """
    dirs = {v: k for k, v in installable_extension_dirs().items()}
    for ext in sorted(out["installed"]):
        pkg = REPO / dirs[ext]
        srcs = sorted(pkg.glob("*.ail"))
        hit = None
        for s in srcs:
            text = s.read_text()
            if "provided_tools:" in text and "on_tool_handle:" in text:
                hit = (s, text)
                break
        if hit is None:
            fail(f"could not find the ExtensionHooks record for '{ext}' under {dirs[ext]}; row 7's "
                 "exemption cannot be re-derived, so it is not earned")
        path, text = hit

        pt = re.search(r"provided_tools:\s*(\[[^\]]*\]|\S+)", text)
        if not pt:
            fail(f"'{ext}' has no readable `provided_tools` binding in {path.name}")
        if pt.group(1).strip() != "[]":
            fail(f"'{ext}' binds `provided_tools: {pt.group(1).strip()}`, which is not the empty\n"
                 "      literal this scan can decide. Row 7's first fact is UNVERIFIED — fail-closed,\n"
                 "      because a non-empty or computed tool list opens the gated on_tool_handle\n"
                 "      dispatch and with it the ScratchpadResult path.")

        th = re.search(r"on_tool_handle:\s*(.*?)(?=\n\s{2,4}on_[a-z_]+:|\n\s*\}\s*\n)", text, re.S)
        if not th:
            fail(f"could not read '{ext}'s `on_tool_handle` binding in {path.name}")
        body = th.group(1)
        if "func(" not in body and "\\" not in body:
            fail(f"'{ext}' binds `on_tool_handle` to something this scan cannot follow "
                 f"({body.strip()[:60]!r}); row 7's second fact is UNVERIFIED — fail-closed")
        if "Handled" in body:
            fail(f"'{ext}'s `on_tool_handle` can return `Handled`, which is the constructor the\n"
                 "      ScratchpadResult path needs. Row 7's exemption does not hold for this profile.")
        if "Delegate" not in body:
            fail(f"'{ext}'s `on_tool_handle` returns neither `Handled` nor `Delegate`; the scan "
                 "cannot decide it")

    print(f"  ✓ CLAIM row7 re-derived from source: all {len(out['installed'])} installed extensions "
          "bind `provided_tools: []` (so the gated on_tool_handle dispatch is never reached) AND "
          "return `Delegate`, never `Handled` — two independent facts, neither of them emptiness")


def check_statement(out):
    """The coverage statement is the successor to WI-D5's mandatory zero-coverage
    caveat, so it is checked for the two things a reader must not be able to
    miss: that it says the coverage is non-zero, and that it says none of it
    mediates. A number without the second half is exactly the "fifth vacuity
    with a number attached" WI-D13 declined to create."""
    s = out["statement"]
    if not s:
        fail("the acceptance script printed no STATEMENT line, so the result carries a coverage "
             "number with no statement of what it means")
    covered = sum(1 for k in out["classification"].values() if k[0] != "explicitly_excluded")
    if str(covered) not in s:
        fail(f"the statement does not name the covered-hook count ({covered}): {s!r}")
    mediating = sum(1 for k in out["classification"].values() if k[3] == "substantively")
    missing = [m for m in ("NO-OPS", "NONE of the world-mediation machinery") if m not in s]
    if mediating == 0 and missing:
        fail(f"the coverage is entirely of no-ops ({mediating} hook(s) mediate a port\n"
             f"      substantively) and the statement omits {missing}. A non-zero number without\n"
             "      that half is the shape WI-D13 declined to create — a vacuity with a number\n"
             f"      attached: {s!r}")
    print(f"  ✓ the coverage statement names the number AND what it means: {covered} covered "
          "hook(s), entirely no-ops, exercising none of the world-mediation machinery")


def main():
    if len(sys.argv) != 2:
        fail("usage: check_no_op_profile.py <acceptance-script-output>")
    out = parse_output(sys.argv[1])
    inv = ambient_inventory()

    needed, resolved = set(inv["std_modules_needed"]), set(inv["std_modules_resolved"])
    if needed - resolved or inv["provision_failures"] or inv["producer_disagreements"]:
        fail("classifier 3 did not fully resolve, so no installed extension's criterion-2 evidence "
             f"is admissible: unresolved {sorted(needed - resolved)}. Every check below would be "
             "reading a partial verdict, which is not a verdict.")

    slots = abi_slots()
    check_install_set(out, inv, slots)
    check_classifications(out, inv, slots)
    check_claims(out, inv)
    check_statement(out)
    print("  ✓ no claim in this profile is a stale transcription: the install set, every "
          "classification, every clause status and every row claim was re-derived")


if __name__ == "__main__":
    main()
