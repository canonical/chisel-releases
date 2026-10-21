import importlib
import pkgutil
from pathlib import Path

import wheel
from wheel._metadata import convert_requirements
from wheel.wheelfile import WheelFile

# bdist_wheel is a setuptools command, and wheel does not depend on setuptools. macosx_libfile is
# for bdist_wheel on macOS and needs ctypes.
for module in pkgutil.walk_packages(wheel.__path__, "wheel."):
    if "bdist_wheel" not in module.name and module.name != "wheel.macosx_libfile":
        importlib.import_module(module.name)

assert list(convert_requirements(["demo[cli]>=1.0"])) == ["demo[cli] >=1.0"]

path = Path("/demo-1.0-py3-none-any.whl")
with WheelFile(path, "w") as archive:
    archive.writestr("demo.py", "VALUE = 42\n")
    archive.writestr("demo-1.0.dist-info/METADATA", "Metadata-Version: 2.1\nName: demo\nVersion: 1.0\n")
    archive.writestr("demo-1.0.dist-info/WHEEL", "Wheel-Version: 1.0\nRoot-Is-Purelib: true\nTag: py3-none-any\n")

# Reading checks every file against the RECORD the writer added.
with WheelFile(path) as archive:
    assert archive.parsed_filename.group("name") == "demo"
    assert archive.read("demo.py") == b"VALUE = 42\n"
    assert "demo-1.0.dist-info/RECORD" in archive.namelist()
