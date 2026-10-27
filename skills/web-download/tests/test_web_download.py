"""Runnable check for web_download.py. Run: python3 tests/test_web_download.py; prints ok."""
import contextlib
import io
import json
import sys
import tempfile
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True  # keep __pycache__ out of the skill folder

import web_download  # noqa: E402

PDF = b"%PDF-1.7\nrest of a real pdf body"
PNG = b"\x89PNG\r\n\x1a\n image bytes"
HTML_ERROR = b"<!DOCTYPE html><html><head><title>404 Not Found</title></html><body>nope</body></html>"


def test_sanitize_filename():
    assert web_download.sanitize_filename("report.pdf") == "report.pdf"
    assert web_download.sanitize_filename("my file (1).pdf") == "my file (1).pdf"
    assert web_download.sanitize_filename("..") == "download"
    assert web_download.sanitize_filename("") == "download"
    assert web_download.sanitize_filename("a" * 200) == "a" * web_download.MAX_NAME_LENGTH
    traversal = web_download.sanitize_filename("../../etc/passwd")
    assert "/" not in traversal and "\\" not in traversal and traversal != ".."
    assert "\n" not in web_download.sanitize_filename("bad\nname.pdf")


def test_filename_from_url():
    assert web_download.filename_from_url("https://a.com/x/report.pdf?v=2") == "report.pdf"
    assert web_download.filename_from_url("https://a.com/my%20file.zip") == "my file.zip"
    assert web_download.filename_from_url("https://a.com/") == "download"
    assert web_download.filename_from_url("https://a.com") == "download"


def test_filename_from_headers():
    quoted = 'Content-Disposition: attachment; filename="real name.pdf"'
    assert web_download.filename_from_headers(quoted) == "real name.pdf"
    extended = "Content-Disposition: attachment; filename*=UTF-8''%E6%8A%A5%E5%91%8A.pdf"
    assert web_download.filename_from_headers(extended) == "报告.pdf"
    assert web_download.filename_from_headers("Content-Type: application/pdf") is None
    assert web_download.filename_from_headers("") is None


def test_parse_content_type():
    assert web_download.parse_content_type("Content-Type: application/pdf; charset=utf-8") == "application/pdf"
    assert web_download.parse_content_type("content-type: text/HTML") == "text/html"
    assert web_download.parse_content_type("") == ""


def test_validate_url():
    assert web_download.validate_url("https://example.com/a.pdf") is None
    for bad in [
        "file:///etc/passwd",
        "https://user:pass@example.com",
        "http://localhost/x",
        "http://127.0.0.1/x",
        "http://10.0.0.5/x",
        "http://169.254.169.254/latest/meta-data",
        "http://[::1]/x",
        "http://nas.local/x",
        "https://example.com/api?api_key=abc",
    ]:
        assert web_download.validate_url(bad) is not None, bad


def test_verify_download():
    with tempfile.TemporaryDirectory() as tmp:
        def check(name, payload):
            path = Path(tmp) / name
            path.write_bytes(payload)
            return web_download.verify_download(path)

        assert check("a.pdf", PDF) == (True, "")
        assert check("a.png", PNG) == (True, "")
        assert check("a.csv", b"name,amount\nx,1\n") == (True, "")
        assert check("a.mp4", b"\x00\x00\x00\x18ftypmp42rest") == (True, "")
        ok, why = check("a.pdf", HTML_ERROR)
        assert not ok and "HTML page" in why
        ok, why = check("a.png", PDF)
        assert not ok and "does not look like" in why
        ok, why = check("a.mp4", b"\x00\x00\x00\x18XXXXmp42")
        assert not ok and "offset 4" in why
        empty = Path(tmp) / "empty.pdf"
        empty.write_bytes(b"")
        ok, why = web_download.verify_download(empty)
        assert not ok and "empty" in why


def test_resolve_target():
    with tempfile.TemporaryDirectory() as tmp:
        headers = 'Content-Disposition: attachment; filename="from-header.pdf"'
        path, error = web_download.resolve_target(tmp, "https://a.com/x/url-name.pdf", None, headers, False)
        assert error is None and path.name == "from-header.pdf"
        path, error = web_download.resolve_target(tmp, "https://a.com/x/url-name.pdf", "explicit.zip", headers, False)
        assert path.name == "explicit.zip"
        # an existing target is refused unless forced
        path.write_bytes(b"old")
        path2, error = web_download.resolve_target(tmp, "https://a.com/x/url-name.pdf", "explicit.zip", headers, False)
        assert path2 is None and "already exists" in error
        path3, error = web_download.resolve_target(tmp, "https://a.com/x/url-name.pdf", "explicit.zip", headers, True)
        assert error is None and path3.name == "explicit.zip"


def fake_curl(payloads, headers_for=None):
    """Stub for _curl: writes the payload and headers where curl would."""
    def fake(args, timeout):
        url = args[-1]
        part = Path(args[args.index("--output") + 1])
        payload, headers = payloads.get(url, (HTML_ERROR, "Content-Type: text/html"))
        if headers_for and url in headers_for:
            headers = headers_for[url]
        part.write_bytes(payload)
        Path(str(part) + ".headers").write_text(headers)
        return 0, "", ""

    return fake


