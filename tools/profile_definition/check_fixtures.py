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
  2. the recorded unrouted-field set equals the tool's (`clock_now` is a
     DISTINCT unrouted state, not a non-member -- treating it as a non-member
     would silently bless an extension reading an ambient clock);
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
    else:
        print("  i src/core/dst_driver_only.ail not present yet (machinery commit); profile check skipped")

    print("  ✓ no fact in the fixtures is a stale transcription of the tool's output")


if __name__ == "__main__":
    main()
