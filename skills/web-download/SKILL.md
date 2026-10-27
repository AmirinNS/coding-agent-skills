---
name: web-download
description: "Download files from public URLs with curl, then verify what actually arrived before keeping it: magic bytes checked against the extension, HTML error pages and login walls rejected, existing files never clobbered without --force, interrupted transfers resumable. No API key and no browser. Use for PDFs, images, archives, datasets, release artifacts, and any binary that web-fetch cannot read as Markdown. Triggers: 'download this file', 'save this pdf', 'fetch this dataset', 'grab this archive', 'download this link'. Not for whole-site mirroring or authenticated downloads. Takes one or more URLs."
---

# Web download

Save files from public URLs with `curl`, then check the bytes before calling it
a success. Backed by `scripts/web_download.py` in this skill folder.

This is the binary counterpart to `web-fetch`. FetchUrl reads a page as
Markdown and rejects binaries outright, so anything that is not a readable
page lands here.

## When to use

- The user gives a URL that should become a file on disk: a PDF, an image, an
  archive, a dataset, a release artifact.
- The download matters enough that a silent failure is unacceptable (a site
  returning an HTML error page saved as `.pdf` looks fine until you open it).

Do **not** use for: whole-site mirroring or crawling (`wget --mirror`, or
`site-clone` when JS rendering matters), downloads that need a login or
cookies (use the browser with a warmed profile instead), or reading a page's
text (`web-fetch`).

## How to run

```bash
python3 <skill-dir>/scripts/web_download.py URL [URL ...] --out DIR
```

- Files land in `--out` (default: the current directory). The name comes from
  `Content-Disposition` when the server sends one, otherwise from the URL's
  last path segment. `--name` overrides both.
- Progress and failures go to **stderr**. A JSON envelope is the only thing on
  **stdout**: `requested`, `count`, `files` (url, path, bytes, content_type),
  and `errors`. Exit code is 1 when no file was saved.
- Multiple URLs run in sequence; one failure does not stop the rest.

## What it verifies

- **Refuses unsafe URLs before spawning curl**: non-http(s) schemes, URLs with
  credentials, secret-looking query parameters (`token`, `api_key`, ...), and
  loopback or private-network hosts.
- **Non-empty.** A zero-byte response is a failure.
- **Not an HTML page.** A response starting with `<!doctype html` or `<html`
  is a login wall, error page, or redirect, never the file you asked for.
- **Magic bytes match the extension** when the format has known ones: `%PDF`
  for `.pdf`, `\x89PNG` for `.png`, `PK` for `.zip`, `ftyp` at offset 4 for
  `.mp4`, and so on. Text formats (csv, json, txt) have no magic and pass on
  the HTML check alone.
- **Never overwrites silently.** An existing target is refused unless
  `--force` is passed.
- **HTTP errors fail loudly.** curl runs with `--fail`, so a 404 or 403 exits
  non-zero instead of saving the error body.

## Choosing options

| Goal | Flags |
|------|-------|
| Save into a specific directory | `--out ~/Downloads/report` |
| Force a filename | `--name report.pdf` |
| Overwrite an existing file | `--force` |
| Abort oversized files | `--max-bytes 50000000` |
| Long or slow transfers | `--timeout 600` |

## Notes & limits

- **Resume.** Downloads stream to `<name>.part`. Re-running the same command
  continues the partial file with curl's `--continue-at -`, so an interrupted
  big file finishes instead of restarting. A failed transfer keeps its partial
  when it has bytes and says so on stderr; scratch `.headers` files are always
  cleaned up.
- **No authentication.** No cookies, no tokens, no headers. A URL that needs a
  login returns the login page, which the HTML check rejects with a clear
  message. For gated content, download through the browser with a warmed
  profile.
- **curl is the only dependency.** It ships with macOS and most Linux images.
- Runnable check for the logic (no network needed):
  `python3 <skill-dir>/tests/test_web_download.py`.
