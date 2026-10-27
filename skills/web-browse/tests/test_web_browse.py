"""Runnable check for web_browse.py. Run: python3 tests/test_web_browse.py; prints ok.

Pure-function checks only, so any python3 works. The browser path needs
Playwright plus real Chrome and is verified by running the script directly.
"""
import contextlib
import io
import json
import sys
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True  # keep __pycache__ out of the skill folder

import web_browse  # noqa: E402


def test_domain():
    assert web_browse._domain("https://www.example.com/a") == "example.com"
    assert web_browse._domain("https://docs.python.org/3/") == "docs.python.org"
    assert web_browse._domain("not a url") == ""


def test_unwrap_bing_redirect():
    # u=a1 + base64url("https://www.example.com/")
    wrapped = (
        "https://www.bing.com/ck/a?!&&p=abc&u=a1aHR0cHM6Ly93d3cuZXhhbXBsZS5jb20v&ntb=1"
    )
    assert web_browse._unwrap_bing_redirect(wrapped) == "https://www.example.com/"
    plain = "https://www.example.com/"
    assert web_browse._unwrap_bing_redirect(plain) == plain
    assert web_browse._unwrap_bing_redirect("https://www.bing.com/ck/a?u=garbage") == \
        "https://www.bing.com/ck/a?u=garbage"


def test_merge_unique_dedupes_first_wins():
    all_posts, seen = [], set()
    first = {"rank": 1, "title": "first", "url": "https://a.com", "keyword": "q1"}
    added = web_browse.merge_unique(all_posts, seen, [first, {"url": "https://b.com"}])
    assert added == 2
    # same URL from a second query is dropped; a different URL is kept
    added = web_browse.merge_unique(
        all_posts, seen, [{"url": "https://a.com", "title": "dup"}, {"url": "https://c.com"}]
    )
    assert added == 1
    assert [p["url"] for p in all_posts] == ["https://a.com", "https://b.com", "https://c.com"]
    assert all_posts[0]["title"] == "first"


def test_merge_unique_skips_empty_urls():
    all_posts, seen = [], set()
    added = web_browse.merge_unique(all_posts, seen, [{"url": ""}, {"title": "no url"}])
    assert added == 0 and all_posts == []


def test_build_envelope():
    envelope = web_browse.build_envelope(["q"], ["brave"], [{"url": "u"}], [{"error": "e"}])
    assert envelope == {
        "keywords": ["q"],
        "engines": ["brave"],
        "count": 1,
        "posts": [{"url": "u"}],
        "errors": [{"error": "e"}],
    }


def test_blocked_reason():
    challenge = (
        "Verifying you're not a bot\nQuick check before you continue searching.\n"
        "Verify\nSwitch to traditional CAPTCHA"
    )
    assert "bot-check" in web_browse.blocked_reason(
        "https://search.brave.com/search?q=x", challenge)
    assert "CAPTCHA" in web_browse.blocked_reason(
        "https://www.google.com/sorry/index?q=x", "redirect notice")
    assert "bot-check" in web_browse.blocked_reason(
        "https://www.bing.com/results?q=x", "Are you a robot?")
    assert web_browse.blocked_reason(
        "https://search.brave.com/search?q=python", "Python 3.14 released October 2025"
    ) is None


def test_engines_config():
    assert set(web_browse.ENGINES) == {"brave", "bing"}
    for name, cfg in web_browse.ENGINES.items():
        for field in ("home", "box", "results_sel", "extract", "page_url"):
            assert cfg.get(field), f"{name} missing {field}"
        assert cfg["home"].startswith("https://")
    assert "offset=1" in web_browse.ENGINES["brave"]["page_url"]("q", 1)
    assert "first=11" in web_browse.ENGINES["bing"]["page_url"]("q", 1)


def test_parse_args_defaults():
    args = web_browse.parse_args(["query"])
    assert args.keywords == ["query"]
    assert args.engine == ["brave"]
    assert args.max == 10
    assert args.fetch is False and args.headless is False and args.profile is None


def test_parse_args_clamps_max():
    assert web_browse.parse_args(["q", "--max", "100"]).max == web_browse.MAX_RESULTS_LIMIT
    assert web_browse.parse_args(["q", "--max", "0"]).max == 1
    assert web_browse.parse_args(["q", "--max", "15"]).max == 15


def test_parse_args_rejects_unknown_engine():
    try:
        web_browse.parse_args(["q", "--engine", "searxng"])
    except SystemExit:
        pass
    else:
        raise AssertionError("searxng must not be an engine for this skill")


def test_log_goes_to_stderr():
    buffer = io.StringIO()
    with contextlib.redirect_stderr(buffer):
        web_browse.log("[INFO] hello")
    assert buffer.getvalue() == "[INFO] hello\n"


def test_main_without_playwright_exits_1():
    with mock.patch.object(web_browse, "async_playwright", None):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = web_browse.main(["q"])
    envelope = json.loads(buffer.getvalue())
    assert code == 1
    assert envelope["count"] == 0 and envelope["posts"] == []
    assert "playwright is not installed" in envelope["errors"][0]["error"]


def _run_all():
    tests = [(name, fn) for name, fn in sorted(globals().items()) if name.startswith("test_")]
    for name, fn in tests:
        fn()
        print(f"ok {name}")
    print(f"{len(tests)} tests passed")


if __name__ == "__main__":
    _run_all()
