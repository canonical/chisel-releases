#!/usr/bin/python3

"""
Tests for install_slices.py script
"""

import logging
import os
import tempfile
import unittest
import unittest.mock

from install_slices import (
    CHISEL_PKG_CACHE,
    Package,
    Archive,
    parse_archive,
    full_slice_name,
    parse_package,
    query_package_existence,
    ensure_package_existence,
    ignore_missing_packages,
    install_slice,
    deb_has_copyright_file,
    main,
)


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
    # Ubuntu Archive Automatic Signing Key (2018) <ftpmaster@ubuntu.com>
    # rsa4096/f6ecb3762474eda9d21b7022871920d1991bc93c 2018-09-17T15:01:46Z
    ubuntu-archive-key-2018:
        id: "871920D1991BC93C"
        armor: |
            -----BEGIN PGP PUBLIC KEY BLOCK-----

            mQINBFufwdoBEADv/Gxytx/LcSXYuM0MwKojbBye81s0G1nEx+lz6VAUpIUZnbkq
            dXBHC+dwrGS/CeeLuAjPRLU8AoxE/jjvZVp8xFGEWHYdklqXGZ/gJfP5d3fIUBtZ
            HZEJl8B8m9pMHf/AQQdsC+YzizSG5t5Mhnotw044LXtdEEkx2t6Jz0OGrh+5Ioxq
            X7pZiq6Cv19BohaUioKMdp7ES6RYfN7ol6HSLFlrMXtVfh/ijpN9j3ZhVGVeRC8k
            KHQsJ5PkIbmvxBiUh7SJmfZUx0IQhNMaDHXfdZAGNtnhzzNReb1FqNLSVkrS/Pns
            AQzMhG1BDm2VOSF64jebKXffFqM5LXRQTeqTLsjUbbrqR6s/GCO8UF7jfUj6I7ta
            LygmsHO/JD4jpKRC0gbpUBfaiJyLvuepx3kWoqL3sN0LhlMI80+fA7GTvoOx4tpq
            VlzlE6TajYu+jfW3QpOFS5ewEMdL26hzxsZg/geZvTbArcP+OsJKRmhv4kNo6Ayd
            yHQ/3ZV/f3X9mT3/SPLbJaumkgp3Yzd6t5PeBu+ZQk/mN5WNNuaihNEV7llb1Zhv
            Y0Fxu9BVd/BNl0rzuxp3rIinB2TX2SCg7wE5xXkwXuQ/2eTDE0v0HlGntkuZjGow
            DZkxHZQSxZVOzdZCRVaX/WEFLpKa2AQpw5RJrQ4oZ/OfifXyJzP27o03wQARAQAB
            tEJVYnVudHUgQXJjaGl2ZSBBdXRvbWF0aWMgU2lnbmluZyBLZXkgKDIwMTgpIDxm
            dHBtYXN0ZXJAdWJ1bnR1LmNvbT6JAjgEEwEKACIFAlufwdoCGwMGCwkIBwMCBhUI
            AgkKCwQWAgMBAh4BAheAAAoJEIcZINGZG8k8LHMQAKS2cnxz/5WaoCOWArf5g6UH
            beOCgc5DBm0hCuFDZWWv427aGei3CPuLw0DGLCXZdyc5dqE8mvjMlOmmAKKlj1uG
            g3TYCbQWjWPeMnBPZbkFgkZoXJ7/6CB7bWRht1sHzpt1LTZ+SYDwOwJ68QRp7DRa
            Zl9Y6QiUbeuhq2DUcTofVbBxbhrckN4ZteLvm+/nG9m/ciopc66LwRdkxqfJ32Cy
            q+1TS5VaIJDG7DWziG+Kbu6qCDM4QNlg3LH7p14CrRxAbc4lvohRgsV4eQqsIcdF
            kuVY5HPPj2K8TqpY6STe8Gh0aprG1RV8ZKay3KSMpnyV1fAKn4fM9byiLzQAovC0
            LZ9MMMsrAS/45AvC3IEKSShjLFn1X1dRCiO6/7jmZEoZtAp53hkf8SMBsi78hVNr
            BumZwfIdBA1v22+LY4xQK8q4XCoRcA9G+pvzU9YVW7cRnDZZGl0uwOw7z9PkQBF5
            KFKjWDz4fCk+K6+YtGpovGKekGBb8I7EA6UpvPgqA/QdI0t1IBP0N06RQcs1fUaA
            QEtz6DGy5zkRhR4pGSZn+dFET7PdAjEK84y7BdY4t+U1jcSIvBj0F2B7LwRL7xGp
            SpIKi/ekAXLs117bvFHaCvmUYN7JVp1GMmVFxhIdx6CFm3fxG8QjNb5tere/YqK+
            uOgcXny1UlwtCUzlrSaP
            =9AdM
            -----END PGP PUBLIC KEY BLOCK-----
"""
DEFAULT_ARCHIVE = Archive(
    version="22.04",
    components=["main", "universe"],
    suites=["jammy", "jammy-security", "jammy-updates"],
)

# Default package for testing.
DEFAULT_PACKAGE_YAML = """
package: hello
slices:
    bins:
        contents:
            /usr/bin/hello:
