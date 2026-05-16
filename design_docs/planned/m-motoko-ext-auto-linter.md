# M-MOTOKO-EXT-AUTO-LINTER

## Summary

An extension that automatically lints, formats, and validates files after WriteFile/EditFile operations, similar to Claude Code's hooks system. Provides immediate feedback on code quality without requiring explicit model intervention.

## Motivation

### Current State

When motoko writes code:
1. Agent calls `WriteFile` or `EditFile`
2. File is written to disk
3. No validation until agent manually runs `make check` or similar
4. If there are errors, agent discovers them on next turn

This is inefficient:
- Errors accumulate across multiple files
- Agent may not think to run checks
- Wasted tokens on invalid code paths

### Desired State

Like Claude Code hooks:
1. Agent writes file
2. **Auto-linter intercepts** the write
3. Linter runs automatically
4. Errors/warnings injected into tool result
5. Agent sees feedback immediately and can fix

This enables:
- Immediate error detection
- Enforced code quality standards
- Reduced token waste on invalid code
- Consistent formatting across the codebase

## Claude Code Hooks Reference

Claude Code supports hooks in `.claude/hooks/`:

```yaml
# .claude/hooks/pre_tool_use.yaml
hooks:
  - match: "WriteFile"
    command: "prettier --check"
    
# .claude/hooks/post_tool_use.yaml  
hooks:
  - match: "WriteFile|EditFile"
    command: |
      if file.endswith('.ts'):
        eslint --fix "$FILE"
      elif file.endswith('.ail'):
        ailang check "$FILE"
```

Hook types:
- `pre_tool_use` - Run before tool execution (can block)
- `post_tool_use` - Run after tool execution (can modify result)
- `stop` - Run when conversation ends
- `notification` - Run on specific events

## Proposed Design

### Extension: `motoko-ext-auto-linter`

**Package:** `sunholo/motoko_ext_auto_linter@0.1.0`

**Hook Point:** `on_tool_handle` intercepts `WriteFile` and `EditFile`

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Agent calls WriteFile("src/foo.ts", content)           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Auto-Linter Extension (on_tool_handle)                  │
│                                                         │
│ 1. Match tool name: WriteFile|EditFile                 │
│ 2. Check file extension: .ts, .ail, .py, etc.          │
│ 3. Look up linter config for extension                 │
│ 4. Run linter command                                   │
│ 5. Inject results into tool response                   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Tool Result to Agent                                    │
│                                                         │
│ "File written to src/foo.ts                             │
│                                                         │
│ [LINTER WARNINGS]                                       │
│ src/foo.ts:10:15 - unused variable 'x'                  │
│ src/foo.ts:15:3 - missing return type                   │
│                                                         │
│ [LINTER FIXED]                                          │
│ Applied prettier formatting                             │
│ Fixed 2 eslint auto-fix issues                          │
│                                                         │
│ Run `eslint src/foo.ts` for full report."              │
└─────────────────────────────────────────────────────────┘
```

### Configuration

```json
// .motoko/config/<profile>/auto_linter.json
{
  "enabled": true,
  "linters": {
    ".ts": {
      "command": "eslint --fix --format compact",
      "timeout_ms": 5000,
      "fix": true,
      "severity": "warn"  // warn | error | block
    },
    ".ail": {
      "command": "ailang check",
      "timeout_ms": 30000,
      "fix": false,
      "severity": "error"
    },
    ".py": {
      "command": "ruff check --fix",
      "timeout_ms": 5000,
      "fix": true,
      "severity": "warn"
    },
    ".go": {
      "command": "gofmt -w",
      "timeout_ms": 5000,
      "fix": true,
      "severity": "warn"
    }
  },
  "block_on_error": [".ail"],  // Extensions that block the write on error
  "ignore_patterns": [
    "**/node_modules/**",
    "**/vendor/**",
    "**/.git/**"
  ]
}
```

### Implementation

```ailang
-- packages/motoko-ext-auto-linter/register.ail

module sunholo/motoko_ext_auto_linter/register

import pkg/sunholo/motoko_ext_abi/types (
  ExtensionHooks, ExtCtx, ToolCallEnvelope, ToolResultEnvelope,
  ToolHandleDecision, Handled, Delegate
)
import pkg/sunholo/motoko_ext_auto_linter/config (read_linter_config)
import pkg/sunholo/motoko_ext_auto_linter/runner (run_linter)
import std/string (endsWith, split)
import std/fs (writeFile, readFile)
import std/json (Json)

