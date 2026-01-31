#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import logging
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from pathlib import Path

from _common import (
    PR,
    UbuntuRelease,
    check_github_token,
    init_distro_info,
    print_pipe_friendly,
)

################################################################################


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
            continue

        for pr in prs_in_release:
            new_slices = new_slices_by_pr.get(pr, frozenset())
            for future_release in future_releases:
                prs_into_future_release = prs_by_ubuntu_release.get(future_release, frozenset())
                if not prs_into_future_release:
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
    for _pr, results_by_future in grouped_comparisons.items():
        for future_release, comparisons in results_by_future.items():
            packages = packages_by_release.get(future_release, set())
            if not packages:
                continue
            _comparison = next(iter(comparisons), None)
            if not _comparison:
                continue
            discontinued_slices = _comparison.slices - packages
            if not discontinued_slices:
                continue

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


def load_data_from_json(
    input_path: Path,
) -> tuple[
    frozenset[PR],
    Mapping[PR, frozenset[str]],
    Mapping[PR, frozenset[str]],
    Mapping[UbuntuRelease, set[str]],
]:
    """Load PR and package data from JSON file."""
    if not input_path.is_file():
        raise FileNotFoundError(f"Input file '{input_path}' does not exist or is not a file.")

    logging.info("Loading data from '%s'...", input_path)

    with input_path.open("r") as f:
        data = json.load(f)

    assert isinstance(data, dict), "Expected loaded data to be a dict."
    expected_keys = {"ubuntu_releases", "prs", "packages_by_release"}
    if set(data.keys()) != expected_keys:
        raise ValueError(f"Loaded data keys do not match expected keys: {expected_keys}")

    # Reconstruct PRs
    prs_list = []
    slices_in_head_by_pr_dict = {}
    slices_in_base_by_pr_dict = {}

    for pr_data in data["prs"]:
        pr = PR.from_dict(pr_data)
        prs_list.append(pr)
        slices_in_head_by_pr_dict[pr] = frozenset(pr_data["slices"]["head"])
        slices_in_base_by_pr_dict[pr] = frozenset(pr_data["slices"]["base"])

    # Reconstruct packages by release
    packages_by_release = {}
    for release_key, packages in data["packages_by_release"].items():
        # release_key is like "ubuntu-24.04"
        version = release_key.removeprefix("ubuntu-")
        # Find matching release from ubuntu_releases
        matching_release = next((r for r in data["ubuntu_releases"] if r["version"] == version), None)
        if matching_release:
            ubuntu_release = UbuntuRelease.from_dict(matching_release)
            packages_by_release[ubuntu_release] = set(packages)

    logging.info("Loaded data from '%s'.", input_path)
    file_size = input_path.stat().st_size
    logging.info("Input file size: %.2f MiB", file_size / (1024 * 1024))

    return frozenset(prs_list), slices_in_head_by_pr_dict, slices_in_base_by_pr_dict, packages_by_release


## MAIN ########################################################################


def main(args: argparse.Namespace) -> None:
    (
        prs,
        slices_in_head_by_pr,
        slices_in_base_by_pr,
        packages_by_release,
    ) = load_data_from_json(args.input)
    ubuntu_releases = sorted(packages_by_release.keys())

    prs_by_ubuntu_release = _group_prs_by_ubuntu_release(prs, ubuntu_releases)
    new_slices_by_pr = _group_new_slices_by_pr(slices_in_head_by_pr, slices_in_base_by_pr)
    grouped_comparisons = _get_grouped_comparisons(prs_by_ubuntu_release, new_slices_by_pr)
    _add_discontinued_slices(grouped_comparisons, packages_by_release)

    print_pipe_friendly(format_forward_port_json(grouped_comparisons, new_slices_by_pr, add_extra_info=False))


################################################################################


def format_forward_port_json(
    grouped_comparisons: Mapping[PR, Mapping[UbuntuRelease, frozenset[Comparison]]],
    new_slices_by_pr: Mapping[PR, frozenset[str]],
    add_extra_info: bool = False,
) -> str:
    output = []
    for pr, comparisons_by_future_release in sorted(grouped_comparisons.items()):
        output_pr: dict = {
            "number": pr.number,
            "title": pr.title,
            "url": pr.url,
            "base": pr.base.ref,
            "head": f"{pr.head.repo_owner}/{pr.head.repo_name}/{pr.head.ref}",
        }
        output_pr["forward_ported"] = forward_porting_status(
            new_slices_by_pr.get(pr, frozenset()),
            comparisons_by_future_release,
        )
        output_pr["label"] = pr.label
        output_pr["forward_ports"] = {}
        if add_extra_info:
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
            if add_extra_info:
                cmp = []
                for c in comparisons:
                    missing = c.missing_slices()
                    overlap = c.overlap()
                    if not missing and not overlap:
                        continue
                    if not c.is_forward_ported() and not overlap:
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
    return json.dumps(output)


## BOILERPLATE #################################################################


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check labels on PRs and forward-port if needed.",
    )
    parser.add_argument("input", type=Path, help="Path to the input json data file")
    return parser.parse_args()


## ENTRYPOINT ##################################################################

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    init_distro_info()
    check_github_token()

    args = parse_args()
    logging.debug("Parsed args: %s", args)

    main(args)
