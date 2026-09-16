#!/usr/bin/env python3
"""Synthetic fixtures for the ADR-004 evaluator (PLAN-004 §3, matrix rows M6 and M1).

The THIRD implementation of the digest forms, written from ADR-003/ADR-004's
definitions in Python `hashlib`, so a fixture's expected digest never comes
from the evaluator's copies (`src/eval/journal/digests.ail`) or from the
candidate functions they copy (`src/core/phase_vocab.ail`, `src/core/journal.ail`,
`src/core/tool_dispatch_adapter.ail`).

Every fixture is synthetic (PLAN-004 §0.6): no journal, excerpt or session
content is read or written here.

It is also the third implementation of ADR-003 D4's fold and of ADR-004 D1's
path, strict decoding and seed (P1.2a, M1): `journal_fixtures.ail` carries
synthetic journals and what this file's own fold and reader say about them, so
the reader's expectations never come from `src/eval/journal/reader.ail`'s
copies or from `src/core/journal.ail`.

Usage:
    gen_fixtures.py            # write digest_fixtures.ail and journal_fixtures.ail
    gen_fixtures.py --check    # exit 1 if either is stale
"""

import hashlib
import json
import sys
from pathlib import Path

OUT = Path(__file__).with_name("digest_fixtures.ail")
JOURNAL_OUT = Path(__file__).with_name("journal_fixtures.ail")

# ---------------------------------------------------------------------------
# The forms.
# ---------------------------------------------------------------------------

# `make[20]` .. `make[1]`, longest first, each to `make[0]`. `make[21]` and
# above are NOT normalised (the canonical form lists exactly twenty).
MAKE_PAIRS = [(f"make[{n}]", "make[0]") for n in range(20, 0, -1)]


def frame(label, value):
    # Length is in code points: AILANG's `std/string.length` counts runes.
    return f"{label}:{len(value)}:{value};"


def normalise_make(value):
    for old, new in MAKE_PAIRS:
        value = value.replace(old, new)
    return value


def tool_calls_form(calls):
    out = []
    for c in calls:
        out.append("tc{" + frame("id", c["id"]) + frame("name", c["name"]) + frame("args", c["arguments"]) + "}")
    return "".join(out) + "tc-end;"


def message_body(m, content):
    return (frame("role", m["role"]) + frame("content", content)
            + frame("tool_call_id", m["tool_call_id"])
            + frame("tool_calls_len", str(len(m["tool_calls"])))
            + tool_calls_form(m["tool_calls"]))


def images_form(images):
    return "".join("im{" + frame("source", i["source"]) + frame("mime", i["mime"]) + "}" for i in images) + "im-end;"


def sha(s):
    return "sha256:" + hashlib.sha256(s.encode("utf-8")).hexdigest()


def payload_digest(msgs):
    """D: canonical form, content normalised, no images."""
    return sha("".join("m{" + message_body(m, normalise_make(m["content"])) + "}" for m in msgs) + "m-end;")


def system_prefix(msgs):
    out = []
    for m in msgs:
        if m["role"] != "system":
            break
        out.append(m)
    return out


def system_prefix_digest(msgs):
    """S: raw canonical form (no normalisation, no images) over the leading system messages."""
    pinned = system_prefix(msgs)
    return sha("".join("m{" + message_body(m, m["content"]) + "}" for m in pinned) + "m-end;")


def raw_frame_digest(msgs):
    """R: the append chain over raw frames (content verbatim, images framed),
    based at the empty history's canonical digest."""
    d = payload_digest([])
    for m in msgs:
        d = sha(d + "m{" + message_body(m, m["content"]) + images_form(m["images"]) + "}")
    return d


def compact_json(v):
    """Compact, keys in source order, duplicates kept, non-ASCII verbatim."""
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, Pairs):  # before `list`: Pairs subclasses it
        return "{" + ",".join(json.dumps(k, ensure_ascii=False) + ":" + compact_json(x) for k, x in v) + "}"
    if isinstance(v, list):
        return "[" + ",".join(compact_json(x) for x in v) + "]"
    raise TypeError(type(v))


class Pairs(list):
    pass


def canonical_arguments(source):
    return compact_json(json.loads(source, object_pairs_hook=Pairs))


# ---------------------------------------------------------------------------
# The fixtures (synthetic).
# ---------------------------------------------------------------------------

def msg(role, content, tool_calls=(), tool_call_id="", images=()):
    return {"role": role, "content": content, "tool_calls": list(tool_calls),
            "tool_call_id": tool_call_id, "images": list(images)}


def call(i, name, args):
    return {"id": i, "name": name, "arguments": args}


def img(source, mime):
    return {"source": source, "mime": mime}


SYS = msg("system", "You are a synthetic fixture.")
SYS2 = msg("system", "Second pinned line.")
USER = msg("user", "List the files.")

MESSAGE_FIXTURES = [
    ("empty", []),
    ("plain", [SYS, USER, msg("assistant", "Done.")]),
    ("no_system", [USER, msg("assistant", "ok")]),
    ("two_system_then_late_system",
     [SYS, SYS2, USER, msg("system", "not pinned: after a user message"), msg("assistant", "x")]),
    ("tool_calls",
     [SYS, USER,
      msg("assistant", "",
          tool_calls=[call("call_1", "BashExec", "{\"command\":\"ls\"}"),
                      call("call_2", "ReadFile", "{ \"path\" : \"a.txt\", \"lines\": [1, 2] }")]),
      msg("tool", "a.txt\nb.txt", tool_call_id="call_1"),
      msg("tool", "alpha", tool_call_id="call_2")]),
    ("image",
     [SYS, msg("user", "what is in this",
               images=[img("iVBORw0KGgoAAAA=", "image/png"), img("https://example.invalid/x.jpg", "image/jpeg")])]),
    ("image_swapped",
     [SYS, msg("user", "what is in this",
               images=[img("/9j/4AAQSkZJRg==", "image/png"), img("https://example.invalid/x.jpg", "image/jpeg")])]),
    ("make_n",
     [SYS, msg("tool", "make[3]: Entering directory '/w'\nmake[12]: Leaving directory '/w'\nmake[21]: kept",
               tool_call_id="call_9")]),
    ("make_n_renumbered",
     [SYS, msg("tool", "make[7]: Entering directory '/w'\nmake[20]: Leaving directory '/w'\nmake[21]: kept",
               tool_call_id="call_9")]),
    ("unicode_and_escapes",
     [msg("system", "tab\there \"quoted\" back\\slash"), msg("user", "h\u00e9llo \u20ac \U0001F600\r\nend \u0001")]),
]

ARGUMENT_FIXTURES = [
    ("spaced_object", "{ \"b\" : 1, \"a\" : [1, 2.5, 1.0], \"c\": {\"z\": null, \"y\": true, \"x\": false} }"),
    ("reordered_object", "{\"a\":[1,2.5,1.0],\"b\":1,\"c\":{\"z\":null,\"y\":true,\"x\":false}}"),
    ("already_compact", "{\"command\":\"ls -la\"}"),
    ("unicode", "{\"\u00e9\": \"\U0001F600\", \"s\": \"x\\\"y\\\\n\\n\"}"),
    ("empty_array", " [ ] "),
    ("duplicate_keys", "{\"k\":1,\"k\":2}"),
]

MALFORMED_ARGUMENTS = ["{bad", "", "{\"a\":1", "[1,]"]


# ---------------------------------------------------------------------------
# Emission as an AILANG module.
# ---------------------------------------------------------------------------

def lit(s):
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "$":
            out.append("\\u{24}")
        elif o < 0x20 or o == 0x7F:
            out.append("\\u{%x}" % o)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def ail_list(items, indent):
    if not items:
        return "[]"
    pad = " " * indent
    return "[\n" + ",\n".join(pad + "  " + x for x in items) + "\n" + pad + "]"


def ail_message(m, indent):
    calls = ail_list([f"{{ id: {lit(c['id'])}, name: {lit(c['name'])}, arguments: {lit(c['arguments'])} }}"
                      for c in m["tool_calls"]], indent + 2)
    images = ail_list([f"{{ source: {lit(i['source'])}, mime: {lit(i['mime'])} }}" for i in m["images"]], indent + 2)
    return (f"{{ role: {lit(m['role'])}, content: {lit(m['content'])}, tool_call_id: {lit(m['tool_call_id'])},\n"
            f"{' ' * (indent + 2)}tool_calls: {calls},\n"
            f"{' ' * (indent + 2)}images: {images} }}")