export func register_with_config(_cfg: a) -> ExtensionHooks ! {Env, FS, Process} {
  let linter_cfg = read_linter_config();
  
  {
    id: "auto_linter",
    provided_tools: [],
    on_describe_tools: \_ . [],
    on_build_system_prompt: \_ . { prepend: [], append: [] },
    on_budget_plan: \_ _ . { requested_total: None, requested_solver: None, requested_verifier: None } ! {Env, FS},
    on_pre_step: \_ _ . PassThrough ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
    on_tool_policy: \_ _ . Allow,
    on_tool_handle: func(ctx: ExtCtx, call: ToolCallEnvelope) -> ToolHandleDecision ! {IO, Process, FS, Env} {
      -- Only intercept WriteFile and EditFile
      if call.tool != "WriteFile" && call.tool != "EditFile" then Delegate
      else {
        -- Extract file path from arguments
        let args = parse_tool_args(call.arguments);
        let file_path = get_file_path(args);
        
        -- Check if we have a linter for this extension
        let ext = get_extension(file_path);
        match linter_cfg.linters[ext] {
          None => Delegate,  -- No linter configured, pass through
          Some(linter) => {
            -- Run the linter
            let linter_result = run_linter(file_path, linter);
            
            -- If linter fixed the file, read the fixed content
            let final_content = if linter_result.fixed then 
              readFile(file_path) 
            else 
              args.content;
            
            -- Build enhanced result
            let enhanced_stdout = build_linter_output(
              call.tool,
              file_path,
              linter_result
            );
            
            -- Return handled result with linter feedback
            Handled({
              tool_call_id: call.id,
              tool: call.tool,
              exit_code: if linter_result.has_errors then 1 else 0,
              stdout: enhanced_stdout,
              stderr: "",
              metadata: {
                "linter_ran": true,
                "linter_errors": linter_result.errors,
                "linter_warnings": linter_result.warnings,
                "linter_fixed": linter_result.fixed
              }
            })
          }
        }
      }
    },
    on_response_intercept: \_ _ . NoIntercept ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream},
    on_solver_candidate: \_ _ . NoDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
  }
}

func build_linter_output(tool: string, file_path: string, result: LinterResult) -> string {
  let base = "${tool} completed: ${file_path}";
  
  if result.errors == 0 && result.warnings == 0 then
    "${base}\n\n✓ Linter passed with no issues."
  else
    "${base}\n\n${format_issues(result)}\n\n${format_summary(result)}"
}

func format_issues(result: LinterResult) -> string {
  -- Format each error/warning line
  let lines = [];
  for issue in result.issues {
    lines = lines ++ ["${issue.file}:${issue.line}:${issue.column} - ${issue.message}"];
  };
  join("\n", lines)
}

func format_summary(result: LinterResult) -> string {
  let parts = [];
  if result.errors > 0 then
    parts = parts ++ ["❌ ${show(result.errors)} error(s)"];
  if result.warnings > 0 then
    parts = parts ++ ["⚠️  ${show(result.warnings)} warning(s)"];
  if result.fixed then
    parts = parts ++ ["✓ Auto-fixed ${show(result.fixed_count)} issue(s)"];
  
  join(" | ", parts)
}
```

### Linter Runner

```ailang
-- packages/motoko-ext-auto-linter/runner.ail

module sunholo/motoko_ext_auto_linter/runner

import std/process (exec)
import std/string (split, trim)
import std/json (Json)

export type LinterResult = {
  errors: int,
  warnings: int,
  fixed: bool,
  fixed_count: int,
  issues: [LinterIssue],
  has_errors: bool
}

export type LinterIssue = {
  file: string,
  line: int,
  column: int,
  message: string,
  severity: string  -- "error" | "warning"
}

