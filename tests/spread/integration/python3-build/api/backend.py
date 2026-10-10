from pathlib import Path
from zipfile import ZipFile


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    filename = "api_demo-1.0-py3-none-any.whl"
    with ZipFile(Path(wheel_directory, filename), "w") as archive:
        archive.write(Path(__file__).with_name("api_demo.py"), "api_demo.py")
    return filename
