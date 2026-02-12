#!/usr/bin/env python3
from __future__ import annotations

import logging
import os
import re
import subprocess as sub
import sys
import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from functools import total_ordering
from typing import Callable

## DISTRO INFO #################################################################


@total_ordering
@dataclass(frozen=True, order=False)
class UbuntuRelease:
    version: str
    codename: str

    def __str__(self) -> str:
        return f"ubuntu-{self.version} ({self.codename})"

    @property
    def version_tuple(self) -> tuple[int, int]:
        year, month = self.version.split(".")
        return int(year), int(month)

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, UbuntuRelease):
            return NotImplemented
        return self.version_tuple < other.version_tuple

    @classmethod
    def from_distro_info_line(cls, line: str) -> UbuntuRelease:
        match = re.match(r"Ubuntu (\d{1,2}\.\d{2})( LTS)? \"([A-Za-z ]+)\"", line)
        if not match:
            raise ValueError(f"Invalid distro-info line: '{line}'")
        return cls(version=match.group(1), codename=match.group(3))

    @classmethod
    def from_branch_name(cls, branch: str) -> UbuntuRelease:
        assert branch.startswith("ubuntu-"), "Branch name must start with 'ubuntu-'"
        version = branch.split("-", 1)[1]
        codename = _VERSION_TO_CODENAME.get(version)
        if codename is None:
            raise ValueError(f"Unknown Ubuntu version '{version}' for branch '{branch}'")
        return cls(version=version, codename=codename)

    @property
    def short_codename(self) -> str:
        """Return the first word of the codename in lowercase. E.g. 'focal' from 'Focal Fossa'."""
        return self.codename.split()[0].lower()

    @classmethod
    def from_dict(cls, data: dict) -> UbuntuRelease:
        return cls(
            version=data["version"],
            codename=data["codename"],
        )


_ALL_RELEASES: set[UbuntuRelease] = set()
_VERSION_TO_CODENAME: dict[str, str] = {}
SUPPORTED_RELEASES: set[UbuntuRelease] = set()
_DEVEL_RELEASE: UbuntuRelease | None = None


def init_distro_info() -> None:
    all_output = sub.getoutput("distro-info --all --fullname").strip()
    supported_output = sub.getoutput("distro-info --supported --fullname").strip()
    devel_output = sub.getoutput("distro-info --devel --fullname").strip()

    global _ALL_RELEASES, _VERSION_TO_CODENAME, SUPPORTED_RELEASES, _DEVEL_RELEASE

    _ALL_RELEASES = set(UbuntuRelease.from_distro_info_line(line) for line in all_output.splitlines())
    _VERSION_TO_CODENAME = {release.version: release.codename for release in _ALL_RELEASES}

    SUPPORTED_RELEASES = set(UbuntuRelease.from_distro_info_line(line) for line in supported_output.splitlines())
    assert SUPPORTED_RELEASES.issubset(_ALL_RELEASES), "Supported releases must be a subset of all releases."

    _DEVEL_RELEASE = UbuntuRelease.from_distro_info_line(devel_output) if devel_output else None
    assert _DEVEL_RELEASE is None or _DEVEL_RELEASE in _ALL_RELEASES, "Devel release must be in all releases."


################################################################################

CHISEL_RELEASES_URL = os.environ.get("CHISEL_RELEASES_URL", "https://github.com/canonical/chisel-releases")


@contextmanager
def timing_context() -> Iterator[Callable[[], float]]:
    t1 = t2 = time.perf_counter()
    yield lambda: t2 - t1
    t2 = time.perf_counter()


def print_pipe_friendly(output: str) -> None:
    """Print to stdout. Make sure we work with pipes.
    https://docs.python.org/3/library/signal.html#note-on-sigpipe
    """
    try:
        print(output)
        sys.stdout.flush()
    except BrokenPipeError:
        # Gracefully handle broken pipe when e.g. piping to head
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)


@dataclass(frozen=True)
class Commit:
    ref: str
    repo_name: str
    repo_owner: str
    repo_url: str
    sha: str

    @classmethod
    def from_github_json(cls, data: dict) -> Commit:
        return Commit(
            ref=data["ref"],
            repo_name=data["repo"]["name"],
            repo_owner=data["repo"]["owner"]["login"],
            repo_url=data["repo"]["html_url"],
            sha=data["sha"],
        )

    @classmethod
    def from_dict(cls, data: dict) -> Commit:
        return Commit(
            ref=data["ref"],
            repo_name=data["repo_name"],
            repo_owner=data["repo_owner"],
            repo_url=data["repo_url"],
            sha=data["sha"],
        )


FORWARD_PORT_MISSING_LABEL = "forward port missing"


@total_ordering
@dataclass(frozen=True, order=False)
class PR:
    number: int
    title: str
    user: str
    head: Commit
    base: Commit
    label: bool
    url: str

    @property
    def ubuntu_release(self) -> UbuntuRelease:
        return UbuntuRelease.from_branch_name(self.base.ref)

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, PR):
            return NotImplemented
        return self.number < other.number

    @classmethod
    def from_github_json(cls, data: dict) -> PR:
        has_label = any(label.get("name") == FORWARD_PORT_MISSING_LABEL for label in data["labels"])
        return PR(
            number=data["number"],
            title=data["title"],
            user=data["user"]["login"],
            head=Commit.from_github_json(data["head"]),
            base=Commit.from_github_json(data["base"]),
            label=has_label,
            url=data["html_url"],
        )

    @classmethod
    def from_dict(cls, data: dict) -> PR:
        return PR(
            number=data["number"],
            title=data["title"],
            user=data["user"],
            head=Commit.from_dict(data["head"]),
            base=Commit.from_dict(data["base"]),
            label=data["label"],
            url=data["url"],
        )


def check_github_token() -> None:
    token = os.getenv("GITHUB_TOKEN", None)
    if token is not None:
        logging.debug("GITHUB_TOKEN is set.")
        if not token.strip():
            logging.warning("GITHUB_TOKEN is empty.")
    else:
        logging.debug("GITHUB_TOKEN is not set.")
