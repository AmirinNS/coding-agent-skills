# pi CLI reference

Read this when diagnosing worker startup, resume, output, compaction, or telemetry problems
for the bundled `pi` helper. This is a focused reference, not a copied pi manual.

Official pages were checked on 2026-10-11. Command help was checked against `pi 0.85.1`, the
installed release on that date. Re-check the installed version and help when repairing an
integration, because later releases can change supported commands and behavior.

## Version baseline and run identity

`pi 0.85.1` at `/opt/homebrew/bin/pi` is the help-checked baseline, not an enforced
installation pin or a supported-version range. Mock helper tests establish local invocation
and state handling; they do not establish live service compatibility for that release.

Both helpers record `pi --version` output and the path returned by `command -v pi` before
executing each new or resumed turn. Read `cli-version.txt` and `cli-path.txt` from the
helper's state directory and copy their values to the work log or implementation log. The
path identifies the selected command, which may itself be a shim or wrapper.

When the recorded version differs from the baseline or a prior turn, inspect `pi --help`
again and compare the failure against that version's actual output. A difference alone does
not establish incompatibility and does not authorize an upgrade or downgrade. Update the
baseline deliberately after checking the new release.

## Official documentation

The pi docs ship with the installed CLI and match its version. Resolve them from the binary
instead of hardcoding a path:

```bash
PI_PKG=$(cd "$(dirname "$(readlink -f "$(command -v pi)")")/../.." && pwd)
ls "$PI_PKG/docs"
```

| Problem | Local doc |
|---|---|
| RPC commands, events, error shapes | `docs/rpc.md` |
| Compaction triggers, split turns, cut points | `docs/compaction.md` |
| Session file layout, entry ids, forking | `docs/sessions.md`, `docs/session-format.md` |
| `PI_*` variables, shell tool environment | `docs/environment-variables.md` |
| Model and provider selection | `docs/models.md`, `docs/providers.md` |
| Project trust, `-a`, no built-in sandbox | `docs/security.md` |
| Real isolation for untrusted work | `docs/containerization.md` |
| Building or patching pi, the `/debug` log | `docs/development.md` |
| Usage, cost, and context footer semantics | `docs/usage.md` |
| Loading skills and extensions into a session | `docs/skills.md`, `docs/extensions.md` |

Upstream source and issues: https://github.com/earendil-works/pi and
https://github.com/earendil-works/pi-mono

Fetch only the doc relevant to the observed failure. If the installed docs are unavailable,
use `pi --help` and the actual event stream, and state that current behavior could not be
verified.

## Installed command checks

```bash
pi --version
pi --help
pi auth check --provider <provider>              # add --model <pattern> to check one model
PI_PKG=$(cd "$(dirname "$(readlink -f "$(command -v pi)")")/../.." && pwd); ls "$PI_PKG/docs"
```

`pi auth check` reports provider readiness. It does not prove that a live request can reach
the service or use the requested model. Do not print credential files or secret environment
values.

## Helper command contract

From the target project's root:

```bash
bash <skill-dir>/pi-work.sh <slug> new <prompt-file>       # delegate-work-pi
bash <skill-dir>/pi-work.sh <slug> resume <prompt-file>
bash <skill-dir>/pi-work.sh <slug> compact ["<instructions>"]
bash <skill-dir>/pi-work.sh <slug> send '<json>'
bash <skill-dir>/pi-work.sh <slug> session
bash <skill-dir>/pi-work.sh <slug> stop

bash <skill-dir>/pi-rpc.sh <slug> new <prompt-file>        # orchestrate-implementation-pi
bash <skill-dir>/pi-rpc.sh <slug> resume <prompt-file>
bash <skill-dir>/pi-rpc.sh <slug> run <prompt-file>        # new if idle, resume otherwise
bash <skill-dir>/pi-rpc.sh <slug> compact ["<instructions>"]
bash <skill-dir>/pi-rpc.sh <slug> send '<json>'
bash <skill-dir>/pi-rpc.sh <slug> session
bash <skill-dir>/pi-rpc.sh <slug> status
bash <skill-dir>/pi-rpc.sh <slug> stop
```

Both helpers run `pi --mode rpc` with `--session-id`, `--session-dir`, and `-a`. The prompt
is delivered as a `{"type":"prompt","message":...}` line on the session's stdin, which a
`tail -f` pipe keeps open.

