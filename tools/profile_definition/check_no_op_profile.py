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

B8 (ADR-001, ABI 6.0): hook ids are ATOM ids `kind[index]` over the eight
capability KINDS; the rowed/rowless split is read off the `Capability` payloads;
and a seventh check, the DENOMINATOR RULE, requires every installed extension's
disclosed atoms to equal B2's enumeration of its registration literal.
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
HOOK_SCOPE = REPO / "tools/ext_ambient_inventory/hook_scope.py"
AMBIENT_DERIVE = REPO / "tools/ext_ambient_inventory/derive.py"

# B8: hook ids are ATOM ids `kind[index]` over the 6.0 capability KINDS. The
# kind table is read from the coverage artifact's own `capability_kind_id` so
# that a ninth kind arrives here too, and the per-extension atoms are read from
# B2's enumeration (`hook_scope.py`), not assumed.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_fixtures import (  # noqa: E402
    ambient_inventory,
    capability_kind_ids,
    capability_payloads,
    dispatch_unconditional,
    installable_extension_dirs,
    kind_of,
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
           "disclosure": set(), "disclosed_atoms": {}, "claim": {}, "statement": ""}

    # B8: the indented `atoms:` / `covered:` / `excluded:` lines that follow a
    # DISCLOSURE line carry the disclosure's atom ids; they are collected per
    # extension so the B2 cross-check in `check_install_set` can read the
    # disclosure itself and not only the classification entries derived from it.
    current = None
    for line in text.splitlines():
        parts = line.split()
        if not parts:
            continue
        tag = parts[0]
        if current is not None and tag in ("atoms:", "covered:", "excluded:"):
            ids = [t.strip() for t in " ".join(parts[1:]).split(",") if t.strip()]
            if ids == ["(none)"]:
                ids = []
            out["disclosed_atoms"].setdefault(current, {})[tag.rstrip(":")] = ids
            continue
        if tag != "DISCLOSURE" and not (tag == current and len(parts) == 1):
            current = None
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
            current = parts[1]
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


EXPECTED_CAPABILITY_KINDS = 9


def abi_slots():
    """capability kind id -> (declared row, outcome type, returns world state).

    B8: the 5.x `ExtensionHooks` record is gone. The kind ids come from the
    coverage artifact's `capability_kind_id` arms (`XKind => "x"`), read there
    rather than written here so a ninth kind arrives at this guard too; each
    kind's row and outcome are read from its `Capability` payload by
    `check_fixtures.capability_payloads`, whose docstring carries the S16
    enumeration of payload shapes. A kind the table names and the ABI does not
    row (or the reverse) is a FAIL, never a skip.
    """
    kinds = capability_kind_ids()
    # NINE at ABI 7.0 (`ExitIntent`), eight before it. Pinned rather than
    # derived on purpose: the count is what makes a kind added to the ABI and
    # forgotten here a FAIL instead of a silent skip, so it moves by hand, once,
    # with the variant.
    if len(kinds) != EXPECTED_CAPABILITY_KINDS:
        fail(f"read {len(kinds)} capability kind ids from {COVERAGE.relative_to(REPO)}, expected "
             f"{EXPECTED_CAPABILITY_KINDS}: {kinds}. The ABI gained or lost a kind and this "
             "guard's per-kind checks would silently skip it.")
    payloads = capability_payloads(ABI_TYPES.read_text())
    if set(payloads) != set(kinds):
        fail(f"the coverage artifact's kind table {sorted(kinds)} and the ABI's `Capability` "
             f"variants {sorted(payloads)} disagree; a kind in one and not the other has no "
             "row this guard can re-derive")
    return {k: payloads[k] for k in kinds}


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


def is_unconditional(hook_id):
    """B8: one dispatch table. `hook_id` may be an atom id (`tool_provider[0]`)
    or a kind id; either way the `XKind => Unconditional|Gated` arm of
    `capability_dispatch` is what answers."""
    return dispatch_unconditional(COVERAGE.read_text(), hook_id)


_HOOK_SCOPE_CACHE = {}


