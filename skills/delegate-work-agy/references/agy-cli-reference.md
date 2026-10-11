# Antigravity CLI reference

Read this when diagnosing worker startup, resume, output, configuration, or telemetry problems.
This is a focused reference for the bundled helper, not a copied Antigravity manual.

Official pages and changelog were checked on 2026-10-11. Command help was checked against
`1.3.3`, the installed release on that date. Check the installed version and command help again
when repairing an integration, because later CLI versions can change supported flags and behavior.

## Version baseline and run identity

`1.3.3` at `/Users/amirinns/.local/bin/agy` is the help-checked baseline, not an enforced
installation pin or a supported-version range. Mock helper tests establish local invocation and
state handling. They do not establish live service compatibility for that release.

Both Antigravity helpers record `agy --version` output and the path returned by `command -v agy`
before executing each new or resumed turn. Read `cli-version.txt` and `cli-path.txt` from that
helper's state directory and copy their values to the work log or implementation log. The path
identifies the selected command, which may itself be a shim or wrapper.

When the recorded version differs from the baseline or a prior turn, inspect installed `agy --help`
and compare the failure against that version's actual output. Do not assume every difference is
incompatible. Use `agy changelog` to inspect changes in newer releases. Do not upgrade or downgrade
the CLI automatically to match the baseline.

## Official documentation and discovery

| Topic | Official source or command | Use it for |
|---|---|---|
| Non-interactive runs | `agy --help`, `agy -p` / `--print` | Print mode flags, `--output-format json`, `--conversation`, `--log-file` |
| Subcommands | `agy help` | Available CLI subcommands |
| Model selection | `agy models` | Available models and aliases |
| Preconfigured agents | `agy agents` | Available specialized agents |
| MCP management | `agy mcp` | Manage MCP servers (`add`, `remove`, `list`, `enable`, `disable`) |
| Plugin management | `agy plugin` | Manage plugins (`install`, `uninstall`, `list`, `enable`, `disable`) |
| Release history | `agy changelog` | Release notes and changes across versions |
| Runtime settings | `~/.gemini/antigravity-cli/settings.json` | CLI settings, permissions, and trusted workspaces |
| Engine configuration | `~/.gemini/config/config.json` | Global agent engine settings and MCP configurations |
| Native subagents | In-session `invoke_subagent` | In-process subagent workflows |

## Installed command checks

```bash
agy --version
command -v agy
agy --help
agy changelog
agy models
```

The skill's worker runs as a separate CLI process driven by `agy --print`. Native subagents inside
an interactive Antigravity session use `invoke_subagent`.

## Helper command contract

From the target project's root:

```bash
bash <skill-dir>/agy-exec.sh <slug> new <prompt-file>
bash <skill-dir>/agy-exec.sh <slug> resume <prompt-file>
bash <skill-dir>/agy-exec.sh <slug> conversation
bash <skill-dir>/agy-exec.sh <slug> stop
```

The helper passes `--dangerously-skip-permissions`, `--output-format json`, and `--log-file`.
A requested model override uses `--model`. A reasoning effort override uses `--effort`.
`resume` targets the conversation ID saved by the helper via `--conversation <id>`.

## Diagnostic files

The following are local helper files under `${TMPDIR:-/tmp}/agy-work-<slug>/` (or `agy-orch-<slug>/`):

| File | Contents |
|---|---|
| `output.json` | Latest turn's raw JSON response from `agy --print` |
| `err.log` | Latest turn's CLI stderr |
| `agy.log` | Latest turn's CLI activity log |
| `cli-version.txt` | Actual `agy --version` output from latest dispatch attempt |
| `cli-path.txt` | Command path selected from PATH before that turn |
| `conversation_id` | Active conversation ID returned by agy |
| `pid` | PID used to detect and stop the current CLI process |

`new` and `resume` overwrite the latest-turn diagnostics. Copy relevant evidence to temporary
storage before retrying. `stop` removes these local files, so capture evidence before stopping.
It does not delete the project's handoff record.

Version and path records are overwritten on each executed turn and removed by `stop`. If version
capture fails, the helper reports the error and does not dispatch `agy`.

The helper's idle timeout measures time without new bytes in `agy.log`, not total command run time.
Inspect process activity before classifying a silent turn as hung.

