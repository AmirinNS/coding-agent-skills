# Antigravity subagent troubleshooting and bugfixes

Practical guide to diagnosing and fixing problems when orchestrating Antigravity (`agy`) subagents.

## Quick diagnostic commands

When an agy turn fails or behaves unexpectedly, inspect these artifacts first:

```bash
# Check helper process status
bash <skill-dir>/agy-exec.sh <slug> status

# Read the current conversation id
bash <skill-dir>/agy-exec.sh <slug> conversation

# Check recorded CLI version and executable path
cat "${TMPDIR:-/tmp}/agy-work-$SLUG/cli-version.txt"
cat "${TMPDIR:-/tmp}/agy-work-$SLUG/cli-path.txt"

# Inspect raw stdout JSON and stderr
cat "${TMPDIR:-/tmp}/agy-work-$SLUG/output.json"
cat "${TMPDIR:-/tmp}/agy-work-$SLUG/err.log"

# Inspect real-time CLI engine activity log
tail -n 50 "${TMPDIR:-/tmp}/agy-work-$SLUG/agy.log"
```

## Common failure modes and bugfixes

### 1. Authentication failure

**Symptoms:**
- Error message: `You are not logged into Antigravity` or `error getting token source`.
- agy command exits with non-zero status during startup.

**Root cause:**
Expired OAuth credentials in the system keyring or missing auth token in `~/.gemini/antigravity-cli/antigravity-oauth-token`.

**Bugfix procedure:**
1. Stop any background orchestrator turns: `bash <skill-dir>/agy-exec.sh <slug> stop`.
2. Open a terminal and run `agy` interactively once to refresh credentials via OAuth flow.
3. Verify authentication succeeded by running:
   ```bash
   agy --print "hello"
   ```
4. Once verified, resume your orchestration run with `resume`.

### 2. Tool permission prompts hang execution

**Symptoms:**
- agy turn remains running indefinitely without writing output.
- Log indicates a tool call is awaiting user approval on stdin.

**Root cause:**
The `--dangerously-skip-permissions` flag was omitted, or global settings require confirmation for specific commands.

**Bugfix procedure:**
1. Check that `agy-exec.sh` includes `--dangerously-skip-permissions` in its command options.
2. Check `~/.gemini/antigravity-cli/settings.json`. Set `"toolPermission": "always-proceed"`.
3. If specific commands fail due to explicit deny rules, inspect the `"permissions"` object in `settings.json` and remove or adjust the restriction.

### 3. Turn hangs or triggers idle timeout

**Symptoms:**
- Helper terminates with `no events for ~600s, turn killed` or `no activity for ~600s`.
- Worker got stuck inside a long-running command, interactive pager, or hung process.

**Root cause:**
The subagent executed a command that requires interactive stdin (e.g. `npm init` without `-y`, `git log` without a pager limit, or an unhandled dev server).

**Bugfix procedure:**
1. Kill the hung turn and clean state:
   ```bash
   bash <skill-dir>/agy-exec.sh <slug> stop
   ```
2. Read the tail of `err.log` and `agy.log` to identify the command that hung.
3. In your reply prompt, instruct agy:
   - Run commands non-interactively (e.g. `CI=1`, `-y`, `--batch`).
   - Limit long outputs using `PAGER=cat` or head/tail.
   - Do not launch background servers directly inside foreground commands.
4. If a legitimate command simply takes a long time (such as large compilation or clean build), increase the timeout before resuming:
   ```bash
   AGY_EXEC_IDLE_TIMEOUT=1200 bash <skill-dir>/agy-exec.sh <slug> resume <prompt-file>
   ```

### 4. Malformed or missing JSON status block

**Symptoms:**
- Helper exits 0, but stdout lacks the expected `{"status": "done"}` or `{"status": "blocked"}` block.
- Orchestrator cannot parse the result.

**Root cause:**
Subagent wrote conversational text but neglected the ending JSON contract, or truncated its response.

**Bugfix procedure:**
1. Check `output.json` to view the raw assistant output:
   ```bash
   cat "${TMPDIR:-/tmp}/agy-work-$SLUG/output.json"
   ```
2. If the work was done but the JSON block is missing, resume the conversation with a short formatting prompt:
   ```bash
   cat << 'EOF' > .orchestrate/<slug>/prompt.md
   Your previous response omitted the required final JSON block. Please state your final status now by ending with exactly one fenced JSON block:
   ```json
   {"status":"done","assignment":"<id>","summary":"<one paragraph>","files":[],"checks":[],"pending":[]}
   ```
   EOF
   bash <skill-dir>/agy-exec.sh <slug> resume .orchestrate/<slug>/prompt.md
   ```

### 5. Access denied to files outside current working directory

**Symptoms:**
- agy reports permission denied when reading files in parent repositories or sibling folders.

**Root cause:**
Antigravity workspaces restrict tool access to the current project directory by default.

**Bugfix procedure:**
1. In `~/.gemini/antigravity-cli/settings.json`, set:
   ```json
   "allowNonWorkspaceAccess": true
   ```
2. Add the target directory to `"trustedWorkspaces"` in `settings.json`.
3. If running from command line, pass `--add-dir /path/to/extra/directory`.

### 6. Rate limits or model quota exhaustion

**Symptoms:**
- Log records HTTP 429 or quota exhaustion from the Gemini API.

**Root cause:**
The default model reached hourly request or token limits.

**Bugfix procedure:**
1. Override the model using an alternative high-capacity model:
   ```bash
   export AGY_ORCH_MODEL="gemini-3.1-pro-high"
   ```
   Or switch to a Claude model if configured:
   ```bash
   export AGY_ORCH_MODEL="claude-sonnet-5-5-high"
   ```
2. Resume the conversation. The new model will pick up the existing conversation context cleanly.

### 7. CLI version check failure

**Symptoms:**
- Helper terminates with `agy-exec: cannot record Antigravity CLI version`.
- Subagent turn is not dispatched.

**Root cause:**
The `agy` executable was not found on `PATH`, lacks execute permissions, or failed when running `agy --version`.

**Bugfix procedure:**
1. Check that `command -v agy` prints a valid executable path.
2. Run `agy --version` directly in your shell to verify the binary executes cleanly.
3. Inspect `${TMPDIR:-/tmp}/agy-work-$SLUG/err.log` for details.

### 8. Native Antigravity subagent issues

**Symptoms:**
- `invoke_subagent` errors when called within an Antigravity IDE/CLI session.

**Bugfix procedure:**
1. Check the subagent arguments:
   - `Role`: 2 to 5 words (e.g. `Phase Implementor`).
   - `TypeName`: `self` (inherits parent tools) or `research`.
   - `Workspace`: `inherit` (shares the current project tree).
2. Use `manage_subagents` with action `list` to inspect active subagents and their conversation IDs.
3. If a subagent is frozen, terminate it with action `kill` and ConversationIds array.
