# pi worker troubleshooting and bugfixes

Read this when the worker reports a failure, its output does not match the actual files, or
the helper cannot start, resume, or collect a turn. Use the
[pi CLI reference](pi-cli-reference.md) to check installed commands and official behavior.

The orchestrator may repair reproducible task or local integration defects within the current
authorization. Documentation access does not authorize changing credentials, global
configuration such as `~/.pi/agent/settings.json`, the installed pi binary, or files outside
permitted locations. The skill's material-drift halt still applies. Do not conceal scope
violations or damaged user work through an automatic repair.

## Diagnose the failing layer

| Layer | Symptom | Evidence to inspect | Recovery |
|---|---|---|---|
| Task code | The worker produced incorrect code | Actual diff, callers, failing acceptance check | Reproduce the bug, then correct it in scope or resume with a focused fix request |
| Prompt or handoff | The worker forgot the brief, contradicted an answer, or produced a malformed report | `task.md`, `answers.md`, `work-log.md`, `last` assistant text in `events.jsonl` | Fix the handoff record, then resume the same session with a corrected instruction |
| Helper | The helper cannot start, resume, or collect a turn | Helper stderr, `cmds.log`, argument construction | Reproduce against a mock CLI and minimally repair the helper in an authorized location |
| pi runtime, auth, or environment | The session dies, credentials fail, or the model is unavailable | `err.log`, `events.jsonl`, `pi auth check --provider <provider>` | Report the actual prerequisite and ask the user to fix it |

A failed turn is not automatically worker drift. Separate the four layers before acting.

## Repair loop

1. Preserve the evidence before another turn overwrites it. Record the assignment, working
   directory, recorded CLI version and command path, affected files, session id if present,
   exit status, and the decisive error line in the work log. Keep full diagnostics private and
   redact secrets from reports. If a worker is still active, stop it and confirm the affected
   processes are no longer editing the target before changing its helper or the same product
   files.
2. Reproduce the failure with the smallest permitted input. For task code, use the actual
   failing path. For a helper bug, prefer an isolated temporary workspace and a mock `pi` that
   emits the observed event or exit pattern. Inspect every caller of the function or command
   being changed. Use `fix-bug` when available; otherwise follow this reproduce-first loop
   directly. Do not route the repair through a `plans/` requirement.
3. Apply the smallest fix to the failing layer. The orchestrator can fix the local helper
   itself when the worker cannot run. Confirm the helper's real installed location and
   permissions first. If that file is outside authorized scope, prepare the diagnosis and
   patch for review and obtain the required authorization before applying it. For a suspected
   upstream pi bug, provide a reproduction and report the blocker rather than patching the
   installed package or performing an unrequested upgrade.
4. Rerun the failing reproduction and relevant existing checks. A non-trivial helper repair
   must leave a runnable regression check. Compare actual files, HEAD, and staging against the
   baseline, then resume the recorded session if it is recoverable. Log the cause, repair,
   command results, and remaining limitations. If the same approach fails twice, reassess and
   report the blocker rather than repeating it.

If the session is unrecoverable, first account for partial file changes and preserve all
answers and verified work. Report the lost context. Start a replacement session only after
recording the reason and constructing a handoff that includes what remains to be done. Never
silently rerun the original task from scratch over partially completed work.

## Verify a helper repair

The bundled helper checks run without authentication or network access:

```bash
bash -n <skill-dir>/pi-work.sh <skill-dir>/tests/test-pi-helpers.sh
bash <skill-dir>/tests/test-pi-helpers.sh
```

These checks cover input guards, fresh session ids per assignment or phase, resume, compact,
stop, and CLI identity capture including a version change across resume and a failed capture
preventing dispatch. They run against a mock `pi`. Extend the check for the reproduced defect
rather than only checking for particular wording. They do not prove a real pi request works.

When live integration is necessary, use a minimal authorized task in an isolated workspace,
preserve the requested model and trust flags, and inspect the actual result before claiming
the integration recovered. Keep a live check pending if access or permissions prevent it.
