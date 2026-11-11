"""Search Brave and Bing through real Chrome with Playwright, no SearXNG.

Runs a search engine the way a person does: opens the engine homepage in the
real installed Chrome, types the query one character at a time, reads the
results page. That sails past the bot blocks that stop bare HTTP scrapers.
Results come back as ranked JSON on stdout, optionally with each page's
readable text.

Ported from the recon-tools bundle (web_recon.py + browser.py) with the
SearXNG API engine, the Docker service, and the recon.db ingest removed.

Usage:
    uv run --with playwright python web_browse.py "QUERY" [more queries] [--engine brave|bing|all]
        [--max N] [--fetch] [--headless] [--profile DIR] [--no-stealth]

Prints a JSON envelope: keywords, engines, count, posts, errors. Each post has
rank, title, url, domain, engine, keyword, snippet, and text (with --fetch).
Progress logs go to stderr. Exit code is 1 when no results were collected.
"""
import argparse
import asyncio
import base64
import json
import random
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse

try:
    from playwright.async_api import TimeoutError as PlaywrightTimeoutError
    from playwright.async_api import async_playwright
except ImportError:  # pure-function paths stay importable without playwright
    async_playwright = None
    PlaywrightTimeoutError = Exception

SELECT_ALL = "Meta+a" if sys.platform == "darwin" else "Control+a"
MAX_FETCH_CHARS = 20_000
# Below this, a page is probably still client-rendering (SPA) rather than
# genuinely short: trigger one extra settle + re-extract before giving up.
THIN_TEXT = 400
MAX_RESULTS_LIMIT = 50
DEFAULT_VIEWPORT = {"width": 1450, "height": 920}


def log(message):
    """Progress goes to stderr so stdout stays pure JSON."""
    print(message, file=sys.stderr)


# --- real-Chrome launcher ---------------------------------------------------
# Sites that block bundled/automation browsers still render in the real
# installed Chrome with automation flags masked.

def _os_ua_platform():
    if sys.platform == "darwin":
        return "Macintosh; Intel Mac OS X 10_15_7"
    if sys.platform.startswith("win"):
        return "Windows NT 10.0; Win64; x64"
    return "X11; Linux x86_64"


def _detect_chrome_version():
    try:
        if sys.platform == "darwin":
            out = subprocess.check_output(
                ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "--version"],
                stderr=subprocess.DEVNULL,
                timeout=2,
            ).decode().strip()
            match = re.search(r"(\d+[\.\d]*)", out)
            if match:
                return match.group(1)
    except Exception:
        pass
    return "130.0.0.0"


def _build_ua(version=None):
    major = (version or _detect_chrome_version()).split(".")[0]
    return (
        f"Mozilla/5.0 ({_os_ua_platform()}) "
        f"AppleWebKit/537.36 (KHTML, like Gecko) "
        f"Chrome/{major}.0.0.0 Safari/537.36"
    )


STEALTH_ARGS = [
    "--disable-blink-features=AutomationControlled",
    "--no-default-browser-check",
    "--disable-infobars",
    "--window-size=1440,900",
]
IGNORE_AUTOMATION_ARGS = ["--enable-automation"]


async def _apply_stealth(context):
    """Mask navigator.webdriver without spoofing false OS/GPU fingerprints."""
    await context.add_init_script("""
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
        });
        if (!window.chrome) {
            window.chrome = { runtime: {} };
        }
    """)


async def launch_browser(playwright, headless=False, profile_dir=None, stealth=True):
    """Launch real Chrome. Returns (browser_or_None, context).

    profile_dir: use a persistent context at that path, which keeps a manual
    login across runs. Otherwise a fresh context.
    """
    args = STEALTH_ARGS if stealth else []
    ignore_default_args = IGNORE_AUTOMATION_ARGS if stealth else []

    if profile_dir:
        context = await playwright.chromium.launch_persistent_context(
            user_data_dir=str(Path(profile_dir).expanduser()),
            channel="chrome",
            headless=headless,
            locale="en-US",
            viewport=None if not headless else DEFAULT_VIEWPORT,
            no_viewport=not headless,
            args=args,
            ignore_default_args=ignore_default_args,
        )
        if stealth:
            await _apply_stealth(context)
        return None, context

    browser = await playwright.chromium.launch(
        headless=headless,
        channel="chrome",
        args=args,
        ignore_default_args=ignore_default_args,
    )
    context = await browser.new_context(
        user_agent=_build_ua(browser.version),
        locale="en-US",
        viewport=None if not headless else DEFAULT_VIEWPORT,
        no_viewport=not headless,
    )
    if stealth:
        await _apply_stealth(context)
    return browser, context


