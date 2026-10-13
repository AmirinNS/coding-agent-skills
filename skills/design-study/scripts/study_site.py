"""Screenshot a live page and tally its computed styles into tokens.json.

Usage:
    /Users/amirinns/PythonEnv/isaham/bin/python study_site.py URL [URL ...] --out DIR

For each URL, writes DIR/<slug>/390.png, 1440.png and tokens.json.
"""
import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import sync_playwright

WIDTHS = [390, 1440]
HEIGHTS = {390: 844, 1440: 900}
TOP_N = 20
SETTLE_MS = 1500
COLOR_PROPS = {"color", "background-color", "border-color"}
SPACING_PROPS = {"padding", "margin", "gap"}
IGNORED = {"", "0px", "none", "normal", None}

COLLECT_JS = """
() => {
  const props = ['font-family', 'font-size', 'font-weight', 'line-height', 'color',
    'background-color', 'border-color', 'border-radius', 'box-shadow',
    'padding', 'margin', 'gap'];
  const samples = [];
  for (const el of Array.from(document.querySelectorAll('body, body *')).slice(0, 3000)) {
    const cs = getComputedStyle(el);
    const box = el.getBoundingClientRect();
    if (cs.display === 'none' || box.width === 0 || box.height === 0) continue;
    const sample = {};
    for (const p of props) sample[p] = cs.getPropertyValue(p);
    if (parseFloat(cs.borderTopWidth) === 0) delete sample['border-color'];
    // Horizontal auto margins compute to centering offsets, not spacing tokens.
    sample['margin'] = `${cs.marginTop} ${cs.marginBottom}`;
    samples.push(sample);
  }
  const root = getComputedStyle(document.documentElement);
  const custom = {};
  for (const name of root) {
    if (name.startsWith('--')) custom[name] = root.getPropertyValue(name).trim();
  }
  return {samples, custom};
}
"""


def rgb_to_hex(value):
    """Opaque rgb()/rgba() to #rrggbb, None if fully transparent, anything else unchanged."""
    match = re.fullmatch(r"rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)", value.strip())
    if not match:
        return value
    red, green, blue, alpha = match.groups()
    if alpha is not None and float(alpha) == 0:
        return None
    if alpha is not None and float(alpha) < 1:
        return value
    return "#{:02x}{:02x}{:02x}".format(int(red), int(green), int(blue))


def slugify(url):
    parsed = urlparse(url)
    slug = re.sub(r"[^a-z0-9]+", "-", f"{parsed.netloc}{parsed.path}".lower()).strip("-")
    return slug or "page"


def tally(samples):
    counts = {}
    for sample in samples:
        for prop, value in sample.items():
            if prop in COLOR_PROPS:
                found = [rgb_to_hex(value)]
            elif prop in SPACING_PROPS:
                prop, found = "spacing", value.split()
            else:
                found = [value]
            for item in found:
                if item not in IGNORED:
                    counts.setdefault(prop, Counter())[item] += 1
    return {prop: [[value, n] for value, n in counter.most_common(TOP_N)]
            for prop, counter in counts.items()}


def capture(url, out_dir):
    out_dir = Path(out_dir)
    samples, custom = [], {}
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        try:
            for width in WIDTHS:
                context = browser.new_context(viewport={"width": width, "height": HEIGHTS[width]})
                page = context.new_page()
                # shortcut: "load" plus a fixed settle, since "networkidle" never fires on pages
                # with beacons or long polling. Raise SETTLE_MS if late-loading styles get missed.
                page.goto(url, wait_until="load", timeout=30000)
                page.wait_for_timeout(SETTLE_MS)
                out_dir.mkdir(parents=True, exist_ok=True)
                page.screenshot(path=str(out_dir / f"{width}.png"), full_page=True)
                result = page.evaluate(COLLECT_JS)
                samples.extend(result["samples"])
                custom.update(result["custom"])
                context.close()
        finally:
            browser.close()
    tokens = {
        "url": url,
        "captured_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "widths": WIDTHS,
        "custom_properties": custom,
        "tally": tally(samples),
    }
    (out_dir / "tokens.json").write_text(json.dumps(tokens, indent=2))
    return tokens


def main():
    parser = argparse.ArgumentParser(description="Screenshot pages and tally their computed styles.")
    parser.add_argument("urls", nargs="+", metavar="URL")
    parser.add_argument("--out", required=True, help="output folder; one subfolder per URL")
    args = parser.parse_args()
    failed = False
    for url in args.urls:
        target = Path(args.out) / slugify(url)
        try:
            capture(url, target)
            print(f"wrote {target}")
        except PlaywrightError as error:
            failed = True
            print(f"error: {url}: {str(error).splitlines()[0]}", file=sys.stderr)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
