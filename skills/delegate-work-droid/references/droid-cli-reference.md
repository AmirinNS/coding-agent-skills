# Droid CLI reference

Confirmed command shapes and documented behavior for the `droid` CLI as used by the
`droid-exec.sh` helper. Everything here comes from installed help output and the official
Droid documentation; the other agent skills in this repository informed the workflow only.

## Version baseline and run identity

The help-checked baseline is `droid 0.251.0`, checked on 2026-10-29 at
`/Users/amirinns/.local/bin/droid`. It is a documentation and invocation reference, not an
enforced installation pin or a live-service compatibility guarantee. Helper checks run
against a mock CLI.

Both helpers (`droid-work-<slug>` and `droid-orch-<slug>` state) save `cli-version.txt` and
`cli-path.txt` before each executed new or resumed turn. Copy the values into the work log
or implementation log after every turn, before another turn overwrites them or `stop`
removes them. A failed version capture prevents worker dispatch.

If the actual version differs from the baseline or the previous turn, inspect
`droid --help`, `droid exec --help`, and `droid resume --help` before dispatch. Reproduce
failures against the recorded version and command path; the path may identify a wrapper
rather than the underlying executable. A version difference alone is not a failure and does
not authorize an upgrade or downgrade. Update the baseline deliberately after verifying the
replacement release.

## Maintenance record, 2026-10-29

Evidence collected when this baseline was set:

- **Help checks (verified):** `droid --help`, `droid exec --help`, `droid resume --help` on
  the installed binary. Confirmed the flags the helper uses: `-f <file>`, `-o stream-json`,
  `--auto low|medium|high`, `-s <session-id>`, `-m <model>`, `-r <level>`, `--cwd`,
  `--tag`, `--append-system-prompt(-file)`, `--list-tools`, tool selectors, and that
  `droid exec -s` continues an existing session and requires a prompt.
- **Mocked helper checks (verified):** `tests/test-droid-exec.sh` covers session capture,
  resume with `-s`, autonomy mapping, guards, failure paths, idle timeout, and CLI identity
  capture against a mock CLI. They do not establish live service behavior.
- **Live probe (partial, default custom model):** one `droid exec -o stream-json` run in an
  isolated temporary directory observed the event shapes used by the extractor: a `system`
  init event carrying `session_id`, `cwd`, `tools`, `model`, and `reasoning_effort`;
  `message` events; and `error` events carrying `session_id` and `message`. Every observed
  event carried `session_id`. That turn ended with `429 you have no left credit for step
  plan` from the configured custom model before any assistant output, so it produced no
  terminal event.
- **Live verification (2026-10-29, `custom:Xiaomi-MiMo-V2.6-Flash`):** read-only turns
  through the shipped helper in an isolated workspace verified session capture from the init
  event, the terminal `completion` event
  (`{"type":"completion","finalText":...,"numTurns":...,"durationMs":...,"session_id":...,"timestamp":...,"usage":{...}}`),
  `droid exec -s` resume (same `session_id`, `numTurns` incremented, same terminal shape),
  and per-turn `usage` counters (`input_tokens`, `output_tokens`, `cache_read_input_tokens`,
  `cache_creation_input_tokens`, `factory_credits`, `thinking_tokens`, `ttft_ms`). Turn 2's
  cache-read counter showed the replayed earlier conversation, confirming the per-turn
  usage semantics. This check also caught an extractor defect: the terminal text field is
  `finalText`, which the original extractor missed, leaving `last.txt` empty. The fix is in
  both helpers and the regression is encoded in `tests/test-droid-exec.sh`.
- **Not live-verified:** end-to-end editing worker turns (autonomy enforcement and
  fail-fast permission stops), billing or auth failure paths, and long-running turn
  behavior. Helper checks beyond the shapes above remain mocked.

## Official documentation

- Droid Exec (headless): https://docs.factory.com/droid-exec/overview.md
- Droid CLI reference (commands, flags, exit codes, worktrees): https://docs.factory.com/droid-cli/cli-reference.md
- Autonomy Level (what each tier allows, approvals, policy): https://docs.factory.com/autonomy-and-safety/auto-run.md
- Permission rules (`droid rules check`): https://docs.factory.com/autonomy-and-safety/permission-rules.md
- Droid TypeScript SDK (result states, per-turn token usage, context stats): https://docs.factory.com/sdk/typescript.md
- Factory Missions (`--mission`, not used by these skills): https://docs.factory.com/missions/overview.md

## Installed command checks

`droid exec` is a one-shot run. The helper invokes it as:

```bash
droid exec -o stream-json -f <prompt-file> [--auto <low|medium|high>] [-m <model>] [-s <session-id>]
```

Facts confirmed by installed help and the official docs:

- Default (no `--auto`) is read-only. `--auto low` allows file edits and low-risk commands;
  `--auto medium` adds installs, builds, tests, and local `git commit`; `--auto high` adds
  pushes, deploys, and other high-risk automation. `--skip-permissions-unsafe` skips all
  permission prompts and is never passed by the helper.
- A command above the current autonomy level fails fast: the run stops at that action,
  prints an error to stderr, and exits non-zero. Edits made before that point stay in the
  working tree.