async def close_browser(browser, context):
    await context.close()
    if browser:
        await browser.close()


def random_pause(low=0.5, high=1.6):
    return random.uniform(low, high)


async def human_dwell(page, low=0.8, high=2.2):
    """Mimic a human reading a page: pause, small scroll down, glance back up."""
    await asyncio.sleep(random.uniform(low, high))
    try:
        await page.mouse.move(
            random.randint(200, 900), random.randint(150, 500),
            steps=random.randint(6, 15),
        )
        await page.mouse.wheel(0, random.randint(250, 650))
        await asyncio.sleep(random.uniform(0.5, 1.3))
        await page.mouse.wheel(0, -random.randint(120, 320))
        await asyncio.sleep(random.uniform(0.3, 0.9))
    except Exception:
        pass


async def human_type(locator, text):
    """Type one character at a time with human-ish random delays and pauses."""
    for char in text:
        await locator.press_sequentially(char, delay=random.uniform(45, 150))
        if random.random() < 0.12:  # occasional "thinking" pause
            await asyncio.sleep(random.uniform(0.15, 0.5))


# --- per-engine in-page extractors ------------------------------------------
# Each returns [{url, title, snippet}] from the current results page. Anchored
# on the most stable structure each engine exposes; fragile by nature (engines
# change markup) but isolated here so one engine breaking doesn't affect others.

BING_JS = r"""
() => {
  const out = [];
  for (const li of document.querySelectorAll('li.b_algo')) {
    const a = li.querySelector('h2 a');
    if (!a || !a.href) continue;
    const title = a.innerText.trim(); if (!title) continue;
    const sn = li.querySelector('.b_caption p, .b_algoSlug, .b_lineclamp2, .b_lineclamp3, .b_paractl, p');
    out.push({url: a.href, title, snippet: sn ? sn.innerText.trim() : ''});
  }
  return out;
}
"""

BRAVE_JS = r"""
() => {
  const out = [];
  let list = document.querySelectorAll('#results [data-type="web"]');
  if (!list.length) list = document.querySelectorAll('#results .snippet, .snippet');
  for (const el of list) {
    const a = el.querySelector('a[href^="http"]'); if (!a) continue;
    const titleEl = el.querySelector('.title') || el.querySelector('[class*="title"]') || a;
    const title = titleEl.innerText.trim(); if (!title) continue;
    const sn = el.querySelector('.generic-snippet, .snippet-description, .snippet-content, .content, .desc, [class*="description"]');
    out.push({url: a.href, title, snippet: sn ? sn.innerText.trim() : ''});
  }
  return out;
}
"""

READABLE_JS = r"""
() => {
  const pick = document.querySelector('article') || document.querySelector('main')
    || document.body;
  return (pick ? pick.innerText : '').replace(/\n{3,}/g, '\n\n').trim();
}
"""

# Order sets the priority of `--engine all`: engines are queried in this order
# and on a URL collision the first engine to return it keeps the result.
ENGINES = {
    "brave": {
        "home": "https://search.brave.com/",
        "box": 'input[name="q"], #searchbox',
        "results_sel": '#results [data-type="web"], #results .snippet, .snippet',
        "extract": BRAVE_JS,
        "paginate": "url",
        "page_url": lambda query, page: f"https://search.brave.com/search?q={quote(query)}&offset={page}",
    },
    "bing": {
        "home": "https://www.bing.com/",
        "box": 'input[name="q"], textarea[name="q"]',
        "results_sel": "li.b_algo",
        "extract": BING_JS,
        "paginate": "url",
        "page_url": lambda query, page: f"https://www.bing.com/search?q={quote(query)}&first={page * 10 + 1}",
    },
}


def _domain(url):
    try:
        return urlparse(url).netloc.replace("www.", "")
    except ValueError:
        return ""


def _unwrap_bing_redirect(url):
    """Bing wraps result links as bing.com/ck/a?...&u=<base64url>... tracking
    redirects. Pull the real destination out of the `u` param when present."""
    if "bing.com/ck/a" not in url:
        return url
    try:
        target = parse_qs(urlparse(url).query).get("u", [""])[0]
        if not target.startswith("a1"):
            return url
        decoded = base64.urlsafe_b64decode(target[2:] + "=" * (-len(target[2:]) % 4))
        return decoded.decode("utf-8", errors="replace")
    except Exception:  # a bad unwrap shouldn't lose the result
        return url


