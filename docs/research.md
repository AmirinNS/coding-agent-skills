# Research log

## 2026-09-21 — pi RPC capabilities available to orchestrate-implementation-pi but not wired in

**Explored:** End-to-end test of the `orchestrate-implementation-pi` skill against a live `pi --mode rpc` session. Beyond the run itself, surveyed what the pi RPC protocol offers that the skill does not currently use.

**Key findings:**

- Sessions are recorded automatically and durably. `pi-rpc.sh` passes `--session-id "orchestrate-$SLUG"`, so one plan produces one session file covering every phase, at `~/.pi/agent/sessions/--<cwd-with-slashes-as-dashes>--/<timestamp>_orchestrate-<slug>.jsonl`. Sessions key off the working directory.
- That recording survives `pi-rpc.sh stop` and outlives the working directory. A test session (138 KB, 125 messages) was still readable after the project directory was deleted.
- Resume restores real context, not just the file. Forking the test session from an empty directory and asking what decision `A1` recorded returned the correct answer with nothing on disk to read it from. Useful commands are `pi -r` (browse per project), `pi --session-id orchestrate-<slug>` (resume in place), `pi --fork <path>` (branch without touching the original).
- `pi --export <session.jsonl>` writes a readable HTML transcript (452 KB for the test session). It takes the session file as its argument and writes `pi-session-*.html` into the current directory. It does not accept an output path, despite what `--export <file>` in the help text suggests.
- Mid-turn steering works. `{"type":"steer","message":"..."}` sent through `pi-rpc.sh send` redirected an agent that was partway through a loop of `sleep` calls; it abandoned the original task and returned the steered answer. Per `docs/rpc.md` the message lands after the current turn's tool calls finish and before the next LLM call. `follow_up` and `abort` work the same way.
- Messaging is two-way but asymmetric on timing. The orchestrator can speak at any point, including mid-turn, via `prompt`, `steer`, `follow_up`, and `abort`. The implementor can only speak at turn boundaries, by ending its turn so its final text becomes the message. That is what the `{"status": "blocked", "questions": [...]}` contract formalizes, with `plans/<slug>-questions.md` as the structured payload.
- A blocking implementor-to-orchestrator channel does exist, but the agent cannot reach it. `docs/rpc.md` documents an Extension UI Protocol where `select`, `confirm`, `input`, and `editor` emit an `extension_ui_request` on stdout and block until the client returns an `extension_ui_response` with a matching `id`. It fires only when an extension calls `ctx.ui.*`. Tool enumeration in a live session returned `read, bash, edit, write, subagent`, with no `ask_question`, since that is an extension tool and only `subagent` is installed. Told to ask a question and block, the agent asked in plain assistant text and the turn settled, emitting zero `extension_ui_request` events. A small extension exposing `ctx.ui.input()` as a tool would give the implementor a real mid-turn ask if one is ever needed.
- `pi-rpc.sh stop` runs `rm -rf "$DIR"`, deleting `events.jsonl`. The skill's Finish step calls `stop` as its first action, so the RPC event stream that `SKILL.md` points to for inspecting tool calls is always gone by the time a run ends. Low impact, since the session `.jsonl` keeps the messages, but the event stream holds the finer tool-call and timing detail.
- pi's protocol reference lives at `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/docs/rpc.md`. Read it before guessing at command shapes.

- `pi-rpc.sh` is portable to Linux. Verified on Ubuntu 24.04 / bash 5.2.21 / x86_64 against a protocol-compatible stub, 10 of 10 checks passing, including both halves of the stall fix. `TMPDIR` is unset there so state falls back to `/tmp`, and the `wc -c | tr -d ' '` normalization matters because Linux and macOS pad that output differently. Only soft dependencies are `pkill` (procps) and `python3`, which are container risks rather than Linux risks.
- `wait_from` greps for exact compact JSON such as `"type":"agent_settled"`. Real pi always serializes without spaces, but the check breaks against any serializer that emits `{"type": "agent_settled"}`. Worth knowing if pi ever changes its output format.
- Probing a remote machine over SSH for installed tools gives false negatives. Ubuntu's stock `.bashrc` returns early for non-interactive shells (`case $- in *i*) ;; *) return;; esac`), and nvm's PATH setup sits below that guard, so `ssh host 'which pi'` reports missing while an interactive terminal resolves it fine. Check `~/.nvm/versions/node/*/bin/` directly, or use `bash -ic`, before concluding anything is not installed.

