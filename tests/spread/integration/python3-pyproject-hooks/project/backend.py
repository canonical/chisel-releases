from pathlib import Path


def get_requires_for_build_wheel(config_settings=None):
    return ["demo>=1"]


def prepare_metadata_for_build_wheel(metadata_directory, config_settings=None):
    dist_info = Path(metadata_directory, "demo-1.0.dist-info")
    dist_info.mkdir()
    Path(dist_info, "METADATA").write_text("Name: demo\nVersion: 1.0\n")
    return dist_info.name


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    wheel = Path(wheel_directory, "demo-1.0-py3-none-any.whl")
    wheel.write_bytes(b"wheel")
    return wheel.name
