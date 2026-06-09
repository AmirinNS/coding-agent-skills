# Plan: SDLC Orchestrator (MCP-bridged)

## Goal
A portable SDLC orchestrator built as **one MCP server + one orchestrator skill**. The MCP server (`sdlc-mcp`) wraps Pi.dev's `AgentSession` and exposes five SDLC tools (plan, plan-review, implement-milestone, impl-review, docs). The orchestrator skill — invoked from Claude Code interactively or Codex via `AGENTS.md` — loops through phases by calling these MCP tools, using a reviewer-reported severity signal to gate review iterations and an adaptive cap (tuned by plan complexity, with an absolute ceiling) to prevent runaway loops. This avoids `claude -p` and the post-2026-06-15 Agent SDK billing pool by keeping Claude Code/Codex in interactive mode the whole time, while delegating skill execution to Pi.dev with open-weight models (Kimi K2, DeepSeek, GLM, etc.) for cost.

## Scope
- In scope:
  - Plan-feature template: complexity tier, optional phasing, milestone markers, metadata block
  - Severity rubric in `plan-review` and `implementation-review` skills + scoped review support (phase + optional milestone params)
  - `sdlc-mcp` Node.js MCP server with five tools, **`AgentAdapter` interface + Pi.dev adapter implementation**, adaptive caps with absolute ceiling, plan-metadata parser, cap-tracker persistence
  - `sdlc.config.json` for caps and Pi.dev provider configuration
  - Portable orchestrator instructions (`sdlc/ORCHESTRATOR.md`) — including the "review per-milestone when a phase has ≥5 milestones" branch — + Claude Code skill wrapper + Codex `AGENTS.md` snippet
- Out of scope (see Future Extensions for trigger conditions):
  - Rolling planning (per-phase detailed plan generation) and phase-level plan-review
  - Concrete adapter implementations beyond Pi.dev (Codex, OpenCode, Claude `claude -p`) — interface designed in, implementations deferred
  - Custom TUI — Claude Code's / Codex's existing UI is the user surface

## Approach

<!-- milestone:1 -->
### Milestone 1: Plan format — complexity, phasing, milestone markers
1. Update `skills/plan-feature/SKILL.md` template:
   - Add `<!-- milestone:N -->` HTML comment before each `### Milestone N:` heading (invisible in rendered markdown, reliably parseable).
   - Add a `## Metadata` block at the bottom of the plan:
     ```yaml
     milestone_count: 12
     complexity: large            # small | medium | large
     phased: true                 # false for small/medium, true for large
     phases:                      # only when phased: true
       - name: "Foundation"
         goal: "Project structure, auth, database schema"
         milestones: [1, 2, 3]
       - name: "Core pages"
         goal: "Main user-facing pages"
         milestones: [4, 5, 6, 7]
     ```
2. Add classification rules to the skill prompt:
   - `complexity: small` — 1–3 milestones, narrow single-area scope
   - `complexity: medium` — 4–7 milestones
   - `complexity: large` — ≥8 milestones OR explicit multi-area scope ("full website", "rewrite X")
   - `phased: true` only when `complexity == large`. For small/medium, `phased: false` and the `phases:` block is omitted.
   - When `phased: true`, every milestone must belong to exactly one phase, and `phases[*].milestones` together cover `1..milestone_count` with no gaps.
3. Add a rule to the skill: "Always emit `<!-- milestone:N -->` before each milestone heading and a `## Metadata` block at the bottom. This is required for the orchestrator MCP server to parse the plan."
→ Verify: write a sample plan via the updated skill and confirm a regex extracts `milestone_count`, `complexity`, `phased`, and (when phased) `phases[*].milestones` correctly.

