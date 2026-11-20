from pathlib import Path

from pyproject_hooks import BuildBackendHookCaller


hooks = BuildBackendHookCaller(
    "/tmp/project",
    "backend",
    backend_path=["."],
)
assert hooks.get_requires_for_build_wheel() == ["demo>=1"]

dist_info = hooks.prepare_metadata_for_build_wheel("/tmp/metadata")
assert dist_info == "demo-1.0.dist-info"
assert Path("/tmp/metadata", dist_info, "METADATA").read_text() == (
    "Name: demo\nVersion: 1.0\n"
)

wheel = hooks.build_wheel("/tmp/wheels")
assert wheel == "demo-1.0-py3-none-any.whl"
assert Path("/tmp/wheels", wheel).read_bytes() == b"wheel"

print("success")
