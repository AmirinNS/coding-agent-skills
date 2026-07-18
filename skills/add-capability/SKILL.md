---
name: add-capability
description: "Add a prebuilt house-style capability to an existing Flask + Bootstrap 5 + MongoDB project (already scaffolded or converted to the house style). Dispatches by name to one capability: auth (email/password register + login + logout, CSRF, rate limiting), seo (JSON-LD structured data + dynamic sitemap), storage (Spaces/S3 file uploads), i18n (EN/MY translations + switcher), payment (Stripe Checkout + webhook). Use when the user wants to bolt one of these onto a project. Triggers: 'add auth', 'add login', 'add register', 'add SEO', 'add structured data', 'add sitemap', 'add file upload', 'add image upload', 'add storage', 'add i18n', 'add translations', 'add language switcher', 'add payment', 'add Stripe', 'add checkout'. Pass the capability name as the argument (e.g. 'auth')."
---

# Add Capability

Bolt a prebuilt, house-style capability onto an existing **Flask + Bootstrap 5 + MongoDB** project (one already created with `scaffold-project` or migrated with `convert-to-house-style`). Each capability is a self-contained instruction file; this skill just routes to the right one.

## Capabilities

| Name | Adds | Instruction file |
|------|------|------------------|
| `auth` | Email/password register, login, logout, sessions; CSRF, rate limiting, hardened cookies (flask-login + werkzeug + Flask-WTF + Flask-Limiter) | `capabilities/auth.md` |
| `seo` | JSON-LD structured data + dynamic DB-driven sitemap, on top of the scaffold's baseline SEO | `capabilities/seo.md` |
| `storage` | File/image uploads to DigitalOcean Spaces / AWS S3 (boto3); public via bucket policy or private via presigned URLs | `capabilities/storage.md` |
| `i18n` | EN/MY UI translations + cookie language switcher (or a pointer to Flask-Babel for richer needs) | `capabilities/i18n.md` |
| `payment` | Stripe Checkout via `StripeClient` + signature-verified, idempotent webhook | `capabilities/payment.md` |

## How to use

1. **Resolve the capability** from the argument or the user's request (`auth`, `seo`, `storage`, `i18n`, `payment`). If it's ambiguous, or they ask for more than one, confirm which and in what order.
2. **Read `capabilities/<name>.md` in this skill directory and follow it exactly.** That file is the authoritative, full instruction set — preconditions, code, verification, and rules. Do not work from memory of what the capability "usually" looks like.
3. If several are requested, apply them **one at a time**, each verified and committed before the next.
4. Mind cross-capability interactions, e.g. `payment`'s webhook route must be `@csrf.exempt` when `auth`'s CSRF protection is enabled.

## Rules

- These capabilities assume a house-style baseline. If the project isn't house-style yet, run `scaffold-project` (new project) or `convert-to-house-style` (existing) first.
- Each capability is independently shippable — never blend two into one big edit.
- This dispatcher only routes; the loaded capability file's own rules govern the work.