<!-- milestone:2 -->
### Milestone 2: Skill contracts for MCP invocation (severity rubric + uniform JSON + new implement-milestone skill + portability audit)
1. **Uniform final-message contract** — every skill ends with a fenced ```json block:
   ```json
   {
     "status": "ready" | "needs_input",
     "needs_input": null | "question text for the user",
     ...tool-specific fields...
   }
   ```
   Document this once in `sdlc-mcp/README.md` ("Skill Output Contract"); each skill references it.

2. **Skill-specific final-block schemas** (the `...` above):
   - `plan-feature` → `{ planPath, featureName }`
   - `plan-review` → `{ severity, summary }`
   - `implementation-review` → `{ severity, summary, phase, milestone }` (last two `null` when not scoped)
   - `implement-milestone` (NEW) → `{ milestone, summary }`
   - `create-docs` → `{ docsPath, summary }`

3. **Severity rubric** — add to both `skills/plan-review/SKILL.md` and `skills/implementation-review/SKILL.md`:
   - `critical`: blocks correctness, security, feasibility, or scope. Must be addressed. Examples: missing edge case that breaks the feature, security hole, infeasible approach, scope creep, contradicts a stated requirement.
   - `minor`: nits, style preferences, optional improvements. Safe to proceed. Examples: naming, comment phrasing, optional optimizations.
   - `none`: no issues found.
   - Aggregation rule: overall severity = highest of any individual finding. One `critical` → overall `critical`.

4. **Scoped implementation-review** — update `skills/implementation-review/SKILL.md` to accept optional `phase` and `milestone` directives in its input:
   - `phase` only: review all milestones in that phase (end-of-phase review)
   - `phase` + `milestone`: review a single milestone within that phase (per-milestone review)
   - Neither: review all milestones (whole-implementation review, flat plans only)
   The skill records the scope (`phase`, `milestone`) in its final JSON block (both `null` if unscoped).

5. **New skill `skills/implement-milestone/SKILL.md`** — invoked by the MCP `implement_milestone` tool. Body:
   - Input args (passed in user prompt): `planPath`, `milestone`
   - Steps: read the plan file, locate milestone N (via the `<!-- milestone:N -->` marker), implement only that milestone's steps, run the milestone's verify step
   - Ends with the contract `{ status, needs_input, milestone, summary }`
   - Explicit: do not touch other milestones; do not refactor adjacent code

6. **Portability audit** — pass over all five skills (`plan-feature`, `plan-review`, `implementation-review`, `implement-milestone`, `create-docs`):
   - Replace references to Claude-Code-only tools (`TaskCreate`, `ExitPlanMode`, `Skill`, `Agent`, etc.) with the four-tool common subset (`read`, `write`, `edit`, `bash`) where possible; drop the rest
   - Strip references to Claude Code UI affordances ("the user will see X in the IDE", "open in the diff panel", etc.)
   - Rewrite turn assumptions: under MCP, the "user" in the conversation is the orchestrator (not a human). Skills must be self-contained — no "ask the user clarifying questions inline" outside of the `needs_input` channel.
   - Where a skill genuinely needs a human (ambiguous spec, missing decision), it sets `status: "needs_input"` with the question — the orchestrator surfaces it.

→ Verify:
   - `plan-feature`: invoke via the MCP server (or by passing the SKILL.md as a prompt to Pi.dev) on a small description → final block contains `{ planPath, featureName }`, plan file exists at `planPath` with all required Metadata fields
   - `plan-review`: (a) plan w/o critical issues → `severity: "minor"` or `"none"`; (b) deliberate critical flaw → `severity: "critical"`
   - `implementation-review`: with `phase: "Foundation"` → summary covers only milestones in that phase; with `phase: "Foundation"`, `milestone: 2` → summary references only milestone 2
   - `implement-milestone`: invoke with `milestone: 3` → only milestone 3's steps executed; verify step run; no edits to milestones 1, 2, 4+
   - `create-docs`: final block contains `{ docsPath, summary }`; docs file exists at `docsPath`
   - Portability: grep the five skill files for `TaskCreate|ExitPlanMode|Skill\(|Agent\(` — should return no matches

<!-- milestone:3 -->
### Milestone 3: `sdlc-mcp` server
1. Create `sdlc-mcp/` at project root:
   - `sdlc-mcp/package.json` — deps: `@modelcontextprotocol/sdk`, `@mariozechner/pi-coding-agent`, `zod`. `bin: { "sdlc-mcp": "./dist/server.js" }`.
   - `sdlc-mcp/tsconfig.json` — ES2022, NodeNext, strict.
2. `sdlc-mcp/src/plan-parser.ts` — given a plan file path, return:
   ```typescript
   {
     featureName: string,
     planPath: string,
     milestoneCount: number,
     complexity: "small" | "medium" | "large",
     phased: boolean,
     phases: { name: string, goal: string, milestones: number[] }[] | null,
   }
   ```
3. `sdlc-mcp/src/config.ts` — reads `sdlc.config.json` from project root, with defaults:
   ```json
   {
     "caps": {
       "small":  { "plan_review": 3,  "impl_review": 2 },
       "medium": { "plan_review": 5,  "impl_review": 3 },
       "large":  { "plan_review": 10, "impl_review": 5 },
       "absolute_ceiling": 15
     },
     "pi": {
       "provider": "openrouter",
       "model": "moonshotai/kimi-k2",
       "apiKeyEnv": "OPENROUTER_API_KEY"
     },
     "skillsDir": "skills"
   }
   ```
4. `sdlc-mcp/src/cap-tracker.ts` — persists iteration counts per plan in `plans/.state/<feature-name>.json`:
   ```json
   { "plan_review": 2, "impl_review": { "": 0, "Foundation": 1 } }
   ```
   - `impl_review` is keyed by phase name (empty string for non-phased plans).
   - Exposes `increment(planPath, kind, phase?) → { iteration, cap, capReached }`. Caps are computed from the plan's `complexity` tier; `capReached = iteration >= min(tierCap, absolute_ceiling)`.
5. `sdlc-mcp/src/adapters/adapter.ts` — `AgentAdapter` interface (shared by all backends):
   ```typescript
   export interface AgentAdapter {
     readonly name: string;            // "pi" | "codex" | "opencode" | "claude" | ...
     runSkill(args: {
       skillPath: string;              // e.g., "skills/plan-review/SKILL.md"
       userPrompt: string;             // task-specific args (plan path, milestone, phase, ...)
       workingDir: string;
     }): Promise<{ finalText: string; toolCalls: ToolCall[] }>;
   }
   ```
   `sdlc-mcp/src/adapters/pi.ts` — Pi.dev implementation: reads the skill markdown as the system prompt, passes `userPrompt` as the user turn, runs `AgentSession` to completion with the configured Pi provider/model from `sdlc.config.json`, returns the final assistant text plus a summary of tool calls. Selected by default in v1.
   Tools call `getAdapter(config).runSkill(...)` rather than calling Pi directly, so adding `codex.ts`/`opencode.ts`/`claude.ts` later is purely additive.
6. `sdlc-mcp/src/server.ts` — registers five MCP tools (stdio transport):

   **Tool: `plan_feature`**
   - Args: `{ description: string }`
   - Runs `skills/plan-feature/SKILL.md` via Pi adapter
   - Parses the produced plan file with `plan-parser.ts`
   - Returns: `{ planPath, featureName, milestoneCount, complexity, phased, phases, summary }`

   **Tool: `review_plan`**
   - Args: `{ planPath: string }`
   - `cap-tracker.increment(planPath, "plan_review")` → `{ iteration, cap, capReached }`. If already at cap before this call, returns `{ severity: "critical", capReached: true, ... }` immediately without invoking Pi.
   - Runs `skills/plan-review/SKILL.md` via Pi adapter
   - Parses the fenced JSON block from the skill's final output for `severity`, `summary`, `needs_input`
   - Returns: `{ iteration, cap, capReached, severity, summary, needs_input }`

   **Tool: `implement_milestone`**
   - Args: `{ planPath: string, milestone: number }`
   - No cap (implementation is per-milestone, sequential).
   - Runs `skills/implement-milestone/SKILL.md` via the selected adapter (same pattern as the other tools)
   - Parses the final fenced JSON block for `status`, `needs_input`, `summary`
   - Returns: `{ milestone, summary, needs_input }`

   **Tool: `review_implementation`**
   - Args: `{ planPath: string, phase?: string, milestone?: number }`
   - Scope key for cap tracker: `${phase ?? ""}:${milestone ?? ""}` — per-milestone reviews increment a separate counter from end-of-phase reviews of the same phase.
   - `cap-tracker.increment(planPath, "impl_review", scopeKey)` → cap check (same shape as plan_review)
   - Runs `skills/implementation-review/SKILL.md` via the selected adapter, with `phase` and (optionally) `milestone` directives in the user prompt
   - Returns: `{ iteration, cap, capReached, severity, summary, phase, milestone, needs_input }`

   **Tool: `create_docs`**
   - Args: `{ planPath: string }`
   - Runs `skills/create-docs/SKILL.md` via Pi adapter
   - Returns: `{ docsPath, summary }`
7. Add `plans/.state/` to `.gitignore`.
→ Verify: `cd sdlc-mcp && npm install && npm run build`. Run the server with `npx @modelcontextprotocol/inspector ./dist/server.js`. Manually invoke `plan_feature` with a small description — confirm a plan file is created and parsed correctly. Invoke `review_plan` twice — confirm `iteration` increments and cap state persists in `plans/.state/<name>.json`. Invoke `review_plan` past the small-tier cap (3) — confirm `capReached: true` is returned without invoking Pi.

<!-- milestone:4 -->
### Milestone 4: Orchestrator instructions + host integrations
1. Create `sdlc/ORCHESTRATOR.md` — the canonical, host-agnostic loop instructions. Outline:
   - **Phase 0 — Plan**: call `plan_feature(description)`. Store the returned `{ planPath, complexity, phased, phases, milestoneCount }` for the rest of the run.
   - **Phase 1 — Plan review loop**: repeatedly call `review_plan(planPath)`. After each call:
     - If `needs_input` is set, pause and ask the user verbatim; relay their answer in the next call via the user's next chat turn (the next `review_plan` invocation will pick up the addendum from the plan or the orchestrator can pass extra context).
     - If `severity != "critical"`, exit the loop.
     - If `capReached: true`, log a warning ("plan-review cap reached while severity=critical, proceeding") and exit the loop.
   - **Phase 2 — Implementation** (branches on `phased`):
     - Flat (`phased: false`): for `m` in `1..milestoneCount`, call `implement_milestone(planPath, m)`. On `needs_input`, pause and resolve. Then run a single **impl review loop** by calling `review_implementation(planPath)` until `severity != "critical"` or `capReached: true`.
     - Phased (`phased: true`): for each `phase` in `phases`:
       1. For each `m` in `phase.milestones`, call `implement_milestone(planPath, m)`. Handle `needs_input` as above.
       2. **Impl-review for this phase:**
          - If `phase.milestones.length < 5` → run one **end-of-phase review loop**: `review_implementation(planPath, phase: phase.name)` until `severity != "critical"` or `capReached: true`.
          - If `phase.milestones.length >= 5` → run **per-milestone review loops**: for each `m` in `phase.milestones`, loop `review_implementation(planPath, phase: phase.name, milestone: m)` until `severity != "critical"` or `capReached: true`. This trades extra reviews for bug containment in large phases.
   - **Phase 3 — Docs**: call `create_docs(planPath)`.
   - **Throughout**: each MCP tool result is the source of truth; do not invent iteration numbers, severity, or completion state.
2. Create `skills/orchestrate/SKILL.md` — Claude Code skill wrapper. Body is short: identifies as the SDLC orchestrator, requires the `sdlc-mcp` MCP server to be configured, instructs the model to follow `sdlc/ORCHESTRATOR.md` for the loop. Description field triggers on: "run sdlc", "orchestrate this feature", "full sdlc workflow".
3. Add a Codex `AGENTS.md` snippet at project root (or augment if one exists) with the same pointer: "For full SDLC orchestration, the `sdlc-mcp` MCP server provides five tools (plan_feature, review_plan, implement_milestone, review_implementation, create_docs). Follow `sdlc/ORCHESTRATOR.md` to drive the loop."
4. Add MCP server config example in README (or a new `sdlc-mcp/README.md`) showing how to register `sdlc-mcp` with Claude Code (`.claude/settings.json` or `claude mcp add`) and Codex (`~/.codex/config.toml`).
→ Verify: from Claude Code, type `/orchestrate add a contact form to the marketing site` — confirm the model calls `plan_feature`, loops `review_plan` until severity drops, calls `implement_milestone` for each milestone, runs `review_implementation`, calls `create_docs`. From Codex, prompt the same — confirm equivalent behavior. Test with a deliberately large feature description that should trigger `phased: true` — confirm per-phase impl reviews fire.

## Metadata
milestone_count: 4
complexity: medium
phased: false

## Affected Files
- Files to modify:
  - `skills/plan-feature/SKILL.md` — milestone markers, full metadata block (complexity, phased, phases), classification rules, final JSON-block contract (`{ status, needs_input, planPath, featureName }`), portability audit
  - `skills/plan-review/SKILL.md` — severity rubric, final JSON-block contract (`{ status, needs_input, severity, summary }`), portability audit
  - `skills/implementation-review/SKILL.md` — severity rubric, final JSON-block contract (`{ status, needs_input, severity, summary, phase, milestone }`), phase + milestone scope support, portability audit
  - `skills/create-docs/SKILL.md` — final JSON-block contract (`{ status, needs_input, docsPath, summary }`), portability audit
  - `.gitignore` — add `plans/.state/`
  - `README.md` — add MCP server registration instructions for Claude Code and Codex
- New files to create:
  - `skills/implement-milestone/SKILL.md` — new skill invoked by the `implement_milestone` MCP tool
  - `sdlc-mcp/package.json`
  - `sdlc-mcp/tsconfig.json`
  - `sdlc-mcp/src/server.ts`
  - `sdlc-mcp/src/tools/plan-feature.ts`
  - `sdlc-mcp/src/tools/review-plan.ts`
  - `sdlc-mcp/src/tools/implement-milestone.ts`
  - `sdlc-mcp/src/tools/review-implementation.ts`
  - `sdlc-mcp/src/tools/create-docs.ts`
  - `sdlc-mcp/src/adapters/adapter.ts`
  - `sdlc-mcp/src/adapters/pi.ts`
  - `sdlc-mcp/src/cap-tracker.ts`
  - `sdlc-mcp/src/plan-parser.ts`
  - `sdlc-mcp/src/config.ts`
  - `sdlc-mcp/README.md` — install + MCP registration instructions
  - `sdlc.config.json` — default caps + Pi.dev provider config
  - `sdlc/ORCHESTRATOR.md`
  - `skills/orchestrate/SKILL.md`
  - `AGENTS.md` (or addendum if one exists)

## Acceptance Criteria
- [ ] `plan-feature` template emits `<!-- milestone:N -->` markers and a `## Metadata` block with `milestone_count`, `complexity`, `phased`, and (when phased) a `phases` block; coverage of `1..N` by phases is enforced
- [ ] All five skills end with a fenced JSON block matching the uniform contract (`status`, `needs_input`, plus skill-specific fields); contract documented in `sdlc-mcp/README.md`
- [ ] `plan-feature` final block contains `{ planPath, featureName }`; `create-docs` final block contains `{ docsPath, summary }`
- [ ] `plan-review` and `implementation-review` final blocks contain `{ severity, summary }`; `implementation-review` also `{ phase, milestone }`
- [ ] `skills/implement-milestone/SKILL.md` exists and is the source loaded by the `implement_milestone` MCP tool; ends with `{ milestone, summary }`
- [ ] `implementation-review` accepts and honors optional `phase` and `milestone` scope
- [ ] Portability audit done: no `TaskCreate`, `ExitPlanMode`, `Skill(`, or `Agent(` references in any of the five skills
- [ ] `sdlc-mcp` exposes five tools: `plan_feature`, `review_plan`, `implement_milestone`, `review_implementation`, `create_docs` — each invokes the selected adapter (Pi.dev in v1) with the matching skill
- [ ] `AgentAdapter` interface is defined in `sdlc-mcp/src/adapters/adapter.ts`; tools call adapters through the interface (no direct Pi.dev imports in tool files)
- [ ] `review_implementation` accepts optional `phase` and `milestone` args; per-milestone reviews use a separate cap counter from end-of-phase reviews
- [ ] Per-plan iteration counts persist in `plans/.state/<feature-name>.json`; review tools return `iteration`, `cap`, and `capReached`
- [ ] Caps come from `sdlc.config.json` tier defaults; `capReached` returns immediately (no Pi invocation) once the tier cap or absolute ceiling is hit
- [ ] `sdlc/ORCHESTRATOR.md` describes the loop for both `phased: false` and `phased: true` plans, the per-milestone vs end-of-phase impl-review branch (threshold: phase size ≥5), `needs_input` handling, and warn-and-proceed on `capReached`
- [ ] `/orchestrate <description>` in Claude Code runs the full SDLC end-to-end against the MCP server; equivalent prompt works in Codex via `AGENTS.md`
- [ ] No `claude -p` or Claude Agent SDK calls anywhere in the runtime path
- [ ] `plans/.state/` is gitignored

## Tests
- Test type: Unit + Manual E2E
- Tests to add:
  - `sdlc-mcp/src/plan-parser.test.ts` — parses sample plan files (flat + phased) and rejects malformed metadata (missing `complexity`, gaps in phase milestone coverage)
  - `sdlc-mcp/src/cap-tracker.test.ts` — increments persist, tier caps applied correctly, absolute ceiling enforced, per-phase counters isolated, per-milestone scope keys don't collide with end-of-phase keys
- Manual E2E:
  - Small feature: invoke `/orchestrate` for a 2-milestone feature — verify flat path, plan-review converges in ≤3 iterations
  - Large/phased feature: invoke `/orchestrate` for a multi-area feature ("add marketing site + blog + contact form") — verify `phased: true` plan, per-phase impl-review fires, scoped severity returns sensibly
  - Per-milestone review branch: invoke `/orchestrate` for a feature with a single phase of ≥5 milestones — verify the orchestrator runs `review_implementation` per-milestone within that phase, and per-milestone counters are tracked separately
  - Cap-reached: deliberately design a plan reviewers won't converge on — verify `capReached: true` returned without invoking the adapter past the cap, warn-and-proceed in orchestrator

## Decisions Log
| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| Architecture | MCP server + portable orchestrator skill | Custom Ink TUI driving Agent SDK; standalone CLI runner | TUI is unneeded — Claude Code/Codex already render tool calls. Agent SDK path now bills against a separate credit pool (post-2026-06-15); MCP keeps Claude Code interactive (no Agent SDK billing). Skill is portable across hosts that support MCP. |
| Implementor backend | Pi.dev (`@mariozechner/pi-coding-agent` SDK) | OpenCode HTTP API; Codex `exec`; Claude `-p` | Pi.dev has a true embedding SDK (`AgentSession`, no subprocess), 20+ providers including open-weight (Kimi, DeepSeek, Groq, OpenRouter), and is purpose-built for embedding. OpenCode is HTTP-only and lacks MCP-server mode. Codex works fine but Pi is simpler to embed. |
| Backend pluggability | `AgentAdapter` interface in v1; Pi.dev is the only implementation shipped | Hardcode Pi.dev calls and refactor later when a second backend is needed | Designing the interface up-front costs ~20 LOC and zero design risk (the surface is just `runSkill(skillPath, userPrompt, workingDir)`). Refactoring tool files to add adaptation later would touch every tool. Future backends drop into `adapters/` without rewiring. |
| Impl-review granularity | End-of-phase by default; **per-milestone when phase size ≥5**, opt-in via the orchestrator's branch | End-of-phase always; per-milestone always; user-configured threshold | End-of-phase is cheap and works for small phases. Per-milestone is bug containment for large phases (a milestone-2 bug surfaces immediately, not 8 milestones later). The ≥5 threshold is a sensible default — can be made configurable in `sdlc.config.json` if needed. Per-milestone reviews use a separate cap counter so they don't starve the end-of-phase budget. |
| Cost routing | Cheap open-weight LLM via Pi.dev for all skill execution; Claude Code/Codex interactive runs only the orchestrator loop | Claude for reviews, Pi for impl (per-phase backend split); one model for everything | One backend per v1 keeps complexity low. Per-phase routing is a future extension once cost data is in. |
| Status reporting | Tools return structured JSON directly | MCP server writes status files, orchestrator reads them separately | Direct return is one round-trip instead of two; the original status file design was a workaround for streaming, which we no longer need. |
| Iteration / cap state | Persisted by MCP server in `plans/.state/<name>.json` | In-memory only; passed by orchestrator on each call | Server-side persistence survives MCP server restarts and prevents orchestrator from lying about iteration count (hard cap stays bulletproof). |
| Cap shape | Adaptive by complexity tier (small/medium/large) + absolute ceiling 15, configurable in `sdlc.config.json` | Fixed counts (5/2); orchestrator-side soft cap; diminishing-returns heuristic | Fixed counts under-serve large features (full website needs >5 plan reviews) and over-serve small ones. Tiered caps scale with the plan's own metadata; absolute ceiling is the runaway safety net. Config file allows tuning without code changes. |
| Severity signal source | Reviewer self-reports `critical | minor | none` in a fenced JSON block; orchestrator trusts it | Orchestrator re-judges review text; diminishing-returns heuristic | Reviewer has full context after its own review. A written rubric anchors the classification. Re-judging adds inconsistency between runs. |
| Cap-reached behavior | Warn-and-proceed (MCP returns `capReached: true`; orchestrator logs and moves on) | Abort the pipeline; require user input | Defeats "full autonomous" if pipeline halts. User can see the warning in the Claude Code / Codex transcript and intervene if needed. |
| Plan structure for large features | Flat milestones + optional `phases:` metadata grouping for `phased: true` plans | Recursive plans-of-plans; phase-per-milestone-file | Keeps the plan a single document so cross-phase dependencies are visible during the whole-plan review. Phases are an implementation/review structure, not a planning structure. |
| Plan-review per phase | Single whole-plan review pass | Per-phase plan-review loops | Phase-level plan-review is mainly valuable when plans are *rolling* (generated as you go). With upfront plans, one whole-plan review pass is sufficient and avoids per-phase loop cost. |
| Skill source location | MCP server reads `skills/<name>/SKILL.md` at runtime | Bundled in the MCP server package | Skill content can be tuned without rebuilding/republishing the server. Skills stay in the same place Claude Code reads them — single source of truth. |
| Tool granularity | Five separate tools | One `run_phase(phase, args)` tool | Five tools give the orchestrating model better self-documentation in its tool list. The `phase` switch would otherwise live in skill prompts and be invisible to the LLM. |
| Codex portability | One canonical `sdlc/ORCHESTRATOR.md` + Claude Code skill wrapper + Codex `AGENTS.md` snippet | Two parallel orchestrator definitions; Codex-only | Single source of truth for the loop logic. Hosts (Claude Code, Codex) get thin pointers. New hosts that support MCP can be added the same way. |

## Future Extensions

Trigger conditions and brief shapes — to revisit when the limits are actually felt.

| Extension | Trigger | Shape |
|-----------|---------|-------|
| **Rolling planning** | Project >15 milestones AND phases genuinely independent AND staleness pain felt (later-phase plans invalidated by earlier-phase implementation discoveries) | New tool `plan_phase(planPath, phaseName)` generates a detailed sub-plan for that phase only. Top-level plan becomes a roadmap. Orchestrator runs plan_phase → review_plan(sub) → implement → impl-review per phase. Requires multi-plan state in cap-tracker and a `parent_plan` reference in sub-plan metadata. |
| **Phase-level plan-review** | Comes with rolling planning (you cannot ship unreviewed sub-plans) | Per-phase plan-review loop runs against the phase's sub-plan, capped same as the whole-plan review (tier-based). |
| **Additional backend adapters** (Codex, OpenCode, Claude `claude -p`) | Pi.dev limitations hit (specific model unsupported, tool-use mismatch) OR per-phase backend routing (e.g., Claude for plan-review quality, Pi for implementation cost) is needed | The `AgentAdapter` interface is already in v1, so this is purely additive: add `adapters/codex.ts`, `adapters/opencode.ts`, `adapters/claude.ts`. Per-phase adapter selection moves into `sdlc.config.json`. |
| **Configurable per-milestone review threshold** | The fixed ≥5 milestones-per-phase threshold proves wrong in practice (some teams want per-milestone always; others never) | Add `caps.per_milestone_review_threshold: number` to `sdlc.config.json` (default `5`). Orchestrator reads it from config exposed via a new MCP tool or by reading the config directly. |
