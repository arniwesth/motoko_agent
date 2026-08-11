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
    """
    slots = ["on_budget_plan", "on_pre_step", "on_tool_handle",
             "on_response_intercept", "on_solver_candidate"]

    barriers, covered, gated = [], [], []
    for slot in slots:
        # `\s*` spans newlines: two of these five slots wrap their arrow onto
        # the next line, and a line-anchored pattern would read them as rowless.
        m = re.search(re.escape(slot) + r":\s*\([^)]*\)\s*->\s*\w+\s*(!\s*\{([^}]*)\})?",
                      abi, re.M)
        if not m:
            fail(f"could not read `{slot}`'s declaration in {ABI_TYPES.relative_to(REPO)} — "
                 "the barrier count cannot be derived, so installability is unknown")
        row = (m.group(2) or "").strip()

        # The dispatch classification is a SECOND producer: it lives in
        # dst_profile_coverage.ail, not in the ABI, and neither derives from
        # the other (S16).
        camel = "On" + "".join(p.capitalize() for p in slot.removeprefix("on_").split("_"))
        if not re.search(camel + r"\s*=>\s*Unconditional", disp):
            gated.append(slot)
        elif row:
            barriers.append((slot, row))
        else:
            covered.append(slot)

    n = len(barriers)
    print(f"  ✓ barrier count DERIVED from the ABI rows and the dispatch table: {n}")
    for slot, row in barriers:
        print(f"      BARRIER  {slot}: unconditionally dispatched, declares ! {{{row}}}")
    for slot in covered:
        print(f"      coverable {slot}: unconditionally dispatched, declares NO row")
    for slot in gated:
        print(f"      gated     {slot}: excludable, so not a barrier")

    if n == 0:
        fail("the barrier count has reached ZERO: every unconditionally-dispatched hook\n"
             "      declares an empty effect row, so an extension IS now installable in a\n"
             "      conformant profile. That is WI-C5's trigger and it must be DECIDED, not\n"
             "      inherited as a side effect of an ABI edit. Re-decide driver_only's empty\n"
             "      install list, and note that installing anything is a coverage claim and a\n"
             "      profile version bump. See the header of src/core/dst_driver_only.ail.")

    print(f"    → {n} barrier(s) stand, so NO extension is installable in a conformant profile")
    print("    → driver_only's empty install list is therefore still not a free choice")


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

    print("  ✓ no fact in the fixtures is a stale transcription of the tool's output")


if __name__ == "__main__":
    main()
