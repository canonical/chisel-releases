#!/usr/bin/env python3
"""
Script to determine which PRs in [chisel-releases](https://github.com/canonical/chisel-releases) are
missing forward ports to future releases, and therefore which PRs should be labeled with "forward port missing"
(and which should have that label removed).

The script checks out chisel-releases to determine which releases are supported, and what slices are currently
present in each release. Then it makes a bunch of calls to the GitHub API to fetch the data about PRs, and what new
slices do they introduce. Finally, to determine the PR status, for each PR we check whether the slices introduced
by that particular PR are either already present in the future release, or are being introduced by another PR.
Any slices for any discontinued packages are ignored.
"""

from __future__ import annotations

from pathlib import Path

import argparse
import tempfile
import datetime
import gzip
import io
import logging
import os
import re
from concurrent.futures import ThreadPoolExecutor
from itertools import product
import subprocess as sub
from dataclasses import dataclass
from contextlib import contextmanager
import time
from typing import Iterator, Callable

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import yaml

# For dev you can use requests-cache to cache the
# GitHub API responses and avoid hitting rate limits:
# import requests_cache
# requests_cache.install_cache("requests_cache")

FORWARD_PORT_MISSING_LABEL = "forward port missing"

# retry rate limits and transient server errors, honouring Retry-After
GITHUB_API_RETRY = Retry(
    total=5,
    backoff_factor=2,
    status_forcelist=(429, 500, 502, 503, 504),
    allowed_methods=("GET",),
)

COLORED_LOGGING: dict[str, str] = {
    "yellow": "\033[33m",
    "green": "\033[32m",
    "reset": "\033[0m",
}


def warn(msg: str) -> None:
    logging.warning("%s%s%s", COLORED_LOGGING["yellow"], msg, COLORED_LOGGING["reset"])


def info(msg: str) -> None:
    logging.info("%s%s%s", COLORED_LOGGING["green"], msg, COLORED_LOGGING["reset"])


@contextmanager
def timing_context() -> Iterator[Callable[[], float]]:
    """Time the execution of a block of code"""
    t1 = t2 = time.perf_counter()
    yield lambda: t2 - t1
    t2 = time.perf_counter()


@dataclass(frozen=True)
class PR:
    number: int
    labels: frozenset[str]
    new_slices: frozenset[str]
    branch: str  # e.g. "ubuntu-22.04"

    @classmethod
    def from_github_json(cls, data: dict) -> PR:
        return PR(
            number=data["number"],
            labels=frozenset(label["name"] for label in data.get("labels", [])),
            new_slices=frozenset(data.get("new_slices", [])),
            branch=data["base"]["ref"],
        )


