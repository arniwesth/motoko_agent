#!/usr/bin/env python3
"""WI-D27's anti-transcription guard for the THIRD profile.

`check_fixtures.py` guards `driver_only`, whose install list is empty.
`check_no_op_profile.py` guards `driver_plus_no_ops`, which installs four
extensions that perform nothing. This script is the same discipline applied to
the first profile that installs an extension which PERFORMS SOMETHING, and every
check here is one that could not have existed before there was a mediated effect
to ask about.

WHAT IT READS, AND WHY NOT THE SOURCE. It takes the OUTPUT of
`scripts/dst/driver_plus_compose_dst.ail`, not the profile module. The profile is
a computed value — the classification entries are built by folding
`all_hook_slots()`, so the source text does not contain them — and a regex over
the source would be checking the constructor rather than the record. The script
prints one canonical line per entry, per installed package, per omission, per
disclosure, per registration source and per CLAIM; this reads those and compares
each against a producer that is independent of the profile.

THE SEVEN CHECKS. The second and the fifth are the ones with teeth, and neither
exists in either predecessor's guard because neither predecessor could fail them:

  1. installed set == {compose} exactly, and installed + omitted == every
     extension in `ailang.toml`'s `[extensions] packages`, with each recorded
     version matching the resolved one.

  2. **COMPOSE STILL HAS STANDING BARRIERS, AND THE PROFILE MUST NOT CITE A
     CLASSIFIER FOR IT.** Classifier 3 is re-run: if it reports compose anything
     other than AMBIENT, this profile's whole evidentiary argument has changed
     and must be re-decided rather than left standing. And no CLASSIFICATION line
     for compose may name `ext_ambient_inventory` — the producer that cannot
     clear it. This is the check that stops the profile quietly upgrading its own
     basis to the stronger-sounding one.

  3. each CLASSIFICATION line's criterion matches the ABI's rowed/rowless split,
     re-derived from `packages/motoko-ext-abi/types.ail`: a rowed slot may not be
     `effect_free`, a rowless one may not be `world_mediated`.

  4. the ONE excluded slot is the ONE gated slot, re-derived from
     `src/core/dst_profile_coverage.ail`'s dispatch table. D5 forbids excluding
     an unconditionally-dispatched hook, and this profile is the first that
     excludes anything at all. B8: hook ids are ATOM ids `kind[index]`, the
     excluded one is `tool_provider[0]`, and the rowed/rowless split is read
     off the `Capability` payloads and compared with the profile's own
     `rowed_slot_ids()` literal. Check 1 also applies the B8 DENOMINATOR RULE:
     compose's disclosed atoms must equal B2's enumeration of its registration.

  5. **THE DEMONSTRATION HAPPENED AND WAS NON-VACUOUS.** Every criterion-2 entry
     names `discovery`, an EXISTENTIAL producer whose evidence is a run, so the
     guard requires the run's own CLAIM line and requires it to carry at least
     one origin-tagged extension effect, the same count reproduced by the replay,
     and zero mismatches. A profile citing `discovery` with no run behind it is
     the fail-open shape `basis` was added to close, and this is where it fails.

  6. the registration DISCLOSED lines match classifier 3's own ambient-source
     list for compose: every source the profile discloses must be one the
     instrument found, and every {Env, FS} source the instrument found in
     compose's registration files must be disclosed.

  7. the computed STATEMENT is the mediating branch and names a non-zero count.

Per plan rule S16, the enumeration for each new scan is in the function that
performs it, and every unenumerated shape reads as FAIL rather than as absent.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
AILANG_TOML = REPO / "ailang.toml"
COVERAGE = REPO / "src/core/dst_profile_coverage.ail"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_fixtures import ambient_inventory, kind_of  # noqa: E402
from check_no_op_profile import (  # noqa: E402
    abi_slots,
    check_disclosed_atoms_against_b2,
    is_unconditional,
    parse_output,
    resolved_extensions,
)

SUBJECT = "compose"
# B8: hook ids are ATOM ids `kind[index]`; the one gated atom compose registers
# is its ToolProvider at index 0 (`excluded_slot_ids()` in the profile).
EXPECTED_EXCLUDED = "tool_provider[0]"


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def parse_disclosed(path):
    """The `DISCLOSED registration <ext> <cap> <file> <symbol>` lines.

    S16 enumeration — the ways such a line can reach this parser malformed:
      (a) absent entirely, because the scenario did not run. Zero lines is a FAIL
          below, not a vacuous pass;
      (b) wrong arity, because the print gained a field. Checked per line;
      (c) a capability outside {Env, FS}. Registration's disclosed classes are
          exactly those two at this revision; anything else is a new ambient
          class nobody counted and reads as FAIL, never as a skip;
      (d) an extension other than the subject. FAIL — this profile installs one.
    """
    rows = []
    for line in Path(path).read_text().splitlines():
        parts = line.split()
        if not parts or parts[0] != "DISCLOSED":
            continue
        if len(parts) != 6:
            fail(f"a DISCLOSED line has {len(parts)} fields, expected 6: {line!r}. The "
                 "registration disclosure gained or lost a field and the print did not move.")
        _, kind, ext, cap, src, symbol = parts
        if kind != "registration":
            fail(f"unknown DISCLOSED kind {kind!r}; this guard enumerates only `registration`, "
                 "and an unenumerated kind is a disclosure nothing is checking")
        if cap not in ("Env", "FS"):
            fail(f"DISCLOSED registration names capability {cap!r}. Registration's disclosed "
                 "classes are Env and FS at this revision; a third is a new ambient class that "
                 "the 15/15 resolution claim does not account for — measure it, do not add it here")
        if ext != SUBJECT:
            fail(f"DISCLOSED registration names extension {ext!r}, and this profile installs "
                 f"{SUBJECT!r}")
        rows.append((cap, src, symbol))
    return rows


# ---------------------------------------------------------------------------
# 1. The install set and the partition
# ---------------------------------------------------------------------------


def check_install_set(out):
    installed = set(out["installed"])
    if installed != {SUBJECT}:
        fail(f"this profile's install list is {sorted(installed)} and it must be exactly "
             f"['{SUBJECT}']. The profile's whole claim is a RATIO — one mediating hook among "
             "seven covered — and an extra installed extension moves the denominator without "
             "moving the numerator. See `declined_reason` in the profile.")

    resolved = resolved_extensions()
    accounted = installed | out["omitted"]
    missing = set(resolved) - accounted
    extra = accounted - set(resolved)
    if missing:
        fail(f"extension(s) {sorted(missing)} are in ailang.toml's [extensions] packages and "
             "appear in neither this profile's install list nor its omissions. An extension in "
             "neither is a decision INHERITED rather than taken (WI-D7).")
    if extra:
        fail(f"this profile names extension(s) {sorted(extra)} that ailang.toml does not resolve")

    rec_version = out["installed"][SUBJECT][1]
    if rec_version != resolved[SUBJECT]:
        fail(f"the profile records {SUBJECT} at version {rec_version!r} and ailang.toml resolves "
             f"{resolved[SUBJECT]!r}. A manifest whose job is exact reproducibility pins nothing "
             "if the version is a stale transcription.")

    if out["disclosure"] != installed:
        fail(f"the disclosure set {sorted(out['disclosure'])} is not the install set "
             f"{sorted(installed)}; D5 requires one set stated three ways")

    # B8 denominator rule: the disclosed atoms of every installed extension must
    # equal B2's enumeration of its registration literal.
    check_disclosed_atoms_against_b2(out, installed)

    print(f"  ✓ install set re-derived: exactly ['{SUBJECT}'] at {rec_version}, "
          f"+ {len(out['omitted'])} omitted = {len(resolved)} resolved extensions")


# ---------------------------------------------------------------------------
# 2. Compose is NOT classifier-clean, and the record must not pretend otherwise
# ---------------------------------------------------------------------------


def check_the_basis_is_not_classifier_shaped(out, inv):
    e = inv["extensions"].get(SUBJECT)
    if e is None:
        fail(f"classifier 3 has no verdict for '{SUBJECT}'; fail-closed, its evidentiary standing "
             "is unknown rather than unchanged, and this profile's basis argument rests on "
             "knowing what the classifier says")

    if e["verdict"] != "AMBIENT":
        fail(f"classifier 3 now reports '{SUBJECT}' {e['verdict']}, not AMBIENT. THIS IS NOT A "
             "FAILURE, IT IS A DECISION POINT: the profile's entire evidentiary argument is that "
             "the only producer able to speak for compose is the DYNAMIC one, because the static "
             "one cannot clear it. If compose is now classifier-clean the barriers may have "
             "fallen, `ext_ambient_inventory` becomes an admissible basis for it, and the profile "
             "must be re-issued with that decision taken explicitly rather than left standing on "
             "a sentence that is no longer true.")

    for (ext, hook), (kind, producer, _bk, _c1, _c2, _c3) in out["classification"].items():
        if producer == "ext_ambient_inventory":
            fail(f"{ext}/{hook} rests on producer 'ext_ambient_inventory', which reports {ext} "
                 f"AMBIENT ({len(e['ambient'])} source(s)). A classification cannot cite an "
                 "instrument that refuses its subject; the admissible basis here is `discovery`, "
                 "and this is the check that stops the record quietly upgrading to the "
                 "stronger-sounding producer.")

    print(f"  ✓ classifier 3 still reports {SUBJECT} AMBIENT ({len(e['ambient'])} source(s), "
          f"{e['ext_ports_calls']} ExtPorts field call(s)), and NO classification cites it — "
          "the dynamic basis is load-bearing, not decorative")
    return e


# ---------------------------------------------------------------------------
# 3 + 4. The classifications, against the ABI and the dispatch table
# ---------------------------------------------------------------------------


def check_classifications(out, slots):
    seen_excluded = []
    for (ext, hook), (kind, producer, basis_kind, c1, c2, c3) in sorted(out["classification"].items()):
        # B8: `hook` is an atom id `kind[index]`; the row is a fact about the KIND.
        if kind_of(hook) not in slots:
            fail(f"{ext}/{hook} is not an atom of one of the ABI's capability kinds: {sorted(slots)}")
        row = slots[kind_of(hook)][0]
        clauses = (c1, c2, c3)

        if kind == "explicitly_excluded":
            seen_excluded.append(hook)
            if producer != "disclosure":
                fail(f"{ext}/{hook} is excluded on producer {producer!r}; the only admissible "
                     "basis for an exclusion is the profile's own D5 field 9 list")
            if clauses != ("not_applicable",) * 3:
                fail(f"{ext}/{hook} is excluded and records criterion-2 clauses {clauses}; an "
                     "excluded entry carries evidence it does not rest on")
            if is_unconditional(hook):
                fail(f"{ext}/{hook} is EXCLUDED and the dispatch table says it is dispatched "
                     "UNCONDITIONALLY. D5 forbids that: the run could not complete, so the "
                     "extension would have to be omitted instead.")
            continue

        if kind == "effect_free":
            if row:
                fail(f"{ext}/{hook} is classified effect_free and the ABI declares the non-empty "
                     f"row `! {{{row}}}` for it. Criterion 1 fails on the declared row, so this "
                     "entry over-claims — the classification must move to criterion 2 or the slot "
                     "must be excluded.")
            if producer != "declared_row" or basis_kind != "assumed":
                fail(f"{ext}/{hook} is criterion 1 on {producer!r}/{basis_kind!r}; criterion 1's "
                     "basis in this tree is the declared row, and ADR:1415 records it as an "
                     "ASSUMPTION rather than a measurement")
            if clauses != ("not_applicable",) * 3:
                fail(f"{ext}/{hook} is effect_free and records criterion-2 clauses {clauses}")
            continue

        if kind == "world_mediated":
            if not row:
                fail(f"{ext}/{hook} is classified world_mediated and the ABI declares NO effect "
                     "row for it. A rowless slot is coverable under criterion 1 and does not need "
                     "criterion 2's evidence; claiming it anyway reads as stronger evidence than "
                     "the entry has.")
            if producer != "discovery" or basis_kind != "measured":
                fail(f"{ext}/{hook} is criterion 2 on {producer!r}/{basis_kind!r}; this profile's "
                     "criterion-2 basis is the DYNAMIC producer `discovery` and nothing else — "
                     "see check 2 for why no static producer is admissible for compose")
            if "not_applicable" in clauses:
                fail(f"{ext}/{hook} claims criterion 2 and leaves clause(s) unrecorded: {clauses}. "
                     "Criterion 2 is a conjunction of three, so an entry claiming it must say how "
                     "each one holds.")
            if c3 != "substantively":
                fail(f"{ext}/{hook} records world_state {c3!r}. Every ABI outcome record carries "
                     "`next_state`, and compose returns `ctx.world` or a threaded successor at "
                     "every binding, so a non-substantive world-state clause is not a fact about "
                     "this extension.")
            continue

        fail(f"unknown classification {kind!r} on {ext}/{hook}")

    if seen_excluded != [EXPECTED_EXCLUDED]:
        fail(f"this profile excludes {seen_excluded} and the record's whole exclusion argument is "
             f"about {EXPECTED_EXCLUDED!r} — the one GATED slot, whose chain reaches compose's "
             "ambient AI. A different exclusion is a different decision and needs its own reason.")

    rowed = sorted(s for s, (row, _t, _w) in slots.items() if row)
    rowless = sorted(s for s, (row, _t, _w) in slots.items() if not row)
    # The profile states the same split as a literal (`rowed_slot_ids()`) and
    # says this guard fails if it disagrees with types.ail — so it is compared,
    # atom by atom, against the payload rows just read.
    profile_src = (REPO / "src/core/dst_driver_plus_compose.ail").read_text()
    pm = re.search(r"func rowed_slot_ids\(\)[^{]*\{\s*\[(.*?)\]\s*\}", profile_src, re.S)
    if not pm:
        fail("could not read `rowed_slot_ids()` in src/core/dst_driver_plus_compose.ail; the "
             "profile's stated rowed/rowless split cannot be checked against the ABI")
    stated = sorted(re.findall(r'"([^"]+)"', pm.group(1)))
    stated_kinds = sorted({kind_of(a) for a in stated})
    if stated_kinds != rowed:
        fail(f"the profile's `rowed_slot_ids()` names kinds {stated_kinds} and the ABI's "
             f"`Capability` payloads declare rows on {rowed}; both readings type-check and the "
             "stale one is silent — re-read the split from types.ail")
    classified_rowed = sorted({h for (_e, h), (k, *_r) in out["classification"].items()
                               if k != "effect_free"})
    if classified_rowed != stated:
        fail(f"the record classifies atoms {classified_rowed} as rowed (criterion 2 or excluded) "
             f"and the profile's `rowed_slot_ids()` says {stated}")
    print(f"  ✓ every classification re-derived against the ABI's rowed/rowless split: "
          f"{len(rowed)} rowed {rowed}, {len(rowless)} rowless; the profile's "
          f"`rowed_slot_ids()` literal {stated} agrees")
    print(f"  ✓ the ONE excluded atom is an atom of the ONE gated kind ({EXPECTED_EXCLUDED}), "
          f"re-derived from the dispatch table — the first non-empty exclusion in the project")


def check_the_mediating_hook(out):
    """The substance, counted off the record's own lines rather than off the
    profile's computed CoverageSubstance, which would be the profile agreeing
    with itself."""
    mediating = [h for (_e, h), (k, _p, _bk, c1, c2, _c3) in out["classification"].items()
                 if k == "world_mediated" and c1 == "substantively" and c2 == "substantively"]
    vacuous = [h for (_e, h), (k, _p, _bk, c1, c2, _c3) in out["classification"].items()
               if k == "world_mediated" and c1 == "vacuously" and c2 == "vacuously"]
    if not mediating:
        fail("NOT ONE covered hook records criterion 2's port and origin clauses substantively. "
             "That is `driver_plus_no_ops`'s shape, and a profile whose name says `compose` "
             "carrying it would be the fourth vacuity with a number attached (S21).")
    print(f"  ✓ {len(mediating)} covered hook(s) mediate SUBSTANTIVELY: {sorted(mediating)}; "
          f"{len(vacuous)} satisfy the port and origin clauses vacuously: {sorted(vacuous)}")


# ---------------------------------------------------------------------------
# 5. The demonstration happened, and it was not vacuous
# ---------------------------------------------------------------------------


def check_the_demonstration(out):
    claim = out["claim"].get("clause1")
    if not claim:
        fail("the acceptance script printed no `CLAIM clause1` line, so the graded session either "
             "did not run or did not report. EVERY criterion-2 entry in this profile names "
             "`discovery` as its basis, and `discovery`'s evidence IS the run — a record citing it "
             "with no run behind it is a basis with nothing under it, which is the fail-open shape "
             "`basis` exists to close. This is the check that refuses it.")

    fields = dict(re.findall(r"(\w+)=(\[[^\]]*\]|\S+)", claim))
    for key in ("extension_effects", "origins", "replayed", "mismatches"):
        if key not in fields:
            fail(f"`CLAIM clause1` has no `{key}` field: {claim!r}")

    effects = int(fields["extension_effects"])
    replayed = int(fields["replayed"])
    mismatches = int(fields["mismatches"])
    origins = [o.strip() for o in fields["origins"].strip("[]").split(",") if o.strip()]

    if effects < 1:
        fail("the graded run recorded ZERO extension-effect interactions. The goal line's clause 1 "
             "requires extension effects world-mediated and present in the recorded program; a run "
             "that performed none proves nothing, and is byte-identical to every profile run in "
             "this tree before WI-D27.")
    if origins != [SUBJECT] * len(origins) or not origins:
        fail(f"the recorded extension effects carry origins {origins}, expected every one to be "
             f"'{SUBJECT}'. The origin is stamped by the fold in ext/runtime.ail, so a wrong one "
             "means the effect was attributed to something other than the extension that "
             "performed it.")
    if replayed != effects:
        fail(f"the recording carries {effects} origin-tagged effect(s) and the replay reproduces "
             f"{replayed}. Clause 1 requires them 'present in the recorded program AND reproduced "
             "by its replay'.")
    if mismatches != 0:
        fail(f"strict replay reported {mismatches} mismatch(es); the graded session does not "
             "replay deterministically, so the profile's `discovery` basis has no reproducible run")

    print(f"  ✓ THE DEMONSTRATION IS NON-VACUOUS: {effects} world-mediated effect(s) origin-tagged "
          f"{origins}, {replayed} reproduced by strict replay, {mismatches} mismatch(es)")


# ---------------------------------------------------------------------------
# 6. Registration's disclosure, against classifier 3's own source list
# ---------------------------------------------------------------------------


def check_registration_disclosure(rows, ext):
    """Both directions. One alone is defeated by a one-line record: a disclosure
    naming a source the instrument never found reads as evidence, and a source
    the instrument found and the profile did not disclose is the gap the goal
    line's clause 2 exists to forbid."""
    if not rows:
        fail("the acceptance script disclosed NO registration source. compose's "
             "`register_with_config` reads Env and FS before any hook is dispatched and this "
             "profile's runs grant both, so a run that discloses nothing has hidden the one gap "
             "the poison pairs do not cover.")

    found = {(s["symbol"].split(".")[-1], s["file"]) for s in ext["ambient"]
             if set(s["effects"]) & {"Env", "FS"}}
    if not found:
        fail("classifier 3 reports no ambient Env or FS source in compose's closure at all, so "
             "this comparison would pass over nothing. Either registration was routed — in which "
             "case the disclosure should be RETIRED and the profile re-issued — or the instrument "
             "did not run.")

    for cap, src, symbol in rows:
        if (symbol, src) not in found:
            fail(f"the profile discloses a registration {cap} read of `{symbol}` at {src}, and "
                 f"classifier 3 found no such source. Disclosed sources it found: "
                 f"{sorted(found)}. A disclosure naming a site the instrument does not see reads "
                 "as evidence and is worse than none.")

    disclosed = {(symbol, src) for _cap, src, symbol in rows}
    registration_files = {f for _s, f in found if f.endswith(("register.ail", "config.ail"))}
    undisclosed = {(s, f) for s, f in found if f in registration_files} - disclosed
    if undisclosed:
        fail(f"classifier 3 finds ambient Env/FS source(s) {sorted(undisclosed)} in compose's "
             "registration files that this profile does not disclose. Goal-line clause 2 requires "
             "every ambient source to be mediated or DISCLOSED WITH A MEASURED REASON; an "
             "undisclosed one is a source nobody counted.")

    print(f"  ✓ registration's {len(rows)} ambient source(s) disclosed, both directions, against "
          f"classifier 3's own source list")


