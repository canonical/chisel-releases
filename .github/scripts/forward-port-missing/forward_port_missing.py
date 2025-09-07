#!/usr/bin/env python3
"""
Check labels on PRs and forward-port if needed.

This the read-only part of the forward porting check.
It pulls the data form relevant places, executes the logic and outputs
the results in text/json format.

This script will use the `GITHUB_TOKEN` variable if set.
"""
# spell-checker: ignore Marcin Konowalczyk lczyk
# spell-checker: words levelname
# mypy: disable-error-code="unused-ignore"

from __future__ import annotations

import argparse
import json
import logging
import os
import pickle
import sys
import zlib
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from functools import total_ordering
from pathlib import Path
from typing import TYPE_CHECKING, Any, Protocol, TypeAlias

__version__ = "0.1.0"
__author__ = "Marcin Konowalczyk"

__changelog__ = [
    ("0.1.0", "split into two scripts", "@lczyk"),
    ("0.0.12", "fix more grouping bugs", "@lczyk"),
    ("0.0.11", "grouping bug + handle non-ascii in titles", "@lczyk"),
    ("0.0.10", "print the fp label status", "@lczyk"),
    ("0.0.9", "fix crash on prs with no new slices", "@lczyk"),
    ("0.0.8", "output formatting + bugfixes", "@lczyk"),
    ("0.0.7", "fetching package lists for FP missing releases", "@lczyk"),
    ("0.0.6", "main forward-porting logic implemented", "@lczyk"),
    ("0.0.5", "slice diff from the merge base, not the branch head", "@lczyk"),
    ("0.0.4", "--jobs for parallel slice fetching", "@lczyk"),
    ("0.0.3", "get_slices_in_pr implemented", "@lczyk"),
    ("0.0.2", "currently_supported_ubuntu_releases implemented", "@lczyk"),
    ("0.0.1", "initial testing", "@lczyk"),
    ("0.0.0", "boilerplate", "@lczyk"),
]

################################################################################


_UbuntuReleaseState: TypeAlias = tuple[str, str]
_UbuntuReleaseStateLen = 2


@total_ordering
@dataclass(frozen=True, order=False)
class UbuntuRelease:
    version: str
    codename: str

    def __str__(self) -> str:
        return f"ubuntu-{self.version} ({self.codename})"

    @property
    def version_tuple(self) -> tuple[int, int]:
        return self.version_to_tuple(self.version)

    @staticmethod
    def version_to_tuple(version: str) -> tuple[int, int]:
        year, month = version.split(".")
        return int(year), int(month)

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, UbuntuRelease):
            return NotImplemented
        return self.version_tuple < other.version_tuple

    def __getstate__(self) -> _UbuntuReleaseState:
        return (self.version, self.codename)

    def __setstate__(self, state: _UbuntuReleaseState) -> None:
        assert len(state) == _UbuntuReleaseStateLen, "Invalid state length."
        for i, field_name in enumerate(self.__dataclass_fields__):
            object.__setattr__(self, field_name, state[i])

    @classmethod
    def from_state(cls, state: _UbuntuReleaseState) -> UbuntuRelease:
        obj = cls.__new__(cls)
        obj.__setstate__(state)
        return obj

    # sabotage pickling
    def __reduce__(self) -> str | tuple[object, ...]:
        raise ValueError(f"{self.__class__.__name__} instances cannot be pickled.")


## IMPL ########################################################################

_CommitState: TypeAlias = tuple[str, str, str, str, str]
_CommitStateLen = 5


@dataclass(frozen=True, unsafe_hash=True)
class Commit:
    ref: str  # Branch name
    repo_name: str  # Name of the repository
    repo_owner: str  # Owner of the repository
    repo_url: str = field(repr=False)  # URL of the repository
    sha: str = field(repr=False)  # SHA of the commit

    def __getstate__(self) -> _CommitState:
        return (self.ref, self.repo_name, self.repo_owner, self.repo_url, self.sha)

    def __setstate__(self, state: _CommitState) -> None:
        assert len(state) == _CommitStateLen, "Invalid state length."
        for i, field_name in enumerate(self.__dataclass_fields__):
            object.__setattr__(self, field_name, state[i])

    # sabotage pickling
    def __reduce__(self) -> str | tuple[object, ...]:
        raise ValueError(f"{self.__class__.__name__} instances cannot be pickled.")


