# Add Auth (email + password)

You are adding email/password authentication to an existing house-style project using **flask-login + werkzeug**. Register, login, logout, sessions, hashed passwords, a `users` collection, and `@login_required` protection.

House-style discipline holds with one sanctioned exception: **flask-login requires a user object**, so a thin `User(UserMixin)` wrapper over the Mongo document is allowed. Everything else stays functional — business logic in `modules/users.py` as pure functions taking `db`, thin routes, imports at top, 4-space indent.

## Step 0: Preconditions

1. Confirm a house-style Flask + MongoDB project (entrypoint with `app`, `sources/config.py` exposing `db` and `SECRET_KEY`, `templates/base.html`). If not present, scaffold or convert first.
2. `SECRET_KEY` must be set (flask-login signs the session cookie). The scaffold already provides it.
3. Clean git baseline — this edits the entrypoint, `base.html`, `_navbar.html`, and adds files.

## Step 1: Dependencies

Add to `requirements.txt` (werkzeug ships with Flask):

```
Flask-Login>=0.6.0
Flask-WTF>=1.2.0
Flask-Limiter>=3.5.0
```

`Flask-WTF` provides CSRF protection; `Flask-Limiter` rate-limits the auth endpoints. Install into the project venv: `/Users/amirinns/PythonEnv/<module_name>/bin/pip install -r requirements.txt`.

## Step 2: `sources/auth.py` — flask-login wiring

```python
# flask-login wiring. The User is a thin wrapper over the Mongo user document
# (flask-login needs an object with get_id()). This is the one sanctioned class.
from flask_login import LoginManager, UserMixin
from bson.objectid import ObjectId

from sources.config import db

login_manager = LoginManager()
login_manager.login_view = "login"
login_manager.login_message_category = "warning"


class User(UserMixin):
    def __init__(self, doc):
        self.doc = doc

    def get_id(self):
        return str(self.doc["_id"])

    @property
    def email(self):
        return self.doc.get("email")


@login_manager.user_loader
def load_user(user_id):
    try:
        doc = db.users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        return None
    return User(doc) if doc else None


def init_login(app):
    login_manager.init_app(app)
    db.users.create_index("email", unique=True)
```

## Step 3: `modules/users.py` — business logic (pure functions)

```python
# User business logic. Pure functions, direct PyMongo. No classes here.
from werkzeug.security import generate_password_hash, check_password_hash

from sources.functions import utcnow


def create_user(db, email, password):
    """Insert a user with a hashed password; returns inserted_id.
    Raises pymongo.errors.DuplicateKeyError if the email already exists."""
    doc = {
        "email": email.strip().lower(),
        "password_hash": generate_password_hash(password),
        "created_at": utcnow(),
    }
    return db.users.insert_one(doc).inserted_id


def get_by_email(db, email):
    return db.users.find_one({"email": email.strip().lower()})


def verify_password(user_doc, password):
    if not user_doc:
        return False
    return check_password_hash(user_doc["password_hash"], password)
```

## Step 4: Security setup (CSRF, rate limiting, secure cookies)

In the entrypoint, before the routes:

```python
from flask_wtf import CSRFProtect
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

from sources.config import IS_PRODUCTION

# CSRF protection for all POST forms (login, register, and any other form).
csrf = CSRFProtect(app)

# Rate limiter — defaults off, applied per-route below.
limiter = Limiter(key_func=get_remote_address, app=app)

# Harden the session cookie.
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=IS_PRODUCTION,   # HTTPS-only in production
    REMEMBER_COOKIE_HTTPONLY=True,
    REMEMBER_COOKIE_SECURE=IS_PRODUCTION,
)
```

Notes:
- `SECRET_KEY` must be a strong random value in production (CSRF tokens and sessions depend on it).
- Any non-browser POST endpoint that can't send a CSRF token (e.g. a Stripe/webhook route) must be exempted with `@csrf.exempt` — its own signature verification is the auth check.
- Behind a proxy/load balancer, configure `ProxyFix` so the limiter sees the real client IP, not the proxy's.

## Step 5: Routes in the entrypoint (thin)

Add imports and init:

```python
from flask import request, redirect, flash, url_for
from urllib.parse import urlparse
from flask_login import login_user, logout_user, login_required, current_user
from pymongo.errors import DuplicateKeyError

from sources.auth import init_login, User
import modules.users as users

init_login(app)

MIN_PASSWORD_LEN = 8


def _safe_next(target):
    # Prevent open-redirect: only allow same-host relative paths.
    if not target:
        return None
    parsed = urlparse(target)
    return target if not parsed.netloc and not parsed.scheme else None
```

Routes:

