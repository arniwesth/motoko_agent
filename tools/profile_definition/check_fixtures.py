#!/usr/bin/env python3
"""WI-A10's anti-transcription guard for `make profile_definition`.

The profile machinery composes facts that other artifacts already computed. Most
of those it reads directly at runtime, in AILANG, so they cannot go stale. Two
cannot be read that way, because they are derived from the SOURCE by a Python
tool rather than declared in an AILANG module:

  * classifier 2's membership set and its `unrouted` set
    (`tools/ext_call_inventory/derive.py`), and
  * which member call sites belong to an INSTALLABLE extension.

Those enter the AILANG fixtures as literals, and a literal is exactly what goes
stale silently — both readings type-check and the wrong one is quiet. This
script is what makes them not stale: it re-derives each one from the tool and
from `ailang.toml` and fails if the AILANG side disagrees.

Three checks, and the third is the one that matters:

  1. the recorded classifier-2 set equals the tool's, member for member;
  2. the recorded unrouted-field set equals the tool's. An unrouted field is a
     DISTINCT state, not a non-member -- treating it as a non-member would
     silently bless an extension reading an ambient clock. `clock_now` was the
     only member until WI-C5 widened it to thread the world token, so the set is
     EMPTY at HEAD and this check is currently vacuous; it is kept because the
     next un-widened seam re-populates it, and because an empty set that is
     re-derived is not the same claim as one that is assumed;
  3. every member call site that lives inside an installable extension package
     is named in the AILANG fixture's classifier-2 call list, so the fixture
     cannot omit an extension that the tool found and stay green.

Check 3 is what stops `driver_only`'s omission list from being a guess: the day
a second extension calls a state-threading seam, this goes red rather than the
profile quietly claiming coverage it does not have.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FIXTURE = REPO / "scripts/dst/profile_definition_dst.ail"
PROFILE = REPO / "src/core/dst_driver_only.ail"
AILANG_TOML = REPO / "ailang.toml"


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def derive():
    out = subprocess.check_output(
        [sys.executable, str(REPO / "tools/ext_call_inventory/derive.py"), "--json"],
        cwd=REPO,
    )
    return json.loads(out)


def literal_list(src, field):
    """Extract the string members of an AILANG list literal `field: [...]`."""
    m = re.search(re.escape(field) + r":\s*\[(.*?)\]", src, re.S)
    if not m:
        fail(f"could not find '{field}' in the AILANG source; the fixture moved")
    return sorted(re.findall(r'"([^"]*)"', m.group(1)))


def installable_extension_dirs():
    """package source dir -> extension id, for entries in [extensions] packages.

    `[extensions] packages` names `sunholo/motoko_ext_<id>@<ver>`; `[dependencies]`
    maps the same package name to a path. Only extensions in the FIRST list can
    appear in a profile's install list, so only their call sites are a
    profile-definition concern -- a call site inside a fixture package such as
    `motoko_ext_conformance` is not installable and must not force an omission.
    """
    toml = AILANG_TOML.read_text()
    ext_block = re.search(r"\[extensions\](.*?)(?:\n\[|\Z)", toml, re.S)
    if not ext_block:
        fail("ailang.toml has no [extensions] block")
    installable = set(re.findall(r'"(sunholo/motoko_ext_[a-z0-9_]+)@', ext_block.group(1)))

    paths = {}
    for pkg, path in re.findall(r'"(sunholo/motoko_ext_[a-z0-9_]+)"\s*=\s*\{\s*path\s*=\s*"([^"]+)"', toml):
        if pkg in installable:
            paths[path.rstrip("/")] = pkg[len("sunholo/motoko_ext_"):]
    missing = installable - {f"sunholo/motoko_ext_{v}" for v in paths.values()}
    if missing:
        fail(f"installable extensions with no path dependency, so no scannable source: {sorted(missing)}")
    return paths


def owning_extension(file_path, dirs):
    for d, ext_id in dirs.items():
        if file_path.startswith(d + "/"):
            return ext_id
    return None


ABI_TYPES = REPO / "packages/motoko-ext-abi/types.ail"


def check_omission_basis(profile_src, required):
    """WI-B4. Check 3 above re-derives `driver_only`'s omission list from
    `member_call_sites`, and until WI-B2b that was a real check: `compaction_ai`
    called `ExtPorts.ai_step`, `ai_step` was a classifier-2 member, so the list
    could not silently drop it. B2b widened `ai_step` to return `AiStepOutcome`.
    It left the classifier-2 set, `member_call_sites` went empty, and check 3
    became VACUOUS — it now passes because it requires nothing, which is
    indistinguishable from passing because everything is right.

    The omission is still correct, but its basis moved from classifier 2 to D5's
    coverage criterion read on DECLARED effect rows.

    ===================================================================
    THE BASIS MOVED AGAIN AT WI-D6 (2026-08-06), AND THIS GUARD FIRED TO
    MAKE IT MOVE DELIBERATELY.
    ===================================================================

    WHAT THIS GUARD USED TO ASSERT, and it was correct from WI-B4 until
    2026-08-06 — kept here in the past tense per plan rule S15 rather than
    rewritten, because it is a record of why the omission stood for five items:

        `ExtensionHooks.on_budget_plan` is unconditionally dispatched, declares
        a NON-EMPTY effect row, and returns a type with no successor field.

    Rows are closed, so that row was not a property of any one binding — every
    implementation in the tree declared exactly it. `Env` and `FS` are not
    world-mediated ports, so criterion 1 failed on the declared row;
    `BudgetPatch` carries no successor, so criterion 2 failed for want of
    returned world state. D5 forbids installing an extension with any
    unconditionally-dispatched hook excluded, so no extension was installable at
    all and the empty install list was FORCED.

    The docstring said this would go red the day `on_budget_plan` was widened,
    "which is exactly the day the omission has to be decided again rather than
    inherited". WI-D6 NARROWED it instead of widening it, the guard fired
    anyway on the same clause, and the omission was decided again. That is the
    guard working: it did not care which direction the row moved, only that the
    basis had changed.

    WHAT THIS GUARD ASSERTS NOW. The polarity of the row check is INVERTED:
    `on_budget_plan` must declare NO effect row. The other three clauses are
    unchanged, because they are still true and still load-bearing for a
    different conclusion.

    AND THE CONCLUSION IS WEAKER, WHICH IS THE POINT. `driver_only` still
    installs nothing and still covers nothing — but the empty install list is
    now CHOSEN rather than FORCED. A chosen emptiness covers exactly as much as
    a forced one. What changed is that a future profile CAN install an
    extension; this one still does not, and that is a decision this file
    records rather than a consequence it derives.
    """
    abi = ABI_TYPES.read_text()

    m = re.search(r"^\s*on_budget_plan:\s*\([^)]*\)\s*->\s*(\w+)\s*(!\s*\{([^}]*)\})?",
                  abi, re.M)
    if not m:
        fail("could not read `on_budget_plan`'s declaration in "
             f"{ABI_TYPES.relative_to(REPO)} — the omission basis cannot be checked")
    ret_type, row = m.group(1), (m.group(3) or "").strip()

    if row:
        fail(f"`ExtensionHooks.on_budget_plan` declares an effect row again: ! {{{row}}}.\n"
             "      WI-D6 narrowed it to none after measuring all fifteen bindings and\n"
             "      finding that not one performs Env or FS (see `make declared_vs_performed`).\n"
             "      A row here makes the slot fail D5 criterion 1 on DECLARED effects, which\n"
             "      makes EVERY extension in the tree un-installable again. If that is\n"
             "      intended, re-decide the omission basis; do not inherit it. See the header\n"
             "      of src/core/dst_driver_only.ail.")

    rm = re.search(r"^export type " + re.escape(ret_type) + r"\s*=\s*\{(.*?)\}", abi, re.M | re.S)
    if not rm:
        fail(f"could not read `{ret_type}` in {ABI_TYPES.relative_to(REPO)}")
    # Still checked, and still meaningful: criterion 1 now carries the slot, so
    # a successor appearing here would mean the slot ALSO satisfies criterion 2.
    # That is not a problem, but it is a change of basis and must be noticed.
    if "next_state" in rm.group(1):
        fail(f"`{ret_type}` now carries a successor field, so `on_budget_plan` satisfies\n"
             "      D5 criterion 2 as well as criterion 1. That is a wider claim than the one\n"
             "      WI-D6 recorded — re-decide the basis rather than inheriting it.")

    disp = (REPO / "src/core/dst_profile_coverage.ail").read_text()
    if not re.search(r"OnBudgetPlan\s*=>\s*Unconditional", disp):
        fail("`OnBudgetPlan` is no longer unconditionally dispatched, so excluding it is a\n"
             "      coverage cost rather than a rejection. driver_only's omission basis has\n"
             "      changed — re-decide it.")

    if "compaction_ai" not in re.findall(r'extension_id:\s*"([^"]+)",\s*reason:', profile_src):
        fail("driver_only no longer omits `compaction_ai`, and check 3 above can no longer\n"
             "      require it (zero classifier-2 member call sites). If installing it is\n"
             "      intended, that is a coverage claim and a profile version bump.")

    print(f"  ✓ omission basis intact: on_budget_plan is Unconditional, declares NO effect "
          f"row (WI-D6; was ! {{Env, FS}} through WI-D5), and returns {ret_type} (no successor)")
    if not required:
        print("    ! note: check 3 is now VACUOUS (zero classifier-2 member call sites). "
              "This check, not that one, is what holds the omission.")

    check_barrier_count(abi, disp)


def check_barrier_count(abi, disp):
    """WI-D7. THE INSTALLABILITY QUESTION, DERIVED RATHER THAN ASSERTED.

    THIS CHECK EXISTS BECAUSE THE LINE IT REPLACES WAS FALSE. Through WI-D6
    this file printed, on every run:

        → the slot is coverable under D5 criterion 1, so an extension IS
          installable

    and it does not follow. `on_budget_plan` was ONE of FOUR unconditionally
    dispatched slots. D5 forbids installing an extension with any
    unconditionally-dispatched hook excluded, so ALL of them must be coverable
    before any extension is installable, and the other three were not. D6's
    report and its design-document edit inherited the same wrong conclusion;
    `dst_driver_only.ail` stated it correctly at the same time, and the two
    disagreed with nothing going red. That is what this function fixes: the
    count is now DERIVED from the ABI and the dispatch table on every run, so
    no artifact can carry a stale answer to it.

    THE RULE, read straight off D5: a slot is a BARRIER when it is
    unconditionally dispatched AND declares a non-empty effect row. A non-empty
    row fails criterion 1 outright. It could still pass criterion 2, but only
    if every effect in it is a world-mediated port — and none of the effects in
    any of these rows is. So a non-empty row on an unconditionally-dispatched
    slot is a barrier, and the count of barriers is the number of things
    standing between this tree and an installable extension.

    WHAT GOES RED, AND WHY THAT IS THE POINT. If the count reaches ZERO, an
    extension becomes installable and the omission has to be DECIDED rather
    than inherited — which is WI-C5's trigger, not an ABI edit's side effect.
    This is B4's guard shape, which WI-D6 recorded as the standard: pin the
    FACT, not the direction, so the check fires whichever way the row moves.

    =========================================================================
    RE-SHAPED AT WI-D13 (2026-08-07): A BARRIER IS A PROPERTY OF THE
    (EXTENSION, SLOT) PAIR, NOT OF THE SLOT.
    =========================================================================

    Everything above is RETAINED and still computed — see `slot_barriers`
    below, which is that derivation unchanged, and the trigger on it unchanged.
    What follows is a second, finer derivation over the same inputs plus one
    more, and the reason it exists is that the coarse one CANNOT ANSWER THE
    QUESTION IT IS ASKED. ADR-001 Amendment A states it (`ADR:1580`): the rule
    above reads the ABI row and the dispatch table, both per-SLOT facts shared
    by all fifteen extensions, while D5 criterion 2 is a claim about a hook of
    an INSTALLED extension. The old derivation cannot tell one extension from
    another, so it answered every extension's question with one number.

    THE THIRD PRODUCER, and it is why the finer derivation is possible now and
    was not at WI-D7. `tools/ext_ambient_inventory/derive.py` — classifier 3,
    built at WI-D12 — decides PER EXTENSION whether every effect it can perform
    arrives through an `ExtPorts` field call, over the extension's transitive
    module closure. It is the only producer in this tree that can supply
    criterion 2's evidence, because criterion 2 is a claim about the CALL PATH
    and every row-reading instrument is blind to provenance by construction
    (`ADR:1449`). Per S16 it is a genuinely separate producer: it reads imports
    and call names, never the declaration being tested.

    CRITERION 2 IS A CONJUNCTION OF THREE CLAUSES (WI-B4 read it that way and
    was right; reading it as one test is how it gets passed):

        (1) effectful only through D1 world-mediated ports
        (2) with origin tagged by extension id
        (3) and explicit world state returned to the host

    and this derivation clears a barrier only when it can discharge ALL THREE:

        (1) classifier 3 reports the extension PORT-MEDIATED.
        (3) the slot's OUTCOME TYPE carries an explicit `next_state` field,
            read from the ABI's own type declaration rather than assumed.
        (2) classifier 3 reports ZERO `ExtPorts` field calls in the closure, so
            there is nothing to tag and the clause is VACUOUS.

    Clause (2) is the fail-closed one and the honest one. This tree has NO
    producer for "is this port call origin-tagged" — WI-B4 established that
    `PreStepStage = { ext_id, outcome }` tags `on_pre_step`'s dispatch, and that
    is one slot read by hand, not a derivation. So this check does not clear a
    barrier for an extension that actually calls a port: it refuses, and says
    which clause it cannot discharge. The consequence is stated rather than
    discovered, and Amendment A predicted it (`ADR:1611`): **the first hooks
    this clears are ones that PERFORM NOTHING, not ones that mediate.**

    CRITERION 1 IS NOT AVAILABLE HERE AND IS NOT USED. In substance these hooks
    are effect-free, which is criterion 1's text — but criterion 1's basis is
    the DECLARED ROW (`ADR:1415` records it as an assumption), the declared rows
    on these slots are non-empty, and a named binding cannot declare narrower
    than a closed ABI slot. Amendment A deliberately WITHHELD criterion 1 from
    its scope, so admitting a measurement there is an ADR-scope act and not this
    file's. Every clearance below is criterion 2.

    WHAT GOES RED AT THIS GRANULARITY. The slot-level trigger above is
    unchanged. The new one is its (extension, slot) analogue and has the same
    shape: an extension whose barrier count reaches ZERO is INSTALLABLE, and
    that must be DECIDED rather than inherited — so it must be accounted for by
    name in the profile, either installed or omitted. Naming it is not a
    coverage claim; INSTALLING it is, and that is WI-C5's.
    """
    slots = ["on_budget_plan", "on_pre_step", "on_tool_handle",
             "on_response_intercept", "on_solver_candidate"]

    slot_barriers, covered, gated = [], [], []
    returns_world = {}
    for slot in slots:
        # `\s*` spans newlines: two of these five slots wrap their arrow onto
        # the next line, and a line-anchored pattern would read them as rowless.
        m = re.search(re.escape(slot) + r":\s*\([^)]*\)\s*->\s*(\w+)\s*(!\s*\{([^}]*)\})?",
                      abi, re.M)
        if not m:
            fail(f"could not read `{slot}`'s declaration in {ABI_TYPES.relative_to(REPO)} — "
                 "the barrier count cannot be derived, so installability is unknown")
        row = (m.group(3) or "").strip()
        returns_world[slot] = outcome_returns_world(abi, m.group(1))

        # The dispatch classification is a SECOND producer: it lives in
        # dst_profile_coverage.ail, not in the ABI, and neither derives from
        # the other (S16).
        camel = "On" + "".join(p.capitalize() for p in slot.removeprefix("on_").split("_"))
        if not re.search(camel + r"\s*=>\s*Unconditional", disp):
            gated.append(slot)
        elif row:
            slot_barriers.append((slot, row))
        else:
            covered.append(slot)

    n = len(slot_barriers)
    print(f"  ✓ SLOT-level barrier count DERIVED from the ABI rows and the dispatch table: {n}")
    for slot, row in slot_barriers:
        print(f"      BARRIER  {slot}: unconditionally dispatched, declares ! {{{row}}}"
              f"  (outcome returns world state: {'yes' if returns_world[slot] else 'NO'})")
    for slot in covered:
        print(f"      coverable {slot}: unconditionally dispatched, declares NO row")
    for slot in gated:
        print(f"      gated     {slot}: excludable, so not a barrier")

    if n == 0:
        fail("the SLOT-level barrier count has reached ZERO: every unconditionally-dispatched\n"
             "      hook declares an empty effect row, so an extension IS now installable in a\n"
             "      conformant profile. That is WI-C5's trigger and it must be DECIDED, not\n"
             "      inherited as a side effect of an ABI edit. Re-decide driver_only's empty\n"
             "      install list, and note that installing anything is a coverage claim and a\n"
             "      profile version bump. See the header of src/core/dst_driver_only.ail.")

    print(f"    → {n} slot-level barrier(s) stand: no extension is installable on the DECLARED ROW alone")
    check_per_extension_barriers(slot_barriers, returns_world)


def outcome_returns_world(abi, type_name):
    """Criterion 2 clause 3, DERIVED from the ABI's type declaration.

    Per S16, the ways a slot's outcome type can carry explicit world state were
    enumerated BEFORE the unit was chosen, because a scan that finds one shape
    and silently misses four is a fail-open:

      (a) a literal `next_state` field on a flat record type. All four outcome
          types in this ABI are this shape, and it is deliberate — the ABI's own
          comment says `next_state` is "named for the criterion, not for taste"
          and to satisfy `derive.py`'s SUCCESSOR_FIELD.
      (b) a nested record carrying the field one level down. None exists.
      (c) an alias, `export type X = Y`, to a record that carries it. None.
      (d) a type parameter instantiated to something carrying it. None.
      (e) the field renamed. The name is load-bearing by design, per (a).

    Only (a) is matched, and every other shape reads as ABSENT — which leaves
    the barrier STANDING. That is the fail-closed direction: this function can
    refuse a hook that in fact returns world state, and cannot clear one that
    does not.
    """
    m = re.search(r"export\s+type\s+" + re.escape(type_name) + r"\s*=\s*\{([^}]*)\}", abi, re.S)
    if not m:
        return False
    return re.search(r"\bnext_state\s*:", m.group(1)) is not None


def ambient_inventory():
    """Classifier 3's per-extension verdict. The third producer (S16)."""
    out = subprocess.check_output(
        [sys.executable, str(REPO / "tools/ext_ambient_inventory/derive.py"), "--json"],
        cwd=REPO,
    )
    return json.loads(out)