_PRState: TypeAlias = tuple[int, str, str, _CommitState, _CommitState, bool, str, _UbuntuReleaseState]
_PRStateLen = 8


@total_ordering
@dataclass(frozen=True, unsafe_hash=True, order=False)
class PR:
    number: int  # number of the PR, e.g #601
    title: str  # title of the PR
    user: str  # user who created the PR (usually, but not necessarily, the author)
    head: Commit
    base: Commit
    label: bool  # whether the PR has the forward-port-missing label
    url: str = field(repr=False)  # URL of the PR

    _ubuntu_release: UbuntuRelease = field(repr=False, compare=False, hash=False)

    @property
    def ubuntu_release(self) -> UbuntuRelease:
        return self._ubuntu_release

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, PR):
            return NotImplemented
        return self.number < other.number

    def __getstate__(self) -> _PRState:
        return tuple(
            getattr(self, field) if field not in ("head", "base") else getattr(self, field).__getstate__()
            for field in self.__dataclass_fields__
        )

    def __setstate__(self, state: _PRState) -> None:
        assert len(state) == _PRStateLen, "Invalid state length."
        obj: object
        for i, field_name in enumerate(self.__dataclass_fields__):
            if field_name in ("head", "base"):
                obj = Commit.__new__(Commit)
                obj.__setstate__(state[i])  # type: ignore
                object.__setattr__(self, field_name, obj)
            elif field_name == "_ubuntu_release":
                obj = UbuntuRelease.__new__(UbuntuRelease)
                obj.__setstate__(state[i])  # type: ignore
                object.__setattr__(self, field_name, obj)
            else:
                object.__setattr__(self, field_name, state[i])

    @classmethod
    def from_state(cls, state: _PRState) -> PR:
        pr = cls.__new__(cls)
        pr.__setstate__(state)
        return pr

    # sabotage pickling
    def __reduce__(self) -> str | tuple[object, ...]:
        raise ValueError(f"{self.__class__.__name__} instances cannot be pickled.")


def _group_new_slices_by_pr(
    slices_in_head_by_pr: Mapping[PR, frozenset[str]],
    slices_in_base_by_pr: Mapping[PR, frozenset[str]],
) -> dict[PR, frozenset[str]]:
    prs: set[PR] = set(slices_in_head_by_pr.keys())
    if set(slices_in_base_by_pr.keys()) != prs:
        raise ValueError("slices_in_head_by_pr and slices_in_base_by_pr must have the same keys.")
    new_slices_by_pr: dict[PR, frozenset[str]] = {}
    for pr in sorted(prs):
        slices_in_head = slices_in_head_by_pr.get(pr, frozenset())
        slices_in_base = slices_in_base_by_pr.get(pr, frozenset())
        new_slices = slices_in_head - slices_in_base
        removed_sliced = slices_in_base - slices_in_head
        if removed_sliced and logging.getLogger().isEnabledFor(logging.WARNING):
            slices_string = ", ".join(sorted(removed_sliced))
            slices_string = slices_string if len(slices_string) < 100 else slices_string[:97] + "..."
            logging.warning("PR #%d removed %d slices: %s", pr.number, len(removed_sliced), slices_string)
        if new_slices:
            new_slices_by_pr[pr] = frozenset(new_slices)
            if logging.getLogger().isEnabledFor(logging.DEBUG):
                slices_string = ", ".join(sorted(new_slices))
                slices_string = slices_string if len(slices_string) < 100 else slices_string[:97] + "..."
                logging.debug("PR #%d introduces %d new slices: %s", pr.number, len(new_slices), slices_string)
        else:
            logging.debug("PR #%d introduces no new slices.", pr.number)
    return new_slices_by_pr


