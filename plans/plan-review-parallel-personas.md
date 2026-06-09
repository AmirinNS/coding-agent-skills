# Plan: Multi-persona plan-review (portable, sequential)

## Goal

Collapse the user's typical 2-10 sequential `plan-review` passes into a single invocation by adding a new skill `plan-review-personas` that runs N persona reviewers **sequentially within one skill body** and emits an explicit `CONVERGED / NEAR-CONVERGED / NOT CONVERGED` verdict. The skill is **portable** — it uses only the `read / write / edit / bash` tool subset, no `Agent`, `Skill`, `ToolSearch`, `TaskCreate`, or `ExitPlanMode`. This is the bar set by `coding-agent-skills/plans/sdlc-orchestrator.md` (lines 84, 95, 248) so the skill runs unchanged under Claude Code today AND under sdlc-orchestrator on Pi.dev / OpenCode / Codex tomorrow.

Source-of-truth design doc: `/Users/amirinns/.claude/plans/refer-the-https-opencode-ai-and-adaptive-conway.md` — refer for persona lenses (lines 41-48) and output envelope shape (lines 51-59). That doc assumes Claude-Code-only parallel fan-out; this plan deliberately diverges to honour the orchestrator's portability contract.

## Scope

**In**
- Create new skill `skills/plan-review-personas/SKILL.md` — runs 5 personas sequentially in the same orchestrator context, aggregates findings, applies fixes, emits convergence verdict. **Existing `skills/plan-review/SKILL.md` stays untouched** as the fast single-pass option.
- New skill triggers (distinct from `plan-review`): `"personas review the plan"`, `"multi-persona review"`, `"deep review the plan"`, `"thorough plan review"`, `"adversarial review of the plan"`.
- Append a `**Verdict:**` line, `**Personas run:**` line, and `**Acknowledged (won't fix):**` line (omitted if empty) to the Review Log block. All existing Review Log fields stay verbatim so `implementation-review` and `create-docs` continue to read plans without changes. The original `plan-review` continues writing the legacy format.

**Out**
- No `plan-review-loop` skill. Convergence loops are the orchestrator's job (sdlc-orchestrator already owns severity gating + adaptive caps per its M2 plan). Under Claude Code without orchestrator, the user re-triggers the skill manually if the verdict is NOT CONVERGED — same UX as today's 2-10 sequential runs but with explicit stop signal.
- No `Agent`-based parallel fan-out. Parallelism is the orchestrator's responsibility when it lands; under Claude Code today, personas run sequentially in the same skill body.
- No changes to `plan-review`, `plan-feature`, `implementation-review`, `create-docs`, or any other skill.
- No new settings, hooks, CLI flags, or shared state files.
- No edits to existing plans in `plans/` to backfill the new Verdict line.
- No README/CLAUDE.md updates.

## Approach

### 1. Create `skills/plan-review-personas/SKILL.md`

Frontmatter: `name: plan-review-personas`; description names the 5 triggers from Scope.

Body steps (each persona lives in the **same** skill body — no subagent spawn, no cross-skill call):

