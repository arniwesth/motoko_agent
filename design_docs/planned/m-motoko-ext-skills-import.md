# M-MOTOKO-EXT-SKILLS-IMPORT

## Summary

An extension that imports and exposes Claude Code skills as motoko tools, allowing agents to leverage existing skill libraries without reimplementing them. Skills are converted from Claude Code format to motoko tool definitions at runtime.

## Motivation

### The Problem

Claude Code has a rich ecosystem of **skills** - reusable prompt templates and tool compositions:

- **code-review** - Analyze and review code changes
- **test-gen** - Generate tests for code
- **refactor** - Safe refactoring workflows
- **explain** - Explain code with diagrams
- **security-audit** - Security vulnerability scanning

These skills are valuable, but:
1. They're in Claude Code's format (`.claude/skills/`)
2. They reference Claude Code's tool interface
3. They can't be used directly in motoko

### The Opportunity

Instead of reimplementing each skill:
1. **Import** existing Claude Code skills
2. **Adapt** them to motoko's tool interface
3. **Expose** them as motoko tools
4. **Compose** them with motoko's extensions

This enables:
- Immediate access to proven workflows
- Reduced duplication of effort
- Cross-pollination between Claude Code and motoko ecosystems
- Easy migration path for Claude Code users

## Claude Code Skills Format

### Directory Structure

```
.claude/
├── skills/
│   ├── code-review/
│   │   ├── skill.md        # Skill definition
│   │   ├── prompts/
│   │   │   ├── review.md
│   │   │   └── suggest.md
│   │   └── tools.json      # Tool dependencies
│   ├── test-gen/
│   │   └── skill.md
│   └── refactor/
│       └── skill.md
└── commands/
    └── ...
```

### Skill Definition

```markdown
# .claude/skills/code-review/skill.md

---
name: code-review
description: Review code changes and provide feedback
tools:
  - ReadFile
  - Search
  - BashExec
inputs:
  - name: target
    type: string
    description: File or directory to review
    required: true
  - name: focus
    type: string
    description: Focus area (security, performance, style)
    required: false
outputs:
  - summary: string
  - issues: array
  - suggestions: array
---

You are a code reviewer. Analyze the target code and provide:
1. A summary of the code's purpose
2. Issues found (bugs, security, style)
3. Suggestions for improvement

Focus on: {{focus}} (if specified)

Target: {{target}}
```

### Tool Dependencies

```json
// .claude/skills/code-review/tools.json
{
  "required": ["ReadFile", "Search", "BashExec"],
  "optional": ["OmnigraphRead", "ExaSearch"]
}
```

## Proposed Design

### Extension: `motoko-ext-skills-import`

**Package:** `sunholo/motoko_ext_skills_import@0.1.0`

**Hook Point:** `on_describe_tools` exposes imported skills as tools

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Skills Directory                                        │
│ .claude/skills/                                         │
│ ├── code-review/skill.md                                │
│ ├── test-gen/skill.md                                   │
│ └── refactor/skill.md                                   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Skills Import Extension                                 │
│                                                         │
│ 1. Scan .claude/skills/ directory                      │
│ 2. Parse skill.md files                                 │
│ 3. Convert to ToolSchema format                         │
│ 4. Register as motoko tools                             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Tool Catalog (exposed to agent)                         │
│                                                         │
│ - code_review(target, focus) -> summary, issues        │
│ - test_gen(target, framework) -> tests                 │
│ - refactor(target, transformation) -> result           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ When Tool Called                                        │
│                                                         │
│ 1. Load skill prompt template                          │
│ 2. Inject parameters (target, focus, etc.)             │
│ 3. Execute skill as sub-agent conversation             │
│ 4. Return structured result                            │
└─────────────────────────────────────────────────────────┘
```

### Implementation

```ailang
-- packages/motoko-ext-skills-import/register.ail

module sunholo/motoko_ext_skills_import/register

import pkg/sunholo/motoko_ext_abi/types (
  ExtensionHooks, ExtCtx, ToolSchema, ToolCallEnvelope, ToolResultEnvelope,
  ToolHandleDecision, Handled, Delegate
)
import pkg/sunholo/motoko_ext_skills_import/loader (load_skills, Skill)
import pkg/sunholo/motoko_ext_skills_import/executor (execute_skill)
import std/string (format)
import std/json (Json)