@dataclass(frozen=False, unsafe_hash=True)
class Comparison:
    """A pair of PRs: one into a given release, and one into a future release."""

    pr: PR
    slices: frozenset[str]
    pr_future: PR
    slices_future: frozenset[str]

    # Slices from the ubuntu release of the base PR that have been
    # discontinued in the ubuntu release of the future PR.
    discontinued_slices: frozenset[str] = field(default_factory=frozenset, init=False)

    @property
    def ubuntu_release(self) -> UbuntuRelease:
        return self.pr.ubuntu_release

    @property
    def future_ubuntu_release(self) -> UbuntuRelease:
        return self.pr_future.ubuntu_release

    def __post_init__(self) -> None:
        if self.pr.ubuntu_release >= self.pr_future.ubuntu_release:
            raise ValueError("pr_future must be into a future release compared to pr.")
        self.slices = frozenset(self.slices)
        self.slices_future = frozenset(self.slices_future)

    def is_forward_ported(self) -> bool:
        return not self.missing_slices()

    def __str__(self) -> str:
        return (
            f"#{self.pr.number}-{self.ubuntu_release.version}.."
            f"#{self.pr_future.number}-{self.future_ubuntu_release.version}"
        )

    def missing_slices(self) -> frozenset[str]:
        missing_slices = self.slices - self.slices_future
        if not missing_slices:
            return frozenset()
        if self.discontinued_slices:
            # some slices were discontinued, so they are missing for a reason
            missing_slices -= self.discontinued_slices
        return frozenset(missing_slices)

    def overlap(self) -> frozenset[str]:
        return self.slices.intersection(self.slices_future)

    # sabotage pickling
    def __reduce__(self) -> str | tuple[object, ...]:
        raise ValueError(f"{self.__class__.__name__} instances cannot be pickled.")


def _get_comparisons(
    prs_by_ubuntu_release: Mapping[UbuntuRelease, frozenset[PR]],
    new_slices_by_pr: Mapping[PR, frozenset[str]],
) -> frozenset[Comparison]:
    prs: set[PR] = set()
    for prs_in_release in prs_by_ubuntu_release.values():
        prs.update(prs_in_release)

    # For each PR we have a mapping from ubuntu release to a set of PRs that
    # forward-port the new slices to that release. An empty set means no
    # forward-port found, a set with None means no new slices to forward-port.
    comparisons: set[Comparison] = set()

    for ubuntu_release, prs_in_release in prs_by_ubuntu_release.items():
        future_releases = [r for r in prs_by_ubuntu_release if r > ubuntu_release]
        if not future_releases:
            logging.debug(
                "No future releases for %s. Skipping all %d PRs into it.", ubuntu_release, len(prs_in_release)
            )
            continue

        for pr in prs_in_release:
            new_slices = new_slices_by_pr.get(pr, frozenset())
            for future_release in future_releases:
                prs_into_future_release = prs_by_ubuntu_release.get(future_release, frozenset())
                if not prs_into_future_release:
                    logging.debug("No PRs into future release %s of PR #%d", future_release, pr.number)
                    # No PRs into this future release
                    continue

                for pr_future in prs_into_future_release:
                    new_slices_in_future = new_slices_by_pr.get(pr_future, frozenset())
                    comparisons.add(
                        Comparison(
                            pr=pr,
                            slices=new_slices,
                            pr_future=pr_future,
                            slices_future=new_slices_in_future,
                        )
                    )
    return frozenset(comparisons)


def _get_grouped_comparisons(
    prs_by_ubuntu_release: Mapping[UbuntuRelease, frozenset[PR]],
    new_slices_by_pr: Mapping[PR, frozenset[str]],
) -> Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]]:
    comparisons = _get_comparisons(prs_by_ubuntu_release, new_slices_by_pr)

    # For convenience we group the comparisons by the PR in the current release, and then by the future release.
    grouped_comparisons: dict[PR, dict[UbuntuRelease, set[Comparison]]] = {}
    for comparison in comparisons:
        pr = comparison.pr
        future_release = comparison.future_ubuntu_release
        if pr not in grouped_comparisons:
            grouped_comparisons[pr] = {}
        if future_release not in grouped_comparisons[pr]:
            grouped_comparisons[pr][future_release] = set()
        grouped_comparisons[pr][future_release].add(comparison)

    # We may not have all the PRs in the grouped_comparisons, since they may not have had any PRs to compare to.
    # We need to add them with empty dicts.
    for prs_in_release in prs_by_ubuntu_release.values():
        for pr in prs_in_release:
            if pr not in grouped_comparisons:
                grouped_comparisons[pr] = {}

    # For each of the dicts in grouped_comparisons, we want all of the future releases, even if there are no comparisons
    for pr, comparisons_by_future_release in grouped_comparisons.items():
        ubuntu_release = pr.ubuntu_release
        future_releases = [r for r in prs_by_ubuntu_release if r > ubuntu_release]
        for future_release in future_releases:
            if future_release not in comparisons_by_future_release:
                comparisons_by_future_release[future_release] = set()
    return {
        pr: {r: frozenset(comparison) for r, comparison in future_releases.items()}
        for pr, future_releases in grouped_comparisons.items()
    }


