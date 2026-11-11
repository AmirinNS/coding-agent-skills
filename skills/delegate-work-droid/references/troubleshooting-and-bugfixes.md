# Droid worker troubleshooting and bugfixes

Read this when the worker reports a failure, its output does not match the actual files,
or the helper cannot start, resume, or collect a turn. Use the
[CLI reference](droid-cli-reference.md) to check installed commands and official behavior.

The orchestrator may repair reproducible task or local integration defects within the
current authorization. Documentation access does not authorize changing credentials,
global configuration, the installed Droid binary, or files outside permitted locations.
The skill's material-drift halt still applies. Do not conceal scope violations or damaged
user work through an automatic repair.

## Diagnose the failing layer

| Symptom | Evidence to inspect | Recovery |
|---|---|---|
| The worker produced incorrect task code | Actual diff, callers, failing acceptance check | Reproduce the bug, then correct it in scope or resume with a focused fix request |
| A report is missing or malformed | `last.txt`, `events.jsonl` terminal event, CLI exit status | If the turn finished and a session id exists, resume once to restate the contract; inspect any edits first |
| The turn succeeded but the final message is empty | `events.jsonl` terminal event field names versus the extractor's field chain in `extract_result` | The extractor missed the terminal text field. `finalText` is the field observed live on `completion` events (defect found and fixed 2026-10-29). Extend the field chain for any new name and add the observed event shape to the mock test |
| The run stops with a permission error and exits non-zero | Decisive stderr line in `err.log`, the autonomy level used | The action exceeded the level (fail-fast behavior). Do not raise the level to force it through; route the action to the main session or ask the user. Edits before the stop stay in the tree |
| A command is rejected by policy | `droid rules check --command '<cmd>'`, the block/ask decision | A blocked check has no approval path in a one-shot run. Report it as skipped or pending; never bypass policy |
| Resume says no session or cannot find one | Helper `session`, `events.jsonl` init event, working directory | Restore the id only when a prior event establishes it; never guess or reuse another run's id. If the turn never produced an event, start `new` and let the handoff files carry state |
| A turn fails authentication, model access, billing, or rate limits | Sanitized stderr and `error` events (`429 ...`, auth messages), `droid doctor` | Report the actual prerequisite. The checked baseline hit `429 you have no left credit for step plan` on a custom model; that is a billing prerequisite, not a code defect. Preserve the requested model and do not change account settings |
| A turn is silent or reaches the idle timeout | Last event in `events.jsonl`, `err.log`, PID and process activity | Distinguish an active long command from a stalled CLI; stop a confirmed stall after preserving evidence |
| A check hits an autonomy or policy denial | Exact denied command and error text | Route the required action to the main session; record the check as pending until it actually runs |
| A live run fails while the helper test passes | Recorded `cli-version.txt`, `cli-path.txt`, exit status, events, environment difference | Narrow the failure to the real integration; a mocked pass cannot establish live service health |

## Repair loop

1. Preserve the evidence before another turn overwrites it. Record the assignment, working
   directory, recorded CLI version and command path, affected files, session id if present,
   exit status, and decisive error line in the work log. Keep full diagnostics private and
   redact secrets from reports.
   If a worker is still active, stop it and confirm the affected processes are no longer
   editing the target before changing its helper or the same product files.
2. Reproduce the failure with the smallest permitted input. For task code, use the actual
   failing path. For a helper bug, prefer an isolated temporary workspace and a mock CLI
   that emits the observed event or exit pattern. Inspect every caller of the function or
   command being changed. Use fix-bug when available; otherwise follow this reproduce-first
   loop directly. Do not route the repair through a plans/ requirement.
3. Apply the smallest fix to the failing layer. The orchestrator can fix the local helper
   itself when the worker cannot run. Confirm the helper's real installed location and
   permissions first. If that file is outside authorized scope, prepare the diagnosis and
   patch for review and obtain the required authorization before applying it. For a
   suspected upstream Droid bug, provide a reproduction and report the blocker rather than
   patching the installed binary, downgrading, or disabling the auto-updater unasked.
4. Rerun the failing reproduction and relevant existing checks. A non-trivial helper repair
   must leave a runnable regression check. Compare actual files, HEAD, and staging against
   the baseline, then resume the recorded session if it is recoverable. Log the cause,
   repair, command results, and remaining limitations. If the same approach fails twice,
   reassess and report the blocker rather than repeating it.

If the session is unrecoverable, first account for partial file changes and preserve all
answers and verified work. The session itself stays in Droid's local session store for
inspection even after helper state is gone. Report the lost conversational context. Start a
replacement session with `new` only after recording the reason and constructing a handoff
that includes what remains to be done. Never silently rerun the original task from scratch
over partially completed work.

## Verify a helper repair

The bundled helper checks can run without authentication or network access:

```bash
bash -n <skill-dir>/droid-exec.sh <skill-dir>/tests/test-droid-exec.sh
bash <skill-dir>/tests/test-droid-exec.sh
```

These checks cover new/resume/session/stop, input validation, autonomy mapping, preservation
of an active session, CLI failure reporting, terminal-event tolerance, and idle timeout.
They also check CLI identity capture, version changes across resume, and failed version
capture preventing dispatch. The sibling plan helper is checked too when present. Extend
the check for the reproduced defect rather than only checking for particular wording. They
do not prove a real Droid request works.

When live integration is necessary, use a minimal authorized task in an isolated workspace,
keep the autonomy level and requested model, and inspect the actual result before claiming
the integration recovered. Keep a live check pending if access, credit, or permissions
prevent it.
