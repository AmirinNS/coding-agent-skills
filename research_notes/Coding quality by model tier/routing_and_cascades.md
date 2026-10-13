# LLM routing, cascades, and orchestrator-worker model mixing for coding

Research cutoff 2026-10-13. Evidence labels used below:
- [Peer-reviewed] means published at a named venue.
- [Preprint] means arXiv, not yet peer reviewed. Several of these release code or data.
- [Vendor] means a model provider or routing company reporting on its own product.
- [Training-knowledge] means I am citing from prior knowledge of a well-known paper and did not re-fetch it in this session. The numbers are widely quoted, but the report writer should treat them as lower-confidence than fetched items.

## 1. What did FrugalGPT, RouteLLM, AutoMix, cascade papers, and 2025-2026 routing work find about cost savings vs quality loss? Which results apply to coding?

### Takeaway
The classic routing papers (2023-2024) report large savings, from 35% to 98%, at near-strong-model quality. Almost all of that evidence comes from chat, QA, and math benchmarks, not code. The 2026 agentic-coding routing papers report smaller but real savings. Examples are about 53% lower API cost at a matched SWE-bench Verified resolve rate and about one fifth the cost per solve on SWE-bench Pro. A key 2026 finding is that solve sets are nested. Cheap models solve mostly a subset of what the strongest model solves, so routing can cut cost but rarely raises accuracy above "always use the strongest model".

### Cited findings