export func register_with_config(_cfg: a) -> ExtensionHooks ! {Env, FS} {
  -- Load skills at registration time
  let skills = load_skills(".claude/skills/");
  
  {
    id: "skills_import",
    provided_tools: map skill_to_name(skills),  -- ["code_review", "test_gen", ...]
    on_describe_tools: func() -> [ToolSchema] {
      -- Convert each skill to ToolSchema
      map skill_to_schema(skills)
    },
    on_build_system_prompt: \_ . { prepend: [], append: [] },
    on_budget_plan: \_ _ . { requested_total: None, requested_solver: None, requested_verifier: None } ! {Env, FS},
    on_pre_step: \_ _ . PassThrough ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
    on_tool_policy: \_ _ . Allow,
    on_tool_handle: func(ctx: ExtCtx, call: ToolCallEnvelope) -> ToolHandleDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream} {
      -- Check if this is a skill tool
      match find_skill(skills, call.tool) {
        None => Delegate,  -- Not a skill, pass to default handler
        Some(skill) => {
          -- Execute the skill
          let result = execute_skill(ctx, skill, call.arguments);
          
          -- Return result
          Handled({
            tool_call_id: call.id,
            tool: call.tool,
            exit_code: 0,
            stdout: result.summary,
            stderr: "",
            metadata: {
              "issues": result.issues,
              "suggestions": result.suggestions
            }
          })
        }
      }
    },
    on_response_intercept: \_ _ . NoIntercept ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
    on_solver_candidate: \_ _ . NoDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
  }
}

func skill_to_schema(skill: Skill) -> ToolSchema {
  {
    name: skill.name,
    description: skill.description,
    parameters: encode_skill_params(skill.inputs)
  }
}

func encode_skill_params(inputs: [SkillInput]) -> string {
  -- Convert skill inputs to JSON schema
  let schema = {
    "type": "object",
    "properties": map input_to_property(inputs),
    "required": filter_required(inputs)
  };
  encode(schema)
}

func input_to_property(input: SkillInput) -> Json {
  {
    "type": input.type,
    "description": input.description
  }
}
```

### Skill Loader

```ailang
-- packages/motoko-ext-skills-import/loader.ail

module sunholo/motoko_ext_skills_import/loader

import std/fs (readDir, readFile)
import std/string (split, trim, contains)
import std/json (decode, getString)
import std/option (Option, Some, None)

export type Skill = {
  name: string,
  description: string,
  tools: [string],
  inputs: [SkillInput],
  outputs: [SkillOutput],
  prompt_template: string
}

export type SkillInput = {
  name: string,
  type: string,
  description: string,
  required: bool
}

export type SkillOutput = {
  name: string,
  type: string
}

export func load_skills(skills_dir: string) -> [Skill] ! {Env, FS} {
  -- Scan skills directory
  let entries = readDir(skills_dir);
  let skills = [];
  
  for entry in entries {
    if entry.is_dir then {
      let skill_path = "${skills_dir}/${entry.name}/skill.md";
      match load_skill(skill_path) {
        None => (),
        Some(skill) => skills = skills ++ [skill]
      }
    }
  };
  
  skills
}

func load_skill(path: string) -> Option[Skill] ! {Env, FS} {
  -- Read skill.md file
  let content = readFile(path);
  
  -- Parse frontmatter (YAML between ---)
  let frontmatter = parse_frontmatter(content);
  
  -- Extract prompt template (after frontmatter)
  let prompt_template = extract_prompt(content);
  
  -- Build skill record
  Some({
    name: frontmatter.name,
    description: frontmatter.description,
    tools: frontmatter.tools,
    inputs: parse_inputs(frontmatter.inputs),
    outputs: parse_outputs(frontmatter.outputs),
    prompt_template: prompt_template
  })
}

func parse_frontmatter(content: string) -> Json {
  -- Extract content between --- markers
  -- Parse as YAML (simplified - could use yaml library)
  -- ...
}

