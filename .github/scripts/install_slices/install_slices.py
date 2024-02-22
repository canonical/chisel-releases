#!/usr/bin/python3

"""
Verify chisel slice definition files by installing the slices.

Usage
-----
install_slices [-h] --arch ARCH --release RELEASE [--dry-run]
               [--ensure-existence] [--ignore-missing] [file ...]

positional arguments:
  file                Chisel slice definition file(s)

options:
  -h, --help          show this help message and exit
  --arch ARCH         Package architecture
  --release RELEASE   chisel-releases branch name or directory
  --dry-run           Perform dry run: do not actually install the slices
  --ensure-existence  Each package must exist in the archive for at least one architecture
  --ignore-missing    Ignore arch-specific package not found in archive errors
"""

import argparse
from dataclasses import dataclass
import logging
import os
import subprocess
import tempfile
import sys

import requests
import yaml


def configure_logging() -> None:
    """
    Configure the logging options for this script.
    """
    logging.basicConfig(
        format="%(levelname)s: %(message)s",
        level=logging.INFO,
    )


def parse_args() -> argparse.Namespace:
    """
    Parse CLI args passed to this script.
    """
    parser = argparse.ArgumentParser(
        description="Verify slice definition files by installing the slices",
    )
    parser.add_argument(
        "--arch",
        required=True,
        help="Package architecture",
    )
    parser.add_argument(
        "--release",
        required=True,
        help="chisel-releases branch name or directory",
    )
    parser.add_argument(
        "--dry-run",
        required=False,
        action="store_true",
        help="Perform dry run: do not actually install the slices",
    )
    parser.add_argument(
        "--ensure-existence",
        required=False,
        action="store_true",
        help="Each package must exist in the archive for at least one architecture",
    )
    parser.add_argument(
        "--ignore-missing",
        required=False,
        action="store_true",
        help="Ignore arch-specific package not found in archive errors",
    )
    parser.add_argument(
        "files",
        metavar="file",
        help="Chisel slice definition file(s)",
        nargs="*",
    )
    return parser.parse_args()


@dataclass
class Archive:
    """
    Minimal data class replicating ubuntu archive in chisel.yaml.
    """

    version: str
    components: list[str]
    suites: list[str]


def parse_archive(release: str) -> Archive:
    """
    Parse the "ubuntu" archive from the chisel.yaml file of a release.
    The chisel.yaml file has the following structure:
        ...
        archives:
            ubuntu:
                version: 22.04
                components: [main, universe]
                suites: [jammy, jammy-security, jammy-updates]
                ...
        ...
    """
    logging.debug("Parsing ubuntu archive info...")
    # (download and) parse chisel.yaml for ubuntu archive info
    try:
        if "/" in release:
            filepath = os.path.join(release, "chisel.yaml")
            with open(filepath, "r", encoding="utf-8") as stream:
                data = yaml.safe_load(stream)
        else:
            base_url = "https://raw.githubusercontent.com/canonical/chisel-releases"
            req_url = f"{base_url}/{release}/chisel.yaml"
            response = requests.get(req_url, timeout=30)
            response.raise_for_status()
            data = yaml.safe_load(response.content)
    except yaml.YAMLError as e:
        logging.error("chisel.yaml: %s", e)
        sys.exit(1)
    # load the yaml data into Archive
    archive_data = data["archives"]["ubuntu"]
    archive = Archive(
        str(archive_data["version"]), archive_data["components"], archive_data["suites"]
    )
    return archive


@dataclass
class Package:
    """
    Minimal data class to store package info.
    """

    package: str
    slices: list[str]


def full_slice_name(pkg: str, slice: str) -> str:
    """
    Return the full slice name in "pkg_slice" format.
    """
    return f"{pkg}_{slice}"


def parse_package(filepath: str) -> Package:
    """
    Parse a slice definition file and return the Package.
    """
    logging.debug("Parsing %s...", filepath)
    with open(filepath, "r", encoding="utf-8") as stream:
        try:
            data = yaml.safe_load(stream)
        except yaml.YAMLError as e:
            logging.error("%s: %s", filepath, e)
            sys.exit(1)
    try:
        package = data["package"]
        slices = list(data["slices"].keys())
        slices = sorted(slices)
    except KeyError as e:
        logging.error("%s: key %s not found", filepath, e)
        sys.exit(1)
    pkg = Package(package, slices)
    return pkg


