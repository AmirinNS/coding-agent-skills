# Codex CLI reference

Read this when diagnosing worker startup, resume, output, or configuration problems.
This is a focused reference for the bundled helper. It is not a copied Codex manual.

Official pages were checked on 2026-10-11. Command help was checked against
`codex-cli 0.162.1`. Check the installed version and subcommand help again when repairing
an integration because later CLI versions can change supported flags and behavior.

## Version baseline and run identity

`codex-cli 0.162.1` is the help-checked baseline, not an enforced installation pin or
a supported-version range. Mock helper tests establish local invocation and state handling;
they do not establish live service compatibility for that release.

Both Codex helpers record `codex --version` output and the path returned by
`command -v codex` before executing each new or resumed turn. Read `cli-version.txt` and
`cli-path.txt` from that helper's state directory and copy their values to the handoff log.
The path identifies the selected command, which may itself be a shim or wrapper.

When the recorded version differs from the baseline or a prior turn, inspect installed
`exec` and `exec resume` help and compare the failure against that version's actual output.
Do not assume every difference is incompatible. Online documentation may describe a newer
release; the [official CLI reference](https://learn.chatgpt.com/docs/cli/reference) supports
command discovery, while installed help establishes the available local flags.
Do not upgrade or downgrade the CLI automatically to match the baseline.

## Maintenance review, 2026-10-11

The previous checked baseline and exact target are both `codex-cli 0.162.1`. Numeric
version components are equal, so there is no intervening release range to migrate.
The [official latest-release endpoint](https://api.github.com/repos/openai/codex/releases/latest)
returned `rust-v0.162.1`, with `draft=false`, `prerelease=false`, and publication time
2026-10-09T19:44:51Z. The publisher's
[`@openai/codex` latest metadata](https://registry.npmjs.org/@openai/codex/latest) independently
returned `0.162.1`. The installed command at `/Users/amirinns/.local/bin/codex` returned
`codex-cli 0.162.1`.

The [release notes](https://github.com/openai/codex/releases/tag/rust-v0.162.1) describe fixes
to multiline asynchronous questions in the TUI and startup compatibility with background
server feature settings. Neither requires changing these helpers' flags or resume handling.
The helpers pass no explicit feature overrides. Optional commands in installed help, such
as `exec fork`, do not replace this workflow's same-thread resume.

| Evidence | Result and scope |
|---|---|
| Installed CLI | `codex --version`, `command -v codex`, `codex exec --help`, and `codex exec resume --help` checked directly. Both help outputs list the helpers' JSONL, final-output, configuration, and model options and document stdin prompts. The direct-task helper also uses `--skip-git-repo-check`; the plan helper explicitly enables sandbox network access. |
| Release source and official docs | Reviewed the pinned [event schema](https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/exec/src/exec_events.rs), [JSONL processor](https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/exec/src/event_processor_with_jsonl_output.rs), and the linked non-interactive, sandbox, configuration, and app-server documentation. Corrected telemetry scope and documented permission-profile conflicts below. |
| Mocked checks | `bash skills/delegate-work-codex/tests/test-codex-exec.sh` passed, including new/resume identity, version changes, and failed version capture preventing dispatch on both helpers. It also passed with only the direct-task skill copied into a temporary directory. These are synthetic events and versions, not observed service output. |
| Local validation | Shell syntax checks passed for both helpers and the test script. Both skills passed skill-creator's `quick_validate.py` using `uv run --no-project --with PyYAML`; plain `python3` lacked PyYAML. |
| Live integration | Not run. No changed helper contract required a service request. Authentication, service health, actual event emission, counter continuity across live resumes, and permission enforcement remain unverified by this pass. |

The checked baseline remains `0.162.1`; no newer candidate is pending. Both skill
instructions, this reference, README, and the delegation guide carry the corrected record
or telemetry guidance. This pass leaves helpers, tests, agent metadata, troubleshooting,
other agents, and the maintenance prompt unchanged. No CLI was installed or changed, and
no changes were staged or committed.

## Official documentation

| Topic | Official source | Use it for |
|---|---|---|
| Scripted runs | [Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode) | Exec sessions, JSONL events, final output, and resume |
| Command options | [Developer commands, CLI](https://learn.chatgpt.com/docs/developer-commands?surface=cli) | Supported flags and subcommands |
| Configuration | [Config basics](https://learn.chatgpt.com/docs/config-file/config-basic) | User/project configuration and override precedence |
| Authentication | [Authentication](https://learn.chatgpt.com/docs/auth) | Login and authentication failures |
| Permissions | [Sandbox](https://learn.chatgpt.com/docs/sandboxing) | Filesystem and network limits, and approvals |
| Native subagents | [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents) | Child agent workflows inside Codex, when actually involved |

Fetch only the page relevant to the observed failure. Prefer an already-connected official
documentation tool or the available OpenAI Docs skill. Otherwise open the linked official
page. If online docs are unavailable, use installed help and the actual event stream and
state that current online behavior could not be verified.

## Installed command checks

```bash
codex --version
codex exec --help
codex exec resume --help
codex login --help
codex login status
```

`login status` helps diagnose the selected authentication method; it does not prove that
a live request can reach the service or use the requested model. Do not print credential
files or secret environment values. Follow the [authentication guide](https://learn.chatgpt.com/docs/auth)
when the user needs to restore login.

The skill's worker is a separate CLI session started by `codex exec`. Native subagents
inside that session are a separate mechanism described in the [subagent guide](https://learn.chatgpt.com/docs/agent-configuration/subagents).
Use the recorded parent session ID for helper resume; do not substitute a child agent ID.

## Helper command contract

From the target project's root:

```bash
bash <skill-dir>/codex-exec.sh <slug> new <prompt-file>
bash <skill-dir>/codex-exec.sh <slug> resume <prompt-file>
bash <skill-dir>/codex-exec.sh <slug> thread
bash <skill-dir>/codex-exec.sh <slug> stop
```

The helper uses `--json`, `-o`, `--skip-git-repo-check`, and
`-c 'sandbox_mode="workspace-write"'`. A requested model override uses `-m`.
Check `exec resume --help` separately. Do not assume every `exec` option is valid after
`resume`; this helper uses a configuration override accepted by both commands.
These options are described in the [CLI command reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli).

`resume` targets the session ID saved by this helper, with the prompt passed on stdin.
Keep the working directory stable. Do not use `--last`, which could select another run.
Avoid ephemeral execution in this workflow because subsequent turns need a persisted
session. See [non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode).

## Diagnostic files

The following are local helper files under `${TMPDIR:-/tmp}/codex-work-<slug>/`:

| File | Contents |
|---|---|
| `events.jsonl` | The latest turn's event stream |
| `last.txt` | The latest turn's final response, possibly empty after a failure |
| `err.log` | The latest turn's CLI stderr |
| `cli-version.txt` | Actual `codex --version` output from the latest dispatch attempt |
| `cli-path.txt` | Command path selected from PATH before that turn |
| `thread` | Session ID extracted from a `thread.started` event |
| `pid` | PID used to detect and stop the current CLI process |

`new` and `resume` overwrite the latest-turn diagnostics. Copy relevant evidence to
temporary storage before retrying. `stop` removes these local files, so capture evidence
before stopping. It does not delete the project's handoff record or invoke CLI session
deletion. Inspect `codex-exec.sh` if helper behavior changes.

Version and path records are also overwritten on each executed turn and removed by `stop`.
If version capture fails, the helper reports the error and does not dispatch `codex exec`.

The JSONL stream and the final fenced JSON response serve different purposes. The stream
shows commands, file changes, turn completion, and errors. The final response follows this
skill's done/blocked contract. A missing final response does not prove that no files changed.
See [JSONL output](https://learn.chatgpt.com/docs/non-interactive-mode#make-output-machine-readable).

The helper's idle timeout measures time without new event bytes, not the maximum duration
of a command. Inspect actual process activity before classifying a silent turn as hung.
Do not repeatedly increase the timeout to conceal a reproducible failure.

## Token usage and compaction

`codex exec --json` emits usage counters in `turn.completed`. The checked release's
[event schema](https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/exec/src/exec_events.rs)
defines input, cached input, cache-write input, output, and reasoning output fields. Read
actual emitted fields rather than asking the worker to estimate its token count. See
[non-interactive output](https://learn.chatgpt.com/docs/non-interactive-mode#make-output-machine-readable).

The pinned [JSONL processor](https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/exec/src/event_processor_with_jsonl_output.rs)
copies `ThreadTokenUsage.total` into `turn.completed.usage`, despite the event schema's
per-turn wording. Treat these as thread-total snapshots, not independent turn increments.
This is source evidence, not a live resume measurement from this maintenance pass.

The helper stores the latest event stream but does not aggregate usage. Preserve each
snapshot and thread ID in the work log before another turn overwrites the diagnostics.
Use the latest reliable total for a thread; do not sum its snapshots across resumes. Combine
totals only across distinct threads with complete evidence. Keep cache and reasoning fields
as breakdowns rather than adding them to input/output. If counters are missing, reset, or
incomplete, report the affected cumulative usage as unavailable. The processor defaults to
zero when it has no usage notification, so an all-zero snapshot alone is not proof of no use.
Total usage over a task is different from the current context size; do not use cumulative
spend alone as a compaction trigger.

The app-server provides `thread/tokenUsage/updated` notifications and a
`thread/compact/start` method for manual compaction. Those require an app-server integration;
they are not commands exposed by this shell helper. See the
[app-server reference](https://learn.chatgpt.com/docs/app-server).

When a worker reports an observable compaction warning, save a checkpoint and let the
orchestrator decide the next step. Do not assume every CLI run emits an advance warning.
The pinned exec event schema has no dedicated context-pressure or compaction event.
Automatic history compaction remains a runtime mechanism governed by its configured
threshold. A prompt asking the worker to wait does not establish control over that mechanism.
See the [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

## Configuration and permissions

When invocation and observed behavior disagree, check the relevant configuration field
and its origin. CLI overrides take precedence over ordinary defaults, while enforced
requirements can constrain allowed behavior. Project configuration also depends on trust.
See [configuration precedence](https://learn.chatgpt.com/docs/config-file/config-basic#configuration-precedence).

The current [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
says not to combine `default_permissions` profiles with `sandbox_mode` or
`sandbox_workspace_write` settings. These helpers use the latter settings. If startup reports
a conflict, preserve the decisive error and identify the configuration source. Do not remove
managed restrictions, ignore user configuration, or migrate global permission settings as an
automatic repair. The help checks here do not exercise that configuration combination.

A blocked filesystem or network action can be an expected permission boundary. Diagnose
the denied action and route it through the main session's approval process when necessary.
Do not remove sandbox settings, ignore rules, or change global configuration as a repair
shortcut. See [sandboxing](https://learn.chatgpt.com/docs/sandboxing).
