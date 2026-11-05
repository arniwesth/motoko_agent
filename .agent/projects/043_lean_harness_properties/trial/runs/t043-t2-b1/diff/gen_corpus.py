#!/usr/bin/env python3
"""Generates the differential-test corpus for HerdrFailureModel.lean, as three sources that
hold the SAME cases in the SAME order:

  gen/corpus.json        the TypeScript half reads it (enumerate.ts)
  gen/Corpus.lean        prepended to the Lean half (enumerate.lean.tail)
  gen/enumerate_herdr.ail  the AILANG half, with every stderr as a string literal

A case is (exit code, stderr); every stderr is crossed with every exit code in EXITS.
Inputs are aimed at the boundaries the two functions read: the exit-code tests (<= 0, == 0,
== 2), the `nested herdr` and `{"error"` substring sniffs, herdr's JSON envelope and its
`error.code`, whitespace JS `trim()` removes and JSON does not, key order, duplicate keys,
\\u escapes, non-string codes, trailing text, and codes that end in `_not_found`.

  python3 -I gen_corpus.py <out dir>     deterministic: seeded random part
"""
import json
import os
import random
import sys

EXITS = [-1, 0, 1, 2, 3, 127]

CODES = ["agent_not_found", "pane_not_found", "plugin_pane_not_found", "server_not_running",
         "timeout", "agent_prompt_stalled", "", "_not_found", "agent_not_found_x",
         "Agent_not_found", "agent_not_found ", "x", "not_found"]


def jstr(s):
    return json.dumps(s, ensure_ascii=True)


# How the code value is written inside the envelope.
def code_encodings():
    out = [jstr(c) for c in CODES]
    out += ['"agent\\u005fnot_found"', '"agent_not\\u005ffound"', '"\\u0061gent_not_found"',
            '"pane\\u005Fnot\\u005Ffound"', '5', 'null', 'true', '["agent_not_found"]',
            '{"x":"agent_not_found"}']
    return out


MESSAGES = ["x", "nested herdr", "no change"]


def envelopes(code, msg="x"):
    m = jstr(msg)
    return [
        '{"error":{"code":%s,"message":%s}}' % (code, m),
        '{"error":{"code":%s,"message":%s},"id":"cli:agent:get"}' % (code, m),
        '{"id":"cli:agent:get","error":{"code":%s,"message":%s}}' % (code, m),
        '{ "error": {"code": %s}}' % code,
        '{\n  "error": {\n    "code": %s\n  }\n}' % code,
        '{"error":{"message":%s}}' % m,
        '{"error":%s}' % code,
        '{"error":{"code":"timeout"},"error":{"code":%s}}' % code,
        '{"error":{"code":%s},"error":{"code":"timeout"}}' % code,
        '{"error":{"code":%s,"code":"timeout"}}' % code,
        '{"error":{"code":"timeout","code":%s}}' % code,
        '[{"error":{"code":%s}}]' % code,
        '{"error":{"code":%s}}x' % code,
        '{"error":{"code":%s}' % code,
        '{"error":{"code":%s}} {"error":{"code":%s}}' % (code, code),
        '{"result":null,"error":{"code":%s}}' % code,
        '{"error":{"code":%s,"message":%s,"details":[1,-2.5e3,true,false,null,{"a":[]}]}}' % (code, m),
    ]


WRAPS = [("", ""), ("", "\n"), (" ", ""), ("\t", "\r\n"), ("\n", "\n"),
         ("\u000b", ""), ("", "\u000c"), (" ", ""), ("﻿", ""), ("", " "),
         ("　", ""), ("", "\nkilled by SIGTERM"), ("warning: x\n", ""),
         # Either side of the edge of ECMAScript's whitespace set: U+0085, U+180E and U+200B
         # are NOT trimmed; U+1680, U+200A, U+2029, U+205F and U+202F are.
         ("\u0085", ""), ("\u180e", ""), ("\u200b", ""), ("", "\u0085"), ("\u1680", ""),
         ("\u200a", ""), ("", "\u2029"), ("\u205f", ""), ("\u202f", "")]