def hook_scope_atoms():
    """B2's per-extension enumeration of registered capability atoms:
    extension id -> sorted [(kind id, index)].

    This is the B8 DENOMINATOR RULE's independent producer: a profile's
    disclosed atoms must equal what `hook_scope.py` enumerates from the
    package's own `register_with_config` literal. `derive.py --hook-scope`
    prints a report rather than JSON, so the two modules are loaded by path
    (the way `derive._hook_scope` itself does) and `derive_hook_scope` is
    called in-process.

    S16 enumeration — how an extension's entry can fail to yield atoms:
      (a) `registration_shape` is not `capability-list` (the list head was not
          located, or the registration is not a literal list) — FAIL; a
          denominator nobody could count is not zero;
      (b) an atom whose constructor is not in the coverage artifact's kind
          table — FAIL, the ABI gained a variant this guard cannot classify;
      (c) an extension absent from the result entirely — FAIL at the caller.
    """
    if _HOOK_SCOPE_CACHE:
        return _HOOK_SCOPE_CACHE["atoms"]
    import importlib.util
    import os

    def load(name, path):
        spec = importlib.util.spec_from_file_location(name, path)
        mod = importlib.util.module_from_spec(spec)
        sys.modules[name] = mod
        spec.loader.exec_module(mod)
        return mod

    c3 = load("motoko_ambient_derive_for_profile", AMBIENT_DERIVE)
    hs = load("motoko_hook_scope_for_profile", HOOK_SCOPE)

    closure = c3.derive(REPO, do_provision=True)
    if closure["provision_failures"]:
        fail(f"B2's cache precondition was not established: {closure['provision_failures']}; "
             "the per-extension atom enumeration is unavailable, so the denominator is unknown")
    producer = c3.Producer()
    producer.load([REPO / "src", REPO / "packages", REPO / "scripts"])
    stdlib = Path(os.environ.get(c3.STDLIB_ENV) or c3.DEFAULT_STDLIB)
    builtins = c3.builtin_effects(stdlib, producer) if stdlib.is_dir() else {}
    c2 = c3.c2
    abi_types = c2.record_types(c2.strip_noise((REPO / c2.ABI_TYPES).read_text()))
    core_types = c2.record_types(c2.strip_noise((REPO / c2.CORE_PORTS).read_text()))
    c2.ALL_TYPES.clear()
    c2.ALL_TYPES.update(core_types)
    c2.ALL_TYPES.update(abi_types)
    ext_fields = tuple(abi_types.get("ExtPorts", {}))
    if not ext_fields:
        fail("ExtPorts has no fields in the ABI; B2 cannot run and the atom enumeration is unknown")
    res = hs.derive_hook_scope(REPO, c3, producer, builtins, ext_fields)

    ctor_to_kind = {}
    for kid in capability_kind_ids():
        ctor_to_kind["".join(p.capitalize() for p in kid.split("_"))] = kid

    atoms = {}
    for ext, r in res.items():
        if r.get("registration_shape") != "capability-list":
            fail(f"B2 reads '{ext}'s registration as {r.get('registration_shape')!r}, not "
                 "`capability-list`; its atom count cannot be enumerated, so the denominator "
                 "for it is UNKNOWN rather than eight. Rejections: "
                 f"{[x.get('detail') for x in r.get('rejections', [])][:3]}")
        got = []
        for a in r.get("atoms", []):
            kid = ctor_to_kind.get(a["kind"])
            if kid is None:
                fail(f"B2 enumerates a `{a['kind']}` atom in '{ext}' that the coverage artifact's "
                     "kind table does not name; the ABI gained a variant this guard cannot classify")
            got.append((kid, int(a["index"])))
        if len(got) != r.get("atom_count"):
            fail(f"B2's atom list for '{ext}' has {len(got)} entries and reports atom_count="
                 f"{r.get('atom_count')}; an atom was dropped, which is fail-open")
        atoms[ext] = sorted(got)
    _HOOK_SCOPE_CACHE["atoms"] = atoms
    return atoms


def atom_ref(atom_id):
    """`tool_provider[0]` -> ('tool_provider', 0). Any other shape is a FAIL:
    an id this guard cannot read is an atom it cannot cross-check."""
    m = re.fullmatch(r"([a-z_]+)\[(\d+)\]", atom_id)
    if not m:
        fail(f"hook id {atom_id!r} is not an atom id `kind[index]`; B8 hook ids are atom ids")
    return (m.group(1), int(m.group(2)))


