"""Fetch public web pages as Markdown through the droid CLI's built-in FetchUrl tool.

Usage:
    python3 web_fetch.py URL [URL ...] [--timeout SECONDS]

Each URL runs one `droid exec --only-tools FetchUrl` process, which authenticates
with the droid CLI's existing login. No fetch API key and no headless browser are
needed. Prints each page's readable Markdown to stdout under a `===== URL =====`
header. Errors go to stderr. Exit code is 1 when no page was fetched.
"""
import argparse
import ipaddress
import json
import re
import subprocess
import sys
from urllib.parse import parse_qs, urlparse

TOOL_FETCH = "FetchUrl"
TEXT_LIMIT = 20000
DEFAULT_TIMEOUT = 120
BLOCKED_HOST_SUFFIXES = (".local", ".internal")
ERROR_PREFIXES = ("FETCH_ERROR:", "Fetch failed")
SECRET_PARAMS = {
    "access_token",
    "api_key",
    "apikey",
    "auth",
    "key",
    "password",
    "passwd",
    "secret",
    "session",
    "sessionid",
    "sig",
    "signature",
    "token",
}


def validate_url(url):
    """Refusal reason for a URL, or None when it is safe to fetch.

    Mirrors the FetchUrl tool's limits: public http(s) only, no credentials, no
    secrets in the query string, no loopback or private-network hosts. Hostnames
    are checked by name; DNS rebinding to a private address is out of scope.
    """
    parsed = urlparse(url.strip())
    if parsed.scheme not in ("http", "https"):
        return f"scheme {parsed.scheme or '(missing)'!r} is not http or https"
    if parsed.username or parsed.password:
        return "URL carries credentials"
    host = (parsed.hostname or "").lower()
    if not host:
        return "URL has no host"
    if host == "localhost" or host.endswith(BLOCKED_HOST_SUFFIXES):
        return f"host {host!r} is not a public address"
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        ip = None
    if ip is not None and (
        ip.is_loopback
        or ip.is_private
        or ip.is_link_local
        or ip.is_reserved
        or ip.is_multicast
        or ip.is_unspecified
    ):
        return f"host {host!r} is a private, loopback, or link-local address"
    for param in parse_qs(parsed.query, keep_blank_values=True):
        if param.lower() in SECRET_PARAMS:
            return f"query parameter {param!r} looks like a secret"
    return None


def build_prompt(url):
    return (
        "Fetch this page with the FetchUrl tool and reply with ONLY its content as"
        f" Markdown, truncated to {TEXT_LIMIT} characters. No commentary, no summary."
        ' If the fetch fails, start your reply with "FETCH_ERROR: " followed by the'
        f" reason and say nothing else. URL: {url}"
    )


def strip_fences(text):
    """Drop a markdown code fence the model may have wrapped its reply in."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:markdown|md)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    return text


def parse_result_event(stdout):
    """Last result event from `droid exec --output-format json`, or None."""
    event = None
    for line in stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            candidate = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(candidate, dict) and candidate.get("type") == "result":
            event = candidate
    return event


def _exec(args, timeout):
    """Subprocess seam so tests can stub the droid CLI."""
    proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    return proc.returncode, proc.stdout, proc.stderr


def run_droid(prompt, timeout):
    """One droid exec call restricted to FetchUrl. Returns (result_text, error)."""
    args = ["droid", "exec", "--only-tools", TOOL_FETCH, "--output-format", "json", prompt]
    try:
        code, out, err = _exec(args, timeout)
    except FileNotFoundError:
        return None, "droid CLI not found on PATH. Install Factory Droid and log in."
    except subprocess.TimeoutExpired:
        return None, f"droid exec timed out after {timeout}s"
    if code != 0:
        detail = (err or out or "").strip().replace("\n", " ")[:300]
        return None, f"droid exec exited {code}: {detail}"
    event = parse_result_event(out)
    if event is None:
        return None, "no result event in droid exec output"
    if event.get("is_error"):
        return None, f"droid exec reported an error: {str(event.get('result'))[:300]}"
    return str(event.get("result") or ""), None


def fetch_page(url, timeout):
    """Readable Markdown for one validated URL. Returns (text, error).

    A refused or failed fetch reaches us as the model's reply text, so a reply
    that opens with an error marker is a failure, not page content.
    """
    text, error = run_droid(build_prompt(url), timeout)
    if error:
        return "", error
    text = strip_fences(text)[:TEXT_LIMIT]
    for prefix in ERROR_PREFIXES:
        if text.startswith(prefix):
            return "", f"fetch failed: {text[len(prefix):].strip()[:200]}"
    if not text.strip():
        return "", "page returned no content"
    return text, None


def which_droid():
    """Path to the droid binary, or None when it is not installed."""
    import shutil

    return shutil.which("droid")


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Fetch web pages as Markdown via the droid CLI.")
    parser.add_argument("urls", nargs="+", help="One or more http(s) URLs")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="Seconds per droid exec call")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if which_droid() is None:
        for url in args.urls:
            print(f"error: {url}: droid CLI not found on PATH. Install Factory Droid and log in.", file=sys.stderr)
        return 1

    fetched = 0
    for url in args.urls:
        reason = validate_url(url)
        if reason:
            print(f"error: {url}: {reason}", file=sys.stderr)
            continue
        text, error = fetch_page(url, args.timeout)
        if error:
            print(f"error: {url}: {error}", file=sys.stderr)
            continue
        if fetched:
            print()
        print(f"===== {url} =====")
        print(text)
        fetched += 1
    return 0 if fetched else 1


if __name__ == "__main__":
    sys.exit(main())