def check_per_extension_barriers(slot_barriers, returns_world):
    """WI-D13's derivation: barriers per (extension, slot). See the long note
    in `check_barrier_count` for the rule and for why clause 2 fails closed."""
    inv = ambient_inventory()
    exts = inv["extensions"]

    # Fail-closed on the instrument itself, on classifier 3's own discipline: a
    # verdict derived from a partial resolution is not a verdict. This mirrors
    # the tool's own RESOLUTION gate rather than trusting that it ran.
    needed, resolved = set(inv["std_modules_needed"]), set(inv["std_modules_resolved"])
    if needed - resolved or inv["provision_failures"] or inv["producer_disagreements"]:
        fail("classifier 3 did not fully resolve, so no extension's criterion-2 evidence is\n"
             f"      admissible: unresolved {sorted(needed - resolved)}, "
             f"provision failures {inv['provision_failures']}, "
             f"producer disagreements {inv['producer_disagreements']}.\n"
             "      Every extension keeps every barrier. Re-run `make ext_ambient_inventory`.")

    installable = set(installable_extension_dirs().values())
    cleared, standing = {}, {}
    for ext_id in sorted(installable):
        e = exts.get(ext_id)
        if e is None:
            fail(f"extension '{ext_id}' is installable per ailang.toml and classifier 3 has no\n"
                 "      verdict for it, so its criterion-2 evidence is missing. Fail-closed: the\n"
                 "      barrier count for it is unknown, not zero.")
        port_mediated = e["verdict"] == "PORT-MEDIATED"
        nothing_to_tag = e["ext_ports_calls"] == 0
        for slot, row in slot_barriers:
            if port_mediated and nothing_to_tag and returns_world[slot]:
                cleared.setdefault(ext_id, []).append(slot)
            else:
                if port_mediated and returns_world[slot] and not nothing_to_tag:
                    why = (f"clause 2 UNDISCHARGED: {e['ext_ports_calls']} ExtPorts field call(s) in "
                           "the closure and this tree has no origin-tagging producer")
                elif not port_mediated:
                    why = f"clause 1 fails: {len(e['ambient'])} ambient source(s) in the closure"
                else:
                    why = "clause 3 fails: the outcome type returns no explicit world state"
                standing.setdefault(ext_id, []).append((slot, why))

    zero = sorted(e for e in installable if not standing.get(e))
    pairs = sum(len(v) for v in standing.values())
    total = len(installable) * len(slot_barriers)

    print(f"  ✓ barrier count RE-DERIVED per (extension, slot) — classifier 3 is the third "
          f"producer: {pairs} of {total} pairs stand")
    for ext_id in sorted(cleared):
        slots_c = ", ".join(cleared[ext_id])
        rest = len(standing.get(ext_id, []))
        print(f"      CLEARED for '{ext_id}': {slots_c}"
              + (f"  ({rest} still standing)" if rest else "  — ZERO barriers remain"))
    if not cleared:
        print("      no extension clears any barrier; the pair derivation agrees with the "
              "slot derivation, which is the state through WI-D12")
    for ext_id in sorted(standing):
        if ext_id in cleared:
            for slot, why in standing[ext_id]:
                print(f"      standing for '{ext_id}': {slot} — {why}")
    n_all = len(installable) - len(cleared)
    print(f"      all {len(slot_barriers)} barriers stand unchanged for the other {n_all} extension(s)")

    if not zero:
        print("    → no extension has reached ZERO barriers, so driver_only's empty install "
              "list is still not a free choice")
        return

    # THE TRIGGER, at the granularity the re-shape introduced. An extension at
    # zero barriers is INSTALLABLE. Naming it is not a coverage claim; leaving
    # it unnamed is inheriting the decision, which is the thing WI-D7's trigger
    # was written to refuse.
    profile_src = PROFILE.read_text() if PROFILE.exists() else ""
    named = set(re.findall(r'extension_id:\s*"([^"]+)",\s*reason:', profile_src))
    named |= set(re.findall(r'extension_id:\s*"([^"]+)",\s*package_id:', profile_src))
    unaccounted = sorted(set(zero) - named)
    if unaccounted:
        fail("the barrier count has reached ZERO for extension(s) "
             f"{unaccounted},\n"
             "      which the profile neither installs nor omits by name. Those extensions ARE\n"
             "      now installable in a conformant profile, on D5 criterion 2 established by\n"
             "      measurement (classifier 3), and that must be DECIDED rather than inherited.\n"
             "      This is WI-D7's trigger at the granularity WI-D13 gave it: a barrier is a\n"
             "      property of the (extension, slot) pair, so it can reach zero for one\n"
             "      extension without any ABI row moving.\n"
             "      Naming an extension in omitted_extensions is NOT a coverage claim and is\n"
             "      the conservative discharge. INSTALLING one is a coverage claim and a\n"
             "      profile version bump, and it belongs to WI-C5.\n"
             "      See the header of src/core/dst_driver_only.ail.")

    print(f"    → ZERO barriers remain for {zero}, so those extensions ARE installable")
    print("    → each is accounted for BY NAME in the profile, so the empty install list is a "
          "CHOICE rather than a consequence for them, and a consequence still for the rest")


