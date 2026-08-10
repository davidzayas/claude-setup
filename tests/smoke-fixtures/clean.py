"""Pure helpers with no known defects."""


def clamp(value, low, high):
    """Return value bounded to [low, high]. Assumes low <= high."""
    if low > high:
        raise ValueError(f"low ({low}) must be <= high ({high})")
    return max(low, min(value, high))


def chunks(items, size):
    """Yield successive size-length chunks; size must be positive."""
    if size <= 0:
        raise ValueError(f"size must be positive, got {size}")
    for start in range(0, len(items), size):
        yield items[start:start + size]
