"""Runnable check for web_search.py. Run: python3 tests/test_web_search.py; prints ok."""
import contextlib
import io
import json
import sys
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True  # keep __pycache__ out of the skill folder

import web_search  # noqa: E402


def droid_stdout(result_text, is_error=False):
    event = {"type": "result", "subtype": "success", "is_error": is_error, "result": result_text}
    return json.dumps(event) + "\n"


def stub_exec(result_text, is_error=False):
    def fake(args, timeout):
        return 0, droid_stdout(result_text, is_error), ""

    return fake


def run_main(argv):
    """Run main() with stdout captured. Returns (exit_code, envelope_dict)."""
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        code = web_search.main(argv)
    return code, json.loads(buffer.getvalue())


def droid_patch():
    """Context manager that makes main() believe the droid binary exists."""
    return mock.patch.object(web_search, "which_droid", lambda: "/usr/local/bin/droid")


def test_extract_json():
    array = '[{"title": "t", "url": "https://a.com", "snippet": "s"}]'
    assert web_search.extract_json(array) == json.loads(array)
    assert len(web_search.extract_json("Sure! Here you go:\n" + array)) == 1
    assert len(web_search.extract_json("```json\n" + array + "\n```")) == 1
    assert web_search.extract_json("I could not search.") is None
    assert web_search.extract_json("[{broken") is None
    assert web_search.extract_json('{"knowledge": {"temp": 30}, "results": []}')["knowledge"]["temp"] == 30


def test_normalize_posts():
    items = [
        {"title": " A ", "url": "https://www.Ex.com/a", "snippet": " s "},
        {"title": "no url"},
        {"url": "https://b.com"},
        "not a dict",
    ]
    posts = web_search.normalize_posts(items, "q")
    assert [p["rank"] for p in posts] == [1, 2]
    assert posts[0] == {
        "rank": 1,
        "title": "A",
        "url": "https://www.Ex.com/a",
        "domain": "ex.com",
        "engine": "websearch",
        "keyword": "q",
        "snippet": "s",
        "text": "",
    }
    assert posts[1]["title"] == "" and posts[1]["snippet"] == ""


def test_dedupe():
    posts = web_search.normalize_posts(
        [
            {"url": "https://a.com/x", "title": "first"},
            {"url": "http://www.a.com/x/", "title": "dup"},
            {"url": "https://a.com/y", "title": "other"},
            {"url": "https://a.com/x?utm_source=nn", "title": "not a dup"},
        ],
        "q",
    )
    kept = web_search.dedupe(posts)
    assert [p["title"] for p in kept] == ["first", "other", "not a dup"]


def test_build_prompt():
    prompt = web_search.build_prompt("python 3.14", 5, False)
    assert "python 3.14" in prompt and "numResults=5" in prompt
    assert "JSON array" in prompt and "knowledge" not in prompt
    knowledge_prompt = web_search.build_prompt("aapl price", 5, True)
    assert 'knowledge="core"' in knowledge_prompt and '"results"' in knowledge_prompt


def test_search_query_retries_once():
    calls = []

    def fake(args, timeout):
        calls.append(args)
        if len(calls) == 1:
            return 0, droid_stdout("the model rambled"), ""
        return 0, droid_stdout('[{"title": "t", "url": "https://a.com", "snippet": "s"}]'), ""

    with mock.patch.object(web_search, "_exec", fake):
        posts, answer, error = web_search.search_query("q", 10, False, 30)
    assert error is None and len(posts) == 1 and posts[0]["url"] == "https://a.com"
    assert len(calls) == 2  # one failure, one retry, no third attempt


def test_search_query_gives_up_after_one_retry():
    calls = []

    def fake(args, timeout):
        calls.append(args)
        return 0, droid_stdout("nope"), ""

    with mock.patch.object(web_search, "_exec", fake):
        posts, answer, error = web_search.search_query("q", 10, False, 30)
    assert posts == [] and answer is None and error == "model reply contained no parseable JSON"
    assert len(calls) == 2


