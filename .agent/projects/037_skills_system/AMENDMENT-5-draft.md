# DRAFT — Amendment 5 to 031 ADR-001

Date: 2026-10-04. Status: **Draft — awaiting the operator's approval of the words. Not landed.**
Written by 037 PLAN-001 P2 (§4 step 4). Nothing in
`.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md` has been
edited.

The operator has ruled that Amendment 5 lands **before** the 033 release tag (PLAN-001 §7 Q5).
What is still open is the text. On approval, the landing is the three edits in "Where it goes"
below and nothing else.

## Where it goes

All three edits are to 031 `ADR-001-extension-owned-structured-decisions.md`. Line numbers are
that file's at `18065e4a`.

1. **The amendment itself**: appended to the `## Amendments` section (`:1185`), after Amendment 4
   and before `## Related records` (`:1313`). The text is the block under "The text" below,
   verbatim.
2. **The status line** (`:4`): `with Amendment 1` has not been extended for Amendments 2–4, so
   this draft does not touch it. If the operator wants the header to name the amendments, that is
   a separate edit and a separate decision.
3. **Related records** (`:1313` on): one line added —
   `- [037: Skills system](../037_skills_system/ADR-001-skills-system.md) — D2 is the decision Amendment 5 records`

## The artifact

`.agent/projects/037_skills_system/evidence/p2/amendment-5/ARTIFACT.txt`, with the two raw logs
beside it. A fixture in the registration-boundary script — a registration whose `config` carries
`registration_refusal` — measured three times: accepted by the host as it stood (`cfdf74c1`), red
the moment the check landed, and asserted as a refusal from `fdeda2cc` on.

## The text

Everything between the two rules is the amendment, exactly as it would be appended.

---

### Amendment 5 (2026-10-04) — a reserved `config` key, `registration_refusal`, by which an extension refuses its own registration

**Adds to** D2 (the configuration channel, `:347-375`; `ExtRegistration = { config, caps }` at
`:355`). **No type, constructor, function or version in the ABI package moves**: the amendment
reserves one key of `config` and states what the host does with it.

**The artifact: a registration the host accepted.** `ExtRegistration` has no error channel, and a
record the ABI exports no constructor for gains no field in 8.x (the ABI header's rule 1,
`packages/motoko-ext-abi/types.ail:27`). So an extension that finds at registration that it must
not be started had no way to say so — the case that raised it is 037 ADR-001 D1, a skill root that
breaks a rule. 037 PLAN-001 P2 put the gap in a fixture in the
registration-boundary script (`scripts/dst/registry_multiplicity_dst.ail`): a registration on the
clean capability list whose `config` is `{"registration_refusal": "<a non-empty string>"}`. At
`cfdf74c1`, against the host as it stood, `make registry_multiplicity` reported that row
**accepted**, the entry carrying the config unchanged and all eleven atoms
(`../037_skills_system/evidence/p2/amendment-5/ARTIFACT.txt`, with both raw logs). The key was
unused: no match for it under `src`, `packages`, `scripts` or `tools` at `18065e4a`. The same row
went red when the check landed (`fdeda2cc`) and now asserts the refusal.

**The rule.** The top-level key `registration_refusal` of `ExtRegistration.config` is reserved,
and an extension uses it for nothing else. An extension that refuses sets it and still returns its
ordinary `caps`.

| the key | the host |
|---|---|
| absent, or `config` is not an object | registers the extension, as before |
| the empty string | registers the extension, as before |
| a non-empty string | refuses the registration; that string is the message |
| any other JSON type, `null` included | refuses the registration, as a malformed refusal |

The host reads the key at the registration boundary — `normalize_registration` in
`src/core/ext/registry_normalize.ail` — **before** the multiplicity walk, and returns a sixth
`RegistrationRejection`, `RegistrationRefused(id, message)`, rule `registration-refused`. One
refusing extension rejects the whole registry build, as any rejection does; the generated registry
already turns a rejection into one JSONL `error` event and exit 2, and is not regenerated. The
host reads one string and learns nothing about why. A key that does not refuse is ordinary
configuration: carried on the entry, stamped as `ext_config` and hashed, unchanged.

