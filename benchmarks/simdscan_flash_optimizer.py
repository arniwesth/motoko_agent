#!/usr/bin/env python3
"""Phase 2(b) driver for the SIMD-scan autoresearch fixture: the model is the
candidate *generator* while scripts/ar_simdscan_harness.ail drives ar_run/ar_log +
held-out grading.

Given the objective, the simdjson paper technique, the current scan.c, and optional
run feedback, it asks the model (default deepseek-v4-flash) for an improved scan.c
and writes it to the worktree candidate. Then run an ar_run via the harness, read
the metric/correctness, and (on a correctness failure) feed the result back here
with --feedback to let the model fix it.

Usage:
  python3 benchmarks/simdscan_flash_optimizer.py [--feedback FILE]

Env overrides:
  SIMDSCAN_CANDIDATE  candidate file to read/overwrite
                      (default: the linked worktree's candidate/scan.c)
  FLASH_MODEL         OpenRouter model id (default: deepseek/deepseek-v4-flash)
  OPENROUTER_API_KEY  read from <repo>/.env if not already in the environment
"""
import os
import re
import sys
import json
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WT_CAND = os.environ.get(
    "SIMDSCAN_CANDIDATE",
    "/workspaces/motoko_agent_simdscan_wt/benchmarks/fixtures/autoresearch_simdscan/candidate/scan.c",
)
MODEL = os.environ.get("FLASH_MODEL", "deepseek/deepseek-v4-flash")

PAPER = """\
Reference material — from "Parsing Gigabytes of JSON per Second" (Langdale &
Lemire, arXiv:1902.08318), the SIMD structural-character classification technique:
- Load a block of bytes into a SIMD register (the paper uses 32-byte AVX2 / 64-byte
  blocks; on ARM NEON a 16-byte uint8x16_t block is natural).
- Classify many bytes in parallel instead of comparing each byte against each
  target individually: either (a) vectorized equality (compare the block against
  each target byte with a parallel compare-equal and OR the resulting lane masks),
  or (b) a nibble table-lookup trick (the targets have distinct low nibbles).
- Reduce the per-lane comparison results to find which lanes matched.
- Process fixed-size blocks unconditionally; handle the leftover tail (fewer than
  one block) with a scalar fallback, or by masking out-of-range lanes.
"""

OBJECTIVE = """\
You are optimizing a C function for throughput on a Linux aarch64 (ARM) machine,
compiled with `gcc -O2`. NEON is available via <arm_neon.h>. x86 intrinsics
(SSE/AVX, <immintrin.h>) are NOT available and will fail to compile.

The function records the index of every "special" byte in buf[0..len) into out[]
(in strictly increasing order) and returns the count. The special bytes are:
    '<' (0x3C)   '&' (0x26)   '\\r' (0x0D)   '\\0' (0x00)

HARD REQUIREMENTS (a candidate that violates these scores nothing):
- Output MUST match the reference scalar scan EXACTLY on every input, including
  buffers whose length is not a multiple of your vector width and buffers shorter
  than one vector block. Do not drop the tail.
- Pure computation only: no file I/O, no system calls, no reading any external
  data, no getenv. Only <stddef.h>, <stdint.h>, and <arm_neon.h> may be included.
- Keep the exact signature:
    size_t scan_special(const uint8_t *buf, size_t len, uint32_t *out)

Make it as fast as possible while staying exactly correct. Output the COMPLETE new
contents of scan.c inside a single ```c code block. No other prose is needed.
"""


def api_key() -> str:
    k = os.environ.get("OPENROUTER_API_KEY", "")
    if k:
        return k
    env = REPO_ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("OPENROUTER_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def extract_code(text: str) -> str:
    blocks = re.findall(r"```(?:c|cpp|C)?\s*\n(.*?)```", text, re.DOTALL)
    if blocks:
        return max(blocks, key=len).strip() + "\n"
    return text.strip() + "\n"


def main() -> int:
    key = api_key()
    if not key:
        print("no OPENROUTER_API_KEY", file=sys.stderr)
        return 2

    feedback = ""
    if len(sys.argv) == 3 and sys.argv[1] == "--feedback":
        feedback = open(sys.argv[2]).read()

    current = open(WT_CAND).read()
    user = OBJECTIVE + "\n" + PAPER + "\nCurrent scan.c:\n```c\n" + current + "```\n"
    if feedback:
        user += "\nResult of your previous attempt (use this to fix/improve):\n" + feedback + "\n"

    body = json.dumps({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": "You are an expert C performance engineer. You write correct, fast, portable code and follow the output format exactly."},
            {"role": "user", "content": user},
        ],
        "temperature": 0.3,
    }).encode()

    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions", data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        resp = json.load(r)

    msg = resp["choices"][0]["message"]["content"]
    print("===== MODEL RESPONSE =====")
    print(msg)
    print("===== USAGE =====", resp.get("usage", {}))

    code = extract_code(msg)
    open(WT_CAND, "w").write(code)
    print(f"\n===== wrote {len(code)} bytes to {WT_CAND} =====")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
