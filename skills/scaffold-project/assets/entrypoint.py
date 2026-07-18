# Standard library
from datetime import datetime, timezone

# Third-party
from flask import Flask, render_template, jsonify, url_for, Response
from waitress import serve

# Local
from sources.config import db, SECRET_KEY, PORT, DEBUG, IS_PRODUCTION, APP_ENV, SITE_URL
from sources.errors import init_errors
import sources.seo as seo
import modules.items as items

app = Flask(__name__)
app.secret_key = SECRET_KEY
init_errors(app)   # themed error pages for every HTTP status


@app.context_processor
def inject_globals():
    # Available in every template (footer year + baseline SEO meta).
    ctx = {"current_year": datetime.now(timezone.utc).year}
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
        + "".join("<url><loc>{}</loc></url>".format(u) for u in urls)
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