def fetch_prs(supported_branches: set[str] | None = None) -> set[PR]:
    """Fetch the list of open PRs into 'ubuntu-XX.XX' branches in chisel-releases which correspond to
    the supported Ubuntu releases. For each PR determine the set of new slices it introduces"""
    url = "https://api.github.com/repos/canonical/chisel-releases/pulls"
    headers: dict[str, str] = {
        "Accept": "application/vnd.github.v3+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    github_token = os.getenv("GITHUB_TOKEN")
    if github_token:
        headers["Authorization"] = f"Bearer {github_token}"

    per_page = 100
    params: dict[str, str | int] = {"state": "open", "per_page": per_page, "page": 1}

    results: list[dict] = []
    with requests.Session() as s:
        s.mount("https://", HTTPAdapter(max_retries=GITHUB_API_RETRY))
        while True:
            response = s.get(url, params=params, headers=headers)
            response.raise_for_status()
            parsed_result = response.json()
            assert isinstance(parsed_result, list), (
                "Expected response to be a list of PRs."
            )
            results.extend(parsed_result)
            if len(parsed_result) < per_page:
                break
            params["page"] += 1  # type: ignore[operator]

    # filter down to PRs into branches named "ubuntu-XX.XX"
    _results: Iterator[dict] = (
        pr for pr in results if pr["base"]["ref"].startswith("ubuntu-")
    )

    # filter out draft PRs
    _results = (pr for pr in _results if not pr.get("draft", False))

    # filter down to PRs into supported branches if specified
    if supported_branches is not None:
        _results = (pr for pr in _results if pr["base"]["ref"] in supported_branches)

    # run the generator
    results = list(_results)

    # fetch the file list of each PR in parallel and collect the slice definition files it adds

    def _fetch_new_slices(pr: dict) -> tuple[int, list[str]]:
        """Return the PR number and the names of the slice definition files the PR adds."""
        files: list[dict] = []
        params: dict[str, int] = {"per_page": per_page, "page": 1}
        with requests.Session() as s:
            s.mount("https://", HTTPAdapter(max_retries=GITHUB_API_RETRY))
            while True:
                response = s.get(f"{url}/{pr['number']}/files", params=params, headers=headers)
                # no skipping on failure: a PR left out takes its slices out of the union
                # the other PRs are checked against, and they would get mislabelled
                response.raise_for_status()
                page = response.json()
                files.extend(page)
                if len(page) < per_page:
                    break
                params["page"] += 1

        new_slices = {
            Path(f["filename"]).stem
            for f in files
            if f["status"] == "added"
            and Path(f["filename"]).parent.name == "slices"
            and Path(f["filename"]).suffix == ".yaml"
        }
        return pr["number"], sorted(new_slices)

    with timing_context() as elapsed:
        with ThreadPoolExecutor(max_workers=5) as executor:
            new_slices_per_pr = dict(executor.map(_fetch_new_slices, results))

    info(f"Fetched the files of {len(results)} PRs in {elapsed():.2f} seconds.")

    for result in results:
        result["new_slices"] = new_slices_per_pr[result["number"]]

    return set(PR.from_github_json(r) for r in results if r.get("new_slices"))


# precompile regex to extract package names from the package listing
_PACKAGE_RE = re.compile(r"^Package:\s*(\S+)", re.MULTILINE)


def fetch_packages_in_release(
    codenames: dict[str, str],  # ubuntu-XX.XX -> short codename (e.g. jammy)
) -> dict[str, set[str]]:
    """Fetch the list of packages in each supported Ubuntu release by scraping the
    package lists from the Ubuntu archive. The releases are in the format 'ubuntu-XX.XX',
    but the archive uses the short codename (e.g. 'jammy') so we need the
    map from short codename to version to construct the correct URLs."""

    info(f"Fetching packages for {len(codenames)} releases...")

    def _fetch_packages(args: tuple[str, str, str]) -> tuple[str, set[str]]:
        """Fetch the list of packages for a given release, component, and repo"""
        short_codename, component, repo = args
        name = f"{short_codename}-{repo}" if repo else short_codename

        url = f"https://archive.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"

        with requests.Session() as s:
            response = s.get(url)
            response.raise_for_status()

        with gzip.GzipFile(fileobj=io.BytesIO(response.content)) as f:
            content = f.read().decode("utf-8")

        return (
            short_codename,
            set(m.group(1) for m in _PACKAGE_RE.finditer(content)),
        )

    # TODO: get these from chisel.yaml instead of hardcoding
    _components = ("main", "restricted", "universe", "multiverse")
    _repos = ("", "security", "updates", "backports")

    _product = list(product(codenames.values(), _components, _repos))
    with timing_context() as elapsed:
        with ThreadPoolExecutor(max_workers=5) as executor:
            results: list[tuple[str, set[str]]] = list(
                executor.map(_fetch_packages, _product)
            )

    info(f"Fetched packages for {len(codenames)} releases in {elapsed():.2f} seconds.")

    # Union all components and repos for each release
    packages_by_release: dict[str, set[str]] = {
        release: set() for release in codenames.keys()
    }
    _codenames = {short: release for release, short in codenames.items()}
    for short_codename, packages in results:
        packages_by_release[_codenames[short_codename]].update(packages)

    return packages_by_release


def checkout_chisel_releases_info(
    url: str = "https://github.com/canonical/chisel-releases",
) -> tuple[dict[str, set[str]], dict[str, str]]:
    """Checkout chisel-releases and get the list of branches named "ubuntu-XX.XX"
    to determine which Ubuntu releases we should consider. For each release branch,
    parse the chisel.yaml to determine the short codename (e.g. "jammy"), and get
    the list of slices currently present in that release."""

    slices_per_branch: dict[str, set[str]] = {}
    codenames: dict[str, str] = {}
    with tempfile.TemporaryDirectory(prefix="chisel-releases-clone-") as _tmpdir:
        tmpdir = Path(_tmpdir)
        sub.run(
            ["git", "clone", url, tmpdir],
            check=True,
        )
        out: list[str] = sub.run(
            ["git", "branch", "--remote", "--format='%(refname:short)'"],
            cwd=tmpdir,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        out = [b.strip().strip("'") for b in out]
        out = [b.removeprefix("origin/") for b in out]
        branches = set(b for b in out if b.startswith("ubuntu-"))
        if not branches:
            raise Exception("No ubuntu branches in chisel-releases")

        # get slice names for each supported release branch
        for branch in branches:
            _ = sub.run(
                ["git", "checkout", branch],
                cwd=tmpdir,
                check=True,
                capture_output=True,
                text=True,
            )
            chisel_yaml: dict = yaml.safe_load((tmpdir / "chisel.yaml").read_text())
            end_of_life: datetime.date = chisel_yaml.get("maintenance", {}).get(
                "end-of-life"
            )
            if not end_of_life:
                continue
            if end_of_life < datetime.date.today():
                continue

            # Parse the short codename from the "archives" field in chisel.yaml.
            # This is needed to quarry the archive
            archives: list[str] = (
                chisel_yaml.get("archives", {}).get("ubuntu", {}).get("suites", [])
            )
            _codenames: set[str] = set(a.split("-")[0] for a in archives)
            if len(_codenames) != 1:
                warn(
                    f"could not parser short codename from chisel.yaml in '{branch}': {archives}"
                )
                continue

            slices_per_branch[branch] = set(
                sdf.stem for sdf in (tmpdir / "slices").glob("*.yaml")
            )
            codenames[branch] = _codenames.pop()

    _branches = sorted(
        map(lambda b: b.removeprefix("ubuntu-"), slices_per_branch.keys())
    )
    info(f"Found {len(slices_per_branch)} branches: {', '.join(_branches)}")

    return (
        dict(sorted(slices_per_branch.items(), key=lambda x: x[0])),
        dict(sorted(codenames.items(), key=lambda x: x[0])),
    )


def determine_forward_porting_status(
    *,
    prs: set[PR],
    slices_per_branch: dict[str, set[str]],
    packages_by_release: dict[str, set[str]] | None = None,
) -> tuple[set[int], set[int]]:
    """Determine forward porting status of each PR. A PR is considered to be forward ported if all the slices it
    introduces are either already present in each of the future releases, or there exist PRs which introduce these
    slices into the future releases. We ignore any missing slices which correspond to packages which are
    not present in the future release."""

    union_slices_per_branch: dict[str, set[str]] = {
        branch: set(slices) for branch, slices in slices_per_branch.items()
    }
    for pr in prs:
        union_slices_per_branch[pr.branch].update(pr.new_slices)

    to_add_label: set[int] = set()
    to_remove_label: set[int] = set()
    for pr in prs:
        fp_missing = False
        for future_branch in filter(lambda b: b > pr.branch, slices_per_branch.keys()):
            missing_slices = pr.new_slices - union_slices_per_branch[future_branch]
            if packages_by_release is not None:
                missing_slices = missing_slices.intersection(
                    packages_by_release[future_branch]
                )
            if missing_slices:
                info(
                    f"#{pr.number}: no fp to '{future_branch.removeprefix('ubuntu-')}': {', '.join(sorted(missing_slices))}"
                )
                if FORWARD_PORT_MISSING_LABEL not in pr.labels:
                    warn(
                        f"#{pr.number}: no fp to '{future_branch.removeprefix('ubuntu-')}': no label"
                    )
                    to_add_label.add(pr.number)

                fp_missing = True

        if not fp_missing:
            if FORWARD_PORT_MISSING_LABEL in pr.labels:
                warn(f"#{pr.number}: has fp but has label")
                to_remove_label.add(pr.number)

    assert to_add_label.isdisjoint(to_remove_label), "PR cannot be in both sets"

    return to_add_label, to_remove_label


def apply_labels(to_add: set[int], to_remove: set[int]) -> None:
    """Apply or remove the 'forward port missing' label on PRs using the gh CLI."""
    label = FORWARD_PORT_MISSING_LABEL
    for number in sorted(to_add):
        info(f"Adding label to PR #{number}")
        result = sub.run(
            ["gh", "pr", "edit", str(number), "--add-label", label],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            logging.error(
                "Failed to add label to PR #%d: %s", number, result.stderr.strip()
            )

    for number in sorted(to_remove):
        info(f"Removing label from PR #{number}")
        result = sub.run(
            ["gh", "pr", "edit", str(number), "--remove-label", label],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            logging.error(
                "Failed to remove label from PR #%d: %s", number, result.stderr.strip()
            )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply label changes to PRs using the gh CLI. Without this flag, only prints the results.",
    )
    args = parser.parse_args()

    slices_per_branch, codenames = checkout_chisel_releases_info()
    prs = fetch_prs(set(slices_per_branch.keys()))
    packages_by_release = fetch_packages_in_release(codenames)

    to_add_label, to_remove_label = determine_forward_porting_status(
        prs=prs,
        slices_per_branch=slices_per_branch,
        packages_by_release=packages_by_release,
    )

    print("add:", ",".join(map(str, sorted(to_add_label))))
    print("remove:", ",".join(map(str, sorted(to_remove_label))))

    if args.apply:
        apply_labels(to_add_label, to_remove_label)


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    main()