```python
@app.route("/register", methods=["GET", "POST"])
@limiter.limit("5 per minute", methods=["POST"])
def register():
    if current_user.is_authenticated:
        return redirect(url_for("index"))
    if request.method == "POST":
        email = request.form.get("email", "").strip()
        password = request.form.get("password", "")
        if not email or not password:
            flash("Email and password are required.", "danger")
            return render_template("register.html")
        if len(password) < MIN_PASSWORD_LEN:
            flash("Password must be at least %d characters." % MIN_PASSWORD_LEN, "danger")
            return render_template("register.html")
        try:
            users.create_user(db, email, password)
        except DuplicateKeyError:
            flash("That email is already registered.", "danger")
            return render_template("register.html")
        login_user(User(users.get_by_email(db, email)))
        return redirect(url_for("index"))
    return render_template("register.html")


@app.route("/login", methods=["GET", "POST"])
@limiter.limit("10 per minute", methods=["POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("index"))
    if request.method == "POST":
        email = request.form.get("email", "").strip()
        password = request.form.get("password", "")
        doc = users.get_by_email(db, email)
        if users.verify_password(doc, password):
            login_user(User(doc))
            return redirect(_safe_next(request.args.get("next")) or url_for("index"))
        flash("Invalid email or password.", "danger")
    return render_template("login.html")


@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("index"))
```

Protect any route with `@login_required`; read the user via `current_user` (e.g. `current_user.email`).

## Step 6: Templates

Add flash rendering to `base.html` — insert a partial `_flash.html` and include it just inside `<main>` (above `{% block content %}`):

`templates/_flash.html`:
```html
{% with messages = get_flashed_messages(with_categories=true) %}
  {% for category, message in messages %}
  <div class="alert alert-{{ category }} alert-dismissible fade show" role="alert">
    {{ message }}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  </div>
  {% endfor %}
{% endwith %}
```

`templates/login.html` and `templates/register.html` (Bootstrap 5, extend base):
```html
{% extends "base.html" %}
{% block title %}Log in · {{ site_name }}{% endblock %}
{% block content %}
<div class="row justify-content-center">
  <div class="col-sm-8 col-md-5 col-lg-4">
    <h1 class="h4 mb-3">Log in</h1>
    <form method="post">
      <input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
      <div class="mb-3">
        <label class="form-label">Email</label>
        <input type="email" name="email" class="form-control" required autofocus>
      </div>
      <div class="mb-3">
        <label class="form-label">Password</label>
        <input type="password" name="password" class="form-control" required>
      </div>
      <button class="btn btn-primary w-100" type="submit">Log in</button>
    </form>
    <p class="small mt-3 mb-0">No account? <a href="{{ url_for('register') }}">Register</a>.</p>
  </div>
</div>
{% endblock %}
```
(`register.html` mirrors this — same hidden `csrf_token` field, a "Register" heading/button posting to `url_for('register')`, and a link back to login.)

## Step 7: Navbar state

Update `_navbar.html` to reflect auth state:
```html
<ul class="navbar-nav ms-auto">
  {% if current_user.is_authenticated %}
  <li class="nav-item"><span class="navbar-text me-3">{{ current_user.email }}</span></li>
  <li class="nav-item"><a class="nav-link" href="{{ url_for('logout') }}">Log out</a></li>
  {% else %}
  <li class="nav-item"><a class="nav-link" href="{{ url_for('login') }}">Log in</a></li>
  <li class="nav-item"><a class="nav-link" href="{{ url_for('register') }}">Register</a></li>
  {% endif %}
</ul>
```
`current_user` is available in templates automatically once flask-login is initialised.

## Step 8: Verify

- Boot the app (dev). `POST /register` a new email+password → redirects to `/`, navbar shows the email.
- `GET /logout` → navbar shows Log in / Register.
- `POST /login` with the same credentials → succeeds; with a wrong password → flashes "Invalid email or password."
- Registering a duplicate email → flashes "already registered" (unique index enforces it).
- Hit a `@login_required` route while logged out → redirects to `/login?next=...`; confirm `next` only honors relative paths.
- Register with a < 8-char password → rejected with the length flash.
- POST `/login` without the `csrf_token` field → 400 (CSRF rejected). With the field (normal form) → works.
- Hammer `/login` past the limit (>10/min) → `429 Too Many Requests`.
- Run existing tests; commit.

## Rules

- Never store plaintext passwords. Always `generate_password_hash` / `check_password_hash` (werkzeug's default is scrypt — good).
- **CSRF-protect every POST form** (Flask-WTF `CSRFProtect` + `{{ csrf_token() }}` in each form). Exempt only signature-verified machine endpoints (`@csrf.exempt`).
- **Rate-limit auth endpoints** (Flask-Limiter) to blunt brute-force/credential-stuffing. Behind a proxy, wire `ProxyFix` so limits key on the real client IP.
- **Harden session cookies**: `HTTPONLY`, `SAMESITE=Lax`, and `SECURE` in production. Use a strong random `SECRET_KEY`.
- Enforce a password minimum length (≥ 8); consider a strength/breach check for stricter needs.
- The `User(UserMixin)` wrapper is the only class — business logic stays in `modules/users.py` as pure functions taking `db`.
- Guard the `next` redirect with `_safe_next` (no open redirects).
- Enforce the unique email index (`init_login` creates it) so duplicate registration fails cleanly.
- Functional + direct PyMongo, imports at top, 4-space indent, match existing file style.
- Keep it email+password. OAuth/social login, email verification, and password reset are separate follow-ups — add them only if asked (verify/reset pair naturally with a transactional-email helper).