def render():
    lines = [
        "-- GENERATED by src/eval/journal/testdata/gen_fixtures.py -- do not edit.",
        "-- Regenerate with `python3 src/eval/journal/testdata/gen_fixtures.py`;",
        "-- `--check` fails when this file is stale.",
        "--",
        "-- Synthetic digest fixtures (PLAN-004 M6). Every expected digest here was",
        "-- computed by the Python generator (hashlib), a third implementation",
        "-- independent of `src/eval/journal/digests.ail` and of `src/core`.",
        "",
        "module src/eval/journal/testdata/digest_fixtures",
        "",
        "import std/ai (Message, ToolCall, ImagePart)",
        "",
        "export type MessageFixture = { name: string, msgs: [Message], payload: string, system: string, raw: string }",
        "",
        "export type ArgumentFixture = { name: string, source: string, canonical: string, digest: string }",
        "",
    ]
    for name, msgs in MESSAGE_FIXTURES:
        body = ail_list([ail_message(m, 2) for m in msgs], 2)
        lines += [f"export pure func fx_msgs_{name}() -> [Message] {{", f"  {body}", "}", ""]
    entries = []
    for name, msgs in MESSAGE_FIXTURES:
        entries.append(
            f"{{ name: {lit(name)}, msgs: fx_msgs_{name}(),\n"
            f"      payload: {lit(payload_digest(msgs))},\n"
            f"      system: {lit(system_prefix_digest(msgs))},\n"
            f"      raw: {lit(raw_frame_digest(msgs))} }}")
    lines += ["export pure func fx_message_fixtures() -> [MessageFixture] {", f"  {ail_list(entries, 2)}", "}", ""]
    entries = []
    for name, src in ARGUMENT_FIXTURES:
        canon = canonical_arguments(src)
        entries.append(f"{{ name: {lit(name)}, source: {lit(src)},\n"
                       f"      canonical: {lit(canon)},\n"
                       f"      digest: {lit(sha(canon))} }}")
    lines += ["export pure func fx_argument_fixtures() -> [ArgumentFixture] {", f"  {ail_list(entries, 2)}", "}", ""]
    for src in MALFORMED_ARGUMENTS:
        try:
            json.loads(src)
        except ValueError:
            continue
        raise AssertionError(f"malformed fixture decodes: {src!r}")
    lines += ["export pure func fx_malformed_arguments() -> [string] {",
              f"  {ail_list([lit(s) for s in MALFORMED_ARGUMENTS], 2)}", "}", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# M1: synthetic journals, an independent fold (ADR-003 D4) and an independent
# reader (ADR-004 D1: path, strict decoding, seed).
# ---------------------------------------------------------------------------

class Refused(Exception):
    """A refusal: `kind` is journal.ail's refusal id, `seq` the entry (-1 for
    none), `field` the field or detail."""

    def __init__(self, kind, seq=-1, field=""):
        super().__init__(kind, seq, field)
        self.kind, self.seq, self.field = kind, seq, field


class ReaderRefused(Exception):
    """A D1 source refusal: family, position label, field."""

    def __init__(self, family, position, field=""):
        super().__init__(family, position, field)
        self.family, self.position, self.field = family, position, field


WAKE_OUTCOMES = ["settled", "lost", "operator_input", "timed_out", "host_error", "aborted"]


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def req(obj, key, typ, seq, field=None):
    v = obj.get(key) if isinstance(obj, dict) else None
    ok = {"str": isinstance(v, str), "int": _is_int(v), "bool": isinstance(v, bool),
          "list": isinstance(v, list), "obj": isinstance(v, dict)}[typ]
    if not ok:
        raise Refused("entry", seq, field or key)
    return v


def msg_field(m, key, typ, where):
    if key not in m:
        raise ValueError(f"{where}.{key}: missing")
    v = m[key]
    if typ == "str" and not isinstance(v, str):
        raise ValueError(f"{where}.{key}: not a string")
    if typ == "list" and not isinstance(v, list):
        raise ValueError(f"{where}.{key}: not an array")
    return v


def decode_message(m, where):
    role = msg_field(m, "role", "str", where)
    content = msg_field(m, "content", "str", where)
    tcid = msg_field(m, "tool_call_id", "str", where)
    calls = []
    for c in msg_field(m, "tool_calls", "list", where):
        w = f"{where}.tool_calls"
        calls.append(call(msg_field(c, "id", "str", w), msg_field(c, "name", "str", w),
                          msg_field(c, "arguments", "str", w)))
    images = []
    for i in msg_field(m, "images", "list", where):
        w = f"{where}.images"
        images.append(img(msg_field(i, "source", "str", w), msg_field(i, "mime", "str", w)))
    return msg(role, content, calls, tcid, images)


def counts_ok(obj, key, seq):
    c = req(obj, key, "obj", seq)
    for k in ["provider_calls_started", "provider_calls_completed", "stage_applied_total",
              "stage_rejected_total", "compaction_ai_applied"]:
        req(c, k, "int", seq, f"{key}.{k}")


def decode_header(e):
    seq = e["seq"]
    if e["type"] != "header":
        raise Refused("header")
    if req(e, "schema_version", "int", seq) != 1:
        raise Refused("schema")
    for k in ["session_id", "workdir", "profile", "ext_set_digest", "model", "system_prefix_digest"]:
        req(e, k, "str", seq)
    b = req(e, "boot", "obj", seq)
    for k, t in [("task", "str"), ("env_url", "str"), ("hybrid_tools", "bool")]:
        req(b, k, t, seq, f"boot.{k}")
    bp = req(b, "budget", "obj", seq, "boot.budget")
    for k in ["total", "solver", "verifier"]:
        req(bp, k, "int", seq, f"boot.budget.{k}")
    for k, t in [("step_budget", "int"), ("ohmy_pi", "bool"), ("max_cost_millicents", "int")]:
        req(b, k, t, seq, f"boot.{k}")
    cr = req(b, "cost_rates", "obj", seq, "boot.cost_rates")
    for k in ["input_per_1m_millicents", "output_per_1m_millicents"]:
        req(cr, k, "int", seq, f"boot.cost_rates.{k}")
    return {"model": e["model"], "profile": e["profile"]}


def decode_appended(e):
    seq = e["seq"]
    run_id = req(e, "run_id", "str", seq)
    req(e, "step", "int", seq)
    mj = req(e, "message", "obj", seq)
    try:
        m = decode_message(mj, "message")
    except ValueError as err:
        raise Refused("entry", seq, str(err))
    rep = req(e, "replaces_previous", "bool", seq)
    d = req(e, "digest_after", "str", seq)
    return {"run_id": run_id, "message": m, "replaces_previous": rep, "digest_after": d}


def decode_wait(w):
    if not isinstance(w, dict) or sorted(w) != ["id"] or not isinstance(w["id"], str) or w["id"] == "":
        raise ValueError("wait")


def decode_entry(e):
    """Strict decode by type; returns a small dict for the kinds the fold reads."""
    seq, kind = e["seq"], e["type"]
    if kind == "history_appended":
        return decode_appended(e)
    if kind == "state_delta":
        req(e, "run_id", "str", seq)
        req(e, "step", "int", seq)
        counts_ok(e, "cumulative", seq)
        t = req(e, "telemetry", "obj", seq)
        for k in ["last_input_tokens", "last_output_tokens", "last_estimated_input_tokens"]:
            req(t, k, "int", seq, f"telemetry.{k}")
        req(e, "ext_artifacts_digest", "str", seq)
        return {"cumulative": e["cumulative"]}
    if kind == "settings":
        for k in ["model", "profile"]:
            if k in e and not isinstance(e[k], str):
                raise Refused("entry", seq, k)
        return {"model": e.get("model"), "profile": e.get("profile")}
    if kind == "run_started":
        return {"run_id": req(e, "run_id", "str", seq)}
    if kind == "run_finished":
        run_id = req(e, "run_id", "str", seq)
        counts_ok(e, "cumulative", seq)
        ordinal = req(e, "world_ordinal", "int", seq)
        req(e, "finish_reason", "str", seq)
        return {"run_id": run_id, "world_ordinal": ordinal}
    if kind == "suspended":
        run_id = req(e, "run_id", "str", seq)
        req(e, "reason", "str", seq)
        return {"run_id": run_id, "step": req(e, "step", "int", seq)}
    if kind == "park":
        rid = req(e, "request_id", "str", seq)
        req(e, "step", "int", seq)
        ws = req(e, "waits", "list", seq)
        if not ws:
            raise Refused("entry", seq, "waits")
        for w in ws:
            try:
                decode_wait(w)
            except ValueError:
                raise Refused("entry", seq, "waits")
        return {"request_id": rid}
    if kind == "wake":
        rid = req(e, "request_id", "str", seq)
        req(e, "wait_id", "str", seq)
        outcome = req(e, "outcome", "str", seq)
        if outcome not in WAKE_OUTCOMES:
            raise Refused("entry", seq, "outcome")
        req(e, "detail", "str", seq)
        return {"request_id": rid, "outcome": outcome}
    if kind == "header":
        raise Refused("header")
    if kind == "resumed":
        # P1.2b: a cross-process resume between a suspension and the run it
        # continues (ContinuationStart). journal.ail's `resumed_of_entry`.
        for k, t in [("resume_count", "int"), ("from_id", "str"), ("from_ordinal", "int"),
                     ("profile_from", "str"), ("profile_to", "str"), ("prompt_digest_from", "str"),
                     ("prompt_digest_to", "str"), ("forced", "bool")]:
            req(e, k, t, seq)
        return {}
    if kind in ("history_replaced", "exit"):
        raise NotImplementedError(f"the generator's fold does not model `{kind}`; no fixture uses it")
    raise Refused("entry", seq, f"type={kind}")


def check_envelopes(lines):
    for idx, e in enumerate(lines):
        if not _is_int(e.get("seq")):
            return Refused("entry", -1, "seq"), idx
        for k, t in [("id", "str"), ("at_ms", "int"), ("type", "str")]:
            v = e.get(k)
            if not (isinstance(v, str) if t == "str" else _is_int(v)):
                return Refused("entry", e["seq"], k), idx
    return None, None


def lenient_path(lines, leaf):
    """journal.ail's rule 1: climb by parent_id, stop at a missing or repeated id."""
    by_id = {}
    for e in lines:
        by_id.setdefault(e["id"], e)
    path, seen, cur = [], set(), leaf
    while cur and cur not in seen and cur in by_id:
        seen.add(cur)
        e = by_id[cur]
        path.append(e)
        cur = e.get("parent_id") or ""
    return list(reversed(path))


def fold(lines, leaf):
    """ADR-003 D4, as journal.ail implements it. Returns the folded state or
    raises Refused."""
    bad, _ = check_envelopes(lines)
    if bad:
        raise bad
    path = lenient_path(lines, leaf)
    if not path:
        raise Refused("header")
    hdr = decode_header(path[0])
    base = payload_digest([])
    hist = []  # (seq, message)
    digest, prev = base, base
    model, profile = hdr["model"], hdr["profile"]
    last, ordinal = ("open", "header"), 0
    for e in path[1:]:
        d = decode_entry(e)
        kind, seq = e["type"], e["seq"]
        if kind == "history_appended":
            # journal.ail `fold_append`: a replacement drops the last message
            # and chains from the digest before it (P1.2b's counting fixture).
            base = prev if d["replaces_previous"] else digest
            if d["replaces_previous"]:
                hist = hist[:-1]
            expected = sha(base + "m{" + message_body(d["message"], d["message"]["content"])
                           + images_form(d["message"]["images"]) + "}")
            if d["digest_after"] != expected:
                raise Refused("digest", seq)
            hist.append((seq, d["message"]))
            prev, digest = base, expected
            last = ("open", "history_appended")
        elif kind == "state_delta":
            last = ("open", "state_delta")
        elif kind == "settings":
            model = d["model"] if d["model"] is not None else model
            profile = d["profile"] if d["profile"] is not None else profile
            last = ("open", "settings")
        elif kind == "run_started":
            last = ("open", "run_started")
        elif kind == "run_finished":
            ordinal = d["world_ordinal"]
            if not (last[0] == "suspended" and last[1] == d["run_id"]):
                last = ("run_finished", d["run_id"])
        elif kind == "suspended":
            last = ("suspended", d["run_id"])
        elif kind == "resumed":
            last = ("open", "resumed")
        elif kind == "park":
            last = ("parked", d["request_id"], False)
        elif kind == "wake":
            if last[0] != "parked" or last[2] or last[1] != d["request_id"]:
                raise Refused("entry", seq, "request_id")
            last = ("open", "wake:aborted") if d["outcome"] == "aborted" else ("parked", last[1], True)
    # pairing
    open_ids, cur_ids, cur_seq = [], [], -1
    for seq, m in hist:
        if m["role"] == "tool":
            if m["tool_call_id"] not in cur_ids:
                raise Refused("pairing", seq)
            open_ids = [i for i in open_ids if i != m["tool_call_id"]]
        elif open_ids:
            raise Refused("pairing", cur_seq)
        elif m["tool_calls"]:
            open_ids = [c["id"] for c in m["tool_calls"]]
            cur_ids, cur_seq = list(open_ids), seq
    msgs = []
    for seq, m in hist:
        if open_ids and seq == cur_seq and m["tool_calls"]:
            m = dict(m, tool_calls=[c for c in m["tool_calls"] if c["id"] not in open_ids])
        msgs.append(m)
    head = True
    for m in msgs:
        if m["role"] == "system" and not head:
            raise Refused("head-prefix")
        head = head and m["role"] == "system"
    for m in msgs:
        if (m["role"] == "tool" and m["tool_call_id"] == "") or any(c["id"] == "" for c in m["tool_calls"]):
            raise Refused("transcript")
    boundary = {"open": lambda: f"open:{last[1]}", "run_finished": lambda: "run_finished",
                "suspended": lambda: "suspended", "parked": lambda: "parked"}[last[0]]()
    return {"history": msgs, "dangling": open_ids, "model": model, "profile": profile,
            "boundary": boundary, "world_ordinal": ordinal,
            "wake_answered": last[0] == "parked" and last[2]}


def refusal_label(r):
    return f"{r.kind}:{r.seq}:{r.field}"


def to_family(r, root_seq):
    if r.kind == "entry":
        pos = f"entry:{r.seq}"
        if r.field.startswith("type="):
            return ReaderRefused("UnknownEntryType", pos, r.field[len("type="):])
        return ReaderRefused("MalformedEntry", pos, r.field)
    if r.kind == "digest":
        return ReaderRefused("ChainBreak", f"entry:{r.seq}", "digest_after")
    if r.kind == "schema":
        return ReaderRefused("UnknownSchema", f"entry:{root_seq}", "schema_version")
    if r.kind == "pairing":
        return ReaderRefused("MalformedEntry", f"entry:{r.seq}", "pairing")
    if r.kind in ("head-prefix", "transcript"):
        return ReaderRefused("MalformedEntry", "path", r.kind)
    return ReaderRefused("ChainBreak", "path", r.kind)


def strict_path(lines, leaf):
    """ADR-004 D1's path: journal.ail's rule 1 made strict — a leaf or parent
    that names no entry, or a cycle, is a chain break at the entry that names
    it; the root must be the header and no other entry may be one."""
    by_id = {}
    for e in lines:
        by_id.setdefault(e["id"], e)
    if leaf not in by_id:
        raise ReaderRefused("ChainBreak", "path", "leaf")
    path, seen, cur = [], set(), leaf
    while True:
        e = by_id[cur]
        seen.add(cur)
        path.append(e)
        parent = e.get("parent_id") or ""
        if parent == "":
            break
        if parent in seen:
            raise ReaderRefused("ChainBreak", f"entry:{e['seq']}", "parent_id")
        if parent not in by_id:
            raise ReaderRefused("ChainBreak", f"entry:{e['seq']}", "parent_id")
        cur = parent
    path.reverse()
    if path[0]["type"] != "header":
        raise ReaderRefused("ChainBreak", f"entry:{path[0]['seq']}", "root")
    for e in path[1:]:
        if e["type"] == "header":
            raise ReaderRefused("ChainBreak", f"entry:{e['seq']}", "header")
    return path


def turn_tail_kind(e):
    return e["type"] == "state_delta" or (e["type"] == "history_appended" and e["message"]["role"] == "tool")


def read(lines, sel):
    """ADR-004 D1: path, strict decoding, seed. Returns the reader's summary or
    raises ReaderRefused. `BadSelector` is the reader's precondition, not a D1
    refusal family."""
    bad, idx = check_envelopes(lines)
    if bad:
        pos = f"entry:{bad.seq}" if bad.seq >= 0 else f"line:{idx}"
        raise ReaderRefused("MalformedEntry", pos, bad.field)
    path = strict_path(lines, sel["leaf"])
    root_seq = path[0]["seq"]
    try:
        decode_header(path[0])
        whole = fold(lines, sel["leaf"])
    except Refused as r:
        raise to_family(r, root_seq)
    ids = [e["id"] for e in path]
    if sel["start"] not in ids:
        raise ReaderRefused("BadSelector", "path", "start")
    si = ids.index(sel["start"])
    s = path[si]
    if (s["type"] != "history_appended" or s["message"]["role"] != "assistant"
            or s["run_id"] != sel["run_id"] or s["replaces_previous"]):
        raise ReaderRefused("BadSelector", "path", "start")
    runs = [i for i in range(si) if path[i]["type"] == "run_started" and path[i]["run_id"] == sel["run_id"]]
    if not runs:
        raise ReaderRefused("BadSelector", "path", "run_id")
    ri = runs[-1]
    for e in path[ri + 1:si]:
        if e["type"] == "history_appended" and e["message"]["role"] == "assistant":
            raise ReaderRefused("BadSelector", "path", "start")
    kind, end_id = sel["end"]
    # `EndAt` may name `start` itself (a one-call segment); `CutoffBefore` must
    # leave at least `start` inside.
    if end_id not in ids or ids.index(end_id) < si or (kind != "EndAt" and ids.index(end_id) == si):
        raise ReaderRefused("BadSelector", "path", "end")
    ei = ids.index(end_id)
    if kind == "EndAt":
        e = path[ei]
        if e["type"] != "history_appended" or e["message"]["role"] != "assistant" or e["run_id"] != sel["run_id"]:
            raise ReaderRefused("BadSelector", "path", "end")
        stop = ei + 1
        while stop < len(path) and turn_tail_kind(path[stop]):
            stop += 1
    else:
        stop = ei
    segment = path[si:stop]
    seed = fold(lines, s["parent_id"])
    # A run opened by a consumed wake: the path up to its `run_started` folds to
    # a park answered by a wake (journal.ail's `BoundaryParked(p, Some(w))`).
    opened = fold(lines, path[ri]["parent_id"])["wake_answered"]
    return {
        "whole": whole,
        "seed": seed,
        "segment_kinds": [e["type"] for e in segment],
        "segment_calls": [len(e["message"]["tool_calls"]) for e in segment
                          if e["type"] == "history_appended" and e["message"]["role"] == "assistant"],
        "parks": [e["seq"] for e in segment if e["type"] == "park"],
        "opened_by_wake": opened,
        "start_seq": s["seq"],
        "run_started_seq": path[ri]["seq"],
        "path": path,
        "ri": ri,
        "segment": segment,
    }


# -- the synthetic journal ---------------------------------------------------

SESSION = "sess_fx"
RUN_A, RUN_B, RUN_C = "sess_fx.r0.0", "sess_fx.r0.1", "sess_fx.r0.2"
ZERO_COUNTS = {"provider_calls_started": 0, "provider_calls_completed": 0, "stage_applied_total": 0,
               "stage_rejected_total": 0, "compaction_ai_applied": 0}


def counts(n):
    return dict(ZERO_COUNTS, provider_calls_started=n, provider_calls_completed=n)


def header_body(schema=1):
    return {"type": "header", "schema_version": schema, "session_id": SESSION, "workdir": "/fx/work",
            "profile": "fx-profile", "ext_set_digest": "sha256:fx-ext", "model": "fx/model-a",
            "system_prefix_digest": "sha256:fx-sys",
            "boot": {"task": "list the files", "env_url": "", "hybrid_tools": True,
                     "budget": {"total": 12, "solver": 12, "verifier": 0}, "step_budget": 12,
                     "ohmy_pi": False, "max_cost_millicents": 0,
                     "cost_rates": {"input_per_1m_millicents": 0, "output_per_1m_millicents": 0}}}


def app(run, step, m):
    return {"type": "history_appended", "run_id": run, "step": step, "message": m, "replaces_previous": False}


def delta(run, step, n):
    return {"type": "state_delta", "run_id": run, "step": step, "cumulative": counts(n),
            "telemetry": {"last_input_tokens": 10 * n, "last_output_tokens": n, "last_estimated_input_tokens": 9 * n},
            "ext_artifacts_digest": "sha256:fx-art"}


def asst(text, *calls):
    return msg("assistant", text, [call(i, "BashExec", "{\"command\":\"ls " + i + "\"}") for i in calls])


def tool(i, text):
    return msg("tool", text, tool_call_id=i)


def park(rid):
    return {"type": "park", "request_id": rid, "step": 4, "waits": [{"id": "w_" + rid}]}


def wake(rid, outcome="settled"):
    return {"type": "wake", "request_id": rid, "wait_id": "w_" + rid, "outcome": outcome, "detail": ""}


def base_bodies():
    """The r2.1 shape at fixture scale: run A folds into the seed; run B starts
    with a leading user entry (r2.1's 1055) before its first assistant (1056,
    `start`), then three continuation calls; run B suspends."""
    return [
        header_body(),                                                   # e0
        {"type": "run_started", "run_id": RUN_A},                        # e1
        app(RUN_A, 0, msg("system", "You are a synthetic fixture.")),    # e2
        app(RUN_A, 0, msg("user", "list the files")),                    # e3
        app(RUN_A, 1, asst("", "c1")),                                   # e4
        app(RUN_A, 1, tool("c1", "a.txt\nb.txt")),                       # e5
        delta(RUN_A, 1, 1),                                              # e6
        app(RUN_A, 2, asst("Two files.")),                               # e7
        delta(RUN_A, 2, 2),                                              # e8
        {"type": "run_finished", "run_id": RUN_A, "cumulative": counts(2),
         "world_ordinal": 3, "finish_reason": "stop"},                   # e9
        {"type": "settings", "model": "fx/model-b"},                     # e10
        {"type": "run_started", "run_id": RUN_B},                        # e11
        app(RUN_B, 0, msg("user", "now count the lines")),               # e12  leading user
        app(RUN_B, 1, asst("", "c2")),                                   # e13  start, call 1
        app(RUN_B, 1, tool("c2", "2 a.txt")),                            # e14
        delta(RUN_B, 1, 3),                                              # e15
        app(RUN_B, 2, asst("", "c3")),                                   # e16  call 2
        app(RUN_B, 2, tool("c3", "5 b.txt")),                            # e17
        delta(RUN_B, 2, 4),                                              # e18
        app(RUN_B, 3, asst("", "c4")),                                   # e19  call 3 (EndAt)
        app(RUN_B, 3, tool("c4", "7 total")),                            # e20
        delta(RUN_B, 3, 5),                                              # e21
        {"type": "suspended", "run_id": RUN_B, "reason": "max_steps", "step": 3},   # e22
        {"type": "run_finished", "run_id": RUN_B, "cumulative": counts(5),
         "world_ordinal": 9, "finish_reason": "max_steps"},              # e23
    ]


def park_wake_bodies():
    """Run B continues past its third call, parks, is woken, and the wake
    opens run C (whose first line is the injected wake message)."""
    b = base_bodies()[:22]
    return b + [
        park("sess_fx.r0.1.p0"),                                         # e22
        wake("sess_fx.r0.1.p0"),                                         # e23
        {"type": "run_started", "run_id": RUN_C},                        # e24
        app(RUN_C, 0, msg("user", "the wait settled")),                  # e25
        app(RUN_C, 1, asst("", "c5")),                                   # e26
        app(RUN_C, 1, tool("c5", "ok")),                                 # e27
    ]


def chain(bodies, parents=None):
    """Envelope and digest every body; `parents` overrides parent ids by index."""
    lines, digest = [], payload_digest([])
    prev = digest
    for i, b in enumerate(bodies):
        e = {"id": f"e{i}", "parent_id": None if i == 0 else f"e{i - 1}", "seq": i, "at_ms": 1000 + i}
        e.update(b)
        if parents and i in parents:
            e["parent_id"] = parents[i]
        if e["type"] == "history_appended":
            m = e["message"]
            base = prev if e["replaces_previous"] else digest
            prev, digest = base, sha(base + "m{" + message_body(m, m["content"]) + images_form(m["images"]) + "}")
            e["digest_after"] = digest
        lines.append(e)
    return lines


def with_message(bodies, i, **fields):
    """Change a message BEFORE chaining: the chain stays consistent."""
    out = [dict(b) for b in bodies]
    out[i]["message"] = dict(out[i]["message"], **fields)
    return out


def with_content(bodies, i, text):
    return with_message(bodies, i, content=text)


def post(lines, i, fn):
    out = [dict(e) for e in lines]
    fn(out[i])
    return out


def drop_key(key):
    return lambda e: e.pop(key)


def drop_message_key(key):
    def f(e):
        e["message"] = {k: v for k, v in e["message"].items() if k != key}
    return f


def set_key(key, value):
    return lambda e: e.__setitem__(key, value)


def set_message_key(key, value):
    def f(e):
        e["message"] = dict(e["message"], **{key: value})
    return f


def sel(leaf, start, end, run=RUN_B):
    return {"leaf": leaf, "run_id": run, "start": start, "end": end}


BASE_SEL = sel("e23", "e13", ("EndAt", "e19"))
REFUSED_SEL = sel("e21", "e13", ("EndAt", "e19"))


def journal_fixtures():
    base = chain(base_bodies())
    pw = chain(park_wake_bodies())
    b21 = base_bodies()[:22]
    fx = [
        # clean
        ("clean", base, BASE_SEL, None),
        ("clean_cutoff_before", base, sel("e23", "e13", ("CutoffBefore", "e16")), None),
        ("incomplete_tail", chain(base_bodies()[:20]), sel("e19", "e13", ("EndAt", "e19")), None),
        ("park_wake", pw, sel("e27", "e13", ("CutoffBefore", "e22")), None),
        ("park_in_segment", pw, sel("e27", "e13", ("CutoffBefore", "e24")), None),
        ("wake_opened_run", pw, sel("e27", "e26", ("EndAt", "e26"), run=RUN_C), None),
        # M15 near-misses: pass M1's refusals
        ("near_miss_chain_break", chain(with_content(base_bodies(), 14, "3 a.txt")), BASE_SEL, None),
        ("near_miss_malformed_entry", chain(with_content(base_bodies(), 13, "checking")), BASE_SEL, None),
        # M1 refusals
        ("chain_break_digest", post(chain(base_bodies()), 17,
                                    set_message_key("content", "6 b.txt")), BASE_SEL,
         ("ChainBreak", "entry:17", "digest_after")),
        ("chain_break_parent", chain(base_bodies(), {15: "e99"}), BASE_SEL,
         ("ChainBreak", "entry:15", "parent_id")),
        ("chain_break_cycle", chain(base_bodies(), {2: "e5"}), BASE_SEL,
         ("ChainBreak", "entry:2", "parent_id")),
        ("chain_break_root", post(chain(base_bodies()), 1, set_key("parent_id", None)), BASE_SEL,
         ("ChainBreak", "entry:1", "root")),
        ("malformed_field", post(base, 16, drop_key("step")), BASE_SEL,
         ("MalformedEntry", "entry:16", "step")),
        ("malformed_message", post(base, 14, drop_message_key("images")), BASE_SEL,
         ("MalformedEntry", "entry:14", "message.images: missing")),
        ("malformed_envelope", post(base, 18, drop_key("at_ms")), BASE_SEL,
         ("MalformedEntry", "entry:18", "at_ms")),
        ("malformed_seq", post(base, 18, drop_key("seq")), BASE_SEL,
         ("MalformedEntry", "line:18", "seq")),
        ("malformed_pairing", chain(with_message(base_bodies(), 14, tool_call_id="c_other")), BASE_SEL,
         ("MalformedEntry", "entry:14", "pairing")),
        ("stray_wake_no_park", chain(b21 + [wake("sess_fx.r0.1.p0")]), sel("e22", "e13", ("EndAt", "e19")),
         ("MalformedEntry", "entry:22", "request_id")),
        ("stray_wake_answered", chain(b21 + [park("sess_fx.r0.1.p0"), wake("sess_fx.r0.1.p0"),
                                              wake("sess_fx.r0.1.p0")]), sel("e24", "e13", ("EndAt", "e19")),
         ("MalformedEntry", "entry:24", "request_id")),
        ("stray_wake_other_request", chain(b21 + [park("sess_fx.r0.1.p0"), wake("sess_fx.r0.1.p1")]),
         sel("e23", "e13", ("EndAt", "e19")),
         ("MalformedEntry", "entry:23", "request_id")),
        ("unknown_entry_type", post(base, 15, set_key("type", "bogus_kind")), BASE_SEL,
         ("UnknownEntryType", "entry:15", "bogus_kind")),
        ("unknown_schema", chain([header_body(schema=2)] + base_bodies()[1:]), BASE_SEL,
         ("UnknownSchema", "entry:0", "schema_version")),
        # the reader's own precondition
        ("bad_selector_start", base, sel("e23", "e12", ("EndAt", "e19")), ("BadSelector", "path", "start")),
        ("bad_selector_not_first_call", base, sel("e23", "e16", ("EndAt", "e19")),
         ("BadSelector", "path", "start")),
    ]
    return fx


def check_fixture(name, lines, s, expected):
    try:
        r = read(lines, s)
    except ReaderRefused as err:
        got = (err.family, err.position, err.field)
        if got != expected:
            raise AssertionError(f"{name}: reader refused {got}, fixture declares {expected}")
        return None
    if expected is not None:
        raise AssertionError(f"{name}: reader accepted, fixture declares {expected}")
    return r


def fold_expectation(lines, leaf):
    try:
        st = fold(lines, leaf)
    except Refused as r:
        return {"ok": False, "refusal": refusal_label(r)}
    return {"ok": True, "refusal": "", "st": st}


def ail_strings(xs):
    return "[" + ", ".join(lit(x) for x in xs) + "]"


def ail_ints(xs):
    return "[" + ", ".join(str(x) for x in xs) + "]"


def render_journal():
    lines = [
        "-- GENERATED by src/eval/journal/testdata/gen_fixtures.py -- do not edit.",
        "-- Regenerate with `python3 src/eval/journal/testdata/gen_fixtures.py`;",
        "-- `--check` fails when this file is stale.",
        "--",
        "-- Synthetic journals (PLAN-004 M1, and M15's M1 near-misses). Every",
        "-- expectation here was computed by the Python generator's own fold and",
        "-- reader, independent of `src/eval/journal/reader.ail` and of `src/core`.",
        "-- `fold_*` is ADR-003 D4 at the leaf (journal.ail's semantics; a refusal is",
        "-- `<refusal_id>:<seq>:<field>`); `reader_*` is ADR-004 D1 for the selector.",
        "",
        "module src/eval/journal/testdata/journal_fixtures",
        "",
        "export type JournalFixture = {",
        "  name: string, lines: [string],",
        "  leaf: string, run_id: string, start: string, end_kind: string, end_id: string,",
        "  fold_ok: bool, fold_refusal: string,",
        "  history_count: int, history_payload: string, history_raw: string,",
        "  dangling: [string], boundary: string, model: string, profile: string, world_ordinal: int,",
        "  reader_ok: bool, reader_family: string, reader_position: string, reader_field: string,",
        "  seed_count: int, seed_payload: string, seed_last_role: string, seed_dangling: [string], seed_model: string,",
        "  segment_kinds: [string], segment_calls: [int], parks: [int], opened_by_wake: bool,",
        "  start_seq: int, run_started_seq: int",
        "}",
        "",
    ]
    entries = []
    for name, jl, s, expected in journal_fixtures():
        r = check_fixture(name, jl, s, expected)
        fe = fold_expectation(jl, s["leaf"])
        st = fe.get("st")
        text = [json.dumps(e, ensure_ascii=False, separators=(",", ":")) for e in jl]
        seed = r["seed"] if r else None
        fields = [
            f"name: {lit(name)}",
            f"lines: {ail_list([lit(t) for t in text], 6)}",
            f"leaf: {lit(s['leaf'])}, run_id: {lit(s['run_id'])}, start: {lit(s['start'])}, "
            f"end_kind: {lit(s['end'][0])}, end_id: {lit(s['end'][1])}",
            f"fold_ok: {'true' if fe['ok'] else 'false'}, fold_refusal: {lit(fe['refusal'])}",
            f"history_count: {len(st['history']) if st else 0}, "
            f"history_payload: {lit(payload_digest(st['history']) if st else '')}, "
            f"history_raw: {lit(raw_frame_digest(st['history']) if st else '')}",
            f"dangling: {ail_strings(st['dangling'] if st else [])}, boundary: {lit(st['boundary'] if st else '')}, "
            f"model: {lit(st['model'] if st else '')}, profile: {lit(st['profile'] if st else '')}, "
            f"world_ordinal: {st['world_ordinal'] if st else 0}",
            f"reader_ok: {'true' if r else 'false'}, "
            f"reader_family: {lit(expected[0] if expected else '')}, "
            f"reader_position: {lit(expected[1] if expected else '')}, "
            f"reader_field: {lit(expected[2] if expected else '')}",
            f"seed_count: {len(seed['history']) if seed else 0}, "
            f"seed_payload: {lit(payload_digest(seed['history']) if seed else '')}, "
            f"seed_last_role: {lit(seed['history'][-1]['role'] if seed else '')}, "
            f"seed_dangling: {ail_strings(seed['dangling'] if seed else [])}, "
            f"seed_model: {lit(seed['model'] if seed else '')}",
            f"segment_kinds: {ail_strings(r['segment_kinds'] if r else [])}, "
            f"segment_calls: {ail_ints(r['segment_calls'] if r else [])}, "
            f"parks: {ail_ints(r['parks'] if r else [])}, "
            f"opened_by_wake: {'true' if r and r['opened_by_wake'] else 'false'}",
            f"start_seq: {r['start_seq'] if r else -1}, run_started_seq: {r['run_started_seq'] if r else -1}",
        ]
        entries.append("{ " + ",\n      ".join(fields) + " }")
        lines += [f"export pure func fxj_{name}() -> JournalFixture {{", f"  {entries[-1]}", "}", ""]
    names = [n for n, _, _, _ in journal_fixtures()]
    lines += ["export pure func fxj_all() -> [JournalFixture] {",
              f"  {ail_list([f'fxj_{n}()' for n in names], 2)}", "}", ""]
    return "\n".join(lines)
# ---------------------------------------------------------------------------
# M2 (P1.2b): an independent excerpt reader, attribution, argument decoding,
# ordered association and the ContinuationStart / EmptySegment refusals
# (ADR-004 D1), over synthetic journals and synthetic host logs.
# ---------------------------------------------------------------------------

ASSOC_OUT = Path(__file__).with_name("association_fixtures.ail")

EXCERPT_TYPES = ("session_start", "provider_call_prepared", "thinking", "context_limit_resolved",
                 "stream_error_retry")


class RunRefused(Exception):
    """A D1 refusal at P1.2b's layer: family, position label, field."""

    def __init__(self, family, position, field=""):
        super().__init__(family, position, field)
        self.family, self.position, self.field = family, position, field


def _x_int(v):
    return (isinstance(v, (int, float)) and not isinstance(v, bool)
            and float(v).is_integer())


def _x_req(o, key, typ, i, where):
    v = o.get(key)
    ok = {"str": isinstance(v, str), "int": _x_int(v), "obj": isinstance(v, dict),
          "strs": isinstance(v, list) and all(isinstance(x, str) for x in v)}[typ]
    if not ok:
        raise RunRefused("Association", f"event:{i}", f"{where}.{key}")
    return int(v) if typ == "int" else v


def read_excerpt(log):
    """The host log's lines -> D1's five event types, in file order, each with
    its line index. Every line must be a JSON object with a string `type`."""
    out = []
    for i, text in enumerate(log):
        try:
            o = json.loads(text)
        except ValueError:
            raise RunRefused("Association", f"event:{i}", "json")
        if not isinstance(o, dict) or not isinstance(o.get("type"), str):
            raise RunRefused("Association", f"event:{i}", "type")
        t = o["type"]
        if t not in EXCERPT_TYPES:
            continue
        if t == "session_start":
            ledger = "run_id" in o
            rpc = "config_profile" in o or "loaded_extensions" in o
            if ledger == rpc:
                raise RunRefused("Association", f"event:{i}", "session_start.shape")
            if ledger:
                ev = {"kind": "ledger_start", "run_id": _x_req(o, "run_id", "str", i, t),
                      "mode": _x_req(o, "mode", "str", i, t), "model": _x_req(o, "model", "str", i, t)}
            else:
                ev = {"kind": "rpc_start", "model": _x_req(o, "model", "str", i, t),
                      "config_profile": _x_req(o, "config_profile", "str", i, t),
                      "loaded_extensions": _x_req(o, "loaded_extensions", "strs", i, t)}
        elif t == "provider_call_prepared":
            ev = {"kind": "prepared", "step": _x_req(o, "step", "int", i, t),
                  "msg_count": _x_req(o, "msg_count", "int", i, t),
                  "payload_digest": _x_req(o, "payload_digest", "str", i, t),
                  "system_prefix_digest": _x_req(o, "system_prefix_digest", "str", i, t),
                  "model": _x_req(o, "model", "str", i, t)}
        elif t == "thinking":
            ev = {"kind": "thinking", "step": _x_req(o, "step", "int", i, t),
                  "finish_reason": _x_req(o, "finish_reason", "str", i, t),
                  "input_tokens": _x_req(o, "input_tokens", "int", i, t),
                  "output_tokens": _x_req(o, "output_tokens", "int", i, t),
                  "tool_calls": _x_req(o, "tool_calls", "int", i, t)}
            for k in ("cache_read_input_tokens", "cache_creation_input_tokens"):
                if k in o:
                    n = _x_req(o, k, "int", i, t)
                    if n <= 0:
                        raise RunRefused("Association", f"event:{i}", f"{t}.{k}")
                    ev[k] = n
                else:
                    ev[k] = 0
        elif t == "context_limit_resolved":
            src = _x_req(o, "context_limit_source", "obj", i, t)
            ev = {"kind": "context_limit", "run_id": _x_req(o, "run_id", "str", i, t),
                  "context_limit": _x_req(o, "context_limit", "int", i, t),
                  "source": [_x_req(src, k, "str", i, f"{t}.context_limit_source")
                             for k in ("arm", "origin", "profile_miss", "catalogue_miss", "model")]}
        else:
            ev = {"kind": "retry", "step": _x_req(o, "step", "int", i, t)}
        ev["index"] = i
        out.append(ev)
    return out


def attribute(segment):
    """Every tool result is attributed to the most recent assistant's calls, in
    source order; every call's arguments decode. Returns, per assistant seq,
    the recorded tools [(seq, call_id, canonical arguments)]."""
    cur, answered, tools = None, [], {}
    for e in segment:
        if e["type"] != "history_appended":
            continue
        m, seq = e["message"], e["seq"]
        if m["role"] == "assistant":
            ids = [c["id"] for c in m["tool_calls"]]
            if len(set(ids)) != len(ids):
                raise RunRefused("DuplicateOrAmbiguousCallId", f"entry:{seq}", "tool_calls.id")
            for n, c in enumerate(m["tool_calls"]):
                try:
                    canonical_arguments(c["arguments"])
                except ValueError:
                    raise RunRefused("MalformedToolArguments", f"entry:{seq}", f"tool_calls[{n}].arguments")
            cur, answered = e, []
            tools[seq] = []
        elif m["role"] == "tool":
            tid = m["tool_call_id"]
            calls = {c["id"]: c for c in cur["message"]["tool_calls"]} if cur else {}
            if tid not in calls:
                raise RunRefused("UnexpectedToolResult", f"entry:{seq}", "tool_call_id")
            if tid in answered:
                raise RunRefused("DuplicateOrAmbiguousCallId", f"entry:{seq}", "tool_call_id")
            answered.append(tid)
            tools[cur["seq"]].append((seq, tid, canonical_arguments(calls[tid]["arguments"])))
    return tools


def continuation_start(lines, r):
    rs = r["path"][r["ri"]]
    if r["opened_by_wake"]:
        raise RunRefused("ContinuationStart", f"entry:{rs['seq']}", "wake")
    j = r["ri"] - 1
    while j > 0 and r["path"][j]["type"] in ("resumed", "settings", "history_replaced"):
        j -= 1
    if fold(lines, r["path"][j]["id"])["boundary"] == "suspended":
        raise RunRefused("ContinuationStart", f"entry:{rs['seq']}", "suspended")


def associate(events, run_id, segment):
    starts = [j for j, e in enumerate(events) if e["kind"] == "ledger_start" and e["run_id"] == run_id]
    if not starts:
        raise RunRefused("Association", "excerpt", "session_start.run_id")
    if len(starts) > 1:
        raise RunRefused("Association", f"event:{events[starts[1]]['index']}", "session_start.run_id")
    j0 = starts[0]
    end = next((j for j in range(j0 + 1, len(events)) if events[j]["kind"] in ("ledger_start", "rpc_start")),
               len(events))
    profile = [e["index"] for e in events[:j0] if e["kind"] == "rpc_start"]
    span = events[j0 + 1:end]
    counted = [e for e in segment if e["type"] == "history_appended" and e["message"]["role"] == "assistant"
               and not e["replaces_previous"]]
    calls, cut, cur = [], None, 0
    for k, a in enumerate(counted, 1):
        p = next((x for x in range(cur, len(span)) if span[x]["kind"] == "prepared"), None)
        if p is None:
            raise RunRefused("Association", f"entry:{a['seq']}", "provider_call_prepared")
        P = span[p]
        nxt = next((x for x in range(p + 1, len(span)) if span[x]["kind"] == "prepared"), len(span))
        window = [x for x in span[p + 1:nxt] if x["kind"] in ("thinking", "retry") and x["step"] == P["step"]]
        if window and window[0]["kind"] == "retry":
            cut = ("ProviderRetry", k, window[0]["index"])
            break
        thinks = [x for x in window if x["kind"] == "thinking"]
        if not thinks:
            if nxt < len(span) and span[nxt]["step"] == P["step"]:
                raise RunRefused("Association", f"event:{span[nxt]['index']}", "provider_call_prepared")
            raise RunRefused("Association", f"event:{P['index']}", "thinking")
        if len(thinks) > 1:
            raise RunRefused("Association", f"event:{thinks[1]['index']}", "thinking")
        T = thinks[0]
        if T["tool_calls"] != len(a["message"]["tool_calls"]):
            raise RunRefused("Association", f"event:{T['index']}", "tool_calls")
        calls.append({"k": k, "seq": a["seq"], "prepared": P["index"], "thinking": T["index"]})
        cur = nxt
    if not calls:
        pos = f"entry:{counted[0]['seq']}"
        raise RunRefused("EmptySegment", pos, cut[0] if cut else "")
    return {"run_event": events[j0]["index"], "profile_event": profile[-1] if profile else -1,
            "calls": calls, "cut": cut,
            "replacing": [e["seq"] for e in segment if e["type"] == "history_appended"
                          and e["message"]["role"] == "assistant" and e["replaces_previous"]]}


def read_run(lines, log, s):
    """P1.2b's reader: P1.2a's, then ContinuationStart, attribution and
    arguments, the excerpt, the association, EmptySegment."""
    try:
        r = read(lines, s)
    except ReaderRefused as err:
        if err.family == "MalformedEntry" and err.field == "pairing":
            seq = int(err.position.split(":")[1])
            e = next(x for x in lines if x["seq"] == seq)
            if e["type"] == "history_appended" and e["message"]["role"] == "tool":
                raise RunRefused("UnexpectedToolResult", err.position, "tool_call_id")
        raise RunRefused(err.family, err.position, err.field)
    continuation_start(lines, r)
    tools = attribute(r["segment"])
    events = read_excerpt(log)
    a = associate(events, s["run_id"], r["segment"])
    seg = r["segment"]
    for c in a["calls"]:
        i = next(n for n, e in enumerate(seg) if e["seq"] == c["seq"])
        c["tools"] = tools[c["seq"]]
        deltas = []
        for e in seg[i + 1:]:
            if e["type"] == "history_appended" and e["message"]["role"] == "assistant":
                break
            if e["type"] == "state_delta":
                deltas.append(e["seq"])
        c["deltas"] = deltas
        asst = seg[i]["message"]
        c["arguments"] = [f"{t['id']}={canonical_arguments(t['arguments'])}" for t in asst["tool_calls"]]
    a["events"] = events
    return a


# -- the synthetic host log ----------------------------------------------------

def m2_bodies():
    """The base journal with a two-call first turn in run B (e13: c2a, c2b)."""
    b = base_bodies()[:13]
    b[12] = app(RUN_B, 0, msg("user", "now count the lines"))
    return b + [
        app(RUN_B, 1, asst("", "c2a", "c2b")),                           # e13  start, call 1
        app(RUN_B, 1, tool("c2a", "2 a.txt")),                           # e14
        app(RUN_B, 1, tool("c2b", "5 b.txt")),                           # e15
        delta(RUN_B, 1, 3),                                              # e16
        app(RUN_B, 2, asst("", "c3")),                                   # e17  call 2
        app(RUN_B, 2, tool("c3", "7 total")),                            # e18
        delta(RUN_B, 2, 4),                                              # e19
        app(RUN_B, 3, asst("", "c4")),                                   # e20  call 3 (EndAt)
        app(RUN_B, 3, tool("c4", "done")),                               # e21
        delta(RUN_B, 3, 5),                                              # e22
        {"type": "suspended", "run_id": RUN_B, "reason": "max_steps", "step": 3},   # e23
        {"type": "run_finished", "run_id": RUN_B, "cumulative": counts(5),
         "world_ordinal": 9, "finish_reason": "max_steps"},              # e24
    ]


def resumed_body():
    return {"type": "resumed", "resume_count": 1, "from_id": "e8", "from_ordinal": 3,
            "profile_from": "fx-profile", "profile_to": "fx-profile",
            "prompt_digest_from": "sha256:fx-sys", "prompt_digest_to": "sha256:fx-sys", "forced": False}


def continuation_bodies(suspend, resume):
    """Run A ends (suspended or not), optionally a cross-process `resumed`,
    then run B's message start: user, one call."""
    b = base_bodies()[:7]                                                # e0..e6
    if suspend:
        b.append({"type": "suspended", "run_id": RUN_A, "reason": "max_steps", "step": 1})
    b.append({"type": "run_finished", "run_id": RUN_A, "cumulative": counts(1),
              "world_ordinal": 2, "finish_reason": "max_steps" if suspend else "stop"})
    if resume:
        b.append(resumed_body())
    return b + [
        {"type": "run_started", "run_id": RUN_B},
        app(RUN_B, 0, msg("user", "go on")),
        app(RUN_B, 1, asst("", "c2")),
        app(RUN_B, 1, tool("c2", "ok")),
        delta(RUN_B, 1, 2),
    ]


def rpc_banner(profile, exts):
    return {"type": "session_start", "task": "fx task", "model": "fx/model-a", "brainVersion": "fx",
            "ailangBuilt": "fx", "config_profile": profile, "config_dir": "/fx/cfg", "backend_mode": "fx",
            "loaded_extensions": exts}


def ledger_banner(run_id, model):
    return {"type": "session_start", "task": "fx task", "model": model, "mode": "v2", "run_id": run_id}


def limit_event(run_id):
    return {"type": "context_limit_resolved", "run_id": run_id, "context_limit": 4096,
            "context_limit_source": {"arm": "bounded", "origin": "profile", "profile_miss": "",
                                     "catalogue_miss": "", "model": ""}}


def build_log(lines, leaf):
    """A host log for every run on the leaf's path, derived from the journal:
    per counted assistant a `provider_call_prepared` over the request the
    journal implies (the fold before it) and a `thinking` with its call
    count, among events of other types; then a later spawn's run."""
    path = lenient_path(lines, leaf)
    out = [rpc_banner("fx-profile", [])]
    run, k = None, 0
    for n, e in enumerate(path):
        if e["type"] == "resumed":
            out.append(rpc_banner("fx-profile", ["fx-ext"]))
        if e["type"] == "run_started":
            if run is not None:
                out.append({"type": "run_summary", "run_id": run})
            run, k = e["run_id"], 0
            out.append(ledger_banner(run, fold(lines, e["parent_id"])["model"]))
            out.append(limit_event(run))
        if (e["type"] == "history_appended" and e["message"]["role"] == "assistant"
                and not e["replaces_previous"]):
            k += 1
            before = fold(lines, e["parent_id"])
            req_msgs = before["history"]
            step = e["step"]
            ncalls = len(e["message"]["tool_calls"])
            think = {"type": "thinking", "step": step, "text": "fx", "finish_reason": "tool_calls" if ncalls else "stop",
                     "input_tokens": 100 * k, "output_tokens": 10 * k, "tool_calls": ncalls, "cost_usd": 0}
            if run == RUN_B and k == 1:
                think["cache_read_input_tokens"] = 4
            if run == RUN_B and k == 2:
                think["cache_creation_input_tokens"] = 3
            out += [
                {"type": "thinking_stream_start", "step": step, "stream_id": f"step-{step}", "model": before["model"]},
                {"type": "provider_call_prepared", "step": step, "msg_count": len(req_msgs),
                 "estimated_input_tokens": 7 * len(req_msgs), "system_prefix_count": len(system_prefix(req_msgs)),
                 "system_prefix_chars": 0, "system_prefix_digest": system_prefix_digest(req_msgs),
                 "payload_digest": payload_digest(req_msgs), "model": before["model"]},
                {"type": "thinking_delta", "step": step, "stream_id": f"step-{step}", "seq": 0, "text_delta": "fx"},
                think,
            ]
            if ncalls:
                out.append({"type": "tool_execution_start", "step": step})
    out.append({"type": "run_summary", "run_id": run})
    out += [rpc_banner("fx-profile-2", ["fx-ext"]), ledger_banner("sess_fx.r1.0", "fx/model-b"),
            {"type": "provider_call_prepared", "step": 1, "msg_count": 1, "estimated_input_tokens": 7,
             "system_prefix_count": 0, "system_prefix_chars": 0, "system_prefix_digest": "sha256:fx-other",
             "payload_digest": "sha256:fx-other", "model": "fx/model-b"},
            {"type": "thinking", "step": 1, "text": "fx", "finish_reason": "stop", "input_tokens": 1,
             "output_tokens": 1, "tool_calls": 0, "cost_usd": 0}]
    return out


def log_text(events):
    return [e if isinstance(e, str) else json.dumps(e, ensure_ascii=False, separators=(",", ":")) for e in events]


def lx_insert(events, i, ev):
    return events[:i] + [ev] + events[i:]


def lx_drop(events, *idx):
    return [e for n, e in enumerate(events) if n not in idx]


def lx_set(events, i, **fields):
    out = list(events)
    out[i] = dict(out[i], **fields)
    return out


def lx_del(events, i, key):
    out = list(events)
    out[i] = {k: v for k, v in out[i].items() if k != key}
    return out


def insert_body(bodies, i, body):
    return bodies[:i] + [body] + bodies[i:]


def swap_bodies(bodies, i, j):
    out = list(bodies)
    out[i], out[j] = out[j], out[i]
    return out


M2_SEL = sel("e24", "e13", ("EndAt", "e20"))

# In the clean M2 log: run B's banner is line 13; call k's prepared is
# 16/21/26 and its thinking 18/23/28 (see `build_log`).


def run_fixtures():
    m2 = chain(m2_bodies())
    log = build_log(m2, "e24")
    stale = insert_body(insert_body(m2_bodies()[:17], 17, app(RUN_B, 2, asst("Checking."))), 18,
                        app(RUN_B, 2, tool("c2b", "late")))
    stale_j = chain(stale + [delta(RUN_B, 2, 4), app(RUN_B, 3, asst("", "c4")), app(RUN_B, 3, tool("c4", "done")),
                             delta(RUN_B, 3, 5)])
    dup_result = chain(insert_body(m2_bodies(), 16, app(RUN_B, 1, tool("c2a", "again"))))
    dup_ids = chain(with_message(with_message(m2_bodies(), 13, tool_calls=[
        call("c2a", "BashExec", "{\"command\":\"ls c2a\"}"), call("c2a", "BashExec", "{\"command\":\"ls c2b\"}")]),
        15, tool_call_id="c2a"))
    bad_args = chain(with_message(m2_bodies(), 13, tool_calls=[
        call("c2a", "BashExec", "{\"command\":\"ls c2a\"}"), call("c2b", "BashExec", "{bad")]))
    pairing = chain(with_message(m2_bodies(), 14, tool_call_id="c_other"))
    cont_s = chain(continuation_bodies(True, False))
    cont_r = chain(continuation_bodies(True, True))
    cont_t = chain(continuation_bodies(False, True))
    pw = chain(park_wake_bodies())
    retry2 = lx_insert(lx_drop(log, 23), 23, {"type": "stream_error_retry", "step": 2, "error": "fx"})
    retry2 = lx_insert(retry2, 24, dict(log[21], step=4))
    retry2 = lx_insert(retry2, 25, dict(log[23], step=4))
    retry1 = lx_insert(lx_drop(log, 18), 18, {"type": "stream_error_retry", "step": 1, "error": "fx"})
    retry1 = lx_insert(retry1, 19, dict(log[16], step=9))
    retry1 = lx_insert(retry1, 20, dict(log[18], step=9))
    nm_args = chain(with_message(m2_bodies(), 13, tool_calls=[
        call("c2a", "BashExec", "{\"command\":\"ls c2A\"}"), call("c2b", "BashExec", "{\"command\":\"ls c2b\"}")]))
    nm_args_log = build_log(nm_args, "e24")
    nm_result = chain(with_content(m2_bodies(), 14, "2 a.tXt"))
    nm_swap = chain(swap_bodies(m2_bodies(), 14, 15))
    replaced_b = m2_bodies()[:17] + [app(RUN_B, 2, asst("draft")),
                                     dict(app(RUN_B, 2, asst("final")), replaces_previous=True)] + m2_bodies()[19:]
    replaced = chain(replaced_b)
    return [
        # clean
        ("m2_clean", m2, log, M2_SEL, None),
        ("m2_clean_cutoff_before", m2, log, sel("e24", "e13", ("CutoffBefore", "e20")), None),
        ("m2_message_start_after_resume", cont_t, build_log(cont_t, "e13"),
         sel("e13", "e11", ("EndAt", "e11")), None),
        ("m2_retry_cut", m2, retry2, M2_SEL, None),
        ("m2_replacement_not_counted", replaced, build_log(replaced, "e24"), M2_SEL, None),
        # M15 near-misses: pass M2's refusals
        ("m15_unexpected_tool_result", nm_result, build_log(nm_result, "e24"), M2_SEL, None),
        ("m15_malformed_tool_arguments", nm_args, nm_args_log, M2_SEL, None),
        ("m15_duplicate_call_id_swap", nm_swap, build_log(nm_swap, "e24"), M2_SEL, None),
        ("m15_association", m2, lx_set(log, 16, payload_digest="sha256:fx-altered"), M2_SEL, None),
        # M2 refusals
        ("m2_duplicate_call_id", dup_ids, build_log(dup_ids, "e24"), M2_SEL,
         ("DuplicateOrAmbiguousCallId", "entry:13", "tool_calls.id")),
        ("m2_duplicate_result", dup_result, build_log(dup_result, "e25"),
         sel("e25", "e13", ("EndAt", "e21")),
         ("DuplicateOrAmbiguousCallId", "entry:16", "tool_call_id")),
        ("m2_unexpected_result_pairing", pairing, log, M2_SEL,
         ("UnexpectedToolResult", "entry:14", "tool_call_id")),
        ("m2_unexpected_result_stale", stale_j, build_log(stale_j, "e22"),
         sel("e22", "e13", ("EndAt", "e20")),
         ("UnexpectedToolResult", "entry:18", "tool_call_id")),
        ("m2_malformed_tool_arguments", bad_args, build_log(m2, "e24"), M2_SEL,
         ("MalformedToolArguments", "entry:13", "tool_calls[1].arguments")),
        ("m2_association_extra_prepared", m2, lx_insert(log, 17, log[16]), M2_SEL,
         ("Association", "event:17", "provider_call_prepared")),
        ("m2_association_extra_prepared_step", m2, lx_insert(log, 20, dict(log[21], step=7)), M2_SEL,
         ("Association", "event:20", "thinking")),
        ("m2_association_extra_assistant", m2, lx_drop(log, 25, 26, 27, 28, 29), M2_SEL,
         ("Association", "entry:20", "provider_call_prepared")),
        ("m2_association_tool_calls", m2, lx_set(log, 18, tool_calls=1), M2_SEL,
         ("Association", "event:18", "tool_calls")),
        ("m2_association_second_thinking", m2, lx_insert(log, 24, log[23]), M2_SEL,
         ("Association", "event:24", "thinking")),
        ("m2_association_no_run", m2, lx_set(log, 13, run_id="sess_fx.r9.9"), M2_SEL,
         ("Association", "excerpt", "session_start.run_id")),
        ("m2_association_two_runs", m2, lx_insert(log, 30, log[13]), M2_SEL,
         ("Association", "event:30", "session_start.run_id")),
        ("m2_excerpt_missing_field", m2, lx_del(log, 21, "payload_digest"), M2_SEL,
         ("Association", "event:21", "provider_call_prepared.payload_digest")),
        ("m2_excerpt_session_start_shape", m2, lx_set(log, 0, run_id=RUN_A), M2_SEL,
         ("Association", "event:0", "session_start.shape")),
        ("m2_excerpt_zero_cache", m2, lx_set(log, 28, cache_read_input_tokens=0), M2_SEL,
         ("Association", "event:28", "thinking.cache_read_input_tokens")),
        ("m2_excerpt_type_not_string", m2, lx_set(log, 12, type=7), M2_SEL,
         ("Association", "event:12", "type")),
        ("m2_excerpt_not_json_line", m2, lx_insert(log, 12, "{truncated"), M2_SEL,
         ("Association", "event:12", "json")),
        ("m2_continuation_suspended", cont_s, build_log(cont_s, "e13"),
         sel("e13", "e11", ("EndAt", "e11")),
         ("ContinuationStart", "entry:9", "suspended")),
        ("m2_continuation_suspended_resumed", cont_r, build_log(cont_r, "e14"),
         sel("e14", "e12", ("EndAt", "e12")),
         ("ContinuationStart", "entry:10", "suspended")),
        ("m2_continuation_wake", pw, build_log(pw, "e27"),
         sel("e27", "e26", ("EndAt", "e26"), run=RUN_C),
         ("ContinuationStart", "entry:24", "wake")),
        ("m2_empty_segment", m2, retry1, M2_SEL,
         ("EmptySegment", "entry:13", "ProviderRetry")),
        # P1.2a's refusals pass through unchanged, the pairing refusal at an
        # assistant (a call left open) included
        ("m2_source_refusal", post(m2, 17, drop_key("step")), log, M2_SEL,
         ("MalformedEntry", "entry:17", "step")),
        ("m2_source_pairing_at_assistant", chain(m2_bodies()[:15] + m2_bodies()[16:]), log,
         sel("e23", "e13", ("EndAt", "e19")),
         ("MalformedEntry", "entry:13", "pairing")),
    ]


def check_run_fixture(name, lines, log, s, expected):
    try:
        a = read_run(lines, log_text(log), s)
    except RunRefused as err:
        got = (err.family, err.position, err.field)
        if got != expected:
            raise AssertionError(f"{name}: read_run refused {got}, fixture declares {expected}")
        return None
    if expected is not None:
        raise AssertionError(f"{name}: read_run accepted, fixture declares {expected}")
    return a


def render_association():
    lines = [
        "-- GENERATED by src/eval/journal/testdata/gen_fixtures.py -- do not edit.",
        "-- Regenerate with `python3 src/eval/journal/testdata/gen_fixtures.py`;",
        "-- `--check` fails when this file is stale.",
        "--",
        "-- Synthetic journals and synthetic host logs (PLAN-004 M2, and M15's M2",
        "-- near-misses). Every expectation here was computed by the Python",
        "-- generator's own excerpt reader, attribution and association,",
        "-- independent of `src/eval/journal/{excerpt,association}.ail` and of",
        "-- `src/core`. No session content: the logs are built from the synthetic",
        "-- journals.",
        "",
        "module src/eval/journal/testdata/association_fixtures",
        "",
        "export type RunFixture = {",
        "  name: string, journal: [string], log: [string],",
        "  leaf: string, run_id: string, start: string, end_kind: string, end_id: string,",
        "  ok: bool, family: string, position: string, field: string,",
        "  excerpt_kinds: [string], excerpt_events: [int],",
        "  run_event: int, profile_event: int,",
        "  call_seqs: [int], prepared_events: [int], thinking_events: [int],",
        "  tool_seqs: [int], tool_ids: [string], tool_arguments: [string], call_arguments: [string],",
        "  deltas: [int], cut_reason: string, cut_call: int, cut_event: int, replacing: [int]",
        "}",
        "",
    ]
    names = []
    for name, jl, log, s, expected in run_fixtures():
        a = check_run_fixture(name, jl, log, s, expected)
        names.append(name)
        journal = [json.dumps(e, ensure_ascii=False, separators=(",", ":")) for e in jl]
        calls = a["calls"] if a else []
        tools = [t for c in calls for t in c["tools"]]
        cut = a["cut"] if a else None
        fields = [
            f"name: {lit(name)}",
            f"journal: {ail_list([lit(t) for t in journal], 6)}",
            f"log: {ail_list([lit(t) for t in log_text(log)], 6)}",
            f"leaf: {lit(s['leaf'])}, run_id: {lit(s['run_id'])}, start: {lit(s['start'])}, "
            f"end_kind: {lit(s['end'][0])}, end_id: {lit(s['end'][1])}",
            f"ok: {'true' if a else 'false'}, family: {lit(expected[0] if expected else '')}, "
            f"position: {lit(expected[1] if expected else '')}, field: {lit(expected[2] if expected else '')}",
            f"excerpt_kinds: {ail_strings([e['kind'] for e in a['events']] if a else [])}, "
            f"excerpt_events: {ail_ints([e['index'] for e in a['events']] if a else [])}",
            f"run_event: {a['run_event'] if a else -1}, profile_event: {a['profile_event'] if a else -1}",
            f"call_seqs: {ail_ints([c['seq'] for c in calls])}, "
            f"prepared_events: {ail_ints([c['prepared'] for c in calls])}, "
            f"thinking_events: {ail_ints([c['thinking'] for c in calls])}",
            f"tool_seqs: {ail_ints([t[0] for t in tools])}, tool_ids: {ail_strings([t[1] for t in tools])}, "
            f"tool_arguments: {ail_strings([t[2] for t in tools])}, "
            f"call_arguments: {ail_strings([x for c in calls for x in c['arguments']])}",
            f"deltas: {ail_ints([d for c in calls for d in c['deltas']])}, "
            f"cut_reason: {lit(cut[0] if cut else '')}, cut_call: {cut[1] if cut else 0}, "
            f"cut_event: {cut[2] if cut else -1}, replacing: {ail_ints(a['replacing'] if a else [])}",
        ]
        lines += [f"export pure func fxr_{name}() -> RunFixture {{", "  { " + ",\n      ".join(fields) + " }", "}", ""]
    lines += ["export pure func fxr_all() -> [RunFixture] {",
              f"  {ail_list([f'fxr_{n}()' for n in names], 2)}", "}", ""]
    return "\n".join(lines)


def main(argv):
    outputs = [(OUT, render()), (JOURNAL_OUT, render_journal()), (ASSOC_OUT, render_association())]
    if "--check" in argv:
        stale = [str(path) for path, text in outputs
                 if not path.exists() or path.read_text(encoding="utf-8") != text]
        for path in stale:
            print(f"stale: {path}", file=sys.stderr)
        if stale:
            return 1
        for path, _ in outputs:
            print(f"up to date: {path}")
        return 0
    for path, text in outputs:
        path.write_text(text, encoding="utf-8")
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