def test_search_query_reports_exec_failure():
    def fake(args, timeout):
        return 1, "", "boom"

    with mock.patch.object(web_search, "_exec", fake):
        posts, _answer, error = web_search.search_query("q", 10, False, 30)
    assert posts == [] and "exited 1" in error


def test_search_query_missing_binary():
    def fake(args, timeout):
        raise FileNotFoundError("droid")

    with mock.patch.object(web_search, "_exec", fake):
        posts, _answer, error = web_search.search_query("q", 10, False, 30)
    assert posts == [] and "not found on PATH" in error


def test_fetch_page_truncates():
    long_text = "x" * (web_search.TEXT_LIMIT + 500)
    with mock.patch.object(web_search, "_exec", stub_exec(long_text)):
        text, error = web_search.fetch_page("https://a.com", 30)
    assert error is None and len(text) == web_search.TEXT_LIMIT


def test_main_envelope_and_exit_code():
    replies = {
        "one": '[{"title": "t1", "url": "https://a.com", "snippet": "s1"}]',
        "two": '[{"title": "t2", "url": "https://a.com", "snippet": "dup"},'
        ' {"title": "t3", "url": "https://b.com", "snippet": "s3"}]',
    }

    def fake(args, timeout):
        prompt = args[-1]
        for keyword, reply in replies.items():
            if f"Search the web for: {keyword}" in prompt:
                return 0, droid_stdout(reply), ""
        raise AssertionError(f"unexpected prompt: {prompt}")

    with mock.patch.object(web_search, "_exec", fake), droid_patch():
        code, envelope = run_main(["one", "two", "--max", "3"])
    assert code == 0
    assert envelope["keywords"] == ["one", "two"]
    assert envelope["count"] == 2  # a.com deduped across queries
    assert [p["url"] for p in envelope["posts"]] == ["https://a.com", "https://b.com"]
    assert envelope["posts"][0]["keyword"] == "one"
    assert envelope["errors"] == []


def test_main_all_fail_exit_1():
    def fake(args, timeout):
        return 0, droid_stdout("nothing"), ""

    with mock.patch.object(web_search, "_exec", fake), droid_patch():
        code, envelope = run_main(["one"])
    assert code == 1
    assert envelope["count"] == 0 and len(envelope["errors"]) == 1


def test_main_missing_droid_exit_1():
    with mock.patch.object(web_search, "which_droid", lambda: None):
        code, envelope = run_main(["one"])
    assert code == 1
    assert "not found on PATH" in envelope["errors"][0]["error"]


def test_main_fetch_fills_text():
    search_reply = '[{"title": "t", "url": "https://a.com", "snippet": "s"}]'

    def fake(args, timeout):
        if args[3] == web_search.TOOL_FETCH:
            return 0, droid_stdout("page body"), ""
        return 0, droid_stdout(search_reply), ""

    with mock.patch.object(web_search, "_exec", fake), droid_patch():
        code, envelope = run_main(["one", "--fetch"])
    assert code == 0
    assert envelope["posts"][0]["text"] == "page body"


def test_main_knowledge_answer():
    reply = '{"knowledge": {"temp_c": 30}, "results": [{"url": "https://a.com"}]}'
    with mock.patch.object(web_search, "_exec", stub_exec(reply)), droid_patch():
        code, envelope = run_main(["weather in kuala lumpur", "--knowledge"])
    assert code == 0
    assert envelope["knowledge"] == {"temp_c": 30}


def test_max_clamped():
    assert web_search.parse_args(["q", "--max", "100"]).max == web_search.MAX_RESULTS_LIMIT
    assert web_search.parse_args(["q", "--max", "0"]).max == 1
    assert web_search.parse_args(["q"]).max == 10


def _run_all():
    tests = [(name, fn) for name, fn in sorted(globals().items()) if name.startswith("test_")]
    for name, fn in tests:
        fn()
        print(f"ok {name}")
    print(f"{len(tests)} tests passed")


if __name__ == "__main__":
    _run_all()
