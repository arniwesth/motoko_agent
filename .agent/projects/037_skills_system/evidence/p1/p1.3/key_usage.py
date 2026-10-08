#!/usr/bin/env python3
"""037 P1.3: the OpenRouter key's own usage counter, for reconciling spend.tsv
(list price) against what the account was actually charged. Prints numbers only:
no key, no label. Appends to key_usage.tsv.

  key_usage.py <note>
"""
import json, os, sys, time, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
req = urllib.request.Request("https://openrouter.ai/api/v1/key",
                             headers={"Authorization": "Bearer " + os.environ["OPENROUTER_API_KEY"]})
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r).get("data", {})
except Exception as e:
    print("key usage unavailable: %s" % type(e).__name__)
    sys.exit(1)
usage = d.get("usage")
row = "%s\t%s\t%s\t%s\t%s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), usage, d.get("limit"),
                              d.get("limit_remaining"), sys.argv[1] if len(sys.argv) > 1 else "")
p = os.path.join(HERE, "key_usage.tsv")
new = not os.path.exists(p)
with open(p, "a") as f:
    if new:
        f.write("utc\tkey_usage_usd\tlimit\tlimit_remaining\tnote\n")
    f.write(row)
print(row.strip())
