# P1.7r — `derive.py --json` before/after, both classifiers, at committed HEAD `6d668fdd` (fresh clone, lock regenerated)

## classifier 2 — `tools/ext_call_inventory/derive.py --json` (`make ext_call_inventory`)

| key | before | after |
|---|---|---|
| exit | 1 | 0 |
| `classifier_2_set` | ['env_get'] | ['env_get'] |
| `unrouted_fields` | [] | [] |
| `member_call_sites` | 0 | 0 |
| `non_member_call_sites` | 87 | 91 ({'direct': 80, 'view:AiPorts': 2, 'view:SnippetExecPorts': 2, 'view:RemovePorts': 2, 'view:InterceptPorts': 3, 'view:FsPorts': 2}) |
| `unresolved` | **24** ({'packages/motoko-ext-abi/types.ail': 15, 'packages/motoko-ext-agentcli/agentcli.ail': 1, 'packages/motoko-ext-compose/compose.ail': 8}) | **0** |
| `port_views` | absent | AiPorts (1), FsPorts (6), InterceptPorts (8), RemovePorts (2), SnippetExecPorts (1) |
| `port_view_projections` | absent | 21 ({'packages/motoko-ext-abi/types.ail': 15, 'packages/motoko-ext-compose/compose.ail': 6}) |

## classifier 3 — `tools/ext_ambient_inventory/derive.py --json` (`make ext_ambient_inventory`)

| | before | after |
|---|---|---|
| exit | 1 | 0 |
| verdicts | {'UNRESOLVED': 18} | {'AMBIENT': 14, 'PORT-MEDIATED': 4} |
| PORT-MEDIATED | [] | ['compaction_structural', 'decision_framework', 'empty_stop_guard', 'progress_contract_guard'] |
| cache precondition | 18/18 | 18/18 |

| extension | before | unresolved receivers | calls | after | unresolved receivers | calls | projections |
|---|---|--:|--:|---|--:|--:|--:|
| a2a | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| agentcli | UNRESOLVED | 16 | 2 | AMBIENT | 0 | 3 | 15 |
| ailang_docs | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| compaction_ai | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 1 | 15 |
| compaction_structural | UNRESOLVED | 15 | 0 | PORT-MEDIATED | 0 | 0 | 15 |
| compose | UNRESOLVED | 23 | 34 | AMBIENT | 0 | 36 | 21 |
| context_mode | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| decision_framework | UNRESOLVED | 15 | 0 | PORT-MEDIATED | 0 | 0 | 15 |
| empty_stop_guard | UNRESOLVED | 15 | 0 | PORT-MEDIATED | 0 | 0 | 15 |
| exa_search | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| herdr | UNRESOLVED | 15 | 50 | AMBIENT | 0 | 50 | 15 |
| mcp | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| microrag | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| omnigraph | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| progress_contract_guard | UNRESOLVED | 15 | 0 | PORT-MEDIATED | 0 | 0 | 15 |
| repetition_guard | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| scratchpad | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
| test_dummy | UNRESOLVED | 15 | 0 | AMBIENT | 0 | 0 | 15 |
