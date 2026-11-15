#!/usr/bin/env python3
"""
Unit tests for triage_prs.py
"""

import os
import sys
from pathlib import Path
from textwrap import dedent
from unittest.mock import MagicMock

import pytest
import yaml

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import triage_prs
from triage_prs import PR, Config, Entry, Request


CONFIG = Config(
    (
        Entry(("canonical/guild",), ("*",)),
        Entry(("alice",), ("openjdk-*-jre-headless", "tomcat*")),
        Entry(("Bob", "carol"), ("systemd",)),
        Entry(("Bob", "canonical/systemd-team"), ("libsystemd0", "systemd")),
    )
)


def make_pr(**kwargs) -> PR:
    defaults = dict(
        number=1,
        author="dave",
        branch="ubuntu-26.10",
        packages=frozenset(),
        seen_users=frozenset(),
        seen_teams=frozenset(),
    )
    return PR(**{**defaults, **kwargs})


def pr_json(number=1, base="ubuntu-26.10", draft=False, state="open", author="dave"):
    return {
        "number": number,
        "state": state,
        "draft": draft,
        "base": {"ref": base},
        "user": {"login": author},
        "requested_reviewers": [],
        "requested_teams": [],
    }


class TestPackageOf:
    @pytest.mark.parametrize(
        "path, package",
        [
            ("slices/systemd.yaml", "systemd"),
            ("slices/libstdc++6.yaml", "libstdc++6"),
            ("tests/spread/integration/systemd/task.yaml", "systemd"),
            ("tests/spread/integration/openssh-server/files/sshd_config", "openssh-server"),
        ],
    )
    def test_match(self, path: str, package: str) -> None:
        assert triage_prs.package_of(path) == package

    @pytest.mark.parametrize(
        "path",
        [
            "chisel.yaml",
            "spread.yaml",
            "slices/foo/bar.yaml",
            "slices/foo.yml",
            "tests/spread/lib/install-slices",
            "tests/spread/integration/systemd",
            ".github/workflows/ci.yaml",
        ],
    )
    def test_no_match(self, path: str) -> None:
        assert triage_prs.package_of(path) is None


class TestMatch:
    def test_packages(self) -> None:
        guild = {"canonical/guild": ()}
        assert triage_prs.match(CONFIG, frozenset({"openjdk-21-jre-headless"})) == {
            "alice": ("openjdk-21-jre-headless",),
            **guild,
        }
        assert triage_prs.match(CONFIG, frozenset({"tomcat10-common", "systemd"})) == {
            "alice": ("tomcat10-common",),
            "Bob": ("systemd",),
            "canonical/guild": (),
            "canonical/systemd-team": ("systemd",),
            "carol": ("systemd",),
        }
        packages = frozenset({"systemd-dev", "openjdk-21-jdk-headless"})
        assert triage_prs.match(CONFIG, packages) == guild

    def test_every_pr(self) -> None:
        assert triage_prs.match(CONFIG, frozenset()) == {"canonical/guild": ()}

    def test_union_across_entries(self) -> None:
        packages = frozenset({"systemd", "libsystemd0"})
        assert triage_prs.match(CONFIG, packages)["Bob"] == ("libsystemd0", "systemd")


class TestConfig:
    def test_repo_config_is_valid(self) -> None:
        assert Config.load(triage_prs.DEFAULT_CONFIG).entries

    def test_repo_config_teams_are_canonical(self) -> None:
        """The API takes team slugs alone, from the org which owns the repo."""
        config = Config.load(triage_prs.DEFAULT_CONFIG)
        for entry in config.entries:
            for reviewer in entry.reviewers:
                if "/" in reviewer:
                    assert reviewer.startswith("canonical/"), reviewer

    def test_repo_config_versions_only(self) -> None:
        """Globs stand in for versions and must not reach unrelated packages."""
        config = Config.load(triage_prs.DEFAULT_CONFIG)
        entries = tuple(e for e in config.entries if triage_prs.EVERY_PR not in e.packages)
        packages = frozenset({"rust-coreutils", "golang-github-foo-dev", "dotnet"})
        assert triage_prs.match(Config(entries), packages) == {}

    def test_load(self, tmp_path: Path) -> None:
        path = tmp_path / "codeowners.yaml"
        path.write_text(
            dedent("""
            - reviewers: [canonical/guild]
              packages:
                "*":
            - reviewers: [alice, Bob]
              packages:
                bar-*:
                baz:
            """)
        )
        assert Config.load(path) == Config(
            (
                Entry(("canonical/guild",), ("*",)),
                Entry(("alice", "Bob"), ("bar-*", "baz")),
            )
        )

    @pytest.mark.parametrize(
        "text, error",
        [
            ("- reviewers: [a]\n  packages:\n    foo:\n    foo:\n", "line 4: duplicate key 'foo'"),
            # a list after a key parses as the value of that key
            ("- reviewers: [a]\n  packages:\n    foo:\n    - bar\n", "foo: values are not"),
            ("- reviewers: [a]\n  packages:\n    - bar\n    foo:\n", "while parsing a block"),
            ("- reviewers: [a]\n  packages:\n    **:\n", "while scanning an alias"),
            ("", "must be a non-empty list"),
        ],
    )
    def test_load_invalid(self, tmp_path: Path, text: str, error: str) -> None:
        path = tmp_path / "codeowners.yaml"
        path.write_text(text)
        with pytest.raises(triage_prs.ConfigError, match=error):
            Config.load(path)


