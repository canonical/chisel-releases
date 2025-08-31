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


def test_version_matches_between_main_and_pyproject() -> None:
    from forward_port_missing import __version__

    main_version = Version(__version__)

    pyproject_version = get_version_from_pyproject(PYPROJECT_FILE)

    assert main_version == pyproject_version, (
        f"Version mismatch: {main_version} in 'forward_port_missing.py' "
        f"and {pyproject_version} in '{PYPROJECT_FILE.name}'. If in doubt, "
        "the version in the main file is the source of truth."
    )


def test_version_in_changelog_matches_main() -> None:
    from forward_port_missing import __changelog__, __version__

    main_version = Version(__version__)

    assert len(__changelog__) > 0, "__changelog__ is empty."

    # Get the version from top of the changelog
    changelog_version = Version(__changelog__[0][0])
    assert main_version == changelog_version, (
        f"Version mismatch: {main_version} in 'forward_port_missing.py' "
        f"and {changelog_version} in __changelog__. If in doubt, "
        "the version in the main file is the source of truth."
    )


def test_changelog_is_sorted() -> None:
    from forward_port_missing import __changelog__

    assert len(__changelog__) > 0, "__changelog__ is empty."

    versions = [Version(entry[0]) for entry in __changelog__]
    sorted_versions = sorted(versions, reverse=True)
    assert versions == sorted_versions, "__changelog__ is not sorted by version in descending order."