**No version change, and what ties the two sides.** The key's name and semantics are stated in the
comment beside `ExtRegistration` in `packages/motoko-ext-abi/types.ail`. The ABI package exports
neither the key nor a reader and stays 8.0. The host's copy of the string and its reader are in
core, where `new_contract_policy` applies. The string therefore has two writers, and one row in
the registration-boundary script, which can import both sides, asserts that the extension's
spelling and the host's are equal.

**Consequence, stated.** The check is in core, and a package version says nothing about core: an
extension cannot depend its way onto a host that has the check. A host without it ignores the key
and starts. An extension that sets the key must therefore fail safe by itself — 037 ADR-001 D2
requires that, with a refusal recorded, its catalogue lists nothing and every call returns the
refusal as a tool error.

**Rejected alternatives.** An 8.1 minor exporting the key and its reader from the ABI package, so
the string has one owner: the manifest version is re-derived and compared by `check_abi_version`,
the package and DST manifests pin `8.0`, and journal admission compares a recorded ABI version
with the lock's, so corpora recorded at 8.0 would stop being admitted — a repository-wide sweep to
share one string (037 ADR-001 D2 prices it). An error field on `ExtRegistration`: excluded by the
8.x rule above. The extension printing the event and calling `exit(2)` itself: the first
registration in the tree to end the process, with the refusal and its message format outside the
one host-owned boundary.

---

## What the draft claims, and where each claim is checked

| Claim in the text | Checked by |
|---|---|
| The host as it stood accepted the fixture | `evidence/p2/amendment-5/step1_host_as_it_stands.raw.log` |
| The key was unused at `18065e4a` | `git grep -n registration_refusal 18065e4a -- src packages scripts tools` exits 1 (ARTIFACT.txt §2) |
| The four rows of the table | `test_refusal_*` in `src/core/ext/registry_normalize.ail`; `evidence/p2/mutgate.tsv` |
| Read before the multiplicity walk | `test_refusal_is_read_before_the_multiplicity_walk`; the order row in the boundary script |
| One refusing extension rejects the whole build | `test_refusal_rejects_the_whole_build` |
| The generated registry is not regenerated | `git diff 18065e4a -- src/core/ext/registry_generated.ail` is empty; `make registry_gen_check` |
| No type, function or version moves in the ABI package | `git diff 18065e4a -- packages/motoko-ext-abi/` adds comment lines only; `ailang.toml` untouched |
| `new_contract_policy` applies to the reader | `make new_contract_policy` (`evidence/p2/gates/`) |
| One row ties the two spellings | the same-string row in `scripts/dst/registry_multiplicity_dst.ail` — see the note below |

## Three things the operator should know before approving

1. **The same-string row has no extension to import yet.** The `skills` package is P3/P4, so at
   P2 the row compares the host's `registration_refusal_key()` with a stand-in for the extension's
   spelling written in the script. The sentence "which can import both sides" is true of the
   script and becomes true of the row at P5, when the stand-in is replaced by the package's own
   export. If the amendment should not say this before it is so, strike the last sentence of
   "No version change…" and add it when P5 lands.
2. **The ABI comment already cites "Amendment 5".** The comment beside `ExtRegistration` was
   written in P2, as the brief orders, and names `ADR-001 (031) Amendment 5`. Until this text
   lands, that citation points at a draft.
3. **A comment-only edit still moves the lock's content hash.** `ailang.lock` records a
   `content_hash` for the ABI package; after the comment, every `ailang` run prints
   `Warning: dependency sunholo/motoko_ext_abi content changed`. It is a warning about the
   content hash only; the package's version is untouched and the gates are unaffected
   (`evidence/p2/gates/`). The lock is P5's surface and P2 did not touch it.
