#!/usr/bin/env python3
from __future__ import annotations

import argparse
import gzip
import io
import json
import logging
import os
import re
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from itertools import product
from typing import Literal

import requests

import _common
from _common import (
    CHISEL_RELEASES_URL,
    PR,
    Commit,
    UbuntuRelease,
    check_github_token,
    init_distro_info,
    print_pipe_friendly,
    timing_context,
)


def _get_merge_base(base: Commit, head: Commit) -> str:
    """Get the SHA of the merge base between head and base."""
    url = (
        f"https://api.github.com/repos/{base.repo_owner}/{base.repo_name}/compare/"
        f"{base.repo_owner}:{base.ref}...{head.repo_owner}:{head.ref}?per_page=1"
    )
    response = _geturl_github(url)
    parsed_result = response.json()
    assert isinstance(parsed_result, dict), "Expected response to be a dict."
    if "merge_base_commit" not in parsed_result:
        raise Exception(f"Could not find merge_base_commit in response from '{url}'.")
    merge_base_commit = parsed_result["merge_base_commit"]
    assert isinstance(merge_base_commit, dict), "Expected merge_base_commit to be a dict."
    if "sha" not in merge_base_commit:
        raise Exception(f"Could not find sha in merge_base_commit from '{url}'.")
    sha = merge_base_commit["sha"]
    assert isinstance(sha, str), "Expected sha to be a str."
    return sha


def _geturl_github(url: str, params: dict[str, str | int] | None = None) -> requests.Response:
    assert "github.com" in url, "Only GitHub URLs are supported."
    url = url.replace("github.com", "api.github.com/repos") if "api.github.com" not in url else url
    url = url.rstrip("/")
    headers = {"Accept": "application/vnd.github.v3+json", "X-GitHub-Api-Version": "2022-11-28"}
    github_token = os.getenv("GITHUB_TOKEN", None)
    if github_token:
        headers["Authorization"] = f"Bearer {github_token}"

    response = requests.get(url, params=params, headers=headers)

    if response.status_code == 404:
        raise Exception(f"Resource not found at '{url}'.")
    elif response.status_code == 403:
        raise Exception(f"Rate limit exceeded for '{url}'. Are you using the GITHUB_TOKEN?")
    elif response.status_code == 401:
        raise Exception(f"Unauthorized access to '{url}'. Maybe bad credentials? Check GITHUB_TOKEN.")
    elif response.status_code != 200:
        raise Exception(f"Failed to fetch '{url}'. HTTP status code: {response.status_code}")

    return response


def _ubuntu_branches_in_chisel_releases() -> set[UbuntuRelease]:
    response = _geturl_github(f"{CHISEL_RELEASES_URL}/branches", params={"per_page": 100})
    parsed_result = response.json()
    assert isinstance(parsed_result, list), "Expected response to be a list of branches."
    branches = {branch["name"] for branch in parsed_result if branch["name"].startswith("ubuntu-")}
    return {UbuntuRelease.from_branch_name(branch) for branch in branches}


def _get_all_prs(url: str, per_page: int = 100) -> set[PR]:
    """Fetch all PRs from the remote repository using the GitHub API. The url
    should be the URL of the repository, e.g. www.github.com/canonical/chisel-releases.
    """
    assert per_page > 0, "per_page must be a positive integer."
    url = url.rstrip("/") + "/pulls"

    params: dict[str, str | int] = {"state": "open", "per_page": per_page, "page": 1}

    results = []
    while True:
        response = _geturl_github(url, params=params)
        parsed_result = response.json()
        assert isinstance(parsed_result, list), "Expected response to be a list of PRs."
        results.extend(parsed_result)
        if len(parsed_result) < per_page:
            break
        params["page"] += 1  # type: ignore

    # filter down to PRs into branches named "ubuntu-XX.XX"
    results = [pr for pr in results if pr["base"]["ref"].startswith("ubuntu-")]
    # filter out draft PRs
    results = [pr for pr in results if not pr.get("draft", False)]

    return set(PR.from_github_json(pr) for pr in results)


################################################################################


def _get_slices(repo_owner: str, repo_name: str, ref: str) -> set[str]:
    """Get the list of files in the /slices directory in the given ref.
    ref can be a branch name, tag name, or commit SHA.
    """

    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/contents/slices"
    response = _geturl_github(url, params={"ref": ref})
    parsed_result = response.json()
    assert isinstance(parsed_result, list), "Expected response to be a list of files."

    files = {item["name"] for item in parsed_result if item["type"] == "file"}
    files = {f.removesuffix(".yaml") for f in files if f.endswith(".yaml")}
    return files