MAKEFILE = REPO / "Makefile"
PROFILE_MODULE = REPO / "src/core/dst_profile.ail"


def check_recognised_producers():
    """WI-D13. `recognised_producers` in src/core/dst_profile.ail is the closed
    set of instruments a classification's `basis` may name, and it is a
    TRANSCRIPTION of facts that live outside AILANG: three Python tools with
    Makefile targets, plus two non-instrument bases the ADR names.

    A transcription is exactly what goes stale silently, which is this script's
    whole reason for existing. So the MEASURED producers are re-derived: each
    must have a real `.PHONY` target behind it. A basis naming an instrument
    that no longer exists reads as evidence and is worse than a blank one.

    The two ASSUMED producers are deliberately not checked against the Makefile
    — `declared_row` and `disclosure` are not tools and have no target. That is
    the point of the kind: it separates "an instrument answered" from "we read a
    declaration", which is the distinction `basis` was added to make visible.
    """
    src = PROFILE_MODULE.read_text()
    block = re.search(r"export pure func recognised_producers\(\).*?\n}", src, re.S)
    if not block:
        fail("could not find `recognised_producers` in src/core/dst_profile.ail; the basis\n"
             "      catalogue moved and this guard cannot re-derive it, so an unrecognised\n"
             "      producer could pass unnoticed")
    entries = re.findall(r'producer_id:\s*"([^"]+)",\s*\n?\s*kind:\s*(\w+)', block.group(0))
    if not entries:
        fail("`recognised_producers` parsed to ZERO entries. An empty closed set accepts no\n"
             "      basis at all, and a guard that re-derives nothing cannot be told from one\n"
             "      that does not run — the `agree=0 disagree=0` shape, one artifact over.")

    makefile = MAKEFILE.read_text()
    measured = [pid for pid, kind in entries if kind == "Measured"]
    missing = [p for p in measured if not re.search(r"^\.PHONY:.*\b" + re.escape(p) + r"\b",
                                                    makefile, re.M)]
    if missing:
        fail(f"`recognised_producers` names measured producer(s) {missing} with no .PHONY\n"
             "      target in the Makefile. A basis may name them and the gate would accept it,\n"
             "      so the record would carry evidence from an instrument this tree cannot run.")
    kinds = {pid: kind for pid, kind in entries}
    print(f"  ✓ classification-basis producers re-derived: {len(measured)} measured, each with a "
          f"Makefile target ({', '.join(sorted(measured))}); "
          f"{len(entries) - len(measured)} assumed, deliberately without one "
          f"({', '.join(sorted(p for p, k in kinds.items() if k == 'Assumed'))})")


