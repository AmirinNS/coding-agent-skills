"""Runnable check for web_fetch.py. Run: python3 tests/test_web_fetch.py; prints ok."""
import contextlib
import io
import json
import sys
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True  # keep __pycache__ out of the skill folder

import web_fetch  # noqa: E402


def droid_stdout(result_text, is_error=False):
    event = {"type": "result", "subtype": "success", "is_error": is_error, "result": result_text}
    return json.dumps(event) + "\n"


def stub_exec(result_text, is_error=False):
    def fake(args, timeout):
        return 0, droid_stdout(result_text, is_error), ""

    return fake


def run_main(argv):
    """Run main() with stdout and stderr captured. Returns (exit_code, out, err)."""
    out_buffer, err_buffer = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out_buffer), contextlib.redirect_stderr(err_buffer):
        code = web_fetch.main(argv)
    return code, out_buffer.getvalue(), err_buffer.getvalue()


def droid_patch():
    """Context manager that makes main() believe the droid binary exists."""
    return mock.patch.object(web_fetch, "which_droid", lambda: "/usr/local/bin/droid")


def test_validate_url_accepts_public():
    assert web_fetch.validate_url("https://example.com") is None
    assert web_fetch.validate_url("http://example.com/a/b?page=2&lang=en") is None
    assert web_fetch.validate_url("https://1.1.1.1/") is None
    assert web_fetch.validate_url("https://sub.domain.co.uk/path#frag") is None


def test_validate_url_rejects_scheme():
    for url in [
        "file:///etc/passwd",
        "ftp://example.com/x",
        "javascript:alert(1)",
        "data:text/html,hi",
        "example.com/no-scheme",
    ]:
        assert web_fetch.validate_url(url) is not None, url


def test_validate_url_rejects_credentials():
    assert "credentials" in web_fetch.validate_url("https://user:pass@example.com")
    assert "credentials" in web_fetch.validate_url("https://token@example.com")


def test_validate_url_rejects_private_hosts():
    for url in [
        "http://localhost:8888/",
        "http://127.0.0.1/",
        "http://127.1.2.3/",
        "http://0.0.0.0/",
        "http://10.0.0.5/",
        "http://192.168.1.1/",
        "http://172.16.0.1/",
        "http://169.254.169.254/latest/meta-data",
        "http://[::1]/",
        "http://printer.local/",
        "http://db.internal/",
    ]:
        assert web_fetch.validate_url(url) is not None, url


def test_validate_url_rejects_secret_params():
    for url in [
        "https://example.com/api?access_token=abc",
        "https://example.com/api?api_key=abc",
        "https://example.com/x?session=abc",
        "https://example.com/x?signature=abc",
    ]:
        assert "secret" in web_fetch.validate_url(url), url


def test_strip_fences():
    assert web_fetch.strip_fences("```markdown\n# T\nbody\n```") == "# T\nbody"
    assert web_fetch.strip_fences("```\n# T\n```") == "# T"
    assert web_fetch.strip_fences("# plain\nbody") == "# plain\nbody"


def test_parse_result_event_takes_last():
    stdout = (
        json.dumps({"type": "log", "message": "thinking"})
        + "\n"
        + droid_stdout("first")
        + droid_stdout("second")
    )
    assert web_fetch.parse_result_event(stdout)["result"] == "second"
    assert web_fetch.parse_result_event("not json at all") is None


def test_fetch_page_truncates_and_strips():
    long_text = "y" * (web_fetch.TEXT_LIMIT + 100)
    with mock.patch.object(web_fetch, "_exec", stub_exec("```markdown\n" + long_text + "\n```")):
        text, error = web_fetch.fetch_page("https://a.com", 30)
    assert error is None and len(text) == web_fetch.TEXT_LIMIT and text[0] == "y"


def test_fetch_page_empty_content_is_error():
    with mock.patch.object(web_fetch, "_exec", stub_exec("   ")):
        text, error = web_fetch.fetch_page("https://a.com", 30)
    assert text == "" and error == "page returned no content"


def test_fetch_page_relayed_tool_error_is_not_content():
    """A failed fetch arrives as the model's reply; it must not pass as a page."""
    reply = (
        "Fetch failed. The URL points to a PDF (`application/pdf` binary file),"
        " and the FetchUrl tool rejects binary files with: Cannot process binary"
        " files, HTTP 400."
    )
    with mock.patch.object(web_fetch, "_exec", stub_exec(reply)):
        text, error = web_fetch.fetch_page("https://a.com/x.pdf", 30)
    assert text == "" and "fetch failed" in error and "PDF" in error


def test_fetch_page_error_prefix_contract():
    with mock.patch.object(web_fetch, "_exec", stub_exec("FETCH_ERROR: 403 Forbidden")):
        text, error = web_fetch.fetch_page("https://a.com", 30)
    assert text == "" and "403 Forbidden" in error


def test_build_prompt_has_error_contract():
    assert "FETCH_ERROR: " in web_fetch.build_prompt("https://a.com")


def test_fetch_page_missing_binary():
    def fake(args, timeout):
        raise FileNotFoundError("droid")

    with mock.patch.object(web_fetch, "_exec", fake):
        text, error = web_fetch.fetch_page("https://a.com", 30)
    assert text == "" and "not found on PATH" in error


def test_main_prints_headers_and_exit_0():
    replies = {"https://a.com": "# A\nbody a", "https://b.com": "# B\nbody b"}

    def fake(args, timeout):
        prompt = args[-1]
        for url, reply in replies.items():
            if prompt.endswith(f"URL: {url}"):
                return 0, droid_stdout(reply), ""
        raise AssertionError(f"unexpected prompt: {prompt}")

    with mock.patch.object(web_fetch, "_exec", fake), droid_patch():
        code, out, err = run_main(["https://a.com", "https://b.com"])
    assert code == 0 and err == ""
    assert out == "===== https://a.com =====\n# A\nbody a\n\n===== https://b.com =====\n# B\nbody b\n"


def test_main_invalid_url_blocks_before_fetch():
    exec_mock = mock.Mock()
    with mock.patch.object(web_fetch, "_exec", exec_mock), droid_patch():
        code, out, err = run_main(["http://localhost/admin"])
        assert not exec_mock.called  # no process spawned for a refused URL
    assert code == 1 and out == ""
    assert "localhost" in err


def test_main_partial_failure_exit_0():
    def fake(args, timeout):
        prompt = args[-1]
        if prompt.endswith("URL: https://bad.com"):
            return 1, "", "fetch failed"
        return 0, droid_stdout("# ok"), ""

    with mock.patch.object(web_fetch, "_exec", fake), droid_patch():
        code, out, err = run_main(["https://good.com", "https://bad.com"])
    assert code == 0
    assert "===== https://good.com =====" in out
    assert "error: https://bad.com: droid exec exited 1" in err


def test_main_all_fail_exit_1():
    with mock.patch.object(web_fetch, "_exec", stub_exec("", is_error=True)), droid_patch():
        code, out, err = run_main(["https://a.com"])
    assert code == 1 and out == ""
    assert "error: https://a.com" in err


def test_main_missing_droid_exit_1():
    with mock.patch.object(web_fetch, "which_droid", lambda: None):
        code, out, err = run_main(["https://a.com"])
    assert code == 1 and out == ""
    assert "not found on PATH" in err


def _run_all():
    tests = [(name, fn) for name, fn in sorted(globals().items()) if name.startswith("test_")]
    for name, fn in tests:
        fn()
        print(f"ok {name}")
    print(f"{len(tests)} tests passed")


if __name__ == "__main__":
    _run_all()
