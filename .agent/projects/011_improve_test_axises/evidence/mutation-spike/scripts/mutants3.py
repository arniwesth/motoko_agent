#!/usr/bin/env python3
"""SPIKE ONLY — part 3: the tool handoffs. Never merges.

T* drop the world successor a tool execution returned. P* are reach probes at the same three
sites: they change nothing unless the successor really differs from the predecessor (a world
request was made), and then they crash with `panic: division by zero`. A gate that is red on P
reached that handoff with a real advance; a gate that is green on P never did, and its verdict
on the matching T is INCONCLUSIVE, not a survival.
"""
import sys

S = "src/core/session.ail"

def poison(succ, pred):
    return f"(if {succ}.ordinal == {pred}.ordinal then {succ} else {{ {succ} | clock_ms: 1 / ({pred}.ordinal - {pred}.ordinal) }})"

H1 = "c2_trace_wire_events(trace_with_calls, done.emitted), done.world);"
H2 = "c2_trace_wire_events(trace_with_calls, pending.emitted), pending.world);"
H3 = "c2_trace_wire_events(approved.trace, executed.emitted), executed.next_state);"

MUTANTS = [
    dict(id="T1", site="batch finished (session.ail:3692)", old=H1,
         new=H1.replace("done.world);", "st.world_state);"),
         rule="session.ail:3682 — `done.world`, not `st.world_state`: taking it off `st` rewinds the world to before the batch"),
    dict(id="T2", site="batch interrupted by an approval (session.ail:3694)", old=H2,
         new=H2.replace("pending.world);", "st.world_state);"),
         rule="session.ail:3703 — tools already executed in this batch before the approval interrupted it must survive the suspension"),
    dict(id="T3", site="approved call executed (session.ail:3623)", old=H3,
         new=H3.replace("executed.next_state);", "post.world_state);"),
         rule="session.ail:3617 — `after` carries BOTH advanced cursors: the approval queue and the tool queue"),
    dict(id="P1", site="reach probe for T1", old=H1,
         new=H1.replace("done.world);", poison("done.world", "st.world_state") + ");"), rule=""),
    dict(id="P2", site="reach probe for T2", old=H2,
         new=H2.replace("pending.world);", poison("pending.world", "st.world_state") + ");"), rule=""),
    dict(id="P3", site="reach probe for T3", old=H3,
         new=H3.replace("executed.next_state);", poison("executed.next_state", "post.world_state") + ");"), rule=""),
]

def apply(mid):
    m = next((x for x in MUTANTS if x["id"] == mid), None)
    if m is None:
        sys.exit(f"unknown mutant {mid}")
    src = open(S, encoding="utf-8").read()
    if src.count(m["old"]) != 1:
        sys.exit(f"{mid}: old text occurs {src.count(m['old'])} times, expected 1")
    if m["old"] == m["new"]:
        sys.exit(f"{mid}: replacement is a no-op")
    pos = src.index(m["old"])
    open(S, "w", encoding="utf-8").write(src[:pos] + m["new"] + src[pos + len(m["old"]):])
    print(f"{mid} applied at {S}:{src.count(chr(10), 0, pos) + 1}")

if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "apply":
        apply(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "ids":
        print(" ".join(m["id"] for m in MUTANTS))
    else:
        sys.exit("usage: mutants3.py apply <id> | ids")
