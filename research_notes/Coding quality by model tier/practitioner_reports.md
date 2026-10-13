# Coding quality by model tier: practitioner reports and vendor guidance

Research date: 2026-10-13. Model generations change the tier gap, so every finding names its model versions and source date. Labels used below:
- [VENDOR] means official guidance or vendor-reported benchmark.
- [MEASURED] means a controlled test with stated method (sample size noted).
- [ANECDOTE] means a single practitioner report, forum comment, or uncontrolled personal test.
- [EDITORIAL] means third-party blog opinion or unverified estimate.

Current lineups as of 2026-10-13 (from sources below):
- Anthropic API: Opus 5.5, Sonnet 5.5, Haiku 5.5, plus a "Fable" tier above Opus. Older but still cited: Opus 4.8, Sonnet 5, Sonnet 4.6, Haiku 4.5.
- OpenAI Codex: GPT-6.1 Sol (default for complex work), GPT-6 Astra (most capable), GPT-6 Luna (focused, high-volume). gpt-5.5 retires from Codex on 2026-10-14. Older: gpt-5-codex-mini, gpt-5.1-codex-mini, gpt-5.4-mini.
- Google: Gemini 3 Pro and Gemini 3 Flash (Gemini CLI, Dec 2025 announcement). I did not find newer Gemini coding guidance.

## What do coding tool vendors recommend?

### Takeaway
Every vendor ships a tiered default. Anthropic positions Sonnet for "daily coding", Opus for "complex reasoning" and Haiku for "simple tasks", and offers opusplan (Opus plans, Sonnet executes). OpenAI and Google route the small tier to well-specified, high-volume or lighter work, and Cursor now routes per request with a classifier. Vendor guidance is framed by task difficulty and how well the task is specified, not by task category lists.

### Cited findings

