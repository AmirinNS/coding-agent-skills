# Codex worker troubleshooting and bugfixes

Read this when the worker reports a failure, its output does not match the actual files,
or the helper cannot start, resume, or collect a turn. Use the
[CLI reference](codex-cli-reference.md) to check installed commands and official behavior.

The orchestrator may repair reproducible task or local integration defects within the
current authorization. Documentation access does not authorize changing credentials,
global configuration, the installed Codex binary, or files outside permitted locations.
The skill's material-drift halt still applies. Do not conceal scope violations or damaged
user work through an automatic repair.

## Diagnose the failing layer

| Symptom | Evidence to inspect | Recovery |
|---|---|---|
| The worker produced incorrect task code | Actual diff, callers, failing acceptance check | Reproduce the bug, then correct it in scope or resume with a focused fix request |
| A report is missing or malformed | `last.txt`, final agent-message events, CLI exit status | If the turn succeeded and a session ID exists, resume once to restate the contract; inspect any edits first |
| An option or configuration field is rejected | Decisive stderr line, installed subcommand help, helper argument construction | Reproduce the invocation mismatch and minimally repair the helper in an authorized location |
| Resume says no thread or cannot find the session | Helper `thread`, prior `thread.started` event, working directory, CLI error | Restore the ID only when the matching prior event establishes it; never guess or use another run's ID |
| A turn fails authentication, model access, or rate limits | Sanitized stderr/events and relevant official docs | Report the actual prerequisite; preserve the requested model and do not rewrite account settings |
| A turn is silent or reaches the idle timeout | Last event, stderr, PID and process activity | Distinguish an active long command from a stalled CLI; stop a confirmed stall after preserving evidence |
| A check hits a sandbox or network denial | Exact denied command/path and permission error | Route the required action to the main session; record the check as pending until it actually runs |
| A live run fails while the helper test passes | Recorded `cli-version.txt`, `cli-path.txt`, exit status, events, environment difference | Narrow the failure to the real integration; a mocked pass cannot establish live service health |

## Repair loop

1. Preserve the evidence before another turn overwrites it. Record the assignment, working
   directory, recorded CLI version and command path, affected files, session ID if present,
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
   patch for review and obtain the required authorization before applying it. For a suspected
   upstream Codex bug, provide a reproduction and report the blocker rather than patching
   the installed package or performing an unrequested upgrade.
4. Rerun the failing reproduction and relevant existing checks. A non-trivial helper repair
   must leave a runnable regression check. Compare actual files, HEAD, and staging against
   the baseline, then resume the recorded thread if it is recoverable. Log the cause, repair,
   command results, and remaining limitations. If the same approach fails twice, reassess
   and report the blocker rather than repeating it.

If the session is unrecoverable, first account for partial file changes and preserve all
answers and verified work. Report the lost context. Start a replacement thread only after
recording the reason and constructing a handoff that includes what remains to be done.
Never silently rerun the original task from scratch over partially completed work.

## Verify a helper repair

The bundled helper checks can run without authentication or network access:

```bash
bash -n <skill-dir>/codex-exec.sh <skill-dir>/tests/test-codex-exec.sh
bash <skill-dir>/tests/test-codex-exec.sh
```

These checks cover new/resume/stop, input validation, preservation of an existing thread,
CLI failure reporting, and idle timeout. They also check CLI identity capture, version changes
across resume, and failed version capture preventing dispatch. The sibling plan helper is
checked too when present. Extend the check for the reproduced defect rather than only checking
for particular wording. They do not prove a real Codex request works.
When live integration is necessary, use a minimal authorized task in an isolated workspace,
preserve the sandbox and requested model, and inspect the actual result before claiming
the integration recovered. Keep a live check pending if access or permissions prevent it.
