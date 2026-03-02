#!/usr/bin/env python3
"""
Script to determine which PRs in [chisel-releases](https://github.com/canonical/chisel-releases) are
missing forward ports to future releases, and therefore which PRs should be labeled with "forward port missing"
(and which should have that label removed).

The script checks out chisel-releases to determine which releases are supported, and what slices are currently
present in each release. The it makes a bunch of calls to github api to fetch the data about PRs, and what new
slices do they introduce. Finally, to determine the PR status, for each PR we check whether the slices introduced
by that particular PR are either already present in the future release, or are being introduced by another PR.
Any slices for any discontinued packages are ignored.
"""

from __future__ import annotations
from functools import partial

from pathlib import Path

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
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from contextlib import contextmanager
import time
from typing import Iterator, Callable

from diff_parser import Diff
import requests
import yaml

# For dev you can use requests-cache to cache the
# GitHub API responses and avoid hitting rate limits:

import requests_cache

requests_cache.install_cache("requests_cache")

FORWARD_PORT_MISSING_LABEL = "forward port missing"

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
            labels=frozenset(label.get("name") for label in data["labels"]),
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
    results = [pr for pr in results if pr["base"]["ref"].startswith("ubuntu-")]

    # filter out draft PRs
    results = [pr for pr in results if not pr.get("draft", False)]

    # filter down to PRs into supported branches if specified
    if supported_branches is not None:
        results = [pr for pr in results if pr["base"]["ref"] in supported_branches]

    # fetch the diff for each PR in parallel and determine which slices they are modifying (i.e. which files in the /slices directory they are adding/modifying)

    def _fetch_diff(s: requests.Session, pr: dict) -> tuple[int, Diff]:
        """Fetch a PR's diff and return the PR number and the parsed Diff object."""
        response = s.get(pr["diff_url"])
        response.raise_for_status()
        diff_text = response.text
        pr_number = pr["number"]
        if "<h1>Too many requests</h1>" in diff_text:
            warn(
                f"Rate limit exceeded when fetching diff for PR #{pr_number}. Skipping."
            )
            sys.exit(1)
        return pr_number, Diff(diff_text)

    with timing_context() as elapsed:
        with requests.Session() as s, ThreadPoolExecutor(max_workers=5) as executor:
            _diffs = list(executor.map(partial(_fetch_diff, s), results))
    diffs: dict[int, Diff] = dict(_diffs)

    info(f"Fetched diffs for {len(results)} PRs in {elapsed():.2f} seconds.")

    # for each PR patch in a field "new_slices" based on the fetched diff
    for result in results:
        diff = diffs.get(result["number"])
        if not diff:
            warn(f"Could not fetch diff for PR #{result['number']}. Skipping.")
            continue

        new_slices: set[str] = set()
        for block in diff:
            if block.type == "new":
                new_filepath = Path(block.new_filepath)
                if (
                    new_filepath.parent.name == "slices"
                    and new_filepath.suffix == ".yaml"
                ):
                    new_slices.add(new_filepath.stem)
        result["new_slices"] = sorted(new_slices)

    return set(PR.from_github_json(result) for result in results)


class DistsHTMLParser(HTMLParser):
    """HTML parser to extract the list of distributions from the Ubuntu archive page."""

    def __init__(self) -> None:
        super().__init__()
        self.dists: set[str] = set()

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href", "")
            if href.endswith("/"):
                dist = href.rstrip("/")
                self.dists.add(dist)

    def short_codenames(self) -> set[str]:
        """Return the set of short codenames for the Ubuntu releases. Filters
        out devel, and squashes e.g. 'jammy', 'jammy-security', 'jammy-updates'
        into just 'jammy'."""
        dists = self.dists
        return {
            d
            for d in dists
            if d
            and not d.startswith("/")
            and not d.startswith("devel")
            and "-" not in d
        }


def fetch_codename_mapping() -> dict[str, str]:
    """Fetch the mapping from Ubuntu codename (e.g. "jammy") to version (e.g. "22.04")
    by scraping the release info from the Ubuntu archive."""
    url = "https://archive.ubuntu.com/ubuntu/dists"

    def _parse_version(s: requests.Session, short_codename: str) -> tuple[str, str]:
        url = f"https://archive.ubuntu.com/ubuntu/dists/{short_codename}/Release"
        release_info = s.get(url).text
        for line in release_info.splitlines():
            if line.startswith("Version:"):
                version = line.split(":", 1)[1].strip()
                return short_codename, version
        raise Exception("Could not find version in release info.")

    with requests.Session() as s:
        dists = s.get(url).text
        parser = DistsHTMLParser()
        parser.feed(dists)
        short_codenames = parser.short_codenames()

        with ThreadPoolExecutor(max_workers=5) as executor:
            _codenames: list[tuple[str, str]] = list(
                executor.map(partial(_parse_version, s), short_codenames)
            )
            return dict(_codenames)


