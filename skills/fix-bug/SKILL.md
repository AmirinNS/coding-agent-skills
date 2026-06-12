---
name: fix-bug
description: "Diagnose and fix a bug with a reproduce-first approach. Use this skill when the user reports a bug, error, or unexpected behavior. Triggers: 'fix this bug', 'debug this', 'this is broken', 'why is this failing', 'fix the error', 'something is wrong with'. Reproduces the issue first, finds root cause, applies a minimal fix, and verifies."
---

# Fix Bug

Diagnose and fix bugs with a reproduce-first approach. No heavy planning — find it, understand it, fix it, verify it.

## Input

The user reports a bug. It may be:
- An error message or stack trace
- A description of unexpected behavior ("clicking X does Y instead of Z")
- A failing test
- A file or component that's broken

If the bug is unclear, ask: "What's the expected behavior vs. what's actually happening?"

## Step 1: Reproduce

Before touching any code, confirm the bug exists:
- Run the failing test, command, or workflow the user described.
- If no test exists, reproduce manually or write a minimal reproduction.
- Capture the actual error — stack trace, wrong output, or unexpected state.

**If you can't reproduce it, stop and tell the user.** Don't fix what you can't see.

## Step 2: Find Root Cause

Trace the bug to its source. Don't guess — read the code path:
- Start from the error or unexpected behavior and trace backward.
- Read the relevant files. Follow the data flow.
- Identify the exact line(s) where the behavior diverges from expected.

Common patterns to check:
- Off-by-one or boundary errors
- Null/undefined where a value is expected
- Wrong variable, stale state, or race condition
- Incorrect conditional logic
- API misuse or wrong arguments
- Missing error handling on a path that can fail

State the root cause clearly before fixing: "The bug is in `file.py:42` — the condition checks `>=` but should check `>`."

## Step 3: Fix

Apply the **minimal fix** that addresses the root cause:
- Change only what's necessary to fix the bug.
- Don't refactor surrounding code.
- Don't add features or "improvements" while you're in here.
- Match existing code style.

If the fix is non-obvious or could change behavior beyond the bug, explain the tradeoff to the user before applying.

## Step 4: Verify

**Iron Law:** No "fixed!" claim without fresh verification evidence in this message. Run the command; read the output; then claim the result.

Confirm the fix works:
1. Run the reproduction from Step 1 — it should pass now.
2. Run related tests — nothing else should break.
3. If no test existed, write one that catches this specific bug so it doesn't regress.

When you add a regression test, prove it actually catches the bug — don't trust that "it passes after the fix" means "it would have failed before." Run the **red → green** cycle:

1. Revert your fix (`git stash` or comment out the patch).
2. Run the new test — it MUST fail with the expected symptom. If it passes, the test doesn't reproduce the bug; rewrite the test before re-applying the fix.
3. Restore the fix.
4. Run the new test again — it MUST pass.
5. Run the broader suite — nothing else breaks.

A regression test that has never been red is not a regression test.

Report results:
```
### Verification
- Reproduction: [Passes / Still failing]
- Related tests: [All pass / Failures found]
- Regression test added: [Yes — file:location / No — reason]
```

## Output Format

```
## Bug Fix: [Short description]

### Root Cause
[File:line] — [What's wrong and why]

### Fix Applied
[File:line] — [What was changed]

### Verification
- Reproduction: [Passes / Still failing]
- Related tests: [All pass / Failures found]
- Regression test added: [Yes / No]
```

## Rules
- Reproduce before fixing. Always.
- Fix the root cause, not the symptom. Don't add a null check to hide a bug upstream.
- Minimal change. A bugfix is not a refactoring opportunity.
- If the fix reveals a deeper issue, fix the reported bug first, then mention the deeper issue separately.
- If you can't find the root cause, say so. Don't apply speculative fixes.
- Always verify. Don't assume your fix works — run it.
