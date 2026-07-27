#!/usr/bin/env python3
"""
Unit tests for install_slices.py
"""

import os
import sys
from unittest.mock import MagicMock, patch

import pytest

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    import install_slices
except ImportError:
    # python3-apt is a system package pip cannot provide, and python-magic
    # raises without libmagic. Both are only reached from
    # deb_has_copyright_file(), which the tests below mock.
    apt = sys.modules.setdefault("apt", MagicMock())
    sys.modules["apt.debfile"] = apt.debfile
    sys.modules.setdefault("magic", MagicMock())

    import install_slices


# Default archive for testing. Copied from the ubuntu-22.04 release.
DEFAULT_CHISEL_YAML = """
format: v1

archives:
    ubuntu:
        version: 22.04
        components: [main, universe]
        suites: [jammy, jammy-security, jammy-updates]
        public-keys: [ubuntu-archive-key-2018]

public-keys:
    ubuntu-archive-key-2018:
        id: "871920D1991BC93C"
        armor: |
            -----BEGIN PGP PUBLIC KEY BLOCK-----
            not a real key
            -----END PGP PUBLIC KEY BLOCK-----
"""
DEFAULT_ARCHIVE = install_slices.Archive(
    version="22.04",
    components=["main", "universe"],
    suites=["jammy", "jammy-security", "jammy-updates"],
)

DEFAULT_PACKAGE_YAML = """
package: hello
slices:
    bins:
        contents:
            /usr/bin/hello:
"""
DEFAULT_PACKAGE = install_slices.Package(package="hello", slices=["bins"])


def rmadison_output(*packages: str) -> str:
    """Build output in the format rmadison prints for found packages."""
    return "".join(f" {p} | 1.0-1 | jammy | source, amd64, arm64\n" for p in packages)


def mock_rmadison(*found: str, returncode: int = 0) -> MagicMock:
    """A subprocess.run replacement that reports `found` as present."""
    return MagicMock(
        return_value=MagicMock(
            returncode=returncode, stdout=rmadison_output(*found), stderr=""
        )
    )


def write_release(tmp_path, chisel_yaml: str = DEFAULT_CHISEL_YAML) -> str:
    """Write a minimal chisel release directory and return its path."""
    (tmp_path / "chisel.yaml").write_text(chisel_yaml, encoding="utf-8")
    return str(tmp_path)


class TestParseArchive:
    """parse_archive()"""

    def test_local_release(self, tmp_path):
        archive = install_slices.parse_archive(write_release(tmp_path))
        assert archive == DEFAULT_ARCHIVE

    def test_remote_release(self):
        # A bare release name is fetched over HTTP rather than read from disk.
        response = MagicMock(content=DEFAULT_CHISEL_YAML.encode())
        with patch("requests.get", return_value=response) as get:
            archive = install_slices.parse_archive("ubuntu-22.04")
        assert archive == DEFAULT_ARCHIVE
        assert get.call_args.args[0].endswith("/ubuntu-22.04/chisel.yaml")

    def test_version_is_stringified(self, tmp_path):
        # YAML parses 23.10 as a float; it must not become "23.1".
        chisel_yaml = DEFAULT_CHISEL_YAML.replace("22.04", "23.10")
        chisel_yaml = chisel_yaml.replace("jammy", "mantic")
        archive = install_slices.parse_archive(write_release(tmp_path, chisel_yaml))
        assert archive == install_slices.Archive(
            version="23.10",
            components=["main", "universe"],
            suites=["mantic", "mantic-security", "mantic-updates"],
        )

    def test_malformed_yaml(self, tmp_path):
        with pytest.raises(SystemExit) as exc:
            install_slices.parse_archive(write_release(tmp_path, "archives: ["))
        assert exc.value.code == 1


class TestParsePackage:
    """parse_package() and full_slice_name()"""

    def test_full_slice_name(self):
        assert install_slices.full_slice_name("foo", "bar") == "foo_bar"

    def test_parse_package(self, tmp_path):
        path = tmp_path / "hello.yaml"
        path.write_text(DEFAULT_PACKAGE_YAML, encoding="utf-8")
        assert install_slices.parse_package(str(path)) == DEFAULT_PACKAGE

    def test_slices_are_sorted(self, tmp_path):
        path = tmp_path / "hello.yaml"
        path.write_text(
            "package: hello\nslices:\n    zed:\n    bins:\n    mid:\n",
            encoding="utf-8",
        )
        assert install_slices.parse_package(str(path)).slices == ["bins", "mid", "zed"]

    def test_missing_key(self, tmp_path):
        path = tmp_path / "hello.yaml"
        path.write_text("package: hello\n", encoding="utf-8")
        with pytest.raises(SystemExit) as exc:
            install_slices.parse_package(str(path))
        assert exc.value.code == 1


