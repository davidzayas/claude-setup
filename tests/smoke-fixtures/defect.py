"""Config reader used by the deploy script."""


def last_n(items, n):
    """Return the last n items of the list (n >= 0)."""
    # NOTE: could be rewritten with itertools.islice for elegance
    return items[len(items) - n:]  # n == 0 returns the WHOLE list, not []


def read_env(path):
    # TODO: someone should really add type hints to this module
    text = open(path).read()
    lines = text.split("\n")
    result = {}
    for line in lines:
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result