def _get_merge_bases_by_pr(prs: set[PR], jobs: int | None = 1) -> dict[PR, str]:
    logging.info("Fetching merge bases for %d PRs...", len(prs))
    merge_bases_by_pr: dict[PR, str] = {}

    with timing_context() as elapsed:
        if jobs == 1:
            # NOTE: it is much nicer to debug/profile without parallelism
            merge_bases_by_pr = {pr: _get_merge_base(pr.base, pr.head) for pr in prs}
        else:
            _prs = list(prs)  # we want list for zipping with results
            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results = list(executor.map(lambda pr: _get_merge_base(pr.base, pr.head), _prs))
            merge_bases_by_pr = {pr: mb for pr, mb in zip(_prs, results)}

    logging.info("Fetched merge bases for %d PRs in %.2f seconds.", len(prs), elapsed())
    for pr, mb in merge_bases_by_pr.items():
        if pr.base.sha != mb:
            logging.warning(
                "PR #%d: base branch '%s' has advanced since the PR was created/updated. Consider rebasing.",
                pr.number,
                pr.base.ref,
            )

    return merge_bases_by_pr


def _get_slices_by_pr(
    prs: set[PR],
    merge_bases_by_pr: dict[PR, str],
    jobs: int | None = 1,
) -> tuple[dict[PR, set[str]], dict[PR, set[str]]]:
    logging.info("Fetching slices for %d PRs...", len(prs))
    # For each PR, get the list of files in the /slices directory in the base branch
    slices_in_head_by_pr: dict[PR, set[str]]
    slices_in_base_by_pr: dict[PR, set[str]]

    def get_slices_base(pr: PR) -> set[str]:
        return _get_slices(pr.base.repo_owner, pr.base.repo_name, merge_bases_by_pr[pr])

    def get_slices_head(pr: PR) -> set[str]:
        return _get_slices(pr.head.repo_owner, pr.head.repo_name, pr.head.ref)

    with timing_context() as elapsed:
        if jobs == 1:
            # NOTE: it is much nicer to debug/profile without parallelism
            slices_in_head_by_pr = {pr: get_slices_head(pr) for pr in prs}
            slices_in_base_by_pr = {pr: get_slices_base(pr) for pr in prs}

        else:
            _prs = list(prs)  # we want list for zipping with results
            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results_head = list(executor.map(get_slices_head, _prs))
                results_base = list(executor.map(get_slices_base, _prs))

            slices_in_head_by_pr = {pr: slices for pr, slices in zip(_prs, results_head)}
            slices_in_base_by_pr = {pr: slices for pr, slices in zip(_prs, results_base)}

    total_slices = sum(len(slices) for slices in slices_in_head_by_pr.values())
    total_slices += sum(len(slices) for slices in slices_in_base_by_pr.values())
    logging.info("Fetched %d slices for %d PRs in %.2f seconds.", total_slices, len(prs), elapsed())

    return slices_in_head_by_pr, slices_in_base_by_pr


def _get_packages_by_release(
    releases: list[UbuntuRelease],
    jobs: int | None = 1,
) -> dict[UbuntuRelease, set[str]]:
    logging.info("Fetching packages for %d releases...", len(releases))
    package_listings: dict[tuple[UbuntuRelease, str, str], set[str]] = {}

    _components = ("main", "restricted", "universe", "multiverse")
    _repos = ("", "security", "updates", "backports")
    _product = list(product(releases, _components, _repos))

    with timing_context() as elapsed:
        if jobs == 1:
            for release, component, repo in _product:
                package_listings[(release, component, repo)] = _get_package_list(release, component, repo)

        else:
            with ThreadPoolExecutor(max_workers=jobs) as executor:
                logging.debug("Using a thread pool of size %d.", getattr(executor, "_max_workers", -1))
                results = list(
                    executor.map(lambda args: _get_package_list(*args), _product)  # type: ignore
                )
            package_listings = {args: pkgs for args, pkgs in zip(_product, results)}

    logging.info("Fetched packages for %d releases in %.2f seconds.", len(releases), elapsed())

    # Union all components and repos
    packages_by_release: dict[UbuntuRelease, set[str]] = {r: set() for r in releases}
    for (release, _component, _repo), packages in package_listings.items():
        packages_by_release[release].update(packages)

    return packages_by_release


_PACKAGE_RE = re.compile(r"^Package:\s*(\S+)", re.MULTILINE)


