# Render an arm brief (PLAN-001 Appendix A or B) verbatim, with its bracketed fields filled.
#   python3 -I brief.py <plan> <A|B> <T0..T6> <copy> <out> <minutes>
import re, sys
plan_path, arm, target, copy, out, minutes = sys.argv[1:7]
plan = open(plan_path, encoding="utf-8").read()

def section(title):
    m = re.search(r"^## " + re.escape(title) + r".*?$\n(.*?)(?=^## |\Z)", plan, re.S | re.M)
    if not m: sys.exit(f"brief: no section {title!r}")
    return m.group(1)

app = section("Appendix A." if arm == "A" else "Appendix B.")
text = "\n".join(l[2:] if l.startswith("> ") else l[1:] if l.startswith(">") else None
                 for l in app.splitlines() if l.startswith(">"))
appendix_d = section("Appendix D.").split("\n---")[0].strip()

if target == "T0":   # the dry run's target, as amendment A1 item 1 registers it
    block = ("**T0. The worked example** (dry run only). `pair_step` and `finish_fold` "
             "(`src/core/journal.ail:1634`, `:1715`) against `updatePending` "
             "(`src/tui/src/session-journal.ts:865`).\n"
             "- **P0.1**: for every history the fold accepts in which no call id is empty and no "
             "tool message carries calls, `exit.pending_tool_calls` equals `SessionState.dangling`.")
else:
    s3 = section("3. Targets and registered properties")
    m = re.search(r"^\*\*" + re.escape(target) + r"\..*?(?=^\*\*T\d\.|\Z)", s3, re.S | re.M)
    if not m: sys.exit(f"brief: no {target} in §3")
    block = m.group(0).strip()

text, n1 = re.subn(r"Target: `\[Tn[^\]]*\]`\. Properties: `\[[^\]]*\]`\.",
                   lambda _: "Your target and its registered properties:\n\n" + block, text, flags=re.S)
text, n2 = re.subn(r"`\[Appendix D, verbatim\]`", lambda _: "\n\n" + appendix_d, text)
text = text.replace("`[copy]`", f"`{copy}`").replace("`[out]`", f"`{out}`")
text, n3 = re.subn(r"You have 2 hours", f"You have {int(minutes) // 60} hours" if int(minutes) % 60 == 0
                   else f"You have {minutes} minutes", text)
if (n1, n2, n3) != (1, 1, 1) or "[copy]" in text or "[out]" in text:
    sys.exit(f"brief: fields not all filled {(n1, n2, n3)}")
print(text.strip())
