---
name: commit-diff-report
description: "Generate a token-efficient diff report between two git commits (or a commit and HEAD) — a changed-files tree, a compacted line-by-line diff, and the commit-message log in one artifact. Compact by default (diff noise stripped, hunks capped, per-file +/- tallies — the rtk 'token killer' technique); pass --full for the verbose human-readable version with banners and statistics. Use when the user wants a review packet, release/changelog summary, or a 'what changed between X and Y' write-up that raw `git diff` doesn't format nicely — especially to feed into an LLM without blowing the context window. Triggers: 'diff report', 'commit diff report', 'what changed between', 'changelog between commits', 'compare these commits', 'generate a review packet', 'summarize changes between <ref> and <ref>', 'changed files tree'. Not for staging a commit (use generate-commit) or reviewing uncommitted work."
---

# Commit Diff Report

Produce one formatted report describing everything that changed between two git
commits. This wraps a bundled script (`git_diff.py`) — a deterministic CLI, pure
Python stdlib, no dependencies. Reach for it when the user wants a **shareable
artifact** (PR packet, release notes, "diff between v1 and v2"), not when a quick
`git diff` on a file would do.

## When to use / not use

- **Use** when: comparing two commits/tags/branches, building a changelog or
  review packet, or answering "what changed between X and Y" with a tidy tree +
  stats + full diff in one file.
- **Don't use** for: staging/writing a commit message (→ `generate-commit`),
  reviewing *uncommitted* working changes (plain `git diff` / `/code-review`), or
  targeted single-file inspection where raw `git diff <file>` is simpler.

## How to run

Run from **inside the target git repository** (the script exits if not in a repo,
and reports paths relative to that repo root). Any `python3` works — no venv or
install step needed.

```bash
python3 <path-to>/git_diff.py <old-commit> [<new-commit>] [options]
```

- `<old-commit>` is required; `<new-commit>` defaults to `HEAD`.
- Commits can be hashes, tags, or branch names (e.g. `v1.2.0 v1.3.0`, `main feature-x`).

**Compact is the default** and is what you almost always want when feeding an LLM.
It emits: a one-line header + **changed-files tree** + a **compacted diff** (noise
stripped, each hunk capped, per-file `+added -removed` tally) + the
**commit-message log**. Overflow past `--max-lines` (default 500) collapses to a
truncation marker rather than dumping everything — typically a 60–75% size cut vs.
the full report. Pass `--full` for the verbose, banner-and-statistics version meant
for human reading.

### Options

| Flag | Effect |
|------|--------|
| `--full` | Verbose human-readable report (banners + statistics + untrimmed diff). Default is compact. |
| `--max-lines N` | Compact mode: cap total diff lines before truncating (default 500) |
| `-o, --output FILE` | Write the report to a file instead of stdout |
| `-n, --files-only`  | Show only the changed-files list (no tree, no diff) |
| `-t, --tree` / `--no-tree` | Changed-files tree — on by default |
| `-d, --diff` / `--no-diff` | Diff section — on by default |
| `-c, --context N` | Context lines around each change (default 3) |
| `-s, --stats` / `--no-stats` | Statistics block — **full mode only** (compact uses per-file tallies) |
| `-w, --word-diff` | Word-level highlighting — **full mode only** |

Tree legend: `[+]` added, `[-]` deleted, `[~]` modified, `[→]` renamed.

## Examples

```bash
# Compact report (default) from a commit to HEAD — token-efficient, for an LLM
python3 git_diff.py 6d9983c

# Verbose human-readable report between two tags, saved as a changelog artifact
python3 git_diff.py v1.2.0 v1.3.0 --full -o CHANGES_v1.3.0.txt

# Quick "what files changed" list only
python3 git_diff.py HEAD~5 -n

# Compact, but tighten the truncation cap for a very large range
python3 git_diff.py main feature-x --max-lines 200
```

## Notes for the agent

- Always confirm the two refs with the user if ambiguous ("between the last release
  and now" → resolve the actual tag/hash first).
- Default (compact) mode is the right choice for reading the diff yourself or
  feeding it into another model — it strips diff noise and self-truncates. Only
  reach for `--full` when a human wants the complete, banner-formatted artifact.
- If a compact diff shows a `... truncated` marker and the user needs the omitted
  detail, either raise `--max-lines` or re-run the specific file with plain
  `git diff <A> <B> -- <path>`.
- The compaction is a Python port of rtk's (Rust Token Killer) `compact_diff`; if
  you want live per-command compaction across a whole session instead of a one-off
  report, that's what the `rtk` binary itself is for.
- The report is deterministic; don't paraphrase it as if you inspected the code —
  run the script and share/attach its output.
