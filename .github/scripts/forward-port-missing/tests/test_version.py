from pathlib import Path

from conftest import __project_root__
from packaging.version import Version

PYPROJECT_FILE = __project_root__ / "pyproject.toml"


def get_version_from_pyproject(file: Path) -> Version:
    # Ideally we would parse the toml, but python backporting support for
    # tomli or other toml parsers is a but meh, so we will just read the file
    lines = file.read_text().splitlines()
    for line in lines:
        if line.startswith("version ="):
            version_str = line.split("=")[1].strip().strip('"').strip("'")
            return Version(version_str)
    raise ValueError(f"Version not found in {file}")


def test_version_matches_scripts() -> None:
    from chisel_releases_data import __version__ as _crd_version
    from forward_port_missing import __version__ as _fpm_version

    crd_version = Version(_crd_version)
    fpm_version = Version(_fpm_version)

    newer_name = "forward_port_missing.py" if fpm_version > crd_version else "chisel_releases_data.py"
    older_name = "chisel_releases_data.py" if fpm_version > crd_version else "forward_port_missing.py"

    assert crd_version == fpm_version, (
        f"Version mismatch: {crd_version} in 'chisel_releases_data.py "
        f"and {fpm_version} in 'forward_port_missing.py'. The version in "
        f"'{newer_name}' is newer. Maybe you forgot to update '{older_name}'?"
    )


def test_version_in_pyproject_matches_chisel_releases_data() -> None:
    from chisel_releases_data import __version__ as _crd_version

    crd_version = Version(_crd_version)
    pyproject_version = get_version_from_pyproject(PYPROJECT_FILE)

    assert crd_version == pyproject_version, (
        f"Version mismatch: {crd_version} in 'chisel_releases_data.py' "
        f"and {pyproject_version} in '{PYPROJECT_FILE.name}'. If in doubt, "
        "__version__ in 'chisel_releases_data.py' is the source of truth."
    )


def test_version_in_changelog_matches_chisel_releases_data() -> None:
    from chisel_releases_data import __changelog__, __version__

    main_version = Version(__version__)

    assert len(__changelog__) > 0, "__changelog__ is empty."

    # Get the version from top of the changelog
    changelog_version = Version(__changelog__[0][0])
    assert main_version == changelog_version, (
        f"Version mismatch: {main_version} in 'chisel_releases_data.py' "
        f"and {changelog_version} in __changelog__. If in doubt, "
        "__version__ is the source of truth."
    )


def test_changelog_is_sorted_chisel_releases_data() -> None:
    from chisel_releases_data import __changelog__

    assert len(__changelog__) > 0, "__changelog__ is empty."

    versions = [Version(entry[0]) for entry in __changelog__]
    sorted_versions = sorted(versions, reverse=True)
    assert versions == sorted_versions, "__changelog__ is not sorted by version in descending order."


def test_version_in_changelog_matches_forward_port_missing() -> None:
    from forward_port_missing import __changelog__, __version__

    main_version = Version(__version__)

    assert len(__changelog__) > 0, "__changelog__ is empty."

    # Get the version from top of the changelog
    changelog_version = Version(__changelog__[0][0])
    assert main_version == changelog_version, (
        f"Version mismatch: {main_version} in 'forward_port_missing.py' "
        f"and {changelog_version} in __changelog__. If in doubt, "
        "__version__ is the source of truth."
    )


def test_changelog_is_sorted_forward_port_missing() -> None:
    from forward_port_missing import __changelog__

    assert len(__changelog__) > 0, "__changelog__ is empty."

    versions = [Version(entry[0]) for entry in __changelog__]
    sorted_versions = sorted(versions, reverse=True)
    assert versions == sorted_versions, "__changelog__ is not sorted by version in descending order."