def merge_unique(all_posts, seen, found):
    """Append results whose URL has not been seen. Returns the count added."""
    added = 0
    for post in found:
        url = post.get("url") or ""
        if url and url not in seen:
            seen.add(url)
            all_posts.append(post)
            added += 1
    return added


def build_envelope(keywords, engines, posts, errors):
    return {
        "keywords": list(keywords),
        "engines": list(engines),
        "count": len(posts),
        "posts": posts,
        "errors": errors,
    }


async def _wait_results(page, cfg):
    try:
        await page.locator(cfg["results_sel"]).first.wait_for(
            state="visible", timeout=15_000)
        return True
    except PlaywrightTimeoutError:
        return False


async def _human_query(page, cfg, query):
    """Open the engine homepage and type the query like a human, then submit."""
    await page.goto(cfg["home"], wait_until="domcontentloaded", timeout=60_000)
    await human_dwell(page)
    box = page.locator(cfg["box"]).first
    await box.wait_for(state="visible", timeout=30_000)
    await box.click()
    await asyncio.sleep(random_pause(0.3, 0.9))
    await box.press(SELECT_ALL)
    await box.press("Backspace")
    await human_type(box, query)
    await asyncio.sleep(random_pause(0.4, 1.1))
    await box.press("Enter")
    try:
        await page.wait_for_load_state("domcontentloaded", timeout=15_000)
    except PlaywrightTimeoutError:
        pass
    await human_dwell(page)


BLOCK_MARKERS = (
    "unusual traffic",
    "are you a robot",
    "verify you are human",
    "verifying you",
    "not a bot",
    "verify you are",
)


def blocked_reason(url, head_text):
    """Detect an interstitial bot-check page and return a short reason, else None."""
    lowered_url = url.lower()
    if "/sorry/" in lowered_url or "captcha" in lowered_url:
        return "CAPTCHA / 'unusual traffic' bot-check"
    head = (head_text or "").lower()
    if any(marker in head for marker in BLOCK_MARKERS):
        return "bot-check interstitial (\"verifying you're not a bot\")"
    return None


async def _blocked_reason(page):
    try:
        head = await page.evaluate("() => document.body.innerText.slice(0,300)")
    except Exception:
        return None
    return blocked_reason(page.url, head)


async def search_engine(page, engine, query, max_results):
    """Run one query on one engine; return ranked organic results."""
    cfg = ENGINES[engine]
    await _human_query(page, cfg, query)
    if not await _wait_results(page, cfg):
        reason = await _blocked_reason(page)
        if reason:
            log(f"  [BLOCKED] {engine}: {reason}. The session was gated. Re-run with "
                f"--engine bing, retry once without --headless, or warm a profile with "
                f"--profile DIR and log in by hand when the window opens.")
        else:
            log(f"  [WARN] {engine}: no results element for {query!r} "
                "(markup may have changed)")
        return []

    collected = {}
    for page_number in range(8):  # page/scroll cap
        raw = await page.evaluate(cfg["extract"])
        gained = 0
        for result in raw:
            url = result.get("url", "")
            if engine == "bing":
                url = _unwrap_bing_redirect(url)
            if url and url not in collected:
                collected[url] = {
                    "rank": len(collected) + 1,
                    "title": result.get("title", ""),
                    "url": url,
                    "domain": _domain(url),
                    "engine": engine,
                    "keyword": query,
                    "snippet": result.get("snippet", ""),
                    "text": "",
                }
                gained += 1
        log(f"  [OK] {engine} {query!r} page {page_number + 1}: +{gained} "
            f"(total {len(collected)})")
        if len(collected) >= max_results:
            break

        if cfg["paginate"] == "url":
            if gained == 0 and page_number > 0:
                break
            await page.goto(cfg["page_url"](query, page_number + 1),
                            wait_until="domcontentloaded", timeout=60_000)
            await human_dwell(page)
            if not await _wait_results(page, cfg):
                break

    return list(collected.values())[:max_results]


