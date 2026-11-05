#!/usr/bin/env python3
"""The run grammar over gen.ail's 13 steps: which step sequences a run (or a session of runs)
can emit. Prints one JSON list of step lists, of the lengths given.

  0 A, 5 U2, 7 checkpoint, 10 follow-up, 11 checkpoint-with-first_kept: only with no call open
  1 Ca, 2 Cab, 12 Ce (call with an empty id): only with no call open; opens their ids
  3 Ra, 4 Rb: only while that id is open
  6 hybrid replacement: only right after 0 (the plain assistant it supersedes)
  8 crash resume, 9 profile-switch resume: anywhere (a crash); the resumed history has no open call
"""
import json, sys, itertools
CALLS = {1: ["a"], 2: ["a", "b"], 12: ["a", ""], 6: ["a"]}
def runnable(seq, allow=frozenset(range(13))):
    open_, last = [], None
    for s in seq:
        if s not in allow: return False
        if s in (0, 5, 7, 10, 11, 1, 2, 12) and open_: return False
        if s == 6 and (last != 0 or open_): return False
        if s in (3, 4):
            i = "a" if s == 3 else "b"
            if i not in open_: return False
            open_ = [x for x in open_ if x != i]
        elif s in CALLS: open_ = list(CALLS[s])
        elif s in (8, 9): open_ = []
        last = s
    return True
if __name__ == "__main__":
    lens = [int(x) for x in sys.argv[1].split(",")]
    allow = frozenset(int(x) for x in sys.argv[2].split(",")) if len(sys.argv) > 2 else frozenset(range(13))
    out = [list(s) for n in lens for s in itertools.product(range(13), repeat=n) if runnable(s, allow)]
    print(json.dumps(out))
