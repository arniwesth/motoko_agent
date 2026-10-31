# Per-call process timeouts — diagram

A diagram for project 041, drawn from `../ADR-002-per-call-process-timeouts.md`. It is a Mermaid
`.mmd` source with its rendered `.svg` alongside, following the convention in
`../../004_phase_core_refactor/mmd/README.md`.

| File | What it shows |
|------|---------------|
| `adr-002-per-call-process-timeouts` | **One tool call under the design, as a mechanism map.** Where its limits come from and the `Limits` or `Legacy` mode, who is calling, the resolver ahead of the world split, enforcement in each world, and what the model reads. The D6 defect and its fix hang off the two `exec` paths, and what the ADR leaves out hangs off the mode. |

Colour is **role**, and the `%%` header states the legend. Blue holds at HEAD; amber is a decision
point; green is new design; purple is new design that waits on an upstream pin; teal is what the
model reads; red is the D6 defect; amber-dashed is its upstream fix; gray-dashed is out of scope.

This diagram is **dated evidence**. The ADR is **Proposed**, and nothing in the green or purple nodes
exists at HEAD. It draws the eighth revision with rulings R1-R11, against `origin/main` `a393314b`.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts <name>.mmd <name>.svg --theme tokyo-night
```
