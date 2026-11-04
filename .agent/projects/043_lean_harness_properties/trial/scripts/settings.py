# One arm session's --settings (PLAN-001 A1 item 4): deny reads outside its own tree and
# output, and deny git, herdr (another pane's screen) and the web (the public upstream code).   python3 -I settings.py <session> <root> <all sessions...>
import json, sys
me, root, everyone = sys.argv[1], sys.argv[2], sys.argv[3:]
deny = [f"Read(/{p}/**)" for p in [
    "/workspaces", "/tmp/claude-1001", "/home/motoko/.claude", "/home/motoko/.codex",
    f"{root}/planter", f"{root}/sealed", f"{root}/collect", f"{root}/dryrun-ref",
] + [f"{root}/s/{s}" for s in everyone if s != me]]
deny += ["Bash(git:*)", "Bash(herdr:*)", "WebFetch", "WebSearch",
         "Bash(curl:*)", "Bash(wget:*)", "Bash(gh:*)"]
print(json.dumps({"permissions": {"deny": deny}}, indent=1))
