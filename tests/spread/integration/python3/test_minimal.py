"""minimal is the interpreter without the stdlib extras of core."""

try:
    import queue  # noqa: F401
except ImportError:
    pass
else:
    raise AssertionError("python3_minimal ships queue, which belongs to core")
