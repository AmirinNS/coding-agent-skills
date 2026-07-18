# Add Payment (Stripe)

Add **Stripe Checkout** + a **signature-verified webhook**. Checkout redirects the user to Stripe's hosted page; the webhook is the source of truth that records paid state in Mongo. Works for one-time payments or subscriptions (pick per Step 0).

House-style discipline: functional, business logic in `modules/payment.py` taking `db` explicitly, thin routes, imports at top, 4-space indent.

## Step 0: Decide the model (ask the user)

- **One-time** payment, or **subscription**? (changes Checkout `mode` and which webhook events matter.)
- What is the user buying, and what unlocks on success? (which Mongo doc/field flips to paid/active.)
- Do you have Stripe **Price IDs** created in the Stripe dashboard? Checkout references a Price, not an ad-hoc amount.

Don't build subscription lifecycle handling if the project only needs a one-time charge.

## Step 1: Dependencies & env

`requirements.txt` (the `.v1` namespace needs a recent major; prefer the latest):
```
stripe>=12.0.0
```

`.env.example`:
```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_ID=price_...
STRIPE_SUCCESS_URL=http://localhost:5000/pay/success
STRIPE_CANCEL_URL=http://localhost:5000/pay/cancel
```

`sources/config.py`:
```python
STRIPE_SECRET_KEY = os.environ.get("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET = os.environ.get("STRIPE_WEBHOOK_SECRET", "")
STRIPE_PRICE_ID = os.environ.get("STRIPE_PRICE_ID", "")
STRIPE_SUCCESS_URL = os.environ.get("STRIPE_SUCCESS_URL", "")
STRIPE_CANCEL_URL = os.environ.get("STRIPE_CANCEL_URL", "")
```

## Step 2: `modules/payment.py`

Use the **service-based `StripeClient`** with the **`.v1` namespace** (current as of stripe v15). The legacy
`stripe.api_key` + `stripe.checkout.Session.create` pattern is deprecated, and even `client.checkout` (without
`.v1`) now emits a deprecation warning.

> **SDK drift — verify at build time.** Stripe's Python surface moves fast (global → `StripeClient` → `.v1`
> namespace in successive majors). Before shipping, confirm the current create-session call against Stripe's
> docs (or Context7 `/stripe/stripe-python`) for the version you install. The code below is correct for
> stripe ≥ ~12 with the `.v1` namespace; older majors use `client.checkout.sessions.create` without `.v1`.

```python
# Stripe payment logic. Pure functions; DB writes take `db` explicitly.
import stripe

from sources.config import (STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRICE_ID,
                            STRIPE_SUCCESS_URL, STRIPE_CANCEL_URL)
from sources.functions import utcnow

# Service-based client (v8+). No global stripe.api_key.
client = stripe.StripeClient(STRIPE_SECRET_KEY)


def create_checkout_session(user_id, mode="payment", idempotency_key=None):
    """Create a Stripe Checkout session. mode='payment' (one-time) or 'subscription'.
    Pass an order-scoped idempotency_key so a retried request returns the same
    session instead of creating a duplicate. Returns the session (use session.url)."""
    options = {"idempotency_key": idempotency_key} if idempotency_key else None
    return client.v1.checkout.sessions.create(
        params={
            "mode": mode,
            "line_items": [{"price": STRIPE_PRICE_ID, "quantity": 1}],
            "success_url": STRIPE_SUCCESS_URL,
            "cancel_url": STRIPE_CANCEL_URL,
            "client_reference_id": str(user_id),
            "metadata": {"user_id": str(user_id)},
        },
        options=options,
    )


def parse_event(payload, sig_header):
    """Verify the webhook signature and return the Stripe event. Raises on bad signature."""
    return client.construct_event(payload, sig_header, STRIPE_WEBHOOK_SECRET)


def record_payment(db, event):
    """Record paid state from a verified event. Idempotent on the Stripe object id."""
    obj = event["data"]["object"]
    if event["type"] == "checkout.session.completed":
        db.payments.update_one(
            {"stripe_id": obj["id"]},
            {"$set": {
                "stripe_id": obj["id"],
                "user_id": obj.get("client_reference_id"),
                "amount_total": obj.get("amount_total"),
                "status": "paid",
                "mode": obj.get("mode"),
                "recorded_at": utcnow(),
            }},
            upsert=True,
        )
        # flip the owning user/doc to active here, e.g.:
        # db.users.update_one({"_id": ObjectId(obj["client_reference_id"])},
        #                     {"$set": {"is_paid": True}})
```

## Step 3: Routes (thin)

```python
from flask import request, redirect, abort
from flask_login import login_required, current_user   # if the auth capability is present
import modules.payment as payment

@app.route("/pay/checkout", methods=["POST"])
@login_required
def pay_checkout():
    session = payment.create_checkout_session(current_user.get_id(), mode="payment")
    return redirect(session.url, code=303)

@app.route("/pay/webhook", methods=["POST"])
def pay_webhook():
    try:
        event = payment.parse_event(request.get_data(), request.headers.get("Stripe-Signature"))
    except Exception:
        abort(400)                       # bad signature / malformed
    payment.record_payment(db, event)
    return "", 200

@app.route("/pay/success")
def pay_success():
    return render_template("pay_success.html")

@app.route("/pay/cancel")
def pay_cancel():
    return render_template("pay_cancel.html")
```

The webhook must read the **raw body** (`request.get_data()`) — signature verification fails against a re-serialized body.

## Step 4: Verify

- Use Stripe **test mode** keys. `stripe listen --forward-to localhost:5000/pay/webhook` to get a `whsec_` and forward events.
- POST `/pay/checkout` → redirects to Stripe; complete with test card `4242 4242 4242 4242`.
- Confirm `checkout.session.completed` hits the webhook, signature verifies, and a `payments` doc is upserted with `status: "paid"`.
- Replay the same event; confirm no duplicate (upsert on `stripe_id` is idempotent).
- Send a tampered body; confirm the webhook returns 400.

## Rules

- **Use `StripeClient` (service-based), not the global `stripe.api_key`/resource pattern** — the latter is being deprecated and won't get new features.
- **The webhook is the source of truth**, not the success redirect (users can skip it). Only grant access on a verified `checkout.session.completed`.
- Pass an **order-scoped `idempotency_key`** to `create_checkout_session` so a retried checkout POST returns the same session rather than a duplicate.
- If CSRF protection is enabled (e.g. via the `auth` capability's Flask-WTF), **exempt the webhook route** — `@csrf.exempt` on `/pay/webhook` — since Stripe can't send a CSRF token; the Stripe signature is its authenticity check.
- Always verify the webhook signature with the raw body. Never trust unsigned callbacks.
- Make `record_payment` idempotent (upsert on the Stripe object id) — Stripe retries and may deliver duplicates.
- Keys from env only; use test keys in development.
- Functional + direct PyMongo, imports at top, 4-space indent. Payment logic in `modules/payment.py`; routes stay thin.
- Build only the model the user needs (one-time vs subscription). For subscriptions, also handle `customer.subscription.updated`/`deleted` to revoke access — add those only when subscriptions are in scope.