def _get_package_list(
    release: UbuntuRelease,
    component: Literal["main", "restricted", "universe", "multiverse"],
    repo: Literal["", "security", "updates", "backports"],
) -> set[str]:
    name = f"{release.short_codename}-{repo}" if repo else release.short_codename

    package_url = f"https://archive.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"
    headers = {
        "User-Agent": "forward-port-missing-script",
        "Referer": f"https://archive.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64",
    }
    response = requests.get(package_url, headers=headers)

    if response.status_code != 200:
        # retry with old-releases if not found in archive
        package_url = f"https://old-releases.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64/Packages.gz"
        headers["Referer"] = f"https://old-releases.ubuntu.com/ubuntu/dists/{name}/{component}/binary-amd64"
        response = requests.get(package_url, headers=headers)

    if response.status_code != 200:
        raise Exception(
            f"Failed to download package list from '{package_url}'. HTTP status code: {response.status_code}"
        )

    with gzip.GzipFile(fileobj=io.BytesIO(response.content)) as f:
        content = f.read().decode("utf-8")

    return set(m.group(1) for m in _PACKAGE_RE.finditer(content))


def _group_prs_by_ubuntu_release(prs: set[PR], ubuntu_releases: list[UbuntuRelease]) -> dict[UbuntuRelease, set[PR]]:
    _prs_by_ubuntu_release: dict[UbuntuRelease, set[PR]] = {ubuntu_release: set() for ubuntu_release in ubuntu_releases}
    _prs = list(sorted(prs))  # we want list for logging
    for pr in _prs:
        if pr.ubuntu_release not in _prs_by_ubuntu_release:
            logging.warning("PR #%d is into unsupported Ubuntu release %s. Skipping.", pr.number, pr.ubuntu_release)
            continue
        _prs_by_ubuntu_release[pr.ubuntu_release].add(pr)
    prs_by_ubuntu_release: dict[UbuntuRelease, set[PR]] = {k: set(v) for k, v in _prs_by_ubuntu_release.items()}

    # Make sure we have all the ubuntu_releases as keys, even if they have no PRs
    for ubuntu_release in ubuntu_releases:
        if ubuntu_release not in prs_by_ubuntu_release:
            prs_by_ubuntu_release[ubuntu_release] = set()

    return prs_by_ubuntu_release


## MAIN ########################################################################


def main(args: argparse.Namespace) -> None:
    ubuntu_releases = sorted(_common.SUPPORTED_RELEASES)
    ubuntu_branches = _ubuntu_branches_in_chisel_releases()

    # filter to only releases with branches in chisel-releases
    ubuntu_releases = [r for r in ubuntu_releases if r in ubuntu_branches]

    logging.info(
        "Considering %d supported Ubuntu releases with branches in chisel-releases: %s",
        len(ubuntu_releases),
        ", ".join(str(r) for r in ubuntu_releases),
    )

    prs = _get_all_prs(CHISEL_RELEASES_URL)
    logging.info("Found %d open PRs in %s", len(prs), CHISEL_RELEASES_URL)

    merge_bases_by_pr = _get_merge_bases_by_pr(prs, args.jobs)
    slices_in_head_by_pr, slices_in_base_by_pr = _get_slices_by_pr(prs, merge_bases_by_pr, args.jobs)
    packages_by_release = _get_packages_by_release(ubuntu_releases, args.jobs)

    if logging.getLogger().isEnabledFor(logging.INFO):
        prs_by_ubuntu_release = _group_prs_by_ubuntu_release(prs, ubuntu_releases)
        for ubuntu_release, prs_in_release in prs_by_ubuntu_release.items():
            logging.info("Found %d open PRs into %s", len(prs_in_release), ubuntu_release)
            for pr in prs_in_release:
                logging.info(
                    "  #%d: %s (%d slices in head, %d slices in merge base)",
                    pr.number,
                    pr.title,
                    len(slices_in_head_by_pr.get(pr, set())),
                    len(slices_in_base_by_pr.get(pr, set())),
                )

    output_data = {
        "ubuntu_releases": [asdict(r) for r in ubuntu_releases],
        "prs": [
            {
                **asdict(pr),
                "ubuntu_release": asdict(pr.ubuntu_release),
                "slices": {
                    "head": sorted(slices_in_head_by_pr.get(pr, set())),
                    "base": sorted(slices_in_base_by_pr.get(pr, set())),
                },
            }
            for pr in sorted(prs)
        ],
        "packages_by_release": {f"ubuntu-{r.version}": sorted(pkgs) for r, pkgs in packages_by_release.items()},
    }

    print_pipe_friendly(json.dumps(output_data))


## BOILERPLATE #################################################################


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch data about open PRs in chisel-releases and write it to a JSON file."
    )
    parser.add_argument(
        "--jobs",
        "-j",
        type=int,
        default=1,  # -1 = as many as possible, 1 = no parallelism
        help="Number of parallel jobs to use when fetching PR details. Default is 1 (no parallelism).",
    )

    args = parser.parse_args()
    if args.jobs == 0 or args.jobs < -1:
        parser.error("--jobs must be a positive integer or -1 for unlimited.")
    args.jobs = None if args.jobs == -1 else args.jobs  # None = as many as possible
    return args


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