Anthropic (Claude Code docs, fetched 2026-10-13):
- [VENDOR] Alias definitions: `sonnet` "Uses the latest Sonnet model for daily coding tasks"; `opus` "Uses the latest Opus model for complex reasoning tasks"; `haiku` "Uses the fast and efficient Haiku model for simple tasks"; `opusplan` "Special mode that uses `opus` during plan mode, then switches to `sonnet` for execution", described as pairing "Opus's reasoning for planning with Sonnet's efficiency for execution." A `fable`/`best` alias exists "for your hardest and longest-running tasks." — [Claude Code model config](https://code.claude.com/docs/en/model-config)
- [VENDOR] Default model on Pro, Max, Team, Enterprise and Anthropic API is Opus 5.5. On the Anthropic API the aliases resolve to Opus 5.5 / Sonnet 5.5 / Haiku 5.5. On Bedrock and Google Cloud, `sonnet` still resolves to Sonnet 4.5 and `haiku` to Haiku 4.5. So "Sonnet" in Claude Code means different model generations depending on provider. — [Claude Code model config](https://code.claude.com/docs/en/model-config)
- [VENDOR] Subagents inherit the session model unless a model is set: "Switch to Opus before Claude delegates research or test runs to one of them, and that work runs on Opus too. To keep a custom subagent on a smaller model, set `model` in its definition." Resolution order: per-invocation `model` parameter, then subagent frontmatter, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the main conversation's model. — [Claude Code model config](https://code.claude.com/docs/en/model-config); [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [VENDOR] The subagents page says subagents help "Control costs by routing tasks to faster, lower-cost models like Haiku." Built-in model assignments in current docs: Explore uses "the main conversation's model" (or the `opus` model when the main session runs Fable on a subscription/Console), Plan inherits, general-purpose uses `CLAUDE_CODE_SUBAGENT_MODEL` if set else the main model, `claude-code-guide` runs on Haiku, `statusline-setup` on Sonnet. — [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- Conflict worth noting: earlier Claude Code docs and third-party guides describe Explore as "a fast, read-only agent" on Haiku (search snippet of [Claude Code subagents](https://code.claude.com/docs/en/subagents); [tembo.io guide](https://tembo.io/blog/claude-code-subagents)). The current page says Explore follows the main model. Anthropic appears to have moved Explore off Haiku. I did not find a changelog entry stating why.
- [VENDOR, via press] Sonnet 5.5 launched 2026-09-28. Reported claims: about 30% faster than Sonnet 5, up to 30% lower typical cost through fewer tokens per task, $2/$10 per million tokens. A Chinese-language report says Anthropic's benchmarks show Sonnet 5.5 beating Opus 5.5 on agentic coding. I did not reach the primary Anthropic page. — [letsdatascience](https://letsdatascience.com/news/anthropic-releases-claude-sonnet-55-with-faster-responses-an-95c4c0b5); [ifeng](https://tech.ifeng.com/c/8wo0tquWeB4); [itdaily](https://itdaily.com/news/software/claude-sonnet-5-5/)
- [VENDOR, via press] Haiku 5.5 was announced alongside Sonnet 5.5 and reported shipped by 2026-10-07 as "the first Haiku with effort levels", 72.4% OSWorld, positioned as a lightweight companion for agent workloads. Sources conflict on ship date and on pricing. Claude Code docs confirm "A Haiku 5.5 request costs more per token when its prompt is longer than 100K tokens." — [AI Catchup newsletter 2026-10-07](https://aicatchup.com/newsletter/2026-10-07); [gradually.ai](https://www.gradually.ai/en/ai-models/claude-haiku-5-5/); [Claude Code model config](https://code.claude.com/docs/en/model-config)
- [VENDOR via third party] Sonnet 5 (released 2026-06-30) vs Opus 4.8, figures attributed to Anthropic's announcement and system card: SWE-Bench Pro 63.2% vs 69.2%; Terminal-Bench 2.1 80.4% vs about 79%; OSWorld-Verified 81.2% vs 81.7%. Recommendation in the article (editorial): Sonnet 5 as default for everyday coding, Opus 4.8 for "the hardest multi-step coding problems" and accuracy-critical work. Publisher sells an AI app builder. — [Emergent, updated 2026-07-01](https://emergent.sh/learn/claude-sonnet-5-vs-opus-4-8)

OpenAI (Codex):
- [VENDOR] Current Codex models page: "For complex coding and agentic workflows, use GPT-6.1 Sol"; "Choose Astra when a task needs the strongest capability across steps and tools"; "Choose Luna for specific, high-volume tasks when you know what a good result looks like" (examples: summarization, extraction, focused coding). "Replace `gpt-5.4-mini` with `gpt-6-luna`." Reasoning effort: Light "suits quick, well-scoped tasks"; High and Extra High "suit difficult work with multiple steps, sources, or tradeoffs." "Most tasks do not need Max or Ultra." No guidance on picking models for subagents. — [OpenAI Codex models](https://learn.chatgpt.com/docs/models.md)
- [VENDOR, older] Before the GPT-6 rollout, the Codex page said start with `gpt-5.5` and use `gpt-5.4-mini` "for lighter coding tasks or subagents". The GPT-5.4 mini release targeted "codebase exploration, large-file review, processing supporting documents, and other less reasoning-intensive subagent work." — search summary of [OpenAI Codex models](https://developers.openai.com/codex/models.md) and [releases.sh](https://releases.sh/release/rel_mUjL3xp9-AE_Jxs5q4L54)
- [VENDOR, Nov 2025] GPT-5-Codex-Mini was positioned for "easier software engineering tasks" and when near rate limits. Codex suggests switching at 90% of limits. SWE-bench Verified 71.3% vs 74.5% for GPT-5-Codex, with "4x more usage." — [Neowin](https://www.neowin.net/news/openai-introduces-gpt-5-codex-mini-a-cost-efficient-coding-model-for-developers/)

Google (Gemini CLI):
- [VENDOR] Dec 17, 2025: Gemini CLI auto-routing reserves Gemini 3 Pro for harder reasoning and sends simpler operations to Gemini 3 Flash. Flash costs "less than a quarter the cost of Gemini 3 Pro" and Google reports 78% SWE-bench Verified for Flash, above Gemini 3 Pro on that benchmark. — [Google Developers Blog](https://developers.googleblog.com/en/gemini-3-flash-is-now-available-in-gemini-cli/)
- [VENDOR via mirror] Per Gemini CLI docs mirror, `/model` and `--model` do not change the model sub-agents use, and internal utility calls fall back silently to 2.5 Flash-Lite, 2.5 Flash, 2.5 Pro. — [mintlify mirror of Gemini CLI docs](https://www.mintlify.com/google-gemini/gemini-cli/concepts/models)

Cursor:
- [VENDOR] Auto now runs through Cursor Router, an ML classifier per agent request that "routes by task type and complexity. Simple requests go to fast, cost-efficient models. Complex work goes to frontier models." The model can change between turns. Modes are Intelligence, Balance (default for new users) and Cost. Cursor staff: "We don't keep a separate public list of exactly which models are in Auto right now." Router page says Teams/Enterprise only; a third-party post says individual plans follow. — [Cursor router help](https://cursor.com/help/models-and-usage/cursor-router); [Cursor forum](https://forum.cursor.com/t/which-models-are-behind-cursor-auto-mode/167010); [startdebugging.net, Jul 2026](https://startdebugging.net/2026/07/cursor-router-makes-auto-a-per-request-model-decision/)

Aider:
- [MEASURED, vendor benchmark] Sep 2024: Architect/Editor split. A reasoning model plans and a separate model writes file edits. o1-preview as Architect with DeepSeek or o1-mini as Editor scored 85% on Aider's code editing benchmark (SOTA then). Motivation was that reasoning models plan well but produce badly formatted edits. — [aider.chat architect post](https://aider.chat/2024/09/26/architect.html)
- [ANECDOTE, secondhand] April 2025: o3 architect + GPT-4.1 editor reportedly hit 83% on Aider Polyglot at lower cost than o3 alone. Only confirmed via third-party review. — [DataLearner](https://www.datalearner.com/en/blog/1051755633012011)
- Aider also has a `--weak-model` setting for commit messages and chat summarization. — [aider.chat](https://aider.chat/2024/09/26/architect.html) (weak-model detail from secondary guides, not verified on the official page)

### Inferences
- Vendors converge on three routing axes: difficulty (multi-step, cross-file), specification clarity ("when you know what a good result looks like"), and volume/latency. None publish a fixed list of "Haiku-safe" task categories.
- The "plan with big, execute with mid" pattern is officially productized by Anthropic (opusplan) and Aider (architect/editor). Small tiers are officially aimed at exploration, read-only search, docs lookups and well-scoped edits.
- The Sonnet/Opus gap is narrow and possibly inverted on some agentic benchmarks in the 5.x generation (Sonnet 5.5 vs Opus 5.5 vendor claims). Routing rules built on 4.x experience may over-allocate Opus.
- Claude Code's own move of Explore from Haiku to the session model hints that Anthropic found exploration quality matters, but this is my inference, not a stated reason.

### Gaps
- Primary Anthropic announcement pages for Sonnet 5.5 and Haiku 5.5 were not fetched. Benchmark numbers for those come from press summaries.
- No official Anthropic statement on why Explore stopped defaulting to Haiku.
- No current Google guidance for Gemini models newer than Gemini 3; no official Sourcegraph/Amp, Cline or Factory model-routing guidance was collected in this pass.
- Cursor does not disclose the router's model pool or its classifier accuracy.

## What do experienced developers report on where smaller models are fine and where they fail?

### Takeaway
The practitioner consensus, mostly anecdotal, is Sonnet as default, Opus for hard debugging, wide refactors, long autonomous runs and thorough PR review, and Haiku only for small, well-bounded, repetitive tasks. Dissent exists in both directions. Some report Haiku outperforming Opus on a mechanical migration, and some say Haiku disappoints even on small tasks.

### Cited findings
- [ANECDOTE] HN thread "Changes to GitHub Copilot individual plans" (about May 2026, Haiku 4.5 / Sonnet 4.6 / Opus 4.x era). Quoted comment: "Haiku is most definitely not fine for the code bases that I work on." Sonnet "is probably fine for most daily tasks" but Opus is needed for "that pesky bug you've been chasing" and to "thoroughly review your PR." — [HN item 47856810](https://news.ycombinator.com/item?id=47856810)
- [ANECDOTE] Same thread, Aurornis: "I don't know how anyone could believe that Haiku is useful for most engineering tasks." Gives Haiku small, well-bounded tasks to save plan limits and is "often disappointed." krzyk: "I use Haiku frequently, and for my codebase it is working fine" for small, repetitive tasks, but does not let models handle large work or refactorings. timr: finds flaws in nearly all Haiku output but considers pricier models not worth the cost, and asks for evidence from those who say Haiku fails. — [HN item 47856810](https://news.ycombinator.com/item?id=47856810)
- [ANECDOTE] HN "Claude Sonnet 5" thread (about July 2026, 1,266 points, 784 comments). One commenter said Opus repeatedly broke a large Tailwind migration by refactoring and changing the design as components got complex, and Haiku completed it "almost without intervention." Another suggested "spec/plan with Opus, and have Sonnet implement." — [HN item 48736605](https://news.ycombinator.com/item?id=48736605)
- [ANECDOTE] Same thread: several users argue Opus at low effort beats Sonnet at any effort. phainopepla2 read the Sonnet 5 system card's agentic benchmarks as showing Opus at low effort beats Sonnet 4.6 at any level at lower cost. Jcampuzano2: "I'm struggling to understand why I'd ever use this instead of just using a lower effort level for opus." — [HN item 48736605](https://news.ycombinator.com/item?id=48736605)
- [ANECDOTE] Same thread, overreach by the large model: itopaloglu83, "I don't know why Opus would try to create an entire library when I told it specifically to do something simple." Others report Opus reading tens of thousands of lines of Terraform for a file-move question and decompiling JARs during investigations. — [HN item 48736605](https://news.ycombinator.com/item?id=48736605)
- [ANECDOTE] Same thread: sixtyj found GLM-5.2 "made a lot of subtle mistakes that needed to be corrected by hand," while Sonnet 4.6 caught them on a second pass. port11 found Sonnet 4.6 "not much better than M3 or Kimi 2.7." — [HN item 48736605](https://news.ycombinator.com/item?id=48736605)
- [EDITORIAL] Blog guides (2026) place multi-file refactors with Opus. Example claim: in a 15-file auth refactor, Sonnet handles files one at a time and can miss a renamed method breaking a call site elsewhere. Same guides say bug fixes, feature additions, test writing and code review give comparable results on both. Model versions mixed (4.6, 4.8, 5). — [fast.io](https://fast.io/resources/claude-sonnet-vs-opus-comparison/); [nxcode](https://www.nxcode.io/resources/news/claude-opus-or-sonnet-for-coding-decision-guide-2026)
- [ANECDOTE, small self-run test] Planted-bug test: Sonnet and Haiku both caught all four planted bugs and both left the clean function alone. Opus 4.8/4.7 compared. — [Medium, ariaxhan](https://medium.com/@ariaxhan/opus-4-8-vs-4-7-vs-sonnet-vs-haiku-when-the-expensive-model-is-worth-it-44892a75d5c5)
- [ANECDOTE] Personal vibe-coding test of Sonnet 4.6 vs Opus 4.6 found them close, with Sonnet 4.6 better on game UI smoothness. Single small test. — [Medium/Codex](https://medium.com/codex/i-tested-sonnet-4-6-vs-opus-4-6-for-vibe-coding-heres-the-winner-4165870c8a3a)
- [EDITORIAL] Common routing pattern in 2026 blogs: Haiku for triage, simple edits and lightweight review; Sonnet for implementation and tests; Opus for planning and hard debugging. — [ayautomate](https://www.ayautomate.com/blog/opus-vs-sonnet-vs-haiku); [ai-cost-estimator](https://ai-cost-estimator.com/blog/claude-opus-vs-sonnet-vs-haiku-which-model-which-coding-task-2026)
- [EDITORIAL] Third-party guidance for gpt-5-codex-mini: scaffolding, repetitive generation, small refactors, quota-constrained work on mini; comprehensive reviews, long autonomous tasks and complex refactors on full Codex. — [CometAPI](https://www.cometapi.com/?p=27987)

### Inferences
- Task types repeatedly named as safe for the small tier: mechanical, well-specified edits (renames, migrations with a clear pattern), repetitive changes, boilerplate, search/triage, commit messages. Task types repeatedly named as needing the top tier: chasing hard bugs, cross-file refactors where call sites must stay consistent, thorough PR review, long autonomous runs.
- The Tailwind anecdote suggests the frontier model can be worse on mechanical work because it overreaches (redesigns, over-explores). A router should consider "too much model" a failure mode, not only "too little."
- The HN debate shows the outcome depends on codebase and workflow, and few commenters give enough detail to generalize. Treat all of it as directional.

### Gaps
- I found no Reddit thread (r/ClaudeAI, r/ChatGPTCoding, r/LocalLLaMA) with confirmed date and content in this pass. Search results did not surface them. The reddit-recon skill could close this gap.
- No X/Twitter posts collected.
- No practitioner reports yet that specifically compare Sonnet 5.5 or Haiku 5.5 against Opus 5.5 on real codebases. Both shipped within the last three weeks.

## What hidden costs do smaller models carry?

### Takeaway
The best measured evidence (one controlled 90-trial study) shows cheaper models can burn more tokens through compile-repair loops and sometimes skip validation, so the real saving is smaller than the rate card. The size of the quality hit varied a lot by vendor. False success claims and unchecked assumptions are reported for all tiers, including Opus.

### Cited findings
- [MEASURED, n=3 per cell, no significance tests] Siemens paper (arXiv, 2026-08-22), reported 2026-08-25: 90 multi-turn coding-agent trials, 5 spec formats × 6 models × 3 trials, building a 7-component, 25-route API with up to 50 turns. Sonnet 4.6 used about 640K tokens and scored 8.42/10; Haiku 4.5 used about 735K tokens and scored 6.50. Rate-card saving of 67% fell to about 62% after token counts. GPT-5 about 248K tokens (7.08) vs GPT-5-mini about 225K (6.72), about 82% token-adjusted saving for a 0.36-point quality loss. Gemini 2.5 Pro 6.07 vs Flash 6.35. — [beri.net](https://www.beri.net/article/coding-agent-spec-format-token-inversion-machine-checkable-contracts)
- [MEASURED] Same study, end-to-end demo run success: Sonnet 4.6 100% of trials, Haiku 4.5 80%, GPT-5 53%, GPT-5-mini 40%, Gemini 2.5 Pro 20%, Gemini 2.5 Flash 0%. Spec format mattered more for weaker models (quality spread 0.83 to 2.42) than for frontier (0.17 to 0.92). Gemini Flash implemented 33% of routes from prose specs and 100% from TypeScript interface contracts. Cheaper models often used more tokens via repeated compile-repair loops, and some skipped validation entirely. — [beri.net](https://www.beri.net/article/coding-agent-spec-format-token-inversion-machine-checkable-contracts)
- Limitations of that study: one system, author-written specs, Sonnet 4.6 as judge of its own family's output, judge-vs-automated completeness correlation r=0.63, security not measured. — [beri.net](https://www.beri.net/article/coding-agent-spec-format-token-inversion-machine-checkable-contracts)
- [MEASURED, cited survey] Stack Overflow 2025 developer survey: 66% cited AI output that is "almost right, but not quite"; 45% said debugging AI code takes more time than expected. Not tier-specific. — cited in [Unblocked, 2026-06-09](https://getunblocked.com/blog/model-routing-coding-agents/)
- [MEASURED, cited paper] Runs on the same SWE-bench Verified task varied up to 30x in total tokens, and models' self-predicted cost correlated at no more than 0.39 with actual cost. — cited in [Unblocked](https://getunblocked.com/blog/model-routing-coding-agents/)
- [EDITORIAL] Unblocked argues a Haiku 4.5 call costs about a fifth of an Opus call, so a few retries plus a debugging session can exceed one clean Opus pass. This is reasoned, not measured, and Unblocked sells a context product. — [Unblocked](https://getunblocked.com/blog/model-routing-coding-agents/)
- [ANECDOTE] False success and unchecked assumptions (Opus 4.8 / Sonnet 5 era): anygivnthursday describes the model saying "nothing will break," spending tokens on a migration, hitting a wall, then admitting it assumed a key fact without checking. Terretta reports the model claiming it had "read" a whole file after receiving only the first 60 lines. c0m47053: "context length can creep up, and that is where opus tends to get expensive." — [HN item 48736605](https://news.ycombinator.com/item?id=48736605)
- [ANECDOTE] Run-to-run variance: springtimesun saw results "all over the map even across versions of the same model"; benny_s and anygivnthursday reported opposite experiences with Opus 4.8 at the same time. — [HN item 48736605](https://news.ycombinator.com/item?id=48736605)
- [VENDOR] Haiku 5.5 charges more per token above 100K prompt tokens, so long-context exploration on Haiku is not as cheap as the base rate suggests. — [Claude Code model config](https://code.claude.com/docs/en/model-config)
- [EDITORIAL] Blog claim that Opus shows lower retry rates on autonomous runs of 30+ minutes. No data shown. — [nxcode](https://www.nxcode.io/resources/news/claude-opus-or-sonnet-for-coding-decision-guide-2026)

### Inferences
- Hidden cost has two parts: extra tokens from repair loops (measured, modest) and lower completion/quality (measured, large for Haiku 4.5 vs Sonnet 4.6 in one study). Review time and rework were not measured anywhere I found.
- Giving small models machine-checkable specs (typed interfaces, failing tests, lint rules) narrowed the gap the most in the one study. A router should send the small tier work that comes with an automated check.
- Silent "skipped validation" by small models means a router needs an independent verify step, not the subagent's own success report.

### Gaps
- No measured data on human review time or defect escape rate by model tier.
- No measured false-success rate by tier. Reports exist for all tiers, anecdotally.
- The Siemens study used Haiku 4.5 and Sonnet 4.6. The 5.5 generation may differ.

## Team case studies with numbers

### Takeaway
I found no first-party engineering write-up with before/after cost and defect numbers from mixing Claude or GPT tiers in a coding workflow. Available numbers are vendor or blog estimates, an older academic router result, and one controlled study.

### Cited findings
- [MEASURED, academic, GPT-4 era] RouteLLM (ICLR 2025): a trained router kept about 95% of GPT-4 quality while sending about 14-26% of calls to the strong model, cutting cost 75-85% vs always-frontier. Not coding-agent specific. — cited in [Unblocked](https://getunblocked.com/blog/model-routing-coding-agents/)
- [MEASURED, academic] Cascades with early abstention (Caltech, arXiv 2025): across six benchmarks, cost fell 13.0% and error fell 5.0% on average. — cited in [Unblocked](https://getunblocked.com/blog/model-routing-coding-agents/)
- [EDITORIAL] Estimated savings from routing: 40-60% solo developer, 60-80% small team, 80-95% CI/CD. No method shown. — [Developers Digest](https://www.developersdigest.tech/blog/model-routing-strategies-cost-effective-coding-2026); 40-60% vs all-Opus — [Augment Code](https://www.augmentcode.com/guides/ai-model-routing-guide)
- [ANECDOTE, unnamed client] A client cut agent costs from $87K to $24K per month, with only about 25% of the reduction attributed to moving triage to Haiku. Client not named. — [LeanOps](https://leanopstech.com/blog/agentic-ai-cost-runaway-token-budget-2026/)
- [MEASURED, vendor-run, no method] Unblocked's own test: same prompt and model with curated context used 42% fewer tokens, ran 27% faster, made 64% fewer tool calls. Suggests context curation can save as much as tier downgrades. — [Unblocked](https://getunblocked.com/blog/model-routing-coding-agents/)
- [MEASURED] Aider architect/editor (Sep 2024): o1-preview + o1-mini/DeepSeek editor reached 85%, then SOTA, on Aider's edit benchmark. This is the closest public numeric evidence that pairing a strong planner with a cheaper executor holds quality. — [aider.chat](https://aider.chat/2024/09/26/architect.html)

### Inferences
- Rate-card math overstates savings. The one controlled agentic study puts Haiku 4.5 vs Sonnet 4.6 at about 62% saving with a 1.92-point quality loss on a 10-point scale, which is a poor trade for implementation work. GPT-5-mini vs GPT-5 was a much better trade (82% saving, 0.36-point loss).
- The strongest numeric support is for "strong planner, cheaper executor" (Aider, opusplan design), not for "small model does the whole task."

### Gaps
- No named company published defect rates, throughput or review-time data by model tier for coding.
- No case studies yet on Opus 5.5 / Sonnet 5.5 / Haiku 5.5 or GPT-6 Sol / Luna mixes.
