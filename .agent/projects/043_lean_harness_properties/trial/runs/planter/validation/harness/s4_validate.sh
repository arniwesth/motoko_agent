#!/usr/bin/env bash
# S4 end-to-end scenarios: the TUI's gate on its own environment, buildChildEnv's output, and the
# runtime's herdr extension registered under exactly that child environment
# (scripts/verify_herdr_gate.ail, which runs register_with_config through the core registry).
set -uo pipefail
P=/home/motoko/trial-043/planter; W=$P/work; H=$W/harness
run() { # <tree> <scenario>
  local tree="$1" sc="$2" out vars=()
  out=$(cd "$tree" && bun $H/s4_child_env.ts "$tree" "$sc" 2>&1)
  echo "$out" | sed 's/^/    /'
  while IFS= read -r l; do k=${l#CHILD }; vars+=("${k%%=*}=$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1]))' "${k#*=}")"); done < <(echo "$out" | grep '^CHILD ')
  local reg; reg=$(cd "$tree" && env -i PATH="$PATH" HOME="$HOME" "${vars[@]}" ailang run --caps Net,AI,SharedMem,IO,Env,Clock,FS,Process,Stream --ai-stub --entry main scripts/verify_herdr_gate.ail 2>/dev/null | grep observed)
  echo "    RUNTIME ${reg# }"
  local tg; tg=$(echo "$out" | grep TUI_GATE | awk '{print $2}'); local n; n=$(echo "$reg" | sed -E 's/.*observed ([0-9]+) tool.*/\1/')
  local rg; [ "$n" = "0" ] && rg=closed || rg=ready
  echo "    => TUI gate $tg, runtime gate $rg: P1.1 end to end $([ "$tg" = "$rg" ] && echo holds || echo VIOLATED)"
}
for s in s03 s04; do
  mkdir -p $P/validation/$s
  { echo "# $s: end-to-end scenario for P1.1 (S4). The TUI process runs with the environment below; the"
    echo "# runtime child is given exactly the HERDR_* variables buildChildEnv returns (plus PATH and HOME)."
    for t in base trees/only-$s trees/T trees/minus-$s; do
      tree=$W/$t; [ "$t" = base ] && name=B0 || name=$(basename $t)
      echo "== $name, scenario $s"; run $tree $s
      echo "== $name, control (all three set)"; run $tree control
    done; } > $P/validation/$s/scenario.log 2>&1
done
grep -h "=>\|^==" $P/validation/s03/scenario.log $P/validation/s04/scenario.log