def main():
    data = derive()
    fixture = FIXTURE.read_text()

    live_c2 = sorted(data["classifier_2_set"])
    live_unrouted = sorted(data["unrouted_fields"])

    recorded_c2 = literal_list(fixture, "classifier_2_set")
    recorded_unrouted = literal_list(fixture, "unrouted_fields")

    if recorded_c2 != live_c2:
        fail(
            "the manifest fixture records classifier-2 set "
            f"{recorded_c2} but the tool derives {live_c2}.\n"
            "      The set is a property of the SOURCE at the scanned revision, and the\n"
            "      fixture transcribed it. Re-read it from `make ext_call_inventory --json`."
        )
    print(f"  ✓ classifier-2 set matches the tool: {live_c2}")

    if recorded_unrouted != live_unrouted:
        fail(
            f"the manifest fixture records unrouted fields {recorded_unrouted} but the "
            f"tool derives {live_unrouted}"
        )
    print(f"  ✓ unrouted-field set matches the tool: {live_unrouted} (a DISTINCT state, not a non-member)")

    dirs = installable_extension_dirs()
    named_in_fixture = set(re.findall(r'extension_id:\s*"([^"]+)",\s*field:', fixture))

    required = {}
    for site in data["member_call_sites"]:
        ext_id = owning_extension(site["file"], dirs)
        if ext_id is not None:
            required.setdefault(ext_id, []).append(f"{site['file']}:{site['line']} ({site['field']})")

    missing = sorted(set(required) - named_in_fixture)
    if missing:
        fail(
            f"the tool found classifier-2 calls in installable extension(s) {missing} that the\n"
            "      AILANG fixture does not name. A profile validated against an incomplete call\n"
            "      list can install an extension that must be omitted, and load clean.\n"
            + "".join(f"\n        {e}: {', '.join(required[e])}" for e in missing)
        )
    for ext_id, sites in sorted(required.items()):
        print(f"  ✓ classifier-2 caller '{ext_id}' is named in the fixture ({len(sites)} site(s))")

    # And the profile, once it exists: every installable classifier-2 caller must
    # be OMITTED by name. This is the check that keeps `driver_only`'s omission
    # list honest rather than a guess frozen at authoring time.
    if PROFILE.exists():
        profile_src = PROFILE.read_text()
        omitted = set(re.findall(r'extension_id:\s*"([^"]+)",\s*reason:', profile_src))
        not_omitted = sorted(set(required) - omitted)
        if not_omitted:
            fail(
                f"{PROFILE.relative_to(REPO)} does not name {not_omitted} in omitted_extensions,\n"
                "      but the tool found a classifier-2 call in it. D1/D5: such an extension must be\n"
                "      OMITTED with a reason, not installed-and-excluded."
            )
        print(f"  ✓ every installable classifier-2 caller is omitted by name in the profile: {sorted(required)}")
        check_omission_basis(profile_src, required)
    else:
        print("  i src/core/dst_driver_only.ail not present yet (machinery commit); profile check skipped")

    check_recognised_producers()
    check_abi_version()
    print("  ✓ no fact in the fixtures is a stale transcription of the tool's output")