def check_disclosed_atoms_against_b2(out, ext_ids):
    """THE B8 DENOMINATOR RULE. For every INSTALLED extension, the profile's
    disclosed atoms (kind + index) must equal B2's enumeration of the atoms
    its `register_with_config` literal registers. A profile that discloses
    fewer atoms than the package registers has a hook nobody classified; one
    that discloses more has coverage claimed over an atom that does not exist.

    Two readings of the profile are compared, and both must agree with B2:
    the CLASSIFICATION entries (one per atom, computed from the disclosure)
    and, when the acceptance script printed them, the DISCLOSURE block's own
    `covered:`/`excluded:` id lines.
    """
    b2 = hook_scope_atoms()
    for ext in sorted(ext_ids):
        if ext not in b2:
            fail(f"B2 has no atom enumeration for installed extension '{ext}'; fail-closed, its "
                 "denominator is unknown")
        want = b2[ext]
        classified = sorted(atom_ref(h) for (e, h) in out["classification"] if e == ext)
        if classified != want:
            fail(f"'{ext}': the profile classifies atoms {classified} and B2 enumerates {want} "
                 f"from its registration literal. The disclosed atom set must EQUAL what the "
                 "package registers (kind + index); this is the B8 denominator rule.")
        da = out["disclosed_atoms"].get(ext)
        if da is None:
            fail(f"'{ext}': the acceptance script printed no `atoms:`/`covered:`/`excluded:` lines "
                 "under its DISCLOSURE line, so the disclosure itself cannot be compared with B2 "
                 "(only the entries derived from it were); a denominator that is not printed is "
                 "not one this guard can read")
        disclosed = sorted(atom_ref(h) for h in da.get("covered", []) + da.get("excluded", []))
        if disclosed != want:
            fail(f"'{ext}': the DISCLOSURE block lists atoms {disclosed} (covered + excluded) "
                 f"and B2 enumerates {want}; the disclosure itself, not only the entries "
                 "derived from it, must equal the registration")
        if "atoms" in da:
            listed = sorted(atom_ref(h) for h in da["atoms"])
            if listed != want:
                fail(f"'{ext}': the DISCLOSURE block's `atoms:` line lists {listed} and B2 "
                     f"enumerates {want}")
    n = sum(len(b2[e]) for e in ext_ids)
    print(f"  ✓ B8 denominator: every installed extension's disclosed atoms equal B2's enumeration "
          f"of its registration literal ({n} atom(s) over {len(ext_ids)} extension(s))")


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

    check_disclosed_atoms_against_b2(out, installed)


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
    # B8: one entry per (installed extension, REGISTERED ATOM), the atoms read
    # from B2's enumeration rather than assumed to be one per kind.
    b2 = hook_scope_atoms()
    expected = {(e, f"{k}[{i}]") for e in installed for (k, i) in b2[e]}
    got = set(out["classification"])
    if got != expected:
        missing, extra = sorted(expected - got), sorted(got - expected)
        fail(f"the classification entries are not one per (installed extension, registered atom).\n"
             f"      missing: {missing}\n      unexpected: {extra}")

    n_c1 = n_c2 = 0
    for (ext, hook), (kind, producer, basis_kind, c1, c2, c3) in sorted(out["classification"].items()):
        if kind_of(hook) not in slots:
            fail(f"{ext}/{hook} names a capability kind the ABI does not have: {sorted(slots)}")
        row, outcome, returns_world = slots[kind_of(hook)]
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


def _balanced(text, start):
    """Index just past the `)` that closes the `(` at `text[start]`, or -1."""
    depth = 0
    for j in range(start, len(text)):
        depth += {"(": 1, ")": -1}.get(text[j], 0)
        if depth == 0:
            return j + 1
    return -1


def _split_top(args):
    """Split `args` at depth-0 commas (parens, brackets, braces)."""
    out, depth, cur = [], 0, []
    for ch in args:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return [a.strip() for a in out]


