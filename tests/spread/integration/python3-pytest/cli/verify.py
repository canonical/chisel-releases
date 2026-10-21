import subprocess


result = subprocess.run(
    ["/usr/bin/pytest", "-q", "/tmp/project/test_features.py"],
    capture_output=True,
    check=False,
    text=True,
)
assert result.returncode == 0, result.stderr
assert "2 passed" in result.stdout

print("success")
