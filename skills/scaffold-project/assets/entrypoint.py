# Standard library
from datetime import UTC, datetime

# Third-party
from flask import Flask, Response, jsonify, render_template, url_for
from waitress import serve

# Local
from modules import items
from sources import seo
from sources.config import APP_ENV, DEBUG, IS_PRODUCTION, PORT, SECRET_KEY, SITE_URL, db
from sources.errors import init_errors

app = Flask(__name__)
app.secret_key = SECRET_KEY
init_errors(app)   # themed error pages for every HTTP status


@app.context_processor
def inject_globals():
    # Available in every template (footer year + baseline SEO meta).
    ctx = {"current_year": datetime.now(UTC).year}
    ctx.update(seo.default_meta())
    return ctx


@app.route("/")
def index():
    recent = items.list_recent(db, limit=20)
    return render_template("index.html", items=recent)


@app.route("/health")
def health():
    return jsonify({"status": "ok", "env": APP_ENV})


@app.route("/robots.txt")
def robots_txt():
    body = "\n".join([
        "User-agent: *",
        "Allow: /",
        "Sitemap: " + SITE_URL + "/sitemap.xml",
    ]) + "\n"
    return Response(body, mimetype="text/plain")


@app.route("/sitemap.xml")
def sitemap_xml():
    # Minimal static sitemap. For dynamic, DB-driven sitemaps use the add-capability skill (seo).
    urls = [SITE_URL + url_for("index")]
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + "".join(f"<url><loc>{u}</loc></url>" for u in urls)
        + "</urlset>"
    )
    return Response(body, mimetype="application/xml")


if __name__ == "__main__":
    if IS_PRODUCTION:
        # Production: proper WSGI server. The native Flask server is dev-only.
        serve(app, host="0.0.0.0", port=PORT)
    else:
        # development / testing: native Flask server with the debugger.
        app.run(host="0.0.0.0", port=PORT, debug=DEBUG)