export func run_linter(file_path: string, cfg: LinterConfig) -> LinterResult ! {Process, Env, FS} {
  let command = "${cfg.command} ${file_path}";
  
  -- Execute linter with timeout
  let result = exec(command, { 
    timeout: cfg.timeout_ms,
    cwd: get_cwd()
  });
  
  -- Parse linter output
  let issues = parse_linter_output(result.stdout, result.stderr);
  
  -- Count errors and warnings
  let errors = count_by_severity(issues, "error");
  let warnings = count_by_severity(issues, "warning");
  
  -- Check if auto-fix was applied
  let fixed = cfg.fix && result.exit_code == 0 && result.stdout != "";
  
  {
    errors: errors,
    warnings: warnings,
    fixed: fixed,
    fixed_count: if fixed then length(issues) else 0,
    issues: issues,
    has_errors: errors > 0
  }
}

func parse_linter_output(stdout: string, stderr: string) -> [LinterIssue] {
  -- Parse common linter formats (eslint, ruff, ailang check, etc.)
  let lines = split("\n", stdout ++ stderr);
  let issues = [];
  
  for line in lines {
    -- Match patterns like "file:line:col - message"
    match parse_issue_line(line) {
      None => (),
      Some(issue) => issues = issues ++ [issue]
    }
  };
  
  issues
}

func parse_issue_line(line: string) -> Option[LinterIssue] {
  -- Pattern: "path/to/file.ts:10:15 - error TS1234: Some error message"
  -- Pattern: "path/to/file.ail:10: error: Some error"
  -- Pattern: "path/to/file.py:10:15: E501 line too long"
  
  -- Try different regex patterns for different linters
  -- ... (implementation details)
}
```

### Severity Levels

| Level | Behavior |
|-------|----------|
| `warn` | Log warnings, don't block write |
| `error` | Log errors, still write file, agent sees feedback |
| `block` | Don't write file if errors exist, force agent to fix |

### Common Linter Configurations

**TypeScript/JavaScript:**
```json
{
  ".ts": {
    "command": "eslint --fix --format compact",
    "fix": true,
    "severity": "warn"
  },
  ".tsx": {
    "command": "eslint --fix --format compact",
    "fix": true,
    "severity": "warn"
  }
}
```

**AILANG:**
```json
{
  ".ail": {
    "command": "ailang check",
    "fix": false,
    "severity": "error",
    "block_on_error": true
  }
}
```

**Python:**
```json
{
  ".py": {
    "command": "ruff check --fix --output-format=concise",
    "fix": true,
    "severity": "warn"
  }
}
```

**Go:**
```json
{
  ".go": {
    "command": "gofmt -w",
    "fix": true,
    "severity": "warn"
  }
}
```

## Integration with motoko

Add to `ailang.toml`:

```toml
[dependencies]
"sunholo/motoko_ext_auto_linter" = "0.1.0"

[extensions.packages]
"sunholo/motoko_ext_auto_linter@0.1.0"
```

Add to profile config:

```json
// .motoko/config/default/auto_linter.json
{
  "enabled": true,
  "linters": { ... }
}
```

## Testing

```
Test Case 1: TypeScript with eslint
1. Agent writes TypeScript file with lint error
2. Auto-linter runs eslint
3. Agent sees error in tool result
4. Agent fixes error in next turn

Test Case 2: AILANG with blocking
1. Agent writes AILANG file with type error
2. Auto-linter runs `ailang check`
3. Write is BLOCKED (file not written)
4. Agent must fix before write succeeds

Test Case 3: Python with auto-fix
1. Agent writes Python file with formatting issues
2. Auto-linter runs `ruff check --fix`
3. File is formatted automatically
4. Agent sees "fixed 3 issues" in result

Test Case 4: Large file timeout
1. Agent writes large file
2. Linter times out after 5s
3. File still written (degraded mode)
4. Agent sees "linter timed out" warning
```

## Performance Considerations

- **Timeouts**: All linters must have timeouts (default 5s)
- **Async execution**: Don't block agent on slow linters
- **Caching**: Cache linter results for unchanged files
- **Incremental**: Only lint changed files, not entire project

## Future Enhancements

1. **Pre-commit hooks**: Run on git commit, not just WriteFile
2. **Test runner**: Auto-run tests for changed files
3. **Type checking**: Run `tsc --noEmit` for TypeScript
4. **Security scanner**: Run `semgrep` or similar for security issues
5. **Custom hooks**: Allow user-defined shell scripts as linters

## Related

- Claude Code hooks system
- ESLint, Ruff, Prettier
- AILANG `ailang check` command
- Git pre-commit hooks
