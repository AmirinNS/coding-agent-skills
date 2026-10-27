"""Download files from public URLs with curl, then verify what actually arrived.

Usage:
    python3 web_download.py URL [URL ...] [--out DIR] [--name NAME] [--force]
        [--max-bytes N] [--timeout SECONDS]

Downloads to a `.part` file, checks the bytes against the extension (a site
that returns an HTML error page for a `.pdf` URL is caught here), then moves it
into place. Prints a JSON envelope on stdout: requested, count, files, errors.
Progress and failures go to stderr. Exit code is 1 when no file was saved.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

CURL = "curl"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
DEFAULT_TIMEOUT = 300
PART_SUFFIX = ".part"
BLOCKED_HOST_SUFFIXES = (".local", ".internal")
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
# Magic bytes per extension, checked when known. Text formats (csv, json, txt)
# carry no magic and are verified only against the HTML-error-page check.
MAGIC_PREFIXES = {
    ".pdf": b"%PDF",
    ".png": b"\x89PNG",
    ".jpg": b"\xff\xd8\xff",
    ".jpeg": b"\xff\xd8\xff",
    ".gif": b"GIF8",
    ".webp": b"RIFF",
    ".zip": b"PK\x03\x04",
    ".gz": b"\x1f\x8b",
    ".ico": b"\x00\x00\x01\x00",
}
MAGIC_AT_OFFSET = {".mp4": (4, b"ftyp")}
HTML_MARKERS = (b"<!doctype html", b"<html")
MAX_NAME_LENGTH = 120


def log(message):
    """Progress goes to stderr so stdout stays pure JSON."""
    print(message, file=sys.stderr)


def validate_url(url):
    """Refusal reason for a URL, or None when it is safe to download.

    Same limits as the web-fetch skill: public http(s) only, no credentials, no
    secrets in the query string, no loopback or private-network hosts.
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
    import ipaddress

    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        ip = None
    if ip is not None and (
        ip.is_loopback or ip.is_private or ip.is_link_local
        or ip.is_reserved or ip.is_multicast or ip.is_unspecified
    ):
        return f"host {host!r} is a private, loopback, or link-local address"
    for param in parse_qs(parsed.query, keep_blank_values=True):
        if param.lower() in SECRET_PARAMS:
            return f"query parameter {param!r} looks like a secret"
    return None


def sanitize_filename(name):
    """A safe single path segment, or 'download' when nothing usable remains."""
    cleaned = re.sub(r"[\\/\x00-\x1f\x7f]", "_", (name or "").strip())
    cleaned = cleaned.strip().strip(".")
    cleaned = re.sub(r"\s+", " ", cleaned)[:MAX_NAME_LENGTH].strip()
    return cleaned or "download"


def filename_from_url(url):
    """Last path segment, percent-decoded, or 'download' when there is none."""
    path = urlparse(url.strip()).path
    name = unquote(path.rsplit("/", 1)[-1]) if path else ""
    return sanitize_filename(name)


def parse_content_type(headers_text):
    for line in (headers_text or "").splitlines():
        if line.lower().startswith("content-type:"):
            return line.split(":", 1)[1].strip().split(";")[0].lower()
    return ""


def filename_from_headers(headers_text):
    """Filename from a Content-Disposition header, or None when absent."""
    for line in (headers_text or "").splitlines():
        if not line.lower().startswith("content-disposition:"):
            continue
        value = line.split(":", 1)[1]
        extended = re.search(r"filename\*=\s*([^']+)'[^']*'([^;]+)", value)
        if extended:
            return sanitize_filename(unquote(extended.group(2)))
        plain = re.search(r'filename\s*=\s*"([^"]+)"', value)
        if plain:
            return sanitize_filename(plain.group(1))
        bare = re.search(r"filename\s*=\s*([^;]+)", value)
        if bare:
            return sanitize_filename(bare.group(1))
    return None


def verify_download(path):
    """Check the saved bytes. Returns (ok, reason)."""
    size = path.stat().st_size if path.exists() else 0
    if size == 0:
        return False, "file is empty"
    with open(path, "rb") as handle:
        head = handle.read(1024)
    lowered = head.lower()
    if any(marker in lowered for marker in HTML_MARKERS):
        return False, "saved content is an HTML page (login wall, error page, or redirect)"
    suffix = path.suffix.lower()
    expected = MAGIC_PREFIXES.get(suffix)
    if expected and not head.startswith(expected):
        return False, f"content does not look like {suffix} (expected magic {expected!r})"
    if suffix in MAGIC_AT_OFFSET:
        offset, expected = MAGIC_AT_OFFSET[suffix]
        if head[offset:offset + len(expected)] != expected:
            return False, f"content does not look like {suffix} (no {expected!r} at offset {offset})"
    return True, ""


