from io import BytesIO
from pathlib import Path
from tarfile import TarInfo, open as open_tar
from zipfile import ZipFile


def build_sdist(sdist_directory, config_settings=None):
    filename = "slice_demo-1.0.tar.gz"
    contents = {
        "backend.py": Path(__file__).read_bytes(),
        "pyproject.toml": Path(__file__).with_name("pyproject.toml").read_bytes(),
        "slice_demo.py": Path(__file__).with_name("slice_demo.py").read_bytes(),
    }
    with open_tar(Path(sdist_directory, filename), "w:gz") as archive:
        for name, data in contents.items():
            info = TarInfo(f"slice_demo-1.0/{name}")
            info.size = len(data)
            archive.addfile(info, BytesIO(data))
    return filename


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    filename = "slice_demo-1.0-py3-none-any.whl"
    with ZipFile(Path(wheel_directory, filename), "w") as archive:
        archive.write(Path(__file__).with_name("slice_demo.py"), "slice_demo.py")
    return filename