- Exit codes: `0` finished (not proof the task succeeded), `1` general runtime error,
  `2` invalid arguments. A permission stop exits non-zero.
- `-s <session-id>` continues an existing session and requires a prompt. `--fork <id>`
  branches into a new session. The `json` output envelope carries `session_id`, `result`,
  and `usage` for scripting; `stream-json` emits one event per line while the run
  progresses.
- Auth for headless runs is `FACTORY_API_KEY` in the environment (or an existing login).
  `droid doctor` diagnoses configuration, connectivity, and auth problems.

## Helper command contract

`droid-exec.sh` ships next to this skill. Commands:

```bash
bash droid-exec.sh <slug> new <prompt-file> [auto]     # fresh session, wait, print final message
bash droid-exec.sh <slug> resume <prompt-file> [auto]  # next turn on the current session
bash droid-exec.sh <slug> session                      # print the current session id
bash droid-exec.sh <slug> stop                         # kill a running turn and remove state
```

- `auto` is `none` (default), `low`, `medium`, or `high`; `none` passes no `--auto` flag.
- State lives under `${TMPDIR:-/tmp}/droid-work-<slug>/` (delegate skill) or
  `${TMPDIR:-/tmp}/droid-orch-<slug>/` (plan skill).
- `new` and `resume` exit `1` when droid fails or when the event stream stays silent for
  `DROID_EXEC_IDLE_TIMEOUT` seconds (default 600).
- `DROID_ORCH_MODEL` overrides the model (`-m`) for every turn. Set it only when the user
  requests a model override.

## Diagnostic files

Under the state directory:

| File | Contents |
|---|---|
| `events.jsonl` | The last turn's `stream-json` event stream (init, messages, tool calls, errors) |
| `last.txt` | The extracted final message of the last turn |
| `usage.json` | The terminal event's `usage` counters, when the event carried them |
| `err.log` | The CLI's stderr for the last turn |
| `session` | The session id used by `resume` |
| `cli-version.txt`, `cli-path.txt` | The CLI identity captured before the turn |
| `pid` | The running turn's process id, present only while a turn runs |

The terminal event extraction accepts `completion` or `result` event types and the
`finalText`, `result`, `text`, or `message` text fields. `finalText` is the field observed
live on `completion` events; the others cover the documented `json` envelope. If no
terminal event exists, `last.txt` falls back to the last `error` event's message.

## Token usage and compaction

- Each turn reports its own usage: input tokens, output tokens, cache-read and
  cache-created input tokens, and Factory Service Credits, when the terminal event carries
  them. The helper stores the latest snapshot in `usage.json`; copy it into the log before
  the next turn or `stop` overwrites or removes it.
- Usage is per turn, not a session total. One turn can make several model calls whose
  usage is combined, and a later turn counts earlier conversation again when it replays it
  as input. Never sum input or cache counters across turns; report per-turn snapshots.
  Missing counters are reported as unavailable, never estimated.
- These counters measure usage, not current context occupancy. Context occupancy is not
  exposed through `droid exec`; the SDK's `getContextStats()` is not available to the
  helper. Report it as unavailable instead of estimating.
- Droid compacts sessions automatically near a configured threshold (commonly around
  250,000 tokens). The helper drives one-shot `droid exec` turns and has no manual
  compaction command. The interactive CLI has `/compress`, and stream JSON-RPC sessions
  expose history compaction methods, but neither is integrated here. Do not invent a
  compaction command. The recovery path for a drifting worker is a checkpoint in the handoff
  files and a fresh `new` session that reads them.

## Configuration and permissions

- **Autonomy is the permission boundary.** Pick the lowest level that covers the
  assignment: `none` for read-only analysis and discussion, `low` for edit-only work,
  `medium` when the assignment installs, builds, or runs tests. Never pass
  `--skip-permissions-unsafe`, and do not raise the level mid-assignment to force a blocked
  action through; route the action to the main session or ask the user.
- **`medium` allows local `git commit`.** The dispatch prompt forbids staging, commits, and
  pushes, and review rechecks `HEAD` and the index against the recorded baseline. A commit
  or moved `HEAD` is material drift. `droid rules check --command '<cmd>'` previews command
  policy when a check is being blocked.
- **Command policy** (`permissionRules`) can allow, require approval, or block commands. An
  effective `ask` is not cleared in a one-shot run, and a `block` has no approval path. A
  policy-blocked check is reported as skipped or routed to the main session, never worked
  around.
- **Organization controls** may cap the maximum autonomy level. A capped or rejected level
  is an environment fact to report, not something to bypass.
- **Worktrees** (`--worktree`) exist for parallel runs on one repository, but these skills
  do not use them: the drift check and baselines assume the worker edits the same tree the
  orchestrator reviews.
- **Mission Mode** (`droid exec --mission`) is Droid's own multi-agent orchestration and
  auto-approves its proposals. These skills deliberately do not use it; they keep scope,
  review, and approval in the orchestrator's session.
- **Sessions persist.** `stop` removes the helper's state only. The Droid session remains
  in the local session store, where `droid search` and the session picker can still find
  it. That is the reviewable record of the worker's turns.