# ---------------------------------------------------------------------------
# 7. The computed statement
# ---------------------------------------------------------------------------


def check_statement(out):
    s = out["statement"]
    if not s:
        fail("the acceptance script printed no STATEMENT line")
    if "ENTIRELY OF NO-OPS" in s or s.startswith("extension-model coverage is ZERO"):
        fail(f"the computed coverage statement is a no-op or zero-coverage sentence: {s!r}. This "
             "profile's record must select `coverage_statement`'s mediating branch, which no "
             "profile in this project has ever reached.")
    m = re.search(r"of which (\d+) mediate the world SUBSTANTIVELY", s)
    if not m or int(m.group(1)) < 1:
        fail(f"the computed statement does not name a non-zero mediating count: {s!r}")
    print(f"  ✓ the computed coverage statement takes the MEDIATING branch "
          f"({m.group(1)} hook(s)) — the first time in this project")


def main():
    if len(sys.argv) != 2:
        print("usage: check_compose_profile.py <driver_plus_compose_dst output>")
        sys.exit(2)
    out = parse_output(sys.argv[1])
    slots = abi_slots()
    inv = ambient_inventory()

    check_install_set(out)
    ext = check_the_basis_is_not_classifier_shaped(out, inv)
    check_classifications(out, slots)
    check_the_mediating_hook(out)
    check_the_demonstration(out)
    check_registration_disclosure(parse_disclosed(sys.argv[1]), ext)
    check_statement(out)
    print("  ✓ no fact in this profile's record is a stale transcription of a producer's output")


if __name__ == "__main__":
    main()