def check_row_7(out):
    """Row 7's two facts, each re-derived from the extension's own source.

    S16 enumeration — how an extension can reach the `ScratchpadResult` path,
    written before the scan unit was chosen. The variant is emitted only when a
    tool named `scratchpad` is served by a ToolProvider handle returning
    `Handled` with a `cells` key, and the dispatch gate is the atom's own
    provided-names list. So an extension reaches it only if BOTH:

      (a) the `ToolProvider(<names>, <handle>)` atom's NAMES are non-empty.
          Ways they can be written:
            1. an inline list literal — the shape all four use; only the empty
               literal `[]` is admitted;
            2. a named identifier or function call — CANNOT be decided by this
               scan, so it FAILS rather than passing;
            3. built from config inside `register_with_config` — same, FAILS.
      (b) the HANDLE can return `Handled`. Ways it can be bound:
            1. an inline `func`/lambda whose body names the constructor — the
               shape all four use;
            2. a reference to a named top-level function IN THE PACKAGE — B8
               admits it by following the name to its body in the package's
               own `.ail` files and applying the same scan there; a name that
               resolves nowhere in the package FAILS;
            3. a value threaded from elsewhere — FAILS.

    B8: the facts are read off the `ToolProvider` atom of the literal
    `[Capability]` list, never off a `provided_tools:`/`on_tool_handle:` field
    or a `default_hooks` head — both are gone from the ABI. A package with no
    `ToolProvider(` atom, or with more than one, is a shape this scan does not
    admit and FAILS. Every unenumerated shape is a FAIL, which is the
    fail-closed direction: this scan can refuse an extension that in fact
    never emits, and cannot bless one that does.
    """
    dirs = {v: k for k, v in installable_extension_dirs().items()}
    for ext in sorted(out["installed"]):
        pkg = REPO / dirs[ext]
        srcs = sorted(pkg.glob("*.ail"))
        hits = []
        for src in srcs:
            text = src.read_text()
            for m in re.finditer(r"\bToolProvider\s*\(", text):
                if re.search(r"\bimport\b", text[max(0, text.rfind("\n", 0, m.start())):m.start()]):
                    continue
                end = _balanced(text, m.end() - 1)
                if end < 0:
                    fail(f"'{ext}': unbalanced `ToolProvider(` in {src.name}")
                hits.append((src, text, text[m.end():end - 1]))
        if len(hits) == 0:
            # Item 4 (6.0 trimming): an extension that registers NO ToolProvider
            # atom has no provided-names list and no handle at all, so the gated
            # ToolProvider dispatch is never reached for it and the
            # ScratchpadResult path is closed by construction. That is stronger
            # than the `ToolProvider([], handle)` shape, and B2's enumeration
            # (check 4) is what guarantees the atom is really absent rather than
            # merely unseen by this scan.
            if any(kind == "tool_provider" for (kind, _i) in hook_scope_atoms()[ext]):
                fail(f"'{ext}' registers a tool_provider atom per B2 and this scan finds no "
                     f"`ToolProvider(` under {dirs[ext]}; the two readings disagree, fail-closed")
            print(f"      row7 '{ext}': registers no ToolProvider atom at all (B2 agrees) — the gated "
                  "dispatch is unreachable by construction")
            continue
        if len(hits) != 1:
            fail(f"'{ext}' has {len(hits)} `ToolProvider(...)` atom(s) under {dirs[ext]} (in "
                 f"{sorted({h[0].name for h in hits})}); this scan admits at most ONE, so row 7's "
                 "exemption cannot be re-derived and is not earned")
        path, text, payload = hits[0]
        args = _split_top(payload)
        if len(args) != 2:
            fail(f"'{ext}'s `ToolProvider` atom has {len(args)} argument(s), expected (names, handle)")
        names, handle = args

        if names != "[]":
            fail(f"'{ext}' registers `ToolProvider({names}, ...)`, whose names are not the empty\n"
                 "      literal this scan can decide. Row 7's first fact is UNVERIFIED — fail-closed,\n"
                 "      because a non-empty or computed tool list opens the gated ToolProvider\n"
                 "      dispatch and with it the ScratchpadResult path.")

        body = handle
        if "func(" not in body and "func " not in body and "\\" not in body:
            # shape (b)2: a bare name; follow it to its body in the package.
            if not re.fullmatch(r"[A-Za-z_]\w*", body):
                fail(f"'{ext}' binds its ToolProvider handle to something this scan cannot follow "
                     f"({body[:60]!r}); row 7's second fact is UNVERIFIED — fail-closed")
            found = None
            for src in srcs:
                t = src.read_text()
                fm = re.search(r"^(?:export\s+)?(?:pure\s+)?func\s+" + re.escape(body) + r"\s*\(",
                               t, re.M)
                if fm:
                    bstart = t.find("{", fm.end())
                    depth, j = 0, bstart
                    while j < len(t):
                        depth += {"{": 1, "}": -1}.get(t[j], 0)
                        j += 1
                        if depth == 0:
                            break
                    found = (src, t[fm.start():j])
                    break
            if found is None:
                fail(f"'{ext}' binds its ToolProvider handle to `{body}`, which resolves to no "
                     f"top-level `func {body}(` in {dirs[ext]}; row 7's second fact is "
                     "UNVERIFIED — fail-closed")
            path, body = found[0], found[1]
        if "Handled" in body:
            fail(f"'{ext}'s ToolProvider handle ({path.name}) can return `Handled`, which is the\n"
                 "      constructor the ScratchpadResult path needs. Row 7's exemption does not hold\n"
                 "      for this profile.")
        if "Delegate" not in body:
            fail(f"'{ext}'s ToolProvider handle ({path.name}) returns neither `Handled` nor "
                 "`Delegate`; the scan cannot decide it")

    print(f"  ✓ CLAIM row7 re-derived from source: all {len(out['installed'])} installed extensions "
          "either register NO ToolProvider atom (B2 agrees) or register `ToolProvider([], handle)` "
          "with a handle that returns `Delegate`, never `Handled` — so the gated ToolProvider "
          "dispatch is never reached, by two independent facts, neither of them emptiness")


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
