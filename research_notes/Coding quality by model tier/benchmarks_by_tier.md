# Coding benchmark results by model tier within vendor families (as of 2026-10-13)

Scope note on current lineups, as found in sources:
- Anthropic: Opus 5.5 (2026-09-22), Sonnet 5.5 (2026-09-28), Haiku 5.5 (2026-10-07). A separate "Fable" line (Fable 5, 5.1) sits at or above Opus pricing. — [Anthropic news](https://www.anthropic.com/news)
- OpenAI: GPT-5.6 launched 2026-07-09 in three tiers, Sol (flagship), Terra (balanced), Luna (cheapest). GPT-6 Astra (2026-09-03) is a new top tier with only Astra and Astra Pro, no Sol/Terra/Luna equivalents yet. — [qainsights summary](https://qainsights.com/?p=18637); [Vellum on GPT-6 Astra](https://www.vellum.ai/blog/gpt-6-astra-benchmarks-explained). Note: Anthropic's Sonnet 5.5 and Haiku 5.5 pages name "GPT-6 Sol" and "GPT-6 Luna" as comparison models, so GPT-6 mid/small tiers may now exist, but I found no OpenAI primary source for them.
- Google: newest Pro I could confirm is Gemini 3.1 Pro (Feb 2026). Flash has moved faster: 3.5, 3.6 (model card dated 2026-07-21), 3.7 and 3.8 Flash appear on leaderboards. Newest Flash-Lite is 3.5 Flash-Lite. I found no "Gemini 3.6 Pro" or later Pro. — [Gemini 3.6 Flash model card](https://deepmind.google/models/model-cards/gemini-3-6-flash/); [Vals SWE-bench](https://www.vals.ai/benchmarks/swebench)

Benchmark versions have moved. Terminal-Bench is now at 4.0 in vendor launch posts (Anthropic, OpenAI), while Google and independent trackers still report 2.1. SWE-bench Verified has been archived as saturated by Vals.ai.

## What are the published scores per tier on SWE-bench Verified, SWE-bench Pro, Terminal-Bench, Aider Polyglot, LiveCodeBench, and similar agentic coding benchmarks?

### Takeaway
In the current generation the tier gap is small for OpenAI and Google mid/small tiers on SWE-bench-style tasks (GPT-5.6 Luna 93.0% vs Sol 96.2% on SWE-bench Verified; Gemini 3.5 Flash-Lite 75.0% vs Flash 78.8%), but large for Anthropic's small tier on hard terminal tasks (Haiku 5.5 39.2% vs Opus 5.5 66.4% vendor, 29% vs 60% independent on Terminal-Bench 4.0). Sonnet 5.5 matches or beats Opus 5.5 on Terminal-Bench 4.0 at max effort, so the mid-to-top gap at Anthropic has nearly closed on that benchmark.

### Cited Findings

Anthropic, Terminal-Bench 4.0 and other agentic coding (vendor-reported, launch posts)
- Terminal-Bench 4.0: Opus 5.5 66.4% (xhigh effort, SE ±2.6), Fable 5.1 55.8%, Opus 5 52.3%, GPT-6 Astra 57.9% (OpenAI-reported, high effort), GPT-5.6 Sol 37.3%. FrontierCode v1.1 Main: Opus 5.5 54.4%, Fable 5.1 50.3%, Opus 5 48.0%, GPT-6 Astra 53.3%, GPT-5.6 Sol 47.5%. CursorBench 4.0: Opus 5.5 57.8%, Fable 5.1 51.8%, Opus 5 46.6%, GPT-5.6 Sol 41.7%. Public tbench leaderboard (5 trials, Claude Code harness) lists Opus 5 at 51.8%. — [Anthropic, Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- Terminal-Bench 4.0: Sonnet 5.5 70.6% vs Sonnet 5 10.3% vs Opus 5.5 66.4%. FrontierCode 1.1 Main: Sonnet 5.5 46.2% at max effort, 52.1% at xhigh, Sonnet 5 42.4%, Opus 5.5 54.4%, GPT-6 Sol 49.3%. CursorBench 4.0: Sonnet 5.5 55.5%, Sonnet 5 34.1%, Opus 5.5 57.8%. Anthropic says Sonnet 5.5 at max effort performs "comparably" to Opus 5.5 on several evaluations but that Opus 5.5 "remains clearly stronger on complex, open-ended work." — [Anthropic, Claude Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- Terminal-Bench 4.0 (pass@1): Haiku 5.5 39.2%, Haiku 4.5 0.0%, GPT-6 Luna 16.4%, Sonnet 5.5 70.6%. FrontierCode 1.1 Main: Haiku 5.5 46.4%, GPT-6 Luna 42.4%, Sonnet 5.5 52.1% (xhigh). — [Anthropic, Claude Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)
- The Opus 5.5, Sonnet 5.5 and Haiku 5.5 launch pages publish no SWE-bench Verified or SWE-bench Pro numbers. — [Opus 5.5](https://www.anthropic.com/claude-opus-5-5); [Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)

Anthropic, Terminal-Bench 4.0 (independent, Artificial Analysis, mini-swe-agent harness, 66 tasks, pass@1 averaged over 3 repeats)
- Sonnet 5.5 (max) 63.6%, Opus 5.5 (max) 59.6%, Opus 5.5 (xhigh) 59.6%. — [Artificial Analysis, Terminal-Bench 4.0](https://artificialanalysis.ai/evaluations/terminalbench-v4-0)
- At xhigh: Haiku 5.5 29% vs Opus 5.5 60%. SciCode: Haiku 5.5 52% vs Opus 5.5 65%. — [AA Haiku 5.5 vs Opus 5.5](https://artificialanalysis.ai/models/comparisons/claude-haiku-5-5-xhigh-vs-claude-opus-5-5-xhigh)
- At xhigh: Sonnet 5.5 57% vs Opus 5.5 60%. SciCode: Sonnet 5.5 57% vs Opus 5.5 65%. Intelligence Index 52 vs 56. — [AA Sonnet 5.5 vs Opus 5.5](https://artificialanalysis.ai/models/comparisons/claude-sonnet-5-5-xhigh-vs-claude-opus-5-5-xhigh)

SWE-bench Verified, independent (Vals.ai, mostly mini-SWE-agent bash-only harness, snapshot 2026-09-01, now archived)
- Anthropic: Opus 5 97.0% ($1.29/test), Fable 5 95.0%, Opus 4.8 88.6% (85.8% with Claude Code harness at $0.67/test), Opus 4.7 82.0%, Sonnet 5 79.6% ($1.49/test), Opus 4.6 Thinking 78.2%, Sonnet 4.6 77.4%, Opus 4.5 Thinking 76.4%, Sonnet 4.5 Thinking 70.0%, Haiku 4.5 Thinking 66.6% ($0.37/test). No 5.x Haiku or 5.5 models listed. — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- OpenAI: GPT-5.6 Sol 96.2% ($1.15/test), GPT-5.6 Terra 95.4% ($0.40), GPT-5.6 Luna 93.0% ($0.04), GPT-5.5 82.6%, GPT-5.4 xhigh 78.2%, GPT-5.3 Codex 78.0% ($0.46), GPT-5.2 75.8%, GPT-5.4 Mini 73.0% ($0.51), GPT-5.2 Codex 72.4%, GPT-5.4 Nano 69.8% ($0.10). — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- Google: Gemini 3.7 Flash 80.8%, 3.8 Flash 80.0%, 3.6 Flash 79.6%, 3.5 Flash 78.8% ($0.95), 3.1 Pro Preview 78.8% ($0.78), 3 Pro 76.4%, 3 Flash 75.0% ($0.28), 3.5 Flash-Lite 75.0% ($0.31), 3.1 Flash-Lite Preview 62.8% ($0.11). — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- Vals separately reports Gemini 3.5 Flash-Lite at 75.00% on the full 500 tasks but 68.63% on the subset used for its index. LiveCodeBench 79.01%, Terminal-Bench 2.1 50.19%. — [Vals.ai Gemini 3.5 Flash-Lite](https://www.vals.ai/models/google_gemini-3.5-flash-lite)

SWE-bench Pro, Terminal-Bench 2.1, DeepSWE (Google model card, vendor-reported, as of July 2026)
- SWE-Bench Pro (Public): Gemini 3.6 Flash 58.7%, 3.5 Flash 55.1%, 3.1 Pro 54.2%, GPT-5.6 Luna 62.7%, Grok 4.5 64.7%, Claude Sonnet 5 63.2%. Terminal-Bench 2.1 (Terminus-2 harness): 3.6 Flash 78.0%, 3.5 Flash 76.2%, 3.1 Pro 73.8%, GPT-5.6 Luna 84.7%, Sonnet 5 80.4%. DeepSWE v1.1: 3.6 Flash 49%, 3.5 Flash 37%, 3.1 Pro 12%, GPT-5.6 Luna 67%, Sonnet 5 54%. — [Gemini 3.6 Flash model card](https://deepmind.google/models/model-cards/gemini-3-6-flash/)
- Gemini 3.5 Flash-Lite: SWE-Bench Pro 54.2% vs 3.1 Flash-Lite 38.3% and vs older 3 Flash 49.6%. Terminal-Bench 2.1 54% vs 31% for 3.1 Flash-Lite (vendor). — [Google blog](https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-3-6-flash-3-5-flash-lite-3-5-flash-cyber/); [DeepMind Flash-Lite page](https://deepmind.google/models/gemini/flash-lite/)

OpenAI tiers (mixed vendor and third-party)
- GPT-5.6 SWE-Bench Pro: Sol 64.6%, Terra 63.4% (reported via secondary summary). Terminal-Bench 2.1: OpenAI chart puts Sol at 91.9% in "ultra" mode; independent testing about Sol 88.8%, Terra 84.3%, Luna 82.5%. Artificial Analysis Coding Agent Index: Sol (max) 80, Terra 77.4, Luna 74.6, vs Opus 4.8 72.5. — [secondary summary via web search: qainsights](https://qainsights.com/?p=18637); [layerlens GPT-5.6 review](https://layerlens.ai/blog/gpt-5-6-benchmark-review-sol-terra-luna). I could not open these pages directly, so treat as unverified.
- Vals Terminal-Bench 2.1 mirror: GPT-5.6 Sol 85.77%, Claude Opus 5 84.64% (2026-07-22 snapshot), Gemini 3.8 Flash 81.27%, GPT-5.6 Luna 79.03% max reasoning (2026-07-16 snapshot). — [BenchLM mirror of Vals TB 2.1](https://benchlm.ai/benchmarks/valsterminalbench21)
- GPT-6 Astra (OpenAI table, max effort): Terminal-Bench 4.0 57.7%, DeepSWE v1.1 74.1% vs GPT-5.6 Sol 72.7%, FrontierCode Main 53.3%, internal DB migration tasks 63.9% vs Sol 42.7%. No SWE-bench Pro figure published. — [Vellum](https://www.vellum.ai/blog/gpt-6-astra-benchmarks-explained)
- Earlier generation (vendor/aggregator): GPT-5.4 mini 54.4% and nano 52.4% on SWE-Bench Pro, GPT-5 mini 45.7%. — [DataCamp](https://www.datacamp.com/blog/gpt-5-4-mini-nano)

Aider Polyglot and LiveCodeBench
- LiveCodeBench: Gemini 3.5 Flash-Lite 79.01% (Vals), Gemini 3.5 Flash 87.6% (Vals run via BenchLM), Gemini 3.1 Flash-Lite 80.12% (Vals). — [Vals 3.5 Flash-Lite](https://www.vals.ai/models/google_gemini-3.5-flash-lite); [BenchLM 3.5 Flash](https://benchlm.ai/models/gemini-3-5-flash); [Vals 3.1 Flash-Lite](https://www.vals.ai/models/google_gemini-3.1-flash-lite-preview)

### Inferences
- Within-family tier gaps are benchmark-dependent. On SWE-bench Verified (saturated) the OpenAI Sol-to-Luna gap is 3.2 points; on Anthropic's Terminal-Bench 4.0 the Opus-to-Haiku gap is 27 points (vendor) or 31 points (AA).
- Anthropic's mid tier is not reliably behind its top tier any more on terminal tasks. Sonnet 5.5 leads Opus 5.5 on Terminal-Bench 4.0 in Anthropic's own table (70.6 vs 66.4) and in AA's max-effort run (63.6 vs 59.6), but trails at matched xhigh effort in AA (57 vs 60) and trails on SciCode (57 vs 65), FrontierCode (52.1 vs 54.4) and CursorBench (55.5 vs 57.8). The mid-to-top gap is roughly 0 to 8 points depending on the benchmark and effort setting.
- OpenAI's small tier is unusually strong on SWE-style tasks: GPT-5.6 Luna scores above Google's newest Flash and Anthropic's Sonnet 5 on Google's own table (SWE-Bench Pro 62.7, TB 2.1 84.7, DeepSWE 67).
- The Terminal-Bench 4.0 drop for small models (Haiku 4.5 0.0%, Sonnet 5 10.3%, GPT-6 Luna 16.4%) suggests TB 4.0 has a capability floor that older or small models fall below entirely, so it separates tiers more than older benchmarks.

### Gaps
- No vendor or independent SWE-bench Pro score for Opus 5.5, Sonnet 5.5, Haiku 5.5, or GPT-6 Astra.
- No primary OpenAI source found for GPT-6 Sol or GPT-6 Luna (names appear only in Anthropic comparison tables). OpenAI's GPT-5.6 tier numbers came through secondary summaries I could not open.
- No Gemini Pro newer than 3.1 Pro found, so Google's current Pro-vs-Flash comparison mixes generations.
- Aider Polyglot: no 2026 per-tier results found. The leaderboard may be stale or saturated; I did not confirm.
- Scale's standardized SWE-bench Pro leaderboard per tier was not retrieved (morphllm and other aggregator pages returned HTTP 429).

## Does the gap between tiers widen on harder or longer tasks (SWE-bench difficulty buckets, multi-file changes, long-horizon agentic tasks, METR time-horizon measurements)?

### Takeaway
Yes, consistently. The gap is several times larger on long-horizon and harder benchmarks (DeepSWE, Terminal-Bench 4.0) than on SWE-bench Verified. Vals.ai says the clearest model differences on SWE-bench Verified appear in the 15 min to 1 hour bucket. METR has no time-horizon data for any small-tier model.

### Cited Findings
- Vals.ai says "the clearest performance differences appear among tasks that take between 15 minutes and 1 hour to complete." The per-bucket table did not render in my fetch. — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- A scraped copy of that table showed Haiku 4.5 (Thinking) at 82%, 62%, 24%, 33% across four buckets, but the column labels were missing, so mapping to buckets is uncertain. — [Vals.ai SWE-bench, via search snippet](https://www.vals.ai/benchmarks/swebench)
- SWE-bench Verified difficulty bins: under 15 min, 15 min to 1 hr, 1 to 4 hr, over 4 hr, annotated assuming an engineer familiar with the codebase. Across 1,699 annotated instances the split is about 24.5%, 53.5%, 19.4%, 2.8%. The two hardest bins are often merged. — [SWE-smith paper](https://arxiv.org/pdf/2504.21798); [METR paper](https://arxiv.org/pdf/2503.14499)
- Google's table shows the gap growing with task length within its own family: Gemini 3.6 Flash vs 3.1 Pro is +4.5 points on SWE-Bench Pro (58.7 vs 54.2) but +37 points on long-horizon DeepSWE v1.1 (49 vs 12). — [Gemini 3.6 Flash model card](https://deepmind.google/models/model-cards/gemini-3-6-flash/)
- Anthropic small tier: Haiku 5.5 trails Sonnet 5.5 by 5.7 points on FrontierCode Main (46.4 vs 52.1) but by 31.4 points on Terminal-Bench 4.0 (39.2 vs 70.6). Terminal-Bench 4.0 is described as "complex, multi-step professional tasks within a command-line interface." — [Anthropic, Claude Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)
- Anthropic says Opus 5.5 "remains clearly stronger on complex, open-ended work" than Sonnet 5.5. Internal long task: HAProxy C-to-Rust translation finished by Opus 5.5 in 9.5 hours vs 12 for Fable 5.1, at 51% lower cost. — [Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- Base44 (customer quote, vendor page): Sonnet 5.5 built apps scoring level with Opus 5 across 118 builds, averaging 3.6 iterations per build vs 7.7 for Opus 5. — [Anthropic, Claude Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- OpenAI internal database migration tasks: GPT-6 Astra 63.9% vs GPT-5.6 Sol 42.7%, a 21-point gap, larger than the 1.4-point DeepSWE gap (74.1 vs 72.7). — [Vellum](https://www.vellum.ai/blog/gpt-6-astra-benchmarks-explained)
- METR time horizons (older, 50% horizon): Claude Opus 4.5 about 5h20m (Nov 2025), Claude Sonnet 4.5 about 2h02m (Sep 2025), GPT-5 about 2h18m (Aug 2025). Under TH 1.1, Opus 4.5 was re-scored at about 320 minutes. — [Wikipedia METR table, via search](https://en.wikipedia.org/wiki/METR); GPT-5 about 2h17m confirmed on [METR time horizons](https://metr.org/time-horizons/)
- METR has measured no Haiku, Gemini Flash, or GPT nano model. The only small model is o4-mini (Apr 2025). The page "is no longer actively updated" as of 2026-09-08, and measurements above 16 hours are "unreliable with our current task suite." Last model added: Claude Mythos Preview (2026-05-08). — [METR time horizons](https://metr.org/time-horizons/)

### Inferences
- Opus 4.5 vs Sonnet 4.5 is the only same-family top-vs-mid METR comparison found: about 2.6x longer 50% horizon for Opus, though the measurements are three months apart and Opus 4.5 was a later release.
- Across vendors the pattern holds: the smaller the model, the larger its deficit on long multi-step agentic tasks relative to short single-issue fixes. SWE-bench Verified compresses tiers into a 3 to 10 point band; DeepSWE and Terminal-Bench 4.0 spread them across 20 to 37 points.

### Gaps
- Labeled per-bucket SWE-bench Verified rates for Opus/Sonnet/Haiku (Vals table did not render).
- No METR time horizon for any 2026 small or mid-tier model, and METR has stopped updating the page.
- No multi-file vs single-file split found for any family.

## Is there evidence of the gap being small on easy or mechanical tasks (single-file edits, simple bug fixes, boilerplate)?

### Takeaway
Indirect evidence only. On SWE-bench Verified, which is dominated by short tasks (about 78% are under 1 hour), small tiers sit within 3 to 10 points of the top tier, and on SWE-bench Lite Haiku 4.5 trails Opus 4.6 by 8 points at about 10x lower cost. I found no benchmark that isolates boilerplate or single-file edits by tier.

### Cited Findings
- SWE-bench Verified: about 24.5% of tasks are under 15 minutes and 53.5% are 15 min to 1 hour. — [SWE-smith paper](https://arxiv.org/pdf/2504.21798)
- On that benchmark: GPT-5.6 Luna 93.0% vs Sol 96.2%; Gemini 3.5 Flash-Lite 75.0% vs 3.5 Flash 78.8%; Haiku 4.5 Thinking 66.6% vs Sonnet 4.5 Thinking 70.0%; GPT-5.4 Nano 69.8% vs Mini 73.0% vs GPT-5.4 xhigh 78.2%. — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- LayerLens: Haiku 4.5 54.33% vs Opus 4.6 62.67% on SWE-bench Lite, an 8.34-point gap with a cost gap of "10x or more." — [LayerLens on X](https://x.com/layerlens_ai/status/2043011471211188333)
- If the scraped Vals bucket values for Haiku 4.5 (82%, 62%, 24%, 33%) are in easiest-to-hardest order, Haiku 4.5 solves most under-15-minute fixes but falls to about a quarter of 1 to 4 hour tasks. Labels were missing. — [Vals.ai SWE-bench, via search snippet](https://www.vals.ai/benchmarks/swebench)

### Inferences
- Small-tier models are close enough on short, well-specified issue fixes that cost per solved task strongly favors them (see cost section). The gap reopens on multi-step and long-horizon work.

### Gaps
- No direct per-tier result on boilerplate, single-file edits, or mechanical refactors. Aider Polyglot, the closest benchmark for edit-format tasks, has no 2026 per-tier data I could find.

## What are per-task costs or token usage per tier where reported, and what is the cost per solved task?

### Takeaway
Small tiers are 10x to 30x cheaper per task while losing a few points on SWE-bench-style work. GPT-5.6 Luna costs about $0.04 per SWE-bench Verified test vs $1.15 for Sol, roughly $0.043 vs $1.20 per solved task. Small models often use more tokens per task than large ones (Haiku 5.5 89k output tokens vs Opus 5.5 66k), so price per token overstates their savings slightly.

### Cited Findings
- Vals SWE-bench Verified cost per test: GPT-5.6 Sol $1.15, Terra $0.40, Luna $0.04; GPT-5.4 Mini $0.51, Nano $0.10; Opus 5 $1.29, Opus 4.8 $1.92 (mini-SWE-agent) or $0.67 (Claude Code), Sonnet 5 $1.49, Haiku 4.5 Thinking $0.37; Gemini 3.5 Flash $0.95, 3.1 Pro $0.78, 3.5 Flash-Lite $0.31, 3.1 Flash-Lite $0.11. Latency: Sonnet 5 16m02s vs Opus 5 9m37s; Haiku 4.5 4m02s. — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- Artificial Analysis, xhigh effort: cost per task Haiku 5.5 $0.12, Sonnet 5.5 $2.01, Opus 5.5 $3.46. Output tokens per task 89k, 75k, 66k. Reasoning tokens per task 66k, 48k, 40k. Output speed 187, 103, 81 tokens/s. Cost to run the Intelligence Index $158, $2,177, $4,057. — [AA Haiku vs Opus](https://artificialanalysis.ai/models/comparisons/claude-haiku-5-5-xhigh-vs-claude-opus-5-5-xhigh); [AA Sonnet vs Opus](https://artificialanalysis.ai/models/comparisons/claude-sonnet-5-5-xhigh-vs-claude-opus-5-5-xhigh)
- AA cost to run Intelligence Index, Haiku 5.5 vs Opus 5.5: medium $56 vs $1,627; high $94 vs $2,172; Opus 5.5 at max $8,708. AA does not yet model Haiku 5.5's 5x price step above 100k tokens, so Haiku costs are provisional. — [AA comparison pages via search](https://artificialanalysis.ai/models/comparisons/claude-haiku-5-5-high-vs-claude-opus-5-5-high)
- List prices per 1M input/output tokens: Opus 5.5 $4/$20 (Opus 5 was $5/$25); Sonnet 5.5 $2/$10; Haiku 5.5 $0.10/$0.50 up to 100k tokens and $0.50/$2.50 above (Haiku 4.5 was $1/$5). Anthropic says Haiku 5.5 costs about 75% less to run than Haiku 4.5 on average, and the figure accounts for a new tokenizer that uses slightly more tokens per task. — [Opus 5.5](https://www.anthropic.com/claude-opus-5-5); [Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5); [Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5)
- Anthropic efficiency claims (vendor): Opus 5.5 at default effort beats Opus 5 at max effort on Terminal-Bench 4.0 for about one-fifth of the cost; Sonnet 5.5 at medium effort exceeds Sonnet 5's best Terminal-Bench 4.0 score at under a tenth of the cost; Sonnet 5.5 is up to 30% cheaper per task than Sonnet 5. — [Opus 5.5](https://www.anthropic.com/claude-opus-5-5); [Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- OpenAI GPT-5.6 launch prices: Sol $5/$30, Terra $2.50/$15, Luna $1/$6. After a 2026-07-30 cut, sources conflict on Luna ($0.20/$1.20 in several posts vs $1/$6 on OpenAI's model page per one source). GPT-6 Astra $10/$50. GPT-5.6 Sol "ultra" mode about $5 per task vs $1.70 single-agent for about 3 points more. — [qainsights](https://qainsights.com/?p=18637); [Vellum](https://www.vellum.ai/blog/gpt-6-astra-benchmarks-explained). Google's July card lists GPT-5.6 Luna at $1/$6 and Gemini 3.6 Flash at $1.50/$7.50, 3.1 Pro at $2/$12. — [Gemini 3.6 Flash model card](https://deepmind.google/models/model-cards/gemini-3-6-flash/)

### Inferences
- Cost per solved task on Vals SWE-bench Verified (cost per test divided by accuracy; my calculation): GPT-5.6 Luna about $0.043, Terra $0.42, Sol $1.20; Haiku 4.5 $0.56, Sonnet 5 $1.87, Opus 5 $1.33, Opus 4.8 (Claude Code) $0.78; Gemini 3.5 Flash-Lite $0.41, 3.5 Flash $1.21, 3.1 Pro $0.99. Check: Luna 0.04/0.93 = 0.0430; Sol 1.15/0.962 = 1.195.
- Within Anthropic on that benchmark, Opus 5 is cheaper per solved task than Sonnet 5 ($1.33 vs $1.87) because Sonnet 5 took longer and solved fewer. Higher tier does not always mean higher cost per solved task.
- On AA's Terminal-Bench 4.0 at xhigh, cost per point: Haiku 5.5 $0.12/29 points vs Opus 5.5 $3.46/60 points. Haiku is about 29x cheaper per task for about half the score. AA's cost per task is measured across the Intelligence Index task mix, not TB 4.0 alone.

### Gaps
- No per-tier cost per task on SWE-bench Pro or Terminal-Bench specifically, only index-wide averages.
- Sonnet 5.5 and Haiku 5.5 have no Vals SWE-bench entry (benchmark archived before their release).

## Any known caveats: benchmark contamination, scaffold differences, saturation

### Takeaway
SWE-bench Verified is saturated and archived; harness choice moves scores by several points; vendor and independent numbers on the same benchmark diverge by 6 to 15 points; and benchmark versions (Terminal-Bench 2.0, 2.1, 4.0) are not comparable.

### Cited Findings
- Vals.ai archived SWE-bench Verified because "performance has saturated," so new models are no longer run on it. Most results use mini-SWE-agent ("a minimal bash-tool-only agent harness"); entries with Claude Code, Codex, Factory or Cursor CLI are not directly comparable. GPT-5.5 scores 82.6% (mini-SWE-agent), 76.4% (Codex), 76.2% (Factory); Opus 4.8 88.6% (mini-SWE-agent) vs 85.8% (Claude Code). — [Vals.ai SWE-bench](https://www.vals.ai/benchmarks/swebench)
- Vendor vs independent Terminal-Bench 4.0: Opus 5.5 66.4% (Anthropic, xhigh) vs 59.6% to 60% (AA, mini-swe-agent); Haiku 5.5 39.2% vs 29%; Sonnet 5.5 70.6% vs 57% (xhigh) or 63.6% (max). — [Anthropic Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5); [AA TB 4.0](https://artificialanalysis.ai/evaluations/terminalbench-v4-0); [AA comparisons](https://artificialanalysis.ai/models/comparisons/claude-sonnet-5-5-xhigh-vs-claude-opus-5-5-xhigh)
- Effort setting changes rank: Sonnet 5.5 scored lower at max effort than xhigh on FrontierCode (46.2 vs 52.1) because at max it more often ran Claude Code's code-review skill with many subagents, causing a timeout or out-of-scope edits in two cases. Defaults are medium in Claude Code and high on the Claude Platform. — [Anthropic, Claude Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5)
- Opus 5.5 ran with production safeguards; when they intervened, cybersecurity tasks fell back to Opus 4.8 and some others to Opus 5, which Anthropic says likely lowers its scores. — [Anthropic, Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5)
- OpenAI's Terminal-Bench 2.1 Sol 91.9% uses "ultra" mode and a different harness from Anthropic's; independent testing put Sol near 88.8%. — [qainsights](https://qainsights.com/?p=18637)
- OpenAI's GPT-6 Astra chart used a 67.4% DeepSWE figure for Fable 5.1 that makes Astra's lead look larger than wider results; Meta reported 75.4% for Muse Spark 1.3 vs Astra 74.1%. — [Vellum](https://www.vellum.ai/blog/gpt-6-astra-benchmarks-explained)
- SWE-bench Pro: scaffold gap example, Scale's standardized scaffold gave gpt-5.2-codex 41.0% on the public set vs 56.4% reported elsewhere. — [nexos.ai, via search summary](https://nexos.ai/blog/gpt-5-benchmarks/). A 2026-09 arXiv paper proposes "SWE-Bench Pro Verified" as a more reliable variant, which implies reliability problems with SWE-bench Pro itself; I did not read it. — [arXiv 2609.08149](https://arxiv.org/pdf/2609.08149)
- Vals Flash-Lite 3.5: 75.00% on all 500 SWE-bench Verified tasks vs 68.63% on its index subset. — [Vals.ai Gemini 3.5 Flash-Lite](https://www.vals.ai/models/google_gemini-3.5-flash-lite)
- METR horizons above 16 hours are unreliable, human baselines "likely overestimate" expert time, and tasks are mainly SWE, ML and cybersecurity. — [METR time horizons](https://metr.org/time-horizons/)

### Inferences
- Generational overtaking is now the norm and is larger than within-generation tier gaps on saturated benchmarks:
  - OpenAI: GPT-5.6 Luna (small, 93.0%) beats the prior flagship GPT-5.5 (82.6%) on Vals SWE-bench Verified. AA Coding Agent Index has Luna at 74.6 vs Opus 4.8 at 72.5 (secondary source).
  - Google: Gemini 3.5 Flash ties 3.1 Pro (78.8% each, Vals); 3.6 Flash beats 3.1 Pro on Google's own SWE-Bench Pro, TB 2.1 and DeepSWE; 3.5 Flash-Lite beats 3 Flash on SWE-Bench Pro (54.2 vs 49.6).
  - Anthropic: Sonnet 4.6 (77.4%) beat Opus 4.5 Thinking (76.4%) and nearly matched Opus 4.6 Thinking (78.2%) on Vals; Sonnet 5 (79.6%) did not match Opus 4.8 (88.6%); Sonnet 5.5 beats Opus 5 on every Anthropic-published coding row (TB 4.0 70.6 vs 52.3; FrontierCode 52.1 vs 48.0; CursorBench 55.5 vs 46.6); Haiku 5.5 (TB 4.0 39.2%) is below Opus 5 (52.3%) but beats GPT-6 Luna (16.4%).
- Comparisons across sources need matched harness, effort level, and benchmark version. Within-family tier gaps in vendor launch posts are probably more reliable than cross-vendor gaps, because the same lab ran the same harness.

### Gaps
- No specific contamination analysis for 2026 models found. SWE-bench Verified saturation (Opus 5 97%) is documented, but whether it reflects contamination was not established in sources I read.
- Did not retrieve tbench.ai or Scale SWE-bench Pro leaderboards directly (aggregators rate-limited).
