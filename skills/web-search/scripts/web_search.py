"""Web search through the droid CLI's built-in WebSearch tool.

Usage:
    python3 web_search.py "QUERY" ["QUERY" ...] [--max N] [--fetch] [--knowledge] [--timeout SECONDS]

Each query runs one `droid exec --only-tools WebSearch` process, which authenticates
with the droid CLI's existing login. No search API key and no local search service
are needed. Prints a JSON envelope to stdout with keywords, count, posts, and errors.
Exit code is 1 when every query fails or returns nothing.
"""
import argparse
import json
import re
import subprocess
import sys
from urllib.parse import urlparse

TOOL_SEARCH = "WebSearch"
TOOL_FETCH = "FetchUrl"
MAX_RESULTS_LIMIT = 20
TEXT_LIMIT = 20000
ATTEMPTS_PER_QUERY = 2
DEFAULT_TIMEOUT = 120


def which_droid():
    """Path to the droid binary, or None when it is not installed."""
    import shutil

    return shutil.which("droid")


def build_prompt(query, max_results, knowledge):
    """Prompt that forces one WebSearch call and a machine-readable reply."""
    if knowledge:
        shape = (
            'a JSON object of the form {"knowledge": <structured answer or null>, '
            '"results": [{"title", "url", "snippet"}]}'
        )
        extra = (
            ' If the query asks for live structured facts such as a stock price, weather,'
            ' sports, or government data, call WebSearch with knowledge="core" and put the'
            ' structured answer in "knowledge". Otherwise set "knowledge" to null.'
        )
    else:
        shape = 'a JSON array of objects, each with "title", "url", and "snippet"'
        extra = ""
    return (
        f"Search the web for: {query}\n"
        f"Call the WebSearch tool once with numResults={max_results}.{extra}\n"
        f"Reply with ONLY {shape}. No prose, no markdown code fences."
    )


def build_fetch_prompt(url):
    return (
        "Fetch this page with the FetchUrl tool and reply with ONLY its readable text,"
        f" truncated to {TEXT_LIMIT} characters. No commentary. URL: {url}"
    )


def extract_json(text):
    """First JSON value embedded in a model reply, or None when there is none."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    for index, char in enumerate(text):
        if char not in "[{":
            continue
        try:
            value, _end = json.JSONDecoder().raw_decode(text, index)
        except json.JSONDecodeError:
            continue
        if isinstance(value, (list, dict)):
            return value
    return None


def domain_of(url):
    netloc = urlparse(url.strip()).netloc.lower()
    return netloc[4:] if netloc.startswith("www.") else netloc


def normalize_url(url):
    """Collapse scheme, www, and trailing slash so duplicates match."""
    parsed = urlparse(url.strip())
    netloc = parsed.netloc.lower()
    if netloc.startswith("www."):
        netloc = netloc[4:]
    path = parsed.path.rstrip("/")
    return f"{netloc}{path}?{parsed.query}" if parsed.query else f"{netloc}{path}"


def normalize_posts(items, keyword):
    """Raw result items to post records, dropping anything without a URL."""
    posts = []
    for item in items:
        if not isinstance(item, dict):
            continue
        url = str(item.get("url") or "").strip()
        if not url:
            continue
        posts.append(
            {
                "rank": len(posts) + 1,
                "title": str(item.get("title") or "").strip(),
                "url": url,
                "domain": domain_of(url),
                "engine": "websearch",
                "keyword": keyword,
                "snippet": str(item.get("snippet") or "").strip(),
                "text": "",
            }
        )
    return posts


def dedupe(posts):
    """Keep the first occurrence of each URL across all queries."""
    seen = set()
    unique = []
    for post in posts:
        key = normalize_url(post["url"])
        if key in seen:
            continue
        seen.add(key)
        unique.append(post)
    return unique


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


def run_droid(prompt, tool, timeout):
    """One droid exec call restricted to a single tool. Returns (result_text, error)."""
    args = ["droid", "exec", "--only-tools", tool, "--output-format", "json", prompt]
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


def search_query(query, max_results, knowledge, timeout):
    """Search one query with one retry. Returns (posts, knowledge_answer, error)."""
    prompt = build_prompt(query, max_results, knowledge)
    last_error = "search failed"
    for _attempt in range(ATTEMPTS_PER_QUERY):
        text, error = run_droid(prompt, TOOL_SEARCH, timeout)
        if error:
            last_error = error
            continue
        data = extract_json(text)
        if data is None:
            last_error = "model reply contained no parseable JSON"
            continue
        results = data.get("results") if isinstance(data, dict) else data
        answer = data.get("knowledge") if isinstance(data, dict) else None
        posts = normalize_posts(results if isinstance(results, list) else [], query)
        if not posts and not answer:
            last_error = "no results"
            continue
        return posts, answer, None
    return [], None, last_error


def fetch_page(url, timeout):
    """Readable text for one URL through the FetchUrl tool. Returns (text, error)."""
    text, error = run_droid(build_fetch_prompt(url), TOOL_FETCH, timeout)
    if error:
        return "", error
    return text[:TEXT_LIMIT], None


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Web search through the droid CLI.")
    parser.add_argument("queries", nargs="+", help="One or more search queries")
    parser.add_argument("--max", type=int, default=10, help="Max results per query (1-20)")
    parser.add_argument("--fetch", action="store_true", help="Fetch readable text for every URL")
    parser.add_argument("--knowledge", action="store_true", help="Allow live structured-facts mode")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="Seconds per droid exec call")
    args = parser.parse_args(argv)
    args.max = max(1, min(MAX_RESULTS_LIMIT, args.max))
    return args


def main(argv=None):
    args = parse_args(argv)
    if which_droid() is None:
        print(
            json.dumps(
                {
                    "keywords": args.queries,
                    "count": 0,
                    "posts": [],
                    "errors": [
                        {
                            "query": None,
                            "error": "droid CLI not found on PATH. Install Factory Droid and log in.",
                        }
                    ],
                },
                indent=2,
            )
        )
        return 1

    posts = []
    errors = []
    knowledge = None
    for query in args.queries:
        query_posts, answer, error = search_query(query, args.max, args.knowledge, args.timeout)
        if error:
            errors.append({"query": query, "error": error})
        if answer is not None and knowledge is None:
            knowledge = answer
        posts.extend(query_posts)

    posts = dedupe(posts)

    if args.fetch:
        for post in posts:
            text, error = fetch_page(post["url"], args.timeout)
            post["text"] = text
            if error:
                errors.append({"query": post["url"], "error": error})

    envelope = {"keywords": args.queries, "count": len(posts), "posts": posts, "errors": errors}
    if knowledge is not None:
        envelope["knowledge"] = knowledge
    print(json.dumps(envelope, indent=2, ensure_ascii=False))
    return 0 if posts or knowledge is not None else 1


if __name__ == "__main__":
    sys.exit(main())
