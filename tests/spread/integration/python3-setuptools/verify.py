import os
import tarfile
import zipfile
from pathlib import Path

from setuptools import build_meta

project = Path("/project")
(project / "demo").mkdir(parents=True)
(project / "demo" / "__init__.py").write_text("VALUE = 42\n")
(project / "pyproject.toml").write_text(
    '[build-system]\nrequires = ["setuptools"]\nbuild-backend = "setuptools.build_meta"\n\n'
    '[project]\nname = "demo"\nversion = "1.0"\n'
)
os.chdir(project)

wheel = build_meta.build_wheel("/dist")
assert "demo/__init__.py" in zipfile.ZipFile(f"/dist/{wheel}").namelist()

sdist = build_meta.build_sdist("/dist")
assert "demo-1.0/demo/__init__.py" in tarfile.open(f"/dist/{sdist}").getnames()