def resolve_target(out_dir, url, name, headers_text, force):
    """Final path for a download. Returns (path, error)."""
    if name:
        filename = sanitize_filename(name)
    else:
        filename = filename_from_headers(headers_text) or filename_from_url(url)
    target = (Path(out_dir).expanduser() / filename).resolve()
    if target.exists() and not force:
        return None, f"{target} already exists (pass --force to overwrite)"
    return target, None


def build_curl_args(url, part_path, timeout, resume, max_bytes):
    args = [
        CURL,
        "--location",
        "--fail",
        "--silent",
        "--show-error",
        "--retry", "2",
        "--max-time", str(timeout),
        "--user-agent", USER_AGENT,
        "--output", str(part_path),
        "--dump-header", str(part_path) + ".headers",
    ]
    if resume:
        args += ["--continue-at", "-"]
    if max_bytes:
        args += ["--max-filesize", str(max_bytes)]
    args.append(url)
    return args


def _curl(args, timeout):
    """Subprocess seam so tests can stub curl."""
    proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    return proc.returncode, proc.stdout, proc.stderr


def _clean_scratch(part_path, headers_path):
    """Drop scratch files after a failure. A part with bytes is a resumable
    partial, so it stays and the next run continues it; an empty one is junk."""
    headers_path.unlink(missing_ok=True)
    if part_path.exists() and part_path.stat().st_size > 0:
        log(f"[INFO] kept {part_path.name} ({part_path.stat().st_size} bytes); re-run to resume")
    else:
        part_path.unlink(missing_ok=True)


def download_one(url, out_dir, name, force, timeout, max_bytes):
    """Download and verify one URL. Returns (record, error)."""
    reason = validate_url(url)
    if reason:
        return None, reason

    scratch = Path(out_dir).expanduser()
    scratch.mkdir(parents=True, exist_ok=True)
    # A name is needed before the curl call only for the part path; the final
    # name can still come from Content-Disposition after the headers land.
    stem = sanitize_filename(name) if name else filename_from_url(url)
    part_path = (scratch / (stem + PART_SUFFIX)).resolve()
    part_path.parent.mkdir(parents=True, exist_ok=True)
    resume = part_path.exists() and part_path.stat().st_size > 0
    if resume:
        log(f"[INFO] resuming {part_path.name} ({part_path.stat().st_size} bytes already there)")

    args = build_curl_args(url, part_path, timeout, resume, max_bytes)
    headers_path = Path(str(part_path) + ".headers")
    try:
        code, _out, err = _curl(args, timeout + 30)
    except FileNotFoundError:
        return None, "curl is not installed"
    except subprocess.TimeoutExpired:
        _clean_scratch(part_path, headers_path)
        return None, f"curl timed out after {timeout}s"
    if code != 0:
        detail = (err or "").strip().replace("\n", " ")[:200]
        _clean_scratch(part_path, headers_path)
        return None, f"curl exited {code}: {detail or 'download failed'}"

    headers_text = headers_path.read_text(encoding="utf-8", errors="replace") if headers_path.exists() else ""
    target, error = resolve_target(out_dir, url, name, headers_text, force)
    if error:
        _clean_scratch(part_path, headers_path)
        return None, error

    ok, why = verify_download(part_path)
    if not ok:
        size = part_path.stat().st_size
        part_path.unlink(missing_ok=True)
        headers_path.unlink(missing_ok=True)
        return None, f"{why} ({size} bytes received)"

    part_path.replace(target)
    headers_path.unlink(missing_ok=True)
    record = {
        "url": url,
        "path": str(target),
        "bytes": target.stat().st_size,
        "content_type": parse_content_type(headers_text),
    }
    return record, None


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Download and verify files with curl")
    parser.add_argument("urls", nargs="+", help="One or more http(s) URLs")
    parser.add_argument("--out", default=".", help="Directory to save into (default: cwd)")
    parser.add_argument("--name", default=None, help="Filename to save as (skips Content-Disposition)")
    parser.add_argument("--force", action="store_true", help="Overwrite an existing file")
    parser.add_argument("--max-bytes", type=int, default=None, help="Abort if the file exceeds this size")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="Seconds for the whole transfer")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    files, errors = [], []
    for url in args.urls:
        log(f"[INFO] downloading {url}")
        record, error = download_one(url, args.out, args.name, args.force, args.timeout, args.max_bytes)
        if error:
            log(f"[ERROR] {url}: {error}")
            errors.append({"url": url, "error": error})
            continue
        log(f"[OK] {record['path']} ({record['bytes']} bytes)")
        files.append(record)

    envelope = {"requested": args.urls, "count": len(files), "files": files, "errors": errors}
    print(json.dumps(envelope, indent=2, ensure_ascii=False))
    return 0 if files else 1


if __name__ == "__main__":
    sys.exit(main())