**Open questions / next steps:**

- Wire `steer` into the drift halt so a phase can be stopped the moment drift is spotted, rather than waiting for the turn to settle before the Step 3.5 check runs.
- Have `stop` copy `events.jsonl` next to the plan before removing the state directory, if the tool-call detail turns out to be worth keeping.
- Decide whether the questions-file handoff should stay as-is or move to a `follow_up`-based channel now that mid-turn messaging is confirmed working.

## 2026-10-13 — Swarm smoke runs (delegate-work-swarm, orchestrate-implementation-swarm)

**Context:** Plan `plans/swarm-orchestration.md`, Milestones 4 and 6. Two scratch Git repos, real CLIs: codex-cli 0.162.1 (gpt-6.1-sol), agy 1.3.3 (default model), pi 0.85.1. Direct-task run: 7 assignments in 3 waves. Plan run: a two-phase plan, three milestones.

**Findings:**

- Same-agent concurrency works. Two pi sessions, then two agy sessions plus one Codex session, ran at once in one repo with separate ids and outputs. The one-worker-per-agent fallback was not needed.
- pi does not exit 1 on provider errors. On `429 quota exhausted` (xiaomi/mimo-v2.6-flash) and on `Connection error.` (stepfun, DNS SERVFAIL for api.stepfun.ai), pi retried by itself, then `pi-work.sh` exited 0 with an empty reply. The cause sits in `events.jsonl` as assistant messages with `"stopReason":"error"` and an `errorMessage`. The swarm rules now treat any turn without final JSON as unsuccessful and list provider outages under "unavailable".
- The unavailability rule worked as written twice. Both times pi's work was held, agy kept running, and the user was asked once; the user chose another pi model each time. Model switches were done with `PI_ORCH_MODEL` on the helper command, leaving `~/.pi/agent/settings.json` untouched.
- A stub `agy` printing a daily-quota 429 makes `agy-exec.sh` exit 1 with the message in `err.log` and no `conversation_id` saved, which confirms an interrupted first agy turn cannot be resumed.
- `restore` had a real bug the unit tests missed: it treated the assignment's handoff directory as owned changes, deleting `prompt.md`, and it failed on its own saved copies under `.orchestrate/`. Fixed (restore skips `.orchestrate/`) with test case 12b.
- The reported-versus-changed check flagged a planted edit in a file whose owner reported nothing. It cannot see a second writer inside a file the owner also changed; only diff review catches that.
- `pi --list-models <name>` is a fuzzy search (`step-5` listed `step-3.5-flash` first). Read the row whose provider and model match exactly.
- Capability routing held: with pi on a text-only model, the image task went to agy, and agy's alt text matched the chart.
- Codex as a read-only reviewer found two real policy gaps in agy's parser (Unicode digits and tab/newline separators accepted); all 15 sampled claims reproduced.
- The escalation path worked, but was forced: pi (deepseek-flash) passed the strict Roman numeral test, so no reasoning failure occurred naturally. Codex honoured the new "do not read partial/" line, excluding `partial/` from every search.
- `__pycache__` files show up as `UNOWNED` in repos without a `.gitignore` entry. They are allowed as generated artifacts, but add noise to every `attribute` call.

**Open questions / next steps:**

- Classifying slip versus reasoning failure is still orchestrator judgment; no natural reasoning failure occurred in these runs.
- Git submodules are not handled by `swarm-files.sh`.
