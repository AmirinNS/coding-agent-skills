---
name: web-browse
description: "Search Brave and Bing by driving the real installed Chrome with Playwright, typing queries like a person so bot blocks don't fire. Returns ranked organic results as a JSON envelope with titles, URLs, domains, snippets, and optional readable page text. No SearXNG, no Docker, no database. Use when you want engine-page results you can open and cite, multi-engine coverage, or pages that block plain HTTP scrapers. Triggers: 'browse for', 'search brave/bing for', 'find pages about', 'look up online'. Not for social opinion or single-page reads. Takes one or more search queries."
---

# Web Browse

Search Brave and Bing the way a person does: open the engine homepage in the
**real** installed Chrome, type the query one character at a time, read the
results page. Backed by `scripts/web_browse.py` in this skill folder, ported
from the recon-tools bundle with the SearXNG API engine, its Docker service,
and the `recon.db` ingest stripped out. Results come back as JSON on stdout.

This is the open-web counterpart to `web-search` (the droid CLI's WebSearch
tool). Reach for `web-browse` when you specifically want engine-page results
with multi-engine coverage or page-text extraction through a real browser;
`web-search` is faster for ordinary lookups.

## When to use

- The user wants current web results or sources on a topic: articles, docs,
  pages, facts.
- You need actual URLs, snippets, and optionally full page text to read and
  cite, not just a model summary.
- The target pages block plain HTTP scrapers, so a real browser session helps.

Do **not** use for social opinion or lived experience, or for reading one
known URL (`web-fetch` covers that).

## Setup

The script drives real Google Chrome through Playwright's `channel="chrome"`,
so two things must exist: Playwright for the interpreter you run, and Google
Chrome itself.

On a machine that already has a Playwright environment, use its Python
directly:

```bash
python3 <skill-dir>/scripts/web_browse.py "QUERY"
```

Otherwise create one next to the skill:

```bash
python3 -m venv <skill-dir>/.venv
<skill-dir>/.venv/bin/pip install playwright
```

No `playwright install` step is needed for the `chrome` channel; it uses the
Chrome already on the machine. If Chrome is missing, install it, and the run
fails with a launch error in the envelope instead of fake results.

## How to run

```bash
<skill-dir>/.venv/bin/python scripts/web_browse.py "QUERY" [more queries] --max 5 --headless
```

- Multiple queries are searched in turn, per engine, and **deduped by URL**
  (first engine to return a URL keeps it).
- Each query takes roughly 10-50 seconds: real navigation plus human-style
  dwell and typing. Keep the query list tight.
- Progress logs (`[INFO]`, `[OK]`, `[WARN]`, `[BLOCKED]`) go to **stderr**. The
  JSON envelope is the only thing on **stdout**. Exit code is 1 when no
  results were collected.

The envelope is `{"keywords": [...], "engines": [...], "count": N,
"posts": [...], "errors": [...]}`. Each post has `rank`, `title`, `url`,
`domain`, `engine`, `keyword`, `snippet`, and `text` (empty without
`--fetch`). Read `errors` too: a query can fail while another succeeds.

## Choosing options

| Goal | Flags |
|------|-------|
| Default | `--engine brave` (already the default) |
| Bing only | `--engine bing` |
| Both engines, deduped | `--engine all` |
| Read the actual page text | `--fetch` (fills `text` per result) |
| More results per query per engine | `--max 15` (clamped to 50) |
| Unattended agent use | `--headless` |
| Watch it work, or clear a bot check | omit `--headless` |
| Gated or logged-in engine session | `--profile DIR` (see Notes) |
| Skip the stealth masking | `--no-stealth` |

## Interpreting results for the user

- `rank` is per-engine result order, not an authority score. With
  `--engine all`, agreement across engines is a signal a page is
  authoritative.
- Weigh `domain` for credibility: official docs and primary sources over
  content farms. Read `snippet` for relevance; read `text` when you need
  specifics.
- **Cite the `url`** so the user can verify. Summarize across results and
  note where sources disagree rather than trusting one page.

## Notes & limits

- **Brave can gate a session.** Observed live: after a few headless runs,
  Brave served a "Verifying you're not a bot" interstitial. The run then
  reports `[BLOCKED] brave: bot-check interstitial` and exits 1 with no fake
  results. Re-run with `--engine bing`, retry once headed (no `--headless`),
  or warm a profile: run with `--profile <dir>` headed once, complete the
  check or login by hand when the window opens, then reuse that `--profile`.
  Never automate the CAPTCHA itself.
- **Bing's markup drifts.** If bing logs "no results element (markup may
  have changed)" or returns off-topic hits, treat it as a selector regression
  in `web_browse.py` and rely on brave. Bing also wraps result links in
  `bing.com/ck/a?...&u=<base64url>` redirects; the script unwraps them.
- **Extractors are fragile by nature.** They are anchored on each engine's
  most stable structure and isolated per engine, so one breaking does not
  affect the other. A fix is a selector edit in `ENGINES`, nothing else.
- **Be polite.** The script already human-dwells between pages and types with
  human delays. Keep `--max` reasonable and don't hammer engines you don't
  need.
- Runnable check for the pure logic (no browser needed):
  `python3 <skill-dir>/tests/test_web_browse.py`.
