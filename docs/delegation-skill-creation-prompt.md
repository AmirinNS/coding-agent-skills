# Delegation skill creation prompt

Use this prompt to create missing agent variants, update outdated ones, or maintain skills
against a newer agent release. It describes
required behavior, not a claim that all current variants already support it. See the
[delegation guide](delegation.md) for the current differences.

```text
Create, update, or maintain two skills for each target coding agent:

- orchestrate-implementation-<agent>
- delegate-work-<agent>

Work in /Users/amirinns/Projects/coding-agent-skills.

Support both creation and version-maintenance requests. In maintenance mode, scope work
to the named agent and both of its skill variants. Honor an explicitly requested release.
If the user asks for the newest release without naming a version, verify the latest stable
release from official sources. Do not select a prerelease unless requested.

Example request:
"Maintain the Codex delegation skills against the latest stable Codex CLI release.
Update affected instructions, helpers, references, and tests. Leave changes uncommitted."

Use these Codex skills as the behavioral references:

- skills/orchestrate-implementation-codex/
- skills/delegate-work-codex/

Read their SKILL.md files, helpers, references, tests, and agent metadata before making
changes. Follow applicable project instructions and skill-creation guidance.

1. Inspect existing skills

Identify the coding agents represented in this repository and inspect their corresponding
skills. If a skill is missing, create it. If it is outdated or lacks required behavior,
update it. If already correct, leave it unchanged.

Compare behavior, not wording. Preserve useful agent-specific behavior that remains
compatible with these requirements. Treat the Codex skills as the baseline intent, not
proof that every command or capability applies to another agent.

Limit changes to these skill families and necessary supporting files. Preserve unrelated
changes. Update repository listings and documentation only where needed.

2. Distinguish the workflows

orchestrate-implementation-<agent>:
- Implements an existing, readable, approved plan.
- Resolves the plan before dispatching workers or making implementation changes.
- Honors approval already provided in the conversation.
- If no plan exists, stops this workflow and recommends delegate-work-<agent>.
- Does not invent a plan, create phases, or require a planning skill merely to continue.
- Does not substitute another plan when an explicitly named file is missing.
- Uses a fresh worker thread for each phase, with review before advancing.

delegate-work-<agent>:
- Handles general and coding assignments from the user's request.
- Does not require a plans/ folder, plan file, or planning skill.
- Supports implementation, bug fixes, refactoring, investigation, requested documentation,
  and discussion.
- Uses one thread per bounded assignment and resumes it for follow-up work.

Make descriptions and instructions distinguish these workflows clearly.

Route by intent:
- "Delegate this task" selects delegate-work.
- "Delegate implementation based on this approved plan" selects orchestrate-implementation
  when the plan is available.
- Discussing or reviewing a plan does not automatically select plan implementation.
- An unrelated plans/ folder does not select orchestrate-implementation.
- Explicit invocation selects that skill, but its prerequisites still apply.

Include clear invocation examples appropriate to the host.

3. Support discussion with a subagent

For discussion-only assignments:
- Define the question and desired insight.
- Default to no product edits and use temporary handoffs when the project is read-only.
- Let the worker challenge assumptions, compare alternatives, explain reasoning, and
  identify uncertainty.
- Let the orchestrator evaluate evidence and resume the same thread for questions or
  counterarguments.
- Record useful conclusions and unresolved questions.
- Treat a completed discussion round as done. Reserve blocked for a real blocker.
- Do not require builds, tests, or implementation artifacts solely for discussion.
- Discussion does not authorize implementing suggestions.

4. Preserve coordination and verification

Keep scope, questions, answers, checkpoints, results, and review outcomes in durable
handoff records. The orchestrator owns coordination, independent review, and the
completion decision. Worker summaries are claims to verify.

Resume the existing thread for questions, corrections, and verification. Start a new
thread at phase or assignment boundaries, or after a documented recovery decision with
a checkpoint. Adapt this to the agent's verified session mechanism.

Preserve existing tracked, staged, and untracked work. Do not automatically stage, commit,
publish, install globally, or add unrelated documentation. Update older variants whose
automatic finalization conflicts with this requirement.

Verify work proportionately using actual command output. Discussion findings require
evidence checks where relevant. Implementation requires appropriate behavioral checks.

5. Handle context pressure and compaction

Determine each agent's actual context-warning and compaction capabilities.

If a worker observes a context-pressure or compaction warning:
- Save constraints, decisions, completed work, pending work, and verification evidence
  in a checkpoint.
- Report the warning and end the turn as blocked.
- Let the orchestrator decide whether to continue or request manual compaction.
- Do not let the worker request manual compaction independently.

Only use a verified supported compaction mechanism. After compaction, reload the handoff
records and continue the same assignment.

Document runtime limitations:
- Automatic compaction may occur before the worker reports a warning.
- Prompt instructions cannot guarantee control over automatic compaction.
- Do not invent warning events, compaction commands, or a runtime veto.
- Do not silently restart a session or change global settings to imitate compaction.

The orchestrator also maintains its own continuity through checkpoints.

6. Report token usage accurately

Inspect each agent's supported telemetry. Report available counters with their scope,
such as current turn, current thread, or cumulative assignment usage.

If cumulative usage can be measured reliably, preserve the necessary counters across
resumes and report the total. Confirm whether counters are incremental or cumulative
before aggregating them.

Do not estimate counts from text length, double-count cumulative counters or cached input,
or treat total tokens spent as current context occupancy. Do not claim unavailable
telemetry exists. When usage cannot be measured, report it as unavailable. Preserve
relevant telemetry before helper logs are overwritten or deleted.

7. Identify CLI versions and preserve run identity

The initial Codex CLI help snapshot for this prompt was codex-cli 0.162.1, checked on
2026-10-11. Read the maintained Codex references to resolve the current checked baseline;
do not overwrite a later verified baseline with this snapshot. Do not copy the Codex
version number into another agent's skill or treat it as a mandatory installation pin.

For each CLI-based agent:
- Confirm its actual version command and installed output.
- Document the exact version and date used to check command help.
- Distinguish help checks, mocked helper checks, and live integration verification.
- Capture the actual runtime version and selected command path before each new or
  resumed turn. For Codex, use codex --version and command -v codex, saved as
  cli-version.txt and cli-path.txt in helper state.
- If a required version check fails, report its error and do not dispatch the worker.
- Copy the captured identity into the work or implementation log after every turn,
  before resume overwrites it or stop removes helper state.
- Compare the actual version against the documented baseline and prior turns.
  If it differs, inspect the installed start and resume help before dispatch.
- Use the recorded version and command path when reproducing a failure. A selected
  command path may identify a shim or wrapper, not the underlying executable.

For native subagents without a separate CLI, record the available host version or build
identity. If the runtime does not expose it, report it as unavailable.

A version difference alone does not establish incompatibility. Do not invent a supported
version range, claim mocked checks prove live compatibility, or automatically upgrade or
downgrade the agent. Update a baseline deliberately after verifying the replacement
release, and state which checks were performed. Online docs may describe a newer release;
use installed help and observed events to establish local behavior.

8. Maintain skills against new agent versions

When invoked for version maintenance:
- Identify the previous documented baseline, installed version and command path, and
  exact target release. Compare versions using the agent's version scheme, not string
  ordering. If the target is already checked, inspect for unresolved compatibility issues
  before deciding that no update is needed.
- Read official release notes and version-relevant documentation for changes between the
  baseline and target. Cite the sources and record the review date. If sources cannot be
  accessed, state what remains unverified rather than guessing the newest version.
- Audit both skill variants and their helpers for affected commands, flags, configuration,
  session and resume behavior, event formats, permissions, compaction, and token telemetry.
  New optional features do not automatically require new integrations.
- When the target CLI is available, check its version, start help, and resume help directly.
  For Codex, inspect codex --version, codex exec --help, and codex exec resume --help.
  Inspect observed event output when a claimed format change requires it.
- Update only behavior affected by confirmed changes. Preserve routing, scope, handoffs,
  independent review, discussion support, and authorization boundaries. If commands remain
  valid, leave helper code unchanged and update only the relevant verification records.
- Add or adapt meaningful regression checks for changed helper behavior. Use an observed
  failure or a documented changed contract as the basis for mocks. Do not merely replace
  expected version strings and call that compatibility verification.
- Run applicable helper checks and skill validation. Perform live checks only when needed
  and authorized, in an isolated workspace. Report help, mock, and live evidence separately.
- Promote the target to the checked baseline only after the relevant checks succeed.
  State exactly what was checked; help or mock checks do not establish live compatibility.
  If the target CLI is unavailable or checks fail, preserve the prior checked baseline,
  record the candidate release and pending verification, and prepare only changes supported
  by available evidence. Do not claim the migration is complete.
- Find active baseline references in both skills, helper comments, maintained references,
  README, and current docs. Update applicable versions, dates, capability limits, and
  troubleshooting guidance consistently. Preserve historical records as historical facts.
  If this prompt's instructions become outdated, update them too.

Maintain an available record of the previous baseline, target release, evidence, affected
files, and remaining limits in the existing reference or maintenance documentation.
Do not create a separate versioning framework. Do not upgrade, downgrade, or install a
global CLI merely because a newer release exists. If the user separately authorizes an
installation, honor the authorized location and version.

9. Attach references and support bug fixes

Add concise references to official agent documentation and confirmed local CLI help for
the capabilities actually used.

Verify commands, flags, event formats, session handling, permissions, compaction, and usage
reporting. Do not copy Codex-specific commands into other agents without verification.

Provide troubleshooting that distinguishes task-code defects, prompt or handoff defects,
helper defects, and agent runtime, authentication, or environment problems.

The orchestrator may reproduce and fix authorized local defects, verify the repair, and
resume the worker when recoverable. Preserve diagnostics before destructive cleanup.
Do not automatically modify credentials, global configuration, installed agent binaries,
or permission boundaries.

10. Validate and deliver

Validate every created or changed skill. Run changed helpers and meaningful checks for
non-trivial helper behavior. Do not create tests that merely match instructional wording.

For CLI identity capture, check new and resumed turns, version changes across resume,
and a failed version check preventing worker dispatch. Use mocks for these local checks
without implying live service health. Keep checks runnable when a skill is installed alone;
check a sibling helper too when present without making it a required dependency.

Check routing, discussion, recovery, compaction limitations, and telemetry claims for
consistency. Read git status --porcelain and account for every file you changed.
Leave changes uncommitted.

Report skills created, updated, and left unchanged; important behavioral differences
between agents; documented and observed versions; help, mocked, and live checks actually
run; and unsupported capabilities or unresolved limits. For version maintenance, include
the previous baseline, exact target release, confirmed compatibility changes, and whether
the target was promoted to a checked baseline or remains pending verification.
```