## CLI release 1.3.3 audit and capabilities

Key capabilities and behaviors confirmed in release 1.3.3:

- **JSON output contract**: `agy --print --output-format json` prints a root JSON object with
  `conversation_id`, `status` (`SUCCESS` or error status), and `response`.
- **Session resumption**: `--conversation <id>` resumes an existing conversation.
- **Permissions**: `--dangerously-skip-permissions` skips tool permission prompts during print mode.
- **MCP server tools**: Support for `_meta: {"antigravity/alwaysLoad": true}` on MCP tools to load
  without discovery delays.
- **Plugins**: Plugins can declare subagents in a root-level `agents.json`.
- **Terminal sandbox**: On macOS, commands running in the sandbox cannot read
  `~/Library/Application Support` by default unless explicitly permitted in settings.
- **Workspace isolation**: Subagents started with `branch` or `share` workspaces in multi-repository
  workspaces run in isolated repository checkouts.
- **Pager handling**: Commands run with `JJ_PAGER=cat`, `PAGER=cat`, and `GIT_PAGER=cat` to avoid
  interactive terminal hangs.

## Token usage and compaction

Antigravity logs step metrics in `transcript.jsonl` under each conversation directory:
`~/.gemini/antigravity-cli/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`.
Logged fields include `input_tokens`, `cache_read_tokens`, and `output_tokens` on model turns.
Read actual emitted fields when reporting metrics rather than estimating token counts from message
length.

The helper captures the turn response and conversation ID but does not calculate cumulative totals
across turns. Preserve observed metrics in the work log or implementation log before another turn
runs. Label their scope (step, turn, or conversation). Do not add cumulative counters together as if
they were independent increments, and do not count cached input twice. If cumulative usage cannot be
measured reliably across turns, report that limitation explicitly. Total tokens spent over a task
differ from the tokens occupying the active context window.

Antigravity manages context compaction automatically at the engine level. The CLI and bundled helper
do not expose a manual compaction command. A prompt instruction asking the worker to wait or stop
does not establish a runtime veto over engine-level compaction.

When a worker observes an advance context-pressure or compaction warning, it must save a checkpoint
and end the turn as blocked so the orchestrator can decide the next action. Do not invent compaction
commands, change global settings, or silently restart conversations to imitate compaction.

## Configuration and permissions

Antigravity stores settings across two primary locations:

### 1. `~/.gemini/antigravity-cli/settings.json`

Controls runtime behavior for the `agy` CLI tool:

```json
{
  "allowNonWorkspaceAccess": true,
  "model": "Gemini 3.8 Flash (High)",
  "toolPermission": "always-proceed",
  "trustedWorkspaces": [
    "/Users/amirinns/Projects"
  ],
  "permissions": {
    "allow": [
      "command(echo)"
    ]
  }
}
```

Key fields:
- `allowNonWorkspaceAccess`: Set `true` to allow file operations outside the workspace root.
- `toolPermission`: `always-proceed` bypasses interactive permission confirmations.
- `trustedWorkspaces`: List of root directories where tool operations are permitted.

### 2. `~/.gemini/config/config.json`

Controls global agent engine settings, MCP configurations, and plugin permissions.

## Environment variables for orchestrators

The helper scripts (`agy-exec.sh`) recognize these environment overrides:

- `AGY_ORCH_MODEL`: Overrides the model passed via `--model` (e.g. `export AGY_ORCH_MODEL="gemini-3.1-pro-high"`).
- `AGY_ORCH_EFFORT`: Overrides the reasoning effort passed via `--effort` (e.g. `export AGY_ORCH_EFFORT="max"`).
- `AGY_EXEC_IDLE_TIMEOUT`: Maximum seconds of inactivity in the log stream before a turn is aborted (defaults to 600 seconds).

## Data and session directories

- Brain and trajectory storage: `~/.gemini/antigravity-cli/brain/<conversation-id>/`
- Transcript logs: `~/.gemini/antigravity-cli/brain/<conversation-id>/.system_generated/logs/transcript.jsonl`
- Background tasks: `~/.gemini/antigravity-cli/brain/<conversation-id>/.system_generated/tasks/`
- Helper transient state: `${TMPDIR:-/tmp}/agy-work-<slug>/` (or `${TMPDIR:-/tmp}/agy-orch-<slug>/`)