PLAIN = ["", " ", "\n", "usage", "herdr agent commands:",
         "error: nested herdr is disabled by default.", "--current requires HERDR_PANE_ID",
         "killed by SIGTERM", "killed by SIGKILL", "null", "true", "false", "5", "-0", "01",
         '"agent_not_found"', "{}", "[]", '{"error"', '{"error":}', '{"error":null}',
         '{"errors":{"code":"agent_not_found"}}', '{"Error":{"code":"agent_not_found"}}',
         '{"error":{"code":"agent_not_found"}', '{"error":{"code":"agent_not_found",}}',
         '{"error":{"code":\'agent_not_found\'}}', '{"error":{"code":"agent_not_found"}}}',
         '{"error":{"code":"agent\tnot_found"}}', '{"error":{"code":"agent\\x5fnot_found"}}',
         '{"error":{"code":"agent_not_found"}}\u0000', '\u0000{"error":{"code":"agent_not_found"}}',
         'nested herdr {"error":{"code":"agent_not_found"}}',
         '{"error":{"code":"agent_not_found","message":"error: nested herdr is disabled"}}',
         '{"__proto__":{"code":"agent_not_found"},"error":{"code":"agent_not_found"}}',
         '{"error":{"code":"agent_not_found"},"__proto__":null}',
         '{"error":{"code":"agent_not_found","n":1e400}}',
         '{"error":{"code":"agent_not_found","n":-}}',
         '{"error":{"code":"agent_not_found","n":.5}}',
         '{"error":{"code":"agent_not_found","n":1.}}',
         '{"error":{"code":"agent_not_found","s":"\\ud800"}}',
         '{"error":{"code":"agent_not_found","s":"café ☃"}}',
         '{"error":{"code":"agent_not_found","n":[1,2,]}}',
         ]
# Added after model correction 2 (float64 range in AILANG's decode): numbers either side of
# the largest double, 1.7976931348623157e308, and of the overflow threshold 2^1024 - 2^970.
for n in ["1e308", "1.7976931348623157e308", "1.7976931348623158e308", "1.797693134862315799e308",
          "1.7976931348623159e308", "17976931348623157" + "0" * 292, "17976931348623159" + "0" * 292,
          "1e309", "-1e400", "1e-400", "0e99999", "123456789012345678901234567890", "-0.0e-0",
          "1E+308", "0.00001e313", "1" + "0" * 400 + "e-100", "2e308"]:
    PLAIN.append('{"error":{"code":"agent_not_found","n":%s}}' % n)
# Trailing text after a complete value (model correction 1).
for t in ["}", "]", ",", " x", "\n{", "garbage", "\u0000", "null"]:
    PLAIN.append('{"error":{"code":"agent_not_found"}}' + t)
    PLAIN.append('  {"error":{"code":"pane_not_found"}}' + t)


def random_cases(rng, n):
    """Mutations of herdr's envelope: random JSON whitespace between tokens, random extra
    keys and key order, random \\u escapes of the code's characters, random code."""
    ws = [" ", "\n", "\t", "\r", ""]
    out = []
    for _ in range(n):
        code = rng.choice(CODES[:6] + ["pane_not_found", "agent_not_found"])
        enc = "".join(("\\u%04x" % ord(ch)) if rng.random() < 0.15 else ch for ch in code)
        w = lambda: rng.choice(ws) if rng.random() < 0.3 else ""
        inner = [("code", '"%s"' % enc), ("message", jstr(rng.choice(MESSAGES)))]
        rng.shuffle(inner)
        inner_s = "{" + ",".join('%s"%s"%s:%s%s%s' % (w(), k, w(), w(), v, w()) for k, v in inner) + "}"
        outer = [("error", inner_s)]
        if rng.random() < 0.5:
            outer.append(("id", '"cli:agent:%s"' % rng.choice(["get", "wait"])))
        rng.shuffle(outer)
        s = w() + "{" + ",".join('%s"%s"%s:%s%s%s' % (w(), k, w(), w(), v, w()) for k, v in outer) + "}" + w()
        out.append(s)
    return out


def corpus():
    seen, out = set(), []

    def add(s):
        if s not in seen:
            seen.add(s)
            out.append(s)

    for p in PLAIN:
        add(p)
    for enc in code_encodings():
        for e in envelopes(enc):
            add(e)
    for c in CODES:
        for msg in MESSAGES:
            for e in envelopes(jstr(c), msg)[:3]:
                add(e)
    for c in ["agent_not_found", "pane_not_found", "server_not_running"]:
        for e in envelopes(jstr(c))[:5]:
            for pre, suf in WRAPS:
                add(pre + e + suf)
    for pre, suf in WRAPS:
        for p in PLAIN[:12]:
            add(pre + p + suf)
    for s in random_cases(random.Random(43), 600):
        add(s)
    return out


