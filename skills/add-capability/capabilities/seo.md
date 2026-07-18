# Add SEO (advanced)

You are adding the advanced SEO layer to an existing house-style project: **JSON-LD structured data** per page type and a **dynamic, DB-driven `sitemap.xml`** with caching. This sits on top of the baseline SEO (meta/OG/Twitter/canonical + `/robots.txt` + a static sitemap) that `scaffold-project` already ships.

Keep house-style discipline: functional, no ORM (direct PyMongo), pure functions that take `db` explicitly, imports at the top, 4-space indent.

## Step 0: Preconditions

1. Confirm the project is house-style Flask + MongoDB with `sources/seo.py`, and `base.html` has the baseline meta/OG blocks. If the baseline is missing, add it first by copying `sources/seo.py` and the `base.html` head from `scaffold-project/assets/` — do not hand-roll it.
2. Confirm a clean git baseline (this skill edits `seo.py`, `base.html`, and route handlers).
3. Confirm `SITE_URL` is set correctly per environment — canonical URLs and sitemap `<loc>`s depend on it.

## Step 1: Identify what needs structured data

Ask the user (or infer from routes/collections), and record answers:

- **Which page types exist?** Typically: a landing page, one or more listing/collection pages, and a detail page per entity.
- **What is the primary entity?** (e.g. product, article, deal, course, event) → picks the schema.org type: `Product`, `Article`, `Event`, `Course`, etc.
- **Which MongoDB collection(s)** back the detail pages, and what field is the URL slug (or is it derived from a title)?
- **How many detail URLs**, roughly? (drives whether the sitemap needs the 45k cap / pagination.)

Don't invent page types the project doesn't have. If it's a single-page app, JSON-LD `WebSite` + a one-URL sitemap is the whole job.

## Step 2: Extend `sources/seo.py`

Add pure functions. Adapt schema types to the entity from Step 1. Reference shape:

```python
import json
import re
import time
from urllib.parse import urljoin

from flask import request

from sources.config import SITE_NAME, SITE_URL, db  # db only if seo.py builds the sitemap

# ── Slugify ──────────────────────────────────────────────────────────────
_slug_strip = re.compile(r"[^a-z0-9\s-]+")
_slug_spaces = re.compile(r"\s+")
_slug_hyphens = re.compile(r"-+")


def slugify(text):
    """SEO-friendly slug: lowercase, alnum + hyphens, max 120 chars."""
    s = _slug_strip.sub("", (text or "").lower())
    s = _slug_spaces.sub("-", s).strip()
    s = _slug_hyphens.sub("-", s).strip("-")
    return s[:120]


# ── JSON-LD builders (one per page type; adapt @type to the entity) ───────
def jsonld_website():
    return {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": SITE_NAME,
        "url": SITE_URL,
    }


def jsonld_item_list(items, path):
    """CollectionPage / ItemList for a listing page."""
    return {
        "@context": "https://schema.org",
        "@type": "ItemList",
        "url": urljoin(SITE_URL + "/", path.lstrip("/")),
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1,
             "name": it.get("name", ""),
             "url": SITE_URL + "/item/" + str(it.get("_id"))}
            for i, it in enumerate(items)
        ],
    }


def jsonld_detail(item):
    """Per-entity structured data. Change @type to Product/Article/Event/etc."""
    return {
        "@context": "https://schema.org",
        "@type": "Thing",
        "name": item.get("name", ""),
        "description": item.get("description", ""),
    }


def jsonld_script(data):
    """Render a dict as a safe <script type=application/ld+json> string."""
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))
```

Notes:
- Import `db` into `seo.py` only if the sitemap builder lives here; otherwise pass `db` in from the route. Prefer passing `db` explicitly to keep functions pure.
- Escape nothing by hand — `json.dumps` output goes inside a `<script>` block, which is safe for JSON-LD.

## Step 3: Render JSON-LD in `base.html`

Add a block in `<head>` (near the other SEO tags):

```html
{% block jsonld %}{% endblock %}
```

Each page that has structured data overrides it:

```html
{% block jsonld %}
<script type="application/ld+json">{{ jsonld | safe }}</script>
{% endblock %}
```

Pass `jsonld=seo.jsonld_script(seo.jsonld_detail(item))` from the route's `render_template(...)`. For site-wide `WebSite` JSON-LD on every page, inject it via the existing `inject_globals` context processor instead of per-route.

## Step 4: Dynamic sitemap

Replace the scaffold's static `/sitemap.xml` with a DB-driven one. Keep the cache — sitemaps are hit by crawlers and should not query Mongo every time.

```python
# In the entrypoint (or a modules/seo.py that returns the body).
import time
from flask import Response

_SITEMAP_TTL = 3600  # 1 hour
_sitemap_cache = {"body": None, "at": 0.0}
MAX_SITEMAP_URLS = 45_000


@app.route("/sitemap.xml")
def sitemap_xml():
    now = time.time()
    if _sitemap_cache["body"] and now - _sitemap_cache["at"] < _SITEMAP_TTL:
        body = _sitemap_cache["body"]
    else:
        urls = [SITE_URL + url_for("index")]
        for it in db.items.find({}, {"_id": 1}).limit(MAX_SITEMAP_URLS):
            urls.append(SITE_URL + "/item/" + str(it["_id"]))
        body = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            + "".join("<url><loc>{}</loc></url>".format(u) for u in urls)
            + "</urlset>"
        )
        _sitemap_cache.update(body=body, at=now)
    return Response(body, mimetype="application/xml",
                    headers={"Cache-Control": "public, max-age=3600"})
```

Adapt the collection, projection, and URL shape to the project. If detail URLs use slugs, project the slug field (or build it with `slugify`).

## Step 5: Verify

- Boot the app (dev mode). `curl` a detail page and confirm a `<script type="application/ld+json">` block is present and that its contents `json.loads()` without error.
- `curl /sitemap.xml` and confirm it lists real DB entities (not just `/`), is well-formed XML, and sets `Cache-Control`.
- Optionally validate structured data against Google's Rich Results test guidelines (report the shape; don't call external services without the user's OK).
- Run existing tests; commit.

## Rules

- Build on the baseline — don't duplicate the meta/OG/canonical tags the scaffold already renders.
- Functional + direct PyMongo only. JSON-LD/sitemap builders are pure functions taking `db` (or the items) explicitly. No classes, no ORM.
- Imports at the top; 4-space indent; match existing file indentation when editing.
- Cache the sitemap (TTL) and cap at `MAX_SITEMAP_URLS`; a sitemap that queries Mongo per request or emits 100k URLs is a regression.
- Pick schema.org `@type` to match the real entity; don't ship generic `Thing` if the entity is clearly a `Product`/`Article`/`Event`.
- Keep it to the page types the project actually has. No speculative structured data.
