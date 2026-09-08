from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass

from . import config
from .slugs import symbol_slug


@dataclass
class Verdict:
    status: str
    detail: str
    data: dict | None = None
    error: str = ""


def classify(stdout: str, source_func_count: int) -> Verdict:
    start = stdout.find("{")
    if start < 0:
        return Verdict("failed", "no_json", None)
    try:
        data = json.loads(stdout[start:])
    except json.JSONDecodeError:
        return Verdict("failed", "invalid_json", None, "invalid JSON in iface stdout")
    has_funcs = "funcs" in data
    has_types = "types" in data
    funcs = data.get("funcs") or []
    if (not has_funcs or not funcs) and source_func_count >= 1:
        return Verdict("partial", "empty_funcs", data)
    if has_funcs and has_types:
        return Verdict("ok", "warning_prefixed" if start > 0 else "ok", data)
    return Verdict("failed", "missing_keys", data, "iface JSON missing funcs/types keys")


def ailang_version() -> str:
    try:
        return subprocess.run(["ailang", "--version"], capture_output=True, text=True, check=False).stdout.strip()
    except FileNotFoundError:
        return "ailang not found"


def run_iface(module: str) -> tuple[str, str]:
    result = subprocess.run(["ailang", "iface", module], capture_output=True, text=True, check=False,
                            cwd=config.REPO_ROOT)
    return result.stdout, result.stderr


def first_error_line(stdout: str, stderr: str) -> str:
    for text in (stderr, stdout):
        for line in text.splitlines():
            line = line.strip()
            if line:
                return line[:500]
    return ""


def type_refs(type_sig: str) -> set[str]:
    cleaned = re.sub(r"!\s*\{[^}]*\}", "", type_sig)
    return {x for x in re.findall(r"\b[A-Z][A-Za-z0-9_]*\b", cleaned)}


def apply_iface(parsed_modules: list) -> tuple[list[dict], list[dict], list[dict], list[dict], list[dict], list[dict]]:
    funcs_by_slug: dict[str, dict] = {f["slug"]: dict(f) for p in parsed_modules for f in p.funcs}
    types: list[dict] = []
    ctors: list[dict] = []
    uses: list[dict] = []
    effects: list[dict] = []
    status_rows: list[dict] = []
    verdicts: dict[str, Verdict] = {}
    for p in parsed_modules:
        stdout, stderr = run_iface(p.slug)
        verdict = classify(stdout, len(p.funcs))
        if verdict.status == "failed" and not verdict.error:
            verdict.error = first_error_line(stdout, stderr)
        verdicts[p.slug] = verdict
        status_rows.append({"module": p.slug, "iface_status": verdict.status, "iface_detail": verdict.detail,
                            "iface_error": verdict.error})
        for f in p.funcs:
            funcs_by_slug[f["slug"]]["module_iface_status"] = verdict.status
        data = verdict.data if verdict.status in {"ok", "partial"} else None
        if not data:
            continue
        for t in data.get("types") or []:
            name = t.get("name", "")
            if not name:
                continue
            tslug = symbol_slug(p.slug, name)
            ctor_list = t.get("ctors") or []
            types.append({"slug": tslug, "module": p.slug, "name": name,
                          "kind": "adt" if ctor_list else "", "n_ctors": len(ctor_list)})
            for raw in ctor_list:
                cname = raw.split("(", 1)[0].strip()
                if cname:
                    ctors.append({"slug": symbol_slug(p.slug, cname), "module": p.slug, "name": cname,
                                  "type_slug": tslug, "source": "iface"})
        known_types = {row["name"]: row["slug"] for row in types if row["module"] == p.slug}
        for fn in data.get("funcs") or []:
            name = fn.get("name", "")
            fslug = symbol_slug(p.slug, name)
            row = funcs_by_slug.get(fslug)
            if not row:
                continue
            effs = fn.get("effects") or []
            row.update({"has_typed_sig": 1, "type_sig": fn.get("type", ""),
                        "declared_effects": "|".join(effs),
                        "pure": "1" if fn.get("pure") is True else "0" if fn.get("pure") is False else "",
                        "module_iface_status": verdict.status})
            for eff in effs:
                effects.append({"func_slug": fslug, "effect": eff})
            for tref in type_refs(fn.get("type", "")):
                tslug = known_types.get(tref, f"?#{tref}")
                uses.append({"from_slug": fslug, "type_slug": tslug, "resolved": int(not tslug.startswith("?"))})
    return list(funcs_by_slug.values()), types, ctors, uses, effects, status_rows
