from pathlib import Path
from zipfile import ZipFile

from build import ProjectBuilder


builder = ProjectBuilder("/tmp/project")
assert builder.build_system_requires == set()
wheel = builder.build("wheel", "/tmp/wheels")
with ZipFile(wheel) as archive:
    assert "api_demo.py" in archive.namelist()
assert Path(wheel).name == "api_demo-1.0-py3-none-any.whl"

print("success")