def test_download_one_success():
    with tempfile.TemporaryDirectory() as tmp:
        url = "https://a.com/files/report.pdf"
        with mock.patch.object(web_download, "_curl", fake_curl({url: (PDF, "Content-Type: application/pdf")})):
            record, error = web_download.download_one(url, tmp, None, False, 60, None)
        assert error is None
        assert record["bytes"] == len(PDF) and record["content_type"] == "application/pdf"
        assert Path(record["path"]).read_bytes() == PDF
        assert not list(Path(tmp).glob("*.part*")), "scratch files must be cleaned up"


def test_download_one_rejects_html_error_page():
    with tempfile.TemporaryDirectory() as tmp:
        url = "https://a.com/missing.pdf"
        with mock.patch.object(web_download, "_curl", fake_curl({url: (HTML_ERROR, "Content-Type: text/html")})):
            record, error = web_download.download_one(url, tmp, None, False, 60, None)
        assert record is None and "HTML page" in error
        assert list(Path(tmp).iterdir()) == [], "nothing may be left on disk"


def test_download_one_existing_file_needs_force():
    with tempfile.TemporaryDirectory() as tmp:
        url = "https://a.com/report.pdf"
        (Path(tmp) / "report.pdf").write_bytes(b"old")
        with mock.patch.object(web_download, "_curl", fake_curl({url: (PDF, "Content-Type: application/pdf")})):
            record, error = web_download.download_one(url, tmp, None, False, 60, None)
            assert record is None and "already exists" in error
            record, error = web_download.download_one(url, tmp, None, True, 60, None)
        assert error is None and Path(record["path"]).read_bytes() == PDF


def test_download_one_resumes_part_file():
    with tempfile.TemporaryDirectory() as tmp:
        url = "https://a.com/big.zip"
        (Path(tmp) / "big.zip.part").write_bytes(b"PK\x03\x04half")
        seen = {}

        def fake(args, timeout):
            seen["args"] = args
            return fake_curl({url: (b"PK\x03\x04whole", "")})(args, timeout)

        with mock.patch.object(web_download, "_curl", fake):
            record, error = web_download.download_one(url, tmp, None, False, 60, None)
        assert error is None
        assert "--continue-at" in seen["args"] and "-" in seen["args"]


def test_download_one_curl_failure():
    with tempfile.TemporaryDirectory() as tmp:
        def fake(args, timeout):
            Path(args[args.index("--output") + 1]).write_bytes(b"")
            return 22, "", "HTTP 404"

        with mock.patch.object(web_download, "_curl", fake):
            record, error = web_download.download_one("https://a.com/x.pdf", tmp, None, False, 60, None)
        assert record is None and "curl exited 22" in error and "HTTP 404" in error
        assert list(Path(tmp).iterdir()) == [], "scratch files must be cleaned up on failure"


def test_download_one_keeps_resumable_part_on_failure():
    with tempfile.TemporaryDirectory() as tmp:
        def fake(args, timeout):
            part = Path(args[args.index("--output") + 1])
            part.write_bytes(b"%PDF-1.7\nhalf a file")
            return 18, "", "transfer cut short"

        with mock.patch.object(web_download, "_curl", fake):
            record, error = web_download.download_one("https://a.com/x.pdf", tmp, None, False, 60, None)
        assert record is None and "curl exited 18" in error
        kept = list(Path(tmp).iterdir())
        assert [p.name for p in kept] == ["x.pdf.part"], "a partial download must survive for resume"


def test_download_one_refuses_unsafe_url_without_curl():
    with mock.patch.object(web_download, "_curl") as curl_mock:
        record, error = web_download.download_one("http://localhost/x.pdf", ".", None, False, 60, None)
    assert record is None and "localhost" in error
    assert not curl_mock.called


def test_curl_args():
    args = web_download.build_curl_args("https://a.com/x.pdf", Path("/tmp/x.pdf.part"), 60, False, None)
    for flag in ("--location", "--fail", "--user-agent", "--output", "--dump-header"):
        assert flag in args, flag
    assert args[-1] == "https://a.com/x.pdf"
    assert "--continue-at" not in args
    limited = web_download.build_curl_args("https://a.com/x.pdf", Path("/tmp/x.pdf.part"), 60, False, 1000)
    assert limited[limited.index("--max-filesize") + 1] == "1000"


def test_main_envelope():
    good, bad = "https://a.com/ok.pdf", "https://a.com/bad.pdf"

    def fake(args, timeout):
        return fake_curl({good: (PDF, "Content-Type: application/pdf"), bad: (HTML_ERROR, "")})(args, timeout)

    with tempfile.TemporaryDirectory() as tmp, mock.patch.object(web_download, "_curl", fake):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = web_download.main([good, bad, "--out", tmp])
        envelope = json.loads(out.getvalue())
    assert code == 0  # one file saved is a partial success
    assert envelope["count"] == 1 and envelope["files"][0]["url"] == good
    assert envelope["errors"][0]["url"] == bad


def test_main_all_fail_exit_1():
    with tempfile.TemporaryDirectory() as tmp, mock.patch.object(
        web_download, "_curl", fake_curl({"https://a.com/x.pdf": (HTML_ERROR, "")})
    ):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = web_download.main(["https://a.com/x.pdf", "--out", tmp])
    assert code == 1
    assert json.loads(out.getvalue())["count"] == 0


def _run_all():
    tests = [(name, fn) for name, fn in sorted(globals().items()) if name.startswith("test_")]
    for name, fn in tests:
        fn()
        print(f"ok {name}")
    print(f"{len(tests)} tests passed")


if __name__ == "__main__":
    _run_all()
