# Shared helper functions. Pure, stateless, imported wherever needed.
from datetime import datetime, timezone


def utcnow():
    """Timezone-aware current UTC timestamp."""
    return datetime.now(timezone.utc)