class TestValidate:
    def test_valid(self) -> None:
        data = [
            {"reviewers": ["canonical/guild"], "packages": {"*": None}},
            {"reviewers": ["alice", "Bob"], "packages": {"bar-*": None, "baz": None}},
        ]
        assert triage_prs.validate(data) == []

    @pytest.mark.parametrize(
        "text, error",
        [
            ("{reviewers: [a], packages: {foo: }}", "must be a non-empty list"),
            ("[]", "must be a non-empty list"),
            ("[foo]", "entry 1: must be a mapping"),
            ("[{reviewers: [a], packages: {foo: }, owners: [b]}]", "unknown key 'owners'"),
            ("[{packages: {foo: }}]", "entry 1: reviewers: must be a non-empty list"),
            ("[{reviewers: a, packages: {foo: }}]", "reviewers: must be a non-empty list"),
            ("[{reviewers: [-a], packages: {foo: }}]", "is not a GitHub login or <org>/<team>"),
            ("[{reviewers: [org/Team], packages: {foo: }}]", "is not a GitHub login"),
            ("[{reviewers: [org/a/b], packages: {foo: }}]", "is not a GitHub login"),
            ("[{reviewers: [b, a], packages: {foo: }}]", "entry 1 (b, a): reviewers not sorted"),
            ("[{reviewers: [a, A], packages: {foo: }}]", "duplicate reviewers"),
            ("[{reviewers: [a]}]", "packages: must be a non-empty mapping"),
            ("[{reviewers: [a], packages: [foo]}]", "packages: must be a non-empty mapping"),
            ("[{reviewers: [a], packages: {b: , a: }}]", "packages not sorted"),
            ("[{reviewers: [a], packages: {'*': , foo: }}]", "'*' must be the only package"),
            ("[{reviewers: [a], packages: {Foo: }}]", "is not a package name"),
            ("[{reviewers: [a], packages: {'**': }}]", "is not a package name"),
            ("[{reviewers: [a], packages: {'slices/foo.yaml': }}]", "is not a package name"),
            ("[{reviewers: [a], packages: {1234: }}]", "is not a package name"),
            ("[{reviewers: [a], packages: {foo: bar}}]", "foo: values are not supported yet"),
        ],
    )
    def test_invalid(self, text: str, error: str) -> None:
        errors = triage_prs.validate(yaml.safe_load(text))
        assert any(error in e for e in errors), errors


class TestSeenReviewers:
    def test_seen(self) -> None:
        pr = pr_json()
        pr["requested_reviewers"] = [{"login": "Pending"}]
        pr["requested_teams"] = [{"slug": "pending-team"}]
        timeline = [
            {"event": "committed"},
            {"event": "review_requested", "requested_reviewer": {"login": "Alice"}},
            {"event": "review_request_removed", "requested_reviewer": {"login": "bob"}},
            {"event": "review_requested", "requested_team": {"slug": "guild"}},
            {"event": "reviewed", "user": {"login": "carol"}, "state": "commented"},
        ]
        users, teams = triage_prs.seen_reviewers(pr, timeline)
        assert users == {"pending", "alice", "bob", "carol"}
        assert teams == {"pending-team", "guild"}