def query_package_existence(
    packages: list[str],
    archive: Archive,
    arch: list[str] | None = None,
) -> tuple[list[str], list[str]]:
    """
    Check which packages exist in the archive. Return a list of packages
    that exist and another list for which do not.
    """
    # Prepare cmd.
    args = ["rmadison"]
    if arch and len(arch) > 0:
        args += ["--architecture", ",".join(arch)]
    if len(archive.components) > 0:
        args += ["--component", ",".join(archive.components)]
    if len(archive.suites) > 0:
        args += ["--suite", ",".join(archive.suites)]
    args.append(" ".join(packages))
    # Query the archives using rmadison.
    logging.debug("Querying the archives for packages...")
    logging.debug("Executing %s", " ".join(args))
    res = subprocess.run(args, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        logging.error("Failed to query the archives %d", res.returncode)
        sys.exit(res.returncode)
    output = res.stdout.rstrip()
    logging.debug("Archive query output:\n%s", output)
    # Parse the output for available packages.
    found = []
    for line in output.split("\n"):
        line = line.strip()
        if line == "":
            continue
        pkg = line.split("|")[0].strip()
        found.append(pkg)
    found = list(set(found))
    missing = list(set(packages) - set(found))
    return sorted(found), sorted(missing)


def ensure_package_existence(packages: list[str], archive: Archive) -> None:
    """
    Ensure that packages exist in the archive for any arch.
    """
    logging.info("Ensuring packages existence in ubuntu-%s archive...", archive.version)
    _, missing = query_package_existence(packages, archive)
    if len(missing) > 0:
        logging.error(
            "The following packages do not exist for ubuntu-%s:\n%s",
            archive.version,
            "\n".join(f"  - {p}" for p in missing),
        )
        sys.exit(1)


def ignore_missing_packages(
    packages: list[Package],
    arch: str,
    release: str,
) -> tuple[list[Package], list[Package]]:
    """
    Filter the packages that do not exist in the archive for [arch, release].
    """
    package_names = [p.package for p in packages]
    archive = parse_archive(release)
    found, _ = query_package_existence(package_names, archive, arch=[arch])
    #
    logging.info("Ignoring missing packages in ubuntu-%s/%s...", archive.version, arch)
    filtered = []
    ignored = []
    for p in packages:
        if p.package in found:
            filtered.append(p)
        else:
            ignored.append(p)
    return filtered, ignored


def install_slice(slice: str, arch: str, release: str) -> None:
    """
    Install the slice by running "chisel cut".
    """
    logging.info("Installing %s on %s...", slice, arch)
    with tempfile.TemporaryDirectory() as tmpfs:
        res = subprocess.run(
            args=[
                "chisel",
                "cut",
                "--arch",
                arch,
                "--release",
                release,
                "--root",
                tmpfs,
                slice,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode != 0:
            logging.error(
                "==============================================\n%s",
                res.stderr.rstrip(),
            )
            sys.exit(res.returncode)


def main() -> None:
    """
    The main function -- execution should start from here.
    """
    configure_logging()
    cli_args = parse_args()
    # Parse slice definition files.
    packages = []
    for file in cli_args.files:
        pkg = parse_package(file)
        packages.append(pkg)
    # Ensure package existence for at least one architecture. This means that
    # each package must be present in the archive for at least one of the
    # architectures.
    if cli_args.ensure_existence:
        archive = parse_archive(cli_args.release)
        ensure_package_existence([p.package for p in packages], archive)
    # Ignore packages who do not exist in the archive for this particular
    # architecture.
    if cli_args.ignore_missing:
        packages, ignored = ignore_missing_packages(
            packages, cli_args.arch, cli_args.release
        )
        if len(ignored) > 0:
            logging.info("The following packages will be IGNORED:")
            for pkg in ignored:
                logging.info("  - %s", pkg.package)
    #
    if len(packages) > 0:
        logging.info("Slices of the following packages will be INSTALLED:")
        for pkg in packages:
            logging.info("  - %s", pkg.package)
    else:
        logging.info("No slices will be installed.")
        return
    # Install the slices in each package.
    for pkg in packages:
        for slice in pkg.slices:
            if cli_args.dry_run:
                logging.info(
                    "Installing %s on %s... (--dry-run)",
                    full_slice_name(pkg.package, slice),
                    cli_args.arch,
                )
            else:
                install_slice(
                    full_slice_name(pkg.package, slice),
                    cli_args.arch,
                    cli_args.release,
                )


if __name__ == "__main__":
    main()
