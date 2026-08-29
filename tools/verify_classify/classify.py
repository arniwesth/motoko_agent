#!/usr/bin/env python3
"""Compute the class of every Z3 contract in src/core/ and pin it.

`proven` is not a metric. A contract that holds for every possible result proves
nothing about the body, and three of the four contracts this repo started with
were of that kind. What counts is `substantive`, and the class is *computed* by
the solver rather than asserted by a human, because a hand-maintained register
cannot validate its own labels -- the editor moves the contract and the label
together, which is not an attack but the normal workflow (ADR-001 §2, and the
failure recorded at src/core/dst_invariants.ail:72-84).

Two probes decide the class of contract E over `f(args) -> T` with body B
(ADR-001 §1):

  TAUT       pure func taut_f(args, r: T) -> T ensures { E } { r }
             VERIFIED means E holds for every result => tautology.

  DETERMINE  pure func det_f(args, r: T) -> T
               requires { E[result := r] } ensures { result == B } { r }
             VERIFIED means E admits only the body's answer => spec-equals-body.
             Semantic, so it catches restatements through lets and aliases too.

  substantive <=> both VIOLATION: E is falsifiable AND admits results the body
                  would not produce.

DETERMINE inlines the body rather than calling f: a user function is not
encodable from inside a contract ("calls user function ... not SMT-encodable in
this context") even when the function itself verifies.

Probe modules are the source module copied with a new module line and the probes
appended, so imports, types and callees resolve exactly as they do in the
original.

Usage:
  classify.py --write    regenerate contracts.register from the tree
  classify.py --check    fail if the tree and the register disagree, either way
"""

import argparse
import hashlib
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src" / "core"
GEN = Path(__file__).resolve().parent / "generated"
REGISTER = Path(__file__).resolve().parent / "contracts.register"

# The free variable the probes bind the result to. Not `r`: a source parameter
# could legitimately be called that.
FREE = "probe_result"

CLASSES = ("substantive", "tautology", "spec-equals-body", "unclassified")


# --------------------------------------------------------------------------
# Source scanning
# --------------------------------------------------------------------------

@dataclass
class Contract:
    module: str          # path relative to repo root
    name: str
    params: str          # "start: int, end: int"
    ret: str             # "{ start: int, end: int }"
    ensures: str         # contract text, braces stripped
    body: str            # body block, braces INCLUDED
    solve_ms: float | None = None
    taut: str = ""       # VERIFIED | VIOLATION | SKIPPED
    det: str = ""
    cls: str = "unclassified"
    provenance: str = "-"
    override: str = ""

    @property
    def contract_hash(self) -> str:
        return _hash(self.ensures)

    @property
    def body_hash(self) -> str:
        return _hash(self.body)


def _hash(text: str) -> str:
    """Hash on normalised whitespace: reindenting a contract is not a reclassification."""
    return hashlib.sha256(" ".join(text.split()).encode()).hexdigest()[:12]