def _group_prs_by_ubuntu_release(
    prs: frozenset[PR], ubuntu_releases: list[UbuntuRelease]
) -> dict[UbuntuRelease, frozenset[PR]]:
    _prs_by_ubuntu_release: dict[UbuntuRelease, set[PR]] = {ubuntu_release: set() for ubuntu_release in ubuntu_releases}
    _prs = list(sorted(prs))  # we want list for logging
    for pr in _prs:
        if pr.ubuntu_release not in _prs_by_ubuntu_release:
            logging.warning("PR #%d is into unsupported Ubuntu release %s. Skipping.", pr.number, pr.ubuntu_release)
            continue
        _prs_by_ubuntu_release[pr.ubuntu_release].add(pr)
    prs_by_ubuntu_release: dict[UbuntuRelease, frozenset[PR]] = {
        k: frozenset(v) for k, v in _prs_by_ubuntu_release.items()
    }

    # Make sure we have all the ubuntu_releases as keys, even if they have no PRs
    for ubuntu_release in ubuntu_releases:
        if ubuntu_release not in prs_by_ubuntu_release:
            prs_by_ubuntu_release[ubuntu_release] = frozenset()

    return prs_by_ubuntu_release


def _add_discontinued_slices(
    grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
    packages_by_release: Mapping[UbuntuRelease, set[str]],
) -> None:
    if logging.getLogger().isEnabledFor(logging.DEBUG):
        for release, packages in packages_by_release.items():
            logging.debug("Release %s has %d packages.", release, len(packages))

    for pr, results_by_future in grouped_comparisons.items():
        for future_release, comparisons in results_by_future.items():
            packages = packages_by_release.get(future_release, set())
            if not packages:
                logging.debug(
                    "PR #%d into %s: No packages found for future release %s.",
                    pr.number,
                    pr.base.ref,
                    future_release,
                )
                continue
            _comparison = next(iter(comparisons), None)
            if not _comparison:
                continue
            discontinued_slices = _comparison.slices - packages
            if not discontinued_slices:
                continue
            if logging.getLogger().isEnabledFor(logging.DEBUG):
                slices_string = ", ".join(sorted(discontinued_slices))
                slices_string = slices_string if len(slices_string) < 100 else slices_string[:97] + "..."
                logging.debug(
                    "Adding %d discontinued slices for PR #%d into %s for future release %s: %s",
                    len(discontinued_slices),
                    pr.number,
                    pr.base.ref,
                    future_release,
                    slices_string,
                )

            for comparison in comparisons:
                comparison.discontinued_slices = frozenset(discontinued_slices)


def forward_porting_status(
    slices: frozenset[str],
    comparisons_by_future_release: Mapping[UbuntuRelease, Iterable[Comparison]],
) -> bool:
    """Each ubuntu release must have at least one comparison with no missing slices."""

    if not slices:
        return True

    for comparisons in comparisons_by_future_release.values():
        if not any(c.is_forward_ported() for c in comparisons):
            return False
    return True


################################################################################


class Loader(Protocol):
    def __init__(self, input: Path) -> None: ...

    def load(
        self,
    ) -> tuple[
        frozenset[PR],
        Mapping[PR, frozenset[str]],
        Mapping[PR, frozenset[str]],
        Mapping[UbuntuRelease, set[str]],
    ]: ...


class PickleLoader:
    def __init__(self, input: Path) -> None:
        if not input.is_file():
            raise FileNotFoundError(f"Input file '{input}' does not exist or is not a file.")
        self.input = input

    def load(
        self,
    ) -> tuple[
        frozenset[PR],
        Mapping[PR, frozenset[str]],
        Mapping[PR, frozenset[str]],
        Mapping[UbuntuRelease, set[str]],
    ]:
        logging.info("Loading data from '%s'...", self.input)

        with self.input.open("rb") as f:
            try:
                # Try to load as compressed first
                data = pickle.loads(zlib.decompress(f.read()))
            except zlib.error:
                # fallback to uncompressed
                f.seek(0)
                data = pickle.load(f)

        assert isinstance(data, dict), "Expected loaded data to be a dict."
        expected_keys = {"prs", "slices_in_head_by_pr", "slices_in_base_by_pr", "packages_by_release"}
        if set(data.keys()) != expected_keys:
            raise ValueError(f"Loaded data keys do not match expected keys: {expected_keys}")

        prs = frozenset(PR.from_state(state) for state in data["prs"])
        slices_in_head_by_pr = {PR.from_state(state): frozenset(v) for state, v in data["slices_in_head_by_pr"].items()}
        slices_in_base_by_pr = {PR.from_state(state): frozenset(v) for state, v in data["slices_in_base_by_pr"].items()}
        packages_by_release = {
            UbuntuRelease.from_state(state): set(v) for state, v in data["packages_by_release"].items()
        }

        logging.info("Loaded data from '%s'.", self.input)
        file_size = self.input.stat().st_size
        logging.info("Input file size: %.2f MiB", file_size / (1024 * 1024))

        return prs, slices_in_head_by_pr, slices_in_base_by_pr, packages_by_release


