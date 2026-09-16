#!/usr/bin/env python3
"""Synthetic digest fixtures for the ADR-004 evaluator (PLAN-004 §3, matrix row M6).

The THIRD implementation of the digest forms, written from ADR-003/ADR-004's
definitions in Python `hashlib`, so a fixture's expected digest never comes
from the evaluator's copies (`src/eval/journal/digests.ail`) or from the
candidate functions they copy (`src/core/phase_vocab.ail`, `src/core/journal.ail`,
`src/core/tool_dispatch_adapter.ail`).

Every fixture is synthetic (PLAN-004 §0.6): no journal, excerpt or session
content is read or written here.

Usage:
    gen_fixtures.py            # write digest_fixtures.ail beside this file
    gen_fixtures.py --check    # exit 1 if digest_fixtures.ail is stale
"""

import hashlib
import json
import sys
from pathlib import Path

OUT = Path(__file__).with_name("digest_fixtures.ail")

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


def main(argv):
    text = render()
    if "--check" in argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"stale: {OUT}", file=sys.stderr)
            return 1
        print(f"up to date: {OUT}")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