def _match_delim(text: str, start: int, open_c: str, close_c: str) -> int:
    """Index just past the delimiter matching the one at `start`, skipping
    string literals and line comments."""
    depth = 0
    i = start
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
            i += 1
            continue
        if c == "-" and text.startswith("--", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError(f"unbalanced {open_c!r} from offset {start}")


DECL_RE = re.compile(
    r"^(?:export\s+)?pure\s+func\s+(?P<name>\w+)\((?P<params>[^)]*)\)\s*->\s*(?P<ret>.+?)\s*$",
    re.M,
)


def scan(path: Path) -> list[Contract]:
    text = path.read_text()
    rel = str(path.relative_to(ROOT))
    out: list[Contract] = []

    for m in DECL_RE.finditer(text):
        # The return type may itself be a record, in which case the signature
        # line ends at a brace the regex has already consumed. Walk from the end
        # of the signature over the clauses.
        i = m.end()
        ensures = None

        while True:
            rest = text[i:]
            stripped = rest.lstrip()
            skip = len(rest) - len(stripped)
            if stripped.startswith("--"):
                nl = text.find("\n", i + skip)
                i = len(text) if nl < 0 else nl + 1
                continue
            for kw, opener, closer in (("requires", "{", "}"),
                                       ("ensures", "{", "}"),
                                       ("tests", "[", "]")):
                if stripped.startswith(kw):
                    j = text.index(opener, i + skip)
                    k = _match_delim(text, j, opener, closer)
                    if kw == "ensures":
                        ensures = text[j + 1:k - 1].strip()
                    i = k
                    break
            else:
                break

        if ensures is None:
            continue

        b = text.index("{", i)
        body = text[b:_match_delim(text, b, "{", "}")]
        out.append(Contract(module=rel, name=m.group("name"),
                            params=m.group("params").strip(),
                            ret=m.group("ret").strip(),
                            ensures=ensures, body=body))
    return out


# --------------------------------------------------------------------------
# Probe generation
# --------------------------------------------------------------------------

RESULT_RE = re.compile(r"\bresult\b")


def probe_source(module_path: Path, contracts: list[Contract]) -> str:
    src = module_path.read_text()
    rel = str(module_path.relative_to(ROOT))
    stem = module_path.stem
    src = src.replace(f"module {rel[:-len('.ail')]}",
                      f"module tools/verify_classify/generated/{stem}_probe", 1)

    parts = [src, "\n\n-- " + "=" * 70,
             "-- GENERATED by tools/verify_classify/classify.py -- do not edit.",
             "-- Probes for the contracts declared above (ADR-001 §1).",
             "-- " + "=" * 70 + "\n"]

    for c in contracts:
        sep = ", " if c.params else ""
        parts.append(
            f"pure func taut_{c.name}({c.params}{sep}{FREE}: {c.ret}) -> {c.ret}\n"
            f"  ensures {{ {c.ensures} }}\n"
            f"  {{ {FREE} }}\n"
        )
        parts.append(
            f"pure func det_{c.name}({c.params}{sep}{FREE}: {c.ret}) -> {c.ret}\n"
            f"  requires {{ {RESULT_RE.sub(FREE, c.ensures)} }}\n"
            f"  ensures  {{ result == {c.body} }}\n"
            f"  {{ {FREE} }}\n"
        )
    return "\n".join(parts)


VERDICT_RE = re.compile(r"(VERIFIED|VIOLATION|SKIPPED)\s+(\w+)(?:\s+\x1b\[2m([\d.]+)ms)?")


def verdicts(path: Path) -> dict[str, tuple[str, float | None]]:
    # Relative to ROOT: `ailang verify` checks the module declaration against the
    # file path, and an absolute path fails that check (MOD010).
    out = subprocess.run(["ailang", "verify", str(Path(path).resolve().relative_to(ROOT))],
                         capture_output=True, text=True, cwd=ROOT)
    if out.returncode not in (0, 1):
        raise SystemExit(f"ailang verify failed on {path}:\n{out.stdout}{out.stderr}")
    found: dict[str, tuple[str, float | None]] = {}
    for line in (out.stdout + out.stderr).splitlines():
        m = VERDICT_RE.search(line)
        if m:
            ms = float(m.group(3)) if m.group(3) else None
            found[m.group(2)] = (m.group(1), ms)
    return found


def classify(contracts: list[Contract]) -> None:
    """Assign cls/provenance from the probe verdicts already recorded."""
    for c in contracts:
        if c.taut == "VERIFIED":
            c.cls = "tautology"
        elif c.det == "VERIFIED":
            c.cls = "spec-equals-body"
            inner = c.body.strip()[1:-1].strip()
            want = f"result == {inner}"
            c.provenance = ("verbatim"
                            if " ".join(c.ensures.split()) == " ".join(want.split())
                            else "independent")
        elif c.taut == "VIOLATION" and c.det == "VIOLATION":
            c.cls = "substantive"
        else:
            c.cls = "unclassified"


# --------------------------------------------------------------------------
# Register
# --------------------------------------------------------------------------

HEADER = """\
# contracts.register -- GENERATED by tools/verify_classify/classify.py.
#
# The class of each contract is computed by Z3, not asserted here: `make
# verify_classify` regenerates this file and `make verify_classify_check`
# fails if the tree and this file disagree in EITHER direction -- a contract
# that changed class without the pin moving, a pinned contract that no longer
# exists, and (the part a hand-written register cannot do) a class edited here
# while the solver computes something else.
#
# The pin is keyed on the contract text AND the body text, both whitespace-
# normalised, so editing either invalidates the entry instead of inheriting it.
#
#   substantive       both probes VIOLATION -- falsifiable, and admits results
#                     the body would not produce. THE ONLY CLASS THAT COUNTS.
#   tautology         TAUT verified -- holds for every result, constrains nothing.
#   spec-equals-body  DETERMINE verified -- admits only the body's answer. A
#                     regression test, not evidence; a standing invitation to
#                     look for the weaker property (ADR-001 §1).
#   unclassified      a probe was SKIPPED; the fragment could not decide.
#
# `solve` is the contract's own time from `ailang verify` on the real module,
# recorded so P4 can see the tail before verify rides in DP7's path (PLAN Q2).
#
# A human may disagree with a probe only on recorded grounds, on an
# `-- override:` line directly beneath the entry, and the grounds must name the
# probe result being overridden. The residual the probes cannot catch is a
# contract that is falsifiable and non-determining yet unrelated to the body's
# purpose (`ensures { result.start >= -1000 }`); that is the only thing an
# override is for.
"""


def render(contracts: list[Contract]) -> str:
    rows = []
    for c in sorted(contracts, key=lambda c: (c.module, c.name)):
        solve = f"{c.solve_ms:.1f}ms" if c.solve_ms is not None else "-"
        rows.append((c.module, c.name, c.cls, c.provenance,
                     c.contract_hash, c.body_hash, solve, c.override))

    if not rows:
        return HEADER + "\n"

    w = [max(len(r[i]) for r in rows) for i in range(4)]
    lines = [HEADER, ""]
    counts: dict[str, int] = {}
    for mod, name, cls, prov, ch, bh, solve, override in rows:
        counts[cls] = counts.get(cls, 0) + 1
        lines.append(f"{mod:<{w[0]}}  {name:<{w[1]}}  {cls:<{w[2]}}  "
                     f"{prov:<{w[3]}}  contract={ch}  body={bh}  solve={solve}")
        if override:
            lines.append(f"  -- override: {override}")
    lines.append("")
    lines.append("# totals: " + ", ".join(f"{counts.get(c, 0)} {c}" for c in CLASSES))
    return "\n".join(lines) + "\n"


ENTRY_RE = re.compile(
    r"^(?P<module>\S+)\s+(?P<name>\S+)\s+(?P<cls>\S+)\s+(?P<prov>\S+)\s+"
    r"contract=(?P<ch>\w+)\s+body=(?P<bh>\w+)\s+solve=(?P<solve>\S+)\s*$")


def parse_register(text: str) -> dict[tuple[str, str], dict]:
    out = {}
    last = None
    for line in text.splitlines():
        if line.startswith("  -- override:"):
            if last:
                out[last]["override"] = line.split("override:", 1)[1].strip()
            continue
        if not line.strip() or line.startswith("#"):
            continue
        m = ENTRY_RE.match(line)
        if not m:
            raise SystemExit(f"contracts.register: unparseable line: {line}")
        last = (m.group("module"), m.group("name"))
        out[last] = {"cls": m.group("cls"), "prov": m.group("prov"),
                     "ch": m.group("ch"), "bh": m.group("bh"), "override": ""}
    return out


# --------------------------------------------------------------------------

def collect() -> list[Contract]:
    GEN.mkdir(parents=True, exist_ok=True)
    for stale in GEN.glob("*.ail"):
        stale.unlink()

    all_contracts: list[Contract] = []
    for path in sorted(SRC.glob("*.ail")):
        if path.name.endswith("_test.ail"):
            continue
        contracts = scan(path)
        if not contracts:
            continue

        real = verdicts(path)
        for c in contracts:
            v = real.get(c.name)
            if v and v[0] == "VERIFIED":
                c.solve_ms = v[1]

        probe = GEN / f"{path.stem}_probe.ail"
        probe.write_text(probe_source(path, contracts))
        got = verdicts(probe)
        for c in contracts:
            c.taut = got.get(f"taut_{c.name}", ("SKIPPED", None))[0]
            c.det = got.get(f"det_{c.name}", ("SKIPPED", None))[0]

        classify(contracts)
        all_contracts.extend(contracts)
    return all_contracts


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--write", action="store_true")
    g.add_argument("--check", action="store_true")
    args = ap.parse_args()

    contracts = collect()

    if args.write:
        REGISTER.write_text(render(contracts))
        for c in sorted(contracts, key=lambda c: (c.module, c.name)):
            print(f"  {c.cls:<16} {c.name}  (taut={c.taut}, det={c.det})")
        print(f"verify_classify: {len(contracts)} contracts classified -> "
              f"{REGISTER.relative_to(ROOT)}")
        return 0

    if not REGISTER.exists():
        print("contracts.register is missing; run `make verify_classify`")
        return 1

    pinned = parse_register(REGISTER.read_text())
    computed = {(c.module, c.name): c for c in contracts}
    bad = []

    for key, c in computed.items():
        p = pinned.get(key)
        if p is None:
            bad.append(f"  unpinned: {key[0]} {c.name} computes {c.cls}, "
                       f"no entry in the register")
            continue
        if p["ch"] != c.contract_hash or p["bh"] != c.body_hash:
            bad.append(f"  stale pin: {key[0]} {c.name} -- contract or body changed "
                       f"since it was classified (pinned contract={p['ch']} body={p['bh']}, "
                       f"now contract={c.contract_hash} body={c.body_hash})")
            continue
        if p["cls"] != c.cls and not p["override"]:
            bad.append(f"  relabelled: {key[0]} {c.name} is pinned as {p['cls']} but "
                       f"the solver computes {c.cls} (taut={c.taut}, det={c.det})")

    for key, p in pinned.items():
        if key not in computed:
            bad.append(f"  vanished: {key[0]} {key[1]} is pinned as {p['cls']} but no "
                       f"such contract exists in the tree")

    counts: dict[str, int] = {}
    for c in contracts:
        counts[c.cls] = counts.get(c.cls, 0) + 1
    summary = ", ".join(f"{counts.get(k, 0)} {k}" for k in CLASSES)

    if bad:
        print("verify_classify: the tree and contracts.register disagree")
        print("\n".join(bad))
        print("\nIf the tree is right, re-pin with `make verify_classify`. "
              "If the solver is wrong,\nadd an `-- override:` line naming the probe "
              "result you are overriding.")
        return 1

    print(f"verify_classify: {len(contracts)} contracts, register agrees ({summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