# precompile regex to extract package names from the package listing
_PACKAGE_RE = re.compile(r"^Package:\s*(\S+)", re.MULTILINE)


def fetch_packages_in_release(releases: list[str]) -> dict[str, set[str]]:
    """Fetch the list of packages in each supported Ubuntu release by scraping the
    package lists from the Ubuntu archive. The releases are in the format 'ubuntu-XX.XX',
    but the archive uses the short codename (e.g. 'jammy') in the URLs, so we first fetch
    the release info to figure out which short codename corresponds to each release."""

    codenames = {
        short: codename
        for short, codename in fetch_codename_mapping().items()
        if f"ubuntu-{codename}" in releases
    }

    info(f"Fetching packages for {len(codenames)} releases...")

    def _fetch_packages(
        s: requests.Session, args: tuple[str, str, str]
    ) -> tuple[str, str, str, set[str]]:
        """Fetch the list of packages for a given release, component, and repo"""
        short_codename, component, repo = args
        name = f"{short_codename}-{repo}" if repo else short_codename

        url = f"https://archive.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"
        response = s.get(url)
        response.raise_for_status()

        with gzip.GzipFile(fileobj=io.BytesIO(response.content)) as f:
            content = f.read().decode("utf-8")

        return (
            short_codename,
            component,
            repo,
            set(m.group(1) for m in _PACKAGE_RE.finditer(content)),
        )

    _components = ("main", "restricted", "universe", "multiverse")
    _repos = ("", "security", "updates", "backports")
    _product = list(product(codenames.keys(), _components, _repos))
    with timing_context() as elapsed:
        with requests.Session() as s, ThreadPoolExecutor(max_workers=5) as executor:
            results: list[tuple[str, str, str, set[str]]] = list(
                executor.map(partial(_fetch_packages, s), _product)
            )

    info(f"Fetched packages for {len(codenames)} releases in {elapsed():.2f} seconds.")

    # Union all components and repos for each release
    packages_by_release: dict[str, set[str]] = {release: set() for release in releases}
    for short_codename, component, repo, packages in results:
        release = f"ubuntu-{codenames[short_codename]}"
        packages_by_release[release].update(packages)

    return packages_by_release


def checkout_slices_per_branch(
    url: str = "https://github.com/canonical/chisel-releases",
) -> dict[str, set[str]]:
    """Checkout chisel-releases and get the list of branches named "ubuntu-XX.XX"
    to determine which Ubuntu releases we should consider"""

    slices_per_branch: dict[str, set[str]] = {}
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

        _branches = sorted(map(lambda b: b.removeprefix("ubuntu-"), branches))

        # get slice names for each supported release branch
        for branch in branches:
            _ = sub.run(
                ["git", "checkout", branch],
                cwd=tmpdir,
                check=True,
                capture_output=True,
                text=True,
            )
            chisel_yaml_path = tmpdir / "chisel.yaml"
            if not chisel_yaml_path.exists():
                warn(f"no chisel.yaml in '{branch}'")
                continue
            chisel_yaml = yaml.safe_load(chisel_yaml_path.read_text())
            end_of_life: datetime.date = chisel_yaml.get("maintenance", {}).get(
                "end-of-life"
            )
            if not end_of_life:
                continue
            if end_of_life < datetime.date.today():
                continue

            slices_per_branch[branch] = set(
                sdf.stem for sdf in (tmpdir / "slices").glob("*.yaml")
            )

    _branches = sorted(
        map(lambda b: b.removeprefix("ubuntu-"), slices_per_branch.keys())
    )
    info(f"Found {len(slices_per_branch)} branches: {', '.join(_branches)}")

    return dict(sorted(slices_per_branch.items(), key=lambda x: x[0]))


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


def main() -> None:
    slices_per_branch = checkout_slices_per_branch()
    prs = fetch_prs(set(slices_per_branch.keys()))
    packages_by_release = fetch_packages_in_release(list(slices_per_branch.keys()))

    to_add_label, to_remove_label = determine_forward_porting_status(
        prs=prs,
        slices_per_branch=slices_per_branch,
        packages_by_release=packages_by_release,
    )

    print("add:", ",".join(map(str, sorted(to_add_label))))
    print("remove:", ",".join(map(str, sorted(to_remove_label))))


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    main()
