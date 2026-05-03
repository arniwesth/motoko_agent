# Omnigraph Knowledge Graph Contract

## Schema

### Node: Decision
- `slug: String` (immutable key)
- `title: String`
- `rationale: String`
- `status: proposed | accepted | superseded | deprecated`
- `date: String`

### Node: Component
- `slug: String` (immutable key)
- `name: String`
- `description: String`
- `layer: domain | infrastructure | api | frontend`

### Edges
- `DependsOn`: `Component -> Component`
- `Governs`: `Decision -> Component`

## Read Query Catalog

### list_decisions
- File: `queries/decisions.gq`
- Params: none
- Purpose: list all decisions.

### decisions_by_status
- File: `queries/decisions.gq`
- Params: `$status: String`
- Purpose: filter decisions by status enum value.

### decisions_governing
- File: `queries/decisions.gq`
- Params: `$component_slug: String`
- Purpose: find decisions that govern a component.

### list_components
- File: `queries/components.gq`
- Params: none
- Purpose: list all components.

### component_dependencies
- File: `queries/components.gq`
- Params: `$slug: String`
- Purpose: list one-hop component dependencies.

## Mutation Catalog

### insert_decision
- File: `mutations/decisions.gq`
- Params: `$slug, $title, $rationale, $status, $date: String`
- Purpose: insert a decision.

### update_decision_status
- File: `mutations/decisions.gq`
- Params: `$slug, $status: String`
- Purpose: update decision status.

### insert_component
- File: `mutations/components.gq`
- Params: `$slug, $name, $description, $layer: String`
- Purpose: insert a component.

### insert_dependency
- File: `mutations/components.gq`
- Params: `$from_slug, $to_slug: String`
- Purpose: insert a DependsOn edge.

### insert_governs
- File: `mutations/components.gq`
- Params: `$decision_slug, $component_slug: String`
- Purpose: insert a Governs edge.

## Deleting graph data

There is no dedicated delete tool. Use `OmnigraphMutate` with the
`delete_*` queries in `mutations/`. The workflow:

1. **Branch.** Direct mutations on `main` are denied. Create a working
   branch first:
   `OmnigraphBranch` with `action: "create"`, `name: "cleanup/<slug>"`.
2. **Delete edges before nodes.** A node with referencing edges may
   fail to delete. For decision cleanup, run `delete_governs`.
   For component cleanup, run `delete_dependency`, `delete_dependency_to`,
   and `delete_governs_to` first, then `delete_component`.
3. **Verify.** `OmnigraphRead list_decisions` (or `list_components`)
   on the working branch; the targets should be gone.
4. **Merge.** `OmnigraphBranch` with `action: "merge"`,
   `name: "cleanup/<slug>"`, `into: "main"`.

Available delete query names (file -> name): `mutations/decisions.gq`
-> `delete_decision`, `delete_all_decisions`; `mutations/components.gq`
-> `delete_component`, `delete_dependency`, `delete_dependency_to`,
`delete_governs`, `delete_governs_to`,
`delete_all_components`, `delete_all_dependencies`,
`delete_all_governs`.

## Usage Rules

1. Never mutate `main` directly. Create a feature branch first.
2. After each mutation, run a read query to verify the change.
3. Pass tool params as JSON strings, never interpolated query text.
4. Prefer branch names like `feature/<topic>` or `decision/<slug>`.
5. Keep `slug` fields stable; do not rename keys in-place.
6. Allowed `Decision.status`: `proposed`, `accepted`, `superseded`, `deprecated`.
7. Allowed `Component.layer`: `domain`, `infrastructure`, `api`, `frontend`.
8. Use `omnigraph_status` before large edits to snapshot current state.
9. Merge to `main` only after branch reads confirm expected output.

## Strict Tool Protocol

Scope: this protocol applies when the task is about the Omnigraph graph/state.
For normal repository tasks (read/edit files, search code, run shell/tests), use standard tools normally.

1. For Omnigraph graph tasks, use these canonical tools: `OmnigraphStatus`, `OmnigraphRead`, `OmnigraphMutate`, `OmnigraphBranch`.
2. For Omnigraph graph tasks, never invent alias tools (for example: `list_branches`, `OmnigraphQuery`, `OmnigraphCreateBranch`).
3. When the user explicitly asks for Omnigraph tool JSON, return only JSON with this envelope:
`{"calls":[ ... ]}`
4. Prefer canonical argument keys:
`query_file`, `name`, `params`, `branch`, `action`, `from`, `into`.
5. Required Omnigraph mutate workflow:
`OmnigraphStatus` -> `OmnigraphBranch(action=create|list)` -> `OmnigraphMutate(branch=feature/...)` -> `OmnigraphRead` verify.

### Canonical Call Shapes

```json
{
  "calls": [
    {
      "id": "s1",
      "tool": "OmnigraphStatus",
      "arguments": {}
    }
  ]
}
```

### Do Not Emit (Negative Examples)

These are invalid for Omnigraph graph operations:

- Unsupported/invented tool names:
  - `{"calls":[{"tool":"list_branches","arguments":{}}]}`
  - `{"calls":[{"tool":"OmnigraphQuery","arguments":{"query":"list_decisions"}}]}`
  - `{"calls":[{"tool":"OmnigraphCreateBranch","arguments":{"branch_name":"feature/x"}}]}`
- Non-canonical branch action payloads when creating a branch:
  - `{"calls":[{"tool":"OmnigraphBranch","arguments":{"branch_name":"feature/x"}}]}`
  - Prefer: `{"calls":[{"tool":"OmnigraphBranch","arguments":{"action":"create","name":"feature/x","from":"main"}}]}`
- Free text mixed with tool JSON when user asked for tool JSON only:
  - `Sure, here is the call ... {"calls":[...]}`
  - `I will now run ...`

```json
{
  "calls": [
    {
      "id": "r1",
      "tool": "OmnigraphRead",
      "arguments": {
        "query_file": "queries/decisions.gq",
        "name": "list_decisions",
        "branch": "main"
      }
    }
  ]
}
```

```json
{
  "calls": [
    {
      "id": "b1",
      "tool": "OmnigraphBranch",
      "arguments": {
        "action": "create",
        "name": "feature/test-decision",
        "from": "main"
      }
    }
  ]
}
```

```json
{
  "calls": [
    {
      "id": "m1",
      "tool": "OmnigraphMutate",
      "arguments": {
        "query_file": "mutations/decisions.gq",
        "name": "insert_decision",
        "params": "{\"slug\":\"test-decision\",\"title\":\"Test\",\"rationale\":\"Test rationale\",\"status\":\"proposed\",\"date\":\"2023-10-27\"}",
        "branch": "feature/test-decision"
      }
    }
  ]
}
```

```json
{
  "calls": [
    {
      "id": "v1",
      "tool": "OmnigraphRead",
      "arguments": {
        "query_file": "queries/decisions.gq",
        "name": "list_decisions",
        "branch": "feature/test-decision"
      }
    }
  ]
}
```