if TYPE_CHECKING:
    _pickle_loader: Loader = PickleLoader.__new__(PickleLoader)

## MAIN ########################################################################


def main(args: argparse.Namespace) -> None:
    loader = PickleLoader(args.input)

    prs, slices_in_head_by_pr, slices_in_base_by_pr, packages_by_release = loader.load()
    ubuntu_releases = sorted(packages_by_release.keys())

    prs_by_ubuntu_release = _group_prs_by_ubuntu_release(prs, ubuntu_releases)
    new_slices_by_pr = _group_new_slices_by_pr(slices_in_head_by_pr, slices_in_base_by_pr)
    grouped_comparisons = _get_grouped_comparisons(prs_by_ubuntu_release, new_slices_by_pr)
    _add_discontinued_slices(grouped_comparisons, packages_by_release)

    # Output
    formatter: JSONOutputFormatter | TextOutputFormatter
    if args.format == "json":
        formatter = JSONOutputFormatter(grouped_comparisons, new_slices_by_pr, add_extra_info=False)
    else:
        formatter = TextOutputFormatter(grouped_comparisons, new_slices_by_pr)

    # Print to stdout. Make sure we work with pipes.
    # https://docs.python.org/3/library/signal.html#note-on-sigpipe
    # spellchecker: ignore WRONLY
    try:
        print(formatter.format())
        sys.stdout.flush()
    except BrokenPipeError:
        # Gracefully handle broken pipe when e.g. piping to head
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)


################################################################################


class JSONOutputFormatter:
    def __init__(
        self,
        grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
        new_slices_by_pr: Mapping[PR, frozenset[str]],
        add_extra_info: bool = False,
    ) -> None:
        self.grouped_comparisons = grouped_comparisons
        self.new_slices_by_pr = new_slices_by_pr
        self.add_extra_info = add_extra_info

    @staticmethod
    def pr_to_dict(pr: PR) -> dict[str, Any]:
        return {
            "number": pr.number,
            "title": pr.title,
            "url": pr.url,
            "base": pr.base.ref,
            "head": f"{pr.head.repo_owner}/{pr.head.repo_name}/{pr.head.ref}",
        }

    def format(self) -> str:
        output = []
        for pr, comparisons_by_future_release in sorted(self.grouped_comparisons.items()):
            output_pr: dict = JSONOutputFormatter.pr_to_dict(pr)
            output_pr["forward_ported"] = forward_porting_status(
                self.new_slices_by_pr.get(pr, frozenset()),
                comparisons_by_future_release,
            )
            output_pr["label"] = pr.label
            output_pr["forward_ports"] = {}
            if self.add_extra_info:
                output_pr["comparisons"] = {}
                output_pr["discontinued"] = {}
                for i, (future_release, comparisons) in enumerate(comparisons_by_future_release.items()):
                    comparison = next(iter(comparisons))
                    discontinued_slices = sorted(comparison.discontinued_slices)
                    output_pr["discontinued"]["ubuntu-" + future_release.version] = discontinued_slices
                    if i == 0:
                        output_pr["slices"] = sorted(comparison.slices)

            for future_release, comparisons in comparisons_by_future_release.items():
                forward_ports = [c for c in comparisons if not c.missing_slices()]
                forward_port_numbers = sorted([c.pr_future.number for c in forward_ports])
                output_pr["forward_ports"]["ubuntu-" + future_release.version] = forward_port_numbers
                if self.add_extra_info:
                    # Add only the interesting comparisons -- those with some overlap or missing slices
                    cmp = []
                    for c in comparisons:
                        missing = c.missing_slices()
                        overlap = c.overlap()
                        if not missing and not overlap:
                            # no slices missing. this happens when the PR has no new slices, or when
                            # all missing slices were discontinued
                            continue
                        if not c.is_forward_ported() and not overlap:
                            # not an interesting comparison
                            continue
                        element: dict = {"number": c.pr_future.number}
                        if overlap:
                            element["overlap"] = sorted(overlap)
                            if missing:
                                element["missing"] = sorted(missing)
                        cmp.append(element)
                    cmp = sorted(cmp, key=lambda r: r["number"])  # type: ignore
                    output_pr["comparisons"]["ubuntu-" + future_release.version] = cmp

            output.append(output_pr)
        return json.dumps(output, indent=2)


