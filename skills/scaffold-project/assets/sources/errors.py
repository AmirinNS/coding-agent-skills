# Themed error handling. One template (error.html) serves every HTTP status;
# API/XHR callers get JSON. Registered for all codes so nothing falls back to
# Flask's default page. Pattern from isaham-learn's server_setup.py.
import logging

from flask import render_template, request, jsonify, make_response
from werkzeug.exceptions import default_exceptions

log = logging.getLogger(__name__)

# heading + message per known status; unknown codes use a generic fallback.
ERROR_COPY = {
    400: ("Bad request", "The request couldn't be understood."),
    401: ("Sign in required", "Please log in to continue."),
    403: ("Forbidden", "You don't have access to this page."),
    404: ("Page not found", "This page doesn't exist."),
    429: ("Too many requests", "You're going a bit fast — please slow down and try again."),
    500: ("Something went wrong", "Something went wrong on our end. Please try again."),
    502: ("Bad gateway", "We got an invalid response upstream. Please try again."),
    503: ("Service unavailable", "The service is temporarily unavailable. Please try again shortly."),
}


def _wants_json():
    """API/XHR callers should get JSON, not an HTML page."""
    if request.path.startswith("/api"):
        return True
    accept = request.accept_mimetypes
    return accept.best == "application/json" and accept["application/json"] >= accept["text/html"]


def _render_error(error):
    code = getattr(error, "code", 500) or 500
    status_label = getattr(error, "name", "Error")
    heading, message = ERROR_COPY.get(code, (status_label, "An unexpected error occurred. Please try again."))

    if _wants_json():
        return jsonify(success=False, error=status_label, code=code, message=message), code

    try:
        html = render_template("error.html", code=code, status_label=status_label,
                               heading=heading, message=message)
    except Exception:
        # Last-resort fallback if template/context rendering itself fails
        # (e.g. DB unreachable during a 500). Keep it dependency-free.
        log.exception("error page render failed")
        html = ("<!doctype html><meta charset=utf-8><title>%d</title>"
                "<h1>%d — %s</h1><p>%s</p><p><a href='/'>Go home</a></p>"
                % (code, code, heading, message))

    response = make_response(html, code)
    if code == 429:
        response.headers["Retry-After"] = "60"
    return response


def init_errors(app):
    """Register the themed handler for every HTTP status Werkzeug knows about."""
    for code in default_exceptions:
        app.register_error_handler(code, _render_error)
