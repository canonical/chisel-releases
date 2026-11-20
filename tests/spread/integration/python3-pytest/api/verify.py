from contextlib import redirect_stderr, redirect_stdout
from io import StringIO

import pytest


stdout = StringIO()
stderr = StringIO()
with redirect_stdout(stdout), redirect_stderr(stderr):
    result = pytest.main(["-q", "/tmp/project/test_api.py"])
assert result == pytest.ExitCode.OK
assert "1 passed" in stdout.getvalue()
assert not stderr.getvalue()

print("success")
