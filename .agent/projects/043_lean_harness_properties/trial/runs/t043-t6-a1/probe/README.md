# probe/ — the first exploratory runs (21:57–21:58), superseded by ../harness/

- `p1.ail`: imports `truncate_utf8_by_bytes` from the real compose package. It fails with
  `undefined variable: truncate_utf8_by_bytes`: the function is not exported, which is why
  ../harness/direct/ builds a one-word export shim.
- `drv/p.ail` over `shimpkg/` (a hand-made copy of store.ail with `export` added to that one
  function, made the same way run_direct.sh now does it at run time): fifteen hand-picked
  inputs. Its output was the first sight of A1-T6-1 by execution: `éé`, max 2 -> 4 bytes;
  `€`, max 1 -> 3 bytes.

Run from the tree root: `ailang run --relax-modules --caps IO --entry main <out>/probe/drv/p.ail`.