def lean_lit(s):
    r = []
    for ch in s:
        o = ord(ch)
        if ch == '"':
            r.append('\\"')
        elif ch == "\\":
            r.append("\\\\")
        elif 32 <= o < 127:
            r.append(ch)
        else:
            r.append("\\u%04x" % o)
    return '"' + "".join(r) + '"'


def ail_lit(s):
    r = []
    for ch in s:
        o = ord(ch)
        if ch == '"':
            r.append('\\"')
        elif ch == "\\":
            r.append("\\\\")
        elif ch == "$":
            r.append("\\u{0024}")   # `${` would start an interpolation
        elif 32 <= o < 127:
            r.append(ch)
        else:
            r.append("\\u{%04x}" % o)
    return '"' + "".join(r) + '"'


AIL_HEAD = """-- enumerate_herdr.ail -- GENERATED by gen_corpus.py; do not edit.
-- The AILANG half of the differential test for HerdrFailureModel.lean: the REAL
-- `failure_code` and `means_agent_gone` (packages/motoko-ext-herdr/types.ail), over the
-- corpus, crossed with the exit codes, in the order of corpus.json and Corpus.lean.
-- One line per case:  <stderr index>|<exit code>|<failure_code>|<means_agent_gone>
--
-- From the repository root:
--   ailang run --relax-modules --caps IO --entry main <this file>

module enumerate_herdr

import std/io (println)
import std/string (intToStr, concat)
import pkg/sunholo/motoko_ext_herdr/types (failure_code, means_agent_gone)

pure func exits() -> [int] { %s }

func row(i: int, e: int, s: string) -> () ! {IO} {
  let gone = if means_agent_gone(e, s) then "true" else "false";
  println(concat([intToStr(i), "|", intToStr(e), "|", failure_code(e, s), "|", gone]))
}

func each_exit(i: int, es: [int], s: string) -> () ! {IO} {
  match es { [] => (), e :: rest => { row(i, e, s); each_exit(i, rest, s) } }
}

func walk(i: int, ss: [string]) -> () ! {IO} {
  match ss { [] => (), s :: rest => { each_exit(i, exits(), s); walk(i + 1, rest) } }
}
"""


def main():
    outdir = sys.argv[1]
    gen = os.path.join(outdir, "gen")
    os.makedirs(gen, exist_ok=True)
    cs = corpus()
    with open(os.path.join(gen, "corpus.json"), "w") as f:
        json.dump({"exits": EXITS, "stderr": cs}, f, ensure_ascii=True)
    with open(os.path.join(gen, "Corpus.lean"), "w") as f:
        f.write("-- GENERATED by gen_corpus.py; do not edit.\n")
        f.write("def corpusExits : List Int := [%s]\n" % ", ".join("(%d : Int)" % e for e in EXITS))
        f.write("def corpusStderr : List String := [\n  ")
        f.write(",\n  ".join(lean_lit(s) for s in cs))
        f.write("]\n")
    # AILANG: the corpus as chunks, so no single list literal is very long.
    chunks = [cs[i:i + 200] for i in range(0, len(cs), 200)]
    with open(os.path.join(gen, "enumerate_herdr.ail"), "w") as f:
        f.write(AIL_HEAD % ("[" + ", ".join(str(e) for e in EXITS) + "]"))
        for k, ch in enumerate(chunks):
            f.write("\npure func chunk%d() -> [string] {\n  [ " % k)
            f.write(",\n    ".join(ail_lit(s) for s in ch))
            f.write(" ]\n}\n")
        f.write("\nexport func main() -> () ! {IO} {\n")
        for k, ch in enumerate(chunks):
            f.write("  walk(%d, chunk%d());\n" % (k * 200, k))
        f.write("  ()\n}\n")
    # The package manifest that lets `pkg/sunholo/motoko_ext_herdr/types` resolve to the tree's
    # real package from here, without writing into the tree.
    with open(os.path.join(gen, "ailang.toml"), "w") as f:
        f.write('[package]\nname = "local/t2_diff"\nversion = "0.1.0"\nedition = "1"\n\n'
                '[dependencies]\n"sunholo/motoko_ext_herdr" = { path = "../../../tree/packages/motoko-ext-herdr" }\n')
    print("corpus: %d stderr strings x %d exit codes = %d cases" % (len(cs), len(EXITS), len(cs) * len(EXITS)))


if __name__ == "__main__":
    main()