class TextOutputFormatter:
    def __init__(
        self,
        grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
        new_slices_by_pr: Mapping[PR, frozenset[str]],
    ) -> None:
        self.grouped_comparisons = grouped_comparisons
        self.new_slices_by_pr = new_slices_by_pr

    def format(self) -> str:
        rows: list[str] = []
        for pr, comparisons_by_future_release in sorted(self.grouped_comparisons.items()):
            forward_ported = forward_porting_status(
                self.new_slices_by_pr.get(pr, frozenset()),
                comparisons_by_future_release,
            )
            title = pr.title.replace("\n", "_").replace(" ", "_")
            title = "".join(c if 32 <= ord(c) <= 126 else "?" for c in title)
            if len(title) > 40:
                title = title[:37] + "..."
            user = pr.user.replace("\n", "_").replace(" ", "_")
            if len(user) > 15:
                user = user[:12] + "..."
            fp_numbers = [
                c.pr_future.number
                for comparisons in comparisons_by_future_release.values()
                for c in comparisons
                if c.is_forward_ported()
            ]
            fp_numbers_str = ",".join(str(n) for n in sorted(fp_numbers))
            if not fp_numbers_str:
                fp_numbers_str = "-1"
            rows.append(
                f"{pr.number:<4}  {int(forward_ported)}  {int(pr.label):<1}  "
                f"{pr.base.ref:<13}  {user:<15}  {title:<40}  {fp_numbers_str}"
            )

        return "\n".join(rows)


## BOILERPLATE #################################################################


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check labels on PRs and forward-port if needed.",
        epilog="Example: ./forward-port-missing.py --log-level debug",
    )
    parser.add_argument(
        "input",
        type=str,
        help="Path to the input data file. Extension determines the format. .pickle or .pickle.gz are supported.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument(
        "--log-level",
        type=str,
        default="info",
        choices=["debug", "info", "warning", "error", "fatal", "critical"],
        help="Set the logging level (default: info).",
    )
    parser.add_argument(
        "--format",
        "-f",
        type=str,
        default="text",
        choices=["text", "json"],
        help="Output format. One of 'text' or 'json'. Default is 'text'.",
    )

    args = parser.parse_args()

    args.input = Path(args.input).absolute()
    suffix = "".join(args.input.suffixes)
    if suffix not in (".pickle", ".pickle.gz"):
        parser.error("Input file must have .pickle or .pickle.gz extension.")
    # args.input_format = suffix.lstrip(".")

    return args


def setup_logging(log_level: str) -> None:
    _logger = logging.getLogger()
    handler = logging.StreamHandler()
    fmt = "%(asctime)s %(levelname)s %(message)s"
    datefmt = "%Y-%m-%dT%H:%M:%S"
    formatter: type[logging.Formatter] = logging.Formatter
    # Try to use colorlog for colored output
    try:
        import colorlog  # type: ignore

        fmt = fmt.replace("%(levelname)s", "%(log_color)s%(levelname)s%(reset)s")
        formatter = colorlog.ColoredFormatter  # type: ignore
    except ImportError:
        pass

    handler.setFormatter(formatter(fmt, datefmt))  # type: ignore
    _logger.addHandler(handler)
    log_level = "critical" if log_level.lower() == "fatal" else log_level
    _logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))


## ENTRYPOINT ##################################################################

if __name__ == "__main__":
    args = parse_args()
    setup_logging(args.log_level)
    logging.debug("Parsed args: %s", args)

    try:
        main(args)

    except NotImplementedError as e:
        logging.error("Not implemented: %s", e)
        sys.exit(99)

    except Exception as e:
        e_str = str(e)
        e_str = e_str or "An unknown error occurred."
        logging.critical(e_str, exc_info=True)
        sys.exit(1)