The helpers wait for `agent_settled`, not `agent_end`. One low-level run can be followed by
an automatic retry or a compaction retry, so `agent_end` is not the end of a turn. See
`docs/rpc.md` for the event table.

Set `PI_ORCH_MODEL` to override the model. It accepts a `provider/id` pattern with an
optional `:<thinking>` suffix. Idle timeouts are `PI_WORK_IDLE_TIMEOUT` and
`PI_RPC_IDLE_TIMEOUT`, both defaulting to 600 seconds.

## Diagnostic files

These are local helper files. `delegate-work-pi` uses
`${TMPDIR:-/tmp}/pi-work-<slug>/`; `orchestrate-implementation-pi` uses
`${TMPDIR:-/tmp}/pi-orch-<slug>/`.

| File | Contents |
|---|---|
| `events.jsonl` | The event stream, including tool calls, retries, and compaction events |
| `cmds.log` | The commands sent to the session, also used as the stdin pipe source |
| `err.log` | pi's stderr |
| `cli-version.txt` | Actual `pi --version` output from the latest dispatch attempt |
| `cli-path.txt` | Command path selected from PATH before that turn |
| `session` | The current session id |
| `gen` | Assignment or phase counter behind the session id sequence |
| `pid` | PID used to detect and stop the current process |

`new`, `resume`, and `run` overwrite the latest-turn diagnostics. Copy relevant evidence to
the work or implementation log before retrying. `stop` removes these local files, so capture
evidence before stopping. It does not delete the project's handoff record. Inspect the helper
script if its behavior changes.

If version capture fails, the helper reports the error and does not send the prompt.

A missing final message does not prove that no files changed. Inspect `events.jsonl` for
tool calls before concluding anything about the tree.

The idle timeout measures time without new event bytes, not the maximum duration of a
command. Inspect actual process activity before classifying a silent turn as hung. Do not
repeatedly increase the timeout to conceal a reproducible failure.

## Token usage and compaction

`get_session_stats` reports `tokens` (input, output, cacheRead, cacheWrite, total), `cost`,
and `contextUsage` (tokens, contextWindow, percent). Per `docs/rpc.md`, `tokens` and `cost`
include assistant messages, usage reported by tools, and compaction and branch-summary
generation across the full session. `contextUsage` is the current context-window estimate
used for compaction and footer display, not cumulative spend.

`contextUsage` is omitted when no model or context window is available, and its `tokens` and
`percent` are `null` immediately after compaction until a fresh post-compaction assistant
response provides valid usage data.

`compact` responds with `tokensBefore`, `estimatedTokensAfter`, and `usage`.
`estimatedTokensAfter` is a heuristic estimate over the rebuilt message context, not a
provider-exact count. `usage` covers the summarization call itself.

Read actual emitted fields rather than asking the worker to estimate. Label their scope:
session-cumulative for `tokens` and `cost`, current-context for `contextUsage`, per-call for
`compact`'s `usage`. Do not add cumulative counters together as if they were independent
increments, and do not count `cacheRead` twice. Total tokens spent over an assignment differ
from the tokens occupying the current context window.

Manual compaction is supported through `{"type":"compact"}` with optional
`customInstructions`, and `{"type":"set_auto_compaction","enabled":...}` toggles automatic
compaction. Automatic compaction fires when context tokens exceed the window minus
`reserveTokens` (default 16384), keeping roughly `keepRecentTokens` (default 20k) of recent
messages. See `docs/compaction.md`.

Automatic compaction can still occur before a worker reports a warning. Prompt instructions
do not establish a runtime veto over it. Do not invent commands, change global settings, or
silently restart a session to imitate compaction.

## Configuration and permissions

pi has no built-in sandbox. The worker can run any command, including `git commit` and
`git push`. The dispatch prompt forbids it and review rechecks HEAD and the index, but that
is a detection control, not a barrier. Never widen trust or permissions to get a check to
pass.

`-a` trusts project-local files for the run. See `docs/security.md` for project trust and
`docs/containerization.md` for real isolation of untrusted work.

Global configuration such as `~/.pi/agent/settings.json`, credentials, and the installed
binary are outside routine local fixes. Prepare a proposed change and obtain the user's
authorization before applying one.
