from pathlib import Path
from tarfile import open as open_tar
from zipfile import ZipFile


dist = Path("/tmp/dist")
wheel = next(dist.glob("slice_demo-1.0-py3-none-any.whl"))
sdist = next(dist.glob("slice_demo-1.0.tar.gz"))
with ZipFile(wheel) as archive:
    assert "slice_demo.py" in archive.namelist()
with open_tar(sdist) as archive:
    assert "slice_demo-1.0/slice_demo.py" in archive.getnames()

print("success")
