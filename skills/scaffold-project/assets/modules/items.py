# Business logic for "items". Pure functions, direct PyMongo calls.
# Every function takes `db` explicitly — no global DB access, no classes.
from bson.objectid import ObjectId

from sources.functions import utcnow


def list_recent(db, limit=20):
    """Return the most recent items, newest first."""
    return list(db.items.find().sort("_id", -1).limit(limit))


def get(db, item_id):
    """Return a single item by its string id, or None."""
    return db.items.find_one({"_id": ObjectId(item_id)})


def create(db, name):
    """Insert a new item and return its inserted id."""
    result = db.items.insert_one({"name": name, "created_at": utcnow()})
    return result.inserted_id