Classic (non-code) routing and cascade results:
- FrugalGPT (Chen, Zaharia, Zou; arXiv May 2023, later TMLR). A sequential cascade with a learned answer scorer matched GPT-4 with up to 98% cost reduction, or beat GPT-4 accuracy by 4% at the same cost. The benchmarks were classification and QA sets such as HEADLINES, OVERRULING, and COQA, not code. [Training-knowledge, Preprint/Peer-reviewed] — [arXiv 2305.05176](https://arxiv.org/abs/2305.05176)
- RouteLLM (Ong et al., LMSYS; arXiv June 2024, ICLR 2025). Routers trained on Chatbot Arena preference data cut cost by over 85% on MT-Bench, 45% on MMLU, and 35% on GSM8K against always-GPT-4, while keeping 95% of GPT-4 performance. No code benchmark was in the headline results. [Training-knowledge, Peer-reviewed] — [arXiv 2406.18665](https://arxiv.org/abs/2406.18665)
- AutoMix (Aggarwal et al.; arXiv Oct 2023, NeurIPS 2024). A small model's few-shot self-verification feeds a POMDP meta-router. It reports over 50% compute cost reduction at comparable performance on reasoning and QA datasets. The authors treat self-verification as noisy, which is why they add the POMDP layer. [Training-knowledge, Peer-reviewed] — [arXiv 2310.12963](https://arxiv.org/abs/2310.12963)
- Hybrid LLM (Ding et al.; ICLR 2024). A query-difficulty router sends up to 40% fewer calls to the large model with no drop in response quality, on general instruction data. [Training-knowledge, Peer-reviewed] — [arXiv 2404.14618](https://arxiv.org/abs/2404.14618)
- Two-model cascades help, but deeper ones rarely do (Bouchard; arXiv v1 7 May 2026, v2 5 Oct 2026). The study covers five benchmarks, nine deferral scores, and eight models. Two-model cascades improved mean test accuracy over single-model selection by 2.1 to 8.2 points. Allowing more than two models did not improve accuracy in 118 of 135 comparisons, with at most +0.43 points. A secondary search snippet says LiveCodeBench is among the benchmarks and reports up to 79.5% cost reduction against always using the most accurate model. I could not confirm that figure from the abstract page. [Preprint] — [arXiv 2605.06350](https://arxiv.org/abs/2605.06350)
- "Cluster, Route, Escalate" (arXiv 2606.27457, 2026), general LLM serving. A search snippet reports that it keeps 97-99% of the strongest model's accuracy while escalating low-quality outputs. I did not fetch or verify the paper. [Preprint] — [arXiv 2606.27457](https://arxiv.org/html/2606.27457)

Code generation (function-level):
- Model Cascading for Code (Chen, Zhu, Dolan-Gavitt, Shafique, Garg, NYU; arXiv May 2024, revised 13 Feb 2025). The models are open-source WizardCoder and CodeGen families, evaluated on HumanEval, MBPP, and APPS-intro. Cost falls by 26% on average and by up to 70% in the best case, at accuracy equal to or above single-model self-testing. Per-family savings at matched accuracy vary widely. On HumanEval they are 17.4%, 11.5%, and 70.0%. On MBPP they are 30.8%, 11.4%, and 39.5%. On APPS-intro they are 16.2% and **−1.6%**, meaning the cascade cost more. Costs are GPU-time estimates (RTX 3090 at $0.44/hr), not commercial API prices. [Preprint] — [arXiv 2405.15842](https://arxiv.org/html/2405.15842v2)

Agentic software engineering (2026):
- TwinRouterBench (Yang et al.; arXiv 14 May 2026). Results on a live 100-instance SWE-bench Verified split:

  | Policy | Resolved | Realized API cost |
  |---|---|---|
  | Trained UncommonRoute | 75/100 | $25.66 |
  | Unrouted Opus 4.6 | 74/100 | $54.73 |
  | SR-KNN | 75/100 | $55.61 |
  | Rule-based UncommonRoute | 73/100 | $172.56 |

  That is a 53.1% API cost cut at a comparable resolve rate for the trained router. SR-KNN, the top router on the static benchmark, saved essentially nothing in the live run. [Preprint] — [arXiv 2605.18859](https://arxiv.org/html/2605.18859v1)
- SWE-Router (Son et al., UCL and others; arXiv 30 Jun 2026). A weak model runs K exploratory turns in mini-SWE-agent, then a 7B value head reads the partial trajectory and decides whether to escalate. Solo SWE-bench Verified reference points:
  - gpt-5-mini: 55.6% resolved for $16.6.
  - deepseek-v3.2: 62.4% resolved for $22.6.
  - gemini-3-pro: 70.4% resolved for $391.3, roughly 17 to 24 times more expensive than the weak models.

  Trajectory-conditioned routing raised Route-AUC from 0.627 to 0.780 for the deepseek→gemini pair. The paper gives no single percentage cost saving. The routed curve briefly exceeds the all-strong point, because the weak and strong models solve partly different tasks. [Preprint] — [arXiv 2607.00053](https://arxiv.org/html/2607.00053v1)
- Scrouting / SuperScout (Bhola, Krishnan, NS, SuperAGI Research; arXiv 5 Aug 2026). A 7B searcher explores the repository and writes a sandbox-verified handoff, then a router picks one of four frontier fixers. On SWE-bench Pro Python (266 tasks) it solved 159 tasks against 158 for the best single model (Opus 4.6), at $0.230 against $1.274 total cost per solve. That is about one fifth of the cost, with searcher GPU time and sandboxes included. A no-router ablation that always picks the cheapest fixer plus the handoff tied the routed system, so the handoff carries the result, not the routing decision. Code, weights, and data are released. [Preprint, reproducible artifacts] — [arXiv 2608.04804](https://arxiv.org/abs/2608.04804)
- The same paper replayed learned routers over public per-task results on SWE-bench Verified, Multilingual, and Pro. Solve sets are strongly nested, with containment of 0.941, 0.912, and 0.773. Pools built only from frontier models still show 0.90 to 0.93. No learned router beat always picking the strongest model on solve rate, and every gap was within noise. The authors conclude that routing for accuracy has little headroom, while routing for cost only requires predicting when a cheaper model will suffice. [Preprint] — [arXiv 2608.04804](https://arxiv.org/abs/2608.04804)
- Agent-as-a-Router / CodeRouterBench (Zhou et al., NUS, Alibaba and others; arXiv 24 Jun 2026). The pool has 8 models, including Opus 4.6, Sonnet 4.6, GPT-5.4, Qwen3-Max, GLM-5, and Kimi-K2.5.

  | Split | ACRouter | Always-Opus 4.6 | Oracle | Perf/$, ACRouter vs Always-Opus |
  |---|---|---|---|---|
  | In-distribution | 49.98% | 43.83% | 57.00% | 3.79 vs 1.29 |
  | Out-of-distribution, agentic (176 tasks) | 62.50% | 57.14% | 75.89% | 1.18 vs 0.64 |

  On the out-of-distribution split, lightweight trained classifiers (LogReg, MLP, RouteLLM variants) collapsed to 8.93%-21.43%, below random at 31.25%. Agentic runs were capped at 40 steps, and dollar costs are estimates because cache hits are unobservable. [Preprint] — [arXiv 2606.22902](https://arxiv.org/html/2606.22902v2)

Vendor claims for coding:
- Not Diamond Code (blog, 4 Aug 2026). It routes per step inside Claude Code among Haiku 4.5, Sonnet 4.6, and Opus 4.8 at several effort levels, and it accounts for KV-cache state.
  - It claims Opus 4.8 Xhigh-level quality at 39% lower cost on Poly-SWE-Bench Verified and 61% lower on LongCodeQA.
  - With GLM 5.2 and DeepSeek V4 Flash added to the pool, it claims +3.6% performance and 66% savings.
  - Enterprise early access reports "over 20%" savings.

  No methodology or data is published for reproduction. [Vendor] — [Not Diamond blog](https://www.notdiamond.ai/blog/not-diamond-code-intelligent-model-routing-for-coding-agents)
- Not Diamond's own pages are inconsistent. The docs say "20%+" savings without quality loss, and the pricing page says 30-90%. [Vendor] — [Not Diamond Code docs](https://code.notdiamond.ai/docs/); [pricing](https://www.notdiamond.ai/pricing)

### Inferences
- The headline 85-98% savings from FrugalGPT and RouteLLM come from tasks where a cheap model often gives an acceptable answer, such as chat and QA. Coding-agent results cluster lower, around 40-80% cost reduction at matched resolve rate, and they depend heavily on harness design.
- On SWE-style tasks, the big price gap between tiers (about 17-24 times in SWE-Router's table) means even a modest share of tasks kept on the cheap model saves a lot. The cost of the cheap attempts that later escalate is small next to the strong model's cost.
- Nested solve sets suggest a practical rule. Expect routing to lower cost, not raise quality. A routed system's best case is matching the strongest model.

### Gaps
- I did not re-fetch FrugalGPT, RouteLLM, AutoMix, or Hybrid LLM in this session. Their numbers come from prior knowledge and should be spot-checked.
- I could not confirm the LiveCodeBench-specific numbers in arXiv 2605.06350.
- I found no published coding evaluation for Martian or for OpenRouter's Auto router.

## 2. Planner/executor and architect/editor splits: quantitative results

### Takeaway
The splits help in published results, but the gains are mostly a few points, and conditions vary between runs.
- Aider's architect/editor split raised every tested pair above the architect's solo score on Aider's edit benchmark (Sep 2024).
- Anthropic's advisor tool (Apr 2026) gave Sonnet +2.7 points on SWE-bench Multilingual at 11.9% lower cost per task.
- Anthropic's Opus-lead plus Sonnet-worker research system beat solo Opus by 90.2% on an internal research eval, using about 15 times the tokens of chat. Anthropic says this pattern fits most coding poorly.
- No published numbers exist for Claude Code's `opusplan`.

### Cited findings
- Aider architect/editor (blog, 26 Sep 2024), on Aider's code editing benchmark.

  | Architect + editor (edit format) | Split pass rate | Architect solo pass rate |
  |---|---|---|
  | o1-preview + o1-mini (whole) | 85.0% | 79.7% |
  | o1-preview + DeepSeek (whole) | 85.0% | 79.7% |
  | Sonnet 3.5 + Sonnet 3.5 | 80.5% | 77.4% |
  | Sonnet 3.5 + DeepSeek | 78.9% | 77.4% |
  | GPT-4o + GPT-4o | 75.2% | 71.4% |
  | o1-mini + DeepSeek (whole) | 71.4% | 61.1% |
  | GPT-4o-mini + GPT-4o-mini (whole) | 60.2% | 55.6% |

  Every pair beat the architect's solo score. Pairing a model with itself also helped. The page gives no cost figures. It says the top "whole"-format pairs are slow and probably impractical for interactive use. [Vendor/open-source project, reproducible benchmark harness] — [Aider blog](https://aider.chat/2024/09/26/architect.html)
- Anthropic advisor tool (`advisor_20260301`, blog 9 Apr 2026). The executor (Sonnet or Haiku) decides when to call Opus inside the same API request. Advisor replies typically run 400-700 tokens, and `max_uses` caps the calls.
  - Sonnet 4.6 plus an Opus advisor gained +2.7 points over Sonnet alone on SWE-bench Multilingual, at 11.9% lower cost per agentic task.
  - Haiku plus an Opus advisor scored 41.2% on BrowseComp against 19.7% for Haiku alone. It scored 29% lower than Sonnet solo at 85% lower cost per task.
  - Sonnet plus an advisor also beat Sonnet alone on Terminal-Bench 2.0 at lower cost. The exact figures appear only in charts.

  The run conditions differed. Sonnet solo used adaptive thinking on SWE-bench while the advisor run had thinking off, and effort levels and system prompts varied. Sample sizes were 300 SWE-bench problems × 5 trials, 1,266 BrowseComp problems × 1, and 89 Terminal-Bench tasks × 5. No numeric comparison against Opus solo is given. [Vendor] — [Claude blog: the advisor strategy](https://claude.com/blog/the-advisor-strategy)
- Secondary blogs report the 11.9% as "cheaper than running Opus solo", which conflicts with the primary blog's comparison against Sonnet alone. Use the primary wording. — [Sean Kim blog](https://blog.imseankim.com/claude-advisor-tool-executor-opus-sonnet-haiku-swe-bench-cost-2026/) (secondary, conflicting) vs [Claude blog](https://claude.com/blog/the-advisor-strategy)
- Anthropic multi-agent research system (engineering blog, 13 Jun 2025). These are vendor results on research tasks, not coding.
  - An Opus 4 lead with Sonnet 4 subagents "outperformed single-agent Claude Opus 4 by 90.2% on our internal research eval".
  - Agents use about 4 times the tokens of chat, and multi-agent systems about 15 times.
  - Three factors explained 95% of BrowseComp variance, and "token usage by itself explains 80%".
  - Anthropic names the poor fits: "most coding tasks involve fewer truly parallelizable tasks than research", domains that need shared context, and tasks whose value does not justify the extra tokens.

  [Vendor] — [Anthropic engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- Claude Code `opusplan`. It uses Opus in plan mode and switches to Sonnet in execution mode. The rationale given is "Opus's reasoning for planning with Sonnet's efficiency for execution". The docs give no performance numbers. For mid-task consultation they point to the advisor tool instead. Subagents inherit the main model unless their definition sets `model` or `CLAUDE_CODE_SUBAGENT_MODEL` is set. [Vendor docs] — [Claude Code model config](https://code.claude.com/docs/en/model-config)
- In SuperScout, a cheap 7B scout's verified handoff lifted the three cheaper fixers but slightly hurt the strongest fixer, Opus 4.6. The calibration study has N=99, so the per-fixer effects are directional only. This is a small-model-helps-big-model split, the reverse of planner/executor. [Preprint] — [arXiv 2608.04804](https://arxiv.org/abs/2608.04804)

### Inferences
- Planner/executor splits lift the weaker or executor model by a few points, roughly 2.7 to 10 in the cited data, at less than strong-model cost. None of the published results shows the split beating the strong model run solo, under matched conditions, on a coding benchmark.
- Anthropic's own guidance points multi-agent fan-out toward parallel research. For coding, the advisor or "plan with big, execute with small" patterns fit better than many parallel workers.
- The 90.2% and 15× figures support a point about cost accounting. Multi-agent quality gains largely track how many tokens were spent, so cost per task must be compared, not price per token.

### Gaps
- No public, reproducible benchmark of `opusplan` against Opus-only or Sonnet-only exists.
- The advisor blog gives no numeric comparison of Sonnet plus advisor against Opus solo.
- Aider's architect results date from 2024 and predate current model tiers. I found no newer architect-pair leaderboard in this session.

## 3. How cascades decide when to escalate, and how reliable those signals are for code

### Takeaway
Escalation signals for code fall into five groups:
- self-confidence or self-verification
- self-generated tests
- hidden or real test suites
- learned routers on the prompt
- learned routers on a partial trajectory

Test-based signals work for function-level code, but self-generated tests produce false positives with weak models. Benchmark tests let through incorrect patches roughly 7.8% to 20% of the time. In agentic SWE tasks, routers trained on the prompt alone transfer badly. Signals drawn from early exploration of the repository work better, with Route-AUC around 0.71-0.78. A frontier model asked to act as a router failed badly in one study.

### Cited findings
- Self-generated tests as the escalation gate. Each model writes k solutions and k tests, and the answer is accepted if its pass score clears θ × k × (number of valid test lines). Otherwise the query escalates. Failure modes:
  - Very weak models (a 1B model on APPS) produce false-positive tests and give negative savings. The authors recommend excluding models below about 10% accuracy.
  - Test lines past the first two or so are more error-prone.
  - The best θ depends on the model and the prompt. Lower θ worked better on MBPP because of false negatives.

  [Preprint] — [arXiv 2405.15842](https://arxiv.org/html/2405.15842v2)
- Benchmark tests as the signal are imperfect. On SWE-bench Verified patches from three tools, 7.8% of patches accepted by the benchmark tests failed the developers' full test suite. Another 29.6% of plausible patches behaved differently from the gold patch, and 28.6% of those were judged certainly incorrect. Together these inflated resolve rates by 6.2 points. [Peer-reviewed, ICSE 2026] — [arXiv 2503.15223](https://arxiv.org/html/2503.15223v2); [ICSE 2026 listing](https://conf.researchr.org/details/icse-2026/icse-2026-research-track/59/Are-Solved-Issues-in-SWE-bench-Really-Solved-Correctly-An-Empirical-Study)
- SWE-ABS (ICML 2026). Stronger test suites rejected 19.78% of "solved" patches from the top 30 agents, and the top agent's score fell from 78.80% to 62.20%. [Peer-reviewed] — [ICML 2026 poster](https://icml.cc/virtual/2026/poster/62669); [arXiv 2603.00520](https://arxiv.org/html/2603.00520v1)
- Trajectory signals beat prompt-only signals. Route-AUC rose from 0.627 (no trajectory) to 0.780 (K=2 turns) for deepseek→gemini. For gpt-5-mini→gemini, the best SWE-Router (0.709) beat the strongest baseline (0.565). AUROC stayed modest at about 0.52-0.70 across methods. Results were inconsistent across splits because of repository-level distribution shift. On the SWE-Smith test split the gpt-5-mini router did not beat baselines. [Preprint] — [arXiv 2607.00053](https://arxiv.org/html/2607.00053v1)
- Per-step routing fails in specific ways inside agents.
  - "One under-routed critical step fails the whole trajectory."
  - Claude Opus 4.6, prompted as a router, predicted "high" for only 7 of 147 verified-high SWE steps and failed all 40 SWE trajectories. That is one model under one prompt template.
  - The rule-based routers ClawRouter and UncommonRoute failed 38/40 and 39/40 SWE trajectories.
  - Switching tiers incurs cache-write charges.

  [Preprint] — [arXiv 2605.18859](https://arxiv.org/html/2605.18859v1)
- Cascade theory. Gains from extra cascade depth appear only when the confidence score tracks whether the current model is correct. They vanish when the score mostly reflects query difficulty shared across models, even at equal AUROC. [Preprint] — [arXiv 2605.06350](https://arxiv.org/abs/2605.06350)
- In AutoMix, self-verification by the small model is noisy, and the paper adds a POMDP layer on top for that reason. [Training-knowledge, Peer-reviewed] — [arXiv 2310.12963](https://arxiv.org/abs/2310.12963)
- In the advisor pattern, the executor model itself decides when it is unsure and calls Opus. This is a self-confidence signal, and Anthropic publishes no separate reliability numbers for it. [Vendor] — [Claude blog](https://claude.com/blog/the-advisor-strategy)

### Inferences
- "Run tests, escalate on failure" is the strongest available signal for code, but it is one-sided. A failing test reliably says escalate. A passing test does not reliably say the code is right. Teams should expect roughly 5-20% of test-passing cheap outputs to still be wrong, depending on test strength, based on the SWE-bench audit figures.
- Weak models writing their own tests is a trap. The model that can't solve the task also can't write a reliable test for it, so this signal degrades as the task gets harder.
- Prompt-only difficulty signals miss shared-difficulty effects. Hard tasks are hard for every model, so a cheap model's low confidence often predicts that the strong model will fail too.

### Gaps
- I found no study that measures "escalate on failing real tests" as a cascade policy on SWE-bench with full cost accounting. Studies use hidden tests for scoring, not as an online escalation signal.
- No published reliability numbers exist for executor-initiated advisor calls.

## 4. Cost of a failed cheap attempt vs using the strong model first

### Takeaway
Published accounting covers token and API cost, not human review time or bugs shipped later. On SWE tasks, a cheap probe costs little next to the strong model, so the wasted tokens on escalation are minor. The larger hidden costs are three:
- strong models do worse when given a weak model's failed trajectory, so escalation means restarting from scratch
- cascades on tasks too hard for the cheap tier cost more than going straight to the strong model
- test-passing but wrong cheap patches slip through

### Cited findings
- SWE-Router counts the K weak-model turns in the cost of every escalated run. On escalation the strong model restarts from the original prompt, because conditioning on the weak model's reasoning "biased the strong model toward its mistakes". So the weak model's work is pure overhead on escalated tasks. [Preprint] — [arXiv 2607.00053](https://arxiv.org/html/2607.00053v1)
- SuperScout uses "total cost per solve" covering every component: searcher GPU, verification sandboxes, and fixer API. The whole searcher GPU bill for the evaluation was $1.13, under half a cent per task. The paper also proposes a "blind-mixing line" baseline. Any random cheap/strong traffic split reaches the line between the two models' (cost, accuracy) points, so a router must sit above that line to add value. [Preprint] — [arXiv 2608.04804](https://arxiv.org/abs/2608.04804)
- Function-level cascades lose money when the dataset is too hard for the small models. WizardCoder-V1.0 on APPS-intro showed −1.6% savings, and the 1B model wasted compute and produced false-positive tests. [Preprint] — [arXiv 2405.15842](https://arxiv.org/html/2405.15842v2)
- Rule-based routing can cost much more than always-Opus. One rule-based router cost $172.56 against $54.73 for unrouted Opus on the same 100 SWE-bench tasks, and resolved fewer (73 vs 74). [Preprint] — [arXiv 2605.18859](https://arxiv.org/html/2605.18859v1)
- Cache economics matter in agent loops. Per-step tier switching incurs cache-write charges. Not Diamond Code says it sometimes stays on a pricier model to keep a warm KV cache. [Preprint] — [arXiv 2605.18859](https://arxiv.org/html/2605.18859v1); [Vendor] — [Not Diamond blog](https://www.notdiamond.ai/blog/not-diamond-code-intelligent-model-routing-for-coding-agents)
- Slipped bugs. Benchmark-accepted patches are wrong often enough to inflate SWE-bench resolve rates by 6.2 points in one audit, and 19.78% of "solved" patches were rejected under stronger tests in another. These figures cover all agents, not only cheap ones. [Peer-reviewed] — [arXiv 2503.15223](https://arxiv.org/html/2503.15223v2); [ICML 2026 SWE-ABS](https://icml.cc/virtual/2026/poster/62669)
- Token spend predicts quality in multi-agent setups, with tokens explaining 80% of BrowseComp variance. Cutting tokens by using cheaper workers can cut quality too. [Vendor] — [Anthropic engineering](https://www.anthropic.com/engineering/multi-agent-research-system)

### Inferences
- With roughly 17-24× price ratios between tiers (SWE-Router), a cheap attempt that fails and escalates adds maybe 5-10% to that task's strong-model cost. A cheap attempt that succeeds saves about 95%. So cheap-first wins on tokens whenever the cheap tier solves a meaningful share of tasks, and loses when it solves very few. That matches the APPS negative-savings result.
- The real risk of cheap-first is accepting a wrong-but-passing patch, not the wasted tokens. That risk scales with test weakness, so cheap-first needs stronger verification than strong-first.

### Gaps
- I found no published measurement of human review time, or of downstream bug rates, for cheap-model output against strong-model output in real codebases.
- No study reports end-to-end cost including human time for a cascade on agentic coding.

## 5. Task-difficulty classifiers that predict which model a coding task needs

### Takeaway
Classifiers that use only the prompt, such as RouteLLM variants, logistic regression, kNN, and MLP, do poorly on agentic coding. They lose to random on out-of-distribution agentic tasks in one benchmark. Static scores also fail to predict live savings. Better predictors use evidence gathered after engaging with the repository: partial trajectories or a scout's hidden states. Even these give modest discrimination, with AUC around 0.7-0.8.

### Cited findings
- On CodeRouterBench's out-of-distribution agentic split, the lightweight classifiers (LogReg, TF-IDF+MLP, RouteLLM-MF/BERT) fell to 8.93%-21.43% AvgPerf, below random at 31.25%. The authors attribute routing limits to an "information deficit". Giving the router per-dimension performance statistics raised AvgPerf from 41.41% to 47.74%. [Preprint] — [arXiv 2606.22902](https://arxiv.org/html/2606.22902v2)
- SR-KNN ranked first on TwinRouterBench's static track (Combined 77.89) but saved essentially nothing against Opus in the live SWE-bench run ($55.61 vs $54.73). The authors call the trained router's live result "initial evidence", not proof that static scores transfer. [Preprint] — [arXiv 2605.18859](https://arxiv.org/html/2605.18859v1)
- In SuperScout, the scout's hidden states improved cost routing on calibration labels, while the text of the scout's handoff did not. No learned prompt-based router beat always-strongest in the public-results replay. [Preprint] — [arXiv 2608.04804](https://arxiv.org/abs/2608.04804)
- SWE-Router's partial-trajectory value head reached Route-AUC 0.709-0.780, against 0.565-0.627 for prompt-only baselines. Repository distribution shift made results unstable across splits. [Preprint] — [arXiv 2607.00053](https://arxiv.org/html/2607.00053v1)
- The cascade theory paper finds that scores capturing shared query difficulty, rather than whether the current model is correct, give no depth gains. [Preprint] — [arXiv 2605.06350](https://arxiv.org/abs/2605.06350)

### Inferences
- For a practical skill or workflow, "cheap model explores first, then decide" beats "classify the ticket text up front". The best published evidence routes after some repository engagement.
- Human-set heuristics such as task type, file count, or "is it a rename" may be about as good as learned prompt-only routers for agentic coding. That is untested.

### Gaps
- I found no study that evaluates simple human-written difficulty heuristics against learned routers for coding agents.
- All agentic routing results are on SWE-bench-family benchmarks with 100-500 tasks. None covers a private production codebase.