async def _fetch_readable(page, url):
    """Navigate to `url` and extract readable text, giving JS-rendered pages a
    chance to paint. Raises on hard navigation failures (DNS/unreachable) so the
    caller can skip; a `load`-event timeout is tolerated (the DOM is usually
    usable even when slow third-party resources never settle)."""
    try:
        await page.goto(url, wait_until="load", timeout=30_000)
    except PlaywrightTimeoutError:
        pass  # load never fired (ads/trackers hanging): extract what rendered
    await asyncio.sleep(random_pause(0.6, 1.4))  # let lazy / hydrating JS paint
    text = (await page.evaluate(READABLE_JS) or "").strip()

    if len(text) < THIN_TEXT:
        # Likely a client-rendered page still hydrating: wait once more, then
        # re-extract; keep whichever attempt yielded more.
        try:
            await page.wait_for_load_state("networkidle", timeout=8_000)
        except PlaywrightTimeoutError:
            pass
        await asyncio.sleep(random_pause(0.6, 1.2))
        retry = (await page.evaluate(READABLE_JS) or "").strip()
        if len(retry) > len(text):
            text = retry
    return text[:MAX_FETCH_CHARS]


async def fetch_pages(context, posts):
    """Open each result URL and extract readable body text (best-effort).

    Each fetch runs on its own throwaway page: a failed navigation (dead link,
    DNS error, timeout) leaves the browser's frame in a broken state that would
    otherwise poison every subsequent goto on the same page, so isolating per
    URL is what keeps one bad link from silently killing the rest of the batch.
    """
    for index, post in enumerate(posts, 1):
        page = await context.new_page()
        try:
            post["text"] = await _fetch_readable(page, post["url"])
        except Exception as error:  # one bad page shouldn't stop the run
            log(f"  [WARN] fetch failed {post['url'][:60]}: {type(error).__name__}")
        finally:
            await page.close()
        if index % 5 == 0:
            log(f"  fetched {index}/{len(posts)}")


async def run(args):
    engines = list(ENGINES) if "all" in args.engine else list(args.engine)
    posts, seen, errors = [], set(), []

    try:
        async with async_playwright() as pw:
            browser, context = await launch_browser(
                pw, headless=args.headless, profile_dir=args.profile,
                stealth=not args.no_stealth,
            )
            page = context.pages[0] if context.pages else await context.new_page()
            try:
                for keyword in args.keywords:
                    for engine in engines:
                        log(f"[INFO] {engine}: searching {keyword!r}")
                        try:
                            found = await search_engine(page, engine, keyword, args.max)
                        except Exception as error:  # one bad run shouldn't stop the rest
                            errors.append({
                                "query": keyword,
                                "engine": engine,
                                "error": f"{type(error).__name__}: {error}",
                            })
                            continue
                        merge_unique(posts, seen, found)

                if args.fetch and posts:
                    log(f"[INFO] Fetching page text for {len(posts)} result(s) ...")
                    await fetch_pages(context, posts)
            finally:
                await close_browser(browser, context)
    except Exception as error:  # launch failures, Playwright/driver problems
        errors.append({"query": None, "engine": None, "error": f"{type(error).__name__}: {error}"})
        log(f"[ERROR] Chrome run failed: {type(error).__name__}: {error}")

    return build_envelope(args.keywords, engines, posts, errors)


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Brave/Bing search via real Chrome + Playwright")
    parser.add_argument("keywords", nargs="+", help="One or more search queries")
    parser.add_argument("--engine", nargs="+", choices=[*ENGINES, "all"], default=["brave"],
                        help="Engine(s) to query (default brave; 'all' = brave then bing)")
    parser.add_argument("--max", type=int, default=10, help="Max results per query per engine")
    parser.add_argument("--fetch", action="store_true",
                        help="Also open each result and extract readable page text")
    parser.add_argument("--headless", action="store_true", help="Run Chrome headless")
    parser.add_argument("--no-stealth", action="store_true")
    parser.add_argument("--profile", default=None, help="Persistent Chrome profile dir")
    args = parser.parse_args(argv)
    args.max = max(1, min(MAX_RESULTS_LIMIT, args.max))
    return args


def main(argv=None):
    args = parse_args(argv)
    if async_playwright is None:
        envelope = build_envelope(args.keywords, args.engine, [], [{
            "query": None,
            "engine": None,
            "error": "playwright is not installed for this interpreter. Setup: "
                     "python3 -m venv <skill-dir>/.venv && <skill-dir>/.venv/bin/pip "
                     "install playwright. Real Google Chrome must also be installed "
                     "(the script launches it via channel=chrome).",
        }])
        print(json.dumps(envelope, indent=2, ensure_ascii=False))
        return 1

    started = time.time()
    envelope = asyncio.run(run(args))
    print(json.dumps(envelope, indent=2, ensure_ascii=False))
    log(f"[INFO] Elapsed {time.time() - started:.1f}s")
    return 0 if envelope["posts"] else 1


if __name__ == "__main__":
    sys.exit(main())
