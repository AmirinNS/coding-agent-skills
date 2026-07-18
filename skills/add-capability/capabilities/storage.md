# Add Storage (Spaces / S3 uploads)

Add object-storage uploads via **boto3** (works for DigitalOcean Spaces and AWS S3 — both S3-compatible). A pure-function helper uploads a Flask `FileStorage` and returns a public/CDN URL.

House-style discipline: functional, helper in `sources/storage.py`, thin routes, imports at top, 4-space indent.

## Step 0: Preconditions

1. House-style Flask project with `sources/config.py`.
2. Clean git baseline.
3. Storage credentials available (Spaces or S3 key/secret/bucket/endpoint).

## Step 1: Dependencies & env

Add to `requirements.txt`:
```
boto3>=1.34.0
```

Add to `.env.example` (Spaces shown; for AWS S3 drop the endpoint and set the real region):
```
STORAGE_ENDPOINT=https://sgp1.digitaloceanspaces.com
STORAGE_REGION=sgp1
STORAGE_BUCKET=your-bucket
STORAGE_KEY=your-key
STORAGE_SECRET=your-secret
STORAGE_CDN=https://your-bucket.sgp1.cdn.digitaloceanspaces.com
```

Add to `sources/config.py`:
```python
STORAGE_ENDPOINT = os.environ.get("STORAGE_ENDPOINT", "")
STORAGE_REGION = os.environ.get("STORAGE_REGION", "")
STORAGE_BUCKET = os.environ.get("STORAGE_BUCKET", "")
STORAGE_KEY = os.environ.get("STORAGE_KEY", "")
STORAGE_SECRET = os.environ.get("STORAGE_SECRET", "")
STORAGE_CDN = os.environ.get("STORAGE_CDN", "").rstrip("/")
```

## Step 2: `sources/storage.py`

```python
# Object storage (DigitalOcean Spaces / AWS S3) via boto3. Pure functions.
import uuid
from mimetypes import guess_type

import boto3

from sources.config import (STORAGE_ENDPOINT, STORAGE_REGION, STORAGE_BUCKET,
                            STORAGE_KEY, STORAGE_SECRET, STORAGE_CDN)

ALLOWED_EXTS = {"png", "jpg", "jpeg", "gif", "webp", "pdf"}
MAX_BYTES = 10 * 1024 * 1024  # 10 MB

_session = boto3.session.Session()
_client = _session.client(
    "s3",
    region_name=STORAGE_REGION or None,
    endpoint_url=STORAGE_ENDPOINT or None,
    aws_access_key_id=STORAGE_KEY or None,
    aws_secret_access_key=STORAGE_SECRET or None,
)


def _ext(filename):
    return filename.rsplit(".", 1)[-1].lower() if "." in filename else ""


def upload_file(file_storage, prefix="uploads"):
    """Upload a Flask FileStorage to object storage. Returns the public URL.
    Raises ValueError on a disallowed extension or oversize file."""
    ext = _ext(file_storage.filename or "")
    if ext not in ALLOWED_EXTS:
        raise ValueError("File type .%s is not allowed" % ext)

    file_storage.stream.seek(0, 2)
    size = file_storage.stream.tell()
    file_storage.stream.seek(0)
    if size > MAX_BYTES:
        raise ValueError("File exceeds %d MB" % (MAX_BYTES // 1024 // 1024))

    key = "%s/%s.%s" % (prefix.strip("/"), uuid.uuid4().hex, ext)
    content_type = guess_type(file_storage.filename)[0] or "application/octet-stream"
    # No per-object ACL. AWS S3 disables ACLs by default (Bucket-owner-enforced,
    # since Apr 2023) and PutObject with an ACL raises AccessControlListNotSupported.
    # Make a prefix public via a bucket policy, or keep it private and hand out
    # presigned_url() links. (DigitalOcean Spaces still supports ACLs — add
    # ExtraArgs={"ACL": "public-read"} only if you deliberately target Spaces.)
    _client.upload_fileobj(
        file_storage.stream, STORAGE_BUCKET, key,
        ExtraArgs={"ContentType": content_type},
    )
    base = STORAGE_CDN or ("%s/%s" % (STORAGE_ENDPOINT.rstrip("/"), STORAGE_BUCKET))
    return "%s/%s" % (base, key), key


def presigned_url(key, expires=3600):
    """Time-limited GET URL for a private object. Use when the bucket/prefix is
    not public — don't rely on ACLs."""
    return _client.generate_presigned_url(
        "get_object",
        Params={"Bucket": STORAGE_BUCKET, "Key": key},
        ExpiresIn=expires,
    )
```

`upload_file` now returns `(public_url, key)` — store the `key` so you can issue a `presigned_url(key)`
later for private objects, or build the public URL from `STORAGE_CDN` for public ones.

**Public vs private — pick per bucket:**
- **Public assets** (avatars, product images): make the prefix world-readable with a bucket policy (not ACLs), and serve via `STORAGE_CDN`. The returned `public_url` is the link.
- **Private files** (user documents, receipts): keep the bucket private; serve each access through `presigned_url(key)`.

## Step 3: Route (thin)

```python
from flask import request, flash, redirect, url_for
import sources.storage as storage

@app.route("/upload", methods=["POST"])
def upload():
    f = request.files.get("file")
    if not f or not f.filename:
        flash("No file selected.", "danger")
        return redirect(request.referrer or url_for("index"))
    try:
        public_url, key = storage.upload_file(f, prefix="uploads")
    except ValueError as e:
        flash(str(e), "danger")
        return redirect(request.referrer or url_for("index"))
    # Persist url + key on the relevant document via a modules/ function.
    # (Store `key` so you can issue a presigned_url(key) later for private files.)
    return redirect(url_for("index"))
```

The upload form needs `enctype="multipart/form-data"` and `<input type="file" name="file">`. Store the returned URL on the owning document with a `modules/` function — `storage.py` only uploads.

## Step 4: Verify

- Boot the app; POST a small PNG to `/upload`; confirm the object exists in the bucket and the returned CDN URL loads.
- POST a `.exe` or an 11 MB file; confirm it's rejected with the flash message (no upload).
- Confirm credentials come from env, never hardcoded.

## Rules

- `sources/storage.py` only uploads / signs URLs — persistence to Mongo belongs in a `modules/` function.
- **Don't set per-object ACLs.** Modern S3 has ACLs disabled by default; use a bucket policy for public prefixes or presigned URLs for private objects. Only use `ACL="public-read"` if you specifically target DigitalOcean Spaces.
- Prefer **presigned URLs** for anything user-private; don't make a bucket public just to avoid signing.
- Validate extension and size before uploading (`ALLOWED_EXTS`, `MAX_BYTES`). Never trust the client filename for the stored key — generate a UUID key.
- Credentials from env only. Never commit keys.
- Functional, imports at top, 4-space indent. The boto3 client is a module-level singleton (don't rebuild it per request).