class TestQueryPackageExistence:
    """query_package_existence() and its rmadison invocation"""

    def test_found_and_missing(self):
        with patch("subprocess.run", mock_rmadison("libc6", "hello")):
            found, missing = install_slices.query_package_existence(
                packages=["libc6", "hello", "foo123"], archive=DEFAULT_ARCHIVE
            )
        assert found == ["hello", "libc6"]
        assert missing == ["foo123"]

    def test_rmadison_args(self):
        run = mock_rmadison("libc6")
        with patch("subprocess.run", run):
            install_slices.query_package_existence(
                packages=["libc6"], archive=DEFAULT_ARCHIVE, arch=["i386"]
            )
        args = run.call_args.args[0]
        assert args[0] == "rmadison"
        assert args[args.index("--architecture") + 1] == "i386"
        assert args[args.index("--component") + 1] == "main,universe"
        assert args[args.index("--suite") + 1] == "jammy,jammy-security,jammy-updates"
        # rmadison takes the package names as a single space-delimited argument.
        assert args[-1] == "libc6"

    def test_batching(self):
        packages = [f"pkg{i}" for i in range(120)]
        run = mock_rmadison(*packages)
        with patch("subprocess.run", run):
            found, missing = install_slices.query_package_existence(
                packages=packages, archive=DEFAULT_ARCHIVE, batch_size=50
            )
        assert run.call_count == 3
        assert found == sorted(packages)
        assert missing == []

    def test_rmadison_failure_exits(self):
        with patch("subprocess.run", mock_rmadison(returncode=2)):
            with pytest.raises(SystemExit) as exc:
                install_slices.query_package_existence(
                    packages=["libc6"], archive=DEFAULT_ARCHIVE
                )
        assert exc.value.code == 2


class TestEnsurePackageExistence:
    """ensure_package_existence()"""

    def test_all_present(self):
        with patch("subprocess.run", mock_rmadison("libc6", "hello")):
            install_slices.ensure_package_existence(
                packages=["libc6", "hello"], archive=DEFAULT_ARCHIVE
            )

    def test_missing_exits(self):
        with patch("subprocess.run", mock_rmadison("libc6", "hello")):
            with pytest.raises(SystemExit) as exc:
                install_slices.ensure_package_existence(
                    packages=["libc6", "hello", "foo123"], archive=DEFAULT_ARCHIVE
                )
        assert exc.value.code == 1


class TestIgnoreMissingPackages:
    """ignore_missing_packages()"""

    def test_split(self, tmp_path):
        packages = [
            install_slices.Package("libc6", []),
            install_slices.Package("hello", []),
            install_slices.Package("foo123", []),
        ]
        with patch("subprocess.run", mock_rmadison("libc6")):
            filtered, ignored = install_slices.ignore_missing_packages(
                packages=packages, arch="i386", release=write_release(tmp_path)
            )
        assert filtered == [install_slices.Package("libc6", [])]
        assert ignored == [
            install_slices.Package("hello", []),
            install_slices.Package("foo123", []),
        ]


class TestChiselCut:
    """chisel_cut() -- argument construction and retries"""

    @staticmethod
    def _cut(results, **overrides):
        """Run chisel_cut with subprocess.run yielding `results` in order."""
        run = MagicMock(side_effect=results)
        kwargs = {
            "arch": "amd64",
            "release": "./",
            "root": "/tmp/root",
            "slice_name": "hello_bins",
            "chisel_version": "main",
            "cache_dir": "/tmp/cache",
        }
        kwargs.update(overrides)
        with patch("subprocess.run", run):
            return install_slices.chisel_cut(**kwargs), run

    def test_cache_dir_is_passed_through_the_environment(self):
        _, run = self._cut([MagicMock(returncode=0, stderr="")], cache_dir="/tmp/xyz")
        assert run.call_args.kwargs["env"]["XDG_CACHE_HOME"] == "/tmp/xyz"

    def test_command_line(self):
        _, run = self._cut([MagicMock(returncode=0, stderr="")])
        args = run.call_args.args[0]
        assert args[:2] == ["chisel", "cut"]
        assert args[args.index("--arch") + 1] == "amd64"
        assert args[args.index("--root") + 1] == "/tmp/root"
        assert args[-1] == "hello_bins"

    @pytest.mark.parametrize(
        "version,expected",
        [
            ("v1.1.0", False),
            ("v1.2.0", False),
            ("v1.4.2", True),
            ("main", True),
            ("unknown", True),
        ],
    )
    def test_ignore_unstable_version_gate(self, version, expected):
        _, run = self._cut([MagicMock(returncode=0, stderr="")], chisel_version=version)
        assert ("--ignore=unstable" in run.call_args.args[0]) is expected

    def test_non_retryable_error_returns_immediately(self):
        err, run = self._cut([MagicMock(returncode=1, stderr="error: no such slice")])
        assert err == "error: no such slice"
        assert run.call_count == 1

    def test_retryable_error_is_retried_then_gives_up(self):
        failure = MagicMock(returncode=1, stderr="cannot talk to archive")
        err, run = self._cut([failure, failure, failure])
        assert err == "cannot talk to archive"
        assert run.call_count == 3

    def test_retryable_error_then_success(self):
        err, run = self._cut(
            [
                MagicMock(returncode=1, stderr="cannot fetch from archive"),
                MagicMock(returncode=0, stderr=""),
            ]
        )
        assert err is None
        assert run.call_count == 2