"""
DEFAULT_PACKAGE = Package(
    package="hello",
    slices=["bins"],
)


class TestScriptMethods(unittest.TestCase):
    """
    Test the methods of install-slices
    """

    def setUp(self) -> None:
        logging.disable(logging.CRITICAL)

    def tearDown(self) -> None:
        logging.disable(logging.NOTSET)

    def test_parse_archive(self):
        """
        Test parse_archive()
        """
        # test parsing local release
        with tempfile.TemporaryDirectory() as tmpfs:
            filepath = os.path.join(tmpfs, "chisel.yaml")
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(DEFAULT_CHISEL_YAML)
            archive = parse_archive(tmpfs)
            self.assertEqual(archive, DEFAULT_ARCHIVE)
        # test parsing remote release
        archive = parse_archive("ubuntu-22.04")
        self.assertEqual(archive, DEFAULT_ARCHIVE)
        # test parsing archive version properly
        chisel_yaml = DEFAULT_CHISEL_YAML.replace("22.04", "23.10")
        chisel_yaml = chisel_yaml.replace("jammy", "mantic")
        with tempfile.TemporaryDirectory() as tmpfs:
            filepath = os.path.join(tmpfs, "chisel.yaml")
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(chisel_yaml)
            archive = parse_archive(tmpfs)
            self.assertEqual(
                archive,
                Archive(
                    version="23.10",
                    components=["main", "universe"],
                    suites=["mantic", "mantic-security", "mantic-updates"],
                ),
            )

    def test_full_slice_name(self):
        """
        Test full_slice_name()
        """
        name = full_slice_name("foo", "bar")
        self.assertEqual(name, "foo_bar")

    def test_parse_package(self):
        """
        Test parse_package()
        """
        with tempfile.TemporaryDirectory() as tmpfs:
            filepath = os.path.join(tmpfs, "hello.yaml")
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(DEFAULT_PACKAGE_YAML)
            pkg = parse_package(filepath)
            self.assertEqual(pkg, DEFAULT_PACKAGE)

    def test_query_package_existence(self):
        """
        Test query_package_existence()
        """
        found, missing = query_package_existence(
            packages=["libc6", "hello", "foo123"],
            archive=DEFAULT_ARCHIVE,
        )
        self.assertEqual(found, ["hello", "libc6"])
        self.assertEqual(missing, ["foo123"])
        # with specific arch
        found, missing = query_package_existence(
            packages=["libc6", "hello", "foo123"],
            archive=DEFAULT_ARCHIVE,
            arch=["i386"],
        )
        self.assertEqual(found, ["libc6"])
        self.assertEqual(missing, ["foo123", "hello"])

    def test_ensure_package_existence(self):
        """
        Test ensure_package_existence()
        """
        ensure_package_existence(
            packages=["libc6", "hello"],
            archive=DEFAULT_ARCHIVE,
        )
        #
        try:
            ensure_package_existence(
                packages=["libc6", "hello", "foo123"],
                archive=DEFAULT_ARCHIVE,
            )
            assert False
        except SystemExit as e:
            self.assertEqual(e.code, 1)

    def test_ignore_missing_packages(self):
        """
        Test ignore_missing_packages()
        """
        filtered, ignored = ignore_missing_packages(
            packages=[
                Package("libc6", []),
                Package("hello", []),
                Package("foo123", []),
            ],
            arch="i386",
            release="ubuntu-22.04",
        )
        self.assertEqual(filtered, [Package("libc6", [])])
        self.assertEqual(
            ignored,
            [
                Package("hello", []),
                Package("foo123", []),
            ],
        )

    def test_install_slice(self):
        """
        Test install_slice()
        """
        mock_missing_copyright = {}
        install_slice("libc6", "libs", "amd64", "ubuntu-22.04", mock_missing_copyright)
        assert mock_missing_copyright == {"libc6_libs": False}
        #
        try:
            install_slice(
                "foo123", "bar", "amd64", "ubuntu-22.04", mock_missing_copyright
            )
            assert False
        except SystemExit as e:
            self.assertEqual(e.code, 1)

    @unittest.mock.patch("os.popen")
    @unittest.mock.patch("pathlib.Path.is_file")
    @unittest.mock.patch("apt.debfile.DebPackage.__new__")
    def test_deb_has_copyright_file(self, mock_debpackage, mock_is_file, mock_popen):
        """
        Test deb_has_copyright_file()
        """
        mock_popen.return_value.read.return_value = "sha\n"

        # If SHA is not a file, we keep skipping
        mock_is_file.return_value = False
        assert deb_has_copyright_file("mock_pkg") == False
        mock_debpackage.assert_not_called()
        mock_is_file.assert_called_once()

        # If SHA is a deb file but the package name doesn't match, we skip
        mock_is_file.return_value = True
        mock_deb = unittest.mock.MagicMock()
        mock_deb.pkgname = "wrong"
        mock_debpackage.return_value = mock_deb
        assert deb_has_copyright_file("mock_pkg") == False

        # If the deb matches and its contents have a copyright, return True
        mock_deb.pkgname = "mock_pkg"
        mock_deb.filelist = "something\nusr/share/doc/mock_pkg/copyright\nextra"
        mock_debpackage.return_value = mock_deb
        assert deb_has_copyright_file("mock_pkg") == True

    def test_main(self):
        """
        Test main()
        """
        with tempfile.TemporaryDirectory() as tmpfs:
            with open(os.path.join(tmpfs, "chisel.yaml"), "w", encoding="utf-8") as f:
                f.write(DEFAULT_CHISEL_YAML)
            slices_dir = os.path.join(tmpfs, "slices")
            os.mkdir(slices_dir)
            slice_path = os.path.join(slices_dir, "hello.yaml")
            with open(slice_path, "w", encoding="utf-8") as f:
                f.write(DEFAULT_PACKAGE_YAML)
            args = ["", "--arch", "amd64", "--release", tmpfs, slice_path]
            with unittest.mock.patch("sys.argv", args):
                try:
                    main()
                except SystemExit as e:
                    self.assertEqual(e.code, 0)


if __name__ == "__main__":
    unittest.main()
