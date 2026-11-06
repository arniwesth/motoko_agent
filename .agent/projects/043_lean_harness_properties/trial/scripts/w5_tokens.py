#!/usr/bin/env python3
"""W5: token counts and times from the trial's Claude Code transcripts (PLAN-001 §9).

    w5_tokens.py <out.tsv> <name>=<transcript.jsonl>[@<cut UTC>] ...

For each transcript:
  - Assistant messages are counted once each, by message id: a transcript can write one
    message on several lines (one per content block), each carrying the same usage. If two
    lines of one id carry different usage, the last line's usage is used and the id is counted
    in `ids_usage_differs`.
  - The four usage fields Claude Code records are summed separately: input_tokens (uncached
    input), cache_creation_input_tokens, cache_read_input_tokens, output_tokens.
    tokens_total = all three input fields + output: every token the model read or wrote.
  - Claude Code's own running totals, the last `cost-state` record (what `/cost` reports), are
    given beside them for every model it lists, with its totalCostUSD.
  - Times: the first record's timestamp, the first tool_use, the last assistant message, the
    last record; and the number of compaction boundaries.
  - An optional @cut (UTC, ISO 8601) counts only messages up to that time (used to split the
    adjudicator's W4 work from what it did after W4 ended).
Reads only; writes <out.tsv>.
"""
import json, sys, datetime

def ts(s):
    return datetime.datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None

def one(name, path, cut):
    by_id, order, differs = {}, [], set()
    first = last = first_tool = last_asst = None
    compactions = 0
    cost = None
    models = {}
    for line in open(path, encoding="utf-8"):
        r = json.loads(line)
        t = ts(r.get("timestamp"))
        if r.get("type") == "cost-state":
            cost = r
            continue
        if t is None:
            continue
        if cut and t > cut:
            continue
        first = first or t
        last = t
        if r.get("type") == "system" and r.get("subtype") == "compact_boundary":
            compactions += 1
        if r.get("type") != "assistant":
            continue
        m = r["message"]
        mid = m.get("id")
        u = m.get("usage") or {}
        if mid in by_id and json.dumps(by_id[mid][0], sort_keys=True) != json.dumps(u, sort_keys=True):
            differs.add(mid)
        if mid not in by_id:
            order.append(mid)
        by_id[mid] = (u, m.get("model"))
        last_asst = t
        if first_tool is None and any(c.get("type") == "tool_use" for c in m.get("content") or []):
            first_tool = t
    sums = {k: 0 for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")}
    for mid in order:
        u, model = by_id[mid]
        models[model] = models.get(model, 0) + 1
        for k in sums:
            sums[k] += int(u.get(k) or 0)
    total = sum(sums.values())
    row = {
        "name": name, "transcript": path.rsplit("/", 1)[-1], "cut": cut.strftime("%Y-%m-%dT%H:%M:%SZ") if cut else "",
        "messages": len(order), "ids_usage_differs": len(differs),
        "models": ",".join(f"{k}:{v}" for k, v in sorted(models.items(), key=lambda kv: str(kv[0]))),
        **sums, "tokens_total": total,
        "first": first, "first_tool_use": first_tool, "last_assistant": last_asst, "last": last,
        "compactions": compactions,
    }
    if cost and not cut:
        mu = cost.get("modelUsage") or {}
        for model, v in sorted(mu.items()):
            tag = "opus" if "opus" in model else ("haiku" if "haiku" in model else model)
            row[f"cs_{tag}_input"] = v.get("inputTokens", 0)
            row[f"cs_{tag}_cache_creation"] = v.get("cacheCreationInputTokens", 0)
            row[f"cs_{tag}_cache_read"] = v.get("cacheReadInputTokens", 0)
            row[f"cs_{tag}_output"] = v.get("outputTokens", 0)
        row["cs_cost_usd"] = round(cost.get("totalCostUSD", 0), 4)
        row["cs_total_duration_s"] = round((cost.get("totalDuration") or 0) / 1000)
    return row

def main():
    out = sys.argv[1]
    rows = []
    for arg in sys.argv[2:]:
        name, rest = arg.split("=", 1)
        path, _, cut = rest.partition("@")
        rows.append(one(name, path, ts(cut) if cut else None))
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    fmt = lambda v: v.strftime("%Y-%m-%dT%H:%M:%SZ") if isinstance(v, datetime.datetime) else ("" if v is None else str(v))
    with open(out, "w") as f:
        f.write("\t".join(keys) + "\n")
        for r in rows:
            f.write("\t".join(fmt(r.get(k)) for k in keys) + "\n")

main()