class TestInstallSlices:
    """install_slices() -- per-chunk behaviour"""

    CHUNK = [("coreutils", "bins"), ("coreutils", "cat"), ("bash", "bins")]

    @staticmethod
    def _run(chunk, dry_run=False, cut=None):
        """Run a chunk with chisel_cut stubbed; return its recorded calls."""
        cut = cut or MagicMock(return_value=None)
        with (
            patch("install_slices.chisel_cut", cut),
            patch("install_slices.deb_has_copyright_file", return_value=False),
        ):
            install_slices.install_slices(
                chunk, dry_run, "amd64", "ubuntu-26.04", 1, "main"
            )
        return [c.kwargs for c in cut.call_args_list]

    def test_every_slice_is_installed(self):
        calls = self._run(self.CHUNK)
        assert [c["slice_name"] for c in calls] == [
            "coreutils_bins",
            "coreutils_cat",
            "bash_bins",
        ]

    def test_dry_run_installs_nothing(self):
        assert self._run(self.CHUNK, dry_run=True) == []

    def test_error_aborts_the_rest_of_the_chunk(self):
        calls = self._run(self.CHUNK, cut=MagicMock(return_value="boom"))
        assert len(calls) == 1


class TestDebHasCopyrightFile:
    """deb_has_copyright_file()"""

    @patch("os.popen")
    @patch("pathlib.Path.rglob")
    @patch("install_slices.DebPackage")
    @patch("magic.from_file")
    def test_deb_has_copyright_file(self, magic_from_file, debpackage, rglob, popen):
        # No files in the cache, nothing to inspect.
        rglob.return_value = []
        assert install_slices.deb_has_copyright_file("mock_pkg") is False
        debpackage.assert_not_called()

        # A cached blob that is not a deb is skipped.
        rglob.return_value = ["fake_sha"]
        magic_from_file.return_value = "not-a-deb"
        assert install_slices.deb_has_copyright_file("mock_pkg") is False
        magic_from_file.assert_called_once_with("fake_sha", mime=True)
        popen.assert_not_called()

        # A deb belonging to another package is skipped.
        magic_from_file.return_value = "debian.binary-package"
        popen.return_value.read.return_value = "bad-pkg-name"
        assert install_slices.deb_has_copyright_file("mock_pkg") is False
        popen.assert_called_once_with(
            f"dpkg-deb -f {str(install_slices.CHISEL_PKG_CACHE)}/fake_sha Package"
        )
        debpackage.assert_not_called()

        # The matching deb decides the answer.
        popen.return_value.read.return_value = "mock_pkg"
        deb = MagicMock()
        deb.filelist = "no\ncopyright\nfile"
        debpackage.return_value = deb
        assert install_slices.deb_has_copyright_file("mock_pkg") is False
        debpackage.assert_called_once()

        deb.filelist = "something\nusr/share/doc/mock_pkg/copyright\nextra"
        assert install_slices.deb_has_copyright_file("mock_pkg") is True


class TestMain:
    """main() -- argument handling and chunking"""

    @staticmethod
    def _main(tmp_path, extra_argv=(), slices=("bins",), workers=None):
        """Run main() over a one-package release; return the submitted chunks."""
        release = write_release(tmp_path)
        sdf = tmp_path / "hello.yaml"
        sdf.write_text(
            "package: hello\nslices:\n"
            + "".join(f"    {s}:\n        contents:\n" for s in slices),
            encoding="utf-8",
        )
        argv = ["", "--arch", "amd64", "--release", release]
        if workers is not None:
            argv += ["--workers", str(workers)]
        argv += [*extra_argv, str(sdf)]

        executor = MagicMock()
        # configure_logging() writes error.log into the working directory.
        cwd = os.getcwd()
        os.chdir(tmp_path)
        try:
            with (
                patch("sys.argv", argv),
                patch("install_slices.ProcessPoolExecutor") as pool,
                patch("install_slices.as_completed", lambda fs: fs),
            ):
                pool.return_value.__enter__.return_value = executor
                install_slices.main()
        finally:
            os.chdir(cwd)
        return [c.args for c in executor.submit.call_args_list]

    def test_chunks_are_submitted(self, tmp_path):
        chunks = self._main(tmp_path)
        assert len(chunks) == 1
        fn, slices, dry_run, arch, release, worker, version = chunks[0]
        assert fn is install_slices.install_slices
        assert slices == [("hello", "bins")]
        assert (dry_run, arch, worker, version) == (False, "amd64", 1, "unknown")

    def test_slices_are_split_across_workers(self, tmp_path):
        chunks = self._main(tmp_path, slices=("a", "b", "c", "d"), workers=2)
        assert [c[1] for c in chunks] == [
            [("hello", "a"), ("hello", "b")],
            [("hello", "c"), ("hello", "d")],
        ]
        assert [c[5] for c in chunks] == [1, 2]