1. **Read plan + existing Review Log.** Build two lists:
   - **Dedup list** — issues previously logged as resolved (don't re-flag).
   - **Acknowledged list** — issues previously logged under `**Acknowledged (won't fix):**` (don't re-flag, ever). This is the escape hatch so a stubborn persona finding cannot block convergence forever.
2. **Calibrate small vs large** — same logic as existing `plan-review` (lines 29-40). Small plans run personas 1, 3, 5 only.
3. **Run personas sequentially in this order** (each persona is a labelled subsection in the skill body — the orchestrator reads the section, applies the lens, emits findings in the strict envelope, then moves to the next persona). **Parseable section boundaries:** wrap each persona block with HTML-comment markers (`<!-- persona:1 architecture -->` … `<!-- /persona:1 -->`) so a future `sdlc-orchestrator` MCP server can slice individual persona prompts out of this file for parallel fan-out (one Pi.dev session per persona) without needing a `persona:` arg on the skill itself. The skill remains the single source of truth for persona prompts regardless of whether the MCP server runs them sequentially in one Pi session or in parallel sub-sessions.
   1. **Architecture & Design** — abstraction layers, data model integrity, coupling, single points of failure.
   2. **Security** — authn/authz gaps, injection, sensitive-data exposure, input validation. (Skipped on small plans.)
   3. **Devil's Advocate** — over-engineering check AND adversarial: actively tries to break the plan, cut scope, find unstated assumptions. Carries the user's "not critical enough" complaint directly.
   4. **Feasibility & Ops** — unrealistic timelines, missing rollback, deployment risk, edge cases, integration breaks. (Skipped on small plans.)
   5. **Library API Correctness** — scans plan for library/framework references; if any are named, attempts to verify version assumptions. **Capability probe:** "listed as an available tool" means **directly callable without a schema-loading step** — i.e., the tool appears in the immediate tool list, not behind a deferred-tool wrapper. If `mcp__plugin_context7_context7__resolve-library-id` is directly callable, use it (and `query-docs`). Do NOT call `ToolSearch` to load deferred schemas (that's Claude-Code-only and would break portability). **Expected behavior under Claude Code today:** MCP tools are exposed as deferred tools (require `ToolSearch` to load schemas), so persona 5 will always return `Skipped` under Claude Code. Persona 5 runs substantively only under MCP backends that expose context7 as directly callable (Pi.dev with the context7 server registered, OpenCode, etc.). If the tools are not directly available, the persona returns `Verdict: Skipped — no library inspection tool available in this runtime` with empty findings. If the plan names no libraries, return `Verdict: No new critical flaws` with empty findings — do not invent libraries.
4. Each persona emits findings in this strict envelope (matches source-of-truth doc lines 51-59):
   ```
   ## Persona: <name>
   **Verdict:** No new critical flaws | Minor issues only | Critical flaws remain | Skipped — <reason>
   **Critical findings:**
   - [flaw] — impact: [...] — suggested fix: [...]
   **Minor findings:**
   - [...]
   ```
5. **Aggregate & dedupe.** Walk every finding; mark cross-persona duplicates (same flaw surfaced by two lenses → keep once, tag with both source personas). Each finding carries a `source: [persona names]` tag — this drives both conflict resolution and the regression check.
6. **Apply fixes.**
   - For non-conflicting fixes: apply directly.
   - For conflicting fixes (two personas, same plan region, different fixes): pick the **smallest plan delta** and log the rejected alternative on the same Review Log row as `— Alternatives: [other fix] — Rejected because: [reason]`. Do not silently drop a persona's suggestion.
   - For findings where multiple viable fixes have meaningfully different tradeoffs: ask the user (carry the "default to action, not questions" rule verbatim from existing `plan-review/SKILL.md` line 178 — only ask when there's a real tradeoff).
7. **Regression check.** After fixes are applied, re-read the affected plan regions and re-apply the lenses of the personas tagged on those fixes. Because everything runs in the same orchestrator context, this is a re-read + re-evaluate — not a new model invocation. If the regression check surfaces a new critical finding, loop back to step 6 (cap regression iterations at 2 inside one skill invocation to prevent infinite churn). **One regression iteration = one full cycle of (re-read affected regions → re-evaluate via tagged personas' lenses → apply any new fixes).** After 2 cycles, stop regressing even if new criticals surface — log them under `Still open` so the next invocation can address them with fresh judgment.
8. **Emit verdict** (printed to user AND written to Review Log):
   - **CONVERGED** — every persona returned `No new critical flaws` (or `Skipped`) and the regression check is clean.
   - **NEAR-CONVERGED** — only minor findings remain across all personas, no criticals.
   - **NOT CONVERGED** — one or more critical findings remain unfixed (auto-fix failed or user input needed).
9. **Write ONE consolidated Review Log entry** to the plan file, in this exact field order:
   - `**Verdict:**` — must match `^\*\*Verdict:\*\* (CONVERGED|NEAR-CONVERGED|NOT CONVERGED)$` exactly. No trailing punctuation, emoji, or extra prose on the line. Anything after must be on a new line. This pinned format is the parse contract for any future orchestrator loop.
   - `**Personas run:**` — comma-separated persona names actually invoked (small-plan calibration shows here).
   - `**Flaws found:**` — count.
   - `**Changes made:**` — bullets, each with persona tag(s) and (when relevant) rejected alternatives.
   - `**Acknowledged (won't fix):**` — bullets (omit the line entirely if none). Each acknowledged finding feeds the dedup list for the next invocation. **How a finding gets here:** the skill never auto-acknowledges. A finding moves into Acknowledged only by user instruction — either (a) the user manually edits the prior Review Log block to add the bullet before the next invocation, or (b) the user tells the orchestrator "acknowledge: <finding text>" in the conversation, and the skill carries that into the next Review Log entry's Acknowledged line. This keeps the escape hatch fully user-controlled — the skill's job is to find flaws, not decide which ones don't matter.
   - `**Still open:**` — bullets.

### 2. Portability discipline

The skill body MUST NOT contain references to any of: `Agent(`, `Skill(`, `ToolSearch`, `TaskCreate`, `ExitPlanMode`. These are Claude-Code-only primitives and would break under Pi.dev / OpenCode / Codex backends. The acceptance criteria include a grep check.

Context7 MCP tools (`mcp__plugin_context7_context7__*`) are not Claude-Code-only — they are MCP server tools that can be configured at the runtime layer of any MCP-capable backend (Claude Code, Pi.dev, OpenCode). The skill calls them directly when listed as available; if not listed, persona 5 skips gracefully. This avoids both `ToolSearch` and a hard dependency.

### 3. Convergence looping is the orchestrator's job

- Under sdlc-orchestrator: the `review_plan` MCP tool wraps this skill with severity gating + adaptive caps. The skill emits a verdict; the orchestrator reads it and loops or stops per its own contract. No new skill needed.
- Under Claude Code without orchestrator: the user re-triggers the skill manually until the verdict is CONVERGED. Same workflow as today's 2-10 sequential runs but with an explicit stop signal instead of guesswork.

This is a deliberate scope cut from earlier iterations of this plan. The previous "plan-review-loop" skill duplicated infrastructure the orchestrator already owns; deleting it keeps the architecture clean.

## Affected Files

- Files to modify: **none**
- New files to create:
  - `skills/plan-review-personas/SKILL.md`

Existing `skills/plan-review/SKILL.md` is **not** modified — it stays as the fast single-pass reviewer.

## Acceptance Criteria

- [ ] `skills/plan-review/SKILL.md` is byte-for-byte unchanged (`git diff` clean).
- [ ] `skills/plan-review-personas/SKILL.md` exists with frontmatter `name: plan-review-personas` and all five triggers in its description: `"personas review the plan"`, `"multi-persona review"`, `"deep review the plan"`, `"thorough plan review"`, `"adversarial review of the plan"`.
- [ ] **Portability bar (grep check):** `grep -E 'Agent\(|Skill\(|ToolSearch|TaskCreate|ExitPlanMode' skills/plan-review-personas/SKILL.md` returns **no matches**. This is the hard gate — if it fails, the skill is not portable and must be rewritten before shipping.
- [ ] On a real plan in `plans/` (e.g., `sdlc-orchestrator.md`), one invocation of `plan-review-personas` runs all applicable personas sequentially and ends with one of `CONVERGED`, `NEAR-CONVERGED`, or `NOT CONVERGED` printed to the user.
- [ ] After that invocation, exactly one new Review Log entry is appended, with fields in this exact order: `**Verdict:**`, `**Personas run:**`, `**Flaws found:**`, `**Changes made:**`, `**Acknowledged (won't fix):**` (omitted if empty), `**Still open:**`. The Verdict line matches the pinned regex `^\*\*Verdict:\*\* (CONVERGED|NEAR-CONVERGED|NOT CONVERGED)$`.
- [ ] On a plan that names a real library (e.g., `react@18`), persona 5 either calls `mcp__plugin_context7_context7__resolve-library-id` directly (if the tool is listed as available) OR returns `Skipped — no library inspection tool available in this runtime` (if not). It does NOT call `ToolSearch`.
- [ ] On a plan that names no libraries, persona 5 returns `No new critical flaws` with no library lookups.
- [ ] `implementation-review` invoked against a plan whose Review Log contains the new Verdict / Personas run / Acknowledged lines runs to completion without parser-style failures (additive change — no existing field reshaped).
- [ ] Trigger routing: `"review this plan"` still routes to `plan-review` (untouched); `"deep review the plan"` routes to `plan-review-personas`. Note: substring overlap (`"review the plan"` ⊂ `"deep review the plan"`) means routing depends on host-model judgment; the user can disambiguate by typing the verbatim trigger if needed.
- [ ] **Regression check behavior:** on a plan crafted so that the first auto-applied fix triggers a new critical finding via a different persona's lens, the skill loops the regression check (re-read affected region → re-evaluate → re-fix) at most 2 times. After 2 cycles, any leftover criticals appear under `**Still open:**` and the skill exits with `NOT CONVERGED` rather than spinning forever.
- [ ] **Acknowledged list survives invocations:** on a plan whose prior Review Log already contains `**Acknowledged (won't fix):**` bullets, the next invocation reads those bullets into the dedup list before persona 1 runs, and no persona re-flags them in its findings.

## Tests

- Test type: manual end-to-end via the skill harness — no automated test framework exists in this repo.
- Tests to run:
  - On `plans/sdlc-orchestrator.md`: trigger `plan-review-personas`, observe sequential persona sections in the output, observe verdict, inspect appended Review Log entry against the pinned regex.
  - Run the portability grep check on the new SKILL.md — must return empty.
  - Create a throwaway weak plan in `plans/` that references an outdated library version (e.g., `react@16`). Trigger `plan-review-personas`. Confirm persona 5 either calls context7 directly OR skips with the documented message — never calls `ToolSearch`.
  - Run `implementation-review` against the same plan after review; confirm no failures parsing the augmented Review Log.
  - Trigger `plan-review` (the original) on any plan and confirm it still produces the legacy Review Log format with no Verdict line — proves the original skill is untouched.
  - On a plan whose Review Log already has `**Acknowledged (won't fix):**` entries, trigger `plan-review-personas` and confirm those findings are NOT re-flagged by any persona.
- Tests to add: none (no automation harness).

## Decisions Log

| Decision | Chosen | Alternatives Considered | Why |
|----------|--------|------------------------|-----|
| Preserve existing `plan-review`; add NEW `plan-review-personas` skill | New skill alongside the old one | Rewrite existing `plan-review` in place | User directive to preserve existing skills. Side-by-side gives a fast single-pass option AND a deep multi-persona option, picked by trigger phrase. |
| Portability bar: skills use only `read / write / edit / bash` | Match `sdlc-orchestrator.md` rule (lines 84, 95, 248): no `TaskCreate`, `ExitPlanMode`, `Skill(`, `Agent(`, `ToolSearch` in skill body | Allow `Agent`-based fan-out under Claude Code; build a Claude-Code-only variant + a portable variant | The user's full architecture (Pembina + sdlc-orchestrator + Pi.dev / OpenCode) explicitly requires skills to run under cheap-model backends. A Claude-Code-only skill blocks the cost-routing goal and creates a fork the user explicitly rejected. Portable-from-day-one is one skill body, not two. |
| Personas run sequentially inside one skill body, not as parallel subagents | Sequential | `Agent` fan-out with `subagent_type=Explore` | `Agent` is Claude-Code-only — fails the portability bar. Parallelism is the orchestrator's job (it wraps the skill and runs it N times in parallel sub-sessions when it lands). Under cheap-model backends the cost difference between sequential and parallel is negligible; wall-clock is the trade-off, and that's an orchestrator concern, not a skill concern. |
| No `plan-review-loop` skill | Drop the loop wrapper entirely | Build a separate loop skill that calls `plan-review-personas` via `Skill` tool | The orchestrator already owns severity-gated loops + adaptive caps per `sdlc-orchestrator.md` M2 — a separate loop skill duplicates that infrastructure. And the loop wrapper would have to use the `Skill` tool, which fails the portability bar. Under Claude Code without the orchestrator, the user re-triggers manually — same flow as today's 2-10 sequential runs but with an explicit stop signal. |
| Context7 is acceptable in the skill body (not Claude-Code-only) | MCP tools called directly by name when listed as available | Require `ToolSearch` to load schemas first; skip context7 entirely | Context7 is an MCP server, configurable at the runtime layer of any MCP-capable backend (Claude Code, Pi.dev, OpenCode). `ToolSearch` is the Claude-Code-only quirk to fix, not context7 itself. Calling the tool directly and degrading gracefully when it's not listed keeps the skill portable. |
| Verdict line format is pinned to a literal regex | `^\*\*Verdict:\*\* (CONVERGED\|NEAR-CONVERGED\|NOT CONVERGED)$` | Free-form prose with substring match | Substring match is fragile ("NOT CONVERGED" contains "CONVERGED"). Pinned format gives any future orchestrator loop a clean parse contract. |
| Review Log is additive in the new skill only | New `**Verdict:**`, `**Personas run:**`, `**Acknowledged (won't fix):**` lines; existing fields kept verbatim | Restructure the Review Log block; retrofit the original `plan-review` | Downstream skills (`implementation-review`, `create-docs`) read existing fields contextually; additive keeps them working. Leaving the original `plan-review` alone respects the user's preservation directive. |
| Small-plan persona subset = {1, 3, 5} | Always include Architecture, Devil's Advocate, Library API; skip Security and Feasibility/Ops unless plan touches auth/data/infra | Run all 5 always; run only persona 3 for small plans | Devil's Advocate carries over-engineering (the most common flaw per existing skill's Rules). Library API is cheap when no libraries are named (early-exits). Architecture is the baseline correctness lens. Skipping Security/Ops on small plans matches existing skill depth calibration. |
| Regression check re-evaluates in-context, not via re-spawn | Same orchestrator re-reads affected plan regions through the originating persona's lens; cap inner-iterations at 2 | Re-spawn personas (impossible without `Agent`); skip the check | Same context = zero new tool calls. Cap prevents infinite churn on a fix that triggers a new fix. Addresses the user's "each fix introduces new issues" complaint without compromising portability. |
| Acknowledged-not-fix list survives across invocations | New Review Log line `**Acknowledged (won't fix):**` feeds the dedup list on next read | Re-flag the issue every invocation and let the user dismiss each time | Without an escape hatch, a stubborn persona finding bounces forever and the user can never reach CONVERGED. Persisting acknowledgement in the plan file matches the existing "resolved issues" dedup pattern (lines 123-126 of original `plan-review/SKILL.md`). |

---

**Implementation handoff:** the source-of-truth design at `/Users/amirinns/.claude/plans/refer-the-https-opencode-ai-and-adaptive-conway.md` describes persona lenses and the output envelope shape but assumes Claude-Code-only parallel fan-out — this plan deliberately diverges to honour the portability contract. Persona prompt text is authored inline in `plan-review-personas/SKILL.md`. Read this plan's Review Log before coding to see what's already been resolved.

## Review Log

### Review 1 — 2026-06-09
**Flaws found:** 5
**Changes made:**
- Switched from rewriting `skills/plan-review/SKILL.md` to creating a new skill `skills/plan-review-personas/SKILL.md` alongside it — **Reason:** user directive to preserve existing skills.
- Added an explicit triggers list for the new skill (5 trigger phrases) — **Reason:** without distinct triggers, the user can't route to the new skill since `plan-review` keeps its existing triggers.
- Pinned the Verdict line format to a literal regex `^\*\*Verdict:\*\* (CONVERGED|NEAR-CONVERGED|NOT CONVERGED)$` — **Reason:** substring matching would misread "NOT CONVERGED" as "CONVERGED".
- Clarified that `plan-review-loop` invokes `plan-review-personas` specifically (not the legacy `plan-review`) — **Reason:** only the new skill writes the Verdict line the loop reads.
- Noted that the source-of-truth design doc lacks ready-to-paste persona prompt text — **Reason:** prevents the implementer from stalling when they discover the doc only has a lens table.
- Added an MCP-tool-availability note for `Explore` subagents — **Reason:** prevents implementer second-guessing whether persona 5 is viable.

**Still open:**
- Persona prompt quality is the dominant implementation risk and cannot be resolved at plan time — flagged for the implementer's attention.

### Review 2 — 2026-06-09
**Flaws found:** 5
**Changes made:**
- Specified that `plan-review-loop` invokes `plan-review-personas` via the `Skill` tool with the plan path as args — **Reason:** the prior plan said "invoke" without naming the mechanism.
- Added explicit `ToolSearch` step in persona 5's prompt to load deferred context7 tool schemas before invoking them — **Reason:** context7 tools were listed as deferred in this environment and would fail without a schema load.
- Added fix attribution + conflict resolution rule: each finding tagged with source persona; conflicting fixes resolved by picking smallest plan delta and logging the rejected alternative — **Reason:** two personas can flag the same area with contradictory fixes; the prior plan didn't say how the orchestrator picks.
- Tied the regression-check spawn list to persona tags on applied fixes — **Reason:** prior plan said "re-spawn only personas whose concern area was touched" with no mechanism for determining which area was touched.
- Added an `**Acknowledged (won't fix):**` Review Log line and corresponding dedup-list semantics — **Reason:** without an escape hatch, a stubborn persona finding burns the iteration cap.
- Added a stall-guard to `plan-review-loop` — **Reason:** belt-and-suspenders for the acknowledged-list mechanism.
- Switched persona prompt content from "full plan text or path" to "path only" with an instruction to Read — **Reason:** inlining a long plan in five parallel subagent prompts wastes input tokens.
- Added explicit acceptance criterion for persona 5's tool-use stream — **Reason:** without this, "context7 worked" was unverifiable.
- Noted the trigger substring overlap — **Reason:** routing is host-model judgment, not deterministic.

**Still open:**
- Persona prompt quality (carried over from Review 1).
- Trigger routing in practice depends on host-model matching.

### Review 3 — 2026-06-09 (architecture pivot — portability)
**Flaws found:** 1 architectural (cascading)
**Changes made:**
- **Pivoted from `Agent`-based parallel fan-out to sequential personas in one skill body.** — **Reason:** the user surfaced that `coding-agent-skills` is the **portable primitive layer** of a three-layer system (`coding-agent-skills/` → `sdlc-orchestrator` MCP → Pembina persona / playbook layer at `~/Projects/sebaik-baik-pembina/`). The orchestrator plan (`coding-agent-skills/plans/sdlc-orchestrator.md` lines 84, 95, 248) explicitly grep-bans `TaskCreate|ExitPlanMode|Skill(|Agent(` from skill bodies so skills run under Pi.dev / OpenCode / Codex backends on cheap models. Review 1+2's Claude-Code-only design violated that bar across the board (`Agent`, `Skill`, `ToolSearch` all forbidden). The pivot drops parallelism inside the skill — parallelism is now the orchestrator's job when `sdlc-orchestrator` lands (it will run the skill N times in parallel sub-sessions). Under Claude Code today the personas run sequentially in one context, which is slower wall-clock but the same correctness.
- **Dropped the `plan-review-loop` skill entirely.** — **Reason:** the loop wrapper would have used the `Skill` tool, which fails the portability bar. Worse, the orchestrator already owns severity-gated loops and adaptive caps per `sdlc-orchestrator.md` M2 — a separate skill duplicated infrastructure the orchestrator will provide. Under Claude Code without orchestrator, the user re-triggers manually if NOT CONVERGED — same workflow as today's 2-10 sequential runs but with an explicit stop signal instead of guesswork.
- **Removed the `ToolSearch` instruction from persona 5.** — **Reason:** `ToolSearch` is Claude-Code-only. Replaced with a capability probe: if `mcp__plugin_context7_context7__resolve-library-id` is listed as available, call it directly; if not, persona 5 returns `Skipped — no library inspection tool available in this runtime`. Context7 is an MCP server (portable across MCP-capable backends), so calling it by name is fine; only the deferred-tool loading mechanism was Claude-Code-specific.
- **Reframed the regression check as in-context re-evaluation, not re-spawn.** — **Reason:** without `Agent`, re-spawn isn't possible. The same orchestrator now re-reads affected plan regions through the originating persona's lens. Cap inner iterations at 2 to prevent infinite churn. Cost: zero new tool calls.
- **Added a portability grep check to Acceptance Criteria.** — **Reason:** the bar needs to be testable. `grep -E 'Agent\(|Skill\(|ToolSearch|TaskCreate|ExitPlanMode' skills/plan-review-personas/SKILL.md` must return empty before the skill ships.
- **Removed all loop-related Acceptance Criteria and Tests** — **Reason:** there is no loop skill to test.

**Still open:**
- Persona prompt quality remains the dominant implementation risk (carried over from Reviews 1 + 2).
- Sequential execution is slower wall-clock than the original parallel design. Acceptable trade-off for portability; the orchestrator will recover parallelism when it ships. Watch for user pain on long plans under Claude Code-only mode in the interim.
- Trigger routing depends on host-model matching (carried over from Review 2).

### Amendment — 2026-06-09 (caller-contract clarification)
**Changes made:**
- Added a "Parseable section boundaries" instruction to Approach step 3: each persona block wrapped in `<!-- persona:N name -->` … `<!-- /persona:N -->` markers — **Reason:** keeps the door open for `sdlc-orchestrator` MCP server to choose between **one Pi.dev session running personas sequentially** (simpler, cheaper per-call) and **N Pi.dev sessions running one persona each in parallel** (faster wall-clock) without any change to this skill file. The skill stays the single source of truth for persona prompt text; the orchestrator decides how to slice it at invocation time. Costs nothing in the skill body; saves a future plan-change when the orchestrator lands. No `persona:` arg on the skill itself (would be added later as a 10-line additive change if direct single-persona invocation from Claude Code / OpenCode ever becomes a real use case).

### Review 4 — 2026-06-09
**Flaws found:** 4
**Changes made:**
- Clarified the persona-5 capability-probe semantics — "listed as available" now explicitly means **directly callable without a schema-loading step**, with an explicit note that under Claude Code today (where MCP tools are deferred behind `ToolSearch`) persona 5 will always `Skipped` — **Reason:** the prior wording assumed "listed = callable", but Claude Code's deferred-tool model lists `mcp__plugin_context7_context7__*` while requiring `ToolSearch` to load schemas. Since the portability bar bans `ToolSearch`, persona 5 has no path to context7 under Claude Code today. Without this clarification, the implementer and the user would expect persona 5 to work under Claude Code and be surprised by the skip — and the test on `react@18` would be misread as a failure rather than expected portable behavior.
- Defined what "one regression iteration" means inside Approach step 7 — **Reason:** the prior "cap at 2" was uninterpretable. With chained findings (fix A → reveals B → fix B → reveals C…), 2 could mean 2 fixes, 2 re-reads, or 2 personas-touched. Pinning iteration = one full cycle of (re-read → re-evaluate → re-fix) makes the cap testable and prevents the skill from either (a) terminating after one re-read or (b) chasing chained findings indefinitely.
- Added an explicit user-controlled rule for how findings reach `**Acknowledged (won't fix):**` — **Reason:** prior reviews added the field and the dedup-list read path but never specified how findings ENTER the list. The skill needs a transition rule or the list stays empty forever, defeating the escape-hatch purpose. User-controlled (via prior-Review-Log edit or in-conversation "acknowledge: …" instruction) is the only rule consistent with the skill's "find flaws, don't decide which ones don't matter" mandate — auto-promoting after N appearances would steal user judgment.
- Added two new Acceptance Criteria covering the regression-check 2-cycle cap and the Acknowledged-list dedup behavior — **Reason:** both behaviors were promised in Approach but had no testable acceptance bullet. Without them, an implementer could ship the skill without the regression cycle or the dedup logic and still pass the acceptance gate.

**Still open:**
- Persona prompt quality remains the dominant implementation risk (carried over from Reviews 1, 2, 3). The plan defers prompt authoring to the implementer; this cannot be resolved at plan time.
- Sequential execution wall-clock cost on long plans under Claude Code (carried over from Review 3).
- Trigger routing depends on host-model substring matching (carried over from Review 2).
- Plan filename still reads `plan-review-parallel-personas.md` despite the Review 3 pivot to sequential execution — cosmetic, not blocking, leaving as-is to avoid churn.