ABI_TOML = REPO / "packages/motoko-ext-abi/ailang.toml"


def check_abi_version():
    """WI-D14. The ABI version, re-derived from the package that declares it.

    ADDED BECAUSE IT HAD ALREADY GONE STALE AND NOTHING NOTICED. `driver_only`'s
    `extension.abi` adapter boundary and `driver_only_dst`'s manifest argument
    both said `4.0` from WI-A10 until 2026-08-07; the ABI moved to 5.0 at WI-B2b,
    which added the world token and the four hook outcome records. So a manifest
    whose whole job is exact reproducibility pinned a contract this tree has not
    had for eleven items, and both readings type-check — the manifest's
    `abi_version` is a free string argument.

    That is the composition defect this script exists for, found in the one
    artifact class it had not been pointed at. The version is a fact declared in
    `packages/motoko-ext-abi/ailang.toml`, so it is read from there.
    """
    m = re.search(r'^version\s*=\s*"([^"]+)"', ABI_TOML.read_text(), re.M)
    if not m:
        fail(f"could not read the ABI version from {ABI_TOML.relative_to(REPO)}; a profile's "
             "recorded abi_version cannot be checked against the package that declares it")
    live = m.group(1)

    # EVERY profile, not only `driver_only`. One fact deserves one guard, and a
    # second profile is exactly how the first one's transcription went unnoticed
    # for eleven items — nothing was comparing it to anything.
    subjects = [PROFILE,
                REPO / "scripts/dst/driver_only_dst.ail",
                REPO / "src/core/dst_driver_plus_no_ops.ail",
                REPO / "scripts/dst/driver_plus_no_ops_dst.ail"]
    seen = 0
    for path in subjects:
        if not path.exists():
            continue
        text = path.read_text()
        for stale in re.findall(r"ABI (\d+\.\d+)[.,) ]", text):
            seen += 1
            if stale != live:
                fail(f"{path.relative_to(REPO)} names 'ABI {stale}' and "
                     f"{ABI_TOML.relative_to(REPO)} declares {live}. A profile record or manifest "
                     "that pins the wrong ABI pins nothing.")
        for arg in re.findall(r'_manifest\([^)]*?"([0-9]+\.[0-9]+)"', text, re.S):
            seen += 1
            if arg != live:
                fail(f"{path.relative_to(REPO)} builds a manifest with abi_version '{arg}' and the "
                     f"ABI package declares {live}")
    if seen == 0:
        fail("no profile record names an ABI version at all, so this guard re-derived nothing. "
             "An assertion with no subject cannot be told from one that does not run.")
    print(f"  ✓ the ABI version every profile record names is the one the package declares: {live} "
          f"({seen} site(s) across {len([p for p in subjects if p.exists()])} file(s))")


if __name__ == "__main__":
    main()