func extract_prompt(content: string) -> string {
  -- Get content after the closing ---
  let parts = split("---", content);
  if length(parts) >= 3 then parts[2]
  else ""
}
```

### Skill Executor

```ailang
-- packages/motoko-ext-skills-import/executor.ail

module sunholo/motoko_ext_skills_import/executor

import pkg/sunholo/motoko_ext_abi/types (ExtCtx)
import std/ai (step, Message)
import std/string (replace, format)
import std/json (Json, decode, encode)

export type SkillResult = {
  summary: string,
  issues: [Json],
  suggestions: [Json]
}

export func execute_skill(ctx: ExtCtx, skill: Skill, args: Json) -> SkillResult ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream} {
  -- 1. Inject parameters into prompt template
  let prompt = inject_params(skill.prompt_template, args);
  
  -- 2. Build messages for skill execution
  let messages: [Message] = [
    { role: "user", content: prompt, tool_calls: [], tool_call_id: "" }
  ];
  
  -- 3. Execute as sub-agent (may call tools)
  let result = step(ctx.model, messages, []);
  
  -- 4. Parse result into structured output
  parse_skill_result(result.message.content, skill.outputs)
}

func inject_params(template: string, args: Json) -> string {
  -- Replace {{param}} with actual values
  let prompt = template;
  
  -- For each parameter, replace placeholder
  let params = get_keys(args);
  for param in params {
    let value = getString(args, param);
    let placeholder = "{{${param}}}";
    prompt = replace(prompt, placeholder, value);
  };
  
  prompt
}

func parse_skill_result(content: string, outputs: [SkillOutput]) -> SkillResult {
  -- Parse the skill output
  -- Skills typically return structured text that we need to parse
  -- Could use JSON mode if the skill supports it
  
  -- For now, extract summary and structured issues
  {
    summary: extract_summary(content),
    issues: extract_issues(content),
    suggestions: extract_suggestions(content)
  }
}
```

### Tool Mapping

Claude Code tools → motoko tools:

| Claude Code | motoko | Notes |
|-------------|--------|-------|
| `ReadFile` | `ReadFile` | Direct mapping |
| `WriteFile` | `WriteFile` | Direct mapping |
| `EditFile` | `EditFile` | Direct mapping |
| `Search` | `Search` | Direct mapping |
| `BashExec` | `BashExec` | Direct mapping |
| `Ask` | (user input) | Requires conversation continuation |
| `Task` | (sub-agent) | Requires agent spawning |

Skills that require `Ask` or `Task` may need adaptation.

### Configuration

```json
// .motoko/config/<profile>/skills_import.json
{
  "enabled": true,
  "skills_dirs": [
    ".claude/skills",
    "~/.claude/skills",           // Global skills
    "~/projects/shared-skills"    // Shared team skills
  ],
  "skill_mappings": {
    // Override tool names in skills
    "code-review": {
      "tools": {
        "Ask": "user_prompt"  // Map Ask to a different behavior
      }
    }
  },
  "exclude_skills": [
    "experimental-*"  // Glob patterns to exclude
  ],
  "execution_mode": "subagent"  // subagent | inline
}
```

## Example Usage

### Skill: code-review

```markdown
# .claude/skills/code-review/skill.md

---
name: code-review
description: Review code and provide actionable feedback
tools: [ReadFile, Search, BashExec]
inputs:
  - name: target
    type: string
    description: File or directory to review
    required: true
  - name: focus
    type: string
    description: Focus area (security, performance, style, all)
    required: false
    default: all
outputs:
  - name: summary
    type: string
  - name: issues
    type: array
  - name: suggestions
    type: array
---

You are an expert code reviewer. Analyze {{target}} with focus on {{focus}}.

For each file:
1. Read the file
2. Identify issues (bugs, security, style, performance)
3. Suggest improvements

Return a structured report with:
- Summary of findings
- List of issues (file:line, severity, description)
- Actionable suggestions
```

### Agent Using Skill

```
User: Review the authentication code in src/auth/

Agent: I'll use the code-review skill to analyze the authentication code.