class TestPlan:
    def test_no_packages(self) -> None:
        request = triage_prs.plan(CONFIG, make_pr())
        assert request == Request(1, users={}, teams={"guild": ()})

    def test_owners(self) -> None:
        pr = make_pr(packages=frozenset({"systemd", "libsystemd0", "tomcat10"}))
        request = triage_prs.plan(CONFIG, pr)
        assert request == Request(
            1,
            users={
                "alice": ("tomcat10",),
                "Bob": ("libsystemd0", "systemd"),
                "carol": ("systemd",),
            },
            teams={
                "guild": (),
                "systemd-team": ("libsystemd0", "systemd"),
            },
        )

    def test_skips_author(self) -> None:
        pr = make_pr(author="bob", packages=frozenset({"systemd"}))
        request = triage_prs.plan(CONFIG, pr)
        assert request is not None
        assert list(request.users) == ["carol"]

    def test_skips_seen(self) -> None:
        pr = make_pr(
            packages=frozenset({"systemd"}),
            seen_users=frozenset({"bob"}),
            seen_teams=frozenset({"guild"}),
        )
        request = triage_prs.plan(CONFIG, pr)
        assert request == Request(
            1, users={"carol": ("systemd",)}, teams={"systemd-team": ("systemd",)}
        )

    def test_nothing_to_do(self) -> None:
        pr = make_pr(
            packages=frozenset({"systemd"}),
            seen_users=frozenset({"bob", "carol"}),
            seen_teams=frozenset({"guild", "systemd-team"}),
        )
        assert triage_prs.plan(CONFIG, pr) is None


class TestIsTriageable:
    def test_open_release_pr(self) -> None:
        assert triage_prs.is_triageable(pr_json())

    @pytest.mark.parametrize(
        "kwargs", [{"draft": True}, {"state": "closed"}, {"base": "main"}]
    )
    def test_skipped(self, kwargs: dict) -> None:
        assert not triage_prs.is_triageable(pr_json(**kwargs))


class FakeGitHub:
    def __init__(self, pages: dict[str, list[dict]], status: dict[str, int] | None = None):
        self.pages = pages
        self.status = status or {}
        self.posted: list[tuple[str, dict]] = []

    def get_all(self, path: str, params: dict | None = None) -> list[dict]:
        return self.pages[path]

    def post(self, path: str, body: dict) -> MagicMock:
        self.posted.append((path, body))
        who = tuple(body.get("reviewers", [])) + tuple(body.get("team_reviewers", []))
        code = self.status.get(",".join(who), 201)
        return MagicMock(ok=code < 400, status_code=code, text="")


class TestFetchPR:
    def test_fetch(self) -> None:
        gh = FakeGitHub(
            {
                "pulls/7/files": [
                    {"filename": "slices/systemd.yaml"},
                    {"filename": "tests/spread/integration/dbus/task.yaml"},
                    {"filename": "slices/new.yaml", "previous_filename": "slices/old.yaml"},
                    {"filename": "chisel.yaml"},
                ],
                "issues/7/timeline": [
                    {"event": "review_requested", "requested_team": {"slug": "guild"}},
                ],
            }
        )
        pr = triage_prs.fetch_pr(gh, pr_json(number=7))  # type: ignore[arg-type]
        assert pr == make_pr(
            number=7,
            packages=frozenset({"systemd", "dbus", "new", "old"}),
            seen_teams=frozenset({"guild"}),
        )


class TestApply:
    request = Request(3, users={"alice": (), "bob": ()}, teams={"guild": ()})

    def test_ok(self) -> None:
        gh = FakeGitHub({})
        assert triage_prs.apply(gh, self.request)  # type: ignore[arg-type]
        assert gh.posted == [
            (
                "pulls/3/requested_reviewers",
                {"reviewers": ["alice", "bob"], "team_reviewers": ["guild"]},
            )
        ]

    def test_retries_one_by_one(self) -> None:
        gh = FakeGitHub({}, status={"alice,bob,guild": 422, "bob": 422})
        assert not triage_prs.apply(gh, self.request)  # type: ignore[arg-type]
        assert [body for _, body in gh.posted] == [
            {"reviewers": ["alice", "bob"], "team_reviewers": ["guild"]},
            {"reviewers": ["alice"]},
            {"reviewers": ["bob"]},
            {"team_reviewers": ["guild"]},
        ]

    def test_other_error(self) -> None:
        gh = FakeGitHub({}, status={"alice,bob,guild": 403})
        assert not triage_prs.apply(gh, self.request)  # type: ignore[arg-type]
        assert len(gh.posted) == 1


class TestDescribe:
    def test_describe(self) -> None:
        request = Request(
            1, users={"alice": ("tomcat10", "tomcat10-common")}, teams={"guild": ()}
        )
        assert triage_prs.describe(make_pr(), request) == (
            "#1 (ubuntu-26.10): request alice (tomcat10, tomcat10-common); team guild"
        )