Tool: code_review(target="src/auth/", focus="security")

Result:
  Summary: Found 3 security issues in authentication module
  
  Issues:
  - src/auth/login.ts:45 - HIGH: Password comparison uses timing attack vulnerable method
  - src/auth/session.ts:102 - MEDIUM: Session token has insufficient entropy
  - src/auth/middleware.ts:23 - LOW: Missing rate limiting on login endpoint
  
  Suggestions:
  1. Use crypto.timingSafeEqual for password comparison
  2. Generate session tokens with 256+ bits of entropy
  3. Add rate limiting middleware to /login endpoint

Agent: I've reviewed the authentication code and found 3 security issues...
```

## Skill Adaptation Patterns

### 1. Direct Tool Mapping

Skills that use standard tools (ReadFile, WriteFile, Search, BashExec) work without modification.

### 2. Ask → User Prompt

Claude Code's `Ask` tool pauses for user input. In motoko:
- Return a "need user input" marker
- TUI prompts user
- Input provided on next turn

```ailang
-- Skill calls Ask("Should I proceed?")
-- Extension intercepts and returns:
Handled({
  ...
  stdout: "Skill requires user input: Should I proceed?",
  metadata: { "need_input": true, "prompt": "Should I proceed?" }
})
```

### 3. Task → Sub-agent

Claude Code's `Task` spawns a sub-agent. In motoko:
- Use `step()` with isolated messages
- Sub-agent has access to same tools
- Result merged back

```ailang
-- Skill calls Task("Write tests for foo.ts")
-- Extension spawns sub-agent:
let sub_messages = [{ role: "user", content: "Write tests for foo.ts", ... }];
let sub_result = step(ctx.model, sub_messages, []);
-- Merge sub_result into skill result
```

### 4. Missing Tools

If a skill requires a tool not available in motoko:
- Log warning at skill load time
- Return error when skill is called
- Suggest alternative tools

```json
{
  "warning": "Skill 'deploy' requires tool 'Deploy' which is not available",
  "available_alternatives": ["BashExec"]
}
```

## Benefits

1. **Immediate Access**: Hundreds of existing skills available
2. **Community Driven**: Benefit from Claude Code community innovations
3. **Migration Path**: Easy transition for Claude Code users
4. **Composition**: Combine skills with motoko extensions
5. **Customization**: Override skill behavior via configuration

## Implementation Phases

### Phase 1: Basic Import (M1)
- Load skills from `.claude/skills/`
- Parse frontmatter and prompt template
- Expose as tools via `on_describe_tools`
- Execute with parameter injection

**Estimated effort:** 2 days

### Phase 2: Tool Mapping (M2)
- Implement tool name mappings
- Handle Ask → user input flow
- Handle Task → sub-agent spawning
- Error handling for missing tools

**Estimated effort:** 1 day

### Phase 3: Advanced Features (M3)
- Multiple skills directories
- Skill inheritance/composition
- Caching of skill definitions
- Skill versioning

**Estimated effort:** 1 day

## Testing

```
Test Case 1: Simple skill with direct tools
1. Create skill that uses ReadFile
2. Load skill via extension
3. Call skill from agent
4. Verify skill executes correctly

Test Case 2: Skill with Ask tool
1. Create skill that uses Ask
2. Call skill from agent
3. Verify TUI prompts for input
4. Verify input flows back to skill

Test Case 3: Skill with Task tool
1. Create skill that spawns sub-agent
2. Call skill from agent
3. Verify sub-agent executes
4. Verify result merged correctly

Test Case 4: Missing tool handling
1. Create skill requiring unavailable tool
2. Load skill (should log warning)
3. Call skill
4. Verify helpful error message
```

## Future Enhancements

1. **Skill Marketplace**: Browse and install community skills
2. **Skill IDE**: Create/edit skills visually
3. **Skill Testing**: Unit test framework for skills
4. **Skill Metrics**: Track skill usage and effectiveness
5. **Cross-Platform**: Export motoko skills to Claude Code format

## Related

- Claude Code skills documentation
- motoko-ext-auto-linter (similar tool interception pattern)
- AILANG `step()` function for sub-agent execution
